# Variables

CycL has several distinct things called "variables" and they coexist deliberately. Each represents a different stage in a query's life — the source-form a user wrote, the canonical form the inference engine binds, and the term-shaped form a variable takes when it is *itself* an argument to a function. A clean rewrite needs all three, plus the small set of edge-case forms.

## The kinds of variable

| Kind | Concrete representation | Typical lifetime | Source file |
|---|---|---|---|
| **HL variable** | `(variable :id N)` struct, `0 ≤ N < *variable-max*` | interned pool, lives forever once `setup-variable-table` runs | `variables.lisp` |
| **EL variable** | a CL `symbol` in the Cyc package whose name begins with `?` | as long as the symbol is interned | `cycl-variables.lisp` |
| **TL variable** | NAUT of shape `(#$TLVariableFn integer-index optional-name-string)` | as long as the TL formula carrying it is alive | `canon-tl.lisp:tl-var?` |
| **Keyword variable** | a CL `keyword`, gated on `*permit-keyword-variables?*` | symbol's interned lifetime | `cycl-variables.lisp:keyword-var?` |
| **Generic-arg variable** | gated on `*permit-generic-arg-variables?*`; predicate body is `missing-larkc` | — | `cycl-variables.lisp:generic-arg-var?` |
| **"Don't-care" variable** | EL variable whose name begins with `??` | EL only; the canonicalizer rewrites each occurrence to a *fresh* HL variable so they don't unify with each other | `cycl-variables.lisp:has-dont-care-var-prefix?` |

All five (six counting don't-care) are admitted by the umbrella predicate **`cyc-var?`**, which is the right thing to call when "is this a variable" is the question. `variable-predicate-fn` returns the *specific* admitting predicate so a caller can keep looking like-for-like.

## HL variables (`variables.lisp`)

The HL variable is the form the inference engine binds against. It carries no name and no payload — only a small integer id.

### Data structure

```
(defstruct variable id)
```

A pool of `*variable-max*` (= 200) variables is allocated up front by `setup-variable-table` and stored in `*variable-array*`. `get-variable N` is just `(aref *variable-array* N)`. The pool is never grown; `*variable-max*` is the hard cap on the number of distinct HL variables that can appear in any one canonicalized form.

The 200 cap is a SubL artifact — every canonical formula in Cyc gets its variables renumbered 0…k–1 from a shared pool, which means inference can compare formulas by `eq` on the variable struct rather than walking names. Two distinct formulas reusing `(variable :id 0)` is *expected* — the variable identity is meaningful only inside one formula's context.

### Lifecycle

- **Birth.** `setup-variable-table` is called from `kb-utilities.lisp:setup-kb` during KB initialization. It mints all 200 variables and never runs again (the function is no-op on subsequent calls because `*variable-array*` is already set).
- **Use.** Wherever a canonical formula needs a variable position, the canonicalizer walks the EL form and replaces each EL variable with a fixed HL variable from the pool, identical occurrences mapping to the same id.
- **Death.** Never. The pool is permanent for the life of the image.

### Printing and naming

```
*hl-variable-prefix-char* = #\?
*variable-names*          = nil   (defparameter, in control-vars.lisp)
```

`print-object` for a variable looks the id up in `*variable-names*` (a list, indexed by id). If a name is found, it prints that. If not, it prints `?varN` where N is the id. A clean rewrite that wants pretty variable names sets `*variable-names*` once at startup; otherwise variables come out as `?var0`, `?var1`, …

`default-el-var-for-hl-var` is memoized (`defun-cached`) and produces an EL variable from the HL one by `prin1-to-string` followed by `make-el-var`. So an HL variable round-trips into EL space as `?VAR0`, `?VAR1`, … (or whatever name was set in `*variable-names*`).

### CFASL serialization

| Opcode | Constant | Reads/writes |
|---|---|---|
| 40 | `*cfasl-opcode-variable*` | the integer id of the variable; load resolves via `find-variable-by-id` |
| 42 | `*cfasl-opcode-complete-variable*` | the "complete" variant (used in externalization mode where the receiver might not have the same pool); body is `missing-larkc` in the port |

`cfasl-output-object` for `variable` is `cfasl-output-object-variable-method`, body `missing-larkc 32187`. The whole serializer/deserializer pair on the input side is `cfasl-input-variable` — read an integer, look it up. Compact because every image agrees on the 0…199 pool.

## EL variables (`cycl-variables.lisp`)

The EL variable is what a user types. It's a Common Lisp symbol with a name starting with `?`, conventionally upper-case. Examples: `?X`, `?VAR0`, `?WHO`, `??ANY`.

### Predicates

- `el-var?` — symbol, non-NIL, non-keyword, name begins with `?` and is at least 2 chars.
- `valid-el-var?` — symbol whose name matches the regex `([?]|[?][?]) [A-Z] ([A-Z]|[0-9])* ([-] ([A-Z]|[0-9])+)*`. Stricter than `el-var?`: enforces the all-caps + hyphen-segment grammar (e.g. `?FOO-BAR-1`).
- `el-var-name?` — applies the same prefix rule to a string rather than a symbol.

### Construction

```
(make-el-var "?X")    →  intern "?X" in *cyc-package*
(intern-el-var x)     →  intern (make-el-var-name x) in *cyc-package*
(make-el-var-name x)  →  uppercased copy of x if it already looks like an EL var name
```

Anything that wants a fresh EL variable goes through `make-el-var` — used by the canonicalizer (`czer-utilities.lisp` for slot names like `?X-1`), the simplifier (when allocating a new-named replacement variable), the clausifier (skolemization), and assertion-variable-name dumping.

### Don't-care variables

`??FOO` is a don't-care variable. The grammar lets the `??` prefix through, but the canonicalizer rewrites *each occurrence* of a `??`-prefixed variable to a freshly-allocated HL variable, so two `??X` slots in the same formula are independent. This is the EL-layer mechanism for "I don't care about this slot's value but I need a placeholder there." The runtime never sees `??X` as a variable identity — it sees two separate HL variables.

### EL ↔ HL bridge

| Direction | Function | Notes |
|---|---|---|
| HL → EL | `default-el-var-for-hl-var` | memoized; `make-el-var (prin1-to-string variable)` |
| EL → HL | done by the canonicalizer | not a single function — happens during `canonicalize-expression` / `canonicalize-formula`. The bridge keeps a per-canonicalization renaming table; identical EL variable symbols collapse to one HL id |
| HL pretty name lookup | `(nth id *variable-names*)` | populated at boot if you want named printing |

## TL variables (`canon-tl.lisp:tl-var?`)

A "TL variable" is a variable that has been **packaged as a NAUT** so it can sit inside a transformation-language form that's traveling around as data:

```
(#$TLVariableFn  integer-index  name-string-or-nil)
```

`tl-var?` admits any `possibly-naut-p` whose functor is `#$TLVariableFn`, whose arg1 is an integer, and whose arg2 is a string or NIL. This is the form variables take in dumps of canonicalized assertions when the canonicalizer wants to record the variable's *position* and *original name* together. Compare:

| Form | "I am a variable" by virtue of |
|---|---|
| HL `(variable :id 3)` | being the struct |
| EL `?X` | being a symbol with a `?` name |
| TL `(#$TLVariableFn 3 "X")` | being a NAUT with the right functor |

Sister TL terms exist for assertions (`#$TLAssertionFn`) and reified function applications (`#$TLReifiedNatFn`). The TL family is the data form of HL-canonical forms — what you'd serialize if you wanted to ship a canonical formula across machines without assuming both sides agree on HL variable ids.

The TL variable predicates and constructors are mostly `missing-larkc` in the port (extracting arg1/arg2, validating arity). A clean rewrite should treat the TL form as a structured record with two fields and not as an opaque NAUT.

## Keyword and generic-arg variables

These are gated escape hatches for forms that the inference engine usually won't see:

- **Keyword variables** are CL keyword symbols (e.g. `:KEY`). `permissible-keyword-var?` admits them only when `*permit-keyword-variables?*` is bound true. Used inside arg-type checks (see `arg-type.lisp:131`) where the expression being checked may legitimately contain keyword positions.
- **Generic-arg variables** are entirely behind `*permit-generic-arg-variables?*`. The body of `generic-arg-var?` is `missing-larkc 3473`. They exist for canonicalizer modes that want to handle "any term in any position" placeholders.

Both flags are `let`-bound by callers that want the broader admission, then released. Outside those scopes, `cyc-var?` rejects keywords and generic-args.

## Public API surface

Registered as Cyc API functions (in `variables.lisp` and `cycl-variables.lisp`):

```
(variable-p object)                       ; HL variable struct test
(variable-count)                          ; → *variable-max*  (registration, no body)
(variable-id variable)                    ; → integer id
(find-variable-by-id id)                  ; → variable | NIL  (alias of get-variable)
(default-el-var-for-hl-var var)           ; → EL symbol
(fully-bound-p object)                    ; no HL variable anywhere
(not-fully-bound-p object)                ; some HL variable somewhere
(el-var? object)                          ; EL symbol test
```

Not registered but public:

```
(get-variable N)                          ; HL pool accessor
(variable-< v1 v2)                        ; total order on ids (used in sort)
(sort-hl-variable-list xs)
(cyc-var? thing)                          ; admits any kind of variable
(variable-predicate-fn var)               ; returns the specific admitting predicate
(variable-name var)                       ; user-facing name (works on HL, EL, keyword)
(make-el-var x) / (intern-el-var x) / (make-el-var-name x)
(valid-el-var? x) / (valid-el-var-name? s)
(has-el-variable-prefix? s) / (has-dont-care-var-prefix? s)
(el-variable-prefix-char) / (el-variable-prefix-char? c)
(hl-var? thing) / (kb-var? sym) / (kb-variable? sym)   ; all = variable-p
(tl-var? object)                          ; #$TLVariableFn NAUT test
(cycl-ground-expression-p expr)           ; alias of fully-bound-p with cyc-var?
```

## How other systems consume variables

| Consumer | Pattern of use |
|---|---|
| **Canonicalizer** (`czer-*.lisp`, `canon-tl.lisp`) | the EL→HL bridge; assigns each distinct EL variable an HL id, renames don't-care variables to fresh ids, packages variables as TL when serializing canonical form |
| **Bindings / unification** (`bindings.lisp`, `unification.lisp`) | binding tables are keyed by `variable-id`; `variable-<` provides a stable order |
| **Inference** (`inference/harness/inference-czer.lisp`, `inference-worker.lisp`, `hl-prototypes.lisp`) | works exclusively with HL variables; HL-prototype templates reuse the same HL pool |
| **Assertions** (`assertions-low.lisp`, `assertions-high.lisp`, `assertions-interface.lisp`) | each assertion may carry a `:variable-names` prop — the original EL names of its HL variables, used so the asserted form can be re-displayed with the user's chosen names rather than `?VAR0`/`?VAR1` |
| **CFASL** (`cfasl-kb-methods.lisp`) | opcodes 40/42 above |
| **Arg-type checks** (`arg-type.lisp`) | checks toggle `*permit-keyword-variables?*` / `*permit-generic-arg-variables?*` so they can admit broader variable forms inside arg-type formulas |
| **Simplifier / clausifier** (`simplifier.lisp`, `clausifier.lisp`) | `make-el-var` to mint fresh names like `?X-Skolem-12345` |
| **`fully-bound-p` clients** (everywhere) | gate evaluations that require ground terms; `expression-find-if #'cyc-var?` is the standard "are there any variables in here" probe |

`assertion-variable-names` deserves its own note: when an assertion is asserted, the original EL variable names are stripped to HL ids, but the names themselves are preserved on the assertion as a list keyed by HL id. `kb-set-assertion-variable-names` is the setter, dumped as the assertion property `:variable-names`. This is how the system can roundtrip back to a user-readable form without an external name table.

## Notes for a clean rewrite

- **Drop the 200-slot pool.** The id-keyed array exists so HL variables are interned and `eq`-comparable. A clean rewrite can either keep that and uncap the pool (lazy allocation, grow on demand), or replace the HL variable struct with a pure value type (`(:variable n)` or similar) and rely on structural equality. The 200 cap is a footgun — it's enough for any one formula but the SubL machinery silently reuses it across formulas, which leaks pool identity into application code.
- **Unify HL/TL representations.** TL variables exist to serialize HL variables. A single canonical wire form for a variable (id + optional name) replaces both forms.
- **Don't-care variables can be a renaming pass, not a primitive.** Lift the `??`-rewrite into the canonicalizer's first pass; downstream code never sees them.
- **`*permit-keyword-variables?*` and `*permit-generic-arg-variables?*` are caller flags.** Replace with explicit modes on the canonicalizer/checker entry points; dynamic-scope flags are hard to follow.
- **`*variable-names*` is a global list keyed by id.** A per-formula name table belongs on the formula (the way assertions already attach `:variable-names`); the global is convenient for the REPL but surprising in production code.
- **`variable-name` falls through to `missing-larkc` for keyword and other variables.** Trivially fixable — it's just `~s` on the symbol/keyword.

## Files

| File | Role |
|---|---|
| `variables.lisp` | HL variable struct, pool, printer, `fully-bound-p`, EL↔HL bridge |
| `cycl-variables.lisp` | EL variable predicates, name validation, keyword/generic-arg gates, `cyc-var?` umbrella, `variable-predicate-fn` dispatch |
| `canon-tl.lisp` | TL variable predicate (`#$TLVariableFn` NAUT) |
| `control-vars.lisp` | `*variable-names*` defparameter |
| `kb-utilities.lisp:setup-kb` | calls `setup-variable-table` at KB-init time |
| `cfasl-kb-methods.lisp` | opcodes 40/42 for variables |
| `arg-type.lisp` | only major caller that toggles the keyword/generic-arg permit flags |
