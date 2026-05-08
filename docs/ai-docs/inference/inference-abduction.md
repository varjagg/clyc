# Inference abduction utilities

Abduction is *reasoning backward from observations to assumptions*: instead of asking "given the rule and the antecedent, what follows?" (deduction), abduction asks "given the rule and the conclusion, what assumption would make this conclusion provable?" The engine treats abduced assumptions as hypotheses — they are returned as part of the answer's bindings rather than as proven facts.

This file (230 lines, mostly missing-larkc bodies) defines the **abductive strategy type** — a tactician variant that prefers *deductive* tactics over *abductive* ones, falling back to abduction only when no deductive path remains. The strategy registration is in this file; the actual abductive removal modules are in `inference/modules/removal/removal-modules-abduction.lisp` (covered by "Removal modules" doc).

Source file: `inference/harness/inference-abduction-utilities.lisp`

## When does abduction fire?

Abduction is opt-in via the inference static property `:abduction-allowed?` (defaults nil). When the user sets this true:
1. `strategy-type-from-static-properties` selects `*abductive-strategy-type* = :abductive` instead of the default tactician.
2. Abductive removal modules (the `:removal-abduction-*` family) become applicable to literals they would otherwise skip.
3. Some completeness-related transformations are unlocked.
4. The strategy gives transformation tactics a different happiness scoring (see "Heuristics" below).

`abduction-allowed-by-properties?` (in inference parameters) returns the static property's value. `problem-store-abduction-allowed?` is the per-store version, set when the store is created.

## The `:abductive` strategy type

The strategy type is registered in this file's `(toplevel ...)` form. Its dispatch table is mostly the same as the heuristic-balanced tactician's — same `:done?`, same `:do-one-step`, same `:select-best-strategem`, same `:quiesce` — with the per-strategy methods (peek/activate/pop/no-active for removal/new-root/transformation) replaced by abductive variants.

The substantive difference is the *happiness scoring*: the abductive strategy has its own per-tactic happiness function that combines a different set of heuristics with different scaling factors (see "Heuristic sets" below).

`abductive-strategy-p(object)` — predicate.

`abductive-strategy-initialize(strategy)` (missing-larkc) — analogous to `heuristic-balanced-strategy-initialize`; sets up the `data` slot.

The abductive strategy variant lives in `*strategy-type-store*` keyed by `:abductive`, alongside `:heuristic-balanced`, `:balancing`, and `:removal`.

## Proof rejection: `reject-proof-due-to-non-abducible-rule?`

```
reject-proof-due-to-non-abducible-rule?(link, supported-problem, subproofs):
  abduction-allowed-on-store?
  AND link is a transformation link
  AND link's rule has the non-abducible-rule property (missing-larkc 6923)
  AND any subproof is itself abductive (missing-larkc 33038)
```

Hits the `:non-abducible-rule` `*proof-reject-reasons*` keyword. The check is: a rule that's been marked non-abducible cannot have an abductive subproof — its conclusion can be deduced but not abduced.

The list of helpers (mostly missing-larkc) describes what the engine knows about abducibility:

| Helper | Purpose |
|---|---|
| `non-abducible-sentence?` | Is this whole sentence non-abducible? |
| `non-abducible-relation?` | Is the predicate a non-abducible-relation? |
| `non-abducible-predicate?` | Is the predicate non-abducible? |
| `non-abducible-collection?` | Is the asent's collection non-abducible? |
| `non-abducible-for-argnum?` | Is the predicate non-abducible at this arg position? |
| `non-abducible-wrt-value-in-argnum?` | …with this specific value? |
| `non-abducible-wrt-value-in-argnum-via-type?` | …via the value's type? |

These are KB-driven: a predicate is non-abducible iff there's a `(nonAbducible<...>` GAF in the KB asserting so. The check is what makes the engine respect KB-author intent: some predicates (e.g. metaknowledge predicates like `genls`) shouldn't be abductively assumed.

## Heuristic sets

`*abductive-tactician-removal-heuristics*` — for removal tactics, the abductive strategy uses just two heuristics:
- `:strategic-productivity` — prefer tactics with *lower* productivity (because high-productivity removal would dominate; we want to delay that to give abduction a chance)
- `:delay-abduction` — prefer deductive over abductive tactics

`*abductive-tactician-transformation-heuristics*` — for transformation tactics, the abductive strategy uses 9 heuristics:
- `:shallow-and-cheap`
- `:completeness`
- `:occams-razor`
- `:magic-wand`
- `:backchain-required`
- `:rule-a-priori-utility`
- `:relevant-term`
- `:rule-historical-utility`
- `:literal-count`

This is a *subset* of the 12 heuristics used by the heuristic-balanced tactician — abduction skips `:backtracking-considered-harmful`, `:rule-literal-count`, `:skolem-count`. The reasoning: abduction is *generative* (it invents bindings), so heuristics that penalise complexity are less relevant.

## The three abductive heuristics

This file declares three strategic heuristics specific to abduction:

### `:strategic-productivity` (scaling-factor 100, `:generalized-removal-or-rewrite`)

```
"Prefer removal tactics with lesser productivity over more productive tactics"
```

Inverts the usual heuristic. Normally high-productivity tactics are preferred; in abduction the opposite. The reasoning: a high-productivity removal tactic will produce many answers immediately, leaving no room for abduction to invent additional ones. Better to use lower-productivity removal first so abduction has work to do.

### `:delay-abduction` (scaling-factor 10000, `:generalized-removal-or-rewrite`)

```
"Prefer deductive removal tactics over abductive removal tactics."
```

Massive scaling factor (10000) — this heuristic dominates. Abductive removal modules (anything in `removal-modules-abduction.lisp`) get a huge happiness penalty, so they only fire when no deductive removal is available.

### `:rule-abductive-utility` (scaling-factor 500)

```
"Prefer proof paths using rules that work well for generative abductive inferences,
without considering the situations in which they were used, i.e.
prior probability.  Consider proof paths using no rules to be at 100%."
```

A learned heuristic: per-rule abductive utility, computed from historical success rates of using the rule in abductive proofs. Implemented via `transformation-problem-rule-abductive-utility(problem, rule)` and `compute-problem-rule-abductive-utility` (missing-larkc).

`*heuristic-rule-abductive-utility-problem-recursion-stack*` — guards against infinite recursion when computing utility (the computation may need to recursively check sub-problems).

## What an abductive answer looks like

When abduction is allowed and the engine returns an answer that includes abduced assumptions, the answer's bindings include both:
- *Proven* bindings — variables assigned to values via deductive proof
- *Hypothesised* bindings — variables assigned to assumptions the engine had to make

The two are distinguished by the answer's `inference-answer-bindings` vs. `inference-hypothetical-bindings` (in the inference struct). Inference returns both; the user's `:return` template may use `:bindings-and-hypothetical-bindings` to receive them as a 2-tuple.

The `result-uniqueness-criterion` for an abductive inference is forced to `:proof` (in `strengthen-query-properties-using-inference`) — different abductive paths to the same bindings count as different answers because their assumptions differ. With `:bindings`, you'd lose the hypothetical-bindings distinction.

## Pruning semantically bad new roots

`*prune-semantically-bad-new-roots?*` (defparameter, default nil) — when on, the abductive strategy actively prunes new-root candidates that are provably false (`abductive-strategy-new-root-provably-false?`). The check uses `provably-false-contextualized-isa-asent?`, `provably-false-contextualized-tou-asent?`, etc. (all missing-larkc).

The intent: if the new-root would be `(isa SomeNewObject Penguin)` and the engine already knows `(disjointWith Cat Penguin)` and the new object is asserted as `(isa SomeNewObject Cat)`, the new-root is provably false — don't pursue it. Pruning these cuts the search space.

## When does each piece fire?

| Operation | Fires when |
|---|---|
| Strategy type selection | Per-query, in `strategy-type-from-static-properties` |
| `reject-proof-due-to-non-abducible-rule?` | When a worker creates a transformation link, before producing a proof |
| Abductive heuristic happiness | Per-tactic, in `abductive-strategy-generic-tactic-happiness` |
| Hypothetical bindings | Per-answer, when an abductive proof is registered |
| Pruning provably-false new roots | Per new-root, in `abductive-strategy-chooses-to-throw-away-new-root?` |

## Cross-system consumers

- **Strategist** registers and dispatches the `:abductive` strategy type.
- **Removal worker** consumes abductive removal modules via the standard module registration.
- **Inference parameters** has `:abduction-allowed?` as a static property (default nil); also forces `:result-uniqueness-criterion :proof` when set.
- **Removal modules abduction** (`inference/modules/removal/removal-modules-abduction.lisp`) registers six abductive removal modules: `:removal-abduction-pos-check`, `:removal-abduction-pos-unify`, `:removal-exclusive-abduction-pos`, `:removal-abduction-neg-check`, `:removal-abduction-neg-unify`, `:removal-exclusive-abduction-neg`.
- **Strategic heuristics** infrastructure (`inference-strategic-heuristics.lisp`) provides the framework these abductive heuristics plug into.

## Notes for the rewrite

- **Abduction is opt-in.** Default off. Most queries don't need it; turning it on changes the answer set substantially (including hypothetical answers).
- **The strategy is mostly the heuristic-balanced strategy with different heuristics.** Don't duplicate the dispatch — make abduction a *configuration* of balanced rather than a wholly separate type. Specifically: the `:abductive` strategy registration here mostly delegates to `balanced-strategy-do-one-step`, `balanced-strategy-quiesce`, etc.
- **The 3 abductive heuristics are essential.** `:delay-abduction` with its 10000 scaling factor is what makes abduction "tried last" rather than dominant. Without it, abduction would generate spurious answers.
- **`:strategic-productivity` inverts the normal preference order.** This is a deliberate trade-off, not a bug. Keep it.
- **`:non-abducible-rule` proof rejection** is missing-larkc on both the `non-abducible-rule?` predicate and the subproof check. The clean rewrite must reconstruct: a transformation link is non-abducible iff its rule has a `(nonAbducibleRule rule)` GAF in the KB; subproofs are abducible iff at least one is an abductive proof.
- **`abduction-allowed-on-asent?`** is the per-literal check (mostly missing-larkc). The clean rewrite needs predicates for: predicate non-abducibility, collection non-abducibility, per-arg non-abducibility, per-value-in-arg non-abducibility. These all read from KB GAFs.
- **`do-abductive-tactician-strategic-heuristics` macro** is left as TODO in the port. The pattern is similar to `do-heuristic-balanced-tactician-strategic-heuristics` but adds a `motivation` parameter. The macro determines which heuristics to consult based on the motivation (`:removal | :transformation | :new-root`).
- **The abductive strategy's `:peek-*` / `:activate-*` / `:pop-*` methods** are missing-larkc placeholders. The expected behaviour: same as heuristic-balanced but consulting the abductive happiness function. The clean rewrite should make these one parameterised set of functions, parameterised on the heuristic set.
- **`*prune-semantically-bad-new-roots?*` is defparameter** — can be enabled per-query. Useful for tests; default off because the provable-false check is itself expensive.
- **Hypothetical bindings vs. regular bindings** — the result struct has two slots; the user's `:return` template addresses both. Keep this dual-binding model.
- **`*heuristic-rule-abductive-utility-problem-recursion-stack*`** — necessary because the utility computation is itself a per-problem inference, which can recurse. The stack is checked before recursing; if the problem is on the stack, return a default to break the cycle. Keep this; it's required for correctness.
