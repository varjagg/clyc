# Misc utilities — startup and KB-handle dispatch

Two files of grab-bag utilities. Their importance is wildly disproportionate to their size:

- **`misc-utilities.lisp`** (313 lines) is **the boot sequence** — `system-code-initializations` is what every Cyc image runs at startup to wire up subsystems. Plus a handful of small helpers (`machine-bogomips`, `warn-unless`, `other-binary-arg`, etc.).

- **`misc-kb-utilities.lisp`** (137 lines) defines **the typed-handle dispatch system** — every KB object (constant, NART, variable, assertion, deduction) has a kind-tagged "KB handle" `(type . id)` that lets cross-system code refer to objects without knowing their specific defstruct. Plus the registration table for resolving handles back to objects.

Despite their "misc" names, both files are load-bearing for system startup.

## Startup: `system-code-initializations`

The single most important function in this file. Called every time the Cyc image is initialised — at first startup, after a KB load, after a re-init request. Its body lays out **the canonical order of subsystem startup**:

```
(defun system-code-initializations (&optional (perform-app-specific-initializations? t))
  (initialize-cyc-product)                       ; product banner / version banner
  (system-code-image-initializations)            ; this image's identity
  (system-code-hl-initializations)               ; HL reasoning layer
  (system-code-inference-initializations)        ; inference engine
  (system-code-api-initializations)              ; API server
  (when perform-app-specific-initializations?
    (system-code-application-initializations))   ; application-specific (e.g. asked-query-queue)
  (if (positive-integer-p (kb-loaded))
      (system-kb-initializations)                 ; KB-dependent state
      (warn "No KB is loaded.  System KB initializations will not be run."))
  (setf *system-code-initializations-marker* (get-process-id))
  t)
```

The `*system-code-initializations-marker*` is set to the current process-id; this is how `system-code-initializations-run-p` detects whether the current process already ran initialisation. (Useful when forking — child processes need to re-run because they inherited the marker but lose all the in-process state on KB-load failures.)

### When does each phase run?

| Phase | Operations | Why |
|---|---|---|
| `image-initializations` | `seed-random`, `reset-cycl-start-time`, `set-cyc-image-id`, `clear-machine-bogomips`, `validate-all-tcp-servers`, `clear-active-os-processes` | Establish per-image identity (image-id, start time) and reset state that depends on the previous image's process id (TCP servers, OS subprocess registry). |
| `hl-initializations` | `disable-hlmts`, `initialize-sbhl-modules` | Reset HL-MT state (cleared from any previous run); reinitialize the SBHL search modules. |
| `inference-initializations` | `reclassify-removal-modules`, `reclassify-hl-storage-modules`, `destroy-all-problem-stores`, `initialize-pad-table` | Reload the inference module classification tables; tear down any in-flight inferences from the previous image; reinit the PAD (problem-analysis-data) table. |
| `api-initializations` | `reset-java-api-kernel` | Reset the Java-API socket bookkeeping. |
| `application-initializations` | `clear-asked-query-queue` | Reset the asked-queries log. |
| `kb-initializations` (only if KB loaded) | `initialize-hl-store-caches`, `set-the-cyclist *default-cyclist-name*`, `initialize-transcript-handling`, `initialize-agenda`, `initialize-global-locks`, `perform-cyc-testing-initializations`, `initialize-kct`, file-backed cache initialiser thread + 0.5s sleep | KB-dependent state — only meaningful when the KB has been loaded; otherwise a warning is logged. |

The `(sleep 0.5)` after spawning the file-backed-cache initialiser thread is **a startup-race workaround** — the cache initializer needs to register its own state before the agenda can start using it. A clean rewrite should use a synchronization primitive (semaphore, condvar) instead of timed sleep.

The `*default-cyclist-name*` defaults to `"Guest"` (`system-parameters.lisp`); a real deployment should change this before startup or via the `*the-cyclist*` API.

### When does the startup state mutate or disappear?

| Trigger | Effect |
|---|---|
| `system-code-initializations` called | All subsystem state is reset and initialized as above. |
| `redo-system-code-initializations` (LarKC-stripped) | Re-runs the full pipeline. Used after KB swap or test-induced wipe. |
| Process fork | `*system-code-initializations-marker*` no longer matches `get-process-id`; `system-code-initializations-run-p` returns NIL until rerun. |
| Image shutdown | All state is dropped. Any persistent state is in the dump files; runtime state evaporates. |

`*hl-store-caches-directory*` is the path where on-disk HL-store caches live. Set lazily by `set-hl-store-caches-directory` from a computation in `hl-store-caches-directory` (which falls back to `missing-larkc 30777`, presumably a "compute the cache directory from KB version"). Caches survive across image restarts; the directory persists.

`*hl-store-caches-shared-symbols*` is the symbol table shared across HL-store cache files — symbols that need to stay interned across the cache load/save cycle.

## HL store caches

```
(defun initialize-hl-store-caches ()
  (unless (hl-store-content-completely-cached?)
    (initialize-hl-store-caches-from-directory (hl-store-caches-directory))))
```

The HL store has **on-disk caches** (file-backed-cache files; see [../persistence/file-backed-cache.md](../persistence/file-backed-cache.md)) for the major KB-handle types. `initialize-hl-store-caches-from-directory` initialises each one in turn:

```
initialize-deduction-hl-store-cache
initialize-assertion-hl-store-cache
initialize-constant-index-hl-store-cache
initialize-nart-index-hl-store-cache
initialize-nart-hl-formula-hl-store-cache
initialize-unrepresented-term-index-hl-store-cache
initialize-kb-hl-support-hl-store-cache
initialize-sbhl-graph-caches
reconnect-tva-cache-registry
```

Each one opens its file-backed cache and wires it up to the in-memory ID-index. See [../kb-access/kb-object-manager.md](../kb-access/kb-object-manager.md) for how the file-backed cache integrates with the LRU / object manager.

`hl-store-content-completely-cached?` is the gate — if all caches are already populated and consistent, skip the directory-load step. Currently `missing-larkc` for several of the type-specific predicates, so the gate currently always returns NIL and the caches always load.

## Bogomips: a vestigial benchmark

`*machine-bogomips*` holds an empirical CPU speed metric (used by `scale-by-bogomips` to make timeout values portable across machines). The implementation reads `/proc/cpuinfo` for the "bogomips" line. Linux-only; on macOS or Windows it returns NIL.

```
(defun scale-by-bogomips (numbers bogomips)
  ;; multiply by bogomips/(machine-bogomips)
  ...)
```

If the current machine is twice as fast as a reference, scale numeric thresholds (e.g. inference timeouts) down by half. Used historically for cross-machine test reproducibility — a slow CI machine that takes longer can adjust timeouts up so tests still pass.

bogomips itself is a **deeply unreliable** speed metric (literally "bogus mips" — Linux uses it for calibrating delay loops, not for benchmarking). A clean rewrite should use a real benchmark or just not portably scale timeouts. The `compute-machine-bogomips` function has a TODO that notes "infinite loop if 'bogomips' not found" — a real CPU benchmark would have to run for non-trivial time anyway.

## `warn-unless`

```
(defmacro warn-unless (form format-string &rest arguments)
  `(unless ,form (warn ,format-string ,@arguments)))
```

A small reconstructed macro — "if FORM is false, log a warning." Used for soft-fail diagnostics where the caller wants to log but continue. ~30 call sites.

## Some leftover helpers

| Function | Purpose |
|---|---|
| `(other-binary-arg arg)` | Takes 1, returns 2; takes 2, returns 1. The "swap arg position" helper used by binary-relation iteration. |
| `(uninitialized)`, `(uninitialized-p obj)`, `(initialized-p obj)` | The `:uninitialized` keyword convention for "not yet computed" lazy values. |
| `*kb-content-copyright-notice*` | Text constant; unused in LarKC. Apparently for KBs Cycorp distributes as commercial products. |

## KB handles

`misc-kb-utilities.lisp` defines **the typed-handle dispatch mechanism**.

A "KB handle" is a `(type . id)` pair that uniquely identifies an object across the whole KB:

| Object kind | Handle |
|---|---|
| Constant | `(:constant . internal-id)` |
| NART | `(:nart . id)` |
| Variable | `(:variable . id)` |
| Assertion | `(:assertion . id)` |
| Deduction | `(:deduction . id)` |

The point: code that wants to refer to "this KB object" generically — without knowing whether it's a constant, NART, etc. — uses a handle. Polymorphism without inheritance.

### Two dispatch tables

```
*kb-handle-internal-method-table*    ; vector of 256 entries indexed by type tag — for fast handle-from-object dispatch
*find-object-by-kb-handle-methods*   ; alist of (type method) — for handle-to-object dispatch
```

The first is a 256-element array indexed by SubL's type-tag byte (e.g. `*dtp-constant*` = some integer). Given an object, the type tag gets a `kb-handle-internal-X-method` function from the table; that function returns `(values type id)`. The CL port has the array but doesn't populate it (the SubL type-tag mechanism doesn't exist in CL); the per-type methods are still callable directly.

The second is an alist used by `find-object-by-kb-handle type id` to do the inverse — given `(type, id)`, look up the appropriate `find-X-by-id` function and call it.

### When does the dispatch table get populated?

```
(toplevel
  (register-find-object-by-kb-handle-method :constant 'find-constant-by-internal-id)
  (register-find-object-by-kb-handle-method :nart 'find-nart-by-id)
  (register-find-object-by-kb-handle-method :variable 'find-variable-by-id)
  (register-find-object-by-kb-handle-method :assertion 'find-assertion-by-id)
  (register-find-object-by-kb-handle-method :deduction 'find-deduction-by-id))
```

At image startup, five entries get registered — one per KB-object-kind. Each says "to find an object of type T, call this function with id." The alist is a plain list with `delete`-then-`push` for replacement (idempotent registration).

`register-find-object-by-kb-handle-method type method` is the public API; new object kinds (e.g. KB-HL-supports, clause-strucs) would register here too. In the current code only the five core kinds register.

### The five surviving methods

```
kb-handle-internal-constant-method object   → (values :constant (constant-internal-id object))
kb-handle-internal-nart-method object       → missing-larkc 4609 (would be :nart + nart-id)
kb-handle-internal-variable-method object   → (values :variable (variable-id object))
kb-handle-internal-assertion-method object  → (values :assertion (assertion-id object))
kb-handle-internal-deduction-method object  → (values :deduction (deduction-id object))
```

The NART method is the only stripped one — the others have surviving bodies that just call the type-specific id accessor. `(values type id)` is the canonical handle representation; the alist version is `(cons type id)` for storage.

## Where KB handles are consumed

KB handles are consumed by every file that wants polymorphic KB-object reference:

- **Externalisation / CFASL**: handles are the wire form for cross-image references when the receiver doesn't share an id space.
- **Dump / load**: each dumped object record has a handle as its "header" so the loader can dispatch to the correct `find-X-by-id` reconstructor.
- **The agenda**: `task-info` slots can hold KB handles to refer to assertions/constants without keeping the actual object alive.
- **The KE / FI**: `(fi-object-from-handle h)` resolves a handle to its object before applying the operation. The function is LarKC-stripped but the wiring is here.
- **`possibly-clear-genl-pos`** is a stub that always returns `:checked` — a placeholder for an after-adding hook that would clear `#$genl-pos` indices when an affecting assertion is added.

## How other systems consume misc-utilities and misc-kb-utilities

- **`system-code-initializations`** is called from `cyc-kernel.lisp` (see [control-vars.md](control-vars.md)) and from any image-restart path. The single most-important entry point in misc-utilities.
- **`other-binary-arg`** is consumed by binary-relation traversal in `genls.lisp`, `isa.lisp`, etc. ~10 call sites.
- **`warn-unless`** has ~30 call sites scattered across the codebase.
- **`machine-bogomips`** / **`scale-by-bogomips`** is consumed by `cardinality-estimates.lisp` (used to scale per-system inference cost estimates).
- **KB handles** consumed by ~20 files; `register-find-object-by-kb-handle-method` is consumed only here.

## Notes for a clean rewrite

### misc-utilities

- **`system-code-initializations` is the canonical init script.** Keep it as a sequence of explicit phase calls. Rename to `(initialize-system &key with-kb)` or similar.
- **The phase dependencies are implicit.** A clean rewrite should make them explicit: each phase declares its dependencies; the orchestrator computes the order. This makes adding new phases (or reordering) safer.
- **Drop the `(sleep 0.5)` at the end.** Use a real synchronization. The cache-initializer thread should signal a semaphore when it's done its registration; the main thread waits on the semaphore.
- **`*system-code-initializations-marker*` = pid-tracking** is a fork-survival mechanism. Modern: most languages don't fork at runtime. If you care about post-fork init, hook a fork-handler explicitly.
- **`bogomips` should die.** Either drop the timeout-scaling entirely or use a real benchmark. Bogomips is meaningless on modern CPUs.
- **`warn-unless` is fine.** Keep it.
- **`uninitialized` / `uninitialized-p` / `initialized-p`** is a common idiom. Modern CL has `:uninitialized` keyword convention or `(values nil :reason)` returns. Pick one and use it consistently.
- **`*kb-content-copyright-notice*`** is a text constant for a feature LarKC doesn't have. Drop it.
- **The HL-store-cache initialization sequence is hand-coded.** A clean rewrite should make each cache module register its own initializer; the orchestrator iterates registrations.

### misc-kb-utilities

- **The KB-handle abstraction is good design.** Polymorphic reference without inheritance is exactly what's needed. Keep it.
- **Drop the type-tag dispatch table.** SubL's 256-entry table is a SubL-specific mechanism. CL's typecase dispatch is the right primitive — let the compiler optimise it.
- **`register-find-object-by-kb-handle-method` is the right shape.** A registry of `(type → reconstructor)` pairs that other modules add to. Keep it; rename `:method` to `:reconstructor` for clarity.
- **The `(type . id)` cons-pair representation works.** A clean rewrite could use a struct with two slots, but cons is fine and idiomatic. The tradeoff is indistinguishable.
- **Add type-tag for kb-hl-support, clause-struc.** The current five-kind set is incomplete. Once KB-HL-supports and clause-strucs are first-class, they should register their own handle methods. The NART method itself is `missing-larkc` and needs reconstruction — port it directly from the surviving constant/variable/assertion/deduction patterns.
- **`possibly-clear-genl-pos` is a stub-pretending-to-be-real.** Either implement it properly (clear the genl-pos cache when the predicate's `(:isa ?x #$TransitiveBinaryPredicate)` changes) or remove it.
- **`fi-object-from-handle`** is a key public-API function for resolving handles. LarKC-stripped, needs porting.
