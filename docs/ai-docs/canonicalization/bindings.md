# Bindings and unification

A **binding** is a (variable, value) pair. A **binding list** is a list of bindings, conventionally read as a substitution from left to right. **Unification** is the process of finding a binding list that makes two terms structurally equal.

These are the three foundations of every match-and-substitute operation in the engine:
- Pattern matching against the KB (find all assertions matching `(isa ?X Cat)`)
- Rule firing (apply rule's bindings to its consequent)
- Inference proof bubbling (transfer parent variables into child bindings)
- Variable canonicalization (rename variables consistently)

Source files:
- `larkc-cycl/bindings.lisp` (384) — the binding-list datastructure and operations
- `larkc-cycl/unification.lisp` (357) — the unification algorithm
- `larkc-cycl/unification-utilities.lisp` (112) — small helpers and post-processing

## What's a binding?

A *binding* is a single `(variable . value)` cons cell:

```lisp
(make-variable-binding ?X #$Cat)  ; → (?X . #$Cat)
(variable-binding-variable b)     ; → ?X
(variable-binding-value b)        ; → #$Cat
```

A *binding list* is a list of these:

```
((?X . #$Cat) (?Y . #$Animal))
```

Reading: "?X is bound to #$Cat, ?Y is bound to #$Animal."

`binding-p(object)` — is this a binding? (Just `(consp object)` — bindings are conses.)
`binding-list-p(object)` — is this a non-dotted list of bindings?

## Three flavours of binding

Bindings exist at three levels of abstraction:

1. **Inference binding** — `(?el-var . <value>)` — used inside the inference engine. The variable is an EL variable.
2. **HL binding** — `(?hl-var . <value>)` — variable is an HL (KB) variable; used after canonicalisation.
3. **KB binding** — `(#$ELInferenceBindingFn ?var <value>)` as a NAUT — represented in the KB as a real assertion.

```lisp
(defun inference-binding-p (object)
  "True if OBJECT is of the form (<el-var> . <whatever>)."
  (and (binding-p object)
       (el-var? (variable-binding-variable object))))

(defun kb-binding-p (object)
  "True if OBJECT is of the form (#$ELInferenceBindingFn <var> <whatever>)"
  (and (possibly-naut-p object)
       (eq (nat-functor object) *el-inference-binding-fn*)
       (el-var? (nat-arg1 object))))
```

The KB form (`#$ELInferenceBindingFn`) lets bindings be stored in the KB as terms — used for queries that take bindings as arguments.

`*el-inference-binding-fn*` is the constant for `#$ELInferenceBindingFn`.

`kb-binding-set-p(object)` — true if a `#$TheSet` of `kb-binding-p` items.

## HL identity bindings

A common operation: produce bindings where every variable maps to itself. `hl-identity-bindings(n)` returns `((?varN-1 . ?varN-1) ... (?var0 . ?var0))` — used as the starting point for chains of substitutions.

Cached via `defun-cached`, eql-keyed, initial size 10. Each call adds one variable to the cached result.

## Operations on bindings

### Construction

```
(make-variable-binding variable value) → binding
(add-variable-binding variable value bindings) → bindings'
```

`add-variable-binding` *cons*es; doesn't check for duplicates.

### Lookup

```
(get-variable-binding variable bindings) → binding or nil
(get-value-binding value bindings &optional test) → binding or nil
(variable-bound-p variable bindings) → boolean
(variable-lookup variable bindings) → value or nil
(bindings-variables bindings) → list of variables
(bindings-values bindings) → list of values
```

`get-variable-binding` is the primary lookup; uses `assoc`. `get-value-binding` does reverse lookup via `rassoc`.

### Equality

```
(bindings-equal? b1 b2) → boolean
```

Compares *as sets*, not as ordered lists — `((?X . a) (?Y . b))` equals `((?Y . b) (?X . a))`.

### Substitution

```
(apply-bindings bindings tree) → new tree
(apply-binding binding tree) → new tree
(napply-bindings bindings tree) → tree (destructive)
```

`apply-bindings` substitutes every occurrence of a variable in the bindings list with its value, anywhere in `tree`. Implemented via `sublis`. The destructive `napply-bindings` uses `nsublis` with `eq` comparison.

```
(apply-bindings-backwards bindings tree) → new tree
(apply-bindings-backwards-to-list bindings list) → new list
(napply-bindings-backwards-to-list bindings list) → list (destructive)
```

The "backwards" variants substitute *values* with *variables* — e.g. given `((?X . #$Cat))`, find every `#$Cat` in tree and replace with `?X`. Used in uncanonicalisation.

```
(apply-bindings-to-values bindings-to-apply target-bindings) → bindings'
```

Apply `bindings-to-apply` to the *values* of `target-bindings`. Used to compose two binding lists where the first transforms the second's right-hand side.

### Subst-bindings (safer apply)

```
(subst-bindings bindings object) → object'
```

Like `apply-bindings` but checks `binding-list-p` first; returns `object` unchanged if `bindings` is not a valid binding list. Safer when the input might be `:unification-failure` or another sentinel.

## Variable maps

A *variable map* is structurally a binding list, but semantically maps one variable to another (not a variable to a value). Used to rename variables during scope changes.

```
(transfer-variable-map-to-bindings a-to-b-variable-map a-to-c-bindings)
  → b-to-c-bindings
```

Given:
- `a-to-b`: `((?X . ?Y))` (rename ?X to ?Y)
- `a-to-c`: `((?X . #$Muffet))` (?X bound to Muffet)

Produces: `((?Y . #$Muffet))` — the binding for ?X now applies to ?Y.

```
(transfer-variable-map-to-bindings-filtered a-to-b a-to-c)
```

Same but skips bindings for variables not in the map (rather than erroring).

```
(transfer-variable-map-to-bindings-backwards a-to-b b-to-c)
```

Inverse direction.

```
(compose-bindings a-to-b-variable-map b-to-c-bindings)
```

Two-step composition: rename variables, then look up values.

## Unification

Unification is "given two terms, find the variable substitution that makes them equal."

### Public entry points

```
unify(obj-trans, obj, &optional share-vars?, justify?) → bindings or nil
```

Returns:
- `nil` — unification fails
- `unification-success-token-p` — succeeds without any bindings (terms were already equal)
- `bindings-p` — succeeds with the binding list
- `set-p of bindings-p` — when `*unify-multiple?*` is t, returns multiple binding sets

`share-vars?`:
- `nil` — variables in obj-trans and obj are in *different* variable spaces; pre-process to uniquify before unifying
- `t` — variables share the same space (no pre-processing)

`justify?`:
- `t` — also return a justification list explaining the unification
- `nil` — no justification

```
unify-assuming-bindings(obj-trans, obj, share-vars?, assume-bindings, justify?)
  → bindings, justifications
```

Like `unify` but with pre-existing bindings as context. The MGU is computed *given* `assume-bindings` already in force.

### Fast-fail: `unify-possible`

Unification can be expensive. `unify-possible(obj1, obj2)` is a *cheap necessary condition*: returns false only if unification is *definitely* impossible. Used as a guard before the full unification call.

```
unify-possible(obj1, obj2):
  cond:
    (eql obj1 obj2) → t
    (variable-p obj1) → t
    (variable-p obj2) → t
    (term-variable-p obj1 AND term-variable-p obj2) →
      (when *unify-term-variable-enabled?*: missing-larkc 31782)
    (fort-p obj1) → unify-possible-fort
    (fort-p obj2) → unify-possible-fort (swapped)
    (consp obj1 AND consp obj2) → unify-possible-cons
    (atom obj1 AND atom obj2) → unify-possible-atom
    else → nil
```

The recursion mirrors the actual unifier: same shape, same dispatch, but only the cheap test (no binding accumulation).

### Configuration

`*unify-term-variable-enabled?*` (defvar, default t) — allow EL term variables to unify with each other. The "Temporary control variable" comment suggests this should always be on; the clean rewrite can remove the flag.

`*unify-possible-cons-function*` and `*unify-cons-function*` — extension points for custom cons-unifiers (defaults `:default`). The custom function is called on every cons-pair during unification; lets domain-specific code override how cons-trees match.

`*unify-multiple?*` (defparameter, default nil) — when true, return *all* possible bindings, not just the first.

`*computing-variable-map?*` (defparameter, default nil) — restrict unification to bind HL variables to *not-yet-bound* HL variables. Used in canonicalisation to compute variable renames.

`*unify-return-justification?*` (defparameter, default nil) — return a justification list. Currently only works when `*unify-multiple?*` is nil.

`*variable-base-max* = 100` — the maximum variable-base ID for fresh variable allocation during unification.

### `with-unifier-justifications` macro

```lisp
(defmacro with-unifier-justifications (&body body)
  `(let ((*unify-return-justification?* t))
     ,@body))
```

Scoped binding to enable justification accumulation for the body.

### Unification possible: per-type predicates

`unify-possible-fort(fort, obj)` — checks if a fort and another object can unify:
- If obj is nil, no
- If fort is a constant, both must be the same constant (or obj must be a variable)
- If fort is a NART, get its EL formula and recurse cons-vs-cons

`unify-possible-constant(constant, obj)` — constant unifies with itself or with any value-equal object

`unify-possible-cons(cons1, cons2)` — recurse on car and cdr

`unify-possible-atom(atom1, atom2)` — must be `equal`

The full unifier (`unify-assuming-bindings`) does the same dispatch with binding accumulation.

## Pre-unify replacement

When `share-vars?` is nil, `pre-unify-replace-variables(obj-trans)` is called to *rename* obj-trans's variables to fresh ones in a separate space. This prevents accidental capture: if both terms use `?X`, but they're meant to be distinct uses, the rename ensures unification doesn't conflate them.

The fresh-variable allocation uses `*variable-base-max* = 100` as the base; new vars are `?V100`, `?V101`, etc.

## Unification utilities

`unification-utilities.lisp` (112 lines) provides smaller helpers:

- `unification-success-token` — the canonical "success without bindings" token
- `unification-success-token-p(object)` — predicate
- `pre-unify-replace-variables(obj)` — fresh-variable rename
- Various helpers for unifying specific shapes (mostly missing-larkc)

The success token distinguishes "unification succeeded with empty bindings" from "unification failed":
- `nil` — fail
- `*unification-success-token*` — succeed, no bindings needed
- `((?X . a) ...)` — succeed with bindings

## When does unification fire?

| Trigger | Path |
|---|---|
| Pattern matching | `formula-pattern-match.lisp` calls `unify` for `:unify` patterns |
| Rule firing | Transformation worker calls `unify` to match rule consequent against goal |
| GAF lookup | `gaf-asent-unify(asent, gaf-formula)` checks if a stored GAF matches a query asent |
| Removal modules | Many removal modules call `unify` to extract bindings |
| Argumentation | Justification computation uses bindings |
| Inference answer extraction | `inference-hl-bindings-from-proof` uses variable maps |
| Canonicalization | Variable renaming uses unification with `*computing-variable-map?*` = t |

## Cross-system consumers

Bindings are universally consumed:
- **Inference engine** — every proof has bindings; every answer is built from bindings
- **Canonicalizer** — variable renaming
- **WFF / AT** — variable type inference uses binding propagation
- **Pattern matching** — `:unify` patterns return bindings
- **Removal modules** — produce bindings via their `:expand` functions
- **Forward inference** — applies rule bindings to derived conclusions
- **TMS** — argument bindings determine truth-value derivation
- **Uncanonicalizer** — variable name restoration uses backward-substitution

## Notes for the rewrite

### Bindings

- **The cons-cell representation** (`(var . value)`) is dirt cheap and ubiquitous. Don't replace with a struct unless you measure overhead; the simple representation is what makes the operations efficient.
- **`bindings-equal?`** compares as sets. Make sure callers know this — comparing as ordered lists would be incorrect.
- **Three binding flavours** (inference / HL / KB) are not interchangeable. Don't assume binding-p is enough; use the more specific predicates when relevant.
- **`hl-identity-bindings`** is cached because it's called every time variables are introduced. Keep the cache.
- **Forward and backward apply-bindings**: keep both; the backward direction is essential for uncanonicalisation.
- **`napply-bindings` uses `eq`**: bindings substitute by identity, not equality. This is correct for variable substitution; `equal` would do the wrong thing for self-referential structures.
- **Variable maps and bindings are structurally identical but semantically different.** Keep them as distinct types in the rewrite; the structural overlap should not cause confusion at the type level.

### Unification

- **`unify-possible` is the fast-fail.** Always call before `unify` if the result is likely to fail. The two functions share dispatch shape; keep them in sync.
- **`*unify-multiple?*` defaults nil**. Most callers want the first MGU. Keep the default; multi-MGU is for specific cases (e.g. abductive reasoning).
- **`*unify-term-variable-enabled?*` should always be t.** The flag is a "temporary control variable"; remove in the clean rewrite.
- **`*unify-cons-function*` and `*unify-possible-cons-function*`** are extension hooks. Domain-specific cons-handling (e.g. for sequence variables) plugs in here. Keep the hooks.
- **`pre-unify-replace-variables`** is the variable-space-isolation step. Without it, two clauses both using `?X` would conflate. Essential.
- **The success token** distinguishes "succeeded, nothing to bind" from "failed." Don't drop it; both are real outcomes.
- **Justifications are optional.** Most callers don't care; only argumentation and proof-construction do. Keep `*unify-return-justification?*` flag.
- **`*computing-variable-map?*`** restricts unification to variable-to-variable bindings. Used during canonicalisation. Keep the mode; it's how the canonicalizer uses unification to compute variable renames.
- **Most function bodies are missing-larkc**. The shape is well-bounded: pattern-match the two terms, recurse with binding accumulation, fail on type mismatch. The clean rewrite must reconstruct the algorithm carefully — bugs here cause silent inference errors.
- **Sequence variables** are a wrinkle. The unifier needs to handle them: a sequence variable in obj-trans can match multiple args in obj. Don't skip; `*unify-cons-function*` is the customisation point.
- **Skolems** unify like constants (with themselves) — but the clean rewrite must check the actual semantics; some skolem subclasses unify more permissively.
- **Performance matters.** Unification runs millions of times per query. Profile the rewrite; the fast-fail (`unify-possible`) and the eq-based substitution (`napply-bindings`) are the hot paths.
- **The constants `*variable-base-max* = 100`** is empirical. Higher bases let more "fresh" variables be allocated without conflict; lower bases save memory. Keep 100 unless profiling shows otherwise.
