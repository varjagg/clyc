# Arg-type (AT) system

The **AT system** is the engine that enforces *argument-type constraints* on every formula. When you assert `(isa Fido Mammal)`, the AT system checks that:
- `Fido` matches `argIsa(isa, 1)` — i.e. is whatever isa's first arg is supposed to be (an instance of Thing)
- `Mammal` matches `argIsa(isa, 2)` — must be a Collection
- The resulting GAF respects all `interArgIsa`, `interArgGenl`, `interArgFormat`, etc. constraints
- The relation `isa` itself is well-typed (its `defining-mts` are visible)
- The relation `isa` doesn't violate constraints on commutativity/asymmetry/anti-transitivity

AT is the largest single subsystem in the Clyc canonicalisation layer (6420 lines across 9 files). It is the *type system* of CycL — much richer than a simple "every arg has an isa constraint." The KB declares constraints via 30+ predicate families; the AT engine enforces them at every assertion and (when configured) every query.

Source files:
- `larkc-cycl/arg-type.lisp` (1027) — the main `formula-args-ok-wrt-type?` pipeline
- `larkc-cycl/at-vars.lisp` (378) — the dynamic-variable vocabulary (~80 specials)
- `larkc-cycl/at-utilities.lisp` (832) — helper functions
- `larkc-cycl/at-routines.lisp` (1204) — the per-constraint-type routines
- `larkc-cycl/at-cache.lisp` (217) — the compiled per-(relation, argnum, mt) constraint cache
- `larkc-cycl/at-defns.lisp` (802) — defns (function/predicate definitions for AT) — see "Defns" doc
- `larkc-cycl/at-macros.lisp` (478) — `with-at-*` scoped binding macros
- `larkc-cycl/at-admitted.lisp` (127) — admitted-argument logic (mostly missing-larkc)
- `larkc-cycl/at-var-types.lisp` (1355) — variable-type computation: what types are inferred for a free variable

## What AT enforces

The KB-declared constraint families:

| Constraint | Asserted via | Meaning |
|---|---|---|
| `argIsa` | `(arg1Isa pred col)` | The first arg of pred must be an instance of col |
| `argQuotedIsa` | `(arg1QuotedIsa pred col)` | Same for quoted args |
| `argGenl` | `(arg1Genl pred col)` | The first arg must be a genl of col (be a more general collection) |
| `argFormat` | `(arg1Format pred fmt)` | Format constraint (e.g. `SingleEntryFormat`, `SetTheFormat`) |
| `argNotIsa` | various | The first arg must NOT be an instance of col (negative constraint) |
| `argsIsa` | `(argsIsa pred col)` | All args must be instances of col |
| `argAndRestIsa` | `(argAndRestIsa pred argnum col)` | The argnum and all subsequent args must be instances of col |
| `interArgIsa` | `(interArgIsa pred a1 col1 a2 col2)` | If arg `a1` is in col1, then arg `a2` must be in col2 |
| `interArgNotIsa` | similar | Negative inter-arg |
| `interArgGenl` | similar | Inter-arg genl constraint |
| `interArgFormat1-2` etc. | various | Format-of-arg-1-given-arg-2 |
| `interArgDifferent` | `(interArgDifferent pred a1 a2)` | The two args must be different |
| `singleEntryFormatInArgs` | argFormat predicate | Single-entry format applies |
| Asymmetric / anti-symmetric / irreflexive / anti-transitive predicates | per-predicate | predicate type relations |
| Negation predicates / negation inverses | per-predicate | negation-relating predicates |
| `definingMt` | `(definingMt pred mt)` | Constraint enforcement is restricted to the relation's defining MT |

Plus `genlPreds` constraints (constraints on a more-general predicate also apply to specs) and `genlInverse` constraints (likewise for inverses).

## The pipeline

`formula-args-ok-wrt-type?(formula, &optional mt)` is the entry. It dispatches to either:
- `mt-literal-args-ok-wrt-type?` — when the formula is an MT-designating literal (special handling)
- `formula-args-ok-wrt-type-int?` — the main path

`formula-args-ok-wrt-type-int?` iterates each arg:

```
1. Extract args, sequence-var
2. Bind *fag-search-limit* = *at-gaf-search-limit*  (limits relevant-gaf search depth)
3. Bind *at-argnum* = 0
4. Compute ground? = no free variables
5. Bind format/relator-constraints based on context (gated by appraising-disjunct?, within-function?, within-predicate?, within-negation?, ground?)
6. Bind *at-formula*, *at-reln*, *variables-that-cannot-be-sequence-variables*
7. Sequence-var inhibition check
8. If reln is a fort:
   a. Check defining-mts-ok? + relator-constraints-ok?
   b. For each arg: dispatch to relation-arg-ok? with the appropriate at-mode
   c. Bookkeep within-negation, within-function, within-predicate, within-disjunction per arg
9. Return ok?
```

Each per-arg call to `relation-arg-ok?(relation, arg, argnum, mt)` is itself a dispatch:

```
relation-arg-ok-int?(relation, arg, argnum, mt):
  if tou-wrt-arg-type?(arg):              tou-arg-ok?
  if weak-fort-wrt-arg-type?(arg):        weak-fort-arg-ok?
  if nat-function-wrt-arg-type?(arg):     nat-function-arg-ok?
  if nat-argument-wrt-arg-type?(arg):     nat-argument-arg-ok?
  if naut-wrt-arg-type?(arg, mt):         naut-arg-ok?
  if strong-fort-wrt-arg-type?(arg):      strong-fort-arg-ok?
  else:                                    opaque-arg-ok?
```

Different *kinds* of arg get different handling. A "weak fort" is a constant or NART. A "strong fort" is one that's been validated. A "tou" is a term-of-unit. A "naut" is a non-atomic-unification-term. The dispatch reflects the AT system's progressive narrowing.

## Modes (`*at-mode*`)

The AT engine runs in different modes depending on context:
- `:arg-isa` — checking arg-isa constraints
- `:arg-genls` — checking arg-genl constraints
- `:arg-quoted-isa` — checking arg-quoted-isa
- `:arg-format` — checking arg format
- `:inter-arg-isa` — inter-arg-isa
- `:inter-arg-genl` — inter-arg-genl
- … etc.

`*at-mode*` is bound during each pass. The mode tells the predicate function `relation-arg-ok?` which constraint family to consult.

## Per-pass scoped state (~80 dynamic specials)

The AT system uses a *huge* number of dynamic specials, all declared via the `def-at-state-var` macro. The macro:
1. Defines the variable (defparameter, deflexical, or defvar)
2. Registers the docstring via `note-state-variable-documentation`
3. Pushes the symbol onto `*at-state-variables*`

This dual registration means the AT state can be saved/restored in bulk (e.g. for nested AT passes) by walking `*at-state-variables*`.

The most important state variables fall into these clusters:

### Master switches

- `*at-check-arg-isa?* = t` — enforce argIsa
- `*at-check-arg-genls?* = t` — enforce argGenl
- `*at-check-arg-quoted-isa?* = t` — enforce argQuotedIsa
- `*at-check-arg-not-isa?* = t` — enforce argNotIsa
- `*at-check-arg-types?* = t` — master switch
- `*at-check-arg-format?* = t` — enforce argFormat
- `*at-check-fn-symbol?* = t` — function symbols must be `Function-Denotational`
- `*at-check-relator-constraints?* = t` — asymmetric, anti-symmetric, etc.

### Inter-arg constraints

- `*at-check-inter-arg-isa?* = t`
- `*at-check-inter-arg-not-isa?* = t`
- `*at-check-inter-arg-genl?* = nil` (off by default — expensive)
- `*at-check-non-constant-inter-arg-isa?* = t`
- `*at-check-non-constant-inter-arg-genl?* = t`
- `*at-check-non-constant-inter-arg-format?* = t`
- `*at-check-inter-arg-format?* = t`
- `*at-check-inter-arg-different?* = t`
- `*at-check-inter-assert-format-w/o-arg-index?* = t`
- `*at-check-inter-assert-format-w/o-arg-index-gaf-count-threshold* = 100`

### Disjointness checks

- `*at-check-not-isa-disjoint?* = t`
- `*at-check-not-quoted-isa-disjoint?* = t`
- `*at-check-not-genls-disjoint?* = t`
- `*at-check-not-mdw?* = t` (mdw — minimal disjoint witness)
- `*at-check-not-sdc?* = t` (sdc — sufficient disjoint check)

### Predicate-level constraints

- `*at-check-relator-constraints?* = t`
- `*at-pred-constraints*` = list of `(:asymmetric-predicate :anti-symmetric-predicate :irreflexive-predicate :anti-transitive-predicate :negation-preds :negation-inverses)`
- `*at-predicate-violations*` = nil — accumulator

### Genl-pred / genl-inverse propagation

- `*at-check-genl-preds?* = t` — apply constraints from genlPreds
- `*at-check-genl-inverses?* = t` — apply constraints from genlInverse

### Defining-MT enforcement

- `*at-possibly-check-defining-mts?* = nil`
- `*at-check-defining-mts?* = t`
- `at-check-defining-mts-p()` is the predicate (both must be true)

### Modes

- `*at-mode* = nil` — the constraint-family currently being checked
- `*at-trace-level* = 1` — trace verbosity 0..5
- `*at-test-level* = 3` — testing extent 0..5
- `*at-break-on-failure?* = nil` — drop into debugger on AT violation (debug only)

### Within-X context

- `*within-at-suggestion?* = nil` — currently formulating a suggestion
- `*within-at-mapping?* = nil` — currently doing a mapping search
- `*appraising-disjunct?* = nil` — currently in a disjunct (relax constraints)
- `*within-decontextualized?* = nil` — decontextualized literal
- `*within-disjunction?* = nil`
- `*within-conjunction?* = nil`
- `*within-negated-disjunction?* = nil`
- `*within-negated-conjunction?* = nil`
- `*within-function?* = nil`
- `*within-predicate?* = nil`
- `*within-tou-gaf?* = nil`
- `*within-negation?* = nil`

These set the AT context: "we're now in a disjunct" → relax certain constraints (because if the disjunct fails, the formula might still hold). "We're inside a function" → check function-arg constraints not predicate-arg constraints.

### Relaxation flags

- `*relax-arg-constraints-for-disjunctions?* = t` — relax in disjunctions
- `*at-relax-arg-constraints-for-opaque-expansion-nats?* = t` — relax for expansion-nats
- `*at-admit-consistent-nauts?* = t` — admit *consistent* (not just *provably-true*) nauts
- `*at-admit-consistent-narts?* = t` — admit consistent narts

### Accumulators

- `*at-isa-constraints*` = (make-hash-table) — applicable isa constraints
- `*at-genl-constraints*` = (make-hash-table)
- `*at-format-constraints*` = (make-hash-table)
- `*at-different-constraints*` = (make-hash-table)
- `*at-isa-assertions*`, `*at-genl-assertions*`, `*at-format-assertions*`, `*at-different-assertions*` — applicable assertions
- `*at-format-violations*`, `*at-different-violations*`, `*at-predicate-violations*` — accumulators

### Gather flags (turn on accumulation)

- `*gather-at-constraints?* = nil` — collect applicable constraints
- `*gather-at-assertions?* = nil` — collect applicable assertions
- `*gather-at-format-violations?* = nil`
- `*gather-at-different-violations?* = nil`
- `*gather-at-predicate-violations?* = nil`

Without `gather-*` on, the accumulators stay empty. With them on, the accumulators record all relevant matches for post-hoc inspection.

### Multi-arg constraint flag

- `*at-consider-multiargs-at-pred?* = t` — consider argsIsa-style multi-arg constraints

### Disjunct-conjunct independence

- `*at-assume-conjuncts-independent?* = t` — assume conjuncts independent (faster, simpler reasoning)

### Top-level AT formula

- `*at-formula*` — the formula being checked
- `*at-reln*` — the relation
- `*at-arg*` — the current arg
- `*at-argnum*` — the current arg position
- `*at-result*` — accumulator for current AT query

## The AT cache (at-cache.lisp)

The AT cache compiles the (relation, argnum) → list-of-(col, mts) lookup into a fast in-memory index.

```
*arg-type-cache* :: hash-table
  relation -> [for each argnum: list of (col . mts)
                                   ^
                                   collection that's a valid arg-isa,
                                   with the mts where this constraint applies]
```

`*arg-type-cache-preds* = (#$arg1Isa #$arg2Isa #$arg3Isa #$arg4Isa #$arg5Isa #$arg6Isa)` — only the binary `argNIsa` predicates feed the cache. `argsIsa` and `argAndRestIsa` are ternary; they're handled separately.

`*arg-type-cache-initialized?*` flag — false on image start; flips true after `initialize-at-cache`.

### Cache lookups

`cached-arg-isas-in-mt(relation, argnum, mt)` → list of collections constituting valid arg-isa for that (relation, argnum) in mt.

```
cached-arg-isas-in-relevant-mts(relation, argnum):
  let argnum-table = *arg-type-cache*[relation]
  let collection-table = nth(argnum-1, argnum-table)
  return at-cache-relevant-collections(collection-table)
```

`at-cache-relevant-collections` filters to only those collections whose constraint MT is currently relevant.

`at-cache-use-possible?(constraint-pred, argnum)` predicate — can we use the cache for this constraint and argnum?

`some-args-isa-assertion-somewhere?(relation)` — does this relation have any `argsIsa` assertions? Falls back when the cache is incomplete.

The cache is built lazily: when `(arg1Isa pred col)` is asserted, the cache gets updated. Periodic full rebuild via `initialize-at-cache` (missing-larkc).

## Variable-type inference (at-var-types.lisp)

When checking a formula like `(arg1 ?V)`, the AT system needs to know what *types* `?V` could have. The variable-type inferences from the literals around it: if `(isa ?V Cat)` is in the same formula, `?V`'s inferred type is `Cat`.

`at-var-types.lisp` is the largest of the AT files (1355 lines). It computes:
- *Inferred isa* — what `?V` is constrained to be an instance of (given the formula)
- *Inferred genls* — what `?V` is constrained to be a genl of
- *Inferred quoted-isa* — quoted-isa version
- *Constraints* — combined constraint set

The inference is intra-formula: only the current formula's literals contribute. KB-wide variable typing is the AT engine's job, not the var-type module's.

## AT defns (at-defns.lisp)

A *defn* (definition) is a per-collection function or predicate that decides whether a value is an instance of the collection. For some collections (Number, Integer, String), the test is structural; for others, it's an assertion in the KB.

`defns-admit?(collection, v-term, &optional mt)` and `defns-reject?(collection, v-term, &optional mt)` are the entry points: respectively "does v-term pass collection's defn?" and "does it fail?" Both can be true (consistent), both false (unknown), or one true (decisive).

`*use-new-defns-functions?*` switches between two implementations; defaults t (the new one).

`define-defn-metered <name> ...` is a macro that wraps a defn function with metering: count calls, count successes, count failures. Used for profiling AT performance.

The defns system is also covered in the "Defns" doc — it's the boundary between AT (constraint enforcement) and the KB's per-collection membership decision logic.

`*suf-defn-cache*` and `*suf-quoted-defn-cache*` — caches for sufficient-defn results. `clear-suf-defns()` and `clear-suf-quoted-defns()` clear them.

## Admitted arguments (at-admitted.lisp)

Mostly missing-larkc. The intended functions include:
- `admitted-argument?(relation, arg, argnum, &optional v-mt)` — does `arg` pass `relation`'s argnum constraint?
- `admitted-formula?(formula, &optional v-mt)` — does the entire formula's args pass?
- `admitted-sentence?(sentence, &optional v-mt)` — for sentences
- `admitted-atomic-sentence-wrt-arg-constraints?(asent)` — atomic-sentence variant
- `relations-admitting-fort-as-arg(fort, argnum, &optional mt)` — reverse lookup: which relations can take fort at argnum?
- `relations-admitting-fort-as-any-of-args(fort, argnums, &optional mt)` — any of these argnums

The reverse-lookup functions (`relations-admitting-...`) feed into KE auto-completion: "given that I'm typing `Fido` as the first arg, what predicates are valid?"

`*at-candidate-relations-table*`, `*at-candidate-relations-argnums-table*`, `*at-candidate-relations-sbhl-space*` — the data structures for the candidate-relations search.

`*at-candidate-relations-max* = 512` — cap on candidate relations.

The ira-* parameters (`*ira-table*`, `*ira-argnum*`, `*ira-relations-estimate* = 512`, `*ira-isa-sbhl-space*`, `*ira-arg-isa-pred*`, `*ira-genl-sbhl-space*`, `*ira-arg-genl-pred*`, `*ira-mapping-result*`) are the parallel structures for inverse-relation-arg searches.

## When does AT fire?

| Trigger | Path |
|---|---|
| User assertion | WFF check → `formula-args-ok-wrt-type?` |
| Canonicalisation | `wff-elf?` calls `formula-args-ok-wrt-type?` if `*check-arg-types?*` is t |
| Forward inference | After-adding hooks check arg constraints |
| KE auto-completion | `relations-admitting-fort-as-arg` |
| Inference (var-type) | `formula-var-types-ok-int?` calls into AT for each variable in the formula |
| Defining-MT validation | `defining-mts-ok?` |
| Relator-constraint check | `relator-constraints-ok?` (asymmetric, anti-symmetric, etc.) |

AT runs *every* time a formula crosses an MT boundary or gets asserted. It's one of the hottest paths in the engine.

## Cross-system consumers

- **WFF** consults AT via `formula-var-types-ok-int?`
- **Canonicalizer** consults AT for arg-type checks
- **KE (Knowledge Editor)** uses AT for auto-completion and validation
- **Forward inference** validates new GAFs via AT
- **Defns** is consumed by AT and consumed by the inference engine separately
- **AT cache** is rebuilt by KB write hooks
- **Argumentation** uses AT to validate intermediate proof steps

## Notes for the rewrite

- **AT is the type system of CycL.** The clean rewrite must preserve every constraint family. Each is real semantic content asserted in the KB.
- **`*at-state-variables*` registry** is how AT state can be saved/restored in bulk. Keep this; without it, nested AT passes (inside an outer pass) corrupt state.
- **The 80+ dynamic specials** are essentially the AT configuration object — but spread across all of `at-vars.lisp`. The clean rewrite should consolidate into a typed `ATConfig` struct.
- **Master switches default on; expensive checks default off.** For example `*at-check-inter-arg-genl?*` is nil. The rewrite should preserve the defaults; they reflect production tuning.
- **The cache (`*arg-type-cache*`)** is essential — without it, every assertion check would do KB lookups. Keep it; understand the invalidation hooks (called from KB write paths).
- **Defns are per-collection membership tests.** Keep them; they're how custom collections (e.g. `EvenInteger`) define membership without an explicit assertion enumeration.
- **Variable-type inference is intra-formula.** The `at-var-types.lisp` 1355-line file is essential for inference — the engine needs to know "given this rule's literals, what types are inferred for the variable in arg 1?" Keep this complete.
- **Most function bodies are missing-larkc.** The shape is well-bounded by the specials and the predicate names. The clean rewrite must reconstruct: the per-constraint-family `at-*-ok?` checks, the inter-arg consistency checks, the cache rebuild, the variable-type inference. The specs are clear; the work is mechanical.
- **`*at-mode*` is the dispatch axis.** Most AT functions read it to decide which constraint family to enforce. Don't remove; it's the cleanest way to share infrastructure across modes.
- **Disjunction relaxation** (`*relax-arg-constraints-for-disjunctions?*`) is correct semantics: `(or P Q)` is true if either disjunct is true; we shouldn't fail the AT check just because one disjunct's args don't pass.
- **Negation flipping** (`*within-negation?*`) — AT in a negated context is *not* simply "ignore"; it's "the constraint must hold for the formula's positive form, but the inference may use it differently." Subtle; preserve carefully.
- **`*at-trace-level*` and `*at-test-level*`** are 0..5 dials. Production: 1 / 3. Debug: 5 / 5. Keep these for diagnostics.
- **`*at-break-on-failure?* = nil`** in production. Debug-only flag.
- **`*at-pred-constraints* = (asymmetric anti-symmetric irreflexive anti-transitive negation-preds negation-inverses)`** — these are the predicate-level constraints AT checks. Keep this list; each is a real KB-asserted constraint.
- **Defining-MT enforcement is gated by both `*at-possibly-check-defining-mts?*` and `*at-check-defining-mts?*`**. Both must be true. The double-gate is intentional: the "possibly" flag enables checking at all (off for performance); the "check" flag controls whether to run the check when enabled.
- **`*at-assume-conjuncts-independent?* = t`** is the production default. Conjunct-dependency checking is more thorough but quadratic in the number of conjuncts. For small formulas it doesn't matter; for large rules it does.
- **`*at-admit-consistent-nauts?*` and `*at-admit-consistent-narts?*`** — admit values that are *consistent with* the constraints, not just *provably-true*. Without this, novel terms (a fresh constant whose isa-genls hasn't been derived yet) would fail AT. Keep this; it's pragmatic.
