# Inference modules (the registered HL modules)

The harness's vocabulary of *what kinds of inference can happen* is open-ended. New reasoning patterns are added by **declaring HL modules** — small, declarative records that describe when a tactic is applicable, how to compute its cost, and how to expand it. A query produces a list of candidate modules per literal; the strategist picks one (via tactics); the worker fires the module's `:expand` function. The HL module *is* the open-ended extension point that earlier docs have referenced as "the thousands of inference engines."

This document describes the module registry, the eight *kinds* of module (removal, conjunctive-removal, meta-removal, transformation, meta-transformation, rewrite, structural, meta-structural), and the catalogue of registered modules in `inference/modules/`. Forward modules, after-adding modules, simplification modules, and preference modules are also covered here — they share the same registration framework.

For *cost* and *productivity* arithmetic specifically, see "Removal module cost / formulas" doc. This doc covers everything else about modules.

Source files:
- `inference/harness/inference-modules.lisp` (1085) — the registry, struct, and core helpers
- `inference/modules/forward-modules.lisp` (1052) — forward inference modules
- `inference/modules/transformation-modules.lisp` (839) — transformation modules (rule-driven backward chaining)
- `inference/modules/preference-modules.lisp` (448) — preference modules (separate struct)
- `inference/modules/after-adding-modules.lisp` (304) — after-adding (forward-propagation) modules
- `inference/modules/simplification-modules.lisp` (216) — simplification modules
- `inference/modules/rewrite-modules.lisp` (215) — rewrite modules
- `inference/modules/removal/` (25 files, ~7000 lines) — the removal modules
  - `meta-removal-modules.lisp` (83) — meta-removal
  - 24 `removal-modules-X.lisp` files — one per reasoning pattern

## The HL module struct

```lisp
(defstruct (hl-module (:conc-name hl-mod-))
  name              ; the keyword identity
  plist             ; the property plist (the source of truth)
  ;; cached pre-computed slots, derived from plist:
  sense             ; :pos | :neg | nil
  predicate         ; the predicate atom this module services, or nil for generic
  any-predicates    ; pattern-list — module fires on any matching predicate
  arity             ; expected arity, or nil for any
  direction         ; :forward (within-forward-inference?) or backward
  required-pattern  ; pattern the asent must match
  required-mt       ; MT constraint
  exclusive-func    ; predicate that, if T, makes module exclusive
  required-func     ; predicate that, if T, makes module applicable
  completeness)     ; pre-computed completeness or nil for compute-on-demand
```

The cached slots are populated from the plist at registration time. The plist is the source of truth — the cached slots exist for fast dispatch on the hot path. The clean rewrite should treat them as a memoised view of the plist.

`*hl-module-store*` is a hashtable from name (keyword) to `hl-module` struct. `find-hl-module-by-name(name)` does the lookup. `add-hl-module` and `remove-hl-module` mutate the store.

Re-declaration is supported: `allocate-hl-module(name)` returns the existing module (clearing its plist for re-population) or mints a new one. This is essential for SLIME reload — modules redefined at the REPL update in place rather than accumulating duplicates.

## The 47 module properties

`*hl-module-properties*` lists every recognised property. They cluster by purpose:

### Identity
| Property | Purpose |
|---|---|
| `:module-type` | one of `:removal`, `:transformation`, `:rewrite`, `:meta-removal`, `:meta-transformation`, `:structural`, `:meta-structural`, `:removal-conjunctive`, `:storage`, `:forward`, `:after-adding`, `:simplification` |
| `:module-subtype` | `:kb` (default), `:sksi`, `:abduction` (specifies the source of the reasoning) |
| `:module-source` | optional source identifier (KB assertion that introduced the module) |
| `:pretty-name` | human-readable name |

### Applicability
| Property | Purpose |
|---|---|
| `:predicate` | atom or list — the predicate(s) this module services |
| `:any-predicates` | list of patterns — alternative match for predicate |
| `:every-predicates` | (conjunctive-removal only) all predicates must be present in the clause |
| `:arity` | expected arity of the asent, or nil for any |
| `:sense` | `:pos`, `:neg`, or nil for either |
| `:direction` | `:forward` or nil — whether usable in forward inference |
| `:required-pattern` | pattern the asent must match |
| `:required-mt` | MT keyword, FORT, or sexpr expression |
| `:applicability` | function-spec — additional dynamic applicability test |
| `:applicability-pattern` | pattern-language form — declarative applicability |
| `:exclusive` | function-spec — when T at runtime, module is exclusive |
| `:supplants` | `:all` (default) or list of module names that this module supplants when exclusive |
| `:required` | function-spec — additional required-condition check |

### Cost (see "Removal module cost / formulas" doc for arithmetic)
| Property | Purpose |
|---|---|
| `:cost-pattern` | pattern-formula whose result is the cost |
| `:cost-expression` | sexpr or symbol that evaluates to the cost |
| `:cost` | function-spec for cost computation |

### Completeness
| Property | Purpose |
|---|---|
| `:completeness` | constant `:complete | :incomplete | :grossly-incomplete | :impossible` |
| `:complete-pattern` | pattern that, if matched, guarantees `:complete` |
| `:completeness-pattern` | pattern-formula returning a completeness keyword |

### Execution
| Property | Purpose |
|---|---|
| `:expand` | function-spec — the worker function (default: pattern-driven) |
| `:expand-pattern` | declarative pattern (instead of `:expand`) |
| `:expand-iterative-pattern` | for iterative (resumable) modules |
| `:check` | `:unknown` (default; auto-detected) or boolean — whether module is a check vs. a generator |

### I/O patterns (declarative pattern language for expand functions)
| Property | Purpose |
|---|---|
| `:input-extract-pattern` | how to extract relevant input from the asent |
| `:input-verify-pattern` | how to validate the extracted input |
| `:input-encode-pattern` | how to encode for the underlying call |
| `:output-check-pattern` | how to check output validity |
| `:output-generate-pattern` | how to generate outputs |
| `:output-decode-pattern` | how to decode an output |
| `:output-verify-pattern` | how to verify a decoded output |
| `:output-construct-pattern` | how to build the supported asent from output |

### Rule selection (transformation modules)
| Property | Purpose |
|---|---|
| `:rule-select` | function-spec — pick rules to apply |
| `:rule-filter` | function-spec — filter pre-selected rules |

### Support generation (proofs)
| Property | Purpose |
|---|---|
| `:support-pattern` | pattern for hl-support construction |
| `:support` | function-spec for support computation |
| `:support-module` | `:opaque` (default) or named — which support flavour |
| `:support-mt` | the MT to attach to supports |
| `:support-strength` | `:default` or specific strength keyword |

### Rewrite-specific
| Property | Purpose |
|---|---|
| `:rewrite-closure` | function-spec — compute rewrite closure |
| `:rewrite-support` | how to attach support for rewrites |

### Storage modules (HL-modifiers, for assertion/retraction)
| Property | Purpose |
|---|---|
| `:argument-type` | which argument position this storage module operates on |
| `:incompleteness` | flag for incomplete storage |
| `:add` | function-spec for assertion |
| `:remove` | function-spec for retraction |
| `:remove-all` | function-spec for bulk retraction |

### Other
| Property | Purpose |
|---|---|
| `:external` | T = external module (lives in `*removal-modules-external*`) |
| `:universal` | T = applies to all predicates (lives in `*removal-modules-universal*`) |
| `:preferred-over` | list of module names this is preferred over |
| `:documentation` | docstring |
| `:example` | example query |

`hl-module-property-p` validates a property keyword. `*hl-module-property-defaults*` (a hashtable) maps each property to its default; `hl-module-property-without-values(module, property)` returns the explicit value or default.

`check-hl-module-property-list` validates a plist at registration:
- Every property must be in `*hl-module-properties*`
- `:supplants` is meaningless without `:exclusive`

## Eight module flavours

### Removal modules — `*removal-modules*`

Set of all backward-chaining literal-level modules. Used by literal-level removal tactics. The largest category. Subdivided by classification (see "Classification" below).

`inference-removal-module(name, plist)` declares one. `strengthen-removal-module-properties` requires `:sense` to be `:pos` or `:neg` — removal modules are sense-specific.

### Conjunctive removal modules — `*conjunctive-removal-modules*`

Modules that solve an entire conjunctive clause at once rather than literal-by-literal. Used by `:removal-conjunctive` tactics. Less common; live in `removal-modules-conjunctive-pruning.lisp`.

`inference-conjunctive-removal-module(name, plist)` declares one. Required properties documented at registration: `:every-predicates`, `:applicability`, `:cost`, `:expand` (uses `conjunctive-removal-callback` for each binding-list), `:documentation`, `:example`.

### Meta-removal modules — `*meta-removal-modules*`

Modules whose `:expand` produces *other tactics* on the same problem (rather than producing answers). They run before regular removal modules and can synthesise tactics dynamically. Used by `:meta-removal` tactics.

`inference-meta-removal-module(name, &optional plist)` declares one. The `meta-removal-completely-decidable-pos-required` and `meta-removal-completely-enumerable-pos-required` functions are example required-funcs that gate meta-removal.

`predicate-uses-meta-removal-module?(predicate, module)`: a predicate uses all meta-removal modules unless it is `solely-specific-removal-module-predicate?` and the meta-removal module hasn't been opted in via `inference-removal-module-use-meta-removal`. The clean rewrite should preserve this opt-in/opt-out structure — solely-specific predicates should not pull in unrelated meta-removal modules.

### Transformation modules — `*transformation-modules*`

Backward chaining via KB rules. Each rule fires one transformation module to produce a transformation tactic; the rule's antecedent becomes a subproblem. Modules in `transformation-modules.lisp`. The work is mostly mechanical — pull rules from the KB index, sort them by predicate-rule-preference, instantiate the antecedent.

`inference-transformation-module(name, plist)` declares one.

`modus-tollens-transformation-module-p(module)` = transformation module with `:sense :neg`. Modus tollens transformations chain backward through the *negation* of a rule's consequent.

### Meta-transformation modules — `*meta-transformation-modules*`

Like meta-removal, but for transformation: produce transformation tactics dynamically. The `*determine-new-transformation-tactics-module*` is the canonical instance — it's the meta-transformation module that sees a literal and produces all applicable concrete transformation tactics.

`inference-meta-transformation-module(name, &optional plist)` declares one.

### Rewrite modules — `*rewrite-modules*`

Syntactic rewrite of one literal into another. No proof obligation beyond the rewrite itself. Live in `rewrite-modules.lisp` (with `simplification-modules.lisp` as a sibling).

`inference-rewrite-module(name, plist)` declares one. `strengthen-rewrite-module-properties` requires `:sense` to be `:pos` or `:neg`.

### Structural modules — `*structural-modules*`

Modules for split/join/join-ordered/union/disjunctive-assumption. Five canonical instances minted at file load time, each via `inference-structural-module(:keyword, plist)`:
- `*split-module*` — the structural module for split tactics
- `*join-ordered-module*` — for join-ordered
- `*join-module*` — for join
- `*union-module*` — for union
- `*disjunction-assumption-module*` — for disjunctive-assumption

These are not the kind of "thousands of modules" that removal modules are; they are the fixed set of structural primitives.

### Meta-structural modules — `*meta-structural-modules*`

Meta-split modules, used for the `:meta-split` tactic that defers the split decision until later. Mostly the `*determine-new-tactics-module*`.

## Other module flavours (separate registries)

### Forward modules — `*forward-modules*`

Forward-direction modules (`forward-modules.lisp`). When an assertion is added, forward modules fire to propagate consequences. Registered via `inference-forward-module`. Their `:direction` property is `:forward`.

### After-adding modules — `*after-adding-modules*`

`after-adding-modules.lisp` — modules that fire after a new assertion is created (for KB-content-driven side effects). Registered via `inference-after-adding-module`. See "Forward propagation" doc in `kb-access/`.

### Simplification modules — `*simplification-modules*`

A *kind* of restriction module that fires early and propagates transformation motivation. Registered via `inference-simplification-module`. Used to handle algebraic simplifications (e.g. `0 + ?X → ?X`) without going through full transformation.

### Preference modules — separate `preference-module` struct

Preference modules are *not* HL modules — they have their own struct (`preference-module`) and registry (`*preference-modules-by-name*`). They contribute to a tactic's preference level wrt a literal.

```lisp
(defstruct preference-module
  name
  predicate any-predicates
  sense
  required-pattern
  required-mt
  preference-level    ; constant level
  preference-func)    ; function to compute level
```

`inference-preference-module(name, plist)` declares one. `preference-module-relevant?(prefmod, asent, sense, bindable-vars)` checks whether a preference module applies. `preference-module-compute-preference-level(prefmod, asent, bindable-vars, strategic-context)` returns the preference level.

The clean rewrite should consider folding preference modules into the HL module struct — they share most of the applicability machinery and only differ in what they output (a preference level vs. a tactic). The split is a port-time legacy.

## Removal module classification

A removal module falls into exactly one of four classification buckets, determined by `classify-removal-module(hl-module)`:

```
classify-removal-module(hl-module):
  if (hl-module-external? hl-module):
    add to *removal-modules-external*
  elif (hl-module-universal hl-module):
    add to *removal-modules-universal*
  else:
    let predicate-spec = hl-module-predicate(hl-module)
    if (null predicate-spec):
      add to *removal-modules-generic*
    elif (atom predicate-spec):
      add to *removal-modules-specific*[predicate-spec] (predicate → module set)
    else:
      for each predicate in predicate-spec:
        add to *removal-modules-specific*[predicate]
```

The four buckets:
1. **External** (`*removal-modules-external*`) — modules implemented outside the engine (SKSI for example). They get a fast-path because external dispatch is expensive.
2. **Universal** (`*removal-modules-universal*`) — apply to *every* predicate (with optional exclusion list). Examples: reflexivity, abduction.
3. **Generic** (`*removal-modules-generic*`) — no `:predicate`; applies broadly. Examples: pred-unbound (when the predicate is a variable).
4. **Predicate-specific** (`*removal-modules-specific*`) — has a `:predicate` keyword; applies only to that predicate.

### Cross-classification opt-ins

Three alists tweak the rules:

- `*removal-modules-specific-use-generic*` — alist `(generic-module . predicates)` saying "this generic module should also be used for these specific predicates" (overriding the default that generic modules are skipped when specific modules exist).
- `*removal-modules-specific-use-meta-removal*` — alist `(meta-removal-module . predicates)` opting specific-only predicates back into meta-removal.
- `*removal-modules-specific-dont-use-universal*` — alist `(universal-module . predicates)` opting predicates *out* of a universal module.

Plus `*solely-specific-removal-module-predicate-store*` — a set of predicates whose specific modules completely override generics. By default, a predicate uses both its specifics and the generics; registering it as solely-specific means *only* the specifics fire.

`reclassify-removal-modules()` rebuilds the classification from scratch (called when a module's properties change).

### Lookup at query time

When the strategist asks "what removal modules apply to this asent with this sense?", the worker (in `inference-worker-removal.lisp`) calls `literal-simple-removal-candidate-hl-modules(asent, sense)`:

1. If the predicate is a FORT, look up `*removal-modules-specific*[predicate]`, filter by sense
2. If solely-specific, that's the entire candidate set; otherwise add `*removal-modules-generic*` for that sense
3. Add `*removal-modules-universal*` for that sense, minus any in `*removal-modules-specific-dont-use-universal*` for this predicate
4. Apply `filter-modules-wrt-allowed-modules-spec(modules, allowed-modules-spec)` — the user's `:allowed-modules` query property

This is the dispatch tree:
```
Predicate-specific modules (always)
  ↓
+ Generic modules (unless solely-specific)
  ↓
+ Universal modules (minus opt-outs)
  ↓
- Filtered by user's :allowed-modules spec
```

## The `:allowed-modules` mini-language

The user's `:allowed-modules` query property accepts a tree-shaped spec to restrict which modules are usable. The grammar:

| Form | Match |
|---|---|
| `:all` | everything |
| `(:or s1 s2 …)` | union |
| `(:and s1 s2 …)` | intersection |
| `(:not s)` | complement |
| `(:module-type T)` | module's `:module-type` equals T |
| `(:module-subtype S)` | module's subtypes contains S |
| `(<property> V)` | module's property V matches (e.g. `(:sense :pos)`) |
| `<symbol>` | specific module by name |

`hl-module-allowed-by-allowed-modules-spec?(hl-module, spec)` is the matcher. `simple-allowed-modules-spec-p` checks whether a spec is a simple lookup that can short-circuit module enumeration; in that case `get-modules-from-simple-allowed-modules-spec(spec)` returns a list of modules directly.

There is also `hl-module-exclusive-func` short-circuiting in `filter-modules-wrt-allowed-modules-spec`: modules with an exclusive-func are kept regardless of the spec. The reasoning: an exclusive module that fires must short-circuit other reasoning, even if the user nominally restricted modules. The clean rewrite should consider whether this is correct semantics or a port-time accident.

## The 24 removal-module files

Each file in `inference/modules/removal/` registers one or more named removal modules. The naming convention is `:removal-<reasoning>-<sense>-<role>`:

| File | Modules registered | Reasoning pattern |
|---|---|---|
| `removal-modules-lookup.lisp` | `:removal-lookup-pos`, `:removal-lookup-neg`, `:removal-pred-unbound` | Direct GAF lookup in the KB |
| `removal-modules-isa.lisp` | `:removal-isa-collection-check-pos/neg`, `:removal-isa-defn-pos/neg`, `:removal-all-isa-pos`, `:removal-isa-naut-collection-*`, `:removal-not-isa-collection-check`, etc. | ISA inference (object/collection membership) |
| `removal-modules-genls.lisp` | `:removal-genls-*`, `:removal-not-genls-*`, `:removal-all-genls-*` | GENLS (collection subset) inference |
| `removal-modules-genlpreds.lisp` | `:removal-genl-predicates-*` | Predicate-generalisation inference |
| `removal-modules-genlpreds-lookup.lisp` | `:removal-genlpreds-lookup-*` | GENLS-of-predicate KB lookup |
| `removal-modules-evaluation.lisp` | `:removal-eval-*`, `:removal-evaluate-bind-*` | Built-in evaluation (compute answers algorithmically) |
| `removal-modules-natfunction.lisp` | `:removal-nat-formula-*`, `:removal-nat-lookup-*`, `:removal-nat-function-lookup-*`, `:removal-nat-argument-lookup-*` | Non-Atomic Term function evaluation |
| `removal-modules-reflexivity.lisp` | `:removal-reflexivity-*` | X = X inference |
| `removal-modules-symmetry.lisp` | `:removal-symmetry-*` | R(X,Y) from R(Y,X) |
| `removal-modules-transitivity.lisp` | `:removal-transitivity-*` | Transitive relation inference |
| `removal-modules-different.lisp` | `:removal-different-*` | Inequality |
| `removal-modules-reflexive-on.lisp` | `:removal-reflexive-on-*` | reflexive-on relation |
| `removal-modules-tva-lookup.lisp` | `:removal-tva-lookup-*`, `:removal-tva-check-*` | Truth Value Assignment lookup |
| `removal-modules-abduction.lisp` | `:removal-abduction-pos/neg-check`, `:removal-abduction-pos/neg-unify`, `:removal-exclusive-abduction-pos/neg` | Abductive reasoning (assume the goal) |
| `removal-modules-backchain-required.lisp` | `:removal-backchain-required-*` | Backchaining required predicates |
| `removal-modules-asserted-formula.lisp` | `:removal-asserted-formula-*`, `:removal-asserted-term-sentences-arg-index-unify` | Asserted-formula lookup |
| `removal-modules-indexical-referent.lisp` | `:removal-indexical-referent-*` | Indexical (`#$Now`, `#$Here`) resolution |
| `removal-modules-function-corresponding-predicate.lisp` | `:removal-fcp-*` | Function↔predicate correspondence |
| `removal-modules-conjunctive-pruning.lisp` | conjunctive-removal modules for pruning | Multi-literal pruning |
| `removal-modules-relation-all.lisp` | `:removal-relation-all-*` | `(forAll R (...))` |
| `removal-modules-relation-all-instance.lisp` | `:removal-relation-all-instance-*` | `(forAll R-instance ...)` |
| `removal-modules-relation-all-exists.lisp` | `:removal-relation-all-exists-*` | `(forAll ... (thereExists ...))` |
| `removal-modules-relation-instance-exists.lisp` | `:removal-relation-instance-exists-*` | `(thereExists ... ?-instance)` |
| `removal-modules-termofunit.lisp` | `:removal-termofunit-*` | NART/term-of-unit lookup |
| `meta-removal-modules.lisp` | `:meta-removal-completely-decidable-pos`, `:meta-removal-completely-enumerable-pos` | Meta-removal: solving via known KB completeness |

Each registration is a `(toplevel ...)` form at the bottom of its file. Example from `removal-modules-lookup.lisp`:

```lisp
(toplevel
  (inference-removal-module :removal-lookup-pos
    (list :sense :pos
          :arity nil
          :required-pattern (cons :fort :anything)
          :cost 'removal-lookup-pos-cost
          :complete-pattern (list :test 'removal-completely-asserted-asent?)
          :input-extract-pattern (list :template (list :bind 'asent) (list :value 'asent))
          :output-generate-pattern (list :call 'removal-lookup-pos-iterator :input)
          :output-decode-pattern (list :template (list :bind 'assertion) (list :value 'assertion))
          :output-construct-pattern (list :call 'gaf-formula :input)
          :support-pattern (list (list :value 'assertion))
          :documentation "(<fort> . <whatever>) using true assertions and GAF indexing in the KB"
          :example "(#$bordersOn #$UnitedStatesOfAmerica ?COUNTRY)
                   (#$bordersOn #$UnitedStatesOfAmerica #$Canada)")))
```

The properties cluster:
- `:sense :pos` and `:arity nil` and `:required-pattern (cons :fort :anything)` — applicability constraints
- `:cost 'removal-lookup-pos-cost` — function reference for cost
- `:complete-pattern (list :test ...)` — if the asent is completely asserted, this module is `:complete`
- `:input-extract-pattern`, `:output-generate-pattern`, etc. — declarative I/O patterns

## The pattern language

Many modules use a *pattern* (sometimes called template) to specify their I/O without writing imperative code. The pattern grammar (used in `:complete-pattern`, `:cost-pattern`, `:input-extract-pattern`, `:output-generate-pattern`, etc.):

| Form | Meaning |
|---|---|
| `:anything` | matches/produces anything |
| `:input` | the input value |
| `(:bind <var> <pattern>)` | binds value to var |
| `(:value <var>)` | reads from a var |
| `(:test <fn>)` | calls fn to test |
| `(:call <fn> <args>...)` | calls fn with args |
| `(:template <bind-pat> <value-pat>)` | a binding template |
| `(:not <subpattern>)` | negation |
| `(:and <subpat>...)`, `(:or <subpat>...)` | conjunction/disjunction |

`pattern-matches-formula-without-bindings(pattern, formula)`, `pattern-transform-formula(pattern, formula)`, and `formula-matches-pattern(formula, pattern)` are the matchers/transformers. The clean rewrite should keep the pattern language — declarative module specs are much more maintainable than imperative `:expand` functions.

## CFASL serialisation

HL modules can be CFASL-serialised: `*cfasl-wide-opcode-hl-module*` is opcode 256, registered via `register-wide-cfasl-opcode-input-function`. `cfasl-output-object-hl-module-method` and `cfasl-input-hl-module` round-trip a module by name (the recipient looks up the module in its local store; a missing module is an error).

## When does a module fire?

The lifecycle of a module's applicability:

1. **Registration** (file load time) — `(toplevel ...)` form at the bottom of a module file calls `inference-removal-module(name, plist)` (or the appropriate flavour). The module is added to its registry and classified.
2. **Reclassification** — if the property table changes (rare), `reclassify-removal-modules()` rebuilds the classification. The clean rewrite should make this automatic on property change.
3. **Lookup at query time** — when `determine-new-literal-removal-tactics(problem, asent, sense)` runs for a new problem's literal, it gathers candidate modules from the registries.
4. **Applicability filtering** — `hl-module-applicable-to-asent?(module, asent)` runs five checks (predicate-relevant, arity-relevant, required-pattern-matched, required-mt-relevant, direction-relevant). Only applicable modules survive.
5. **Exclusivity** — modules with `:exclusive-func` may supplant others; a totally-exclusive module short-circuits the search.
6. **Required-func** — module's `:required-func` runs as a final gate.
7. **Tactic creation** — for each surviving module, a tactic is created via `new-removal-tactic(problem, hl-module, productivity, completeness)`.
8. **Tactic execution** — strategist picks the tactic; worker calls module's `:expand` function via the dispatch tables.
9. **Result registration** — the `:expand` function calls `removal-add-node(hl-support)` (or similar) for each result, which becomes a removal-link → proof.

## Hot-path module dispatch tables

The `removal-module-exclusive-func-funcall`, `removal-module-required-func-funcall`, and `removal-module-expand-func-funcall` (in `inference-worker-removal.lisp`) are *switch tables* mapping symbolic function names to actual Lisp functions. Each branch is a hardcoded `(eq func 'name)` dispatch. When the func is not in the table, fallback to `possibly-cyc-api-funcall-2(func, asent, sense)` which does a string-keyed API lookup.

The reason this exists: SubL allowed function-spec strings to be looked up at runtime by name. The Lisp port preserves this by hardcoding the table. The clean rewrite should replace the table with direct function references stored on the HL module (`'<name>` → `#'<name>` at registration time). This eliminates the runtime dispatch and is more lispy.

The same pattern exists for transformation modules (in `inference-worker-transformation.lisp`).

## Cross-system consumers

- **Inference workers** (`inference-worker-*.lisp`) call `*-modules-for-sense`, `hl-module-applicable-to-asent?`, `hl-module-cost`, etc. They are the primary consumers.
- **Strategist** uses `hl-module-completeness` and `hl-module-active?` for filtering tactics.
- **Argumentation** (`argumentation.lisp`) reads the `:support-pattern`, `:support-mt`, and `:support-strength` to render explanations.
- **Inference analysis** (`inference-analysis.lisp`) tracks per-module success counts via `cinc-module-expand-count`.
- **Forward inference / after-adding** uses the same hl-module struct via separate registries.
- **CFASL** serialises and deserialises modules by name.
- **HL storage modules** (`hl-storage-modules.lisp`) — for assertion/retraction — share the struct but with `:storage` module-type and `:add`/`:remove` properties instead of `:expand`.

## Notes for the rewrite

- **Property plist is the source of truth; cached slots are a view.** Keep this distinction. The cached slots make the hot path fast; the plist is what the registration writes and what gets serialised.
- **Module registries should be per-flavour.** Don't try to unify all modules into one mega-store; the dispatch is keyed on flavour first.
- **Replace function-spec dispatch tables with direct function references.** At registration time, resolve `'<name>` to `#'<name>` and store the function reference directly.
- **The pattern language is declarative — keep it.** Use it as the default `:expand`; only fall back to `:expand` function for irregular cases. Imperative `:expand` is the escape hatch.
- **Solely-specific predicates** are an opt-in pattern that overrides the default "specific + generic" behaviour. Keep this; some predicates legitimately want to disable generic fallback.
- **The 24 removal-module files** each correspond to a distinct reasoning pattern. Don't fold them — the file structure helps maintainability.
- **Forward modules and after-adding modules** are different flavours but share the framework. Keep them as separate registries with shared infrastructure.
- **Preference modules are a separate struct.** Consider whether to fold them into hl-module — the split is historical; in the clean rewrite they could be `(module-type :preference)` modules with a `:preference-level` property and a `:preference-func`.
- **Universal modules with exception lists** (`*removal-modules-specific-dont-use-universal*`) are an opt-out pattern. Keep this; some predicates have semantics incompatible with universal modules.
- **Module CFASL serialisation by name** is critical for cross-image compatibility. The clean rewrite must keep "module identity = its name" as the cross-image invariant.
- **Re-declaration support** matters for SLIME/REPL workflows. `inference-preference-module` already does deregister-and-recreate; the clean rewrite should make this the consistent behaviour for all module flavours.
- **`:exclusive` short-circuits other modules.** This is essential for correctness — e.g. an exclusive abduction module should prevent a regular removal from firing on the same asent. Make sure the rewrite preserves this.
- **`:supplants` defaults to `:all`.** Without `:supplants`, an exclusive module supplants every other module that matched. With `:supplants <list>`, it supplants only the named ones. Keep this fine-grained control.
- **Module `:direction` defaults to `:forward`.** This seems wrong (most modules are usable in both directions), but it is what the registry defaults to. The clean rewrite should re-examine this; the within-forward-inference? gate is what enforces the actual restriction.
