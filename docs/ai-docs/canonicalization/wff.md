# WFF (well-formedness) checking

A *well-formed formula* (WFF) is a CycL expression that satisfies the engine's syntactic and semantic constraints. The WFF checker is what decides whether the canonicalizer should accept an input. Running canonicalisation on a non-WFF either fails outright or — if `*try-to-simplify-non-wff-into-wff?*` is on — attempts a syntactic simplification that might rescue it.

WFF runs at *every* assertion and at *every* query — it's the first checkpoint after parsing. The pass has multiple levels:
1. **Syntactic** — basic shape (right number of args, right kinds of operators, valid constants)
2. **Arity** — does each formula have the right number of args for its operator?
3. **Arg-type / semantic** — do the args satisfy the per-arg type constraints in the KB?
4. **Coherence** — are the literals coherent (e.g. no contradictory typing)?
5. **Expansion-validity** — if the formula has an EL expansion, does the expansion also pass WFF?

Each level is gated independently — callers can choose syntactic-only checks (fast) or full semantic checks (thorough).

Source files:
- `larkc-cycl/wff.lisp` (988) — the main WFF entry points and per-formula-shape checks
- `larkc-cycl/wff-vars.lisp` (218) — the dynamic-variable vocabulary, mode flags, violation/suggestion accumulators
- `larkc-cycl/wff-utilities.lisp` (92) — small helper functions
- `larkc-cycl/wff-macros.lisp` (168) — `with-wff-*` scoped binding macros
- `larkc-cycl/wff-module-datastructures.lisp` (148) — pluggable WFF violation modules

## Public entry points

```
(el-wff? sentence &optional (mt *mt*) v-properties)
  → boolean; is sentence a well-formed EL sentence?
  → also accumulates *wff-violations* on failure

(el-wff-syntax? sentence &optional mt)
  → boolean; check syntax only (cheap)

(wff-query? formula &optional (mt *mt*) (v-properties nil))
  → boolean; well-formed CycL query (different rules than assertion)

(wff? formula &optional (type :elf) (mt *mt*))
  → dispatch on type: :elf, :cnf, :dnf, :naf
  → most callers use :elf
```

`v-properties` is a plist of WFF property overrides — e.g. `(:check-arity? nil :check-arg-types? nil)` to disable specific checks for one call. Properties are validated via `wff-property-p`; declared via `defparameter-wff` (the `defparameter-wff` macro hooks into `*wff-properties-table*`).

## Two modes: `:strict` vs `:lenient`

```
*wff-mode* = :strict   ; default
  :strict — reject sentences that don't provably meet arg constraints
            ("bitchy gatekeeper" mode)
  :lenient — reject only if disjoint with arg constraints; provable
             consequences not added to KB
```

Strict mode is what production uses — every assertion must explicitly meet its constraints. Lenient mode is for asserting partial knowledge: we know it doesn't *contradict* the constraints but can't *prove* it satisfies them.

## The per-formula pipeline

`wff-elf?(sentence, mt)` is the workhorse. The pipeline:

```
1. Bind *wff-violations* = nil
2. syntactically-wff-elf-int?(sentence, nil) — basic shape check
   - mal-variables? — invalid variable shapes
   - mal-forts? — invalid fort references
   - cycl-sentence-p — basic CycL sentence shape
3. Reify the MT (turn naut into nart)
4. Check the MT itself isn't malformed (mal-mt-spec?)
5. Unless syntactic-only:
   - Set up MT relevance frame
   - mal-precanonicalizations? — does precanonicalization fail?
   - wff-elf-int? — the main semantic check
   - if check-var-types?: formula-var-types-ok-int?
   - if check-wff-coherence?: wff-coherent? check
6. If check-wff-expansion?: also run wff-elf? on the expansion
7. Accumulate violations into *wff-violations*
```

Each step gates further checks: if syntax fails, don't check arg-types. If arg-types pass, check coherence. If coherence passes, validate the expansion.

### Syntactic check

`syntactically-wff-elf-int?(sentence, check-fast-gaf?)`:
1. `mal-variables?(sentence)` — any variables that aren't well-formed?
2. `mal-forts?(sentence)` — any forts that aren't valid?
3. `cycl-sentence-p(sentence)` OR (if `check-fast-gaf?`) `wff-fast-gaf?(sentence)` — proper CycL sentence shape

The "fast-gaf" path:
```lisp
(defun wff-fast-gaf? (sentence)
  (and (no-wff-semantics?)
       (member (formula-operator sentence)
               (list #$isa #$genls #$myCreator #$myCreationTime
                     #$myCreationPurpose #$myCreationSecond))
       (formula-arity= sentence 2)
       (not (contains-subformula-p sentence))
       (ground? sentence #'el-var?)))
```

A "fast GAF" is a closed binary-predicate sentence with one of six predefined predicates and no subformulas. These are the most common shape; the fast path skips most semantic checks.

### Semantic check (`semantically-wff-elf-int?`)

Dispatches on sentence shape:
- assertion → t (already validated)
- atomic sentence → `semantically-wf-literal?`
- non-atomic sentence → `semantically-wf-non-atomic-sentence?`
- variable → `*encapsulate-var-formula?*` (whether bare-variable formulas are allowed)
- otherwise → error

Atomic sentence checks are mostly arg-type via the AT system (see "Arg-type" doc).

### `wff-fast-gaf?` short-circuit

Inside `wff-elf-int?`:
```lisp
(defun wff-elf-int? (sentence &optional mt)
  (cond ((eq #$True sentence) t)
        ((eq #$False sentence) (not (within-assert?)))
        ((wff-fast-gaf? sentence) t)
        (t (semantically-wff-elf-int? sentence mt))))
```

`#$True` is always WFF. `#$False` is WFF *as a query* but not as an assertion (you can't assert `False`). The fast-GAF check short-circuits common cases. Otherwise fall through to the full semantic check.

## Property table

`*wff-properties-table*` maps property keyword → (variable, default-value). Populated via `note-wff-property(keyword, variable, default)` during file load.

The properties:

### Mode and behaviour

- `:wff-mode` → `*wff-mode*`, default `:strict`
- `:wff-debug?` → `*wff-debug?*`, default nil
- `:provide-wff-suggestions?` → `*provide-wff-suggestions?*`, default nil

### Check enablers

- `:validate-constants?` → `*validate-constants?*`, default t
- `:recognize-variables?` → `*recognize-variables?*`, default t
- `:reject-sbhl-conflicts?` → `*reject-sbhl-conflicts?*`, default t
- `:inhibit-skolem-asserts?` → `*inhibit-skolem-asserts?*`, default t
- `:simplify-evaluatable-expressions?` → `*simplify-evaluatable-expressions?*`, default nil
- `:enforce-evaluatable-satisfiability?` → `*enforce-evaluatable-satisfiability?*`, default t
- `:enforce-only-definitional-gafs-in-vocab-mt?` → default nil
- `:inhibit-cyclic-commutative-in-args?` → default t
- `:enforce-literal-wff-idiosyncrasies?` → default t

### Violation handling

- `:accumulating-wff-violations?` → default nil; collect more than one violation
- `:noting-wff-violations?` → default nil; record violations for display
- `:include-suf-defn-violations?` → default t; sufficient-definition violations included
- `:wff-violation-data-terse?` → default nil; terse data only

### Variable permissions

- `:permit-keyword-variables?` → default nil; transient flag, t during KWT-WFF? execution
- `:permit-generic-arg-variables?` → default nil; transient flag

### Expansion handling

- `:validate-expansions?` → default nil; check expansions in addition to given form

The properties are *threaded through* the pipeline via `with-wff-properties(plist) … body`, which rebinds each variable to the user's override or the default.

## Violations and suggestions

`*wff-violations*` accumulates violation descriptions. Each is a list of the form `(violation-type . extra-data)`:
- `(:mal-precanonicalizations)`
- `(:mal-forts <list-of-bad-forts>)`
- `(:invalid-mt)`
- `(:invalid-variables)`
- and many more (each is a `wff-violation-module` registered separately)

`note-wff-violation(violation)` adds one. `reset-wff-violations()` clears.

`note-wff-violations(violations)` adds many at once.

`wff-violations()` returns the accumulated list.

`*wff-suggestions*` is the parallel structure for suggestions: "this formula is non-WFF, but if you change X to Y it would be WFF." Used by interactive editors and the canonicalizer's "try to simplify into WFF" path.

`provide-wff-suggestions?()` predicate gates suggestion generation. When off, suggestions aren't computed (faster).

## WFF modules: pluggable violation types

`wff-module-datastructures.lisp` defines the *plugin* infrastructure for WFF violations. Each violation type is a `wff-module` with:

```lisp
(defstruct wff-module
  name        ; the violation keyword
  plist)      ; properties
```

The plist contains `(:explain-func <symbol>)` and `(:comment <string>)`.

`wff-violation-module(name, plist)` registers a new violation type:
```lisp
(defun wff-violation-module (name plist)
  (let ((wff-module (setup-wff-module name :violation plist)))
    wff-module))
```

When a violation is reported, the engine uses `wff-violation-explanation-function(name)` to find the explanation function, then calls it on the violation data to produce a user-readable error message.

`*wff-module-store*` is the equal-hashtable indexing modules by name, sized 212.

The clean rewrite should keep this pluggable design — KB authors can register custom violation types for domain-specific constraints.

## Per-pass scoped state

Several macros set up per-WFF-pass state:

### `with-wff-formula(formula) … body`

Binds `*wff-formula*` (and `*wff-original-formula*`) to the formula being checked, so deep code can find what formula it's checking without threading the argument.

### `with-wff-memoization-state … body`

Allocates a fresh `*wff-memoization-state*` for the duration of the WFF check. Without this, repeated WFF checks on similar formulas would re-do work.

### `with-wff-properties(plist) … body`

Applies the user's property overrides via the property table.

### `within-wff … body`

Sets `*within-wff?*` to t (so deep code knows it's running inside a WFF check) and tracks recursive entry. Used to gate caches and to short-circuit recursive WFF checks on already-checked subformulas.

### `wff-done?(wff?)` — short-circuit predicate

Returns true if WFF should stop checking (because either WFF is decisively false, or `*accumulating-wff-violations?*` is off and we've already failed). Used to bail out early from the pipeline when one stage fails.

## Var-type checking

When `*check-var-types?*` is t (the default):

`formula-var-types-ok-int?(sentence, mt)` walks the formula, checking each variable against the arg-type constraints from the AT system.

`*at-assume-conjuncts-independent?*` (in arg-type vars) controls whether the var-type check assumes conjuncts are independent. When t (production default), each conjunct's var bindings are checked independently. When nil, conjuncts can constrain each other (more thorough but more expensive).

The result feeds into the violation accumulator: if var-types are bad, the violations come from the AT system (see "Arg-type" doc).

## Expansion validation

When the formula has an EL expansion (some predicates have `(expansion <pred> <expansion-formula>)` GAFs in the KB) and `*validate-expansions?*` is on:

```
1. Compute the expansion
2. *unexpanded-formula* := original formula
3. *wff-expansion-formula* := expansion
4. wff-elf? on the expansion
5. If expansion fails WFF, the whole formula fails
```

Why? An assertion might be syntactically WFF on the surface but its expansion isn't. The user should know.

`*validating-expansion?*` is t during the recursive call — prevents infinite recursion when expansions have their own expansions.

## What "WFF check disabled" means

Various callers want only some levels of WFF check. Examples:
- The canonicalizer's `*check-wff-arity-p*` and `*check-wff-semantics-p*` switches enable/disable arity and semantic checks during canonicalisation
- `wff-only-needs-syntactic-checks?()` — predicate; when t, skip everything past syntax
- `no-wff-semantics?()` — predicate; when t, skip semantic checks entirely (used by `wff-fast-gaf?`)

The granularity matters because semantic checks are expensive (require KB lookups) and not all paths need them.

## Coherence

`wff-coherent?(sentence, type)` (mostly missing-larkc 8102) — checks whether the literals in a sentence are *coherent* with each other. E.g. `(and (isa ?X Cat) (isa ?X Penguin))` is incoherent (Cat and Penguin are disjoint).

When `*check-wff-coherence?*` is t, this check runs after var-types pass.

`*coherence-violations*` accumulates the coherence-specific violations.

## Reset and lifecycle

`reset-wff-state()` is called at the start of each WFF pass:
1. If not inside the canonicalizer, clear the canon caches
2. `reset-wff-violations()`
3. `reset-wff-suggestions()`
4. `reset-at-state()` (reset arg-type state)

This ensures each WFF check starts fresh — past violations don't pollute current results.

## Cross-system consumers

- **Canonicalizer** (czer-main.lisp) calls `canon-wff-p` (= `wff-elf?` with reset) before every canonicalization
- **Assert path** (`cyc-assert-wff`) — the function name reflects "assert if WFF"
- **KE (Knowledge Editor)** uses WFF with `provide-wff-suggestions?` enabled to give the user fix suggestions
- **Pre/post canonicalization** (`safe-precanonicalizations`) consults WFF
- **WFF modules** (registered violations) — domain-specific WFF rules
- **Argumentation** — checks proof-step well-formedness via the intermediate-step validation infrastructure

## Notes for the rewrite

- **WFF is the gatekeeper.** Every assertion and every query passes through it. Performance matters — the fast-GAF path is essential.
- **`:strict` vs `:lenient` modes** are real semantic distinctions. Keep both. Strict for production, lenient for partial-knowledge contexts.
- **The five-level pipeline** (syntactic, arity, arg-type, coherence, expansion) is well-designed. Each level can be independently enabled/disabled. Don't fuse the levels.
- **Property table pattern** (`*wff-properties-table*` mapping keyword → (variable, default)) is a clean way to handle ~20 boolean overrides. Keep it.
- **WFF modules** are how violations are pluggable. KB authors can add custom WFF rules. Keep the registration interface.
- **Violation accumulation** under `*accumulating-wff-violations?*` is what enables "tell me everything wrong" UIs. Default off (faster); UIs flip it on.
- **Suggestion generation** under `*provide-wff-suggestions?*` is interactive. Default off (faster); interactive editors flip it on.
- **The `wff-fast-gaf?` six predicates** are: isa, genls, myCreator, myCreationTime, myCreationPurpose, myCreationSecond. These are the most-asserted predicates; fast-pathing them by skipping semantics gives a real perf win. Keep this list KB-tunable; new common predicates may want to be added.
- **`#$False` is non-asserting WFF.** `(eq #$False sentence) → (not (within-assert?))` — you can ask `(False)?` but you can't assert `False`. Subtle but correct.
- **Most function bodies are missing-larkc.** The shape is well-bounded by the function names. The clean rewrite must reconstruct: `mal-variables?`, `mal-forts?`, `mal-mt-spec?`, `cycl-sentence-p`, `wff-coherent?`, `wff-el-expansion`, `formula-var-types-ok-int?`, `el-wff-assertible?`, `hl-wff?`, the various `wff-cnf?`/`wff-dnf?`/`wff-naf?` dispatchers.
- **The dynamic-special vocabulary** (~30 specials in `wff-vars.lisp`) is what makes WFF customisable. Keep all of them; the names document each axis.
- **`*within-wff?*` is the recursion-detection flag** — without it, expansions could loop. Keep it.
- **`*wff-formula*`, `*wff-original-formula*`, `*wff-expansion-formula*`** are the three-level formula context: the immediate, the original input, the expansion under check. Used by deep code in violation-explanation generation.
- **Testing WFF with bad input is the production test suite** — every WFF reject case should have a test. The clean rewrite should keep this comprehensive.
- **`*permit-keyword-variables?*` and `*permit-generic-arg-variables?*`** are transient flags toggled by canonicalizer-directives (see "EL → HL canonicalization" doc). Their purpose is per-arg flexibility for specific predicates. Keep this; it's how the KB customises WFF.
- **Coherence checking is expensive.** `*check-wff-coherence?*` is on by default but can be disabled for hot paths. The clean rewrite should preserve the option.
- **Don't merge syntactic and semantic checks.** Many callers genuinely want syntactic-only (e.g. forming a query during inference where semantic is too expensive). Keep `el-wff-syntax?` as a separate entry point.
