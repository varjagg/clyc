# SDBC (SubL Database Connectivity)

A **JDBC-style client connector to a relational database** via a Java proxy server. Cyc opens a TCP connection to a separate Java proxy process (which speaks JDBC to PostgreSQL or another DBMS), then sends numbered commands corresponding to JDBC's `Connection`/`Statement`/`PreparedStatement`/`ResultSet` operations. The wire format is a custom command/response protocol; the real database driver lives in the Java proxy.

The implementation is `sdbc.lisp`. **The functional code is entirely missing-larkc** — only the data structures, the command/response/error opcodes, configuration constants, and the proxy address survive in the port. Every operation function (`new-sql-connection`, `sqlc-execute`, `sqls-execute-query`, `sqlrs-next`, etc.) is a commented stub. The macros (`with-sql-connection`, `with-sql-statement`, `with-prepared-sql-statement`, `with-sql-transaction`, `with-sql-result-set`, `do-sql-result-set`, `sqls-execute-transaction`) are *not* even reconstructed — declared as commented-out declareMacros only.

What's here is essentially the **wire-protocol catalog** plus the **client-side data shapes**.

(The README incorrectly groups `sdc.lisp` as a sibling here. `sdc.lisp` is "Sibling-Disjoint Collections" — a graph reasoning module about disjointness of collection types, completely unrelated to database connectivity. It belongs under [graph-reasoning/](../graph-reasoning/) near `named-hierarchies.md`. The README index should be corrected.)

## What problem SDBC solves

Cyc historically wanted to talk to relational databases — for ETL pipelines (loading external data into the KB), for KB persistence experiments (storing KB content as relational tables), and for application-specific extensions (Cyc apps that needed conventional databases alongside the KB).

Going from SubL → JDBC directly was awkward because SubL had no native JDBC binding. The solution: spin up a Java *proxy* process that speaks JDBC on one side and a custom wire protocol on the other. SubL → wire → Java proxy → JDBC → DBMS. The Java proxy is `db-server.cyc.com` in the original deployment.

This is a 2009-era design. A clean rewrite shouldn't need the proxy if the host runtime has direct database bindings (Java does, Python does, modern CL does via `cl-postgres`/`postmodern`).

## The five core data structures

### `sql-connection` (conc-name `SQLC-`)

```
(defstruct sql-connection
  db                ; database name string
  user              ; auth user
  dbms-server       ; hostname of the DBMS itself (not the proxy)
  port              ; DBMS port
  channel           ; TCP stream to the Java proxy
  statements        ; list of open sql-statement / sql-prepared-statement
  lock              ; thread-safety mutex
  subprotocol       ; "postgresql" / "mysql" / etc.
  proxy-server      ; hostname of the Java proxy
  error-handling    ; per-connection error policy tag
  tickets           ; pending request tickets (see "Ticket-based async" below)
  mailman)          ; the dispatch thread for delivering replies
```

The connection has both a `dbms-server` (the actual database) and a `proxy-server` (the Java relay). The `channel` is the TCP stream to the proxy, not to the database directly. The `lock` is mandatory because the protocol is request/response — concurrent senders would interleave bytes on the wire.

### `sql-ticket`

```
(defstruct sql-ticket
  semaphore         ; released when the response arrives
  result)           ; populated by the mailman thread
```

A ticket is the async-receive primitive: caller submits a request, gets a ticket, blocks on the ticket's semaphore. The mailman thread reads incoming responses and matches each to a ticket by sequence; when matched, it sets `result` and releases the semaphore.

### `sdbc-error`

```
(defstruct sdbc-error
  type              ; error-code keyword (one of *io-error* etc.)
  message           ; human-readable text
  code)             ; per-DBMS error code (from JDBC SQLState)
```

An error is its own struct rather than a thrown condition because it travels over the wire — the proxy serializes errors as messages, and the client wraps them in this shape for caller inspection.

### `sql-result-set` (conc-name `SQLRS-`)

```
(defstruct sql-result-set
  rows              ; locally-cached rows
  current           ; current cursor position
  last              ; last row index seen
  start             ; index where local block begins
  connection        ; back-pointer to the originating connection
  block-size        ; how many rows to fetch at a time
  id)               ; result-set identifier on the proxy side
```

Result sets are paged: the proxy keeps the full result, the client locally caches `block-size` rows at a time. `*result-set-block-size*` defaults to 1000. Cursor operations (`sqlrs-next`, `sqlrs-previous`, `sqlrs-absolute`) move within the local block when possible and refetch from the proxy when out of range.

The local-vs-remote distinction is exposed as `sqlrs-row-local-p` / `sqlrs-row-remote-p` (stripped) — useful for performance debugging ("am I about to round-trip?").

### `sql-statement` (conc-name `SQLS-`)

```
(defstruct sql-statement
  connection        ; the parent connection
  id                ; statement identifier on the proxy
  sql               ; the SQL text (or template, for prepared statements)
  settings          ; map of per-statement settings (timeout, fetch size, etc.)
  batch             ; list of pending batched SQL strings
  rs)               ; the current open result-set, if any
```

Used for both `sql-statement` (regular) and `sql-prepared-statement` (parameterized, with `set-int`/`set-string`/etc. operations on bind variables). The current port doesn't separate the two structs — both share the same shape.

## Wire-protocol opcodes

Three classes of opcodes, all numbered:

### Commands (client → proxy)

| Code | Constant | Operation |
|---|---|---|
| 0 | `*quit*` | Disconnect. |
| 1 | `*execute-update*` | DML statement (INSERT/UPDATE/DELETE). |
| 2 | `*execute-query*` | DQL statement (SELECT). |
| 3 | `*prepare-statement*` | Compile a parameterized statement. |
| 4 | `*create-statement*` | Open a regular (non-prepared) statement. |
| 5 | `*set-bytes*` | Bind a byte-array parameter. |
| 6 | `*ps-execute-update*` | Execute a prepared-statement DML. |
| 7 | `*ps-execute-query*` | Execute a prepared-statement DQL. |
| 8 | `*set-int*` | Bind an int parameter. |
| 9 | `*close-statement*` | Close a statement. |
| 10 | `*new-connection*` | Open a connection. |
| 11 | `*set-string*` | Bind a string parameter. |
| 12 | `*set-long*` | Bind a long parameter. |
| 13 | `*set-double*` | Bind a double parameter. |
| 14 | `*set-float*` | Bind a float parameter. |
| 15 | `*execute-batch*` | Send the batch. |
| 16 | `*get-rows*` | Fetch next block of rows. |
| 17 | `*close-result-set*` | Close a result-set on the proxy. |
| 18 | `*execute-update-auto-keys*` | Update with auto-generated keys returned. |
| 19 | `*get-generated-keys*` | Fetch generated keys from last update. |
| 20 | `*set-auto-commit*` | Toggle auto-commit. |
| 21 | `*commit*` | Commit transaction. |
| 22 | `*rollback*` | Roll back transaction. |
| 23 | `*get-transaction-isolation*` | Read isolation level. |
| 24 | `*set-transaction-isolation*` | Set isolation level. |
| 25 | `*get-auto-commit*` | Read auto-commit state. |
| 26 | `*get-tables*` | DatabaseMetaData.getTables. |
| 27 | `*get-columns*` | getColumns. |
| 28 | `*get-primary-keys*` | getPrimaryKeys. |
| 29 | `*get-imported-keys*` | getImportedKeys (foreign keys this table references). |
| 30 | `*get-exported-keys*` | getExportedKeys (foreign keys referencing this table). |
| 31 | `*get-index-info*` | getIndexInfo. |
| 32 | `*cancel*` | Cancel a running statement. |
| 33 | `*get-max-connections*` | Read pool's max connections. |

The opcode set tracks JDBC's `Connection` / `Statement` / `PreparedStatement` / `DatabaseMetaData` interfaces 1:1. This is essentially "JDBC over our custom protocol."

### Responses (proxy → client)

| Code | Constant | Payload type |
|---|---|---|
| 0 | `*stop-response*` | End of multi-message response (terminator). |
| 1 | `*integer-response*` | Single integer. |
| 2 | `*result-set-response*` | Beginning of a result-set; rows follow until `*stop-response*`. |
| 3 | `*void-response*` | Acknowledgement for a void-return command. |
| 4 | `*connection*` | A new connection's id. |
| 5 | `*update-counts*` | Batch update counts (one int per batched stmt). |
| 6 | `*transaction-isolation-level*` | Iso level enum value. |
| 7 | `*boolean*` | Boolean. |

The streamed nature of result-sets (chunks until terminator) is why result-sets carry their own `id` and live on the proxy until explicitly closed — a half-streamed result-set must be drainable on demand.

### Errors (proxy → client)

| Code | Constant | Class |
|---|---|---|
| -1 | `*io-error*` | Network / proxy I/O failure. |
| -2 | `*sql-error*` | DBMS reported a SQL error. |
| -3 | `*unknown-error*` | Unclassified. |
| -4 | `*client-error*` | Client-side mis-use (e.g. close on already-closed). |
| -5 | `*commit-error*` | Commit failed. |
| -6 | `*rollback-error*` | Rollback failed. |
| -7 | `*transaction-error*` | Transaction-level error (deadlock, isolation conflict). |
| -8 | `*batch-update-error*` | One or more statements in a batch failed. |

`*sdbc-error-decoding*` maps these codes to a string suffix appended to the error class for diagnostic output (`-IO`, `-SQL`, `-CLIENT`, etc.).

## Configuration

| Variable | Default | Use |
|---|---|---|
| `*dbms-server*` | `"db-server.cyc.com"` | DBMS host. |
| `*sdbc-proxy-server*` | `"db-server.cyc.com"` | Proxy host (same machine in default deploy). |
| `*sql-port*` | `9999` | DBMS port (proxy listens here). |
| `*sql-protocol*` | `"jdbc"` | URL protocol scheme. |
| `*sql-subprotocol*` | `"postgresql"` | JDBC subprotocol — selects driver on proxy. |
| `*sql-connection-timeout*` | `5` | Connect timeout in seconds. |
| `*connection-id*` | `"CONNECTION"` | Sentinel for "this is a connection-create request." |
| `*result-set-block-size*` | `1000` | Page size for cursor walks. |
| `*sdbc-test-row-cardinality*` | `25` | Rows used by `sdbc-test*` self-tests. |

## Ticket-based async

The `sql-ticket` shape and the `mailman` slot on connection together implement one-connection-many-pending requests. Wire layer (all stripped):

| Function | Use |
|---|---|
| `new-sql-ticket` | Create a fresh ticket. |
| `sql-ticket-retrieve ticket` | Block on the ticket's semaphore until result arrives. |
| `launch-sql-mailman connection` | Start the mailman thread for this connection. |
| `sqlc-deliver connection` | Mailman's main loop: read response, find matching ticket, fill result, signal semaphore. |
| `sqlc-execute connection command args` | Synchronous send-and-wait. |
| `sqlc-send connection ticket command args` | Async send (returns immediately; ticket is the receipt). |
| `sqlc-receive connection` | Drain one response from the wire (used by mailman). |

The pattern is: caller calls `sqlc-execute` for normal sync use, or `sqlc-send + sql-ticket-retrieve` to overlap multiple in-flight requests. The mailman is the single-thread reader that demultiplexes responses.

## Operation surface (all stripped, organized by struct)

### Connection (`sqlc-`)

`new-sql-connection`, `sqlc-close`, `sqlc-create-statement`, `sqlc-prepare-statement`, `sqlc-set-auto-commit`, `sqlc-get-auto-commit`, `sqlc-commit`, `sqlc-rollback`, `sqlc-get-transaction-isolation`, `sqlc-set-transaction-isolation`, `sqlc-set-error-handling`, `sqlc-get-tables(-meta-data)`, `sqlc-get-columns(-meta-data)`, `sqlc-get-primary-keys(-meta-data)`, `sqlc-get-imported-keys(-meta-data)`, `sqlc-get-exported-keys(-meta-data)`, `sqlc-get-index-info(-meta-data)`, `sqlc-get-max-connections`, `sql-open-connection-p`, `sqlc-open-p`.

### Statement (`sqls-`)

`new-sql-statement`, `sqls-execute-query`, `sqls-execute-update`, `sqls-cancel`, `sqls-get-generated-keys`, `sqls-close`, `sqls-add-batch`, `sqls-clear-batch`, `sqls-execute-batch`, `sqls-open-p`, `sql-open-statement-p`, `sqls-get-connection`, `sqls-local-close`, `sqls-handle-commit-error`, `sqls-handle-rollback`, `sqls-handle-transaction-errors`.

### Prepared Statement (`sqlps-`)

`new-sql-prepared-statement`, `sqlps-execute-query`, `sqlps-execute-update`, `sqlps-set-bytes`, `sqlps-set-int`, `sqlps-set-long`, `sqlps-set-float`, `sqlps-set-double`, `sqlps-set-string`, `sqlps-set` (generic dispatch), `sql-prepared-statement-p`, `sql-prepared-open-statement-p`.

### Result-Set (`sqlrs-`)

`new-sql-result-set`, `sqlrs-close`, `sqlrs-empty?`, `sqlrs-absolute`, `sqlrs-next`, `sqlrs-previous`, `sqlrs-is-last`, `sqlrs-is-first`, `sqlrs-column-count`, `sqlrs-row-count`, `sqlrs-get-row`, `sqlrs-get-object`, `sqlrs-get-object-tuple`, `sqlrs-block`, `sqlrs-row-local-p`, `sqlrs-row-remote-p`, `sqlrs-local-close`, `sql-open-result-set-p`, `sqlrs-closed-p`, `sqlrs-open-p`, `sqlrs-valid-row-p`, `sqlrs-valid-column-p`.

### Errors and tags

`new-sdbc-error`, `sdbc-error-throw`, `sdbc-error-warn`, `sdbc-server-error-p`, `sdbc-client-error-p`, `sdbc-sql-error-p`, `sdbc-io-error-p`, `sdbc-transaction-error-p`, `sdbc-batch-update-error-p`, `sdbc-other-error-p`, `decode-sdbc-error-code`, `sdbc-error-handling-tag-p`, `sql-transaction-level-p`, `sql-null-p`, `sql-true-p`, `sql-false-p`.

### Helpers

`sql-export` (export a result-set to a stream with column separator), `sql-proxy-server-running?` (heartbeat), `new-db-url` (build the JDBC URL string), `java-integerp`/`-longp`/`-floatp`/`-doublep` (Java numeric range predicates for parameter validation), `new-statement-id` / `new-result-set-id` (id allocators).

### Self-test

`sdbc-test`, `sdbc-test-prepared`, `sdbc-test-created`, `sdbc-test-batch` — round-trip sanity checks against a real database. Each takes db/user/password and runs a fixed set of `*sdbc-test-row-cardinality*` rows of insert/query/cleanup operations.

## The seven missing macros

Declared but not reconstructed in the port:

| Macro | Likely shape |
|---|---|
| `with-sql-connection` | `(with-sql-connection (conn db user password &rest opts) body...)` — auto-closes on exit |
| `with-sql-statement` | `(with-sql-statement (stmt conn) body...)` — auto-closes |
| `with-prepared-sql-statement` | `(with-prepared-sql-statement (ps conn sql) body...)` — auto-closes |
| `sqls-execute-transaction` | `(sqls-execute-transaction (conn) body...)` — wraps body in begin/commit, rolls back on error |
| `with-sql-transaction` | Probably alias for above. |
| `with-sql-result-set` | `(with-sql-result-set (rs stmt) body...)` — auto-closes |
| `do-sql-result-set` | `(do-sql-result-set (row rs) body...)` — iterates rows |

The setup phase registers `sqls-execute-transaction` as the parent macro for `sqlc-set-error-handling`, `sqls-get-connection`, `sqls-handle-commit-error`, `sqls-handle-rollback`, `sqls-handle-transaction-errors` — these are macro-helpers used inside the transaction macro's expansion.

A clean rewrite needs all seven; their semantics are mechanically derivable from the function set.

## When does SDBC get used?

In the LarKC port: **never**. There are no callers anywhere in the codebase. The connector is dormant.

In the full Cyc engine, the implied callers are:
1. **ETL tools** that load external relational data into the KB.
2. **Application-specific Cyc apps** that need a DBMS alongside the KB (e.g. for storing user state, audit logs, multimedia blobs).
3. **Test/dev tooling** that uses the `sdbc-test*` self-tests.

The dormant state means the design intent is fully recoverable from the API surface (JDBC parity) but no live integration to study.

## Notes for a clean rewrite

- **Drop the Java proxy layer.** Modern CL (or any modern host) has direct database bindings. `cl-postgres`/`postmodern` for PostgreSQL, `cl-dbi` as a driver-agnostic layer, or whatever the host provides. The Java proxy was a 2009 workaround for SubL's lack of DB bindings; nothing in 2026 needs it.
- **Use a real DB library.** Don't reimplement JDBC over a custom wire protocol. The opcode tables here are useful as a *reference* for "what operations does a DB connector need to support," but as code they're obsolete.
- **Keep the data structure shapes** for the wrapped types (`sql-connection`, `sql-result-set`, `sql-statement`) — they're a reasonable abstraction over the underlying library's primitives. Use them as the Cyc-facing API and delegate internals to the DB library.
- **Drop the ticket/mailman async layer.** Modern DB libraries handle their own connection pooling and async/await. The ticket pattern was for round-tripping over a single socket; with a real connection pool, just open multiple connections.
- **The 1000-row block-size default is too small for analytical queries and too large for OLTP.** Make it per-query. Default should match the DB driver's recommendation.
- **The `*sql-protocol*`/`*sql-subprotocol*`/`*sql-port*` config is JDBC-specific.** A clean rewrite should use a single connection-string parameter (Postgres URI, JDBC URL, whatever) instead of three separate dials.
- **`new-db-url`** builds the connection URL by concatenation. Real libraries handle this themselves; drop it.
- **The error taxonomy (8 classes)** is JDBC-derived and worth keeping mostly as-is. `*io-error*` (network), `*sql-error*` (DBMS), `*client-error*` (mis-use), `*commit-error*` / `*rollback-error*` / `*transaction-error*`, `*batch-update-error*`. A clean rewrite should expose these as a sealed enum; clients should be able to switch on them.
- **`java-integerp`/`-longp`/`-floatp`/`-doublep`** were range-check predicates because Java has 32-bit int / 64-bit long / 32-bit float / 64-bit double, and SubL ints are arbitrary-precision. The clean rewrite needs equivalents only if the target DB has narrower numeric types than the host language; otherwise drop. PostgreSQL has its own type system (smallint/int/bigint/numeric/real/double precision); coerce at bind time.
- **Auto-commit defaults differ between drivers.** Always set explicitly; never assume.
- **The seven missing macros are the user-friendly API.** A clean rewrite needs them all, plus modern equivalents: `with-connection`, `with-transaction`, `with-prepared-statement`, `do-rows` iterator. The error-handling-aware transaction macro is critical — must rollback on any error and commit on clean exit.
- **`sql-export`** as a result-set serializer is useful — keep an equivalent for "dump a query result as CSV." But pick a real CSV library; don't reinvent quoting rules.
- **The metadata operations (`get-tables`, `get-columns`, etc.)** are JDBC's `DatabaseMetaData` and are well-shaped. Keep them but expose via a `metadata` namespace, not flat on the connection.
- **`sql-null-p`/`sql-true-p`/`sql-false-p`** predicates suggest the proxy returns SQL NULLs and booleans as distinguished sentinel values rather than nil/t. A clean rewrite should pick host conventions: SQL NULL → CL nil (with explicit flag), booleans → t/nil. Or use a 3-valued logic library if the application semantically needs to distinguish NULL from FALSE.
- **No connection pooling.** The current model is one connection per `sql-connection` struct; no reuse. A clean rewrite needs pooling — every modern application server has it.
- **No prepared-statement caching.** `sqlc-prepare-statement` builds a new one each call. A clean rewrite should cache by SQL text.
- **No statement timeout enforcement.** `*sql-connection-timeout*` covers connect only, not query. Add a query timeout per call.
- **Transaction isolation levels are exposed but nothing forces them at code-write time.** A clean rewrite should make isolation level part of the transaction context: `(with-transaction (:isolation :serializable) ...)`.
- **The `*ignoring-sdc?*` etc. parameters in the `sdc.lisp` confused-with-this-module are unrelated.** Make sure that file moves to the graph-reasoning category in a README cleanup; the current grouping is a typo.
