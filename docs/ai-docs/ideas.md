# Rewrite ideas

A scratchpad for design ideas that don't yet have a home in the per-system docs but that should inform the clean rewrite. Each entry is a short pitch — the problem, the proposed change, why it's worth doing.

## 1. Inline page-in slot on shell objects, eliminate the LRU hashtable

**Status quo.** Assertions, deductions, NARTs, kb-hl-supports each have a handle/content split:

- A small handle struct (`assertion`, `deduction`, `nart`, `kb-hl-support`) carrying just an integer `id`.
- A separate `kb-object-manager` keyed on the id, layered as `lru-cache → file-vector`. The cache is a hashtable from id to content. On a cache miss, load the content from the file-vector, install it in the hashtable, and return.

This is the design described in [kb-object-manager.lisp](../../larkc-cycl/kb-object-manager.lisp) and consumed by every per-type manager (`assertion-manager.lisp`, `deduction-manager.lisp`, `nart-hl-formula-manager.lisp`, etc.).

**The problem.** Every `lookup-assertion-content`, `lookup-deduction-content`, `lookup-nart-hl-formula`, etc. is a hashtable lookup. These functions are on the hottest path of inference — every literal match, every term-index walk, every TMS step touches at least one. The hashtable overhead (hash, probe, key compare, possible re-probe) is paid on every hit, plus the manager's LRU bookkeeping (cache-record allocation, doubly-linked-list pointer manipulation) on every access. The cache itself adds significant heap footprint: at 1M assertions × 16% LRU residence × ~5 words per cache entry, the cache alone is ~6 MB before counting the LRU list nodes.

**Proposed change.** Put the content slot **directly on the shell**:

```lisp
(defstruct (assertion (:conc-name as-))
  id
  content      ; nil = paged out, assertion-content struct = paged in
  lru-tick)    ; timestamp or clock counter, for eviction policy
```

A cache hit is a slot read on the assertion struct the caller already has in hand. No hashtable, no probe, no comparison. A cache miss tests the slot for nil, falls through to file-vector load, and writes the content back into the slot. Eviction sets the slot back to nil and decrements a global counter.

**Eviction policy.** A strict LRU doubly-linked-list with intrusive prev/next slots on every shell would work but adds 2 pointers per shell (paged in or not). Alternatives:

- **CLOCK** (second-chance). Single `lru-tick` slot per shell. Global clock pointer walks the id-index space; if the slot is set, mark as "recently used" and skip; if unmarked, evict. O(1) amortized eviction, no per-access bookkeeping.
- **Random sampling.** On evict, sample N random shells from the id-index, evict the one with the oldest `lru-tick`. Trades determinism for zero per-access cost.
- **Generational.** Two slots, "young" and "old". Promotion happens on a scan. Trades the LRU's perfect ordering for cache-line locality.

**Why it's worth doing.**

- **No per-access hashtable cost.** Cache hits become slot reads. The fast path is as fast as in-RAM data access on any other struct.
- **Lower memory footprint.** No cache table, no key/value cells, no hash buckets. The slot replaces the hashtable entry it would have lived in.
- **Better locality.** The content pointer is one word away from the id, on the same cache line. The shell and its content are together in the working set.
- **Cache validity by construction.** The shell *is* the cache entry. There's no way to have a stale cache record pointing at a freed shell, no way to have a shell whose hashtable entry was evicted but whose code still holds a stale pointer. The slot's nil-ness is the single source of truth.
- **Uniform across systems.** All four KB-resident object families (assertion, deduction, nart, kb-hl-support) have the same handle/content split and would benefit identically. One change pattern; one set of consequences to verify.

**Costs.**

- Every shell carries the overhead (one pointer + one tick word) even when never paged. For an id-index of 5M assertion shells with no content loaded, that's ~80 MB of pure overhead. Worth it only if shell allocation is roughly proportional to expected working-set size — which it is for KB-resident object types.
- Concurrency. The current manager uses a single lock on the kb-object-manager; the proposed design either keeps a single lock around eviction-decision points or uses fine-grained locks per shell. The hot path (cache hit) is lock-free in either design — a slot read.
- Static-space allocation. Shells currently can be allocated in `*structure-resourcing-make-static*` for KB-load-time content. Mutable content slots and lru-tick fields work fine in static space; this isn't a blocker.
- Mutation visibility. When content is updated through the public API (`set-assertion-formula-data`, etc.), the existing path goes through `mark-kb-object-content-as-muted`, which knows to write back to the file-vector on eviction. The slot-based design needs the same: a `dirty?` bit on the shell, set on any mutation, cleared on eviction-with-flush.

**Migration sketch.**

1. Add `content` and `lru-tick` slots to each shell defstruct.
2. Replace `lookup-X-content` to read the slot, fall through to a refill function on nil.
3. Replace `register-X-content` / `deregister-X-content` to write/clear the slot.
4. Replace the per-system kb-object-manager with a global eviction loop (or per-system, if locking dictates) that walks the id-index sampling for eviction candidates.
5. Remove the cache-utilities-backed hashtable entirely from the kb-object-manager.
6. Verify mutation paths (`mark-X-content-as-muted`, `swap-out-all-pristine-X`) continue to flush dirty content on eviction.
