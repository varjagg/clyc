# Enumeration types

`enumeration-types.lisp` is the **central registry of small fixed enumerations** used across the KB and inference engine. Each enumeration is an ordered list of keyword constants, plus a predicate, plus (where ordering matters) `encode`/`decode` integer-coercion functions. The file is small (~150 lines) but the symbols it defines are referenced in every assertion, every deduction, every truth value, every literal — anywhere CycL needs a tiny categorical attribute.

The five enumerations:

| Enumeration | Constant | Members | Ordered? |
|---|---|---|:---:|
| **Inference direction** | `*valid-directions*` | `:backward`, `:forward`, `:code` | yes (encode/decode) |
| **Assertion type** | `*valid-assertion-types*` | `:gaf`, `:rule` | no |
| **EL strength** | `*valid-el-strengths*` | `:default`, `:monotonic` | yes (subsumption check) |
| **Truth** | `*valid-truths*` | `:true`, `:unknown`, `:false` | informally |
| **Sense (literal polarity)** | `*valid-senses*` | `:neg`, `:pos` | no |
| **HL truth value (TV)** | `*valid-hl-truth-values*` | `:true-mon`, `:true-def`, `:unknown`, `:false-def`, `:false-mon` | yes (encode/decode) |
| **Term args** | `*term-args*` | `1 2 0 :neg :pos 3 4 5 :ist :other` | yes (a fixed argument-position dispatch order) |

These are **the ground vocabulary** of the KB's truth/justification system. They never grow at runtime — every member is fixed at compile time. They are not OO enums; they are keyword symbols that participate in `case` dispatch and `(member-eq? X *valid-X*)` predicates.

## When does an enumeration value come into being?

Every enumeration value is a *literal keyword constant*. They don't get "created"; they exist at read time as `:foo` and become elements of the `defconstant` list at file load. The interesting question is **when do KB facts and runtime decisions get tagged with a particular value?**

### Direction (`:backward` / `:forward` / `:code`)

A direction tag is attached to every rule assertion saying *which way that rule is meant to fire*:
- `:backward` — used only to answer queries (the default).
- `:forward` — fires whenever the antecedent becomes true (forward propagation runs the consequent).
- `:code` — the rule is realized as compiled code, not as inference (used by `defcyc-subl-defn` in evaluatable predicates and by some HL modules).

The tag is set when an assertion is created (via `assert-direction` in [kb-access/hl-modifiers.md](../kb-access/hl-modifiers.md)) and can be changed by `change-direction` (see `assertions-interface.lisp`). It influences forward-propagation enrollment and the rule-driven HL module dispatch.

### EL strength (`:default` / `:monotonic`)

Every EL assertion carries a strength saying whether the conclusion is overrideable:
- `:default` — a defeasible default; later, more-specific evidence can argue against it.
- `:monotonic` — a hard rule that cannot be defeated.

The tag is set at assertion time via `assert-strength`. `el-strength-implies S1 S2` returns true iff `S2` is at least as strong as `S1` (i.e. `:monotonic` implies `:default` but not vice versa). Used during argumentation when comparing competing supports.

### Truth (`:true` / `:false` / `:unknown`)

Each assertion has a *truth* — whether it asserts the proposition or its negation, or expresses ignorance. `:unknown` exists for explicitly-unknown facts (rare; mostly used for incomplete conditional probabilities and a few specific HL modules).

The tag is set at assertion creation via `assert-truth`; it can be flipped by `swap-assertion-truth`. Combined with strength to form an HL truth value (see below).

### Sense (`:pos` / `:neg`)

A sense is the polarity of a literal in a clause. Every literal in a CNF or DNF formula carries a sense, and every KB-mapping iterator that walks "all assertions about pred P with sense S" is parameterized by sense. `:pos` ↔ literal appears positively; `:neg` ↔ literal is negated. Equivalent to truth at the formula level, but kept distinct because senses live on *clause literals* while truths live on *whole assertions*.

`inverse-sense` and the truth↔sense conversions (`truth-sense`, `sense-truth`) link the two enumerations: `:pos`↔`:true`, `:neg`↔`:false`. `:unknown` collapses to `:neg` for sense purposes (effectively "not asserted positive").

### HL truth value (TV)

The HL truth value is the **product** of truth and strength, packed into one keyword:

| HL TV | Meaning | `(tv-truth)` | `(tv-strength)` |
|---|---|---|---|
| `:true-mon` | Monotonically true | `:true` | `:monotonic` |
| `:true-def` | True by default | `:true` | `:default` |
| `:unknown` | Unknown | `:unknown` | `:default` |
| `:false-def` | False by default | `:false` | `:default` |
| `:false-mon` | Monotonically false | `:false` | `:monotonic` |

The TV is what argumentation reasons over: a deduction's "color" is a TV, and the argumentation algorithm in [core-kb/arguments.md](../core-kb/arguments.md) uses TVs to compare supports. The functions `tv-truth`, `tv-strength`, and `tv-from-truth-strength` are the projections and constructor.

The encode/decode functions (`encode-tv` ↔ position in `*valid-hl-truth-values*`) are how TVs are stored compactly in CFASL — instead of writing the keyword, the dump writes the integer index.

### Term args (`*term-args*`)

`*term-args*` is a fixed list of "argument-position dispatch tokens" — `1 2 0 :neg :pos 3 4 5 :ist :other`. The order is significant; it's the canonical iteration order over an indexed term's argument positions used by `kb-indexing` and `kb-mapping`. The first three (`1 2 0`) are the most common pred-arg positions; `:neg`/`:pos` represent literal polarity in clause indexing; `3 4 5` cover higher arities; `:ist` is the microtheory wrapper; `:other` is the catch-all for everything else.

The constant has **no consumers in the ported code** (verified via grep) — it was used by indexing modules whose callers were stripped by LarKC. Preserved as evidence of the index-key vocabulary the rewrite needs to support.

## Cyc API surface

Four predicates are registered as Cyc API functions:
- `direction-p`
- `el-strength-p`
- `truth-p` (note: `truth-p` is *registered* but **no defun for it appears in the file or anywhere else in the port** — it was either a stripped function or a built-in macro defined in `subl-support`. The registration is a stub. The function exists by *name* in the API; calling it would error.)
- `sense-p`

`tv-p`, `assertion-type-p`, and the other predicates are not API-exposed — they're internal-only.

## How other systems consume these enumerations

| Enumeration | Primary consumers |
|---|---|
| Direction | Assertion creation/edit (`assertions-interface`), forward-propagation enrollment (`forward.lisp`), rule HL-modules (`removal-modules-*-rule.lisp`), GHL search (`ghl-search-methods.lisp`). |
| Assertion type | Assertion creation, indexing — `:gaf` vs `:rule` is the gross taxonomy that selects different storage paths. Only used in a handful of places (indexing, dumper, czer); usually subsumed under the existence of an antecedent CNF. |
| EL strength | Assertion creation, argumentation (`arguments.lisp` ranks supports by strength), forward propagation (only `:monotonic` rules drive certain inference modes), TVA (`tva-strategy.lisp` filters by strength). |
| Truth | Assertion creation, deduction creation (`deductions-high.lisp`), clause representation (`clauses.lisp` stores per-literal truths), TMS (`tms.lisp` compares truths when reconciling). |
| Sense | Clause representation, KB indexing (`kb-mapping.lisp` iterates by sense), unification (`unification.lisp` flips sense when matching negated literals). |
| HL TV | Deduction creation, GHL search (computes TV for each search step), argumentation, CFASL serialization (TVs are encoded as ints). |

## Notes for a clean rewrite

- **These five enumerations are the right granularity.** Every value carries a precise meaning that's load-bearing somewhere in the inference engine. Don't merge `truth` and `sense` even though they look redundant — keeping them distinct lets the literal level and the assertion level have independent vocabularies.
- **Replace the keyword + `member-eq?` predicate idiom with a real enum type.** A clean rewrite (in CL, Rust, etc.) should use `(deftype direction () '(member :backward :forward :code))` or its equivalent so that `check-type` and the type system enforce the constraint. The current `direction-p` predicate is a runtime-only check.
- **The integer encoding (`encode-direction`, `encode-tv`, `decode-tv`) is a serialization concern, not a domain concern.** Move it to the CFASL layer; the in-memory representation should always be the keyword. The `position`-based encoding is fragile (re-ordering the constant list silently changes the wire format).
- **`*valid-hl-truth-values*` ordering is load-bearing for `encode-tv` only.** Document this as "wire-format order, do not reorder" or break the dependency by encoding via an explicit `(:true-mon . 0) (:true-def . 1) ...` alist.
- **`tv-from-truth-strength :unknown ANY` always returns `:unknown`** — strength is irrelevant when truth is unknown. A clean rewrite should make this an algebraic-data-type case rather than nested `case` dispatch: `(:known TRUTH STRENGTH)` vs `:unknown`.
- **`*term-args*` is an index-key vocabulary.** A clean rewrite that redoes KB indexing should re-derive this list from the index schema rather than hard-coding the mixed integer/keyword sequence. The mixed types are a clue that the index was schema-versioned over time.
- **`truth-p` is registered but undefined.** Either define it (one-liner: `(member-eq? object *valid-truths*)`) or unregister it. Currently the API claims to expose a function that doesn't exist — a calling client would get an undefined-function error. This is a port bug worth noting.
- **The `:code` direction is a code smell.** It's a rule that bypasses the inference engine entirely by calling a Lisp function. A clean rewrite should split this out into a "function-backed predicate" first-class concept rather than overloading the direction tag.
- **`encode-direction` and `decode-direction` use `position`/`nth` linearly.** Three elements, so it doesn't matter performance-wise — but a clean rewrite should use the `deftype` MEMBER form's natural enumeration index rather than `position` calls.
