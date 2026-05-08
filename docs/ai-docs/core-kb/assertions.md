# Assertions

An **assertion** is the KB's atomic record of a believed sentence. Every fact, rule, and meta-claim that lives in Cyc is an assertion: it pairs an HL formula (the *content*) with a microtheory (the *context*), a truth/strength pair (its *truth value*), a direction marker (`:forward` / `:backward` / `:code`, governing how inference uses it), and the bookkeeping that justifies why it's there at all (its *arguments* — assertions are never naked facts, they are facts plus reasons).

Assertions have a **handle/content split** that mirrors the Constant and NART pattern: a tiny `assertion` struct carrying just an integer ID, plus a heavyweight `assertion-content` carrying the formula, MT, flag bits, argument list, and property plist. The content lives in an LRU-fronted on-disk store (the `kb-object-manager`) so the working set of assertions in RAM is bounded by `*assertion-lru-size-percentage*` (16% — chosen because Arete experiments showed 16% of assertions cover normal inference traffic).

Assertions are also the thing the KB *indexes*: every assertion is registered in the term index of every term it mentions, so that "all assertions about X" and "all rules whose antecedent matches X" can be retrieved without a scan. The TMS (truth-maintenance system) also tracks each assertion's *arguments* (asserted-argument tokens or deductions), so removing an assertion can cascade to dependent assertions.

A **GAF** (Ground Atomic Formula) is a special, common case: an assertion whose formula is a single atomic literal with no variables and no logical connectives — the workhorse representation of facts like `(isa Fido Dog)`. GAFs are tracked separately from rules everywhere a fast path matters.

## When does an assertion get created?

Five situations drive `kb-create-assertion` (the lowest-level mint, an `hl-creator`-wrapped function). All other "create an assertion" entry points funnel into one of these:

1. **A cyclist asserts a sentence via the KE** (`ke-assert`, `ke-assert-now`, `ke-assert-wff-now` in `ke.lisp`). The interactive editor canonicalizes the EL formula, picks an MT, and calls into the storage module's `:asserted-argument` path — `hl-assert-as-kb-assertion`. If the (CNF, MT) pair doesn't already exist, a new assertion is minted and an asserted-argument-token is attached carrying the cyclist's chosen TV.

2. **An external client asserts via FI** (`fi-assert` in `fi.lisp`). The functional interface used by transcript replay, file translation, and the API layer. Routes through `tms-create-asserted-argument-with-tv` after canonicalization. Same effect as #1 — assertion plus asserted-argument-token.

3. **A forward rule's conclusion needs to be persisted.** Forward inference produces a deduction whose conclusion is an assertion that may not yet exist. The forward-propagation drain calls `hl-deduce-as-kb-deduction` → `tms-add-deduction-for-cnf` → `find-or-create-assertion`. If the conclusion-assertion is new, it's minted here and the deduction is attached. If the conclusion-assertion already exists (some other path produced it earlier), only the deduction is added. **This is the only inference-driven creation path**; backward queries never mint assertions.

4. **A canonicalization rewrite needs to look up or create the rewritten form.** When a sentence is canonicalized, the canonical form may be a CNF that doesn't yet exist as an assertion. `find-or-create-assertion` is used as a lookup-or-mint primitive in some czer paths.

5. **KB load reads an assertion off the dump.** Two-phase: `initialize-assertion-shells` mints a handle for every dump-id 0..N-1 (no content yet), then `load-assertion-content` populates each handle's content from the CFASL stream. The mint here doesn't go through `kb-create-assertion` — it goes through the lower-level `make-assertion-shell` directly, because the assertion's identity is dictated by the dump rather than synthesized fresh.

**Backward inference does not create assertions.** A backward worker computes answer bindings and returns them; the proof tree it builds is transient (held in `problem` / `proof` datastructures during the inference run) and discarded when the run completes. If a query's conclusion needs to *become* an assertion, that's a separate post-query persistence step — currently a missing-larkc gap (the same `tms-reprove-deduction-query-*` machinery as discussed in [deductions.md](deductions.md#when-does-a-deduction-get-created)).

The minting distinction worth keeping in mind: `kb-create-assertion` makes a new fact (the formula plus its MT plus a fresh handle); the *justification* for that fact (asserted-argument-token vs. deduction) is attached separately. KE-driven creation always also attaches an asserted-argument; forward-driven creation always also attaches a deduction; KB-load reads both back from the dump.

## Terminology

- **HL CNF / formula data**: the canonical Heuristic-Level form of the assertion's sentence. For a rule, this is a CNF clause. For a GAF, the storage is the GAF formula itself (a list `(pred arg1 ... argN)`); `gaf-formula-to-cnf` synthesizes a one-literal CNF on demand. The slot may also hold a `clause-struc` (a shared CNF interned across many assertions — the rule-folding optimization).
- **MT**: the assertion's microtheory. An `hlmt` — either a FORT (constant or NART) or a NAUT-shaped microtheory expression.
- **TV** (truth value): a fused (truth, strength) pair, encoded into 3 bits inside the flags. Truth ∈ {`:true`, `:false`, `:unknown`}; strength ∈ {`:monotonic`, `:default`, `:unknown`}.
- **Direction**: `:backward` (the default; rule fires only when needed during a query), `:forward` (rule fires immediately when its antecedent becomes provable), `:code` (rule executes attached SubL, not a CycL inference step).
- **Argument**: in the bookkeeping sense — a justification for the assertion. Either an *asserted-argument token* (the assertion was directly asserted by a cyclist) or a `deduction` (the assertion is the conclusion of a rule applied to other supports). An assertion's `arguments` list contains all of these. **Note the overload:** "argument" means both *justification* (this sense) and *parameter to a predicate* (`gaf-arg N`); the context disambiguates.
- **Dependent**: the inverse pointer of an argument. A deduction that *uses* this assertion as a support shows up in this assertion's `dependents`. Removing the assertion removes those dependents.
- **Asserted vs deduced**: an assertion is *asserted* if any of its arguments is an asserted-argument token; otherwise it is purely *deduced*. Both states can coexist (multiple justifications).
- **`tou-assertion?`**: a `(#$termOfUnit nart naut)` GAF. These are the records that reify NARTs, so they are kept distinct in TMS and in cleanup paths.

## Data structure

### Handle struct

```lisp
(defstruct (assertion (:conc-name as-))
  id)    ; non-negative integer | nil
```

Same minimal handle pattern as `constant` and `nart`. The handle is identity; everything else lives in the content.

`free-assertion` invalidates by NIL-ing the ID; `assertion-handle-valid?` is `(integerp (as-id ...))`. `valid-assertion?` is the predicate used everywhere the caller needs to be defensive against stale handles (after a removal, a CFASL load with a dangling reference, etc.).

`make-assertion-shell` is the allocation primitive: takes an optional ID (mints one via `make-assertion-id` from the id-index reserve when omitted) and registers the new handle in `*assertion-from-id*`. Used both during normal creation (via `kb-create-assertion-kb-store`) and during KB load to pre-allocate the entire ID space before content streams in (`initialize-assertion-shells`).

### Content struct

```lisp
(defstruct (assertion-content (:conc-name as-content-))
  formula-data   ; cnf | gaf-formula | clause-struc | nil
  mt             ; hlmt-p
  flags          ; fixnum: (gaf-bit | direction-bits | tv-bits)
  arguments      ; list of asserted-argument-tokens and/or deductions
  plist)         ; property list — :variable-names, :assert-info, :dependents, :index
```

The content is the heavy object. It is created by `create-assertion-content` (just allocates with default flags), populated lazily through the per-field setters (`set-assertion-formula-data`, `set-assertion-flags`, `set-assertion-arguments`, `set-assertion-plist`), and ultimately swapped in/out by `*assertion-content-manager*` keyed on the ID. Every setter calls `mark-assertion-content-as-muted` so the LRU knows to write back on eviction.

The flags fixnum is bit-packed:

| Bits | Field | Decoder |
|---|---|---|
| 0 | gaf? | `assertion-flags-gaf-p` |
| 1–2 | direction | `assertion-flags-direction-code` → `decode-direction` |
| 3–5 | tv | `assertion-flags-tv-code` → `decode-tv` |

The plist holds rarely-changing or rarely-set properties so the content struct doesn't grow a slot per attribute:

- `:variable-names` — list of strings, the EL variable names for rule literals. Empty for GAFs.
- `:assert-info` — `(who when why second)` 4-tuple; present iff some asserted-argument carries timestamp/cyclist info.
- `:dependents` — list of deductions that use this assertion as a support. Maintained by TMS via `add-assertion-dependent` / `remove-assertion-dependent`.
- `:index` — the index (forward-pointer to all assertions that mention this assertion as a meta-assertion). See [the index section](#assertion-as-meta-target-the-assertion-index).

### `assert-info` 4-tuple

```lisp
(defstruct (assert-info (:type list)
                        (:constructor make-assert-info (&optional who when why second)))
  who when why second)
```

Stored as a plain list, so `(:type list)` gives free positional access. `who` is the cyclist FORT, `when` is a universal-date (day granularity), `why` is the purpose FORT, `second` is the universal-second (sub-day timestamp). The four fields are addressed individually through `set-assertion-asserted-by/-when/-why/-second`, each of which destructures the existing tuple, replaces one slot, and calls `reset-assertion-assert-info`.

## Identifier space

Assertions use a single per-image integer ID. **There is no GUID.** Like NARTs, an assertion's identity is local to the image; cross-image transport is by *recipe* (write the formula, MT, etc. with constants/NARTs going by their cross-image identity), or by *handle* with a separately-shipped dump-id table that bridges old IDs to new ones during a KB load.

The lookup tables:

```
ID  → assertion              *assertion-from-id*           (id-index)
ID  → assertion-content      *assertion-content-manager*   (LRU + on-disk file-vector)
```

`*assertion-content-manager*` is a `kb-object-manager` ("assertion" / "assertion-index" file pair). It deserializes content on cache miss via `load-assertion-def-from-cache`, and uses `*cfasl-assertion-handle-lookup-func*` = nil during the swap-in so the content's CFASL stream reads any embedded assertion handles as direct IDs.

There is also a transient **dump-id table**:

```lisp
*assertion-dump-id-table*               ; hash IDs at-time-of-dump → current handle (or vice-versa)
*cfasl-assertion-handle-func*           ; on dump: ID-rewrite function
*cfasl-assertion-handle-lookup-func*    ; on load: ID-rewrite function
```

`with-assertion-dump-id-table` binds the table and the dump-direction func together; the load side is bound by the KB-load preamble in `kb-load-from-directory` (see [cfasl.md](../persistence/cfasl.md) for the full pattern).

## Lifecycle

### Birth

The triggering situations are listed in [When does an assertion get created?](#when-does-an-assertion-get-created) above. All paths converge on `kb-create-assertion`, an `hl-creator`-wrapped function that:

1. Routes to `kb-create-assertion-local` (or, in a remote-image setup, `missing-larkc 32157`).
2. `kb-create-assertion-kb-store` — first, look the (CNF, MT) pair up via `find-assertion-internal`. If an assertion already exists, return its ID. Otherwise mint a new ID, allocate a shell (`make-assertion-shell`), then call `kb-create-assertion-int`.
3. `kb-create-assertion-int` — register a fresh `assertion-content` in the manager, set TV to `:unknown`, find a `formula-data-hook` for the CNF (this is the **clause-struc sharing path** — if another assertion in any MT already carries this CNF, reuse its `clause-struc`), then `connect-assertion`.
4. `connect-assertion` — install the formula data and add the assertion to all relevant term indices (`add-assertion-indices`).

After creation, `create-assertion-int` sets the variable names and direction. The variable names are *the EL names* (strings); `assertion-el-variables` walks them through `intern-el-var` to recover the HL variables.

`find-or-create-assertion` is the "upsert" entry: lookup, create only if absent. For purely GAF use (formula, not CNF), the obsolete `find-or-create-gaf` exists but is `missing-larkc`.

### Mutation

The assertion's *content* mutates in well-defined situations:

- **TV recomputation**: when an argument is added or removed, the TMS calls `tms-recompute-assertion-tv`, which may flip truth/strength bits via `reset-assertion-tv` (and back-propagate the flag changes). If the recomputation determines no support remains, the assertion is removed.
- **Direction change**: `kb-set-assertion-direction` — if the assertion is a rule, the indices must be torn down and rebuilt because the rule index is keyed on direction; for GAFs it's just a flag update.
- **Variable names rewrite**: `kb-set-assertion-variable-names` — sets/clears `:variable-names` plist entry.
- **Bookkeeping timestamp**: `kb-set-assertion-asserted-by/-when/-why/-second` — destructure-modify-reassemble the `assert-info` 4-tuple. Only meaningful when the assertion has an asserted argument.
- **Argument list changes**: `add-new-assertion-argument` / `remove-assertion-argument` — TMS-level mutations. Only the TMS is supposed to touch these.
- **Dependents**: `add-assertion-dependent` / `remove-assertion-dependent` — the back-pointer is updated whenever some other assertion's deduction starts or stops using this assertion as a support.
- **Formula data swap**: `update-assertion-formula-data` is the multiplexer: if the new value is a `clause-struc` it goes through `missing-larkc 32000`; if NIL it `annihilate`s; if a CNF it `reset-assertion-cnf`s; if an EL formula it `reset-assertion-gaf-formula`s. Used by canonicalization-replacement paths.

Every setter dispatches through `set-assertion-content` → `mark-assertion-content-as-muted`, so the LRU's dirty bit is set and the next eviction will flush.

### Death

Removal is initiated by `tms-remove-assertion` (or a forced `remove-assertion` from KE). The TMS path:

1. If the assertion has arguments, recursively `tms-remove-argument` each. Each argument-removal may in turn cascade to dependent assertions.
2. When no arguments remain (or removal is forced), `tms-remove-assertion-int-2` runs:
   - `remove-term-indices` — strip every term index that points to this assertion.
   - `remqueue-forward-assertion` — if it was queued for forward propagation, dequeue.
   - For rules, `clear-transformation-rule-statistics`.
   - **Skip the final removal if it's a `tou-assertion?`** (a `(#$termOfUnit nart naut)` GAF) — the NART subsystem owns the lifecycle of those.
   - Otherwise `remove-assertion` → `kb-remove-assertion` → `kb-remove-assertion-internal`:
     - `disconnect-assertion` — `remove-assertion-indices` then `disconnect-assertion-formula-data` (annihilate the formula slot, releasing any clause-struc co-occupancy).
     - `destroy-assertion-content` — NIL out every slot of the content struct, deregister from the content manager.
     - `deregister-assertion-id` — remove from the id-index.
     - `free-assertion` — NIL the handle's ID.

After this, `valid-assertion?` returns NIL on the freed handle. Any other reference still holding the handle (e.g. a deduction's support list) will see it as invalid; `valid-support?` is the gate every support consumer should check.

`free-all-assertions` is the global teardown: walk the id-index, NIL every handle, clear both tables. Called only as part of full KB-state reset.

## The clause-struc sharing optimization

Rule CNFs are heavyweight and frequently shared across MTs (e.g. the same logical implication asserted in multiple contexts). Cyc folds shared CNFs through a `clause-struc` interning layer:

- During `kb-create-assertion-int`, `find-cnf-formula-data-hook cnf` checks whether some other assertion in any MT already carries this exact CNF. If so, it returns either the existing assertion's `clause-struc` (if one is present) or the existing assertion itself (the second assertion will get a clause-struc built and both will end up sharing it).
- `connect-assertion-formula-data` is the dispatch on the hook type. The CNF case is the trivial path: the assertion's formula slot becomes the CNF directly. The `assertion-p` case is the *promotion-to-shared* path: build a new `clause-struc` for the existing CNF (currently `missing-larkc 11343`), point the existing assertion at it, then point the new assertion at the same struc. The `clause-struc-p` case is the *already-shared* path: just point at the existing struc.
- `assertion-clause-struc` returns the struc if present, else NIL. `assertion-hl-cnf` walks one level of indirection: if the formula slot is a clause-struc, return its CNF; if it's a GAF formula, lift it to a CNF on the fly via `gaf-formula-to-cnf`.

In a clean rewrite, this could be reframed as: the `formula-data` slot is a single value, and CNF identity goes through a hash-cons (or, since rules are rare, a simple weak-keyed table from CNF to the canonical assertion that owns it). The current scheme requires every assertion-side CNF reader to peek through the clause-struc layer.

Most of the active build path for clause-strucs is `missing-larkc` in the LarKC drop (11315, 11316, 11317, 11343, 11355, 32000, 32001) — the runtime that's there only consumes pre-built clause-strucs (read from CFASL during KB load) and never builds new ones.

## The rule-set cache

For "is this assertion a rule (vs. a GAF)?", there are two answer paths:

- **Flag bit**: bit 0 of `flags`. The default fast path. `assertion-flags-gaf-p` reads it.
- **Membership in `*rule-set*`**: a global set of every rule assertion. Used when `*prefer-rule-set-over-flags?*` is non-NIL.

The set exists because *iteration* over rules is a common-enough operation (every transformation tactician walks rules) that having an explicit container is faster than scanning every assertion and checking the flag. The set is built lazily on KB load (`load-rule-set-from-stream` reads it from a dedicated CFASL section) and maintained incrementally by `set-assertion-gaf-p`: when a flag flips, the set is updated to match.

`do-rules` iterates this set; `rule-count` returns its size. When the set is unbuilt, the iteration falls back to walking the assertion id-index and filtering on the flag.

## Indexing

Every assertion is reachable from every term it mentions, via the **term index**. The flow:

- `add-assertion-indices` — dispatches on `kb-gaf-assertion?` to either `add-gaf-indices` or `add-rule-indices`. Each picks a primary term (predicate for rules, arg1 for predicate-extent indexing, etc.) and registers the assertion under multiple keys (predicate-extent, gaf-arg-by-position, rule-by-pred, rule-by-isa, rule-by-genls, rule-by-genl-mt, rule-by-function, rule-by-exception, rule-by-pragma, …). See [kb-indexing.md](#) for the index taxonomy (planned doc).
- `remove-assertion-indices` — symmetric tear-down.

When an assertion is created, the indices are added in `connect-assertion`. When direction changes for a rule, the indices are torn down and rebuilt because the index buckets are direction-aware. When the assertion is removed, `disconnect-assertion` strips them.

The lookup primitive on top of the indices:

```
(find-assertion cnf mt)         ; eq MT match
(find-assertion-any-mt cnf)     ; in any MT
(find-gaf gaf-formula mt)       ; eq MT match, GAF-shaped formula
(find-gaf-any-mt gaf-formula)   ; in any MT, GAF-shaped formula
(find-gaf-in-relevant-mt gaf-formula)  ; under current *mt* / *relevant-mt-function*
```

These are bounded over the index buckets that contain the formula's most discriminating term. The per-shape mappers (`map-other-index`, `map-predicate-rule-index`, `map-isa-rule-index`, `map-genls-rule-index`, `map-genl-mt-rule-index`, `map-function-rule-index`, `map-exception-rule-index`, `map-pragma-rule-index`, etc.) are mostly `missing-larkc`, but the GAF lookup path (`find-gaf-internal` over `find-gaf-formula`) is intact.

### Assertion as meta-target: the assertion-index

Distinct from the term index, an assertion can itself be the *target* of meta-assertions. For example `(asserted-by SomeRule SomeCyclist)` is a meta-assertion whose subject is `SomeRule`. Each assertion's plist carries an `:index` slot — an index of all meta-assertions about it.

```
(assertion-index assertion)         ; lookup
(reset-assertion-index assertion i) ; mutation; rejects the empty simple-index sentinel
(assertion-has-meta-assertions? a)  ; bool — empty? check
```

In a clean rewrite this should be unified with the term index: an assertion is a term-like entity, and `(meta-assertions-for assertion)` is just `(term-index assertion)`. Currently the term index covers FORTs and the `:index` plist slot covers assertion subjects.

## CFASL serialization

See [cfasl.md](../persistence/cfasl.md). Opcode `*cfasl-opcode-assertion*` = 33. Assertions serialize **only by handle** (the recipe path is `missing-larkc 32166`) — the same constraint as NARTs. Cross-image dumps therefore require the dump-id table.

| Direction | Code path |
|---|---|
| Output | `cfasl-output-object-assertion-method` (currently missing-larkc) |
| Input | `cfasl-input-assertion` → `cfasl-input-assertion-handle` → `cfasl-assertion-handle-lookup` |

Handle lookup dispatches through `*cfasl-assertion-handle-lookup-func*`:

| Value | Use |
|---|---|
| `nil` or `'find-assertion-by-id` | normal in-image |
| `'find-assertion-by-dump-id` | KB load — translates dump IDs to current IDs |

`with-assertion-dump-id-table` binds both `*assertion-dump-id-table*` and `*cfasl-assertion-handle-func*` for the duration of a dump (for emit-side). The load side bindings are set in `kb-load-from-directory` directly.

Unknown ID resolves to `*sample-invalid-assertion*` — same fail-soft pattern as the constant/NART subsystems, and the same pattern flagged for replacement with a condition in the clean rewrite.

The **content** (`assertion-content`) is what actually flows over CFASL (formula-data, mt, flags, arguments, plist — five fields, one CFASL value each). `load-assertion-content` reads the five values in order and calls `load-assertion-content-int` to register them. The dump-side equivalents are all `missing-larkc` (`bundle-assertion-content`, `dump-assertion-content`, `dump-assertion-content-to-fht`).

## KB load / dump lifecycle

Mirror of NART/constant lifecycle:

1. **Setup** — `setup-assertion-table size exact?` allocates `*assertion-from-id*`. `setup-assertion-content-table size exact?` allocates `*assertion-content-manager*` with `load-assertion-def-from-cache` as the swap-in callback.
2. **Pre-allocate shells** — `initialize-assertion-shells assertion-count` mints handles 0..N-1 by calling `make-assertion-shell` in a loop, then `finalize-assertions assertion-count` records the next-id watermark.
3. **Load contents** — for each non-monolithic load, the file-backed cache lazy-loads on demand. For monolithic load, the assertion-def CFASL is streamed top-to-bottom and `load-assertion-def-from-cache` registers each content.
4. **Load rule-set** — `load-rule-set-from-stream` reads the dedicated rule-set CFASL.
5. **Bookkeeping** — `*tl-assertion-lookaside-table*` (transcript-level → HL assertion cache, capacity 5) is reinitialized.

`free-all-assertions` is the inverse: walks the id-index, frees every handle, clears both tables.

## Public API surface

The Cyc API exposes these (the ones marked **Cyc API** are registered with `register-cyc-api-function` and are part of the wire protocol):

### Identity / iteration

```
(assertion-p obj)                       ; Cyc API
(assertion-id assertion)                ; Cyc API
(find-assertion-by-id id)               ; Cyc API
(assertion-count)                       ; Cyc API
(do-assertions (var [progress] &key done) ...)  ; Cyc API macro
(do-rules (var &key progress done) ...)
(do-gafs (var &key progress done) ...)
(do-old-assertions / do-new-assertions)
```

### Content readers

```
(assertion-cnf assertion)               ; Cyc API — the CNF (synthesized for GAFs)
(possibly-assertion-cnf assertion)      ; nil if no content
(assertion-mt assertion)                ; Cyc API
(assertion-direction assertion)         ; Cyc API → :forward | :backward | :code
(assertion-truth assertion)             ; Cyc API → :true | :false | :unknown
(assertion-strength assertion)          ; Cyc API → :monotonic | :default | :unknown
(assertion-tv assertion)                ; fused (truth, strength)
(assertion-variable-names assertion)    ; Cyc API
(assertion-el-variables assertion)
(assertion-arguments assertion)         ; bookkeeping arguments
(assertion-dependents assertion)
(assertion-formula assertion)           ; Cyc API → an EL formula
(assertion-cons assertion)              ; Cyc API → CNF or GAF formula
(assertion-formula-data assertion)      ; HL representation directly
(assertion-hl-cnf assertion)            ; force-CNF
(assertion-clause-struc assertion)      ; if present
```

### GAF accessors

```
(gaf-assertion? assertion)              ; Cyc API
(gaf-formula assertion)                 ; the GAF literal
(gaf-hl-formula assertion)
(gaf-el-formula assertion)              ; with #$not for negated
(gaf-args assertion)
(gaf-arg assertion n)
(gaf-arg0 a) ... (gaf-arg5 a)           ; Cyc API
(gaf-predicate assertion)               ; Cyc API
```

### Type / state predicates

```
(assertion-type assertion)              ; :gaf | :rule
(assertion-has-type? a type)
(assertion-has-direction? a direction)  ; Cyc API: forward-assertion? backward-assertion? code-assertion?
(assertion-has-truth? a truth)          ; Cyc API
(rule-assertion? a)
(forward-assertion? a)                  ; Cyc API
(forward-rule? a)
(true-assertion? a)
(asserted-assertion? a)                 ; Cyc API
(deduced-assertion? a)                  ; Cyc API
(get-asserted-argument a)               ; Cyc API
(asserted-by/when/why/second a)         ; Cyc API
(assertion-has-meta-assertions? a)      ; Cyc API
(assertion-has-dependents-p a)          ; Cyc API
(valid-assertion? a) (invalid-assertion? a)
(valid-assertion-handle? a)
(valid-assertion-with-content? a)
(excepted-assertion? a)
(excepted-assertion-in-mt? a mt)
```

### Mutation entry points

```
(kb-create-assertion cnf mt)            ; Cyc API
(create-assertion cnf mt &optional var-names direction)
(find-or-create-assertion cnf mt &optional var-names direction)
(remove-assertion assertion)
(kb-remove-assertion assertion)         ; Cyc API
(kb-set-assertion-direction a new-dir)  ; Cyc API
(kb-set-assertion-truth a new-truth)    ; Cyc API
(kb-set-assertion-strength a new-strength) ; Cyc API
(kb-set-assertion-variable-names a names)  ; Cyc API
(kb-set-assertion-asserted-by/-when/-why/-second a value)  ; Cyc API
```

The `kb-` prefix marks the **HL-modifier**-wrapped layer that handles dispatch to remote-image vs local, locking, and write-side bookkeeping. Direct-mutation functions (`reset-assertion-tv`, `reset-assertion-flags`, `set-assertion-prop`) exist but are internal; a clean rewrite should not export them.

### Iteration helpers (callable from inference modules)

```
(do-assertion-arguments (arg-var assertion &key done) ...)
(do-assertion-dependents (deduction-var assertion &key done) ...)
(do-assertion-literals (lit-var assertion &key sense predicate done) ...)
(do-assertion-dependent-assertions (dep-assertion assertion) ...)
(do-assertion-supporting-assertions (sup-assertion assertion &key done) ...)
```

### Index / lookup (in `kb-indexing.lisp`)

```
(find-assertion cnf mt)
(find-assertion-any-mt cnf)             ; Cyc API
(find-gaf gaf-formula mt)
(find-gaf-any-mt gaf-formula)           ; Cyc API
(find-gaf-in-relevant-mt gaf-formula)
```

## Consumers

A non-exhaustive map of the systems that depend on the assertion API:

| Consumer | What it uses assertions for |
|---|---|
| **Inference (every backward worker)** | `assertion-cnf`, `assertion-mt`, `assertion-direction`, `assertion-truth`, `do-assertion-literals`, `assertion-arguments`, `assertion-dependents`. Each removal-module module reads the rule's CNF and walks term indices to apply it. |
| **Forward propagation** (`forward.lisp`) | `forward-assertion?`, `do-rules` filtered to forward, `assertion-cnf`, `assertion-mt`. |
| **Canonicalizer / WFF** | `find-assertion`, `find-or-create-assertion`, plus `update-assertion-formula-data` when a canonicalization rewrites a stored formula. |
| **TMS** (`tms.lisp`) | `tms-remove-assertion`, `tms-recompute-assertion-tv`, `assertion-arguments`, `add/remove-assertion-dependent`. |
| **KE / FI** (`ke.lisp`, `fi.lisp`) | `ke-assert-now`, `fi-assert` — public entry points that call `kb-create-assertion` after canonicalizing. |
| **HL Storage Modules** (`hl-storage-module-declarations.lisp`) | `kb-create-assertion`, `kb-remove-assertion` — generic store interface. |
| **Bookkeeping store** | `set-assertion-asserted-by/-when/-why/-second` after each successful assert. |
| **Dumper / KB load** (`dumper.lisp`) | `make-assertion-shell`, `finalize-assertions`, `load-assertion-content`, `load-assertion-def-from-cache`. |
| **CFASL** (`cfasl-kb-methods.lisp`) | `cfasl-input-assertion`, `cfasl-assertion-handle-lookup`. |
| **kb-indexing** | `add-assertion-indices`, `remove-assertion-indices`, `assertion-index`, `assertion-indexing-store-get/set`. |
| **kb-mapping** | `do-assertions`, `do-gafs`, `do-rules`, every `do-X-for-term` macro. |
| **Arguments / supports** (`arguments.lisp`) | `support-p`/`support-equal`/`support-<` treat `assertion-p` as a kind of support. `valid-support?` checks `valid-assertion?`. |
| **HL-supports** (`hl-supports.lisp`) | finds existing assertion via `find-assertion-internal` to attach a kb-hl-support. |
| **NART removal** (`narts-high.lisp`) | `tou-assertion?` GAFs are skipped during normal `tms-remove-assertion-int-2`; NART removal manages them directly. |

## Files

| File | Role |
|---|---|
| `assertion-handles.lisp` | struct, ID table, register/reset/find-by-id, iteration macros (`do-assertions`, `do-old-assertions`, `do-new-assertions`) |
| `assertions-low.lisp` | content struct, flags, formula-data, clause-struc dispatch, rule-set cache, `connect-assertion` / `disconnect-assertion`, plist-backed properties (assert-info, dependents, variable-names) |
| `assertions-high.lisp` | the public reader veneer (`define-valid-assertion-func` synthesizing each `kb-...` ↔ `assertion-...` pair), GAF accessors, `create-assertion`, `find-or-create-assertion`, `with-assertion-dump-id-table`, the iteration macros that wrap `do-assertions`, all Cyc API registrations |
| `assertions-interface.lisp` | the HL-modifier and HL-creator layer — dispatch to remote vs local, the synthesized `kb-set-assertion-*` modifier set, the synthesized `kb-assertion-*` reader set; this is the layer KE/FI talks to |
| `assertion-utilities.lisp` | derived predicates and helpers — `excepted-assertion?`, `do-rules`, `do-gafs`, `self-expanding-rule?`, `all-forward-rules-relevant-to-term`, `assertion-matches-type?`/-truth?/-direction?/-mt?, `gaf-assertion-with-pred-p`, `rule-literal-count` |
| `assertion-manager.lisp` | content swap layer — `*assertion-content-manager*` (kb-object-manager wrapper), `register/lookup/deregister-assertion-content`, LRU and Arete touch-tracking |

## Notes for a clean rewrite

- **Collapse the handle/content split** unless on-disk swapping is genuinely needed for memory pressure. With modern RAM the `kb-object-manager` LRU layer adds latency on every read for a benefit that doesn't materialize. If kept, hide it behind the same accessor names so the caller can't tell the difference.
- **Unify the indexing layers**. The term index, the per-assertion meta-index (`:index` plist), and the rule-set cache are three different data structures answering "what assertions match this filter". One graph-shaped index keyed on (term, role) would replace all of them.
- **Drop the clause-struc layer** unless rule sharing measurably matters. CL has trivial structural-hash interning, and rules are a tiny fraction of all assertions. The current scheme demands every consumer of `formula-data` peek through one level of indirection (`assertion-hl-cnf`) for negligible benefit.
- **Replace the obsolete `kb-` / non-`kb-` reader pairs**. Currently `assertion-cnf` calls `kb-assertion-cnf` calls `assertion-cnf-internal`. The Java pattern (`define-valid-assertion-func` + `define-kb-non-remote`) was a workaround for not having macro-expansions; in CL the public reader can be one defun.
- **Make `:assert-info` first-class.** Currently it's a 4-tuple in a plist, with four hand-rolled `set-asserted-X` setters. A struct (`assert-info` already exists at `(:type list)`) with proper accessors and a single `set-assert-info` mutator would simplify the bookkeeping API. Same for `:variable-names` (small list-of-strings) and `:dependents` (list-of-deductions) — all three are slot-shaped and forced into a plist only because the SubL compiler made plists cheap.
- **Replace `*sample-invalid-assertion*`** with a condition signaled at the lookup site. Same pattern as constants/NARTs.
- **`tou-assertion?`-skip in `tms-remove-assertion-int-2`** is a layering smell: the assertion-removal path knows about NART internals. A clean version: NARTs own their `(termOfUnit ...)` GAF, the GAF carries a flag bit "owned by external subsystem," and the TMS skips any owned-elsewhere assertion regardless of which subsystem owns it.
- **Direction as part of the assertion** is awkward — it's a *use-pattern marker* (does the engine fire this proactively or wait for queries?), not a property of the *assertion's content*. A cleaner design moves direction to a per-rule index: the same logical rule can be in the forward queue, the backward index, both, or neither, without being three different assertions.
- **Argument list polymorphism** (asserted-argument-token | deduction) should be a sealed sum type, not a flat list with `(if (asserted-argument-p x) ... (deduction-p x) ...)` everywhere. The number of callers that walk this list and dispatch on type is large.
- **Many of the currently-`missing-larkc` functions describe genuine engine behavior**: `assertion-mentions-term?`, `random-rule-mentioning`, `rules-mentioning`, `assertion-earlier?`, `assertion-info`, `gather-all-exception-rules`, `lifting-rule?`, `rule-has-unlabelled-dont-care-variable?`, etc. The clean rewrite must implement these because external clients (and the inference engine) rely on them; they aren't optional.
