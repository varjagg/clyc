# Simple-LRU-cache-strategy

A **pluggable LRU eviction policy object** that conforms to the `cache-strategy-object-*` generic-function protocol declared in `cache-utilities.lisp`. The full Cyc engine has two main strategies: this file's `simple-lru-cache-strategy` and the hashtable-backed `metered-cache` (in `cache-utilities.lisp`). Callers that want LRU tracking — most prominently the file-vector-backed map used by SBHL graph caches and (potentially) by kb-object-manager swap-in — hold a generic `cache-strategy-p` reference and dispatch through the protocol; the strategy decides whom to evict and whether to gather hit/miss metrics. This decoupling is *why* the cache strategy is a separate file: the same callers can swap the policy without changing call-site code, and a future clean rewrite can introduce alternative policies (LFU, ARC, CLOCK) by adding a new strategy class with the same protocol.

**The bodies are almost entirely missing-larkc in the LarKC port.** The struct exists, the `cache-strategy-object-p` `defmethod` returns t, but every meaningful function (track, note-reference, untrack, peek, iterate, the test suite) has no body. So this file is a *protocol shape and a placeholder*; the working strategy in the port is `metered-cache`, and the simple-LRU strategy is dead code that the port keeps loading because callers reference its symbols and CFASL might emit them.

## What the struct holds

```lisp
(defstruct (simple-lru-cache-strategy (:conc-name "SLRU-CACHESTRAT-"))
  capacity        ; fixnum: maximum items tracked
  index           ; vector: per-slot {datum, backref, fwdref} triple — the index
                  ;   into the linked list, fast O(1) "is this datum tracked?"
  payload         ; storage of the actual datum values plus per-datum metadata
  head            ; index of the most-recently-referenced datum (newest)
  tail            ; index of the least-recently-referenced datum (oldest, evict next)
  freelist-head   ; index of the next free slot in `index` (or NIL when full)
  metrics)        ; cache-metrics struct (hit-count + miss-count) when active, else nil
```

The shape is the standard intrusive doubly-linked list embedded in a fixed-size index vector — the same idea as `cache.lisp`'s circular list, but with array-of-triples (`{datum, backref, fwdref}`) instead of struct-cons-cells. The intent of using array slots and a freelist of integer indices, instead of `cache-entry` structs and a freelist of structs, is to eliminate per-entry allocation entirely: every slot's lifetime is the strategy's lifetime, and tracking adds nothing to GC pressure. This is the same allocation-avoidance theme as `cache.lisp`'s `*cache-entries-preallocate?*` mode, taken further — instead of preallocating structs, the strategy preallocates the entire backing array.

The internal accessors implied by the (unimplemented) declareFunctions:

| Implied accessor | Reads | Writes |
|---|---|---|
| `slru-cache-index-datum` | the datum stored at index `i` | — |
| `slru-cache-index-backref` | "older than me" pointer | `set-slru-cache-index-backref` |
| `slru-cache-index-fwdref` | "newer than me" pointer | `set-slru-cache-index-fwdref` |
| `slru-cache-payload-size` | live count | — |

The triple `{datum, backref, fwdref}` per slot is enough to thread a doubly-linked list through the index vector; `head` / `tail` / `freelist-head` are integer slot indices into that vector.

## When does a strategy come into being?

In the LarKC port, **never**. The constructor `new-simple-lru-cache-strategy` is an active declareFunction with no body, so no consumer actually allocates one — the symbol is referenced but the call would error.

In full Cyc, the construction triggers would be:

| Trigger | Caller |
|---|---|
| A file-vector-backed map needs an LRU policy and the operator chose simple-LRU over metered-cache | `*sbhl-backing-file-vector-cache-constructor*` (default in port is `'new-metered-preallocated-cache`; full Cyc could rebind this to a constructor that calls `new-simple-lru-cache-strategy`) |
| A test allocates one to compare semantics with a plain `cache` | `compare-slru-cache-strategy-with-cache`, `test-basic-slru-cache-strategy` (all unimplemented) |
| A KB-object-manager swap layer in a configuration that uses cache-strategy abstraction rather than a raw cache | hypothetical; the port's kb-object-manager calls `cache-set-return-dropped` directly |

Once allocated, a strategy is mutated by `cache-strategy-object-track`, `-note-reference`, `-untrack`, and reset by `-reset` (delegating to `clear-simple-lru-cache-strategy`). It disappears with normal GC; there's no explicit `destroy` step.

## Public API surface

All listed below are **active declareFunctions with no body** — the symbols are exported but invocation triggers a SubL error rather than a missing-larkc; the structure declaration and the four `defmethod`s on the protocol are the only live content.

### Constructor & lifecycle

| Function | Intended semantics |
|---|---|
| `(new-simple-lru-cache-strategy capacity &optional metrics)` | Allocate a strategy of fixed `capacity`. `metrics` is an optional `cache-metrics` to enable hit/miss counting from creation. |
| `(clear-simple-lru-cache-strategy strategy)` | Reset to empty: `head`/`tail` cleared, every slot returned to freelist, payload zeroed. |
| `(print-simple-lru-cache-strategy object stream depth)` | Print method (in CL, the default `print-object` covers this; `missing-larkc 29372` flagged in source). |

### Size queries

| Function | Intended semantics |
|---|---|
| `(simple-lru-cache-strategy-size strategy)` | Number of currently tracked datums. |
| `(simple-lru-cache-strategy-capacity strategy)` | Configured capacity (mirrors slot accessor). |

### Tracking & references

| Function | Intended semantics |
|---|---|
| `(simple-lru-cache-strategy-tracked? strategy object)` | T iff `object` is currently tracked. O(1) via index. |
| `(simple-lru-cache-strategy-track strategy object)` | Begin tracking. If at capacity, evict the tail (LRU) and return the evicted datum so the caller can flush/finalize it; otherwise return `object`. |
| `(simple-lru-cache-strategy-note-reference strategy object)` | Move `object` to head (most-recently-referenced). No-op if untracked. |
| `(simple-lru-cache-strategy-untrack strategy object)` | Stop tracking `object`; return the datum to the freelist. |

### Peek operations (no requeue)

| Function | Intended semantics |
|---|---|
| `(simple-lru-cache-strategy-peek-most-recent strategy)` | Read the head datum without changing recency. |
| `(simple-lru-cache-strategy-peek-most-recent-nth strategy n)` | The nth-newest datum. |
| `(simple-lru-cache-strategy-peek-least-recent strategy)` | Read the tail datum (next eviction candidate). |
| `(simple-lru-cache-strategy-peek-least-recent-nth strategy n)` | nth-oldest. |
| `(simple-lru-cache-strategy-most-recent-items strategy)` | List of all datums newest-first. |
| `(simple-lru-cache-strategy-least-recent-items strategy)` | List oldest-first. |
| `(new-simple-lru-cache-current-content-iterator strategy &optional direction)` | Iterator over current contents in `:newest` or `:oldest` order. |

### Cache-strategy generic protocol implementations

The file installs the strategy as a participant in the `cache-strategy-object-*` generic-function protocol from `cache-utilities.lisp`. Two are real `defmethod`s; the rest are LarKC-stripped `defun … missing-larkc N`:

| Generic | Status in port |
|---|---|
| `cache-strategy-object-p` | `defmethod` → `t` |
| `cache-strategy-object-track` | `defmethod` → `missing-larkc 29354` |
| `cache-strategy-object-reset-…-method` | `defun` → `missing-larkc 29353` |
| `cache-strategy-object-cache-capacity-…-method` | `defun` → `missing-larkc 29351` |
| `cache-strategy-object-cache-size-…-method` | `defun` → `missing-larkc 29352` |
| Tracked? / untrack / supports-parameter / get-parameter / set-parameter / note-reference / note-references-in-order / get-metrics / reset-metrics / gather-metrics / dont-gather-metrics / keeps-metrics-p / new-tracked-content-iterator / map-tracked-content / untrack-all | active declareFunctions, no body |

The `defmethod`-vs-`defun` split is intentional — the four `defmethod`s are the entry points the protocol layer dispatches through, while the rest are non-method `-method` named "implementation" functions reachable only via the explicit dispatch. In CL the cleaner pattern is a single `defmethod` per protocol entry point; the `-method`-suffixed defuns are an artifact of the SubL-Java structure-method registration system.

### Metered, non-method "bridge" delegators

A second set of bridge functions named `cache-strategy-slru-cache-object-*` delegate to the implementations without going through the generic dispatch. These exist to allow "I know this is a simple-lru-cache-strategy, skip the dispatch" call paths. All active declareFunctions, no body.

### Test suite

Five test functions (`test-basic-slru-cache-strategy`, `compare-slru-cache-strategy-with-cache`, `compare-slru-cache-strategy-speed-with-cache`, `test-slru-cache-strategy-compare-directions`, `test-slru-cache-strategy-peek-operators`) are declared but stripped. The trailing comment in the file notes the test-case-table setup is itself blocked because `test-case-name-p` and `cyc-test-kb-p` are missing-larkc — so even if the test bodies returned, they couldn't register at load time.

## CFASL registration

`*dtp-simple-lru-cache-strategy*` is exported as the type designator for serialization. No CFASL opcode constant is bound in this file; the cache-strategy objects are not directly serialized in the LarKC distribution. Full Cyc presumably registers an opcode for the type so a strategy can round-trip through a CFASL stream alongside the data it caches; the LarKC port omits that opcode, so a strategy is effectively per-image-only.

## Where this is consumed

- **Nowhere directly in the LarKC port.** No file calls `new-simple-lru-cache-strategy`. The only file outside the source itself that mentions the type is `system-version.lisp`, which lists `simple-lru-cache-strategy` as one of the loaded subsystems for image-version reporting.
- **Indirectly through `cache-strategy-p`** wherever the file-vector-backed map (`file-vector-utilities.lisp`) takes a cache-strategy argument — `file-vector-backed-map-w/-cache-get` calls `(cache-strategy-track strategy key)` and `(cache-strategy-note-reference strategy key)` against whatever strategy is passed in. In the port the strategy is always a `metered-cache` (from `cache-utilities.lisp`); the simple-LRU strategy is the alternative implementation that the protocol design accommodates. See [persistence/file-vector.md](../persistence/file-vector.md) for that consumer.
- **Eventually**, a clean rewrite of the kb-object-manager could replace the current `(new-preallocated-cache lru-size #'eq)` pattern with a `simple-lru-cache-strategy` to consolidate the eviction policy in one place rather than scattering it across `cache.lisp` and the cache-strategy protocol.

## Why a separate file at all

The split exists because **the cache-strategy is policy, the cache is mechanism, and a real engine wants to vary them independently:**

- `cache.lisp` is one specific mechanism: a hashtable + a doubly-linked list of `cache-entry` structs. Eviction policy is hard-coded as LRU (and even then, `missing-larkc`).
- `cache-utilities.lisp` defines the protocol: `cache-strategy-object-track`, `-note-reference`, `-tracked?`, `-untrack`, `-get-metrics`, etc. Any object implementing those generics is a cache-strategy.
- `simple-lru-cache-strategy.lisp` is one *implementation* of the protocol — exact LRU using an array of `{datum, backref, fwdref}` triples.
- `cache-utilities.lisp` also includes `metered-cache`, an *alternate* implementation that wraps a `cache` plus a `cache-metrics`.

Two implementations of the same protocol means callers can choose at runtime: SBHL picks `metered-cache` via `*sbhl-backing-file-vector-cache-constructor*`. A future caller could pick `simple-lru-cache-strategy` (when its bodies arrive) for a workload where the array-backed implementation has lower GC pressure than the hashtable + cons-cells.

The shared kb-object-manager and SBHL infrastructure benefits because `file-vector-backed-map-w/-cache-get` doesn't care which strategy backs it. The LRU-policy code lives once per implementation class, not per consumer.

## Notes for a clean rewrite

- **Decide whether the strategy abstraction earns its keep.** The protocol surface is large (~17 generic operations), but the LarKC port only meaningfully uses one strategy (`metered-cache`). If a clean rewrite settles on a single LRU implementation, collapse the strategy layer entirely. If experiments with alternative policies (LFU, segmented LRU, CLOCK, ARC) are planned, keep it.
- **The struct shape is correct.** Array-of-triples + integer-index linked-list + freelist is the textbook intrusive-LRU layout. It outperforms a hashtable + cons-cells when allocation pressure matters. A clean rewrite can keep this layout and just implement the bodies.
- **The `-method` / non-method twin functions are noise.** In CL the protocol is `defgeneric` + `defmethod`. Drop the standalone `…-simple-lru-cache-strategy-method` defuns — they're a SubL-era separation that the host language doesn't need.
- **Implement bodies in the order: `track`, `note-reference`, `untrack`, `tracked?`, `peek-{most,least}-recent`, `iterate`, `clear`, `metrics-{gather,reset,note-hit,note-miss}`.** Once those work, the test suite (also stripped) can run.
- **`cache-strategy-track` returning the evicted datum on overflow is the right shape.** Same convention as `cache-set-return-dropped` in `cache.lisp`. Preserve it; the file-vector-backed map relies on it to do the swap-out callback.
- **The metrics slot is fine to leave nil-able.** Metric collection is opt-in per strategy; `keeps-metrics-p` answers it.
- **Drop `print-simple-lru-cache-strategy`.** CL's default `print-object` prints structs adequately for debugging; the source comment already flags this is `missing-larkc 29372` and CL-redundant.
- **The test functions name a property worth testing**: a randomized comparison between simple-LRU and the plain `cache` should agree on which entry is the LRU at every step, given the same access trace. Implementing those two test runs is a good spec-by-example.
- **Consider implementing `cache.lisp`'s missing eviction in terms of this file's strategy** instead of reimplementing. If the cache-strategy abstraction stays, the cache-with-LRU is just `metered-cache` over a `simple-lru-cache-strategy`.
