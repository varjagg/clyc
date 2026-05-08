# Guardian — async safety / interruption

The **guardian** is a **single background thread that periodically checks user-supplied predicates and notifies/interrupts the requesting thread when a predicate flips**. It's a generic mechanism for "watch this condition and tell me when it's no longer NIL" — used primarily for **safety-style timeouts and external cancellation** of long-running operations.

The implementation is `guardian.lisp` (221 lines). **Almost the whole file is missing-larkc** — only one defstruct, one reconstructed macro, four defglobal/deflexical variables, and the API registrations survive. The actual guardian-thread main loop, request scheduling, and notification dispatch are stripped.

## What the guardian is for

A long-running task — say, an inference that's been running 30 seconds — needs an external way to be cancelled. The task itself can't poll for cancellation cheaply; instead, the cancellation requestor schedules a **guardian request**:

```
(schedule-guardian-request checker-fn parameter notification-fn &optional process interrupt-p)
```

The guardian periodically calls `(funcall checker-fn parameter)`. As long as that returns non-NIL, the task continues. When it returns NIL, the guardian fires the notification:

- If `interrupt-p` is NIL: `(funcall notification-fn parameter)` runs **on the guardian thread**. Useful when the action doesn't need to interrupt the watched thread (e.g. logging, signalling another thread).
- If `interrupt-p` is T: `(interrupt-process-with-args process notification-fn parameter)` interrupts the watched thread and runs the notification *in that thread's context*. Useful when the action is "throw out of the long-running computation."

The `process` argument defaults to the current thread (`(current-process)`); the watched thread is whoever scheduled the request unless explicitly overridden.

`schedule-guardian-request` returns a request-id (a fixnum); the requestor saves it so they can later `(cancel-guardian-request request-id)` if their work finishes before the guardian fires.

## The data structure

```
(defstruct guardian-request
  id                  ; fixnum, allocated by *guardian-isg*
  checker-fn          ; predicate to poll
  parameter           ; arg to pass to checker-fn and notification-fn
  notification-fn     ; what to do when checker-fn returns NIL
  interrupt-p         ; T = interrupt the requesting process; NIL = funcall
  process)            ; the process to interrupt (if interrupt-p)
```

`*dtp-guardian-request*` = `'guardian-request` is the type tag.

`*guarding-requests*` is the global list of pending requests (NIL when none scheduled).

`*guardian-process*` is the BT thread running the guardian loop, or NIL when not running.

`*guardian-isg*` is an integer-sequence-generator used to mint unique request-ids.

`*guardian-timeslice*` = 2 — number of seconds between successive checks. The guardian wakes every 2s, walks the request list, runs each `checker-fn`, fires notifications for any that flipped to NIL.

`*guardian-shutdown-marker*` and `*guardian-sleep-marker*` are uninterned-symbol sentinels used to communicate with the guardian thread without using locks (the markers are passed via `interrupt-process` to wake the guardian for shutdown or for an immediate check).

## When does the guardian come into being?

`(initialize-guardian)` — typically called at image startup or lazily on first `with-guardian-request`. Spawns the guardian thread; `*guardian-process*` ← the new thread; the thread runs `guardian-handler` which is the main loop.

`(start-guardian)` — same but stronger: stops any existing guardian first, then starts a fresh one. Used for "I want a fresh guardian, kill the old one."

`(ensure-guardian-running)` — idempotent: if `*guardian-process*` is alive, no-op; otherwise calls `start-guardian`. The reconstructed `with-guardian-request` macro calls this before scheduling, so guardian-using code doesn't have to worry about whether the guardian is running.

`(stop-guardian)` — interrupts the guardian thread with `*guardian-shutdown-marker*`; the thread exits its loop and dies.

All four lifecycle functions are LarKC-stripped. The guardian's main loop (`guardian-handler`) is also stripped — the surviving file describes the design surface but has no live implementation.

## When does a guardian request come into being or disappear?

| Trigger | Effect |
|---|---|
| `(schedule-guardian-request checker-fn parameter notification-fn &optional process interrupt-p)` | Mint a `guardian-request` with id = `(next-integer-sequence *guardian-isg*)`. Push onto `*guarding-requests*`. Return the id. |
| `(cancel-guardian-request request-id)` | Remove the request matching `request-id` from the list. Returns symbol (T or NIL). |
| `(with-guardian-request (checker-fn parameter notification-fn) body)` | The reconstructed macro: ensure guardian is running, schedule a request, run body, cancel-on-exit via unwind-protect. Most user code goes through this rather than `schedule` directly. |
| Guardian thread polls and sees `(funcall checker-fn parameter)` returned NIL | Fires notification (funcall or interrupt depending on `interrupt-p`). Removes the request from `*guarding-requests*`. |

The `with-guardian-request` macro is the **idiomatic usage** — it ties the request lifecycle to a body's dynamic extent, ensuring cleanup even on non-local exit. Without it, a thrown exception during the guarded body would leak the request (the guardian would keep firing forever).

The reconstructed macro:

```
(defmacro with-guardian-request ((checker-fn parameter notification-fn) &body body)
  (with-temp-vars (request-id)
    `(progn
       (ensure-guardian-running)
       (let ((,request-id (schedule-guardian-request ,checker-fn ,parameter ,notification-fn)))
         (unwind-protect
              (progn ,@body)
           (when ,request-id
             (cancel-guardian-request ,request-id)))))))
```

The macro gensyms the request-id var so nested uses don't collide.

## Public API surface

Six API functions + one macro registered:

| Entry | Purpose |
|---|---|
| `schedule-guardian-request` | Submit a watch request. |
| `guardian-request-id-p` | Validate a request id. |
| `cancel-guardian-request` | Withdraw a request. |
| `with-guardian-request` (macro) | Idiomatic scoped use. |
| `active-guardian-requests` | List currently-pending requests + a timestamp of the list contents (for clients that want to subscribe to changes). |
| `initialize-guardian` | Start guardian if not running. |
| `stop-guardian` | Shut down. |
| `start-guardian` | Restart (kill-and-start). |
| `ensure-guardian-running` | Idempotent start. |

These are exposed via `register-cyc-api-function` / `register-cyc-api-macro`. Clients that want to programmatically watch conditions can submit guardian requests through the API.

## How is the guardian used in Cyc?

In Cyc the engine, the guardian is consumed primarily by:

- **Inference timeouts** — schedule a request `(checker-fn = (lambda (_) (< (elapsed-time) deadline)))` with `interrupt-p T`. When the time elapses, the inference thread is interrupted and unwinds.
- **Memory-pressure cancellation** — schedule with `(checker-fn = (lambda (_) (< (memory-used) limit)))`. Long-running tasks that exceed memory get pulled.
- **External shutdown signals** — schedule with `(checker-fn = (lambda (_) (not *system-shutting-down?*)))`. When shutdown is requested, the watching thread is killed.
- **`task-processor` cancellation** ([task-processor.md](task-processor.md)) — `terminate-active-task-processes` interrupts a task-processor worker, but the underlying mechanism — periodically polling a "should-cancel?" flag and signalling on flip — is exactly the guardian's job.

In the LarKC port, **none of these consumers are wired up** because the guardian's main-loop body is stripped. The API surface is preserved as the spec.

## Notes for a clean rewrite

- **The guardian is "watch a condition periodically and signal on flip" — a common pattern.** Modern languages have it: Tokio's `tokio::select!`, Go's `context.WithCancel`, JS's `AbortController`. A clean rewrite should use the host's idiomatic mechanism.
- **2s polling is wrong for inference timeouts.** Inference-step boundaries are sub-millisecond; a 2s polling interval means deadline overshoot up to 2 seconds. A clean rewrite should support both polling guardians (cheap, coarse) and event-triggered guardians (expensive setup, fine-grained).
- **Combine guardian with `with-timeout`** ([modules-and-subl.md](modules-and-subl.md)). Both implement "watch a deadline and unwind." `with-timeout` uses a per-invocation watchdog thread; the guardian uses a shared thread with multiple requests. The shared model is more efficient, but `with-timeout` is integrated with SubL's exception-handling. A clean rewrite should unify these — one mechanism, one thread, both APIs.
- **`interrupt-p` selecting between `funcall` and `interrupt-process`** is fragile. `interrupt-process` is unsafe in many CL implementations (the comment in `schedule-guardian-request`'s docstring acknowledges this). A clean rewrite should use cooperative cancellation: the watched thread polls a cancellation token at safe points, and the guardian sets the token instead of interrupting.
- **The 6-slot `guardian-request` struct is right.** Keep it but rename: `process` → `target-thread`, `parameter` → `arg`. Drop `interrupt-p` if you adopt cooperative cancellation.
- **`*guardian-isg*`** for id allocation is overkill. A simple `(incf *next-id*)` under the lock is fine.
- **`active-guardian-requests` returns a timestamp.** Useful for caching ("don't refetch the list if it hasn't changed"), but most callers want just the list. A clean rewrite should expose two functions if both are needed.
- **The shutdown-via-uninterned-marker mechanism is clever but obscure.** `*guardian-shutdown-marker*` is a sentinel passed via `interrupt-process` to make the guardian wake and quit. A clean rewrite should use a real shutdown signal (an atomic boolean the loop checks each iteration) — the marker pattern is too SubL-ish.
- **The single guardian thread is a singleton.** That's fine for now, but if guardian usage scales (many requests with different polling intervals), consider per-priority guardians or a thread pool.
- **Connect the guardian to telemetry.** Every fire is interesting (it indicates a long-running task hit its limit). Log the request, parameter, and reason (timeout, memory, shutdown, etc.).
