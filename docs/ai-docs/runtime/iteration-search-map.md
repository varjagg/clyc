# Iteration, search, map, hierarchical-visitor

A grab-bag of generic-traversal abstractions. Four small files, all of which would be one-liners or single-call-site primitives in a modern language. They exist as separate machinery in Cyc because SubL didn't have language-level iterators, generic dispatch, or sequence protocols.

| File | Lines | Purpose |
|---|---|---|
| `iteration.lisp` | 326 | Cooperative iterator protocol — a struct with `state`, `done`, `next`, `finalize` callbacks. Constructors for list, hashtable, singleton, indirect (transformed), filter, iterator-of-iterators. |
| `search.lisp` | 205 | Generic graph-search framework — a `search-struc` with 14 callbacks (no-leaves-p, next-node, goal-p, expand, add-node, …). Supports BFS, DFS, A*-like by parameterising the callbacks. **Mostly missing-larkc.** |
| `map-utilities.lisp` | 63 | Tiny: aliases for hashtable ops under `map-` names (`map-p`, `map-size`, `map-empty-p`, `map-get`, `map-put`, `map-remove`). Author's TODO: deprecate the file in favour of using hashtables directly. |
| `hierarchical-visitor.lisp` | 100 | Visitor-pattern struct with five callbacks (begin-path / end-path / accept-node / begin-visit / end-visit). **Almost entirely missing-larkc.** |

The general theme: **abstractions that exist for genericity but don't carry their weight in the LarKC port** — most of the implementations are stripped, and the abstractions are mostly used only by code paths that are themselves stripped.

## Iteration: the iterator protocol

The core: an `iterator` is a struct holding four callbacks plus state.

```
(defstruct (iterator (:conc-name "IT-"))
  state          ; arbitrary; the iterator's internal state
  done           ; (state) → bool: is iteration finished?
  next           ; (state) → (item next-state premature-end?)
  finalize)      ; (state) → bool: cleanup
```

The protocol functions:

| Function | Purpose |
|---|---|
| `(new-iterator state done next &optional finalize)` | Construct. |
| `(iteration-done iterator)` | Calls `done` on `state`. |
| `(iteration-next iterator)` | Calls `next`; returns 2 values: `(item, valid?)`. Updates state in place. |
| `(iteration-next-without-values iterator &optional invalid-token)` | Single-value variant; returns `invalid-token` instead of `(values nil nil)`. |
| `(iteration-finalize iterator)` | Calls `finalize`. |
| `(map-iterator function iterator)` | Apply function to each item. |

The `do-iterator-without-values-internal` macro is the iteration sugar — `(do-iterator-without-values-internal (var iter :invalid-token tok :done halt-cond) body)` consumes an iterator with the body executed for each item.

### Built-in iterator constructors

| Constructor | Purpose |
|---|---|
| `new-list-iterator list` | Iterate over a list. State = the cons-tail. |
| `new-hash-table-iterator ht` | Iterate over `(key value)` tuples. CL port pre-collects pairs (vs. SubL which iterated keys-then-gethash). |
| `new-alist-iterator alist` | List of `(key . value)`, iterates as tuples `(key value)`. |
| `new-singleton-iterator item` | Iterates over a single item. |
| `new-indirect-iterator iter &optional transform finalize` | Wraps another iterator; applies `transform` to each item. |
| `new-filter-iterator-without-values input filter-method &optional filter-args invalid-token` | Wraps; only emits items for which `(apply filter-method item filter-args)` is non-NIL. |
| `new-iterator-iterator iterators` | Concatenates a list of iterators. Empty case is `missing-larkc 22987`; singleton just returns the inner iterator. |

The `new-filter-iterator` (with values) and several other constructors are missing-larkc. Inference and KB-mapping code use these constructors heavily where they survive.

### When does an iterator come into being?

Whenever a piece of code wants **lazy traversal of a sequence** rather than computing the whole list upfront. Common situations:

- **KB mapping**: `do-X-for-term` iterators yield assertions/constants matching a query, one at a time, so the consumer can stop early.
- **Inference**: tactics produce candidate proofs lazily; an iterator over candidates lets the strategist pick the next one without materialising the whole space.
- **Bulk operations**: visiting every constant in the KB; the iterator yields constants one at a time so memory stays bounded.

### The struct vs. closure tradeoff

Author's TODO at the top of the file:

> this will likely run faster if done/next/finalize are 3 functions returned from a single closure around STATE, although loses decoupling.

The current design: separate `state`, `done`, `next`, `finalize` slots. Each call passes `state` to the function. SubL's compiler can specialise on the function symbol; CL's can't reliably.

A closure-based iterator would have the function bodies capture `state` directly. The CL port keeps the struct because the original was a struct and rewriting all callers was out of scope. A clean rewrite probably uses generators (CL's `cl-cont` / Python's `yield` / Rust's `Iterator` trait).

### When does an iterator change or disappear?

| Trigger | Effect |
|---|---|
| `(iteration-next iter)` returns `(values item t)` | Mutates `(it-state iter)` to the new state. |
| `(iteration-next iter)` returns `(values nil nil)` | Iteration done. The state typically becomes `:done` or NIL. |
| Iterator-iterator's inner iterator finishes | The iterator-iterator pops its `working-state` and either advances to the next inner iterator or signals premature-end if no more. |
| Filter iterator's input ends | `state` becomes `'(:done . nil)`; the next call returns invalid. |
| `(iteration-finalize iter)` called | Runs `finalize` callback. **Often missing-larkc** — author's TODO notes finalization rarely fires. |

The TODO at the file header notes: "finalizers seem to be missing-larkc even though they're referenced by name. Finalization is probably never called?" This is the resource-leak risk — a file-iterator that holds an open file handle would leak if its finalize were never called. The current code mostly avoids this by using only memory-only iterators.

## Search: generic graph search

`search-struc` is the **search-state record** for a generic search algorithm. The struct has 14 slots:

```
(defstruct search-struc
  tree                  ; the search tree built so far
  leaves                ; current leaves to expand
  goals                 ; goal nodes found so far
  no-leaves-p-func      ; (state) → bool: no more leaves?
  next-node-func        ; (state) → next node to expand
  goal-p-func           ; (node state) → bool: is this node a goal?
  add-goal-func         ; (node state) → state with goal added
  options-func          ; (node) → list of next-options (e.g. successors)
  expand-func           ; (node options state) → state expanded
  add-node-func         ; (parent options state) → state with new children
  too-deep-func         ; (node state) → bool: prune?
  state                 ; arbitrary user state
  print-func            ; for debugging
  limbo                 ; nodes neither leaves nor goals
  current-node)         ; node being processed now
```

Plus a `search-node`:

```
(defstruct (search-node (:conc-name "SNODE-"))
  search parent children depth options state)
```

A search-node tracks the parent for path reconstruction and stores per-node state.

`*search-struc-free-list*` and `*search-struc-free-lock*` together implement an **object pool** — search-strucs are reused across searches to avoid GC pressure. The pool would have routines `get-search-struc` (pop or allocate) and `free-search-struc` (push back) — both LarKC-stripped.

### When does a search happen?

The entry point would be `(new-search no-leaves-p-func next-node-func goal-p-func add-goal-func too-deep-func options-func expand-func add-node-func &optional state print-func)` — gather the eight callbacks plus optional state, allocate a search-struc, run the loop. **All search routines are LarKC-stripped.**

In Cyc the engine, this generic-search framework was used by:

- The agenda's task scheduling (search through the priority queue).
- Some now-stripped diagnostic / KB-introspection commands.
- Possibly inference's lookahead (LarKC has its own dedicated search code in `inference/harness/`, but the generic search may have been used for non-inference graph traversals like NL parsing).

### The 14-callback design

The search-struc is **completely parameterised** — every behaviour is a callback. This means one struct handles BFS (where `next-node-func` returns the front of `leaves`), DFS (returns the end), best-first (returns the min by some metric), bidirectional (use two search-strucs and intersect goals), etc.

The cost is that the implementation is a thin loop over callbacks with no specialisation — every step is a funcall. Real Cyc's search code (`backward.lisp`, the inference-tactician family) is hand-written for the inference case and ignores this framework entirely.

A clean rewrite probably drops `search.lisp` — modern languages have search libraries; the inference engine has its own bespoke code; nothing else needs the abstraction.

## Map utilities

The most clearly-deprecated file. The whole content is:

```
(symbol-mapping map-p hash-table-p
                map-size hash-table-count
                map-empty-p hash-table-empty-p
                map-get-without-values map-get)

(defun* map-put (map key value) (:inline t)
  (setf (gethash key map) value))

(defun* map-get (map key &optional default) (:inline t)
  (gethash key map default))

(defun* map-remove (map key) (:inline t)
  (remhash key map))

(defun new-map-iterator (map)
  (new-hash-table-iterator map))
```

`symbol-mapping` (a SubL idiom for "map this symbol to that one") aliases `map-p` to `hash-table-p`, etc. The file is a literal alias layer.

The author's TODO at the top:

> These utilities abstract Dictionary & hashtable. But since we eliminated dictionary and only work on hashtables, this is moot. Deprecate all of this and wrap into hash-table-utilities.

The file existed because Cyc had two incompatible map types (`dictionary` and `hash-table`); the `map-X` aliases let code work with either. The dictionary is being phased out in favour of hashtables — at which point the alias layer is pointless.

Use sites: callers that say `(map-get table key default)` instead of `(gethash key table default)` — there are some, but a clean rewrite either inlines them at call sites or uses the host's hashtable API directly.

## Hierarchical visitor

A visitor-pattern struct for **traversing tree-like KB structures** with per-event callbacks:

```
(defstruct (hierarchical-visitor (:conc-name "HIER-VISIT-"))
  begin-path-fn        ; called at start of each new path
  end-path-fn          ; called when a path is complete
  accept-node-fn       ; called for each node visited
  begin-visit-fn       ; called once at start of whole visit
  end-visit-fn         ; called once at end of whole visit
  param)               ; user-supplied parameter passed to all callbacks
```

The five-callback design covers DFS-with-context: callers know about path entries (descending into a subtree), path exits (returning), and node visits. `param` is a user state holder threaded through every call.

`*default-hierarchical-visitor-noop-callback*` is `#'false` — used when a callback isn't needed (always returns NIL). Saves callers from having to write `(constantly nil)` shims.

### Surviving entry points

```
new-hiearchical-visitor begin-path end-path accept-node begin-visit end-visit &optional param
new-simple-hierarchical-visitor begin-path accept-node end-path &optional param
hierarchical-visitor-begin-visit visitor
hierarchical-visitor-end-visit visitor
show-hierarchical-visitor-node visitor node
show-hierarchical-visitor-path-begin visitor path
show-hierarchical-visitor-path-end visitor path
set-hierarchical-visitor-parameter visitor param
get-hierarchical-visitor-parameter visitor
new-hierarchical-print-visitor
print-hier-visitor-begin-visit / end-visit / begin-path / end-path / accept-node
new-no-op-hierarchical-visitor
```

All LarKC-stripped. Only the struct + its accessors survive. The visitor is a design surface with no implementation.

### When would it be used?

In Cyc the engine, hierarchical visitors would walk:

- **The genls / isa hierarchy** when generating a description of a constant ("X is a Y, which is a Z, which is...").
- **KB-content reports** that print out subtree structure.
- **Validation passes** that need to know "we're now descending into the third path of the second branch."

In the LarKC port, none of these consumers survive in working form. The visitor is unused.

## How other systems consume these

- **Iteration** is consumed extensively by KB-mapping (`kb-mapping.lisp`, `kb-indexing.lisp`), inference (each tactic produces an iterator over candidate proofs), and any place that wants lazy sequences. ~100 call sites of `iteration-next` / `do-iterator-without-values-internal`.
- **Search** has no surviving consumers — every caller is itself stripped.
- **Map-utilities** has scattered consumers — code that pre-dates the dictionary deprecation. Maybe ~50 call sites.
- **Hierarchical-visitor** has no surviving consumers.

## Notes for a clean rewrite

### Iteration

- **Use the host language's iterator/generator/Iterator protocol.** CL has loop and iterator libraries. Python has generators. Rust has Iterator. JavaScript has Symbol.iterator. The Cyc-specific protocol adds nothing.
- **Lazy iteration is the only thing iterators give you that other patterns don't.** Most callers want lazy because their consumer can stop early (find the first proof, find the first match, etc.). A clean rewrite should make laziness the default.
- **Drop `finalize`.** It's mostly never called and the cases where it matters (resource cleanup) should use the host's `with-resource` / `try-with-resources` / RAII pattern.
- **The transform/filter/concatenate constructors are functional combinators.** Modern languages provide these (`map`, `filter`, `flatten`/`flatMap`, etc.). Use them.
- **`new-hash-table-iterator` pre-materializes the pairs.** That's not lazy! The TODO comment notes this is a deliberate simplification because GETHASH-during-iteration was slow. A clean rewrite should use the host's hashtable iterator directly (most are lazy and well-optimized).
- **`do-iterator-without-values-internal` macro is the right shape.** Keep something like it (`for item in iterator`); just align with the host's syntax.

### Search

- **Drop the file.** The 14-callback abstraction is a generic graph-search library. Modern languages have these. Inference has its own bespoke code that doesn't use this framework. Nothing else needs it.
- **The free-list / pool is premature optimisation.** Modern GCs handle short-lived allocations well. Don't pool search-strucs unless profiling shows you must.
- **Hand-rolled BFS / DFS is fine in 2026.** A function with explicit queue/stack is clearer than 14 callbacks parameterising a meta-loop.

### Map-utilities

- **Delete the file. Use hashtables directly.** The author's TODO is right: there's no second map type to abstract over.

### Hierarchical visitor

- **Drop the file.** The visitor pattern is fine; the implementation here is missing. If a clean rewrite needs tree traversal with callbacks, write a 20-line `(defun walk-tree (tree begin-path end-path accept-node))` directly at the call site.
- **If you want a real visitor pattern, use the host's CLOS / interfaces / traits.** Generic-function dispatch on node type is cleaner than callback slots on a struct.
