# Inference engine tests

Five test types share a common shape: each one pairs a **CycL sentence** with **a verifiable claim about how the inference engine processes it**. They are the test types most directly tied to inference correctness, and they are all defined in their own files alongside the inference-engine code they exercise.

| Type | Tag | Define-macro | Verifies |
|---|---|---|---|
| Inference unit test | `:iut` | `define-inference-unit-test` | An ASK against the sentence terminates with the expected result and halt-reason |
| Removal-module test | `:rmt` | `define-removal-module-test` | A query causes a *named* removal module to fire on at least one goal path |
| Transformation-module test | `:tmt` | `define-transformation-module-test` | A query causes a *named* transformation module to fire |
| Removal-module cost test | `:rmct` | `define-removal-module-cost-test` | The cost estimate produced by a removal module is below a regression threshold |
| Evaluatable-relation test | `:ert` | `define-evaluatable-function-test` / `-predicate-test` and the `simple-` variants | A particular evaluatable function or predicate evaluates correctly on a literal |

The implementations are `cyc-testing/inference-unit-tests.lisp`, `cyc-testing/removal-module-tests.lisp`, `cyc-testing/transformation-module-tests.lisp`, `cyc-testing/removal-module-cost-tests.lisp`, `cyc-testing/evaluatable-relation-tests.lisp`. In all five files, the LarKC port has stripped the runner bodies; the structs, the `define-*` macros (reconstructed from Internal Constants evidence), and the registration plumbing are intact.

Each type is an independent island: its own struct, its own master table, its own define-macro, its own runner. The harness layer ([harness.md](harness.md)) is what unifies them under `cyc-test`; this doc describes what each type *is* and how it differs.

## Common shape

All five types follow the same pattern:

1. A `defstruct` with a `*-test` name and a short conc-name (`IUT-`, `RMT-`, `TMT-`, `RMCT-`, `ERT-`).
2. A `*dtp-*` constant naming the struct type.
3. A `defglobal` master table — usually a hashtable, sometimes keyed by a name keyword, sometimes by the relation/module/predicate the test targets.
4. A `define-*-test` macro (active `declareMacro`, reconstructed from Internal Constants).
5. An `-int` helper function (registered macro-helper, body LarKC-stripped) that does the validation, struct construction, and master-table install.
6. A run cascade: `run-all-*-tests`, `run-*-tests-for-X`, `run-*-test`, `run-*-test-int`, `run-*-test-query`, plus a per-test predicate `run-*-test?` and printers `print-*-preamble`/`-result`.
7. A toplevel block that `declare-defglobal`s the master table, registers the macro-helper, and (where applicable) registers a CFASL opcode.

Below: the per-type variations.

## Inference unit tests (`:iut`)

The richest type. An IUT carries a full ASK specification: the sentence to ask, the parameters to ask it with, the expected result, the expected halt-reason, an optional result-test predicate, and a list of follow-up queries to chain after this one succeeds. They're the workhorse of regression testing for the inference harness.

### Struct (`inference-unit-test`, conc-name `IUT-`)

15 slots:

| Slot | Meaning |
|---|---|
| `name` | Test name. Symbol/keyword. |
| `comment` | Free-text comment. |
| `sentence` | CycL sentence to ASK. |
| `properties` | Inference-parameters plist (e.g. `(:max-time 30 :max-transformation-depth 1)`). |
| `result` | Expected answers — typically `t`, `nil`, a number, or a list of bindings. |
| `halt-reason` | Expected halt reason; defaults to `:exhaust-total`. Other common values: `:max-time`, `:max-number`, `:exhaust-total-and-paused`. See `inference-datastructures-enumerated-types.lisp`. |
| `result-test` | Optional function called with `(actual-result expected-result)`; returns truthy on match. Used when bare equality is wrong (e.g. set comparison). |
| `followups` | List of follow-up queries, each a recipe describing a chained ASK using bindings from the parent. |
| `bindings` | Initial bindings to seed the parent ASK. |
| `kb` | KB requirement (`:tiny`, `:full`). Default `:tiny`. |
| `owner` | Cyclist responsible. |
| `bug-number` | Linked bug ticket, if any. |
| `creation-date` | Test creation date. |
| `creator` | Who wrote the test. |
| `working?` | Is this test known-working? Default `t`. |

### Macro

```
(define-inference-unit-test name
    &key sentence properties expected-result
         (expected-halt-reason :exhaust-total) expected-result-test comment
         followups bindings (kb :tiny) owner bug created creator (working? t))
```

Expands to a call to `define-inference-unit-test-internal` with 15 positional arguments matching the struct slots. The split between `result`/`halt-reason` (post-run) and `expected-result`/`expected-halt-reason` (pre-run) is captured in the macro: `expected-` is what the user supplies, the unprefixed slot names are populated at run time.

### Master tables

| Variable | Type | Purpose |
|---|---|---|
| `*inference-unit-test-names-in-order*` | ordered list | Iteration order. |
| `*inference-unit-tests-by-name*` | hashtable, `eq` test, size 212 | Lookup. |

### Side-effect tracking

`*within-inference-unit-test?*` and `*inference-unit-test-assertions-created*` track assertions made by side-effect during a test (some inference unit tests create temporary KB content, then need to clean up). `note-assertion-for-inference-unit-test` (LarKC-stripped) is the hook called by the assertion-creating code paths when `*within-inference-unit-test?*` is true; `inference-unit-test-cleanup` is the unwind-protect handler.

### Followups

`define-inference-unit-test`'s `:followups` is a list of follow-up recipes. Each recipe describes a sub-query that should be run in the bindings produced by the parent. `run-inference-unit-test-followup-query` (LarKC-stripped) is the per-followup runner; `followup-substitute-hypothetical-bindings` substitutes parent-bindings into the followup template. A failing followup fails the parent test.

### CFASL

Opcode 513 (`*cfasl-wide-opcode-inference-unit-test*`). All four CFASL methods are LarKC-stripped, but the input opcode is registered. The intent is the same as everywhere: serialize tests across image boundaries.

### Iteration macro

`(do-inference-unit-tests (var &key done) &body body)` — walk `*inference-unit-test-names-in-order*`, lookup each by name (via `find-inference-unit-test-by-name`), bind to `var`, execute body. `:done` short-circuits iteration. Reconstructed from Internal Constants evidence (the only list variable in scope is the names list, and the gensym name is passed to the lookup).

## Removal-module tests (`:rmt`)

A removal-module test names a *removal module* (an HL inference module — see [inference/removal-modules.md](../inference/removal-modules.md)) and asserts that running a query on a sentence causes that module to fire on at least one goal path. They're the regression tests for module dispatch correctness.

### Struct (`removal-module-test`, conc-name `RMT-`)

12 slots: `hl-module`, `id`, `sentence`, `mt`, `properties`, `comment`, `kb`, `owner`, `bug-number`, `creation-date`, `creator`, `working?`. Each test has a numeric `id` within its module — `(name, id)` is the unique key — so a given module can have many tests.

### Macro

```
(define-removal-module-test name id sentence
    &key (mt #$EverythingPSC) properties (kb :tiny)
         owner comment bug created creator (working? t)
    &allow-other-keys)
```

Default MT is `#$EverythingPSC` (the everything-psc — the broadest meaningful context for an inference test).

### API exposure

This is the only one of the five that gets `register-cyc-api-macro` — the macro is published as part of the Cyc API surface, with its full keyword spec and docstring. The other four are macro-helpers only.

### Master table

`*removal-module-tests*` — a single hashtable keyed by hl-module, value a list (or sub-table) of the per-id tests. Size 100.

### Runners

The runner cascade is structured for both blocking and browsable styles:

| Function | Purpose |
|---|---|
| `run-all-removal-module-tests` | Walk all modules, run all tests. |
| `run-removal-module-tests-for-pred` | Run all tests for modules of a given predicate. |
| `run-removal-module-tests` | Run all tests for one module. |
| `run-removal-module-test-number` | Run one specific (name, id) test. |
| `-browsable` / `-blocking` variants | "Browsable" leaves the resulting inference visible in the inference browser; "blocking" returns synchronously. |

The query verifies *that the module was used* — `run-removal-module-test-query-int`'s contract (per the docstring on `define-removal-module-test`): "queries SENTENCE in MT and verifies that a removal module named NAME was used in some goal path."

## Transformation-module tests (`:tmt`)

Identical shape to RMT, but for transformation modules. Same 12-slot struct (`transformation-module-test`, conc-name `TMT-`), same `(hl-module, id, sentence)` key, same default `:mt #$EverythingPSC`, same runner cascade. The differences are:

- The macro is `define-transformation-module-test`.
- The master table is `*transformation-module-tests*`.
- The macro is a macro-helper only — *not* `register-cyc-api-macro`-published.
- The runners verify that the named transformation module fired on at least one transformation step.

The duplication between RMT and TMT is mechanical and a clear candidate for unification in a clean rewrite: parameterize on module-type (`:removal` or `:transformation`) and share one struct, one macro, one runner.

## Removal-module cost tests (`:rmct`)

A cost test runs the named removal module against a sentence and compares the *cost estimate* it produces against a baseline, flagging regressions when cost rises.

### Struct (`removal-module-cost-test`, conc-name `RMCT-`)

11 slots: `hl-module`, `id`, `sentence`, `mt`, `comment`, `kb`, `owner`, `bug-number`, `creation-date`, `creator`, `working?`. Note the missing `properties` slot vs RMT — cost tests are pure cost regressions; they don't carry custom inference parameters.

### Macro

```
(define-removal-module-cost-test name id sentence
    &key (mt #$EverythingPSC) (kb :tiny)
         owner comment bug created creator (working? t)
    &allow-other-keys)
```

### Cost comparison

`generic-cost-test-comparison` (LarKC-stripped) is the threshold check. The actual baseline storage isn't visible from this file alone — it's likely in the inference-metrics infrastructure. The runners (`run-removal-module-cost-test-comparison`, `run-removal-module-cost-test`) capture the current cost and compare.

The `:since` keyword on `run-all-removal-module-cost-tests` filters tests by date (presumably "tests added since this date").

## Evaluatable-relation tests (`:ert`)

A test that a given Cyc evaluatable function or predicate computes the right answer on a literal expression. **The smallest and simplest of the five.**

### Struct (`evaluatable-relation-test`, conc-name `ERT-`)

5 slots only: `relation`, `id`, `sentence`, `kb`, `owner`. No working? flag, no comment, no creation-date — these are minimal tests.

### Macros (5 of them)

All expand to a registered `-int` helper:

| Macro | Helper | Purpose |
|---|---|---|
| `define-evaluatable-function-test function id sentence &key (kb :full) owner` | `define-evaluatable-relation-test-int` | Test that `function` evaluates `sentence` correctly. KB defaults to `:full` here, not `:tiny` — eval tests usually need real data. |
| `define-evaluatable-predicate-test predicate id sentence &key (kb :full) owner` | same | Test that `predicate` evaluates correctly. |
| `define-simple-evaluatable-function-test function id expression &key (result :dont-care) (kb :full) mt owner` | `define-simple-evaluatable-function-test-int` | A single-form test: evaluate `expression`, optionally compare to `result`. `:dont-care` means "just verify it terminates and is well-formed." |
| `define-simple-evaluatable-function-test-block function start-id &key (mt #$InferencePSC) (kb :full) tests owner (working? t)` | `define-simple-evaluatable-function-test-block-int` | Define a *block* of consecutively-numbered tests starting at `start-id`. `tests` is a list of test bodies; each gets a sequential id. |
| `define-simple-evaluatable-predicate-test`, `define-simple-evaluatable-predicate-test-block` | corresponding `-int` helpers | Predicate analogues. |

The simple-block forms exist because evaluatable-test data is verbose: a function like `+` has dozens of small tests (1+1, 2+3, edge cases) and assigning ids manually is bookkeeping nobody wants. The block form auto-numbers.

### Master table

`*evaluatable-relation-tests*` — a single hashtable keyed by the relation. Size 100. The structure under each key is a list (or sub-table) of tests, identified by id within the relation.

### Runners

Standard cascade: `run-all-evaluatable-relation-tests`, `run-evaluatable-relation-tests` (for one relation), `run-evaluatable-relation-test-number` (one specific id), plus the `-browsable` variant. `evaluatable-relation-test-query-inference` is the inner-loop "build and run the inference object" entry.

### Indention patterns

The toplevel block declares 6 `declare-indention-pattern` forms — these tell the editor (Emacs/SLIME) how to indent each macro body. ERT tests have particularly varied shapes (`function id &body body`, `predicate start-id &body body`, etc.), so explicit indention hints are needed for clean source.

## Cross-cutting observations

### Ids are name-scoped

For RMT/TMT/RMCT/ERT, the test id is *only unique within the parent module/relation*. The full key is `(name, id)`. For IUT and the test-case-table, the test name is the unique key directly.

### Default MT and KB vary by intent

| Type | Default MT | Default KB |
|---|---|---|
| IUT | (none — `properties` carries the MT) | `:tiny` |
| RMT | `#$EverythingPSC` | `:tiny` |
| TMT | `#$EverythingPSC` | `:tiny` |
| RMCT | `#$EverythingPSC` | `:tiny` |
| ERT (define-*-test) | (none — `sentence` is the literal eval) | `:full` |
| ERT (simple-*-test-block) | `#$InferencePSC` | `:full` |

The pattern: *unit-style* tests default to `:tiny` KB; *evaluation* tests need `:full`. MT defaults reflect what's broadly useful for the test type — `EverythingPSC` for any-context inference, `InferencePSC` for blocks of evaluatable tests where the standard inference context is what matters.

### `working?` flag is universal except ERT

Every type except ERT has `working?` defaulting to `t`. ERT skips it because eval tests are simpler — broken eval is a hard failure, not a "working on it" state.

### Macro-helper publication

Four of the five (RMT, TMT, RMCT, ERT) only register their `-int` helpers as macro-helpers — the macros aren't part of the Cyc API surface. Only RMT publishes the macro itself via `register-cyc-api-macro`. That's a reasonable position: removal-module tests are part of the public API for module authors, while the others are infrastructure-internal.

### Why the strip was so aggressive here

Every runner is `missing-larkc`. The reason: each runner depends on the inference engine (problem store, strategy, tactician, modules) — all of which are themselves heavily LarKC-stripped. Test runners would call into inference at full depth, and if the inference path is missing, the runner has no body to port. So the test framework has the registration scaffolding but no execution path. To actually run any of these tests in the LarKC port, the inference engine would need to be reconstructed first.

## Notes for a clean rewrite

- **Unify RMT and TMT.** They are the same struct with `hl-module-type` differing. One struct, one macro `(define-module-test :type :removal ...)`, one runner.
- **Unify RMT/TMT/RMCT into one "module test" hierarchy.** Cost-vs-correctness is an axis on a per-test-run basis, not a separate test type. A removal-module test could carry a `:cost-baseline N` annotation and the runner does both checks.
- **The `(name, id)` key is too cute.** Just give every test a unique name. Numeric ids inside a name namespace add a step ("look up the module's test list, then index into it") that's only marginally faster than a hashtable lookup, and makes test-set diff/merge harder.
- **Drop the `-int` helper indirection.** Same as in [test-case-tables.md](test-case-tables.md): the macro can do its work directly. The macro-helper system exists for SubL API publication; CL has nothing equivalent and doesn't need it.
- **Drop CFASL serialization for tests.** Same as everywhere — tests are source-of-truth in `.lisp` files. Opcodes 513 (IUT) and the `cfasl-output-*-test` methods can all go.
- **Property-list initializers + slot-symbol case dispatch is a SubL idiom.** In CL, use `(make-iut :name foo :sentence bar ...)` directly — defstruct's keyword constructor is exactly what you want.
- **`*within-inference-unit-test?*` should be replaced with a thread-local scope.** The "track assertions and clean up on test exit" pattern is a perfectly good idea, but a dynamic flag plus a mutable list plus a manual cleanup is a recipe for leaks if the test errors. Put it in an `unwind-protect`-bracketed scope object.
- **Consolidate `:bug` / `:created` / `:creator` / `:owner`.** These are "test metadata" — they should live in a single annotation block, not as separate slots. A `(:metadata ...)` parameter that takes a plist would compress the slot count.
- **The five separate `define-evaluatable-*` macros are too many.** A single `define-evaluatable-test relation id sentence &key result mt kb owner` covers function and predicate, and an explicit `:simple? t` flag (or just always-simple) covers the simple-* variants. The block forms are sugar; they can stay or be replaced with `(loop for sentence across SENTENCES do ...)`.
