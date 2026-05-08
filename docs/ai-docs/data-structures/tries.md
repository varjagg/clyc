# Tries and finite-state transducers

`larkc-cycl/tries.lisp` is a **character-keyed trie** used to look up KB constants by their textual name and, more importantly, to enumerate every constant whose name has a given prefix. `larkc-cycl/finite-state-transducer.lisp` declares an FST struct intended to do tokenized pattern matching on input streams; in the LarKC port it's almost entirely stripped, but the struct shape and macro definition are kept for reconstruction.

The two systems are grouped here because the FST file is a near-empty companion that nothing in the surviving port consumes — its presence is design truth, not call-site truth.

## Why a trie, not a hashtable

Cyc's constant-completion problem: a user types `Person` and the editor must offer `Person`, `Person-Animal`, `Person-Female`, `PersonalComputer`, `PersonTypeByGender`, … without a linear scan of the constant list. A hashtable on the full name handles `constant-shell-from-name` (exact lookup) but cannot answer "every name starting with `Pers`" — a hash fundamentally destroys the prefix relationship between strings. The choice is:

- **Hashtable** — O(1) exact, **O(N) prefix** (must scan every key).
- **Sorted vector + binary-search-the-prefix-range** — O(log N) exact, O(log N + k) prefix, but every insert/delete is O(N).
- **Trie** — O(L) exact (L = name length), O(L + k) prefix, O(L) insert, O(L) delete.

For an editor latency target where N is hundreds of thousands of constants, hashtable-and-scan is unacceptable. A trie keyed on characters is the natural fit because the *use* is character-by-character: the user is typing, the system is filtering. Each keystroke walks one trie level; the surviving subtree's leaves are the answer set.

That's the whole story for `*constant-completion-table*` — it's the one trie the surviving LarKC port maintains.

## Trie shape

The `trie` struct itself is a small descriptor:

| Slot | Meaning |
|---|---|
| `name` | Display label. |
| `top-node` | The root cons cell — a sentinel `(:top . subnodes)`. |
| `unique` | If T, a string maps to one object and inserting a different object errors. If NIL, leaves hold lists. |
| `case-sensitive` | If T, character match uses `char=`; otherwise `char-equal`. |
| `entry-test-func` | Equality predicate for stored objects (default `#'eql`). Used to detect duplicate inserts and to remove. |
| `multi`, `multi-keys`, `multi-key-func` | Multi-trie machinery. **All multi-trie support is missing-larkc** — the slots survive but no surviving function ever sets them. |

The actual tree is **made of cons cells**, not structs. This is a SubL micro-optimization: a trie node is nothing more than `(key . subnodes)` where `subnodes` is a list of child nodes sorted by key. A leaf node has `key = :end` and the cdr is the stored object (unique tries) or a list of stored objects (non-unique tries):

```
nonterminal node:  (#\P . ( (#\e . (...) ) (#\h . (...) ) ))
terminal node:     (:end . #<constant Person>)             ; unique
                   (:end #<constant1> #<constant2>)        ; non-unique (cdr is a list)
```

Children are kept in **sorted character order** so insertion can stop early. The leaf is identified by `(eq (car node) :end)`; nonterminals carry a character (or potentially a list — the author's TODO calls out that the multi-trie code might use list-keyed nodes, but no surviving caller does).

The lock-free pool `*trie-free-list*` and `*trie-free-lock*` are SubL's structure-resourcing pattern (reuse trie struct shells across allocations). `get-trie` is the allocation entry: when `*structure-resourcing-enabled*` is on it pops from the free list (`missing-larkc 12492`), and when off it just calls `make-trie` and `init-trie`. The pool path is stripped in LarKC.

## Public API (tries.lisp)

| Function | Purpose |
|---|---|
| `(create-trie unique &optional name (case-sensitive t) (test #'eql))` | Allocate and initialize a fresh trie. |
| `(trie-insert trie string &optional object start end)` | Walk/extend the trie down the chars of `string[start..end]`, then attach a leaf carrying `object` (or push it onto the existing leaf's list, in the non-unique case). For unique tries, an existing different leaf signals an error. |
| `(trie-remove trie string &optional object start end)` | Walk down to the leaf and remove `object`. For non-unique tries, removes one entry from the leaf's list and keeps the leaf if any remain. For unique tries (or last entry), prunes the leaf and any path that becomes a dangling chain — this is what `last-branching-node` / `last-branch` track during the descent. |
| `(trie-exact trie string &optional case-sensitive? start end)` | Return the unique object indexed by `string`, or NIL. Errors if the trie is non-unique (the API contract is "exact lookup needs uniqueness"). |
| `(trie-prefix trie string &optional case-sensitive? exact-length? start end)` | Return a list of every object indexed by a string starting with `string` (or, with `exact-length? = T`, exactly equal to `string`). Implemented via `trie-prefix-recursive` / `trie-prefix-recursive-int` collecting into the dynamic var `*trie-objects*`. |
| `(new-trie-iterator trie &optional forward?)` | Return an iterator (per the `iteration.lisp` protocol) yielding objects in sorted-key order. Used by `kb-new-constant-completion-iterator-internal` to walk all constants by name. |

`trie-prefix-recursive-int` is the workhorse: at each level it picks the subnode whose key matches the next char and recurses; at depth = `stop` it gathers all leaves under the current node (or just the immediate leaf when `exact-length?` is set). The `exact-length?`-NIL case under `trie-prefix-recursive-int`'s "consume all leaves below this point" branch is `missing-larkc 12474` — the LarKC build doesn't ship general-prefix gathering, only exact-length lookup. **This is a hole in the LarKC port that a clean rewrite must fill** — Cyc the engine returns every object in the subtree at the matched depth, which is exactly the behavior an editor's auto-complete needs.

Likewise, `trie-prefix` errors out via `missing-larkc 12549` when `case-sensitive?` is requested but the trie is case-insensitive — the port only supports case-insensitive prefix lookup against case-insensitive tries.

The trie iterator (`new-trie-iterator-state`, `trie-iterator-next`, `trie-iterator-next-unique`) is a stack-based DFS over leaves. It survives for unique tries; non-unique uses a queue and is `missing-larkc 12530`. The "done" check (`trie-iterator-done`) eventually trampolines into `missing-larkc 12528`, so even the unique-iterator path has a hole the rewrite must close.

### Multi-trie (entirely missing-larkc)

The `multi`, `multi-keys`, `multi-key-func` slots and the helpers `multi-trie-new-insert-mark` / `multi-trie-remove-mark` / `*trie-relevant-marks*` / `trie-relevant-ancestor-path?` / `trie-relevant-object` / `initialize-trie-ancestor-tracking` are the surface of a planned **partitioned trie** where each entry is tagged with one or more "marks" (e.g. microtheory, KB partition, namespace) and lookups can be filtered to only return entries whose ancestor path / leaf object passes a mark predicate. Every implementing function is `(:ignore t)` — they exist as no-op stubs returning NIL or T to keep the surrounding code compilable. The clean rewrite needs to either:

- Implement the multi-trie design properly (per-leaf mark sets, per-path mark accumulator, configurable filters), or
- Delete the surface and let callers filter post-hoc by walking the result list.

`*require-valid-constants*` in `constant-completion-low.lisp` is a tiny version of the latter approach: filter the trie's output by `valid-constant-handle-p` outside the trie. For the constant-completion use case that's enough; multi-trie's design overhead isn't earning its keep.

## Where the trie is actually used

There is exactly **one surviving production trie**: `*constant-completion-table*`, defined in `constant-completion-low.lisp`. It maps constant name strings → constant structs.

Lifecycle of an entry in this trie:

| Situation | Effect |
|---|---|
| A constant is created and given a name (`make-constant-from-internal-id-and-name` or after a name is set on a fresh shell) | `add-constant-to-completions` calls `trie-insert` with the name and the constant. |
| A constant is renamed | `rename-constant` calls `remove-constant-from-completions` with the old name then `add-constant-to-completions` with the new name. |
| A constant is removed from the KB | `remove-constant-from-completions` calls `trie-remove`. |
| The user types a prefix in the KE editor or calls the API | `kb-constant-complete-internal` calls `trie-prefix`; the result is filtered by `*require-valid-constants*`. |
| The user types a full name | `constant-shell-from-name` / `kb-constant-complete-exact-internal` call `trie-exact`. |
| Bulk iteration over constants by name (e.g. to dump in alphabetical order) | `kb-new-constant-completion-iterator-internal` returns a `new-trie-iterator`. |

This trie is **not** the primary "look up a constant by name" path — that goes through the `*constant-name-to-constant-table*` hashtable in `constants-low.lisp` for O(1) exact lookup. The trie exists specifically because the hashtable cannot answer prefix queries.

The trie is **not serialized to CFASL.** It is rebuilt at KB-load time by walking every loaded constant and calling `add-constant-to-completions`. This is why no CFASL opcodes are registered for the trie data structure — it's pure derived state. A clean rewrite can keep this; it costs O(N·L) at load time but avoids dump-format complexity and keeps the trie cache-line-fresh.

No other surviving caller in `larkc-cycl/` invokes `create-trie`. The data structure is general-purpose but in the stripped port has only this one consumer. (Multi-trie support, were it implemented, would presumably gain consumers in NL parsing or other lexicon-driven paths.)

## Finite-state transducer (finite-state-transducer.lisp)

A finite-state transducer is **a state machine that, while consuming input tokens, emits output tokens** (vs. a finite-state acceptor, which only says yes/no). Cyc would use one for tokenized pattern matching over CycL formulas or NL text — e.g. recognize a `<NP> <VP>` sequence in a pre-tokenized sentence and emit a structured match.

The struct (declared, all functions stubbed):

| Slot | Role |
|---|---|
| `initial-state` | Where execution starts. |
| `final-states` | Set of accepting states. |
| `machine-table` | The transition table: `(state, input-key) → (next-state, action)`. |
| `token-builder` | Caller-supplied callback that turns raw input into the tokens the machine sees. |
| `input` | The current input sequence. |
| `current-token-index` | Position in the input. |
| `current-state` | Current machine state. |
| `memory` | Scratch slot for `fst-remember` / `fst-backup` (look-ahead with rollback). |
| `indexed-output` | The accumulating output. |

**Every function is missing-larkc** (`finite-state-transducer-p`, `make-finite-state-transducer`, `new-finite-state-transducer`, `fst-match`, `fst-match-global`, `fst-initialize`, `fst-match-internal`, `fst-run`, `fst-current-token`, `fst-final-state-p`, `fst-action-p`, `fst-execute`, `fst-emit`, `fst-remember`, `fst-backup`, `machine-table-set`, `machine-table-get`, `key-matches`, `max-state`, `fst-output`, `fst-output-start`, `fst-output-end`). The `fst-do-match` macro is reconstructed from orphan Internal Constants but the underlying functions it expands to are stubs — the macro is shape-correct but not currently runnable.

There are **no surviving callers of any FST function in the LarKC port.** `system-version.lisp` lists `"finite-state-transducer"` in the file-load order, but that's bookkeeping. A grep for `fst-`, `finite-state-transducer`, or `make-finite-state-transducer` outside the file itself returns only the system-version reference.

This is the cleanest example of "missing-larkc as design truth" — Cyc the engine had a working FST module presumably used by NL or pattern-matching subsystems; LarKC stripped both the module and its consumers; the file is preserved as the schematic for what to build back.

A clean rewrite has two options:

- **Drop the file.** If pattern matching over tokenized streams is needed, write it directly when needed, or use a host-language regex / parser combinator library. The 14-function FST API is overhead that pays off only if there are many consumers of the same pattern-matching engine.
- **Implement it from the orphan structure.** The slot list is enough to reconstruct: a transition table indexed by `(state, key)`, an interpreter loop that reads tokens, looks up the transition, executes its action, and advances the state. Memory + backup means it supports backtracking — useful for non-deterministic patterns. If NL or related subsystems reappear, build it; otherwise leave it out.

## CFASL serialization

Neither tries nor FSTs have CFASL opcodes registered. Tries are derived state (rebuilt from the constant table at load time). FSTs were presumably part of a separate persistence story that's also stripped. There is no `register-cfasl` reference for either type.

## Notes for a clean rewrite

### Tries

- **Keep the data structure; replace the cons-based representation.** A trie node should be a struct or a small array, not a cons of `(key . subnodes)`. The cons trick was fine in SubL where struct allocation was expensive; in modern Lisp it just makes the code harder to read. With named slots, `(:end . object)` and `(char . children)` stop being two flavors of the same shape and the `trie-leaf-node-p` check becomes a discriminator that the compiler can specialize.
- **A radix tree (path-compressed trie) cuts memory dramatically.** For a constant name like `PersonalComputer-EarlyVersionNumberValueTen`, a character-per-level trie has ~40 nodes; a radix tree compresses unbranching chains to `("PersonalComputer-EarlyVersionNumberValue" . ("Ten" . #<leaf>))` and uses 2 nodes. With ~10⁵ constants, this is a 10× memory difference. Radix-tree prefix lookup is identical in complexity but constant-factor faster.
- **Decide the case-sensitivity story up front.** The current code has case-sensitive trie storage and a per-call `case-sensitive?` lookup flag, with a missing-larkc when they conflict. The clean rewrite should pick one: either store both cases (canonicalize-on-insert + a side index for original case), or store only canonical and let the caller normalize before lookup. The dual-mode-with-runtime-flag is a bug magnet.
- **The leaf representation should distinguish "single object" from "list of objects" by type, not by trie configuration.** A unique trie's leaves carry an object directly; a non-unique trie's leaves carry a list. This means lookup code branches on the trie configuration when it should branch on the leaf cell. A clean rewrite stores `(:end . list)` always and the unique constraint is enforced at insert time only.
- **Drop the multi-trie design or commit to it.** The current state — slots present, helpers all `(:ignore t)`, no callers — is the worst case. Either implement mark-based partitioning properly or delete the slots. For the constant-completion use case, post-hoc filtering via `*require-valid-constants*` works fine.
- **`trie-prefix` should return an iterator, not a list.** A user typing `P` in the editor should not allocate a list of 50,000 constants; a lazy iterator yields just enough to fill the visible suggestion list. The current `*trie-objects*` dynamic-var-of-results pattern is a list-builder; the iteration framework already exists in `iteration.lisp`.
- **The structure-resourcing pool is dead code.** `*trie-free-list*` is never populated because the surviving `get-trie` path always does `make-trie`. Delete the slots and the lock; modern GCs handle small struct allocation.
- **The ancestor-tracking machinery is also dead code.** Every function that reads the ancestor path is a no-op. If multi-trie is dropped, drop ancestor tracking with it. If multi-trie is kept, the ancestor stack should be a real data structure threaded through the recursion rather than a dynamic var.
- **Keep the iterator API but use the host's iteration.** CL has `loop`, generators libraries, etc. The Cyc-specific `iteration` protocol adds nothing for a trie iterator.

### Finite-state transducers

- **Decide whether the rewrite needs FSTs at all.** No surviving caller. If NL parsing returns and needs them, implement; otherwise delete the file.
- **If implementing: model the transition table as a hashtable keyed on `(state . input-key)`, not the slot-soup of the current struct.** A clean FST has `transitions: Map<(State, Token), (State, Action)>` plus `initial`, `accepting`, an interpreter loop. The slot list in the current struct conflates configuration (`initial-state`, `final-states`, `machine-table`, `token-builder`) with execution state (`current-token-index`, `current-state`, `memory`, `indexed-output`); a rewrite should split these into separate "definition" and "running instance" types.
- **Make `fst-remember` / `fst-backup` an explicit nondeterminism mechanism.** A single `memory` slot suggests one-step lookahead; for serious pattern matching the rewrite probably wants a real continuation or a backtracking stack.
