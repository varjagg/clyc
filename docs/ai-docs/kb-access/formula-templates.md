# Formula Entry Templates (FET)

The **Formula Entry Template** system is Cyc's data-driven UI scaffold for guided knowledge entry. A template is a pre-authored CycL formula with named argument-position slots; a UI presents the formula to a human user, the user fills the slots, and the template emits one or more assertions. Templates are organized into topics (e.g. "Personal Information," "Geographic Data") that themselves form a tree.

FET is the layer that turns "the user wants to assert facts about *this term*" into "show them these forms, with these slot prompts, these candidate replacements, these validation rules, in this MT, with these follow-up questions." It is the structured-form alternative to free-form `ke-assert` (see [ke-and-user-actions.md](ke-and-user-actions.md)).

In the larkc-stripped port nearly every FET operation is `missing-larkc`. The struct definitions, CFASL registration, the macro layer, and the global state are intact; the operational guts — load templates from KB, render to XML, run the loading-supporting-ask, find/validate assertions for a template instance — are all stripped. A clean rewrite reconstructs them from the structs and the surviving Cyc API entry points.

## Core data structures

Three defstructs, each registered for CFASL transport so a topic tree can be serialized and shipped to a thin client.

### `template-topic`

A node in the topic tree. Holds the templates that live at this node, the subtopics under it, and the MTs that govern its data.

| Slot | Meaning |
|---|---|
| `supertopic` | parent in the topic tree (nil at root) |
| `topic` | the topic FORT itself (a Cyc term naming the topic) |
| `subtopics` | child topics, in display order |
| `templates` | `formula-template`s living directly at this node |
| `ordering` | display ordering — see "subtopic-ordering" / "template-ordering" |
| `title` | localized human-readable title |
| `term-prefix` | string stub for newly created terms ("Person-…") |
| `intro-template` | a `formula-template` used as the first form a user fills (creates the "anchor" term) |
| `source-types` | which types of source data feed assertions here |
| `source-mt` | MT where source assertions are recorded |
| `query-mt` | MT used to drive the loading-supporting-ask that pulls existing values into the form |
| `definitional-mt` | MT that defines the structural constraints on the topic |

The three MTs split write-where (`source-mt`), read-where (`query-mt`), and define-where (`definitional-mt`). A topic can be defined in `#$EnglishMt`, draw existing facts from `#$AnytimePSC`, and write new ones to a project-specific MT, all without changing the form code.

### `formula-template`

A single fillable formula.

| Slot | Meaning |
|---|---|
| `topic` | the owning `template-topic` |
| `id` | unique template id within the topic |
| `formula` | the CycL formula skeleton with named variables in argpos slots |
| `query-specification` | how to query the KB for existing assertions matching this template |
| `elmt` | the "ephemeral" MT — an instance-scoped MT for working state (see "fet-fallback-to-default-mt?") |
| `focal-term` | the variable representing the *thing the user is editing* — the assertion subject |
| `argpos-details` | list of `arg-position-details` for each slot |
| `argpos-ordering` | display order over the slots |
| `examples` | example fillings shown as hints |
| `entry-format` | rendering hint (single vs multi-entry, free-form vs constrained) |
| `follow-ups` | other templates suggested after this one is filled |
| `gloss` | localized prompt text for the whole template |
| `refspec` | reformulation specification — see "reformulation" below |

A template's `formula` plus its `argpos-details` is enough to render a UI form. The `query-specification` plus `query-mt` is enough to pre-fill it from existing KB content. The `refspec` is enough to convert the user's filled form back into one or more canonical assertions.

### `arg-position-details`

Per-slot metadata. There is one of these for each variable position in the template's `formula` that the user is allowed to fill.

| Slot | Meaning |
|---|---|
| `argument-position` | the argpos in the formula (e.g. `(1)`, `(2 1)` for nested slots) |
| `ordering` | display order among siblings |
| `gloss` | localized prompt text for this slot |
| `invisible-replacement-positions` | sub-slots that are computed, not user-entered (e.g. an MT auto-derived from the `focal-term`) |
| `replacement-constraints` | type / collection / arg-isa restrictions — what's a valid filling |
| `candidate-replacements` | autocomplete suggestions, often a query result |
| `is-editable` | bool: does this slot accept input or only display |
| `explanation` | help text on hover |
| `requires-validation` | bool: should the answer be wff-checked before commit |
| `unknown-replacement` | placeholder term to fill if the user submits nothing |

Constraints + candidates + validation make this a typed form-field, not a free string.

## How a template runs

The lifecycle, reconstructed from the surviving function names and the Cyc API registrations:

1. **Discovery.** The client calls `applicable-template-topics-for-term term` to find which topics apply to a term (or `find-template-topic-matches-for-constraint` for a constraint-based search). Returns topic FORTs.
2. **Topic load.** `get-template-topic-in-xml topic` serializes the topic — its title, term-prefix, intro-template, subtopics, templates — to XML for the client.
3. **Form render.** The client renders each `formula-template` as a form: the formula's natural-language gloss across the top, one input per `arg-position-details` slot, ordered by `argpos-ordering`, prompts from each slot's `gloss`, autocomplete from `candidate-replacements`, type-check via `replacement-constraints`.
4. **Pre-fill.** For an existing instance, `get-assertions-for-template-topic-instance topic instance mt` runs the `query-specification` against `query-mt` and returns all assertions that already match the template. The form is pre-filled with those values; the assertions are tagged "non-editable" if they fall in the `*non-editable-assertions-for-template-topic-instance*` set (forms shouldn't let the user clobber facts they don't own).
5. **Submit.** When the user fills the form, `cyc-assert` (or `cyc-assert-wff` if `requires-validation`) is run on each completed formula in `source-mt`. Bookkeeping is recorded as for any KE op.
6. **Reformulation.** Some templates declare a `refspec` — the *visual* form the user fills isn't the *canonical* form stored. `ftemplate-reformulated-query-mt` and friends translate between the two. The `reformulate-unknown-fet-term` Cyc API entry handles the "user typed a string; figure out which Cyc term they meant" case.
7. **Follow-ups.** When a template is done, its `follow-ups` are presented to the user as suggested next forms.

## Topic priority and ordering

`*high-to-low-priorities*` is a dictionary mapping terms to lists of lower-priority terms — used by `apply-prioritizing-ordering-to-kb-objects` and `formula-template-load-prioritization-information-*` to sort subtopics and templates within a topic. Higher-priority items render first; "priority" is asserted in the KB via the topic's `definitional-mt`.

`stable-template-id-compare` provides a deterministic tie-breaker so the form layout doesn't shuffle between sessions.

## Non-editable assertion tracking

`*non-editable-assertions-for-template-topic-instance*` is a dynamic var that holds the set of assertions the template should display as read-only. Bound by `with-known-non-editable-assertions-for-template-topic-instance` (the surviving macro, reconstructed from Internal Constants). The deeper macro `with-non-editable-assertions-for-template-topic-instance` calls `compute-non-editable-assertions-for-template-topic-instance` to populate it from the KB at form-load time.

This is where access control gets layered onto the template: an assertion authored under `#$BookkeepingMt` by another cyclist won't be edit-able through a project-MT form even if the form's query pulls it in.

## Reformulation caching

`*get-assertions-from-initial-ask?*` (default `t`) controls a perf optimization: try to get the actual assertion objects from the first ask, rather than getting bindings, substituting back, and re-finding the assertions. The fallback path exists because some `query-specification`s rewrite the formula in ways that change the assertion's surface form — in that case the pre-filled values come from one query and the "this assertion is non-editable" tagging requires a second.

`*ftemplate-constraint-to-collection-skiplist*` (initialized in setup) maps slot-constraint specs to the collection that satisfies them, skipping the constraint→collection compilation step on subsequent uses of the same template.

## XML serialization

Templates are transported to thin clients as XML, not CFASL. The XML revisions are tracked in `*xml-template-topic-revisions*` and `*xml-template-topic-assertions-revisions*` so a server can negotiate format with an older client. `*xml-suppress-future-template-extensions*` is a feature gate for shipping-but-not-yet-public template features. `xml-serialize-formula-template`, `xml-serialize-template-topic`, etc. are LarKC-stripped; the protocol survives only as the version-history strings.

## CFASL

Three opcodes are registered (the GUIDs are in the source) so a topic tree can be CFASL-dumped:

| Type | GUID-keyed input fn |
|---|---|
| `template-topic` | `cfasl-input-template-topic` |
| `formula-template` | `cfasl-input-formula-template` |
| `arg-position-details` | `cfasl-input-arg-position-details` |

The output side dispatches via `defmethod cfasl-output-object` on each struct type. The actual encoders are `missing-larkc` (5669/5670/5671). A clean port has to either reconstruct them or write a fresh struct-to-CFASL pipeline using the slot inventory above as the schema.

## Cyc API surface

Registered in [eval-in-api-registrations.lisp](../../larkc-cycl/eval-in-api-registrations.lisp):

| API entry | Purpose |
|---|---|
| `applicable-template-topics-for-term` | which topics apply to a term — entry point for "edit this term" |
| `focal-term-type-for-topic-type` | introspect what kind of term a topic operates on |
| `find-template-topic-matches-for-constraint` | constraint-based topic search |
| `get-template-topic-in-xml` | dump a topic + its subtopics + templates as XML |
| `get-template-topic-assertions-for-match-in-xml` | the pre-fill response — assertions matching the template, as XML |
| `add-template-with-formula-and-gloss` | author a new template at runtime |
| `create-minimal-formula-template-with-query` | programmatic template creation |
| `create-new-formula-template-with-query` | richer programmatic creation |
| `reformulate-unknown-fet-term` | string-to-term resolution for user input |

The pattern is XML-in / XML-out for the human-facing operations; structured Cyc terms for the internal authoring path.

## Memoization

Two functions are registered for memoization at file-load:

- `count-asserted-formula-template-ids-for-type` — used to pre-flight the form list
- `map-elmt-to-published-conceptual-work` — caches the elmt → published-work mapping (`*map-elmt-to-published-conceptual-work-caching-state*`)

`clear-map-elmt-to-published-conceptual-work` and `remove-map-elmt-to-published-conceptual-work` provide manual invalidation for when the underlying KB facts change.

## Notes for a clean rewrite

- **The three structs are the schema.** If you keep the FET concept, the cleanest port preserves these as data classes — they map directly to a JSON/Protobuf schema for a modern client.
- **Three MTs per topic is load-bearing.** Splitting source / query / definitional MTs lets one topic mediate between authored data, queryable data, and structural definitions. Don't collapse into a single "the MT" without auditing.
- **The "non-editable" set is an ACL primitive.** A modern UI implements per-row read-only via the same mechanism — populate the set from auth, render disabled inputs.
- **`elmt` (ephemeral MT)** is a per-instance scratch MT. Document its lifecycle clearly — when does it get created, when garbage-collected. The current code suggests it's tied to the `template-topic` instance lifetime.
- **The XML transport is replaceable.** If a client doesn't need the XML wire format, the slot-inventory structures map to JSON 1:1. The XML revision-tracking mechanism (`*xml-template-topic-revisions*`) is good practice and worth preserving.
- **Most operational functions are stripped.** A clean port reconstructs them from the struct slots, the query-specification grammar, and the assertion-finding contract — the surviving function-name list in this file is the spec.
- **`*template-count-mt*` defaults to `#$InferencePSC` at load time.** Initialization order matters: `#$InferencePSC` must exist before this file's setup runs.
- **Validation ladder is `requires-validation` on each slot.** The slot says whether to wff-check; the form aggregates. Modern UIs do field-level validation as the user types — this needs a `validate-slot` API exposed beyond the current "validate the whole form" surface.
- **Follow-up workflow is shallow.** A template's `follow-ups` is a list of next-templates; there's no branching ("if user picked X, show template Y; else Z"). A clean rewrite either keeps it shallow or extends to a proper authoring flow graph.
- **`is-skolemish-term?`, `uninteresting-indeterminate-term?`, `bad-assertion-for-formula-templates?`** are filters used to keep the form clean — Skolems and bookkeeping assertions don't show up in user-facing form pre-fill. Preserve these or document why they were dropped.
- **`fet-fallback-to-default-mt?`** is the safety valve when an instance has no `elmt` — fall back to a project default. A clean port surfaces this as an explicit policy, not a buried check.
