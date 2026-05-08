# Stacks

A LIFO stack stored as a CL list, paired with an explicit fixnum element count. The struct trades one extra word per stack for O(1) `stack-num` lookups, because a plain `(length list)` is O(n) and Cyc's callers query the count often enough that this matters in profiled paths. The locked variant is declared but unused in the surviving port. The whole file is 90 lines and intentionally tiny — `stacks.lisp` is here for the count, not for any other behavior. If you don't need O(1) length, `cl:cons` and `cl:car`/`cl:cdr` are the equivalent.

## Public API (stacks.lisp)

| Function | Purpose |
|---|---|
| `create-stack` | Allocate a fresh empty stack (`stack-num 0`, `stack-elements nil`). |
| `clear-stack stack` | Reset a stack in place to empty. Returns the stack. |
| `stack-empty-p stack` | T iff `stack-elements` is NIL. (Note: tests the list, not `stack-num`.) |
| `stack-push item stack` | Increment count, push onto the head of the element list. Returns the stack. |
| `stack-pop stack` | Decrement count, pop from the head. Returns the popped item, or NIL on an empty stack. |
| `stack-peek stack` | Return the top item without removing it. NIL on empty. |
| `do-stack-elements (item-var stack &key done) &body body` | Iterate from top to bottom. The `done` keyword is treated as an early-exit predicate; if a caller uses it, the macro emits a `warn` (the original semantics were ambiguous and the port chose this interpretation conservatively — see the TODO in the source). |

`stack`, `stack-p`, the `stack-num` and `stack-elements` accessors are emitted by `defstruct`. `locked-stack` is also a `defstruct` (`lock`, `stack` slots) but has no constructors, accessors, or operations beyond what `defstruct` generates — the source comment notes "rest of it seems missing-larkc."

## Why an explicit count?

A list-backed stack is the obvious CL representation, and most callers don't care about size. But a few hot spots ask "how many items are on this stack right now?" frequently enough that the per-push/pop integer increment is worth its weight. The struct preserves the invariant `stack-num = (length stack-elements)` across every public mutator. `stack-empty-p` checks the list directly rather than `(zerop stack-num)`; this is defensive (the list is the source of truth), but in practice the two are kept in lockstep.

In real Cyc, the count would also be available on the `locked-stack` after acquiring the lock, but that variant has no working operations in this port. A clean rewrite that uses the host language's stack primitive (Java `Deque`, Python `list`, CL `cons` cells with a separate counter when needed) gets the same property for free.

## What uses it

Two surviving consumer patterns, both in the inference engine:

**1. The "happiness index" in `inference/harness/inference-tactician.lisp`** (lines 352-410) — a two-level structure:
- A hashtable `happiness → object-stack` (the secondary buckets).
- A priority queue ranked by happiness (the primary index).

Each happiness bucket is a `stack`. `problem-happiness-index-add` pushes an object onto the bucket, optionally enqueueing the happiness in the priority queue if it's a new bucket. `problem-happiness-index-next` pops from the highest-ranked bucket and removes that happiness from the priority queue when the bucket empties. The stack here is the LIFO discipline within a single happiness level — last-added candidate is the next one tried.

**2. The "removal index" in `inference/harness/inference-heuristic-balanced-tactician.lisp`** (lines 44-105) — a depth-first stack of removal strategems being explored:
- `(create-stack)` builds the index.
- `stack-push` adds a fresh strategem when descending.
- `stack-pop` retreats one level.
- `stack-peek` returns the current strategem.
- `stack-empty-p` is the loop termination condition.

The struct's `:comment` slot literally says "uses a depth-first stack for removal problems," explicitly identifying the data-structure choice with the search discipline. There's a parallel `new-root-index` queue in the same struct used for breadth-first treatment of new-root problems — same shape, opposite traversal order, see `queues.md`.

Outside of these two files, no code calls `stack-push`/`stack-pop`/`create-stack`. The accessors `stack-num`, `stack-elements`, and the macro `do-stack-elements` have zero consumers in the rest of `larkc-cycl/`.

The unrelated `*defn-stack*` in `at-defns.lisp` is a stack-of-strings discipline implemented on hashtables (`push-hash` / `pop-hash`); it does not use this `stack` struct. Likewise, `task-processor.lisp:object-stack` and `java-api-kernel.lisp` mention stacks in identifier names but do not call the API in this file.

## CFASL

There is no CFASL opcode for `stack`. Stacks live entirely in memory. They are temporary scratch structures inside inference and are not part of any persisted KB.

## Notes for a clean rewrite

- **Use the host's deque/stack primitive.** CL's list with `push` / `pop` / `length` is fine if O(n) length is acceptable; otherwise `cl-containers:queue-container` or any deque-backed collection. The dedicated 90-line file earns nothing.
- **The explicit count is the only design feature worth preserving.** If callers need O(1) `size`, give them O(1) `size`. If they don't (and most don't), drop the field.
- **Drop `locked-stack` entirely.** It has no operations. If thread-safe stacks are needed, wrap whatever the host language provides — concurrent stacks are a solved problem.
- **Drop the `do-stack-elements done` parameter.** The TODO note says the original semantics were unclear; nobody uses it; pick `loop` / `dolist` / iterator and move on.
- **Inline at call sites.** The two surviving consumers (happiness index, removal-strategem index) each use a stack in one local block of code. A direct `cl:cons`-backed stack with a separate counter, or even a CL list with a `defstruct` defined right next to the consumer, removes the cross-file dependency.
