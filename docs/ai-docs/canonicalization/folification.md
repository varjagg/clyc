# Folification (CycL → First-Order Logic)

**Folification** is the *export* path from CycL to standard First-Order Logic (FOL). The motivation: external theorem provers and FOL libraries don't speak CycL — they speak [TPTP](http://www.tptp.org) (the standard FOL benchmark format) or generic CycL-shaped FOL. To use them, the engine must translate each CycL assertion into an equivalent FOL formula.

This is *not* the inverse of canonicalization (that's the uncanonicalizer — see "Uncanonicalize" doc). Folification produces *a different formal language*, not pretty-printed EL. The result is plain FOL — no MTs, no NARTs, no skolems beyond standard Skolem functions, no meta-literals.

The system is mostly missing-larkc in the LarKC port, but the configuration vocabulary is intact, which lets the design intent be reconstructed.

Source file: `larkc-cycl/folification.lisp` (601 lines, mostly missing-larkc bodies)

## Why folification?

Two academic motivations from the file's commentary:

1. **First-Orderized ResearchCyc paper** (referenced in `*deepak-queries*`, named for Deepak Ramachandran). Cyc was once translated to FOL for a published evaluation showing FOL theorem provers can answer Cyc queries. The set of test queries is hardcoded in this file as `*deepak-queries*` and `*deepak-queries-2*`.
2. **Interoperability** — TPTP-formatted output can feed any TPTP-compatible prover (Vampire, E, etc.). Useful for verification, benchmarking, and embedding Cyc reasoning into FOL pipelines.

The system is a *one-way export*: CycL → FOL. There is no FOL → CycL path here. The engine cannot ingest FOL.

## Configuration vocabulary

The folification configuration is the bulk of the file. Each parameter controls one axis of the translation. They cluster:

### Translation type

```
*fol-translation-type* = :regular-fol
  :regular-fol — direct translation
  :set-theory — set-theoretic translation (collections become sets, isa becomes elementOf)
```

Set-theoretic translation is deeper: it represents Cyc's collection membership in standard ZF set theory, which is more expressive but more verbose.

### MT handling

```
*fol-mt-handling* = :mt-visible-except-core-mts
  :mt-visible — translate MTs as part of the formula (using ist as a top-level wrapper)
  :mt-visible-except-core-mts — same but skip MTs that everyone uses (BaseKB, etc.)
  :mt-argument — extra MT argument on every literal
  (:collapse <theory>) — collapse all MTs into one named theory
  :flat — drop MTs entirely (NOT RECOMMENDED — loses correctness)
```

This is the central design choice. Cyc's MT system has no direct FOL equivalent; folification has to choose how to represent context. `mt-visible-except-core-mts` is the default — preserve MT semantics where it matters but don't pollute output with universal core context.

### ISA handling

```
*fol-isa-handling* = :unary-predicate
  :unary-predicate — `(isa X Cat)` becomes `cat(X)` (faster but less faithful)
  :isa — `(isa X Cat)` stays as a binary predicate
```

Unary-predicate form is more native to FOL provers; binary form is more faithful to the CycL.

### Rule-macro predicate handling

```
*fol-rmp-handling* = :gaf
  :gaf — translate the rule macro as a GAF
  :expansion — expand the rule macro inline
  :gaf-and-expansion — both
```

Rule-macro predicates in CycL (predicates whose semantics are defined by an expansion sentence) have multiple FOL representations. The choice depends on whether downstream provers can handle the expanded form.

### String handling

```
*fol-string-handling* = :allowed
  :allowed — keep strings as terms
  :dwim-to-single-constant — all strings → one constant `TheString`
  :dwim-to-distinct-constants — each string → its own constant
  :skip — skip assertions with strings
```

FOL doesn't natively know about strings; folification must make a choice.

### Number handling

```
*fol-number-handling* = :dwim-floats-to-distinct-constants
  :allowed — keep numbers as terms
  :dwim-floats-to-distinct-constants — float → constant
  :dwim-all-to-distinct-constants — all numbers → constants
```

The `dwim-floats-to-distinct-constants` default is "preserve integers, abstract floats." Some provers can't handle floats; integers usually work because most FOL contexts treat them as constants.

### Output format

```
*fol-output-formats* = (:tptp :cycl)
  :tptp — TPTP standard format
  :cycl — CycL-shaped output (for debugging the translation)
```

TPTP is the default in production; CycL output is for debugging the FOL translation itself (does the FOL look right?).

### TPTP-specific

```
*tptp-query-name* = nil
*tptp-axiom-prefix* = nil
*tptp-long-symbol-min-length* = 256
*tptp-long-symbol-name-cache* — for symbols longer than 256 chars
```

TPTP has length conventions. Long symbols are cached so the same Cyc constant always produces the same shortened TPTP symbol within a file.

### Counters

```
*tptp-axiom-count*, *candidate-sentence-count*, *handled-sentence-count*,
*term-count*, *handled-term-count*, *partially-handled-term-count*, *unhandled-term-count*
```

Per-run statistics: how many sentences were translated, how many failed, etc.

## Unfolifiable terms

Some CycL constructs cannot be translated to FOL:

```lisp
(deflexical *unfolifiable-terms*
  (list #$Quote #$EscapeQuote #$QuasiQuote #$SubLQuoteFn #$ExpandSubLFn
        #$completeExtentEnumerable #$completelyEnumerableCollection #$unknownSentence
        #$evaluate #$Nothing #$CollectionDifferenceFn #$reformulatorEquiv))
```

Why each is unfolifiable:
- **Quote / EscapeQuote / QuasiQuote / SubLQuoteFn / ExpandSubLFn** — quoting is meta-linguistic; FOL has no native quoting
- **completeExtentEnumerable / completelyEnumerableCollection** — KB-only completeness predicates
- **unknownSentence** — refers to inference state, not the formal language
- **evaluate** — meta-evaluation
- **Nothing** — Cyc's empty collection; clashes with FOL's `nothing` semantics
- **CollectionDifferenceFn** — set-theoretic operator that requires fol-translation-type :set-theory
- **reformulatorEquiv** — KB-internal equivalence not exported

Sentences containing these terms get skipped or specially handled (depending on configuration).

## Failure modes

`*folification-unhandled-explanation-table*` is a 17-entry alist of failure-keyword → human-readable reason. Each captures one class of un-folifiable input:

| Reason keyword | Why it can't be folified |
|---|---|
| `:variable-arity-predicate` | Variable-arity predicate with a maximum arity |
| `:variable-arity-function` | Variable-arity function with a maximum arity |
| `:unbounded-arity-predicate` | Variable-arity predicate with no upper bound |
| `:unbounded-arity-function` | Variable-arity function with no upper bound |
| `:meta-sentence` | Sentence used as a term |
| `:meta-assertion` | Assertion used as a term |
| `:meta-variable` | Variable used as a meta-level reference |
| `:subl-escape` | Escape to SubL (an underlying-implementation hook) |
| `:function-arg-constraint` | Argument constraint on a function (FOL has no native constraint syntax for function args) |
| `:function-quantification` | Quantified over functions (higher-order) |
| `:predicate-quantification` | Quantified over predicates (higher-order) |
| `:collection-quantification` | Quantified into a collection (effectively predicate quantification) |
| `:sequence-var` | Sequence variable |
| `:ist` | Used `#$ist` for context lifting |
| `:ill-formed` | Not WFF |
| `:nonstandard-sentential-relation` | Bounded existential, user-defined logical operator/quantifier |
| `:expansion` | Has an expansion that can't be translated |
| `:kappa` | Used `Kappa` (predicate-denoting function) |
| `:lambda` | Used `Lambda` (function-denoting function) |
| `:explicitly-forbidden-term` | Listed in `*unfolifiable-terms*` |

The reasons are all higher-order or meta-level features that have no FOL equivalent. For each failure, folification skips the assertion and increments `*unhandled-term-count*`.

## When does folification fire?

Folification is a *batch operation*: walk a corpus of CycL assertions, translate each that can be translated, output a TPTP file. It is not part of any inference path. Triggered by:
- User runs `folify` (missing-larkc) on a sentence list
- Researcher runs the academic test suite (`*deepak-queries*` etc.)
- Cyc developer runs the FOL benchmark for an external prover

There is no automatic folification — every fire is explicit.

## The Deepak query sets

`*deepak-queries*` and `*deepak-queries-2*` are hardcoded test corpora used to evaluate the folification system. Examples:

```
(ist CurrentWorldDataCollectorMt-NonHomocentric (isa isa Individual))
(ist CurrentWorldDataCollectorMt-NonHomocentric
  (implies
    (and (subOrganizations ?z ?x)
         (hasMembers ?x ?y))
    (hasMembers ?z ?y)))
```

The first asks "is `isa` an instance of `Individual`?" — meta-level. The second is a transitivity rule for organisational structure.

`*deepak-folification-properties*`:
```
(:translation-type :set-theory
 :mt-handling :mt-visible-except-core-mts
 :isa-handling :unary-predicate
 :string-handling :dwim-to-single-constant)
```

These are the property values used in the published Deepak experiments, capturing the configuration that produced the academic results.

## Categorisation flags

```
*categorize-fol-predicates* — categorise predicates after FOLification
*categorize-fol-functions* — same for functions
*categorize-fol-terms* — same for terms
```

When set, the folifier emits per-predicate/function/term metadata to the output file. Used for downstream analysis (e.g. counting which predicates dominate the translated corpus).

## Caching

```
*fol-sequence-variable-args-for-arity-caching-state*
*compute-tptp-query-index-number-caching-state*
*fol-nart-string-caching-state*
*tptp-long-symbol-name-cache* — equal-keyed, capacity 256
```

These are the caches the folifier maintains during a translation run. The most consequential is `*tptp-long-symbol-name-cache*`: TPTP has length restrictions; long Cyc constants must map to consistent shortened TPTP symbols.

## Folification properties bundle

`*deepak-folification-properties*` is a **property bundle** — an alist of keyword/value pairs that configures all the per-axis flags at once:

```lisp
(:translation-type :set-theory
 :mt-handling :mt-visible-except-core-mts
 :isa-handling :unary-predicate
 :string-handling :dwim-to-single-constant)
```

The clean rewrite should keep this pattern: a property-bundle struct that callers pass in, and the folifier reads from. The current implementation reads from dynamic specials, which makes batch experiments error-prone.

## Cross-system consumers

- **External theorem provers** (Vampire, E, Otter, etc.) — consume the TPTP output
- **Folification benchmark suite** — runs `*deepak-queries*` and `*deepak-queries-2*` and compares results against known answers
- **WFF-checker** — folification gates on WFF; ill-formed assertions get the `:ill-formed` failure reason
- **EL→HL canonicalization** — runs first; folification operates on the HL form

## Notes for the rewrite

- **Folification is rare in production.** The clean rewrite can keep it as an optional module; default off; built only when needed.
- **The configuration vocabulary is well-designed.** Each axis has 2-5 named values that map onto distinct semantic choices. Keep the structure; expose as a typed configuration struct.
- **Most function bodies are missing-larkc.** The shape of the work is well-bounded by the configuration: walk the assertion, dispatch on each construct, emit the TPTP form. The clean rewrite must implement the dispatch explicitly per construct kind.
- **The 19 unfolifiable failure reasons** (`*folification-unhandled-explanation-table*`) are the canonical list of "things FOL can't represent." Keep all 19; they're the contract between the folifier and the external prover.
- **TPTP is the standard.** The clean rewrite should support TPTP first-class. The CycL output format is for debugging only; doesn't need long-term maintenance.
- **String and number "DWIM" modes** (`*fol-string-handling*`, `*fol-number-handling*`) are pragmatic: many provers can't handle strings/floats. The DWIM ("do what I mean") name reflects that the folifier picks the right thing based on context.
- **MT handling is the hard problem.** No FOL equivalent for context. The four named modes (`:mt-visible`, `:mt-visible-except-core-mts`, `:mt-argument`, `:collapse`, `:flat`) capture different tradeoffs. Keep all of them; different downstream uses prefer different modes.
- **Property bundle pattern** — pass in an alist or struct of all settings, rather than reading dynamic specials. The latter is error-prone; the former is composable.
- **Per-run statistics** (`*tptp-axiom-count*`, `*candidate-sentence-count*`, etc.) are essential for benchmarking. Make sure the rewrite exposes them as a result object, not just dynamic specials.
- **`*unfolifiable-terms*` is empirical.** Some terms are forbidden because past experiments showed they break provers. Don't add to this list lightly; each entry is a known incompatibility.
- **Set-theory translation type is more expressive but slower.** `:regular-fol` is the production default. Choose `:set-theory` only when the downstream prover specifically benefits.
- **The Deepak queries are *the* canonical test corpus.** Any change to the folifier must continue to handle these correctly; they're the regression suite.
