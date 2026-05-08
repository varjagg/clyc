# Graphic Library Format (GLF)

GLF is **Cyc's data model for typed directed graphs that are stored as KB content** and rendered as diagrams. A GLF graph is a graph term in the KB (an `Individual` whose isa includes `GraphicLibraryGraph` or similar) with associated facts about its nodes, arcs, connector points, and rendering info; this module provides the runtime structs to materialize that graph term out of the KB into in-memory form, plus the (stripped) XML serializer to emit it for diagram-rendering tools.

The implementation is `graphic-library-format.lisp`. **Every function body is missing-larkc** — only the four defstructs survive in functional form. What's here:

- `glf-graph` (13 slots) — the top-level graph node container.
- `glf-node` (4 slots) — a node inside a graph.
- `glf-arc` (6 slots) — an arc connecting two nodes.
- `glf-rendering` (1 slot, just a `label`) — rendering metadata for a component.

The function names, when read together, tell the loading + serializing pipeline.

## What GLF is for

Cyc's KB sometimes models **structured diagrams** as first-class content: process flow diagrams, organizational charts, system architecture graphs, anything where the topology is data, not just visualization. The "Graphic Library" name suggests this was tied to a Cyc graphical UI tool (the original Cyc desktop app probably had a diagram viewer); GLF is the data shape that bridges the KB to that UI.

The pipeline (inferred from function names):

1. **Some Cyclist asserts in the KB** that some graph term is a `GraphicLibraryGraph` with these node terms, these arc terms, certain types, and certain rendering hints.
2. **`create-glf-graph-from-kb graph-term mt`** materializes the in-memory `glf-graph` by querying the KB.
3. **`xml-serialize-glf-graph`** emits the graph as XML for an external diagram tool.

The data model accommodates **typed graphs** — every node has types, every arc has types, the graph itself has types, the connectors (entry/exit edges) have types. This is heavier than plain "nodes and edges" and reflects that Cyc graphs are categorized objects with semantic content.

## Data structures

### `glf-graph` (conc-name `GLFGRPH-`, 13 slots)

```
(defstruct glf-graph
  id                              ; KB term identifying this graph
  types                           ; list of types asserted of the graph
  ais                             ; "atomic instances of"? — likely a flat enum of all subgraph elements
  nodes                           ; list of glf-node
  node-types                      ; list of types appearing on any node (cached from nodes)
  source-node                     ; the entry-point node, if any
  arcs                            ; list of glf-arc
  arc-types                       ; list of types appearing on any arc
  incoming-connectors             ; arcs that enter the graph from outside (subgraph edge)
  outgoing-connectors             ; arcs that exit the graph
  incoming-connector-types        ; types on incoming connectors
  outgoing-connector-types        ; types on outgoing connectors
  rendering-info)                 ; glf-rendering or nil
```

The `ais` slot is unclear from name alone — likely "atomic instances," a flat union of all element ids in the graph regardless of node-vs-arc-vs-connector. The slot's role is exposed via the stripped `map-glf-graph-to-ais` function but the body is missing.

The `incoming-connectors` / `outgoing-connectors` distinction matters when this graph is itself a *subgraph* of a larger graph — the connectors are the arcs that bridge across the subgraph boundary, separated by direction. A standalone graph has empty connector lists.

The four `*-types` cache slots (`node-types`, `arc-types`, etc.) are *materialized* lists — they pre-compute the set of types appearing in their respective collections so that consumers can iterate types without scanning every element. Population is via the stripped `initialize-glfgrph-node-types` / `initialize-glfgrph-arc-types` (and presumably parallel ones for connectors). `note-glf-graph-node-type` / `note-glf-graph-arc-type` add a single type to the cached list.

`source-node` is the canonical "start" of the graph — a flowchart's entry point, an org chart's root, etc. It's a single node, not a list, so this only models graphs with one canonical start. Multi-entry graphs would either pick one or be modeled differently.

### `glf-node` (conc-name `GLFNODE-`, 4 slots)

```
(defstruct glf-node
  id          ; KB term for this node
  types       ; list of types asserted of this node
  parent      ; the containing glf-graph (or possibly a parent node for nesting)
  semantics)  ; opaque slot — the node's "meaning," likely a CycL formula or a constant
```

The `parent` slot enables nested graphs (a subgraph inside a parent graph). The `semantics` slot is the bridge to actual KB content — a node represents *something*, and that something is in `semantics` (e.g. `#$Walking-Generic` for a node that means "a walk action").

### `glf-arc` (conc-name `GLFARC-`, 6 slots)

```
(defstruct glf-arc
  id          ; KB term
  types       ; list of types
  parent      ; containing glf-graph
  from        ; source glf-node
  to          ; destination glf-node
  semantics)  ; opaque CycL meaning
```

Standard directed-arc shape. Note that arcs reference *nodes*, not arbitrary elements — there are no arc-to-arc relations in this model. Connectors (cross-subgraph arcs) are still arcs but live in `incoming-connectors`/`outgoing-connectors` rather than the main `arcs` list.

### `glf-rendering` (conc-name `GLFRNDR-`, 1 slot)

```
(defstruct glf-rendering
  label)      ; the visual label for this component
```

A trivial holder for now — the original probably grew over time to include color, position, font, etc. but only `label` survived in the LarKC distribution. Rendering info attaches to a `glf-graph`'s `rendering-info` slot at the top level; the stripped `create-glf-rendering-for-component-from-kb` suggests per-component rendering can also be attached, but no slot in `glf-node` or `glf-arc` exists for it — possibly the rendering is keyed on `id` in some side table that's also stripped.

## When does a GLF graph get materialized?

The pipeline (all stripped):

| Function | Role |
|---|---|
| `get-graph-defining-mt graph-term` | Find the microtheory that holds this graph's facts. |
| `create-glf-graph-from-kb graph-term mt` | Build the `glf-graph` struct. |
| `load-glf-graph-from-kb graph-term mt` | Likely the same as create with caching; pair name suggests load-vs-load-from-kb-vs-create distinction. |
| `initialize-glfgrph-node-types graph mt` | Populate the type-cache slots. |
| `initialize-glfgrph-arc-types graph mt` | Same for arcs. |
| `load-all-glf-nodes-from-kb graph mt` | Populate the `nodes` slot by querying the KB for every node fact about `graph-term`. |
| `load-one-glf-node-from-kb graph node mt` | Build one node. |
| `load-all-glf-arcs-from-kb graph mt` | Populate the `arcs` slot. |
| `load-one-glf-arc-from-kb graph arc mt` | Build one arc. |
| `create-glf-node-from-kb graph node mt` | Probably the actual struct constructor (vs. the load-one function which fetches plus calls this). |
| `create-glf-arc-from-kb graph arc mt` | Same for arcs. |
| `create-glf-rendering-for-component-from-kb graph component mt` | Attach rendering metadata. |

The `mt` parameter throughout means GLF queries are *microtheory-relative* — a graph's facts can be asserted in different mts and a single graph term might have different topologies in different mts. This matches Cyc's general "context-relative truth" pattern.

The pipeline always starts with a graph term and an mt: callers know what graph they want and where its facts live. There is no "find all GLF graphs in this KB" entry point, so GLF was apparently only consumed via specific ID-driven lookups.

## When does a GLF graph get serialized?

Only one direction is implemented: KB → in-memory → XML. There is no XML → GLF parser, and no GLF → KB writer. The system is producer-side for serialization.

| Function | Role |
|---|---|
| `xml-serialize-glf-graph glf-graph &optional stream` | Top-level entry. |
| `xml-serialize-glf-graph-core glf-graph stream` | Skeleton: id, types, lists. |
| `xml-serialize-glf-graph-diagram glf-graph stream` | Visual layout layer. |
| `xml-serialize-glf-graph-rendering glf-graph stream` | Per-component rendering. |
| `xml-serialize-glf-graph-rendering-info glf-graph stream` | Top-level rendering-info slot. |
| `xml-serialize-glf-graph-flow-model glf-graph stream` | Flow semantics — the `source-node` and how data flows through the graph. |

The five-way decomposition (core / diagram / rendering / rendering-info / flow-model) suggests the XML output had a layered schema where each layer was independently consumable by different downstream tools — one tool reads only `core` to extract the topology; another reads `diagram` + `rendering` for layout; a third reads `flow-model` to do flow analysis.

## Cross-references

GLF builds on:
- **KB query** ([kb-access/kb-mapping.md](../kb-access/kb-mapping.md)) — every "load-from-kb" function needs to iterate facts about a term in an mt.
- **CycL terms** — the `id`, `types`, `semantics` slots all hold CycL constants/formulas.
- **xml-utilities** ([xml-utilities.md](xml-utilities.md)) — the XML serializer presumably wraps in `with-xml-output-to-stream`.

Nothing else builds on GLF. There are no callers of any GLF function in the rest of the codebase. It's a self-contained sink: input is the KB, output is XML.

## Notes for a clean rewrite

- **The data shape is fine; the loader is missing.** The four structs faithfully model "typed directed graph with rendering hints," and a clean rewrite can keep them mostly as-is. The work is in re-implementing the from-KB loader.
- **`ais` is opaque without the function bodies.** The single hint is `map-glf-graph-to-ais` — a function that maps a graph to its `ais` value. A clean rewrite probably wants to call this `all-element-ids` or just compute it on demand from `(append (mapcar #'glfnode-id nodes) (mapcar #'glfarc-id arcs) ...)` rather than store it.
- **The four `*-types` cache slots are denormalization.** They duplicate data already present in nodes/arcs/connectors. Drop the caches; compute types on demand. Modern hardware can scan a few-hundred-element list faster than the cache invalidation logic costs.
- **`source-node` is single-valued** but a real flowchart can have multiple entries. A clean rewrite should make this `source-nodes` (a list) or add a separate `entry-points` slot.
- **`semantics` as opaque blob is OK** but should be typed. Pick a union: `(or constant nart formula nil)`. Document explicitly.
- **The `parent` slot on nodes and arcs is back-pointer redundancy.** It's useful for tree-walking but introduces cycles in object graphs that defeat naive serialization. A clean rewrite should either resolve this with a parent-graph context that's threaded explicitly, or use weak references in object form.
- **Add a from-XML parser.** The current asymmetry (KB → XML only) means external diagram tools can't push edits back. A clean rewrite that keeps GLF should support round-trip.
- **The five-way XML decomposition (core/diagram/rendering/rendering-info/flow-model) is over-engineered.** A clean rewrite can use a single layered XML doc with namespaces or named sections, not five separate functions. But preserve the *intent*: the schema separates topology from layout from rendering — this is correct, just not five functions correct.
- **GLF graphs should probably move to a modern format like GraphML or DOT** for the XML serialization. The semantic types (`Walking-Generic` etc.) can live in custom namespaced attributes. This gets free tooling support (Graphviz, yEd, dozens of others).
- **The `load-glf-graph-from-kb` vs. `create-glf-graph-from-kb` distinction is unclear.** If they're a load/create cache pair (load returns cached if present, create always builds), the cache key and lifecycle should be documented; if they're synonyms, drop one. A clean rewrite needs to decide.
- **The `rendering-info` slot is a single `glf-rendering` struct** with one field (`label`). This is suspiciously thin and likely a stub for a richer struct. A clean rewrite should expand it: position (x, y), size, color, font, z-index, layer, etc. — whatever the consumer tool needs. Or punt: store it as an opaque key/value plist and let consumers schema-validate.
- **No tests survive.** With every body missing-larkc, the only spec is the slot list and the function names. A clean rewrite needs to reverse-engineer the actual KB queries by reading Cyc constants like `#$GraphicLibraryGraph`, `#$arcsInGraph`, etc., to find what predicates connect a graph term to its parts.
