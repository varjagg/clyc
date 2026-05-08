# Predicate relevance and `preservesGenlsInArg`

Two related but distinct mechanisms for **lifting reasoning through predicate hierarchies**:

1. **Predicate relevance** (`predicate-relevance-cache.lisp` + `pred-relevance-macros.lisp`) — when an inference asks "is this predicate relevant?", the answer can be yes via direct equality, via spec-pred relation (the asked pred is a spec-pred of the relevant pred), or via spec-inverse. The cache and macros wire this dynamic-binding-driven dispatch into the iteration layer.
2. **`preservesGenlsInArg`** (`preserves-genls-in-arg.lisp`, abbreviated **PGIA**) — a meta-rule about functors: when a function `F` "preserves genls in arg N", a `(genls A B)` implies `(genls (F … A …) (F … B …))` at that arg position. The PGIA system propagates these implied genls when the underlying `(genls A B)` is asserted.

Both files are heavily missing-larkc; the structure is preserved but most of the actual propagation logic must be reconstructed.

## When does this run?

### Predicate relevance

Continuously, during every KB iteration. `relevant-pred? pred` is called by:
- Every `do-<role>-index` iteration that has a predicate-keyed level (the pred-keys quiesce step in [kb-mapping.md](../kb-access/kb-mapping.md)).
- Every SBHL traversal that walks predicate-domain modules.
- Every GHL closure expansion (see [graphl-ghl-gt.md](graphl-ghl-gt.md)).

The dynamic vars `*pred*` and `*relevant-pred-function*` are set by callers to scope the relevance check to one predicate plus whatever spec/inverse it implies.

### PGIA

When `(isa NAUT some-collection)` is asserted (where NAUT is a non-atomic-unreified-term with a functor that has `preservesGenlsInArg`), or when `(genls col1 col2)` is asserted/removed and there's a NAT-shape match. The hooks fire from `#$afterAdding` registrations.

## Predicate relevance

### The dynamic context

```
*pred*                    nil   the predicate at the focus
*relevant-preds*          nil   precomputed list of relevant preds (sometimes used)
*relevant-pred-function*  nil   function (pred) → bool
```

The *relevance-function* polymorphism — the caller decides which preds are relevant by binding `*relevant-pred-function*` to one of:

| Function | Returns t if pred is... |
|---|---|
| `relevant-pred-is-eq` | `(eq *pred* pred)` — identical |
| `relevant-pred-is-spec-pred` | identical OR a spec-pred of `*pred*` |
| `relevant-pred-is-spec-inverse` | a spec-inverse of `*pred*` |
| `relevant-pred-is-everything` | always t |
| `inference-genl-predicate-of?` | a spec-pred of the current inference literal's predicate |
| `inference-genl-inverse-of?` | a spec-inverse of the current inference literal's predicate |
| `relevant-pred-wrt-gt?` | (in [graphl-ghl-gt.md](graphl-ghl-gt.md)) — for GT search |

### Public surface

```
(relevant-pred? pred)                        ; the central check
(pred-relevance-undefined-p)                 ; (null *relevant-pred-function*)
(all-preds-are-relevant?)                    ; t if everything is relevant

;; Specific relevance functions
(relevant-pred-is-eq pred)
(relevant-pred-is-spec-pred pred)
(relevant-pred-is-spec-inverse pred)

;; Inference-context relevance
(inference-genl-predicate-of? pred)
(inference-genl-inverse-of? pred)
(determine-inference-genl-or-spec-pred-relevance sense)
(determine-inference-genl-or-spec-inverse-relevance sense)

;; Pred-info struct
(make-pred-info-object) (pred-info-object-p)
(pred-info-pred obj) (pred-info-relevance-function obj)
```

### `relevant-pred?` dispatch

```lisp
(defun relevant-pred? (pred)
  (or (pred-relevance-undefined-p)        ; no function bound — everything is relevant
      (funcall *relevant-pred-function* pred)))
```

The "undefined" branch defaults to "yes" — meaning code paths that don't bind the dynamic see every predicate as relevant. Inference paths that *do* bind the dynamic will filter to the relevant set.

### `inference-genl-predicate-of?` and `inference-genl-inverse-of?`

These read the current inference literal's predicate (from `*inference-literal*`) and check whether `pred` is a spec-pred (or spec-inverse) of it. Used by the inference engine to expand a query like "`(P x y)` for predicate P" to also consider all spec-preds of P.

`determine-inference-genl-or-spec-pred-relevance sense`:
- For `:pos` sense: `inference-genl-predicate-of?` (spec-preds also count).
- For `:neg` sense: `inference-genl-predicate?` — the inverse direction. (The `inference-genl-predicate?` function is defined elsewhere; the directionality flip handles "negated literal needs more-general-pred relevance.")

Same shape for the inverse variant.

### `pred-info-object` struct

```lisp
(defstruct (pred-info-object (:conc-name "PRED-INFO-"))
  pred
  relevance-function)
```

A bundle: a predicate plus the relevance-function to use when filtering. Used to package the (pred, relevance-fn) pair as a single value when passing across function boundaries (e.g. inference dispatch).

### Cache layer

`predicate-relevance-cache.lisp` provides 8 caches indexing the four spec/genl × pred/inverse × FORT/NAUT relations:

| Cache | What it caches |
|---|---|
| `*spec-pred-fort-cache*` | `(genl, mt)` → set of spec-preds of `genl` (FORT key) |
| `*spec-inverse-fort-cache*` | `(genl, mt)` → set of spec-inverses |
| `*genl-pred-fort-cache*` | `(spec, mt)` → set of genl-preds |
| `*genl-inverse-fort-cache*` | `(spec, mt)` → set of genl-inverses |
| `*spec-pred-naut-cache*` | (same, NAUT key) |
| `*spec-inverse-naut-cache*` | (same, NAUT key) |
| `*genl-pred-naut-cache*` | (same, NAUT key) |
| `*genl-inverse-naut-cache*` | (same, NAUT key) |

Each cache is a `new-cache` of size `*pred-relevance-cache-size* = 128` keyed by `equal`.

### Cache lookup

`fort-cache-relevant-pred? cache key-pred relevant-pred mt update-function` ([`predicate-relevance-cache.lisp:84`](../../../larkc-cycl/predicate-relevance-cache.lisp#L84)):

```
key := (key-pred mt)
relevant-predicates, hit? := cache-get cache key
unless hit?:
  relevant-predicates := update-relevant-pred-fort-cache update-function key-pred mt
  cache-set cache key relevant-predicates
return (set-contents-member? relevant-pred relevant-predicates)
```

`update-relevant-pred-fort-cache update-function pred mt`:

```
case update-function:
  'all-spec-predicates → construct-set-from-list (all-spec-predicates pred mt) #'eq
  'all-spec-inverses   → construct-set-from-list (all-spec-inverses pred mt) #'eq
  'all-genl-predicates → ...
  'all-genl-inverses   → ...
  default              → (funcall update-function pred mt) [for custom]
```

Each cache maps to a corresponding `all-X` accessor in [named-hierarchies.md](named-hierarchies.md).

### Public surface — cache layer

```
(*pred-relevance-cache-size*)                 ; 128
(*spec-pred-fort-cache*) (*spec-inverse-fort-cache*)
(*genl-pred-fort-cache*) (*genl-inverse-fort-cache*)
(*spec-pred-naut-cache*) (*spec-inverse-naut-cache*)
(*genl-pred-naut-cache*) (*genl-inverse-naut-cache*)

(cached-spec-pred? genl spec &optional mt)
(cached-spec-inverse? genl spec &optional mt)
(cached-genl-pred? genl spec &optional mt)              ; missing-larkc body
(cached-genl-inverse? genl spec &optional mt)           ; missing-larkc body

(fort-cache-relevant-pred? cache key-pred relevant-pred mt update-function)
(naut-cache-relevant-pred? ...)                         ; missing-larkc body
(update-relevant-pred-fort-cache update-function pred mt)
(update-relevant-pred-naut-cache ...)                   ; missing-larkc body
(fort-cache-spec-pred? genl spec mt)
(fort-cache-spec-inverse? genl spec mt)
(fort-cache-genl-pred? genl spec mt)                    ; missing-larkc body
(fort-cache-genl-inverse? genl spec mt)                 ; missing-larkc body
(naut-cache-spec-pred? genl spec mt)                    ; missing-larkc body
(naut-cache-spec-inverse? genl spec mt)                 ; missing-larkc body
(naut-cache-genl-pred? genl spec mt)                    ; missing-larkc body
(naut-cache-genl-inverse? genl spec mt)                 ; missing-larkc body

(clear-predicate-relevance-cache)
(clear-spec-pred-fort-cache) (clear-spec-pred-naut-cache)
(clear-spec-inverse-fort-cache) (clear-spec-inverse-naut-cache)
(clear-genl-pred-fort-cache) (clear-genl-pred-naut-cache)
(clear-genl-inverse-fort-cache) (clear-genl-inverse-naut-cache)
```

### Bug note — `clear-genl-inverse-*-cache`

The Java source had a bug where `clear-genl-inverse-fort-cache` and `clear-genl-inverse-naut-cache` cleared the `*spec-inverse-*` caches instead. The port fixes this. The bug went undetected because `fort-cache-genl-inverse?` and `naut-cache-genl-inverse?` are stripped stubs — the genl-inverse caches were never populated, so the wrong-clear did nothing observable. (See [`predicate-relevance-cache.lisp:146-155`](../../../larkc-cycl/predicate-relevance-cache.lisp#L146).)

## PGIA — `preservesGenlsInArg`

### Concept

`(preservesGenlsInArg F N)` says: "the function F preserves genls in arg N." Meaning: if `(genls A B)`, then `(genls (F arg1 … A … argN) (F arg1 … B … argN))` for the corresponding argument-substituted NATs.

Example: `(preservesGenlsInArg #$DateFn 1)` — replacing the year argument with a more general year-collection-instance preserves genls. So `(genls Year2025 Year2020s)` implies `(genls (#$DateFn Year2025 month day) (#$DateFn Year2020s month day))`.

PGIA propagation lets these implied genls fire automatically without enumerating every NAT-pair.

### The PGIA rule

The core rule (PGIA_RULE in [`preserves-genls-in-arg.lisp:62`](../../../larkc-cycl/preserves-genls-in-arg.lisp#L62)):

```
(implies
  (and (preservesGenlsInArg (FormulaArgFn 0 ?nat-1) ?arg)
       (equals (FormulaArgFn 0 ?nat-1) (FormulaArgFn 0 ?nat-2))
       (different ?nat-1 ?nat-2)
       (genls (FormulaArgFn ?arg ?nat-1) (FormulaArgFn ?arg ?nat-2)))
  (genls ?nat-1 ?nat-2))
```

Reading this: if the functor at position 0 of nat-1 is `preservesGenlsInArg` at arg, the functors of nat-1 and nat-2 are equal, the nats are different, and the two arg-`?arg` values are genls-related, then the two nats are genls-related.

The rule isn't *applied* like a normal rule — instead, the PGIA after-adding hooks propagate the conclusion directly.

### State variables

```
*pgia-fn*            functor for current PGIA processing
*pgia-gaf*           the triggering GAF
*pgia-arg*           arg position
*pgia-done*          set of (genl, spec) pairs already processed
*pgia-nat*           current NAT
*pgia-nat-fort*      the NAT's FORT form
*pgia-col*           the collection
*pgia-genl*          the genl side
*pgia-genl-nat*      the genl NAT
*pgia-genl-nats*     candidate genl NATs
*pgia-spec*          the spec side
*pgia-spec-nat*      the spec NAT
*pgia-spec-nats*     candidate spec NATs
*candidate-pgia-genls*    pending genls to assert
*candidate-pgia-specs*    pending specs to assert
*consider-current-pgia?*  per-step gate
*current-pgia-genls*      current set being considered
*current-pgia-specs*      same
*pgia-mt*            #$BaseKB                 the MT for PGIA propagation (defglobal)
*pgia-active?*       (defined elsewhere)      master switch
```

### After-adding hooks

`pgia-after-adding-pgia argument assertion` (missing-larkc body) — fires when a `(preservesGenlsInArg F N)` is asserted. Recomputes which existing isa-asserted NATs of F should now propagate.

`pgia-after-adding-isa argument assertion` ([`preserves-genls-in-arg.lisp:84`](../../../larkc-cycl/preserves-genls-in-arg.lisp#L84)) — fires when an `(isa NAT collection)` is asserted. If `*pgia-active?*` and the collection is a genl of `#$Collection`, and the NAT's functor has a `preservesGenlsInArg`, then call `missing-larkc 9452` (the actual propagation: walk genls of the col-type and emit `(genls NAT genl-NAT)` for each).

`pgia-after-removing-genls deduction assertion` ([`preserves-genls-in-arg.lisp:115`](../../../larkc-cycl/preserves-genls-in-arg.lisp#L115)) — fires when a `(genls NAT1 NAT2)` is removed. If both NATs have the same functor, retract the corresponding PGIA-derived genls. Body is mostly missing-larkc.

### Public surface

```
;; Variables
(*pgia-mt*)                          ; #$BaseKB
(*pgia-active?*)                     ; defined elsewhere; master switch
(*pgia-rule*)                        ; the canonical rule sketched above

;; PGIA dynamics (used during propagation)
(*pgia-fn*) (*pgia-gaf*) (*pgia-arg*) (*pgia-done*)
(*pgia-nat*) (*pgia-nat-fort*) (*pgia-col*)
(*pgia-genl*) (*pgia-genl-nat*) (*pgia-genl-nats*)
(*pgia-spec*) (*pgia-spec-nat*) (*pgia-spec-nats*)
(*candidate-pgia-genls*) (*candidate-pgia-specs*)
(*consider-current-pgia?*)
(*current-pgia-genls*) (*current-pgia-specs*)

;; After-adding / after-removing hooks
(pgia-after-adding-pgia argument assertion)             ; missing-larkc body
(pgia-after-adding-pgia-1 nat) (pgia-after-adding-pgia-2 genl-col) (pgia-after-adding-pgia-3 spec-col) ; missing-larkc body
(pgia-after-adding-isa argument assertion)
(pgia-after-adding-isa-1 gaf) (pgia-after-adding-isa-2 gaf)        ; missing-larkc body
(pgia-after-removing-genls deduction assertion)
(pgia-after-removing-genls-1 gaf)                                  ; missing-larkc body

;; Candidate machinery (mostly missing-larkc)
(candidate-pgia fn col genl-nat nat-fort mt &optional rule)
(pgia-true-in-mts genl-nat nat-fort mt)
(recompute-functor-pgia fn) (recompute-functor-pgia-1 gaf)
(recompute-nat-pgia nat) (recompute-nat-pgia-1 gaf)
(current-pgia-specs col mt) (current-pgia-genls col mt)
(gather-pgia gaf)
(pgia-assertion? assertion &optional mt)
(pgia-support? support)
(pgia-deduction? deduction &optional assertion)
(assert-candidate-pgia-genls) (assert-candidate-pgia-specs)
(known-pgia? spec genl mt) (candidate-pgia? spec genl mt)
(map-tous-of-fn-arg fn arg pred func)
```

## Consumers

| Consumer | What it uses |
|---|---|
| **kb-mapping** | Every iteration with predicate-keyed levels reads `*relevant-pred-function*` to filter |
| **SBHL** | Predicate-domain modules use predicate relevance to filter spec-pred lifts |
| **GHL / GT** | `relevant-pred-wrt-gt?` is the GT-domain relevance function; spec-pred / spec-inverse caches drive it |
| **Inference engine** | `inference-genl-predicate-of?` / `inference-genl-inverse-of?` are bound during query expansion |
| **Forward propagation** | PGIA hooks fire when isa or genls assertions are added/removed |
| **Canonicalizer** | PGIA-derived genls are canonical inferences; the canonicalizer must respect them when proving rule head sentences |
| **TMS** | PGIA-derived deductions are `pgia-deduction?` — they need TMS-tracking like any other deduction |

## Notes for a clean rewrite

- **The dynamic-binding pattern for predicate relevance** — `*pred*`, `*relevant-pred-function*` — works but is fragile. A clean rewrite passes a relevance-config struct explicitly through iteration and search APIs.
- **The cache size of 128 is small.** For predicate-rich KBs, the cache misses constantly. Modern designs scale by graph size.
- **The 8-cache split (spec/genl × pred/inverse × FORT/NAUT)** has a lot of redundancy. A single `(direction, kind, key-shape)` keyed cache would be cleaner.
- **`cached-genl-pred?`, `cached-genl-inverse?`, and the four NAUT caches are all missing-larkc** — only the spec-pred and spec-inverse FORT caches are functional. The clean rewrite must reconstruct, mirroring `fort-cache-spec-pred?` shape.
- **The `update-relevant-pred-fort-cache` switch on `'all-spec-predicates`/etc. symbols** is a poor man's polymorphism. A cleaner design has each cache hold a reference to its update function directly.
- **Cache invalidation is total** — `clear-predicate-relevance-cache` clears all 8 caches. There's no incremental invalidation when a single `(genlPreds A B)` is asserted/removed. The clean rewrite hooks this into the SBHL-cache invalidation path.
- **The `pred-info-object` struct is barely used.** It exists to bundle `(pred, relevance-function)`. A modern rewrite either uses a typedef'd cons or a richer config struct.
- **`relevant-pred?` defaulting to "everything is relevant" when no fn is bound** is a footgun — silently expanding a query to all preds. A clean rewrite errors when relevance is unbound in a context that should have specified it (and only bypasses the check in explicit "everywhere" mode).
- **PGIA is mostly missing-larkc.** The state variables, the rule, and the hook stubs are there; the actual propagation logic (~25 missing-larkc references) must be reconstructed. Without PGIA, NAT-genls implications are not automatically propagated, and inference must enumerate them via slower paths.
- **The PGIA rule** in `*pgia-rule*` is a reified CycL form. It's not actually evaluated as a rule; it's used as a structural template for the propagation code that mimics it. A clean rewrite either applies it as a real rule (slower but uniform) or generates the propagation code from the template (the current intent).
- **The `*pgia-mt*` defaults to `#$BaseKB`** — PGIA propagation happens in the BaseKB scope. This is conservative; PGIA conclusions should arguably propagate in whatever MT the source isa-assertion was in. Document the choice.
- **`*pgia-active?*` master switch** lets PGIA be globally disabled (e.g. during bulk imports). Reasonable, but should be a per-import option, not a global.
- **`pgia-after-adding-pgia` recomputes every existing NAT-with-this-functor** when a `preservesGenlsInArg` is added. This is O(NAT-count-of-functor). For a frequently-instanced functor like `#$DateFn`, the bulk-add of `preservesGenlsInArg` becomes expensive. A clean rewrite incrementalizes via marking.
- **The PGIA dynamic vars (~16) are again a smell.** Bundle into a `pgia-context` struct passed explicitly.
- **Cache eviction** is via the underlying `cache.lisp` LRU — when cache fills, oldest entry evicted. The clean rewrite should match the SBHL cache strategy (size-percentage of total predicates) rather than fixed 128.
