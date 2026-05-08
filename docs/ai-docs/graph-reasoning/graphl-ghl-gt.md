# GraphL, GHL, and GT — Generic Graph Reasoning

A three-layer abstract graph-search framework, complementing SBHL ([sbhl.md](sbhl.md)) which is specialized for the canonical hierarchical predicates. GraphL/GHL/GT handle the *general case*: any user-declared transitive predicate, any combination of predicates, predicates that are not SBHL-managed.

The three layers (bottom to top):

| Layer | Role | Files |
|---|---|---|
| **GraphL** | Abstract graph-search framework — pure data shape (`graphl-search` struct) and traversal primitives. Predicate-agnostic, KB-agnostic. The substrate. | `graphl-search-vars.lisp`, `graphl-graph-utilities.lisp`, `graph-utilities.lisp` |
| **GT** | General Transitivity — search engine for non-SBHL transitive predicates. Walks the gaf-arg index of a predicate, applying transitive closure. The fallback when SBHL doesn't apply. | `gt-search.lisp`, `gt-methods.lisp`, `gt-utilities.lisp`, `gt-vars.lisp` |
| **GHL** | Graph Hierarchy Link — the *unified* dispatcher. Wraps GraphL state with predicate-and-TV awareness and dispatches per-predicate to either SBHL (for SBHL-managed preds) or GT (for everything else). The polymorphic entry point. | `ghl-search-utilities.lisp`, `ghl-search-methods.lisp`, `ghl-search-vars.lisp`, `ghl-link-iterators.lisp`, `ghl-marking-utilities.lisp` |

The abstract design lets one query code path (`(ghl-search v-search start-node)`) drive reasoning over `genls`, `geographicalSubRegions`, `temporallyContains`, or any other transitive predicate, without the caller knowing which storage shape is in use.

## When does this run?

Five triggering situations:

1. **A `gt-predicate-relation-p pred a b` query.** `(ghl-search-utilities.lisp gt-predicate-relation-p` — see `ghl-link-iterators.lisp`) — does the closure of `pred` from `a` reach `b`? Routes through GHL, which dispatches to SBHL (if `pred` is SBHL-managed) or GT.
2. **Forward/backward closure over a predicate.** `new-ghl-closure-iterator pred node direction &optional mt tv` — an iterator yielding every node reachable from `node` via `pred` in the given direction. Used by inference modules that need to enumerate transitive consequences.
3. **A justification request.** `why-gt-predicate-relation-p pred a b &optional mt tv` — like `gt-predicate-relation-p` but returns the proof: the chain of supports proving the relation. Used by the justification API.
4. **TVA (transitive value access) cache lookups.** TVA queries traversal results and caches them; GHL is the underlying engine.
5. **Inference removal modules call `new-removal-ghl-closure-iterator`.** Same as the standard closure iterator but with `return-non-transitive-results? = nil`, suppressing the start-node reflexivity. Used when a removal module wants strictly the non-trivial children/parents.

## GraphL — the data substrate

### `graphl-search` struct

```lisp
(defstruct graphl-search
  direction               ; :forward, :backward, or :accessible (both)
  type                    ; :transitive-reasoning, :one-step, etc.
  order                   ; :depth-first or :breadth-first
  cutoff                  ; max depth (per-search budget)
  marking                 ; marking strategy (:simple, etc.)
  marking-space           ; the marking hashtable
  goal-space              ; goal-detection hashtable
  goal                    ; target node, list of targets, or nil
  goal-fn                 ; predicate (search node) → bool — alternate goal test
  goal-found-p            ; flag set when goal is hit
  satisfy-fn              ; per-step satisfaction function
  map-fn                  ; per-node visitor
  justify?                ; should we collect justification supports?
  add-to-result?          ; per-node "should we accumulate this?" function
  unwind-fn-toggle        ; toggle for unwind-fn behavior
  result                  ; the accumulated result list
  graph)                  ; the graph being searched (when explicit)
```

`new-graphl-search plist` constructs and initializes from a plist. The initializer body for plist-keys is **missing-larkc 31969** — the clean rewrite must reconstruct, mapping each plist key to the corresponding setter.

`destroy-graphl-search` clears slots to `:free` for resource reclamation.

`graphl-add-to-result search addition &optional test` — `pushnew` onto the result list. `:eq`-keyed by default.

`possibly-initialize-graphl-marking-spaces search` — allocate marking-space hashtable if not yet set. Default size `*graphl-search-size*` = 200.

`graphl-instantiate-new-space` — `make-hash-table :size 200`.

### Direction handling

```
(graphl-forward-direction-p d) ≡ (eq d :forward)

(determine-graphl-relevant-directions :accessible) → (:forward :backward)
(determine-graphl-relevant-directions :forward)    → (:forward)
(determine-graphl-relevant-directions :backward)   → (:backward)
```

### `*graphl-finished?*`

A dynamic flag set by `set-graphl-finished` (and `ghl-resolve-goal-found`) to terminate the traversal early. `with-new-graphl-finished body` rebinds it to nil for body. `reset-graphl-finished` resets.

### Edge primitives (graphl-graph-utilities.lisp)

`graphl-node-p`, `graphl-edge-p`, `graphl-directed-edge-p`, `graphl-edge-label`, `graphl-edge-start-node`, `graphl-edge-end-node` — all active declareFunction, no body. The clean rewrite implements as defstructs/predicates if generic edge-data is needed.

`graphl-add-unwind-edges-now-p search` — gate for whether unwind-edges should be processed now (used by depth-first justification).

### graph-utilities.lisp

A small library of generic graph operations used by GraphL but not specific to it. Not detailed here; mostly missing-larkc.

## GT — General Transitivity

### Concept

GT is the search engine for **transitive predicates that are NOT SBHL-managed**. Examples: `#$geographicalSubRegions`, `#$temporallyContains`, `#$objectFoundInLocation`, user-defined transitive predicates.

For these predicates, there is no precomputed graph cache — GT walks the `gaf-arg` index directly. The traversal:

1. Find every assertion `(pred node ?x)` (via `do-gaf-arg-index node 1 pred`).
2. For each such assertion, the `?x` is a successor.
3. Recurse into `?x`.

`gt-predicate-p pred` ([`gt-vars.lisp`](../../../larkc-cycl/gt-vars.lisp)) — predicate registered as a GT predicate.

`gt-index-argnum-for-direction direction` — for forward search, `1`; backward, `2`. (Inverted by `*gt-args-swapped-p*` for spec-pred handling.)

`other-binary-arg argnum` — `1 → 2`, `2 → 1`.

### Variables (`gt-vars.lisp`)

```
*gt-relevant-pred*       nil   the predicate whose closure we're computing
*gt-args-swapped-p*      nil   whether args are flipped (spec-pred mode)
*relevant-pred-function* — set to relevant-pred-wrt-gt? during GT search
```

`relevant-pred-wrt-gt? pred` — true iff `pred` is `*gt-relevant-pred*` or one of its spec-preds. Allows `(geographicalSubRegions A B)` evidence to also fire on `(politicalSubRegions A B)` if `politicalSubRegions` is a spec-pred.

### Search methods (`gt-methods.lisp`, `gt-search.lisp`)

- `gt-predicate-relation-p pred node1 node2 &optional mt tv` — does the closure of `pred` reach `node2` from `node1`?
- `gt-predicate-relation-p-add-accessible-link-nodes-to-deck` — the per-step expansion (helper function).
- `why-gt-predicate-relation-p pred node1 node2 &optional mt tv` — same with justification.

The closure is stack-based (depth-first) by default, with the `search-deck` carrying the frontier. Marking spaces detect cycles. The MT and TV are honored at each step.

### `gt-utilities.lisp`

Helpers like `gt-relevant-predicates pred` — return the set of preds to walk during a GT closure (the pred plus its spec-preds, optionally).

## GHL — the unified dispatcher

### Concept

GHL wraps GraphL with **predicate-aware dispatch**: at each step of the closure, it asks "is this predicate SBHL-managed?" and routes to SBHL or to GT accordingly. This lets a single query handle mixed predicate sets — e.g. "the union of `genls` (SBHL) and `geographicalSubRegions` (GT)."

### `ghl-search` struct

```lisp
(defstruct ghl-search
  graphl-search           ; the underlying graphl-search
  predicates              ; the predicate or list of predicates
  tv)                     ; truth value (e.g. :true-def)
```

Mostly delegates to its inner `graphl-search` via accessors:

```
(ghl-result search)         → (graphl-result (ghl-graphl-search search))
(ghl-space search)          → (graphl-space (ghl-graphl-search search))
(ghl-direction search)      → (graphl-direction ...)
(ghl-compute-justify? s)    → (graphl-compute-justify? ...)
(ghl-goal s) (ghl-goal-fn s) (ghl-depth-first-search-p s)
```

The split (ghl-search wrapping graphl-search) is essentially struct inheritance; `;; TODO DESIGN - this also smells like structure inheritance` in the source. A clean rewrite uses real inheritance or composition with a clear contract.

### Defaults

`*ghl-search-property-defaults*`:

```
:direction → :forward
:tv        → :true-def
:order     → :breadth-first
```

`new-ghl-search plist` allocates a new `ghl-search`, allocates an inner `graphl-search`, applies defaults, then applies plist overrides via `set-ghl-search-property`.

### Property-setter dispatch

`set-ghl-search-property search property value` ([`ghl-search-vars.lisp:103`](../../../larkc-cycl/ghl-search-vars.lisp#L103)):

```
(case property
  (:predicates (set-ghl-search-predicates search value))
  (:direction  (set-graphl-search-direction graphl-search value))
  (:tv         (set-ghl-search-tv search value))
  (:type       (set-graphl-search-type graphl-search value))
  (:order      (set-graphl-search-order graphl-search value))
  (:cutoff     (missing-larkc 31965))
  (:marking    (set-graphl-search-marking graphl-search value))
  (:marking-space (set-graphl-search-marking-space graphl-search value))
  (:goal       (set-graphl-search-goal graphl-search value))
  (:goal-fn    (missing-larkc 31966))
  (:goal-space (missing-larkc 31967))
  (:satisfy-fn (missing-larkc 31970))
  (:map-fn     (missing-larkc 31968))
  (:justify?   (set-graphl-search-justify? graphl-search value))
  (:add-to-result? (missing-larkc 31964)))
```

Several of the missing-larkc setters are obvious one-liner accessors (`(setf (graphl-search-cutoff graphl-search) value)` etc.). The clean rewrite reconstructs these.

### Direction for predicate relation

```lisp
(defun ghl-direction-for-predicate-relation (pred)
  (if (eq 1 (fan-out-arg pred))
      :forward
      :backward))
```

`#$fanOutArg` is the predicate's "from" argument position. For `#$genls`, fan-out is 1 (first arg `Dog` is the from-side). For `#$geoSubRegion`, fan-out is 2 (second arg is the from-side; `(geoSubRegion USA Texas)` says Texas is "in" USA, so the natural direction from USA goes outward).

### Per-step expansion: `ghl-add-accessible-link-nodes-to-deck v-search node node-deck`

The big function ([`ghl-search-methods.lisp:62`](../../../larkc-cycl/ghl-search-methods.lisp#L62)). For each predicate in `(ghl-relevant-predicates v-search)`:

- **If `(sbhl-predicate-p pred)`**: route to SBHL — for each search direction, fetch the SBHL graph link, walk MT-links and TV-links, push every link-node onto the deck.
- **If `(gt-predicate-p pred)`**: route to GT — for each search direction, walk the `gaf-arg` index for `pred` at the index-argnum, push every gather-argnum value onto the deck. Optionally do a swapped pass for spec-pred coverage if `*ghl-uses-spec-preds-p*`.

The body of the function is ~130 lines because the GHL/SBHL/GT iteration macros referenced in the original (`do-ghl-accessible-link-nodes`, `do-gt-accessible-link-nodes`) weren't ported — the helper macros expanded inline to avoid the dependency.

### Closure iterators

```
(new-ghl-closure-iterator pred node direction &optional mt tv search-order return-non-transitive?)
```

Builds:
1. A new `ghl-search` with `:predicates (list pred)`, `:type :transitive-reasoning`, `:order :breadth-first` (default), `:direction direction`, `:tv tv`, `:marking :simple`.
2. Calls `new-ghl-closure-search-iterator v-search node mt reflexive? return-non-transitive?`.

`new-removal-ghl-closure-iterator pred node direction &optional mt` — same with `:order :breadth-first` and `return-non-transitive? = nil`. Used by removal modules.

`ghl-closure-search-iterator-state v-search start-node mt reflexive? return-non-transitive?`:

- Allocates a deck (stack for DFS, queue for BFS).
- Marks the start-node with `:start`.
- Initializes the deck with the start-node's accessible link nodes.

`ghl-closure-search-iterator-next state` — pop next node from deck, expand into more nodes, return.

`ghl-closure-search-iterator-done state` — deck empty.

`ghl-closure-search-iterator-finalize state` — release marking-space, clear state.

### Justification

`ghl-create-justification v-search supports`:

```
search-preds := the search's predicates (as list)
search-mt    := *mt*
search-tv    := (ghl-tv v-search)
sbhl-tv      := (support-tv-to-sbhl-tv search-tv)

for each support in supports:
  if (support-p support): cons onto justification
  support-pred := derive from support shape (assertion / hl-support / el-formula)
  unless support-pred ∈ search-preds:
    find a search-pred such that (genl-predicate? support-pred search-pred ...) = t
      → make hl-support :genlpreds (#$genlPreds support-pred genl-pred) ...
        and cons onto justification
    find a search-pred such that "genl-inverse?" holds (missing-larkc 7102)
      → make hl-support :genlpreds (#$genlInverse support-pred genl-inverse) ...
        and cons onto justification

return (fast-delete-duplicates (nreverse justification) #'equal)
```

This builds a justification list that includes the supports plus any additional `#$genlPreds` / `#$genlInverse` hl-supports needed to bridge the predicates. So a query "via genls" that finds a chain through `#$specs` (a spec-pred of `#$genls`) gets the bridging `(#$genlPreds #$specs #$genls)` hl-support attached automatically.

### Cardinality helpers

```
(ghl-predicate-cardinality pred node)
```

How many forward edges does `node` have under `pred`? Sum of:
- `sbhl-predicate-cardinality module node` — if SBHL-managed.
- 0 from SKSI (external relational data sources, mostly stripped).

`ghl-inverse-cardinality pred node` — backward edges. Same shape.

These are used by the planner to estimate traversal cost.

### Reflexivity

`ghl-node-admitted-by-some-reflexive-gaf v-search node` (missing-larkc) — does `node` have a gaf supporting reflexive treatment?

`ghl-add-reflexivity-justification v-search node pred` (missing-larkc) — append a reflexivity justification (e.g. `(genls X X)` for any X).

Reflexive predicates (`#$ReflexiveBinaryPredicate`) — the start-node is in its own closure result.

### Goal detection

`ghl-goal-node? v-search node &optional test`:

```
if (ghl-goal-fn v-search):                  ; explicit fn-based goal
  funcall (ghl-goal-fn ...) v-search node
else if (listp (ghl-goal v-search)):        ; multi-target
  member? node goal test
else:                                       ; single target
  funcall test goal node
```

When goal is found, `ghl-resolve-goal-found v-search node` sets `goal-found-p` and `*graphl-finished?*`, terminating the traversal.

## ghl-link-iterators.lisp

Defines `with-ghl-link-pred pred body` and `with-new-ghl-link-pred body` — bind the dynamic `*ghl-link-pred*` for the body. Used by per-step iteration to know which predicate's links are being walked.

`*gt-relevant-pred*` is the GT-domain analog.

## ghl-marking-utilities.lisp

Marking helpers analogous to SBHL's marking machinery, but operating on the `graphl-search-marking-space` hashtable. `ghl-mark-node v-search node mark` sets `marking-space[node] = mark` (e.g. `:start`, `:visited`, `:goal`, `:terminal`). Used by the closure walker to detect cycles and short-circuit.

## Public API surface

```
;; GraphL
(*graphl-search-size*)
(*graphl-finished?*)
(make-graphl-search) (graphl-search-p)
(new-graphl-search plist)
(destroy-graphl-search graphl-search)
(graphl-add-to-result search addition &optional test)
(graphl-direction s) (graphl-order s) (graphl-space s)
(graphl-compute-justify? s) (graphl-result s)
(graphl-search-goal s) (graphl-search-goal-fn s) (graphl-search-goal-found-p s)
(graphl-search-result s) (graphl-search-justify? s)
(graphl-search-marking-space s) (graphl-search-direction s)
(graphl-depth-first-search-p search)
(set-graphl-search-direction s d)
(set-graphl-search-type s t)
(set-graphl-search-order s o)
(set-graphl-search-marking s m)
(set-graphl-search-marking-space s ms)
(set-graphl-search-goal s g)
(set-graphl-search-goal-found-p s p)
(set-graphl-search-justify? s j)
(set-graphl-search-result s r)
(possibly-initialize-graphl-marking-spaces s)
(graphl-instantiate-new-space)
(graphl-forward-direction-p direction)
(determine-graphl-relevant-directions direction)
(with-new-graphl-finished &body body)
(set-graphl-finished)                                   ; missing-larkc body
(reset-graphl-finished)
(graphl-add-unwind-edges-now-p search)                  ; missing-larkc body
(graphl-node-p obj) (graphl-edge-p obj)                 ; missing-larkc body
(graphl-directed-edge-p obj)                            ; missing-larkc body
(graphl-edge-label edge) (graphl-edge-start-node edge) (graphl-edge-end-node edge)
                                                         ; all missing-larkc body

;; GT
(*gt-relevant-pred*) (*gt-args-swapped-p*) (gt-args-swapped-p)
(gt-predicate-p pred)
(relevant-pred-wrt-gt? pred)
(gt-index-argnum-for-direction direction)
(other-binary-arg argnum)
(gt-relevant-predicates pred)
(gt-predicate-relation-p pred node1 node2 &optional mt tv)
(why-gt-predicate-relation-p pred node1 node2 &optional mt tv)
(gt-predicate-relation-p-add-accessible-link-nodes-to-deck ...)

;; GHL search struct
(make-ghl-search) (ghl-search-p)
(new-ghl-search plist)
(destroy-ghl-search search)
(ghl-search-predicates s) (ghl-search-tv s) (ghl-search-graphl-search s)
(ghl-graphl-search s) (ghl-relevant-predicates s) (ghl-tv s)
(ghl-result s) (ghl-space s) (ghl-direction s)
(ghl-compute-justify? s) (ghl-goal s) (ghl-goal-fn s) (ghl-goal-found-p s)
(ghl-depth-first-search-p s)
(set-ghl-graphl-search s gs)
(set-ghl-search-predicates s ps)
(set-ghl-search-tv s tv)
(set-ghl-search-result s r)
(set-ghl-goal-found-p s p)
(set-ghl-search-property s prop val)
(set-ghl-search-properties s plist)
(ghl-set-result s r)
(ghl-add-to-result s addition &optional test)
(ghl-resolve-goal-found s node)
(ghl-goal-node? v-search node &optional test)
(ghl-goal-or-marked-as-goal? ...)                       ; missing-larkc body
(ghl-node-satisfies-pred-arg-type? ...)                 ; missing-larkc body
(ghl-search-property-default property)
(*ghl-search-property-defaults*)
(*ghl-uses-spec-preds-p*) (ghl-uses-spec-preds-p)
(ghl-direction-for-predicate-relation pred)
(ghl-forward-direction-p direction)
(ghl-predicate-cardinality pred node)
(ghl-inverse-cardinality pred node)

;; Iterators
(new-ghl-closure-iterator pred node direction &optional mt tv search-order return-non-transitive?)
(new-removal-ghl-closure-iterator pred node direction &optional mt)
(new-ghl-closure-search-iterator v-search start-node mt reflexive? return-non-transitive?)
(ghl-closure-search-iterator-state v-search start-node mt reflexive? return-non-transitive?)
(ghl-closure-search-iterator-done state)
(ghl-closure-search-iterator-next state)
(ghl-closure-search-iterator-finalize state)

;; Search methods (mostly missing-larkc)
(ghl-search v-search start-node)
(transitive-ghl-search v-search start-node)
(ghl-mark-and-sweep v-search start-node)
(ghl-unmark-and-sweep v-search start-node)
(ghl-mark-sweep-until-goal v-search start-node)
(ghl-unmark-sweep-and-map v-search start-node)
(ghl-mark-and-sweep-df v-search start-node)
(ghl-unmark-and-sweep-df v-search start-node)
(ghl-mark-and-sweep-bf v-search start-node)
(ghl-unmark-and-sweep-bf v-search start-node)
(ghl-mark-and-sweep-iterative-df ...)
(ghl-mark-and-sweep-iterative-bf ...)
(ghl-mark-and-sweep-depth-cutoff ...)
(ghl-all-edges-iterative-deepening-initializer ...)
(*ghl-mark-and-sweep-recursion-limit*)                  ; default 24

;; Per-step expansion
(ghl-add-accessible-link-nodes-to-deck v-search node node-deck)
(ghl-add-accessible-link-nodes-and-supports-to-deck ...) ; missing-larkc body
(ghl-add-justification-to-result v-search justification)
(ghl-create-justification v-search supports)
(ghl-add-support-to-result v-search support)            ; missing-larkc body
(ghl-add-gt-assertion-to-result v-search assertion)     ; missing-larkc body
(ghl-add-sbhl-assertion-to-result v-search link-node mt tv pred sense) ; missing-larkc body
(ghl-add-reflexivity-justification v-search node pred)  ; missing-larkc body
(ghl-node-admitted-by-some-reflexive-gaf v-search node) ; missing-larkc body
(ghl-remove-unneeded-supports supports)                 ; missing-larkc body

;; Link-pred binding
(*ghl-link-pred*)
(with-ghl-link-pred pred &body body)
(with-new-ghl-link-pred &body body)
(get-ghl-link-pred)                                     ; missing-larkc body

;; Marking
(ghl-mark-node v-search node mark)                      ; in ghl-marking-utilities
(ghl-marked? v-search node)
(*ghl-trace-level*)                                     ; default 1

;; SKSI integration
(*sksi-gt-search-pred*)
```

## Consumers

| Consumer | What it uses |
|---|---|
| **TVA** (`tva-cache.lisp`, `tva-inference.lisp`) | `new-ghl-closure-iterator`, `gt-predicate-relation-p`, `why-gt-predicate-relation-p` for cached transitive-value lookups |
| **Removal modules** (`inference/modules/removal/*.lisp`) | `new-removal-ghl-closure-iterator` to enumerate closure non-trivially |
| **Justification API** | `why-gt-predicate-relation-p` for explanation paths |
| **Inference workers** | `ghl-search` for general transitive-reasoning queries that span SBHL and GT preds |
| **`gt-search.lisp`** | builds on `ghl-link-iterators.lisp` for the actual closure walks |

## Notes for a clean rewrite

- **The three-layer split is not pulling weight.** GraphL has almost no behavior — its struct is essentially a search-config bag. GT and GHL are tightly coupled (GT's iteration helpers live in `ghl-link-iterators.lisp`). A clean rewrite collapses to two layers: a per-pred dispatch (SBHL vs general) plus a unified search engine. The `graphl-search` struct becomes the single search-state.
- **The `ghl-search` wrapping a `graphl-search` is awkward struct-inheritance.** The source comment notes this. Use real inheritance or composition with a clear interface.
- **Most search methods are missing-larkc.** `ghl-search`, `transitive-ghl-search`, `ghl-mark-and-sweep` (and DF/BF variants), `ghl-mark-and-sweep-depth-cutoff`, `ghl-all-edges-iterative-deepening-initializer` — all stripped. The clean rewrite reconstructs these from the patterns in `ghl-add-accessible-link-nodes-to-deck` and the closure iterator.
- **The per-step dispatch on `(sbhl-predicate-p pred)` vs `(gt-predicate-p pred)`** branches into two ~50-line bodies that handle MT/TV iteration differently. Refactor into a per-pred-kind protocol with a single `expand-node-via-pred` interface.
- **The `:cutoff`, `:goal-fn`, `:goal-space`, `:satisfy-fn`, `:map-fn`, `:add-to-result?` setters are missing-larkc** — trivial accessor wrappers, but absence means callers can't use these properties. Clean rewrite reconstructs.
- **`*ghl-mark-and-sweep-recursion-limit*` = 24** is hardcoded. A modern design makes this configurable per-search; deep ontologies (especially `#$genls` chains in Cyc) regularly exceed 24.
- **The `*ghl-uses-spec-preds-p*` toggle** controls whether GT closure walks spec-preds (so a query "via geoSubRegion" also catches "via politicalSubRegion"). Default t. Useful but underdocumented; a clean rewrite makes the spec-pred-set explicit per search.
- **Justification building (`ghl-create-justification`)** automatically inserts `#$genlPreds` and `#$genlInverse` hl-supports when a support's predicate is a generalization of a search-pred. The `(missing-larkc 7102)` for `genl-inverse?` must be implemented — currently the inverse case is unreachable.
- **`graphl-search-vars.lisp` ports the struct but leaves slot-init missing-larkc** — `new-graphl-search` can't currently respect a plist. Clean rewrite implements the plist-to-setter dispatch.
- **`graph-utilities.lisp` and `graphl-graph-utilities.lisp` overlap.** Both are general graph utilities; the split is historical. Consolidate.
- **GT walks the gaf-arg index per closure step** — every step is one `do-gaf-arg-index` iteration, scaling with the per-node fan-out. For dense predicates this is expensive. A clean rewrite considers caching per-pred-per-node successor sets, similar to SBHL's graph cache but for general transitive predicates.
- **`*sksi-gt-search-pred*`** integration with SKSI (external relational sources) is mostly missing-larkc. The infrastructure assumes a working SKSI which the LarKC distribution doesn't have.
- **The `:order :depth-first` vs `:breadth-first` choice** affects the deck (stack vs queue). A clean rewrite considers iterative-deepening (DFS with progressively-deeper bounds) as a third option for unbounded graphs.
- **`ghl-direction-for-predicate-relation`** uses `#$fanOutArg` to decide direction. This is a useful heuristic but not always right — symmetric predicates have ambiguous direction. A clean rewrite either (a) always supports both directions for symmetric preds, or (b) rejects the question outright when fanOutArg is unset.
- **The `ghl-add-justification-to-result` / `ghl-add-to-result` separation** — one for batch (`ghl-add-justification-to-result` calls `ghl-add-to-result` per support), one for single. Collapse; the batch version is just the single in a loop.
- **`*ghl-trace-level*` = 1** is a debug verbosity knob, but no `ghl-note` / `ghl-trace` printer survives. Clean rewrite hooks into a structured logging system.
