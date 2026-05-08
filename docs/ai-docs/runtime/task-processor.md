# Task processor & transcripts

This doc covers two adjacent runtime systems that together implement **asynchronous request handling and inter-image KB replication**:

- `task-processor.lisp` (837 lines) — the **worker pool**: a generic priority-queued thread pool that runs API requests asynchronously. The synchronous API path runs each request on its connection thread; the task-processor path queues the request to a pool of worker threads, frees the connection, and dispatches the response back via a separately-keyed channel later. Cyc has three configured pools: `:api` for client requests, `:bg` for background jobs, and `:console` for interactive console requests.
- `transcript-server.lisp` (110 lines) and `transcript-utilities.lisp` (226 lines) — the **transcript layer**: file-based and network-based replication of KB operations across multiple Cyc images. A "local transcript" is the rolling log of all KE ops applied locally; a "master transcript" is the shared log that all images replicate from. The transcript-server protocol is how images exchange operations through a central master.

Both files together implement Cyc's distributed-KB-state-management runtime. The task processor is the **execution** side; the transcript is the **persistence/replication** side; they meet in the agenda thread (see [../inference/agenda.md](../inference/agenda.md)) which uses the task processor's queueing to defer transcript operations.

The agenda doc already covers the agenda thread, the four operation queues, and the cross-image sync flow. This doc focuses specifically on the task-processor data structures and the transcript file/server layer.

## Task processor: what it is

A **task processor pool** is a struct holding:
- A priority queue of pending `task-info` requests.
- A semaphore counting available work.
- A list of worker threads, each one running `task-processor-handler`.
- A lock serialising queue access.
- Min / max worker thread counts (auto-scaling).

Three pools are pre-configured:

| Pool | Globals | Purpose |
|---|---|---|
| `:api` | `*api-task-process-pool*`, `*api-task-process-pool-lock*` | API requests of form `(task-processor-request ...)` |
| `:bg` | `*bg-task-process-pool*`, `*bg-task-process-pool-lock*` | Background jobs (LarKC-stripped — `bg-task-processor-request` is `missing-larkc`) |
| `:console` | `*console-task-process-pool*`, `*console-task-process-pool-lock*` | Interactive REPL/console requests (LarKC-stripped) |

Each pool has independent worker threads, an independent queue, and an independent lock. They share the global `*task-processor-eval-fn-dict*` (which eval function to use, keyed by pool type) and `*task-processor-response-dispatch-fn-dict*` (which response delivery function to use).

## The four datastructures

```
(defstruct task-info
  type             ; :api / :bg / :console — picks the eval and response-dispatch fns
  id               ; client-supplied request id
  priority         ; integer; higher fires first
  requestor        ; client name string (for logs)
  giveback-info    ; uuid-string for response routing
  bindings         ; alist of dynamic bindings to apply during eval
  request          ; the form to evaluate
  response         ; eval result (filled in by worker)
  error-message    ; error text if eval threw (filled in by worker)
  task-processor-name)  ; name of the worker thread that handled it (filled in by worker)
```

A `task-info` carries everything a worker needs to process the request and ship the result back.

```
(defstruct task-result-set
  result task-info finished)
```

A wrapper produced by `new-task-result-set` for clients that consume results synchronously (LarKC-stripped intermediate-results-accumulator path uses these).

```
(defstruct task-processor
  name process busy-p task-info)
```

One worker. `process` is the BT thread, `busy-p` is the "currently processing" flag, `task-info` is the in-flight request (so the pool can show what each worker is doing).

```
(defstruct task-process-pool
  lock request-queue request-semaphore
  processors background-msgs process-name-prefix
  min-nbr-of-task-processors max-nbr-of-task-processors)
```

A pool. `request-queue` is a priority-queue of pending `task-info` records. `request-semaphore` blocks workers when the queue is empty. `processors` is the list of worker-thread structs. `background-msgs` is a list of diagnostic messages (or, if `*tpool-background-msg-path*` is set, they go to a file stream instead).

## When does a task-info get created?

Three situations mint a `task-info`:

1. **An API client sends `(task-processor-request request id priority requestor client-bindings uuid-string)`.** The connection thread routes to `api-task-processor-request`, which constructs a `task-info` with `:api` type and enqueues it on `*api-task-process-pool*`. The connection thread immediately returns to the API server loop — it does **not** wait for the result.
2. **A background job submits work.** `bg-task-processor-request` (LarKC-stripped) creates one with `:bg` type. Used by the agenda for daily GC, transcript transmit, etc. — though in the LarKC port these all run inline on the agenda thread instead.
3. **The console submits a request.** `console-task-processor-request` (LarKC-stripped) — for an interactive prompt that wants to run inference without blocking the read loop.

The `(first request)` may be `with-immediate-execution`. If so, the wrapping is unwrapped and the `task-info` is enqueued normally — but the priority is implicitly bumped (see `task-processor-handler` / `awaken-first-available-task-processors`).

## When does a task-info change or disappear?

| Trigger | Effect |
|---|---|
| Worker dequeues from request-queue | `tproc-task-info` ← task-info; `tproc-busy-p` ← T |
| Worker calls `note-active-task-process-description-if-permitted` | Records `(task-id, giveback-info) → thread` in `*task-processes-being-worked-on*` cache. Returns NIL if the task hasn't been pre-cancelled. If non-NIL, the worker skips eval and sets `error-message` to the abort reason. |
| Worker invokes `eval-with-bindings` | Constructs `(let bindings (setf *eval-with-bindings* request))` and dispatches to the registered eval-fn for the type (e.g. `cyc-api-eval` for `:api`). Result lands in `*eval-with-bindings*`. |
| Worker stores result | `(ti-response task-info)` ← result; `(ti-error-message task-info)` ← error message string (if any). |
| Worker calls `dispatch-task-processor-response` | Looks up the response dispatch fn for the type and calls it with the task-info. The dispatch fn is responsible for getting the result back to the client. |
| Worker finishes | `note-inactive-task-process-description` removes the entry from `*task-processes-being-worked-on*`; the task-info is GC'd. |
| Client calls `terminate-active-task-processes giveback-info` | Iterates `*task-processes-being-worked-on*` for matching giveback-info and signals the relevant threads to terminate. The signalled thread throws `:terminate-prematurely` and the worker loop catches it, leaves the task-info with an error, and goes back to wait on the semaphore. |

The `*task-processes-being-worked-on*` cache is also a **pre-cancellation channel**: a client can populate the cache *before* a task is dequeued (with a non-NIL "stop reason"), so when the worker tries to claim the task, it reads back the reason and skips eval. Used for batched cancellation when a client knows it's about to drop a request before the worker picks it up.

## Response delivery: the giveback-info

When a worker finishes, `dispatch-api-task-processor-response`:

1. Looks up the destination socket and lock by `giveback-info` (the UUID string the client supplied with the request) via `java-api-socket-out-stream` and `java-api-lock`.
2. Constructs a `(task-processor-response request id priority requestor response error-message finished)` form.
3. If the socket is still open, switches the codec to CFASL externalized mode (`*within-complete-cfasl-objects*` = T, `cfasl-set-mode-externalized`) and `send-cfasl-result` to the socket.
4. If the socket is closed, drops the response with a logged warning.

This is the **out-of-band response channel**: the client opens a "results" socket, sends a `:listening` registration with its uuid-string to the server, and the worker uses `java-api-socket-out-stream uuid-string` to find that socket when it has a result. The original API request connection is not held open during eval.

`java-api-socket-out-stream` and `java-api-lock` (in `java-api-kernel.lisp`) implement this routing — see [../external/java-c-name-translation-and-backends.md](../external/java-c-name-translation-and-backends.md) for the Java side.

## Worker pool lifecycle

| Trigger | Effect |
|---|---|
| First `task-processor-request` arrives on the API channel | `initialize-api-task-processors` runs under `*api-task-process-pool-lock*`. Allocates a fresh pool with min=5, max=25, prefix="API processor ". |
| Pool is full (busy-p T on all workers) and queue not empty | `awaken-first-available-task-processors` checks count vs. max; if room, calls `add-new-task-processor-to-pool` to spawn a new worker; signals the semaphore once. |
| Worker thread runs `task-processor-handler` | Inner loop: clear busy, wait on semaphore, dequeue, set busy, eval, dispatch response, repeat. |
| `halt-api-task-processors` called | Sets `*api-task-process-pool*` ← NIL after halting. Halting is `missing-larkc 31801` and the unblock signal is `missing-larkc 31791`. Real Cyc terminates each worker via interrupt. |

The auto-scale behavior is **soft**: workers are added on demand up to the max but never automatically removed. A long burst of requests grows the pool to 25; after the burst, the workers stay alive and idle on the semaphore. There's no shrink. A clean rewrite probably wants idle-timeout shrinking.

## The eval/response dispatch dictionaries

```
*task-processor-eval-fn-dict*  ; :type → eval-fn
*task-processor-response-dispatch-fn-dict*  ; :type → response-fn
```

Both populated at startup (`task-processor.lisp:806-836`). All three pool types (`:api`, `:bg`, `:console`) currently map their eval-fn to `#'cyc-api-eval` — they all evaluate forms the same way. The dispatch differs:

| Type | Dispatch function |
|---|---|
| `:api` | `dispatch-api-task-processor-response` (CFASL to a side-channel socket) |
| `:bg` | `dispatch-bg-task-processor-response` (LarKC-stripped — likely posts to a result queue the requestor reads) |
| `:console` | `dispatch-console-task-processor-response` (LarKC-stripped — likely prints to a console output stream) |

The dictionary indirection is the extension point. A new pool type just adds entries to both dicts and a registration call.

## Macros published for clients

Two reconstructed macros let the client side handle worker termination:

```
(defmacro catch-task-processor-termination (ans-var &body body)
  `(setf ,ans-var (catch :terminate-prematurely (progn ,@body))))

(defmacro catch-task-processor-termination-quietly (&body body)
  `(catch :terminate-prematurely ,@body))
```

The worker uses `throw :terminate-prematurely <reason>` when an active termination signal arrives. The client wraps its task-form in one of these macros so the throw lands cleanly and the request finishes with the reason as the result. Without the wrapper, the throw would unwind past the eval frame and abort the entire task.

These are registered as Cyc API macros so a client can include them in a `(task-processor-request '(catch-task-processor-termination ans (long-running-thing)) ...)` form.

## Transcripts: the KB replication log

A **transcript** is a file containing a sequence of KE operations (`assert`, `unassert`, `create-constant`, `merge`, etc.) in encapsulated form. There are two kinds:

| Transcript | Variable | What goes in |
|---|---|---|
| **Local** | `*local-transcript*` | KE ops applied to *this image's* KB, in order |
| **Master** | `*master-transcript*` | KE ops shared with peer images via the transcript server |

`*local-hl-transcript*` is a third kind — the same ops but at the HL layer (post-canonicalization, post-WFF-checking). The HL transcript exists for replay scenarios where re-canonicalising the EL form would be expensive or non-deterministic. Almost all of the HL-transcript handling is `missing-larkc`.

A `*read-transcript*` parameter points at whichever transcript file is currently being read for replay.

### Filename conventions

| Pattern | Example | Meaning |
|---|---|---|
| `cyc-kb-NNNN.ts` | `cyc-kb-0042.ts` | Master transcript for KB version 42 |
| `<image-id>-local-N.ts` | `cyc-3a7b-...-local-0.ts` | Local transcript, N-th rolled file for this image |

The master filename comes from `make-master-transcript-filename` (KB version padded to 4 digits in `transcript-directory-int`). The local filename embeds the image's UUID so multiple images don't collide if they share storage. All transcripts live in `<cyc-home>/transcripts/<kb-version>/`. The directory is auto-created by `transcript-directory`.

`*transcript-suffix*` defaults to `"ts"` — every transcript file is `*.ts`.

`*approx-chars-per-op*` = 206 — used for op-count estimation by file size when full counts are unavailable.

### When does a transcript come into being?

| Trigger | Effect |
|---|---|
| Image startup `initialize-transcript-handling` | Sets `*master-transcript-already-exists*` ← NIL; calls `new-local-transcript` (creates a fresh local transcript file); `set-master-transcript`; `set-read-transcript ← master-transcript`. If `(use-transcript-server)`, sets `*auto-increment-kb*` ← T. |
| `new-local-transcript` while old one exists | Archives the old local-transcript (`missing-larkc 6062`, likely renames with a "ROLLED" mark) and records it on `*local-transcript-history*` (`missing-larkc 6055`). Then constructs a new filename via `make-local-transcript-filename` using the current `*local-transcript-version*`. |
| Roll request on the agenda | LarKC-stripped `roll-local-transcript` — increments `*local-transcript-version*` and rolls the file. |

### When does a transcript change?

The transcript file itself is **append-only** during a session. Each KE op is encapsulated and appended. The interesting state is:

| State | Mutation trigger |
|---|---|
| `*local-transcript*` (filename) | Set on `new-local-transcript`; rolled on every server checkpoint |
| `*local-transcript-version*` | Incremented when the local transcript rolls |
| `*local-transcript-history*` | Rolled-file paths pushed on every roll |
| `*read-transcript-position*` | Updated as `read-one-transcript-operation-from-server` consumes the master transcript on replication-receive |
| `*master-transcript*` | Set once at startup unless `(use-transcript-server)` is T (in which case it's NIL because the master is on the server) |
| `*master-transcript-already-exists*` | Bool: has anyone touched the master transcript yet? Used to decide whether to do first-time initialization. |

### The transcript server protocol

`transcript-server.lisp` is **the wire protocol for talking to a master-transcript server** — a separate Cyc process (or a dedicated transcript-server process) that holds the canonical master transcript and arbitrates replication between client images.

The protocol is text-based with a small command vocabulary. The functions are all LarKC-stripped (active declareFunctions, no body), but the names are evidence:

| Function | Purpose |
|---|---|
| `transcript-server-message-startup channel` | Send the protocol-version negotiation handshake |
| `transcript-server-message-shutdown channel` | Clean shutdown handshake |
| `ts-ack-server-connection channel` | Confirm the server accepted the connection |
| `ts-send-set-image-message channel` | Tell the server which image-id we are |
| `ts-send-set-kb-message channel` | Tell the server which KB version we're tracking |
| `ts-send-set-op-message channel` | Tell the server which op-id is the high-water mark we've already seen |
| `ts-send-how-many-ops-message channel direction` | Ask "how many ops in direction X are available?" |
| `ts-send-send-ops-begin-message / send-ops-op / send-ops-end-message` | Send a batch of ops to the server (transmit phase) |
| `ts-send-get-ops-message channel` | Ask the server for new ops (receive phase) |
| `ts-send-quit-message channel` | Goodbye |

`*master-transcript-server-connection-timeout*` = 10 seconds.
`*transcript-server-protocol-version*` = 1 (current). Version 0 is the legacy protocol (no version negotiation).

Higher-level operations (also LarKC-stripped):

| Function | Purpose |
|---|---|
| `send-operations-to-server` | Push pending local ops to the master |
| `read-operations-from-server` | Pull new ops from the master and apply locally |
| `transcript-server-check` | Health check — is the connection alive? |
| `total-master-transcript-operations` | Count |

Two reconstruction-deferred macros (`with-transcript-server-connection`, `transcript-server-message-body`) wrap the lower-level ops with timeout / connection-management. Their reconstruction was abandoned because no expansion sites exist in the surviving Java codebase.

### When does the transcript server get used?

The agenda thread (see [../inference/agenda.md](../inference/agenda.md)) periodically calls `send-operations-to-server` and `read-operations-from-server` if `(use-transcript-server)` is T. The user-level KE ops accumulate in the local-operation-queue (see `operation-queues.lisp` — also covered in the agenda doc), and the agenda flushes them to the master-transcript server on its schedule.

In the LarKC port, `(use-transcript-server)` is controlled by `*use-transcript-server*` (defined elsewhere; defaults vary). When NIL, the master transcript is just a local file shared by file system; when T, the master is over the wire.

## Transcript reading: replay

`transcript-utilities.lisp` exposes (some surviving, some stripped):

| Function | Purpose |
|---|---|
| `transcript-eval form &optional options` | (stripped) Run one transcript op as if it had been read off a transcript file. Used by replay/load-transcript. |
| `transcript-form` / `transcript-form-int` / `form-to-transcript-form` | (stripped) Encapsulate a form for transcript writing. |
| `count-operations transcript` | (stripped) Exact op count for a transcript file. |
| `estimate-number-of-ops transcript` | (stripped) Cheap estimate using `*approx-chars-per-op*`. |
| `collect-ops-in-range transcript start end count` | (stripped) Iterator over a slice of a transcript file. |
| `bp-count-ops transcript` | (stripped) Bookkeeping-positioned count. |

Plus a family of analysis tools that operate on a transcript file as data:

| Function | Purpose |
|---|---|
| `constant-modifications-in-transcript transcript` | Set of constants touched in this file |
| `report-constant-modifications-in-transcript stream` | Emit a human-readable summary |
| `report-constant-modifications-in-transcript-to-file path transcript` | Same, to file |
| `add-transcript-rename-info` / `add-transcript-create-info` / `rem-transcript-*-info` / `reset-transcript-rename-hash` | Scan a transcript and build hashes of "this constant was renamed" / "this constant was created" — useful for comparing across snapshots |
| `constant-created-in-transcript external-id` | "Was this constant created in the transcript?" |

The user-facing entry point is the surviving `write-specific-transcript-file-as-ke-text transcript-filename output-filename`, registered as a Cyc API function: load a binary transcript and re-emit it as readable KE text. This is the export-for-debug path.

`*count-ops-table*`, `*transcript-rename-hash*`, `*transcript-create-hash*` are the three globals used by the analysis helpers. All initialised NIL — populated lazily.

## How other systems consume this

- **API kernel** ([cyc-api.md](cyc-api.md)) — calls `task-processor-request` (registered in `cfasl-kernel.lisp`) when an API request's first symbol is `task-processor-request`. The kernel doesn't otherwise touch the pool.
- **Agenda** ([../inference/agenda.md](../inference/agenda.md)) — owns the transcript transmit/receive scheduling. The agenda is *the* user of `send-operations-to-server` / `read-operations-from-server`.
- **Operation queues** (`operation-queues.lisp`, covered in agenda) — own the local-operation-storage queue that the transcript-write side drains. `clear-local-operation-storage-queue` is called from `new-local-transcript`.
- **Bookkeeping** ([../kb-access/bookkeeping-store.md](../kb-access/bookkeeping-store.md)) — the cyclist/timestamp/purpose triples that get stamped into transcript ops come from here.
- **CFASL externalization** ([../persistence/cfasl.md](../persistence/cfasl.md)) — `dispatch-api-task-processor-response` switches the codec to `*within-complete-cfasl-objects*` mode for the response. This is one of the few callers of that mode at runtime (the others are KB-dump and remote-image).
- **KB dumper** ([../persistence/kb-dumper-loader.md](../persistence/kb-dumper-loader.md)) — `make-master-transcript-filename` uses `(kb-loaded)` (the dumped KB version number) as the filename version, so transcripts are tagged to the KB they apply against.

## Notes for a clean rewrite

- **The three pool types collapse to one.** `:api`, `:bg`, `:console` all use the same eval function and differ only in response delivery. A clean rewrite should have one priority queue + one worker pool, with the response delivery as a per-request callback rather than a per-pool dispatch table.
- **Drop the `task-info` slot bag for a real message envelope.** The 11-slot struct is hard to extend. A request has a `request body`, a `metadata header` (id, priority, requestor, deadline, retry-count, …), and a `response slot`. Three nested objects, not 11 flat slots.
- **Auto-scale should shrink, not just grow.** Idle workers should retire after a timeout. Currently they sit forever, eating memory.
- **Priority queue with bumping is brittle.** `awaken-first-available-task-processors` "bumps" lower-priority requests off the queue when full. The `bumped-request?` return path is just a `cerror` — bumped requests are *lost*. A clean rewrite should reject submissions when full (with backpressure to the client) rather than silently dropping mid-priority work.
- **Move giveback-info socket lookup out of the worker.** `dispatch-api-task-processor-response` looks up `java-api-socket-out-stream` by uuid string. That coupling means the task-processor knows about the API transport. A clean rewrite should let the request-submitter supply the response callback (a closure over the destination), not the worker.
- **`with-immediate-execution` is undocumented sugar.** Its effect is "queue this with bumped priority"; the implementation just unwraps the form and enqueues normally. A clean rewrite should make the priority explicit on the submission.
- **The `*task-processes-being-worked-on*` cache is a thread registry.** Rename it. Make the lifecycle explicit: register-on-claim, deregister-on-finish, with cancellation as a separate channel.
- **Transcript files are append-only ops over time.** This is a write-ahead log. Use a real WAL library (or a real database). The Cyc-specific bits — encapsulated CycL ops, master/local split, image-id namespacing — are valuable; the file format and protocol are not.
- **The transcript-server protocol is RPC reinventing the wheel.** Replace with gRPC or HTTP/2 + protobuf. Keep the operation taxonomy (set-image, set-kb, set-op, send-ops, get-ops, how-many-ops); drop the hand-rolled connection state machine.
- **`*local-transcript-history*` should be a directory listing, not a list.** The on-disk filenames are the canonical history; the in-memory list is just a cache, and it gets stale.
- **The HL transcript is duplicated state.** `*local-hl-transcript*` is the same ops at a lower level. If the canonicaliser is deterministic (which it should be), the EL transcript suffices and the HL transcript can be regenerated. The LarKC-stripped HL handling reflects this — Cyc the engine kept it for replay performance, not correctness.
- **`*master-transcript-already-exists*` is a bool with three values (NIL, T, "number"), per the comment on `set-master-transcript-already-exists`.** Pick one type. The current arrangement is a porting artefact.
- **`*approx-chars-per-op*` = 206 is empirical magic.** A clean rewrite should index transcript files (header with op count) instead of estimating from byte size.
- **The transcript-server protocol-version variable supports two values (0, 1) but no negotiation logic survives.** Negotiation matters when rolling out version 2. Keep the version field; design the negotiation handshake explicitly.
- **`construct-transcript-filename` does string concatenation.** Replace with proper path manipulation. Same for `make-local-transcript-filename`.
- **The four "intermediate-results-accumulator" stubs (LarKC-stripped) are a streaming-results feature.** Long inferences yield partial results progressively; the accumulator is how the worker pushes partial results before the inference finishes. A clean rewrite that wants streaming queries should rebuild this — the API design (callbacks per partial) is sound; the implementation is missing.
