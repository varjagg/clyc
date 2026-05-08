# CycML generator

CycML is **Cyc's XML serialization for KB operations** — the wire format for shipping a KB delta (constants created, assertions made, NARTs killed, etc.) as a self-contained XML document. Where transcript files (covered in [persistence/](../persistence/)) carry encapsulated CycL forms designed to be `eval`'d on a peer image, CycML carries declarative *operations* designed to be parsed by an arbitrary client (a non-Cyc tool, a web service, a Java consumer of the LarKC API).

The implementation is `cycml-generator.lisp`. **The entire file is missing-larkc** — every `cycml-serialize-*` and `cycml-add-*-oper` function is an active declareFunction with no body. What survived the LarKC strip:

- The `cycml-kp-info` defstruct (knowledge-package metadata holder).
- One reconstructed macro (`within-cycl-atomic-sentence`).
- The `*within-cycl-atomic-sentence?*` parameter.
- The Cyc API registration of `cycml-serialize-object-to-string`.

The file is a *spec catalogue* — every function name and arglist is preserved, so the clean rewrite has the schema even though it has none of the bytes.

## What CycML is

A CycML document is XML that describes a sequence of KB operations applied within a "knowledge package" (a unit of related changes, similar to a database transaction). Reading the function-name list reveals the schema:

### Operation types (per `cycml-add-*-oper` and `cycml-serialize-*-oper` pairs)

| Operation | Adds / serializes |
|---|---|
| `create-constant-oper` | A new constant being introduced. |
| `find-or-create-constant-oper` | Idempotent constant introduction (no-op if already exists). |
| `rename-constant-oper` | Constant rename. |
| `merge-fort-oper` | Two FORTs merged into one (loser → winner). |
| `kill-fort-oper` | Constant or NART deletion. |
| `assert-oper` | New assertion with mt + strength + direction. |
| `reassert-oper` | Re-assertion (e.g. with new bookkeeping but same semantics). |
| `unassert-oper` | Removal of a single argument from an assertion. |
| `blast-assertion-oper` | Hard delete of an assertion (no argument left, fully gone). |
| `create-skolem-oper` | Skolem function created with arg-types + CNFs. |

Each operation type has paired `add` (mutator on the in-memory kp-info) and `serialize` (emit XML for that operation). The `add` family is how a producer constructs a kp-info; the `serialize` family is how a consumer-side serializer renders one to XML.

### Datatype serializers (per `cycml-serialize-<type>`)

| Type | Wire form |
|---|---|
| `truth` | `:true` / `:default-true` / `:false` / `:default-false` / `:unknown` |
| `nonnegativeinteger`, `positiveinteger` | XSD-style numeric atoms |
| `new-name`, `date`, `time` | per-XSD primitive types |
| `cyc-image-id`, `knowledge-package-id` | string-form image / package identifiers |
| `sublsymbol`, `sublstring`, `sublrealnumber` | atomic SubL values |
| `cyclvariable` | `?X`-style EL variable |
| `uri`, `namespace` | URL / XML-namespace atoms |
| `false`, `true` | literal Boolean tags |
| `microtheory`, `fort`, `cyclconstant` | KB-handle references |
| `cyclreifiednonatomicterm`, `cyclreifiablenonatomicterm`, `elnonatomicterm` | NART / NAT / EL-NAT |
| `subllist`, `cyclsentence`, `cyclatomicsentence` | structural CycL forms |
| `purpose`, `universal-date`, `universal-second` | bookkeeping fields |
| `support`, `hl-support` | argument supports (HL-support or kb-hl-support) |
| `justification`, `bookkeeping` | composite metadata |

The schema is essentially a one-to-one XML rendering of the CycL type system (constants, NARTs, NATs, sentences, assertions, mt's, supports), plus the operation envelope.

## Data structure: `cycml-kp-info`

The single defstruct in the file is the in-memory accumulator for a knowledge package being built up:

```
(defstruct cycml-kp-info
  knowledge-package-id              ; string id for this package
  knowledge-package-dependencies    ; list of other knowledge-package ids this one depends on
  operations)                       ; ordered list of operation records
```

Lifecycle (inferred from `add-*-oper` signatures): construct with `make-cycml-kp-info`, populate via repeated `cycml-add-X-oper info ...` calls, then serialize the whole package via `cycml-serialize-knowledge-package-info` (or in a streaming variant, write one operation at a time).

The dependency list lets a consumer re-order multiple incoming packages by topological sort: package B that depends on package A's constants must wait for A to be applied first.

## When does a CycML document get produced?

The Cyc API registration of `cycml-serialize-object-to-string` (the only registered external symbol) suggests CycML is producer-side only — a client invokes `cycml-serialize-object-to-string OBJECT` and gets back a CycML string for that one object. The full kp-info pipeline (`add-*-oper` → `serialize-knowledge-package`) is for batch operations, presumably used by an export tool or a delta-tracking subscriber. There is no consumer/parser in this file — CycML is asymmetric: Cyc emits, others consume.

In the running LarKC port, no live KB code path produces CycML — every entry point is missing-larkc. The hooks would have been:
1. Knowledge editor commits — emit a CycML doc per editing session.
2. KB diff / sync tools — emit a CycML delta between two KB states.
3. Web-service responses — emit a CycML rendering of a query result.

## The `within-cycl-atomic-sentence?` parameter

```
(defparameter *within-cycl-atomic-sentence?* nil
  "[Cyc] When T the serialization context is within an atomic sentence and lists
are more likely to be interpreted as el nats.")
```

When serializing CycL, a list `(SomePred X Y)` is ambiguous — at the top level it could be an atomic sentence; inside another sentence's argument position it must be an EL non-atomic term (e.g. `(GovernmentFn USA)`). The flag tells the serializer "I'm inside an atomic sentence, so any embedded list is by default a NAT, not another sentence." The associated macro:

```
(defmacro within-cycl-atomic-sentence (&body body)
  `(let ((*within-cycl-atomic-sentence?* t)) ,@body))
```

is wrapped around the body of `cycml-serialize-cyclatomicsentence` (stripped) so that nested calls to `cycml-serialize-object` know they're emitting NATs, not sentences.

## How CycML differs from CFASL externalization and from encapsulation

| | CFASL externalization | Encapsulation | CycML |
|---|---|---|---|
| Output | binary opcode stream | s-expression `(:hp ...)` | XML element tree |
| Reader | `cfasl-input` | `read` + `unencapsulate` | external XML parser |
| Audience | another Cyc image | another Cyc image | non-Cyc consumer |
| Identity | GUID + ext-id | GUID + name fallback | by name + namespace URI |
| Domain | any KB object | constants, NARTs (in transcripts) | KB operations + KB objects |
| Used by | dump files, API streams | API queue, transcript log, KE | external KB-export tools, web services |

The key distinction: CycML is the only one of the three that is **declarative** (describes operations as data) rather than imperative (the receiver runs the operations). A consumer parses CycML, examines what changed, and decides what to do — they may not have a KB at all.

## Notes for a clean rewrite

- **CycML is XML for an XML era.** A modern rewrite would emit JSON or Protobuf or RDF/Turtle. The schema (operation tags + datatype tags) is valuable independent of serialization format; preserve the schema, drop the XML.
- **Keep the operation taxonomy.** The 10 op types (`create-constant`, `find-or-create-constant`, `rename`, `merge`, `kill`, `assert`, `reassert`, `unassert`, `blast-assertion`, `create-skolem`) are a complete spec for KB-mutation events. They're useful as an internal event-bus schema even if no external consumer ever sees the wire format. The KE → CycML pipeline is essentially CDC for the KB.
- **Drop `find-or-create-constant` if you have CRDT-style "create" semantics** that are idempotent on identity. Currently the distinction exists because `create-constant` errors if the name is taken; a cleanly-versioned KB shouldn't need both.
- **`blast-assertion` vs. `unassert` is a real distinction worth preserving.** `unassert` removes one argument (justification) from an assertion; `blast-assertion` deletes the assertion entirely regardless of remaining arguments. A clean rewrite should keep both as distinct events because they have different consumer-visible consequences.
- **The `*within-cycl-atomic-sentence?*` flag is parser-state leaking into emit-state.** A clean rewrite should pass this as a parameter to the serializer, not a special variable. Same with the `cycml-kp-info` accumulator — accumulator-style mutation is fine but the dependency list should be a real graph (topological constraints), not a flat list.
- **The CycML schema's namespace / URI layer is unused in the LarKC port** — `cycml-serialize-uri` and `cycml-serialize-namespace` are stripped, but their existence implies CycML carries XML-namespace metadata for cross-vocabulary compatibility (e.g. mixing OpenCyc constants with private constants in the same document). A clean rewrite should keep this — KB content from multiple sources needs origin disambiguation.
- **The `cycml-serialize-object-to-string` API call is the *only* surfaced entry point.** That suggests CycML was intended primarily as a one-shot rendering tool ("show me this term as CycML"), not a batch export. The kp-info pipeline was secondary. A clean rewrite can treat the single-object emit as the primary API and the batch as a wrapper around repeated calls.
- **No parser in the file** — the system is one-way. A clean rewrite that wants two-way flow (round-trip through CycML) needs to add a parser; nothing here will help.
- **The dependency graph between knowledge packages is the only feature CycML has that CFASL/encapsulation lack.** Worth keeping as a mechanism for ordered batch apply on the consumer side, even if the wire format changes.
