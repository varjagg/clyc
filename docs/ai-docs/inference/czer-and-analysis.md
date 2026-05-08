# Inference canonicalization, analysis, and instrumentation

The harness needs three categories of supporting code that don't fit the worker/strategist/module taxonomy:

1. **Canonicalization (czer)** — turning a user query into the canonical form the engine actually runs on. Sort literals deterministically, dedup duplicate clauses, simplify trivial constructs, name variables consistently. Done once per query.
2. **Trivial query fast path** — recognising syntactically obvious queries and answering them without spinning up the full strategist.
3. **Analysis and instrumentation** — counters, metrics, statistics, completeness machinery, transformation-depth bookkeeping, lookahead productivity, strategic heuristics. The auxiliary infrastructure that makes the strategist's decisions informed.

These are technically separate concerns, but they cluster naturally: czer prepares the input; trivial-query short-circuits; everything else is bookkeeping the engine accumulates as it runs.

Source files (4007 lines total):
- `inference/harness/inference-czer.lisp` (781) — query canonicalization
- `inference/harness/inference-trivial.lisp` (309) — trivial query fast path
- `inference/harness/inference-analysis.lisp` (567) — historical statistics, transformation-rule statistics, asked-queries logging
- `inference/inference-completeness-utilities.lisp` (424) — completeness predicate accessors
- `inference/harness/inference-min-transformation-depth.lisp` (365) — transformation-depth signature propagation
- `inference/harness/inference-metrics.lisp` (449) — historical counters and inference-metric struct
- `inference/inference-pad-data.lisp` (240) — empirical PAD timing data
- `inference/harness/inference-strategic-heuristics.lisp` (775) — pluggable scoring heuristics
- `inference/harness/inference-lookahead-productivity.lisp` (97) — productivity estimation lookahead

## Canonicalization (czer)

Every problem-store has an `equality-reasoning-method` (`:equal | :czer-equal`) that decides how new problems are deduplicated against existing ones. With `:czer-equal`, the system canonicalizes both sides and compares the canonical forms. So canonicalization is what gives the search graph its DAG structure rather than tree-with-duplicates.

`canonicalize-problem-query(query)` is the entry point. The pipeline:

```
canonicalize-problem-query(query):
  let query = copy-tree(query)            ; mutate-safe copy
  let q1 = inference-simplify-problem-query(q)        ; (not (and ...)) → (or ...), etc.
  let q2 = inference-sort-clauses-and-literals(q1)    ; deterministic ordering
  let q3 = inference-delete-duplicate-literals(q2)    ; literal dedup
  let q4 = inference-delete-duplicate-clauses(q3)     ; clause dedup
  return contiguize-hl-vars-in-clauses(q4)            ; rename ?V0 ?V1 ?V2 ...
```

### Simplification — `inference-simplify-problem-query`

Walks every contextualized DNF clause and runs three rewrites at the literal level (`inference-simplify-contextualized-asent`):

1. **`(ist <mt> <asent>)`** with fully-bound `<mt>` → flatten by stripping the `ist` and using `<mt>` as the literal's microtheory. Saves work and lets the engine see the actual asent for indexing/cost purposes.
2. **`(trueSentence <asent>)`** (the metaphysical "this is the case" wrapper) → just `<asent>`.
3. **`(elementOf ?X (TheSetOf ?Y (isa ?Y <coll>)))`** → `(isa ?X <coll>)`. A common idiom users write that simplifies to a primitive.

Plus, in `inference-simplify-contextualized-dnf-clause`: for each `neg-lit` whose underlying asent is a `true-sentence`, *move* it to `pos-lits` (after `inference-simplify-negated-true-sentence` does the inversion). This keeps the polarity-canonicalised form: `(not (true X))` becomes the positive literal `X`.

These simplifications are conservative — only known-equivalent rewrites. They are not the full canonicalizer (`canon-tl.lisp` etc.) which is run *before* this pass; this is just the inference-side cleanup of forms the canonicalizer cannot eliminate without context.

### Sorting — `inference-sort-clauses-and-literals`

Deterministic ordering is the precondition for dedup. Two pieces:

- **Per-clause:** `inference-sort-contextualized-clause-literals` sorts the neg-lits and pos-lits of each clause. Default sort is `inference-awesome-sort-contextualized-literals` (the "awesome" sorter — the simple sorter is `inference-simple-sort-contextualized-literals` using `inference-contextualized-asent-<` as the comparator).
- **Per-clauses:** `inference-sort-contextualized-clauses` (missing-larkc 35651) sorts a multi-clause query.

The total order: terms are typed (`inference-term-type-code`); types compare numerically; within a type-code, type-specific comparators are used (`inference-constant-<` for constants, `inference-formula-<` for formulas, `<` for fixed-variable IDs and numbers). Variables come last. The order is opaque to clients — what matters is determinism.

### "Awesome" literal sorting

`inference-awesome-sort-contextualized-literals` is a more sophisticated sort that handles commutativity and fully-fixed-vs-free literals:

```
inference-awesome-sort-contextualized-literals(literals):
  iterate while there are unsorted literals:
    pick fully-fixed literals first (they have no variables to vary)
    pick uniquely-constrained literals next (they fix a variable that
      others depend on — picking them first reduces the search later)
    pick unique-commutative literals last
```

The "awesome" name reflects that this sort is more than alphabetical — it is a *deferred-decision* heuristic that picks literals in an order that makes downstream dedup and search more effective. `*inference-czer-fixed-vars-table*` and `*inference-czer-next-fixed-var-id*` track the fixed-variable namespace as the sort proceeds.

`*inference-czer-at-least-partially-commutative-relations-alist*` caches commutativity info per predicate — used by `at-least-partially-commutative-contextualized-asent-p` to decide whether literal argument order matters for sorting.

### Deduplication — `inference-delete-duplicate-literals`, `…-clauses`

`delete-duplicate-sorted-literals(literals)` runs `delete-duplicates-sorted` on `equal`. After dedup, if anything was removed, the clauses are re-sorted (since dedup may have changed structure that affected the sort).

Clause-level dedup likewise (mostly missing-larkc in the LarKC port — the structure is there but the body is in `delete-duplicate-sorted-clauses`).

### Variable contiguization — `contiguize-hl-vars-in-clauses`

After all the above, the HL variable numbers may have gaps (because some variables were eliminated). This pass renumbers them `?V0, ?V1, ?V2 …` in the order they first appear. `*hl-var-contiguity-alist*` tracks the renaming.

The result is *the* canonical form: any two semantically-equivalent queries produce the same canonical representation. This is what the problem-store uses as the dedup key.

### Public canonicalization entry points

- `inference-canonicalize-ask-memoized(cycl-query, mt, disjunction-free-el-vars-policy)` — the user-facing canonicalizer; memoised. Returns three values: `czer-result` (canonical form), `el-bindings` (EL→HL var map), `free-el-vars` (free EL variables in display preference order).
- `inference-canonicalize-ask-int(...)` — the worker.
- `inference-standardize-canonicalize-ask-result(...)` — applies the disjunction-free-el-vars policy and produces the standard form.

### Helper functions for clauses and asents

A pile of helpers in this file are the *standard library* for working with contextualized DNF clauses. Most relevant for the rewrite:
- `contextualized-neg-lits(clause)`, `contextualized-pos-lits(clause)` — accessors
- `convert-to-hl-contextualized-asent(asent, mt)` — builds a contextualized asent from EL/HL form
- `dnf-and-mt-to-hl-query(dnf-clause, mt)` — wraps a DNF clause into a fully-canonical problem-query
- `contextualize-clause(clause, mt, ...)` — pushes an mt down through a clause
- `canonicalize-contextualized-clause(...)` — clause-level canonicalisation
- `contextualized-dnf-clause-formula(...)` — converts to display formula
- `contextualized-dnf-clause-common-mt(clause)` — extracts the common MT (or nil) across all literals
- `determine-best-clauses-level-mt(clauses)` — picks the MT to attach at the clauses level

## Trivial-query fast path

`inference-trivial.lisp` implements the optimisation that lets the kernel return immediately for syntactically obvious queries. Triggered by `*new-cyc-trivial-query-enabled?*` (defaults T; the comment says it should always stay T).

`new-cyc-trivial-query-int(sentence, mt, query-properties)`:
1. Strengthen the query properties (`trivial-strategist-strengthen-query-properties`) — drop properties this fast path doesn't honour, force `:answer-language :hl` if the user asked for `:supports`.
2. Check whether the trivial strategist can handle these properties (`trivial-strategist-can-handle-query-properties?`). If not, fall through.
3. Filter to just the properties this path *does* handle (`trivial-strategist-at-least-partially-handled-query-property-p`).
4. Canonicalise the sentence into clauses.
5. If the result is `atomic-clauses-p` (single clause, atomic), dispatch to `new-cyc-trivial-query-via-removal-ask` — call the removal-ask machinery directly without the full strategist.
6. Otherwise return `(values nil :non-trivial nil)` to fall through.

`new-cyc-trivial-query-via-removal-ask(sentence-clause, v-bindings, free-hl-vars, trivial-query-properties)`:
1. Determine truth: positive clause → `:true`, negative → `:false`
2. Destructure to `(hl-mt, hl-sentence)`
3. Pick out a few critical properties: `:max-time`, `:return`, `:answer-language`, `:productivity-limit`
4. Call `removal-ask(hl-sentence, hl-mt, truth, removal-ask-query-properties)` inside `with-inference-error-handling`, `with-timeout`, and `with-possibly-new-memoization-state`
5. Post-process: filter uninteresting bindings, transform closed-query success, transform return type

`*current-query-properties*` is bound to the trivial-query properties so deep code can read them.

### What properties does the trivial strategist handle?

`*trivial-strategist-dont-care-properties*` — properties whose value is irrelevant to the trivial path (13 keys: `:disjunction-free-el-vars-policy`, `:allow-*-predicate-transformation?`, `:allowed-rules`, `:max-proof-depth`, `:probably-approximately-done`, `:max-problem-count`, `:transformation-allowed?`, etc.). The trivial path can be used regardless of these.

`*trivial-strategist-forbidden-properties*` — properties whose presence (any value) disqualifies the trivial path: `:conditional-sentence?`, `:non-explanatory-sentence`, `:maintain-term-working-set?`, `:cache-inference-results?`, `:browsable?`, `:continuable?`. These all imply needing the full strategist.

The remaining "at-least-partially-handled" properties are forwarded to `removal-ask`.

### Why does this exist?

`removal-ask` is a much shallower entry-point than `new-cyc-query` — it bypasses problem-store creation, strategy initialization, and the strategist's main loop. For a single-literal positive query that just needs a removal lookup, the kernel pays an enormous overhead it doesn't need. The trivial-query path detects this and uses removal-ask directly.

The clean rewrite should keep this fast path. Most queries the engine answers are trivial in this sense — ASK on a single fact, ASK with one obvious lookup. The savings are large.

## Inference analysis

`inference-analysis.lisp` is the engine's *learning surface* — it records what worked and what didn't so future runs can prefer rules that have succeeded historically.

### Transformation rule statistics

Per-rule counters in `*transformation-rule-statistics-table*` (eq-hashtable, rule → 4-element vector):

| Index | Counter |
|---|---|
| 0 | total-considered count (across all-time runs) |
| 1 | total-success count |
| 2 | recent-considered count (since last reset of "recent" window) |
| 3 | recent-success count |

Updates are guarded by `*transformation-rule-statistics-lock*`. `update-rule-statistics` (and friends) is called from `perform-inference-answer-proof-analysis` (in inference-strategist.lisp) when an answer's proof contains a transformation step — every rule that contributed to a successful proof gets its success counter bumped.

Pruning thresholds:
- `*transformation-rule-historical-success-pruning-threshold*` — absolute success count below which the rule is never tried (default 0; clean rewrite should make this configurable per-mode)
- `*transformation-rule-historical-utility-pruning-threshold*` — utility (success - considered × cost) below which the rule is never tried (default -100)

The `*average-rule-historical-success-probability*` (≈ 0.029) is the prior probability used to compute the Beta-distribution-like utility scores for never-tried rules.

`*transformation-rule-statistics-update-enabled?*` is the master switch. Disable it for deterministic test runs.

### Connectivity graph

`*transformation-rule-historical-connectivity-graph*` — eq-hashtable from rule → set-contents of rules that have appeared in a successful proof together. Models "rule A often succeeds with rule B" — the strategist uses this for the `:rule-historical-utility` heuristic.

### Recent-experience persistence

`*transformation-rule-statistics-filename-load-history*` and `*save-recent-experience-lock*` track the persistence layer. Recent experience can be saved to a file (the experience transcript) and loaded back into a fresh image — so historical statistics survive image restart. The exact file format is mostly missing-larkc; the load-history list tracks which files have been incorporated.

`add-to-transformation-rule-statistics-filename-load-history(filename)` is the registration; `clear-transformation-rule-statistics-filename-load-history()` is the reset.

### Asked-queries logging

`*asked-queries-queue*` — a queue of recent queries (limit `*asked-queries-queue-limit*` = 300). Queries are enqueued by `possibly-enqueue-asked-query` from the kernel's run path. When the queue fills, the contents are flushed to a file (the asked-queries transcript). Used for query-replay testing and for offline analysis of what users ask.

`*asked-query-common-symbols*` — symbol table for CFASL-encoding queries to the asked-queries file. (CFASL files have a per-file symbol table to avoid repeating long symbol names; this is its asked-queries flavour.)

`*save-recent-asked-queries-lock*` guards concurrent flushes.

### HL module expand counts

`*hl-module-expand-counts-enabled?*` — when enabled, every call to an HL module's `:expand` increments `*hl-module-expand-counts*[module]`. This is profiling data: which modules are doing the most work? The clean rewrite should keep this opt-in (it adds overhead).

## Inference completeness utilities

`inference-completeness-utilities.lisp` is the read-only side of completeness reasoning: given a predicate and an MT, look up which completeness GAFs apply.

The four completeness levels (recap):
- **Complete extent asserted** — the GAFs in MT-and-genlMts capture every true statement of the predicate
- **Complete extent enumerable** — even if not asserted, the answers can be enumerated by some procedure
- **Complete extent decidable** — given a candidate, can decide truth (weaker than enumerable but stronger than nothing)
- **Incomplete** — the default

Each level has a `(memoized) inference-complete-extent-X-gafs(predicate, mt)` accessor that walks the MT hierarchy and collects every supporting GAF. The plural-gafs variants return a list ordered by inferential strength (strongest first).

The per-arg variants (`-for-arg-gafs`, `-for-value-in-arg-gafs`) are finer-grained: a predicate may be complete only for a specific argument position, or only when that argument is bound to a specific value (e.g. `(bordersOn USA ?X)` is complete because we know all USA's borders, but `(bordersOn ?X ?Y)` is not).

These accessors are what backchain-required modules and meta-removal modules consult to decide whether to fire. They are also what `:complete-pattern` and `:completeness-pattern` HL module properties evaluate against.

## Min transformation depth

The *minimum transformation depth* of a problem is the smallest number of transformation steps required to reach an answer. Tracked per-problem in the store (`min-transformation-depth-index`) so the strategist can:
1. Avoid re-considering a problem at depth N if it has already been considered at depth M ≤ N
2. Honour `:max-transformation-depth` by refusing to expand problems past the limit
3. Compute the strategic heuristic `:shallow-and-cheap` (preferring shallower problems)

`inference-min-transformation-depth.lisp` implements depth *signature* propagation. A signature is a tree-shaped record of per-literal depths (in `:counterintuitive` mode, `tree-min-number(signature)` gives the depth; in `:intuitive` mode, `tree-sum(signature)` gives a total transformation count).

The propagation is link-type-aware:
- **Transformation link:** child = parent + 1 (one more transformation step on the way down)
- **Join-ordered link:** focal child = parent's focal-spec subclause; non-focal child = parent's non-focal-spec subclause (each preserves its sub-depth)
- **Split link:** each conjunct child gets the parent's subclause-restricted depth signature
- **Restriction link:** child = parent (restriction is depth-zero)
- **Residual transformation link:** parallel to transformation (missing-larkc 35423)
- **Union link:** parallel to split (missing-larkc 35424)

`propagate-min-transformation-depth-signature(problem, mtds, inference)` updates the problem's depth signature. If the new signature is strictly less than the existing, fan out to all the problem's argument-links and recurse.

`*problem-min-transformation-depth-from-signature-enabled?*` (defaults T) controls whether the depth comes from the signature or from the legacy direct-counter approach. The "Temporary control variable" comment says it should always be on; clean rewrite should remove the flag.

## Inference metrics

`inference-metrics.lisp` declares the **counter infrastructure** the engine uses for per-run metrics and for global historical counts. Two parts:

### `inference-metric` struct (declared metrics)

```lisp
(defstruct (inference-metric (:conc-name "INF-METRIC-"))
  name                   ; keyword identifier
  evaluation-func        ; symbol — function called as (func problem-store inference)
  evaluation-arg1        ; static first arg
  cross-product?)        ; whether to cross-product over answers (per-answer metric)
```

`declare-inference-metric(name, evaluation-func, evaluation-arg1, &optional cross-product?)` registers a metric. The store is `*inference-metrics-store*`. When an inference's `:metrics` template names a metric, `inference-metric-evaluate(metric, problem-store, inference)` runs the evaluation-func and records the result.

### Historical counters

A pile of `defglobal *X-historical-count*` and `increment-X-historical-count` pairs:

| Counter family | Counts |
|---|---|
| `*problem-store-historical-count*` | how many stores have been created |
| `*forward-problem-store-historical-count*` | forward-mode stores |
| `*maximum-problem-store-historical-problem-count*` | worst-case problem count seen |
| `*expensive-forward-problem-store-threshold*` | warn threshold for forward stores (1000) |
| `*problem-historical-count*` | how many problems |
| `*good-problem-historical-count*`, `*no-good-problem-historical-count*` | by provability |
| `*forward-problem-historical-count*` | forward-mode problems |
| `*single-literal-problem-historical-count*` | single-literal vs multi |
| `*problem-link-historical-count*`, plus `*structural-link-*`, `*content-link-*`, `*removal-link-*`, `*transformation-link-*` | by link type |
| `*dependent-link-historical-count*` | dependent link total |
| `*single-literal-problem-dependent-link-historical-count*` | single-literal dependents |
| `*tactic-historical-count*` | tactics ever created |
| `*executed-tactic-historical-count*`, `*discarded-tactic-historical-count*` | by status |
| `*unification-attempt-historical-count*` | unifications ever attempted |
| `*inference-historical-count*` | inferences ever created |
| `*successful-inference-historical-count*` | inferences that produced ≥1 answer |
| `*proof-historical-count*` | proofs ever derived |

These counters are global — they accumulate across all queries in the image lifetime. Used for image-level health monitoring and for the engine's self-test suites.

`increment-problem-link-type-historical-counts(link-type)` is the canonical fan-out: every link-type increments the family-wide and type-specific counters in one call.

The clean rewrite should keep these as opt-in instrumentation; in production they are inexpensive (atomic-incf) and provide invaluable observability. In a multi-tenant environment they should be per-image and exposed via a metrics endpoint.

## PAD data

`inference-pad-data.lisp` is purely *empirical timing data* — a deflexical of the times-to-first-answer measured on a reference machine. `*non-tkb-final-times-to-first-answer*` is a long sorted list of doubles; `*non-tkb-final-bogomips*` records the reference machine's bogomips so timings can be normalised to the running machine.

`*non-tkb-final-bogomips*` was 4154.98d0 on the reference machine. The PAD ("probably approximately done") computation uses these timings to estimate "if we haven't found an answer in T seconds, the inference has empirically run X% beyond its expected time-to-first-answer."

The clean rewrite can keep this list, replace it with a regenerated dataset, or remove the empirical PAD entirely (in which case `:probably-approximately-done` would be a no-op). The empirical data is a port-time artifact, not a load-bearing design decision.

## Strategic heuristics

`inference-strategic-heuristics.lisp` — pluggable scoring functions that contribute to the heuristic-balanced tactician's happiness computation (see "Strategist & tacticians" doc).

### The heuristic record

A heuristic registration is a 5-element list `(function scaling-factor pretty-name comment tactic-type)` stored in `*strategic-heuristic-index*` (eq-hashtable, heuristic → data list).

```lisp
(declare-strategic-heuristic
  :occams-razor
  (list :function 'strategic-heuristic-occams-razor
        :scaling-factor 5
        :pretty-name "Occam's Razor"
        :comment "Prefer shorter proofs"
        :tactic-type :transformation))
```

### The `do-strategic-heuristics` macro

Iterates the index, filters by tactic-type match, and yields each heuristic's function and scaling factor. Used by `heuristic-balanced-strategy-generic-tactic-happiness` to walk all relevant heuristics for a tactic.

### The 12 declared heuristics (from `*heuristic-balanced-tactician-heuristics*`)

| Heuristic | Implementation function |
|---|---|
| `:shallow-and-cheap` | `strategic-heuristic-shallow-and-cheap` — multiply productivity by uselessness-based-on-proof-depth |
| `:completeness` | (inferred) — prefer complete tactics over incomplete |
| `:occams-razor` | (inferred) — prefer shorter proofs |
| `:magic-wand` | (inferred) — boost magic-wand tactics |
| `:backtracking-considered-harmful` | (inferred) — penalize tactics that lead to backtracking |
| `:backchain-required` | (inferred) — favour rules whose predicates are backchain-required |
| `:rule-a-priori-utility` | (inferred) — score rules by their KB-asserted utility |
| `:relevant-term` | (inferred) — boost tactics that mention currently-relevant terms |
| `:rule-historical-utility` | (inferred) — uses the rule statistics table |
| `:literal-count` | (inferred) — penalize multi-literal lookups |
| `:rule-literal-count` | (inferred) — penalize rules with many antecedent literals |
| `:skolem-count` | (inferred) — penalize skolemised forms |

The exact scoring functions are mostly implemented (some `missing-larkc`); each takes `(strategy, tactic)` and returns a happiness in roughly [-100, 100].

`*overriding-strategic-heuristic-scaling-factors*` is a dynamic variable — a plist of overrides that takes precedence over declared scaling factors. Used in tests and tuning.

The clean rewrite should keep heuristics pluggable. They are tunable knobs; users may want to add domain-specific heuristics. The 12-strong default set is the production tuning.

## Lookahead productivity

`inference-lookahead-productivity.lisp` — answer the question "how many results would this problem produce if I solved it?"

`memoized-problem-max-removal-productivity(problem, strategic-context)` is the entry — memoised eq because productivity is stable per problem within an inference.

```
problem-max-removal-productivity(problem, strategic-context):
  let existing-proofs = problem-proof-count(problem)
  let max-productivity = productivity-for-number-of-children(existing-proofs)
  for tactic in problem-relevant-tactics-wrt-removal(problem, strategic-context):
    let lookahead = tactic-max-removal-productivity(tactic, strategic-context)
    max-productivity = max(max-productivity, lookahead)
  return max-productivity
```

`tactic-max-removal-productivity(tactic, strategic-context)` is dispatched by tactic kind:
- **Generalized-removal or rewrite tactic:** the tactic's own original-productivity
- **Logical tactic with unique lookahead:** recurse into the lookahead problem
- **Join tactic:** recurse into both supporting problems and take the max
- **Meta-split tactic:** 0 (deferred decision; productivity unknown until specialised)

This is *lookahead* in the sense that it walks the problem graph forward to estimate productivity from descendants — a key ingredient in the strategist's decision-making. The "shallow-and-cheap" heuristic uses this lookahead value scaled by uselessness-based-on-proof-depth.

## When does each piece fire?

| Operation | Fires when |
|---|---|
| `canonicalize-problem-query(query)` | every `new-problem(store, query)` |
| `inference-canonicalize-ask-memoized` | every `new-cyc-query` (and thus every prepare-inference-hl-query path) |
| `new-cyc-trivial-query-int` | every `new-cyc-query` (before falling through to the full path) |
| Transformation rule statistics update | every successful proof's `perform-inference-answer-proof-analysis` |
| Asked-queries enqueue | `possibly-enqueue-asked-query` on every query the engine accepts |
| `inference-metric-evaluate` | `inference-postprocess` after each suspend, per template entry |
| Historical counters | every entity creation/destruction site |
| Min-transformation-depth propagation | every problem-link creation (via `propagate-problem-link`) |
| Strategic heuristic score | `heuristic-balanced-strategy-generic-tactic-happiness` for every transformation tactic |
| Lookahead productivity | `tactic-strategic-productivity` and the `:shallow-and-cheap` heuristic |

## Cross-system consumers

- **Kernel** (`new-cyc-query`) calls trivial-query and canonicalisation.
- **Strategist** consumes lookahead productivity, strategic heuristics, transformation depth signatures, completeness predicates.
- **Workers** call canonicalisation indirectly through `new-problem`. Productivity computations consume worker-produced links.
- **Removal modules and meta-removal modules** consume completeness utilities (`inference-complete-extent-asserted-gaf`, `…-decidable-gafs`, etc.).
- **Argumentation** reads transformation rule statistics for proof annotation.
- **Inference parameters** — the `:metrics` and Arete metric query properties consume the metric infrastructure.
- **Forward inference** uses dedicated counters (`*forward-problem-store-historical-count*` etc.).
- **CFASL** persists transformation-rule statistics across image saves.

## Notes for the rewrite

- **Canonicalisation and dedup is the foundation of DAG-shaped search.** Without it, the search graph would be a tree and would re-do every common subgoal many times. Keep it.
- **The "awesome" sort matters.** The simple sort would also produce a deterministic order, but it would not factor in fully-fixed-vs-free literal ordering, which affects what subsequent dedup can remove. Don't replace with a naive sort.
- **Trivial-query fast path is forever-on.** The `*new-cyc-trivial-query-enabled?*` flag is documented as "should eventually stay T." Remove it.
- **Empirical PAD data is suspect.** The 1000+ doubles in `inference-pad-data.lisp` are timings from one specific machine. They normalise via bogomips, which is itself a flawed metric. The clean rewrite should regenerate this data on a known-target machine, or replace PAD with a wall-clock estimate (e.g. "if you've spent 5× the median query time without an answer, give up").
- **Transformation rule statistics need a clean persistence story.** The current "experience transcript" file format is mostly missing-larkc. The rewrite should pick a format (CBOR? Protobuf?) and document it.
- **Strategic heuristics should be a typeclass/trait, not a 5-element list.** Each heuristic has `(function, scaling-factor, name, comment, tactic-type)` — that's a struct, not a list. The clean rewrite can use a real type.
- **Min-transformation-depth signatures are subtle.** The `:counterintuitive` vs `:intuitive` mode (for what "depth" means) is a load-bearing decision that affects how the strategist treats nested transformations. Don't break this; the default `:counterintuitive` is what `*transformation-depth-computation*` ships with.
- **Historical counters should be opt-in via a feature flag** for environments where atomic-incf overhead matters (e.g. high-throughput query servers). Default on.
- **HL module expand counts are debug-only.** `*hl-module-expand-counts-enabled?*` defaults nil for a reason — counting every module call is expensive. Keep it that way.
- **The 12 heuristics are an empirical set.** Add new ones rather than changing the existing ones. The scaling factors are tuned together.
- **`magic-wand` heuristic is coupled to `magic-wand-tactic?` in the strategist.** They must be kept in sync. The clean rewrite should consider whether `magic-wand` should be a heuristic (additive contribution) or a hard preference-level boost (categorical).
- **`*overriding-strategic-heuristic-scaling-factors*` is a parameter** so tests can rebind. Keep this.
- **Asked-queries logging is for offline analysis.** The 300-element queue is small; the file format needs to be efficient. Replace the missing-larkc serialiser with CBOR or similar.
- **`inference-completeness-utilities.lisp` is read-only.** It only reads completeness GAFs from the KB; it does not assert them. Some other module (probably `predicate-completeness-tactical.lisp` or similar — TODO check) is the asserter. Keep this read/write split.
