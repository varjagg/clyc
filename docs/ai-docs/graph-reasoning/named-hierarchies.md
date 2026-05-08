# Named hierarchies — isa, genls, genlPreds, disjointWith, equality, negation, transitivity

These eight files are the **named-accessor surface** for the most important transitive predicates in the KB. Each file is a thin layer of public functions named after the predicate (`isa?`, `genls?`, `disjoint-with?`, `genl-predicate?`, `equals?`, etc.) wrapping an SBHL or GT call. They:

1. **Define the public API** that inference modules, accessors, and external tooling use.
2. **Implement the after-adding / after-removing hooks** that the [forward-propagation](../kb-access/forward-propagation.md) machinery fires when a `(genls A B)` (or `(isa …)`, etc.) is asserted/unasserted, mutating the corresponding SBHL graph.
3. **Provide accessor variants** — local-only, max, min, all, asserted-only, supported-only, why-* (justification) — so callers don't have to compose primitives.

| File | Lines | Predicate(s) covered |
|---|---|---|
| `isa.lisp` | 568 | `#$isa`, `#$quotedIsa` |
| `genls.lisp` | 490 | `#$genls`, `#$specs` (inverse) |
| `genl-predicates.lisp` | 574 | `#$genlPreds`, `#$genlInverse`, `#$specPreds`, `#$specInverse` |
| `disjoint-with.lisp` | 149 | `#$disjointWith` |
| `equals.lisp` | 197 | `#$equals`, `#$different`, `#$rewriteOf` |
| `equality-store.lisp` | 149 | `*some-equality-assertions-somewhere-set*` cache |
| `negation-predicate.lisp` | 169 | `#$negationPreds`, `#$negationInverse` |
| `transitivity.lisp` | 140 | Generic-Transitivity dispatcher (GTM) |

**Sibling-disjoint collections (SDC)** — covered separately in [sdc.md](sdc.md) — is the *meta-level* disjointness predicate: instead of asserting that C1 and C2 are disjoint, SDC asserts disjointness *by default* among instances of the same `#$SiblingDisjointCollectionType`, with a `#$siblingDisjointExceptions` carve-out. Conceptually it's a sibling of `disjointWith`, but it has its own marking-space machinery and exception-bypass search large enough to warrant a standalone page.

The pattern across all files is the same: a small core function delegates to SBHL or GT, then a fleet of named variants composes around it.

## When does this run?

Three triggering situations:

1. **An accessor is called.** Inference modules, type-checking, canonicalization, paraphrase — they all eventually call `isa?`, `genls?`, `disjoint-with?`, `genl-predicate?`, etc.
2. **An assertion is added or removed.** The corresponding `#$afterAdding` / `#$afterRemoving` registration fires the per-predicate hook (`isa-after-adding`, `genls-after-adding`, `disjoint-with-after-adding` (a.k.a. `mdw-after-adding`), `genl-predicate-after-adding`, `negation-inverse-after-adding`), which mutates the SBHL graph and invalidates the relevant per-pair caches.
3. **The KB is reset.** `clear-X-graph` and `reset-X-graph` (mostly missing-larkc) wipe the per-predicate SBHL graph during a teardown. `clear-some-equality-assertions-somewhere-set` resets the equality-cache.

## isa — `#$isa` and `#$quotedIsa`

### Public surface

```
(isa? v-term collection &optional mt tv)             ; the central question
(isa-in-any-mt? v-term collection)                   ; ignore MT relevance
(quoted-isa? v-term collection &optional mt tv)
(quoted-isa-in-any-mt? v-term collection)
(all-isa v-term &optional mt tv)                     ; collections this term is in
(all-instances col &optional mt tv)                  ; terms in this collection
(all-isa-among v-term collections &optional mt tv)
(asserted-isa? v-term &optional mt)
(asserted-isa v-term &optional mt)
(asserted-quoted-isa? v-term &optional mt)
(min-isa v-term &optional mt tv)                     ; missing-larkc; most-specific isa collections
(max-isa-among v-term collections &optional mt tv)   ; missing-larkc
(why-isa? v-term collection &optional mt tv)         ; justification
```

### Implementation

`isa?` ([`isa.lisp:142`](../../../larkc-cycl/isa.lisp#L142)) is a per-shape dispatcher:

- For a constant or NART `v-term`: `sbhl-true-isa? v-term collection mt tv` via the `:isa` SBHL module.
- For an unrepresented term (number/string): special-case lookup against the implicit-fort-typing table.
- For a NAUT: reduce via `result-isa` of the functor (does the functor's resultIsa apply?), or via the arg-2-naut table.

The arg-2-naut table (`*isa-arg2-naut-table*`) is populated by `initialize-isa-arg2-naut-table` and is referenced by the `:isa` SBHL module's `:naut-forward-true-generators` (see [sbhl.md](sbhl.md)). It maps NAUT shapes to the collections they implicitly belong to (e.g. every `(#$DateFn …)` is `isa #$Date`).

### After-adding hooks

`isa-after-adding source assertion` ([`isa.lisp:264`](../../../larkc-cycl/isa.lisp#L264)) is fired by the `(#$afterAdding #$isa <fn>)` registration. It:

1. Calls `sbhl-after-adding source assertion (get-sbhl-module #$isa)` — extends the SBHL graph.
2. Calls `possibly-propagate-isa-collection-subset-fn-the-set-of assertion` — if the new isa is `(isa X (CollectionSubsetFn …))`, propagate.
3. Calls `possibly-propagate-isa-the-collection-of assertion` — if `(isa X (TheCollectionOf …))`, propagate.

`isa-after-removing source assertion` ([`isa.lisp:311`](../../../larkc-cycl/isa.lisp#L311)) — symmetric remove.

`instanceof-after-adding` is a delegation to `isa-after-adding` (used in legacy code paths).

### Quoted-isa

`quoted-isa?` is the same shape as `isa?` but operates on the `:quoted-isa` SBHL module. The difference: `(quotedIsa "foo" #$CharacterString)` says the **quoted** form (the literal string `"foo"`) is a CharacterString, distinct from any unquoted/dereferenced form.

`quoted-instanceof-after-adding` mirrors `instanceof-after-adding` for the quoted-isa graph.

## genls — `#$genls`

### Public surface

```
(genl? spec genl &optional mt tv)                    ; subsumption: is genl above spec?
(genls? spec genl &optional mt tv)                   ; alias of genl?
(spec? genl spec &optional mt tv)                    ; inverse direction
(any-spec? genl specs &optional mt tv)               ; any of these specs?
(all-genls col &optional mt tv)                      ; transitive closure upward
(all-specs col &optional mt tv)                      ; transitive closure downward
(gather-all-genls fn col &optional mt tv combine-fn)
(min-cols cols &optional mt tv)                      ; most-specific filter
(asserted-genls? col &optional mt)
(asserted-genls col &optional mt)
(handle-more-specific-genl spec genl)                ; missing-larkc; for incremental cache update
```

### Implementation

`all-genls col &optional mt tv` ([`genls.lisp:63`](../../../larkc-cycl/genls.lisp#L63)) → `sbhl-all-forward-true-nodes (get-sbhl-module #$genls) col mt tv` plus reflexive append.

`all-specs col &optional mt tv` ([`genls.lisp:77`](../../../larkc-cycl/genls.lisp#L77)) → `sbhl-all-backward-true-nodes` of the `:genls` module.

`genl?` ([`genls.lisp:131`](../../../larkc-cycl/genls.lisp#L131)) → `sbhl-true-genl? spec genl mt tv` via the `:genls` SBHL module.

`min-cols cols` ([`genls.lisp:213`](../../../larkc-cycl/genls.lisp#L213)) — pairwise filter: keep `c` iff no other `c'` in `cols` is `(genls c' c)`-strict-spec of `c`. Implemented with `:genls` SBHL marking spaces.

### After-adding hooks

`genls-after-adding source assertion` ([`genls.lisp:259`](../../../larkc-cycl/genls.lisp#L259)) — calls `sbhl-after-adding source assertion (get-sbhl-module #$genls)`. Then optionally calls `handle-more-specific-genl` to propagate any ist-implied genls.

`genls-after-removing` is the symmetric remove.

## genl-predicates — `#$genlPreds`, `#$genlInverse`, `#$specPreds`, `#$specInverse`

The predicate-domain analog of genls. `(genlPreds P1 P2)` says P2 is a *generalization* of P1 — every assertion `(P1 x y)` implies `(P2 x y)` (in the same MT scope).

### Public surface

```
(genl-predicate? spec genl &optional mt tv)
(genl-pred? spec genl &optional mt)                  ; alias
(genl-inverse? spec genl &optional mt tv)            ; for inverse
(all-genl-predicates pred &optional mt tv)
(all-genl-preds pred &optional mt tv)                ; alias
(all-genl-inverses pred &optional mt tv)
(all-spec-predicates pred &optional mt tv)
(all-spec-preds pred &optional mt tv)
(all-spec-inverses pred &optional mt tv)
(all-proper-genl-predicates pred &optional mt tv)    ; excludes self
(all-proper-genl-inverses pred &optional mt tv)
(min-predicates preds &optional mt tv)
(max-predicates preds &optional mt tv)
(some-genl-pred-or-inverse? pred &optional mt tv)
(some-spec-pred-or-inverse? pred &optional mt tv)
(some-spec-predicate-or-inverse-somewhere? pred)
(asserted-genl-predicates? pred &optional mt)
(asserted-genl-inverses? pred &optional mt)
(some-all-spec-preds-and-inverses pred fn &optional mt tv)
```

### Implementation

`genl-predicate? spec genl &optional mt tv` ([`genl-predicates.lisp:183`](../../../larkc-cycl/genl-predicates.lisp#L183)) → `sbhl-true-genl-predicate?` via the `:genl-preds` SBHL module.

`all-genl-predicates pred mt tv` → `sbhl-all-forward-true-nodes` of `:genl-preds`.

The genl-preds module has the special property `:module-inverts-arguments #$genlInverse` — meaning a `(genlInverse P1 P2)` assertion contributes "spec-inverse" links into the genl-preds graph. The dual structure means `(P2 x y) ⇐ (P1 y x)` is captured by the same machinery as `(P2 x y) ⇐ (P1 x y)`.

### After-adding hooks

`genl-predicate-after-adding source assertion` ([`genl-predicates.lisp:316`](../../../larkc-cycl/genl-predicates.lisp#L316)) — `(sbhl-after-adding source assertion (get-sbhl-module #$genlPreds))`.
`genl-inverse-after-adding source assertion` — for `:genl-inverse` module.
`genl-predicate-after-removing` / `genl-inverse-after-removing` — symmetric removes.

`add-genl-predicate` / `add-genl-inverse` / `remove-genl-predicate` / `remove-genl-inverse` are aliases used elsewhere.

## disjoint-with — `#$disjointWith`

### Public surface

```
(disjoint-with? c1 c2 &optional mt tv)               ; central
(any-disjoint-with? c1s c2 &optional mt tv)
(any-disjoint-with-any? c1s c2s &optional mt tv)     ; missing-larkc body
(any-disjoint-collection-pair cols &optional mt)
(any-disjoint-collection-pair? cols &optional mt)    ; missing-larkc body
(disjoint-with-specs? c1 c2 &optional mt)            ; missing-larkc body
(collections-disjoint? c1 c2 &optional mt)           ; missing-larkc body; obsolete alias
(local-disjoint-with col &optional mt tv)            ; missing-larkc body; only direct disjoints
(all-disjoint-with col &optional mt tv)              ; missing-larkc body
(max-all-disjoint-with col &optional mt tv)          ; missing-larkc body
(why-disjoint-with? c1 c2 &optional mt tv behavior)  ; missing-larkc body
(why-collections-disjoint? c1 c2 &optional mt)       ; missing-larkc body; obsolete
(instances-of-disjoint-collections? t1 t2 &optional mt tv)  ; missing-larkc body
(why-instances-of-disjoint-collections t1 t2 &optional mt tv) ; missing-larkc body
(maximal-consistent-subsets cols)                    ; missing-larkc body
(maximal-consistent-subset? cols1 cols2)             ; missing-larkc body
```

### Implementation

`disjoint-with? c1 c2 &optional mt tv` ([`disjoint-with.lisp:79`](../../../larkc-cycl/disjoint-with.lisp#L79)):

```
if (first-order-naut? c1):
  missing-larkc 10979       -- nat-disjoint-with? path
else:
  sbhl-implied-disjoins-relation-p (get-sbhl-module #$disjointWith) c1 c2 mt tv
```

The SBHL `:disjoint-with` module has `:module-type :disjoins` and `:transfers-through-module #$genls`. So `(disjointWith Mammal Plant)` plus `(genls Dog Mammal)` and `(genls Oak Plant)` lets `(disjointWith Dog Oak)` be derived without per-pair assertions.

`any-disjoint-collection-pair cols mt` ([`disjoint-with.lisp:62`](../../../larkc-cycl/disjoint-with.lisp#L62)) — pairwise check on a list of collections: returns `(c1 c2)` for the first disjoint pair found. Used to detect inconsistencies like "isa X Mammal" plus "isa X Plant."

### After-adding hooks

`mdw-after-adding argument assertion` (missing-larkc body) — registered as the disjoint-with after-adding hook (mdw = "minimal disjointWith"). Calls into the `:disjoint-with` module's link-add path.
`mdw-after-removing` — symmetric.

### Related: sibling-disjoint collections

For *default* disjointness among instances of a `#$SiblingDisjointCollectionType` (e.g. `Adult` vs. `Infant` under `BiologicalLifeStage`) with `#$siblingDisjointExceptions` carve-outs, see the standalone [sdc.md](sdc.md). SDC and `disjointWith` are different mechanisms — `disjointWith` is direct/asserted, SDC is by-default-via-meta-type-with-exceptions — but consumers asking "are these collections disjoint?" usually want both checked.

## equals.lisp — `#$equals`, `#$different`, `#$rewriteOf`

### Public surface

```
(equals? obj1 obj2 &optional mt tv)                  ; central
(equal-fort? fort non-fort &optional mt tv)
(equal-forts? fort1 fort2 &optional mt tv)
(equal-everywhere? obj1 obj2)                        ; missing-larkc body
(equal-somewhere? obj1 obj2)                         ; missing-larkc body
(all-equals obj &optional mt tv)                     ; missing-larkc body
(why-equals obj1 obj2 &optional mt tv)               ; missing-larkc body
(direct-rewrite-of? fort1 fort2 &optional mt)        ; missing-larkc body
(any-direct-rewrite-of? fort1 fort2 &optional mt)    ; missing-larkc body
(simplest-forts-wrt-rewrite fort &optional mt)       ; missing-larkc body
(different? objects &optional unknown-value)
(different?-binary obj1 obj2 &optional unknown-value)
(why-different objects)
(why-different-binary obj1 obj2)
(asserted-different? obj1 obj2)                      ; missing-larkc body
(unique-names-assumption-applicable-to-term? v-term)
(unique-names-assumption-applicable-to-all-args? formula)
(unique-names-assumption-applicable-to-all-args-except? formula argnum)
```

### Implementation

`equals? obj1 obj2` ([`equals.lisp:43`](../../../larkc-cycl/equals.lisp#L43)) dispatches:

- `(equal obj1 obj2)` — fast path; identical or list-equal.
- Both are FORTs → `equal-forts? fort1 fort2 mt tv` via `gt-predicate-relation-p #$equals`.
- One is FORT, other not → `equal-fort? fort non-fort mt tv`.
- Otherwise nil.

The `gt-predicate-relation-p` call uses GT (general-transitivity, see [graphl-ghl-gt.md](graphl-ghl-gt.md)) because `#$equals` is not SBHL-managed.

`*perform-equals-unification*` gates whether equals reasoning runs (defaults to enabled but can be suppressed for speed).

### Different — `(different obj1 obj2 ... objN)`

`different? objects` is the multi-way version: every pair must be `different?-binary`. Returns t if all distinct, nil if any pair is equal/unifiable, `unknown-value` if any pair can't be decided.

`different?-binary obj1 obj2`:

```
1. (term-unify obj1 obj2)                           -- if unifiable, NOT different
2. both subl-strict-atomic-term-p (different lisp values)  -- DIFFERENT
3. both UNA-applicable                               -- DIFFERENT (Unique Names Assumption)
4. asserted-different? (missing-larkc 29996)        -- DIFFERENT
5. different-by-disjointness? (missing-larkc 29998) -- DIFFERENT
6. otherwise: unknown-value
```

`unique-names-assumption-applicable-to-term?` — returns t iff the term is *not* `inference-indeterminate?` and not isa `#$TermExemptFromUniqueNamesAssumption`. UNA is the assumption that "different constants name different individuals" — which doesn't hold for indeterminate / abstract terms.

`why-different` and `why-different-binary` build justification chains: opaque hl-supports for the atomic / UNA cases, missing-larkc for the asserted-different and disjointness cases.

### Rewrite-of

`#$rewriteOf` is the rewriting predicate: `(rewriteOf X Y)` says X can be rewritten as Y (e.g. `(rewriteOf (PlusFn 1 1) 2)`). The rewrite-of mechanism propagates via `perform-rewrite-of-propagation` (called from TMS — see [tms.md](../kb-access/tms.md)).

`some-source-rewrite-of-assertions-somewhere?` uses `some-pred-assertion-somewhere? #$rewriteOf obj 2` — true iff `obj` is the source (arg-2) of some `#$rewriteOf` assertion.

## equality-store.lisp — the equality cache

A small but important cache: `*some-equality-assertions-somewhere-set*` is a set of FORTs known to participate in any `#$equals`-style assertion. This is consulted by `equals?` to short-circuit: if neither FORT is in the set, no equality can hold.

`some-equality-assertions? obj` — does this FORT have any equality assertions in any MT?

`some-equality-assertions-somewhere? obj` — same, ignoring MT (lazier check).

`initialize-some-equality-assertions-somewhere-set` ([`equality-store.lisp:72`](../../../larkc-cycl/equality-store.lisp#L72)) walks every spec-pred of `#$equals`, every assertion in that pred's predicate-extent, and `cache-some-equality-assertions-somewhere` for each. This rebuilds the set after KB load.

`cache-some-equality-assertions-somewhere assertion` adds both arg1 and arg2 of the GAF to the set (if both are FORTs).

`clear-some-equality-assertions-somewhere-set` resets.

`decache-some-equality-assertions-somewhere arg1 arg2` (missing-larkc body) — symmetric remove for unassert hooks.

## negation-predicate.lisp — `#$negationPreds`, `#$negationInverse`

Mirror of genl-predicates but for *negation*: `(negationPreds P1 P2)` says P2 is the negation of P1 — `(P1 x y)` implies `(NOT (P2 x y))` and vice versa.

### Public surface

```
(negation-predicate? pred1 pred2 &optional mt tv)    ; missing-larkc body
(negation-pred? pred1 pred2 &optional mt)            ; missing-larkc body
(negation-inverse? pred1 pred2 &optional mt tv)      ; missing-larkc body
(all-negation-predicates pred &optional mt tv)
(all-negation-preds pred &optional mt)               ; missing-larkc body
(all-negation-inverses pred &optional mt tv)         ; missing-larkc body
(do-all-negation-predicates (negation-pred pred &key mt tv done) body)
(max-all-negation-predicates pred &optional mt tv)
(max-negation-preds pred &optional mt)
(max-all-negation-inverses pred &optional mt tv)
(max-negation-inverses pred &optional mt)
(some-negation-pred-or-inverse? pred &optional mt tv)  ; missing-larkc body
(asserted-negation-preds pred &optional mt)            ; missing-larkc body
(why-negation-pred? pred1 pred2 &optional mt tv)       ; missing-larkc body
```

### Implementation

`all-negation-predicates pred mt tv` → `sbhl-all-implied-disjoins (get-sbhl-module #$negationPreds) pred mt tv`. Uses the `:negation-preds` SBHL module which is `:module-type :disjoins` and `:transfers-through-module #$genlPreds`.

`max-all-negation-predicates pred mt tv` → `sbhl-implied-max-disjoins` — only the most-general negation preds.

### After-adding hooks

`negation-predicate-after-adding` (missing-larkc body) and `negation-inverse-after-adding` ([`negation-predicate.lisp:127`](../../../larkc-cycl/negation-predicate.lisp#L127)). The latter calls `sbhl-after-adding source assertion (get-sbhl-module #$negationInverse)`.

`add-negation-inverse` / `remove-negation-inverse` are aliases.

## transitivity.lisp — Generic Transitivity dispatcher (GTM)

A generic transitivity-method dispatcher. **GTM** = "GT Method" — a way to invoke a parameterized transitive-search method (`:transitive-closure`, `:relation-p`, `:max-transitive-closure`, etc.) for any transitive predicate.

### Public surface

```
(gtm predicate method &optional arg1 arg2 arg3 arg4 arg5)
(gtm-in-mt predicate method mt &optional arg1 arg2 arg3)   ; missing-larkc body
(gtm-in-all-mts predicate method &optional arg1 arg2 arg3) ; missing-larkc body
(gti predicate method ...)                                  ; missing-larkc body
(gti-predicate predicate index-arg gather-arg method ...)   ; missing-larkc body
(gti-accessors accessors method ...)                        ; missing-larkc body
(apply-gti-function gti-function arg1 arg2 arg3 arg4 arg5)
(reset-gti-state)                                           ; missing-larkc body
(gt-method-function method)
(gt-method-arg-list method)                                 ; missing-larkc body
(gt-mt-arg method)
(gt-mt-arg-value method &optional arg1 arg2 arg3 arg4 arg5)
(gt-method? method)                                         ; missing-larkc body
(gt-module? module) (gt-predicate module) (gt-mt module)    ; all missing-larkc
(gt-index-arg module) (gt-gather-arg module)                ; missing-larkc body
(ggt-index-arg predicate) (ggt-gather-arg predicate)
(gt-accessors module)                                       ; missing-larkc body
(setup-transitivity-module predicate plist)                 ; missing-larkc body
```

### `gtm` dispatch

```
(gtm pred method &optional arg1 arg2 arg3 arg4 arg5):
  mt-var := gt-mt-arg-value method arg1 arg2 arg3 arg4 arg5
  bind *mt*, *relevant-mt-function*, *relevant-mts* per mt-var
  if (transitive-predicate? pred) OR *gt-handle-non-transitive-predicate?*:
    gti-function := gt-method-function method     -- look up the implementation
    when (function-spec-p gti-function):
      bind *gt-pred*, *gt-index-arg*, *gt-gather-arg*
      if *gt-marking-table*: just apply
      else: bind *gt-marking-table* := (get-sbhl-marking-space)
            apply, then free
  else: missing-larkc 4004 (predicate not transitive)
```

`gt-method-function` looks up the method in `*gt-dispatch-table*` (declared elsewhere) which maps method-keyword to function. Examples of methods would include `:transitive-closure`, `:relation-p`, `:max-X`, `:min-X`.

`gt-mt-arg method` returns the position of `mt` in the method's arg-list (so `gt-mt-arg-value` can extract it from the variadic args).

`ggt-index-arg pred` — returns `(fan-out-arg pred)` if set, else falls back to the dynamic `*gt-index-arg*`.

`ggt-gather-arg pred` — `1` if index is `2`, else `2` (binary-flip).

### `apply-gti-function`

A hand-rolled variadic apply that handles the `*unprovided*` sentinel. Arguments shifted off as nil.

This whole file is **mostly missing-larkc** — only `gtm`, `apply-gti-function`, `gt-method-function`, `gt-mt-arg`, `gt-mt-arg-value`, `ggt-index-arg`, `ggt-gather-arg` have bodies. The core dispatch table `*gt-dispatch-table*`, the per-method specs, and the actual GTI methods are all stripped.

## Public API surface (consolidated)

This section lists the high-traffic accessors. Every function above is an entry point; the list here is a quick-lookup of the most-called ones.

```
;; Type queries
(isa? v-term collection &optional mt tv)
(isa-in-any-mt? v-term collection)
(quoted-isa? v-term collection &optional mt tv)
(genls? spec genl &optional mt tv)
(spec? genl spec &optional mt tv)
(genl-predicate? spec genl &optional mt tv)
(genl-pred? spec genl &optional mt)
(genl-inverse? spec genl &optional mt tv)
(disjoint-with? c1 c2 &optional mt tv)
(equals? obj1 obj2 &optional mt tv)
(different? objects &optional unknown-value)
(different?-binary obj1 obj2 &optional unknown-value)
(unique-names-assumption-applicable-to-term? term)

;; Closure
(all-isa term &optional mt tv) (all-instances col &optional mt tv)
(all-genls col &optional mt tv) (all-specs col &optional mt tv)
(all-genl-predicates pred &optional mt tv)
(all-spec-predicates pred &optional mt tv)
(all-negation-predicates pred &optional mt tv)
(all-disjoint-with col &optional mt tv)
(all-equals obj &optional mt tv)

;; Most-specific / most-general
(min-cols cols &optional mt tv)
(min-isa term &optional mt tv) (max-isa-among term cols &optional mt tv)
(min-genls col &optional mt tv) (max-not-genls col &optional mt tv)
(min-predicates preds &optional mt tv) (max-predicates preds &optional mt tv)
(max-all-disjoint-with col &optional mt tv)
(max-all-negation-predicates pred &optional mt tv)

;; Equality cache
(*some-equality-assertions-somewhere-set*)
(some-equality-assertions? obj &optional mt)
(some-equality-assertions-somewhere? obj)
(initialize-some-equality-assertions-somewhere-set)
(clear-some-equality-assertions-somewhere-set)
(cache-some-equality-assertions-somewhere assertion)
(some-source-rewrite-of-assertions-somewhere? obj)

;; After-adding hooks (for forward-propagation registration)
(isa-after-adding source assertion) (isa-after-removing source assertion)
(quoted-instanceof-after-adding source assertion)
(genls-after-adding source assertion) (genls-after-removing source assertion)
(genl-predicate-after-adding source assertion) (genl-predicate-after-removing ...)
(genl-inverse-after-adding source assertion) (genl-inverse-after-removing ...)
(negation-predicate-after-adding source assertion) (negation-inverse-after-adding ...)
(mdw-after-adding argument assertion) (mdw-after-removing argument assertion)
(add-genl-predicate ...) (add-genl-inverse ...) (add-negation-inverse ...)
(remove-genl-predicate ...) (remove-genl-inverse ...) (remove-negation-inverse ...)
(handle-more-specific-genl spec genl)

;; Justification
(why-isa? v-term collection &optional mt tv)        ; missing-larkc body
(why-genls? spec genl &optional mt tv)              ; missing-larkc body
(why-genl-predicate? spec genl &optional mt tv)     ; missing-larkc body
(why-disjoint-with? c1 c2 &optional mt tv behavior) ; missing-larkc body
(why-equals obj1 obj2 &optional mt tv)              ; missing-larkc body
(why-different objects)
(why-different-binary obj1 obj2)
(why-negation-pred? pred1 pred2 &optional mt tv)    ; missing-larkc body

;; Generic transitivity dispatcher
(gtm predicate method &optional arg1 arg2 arg3 arg4 arg5)
```

## Consumers

| Consumer | What it uses |
|---|---|
| **Inference** (workers, removal modules) | `isa?`, `genls?`, `disjoint-with?`, `genl-predicate?` for type-gating and for spec-pred lifting |
| **WFF / arg-type system** | `isa?` for every arg-type check on every assert |
| **Canonicalizer** | `disjoint-with?` for tautology/contradiction detection; `equals?` for term equivalence |
| **TMS** | `equals?` and `different?` propagate via rewrite-of; the equality-store cache fast-paths the check |
| **Microtheory relevance** | `:genl-mt` SBHL via `genl-mt?` (defined elsewhere in `genl-mts.lisp`) |
| **Bookkeeping / forward-propagation** | All `*-after-adding` / `*-after-removing` hooks register against `#$afterAdding` GAFs |
| **Cyc API** | Most named accessors are exposed via `register-cyc-api-function` |
| **HL-support modules** | `:isa`, `:genls`, `:disjointwith`, `:equality`, `:negationpreds` (see [kb-hl-supports.md](../core-kb/kb-hl-supports.md)) — these named-hierarchy functions produce the supports |

## Notes for a clean rewrite

- **The named-accessor file pattern is the right interface.** Each file is a thin contract layer between inference clients and the underlying SBHL/GT engine. Preserve. Each new transitive predicate that needs first-class accessors should get its own file with the same shape.
- **Many `local-*`, `max-*`, `min-*`, `asserted-*`, `supported-*`, `why-*` variants are missing-larkc.** These are the variants callers need but LarKC stripped. Reconstruct as one-liners on top of the SBHL primitives:
  - `local-X` = direct-edge-only (no transitive closure).
  - `max-X` / `min-X` = boundary filter on the closure result.
  - `asserted-X` = filter to assertions present in the KB.
  - `supported-X` = filter to assertions with valid supports (TMS-aware).
  - `why-X` = build a justification chain by walking the closure with `:justify? t`.
- **The `equals?` short-circuit through `*some-equality-assertions-somewhere-set*` is correct and important.** Most KB terms have no equality assertions; the cache turns the answer into an O(1) negative lookup. Preserve.
- **`gtm` and the `*gt-dispatch-table*`** are the generic-transitivity escape hatch — letting inference invoke parameterized transitive operations on arbitrary transitive predicates. Most of the file is missing-larkc; reconstruct from the dispatch-table shape (each entry is `(method fn arglist)`).
- **`*gt-handle-non-transitive-predicate?*`** is a relax-the-rules toggle for testing. The default check `(transitive-predicate? predicate)` rejects non-transitive predicates from gtm; the toggle bypasses. Document as test-only.
- **The `#$afterAdding` registration pattern** for these hooks is repeated across files — `negation-predicate.lisp`'s setup ends with six `register-kb-function` calls. Consolidate via a declarative module-property: `(:after-adding-hook genl-predicate-after-adding)` rather than a separate registration call per pred.
- **`mdw-after-adding` / `mdw-after-removing`** for disjointWith use the `mdw` prefix (minimal-disjoint-with), historical naming. Rename to `disjoint-with-after-adding` / `-after-removing` for consistency.
- **`equals?` going through `gt-predicate-relation-p`** is correct (since `#$equals` isn't SBHL-managed) but means an equality query has the full GT closure cost. For a high-traffic predicate, consider giving it its own SBHL module — the `:equals` module would be `:simple-reflexive` and `:disjoins-module #$different`.
- **The `:disjoint-with` and `:negation-preds` modules transfer through `:genls` and `:genl-preds`** — clever, lets disjointness propagate without N² assertions. Document the transfer arg semantics carefully; off-by-one in transfer-arg can cause silent inconsistency.
- **The arg2-naut tables for isa/quoted-isa** (`*isa-arg2-naut-table*`, `*quoted-isa-arg2-naut-table*`) are populated at module-init from special functions and provide implicit isa for NAUTs. The clean rewrite makes these declarative — a function-property `:result-isa-table`.
- **`unique-names-assumption-applicable-to-term?`** has a hardcoded fallback through `inference-indeterminate-term?`. Modern designs make UNA scope a per-term property recorded explicitly.
- **Several "obsolete" Cyc API functions** (`collections-disjoint?`, `why-collections-disjoint?`) are registered as `register-obsolete-cyc-api-function` redirecting to new names. Preserve the redirects but emit deprecation warnings in the rewrite.
- **The `(missing-larkc 7102)` placeholder for `genl-inverse?` in `ghl-create-justification`** ([graphl-ghl-gt.md](graphl-ghl-gt.md)) means the inverse-side justification path is unreachable. The `genl-inverse?` accessor in `genl-predicates.lisp` is also missing-larkc. Reconstruct: it's `sbhl-true-genl-inverse?` via the `:genl-inverse` SBHL module.
- **`possibly-propagate-isa-collection-subset-fn-the-set-of` and `possibly-propagate-isa-the-collection-of`** in `isa.lisp` handle two specific NAUT shapes (`(CollectionSubsetFn …)` and `(TheCollectionOf …)`). These are forward-propagation hooks specific to those functor shapes. A clean design has a `:forward-propagate-fn` property on the functor declaration, registering this behavior declaratively.
- **The `transitivity.lisp` API surface** (gtm, gti, gti-predicate, gti-accessors, setup-transitivity-module) is mostly stub. The clean rewrite implements: a registry of transitive predicates with their `:index-arg` / `:gather-arg` / `:methods`, and a generic dispatch.
