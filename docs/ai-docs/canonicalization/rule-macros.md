# Rule macros

A **rule macro** is a *meta-level shorthand* for a class of CycL rules. Instead of asserting `(implies (and (genls ?X Y) (isa ?Z ?X)) (isa ?Z Y))` (transitivity of isa), the KB asserts `(transitivePredicate isa)` and the engine treats the rule as implicit.

The canonicalizer has an *equivalence transformation*: when it sees a rule shape that *matches* a rule-macro pattern (e.g. a transitivity rule structure), it can convert it to the corresponding rule-macro assertion. This compresses the KB and makes the rule's semantics explicit.

The transformation is opt-in via the 17 `*express-as-X?*` flags in `czer-vars.lisp` (see "EL → HL canonicalization" doc, §"Express as expressivity bits"). Each flag enables one specific rule-macro recognition.

The system is mostly missing-larkc in the LarKC port — only one function (`canonicalize-clauses-wrt-rule-macros`) has a partial body; all 36 of its helpers are stubbed.

Source file: `larkc-cycl/rule-macros.lisp` (89 lines, almost entirely missing-larkc)

## The 16 rule-macro categories

Each category has a *recognition predicate* (`X-clause?`) and an *expression function* (`express-as-X`). The list:

| Category | Recognition | Expression | Asserts |
|---|---|---|---|
| Required-arg-pred | `required-arg-pred-clauses?` | `express-as-required-arg-pred` | `(requiredArg1Pred pred ...)` etc. |
| Relation-type | `relation-type-clauses?` | `express-as-relation-type` | varied per relation type |
| Genls | `genls-clause?` | `express-as-genls` | `(genls subcol supercol)` |
| Genl-predicates | `genl-predicates-clause?` | `express-as-genl-predicates` | `(genlPreds subpred superpred)` |
| Genl-inverse | `genl-inverse-clause?` | `express-as-genl-inverse` | `(genlInverse pred1 pred2)` |
| Arg-isa | `arg-isa-clause?` | `express-as-arg-isa` | `(arg1Isa pred col)` etc. |
| Arg-genl | `arg-genl-clause?` | `express-as-arg-genl` | `(arg1Genl pred col)` etc. |
| Inter-arg-isa | `inter-arg-isa-clause?` | `express-as-inter-arg-isa` | `(interArgIsa pred a1 col1 a2 col2)` |
| Disjoint-with | `disjoint-with-clause?` | `express-as-disjoint-with` | `(disjointWith col1 col2)` |
| Negation-preds | `negation-preds-clause?` | `express-as-negation-preds` | `(negationPreds pred1 pred2)` |
| Negation-inverse | `negation-inverse-clause?` | `express-as-negation-inverse` | `(negationInverse pred1 pred2)` |
| Reflexive-predicate | `reflexive-predicate-clause?` | `express-as-reflexive-predicate` | `(reflexive pred)` |
| Irreflexive-predicate | `irreflexive-predicate-clause?` | `express-as-irreflexive-predicate` | `(irreflexive pred)` |
| Transitive-predicate | `transitive-predicate-clause?` | `express-as-transitive-predicate` | `(transitivePredicate pred)` |
| Symmetric-predicate | `symmetric-predicate-clause?` | `express-as-symmetric-predicate` | `(symmetricPredicate pred)` |
| Asymmetric-predicate | `asymmetric-predicate-clause?` | `express-as-asymmetric-predicate` | `(asymmetricPredicate pred)` |

Each is gated by the corresponding `*express-as-X?*` flag — all default off in production. The rule-macro transformation is opt-in because it changes the *form* of the assertion; KB authors might assert a rule that *happens to match* a transitivity pattern but is actually meant to be a regular rule.

## The pipeline

`canonicalize-clauses-wrt-rule-macros(v-clauses)` is the entry. The body shows the dispatch:

```lisp
(defun canonicalize-clauses-wrt-rule-macros (v-clauses)
  (if (not *express-as-rule-macro?*)
      v-clauses
      (if (missing-larkc 3759)
          (missing-larkc 3755)
          (if (missing-larkc 3757)
              (missing-larkc 3754)
              (mapcar #'canonicalize-clause-wrt-rule-macros v-clauses)))))
```

`*express-as-rule-macro?*` is the master switch. When false, no rule-macro transformation. When true, the function tries (in order):
1. (missing-larkc 3759) — likely a top-level pattern check
2. (missing-larkc 3757) — likely a different top-level pattern check
3. Per-clause: `canonicalize-clause-wrt-rule-macros`

`canonicalize-clause-wrt-rule-macros(clause)` (missing-larkc) — the per-clause logic. The shape:
1. Check each `X-clause?` predicate
2. For the first match where the corresponding `*express-as-X?*` flag is t, call the expression function
3. Otherwise return the clause unchanged

## Per-category helpers (mostly missing-larkc)

Each category has additional helpers:

### Reflexive-predicate

- `reflexive-predicate-clause?(clauses, &optional opt)` — recognise the pattern
- `reflexive-neg-lits?(clauses, neg-lits, lit, &optional opt)` — pattern's negative-literals checker
- `express-as-reflexive-predicate(clause)` — convert

### Symmetric-predicate

- `symmetric-predicate-clause?(clause, &optional opt)` — recognise
- `symmetric-literals?(lit1, lit2, &optional opt)` — are these two literals symmetric forms of each other?
- `express-as-symmetric-predicate(clause)` — convert

### Arg-isa

- `arg-isa-clause?(clause, &optional opt)` — recognise
- `relevant-arg-of-isa-clause(arg1, arg2, &optional opt)` — find the relevant arg
- `express-as-arg-isa(clause)` — convert

### Relation-type

- `relation-type-clauses?(clauses, &optional opt)` — recognise (note plural — checks multiple clauses)
- `relation-type-pred(arg1, &optional arg2)` — get the predicate
- `relation-type-gaf(arg1, arg2, arg3, arg4, &optional arg5)` — produce the resulting GAF
- `express-as-relation-type(clauses)` — convert

The `relation-type-` family is most complex because relation types involve multiple constraints (arity, isa, format) that must all match before the conversion fires.

### Required-arg-pred

- `required-arg-pred-clauses?(clauses, &optional opt)` — recognise (multi-clause)
- `required-arg-pred(arg1)` — extract the pred
- `express-as-required-arg-pred(clauses)` — convert

## `make-rm-cnf`

`make-rm-cnf(arg1, &optional arg2)` (missing-larkc) — produces the CNF form of a rule-macro assertion. Used internally by the express-as-X functions to compose the result.

## When does rule-macro canonicalisation fire?

Inside the main canonicalization loop, after clausification. Only when:
1. `*express-as-rule-macro?*` is true (master switch)
2. The corresponding per-category `*express-as-X?*` flag is true

In production, both are typically false. The transformation is enabled when:
- KB authors are asserting many rules that match standard patterns
- A KB rebuild wants to compress redundant rule structure
- An automated tool is normalising rule expressions

## Inverse direction: rule-macro → expanded rule

The opposite direction (expanding rule-macro assertions back into rule form) is *not* in this file. It happens elsewhere:
- The transformation engine treats rule-macro predicates (transitivePredicate, etc.) as having implicit rule expansions
- Specific HL modules (e.g. `removal-modules-transitivity.lisp`) understand the expansion semantics

The two directions are decoupled: canonicalization (forward) compresses; inference (backward) expands as needed.

## Cross-system consumers

- **Canonicalizer** — `canonicalize-cycl-int` calls `canonicalize-clauses-wrt-rule-macros` after main clausification
- **HL modules** — recognise rule-macro predicates and provide their inference behaviour
- **AT system** — uses some rule-macro-asserted constraints (e.g. `arg1Isa`)
- **WFF** — rule-macro assertions go through the same WFF check as any other GAF

## Notes for the rewrite

- **The 16 categories are well-defined.** Each captures a real semantic equivalence: a rule shape that has a more concise rule-macro form. Don't try to combine; each is its own pattern.
- **The flags are opt-in for safety.** Don't flip defaults. KB authors might *intend* a rule that looks like a transitivity but isn't meant to be one.
- **Most function bodies are missing-larkc.** The shape is well-bounded by the predicate names. The clean rewrite must:
  1. Implement each `X-clause?` predicate (recognise the pattern)
  2. Implement each `express-as-X` function (produce the GAF)
  3. Wire them through `canonicalize-clause-wrt-rule-macros`
  4. Implement the multi-clause helpers (`reflexive-neg-lits?`, `symmetric-literals?`, `relevant-arg-of-isa-clause`, etc.)
- **`make-rm-cnf`** is the result-construction utility. Used by every express-as-X. Keep this single point of construction; consistency matters.
- **The recognition is pattern-matching.** The clean rewrite should use the pattern-match engine (see "Pattern matching" doc) for clean recognition of these clause shapes. Currently each predicate likely hand-codes the recognition.
- **Multi-clause patterns (`relation-type`, `required-arg-pred`)** match multiple clauses at once — meaning the canonicalization has to look at the full clause-list, not just one clause. Keep this; the alternatives (per-clause matching) miss patterns that span multiple clauses.
- **Performance matters.** Rule-macro canonicalisation runs on every assert; the recognition predicates must be cheap. Optimise for the common case of "no rule macro applies" — short-circuit on the first failed predicate.
- **`*express-as-rule-macro?*`** — master switch — defaults nil. The full rule-macro infrastructure exists but isn't enabled by default. The clean rewrite can keep this gating; turning it on for the first time should be a deliberate decision.
- **The inverse direction (expansion)** is in inference, not canonicalization. Don't conflate; canonicalization compresses, inference expands. Both directions are needed for the engine to be complete.
- **Each express-as-X function produces one or more GAFs.** Some categories (like relation-type) produce multiple GAFs from one rule. Document each carefully; the clean rewrite must preserve the equivalence.
- **The transformation must be idempotent.** Once a rule has been converted to a rule-macro form, re-canonicalising should not change it again. Make sure the recognition predicates don't match their own outputs.
