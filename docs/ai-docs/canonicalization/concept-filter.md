# Concept filter

A **concept filter** is a *KB-driven query restriction* — a way to scope an inference to a particular taxonomic subset of the KB without changing the inference itself. The user (or downstream tool) declares "I only care about concepts in this taxonomy" and the engine restricts its search accordingly.

Filters are KB objects: instances of `#$ConceptFilter` (or specialised subclasses like `#$DecisionTreeConceptFilter`). Each filter has a *specification* (instance of `#$ConceptFilterSpecification`) that gives its parameters. The default filter is `#$TaxonomyOfEasilyUnderstandableConcepts`.

The system is mostly missing-larkc in the LarKC port — only the variables, two memoization macros, and the registration scaffolding survive. The clean rewrite must reconstruct from the function names and orphan-constant evidence.

Source file: `larkc-cycl/concept-filter.lisp` (260 lines, almost entirely missing-larkc)

## What does a concept filter restrict?

A filter restricts which *concepts* are visible:
- **Specified nodes** — concepts asserted as `(nodeInSystem <node> <filter>)` — explicitly part of the filter
- **Organising nodes** — concepts asserted as `(classifyingNodeInFilter <node> <filter>)` — used as classification keys
- **Suppressed nodes** — concepts asserted as `(suppressIndividualNode <node> <filter>)` — explicitly excluded

The filter's *defining MT* (`conceptFilterSpecificationDefiningMt`) controls which MT relevance frame the filter uses. Different filters can produce different views of the KB.

## When does a filter fire?

A filter is consulted whenever:
- A query needs to know "is this concept in scope?"
- A node enumeration needs to be filtered to a particular taxonomy
- A KB editor wants to show only relevant concepts

The dispatch is per-concept: `specified-node-in-filter?`, `node-suppressed-from-filter?`, `organizing-node-for-filter?`.

## Variables

```
*concept-filter-default-mt* = #$InferencePSC
  ; default MT for semantic tests when no MT is specified

*default-concept-filter* = #$TaxonomyOfEasilyUnderstandableConcepts
  ; the default filter

*default-concept-filter-specification* = nil
  ; default specification (computed lazily)

*concept-filter-memoization-state* = nil
  ; per-call memoization state
```

## Memoization scoping

Two macros set up memoization context:

```lisp
(with-new-concept-filter-memoization-state
  ...body...)
```

Establishes a fresh memoization state for the body. Multiple concept-filter operations in the body share the cache.

```lisp
(with-concept-filter-memoization-state
  ...body...)
```

Uses the *current* memoization state (assumes one is already set up).

The pattern is the standard "scoped memoization" pattern used elsewhere in Clyc.

## Specification structure

A concept-filter specification is a NAUT of the form:

```
(ConceptFilterSpecificationFn <filter> <trigger> <mode>)
```

or with explicit MT:

```
(ConceptFilterSpecificationWithMtFn <filter> <trigger> <mode> <mt>)
```

The components:
- `<filter>` — the concept filter (e.g. `#$TaxonomyOfEasilyUnderstandableConcepts`)
- `<trigger>` — what triggers the filter; e.g. `#$TriggerFromConcept`
- `<mode>` — filter mode parameter; e.g. `#$ConceptOnlyFilterParameter`, `#$ConceptAndInstancesFilterParameter`
- `<mt>` — defining MT (optional; falls back to filter's own defining MT)

`decompose-concept-filter-spec(spec, &optional mt)` parses a specification into its components. The function is `defun-cached` for performance; specs are immutable so caching is safe.

## Cached functions

Several functions follow the "globally-cached" pattern: a function plus its caching-state variable plus clear/remove operations. All five families:

### `concept-filter-specification-p` (predicate)

Cached via `*concept-filter-specification-p-caching-state*`. Tests whether an object is a valid filter specification. The shape:

```
(and (possibly-naut-p object)
     (eq #$ConceptFilterSpecificationFn (nat-functor object))
     (or (= 3 (nat-arity object))  ; no MT
         (= 4 (nat-arity object))) ; with MT
     (concept-filter? (nat-arg1 object))
     (member (nat-arg3 object) '(#$ConceptOnlyFilterParameter
                                  #$TriggerFromConcept ...)))
```

Cache size 50 entries (`$int11$50`). Cleared on KB change.

### `concept-filter-all-isa(term, mt)`

Cached via `*concept-filter-all-isa-caching-state*`. Returns the list of all isa-collections for `term` that are nodes in any concept filter.

Cache size 500 entries (`$int21$500`).

### `specified-nodes-in-filter(concept-filter, mt)`

Cached. Returns the list of nodes asserted as `(nodeInSystem <node> <concept-filter>)` in `mt`.

The implementation walks the KB query for `(nodeInSystem ?N <filter>)` GAFs in the relevant MT and returns the bound `?N` values.

`specified-nodes-in-filter-cached-p(concept-filter, mt)` — predicate: is the result cached?

`specified-node-in-filter?(node, &optional concept-filter, mt)` — direct membership check.

### `nodes-suppressed-from-filter(concept-filter, mt)`

Cached. Returns nodes asserted as `(suppressIndividualNode <node> <concept-filter>)`.

`node-suppressed-from-filter?(node, concept-filter, mt)` — direct check.

### `organizing-nodes-for-filter(concept-filter, mt)`

Cached. Returns nodes asserted as `(classifyingNodeInFilter <node> <concept-filter>)` — the *organising* nodes used as classification keys.

`organizing-node-for-filter?(node, &optional concept-filter, mt)` — direct check.

### `filter-defn(concept-filter, defn-type)`

Cached. Returns the *defn* for the filter with the given `defn-type`. Used to compute the definition of "what's in this filter" — typically returns a function that decides membership for a given term.

The `defn-type` keyword discriminates: `:bad-for-tagging-defn`, `:predicate-filter-tagging-defn`, etc.

### `bad-for-tagging?(term, &optional concept-filter)`

Cached. Predicate: should `term` be excluded from concept-tagging? Used to skip tagging operations on terms that are noisy or irrelevant.

The implementation likely checks if `term` is one of `#$InstanceNamedFn`, `#$InstanceNamedFn-Ternary`, `#$ThingDescribableAsFn`, `#$Kappa` (the orphan constant `$list66`).

### `valid-concept-filter-nodes(concept-filter, &optional mt)`

The aggregated query: combine specified-nodes + organising-nodes minus suppressed-nodes, possibly extended by `concept-filter-all-isa` lookups.

Memoised via `valid-concept-filter-nodes-memoized` (state-dependent). The destructuring pattern (orphan `$list70`) is `(CONCEPT-FILTER ALLOW-SPECS ALLOW-INSTANCES RETURN-INSTANCES MT)` — the cache key includes options for whether to include specs, instances, and what to return.

## Adhoc filter creation

```
new-adhoc-concept-filter-spec(collection, &optional mt)
new-adhoc-isa-concept-filter-spec(collection, &optional mt)
new-adhoc-genls-concept-filter-spec(collection, &optional mt)
```

Three constructors for *ad hoc* concept filters: filter to instances/genls of a specific collection. Used when the caller wants a one-off filter without persisting a `ConceptFilter` constant in the KB.

The shape (from orphan constants):
```
;; new-adhoc-isa-concept-filter-spec → 
(ConceptFilterSpecificationFn (isa-collection-? collection)
                              ConceptOnlyFilterParameter
                              TriggerFromConcept)
```

`isa-collection-?` is the predicate "is the term an instance of collection?"; the constructor wraps this as a synthetic filter.

`new-adhoc-genls-concept-filter-spec` is similar but for genls-of-collection.

These are registered as `register-external-symbol` — public Cyc API.

## After-adding hooks

```
nodes-for-concept-filter-after-adding(argument, assertion)
nodes-for-concept-filter-after-removing(argument, assertion)
```

Registered as KB functions via `register-kb-function`. Triggered when a concept-filter-related GAF is added or removed (e.g. a new `(nodeInSystem ...)` assertion). The hook updates the cached node sets.

## Decision-tree filters

`decision-tree-filter?(concept-filter)` (missing-larkc) — predicate: is this filter a `#$DecisionTreeConceptFilter` (orphan `$const55$DecisionTreeConceptFilter`)?

A decision-tree filter has *implicit* node membership computed via a decision-tree algorithm rather than enumerated assertions. The filter's `:filter-defn` returns a tree-walker function.

`complete-extent-should-be-queried-from-kb?(concept-filter)` (missing-larkc) — does this filter require a full KB extent query? Used to decide between fast-path (cached extent) and slow-path (live KB query).

## When does each piece fire?

| Trigger | Path |
|---|---|
| User runs query with `:concept-filter` set | The inference engine consults the filter for each candidate term |
| KE displays a concept browser | `specified-nodes-in-filter` for the filter being browsed |
| Filter membership check | `specified-node-in-filter?` / `node-suppressed-from-filter?` |
| New filter-related GAF asserted | `nodes-for-concept-filter-after-adding` invalidates caches |
| Concept-tagging | `bad-for-tagging?` filters out noise |

## Cross-system consumers

- **Inference engine** — queries can specify a concept filter; the filter restricts the search space
- **KE** — concept browsers use filters to scope what's shown
- **NL generation** — filtering by easily-understood concepts (the default filter)
- **Concept tagging** — `bad-for-tagging?` excludes noisy concepts
- **Argumentation** — filtering proof support to relevant concepts only

## Notes for the rewrite

- **Concept filters are KB-driven views.** The KB defines what's in each filter; the engine just enumerates and caches. Don't try to make filters code-defined; the KB-driven approach is what makes them flexible.
- **The four cached functions** (`specified-nodes-in-filter`, `nodes-suppressed-from-filter`, `organizing-nodes-for-filter`, `concept-filter-all-isa`) all follow the same pattern: KB lookup with a per-filter cache. The rewrite should consolidate the cache-management code.
- **`bad-for-tagging?`** has a hardcoded list of "bad" functors (`#$InstanceNamedFn`, etc.). Keep this list KB-tunable; new bad functors might emerge.
- **`new-adhoc-*-concept-filter-spec`** are the ad-hoc constructors. Useful for one-off filters; keep them. The clean rewrite should consider whether to make every filter ad-hoc by default (no need for KB-persistence unless requested).
- **Decision-tree filters** are a special subclass with computed (not enumerated) membership. Implement carefully; the decision-tree algorithm is its own subsystem.
- **Most functions are missing-larkc.** The shape:
  - The predicates do KB lookups (e.g. `(nodeInSystem ?N <filter>)`) and check membership
  - The cached wrappers do the standard cache-state pattern
  - The decompose function parses NAUT structure into filter components
  - The defn function looks up the filter's defining function
  The clean rewrite must reconstruct all of these from KB query patterns.
- **The `:bad-for-tagging-defn` and `:predicate-filter-tagging-defn` defn-types** are filter-specific defn varieties. Keep this generality; new defn-types may be added by KB authors.
- **Memoisation is essential.** Filter membership is queried many times per inference; without caching, every query would do KB lookups. Don't disable; the cache is small (500 entries for `concept-filter-all-isa`).
- **`*concept-filter-default-mt* = #$InferencePSC`** — the default MT. Production setting; keep this.
- **`*default-concept-filter* = #$TaxonomyOfEasilyUnderstandableConcepts`** — the default filter. This is a Cyc-specific default; a different KB might want a different default. Keep this configurable.
- **The after-adding/after-removing hooks** are registered as KB functions. They're how the filter caches stay consistent with KB updates. Keep this; without it, asserting `(nodeInSystem ...)` wouldn't take effect until the next image restart.
- **External symbol registration** — `new-adhoc-concept-filter-spec` and friends are registered for external API. Keep this; downstream tools call these.
