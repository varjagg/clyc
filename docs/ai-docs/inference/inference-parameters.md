# Inference parameters

A user query is parameterised by a single property list — the `query-properties` plist — that specifies *everything* about how the inference should run: resource limits, completeness/efficiency tradeoffs, what the result should look like, which rules and modules are allowed, whether the inference is browsable, and so on. This system catalogues that vocabulary, classifies each property, and provides the merging arithmetic that decides which of two property sets is "more efficient" or "more complete" than the other.

Source files:
- `inference/harness/inference-parameters.lisp` — the property catalogue, inference modes, and merging arithmetic
- `inference/harness/inference-datastructures-enumerated-types.lisp` — the property *predicates* (what counts as static vs. dynamic, what counts as inference vs. strategy vs. problem-store) and per-property accessors with defaults

Most of the predicates and accessors live in `inference-datastructures-enumerated-types.lisp` because they belong to the type vocabulary. The merging logic and the inference-mode table live in `inference-parameters.lisp`. The split is somewhat arbitrary; in the clean rewrite they should be one cohesive module.

## The plist API

Everywhere in the harness, "query properties" means a property list of `(key value key value …)`. Examples:

```lisp
;; A simple ask:
(:bindings (?X) :max-number 10 :inference-mode :shallow)

;; Browsable inference with a private store:
(:browsable? t :continuable? t :max-time 30 :inference-mode :extended)

;; Sharing a store across two queries:
(:problem-store *my-store* :return :bindings-and-supports)
```

The plist is the only way the user controls the inference. Any flag, limit, or capability a caller wants to set is a key in this plist. Once the kernel receives it, the plist is *split* into four sub-plists by `extract-…-properties` filters (see "Extraction" below), each routed to the relevant subsystem (problem-store / inference / strategy / dynamic-only). The defaults are read from per-property `*default-…*` deflexicals at the moment of need (so they can be rebound for tests).

The clean rewrite should consider whether to keep this plist representation or move to a typed property struct. The plist representation has the virtue of being trivially extensible (any caller can stuff in any keyword they want) and trivially serialisable, but at the cost of validation discipline (`query-property-p` does runtime membership testing).

## Property classification

Every recognised property belongs to exactly one *category* and one *lifecycle*:

**Category** = which subsystem owns it:
1. **inference properties** — owned by the `inference` struct (e.g. `:max-number`, `:allow-abnormality-checking?`)
2. **strategy properties** — owned by the `strategy` struct (`:productivity-limit`, `:proof-spec`, `:removal-backtracking-productivity-limit`)
3. **problem-store properties** — owned by the `problem-store` struct (`:transformation-allowed?`, `:equality-reasoning-method`, `:max-problem-count`, etc.)

**Lifecycle** = when it can change:
1. **static** — set at creation, immutable while the inference is suspended. Changes require creating a fresh inference. (`:problem-store`, `:allowed-rules`, `:result-uniqueness`, the policy switches.)
2. **dynamic** — may be updated each time the inference is suspended and continued. (`:max-number`, `:max-time`, `:max-step`, `:return`, `:metrics`, `:productivity-limit`.)

**Meta-property** is a third axis; the only meta-property is `:inference-mode`, which expands into a whole cluster of other property values (see "Inference modes" below).

The cross-product gives 6 buckets of properties, plus the meta bucket. The full vocabulary is the union of these deflexicals from `inference-datastructures-enumerated-types.lisp`:

| Property set | Defined in | Membership |
|---|---|---|
| `*inference-static-properties*` | enumerated-types | 17 keys (see "Catalogue") |
| `*inference-resource-constraints*` | enumerated-types | 4 keys: `:max-number`, `:max-time`, `:max-step`, `:inference-mode` |
| `*inference-other-dynamic-properties*` | enumerated-types | 12 keys (see "Catalogue") |
| `*inference-meta-properties*` | enumerated-types | 1 key: `:inference-mode` |
| `*strategy-static-properties*` | enumerated-types | 2 keys: `:removal-backtracking-productivity-limit`, `:proof-spec` |
| `*strategy-dynamic-properties*` | enumerated-types | 1 key: `:productivity-limit` |
| `*problem-store-static-properties*` | enumerated-types | 16 keys (see "Catalogue") |
| `*problem-store-dynamic-properties*` | enumerated-types | nil — no problem-store property is dynamic |

`query-property-p` is the union predicate: `(or (query-static-property-p) (query-dynamic-property-p))`, where each side is the union of the inference/problem-store/strategy variants. `inference-dynamic-property-p` is the union `(or inference-resource-constraint-p (member-eq object *inference-other-dynamic-properties*))`.

## Property catalogue

### Inference static properties

From `*inference-static-properties*`:
- `:disjunction-free-el-vars-policy` — `:require-equal | :compute-intersection | :compute-union` — what to do with EL variables that appear free on different sides of a disjunction
- `:result-uniqueness` — `:proof | :bindings` — dedup criterion for answers
- `:problem-store` — an existing store to attach to (overrides creating a private one)
- `:conditional-sentence?` — boolean — whether the input is a conditional (treats antecedent as hypothesised)
- `:non-explanatory-sentence` — sub-sentence to evaluate without contributing to explanations
- `:allow-hl-predicate-transformation?` — boolean
- `:allow-unbound-predicate-transformation?` — boolean
- `:allow-evaluatable-predicate-transformation?` — boolean
- `:allow-indeterminate-results?` — boolean (default T)
- `:allowed-rules` — `:all` or a list of allowed rule assertions
- `:forbidden-rules` — `:none` or a list of forbidden rule assertions
- `:allowed-modules` — `:all` or a *modules-spec* (see "Modules spec" below)
- `:allow-abnormality-checking?` — boolean (default T)
- `:transitive-closure-mode` — `:none | :focused | :all`
- `:maintain-term-working-set?` — boolean
- `:events` — list of event-types from `*inference-event-types*` to fire on (`:new-answer`, `:status-change`, `:new-transformation-depth-reached`)
- `:halt-conditions` — list of `*inference-halt-conditions*` (e.g. `:look-no-deeper-for-additional-answers`)

### Inference dynamic properties

From `*inference-resource-constraints*` (4):
- `:max-number` — integer or nil — stop after this many answers
- `:max-time` — seconds or nil — stop after this much real time (enforced via `with-timeout`; can be disabled by `*inference-max-time-timeout-enabled?*` for debugging)
- `:max-step` — integer or nil — stop after this many strategy steps
- `:inference-mode` — meta-property; `:minimal | :shallow | :extended | :maximal | :custom` (see "Inference modes")

From `*inference-other-dynamic-properties*` (12):
- `:forward-max-time` — seconds — time budget for forward propagation in this query (default 0 = none)
- `:max-proof-depth` — integer or nil — limit on proof tree depth
- `:max-transformation-depth` — integer or nil — limit on transformation chains (`*default-max-transformation-depth*` is 0 → no transformation by default)
- `:probably-approximately-done` — score 0..1 — heuristic for when to halt early
- `:return` — `:answer | :bindings | :supports | :bindings-and-supports | :bindings-and-hypothetical-bindings | <template>` — result format (default `:bindings`)
- `:answer-language` — `:el | :hl` — represent bindings in EL (user-friendly) or HL (engine-internal) form (default `:el`)
- `:cache-inference-results?` — boolean — store answers in the KB cache
- `:forget-extra-results?` — boolean — discard answers above `:max-number`
- `:browsable?` — boolean — keep the inference object alive for post-mortem inspection
- `:continuable?` — boolean — allow `continue-inference` to resume after a suspend
- `:block?` — boolean — block the calling thread until the inference completes (vs. async)
- `:metrics` — a metrics-template (see "Metrics" below)

### Strategy properties

Static (`*strategy-static-properties*`):
- `:removal-backtracking-productivity-limit` — productivity above which a tactic will not be considered for removal backtracking (default 200)
- `:proof-spec` — `:anything` or a structured proof-spec describing what kind of proofs the strategy is allowed to produce

Dynamic (`*strategy-dynamic-properties*`):
- `:productivity-limit` — tactics with productivity ≥ this are ignored rather than executed (default `(* 2 100 *default-removal-cost-cutoff*)`)

### Problem-store static properties

From `*problem-store-static-properties*` (16):
- `:problem-store-name` — symbol — assigned name (must be unique among live stores)
- `:equality-reasoning-method` — `:equal | :czer-equal` — how to dedup problems (default `:czer-equal` = canonicalisation-based)
- `:equality-reasoning-domain` — `:all | :single-literal | :none` — which problems are subject to dedup
- `:intermediate-step-validation-level` — `:all | :arg-type | :minimal | :none` (default `:none`)
- `:max-problem-count` — integer (default 100000); `:positive-infinity` allowed for inference modes that need it
- `:removal-allowed?` — boolean (default T)
- `:transformation-allowed?` — boolean (default T)
- `:add-restriction-layer-of-indirection?` — boolean (default nil; auto-flipped to T in some flows)
- `:negation-by-failure?` — boolean (default nil)
- `:completeness-minimization-allowed?` — boolean
- `:direction` — `:backward | :forward` (default `:backward`)
- `:evaluate-subl-allowed?` — boolean (default T) — allow modules to call out to SubL evaluation
- `:rewrite-allowed?` — boolean (default nil; defparameter so tests can rebind)
- `:abduction-allowed?` — boolean (default nil)
- `:new-terms-allowed?` — boolean (default T)
- `:compute-answer-justifications?` — boolean (default T)

Problem-store has no dynamic properties — once the store is created, its policies are fixed.

## Inference modes (the meta-property)

`:inference-mode` is the meta-property that expands into a *cluster* of other property values. There are five modes:

- `:minimal` — fastest, narrowest. No transformation, no new terms, no transitive closure. `max-proof-depth` 15.
- `:shallow` — single-level transformation. Allows evaluatable-predicate transformation. `max-transformation-depth` 1.
- `:extended` — two-level transformation. Allows new terms. `max-transformation-depth` 2.
- `:maximal` — unlimited transformation, full transitive closure, all predicate transformations, infinity for limits.
- `:custom` — explicit values, no expansion.

`:custom` is the default (`*default-inference-mode*`). When the user does not pass `:inference-mode`, no expansion happens — the user's per-property values are taken at face value.

The expansion table is `*inference-mode-query-properties-table*` in `inference-parameters.lisp`. Each mode entry lists which properties it sets and to what value. `query-properties-for-inference-mode(mode)` looks up an entry. `explicify-inference-mode-defaults(query-properties)` (defined in `inference-strategist.lisp`) does the merge:

```lisp
(merge-plist (query-properties-for-inference-mode inference-mode)
             query-properties)
```

`merge-plist` overlays the mode's defaults *underneath* the user's explicit values — so any property the user sets explicitly wins over what the mode would have given. The mode is just a default-cluster.

The kernel calls `explicify-inference-mode-defaults` early in `new-cyc-query` so that subsequent extraction and assignment to the inference/strategy/store all see the expanded values.

A continuation can change the inference-mode dynamically — see "Continuation and mode change" below.

### Mode-vs-mode relationships

The five modes form a partial order along two axes — efficiency and completeness — that match the table `*query-properties-efficiency-hierarchy*`. For each property where two values differ in efficiency, the table lists them in efficiency order (most efficient first). Examples:
- `(:transformation-allowed? nil t)` — disabling transformation is more efficient
- `(:max-transformation-depth …)` — implicit; lower depth is more efficient
- `(:transitive-closure-mode :none :focused :all)` — `:none` most efficient, `:all` most complete
- `(:answer-language :hl :el)` — `:hl` is more efficient (no expansion)

The clean rewrite should think of inference-modes as named points on a Pareto curve between speed and completeness. `:minimal` is the speed corner; `:maximal` is the completeness corner; `:shallow` and `:extended` are useful midpoints.

## Extraction: routing properties to the right subsystem

Once `explicify-inference-mode-defaults` has expanded `:inference-mode`, the kernel splits the resulting plist by category × lifecycle into four buckets. All four extractors are simple `filter-plist` calls over the appropriate predicate:

```lisp
(extract-query-static-properties properties)   ; → all static, all categories
(extract-query-dynamic-properties properties)  ; → all dynamic, all categories

(extract-inference-static-properties props)    ; → inference-static only
(extract-inference-dynamic-properties props)   ; → inference-dynamic only

(extract-strategy-static-properties props)     ; → strategy-static only
(extract-strategy-dynamic-properties props)    ; → strategy-dynamic only

(extract-problem-store-properties-from-query-static-properties props)
                                               ; → problem-store-static only
                                               ;   (no problem-store-dynamic exists)
```

The kernel calls `extract-query-static-properties` and `extract-query-dynamic-properties` first to compute the inference-creation vs. inference-update split. Then for each subsystem it re-filters with the per-subsystem extractor and hands the result to the relevant initializer (`inference-set-static-properties`, `strategy-initialize-properties`, `new-problem-store`).

There is a sharp warning on `extract-query-static-properties`: it filters out `:inference-mode` because `:inference-mode` is a *meta*-property, not a static one. If you skip the explicify step and feed the result to `new-continuable-inference`, you lose the mode — the doc directs callers to `extract-query-static-or-meta-properties` (active declareFunction with no body in the LarKC port) for that case.

## Property accessors with defaults

For every property in the catalogue there is an accessor `inference-properties-X(plist)` (or `strategy-…`, or `problem-store-…`) that does `(getf plist :X *default-X*)`. These are the canonical readers — code never reaches into the plist directly. Examples:

```lisp
(inference-properties-max-number plist)        ; (getf plist :max-number *default-max-number*)
(inference-properties-mode plist)              ; (getf plist :inference-mode *default-inference-mode*)
(inference-properties-transitive-closure-mode plist)
(inference-properties-events plist)
(strategy-dynamic-properties-productivity-limit plist)
```

Defaults live in `*default-…*` deflexicals at the top of `inference-datastructures-enumerated-types.lisp`. Some are nil (meaning "no limit"), some are concrete numbers, some are keywords.

## Modules spec

`:allowed-modules` accepts a mini query-language to restrict which HL modules the inference may use. The grammar:

| Form | Meaning |
|---|---|
| `:all` | unrestricted |
| `(:or spec1 spec2 …)` | union |
| `(:and spec1 spec2 …)` | intersection |
| `(:not spec)` | complement |
| `(:module-type T)` | by tactic-type (`:removal`, `:transformation`, …) |
| `(:module-subtype S)` | by subtype (`:kb`, `:sksi`, `:abduction`) |
| `<symbol>` | a specific module by name |

`filter-modules-wrt-allowed-modules-spec` (in `inference-modules.lisp`, see "Removal modules" doc) walks the spec against each candidate module. The clean rewrite should preserve this DSL — it is the public way to scope an inference to a tractable subset of modules.

## Metrics template

`:metrics` accepts a metrics-template that controls what to record about the inference run. The template is a list of metric names; the inference accumulates each in its `accumulators` hashtable as it runs. The vocabulary is the union of:
- `*specially-handled-inference-metrics*` (5 keys) — e.g. `:new-root-times`, `:problem-creation-times`, `:inference-answer-query-properties`
- `*non-inference-query-metrics*` (3 keys) — clock-time metrics computed outside the inference: `:complete-user-time`, `:complete-system-time`, `:complete-total-time`
- declared-via-`declare-inference-metric` metrics (the LarKC port's `(missing-larkc 36316)` branch)

Plus the predefined templates:
- `*arete-query-metrics*` — `(:answer-count :time-to-first-answer :time-to-last-answer :total-time)`
- `*removal-ask-query-metrics*` — like Arete plus per-answer breakdown and the three complete-time metrics

`*default-inference-metrics-template*` is nil, meaning no metrics by default. After the inference runs, `inference-compute-metrics` walks the template and emits an alist; the kernel post-processes it via `update-query-metrics-wrt-timing-info` to fold in the wall-clock metrics the inference itself cannot measure.

The `*gather-inference-answer-query-properties*` deflexical is a different list: it's the set of query properties whose *runtime values* should be recorded with each answer, so that consumers can later compute "what query properties produced this answer." This is part of Arete's analysis.

## Continuation and mode change

When a caller resumes a suspended inference via `continue-inference`, they may pass a different property plist — including a different `:inference-mode`. `update-inference-input-query-properties` (in `inference-datastructures-inference.lisp`) handles the mode-change case:

1. Compare the static-mode (the one set at creation, recorded in `input-query-properties`) to the dynamic-mode (the one in the new plist).
2. If different: re-extract static properties from `(explicify-inference-mode-defaults input-query-properties)` so the original user intent is recovered, then `putf :inference-mode <new-mode>` and merge the new properties on top.
3. Otherwise just update each property in the dynamic plist via `putf`.

The principle: an inference's *input* properties (what the user originally asked for) are preserved exactly, and the mode-expansion is recomputed each time. So a query started with `:inference-mode :shallow` and later resumed with `:inference-mode :extended` does the right thing — it doesn't keep `:shallow`'s expansion baked in.

`strengthen-query-properties-using-inference` (in `inference-strategist.lisp`) is the post-prepare adjustment that fixes a few cross-property invariants:
- If `transformation-allowed?` is nil on the store, force `max-transformation-depth` to 0 on the inference.
- If `:return` includes `:supports`, force `:answer-language :hl` (because supports are HL-side).
- Various `add-restriction-layer-of-indirection?` toggles based on whether the store is private and whether the query is single-literal.
- If `abduction-allowed?` on the store, force `result-uniqueness :proof`.

These are couplings between properties that are not enforced by the property catalogue itself — the rewrite should move them into a single `validate-and-normalise-properties` pass that runs once after extraction.

## Merging arithmetic

`inference-parameters.lisp` declares 30+ functions for property-set arithmetic, almost all `missing-larkc` in the LarKC port. The intent is captured by their names and the supporting deflexicals; the clean rewrite must implement them. They form three families:

### 1. Inclusion / merging
- `inference-merge-query-properties(p1, p2)` — combine two property sets. `*boolean-query-properties-to-include-on-merge*` (12 keys) lists which booleans are merged conservatively (true if true on either side); other properties use `inference-conservatively-select-property-value-for-merge`.
- `union-plist-properties(plist1, plist2)` — generic plist union.

### 2. Efficiency / completeness ordering
- `query-property-value-more-efficient?(prop, val1, val2)` — uses the `*query-properties-efficiency-hierarchy*` table (lower index = more efficient).
- `query-property-value-more-complete?(prop, val1, val2)` — opposite direction in the same table.
- `…at-least-as-efficient?`, `…at-least-as-complete?` — non-strict variants.
- `most-efficient-value-for-query-property(prop)`, `most-complete-value-for-query-property(prop)` — extreme of the table.
- `query-properties-more-efficient?(p1, p2)`, `…less-efficient?` — pairwise comparison summed across all properties.
- `most-efficient-query-properties(list)`, `most-complete-query-properties(list)` — Pareto extrema over a list of property sets.
- `least-efficient-query-properties(list)`, `least-complete-query-properties(list)` — opposite extrema.

### 3. Per-answer property attribution
- `inference-compute-all-answers-query-properties(inference)` — what properties produced ALL answers
- `inference-compute-some-answer-query-properties(inference)` — what properties produced AT LEAST ONE answer
- `inference-compute-proof-query-properties(proof)` — what properties produced this proof
- `inference-compute-inference-answer-query-properties(inference)` — per-answer breakdown
- `inference-answer-compute-…`, `proof-query-properties(proof, inference, properties)`, `compute-proof-query-properties-list(answer, properties)`

This third family is the substrate for Arete's analysis: given an inference that ran with mode `:maximal`, compute the *minimum* set of properties that would still have produced each particular answer. That tells you which queries were "easy" (efficient properties suffice) vs. "hard" (only maximal mode finds them). The clean rewrite needs this for any meaningful inference profiling.

### Numeric maxing-out

`*numeric-query-properties-that-max-out-at-positive-infinity*` lists three properties (`:max-problem-count`, `:productivity-limit`, `:removal-backtracking-productivity-limit`) where `:positive-infinity` is the saturation value. `numeric-query-property-max(property)` returns `:positive-infinity` for these and ordinary number maxes for the others.

`*proof-query-properties-to-override*` is the opposite: when generating a sub-query to compute a proof's properties, these are not gathered from the parent but always set fresh (`:intermediate-step-validation-level`, `:max-time`, `:max-step`, `:probably-approximately-done`, `:allow-indeterminate-results?`, `:answer-language`, `:bindings`).

## Problem-store reuse check

`problem-store-allows-reuse-wrt-query-properties?(store, properties)` is used when a caller passes `:problem-store` to reuse an existing store: the kernel checks that the store's policies are compatible with the new query's static properties (e.g. you cannot reuse a `:transformation-allowed? nil` store for a query that needs transformation). `problem-store-allows-reuse-wrt-query-property(store, prop, val)` is the per-property test. Both are `missing-larkc` in the LarKC port; the clean rewrite must implement them by checking that the store's value for each property is at least as permissive as the new query needs.

## When properties are read

To make the lifecycle concrete: the same property is read at very different moments depending on its category.

| Property category | Read at |
|---|---|
| problem-store static | `new-problem-store` (creation only) |
| inference static | `inference-set-static-properties` (creation only) |
| strategy static | `strategy-initialize-properties` (creation only); never reread |
| inference dynamic | `inference-update-dynamic-properties` (each `continue-inference`) |
| strategy dynamic | `strategy-update-properties` (each `continue-inference`) |
| `:metrics` | `inference-postprocess` (after each suspend) |
| `:return` and `:answer-language` | `inference-postprocess` (after each suspend); also strengthening at prep time |
| `:browsable?`, `:continuable?` | `new-cyc-query-int` cleanup decision |
| `:problem-store` | extracted by `inference-properties-problem-store` to decide private-vs-shared |

## Cross-system consumers

- **Kernel** (`inference-kernel.lisp`) — splits properties into static/dynamic, routes to subsystem initializers
- **Strategist** (`inference-strategist.lisp`) — `explicify-inference-mode-defaults`, `strengthen-query-properties-using-inference`
- **Datastructures inference/strategy/problem-store** — consume their respective extracted plists in `…-set-static-properties` / `…-update-dynamic-properties`
- **`inference-modules.lisp`** — `filter-modules-wrt-allowed-modules-spec` consumes the modules spec
- **`inference/ask-utilities.lisp`** — packages user-friendly entry points (`cyc-query`, `query`, `removal-ask`) as property-set defaults
- **`inference/inference-trampolines.lisp`** — older API entry points compose property sets for asent-style calls
- **`inference/arete.lisp`** — defines per-mode evaluation, calls `most-efficient-query-properties` / `most-complete-query-properties` over batches
- **Forward inference** (`inference/harness/forward.lisp`) — uses dedicated forward properties (`:forward-max-time`, `*forward-inference-allowed-rules*`)
- **TVA** (`tva-inference.lisp`) — composes its own property defaults for transitive-value queries

## Notes for the rewrite

- **One module, not two.** Merge `inference-parameters.lisp` and the property half of `inference-datastructures-enumerated-types.lisp` into one `query-properties` module. The split is not load-bearing.
- **Consider a typed properties record.** Instead of a plist, a struct with one field per property — Option types for nullable ones — gives validation for free and removes 30+ accessor functions. The cost is that `:allowed-modules` and `:metrics` and `:proof-spec` are still data-structured; they would be sub-records.
- **Inference modes as named presets.** Keep the table; consider making it user-extensible (a defmethod / register-mode hook) so callers can register their own clusters.
- **`merge-plist` semantics matter.** The user's explicit values must win over mode defaults; the inference-mode is the *floor*, not a *ceiling*. Keep this asymmetry.
- **`strengthen-query-properties-using-inference` is a normalisation step** that runs after extraction. Its effects are subtle (forcing `:hl` answer language when supports are requested, etc.). Make it a single explicit `normalise(properties)` function so the cross-property invariants are visible in one place.
- **`*inference-max-time-timeout-enabled?*` is a debug flag.** The "Temporary control variable" comment says it should always be on. Remove it in the clean rewrite.
- **Property-attribution functions (the third merging family) are the foundation of inference analytics.** Don't skip them. Without them, profiling and explanation cannot work.
- **`:positive-infinity` is the saturation value for three numeric properties** — it should be a concrete option-type variant (`Limit::Infinite | Limit::Finite(n)`) in the rewrite, not a magic keyword.
- **Some defaults are `defparameter` not `deflexical`** (e.g. `*rewrite-allowed-default?*`) so tests can rebind them. Keep this distinction — fixed defaults are `deflexical`/constant; rebindable defaults are parameters.
