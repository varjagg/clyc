# Cyc API — registration & dispatch

The **Cyc API** is the public RPC surface of a running Cyc image: a TCP server that accepts SubL-form requests, evaluates them in a restricted environment, and returns results. It is how external clients (Java consumers of the LarKC API, the Knowledge Editor, batch scripts, paired Cyc images doing transcript replication) talk to a live KB.

This doc covers two source files plus a slice of `utilities-macros.lisp`:

- `api-control-vars.lisp` — the small set of dynamic-binding hooks the API needs: who's logged in (`*the-cyclist*`), which KE bucket they're acting in (`*ke-purpose*`), the `*cfasl-*-handle-func*` overrides for cross-image identity, and a couple of result-formatting flags.
- `api-kernel.lisp` — the server loop: TCP-server registration, the per-connection top-level, the request pipeline (read → validate → record → eval → send), and the protocol-method indirection that lets a connection swap codecs mid-stream.
- `utilities-macros.lisp` (top half) — the registration plumbing that the rest of the codebase uses to *publish* a function or macro to the API. Every other source file's `register-cyc-api-function` calls flow through here.

Adjacent systems documented separately:
- The eval side (the SubL-subset interpreter that runs API forms) — see [eval-in-api.md](eval-in-api.md).
- The task-processor pool that handles asynchronous API requests — see [../inference/agenda.md](../inference/agenda.md) and [transcript-server.md](transcript-server.md).
- The TCP plumbing (server-type registration, accept loop, per-connection threads) — see [tcp-transport.md](tcp-transport.md).
- Cross-image RPC (`cyc-api-remote-eval`, `cyc-api-channel-eval`) — see [remote-image.md](remote-image.md).

## What the API actually is

A Cyc image runs **multiple TCP servers on offset ports** (`*base-tcp-port*` + various offsets). The Cyc API server is one of them, registered at startup with:

```
(register-tcp-server-type :cyc-api 'api-server-handler :text)
```

`tcp.lisp` and `tcp-server-utilities.lisp` provide the listener loop; on each accepted connection, they look up the handler for the `:cyc-api` server type and call `(api-server-handler in-stream out-stream)` on a fresh thread. That handler is `api-server-top-level`, which sets up dynamic bindings and enters the server loop.

The on-port `:cyc-api` channel speaks a **text protocol**: one CycL/SubL `read`-able form per request, one CycL/SubL `read`-able form per response. The other protocol option is `:binary` (used by the CFASL channel, registered separately by other servers; see [tcp-transport.md](tcp-transport.md)). The `:text` mode means a request looks like `(cyc-query '(#$isa ?X #$Person) #$BaseKB)` and the response is a code-prefixed s-expression — `200 (#$Fred #$Wilma ...)` for success or `500 "error message"` for failure.

There is **no authentication, no encryption, no transport security**. The API trusts whoever can connect to its port. Production deployments either firewall the port or front it with a proxy. A clean rewrite must address this.

## When does an API request come into being?

Three situations create a request that flows through `api-server-one-complete-request`:

1. **A client sends an s-expression on an established TCP connection.** This is the normal external case — a Java/Python/etc. client opens a socket to the API port and writes a form. `read-api-request` reads one form via the current `*api-input-protocol*` and returns it.
2. **The reader hits EOF.** Reading returns `*api-input-eof-marker*` (a uninterned symbol generated at load time). `read-api-request` throws `:api-quit` and the connection's `catch :api-quit` form unwinds the loop. Connection close is implicit — there is no "goodbye" handshake; either side just shuts the socket.
3. **An internal caller invokes `cyc-api-eval` directly.** Code that wants to evaluate a form *as if* it had come over the API can call `(cyc-api-eval form)` from any thread. This bypasses the read/validate/send wrappers but reuses the same eval-in-api environment, so the form sees the same restricted set of operators. Used by transcript replay (`load-transcript-file`) and by the task-processor when a queued request fires.

## When does an API request mutate or disappear?

The request itself is a single value that lives only until evaluation finishes. The interesting state is the **per-connection environment**, which is born when a connection opens and dies when it closes:

- `*the-cyclist*` is the user identity. Set at connection open via `(the-cyclist)` (an external-image-supplied default) and stays put until the next connection's top-level rebinds it. KE assertions stamped during this connection get tagged with this cyclist.
- `*ke-purpose*` is the editorial bucket. Defaults to `*default-ke-purpose*` (which itself defaults to NIL = "general Cyc KE"). A long-running editing session can override this so all that session's edits are tagged with a project-specific purpose.
- `*api-input-protocol*` and `*api-output-protocol*` are the codec hooks. A client can request a codec change via `change-api-protocol`; that doesn't take effect immediately but is staged into `*new-api-input-protocol*` / `*new-api-output-protocol*` and committed by `update-api-protocol` *after* the response to the change request has been sent. This avoids the race where the request is decoded by codec A but the response is sent by codec B.
- `*eval-in-api-env*` is the per-connection variable environment used by the SubL-interpreter eval path. Initialized by `initialize-eval-in-api-env` (currently NIL — the body is `(initialize-eval-in-api-env)` returning NIL because real eval-in-api is `missing-larkc`). Every request sees a fresh env when the connection starts; bindings made by one request persist for the lifetime of the connection.
- `*api-task-processors-initialized-p*` (in `task-processor.lisp`) controls whether the worker pool has been spun up. Lazily created on first `task-processor-request` — see "Task processor route" below.

## The request pipeline

`api-server-one-complete-request` runs five steps in sequence, each of which can short-circuit on error:

| Step | Function | Purpose |
|---|---|---|
| 1. Read | `read-api-request` | Decode one form from the input stream using the active input protocol. EOF → `api-quit`. |
| 2. Validate | `validate-api-request` | If `*api-validate-method*` is non-NIL, call it on the request. Default is `default-validate-api-request` (LarKC-stripped — Cyc's real validator checks the form against the predefined-operator tables). |
| 3. Record | `record-api-request` | If `*record-api-messages?*`, append the request to `*api-message-sink*` (a list or a stream). Used for replay and audit. |
| 4. Dispatch | (task processor branch) or `perform-api-request` → `cyc-api-eval` | Either queue the request to a background processor or run it synchronously. |
| 5. Send | `send-api-result` | Encode result via the output protocol; on send error, call `api-quit`. |

`setf-error` is the SubL-style `(handler-case ... (error (e) (setf err e)))` used at each step to capture errors into a local variable rather than unwinding. If any step errors, subsequent steps are skipped and the error message is sent in step 5 (with `error?` = T).

After step 5, `update-api-protocol` swaps in any pending codec change. Then the loop iterates and reads the next request.

## The two dispatch routes

After validation, the pipeline branches on the first symbol of the request:

```
(if (eq 'task-processor-request (car api-request))
    [queue route]
    [synchronous route])
```

### Synchronous route

Most requests go here. `perform-api-request` calls `cyc-api-eval` which dispatches on `*eval-in-api?*`:

- `*eval-in-api?* = NIL` (the only supported value in the LarKC port) → `eval-in-api-subl-eval` → `funcall *subl-eval-method*` (currently `'eval`) → host-language `eval`. This is "bypass mode": the request is just `eval`'d in the host CL/SubL with no sandboxing. It works because the API port is firewalled or trusted.
- `*eval-in-api?* = T` (the supported-but-stripped path) → `missing-larkc 10828`. In real Cyc this routes through a SubL-subset interpreter that walks the form, checks each operator against `*api-predefined-function-table*` / `*api-predefined-macro-table*` / `*api-special-table*`, and rejects unknown ones. The interpreter is the safety boundary that makes the API safe to expose without firewalling. See [eval-in-api.md](eval-in-api.md).

The result is then optionally transformed by `*api-result-method*` (e.g. `daml-api-result-transform` for clients that want OWL-shaped output) and returned.

If `(fi-error-signaled?)` is true after eval, `missing-larkc 11154` would have unwound a more elaborate FI-style error envelope — in the port, FI errors propagate as ordinary errors instead.

### Task-processor (queued) route

A request shaped like:

```
(task-processor-request request id priority requestor client-bindings uuid-string)
```

is **not** evaluated on the connection thread. Instead the connection thread:

1. Acquires `*api-task-process-pool-lock*` and lazily initializes the worker pool via `initialize-api-task-processors` if it hasn't been started yet.
2. Calls `task-processor-request` (in `cfasl-kernel.lisp`!) which routes to `api-task-processor-request` (in `task-processor.lisp`), which enqueues a `task-info` struct on the pool's input queue with the given priority and immediately returns.

The actual work runs on a worker thread later. The original connection is **not** held open waiting for the result — the queued request returns its results via a separate channel keyed by the `uuid-string`. This is how Cyc supports long-running queries (e.g. inference taking minutes) without tying up a TCP connection.

The cross-file split (registration in `cfasl-kernel.lisp`, dispatch in `task-processor.lisp`) is a quirk of the build order — `task-processor-request` was the first API function the CFASL kernel needed to publish, so its registration ended up there.

See [transcript-server.md](transcript-server.md) for the worker pool internals.

## Registration: how a function becomes API-callable

Every public API entry point is announced by one call to `register-cyc-api-function` (or `register-cyc-api-macro`). The mechanism is in `utilities-macros.lisp`:

```
(defun register-cyc-api-function (name arglist doc-string argument-types return-types)
  (register-api-predefined-function name)        ; add to *api-predefined-function-table*
  (register-cyc-api-symbol name)                  ; pushnew on *api-symbols* + put :cyc-api-symbol prop
  (register-cyc-api-args name arglist)            ; put :cyc-api-args prop
  (register-cyc-api-function-documentation name doc-string)  ; (currently a no-op — doc lives in defun docstring)
  (register-cyc-api-arg-types name argument-types)  ; put :cyc-api-arg-types prop
  (register-cyc-api-return-types name return-types)) ; validate + put :cyc-api-return-types prop
```

The registration is **purely metadata-installing**: it does not generate code, define a stub, or wire the function into anything. The host-language defun already exists; registration is what makes the SubL interpreter (`*eval-in-api?*` = T path) willing to call it and what makes documentation tools find it.

### The five tables

| Table | Population | Purpose |
|---|---|---|
| `*api-symbols*` | every register-cyc-api-* call | Master list of every symbol that's been registered as API. The reverse-engineering view: "what's published?" |
| `*api-predefined-function-table*` | `register-api-predefined-function` | Functions callable from API. Hash, key = symbol, value = T. |
| `*api-predefined-macro-table*` | `register-api-predefined-macro` | Macros expandable from API. |
| `*api-predefined-host-function-table*` | `register-api-predefined-host-function` | Host-language functions (e.g. `read`, `format`, `make-process`). Gated by `*permit-api-host-access*` — usable only when the connection has elevated privilege. |
| `*api-predefined-host-macro-table*` | `register-api-predefined-host-macro` | Same, for macros. Gated similarly. |
| `*api-special-table*` | `register-api-special` | Special-form handlers. Used for things like `(quote X)` that aren't ordinary functions. |

The four tables are consulted in **lookup order** by the eval-in-api interpreter (when it ever runs): special > predefined > host (if permitted). The host tables are an explicit boundary — calling `read` from the API requires the connection to have set `*permit-api-host-access*`, otherwise the host table lookup returns NIL and the function is unrecognized.

### The metadata properties

Stored on each registered symbol's plist:

| Property | Set by | Used for |
|---|---|---|
| `:cyc-api-symbol` | `register-cyc-api-symbol` | Boolean — "this is published" |
| `:cyc-api-args` | `register-cyc-api-args` | Arglist preserved for clients that need to introspect signatures (host CL has it on the function but SubL doesn't, hence the explicit copy) |
| `:cyc-api-arg-types` | `register-cyc-api-arg-types` | Per-arg type-predicate forms, e.g. `((api-request consp) (machine stringp) (port integerp))` — used by the validator |
| `:cyc-api-return-types` | `register-cyc-api-return-types` | Per-return-position type-predicate forms — used by the validator and by tools that want to know what the function produces |

Each of these has a `deregister-cyc-api-X` companion (LarKC-stripped) for unpublishing a function — useful for hot-fixes or pulling broken APIs without restarting the image.

### Registration scale

`register-cyc-api-function` is called **~828 times** across the codebase. Roughly half live in `eval-in-api-registrations.lisp` (which is essentially a giant manifest of bulk registrations — see [eval-in-api.md](eval-in-api.md)), the other half are scattered in the source files where the functions themselves are defined (e.g. `kb-mapping.lisp` registers ~252 mapping functions). The split is editorial: simple "expose this verbatim" goes near the defun; bulk catalogues of host/SubL primitives that don't have a natural home file go in the registrations file.

## API control vars

`api-control-vars.lisp` defines a thin set of dynamic-binding hooks consumed elsewhere. They're split out into a separate file so the bottom layer of the codebase can rebind them without depending on the api-kernel itself.

### CFASL handle override hooks

Six paired parameters, one pair per KB-handle type (constant, NART, assertion, deduction, KB-HL-support, clause-struc):

```
*cfasl-constant-handle-func*           ; output: id-of-this-constant
*cfasl-constant-handle-lookup-func*    ; input: constant-with-this-id
... (same for NART, assertion, deduction, KB-HL-support, clause-struc)
```

When `NIL`, the CFASL codec uses the default identifier (e.g. `constant-internal-id` for output, `find-constant-by-internal-id` for input). When non-NIL, the codec calls the supplied function instead. This is how cross-image transport works — a remote-image session sets these to functions that translate between the local id space and the remote one's. See [../persistence/cfasl.md](../persistence/cfasl.md) and [remote-image.md](remote-image.md).

These are dynamic parameters, not globals. Default scope is "image lifetime"; an active CFASL externalization session rebinds them via `let`.

### Identity hooks

| Variable | Purpose |
|---|---|
| `*the-cyclist*` | Currently-logged-in user (a constant denoting an instance of `#$Cyclist`). The persona under which assertions are recorded. NIL = no identity, edits are anonymous. |
| `*default-ke-purpose*` | Default editorial bucket. NIL = generic Cyc KE. Project-specific Cyc deployments can change this at startup so all asserts of unspecified purpose get tagged with the project. |
| `*ke-purpose*` | Currently-active editorial bucket. Inherits from `*default-ke-purpose*`. Rebound per-session. |

The cyclist/purpose pair is what gets stamped into the bookkeeping fields of every assertion made during this session (see [../kb-access/bookkeeping-store.md](../kb-access/bookkeeping-store.md)).

### Dispatch-routing hooks

| Variable | Purpose |
|---|---|
| `*use-local-queue?*` | If T, KE operations write to the local operation-queue rather than transmitting them to the master transcript. The API rebinds it to NIL so API-driven changes propagate. |
| `*generate-readable-fi-results*` | If T, FI results are prettified for human consumption (slower); if NIL, raw forms are returned. |

## Protocol indirection

The four `*default-api-X*` parameters are immutable defaults; the four `*api-X*` parameters are the active values, rebound per-connection. They form a four-stage transform:

```
[client wire bytes] --(api-input-protocol)--> form
                    --(api-validate-method)--> form (or error)
form  --(perform-api-request → cyc-api-eval)--> result
result --(api-result-method)--> result'
result' --(api-output-protocol)--> [client wire bytes]
```

Each of the four hooks is a function spec (symbol or compiled function). Out-of-the-box defaults:

| Stage | Default |
|---|---|
| Input protocol | `default-api-input-protocol` (`missing-larkc 31555` — Cyc's real impl reads one s-expression with appropriate package handling) |
| Validate | `default-validate-api-request` (LarKC-stripped) |
| Result | NIL (no transform) |
| Output | `default-api-output-protocol` (writes `<code> <result-form>` followed by a newline + `force-output`) |

`change-api-protocol` (LarKC-stripped) is the API call a client uses to switch codecs mid-stream; the staging-via-`*new-X*` mechanism described above ensures atomicity around the response that announces the switch.

## Cross-image evaluation

Three entry points let a client run forms on a different image:

| Function | Path |
|---|---|
| `cyc-api-remote-eval api-request machine port` | TCP. Open a connection to `machine:port`, send the request, read the response, close. One-shot. |
| `cyc-api-channel-eval api-request channel` | Reuse an existing channel object (a long-lived connection encapsulator). |
| `cyc-api-channel-eval-internal`, `cyc-api-channel-output`, `cyc-api-channel-input` | The channel codec internals. |

All four are LarKC-stripped (active declareFunctions, no body). The clean rewrite needs them — they're the only way for one Cyc image to call another at the API level.

`fi-server-top-level` / `fi-quit` / `fi-port` are the older "FI" (Functional Interface) version of the same thing — kept for transcript-replay compatibility but otherwise superseded.

## How the API is consumed

The **synchronous route** is the bulk of traffic — the Knowledge Editor, FI calls, ad-hoc queries from cyclist tools. Every form is a one-shot eval and the connection is held open across many forms.

The **task-processor route** is for long inferences and any operation that needs to survive a connection drop. The KBQ system (`inference/kbq-query-run.lisp`), large-batch assertion via the KE, and any tool that submits a `task-processor-request` form go here.

The **registration mechanism** (`register-cyc-api-function`) is consumed by *every* source file in the codebase. Searching for this symbol is the equivalent of `objdump -T` for finding all exported symbols — the result is the public API of a Cyc image.

The **CFASL handle override hooks** are consumed by `cfasl.lisp` and by `remote-image.lisp` exclusively. Other code never touches them.

## Notes for a clean rewrite

- **The API is JSON-shaped, not s-expr-shaped.** Modern clients want JSON. Keep the operation-symbol dispatch but switch the wire format. The codec indirection (`*api-input-protocol*`/`*api-output-protocol*`) is exactly the right hook for this — define a JSON codec and ship.
- **Authentication and TLS are not optional.** A clean rewrite needs to terminate TLS, authenticate the cyclist, and authorize each call against per-cyclist permissions (which are already in the KB as `(allowedToAssert ?Cyclist ?Predicate)` etc.). The current implementation trusts the firewall.
- **Drop the eval-in-api fallback path.** `*eval-in-api?* = NIL` means the API just calls host-language `eval`. That's an arbitrary-code-execution surface. The right thing is to *always* use the SubL interpreter and require that every callable function be explicitly registered. The LarKC port stripped the interpreter, so this means re-implementing it; see [eval-in-api.md](eval-in-api.md).
- **The five tables (special / predefined-fn / predefined-macro / host-fn / host-macro) collapse to two.** Host vs. predefined is a permission distinction, not a category distinction. A clean rewrite has one registry of API-callable operators, each with a permission tag (`:public`, `:host-access`, `:internal`). The interpreter checks the tag against the connection's privilege.
- **Symbol-plist metadata is implementation-leaky.** `:cyc-api-symbol`, `:cyc-api-args`, `:cyc-api-arg-types`, `:cyc-api-return-types` should live in a real registry struct, not on plists. The plist approach was a SubL convention because SubL's `defun` discarded arglists; modern CL has them on the function and a clean rewrite has them in the function metadata.
- **Validation is a real type system, not a list of predicates.** The `((arg pred) ...)` form is a hand-rolled type schema. A clean rewrite should use a real schema language — the same one the public docs use, the same one the IDE uses for autocomplete.
- **The protocol-change handshake is fine but deserves a name.** "Send response in old protocol, then atomically switch to new" is a real pattern. Document it; don't bury it in `update-api-protocol`.
- **`*eval-in-api-env*` is per-connection variable storage.** That's a session feature. A clean rewrite should make this explicit — sessions have variables, sessions have lifetimes, sessions can be resumed across reconnects (with auth). The current per-connection env is lost on disconnect.
- **The task-processor split should not be a magic symbol.** `(eq 'task-processor-request (car api-request))` is a syntactic dispatch. A clean rewrite should expose async-request as a header on the request envelope, not as an in-band sentinel.
- **Drop `*generate-readable-fi-results*` and the prettifier.** Pretty-printing belongs at the client. Don't waste server cycles formatting forms for human eyes.
- **`*the-cyclist*` and `*ke-purpose*` are session-scope identity.** Make that explicit by carrying them on the session object instead of as global dynamic bindings. Dynamic binding works because there's one connection per thread and one cyclist per connection; that's accidental, not architectural.
- **The CFASL handle override hooks are right but undernamed.** They're "id-translation hooks for cross-image identity." In a clean rewrite, package them as part of the cross-image session object: a session has a translation table; the codec asks the session for translation; the session is what gets installed in the dynamic environment. Today it's six independent parameters that all need to be set together.
