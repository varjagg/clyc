# Deductions

A **deduction** is the KB's record of *one inference step that produced an assertion*. Concretely: "this assertion is true (with this truth/strength) because these supports together justify it." Deductions are the inference-built form of an `argument`; the other form is the **asserted-argument-token** (a small enum standing for "a cyclist asserted this directly with truth/strength X"). Together, a deduction and the asserted-argument tokens are the two kinds of thing that show up in `(assertion-arguments assertion)` — the per-assertion list of justifications.

Adding a deduction to its conclusion's argument list is what *commits* an inference: the conclusion now has a justification, the TMS will recompute its TV, and forward propagation kicks in.

Deductions are **first-class, ID-keyed, persisted KB objects**. They survive across image saves, they get their own CFASL opcode, they get their own LRU-fronted on-disk content store (mirror of the assertion architecture), and they have stable per-image integer IDs. This is unlike the asserted-argument-token, which is a flyweight keyword — the asserted form needs no identity because all "asserted, truth=:true, strength=:default" arguments are interchangeable, while every deduction is a distinct event.

## When does a deduction get created?

Not every rule firing makes one. There are exactly four situations that drive `kb-create-deduction`:

1. **A forward rule fires.** Forward inference exists *to* commit new conclusions to the KB. When a forward rule's antecedent matches, the body queues an `hl-assertible` carrying a `(:deduction . supports)` spec ([`handle-forward-deduction-in-mt-as-assertible-int`](../../../larkc-cycl/inference/harness/forward.lisp#L543)). When the queue drains, the conclusion-assertion and the deduction are minted together via `hl-deduce-as-kb-deduction` → `tms-add-deduction-for-cnf` → `tms-add-new-deduction` → `kb-create-deduction`. This is the workhorse path.

2. **A KE/FI client explicitly records a deduction.** `hl-add-argument` ([`hl-storage-module-declarations.lisp`](../../../larkc-cycl/hl-storage-module-declarations.lisp)) dispatches on the argument-spec type; `(:deduction . supports)` routes through the same `hl-deduce-as-kb-deduction` path as #1. This is how external tooling can persist a justification without going through inference at all — used by transcript replay, by the KE for explicit user-built deductions, and by any code that wants to *say* "this conclusion holds because of these supports" as a primary act.

3. **A `kb-hl-support` is created.** When an HL-level inference (a collection-level relationship, a meta-fact computed by an HL module — *not* a CycL rule firing) gets reified into the KB, its initial justification is a deduction whose conclusion *is* the kb-hl-support. Entry: `create-deduction-for-hl-support` from `kb-hl-supports.lisp`.

4. **TMS-driven inference inside argument processing.** Internal flows like `tms-recompute-assertion-tv` may call `tms-add-new-deduction` directly when re-justifying an assertion under updated supports. This is rare — most TMS work is *removal* of stale arguments, not creation of new ones — but the entry exists.

**Backward-rule firings during query execution do NOT create deductions.** A backward worker fires a rule, walks the antecedent, finds bindings, and returns answers up the strategy tree. The transient justification is built in `proof` / `problem-link` datastructures inside the inference run, then discarded when the run finishes. The query result is a list of variable bindings; no KB state changes.

The framework anticipates query-driven persistence — `tms-reprove-deduction-query-sentence`, `tms-reprove-deduction-query-mt`, `tms-reprove-deduction-query-properties` are declared but LarKC-stripped (commented `declareFunction`s in [tms.lisp:301-303](../../../larkc-cycl/tms.lisp#L301-L303)). The intent: an answer-caching mode that, after a query completes, takes the proof tree and persists the conclusion as an assertion plus a deduction so the same query is fast next time, plus the cached answer can later be *re-proved* if any of its supports change. The clean rewrite needs to support this; the current port does not.

Distinction worth keeping in mind: `kb-create-assertion` (which makes a *new fact*) and `kb-create-deduction` (which adds a *justification* for an existing fact) are independent. A successful `ke-assert` makes the assertion plus an asserted-argument-token, no deduction. A forward rule firing makes a deduction; if the conclusion-assertion didn't already exist, it makes that too. A backward query makes neither.

## Terminology

- **Conclusion / assertion** of the deduction: the assertion this deduction *justifies*. The deduction's `assertion` slot. Almost always an `assertion`, but the slot also accepts an `hl-support` (transient, in-flight justification) or `kb-hl-support` (a reified hl-support stored in the KB). When the conclusion is a `kb-hl-support`, the same justification machinery applies but the dependent-pointer goes through `kb-hl-support-add-dependent` instead of `add-assertion-dependent`.
- **Supports**: the list of `support`-typed objects (assertion | kb-hl-support | hl-support) used by this deduction. The conjunction of their truths produces the conclusion. Stored canonicalized — sorted via `support-<` so two equivalent deductions canonicalize to the same supports list.
- **TV**: a fused (truth, strength) pair, same encoding as on assertions.
- **Argument** (in the bookkeeping sense): a deduction *or* an asserted-argument-token. Both implement the small protocol used by the TMS — `argument-truth`, `argument-tv`, `argument-strength`, `valid-argument`, `remove-argument`. See [the assertions doc](assertions.md#terminology) for the dual sense ("argument" also means "predicate parameter").
- **Dependent**: the inverse pointer. A deduction is *added to* its assertion's argument list (so the assertion has a justification). At the same time, the deduction is *registered as a dependent* on each of its supports (so removing a support cascades to invalidate this deduction). The two pointers are kept in sync by `add-deduction-dependents` / `remove-deduction-dependents`.
- **Justification**: a synonym for the supports list as a value. `hl-justification-p` is the predicate; `non-empty-hl-justification-p` is the version that excludes the empty list. Shows up in API signatures (`(supports hl-justification-p)`).
- **Deduction-spec**: a transient cons `(:deduction . canonicalized-supports)` used to *pass a planned deduction* through the forward-propagation pipeline before the conclusion has been canonicalized into an assertion. See [the forward-propagation use](#forward-propagation).

## Data structure

### Handle struct

```lisp
(defstruct (deduction (:conc-name "D-"))
  id)
```

Same minimal handle pattern as `constant`, `nart`, and `assertion`. The handle is identity; everything else lives in the content. `free-deduction` invalidates by NIL-ing the ID; `deduction-handle-valid?` is just `(d-id deduction)` (currently, though the field's invariant is integer-or-NIL — there is a TODO acknowledging this should check `integerp`). `valid-deduction?` defaults to handle-validity only; the `robust?` flag also walks every support and checks each is `valid-support?`, plus checks that the conclusion-assertion is itself valid.

`make-deduction-shell` mints a new ID (or accepts an externally provided one) and registers it in `*deduction-from-id*`.

### Content struct

```lisp
(defstruct (deduction-content (:conc-name "D-CONTENT-"))
  tv
  assertion
  supports)
```

Three slots — much smaller than `assertion-content` because deductions don't carry direction, MT, plist, or arguments-of-their-own. The `tv` is the fused truth/strength of *this deduction's conclusion* (which need not equal the assertion's overall TV — the assertion's TV is the recomputed combination of all its arguments, while each deduction has its own TV).

The content struct is allocated by `create-deduction-content id assertion supports`, which initializes `tv` to `:unknown` and registers the content in `*deduction-content-manager*`. `kb-create-deduction-int` then immediately overwrites the TV via `reset-deduction-tv` to the actual value derived from the requested truth+strength.

There is no flag-bit packing on deductions. The TV is stored as a keyword, not a bitfield — the rationale would be that deductions are far less numerous than assertions, so the per-object savings don't matter, and the read-path simplicity does.

## Identifier space

Deductions use a single per-image integer ID. **No GUID.** Like NARTs and assertions, identity is local to the image; cross-image transport is by handle plus a dump-id table.

```
ID  → deduction              *deduction-from-id*           (id-index)
ID  → deduction-content      *deduction-content-manager*   (LRU + on-disk file-vector, "deduction" / "deduction-index")
```

`*deduction-content-manager*` uses `*deduction-lru-size-percentage*` = 8 (half of assertions; the comment notes this is a guess based on the assertion ratio). Deduction content is loaded from the `deduction` CFASL file via `load-deduction-def-from-cache` on cache miss.

The transient dump-id table:

```lisp
*deduction-dump-id-table*               ; hash IDs at-time-of-dump → current handle
*cfasl-deduction-handle-lookup-func*    ; on load: ID-rewrite function
```

There is no `with-deduction-dump-id-table` macro paralleling `with-assertion-dump-id-table` — emit-side dump rebinding for deductions is not exposed (the dump-side functions are LarKC-stripped). The load-side rebinding is set in `kb-load-from-directory` directly alongside the assertion / nart / constant / kb-hl-support / clause-struc lookup functions, so KB load works.

## Lifecycle

### Birth

The triggering situations are listed in [When does a deduction get created?](#when-does-a-deduction-get-created) above. All four routes converge on `kb-create-deduction` (an `hl-creator`-wrapped function). The flow:

1. Routes to `kb-create-deduction-local` (or remote-image: `missing-larkc 32156`).
2. `kb-create-deduction-kb-store assertion supports truth` — mint a new ID, allocate a shell, call `kb-create-deduction-int`.
3. `kb-create-deduction-int`:
   - Compute the TV from `(truth, :default)`.
   - Allocate the content with `create-deduction-content` and store it in the manager.
   - Set the TV on the new shell via `reset-deduction-tv`.
   - **If the conclusion is an `assertion`**, register the deduction as one of that assertion's arguments via `add-new-assertion-argument`. (If it's an `hl-support`/`kb-hl-support`, this step is skipped here; the kb-hl-support is its own subsystem.)
   - **For each support**, register the new deduction as a dependent of the support — `add-assertion-dependent` for an assertion-support, `kb-hl-support-add-dependent` for a kb-hl-support. This is the back-pointer that lets the TMS find this deduction when the support is later removed.

The deduction is now wired into both directions of the dependency graph: the conclusion knows it has a new justification, and every support knows it has a new dependent.

### Mutation

The only mutating operation on an existing deduction is **strength change**: `kb-set-deduction-strength` (HL-modifier wrapped) → `kb-set-deduction-strength-internal` → `reset-deduction-tv` with the recomputed TV. Truth is not mutable separately; if a deduction's truth needs to change, it is removed and re-created with the new value.

There is no mutation API for the supports list or the conclusion-assertion. A deduction's supports are immutable for its lifetime — if the rule firing changes (different supports, different bindings), it's a different deduction.

### Death

Removal is initiated when **a support becomes invalid** (TMS cascade) or when the deduction's conclusion is being removed. The path:

1. `tms-remove-argument argument assertion` — generic argument-removal wrapper. Notes the argument as being-removed (so reentry can short-circuit), then calls `remove-argument`, which dispatches: if the argument is a `belief` (asserted-argument-token), do `remove-belief`; otherwise (a deduction), `kb-remove-deduction`.
2. `kb-remove-deduction deduction` (HL-modifier wrapped):
   - `remove-deduction-dependents` — for each support, unregister the deduction as a dependent. Asymmetric with `add-deduction-dependents`: this version checks `valid-assertion?` / `valid-kb-hl-support?` first because the support might *also* be in the middle of being removed, and we don't want to error trying to mutate a half-deconstructed support.
   - For the conclusion-assertion: if it's still valid, remove the deduction from its argument list via `remove-assertion-argument`.
   - For an `hl-support` conclusion: locate the corresponding `kb-hl-support` and call `missing-larkc 11044` (the equivalent of `remove-assertion-argument` for kb-hl-supports).
   - `kb-remove-deduction-internal`:
     - `destroy-deduction-content id` — NIL out tv/assertion/supports slots, deregister from the content manager.
     - `deregister-deduction-id id` — remove from the id-index.
     - `free-deduction deduction` — NIL the handle's ID.
3. The TMS then calls `tms-propagate-removed-argument` on the (now-orphan) deduction's conclusion-assertion to recompute its TV; if no arguments remain, the assertion itself is removed (which cascades through every other deduction whose conclusion was that assertion).

`free-all-deductions` is the global teardown: walk the id-index, free every handle, clear both tables.

## Identity-by-content lookup

Two deductions are equal if they justify the same conclusion via the same set of supports with the same truth. `find-deduction assertion supports &optional truth` is the query primitive; it dispatches through `kb-lookup-deduction` to `find-deduction-internal`:

- For an `assertion` conclusion: walk `(assertion-arguments assertion)`, ignoring the asserted-argument-tokens, and check each `deduction-p` argument with `deduction-matches-specification` (assertion equal, truth eq, supports set-equal via `support-equal`).
- For a `kb-hl-support` conclusion: `missing-larkc 11006`.

`deduction-supports-equal` is the set-equality predicate over supports lists, length-checked first.

The lookup is O(arguments-of-assertion). The supports list is canonicalized and sorted at deduction creation time, so a hash-based identity index could be added; currently there is none.

## Forward propagation

Forward inference creates deductions through a deferred path because the conclusion does not exist yet at firing time. Concrete sequence inside `handle-forward-deduction-in-mt-as-assertible-int`:

```lisp
(let* ((deduction-spec (create-deduction-spec supports))         ; (:deduction . canon-supports)
       (hl-assertion-spec (new-hl-assertion-spec cnf mt :forward variable-map))
       (hl-assertible (new-hl-assertible hl-assertion-spec deduction-spec)))
  (note-new-forward-assertible hl-assertible))
```

The `create-deduction-spec` doesn't create a deduction; it canonicalizes the supports list and tags it with `:deduction`. The full deduction is materialized later, when the queued `hl-assertible` is processed and the canonicalized CNF has been turned into a real assertion. At that point the spec's supports plus the new assertion plus a truth value are passed to `kb-create-deduction`, the deduction lands in the assertion's argument list, and forward propagation continues.

`deduction-spec-supports` extracts the supports back out of a spec. The spec's `:deduction` keyword distinguishes it from a kb-hl-support-spec (or any other future justification kind that the forward queue might carry).

## CFASL serialization

See [cfasl.md](../persistence/cfasl.md). Opcode `*cfasl-opcode-deduction*` = 36. Like assertions and NARTs, deductions serialize **only by handle** — the recipe path (`cfasl-output-deduction-recipe`, `cfasl-output-deduction-handle`) is LarKC-stripped, and the immediate `cfasl-output-object-deduction-method` is `missing-larkc 32182`.

| Direction | Code path |
|---|---|
| Output | `cfasl-output-object-deduction-method` (currently missing-larkc) |
| Input | `cfasl-input-deduction` → `cfasl-input-deduction-handle` → `cfasl-deduction-handle-lookup` |

Handle lookup dispatches through `*cfasl-deduction-handle-lookup-func*`:

| Value | Use |
|---|---|
| `nil` or `'find-deduction-by-id` | normal in-image |
| `'find-deduction-by-dump-id` | KB load — translates dump IDs to current IDs |

Unknown ID resolves to `*sample-invalid-deduction*` — same fail-soft pattern as constants/NARTs/assertions, same flag for replacement with a condition in the clean rewrite.

The **content** (`deduction-content`) flows over CFASL as three values: `tv`, `assertion`, `supports`, in that order. `load-deduction-content` reads them and calls `load-deduction-content-int` to register. Note the assertion field's CFASL value is *itself* an assertion handle, so loading deduction content depends on the conclusion-assertion already existing — this ordering constraint is satisfied because `load-essential-kb` loads assertion shells before deduction defs.

## KB load / dump lifecycle

Mirror of NART/constant/assertion lifecycle:

1. **Setup** — `setup-deduction-table size exact?` allocates `*deduction-from-id*`. `setup-deduction-content-table size exact?` allocates `*deduction-content-manager*`.
2. **Pre-allocate shells** — `load-deduction-defs` either lazy-loads via the file-backed cache (default for non-monolithic), or eagerly streams every deduction-def from the CFASL: for each dump-id read, `make-deduction-shell dump-id` mints the shell, then `load-deduction-def dump-id stream` reads and registers the content.
3. `finalize-deductions deduction-count` records the next-id watermark.

`free-all-deductions` is the inverse.

## Public API surface

### Identity / iteration

```
(deduction-p obj)                       ; Cyc API
(deduction-id deduction)                ; Cyc API
(find-deduction-by-id id)               ; Cyc API
(deduction-count)                       ; Cyc API
(do-deductions (var [progress] &key done) ...)  ; Cyc API macro
```

### Content readers

```
(deduction-assertion deduction)         ; Cyc API → support-p (the conclusion)
(deduction-supports deduction)          ; the list of supports — possibly-unreify-kb-hl-supports applied
(deduction-truth deduction)             ; Cyc API → :true | :false | :unknown
(deduction-strength deduction)          ; Cyc API → :monotonic | :default | :unknown
(deduction-tv deduction)                ; fused (truth, strength)
```

`deduction-assertion`, `deduction-supports`, `deduction-truth`, and `deduction-strength` all guard with `deduction-handle-valid?` — calling on an invalid handle returns NIL (or `:unknown` for `deduction-truth`) rather than signalling. This matches the assertions pattern.

`deduction-supports` post-processes the stored list with `possibly-unreify-kb-hl-supports`, which looks up any `kb-hl-support` and returns it as the equivalent `hl-support` 4-tuple if that's what the caller is expecting. This is a layering smell — the storage form is `kb-hl-support` (compact handle), and consumers that want the unreified hl-support 4-tuple force this read at every access.

### Mutation entry points

```
(create-deduction assertion supports truth)              ; thin wrapper around kb-create-deduction
(create-deduction-with-tv assertion supports tv)         ; create + immediately set strength
(create-deduction-for-hl-support hl-support justification)
(kb-create-deduction assertion supports truth)           ; Cyc API — HL-creator wrapped
(remove-deduction deduction)
(kb-remove-deduction deduction)                          ; Cyc API — HL-modifier wrapped
(set-deduction-strength d new-strength)
(kb-set-deduction-strength d new-strength)               ; Cyc API
(find-deduction assertion supports &optional truth)      ; identity-by-content lookup
(kb-lookup-deduction assertion supports truth)           ; Cyc API
```

### Bookkeeping helpers (internal)

```
(add-deduction-dependents deduction)        ; called from kb-create-deduction-int
(remove-deduction-dependents deduction)     ; called from kb-remove-deduction
(deduction-supports-internal deduction)     ; bypasses possibly-unreify-kb-hl-supports
(deduction-supports-equal supports1 supports2)
(create-deduction-spec supports)            ; used by forward propagation
(deduction-spec-supports spec)
```

### Iteration helpers

`do-deduction-supports` — declared in the Java but the body is stripped in the LarKC drop. The expansion is a `do-list` over `deduction-supports` (it appears in `assertion-utilities.lisp`'s call sites: `(do-deduction-supports (supporting-assertion argument :done done) ...)`).

## Consumers

| Consumer | What it uses deductions for |
|---|---|
| **Assertions** (`assertions-low.lisp`, `assertions-high.lisp`) | `(assertion-arguments assertion)` is the canonical container of deductions; `(assertion-dependents assertion)` is the inverse pointer (deductions whose supports include this assertion). Iterators `do-assertion-arguments`, `do-assertion-dependents`, `do-assertion-supporting-assertions`, `do-assertion-dependent-assertions` walk these. |
| **TMS** (`tms.lisp`) | `tms-add-new-deduction` (creates deductions for inferred conclusions), `tms-remove-argument` (dispatches `kb-remove-deduction` for deduction args), `tms-propagate-removed-argument` (cascades via the dependent list). |
| **Forward propagation** (`inference/harness/forward.lisp`) | `create-deduction-spec` to defer materialization until canonicalization completes; `handle-forward-deduction-in-mt-as-assertible-int` is the integration point. |
| **Backward inference** (`backward.lisp` and the per-strategy workers) | When a query produces a new conclusion that should be cached, the TMS path creates a deduction. The strategy/tactician code does not name `deduction` directly; it goes through the assertion-creation path, which adds the asserted-argument or deduction depending on the source. |
| **kb-hl-supports** (`kb-hl-supports.lisp`) | `create-deduction-for-hl-support` is the constructor for kb-hl-support's initial justification; `kb-hl-support-add-dependent` / `kb-hl-support-remove-dependent` are the symmetric of `add-assertion-dependent`. |
| **arguments.lisp** | `argument-truth`, `argument-tv`, `argument-strength`, `valid-argument`, `support-p`, `support-<` — the polymorphic argument/support API treats `deduction` as one of three support kinds. `support-justification` for an assertion returns `(list assertion)`; for a kb-hl-support delegates; for an hl-support delegates to `hl-support-justify`. |
| **Argumentation** (`inference/harness/argumentation.lisp`) | `compute-deduction-tv` is declared but missing-larkc — the design is for argumentation to recompute a deduction's TV given the current TVs of its supports (e.g. when one support's strength changes from `:monotonic` to `:default`, the deduction's strength must recompute too). |
| **Dumper / KB load** (`dumper.lisp`) | `make-deduction-shell`, `finalize-deductions`, `load-deduction-def`, `load-deduction-defs`. |
| **CFASL** (`cfasl-kb-methods.lisp`) | `cfasl-input-deduction`, `cfasl-deduction-handle-lookup`. |
| **assertion-utilities** | `deduction-forward-rule-supports` filters supports to the forward-rule subset for the `all-forward-rules-relevant-to-term` traversal. |

## Files

| File | Role |
|---|---|
| `deduction-handles.lisp` | struct, ID table, register/reset/find-by-id, `valid-deduction?`, `make-deduction-shell` |
| `deductions-low.lisp` | content struct, content lookup/register/destroy, `kb-create-deduction-int` (the actual creation logic), `kb-remove-deduction-internal`, `add-deduction-dependents`/`remove-deduction-dependents`, `find-deduction-internal`, `deduction-matches-specification` |
| `deductions-high.lisp` | public veneer — `create-deduction-spec`, `create-deduction-with-tv`, `create-deduction-for-hl-support`, `find-deduction`, `deduction-supports` (with kb-hl-support unreification), Cyc API registrations |
| `deductions-interface.lisp` | the HL-creator/HL-modifier wrappers — `kb-create-deduction`, `kb-remove-deduction`, `kb-lookup-deduction`, `kb-deduction-assertion`/`-supports`/`-truth`/`-strength`, `kb-set-deduction-strength` |
| `deduction-manager.lisp` | content swap layer — `*deduction-content-manager*` (kb-object-manager wrapper), `register/lookup/deregister-deduction-content`, LRU |

## Notes for a clean rewrite

- **Collapse the handle/content split** unless on-disk swapping demonstrably helps. With the assertion machinery already inheriting the same pattern and the same critique, a unified decision should be made. Deduction content is only three values; the per-deduction memory is small enough that swapping out is rarely worth the indirection.
- **Sealed sum type for `argument`** — the dispatch `(if (asserted-argument-p x) ... (deduction-p x) ...)` appears everywhere a TMS path walks an argument list. A two-variant sum (`asserted` carrying just a TV keyword, `deduced` carrying a deduction) makes the dispatch syntactic, not runtime.
- **Sealed sum type for `support`** — same critique. The `(cond (assertion-p ...) (kb-hl-support-p ...) (hl-support-p ...))` pattern shows up in `support-module`, `support-sentence`, `support-mt`, `support-justification`, `support-tv`, `valid-support?`, `support-<`, `support-equal` — it's the same dispatch every time. A polymorphic `support` type with three variants and a small protocol replaces all of these.
- **`possibly-unreify-kb-hl-supports` should not be in the read path.** Either store hl-supports in their unreified form (and pay the lookup cost on writes when registering with kb-hl-support indexes), or store them as kb-hl-supports and force consumers that want the 4-tuple to call the converter explicitly. Doing it on every `deduction-supports` read is silently expensive and inverts the optimization (kb-hl-support's whole point is being more compact than the hl-support 4-tuple).
- **Replace `*sample-invalid-deduction*`** with a condition signaled at the lookup site. Same pattern as constants/NARTs/assertions.
- **The `(:deduction . supports)` deduction-spec is a cons-tagged variant.** A struct or sum-type variant would be self-documenting and let the forward queue carry future kinds (e.g. `(:kb-hl-support-justification ...)`) cleanly.
- **`compute-deduction-tv` (currently missing-larkc) is required for correct argumentation.** A deduction's TV cannot be a static field if the underlying supports' TVs can change — the value should be recomputed on demand from the current supports' TVs (per `argumentation.lisp`'s design), and the stored `tv` slot becomes a cache. Cache invalidation is then driven by support-TV-change events.
- **Identity-by-content lookup is O(arguments-of-assertion).** For assertions with many deductions (e.g. a heavily-deduced GAF), this dominates. A content-keyed hash-table mapping `(conclusion, sorted-supports, truth) → deduction` would give O(1) lookup at minor memory cost; canonicalization already sorts the supports.
- **`deduction-handle-valid?` checks `d-id`, but the field's invariant is integer-or-NIL.** The current implementation returns NIL or the integer (truthy on integer, falsy on NIL). A future change of the field's domain would silently miscompute — `(integerp (d-id deduction))` is the documented intent and should replace the current implementation. (There's already a TODO marking this.)
- **Asymmetric `add-`/`remove-deduction-dependents`.** The remove version checks each support's validity; the add version doesn't. The asymmetry is intentional (when adding, all supports just passed `valid-support?` in the creator), but a clean rewrite should make them symmetric or document the precondition explicitly.
- **The conclusion slot accepts three types** (assertion | kb-hl-support | hl-support). In practice the hl-support case is transient — a kb-hl-support is found or created and the slot is updated. The clean type can shrink to two variants.
