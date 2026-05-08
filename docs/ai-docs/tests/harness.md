# Cyc test harness

The harness is the **uniform registration and run layer** that sits over every flavor of Cyc test. The eight test types in Cyc — generic test-case tables, inference unit tests, inference tests, removal-module tests, transformation-module tests, removal-module cost tests, evaluatable-relation tests, KB content tests — each have their own struct, their own define-macro, and their own runner. The harness is the polymorphic seam that lets `(run-all-cyc-tests path)` walk a directory of `.lisp` test files and invoke the right runner per test, without callers caring which flavor anything is.

The implementation is `cyc-testing/cyc-testing.lisp` (the `cyc-test` wrapper, the master list, the file table, the run/load API) and `cyc-testing/cyc-testing-initialization.lisp` (the one-shot indexing pass run at startup).

Note: the LarKC port has stripped most of the runner bodies. The structs, the master list, the `define-test-case-table` →`new-cyc-test` registration path, and the do-/index- macros are all intact; everything that actually *runs* a test is `missing-larkc`. This doc describes the architecture that the harness *exposes* — a clean reimplementation needs all of it, and most of it is straightforward.

## The `cyc-test` wrapper

A `cyc-test` is a 2-slot defstruct (`(:conc-name "CT-")`):

| Slot | Meaning |
|---|---|
| `file` | The pathname of the `.lisp` file the test was defined in (string). Used for "rerun the tests in this file" and for failure reporting. May be `nil` for tests defined at the REPL. |
| `guts` | The actual test object — a `generic-test-case-table`, an `inference-unit-test`, a `removal-module-test`, etc. The polymorphism happens here. |

`make-cyc-test` accepts a property-list initializer (`:file`, `:guts`); other keys signal an error. `new-cyc-test file guts` is the registration entry point: it validates `guts`, looks up the existing test by name (and removes it if a redefinition is happening), pushes the new one onto `*cyc-tests*`, and indexes it into both name tables.

The `guts` slot's type is dispatched on by `cyc-test-guts-type`:

```
(generic-test-case-table-p guts) → :tct
(inference-unit-test-p guts)     → :iut    (LarKC-stripped)
(removal-module-test-p guts)     → :rmt    (LarKC-stripped)
(removal-module-cost-test-p guts) → :rmct  (LarKC-stripped)
(transformation-module-test-p guts) → :tmt (LarKC-stripped)
(evaluatable-relation-test-p guts) → :ert  (LarKC-stripped)
(inference-test-p guts)          → :it     (LarKC-stripped)
(kct-test-spec-p guts)           → :kct    (LarKC-stripped)
```

The eight type keywords are the table keys for `*cyc-test-type-table*`, which carries human-readable names ("inference unit test", "KB content test", etc.). When a type predicate is added, `cyc-test-guts-type` and `*cyc-test-type-table*` both need an entry.

`cyc-test-name` dispatches similarly: each type knows where its name lives (e.g. `:tct` reads `(generic-test-case-table-name guts)`; the others are LarKC-stripped). Names are assumed unique across types — there's no namespace per type; one global `*cyc-test-by-name*`.

## Master tables

| Variable | Type | Purpose |
|---|---|---|
| `*cyc-tests*` | ordered list | The master list, in registration order. Iteration goes here. |
| `*cyc-test-by-name*` | hashtable, `equal` test, size 212 | Exact-name → cyc-test. The fast path for `find-cyc-test-by-exact-name`. |
| `*cyc-test-by-dwimmed-name*` | hashtable, `equal` test, size 212 | "DWIMmed" name → list of cyc-tests. The forgiving lookup: a name may map to multiple tests if the DWIMming collapses keywords/strings/casing, hence list-valued. |
| `*cyc-test-files*` | ordered list | The master list of `cyc-test-file` records (filename + KB tag). |
| `*most-recent-cyc-test-runs*` | list (or nil) | Cache of the last run results — `run-all-loaded-cyc-tests` populates this for `most-recent-cyc-test-runs` / `most-recent-failing-cyc-test-runs` / `rerun-failing-cyc-tests`. |
| `*most-recent-cyc-test-file-load-failures*` | list (or nil) | Files that failed to load on the last `load-all-cyc-tests`. Inspected after a load run. |

All five are `defglobal` with `boundp` guards (so reloading the file doesn't blow them away) and are registered with `declare-defglobal` in the toplevel block — that's the standard Cyc pattern for "globals that survive image dumps".

`index-cyc-test-by-name ct name` is the install function: it warns if a duplicate is detected (gated on `*warn-on-duplicate-cyc-test-names?*`), writes both tables, and — if `(cyc-tests-initialized?)` — runs the per-type post-install hooks (the `removal-module-test-p` and `removal-module-cost-test-p` branches are LarKC-stripped, but they're where module-level indexing would go).

`index-all-cyc-tests-by-name` is the bulk reindex: walk `*cyc-tests*`, install each. Called from `perform-cyc-testing-initializations` at startup.

## The "is the harness initialized?" gate

`*cyc-tests-initialized?*` is a deflexical flag flipped to `t` exactly once, by `perform-cyc-testing-initializations`. Most code paths under `index-cyc-test-by-name` and `new-cyc-test` consult `(cyc-tests-initialized?)` to decide which validity check to use:

- **Pre-init** (loading test files at startup): `guts` is type-checked as `generic-test-case-table-p` only — that's the only test type whose constructor and predicate exist before the harness is fully wired. Other types' bodies are LarKC-stripped, so the runtime type predicates (`cyc-test-guts-p`) don't yet work; the gate makes pre-init validation cheaper and tolerant.
- **Post-init**: the full `cyc-test-guts-p` polymorphic check runs.

The gate's docstring carries an explicit warning: recompiling the file resets `*cyc-tests-initialized?*` to `nil`, which breaks the harness — re-run `perform-cyc-testing-initializations` to recover. This is a common SubL-era pattern: a flag that *must* be re-set after dev-time recompiles. A clean rewrite should drop the flag entirely; type predicates should be defined unconditionally.

## Test result vocabulary

Three lexical lists carve up the result space:

| Name | Members | Meaning |
|---|---|---|
| `*cyc-test-result-success-values*` | `:success`, `:regression-success` | Counted as success. |
| `*cyc-test-result-failure-values*` | `:failure`, `:regression-failure`, `:abnormal`, `:error` | Counted as failure. |
| `*cyc-test-result-ignore-values*` | `:non-regression-success`, `:non-regression-failure`, `:not-run`, `:invalid` | Excluded from success/failure tallies. |

The "regression" qualifier is for tests that have a known prior status — a `:regression-failure` is a test that previously succeeded and now fails, weighted differently in summary reporting. `:abnormal` is reserved for tests whose run aborted unexpectedly (Lisp error mid-test). `:invalid` is for tests that mention a constant that no longer exists (`cyc-test-mentions-invalid-constant?`) — they're skipped and not counted.

`*cyc-test-result-values*` is the union; `cyc-test-success-result-p` / `cyc-test-failure-result-p` / `cyc-test-ignore-result-p` are the membership predicates.

## Verbosity and output format

Two parallel sets of knobs flow through every runner entry point as keyword arguments:

- **Verbosity**: `:silent`, `:terse`, `:verbose`. Default `:terse`. Carried in `*cyc-test-verbosity-levels*`. `run-cyc-test-verbose` is the convenience wrapper that hard-binds `:verbose`.
- **Output format**: `:standard` (text) or whatever else the runners support (the LarKC strip lost the alternates). Carried in `*it-output-format*` (a defparameter, default `:standard`).

Both knobs propagate down through every `run-cyc-test-*` entry point and every `print-cyc-test-*` helper. They're keyword args rather than dynamic vars so individual runs can override without `let`-binding.

## Run entry points

`run-cyc-test name &key verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?` — defmacro that expands to `run-cyc-test-int` (the helper is registered with `register-macro-helper`, so the API publication infrastructure can find it). Looks up by name, dispatches by type:

- `:iut` → `run-cyc-test-iut`
- `:it`  → `run-cyc-test-it`
- `:rmt` → `run-cyc-test-rmt`
- `:tmt` → `run-cyc-test-tmt`
- `:rmct` → `run-cyc-test-rmct`
- `:ert` → `run-cyc-test-ert`
- `:tct` → `run-cyc-test-tct`
- `:kct` → `run-cyc-test-kct`

All eight per-type runners are LarKC-stripped. The dispatching layer (`run-cyc-test-object`) is also stripped but its job is clear: read the type from the cyc-test, route to the right runner, capture the result into a `cyc-test-run` record.

`run-cyc-test-parallel name &key nthreads ntimes ...` — same dispatcher, but spawns `nthreads` worker threads and runs the test `ntimes` per thread. Used to expose threading bugs in inference modules. The inner helper `run-cyc-test-parallel-int` is the registered macro-helper.

`run-cyc-test-verbose name &key ...` — convenience macro pinning `:verbose` verbosity.

## File-level registration

Tests are organized into files. A `cyc-test-file` is a 2-slot defstruct (`(:conc-name "CTF-")`):

| Slot | Meaning |
|---|---|
| `filename` | Pathname of the `.lisp` test file. |
| `kb` | Which KB this file's tests need — `:tiny`, `:full`, etc. (`cyc-test-kb-p` is the predicate, LarKC-stripped). |

`(declare-cyc-test-file filename :kb tag)` registers a file in `*cyc-test-files*`. Forms read from a `.testdcl` file (one per directory) — see `parse-testdcl-path` and `load-testdcl`. The expanded form is a call to `declare-cyc-test-file-int` (registered as macro-helper).

## Loading and running a directory

`(load-all-cyc-tests path &optional stream verbosity stop-at-first-failure?)` — walk a directory tree, find every `.testdcl`, load it (which calls `declare-cyc-test-file` for each test file declared), then load each declared file. Failures during file load are collected in `*most-recent-cyc-test-file-load-failures*`. As each file loads, every `(define-test-case-table ...)` (or sister macro) inside it calls `new-cyc-test` against `*cyc-test-filename*` (a defparameter bound to the current file during load) — that's how the file→test back-pointer is established.

`(run-all-cyc-tests path &key stream verbosity stop-at-first-failure? output-format ...)` — loads everything and runs it. Macro that expands to `run-all-cyc-tests-int`. Header/footer printing splits across `run-all-loaded-cyc-tests-print-header` / `print-failing-cyc-tests-message` / `print-succeeding-cyc-tests-message` / `print-ignored-cyc-tests-message`.

`(run-all-loaded-cyc-tests &key ...)` — same as above but skips loading. The `*most-recent-cyc-test-runs*` is populated here.

`(rerun-failing-cyc-tests &key ...)` — convenience macro: take the failures from `*most-recent-cyc-test-runs*`, rerun those.

`(run-cyc-tests names &key ...)` — given a list of names (resolved via `find-cyc-tests-by-name`, the DWIMming form), run only those.

The keyword `:run-tiny-kb-tests-in-full-kb?` (default `t`, controlled by `*run-tiny-kb-tests-in-full-kb?*`) governs whether tests tagged `:kb :tiny` should be skipped when the running image has the full KB loaded — defaults to "include them" so a single test pass covers everything. The flag exists because a few tests truly only make sense against the tiny KB and would fail on full.

## Result records

Each per-type runner produces a `cyc-test-run`. Slots (all accessor names exist as LarKC-stripped declareFunctions; the struct definition itself is also stripped, but the accessors imply it):

- `type` — the test's `:iut`/`:tct`/etc keyword
- `name` — the test name
- `result` — one of `*cyc-test-result-values*`
- `time` — wall-clock duration
- `cyc-test` — back-pointer to the wrapper
- `owner` — the test's responsible person (cyclist string)
- `project` — project this test belongs to

`cyc-test-runs-overall-result runs` aggregates a list of runs into a single result via `cyc-test-result-update old new` (the lattice `:success ⊓ :failure → :failure`, etc.) — implementation LarKC-stripped, but the contract is clear.

`new-cyc-test-null-run ct` and `new-cyc-test-invalid-run ct` are constructors for the "didn't run" cases (no-op or constants-invalidated).

`failing-cyc-test-run-p`, `succeeding-cyc-test-run-p`, `ignored-cyc-test-run-p` partition runs into the three buckets.

## Real-time pruning carve-out

`*test-real-time-pruning?*` (default `nil`) and `*tests-that-dont-work-with-real-time-pruning*` (a deflexical list of ~150 test name keywords) carve out a known subset of tests that fail under Cyc's real-time pruning mode (where `:compute-answer-justifications?` is forced to `nil` and problem-store pruning happens during inference). The variable's docstring spells out the constraint; the list is the empirical exclusion set, accumulated by hand over the project's history. A clean rewrite should not bake this list into source — it's better as KB metadata or per-test annotations.

## CFASL hooks

Two wide opcodes are carved out for serializing cyc-test wrappers:

| Opcode | Wire form |
|---|---|
| 514 (`*cfasl-wide-opcode-cyc-test*`) | A `cyc-test` wrapper. `cfasl-wide-output-cyc-test` and `cfasl-input-cyc-test` are LarKC-stripped, but the opcode is registered. |

The point is to allow test runs to dump/load test results across image boundaries. The output method is registered onto the global `cfasl-output-object` generic; the input opcode is registered with `register-wide-cfasl-opcode-input-function` in the toplevel block.

## Initialization sequence

`(perform-cyc-testing-initializations)`:
1. `index-all-cyc-tests-by-name` — walk `*cyc-tests*`, install each in the two name tables.
2. `setf *cyc-tests-initialized?* t` — flip the gate, so subsequent registrations use the full type-check path.
3. Returns `nil`.

Called once at image startup, after every test file has been loaded. If `*cyc-tests*` is populated dynamically later (REPL test definitions), `index-cyc-test-by-name` runs against the already-initialized harness and uses the strict path.

## Notes for a clean rewrite

- **Drop `*cyc-tests-initialized?*`.** The two-mode validation only exists because LarKC-stripped predicates can't reliably typecheck `guts`. In a clean rewrite, every test type has its predicate, and pre/post-init become identical.
- **Use a single typed slot, not a `guts` polymorphism.** Common Lisp has classes; the eight test types should be subclasses of a `cyc-test` superclass with `run-cyc-test`, `cyc-test-name`, `cyc-test-type`, `cyc-test-kb` as generic functions. The current `cyc-test-guts-type` cond-cascade is a `case` over what should be method dispatch.
- **Drop the macro-helper indirection.** `define-test-case-table` → `define-test-case-table-int`, `run-cyc-test` → `run-cyc-test-int`, etc., are all macro-helper pairs that exist because the SubL API publisher introspects helpers. In a clean Lisp rewrite the macro can do the work directly; the helpers are only needed if the API surface introspects them.
- **The `*cyc-test-by-dwimmed-name*` table is doing too much.** Multiple-mapping by name is a UX feature ("the user typed `:foo`, did they mean `:foo` or `'foo'?") that should be a separate `find-cyc-tests` search function over `*cyc-test-by-name*`, not a parallel pre-built index.
- **`*tests-that-dont-work-with-real-time-pruning*` should not be a hardcoded list.** Annotate each test with a `:real-time-pruning-safe? nil` flag in its definition; collect the list at run time. The current single deflexical means every test author has to remember to update one file in another part of the tree.
- **The CFASL hook for cyc-test serialization is unfinished.** Both ends (`cfasl-output-cyc-test-internal` and `cfasl-input-cyc-test`) are LarKC-stripped. If cross-image test result transport is wanted, finish it — otherwise drop the opcode reservation.
- **The `:run-tiny-kb-tests-in-full-kb?` keyword should default `nil` and be opt-in.** Defaulting to "include" means every full-KB test run pulls in tiny-KB tests too, which doubles the runtime for what's usually noise. Make the explicit `:tiny`-and-`:full` matrix opt-in.
- **Replace `register-defglobal` with normal Lisp dump/load.** The defglobal-with-boundp-guard pattern exists to survive image dumps, which is a SubL-era image-persistence concern; a clean rewrite that lives off `.fasl`s and starts fresh per process doesn't need this.
- **`new-cyc-test` should not silently delete a duplicate.** The current path `(setf *cyc-tests* (delete existing-ct *cyc-tests* :test #'eq))` followed by a `missing-larkc 32458` removal-from-name-table call is a redefinition path. It works but it's quiet — a redefining `define-test-case-table` should warn at minimum.
