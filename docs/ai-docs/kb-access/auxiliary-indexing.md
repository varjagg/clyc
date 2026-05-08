# Auxiliary indexing, simple-index matchers, virtual indexing

This trio of files covers the parts of the KB indexing layer that don't fit cleanly into the per-term role indexing covered in [kb-indexing.md](kb-indexing.md):

- **Auxiliary indexing** (`auxiliary-indexing.lisp`) — the *unbound rule index*, plus a small framework for declaring sentinel "indices" that are not attached to any KB term. The unbound-rule-index is where rules whose predicate is a *variable* are parked, since they have no term to index under.
- **Simple-index matchers** (`simple-indexing.lisp`) — the `matches-<role>-index` predicate family (and their `simple-key-…` accumulator helpers). These are how the simple (linear-scan) form of a term's index decides which assertions belong to which role at lookup time. Plus the simple↔complex mode-toggle machinery and overlap heuristics shared across the indexing layer.
- **Virtual indexing** (`virtual-indexing.lisp`) — the *overlap method* for finding gafs that mention multiple terms. Lets the engine intersect the indexes of several terms to find their intersection set of co-mentioning assertions, when no single term's role bucket is small enough to drive the lookup.

These three are conceptually distinct but related — they all extend the basic per-term/per-role indexing with shapes that handle "what if there's no single term to index by?"

## When do these systems engage?

Auxiliary indexing engages when:
1. **A rule with an unbound predicate (variable) is asserted.** The canonicalizer leaves a literal `(?P x y)` in a rule it cannot otherwise index. `add-rule-indices` ([`kb-indexing.lisp:825`](../../../larkc-cycl/kb-indexing.lisp#L825)) calls `add-unbound-rule-indices` ([`auxiliary-indexing.lisp:139`](../../../larkc-cycl/auxiliary-indexing.lisp#L139)), which checks `some-unbound-predicate-literal cnf sense` for each sense and registers the assertion under `:unbound-rule-index-pos` or `:unbound-rule-index-neg`.
2. **An inference module is searching for unbound-predicate rules.** SBHL and certain meta-rule modules iterate the unbound-rule-index when looking for rules with variable predicates, since those don't appear in any per-term predicate-rule bucket.
3. **The auxiliary index is being dumped or loaded.** `dump-auxiliary-indices` (missing-larkc) writes the registered auxiliary indices over CFASL; `load-auxiliary-indices` reads them back.

Simple-index matchers engage on every lookup of a term whose index is currently in simple form (count below the toggle threshold — see kb-indexing.md). The matcher is invoked once per assertion in the term's flat list to filter to the role-relevant ones.

Virtual indexing engages when `lookup-should-use-index-overlap?` returns t — typically when no single-term role bucket is small enough but the formula has multiple bound terms whose indexes can be intersected to a smaller set.

## Auxiliary indexing

### Auxiliary-index registry

`*auxiliary-indices*` is a list of registered auxiliary-index keywords. Each entry is a symbol (a *sentinel* like `:unbound-rule-index`) that has properties on its symbol-plist:

```
keyword   ─property: :index-name─→  string ("Unbound Rule Index")
keyword   ─property: :index─────→  the actual subindex datastructure
```

Operations:

| Function | Effect |
|---|---|
| `declare-auxiliary-index aux-index name` | `pushnew aux-index *auxiliary-indices*; (put aux-index :index-name name)` |
| `auxiliary-index-p object` | `(member? object *auxiliary-indices*)` |
| `get-auxiliary-index aux-index` | `(get aux-index :index nil)` — fetch the subindex |
| `reset-auxiliary-index aux-index new-index` | put-or-remprop `:index` |
| `auxiliary-index-name aux-index` | (active declareFunction, no body) |
| `clear-auxiliary-index aux-index` | (active declareFunction, no body) |

The clean rewrite has one auxiliary-index registered: `:unbound-rule-index` ("Unbound Rule Index"), via `(toplevel (declare-auxiliary-index :unbound-rule-index "Unbound Rule Index"))`.

The reason this exists as a sentinel-keyed registry rather than just a global variable: every place that takes a `term` argument and queries its index can also take an auxiliary-index keyword, dispatching via `(auxiliary-index-p term)`. So `term-index`, `reset-term-index`, `get-subindex` etc. transparently work for both real terms and auxiliary indices. See `term-index` ([`kb-indexing-datastructures.lisp:114`](../../../larkc-cycl/kb-indexing-datastructures.lisp#L114)) — its last `cond` arm is `((auxiliary-index-p term) (get-auxiliary-index term))`.

### Unbound rule index

Rules whose CNF contains a literal `(?P x y …)` with a variable in the predicate position have nothing to index under per-term — variables aren't indexed terms. The unbound-rule-index is the catch-bucket for these.

`add-unbound-rule-indices assertion`:

1. Reads `cnf`, `mt`, `direction` from the assertion.
2. For each sense in `*valid-senses*` (`:pos`, `:neg`), calls `some-unbound-predicate-literal cnf sense` — finds any pos/neg literal whose predicate is a variable.
3. If found, calls `missing-larkc 30772` (the actual indexing add). The clean rewrite recovers this by calling `term-add-indexing-leaf (unbound-rule-index) (list sense mt direction) assertion` — registering the assertion under the auxiliary-index sentinel at the per-sense, per-MT, per-direction path.

`rem-unbound-rule-indices` is the symmetric remove (`missing-larkc 30776`).

`some-unbound-predicate-literal clause sense`:

```lisp
(defun some-unbound-predicate-literal (clause sense)
  (let ((literals (if (eq sense :pos)
                      (pos-lits clause)
                      (neg-lits clause))))
    (find-if #'unbound-predicate-literal literals)))

(defun unbound-predicate-literal (literal)
  (and (consp literal)
       (variable-p (literal-predicate literal))))
```

### Index declarations

Both unbound-rule indices have explicit `declare-index` registrations at the bottom of the file. These are the only `declare-index` calls visible in the port (per [kb-indexing.md](kb-indexing.md), the bulk of the per-role declarations were stripped). Each entry:

```
:unbound-rule-index-pos   :TOP-LEVEL-KEY :POS
                          :DOMAIN     {term, AUXILIARY-INDEX-P}
                          :KEYS       (sense SENSE-P EQ)
                                      (mt HLMT-P EQUAL — MT?:T, RELEVANT-MT? as relevance)
                                      (direction DIRECTION-P EQ)
                          :RANGE      rule (RULE-ASSERTION?, "in mt MT with direction DIRECTION,
                                            contains a pos-lit with variable predicate")

:unbound-rule-index-neg   :TOP-LEVEL-KEY :NEG
                          (mirror of pos, with neg-lit)
```

The per-key plist (validity test, equal test, MT relevance flag) is what `index-equality-test-for-keys` ([`kb-indexing-declarations.lisp:73`](../../../larkc-cycl/kb-indexing-declarations.lisp#L73)) reads to decide each level's hash test. The `:RELEVANCE-TEST` field hints at clean-rewrite: every per-level key could carry a relevance test, generalizing the MT-relevance pattern.

### Lifecycle

The unbound-rule-index has the same simple↔complex toggle as any other indexed entity — `simple-indexed-term-p (unbound-rule-index)` decides which path is taken. Mutation is via the standard `term-add-indexing-leaf` / `term-rem-indexing-leaf` going through `(auxiliary-index-p term)` dispatch.

CFASL serialization: `dump-unbound-rule-index` (missing-larkc) writes via the standard subindex serialization. `load-unbound-rule-index stream` reads with `cfasl-input` then `reset-auxiliary-index (unbound-rule-index) <result>`. Wrapped by `load-auxiliary-indices stream` which loads each registered auxiliary index in turn.

`reconstruct-auxiliary-indices` and `reconstruct-unbound-rule-indices` (both missing-larkc) are the rebuild paths — walk the assertion table and re-register every unbound-predicate rule.

## Simple-index matchers

A *matcher* `matches-<role>-index assertion term &optional <subkeys>` returns t iff the assertion belongs to `term`'s `<role>` bucket at the requested sub-keys. Used in two places:

1. **Simple-index lookup**: when the term's index is currently simple (a flat list), every count/key/get/lookup function in `kb-indexing.lisp` does a linear scan over the list calling the matcher per assertion. This is how role-keyed semantics are recovered without the per-role hash structure.
2. **Simple-index final-index-spec iterator**: `new-singleton-iterator (term :simple match-fn)` produces a final-index-spec that wraps the term's simple-index list with the matcher as a post-hoc filter. The final-index-iterator built from this spec walks the list and skips assertions where the matcher returns nil.

### Matchers per role

| Function | What it tests |
|---|---|
| `matches-gaf-arg-index ass term &opt arg pred mt` | gaf, term occurs in arg position(s), predicate matches, MT matches (`hlmt-equal`) |
| `matches-nart-arg-index ass term &opt arg func` | gaf with predicate `#$termOfUnit`, NAUT matches term/arg/func |
| `matches-predicate-extent-index ass term &opt mt` | gaf with predicate eq term, MT matches |
| `matches-function-extent-index ass term` | (`missing-larkc 30226` — gaf with `#$termOfUnit` predicate and term as functor of arg2) |
| `matches-predicate-rule-index ass pred &opt sense mt direction` | rule, MT/direction match, predicate appears in pos-lits or neg-lits |
| `matches-ist-predicate-rule-index ass pred &opt sense mt direction` | same shape but predicate is wrapped in `#$ist` |
| `matches-decontextualized-ist-predicate-rule-index ass pred &opt sense direction` | similar; *no MT match* (decontextualized) |
| `matches-isa-rule-index ass col &opt sense mt direction` | rule, MT/direction match, col is arg2 of a `#$isa` literal |
| `matches-quoted-isa-rule-index ass col &opt sense mt direction` | same with `#$quotedIsa` |
| `matches-genls-rule-index ass col &opt sense mt direction` | same with `#$genls` |
| `matches-genl-mt-rule-index ass mt &opt sense rule-mt direction` | same with `#$genlMt` |
| `matches-function-rule-index ass func &opt mt direction` | rule with `(not (#$termOfUnit ?x (FUNC . args)))` neg-lit |
| `matches-exception-rule-index ass rule &opt mt direction` | rule with `(#$abnormal ?x RULE)` pos-lit |
| `matches-pragma-rule-index ass rule &opt mt direction` | rule with `(#$meetsPragmaticRequirement ?x RULE)` pos-lit |
| `matches-other-index ass term` | term occurs in CNF or MT, but matches none of the specialized roles above |
| `mt-index-assertion-match-p ass mt` | MT of assertion matches (HLMT-equal) |

The `matches-other-index` predicate is the one that defines the `:other` catch-all: it passes iff the term occurs *and* every other role's matcher fails. It runs O(K) matchers per check (one per other role) — this is the cost of the catch-all.

### Simple-key accumulators

For each role with sub-keys, there's a `simple-key-<role>-index assertion accumulator term <subkeys>` that pushes the keys *the assertion would be filed under* onto an accumulator list. Used when the term's index is simple and the caller wants a list of next-level keys. Examples:

- `simple-key-gaf-arg-index assertion accum term arg pred` — if the assertion matches the gaf-arg-index for term/arg/pred, push the next level's key (predicate name if `arg` is set but `pred` isn't, MT if both are set, or the position itself if no `arg`).
- `simple-key-<other-role>-index` — many of these are missing-larkc bodies.

### Simple↔complex mode toggling

(Also documented in [kb-indexing.md](kb-indexing.md), repeated here for completeness because the implementation lives in this file.)

```
*index-convert-threshold*           20
*index-convert-range*                4
*index-convert-complex-threshold*   22
*index-convert-simple-threshold*    18
```

Each mutating index operation must run inside a `noting-terms-to-toggle-indexing-mode` body. The body sets `*within-noting-terms-to-toggle-indexing-mode* = t` and `*terms-to-toggle-indexing-mode* = nil`. Inside, every `term-add-indexing-leaf` / `term-rem-indexing-leaf` calls `possibly-toggle-term-index-mode term` which, if the term's count crosses the threshold, `pushnew`s the term into the deferred list. When the body exits, every queued term is `toggle-term-index-mode`'d (i.e. converted in place to the other form).

`convert-to-complex-index term` ([`simple-indexing.lisp:387`](../../../larkc-cycl/simple-indexing.lisp#L387)):
1. Snapshot the term's flat assertion list (reverse to preserve insert order).
2. Call `initialize-term-complex-index term` to install an empty top-level intermediate-index.
3. Re-add each assertion's indices via `add-assertion-indices assertion term` — this re-runs the full `add-gaf-indices` / `add-rule-indices` pipeline restricted to `term`, building up the complex form.

`convert-to-simple-index term` (the body is mostly a similar walk that gathers all role-keyed leaves into one list, missing-larkc for some sub-roles).

The value of the design: bulk add/remove operations (many-leaf updates to one term) batch their toggle decisions, so the term flips at most once per batch. Without batching, repeated insertions across the threshold would re-encode a term every time.

### `add-simple-index` / `rem-simple-index`

```lisp
(defun add-simple-index (term assertion)
  (let* ((old-index (simple-term-assertion-list term))
         (new-index (adjoin assertion old-index)))
    (when (not (eq old-index new-index))
      (reset-term-simple-index term new-index)
      (possibly-toggle-term-index-mode term))))
```

Eq-comparison adjoin so duplicates are dropped. Mode-toggle gets a chance after every mutation, but only fires inside a `noting-terms-to-toggle-indexing-mode` body.

## Virtual indexing — the overlap method

When a query like `(#$differentObjects ?x ?y)` has *two* indexed terms but every role bucket is large, no single index gives a good driver for the search. The overlap method computes the intersection of the per-term assertion sets directly — for terms `[t1 t2 t3]`, find every assertion whose term-set includes all three.

### Tunable parameters

| Variable | Default | Meaning |
|---|---|---|
| `*index-overlap-enabled?*` | `t` | Master switch |
| `*lookup-overlap-watermark*` | `50` | Below this best-other-index cost, overlap isn't worth it |
| `*overlap-index-expense-multiplier*` | `7` | Overlap is ~7× more expensive per assertion than direct lookup (multiple passes, intersection consing). Empirically determined Aug 2005. |

### `lookup-should-use-index-overlap? formula &optional best-count`

Decides whether the planner should pick the overlap method:

- nil if overlap is disabled.
- nil if `best-count < *lookup-overlap-watermark*` (cheap-enough direct lookup exists).
- nil if `too-few-terms-for-index-overlap? formula` — need at least 2 indexable terms.
- `missing-larkc 6920` if `best-count` is provided and all MTs are relevant — the path takes a different cost shape.
- t otherwise.

### `too-few-terms-for-index-overlap? formula`

True if the formula has at most one indexable arg (counting via `good-term-for-overlap-index-p`, which accepts `indexed-term-p` plus non-cons subl-atomic terms — i.e. constants, narts, assertions, strings, numbers).

### `good-term-for-overlap-index-p object`

```lisp
(or (indexed-term-p object)           ; fort, assertion, unrepresented
    (and (not (consp object))
         (subl-atomic-term-p object)))
```

A term is overlap-eligible if it's a regular indexed term *or* an atomic SubL value. Excludes formulas (consp) — overlap can't intersect over compound subforms.

### Cyc API: `assertions-mentioning-terms`

Registered: `(assertions-mentioning-terms term-list &optional include-meta-assertions?)` returns the list of assertions mentioning *every* term in `term-list`. The body is missing-larkc — this is essentially the public face of the overlap method.

### Why missing-larkc is significant

Most of the overlap implementation is missing in the port:
- `lookup-index-for-overlap` (and `5149`, `12767`, `12755`, `12768`, `5114`, `5115`)
- `do-overlap-index` macro body
- `do-gli-via-overlap` sub-macro body
- `assertions-mentioning-terms` body

The clean rewrite must implement these. The shape: take the term-list, find the term with the smallest role bucket (driver), iterate it, for each candidate assertion check that all other terms appear in it. The `*overlap-index-expense-multiplier*` is meaningful only because the implementation conses up intersection sets — a hash-set-based intersection would be much faster and the multiplier would shrink. A modern rewrite uses a graph-style edge index `(assertion, term)` and intersects via set operations.

## Public API surface

```
;; Auxiliary index framework
(declare-auxiliary-index aux-index name)
(auxiliary-index-p object)
(get-auxiliary-index aux-index)
(reset-auxiliary-index aux-index new-index)
(auxiliary-index-name aux-index)            ; missing-larkc body
(clear-auxiliary-index aux-index)            ; missing-larkc body
(auxiliary-indices)                          ; missing-larkc body
(*auxiliary-indices*)

;; Unbound rule index
(unbound-rule-index)                         ; constant: :unbound-rule-index
(num-unbound-rule-index &optional sense mt direction)
(relevant-num-unbound-rule-index &optional sense)
(relevant-key-unbound-rule-index &optional sense)   ; missing-larkc body
(key-unbound-rule-index &optional sense mt)
(get-unbound-rule-subindex sense &optional mt direction)
(add-unbound-rule-index assertion sense mt direction)   ; missing-larkc body
(rem-unbound-rule-index assertion sense mt direction)   ; missing-larkc body
(map-unbound-rule-index fn sense &optional mt)          ; missing-larkc body
(map-unbound-rule-mt-index fn sense mt &optional dir)   ; missing-larkc body
(add-unbound-rule-indices assertion)
(rem-unbound-rule-indices assertion)
(unbound-predicate-literal literal)
(some-unbound-predicate-literal clause sense)
(unbound-predicate-rule-p rule)              ; missing-larkc body
(unbound-rule-assertion-p assertion)         ; missing-larkc body
(clear-unbound-rule-index)                   ; missing-larkc body
(reconstruct-auxiliary-indices)              ; missing-larkc body
(reconstruct-unbound-rule-indices)           ; missing-larkc body
(dump-auxiliary-indices stream)              ; missing-larkc body
(load-auxiliary-indices stream)
(dump-unbound-rule-index stream)             ; missing-larkc body
(load-unbound-rule-index stream)

;; Simple-index matchers (one per role; full list above)
(matches-<role>-index assertion term &optional <subkeys>)
(simple-key-<role>-index assertion accum term &optional <subkeys>)

;; Mode toggle
(noting-terms-to-toggle-indexing-mode body)
(possibly-toggle-term-index-mode term)
(toggle-term-index-mode term)
(convert-to-complex-index term)
(convert-to-simple-index term)
(*index-convert-threshold*) (*index-convert-range*)
(*index-convert-complex-threshold*) (*index-convert-simple-threshold*)

;; Simple-index add/remove
(add-simple-index term assertion)
(rem-simple-index term assertion)

;; Virtual / overlap
(*index-overlap-enabled?*)
(*lookup-overlap-watermark*)
(*overlap-index-expense-multiplier*)
(good-term-for-overlap-index-p obj)
(too-few-terms-for-index-overlap? formula)
(lookup-should-use-index-overlap? formula &optional best-count)
(assertions-mentioning-terms term-list &optional include-meta?)   ; Cyc API; missing-larkc body
```

## Consumers

| Consumer | What it uses |
|---|---|
| **assertion creation/removal** (`assertion-manager.lisp`, `assertions-low.lisp`) | `add-unbound-rule-indices` / `rem-unbound-rule-indices` (called from `add-rule-indices` / `remove-rule-indices`) |
| **inference modules** | `do-unbound-predicate-rule-index` ([`kb-mapping-macros.lisp:1232`](../../../larkc-cycl/kb-mapping-macros.lisp#L1232)) for meta-rule and SBHL paths |
| **kb-indexing layer** (`kb-indexing.lisp`) | every `num/key/<role>` function checks `simple-indexed-term-p` and falls back to scanning the simple-index assertion list with `matches-<role>-index` |
| **kb-mapping iteration macros** | `(term :simple match-fn)` final-index-spec uses the matcher for filtering |
| **lookup planner** (`kb-indexing.lisp` `best-gaf-lookup-index`) | `lookup-should-use-index-overlap?`, `too-few-terms-for-index-overlap?`, `good-term-for-overlap-index-p` |
| **dumper / loader** | `load-auxiliary-indices`, `load-unbound-rule-index` for KB load; corresponding dump functions are missing |
| **Cyc API** | `assertions-mentioning-terms` |

## Notes for a clean rewrite

- **The auxiliary-index sentinel pattern is a fragile workaround.** It uses keyword-symbol property lists (`(get aux-index :index)`) to attach data to a sentinel. A clean design either makes auxiliary "containers" first-class objects with their own struct, or recognizes that the unbound-rule-index is just a registry of all rule assertions whose CNF has at least one variable predicate, and stores it explicitly as a hash from (sense, mt, direction) to set, with no relation to the term-indexing layer.
- **Unbound predicates should probably not be a separate index at all.** A clean rewrite could (a) require all rule predicates to be FORTs at canonicalization time (rejecting unbound-predicate rules outright — Cyc has very few of these), or (b) store them with the unbound predicate position recorded, indexed by every constraint that *does* exist (sense, MT, direction) without inventing a sentinel "term."
- **The `matches-<role>-index` family is a perfect duplicate of the role-key-extraction logic in `determine-gaf-indices` / `determine-rule-indices`.** When an assertion is added, the system computes which role(s) it belongs to. When the simple-index is queried, the system re-derives the same fact per scan. Cache the role-set on the assertion at canonicalization time.
- **The simple-index path is the source of significant complexity** — every per-role function in kb-indexing.lisp has a "simple-index" branch and a "complex-index" branch. Removing the simple/complex split (per kb-indexing.md note) eliminates ~60% of this file.
- **The overlap method is structurally important** — for sentences with 3+ bound terms it's often the only feasible plan — but the implementation is mostly missing-larkc. The clean rewrite must implement at least the simple intersection algorithm: pick the term with the smallest index, iterate it, filter by membership in the others. Modern hash-set intersection makes the `*overlap-index-expense-multiplier*` of 7 obsolete — measure on a modern KB and update.
- **`good-term-for-overlap-index-p` admits SubL atomic values** (numbers, strings, characters) but the `indexed-term-p` branch already handles unrepresented terms (which are exactly strings and numbers). The non-cons subl-atomic-term-p branch may be redundant; verify and simplify.
- **The `*overlap-index-expense-multiplier*` is a single global** — but expense relative to other methods varies with the size of the formula and the specificity of bound args. A more principled cost model (cardinality estimate × number of intersection passes) is in [cardinality-estimates.lisp](../../../larkc-cycl/cardinality-estimates.lisp); the planner should consult that rather than a fixed constant.
- **`too-few-terms-for-index-overlap?` rejects formulas with subformulas** but in real Cyc, formulas with subformulas are common — the rejection is a simplifying heuristic. A clean rewrite either lifts subformula terms into the overlap calculation or treats subformulas as opaque atoms with their own per-term index.
- **`reconstruct-*` paths are missing-larkc.** A clean rewrite must implement these; they're the rebuild-from-scratch path needed when the auxiliary index is lost or corrupted.
- **The pos/neg split in unbound-rule-index uses two separate `:TOP-LEVEL-KEY` declarations** but the actual storage is one auxiliary index keyed by sense at the first level. The two `declare-index` entries are documentation-shaped; the actual sense level is a regular subindex level. A clean rewrite consolidates this.
