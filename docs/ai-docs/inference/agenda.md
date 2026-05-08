# Agenda — the priority-driven background task system

The **Agenda** is the long-running background process that drives ambient maintenance work — replicating KB operations to/from the master transcript, saving asked-queries logs, running daily GC, processing local and remote operation queues. It is *not* the inference engine's strategy/tactic system (those are also called "tactician strategies" and confusingly use similar vocabulary). The agenda runs *separately from* and *alongside* foreground inference.

The Agenda system has four files:

1. **`agenda.lisp`** (404) — the Cyc Agenda thread itself: top-level loop, task table, error modes, daily GC scheduler, transcript transmit/receive scheduler.
2. **`task-processor.lisp`** (837) — the *task processor* worker pool: structs for `task-info`, `task-result-set`, `task-processor`, `task-process-pool`. The infrastructure for running per-request work (e.g. each Cyc API call gets a task-info routed to a task-processor pool member).
3. **`operation-queues.lisp`** (222) — the seven operation queues that mediate between the agenda and the rest of the system.
4. **`operation-communication.lisp`** (491) — how the local image and master transcript exchange operations: transmit/receive modes, authentication, transcript-load gating.

These four pieces together implement Cyc's **distributed KB synchronisation** — multiple Cyc images cooperating to maintain a shared KB by exchanging operations through a master transcript file.

Source files:
- `larkc-cycl/agenda.lisp`
- `larkc-cycl/task-processor.lisp`
- `larkc-cycl/operation-queues.lisp`
- `larkc-cycl/operation-communication.lisp`

## The Agenda thread

Single thread named "Cyc Agenda", started at image startup (when `*start-agenda-at-startup?*` is T) and runs forever until halt. The main loop:

```
agenda-top-level:
  start-agenda-process               (claim *agenda-process* slot)
  agenda-startup-actions             (ensure transcript files are open)
  let *resourced-sbhl-marking-spaces* = ten reserved SBHL spaces
  loop until *agenda-should-quit*:
    while (not *agenda-should-quit*) and (agenda-work-to-do):
      perform-one-agenda-action
    process-wait "Idle" #'agenda-work-to-do
  clear-agenda-process
```

The agenda thread reserves 10 SBHL marking spaces (`*agenda-resourcing-spaces*`) for its own use — separate from the foreground inference's marking-space pool — so that agenda work doesn't compete for marking spaces with active queries.

### Agenda lifecycle

- `start-agenda(&optional wait?)` — spawn the thread; optional wait until running
- `halt-agenda(&optional wait?)` — signal `*agenda-should-quit*` and notify; optional wait until stopped
- `abort-agenda()` (missing-larkc) — forced shutdown
- `abort-and-restart-agenda()` (missing-larkc) — forced restart
- `wait-for-agenda-running(&optional wait-time)`, `wait-for-agenda-not-running(&optional wait-time)` — synchronisation helpers
- `current-process-is-agenda()` — is the calling thread the agenda?
- `agenda-running()` — is the thread alive?

`*agenda-should-quit*` and `*restart-agenda-flag*` are the two flag globals. `*agenda-process-lock*` (a `bt:make-lock`) guards mutations to `*agenda-process*`.

### Error modes

`*agenda-error-modes* = (:ignore :halt :debug :log)`:
- `:ignore` — swallow errors silently
- `:halt` — stop the agenda on error (default `*agenda-error-mode*`)
- `:debug` — drop into the debugger
- `:log` — write to `*agenda-log-file*` and continue

`set-agenda-error-mode(mode)` (missing-larkc) is the setter.

## Agenda tasks

The agenda has a *task table* of declared tasks. Each task has:
- `test` — predicate function: when this returns true, the task should run
- `action` — function that performs the work
- `priority` — integer; lower = higher priority

```lisp
(declare-agenda-task TEST-FN ACTION-FN PRIORITY)
  → adds (test action priority) to *agenda-action-table*, sorted by priority

(undeclare-agenda-task TEST-FN)
  → removes
```

`*agenda-action-table*` is the sorted list. `*agenda-action-table-lock*` guards mutations.

`agenda-work-to-do()` walks the task list, finds the first task whose test returns true *and* whose action is fboundp, and returns it. Returns nil if no work.

`perform-one-agenda-action()` calls the chosen task's action with `*within-agenda*` bound to T (so deep code can detect "we're being run from the agenda"). After the action completes, the loop tries again.

### Built-in tasks

Several global counters and quanta control the built-in periodic tasks:

| Quantum | Meaning |
|---|---|
| `*save-transcript-quantum* = 60` | save local transcript every 60s |
| `*worry-transmit-quantum* = 600` | transmit on worry threshold every 600s |
| `*worry-transmit-size* = 1000` | worry threshold (queue size) |
| `*normal-transmit-quantum* = 120` | normal transmit every 120s |
| `*load-transcript-quantum* = 120` | load master transcript every 120s |
| `*save-experience-transcript-quantum* = 600` | save experience every 600s |
| `*save-asked-queries-transcript-quantum* = 60` | save asked-queries every 60s |
| `*transcript-queue-worry-size* = 20` | worry threshold for transcript queue |

For each quantum there's a `*next-X-time*` global tracking when the task next fires. `agenda-work-to-do` checks each `*next-X-time*` against `(get-universal-time)`; if the current time exceeds, the task fires and `*next-X-time*` is updated.

### Daily GC

`*agenda-daily-gc-enabled* = nil` — opt-in. When enabled, the agenda triggers a full GC once a day at `*agenda-daily-gc-time-of-day* = '(4 0 0)` (4 AM). `*next-agenda-daily-gc-time*` tracks when the next GC fires. `*agenda-daily-gc-lock*` ensures only one GC runs at a time.

The clean rewrite should keep daily GC opt-in. Modern GCs are concurrent and don't need this; but for SBCL with conservative collector, the periodic full GC is still useful for very long-running images.

## The seven operation queues

`operation-queues.lisp` defines seven queues that mediate work flow:

| Queue | Purpose |
|---|---|
| **local-queue** | operations originating in this image, pending application |
| **remote-queue** | operations from the master transcript, pending application |
| **transcript-queue** | operations to be saved to the local transcript |
| **hl-transcript-queue** | HL-level transcript queue (separate from the user-facing transcript) |
| **auxiliary-queue** | secondary operations (lower priority) |
| **transmit-queue** | operations to be transmitted to the master transcript |
| **local-operation-storage-queue** | operations being temporarily stored locally |

Each queue has:
- A `*<name>-queue*` global (the queue itself, a `queue` struct)
- A `*<name>-queue-lock*` for thread safety
- Standard ops: `<name>-queue-size`, `<name>-queue-empty`, `<name>-queue-enqueue`, `<name>-queue-dequeue`, `<name>-queue-peek`, `<name>-queue-contents`, `clear-<name>-queue`

The enqueue functions notify `*process-wait-cv*` after enqueuing, waking up any thread waiting on `agenda-work-to-do` or similar conditions.

`add-to-local-queue(form, &optional encapsulate?)` — convenience: optionally wrap `form` as an API op via `form-to-api-op` before enqueuing.

`run-one-local-op()`, `run-one-remote-op()` (missing-larkc) — process one operation from the respective queue.

The flow:

```
This image creates an op (e.g. user asserts a fact)
   │
   ▼
local-operation-storage-queue (briefly)
   │
   ▼
local-queue ← run by the agenda
   │
   ▼ executed locally
   │
   ▼
transcript-queue ← saved to disk by the agenda
   │
   ▼
transmit-queue ← sent to master transcript by the agenda

Master transcript                  →  remote-queue ← read by the agenda
                                       │
                                       ▼ executed remotely (this image's perspective)
                                       │
                                       ▼ recorded as having been processed
```

## Communication modes

`operation-communication.lisp` defines six communication modes via `*all-communication-modes*`:

| Mode | Meaning |
|---|---|
| `:transmit-and-receive` | "Sending and Receiving" — full participation |
| `:receive-only` | "Storing and Receiving" — read but don't transmit |
| `:transmit-only` | "Sending Only" — transmit but don't read |
| `:dead-receive` | "Not Recording but Receiving" — read but don't save |
| `:deaf` | "Storing Only" — neither send nor receive |
| `:dead` | "Not Recording or Receiving" — completely offline |

The local image's mode is set via `set-communication-mode`. A typical experimental image is `:dead` (no transmit, no receive); a typical production worker is `:transmit-and-receive`.

### Per-direction switches

Even within a mode, individual switches control specifics:
- `*allow-transmitting*` — master switch for transmitting
- `*receiving-remote-operations?*` — receive switch
- `*process-local-operations?*` — execute local ops
- `*process-auxiliary-operations?*` — execute aux ops
- `*saving-operations?*` — save to transcript (defaults nil)

### Counters

| Counter | What it tracks |
|---|---|
| `*total-remote-operations-run*` | ops from master transcript successfully processed |
| `*total-auxiliary-operations-run*` | aux queue ops processed |
| `*total-local-operations-recorded*` | local ops recorded in local transcript |
| `*total-local-operations-transmitted*` | local ops sent to master transcript |
| `*read-master-transcript-op-number*` | position in master transcript (this image's read cursor) |
| `*total-master-transcript-operations-processed*` | master ops actually executed |

Cumulative across image lifetime; not reset when a new local transcript starts.

### The `*allow-transmitting*` switch

Three reasons for it to be false:
1. The image is `*experimental-image*` (set at startup; experimental images can't pollute the master transcript)
2. The image connected to the transcript server and was given a CLOSED transcript
3. The image read through a master transcript and evaluated `CLOSE-KB`

The first reason is the common case for development. The second and third reflect lifecycle states of the master transcript (experiments end; KBs are formally closed at release).

### Authentication

`*image-requires-authentication?* = nil` — when true, every Cyc API request must be authenticated.
`*cyclist-authenticating-app* = #$CycBrowser` — the application context for authentication.
`*default-cyclist-authentication-mt* = #$CyclistsMt` — the MT for looking up authentication info.

The authentication machinery is mostly missing-larkc — the LarKC port doesn't include the production authentication path.

### Transcript locks

`*save-transcript-ops-lock*` and `*save-hl-transcript-ops-lock*` — global locks that serialise transcript writes. Without them, multiple threads writing the same transcript file would interleave content, corrupting it.

## The task processor

`task-processor.lisp` implements a *worker pool* for handling Cyc API requests, background tasks, and console requests.

### Three pools

| Pool | Purpose |
|---|---|
| `*api-task-process-pool*` | Cyc API requests (network, IPC) |
| `*bg-task-process-pool*` | background tasks |
| `*console-task-process-pool*` | console (REPL) interactions |

Each is a `task-process-pool` struct with:
- `lock` — guards mutation
- `request-queue` — pending requests
- `request-semaphore` — wakes up workers when work arrives
- `processors` — list of `task-processor` instances
- `background-msgs` — log
- `process-name-prefix` — prefix for naming worker threads
- `min-nbr-of-task-processors`, `max-nbr-of-task-processors` — pool sizing

Each pool has its own `-lock` for initialisation (e.g. `*api-task-process-pool-lock*`).

`*min-nbr-of-task-processors* = 5`, `*max-nbr-of-task-processors* = 25` — defaults.

`*task-request-queue-max-size* = 500` — backpressure threshold.

### Per-request: `task-info`

```lisp
(defstruct task-info
  type             ; :api | :bg | :console
  id               ; serial number
  priority         ; integer
  requestor        ; string identifying the requestor
  giveback-info    ; how to send the response back
  bindings         ; environment for evaluation
  request          ; the actual form to evaluate
  response         ; the result (filled by the worker)
  error-message    ; nil unless the worker errored
  task-processor-name) ; which worker handled this
```

The structure flows from request (`request`, `bindings`, `requestor`, `priority`) to response (`response`, `error-message`).

`*task-processor-response-dispatch-fn-dict*` — a dictionary of `task-processor-type → response-dispatch-fn`. After a worker completes, the dispatch function is called to deliver the response to the requestor (over the network, into a queue, to stdout, etc.).

`*task-processor-eval-fn-dict*` — task-processor-type → eval function. For API requests this is `cyc-api-eval`; for other request types it may be raw `eval`.

`*task-processes-being-worked-on*` is an LRU cache of task-process-descriptions → process objects, used to support task suspensions (a task can pause, the worker can be reused, the task can be resumed later).

### Per-worker: `task-processor`

```lisp
(defstruct task-processor
  name        ; thread name
  process     ; the bt:thread
  busy-p      ; is this worker currently running a task?
  task-info)  ; the current task-info (or nil)
```

### Per-result: `task-result-set`

```lisp
(defstruct task-result-set
  result      ; the actual result value
  task-info   ; the originating task-info
  finished)   ; t when complete
```

A `task-result-set` is what the requestor receives back. The `finished` flag is essential for asynchronous results — the requestor can poll, or wait on a condition variable, until `finished` is t.

### Verbosity

`*task-processor-verbosity* = 0` — diagnostic level (0 = quiet, 9 = maximum).

### Background message logging

`*tpool-background-msg-path*` — optional file path for pool background messages.
`*tpool-background-msg-stream*` — open stream for the file.
`*tpool-background-msg-lock*` — serialises writes.

### `*minimize-task-processor-info-communication* = t`

Optimisation: when sending the response back, don't echo the original request. Saves network traffic.

### `*current-task-processor-info*`

Dynamic special: the *current* task-info being processed by the worker thread. Read by deep code that needs to know which request it's handling.

## When does each piece fire?

| Operation | Fires when |
|---|---|
| `start-agenda` | At image startup (if enabled) |
| `agenda-top-level` loop | Continuously, until `halt-agenda` |
| `agenda-work-to-do` | Each iteration of the loop |
| Task quanta | When their `*next-X-time*` is reached |
| Daily GC | Once daily at `*agenda-daily-gc-time-of-day*` (if enabled) |
| Operation queue enqueue | Whenever a new operation arrives (foreground or background) |
| Task processor pool init | Once per pool, lazily on first use |
| Task processor worker | Continuously while pool is alive |
| Communication mode change | User-triggered or transcript-driven |

## Cross-system consumers

- **KB write paths** enqueue operations to local-operation-storage-queue and transcript-queue
- **Cyc API** sends incoming requests to the api-task-process-pool
- **Forward inference** can enqueue propagation work via the agenda
- **Inference analysis** uses the agenda's transcript timing for its statistics
- **Transcript machinery** (in `transcript-server.lisp`, `transcript-utilities.lisp`) consumes the transmit-queue and produces the remote-queue
- **CFASL** is the persistence format for transcript files
- **Memoization-state** uses the agenda's marking-space resource

## Notes for the rewrite

### Agenda

- **The single-threaded agenda is a port-time choice.** The clean rewrite could parallelise per-task, but most tasks are I/O-bound (transcript reads/writes) so there's little to gain. Keep the single-thread model unless profiling shows it as a bottleneck.
- **The 10 SBHL marking spaces** for the agenda are reserved up-front. Necessary because foreground queries can also resource them; without reservation, the agenda might starve.
- **Quanta-based scheduling** is primitive but reliable. Don't replace with a job scheduler unless there's clear value — the current model is debuggable.
- **Daily GC** is opt-in. Default off; enable explicitly when needed.
- **Error modes** — `:halt` is the default (production); `:debug` is for developers; `:log` is for production with bug reports. Keep all four.

### Operation queues

- **Seven queues is excessive.** The clean rewrite should consolidate: most work passes through 2-3 queues, not 7. The split is historical (each queue was added for a specific purpose).
- **Per-queue locks** ensure thread safety. Don't replace with lock-free queues unless profiling shows lock contention.
- **`*process-wait-cv*` is the single condition variable** used to wake up waiting threads. Keep this; multiple CVs would create thundering-herd.
- **`add-to-local-queue` with `encapsulate?`** is the user-friendly entry. Expose this; `local-queue-enqueue` is internal.

### Communication

- **The 6 communication modes** map onto a simple Cartesian product of (transmit?) × (receive?) × (record?). The clean rewrite could express as 3 boolean flags, but the named modes are clearer to operators.
- **`*allow-transmitting*` is a hard switch** — even in `:transmit-and-receive` mode, this can disable transmits. Keep the layering.
- **Authentication is mostly missing-larkc.** The clean rewrite needs to decide whether to implement Cyc-style authentication or use modern OAuth/JWT. Probably the latter.
- **Transcript locks** (`*save-transcript-ops-lock*`, `*save-hl-transcript-ops-lock*`) are critical for correctness. Don't remove.

### Task processor

- **Three pools** for three workload types. Don't merge; the workloads have different characteristics:
  - API: synchronous, latency-sensitive
  - Background: asynchronous, throughput-sensitive
  - Console: interactive, often runs alongside debugger
- **Min/max processors** are tunable. The defaults (5/25) are reasonable for a small server; production should tune based on hardware.
- **`task-info` carries everything** request-related. Keep the struct shape; it's the cleanest cross-thread message.
- **Eval-fn dispatch** by type lets each pool use a different evaluator. API uses `cyc-api-eval` (sandbox); console uses `eval` (full Lisp). Keep the indirection.
- **Response-dispatch fn dispatch** likewise: each pool delivers responses differently. API serialises over network; background queues into a result-dict; console prints. Keep the indirection.
- **`*task-processes-being-worked-on*` LRU cache** supports task suspension (pausing a long-running query, resuming later from the same worker). Keep this if suspension is needed; the modern equivalent is async/await with a cancellation token.
- **`*current-task-processor-info*` dynamic special** is the standard way to thread context through deep code. Keep it.
- **Many of the task-processor functions are missing-larkc.** The struct slots and accessors are documented; the orchestration logic is in the missing-larkc bodies. The shape is well-bounded; the rewrite needs to implement: enqueue, dequeue, evaluate, response-dispatch, suspend, resume.
