# SBHL — Subsumption-Based Hierarchical Lookup

SBHL is the **graph reasoner for hierarchical, transitive predicates** — `#$genls`, `#$isa`, `#$genlPreds`, `#$genlMt`, `#$disjointWith`, `#$negationMt`, `#$negationPreds`, `#$negationInverse`, `#$genlInverse`, `#$quotedIsa`. It answers questions like "is Dog a spec of Animal?", "what are all genls of Mammal?", "is Dog disjoint from Plant?" — orders of magnitude faster than the general inference engine, by maintaining a per-predicate adjacency graph and traversing it directly.

The SBHL subsystem is the **single largest piece of inference machinery in Cyc**: 23 files, ~7000 lines of port. The reason: nearly every step of higher-level reasoning ("does this collection have this isa?", "is this MT relevant?", "can this rule fire?") is a question about subsumption. Making it fast makes everything fast.

The architecture has three layers:

1. **The graph store**: per-predicate adjacency hash tables, optionally backed by an on-disk file-vector with an LRU swap layer. Each "module" (one per predicate) has its own graph.
2. **The traversal engine**: a parameterized search machine that walks the graph in forward or backward direction, applying MT-relevance filters and TV-relevance filters, with marking-based cycle detection and result accumulation.
3. **The cache layer**: precomputed per-pair results (e.g. `(genls A B)` answered by lookup in `*genls-cache*` keyed by `A` and `B`) for the most common queries, avoiding traversal entirely.

## When does SBHL run?

Five triggering situations:

1. **An accessor asks a subsumption question.** `genls? spec genl &optional mt`, `isa? term collection &optional mt`, `min-genls col &optional mt`, `all-specs col &optional mt`, `disjoint-with? col1 col2 &optional mt`, `genl-pred? pred1 pred2 &optional mt`, etc. — every accessor in the `genls.lisp` / `isa.lisp` / `genl-predicates.lisp` / `disjoint-with.lisp` family routes to an SBHL traversal.
2. **A canonicalizer / WFF check resolves a type constraint.** Every `argIsa` / `argGenl` check against an asserted argument value goes through SBHL's `isa?` to verify the value matches its declared type.
3. **An assertion is added or removed.** `#$afterAdding`/`#$afterRemoving` hooks (see [forward-propagation.md](../kb-access/forward-propagation.md)) on `#$genls`/`#$isa`/`#$disjointWith`/`#$genlPreds`/`#$genlMt` etc. fire `propagate-genls-after-adding` / `propagate-isa-after-adding` / etc., which insert/remove the corresponding edge in the SBHL graph and invalidate stale cache entries.
4. **An inference module asks for predicate paths.** Removal modules (`removal-modules-isa`, `removal-modules-genls`, `removal-modules-disjoint-with`) call SBHL traversals to enumerate candidates.
5. **The KB loads.** SBHL graphs are persisted in `sbhl-modules.cfasl` + `sbhl-module-graphs.cfasl` (with index file). On load, the file-vector backing is initialized and graphs become lazy-loadable per node.

## The module concept

Each transitive predicate gets an **SBHL module** — a struct holding the predicate, its graph, its module-type, its mark/unmark functions, plus a registry of related modules (e.g. `#$genls`'s "disjoins-module" is `#$disjointWith`). Modules are declared via `init-sbhl-module-data pred plist` in [`sbhl-module-declarations.lisp`](../../../larkc-cycl/sbhl/sbhl-module-declarations.lisp).

The ten built-in modules:

| Module | Predicate | Type | Notes |
|---|---|---|---|
| `:genls` | `#$genls` | `:simple-reflexive` | root `#$Thing`, disjoins via `#$disjointWith` |
| `:disjoint-with` | `#$disjointWith` | `:disjoins` | transfers through `#$genls` (arg 1) |
| `:isa` | `#$isa` | `:transfers-through` | transfers through `#$genls` (arg 2); has arg2-naut table |
| `:quoted-isa` | `#$quotedIsa` | `:transfers-through` | transfers through `#$genls` (arg 2); has arg2-naut table |
| `:genl-mt` | `#$genlMt` | `:simple-reflexive` | root `*mt-root*`, disjoins via `#$negationMt` |
| `:negation-mt` | `#$negationMt` | `:disjoins` | transfers through `#$genlMt` (arg 1) |
| `:genl-preds` | `#$genlPreds` | `:simple-reflexive` | predicate-search; inverts arguments via `#$genlInverse` |
| `:genl-inverse` | `#$genlInverse` | `:simple-non-reflexive` | inverts arguments of `#$genlPreds` |
| `:negation-preds` | `#$negationPreds` | `:disjoins` | transfers through `#$genlPreds`; inverts via `#$negationInverse` |
| `:negation-inverse` | `#$negationInverse` | `:disjoins` | inverts arguments of `#$negationPreds` |

### Module properties

Each module is a plist with these keys ([`sbhl-module-declarations.lisp`](../../../larkc-cycl/sbhl/sbhl-module-declarations.lisp)):

| Key | Meaning |
|---|---|
| `:link-pred` | the CycL predicate this module reasons about |
| `:link-style` | `#$DirectedMultigraph` (forward and inverse links) or `#$Multigraph` (single direction) |
| `:module-type` | `:simple-reflexive` (transitive, reflexive), `:simple-non-reflexive`, `:transfers-through` (e.g. isa transfers through genls), `:disjoins` (e.g. disjointWith) |
| `:type-test` | `collection-p`, `microtheory-p`, `predicate-p` — type-check for valid module nodes |
| `:root` | top of the lattice (`#$Thing`, `*mt-root*`) |
| `:disjoins-module` | the module representing the negation of this one (genls → disjointWith) |
| `:transfers-through-module` | the module through which this transfers (e.g. disjointWith transfers through genls) |
| `:transfers-via-arg` | the arg position used in transfer |
| `:inverts-arguments-of-module` | for inverse modules (genlInverse inverts genlPreds) |
| `:module-inverts-arguments` | the inverse module (genlPreds is inverted by genlInverse) |
| `:naut-forward-true-generators` | functions that compute forward-true conclusions for NAUT terms |
| `:path-terminating-mark?-fn` | predicate to test if a mark terminates traversal |
| `:marking-fn` | function to apply a mark to a node |
| `:unmarking-fn` | function to clear a mark |
| `:predicate-search-p` | t for predicate-domain searches (uses different marking fns) |
| `:add-node-to-result-test` | gate function for whether a node should be added to results |
| `:accessible-link-preds` | list of predicates whose links can be traversed |
| `:index-arg` | arg position to index by |

`initialize-sbhl-modules &optional force?` sets up all ten modules. Idempotent unless `force?` — gated by `*sbhl-modules-initialized?*`.

## The graph store

### Per-module graph

Each module's graph is a hash table: `node → sbhl-direction-link`. Two link shapes:

```lisp
(defstruct sbhl-directed-link
  predicate-links     ; mt-links in the forward direction
  inverse-links)      ; mt-links in the backward direction

(defstruct sbhl-undirected-link
  links)              ; mt-links (single direction)
```

`sbhl-direction-link-p` is the union: either kind is acceptable.

The "mt-links" inside a direction-link are themselves a structure mapping `MT → list-of-target-nodes`. So the full path to walk an edge is:

```
graph[from-node] → direction-link
                    → (in forward direction): mt-links
                       → (for relevant MT): target-node-list
```

### File-vector backing

For large graphs (the default `#$genls` graph for a Cyc-Tiny KB has ~50k nodes), keeping every node's link in memory is wasteful. SBHL uses a file-vector backed map per module:

- The graph hash holds nodes that have been *touched* (loaded or modified).
- `*sbhl-backing-file-vector*` is the shared file-vector reading from `sbhl-module-graphs.cfasl`.
- `*sbhl-backing-file-vector-caches-for-modules*` is an alist `module → cache-strategy` where each cache is a per-module LRU.

When a node's links are needed: `get-sbhl-graph-link-from-graph node graph cache` consults the in-memory hash first, falls back to the file-vector via `file-vector-backed-map-w/-cache-get`. The result is cached in the LRU until evicted.

Cache sizes are 2% of the graph size by default (`*sbhl-backing-file-vector-cache-size-percentage* = 2`), with a floor of 100 entries (`*sbhl-backing-file-vector-cache-minimum-size*`).

`swap-out-all-pristine-sbhl-module-graph-links` is the bulk evictor — called from `swap-out-all-pristine-kb-objects` ([kb-accessors.md](../kb-access/kb-accessors.md)) before KB save.

### Locking

`*sbhl-rw-lock*` — read-write lock on the entire SBHL store. `with-rw-read-lock` for queries, `with-rw-write-lock` for mutations.

`*sbhl-file-vector-data-stream-lock*` — separate lock for the file-vector data stream itself, since CFASL reads must not be interrupted.

## The traversal engine

SBHL search is a parameterized graph traversal driven by ~30 dynamic variables. The skeleton:

```
search(node, module, mt, tv):
  bind dynamics for module / direction / MT-relevance / TV-relevance
  allocate marking-space
  unwind-protect:
    set search-behavior, terminating-marking-space, consider-node-fn
    sbhl-transitive-closure(node)   -- the actual graph walk
  cleanup: release marking-space
  return result
```

### Key entry points (in [`sbhl-search-methods.lisp`](../../../larkc-cycl/sbhl/sbhl-search-methods.lisp))

| Function | Returns |
|---|---|
| `sbhl-all-forward-true-nodes module node &optional mt tv` | every node reachable from `node` via forward `module` edges |
| `sbhl-all-backward-true-nodes module node &optional mt tv` | every node reachable from `node` via backward `module` edges |
| `sbhl-all-forward-false-nodes module node ...` | (missing-larkc) negative-edge reachable nodes |
| `sbhl-true-genl? spec genl &optional mt tv` | does the genls path exist? |
| `sbhl-true-spec? genl spec ...` | inverse |
| `sbhl-marked-as-true-genl? ...`, `sbhl-marked-as-false-spec? ...` | (cache-aware variants) |
| `sbhl-min/max-X` | filter the closure to keep only the boundary (most-specific or least-specific) |

### `sbhl-transitive-closure node`

The depth-first closure walk:

```
visit node:
  apply marking-fn (mark this node as visited)
  apply consider-node-fn (push to result if appropriate)
  for each outgoing edge in current direction (forward or backward):
    for each target in mt-relevant edges:
      if target not already path-terminated:
        recurse into target
```

The `consider-node-fn` is what decides which nodes appear in the result. Common variants: `sbhl-push-onto-result`, `sbhl-record-cardinality`, `sbhl-test-and-finish`. Set per-call via the dynamic `*sbhl-consider-node-fn*`.

### Search behavior

`determine-sbhl-search-behavior module direction tv` returns a `:sbhl-search-behavior` keyword:

- `:default` — standard transitive closure.
- `:negation-by-failure?` — assume not-genls if no path exists.
- `:transfers-through` — for modules like `:isa` that walk through another module's edges.
- `:disjoins` — for `:disjointWith` etc. — find disjoint pairs.
- `:resource-limited` — abort after exceeding a bound.

The behavior selects which `relevant-link-extractor` to use, which determines how each step queries edges from the current node.

### Marking spaces

To detect cycles and avoid revisiting nodes, SBHL maintains *marking spaces* — a hashtable mapping node → marking-state. Spaces are allocated at the start of a traversal and released at the end. Multiple parallel searches require parallel spaces.

`*sbhl-space*` is the primary search space (visited-node tracking). `*sbhl-gather-space*` is the result-accumulation space (used for `min-genls` style filtering where you mark candidates then prune). `*sbhl-resourced-sbhl-marking-spaces*` is the resource-managed pool.

`sbhl-new-space-source` decides whether to reuse an existing space or allocate a fresh one. The `:resource` source pulls from `*resourced-sbhl-marking-spaces*` (a pool, capped by `*resourced-sbhl-marking-space-limit*`); the `:old` source reuses the current `*sbhl-space*`.

`*resourcing-sbhl-marking-spaces-p*` — gate for whether resourcing is active. Set during forward inference (one space per query).

`update-sbhl-resourced-spaces space` — return a space to the pool.

The marking functions are per-module:

- For collection-domain modules: `set-sbhl-marking-state-to-marked`, `set-sbhl-marking-state-to-unmarked`, `sbhl-marked-p`.
- For predicate-domain modules: `sbhl-predicate-marking-fn`, `sbhl-predicate-unmarking-fn`, `sbhl-predicate-path-termination-p`.

The predicate-domain variants distinguish between "marked as predicate" and "marked as inverse" — needed for genlPreds/genlInverse where direction matters per node.

### MT relevance

Each edge is stored under an MT key. Traversal must respect the current MT relevance:

- `*sbhl-tv*` — current truth-value relevance (e.g. `#$True-JustificationTruth`).
- `*relevant-sbhl-tv-function*` — function to test relevance.
- `possibly-with-sbhl-mt-relevance mt body` — wrapper that establishes MT-relevance dynamics for an SBHL body.

`sbhl-mt-relevance-cache` (in [`sbhl-search-what-mts.lisp`](../../../larkc-cycl/sbhl/sbhl-search-what-mts.lisp)) tracks which MTs are relevant for which queries.

### Implied relations

`sbhl-search-implied-relations.lisp` covers cross-module inference: e.g. when traversing `:isa`, finding a `(genls A B)` step also implies `(isa x B)` for any `x` such that `(isa x A)`. The "transfers-through" property of modules drives this.

## The cache layer

### Per-pair caches

For the most-frequent subsumption questions, SBHL maintains direct lookup caches:

| Cache | Key | Value |
|---|---|---|
| `*genls-cache*` | `(spec, genl)` | bool / TV |
| `*all-mts-genls-cache*` | `(spec, genl)` | bool, MT-agnostic |
| `*isa-cache*` | `(term, collection)` | bool / TV |
| `*all-mts-isa-cache*` | `(term, collection)` | bool, MT-agnostic |
| `*genl-predicate-cache*` | `(pred1, pred2)` | bool |
| `*genl-inverse-cache*` | `(pred1, pred2)` | bool |
| `*all-mts-genl-predicate-cache*` | `(pred1, pred2)` | bool |
| `*all-mts-genl-inverse-cache*` | `(pred1, pred2)` | bool |
| `*implicit-fort-type-mapping*` | term | implicit-type-collection |

The caches are populated on demand: when `cached-relation-p pred subnode node` is called and the cache entry is missing, traversal runs and the result is cached. Subsequent queries with the same pair are O(1).

### Cached subsumption nodes

`*cached-genls*`, `*cached-genls-set*`, `*cached-isas*`, `*cached-isas-set*` — sets of FORTs that SBHL has decided are *worth caching*. Not every collection gets cached; only ones with frequent traffic.

`do-sbhl-cached-subsumption-nodes (node-var pred) body` — iteration macro over the cached node set for a predicate.

`cached-node? node pred` — is this node in the cached set?

`sbhl-pred-has-caching-p pred` — does the cache exist for this pred?

`sbhl-cache-use-possible-p pred node1 node2` — can we serve this query from cache? (both nodes must be cached.)

### Implicit fort typing

`*additional-fort-typing-collections*` and `*implicit-fort-typing-collections*` are special collections that carry implicit type information for FORTs (e.g. `#$Predicate`, `#$BinaryPredicate`, `#$Function-Denotational`, `#$Microtheory`). When a FORT is known to be one of these by structural property (e.g. its arity is set, its kind is determined), the implicit-type cache records this without needing a `(isa <fort> <type>)` SBHL search.

`*implicit-fort-type-mapping*` is the FORT → implicit-type-collection table.

### Cache invalidation

When an SBHL graph changes (an edge is added or removed), the per-pair caches must be invalidated:

- `sbhl-cache-addition-maintainence assertion` — called from the `#$afterAdding` hook for SBHL predicates. Invalidates entries that could have been affected.
- `sbhl-cache-removal-maintainence assertion` — `#$afterRemoving` counterpart.
- `possibly-add-to-sbhl-caches assertion term2-check-pred cache-pred` — selectively re-cache after addition.
- `possibly-remove-from-sbhl-caches pred assertion` — invalidate on removal.

`recache-sbhl-caches?` — predicate for whether the caches need rebuilding (e.g. after a bulk import).

## Mutation

When `(genls A B)` is asserted, the `#$afterAdding` hook for `#$genls` fires `propagate-genls-after-adding` which:

1. Acquire `*sbhl-rw-lock*` write.
2. `set-sbhl-graph-link A direction-link :genls` — extend `A`'s direction-link with `B` in the forward direction (add MT-link).
3. `set-sbhl-graph-link B direction-link :genls` — extend `B`'s direction-link with `A` in the backward direction.
4. Invalidate cache entries via `sbhl-cache-addition-maintainence`.

Removal mirrors this. The actual `propagate-X-after-adding` functions are mostly missing-larkc — the clean rewrite must reconstruct them from the per-module link/marking/unmarking specs.

## Public API surface

```
;; Module setup
(initialize-sbhl-modules &optional force?)
(initialize-genls-module) (initialize-isa-module) (initialize-disjoint-with-module)
(initialize-quoted-isa-module) (initialize-genl-mt-module) (initialize-negation-mt-module)
(initialize-genl-preds-module) (initialize-genl-inverse-module)
(initialize-negation-preds-module) (initialize-negation-inverse-module)
(reset-sbhl-modules)                                    ; missing-larkc body
(sbhl-modules-initialized?) (note-sbhl-modules-initialized)
(*sbhl-modules-initialized?*)
(init-sbhl-module-data pred plist)                      ; in sbhl-module-utilities

;; Module accessors
(get-sbhl-module pred)
(get-sbhl-module-list)
(get-sbhl-graph module)
(get-sbhl-module-type module)
(get-sbhl-module-forward-direction module)
(get-sbhl-module-backward-direction module)
(sbhl-module-directed-links? module)
(sbhl-module-p obj)
(get-sbhl-add-node-to-result-test module)

;; Graph store
(make-new-sbhl-graph)
(initialize-sbhl-graph-caches) (initialize-sbhl-graph-caches-during-load-kb data idx)
(initialize-sbhl-graph-caches-file-vector data idx)
(get-cache-strategy-for-sbhl-module module)
(set-cache-strategy-for-sbhl-module module strategy)
(new-cache-strategy-for-sbhl-module module &optional capacity)
(cache-capacity-for-cache-strategy-for-sbhl-module module)
(get-sbhl-graph-link node module)
(set-sbhl-graph-link node direction-link module)
(touch-sbhl-graph-link node direction-link module)
(remove-sbhl-graph-link node module)
(get-sbhl-graph-link-from-graph node graph cache)
(put-sbhl-graph-link-into-graph node graph cache value)
(remove-sbhl-graph-link-from-graph node graph cache)
(touch-sbhl-link-graph node graph cache)
(swap-out-all-pristine-graph-links module)
(swap-out-all-pristine-sbhl-module-graph-links)

;; Link types
(make-sbhl-directed-link) (make-sbhl-undirected-link)
(sbhl-directed-link-p obj) (sbhl-undirected-link-p obj) (sbhl-direction-link-p obj)
(create-sbhl-directed-link direction mt-links)
(create-sbhl-undirected-link mt-links)
(create-sbhl-direction-link direction mt-links module)
(set-sbhl-directed-link link direction value)
(set-sbhl-undirected-link link value)
(get-sbhl-directed-mt-links link direction)
(get-sbhl-undirected-mt-links link)
(get-sbhl-mt-links link direction module)
(any-sbhl-predicate-links-p node pred)

;; Search
(sbhl-all-forward-true-nodes module node &optional mt tv)
(sbhl-all-backward-true-nodes module node &optional mt tv)
(sbhl-all-forward-false-nodes ...)                      ; missing-larkc
(sbhl-true-genl? spec genl &optional mt tv)
(sbhl-true-spec? genl spec &optional mt tv)
(sbhl-true-isa? term collection &optional mt tv)
(sbhl-marked-as-true-genl? ...) (sbhl-marked-as-false-spec? ...)
(sbhl-min-genls col &optional mt tv) (sbhl-max-specs col &optional mt tv)
(sbhl-transitive-closure node)
(determine-sbhl-search-behavior module direction tv)
(determine-sbhl-terminating-marking-space behavior)
(get-sbhl-search-module) (get-sbhl-search-direction)
(get-sbhl-forward-search-direction) (get-sbhl-backward-search-direction)
(get-sbhl-tv) (get-sbhl-true-tv)
(possibly-with-sbhl-mt-relevance (mt) &body body)

;; Marking
(set-sbhl-marking-state-to-marked node) (set-sbhl-marking-state-to-unmarked node)
(sbhl-marked-p node)
(sbhl-predicate-marking-fn node) (sbhl-predicate-unmarking-fn node)
(sbhl-predicate-path-termination-p node)
(get-sbhl-marking-space) (sbhl-get-new-space source) (sbhl-new-space-source)
(update-sbhl-resourced-spaces space)
(*sbhl-space*) (*sbhl-gather-space*)
(*resourced-sbhl-marking-spaces*) (*resourcing-sbhl-marking-spaces-p*)
(*resourced-sbhl-marking-space-limit*)
(determine-marking-space-limit)

;; Caching layer
(*sbhl-caches-initialized?*)
(*genls-cache*) (*isa-cache*) (*genl-predicate-cache*) (*genl-inverse-cache*)
(*all-mts-genls-cache*) (*all-mts-isa-cache*)
(*all-mts-genl-predicate-cache*) (*all-mts-genl-inverse-cache*)
(*cached-genls*) (*cached-genls-set*) (*cached-isas*) (*cached-isas-set*)
(*cached-genl-predicates*) (*cached-genl-predicates-set*) (*cached-preds*)
(*additional-fort-typing-collections*) (*implicit-fort-typing-collections*)
(*implicit-fort-type-mapping*)
(note-sbhl-caches-initialized) (sbhl-caches-initialized-p)
(do-sbhl-cached-subsumption-nodes (node-var pred) &body body)
(cached-node? node pred)
(sbhl-pred-has-caching-p pred)
(sbhl-cache-use-possible-p pred node1 node2)
(sbhl-cache-use-possible-for-nodes-p pred nodes node)
(sbhl-cached-predicate-relation-p pred subnode node &optional mt)
(sbhl-cached-relation-p pred subnode node)
(get-sbhl-cache-for-pred pred)
(get-sbhl-all-mts-cache-for-pred pred)
(cached-relation-p pred subnode node)
(cached-relation-in-cache-p pred subnode node mt)
(get-mts-for-cached-sbhl-relation pred subnode node)
(cached-all-mts-relation-p pred subnode node)
(cached-all-mts-relations-for-node pred node)
(add-to-sbhl-cache pred node subnode mt)
(add-to-sbhl-all-mts-cache pred node subnode)
(retract-from-sbhl-cache pred node subnode mt)
(retract-from-sbhl-all-mts-cache pred node subnode)
(sbhl-cache-addition-maintainence assertion)
(sbhl-cache-removal-maintainence assertion)
(possibly-add-to-sbhl-caches assertion term2-check-pred cache-pred)
(possibly-remove-from-sbhl-caches pred assertion)
(recache-sbhl-caches?)

;; Type-checking
(valid-fort-type? type) (sbhl-node-object-p obj) (sbhl-predicate-p obj)
(sbhl-mt-links-object-p obj) (sbhl-true-tv-p obj)
(sbhl-directed-direction-p direction)
(sbhl-check-type obj predicate)

;; Module declarations (one per pred)
(my-creator-...) etc. as listed in module table above
```

## Files

| File | Role |
|---|---|
| `sbhl-graphs.lisp` | Graph store: file-vector backed, per-module caches, swap layer |
| `sbhl-links.lisp` | `sbhl-directed-link` / `sbhl-undirected-link` defstructs + accessors |
| `sbhl-link-iterators.lisp` | Iteration over edges from a node |
| `sbhl-link-methods.lisp` | Per-module edge add/remove |
| `sbhl-link-utilities.lisp` | Helpers for link manipulation |
| `sbhl-link-vars.lisp` | Dynamics for link traversal direction |
| `sbhl-iteration.lisp` | Generic iteration framework |
| `sbhl-macros.lisp` | Iteration / search macros |
| `sbhl-search-methods.lisp` | The traversal entry points (1389 lines — the big one) |
| `sbhl-search-datastructures.lisp` | Behavior structs, search-result accumulators |
| `sbhl-search-implied-relations.lisp` | Cross-module inference (e.g. isa via genls) |
| `sbhl-search-utilities.lisp` | Helpers used by search methods |
| `sbhl-search-vars.lisp` | The ~30 dynamics for traversal state |
| `sbhl-search-what-mts.lisp` | MT-relevance during search |
| `sbhl-marking-methods.lisp` | Per-module marking functions |
| `sbhl-marking-utilities.lisp` | Marking-space allocation, resource pool |
| `sbhl-marking-vars.lisp` | Dynamics for marking |
| `sbhl-cache.lisp` | The cache layer (619 lines) |
| `sbhl-caching-policies.lisp` | Which terms get cached |
| `sbhl-module-declarations.lisp` | The ten module declarations |
| `sbhl-module-utilities.lisp` | `init-sbhl-module-data`, `get-sbhl-module`, etc. |
| `sbhl-module-vars.lisp` | Module registry |
| `sbhl-paranoia.lisp` | Type-check / consistency-verify utilities |

## Consumers

| Consumer | What it uses |
|---|---|
| **isa.lisp / genls.lisp / genl-predicates.lisp** | Wraps `sbhl-true-isa?`, `sbhl-all-forward-true-nodes`, etc. as the named accessors `isa?`, `all-genls`, `genl-pred?` |
| **disjoint-with.lisp** | `sbhl-true-disjoint-with?` for the `:disjoint-with` module |
| **WFF / arg-type system** | Every `argIsa` / `argGenl` check resolves via `isa?` (which is SBHL) |
| **Inference removal modules** | Removal-modules-isa/genls/disjoint-with use SBHL traversal to enumerate candidates |
| **Microtheory relevance** | `relevant-mt?` (the runtime predicate read by every KB iteration) ultimately uses the `:genl-mt` SBHL module to resolve MT subsumption |
| **Canonicalizer** | Type-checking during canonicalization |
| **after-adding hooks** | `#$genls`/`#$isa`/etc. afterAdding GAFs trigger `propagate-X-after-adding` which mutates SBHL graphs |
| **dumper / loader** | SBHL graphs persist to `sbhl-module-graphs.cfasl`; loader calls `initialize-sbhl-graph-caches-during-load-kb` |
| **HL inference modules** | `:isa`, `:genls`, `:disjointWith`, `:genlPreds`, `:genlInverse`, `:genlmt`, `:negationPreds` HL-support modules ([kb-hl-supports.md](../core-kb/kb-hl-supports.md)) — SBHL produces the supports |

## Notes for a clean rewrite

- **The module abstraction is good** — declarative per-predicate config (`:link-pred`, `:type-test`, `:transfers-through-module`, etc.) makes adding a new transitive predicate a config change, not code. Preserve this design and consider extending: maybe arbitrary user predicates can declare an SBHL module if they self-attest as transitive.
- **The 30 dynamics for search state are awkward.** Modern designs use a single `search-state` struct passed through the traversal. The dynamics-pattern was inherited from SubL where it minimizes parameter-list shape changes.
- **The cache invalidation is conservative.** Most invalidations could be incremental (only the specific entry affected) but the implementation often invalidates whole sections. A clean rewrite uses an inverted index from cache-entry to graph-edge so invalidation is targeted.
- **The marking-space resource pool** is a hand-rolled object pool to avoid GC pressure during inference. Modern implementations use thread-local pools or rely on generational GC; the pool may be unnecessary. Profile in the rewrite before keeping or removing.
- **`sbhl-pred-has-caching-p` is a static decision** — set up at module init. A clean rewrite should make this dynamic so caches can grow and shrink based on observed query patterns.
- **`*implicit-fort-type-mapping*` is a side cache** that records "this FORT is implicitly type-X without an asserted isa." The set is hardcoded (predicates, microtheories, functions). A clean rewrite makes this a property on the FORT itself, set at creation time.
- **The file-vector backing is read-only at runtime** — mutations happen in memory and are flushed at save. This means SBHL doesn't track "dirty pages" for the file vector. The clean rewrite either preserves this (simpler, requires periodic flush) or implements proper write-through.
- **`get-sbhl-graph-link` acquires `*sbhl-rw-lock*` for every read** — fine for ad-hoc queries but expensive in a hot inference loop. The clean rewrite either batches lookups or uses lock-free data structures (snapshot-isolation via persistent hash tables).
- **Many `propagate-*-after-adding` functions are missing-larkc.** The mutation paths must be reconstructed from the link/mark machinery. The clean rewrite must implement these or the SBHL graph won't update on KB changes.
- **`sbhl-paranoia.lisp` provides type-checking that's compiled out in production.** Modern designs make this a debug-build assertion mechanism, not a per-call runtime check.
- **The graph store is per-MT-tagged at the edge level**, but search happens at the node level — meaning every edge fetch may walk past many irrelevant MT entries. A modern design indexes edges by MT explicitly so edge fetches are MT-filtered upfront.
- **The `:naut-forward-true-generators` mechanism** lets specific NAUT shapes (like `(#$DateFn …)`) generate implied edges for SBHL traversal — e.g. `#$DateFn` instances all `isa #$Date`. This is per-functor logic. Preserve as the extension mechanism for "compute-on-demand" edges.
- **`sbhl-min-X` and `sbhl-max-X` filter the closure** — keep only most-specific or least-specific results. Implemented as a second-pass filter over the closure result. A clean rewrite computes these incrementally during traversal (don't add a node if it's a genl of an already-added node, etc.).
- **Cache size policy (2% of graph) is heuristic.** Modern designs adapt based on hit rate.
- **The `:transfers-through-module` mechanism** — `:isa` walks `:isa` edges plus `:genls` edges of arg2 — is the polymorphism enabling cross-predicate inference. Preserve. Document the transfer-arg semantics (which arg position the transfer applies to).
- **`*sbhl-modules-initialized?*` is a one-shot init flag.** Forces explicit init order: SBHL must be initialized before any query. A clean rewrite makes initialization implicit / lazy where possible.
- **Stress-test stubs at the bottom of `sbhl-graphs.lisp`** (`stress-test-sbhl-graph-concurrent-swapping`, etc.) are missing-larkc. These are useful for verification; reconstruct in the rewrite.
- **Predicate-domain modules** (`genl-preds`, `genl-inverse`, `negation-preds`, `negation-inverse`) use different marking functions because nodes can be marked as "matched as predicate" or "matched as inverse." The collection-domain modules don't need this distinction. Preserve the split.
