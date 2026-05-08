# Deck (stack/queue dispatch)

A trivial five-function shim that holds either a [`stack`](stacks.md) or a [`queue`](queues.md) and dispatches a unified `push`/`pop` API to whichever it holds. The whole file is 83 lines, the struct has two slots (`type` and `data`), and there is no other behavior. The point is **not to abstract over collections** — it's to let a single piece of search code pick BFS or DFS at runtime by passing `:queue` or `:stack` to `create-deck`. Eight files use this exact pattern, and several of them either choose between the two based on a search-order parameter (`ghl-search-methods.lisp`) or hard-code one type with the comment that the other could be used (most of the SBHL/AT recursion frames).

## Public API (deck.lisp)

| Function | Purpose |
|---|---|
| `create-deck type` | Allocate a deck. `type` is either `:queue` or `:stack`; the constructor calls `create-queue` or `create-stack` accordingly to fill the `data` slot. |
| `clear-deck deck` | Reset the underlying container in place. Returns the deck. |
| `deck-empty-p deck` | Dispatch to `queue-empty-p` or `stack-empty-p` on the inner container. |
| `deck-push elt deck` | Dispatch to `enqueue` or `stack-push`. Returns the deck. |
| `deck-pop deck` | Dispatch to `dequeue` or `stack-pop`. Returns the popped element. |

The `deck` struct has just `type` and `data`; the type discriminator is a keyword and the dispatch is a `case` statement in each operation. There are no further accessors, no peek, no size, no iteration macro, no CFASL opcode. The interface is deliberately minimal — exactly what a generic worklist algorithm needs.

## Why dispatch?

A graph-traversal algorithm parametrized over BFS-vs-DFS looks identical except for one thing: the worklist. BFS uses a FIFO queue (push to the back, pop from the front; oldest-first ordering yields breadth-first). DFS uses a LIFO stack (push to the top, pop from the top; newest-first ordering yields depth-first). Everything else — visited-set tracking, neighbor expansion, termination checks — is identical.

A function that wants to support both can either:
1. Branch on a flag inside the inner loop (annoying, error-prone).
2. Take the worklist as a parameter and trust the caller to pick the right shape.
3. Wrap a worklist that handles either dispatch internally — i.e. a deck.

`deck.lisp` is approach #3. The caller picks the type once at deck construction; the algorithm body is written against `deck-push` / `deck-pop` and works either way. This is the only purpose. The deck is **not** a deque (despite the suggestive name) — there's no double-ended access, no `deck-push-front` vs `deck-push-back`, no peek. It's a tagged union of stack and queue, deliberately limited to the four operations a worklist needs.

## What uses it

Every consumer is a graph traversal in the inference / KB-access stack:

**1. `ghl-search-methods.lisp:297-299, 453-455, 591-593`** — the canonical example. The code reads:

```
(let ((search-deck (if (ghl-depth-first-search-p v-search)
                       (create-deck :stack)
                       (create-deck :queue))))
  ...)
```

The GHL search struct has an `:order` slot defaulting to `:breadth-first` (`ghl-search-vars.lisp:41`), and `ghl-depth-first-search-p` consults it. Three different search routines in `ghl-search-methods.lisp` build a deck whose type matches the search order, then run the same body. This is exactly the design intent.

**2. `at-utilities.lisp:257-258, 471-472`** — the AT (arg-type) system's `most-specific-defns`-style traversals. These hard-code `:stack` (DFS), then run `deck-push` / `deck-pop` against `recur-deck`. The `deck-type` is a local let-binding even though it's never reassigned, suggesting it was once parameterised and got fixed during porting; the traversal would still work with `:queue`.

**3. `inference/inference-trampolines.lisp:162-163, 265-300`** — `inference-all-proper-spec-predicates-with-axiom-index` walks the spec-predicate hierarchy via a deck of `(node mode)` pairs. Hard-coded `:queue` (BFS).

**4. `tva-cache.lisp:129, 207-233`** and **`tva-utilities.lisp:213-214, 294-324`** — TVA closure walks. The `tva-cache.lisp` site hard-codes `:queue`; `tva-utilities.lisp` uses a `deck-type` let that is fixed at `:queue` but again has the parametric shape.

**5. `inference/modules/removal/removal-modules-tva-lookup.lisp:161, 315, 415` and `removal-modules-genlpreds-lookup.lisp:151` and `removal-modules-transitivity.lisp:77-78, 194-195`** — the removal-module bodies that walk genl-predicate / transitivity / TVA chains for backward inference. Mixed: tva-lookup hard-codes `:queue`; transitivity uses a `deck-type :queue` let.

In total, the `(deck-push elt recur-deck)` / `(setf node-and-predicate-mode (deck-pop recur-deck))` shape recurs across these eight files with **the same pattern of a node-walking loop** — push neighbors, pop next-to-process — exactly because they were written from a shared template that wanted BFS-vs-DFS as a knob.

## CFASL

There is no CFASL opcode for `deck`. Decks are transient scratch structures used during inference / KB walks and are never persisted.

## Notes for a clean rewrite

- **Drop the file. Inline the choice.** A clean rewrite has the host language's deque, queue, and stack primitives, all with O(1) push and pop. The dispatch shim earns nothing in modern code; the call sites can pick the right primitive directly. If a function genuinely wants the BFS-vs-DFS knob, take a `Function<E, Worklist<E>>` constructor parameter, or a strategy enum, or just two functions.
- **Most consumers don't actually need the knob.** Looking at the surviving consumers: only `ghl-search-methods.lisp` actually picks the type at runtime. Every other site hard-codes one. Those should just use the relevant container directly, no deck involved.
- **The knob, when it survives, belongs in the search struct, not in a generic shim.** `ghl-search-vars.lisp` already has the `:order` slot on the search struct itself. A clean rewrite makes the search engine read that slot and pick its worklist accordingly, without the deck indirection. The deck doesn't carry semantic information that the search struct doesn't already have.
- **Drop `:queue` and `:stack` as runtime keywords.** Picking a worklist shape via a keyword that gets case-dispatched in five different methods is the kind of dynamic dispatch that costs maintainability for no real flexibility. The host's type system can handle it directly.
- **The deck has no `peek`, no `size`, no iteration.** That's a deliberate minimum, but it's also a sign that callers were carefully written against the lowest-common-denominator API. A clean rewrite that uses real container types gets all those operations for free; whether the consumers want to use them is then a question for the consumer's design rather than the deck's.
