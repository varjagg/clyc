# Cache (LRU)

A **fixed-capacity LRU cache** combining a hashtable for O(1) lookup with a circular doubly-linked list of entries threaded through a sentinel `head-entry`. Newest is `(cache-entry-older head-entry)`, oldest is `(cache-entry-newer head-entry)`. The intent is "hashtable that throws away the least-recently-used entry when capacity is reached." The readme calls out that **LRU discarding might be missing-larkc** — the port has the structure, the requeue-on-touch, the linked-list mechanics, the iteration macro, and most consumers, but the actual eviction step at `cache-set` time is `missing-larkc 31600` and the matching dropped-entry path inside `cache-set-return-dropped` is `missing-larkc 31599`. So in practice the port either runs caches at sub-capacity or relies on the consumer to pre-size; what nominally is "LRU" is "hashtable + access-order list + capacity check that errors instead of evicts."

## Two complementary representations

```
cache:
  capacity      fixnum
  map           hashtable: key → cache-entry
  head-entry    sentinel; its `older` slot points to newest, `newer` to oldest

cache-entry:
  newer / older  doubly-linked list pointers
  key            (also reused as free-list head pointer in preallocated mode)
  value
```

The map gives O(1) key lookup; the list gives O(1) requeue-to-newest on hit and O(1) drop-the-oldest on eviction. Iteration follows the list in either direction (`do-cache` macro), so callers can enumerate in newest-first or oldest-first order without a sort.

The sentinel `head-entry` is a fixed node never removed; the list is circular, so `(cache-entry-older head-entry)` is always the newest entry (or the head itself when empty) and `(cache-entry-newer head-entry)` is always the oldest. This avoids null-checks and special cases when the cache is empty.

## When does a cache come into being?

| Trigger | Caller | Capacity | Test |
|---|---|---|---|
| KB load reads pristine LRU information for a per-type kbom | `kb-object-manager.lisp` `setup-kb-object-content-support` | `max(212, table-size * lru-percentage / 100)` | `#'eq` |
| Module of `defun-cached` with `:capacity N` is loaded | `memoization-state.lisp` `create-caching-state` | caller-supplied | caller-supplied |
| Predicate-relevance lookup tables | `predicate-relevance-cache.lisp` | 128 | `#'equal` |
| Monad-MT relevance lookup tables | `mt-relevance-cache.lisp` | 256 | `#'eq` / `#'equal` |
| Task processor "actively-running" tracking | `task-processor.lisp` `ensure-task-process-being-worked-on-initialized` | `*task-processes-worked-on-history*` | `#'equal` |
| Call site uses `(new-metered-preallocated-cache N)` to back a `metered-cache` cache-strategy | `cache-utilities.lisp` (consumed by SBHL when `*sbhl-backing-file-vector-cache-constructor*` defaults to it) | caller-supplied | caller-supplied |

The constructor is `(new-cache capacity &optional (test #'eql))`. `(new-preallocated-cache capacity &optional test)` binds `*cache-entries-preallocate?*` true while constructing — the cache then allocates `capacity` cache-entry structs eagerly into a free-list and reuses them across mutations rather than calling `make-cache-entry`/letting GC reclaim. This is the "structure resourcing" pattern flagged in the readme: amortize allocation cost on a hot mutating cache. Used by `kb-object-manager` for its LRU information table and by `metered-cache` callers.

## Public API

| Function | Purpose |
|---|---|
| `(new-cache capacity &optional test)` | Construct empty cache. |
| `(new-preallocated-cache capacity &optional test)` | Same, but eagerly allocates `capacity` reusable cache-entries into a free-list. |
| `(cache-p obj)` | Predicate (defstruct-generated). |
| `(cache-size cache)` | Number of live entries (= `hash-table-count` of the map). |
| `(cache-empty-p cache)` | True iff list is empty (newest = head). |
| `(cache-full-p cache)` | True iff `size >= capacity`. |
| `(cache-contains-key-p cache key)` | Membership test that does **not** requeue. |
| `(cache-get cache key)` → values `(value present?)` | Looks up; on hit, requeues to newest. |
| `(cache-get-without-values cache key &optional default)` | Single-value variant. |
| `(cache-set cache key value)` → values `(previous-value old-entry)` | Insert or replace. **`missing-larkc 31600`** on insert when full — the LRU eviction step is unimplemented. On hit, just replaces the value and requeues. |
| `(cache-set-without-values cache key value)` | Single-value variant. |
| `(cache-set-return-dropped cache key value)` → `(dropped-key dropped-value dropped?)` | The eviction-aware setter — *intended* to return the LRU loser when the cache is full. **`missing-larkc 31599`** on the eviction path; in the port the function returns `(nil nil nil)` for that case. |
| `(cache-remove cache key)` → values `(previous-value entry-or-nil)` | Drop a key explicitly. |
| `(cache-clear cache)` | Empty out. For non-preallocated caches, just `clrhash` + reset list pointers. For preallocated caches, walks individually so each entry returns to the free-list — **`missing-larkc 31601`** for that branch. |
| `(cache-newest cache)` | The most-recently-touched entry (or the head sentinel if empty). |
| `(do-cache (id value cache &optional order) body…)` | Iteration macro; `order` is `:newest` (newest-first, default) or `:oldest`. |
| `*cfasl-opcode-cache*` = 63 | Reserved CFASL opcode. **No `cfasl-input-cache` / `cfasl-output-cache` reader is registered** in the port — the opcode is a placeholder; full Cyc has serializable caches but the LarKC port does not. |

The internal accessors and helpers (`cache-queue-requeue`, `cache-queue-enqueue`, `cache-queue-append`, `cache-queue-unlink`, `cache-queue-remove`, `is-cache-preallocated-p`, `get-new-cache-entry`, `cache-free-list`, `set-cache-free-list`, `possibly-resource-cache-entry`, `resource-cache-entry`, `unresource-cache-entry`, `scrub-cache-entry`, `cache-get-int`, `cache-set-int`) are implementation details — the consumers go through the surface listed above.

## What "LRU might be missing-larkc" means in practice

The structural mechanism for eviction *is* present:

- `cache-full-p` answers "should we evict?"
- The list lets `cache-newest` and (by following `(cache-entry-newer head-entry)`) the *oldest* entry be located in O(1).
- `cache-queue-unlink` removes any entry from the list.
- `cache-remove` removes from the map.

What is missing is the policy code that ties them together inside `cache-set-int` and `cache-set-return-dropped`. In the full Cyc engine the eviction step is something like "let oldest = (cache-entry-newer head-entry); cache-remove cache (cache-entry-key oldest); reuse the entry slot" — straightforward, but the LarKC distribution stripped it. Three identifiers carry the gap:

| ID | Site | What it should do |
|---|---|---|
| `missing-larkc 31600` | `cache-set-int` insert-when-full branch | Drop the oldest entry, reuse its struct slot, install the new key/value at the newest end. |
| `missing-larkc 31599` | `cache-set-return-dropped` insert-when-full branch | Same, but also bind `oldest-key`/`oldest-value`/`dropped` so the caller can post-process the evicted entry (e.g. `kb-object-manager` calls `swap-out-pristine-kb-object-content` on the loser). |
| `missing-larkc 31601` | `cache-clear` preallocated branch | Walk oldest→newest pulling each entry off, returning each struct to the free-list rather than orphaning them for GC. |

The TODO at line 131 calls out the design impact: `;; TODO DESIGN - the cache test for setting when it's full goes missing-larkc, which invalidates a fundamental use of the cache in the first place.`

For the kb-object-manager — the heaviest consumer — eviction is **needed** (it's how a fixed working set holds in memory while the rest stays on disk in the file-vector). With `cache-set-return-dropped` not implementing the eviction, in the LarKC port the kb-object-manager LRU effectively grows until it hits `cache-full-p`, at which point new swap-ins error. This is one of the most important things a clean rewrite has to fix.

## CFASL registration

`*cfasl-opcode-cache*` = 63 is declared but unwired — there is no input/output handler. Full Cyc presumably serializes a cache as `(capacity, test-symbol, count, key/value/order tuples)` and reconstructs it deterministically. In the port no caller writes a cache to a CFASL stream; the per-type caches that need to survive a dump (`somewhere-cache`, `tva-cache`, `predicate-relevance-cache`, etc.) serialize their *contents* (sets, hashtables) directly without going through the cache wrapper.

## Where caches are consumed

By role rather than by file count:

### As an LRU swap manager
- `kb-object-manager.lisp` — every per-type kbom (assertion content, deduction content, kb-hl-support content, NART HL formulas, constant indexing, NART indexing, unrepresented-term indexing, SBHL module graph) holds a `(new-preallocated-cache lru-size #'eq)` as its `lru-information` slot. The cache stores `id → id` (membership only, not value); `cache-set-return-dropped` is the eviction trigger that names the LRU loser to swap out. See [kb-access/kb-object-manager.md](../kb-access/kb-object-manager.md). **This is the consumer that actually depends on eviction working.**

### As a memoization backing store
- `memoization-state.lisp` — `create-caching-state` allocates a `new-cache` when the caller passes `:capacity`, otherwise a plain hashtable. `defun-cached` and `defun-memoized` route through `caching-state-lookup` / `caching-state-put` / `caching-state-clear`, which dispatch to `cache-get-without-values` / `cache-set` / `cache-clear` for the bounded-size case.
- See [runtime/memoization.md](../runtime/memoization.md).

### As a global lookup cache for KB-relevance queries
- `predicate-relevance-cache.lisp` — eight 128-entry `#'equal` caches keyed on `(pred . mt)`, holding precomputed sets of relevant predicates (genl/spec, fort/naut crossed). The cache key is a fresh cons each lookup; eviction is triggered by `cache-set` when the table gets large.
- `mt-relevance-cache.lisp` — `*monad-mt-fort-cache*` (256, `#'eq`) and `*monad-mt-naut-cache*` (256, `#'equal`) hold "is `basemt` an `all-genl-mts` of `mt`?" answers.

### As a generation tracker (no eviction needed)
- `task-processor.lisp` — `*task-processes-being-worked-on*` is a cache keyed by `(task-id . giveback-info)` of currently-running task processes. The `do-cache` iteration is used to find and terminate processes by giveback-info.

### As a metered-cache strategy backing
- `cache-utilities.lisp` `metered-cache` wraps a `cache` plus a `cache-metrics` (hit/miss counts) and exposes the `cache-strategy-object-*` generic-function protocol. `new-metered-preallocated-cache` constructs a metered cache around a `new-preallocated-cache`. The default `*sbhl-backing-file-vector-cache-constructor*` (`sbhl/sbhl-graphs.lisp`) is `'new-metered-preallocated-cache`, so SBHL module-graph caches are caches-with-hit-rate-counters.

There are roughly nine source files that *construct* a cache (the eight `defglobal` sites in `predicate-relevance-cache.lisp` plus `mt-relevance-cache.lisp`, `memoization-state.lisp`, `task-processor.lisp`, `kb-object-manager.lisp`, and `cache-utilities.lisp`). The set of files that *call into* a cache (via `cache-get`, `cache-set`, `cache-remove`, `cache-clear`, `do-cache`) overlaps these plus `kb-object-manager.lisp`, which exercises the full mutation surface.

## Cache strategies

This file is one half of the caching subsystem. The other half is the **cache-strategy** abstraction (in `cache-utilities.lisp`, with concrete implementations in `simple-lru-cache-strategy.lisp` — see [simple-lru-cache-strategy.md](simple-lru-cache-strategy.md) — and the inline `metered-cache` impl). A cache-strategy is a polymorphic "track this object as referenced; tell me whom to evict next; gather hit/miss metrics" object that decouples the eviction policy from any particular store. The `cache` here is one *backing implementation* a cache-strategy can wrap (via `metered-cache`); the kb-object-manager LRU uses the cache directly without a strategy wrapper. The two layers exist because the file-vector-backed map (`file-vector-utilities.lisp`) wants to call `(cache-strategy-track strategy key)` and `(cache-strategy-note-reference strategy key)` without caring whether the underlying eviction is "exact LRU" (a `simple-lru-cache-strategy`) or "approximate LRU via fixed-cap hashtable" (a `metered-cache` over a `cache`).

## Notes for a clean rewrite

- **Implement eviction.** The single most important change. Delete the three `missing-larkc` IDs and write the obvious "drop oldest, install new at newest" code path. Without this the cache type is fraudulent.
- **The hashtable + linked list combo is the textbook LRU implementation.** It's correct as designed; the LarKC port's gap is in the policy, not the data structure. A clean rewrite can keep the shape verbatim, or use the host's standard LRU container (Java `LinkedHashMap` with access-order; Python `collections.OrderedDict` + `move_to_end`; Rust `lru` crate; modern CL `org.shirakumo.alexandria` doesn't have one but `shasht` / `cl-containers` do).
- **Drop the `head-entry` sentinel-as-data trick.** The current code reuses `cache-entry-key` of the head entry as the free-list head pointer when preallocation is on. That's a clever space saving on a 32-bit Lisp; on a 64-bit Lisp with cheap GC, the header struct should have its own `free-list-head` slot. It's significantly clearer.
- **Drop preallocation/structure-resourcing.** Modern GCs handle short-lived `cache-entry` allocations well. Profile before paying the complexity tax. The pool is preserved here mainly because the kb-object-manager's hot path mutates the LRU on every KB lookup, and the original SubL implementation feared GC pressure. Benchmark the alternative.
- **Wire up CFASL opcode 63 or remove it.** Either implement input/output (a cache is `(capacity, test, count, ordered key/value list)` on the wire) or delete the constant. A reserved-but-unused opcode is a footgun.
- **Decide whether `cache` and `cache-strategy` should remain separate.** The two-layer split (this file + cache-utilities + simple-lru-cache-strategy) exists because Cyc had multiple eviction policies in flight. If a clean rewrite picks one (LRU is the only policy actually in use), collapse the layers. Keep the strategy abstraction only if multiple eviction policies are genuinely needed.
- **Replace `do-cache`'s newest/oldest direction parameter with two macros** (`do-cache-newest-first`, `do-cache-oldest-first`) or with the host language's iterator direction primitive. The `:newest`/`:oldest` symbol dispatch is fine but not idiomatic CL.
- **The `cache-set-return-dropped` calling convention is right.** Returning the evicted key/value as multiple values is what kb-object-manager needs to call `swap-out-pristine-kb-object-content` on the loser. Preserve the shape; just implement the body.
- **The `test` parameter at construction time is permanent.** A cache's hashtable test cannot change after creation. Lock it in the constructor; never expose a setter.
