# Lucene session

A **client-side connector to an external Apache Lucene full-text-search server.** Cyc opens a TCP connection to a separate Lucene process, sends commands as numbered message types, and receives responses. Used to keep an external full-text index of KB content (constant names, comments, paraphrases) that can be queried by string matching far faster than walking the KB.

The implementation is `lucene-session.lisp`. **Almost everything is missing-larkc** — every one of the 31 active declareFunctions had its body stripped, and `lucene-session-print-function-trampoline` (the only one with a Java body) is itself `handleMissingMethodError 29219`. The port preserves: the defstruct, the `*lucene-host*`/`*lucene-port*` config, the six message-type opcodes, the `with-lucene-session` macro (reconstructed), and the print-object stub.

This module is best read as a **wire-protocol spec** — the operation set is recoverable from the function names and message-type opcodes, but the implementation is gone.

## What this is for

The KB has lots of strings — constant names (`#$Walking-Generic`), aliases, NL paraphrases, free-text comments. A query like "find me a constant whose name contains 'walk'" is slow over an in-process scan but fast through Lucene's inverted index. So Cyc maintains an external Lucene index alongside the KB and queries it via this connector.

The "semantic search" host name (`*lucene-host*` defaults to `"semanticsearch"`) suggests this was paired with semantic-similarity scoring on top of plain text matching — a typical Lucene use case is "rank these terms by how close they are to this query."

The protocol is one-way request/response: Cyc sends a numbered message, the Lucene server processes it, sends back a result. There's no streaming, no subscription, no async push.

## Connection config

| Variable | Default | Use |
|---|---|---|
| `*lucene-host*` | `"semanticsearch"` | Hostname of the Lucene server. |
| `*lucene-port*` | `1928` | TCP port. |
| `*lucene-host-override*` | `nil` | If non-nil, overrides `*lucene-host*` at connect time. |
| `*lucene-port-override*` | `nil` | Same for port. |

The `*-override*` parameters are the dynamic-binding escape hatch — useful when running Cyc against a non-default Lucene (test instance, sharded backend, local-dev mock).

`get-lucene-host` and `get-lucene-port` are the accessors that consult the override-then-default chain. Both are stripped, but the design is clear from the variable docstrings.

## Message-type opcodes

Six numbered operations:

| Opcode | Constant | Operation | Direction |
|---|---|---|---|
| 0 | `*init-lucene-session*` | Initialize a session against an index | request |
| 1 | `*add-document*` | Add a document (KB term + searchable strings) | request |
| 2 | `*query*` | Run a Lucene query string | request |
| 3 | `*optimize*` | Compact the index | request |
| 4 | `*close-index*` | Close the index, finalize writes | request |
| 5 | `*new-index-writer*` | Open a writer (with optional overwrite) | request |

The opcodes are positional integers — wire format is presumably `(opcode, payload)` with payload format dependent on opcode. A clean rewrite should use named tags or a proper enum, not magic integers.

The lifecycle is: open session (0) → optionally open writer (5) → add documents (1) → optimize (3) → close (4) → close session (which the macro handles). Or for read-only: open session (0) → query (2) repeatedly → close.

## Data structure: `lucene-session`

```
(defstruct (lucene-session (:conc-name "LUCENE-"))
  host           ; server hostname
  port           ; server port
  connection     ; the underlying TCP socket / stream
  session-type   ; :read or :write (inferred — the with-lucene-session macro takes a "type" arg)
  index          ; name of the Lucene index this session targets
  overwrite)     ; bool — when opening a writer, replace existing index?
```

Constructor: `new-lucene-session host port index type &optional overwrite` (stripped). Auto-finalizer: `lucene-finalize session` (stripped) — closes the connection and presumably the writer.

## The `with-lucene-session` macro

```
(with-lucene-session (session index type &optional (host '(get-lucene-host))
                                                   (port '(get-lucene-port)))
  body...)
```

Reconstructed from Internal Constants evidence. Binds `session` to a fresh `lucene-session` connecting to `index` (a string naming the Lucene index) in `type` mode (presumably `:read` / `:write`), then runs `body`. On exit (normal or unwind), calls `lucene-finalize` to close.

The macro is the **only** ergonomic entry point — every other function takes a session as first argument, so the typical usage is to wrap a session-using block in this macro.

## Operation surface (all stripped)

The functions that operate on a session, ordered by their typical usage flow:

### Session lifecycle

| Function | Use |
|---|---|
| `new-lucene-session host port index type &optional overwrite` | Construct + connect. |
| `lucene-init session host port` | Initialize the session-state with the server (sends opcode 0). |
| `lucene-finalize session` | Close cleanly. |

### Index writing

| Function | Use |
|---|---|
| `lucene-new-index-writer session &optional overwrite` | Open a writer (opcode 5). |
| `lucene-add-document session term-string concept-string confirmed-terms-string boost-value &optional document-id non-linking-phrase-string` | Add one document (opcode 1). The signature reveals the document shape. |
| `lucene-optimize session` | Force index compaction (opcode 3). |
| `lucene-close-index-writer session` | Close the writer (opcode 4). |
| `default-lucene-confirmed-terms-boost` | Default value for the boost parameter. |

### Index querying

| Function | Use |
|---|---|
| `lucene-query session query-string &optional max-results` | Run a query (opcode 2). |

### Wire-level helpers

| Function | Use |
|---|---|
| `lucene-send session message-type message` | Encode and send. |
| `lucene-receive session` | Block-and-read response. |
| `lucene-execute session message-type message` | send + receive in one call. |
| `interpret-lucene-response response` | Parse a received response into something useful. |

The send/receive layer is the wire codec. The `interpret-lucene-response` is the response-side parser — the result of a query, for example, would be a list of `(document-id, score)` tuples, parsed from whatever bytes the Lucene server returned.

## Document shape

`lucene-add-document` takes:

| Parameter | Meaning |
|---|---|
| `term-string` | The CycL term being indexed, as a string (e.g. `"#$Walking-Generic"`). |
| `concept-string` | The concept's main searchable text (probably the constant's name + aliases). |
| `confirmed-terms-string` | Terms that have been *confirmed* — manually-curated synonyms vs. auto-extracted ones. |
| `boost-value` | Lucene per-document boost. |
| `document-id` | Optional explicit doc id; otherwise Lucene auto-assigns. |
| `non-linking-phrase-string` | Phrases that should be searchable but should not link to this term in extractions. |

This is a fairly specific schema for "Cyc constant indexed for semantic search." A clean rewrite either preserves the parameter set as-is or renames to a structure (e.g. `add-document session document-record`).

The "linking-phrase" / "non-linking-phrase" distinction suggests Cyc has a downstream NL pipeline that, when it encounters a phrase in text, looks it up in Lucene to get a candidate term, and the "non-linking" phrases are searchable but should not produce a link suggestion. (This is used for things like "the" or function-word phrases that need to be in the index for completeness but should never be candidates for term extraction.)

## When does Lucene get used?

In the LarKC port: **never**. There are no callers in the rest of the codebase. The connector is dormant — no live KB code path opens a Lucene session, adds documents, or queries.

In the full Cyc engine, the implied callers are:
1. **Indexing tools** that walk the KB on a schedule and re-emit Lucene documents for each constant.
2. **NL extraction code** that takes a phrase from text and queries Lucene for candidate term matches.
3. **Constant completion** ([core-kb/constants.md](../core-kb/constants.md)) — the `constant-completion-*` files are partially Lucene-aware in the original, but in the LarKC port that integration is also stripped.

The dormant state means the design intent is recoverable only from the API surface, not from live use.

## Notes for a clean rewrite

- **Use a real Lucene client library.** Apache Lucene has Java APIs natively; Solr and Elasticsearch are server wrappers around Lucene with mature client SDKs in every language. Don't write a custom TCP wire protocol when a JAR / HTTP REST adapter exists.
- **The numbered-opcode wire protocol is a 2009-era custom thing.** Solr and Elasticsearch speak HTTP/JSON; even raw Lucene from Java is straight method calls. Drop the opcode integers entirely.
- **The "semanticsearch" hostname** is a Cyc-specific deployment thing. Make it a config-file parameter, not a default constant.
- **Port 1928 is a custom port** — pick whatever the chosen library uses (Solr default 8983, Elasticsearch default 9200).
- **The document shape (term-string, concept-string, confirmed-terms-string, etc.) IS reusable** as a domain model. Keep it. A struct or record type with these fields is the bridge from Cyc's "what should be indexed about a term" to whatever search backend handles it.
- **Boost values should default but be tunable per-document.** `default-lucene-confirmed-terms-boost` is the right shape; carry forward.
- **The "linking-phrase / non-linking-phrase" distinction** is a Cyc-specific feature about how NL extraction relates to the index. Preserve it — it's a real concept.
- **The `:read` / `:write` session-type split** maps to Lucene's `IndexReader`/`IndexWriter` distinction. Keep it; preserve the invariant that a session is one or the other (no read-then-write upgrades — the underlying library doesn't allow it cleanly).
- **`overwrite` should be a keyword arg**, not positional optional. The current shape (`new-lucene-session host port index type &optional overwrite`) buries an important semantic flag.
- **Add a "test/staging index" config dimension.** Most installations want a primary index and a backup; the `*-override*` vars exist for ad-hoc switching but a clean rewrite should have a "named-index" abstraction with multiple configured backends.
- **The auto-finalize via `with-lucene-session`** is correct and worth keeping — RAII-style resource management for sessions.
- **`lucene-send` / `lucene-receive` / `lucene-execute`** are the wire-level layer. A clean rewrite using a real client library doesn't need these — but if writing a custom protocol, factor the same way: encode/decode separately, with a one-call helper.
- **No retry, no timeout on `lucene-receive`.** A clean rewrite must add: timeouts (Lucene optimize can take minutes), retries with backoff, circuit breakers if the search service is down.
- **No batched add.** `lucene-add-document` adds one. A clean rewrite should have `add-documents documents-list` to batch — Lucene benefits hugely from batched indexing.
- **No incremental indexing tracking.** Cyc has no record here of which constants have been indexed, last-modified timestamps, etc. A clean rewrite needs this — re-indexing the whole KB on every startup is too slow.
- **Document IDs should be deterministic** — using the constant's GUID as the document ID makes re-indexing idempotent. The current `&optional document-id` lets it be nil (auto-assigned), which is the wrong default for a KB-driven indexer.
- **Consider dropping Lucene entirely** for in-memory or embedded full-text search if KB is small enough. Lucene shines on millions of documents; a 100K-constant KB might be better served by an in-memory inverted index in the same process.
