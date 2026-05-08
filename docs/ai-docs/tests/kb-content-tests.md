# KB Content Tests (KCT) and the ctest repository

A **KB Content Test** (KCT) is a Cyc test whose definition lives **as KB assertions**, not as Lisp source. Every other test type ([test-case-tables.md](test-case-tables.md), [inference-tests.md](inference-tests.md)) is defined by a `define-*-test` macro in a `.lisp` file; KCT is defined by `(#$testQuerySpecification ...)` and friends in the KB itself, and discovered at run time by walking the KB. This puts test maintenance in the same workflow as KB maintenance — Cyclists can author, modify, and tag tests without touching source.

The implementation is `cyc-testing/ctest-utils.lisp` (the **ctest infrastructure**: SQL schema constants, default-value defaults, helpers) and `cyc-testing/kb-content-test/kct-utils.lisp` (the KCT-specific layer that builds on ctest). Almost every function in both files is `missing-larkc`-stubbed in the LarKC port — the runtime that actually loads tests from KB and writes results to a database is absent. The constants, defaults, and initialization functions remain, which together define the *vocabulary* of the system even where the bodies are gone.

A clean rewrite has three real choices: (1) reimplement the SDBC-backed reporting (probably overkill), (2) drop the SDBC layer and run KCTs in-process with results going to stdout/JSON like other tests, or (3) drop KCT entirely in favor of test-case tables that load KB content via `assert` forms. This doc captures what the system *was* so a clean rewrite can pick deliberately.

## Conceptual model

A KCT is a **query whose answers are the test assertion**. Three execution modes (constants `*sampling-execution-mode*`, `*hypothesize-execution-mode*`, `*simple-execution-mode*`):

| Mode | Constant | When the query has form... | Run by... |
|---|---|---|---|
| `:sampling` | `"S"` | `(implies LHS RHS)` | finding existing KB objects that satisfy LHS, substituting into RHS, querying the substituted RHS |
| `:hypothesize` | `"H"` | `(implies LHS RHS)` | hypothesizing terms to satisfy LHS, substituting into RHS, querying the substituted RHS |
| `:simple` | `"X"` | non-implication | querying the formula directly |

This taxonomy is for *implication-shaped* tests — the most natural KB-test form is "for any X satisfying P, does Q hold?" — and the mode controls how X gets bound. The simple mode is the escape hatch for non-implication queries.

Alongside the query, a test can declare:

- **Exact / wanted / unwanted / unimportant binding sets** — answers the test must return, may return, must not return, and is indifferent to. (Constants `*kct-exact-binding-set-designation*` "E", `*kct-wanted-binding-set-designation*` "W", `*kct-unwanted-binding-set-designation*` "N", `*kct-unimportant-binding-set-designation*` "U".)
- **Wanted / unwanted modules and supports** — which inference modules and assertions the test expects to (or expects not to) appear in the answer's justification. (Module support type "M", support support type "S"; designations "W"/"N".)
- **Inference parameters** — overrides for the ASK call.
- **Metrics** — collection-, query-, or binding-level metrics to gather. (Constants `*ctest-collection-level-metric*` "C", `*ctest-query-level-metric*` "Q", `*ctest-binding-level-metric*` "B".)
- **Genls / isas** — KB classification of the test itself, so tests can be grouped without a Lisp-side `:classes` keyword.
- **Responsible cyclists, comments, dependencies** — metadata.

A **KCT collection** is a group of tests, runnable as a unit. Two collection types: `*collection-test-collection-type*` "C" (a normal collection of tests) and `*system-test-collection-type*` "S" (a system-wide grab-bag).

The infrastructure for all of this — the inverted indexes "which tests have wanted module X", "which tests are part of collection Y" — is `missing-larkc` in the port. The constants and table names that define it are intact.

## The ctest layer (`ctest-utils.lisp`)

The ctest layer is **shared between KCT and a planned (but never finished) test framework that wrote results to a SQL database**. Most constants here are SQL table and column names, with field-length maxima.

### SQL schema constants

The Cyc Test Repository was a relational database (likely Oracle, given Cycorp's history) with these tables:

| Constant | Table |
|---|---|
| `*csc-table-name*` "cyc_system_config" | One row per Cyc system being tested (image type, version, KB number) |
| `*mc-table-name*` "machine_config" | Machine identity (name, type, OS) |
| `*te-table-name*` "test_execution" | One row per test run |
| `*tem-table-name*` "test_execution_member" | Tests-in-this-execution join table |
| `*tcmr-table-name*` "test_collection_metric_result" | Per-collection per-metric results |
| `*tmr-table-name*` "test_metric_result" | Per-test per-metric results |
| `*kcte-table-name*` "kct_execution" | KCT-specific run record |
| `*kctem-table-name*` "kct_execution_member" | KCT-execution / test-member join |
| `*kctc-table-name*` "kct_config" | KCT configuration (one row per test) |
| `*kctcc-table-name*` "kct_collection_config" | Collection-level config |
| `*tcrc-table-name*` "test_cyclist_responsible_config" | Cyclist-responsibility mapping |
| `*kctccbs-table-name*` "kct_config_cycl_binding_set" | Per-test binding-set declarations |
| `*kctcas-table-name*` "kct_config_answer_support" | Per-test answer-support declarations |
| `*ipc-table-name*` "inference_param_config" | Inference parameter configurations |
| `*tmc-table-name*` "test_metric_config" | Test-metric configurations |
| `*tdc-table-name*` "test_dependency_config" | Test dependency declarations |
| `*kctcg-table-name*` "kct_config_genls" | Per-test genls declarations |
| `*kctci-table-name*` "kct_config_isas" | Per-test isa declarations |

Each table has a max-field-length suite (`*max-test-id-len*` 100, `*max-machine-name-len*` 100, etc.) — the SDBC interface needs these because Oracle column widths are part of the schema and string truncation has to happen client-side. `*ctest-field-maxima*` is the master alist mapping column name to length.

`*ctest-field-maxima*` is consulted by `ctest-truncate-value-for-field` (LarKC-stripped) before any SDBC insert — the truncation is *silent* when the value is too long. A clean rewrite either uses TEXT/CLOB columns and drops the truncation, or makes truncation explicit and warned.

### Status and type vocabularies

| Constant | Allowed values | Used for |
|---|---|---|
| `*ctest-test-types*` | `("KBCONTENT")` | Type column of test_execution table. Only KCT is currently a recognized test type at this layer — the rest of the test taxonomy never made it into the SDBC layer. |
| `*ctest-test-statuses*` | `("SUCCESS" "FAILURE" "DFAILURE" "ERROR" "SKIPPED" "PROBLEM")` | Status column. Maps loosely onto `*cyc-test-result-values*`: SUCCESS↔`:success`, FAILURE↔`:failure`, DFAILURE is "deferred failure" (regression), ERROR↔`:error`, SKIPPED↔`:not-run`, PROBLEM is a meta-failure (problem with running the test, not the test itself). |
| `*ctest-output-formats*` | `(:text :html)` | Report output formats. |
| `*ctest-output-styles*` | `(:brief :verbose :post-build)` | Verbosity flavors for reports. |
| `*ctest-metric-types*` | `("C" "Q" "B")` | Collection-level / query-level / binding-level. |
| `*ctest-support-types*` | `("M" "S")` | Module-support / source-support. |
| `*ctest-support-designations*` | `("W" "N")` | Wanted / unwanted. |
| `*kct-binding-set-designations*` | `("E" "W" "N" "U")` | Exact / wanted / unwanted / unimportant. |

Per-status convenience constants exist for each status string (`*ctest-success-status*`, `*ctest-failure-status*`, etc.) — these are the symbolic forms callers use to avoid re-typing the strings.

`*max-test-retry-time*` = 60 — seconds before a hung test is killed. Only relevant when SDBC is talking to a remote test runner, not in-process.

### Default test parameters

`initialize-ctest` is the **only function with a body** in `ctest-utils.lisp`. It populates a suite of `*default-*` defglobals from the KB:

| Variable | Populated from |
|---|---|
| `*default-email-notify-style-id*` | `(constant-external-id #$TestResultNotification-EmailBrief)` as string — GUID for notifying test failures by email. |
| `*default-test-id*` | GUID of `#$TKBTemplateTestForMissingMt` — the canonical "test that checks for missing-MT issues". |
| `*default-string-binding-set*` | `"(#$TheSet (#$ELInferenceBindingFn ?SOMETHING \"A SOMETHING\"))"` — the canonical binding-set string. |
| `*default-binding-set*`, `-2*` | `(make-kb-binding-set ...)` from `?SOMETHING`/`?OTHERTHING`. |
| `*default-set-of-binding-sets*`, `-2*`, `-3*` | Triple-nested binding sets used as test fodder. |
| `*default-module-sentence*` | `(genls Collection Thing)` — the canonical "trivially true" sentence. |
| `*default-module-mt*`, `-2*` | `#$BaseKB`, `#$UniversalVocabularyMt`. |
| `*default-dependency-test-id*`, `-2*` | GUIDs of `#$TKBTemplateTestForMissingExplanation` / `-Example`. |
| `*default-isa-id*`, `-2*` | GUIDs of `#$TKBTemplateIntegrityTest` / `#$TKB-RTVQueries`. |
| `*default-test-query*` | `(genls Collection ?WHAT)` — the canonical query template. |
| `*default-test-mt*` | `#$BaseKB`. |
| `*default-collection-id*` | GUID of `#$TKBTemplateIntegrityTest`. |

These defaults exist so SDBC inserts have valid foreign keys when a test row doesn't fully specify all its associations. A test that doesn't declare an MT defaults to `#$BaseKB`, etc. The KB constants referenced (`#$TKB...`) are the foundational test-template constants — TKB is "Template KB", the seed structure for KCT.

The defglobals all have `boundp`-guards in their definitions (so reload doesn't blow them away) and are `declare-defglobal`-registered.

### `*ctest-storing-p*` and `*ctest-storing-configs-p*`

Two flags govern SDBC writes:

- `*ctest-storing-p*` — if `t`, test runs write to the repository. Default `nil`. The "are we in CI mode" gate.
- `*ctest-storing-configs-p*` — if `t`, the per-run configuration history is also written. Default `nil`. The docstring records *why* this defaults off:

  > This was the default until October 2004, but was disabled due to problems with completing the storage of config info within the 4-hour SDBC timeout.

  The 4-hour timeout is a real constraint of the SDBC connector — long-running test executions kept hitting it because dumping the full test config was bottlenecked by the database connection. The fix in 2004 was to stop storing it; the docstring is the historical record. A clean rewrite that doesn't use SDBC has no equivalent constraint.

`*ctest-required-metrics*` — list of `#$IndividualTestMetric` instances that get collected for *every* test regardless of per-test config. Default `nil`. The "global metrics" override.

`*tests-in-process*` — index of test/collection GUIDs currently being constructed. Used to break cycles in collection-config inserts (a test in collection A that's part of collection B that contains test → collection A again).

## The KCT layer (`kct-utils.lisp`)

This file is the KCT-specific glue on top of ctest.

### Constants and parameters

```lisp
*kct-test-execution-type*       "I"   ; individual test execution
*kct-collection-execution-type* "C"   ; collection execution

*kct-default-error-notify-cyclist* nil  ; who gets emailed on KCT errors
*kct-use-sampling-mode* nil             ; if t, use sampling rather than hypothesize for implications
*kct-debug* nil                         ; debug flag
```

`*kct-core-constants*` is a deflexical list `(#$TestVocabularyMt #$testQuerySpecification)` — the KB constants that *must* be loaded for KCT to work. This is a representative sample, not exhaustive.

### Initialization

```lisp
(defun initialize-kct ()
  (initialize-ctest)
  t)

(defun initialize-kct-kb-feature ()
  (if (every-in-list #'valid-constant? *kct-core-constants*)
      (missing-larkc 32161)         ; would set kct-kb-loaded
      (unset-kct-kb-loaded))
  (kct-kb-loaded-p))
```

`initialize-kct-kb-feature` is the gate: if `#$TestVocabularyMt` and `#$testQuerySpecification` both exist, KCT is "available"; otherwise it's not. The `missing-larkc 32161` is the set-flag-and-publish-feature path that LarKC stripped.

`(initialize-kct)` chains to `(initialize-ctest)` — they share the default-value population.

### KCT operations (all LarKC-stripped)

All bodies are `missing-larkc`. The *names* are the API:

| Function | Purpose |
|---|---|
| `kct-query-specification kct` | Get the underlying CycL query of a KCT |
| `kct-test-spec-p object` | Predicate: is `object` a KCT? |
| `kct-test-collection-p object` | Predicate: is `object` a KCT collection? |
| `kct-asserted-test-collections kct` | Collections this test is asserted to be in |
| `kct-comments kct` | Comments on this test (KB assertions) |
| `kct-test-collection-instances collection` | Tests in a collection |
| `kct-responsible-cyclists kct` / `-collection-responsible-cyclists collection` | Responsibility lookup |
| `kct-test-metrics kct` | Metrics this test collects |
| `kct-exact-set-of-binding-sets`, `-exact-binding-sets`, `-wanted-binding-sets`, `-unwanted-binding-sets` | Binding-set retrieval, by designation |
| `kct-bindings-unimportant?` | Is the test binding-set-designation `"U"`? |
| `kct-binding-sets-cardinality`, `-min-cardinality`, `-max-cardinality` | Cardinality bounds |
| `kct-defining-mt kct` | The MT in which the test is defined |
| `kct-test-runnable? kct` / `-known-unrunnable?` | Validity gate |
| `why-not-kct-test-valid kct` | Diagnostic: explain why a KCT can't run |
| `categorize-kct-invalidity-reasons` | Aggregate invalidity reasons over all KCTs |
| `printable-execution-mode mode` / `-execution-type type` | Format helpers |
| `kct-default-for-parameter parameter` | Look up a default from the `*default-*` globals in ctest-utils |
| `kct-new-hlmt mt arg1 arg2` | Construct an HLMT for a KCT context |
| `kct-transform-query-results-for-comparison results` | Normalize results before binding-set comparison |
| `canonicalize-query-bindings-int`, `ncanonicalize-query-bindings-int`, `ncanonicalize-query-binding-int` | Binding canonicalization (stable comparison across runs) |
| `kct-transform-set-of-binding-sets set-of-binding-sets transform` | Apply a transform to every binding in a set |
| `kct-formula-if-assertion obj` | Strip an assertion to its CycL formula |

Together, this API is **the test-validity-and-comparison kernel for KCT**. A test loaded from the KB is validated, run, has its results canonicalized, and gets compared against the asserted exact/wanted/unwanted binding sets — those are the operations whose pieces are listed above.

## Initialization sequence

When the `(initialize-kct)` path runs (LarKC-stripped from this file but presumably called from the harness initialization in production):

1. `initialize-ctest` populates the default-value globals from the KB. Requires `#$BaseKB`, `#$TKBTemplate*` constants to exist.
2. `initialize-kct-kb-feature` checks `#$TestVocabularyMt` and `#$testQuerySpecification`. If both exist, the KCT-KB-loaded flag would be set; otherwise unset.
3. KCT tests are then discovered by walking the KB for instances of `#$KBContentTest` (or whatever the canonical class is — the Lisp doesn't say, the constant must be in the KB).
4. Each discovered KCT is wrapped in a `cyc-test` (with type `:kct`) via `new-cyc-test`, so it appears in the harness's master list.

The runner path is `run-cyc-test-kct ct ...` (declared in `cyc-testing.lisp`, body LarKC-stripped). It would:
- Resolve the KCT's query specification.
- Apply its execution mode (sampling/hypothesize/simple).
- Run the inference.
- Canonicalize the results.
- Compare to the exact/wanted/unwanted binding sets.
- Emit per-test result rows; if `*ctest-storing-p*`, write them to SDBC.

## Notes for a clean rewrite

- **Drop SDBC entirely.** The 4-hour-timeout docstring on `*ctest-storing-configs-p*` is one of many footguns. Modern test reporting writes JSON (or JUnit XML, or directly to stdout) and is consumed by external CI. The SQL schema, all 19 table-name constants, the `*max-*-len*` field-length suite, `ctest-truncate-value-for-field`, and `add-leading-and-trailing-text` can all go.
- **Drop the keyword/string vocabulary duplication.** Statuses are stored as both keyword (`:success`) and string ("SUCCESS"); modes as both keyword and char ("S"/"H"/"X"); designations as char ("E"/"W"/"N"/"U"). The chars exist for SQL storage. With SDBC gone, just use keywords throughout.
- **The default-value population is too aggressive.** `initialize-ctest` populates 18 globals at startup whether KCT is being used or not. They should be lazily computed (or, better, just computed inline at first use — they're cheap KB lookups).
- **`*default-*` globals fixate on specific KB constants.** `#$TKBTemplateTestForMissingMt` is the canonical "default test ID" — but if that constant gets renamed or removed, KCT silently breaks. The defaults should be configurable (parameter, KB query) rather than hardcoded.
- **The execution-mode taxonomy is correct.** Sampling vs hypothesize vs simple is a real distinction worth preserving — it captures different ways a test can be parameterized over the KB. Keep it.
- **Authoring tests in the KB is a real win.** This is the *only* test type whose definition is shared with KB content. Cyclists can write tests in their normal workflow, tag them with collections via assertion, and have them participate in regular runs. Don't lose this — it's the architectural advantage of KCT over the other test types.
- **The wanted/unwanted/exact/unimportant binding-set vocabulary is sound, if verbose.** It captures three common test shapes ("must return exactly these", "must include at least this", "must not include this") plus the "we don't care about bindings, just answer count" case. Keep it; rename "unimportant" to "any" or "wildcard".
- **The wanted/unwanted module/support designation is doing too much.** Combining "must use module X" with "must justify by assertion Y" into one mechanism saves a struct slot at the cost of conceptual clarity. Split them: `:expected-modules`, `:forbidden-modules`, `:expected-supports`, `:forbidden-supports`.
- **`*kct-use-sampling-mode*` as a global flag is a smell.** Sampling vs hypothesize is per-test; a single global toggle means "rerun all KCTs in sampling mode" which is rarely what you want. Make it per-test, with the flag as a "default-when-not-specified" only.
- **`kct-test-runnable?` and `kct-known-unrunnable?` should collapse into `kct-runnability` returning `:runnable`, `:unrunnable :reason`, or `:unknown`.** Two predicates encoding three states is a bug magnet.
- **Cycles in collection config (the `*tests-in-process*` mechanism) shouldn't be the runtime's problem.** A KCT collection containing itself is a KB consistency error; detect and reject at assertion time, not as runtime cycle-breaking.
- **`why-not-kct-test-valid` returning a list of reasons is good UX.** Keep it; expose it in the test report so a `:not-run` test explains itself.
