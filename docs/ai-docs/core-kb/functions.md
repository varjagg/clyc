# Functions and function terms

"Function" in CycL means **a relation that produces a referent value when applied to arguments**, distinct from a *predicate* (which produces a truth value). `(MotherFn Bart)` denotes Marge; `(isa Marge Person)` is a predicate application that's true or false.

Functions are not defined by code in CycL — they're constants that are typed (via `isa`) into one or more **function classes**. The class membership is what tells the system how to handle an application:

- **`#$Function-Denotational`** — the broad class for non-predicate functions. Membership in any sub-collection of this is what `non-predicate-function?` / `functor?` checks for.
- **`#$ReifiableFunction`** — the function's applications can be **reified** as NARTs and stored in the KB. The reified term gets its own identity. See [narts.md](narts.md).
- **`#$EvaluatableFunction`** — the function's applications are **computed** at use time, by Lisp/SubL code, and have no KB identity. `(PlusFn 2 3)` is just `5`.
- **`#$SkolemFunction`** — Skolem-introduced function symbols, generated during canonicalization.
- **`#$LogicalConnective`** — `#$and`, `#$or`, `#$not`, `#$implies`, `#$xor`, etc.
- **`#$Quantifier`** — `#$forAll`, `#$thereExists`, `#$thereExistsExactly`, etc.
- **`#$ScopingRelation`** — relations that scope variable bindings (quantifiers + others).

A given function constant can be in several of these. `#$PlusFn` is `EvaluatableFunction` and not `ReifiableFunction`. `#$MotherFn` is `ReifiableFunction` and not `EvaluatableFunction`. The combination determines what the inference engine and the canonicalizer do with applications of it.

## Type checks

All in `fort-types-interface.lisp`. Each is `(fort-has-type-in-any-mt? fort #$SomeCollection)` underneath; the surface forms exist for readability and to gate on `*anect-mt*` (the always-relevant collection MT) where required.

| Check | Class membership |
|---|---|
| `function-in-any-mt?` / `function?` / `functor?` / `non-predicate-function?` | `#$Function-Denotational` |
| `reifiable-function-p` / `isa-reifiable-function?` | `#$ReifiableFunction` |
| `evaluatable-function-p` | `#$EvaluatableFunction` |
| `evaluatable-predicate-p` | `#$EvaluatablePredicate` |
| `predicate-p` / `predicate?` / `predicate-in-any-mt?` | `#$Predicate` |
| `relation-p` | `#$Relation` |
| `logical-connective-p` | `#$LogicalConnective` |
| `quantifier-p` | `#$Quantifier` |
| `scoping-relation-p` | `#$ScopingRelation` |
| `skolem-function-p` | `#$SkolemFunction` |
| `commutative-relation-p`, `symmetric-binary-predicate-p`, `transitive-binary-predicate-p`, `irreflexive-binary-predicate-p`, `reflexive-binary-predicate-p`, `asymmetric-binary-predicate-p`, `anti-symmetric-binary-predicate-p`, `anti-transitive-binary-predicate-p` | self-explanatory algebraic property collections |
| `variable-arity-relation-p` | `#$VariableArityRelation` (variable arity, `arity-min`/`arity-max`) |
| `bookkeeping-predicate-p` | bookkeeping predicates (creator, comment, etc.) |
| `microtheory-designating-relation-p` | relations whose value is an MT |
| `mt?` | `#$Microtheory` |
| `evaluatable-relation-contextualized-p` | true when a function's evaluation depends on the current MT |
| `el-relation-p` | `#$ELRelation` (EL-only constructs that get rewritten by canonicalization) |
| `partially-commutative-relation-p` / `partially-commutative-predicate-p` | `#$PartiallyCommutativeRelation` |
| `bounded-existential-quantifier-p` | bounded-existential operators |

The `isa-X?` family (e.g. `isa-predicate?`, `isa-mt?`, `isa-collection?`, `isa-quantifier?`) is the polymorphic version: handles a FORT directly, falls back to a regular `isa?` check for non-FORT terms.

`with-all-mts` is the macro that broadens the inference MT scope so the type check answers across the whole KB rather than the active MT. Most function-class queries use it.

## Function call (NAT) shape

Wherever you see `(functor arg1 ... argN)` in CycL data, the same operations apply regardless of whether it's an EL formula, a NAUT, a NART body, etc. Helpers in `el-utilities.lisp`, `term.lisp`, `formula-pattern-match.lisp`:

```
(formula-operator formula)        ; the functor (car-equivalent)
(formula-args formula)            ; the args (cdr-equivalent)
(formula-arity formula)           ; (length args)
(nat-functor naut)                ; functor specifically of a NAT
(nat-arg1 naut), (nat-arg2 naut)  ; positional accessors
(el-formula-p obj)                ; is this an EL formula
(el-formula-with-operator-p obj op)
(possibly-naut-p obj)             ; is it shaped like a NAT
```

There is no per-functor protocol or dispatch table beyond the type-class membership tests above. The whole "function" abstraction is sentence-shape + class-membership; concrete behavior is determined either by the `#$evaluationDefn` predicate (for evaluatable) or by reification rules (for reifiable).

## Arity (`arity.lisp`)

Arity for a relation is read from `(#$arity relation N)` GAFs at KB load time, cached, and consulted by validation, indexing, and inference.

```
*kb-arity-table*       (eq hash table)   relation → arity
*kb-arity-min-table*                     relation → min arity (variable-arity)
*kb-arity-max-table*                     relation → max arity
```

```
(arity relation)         ; → integer or NIL; handles fort, kappa-predicate, lambda-function, reifiable-nat
(arity-min relation)     ; → integer (default 0)
(arity-max relation)
(set-arity relation n)   ; raw setter, no MT check
(maybe-add-arity-for-relation relation arity)    ; fails if arity already set differently
(maybe-remove-arity-for-relation relation arity) ; consults remaining (#$arity ...) GAFs
(binary? relation)       ; arity = 2
(binary-arg-swap arg)    ; 1 ↔ 2
(variable-arity? relation)
(arity-cache-unbuilt?)
(load-arity-cache-from-stream stream)            ; CFASL: 4 hashtables in sequence
```

`*kb-arity-table*` is dumped/loaded as a single CFASL hashtable; the dump format is four hashtables in sequence (arity, min, max, and one more — fourth is read but discarded in the port; likely the `#$resultIsa` or arg-count cache).

Many of the maintenance functions (`initialize-arity-table`, `rebuild-arity-cache`, `dump-arity-cache-to-stream`, `arity-admits?`, `arity-admits>=`, etc.) are LarKC-stripped — only the load path and direct setters survive in the port.

A clean rewrite should treat arity as a derived view over `(#$arity ...)` and `(#$arityMin ...)` / `(#$arityMax ...)` assertions, with cache invalidation on those specific GAFs.

## Function evaluation (`relation-evaluation.lisp`)

The dispatch path for `cyc-evaluate`:

```
(cyc-evaluate expression) → (values answer valid? contextualized?)
```

1. `formula-operator` → `relation`.
2. `evaluatable-relation?` gate — `evaluatable-function?` OR `evaluatable-predicate?`. Function side admits FORT-typed `EvaluatableFunction`, `function-to-arg-function-p` (`(#$FunctionToArg N fn)`-shaped), and `lambda-function-p` (`(#$Lambda (args) body)`-shaped).
3. `evaluation-function relation` → the SubL/CL function symbol that implements the evaluation.
   - For a FORT: cached result of `evaluation-defn relation` (which reads `(#$evaluationDefn relation symbol)` from the KB).
   - For `function-to-arg`: returns `'cyc-function-to-arg`.
   - For `lambda-function`: returns `'cyc-lambda`.
4. `evaluation-arity relation` → expected arg count, used to validate.
5. `cyc-evaluate-args` recursively evaluates each arg (so `(PlusFn (TimesFn 2 3) 4)` becomes `(PlusFn 6 4)` becomes `10`).
6. The actual call is dispatched via `possibly-cyc-api-funcall-1` — i.e. through the Cyc API surface, so unsafe Lisp functions can't sneak in.
7. If args were rewritten (something was evaluated), `note-evaluation-function-support` records the support; otherwise no support change.

Special vars used during evaluation:

| Var | Purpose |
|---|---|
| `*cyc-evaluate-relation*` | the relation currently being evaluated (for the inner function to introspect) |
| `*cyc-evaluate-gather-justifications?*` | when true, every step records a support |
| `*cyc-evaluate-supports*` | accumulator for the above |
| `*cyc-evaluate-some-contextualized-relation?*` | becomes true if any contextualized relation was used |

`cyc-evaluate` catches `:unevaluatable` so a bottoming-out arg can abort the whole evaluation cleanly.

`cyc-evaluate-if-evaluatable` is the lazy wrapper: returns the input unchanged if not evaluatable; otherwise evaluates.

A clean rewrite can fold `function-to-arg` and `lambda-function` into the same single dispatch by treating them as just-another `evaluationDefn`.

## Function-to-arg

```
(#$FunctionToArg N functor)    →  the function "extract arg N from the result of applying functor"
```

`function-to-arg-function-p` checks the EL formula shape; the actual evaluation is `cyc-function-to-arg`. Used as a way to pick a specific arg position from a function that returns a complex structured value, without introducing a new constant.

## Lambda

```
(#$Lambda (var1 ... varN) body)    →  an inline anonymous function
```

`lambda-function-p` checks the shape. Evaluation pairs args with vars, substitutes into body, evaluates the result. `evaluation-arity` of a lambda is the arg-vector length. The implementation in port is `missing-larkc` (30575).

## Skolems

Skolem functions are introduced by canonicalization to eliminate existential quantifiers (`#$thereExists`). Each skolem function is a constant; the **predicate** that introduces it is `#$skolem`, and `(reified-skolem-fn-in-any-mt? constant t t)` checks whether removing a constant would break a Skolem dependency. Skolem function application (e.g. `(SkolemFn-1234 ?X)`) reifies as a NART like any other reifiable function.

`skolems.lisp` owns this. Most of the heavyweight machinery (skolemize-forward / skolemize-existential / clausifier integration) is preserved, but `reified-skolem-fn-in-any-mt?` is the only check called by `remove-everything-about-constant`.

## Reifiable functor admission (`czer-utilities.lisp:reifiable-functor?`)

Closer to canonicalization than to function classification, but core to the function story: this is the gate that decides at NAT-application time whether the formula `(functor arg1 ... argN)` is a candidate for NART reification.

```
(reifiable-functor? functor &optional mt)
```

True when `functor` is in `#$ReifiableFunction` in the relevant MT(s). Walked by `nart-substitute-recursive` and `find-nart` to short-circuit non-reifiable applications. Sub-functor cases (function applied to a function-result) are handled in the same predicate.

## Public API surface for "function"-related things

All of these are registered as Cyc API functions where shown:

```
(arity relation)                       ; cyc-api
(non-predicate-function? fort)
(reifiable-function-p fort) (isa-reifiable-function? term &optional mt)
(evaluatable-function-p fort)
(evaluatable-predicate-p fort &optional mt)
(evaluatable-relation? relation)
(evaluatable-expression? object)
(predicate-p fort)
(logical-connective-p fort) (quantifier-p fort) (scoping-relation-p fort)
(commutative-relation-p fort) (symmetric-binary-predicate-p fort) ; ...
(cyc-evaluate expression)              ; cyc-api: returns (values answer valid? contextualized?)
(cyc-evaluate-if-evaluatable expr)
(evaluation-function relation)
(evaluation-defn fort &optional mt)
(function-to-arg-function-p obj)
(lambda-function-p obj)
```

## Files

| File | Role |
|---|---|
| `fort-types-interface.lisp` | every function-class membership predicate (`function?`, `predicate?`, `quantifier-p`, `reifiable-function-p`, etc.) |
| `arity.lisp` | arity / arity-min / arity-max tables and lookups |
| `relation-evaluation.lisp` | `cyc-evaluate`, `evaluation-function`, `evaluation-defn`, function-to-arg, lambda |
| `function-terms.lisp` | NAT predicates and complexity, `term-of-unit-assertion-p`, `naut-to-nart` |
| `term.lisp` | low-level NAT/CycL-NAT predicates |
| `el-utilities.lisp` | `formula-operator`, `formula-args`, `formula-arity`, `nat-functor`, etc. |
| `czer-utilities.lisp` | `reifiable-functor?` gate |
| `skolems.lisp` | Skolem function introduction |

## Notes for a clean rewrite

- Function class membership is a graph query against `isa`/`genls` — `fort-has-type-in-any-mt?` does an SBHL traversal each call. The forty+ predicates in `fort-types-interface.lisp` could be a single `(fort-has-type? fort 'collection)` macro plus a list of the well-known classes.
- Arity should be derived from `(#$arity ...)` GAFs with cache invalidation, not pre-cached at startup. The current `*kb-arity-table*` is dumped to `.cfasl` and loaded back — duplicating data already in the assertion store.
- `cyc-evaluate` and `function-to-arg`/`lambda` have parallel implementations. Unify under one dispatch keyed on a single attribute (the evaluation function symbol).
- The `*cyc-evaluate-supports*` machinery is opt-in via a special var. A clean rewrite can pass an explicit context object instead.
- `evaluatable-relation-contextualized-p` exists so the answer to `(SomeFn ...)` can vary by MT. This is rare and probably worth a feature flag rather than always-on.
- `register-cyc-api-function` is duplicated for every public entry point. The exposed surface should be a single declaration that synthesizes all the registrations.
