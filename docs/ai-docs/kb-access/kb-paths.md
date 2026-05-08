# KB paths

KB-paths is a **graph-search system over the assertion graph**. Its job is to find paths in the KB connecting two terms — sequences of assertions where each step shares a term with the previous one — given a configurable set of node/link filters and budget bounds. The outputs are useful for justification reporting, term-relatedness scoring, conceptual-relation explanation, and exploratory KB browsing.

In the LarKC distribution this file is a **shell**. All ~85 declared functions are stripped of bodies — the only function with content is `fort-name`. What survives is the *configuration surface* — ~70 state variables defining how the search behaves — plus the file's CFASL state-variable registration. The clean rewrite reconstructs the search itself; the configuration shape is preserved as the API.

This document describes what the LarKC stub *was* and what the clean rewrite needs to be.

## When does kb-paths run?

Three triggering situations:

1. **A user (or external tool) asks "what connects A and B?"** Entry points `kb-paths source target &optional mt`, `kb-paths-n source target &optional mt`, `kb-paths-in-all-mts source target`, `kb-paths-in-just-mt source target mt`. Returns the configured `*kbp-result-format*` (`:paths`, `:links`, plus the kbp-result-* family).

2. **The conceptual-relations explanation engine cites kb-paths.** `explain-cr-pair`, `explain-cr-gafs-via-paths`, `explain-cr-gaf-via-paths` call into kb-paths to find a justifying chain when an inference module concludes "A and B are conceptually related." The four `*cr-*-count*` state variables track explanation statistics across a session.

3. **A justification or rendering pipeline asks for shortest-path examples.** `kbp-min-isa-paths`, `kbp-min-genls-paths`, `kbp-min-genl-mt-paths` — minimum-length paths under one of the structural relations.

The search is **bounded** by depth, term count, iteration count, and elapsed time. Without bounds the search would diverge through the densely-connected KB graph (Cyc has constants with thousands of mentions).

## What is a "path"?

A path is a sequence `[node link node link node …]` where:
- **Nodes** are FORTs by default (`*kbp-node?* = #'fort-p`). Individual searches can override.
- **Links** are assertions by default (`*kbp-link?* = #'assertion-p`). The default `*kbp-only-gaf-links?* = t` further restricts links to GAFs.
- Each consecutive node-link-node triple satisfies: the node is in the link's term-set, in the right argument position.

Paths are *bidirectional* in the sense that the search runs from both endpoints toward each other (the `*kbp-searchers*` machinery), meeting in the middle at common nodes.

## State variables — the configuration surface

The bulk of the file declares state variables via `def-kbp-state-var`, a thin wrapper around `def-state-var` that registers each variable with `*kbp-state-variables*`. This integration lets `with-kbp-state` (or analogous wrappers — actual macro is in `at-vars.lisp` style) snapshot and restore the search state, and lets `*fi-state-variables*`-style mechanisms export the configuration through the API.

Variables grouped by purpose:

### Result control

| Variable | Default | Meaning |
|---|---|---|
| `*kbp-quit?*` | nil | external-set flag to abort the search |
| `*kbp-result-format*` | `:paths` | what shape `kbp-result` returns: `:paths`, `:links`, possibly others |
| `*kbp-quit-with-success?*` | nil | when set, current state is treated as a successful termination |

### Node and link identity

| Variable | Default | Meaning |
|---|---|---|
| `*node-equal?*` | `#'eq` | equality test for nodes |
| `*kbp-node?*` | `#'fort-p` | predicate for "this object is a node" |
| `*kbp-link?*` | `#'assertion-p` | predicate for "this object is a link" |
| `*nodes-accessor-fn*` | nil | function returning the nodes of a link (defaults to assertion args by argument-position config) |
| `*source-term-args*` | `(1 2 3 4 5)` | argument positions in source-side links to follow |
| `*target-term-args*` | `(1 2 4 4 5)` | argument positions in target-side links to follow (note: 4 appears twice, no 3 — preserved from Java; either Cyc bug or a deliberate weighting) |

### Search dynamics

| Variable | Default | Meaning |
|---|---|---|
| `*search-iteration*` | nil | iteration counter |
| `*max-search-iterations*` | 5 | iteration budget |
| `*kbp-searcher*` | nil | currently active searcher (one of `*kbp-searchers*`) |
| `*kbp-searchers*` | nil | the searchers (typically two: source-side and target-side, walking toward each other) |
| `*path-source*` / `*path-target*` | nil | the search endpoints |
| `*path-horizon*` | nil | the unexplored frontier |
| `*kbp-common-nodes*` | nil | nodes both searchers have reached — meeting point candidates |
| `*kbp-ancestor*` | nil | scratch ancestor pointer during expansion |
| `*kbp-ancestor-hash*` | hash | ancestor relationships, equal-keyed, 2048 buckets |
| `*kbp-search-hash*` | hash | which nodes/links each searcher has visited |
| `*node-ancestors*` / `*link-ancestors*` | nil | per-iteration ancestor pointers |
| `*kbp-depth*` | nil | current depth |
| `*kbp-nodes*` / `*kbp-links*` | nil | accumulators |
| `*term-arg*` | nil | current term-arg position |
| `*relevant-node?*` / `*relevant-link?*` / `*relevant-link-tree?*` / `*relevant-node-tree?*` | (default fns) | per-step relevance gates |
| `*path-link-op*` / `*path-node-op*` | nil | per-step transformer functions (default-link-op, default-node-op) |

### Lattice / extraction state

| Variable | Default | Meaning |
|---|---|---|
| `*path-link-lattice*` / `*path-node-lattice*` | nil | DAGs of discovered links and nodes |
| `*kbp-stats*` / `*collect-kbp-stats?*` | nil/t | search statistics |
| `*kbp-node-count*` / `*kbp-link-count*` / `*kbp-term-count*` | nil | counters |
| `*kbp-run-time*` | nil | elapsed time |
| `*kbp-trace-level*` | 0 | verbosity for `kbp-note` / `kbp-error` / `kbp-warn` |

### Bounds and filters

The largest group — these gate the search to make it tractable:

| Variable | Default | Meaning |
|---|---|---|
| `*limit-path-depth?*` | t | apply max depth |
| `*kbp-max-depth*` | nil | depth cap |
| `*kbp-max-term-count*` | 1000 | total term-count cap |
| `*kbp-min-isa-path?*` / `*kbp-min-genls-path?*` | t | when computing min-length paths, restrict to isa/genls links |
| `*kbp-designated-node-superiors?*` / `*kbp-designated-node-superiors*` | t / nil | node-superior whitelist gate + list |
| `*kbp-only-gaf-links?*` | t | exclude rule assertions as links |
| `*kbp-no-bookkeeping-links?*` | t | exclude `myCreator`/`myCreationTime` etc. |
| `*kbp-no-instance-links?*` | t | exclude `#$isa` GAFs as links (would dominate the graph) |
| `*kbp-no-bi-scoping-links?*` | nil | exclude bi-scoping links |
| `*kbp-explode-nats?*` | nil | when t, treat NAUT internal terms as additional nodes |
| `*kbp-designated-preds?*` / `*kbp-designated-preds*` | t / nil | predicate-whitelist + list |
| `*kbp-restricted-preds?*` / `*kbp-restricted-preds*` | t / nil | predicate-blacklist + list |
| `*kbp-restricted-mts?*` / `*kbp-restricted-mts*` | nil / `(EnglishMt)` | MT-blacklist + list |
| `*kbp-external-link-pred?*` / `*kbp-external-link-pred*` | nil / nil | hook for foreign predicates (e.g. SKSI) |
| `*kbp-genl-bound?*` / `*kbp-genl-bound*` | t / nil | distance-from-root genl bound |
| `*kbp-genls-cardinality-delta-bound?*` | t | bound on changes in genls cardinality between steps |
| `*kbp-genls-cardinality-delta-bound*` | 20 | the actual cardinality-delta cutoff |
| `*kbp-isa-bound?*` / `*kbp-isa-bound*` | t / nil | bound for instance-of |
| `*kbp-node-isa-bound?*` / `*kbp-node-isa-bound*` | t / nil | per-node isa bound |
| `*kbp-restricted-nodes-as-arg?*` / `*kbp-restricted-nodes-as-arg*` | t / `((quotedCollection 1))` | nodes that may not appear at specified arg positions (default: `quotedCollection` may not be at arg1) |
| `*kbp-link-reference-set-bound?*` / `*kbp-link-reference-set-bound*` | t / nil | bound on link-reference-set size |
| `*kbp-designated-link-references?*` / `*kbp-designated-link-references*` | t / nil | link-reference whitelist |
| `*kbp-bound-gaf-terms?*` / `*kbp-bound-gaf-terms*` | t / `(0)` | which gaf term positions to keep bound (0 = predicate; conventionally we don't change the predicate as we walk a gaf-arg-link) |
| `*kbp-bound-link-terms?*` / `*kbp-bound-link-terms*` | t / nil | same for general links |
| `*kbp-use-max-mts?*` | nil | use max-mts (most-general MTs) for link relevance |
| `*exclude-nodes*` / `*exclude-links*` | nil / nil | per-search exclusion sets |

### Conceptual-relations support

| Variable | Default | Meaning |
|---|---|---|
| `*cr-paths-table*` | hash 1024 | cached paths from `explain-cr-pair` calls |
| `*cr-gaf-count*` | 0 | counter |
| `*cr-explained-count*` | 0 | counter |
| `*cr-error-count*` | 0 | counter |

## Implementation status

`fort-name` is the only function with a body:

```lisp
(defun fort-name (fort)
  (cond
    ((constant-p fort) (constant-name fort))
    ((nart-p fort) (missing-larkc 7493))   ; the NART branch is also stripped
    (t nil)))
```

Every other declared function is `;; (defun ... ...) -- commented declareFunction, no body`. The full set covers:

- **Public entry points**: `kb-paths`, `kb-paths-n`, `kb-paths-in-all-mts`, `kb-paths-in-just-mt`, `kbp-result`, `kbp-result-links`, `kbp-result-paths`, `kbp-min-isa-paths`, `kbp-min-genls-paths`, `kbp-min-genl-mt-paths`.
- **Search core**: `find-paths`, `complete-paths-home`, `complete-paths-home-from-link`, `complete-paths-home-from-node`, `extract-paths`, `linearize-lattice`, `gather-node-lattice`, `gather-link-lattice`, `mark-next-horizon`, `next-iteration`, `kbp-give-up?`, `kbp-exhausted?`, `kbp-iteration-bound-met?`, `kbp-term-bound-met?`.
- **Graph traversal**: `kbp-neighbors-among`, `kbp-node-links`, `kbp-link-nodes`, `kbp-connecting-links`, `kbp-node-neighbors`, `do-link-nodes`.
- **Legality / relevance**: `kbp-legal-link?`, `kbp-legal-node?`, `default-link-op`, `default-node-op`, `default-relevant-link?`, `default-relevant-node?`, `default-relevant-link-tree?`.
- **Bound checks**: `kbp-beyond-genls-cardinality-delta-bound?`, `kbp-beyond-genl-bound?`, `kbp-beyond-isa-bound?`, `kbp-undesignated-node-superior?`, `kbp-node-restricted-as-arg?`, `kbp-node-beyond-isa-bound?`, `kbp-gaf-term-beyond-bound?`, `kbp-undesignated-pred-assertion?`, `kbp-restricted-pred-assertion?`, `kbp-restricted-mt-assertion?`, `kbp-link-terms-beyond-reference-set-bound?`, `kbp-link-terms-w/o-references?`, `kbp-link-satisfies-external-pred?`, `kbp-link-term-beyond-bound?`, `kbp-link-w/o-max-mt?`, `kbp-bi-scoping-link?` (and `-1?`), `kbp-bi-scoping-node?` (and `-1?`).
- **Ancestry tracking**: `kbp-record-ancestor`, `kbp-ancestors`, `kbp-ancestors-via-all`, `kbp-ancestor?`, `kbp-ancestor-via-any?`, `kbp-searched?`, `kbp-searched-by?`, `kbp-searched-by-all?`, `kbp-searched-by-any?`, `kbp-searched-by`, `kbp-all-searched-by`, `kbp-mark-as-searched-by`, `kbp-mark-as-unsearched-by`, `kbp-mark-as-searched-by-all`, `kbp-mark-as-unsearched-by-all`, `kbp-mark-all-as-unsearched`, `kbp-mark-as-unsearched`, `kbp-all-searched-by-all`.
- **Stats / output**: `kbp-stats`, `kbp-node-count`, `kbp-link-count`, `kbp-searched-object-count`, `kbp-note`, `kbp-error`, `kbp-warn`, `paths-link-count`.
- **Misc**: `kbp-searcher?`, `equal-nodes?`, `instance-btree?`, `bookkeeping-btree?`, `bookkeeping-gaf-assertion?`, `kbp-excluded-node?`, `kbp-excluded-link?`, `kbp-paths-links`, `kbp-path-links`, `kbp-paths-tuples`, `kbp-path-tuples`, `kbp-justs-from-tuples`, `kbp-just-from-tuples`, `kbp-just-from-tuple`, `make-gaf-assertion`, `clear-kb-paths`.
- **Conceptual-relations explanation**: `explain-cr-pair`, `explain-cr-gafs-via-paths`, `explain-cr-gaf-via-paths`, `cr-paths-status`, `evaluate-cr-path`.
- **Comparison helpers**: `fort-name<`, `assertions-fi-equal?`, `assertions-fi-formulae`.
- **Focus / spec / genl helpers** (used in path scoring): `focuses`, `genls-gather-focus-preds-cols`, `remove-genls-of-all`, `remove-common-spec-path`, `remove-common-spec-path-wrt`, `remove-specs-of-all`, `remove-common-genl-path`, `remove-common-genl-path-wrt`, `candidate-focus-collections`, `candidate-focus-collections-strategy-middle`, `candidate-focus-collections-strategy-edge`, `appraise-candidate-focuses`, `genls-focus-min-preds`, `genls-gather-focus-preds-of`, `meta-pred-specs`.
- **Tree iteration helpers**: `do-if-term-assertions`, `obsolete-tree-do-if`, `assertion-indexed-by`, `all-assertion-terms`, `all-assertion-references`.

## Public API surface

```
;; Entry points
(kb-paths source target &optional mt)
(kb-paths-n source target &optional mt)
(kb-paths-in-all-mts source target)
(kb-paths-in-just-mt source target mt)
(find-paths &optional source target)

;; Min-length paths
(kbp-min-isa-paths source target &optional ...)
(kbp-min-genls-paths source target &optional ...)
(kbp-min-genl-mt-paths source target &optional ...)

;; Result
(kbp-result)
(kbp-result-links)
(kbp-result-paths)

;; Conceptual-relations explanations
(explain-cr-pair source target)
(explain-cr-gafs-via-paths &optional restrictor)
(explain-cr-gaf-via-paths gaf)
(cr-paths-status)
(evaluate-cr-path path source target &optional ...)

;; State management
(clear-kb-paths)
(kbp-stats searcher)
(kbp-node-count) (kbp-link-count)
(kbp-note level fmt &optional ...)
(kbp-error level fmt &optional ...)
(kbp-warn level fmt &optional ...)

;; Helpers
(fort-name fort)                    ; the only function with a body
(fort-name< f1 f2)
```

## Consumers (intent — bodies are missing)

| Consumer | What it would use |
|---|---|
| **Conceptual-relations explanation** (`#$conceptuallyRelated`) | `explain-cr-pair`, `explain-cr-gafs-via-paths` to justify CR conclusions |
| **Justification rendering** | `kb-paths-n` to find example chains for "why is A related to B?" |
| **KB browser / paraphrase** | `kbp-min-genls-paths` for taxonomy navigation |
| **Diagnostic tools** | `kb-paths-in-all-mts` to find unexpected connections |
| **Cyc API** | several entries are likely API-exposed in full Cyc |

## Notes for a clean rewrite

- **The configuration surface is well-shaped and worth preserving.** Two bidirectional searchers, ancestry tracking, multi-axis bounds (depth, term count, iterations, time, relevance, MT, predicate, sense, NAT-explosion), pluggable node/link predicates, lattice-based result extraction. Keep the variable names; rebuild the implementation.
- **The default `*target-term-args*` of `(1 2 4 4 5)`** — preserved from Java with the duplicated 4 — is suspicious. Either it's a bug that was never noticed (and the search slightly favors arg4 over arg3) or it's a tuned weighting. The clean rewrite should resolve this — either fix to `(1 2 3 4 5)` or document the weighting rationale.
- **Bidirectional search should be standard.** Two searchers walk from source and target toward each other; the meeting point is the path. Combined with depth-first lattice expansion and ancestry hashing, this gives roughly `O(B^(d/2))` instead of `O(B^d)` where B is the branching factor and d is path depth. Preserving the architecture from the variable shape makes this straightforward.
- **The bounds should be expressed declaratively.** `*kbp-genls-cardinality-delta-bound*` = 20 (the Cyc-tuned default) means "don't follow a step that increases the genls cardinality by more than 20." A clean rewrite has a per-step bound function returning a numeric cost, with a budget that decrements; the constants live in a config file.
- **NAT explosion (`*kbp-explode-nats?*`) is significant.** When walking through a NAUT like `(#$DateFn 2024 5 1)`, you can either treat the NAUT as an opaque atomic node, or *explode* it into nodes for the functor and each arg, with edges between them. The default off (false) prevents an explosion of nodes; the option-on path is needed for queries that care about, e.g., "what date connects these two events?"
- **Conceptual-relations integration is a load-bearing client.** `*cr-paths-table*` and the four counters track session-wide explanation work. The clean rewrite must preserve the ability to cache paths across multiple `explain-cr-pair` calls — recomputing from scratch is too expensive given Cyc's KB size.
- **The `*kbp-restricted-mts*` default is `(#$EnglishMt)`** — English-language assertions are excluded by default to avoid lexicon links dominating the search. This is a domain-specific choice that should be configurable, not hardcoded in the default state-var initialization.
- **`*kbp-restricted-nodes-as-arg*` default is `((#$quotedCollection 1))`** — `#$quotedCollection` may not appear at arg1 of a link. Another domain-specific choice; preserve as a tunable.
- **The Visitor / map / iteration helpers** (`do-if-term-assertions`, `obsolete-tree-do-if`, `all-assertion-terms`, etc.) are "iterate every term/reference in this assertion" walks. Modern designs use generic visitor protocols on assertion structure rather than file-local helpers.
- **`fort-name<` is missing** — it's the comparator for sort-stable path output. The clean rewrite uses `term-<` from `kb-utilities.lisp` (with constants-by-name). Probably duplicate; consolidate.
- **`make-gaf-assertion` is missing** — odd helper that wraps an assertion handle in a "for-display" structure. Fold into the path-rendering layer.
- **The state-variable plurality (~70 vars) is a smell.** Most of these are interrelated configuration fields of one search call. A clean rewrite uses a search-config struct passed explicitly, with a small ambient-context struct for the ancestor hash and stats. The dynamic-binding pattern stays only for re-entrancy with the rest of the engine (e.g. when a path-search itself triggers inference that needs to know we're inside one).
- **The whole module is missing-larkc-heavy** — the LarKC distribution of Cyc deliberately stripped path-search because it was a major source of complexity that the LarKC use-case (knowledge access) didn't need. The clean rewrite must reconstruct this from documentation and the variable shape; the Cyc proper version is the spec.
