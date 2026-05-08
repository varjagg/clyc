# Set-utilities

A thin layer of cross-set operations on top of the [`set`](set.md) type: union, intersection, and bulk-load helpers. The whole file is four functions and ~40 lines of code.

`set-utilities` is the *only* place in the port where set-of-sets operations are kept. Callers — caches, reasoning code, indexing — reach for these helpers whenever they need to combine multiple sets without writing the iteration manually.

## API

| Function | Purpose |
|---|---|
| `(set-union set-list &optional test)` | New set containing every element appearing in any of the input sets. `test` defaults to `#'eql`. |
| `(set-intersection set-list &optional test)` | New set containing elements present in every input set. |
| `(construct-set-from-list list &optional test size)` | Build a set from a list. `size` defaults to `(length list)` so the backing hashtable is sized correctly up front. |
| `(set-add-all elements set)` | Bulk-add a list of elements to an existing set. Mutates `set`, returns it. |

All four return a `set` (i.e. a `hash-table`) and accept the standard `set` test functions (`#'eql`, `#'eq`, `#'equal`, `#'equalp`).

## Implementation notes

Both `set-union` and `set-intersection` short-circuit:

- empty `set-list` → fresh empty set with the requested test.
- single-element `set-list` → `copy-set-contents` of that one set (preserves the original's test, not the supplied `test`).
- general case → fresh hashtable, fill via iteration.

`set-intersection` picks the smallest input as the iteration driver (`(extremal set-list #'< #'set-contents-size)`) so the per-element cost scales with `min(|S_i|)` rather than `|S_1|`. Each candidate is admitted only if `every` other set contains it.

The file reaches across the [`set`](set.md) / [`set-contents`](set-contents.md) abstraction line: it calls `copy-set-contents` and `set-contents-size` from the deprecated `set-contents` layer while constructing results with `make-hash-table`/`gethash` directly. A clean rewrite folds these helpers into the same module as `set` and removes the `set-contents` indirection.

A standing TODO in the source: `set-union`'s default `test` argument is `#'eql`, which means combining a `#'equal`-keyed set with the default flag silently downgrades to `#'eql`. Better default would be "copy the first set's test."

## Where it's used

| Consumer | What it uses |
|---|---|
| `predicate-relevance-cache.lisp` | `set-union` / `set-intersection` for combining relevance sets across MTs |
| `mt-relevance-cache.lisp` | `construct-set-from-list` to convert seed lists into membership sets |
| `assertion-utilities.lisp` | `construct-set-from-list` building lookup sets from query results |
| `kb-hl-supports.lisp` | `construct-set-from-list` |
| `inference/collection-intersection.lisp` | the namesake — `set-intersection` over collection-extension sets |
| `inference/harness/inference-abduction-utilities.lisp` | combining candidate sets across abduction steps |
| `inference/harness/inference-analysis.lisp` | `construct-set-from-list` |
| `inference/harness/inference-datastructures-inference.lisp` | bulk seed of inference state |
| `inference/harness/inference-heuristic-balanced-tactician.lisp` | building scored sets |
| `sbhl/sbhl-cache.lisp` | `set-add-all` for cache prepopulation |

The pattern: any time the caller has *several sets* and needs *one set* back, the call goes through here. Manual `dohash`-into-result loops are confined to `set-utilities` itself; everywhere else uses the named helpers.

## Notes for a clean rewrite

- **Fold into `set`.** Four functions in their own file is overhead. A modern set type provides `union`, `intersection`, `from_iter`, `extend` natively (Java `Set.addAll`, Rust `HashSet::union`, Python `set.union`). No per-Cyc API needed.
- **Fix the `test` default.** Inherit from the first input set, not from `#'eql`.
- **Drop `copy-set-contents` reach-around.** Once `set-contents` is gone (it's deprecated in favor of `set`), the single-input fast path becomes a plain `(copy-set ...)`.
- **`set-intersection` smallest-driver heuristic should stay.** The complexity argument is real, and a host's bulk-intersection often does the same.
- **`set-add-all` returns the mutated set** — convenient for chaining. Preserve in any rewrite that supports a fluent API; flag the mutation in the docs of strict-immutable rewrites.
- **No `set-difference` here.** If a clean rewrite needs it, add to the same module — there is no current caller in the port, but it's the obvious gap in a union/intersection API.
