# KB accessors, macros, utilities, control vars, compare

This bundle is the library layer that the rest of the engine talks to when it wants a *named property* of a KB term — `result-isa`, `defining-defns?`, `decontextualized-predicate?`, `fan-out-arg`, `not-assertible-mt?`, etc. — without having to know which predicate it queries against, which MT scope is correct, or which microoptimizations are appropriate. It is essentially Cyc's *standard library of named queries*: every accessor here has the same shape — call into [kb-mapping.md](kb-mapping.md) with the right predicate and arg-position, return a list/value/boolean.

It also includes related odds-and-ends: KB-wide feature flags, sort orders for terms, KB statistics dump, the KB-difference / KB-intersection comparison structures used for cross-image diffing, and a small set of utility macros.

The five files do five distinct things; they're grouped here because they're the "service layer" between the iterators in kb-mapping and the named knowledge consumers (inference, canonicalizer, rule-set, accessors, etc.).

## When does anything in this layer run?

There is no creation-and-mutation lifecycle to track — the layer is a stateless accumulation of named queries plus a few small tables. The only triggering situations are:

1. **Some caller asks "what is the X of Y?"** — `result-isa func`, `argn-isa relation argnum`, `comment fort`, `cyclist? term`, `binary-predicate? pred`, `decontextualized-predicate? pred`, `quoted-argument? rel argnum`, `complete-extent-asserted-gaf pred`, etc. The accessor expands to one or two `pred-values` / `fpred-value` / `some-pred-value` calls in the right MT scope.

2. **The KB starts up.** `setup-kb-tables-int` is called from KB initialization with constant/nart/assertion/deduction/kb-hl-support/clause-struc/unrepresented-term counts, sized by `*kb-table-padding-multiplier*` (1.05). It chains to per-system `setup-*-tables` calls.

3. **The KB is cleared.** `clear-kb-state-int` walks every per-system `free-all-*` and `clear-*` cleaner. `clear-kb-state-hashes` clears computed caches.

4. **The KB is being inspected.** `kb-statistics` writes a formatted multi-line summary to a stream.

5. **Two KB images are being compared.** `with-new-kb-compare-connection` opens a remote-image link; `do-kb-intersection-constants`, `do-kb-difference-*` walk the cached comparison results. The bulk of the comparison computation is `missing-larkc`.

6. **Forward inference is active.** `*within-forward-inference?*`, `*forward-inference-environment*`, `*forward-inference-time-cutoff*` are bound by callers; `kb-control-vars.lisp` declares them and registers them with `*fi-state-variables*`.

7. **Some FORT is being removed.** `*forts-being-removed*` is dynamically extended by callers — `some-fort-being-removed?` is a poll-only predicate other layers use to skip work that would dangle on a half-removed term.

## kb-accessors.lisp — named knowledge accessors

The bulk of this file is single-line wrappers like:

```lisp
(defun* sufficient-defns? (col &optional mt) (:inline t)
  (some-pred-value-in-relevant-mts col #$defnSufficient mt))
```

Each accessor is the *intent-named* form of a KB query: a reader looking at `(sufficient-defns? col mt)` knows what's being asked without unpacking the predicate or arg position. The file is a directory mapping intent-name → kmu helper + predicate.

### Categorical groupings

| Category | Sample accessors | Predicate(s) |
|---|---|---|
| Predicate property tests | `binary-predicate?`, `irreflexive-predicate?`, `asymmetric-predicate?`, `anti-symmetric-predicate?`, `transitive-predicate?`, `anti-transitive-predicate?`, `symmetric-predicate?`, `commutative-function?` | `#$IrreflexiveBinaryPredicate`, `#$AsymmetricBinaryPredicate` etc. via `…-binary-predicate-p` |
| Defns | `admitting-defns?`, `sufficient-defns?`, `necessary-defns?`, `defining-defns?` | `#$defnSufficient`, `#$defnNecessary`, `#$defnIff` |
| isa/genls helpers | `cyclist?`, `argn-isa`, `argn-quoted-isa`, `argn-genl`, `arg-isa-pred`, `arg-quoted-isa-pred`, `arg-genl-pred`, `arg-isa-inverse`, `arg-quoted-isa-inverse`, `arg-genl-inverse`, `inverse-argnum`, `isa-pred-arg` | `#$isa`, `#$arg1Isa`, `#$arg2Isa`, …, `#$argsIsa`, `#$arg1Genl`, …, `#$arg1QuotedIsa`, … |
| Result-isa / meta-result-isa | `result-isa`, `meta-result-isa`, `evaluation-result-quoted-isa`, `result-quoted-isa` | `#$resultIsa`, `#$relationAllInstance`, `#$evaluationResultQuotedIsa`, `#$resultQuotedIsa` |
| Decontextualization | `decontextualized-predicate?`, `decontextualized-collection?`, `decontextualized-literal?`, `decontextualized-collection-literal?`, `decontextualized-atomic-cnf?`, `predicate-convention-mt`, `collection-convention-mt`, `decontextualized-literal-convention-mt`, `mt-matches-convention-mt?`, `possibly-convention-mt-for-decontextualized-cnf` | `#$decontextualizedPredicate`, `#$decontextualizedCollection`, `#$predicateConventionMt`, `#$collectionConventionMt` |
| Format / inter-arg | `argn-format-inverse`, `argn-format-pred`, `inter-arg-format-pred`, `inter-arg-format-preds-dep`, `inter-arg-format-preds-ind` | `#$arg1Format`, …, `#$arg1Format-1-2`, … |
| Quoted args / argument types | `quoted-argument?`, `arg-and-rest-isa-min-argnum`, `arg-and-rest-isa-applicable?`, `arg-and-rest-quoted-isa-min-argnum`, `arg-and-rest-quoted-isa-applicable?`, `arg-and-rest-genl-min-argnum`, `arg-and-rest-genl-applicable?` | `#$quotedArgument`, `#$argAndRestIsa`, `#$argAndRestQuotedIsa`, `#$argAndRestGenl` |
| Skolem & reification | `skolemize-forward-somewhere?`, `skolemize-forward?`, `forward-reification-rule?` | `#$skolemizeForward`, `#$skolemizeForwardSomewhere?`, `#$forwardReificationRule` |
| Complete extent | `complete-extent-asserted-gaf`, `complete-extent-asserted-for-value-in-arg-gaf`, `complete-extent-enumerable-gaf`, `complete-extent-decidable-gaf`, `complete-extent-enumerable-for-arg-gaf`, `complete-extent-enumerable-for-value-in-arg-gaf`, `complete-extent-decidable-for-value-in-arg-gaf`, `completely-enumerable-collection-gaf` | `#$completeExtentAsserted`, `#$completeExtentEnumerable`, `#$completeExtentDecidable`, `#$completeExtentAssertedForValueInArg`, …, `#$completelyEnumerableCollection` |
| Term assertions | `all-term-assertions`, `term-assertions` | (delegates to `gather-index` with `*relevant-mt*`) |
| Not-assertible | `not-assertible-predicate?`, `not-assertible-collection?`, `not-assertible-mt?` | `#$notAssertible`, `#$notAssertibleCollection`, `#$notAssertibleMt` |
| Fan-out | `fan-out-arg`, `asserted-fan-out-arg` | `#$fanOutArg` |
| Scoping | `scoping-args`, `some-scoping-arg-somewhere?` | `#$scopingArg` |
| Indeterminate term denotation | `common-non-skolem-indeterminate-term-denoting-function?`, `non-skolem-indeterminate-term-denoting-function?`, `fast-non-skolem-indeterminate-term?` | `#$IndeterminateTermDenotingFunction` (and the hard-coded `*common-non-skolem-indeterminate-term-denoting-functions*` list) |

### Why this layer matters for the rewrite

Each accessor is a *contract* between a piece of inference (or canonicalization, or storage) code and a specific predicate in the KB. If you grep for `#$decontextualizedPredicate`, you find one entry: `decontextualized-predicate?`. Every other piece of code that wants to know "is this predicate decontextualized?" calls the accessor.

This means: in a clean rewrite, the accessor file is the **public ABI of the KB to its consumers** — a registry of named knowledge queries. Renaming a predicate in the KB requires updating one wrapper, not 200 call sites. The clean rewrite should preserve this property.

It also means: the accessor file is the **complete enumeration of which KB predicates the engine treats as load-bearing**. A clean rewrite that wants to know "what predicates do I need to support?" looks here.

### Cyc API exposure

A large fraction of these accessors are registered with `register-cyc-api-function` so they're callable from external API clients. The registrations specify input types (e.g. `(fort fort-p)`) and result types (e.g. `(list fort-p)`), and double as runtime contract documentation.

### `do-gafs-wrt-pred-type` macro

`(do-gafs-wrt-pred-type (var term pred-type &key mt truth done) body)` — registered as a Cyc API macro at the bottom of [`kb-accessors.lisp`](../../../larkc-cycl/kb-accessors.lisp). The body is `missing-larkc`. In Cyc proper this macro dispatches `pred-type` (`:isa`, `:genls`, `:disjointWith`, etc.) to the corresponding `do-gaf-arg-index :predicate <pred>` form. The clean rewrite needs it; it's a thin syntactic shorthand.

## kb-macros.lisp — fort-removal poll

A 50-line file that defines exactly two things:

```lisp
(defparameter *forts-being-removed* nil)
(defun some-fort-being-removed? () *forts-being-removed*)
```

The variable is dynamically extended by `tms-remove-fort` cascades (and friends). Other layers — caches, indexing trickle-up cleanups, dependency walks — read `some-fort-being-removed?` to decide whether to skip work that might dangle on a half-removed FORT or to defer until the cascade has settled. It's a low-rent escape hatch from "what should we do during partial KB state."

A clean rewrite probably folds this into a more general "removal scope" idiom or removes the need entirely (atomic transactional removal would let consumers always see consistent state).

## kb-utilities.lisp — table sizing, statistics, term sorting

### Table-size estimates

```
*estimated-assertions-per-constant*           17.1
*estimated-constants-per-nart*                 1.41
*estimated-assertions-per-deduction*           2.67
*estimated-assertions-per-clause-struc*       39.3
*estimated-assertions-per-meta-assertion*     30.3
*estimated-arguments-per-assertion*            1.12
*estimated-assertions-per-unrepresented-term*  7.97
*estimated-deductions-per-hl-support*         10
*kb-table-padding-multiplier*                  1.05
*default-estimated-constant-count*         50000
```

These are empirical ratios derived from a typical Cyc KB. They're used by `setup-kb-tables-int` to size all per-type id-indices and content managers from a single seed (constant count). Each ratio is the multiplier from the seed to that type's estimated count. The padding multiplier of 1.05 reserves 5% headroom so the tables don't immediately need rehashing as they fill.

### `setup-kb-tables-int` — KB table allocation

```lisp
(setup-kb-tables-int exact?
                     constant-count nart-count assertion-count
                     deduction-count kb-hl-support-count
                     clause-struc-count kb-unrepresented-term-count)
```

Multiplies each count by 1.05, then chains to:

- `setup-kb-fort-tables` → `setup-constant-tables`, `setup-nart-table`, `setup-nart-hl-formula-table`, `setup-nart-index-table`
- `setup-kb-assertion-tables` → `setup-assertion-table`, `setup-assertion-content-table`
- `setup-kb-deduction-tables` → `setup-deduction-table`, `setup-deduction-content-table`
- `setup-kb-hl-support-tables`
- `setup-clause-struc-table`
- `setup-unrepresented-term-table`
- `setup-variable-table`
- `setup-indexing-tables`
- `setup-rule-set`
- `setup-cardinality-tables`

The `exact?` parameter, when t, sizes tables to *exactly* the given count (no padding); used during KB load when the count is known precisely. When nil, the padding ratios from `*estimated-*` are applied.

### `clear-kb-state-int` — KB teardown

Walks `free-all-clause-strucs`, `free-all-kb-hl-support`, `free-all-deductions`, `free-all-assertions`, `free-all-narts`, `free-all-constants`, then `map-constants-in-completions #'init-constant`, `clear-unrepresented-term-table`, `clear-current-forward-inference-environment`, `clear-bookkeeping-binary-gaf-store`, and `clear-kb-state-hashes`. Order matters — leaf objects first (clause-strucs, kb-hl-supports), then dependent objects (deductions, assertions), then identifying handles (NARTs, constants). The constant-completion table is preserved but each entry is reinitialized rather than freed.

### Computed-cache management

Three bookkeeping triples for caches that should regenerate when KB state changes:

- `possibly-clear-dumpable-kb-state-hashes` — clears `defns-cache`, `somewhere-cache` if marked unbuilt.
- `possibly-initialize-dumpable-kb-state-hashes` — calls `missing-larkc` for `nart-hl-formulas`, `non-fort-isa-tables`, `tva-cache`, `defns-cache`, `somewhere-cache`, `arity-cache` if marked unbuilt. The clean rewrite must implement these — they are the "rebuild this cache" entry points.
- `clear-kb-state-hashes` — clears the above plus `after-addings`, `after-removings`, `some-equality-assertions-somewhere-set`, all `arg-type-predicate-caches`.
- `initialize-kb-state-hashes` — initializes the rebuildable ones plus `rebuild-after-adding-caches`, `initialize-some-equality-assertions-somewhere-set`, `initialize-all-arg-type-predicate-caches`.
- `swap-out-all-pristine-kb-objects` — flushes pristine (unmodified-since-load) LRU pages back to disk. Used during dumping to free RAM without losing identity.

### `kb-statistics` — formatted dump

Prints a multi-line summary to a stream:

```
;;; KB <kb-name> statistics
FORTs                   :     XXXXX
 Constants              :     XXXXX
  cached indexing       :     XXXXX  (XX.XXX%)
 NARTs                  :     XXXXX
  cached indexing       :     XXXXX  (XX.XXX%)
  cached HL formulas    :     XXXXX  (XX.XXX%)
Assertions              :     XXXXX
 KB Assertions          :     XXXXX
  cached                :     XXXXX  (XX.XXX%)
 Bookkeeping Assertions :     XXXXX
Deductions              :     XXXXX
  cached                :     XXXXX  (XX.XXX%)
KB HL supports          :     XXXXX
  cached                :     XXXXX  (XX.XXX%)
Unrepresented terms     :     XXXXX
  cached indexing       :     XXXXX  (XX.XXX%)
```

`cached-X-count` reports how many of type X are currently in their LRU manager's hot set; the percentage tells you LRU coverage. Useful for tuning LRU sizes.

### `sort-terms`, `term-<`, `form-sort-pred`, `cons-sort-pred`, `atom-sort-pred`, `symbol-sort-pred`, `fort-sort-pred`, `constant-sort-pred`

A total-order over arbitrary CycL terms used wherever deterministic enumeration matters (canonicalization, rule-set storage, debug output). The order is:

1. **FORTs first** (compared by sub-rule), then non-FORTs.
2. **Among FORTs**: NARTs before constants; constants by name (default) or external-id (if `*sort-terms-by-internal-id?*` is set; mostly missing-larkc body); NART-vs-NART comparison is `missing-larkc 4905`.
3. **Variables next**, then symbols, strings, numbers, characters.
4. **Among atoms of the same type**: lexicographic (name for symbols, `string<` for strings, `<` for numbers, `char<` for characters).

`*sort-terms-constants-by-name*` (default `t`), `*sort-terms-ignore-variable-symbols*`, `*sort-terms-by-internal-id?*` are the dynamic knobs.

### `*definitional-pred-sort-order*`

A hard-coded ordered list of "definitional" predicates that should come first when serializing/displaying assertions about a term:

```
isa, genls, genlPreds, genlInverse, genlMt, disjointWith, negationPreds,
negationInverse, negationMt, defnIff, defnSufficient, defnNecessary,
resultIsa, resultIsaArg, resultGenl, resultGenlArg, arity, arityMin, arityMax,
argsIsa, argsGenl, arg1Isa, arg1Genl, arg2Isa, arg2Genl, arg3Isa, arg3Genl,
arg4Isa, arg4Genl, arg5Isa, arg5Genl, argIsa, argGenl, fanOutArg,
evaluationDefn, afterAdding, afterRemoving
```

These are the predicates a reader most wants to see first when reading about a constant — the ones that *define* the constant rather than describe its properties. Used by paraphrase/render code (mostly missing-larkc).

### Forbidden-collection lists

Three hard-coded lists for KB-covering query restrictions:

- `*forbidden-kb-covering-collection-types*` — `#$UnderspecifiedCollectionType`, `#$CycKBSubsetCollection`. Instances of any of these are forbidden as KB-covering collections.
- `*forbidden-kb-covering-quoted-collection-types*` — `#$WorkflowConstant`, `#$TPTP-PLA001-1-ProblemFORT`, `#$PoorlyOntologized`, `#$StubTerm`, `#$IndeterminateTerm`. Quoted instances of these are forbidden.
- `*forbidden-cols*` — `#$PotentialCBRNEThreat`, `#$Y2KThing`, `#$BPVMilitaryUnit`, `#$BPVEvent`, `#$BPVArtifact`, `#$BPVAgent`, `#$HPKB-TransnationalAgent`. Specific collections forbidden (the `BPV*` and `HPKB-*` are project-specific).
- `*forbidden-specs*` — nil by default; specs of any of these collections are forbidden. The author-comment notes this might be for ensuring private client data doesn't escape. The clean rewrite should make this configurable, not hard-coded.

### `*predicate-type-arity-table*`

Quick mapping from arity to canonical type-collection: `1 → #$UnaryPredicate`, `2 → #$BinaryPredicate`, …, `5 → #$QuintaryPredicate`. Used by canonicalizer/wff to assign predicate types based on declared arity.

## kb-control-vars.lisp — feature flags and FI dynamics

### KB-feature flags

A list of `*<feature>-kb-loaded?*` defglobals one per loadable KB module:

```
*reformulator-kb-loaded?*  *sksi-kb-loaded?*  *paraphrase-kb-loaded?*
*nl-kb-loaded?*            *lexicon-kb-loaded?*  *rtp-kb-loaded?*
*rkf-kb-loaded?*           *thesaurus-kb-loaded?*  *quant-kb-loaded?*
*time-kb-loaded?*          *date-kb-loaded?*  *cyc-task-scheduler-kb-loaded?*
*wordnet-kb-loaded?*       *cyc-secure-kb-loaded?*  *planner-kb-loaded?*
*kct-kb-loaded?*
```

Each is a boolean: t once the corresponding KB module's content has finished loading. They're collected into `*kb-features*` at top-level via a `dolist (pushnew item *kb-features*)` registration. Modules check these to short-circuit work that depends on data not yet present (e.g. NL paraphrase code checks `*nl-kb-loaded?*` before doing surface generation).

`kct-kb-loaded-p` and `unset-kct-kb-loaded` are the only specific accessors visible — other features either lack accessors or rely on direct symbol-value reads.

### `*backchain-forbidden-unless-arg-chosen*`

Initialized via `(reader-make-constant-shell "backchainForbiddenWhenUnboundInArg")` — the `#$` reader macro isn't loaded yet at this file's load order, so direct shell construction is used. This is the predicate name pattern; the constant is later resolved to the real handle.

### Forward-inference dynamics

```
*forward-inference-enabled?*           t       — the master switch
*forward-propagate-from-negations*     nil     — allow forward propagation from negated gafs
*forward-propagate-to-negations*       nil     — allow concluding negated gafs in forward propagation
*within-forward-inference?*            nil     — set during forward inference; (within-forward-inference?) is the predicate
*within-assertion-forward-propagation?* nil    — set during the after-adding propagation phase
*relax-type-restrictions-for-nats*     nil     — temporary relaxation knob
*forward-inference-time-cutoff*        nil     — per-FI time cap (nil = unlimited)
*forward-inference-allowed-rules*      :all    — :all, or list of allowed rules
*forward-inference-environment*        (queue) — the FI work queue
*recursive-ist-justifications?*        t       — give full justifications for ist gafs
*recording-hl-transcript-operations?*  nil     — record HL storage-module operations
*hl-transcript-operations*             nil     — recorded ops list
```

`*forward-inference-environment*` is registered with `*fi-state-variables*` so it's preserved across FI scopes.

## kb-compare.lisp — cross-image diffing

For comparing two Cyc images (typically a local one against a remote one accessed via `with-new-remote-image-connection`). Used in the dev-only "did my KB change?" workflow.

### Data structures

```lisp
(defstruct (kb-intersection (:conc-name "KB-INTRSCT-"))
  remote-image
  constant-index    ; id-index keyed by local internal-id, value = remote-id
  nart-index        ; same
  assertion-index   ; same
  deduction-index)  ; same

(defstruct (kb-difference (:conc-name "KB-DIFF-"))
  common-intersection ; the shared kb-intersection
  renamed-constants   ; dictionary local-constant -> remote-name
  constants           ; set of constants only on local side
  narts               ; set of narts only on local side
  assertions          ; set of assertions only on local side
  deductions)         ; set of deductions only on local side
```

The intersection records the **common subset**, mapped local-id ↔ remote-id. The difference records the **local-only** content plus the table of "this constant exists on both sides but with a different name."

### Communication

`with-new-kb-compare-connection remote-image body` opens a remote-image link, rebinds `*kb-compare-common-symbols*` (a list of CFASL-encoded shared symbols including assertion/deduction/constant/nart/format helpers and all valid truths and HL truth values), calls `set-kb-compare-connection-common-symbols` (missing-larkc) to register them on the remote side, and wraps body in `with-cfasl-common-symbols` so CFASL transmissions use the agreed symbol table. The shared-symbol convention shrinks each transmission by avoiding repeated symbol-name encoding.

### Iteration macros

| Macro | Walks |
|---|---|
| `do-kb-intersection-constants (constant intersection &key progress-message)` | `kb-intersection-constant-index` via `do-id-index`, looks up each by internal-id |
| `do-kb-difference-renamed-constants (constant remote-name diff &key done)` | `kb-difference-renamed-constants` via `do-dictionary` |
| `do-kb-difference-constants (constant diff &key done)` | `kb-difference-constants` via `do-set` |
| `do-kb-difference-narts (nart diff &key done)` | `kb-difference-narts` via `do-set` |
| `do-kb-difference-assertions (assertion diff &key done)` | `kb-difference-assertions` via `do-set` |
| `do-kb-difference-deductions (deduction diff &key done)` | `kb-difference-deductions` via `do-set` |

Most of the actual computation (`kb-intersection-compute`, `kb-difference-compute*`, `compute-remote-image-*`, `compute-constant-remote-id`, `compute-assertion-remote-id`, etc.) is **missing-larkc**. The clean rewrite needs the comparison engine; the harness here is just struct-and-iterators.

### Why this exists

KB comparison is the basis for KB diffing tools, KB merging, and "did the dump change semantically?" scripts. With identity not stable across images (constants get renamed by `myCreator`-style metadata, assertions are matched by canonical CNF, NARTs by HL formula), a structural diff is the only way to detect actual change.

## Public API surface

```
;; kb-accessors — named query functions (selected; ~70 total)
(result-isa func &optional mt) (meta-result-isa mfunc &optional mt)
(binary-predicate? p) (irreflexive-predicate? p) (transitive-predicate? p) ...
(admitting-defns? col &optional mt) (sufficient-defns? col &optional mt) ...
(decontextualized-predicate? pred) (decontextualized-collection? col)
(decontextualized-literal? lit) (predicate-convention-mt pred) ...
(quoted-argument? rel argnum) (complete-extent-asserted-gaf pred)
(skolemize-forward? func &optional mt) (forward-reification-rule? func rule &optional mt)
(argn-isa rel argnum &optional mt) (argn-quoted-isa rel argnum &optional mt)
(argn-genl rel argnum &optional mt) (arg-isa-pred argnum &optional reln mt)
(arg-and-rest-isa-min-argnum rel &optional mt) ...
(fan-out-arg pred &optional mt) (asserted-fan-out-arg pred &optional mt)
(scoping-args rel &optional mt) (some-scoping-arg-somewhere? rel)
(all-term-assertions term &optional remove-duplicates?)
(term-assertions term &optional mt remove-duplicates?)
(not-assertible-predicate? p &optional mt) (not-assertible-collection? c &optional mt)
(not-assertible-mt? mt)
(common-non-skolem-indeterminate-term-denoting-function? obj)
(non-skolem-indeterminate-term-denoting-function? obj)
(fast-non-skolem-indeterminate-term? term)
(do-gafs-wrt-pred-type (var term pred-type &key mt truth done) ...) ; missing-larkc

;; kb-macros
(some-fort-being-removed?)            ; reads *forts-being-removed*

;; kb-utilities — setup, clear, statistics
(setup-kb-tables-int exact? constant-count nart-count assertion-count
                     deduction-count kb-hl-support-count clause-struc-count
                     kb-unrepresented-term-count)
(setup-kb-fort-tables constant-count nart-count exact?)
(setup-kb-assertion-tables size exact?)
(setup-kb-deduction-tables size exact?)
(clear-kb-state-int)
(possibly-clear-dumpable-kb-state-hashes)
(possibly-initialize-dumpable-kb-state-hashes)
(clear-kb-state-hashes)
(initialize-kb-state-hashes)
(swap-out-all-pristine-kb-objects)
(kb-statistics &optional stream)
(sort-terms list &optional copy? stable? constants-by-name?
                            ignore-variable-symbols? key use-internal-ids?)
(term-< t1 t2 &optional ...)

;; kb-control-vars
(within-forward-inference?)
(kct-kb-loaded-p) (unset-kct-kb-loaded)
;; (and a dozen *<feature>-kb-loaded?* globals)

;; kb-compare — diffing
(with-new-kb-compare-connection (remote-image) ...)
(do-kb-intersection-constants (var intersection &key progress-message) ...)
(do-kb-difference-constants (var difference &key done) ...)
(do-kb-difference-narts ...) (do-kb-difference-assertions ...)
(do-kb-difference-deductions ...) (do-kb-difference-renamed-constants ...)
;; (most of the compute-* and add-* operations are missing-larkc)
```

## Consumers

| Consumer | What it uses |
|---|---|
| **Inference engine** | `binary-predicate?`, `transitive-predicate?`, `argn-isa`, `argn-genl`, `defining-defns?`, `result-isa` to gate / parameterize per-rule reasoning. |
| **Canonicalizer** (`czer-main.lisp`, `wff.lisp`) | `decontextualized-*` family, `quoted-argument?`, `arg-and-rest-*`, `fan-out-arg`, `not-assertible-*`, `predicate-convention-mt`, `mt-matches-convention-mt?` — drive type-checking and decontextualization decisions during canonicalization. |
| **Forward propagation** | `*within-forward-inference?*`, `*forward-inference-enabled?*`, `*forward-inference-environment*`, `*forward-inference-time-cutoff*`. |
| **Removal cascades** (`tms.lisp`) | `some-fort-being-removed?` to skip work; `clear-kb-state-int` for full reset. |
| **KB dumper / loader** | `setup-kb-tables-int`, `swap-out-all-pristine-kb-objects`, `clear-kb-state-int`, `*estimated-*` ratios. |
| **Statistics tools** | `kb-statistics`. |
| **Term-rendering / paraphrase** | `*definitional-pred-sort-order*`, `sort-terms`, `*forbidden-cols*`. |
| **External diff tooling** | `with-new-kb-compare-connection` and the `do-kb-difference-*` walkers. |
| **Cyc API** | most kb-accessors are exposed via `register-cyc-api-function`. |

## Notes for a clean rewrite

- **The accessor file is the public ABI between inference and KB.** Keep it as a thin, single-purpose layer. Resist adding business logic — accessors should be one-liners that delegate to the lookup machinery and let the predicate-name carry the meaning.
- **The `*-binary-predicate-p` family of one-liners** (`irreflexive-predicate?` etc.) is `(<type>-binary-predicate-p p)` and `<type>-binary-predicate-p` is `(isa? p #$<Type>BinaryPredicate)` from a sibling file. Two thin wrappers stacked. Collapse to one.
- **Hard-coded forbidden lists should be configuration.** `*forbidden-cols*`, `*forbidden-kb-covering-collection-types*`, etc. are environment-specific. A clean rewrite reads these from a config file or KB assertion (`(forbiddenCol #$Y2KThing)`).
- **`kb-statistics` is fine but it's a manual implementation of "iterate every per-system count".** A clean rewrite registers each system with a "report stats" callback so `kb-statistics` is `(dolist (sys *kb-systems*) (funcall (system-stats-fn sys) stream))` and the format is uniform.
- **`*estimated-*-per-*` ratios are KB-distribution-specific.** They were tuned for a Cyc-Tiny-era KB. The clean rewrite either re-derives them at startup from the loaded KB, or stores the actual counts in the dump and skips the ratios entirely.
- **The kb-feature flags are coarse** — boolean per module. A more flexible design has (a) a registry that records loaded chunks with metadata, and (b) per-query "needed-features" annotations so accessors can fail loudly when a needed module is absent.
- **`kb-compare.lisp` is mostly stripped.** The clean rewrite must implement `kb-intersection-compute`, `kb-difference-compute`, the `compute-*-remote-id` family, and the iteration macros. The struct definitions and the iteration shape are honest; the comparison logic is not.
- **`do-gafs-wrt-pred-type` (missing-larkc) is a very common shorthand** — a clean rewrite should provide it, since "iterate gafs of TERM where predicate is one of $isa/$genls/$disjointWith/etc." is the most common shape of an SBHL-flavored query.
- **`*forts-being-removed*` is a leaky abstraction.** A clean rewrite uses transactional removal — the cascade either fully completes or rolls back, so consumers never see a half-removed FORT. The polling pattern goes away.
- **`sort-terms` / `form-sort-pred` / `atom-sort-pred` is structurally messy.** It's a hand-coded total order through 6 type cases via a chain of `or`/`and`. A clean rewrite uses CLOS-like dispatch on type and lifts the order specification into a declarative table.
- **`*decontextualized-*-mt*` and `*default-convention-mt*` are external dependencies of the accessor file.** They're defined elsewhere (`mt-vars.lisp`?) but read here as if globally accessible. A clean rewrite imports them explicitly.
