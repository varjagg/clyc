# TVA — transitive value access

TVA (Transitive Value Access) is a *specialised inference subsystem* for queries on **transitive predicates** like `(genls A B)`, `(temporallySubsumes T1 T2)`, `(boundsOf C R)`. The KB asserts the immediate links; TVA answers transitive-closure queries by walking the link graph rather than asking the engine to apply transitivity rules one step at a time.

The naming convention:
- **TVA** = transitive via arg — `(transitiveViaArg pred argnum)` declares that `pred` chains transitively through `argnum`
- **TVAI** = transitive via arg inverse — same, but the chain reverses direction at one end
- **CVA** = conservative via arg — closure stops at certain barrier conditions
- **CVAI** = conservative via arg inverse

Transitive closure of binary predicates is a common operation; doing it via tactics is `O(N²)` per asent. TVA precomputes/caches closures for hot predicates, achieving `O(N + M)` (where M is the number of relevant binary closures).

The five files (1332 lines total) form a layered subsystem:

- `tva-utilities.lisp` (361) — the meta-level: which predicates have TVA, the precomputation threshold, the hot-path predicates `some-tva-for-predicate`, `some-cva-for-predicate`
- `tva-cache.lisp` (464) — the cache datastructures: `tva-cache` struct + registry + per-predicate lookup
- `tva-strategy.lisp` (159) — `tva-strategy` struct (different concept than the inference strategist!) — represents which arguments have been unified and which tactics remain
- `tva-tactic.lisp` (195) — `tva-tactic` struct — represents one step in resolving a TVA query
- `tva-inference.lisp` (153) — `tva-inference` struct — orchestrates the per-query state

Source files:
- `larkc-cycl/tva-utilities.lisp`
- `larkc-cycl/tva-cache.lisp`
- `larkc-cycl/tva-strategy.lisp`
- `larkc-cycl/tva-tactic.lisp`
- `larkc-cycl/tva-inference.lisp`

## The four TVA predicates

`*tva-predicates*` lists them:

```lisp
(deflexical *tva-predicates*
  (list #$transitiveViaArg
        #$transitiveViaArgInverse
        #$conservativeViaArg
        #$conservativeViaArgInverse))
```

These are the meta-predicates. `(transitiveViaArg genls 1)` says "`genls` is transitive on its first argument; the closure relation is genls itself." More concretely: if `(genls A B)` and `(genls B C)`, then `(genls A C)`.

`(conservativeViaArg <pred> <argnum>)` adds a barrier: the closure stops at certain conditions. Example: `(conservativeViaArg before 1)` — chains of `before` link relations stop at certain temporal markers.

`do-tva-predicates(pred ... body)` iterates the four predicates.

## The hot-path predicates

`some-tva-for-predicate(predicate)` — does this predicate have *any* TVA assertion? Returns boolean. Cached via `cached-some-tva-for-predicate(predicate, mt-info)` (defun-cached, equal, capacity 100, cleared on `:hl-store-modified`).

The cache is keyed on `(predicate, mt-info)`. The `mt-info` parameter is necessary because TVA-relevance depends on the current MT relevance frame (a predicate can be transitive in one MT and not another).

Inside the cache function, the dispatch is on the MT function:
- `relevant-mt-is-everything` → use `#$EverythingPSC`
- `relevant-mt-is-any-mt` → use `#$InferencePSC`
- `mt-union-naut-p` → extract MT-list from union NART
- else → use the given mt-info as the relevant MT

Then call `some-all-spec-preds-and-inverses(predicate, 'some-transitive-via-arg-assertion?)` — walk the spec-pred graph (and inverses) of the predicate, looking for any TVA assertion.

`some-cva-for-predicate(predicate)` is the conservative version with the same shape.

`some-transitive-via-arg-assertion?(predicate)` and `some-conservative-via-arg-assertion?(predicate)` are the per-predicate predicates that actually look for TVA/CVA assertions.

`tva-assertion-p(assertion)` and `cva-assertion-p(assertion)` are the assertion-level predicates.

## When does TVA fire?

The TVA module is one of the registered HL removal modules (`:removal-tva-lookup-pos`, `:removal-tva-lookup-neg`, `:removal-tva-check-pos`, `:removal-tva-check-neg` etc. in `removal-modules-tva-lookup.lisp`). Whenever a removal tactic on a transitive predicate fires, the TVA module is one candidate.

The `:expand` of the TVA modules eventually delegates to `tva-unify(asent, &optional one-answer? justify? v-bindings hypothetical-bindings restricted-assertion)` (mostly missing-larkc) — the workhorse function that computes the answer set by walking the closure graph.

Inside `tva-unify`:
1. Construct a `tva-inference` for this query
2. Determine which argnums are bound (`determine-term-argnums`) and which are variables (`determine-var-argnums`)
3. Choose a strategy (which order to unify the arguments)
4. Walk the closure graph, marking visited nodes
5. For each closure node that satisfies the asent, accumulate the answer

The result feeds into `removal-add-node` like any other HL module (see "Backward inference" doc).

## The `tva-cache` datastructure

```lisp
(defstruct tva-cache
  pred           ; the predicate this cache is for
  index-argnum   ; the argument we index on
  tva-pred-gafs  ; precomputed TVA assertions
  tvai-pred-gafs ; precomputed TVAI assertions
  map)           ; the actual cache: key → (raw-supported-values . supported-subkeys)
```

The cache is *one cache per predicate per index-argnum*. A predicate like `genls` has caches for both arg1 (forward closure) and arg2 (backward closure).

`*tva-cache-registry*` is the dictionary of `predicate → caches`. `tva-caches-for-predicate(predicate)` returns the list. `tva-cache-for-predicate-and-index-argnum(predicate, argnum)` finds the specific cache.

`tva-cache-predicate-index-arg-cached-p(predicate, index-arg)` — is there a cache?

`do-tva-cache((key raw-supported-values supported-subkeys cache) ...)` — iterate the cache map, destructuring each entry into key + value.

`do-tva-caches((cache bin-pred) ...)` — iterate every cache in the registry.

### Cache lookups

`tva-cache-get-values(key, cache, inverse?, done?)` (missing-larkc) — the main lookup. Given a key (the argument value to start from), walk the cache's map and return the closure values reachable from key.

`tva-cache-check-value(key, cache, inverse?, done?, ...)` (missing-larkc) — check if a specific value is in the closure.

### Cache lifecycle

- `initialize-tva-caches()` (missing-larkc) — at startup, build caches for predicates marked as TVA-precompute
- `initialize-uninitialized-tva-caches()` (missing-larkc) — lazy initialisation
- `register-tva-cache(cache)` (missing-larkc) — add to the registry
- `clone-swappable-tva-cache(cache, fvector)` (missing-larkc) — duplicate for serialisation
- `reconnect-swappable-tva-cache(cache, fvector, &optional common-symbols)` (missing-larkc) — rebind after deserialise

The "swappable" naming refers to the file-backed cache layer (see "File-backed cache" doc in `kb-access/`): TVA caches can be swapped out to disk and reloaded on demand.

### When to precompute?

`*tva-precompute-closure-threshold* = 60` — closure cardinality below which to *always* mark (precompute). Above this, only mark on demand.

`with-tva-precompute-closure-threshold(num) … body` rebinds the threshold for a specific scope. Used for benchmarking what threshold gives best performance.

The threshold is empirically tuned: 60 is small enough that the work is cheap, large enough to capture the most-frequently-asked closures.

## The TVA strategy

TVA has its own `tva-strategy` struct — separate from the inference engine's strategy:

```lisp
(defstruct tva-strategy
  inverse-mode-p            ; are we walking the closure backwards?
  argnums-unified           ; which argnums have been unified so far
  argnums-remaining         ; which argnums still need unification
  tactics                   ; the queue of tactics to try
  tactics-considered)       ; tactics already tried
```

A TVA strategy represents the current state of a multi-argument TVA query. For `(transitivePredicate ?A ?B)`, the strategy might decide to bind `?A` first, then `?B` from the closure of `?A`'s value. Or vice versa. The strategy tracks what's been done.

Operations on the strategy (mostly missing-larkc):
- `new-tacticless-strategy()` — empty strategy
- `new-strategy-with-tactics(tactics)` — start with a tactic list
- `make-tva-default-strategy()` — the default
- `make-tva-simple-strategy()` — minimal strategy
- `with-new-tva-strategy(var) … body` — scoped binding
- Various `do-strategy-*` macros for iterating remaining argnums and tactics
- `tva-restrategize(...)` — recompute strategy mid-query
- `proceed-with-tva-strategy(strategy)` — advance the strategy by one step

`strategy-considered-tactic?` and `strategy-unified-tactic-argnum?` are the bookkeeping predicates.

`tva-strategy-subsumes-strategy-p` — does one strategy strictly dominate another? (Used for de-duplicating exploration.)

## The TVA tactic

`tva-tactic` (defstruct details mostly stripped) — represents one *concrete* step in resolving a TVA query: which argnum, which value, which closure walk.

Tactic operations (mostly missing-larkc): `tva-tactic-argnum-to-strategy-argnum`, plus standard accessors and constructors.

The tva-tactic vs. tva-strategy distinction parallels the engine's tactic vs. strategy: the strategy plans what tactics to consider; tactics execute concrete work.

## The TVA inference

```lisp
(defstruct tva-inference
  problem                       ; the parent problem
  asent-pred                    ; the predicate of the asent being resolved
  asent-args                    ; the asent's args
  args-admitted                 ; per-arg admittance bitvector
  term-argnums                  ; argnums where the value is fully bound
  var-argnums                   ; argnums where the value is a variable
  precomputations               ; cached intermediate results
  reused-spaces                 ; reused SBHL marking spaces
  one-answer?                   ; stop after first answer?
  justify?                      ; produce justification supports?
  restricted-assertion          ; the focal assertion (if restriction-driven)
  answers)                      ; accumulated answers
```

Constructed via `make-tva-inference`. Active during a single TVA query.

`with-new-tva-inference … body` binds `*tva-inference*` to a fresh inference for the body's scope.

`*tva-reuse-spaces?*` (defparameter, default nil) — when on, SBHL marking spaces are reused across multiple TVA queries within the same outer inference. Saves marking-space allocation overhead at the cost of reduced parallelism.

`*tva-max-time-enabled?* = t` — should the TVA inner loop check the controlling inference's `:max-time` parameter? Yes by default; turn off only for benchmarking.

### Per-query lifecycle

For a single `tva-unify(asent, ...)` call:

1. Construct `tva-inference` via `make-tva-inference`
2. `initialize-tva-inference(asent, one-answer?, justify?)` — set up term-argnums, var-argnums, args-admitted vectors
3. `determine-restricted-assertion(asent)` — if there's a focal assertion the closure must include, find it
4. Construct or retrieve a `tva-strategy` for this argnum signature
5. Walk the strategy: pop tactic, execute, accumulate, repeat
6. Each tactic execution: walk closure (using TVA cache if available, else SBHL search), mark nodes, collect answers
7. `tva-unify-closure-iterator(asent, one-answer?, justify?)` is the iterator interface for streaming results

### `precomputations` slot

Caches per-tactic intermediate results within this single TVA inference. E.g. if a tactic computes "all values reachable from X via genls," the result is stashed in the precomputations alist so a later tactic that needs the same set doesn't recompute.

`tva-store-precomputation(key, value)` and `tva-tactic-precomputations(tactic)` are the access functions.

## TVA's role in the inference engine

TVA is *one* of the optimisations the engine uses. The flow:

1. User asks `(genls Cat Animal)` → the strategist's removal-determination calls TVA-applicable check for this asent
2. If `some-tva-for-predicate(genls)` → T, the TVA module is among the candidate removal modules
3. The TVA module's `:expand` calls `tva-unify(asent, …)`
4. TVA computes the closure walk using the TVA cache (if available) or falls back to SBHL graph search
5. TVA returns answers via `removal-add-node` like any other HL module

The TVA cache is *the* speedup: for a hot predicate like `genls`, the closure of every common collection is precomputed. Asking "is X a genl of Y?" is `O(1)` lookup in the cache, not `O(closure-depth)` graph walk.

## Cross-system consumers

- **Removal modules** in `removal-modules-tva-lookup.lisp` are the entry — they detect when TVA applies and dispatch to TVA functions.
- **HL modules** consult `some-tva-for-predicate` to decide whether to defer to TVA.
- **CFASL** can serialise TVA caches via the swappable-cache pattern.
- **SBHL** is the fallback — when TVA cache miss, the underlying SBHL graph search runs.
- **Inference parameters** has `:transitive-closure-mode` (`:none | :focused | :all`) which controls TVA aggressiveness.

## Notes for the rewrite

### Naming

- **TVA = "transitive via arg," not "transitive value access"** despite the file name. Both interpretations are sensible; the original code uses both. Pick one (the doc above uses "transitive value access" because it matches the file name).
- **CVA is "conservative via arg."** Conservative means "stops at barriers."
- **The "I" suffix means "inverse"** — TVAI = TVA with the chain reversed at one end.

### Caching

- **TVA caches are the heart of the optimisation.** Without them, every transitive query falls back to SBHL graph walking. Implement the caches; the rest of the design depends on them.
- **The 60-element threshold is empirical.** Lower means more precomputation cost upfront; higher means more per-query cost. Tune for the target KB size.
- **Caches are per-predicate per-argnum.** `genls` has separate caches for arg1 (forward closure) and arg2 (backward closure). Both are needed.
- **Swappable caches** mean TVA caches can be persisted to disk. Keep this; the file-backed cache layer is what makes large KBs tractable.
- **`:clear-when :hl-store-modified`** is the standard cache invalidation. TVA caches must respect this; otherwise they go stale.

### Strategy / tactic

- **The TVA strategy/tactic is a *separate* concept from the engine's strategy/tactic.** Don't conflate. The TVA strategy plans the *order of unifying TVA query arguments*; the engine's strategy plans the *order of firing tactics*. Both are search controls but at different levels.
- **TVA strategy bodies are missing-larkc.** The strategy struct slots and the operation function names are documented; the bodies need reconstruction. The clean rewrite has good guidance from the function names.

### Inference

- **`*tva-reuse-spaces?*`** is a useful optimisation but defaults off because of subtle issues with cross-thread reuse. Keep the flag; consider whether to flip the default.
- **`*tva-max-time-enabled?*`** should always be on in production. The flag is for benchmarks only.
- **TVA must respect the parent inference's interrupt/abort.** Without it, a long TVA closure walk could ignore the user's interrupt.

### Structural

- **TVA is one HL module.** Don't try to make it the *only* path to transitive-predicate queries; the engine still needs the tactic-based path for non-cached predicates.
- **`:transitive-closure-mode`** is a per-query property: `:none | :focused | :all`. `:none` disables TVA closure precomputation; `:focused` limits to non-fan-out direction; `:all` enables full closure. The default is `:none` because TVA precomputation is expensive; users opt in.
- **The five-file split** (utilities, cache, strategy, tactic, inference) is sensible. Keep it; each file has a distinct responsibility.

### Missing-larkc

- **Most function bodies are missing-larkc.** The cache datastructure is fully defined; the cache-walk algorithms are not. The clean rewrite must implement: `tva-cache-get-values`, `tva-cache-check-value`, `initialize-tva-caches`, `tva-unify`, all the iterator state machines.
- **The strategy/tactic operations are stubs.** The clean rewrite must implement them based on the documented signatures and the strategy/tactic struct slots.
- **The reconstruction is well-bounded** because the design documents itself. Each function's purpose is clear from its name and the overall flow.
