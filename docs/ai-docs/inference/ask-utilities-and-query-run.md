# Ask-utilities and KBQ query-run

Two related but distinct concerns:

1. **Ask-utilities** (`inference/ask-utilities.lisp`, 158 lines) — the public Cyc-API entry points for asking queries: `query-justified`, `query-template`, `query-variable`, `query-template-eval`. These are thin wrappers over `new-cyc-query` that adapt to specific use cases. Plus the deprecated `ask-*` API (renamed to `query-*` years ago, kept for backward compatibility).
2. **KBQ query-run** (`inference/kbq-query-run.lisp`, 772 lines) — the **K**B-content **Q**uery test harness. A separate framework for running batches of queries from the KB content tests, recording per-query and per-set timing/answer/proof statistics, and persisting results to disk. Used to monitor KB regression and inference performance over time.

The two files together form the *external API* surface for asking queries, plus the *test/regression* infrastructure on top.

Source files:
- `inference/ask-utilities.lisp` (158)
- `inference/kbq-query-run.lisp` (772)

## Ask-utilities

The file is mostly a registration toplevel for Cyc-API functions. Almost every function body is `missing-larkc` in the LarKC port — the bodies are stubbed because the actual call delegates to `new-cyc-query` with the appropriate property massaging. The contract of each is documented in the API registration string.

### Public (registered) Cyc-API functions

Each registered with `register-cyc-api-function`:

| Function | Signature | Returns |
|---|---|---|
| `query-justified` | `(sentence &optional mt query-properties)` | `(listp query-halt-reason-p)` — list of `(bindings, justification)` pairs |
| `query-template` | `(template sentence &optional mt query-properties)` | `(listp query-halt-reason-p)` — list of template instantiations |
| `query-variable` | `(variable-token sentence &optional mt query-properties)` | `(listp query-halt-reason-p)` — list of values for the named variable |
| `query-template-eval` | `(template sentence &optional mt query-properties)` | `(non-negative-integer-p)` — count of template evaluations |

Each is a wrapper over `new-cyc-query` that:
1. Sets the `:return` property appropriately (`:bindings-and-supports`, a template, just bindings, or count-of-evals)
2. Calls `new-cyc-query(sentence, mt, properties)`
3. Massages the result into the documented shape

The `query-template-eval` variant is special — the template is *evaluated* (as Lisp code) for each binding, not just substituted. Used for side-effecting queries (e.g. printing each match). The function returns the count of evaluations performed, not a list of results.

### Deprecated `ask-*` API

For each `query-*` there is a deprecated `ask-*`:

| Deprecated | Replacement |
|---|---|
| `ask-justified` | `query-justified` |
| `ask-template` | `query-template` |
| `ask-variable` | `query-variable` |
| `ask-template-eval` | `query-template-eval` |

The deprecated forms take the legacy 4-parameter resource control (`backchain number time depth`) instead of a `query-properties` plist. They are registered via `register-obsolete-cyc-api-function` so callers get a deprecation warning.

The legacy parameters map onto modern properties via `query-properties-from-legacy-ask-parameters(backchain, number, time, depth)`:
- `backchain` → if integer, `:max-transformation-depth = backchain`; if T, no transformation limit; if nil, `:max-transformation-depth = 0`
- `number` → `:max-number`
- `time` → `:max-time`
- `depth` → `:max-proof-depth`

`query-static-properties-from-legacy-ask-parameters()` and `query-dynamic-properties-from-legacy-ask-parameters(...)` are the static/dynamic split versions (mostly missing-larkc).

### Recursive query infrastructure

The trickiest piece in this file. When an HL module needs to ask a sub-query mid-expansion (e.g. transformation modules that need to check the antecedent before firing), it recursively calls `recursive-query` (or the older `inference-recursive-ask`).

`*recursive-query-depth*` (defaults nil) tracks current recursion. `*max-recursive-query-depth* = 27` is the hard limit — exceeding it is an error.

`*recursive-queries-in-currently-active-problem-store?*` (defaults T, "Temporary control variable") — when set, recursive queries reuse the parent's problem store. This shares memoization and SBHL space across the recursion.

The recursive query path:
1. `recursive-query(sentence, mt, query-properties)` (mostly missing-larkc) — entry
2. `recursive-query-problem-store-to-reuse(query-properties)` — pick the store to reuse
3. `filter-query-properties-for-recursive-query(query-properties)` — strip out properties that don't make sense in a recursive context (e.g. `:browsable?` is forced off; `:metrics` is dropped)
4. `query-property-inherited-by-recursive-query?(property)` — per-property test for inheritance

The `filter-` step is essential: a recursive query inherits some properties from the parent (`:max-transformation-depth`, `:allowed-rules`) but not others (`:return`, `:max-time`, `:metrics`). The filter is what enforces this.

### Kappa-tuples API

`kappa-tuples(variable-list, sentence, mt, &optional query-properties)` — given a sentence with multiple free variables, return a list of tuples (one per free variable position, in the order specified). The "kappa" reflects the lambda-binding style: ask `(P ?X ?Y ?Z)` and get back `((x1 y1 z1) (x2 y2 z2) ...)`.

`kappa-tuples-justified` is the same but each tuple is paired with its justification.

Both are registered as Cyc-API functions (mostly missing-larkc body).

### `inference-literal-truth` and `inference-literal-ask`

Two specialised entry points for the simplest query: "is this literal true in this MT?" `inference-literal-truth(literal, mt)` returns one of `:true | :false | :unknown`. `inference-literal-ask(literal, mt)` returns the answer set. These are missing-larkc but used by removal modules and tactical-evaluation paths to check a single asent's status.

### `the-set-of-elements`

`the-set-of-elements(expression, &optional mt query-properties)` — evaluates a `(TheSetOfElementsFn)` expression by running the contained query and collecting bindings. Used for set-valued evaluations like `(SetOfElementsFn ?X (instances ?X Cat))`. Mostly missing-larkc.

`the-set-of-problem-solvable-via-generalized-query?` and `the-set-of-elements-via-generalized-query` are the deeper machinery — they detect when a TheSetOf expression can be answered by reusing an existing problem-store query rather than minting a fresh one.

### `cyc-query-with-minimal-required-transformation`

Helper for queries that should succeed with the minimal transformation depth — start at depth 0 and only escalate if needed. Mostly missing-larkc.

## KBQ query-run

The KBQ harness is a layered framework for running batches of KB-content queries:

- **Query** — a single sentence + MT + properties
- **Test** — a query plus expected results (for assertion-style tests)
- **Query set** — a batch of queries
- **Test set** — a batch of tests
- **Run** — one execution of a query/test/set
- **Runstate** — the live state of a run

The harness records timing, answer counts, problem/proof counts, link counts (broken down by type and by status), and persists everything to CFASL files. Used for KB regression testing and for measuring inference performance changes over time.

### The three runstate structs

```lisp
(defstruct kbq-runstate
  id              ; unique within image
  lock            ; for concurrent updates
  query-spec
  inference       ; the live or completed inference
  result          ; the answers
  test-runstate   ; the parent kct-runstate, if any
  run-status)     ; :running | :complete | :error etc.

(defstruct kct-runstate
  id lock test-spec result query-runstate test-set-runstate
  run-status start end)

(defstruct kct-set-runstate
  id lock test-set result test-runstates
  run-status start end)
```

A `kct-set-runstate` (test set) contains many `kct-runstate`s (tests), each of which contains a `kbq-runstate` (query) plus expected-result info.

The dynamic specials `*kct-set-runstate*`, `*kct-runstate*`, `*kbq-runstate*` are bound by the harness as it descends into nested execution levels. The kernel's `possibly-set-kbq-runstate-inference` reads `*kbq-runstate*` and stores the live inference object onto the runstate so the harness can introspect mid-run.

### CFASL common-symbol tables

KBQ persists data via CFASL (the engine's binary serialisation). Per-file *common-symbol tables* avoid repeating long keyword names. Three tables:

- `*kbq-old-cfasl-common-symbols*` — backward-compatible legacy keywords (15 keys)
- `*kbq-new-cfasl-common-symbols*` — extended keywords (≈80 per-link-type, per-status counts)
- `*kbq-cfasl-common-symbols*` — union (use this for new files)

Plus the test-suite versions: `*kct-old-cfasl-common-symbols*`, `*kct-cfasl-common-symbols*`. These add `:success`, `:failure`, `:status`, `:test`.

The `*kbq-new-cfasl-common-symbols*` list is essentially the metric vocabulary: `:answer-count`, `:time-to-first-answer`, every `:X-link-count`, every `:Y-problem-count` for each combination of provability × tactical-status × literal-shape. Hundreds of small keywords for fine-grained per-query statistics.

### `with-kbq-query-set-run` macro

Binds `*kbq-internal-time-units-per-second*` to the test's scaling factor, so deeply-nested code can convert internal-real-time to seconds consistently.

### `kct-test-metric-table`

Maps KB-side `TestMetric-*` constants to keyword metric names:

```
TestMetric-TotalTime              → :total-time
TestMetric-TimeToFirstAnswer      → :time-to-first-answer
TestMetric-TimeToLastAnswer       → :time-to-last-answer
TestMetric-AnswerCount            → :answer-count
TestMetric-AnswerCountAt30Seconds → :answer-count-at-30-seconds
TestMetric-AnswerCountAt60Seconds → :answer-count-at-60-seconds
TestMetric-ProblemStoreProofCount → :proof-count
TestMetric-ProblemStoreProblemCount → :problem-count
```

The constants are KB-defined (in `TestMetric` collection); the harness translates them to runtime keywords for metric collection.

### `*kbq-test-collection-to-query-set-query*`

A canonicalised CycL query that, given a test collection (e.g. `#$BasicCommonSenseTests`), enumerates all the queries belonging to that collection. The structure:

```
(evaluate ?set
  (SetExtentFn
    (TheSetOf ?query
      (thereExists ?test
        (and (knownSentence (isa ?test :test-collection))
             (assertedSentence (testQuerySpecification ?test ?query)))))))
```

When the harness wants to run all tests in a collection, it asks this query (with `:test-collection` substituted) and gets back the test-spec list.

### Query-set persistence: file format

Query-set runs are persisted to `.cfasl` files (`*query-set-run-file-extension* = ".cfasl"`). The file format:

1. Open as CFASL stream with `*kbq-cfasl-common-symbols*`
2. Write the `kbq-query-set-run` header (`kbq-save-query-set-run-preamble`)
3. For each query-run: write the `kbq-query-run` record (`kbq-save-query-run`)

Reading is symmetric: `kbq-load-query-set-run-int(stream)` reads the header; `kbq-load-query-run-int(stream)` reads each query-run; `:eof` marker terminates. The macros `do-query-set-run` and `do-query-set-run-query-runs` iterate this format.

`kbq-save-query-set-run-without-results` is the variant that omits per-query results (just records query-spec + metadata; useful for distributing test sets without leaking expected results).

### Query-set filtering and analysis

A pile of `kbq-filter-*` and `kbq-*-query-set-runs` functions (mostly missing-larkc) provide *post-hoc analysis*:

- `kbq-filter-query-set-run-by-property-value` — pick out runs matching a property
- `kbq-filter-query-set-run-by-test` — pick out runs matching a predicate
- `kbq-answerable-query-set-run` / `kbq-unanswerable-query-set-run` — split by answer count
- `kbq-mutually-answerable-queries` — across multiple sets, find queries answered by all
- `kbq-same-property-value-queries` — find queries with same metric values across sets
- `kbq-fast-queries` — under a time threshold

Test sets get analogous functions: `kct-succeeding-test-set-run`, `kct-failing-test-set-run`, `kct-common-sense-test-set-run`, `kct-mutually-succeeding-tests`, etc.

These are the tools for asking "which queries got faster/slower between version X and version Y?" and "which tests failed in version X but passed in Y?" — KB regression analysis.

### Outlier handling

`*kbq-outlier-timeout* = 600` (defparameter, defaults 10 minutes) — the per-query maximum time for a KBQ run. Queries that exceed are flagged as outliers and don't contribute to aggregate statistics. `*kbq-default-outlier-timeout*` is the deflexical default.

### Run number

`*kbq-run-number* = 1` — the harness can run each query N times (for profiling stability). Most production runs use 1.

## When does each piece fire?

| Operation | Triggered by |
|---|---|
| `query-justified` etc. | User code via Cyc API |
| `ask-justified` etc. | Legacy callers (with deprecation warning) |
| `recursive-query` | HL modules that need to ask sub-queries during expansion |
| `kappa-tuples` | Set-collection queries |
| `inference-literal-truth` / `inference-literal-ask` | Single-literal status checks (most callers) |
| KBQ runstate setup | The KBQ test harness when running a query batch |
| KBQ persistence | After each query batch completes |
| KBQ analysis | Post-hoc when comparing query-set runs |

## Cross-system consumers

- **User code** calls the registered Cyc-API functions.
- **HL modules and workers** call `recursive-query`, `inference-literal-truth`, `inference-literal-ask`.
- **Kernel** calls `possibly-set-kbq-runstate-inference` to wire the live inference into the KBQ runstate.
- **KBQ test runner** (in `cyc-testing/kb-content-test/`) drives the query-set runs.
- **CFASL** is the persistence layer for both the metric data and the test-set archives.
- **Inference parameters** — query properties are the contract between ask-utilities and the kernel.

## Notes for the rewrite

### Ask-utilities

- **The deprecated `ask-*` API can go.** It exists for backward compatibility with code that predates the property plist. The clean rewrite has no such legacy.
- **The `query-*` Cyc-API functions are the public surface.** Their bodies should be one-liners that call `new-cyc-query` with the appropriate `:return` property and pass everything else through.
- **Recursive queries with shared problem-store** are essential for transformation rule firing — without them, every sub-ask would mint a fresh store and lose the shared memoization. Keep `*recursive-queries-in-currently-active-problem-store?*` as on-by-default.
- **`*max-recursive-query-depth* = 27`** is empirical. It's deep enough for most legitimate recursion and shallow enough to catch infinite loops fast. Keep it; expose as a configurable.
- **`filter-query-properties-for-recursive-query`** is the only code that knows which properties to inherit. Document the per-property inheritance decisions; the clean rewrite should make them explicit (a per-property `inheritable?` flag).
- **`inference-literal-truth` returns 3-valued.** Don't collapse to a boolean; users need to distinguish `:false` from `:unknown`.
- **`kappa-tuples` is a useful primitive** — multi-variable bindings as tuples. The clean rewrite should keep it as a first-class operation.
- **Cyc-API registration** uses the `register-cyc-api-function` infrastructure. Keep the registration step — it's how the API surface is documented and discoverable.

### KBQ query-run

- **The KBQ harness is heavyweight.** Three nested runstate types, persistence to disk, fine-grained metric collection. Don't simplify it; the test infrastructure depends on it.
- **The CFASL common-symbol tables matter.** The "old" and "new" symbol sets exist for backward compatibility with archived test-set runs. The clean rewrite should preserve the ability to read old files.
- **The `*kbq-new-cfasl-common-symbols*` list is the canonical metric vocabulary** — every per-link-type, per-status, per-literal-shape counter. The clean rewrite should generate this list from the inference-metrics struct rather than maintaining it by hand.
- **Runstate dynamic specials** (`*kbq-runstate*`, `*kct-runstate*`, `*kct-set-runstate*`) are bound by the harness and read by the kernel. Keep this hook (`possibly-set-kbq-runstate-inference`); it's how the harness gets the live inference for introspection.
- **Outlier timeout is per-query.** 600 seconds = 10 minutes. Tune per environment; production CI may want shorter, deep regression runs may want longer.
- **Most KBQ functions are missing-larkc.** The infrastructure shape is documented but not implemented in the LarKC port. The clean rewrite must build the persistence and analysis tooling. The shape is well-defined; the work is mechanical.
- **The `do-query-set-run` and `do-query-set-run-query-runs` macros** are the iteration interface over persisted files. Keep them; they hide the file-IO details from analysis code.
- **`kct-test-metric-table` is the KB↔engine metric mapping.** When a test asserts `(measureMetric MyTest TestMetric-TotalTime)`, the harness translates to `:total-time` for metric collection. Keep this translation explicit; don't hard-code metric names.
- **`*kbq-test-collection-to-query-set-query*`** is a hardcoded canonicalised query for finding tests-in-a-collection. The clean rewrite should keep it as a constant — re-canonicalising at runtime is a waste.
- **The harness can run tests in parallel** (each runstate has a lock). The clean rewrite should preserve this; KBQ runs over thousands of tests benefit from concurrency.
- **The legacy CFASL file format is binary** — be careful with versioning. A new format should be backward-compatible (read old files) or the harness should explicitly migrate.
