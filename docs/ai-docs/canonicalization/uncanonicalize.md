# Uncanonicalization

The **uncanonicalizer** is the inverse of the canonicalizer (see "EL → HL canonicalization" doc): given an HL form, produce an EL form a user can read. Used wherever the engine has to *show* an assertion, rule, or query back to the user — `display-assertion`, query-results-with-supports, NL generation, KE editing.

The transformation undoes:
1. Standardised KB variables → original EL variable names (via `*ununiquified-el-vars*` and `*el-var-blist*`)
2. Reified narts → unreified function applications (when `*unreify-narts?*`)
3. Skolems → existentials
4. Removed universals → restored universals (when `*unremove-universals?*`)
5. Clausified DNF/CNF → conjunction/implication form
6. Sorted commutative args → original order (best effort; the original order is lost so the canonical order is preserved)

The system is mostly missing-larkc in the LarKC port — only the registration scaffolding and the dynamic-variable vocabulary survive. The clean rewrite must reconstruct from the function names and surrounding evidence.

Source file: `larkc-cycl/uncanonicalizer.lisp` (201 lines, mostly missing-larkc)

## When does uncanonicalization fire?

- **`assertion-el-formula(assertion)`** — registered as a Cyc API function: "Return the EL formula for ASSERTION. Does uncanonicalization, and converts HL terms to EL."
- **`assertion-el-ist-formula(assertion)`** — same but wraps the formula in `(ist <mt> ...)`.
- **`cnf-el-formula(cnf, &optional mt direction)`** — uncanonicalize a raw CNF.
- **`dnfs-el-formula(dnfs, &optional mt direction)`** — uncanonicalize a list of DNFs.
- **`el-version(formula, &optional mt)`** — generic uncanonicalization entry point.

`cnf-el-formula` and `dnfs-el-formula` take an optional `direction` argument that controls how implications are rendered (`:forward` produces `(implies P Q)`; `:backward` produces `(implies Q P)` for the same rule).

## Memoisation and caching

Two cache layers:

1. **Per-image memoisation** of `assertion-el-formula-memoized`. The cache lives in the image's memoization-state; `note-memoized-function 'assertion-el-formula-memoized`.
2. **Globally cached** `cached-assertion-el-formula-int`. Same idea, but at a different lifecycle layer — controlled by the `*cached-assertion-el-formula-int-caching-state*` deflexical with explicit `clear-cached-assertion-el-formula-int` and `remove-cached-assertion-el-formula-int` for entry-by-entry invalidation.

Both are cleared when the underlying KB changes (the `:hl-store-modified` clearing path).

`*cache-el-formula?*` (defparameter, default nil) — should the *uncanonicalizer itself* cache its computed EL formulas? When on, results are stored on the assertion. Defaults nil because most assertions don't get their EL re-shown often; storing it costs memory. Production use: nil.

## The transformation pipeline

Conceptually, uncanonicalization runs in reverse of canonicalization:

```
HL CNF/DNF
    │
    ▼ unreify-cnfs-nats — turn nart references into function applications
    │
    ▼ unreify-cnfs-terms — turn other reified terms back into their EL form
    │
    ▼ unreify-cnfs-skolem — replace skolem function calls with existentials
    │
    ▼ undo-existentials-and-refd-universals — flip negative-quantifier transformations
    │
    ▼ undo-implications — rebuild (implies P Q) from (or (not P) Q)
    │
    ▼ unremove-universals — restore (forAll ?V ...) wrappers
    │
    ▼ undo-variables — rename KB vars back to EL var names
    │
    ▼ ununiquify-el-vars — drop unique numerical suffixes
    │
    ▼ remove-truesentence-refs — clean up trueSentence wrappers
    │
    ▼ ists-out — wrap (ist mt ...) where appropriate
EL formula
```

Every step has its own missing-larkc body in the LarKC port. The pipeline is sequential; later steps depend on earlier ones (e.g. you can't undo implications until existentials are restored).

## Variable-name preservation

The single most user-visible aspect of uncanonicalization is **variable-name preservation**: the user typed `?MyDog`; canonicalization renamed it to `?V0`; uncanonicalization should restore `?MyDog`.

### `*ununiquified-el-vars*`

A per-uncanonicalization dictionary keyed on KB variables, mapping to the EL name to restore. Built up as the uncanonicalizer walks the structure.

```lisp
(defmacro remembering-ununiquified-el-vars (cnf &body body)
  `(let ((*ununiquified-el-vars* (make-hash-table)))
     (dolist (var (clause-variables ,cnf))
       (remember-ununiquified-el-var var var))
     ,@body))
```

The macro initialises the dictionary, seeds it with each variable in the CNF (each variable starts mapped to itself), and runs the body. Within the body, `remember-ununiquified-el-var(var, value)` updates the mapping; `ununiquify-el-var(var)` reads it.

### `ununiquification-conflict?`

When two different KB variables would map to the same EL name (because the user used the same name twice in different scopes), `ununiquification-conflict?(var, value)` detects the conflict and forces a rename. Without this, the output would have name collisions and the user couldn't re-canonicalise from the displayed form.

### `*el-var-blist*`

In `czer-vars.lisp`: "Stores the variable rename mappings formed while standardizing variables during uncanonicalization." This is the longer-term version of `*ununiquified-el-vars*` — used when uncanonicalisation needs to span multiple expressions and remember which vars have been renamed.

### `*ununiquify-el-vars?*`

Top-level switch in `czer-vars.lisp`. When nil, the uncanonicalizer keeps the unique numerical suffixes (`?V0`, `?V1`); when t (the default for user-display paths), it restores the original `?MyDog` names.

## Skolem unwinding

Skolems are how the canonicalizer represents existentially-quantified variables in clausified form. To display the assertion to the user, the skolems must be unwound:

- `gather-skolem-constants(formula, &optional skolems)` — collect the skolems mentioned
- `*universal-vars-to-skolem*` — hashtable mapping universal variables to the skolems that reference them
- `remove-skolem-from-universal-vars-to-skolem(skolem)` — clean up after unwinding
- `order-skolems-inner-to-outer(skolems)` — sort so the deepest skolems are processed first
- `unreify-cnfs-skolem(cnfs, skolem, vars)` — replace the skolem reference with an existential
- `expression-subst-skolem(skolem, var, formula, &optional mt)` — substitute one skolem with one variable
- `sk-fn-arg-wrt(skolem, arg, &optional mt direction)` — get the argument of a skolem function
- `sk-var-wrt(skolem, arg, &optional mt direction)` — get the variable a skolem represents

`*default-skolem-vars* = '(?X ?Y ?Z ?A ?B ?C ?D ?E)` — the variable names to use when unwinding zero-arity skolems. (Zero-arity skolems are equivalent to existential variables; we just need a fresh name.)

`segregate-skolems(skolems)` — separate skolems by argument-arity (zero-arity become bare existentials; multi-arity become universal-quantified existentials).

`init-existentialize-formula(formula, var)` and `existentialize-formula(formula, var)` — the actual quantifier-restoration step.

`undo-existentials-and-refd-universals(formula, &optional skolems)` — combined: replace skolems with existentials AND restore the universals that referenced them.

`*universal-vars-to-skolem*` — hashtable; `universal-vars-to-skolem-table(formula, &optional table)` builds it.

The clean rewrite must implement these. The shape of the work is well-bounded: walk the formula, collect skolems, segregate by arity, replace each with the appropriate quantifier expression, and clean up the references.

## Implication restoration

CNF clauses encode implications as disjunctions: `(or (not P) Q)` ≡ `(implies P Q)`. The uncanonicalizer restores the implication form for readability.

- `el-cnfs-to-el-implication(neg-cnfs, pos-cnfs)` — given the negative and positive literals, produce `(implies (and ...neg-lits...) (and ...pos-lits...))`
- `implications-in(formula)` — find sub-formulas that were originally implications
- `undo-implications(formula)` — restore implication form
- `implicatable-disjunction?(formula)` — does this disjunction look like an implication in disguise?
- `implicatable-conjunction?(formula)` — corresponding for conjunctions

The decision is heuristic: not every `(or (not P) Q)` was originally an implication. The uncanonicalizer uses context (negation pattern, KB rule structure, assertion direction) to decide.

`*uncanonicalizer-dnf-threshold* = 5` — when computing the EL form of a complex CNF, the uncanonicalizer may attempt DNF conversion to find an implicative form. The threshold caps the number of conjuncts to attempt — beyond 5, the conversion is too expensive.

## Universals restoration

Canonicalization elides leading universals. Uncanonicalization restores them.

- `unremove-universals(formula)` — restore `(forAll ?V ...)` wrappers
- `remove-leading-universals(formula)` — inverse (used elsewhere)
- `*retain-leading-universals*` (defparameter, default nil) — variables whose leading universal *should* be retained
- `*vars-to-universalize*` (defparameter, default nil) — list of variables to wrap in universals
- `add-universal-var-placeholder(formula)`, `check-for-universal-var-placeholder(formula)`, `remove-universal-var-placeholder(formula)` — placeholder-based bookkeeping for the universals

`*unremove-universals?*` (defparameter, default t) is the master switch in `czer-vars.lisp`.

## NART unreification

NARTs are HL handles for reified function applications. Uncanonicalization expands them back to the function-application syntax:

```
NART<id=42, formula=(GovernmentFn USA)> → (GovernmentFn USA)
```

- `unreify-cnfs-nats(cnfs, &optional mt direction)` — sweep through CNFs, expanding NARTs
- `naut-formula?(formula)` — is this a non-atomic-unification-term formula?
- `*unreify-narts?*` (in czer-vars) — controls this; defaults t

## IST handling

`#$ist` (in some-theory) is the contextualization predicate. The uncanonicalizer:

- `ists-out(formula)` — wrap relevant assertions in `(ist <mt> ...)` when their MT differs from the surrounding context
- `simplifiable-ist-expression?(expression)` — predicate
- `simplify-ist-expression(expression)` — collapse nested IST forms
- `base-kb-ist-sentence?(sentence)` — is this an `(ist BaseKB ...)` sentence? (handled specially because BaseKB is the default context)

## Tense handling

`*potentially-interestingly-uncanonicalizable-tense-terms* = (#$IntervalEndedByFn #$IntervalStartedByFn)` — terms involving these functors are candidates for tensed-literal restoration.

`*uncanonicalize-tensed-literals?*` (defparameter, default t, in czer-vars) — should tensed forms be reconstructed?

When on, an assertion like `(holdsIn TimeAfterX P)` may be displayed as `(was P TimeBeforeX)` or `(willBe P TimeAfterX)` for readability.

## Pragmatic requirements and exceptions

- `el-pragmatic-requirements(formula)` — extract the pragmatic-requirement portion of the formula
- `el-pragmatic-requirement(formula)` — single-requirement variant
- `el-exceptions(formula)` — extract exception clauses
- `el-except-for(formula)` — `(exceptFor ...)` clauses
- `el-except-when(formula)` — `(exceptWhen ...)` clauses

The uncanonicalizer separates these from the main formula structure so the user sees them distinctly: a rule plus its pragmatic requirements plus its exceptions, rather than one giant conjunction.

## Recursive query uncanonicalisation

- `uncanonicalize-recursive-query(formula)` — special handling for queries used in recursive contexts
- `uncanonicalize-recursive-query-vars(formula)` — variable handling for recursive queries

A recursive query has special variable scoping: variables in the inner query shouldn't conflict with variables in the outer. The uncanonicalizer ensures the displayed form has a consistent variable namespace.

## Removing index lits, TOU lits, evaluate lits

After clausification, the canonicalizer adds bookkeeping literals (index, term-of-unit, evaluate). The uncanonicalizer strips these for display:

- `index-lits-to-remove(cnf)` — index literals to drop
- `tou-lits-to-remove(cnf)` — term-of-unit literals to drop
- `evaluate-lits-to-remove(cnf)` — evaluate literals to drop
- `equals-lits-to-remove(cnf)` — equals literals that are bookkeeping
- `remove-index-lits-from-cnfs(cnfs, index-lits)` — actual removal
- `subst-index-in(formula, index)` — substitute the index literal's binding into the formula
- `variable-should-not-be-substituted-during-uncze?(var, cnf)` — predicate that gates substitution

These bookkeeping literals are essential for the *engine* but irrelevant to the *user*. Stripping them produces clean output.

## Public API

```
(register-cyc-api-function 'assertion-el-formula '(assertion)
  "Return the EL formula for ASSERTION.  Does uncanonicalization, and converts HL terms to EL."
  '((assertion assertion-p))
  '(listp))

(register-cyc-api-function 'assertion-el-ist-formula '(assertion)
  "Return the el formula in #$ist format for ASSERTION."
  '((assertion assertion-p))
  '(consp))
```

These are the registered Cyc API entries. Internal callers use `el-version`, `cnf-el-formula`, `dnfs-el-formula` directly.

## Cross-system consumers

- **KE (Knowledge Editor)** displays assertions to users as EL — calls `assertion-el-formula` extensively
- **Argumentation / explanation** renders proof supports as EL formulas
- **Inference results** with `:answer-language :el` use uncanonicalization to convert HL bindings back to EL
- **Transcript display** — reading a transcript means uncanonicalising each operation
- **API responses** — most external API responses use EL form
- **NL generation** — natural-language generators take EL as input

## Notes for the rewrite

- **Uncanonicalization is *not* the inverse of canonicalisation.** It is *one possible inverse*. There are infinitely many EL forms that canonicalise to the same HL; the uncanonicalizer picks one according to readability heuristics. Don't expect round-trip equality (canonicalize → uncanonicalize → canonicalize will yield the same canonical form, but uncanonicalize → canonicalize → uncanonicalize might not).
- **Variable-name preservation is user-visible.** A user who typed `?MyDog` and saw `?V0` back would think the system lost their input. Keep `*ununiquified-el-vars*` working.
- **Conflict resolution for variable names** matters: when two scopes use the same name, neither can be restored without disambiguation. Document the disambiguation rule (suggest: numeric suffix on the second occurrence).
- **Skolem unwinding is the most subtle step.** Each skolem represents an existentially-quantified variable in the inner scope of some universal quantifiers. Restoring the right `(thereExists ?V ...)` requires knowing which universals the skolem references. `*universal-vars-to-skolem*` tracks this.
- **`*unreify-narts?*` controls NART display.** Off in some KE-internal paths (where the user wants to see the NART handle); on in user-facing paths.
- **`*uncanonicalize-tensed-literals?*`** affects how tensed forms render. Useful for natural-sounding output but risks producing tense-shifts that lose information.
- **Bookkeeping-literal stripping is essential for readability.** Don't skip; the user shouldn't see `(termOfUnit ?V Nart-12345)` literals.
- **The implications-restoration heuristic is empirical.** Some `(or (not P) Q)` forms were originally implications; some weren't. The uncanonicalizer guesses based on context. Document the guess heuristic; it's user-visible behaviour.
- **`*uncanonicalizer-dnf-threshold* = 5`** caps DNF conversion attempts. Don't change without understanding why; raising it makes uncanonicalisation slow on complex assertions.
- **Most function bodies are missing-larkc.** The signatures and intent are documented in the function names and the cluster of accessors. The clean rewrite must reconstruct each. The shape:
  - `el-version(formula, mt)` is the top entry
  - It runs the pipeline sequentially: skolem-unwind, implication-restore, universals-restore, NART-unreify, IST-out, variable-rename
  - Each pipeline step is a recursive walk over the formula
- **Per-direction handling** — the `direction` argument of `cnf-el-formula` etc. controls how rules are oriented. `:forward` makes the rule's antecedent the LHS; `:backward` makes the consequent the LHS. Both are correct EL forms; the choice is presentation.
- **`*cache-el-formula?*` defaults nil**. Most assertions are uncanonicalised once or twice in their lifetime; caching costs more memory than it saves. Keep this default.
- **Pragmatic requirements and exceptions are separated for display.** Don't fold them into the main formula in the user-facing output; they're conceptually separate.
- **The Cyc API surface is small.** Just `assertion-el-formula` and `assertion-el-ist-formula` are registered. Internal callers use the lower-level entries directly.
