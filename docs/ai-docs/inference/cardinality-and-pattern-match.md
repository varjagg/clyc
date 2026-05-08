# Cardinality estimates and formula pattern matching

Two infrastructure files supporting the inference engine's *cost estimation* and *pattern-driven module dispatch*:

1. **Cardinality estimates** (`cardinality-estimates.lisp`, 308 lines) — precomputed counts of "how many instances does collection C have?" "how many specs/genls?" Used by removal-module cost functions to estimate productivity without running the actual lookup.
2. **Formula pattern matching** (`formula-pattern-match.lisp`, 145 lines) — the pattern-language interpreter for HL module declarative properties. Patterns like `(:isa #$Person)` test whether a formula matches; `(:fort . :anything)` tests structural shape.

Both are *foundation* files: many other systems consume them. The naming "removal module cost / formulas" in the index reflects what they're primarily used for, but each has a broader role.

Source files:
- `larkc-cycl/cardinality-estimates.lisp`
- `larkc-cycl/formula-pattern-match.lisp`

## Cardinality estimates

### What cardinalities are tracked

Eight global tables (`defglobal`):

| Table | Per-term value |
|---|---|
| `*local-instance-cardinality*` | local instance count for a collection in its definitional MT |
| `*local-quoted-instance-cardinality*` | local quoted-instance count |
| `*local-spec-cardinality*` | local spec count |
| `*total-instance-cardinality*` | accumulated instance count across all genls |
| `*total-quoted-instance-cardinality*` | accumulated quoted-instance count |
| `*total-spec-cardinality*` | accumulated spec count |
| `*total-genl-cardinality*` | accumulated genl count |
| `*generality-estimate-table*` | combined generality score |

The "local" version is what's directly asserted in the term's MT; the "total" version accumulates across the genl-mt closure. For `Cat`, local-instance-cardinality is "how many Cat-instance facts in the MT where Cat is defined?"; total-instance-cardinality is "how many across all relevant MTs?"

### Per-term entry points

| Function | Returns |
|---|---|
| `instance-cardinality(term)` | total instance count |
| `genl-cardinality(term)` | total genl count |
| `spec-cardinality(term)` | total spec count (for hlmt-naut, dispatches via `hlmt-monad-mt`) |
| `use-cardinality(term)` | instance + spec count (combined for "how many uses") |
| `total-instance-cardinality(term)` | gethash on the table; default 0 |
| `total-quoted-instance-cardinality(term)` | same |
| `total-spec-cardinality(term)` | same |
| `total-genl-cardinality(term)` | same |

`instance-iteration-cost(term)` = `instance-cardinality(term)` — used by removal modules to estimate "if I iterate the instances of this term, how much work?"

### Generality estimate

`*generality-estimate-scale-factor* = 100` — multiplier for the generality estimate (which combines several cardinalities into one score).

`generality-estimate(term)` (missing-larkc) — the combined score; used to sort terms by "how general are they?" `Animal` has high generality; `MyDogFido` has low generality.

`set-generality-estimate(term, estimate)` — manual override (e.g. used by KB authors to assert generality directly).

`generality-estimate<` and `generality-estimate>` — comparison predicates. `sort-by-generality-estimate(seq)` and `stable-sort-by-generality-estimate(seq)` use them. The strategist uses these to *order rule processing* — try more general rules later (they tend to be slower) and more specific first.

### Lifecycle

`setup-cardinality-tables(estimated-size)` — at startup, allocate hashtables sized for ~10% of the estimated KB size.

`rebuild-cardinality-estimates()` (missing-larkc) — recompute everything by walking the KB. Slow; called occasionally.

`initialize-cardinalities()` (missing-larkc) — initial population.

`clear-cardinalities()`, `clear-local-cardinalities()`, `clear-total-cardinalities()`, `clear-generality-estimates()` (missing-larkc) — reset.

The lifecycle is incremental: when a new GAF is added (e.g. `(isa NewObject Cat)`), the engine should:
1. `update-cardinality-estimates-wrt-isa(new-object, cat)` — increment local instance count of Cat
2. Cascade: increment total-instance-cardinality of Cat and all its genls

`update-cardinality-estimates-wrt-genls(spec, genl)` is one such update entry point; the rest (mostly missing-larkc) handle ISA, spec/genls predicate, MT spec/genl, etc.

### Persistence: load and dump

```
(defun load-cardinality-estimates-from-stream (stream)
  (setf *local-instance-cardinality* (cfasl-input stream))
  (setf *local-quoted-instance-cardinality* (cfasl-input stream))
  (setf *local-spec-cardinality* (cfasl-input stream))
  (setf *total-instance-cardinality* (cfasl-input stream))
  (setf *total-quoted-instance-cardinality* (cfasl-input stream))
  (setf *total-spec-cardinality* (cfasl-input stream))
  (setf *total-genl-cardinality* (cfasl-input stream))
  (setf *generality-estimate-table* (cfasl-input stream))
  nil)
```

`dump-cardinality-estimates-to-stream(stream)` (missing-larkc) is the symmetric writer. The eight tables are persisted in a fixed order via CFASL.

This persistence is what makes the cardinality estimates survive image restart. Without persistence, every fresh image would have to walk the whole KB to rebuild the tables — minutes of startup time saved.

### `do-sbhl-module-nodes` macro

A reconstructed iteration macro: walk every node in an SBHL module's graph, with progress reporting:

```lisp
(do-sbhl-module-nodes (node-var module &key progress-message done)
  ...body...)
```

Used inside the cardinality-rebuild loop: walk every node in the genls graph, count its specs, store. The progress-message is rendered as percent-complete.

### How removal modules consume cardinalities

A removal module's `:cost-pattern` may contain `(:call instance-cardinality :input)` — meaning "the cost of this module is the instance cardinality of the input collection." Concretely:
- `(isa ?X #$Cat)` with the all-isa-collection module: cost = `instance-cardinality(#$Cat)` ≈ how many Cats are in the KB ≈ how many bindings for `?X` we'll get.

Without cardinality estimates, the strategist couldn't choose between "do this cheap removal first" vs. "do this expensive removal later." The estimates are the substrate of the strategist's productivity model.

## Formula pattern matching

The pattern language is a declarative way to test formulas (asents, rules, NARTs) against shapes. HL modules use it for `:required-pattern`, `:complete-pattern`, `:cost-pattern`, `:input-extract-pattern`, etc. (see "Inference modules" doc).

### The two main entry points

```
pattern-matches-formula(pattern, formula)
  → t/nil; can use :BIND patterns (returns bindings as second value)

pattern-matches-formula-without-bindings(pattern, formula)
  → t/nil; :BIND not allowed (cheaper, no binding accumulation)
```

`formula-matches-pattern` is the same operation with arguments flipped — alias.

`pattern-transform-formula(pattern, formula, &optional bindings)` — apply a transformation pattern to produce a new formula.

### Atomic match methods

`*pattern-matches-formula-atomic-methods*` — keyword → predicate function. The pattern-language atom `(:fort)` becomes `(fort-p formula)`:

| Pattern atom | Predicate |
|---|---|
| `:fully-bound` | `fully-bound-p` |
| `:not-fully-bound` | `not-fully-bound-p` |
| `:string` | `stringp` |
| `:integer` | `integerp` |
| `:fort` | `fort-p` |
| `:hlmt` | `hlmt-p` |
| `:closed-hlmt` | `closed-hlmt-p` |
| `:constant` | `constant-p` |
| `:nart` | `nart-p` |
| `:closed-naut` | `closed-naut?` |
| `:open-naut` | `open-naut?` |
| `:assertion` | `assertion-p` |
| `:sentence` | `el-sentence-p` |
| `:variable` | `variable-p` |
| `:el-variable` | `el-variable-p` |
| `:collection-fort` | `collection-p` |
| `:predicate-fort` | `predicate-p` |
| `:functor-fort` | `functor-p` |
| `:mt-fort` | `microtheory-p` |

### Compound match methods

`*pattern-matches-formula-methods*` — keyword → method function. Pattern operators that look at the formula structure:

| Pattern op | Method |
|---|---|
| `:isa` | `pattern-matches-formula-isa-method` — `formula isa (second pattern)` |
| `:isa-memoized` | memoized variant |
| `:not-isa-disjoint` | `formula not-isa-disjoint (second pattern)` |
| `:not-isa-disjoint-memoized` | memoized variant |
| `:genls` | `pattern-matches-formula-genls-method` — `formula genls (second pattern)` |
| `:spec` | `pattern-matches-formula-spec-method` — `formula spec (second pattern)` |
| `:nat` | `pattern-matches-formula-nat-method` — formula is a NART/NAUT, recurse on the NAUT body |
| `:unify` | unification check |
| `:genl-pred` | `formula's predicate is a genl of (second pattern)` |
| `:genl-inverse` | inverse-pred genl |
| `:spec-pred` | spec-pred |
| `:spec-inverse` | spec-pred-inverse |

The `pattern-matches-formula-nat-method` has a body — when the formula is a NART, it's converted to its NAUT formula (via `nart-el-formula` or similar) before matching the subpattern.

### Memoised variants

`memoized-call-pattern-matches-formula-isa-method` and `memoized-call-pattern-matches-formula-not-isa-disjoint-method` are the cached versions, declared via `note-memoized-function`. Used for hot patterns where the same isa check fires many times.

### Pattern-transform: producing values

`pattern-transform-formula` is the *generative* counterpart to matching. Where matching returns t/nil, transformation runs the pattern and produces a value. Used in `:cost-pattern`, `:expand-pattern`, etc.:

```lisp
;; A removal module's :cost-pattern might be:
(:call instance-cardinality :input)
```

Calling `pattern-transform-formula(pattern, formula)` with this pattern and `formula = #$Cat` returns `(instance-cardinality #$Cat)` = the cardinality of Cat.

The pattern operators for transformation:
- `:input` — the input formula
- `(:value <var>)` — read from a binding
- `(:bind <var> <pattern>)` — bind the matched value
- `(:call <fn> <args>...)` — call fn on substituted args
- `(:template <bind-pat> <value-pat>)` — bind via the bind-pat, return value-pat

### How HL modules consume pattern-match

A removal module declares `:required-pattern (cons :fort :anything)`. When the strategist evaluates whether the module applies to `(isa Fido Dog)`:

1. Get the module's `:required-pattern`
2. Call `pattern-matches-formula-without-bindings(pattern, asent)` (cheap; no binding accumulation)
3. If t, continue checking other applicability conditions
4. If nil, skip this module

The fast path through pattern matching is what makes the candidate-module enumeration tractable. With ~200 candidate modules and 10000 asents per query, a slow pattern matcher would dominate.

## When does each piece fire?

| Operation | Fires when |
|---|---|
| `instance-cardinality` and friends | Removal-module `:cost-pattern` evaluation; sort-by-generality |
| `total-spec-cardinality` etc. | Same |
| `setup-cardinality-tables` | Image startup |
| `rebuild-cardinality-estimates` | After bulk KB load; admin-triggered |
| `update-cardinality-estimates-wrt-X` | Per-GAF after KB write |
| `load-cardinality-estimates-from-stream` | Image start (from CFASL persistence) |
| `pattern-matches-formula-without-bindings` | Every HL module applicability check |
| `pattern-transform-formula` | Every HL module cost / expand pattern evaluation |
| Memoised pattern variants | Repeated isa/not-isa-disjoint checks |

## Cross-system consumers

### Cardinality estimates

- **Removal modules** — `:cost-pattern` evaluation reads cardinalities
- **Strategist** — `sort-by-generality-estimate` is used to order rule firing
- **Inference analysis** — uses cardinalities to compute rule utility
- **CFASL** — persists the cardinality tables
- **KB write hooks** — call the `update-cardinality-estimates-wrt-X` family

### Formula pattern matching

- **HL modules** — every `:required-pattern`, `:complete-pattern`, `:cost-pattern`, `:expand-pattern`, etc. consumes pattern-match
- **`hl-module-applicable-to-asent?`** — calls `hl-module-required-pattern-matched-p` which calls `pattern-matches-formula-without-bindings`
- **Worker dispatch** — pattern transformation is the alternate path to imperative `:expand` functions
- **Cost computation** — `hl-module-cost-pattern-result` calls `pattern-transform-formula`

## Notes for the rewrite

### Cardinality estimates

- **The 8 tables can be one struct.** The clean rewrite should consolidate: a `cardinality-info(term)` record with all 8 fields, indexed by term. Saves 8 hashtable lookups per query.
- **Incremental updates are subtle.** Adding `(isa NewObject Cat)` cascades up the genls graph: every genl of Cat gets its total-instance-cardinality incremented. The cascade has to happen atomically wrt concurrent queries.
- **Persistence via CFASL is essential.** Without it, image start spends minutes rebuilding. The clean rewrite should keep the persistence; consider a more efficient format (CBOR, etc.).
- **Generality estimate is a tuned scoring function.** The combination weights are empirical. Don't tune them without benchmarking.
- **`*generality-estimate-scale-factor* = 100`** is a magic number; document why 100 was chosen.
- **`do-sbhl-module-nodes` macro** is reconstructed; it's the standard "walk-the-graph-with-progress-bar" iteration. Keep this pattern.
- **Most update functions are missing-larkc.** The clean rewrite must reconstruct them. The shape: when a GAF changes, find every cardinality table affected and call the appropriate increment/decrement.

### Formula pattern matching

- **The pattern language is the *declarative* alternative to imperative `:expand` functions.** Encourage modules to use patterns; they're easier to analyse and serialise.
- **The atomic-methods and methods tables are hardcoded.** The clean rewrite should make them extensible (a `register-pattern-method` API) so domain-specific patterns can be added.
- **`:isa` and `:not-isa-disjoint` need memoisation.** Without the cache, every applicability check re-runs the isa lookup. Keep `note-memoized-function` for these.
- **`pattern-matches-formula-without-bindings` is the fast path.** When you don't need bindings, use this — the binding-collection version is slower.
- **`:nat` recurses on the NAUT formula** — necessary because patterns are written against the formula syntax, but a NART is a stable handle. Without the recursion, patterns can't see inside NART structure.
- **`pattern-transform-formula` is the generative dual.** Keep both directions: matching returns t/nil + bindings; transformation returns a new value.
- **The `*pattern-matches-tree-*` machinery** is shared with non-formula patterns (e.g. arg-type patterns). The clean rewrite can keep the layering: tree-level patterns + formula-specific atomic and compound methods.
- **`:bind` and `:value` and `:call` and `:template`** are the binding/computation primitives. They make patterns Turing-incomplete-on-purpose: a pattern can compute, but only via named functions.
- **`:genl-pred` and `:spec-pred` are HL-system-specific.** They consult the pred-relation graph. Keep these as part of the formula-pattern vocabulary; they're not generic.
