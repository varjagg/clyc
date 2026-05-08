# ID-index (vector + overflow hashtable)

An `id-index` is a **map from non-negative integer ids to arbitrary objects**, optimized for the case where ids are dense and start near zero. It backs every "look up the X with id N" table in Cyc — constants by SUID, narts by id, assertions, deductions, kb-hl-supports, clause-strucs, unrepresented-terms, problem-stores, inferences, and several auxiliary indexes.

The implementation is in `larkc-cycl/id-index.lisp` (~400 lines, ~half of which is commented `declareFunction` stubs the LarKC build stripped).

## Shape

A two-tier store with one fixnum cursor:

| Slot | Type | Role |
|---|---|---|
| `lock` | bt:lock | Guards every mutation; reads are unlocked. |
| `count` | fixnum | Total live entries (old vector + new hashtable). |
| `next-id` | fixnum | The next id `id-index-reserve` will hand out. |
| `old-objects` | simple-vector | The hot path. `aref` lookup at `(< id (length old-objects))`. Empty cells are filled with the sentinel `+id-index-tombstone+` (`:%tombstone`). |
| `new-objects` | hash-table | Spillover. Holds entries whose ids are `>=` the vector length, until `optimize-id-index` migrates them in. |

`new-id-index` mints a fresh one with `make-vector` of the requested old-objects size pre-filled with tombstones, plus a hashtable sized to roughly `floor(old-size / *id-index-default-scaling-factor*)` (default 100 — old entries are expected to outnumber new by 100×).

The Clyc port simplified the original SubL design: SubL had **two** sentinel values (a tombstone and an "empty list" marker) because SubL couldn't control a vector's default-fill value, so NIL was reserved as the tombstone and a separate symbol stood in for "actual NIL value." The CL port collapses that to one tombstone (`:%tombstone`), letting NIL be a legal value. `*id-index-empty-list*` and `id-index-empty-list` are kept vestigial for callers that still reference them — both return NIL.

## Why a vector + hashtable hybrid

The single design question this data structure answers: **how do you store a sparse-but-mostly-dense int → object map cheaply?** The constraints in Cyc:

- IDs are issued sequentially from a counter (`id-index-reserve`), so the *live* ids are roughly `[0, count)` minus a small set of holes from `id-index-remove`.
- Lookup happens on **every KB access** — every `find-constant-by-internal-id`, every assertion fetch, every nart-from-id. It must be `aref` fast.
- The KB is loaded from a CFASL dump where ids are known up-front, so the table can be **sized exactly at load time**.
- Runtime additions (KB editing) extend past the loaded size, but this is the rare path.

The straightforward alternatives lose:

- A pure hashtable hash-codes every lookup, which is slower than a vector indexing for the hot read path.
- A pure auto-growing vector handles writes by `vector-push-extend`, which can't keep `old-objects` a `simple-vector` (the type that allows the fastest `aref`).
- An array of object pointers sized to `next-id` would waste memory when `next-id` runs ahead of actual entries.

The hybrid solves it by **freezing the fast path**: `old-objects` is a `simple-vector` allocated once (or grown rarely via `optimize-id-index`), the hot lookup is a single bounds check + `aref`, and the rare overflow case spills into the hashtable. `optimize-id-index` is what flushes the hashtable back into the vector by reallocating to a larger size and copying. Callers like `constant-handles` call it after a load to tighten the structure.

The split also explains `id-index-old-object-id-p`: a one-line predicate (`(< id (length old-objects))`) that tells the lookup which side to check. The hashtable is only consulted on the rare slow path.

## When does an id-index get created?

| Situation | Citation |
|---|---|
| KB load: each per-type table is allocated with size = the count just read off the CFASL header, so the vector is sized exactly to the loaded set. | `nart-handles.lisp`, `assertion-handles.lisp`, `constant-handles.lisp`, `deduction-handles.lisp`, `kb-hl-supports.lisp`, `unrepresented-terms.lisp`, `clause-strucs.lisp`, `constants-low.lisp` (for `*constant-guid-table*` and `*constant-merged-guid-table*`) |
| New problem-store is minted: each store's per-object id-indexes (inference, strategy, problem, link, proof) are created. | `inference-datastructures-problem-store.lisp` |
| New inference is minted: `answer-id-index` is allocated with size 10. | `inference-datastructures-inference.lisp` |
| KB-object-manager is initialized for a swappable type: content-table and usage-table are id-indexes. | `kb-object-manager.lisp` |
| Each `fort-id-index` (used by SBHL caches) wraps two id-indexes, one for constants and one for narts. | `forts.lisp` |
| Process-global `*problem-store-id-index*` is created lazily for the master problem-store registry. | `inference-datastructures-problem-store.lisp` |

## Public API

| Function | Purpose |
|---|---|
| `(new-id-index &optional old-size new-id-start)` | Allocate a fresh id-index, sized to `old-size` (the dense vector size) with new-ids starting at `new-id-start` (defaults to `old-size`). |
| `(id-index-p object)` | Predicate (defstruct-generated). |
| `(id-index-count idx)` | Total live entries. |
| `(id-index-empty-p idx)` | `count == 0`. |
| `(id-index-next-id idx)` / `(set-id-index-next-id idx n)` | Read or set the id cursor. |
| `(id-index-reserve idx)` | Atomically returns `next-id` and increments the cursor. The id-issuance primitive. |
| `(id-index-lookup idx id &optional default)` | The hot path. Returns the object or `default` (or NIL) if absent. |
| `(id-index-enter idx id object)` / `(id-index-enter-unlocked …)` | Insert or overwrite under id. The unlocked variant assumes the caller already holds the lock. |
| `(id-index-enter-autoextend idx id object)` / `(id-index-enter-unlocked-autoextend …)` | Same, but if `id` lands at the vector boundary, calls `optimize-id-index` to grow. Used by callers issuing fresh ids that might exceed the loaded size (e.g. inference answer table). |
| `(id-index-remove idx id)` | Remove. Decrements count only if the slot was live. Vector slot becomes a tombstone; hashtable entry is `remhash`-ed. |
| `(clear-id-index idx)` | Reset count to 0, fill vector with tombstones, clear hashtable. Called during KB unload / problem-store destruction. |
| `(optimize-id-index idx &optional size)` | Migrate the hashtable into a (possibly larger) `simple-vector` and clear the hashtable. Called after bulk loads to make subsequent lookups all hit the fast path. |
| `(id-index-values idx)` | Return a list of all live values in vector-then-hashtable order. Used by `*problem-store-id-index*` for whole-table dumps. |
| `(id-index-old-objects idx)` / `(id-index-new-objects idx)` / `(id-index-new-id-threshold idx)` | Direct accessors for code that wants to walk a side itself (kb-mapping does this for hand-tuned hot loops). |
| `(id-index-old-object-id-p idx id)` / `(id-index-tombstone-p object)` / `(id-index-tombstone)` | Tombstone and slot-ownership predicates. |
| `(do-id-index (id object idx &key tombstone ordered progress-message done) …)` | The iteration macro. Walks the vector first (skipping tombstones by default), then the hashtable. `:ordered t` forces sequential id order through the hashtable. `:progress-message` enables `noting-percent-progress` reporting (suitable for long KB scans). |

The macro is the dominant consumer surface — `do-id-index` calls outnumber explicit lookup loops in client code roughly 2:1.

### What the LarKC build stripped

A long block of `commented declareFunction`s at the bottom of the file represents Cyc engine functionality that didn't ship with LarKC: `cfasl-input-id-index`, `cfasl-output-id-index-internal`, `cfasl-wide-output-id-index`, `clone-id-index`, `copy-id-index`, `compact-id-index`, `id-index-ids`, `id-index-missing-ids`, `build-reverse-index-for-id-index`, `new-id-index-from-reverse-index`, `id-index-iterator` and friends. For a clean rewrite these are required:

- **CFASL serialization**: the Cyc dumper writes id-indexes as a single CFASL record using wide opcode 128 (`*cfasl-wide-opcode-id-index*` is declared in the file but with no `register-wide-cfasl-opcode-input-function` call). The corresponding output method `cfasl-output-object-id-index-method` is a stub. The full Cyc engine round-trips id-indexes; the LarKC port instead writes per-type `.cfasl` files where each entry's id and object are emitted explicitly, then re-builds the id-index in memory at load time. Either approach works; the rewrite should pick the dump-format choice deliberately rather than inherit the LarKC workaround.
- **Iterators (`new-id-index-iterator`, `new-id-index-values-iterator`, `…-old-objects-iterator`, `…-new-objects-iterator`)**: the lazy-iteration story for id-indexes. The `do-id-index` macro covers most call sites because the consumer is a body, not a separate piece of code holding an iterator handle, but inference sometimes wants a real iterator to interleave with other sources.
- **`compact-id-index` / `id-index-compact-p`**: vacuum after heavy delete churn — collapse tombstoned vector slots and renumber. The port doesn't need this because LarKC's KB load is one-shot, but a long-running editor session does.
- **Reverse-index construction**: `build-reverse-index-for-id-index reverse-key-fn` lets you take an id→object index and a function `(object → key)` and build an id-index keyed by some other id derived from each object. This is how secondary indexes get bootstrapped.

## Who uses it

The id-index is the **uniform shape for every per-type id-keyed table** in Cyc. The list:

| Per-type table | Owning file | What it maps |
|---|---|---|
| `*constant-from-suid*` | `constant-handles.lisp` | constant SUID → constant struct |
| `*constant-guid-table*` | `constants-low.lisp` | constant SUID → GUID |
| `*constant-merged-guid-table*` | `constants-low.lisp` | preserved GUIDs of merged-away constants |
| `*nart-from-id*` | `nart-handles.lisp` | nart id → nart struct |
| `*assertion-from-id*` | `assertion-handles.lisp` | assertion id → assertion (or file-vector-reference for swappables) |
| `*deduction-from-id*` | `deduction-handles.lisp` | deduction id → deduction |
| `*kb-hl-supports-from-ids*` | `kb-hl-supports.lisp` | kb-hl-support id → support struct |
| `*clause-struc-from-id*` | `clause-strucs.lisp` | clause-struc id → clause-struc |
| `*unrepresented-term-from-suid*` | `unrepresented-terms.lisp` | unrepresented-term SUID → term |
| `*problem-store-id-index*` | `inference-datastructures-problem-store.lisp` | global problem-store registry |
| problem-store's `inference-id-index` / `strategy-id-index` / `problem-id-index` / `link-id-index` / `proof-id-index` | `inference-datastructures-problem-store.lisp` | per-store registries of inference-engine objects |
| inference's `answer-id-index` | `inference-datastructures-inference.lisp` | per-inference answer registry |
| `kb-object-manager` content-table and usage-table | `kb-object-manager.lisp` | swappable-object id → file-vector-reference (or live object); usage counter for LRU eviction |
| `fort-id-index`'s `constants` and `narts` slots | `forts.lisp` | combined fort-keyed map (dispatches by `constant-p` to one or the other) |

`fort-id-index` itself is a thin wrapper: a struct with two id-index slots (one for constants, one for narts) and `lookup`/`enter`/`remove` operations that pick the right slot based on the fort kind. The SBHL all-mts caches use it (see `sbhl-cache.lisp`'s `sbhl-pred-all-mts-cache-uses-id-index-p` branch — for some predicates the cache value is itself a `fort-id-index`).

`do-id-index` is the only reasonable way to walk every constant / nart / assertion / etc., so it appears throughout: KB save (`set-next-constant-suid`, `set-next-assertion-id`), KB initialization, GC scans, debug dumps, and the inference-store iteration macros.

## Locking story

Every mutation goes through `with-idix-lock`, which does `bt:with-lock-held` on the per-index lock. Readers don't lock — `id-index-lookup` is a single `aref` plus a possible `gethash`, and the assumption is that overlapping a write with a read produces either the old or the new value, both of which are valid (the tombstone case turns into "absent," which the caller handles). This is fine for the load-once-mostly-read pattern but isn't safe for concurrent KB editing without external coordination.

`id-index-enter-unlocked` exists for the case where the caller is already inside `with-idix-lock` for a multi-step operation (e.g. enter-and-bookkeep). The unlocked-autoextend variant exists for the same reason.

## CFASL serialization

The wide opcode is declared:

```lisp
(defconstant *cfasl-wide-opcode-id-index* 128)
```

But the registration with `register-wide-cfasl-opcode-input-function` and the matching `cfasl-output-object-id-index-method` defmethod are both absent / stubbed. This is the LarKC strip — the engine knows how to round-trip an id-index as a single record but the build dropped the implementation.

The format presumably (by symmetry with `cfasl-input-fort-id-index` at opcode 99): a count followed by alternating id/object pairs, deserialized into a fresh id-index of size = count. A clean rewrite should implement this; otherwise every owner of an id-index has to write its own per-table dump/load (which is what the per-type handle files currently do via `do-id-index`-driven loops).

## Notes for a clean rewrite

- **Keep the hybrid shape, but reconsider the threshold logic.** The dense-vector + overflow-hashtable design is genuinely good for its workload (load-time-sized table + small runtime growth). The author's TODO notes that in practice everything entered into `new-objects` has `id <= next-id`, which means the only reason the hashtable exists at all is so the vector doesn't have to grow on every insert. A cheaper alternative is "grow the vector to `2 * next-id` whenever you'd write past its end" — same amortized cost, no hashtable, no second lookup branch, simpler code. Worth measuring.
- **Drop the dual sentinel system.** The Clyc port already collapsed it to one tombstone; the vestigial `*id-index-empty-list*` should be deleted. The `:skip` vs `:%tombstone` distinction inside `do-id-index`'s `:tombstone` keyword is also confusing — pick one.
- **Use a real concurrency primitive.** Per-index `bt:make-lock` is fine, but the unlocked-reader / locked-writer split should be documented as the contract; if the rewrite needs concurrent mutation, switch to a striped or RW lock.
- **Make the iteration macro syntax-host-native.** `do-id-index` is "for (id, object) in idx" — every modern language has this directly. Don't reinvent.
- **`do-id-index` with `:progress-message`** is doing two things (iteration and progress reporting). Split — let progress reporting be a generic loop wrapper, not baked into the table iteration.
- **Implement CFASL round-trip as one record.** The current per-handle-file dump loop is fine but it duplicates the iteration logic across nart-handles, assertion-handles, etc. A single `cfasl-output-id-index` / `cfasl-input-id-index` pair lets the per-type code call one function.
- **Issue a real type for ids.** SubL had only fixnum; modern Lisp can carry a `(deftype constant-id () '(integer 0 (#.most-positive-fixnum)))` and let the compiler enforce that callers don't accidentally pass a float or a negative. The negative-id branch in `id-index-old-object-id-p` (a check that always returns false because negatives can never be vector indices) becomes provably dead.
- **Replace `optimize-id-index`'s "grow to size" parameter with a strategy.** Currently callers pass arbitrary sizes; sometimes `2 * threshold`, sometimes `2 * max(threshold, id)`. A clean rewrite picks one growth strategy (e.g. golden ratio, doubling) and hides it.
- **The `fort-id-index` wrapper belongs in `forts.lisp`, not as a separate type to know about.** It's just a discriminated pair. If the rewrite collapses constants and narts into a single FORT type with a `kind` tag, the wrapper goes away — one id-index keyed on the FORT id suffices.
