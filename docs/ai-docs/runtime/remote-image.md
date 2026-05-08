# Remote image — cross-image RPC

A **remote image** is another running Cyc instance, identified by `(machine, port, protocol)`. The remote-image system is a thin client-side abstraction for **opening a long-lived connection to another Cyc image and evaluating forms on it remotely** — the inverse of the API server.

The implementation is `remote-image.lisp` (154 lines). **Almost the whole file is missing-larkc**: the surviving pieces are two defstructs, three predicates, two reconstructed macros, and a parameter. The actual connection-opening, channel-eval, and lifecycle-management functions are stripped.

## Why this exists

The Cyc API server ([cyc-api.md](cyc-api.md)) accepts inbound requests. The remote-image client is the **outbound** counterpart — when *this* image needs to call out to a peer image. Use cases:

- The transcript-server flow: `*master-transcript-lock-host*` is a different machine running a transcript server; this image opens connections to it.
- Distributed inference: a query runs on this image but a sub-problem is delegated to a different image (e.g. one with a richer KB or specialised modules).
- KB sync: `cyc-api-remote-eval` ([cyc-api.md](cyc-api.md)) opens a one-shot connection, runs a form, closes — useful for asking a peer image "do you have constant X?" without keeping a connection.

Cross-image evaluation works because both sides use the **same CFASL externalised mode** ([../persistence/cfasl.md](../persistence/cfasl.md)): GUIDs identify constants across image boundaries even when their local handle ids differ.

## The two structs

### `remote-image`

```
(defstruct (remote-image (:conc-name "RMT-IMG-"))
  machine    ; hostname string
  port       ; TCP port (integer)
  protocol)  ; codec hint: :text, :binary, :cfasl
```

A `remote-image` is **immutable identity** — it describes "that image over there." A single `remote-image` can be shared by many connections. The `protocol` slot picks the wire format; current values are `:text` (s-expression eval) and `:cfasl` (binary CFASL stream). The CFASL protocol uses the `:cfasl-server` port (`*base-tcp-port* + *cfasl-port-offset*`) on the remote side; the text protocol uses the `:cyc-api` port.

### `remote-image-connection`

```
(defstruct (remote-image-connection (:conc-name "RMT-IMG-CONN-"))
  image        ; the remote-image this connects to
  channel)     ; the live channel object (TCP stream + codec state)
```

A `remote-image-connection` is **a live binding** — it represents an open TCP connection to a `remote-image`. The `channel` slot holds the codec-aware stream wrapper; `image` is the back-reference to the identity. Multiple connections can target the same image (parallel calls).

## When does a remote-image come into being?

```
(new-remote-image machine port &optional protocol)
```

`new-remote-image` is LarKC-stripped; based on the slot list and the field accessors, it builds a `remote-image` struct holding the three values. Default protocol is `:text` (the `&optional` arg).

There's no implicit caching of `remote-image` instances — each call mints a new one. Two images with the same `(machine, port, protocol)` triple are distinct structs; equality is by identity, not by content. A clean rewrite probably wants interning.

When does the application call `new-remote-image`? Wherever a peer's address is known — typically read from configuration (`*master-transcript-lock-host*`, `*master-transcript-server-port*`) or supplied explicitly by the user.

## When does a remote-image-connection come into being?

The lifecycle is:

```
(let ((conn (new-remote-image-connection image)))      ; mint
  (open-remote-image-connection conn)                  ; connect
  (with-remote-image-connection (conn)                 ; bind the dynamic env
    ...                                                 ; eval forms
    (remote-image-connection-eval conn form))
  (close-remote-image-connection conn))                ; tear down
```

All four lifecycle functions are LarKC-stripped. The reconstructed macro `with-new-remote-image-connection` packages the whole sequence:

```
(defmacro with-new-remote-image-connection ((remote-image) &body body)
  (let ((connection (make-symbol "CONNECTION")))
    `(let ((,connection (new-remote-image-connection ,remote-image)))
       (cunwind-protect
         (progn
           (open-remote-image-connection ,connection)
           (with-remote-image-connection (,connection)
             ,@body))
         (close-remote-image-connection ,connection)))))
```

This is the **canonical client-side usage**: open, run body, close on exit. The `cunwind-protect` ensures the close fires even on error.

## When does a remote-image-connection mutate or disappear?

| Trigger | Effect |
|---|---|
| `new-remote-image-connection image` | Mint a closed connection struct pointing at `image`. The `channel` slot is initially NIL; a TCP socket has not yet been opened. |
| `open-remote-image-connection conn` | Establishes the TCP connection to the image's `(machine, port)`, performs any protocol handshake, and stashes the resulting channel in `(rmt-img-conn-channel conn)`. |
| `with-remote-image-connection (conn) body` | Dynamically binds `*current-remote-image-connection*` to `conn` for the body. This lets `current-remote-image-connection-eval` find the active connection without an explicit argument. |
| `remote-image-connection-eval conn form` | Sends `form` over the channel; reads back the result; returns it. Errors on the remote side become local errors. |
| `current-remote-image-connection-eval form` | Same, but uses the dynamically-bound `*current-remote-image-connection*` as the connection. The macro-friendly form. |
| `reopen-remote-image-connection conn` | If the channel is in error state (e.g. peer disconnected), tears down and re-establishes. Idempotent. |
| `close-remote-image-connection conn` | Closes the TCP socket and clears the channel slot. `(remote-image-connection-closed? conn)` is now T; `open?` is NIL. |

The struct's mutable state is just the `channel` slot — open/closed transitions flip it between live-channel-object and NIL. The image identity never changes.

## The `*current-remote-image-connection*` parameter

Reconstructed macro:

```
(defmacro with-remote-image-connection ((connection) &body body)
  `(clet ((*current-remote-image-connection* ,connection))
     ,@body))
```

This is the **dynamic-binding handle** for "which remote image are we currently talking to?" When you're inside `(with-remote-image-connection (conn) ...)`, calls like `(current-remote-image-connection-eval form)` and any macros that want to dispatch to the remote use the bound connection. Outside the form, the parameter is NIL.

This is the natural pattern for sub-DSLs — a chunk of code that pretends to be local but in fact runs on the remote. Without the dynamic binding, every remote call would need an explicit connection argument, which clutters intent.

## How the channel works

The channel is the codec layer wrapping a TCP stream. For `:text` protocol, the channel is a stream + the API client protocol — write a form, read back `<status-code> <result>`. For `:cfasl` protocol, the channel uses CFASL externalised mode for both directions.

The handle-translation hooks in `api-control-vars.lisp` ([cyc-api.md](cyc-api.md)) — `*cfasl-constant-handle-func*`, `*cfasl-constant-handle-lookup-func*`, etc. — are bound by the channel-open routine to functions that translate between this image's id space and the remote's. A constant sent over the wire is identified by GUID (cross-image-stable); on receive, the lookup hook resolves the GUID to whatever local id corresponds. See [../persistence/encapsulation.md](../persistence/encapsulation.md).

`api-channel-remote-eval` (LarKC-stripped) is the lower-level entry point — given an explicit channel, send + read one form. It's what `remote-image-connection-eval` is built on.

## How other systems consume this

The LarKC port has **no surviving call sites** of remote-image — every consumer is itself stripped:

- `cyc-api-remote-eval` (LarKC-stripped) — the one-shot wrapper. Builds a `remote-image`, runs `with-new-remote-image-connection`, evaluates the form, returns. Useful for ad-hoc cross-image queries.
- `cyc-api-channel-eval` (LarKC-stripped) — uses an existing channel rather than minting one.
- The transcript-server client (`transcript-server.lisp`, [task-processor.md](task-processor.md)) — would use `with-tcp-connection` directly rather than going through remote-image, because the transcript-server protocol is custom (not API-shaped).

In the Cyc engine these would be heavily used by:

- **Distributed inference** — a sub-problem is split off and executed on a peer image with stronger KB content for that domain.
- **KB syndication** — periodic pulls of new constants/assertions from an upstream image.
- **Cluster mode** — multiple Cyc images cooperate; remote-image is how they exchange queries.

## Notes for a clean rewrite

- **Most of the file is stripped; the design surface that survived is small.** Two structs (image + connection), one protocol slot, one current-connection parameter, one with-block macro. That's a concise client API; rebuild it directly.
- **Intern `remote-image` instances.** A clean rewrite should make `(remote-image "host" 3601 :text)` return the same struct each time. The struct is immutable, so interning is safe and saves identity confusion.
- **Make the connection a real session, not a struct with a channel slot.** A modern session: an authenticated identity, a connection pool (multiple parallel TCP streams), a codec, a heartbeat, automatic reopen on transient failure. A struct + ad-hoc reopen-on-error doesn't scale.
- **`*current-remote-image-connection*` should be a parameter on the connection-aware functions, not a dynamic binding.** Dynamic binding works because there's only one in-flight remote operation per thread; if a clean rewrite supports parallel cross-image work (e.g. concurrent fan-out to multiple peers), the binding pattern breaks.
- **Drop `:protocol :text`.** The text protocol is just s-expressions over a socket — equivalent to API mode but inferior to CFASL because it can't carry references that need handle translation. A clean rewrite has one cross-image protocol (CFASL or its successor), and the API-text protocol is for *clients*, not for *peer images*.
- **Connection pool, not single connection.** A long-running peer relationship should pool connections — open N streams to the peer, round-robin requests, deal with mid-stream errors by retiring the stream and opening a new one. The current single-channel-per-connection design is fine for tests; production needs pooling.
- **Reopen logic should be automatic.** `reopen-remote-image-connection` is a manual operation; in practice, transient TCP failures should be handled by the channel layer transparently. Manual reopen is a code smell.
- **Channel state belongs to the connection, not the image.** The current `(rmt-img-conn-channel conn)` slot suggests this is already the case — keep it that way in a rewrite.
- **Identity hooks (`*cfasl-*-handle-func*`) need to be a property of the connection, not global parameters.** Currently a remote-image-connection has to rebind six different parameters via dynamic binding. A clean rewrite should bundle them as a struct on the connection and have the codec ask the connection for translations.
- **Cross-image identity is GUID-only.** Encapsulation ([../persistence/encapsulation.md](../persistence/encapsulation.md)) handles the case where the peer doesn't yet know about a constant — falls back to `(:hp name guid)` representation that the peer can resolve or create. Keep that mechanism; it's load-bearing.
- **`make-remote-image`'s arglist parameter is currently a no-op.** The intent was probably keyword arglist for backwards compat; in the clean rewrite, just take `machine port &optional protocol` directly.
- **`*dtp-remote-image*` and `*dtp-remote-image-connection*` are SubL type-tag conventions.** Drop them.
