# Generic test-case tables

A **test-case table** is the generic, KB-agnostic test type. It's parameterized by a function-under-test and a list of `(input-args . expected-result)` tuples; running the table means calling the function on each tuple's input args and asserting the result matches the tuple's expected output. Think `assertEqual` in xUnit — that's the entire model.

This is the only test type whose runner Cyc actually exposes broadly via `(define-test-case-table ...)` in arbitrary `.lisp` files; the inference/removal/transformation/etc. test types are specialized for testing pieces of the inference engine and have their own define-macros (see [inference-tests.md](inference-tests.md)).

The implementation is `cyc-testing/generic-testing.lisp`. Most runner bodies are LarKC-stripped, but the struct, the registration path (`define-test-case-table-int`), the master indexes, and the CFASL hooks are intact.

## The `generic-test-case-table` struct

A `generic-test-case-table` is a 7-slot defstruct (`(:conc-name "GTCT-")`):

| Slot | Type | Meaning |
|---|---|---|
| `name` | symbol or keyword | The test's name. Must satisfy `test-case-name-p` (a symbol; LarKC-stripped predicate, but evidence points to `symbolp`). |
| `tuples` | list of `(input . expected)` lists | The test cases. Each tuple is a proper list of length ≥ 2: `(input-arg-1 input-arg-2 ... expected-result)`. The last element is what the test compares against; everything before it is the args list passed to the function-under-test. The "function-of-N-args returning a single value" model. |
| `test` | function or symbol | The equality test. Default `#'equal`. Common alternatives are `equalp` (case-insensitive strings, numeric coercion) and `eq` (identity). Validated by `function-spec-p` — symbols and function objects both work. |
| `owner` | string or nil | Cyclist responsible for the test. Optional. |
| `classes` | list of keywords | Tags for grouping tests. A test in classes `(:fast :readonly)` can be run by `(run-test-case-tables-of-class :fast)`. The class index is `*test-case-tables-by-class*`. |
| `kb` | keyword | KB requirement: `:tiny`, `:full`, or whatever else `cyc-test-kb-p` accepts. Default `:tiny`. |
| `working?` | boolean | If `nil`, the test is known broken and excluded from default runs (unless `:run-non-working-tests t` is passed). Default `t`. |

`make-generic-test-case-table` accepts a property-list initializer. `make-generic-test-case-table-struct` is the bare defstruct constructor. The "kw-init list with `case` dispatch" pattern is uniform across the cyc-testing files — `:name`, `:tuples`, `:test`, etc. — and unrecognized keys signal an error.

`new-generic-test-case-table name tuples test owner &optional classes (kb :tiny) (working? t)` is the validated constructor. It performs:

- `name` must satisfy `test-case-name-p`
- `tuples` must be a non-dotted list
- `test` must satisfy `function-spec-p`
- if `owner` non-nil, must be a string
- if `classes` non-nil, must be a list
- `kb` must satisfy `cyc-test-kb-p`
- each `tuple` must be a proper list of length ≥ 2

If `test` is `nil`, defaults to `#'equal`.

## Master tables

| Variable | Type | Purpose |
|---|---|---|
| `*test-case-table-index*` | hashtable, default `eql` test, size 212 | name → `generic-test-case-table`. The fast lookup. |
| `*ordered-test-cases*` | ordered list | name list in registration order. Defines the iteration order of `run-all-test-case-tables`. |
| `*test-case-tables-by-class*` | hashtable, size 64 | class keyword → list of test names. The "tests of class :fast" inverted index. |

All three are populated by `define-test-case-table-int`. The first two are `defglobal`; the third is `deflexical` (built once at file-load time and never replaced — it's a pure index, not state).

## The define-macro

`(define-test-case-table name (&key test owner classes (kb :tiny) (working? t)) &body tuples)` is the public face. It expands to a call to `define-test-case-table-int` (registered as a macro-helper):

```lisp
(define-test-case-table :string-upcase-table
    (:test #'string=
     :owner "alice@cyc.com"
     :classes (:string :fast)
     :kb :tiny)
  ((("hello") "HELLO")
   ((" abc ") " ABC ")
   ((""))    "")
```

Each tuple is a list — the leading sublist is the args list passed via `apply` to the function under test (resolved by `name`); the final element is the expected result. The `properties` argument-list to `define-test-case-table-int` is constructed positionally as `(list :owner ... :test ... :classes ... :kb ... :working? ...)`, then deconstructed by `define-test-case-table-int` via `destructuring-bind`.

`define-test-case-table-int name properties tuples`:
1. Build a `generic-test-case-table` via `new-generic-test-case-table`.
2. For each `class` in the test's classes, `adjoin` the test name to `*test-case-tables-by-class*`.
3. `pushnew-last` the name onto `*ordered-test-cases*` (uniquified by `eql`).
4. Install in `*test-case-table-index*`.
5. Wrap in a `cyc-test` and register via `(new-cyc-test *cyc-test-filename* gtct)`.
6. Return the test name.

The `*cyc-test-filename*` defparameter is a dynamic var bound during `load-cyc-test-file` — it lets the test know what file it came from.

## Test results

A test-case table run produces a single result drawn from `*generic-test-results*`:

- `:success` — every tuple's actual result matched the expected via `test`.
- `:failure` — at least one tuple's result didn't match.
- `:error` — a tuple invocation signaled a Lisp error.
- `:not-run` — the test was excluded (wrong KB, `working? nil`, etc.).
- `:invalid` — the test references a constant that no longer exists.

The aggregation function `generic-test-result-update old new` (LarKC-stripped) implements the lattice merge: `:success ⊓ :failure → :failure`, `:not-run` is the bottom element, `:invalid` is sticky, etc. This is the same lattice as the cyc-test result vocabulary, just narrowed to test-case-table-relevant values.

## Verbosity levels

`*generic-test-verbosity-levels*` = `(:silent :terse :verbose :post-build)`. Same shape as the harness verbosity, plus a `:post-build` mode whose token is `:tct` — read by the post-build test runner to identify these as the test-case-table category.

`*test-case-table-post-build-token*` = `:tct` is the post-build identifier. Post-build is Cycorp's term for the test pass that runs as part of every nightly KB build.

## Runner entry points (all LarKC-stripped)

| Function | Effect |
|---|---|
| `run-test-case-table name &optional verbosity stream output-format` | Run one named table. |
| `run-all-test-case-tables &optional stream verbosity output-format stop-at-first-failure?` | Walk `*ordered-test-cases*`, run each. Aggregate results. |
| `run-test-case-tables-of-class class &optional ...` | Run only tests tagged with `class`. |
| `run-test-case-tables tables &optional ...` | Run a specific list of named tables. |
| `run-generic-test-case-int gtct verbosity stream output-format` | The core dispatch — resolve the function, walk tuples. |
| `run-test-case-table-int name gtct tuples verbosity stream output-format stop-at-first-failure?` | The looping body. |
| `run-test-case-table? gtct` | Predicate: should this test run given current `*run-tiny-kb-tests-in-full-kb?*`, working flag, etc. |
| `run-test-case-tuple-int name tuple test verbosity stream output-format` | One tuple. |
| `determine-run-test-case-tuple-result tuple test output-format` | Apply the function, compare via `test`, decide success/failure/error. |
| `get-gtct-by-name name` | `gethash` against `*test-case-table-index*`. |
| `test-case-classes name` | Reverse: name → classes. |

The print helpers (`run-test-case-table-print-header`/`-footer`, `run-test-case-tuple-print-header`/`-footer`) emit the per-test and per-tuple banner/result lines.

## CFASL hooks

| Opcode | Wire form |
|---|---|
| 512 (`*cfasl-wide-opcode-generic-test-case-table*`) | A serialized `generic-test-case-table`. The output methods `cfasl-output-object-generic-test-case-table-method` and `cfasl-wide-output-generic-test-case-table` are LarKC-stripped; the input function `cfasl-input-generic-test-case-table` is registered with the wide-opcode dispatch table. |

The intended use is to dump test definitions cross-image — useful for shipping a "tested-against-this-KB" manifest with a KB dump. Practically, the LarKC strip means it doesn't currently work, and tests are loaded from `.lisp` source instead.

## Initialization sequence

The toplevel block in `generic-testing.lisp`:
1. `declare-defglobal '*test-case-table-index*` — register for image-dump.
2. `declare-defglobal '*ordered-test-cases*` — same.
3. `register-macro-helper 'define-test-case-table-int 'define-test-case-table` — publish to the API.
4. `register-wide-cfasl-opcode-input-function 512 'cfasl-input-generic-test-case-table` — wire the opcode.

No reset/init function — the indexes accumulate as `.lisp` files load and `define-test-case-table` forms execute. `undefine-test-case-table name` and `undefine-all-test-case-tables` (LarKC-stripped) are the inverse, used during dev for redefinition.

## Notes for a clean rewrite

- **Tuples should be `(input-list expected-result)` two-tuples**, not "proper list of length ≥ 2 with last element as the expected." The current shape is hostile to readability — it's not visually obvious that the last element is special. Make the test definition explicit:
  ```lisp
  (define-test-case-table :upcase
      (:test #'string=)
    (((args "hello") :expected "HELLO"))
  ```
- **Replace `*test-case-tables-by-class*` with computed lookup.** The class index is built at registration time, but classes change rarely — a `(remove-if-not (lambda (n) (member class (gtct-classes (gethash n index)))) order)` over the few hundred tests is fast enough and removes a parallel structure to maintain.
- **`pushnew-last` is the wrong primitive.** It's O(n²) over the test-case set as you add tests during file load — for hundreds of tests this is fine, but if Cyc grows to thousands it will dominate startup. Use a `vector` with `vector-push-extend`, or accept that order doesn't matter and use a list with `push` + `nreverse` once.
- **`function-spec-p` is too lax.** Accepting "symbol or function object" makes errors deferred (a nonexistent symbol fails inside the runner, not at definition). Resolve the function at definition time and store the function object; signal at definition if it doesn't exist.
- **Drop `:working? nil`.** A non-working test is just commented-out test code with worse maintenance properties. If a test is broken, fix it or delete it; `:working? nil` is a dishonest "we'll get to it later" that lasts forever.
- **The `:kb :tiny` default is fine, but the runtime carve-out (`run-tiny-kb-tests-in-full-kb?`) is the wrong shape.** Tests that are tiny-KB-only and tests that are tiny-KB-or-better should be different annotations, not a runtime flag that flips meaning.
- **CFASL serialization of tests is dead code; remove it.** Tests are source-of-truth in `.lisp` files. There's no scenario where dumping test definitions to a binary blob beats just shipping the `.lisp` file. Drop opcode 512 and the methods.
- **The `:post-build` verbosity is a separate concern.** Post-build reporting is a different output format (machine-parseable), not a verbosity level. Split it out.
