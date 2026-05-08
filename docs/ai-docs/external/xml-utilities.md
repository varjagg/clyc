# XML utilities

A general-purpose XML emitter library for Cyc — the layer that CycML and any other Cyc-emitted XML format build on. Provides indented pretty-printing, well-formed-name validation against the XML 1.0 character classes, attribute-aware tag emission, CDATA handling, entity escaping, and an "S-expression as XML" pretty-printer for query results.

The implementation is `xml-utilities.lisp`. **The entire file is missing-larkc** — every one of the 68 active `declareFunction` entries has no Java method body (not even `handleMissingMethodError`). What survived:

- Five lexicals + parameters (XML version, indentation level/amount, CDATA delimiters, special chars).
- Two giant Unicode range tables (`*xml-base-char-code-ranges*`, `*xml-ideographic-char-code-ranges*`).
- Four reconstructed macros (`with-xml-indentation`, `xml-tag`, `with-xml-output-to-stream`, `with-xml-output-to-string`).
- Three Cyc-API registrations (`query-results-to-xml-stream` / `-file` / `-string`).
- One obsolescence note (`generate-valid-xml-header` → `xml-header`).

The function bodies are all stripped, but the macros are recoverable from Internal Constants evidence and reconstructed correctly in the port.

## What this is for

XML output, full stop. Cyc emits XML in two scenarios:

1. **Knowledge package serialization** — see [external/cycml-generator.md](cycml-generator.md). CycML is the Cyc-specific XML schema for KB operations; this module is its renderer.
2. **Query result serialization** — `query-results-to-xml-{stream,file,string}` (the three Cyc-API entry points). A query has a list of bindings (`?X = Foo, ?Y = Bar`); this module renders them as XML with a configurable spec describing element names and attribute placement. Used by web-service consumers that need a tabular XML rendering rather than the verbose CycML form.

The module has no parser — it is purely an emitter. (Parsing XML inputs in Cyc is the responsibility of `web-utilities.lisp`, which has its own `xml-tag?` / `xml-tag-attribute-value` predicates for inspecting parsed tokens.)

## Data structures

There is no defstruct in this file. The "data structures" are the global parameters that control emission:

| Variable | Default | Role |
|---|---|---|
| `*xml-version*` | `1.0` | The XML version declared in headers. |
| `*xml-indentation-level*` | `0` | Current depth, incremented inside `with-xml-indentation`. |
| `*xml-indentation-amount*` | `1` | Spaces (or units) added per nesting level. |
| `*cycml-indent-level*` | `0` | Tracks indent at *this* nesting level — see "the cycml-indent shadow" below. |
| `*xml-cdata-prefix*` | `"<![CDATA["` | CDATA opening token. |
| `*xml-cdata-suffix*` | `"]]>"` | CDATA closing token. |
| `*xml-special-chars*` | `'(#\& #\" #\' #\> #\< #\Newline)` | Chars that need escaping outside of CDATA. |
| `*alists-sort-key*` | `nil` | Sort key for attribute alists; controls deterministic emission order. |
| `*xml-stream*` | (no defparameter — set by macro) | Bound by `with-xml-output-to-stream`; consumed by every emit function. |

Two additional **lookup tables** are character-class data:

- `*xml-base-char-code-ranges*` — a list of `(min max)` Unicode ranges defining the XML 1.0 "BaseChar" production. About 200 ranges covering ASCII letters, Latin/Greek/Cyrillic/Hebrew/Arabic/Devanagari/CJK letter ranges. Used by the stripped `xml-base-char-code-p` to validate XML element names.
- `*xml-ideographic-char-code-ranges*` — three ranges (CJK Unified Ideographs U+4E00–U+9FA5, the Han radical U+3007, plus U+3021–U+3029). The "Ideographic" production — separate from BaseChar in XML 1.0.

The non-overlapping union of these two tables is the set of code points allowed as the *first* character of an XML name; combined with `digit-char-code-p` and a few combining-mark/extender ranges (not separately tabulated, would have been hardcoded into the stripped `valid-xml-name-char-p`), it gives the complete XML 1.0 Name production.

## The four reconstructed macros

### `with-xml-indentation`

```
(defmacro with-xml-indentation (&body body)
  `(let ((*xml-indentation-level* (+ *xml-indentation-amount* *xml-indentation-level*))
         (*cycml-indent-level* *xml-indentation-level*))
     ,@body))
```

Bumps the indent counter by `*xml-indentation-amount*` for the duration of `body`. Does NOT emit anything by itself — the actual indent string is written by `xml-add-indentation` (stripped) which reads `*xml-indentation-level*` at print time.

### `xml-tag`

```
(defmacro xml-tag ((name &optional attributes atomic? no-nested-elements?) &body body)
  `(progn
     (xml-start-tag-internal ,name ,attributes ,atomic?)
     (with-xml-indentation
       ,@body)
     (unless ,no-nested-elements?
       (xml-terpri))
     (xml-end-tag-internal ,name)))
```

The bread-and-butter tag emitter. Name plus optional attributes plus atomic-flag (controls whether the tag self-closes as `<name/>`); body is the inner content emitted at one extra level of indent; `no-nested-elements?` suppresses the terpri before the close-tag (used for inline tags whose close should follow text on the same line).

### `with-xml-output-to-stream` and `with-xml-output-to-string`

```
(defmacro with-xml-output-to-stream (stream &body body)
  `(let ((*xml-stream* ,stream))
     ,@body))

(defmacro with-xml-output-to-string (string-var &body body)
  (with-temp-vars (stream)
    `(let ((,string-var
             (with-output-to-string (,stream)
               (with-xml-output-to-stream ,stream
                 ,@body))))
       ,string-var)))
```

The stream-form sets `*xml-stream*`; every emit function (`xml-write-string`, `xml-write-char`, `xml-tag`, etc.) writes to that stream. The string-form is a wrapper that captures the output to a string-bound variable.

`*xml-stream*` is the only global stream binding in the module. There is no defparameter for it — it gets a fresh binding each time `with-xml-output-to-stream` runs.

## The cycml-indent shadow

`*cycml-indent-level*` is a separate counter that mirrors `*xml-indentation-level*` but is read by CycML-specific code (it lives in this file but used to be tracked separately by the CycML serializer). The reconstructed macro:

```
(*cycml-indent-level* *xml-indentation-level*)
```

binds it to the *post-bump* xml level, so a CycML emitter that wants its own depth tracking gets the right number. In a clean rewrite this duality is unnecessary — drop one of the two and pick a single indent counter.

## When does an XML emit happen?

There are three publicly-registered entry points (all `register-external-symbol`):

1. **`query-results-to-xml-stream`** — `(results &optional el-vars xml-spec root-element-name stream)`. Render query bindings to a stream as XML.
2. **`query-results-to-xml-file`** — same, to a named file.
3. **`query-results-to-xml-string`** — same, to a returned string.

There's also one obsolete entry: `generate-valid-xml-header` is registered as obsolete in favor of `xml-header`.

In the LarKC port no live code path actually exercises these; in the full Cyc engine, query-results-to-xml is the consumer-facing rendering for SOAP / HTTP / web-service responses.

The grouping pipeline (inferred from stripped function names) is:

1. `attribute-vars xml-spec` — pull attribute placements from the spec.
2. `sort-query-results-on-el-var results var` — sort by primary grouping variable.
3. `query-bindings-to-xml-stream bindings el-vars xml-spec root-element-name stream` — group bindings, emit one XML tree per group.
4. `write-xml-from-grouped-bindings grouped-bindings ...` — actual emission.

The `xml-spec` describes how to map EL variables to XML structure (which become elements, which become attributes, what's the wrapping element).

## Notes for a clean rewrite

- **The whole file is dead code in the LarKC port.** Every emit function is missing-larkc; no live consumer exists. A clean rewrite has to choose: (a) re-implement the schema-faithful XML emitter, or (b) drop XML entirely and use a modern format (JSON, YAML, Protobuf). Option (b) is probably right — XML's verbosity is no longer a fit, and the typical consumer of "query results as data" is a web frontend that prefers JSON.
- **If XML is kept**, build on a real XML library (libxml2, host-language stdlib) rather than rewriting the emitter. The reasons the original SubL-emitted its own:
  - Indent control hooks at every print-step.
  - Tight integration with Cyc's special-char escape rules (Cyc's `~` and `?` and `:` need careful treatment in XML names).
  - A SubL list is the natural input shape, so the emitter reads s-expressions directly.
  None of these are good enough reasons in 2026; a thin shim atop a real library handles them all.
- **The 200-line `*xml-base-char-code-ranges*` table is the XML 1.0 BaseChar production.** This is *fixed* — XML 1.0 hasn't changed. Don't keep it in source; reference the spec or use the host's Unicode library (`Character.isLetter` in Java, `unicodedata.category(c).startswith('L')` in Python) which gets it right by construction. Same for `*xml-ideographic-char-code-ranges*`.
- **`*xml-special-chars*` is missing the apostrophe-as-`&apos;` case** (it has `#\'` but the escape table is in the stripped `xml-char-escaped-version`). XML 1.0 requires `&` `<` and `>` to be escaped in element content; `"` must be escaped in attribute values; `'` is conditional. The list-of-six is informally complete but incorrect for context — escaping is context-sensitive. A clean rewrite should escape per-context, not per-char-class.
- **`*alists-sort-key*` is a global controlling attribute order.** XML attribute order is not semantically significant, but Cyc apparently wanted deterministic output. Make this a per-call parameter, not a special var.
- **`with-xml-output-to-string` uses `with-output-to-string` + `with-xml-output-to-stream`.** That's a cleanly-layered design and a good model — keep it.
- **The `xml-spec` argument to `query-bindings-to-xml` is a small DSL** (element name → field, attribute name → variable, root element name) that's never made explicit in the file because the parser is missing-larkc. A clean rewrite should fully define the spec (perhaps with a schema language, perhaps with a function that builds a render tree). The current "implicit struct" approach loses portability.
- **The CDATA handling** (`xml-cdata`, prefix/suffix lexicals) is for embedding arbitrary text without escaping. Keep this — it's a real XML feature that some consumers depend on.
- **`define-obsolete-register 'generate-valid-xml-header '(xml-header)`** — the migration was already done at port time. A clean rewrite shouldn't carry the obsolete name forward.
- **The `boolean-to-true/false-string` helper at the end** signals the file's "we serialize CL booleans as XML `true`/`false` strings" convention. That's correct for XSD-typed XML; keep it documented.
- **The lack of any parser is significant.** The clean rewrite should accept that XML is a *one-way* format here — Cyc emits, never consumes. Round-trip testing isn't on the table.
