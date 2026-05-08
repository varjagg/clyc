# CycL query specification

A **query specification** is the *KB-level representation of a query*: a CycL constant whose attached assertions describe a stored, executable query. Where the inference engine's `query-properties` plist (see "Inference parameters" doc) is a runtime data structure, a query specification is a *KB object* — `(testQuerySpecification <test> <query-spec-id>)` GAFs link tests to their specifications.

There are two generations of the specification:
1. **`cycl-query-specification`** — the *legacy* spec with hardcoded fields for the named inference parameters (max-results, time-cutoff, etc.)
2. **`new-cycl-query-specification`** — the *modern* spec with a generic property plist + indexicals + edited-flag

The modern spec is what new code uses; the legacy spec is preserved for backward compatibility with KB-stored queries that haven't been migrated.

The system is mostly missing-larkc in the LarKC port — only the struct definitions and registry scaffolding survive. The clean rewrite must reconstruct the methods.

Source files:
- `larkc-cycl/cycl-query-specification.lisp` (154) — legacy spec
- `larkc-cycl/new-cycl-query-specification.lisp` (128) — modern spec

## Why a KB-level spec?

Query-properties plists work fine for runtime queries. But for *stored* queries — KBQ test cases, regression tests, parameterised templates — you want:
1. A **CycL identity** (a constant) so the query can be referenced from other assertions
2. **Persistence** across image restarts (KB load brings them back)
3. **Inheritance and parameterisation** — one spec can be a template that other specs instantiate
4. **KB-level metadata** — comments, edit history, indexicals (variables that get substituted at run time)

A query specification is the answer. It lives in the KB as an instance of `#$CycLQuerySpecification` (or its modern equivalent). The struct in this code is the in-memory cache layer.

## Legacy: `cycl-query-specification`

Defstruct with 15 fields:

```lisp
(defstruct cycl-query-specification
  cycl-id                         ; the constant denoting this spec
  formula                         ; the query formula
  mt                              ; the microtheory
  comment                         ; human-readable comment
  max-number-of-results
  back-chaining
  time-cutoff-secs
  max-depth
  removal-cost-cutoff
  enable-negation-by-failure
  enable-hl-predicate-backchaining
  enable-cache-backwards-query-results
  enable-unbound-predicate-backchaining
  enable-semantic-pruning
  enable-consideration-of-disjunctive-temporal-relations)
```

Each field corresponds to a runtime inference parameter:
- `max-number-of-results` ↔ `:max-number`
- `back-chaining` ↔ `:max-transformation-depth`
- `time-cutoff-secs` ↔ `:max-time`
- `max-depth` ↔ `:max-proof-depth`
- `removal-cost-cutoff` ↔ `:productivity-limit` (after multiplication)
- `enable-negation-by-failure` ↔ `:negation-by-failure?`
- `enable-hl-predicate-backchaining` ↔ `:allow-hl-predicate-transformation?`
- `enable-cache-backwards-query-results` ↔ `:cache-inference-results?`
- `enable-unbound-predicate-backchaining` ↔ `:allow-unbound-predicate-transformation?`
- `enable-semantic-pruning` ↔ a part of `:transformation-allowed?` etc.
- `enable-consideration-of-disjunctive-temporal-relations` ↔ time-related option

`*dtp-cycl-query-specification* = 'cycl-query-specification` — the dtype constant.

### Operations (mostly missing-larkc)

```
cycl-query-specification-cycl-id(spec)         → cycl-id
cycl-query-specification-formula(spec)          → formula
cycl-query-specification-mt(spec)               → mt
cycl-query-specification-comment(spec)          → comment
cycl-query-specification-max-number-of-results(spec)
cycl-query-specification-back-chaining(spec)
cycl-query-specification-time-cutoff-secs(spec)
cycl-query-specification-max-depth(spec)
cycl-query-specification-conditional-sentence?(spec) → boolean
cycl-query-specification-removal-cost-cutoff(spec)
cycl-query-specification-enable-negation-by-failure(spec)
…  (and so on)

cycl-query-specification-copy(spec)             → fresh copy
cycl-query-specification-print(obj, stream, depth) → printable

cycl-query-specification-new()                  → new empty spec
cycl-query-specification-assign-param(spec, param, value)
                                                 → mutate one slot
cycl-query-specification-get(cycl-id, &optional mt)
                                                 → load from KB

cycl-query-specification-set-mt(spec, mt)      → setter

cycl-query-specification-ask-int(spec)           → execute the query, internal
cycl-query-specification-ask(spec)               → execute, public

cycl-query-specification-new-query-from-old(old-spec, formula, mt)
                                                 → build a new spec from an existing one

new-continuable-inference-from-cycl-query-spec(spec)
                                                 → create an inference object
continue-cycl-query-spec-inference(spec, inference)
                                                 → continue an existing inference

static-query-properties-from-cycl-query-spec(spec)
                                                 → produce a static-properties plist
dynamic-query-properties-from-cycl-query-spec(spec)
                                                 → produce a dynamic-properties plist
```

The static/dynamic split mirrors the runtime distinction (see "Inference parameters" doc): some fields are static (set at creation), some are dynamic (can change between continues).

## Modern: `new-cycl-query-specification`

Defstruct with 7 fields:

```lisp
(defstruct new-cycl-query-specification
  cycl-id        ; constant
  formula        ; query formula
  mt             ; microtheory
  comment        ; comment
  properties     ; generic property plist (replaces all hardcoded fields)
  indexicals     ; variables that get substituted at run time
  edited)        ; was this spec modified after KB load?
```

The shift: `properties` is now a generic plist, not hardcoded fields. New parameters can be added without changing the struct.

`*dtp-new-cycl-query-specification* = 'new-cycl-query-specification`.

### Indexicals

An *indexical* is a variable in the query formula that gets substituted at run time. Example: `(isa ?USER #$Cyclist)` where `?USER` is the indexical for "the current user." `instantiate-new-cycl-query-specification-from-template(spec, substitutions, &optional mt)` substitutes the indexicals with concrete values.

`new-cycl-query-indexical-p(object)` — predicate
`new-cycl-query-indexical-formula-p(formula)` — formula-level predicate
`analyse-new-cycl-query-specification-for-indexicals(spec)` — find indexicals in the spec
`templated-new-cycl-query-specification-p(spec)` — does this spec contain indexicals (= is a template)?

### Operations (mostly missing-larkc)

```
new-cycl-query-specification-p(object)
new-cycl-query-specification-cycl-id(spec)       → cycl-id
new-cycl-query-specification-formula(spec)
new-cycl-query-specification-mt(spec)
new-cycl-query-specification-comment(spec)
new-cycl-query-specification-properties(spec)
new-cycl-query-specification-indexicals(spec)
new-cycl-query-specification-edited(spec)

set-new-cycl-query-specification-cycl-id(spec, value)
set-new-cycl-query-specification-formula(spec, formula)
set-new-cycl-query-specification-mt(spec, mt)
set-new-cycl-query-specification-comment(spec, comment)
set-new-cycl-query-specification-properties(spec, properties)
set-new-cycl-query-specification-properties-eliminating-defaults(spec, properties)
set-new-cycl-query-specification-indexicals(spec, indexicals)
set-cycl-query-specification-edited(spec)

create-new-cycl-query-specification()           → fresh empty spec
load-new-cycl-query-specification-from-kb(cycl-id, &optional mt)
                                                 → load from KB by id

new-cycl-query-specification-load-sentence(spec, cycl-id)
                                                 → load just the formula from KB
new-cycl-query-specification-load-mt(spec, cycl-id)
                                                 → load just the mt from KB
new-cycl-query-specification-load-inference-parameters(spec, cycl-id)
                                                 → load the parameter values

copy-new-cycl-query-specification(spec)
                                                 → fresh copy

instantiate-new-cycl-query-specification-from-template(spec, substitutions, &optional mt)
                                                 → make a non-template from a template

new-cycl-query-specification-ask(spec, &optional mt properties substitutions)
                                                 → execute

xml-serialize-new-cycl-query-specification(spec, &optional stream)
                                                 → emit XML form

mark-new-cycl-query-specification-modified(spec)
                                                 → mark as edited

update-query-spec-params-using-defaults(spec, defaults)
                                                 → fill in missing params from defaults

reset-new-cycl-query-specification-formula(spec, formula)
                                                 → re-set the formula (and re-analyse)
reset-new-cycl-query-specification-mt(spec, mt)
                                                 → re-set the mt
```

### The parameter set

`*new-cycl-query-parameter-set*` (defglobal, default nil) — contains all the code mappings for permissible CycL query parameters.

`*new-cycl-query-encoding-extent* = #$CycAPIMt` — the MT where the SubL encoding for inference parameters is stored.

The parameter-set machinery:
- `get-new-cycl-query-parameter-set()` — accessor
- `ensure-new-cycl-query-parameter-set-initialized()` — lazy initialise
- `is-new-cycl-query-parameter-set-initialized?()` — predicate
- `new-cycl-query-parameter-set()` — alternative accessor
- `ncq-inference-parameter-p(object)` — is this object a valid parameter?
- `initialize-new-cycl-query-parameter-set()` — explicit init
- `compute-new-cycl-query-parameter-set()` — recompute the set
- `new-cycl-query-get-all-parameters()` — list all valid parameters
- `new-cycl-query-get-internal-encoding-for-parameter(param)` — get a parameter's internal SubL encoding

The parameter set is *driven from the KB*: assertions in `#$CycAPIMt` describe which inference parameters are permissible and what their internal encoding is. The runtime parameter-set is computed by walking these assertions.

This design lets new parameters be added by KB authors via assertions, without engine code changes.

## When does each piece fire?

| Trigger | Path |
|---|---|
| Test runner loads test cases | `load-new-cycl-query-specification-from-kb` for each test query |
| User opens query editor | `cycl-query-specification-get` (legacy) or `load-new-cycl-query-specification-from-kb` (modern) |
| User saves a query | `mark-new-cycl-query-specification-modified` + KB persistence |
| Test runs | `cycl-query-specification-ask` or `new-cycl-query-specification-ask` |
| Template instantiation | `instantiate-new-cycl-query-specification-from-template` |

## Cross-system consumers

- **KBQ test runner** (`kbq-query-run.lisp`) loads test specifications and runs them
- **Query API** translates incoming user queries to specs when persistence is needed
- **NL generation** uses templates to fill in indexicals
- **KE / Query Editor** loads/saves specs as the user works
- **CFASL** persists specs across image saves
- **Inference engine** consumes the static/dynamic property plists derived from a spec

## Notes for the rewrite

- **Two generations exist.** The clean rewrite should pick one — the modern (new-cycl-query-specification) is more flexible. The legacy can be migrated.
- **The plist-based properties slot** in the modern spec is the right design. New parameters don't require schema changes.
- **Indexicals are templates.** Keep the `templated-new-cycl-query-specification-p` predicate; templates and instantiated specs have different lifecycles.
- **The parameter-set is KB-driven.** This is the elegant part: parameters are defined by assertions in `#$CycAPIMt`. Don't hardcode parameter names in engine code. Read them from the KB.
- **`*new-cycl-query-encoding-extent* = #$CycAPIMt`** — the MT where parameter encodings live. Keep this as a configurable; some deployments may use a different MT.
- **`edited` flag** is for UI: "this spec has unsaved changes." Keep it; it's a UI concern but the spec is the right place for it.
- **Most function bodies are missing-larkc.** The shapes are documented; the clean rewrite must reconstruct each.
- **Static vs. dynamic property split** — `static-query-properties-from-cycl-query-spec` and `dynamic-query-properties-from-cycl-query-spec` produce the two plists. Keep this split; it mirrors the runtime distinction in "Inference parameters" doc.
- **`xml-serialize-new-cycl-query-specification`** — the XML serialization is for external systems (e.g. test management tools). The clean rewrite should consider whether to keep XML or move to JSON.
- **Loading from KB is split** into `load-sentence`, `load-mt`, `load-inference-parameters` — each can be called separately. Useful for partial loads (e.g. show just the formula in a list view, load full params only when the user opens the spec).
- **`update-query-spec-params-using-defaults(spec, defaults)`** is the inheritance mechanism: a spec can inherit from a "defaults" spec. The clean rewrite should make this explicit (a `parent-spec` slot) rather than implicit.
- **The query specification is the right place to express "this query is named, has metadata, has parameters, can be templated."** The runtime query-properties plist is an unnamed bag of values. Keep both; they serve different purposes.
- **`ncq-inference-parameter-p(object)`** — predicate for "is this a valid inference parameter for the new-cycl-query system?" Used to validate user input. Keep this.
- **`mark-new-cycl-query-specification-modified` and the `edited` flag** are how the UI knows when to prompt for save. Keep this UI hook.
