# TCP transport

The TCP layer is the **lowest-level transport** for the Cyc API and CFASL channels. It provides:

- Server-side port-binding and per-connection thread spawning.
- Server-type registration: `:cyc-api`, `:cfasl-server`, `:html`, `:transcript-server`, etc. each register a handler function and a wire mode (`:text` or `:binary`); enabling a server-type binds it to a port.
- Client-side `open-tcp-stream` for outbound connections (used by remote-image and the transcript-server client).
- Stream buffering primitives (`stream-buffer`, `string-buffer`) for line-oriented IO over a TCP stream.

Three source files cover this:

- `tcp.lisp` (71 lines) — thin wrapper over `usocket` for the host-CL implementation. `open-tcp-stream` and `start-tcp-server` / `stop-tcp-server` plus a port → listener-socket map. This file is the porting-time bridge — Java's `java.net.ServerSocket` plumbing replaced with usocket calls.
- `tcp-server-utilities.lisp` (144 lines) — the SubL-side server-type registry (`register-tcp-server-type`), the `tcp-server` defstruct, and the enable/disable lifecycle. This is where servers are *named* and where a port + handler is associated with a name.
- `stream-buffer.lisp` (168 lines) — buffered line reader for streams. Two structs (`string-buffer`, `stream-buffer`), two macros (`do-file-lines-buffered`, `do-stream-lines-buffered`), one struct constructor each. **Almost entirely missing-larkc** — only the structs and the iteration macros survived; the buffer-fill, line-read, reset/destroy primitives are stripped.

## Port mapping

Cyc's TCP services are all offsets from a base port (`*base-tcp-port*` = 3600 by default):

| Service | Offset | Default port | Mode |
|---|---|---|---|
| Cyc API | `*fi-port-offset*` = 1 | 3601 | `:text` |
| CFASL server | `*cfasl-port-offset*` = 14 | 3614 | `:binary` |
| HTML server | (separate, in `*html-port*`) | varies | `:text` |
| Transcript server | `*master-transcript-server-port*` = 3608 | 3608 | (client-side only — Cyc connects out) |

Other historical offsets (Java/SDC/etc.) exist but the LarKC port has stripped them.

`*tcp-localhost-only?*` (defaults NIL = remote allowed) gates whether the listening socket binds to `0.0.0.0` or `127.0.0.1`. The default is *less* secure than the docstring recommends — production deployments should set this to T and front Cyc with a reverse proxy.

`*permit-api-host-access*` (defaults T) is the orthogonal gate — when T, API requests can call host functions like `read`, `open`, `make-process`, `kill-process`. The documentation explicitly recommends NIL for production.

## When does a TCP server come into being?

Server lifecycle has two phases — **type registration** and **port binding**:

1. **Type registration**: at image startup, each module that wants to expose a server calls `(register-tcp-server-type type handler &optional mode)`. This adds an entry to `*tcp-server-type-table*` (a list of `(type handler mode)` triples) but does *not* open a port. The `:cyc-api` type is registered by `api-kernel.lisp:274`. Other types (`:cfasl-server`, `:html`, transcript-server-side, etc.) are registered by their respective modules.

2. **Port binding**: `(enable-tcp-server type port)` looks up the type's handler from the table and spawns a listener thread on the port. Each accepted connection invokes the handler with the connection stream. The current implementation uses usocket's multi-threaded `socket-server` — one thread per connection. The listener thread is recorded in `*port-to-server-socket-process-map*` (port → usocket listener socket) for shutdown purposes.

`enable-tcp-server` is the *system-startup* path. `(use-transcript-server)`, `(start-agenda)`, etc. all assume the relevant servers have been enabled. The startup sequence (in `cyc-kernel.lisp`) calls `enable-tcp-server` on each registered type with its corresponding port.

The two-phase design (register-type / enable-port) lets multiple ports use the same handler — though in practice each type has exactly one port. The flexibility is mostly cosmetic.

## When does a TCP server change or disappear?

| Trigger | Effect |
|---|---|
| `(disable-tcp-server <designator>)` | If a tcp-server struct: `missing-larkc 31593` (likely halts the listener thread + closes the socket). If a port number: looks up the server by port, recurses. If a type symbol: iterates `all-tcp-servers` and disables each whose type matches `missing-larkc 31597`. Returns total count disabled. |
| `(stop-tcp-server port)` | The lower-level `tcp.lisp` form: looks up the listener in `*port-to-server-socket-process-map*`, removes it, and (in usocket) closes it. Used by `disable-tcp-server`. |
| `(validate-all-tcp-servers)` | Iterates all servers, checks each one's listener thread via `valid-process-p`; disables any whose listener is dead. Called on startup or recovery. |
| `(deregister-tcp-server-type type)` | Removes the type from `*tcp-server-type-table*`. Doesn't disable any active servers using the type. |
| Client connection drops | The handler thread for that connection unwinds (most handlers wrap their loop in `catch :api-quit` or similar). Listener stays up and accepts new connections. |
| Image shutdown | All listener threads are killed; the registry tables are not preserved. |

The interesting nuance: the **type registry** (`*tcp-server-type-table*`) and the **active-server list** (`*all-tcp-servers*`) are independent. Disabling a server doesn't deregister its type; deregistering a type doesn't disable its active server. They're two separate registries linked only by the type symbol.

## The data structures

### `tcp-server` defstruct

```
(defstruct (tcp-server (:conc-name "TCPS-"))
  type                                    ; the symbol (:cyc-api, :cfasl-server, ...)
  (port nil :type (or null fixnum))        ; NIL if disabled
  process)                                  ; the listener thread (usocket socket)
```

One per active server. `port = NIL` is the "disabled but still in the list" sentinel — the handler can outlive its binding while a `disable-tcp-server` is in flight.

### `*tcp-server-type-table*`

A flat list of `(type handler mode)` triples. Lookup is `(find type table :key #'first)`. The table is small (one entry per registered service type, ~5 entries total) so list scan is fine.

### `*all-tcp-servers*`

A flat list of `tcp-server` structs. One per active port-binding. Searched by port via `(find port *all-tcp-servers* :key #'tcp-server-port)`.

### `*port-to-server-socket-process-map*`

A synchronized hashtable in `tcp.lisp`. Independent of `*all-tcp-servers*` — `tcp.lisp` is the host-CL bridge and doesn't know about the SubL-side server structs. `start-tcp-server` (low-level) writes to this map; `stop-tcp-server` reads + removes. The two layers (low-level usocket map + high-level server-struct list) duplicate state and a clean rewrite should consolidate.

## Wire modes

Each registered server type has a `mode` slot:

- `:text` — the handler reads s-expressions from the stream via `read` (with `*read-default-float-format*` set to double-float, `*read-eval*` NIL, etc.). Used by the API and HTML servers.
- `:binary` — the handler reads CFASL opcodes from the stream as raw bytes. Used by the CFASL server. The stream is opened with `:element-type '(unsigned-byte 8)` rather than character.

The mode is consulted by the listener thread when wrapping the raw socket into a stream. In the current implementation `tcp.lisp:open-tcp-stream` always uses `:element-type '(unsigned-byte 8)` (binary) — text-mode wrapping happens at a higher layer.

## The handler protocol

The contract for a registered handler is:

```
(defun handler (in-stream out-stream) ...)
```

Called once per accepted connection. The connection is held open for the duration of the handler call; when the handler returns or unwinds, the connection closes.

`api-server-handler` is one example. `cfasl-server-handler` is another. There is a quirky note in `tcp.lisp`: "the java interface seems to pass the stream into it twice, maybe a reader & writer stream separately". This reflects Cyc's two-stream interface — the handler receives `in-stream` and `out-stream` separately even though they're the same TCP connection. usocket gives a single bi-directional stream; `tcp.lisp` passes it twice as a compatibility shim.

## Outbound TCP

`open-tcp-stream host port` opens a connection out. The companion macro `with-tcp-connection` (in `subl-macro-promotions.lisp`) wraps a body in:

```
(let ((bi-stream (open-tcp-stream-with-timeout host port timeout access-mode)))
  (unwind-protect body (close-tcp-stream bi-stream)))
```

`open-tcp-stream-with-timeout` is LarKC-stripped; it would have used SubL's `with-timeout` to bound the connection attempt. `:access-mode :public` vs `:private` distinguishes between locale-shared (e.g. file streams the user has explicitly opened) and locale-internal connections.

Outbound TCP is consumed by:

- `cyc-api-remote-eval` (in `api-kernel.lisp` — LarKC-stripped) for one-shot remote API calls.
- The transcript-server client (`transcript-server.lisp` — LarKC-stripped) for the `with-transcript-server-connection` macro.
- `web-utilities.lisp:226` for HTTP fetches.
- `lucene-session.lisp` (mostly stripped) for the Lucene search-engine connection.

## Stream buffering

`stream-buffer.lisp` is **the buffered line-reader for byte streams**. Almost the whole file is missing-larkc — what survived is the structs and the two iteration macros.

### `string-buffer` defstruct

```
(defstruct (string-buffer (:conc-name "STRBUF-"))
  string                ; the underlying CL string (mutable)
  position)             ; current write position (= length when full)
```

A growable string buffer. `string-buffer-add char`, `string-buffer-add-sequence string &optional start end`, `string-buffer-reset` etc. are all stripped. The reconstructed `with-string-buffer ((str-var pos-var) string-buffer) body` macro destructures a string-buffer for inspection.

`*dtp-string-buffer*` = `'string-buffer` is the type tag.

### `stream-buffer` defstruct

```
(defstruct (stream-buffer (:conc-name "STRM-BUF-"))
  stream                ; underlying char stream
  buffer                ; a string-buffer holding chunks read from the stream
  end                   ; logical end position in buffer
  position)             ; logical current read position in buffer
```

A read-buffered wrapper around a stream. The buffer holds one block (`*default-block-size*` worth) of characters; when `position` reaches `end`, `stream-buffer-load` refills the buffer from the underlying stream. The line-reader iterates the buffer looking for newlines and produces one line per call into a `string-buffer` of its own.

`*dtp-stream-buffer*` = `'stream-buffer`.

### The line-iteration macros

Two macros that wrap the iteration:

```
(do-file-lines-buffered (line-buffer-var filename &key block-size done) body...)
(do-stream-lines-buffered (line-buffer-var stream &key block-size done) body...)
```

The file form opens `filename` for reading via `with-private-text-file`, then delegates to the stream form. The stream form initialises a stream-buffer + line-buffer pair, loops calling `do-stream-lines-buffered-next` until it returns NIL (end of stream), runs `body` on each line, and finalises in an unwind-protect.

`block-size` controls the underlying buffer size. `done` is an optional boolean expression — when T after a body run, the loop terminates early.

The three helpers used by the macro (`do-stream-lines-buffered-initialize`, `do-stream-lines-buffered-next`, `do-stream-lines-buffered-finalize`) are LarKC-stripped. Same for the iterator-state object form (`new-stream-line-iterator`, `stream-line-iterator-done?`, `stream-line-iterator-next`, `stream-line-iterator-finalize`) which is the non-macro alternative for iteration.

## How other systems consume TCP transport

- **API kernel** ([cyc-api.md](cyc-api.md)) — the only `register-tcp-server-type` call site in the LarKC port (`api-kernel.lisp:274`). Other server types (CFASL, HTML, transcript) would have their own registrations but those modules are mostly stripped.
- **System startup** (`cyc-kernel.lisp`, see [control-vars.md](control-vars.md)) — calls `enable-tcp-server` on each registered type using the corresponding `*X-port-offset*`-derived port.
- **Outbound clients**: `cyc-api-remote-eval` (api-kernel), web-utilities, transcript-server client, lucene-session — all use `open-tcp-stream` (or `with-tcp-connection`).
- **`*permit-api-host-access*`** is consumed by `eval-in-api` to gate calls into `*api-predefined-host-function-table*` (which contains `open-tcp-stream`, `make-process`, `read`, etc.).
- **Stream buffering** is consumed nowhere visible in the current port — every direct caller of `do-stream-lines-buffered` was in a stripped function. The macros remain because they're API-callable from external code (e.g. a `(load-file)` API call that wants buffered iteration).

## Notes for a clean rewrite

- **`tcp.lisp` and `tcp-server-utilities.lisp` are two halves of one system.** The split exists because the originals were `Tcp.java` (Java-side) and `tcp-server-utilities.lisp` (SubL-side). A clean rewrite has one module: open/listen/close and a registry of named services.
- **The two registries (`*tcp-server-type-table*` + `*all-tcp-servers*` + `*port-to-server-socket-process-map*`) collapse to one.** A single struct per active server, holding type, port, handler, mode, and listener thread. Lookup by any field via a hashtable index.
- **Modes (`:text` / `:binary`) belong on the handler, not on the type registration.** The handler knows what it expects on the wire. A clean rewrite has handlers receive a raw byte stream and choose their decoder.
- **`*tcp-localhost-only?* = NIL` is the wrong default.** Bind to localhost by default; require explicit opt-in for remote. The current default exposes a Cyc image to the network with no auth — that's fine in 2003, dangerous in 2026.
- **TLS, mutual auth, per-connection identity.** The current transport is plaintext and trusts whoever opens a socket. A clean rewrite must terminate TLS (or expose a Unix socket and require an external proxy for TLS). Per-connection identity (the `*the-cyclist*`) should come from auth, not from a client-supplied form.
- **Drop `*permit-api-host-access*`.** It's a global flag for "is this image trusted enough to call open?" — replace with per-cyclist permissions. The API caller should be denied `(make-process)` because *they* lack the privilege, not because the *image* lacks it.
- **Replace `usocket` with the host language's standard async I/O.** Modern async (Tokio / asyncio / Node / Go's goroutines) handle thousands of concurrent connections per thread. The current "one OS thread per connection" model is wasteful — but acceptable while max API connections is small (a handful of editor clients). If the API is exposed broadly, switch to async.
- **`tcp-server-port` is `tcps-port` is `tcp-server-port`.** Drop the `tcps-` conc-name; just use field accessors. The defstruct boilerplate is SubL-flavored.
- **Stream-buffer is half-implemented; don't fix it, drop it.** Modern hosts have line-buffered stream APIs (CL has `read-line`, Python has `for line in file`). The Cyc layer adds nothing that the host doesn't already do better. The two iteration macros become `(do-each-line file body)` wrapping the host primitive.
- **`with-tcp-connection` macro can stay.** `with-` macros for resource management are the right pattern. Keep but rebuild on top of the new transport — pass a `Connection` object that carries auth, encoding, and identity instead of just `(stream)`.
- **Port-offset arithmetic is pure cargo.** `*base-tcp-port* + *fi-port-offset*` was needed when one host had multiple Cyc images and you wanted predictable port allocation. Modern deployments use container orchestration; each Cyc image gets its own pod with one port. Drop the offset machinery and bind each service to a configured port directly.
- **`disable-tcp-server` accepts a server, a port, *or* a type symbol.** Three different shapes for the same operation. Pick one (probably the server struct, since that's what `enable-tcp-server` returns) and let callers look up by port or type via a separate `find-server` call.
- **The `:access-mode :public` / `:private` distinction in `with-tcp-connection` is unused in the LarKC port.** Either drop it or document the threat model that requires it. The Java had this for "trusted file" vs. "world-accessible URL"; without that distinction, a clean rewrite has just one access mode.
