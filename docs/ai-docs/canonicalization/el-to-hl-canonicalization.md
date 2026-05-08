# EL → HL canonicalization (czer)

The **canonicalizer** (czer) takes a user-readable CycL sentence (the *EL* — External Language form) and produces the engine-internal *HL* (HL = Heuristic Level) representation: clausified DNF/CNF with KB variables, reified narts, sorted commutative args, and standardised variable names. Two semantically equivalent EL sentences produce *equal* HL forms — that's the canonicalization invariant. Without it, the inference engine would treat `(genls Cat Animal)` and `(genls cat animal)` as different problems; or `(plus 1 2)` and `(plus 2 1)` as different; or two rules with different variable names as separate.

Canonicalization is the *first* step every assert and every query goes through. After czer runs, the rest of the engine sees a normalised form.

The system also handles the inverse: **TL** (Transcript Level) — the format used in transcript files for inter-image KB synchronisation. `canon-tl.lisp` translates between HL and TL: HL constants/narts/vars become `(TLAssertionFn id)`, `(TLReifiedNatFn formula)`, `(TLVariableFn id name)` — symbolic references that survive cross-image transport.

Source files:
- `larkc-cycl/canon-tl.lisp` (198) — HL ↔ TL translation
- `larkc-cycl/czer-main.lisp` (2064) — the main canonicalization pipeline
- `larkc-cycl/czer-meta.lisp` (358) — meta-canonicalization: finding KB assertions from EL sentences
- `larkc-cycl/czer-graph.lisp` (140) — graph datastructures for formula-isomorphism comparison (mostly missing-larkc)
- `larkc-cycl/czer-utilities.lisp` (574) — canonicalizer-directive lookup, arg-permission checks
- `larkc-cycl/czer-trampolines.lisp` (86) — czer-side wrappers for KB lookups
- `larkc-cycl/czer-vars.lisp` (366) — the dynamic-variable vocabulary

## The three formula levels

| Level | Audience | Examples |
|---|---|---|
| **EL** (External Language) | User-facing; what a person types | `(isa Fido Dog)`, `(forAll ?X (implies (isa ?X Bird) (canFly ?X)))`, `(plus 1 (TheOneArg #$Cat))` |
| **HL** (Heuristic Level) | Engine-internal; what the inference engine sees | Clausified DNF/CNF; commutative args sorted; narts reified; KB variables (numeric IDs) |
| **TL** (Transcript Level) | Wire format for KB synchronisation | Same as HL but with `(TLAssertionFn id)`, `(TLReifiedNatFn formula)`, `(TLVariableFn id name)` standing in for opaque object references |

EL → HL is czer's main job. EL ↔ HL is mostly EL → HL plus the inverse `uncanonicalizer` (separate doc, "Uncanonicalize"). HL ↔ TL is `canon-tl.lisp`. EL ↔ TL is rare; usually goes through HL.

## When does canonicalization fire?

The triggering situations:

1. **User asserts.** `cyc-assert-wff(formula, mt)` calls `canonicalize-cycl(formula, mt)` to produce HL clauses, which then become assertions. Every fact added to the KB is canonicalized first.
2. **User queries.** `new-cyc-query(sentence, mt, props)` calls `inference-canonicalize-ask-memoized(sentence, mt, ...)` (in `inference-czer.lisp` — see "Inference czer & analysis" doc). This runs the *same* canonicalizer with a different policy (allow free EL vars, skip skolemisation if `*skolemize-during-asks?*` is nil).
3. **Forward inference.** New conclusions derived by forward rules are canonicalized before being asserted.
4. **TL transcript ingestion.** `transform-tl-terms-to-hl(tree)` walks a TL tree and replaces every TL term with its HL equivalent (looking up the assertion/nart/variable by id).
5. **Cross-image transport.** `transform-hl-terms-to-tl(tree)` walks an HL tree and replaces every HL term with its TL equivalent — used when writing to the transcript queue.

The canonicalizer is *not* re-run on the same formula twice — once HL, always HL. The `czer-result-quiesced-p` check verifies that the input doesn't need another pass; if it does, the loop iterates.

## The pipeline

`canonicalize-cycl-int(sentence, mt, testing?, destructive?, unwrap-ist?, check-wff?)` is the workhorse. The pipeline:

```
1. Canonicalize MT itself (canonicalize-hlmt mt)
2. Bind *within-canonicalizer-p* = t, *czer-memoization-state* = fresh
3. Possibly clear caches (clear-canon-caches)
4. WFF check (canon-wff-p formula mt) — if not WFF, optionally try to simplify into WFF
5. Loop until quiesced or *czer-quiescence-iteration-limit* (10) reached:
   a. clausify-eliminating-ists(result, mt, :cnf, unwrap-ist?)
      → result is now CNF clauses with ist literals processed
   b. cnf-operators-out(result)
      → strip CNF wrapping operators
   c. canonicalize-clauses(result, mt)
      → standardise variables, sort commutative args, reify narts, etc.
   d. Test czer-result-quiesced-p(result, unwrap-ist?)
6. clothe-naked-skolems if *clothe-naked-skolems-p* (asserts termDependsOn for new skolems)
7. Return (values result subordinate-fi-ops? variables-memory mt)
```

The *quiescence* loop is essential: canonicalization may discover new skolems, new narts, new equivalences mid-pass; one iteration may not be enough. The 10-iteration cap (`*czer-quiescence-iteration-limit*`) prevents pathological cases.

`canonicalize-clauses` is the per-pass workhorse. It iterates the clauses doing:

| Step | What it does |
|---|---|
| `canonicalize-clauses-quoted-terms` | Canonicalise quoted subterms (terms inside `(Quote ...)`) |
| `canonicalize-clauses-sentence-terms` | Canonicalise sub-sentences (literals containing nested sentences) |
| `canonicalize-clauses-commutative-terms-destructive` | Sort args of commutative literals (e.g. `(equals A B)` → `(equals A B)` or `(equals B A)` whichever is canonical) |
| `canonicalize-clauses-tou-terms` | Term-of-Unit (NART) reification |
| `canonicalize-functions` | Reify function applications into NARTs |
| `add-term-of-unit-lits` | Add `(termOfUnit ?V Nart)` literals for any quantified function terms |
| `canonicalize-clauses-literals` | Sort literals within each clause via the lit-< total order |
| `canonicalize-clauses-variables` | Standardise variable names |

### Variable canonicalisation

`*canonical-variable-type*` is `:el-var` or `:kb-var` (default). KB variables have integer IDs (`find-variable-by-id n`); EL variables have string names (`X-0`, `X-1`, …).

`get-nth-canonical-variable(n, type)` produces the nth variable of the chosen type:
```
type :el-var → (make-el-var (format nil "X-~d" n))
type :kb-var → (find-variable-by-id n)
```

`*standardize-variables-memory*` records the original-EL-name → KB-id mapping during a canonicalization pass. On the inverse path (uncanonicalisation), this lets the system restore the user's chosen variable names.

The end result: `(forAll ?X (P ?X ?Y))` and `(forAll ?A (P ?A ?B))` produce the same HL form, with `?X` and `?A` both mapped to the same KB variable id 0, and `?Y`/`?B` mapped to id 1.

### Commutative-arg ordering

`canonicalize-literal-commutative-terms-destructive(lit)` sorts the args of a commutative-relation literal. The order is fixed (`order-commutative-terms`) — by `canon-term-<` total order, with constants sorted first by `canonicalizer-constant-<`, then NARTs, then variables.

`*never-commutative-predicates*` lists `#$isa #$genls` — predicates that are *never* commutative (even if SBHL would otherwise consider them so). Checked first for speed.

`commutative-argnums(relation-expression)` returns the list of arg positions that should be sorted. For symmetric binary preds it's `(1 2)`; for partially commutative it's a subset; for `:dont-reorder` directive args, none.

`commutative-terms-in-order-p(t1, t2)` is the comparator: `t` if `t1 < t2` in canonical order.

### Clausification

`clausify-eliminating-ists(sentence, mt, :cnf, unwrap-ist?)` is the EL → CNF conversion:
1. Translate `#$implies` to `(or (not P) Q)`
2. Translate `#$equiv` to `(and (or (not P) Q) (or (not Q) P))`
3. Distribute `#$not` (de Morgan)
4. Distribute `#$and` and `#$or` to put everything in CNF
5. If `unwrap-ist?`, unwrap `(ist mt asent)` literals so the MT becomes the literal's contextualization

The result is a list of CNF clauses, each clause is `(neg-lits pos-lits)`.

`canonicalize-cycl` and `canonicalize-cycl-sentence` are the public entry points. The variant `canonicalize-wf-cycl-sentence` adds WFF checking; `canonicalize-ask-sentence` is the ask-mode variant; `canonicalize-assert-sentence` is the assert-mode variant.

## Memoised entry points

Three memoisations:
- `canonicalize-term-memoized-int(term, mt)` — equal-keyed; for term canonicalisation
- `canonicalize-wf-cycl-int-memoized(sentence, mt)` — equal-keyed; for WFF-checked sentences
- `canonicalize-ask-int-memoized(sentence, mt)` — equal-keyed; for queries

All three are `defun-memoized`. The cache lives in the per-strategy memoization-state; the canonicalizer's own `*czer-memoization-state*` is bound for the duration of a canonicalization. Inside that state, sub-canonicalizations (e.g. canonicalising sub-sentences or commutative subterms) reuse intermediate results.

## Public APIs (registered Cyc functions)

```
(register-cyc-api-function 'el-to-hl
    '(formula &optional mt)
  "Translate el expression FORMULA into its equivalent canonical hl expressions"
  '((formula el-formula-p))
  nil)

(register-cyc-api-function 'el-to-hl-query
    '(formula &optional mt)
  "Translate el query FORMULA into its equivalent hl expressions"
  '((formula el-formula-p))
  nil)

(register-cyc-api-function 'canonicalize-term
    '(term &optional (mt *mt*))
  "Converts the EL term TERM to its canonical HL representation."
  nil
  nil)
```

These are the public entry points. There are also `el-to-hl-fast` and `el-to-hl-really-fast` (mostly missing-larkc) — same operation but skipping some checks for performance-sensitive callers.

## Sentence-level invariants enforced

Per-clause:
- All commutative arg positions are sorted in canonical order
- Literals within the clause are sorted via `lit-<` (total order over predicates and args)
- All non-FORT terms inside literals are reified (NARTs, skolems)
- Variables are renamed to fresh KB variables in standardised order
- Clause is in DNF or CNF (depending on `*form-of-clausal-form*`)

Per-sentence (set of clauses):
- Clauses are sorted via `clause-<`
- Duplicate clauses are removed
- Variables across clauses are consistently named

After canonicalization, `equal` on the HL form is *the* equivalence check: two formulas are semantically equivalent iff their canonical HL forms are `equal`.

## TL (Transcript Level) translation

Three TL term types:

| TL term | Encodes | Args |
|---|---|---|
| `(TLAssertionFn id formula)` | An assertion reference | id (integer) + formula (the EL formula for verification) |
| `(TLReifiedNatFn formula)` | A NART reference | formula (the NAUT formula) |
| `(TLVariableFn id name)` | A KB variable | id (integer) + name (string or nil) |

The trio of predicates:
```
tl-assertion-term?(object) — (TLAssertionFn id formula) shape match
tl-function-term?(object)  — (TLReifiedNatFn formula) shape match
tl-var?(object)            — (TLVariableFn id name) shape match
```

`tl-term?(object)` is the union.

### HL → TL: `transform-hl-terms-to-tl(tree)`

```lisp
(defun transform-hl-terms-to-tl (tree)
  (quiescent-transform tree #'hl-not-tl-term? #'hl-term-to-tl))
```

`hl-not-tl-term?(object)` matches assertions, narts, and variables that are not already TL forms. `hl-term-to-tl(object)` (mostly missing-larkc) dispatches to:
- `hl-assertion-term-to-tl` — `(TLAssertionFn <suid> <formula>)`
- `hl-function-term-to-tl` — `(TLReifiedNatFn <formula>)`
- `hl-var-to-tl` — `(TLVariableFn <id> <name>)`

`tl-encapsulate(tree)` is the convenience: HL → TL → encapsulate (for sending across a boundary).

### TL → HL: `transform-tl-terms-to-hl(tree)`

```lisp
(defun transform-tl-terms-to-hl (tree)
  (quiescent-transform tree #'tl-term? #'tl-term-to-hl))
```

`tl-term-to-hl(object)` (mostly missing-larkc) dispatches to:
- `tl-assertion-term-to-hl` — looks up by id; if found, returns the assertion; if not, errors with `"referenced assertion not found"`
- `tl-function-term-to-hl` — looks up the nart by formula
- `tl-var-to-hl` — `find-variable-by-id`

`tlmt-to-hlmt(tl-mt)` is the convenience for converting a TL MT to HL.

### Use cases

- The agenda transmits operations to the master transcript by translating HL → TL.
- The agenda receives operations from the master transcript by translating TL → HL.
- API requests use TL when arguments include KB-internal references; the handler translates incoming arguments TL → HL before evaluation.

The translation is *quiescent* — repeat until no more transformations apply. This handles nested cases (a TL term containing another TL term).

## Meta-canonicalization (czer-meta.lisp)

Meta-canonicalization is "given an EL sentence, find the KB assertions that match it." This is *not* the same as canonicalisation — it's *lookup* using the canonicalizer's machinery.

### The find-assertions API

```lisp
(find-assertion-cycl sentence &optional mt)   → arbitrary single match
(find-kb-assertions sentence &optional mt)    → list of matches
(find-assertions-cycl sentence &optional mt)  → list, with "missing" flag
```

The three differ in: arity returned, MT-relevance frame, and robust-lookup behaviour.

`find-assertions-cycl-int(sentence, mt, include-genl-mts?)`:
1. Try with the standard CNF/GAF matching predicates
2. If no result and `robust-assertion-lookup?` is on, retry with `recanonicalized-candidate-assertion-equals-cnf?` and `recanonicalized-candidate-assertion-equals-gaf?` (slower but catches uncanonical assertions)

`*robust-assertion-lookup*` defaults to `nil`. The Nov 2002 doc-comment notes the historical change: it was `:default` → t when inside the canonicalizer/wff-checker; now it's nil-by-default because robustness costs too much. The right fix is to recanonicalise uncanonical assertions when they're encountered, not to retry every lookup robustly.

### Cached find-assertions-cycl

`*cached-find-assertions-cycl-caching-state*` holds the cache. `clear-cached-find-assertions-cycl()` clears it manually. The full cache lifecycle is partly missing-larkc — the lookup function (`cached-find-assertions-cycl`) and its `-internal` are stubs. The clean rewrite must implement them.

### Meta-relations

A *meta-relation* is a relation that takes other formulas as arguments — for example `#$equiv`, `#$causes-Underspecified`, `#$assertedSentence`. `meta-relation?(relation, mt)` (mostly missing-larkc) checks; the result is cached via `*meta-relation-somewhere?-caching-state*`.

`possibly-meta-relation?` is the looser version: "could this be a meta-relation?" Used to decide whether to flag a literal for special meta-canonicalization handling.

`mt-designating-literal?(literal)` — does the literal designate an MT (e.g. `(mtVisible #$BiologyMt)`) — when canonicalising a TL formula, an MT-designating literal triggers different lookup logic.

The meta-canonicalization logic exists to handle subtle cases: a sentence like `(equiv P Q)` is itself a sentence containing two sub-sentences. Canonicalising the outer requires canonicalising the inner. Meta-canonicalization is what walks the structure correctly.

## Canonicalizer-directive lookup (czer-utilities.lisp)

The KB can override the canonicalizer's default behaviour for specific relations and arg positions via three predicates:

| Predicate | Granularity |
|---|---|
| `#$canonicalizerDirectiveForArg` | Per (relation, argnum, directive) |
| `#$canonicalizerDirectiveForArgAndRest` | Per (relation, argnum-and-up, directive) |
| `#$canonicalizerDirectiveForAllArgs` | Per (relation, directive) |

The directives:
- `#$AllowGenericArgVariables` — variables in this arg position can be generic
- `#$AllowKeywordVariables` — keywords are allowed as variables
- `#$RelaxArgTypeConstraintsForVariables` — soften arg-type checks for variables
- `#$DontReOrderCommutativeTerms` — skip commutative sorting for this arg

`canonicalizer-directive-for-arg?(relation, argnum, directive, mt)` — does the directive apply? The function also follows spec-directive chains so a parent directive can apply to all spec directives.

`some-canonicalizer-directive-assertions-somewhere?(relation)` — fast precheck: does this relation have any directive assertions at all? If not, skip the per-directive lookup entirely.

These directives are the KB's hook for influencing the canonicalizer without changing engine code. A KB author can mark a specific predicate as "don't sort args" by asserting a `(canonicalizerDirectiveForAllArgs <pred> #$DontReOrderCommutativeTerms)` GAF.

## The dynamic-variable vocabulary (czer-vars.lisp)

`czer-vars.lisp` is essentially a list of dynamic specials that control canonicalizer behaviour. Most are switches that callers can rebind to alter one aspect of the canonicalization:

### Top-level switches

- `*within-canonicalizer-p*` — true while canonicalising
- `*new-canonicalizer?*` — use the newer canonicalizer code path (when both exist)
- `*canon-verbose?*` — print after each step (debugging)
- `*el-trace-level*` — 0..5 trace level

### Variable handling

- `*canonical-variable-type*` — `:el-var | :kb-var`
- `*var?*` — predicate for "is this a variable?"
- `*canon-var-function*` — alternate variable predicate for special canonicalization passes
- `*standardize-variables-memory*` — accumulator of original→canonical name mappings
- `*el-symbol-suffix-table*` — uniquifying suffix table
- `*el-var-blist*` — variable rename mappings during uncanonicalisation
- `*ununiquify-el-vars?*` — should uncanonicalisation strip unique suffixes?

### Existential / skolemisation

- `*turn-existentials-into-skolems?*` — defaults t; "If you set this to NIL, the canonicalizer will be severely crippled"
- `*reify-skolems?*` — defaults t
- `*skolemize-during-asks?*` — defaults nil (asks don't skolemise)
- `*drop-all-existentials?*` — defaults nil; drops existentials entirely
- `*leave-skolem-constants-alone?*` — defaults nil
- `*use-skolem-constants?*` — defaults nil; constant-skolems vs zero-arity-fn-skolems
- `*minimal-skolem-arity?*` — only free vars in args
- `*infer-skolem-result-isa-via-arg-constraints?*` — defaults t
- `*interpolate-singleton-arg-isa?*` — defaults nil
- `*clothe-naked-skolems?*` — for tests; assert `termDependsOn` for new skolems
- `*skolem-axiom-table*` — global table of known skolem definitions
- `*empty-skolems*`, `*mal-skolems*` — diagnostic accumulators

### Universals

- `*implicitify-universals?*` — defaults t; remove universals from the top-level for asserts
- `*assume-free-vars-are-existentially-bound?*` — defaults nil; queries should be t
- `*unremove-universals?*` — for uncanonicalisation, restore universals around free vars

### Simplification

- `*simplify-sentence?*`, `*simplify-literal?*`, `*simplify-implication?*`, `*simplify-non-wff-literal?*` — fine-grained switches for the simplifier
- `*try-to-simplify-non-wff-into-wff?*` — defaults t; let the canonicalizer try to fix non-WFF
- `*simplify-using-semantics?*` — defaults t; skip semantic simplification if nil
- `*simplify-redundancies?*` — defaults nil
- `*simplify-transitive-redundancies?*` — defaults nil
- `*simplify-sequence-vars-using-kb-arity?*` — defaults t

### Sequence variables

- `*el-supports-dot-syntax?*` — defaults t; whether sequence variables (`. ?V`) are allowed
- `*sequence-variable-split-limit* = 5` — max split into separate variables
- `*forbid-quantified-sequence-variables?*` — `:assert-only` (default), t, or nil
- `*variables-that-cannot-be-sequence-variables*` — dynamic stack
- `*el-supports-variable-arity-skolems?*` — defaults t

### Commutative handling

- `*canonicalize-gaf-commutative-terms?*` — defaults t
- `*never-commutative-predicates*` = `(isa genls)` — never sort

### Look-up / recanonicalisation

- `*robust-assertion-lookup*` — defaults nil
- `*robust-nart-lookup*` — defaults `:default`
- `*recanonicalizing?*` — true while recanonicalising
- `*recanonicalizing-candidate-assertion-stack*` — recursion-detection stack
- `*recanonicalizing-candidate-nat?*` — true while recanonicalising a NART

### Loop limits

- `*czer-quiescence-iteration-limit* = 10` — max canonicalization iterations

### Tense handling

- `*canonicalize-tensed-literals?*` — defaults t; rephrase via `was`/`willBe`/etc.
- `*tense-czer-mode*` — `:default | :query | :assert`
- `*uncanonicalize-tensed-literals?*` — defaults t; inverse for uncanonicalisation

### Meta-knowledge

- `*distributing-meta-knowledge?*` — defaults nil
- `*distribute-meta-over-common-el?*` — defaults t

### "Express as" expressivity bits

- `*express-as-rule-macro?*`, `*express-as-genls?*`, `*express-as-arg-isa?*`, `*express-as-arg-genl?*`, `*express-as-genl-predicates?*`, `*express-as-genl-inverse?*`, `*express-as-inter-arg-isa?*`, `*express-as-disjoint-with?*`, `*express-as-negation-predicates?*`, `*express-as-negation-inverse?*`, `*express-as-reflexive?*`, `*express-as-symmetric?*`, `*express-as-transitive?*`, `*express-as-irreflexive?*`, `*express-as-asymmetric?*`, `*express-as-relation-type?*`, `*express-as-required-arg-pred?*` — flags for *equivalence transformations* the canonicalizer is allowed to perform

These last 17 are how a KB author tells the canonicalizer "if you see `(genlPreds X Y)`, you may also express this as `(implies (X args) (Y args))`" or similar. Each defaults nil; KB-driven specific opt-ins.

### Control flags

- `*control?*`, `*control-1*` … `*control-6*`, `*control-eca?*` — temp parameters for controlling experimental code branches

These exist because the canonicalizer is one of the most complex pieces of Cyc; new behaviour is gated behind a control flag until proven safe. The clean rewrite should track which flags are still in flux and consolidate.

## Czer-graph: formula isomorphism (mostly missing-larkc)

`czer-graph.lisp` defines four structs for graph-isomorphism comparison of formulas — the key infrastructure for deciding "are these two formulas, considered as graphs, the same?"

### `v-colour` — vertex colouring

```lisp
(defstruct v-colour
  sorted-constant-list
  sorted-nat-list
  sorted-assertion-list
  list-structure
  sorted-var-positions)
```

A vertex colouring records the *external* identity of a node: which constants it touches, which narts, which assertions, the structural shape, and where its variables fall.

### `arc` — directed edge

```lisp
(defstruct arc
  head     ; the destination vertex
  colour)  ; the colour of this edge
```

### `vertex` — node

```lisp
(defstruct vertex
  id
  colour
  arc-set)
```

### `graph-search-node` — search state

```lisp
(defstruct graph-search-node
  vertex
  search-history)
```

Used during graph-isomorphism search: record the path through the graph so cycles can be detected.

### Use cases

These structures support `compute-sorted-shared-vars(formula1, formula2)` — given two formulas, compute the variables they share *up to renaming*. This is what makes "are these two rules logically equivalent?" computable: convert each to its canonical graph, compare structurally.

Most function bodies are missing-larkc. The clean rewrite must reconstruct from the struct shapes and the sparse comments. The algorithm is well-understood (formula graph isomorphism = standard NP-hard problem; Cyc uses a heuristic with vertex colouring to prune the search space).

## Czer-trampolines: KB lookup wrappers

Two key wrappers:

`czer-memoization-state()` — accessor; returns `*czer-memoization-state*`.
`within-czer-memoization-state?()` — is there a current canonicalizer memoization state?

`czer-scoping-formula?(formula)` — is this formula a *scoping* formula (one that introduces a quantifier scope)?
`czer-scoping-args(formula)` (missing-larkc) — extract the scope-args.
`czer-scoped-vars(formula)` (missing-larkc) — extract the variables introduced.

`czer-argn-quoted-isa-int(relation, argnum, mt-info)` — memoised `argn-quoted-isa` lookup using the canonicalizer's MT-handling (`relevant-mt-is-everything`, `relevant-mt-is-any-mt`, `mt-union-naut-p`, default).

These wrappers exist so deep canonicalizer code can do KB lookups without having to set up MT relevance manually.

## Cross-system consumers

- **Assert path** (`ke.lisp`, `cyc-assert-wff`, etc.) calls `canonicalize-cycl` to produce assertion CNF
- **Query path** (`new-cyc-query` via `inference-canonicalize-ask-memoized`) calls the canonicalizer with ask-mode policy
- **Forward inference** canonicalises new GAFs before recording
- **Agenda** (transcript transmit/receive) calls `transform-hl-terms-to-tl` and `transform-tl-terms-to-hl`
- **TMS** uses `find-kb-assertions` to locate the assertion an argument refers to
- **Pre/post canonicalization** wraps this with additional simplification (see "Pre/post canonicalization" doc)
- **Folification** uses canonicalisation as its first step (see "Folification" doc)

## Notes for the rewrite

- **The pipeline is one of the most complex in the engine.** Don't try to simplify by removing steps; each step handles a specific class of input.
- **The quiescence loop with `*czer-quiescence-iteration-limit* = 10`** is the safety net. Most inputs converge in 1-2 iterations. A formula that needs more than 10 is by definition pathological; the loop should give up and the WFF check should reject it.
- **`equal` on canonical HL is *the* equivalence check.** This means the canonicalizer's output must be *exactly* deterministic — same input ⇒ same output, byte-identical. Don't introduce any non-determinism (hash-table iteration order, time-based naming, etc.).
- **Many flags are temp control variables.** The doc-comments admit it: "Temp: used to control canonicalizer to include (= nil) or exclude (= t) experimental code." The clean rewrite should consolidate: features that are stable should remove their gates; features that are still experimental should be clearly marked.
- **TL is the wire format; HL is the in-memory format.** Don't conflate. The HL ↔ TL boundary is at the agenda; everything else uses HL.
- **The `*standardize-variables-memory*` lets uncanonicalisation restore user variable names.** Without it, the user's `?MyDog` becomes `?X-0` and stays that way; with it, the inverse path can recover `?MyDog`. Keep this; it's user-visible.
- **`*czer-memoization-state*` is per-canonicalization, not per-image.** Don't collapse to a global cache; that breaks the variable-renaming consistency guarantee.
- **The 17 `*express-as-*` flags are how the KB customises canonicalisation.** Keep them; each is a real semantic equivalence that some KB content depends on.
- **`*czer-quiescence-iteration-limit*` defaults to 10.** Keep this. Higher values let the canonicalizer fix-point on more pathological inputs but increase worst-case time.
- **Many functions are missing-larkc.** The signatures and behaviour are documented; the clean rewrite must reconstruct, especially: `clausify-eliminating-ists`, the simplifier helpers, the meta-relation predicates, the `czer-graph.lisp` graph-isomorphism algorithms, the TL ↔ HL translation per-term-type bodies.
- **The canonicalizer is *idempotent on HL*.** Running it on already-HL input should produce the same HL. The clean rewrite should test this invariant.
- **Failed canonicalisation produces `:tautology | :contradiction | :ill-formed`** as the inference status — see the "Strategist & tacticians" doc for how the inference engine surfaces these. The canonicalizer's job is to detect these states; the engine's job is to handle them.
- **`*recanonicalizing?*`** is true when re-canonicalising an already-canonicalised assertion (e.g. after a KB schema change makes a previously-canonical assertion uncanonical). The flag is consulted by lookup paths to use slower-but-more-tolerant matching.
