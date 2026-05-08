# Set-contents (deprecated)

> **Deprecation flag:** the readme lists `set-contents` under "Deprecated" with the note *"A set, stored in a list when small, keyhash when large. Converted to use only a hashtable backend, though should be deprecated in favor of `set`."* The file's own header comment goes further: "TODO - mark all functions as deprecated." Treat `set-contents` as a redundant peer of `set` (see [set.md](set.md)) — every operation has a one-line equivalent there.

`set-contents` was originally the **storage backend** for `set`: a polymorphic value that started as a single SubL value, promoted to an unboxed list at low cardinality, and switched to a manually-implemented `keyhash` (key→T hash table) above a watermark. The readme's complaint about that design — "introspection is pretty dangerous if you're using lists as data elements" and "this one keeps lists up to 128 elements, which is nuts" — explains why the watermark logic was thrown out.

In the current port, **`set-contents` is just a `hash-table`** with the same membership-as-key, value-is-`T` shape `set` uses. The list/keyhash promotion path is gone.

## Why the type still exists

Three reasons it hasn't been deleted yet:

1. **CFASL chaining.** `cfasl-input-set-contents` (this file) is called by `cfasl-input-set` (in `set.lisp`). The set-level reader handles `(opcode, test, size)` then hands off to the set-contents reader for the size body. Splitting them was useful in the original because a set-contents could appear inline as part of a *larger* container (`bag`'s `unique-contents` was a set-contents, not a set). With native CL, the helper could be inlined into `cfasl-input-set` and the file deleted.
2. **`bag` references it.** `bag.lisp`'s `do-bag-unique-contents` macro expands to `do-set-contents` (the macro, not defined in this file but expected by name). The bag port is itself missing-larkc, so the dependency is on paper only.
3. **Call-site momentum.** Around 20 files still call the `set-contents-*` API. None of them care that the storage is hashtable-only.

## Public API (`set-contents.lisp`)

| Function | Purpose |
|---|---|
| `(new-set-contents &optional size test)` | Allocate a hashtable with the given test (default `#'eql`) and size hint. |
| `(copy-set-contents set-contents)` | Allocate a fresh hashtable with the source's test and size, copy each pair via `maphash`. Used by `set-utilities.lisp` for `set-union`/`set-intersection`. |
| `(set-contents-size set-contents)` | `hash-table-count`. |
| `(set-contents-empty? set-contents)` | `hash-table-empty-p`. |
| `(set-contents-singleton? set-contents)` | `(= 1 hash-table-count)`. |
| `(set-contents-member? element set-contents)` | `gethash`. |
| `(set-contents-add element set-contents)` | `(setf (gethash …) t)`; returns the set-contents (not a freshness flag — different contract from `set-add`). |
| `(set-contents-delete element set-contents)` | `remhash`; returns the set-contents. |
| `(clear-set-contents set-contents)` | `clrhash`. |
| `(new-set-contents-iterator set-contents)` | Eagerly materializes `hash-table-keys` and wraps in a `new-list-iterator`. The TODO note explains this is wasteful but a closure-based hashtable iterator was undefined behaviour in SubL. |
| `(cfasl-input-set-contents stream set-contents size)` | Read `size` elements from `stream`, add each to the in-progress `set-contents`. Called from `cfasl-input-set` in `set.lisp`. |
| `(set-contents-element-list set-contents)` | `hash-table-keys`. |
| `(set-contents-rebuild set-contents)` | No-op. The original keyhash backend needed periodic rehash; the host hashtable does not. |

There is no `set-contents-p` predicate; the source comment at the top of the file explains this is intentional ("Degenerate, there's no wrapper") because the type is exactly `hash-table` and would alias `hash-table-p`.

## CFASL

No own opcode. `cfasl-input-set-contents` is invoked by `cfasl-input-set` (opcode 60) and would be invoked by the `bag` reader (opcode 62) if `bag` were not stripped. The output side is generic-method dispatch in the dump pipeline.

## Where `set-contents` is consumed

About 20 files call the `set-contents-*` family directly. The pattern is consistently "object owns a small unordered collection where the *only* operations are add / membership / iterate / count":

- **Inference state** — `inference-datastructures-problem.lisp`, `inference-datastructures-strategy.lisp`, `inference-datastructures-proof.lisp`, `inference-strategic-heuristics.lisp` (heaviest user, ~12 sites), `inference-min-transformation-depth.lisp`, `inference-balanced-tactician-strategic-uninterestingness.lisp`, `inference-tactician-strategic-uninterestingness.lisp`, `inference-balanced-tactician-motivation.lisp`, `removal-tactician-motivation.lisp`. Argument-link sets, dependent-link sets, completed-tactic sets — all use `set-contents`.
- **Caches** — `mt-relevance-cache.lisp`, `predicate-relevance-cache.lisp`.
- **KB systems** — `kb-hl-supports.lisp`, `xref-database.lisp`.
- **Inference modules** — `inference/modules/transformation-modules.lisp`, `inference/modules/removal/removal-modules-conjunctive-pruning.lisp`, `inference/harness/inference-worker-restriction.lisp`.
- **Set utilities** — `set-utilities.lisp` reaches across the abstraction (calls `copy-set-contents`, `set-contents-size` while building hashtables directly).
- **Bag** — `bag.lisp`'s reconstructed `do-bag-unique-contents` macro depends on `do-set-contents` macro existing.

There is no caller outside the porter's own ecosystem.

## Notes for a clean rewrite

- **Delete the file.** Every operation is a one-liner over the host's `Set<T>` / `HashSet<T>` / `dict[k]=True`-equivalent. The `set` doc covers all the same surface area.
- **Migrate callers to the `set` API as a single rename pass.** `new-set-contents → new-set`, `set-contents-add → set-add`, etc. Watch for the `set-add`-vs-`set-contents-add` return-value contract difference: `set-add` returns "was-new?", `set-contents-add` returns the set itself. About a dozen call sites rely on the chained-return form (`(setf (slot obj) (set-contents-add x (slot obj)))`).
- **Inline `cfasl-input-set-contents` into `cfasl-input-set`.** No other reader needs it (bag's reader is stripped and would have its own opcode anyway).
- **Drop `set-contents-rebuild`.** No-op.
- **The eager-materialization in `new-set-contents-iterator` is a pessimization.** A clean rewrite uses the host's hashtable iteration directly — the SubL "undefined behavior under mutation" concern is gone.
