# Pre- and post-canonicalization, plus the simplifier

The full canonicalization story has three layers around the main canonicalizer (`czer-main.lisp`):

1. **Precanonicalization** runs *before* the main canonicalizer. It expands EL-relation expressions, evaluates evaluatable subexpressions, and removes implicit meta-literal sentences. Done destructively to avoid copying overhead. Output: a formula ready for clausification.
2. **Main canonicalizer** (covered in "EL → HL canonicalization" doc) runs clausify → simplify → quiesce in a loop.
3. **Postcanonicalization** runs *after* the main canonicalizer. It handles canonicalisations the main pass couldn't — primarily pragmatic-requirement canonicalisation in disjunctions.
4. **Simplifier** is the shared infrastructure for *syntactic* simplification used by all three layers: lift nested conjunctions/disjunctions, drop unary juncts, eliminate duplicates, simplify special cases.

The pre/post split exists because some transformations don't fit the main canonicalizer's clausify-and-iterate model — they need either a setup pass (pre) or a cleanup pass (post).

Source files:
- `larkc-cycl/precanonicalizer.lisp` (167)
- `larkc-cycl/postcanonicalizer.lisp` (78)
- `larkc-cycl/simplifier.lisp` (690)

## Precanonicalization

The precanonicalization phase performs *non-clausification* transformations: expanding EL-relations, evaluating constants, eliminating implicit meta-literals. The result is a formula in a shape the main canonicalizer can ingest cleanly.

### Three classes of precanonicalization

`precanonicalizations?(formula, mt, &optional formula-is-an-asent-with-no-subformulas?)` is the predicate: "does this formula need precanonicalization?" It returns true if any of three conditions hold:

1. **Expandible EL-relation expression** — `expandible-el-relation-expression?` matches anywhere in the formula. EL-relations are user-friendly forms like `(elementOf X (TheSetOf ?V (P ?V)))` that the canonicalizer prefers as the underlying CycL form.
2. **EL-evaluatable expression** — a function term whose functor has `(evaluateAtEL <fn>)` asserted in the KB. The expression should be evaluated at canonicalization time and replaced with the result. E.g. `(plus 1 2)` becomes `3`.
3. **EL-implicit-meta-literal sentence** — a sentence that implicitly involves meta-literals (e.g. `(assertedSentence ...)` patterns). Should be made explicit before the main canonicalizer runs.

The fast-path argument `formula-is-an-asent-with-no-subformulas?` skips the recursive `formula-find-if` walk; called from `canon-fast-gaf?` for atomic GAFs that can't have nested expandible expressions.

### `safe-precanonicalizations` and `precanonicalizations`

Two entry points:
- `safe-precanonicalizations(formula, mt)` — non-destructive; allocates fresh memoization state if needed
- `precanonicalizations(formula, mt)` — destructive; mutates the input formula

Both delegate to `precanonicalizations-int(formula, mt)` (missing-larkc; the actual transformation engine). The difference is whether the EL-symbol-suffix table and standardize-variables-memory are bound fresh, and whether mutation is allowed.

The *destructive* path is the production path: copying the formula at every canonicalization step would dominate the work. Mutation is safe because the formula is owned by the caller — the canonicalizer is the only writer.

### EL-evaluatable expressions

`el-evaluatable-functor?(object, &optional mt)` — is this functor declared `(evaluateAtEL ...)` in the relevant MT?

```
(defun el-evaluatable-functor? (object &optional mt)
  (when (fort-p object)
    (and (el-evaluatable-functor-somewhere? object)
         (some-pred-value-in-relevant-mts object #$evaluateAtEL mt)
         t)))
```

Two-stage check: cheap "exists somewhere" lookup first, then MT-relevance check.

`el-evaluatable-expression?(object, &optional mt)` — is this an evaluatable expression? Functor is evaluatable AND the args are evaluatable AND the expression is well-formed. Two of those checks are missing-larkc.

`transform-evaluation-expression(expression)` (missing-larkc) — actually evaluate. The result replaces the expression in the formula.

`transform-evaluation-expression-or-throw` (missing-larkc) — same but throws on failure (used when failure is a hard error rather than "leave it alone").

The "immediately" variants (`immediately-evaluatable-functor?`, etc.) are stronger — the functor is evaluatable *without* needing inference. Used when the canonicalizer hasn't yet set up MT relevance.

### Implicit meta-literal sentences

`implicit-meta-literals-out(formula)` (missing-larkc) — strip implicit meta-literals into explicit form. The "implicit" form might be `(impl P Q)` where `P` is itself a meta-literal — the canonicalizer prefers explicit handling.

`el-implicit-meta-literal-sentence-p(formula)` (missing-larkc) — predicate.

The canonicalizer separates this pass because meta-literals interact with clausification in subtle ways (a meta-literal mentioning a sentence shouldn't have that sentence clausified the same way as the outer sentence's other literals).

### Memoisation

`(toplevel (note-memoized-function 'precanonicalizations-int))` — the precanonicalization-int function is memoised; the cache lives in the canonicalizer's memoization state.

## Postcanonicalization

Much smaller (78 lines). Handles one specific case: pragmatic-requirement canonicalisation in disjunctions.

### Pragmatic requirements

A *pragmatic requirement* is a constraint expressed as a sentence that some queries want to evaluate during inference (rather than at canonicalization time). Example: `(pragmaticRequirement <sentence> ...)` — the inner sentence is the pragmatic check; the constraint is evaluated as a meta-query during inference.

The main canonicalizer can't fully handle pragmatic requirements because they're conditional on inference state. Postcanonicalization is the cleanup that finalises them.

### `postcanonicalizations`

```lisp
(defun postcanonicalizations (sentence mt)
  (postcanonicalizations-int sentence mt))

(defun postcanonicalizations-int (sentence mt)
  (if (not (tree-find-if #'el-meets-pragmatic-requirement-p (sentence-args sentence)))
      (values sentence mt)
      (cond
        ((el-conjunction-p sentence)
         ;; for each conjunct, postcanonicalize-possible-disjunction
         (let ((conjuncts nil))
           (cdolist (conjunct (formula-args sentence :ignore))
             (push (missing-larkc 8556) conjuncts))
           (setf sentence (make-conjunction (nreverse conjuncts)))))
        ((el-disjunction-p sentence)
         ;; postcanonicalize-possible-disjunction on the entire disjunction
         (setf sentence (missing-larkc 8557))))
      (values sentence mt)))
```

The fast-path: if no pragmatic requirements anywhere, return as-is. Otherwise, walk conjuncts/disjunction structure and call `postcanonicalize-possible-disjunction` per branch (mostly missing-larkc).

`el-meets-pragmatic-requirement-p` is the predicate; matches `(pragmaticRequirement ...)` literals.

`transform-dnf-and-binding-list-to-negated-el(dnf-and-binding-list)` (missing-larkc) — utility for turning DNF into negated EL form (used in postcanonicalising negated pragmatic requirements).

### Why post and not part of czer-main?

Pragmatic requirements need to be evaluated *as inference happens*, not at assertion time. Their canonical form is therefore "preserved as a meta-literal" rather than "clausified into the regular CNF stream." Postcanonicalization is what wraps them in the right meta-form *after* the main canonicalizer has finished its DNF/CNF work.

## The simplifier

`simplifier.lisp` is the largest of the three (690 lines). It provides syntactic and semantic simplification operations used throughout canonicalisation.

### Top-level entry points

```
simplify-cycl-sentence(sentence, &optional var?)
  → main entry; runs special-cases, then int, then transitive-redundancies if enabled

simplify-cycl-sentence-deep(sentence, &optional var?)
  → simplify-sequence-variables-1 + simplify-cycl-sentence

simplify-cycl-sentence-syntax(sentence, &optional var?)
  → like simplify-cycl-sentence but with *simplify-using-semantics?* = nil
```

`simplify-cycl-sentence-int` is the workhorse. Special cases:
- `#$True`, `#$False`, subl-escape, fast-cycl-quoted-term — return as-is
- atom (other than the above) — error: not well formed
- assertion — return as-is
- variable — return as-is

For composite sentences, dispatch on operator and run the per-operator simplifier (missing-larkc; bodies stripped).

### Disjunction lifting

`lift-disjuncts(disjuncts)` (missing-larkc) and `nlift-disjuncts(disjuncts)` flatten nested disjunctions: `(or A (or B C) D)` becomes `(or A B C D)`.

`disjoin(sentence-list, &optional simplify?)` and `ndisjoin(sentence-list, &optional simplify?)` — combine sentences into a disjunction, optionally lifting nested.

The non-destructive variant copies the input first; the destructive (n-prefix) one mutates. Always preserve order: lifting must not reorder.

### Conjunction lifting

`lift-conjuncts(conjuncts)`, `nlift-conjuncts(conjuncts)`, `liftable-conjuncts?(conjuncts)` — same as disjunction, mostly missing-larkc.

`conjoin(sentence-list, &optional simplify?)`, `nconjoin(sentence-list, &optional simplify?)` (missing-larkc) — disjunction-style conjunction builders.

### Sequence-variable simplification

`*simplifying-sequence-variables?*` — bound t while inside `simplify-sequence-variables-1`, prevents infinite recursion.

`simplify-sequence-variables-1(sentence)` (definition not visible in this file, but referenced) — when a sequence-variable's KB arity is known, expand the sequence into individual variables.

`*sequence-variable-split-limit* = 5` (in czer-vars) caps how many split-variables can be created.

### Transitive-redundancy simplification

`*simplifying-redundancies?*` — bound t while inside `simplify-transitive-redundancies` to prevent recursion.

`*transitive-constraint-preds* = (#$isa #$genls)` — the predicates considered transitive for redundancy purposes.

`simplify-transitive-redundancies(sentence)` (missing-larkc 10691) — walk the conjuncts, and if the same variable has both `(isa ?X SubCol)` and `(isa ?X SuperCol)` and `(genls SubCol SuperCol)` is known, drop the redundant `(isa ?X SuperCol)`.

Gated by `*simplify-transitive-redundancies?*` (defparameter, default nil) — opt-in because the redundancy check is expensive.

### Other simplifications (mostly missing-larkc)

- `simplify-unary-junct(junct)` — `(or X)` becomes `X`; `(and X)` becomes `X`
- `simplify-duplicate-juncts(sentence)` — eliminate duplicate disjuncts/conjuncts
- `simplify-el-syntax(sentence, &optional var?)` — top-level syntactic simplification
- `try-to-simplify-non-wff-into-wff(non-wff, &optional wff-function, arg2-to-wff-function)` — attempt to massage a non-WFF into a WFF; used by the canonicalizer when WFF check fails
- `simplify-special-cases(sentence)` — handle special-case shapes (e.g. degenerate quantifiers, empty conjunctions)

### Simplification flags (in czer-vars.lisp, controlling the simplifier)

| Flag | Default | Effect |
|---|---|---|
| `*simplify-sentence?*` | t | master switch |
| `*simplify-literal?*` | t | per-literal simplification |
| `*simplify-implication?*` | t | implication-specific |
| `*simplify-non-wff-literal?*` | t | reduce non-WFF literals to `#$False` |
| `*try-to-simplify-non-wff-into-wff?*` | t | retry WFF after simplification |
| `*simplify-using-semantics?*` | t | semantic simplification (not just syntactic) |
| `*simplify-redundancies?*` | nil | redundancy elimination |
| `*simplify-transitive-redundancies?*` | nil | transitive redundancy elimination |
| `*simplify-sequence-vars-using-kb-arity?*` | t | use KB arity for sequence-var splitting |
| `*simplify-equal-symbols-literal?*` | nil | (warning: scoping issues) |
| `*simplify-true-sentence-away?*` | nil | (warning: inference problems) |

The defaults are tuned: simple syntactic simplification is always on; expensive semantic simplifications are opt-in; experimental simplifications (`equal-symbols`, `true-sentence-away`) are off by default with explicit warnings about correctness.

## When does each piece fire?

| Operation | Fires when |
|---|---|
| `precanonicalizations?` | Before `clausify-eliminating-ists` in the main canonicalizer pipeline |
| `precanonicalizations` | When the predicate returns true |
| `transform-evaluation-expression` | When `el-evaluatable-expression?` matches |
| `simplify-cycl-sentence` | After clausification, in the canonicalizer's quiescence loop |
| `simplify-sequence-variables-1` | At the start of each canonicalization pass |
| `lift-disjuncts` / `lift-conjuncts` | When normalising disjunctions/conjunctions |
| `try-to-simplify-non-wff-into-wff` | When `canon-wff-p` returns false |
| `postcanonicalizations` | After main canonicalizer completes, on the result |
| `postcanonicalize-possible-disjunction` | When `el-meets-pragmatic-requirement-p` matches anywhere |

## Cross-system consumers

- **czer-main.lisp** — the main canonicalizer calls into precanonicalization at the start and the simplifier throughout
- **WFF check** (`wff.lisp`) — calls `try-to-simplify-non-wff-into-wff` when a formula fails WFF
- **Inference engine** — receives postcanonicalized output (the canonical HL form)
- **EL relations** — the `(evaluateAtEL <fn>)` predicate is what enables precanonicalization to evaluate constants
- **Sequence variable handling** — `*simplifying-sequence-variables?*` and the split-limit interact with the sequence variable infrastructure (in `el-utilities.lisp` and `wff.lisp`)

## Notes for the rewrite

### Precanonicalization

- **The destructive path is the production path.** Copying defeats the optimisation. Make sure the rewrite preserves this; the safe variant is for callers that need to keep the original.
- **Three classes of expansion** — EL-relations, evaluatable functors, implicit-meta-literals. Don't conflate; each has its own predicate and its own transformation.
- **`(evaluateAtEL ...)` is the KB hook for compile-time evaluation.** Keep this; it's how authors mark functions as constant-foldable.
- **The fast-path for atomic GAFs** (`formula-is-an-asent-with-no-subformulas?`) skips a tree walk. Keep it; the no-subformulas case is common.
- **`precanonicalizations-int` is missing-larkc.** The clean rewrite must implement: walk the tree, apply the per-class transformations, return new tree + new mt. Keep destructive.

### Postcanonicalization

- **Pragmatic requirements are special.** They're evaluated at inference time, not assertion time. Postcanonicalization wraps them so the inference engine knows to defer.
- **The fast-path "no pragmatic requirements anywhere → return as-is"** is what makes postcanonicalization cheap on most inputs. Keep it.
- **`postcanonicalize-possible-disjunction` is missing-larkc.** The shape: walk the disjunction, for each disjunct that contains a pragmatic-requirement literal, transform to the meta-literal form. Document the meta-literal form clearly; it's the contract with the inference engine.

### Simplifier

- **The simplifier is *shared infrastructure*** — used by precanonicalization, main canonicalisation, postcanonicalization, and externally for ad-hoc cleanup. Keep it as a library, not a layer.
- **Disjunction/conjunction lifting must preserve order.** Many KB authors rely on the order of disjuncts/conjuncts for readability. Don't reorder.
- **The "n" prefix means destructive.** Both variants (destructive and non-destructive) are needed; the destructive is for performance, the non-destructive for callers that need their input intact.
- **`*simplify-sentence?*` / `*simplify-literal?*` / `*simplify-implication?*`** are fine-grained. Don't collapse to one flag; tests and debugging need to disable specific simplifications independently.
- **`*simplify-using-semantics?*` is the syntactic-vs-semantic switch.** Keep this — semantic simplification needs MT relevance and is more expensive; syntactic-only is the fast path.
- **`*simplify-equal-symbols-literal?*` and `*simplify-true-sentence-away?*` ship off by default with warnings.** Don't turn them on without proper testing; the warnings document the known issues.
- **Most function bodies are missing-larkc.** `simplify-cycl-sentence-int`, `simplify-special-cases`, `simplify-unary-junct`, `simplify-duplicate-juncts`, `lift-disjuncts`, `lift-conjuncts`, `simplify-transitive-redundancies`, `try-to-simplify-non-wff-into-wff`, `simplify-el-syntax` — all need reconstruction. The shape is well-bounded; the rewrite has good guidance from the function names and surrounding evidence.
- **Ordering of simplification passes matters.** `simplify-cycl-sentence` runs `simplify-special-cases` first, then `int`, then `simplify-transitive-redundancies` if enabled. Keep this order; the special cases include termination conditions that the int pass would loop on.
- **`*transitive-constraint-preds* = (#$isa #$genls)`** is the empirical list. KB authors might add others; the clean rewrite should consider making this configurable or KB-driven via a meta-predicate.
