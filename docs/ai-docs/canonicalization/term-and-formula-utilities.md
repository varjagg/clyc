# Term and formula utilities

The five files in this cluster are *low-level term and formula manipulation primitives* — the working vocabulary every other layer uses. They form the substrate the canonicalizer, WFF checker, AT system, and inference engine all build on.

The five files split by concern:

1. **`term.lisp`** (218 lines) — predicates for *kinds of term*: el-fort-p, kb-assertion?, kb-predicate?, kb-relation?, reified-skolem-term?, ground-naut?, etc. Lightweight type tests, not full WFF.
2. **`el-utilities.lisp`** (1611 lines) — heavy-duty *formula manipulation* utilities: building IST sentences, walking sub-formulas, finding free sequence variables, accessor patterns, sentence-arg navigation. The largest file in the cluster.
3. **`cycl-utilities.lisp`** (818 lines) — generic *expression-walking* utilities: substitute free vars, opaque-arg handling, expression transformations. Used everywhere; doesn't depend on the EL/HL distinction.
4. **`el-grammar.lisp`** (49 lines) — minimal: the EL-specific grammar predicates (`el-non-formula-sentence-p`, `el-literal-p`).
5. **`cycl-grammar.lisp`** (538 lines) — the full CycL grammar predicates: `cycl-sentence-p`, `cycl-atomic-sentence-p`, `cycl-binary-sentence-p`, etc. Recursive grammar that handles all sentence shapes.

Source files:
- `larkc-cycl/term.lisp`
- `larkc-cycl/el-utilities.lisp`
- `larkc-cycl/cycl-utilities.lisp`
- `larkc-cycl/el-grammar.lisp`
- `larkc-cycl/cycl-grammar.lisp`

## term.lisp — type predicates

`term.lisp` is the *taxonomy* of term kinds. Each predicate answers "is this object of kind K?" with no recursion or KB lookup beyond the immediate test.

### Forts and forts-like

- `el-fort-p(object)` — is fort, nil, or el-formula?
- `kb-assertion?(object)` — is an assertion?
- `kb-predicate?(symbol)` — is a fort that is a predicate?
- `kb-relation?(object)` — is a fort that is a relation, or a NAUT?
- `mt-designating-relation?(term)` — fort and microtheory-designating-relation?

### Skolem term predicates

- `reified-skolem-term?(term)` — is `(SKF-N args...)` shape?
- `reified-skolem-fn-in-any-mt?(fn, &optional robust?, assume?)` — is `fn` a skolem function?
- `has-skolem-name?(fort)` — does the fort's name start with "SKF"?
- `fast-reified-skolem?(fort)` — fast version
- `fast-skolem-nart?(term)` — is a NART whose functor is a skolem?
- `fast-skolem-nat?(term)` — NART or NAUT whose functor has skolem name
- `unreified-skolem-term?(term)` and `unreified-skolem-fn-term?(term)` — predicates for the unreified `(SKF args)` shape

```lisp
(defun has-skolem-name? (fort)
  (cond
    ((constant-p fort) (let ((name (constant-name fort)))
                         (when (stringp name)
                           (starts-with name "SKF"))))
    ((nart-p fort) (has-skolem-name? (nat-functor fort)))))
```

The "SKF" prefix is the canonical skolem-name marker.

### Naut predicates (ground / closed / open)

- `ground-naut?(naut, &optional var?)` — is a NAUT with no variables?
- `hl-ground-naut?(object)` — at the HL level (no HL variables)?
- `closed-naut?(object, &optional var?)` — is a NAUT and is closed?

The `var?` parameter lets callers customise what counts as a variable (default `cyc-var?`).

### Skolem function functions

`*skolem-function-functions*` (from `czer-vars.lisp`) lists `(#$SkolemFunctionFn #$SkolemFuncNFn)` — the two functor symbols that denote functions whose ranges are skolems.

`skolem-fn-function?(symbol)` — is symbol one of these?

## el-utilities.lisp — formula manipulation

The largest of the cluster. Two main themes:

1. **Formula construction** — `make-ist-sentence`, `make-binary-formula`, etc.
2. **Formula traversal** — find free sequence variables, walk sub-formulas, navigate args

### Construction

```lisp
(defun el-formula-with-operator-p (formula operator)
  (and (el-formula-p formula)
       (equal operator (formula-arg0 formula))))

(defun make-ist-sentence (mt sentence)
  (make-binary-formula #$ist mt sentence))

(defun unmake-ternary-formula (formula)
  (values (formula-arg0 formula)
          (formula-arg1 formula)
          (formula-arg2 formula)
          (formula-arg3 formula)))
```

Many builders for specific sentence shapes (mostly missing-larkc); the pattern is `(make-X-formula args...)` constructs, returning a new formula.

### Sub-formula walking

`possibly-formula-with-sequence-variables?(formula)` — fast-fail check: does the formula syntactically *look like* it might contain a sequence variable? Implemented as `(tree-find-if #'dotted-list-p formula)`. Used to skip the expensive variable-finder on formulas that obviously don't have any.

`sentence-free-sequence-variables(sentence, &optional bound-vars var?)` — recursive walker that returns sequence variables not bound in any enclosing quantifier. Handles every sentence shape:
- negation: recurse on arg1
- conjunction/disjunction: recurse on each conjunct, accumulate
- implication/exception: recurse on antecedent then consequent
- quantified: recurse with quantified-var added to bound-vars
- mt-designating-literal: special MT-context handling
- atomic sentence: collect literal's free seq-vars
- relation expression: collect relation's free seq-vars

The recursion handles every sentence type uniformly. `bound-vars` accumulates as the walker descends into quantifier scopes.

`literal-free-sequence-variables(literal, ...)` — special case for literals.

`relation-free-sequence-variables(relation, ...)` — for relation expressions.

### Sentence-args navigation

`sentence-args(sentence, &optional seqvar-handling)` — return the args list (handling sequence vars per the keyword: `:include`, `:ignore`, etc.).

`formula-arg0`, `formula-arg1`, `formula-arg2`, `formula-arg3`, `formula-arg4`, `formula-arg5`, `formula-arg(formula, n)` — argN accessors.

### EL-specific predicates

- `el-conjunction-p`, `el-disjunction-p`, `el-negation-p`, `el-implication-p`, `el-exception-p` — sentence-shape predicates
- `possibly-el-quantified-sentence-p`, `quantified-sub-sentence`, `quantified-var` — quantifier handling
- `el-existential-p`, `cycl-generalized-tensed-literal-p` — etc.

These are all syntactic predicates: do they match the shape, regardless of MT or KB content? Used everywhere as the dispatch keys when walking formulas.

## cycl-utilities.lisp — expression manipulation

Generic expression-walking utilities. The two key features:

### Opaque arg handling

```lisp
(defparameter *opaque-arg-function* 'default-opaque-arg?)
(defparameter *opaque-seqvar-function* 'default-opaque-seqvar?)
```

An *opaque arg* is one that should *not* be recursed into during expression walking. Examples:
- The 2nd arg of `(SkolemFunctionFn ?Args ...)` — the args are an enumeration, not subformulas
- A SubL-escaped subexpression — the contents are SubL code, not CycL

`opaque-arg?(formula, argnum)` checks via the dispatch function; the default is `default-opaque-arg?`:
```lisp
(defun default-opaque-arg? (formula argnum)
  (when (formula-arity< formula argnum)
    (missing-larkc 29826))
  (subl-escape-p formula))
```

`opaque-arg-wrt-free-vars?(formula, argnum)` is a per-purpose variant: the 2nd arg of SkolemFunctionFn is opaque wrt free-vars (we don't want to substitute into it) but might not be opaque for other purposes.

### Expression substitution

`expression-nsubst-free-vars(new, old, expression, &optional test)` — replace free occurrences of `old` with `new` in `expression`. Recurses into sub-expressions but respects opacity:
- If expression matches old, return new
- If not an EL formula, return as-is
- If escape-quote or quasi-quote: bind `*inside-quote*` = nil, recurse
- If quote: bind `*inside-quote*` = t, recurse
- If `ExpandSubLFn` with old in args: substitute in args
- Otherwise: walk args, substitute non-opaque ones

The `*inside-quote*` dynamic special tracks "are we inside a quoted form?" Variables inside a quote should not be substituted (they're being quoted, not used).

`*canonicalize-variables?*` (in czer-vars) controls whether `#$EscapeQuote`s are removed during substitution. When variables are being canonicalised, EscapeQuotes should already contain HL variables; the substitution removes the EscapeQuotes to complete canonicalisation.

### Expression-walking primitives

- `expression-find-if(pred, expression)` — find the first sub-expression matching pred
- `expression-find(item, expression, &optional test)` — find a specific item
- `expression-gather(expression, pred)` — collect all sub-expressions matching pred
- `tree-find-if`, `tree-find`, `tree-gather` — tree-level (cons-cell) variants

`expression-` walks honour CycL semantics (formulas, quotes, escapes); `tree-` walks are pure cons-cell tree traversal.

### Term walking primitives

- `nat-arg2(nat, &optional seqvar-handling)` — accessor for NAT arg2
- `nat-functor(nat)` — get the functor
- `formula-operator(formula)` — get arg0
- `nat-functor`, `naut-functor` — NART/NAUT-specific

## el-grammar.lisp — EL-specific predicates

A tiny file (49 lines) — just two predicates:

```lisp
(defun el-non-formula-sentence-p (sentence)
  "[Cyc] Returns T iff SENTENCE is an EL sentence, but not an EL formula.
currently (11/9/99) the only such animals are #$True, #$False, and EL variables."
  (and (not (el-formula-p sentence))
       (missing-larkc 6562)))

(defun el-literal-p (object)
  (let ((*grammar-permits-hl?* nil))
    (cycl-literal-p object)))
```

`el-non-formula-sentence-p` recognises the three "atomic sentences" that aren't formulas: `#$True`, `#$False`, and EL variables. Mostly used in WFF checking.

`el-literal-p` is `cycl-literal-p` with HL constructs disabled — equivalent to "is this an EL-only literal?"

## cycl-grammar.lisp — full CycL grammar

The recursive grammar predicates for CycL sentences. The dispatch function is `cycl-sentence-p`:

```lisp
(defun cycl-sentence-p (object)
  (let ((wff? (or (cycl-formulaic-sentence-p object)
                  (cycl-truth-value-p object))))
    ;; Note WFF violation if not WFF
    wff?))

(defun cycl-formulaic-sentence-p (object)
  (if (el-formula-p object)
      (or (cycl-unary-sentence-p object)
          (cycl-binary-sentence-p object)
          (cycl-quantified-sentence-p object)
          (cycl-variable-arity-sentence-p object)
          (cycl-atomic-sentence-p object)
          (cycl-ternary-sentence-p object)
          (cycl-quaternary-sentence-p object)
          (cycl-quintary-sentence-p object)
          (cycl-user-defined-logical-operator-sentence-p object))
      ;; not an EL formula — could be HL or variable
      (or (and (grammar-permits-hl?) (missing-larkc 31386))
          (cycl-variable-p object))))
```

A sentence can be:
- A truth value (`#$True`, `#$False`)
- A variable
- An HL assertion (if `*grammar-permits-hl?*`)
- A formula of one of nine arities/shapes:
  - unary, binary, ternary, quaternary, quintary
  - quantified (`forAll`, `thereExists`, etc.)
  - variable-arity (`and`, `or`, etc.)
  - atomic (a predicate applied to args)
  - user-defined logical operator

Each of these predicates (`cycl-unary-sentence-p`, etc.) has its own definition that checks the operator type and recurses on the args.

### Grammar configuration

- `*grammar-permits-hl?* = t` — allow HL constructs
- `*grammar-uses-kb?* = t` — consult KB for type checks (vs. syntactic-only)
- `*grammar-permits-list-as-terminal?* = nil` — bare lists as terminals
- `*grammar-permits-symbol-as-terminal?* = nil`
- `*grammar-permits-non-ascii-strings?* = nil`
- `*grammar-permissive-wrt-variables?* = t` — variables can denote anything
- `*grammar-permits-quoted-forms* = t`

`*within-quote-form*` — true while inside a `(Quote ...)` form; many predicates are more permissive inside a quote (the contents aren't being interpreted).

### `grammar-uses-kb?()` predicate

```
(and *grammar-uses-kb?*
     (kb-loaded))
```

The grammar can run *purely syntactically* (without KB) or *with KB consultation*. Pure syntax is faster but less precise — `*grammar-uses-kb?*` controls. Always disabled when KB is not loaded.

## When does each piece fire?

| Layer | Calls into |
|---|---|
| WFF checking | `cycl-sentence-p`, `cycl-formulaic-sentence-p`, all the per-shape predicates |
| Canonicalizer | `el-utilities.lisp` for sub-formula walking, sentence-args navigation, sequence-var detection |
| AT system | `term.lisp` predicates (kb-relation?, kb-predicate?, etc.) |
| Pattern matching | `cycl-utilities.lisp` for expression walking and substitution |
| Inference | `term.lisp` for type tests on arg values |
| Display / KE | All of them |

## Cross-system consumers

Essentially every other module consumes these utilities. They are the *substrate*.

Hot consumers:
- `wff.lisp`, `arg-type.lisp`, all canonicalization files — every line of these files calls into the term/formula utilities
- `inference-czer.lisp`, `inference-trampolines.lisp` — the inference layer's own term-level wrappers consult these primitives
- KE, NL generation, API marshaling — top-level paths consume the grammar predicates

## Notes for the rewrite

### term.lisp

- **Type predicates are the type system.** Don't restructure; the names are documented at the file level and used widely.
- **Skolem-name "SKF" prefix** is a hardcoded convention. Keep this; many places assume it.
- **`reified-skolem-fn-in-any-mt?` has three flavours** of robustness (strict, robust, assume) — keep all three; different callers want different tradeoffs.
- **`hl-ground-naut?`** is the HL-side check. Don't conflate with `ground-naut?`; they use different `var?` predicates.

### el-utilities.lisp

- **The largest file.** Each function is small but there are many. Don't fold them; the names are the documentation.
- **`possibly-formula-with-sequence-variables?`** is a fast-fail. The full sequence-variable walker is expensive; this fast check skips it for obvious-no cases. Keep this pattern; it's a 50-100x speedup on common cases.
- **Sentence-args walking handles every shape.** Don't simplify by collapsing cases; each shape has its own recursion pattern.
- **MT-designating-literal handling** in `sentence-free-sequence-variables` is the only place that re-establishes MT relevance during walking. Keep this; the contextualization is essential.

### cycl-utilities.lisp

- **`*opaque-arg-function*` and `*opaque-seqvar-function*` are extension points.** Custom callers can rebind to provide domain-specific opacity. Keep this.
- **`expression-nsubst-free-vars`** is the canonical free-var-substitution routine. Used by everything that needs to instantiate a rule. Get it right; bugs here cause silent inference errors.
- **`*inside-quote*`** is the dynamic special that makes substitution quote-aware. Without it, variables inside `(Quote ...)` forms would be substituted, breaking quoting semantics. Keep this; subtle but essential.
- **`expression-` vs. `tree-` walks.** Different semantics: `expression-*` knows about CycL formulas (quotes, escapes); `tree-*` is pure cons-cell. Don't merge.

### el-grammar.lisp

- **Tiny file.** Just two predicates. Keep them where they are.
- **`el-non-formula-sentence-p` body is missing-larkc.** Reconstruct: matches `#$True`, `#$False`, and el-variables.

### cycl-grammar.lisp

- **The recursive grammar is one of the canonical specs of the CycL language.** The function names are the BNF: `cycl-sentence-p`, `cycl-atomic-sentence-p`, `cycl-binary-sentence-p`, etc. Keep the structure; it's the language reference.
- **`*grammar-permits-hl?*`** is t in production. Keep this default; turning off means HL constructs are rejected.
- **`*grammar-uses-kb?*`** is t in production. Pure-syntactic checking is for very-early-load contexts (when the KB isn't loaded yet).
- **The 9 shape predicates** (unary, binary, ternary, quaternary, quintary, atomic, quantified, variable-arity, user-defined-logical-operator) cover every CycL sentence shape. Don't omit any; each maps to a real syntactic class.
- **Variable-arity sentences** (`and`, `or`) are handled differently from fixed-arity sentences. The grammar must treat them as their own class.
- **`cycl-truth-value-p`** is `(or (eq object #$True) (eq object #$False))`. Keep this primitive; it's the recursion base case.
- **Most sub-grammar predicates have small missing-larkc paths** (e.g. `cycl-unary-sentence-p`, `cycl-binary-sentence-p` mostly have bodies but recurse via missing-larkc helpers). The clean rewrite must reconstruct each from the specification.
- **The recursion is mutually recursive.** A unary sentence's arg must itself be a sentence. The grammar predicates form a fixed-point that the engine relies on. Keep this; don't try to flatten.
