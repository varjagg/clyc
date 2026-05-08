# Queues (FIFO and priority FIFO)

Two queue flavors live in `queues.lisp`:

- **`queue`** — a plain FIFO. Cons-list backed, with a `last` tail pointer for O(1) `enqueue` and an explicit `num` slot for O(1) `queue-size`. This is the workhorse used everywhere in the inference engine and TMS.
- **`priority-queue`** — a priority FIFO with an optional max-size, ranked by a caller-supplied `rank-func` and ordered by a caller-supplied `comp-func`. The backing store is a [binary tree](binary-tree.md) where each node's `state` is a FIFO bucket of equally-ranked items (so two items with the same rank are dequeued in insertion order). Used by the task processor and the inference happiness index.

Two more structs are declared but have no implementation: `lazy-priority-queue` and `locked-queue` / `locked-p-queue`. These would be Cyc's eager-vs-lazy heap variant and concurrency-safe wrappers respectively, but in the LarKC port they're skeletons only.

## Public API

### Plain FIFO (`queue`)

| Function | Purpose |
|---|---|
| `create-queue` | Allocate an empty queue. |
| `clear-queue queue` | Reset in place. Returns the queue. |
| `queue-empty-p queue` | T iff there are no elements. (inline) |
| `queue-size queue` | Element count from the cached `q-num` slot. (inline) |
| `enqueue item queue` | Append to the tail in O(1) using the `q-last` cell. Returns the queue. |
| `dequeue queue` | Remove and return the head; updates `q-last` to NIL when the queue empties. NIL on empty queue. |
| `remqueue item queue &optional test` | Destructively remove **all** occurrences of `item` (default `eql`); preserves count and tail-cell invariants. Returns the queue. |
| `queue-peek queue` | Return the head without removing it. (inline) |

The `queue` struct slots are `(num 0 :type fixnum)`, `elements`, and `last`. The element count, head pointer, and tail pointer are kept in lockstep across every mutator; this is the primary invariant the API protects.

### Priority FIFO (`priority-queue`)

| Function | Purpose |
|---|---|
| `create-p-queue max-size rank-func &optional comp-func` | Allocate a priority queue. `comp-func` defaults to `#'<`. `max-size` may be NIL for unbounded. |
| `p-queue-size priority-queue` | Element count. (inline) |
| `p-queue-empty-p priority-queue` | T iff size is 0. (inline) |
| `p-queue-full-p priority-queue` | T iff `max-size` is set and size equals it. |
| `p-queue-best priority-queue` | Return the highest-priority item (smallest under `comp-func`) without removing it. Walks the binary tree's leftmost path, then takes the head of that node's bucket via `pq-collision-next`. |
| `p-enqueue item priority-queue` | Insert `item`. Returns 3 values: `(priority-queue bumped? bumped-item)`. The bumped-on-overflow path (when the queue is full and a worse item must be evicted) is `missing-larkc 29894`; in this port, calling `p-enqueue` on a full queue is broken. |
| `p-dequeue priority-queue &optional worst?` | Remove and return the best item. With `worst?` non-NIL, would remove the worst-ranked item — `missing-larkc 29895`, so dequeue-worst is broken in this port. |

The four `pq-collision-*` callbacks are passed into `btree-insert` / `btree-remove` as the `add-val-func` / `rem-val-func` / `empty-func`, plus one extra `next` callback used by `p-queue-best`:

| Function | Purpose |
|---|---|
| `pq-collision-enter item bucket` | Append `item` to the end of the bucket list. (Why the FIFO discipline: items with the same rank dequeue in insertion order.) |
| `pq-collision-next bucket` | Return the head of the bucket. |
| `pq-collision-remove item bucket` | Delete the first occurrence of `item` from the bucket. |
| `pq-collision-empty bucket` | T iff the bucket is empty (NIL). |

## Why two flavors?

The two queue types solve unrelated problems and the only thing they share is the word "queue" in their names.

**The plain FIFO is a sequencer.** When code wants to process items in arrival order with O(1) push and O(1) pop, the cons-list-with-tail-pointer is the textbook implementation. The cached `num` slot makes `queue-size` O(1), which is wanted because callers regularly compare against worry-thresholds (`*transcript-queue-worry-size*` in `agenda.lisp` is 20; `*worry-transmit-size*` is similar). A plain `(length list)` would be O(n) and the worry-checks happen on the hot path.

**The priority FIFO is a scheduler.** When code wants to process items in priority order — best first — and break ties FIFO-style, you need an ordered map from priority to a queue of items. The implementation uses [`binary-tree`](binary-tree.md) as the ordered map and the binary-tree node's `state` slot as the FIFO bucket. The `pq-collision-*` callbacks compose those two layers. This is the only consumer of `binary-tree.lisp` in the entire codebase — the BST exists for the priority queue and nothing else. A clean rewrite using a real heap (with secondary FIFO buckets per heap entry) collapses the two files into one.

The `lazy-priority-queue` struct (slots `ordered-items`, `new-items`) is the **deferred-merge** variant: items go into `new-items` on insertion and are merged into `ordered-items` only when the priority is queried. This is a classic optimisation when bursts of insertions are followed by occasional dequeues; in the LarKC port it has no implementation.

## What uses it

### Plain FIFO consumers

The FIFO is used in roughly three roles:

**1. Pending-work queues in inference and forward propagation.**
- `inference/harness/forward.lisp:68,150,159,177,192,211` — the forward inference environment is a queue of assertions waiting to be propagated.
- `inference/harness/inference-analysis.lisp:98,488,513-514` — a queue of asked queries pending recording (`*asked-queries-queue*`).
- `inference/harness/inference-datastructures-inference.lisp:216,222,1271,1109` — every inference owns two queues: `new-answer-justifications` (results not yet handed back) and `interrupting-processes` (processes that called for a halt).
- `inference/harness/inference-heuristic-balanced-tactician.lisp:45,61,66-67,109,114` — the `new-root-index` queue inside a balanced strategy (paired with a `removal-index` stack — see [stacks.md](stacks.md)). The struct comment explicitly contrasts "depth-first stack" with "breadth-first queue."

**2. The TMS's pending-support queue.**
- `kb-hl-supports.lisp:444-449,530-532` — `*tms-kb-hl-support-queue*` is a queue of KB-HL-supports awaiting truth-maintenance recompute. The `enqueueing-kb-hl-supports-for-tms?` check + `dequeue` loop is the standard producer/consumer pattern.

**3. Connection pools and mailboxes.**
- `hl-interface-infrastructure.lisp:73` — `*remote-hl-store-connection-pool*` is a queue of free connections.
- `kb-control-vars.lisp:91` — `*forward-inference-environment*` is a default queue handed to forward inference.

**Specialist queue-of-something at the agenda layer:** `agenda.lisp` and `operation-communication.lisp` use the names `transcript-queue-empty`, `transmit-queue-empty`, `auxiliary-queue-empty`, `local-queue-empty`, etc. These are wrappers over operation-storage data structures that may or may not be plain `queue`s in this port — see [inference/agenda.md](../inference/agenda.md).

**Tries:** `tries.lisp:409` calls `(create-queue)` to hold a per-trie-node FIFO of completion candidates.

**`remqueue` consumer:** `inference/harness/forward.lisp:155-159` and `tms.lisp:207`. This is why `remqueue` exists and why it preserves count/tail invariants — TMS retraction needs to remove an assertion from the middle of the queue without breaking the size cache.

### Priority FIFO consumers

Only two files build priority queues:

**1. `task-processor.lisp:521,575,631`** — the **API task pool**. `tpool-request-queue` is a `priority-queue` ranked by `ti-priority` (task-info priority field), capped at `*task-request-queue-max-size*` (500). Worker threads `p-dequeue` to pull the next task; clients `p-enqueue` to submit. This is the queue that orders incoming API requests by their declared priority.

**2. `inference/harness/inference-tactician.lisp:354,359,370,379,396,406`** — the **happiness index**. `greatest-happiness-index` is a `priority-queue` ranked by `#'identity` (the items themselves are happiness values, no separate ranking) and ordered by `#'happiness->` (so "best" is the **largest** happiness, not the smallest — see the use of `>` instead of `<`). It tracks which happiness levels currently have problems waiting; the actual problems are stored in a parallel hashtable of stacks (see [stacks.md](stacks.md)).

No other file calls `create-p-queue`. The priority queue is genuinely a low-traffic structure used by exactly two inference subsystems.

## CFASL

| Opcode | Constant | Purpose |
|---|---|---|
| 131 (wide) | `*cfasl-wide-opcode-queue*` | Reserved for plain `queue` serialization. No `cfasl-input-*` / `cfasl-output-*` method is registered against it in this port — queues are runtime-only structures and the opcode exists against an old format that does not appear in surviving consumers. |

`priority-queue` has no opcode. Both queue flavors live entirely in memory.

## Notes for a clean rewrite

### Plain FIFO

- **Use the host's deque.** Java's `ArrayDeque`, Python's `collections.deque`, Rust's `VecDeque`, modern CL's `cl-containers:basic-queue` — every modern language has an O(1) deque. The cons-list-with-tail-pointer trick is only needed when the language doesn't.
- **Keep the cached size.** O(1) `size` is genuinely useful (worry-thresholds, count-based heuristics) and the cost is one fixnum per queue. Whatever container the rewrite picks, make sure size is O(1).
- **`remqueue` semantics matter.** "Delete all occurrences while preserving count" is what the TMS retraction path needs. In a host language with a real deque, this becomes either `removeAll` / `filter` / `retain`, or a loop that walks once. Don't lose the contract.
- **Drop the `lazy-priority-queue` struct.** It's a skeleton with no implementation. If lazy merging turns out to matter, write it then with profiling evidence; speculatively reserving the type adds nothing.
- **Drop the `locked-queue` struct.** Concurrency-safe queues are a solved problem in every modern runtime — use the host's `BlockingQueue` / `Queue` / channel and be done with it.
- **The CFASL opcode 131 is reserved but unused — drop it from the format.**

### Priority FIFO

- **Replace the binary-tree backing store with a real binary heap.** A heap on an adjustable vector gives O(log n) insert and extract-best with no rebalancing dance and no per-node allocation. The tie-breaking FIFO bucket per heap entry is straightforward (just store a list at each entry, or use sub-priority indices).
- **Keep the rank-func/comp-func split.** It's awkward — most APIs let you pass one comparator. But the rank-func/comp-func split lets the priority queue cache the rank rather than recomputing it on every comparison, which matters when the rank is expensive (e.g. a tactician's heuristic score). Either keep that or guarantee that comparators are cheap.
- **Implement bounded-size eviction.** The current port's `bumped?` path is `missing-larkc 29894`; the task pool's max-size of 500 is enforced only by panic in this port. A real implementation evicts the worst-ranked item when full and returns it to the caller as the third return value (the `bumped-request-item` in `task-processor.lisp:631`).
- **Implement dequeue-worst.** The `worst?` flag on `p-dequeue` is the dual operation, also `missing-larkc`. A heap supporting both ends of the priority order is a min-max heap; alternatively, two heaps with cross-references; alternatively, ignore it if no caller needs it (in this port nothing does — it's only a flag).
- **Drop `pq-collision-*` as a public surface.** The collision-bucket abstraction leaks the binary-tree internals out of the priority queue. In a heap-backed rewrite, the bucket logic is internal to the heap entry's value type; callers should never see it.
