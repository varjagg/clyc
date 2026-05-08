# Value tables

A trio of structs — `value-table-column`, `value-table`, `variable-mapping-table` — that, in real Cyc, back a query-driven tabular data feature: rows of input-column values keyed by a query result, an output column produced by another query, and a sibling mapping from one query's variables to another's. The LarKC port contains only the struct shells. **Every constructor, accessor wrapper, query loader, and XML serializer is missing-larkc**, and **no caller in the Lisp port references any of these structs.** What survives is enough to round-trip the structs through CFASL by `defstruct`-default behavior, nothing more.

## What the engine does with these (from Internal Constants evidence)

The `value_tables.java` Internal Constants section names the predicates that drive the loader:

| Constant | Role |
|---|---|
| `validQueryResultForTable` | A predicate over (table, result-row) — KB-side definition of which result tuples are admitted into a table. |
| `valueTableSourceQueries` | Per-table: the queries whose results populate the input columns. |
| `valueTableTargetQuery` | Per-table: the single query whose results populate the output column. |
| `queryResultsCombineInTable` | The combining relation that ties input-column values to an output-column value. |
| `variableMappingTableSourceFormula-QuerySpec` | Per-mapping-table: source query specification. |
| `variableMappingTableTargetFormula-QuerySpec` | Per-mapping-table: target query specification. |
| `querySpecVariablesUnifyInTable` / `querySpecVariablesUnifyInTable-WorkaroundPred` | Records that two query-specification variables unify (or are intentionally non-unifiable) under a given mapping. |

So this is **a KB-asserted query→table feature**: Cyc lets a user define a `#$ValueTable` constant in the KB, declare which queries fill its input columns, declare a target query for the output column, and have the engine materialize a row-set the user can iterate. The `variable-mapping-table` is the related construct that records how the variables of one query specification are renamed/unified into another's — so two `query-specification`s that share variables under different names can have results joined.

## Public API (value-tables.lisp) — what survives

| Item | Status |
|---|---|
| `defstruct value-table-column` (3 slots: `query`, `label`, `values`) | Present. `make-value-table-column`, accessors, setf accessors all auto-generated. |
| `defstruct value-table` (5 slots: `id`, `label`, `input-columns`, `output-column`, `assignments`) | Present. Accessors auto-generated. |
| `defstruct variable-mapping-table` (7 slots: `id`, `source-query`, `target-query`, `source-variables`, `target-variables`, `incompatibles`, `assignments`) | Present. Accessors auto-generated. |
| `*dtp-value-table-column*`, `*dtp-value-table*`, `*dtp-variable-mapping-table*` | Constants holding the dtp symbol. Used by CFASL polymorphism. |
| `(toplevel (note-memoized-function 'any-disjoint-with-any?-memoized) (register-external-symbol 'varmap-unique-el-var-wrt-vars))` | The only live setup forms. |

Every other entry point in the file is a **commented declareFunction** (i.e. a stub) — listed below grouped by what they were meant to do:

### value-table-column
- `new-value-table-column query` — mint a fresh column for a given query.
- `load-value-table-column-from-kb column term mt` — read column data from the KB under `mt`.
- `xml-serialize-value-table-column column &optional stream` — XML round-trip.
- `get-vtbl-query-result-values column term mt` / `get-vtbl-query-result-sets column term mt` — execute the column's query and collect either a flat values list or per-row result sets.
- `print-value-table-column object stream depth` — print method (CL's default print-object covers this).

### value-table
- `new-value-table term` — mint a value-table from a KB term that names one.
- `load-value-table-from-kb table mt` — load all of a table's content from KB.
- `xml-serialize-value-table table &optional stream` — XML round-trip.
- `get-vtbl-input-queries table mt` / `get-vtbl-output-query table mt` — fetch the source and target queries from the KB.
- `load-value-table-assignments-from-kb table mt` — populate the `assignments` slot by running queries.
- `print-value-table` — print method.

### variable-mapping-table
- `new-variable-mapping-table term` — mint from a KB term.
- `load-variable-mapping-table-from-kb table mt &optional source-formula target-formula` — load mapping definition.
- `get-variable-mapping-table-for-formulas term source-formula target-formula &optional source-mt target-mt` — fetch the right mapping table for a (source-formula, target-formula) pair.
- `varmaptbl-assign-queries table source-query target-query mt` — bind the queries to the table.
- `varmaptbl-load-source-query-information table mt` / `varmaptbl-load-target-query-information table mt` — pull per-side query-spec details (variables, formula, mt).
- `varmaptbl-assign-variable-information table mt` and the `-from-formulas` overload — populate `source-variables` / `target-variables` from queries or from raw formulas.
- `varmaptbl-store-variable-information table var isas genls` — record per-variable type info.
- `varmaptbl-load-query-variable-information table mt` — pull each variable's isas/genls from the KB.
- `varmaptbl-assign-current-assignments table mt` / `varmaptbl-load-current-assignments table source-var target-var mt` — populate the `assignments` slot, the actual variable-pair unification table.
- `varmap-autocombine-literals table &optional source-mt target-mt combine-fn` — automatic unification of literals.
- `varmap-uniquify-source-vars formula vars` / `varmap-unique-el-var-wrt-vars var vars` — generate fresh variables that don't collide with a given set. The latter is the only one explicitly registered as an external symbol.
- `varmap-attempt-to-combine-variables source-var target-var table &optional source-mt target-mt` — try to unify a source/target variable pair.
- `any-disjoint-with-any?-memoized-internal isas genls mt` / `any-disjoint-with-any?-memoized isas genls mt` — disjointness check used during variable unification, registered as a memoized function.
- `print-varmap-table object stream depth` — print method.
- `xml-serialize-variable-mapping-table table &optional stream` — XML round-trip.

## Where this fits

**Zero callers in `larkc-cycl/`.** The only references to the file are:

- `system-version.lisp` line 619 — the string `"value-tables"` in the cycl-module manifest (informational, not a call site).
- `disjoint-with.lisp` — a commented stub of the unrelated `any-disjoint-with-any?` (the non-memoized version), not a caller of the memoized one in this file.

In the Java tree the only non-self caller is `inference/modules/removal/removal_modules_conjunctive_pruning.java`, which has a bare `import com.cyc.cycjava.cycl.value_tables;` — its actual usage is LarKC-stripped, so the link to the conjunctive-pruning removal module is real but invisible in the port. This connects the value-table machinery to **conjunctive query pruning**: when a query is being broken into a conjunction of subqueries, the planner can consult a value-table that pre-stores known answer tuples for some sub-pattern and avoid re-running it.

## CFASL

No explicit CFASL opcode for value-tables, value-table-columns, or variable-mapping-tables — they fall through to the generic `defstruct` CFASL dispatch via `*dtp-*` constants. If a clean rewrite needs persistence, it gets it for free from the host's serializer.

## Notes for a clean rewrite

- **All function bodies are missing-larkc.** This is a pointer to required behavior, not a permission to delete. The full Cyc engine implements the value-table feature; the LarKC port stripped it. A clean rewrite that targets parity with full Cyc must reimplement: `new-value-table`, `load-value-table-from-kb`, `get-vtbl-input-queries`, `get-vtbl-output-query`, `load-value-table-assignments-from-kb`, plus the variable-mapping-table family.
- **The data model is sound; reuse it.** Three structs split as (column / table / variable-mapping) reflect the right separation. A clean rewrite should keep the shape and reimplement the loaders.
- **The runtime sole consumer is the conjunctive-pruning removal module.** Verify before deletion that no other system uses value-tables — if conjunctive-pruning is the only caller and that module isn't a priority, the entire feature can be deferred.
- **`varmap-unique-el-var-wrt-vars` and `any-disjoint-with-any?-memoized` are registered as external/memoized.** They survive in the symbol-table register but neither has a body. The memoization registration is a hint that the disjointness check is hot — the variable-unification phase calls it for every (isas, genls, mt) triple it considers, and answers are stable across calls within an inference session.
- **XML serialization is probably dead in modern Cyc.** The `xml-serialize-*` entry points likely target an older Web-of-Cyc export format. A rewrite should pick CFASL or JSON, not revive the XML path.
- **Drop `print-*` stubs entirely.** CL's default print-object prints structs adequately; the SubL print trampolines that the comments reference are vestiges of the SubL printer machinery and don't need to come back.
- **The "tabular data" abstraction is general enough to be its own subsystem.** A clean rewrite should consider whether value-tables belongs in `data-structures/` (where it sits today) or alongside the inference modules, since its data model is tightly coupled to query-spec / query-results.
