# Dictionary (deprecated)

> **Deprecation flag:** the readme lists `dictionary` under "Deprecated" with the note *"Key/value storage backed by an a-list when small, and a hashtable when large. Elided in preference to standard hashtables."* The file's own header comment states: *"DEPRECATED: The SubL dictionary type is elided in preference to standard CL hash tables. Only non-obvious functionality is retained here."* All core constructors and accessors (`new-dictionary`, `dictionary-p`, `do-dictionary`, `do-dictionary-progress`) are commented-out in the source — callers are expected to use `make-hash-table` / `gethash` / `maphash` directly.

A SubL `dictionary` was a **promotion-style key→value map**: a-list while element count was below a watermark, hash table above it. The promotion cutoff was tuned for SubL's allocator and predates modern hash tables, where the rule of thumb is "switch around 10 elements." With CL's native hashtable carrying very low overhead even when sparse, the polymorphism stops paying for itself.

The two source files form a thin remnant:

| File | Role |
|---|---|
| `dictionary.lisp` (96 lines) | CFASL deserialization for opcode 61. Core API commented out. |
| `dictionary-utilities.lisp` (123 lines) | A handful of higher-order operations on hashtable values (push/pushnew, plist-valued lookup, increment, sort), plus a thin `synchronized-dictionary-*` wrapper around SBCL synchronized hashtables. |

## Public API

### `dictionary.lisp` — surviving definitions

| Function / opcode | Purpose |
|---|---|
| `*cfasl-opcode-dictionary*` (61), `cfasl-input-dictionary` | Reader: pulls `(test, size)` then `size` `(key, value)` pairs into a fresh `make-hash-table`. |
| `*cfasl-opcode-legacy-dictionary*` (64) | Constant for the legacy-format opcode. Reader is LarKC-stripped (`cfasl-input-legacy-dictionary` is an active declareFunction with no body). |

The whole core API (`dictionary-p`, `new-dictionary`, `do-dictionary`, `do-dictionary-progress`) is **commented-out** inside a `#| ... |#` block. The block exists as documentation; nothing in the system loads it. Callers that need a CL hashtable use the host calls directly.

### `dictionary-utilities.lisp` — actually defined

| Function | Purpose |
|---|---|
| `(dictionary-push dictionary key value)` | Cons `value` onto whatever's at `key`. Errors if the existing value isn't a list. |
| `(dictionary-pushnew dictionary key val &optional test key-accessor)` | Same but uses `member :test :key`. |
| `(dictionary-getf dictionary key indicator &optional default)` | Treat the value at `key` as a plist, look up `indicator`. |
| `(dictionary-putf dictionary key indicator value)` | Treat the value at `key` as a plist, set `indicator → value`. |
| `(dictionary-delete-first-from-value dictionary key elt &optional test)` | Delete the first matching element from the list at `key`; remove the entry entirely if the list becomes empty. |
| `(dictionary-increment dictionary key &optional increment)` | `(incf (gethash key dict 0) increment)`. Used as a multiset/histogram primitive. |
| `(new-dictionary-from-alist alist &optional test)` | `alexandria:alist-hash-table`. |
| `(dictionary-has-key? dictionary key)` | Returns `(nth-value 1 (gethash key dict))` — the *presence* flag, not the value. |
| `(new-synchronized-dictionary &optional test size)` | `make-hash-table :synchronized t` (SBCL extension). |
| `(clear-synchronized-dictionary dict)` | `clrhash`. |
| `(synchronized-dictionary-enter dict key value)` | `(setf gethash …)`. |
| `(synchronized-dictionary-remove dict key)` | `remhash`. |
| `(synchronized-dictionary-lookup dict key &optional default)` | `gethash`. |
| `(synchronized-dictionary-keys dict)` | `hash-table-keys` under `with-locked-hash-table`. |
| `*dictionary-keys-sorter-current-sorting-information*` | Dynamic var that *would* be bound by `dictionary-keys-sorted-by-values` (LarKC-stripped). Exists as a placeholder. |

## Why a dictionary type existed in the first place

The SubL design rationale: **memory and locality on small dicts**. A 3-entry hashtable is several hundred bytes (buckets, count, rehash threshold, etc.); a 3-entry alist is six conses. For a system that creates millions of small per-term dictionaries during indexing and inference, the storage difference adds up. The promotion-on-grow approach kept small dicts cheap and large dicts fast.

What killed it for the port:

- **CL hashtables are already pretty small.** SBCL's empty hashtable is about 30 words; alist 0 conses. The cliff is real, but SBCL's GC and allocator absorb it well enough that the polymorphism cost wins overall.
- **The promotion logic is a switch on the value's `consp` / `hash-table-p`.** Every primitive (`dictionary-add`, `dictionary-lookup`, `do-dictionary`) had to dispatch. Modern profilers show the dispatch cost dominates the storage savings on hot paths.
- **The polymorphic value can't be locked.** A synchronized dictionary in the SubL design needs a separate type, because the alist phase has no locking primitive. CL's `:synchronized t` works only for hashtables. The port's `synchronized-dictionary-*` family uses a hashtable directly — the abstraction breaks immediately.
- **CFASL has to know.** A dumped dictionary could be either form; the loader has to handle both. The port's reader (`cfasl-input-dictionary`) writes only into a hashtable — the alist case is impossible because it's never produced.

## CFASL

| Opcode | Symbol | Reader |
|---|---|---|
| 61 | `*cfasl-opcode-dictionary*` | `cfasl-input-dictionary` |
| 64 | `*cfasl-opcode-legacy-dictionary*` | reader stripped |

Wire format: `(opcode, test-symbol, size, [key, value]…size times)`. Identical shape to set's wire format with key/value pairs instead of just keys.

The output side uses CL's generic-method dispatch on `hash-table` and lives in the dump pipeline; only the reader is here.

## Where the dictionary API is consumed

`do-dictionary` and `do-dictionary-progress` (commented out) had ~50–100 call sites historically. After the port's switch to native hashtables, callers were rewritten to use `maphash` / `dohash` directly, leaving the surviving utilities as the only API surface that's still distinct from the bare hashtable.

Active consumers of `dictionary-utilities.lisp`:

- **At-routines / At-utilities** — `at-utilities.lisp` (~10 call sites of `do-dictionary-contents`), `at-routines.lisp`. `dictionary-push` for accumulating per-term arg-type evidence.
- **Assertion manager** — `assertion-manager.lisp` for accumulator-style maps.
- **Inference metrics & prototypes** — `inference-metrics.lisp` (`dictionary-increment` for rule-time accounting), `hl-prototypes.lisp` (`dictionary-increment` for hit counts), `inference-datastructures-strategy.lisp`, `inference-datastructures-proof.lisp`, `inference-worker-join.lisp`, `inference-worker-join-ordered.lisp`.
- **Removal modules** — `inference/modules/preference-modules.lisp`, `inference/modules/removal/removal-modules-genls.lisp`.
- **API & registrations** — `java-api-kernel.lisp`, `eval-in-api-registrations.lisp`, `task-processor.lisp`.
- **SBHL** — `sbhl-cache.lisp` for `dictionary-increment` on cache statistics.
- **Storage modules** — `hl-storage-modules.lisp`, `at-var-types.lisp`.

Most of these are histograms (`dictionary-increment`) or accumulators (`dictionary-push`) — patterns that the host language usually expresses as `Counter` / `defaultdict(list)` / `Map<K, List<V>>`.

## Related files

- `bookkeeping-store.lisp` — defines its own `do-dictionary` macro (a single-file local override that expands to itself; comment notes the original called the dictionary's macro).
- `tva-cache.lisp` — also calls `do-dictionary` in a macro body; unclear which definition resolves at expansion time. Likely a port hazard.
- `hash-table-utilities.lisp` — the file the deprecation TODO names as the home for the surviving utilities once dictionary is gone.
- `map-utilities.lisp` — the alias layer that abstracted dictionary-vs-hashtable; per its own author TODO, also slated for deletion now that there's no second map type.

## Notes for a clean rewrite

- **Delete `dictionary.lisp` outright.** Keep only opcode 61 / `cfasl-input-dictionary` for backward-compatible dump loading; move that into the CFASL module.
- **Move the surviving utilities to `hash-table-utilities`.** `dictionary-push`, `dictionary-pushnew`, `dictionary-getf`, `dictionary-putf`, `dictionary-increment`, `dictionary-delete-first-from-value`, `new-dictionary-from-alist`, `dictionary-has-key?` — all small, all worth keeping as named helpers, none need a separate type.
- **`dictionary-increment` is the histogram primitive — keep it under the name `histogram-incr` or `counter-incr`.** A counter-typed wrapper or a host `Counter` is even cleaner, but the bare `(incf (gethash key h 0) inc)` form is fine.
- **`dictionary-has-key?` is the only safe presence check.** `gethash`'s primary value can be the literal `nil`; without `nth-value 1` callers can't tell "absent" from "present-as-nil." This nuance has to survive the rename — many call sites depend on it.
- **Drop `synchronized-dictionary-*`.** Just use `(make-hash-table :synchronized t)` directly; the wrappers add no value.
- **Drop `*dictionary-keys-sorter-current-sorting-information*`** unless `dictionary-keys-sorted-by-values` gets reimplemented — it's a dynamic-var slot with no current consumer.
- **The legacy opcode 64 reader is stripped.** A clean rewrite either drops the constant or implements a converter from old dump files. Most likely the legacy format is no longer interesting.
- **CFASL's wire format for dictionary is permanent.** Existing dump files have to load. Don't change opcode 61 or its layout.
