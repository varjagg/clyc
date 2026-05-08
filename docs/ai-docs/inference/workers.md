# Workers (per inference-step execution)

Workers are the code that *executes* a tactic — taking a candidate `(hl-module, problem)` pairing and turning it into one or more problem-links and proofs, propagating them through the search graph, and feeding any resulting answers back to the inference. The strategist (see "Strategist & tacticians") *picks* which tactic to run; the workers *run* it.

There are eleven kinds of work step, each backed by its own file. They cluster into four families:

- **Content workers** produce content links, the leaves of the proof DAG. These are the workers that actually consult the KB or call HL modules to derive new facts.
  - Removal — a single literal, satisfied directly by an HL module
  - Transformation — a single literal, expanded by applying a rule
  - Residual transformation — leftover sub-clause from a transformation that shares variables with an open join-ordered link
  - Rewrite — a single literal, expanded by a syntactic rewrite rule
- **Structural workers** produce structural links — edges that decompose or recompose problems without consulting the KB.
  - Split — a single problem with no shared variables across literals → independent subproblems
  - Join-ordered — connected conjunction with one focal literal and a residual non-focal sub-clause
  - Join — connected conjunction split as a hash-join on shared variables
  - Union — disjunction (OR) of multiple sub-clauses → all of them
- **Restriction workers** apply a binding-set to narrow a problem before solving — the layer of indirection used to avoid duplicating the KB lookup work.
  - Restriction
- **The answer worker** is the link that connects the inference's root problem to the inference itself.
  - Answer

Plus the central dispatcher in `inference-worker.lisp` that decides which worker to call.

Source files (6951 lines total):
- `inference/harness/inference-worker.lisp` (2275) — central dispatch, common helpers
- `inference/harness/inference-worker-removal.lisp` (972) — removal links and tactics
- `inference/harness/inference-worker-transformation.lisp` (1015) — transformation links
- `inference/harness/inference-worker-residual-transformation.lisp` (136) — residual-transformation links
- `inference/harness/inference-worker-rewrite.lisp` (123) — rewrite links
- `inference/harness/inference-worker-split.lisp` (528) — split links
- `inference/harness/inference-worker-join-ordered.lisp` (1042) — join-ordered links
- `inference/harness/inference-worker-join.lisp` (442) — join links (hash join)
- `inference/harness/inference-worker-union.lisp` (87) — union links
- `inference/harness/inference-worker-restriction.lisp` (240) — restriction links
- `inference/harness/inference-worker-answer.lisp` (91) — answer link

## What every worker does

The worker pattern is the same for all eleven types:

1. A function `<type>-tactic-p(tactic)` recognises tactics whose `tactic-type` is the worker's type.
2. A function `<type>-link-p(link)` recognises links of the worker's type.
3. A defstruct `<type>-link-data` holds the per-link data carried in the `data` slot of the generic `problem-link`.
4. `new-<type>-link(...)` and `new-<type>-link-int(...)` mint the link, initialise its data, attach it to the supporting and supported problems, and call `propagate-problem-link`.
5. `execute-<type>-tactic(tactic)` is the worker's entry point; it usually calls `<type>-tactic-link(tactic)` to find or create the link and then opens its supporting indices.
6. `bubble-up-proof-to-<type>-link(...)` is the proof-propagation function — when a supporting problem produces a proof, this function combines it with sibling proofs into a new proof of the supported problem.

The two essential operations a worker implements are **link creation** and **proof bubbling**. Tactic execution is just "make sure the link exists, then mark its supporting positions as open." The actual answer flow goes upward as proofs bubble from leaves toward the root.

## When does a worker fire?

The strategist picks a tactic and calls `execute-tactic(tactic)` (in `inference-worker.lisp`):

```
execute-tactic(tactic):
  must (not (eq tactic *currently-executing-tactic*))   ; no recursion
  must (tactic-possible? tactic)
  within-tactic-execution(tactic):
    note-tactic-most-recent-executed(tactic)            ; debug crumb
    if single-literal-tactic-p(tactic):
      execute-literal-level-tactic(tactic)
    elif generalized-conjunctive-tactic-p(tactic):
      execute-multiple-literal-tactic(tactic)
    elif disjunctive-tactic-p(tactic):
      ...union dispatch...   (missing-larkc 35226 in port)
    else:
      error
    possibly-note-tactic-finished(tactic)
```

The single-literal vs. multiple-literal split is the first level of dispatch. Multi-clause queries (problems with disjunctive structure) fall to `execute-multiple-clause-tactic` (a missing-larkc in the port).

### Single-literal dispatch

`execute-literal-level-tactic(tactic)`:
```
let problem = tactic-problem(tactic)
let query   = problem-query(problem)
multiple-value-bind (mt asent sense) =
  mt-asent-sense-from-singleton-query(query)
within-single-literal-tactic-with-asent-and-mt((asent mt)):
  case tactic of:
    literal-level-removal-tactic-p:        execute-literal-level-removal-tactic
    literal-level-meta-removal-tactic-p:   missing-larkc 36226
    literal-level-transformation-tactic-p: execute-literal-level-transformation-tactic
    literal-level-rewrite-tactic-p:        missing-larkc 32958
```

The `*asent-of-currently-executing-tactic*` and `*mt-of-currently-executing-tactic*` parameters are bound here so deep code can find what literal it is working on without threading it through every call.

### Multi-literal dispatch

`execute-multiple-literal-tactic(tactic)`:
```
case tactic of:
  structural-tactic-p:
    case tactic of:
      split-tactic-p:        execute-split-tactic
      join-ordered-tactic-p: execute-join-ordered-tactic
      join-tactic-p:         execute-join-tactic
  meta-structural-tactic-p:
    case tactic of:
      meta-split-tactic-p:   tactic-in-progress-next  ; iterative meta-split
  conjunctive-removal-tactic-p:
                              missing-larkc 36225
```

The structural/meta-structural distinction: a *structural* tactic fires once and produces a finite set of subproblems; a *meta-structural* tactic is iterative — `tactic-in-progress-next` advances its progress iterator and the strategist will fire it again later. Meta-split tactics defer the decision of how to split a problem until more information is available.

## Tactic-type taxonomy

The set of predicates `inference-worker.lisp` provides:

| Predicate | Definition |
|---|---|
| `single-literal-tactic-p` | removal ∪ meta-removal ∪ transformation ∪ rewrite (each at literal-level) |
| `literal-level-tactic-p` | not conjunctive, not disjunctive |
| `connected-conjunction-tactic-p` | join-ordered ∪ join |
| `logical-conjunctive-tactic-p` | split ∪ connected-conjunction |
| `conjunctive-tactic-p` | logical-conjunctive ∪ conjunctive-removal |
| `meta-conjunctive-tactic-p` | meta-split |
| `generalized-conjunctive-tactic-p` | conjunctive ∪ meta-conjunctive |
| `disjunctive-tactic-p` | union ∪ disjunctive-assumption |
| `logical-tactic-p` | logical-conjunctive ∪ logical-disjunctive |
| `structural-tactic-p` | logical-tactic |
| `meta-structural-tactic-p` | meta-conjunctive |
| `generalized-structural-tactic-p` | structural ∪ meta-structural |
| `content-tactic-p` | generalized-removal ∪ transformation ∪ rewrite |
| `executable-strategem-p` | content ∪ meta-structural |
| `generalized-removal-tactic-p` | removal ∪ conjunctive-removal ∪ meta-removal |

Symmetrically for links:
| Predicate | Definition |
|---|---|
| `connected-conjunction-link-p` | join-ordered ∪ join |
| `conjunctive-link-p` | split ∪ connected-conjunction |
| `disjunctive-link-p` | union ∪ disjunctive-assumption |
| `logical-link-p` | conjunctive ∪ disjunctive |
| `content-link-p` | removal ∪ transformation ∪ residual-transformation ∪ rewrite |

These predicates are the vocabulary the strategist uses to filter and dispatch. They appear in `do-problem-tactics :type <generalized-tactic-type>` calls everywhere.

## Worker-by-worker

### Removal (`inference-worker-removal.lisp`)

A removal link fires an HL module against a single literal. Because the module produces results directly, the link has *no supporting problems* — its proof is "the HL module said so."

**Data:**
```lisp
(defstruct removal-link-data
  hl-module      ; which HL module produced the result
  bindings       ; the variable bindings the module returned
  supports)      ; the HL justification list
```

**Lifecycle:**
1. `new-removal-link(problem, hl-module, removal-bindings, supports)` — mints the link, attaches it to the problem as an argument-link, calls `propagate-problem-link` to push it forward
2. The link has no supporting-mapped-problems — it is a leaf. The proof is generated via `new-removal-proof`/`bubble-up-proof` directly on link creation.

**Execution path:**
- `determine-new-literal-removal-tactics(problem, asent, sense)` runs at problem examination time, walking applicable HL modules
- `literal-simple-removal-candidate-hl-modules(asent, sense)` returns all candidate modules from the registries (specific → generic → universal — see "Removal modules" doc)
- `update-applicable-hl-modules` does *exclusivity filtering*: a module with `:exclusive-func` may supplant other modules; a totally-exclusive module short-circuits the search
- `compute-tactic-specs-for-asent` produces `(hl-module, productivity, completeness)` triples
- For each spec, `new-removal-tactic(problem, hl-module, productivity, completeness)` mints the tactic with status `:possible`

**Module-call indirection.** HL modules' `:exclusive-func`, `:required-func`, and `:expand-func` are function-spec names; the worker dispatches via switch tables (`removal-module-exclusive-func-funcall`, `removal-module-required-func-funcall`, `removal-module-expand-func-funcall`) that map the symbolic name to a Lisp function. This is a port-time concession to the original SubL API — the dispatch table was needed because SubL allowed string-keyed function lookup. The clean rewrite should replace these tables with direct function references stored on the HL module.

**Conjunctive removal.** A separate path: `determine-new-conjunctive-removal-tactics(problem, dnf-clause)` for problems that benefit from solving the entire conjunction at once (e.g. `(and (isa ?X Cat) (isa ?X Animal))` with a module that knows both). Modules are sorted by priority (`conjunctive-pruning-module-p` first, then `simplification-module-p`, then everything else) so an exclusive simplification module does not trump an exclusive pruning module.

### Transformation (`inference-worker-transformation.lisp`)

A transformation link fires a *rule* against a single literal: the rule's consequent matches the literal, and the antecedent becomes a new subproblem. The proof of the supported problem requires the proof of the antecedent subproblem.

**Data:**
```lisp
(defstruct transformation-link-data
  hl-module
  bindings                      ; from supported-problem's vars to supporting-problem's vars
  supports                      ; rule-assertion plus more-supports
  non-explanatory-subquery)     ; for partially-explanatory rules
```

**Lifecycle:**
1. `add-tactic-to-determine-new-literal-transformation-tactics(problem, asent, sense, mt)` adds a *meta-transformation tactic*: a placeholder that, when fired, computes the actual transformation tactics. The placeholder is gated by `inference-backchain-forbidden-asent?` (forbidden assertions don't get transformation tactics).
2. When the meta-transformation tactic fires, it walks applicable transformation modules and creates one transformation tactic per applicable rule.
3. `new-transformation-link(supported-problem, supporting-mapped-problem, hl-module, transformation-bindings, rule-assertion, more-supports, non-explanatory-subquery)` mints the link, connects the supporting problem, calls `problem-link-open-all`, and propagates.

**The rule + module pair.** Transformation modules are different from removal modules: they don't have `:exclusive-func` or `:required-func`. Instead, the rule itself (a KB assertion) determines applicability. The HL module's role is to provide the matching algorithm. The tactic stores `(hl-module, rule-assertion)` pairs, and `transformation-link-tactic` looks one up by both keys.

**`with-problem-store-transformation-assumptions`.** A scoped binding macro:
```lisp
(let ((*hl-failure-backchaining* t)
      (*unbound-rule-backchain-enabled* t)
      (*evaluatable-backchain-enabled* t)
      (*negation-by-failure* (problem-store-negation-by-failure? store)))
  ...)
```
These four parameters control how aggressively the backchainer chases rules. The clean rewrite should keep them as named flags but consider whether they belong on the strategy or the inference rather than as dynamic specials.

### Residual transformation (`inference-worker-residual-transformation.lisp`)

A residual-transformation link is the bookkeeping for *partial* transformation: a transformation rule expects to expand a single literal, but if the surrounding problem has additional sibling literals (a join-ordered structure), then after the rule fires, the *unexpanded* literals form a residual. The residual-transformation link connects the residual back to the join-ordered link that motivated it.

**Triggers** are bidirectional:
- `maybe-possibly-add-residual-transformation-links-via-join-ordered-link(jo-link)` — when a new join-ordered link is created, scan its focal problem's argument links for transformation links and pair each up with the JO link.
- `maybe-possibly-add-residual-transformation-links-via-transformation-link(t-link)` — when a new transformation link is created, scan its supported problem's dependent links for join-ordered links and pair each up.

This double-trigger ensures every JO/transformation pair gets its residual-transformation link regardless of which one is created first.

**Why the asymmetry with regular transformation?** A regular transformation tactic produces a transformation link with one supporting problem (the antecedent). A residual transformation link is the surface area where two larger structures meet — it is *not* a worker that fires; it is bookkeeping. The clean rewrite should present residual-transformation as a derived edge type, not a separate worker; the implementation in the LarKC port is mostly missing-larkc but the trigger logic is in this file.

### Rewrite (`inference-worker-rewrite.lisp`)

A rewrite link applies a *syntactic* rewrite rule: it transforms a literal into another literal without proof obligations. The rewrite is structural: `R(X) → S(X)` becomes a 1-link path. Compared to transformation, rewrite is cheaper because it has no antecedent to prove.

**Data:**
```lisp
(defstruct rewrite-link-data
  hl-module
  bindings
  supports)
```

The Lisp port has most of `inference-worker-rewrite.lisp`'s functions stubbed (mostly missing-larkc); the file is ~123 lines and is mostly the struct, predicates, and the `trigger-restriction-link-listeners` glue. The actual rewrite expansion is in the rewrite modules (see "Removal modules" doc — rewrite modules live in a separate file but use the same registration framework).

**Restriction-listening rewrite.** When a rewrite tactic registers as a listener on a restriction link, it gets notified when the restriction's supported problem produces a proof — and *then* applies its rewrite to the proof's atom. This is the core of how rewrites compose with restrictions: a problem like `(equals ?X ?Y) AND (foo ?X)` can have its `(equals)` proven, the bindings propagated via restriction, and *then* the `(foo)` rewritten.

### Split (`inference-worker-split.lisp`)

A split link decomposes a multi-literal problem into independent sub-problems by partitioning the literals according to *shared variable islands*. Two literals are in the same island iff they share a variable. The split is "anything you can split, you should split" — independent islands have nothing to gain from solving together.

**Data:** none (the supporting-mapped-problems list itself is the data).

**Lifecycle:**
1. `maybe-new-split-link(supported-problem, dnf-clause)` — find or create a split link for the problem
2. `find-or-create-split-link-supporting-problems(store, dnf-clause)` — partition the clause into shared-variable islands via `determine-shared-variable-islands` and create one supporting problem per island
3. `new-split-link(supported-problem, supporting-mapped-problems)` mints the link

**Tactic dynamics.** Each *index* into the supporting-mapped-problems list is its own tactic (`split-tactic` with `tactic-data = index`). The strategy can fire individual index tactics independently. `execute-split-tactic(tactic)` calls `problem-link-open-and-repropagate-index(split-link, index)` to mark that supporting position open and re-trigger propagation.

**Default preference level**: `*split-tactic-default-preference-level*` is `:preferred`. Splits are independent so all should be preferred — unless any one is `:disallowed`, in which case the whole problem is no-good. The preference computation is `compute-split-tactic-preference-level`.

**Proof bubbling.** `bubble-up-proof-to-split-link(supporting-proof, my-variable-map, split-link)` is interesting:
1. Identify which supporting problem produced the proof
2. For each *other* supporting problem, collect all its currently-proven proofs
3. Cartesian product them all — every combination of one proof per supporting problem produces a candidate proof of the supported problem (since the islands are independent)

This is why the proof-bindings-index on each problem is keyed by bindings — the cartesian product naturally produces many candidate combinations.

### Join-ordered (`inference-worker-join-ordered.lisp`)

A join-ordered link is the workhorse of conjunction handling. It splits a connected conjunction into a *focal* literal and a *non-focal* sub-clause, where the focal is solved first and its bindings are pushed down to the non-focal as restrictions.

**Data:**
```lisp
(defstruct join-ordered-link-data
  focal-proof-index             ; equal-keyed dictionary: bindings → proofs
  non-focal-proof-index         ; equal-keyed dictionary: bindings → proofs
  restricted-non-focal-link-index)  ; eq-keyed dictionary
```

The two proof indexes hold proofs as they bubble in from each side. When a focal proof arrives, its bindings are looked up in the non-focal index; matching non-focal proofs are paired into supported-problem proofs. Symmetric for non-focal proofs.

**The restriction layer of indirection.** When a focal proof arrives, instead of immediately querying the non-focal subproblem with the focal's bindings, the system creates a *restriction link* that holds the bindings and the non-focal subproblem solves the restricted version. The restricted version's proofs bubble back up through the restriction to satisfy the JO link. This is the "layer of indirection" the `:add-restriction-layer-of-indirection?` problem-store property controls.

Why the indirection? Several non-focal restrictions can share their underlying unrestricted problem, deduplicating work. Without it, every distinct binding from the focal would generate a fresh non-focal problem.

**Residual-transformation links** attach to JO links — see the residual-transformation worker.

### Join (`inference-worker-join.lisp`)

A join link is like a join-ordered link but unordered: both supporting problems can produce proofs independently and the link does a *hash-join* on their shared variables. There is no focal/non-focal asymmetry.

**Data:**
```lisp
(defstruct join-link-data
  join-vars            ; the shared variables across the two supporting problems
  first-proof-index    ; equal-keyed: bindings (filtered to join-vars) → proofs
  second-proof-index)  ; equal-keyed: bindings (filtered to join-vars) → proofs
```

**Algorithm.** When a proof of the first supporting problem arrives:
1. Filter its bindings to the join-vars
2. Index it: `first-proof-index[filtered-bindings] := proof`
3. Look up matching second proofs in `second-proof-index[filtered-bindings]`
4. For each match, produce a join proof by combining the two

`shared-sibling-vars(first-mapped-problem, second-mapped-problem)` computes the join-vars at link-creation time. The two supporting problems are independent — only the shared vars need to match.

`maybe-new-join-link` is idempotent (looks for an existing link with the same supporting mapped problems before creating a new one).

The join-tactic `tactic-data` is the variable-map that connects the join's supported variables to one of the two supporting problems' variables.

### Union (`inference-worker-union.lisp`)

A union link is an OR-decomposition: any proof of any disjunct proves the supported problem. Most of the implementation is `missing-larkc` in the LarKC port (`new-union-link`, `destroy-union-link`, `execute-union-tactic`, `bubble-up-proof-to-union-link`, etc.).

**Default preference level**: `*union-tactic-preference-level* = :preferred`. Like splits, union disjuncts are independent — all should be preferred.

A `disjunctive-assumption-link-p` is a related link type used when one disjunct is *assumed* rather than proven (during conditional-sentence handling). It uses the `*disjunction-assumption-module*` HL module.

The clean rewrite must reimplement union from the design pattern: a single supported problem, multiple supporting mapped problems (the disjuncts), a proof of any one is sufficient. The proof-bindings are simply the disjunct's bindings (no Cartesian product).

### Restriction (`inference-worker-restriction.lisp`)

A restriction link narrows a problem by applying a binding-set: given an unrestricted problem `P(?X, ?Y)`, the restriction `?X = a` produces a restricted problem `P(a, ?Y)`. The restriction link points from the restricted version *back* to the unrestricted version.

**Two flavours of restriction-link-data:**
```lisp
(defstruct restriction-link-data         ; non-listening
  bindings
  hl-module)

(defstruct restriction-listening-link-data  ; with rewrite listeners
  bindings
  hl-module
  listeners)                             ; rewrite tactics waiting for proofs
```

The `listening` flavour is for rewrite-restriction interaction: when the restriction's supported problem produces a proof, the listeners (rewrite tactics) are triggered to apply their rewrite to the proven atom.

**Lifecycle:**
- `maybe-new-restriction-link(supported-problem, supporting-mapped-problem, restriction-bindings, listening-link?, tactic)` — find an existing matching link or create a new one
- `new-restriction-link(...)` mints the link, opens all supporting positions, propagates
- `bubble-up-proof-to-restriction-link(restricted-proof, restricted-variable-map, restriction-link)` — when the supporting (restricted) problem produces a proof, propagate up to the unrestricted side, then trigger restriction-link-listeners

**Simplification.** `simplification-module-p` is a sub-class of HL modules whose links are restriction links. `simplification-link-p(link)` = `restriction-link-p(link)` AND `simplification-module-p(restriction-link-hl-module(link))`. Simplification tactics fire early and pass down transformation motivation.

### Answer (`inference-worker-answer.lisp`)

The answer link is the special root edge: it connects the inference's *root problem* to the *inference itself*. Every answer flows up through the root problem and across this link. It is the only link type whose `supported-object` is an inference rather than a problem.

```
new-answer-link(inference):
  let answer-link = new-answer-link-int(inference)
  set-inference-root-link(inference, answer-link)
  return answer-link
```

`new-answer-link-int` creates the link with `supported-object = inference` and stores the inference's `explanatory-subquery` in the `data` slot.

The answer link has exactly one supporting-mapped-problem (the root problem). When proofs arrive at the root problem, they propagate up through this link and become inference-answers via `inference-note-proof` (see "Strategist & tacticians" doc, "Producing answers" section).

`note-answer-link-propagated(answer-link)` opens the sole supporting position; thereafter answers can flow freely.

`answer-link-supporting-problem-wholly-explanatory?` returns T iff the explanatory-subquery is `:all` (the whole query is explanatory; no non-explanatory subquery exists).

## Tactic determination

Workers don't run on their own; they run via tactics, and tactics are *determined* lazily. The flow is:

1. Strategist visits a fresh problem (status `:new`).
2. `determine-new-tactics(problem)` is called by the strategist.
3. Inside `within-problem-consideration(problem)`:
   - If the problem is single-clause, dispatch to `determine-new-tactics-for-dnf-clause(problem, sole-clause)`
   - Otherwise dispatch to `determine-new-tactics-for-disjunction(problem, query)` (missing-larkc 35213)
4. `note-problem-examined(problem)` — flip status from `:unexamined` to `:examined`
5. `discard-all-impossible-possible-tactics(problem)` — remove tactics with completeness `:impossible`
6. `consider-that-problem-could-be-no-good(problem, ...)` — if no possible tactics remain, mark problem as `:no-good`

Inside `determine-new-tactics-for-dnf-clause(problem, dnf-clause)`:

| Clause kind | Dispatch |
|---|---|
| `pos-atomic-clause-p` (single positive literal) | `determine-new-tactics-for-literal(problem, asent, :pos)` |
| `neg-atomic-clause-p` (single negative literal) | `determine-new-tactics-for-literal(problem, asent, :neg)` |
| else (multi-literal) | `determine-new-tactics-for-multiple-literals(problem, dnf-clause)` |

`determine-new-tactics-for-literal(problem, asent, sense)` then:
1. `with-inference-mt-relevance(mt)` — bind MT relevance to the literal's microtheory
2. `determine-new-literal-removal-tactics(problem, asent, sense)` — always
3. If `problem-store-rewrite-allowed?`: rewrite tactics (missing-larkc 32957)
4. If `problem-store-transformation-allowed?`: `add-tactic-to-determine-new-literal-transformation-tactics(...)` — adds the meta-transformation tactic placeholder

`determine-new-tactics-for-multiple-literals(problem, dnf-clause)`:
1. `determine-new-conjunctive-removal-tactics(problem, dnf-clause)`
2. If all literals are connected by shared vars (`all-literals-connected-by-shared-vars?`):
   - `determine-new-connected-conjunction-tactics(problem, dnf-clause)` — both join-ordered AND join tactics
3. Otherwise:
   - If `meta-split-tactics-enabled?`: `determine-new-meta-split-tactics(problem, dnf-clause)` — defers split decision until later
   - Otherwise: classical split (missing-larkc 36478)

The connected-conjunction case produces *both* a join-ordered tactic and a join tactic for the same problem — the strategist will pick whichever scores better.

## Compute-strategic-properties dispatch

Once tactics are determined, the strategist asks the worker to compute their *strategic* properties (productivity and preference-level) wrt the strategy:

`default-compute-strategic-properties-of-tactic(strategy, tactic)`:

| Tactic kind | Function |
|---|---|
| split-tactic | `compute-strategic-properties-of-split-tactic` |
| meta-split-tactic | `compute-strategic-properties-of-meta-split-tactic` |
| union-tactic | (missing-larkc 33005) |
| join-ordered-tactic | `compute-strategic-properties-of-join-ordered-tactic` |
| join-tactic | `compute-strategic-properties-of-join-tactic` |
| transformation-tactic | `compute-strategic-properties-of-transformation-tactic` |
| meta-transformation-tactic | (missing-larkc 36428) |
| removal-tactic | `compute-strategic-properties-of-removal-tactic` |
| meta-removal-tactic | (missing-larkc 36109) |
| rewrite-tactic | (missing-larkc 32956) |
| conjunctive-removal-tactic | (missing-larkc 0) |

These compute productivity and preference at *strategic-context* granularity — the same tactic can have different productivities under different strategies (e.g. an exhaustive strategy values completeness over speed). The cached results live on the tactic via `set-tactic-strategic-productivity` / `set-tactic-strategic-preference-level`.

## Proof bubbling

Each worker contributes a `bubble-up-proof-to-<type>-link` function. When a supporting problem produces a proof, the harness calls each dependent link's bubble-up function. The dispatch is by link type (in `bubble-up-proof` in inference-worker.lisp). The bubble-up function:

1. Combines the proof with sibling proofs (cartesian product for split/union; hash-join lookup for join/join-ordered; pass-through for restriction; no-op for removal because removal links have no supporting problems)
2. Computes the resulting bindings via `proof-bindings-from-constituents`
3. Calls `propose-new-proof-with-bindings(link, bindings, subproofs)` to mint or find the proof
4. If newly-created, recursively `bubble-up-proof(new-proof)` to continue propagation
5. If the link is the root answer-link, fires `inference-note-proof` to register an inference-answer

## Open flags

Every link has an `open-flags` bitfield indicating which supporting-mapped-problem positions are still being explored. `problem-link-open-all` opens all positions; `problem-link-open-and-repropagate-index(link, idx)` opens a specific index and re-runs propagation for newly-opened state; `problem-link-close-index(link, idx)` closes a position (so further proofs from that problem don't bubble up). `do-problem-link-supporting-mapped-problems` accepts a `:open?` keyword to filter only open positions.

The open/closed distinction is necessary because a JO link's non-focal position is *closed* until a focal proof arrives that opens it (with the appropriate bindings). For split links, opening an index is what fires that branch's tactic. For removal links there are no supporting positions, so the flag is irrelevant.

## Dynamic specials used by workers

| Special | Bound by | Used by |
|---|---|---|
| `*currently-executing-tactic*` | `within-tactic-execution` | `execute-tactic` recursion check, debug |
| `*currently-active-problem*` | `within-problem-consideration` | tactic determination |
| `*asent-of-currently-executing-tactic*`, `*mt-of-currently-executing-tactic*` | `within-single-literal-tactic-with-asent-and-mt` | HL module callbacks |
| `*hl-failure-backchaining*`, `*unbound-rule-backchain-enabled*`, `*evaluatable-backchain-enabled*` | `with-problem-store-transformation-assumptions` | rule expansion |
| `*negation-by-failure*` | `with-problem-store-tactical-evaluation-properties` and `with-problem-store-removal-assumptions` | HL module callbacks |
| `*resourced-sbhl-marking-spaces*`, `*resourcing-sbhl-marking-spaces-p*`, `*resourced-sbhl-marking-space-limit*` | `simplest-inference-run-handler` | SBHL graph traversal |

The clean rewrite should keep these as dynamic context (or thread-local) — they are used deep in HL module callbacks and threading them through every call would be impractical.

## Cross-system consumers

- **Strategist** calls `execute-tactic` and `determine-new-tactics`.
- **Workers call each other**: a transformation worker creates child problems whose tactics are determined fresh; a JO worker creates restriction links via the restriction worker; a residual-transformation worker is triggered as a side-effect of JO and transformation worker actions.
- **HL modules** are the leaves: removal/transformation/rewrite workers funnel control to module-defined `:expand` functions. The workers manage the *infrastructure*; the modules supply the *domain logic*.
- **Backward inference** (`backward.lisp`) and **forward inference** (`forward.lisp`) trigger workers via the kernel's `new-cyc-query` path.
- **Argumentation** (`argumentation.lisp`) reads the link/proof structures workers build to produce explanations.
- **Inference analysis** consumes link-level metrics produced as side effects (per-rule success counters, etc.).

## Notes for the rewrite

- **The 11 link types are 11 cases of one trait**: `(create_link, bubble_up, dispose)`. The clean rewrite should express them via a sealed sum type with per-variant data, plus a trait/typeclass for the bubble-up logic.
- **Workers should be data-only as much as possible.** Most worker code is bookkeeping: index this proof, enumerate that link. The actual reasoning is in the HL module's `:expand` function. Aim to make worker code 100% generic over link/proof shape; HL modules carry the domain logic.
- **Proof bubbling is recursive.** Don't try to flatten it — the recursion mirrors the proof DAG structure.
- **`open-flags` is a bitfield because most links have ≤16 supporting positions.** Keep it as a u16. For union with many disjuncts, this is the limit; use a u32 or a bitvector if needed.
- **The `meta-` tactics (meta-removal, meta-transformation, meta-split) are deferred decisions.** A meta-tactic fires once and produces concrete tactics on the fly. The clean rewrite should keep this — it lets the strategy decide whether to commit to expansion based on cost.
- **The function-spec dispatch tables in `removal-module-*-funcall`** are a port-time hack. Replace with direct function references on the HL module struct.
- **`simplification-module-p` has special status** — it routes through restriction links and fires early. Keep this; it is what makes simple algebraic rewriting work (e.g. `0 + ?X → ?X`) without going through full transformation machinery.
- **Many workers are mostly missing-larkc** — rewrite (95% missing), residual-transformation (mostly missing), union (mostly missing), some tactic-property computations. The trigger logic is in the file; the fanout is not. The clean rewrite must recreate the fanout from the proof-bubbling protocol.
- **The split worker's preference level (`*split-tactic-default-preference-level* = :preferred`)** is a load-bearing decision: making splits preferred ensures the strategist always picks them when available. Don't accidentally regress this.
- **Restriction listeners** are how rewrites compose with restrictions. The listening-link-data flavour is used; the regular flavour is not. The clean rewrite should consider unifying these into one flavour with an optional listener list.
- **Open-flags vs. proof-indexes.** Two ways the engine tracks "what's been seen so far": open-flags say which supporting positions are *active*; proof-indexes say which *bindings* have arrived. Both are needed. Don't conflate them.
