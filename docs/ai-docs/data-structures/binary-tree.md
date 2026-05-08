# Binary tree (and the missing-larkc AVL tree)

A homegrown unbalanced binary search tree, plus a defstruct-only sketch of an AVL tree whose implementation is `missing-larkc`. The unbalanced tree is **not** a general-purpose container — its sole consumer is the priority queue in `queues.lisp`, which uses it as an ordered key→bucket store. Nothing else in the codebase touches `btree-insert`, `btree-remove`, or `btree-find-best`. The AVL tree exists only as a struct skeleton plus three CFASL opcodes; in real Cyc it would be the balanced version of the same idea, but in the LarKC port there is no code that builds, walks, or serializes one.

## What the unbalanced tree is for

`p-enqueue` / `p-dequeue` in `queues.lisp` thread three callbacks (`rank-func`, `comp-func`, plus the four `pq-collision-*` functions) into `btree-insert` / `btree-remove` / `btree-find-best`. The keys ranked by `rank-func` become `bt-tag`s; the values stored at each node become `bt-state`s; the `add-val-func` / `rem-val-func` / `empty-func` callbacks let the priority queue stash a list of equal-rank items in the node's `state` slot. So the binary tree is really doing two things at once: it's an **ordered map from rank to bucket** (the tree structure) and the buckets are FIFOs of equally-ranked items (the lists in `bt-state`). That's why it has callbacks on insert/remove instead of just storing the value directly — collision handling is delegated to the caller.

The "best" operation walks `bt-lower` repeatedly until it hits NIL — i.e. the leftmost node, which under the user-supplied `comp-func` is the minimum. `p-queue-best` then asks `pq-collision-next` for the head of that node's bucket. There is no symmetric `btree-find-worst`; `p-dequeue` with `worst?` is `missing-larkc 29895`.

## Public API (binary-tree.lisp)

| Function | Purpose |
|---|---|
| `init-btree btree` | Zero out all four slots of a `btree`. Used after pulling one off the free list. |
| `free-btree-p object` | Predicate: is this btree currently on the free list? Detected by `(eq state :free)`. |
| `free-btree object` | Place a btree on the free list (no-op if already freed). The free list and lock are gated by `*structure-resourcing-enabled*`. |
| `get-btree` | Pop a btree off the free list; allocate a fresh one if none available or resourcing is disabled. |
| `btree-insert val tag btree comp-func add-val-func` | Find or create the node tagged `tag`; replace its state with `(funcall add-val-func val state)`. Returns the (possibly new) tree root. |
| `btree-remove val tag btree comp-func rem-val-func &optional empty-func` | Find the node, replace its state via `rem-val-func`; if the result satisfies `empty-func` (default `#'null`), splice the node out. Returns the new tree root. |
| `btree-find-best btree` | Return the leftmost node (smallest under `comp-func`). |
| `incomparable func obj1 obj2` | Predicate: `(not (or (func a b) (func b a)))` — used to detect tag equality given only a strict-less-than comparator. |
| `btree-find-aux tag btree comp-func &optional create?` | Internal walk; with `create?` t, allocates and links a new node when the tag isn't found. Returns `(values found-node parent-node)`. |
| `btree-insert-aux new old comp-func` | Internal: link a freshly allocated node as either the lower or higher child of `old`. Asserts that the slot is empty (`must-not`); otherwise data would be silently lost. |
| `btree-remove-aux node back top comp-func` | Internal: unlink `node` from its parent `back`, splicing in one of its children as replacement. If both children are present the surviving one is picked at random; the loser would need to be reinserted, but **that path is `missing-larkc 11595`** — so removal of internal nodes with two children is not actually working in this port. |

`*validate-btrees*` and `*btree-remove-debugging*` are diagnostic toggles whose enabled paths are `missing-larkc`. `*btree-tags*` is a defparameter holding `nil` with no consumers.

## The `btree` struct

```
(defstruct (btree (:conc-name "BT-"))
  tag       ; the rank/key under comp-func
  state     ; the per-node payload (a bucket list, in priority-queue use)
  lower     ; left child (smaller tag)
  higher)   ; right child (larger tag)
```

No parent pointer, no balance factor, no count. The tree is a plain linked-cell BST; balancing is the AVL tree's job (and the AVL tree is missing).

## Object pool (free list)

`*btree-free-list*` and `*btree-free-lock*` implement structure pooling: `free-btree` returns a node to the list, `get-btree` pops one. The pooling is conditional on `*structure-resourcing-enabled*`; when disabled, every `get-btree` is a fresh `make-btree`. The freed-node's `bt-tag` slot doubles as the "next" pointer in the free list — the pool is intrusive.

The TODO at `get-btree` notes the pool's invariants are sketchy: nodes can land on the free list without their `state` being `:free`, and the lock-held removal loop seemingly trusts that no concurrent re-entry happens. A clean rewrite should either drop pooling entirely (modern GCs handle short-lived nodes fine) or use a real lock-free free-list primitive.

## CFASL opcodes (declared, no behavior in this port)

| Opcode | Constant | Purpose |
|---|---|---|
| 19 | `*cfasl-opcode-btree*` | A binary-tree value. |
| 20 | `*cfasl-opcode-legacy-btree-low*` | Legacy left-child marker (older tree format). |
| 21 | `*cfasl-opcode-legacy-btree-high*` | Legacy right-child marker. |
| 22 | `*cfasl-opcode-legacy-btree-leaf*` | Legacy leaf marker. |
| 80 | `*cfasl-opcode-avl-tree*` | An AVL-tree value. |
| 81 | `*cfasl-opcode-avl-tree-node*` | An AVL-tree-node value. |

The opcodes are declared as constants but no `cfasl-input-*` / `cfasl-output-*` methods reference them — the legacy formats are dead format slots reserved against an old dump file, and the live btree/avl input/output routines are stripped.

## The AVL tree (skeleton only)

```
(defstruct avl-tree root test size)
(defstruct avl-tree-node data balance lower higher)
```

That is the entirety of the AVL machinery in this port. There is no insert, no remove, no rotate, no rebalance, no walker, no serializer, and no consumer. In real Cyc the AVL tree would be the **balanced** counterpart used wherever `btree-insert` is called today — same priority-queue role, but with O(log n) worst-case guarantees instead of the unbalanced tree's O(n) degeneration on monotonic key sequences. The `balance` slot on the node and the `test` slot on the tree are the standard AVL pieces. A clean rewrite that needs an ordered map should pick a real balanced tree (red-black, AVL, or skip-list) once and use it for all such jobs; keeping two different tree implementations for the same role is a SubL-era artefact.

## Where this fits

```
p-enqueue / p-dequeue  (queues.lisp)
  → btree-insert / btree-remove / btree-find-best  (binary-tree.lisp)
    → btree-find-aux  (walk left or right under comp-func)
      → get-btree  (pool or fresh node)
```

Outside of `queues.lisp`, the only references to `btree`-anything in the codebase are:
- `eval-in-api-registrations.lisp` exposes `bt-lower` and `bt-higher` to the API for debugging.
- `kb-paths.lisp` has two unrelated `*-btree?` predicates (`instance-btree?`, `bookkeeping-btree?`) that are commented-out declareFunctions; they're a separate naming clash, not real binary-tree consumers.

So the dependency graph is essentially `queues.lisp → binary-tree.lisp` and nothing else. If the priority queue moves to a heap (the natural choice), `binary-tree.lisp` can be deleted in its entirety.

## Notes for a clean rewrite

- **The priority queue is the only caller. Pick a real data structure for it and delete this file.** A binary heap on a CL adjustable vector gives O(log n) insert and extract-best with no rebalancing dance and no per-node allocation. The collision-bucket layer (multiple items at the same rank) becomes a secondary list inside the heap entry, which is what the current code already does at the `bt-state` slot. There is no architectural reason for the BST shape.
- **If the consumer needs an ordered map (key range queries, in-order traversal), use a balanced tree from a real library** (`cl-containers`, `fset`, etc.). Don't write another homegrown one.
- **Drop the structure-resourcing pool.** Two btree allocation sites in the entire codebase (insert and the create-on-find path) do not justify a pool, a lock, and an intrusive free list. SBCL's GC handles this kind of allocation pattern without notice.
- **Drop the AVL tree skeleton.** It's three structs, three opcodes, and no behavior. If a future version needs a balanced ordered map, write it then; carrying empty type declarations forward serves no one.
- **Drop the legacy-btree CFASL opcodes 20/21/22.** They are slots reserved against an older serialization format that will not appear in any KB image the rewrite needs to load. If backward-compat with old dumps is wanted, it should live behind a versioned deserializer rather than as constants in the binary-tree file.
- **Drop the `*btree-tags*` defparameter and `*validate-btrees*` / `*btree-remove-debugging*` flags.** They are vestigial.
- **The `btree-remove-aux` two-child case is broken in this port** (`missing-larkc 11595`). If the priority queue ever grew to need internal-node deletion with both children present (it currently does not, because collision buckets keep node count modest), this would be the bug to find. A clean rewrite using a heap sidesteps the issue entirely.
