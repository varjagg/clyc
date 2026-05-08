# Set

A **set of distinct keys** under a chosen equality test. In the clean port the implementation is a Common Lisp `hash-table` mapping every member to `T`; the membership test is the hash table's own `:test`. There is no separate struct — `set-p` is just `hash-table-p`, which the source comment flags as overfit.

`set` is the primary set abstraction in Cyc and is the recommended replacement for the older `set-contents` (see [set-contents.md](set-contents.md)).

## Why a wrapper exists at all

The readme entry for `set` says the type is "wrapped set-contents for some reason, maybe for its cfasl interface." Reading the file confirms that interpretation: the only thing `set` adds over a bare hashtable / over `set-contents` is the **CFASL serialization registration**:

| Opcode | Symbol | Reader |
|---|---|---|
| 60 | `*cfasl-opcode-set*` | `cfasl-input-set` |
| 67 | `*cfasl-opcode-legacy-set*` | reader is LarKC-stripped (`cfasl-input-legacy-set` is an active declareFunction with no body) |

`cfasl-input-set` reads `(test, size)` then delegates to `cfasl-input-set-contents` from `set-contents.lisp` to read `size` elements. The wire format is "set marker, equality test symbol, count, members…" — symmetric to dictionary's "marker, test, count, key/value pairs." Without the wrapper there'd be no opcode to dispatch on at load time.

The original `set-contents` was a list/keyhash hybrid that switched at a watermark. The current `set` was rewritten by the porter as "key→T hashtable" and now has the same backing as `set-contents` does after its own simplification. The two files are a duplicated layer; `set-contents` is flagged for deprecation in favor of `set`.

## Public API (`set.lisp`)

| Function / macro | Purpose |
|---|---|
| `(new-set &optional test size)` | Allocate. `test` defaults to `*new-set-default-test-function*` (`#'eql`); `size` is a hash-table size hint. |
| `(set-size set)` | `hash-table-count`. |
| `(set-empty? set)` | `hash-table-empty-p`. |
| `(set-member? element set)` | `gethash` — returns the raw `T` mapped value, or `nil`. |
| `(set-add element set)` | Insert. Returns `T` iff the element was *not* already present. The TODO at the call site notes this return-value contract is the only reason `set-add` can't be a single `(setf (gethash …) t)`. |
| `(set-remove element set)` | `remhash`. Returns `T` iff present. |
| `(clear-set set)` | `clrhash`; returns the cleared set. Original sizing is lost (TODO). |
| `(new-set-iterator set)` | Wraps the set in a hash-table iterator (see [runtime/iteration-search-map.md](../runtime/iteration-search-map.md)). |
| `(set-element-list set)` | `hash-table-keys`. |
| `(set-rebuild set)` | No-op pass-through (TODO: deprecate). The original `set-contents` rebuilt because keyhashes could degrade; the hashtable backend doesn't need it. |
| `(set-p obj)` | Alias of `hash-table-p`. |
| `(do-set (item set &optional done-form) body…)` | Iteration macro built on `maphash`. `done-form` is checked before the body runs each iteration. |

CFASL: opcode 60 is registered via `declare-cfasl-opcode` at file load time. The output side uses CL's generic-method dispatch and lives elsewhere in the dump pipeline; only the input side is in this file.

## Where `set` is consumed

Sets are heavily used as **registries of objects without a value payload** — places where existing code needs membership checks plus iteration, with neither ordering nor an associated value. Top consumers (~30+ files):

- **Inference module registries** — `inference-modules.lisp`, `inference-strategist.lisp`, the various `inference-worker-*.lisp`, `removal-tactician-datastructures.lisp`, `inference-balanced-tactician-datastructures.lisp`. `*removal-modules*`, `*conjunctive-removal-modules*`, `*solely-specific-removal-module-predicate-store*`, etc., are all `(new-set #'eq)`.
- **KB-mapping macros** — `kb-mapping-macros.lisp`, `kb-indexing-datastructures.lisp` use sets for "have-we-seen-this-term-yet" gating during fan-out.
- **Unification & bindings** — `unification.lisp`, `assertion-utilities.lisp`, `equality-store.lisp`, `at-utilities.lisp`, `at-var-types.lisp`.
- **Caches** — `somewhere-cache.lisp`, `mt-relevance-cache.lisp`, `predicate-relevance-cache.lisp` use sets for tracked-membership components.
- **Bookkeeping** — `bookkeeping-store.lisp`.
- **Inference body** — `inference/leviathan.lisp`, `inference/collection-intersection.lisp`, `inference/modules/preference-modules.lisp`, `inference/modules/transformation-modules.lisp`, `inference/modules/removal/removal-modules-conjunctive-pruning.lisp`, `inference/harness/inference-worker-*.lisp`.
- **CFASL itself** — `cfasl-kb-methods.lisp` reads sets back from the dump.

`set-utilities.lisp` provides four helpers (`set-union`, `set-intersection`, `construct-set-from-list`, `set-add-all`) on top of the type. They reach across the abstraction line — they call both `set-contents-size`/`copy-set-contents` from the deprecated layer and use `make-hash-table`/`gethash` directly. A clean rewrite folds these into the same module.

## Related files

- `set-contents.lisp` — see [set-contents.md](set-contents.md). Originally the storage backend; now redundant.
- `set-utilities.lisp` — set-of-sets operations layered on top.
- `keyhash` — formerly the large-set backend, now elided per readme. No `keyhash.lisp` exists in the port.

## Notes for a clean rewrite

- **Use the host hashtable directly.** Every `set` operation is a one-liner over a hashtable. The named API (`set-add`, `set-remove`, etc.) carries no information the host's `Set<T>` type doesn't already carry.
- **The `set-add` return contract is load-bearing in places.** Before deleting it, audit call sites — most discard the return, but a few use it to detect "first time we saw this." The host's set type usually has an "insert returns boolean" (Java's `Set.add`, Rust's `HashSet::insert`, Python's `set.add` does *not* — there it's `add` returns None and `len()` change is the witness). Pick a host type whose insert reports newness, or wrap it.
- **Drop `set-rebuild`.** Already a no-op.
- **`do-set` should become whatever the host's `for x in set` is.**
- **CFASL opcode 60 is the only thing that has to survive verbatim.** A clean rewrite still has to read existing dump files, so the wire format (`60, test-symbol, count, members…`) is permanent. The dispatch glue can shrink to one function — read test, allocate, read N members.
- **`set-p` overfits onto `hash-table-p`.** Source comment flags it as a TODO. If a caller ever needs to distinguish "set used as a set" from "hashtable used as a map," the current type system can't. A clean rewrite makes them distinct types or accepts that they're the same and removes the predicate.
- **Default test is `#'eql`.** A handful of callers explicitly pass `#'eq` (modules registered by symbol identity) or `#'equal` (formula-keyed sets). Preserve per-set test-function customization.
