# Arguments and supports — the polymorphic justification layer

`arguments.lisp` is the **type-erasure seam** between assertions, deductions, kb-hl-supports, and the TMS. It defines two parallel polymorphisms:

- **Argument**: what *justifies* an assertion. Every assertion's `arguments` slot is a list of these.
- **Support**: what *supports* a deduction. Every deduction's `supports` slot is a list of these.

The two are different concepts (an argument *is for* an assertion, a support *is used by* a deduction) but both are polymorphic unions over the same KB-resident object kinds. Both are used as the value type of cross-system pointers — without them, every consumer would have to dispatch on three or four KB-object types every time it walks a justification chain.

## Argument vs. Support — what's the difference

The vocabulary trips up newcomers because both words point at "things that justify other things". The distinction:

| Concept | What it is | Members | Where it lives |
|---|---|---|---|
| **Argument** | The justification of an *assertion*. | `belief` (= asserted-argument-token) ∪ `deduction` | `(assertion-arguments assertion)` |
| **Support** | A premise *used by* a deduction. | `assertion` ∪ `kb-hl-support` ∪ `hl-support` | `(deduction-supports deduction)` |

So:

- An assertion has a list of arguments. Each argument is *either* "a cyclist asserted this with TV X" (a belief) *or* "this rule firing produced this conclusion" (a deduction).
- A deduction (one of those arguments) has a list of supports. Each support is *either* an assertion ("this other fact in the KB"), a kb-hl-support ("this reified HL inference"), or an hl-support ("this transient HL inference").

The two layers are stacked: an argument-of-assertion is a deduction; the deduction's supports are themselves assertions/kb-hl-supports/hl-supports — which can in turn have their own arguments. The argument graph is what the TMS walks for cascade removal.

## When does an argument get created?

Two situations:

1. **A cyclist asserts a sentence directly.** `kb-create-asserted-argument assertion truth strength` ([hl-modifiers.lisp:45](../../../larkc-cycl/hl-modifiers.lisp#L45)) is the entry point. It builds a TV from `(truth, strength)`, calls `create-asserted-argument` (which converts the TV to one of five flyweight keyword tokens), and `add-new-assertion-argument`s it onto the assertion. KE/FI assert paths funnel here via `tms-create-asserted-argument-with-tv`. The result is a `belief` argument.

2. **Inference produces a conclusion that needs justification.** A deduction is created (see [deductions.md](deductions.md)) and registered as one of the conclusion-assertion's arguments via `add-new-assertion-argument`. The deduction *is* the argument.

Both kinds of argument live in the same `(assertion-arguments assertion)` list, distinguished by `(belief-p arg)` vs `(deduction-p arg)`. Code that walks the list dispatches on these.

## When does a support get created?

A support is whatever an inference step uses as a premise. The triggering situations are described in the docs of the support kinds:

- **Assertion-supports**: when an inference reads an existing assertion, that assertion *is* a support. No separate creation step. Just a reference to the existing handle.
- **HL-supports**: when an inference module fires (see [kb-hl-supports.md](kb-hl-supports.md#when-does-an-hl-support-get-created)). Cheap, value-typed.
- **KB-HL-supports**: when an HL-support needs persistent identity (see [kb-hl-supports.md](kb-hl-supports.md#when-does-a-kb-hl-support-get-created)).

The only argument-side operation that creates supports is `canonicalize-supports`, which traverses a list and ensures every entry is in canonical form (assertion or kb-hl-support; an hl-support that needs reification gets a kb-hl-support minted on the spot via `find-or-possibly-create-kb-hl-support`).

## The argument-type hierarchy

A small four-element lattice:

```
                ARGUMENT
               /        \
           BELIEF      DEDUCTION
            /
  ASSERTED-ARGUMENT
```

Encoded in `*argument-type-hierarchy*`:

```lisp
(deflexical *argument-type-hierarchy*
  '((:argument ())
    (:belief (:argument))
    (:asserted-argument (:belief))
    (:deduction (:argument))))
```

`argument-type-genls` and `argument-type-proper-genls` walk this lattice to ask "is X a kind of Y?".

In current code `:asserted-argument` and `:belief` are effectively synonyms — `belief-p` is `(asserted-argument-p object)`, `belief-truth` is `(asserted-argument-truth belief)`. The hierarchy reserves the distinction in case future code wants to treat "an asserted argument" as a stricter subtype of "a belief", but the implementation doesn't currently exploit it.

## Asserted-argument tokens — the flyweight design

An asserted-argument doesn't have its own struct. It's one of **five keyword tokens**:

```lisp
(deflexical *asserted-argument-tv-table*
  '((:asserted-true-mon  :true-mon)
    (:asserted-true-def  :true-def)
    (:asserted-unknown   :unknown)
    (:asserted-false-def :false-def)
    (:asserted-false-mon :false-mon)))

(deflexical *asserted-arguments* (mapcar #'first *asserted-argument-tv-table*))
```

Each token is paired with the HL TV it represents. The constructor `asserted-argument-token-from-tv tv` does `(car (find tv ... :key #'second))`; the reader `tv-from-asserted-argument-token` is the inverse.

`asserted-argument-p obj` is `(member? object *asserted-arguments* #'eq)` — pure keyword identity, no struct. This is the flyweight: any two "asserted, true, monotonic" arguments are *the same `:asserted-true-mon` keyword*. There's no per-assertion belief object; the `(assertion-arguments ...)` list just carries the keyword directly.

The implication: a belief carries no information beyond its TV. The "who/when/why/how" of an asserted assertion lives on the *assertion's plist* (`:assert-info` 4-tuple — see [assertions.md](assertions.md#assert-info-4-tuple)), not on the belief itself. The belief is a marker that says "yes, this assertion has a direct cyclist-asserted argument with this TV".

`create-asserted-argument assertion tv` therefore *ignores* the assertion argument and just calls `asserted-argument-token-from-tv tv`. There's a TODO acknowledging this: "doesn't this need the assertion?" — and the answer is no, because the keyword carries everything.

## Argument operations

The polymorphic API (`belief-p` vs `deduction-p` dispatch):

```
(argument-p obj)              ; belief-p OR deduction-p
(valid-argument arg &opt robust)  ; belief-p OR (deduction-p AND valid-deduction)
(argument-truth arg)          ; belief-truth OR deduction-truth
(argument-tv arg)             ; belief-tv OR (tv-from-truth-strength deduction-truth deduction-strength)
(argument-strength arg)       ; missing-larkc 31879 for belief; deduction-strength for deduction
(remove-argument arg assertion)  ; remove-belief OR kb-remove-deduction
(argument-equal a b)          ; missing-larkc — declared but not implemented
```

Iteration helpers (over all assertions in the KB, all their arguments):

```
(do-arguments (assertion argument &optional message) body...)
(do-beliefs (assertion argument &optional message) body...)        ; filtered to belief-p
(do-asserted-arguments (assertion argument &optional message) body...) ; same as do-beliefs
```

These macros all expand to `(do-assertions (assertion ...) (cdolist (argument (assertion-arguments assertion)) ...))` with a per-element filter.

## Argument-spec — transient creation specs

A *spec* is a tagged list used to defer argument creation through a queueing pipeline (the same `hl-add-argument` pattern documented in assertions.md and deductions.md). Two variants:

- **Asserted-argument-spec**: `(:asserted-argument <strength-spec>)` constructed by `create-asserted-argument-spec strength-spec`. Carried by FI/KE assert paths through `hl-storage-modules.lisp` until the assertion is ready and the actual asserted-argument-token can be installed.
- **Deduction-spec**: `(:deduction . <canonicalized-supports>)` constructed by `create-deduction-spec` (see [deductions.md](deductions.md#forward-propagation)).

`argument-spec-type` reads the tag. Dispatch in `hl-add-argument` cases on the tag and routes to either `hl-assert-as-kb-assertion` (for asserted) or `hl-deduce-as-kb-deduction` (for deduction).

## Support — the three-variant union

`support-p obj` is the polymorphism: `(or (assertion-p obj) (kb-hl-support-p obj) (hl-support-p obj))`. The three kinds:

- **Assertion** — a stored fact. Identity via the assertion handle's id.
- **KB-HL-support** — a reified HL inference, KB-resident. See [kb-hl-supports.md](kb-hl-supports.md).
- **HL-support** — a transient HL inference (a 4-list `(module sentence mt tv)`). Reified into a kb-hl-support iff used in a persisted deduction.

The polymorphic API every support kind implements:

```
(support-p obj)
(valid-support? sup &opt robust)
(support-module sup)        ; :assertion / kb-hl-support module / hl-support's first elt
(support-sentence sup)      ; assertion-formula / kb-hl-support-sentence / hl-support-sentence
(support-formula sup)       ; alias for support-sentence (obsolete)
(support-mt sup)            ; assertion-mt / kb-hl-support's MT / hl-support-mt
(support-justification sup) ; (list sup) / kb-hl-support's justification (missing-larkc) / hl-support-justify
(support-tv sup)            ; cyc-assertion-tv / kb-hl-support-tv / hl-support-tv
(support-truth sup)         ; missing-larkc; would be (tv-truth (support-tv sup))
(support-strength sup)      ; (tv-strength (support-tv sup))
(support-equal a b)         ; eq for assertion/kb-hl-support; equal for hl-support
(support-< a b)             ; total order: GAFs < rules < kb-hl-supports < hl-supports < other
```

Each is a `cond` over the three variants. The pattern is mechanical and shows up everywhere — a sealed sum type with a small protocol would replace it cleanly.

`support-<` is the arbitrary-but-consistent total order used to canonicalize supports lists so that two equivalent justifications canonicalize to the same sorted list. The order:

1. Assertions come first. Within assertions, GAFs before rules (via `rule-assertion?`); ties broken by assertion ID.
2. KB-HL-supports next. Ties broken by kb-hl-support ID.
3. Anything else (hl-supports, raw terms) last, ordered by `term-<`.

## hl-support 4-tuple

```lisp
(defstruct (hl-support (:type list) (:constructor nil))
  module
  sentence
  mt
  tv)

(defun make-hl-support (hl-module sentence &optional (mt *mt*) (tv :true-def))
  (list hl-module sentence mt tv))
```

A `(:type list)` defstruct gives free positional accessors (`hl-support-module`, `hl-support-sentence`, etc.) without the overhead of a real struct header. The `:constructor nil` suppresses the default keyword constructor in favor of the explicit positional `make-hl-support`.

`hl-support-p` is structural: a 4-element proper list whose car is a registered hl-support module keyword. No tag, no struct header — just a list shape.

`assertion-from-hl-support hl-support` is a clever coercion: if the hl-support's module is `:assertion`, look up the matching assertion and return that instead. This means a `(:assertion <sentence> <mt> <tv>)` 4-tuple is interchangeable with the actual assertion handle when the assertion exists — used by `canonicalize-support` to fold an hl-support back into its corresponding assertion.

## hl-justification — the multiset of supports

A **justification** is a list of supports. Conceptually a multiset (order doesn't matter; duplicates do, in the rare case where the same support appears twice in a derivation).

```
(non-empty-hl-justification-p obj)        ; proper-list-p AND every-in-list support-p
(hl-justification-p obj)                  ; missing-larkc
(empty-hl-justification-p obj)            ; missing-larkc
(justification-equal j1 j2)               ; multiset equality via support-equal
(canonicalize-hl-justification j)         ; sort by support-<
(canonicalize-supports supports &opt create?)  ; canonicalize each + sort
```

`canonicalize-supports` is the entry point used by `kb-create-deduction` and forward propagation. It walks the supports list and for each entry that's an hl-support, calls `canonicalize-hl-support`, which routes:
- If there's a matching `assertion`, return it directly (folding back to assertion-support).
- Else if `possibly-create-new-kb-hl-supports?` is true, find or mint a kb-hl-support.
- Else just return the hl-support unchanged.

Then sorts by `support-<` so the resulting list is canonical.

## TMS interactions

The argument/support layer is where the TMS sits — every truth-maintenance operation walks one of these polymorphic structures. Key TMS entry points that consume this layer:

- `tms-add-new-deduction assertion supports tv` → `create-deduction-with-tv` → adds a deduction-argument to the assertion's argument list.
- `tms-create-asserted-argument-with-tv assertion tv` → `kb-create-asserted-argument-with-tv` → adds a belief-argument.
- `tms-remove-argument argument assertion` → dispatches: if `belief-p`, `remove-belief`; else `kb-remove-deduction`.
- `tms-recompute-assertion-tv assertion` → walks `(assertion-arguments assertion)`, computes the joint TV from each `(argument-tv arg)`, decides whether to rewrite or remove.
- `tms-remove-dependents assertion` → walks `(assertion-dependents assertion)` (deductions whose supports include this assertion), removes each.

The `do-arguments` / `do-beliefs` / `do-asserted-arguments` macros are mostly used in TMS verification and audit code — "for every assertion in the KB, for every argument it has, …".

## Public API surface

### Predicates

```
(argument-p obj)                       ; Cyc API
(valid-argument arg &opt robust)
(belief-p obj) (asserted-argument-p obj)  ; Cyc API
(asserted-argument-token-p obj)
(deduction-p obj)                      ; — see deductions.md

(support-p obj)                        ; Cyc API
(valid-support? sup &opt robust)
(hl-support-p obj)                     ; Cyc API
(non-empty-hl-justification-p obj)
```

### Argument readers

```
(argument-truth arg)                   ; Cyc API
(argument-tv arg)
(argument-strength arg)                ; Cyc API
(argument-equal a b)                   ; Cyc API (missing body)
```

### Argument-type lattice

```
(argument-type-hierarchy)
(argument-type-genls type)
(argument-type-proper-genls type)
*argument-types*                       ; (:argument :belief :asserted-argument :deduction)
*argument-type-hierarchy*
```

### Argument creation

```
(create-asserted-argument assertion tv)
(create-asserted-argument-spec strength-spec)
(asserted-argument-spec-strength-spec spec)
(kb-create-asserted-argument assertion truth strength)
(kb-create-asserted-argument-with-tv assertion tv)
(remove-argument arg assertion)
(remove-belief belief assertion)
(kb-remove-asserted-argument assertion belief)
(kb-lookup-asserted-argument assertion truth strength)  ; Cyc API (missing body)
```

### Asserted-argument tokens

```
(asserted-argument-tokens)             ; the 5-element list
(asserted-argument-token-p obj)
(asserted-argument-token-from-tv tv)
(tv-from-asserted-argument-token token)
(asserted-argument-tv token)
(asserted-argument-truth token)
*asserted-arguments*                   ; the 5 token keywords
*asserted-argument-tv-table*           ; token ↔ TV mapping
```

### Argument-spec

```
(argument-spec-type spec)              ; car
(argument-spec-p obj)                  ; missing body
(argument-to-argument-spec arg)        ; missing body
(argument-type-p obj)                  ; missing body
```

### Support readers (polymorphic)

```
(support-module sup)                   ; Cyc API
(support-sentence sup)                 ; Cyc API
(support-formula sup)                  ; obsolete alias
(support-mt sup)                       ; Cyc API
(support-tv sup)
(support-truth sup)                    ; Cyc API (missing body)
(support-strength sup)                 ; Cyc API
(support-justification sup)
(support-equal s1 s2)
(support-<  s1 s2)
*assertion-support-module*             ; the :assertion keyword
```

### Support construction & canonicalization

```
(make-hl-support hl-module sentence &opt mt tv)   ; Cyc API
(canonicalize-support sup &opt create?)
(canonicalize-supports supports &opt create?)
(canonicalize-hl-support hl-sup &opt create?)
(canonicalize-hl-justification j)
(assertion-from-hl-support hl-sup)
(justification-equal j1 j2)
```

### hl-support struct accessors

```
(hl-support-module hl-sup)
(hl-support-sentence hl-sup)
(hl-support-mt hl-sup)
(hl-support-tv hl-sup)
```

### Iteration macros

```
(do-arguments (assertion argument &opt message) body...)
(do-beliefs (assertion argument &opt message) body...)
(do-asserted-arguments (assertion argument &opt message) body...)
```

## Consumers

| Consumer | What it uses |
|---|---|
| **Assertions** ([assertions.md](assertions.md)) | `(assertion-arguments a)` returns a list of arguments. `add-new-assertion-argument` / `remove-assertion-argument` are the mutation entry points. `asserted-assertion?` walks the list with `find-if #'asserted-argument-p`. |
| **Deductions** ([deductions.md](deductions.md)) | `(deduction-supports d)` returns supports (canonicalized). `support-equal` and `support-<` for canonicalization. `support-p` for valid-deduction. |
| **kb-hl-supports** ([kb-hl-supports.md](kb-hl-supports.md)) | Implements the `support-*` polymorphic protocol. `hl-support-justify` is the per-module justification. `non-empty-hl-justification-p` gates `possibly-create-kb-hl-support`. |
| **TMS** (`tms.lisp`) | `tms-add-new-deduction`, `tms-remove-argument`, `tms-create-asserted-argument-with-tv`, `tms-recompute-assertion-tv`, `tms-remove-dependents`. The argument-list walker. |
| **HL-modifiers** (`hl-modifiers.lisp`) | `kb-create-asserted-argument` is the HL-modifier wrapper that mints an asserted-argument. `kb-remove-asserted-argument` is the symmetric removal that also clears `:assert-info` plist entries. |
| **HL-storage-modules** (`hl-storage-modules.lisp`) | `hl-add-argument` dispatches on `argument-spec-type`; the `:asserted-argument` and `:deduction` cases route to the matching creation paths. `*dummy-asserted-argument-spec*` is the placeholder used when the strength is `:unspecified`. |
| **KE / FI** (`ke.lisp`, `fi.lisp`) | `ke-assert-now` and `fi-assert` build asserted-argument-specs and pass them through `hl-add-argument`. |
| **Forward propagation** (`inference/harness/forward.lisp`) | Builds deduction-specs via `create-deduction-spec`. |
| **Argumentation** (`inference/harness/argumentation.lisp`) | `compute-deduction-tv` would recompute a deduction's TV from its supports' TVs (currently missing-larkc). |
| **HL supports module impls** (`hl-supports.lisp`) | `hl-justify` dispatches to `support-justification`; the per-module `:justify` functions return new lists of supports built via `make-hl-support`. |

## Files

| File | Role |
|---|---|
| `arguments.lisp` | Everything in this doc — the argument/support polymorphism, the asserted-argument-token taxonomy, the hl-support 4-tuple, the canonicalization helpers, the type hierarchy. ~510 lines, lots of `cond`-dispatch over the three support variants. |

The closely-related files `hl-modifiers.lisp` (asserted-argument creation hl-modifier) and `tms.lisp` (the truth-maintenance machinery that consumes this layer) live in the KB-access section — see the README index.

## Notes for a clean rewrite

- **Rename "argument" the justifier-role to "justification" — but keep the existing `justification` value-type renamed too.** "Argument" is fatally overloaded: it means both "predicate parameter" (`gaf-arg N`, `formula-arg1`, `assertion-arguments` in the SubL plist sense, atomic-sentence-args) *and* "thing that justifies an assertion" (`(assertion-arguments a)` in the bookkeeping sense, `argument-p`, `argument-truth`). The two senses live in adjacent code; readers have to disambiguate every time. After rename, "argument" should only ever mean "predicate parameter".

  The renamed "argument" (a belief or deduction) and the current `hl-justification` (a list of supports) are **not** the same concept in this codebase — they differ in cardinality (single vs. list) and member type (belief|deduction vs. assertion|kb-hl-support|hl-support), and they occupy different layers of the proof tree (an assertion has arguments; an argument-which-is-a-deduction has a justification = its supports list). They're related but distinct.

  The cleanest rename:
  - `argument` (the justifier-role) → **`justification`** (singular). `(assertion-arguments a)` becomes `(assertion-justifications a)`. `argument-p`, `argument-truth`, `argument-tv`, `argument-strength`, `valid-argument`, `do-arguments` get prefixes accordingly.
  - `hl-justification` (the list-of-supports value-type) → **`premises`** (or `supports-list`). `hl-justification-p` becomes `premises-p`, `non-empty-hl-justification-p` becomes `non-empty-premises-p`, `canonicalize-hl-justification` becomes `canonicalize-premises`. A deduction's `supports` slot is "the deduction's premises", which is what it actually represents.
  - The argument-type lattice (`*argument-type-hierarchy*`) becomes the justification-type lattice; the four type keywords (`:argument`, `:belief`, `:asserted-argument`, `:deduction`) become `:justification`, `:belief`, `:asserted-argument`, `:deduction`.

  After this rename:
  - "argument" = predicate parameter (always).
  - "justification" = a single entity that justifies an assertion (a belief or deduction).
  - "premises" = a list of supports a deduction relies on.
  - "support" = a single entity used by a deduction (assertion, kb-hl-support, hl-support).

  Each word means one thing.

- **Sealed sum types for `justification` and `support`.** The `(if (belief-p arg) ... (deduction-p arg) ...)` and three-way `(cond (assertion-p ...) (kb-hl-support-p ...) (hl-support-p ...))` patterns are everywhere. Two sealed sum types — `justification = belief | deduction` and `support = assertion | kb-hl-support | hl-support` — would make every dispatcher syntactic instead of runtime, and the compiler could verify exhaustiveness.
- **`belief` and `asserted-argument` are aliases.** `belief-p` is `(asserted-argument-p object)`; `belief-truth` is `(asserted-argument-truth belief)`; `belief-tv` is `(asserted-argument-tv belief)`. The argument-type hierarchy lists them as separate types but they're the same predicate. Either pick one name and remove the other, or implement the actual subtype distinction the hierarchy promises.
- **The flyweight asserted-argument-token design is fine but exposes its representation.** "An asserted argument is one of these five keywords" leaks into every consumer that has to know the keyword names. A clean rewrite hides this: `(asserted-argument truth strength)` is a struct with two slots (or two enum fields), and the keyword-pool optimization is internal to the constructor.
- **`create-asserted-argument` ignores its `assertion` parameter.** The TODO in the code asks "doesn't this need the assertion?" — the answer is no, because the keyword token carries no per-assertion info. Drop the unused parameter.
- **`*assertion-support-module*` = `:assertion`** — a deflexical wrapping a single keyword. Just inline the keyword. The indirection serves no purpose.
- **`hl-support` as a `(:type list)` defstruct** is a SubL-port artifact (the SubL compiler emitted hl-supports as 4-element lists). A clean rewrite uses a real struct with a proper type tag, eliminating the structural `hl-support-p` check (currently `(and (listp obj) (proper-list-p obj) (length= obj 4) (hl-support-module-p (car obj)))` — every check walks the list).
- **`support-truth` is missing-larkc** but trivially implementable as `(tv-truth (support-tv sup))`. Wire it up — it's a public API entry that currently always errors.
- **`argument-strength` for beliefs is missing-larkc 31879.** The TV is right there in the token; the strength is the second component. Trivially implementable as `(tv-strength (asserted-argument-tv belief))`. Wire it up.
- **`argument-equal` is registered as Cyc API but has no body.** Implementation: `(or (eq a b) (and (belief-p a) (belief-p b) (eq a b)) (and (deduction-p a) (deduction-p b) (eq a b)))` — beliefs are flyweights, deductions are interned, so `eq` is correct everywhere. Wire it up.
- **`support-equal` mixes `eq` and `equal` based on type.** A single `(eq a b)` would work for assertions and kb-hl-supports (both interned) but fail for hl-supports (raw lists). The mixed dispatch is correct; the comment is needed because it surprises every reviewer.
- **`support-<` is hand-coded with three nested conds.** A sealed sum's variants can have an explicit ordinal field; comparing variants becomes an integer compare followed by within-variant ordering. Cleaner and faster.
- **`hl-justification-p`, `empty-hl-justification-p`, `argument-equal`, `argument-spec-p`, `belief-spec-p`** are all "active declareFunction with no body" — Cyc API registrations without implementation. Wire them up; consumers exist for each.
- **`*argument-type-hierarchy*` is a 4-element lattice with hand-rolled traversal.** For four elements, hardcoding the parent relationships is fine, but the `argument-type-proper-genls` function is general-purpose graph traversal applied to a tiny static structure. A flat lookup table would be simpler.
