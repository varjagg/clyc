# Specialized inference modes

Four files implement *specialised inference programs* — frameworks layered on top of the basic ask machinery to do something more than answer one query at a time. Each is opt-in, used by tooling rather than by the everyday user query path. Most are mostly missing-larkc in the LarKC port; the design intent is documented well enough that the rewrite can reconstruct from name and surrounding evidence.

| File | Lines | Purpose |
|---|---|---|
| `arete.lisp` | 138 | Experiment harness: run query batches, measure metrics, compare runs, generate analysis reports |
| `leviathan.lisp` | 296 | Larger experiment harness for "haystack" testing: bulk querying with synthetic test corpora, measuring rule utility, automatically retiring inert rules |
| `janus.lisp` | 242 | Inference record-and-replay: log every create/assert/query the system performs, save as a transcript, replay later |
| `collection-intersection.lisp` | 152 | Specialised forward-inference module for `(collectionIntersection)` NARTs — when a NART of two intersecting collections is created, automatically derive the genls/specs links |

These are *not* tactician variants (those are in `inference/harness/`). They are *application-level* tools that use the inference engine to do bulk or specialised work.

## Arete

**The experiment harness for running a batch of queries and analysing aggregate behaviour.**

### Setup constants

- `*arete-experiment-directory* = "/cyc/projects/inference/arete/experiments/"` — where experiment files live
- `*arete-analysis-directory* = "/cyc/projects/inference/arete/analysis/"` — where analysis output goes
- `*arete-outlier-timeout*` — defaults to `*kbq-default-outlier-timeout*` (600 seconds)
- `*kbq-control-query-set-run*` — the baseline run to compare against (`:uninitialized` until set)
- `*arete-log-kb-touches?*` (defparameter, default nil) — when on, every KB access during an experiment is logged into one of three dictionaries (read counts, modification counts, etc.). Used for profiling KB hot spots.

### `run-arete-experiment` macro (TODO in port; design known)

The entry point for running an experiment. Signature reconstructed from Internal Constants:

```lisp
(run-arete-experiment
  &key query-spec-set                                 ; the set of queries to run
       filename                                       ; output filename
       comment
       overriding-query-properties                    ; properties applied to every query
       (metrics '(all-arete-query-metrics))           ; metrics to gather
       (outlier-timeout '*arete-outlier-timeout*)
       incremental                                    ; resume an interrupted run
       (include-results t)                            ; record per-query result data
       (skip 0) count                                 ; subset selection
       (directory *arete-experiment-directory*))
```

The macro ultimately calls `RUN-KBQ-EXPERIMENT`. The experiment runs every query in the set, captures the metrics, writes the per-query record to a CFASL file in the experiment directory.

### Analysis functions (mostly missing-larkc)

A pile of "compare two query-set runs" functions:

| Function | Purpose |
|---|---|
| `kbq-compare-query-set-run-answers-to-control` | Given a run, compare answer sets to `*kbq-control-query-set-run*` |
| `kbq-hybridize-query-set-runs` | Merge results from multiple runs (taking best per query) |
| `kbq-tag-query-set-runs` | Tag each query-run with which run it came from |
| `kbq-better-query-run` | Pick the better of two runs for the same query |
| `kbq-query-run-better?` | Comparison predicate |
| `kbq-query-run-better-per-answer?` | Per-answer comparison |
| `kbq-query-run-better-wrt-time?` | Time-based comparison |
| `kbq-may-have-harmful-side-effects?` | Check whether the query is safe to run |
| `arete-generate-property-correlation-plot` | Render a property-vs-property correlation plot |
| `arete-generate-sorted-property-comparison` | Sort runs by a property and display |

### Reporting

`kbq-save-report`, `kbq-print-report`, `kbq-print-histogram`, `kbq-print-data`, `kbq-print-tuples`, `kbq-print-func-of-tuples` (all missing-larkc) — render the analysis output as text/plot.

### Conses-saved analysis

`assertion-cons-sharing-dictionary`, `conses-saved-and-total-conses`, `nauts-shared-and-unshared` — measure whether the engine is reusing cons cells effectively. Memory profiling.

### Side-effect detection

`query-may-have-harmful-side-effects?`, `sentence-contains-subl-performative?`, `subl-performative-p` — used to filter out queries that would mutate the KB (don't run them in benchmark mode).

### Use case

Arete is what an inference researcher uses when asking "did this engine change make queries faster?" — run the experiment before, run it after, compare. The CFASL persistence is what allows comparison across image restarts.

## Leviathan

**A larger, more featureful experiment harness, oriented toward "haystack" testing.**

A *haystack* is a synthetic KB extension: take the real KB, add N artificial facts (the "haystack"), then test whether queries that depend on a "needle" (a specific fact in the haystack) can find it. Used to measure inference quality independent of KB content noise.

### Setup constants

- `*leviathan-directory* = "/cyc/projects/inference/leviathan/"`
- `*leviathan-experiment-directory*` — derived
- `*leviathan-outlier-timeout*` — same default as Arete
- `*leviathan-crtl-internal-time-units-per-second* = 1000000` — for cross-image timing comparison
- `*standard-leviathan-query-metrics*` — 17 metrics covering answer counts, timings, and per-link-type counts

### `run-leviathan-experiment` macro (TODO in port)

Same shape as `run-arete-experiment` with different defaults:
- `(metrics '(all-leviathan-query-metrics))`
- `(incremental t)` — default to incremental (resume on restart)
- `(include-results nil)` — default to *not* include per-query results (just metrics)

### Haystack management (mostly missing-larkc)

- `save-haystack`, `load-haystack` — persist/restore one haystack
- `load-all-haystacks` — load every haystack
- `cached-load-all-haystacks` (defun-cached pattern) — same with cache
- `make-haystacks-good`, `make-haystacks-crippled` — corrupt/restore haystacks for negative testing
- `reify-all-haystacks` — turn each haystack into a real KB extension
- `haystack-id-string-from-query` — derive an ID from the query

Three haystack categories:
- **plain** — synthetic facts that the original KB doesn't already prove
- **instantiated** — haystacks where the variables are bound to concrete values
- **crippled** — haystacks with key facts missing (negative test cases)

### Rule utility analysis

`*sorted-rule-analyses*` lists the 13 rule categories Leviathan classifies rules into:
- `:sucky-skolem-rule`, `:negative-utility-skolem-rule`, `:sucky-rule`
- `:inert-skolem-rule`, `:never-considered-forward-skolem-rule`, `:never-considered-backward-skolem-rule`
- `:inert-rule`, `:unsuccessful-forward-rule`, `:unsuccessful-backward-rule-with-dependents`
- `:successful-skolem-rule`, `:backward-successful-backward-rule`, `:backward-successful-forward-rule`
- `:successful-forward-rule`, `:other`

After running enough experiments, Leviathan can sort the KB's rules into these buckets and recommend which to retire (the "sucky" and "inert" categories).

`kill-all-skolem-rules`, `kill-all-negative-utility-skolem-rules`, `kill-all-inert-rules`, `kill-all-rules-that-totally-suck` — automated rule deletion based on the analysis. Dangerous; used during KB cleanup passes.

### Justified-query rule allowlist

`assert-allowed-rules-for-justified-queries`, `allowed-rules-utilities`, `skolem-rules-used-in-justified-queries` — for each successfully-answered query, record which rules contributed. Used to derive a per-query `:allowed-rules` whitelist for reproducibility.

### Conditional-query analysis

`conditional-queries`, `queries-that-probably-ought-to-be-conditional`, `fix-queries-that-probably-ought-to-be-conditional` — find queries that should be `:conditional-sentence?` but aren't.

### Rule-bindings WFF cache

`*rule-bindings-wff-table*`, `rule-bindings-wff-cached?`, `initialize-rule-bindings-wff-table`, `rule-bindings-wff-analysis` — cache of "is this rule's bindings well-formed?" Pre-compute the WFF check to avoid running it during every transformation tactic.

`*rule-bindings-to-closed-wff-pruning-enabled?*` (defparameter, default nil) — when on, prune transformation tactics whose closed-form rule bindings are not WFF.

### Use case

Leviathan is what KB engineers use to evaluate whether a KB change improves inference. Run on the old KB, run on the new KB, compare — and identify rules that are dead weight (never fire) or harmful (fire often but never lead to success).

## Janus

**Inference record-and-replay framework.**

Logs every create/assert/query operation the system performs, persists as a transcript, and can be replayed later (in the same or different image) to verify reproducibility.

The file is mostly stripped — the design is documented but the bodies are mostly missing-larkc.

### Operation types

Janus distinguishes four operation types:
- `janus-create-operation-p` — a constant was created
- `janus-assert-operation-p` — an assertion was added
- `janus-query-operation-p` — a query was run
- `janus-modification-operation-p` — KB modification (catchall)

For each type there's a constructor (`new-janus-create-op`, `new-janus-assert-op`, `new-janus-query-op`) that produces a structured log record.

### Per-op slot accessors

For each op type there are accessors for its fields:
- `janus-create-op-name`, `janus-create-op-external-id`, `janus-create-op-tag`
- `janus-assert-op-sentence`, `janus-assert-op-mt`, `janus-assert-op-strength`, `janus-assert-op-direction`, `janus-assert-op-expected-deduce-specs`, `janus-assert-op-allowed-rules`, `janus-assert-op-tag`
- `janus-query-op-sentence`, `janus-query-op-mt`, `janus-query-op-query-properties`, `janus-query-op-expected-result`, `janus-query-op-expected-halt-reason`, `janus-query-op-tag`

### Log capture hooks

`janus-note-create-finished(new-constant)`, `janus-note-assert-finished(sentence, mt, strength, direction, deduce-specs)`, `janus-note-query-finished(sentence, mt, query-properties, result, halt-reason)` are the hooks called from the kernel/KB layer. Each:
1. Checks `*janus-test-case-logging?*` and `*janus-within-something?*`
2. Validates the operation arguments (rejects on invalid constants/assertions)
3. Constructs the operation record and conses it onto `*janus-operations*`

`*janus-tag*` is a per-thread tag attached to operations for grouping (e.g. all operations from one test case share a tag).

`*janus-new-constants*` accumulates the list of constants created during a logged session — useful for replay (the replay first creates these, then asserts/queries reference them).

The kernel calls `janus-note-query-finished` from `new-cyc-query` (see kernel doc). The corresponding `janus-note-assert-finished` is called from KB write paths; `janus-note-create-finished` is called from `cyc-create-new-ephemeral` and `ke-create-now`.

### Transcript persistence

- `save-janus-transcript(arg1, arg2, &optional arg3)` — write to disk
- `load-janus-transcript(filename)` — read back
- `janus-transcript-full-filename(filename)` — resolve to absolute path

The transcript format is binary CFASL.

### `janus-dwim-*` (DWIM = "do what I mean")

`janus-dwim-constant`, `janus-dwim-expression` — when replaying in a new image, the original constant might have a different SUID. DWIM resolves an external-id to whatever local constant has that external-id, so the replay rebinds appropriately.

`janus-new-constant?`, `janus-dwimmed-constant-id`, `janus-dwimmed-constant?` — predicates for tracking which constants are created/replayed/dwimmed.

### Use case

Janus is what regression testing uses to capture engine behaviour. A unit test sets up state, makes assertions, runs queries — Janus records the entire sequence. The recorded transcript becomes a reproducible test artifact: when the engine changes, replay the transcript and compare the outputs. Differences indicate behavioural changes (intended or otherwise).

The Cyc readme says Janus is "Not included" — the framework is here but the production tooling that drives it is not. The clean rewrite needs to decide whether to keep Janus (useful for regression testing) or replace with a different test-capture mechanism.

## Collection-intersection

**Forward-inference specialisation for `(collectionIntersection)` NARTs.**

The collectionIntersection function takes a list of collections and returns their intersection: `(collectionIntersection (list Cat Pet))` is the collection of cats that are pets. When such a NART is created, the engine should automatically:
1. Add genls links from the intersection to each constituent collection
2. Add specs links from the intersection to anything that's a spec of all constituents

This file is the after-adding hook that does that work.

### Configuration

- `*collection-intersection-genls-support-enabled?*` (defparameter, default nil) — master switch
- `*nart-indexing-bug-workaround-enabled?*` (defparameter, default nil) — historical workaround for a NART indexing bug, now fixed in current Cyc

### `genls-collection-intersection-after-adding-int(gaf)`

The active function. Triggered when a new `(genls A B)` GAF is added:
1. Get all specs of A and all genls of B
2. Find candidate spec-NARTs and genl-NARTs (NARTs that have these collections as constituents)
3. For each candidate-genl-NART, propagate the genls link

The body has 3-4 missing-larkc calls — the inner loops that do the actual NART-graph traversal and link assertion are stripped. The shape is documented; the rewrite must reconstruct.

### `cyc-collection-intersection-after-adding(hl-module, gaf)` (missing-larkc)

The HL-module callback that fires after a `(collectionIntersection)` NART is created. Calls `genls-collection-intersection-after-adding-int` and the related specs version.

### The two rules

`*collection-intersection-genls-rule*` and `*collection-intersection-specs-rule*` are the canonical implication rules that justify the derived links:

```
(implies
  (and (collectionIntersection ?SPEC ?SPEC-COLS)
       (collectionIntersection ?GENL ?GENL-COLS)
       (forAll ?GENL-CONSTIT
         (implies (elementOf ?GENL-CONSTIT ?GENL-COLS)
                  (thereExists ?SPEC-CONSTIT
                    (and (elementOf ?SPEC-CONSTIT ?SPEC-COLS)
                         (genls ?SPEC-CONSTIT ?GENL-CONSTIT))))))
  (genls ?SPEC ?GENL))
```

In English: if every constituent collection of GENL has a sub-constituent in SPEC, then SPEC genls GENL. The rule is canonical CycL; it serves as the *justification* for the derived genls link (the link's HL support points at this rule).

`*collection-intersection-defining-mt* = #$UniversalVocabularyMt` — where the rules and constituents are defined.

### Why a special module?

A regular forward rule that derives genls from collection-intersection would have to:
1. Match every `(collectionIntersection ?X ?CS)` GAF
2. For each, scan every other `(collectionIntersection ?Y ?DS)` GAF
3. Check the universal-quantifier subgoal

That's `O(N²)` per GAF added. The specialised module short-circuits: when one GAF arrives, it directly walks the NART index for the affected collections and writes the derived links — `O(N)` per GAF.

The clean rewrite should keep collection-intersection as a specialised module. It is one of the few places where a forward-rule-of-the-form-X specialisation justifies the complexity.

### Registration

```lisp
(register-kb-function 'cyc-collection-intersection-after-adding)
(register-kb-function 'cyc-collection-intersection-2-after-adding)
```

These register the after-adding callbacks with the KB write hook system (see "Forward propagation" doc in `kb-access/`).

## Cross-system consumers

- **Arete and Leviathan** consume `kbq-query-run` (test infrastructure) and `inference-parameters` (metrics).
- **Janus** is wired into the kernel via `janus-note-query-finished` from `new-cyc-query`. KB write paths call `janus-note-assert-finished` and `janus-note-create-finished`.
- **Collection-intersection** is registered via `register-kb-function` and invoked by the after-adding pipeline when relevant GAFs are added.

## Notes for the rewrite

### Arete

- **The harness is mostly missing-larkc.** The design is well-documented; the rewrite must reconstruct from the function names and surrounding evidence.
- **Run-experiment macro** — keep the keyword-argument shape; it's well-designed for batch experiment workflows.
- **Cons sharing analysis** — the "are we reusing memory?" check is useful but expensive. Make it opt-in via a property.
- **Side-effect detection** matters for benchmark integrity. Don't skip it; queries with side effects will pollute the comparison.

### Leviathan

- **Haystack testing is the gold standard for inference evaluation.** Don't drop it; the synthetic-corpus methodology is what produces reproducible quality measurements.
- **The 13-category rule classification** (`*sorted-rule-analyses*`) is empirical taxonomy. Keep it; the categories are the vocabulary KB engineers use to talk about rule quality.
- **`kill-all-*-rules` are dangerous.** Wrap them in a confirmation prompt; never run unattended.
- **Rule-bindings WFF caching** is a real optimisation. If you can prove a rule's bindings are always (or never) WFF, the engine can skip the runtime WFF check.

### Janus

- **The capture API is well-designed** — three op types (create/assert/query), each with a constructor and accessors. Keep this shape.
- **Dwimming via external-id** is what makes cross-image replay work. Implement the external-id machinery if not present.
- **`*janus-operations*` is a global accumulator.** Make it per-thread or per-test in the rewrite.
- **The replay engine is missing.** The capture side is documented; the replay side needs to be built. Replay = walk the operation list, perform each, compare outputs to expected.
- **Janus is the inference test framework.** Without it, regression testing is per-test ad-hoc. Build it.

### Collection-intersection

- **Specialised modules are justified for high-frequency operations.** Don't use them gratuitously; collection-intersection's NART rate justifies the optimisation.
- **The two rules** (`*collection-intersection-genls-rule*`, `*collection-intersection-specs-rule*`) are the *justification* the derived links carry. Don't skip recording them; without the rules, the derived links can't be explained to the user.
- **`*collection-intersection-genls-support-enabled?*`** is opt-in. Default off because the optimisation is only valuable when the KB has many `(collectionIntersection)` NARTs.
- **`*nart-indexing-bug-workaround-enabled?*`** is dead weight. Remove it; the bug is fixed.
- **The after-adding hook is the integration point.** Keep this; it's how specialised forward inference is dispatched.
