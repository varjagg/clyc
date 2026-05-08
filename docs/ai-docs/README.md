# Clyc Clean Codebase Documentation

This directory contains system-by-system writeups intended to support a future clean rewrite of Clyc. The goal is **total coverage of how each system is used in Cyc**, captured at the level needed to reimplement it in a modern codebase. The notes deliberately avoid LarKC/SubL idioms when they aren't load-bearing — they exist to brief a reimplementer, not to mirror the port.

This README is the **index** of what's in the directory: the categorical taxonomy, the doc that covers each system, and the `larkc-cycl/*.lisp` source files that system spans. Docs live in subdirectories named after their category.

## What's covered, what isn't

A "system" doc here describes:
- The **data structures** the system owns (with field semantics, invariants, lifecycle).
- The **public API** (what other systems are supposed to call).
- **How other systems consume it** — the use sites and patterns of use, with enough detail that a rewrite knows what surface area to keep.
- **Serialization (CFASL)** registration and round-trip protocol, where applicable.
- **Deprecation / refactor flags** the user has called out (e.g. `dictionary` → native CL hash, `set-contents` → `set`).

A doc here is **not**:
- A line-by-line description of the Lisp port. The port is the source of truth for the *current* implementation; this doc is the spec for a *future* one.
- A reproduction of `readme.md`'s glossary. Read that first; these docs assume it.
- An ultra-deep technical spec for the low-level utility containers (`set`, `dictionary`, `queue`, `binary-tree`, etc.) — those are flagged for native-CL replacement and only need their API surface and consumer story captured.

## Cross-cutting

| Doc | Purpose |
|---|---|
| [ideas.md](ideas.md) | Scratchpad for cross-cutting design ideas (e.g. inline page-in slots replacing the LRU hashtable). |

## Index

Source files are paths under `larkc-cycl/`.

### Core KB systems — [core-kb/](core-kb/)

| System | Doc | Source files |
|---|---|---|
| Constants | [core-kb/constants.md](core-kb/constants.md) | `constant-handles.lisp`, `constants-low.lisp`, `constants-high.lisp`, `constants-interface.lisp`, `constant-index-manager.lisp`, `constant-completion.lisp`, `constant-completion-high.lisp`, `constant-completion-interface.lisp`, `constant-completion-low.lisp`, `constant-reader.lisp` |
| NARTs (and NAUTs) | [core-kb/narts.md](core-kb/narts.md) | `nart-handles.lisp`, `narts-high.lisp`, `nart-hl-formula-manager.lisp`, `nart-index-manager.lisp`, `function-terms.lisp` |
| Functions and function terms | [core-kb/functions.md](core-kb/functions.md) | `fort-types-interface.lisp`, `arity.lisp`, `relation-evaluation.lisp`, `function-terms.lisp`, `term.lisp`, `el-utilities.lisp`, `czer-utilities.lisp`, `skolems.lisp` |
| Variables (HL, EL, TL) | [core-kb/variables.md](core-kb/variables.md) | `variables.lisp`, `cycl-variables.lisp`, `canon-tl.lisp`, `control-vars.lisp`, `kb-utilities.lisp`, `cfasl-kb-methods.lisp`, `arg-type.lisp` |
| FORTs (Constant ∪ NART) | [core-kb/forts.md](core-kb/forts.md) | `forts.lisp`, `fort-types-interface.lisp` |
| Microtheories (MT) | [core-kb/microtheories.md](core-kb/microtheories.md) | `mt-vars.lisp`, `mt-relevance-macros.lisp`, `mt-relevance-cache.lisp`, `genl-mts.lisp`, `hlmt.lisp`, `hlmt-czer.lisp`, `psc.lisp` |
| Assertions | [core-kb/assertions.md](core-kb/assertions.md) | `assertion-handles.lisp`, `assertions-low.lisp`, `assertions-high.lisp`, `assertions-interface.lisp`, `assertion-utilities.lisp`, `assertion-manager.lisp` |
| Deductions | [core-kb/deductions.md](core-kb/deductions.md) | `deduction-handles.lisp`, `deductions-low.lisp`, `deductions-high.lisp`, `deductions-interface.lisp`, `deduction-manager.lisp` |
| HL-supports & KB-HL-supports | [core-kb/kb-hl-supports.md](core-kb/kb-hl-supports.md) | `hl-supports.lisp`, `kb-hl-supports.lisp`, `kb-hl-support-manager.lisp` |
| Arguments and supports (justification polymorphism) | [core-kb/arguments.md](core-kb/arguments.md) | `arguments.lisp` |
| Clauses, CNF, DNF, clause-strucs | [core-kb/clauses.md](core-kb/clauses.md) | `clauses.lisp`, `clause-utilities.lisp`, `clause-strucs.lisp`, `clausifier.lisp` |

### KB indexing & access — [kb-access/](kb-access/)

| System | Doc | Source files |
|---|---|---|
| KB indexing | [kb-access/kb-indexing.md](kb-access/kb-indexing.md) | `kb-indexing.lisp`, `kb-indexing-datastructures.lisp`, `kb-indexing-declarations.lisp`, `kb-indexing-macros.lisp` |
| KB mapping (do-X-for-term iterators) | [kb-access/kb-mapping.md](kb-access/kb-mapping.md) | `kb-mapping.lisp`, `kb-mapping-utilities.lisp`, `kb-mapping-macros.lisp`, `kb-gp-mapping.lisp` |
| KB accessors and macros | [kb-access/kb-accessors.md](kb-access/kb-accessors.md) | `kb-accessors.lisp`, `kb-macros.lisp`, `kb-utilities.lisp`, `kb-control-vars.lisp`, `kb-compare.lisp` |
| Auxiliary indexing | [kb-access/auxiliary-indexing.md](kb-access/auxiliary-indexing.md) | `auxiliary-indexing.lisp`, `simple-indexing.lisp`, `virtual-indexing.lisp` |
| KB paths (graph paths) | [kb-access/kb-paths.md](kb-access/kb-paths.md) | `kb-paths.lisp` |
| KB object manager (LRU + on-disk file-vector) | [kb-access/kb-object-manager.md](kb-access/kb-object-manager.md) | `kb-object-manager.lisp`, `kb-access-metering.lisp` |
| HL modifiers (mutation gateway, locking) | [kb-access/hl-modifiers.md](kb-access/hl-modifiers.md) | `hl-modifiers.lisp`, `hl-interface-infrastructure.lisp`, `hl-storage-modules.lisp`, `hl-storage-module-declarations.lisp` |
| Bookkeeping store | [kb-access/bookkeeping-store.md](kb-access/bookkeeping-store.md) | `bookkeeping-store.lisp`, `cyc-bookkeeping.lisp` |
| TMS (truth maintenance) | [kb-access/tms.md](kb-access/tms.md) | `tms.lisp` |
| Forward propagation (after-adding) | [kb-access/forward-propagation.md](kb-access/forward-propagation.md) | `inference/harness/after-adding.lisp`, `inference/harness/forward.lisp`, `inference/harness/rule-after-adding.lisp` |
| KE (Knowledge Editor) and user-actions | [kb-access/ke-and-user-actions.md](kb-access/ke-and-user-actions.md) | `ke.lisp`, `user-actions.lisp` |
| FI (Functional Interface — older API) | [kb-access/fi.md](kb-access/fi.md) | `fi.lisp` |
| Formula Entry Templates (FET) | [kb-access/formula-templates.md](kb-access/formula-templates.md) | `formula-templates.lisp` |

### Subsumption & graph reasoning — [graph-reasoning/](graph-reasoning/)

| System | Doc | Source files |
|---|---|---|
| SBHL (subsumption-based HL) | [graph-reasoning/sbhl.md](graph-reasoning/sbhl.md) | `sbhl/sbhl-graphs.lisp`, `sbhl/sbhl-links.lisp`, `sbhl/sbhl-link-methods.lisp`, `sbhl/sbhl-search-methods.lisp`, `sbhl/sbhl-search-utilities.lisp`, `sbhl/sbhl-marking-methods.lisp`, `sbhl/sbhl-cache.lisp`, `sbhl/sbhl-caching-policies.lisp`, `sbhl/sbhl-module-*.lisp` (23 files total) |
| GraphL, GHL, GT | [graph-reasoning/graphl-ghl-gt.md](graph-reasoning/graphl-ghl-gt.md) | `graphl-graph-utilities.lisp`, `graphl-search-vars.lisp`, `graph-utilities.lisp`, `ghl-search-utilities.lisp`, `ghl-search-methods.lisp`, `ghl-search-vars.lisp`, `ghl-link-iterators.lisp`, `ghl-marking-utilities.lisp`, `gt-search.lisp`, `gt-methods.lisp`, `gt-utilities.lisp`, `gt-vars.lisp` |
| isa / genls / disjoint / equality / negation / transitivity | [graph-reasoning/named-hierarchies.md](graph-reasoning/named-hierarchies.md) | `isa.lisp`, `genls.lisp`, `genl-predicates.lisp`, `disjoint-with.lisp`, `equality-store.lisp`, `equals.lisp`, `negation-predicate.lisp`, `transitivity.lisp` |
| Predicate relevance / preserves-genls | [graph-reasoning/predicate-relevance.md](graph-reasoning/predicate-relevance.md) | `predicate-relevance-cache.lisp`, `pred-relevance-macros.lisp`, `preserves-genls-in-arg.lisp` |
| Skolems | [graph-reasoning/skolems.md](graph-reasoning/skolems.md) | `skolems.lisp` |
| Sibling-disjoint collections (SDC) | [graph-reasoning/sdc.md](graph-reasoning/sdc.md) | `sdc.lisp` — meta-level disjointness via `#$SiblingDisjointCollectionType`; cross-referenced from `named-hierarchies.md` |

### Inference engine — [inference/](inference/)

| System | Doc | Source files |
|---|---|---|
| Inference kernel & datastructures | [inference/inference-kernel-and-datastructures.md](inference/inference-kernel-and-datastructures.md) | `inference/harness/inference-kernel.lisp`, `inference/harness/inference-datastructures-*.lisp` (problem, problem-store, problem-query, problem-link, proof, strategy, tactic, inference, forward-propagate, enumerated-types), `inference/harness/inference-macros.lisp` |
| Inference parameters | [inference/inference-parameters.md](inference/inference-parameters.md) | `inference/harness/inference-parameters.lisp` |
| Strategist & tacticians | [inference/strategist-and-tacticians.md](inference/strategist-and-tacticians.md) | `inference/harness/inference-strategist.lisp`, `inference/harness/inference-tactician.lisp`, `inference/harness/inference-heuristic-balanced-tactician.lisp`, `inference/harness/balancing-tactician.lisp`, `inference/harness/inference-balanced-tactician-*.lisp`, `inference/harness/removal-tactician*.lisp`, `inference/harness/inference-tactician-utilities.lisp`, `inference/harness/inference-tactician-strategic-uninterestingness.lisp`, `inference/harness/new-root-tactician-datastructures.lisp`, `inference/harness/transformation-tactician-datastructures.lisp` |
| Workers (per inference step) | [inference/workers.md](inference/workers.md) | `inference/harness/inference-worker.lisp`, `inference/harness/inference-worker-removal.lisp`, `inference/harness/inference-worker-transformation.lisp`, `inference/harness/inference-worker-residual-transformation.lisp`, `inference/harness/inference-worker-restriction.lisp`, `inference/harness/inference-worker-rewrite.lisp`, `inference/harness/inference-worker-split.lisp`, `inference/harness/inference-worker-join.lisp`, `inference/harness/inference-worker-join-ordered.lisp`, `inference/harness/inference-worker-union.lisp`, `inference/harness/inference-worker-answer.lisp` |
| Inference modules (HL modules) | [inference/removal-modules.md](inference/removal-modules.md) | `inference/harness/inference-modules.lisp`, `inference/modules/removal/...`, `inference/modules/transformation-modules.lisp`, `inference/modules/rewrite-modules.lisp`, `inference/modules/simplification-modules.lisp`, `inference/modules/preference-modules.lisp`, `inference/modules/forward-modules.lisp`, `inference/modules/after-adding-modules.lisp` |
| Inference czer & analysis | [inference/czer-and-analysis.md](inference/czer-and-analysis.md) | `inference/harness/inference-czer.lisp`, `inference/harness/inference-analysis.lisp`, `inference/harness/inference-trivial.lisp`, `inference/inference-completeness-utilities.lisp`, `inference/harness/inference-min-transformation-depth.lisp`, `inference/harness/inference-metrics.lisp`, `inference/inference-pad-data.lisp`, `inference/harness/inference-strategic-heuristics.lisp`, `inference/harness/inference-lookahead-productivity.lisp` |
| HL prototypes & abnormal | [inference/hl-prototypes-and-abnormal.md](inference/hl-prototypes-and-abnormal.md) | `inference/harness/hl-prototypes.lisp`, `inference/harness/abnormal.lisp` |
| Argumentation | [inference/argumentation.md](inference/argumentation.md) | `inference/harness/argumentation.lisp` |
| Inference-abduction utilities | [inference/inference-abduction.md](inference/inference-abduction.md) | `inference/harness/inference-abduction-utilities.lisp`, `inference/modules/removal/removal-modules-abduction.lisp` |
| Backward inference | [inference/backward-inference.md](inference/backward-inference.md) | `backward.lisp`, `backward-utilities.lisp`, `backward-results.lisp` |
| Ask-utilities & query run | [inference/ask-utilities-and-query-run.md](inference/ask-utilities-and-query-run.md) | `inference/ask-utilities.lisp`, `inference/kbq-query-run.lisp` |
| Inference trampolines | [inference/inference-trampolines.md](inference/inference-trampolines.md) | `inference/inference-trampolines.lisp` |
| Specialized inference modes | [inference/specialized-modes.md](inference/specialized-modes.md) | `inference/arete.lisp`, `inference/leviathan.lisp`, `inference/janus.lisp` (Janus mostly missing-larkc), `inference/collection-intersection.lisp` |
| TVA (transitive value access) | [inference/tva.md](inference/tva.md) | `tva-cache.lisp`, `tva-inference.lisp`, `tva-strategy.lisp`, `tva-tactic.lisp`, `tva-utilities.lisp` |
| Cardinality estimates & pattern match | [inference/cardinality-and-pattern-match.md](inference/cardinality-and-pattern-match.md) | `cardinality-estimates.lisp`, `formula-pattern-match.lisp` |
| Agenda (priority-driven background task system) | [inference/agenda.md](inference/agenda.md) | `agenda.lisp`, `task-processor.lisp`, `operation-queues.lisp`, `operation-communication.lisp` |

### Canonicalization (czer) and well-formedness — [canonicalization/](canonicalization/)

| System | Doc | Source files |
|---|---|---|
| EL → HL canonicalization | [canonicalization/el-to-hl-canonicalization.md](canonicalization/el-to-hl-canonicalization.md) | `canon-tl.lisp`, `czer-main.lisp`, `czer-meta.lisp`, `czer-graph.lisp`, `czer-utilities.lisp`, `czer-trampolines.lisp`, `czer-vars.lisp` |
| Pre/post canonicalization | [canonicalization/pre-and-post-canonicalization.md](canonicalization/pre-and-post-canonicalization.md) | `precanonicalizer.lisp`, `postcanonicalizer.lisp`, `simplifier.lisp` |
| Folification (CycL → FOL) | [canonicalization/folification.md](canonicalization/folification.md) | `folification.lisp` |
| Uncanonicalize | [canonicalization/uncanonicalize.md](canonicalization/uncanonicalize.md) | `uncanonicalizer.lisp` |
| WFF (well-formedness) | [canonicalization/wff.md](canonicalization/wff.md) | `wff.lisp`, `wff-macros.lisp`, `wff-vars.lisp`, `wff-utilities.lisp`, `wff-module-datastructures.lisp` |
| Arg-type (AT) system | [canonicalization/arg-type.md](canonicalization/arg-type.md) | `arg-type.lisp`, `at-admitted.lisp`, `at-cache.lisp`, `at-defns.lisp`, `at-macros.lisp`, `at-routines.lisp`, `at-utilities.lisp`, `at-vars.lisp`, `at-var-types.lisp` |
| Defns (function/predicate definitions for AT) | [canonicalization/defns.md](canonicalization/defns.md) | `defns.lisp`, `collection-defns.lisp`, `evaluation-defns.lisp` |
| Term & formula utilities | [canonicalization/term-and-formula-utilities.md](canonicalization/term-and-formula-utilities.md) | `term.lisp`, `el-utilities.lisp`, `cycl-utilities.lisp`, `el-grammar.lisp`, `cycl-grammar.lisp` |
| CycL query specification | [canonicalization/cycl-query-specification.md](canonicalization/cycl-query-specification.md) | `cycl-query-specification.lisp`, `new-cycl-query-specification.lisp` |
| Bindings | [canonicalization/bindings.md](canonicalization/bindings.md) | `bindings.lisp`, `unification.lisp`, `unification-utilities.lisp` |
| Pattern matching | [canonicalization/pattern-match.md](canonicalization/pattern-match.md) | `pattern-match.lisp` |
| Rule macros | [canonicalization/rule-macros.md](canonicalization/rule-macros.md) | `rule-macros.lisp` |
| Concept filter | [canonicalization/concept-filter.md](canonicalization/concept-filter.md) | `concept-filter.lisp` |
| Builder utilities | [canonicalization/builder-utilities.md](canonicalization/builder-utilities.md) | `builder-utilities.lisp` |

### KB persistence — [persistence/](persistence/)

The on-disk representation of the KB: binary serialization, the dump format, the file-backed swap layer for the LRU object managers, and the cross-image-identity machinery (GUID, encapsulation) that lets a serialized KB load into a fresh image without identity collisions.

| System | Doc | Source files |
|---|---|---|
| CFASL serialization | [persistence/cfasl.md](persistence/cfasl.md) | `cfasl.lisp`, `cfasl-kernel.lisp`, `cfasl-kb-methods.lisp`, `cfasl-utilities.lisp`, `cfasl-compression.lisp` |
| KB dumper / loader | [persistence/kb-dumper-loader.md](persistence/kb-dumper-loader.md) | `dumper.lisp` |
| File-backed cache | [persistence/file-backed-cache.md](persistence/file-backed-cache.md) | `file-backed-cache.lisp`, `file-backed-cache-setup.lisp` |
| File-vector (on-disk array, read-only) | [persistence/file-vector.md](persistence/file-vector.md) | `file-vector.lisp`, `file-vector-utilities.lisp` |
| GUID generation | [persistence/guid.md](persistence/guid.md) | `guid.lisp` |
| Encapsulation (id + name fallback for cross-image transport) | [persistence/encapsulation.md](persistence/encapsulation.md) | `encapsulation.lisp` |

### External interop — [external/](external/)

Communication with non-Cyc systems: outbound code generation for other languages, message/document formats, network protocols, and connectors to external services (databases, search engines, web).

| System | Doc | Source files |
|---|---|---|
| Java/C name translation & backends | [external/java-c-name-translation-and-backends.md](external/java-c-name-translation-and-backends.md) | `java-name-translation.lisp`, `java-api-kernel.lisp`, `c-name-translation.lisp`, `c-backend.lisp` |
| CycML generator | [external/cycml-generator.md](external/cycml-generator.md) | `cycml-generator.lisp` |
| XML utilities | [external/xml-utilities.md](external/xml-utilities.md) | `xml-utilities.lisp` |
| Mail message | [external/mail-message.md](external/mail-message.md) | `mail-message.lisp` |
| Web utilities | [external/web-utilities.md](external/web-utilities.md) | `web-utilities.lisp` |
| Graphics format (GLF) | [external/graphic-library-format.md](external/graphic-library-format.md) | `graphic-library-format.lisp` |
| Lucene session | [external/lucene-session.md](external/lucene-session.md) | `lucene-session.lisp` (mostly missing-larkc) |
| SDBC (database connector) | [external/sdbc.md](external/sdbc.md) | `sdbc.lisp` (mostly missing-larkc) |
| SKSI (Semantic Knowledge Source Integration) | [external/sksi.md](external/sksi.md) | `sksi/sksi-macros.lisp` (mostly missing-larkc; only macro hooks survive) |

### Cyc API & runtime control — [runtime/](runtime/)

| System | Doc | Source files |
|---|---|---|
| Cyc API registration & dispatch | [runtime/cyc-api.md](runtime/cyc-api.md) | `api-control-vars.lisp`, `api-kernel.lisp` |
| Eval-in-API (SubL-subset interpreter for API) | [runtime/eval-in-api.md](runtime/eval-in-api.md) | `eval-in-api.lisp`, `eval-in-api-registrations.lisp` |
| Task processor & transcripts | [runtime/task-processor.md](runtime/task-processor.md) | `task-processor.lisp`, `transcript-server.lisp`, `transcript-utilities.lisp` |
| TCP transport | [runtime/tcp-transport.md](runtime/tcp-transport.md) | `tcp.lisp`, `tcp-server-utilities.lisp`, `stream-buffer.lisp` |
| Remote image (cross-image RPC) | [runtime/remote-image.md](runtime/remote-image.md) | `remote-image.lisp` |
| Modules & SubL primitives | [runtime/modules-and-subl.md](runtime/modules-and-subl.md) | `modules.lisp`, `subl-identifier.lisp`, `subl-macros.lisp`, `subl-macro-promotions.lisp`, `subl-promotions.lisp` |
| Memoization & caching | [runtime/memoization.md](runtime/memoization.md) | `memoization-state.lisp`, `cache-utilities.lisp` |
| Special-variable-state | [runtime/special-variable-state.md](runtime/special-variable-state.md) | `special-variable-state.lisp` |
| Verbosifier & standard-tokenization | [runtime/verbosifier-and-tokenization.md](runtime/verbosifier-and-tokenization.md) | `verbosifier.lisp`, `standard-tokenization.lisp` |
| Iteration / search / map / hierarchical-visitor | [runtime/iteration-search-map.md](runtime/iteration-search-map.md) | `iteration.lisp`, `search.lisp`, `map-utilities.lisp`, `hierarchical-visitor.lisp` |
| Misc-utilities (startup & KB handles) | [runtime/misc-utilities.md](runtime/misc-utilities.md) | `misc-utilities.lisp`, `misc-kb-utilities.lisp` |
| Control vars, cyc-kernel, revision | [runtime/control-vars.md](runtime/control-vars.md) | `control-vars.lisp`, `cyc-kernel.lisp`, `cyc-revision-extraction.lisp` |
| Guardian (async safety / interruption) | [runtime/guardian.md](runtime/guardian.md) | `guardian.lisp` |
| System info / parameters / version / benchmarks | [runtime/system-info.md](runtime/system-info.md) | `system-info.lisp`, `system-parameters.lisp`, `system-version.lisp`, `system-benchmarks.lisp` |
| Process utilities, OS process, timing | [runtime/process-utilities.md](runtime/process-utilities.md) | `process-utilities.lisp`, `os-process-utilities.lisp`, `timing.lisp` |
| Obsolete | [runtime/obsolete.md](runtime/obsolete.md) | `obsolete.lisp` |

### Data structures — [data-structures/](data-structures/)

The low-level container library. Internals are replaceable by native CL or modern libraries; the docs capture **why** each feature exists and **who** consumes it so a clean rewrite preserves load-bearing behaviour.

| System | Doc | Source files | Notes |
|---|---|---|---|
| ID-index (vector + overflow hashtable) | [data-structures/id-index.md](data-structures/id-index.md) | `id-index.lisp` | Used by every per-type id-keyed table; deeply integrated with CFASL load |
| Tries (constant name interning + completion) | [data-structures/tries.md](data-structures/tries.md) | `tries.lisp`, `finite-state-transducer.lisp` | Replace with native trie or radix tree |
| Set | [data-structures/set.md](data-structures/set.md) | `set.lisp` | Hashtable wrapper; raison d'être is CFASL opcode 60 |
| Set-contents | [data-structures/set-contents.md](data-structures/set-contents.md) | `set-contents.lisp` | Deprecated; replace with set |
| Set-utilities (union/intersect/build helpers) | [data-structures/set-utilities.md](data-structures/set-utilities.md) | `set-utilities.lisp` | Layered on `set`; merge into set in clean rewrite |
| Dictionary | [data-structures/dictionary.md](data-structures/dictionary.md) | `dictionary.lisp`, `dictionary-utilities.lisp` | Deprecated; core API commented out, replace with native hashtable |
| Bag (multiset) | [data-structures/bag.md](data-structures/bag.md) | `bag.lisp` | Zero callers in the port |
| Bijection | [data-structures/bijection.md](data-structures/bijection.md) | `bijection.lisp` | Mostly missing-larkc; zero callers; recreate with two hashtables |
| Cache (LRU) | [data-structures/cache.md](data-structures/cache.md) | `cache.lisp` | Used everywhere |
| Simple-LRU-cache-strategy | [data-structures/simple-lru-cache-strategy.md](data-structures/simple-lru-cache-strategy.md) | `simple-lru-cache-strategy.lisp` | |
| Somewhere-cache | [data-structures/somewhere-cache.md](data-structures/somewhere-cache.md) | `somewhere-cache.lisp` | |
| Binary tree (incl. unimplemented AVL) | [data-structures/binary-tree.md](data-structures/binary-tree.md) | `binary-tree.lisp` | |
| Stacks | [data-structures/stacks.md](data-structures/stacks.md) | `stacks.lisp` | |
| Queues | [data-structures/queues.md](data-structures/queues.md) | `queues.lisp` | |
| Deck (stack/queue dispatch) | [data-structures/deck.md](data-structures/deck.md) | `deck.lisp` | |
| Hash-table-utilities | [data-structures/hash-table-utilities.md](data-structures/hash-table-utilities.md) | `hash-table-utilities.lisp` | |
| List utilities | [data-structures/list-utilities.md](data-structures/list-utilities.md) | `list-utilities.lisp`, `transform-list-utilities.lisp` | |
| Vector utilities | [data-structures/vector-utilities.md](data-structures/vector-utilities.md) | `vector-utilities.lisp` | |
| String utilities | [data-structures/string-utilities.md](data-structures/string-utilities.md) | `string-utilities.lisp` | |
| Integer sequence generator | [data-structures/integer-sequence-generator.md](data-structures/integer-sequence-generator.md) | `integer-sequence-generator.lisp` | |
| Interval span | [data-structures/interval-span.md](data-structures/interval-span.md) | `interval-span.lisp` | |
| Number utilities (incl. rationals/dates) | [data-structures/number-utilities.md](data-structures/number-utilities.md) | `number-utilities.lisp`, `numeric-date-utilities.lisp`, `scientific-numbers.lisp` | |
| Format-nil | [data-structures/format-nil.md](data-structures/format-nil.md) | `format-nil.lisp` | |
| Unicode strings/chars/subsets/streams | [data-structures/unicode.md](data-structures/unicode.md) | `unicode-strings.lisp`, `unicode-streams.lisp`, `unicode-subsets.lisp` | |
| File utilities | [data-structures/file-utilities.md](data-structures/file-utilities.md) | `file-utilities.lisp` | |
| Value tables | [data-structures/value-tables.md](data-structures/value-tables.md) | `value-tables.lisp` | All bodies missing-larkc; zero Lisp callers |
| Xref database | [data-structures/xref-database.md](data-structures/xref-database.md) | `xref-database.lisp` | Build-time tooling; zero callers; cf. source-translator |
| Morphology | [data-structures/morphology.md](data-structures/morphology.md) | `morphology.lisp` | All bodies missing-larkc; data tables present; zero callers |
| Neural net | [data-structures/neural-net.md](data-structures/neural-net.md) | `neural-net.lisp` | Dead code; zero callers; delete candidate |

### Reverse engineering & meta — [meta/](meta/)

| System | Doc | Source files |
|---|---|---|
| Access macros & definitional metadata | [meta/access-macros.md](meta/access-macros.md) | `access-macros.lisp`, `meta-macros.lisp`, `subl-macros.lisp`, `utilities-macros.lisp` |
| Enumeration types | [meta/enumeration-types.md](meta/enumeration-types.md) | `enumeration-types.lisp` |
| Rewrite-of propagation | [meta/rewrite-of-propagation.md](meta/rewrite-of-propagation.md) | `rewrite-of-propagation.lisp` |
| Misc helpers | [meta/misc-helpers.md](meta/misc-helpers.md) | `misc-utilities.lisp`, `misc-kb-utilities.lisp` |
| Unrepresented terms | [meta/unrepresented-terms.md](meta/unrepresented-terms.md) | `unrepresented-terms.lisp`, `unrepresented-term-index-manager.lisp` |
| RED infrastructure (REgistry-style data store, missing-larkc) | [meta/red-infrastructure.md](meta/red-infrastructure.md) | `red-infrastructure.lisp`, `red-infrastructure-macros.lisp` |
| SubL → Java/C source translator (build-time tool, mostly missing-larkc) | [meta/source-translator.md](meta/source-translator.md) | `file-translation.lisp`, `secure-translation.lisp`, `system-translation.lisp` |

### Test harness — [tests/](tests/)

The Cyc test framework. Most runner bodies are LarKC-stripped, so these docs describe the registration scaffolding and the test-type vocabulary rather than how a test actually executes — the harness layer ([tests/harness.md](tests/harness.md)) is intact, the per-type structs and define-macros are intact, but everything that actually runs a test is missing.

| System | Doc | Source files |
|---|---|---|
| Cyc test harness (cyc-test wrapper, master tables, run/load API) | [tests/harness.md](tests/harness.md) | `cyc-testing/cyc-testing.lisp`, `cyc-testing/cyc-testing-initialization.lisp` |
| Generic test-case tables (`define-test-case-table`) | [tests/test-case-tables.md](tests/test-case-tables.md) | `cyc-testing/generic-testing.lisp` |
| Inference-engine tests (IUT, RMT, TMT, RMCT, ERT) | [tests/inference-tests.md](tests/inference-tests.md) | `cyc-testing/inference-unit-tests.lisp`, `cyc-testing/removal-module-tests.lisp`, `cyc-testing/transformation-module-tests.lisp`, `cyc-testing/removal-module-cost-tests.lisp`, `cyc-testing/evaluatable-relation-tests.lisp` |
| KB Content Tests and the ctest repository | [tests/kb-content-tests.md](tests/kb-content-tests.md) | `cyc-testing/ctest-utils.lisp`, `cyc-testing/kb-content-test/kct-utils.lisp` |
| Test query suite (orphan struct, no consumers) | [tests/test-query-suite.md](tests/test-query-suite.md) | `test-query-suite.lisp` |
