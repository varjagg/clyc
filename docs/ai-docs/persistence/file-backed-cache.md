# File-backed cache

A separate caching framework from the `kb-object-manager`/`file-vector` swap layer. Where `file-vector` exists to **page individual KB objects in and out of memory** during normal lookup, file-backed cache exists to **persist the results of expensive computations across image restarts**, so that a fresh image can avoid recomputing them by reading them from disk.

The implementation is `file-backed-cache.lisp` (per-cache instance) and `file-backed-cache-setup.lisp` (the registry that lets caches be discovered and re-initialized at startup).

## Port status: skeleton only

Almost everything in this system is `missing-larkc`. The two files together carry **two struct definitions and two real function bodies**:

| Has body | What |
|---|---|
| `file-backed-cache` defstruct | 9 slots, conc-name `FBC-` |
| `file-backed-cache-registration` defstruct | 7 slots, conc-name `FBCR-` |
| `*fbc-reset-lock*` deflexical | per-instance reset gate |
| `*fbc-registration-lock*` deflexical | global registry gate |
| `*file-backed-cache-base-path*` | `"data/caches/"` (originally driven by `red-infrastructure-macros`, which is elided) |
| `*file-backed-cache-default-temp-dir*` | `"tmp/"` |
| `*registered-file-backed-caches*` | the registry list |
| `initialize-all-file-backed-caches` | iterate registry, call each registration's initialization function (the call itself is `missing-larkc 10736`, so even this is shimmed) |

Everything else — `file-backed-cache-create`, `file-backed-cache-lookup`, `file-backed-cache-enter`, `file-backed-cache-reset`, `file-backed-cache-finalize`, `register-file-backed-cache`, `lookup-file-backed-cache-by-name`, `preload-entire-file-hash-table`, `file-backed-cache-reconnect`, `replicate-file-backed-cache`, the `generate-test-install-*` family — is a commented-out `declareFunction` with no body.

So this doc is mostly a description of the design as embedded in the struct definitions plus what the surviving entry point does at startup. The clean rewrite is going to recreate the implementation; what survives here tells the rewriter the shape and the contract.

## What it's for

A file-backed cache is the persistent counterpart to a memoization table. The pattern:

1. Some computation `compute-X(key)` is expensive (a query against the KB, a graph walk, a derived analysis).
2. The result `X(key)` is worth keeping across runs, because the KB doesn't change frequently and the same `key`s recur.
3. So a `file-backed-cache` instance is registered with a generation function (computes the value), an initialization function (loads from disk and wires up the in-memory side), a reset function (invalidates and recomputes), and a default-FHT-name function (where on disk to put it).
4. On startup, `initialize-all-file-backed-caches` walks the registry and calls each cache's initialization. The cache becomes ready before any caller hits a lookup.
5. `file-backed-cache-lookup cache key` checks the in-memory hashtable; on miss, falls through to the on-disk file-hash-table; on miss again, calls the generator and stores the result.
6. `file-backed-cache-enter cache key value` writes a new entry through.
7. `file-backed-cache-reset cache` clears the on-disk store and re-runs generation.

The "file-hash-table" (FHT) the slot names refer to is the on-disk hashtable format implemented in (originally) `file-hash-table.lisp` and `file-hash-table-utilities.lisp` — both **elided from the port** (see `system-version.lisp` line 149-150 for their place in the SubL system list, and the absence of those `.lisp` files in `larkc-cycl/`). So this is one of several layers stacked on top of nothing in the LarKC port.

## `file-backed-cache` struct

Slots (conc-name `FBC-`):

| Slot | Purpose |
|---|---|
| `file-hash-table-cache` | The on-disk file-hash-table (FHT) the cache reads from. The persistent half. |
| `local-cache` | An in-memory hashtable. The hot half. Reads check here first. |
| `file-hash-table-path` | Path to the FHT file. Constructed from the registration's default-fht-name-function and `*file-backed-cache-base-path*`. |
| `should-preload-cache` | Boolean. When t, `preload-entire-file-hash-table` reads everything into `local-cache` at startup; otherwise, entries page in lazily. |
| `is-fort-cache` | Boolean. T if the cache is keyed by FORTs (constants/NARTs). Affects key serialization (FORTs travel by GUID for stability across image rebuilds). |
| `fht-cache-percentage` | Cache fill ratio threshold for the LRU policy on top of the FHT. |
| `test` | Hash test for the in-memory side (`equal`, `eql`, etc.). |
| `mode` | Open mode — read-only vs read/write. |
| `is-busy` | Concurrency flag. Set during reset/finalize; checked by lookups to avoid using a half-built cache. |

The struct's `print-object` is `missing-larkc 7781`; CL's default takes over.

## `file-backed-cache-registration` struct

A registration is a record placed on `*registered-file-backed-caches*`. It tells the framework how to instantiate one cache. Slots (conc-name `FBCR-`):

| Slot | Purpose |
|---|---|
| `generation-function` | Computes the value for a key on miss. |
| `initialization-function` | Wires the cache up at startup (opens the FHT, populates `local-cache` if `should-preload-cache`). |
| `reset-function` | Invalidates and rebuilds the on-disk store. |
| `default-fht-name-function` | Returns the on-disk filename, derivable from system / module / KB version. |
| `test-suite-name` | Used by `generate-test-install-*` to associate the cache with a regression test suite. |
| `module-name`, `system-name` | Provenance: which module owns the cache, which system the cache belongs to. Used by the dev-time `generate-test-install-file-backed-cache` flow that builds the cache from scratch in a fresh image and validates round-trip. |

`register-file-backed-cache` (stripped) takes 7 args matching the slots; appends a registration to `*registered-file-backed-caches*` under the registration lock.

`lookup-file-backed-cache-by-name` (stripped) finds a registration by `test-suite-name` (or perhaps by module — without a body it's not certain which).

## Startup wiring

`initialize-all-file-backed-caches` is the only end-to-end working entry point. It:

1. Bails immediately if `(not (kb-loaded))` — caches make no sense without a KB.
2. Logs `Initializing file-backed caches.` if any are registered.
3. Iterates `*registered-file-backed-caches*`. For each, calls `(funcall (missing-larkc 10736))` — the original code presumably extracted the `initialization-function` and called it with appropriate args, and accumulated any error message to warn about. The shim here just signals 10736 if reached, so in practice this loop does nothing useful in the LarKC port.

The function is invoked at startup by `system-kb-initializations` in `misc-utilities.lisp` (line 141), which runs it in a **dedicated thread** (`bt:make-thread :name "file-backed cache initializer"`) and then sleeps 0.5 seconds before continuing. The async pattern lets the main image come up while caches preload in the background.

## How it differs from `kb-object-manager` swap

| | `file-backed-cache` | `kb-object-manager` (file-vector swap) |
|---|---|---|
| Purpose | Persist computed results across runs | Page KB-object content in and out of RAM |
| Per-record format | File-hash-table (key→value pairs) | File-vector (offset-table indexed array) |
| Keyed by | Arbitrary value (often FORTs) | Integer dump-id |
| Lookup miss path | Run a generator function | Error — every id should be in the file-vector |
| Mutation path | Reset / re-enter | Mark mutated, write back (mostly stripped) |
| Load policy | Optional preload of whole table | Lazy on first access |
| Lifetime | Across images, regenerated when stale | One image (recreated by next `load-kb`) |
| Population | Generated by application code | Dumped by `dumper.lisp` |

The two systems coexist because they answer different questions. A KB load reads `assertion.cfasl` and gets a swap-in-able image of every assertion (object-manager). Then the running image computes some derived predicate-relevance summary and stuffs it in a file-backed cache so the *next* image starts with that summary already on disk.

## What the port can and can't do

**Can**: define a registration, push it onto the registry. The `system-kb-initializations` thread will call into the (stripped) initialization loop without erroring out the rest of startup, because each initialization is wrapped in `handler-case`.

**Can't**: actually serve a lookup, enter a value, reset a cache, replicate a cache, or generate-test-install one. Every operation past the registry walk is `missing-larkc`. The on-disk file-hash-table format itself isn't implemented (see `file-hash-table.lisp` absence noted above).

This means: any subsystem in Cyc that depends on a file-backed cache is itself non-functional in the LarKC port at the persistence level. It may have an in-memory fallback, but a clean rewrite needs both this layer and the file-hash-table layer beneath it.

## Notes for a clean rewrite

- **Decide whether the on-disk format is the same as the data file under file-vector.** They could share — both are key→value with a CFASL value and a stable key. The only divergence is that file-vector keys are dense small integers (offsets-into-array) while file-hash-table keys are arbitrary values. A shared format with a key index — sorted, hashed, or B-tree — covers both. Worth considering whether the rewrite should unify them.
- **Pick a database-backed store.** SQLite, RocksDB, LMDB. The file-hash-table-from-scratch approach is what made writing this layer hard enough that LarKC stripped most of it. A modern KV store solves the problem in 50 lines instead of 2000.
- **The async-preload-on-startup pattern is correct.** Caches that take seconds to load shouldn't block image start. Keep this; just don't rely on a 0.5-second sleep — properly synchronize with a barrier.
- **Drop `is-busy`.** Use a real lifecycle: `:uninitialized | :loading | :ready | :resetting | :closed`. A boolean and an external lock isn't enough state.
- **`is-fort-cache` is a special case worth generalizing.** What it really means is "the keys are externalized when stored" — FORTs serialize by GUID rather than by handle id, because handle ids are image-local and would break on the next image. A clean rewrite parameterizes this on the codec, not on a specific is-FORT flag.
- **Registrations should be plain data, not `defstruct`.** A list of registrations is a list of `(:generator ... :initializer ... :reset ... :path ... :module ... :system ...)` plists. The struct buys nothing.
- **The 7-argument `register-file-backed-cache` is a smell.** Use a keyword-arg API or a `register-file-backed-cache name :generator ... :initializer ...` form.
- **Move test-suite-name out of the runtime registration.** A test runs for a cache by name, not the other way around. The runtime cache doesn't need to know about its tests.
- **`preload-entire-file-hash-table` should be opt-in per cache, not per registration field.** Some caches benefit from preload (small, hot); most do not. Make the decision at lookup time when the working set has shape.
- **Rebuild support is absent in the port.** A cache that's "stale" (KB version changed, generator changed, file format changed) needs an automatic regenerate path. Define a versioning convention in the file header so a stale file is detected at open time and triggers reset rather than a corrupt read.
- **The file-hash-table layer underneath is a separate rewrite job.** This system is one consumer of it; the FORT name lookup, NL lexicon caches, and several other subsystems used the same FHT. A clean rewrite picks one persistent KV store and serves all of them.
