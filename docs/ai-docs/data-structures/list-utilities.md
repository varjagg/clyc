# List utilities (and transform-list-utilities)

A 1027-line generic list-and-tree library plus a 239-line companion (`transform-list-utilities.lisp`) for repeated tree-rewriting. Together they provide everything Cyc code reaches for above bare CL `cons` / `car` / `cdr`: length comparisons that don't traverse to the end, proper-vs-dotted predicates, set operations with hashtable fast paths, alist and plist helpers, tree search and gather, permutations and Cartesian products, and a recursive transform-until-fixpoint engine.

The two files split along function-vs-tree-rewriting lines: `list-utilities.lisp` is the broad catalog, `transform-list-utilities.lisp` is the fixpoint-iterating tree transformer used by canonicalization, inference, and unification. Keep them separate in a rewrite only if the tree-transformation engine grows beyond a few helpers.

There are no data structures here in the invariant-bearing sense — just functions over lists, trees, alists, and plists.

## How to read this doc

The file is too large for a per-function table to be useful. Below, functions are bucketed by **purpose**. Each bucket has a representative table and notes on the few entries with non-obvious semantics. Functions with a single Cyc-specific consumer are called out by name; everything else is treated as a generic helper.

## Configuration

| Var | Purpose |
|---|---|
| `*magic-hashing-cutoff*` (80) | Length threshold above which `fast-set-difference`, `fast-subset?`, `fast-delete-duplicates`, etc. switch from O(N²) member-walk to O(N) hashtable. The TODO notes this is unprofiled; the constant is shared across all the `fast-*` family. |
| `*remove-duplicates-{eq,eql,equal,equalp}-table*` + their locks | Reusable scratch hashtables for `fast-delete-duplicates` to amortize allocation. Each has a `bordeaux-threads` lock paired with it. |
| `*default-recursion-limit*` (212), `*default-transformation-max*` (nil), `*default-quiescent-transformation-max*` (1024) | Caps for the transform engine; see the transform section. |

## Group: length and shape

| Function | Purpose |
|---|---|
| `length<`, `length<=`, `length=`, `length>`, `length>=` | Compare list length to N **without traversing the whole list**. Stops once the verdict is known. Each takes an optional `count-dotted-list?` flag deciding whether `(1 2 . 3)` counts as length 2 or 3. |
| `greater-length-p`, `greater-or-same-length-p`, `same-length-p` | Pairwise length comparisons that walk both lists in parallel and stop early. |
| `proper-list-p`, `dotted-list-p`, `non-dotted-list-p` | Shape predicates. `proper-list-p` is `(consp obj)` plus `(null (cdr (last obj)))`. |
| `dotted-length cons` | Number of cells, counting the dotted final tail as one extra. |
| `singleton?`, `doubleton?`, `triple?` | Exact-length-1/2/3 tests, faster than `(= (length …) N)`. |
| `alist-p object` | Trivially `(listp object)` — an empty list and a list of conses are both alists in Cyc's vocabulary. |

The length-N comparators are heavily used: any code that asks "are there at least 3 things in this list?" does it via `length>= list 3`, not `(>= (length list) 3)`. The motivation is that Cyc operates on lists that might be long-but-mostly-equivalent (e.g. a 10000-entry interning table), and full length traversals were a profiled hotspot.

The supporting macro `scan-list-cells-with-index` is a tiny `labels`-based driver for cell-by-cell iteration with three exits (`:cons`, `:end`, `:dotted`). It powers `length<`, `length=`, `dotted-length`, and `flatten`.

## Group: cons and cell mutation

| Function | Purpose |
|---|---|
| `recons car cdr cons` | Allocate a new cons only if the new car/cdr differ from the existing ones (preserves sharing). |
| `ncons car cdr cons` | Destructively `rplaca`+`rplacd` the cell. |
| `flip-cons cons` | Swap car and cdr. |
| `flip-alist alist` | `mapcar` of `flip-cons` over an alist. |
| `nadd-to-end item list` | Destructively append a single item; returns the modified list. |
| `nreplace-nth n new list` / `replace-nth n new list` | Destructive / non-destructive Nth-element replacement. |

`recons` and `ncons` are the SubL idiom for "rebuild this cell only if needed" — they enable fixpoint iterations to skip allocation when a tree-transform produces an identical result. They're hot-path-critical in canonicalization.

## Group: search and selection

| Function | Purpose |
|---|---|
| `member-eq?`, `member-equal` | `(member item list :test #'eq/equal)`. |
| `last1 list` | `(last list)` with an explicit comment that they're equivalent. |
| `extremal list test &optional key` | First item maximizing `test`. |
| `parameterized-median list sort-pred` | Median element after sorting; picks the larger when even-length. |
| `safe-= o1 o2` | `=` that returns NIL for non-numbers instead of erroring. |
| `position-< item1 item2 guide-seq &optional test key` | T iff `item1` precedes `item2` in `guide-seq` (with off-guide items considered last). |
| `sort-via-position seq guide-seq …`, `stable-sort-via-position` | Sort `seq` by position in `guide-seq`. Used to project an arbitrary list back into a canonical order. |
| `sort-via-position-earlier`, `*sort-via-position-guide*`, `*sort-via-position-test*` | Helper plus dynamic-var pair binding the sort comparator. |

## Group: filtering and partitioning

| Function | Purpose |
|---|---|
| `partition-list list func` | Two-value return: items passing `func`, items failing. |
| `delete-first obj sequence &optional test` | `delete` with `:count 1`. |
| `find-all-if-not test seq &optional key` | **`missing-larkc 4774`** — original would return all items failing `test`. CL has no direct primitive (`(remove-if test ...)` reverses the polarity but allocates). |
| `delete-subsumed-items list test &optional key` | **`missing-larkc 9081`** — drops items dominated by another under `test`. Used by inference to prune subsumed proofs. |

`find-all-if-not` callers expect what `(remove-if test seq :key key)` would produce; `delete-subsumed-items` callers expect a transitively-reduced list under a partial order.

## Group: set / multiset operations

| Function | Purpose |
|---|---|
| `proper-subsetp list1 list2 &optional test key` | Strict subset (declared inline). |
| `sets-equal? set1 set2 &optional test` | Mutual subset. |
| `multisets-equal? set1 set2 &optional test` | Same length plus per-item count match plus set equality. |
| `fast-subset? list1 list2 &optional test` | Switches to hashtable above `*magic-hashing-cutoff*`. |
| `fast-sets-equal? s1 s2 &optional test` | Two-way `fast-subset?`. |
| `ordered-union set1 set2 &optional test key` | `union` preserving input order. |
| `ordered-set-difference list1 list2 &optional test key` | `set-difference` preserving input order. |
| `fast-set-difference list1 list2 &optional test` | Hashtable fast path above the cutoff. |
| `mapunion`, `mapnunion` | `(union (apply-fn-to-each-elt))` — maps a function returning lists, unions all results. |
| `nmapcar function list` | Destructive `mapcar`. |
| `mapappend function list` | `mapcan`, basically. |
| `mapcar-product function l1 l2` | Cartesian product as a flat list. |
| `duplicates? list &optional test key`, `duplicates list …` | Any-duplicates predicate / extract-duplicates. |
| `list-to-hashset list &optional test` | Build a hashtable mapping each element to T. |

The `fast-*` family is the file's signature design choice: the same operation in two implementations, dispatched by length. Below `*magic-hashing-cutoff*` the O(N²) member-walk is faster (no hashtable allocation); above, the O(N) hashtable wins. The cutoff is heuristic and unprofiled — see the TODO at the top.

`list-to-hashset` is exposed because `fast-subset?` and `fast-set-difference` both build the same set-of-keys structure, and inference-side callers want to reuse the constructed table across multiple subset queries.

## Group: deduplication

| Function | Purpose |
|---|---|
| `fast-delete-duplicates sequence &optional test key hashtable start end` | `delete-duplicates` with hashtable fast path; can reuse a passed-in hashtable. |
| `remove-duplicate-forts forts` / `delete-duplicate-forts forts` | Specialized to FORTs (uses `eq`). |
| `delete-duplciates-sorted sorted-list &optional test` | Linear-pass dedup assuming sorted input (similar items consecutive). The `delete-duplciates` typo in the function name is preserved from SubL. |

## Group: alist helpers

| Function | Purpose |
|---|---|
| `alist-lookup alist key &optional test default` | `(values value found?)`. |
| `alist-lookup-without-values …` | Single-value variant. |
| `alist-has-key? alist key &optional test` | Predicate. |
| `alist-enter alist key value &optional test` | Update or insert; returns `(values new-alist found?)`. |
| `alist-enter-without-values …` | Single-value variant. |
| `alist-delete alist key &optional test` | Remove an entry. |
| `alist-push alist key value &optional test` | Add value to a list bucket at key. |
| `alist-keys alist`, `alist-values alist` | `(mapcar #'car alist)`, `(mapcar #'cdr alist)`. |
| `alist-optimize alist predicate` | Stable-sort the alist by `predicate` over keys. |
| `alist-to-hash-table alist &optional test` | Materialize as a hashtable. |
| `alist-to-reverse-hash-table alist &optional test` | Same but value→key. |

The `…-without-values` variants exist because some callers don't want to pay the `multiple-value-bind` cost. SubL had cheap multi-value returns in some contexts and not others.

## Group: plist helpers

| Function | Purpose |
|---|---|
| `filter-plist plist pred` | Subset of plist keys passing `pred`. |
| `nmerge-plist plist-a plist-b` | Destructively overlay B onto A. |
| `merge-plist plist-a plist-b` | Non-destructive variant via `copy-list`. |

`do-plist` (the iteration macro) is defined in `subl-promotions.lisp` or `subl-macros.lisp`, not here.

## Group: number-list construction

| Function | Purpose |
|---|---|
| `num-list num &optional start` | Cached integer-range list `[start, start+num)`. The cached list is verified each call — if mutated, falls into a `missing-larkc 9349` branch instead of repopulating. |
| `new-num-list num &optional start` | Uncached version (always allocates). |
| `verify-num-list num-list length start` | Check that a candidate cache entry is a valid range. |
| `num-list-cached num start` | Internal `defun-cached` underlying `num-list`. |
| `numlist length &optional start` | Inline alias for `num-list`. |

The cache exists because Cyc inference iterates over `(num-list n)` for the same N many times during a single query (`(0 1 … n-1)` for arity loops), and the original SubL profiler showed the allocation matters. Modern hardware and GCs probably make this negligible — the `missing-larkc 9349` repopulation branch suggests the original logic for cache repair was stripped.

## Group: tree operations

| Function | Purpose |
|---|---|
| `flatten tree` | Non-recursive (stack-based) flatten of all non-NIL atoms. |
| `tree-find item object &optional test key` | Two-value: first sub-object satisfying test, plus found-flag. |
| `simple-tree-find?`, `simple-tree-find-via-equal?` | Specialized `eq` / `equal` predicate-only variants. |
| `tree-find-any items tree &optional test key` | Any of `items` found anywhere in `tree`. |
| `tree-find-if test object &optional key` | First sub-object satisfying `test`. |
| `cons-tree-find-if` | Obsolete alias for `tree-find-if`. |
| `tree-count-if test object &optional key` | Count satisfying nodes. |
| `tree-gather object predicate &optional test key subs-too?` | Collect all satisfying nodes. With `subs-too?` t (default), descends into a satisfying sub-tree's children too; with NIL, stops at the first match per branch. |
| `tree-funcall-if test fn object &optional key` | Side-effecting: call `fn` on each satisfying sub-object. |

`flatten` is implemented iteratively with an explicit stack to avoid blowing CL's call stack on deep KB structures. The TODO inside notes the one-half consing improvement vs. a naive cons-pushing version.

`tree-gather`'s `subs-too?` flag is the substantive option: when T, every match's children are also walked; when NIL, the search backtracks once it finds a match. Both modes have callers in canonicalization.

## Group: quoting and self-evaluation

| Function | Purpose |
|---|---|
| `self-evaluating-form object` | T iff `(eval object) ≡ object`. Atoms, NIL, T, keywords, and non-symbols. |
| `quotify object` | Returns `object` if self-evaluating, else `(list 'quote object)`. |
| `only-one list` | Returns the singleton element, errors otherwise. |

`self-evaluating-form` is used by code that builds Cyc forms intended for later evaluation in a Cyc-API or `eval-in-api` context — it's deliberately not identical to CL's `(constantp object)` because the predicate runs over CycL values, not Lisp values.

## Group: combinatorics

| Function | Purpose |
|---|---|
| `permute-list elements &optional test` | All distinct ordered permutations. Specializes for length < 5. |
| `permute-list-int elements &optional test` | All permutations, no duplicate handling. |
| `all-permutations n` | All permutations of `[0, n)`. |
| `permute list permutation` | Apply a positional permutation to a list. |
| `cartesian-product l &optional fun start test` | Cartesian product of a list of lists. The `test` branch is `missing-larkc 9053`. |
| `cartesian-helper a b fun` | Two-list Cartesian helper. |

`cartesian-product` produces an N-deep result whose elements are built by `fun` (default `cons`). It's used by inference to enumerate combined-bindings vectors over multiple variables.

## Group: insertion into sorted lists

| Function | Purpose |
|---|---|
| `splice-into-sorted-list object sorted-list predicate &optional key` | Destructively insert `object` so the list remains sorted under `predicate`. |
| `list-of-type-p pred object` | T iff `object` is a non-dotted list whose every element satisfies `pred`. |

## Group: combinator helpers

| Function | Purpose |
|---|---|
| `any-in-list predicate list &optional key` | `csome`-based; specialized for `key = identity`. |
| `every-in-list predicate list &optional key` | Same shape. |
| `first-n n list` | `(subseq list 0 n)`. |

`any-in-list` and `every-in-list` exist because SubL's `csome` had different short-circuit semantics than CL `some` / `every` — the optimization is the inlined `key = identity` fast path.

## transform-list-utilities.lisp — fixpoint tree rewriting

A separate file because the transform engine is conceptually distinct: instead of a one-shot map over a tree, `transform` and friends **iterate the rewrite to fixpoint**. The function caller passes a predicate `pred` and a transform `transform`; on each pass, every sub-object satisfying `pred` is replaced by `(transform object)`, recursing into the result, until no further change occurs.

| Function | Purpose |
|---|---|
| `transform object pred transform &optional key` | Non-destructive — copies the tree first, then `ntransform`s. |
| `ntransform object pred transform &optional key recursion-limit transformation-max` | Destructive, with recursion and transformation caps. Defaults: 212-deep recursion limit, no transformation max. |
| `ntransform-recursive` | Inner loop. Iterates down CDR, recurses on CAR. When `recursion-level` hits `recursion-limit`, falls back to an iterative algorithm — body is `missing-larkc 7700`. |
| `ntransform-perform-transform object pred transform &optional key` | One step of "apply transform until pred no longer holds." Has identity-key and key-calling variants; key-calling variant has `missing-larkc 7716`/`7717` for the per-step `funcall key …`. |
| `quiescent-transform`, `quiescent-ntransform` | Like `transform` but the loop terminates when applying `quiescence` (default `equal`) to consecutive results returns T, instead of when `pred` returns NIL. Allows transforms that fluctuate but converge. |
| `shy-quiescent-ntransform-recursive`, `shy-ntransform-perform-quiescent-transform` | Inner loops with a transformation count throttle that throws `:transformation-limit-exceeded` when exceeded. The "shy" prefix means "stops after a configured number of transformations." Four code paths inside, dispatching on whether `key` is identity and whether `quiescence` is `equal`. |
| `transform-pred-funcall pred object`, `transform-transform-funcall transform object` | Trampoline through `possibly-cyc-api-funcall` so the predicate or transform can be a Cyc-API symbol. |

### Why the engine has caps

`recursion-limit` (default 212) bounds CL stack depth before a fall-through to an iterative implementation. `transformation-max` bounds the number of *rewrites*, regardless of recursion depth — used by quiescent-transform to detect non-converging rules. `*default-quiescent-transformation-max*` of 1024 reflects "if the rule hasn't settled after 1024 rewrites, it's almost certainly oscillating."

The four-way dispatch in `shy-ntransform-perform-quiescent-transform` (key=identity vs not, quiescence=equal vs not) is a hand-unrolled specialisation: each branch is structurally identical but inlines or skips the corresponding funcall. SubL's compiler would hoist the dispatch; CL's may or may not.

The recursive/iterative split (`recursion-level >= recursion-limit` falls into `missing-larkc 7700` / `7715`) is a port-side gap: Cyc's full implementation has a manual stack-based fallback for very deep KB formulas; the LarKC drop only ships the recursive case. Any consumer that exceeds the recursion limit on a real KB will fail.

### What `transform` is for

Three categories of caller, all in canonicalization or inference:

- **EL ↔ HL term substitution.** `narts-high.lisp` line 98 rewrites every NART in a formula to its EL form via `(transform object #'nart-p #'nart-el-formula)`. `unification.lisp` line 340 rewrites every base-variable to its non-base version. `fi.lisp` line 829 rewrites assertions to their FI formulas.
- **Variable normalization.** `inference/harness/inference-czer.lisp` line 447 rewrites every non-fixed variable to a `variable-token` for canonical comparison. `at-var-types.lisp` performs similar arg-type-positional rewrites.
- **Formula simplification.** `simplifier.lisp` line 575 rewrites nested-collection-subset expressions until stable. `formula-pattern-match.lisp` and `pattern-match.lisp` use `transform` to apply pattern rewrites uniformly.

`iteration.lisp` uses `transform` for an unrelated purpose — building an iterator that maps `#'identity` over its input — which is essentially a `(copy-tree)`. That's a one-off; the substantive uses are the tree-rewrite ones.

## What uses these utilities

Roughly **eighty files** across the codebase reach into list-utilities. Categorised by function:

- **Inference engine.** ~25 files — every `inference/harness/` file uses some combination of `length=`, `partition-list`, `tree-find`, `extremal`, `fast-set-difference`. The transform engine is hot in canonicalization (`czer-meta.lisp`, `inference-czer.lisp`).
- **KB indexing and mapping.** `kb-indexing.lisp`, `kb-mapping.lisp`, `kb-accessors.lisp`, `auxiliary-indexing.lisp` — set operations, alist helpers, `flatten`.
- **Canonicalization (czer).** `czer-graph.lisp`, `canon-tl.lisp`, `cycl-utilities.lisp`, `simplifier.lisp` — tree-search and rewrite.
- **Pattern matching and unification.** `pattern-match.lisp`, `formula-pattern-match.lisp`, `unification.lisp`, `bindings.lisp` — `transform` plus `tree-find`.
- **Test harness, reporting, KB content.** scattered alist and plist usage.
- **External translators.** `c-name-translation.lisp`, `java-name-translation.lisp`, `system-translation.lisp` — `tree-find`, `transform` for source-form rewriting.

Most callers use a small subset of the file's API: the length comparators, the alist helpers, `tree-find`, and one or two `fast-*` set ops. No single caller uses more than a dozen functions.

## Notes for a clean rewrite

### What CL / alexandria / serapeum already provides

Most of the file. Specifically:

- **Length comparisons.** Replace with `serapeum:length<`, `length>=`, `length=`. Direct match.
- **Proper / dotted list predicates.** `alexandria:proper-list-p`. Dotted is one line.
- **`singleton?` etc.** `serapeum:single?`, `length= list 2/3`. Drop the helpers.
- **Set operations.** CL has `union`, `intersection`, `set-difference`, `subsetp`. The order-preserving / fast / `n*` variants are case-by-case; `serapeum:assort` and `serapeum:partitions` cover some.
- **`partition-list`.** `serapeum:partition`.
- **`flatten`.** `alexandria:flatten` (recursive). The iterative version here is worth keeping if depth is a concern.
- **Alist helpers.** Mostly one-liners over `assoc`, `acons`, `mapcar #'car`. `serapeum:alist-to-hash-table` exists.
- **Plist helpers.** `alexandria:plist-alist`, `alexandria:alist-plist`. Filtering is one line.
- **Tree search/gather.** `serapeum:walk-tree`, custom for the rest.
- **`every-in-list` / `any-in-list`.** Use `every` / `some`. The `key = identity` specialization is something a modern compiler does for free.
- **`numlist`.** `alexandria:iota`.
- **Permutations and Cartesian product.** Off-the-shelf libraries (`alexandria:map-product`, plus combinatorics libraries).
- **Fast-set-* family.** Optional — if the input lists are small in practice (which they are for most Cyc consumers), the O(N²) primitives are fine.

### What to keep

A small set of operations are genuinely Cyc-flavored:

- **`recons` / `ncons`.** The "rebuild only on change" idiom enables transform-engine sharing. Keep it; rename if needed.
- **`transform` / `quiescent-transform`.** The fixpoint tree rewriter is non-trivial and heavily used. A clean rewrite should keep something equivalent — possibly reframed as a generic rewrite-rule applier with explicit termination conditions.
- **`tree-gather` with the `subs-too?` flag.** The alternative semantics (descend-after-match vs not) has both meaningful callers; CL libraries don't typically expose this distinction.
- **`splice-into-sorted-list`.** The destructive in-place insert at the right position is occasionally useful; CL doesn't ship it.
- **`make-valid-constant-name` adjacency.** Doesn't live here, but transformations between free-text and FORT names are Cyc-specific and worth a dedicated module.

### What to drop

- **`*magic-hashing-cutoff*` and the entire `fast-*` family in their current form.** The cutoff is unprofiled; on modern hardware the crossover point is different and probably lower. A clean rewrite either always uses hashtables (if N is unbounded) or always uses `member` (if N is bounded). Don't ship a heuristic.
- **`*remove-duplicates-…-table*`** scratch-hashtable pool. A modern GC handles short-lived hashtables fine; the locks add complexity for negligible benefit.
- **`num-list` cache.** Allocating a fresh `iota n` is cheap on modern Lisp. The cache + verification + `missing-larkc 9349` repair branch is more code than the operation it accelerates.
- **`…-without-values` variants.** A clean rewrite picks one calling convention. CL `multiple-value-bind` is cheap.
- **`f_-prefix` and SubL-style `?`-suffixed names.** Rename to CL-idiomatic spellings. `singleton?` → `singletonp`, `member-eq?` → `member-eq`. Or just delete them and use `member :test #'eq`.
- **`*sort-via-position-guide*` / `*sort-via-position-test*` / `*plistlist-sort-indicator*` / `*subseq-subst-recursive-answers*`.** Dynamic-var-passed comparators are a SubL idiom; CL closures handle the same use case cleanly.

### Notes specific to the transform engine

- **The recursion/iterative split is a load-bearing design.** Real KB formulas can be deep. A clean rewrite must either preserve the explicit stack fallback (currently `missing-larkc 7700` / `7715`) or bound formula depth.
- **The four-way specialization in `shy-ntransform-perform-quiescent-transform` should disappear.** CL compilers can hoist branch tests on closures. If they can't, code-generate the specializations rather than write them by hand.
- **The `:transformation-limit-exceeded` throw is a control-flow channel.** A clean rewrite should signal a condition instead and let callers handle it via `restart-case` — much easier to compose with the rest of CL.
- **The `transform-pred-funcall` / `transform-transform-funcall` indirection through `possibly-cyc-api-funcall` exists so Cyc-API symbols can stand in for functions.** Whether to preserve this depends on whether the rewrite keeps the Cyc-API funcall protocol.
