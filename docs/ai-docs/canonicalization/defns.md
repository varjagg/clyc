# Defns — function and predicate definitions for arg-type checking

A **defn** (definition) is the engine's way of representing **collection membership tests** and **predicate evaluation rules** as code instead of data. The KB asserts that some collections (`#$Number`, `#$String`, `#$CycLAssertion`) and predicates (`#$different`, `#$cycSystemRealNumberP`) have *defns* — KB-attached evaluation functions that decide membership or compute truth at run time.

There are three kinds of defn:
1. **Iff-defn** — a *necessary and sufficient* condition for collection membership. Used as the canonical decision: if the iff-defn returns true, the term is *definitely* an instance.
2. **Suf-defn** (sufficient defn) — a *sufficient* condition. If true, the term is an instance; if false, you can't conclude anything.
3. **Nec-defn** (necessary defn) — a *necessary* condition. If false, the term is *definitely not* an instance; if true, you can't conclude anything.

Together these allow the AT system (see "Arg-type" doc) to decide collection membership without doing inference.

The system also includes **evaluation defns** for predicates like `#$different` — the predicate's truth-value is computed by calling a defn function, not by KB lookup.

Source files:
- `larkc-cycl/defns.lisp` (598) — the defn registry, dispatching, and admit/reject logic
- `larkc-cycl/collection-defns.lisp` (492) — the actual defn functions for collections (`stringp`, `integerp`, `el-formula-p`, etc.)
- `larkc-cycl/evaluation-defns.lisp` (305) — the actual defn functions for predicates (`cyc-different`, `cyc-string-tokenize`, etc.)

## The three defn kinds

### Iff-defn

`(iff-defn col quoted?)` returns the iff-defn function for collection `col`. There can be only *one* iff-defn per collection — by definition, an iff-defn fully characterises membership.

```
*iff-defns* :: hash table col -> function
*quoted-iff-defns* :: hash table col -> function (for quoted-isa)
```

Examples:
- `#$CharacterString`'s iff-defn is `stringp`
- `#$Integer`'s iff-defn is `integerp`
- `#$SubLString`'s iff-defn is `subl-string-p`
- `#$HLFormula`'s iff-defn is `(lambda (object) (or (nart-p object) (assertion-p object)))`
- `#$CycLSubLSymbol`'s iff-defn is `cycl-subl-symbol-p`

### Suf-defn

`(suf-defns col quoted?)` returns the *list* of suf-defn functions for collection `col`. Each function is a sufficient condition; if any returns true, the term is an instance.

```
*suf-defns* :: hash table col -> list of functions
*quoted-suf-defns* :: hash table col -> list of functions
*has-suf-defn-cache* :: hash table col -> count (cache for has-suf-defn-somewhere?)
*has-quoted-suf-defn-cache* :: same for quoted
```

Used when no iff-defn exists but the engine has *multiple ways* to prove membership — e.g. an `Animal` has suf-defns covering `Cat`, `Dog`, `Bird`, etc.

### Nec-defn

`(nec-defns col quoted?)` returns the list of nec-defn functions. If *any* returns false, the term is *not* an instance.

```
*nec-defns* :: hash table col -> list of functions
*quoted-nec-defns* :: hash table col -> list of functions
```

Example: `#$Individual` has a nec-defn `cyc-individual-necessary` that rejects collections — an Individual must not be a Collection.

## The minimum-defn admits map

For *primitive* collections (the ones that bottom out the membership hierarchy), the engine has a hardcoded mapping:

```lisp
*min-defn-admits-map*
  ((stringp                #$CharacterString)
   (positive-integer-p     #$PositiveInteger)
   (non-negative-integer-p #$NonNegativeInteger)
   (integerp               #$Integer)
   (floatp                 #$RealNumber)
   ((constantly t)         #$Thing))
```

`*min-quoted-defn-admits-map*`:
```lisp
((stringp        #$SubLString)
 (integerp       #$SubLInteger)
 (floatp         #$SubLRealNumber)
 (symbolp        #$SubLSymbol)
 (constant-p     #$CycLConstant)
 (nart-p         #$CycLNonAtomicReifiedTerm)
 (assertion-p    #$CycLAssertion)
 ((constantly t) #$CycLExpression))
```

These are the *primitives* — every term has *some* membership decision via these maps, even if no specific defn exists. The catch-all `(constantly t #$Thing)` ensures every term is an instance of `#$Thing`.

## Public API

```
defns-admit?(col, term, &optional mt) → boolean
  ; do COL's defns admit TERM?

defns-reject?(col, term, &optional mt) → boolean
  ; do COL's defns reject TERM?
```

Both can be true (consistent), both false (unknown), or one true (decisive).

`*use-new-defns-functions?*` switches between two implementations; defaults t (new). The "old" path delegates via `missing-larkc 5340` / `5341`.

`new-defns-admit?(col, term, &optional mt)` is the new entry. It calls `defns-admit?-int(col, term, mt, nil)` (the `nil` means non-quoted).

`new-defns-reject?(col, term, &optional mt)` is the parallel.

`new-quoted-defns-admit?(col, term, &optional mt)` and `new-quoted-defns-reject?(col, term, &optional mt)` are the quoted-version variants.

The `define-defn-metered` macro wraps these in metering: count calls, time spent, success/failure rates. Used for performance profiling.

## The admit/reject pipeline

`defns-admit?-int(col, term, mt, quoted?)`:

```
1. If col is reifiable-nat?, replace with reified form
2. If permitting-denotational-terms-admitted-by-defn-via-isa?:
   ; this is the "trust isa" shortcut
   if (isa? term col mt): return t
   ; (or quoted-isa? for quoted)
3. If col is not a fort and has no suf-defn-somewhere?: return nil
4. Bind the four history tables:
   *defn-fn-history*, *quoted-defn-fn-history*,
   *defn-col-history*, *quoted-defn-col-history*
5. initial-check-defn-admit-status(col, term, mt, quoted?):
   case :admitted -> t
   case :rejected -> nil
   otherwise:
     defns-walk-admit?(col, term, mt, quoted?)
     ; if not, and term is a quote, try denoted-term:
     if (fast-quote-term-p term):
       let denoted = cycl-denotation-term(term)
       quoted-defns-admit?(col, denoted, mt) ?
6. clear-defn-space  (cleanup)
```

The four history tables prevent infinite recursion: when a defn calls into another collection's defn, the history records "we're already checking col X with term Y" so it can short-circuit cycles.

`initial-check-defn-admit-status` is the fast path — checks the history tables and primitive defns before walking the suf-defns list.

`defns-walk-admit?` is the workhorse: walks the suf-defn functions, returning true on the first hit.

`nec-defn-rejects?` is the reject-side equivalent: walks nec-defns, returning true on the first failure.

`clear-defn-space` cleans up the per-call caches after the call completes.

## Collection defns (collection-defns.lisp)

This file defines the actual *defn functions* for primitive collections. Each function answers "is OBJECT an instance of THIS-COLLECTION?"

### SubL-function defns

`*subl-functions-used-as-collection-defns*` lists pure SubL predicates registered as collection defns:
```
'(stringp integerp keywordp listp symbolp true false)
```

These map to:
- `stringp` → `#$CharacterString` / `#$SubLString`
- `integerp` → `#$Integer` / `#$SubLInteger`
- `keywordp` → `#$KeywordSymbol` etc.
- `listp` → `#$ConsCell` etc.
- `symbolp` → `#$SubLSymbol`
- `true` → `#$True`
- `false` → `#$False`

### CycL-function defns

`*cycl-functions-used-as-collection-defns*` lists Cyc-specific predicates registered as collection defns:
```
'(cycl-constant-p cycl-variable-p el-variable-p hl-variable-p
  cycl-denotational-term-p el-relation-expression? gaf?
  string-w/o-control-chars? url-p)
```

Examples:
- `cycl-constant-p` → `#$CycLConstant`
- `el-variable-p` → `#$CycLELVariable`
- `gaf?` → `#$CycLGAFAssertion`
- `url-p` → `#$URL`

### Specific defn examples

```lisp
(defun cyc-individual-necessary (object)
  "[Cyc] #$defnNecessary for #$Individual"
  (if (and (fort-p object) (collection? object))
      nil  ; collections aren't individuals
      t))

(defun cyc-system-string-p (object)
  "[Cyc] defnIff for #$SubLString"
  (subl-string-p object))

(defun cycl-subl-symbol-p (object)
  "[Cyc] defnIff for CycLSubLSymbol"
  (when (el-formula-p object)
    (and (subl-quote-p object)
         (symbolp (formula-arg1 object)))))

(defun hl-formula-p (object)
  "[Cyc] defnIff for HLFormula"
  (or (nart-p object) (assertion-p object)))
```

The pattern: a function named for the collection it tests. The docstring marks the kind: `defnIff`, `defnNecessary`, `defnSufficient`. The KB has corresponding `(defnIff Col defn-fn)` GAFs that register each function.

Most function bodies in collection-defns.lisp are missing-larkc — many CycL types like `cycl-formula?`, `cycl-sentence?`, `cycl-non-atomic-term?` are commented out. The clean rewrite must reconstruct from the KB's defnIff/defnSuf/defnNec assertions and the documented type predicates.

## Evaluation defns (evaluation-defns.lisp)

Same idea but for *predicates* — KB-attached functions that compute the predicate's truth value.

`*cycl-functions-used-as-evaluation-defns* = '(asserted-when)` — the canonical example. `(asserted-when ?A ?T)` is true when ?A was asserted at time ?T; the defn computes this from the assertion's metadata.

### `cyc-different`

```lisp
(defun cyc-different (args)
  "[Cyc] #$evaluationDefn for #$different"
  (let ((result (different? args :unknown)))
    (if (eq result :unknown)
        (missing-larkc 30339)  ; deeper inference for :unknown
        result)))
```

This is the production defn for `#$different`. Given a list of args, return `t` if all are known to be different, `nil` if any are equal, or recurse via deeper inference for :unknown.

The 3-valued return shape (true / false / unknown) is normal for evaluation defns — the defn can know decisively *or* defer to deeper inference.

### Cyc-* eval functions (mostly missing-larkc)

The bulk of `evaluation-defns.lisp` is a long list of stripped function declarations:
- `cyc-different-symbols`, `cyc-substring-predicate`, `cyc-prefix-substring`, `cyc-suffix-substring`, `cyc-subword-predicate`, `cyc-find-constant`
- `cyc-string-upcase`, `cyc-string-downcase`, `cyc-substring`, `cyc-string-concat`, `cyc-strings-to-phrase`, `cyc-pre-remove`, `cyc-replace-substring`, `cyc-remove-substring`, `cyc-post-remove`, `cyc-trim-whitespace`, `cyc-string-search`, `cyc-length`, `cyc-string-to-integer`, `cyc-integer-to-string`, `cyc-string-to-real-number`, `cyc-real-number-to-string`, `cyc-string-tokenize`, `cyc-http-url-encode`
- `cyc-html-image`, `cyc-html-table-data`, `cyc-html-table-row`, `cyc-html-table`, `cyc-html-division`, `cyc-contextual-url`, `cyc-remove-html-tags`, `cyc-capitalize-smart`, `cyc-recapitalize-smart`
- `cyc-relation-arg`, `cyc-relation-args-list`

These are the runtime evaluators for predicates whose semantics are computed (string manipulation, HTML construction, integer/float conversion, etc.). The clean rewrite must reimplement each — they are KB-asserted functionality.

## Caching

Each defn lookup goes through a per-call history table. The four history tables (`*defn-fn-history*`, `*quoted-defn-fn-history*`, `*defn-col-history*`, `*quoted-defn-col-history*`) prevent infinite recursion: when a defn calls another, the history records the (collection, term) tuple already in flight; recursive calls short-circuit.

The history tables are allocated lazily via `possibly-make-defn-fn-history-table` (and analogues). For most defn calls, they're not allocated at all (the call doesn't recurse).

`clear-defn-space` cleans up after a call. Without this, defn calls would leak the per-call state.

`*has-suf-defn-cache*` and `*has-quoted-suf-defn-cache*` are persistent per-image caches: "does this collection have *any* suf-defn?" Used by the fast-path check in `defns-admit?-int` step 3.

## When does defn checking fire?

| Trigger | Path |
|---|---|
| AT arg-type check | `formula-args-ok-wrt-type-int?` calls `defns-admit?` for each arg's collection |
| WFF check | Indirectly via AT |
| Inference (specifically removal modules) | `removal-modules-evaluation.lisp` calls into evaluation defns to decide if `(different ?X ?Y)` etc. is satisfied |
| KE auto-completion | Per-arg constraint check |
| Pattern matching | `pattern-matches-formula-isa-method` calls `defns-admit?` |

## Cross-system consumers

- **AT** (`arg-type.lisp`) consumes `defns-admit?` and `defns-reject?` for every arg-isa check
- **Removal modules** (`removal-modules-evaluation.lisp`) consume evaluation defns for predicates like `different`, `string-upcase`
- **Forward inference** consumes them when a new GAF needs validation
- **Pattern matching** (`formula-pattern-match.lisp`) uses `defns-admit?` for `:isa` patterns
- **KE / API** validates constants via defns

## Notes for the rewrite

- **Defns are the bridge between KB-driven and code-driven semantics.** Some collections are defined by KB assertions; others by Lisp predicates; defns let both coexist. Keep the registration mechanism.
- **The three-kind structure (iff / suf / nec) is essential.** Each kind has different semantics; collapsing to one would lose information. Iff is "decisive both ways"; suf is "sufficient if true"; nec is "necessary if false."
- **The `*min-defn-admits-map*` and `*min-quoted-defn-admits-map*`** are the primitive grounding. Every term gets to `#$Thing` via these. Keep them; they're the type-system root.
- **Most function bodies in `collection-defns.lisp` are missing-larkc.** The shape is well-bounded: each function answers "is OBJECT an instance of THIS-COLLECTION?" The clean rewrite must reconstruct from the KB's `(defnIff col fn)` / `(defnSuf col fn)` / `(defnNec col fn)` assertions.
- **Most function bodies in `evaluation-defns.lisp` are missing-larkc.** These are the *implementation* of evaluable predicates and functions. Each is a runtime evaluator; without them, predicates like `cyc-string-tokenize` can't fire. The clean rewrite must reimplement in Lisp/CL using native facilities (string manipulation, regex, etc.).
- **`*use-new-defns-functions?*`** is t in production. The "old" path is dead code; the rewrite can drop it.
- **`define-defn-metered`** is the metering wrapper. Used for profiling. Keep the macro but make metering opt-in via a flag.
- **The four history tables** are essential to prevent recursion. Don't simplify; recursion can happen when a defn for col1 references col2 which references col1.
- **`clear-defn-space`** must run after every top-level defn call. Skipping it leaks state. Wrap with unwind-protect (the existing code does).
- **`reifiable-nat?` rewrite** at the start of admit-int handles the case where col is a NAUT that has a NART form. Without this, the lookup would miss the cached defns. Keep this.
- **`permitting-denotational-terms-admitted-by-defn-via-isa?`** is the "trust isa" shortcut. When true, an existing isa GAF short-circuits the defn check. Useful for performance but can produce different results than full defn checking. Production default needs to be documented.
- **`*max-supported-formula-arity* = 1000`** in evaluation-defns.lisp. Formulas longer than this are rejected as "more trouble than they're worth." Keep this guard.
- **`*bug-18769-switch?*`** and `*word-strings-fn*` etc. are debug/configuration knobs. The rewrite can audit which are still needed.
- **`*term-to-isg-table*`** is a global table mapping terms to integer-sequence-generators for stable ID assignment. Keep it; needed for deterministic ID generation across defn calls.
