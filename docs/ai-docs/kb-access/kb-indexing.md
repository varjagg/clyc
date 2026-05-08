# KB indexing

The KB indexing system answers a single question fast: *given a term, which assertions mention it, in which role?* Every term that occurs in any assertion carries a per-term index — a structure mapping role-keys (`:gaf-arg`, `:predicate-extent`, `:predicate-rule`, …) to the set of assertions where the term plays that role. The indexing layer is **derivable** (you could rebuild it from scratch by re-asserting every assertion) but expensive enough to warrant on-disk persistence.

Two index shapes coexist for the same term:

- **Simple index** — a flat list of every assertion mentioning the term, no role distinction. Used when the term has fewer than ~20 assertions; saves memory and is O(N) to scan exhaustively. Filtering by role is done at scan time using `matches-<role>-index` predicates.
- **Complex index** — a four-level nested hash (`role → arg1 → arg2 → arg3 → leaf-set`), one branch per role. Used when the term has many assertions; gives O(1) access to each role's assertion set at the cost of structural overhead per term.

A given term flips between simple and complex as it grows or shrinks past the toggle thresholds. The flip is **deferred** until the end of the surrounding update batch (see [Index-mode toggling](#index-mode-toggling)).

## When does a term acquire an index?

The term-index is a slot inside the term's content-struct (see [constants.md](../core-kb/constants.md), [narts.md](../core-kb/narts.md), [`unrepresented-terms.lisp`](../../../larkc-cycl/unrepresented-terms.lisp)) — the moment the term is created, an empty simple index (literally `nil`) is allocated alongside it. There is no separate "register this term with the indexing system" step.

The index becomes non-empty as soon as an assertion mentioning the term is added. There are exactly two situations:

1. **An assertion is asserted into the KB.** `kb-create-assertion` (or any of its callers — `assert-cnf`, the canonicalizer, KB load) eventually calls `add-assertion-indices assertion`, which dispatches to either `add-gaf-indices` (for GAFs) or `add-rule-indices` (for rules). These walk every term mentioned in the formula/CNF and call `term-add-indexing-leaf term role-keys assertion` for each `(term, role)` pair.

2. **A reindex is requested.** `reindex-assertion`, `reindex-all-term-assertions`, `reindex-all-assertions` (currently `missing-larkc`) re-derive the indices for an assertion or term. This is normally called after a structural change to the assertion, or once at end of KB load to ensure consistency.

The inverse — `remove-assertion-indices` / `remove-rule-indices` / `remove-gaf-indices` — runs whenever an assertion is invalidated.

A term whose index becomes empty does *not* automatically delete the term — index emptiness is independent of term lifecycle. But `remove-term-indices term` is the path to "delete every assertion mentioning this term" and is part of the term-removal cascade.

## Index roles

A term's index is partitioned by **role** — the way the term participates in each indexed assertion. Each role corresponds to a top-level key in the complex index:

| Role key | Role | Indexed term | Sub-keys |
|---|---|---|---|
| `:gaf-arg` | The term appears at argnum N of a GAF | the term | `argnum`, `pred`, `mt` |
| `:nart-arg` | The term appears in arg N of a `(#$termOfUnit nart (func . args))` GAF | the term inside the NAUT | `argnum`, `func` |
| `:predicate-extent` | The term *is* the predicate of a GAF | the predicate | `mt` |
| `:function-extent` | The term *is* the functor of a `#$termOfUnit` GAF | the functor | (mt-keyed via dedicated subindex) |
| `:predicate-rule` | The term is a predicate appearing in a rule literal | the predicate | `sense`, `mt`, `direction` |
| `:decontextualized-ist-predicate-rule` | Predicate inside an `ist` literal in a decontextualized rule | the predicate | `sense`, `direction` |
| `:isa-rule` | Collection appearing as arg2 of `#$isa` in a rule literal | the collection | `sense`, `mt`, `direction` |
| `:quoted-isa-rule` | Collection appearing as arg2 of `#$quotedIsa` in a rule | the collection | `sense`, `mt`, `direction` |
| `:genls-rule` | Collection appearing as arg2 of `#$genls` in a rule | the collection | `sense`, `mt`, `direction` |
| `:genl-mt-rule` | MT appearing as arg2 of `#$genlMt` in a rule | the MT | `sense`, `mt`, `direction` |
| `:function-rule` | Function appearing in a `(not (termOfUnit … (func …)))` neg-lit | the function | `mt`, `direction` |
| `:exception-rule` | Rule cited in a `#$abnormal` pos-lit | the cited rule | `mt`, `direction` |
| `:pragma-rule` | Rule cited in a `#$meetsPragmaticRequirement` pos-lit | the cited rule | `mt`, `direction` |
| `:ist` (mt-index) | The term is the MT of any assertion | the MT | (no further sub-key) |
| `:other` | The term is mentioned in the assertion's CNF or MT but matches no specialized role | the term | (no further sub-key) |

A single assertion typically registers under several roles for several terms — e.g. a GAF `(#$isa #$Fido #$Dog)` registers under `:gaf-arg/1/#$isa/MT` for `#$Fido`, `:gaf-arg/2/#$isa/MT` for `#$Dog`, `:isa-rule`-related sub-keys do *not* fire for GAFs, but `:predicate-extent/MT` fires for `#$isa` and `:ist` fires for the MT itself.

The `:other` role is the catch-all for terms that *are* referenced (per `tree-gather` over the formula or MT) but not via any specialized role. It exists so that `remove-term-indices` can find every assertion mentioning a term, including those where the term appears nested inside a NAUT or string. Specialized roles take precedence — a term is registered under `:other` only if `matches-<role>` reports false for every other role.

The **unindexed-syntax-constants** (`#$implies`, `#$and`, `#$or`, `#$not`) bypass indexing entirely. Their occurrences would dominate every bucket and they never participate in interesting lookups; `unindexed-syntax-constant-p` short-circuits.

## Per-role indexing depth

Each role is a separate sub-tree under the term's complex index, with a fixed key path:

```
term-index
├── :gaf-arg → {argnum → {pred → {mt → leaf-set}}}
├── :nart-arg → {argnum → {func → leaf-set}}
├── :predicate-extent → {mt → leaf-set}
├── :predicate-rule → {sense → {mt → {direction → leaf-set}}}
├── :decontextualized-ist-predicate-rule → {sense → {direction → leaf-set}}
├── :isa-rule → {sense → {mt → {direction → leaf-set}}}
├── :quoted-isa-rule → {sense → {mt → {direction → leaf-set}}}
├── :genls-rule → {sense → {mt → {direction → leaf-set}}}
├── :genl-mt-rule → {sense → {mt → {direction → leaf-set}}}
├── :function-rule → {mt → {direction → leaf-set}}
├── :exception-rule → {mt → {direction → leaf-set}}
├── :pragma-rule → {mt → {direction → leaf-set}}
├── :ist → leaf-set (the MT-index)
└── :other → leaf-set
```

Each level is an `intermediate-index` (counted hash). The deepest level is a `final-index` (a `set` of assertions) — except `:ist` and `:other`, which have leaf-set directly under the role key.

## Data structures

### simple-index

A bare list of assertions: `(a1 a2 a3 ...)`. The term-index slot holds the list directly. `new-simple-index` returns `nil`. `simple-indexed-term-p term` is `(simple-index-p (term-index term))`.

Operations are linear scans:

- **Add**: `(add-simple-index term assertion)` does `(adjoin assertion list)` — eq-comparison membership.
- **Remove**: `(rem-simple-index term assertion)` does `(delete-first assertion list)`.
- **Count by role**: every `num-<role>-index` falls back to a linear scan calling `matches-<role>-index assertion …` on every list element.
- **Count keys at next level**: `key-<role>-index` similarly walks every assertion calling a `simple-key-<role>-index` accumulator.

The `matches-<role>-index` predicates ([`simple-indexing.lisp`](../../../larkc-cycl/simple-indexing.lisp)) inspect the assertion's CNF to decide whether it belongs to the role at the requested sub-keys. They are the only thing distinguishing simple-index roles at lookup time.

### intermediate-index

A counted dictionary: `(leaf-count . hashtable)`. The leaf count is the number of leaf assertions anywhere below this node, used to short-circuit empty branches and to detect when to convert back to a simple index.

```
(intermediate-index-p obj) ≡ (and (consp obj)
                                   (integerp (car obj))
                                   (hash-table-p (cdr obj)))
(new-intermediate-index test) ≡ (cons 0 (make-hash-table :test test))
(intermediate-index-leaf-count ii) ≡ (car ii)
(intermediate-index-dictionary ii) ≡ (cdr ii)
```

`intermediate-index-insert ii keys leaf` walks the keys list, creating intermediate-indices along the way (with the per-level equality test from the index declaration), and inserts `leaf` into the bottom final-index. Returns t iff the leaf was newly added; if so, every level on the path increments its leaf-count. Mirrors for `intermediate-index-delete`, including cleanup-trickle-up: when a subindex's leaf-count hits zero, its parent removes the key entirely.

Each level's hash test is determined by `index-equality-test-for-keys keys` ([`kb-indexing-declarations.lisp:73`](../../../larkc-cycl/kb-indexing-declarations.lisp#L73)) — a lookup against the `*kb-indexing-declaration-store*` plist of the index's top-level role. `:eq` is the default; some roles use `:equal` for HLMT keys.

### final-index

A `set` of assertions. The set is keyed `eq`. `final-index-insert/delete` are direct passthrough to set ops.

### Term-index slot

The slot lives inside the term's content struct, not as a separate registry:

| Term type | Holder | Accessor |
|---|---|---|
| Constant | `*constant-index-manager*` (LRU) | `constant-index` / `reset-fort-index` |
| NART | `*nart-index-manager*` (LRU) | `nart-index` |
| Assertion | the assertion's content struct | `assertion-index` |
| Unrepresented term | `*unrepresented-term-index-manager*` (LRU) | `unrepresented-term-index` |
| Auxiliary index | the auxiliary-index struct itself | `get-auxiliary-index` |

`term-index term` ([`kb-indexing-datastructures.lisp:114`](../../../larkc-cycl/kb-indexing-datastructures.lisp#L114)) dispatches on term type and returns the slot value. `reset-term-index term index` writes back. The dispatch is essentially the *index ownership polymorphism*: any term-like object that wants to be indexed implements both readers.

## Index-mode toggling

The simple↔complex transition is gated on assertion count:

| Constant | Value | Meaning |
|---|---|---|
| `*index-convert-threshold*` | 20 | nominal flip point |
| `*index-convert-range*` | 4 | hysteresis band |
| `*index-convert-complex-threshold*` | 22 | simple → complex if count ≥ this |
| `*index-convert-simple-threshold*` | 18 | complex → simple if count ≤ this |

The hysteresis avoids thrashing when the term oscillates around the threshold.

The toggle is **deferred**. Every mutating operation runs inside a `noting-terms-to-toggle-indexing-mode` macro wrapper, which dynamically binds `*within-noting-terms-to-toggle-indexing-mode* = t` and `*terms-to-toggle-indexing-mode* = nil`. Inside, every `term-add-indexing-leaf` / `term-rem-indexing-leaf` calls `mark-term-index-as-muted` (notifying the LRU manager that the index slot is dirty); after the inner work, `possibly-toggle-term-index-mode term` checks the new count against the threshold and `pushnew`s the term into the deferred list. When the wrapper exits, every queued term gets `toggle-term-index-mode` (which calls `convert-to-complex-index` or `convert-to-simple-index`).

This batching is what lets `add-assertion-indices` and `remove-assertion-indices` register many leaves on many terms while never converting an index more than once per call.

`mark-term-index-as-muted` is the dirty-bit. It dispatches on term type and marks the corresponding LRU manager slot dirty so the subsequent persistence flush writes the new index. NARTs go through `missing-larkc 30874` (clean rewrite must implement parallel to the constant branch).

## Index declaration store

`*kb-indexing-declaration-store*` ([`kb-indexing-declarations.lisp:41`](../../../larkc-cycl/kb-indexing-declarations.lisp#L41)) is a hash from role-key to plist. Each entry says, for that role: what is the top-level key, what are the sub-keys (each with their own equality test), and any role-specific attributes.

Most of the `declare-index` calls are in `auxiliary-indexing.lisp` (only `:unbound-rule-index-pos` and `:unbound-rule-index-neg` are visible in the port). The bulk of the registrations would normally include every role in the table above; the LarKC strip elided them for roles like `:gaf-arg`, `:predicate-extent`, etc. — those are still implicitly used because `index-equality-test-for-keys` falls through to `*default-intermediate-index-equal-test*` (`#'eq`) when no declaration is found.

The clean rewrite should resurrect explicit declarations for every role, with sub-key info, equality tests, and any per-role optimizations. Centralizing index metadata makes the indexing layer reflectable — code paths like `dump-kb-indexing` can iterate every declared role rather than hard-coding role names.

## How an assertion is dispatched to roles

`add-assertion-indices assertion` ([`kb-indexing.lisp:611`](../../../larkc-cycl/kb-indexing.lisp#L611)) is the entry point on assertion creation. It dispatches on GAF vs rule:

### GAF path

`add-gaf-indices assertion` ([`kb-indexing.lisp:710`](../../../larkc-cycl/kb-indexing.lisp#L710)):

1. `determine-gaf-indices formula mt` walks the literal and returns:
   - `argnum-pairs` — `((0 . pred) (1 . arg1) (2 . arg2) ...)` for the indexable args
   - `others` — the set of fully-indexed terms found via `tree-gather` that aren't already in `argnum-pairs` (terms nested inside NAUTs or HLMT functor/args)
2. **MT index** — `add-mt-index mt assertion` (skipped if `broad-mt?` — the broadest MTs like `#$BaseKB` would dominate the index).
3. **Predicate extent** — `add-predicate-extent-index pred mt assertion`.
4. **Per-arg indexing** — for each `(argnum . arg)` with `argnum > 0`, `add-gaf-arg-index arg argnum pred mt assertion`.
5. **NART arg or other** — if the predicate is `#$termOfUnit`, the arg2 NAUT terms register under `:nart-arg`; otherwise every fort in `others` registers under `:other`.

### Rule path

`add-rule-indices assertion` ([`kb-indexing.lisp:825`](../../../larkc-cycl/kb-indexing.lisp#L825)):

1. `determine-rule-indices cnf` returns:
   - `neg-pairs` — `((indexing-type term) ...)` for terms that appear in neg-lits
   - `pos-pairs` — same shape, for pos-lits
   - `other` — terms found by `tree-gather` minus those in pairs

   The `indexing-type` is one of `:pred`, `:ist-pred`, `:func`, `:isa`, `:quoted-isa`, `:genls`, `:genl-mt`, `:exception`, `:pragma`. It is decided by `determine-rule-indices-int`'s `cond` on the literal's predicate.

2. For each neg-pair, dispatch to `add-<role>-rule-index term :neg mt dir assertion`. Similarly for pos-pairs with `:pos`.
3. For each other-term, `add-other-index term assertion`.
4. MT-index the rule's MT.
5. After all term-keyed indexing, `add-unbound-rule-indices assertion` ([auxiliary-indexing.md](auxiliary-indexing.md)) registers the assertion under the fixed `unbound-rule-index` for rules that have no fully-indexed term.

`remove-rule-indices` / `remove-gaf-indices` mirror, calling the corresponding `rem-` functions.

## Lookup: the "best lookup index" planner

A query like "find an assertion matching `(#$isa ?x #$Dog)`" needs to scan one role's bucket. Which role gives the smallest bucket? `best-gaf-lookup-index asent truth methods` ([`kb-indexing.lisp:1079`](../../../larkc-cycl/kb-indexing.lisp#L1079)) is the planner.

It returns a `lookup-index` plist with `:index-type` set to one of `:gaf-arg`, `:predicate-extent`, `:overlap`, plus role-specific sub-keys. The planner:

1. Computes `num-predicate-extent-index pred` and `num-gaf-arg-index arg argnum pred` for every bound arg.
2. Picks the smallest, breaking ties toward `:predicate-extent` (no per-arg keys to track).
3. If MT-relevance is restricted, retries with cutoff-aware variants (`relevant-num-predicate-extent-index-with-cutoff` / `relevant-num-gaf-arg-index-with-cutoff`) — these stop counting once they exceed the current best, avoiding wasted work on roles that can't possibly win.
4. If `:overlap` is allowed and no per-key index is small enough, falls back to overlap-style lookup (currently `missing-larkc 12755` / `12767`).

The `methods` argument lets a caller restrict the planner to a subset of roles — e.g. `find-gaf` allows only `:predicate-extent` and `:gaf-arg`; `find-cnf` for rules dispatches differently via `decent-rule-index`.

`decent-rule-index cnf` ([`kb-indexing.lisp:961`](../../../larkc-cycl/kb-indexing.lisp#L961)) is the rule-side planner. It computes `num-<role>-rule-index` for every term in `neg-pairs`, `pos-pairs`, and `other`, picks the smallest, and returns `(role-with-sense, term)` (e.g. `:pred-pos`, `:isa-neg`, `:other`). The caller (`find-rule-cnf-via-index-int`) then walks that one role's leaf-set with `find-cnf-internal` checking each candidate against `*mapping-target*` via the dynamic `*cnf-matching-predicate*`.

## Lifecycle

### Birth (term index)

The term-index slot is initialized to `nil` (a fresh simple-index) when the term's content struct is first constructed. `initialize-term-complex-index term` is available for callers that know they need a complex index immediately, but the default is simple.

### Mutation

Every `add-<role>-index` and `rem-<role>-index` call mutates the term's index. The mutation is observable to the LRU layer via `mark-term-index-as-muted`, which dirties the index page so it gets persisted on the next flush.

### Mode toggle

`convert-to-complex-index term` ([`simple-indexing.lisp:387`](../../../larkc-cycl/simple-indexing.lisp#L387)): collects the term's simple-index assertion list, calls `initialize-term-complex-index`, then re-adds each assertion's indices via the full per-role machinery. `convert-to-simple-index` does the reverse — gathers all leaves from every role and stores them as a flat list.

### Death

`free-term-index term` ([`kb-indexing-datastructures.lisp:141`](../../../larkc-cycl/kb-indexing-datastructures.lisp#L141)) frees an index and replaces it with an empty simple-index. `free-complex-index` / `free-subindex` / `free-intermediate-index` walk the tree clearing hashtables. `free-final-index` is `missing-larkc 31924`.

`remove-term-indices term` ([`kb-indexing.lisp:627`](../../../larkc-cycl/kb-indexing.lisp#L627)) is the *removal cascade*: it gathers the assertion lists from every role of `term`'s index and TMS-removes each batch. Roles processed: `:other`, `:ist` (if HLMT), every `*-rule-index` role, `:predicate-extent`, `:function-extent`, `:nart-arg`, `:gaf-arg` per argnum (with special handling for `:isa`/`:genls`/`:termOfUnit` arg1 to avoid removing the term itself before its bookkeeping is gone). Order matters: `:isa` and `:genls` and `:termOfUnit` arg1 assertions are removed *last* so SBHL caches and term existence checks see consistent state during the cascade. The function is the term-removal counterpart of `tms-remove-assertion`.

## Public API surface

```
;; Term-level operations
(term-index term)                      ; fetch the index struct
(reset-term-index term index)          ; primitive replacement
(term-add-indexing-leaf term keys leaf)
(term-rem-indexing-leaf term keys leaf)
(get-subindex term keys)
(num-index term)                       ; total leaf count
(remove-term-indices term)             ; cascade removal

;; Per-role operations (one set per role; pattern below)
;;   <role> ∈ {gaf-arg, nart-arg, predicate-extent, predicate-rule,
;;             decontextualized-ist-predicate-rule, isa-rule, quoted-isa-rule,
;;             genls-rule, genl-mt-rule, function-rule, function-extent,
;;             exception-rule, pragma-rule, mt, other}
(num-<role>-index term &optional <subkeys>)
(relevant-num-<role>-index term &optional <subkeys>)               ; mt-filtered
(relevant-num-<role>-index-with-cutoff term cutoff &optional <subkeys>)
(key-<role>-index term &optional <subkeys>)
(get-<role>-subindex term &optional <subkeys>)
(add-<role>-index term <subkeys> assertion)
(rem-<role>-index term <subkeys> assertion)
(matches-<role>-index assertion term &optional <subkeys>)

;; Assertion-level operations
(add-assertion-indices assertion &optional term-restriction)
(remove-assertion-indices assertion &optional term-restriction)
(add-gaf-indices assertion &optional term-restriction)
(add-rule-indices assertion &optional term-restriction)
(remove-gaf-indices assertion &optional term-restriction)
(remove-rule-indices assertion &optional term-restriction)
(determine-gaf-indices formula mt)
(determine-rule-indices cnf)
(determine-formula-indices formula)

;; Lookup planner
(best-gaf-lookup-index asent truth &optional methods)
(num-best-gaf-lookup-index asent truth &optional methods)
(decent-rule-index cnf)
(lookup-index-get-type li)
(lookup-index-gaf-arg-values li)
(lookup-index-for-predicate-extent pred)
(lookup-index-for-gaf-arg term argnum pred)

;; Find-by-CNF
(find-cnf cnf)                         ; relevant-mt scoped from outside
(find-assertion cnf mt)
(find-assertion-any-mt cnf)
(find-gaf gaf-formula mt)
(find-gaf-any-mt gaf-formula)
(find-gaf-formula gaf-formula)
(find-gaf-cnf cnf)
(find-rule-cnf cnf)
(find-all-assertions cnf)              ; missing-larkc

;; Predicates
(indexed-term-p obj)                   ; fort or assertion or unrepresented
(fully-indexed-term-p obj)             ; indexed-term-p minus unindexed-syntax-constants
(valid-indexed-term? obj)
(valid-fully-indexed-term-p obj)
(unindexed-syntax-constant-p obj)
(simple-indexed-term-p term)
(simple-index-p obj) (complex-index-p obj)
(intermediate-index-p obj) (final-index-p obj)

;; Mode-toggle wrappers
(noting-terms-to-toggle-indexing-mode <body>)
(possibly-toggle-term-index-mode term)
(toggle-term-index-mode term)
(convert-to-complex-index term)
(convert-to-simple-index term)

;; Iteration macros (covered in kb-mapping.md)
(do-gaf-arg-index ...) (do-predicate-rule-index ...) etc.
```

## Consumers

| Consumer | What it uses |
|---|---|
| **assertion creation/removal** (`assertion-manager.lisp`, `assertions-low.lisp`) | `add-assertion-indices` / `remove-assertion-indices` — every assertion mutation runs through here |
| **canonicalizer** (`canon-tl.lisp`, `czer-main.lisp`) | `find-assertion`, `find-cnf` to detect duplicates before creating a new assertion |
| **inference engine** (`inference/harness/*.lisp`, `inference/modules/*.lisp`) | `best-gaf-lookup-index` to plan candidate scanning, `do-<role>-index` macros to walk buckets |
| **KB mapping** (`kb-mapping.lisp`) | wraps every iteration macro with relevance-MT filtering, sense filtering, etc. — the "user-friendly" iteration API on top of the raw indexing |
| **TMS** (`tms.lisp`) | `remove-term-indices`, `tms-remove-assertion-list` cascade |
| **dumper** (`dumper.lisp`) | per-term index serialization on KB save |
| **HL modifiers** (`hl-modifiers.lisp`) | calls `add-assertion-indices` after KB mutation passes the storage-module preamble |
| **kb-content tests** (`cyc-testing/kb-content-test/`) | uses index walks to validate consistency invariants |

## Files

| File | Role |
|---|---|
| `kb-indexing.lisp` | Per-role `num/key/get/add/rem` operations. The `add-gaf-indices` / `add-rule-indices` dispatchers. The lookup planners (`best-gaf-lookup-index`, `decent-rule-index`). `find-gaf-formula` / `find-cnf` traversal. `remove-term-indices` cascade. The big file. |
| `kb-indexing-datastructures.lisp` | Defines `simple-index`, `intermediate-index`, `final-index`, `subindex` polymorphism. `term-index` / `reset-term-index` dispatch. Free-* functions. |
| `kb-indexing-declarations.lisp` | `*kb-indexing-declaration-store*` and `declare-index` registration. `index-equality-test-for-keys` per-level test lookup. |
| `kb-indexing-macros.lisp` | Helpers used by the per-role `cond` blocks: `number-of-non-null-args-in-order`, `number-has-reached-cutoff?`. |
| `simple-indexing.lisp` | `matches-<role>-index` predicates (the linear-scan dispatcher for simple-index lookup). `add-simple-index` / `rem-simple-index`. Mode-toggle thresholds and the `noting-terms-to-toggle-indexing-mode` macro. `convert-to-complex-index` / `convert-to-simple-index`. |
| `auxiliary-indexing.lisp` | Indexing for `unbound-rule-index` (rules with no indexed term). [auxiliary-indexing.md](auxiliary-indexing.md). |
| `virtual-indexing.lisp` | Stub for indexing of virtual terms (mostly missing-larkc). |

## CFASL serialization

The term's index is serialized as part of the term's content. Constants, NARTs, unrepresented terms, and assertions all have a `index` slot that flows over CFASL via the manager-level dump/load path. There is no separate "kb-indexing.cfasl" — the index lives wherever the term's content is stored:

- `indices.cfasl` — per-constant indices (the file of constant content)
- `nat-indices.cfasl` — per-NART indices
- `unrepresented-term-indices.cfasl` — per-unrepresented-term indices
- `assertion-indices.cfasl` — per-assertion auxiliary indices

The serialized form is the simple-index list or the recursively-encoded intermediate-index/final-index. Reading is symmetric: the manager reconstructs the index struct in memory.

`reindex-all-assertions` (currently `missing-larkc 12832`/etc.) is the rebuild path — call this after any structural change to the indexing scheme. It iterates every assertion and re-runs `add-assertion-indices` from scratch.

## Relevance-MT filtering

A query rarely cares about *every* assertion mentioning a term — it cares about the ones in MTs visible from the current relevance scope. The indexing layer cooperates by exposing `relevant-<role>` variants of every count and key function. These come in three flavors:

- **All MTs relevant** (`all-mt-subindex-keys-relevant-p`): identical to the unfiltered count.
- **One MT relevant** (`only-specified-mt-is-relevant?`): direct lookup at the MT key in the per-role MT subindex.
- **General**: walks the MT subindex, filtering by `relevant-mt? mt` and accumulating leaf counts.

`relevant-mt-subindex-count-with-cutoff` ([`kb-indexing.lisp:72`](../../../larkc-cycl/kb-indexing.lisp#L72)) is the workhorse — it short-circuits once it has counted past the cutoff, so the planner can use it without spending time on hopeless candidates.

The dynamic variables `*relevant-mt-function*` and `*mt*` are read via `relevant-mt?` ([`mt-relevance-macros.lisp`](../../../larkc-cycl/mt-relevance-macros.lisp)) on every check. See [microtheories.md](../core-kb/microtheories.md) for how these are bound.

## Notes for a clean rewrite

- **Unify the role taxonomy in one place.** Roles are referenced by name in `add-<role>-index`, `rem-<role>-index`, `num-<role>-index`, `key-<role>-index`, `get-<role>-subindex`, `matches-<role>-index`, the `:keys` plist of `declare-index`, and the `case` arms of `find-rule-cnf-via-index-int`. A clean design declares the role once with its sub-key schema, equality tests, and matchers, and generates the rest. The current code has ~14 roles × ~6 functions = ~84 near-duplicate functions, most of them missing-larkc stubs.
- **Drop the simple/complex split and use a single radix-tree-or-graph structure.** The split exists to save memory on long-tail terms (most constants are only mentioned in a few assertions). A modern hash table or trie can self-tune without an explicit toggle. The `noting-terms-to-toggle-indexing-mode` machinery and the LRU dirty-bit complexity goes away.
- **Move from "per-role nested hash" to "single (term, role, sub-keys) keyed graph."** The current `term → role → arg1 → arg2 → arg3 → set` tree is what an embedded graph database represents natively. A clean design uses one `(predicate, *args)`-keyed table per assertion-with-roles, and lookups become standard graph walks.
- **The `:other` catch-all and the `tree-gather` term-extraction logic are O(formula-size) per assertion.** A clean design stores the term-set explicitly on the assertion at canonicalization time so indexing and unindexing don't recompute it.
- **The `matches-<role>-index` predicates duplicate the "what role does this term play in this assertion" logic that `determine-gaf-indices` / `determine-rule-indices` already compute at insertion time.** Cache the role assignments on the assertion and the matcher reduces to a set membership check.
- **`best-gaf-lookup-index` is a hand-rolled query planner.** A clean design uses a real cardinality estimator (Cyc actually has one — see [`cardinality-estimates.lisp`](../../../larkc-cycl/cardinality-estimates.lisp)) and lifts the planner out of the indexing layer.
- **Mode toggling on the storage-module level is mixed with mode toggling on the indexing level.** The simple↔complex flip should be a private detail of the indexing implementation, not a global wrapper macro callers must wrap their code in.
- **The unindexed-syntax-constant blacklist should be data-driven** — a property on the constant ("indexable?") settable at constant creation, instead of a hard-coded list of four symbols.
- **`relevant-mt-subindex-count-with-cutoff` is essentially a hand-rolled cardinality query with cutoff** — bind it into a generic "count-leaves under a graph node, abort if exceeds N" primitive.
