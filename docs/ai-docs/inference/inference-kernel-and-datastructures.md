# Inference kernel and core datastructures

The inference *harness* is the engine layer that turns a user query into a set of answers. It sits below `ask-utilities` and above the workers and HL modules. Nothing in this document is module-specific or strategy-specific — those are separate docs. This doc covers the **engine bookkeeping**: the objects used to track an in-flight inference, the search graph it builds, the per-search-node tactics it considers, the proofs it derives, and the answers it accumulates.

The kernel itself (`inference/harness/inference-kernel.lisp`) is small — fewer than 400 lines. It is the thin entry-point function `new-cyc-query` plus its DNF variant, the post-processing that turns answers into a user-facing result, and a couple of plumbing helpers. Almost all the substance is in the datastructures.

Source files:
- `inference/harness/inference-kernel.lisp`
- `inference/harness/inference-datastructures-inference.lisp`
- `inference/harness/inference-datastructures-problem-store.lisp`
- `inference/harness/inference-datastructures-problem.lisp`
- `inference/harness/inference-datastructures-problem-query.lisp`
- `inference/harness/inference-datastructures-problem-link.lisp`
- `inference/harness/inference-datastructures-proof.lisp`
- `inference/harness/inference-datastructures-tactic.lisp`
- `inference/harness/inference-datastructures-strategy.lisp`
- `inference/harness/inference-datastructures-forward-propagate.lisp`
- `inference/harness/inference-datastructures-enumerated-types.lisp`
- `inference/harness/inference-macros.lisp`

## Conceptual model

A single user query is represented at runtime by an **inference** object. The inference owns a **problem store** — a workspace that holds every problem (search-graph node), link (search-graph edge), proof, strategy, and inference within the scope of this query. (Problem stores can be shared across multiple inferences; in that case the store outlives any single inference.)

Inside the store, the search graph is built up bottom-up:

- A **problem** represents a goal to prove: a contextualized DNF clause set (a problem-query) the engine wants to satisfy. Problems are deduplicated within the store by their query (subject to the store's equality-reasoning method), so the same goal is only considered once.
- A **problem-link** is a directed edge between problems. Each link has a *type* (`:removal`, `:transformation`, `:rewrite`, `:join-ordered`, `:join`, `:split`, `:union`, `:restriction`, `:residual-transformation`, `:answer`, `:disjunctive-assumption`, `:indirection`) corresponding to the inference step that would justify the supported problem from one or more supporting problems. Links are the edges of the proof DAG-in-progress.
- A **tactic** is a candidate inference step *attached to a problem*: an `(hl-module, problem)` binding that, if executed, would produce one or more new problem-links and possibly child problems. A problem accumulates many tactics over its lifetime; the strategy chooses which to actually fire.
- A **proof** is a derivation: a problem-link plus subproofs and a binding. Proofs are what get turned into inference answers when they reach the root.
- A **strategy** is a controller attached to the inference that decides which problems are active vs. set-aside, which tactics to execute next, and which proofs satisfy the user's `:proof-spec`.
- An **inference-answer** is an entry in the answer index (one per unique binding-vector under `equal`); each answer accumulates a list of justifications, each backed by one or more proofs.

A single problem store can host many concurrent inferences over the same workspace — useful for sharing memoization, sharing already-explored subproblems, and for browsable/continuable inferences.

## When does each entity get created?

The triggers for creation are the heart of the design. They are arranged here in the order they fire during a fresh query.

### When is a problem store created?
1. **Default path: a new query is launched without a `:problem-store` property.** `new-cyc-query` synthesises a private store via `problem-store-from-properties` → `new-problem-store`, owned by this inference and destroyed when the inference finishes (unless `:browsable?`). This is the common case: each query is its own workspace.
2. **Caller passes `:problem-store` in query-properties.** Multiple sequential queries can share a store — useful for browsable inferences continued via `continue-inference`, and for sharing the SBHL resource space and memoization tables across logically-related queries. The store is then *not* destroyed when the inference ends; the caller must `destroy-problem-store` it.
3. **Test harness / KB-content tests / evaluation harness** create stores explicitly via `with-new-problem-store` to scope a batch of inferences.

A store is *destroyed* when its lifetime ends per (1) — or when the user explicitly calls `destroy-problem-store`. `destroy-all-problem-stores` exists for image teardown.

### When is an inference created?
Always exactly once per query, at the start. `new-cyc-query` calls `new-continuable-inference-int` (or `…-from-dnf-int`) which calls `simplest-inference-prepare-new`, which mints a fresh inference attached to the store. Ditto for `new-cyc-query-from-dnf` (skips canonicalization) and the trivially-true/trivially-false fast path (`new-cyc-trivial-query-int`) — that fast path can return *without* minting an inference at all if the query is recognised as a tautology, contradiction, or ill-formed.

Inferences are also created indirectly when the **user supplies an existing inference and calls `continue-inference`**: no new inference is minted; the existing one's status moves from `:suspended` back to `:running` and the answer-id-start cursor is reset so the next pull only delivers fresh answers.

An inference is *destroyed* either at the end of `new-cyc-query` (non-browsable case) or when the caller explicitly calls `destroy-inference` on a browsable one. Destruction sets every slot to `:free` and removes the inference from its store; then unless the store is shared, the store is destroyed too.

### When is a problem created?
Problems are minted by `new-problem(store, query)`. The triggers are:
1. **Root problem:** `simplest-inference-prepare-new` constructs one or two root problems for the inference (the explanatory and non-explanatory subqueries, when distinct). This is the entry point of the search.
2. **Tactic execution creates children.** When a worker fires a tactic for a parent problem and the tactic introduces sub-goals, each sub-goal becomes a new problem (or, by the deduplication rule, finds an existing one). This is the dominant source of problems.
3. **Problem-store equality reasoning may *avoid* creation.** If the store's `equality-reasoning-method` matches an existing problem's query (`:equal` for raw equality, `:czer-equal` for canonicalisation-equality), `new-problem` is *not* called — instead the existing problem is reused. This is what makes the search a DAG rather than a tree.
4. **Forward-inference propagation** (when a new assertion is being propagated) constructs a problem to evaluate the rule's conclusion against the new fact. This is rarer than backward-inference creation.

A problem is *destroyed* only when its containing store is destroyed; problems are never individually torn down during a live inference.

### When is a problem-link created?
A problem-link is the result of *executing* a tactic (or, for `:answer` links, registering an answer at the root). Concretely:
- **Worker fires a tactic on a problem.** Each worker (`inference-worker-removal`, `…-transformation`, `…-rewrite`, `…-split`, `…-join`, `…-join-ordered`, `…-restriction`, `…-union`, `…-residual-transformation`) constructs the appropriate `:type` of link via `new-problem-link`, attaches it as an *argument-link* of the problem (the problem this link supports) and as a *dependent-link* of every supporting problem (the problems whose answers feed into the link).
- **Answer registration.** When a proof reaches the root and produces a binding, `new-answer-link` creates a `:type :answer` link whose supported-object is the inference itself rather than another problem. This is how the inference's results get tied back to their derivation graph.

Links are *destroyed* when their containing store/inference is torn down; `destroy-problem-link` runs the per-type cleanup (most paths are `missing-larkc` in the LarKC port — the real engine has more elaborate per-type cleanup that the clean rewrite must reimplement, including detaching back-pointers and disposing data slot contents for residual-transformation, restriction, join-ordered, join, split, and union links).

### When is a tactic created?
A tactic is a *candidate* link, not an executed one. Candidate generation happens in two situations:
1. **A problem becomes motivated.** The strategist examines the problem's query, asks the HL-module-store which modules are applicable to each literal (or to the multi-literal clause), and for each match calls `new-tactic(problem, hl-module)`. Most tactics are minted at this moment, with status `:possible`.
2. **A meta-removal tactic introduces secondary tactics.** Meta-removal modules can synthesise new tactics on the fly, also via `new-tactic`.

A tactic is *executed* when the strategy picks it; execution moves its status from `:possible` to `:executed` and produces one or more problem-links. Tactics are never literally destroyed mid-inference, but `destroy-problem-tactic` is the cleanup path used when the store is torn down. Tactics whose productivity is rejected (above `productivity-limit`) get status `:discarded`.

### When is a proof created?
1. **Worker output.** When a worker has computed a derivation step (e.g. removal-worker confirmed an HL fact, transformation-worker chained a rule), it calls `new-proof-with-bindings(link, bindings, subproofs)`. The proof is registered with both the supported problem and the store.
2. **Answer-link registration.** When subproofs propagate up and bind variables in a way that completes the root query, the resulting proof is the one that becomes (or is attached to) an inference-answer-justification.

Proofs are deduplicated through the `proof-bindings-index` on each problem (key = bindings vector). The store also tracks rejected and processed proofs to avoid revisiting the same derivation.

### When is an inference-answer created?
Always via `find-or-create-inference-answer(inference, bindings)` — keyed on the binding vector under `equal`. Bindings already seen are returned; truly new ones are minted with `new-inference-answer`, which also kicks the answer-id-index forward and signals via `possibly-signal-new-inference-answer` (so user code waiting on `:max-number` can be released).

Each answer can collect multiple `inference-answer-justification` records (one per distinct supports list). Justifications are likewise deduplicated under `justification-equal`. A justification accumulates the proofs that produced its supports.

### What does *not* trigger creation
- **Backward queries do not create deductions.** A *deduction* in Cyc is a saved KB inference (it lives in the deduction-handles space and is asserted into the KB); inference answers are an in-memory artifact of running the harness. When you ask a query and get answers, no deduction objects are minted unless TMS is being used to record the proof and the inference is being executed in an asserting mode (e.g. forward propagation creating new assertions). The clean rewrite needs to remember this: the inference proof DAG is *not* the same thing as the KB's deduction graph, even though both record "this assertion follows from those assertions."
- **Reading a problem store back from CFASL does not create a fresh inference.** It reconstructs the existing one, restoring suid identity. The kernel does not have a "load query" entry point distinct from "create query." Browsability across image saves is therefore a property the store layer must implement, not the inference layer.

## The kernel: `new-cyc-query`

The kernel is one big function (`new-cyc-query` in `inference-kernel.lisp`), broken into five logical steps. Mostly bookkeeping, mostly delegating.

```
new-cyc-query(sentence, mt, query-properties)
 │
 ├─ Start resource tracking (CPU time, real time)
 │
 ├─ Try the trivial-query fast path:
 │     new-cyc-trivial-query-int(sentence, mt, query-properties)
 │     ↳ may return halt-reason :tautology / :contradiction / :ill-formed,
 │       skipping the rest of the pipeline; or :non-trivial to fall through
 │
 ├─ If non-trivial:
 │   ├─ Split query-properties into:
 │   │     static-properties — required at creation, immutable while suspended
 │   │     dynamic-properties — may change between suspends
 │   ├─ explicify-inference-mode-defaults — replaces :inference-mode with
 │   │     concrete property values (see "Inference parameters" doc)
 │   ├─ new-continuable-inference-int(…) → mints inference and root problem(s)
 │   ├─ set-inference-input-query-properties — records what the user asked for,
 │   │     verbatim (so it can be re-used on continue-inference with a different
 │   │     inference-mode and merged sensibly)
 │   ├─ possibly-set-kbq-runstate-inference — KBQ test-suite plumbing
 │   └─ new-cyc-query-int — runs the inference body
 │
 ├─ janus-note-query-finished — Janus is the missing-larkc record-and-replay
 │     framework for inference; the clean rewrite may or may not include it
 │
 ├─ Compute timing-info, fold into metrics
 │
 └─ values: result, halt-reason, inference (or nil), metrics
```

`new-cyc-query-int` is mostly accounting: extract dynamic properties; decide if the problem store is private and should be destroyed at the end; decide if the inference is browsable and should be returned to the user. Then dispatch:
- continuable inference → `continue-inference-int` (the run loop, see "Strategist & tacticians")
- non-continuable inference → `missing-larkc 36247` (the real engine has a code path for one-shot non-continuable execution; clean rewrite must implement it, but it is a strict subset of `continue-inference-int` followed by an immediate destroy)

After the run, `inference-postprocess` extracts the answers, computes metrics, and converts the answers into the user's chosen `:return` format.

### Trivial-query fast path

`*new-cyc-trivial-query-enabled?*` is a flag that defaults to T. When set, every query first tries `new-cyc-trivial-query-int`, which checks for syntactically obvious tautologies/contradictions/ill-formed sentences and returns immediately if one is detected. The flag exists because the original engine evolved this fast path; the comment says "Eventually should stay T." The clean rewrite should make it always-on and remove the flag.

### `:problem-store-private?` plumbing

This boolean threads through the kernel and tells the cleanup path whether to destroy the problem store at the end. It is true iff the user did *not* pass `:problem-store` in the properties. Combined with `:browsable?`, it controls four cases:
- **private + non-browsable:** destroy both inference and store at the end.
- **private + browsable:** destroy nothing; return the inference; user owns the cleanup.
- **shared + non-browsable:** destroy the inference, keep the store.
- **shared + browsable:** keep both.

A `note-problem-store-destruction-imminent` hook fires before destruction so other inferences sharing the store can flush their references.

## Result conversion

`inference-result-from-answers` converts the raw `inference-answer` list into the user's chosen `:return` shape:

| `:return` | Result shape |
|---|---|
| `:answer` | the answer objects themselves |
| `:bindings` | per-answer binding lists (HL or EL per `:answer-language`) |
| `:supports` | per-answer support lists |
| `:bindings-and-supports` | both, in a 2-tuple |
| `:bindings-and-hypothetical-bindings` | bindings plus hypothetical bindings (for conditional queries) |
| arbitrary template | a sexpr containing `:bindings`/`:supports` placeholders that get substituted per answer |

Templates are evaluated by `inference-result-from-answers-via-template`, walking each answer's bindings/justifications and substituting symbolically. The HL→EL conversion (`inference-answer-hl-to-el`) inlines via `assertion-expand` and `nart-expand` so hidden assertion/NART terms become EL-readable formulas.

## Datastructures

### `problem-store` (46 slots)

Conc-name `prob-store-`. The central workspace. Owns the SUID space for problems, links, proofs, strategies, and inferences within its scope.

Key slots:
- **identity** — `guid` (cross-image), `suid` (in-image), `creation-time`, `lock` (a `bt:lock` for thread safety)
- **id-indexes** — `inference-id-index`, `strategy-id-index`, `problem-id-index`, `link-id-index`, `proof-id-index`. All are `id-index` structures (vector + overflow hashtable). The default sizes (`*default-problem-store-problem-size*` = 80, etc.) are tuned for one query's worth of state.
- **deduplication and lookup** — `problem-by-query-index` (hashtable keyed on the contextualized clause; `:empty-domain` if equality reasoning is `:none`); `complex-problem-query-czer-index` and `complex-problem-query-signatures` for canonicalisation-based dedup
- **proof bookkeeping** — `rejected-proofs` (hashtable, eq), `processed-proofs` (set, eq), `non-explanatory-subproofs-possible?` flag plus `non-explanatory-subproofs-index`, `proof-keeping-index`
- **depth tracking** — `min-proof-depth-index`, `min-transformation-depth-index`, `min-transformation-depth-signature-index`, `min-depth-index` (each per-problem)
- **policy switches** — `removal-allowed?`, `transformation-allowed?`, `rewrite-allowed?`, `abduction-allowed?`, `new-terms-allowed?`, `evaluate-subl-allowed?`, `negation-by-failure?`, `completeness-minimization-allowed?`, `add-restriction-layer-of-indirection?`, `compute-answer-justifications?`, `direction` (`:backward` or `:forward`), `equality-reasoning-method` and `equality-reasoning-domain`, `intermediate-step-validation-level`, `max-problem-count`, `crazy-max-problem-count`
- **shared resources** — `memoization-state` (one per store; its lock prevents accidental cross-thread reuse), `sbhl-resource-space` (an isolated pool of SBHL marking space)
- **lifecycle** — `prepared?`, `destruction-imminent?`, `meta-problem-store` (when a meta-store wraps several real stores), `static-properties`, `janitor` (deferred-cleanup queue), `historical-root-problems`, `most-recent-tactic-executed` (a debug crumb)

`*problem-store-id-index*` is the global registry of all live stores. `do-all-problem-stores` iterates them; `find-problem-store-by-id` does the lookup. Stores are `print-object`ed as `#<problem-store SUID>`.

`with-problem-store-lock-held` and `with-problem-store-memoization-state` are the two scoped contexts that worker code uses to operate on the store: the lock guards id allocation; the memoization-state context binds `*memoization-state*` and asserts single-thread ownership.

### `inference` (68 slots)

Conc-name `infrnc-`. The inference object — created once per query (or once and reused for browsable continues). The 68 slots split into roughly five clusters:

**Identity and parent context**
- `suid` — unique within the store
- `problem-store` — back-pointer
- `forward-propagate` — for forward inference; an `forward-propagate` struct (old-queue + new-queue of assertions to push)

**Input** (set once at creation, re-used to recompute on `continue-inference`)
- `input-mt`, `input-el-query`, `input-non-explanatory-el-query`, `input-query-properties`

**Canonicalised query**
- `mt`, `el-query`, `el-bindings`, `hl-query`, `explanatory-subquery`, `non-explanatory-subquery`, `free-hl-vars`, `hypothetical-bindings`

**Answer index**
- `answer-id-index` — id-index of `inference-answer`s
- `answer-bindings-index` — equal-keyed hashtable from binding-vector → answer
- `new-answer-id-start` — cursor: answers ≥ this id are "new since last suspend"
- `new-answer-justifications` — queue of justifications produced since last suspend (so the caller pulling answers gets exactly the new ones)

**Status and orchestration**
- `status` — `:new`, `:prepared`, `:ready`, `:running`, `:suspended`, `:dead`, `:tautology`, `:contradiction`, `:ill-formed`
- `suspend-status` — `:abort`, `:interrupt`, `:max-number`, `:max-time`, `:max-step`, `:max-problem-count`, `:max-proof-count`, `:probably-approximately-done`, `:exhaust`, `:exhaust-total` (or a halt-condition keyword)
- `root-link` — the topmost `:answer` link
- `relevant-problems` — set of problems being worked on for this inference
- `strategy-set` — the strategies running on this inference (usually one)
- `control-process` — the thread executing this inference (for interrupt routing)
- `interrupting-processes` — queue of threads that requested interruption
- `max-transformation-depth-reached` — running maximum

**Static properties** (immutable while suspended; see `*inference-static-properties*`)
- `disjunction-free-el-vars-policy`, `result-uniqueness-criterion`, `allow-hl-predicate-transformation?`, `allow-unbound-predicate-transformation?`, `allow-evaluatable-predicate-transformation?`, `allow-indeterminate-results?`, `allowed-rules`, `forbidden-rules`, `allowed-modules`, `allow-abnormality-checking?`, `transitive-closure-mode`, `problem-store-private?`, `continuable?`, `browsable?`, `return-type`, `answer-language`

**Dynamic properties** (mutable across suspends; see `*inference-resource-constraints*` and `*inference-other-dynamic-properties*`)
- `cache-results?`, `blocking?`, `max-number`, `max-time`, `max-step`, `mode`, `forward-max-time`, `max-proof-depth`, `max-transformation-depth`, `probably-approximately-done`, `metrics-template`

**Time and metrics**
- `start-universal-time`, `start-internal-real-time`, `end-internal-real-time`, `pad-internal-real-time`, `cumulative-time`, `step-count`, `cumulative-step-count`
- `events`, `halt-conditions`, `accumulators` (eq-hashtable for declared metrics)
- `proof-watermark` — counter for proof-id allocation
- `problem-working-time-data` — opt-in working-set timing (see `:maintain-term-working-set?`)

**Type extension**
- `type` (currently only `:simplest`), `data` — for future type-specific extension

`new-inference(store)` allocates with sensible defaults from the `*default-…*` deflexicals. `destroy-inference` unwind-protects the abort, marks `:dead`, destroys all strategies, destroys the root link, removes from store. `destroy-inference-int` then `:free`s every slot. The free pattern (a sentinel value rather than nil) lets `*-invalid-p` predicates detect destroyed objects without ambiguity.

`with-inference-var(var) … destroy-inference-and-problem-store` is the standard scoped wrapper used in tests and one-shot harnesses.

### `problem` (9 slots)

Conc-name `prob-`. A search-graph node.

- `suid` — store-local
- `store` — back-pointer (used to find the right id space, lock, and memoization state)
- `query` — the contextualized DNF clauses (a `problem-query`)
- `status` — see `*problem-status-table*`: a 2-axis state, tactical (`:new`, `:unexamined`, `:examined`, `:possible`, `:pending`, `:finished`) × provability (`:good`, `:neutral`, `:no-good`); 16 product values total
- `dependent-links` — set-contents of links that *depend on* this problem's answers (parent edges)
- `argument-links` — set-contents of links that *support* this problem (child edges)
- `tactics` — list (capped at `*max-problem-tactics*` = 10000) of candidate tactics
- `proof-bindings-index` — equal-hashtable: bindings → proof, deduplicates within the problem
- `argument-link-bindings-index` — equal-hashtable: bindings → argument-link, deduplicates link insertion

The status's two axes mean different things. Tactical status records *how far the inference has gotten* with this problem (have we considered tactics? executed any? exhausted them?). Provability records *what we currently believe* about the problem's answer set (good = at least one proof so far; no-good = proven impossible; neutral = unknown). Both axes evolve independently as the strategy fires tactics and as proofs propagate.

`*generalized-tactic-types*` is a vocabulary of *type specs* that select multiple concrete tactic types: `:non-transformation`, `:generalized-removal`, `:generalized-removal-or-rewrite`, `:connected-conjunction`, `:conjunctive`, `:disjunctive`, `:logical`, `:logical-conjunctive`, `:structural-conjunctive`, `:meta-structural`, `:content`, `:union`, `:split`, `:join-ordered`, `:join`. `tactic-matches-type-spec?` is the dispatch.

### Problem queries (`inference-datastructures-problem-query.lisp`)

Not its own struct — a problem-query is just a list of contextualized DNF clauses (`contextualized-dnf-clauses-p`). Each clause is a `dnf` object whose pos-lits and neg-lits are *contextualized* — each is a `(mt asent)` 2-list (`hl-contextualized-asent-p`). Two macros traverse them:
- `do-contextualized-clauses-literals` — for-each-literal over a problem-query
- `do-problem-query-literals` — alias, called by `do-problem-literals` on a problem

Single-literal queries are common and have helpers (`single-literal-problem-query-p`, `…-sense`, `…-mt`, `…-atomic-sentence`, `…-predicate`, `mt-asent-sense-from-singleton-query`). The strategist checks single-literal-ness early to decide whether to dispatch to literal-level tactics or to multi-literal tactics (split/join).

### `problem-link` (7 slots)

Conc-name `prob-link-`. A directed edge in the proof DAG.

- `suid` — store-local
- `type` — one of `*problem-link-types*`
- `supported-object` — the *parent*: a problem (for most types) or an inference (only for `:answer` links)
- `supporting-mapped-problems` — list of `mapped-problem` records (each = problem + variable-map between the parent's vars and the child's vars)
- `open-flags` — bitfield indicating which supporting positions are still being explored (vs. finalised)
- `data` — type-specific extra data (e.g. for `:residual-transformation`, the leftover sub-clause)
- `proofs` — link-local proof cache (only populated when `*problem-link-datastructure-stores-proofs?*` is T)

The 11 link types correspond to 11 categories of inference step. Each has a worker (see "Workers" doc) that knows how to fire it. The most subtle is `:residual-transformation` — a transformation step that leaves some literals unsolved, which then attaches as a child of a join-ordered link.

`destroy-problem-link` is heavily `missing-larkc` in the LarKC port: each type has its own teardown for its data slot. The clean rewrite must reimplement this per-type, especially for join, join-ordered, split, restriction, and union which all hold structural state.

### `proof` (5 slots)

Conc-name `prf-`. A derivation node.

- `suid`
- `bindings` — variable-bindings under which this proof's link instantiates correctly. Maps the supported-problem's variables to the bound terms for this particular derivation.
- `link` — the supporting link
- `subproofs` — list of proofs of the supporting problems (one per supporting-mapped-problem, in the same order)
- `dependents` — list of proofs that *depend on* this proof (only populated when `*proof-datastructure-stores-dependent-proofs?*` is T; otherwise `do-proof-dependent-proofs` recomputes by walking the problem graph)

Two iteration modes — stored and computed — mirror the problem-link/proofs duality: for low-memory configurations the back-pointers are not stored and are computed on demand.

### `tactic` (11 slots)

Conc-name `tact-`. A candidate inference step.

- `suid` — problem-local (allocated by `problem-next-tactic-suid`)
- `problem` — back-pointer
- `type` — one of `*tactic-types*` (`:removal`, `:meta-removal`, `:transformation`, `:rewrite`, `:structural`, `:removal-conjunctive`); cached, but derivable from `hl-module` via `tactic-type-from-hl-module`
- `hl-module` — the registered HL module the tactic will invoke
- `completeness` — one of `*ordered-completenesses*` (`:impossible`, `:grossly-incomplete`, `:incomplete`, `:complete`); doubles as a preference-level (the `tactic-completeness` accessor un-does the conversion if a preference-level is stored instead)
- `preference-level-justification` — a string explanation
- `productivity` and `original-productivity` — how many results the tactic is estimated to produce; the strategist uses this against `productivity-limit`
- `status` — `:possible`, `:executed`, `:discarded` (or `:free` once destroyed)
- `progress-iterator` — for tactics that yield results incrementally (e.g. iterative-removal); a stateful iterator that persists across executions of the same tactic
- `data` — type-specific extra (rule for transformation tactics, etc.)

Tactics print as `<status TACTIC store.problem.tactic:(type module-name)>` — a useful format string for debugging.

### `strategy` (15 slots)

Conc-name `strat-`. A controller. See "Strategist & tacticians" doc for details. Listed here for completeness:

- `suid`, `inference`
- `result-uniqueness-criterion` — `nil`, `:bindings`, or `:proofs`
- `active-problems`, `motivated-problems`, `set-aside-problems` — the three classes of in-flight problems
- `should-reconsider-set-asides?`, `productivity-limit`, `removal-backtracking-productivity-limit`, `proof-spec`
- `problem-proof-spec-index`, `problem-strategic-index` — per-problem strategy-private data
- `memoization-state` — strategy-private memoization (separate from store memoization)
- `type` — `:removal`, `:balancing` — selects the dispatch table from `*strategy-type-store*`
- `data` — type-specific data

`new-strategy(type, inference)` constructs the strategy, looks up the registered constructor for `type` from `*strategy-type-store*`, and lets it initialize the `data` slot.

### `forward-propagate` (2 slots)

Conc-name `fpmt-`. Used by forward inference to maintain a queue of assertions to propagate. `old-queue` and `new-queue` are the standard double-buffered pattern; `swap-forward-propagate-queues` rotates them. See "Forward propagation" doc for the protocol.

### `inference-answer` (6 slots)

Conc-name `inf-answer-`.

- `suid` — assigned when the answer is registered in the inference's answer-id-index
- `inference` — back-pointer (for `inference-answer-result-bindings` to look up the answer-language)
- `bindings` — the binding vector (the answer's identity for deduplication)
- `justifications` — list of `inference-answer-justification`s (one per distinct support set)
- `elapsed-creation-time` — internal-real-time elapsed since inference start when this answer was created
- `step-count` — cumulative step count of the inference at creation

### `inference-answer-justification` (3 slots)

Conc-name `inf-ans-just-`.

- `answer` — back-pointer
- `supports` — the list of HL supports (assertions / assumptions / module-supports) backing this justification
- `proofs` — list of proofs that produced this support set

A justification is the bridge between the proof DAG (problem-store-internal) and the answer presented to the user (which only mentions assertion-level supports, not the structural tactic links). One answer can have many justifications, one per distinct HL support set.

## Enumerated types reference (`inference-datastructures-enumerated-types.lisp`)

This file is *only* deflexicals — there is no behaviour. It is the dictionary of every keyword vocabulary in the harness:

- **Inference statuses:** `*inference-statuses*` (9), `*continuable-inference-statuses*` (2), `*avoided-inference-reasons*` (5)
- **Suspend statuses:** `*inference-suspend-statuses*` (10), `*continuable-inference-suspend-statuses*` (6), `*exhausted-inference-suspend-statuses*` (2)
- **Problem statuses:** `*tactical-statuses*` (6), `*provability-statuses*` (3), `*problem-status-table*` (16), `*ordered-tactical-statuses*`
- **Tactic types/statuses:** `*tactic-statuses*` (3), `*tactic-types*` (6), `*ordered-completenesses*` (4)
- **Productivity:** `*productivity-to-number-table*` (sparse mapping for converting between productivity reals and integer counts)
- **Inference modes:** `*inference-modes*` (5: `:minimal`, `:shallow`, `:extended`, `:maximal`, `:custom`); `*default-inference-mode*` is `:custom`. See "Inference parameters" doc.
- **Problem link types:** `*problem-link-types*` (11)
- **Problem-store properties:** `*problem-store-static-properties*` (16), `*problem-store-dynamic-properties*` (nil), problem-store-direction, equality reasoning method/domain, validation level, max-problem-count default
- **Inference properties:** `*inference-static-properties*` (17), `*inference-resource-constraints*` (4), `*inference-other-dynamic-properties*` (12), `*inference-meta-properties*` (1)
- **Strategy properties:** `*strategy-static-properties*` (2: `:removal-backtracking-productivity-limit`, `:proof-spec`), `*strategy-dynamic-properties*` (1: `:productivity-limit`)
- **Metrics vocabulary:** `*specially-handled-inference-metrics*`, `*non-inference-query-metrics*`, `*arete-query-metrics*`, `*removal-ask-query-metrics*`

The clean rewrite should keep these as named enums (or sealed sum types) — they appear on countless function signatures and are the public-facing vocabulary.

## Macros that matter

Most of `inference-macros.lisp` and the other datastructure files is iteration-macro reconstruction. Two macros are *control* rather than iteration, and the clean rewrite must preserve their semantics:

- **`within-controlling-inference(inference) … body`** — pushes `inference` onto `*controlling-inferences*` (a per-thread stack); `current-controlling-inference` reads the top. Used so that deep code paths can find the inference they belong to without threading it through every call.
- **`within-controlling-strategy(strategy) … body`** — same idea for `*controlling-strategy*`.

Plus:
- **`with-inference-var(var) … body`** and **`with-problem-store-var(var) … body`** — unwind-protected scoped allocation; mandatory for safe error handling.
- **`do-problem-store-{inferences|strategies|problems|links|proofs}`** — id-index iterators. The clean rewrite should expose these as iterator generics.
- **`do-problem-{argument|dependent}-links`** — set-iterators with optional type filtering.
- **`do-problem-link-supporting-{mapped-problems|problems}`** — walks the bipartite proof-DAG edges.
- **`do-problem-tactics(tactic-var problem &key status completeness preference-level hl-module type productivity)`** — the workhorse: filters tactics by any combination of those keys. The strategist uses this everywhere.

## Cross-system consumers

The kernel is consumed by:
- `inference/ask-utilities.lisp` — `cyc-query` and friends (the user-facing API) all funnel through `new-cyc-query`.
- `inference/inference-trampolines.lisp` — wraps `new-cyc-query` with input-asent-style entry points used by the older API.
- `inference/kbq-query-run.lisp` — KBQ test-suite plumbing, which wants direct kernel access to control how the query is run and where the inference object goes.
- Forward inference / after-adding (`inference/harness/forward.lisp`, `…/after-adding.lisp`) — uses `new-cyc-query-from-dnf` to evaluate forward rules.
- Backward inference (`backward.lisp`) — calls `new-cyc-query` with a specific shape of properties to do classical backchain.
- The browse tools — open an inference handed out via `:browsable?` and call `continue-inference` to extract more answers.
- TVA (`tva-inference.lisp`) — its own caller-protocol on top of the kernel (see "TVA" doc).
- Specialized modes — `arete.lisp`, `leviathan.lisp`, `janus.lisp`, `collection-intersection.lisp` each layer their own protocol on top of `new-cyc-query`. Janus is mostly missing-larkc; its purpose was record-and-replay (see `*janus-within-something?*` in the kernel).

## Notes for the rewrite

- **Free-sentinel pattern.** `:free` rather than `nil` lets the `*-invalid-p` predicates detect destroyed objects unambiguously. The clean rewrite can keep this with a sealed `(or T :free)` slot type, or replace it with a `valid?` flag. The current pattern is verbose but never lies.
- **id-indexes are everywhere.** Each entity type has its own id-index in the store. The clean rewrite probably wants a generic `IdIndex<T>` type — see "ID-index" doc.
- **`missing-larkc` is dense in problem-link destruction.** The destruction protocol is the most under-documented region of the harness. The clean rewrite must define a per-link-type `Drop` (or destructor) that detaches back-pointers, releases per-link state, and notifies dependents. This is described by inversion in the workers: whatever a worker constructs, the destructor must dismantle.
- **Two parallel worlds: storage and computation.** The flags `*problem-link-datastructure-stores-proofs?*` and `*proof-datastructure-stores-dependent-proofs?*` toggle whether back-pointers are stored or recomputed on demand. The clean rewrite should pick one (storing them is faster but uses more memory; the engine's internal default is to *not* store, recomputing through `do-…-computed` macros). Decide once and remove the flag.
- **The kernel is small; the action is in the workers and strategist.** Don't bloat the kernel. Almost everything `new-cyc-query` does is splice properties, mint structures, run, and dispose. Keep it that way; resist the temptation to inline strategy logic.
- **Trivial-query fast path is a forever-on optimisation.** The flag should go.
- **Inference vs. deduction is a hard line.** Inference produces in-memory answers. Deductions are KB facts. The clean rewrite must not let workers create deductions as a side effect of a backward query — that conflation is one of the historical sources of confusion. Forward propagation creates deductions; backward query does not.
