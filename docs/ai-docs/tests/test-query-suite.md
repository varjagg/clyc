# Test query suite

A `test-query-suite` is a **named, KB-keyed collection of CycL queries** for a single test scenario. Distinct from KCT (whose tests live in the KB) and from inference unit tests (whose definitions live in `.lisp` source), a test-query-suite is a *Lisp-side* container that groups several queries under a single CycL-id and MT, so a runner can iterate them as a unit.

The implementation is `larkc-cycl/test-query-suite.lisp`. The file is structurally self-contained — 86 lines, one struct, twelve LarKC-stripped helpers, and *no consumers anywhere else in the codebase*. The only external mention is a literal string in `system-version.lisp` (the file-loading manifest). In the LarKC port, this code is dormant.

A clean rewrite has two reasonable choices: (1) keep the struct as a useful primitive for grouped-query test definitions if such a feature is wanted later, or (2) drop the file entirely. This doc captures what the type *is* in case a future feature wants it.

## The `test-query-suite` struct

A 4-slot defstruct (`(:conc-name "TEST-STE-")`):

| Slot | Meaning |
|---|---|
| `cycl-id` | The CycL-side identifier — likely a string or a constant — that names this suite. The "primary key". |
| `comment` | Free-text comment describing the suite. |
| `mt` | The microtheory in which the suite's queries should be run. One MT per suite. |
| `queries` | A list of queries belonging to this suite. The query type isn't pinned down by this file; from the helper names below, queries appear to have their own per-query ids and individual comments. |

The conc-name `TEST-STE-` is **a typo or an abbreviation of "suite"** — `STE` for *suite*. Reflected in every accessor: `test-ste-cycl-id`, `test-ste-comment`, etc. Other test-related defstructs in `cyc-testing/` use sensible conc-names (`CT-`, `GTCT-`, `IUT-`, `RMT-`, etc.); this one is alone in being abbreviated. A clean rewrite should fix this to `TQS-` or just spell it out.

`*dtp-test-query-suite*` = `'test-query-suite` is the standard type-tag constant.

## Operations (all LarKC-stripped)

The active declareFunctions imply this API:

| Function | Implied purpose |
|---|---|
| `test-query-suite-cycl-id suite` | Slot accessor (wrapper around `test-ste-cycl-id`). |
| `test-query-suite-comment suite` | Slot accessor. |
| `test-query-suite-mt suite` | Slot accessor. |
| `test-query-suite-queries suite` | Slot accessor. |
| `test-query-suite-print object stream depth &optional length` | The `print-object` body. |
| `test-query-suite-get cycl-id &optional mt` | Lookup by CycL-id. The `&optional mt` argument suggests a global table keyed by `(cycl-id, mt)`, with `mt` defaulting to nil for global lookup. |
| `test-query-suite-find-query-by-id suite query-id` | Find one query inside a suite by its query-id. |
| `test-query-suite-set-queries suite queries` | Replace the queries list. |
| `test-query-suite-find-query-siblings suite query` | "Sibling" relation among queries in a suite — likely "queries with the same parent question or topic". |
| `test-query-suite-new cycl-id mt` | Constructor. Note the lack of a `name` or `comment` arg — those are likely set later via slot setters. |
| `cycl-query-specification-comment-comparator spec-a spec-b` | A comparator used in sorting — sorts CycL query specifications by their comment. Uses `cycl-query-specification` from [canonicalization/cycl-query-specification.md](../canonicalization/cycl-query-specification.md). |
| `test-query-suite-sort-by-comment suite` | Sort a suite's queries by their associated comment. |

Notably absent: any `define-test-query-suite` macro, any `*test-query-suites*` master table, any runner. The runner-side and the registration-side are both LarKC-stripped or never existed. The struct alone is what survives.

## Relationship to other test types

The struct shape suggests test-query-suite was meant to be a **layer above** an inference-unit-test or a query-specification. The slots:

- `cycl-id` (one CycL identifier per suite)
- `mt` (one MT per suite)
- `queries` (many queries)

…is the natural shape for "test the same scenario against a fixed MT, but with several different ASK forms" — a regression suite for a single CycL feature. Compare to:

- IUT: one sentence, one expected result, with optional followups. Followups are *chained* (next query uses parent's bindings).
- Test-case-table: one function-under-test, many input/output tuples. Generic, not CycL-specific.
- KCT: one query per test, defined in KB. KB-driven.

A test-query-suite is closer in spirit to "a small KCT collection that you happen to define in Lisp source, where queries are *parallel* (no chaining) but *share an MT*."

The unique value would have been: in a test-case-table, the function-under-test must be a Lisp function (not a CycL ASK); in IUT, multiple queries require either followups (which constrain by binding-substitution) or separate top-level IUTs (which lose the shared-MT setup). A test-query-suite would have been the missing third option: parallel CycL queries, shared MT, one identity. The fact that nothing consumes the type in the LarKC port suggests this layer was never finished.

## Notes for a clean rewrite

- **Drop the file.** No consumer in the codebase, no runner, no registration mechanism. If a "grouped queries with shared MT" test type turns out to be needed later, design it then with the requirements in hand.
- **If kept, fix the conc-name.** `TEST-STE-` is unreadable. `TQS-` or full `TEST-QUERY-SUITE-` is the right shape, matching the rest of the test-types directory.
- **If kept, give it a `*test-query-suites*` table and a registration macro.** Without those, the struct is unreachable from the harness.
- **The `cycl-query-specification-comment-comparator` is misplaced.** Comparing query specifications by comment is a query-specification concern, not a suite concern; if the function is needed it belongs in `cycl-query-specification.lisp`.
- **The `:queries` slot type is unspecified in the source.** Pin it down: are queries `cycl-query-specification` instances, raw EL forms, or CycL-string id references? The choice determines a lot.
