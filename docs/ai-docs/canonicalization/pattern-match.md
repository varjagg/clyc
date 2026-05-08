# Pattern matching

`pattern-match.lisp` is the **generic tree pattern-matching engine** — a small declarative language for testing whether a tree-shaped object matches a pattern, and for transforming a tree according to a pattern.

This is the *abstract* substrate. Domain-specific pattern matchers (formula pattern-match in `formula-pattern-match.lisp`, see "Cardinality estimates and pattern match" doc in the inference category) extend the methods table with formula-specific operators.

The pattern language has two parts:
1. **Match patterns** — return t/nil and accumulate variable bindings
2. **Transform patterns** — produce a new tree from the input + bindings

Source file: `larkc-cycl/pattern-match.lisp` (233 lines)

## Match patterns

### Atomic patterns

| Pattern | Matches |
|---|---|
| `:anything` | every tree |
| `:nothing` | no tree |
| any other atom | only the specific atom (via `equal`) |
| any operator in `*pattern-matches-tree-atomic-methods*` | dispatched to the registered method |

### Compound patterns

| Pattern | Matches when |
|---|---|
| `(:bind <var> <pattern>)` | the inner pattern matches; binds `<var>` to the matched tree |
| `(:value <var>)` | (missing-larkc 32006) — likely tests against an already-bound variable |
| `(:and <p1> <p2> ...)` | all sub-patterns match |
| `(:or <p1> <p2> ...)` | any sub-pattern matches |
| `(:not <pattern>)` | the inner pattern doesn't match |
| `(:test <fn> <args>...)` | `(funcall fn tree args...)` returns non-nil |
| `(:tree-find <pattern>)` | `<pattern>` matches *somewhere* in the tree (recursive find) |
| `(:quote <obj>)` | tree is `equal` to `obj` (escapes pattern interpretation) |
| `(<op> ...)` where op is in `*pattern-matches-tree-methods*` | dispatched to the registered method |
| any other cons | tree is a cons, head matches recursively, tail matches recursively |

### Bindings

Match patterns may include `(:bind <var> <subpattern>)` to capture sub-trees:

```lisp
(pattern-matches-tree '(:bind ?X (:and :anything))  ; bind ?X to anything
                      '(foo bar baz))
;; → t, with bindings ((?X . (foo bar baz)))
```

`*pattern-matches-tree-bindings*` is the dynamic special accumulator. `add-pattern-matches-tree-binding(var, value)` adds an entry; uses `alist-enter-without-values` (skips if already bound).

### Public entry points

```
(pattern-matches-tree pattern tree)
  → (values t/nil bindings)
  ; sets up *pattern-matches-tree-bindings* = nil, runs the matcher,
  ; returns success + reversed bindings on success

(pattern-matches-tree-without-bindings pattern tree)
  → t/nil
  ; faster; doesn't accumulate bindings; :BIND not allowed in pattern

(pattern-matches-tree-internal pattern tree)
  → t/nil  (also affects *pattern-matches-tree-bindings*)
  ; for use by pattern-match methods in other files (extends the engine)
```

The third entry point is what extension files (like `formula-pattern-match.lisp`) call when their custom methods need to recurse.

### Error handling

`pattern-matches-tree` wraps the matcher in `handler-case`: any error during matching produces `(values nil nil)`. This is conservative — a malformed pattern doesn't crash the caller; it just doesn't match.

### The matcher core

```lisp
(defun pattern-matches-tree-recursive (pattern tree)
  (if (atom pattern)
      ;; atomic pattern: dispatch on keyword
      (case pattern
        (:anything t)
        (:nothing nil)
        (otherwise
         ;; check the registered atomic methods, fall back to equal
         (dolist (method-info *pattern-matches-tree-atomic-methods*
                  (equal pattern tree))
           (when (eq (first method-info) pattern)
             (return (funcall (second method-info) tree))))))
      ;; compound pattern: dispatch on operator
      (destructuring-bind (pattern-operator . pattern-args) pattern
        (case pattern-operator
          (:bind   (pattern-matches-tree-bind pattern tree))
          (:value  (missing-larkc 32006))
          (:and    (pattern-matches-tree-and pattern tree))
          (:or     (pattern-matches-tree-or pattern tree))
          (:not    (not (pattern-matches-tree-recursive (second pattern) tree)))
          (:test   (apply (first pattern-args) tree (rest pattern-args)))
          (:tree-find (pattern-matches-tree-tree-find (second pattern) tree))
          (:quote  (equal (second pattern) tree))
          (otherwise
           ;; check the registered compound methods, fall back to cons matching
           (dolist (method-info *pattern-matches-tree-methods*
                    (pattern-matches-tree-cons pattern tree))
             (when (eq (car method-info) pattern-operator)
               (return (funcall (second method-info) pattern tree)))))))))
```

The two extension hooks (`*pattern-matches-tree-atomic-methods*` and `*pattern-matches-tree-methods*`) let domain-specific code add new pattern operators without modifying this file.

### Cons matching

`pattern-matches-tree-cons(pattern, tree)` — the default behaviour when no compound operator matches. Walks the cons cells: head must match head, tail must match tail. Uses recursion via `pattern-matches-tree-recursive`.

```lisp
(defun pattern-matches-tree-cons (pattern tree)
  (unless (atom tree)
    (destructuring-bind (pattern-operator . pattern-args) pattern
      (destructuring-bind (tree-operator . tree-args) tree
        (when (pattern-matches-tree-recursive pattern-operator tree-operator)
          (do ((rest-pattern-args pattern-args (cdr rest-pattern-args))
               (rest-tree-args tree-args (cdr rest-tree-args)))
              ((or (atom rest-pattern-args) (atom rest-tree-args))
               (pattern-matches-tree-recursive rest-pattern-args rest-tree-args))
            (unless (pattern-matches-tree-recursive (car rest-pattern-args)
                                                    (car rest-tree-args))
              (return nil))))))))
```

Walks both lists in lockstep, matching head against head until one runs out, then matches the remaining tail.

### `:test` operator

```
(:test <fn> <args>...)
```

Calls `(apply <fn> tree <args>)`. If non-nil, the pattern matches.

Example: `(:test integerp)` matches any integer. `(:test > 0)` matches any positive number.

### `:tree-find` operator

```
(:tree-find <subpattern>)
```

Searches the entire tree (depth-first) for any sub-tree matching `<subpattern>`. Returns t if found, nil otherwise.

Implemented via `tree-find` with `pattern-matches-tree-recursive` as the equality predicate.

## Transform patterns

Transform patterns *produce* a new tree from the input plus bindings. Used by HL modules' `:cost-pattern`, `:expand-pattern`, `:input-extract-pattern`, etc.

### Atomic transforms

| Pattern | Produces |
|---|---|
| `:input` | the input tree |
| `:bindings` | the current `*pattern-transform-tree-bindings*` |
| any other atom | the atom itself (passed through) |

### Compound transforms

| Pattern | Produces |
|---|---|
| `(:value <var>)` | the value bound to `<var>` |
| `(:tuple <vars> <subpattern>)` | binds each var in `<vars>` to the corresponding tree element, then transforms `<subpattern>` with no input |
| `(:template <match-pat> <subpattern>)` | matches input against `<match-pat>`, accumulates bindings, transforms `<subpattern>` with no input |
| `(:call <fn> <args>...)` | applies `<fn>` to the recursively-transformed `<args>` |
| `(:quote <obj>)` | `<obj>` literally |
| any other cons | recursively transforms each element |

### Public entry points

```
(pattern-transform-tree pattern tree &optional bindings)
  → (values transformed-tree updated-bindings)

(pattern-transform-tree-internal pattern tree)
  → transformed-tree
  ; for use by transform methods in other files
```

`*pattern-transform-tree-bindings*` is the accumulator (initially the optional `bindings` argument).

`*pattern-transform-match-method*` — extension hook: when set, replaces the default `pattern-matches-tree` call inside `:template` operations. Used by `formula-pattern-match.lisp` to substitute `pattern-matches-formula` so `:template` patterns use formula-aware matching.

### `:tuple` transform

```lisp
(:tuple (?X ?Y ?Z) <subpattern>)
```

Given a tree like `(a b c)`, binds `?X = a`, `?Y = b`, `?Z = c`, then transforms `<subpattern>`. Useful for destructuring.

### `:template` transform

```lisp
(:template <match-pat> <subpattern>)
```

Matches the input tree against `<match-pat>`, accumulates the bindings, then transforms `<subpattern>` with those bindings. Combines matching and transforming in one operation.

### `:call` transform

```lisp
(:call <fn> <arg1> <arg2> ...)
```

Each `<argi>` is recursively transformed (so it can reference `:input`, `:bindings`, `(:value ?V)`, etc.), then `<fn>` is applied to the transformed args.

Example: `(:call instance-cardinality :input)` returns the cardinality of the input.

### `:quote` transform

```lisp
(:quote <obj>)
```

Produces `<obj>` literally, not as a pattern. Use to escape the pattern interpretation when an object happens to look like a pattern operator.

### Default cons transformation

```lisp
(defun pattern-transform-cons (pattern tree)
  (let ((answer (copy-list pattern)))
    ;; Walk the list, recursively transforming each element
    (do ((rest-answer answer (cdr rest-answer)))
        ((atom (cdr rest-answer))
         ;; tail: handle dotted-tail case
         (rplaca rest-answer (pattern-transform-tree-recursive (car rest-answer) tree))
         (when (cdr rest-answer)
           (rplacd rest-answer (pattern-transform-tree-recursive (cdr rest-answer) tree))))
      (rplaca rest-answer (pattern-transform-tree-recursive (car rest-answer) tree)))
    answer))
```

The default behaviour for an unrecognised compound pattern: copy the list, transform each element. This is what makes `:input` and `(:value ?V)` work inside arbitrary cons structures — the recursion finds them and replaces them.

## Extension methods

Two parallel registries:

```
*pattern-matches-tree-atomic-methods* :: list of (operator method)
  ; method called as (funcall method tree)

*pattern-matches-tree-methods* :: list of (operator method)
  ; method called as (funcall method pattern tree)
```

The atomic-methods table is for atom-shaped operators (e.g. `(:fort)`); the methods table is for cons-shaped operators (e.g. `(:isa #$Cat)`).

Extension example (from `formula-pattern-match.lisp`):

```lisp
(deflexical *pattern-matches-formula-atomic-methods*
  '((:fort     fort-p)
    (:variable variable-p)
    (:assertion assertion-p)
    ... etc))

(deflexical *pattern-matches-formula-methods*
  '((:isa     pattern-matches-formula-isa-method)
    (:genls   pattern-matches-formula-genls-method)
    ... etc))
```

When `formula-pattern-match.lisp` enters its matcher:
```lisp
(let ((*pattern-matches-tree-atomic-methods* *pattern-matches-formula-atomic-methods*)
      (*pattern-matches-tree-methods* *pattern-matches-formula-methods*))
  (pattern-matches-tree pattern formula))
```

It rebinds the dispatch tables so the generic engine consults the formula-specific methods. Same pattern would work for any domain-specific extension.

## Performance notes

Two TODOs in the source:
1. **Precompilation** — pattern matching has a regex-style compile/run split that would speed up frequent patterns. Currently every match re-interprets the pattern.
2. **`destructuring-bind (single)` overhead** — many patterns destructure into single elements; a length-check would be cheaper.

The clean rewrite should consider:
- A `pattern-compile` step that produces a closure over the pattern, with the dispatch resolved at compile time
- Eliminating the per-call `case` dispatch by table-driven lookup
- Special-casing common patterns (`:anything`, fixed atoms) at the call site

## When does pattern matching fire?

Patterns are used everywhere:
- **HL modules** — `:required-pattern`, `:cost-pattern`, `:expand-pattern`, `:input-extract-pattern`, `:output-construct-pattern`, etc.
- **AT directives** — `(canonicalizerDirectiveForArg ...)` use patterns to specify which args
- **WFF checks** — pattern-based shape checks
- **Pre-canonicalization** — `pattern-matches-formula-without-bindings` for fast existence checks

The hot path is `pattern-matches-formula-without-bindings` (no binding accumulation, no error wrapping) — called many times per inference.

## Cross-system consumers

- **HL modules** (`inference-modules.lisp`) — every pattern property
- **AT directives** (`czer-utilities.lisp`) — `canonicalizer-directive-for-arg?` consults
- **Formula pattern match** (`formula-pattern-match.lisp`) — extends the methods table
- **WFF / canonicalizer** — uses pattern matching for shape tests

## Notes for the rewrite

- **The pattern language is small and well-designed.** Eight match operators (`:anything :nothing :bind :value :and :or :not :test :tree-find :quote`) plus extensions cover all observed use cases. Don't expand without need.
- **The transform language has parallel structure.** Five transform operators (`:input :bindings :value :tuple :template :call :quote`). Same shape, different semantics.
- **The two extension hooks** (`*pattern-matches-tree-atomic-methods*` and `*pattern-matches-tree-methods*`) are essential. Domain extensions plug in here. Keep them.
- **`*pattern-transform-match-method*`** lets transforms use a different match strategy. Used by `:template` to enable formula-aware matching during transformation. Keep the hook.
- **Bindings accumulate during matching.** Even with `pattern-matches-tree-without-bindings` the matcher still allocates bindings (just doesn't return them). The clean rewrite could optimise the no-bindings path to skip allocation entirely.
- **`handler-case` wrapping** of the top-level matcher converts errors to `(values nil nil)`. Keep this conservative behaviour; pattern errors should not crash callers.
- **`pattern-matches-tree-cons` walks both lists in lockstep.** Don't replace with a simpler loop; the dotted-tail case (when one list is dotted) needs the recursion.
- **The recursion is mutual** (`pattern-matches-tree-cons` calls `pattern-matches-tree-recursive`, which calls back into the dispatcher). Keep this; it's how the pattern language composes.
- **`(:value ?V)` body is missing-larkc.** It "presumably tests against an already bound variable" — i.e. fails if the variable's value doesn't match the tree. The clean rewrite must implement; needed for back-references in patterns.
- **The atomic-method dispatch uses `eq`** for the operator match, not `equal`. Keep this; pattern operators are keywords, eq is correct and fast.
- **Performance is the bottleneck.** Pre-compilation would help. Don't ship a clean rewrite without measuring; the compile-once-run-many pattern is the right approach.
- **`:bind` returns the value of `add-pattern-matches-tree-binding`**, not t directly. Currently the binding-add returns t; keep this consistency.
- **The empty case for `dolist (method-info ...)` returns `(equal pattern tree)`** for atomic methods or `(pattern-matches-tree-cons pattern tree)` for compound. This is the *fallback*: if no extension matches, fall back to the default behaviour. Keep both fallbacks.
- **Transform-cons copies the list with `copy-list`** — top-level only, not deep. Sub-trees are shared. The recursion replaces sub-elements as needed. Keep this; it's correct and efficient.
