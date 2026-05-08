# Process utilities, OS process utilities, timing

Three files of **concurrency primitives and timing instrumentation**:

- `process-utilities.lisp` (128 lines) — **threads & IPC primitives**. "Process" here means thread (the old Lisp usage). Three defstructs (`task`, `thinking-task`, `ipc-queue`, `ordered-ipc-queue`, `process-wrapper`) plus helpers for visiting threads and locks. **Mostly stripped.**
- `os-process-utilities.lisp` (248 lines) — **subprocess management**. The `os-process-impl` defstruct holds metadata for a child OS process (program, args, stdin/stdout/stderr streams, status, exit code). `make-os-process` spawns a process; the active list lives in `*active-os-processes*`. **Substantially stripped.**
- `timing.lisp` (99 lines) — **per-function timing instrumentation**. `(deftimed name ...)` would record per-call timing into `*timing-table*`. **Almost entirely stripped** — only the variables, the `timing-info` defstruct, and the file header survive.

These are infrastructure layers that the LarKC port leaves mostly as design surface. Concurrency primitives end up partially-implemented because the Java→CL port had to bridge SubL's "process" model (essentially CL's special-variable threads) to the host CL's `bordeaux-threads` model (more rigorous about thread-local state). Subprocess management gets stripped because no LarKC-distributed code launches subprocesses.

## Process-utilities: threads and IPC

### `task` defstruct

A "task" is **the simplest possible thread wrapper**:

```
(defstruct task
  process     ; the bt:thread
  completed)  ; bool
```

Used when code wants to "fire-and-check" — start a thread, periodically poll `completed` until it flips to T. No structured cancellation, no result delivery; just fire-and-forget with a completion flag.

### `thinking-task` defstruct

A heavier task with **progress reporting and result/error capture**:

```
(defstruct (thinking-task (:conc-name "T-TASK-"))
  lock
  thread
  name
  status
  progress-message  ; e.g. "Iterating constants..."
  progress-sofar    ; integer
  progress-total    ; integer
  start-time
  finish-time
  result
  error-message
  properties)       ; user-supplied alist
```

Per-task state for "long-running computation that the user is watching." The progress-N triplet is consumed by progress-bar UIs (the KE shows them in the status bar). Result + error-message are how the watching thread reads back the answer.

`*thinking-task*` is the per-thread current task — bound to the active `thinking-task` for the duration of work. Code that wants to update progress reads `*thinking-task*` and mutates the slots.

The lifecycle (functions all stripped):
- `(new-thinking-task name)` — mint
- `(set-thinking-task-progress sofar total message)` — update
- `(thinking-task-finish task result)` — mark complete with result
- `(thinking-task-fail task error)` — mark failed

### IPC queues

```
(defstruct ipc-queue
  lock semaphore data-queue)

(defstruct (ordered-ipc-queue (:conc-name "ORDRD-IPCQ-"))
  lock producer-isg consumer-isg payload)
```

Two flavours of inter-thread queue:

- **`ipc-queue`** is unordered — a producer pushes, the semaphore signals, a consumer pops. Multiple consumers may pop in any order if the data-queue uses a hashtable. Used for fan-in scenarios (many producers → one consumer pulls work).

- **`ordered-ipc-queue`** uses **integer-sequence-generators** (one for the producer, one for the consumer) to enforce **delivery order**. Each producer call increments the producer-isg and tags the payload; the consumer reads the next item by consumer-isg and waits if it's not yet present. Used when the order of items matters across producer-side races (e.g. transcript ops must be applied in producer-side commit order even if multiple producers are concurrent).

`*ordered-ipcq-empty*` is the sentinel for "this slot in the payload doesn't have a value yet" — distinguishes empty-but-allocated from never-allocated.

Both queue types are mostly stripped. The defstructs survive; the `enqueue`/`dequeue`/`peek` operations are LarKC-stripped.

### `process-wrapper`

```
(defstruct process-wrapper
  id process state lock plist)
```

A **decorated thread**: an integer id, the underlying bt:thread, a state symbol (`:running`, `:blocked`, etc.), a per-wrapper lock, and an arbitrary properties list. The TODO comment notes "never used" — the abstraction was forward-looking but no surviving code allocates a `process-wrapper`. Could be used for "thread with extra metadata" if the rewrite needs that.

### `make-exhausted-process` and the visit-defstruct integration

```
(defun process-exhaust-immediately-fn () nil)

(defun make-exhausted-process (name)
  "[Cyc] A wrapper for creating an already exhausted process."
  (bt:make-thread #'process-exhaust-immediately-fn :name name))
```

Spawns a thread that **immediately exits**. Used as a placeholder when code wants a thread-shaped value without actually doing work — e.g. for a process slot in a `task-info` that hasn't been assigned to a worker yet, or for testing.

The two `defmethod visit-defstruct-object` for `sb-thread:thread` and `sb-thread:mutex` plug into Cyc's structure-visitor machinery — when serialising a structure that contains a thread or mutex, the visitor calls these methods to skip over the live object and emit a re-creatable form (`make-exhausted-process` for threads, `bt:make-lock` for mutexes). Threads and locks aren't serialisable — these methods produce a placeholder that the loader can re-instantiate.

The TODO notes the dispatch hits SBCL internals because CL doesn't allow `defmethod` to dispatch on type rather than class — and `sb-thread:thread` is a class but `bt:lock` is something else on different impls. SBCL-specific code.

### `kill-process-named name`

The single registered Cyc API function in this file. Kills any thread with the given name. Note: `kill-process` isn't supported on Win32 (per the docstring). Stripped in the LarKC port — only the registration survives.

## OS process utilities: subprocess management

`os-process-utilities.lisp` is the **subprocess (child OS process, not thread) management** layer. Cyc occasionally needs to spawn an external command — invoke `gunzip`, run a helper script, call out to an SDC database connector. The os-process API encapsulates this.

### `os-process-impl` defstruct

15 slots tracking everything about a child process:

```
(defstruct (os-process-impl (:conc-name "OS-PROCESS-IMPL-")
                            (:constructor make-os-process-impl
                              (&key id name program arguments
                                    stdin-stream stdin-filename
                                    stdout-stream stdout-filename
                                    stderr-stream stderr-filename
                                    status started finished
                                    exit-code properties)))
  id name program arguments
  stdin-stream stdin-filename
  stdout-stream stdout-filename
  stderr-stream stderr-filename
  status started finished
  exit-code properties)
```

Slot semantics:

| Slots | Purpose |
|---|---|
| `id name program arguments` | What was launched: process id (PID), human-readable name, program path, arglist. |
| `stdin-stream stdin-filename`, etc. | The three standard streams. Each can be either a live stream object (caller passed `*standard-input*` etc.) or a filename that the spawn redirected to. |
| `status` | One of `:initializing`, `:running`, `:dead`, `:failure` (`*valid-os-process-status*`). |
| `started finished` | Universal-time timestamps. |
| `exit-code` | Set when status = `:dead` or `:failure`. |
| `properties` | User-supplied alist for extra metadata. |

`*dtp-os-process-impl*` = `'os-process-impl` is the type tag.

### Active-process registry

```
*active-os-processes*  ; list of all currently-running os-process-impl structs
*os-process-enumeration-lock*  ; serialises mutation of the list
```

Both are deflexicals with `boundp` guards (so reloading the file doesn't wipe an existing list). `clear-active-os-processes` is called from `system-code-image-initializations` ([misc-utilities.md](misc-utilities.md)) to reset the list at image startup — child processes that the previous image launched aren't tracked anymore (the OS may have killed them when the parent exited).

### Lifecycle

| Trigger | Effect |
|---|---|
| `(make-os-process name program &optional args stdin stdout stderr)` | Allocate the impl struct, set `started`, `status` ← `:initializing`. Resolve stream specs (file path → open file, `:stream` → make-pipe). Call host CL's `sb-ext:run-program` (LarKC-stripped path) to actually fork+exec. On success, set status ← `:running`, register in `*active-os-processes*`. |
| Process exits | A reaper thread (LarKC-stripped) detects exit, sets `finished`, `exit-code`, status ← `:dead` or `:failure`. Removes from `*active-os-processes*`. |
| `(kill-os-processes-named name)` | Iterate `*active-os-processes*` looking for matching name; send SIGTERM (or platform equivalent). |
| `(all-os-processes)`, `(show-os-processes)`, `(os-processes-named name)` | Query helpers. All stripped. |
| `(remove-os-process-from-active-list os-process &optional warn?)` | Manual deregister. |

The actual `make-os-process` body has 3 `missing-larkc` calls for the stream-spec resolution paths and a `multiple-value-bind` of stream-stream-stream-pid that's the host's `run-program` result. Most callers in the codebase pass already-resolved streams, so the `missing-larkc` paths are the rarely-exercised ones — but this means file-redirection of subprocess output doesn't work in the LarKC port.

## Timing: per-function instrumentation

`timing.lisp` is **the function-call timing system**. It would let you say "time every call to `assert-cnf`" and produce a report with call-count, total time, max time per call.

### Surviving state

```
*time-testing-environment*  ; hashtable, key → run results
*timing-table*              ; hashtable, function-symbol → timing-info
*utilize-timing-hooks*      ; T (default) — master switch
*all-currently-active*      ; T = time everything; NIL = only *timed-funs*
*timed-funs*                ; list of function symbols to time
```

```
(defstruct timing-info
  count    ; how many calls
  total    ; total elapsed time
  max)     ; max single-call time
```

`*dtp-timing-info*` = `'timing-info`.

### Stripped: everything else

The whole API is missing-larkc:

- `(timing-these-functions (...) body)` macro — wrap body with timing for these functions.
- `(timing-all-functions body)`, `(timing-no-functions body)` — set `*all-currently-active*`.
- `(deftimed name args body)` — like `defun` but installs a timing wrapper.
- `(report-timing-info &optional stream)` — print the report.
- `(clear-timing-info)`, `(clear-time-testing-info)` — wipe.
- `(record-time fun time)`, `(update-timing-info timing-info time)`, `(new-timing-info time)` — internal updaters.
- `(time-function? fun)` — predicate: is this function being timed?

The timing instrumentation would have wrapped every `deftimed` function in `(let ((start (get-internal-real-time))) (unwind-protect body (record-time 'name (- (get-internal-real-time) start))))`. The records would accumulate in `*timing-table*`. `report-timing-info` would walk the table and print one line per timed function with count, total, max, average.

In the LarKC port, the abstraction is gone but the data structure survives. The clean rewrite needs to either reimplement (host languages have profilers; CL has `time` and SBCL has `sb-profile`) or drop entirely.

## How other systems consume these

- **`thinking-task`** would be consumed by long-running operations (KB load, KB dump, large inferences) for progress reporting. Currently no live consumers.
- **`task`** is consumed by `*system-code-initializations*` for the `bt:make-thread` of the file-backed-cache initializer ([misc-utilities.md](misc-utilities.md)).
- **`ipc-queue` / `ordered-ipc-queue`** would have been used by the operation-queues system ([../inference/agenda.md](../inference/agenda.md)). The actual operation-queues use a different mechanism (a `priority-queue` from `queues.lisp`).
- **`os-process-impl`** would be consumed by SDC/SDBC database connectors and any helper-script invocations. Currently not consumed because the consumer code is stripped.
- **`clear-active-os-processes`** is called from `system-code-image-initializations`. The other os-process functions have no surviving consumers.
- **Timing**: no surviving consumers.
- **`*thinking-task*`** parameter is referenced by progress-reporting code in some files (`progress-cdotimes`, `note-percent-progress`) — see `format-nil.lisp` for the progress-bar machinery.

## Notes for a clean rewrite

### Process utilities

- **Drop the SubL "process" terminology.** Modern CL says "thread"; everyone else says "thread"; only Lisp ancestry says "process." Rename throughout.
- **`task` is a placeholder for a future.** Use the host's promise/future/Task type. CL has `lparallel`'s futures; Rust has `Future`; Python has `asyncio.Task`. Don't roll your own.
- **`thinking-task` is a long-running-operation tracker with progress.** Worth keeping but unify with the task-processor's `task-info` ([task-processor.md](task-processor.md)) — same shape, different name. One struct.
- **IPC queues should be the host's channel/queue.** `bt:semaphore` + `queue` → `bordeaux-threads-2`'s `mailbox` or just standard library queues.
- **`process-wrapper` is dead. Remove it.**
- **`make-exhausted-process` is a hack.** Replace with `nil`-as-no-thread and let callers check for nil. The "I need a thread-shaped value but no actual thread" use case shouldn't exist.
- **The `defmethod visit-defstruct-object` for thread/mutex** is a serialization hack — if a clean rewrite doesn't serialize threads, drop these methods. If it does, use the host's `make-load-form` / `serde::Serialize` / `pickle` mechanisms.

### OS process utilities

- **Use the host's subprocess library.** SBCL has `sb-ext:run-program`; Python has `subprocess`; Rust has `std::process::Command`. Don't build a 15-slot abstraction over the host's primitive.
- **The 15 slots are right (PID, name, program, args, three streams, status, timing, exit code, properties).** Port them to a clean rewrite as a thin wrapper struct over the host's process handle.
- **`*active-os-processes*` is a real-process registry.** Useful for "show me what's running" diagnostics. Keep but make it a weak-ref'd hashtable so dead processes don't leak.
- **Don't reinvent stream redirection.** `:stream` / filename / live-stream resolution is what the host already does. Pass through.
- **The reaper thread is a real concern.** Each spawned process needs `wait()`-ing or its zombie status will leak. The host library handles this; don't undermine.

### Timing

- **Use the host profiler.** SBCL has `sb-profile` with similar semantics. Drop this file.
- **Or build on top of metrics.** Modern observability uses Prometheus/StatsD/etc. — emit counters and histograms instead of accumulating in a hashtable.
- **The `count/total/max` triple is right.** A clean rewrite that keeps timing should also track p50/p95/p99 percentiles (use a HDR histogram).
- **`*utilize-timing-hooks*` is the right design** — a master switch to elide all instrumentation in production. Make it a build-time conditional rather than a runtime flag (avoid the "is timing enabled" branch on every timed call).
