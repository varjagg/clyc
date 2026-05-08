# Eval-in-API — the SubL-subset interpreter

`eval-in-api` is **the safety boundary that makes the Cyc API exposable**. When `*eval-in-api?*` is T, every form arriving on the API port is walked by a SubL-subset interpreter that checks each operator against the registered-API tables and rejects unknown ones. When NIL (the LarKC default), the API just calls host-language `eval` — fast, but arbitrary-code execution.

In the Cyc engine, `*eval-in-api?*` defaults to T and the interpreter is fully populated. In the LarKC port the interpreter is `missing-larkc 10828` / `10829` — only the *registration manifest* survived. That manifest is `eval-in-api-registrations.lisp` (692 lines): a near-exhaustive catalogue of every symbol Cyc the engine considered safe to expose. The body of `eval-in-api.lisp` (176 lines) is the registration tables, the env-management primitives, and a stub eval that bypasses to host `eval`.

This doc covers both files plus the interpreter-shaped contract that `register-api-*` calls publish into.

## What the interpreter is supposed to do

Given an API request like `(some-fn arg1 (other-fn arg2))`, `eval-in-api` (the function — not the system) walks the form recursively and at each subexpression:

1. **Atom** — if it's a self-evaluating literal, return it. If it's a symbol, look it up in `*eval-in-api-env*` (per-connection variable bindings), then in the API mutable/immutable globals lists, then in the SubL global value cell. Reject unbound symbols rather than erroring out generically.
2. **Cons (operator + args)** — get the operator. Dispatch in priority order:
   - `(api-special-p operator)` → call the registered special handler with the unevaluated args (this is how `quote`, `if`, `let`, etc. work — they need their args unevaluated).
   - `(api-predefined-macro-p operator)` → look up the macro expansion and recurse on the expansion.
   - `(api-predefined-function-p operator)` → recursively eval the args, then `funcall operator <args>` against the host CL function.
   - `(api-predefined-host-function-p operator)` → same as above but only if `*permit-api-host-access*` is T (privileged connections only).
   - `(api-function-p operator)` (user-defined) → look up the user-defined body in `*api-function-table*` and recurse on it with args bound.
   - Otherwise → reject with "operator not exposed via API".

The walker also applies **trace logging** (`*eval-in-api-traced-fns*` / `*eval-in-api-trace-log*`) so a privileged client can ask for a record of every function that was called during a request.

The walker maintains **two stacks**: `*eval-in-api-level*` (function-call depth) and `*eval-in-api-macro-stack*` (currently expanding macros), used for diagnostics and recursion limits.

A **separate verifier** (`verify-in-api`) walks a form *without* evaluating it and reports whether evaluation would succeed. It uses `*verify-in-api-bound-symbols*` and `*verify-in-api-fbound-symbols*` to track in-scope bindings introduced by `let`/`flet`/etc., and `*verify-in-api-macro-stack*` for nested expansions. The verifier exists because clients want to validate a form ahead of submitting it (think of an IDE that gates the "Run" button on whether the form would be accepted).

None of this exists in the port. The body of `cyc-api-eval` is:

```
(if *eval-in-api?*
    (missing-larkc 10828)
    (eval-in-api-subl-eval api-request))   ; → host CL eval
```

`eval-in-api-subl-eval` calls `(funcall *subl-eval-method* form)`, which is `eval` in the LarKC build. The `*subl-eval-method*` indirection was meant to let the interpreter swap in a different eval (e.g. one that records execution time per form, or one that catches `error` differently); none of those alternatives ship.

## The state the system owns

### Per-connection eval environment

```
*eval-in-api-env*   ; alist of (symbol . value) — local lexical bindings made by let/flet/etc.
```

Initialized to NIL on connection open by `initialize-eval-in-api-env` (currently a no-op stub returning NIL). Mutated by every `let`/`let*` form encountered during evaluation: a `let` handler walks its bindings, evaluates each value, then dynamically rebinds `*eval-in-api-env*` to a longer alist for the body. On exit the alist is unbound, so the bindings have correct scope.

This is **not** the host CL lexical environment — it's a separate alist maintained by the walker. That's why API forms can't capture closures or use full CL semantics: the walker isn't a CL implementation, it's a SubL subset.

### Globals registry

Two lists track which special variables an API form is allowed to reference or mutate:

```
*eval-in-api-mutable-globals*    ; symbols allowed in (setf *foo* ...) from API
*eval-in-api-immutable-globals*  ; symbols allowed to read but not set
```

A `setq`/`setf` of a special variable is rejected unless the symbol is on `*eval-in-api-mutable-globals*`. A read of a special variable is permitted if it's on either list. The two-tier split lets Cyc expose read-only globals (e.g. `*null-output*`) without letting an API caller redirect them.

The list of mutable globals is the API's view of "session settings" — `*paraphrase-precision*`, `*ke-purpose*`, `*the-cyclist*`, `*api-output-protocol*`, `*progress-note*`, etc. (see `eval-in-api-registrations.lisp:139-167`). An API caller can `(setf *ke-purpose* SomeKEPurpose)` and it sticks for the rest of the connection.

### Special-form handlers

```
*api-special-table*           ; operator → handler function
*api-special-verify-table*    ; operator → verifier function
```

Special forms are operators that need their args unevaluated (or evaluated specially). The standard set: `quote`, `function`, `if`, `cond`, `case`, `let`, `let*`, `flet`, `labels`, `progn`, `prog1`, `setq`, `setf`, `unwind-protect`, `block`, `return`, `return-from`, `tagbody`, `go`, `catch`, `throw`, `multiple-value-bind`, `multiple-value-call`, `multiple-value-list`, `multiple-value-prog1`, `the`, `declare`. Each one has a corresponding eval handler (registered via `register-api-special`) and a verifier handler (via `register-api-special-verify`).

### User-defined function table

```
*api-function-table*    ; symbol → user-defined function body
*api-macro-table*       ; symbol → user-defined macro body
```

Lets API clients **define new functions at runtime** that subsequent API calls can use. `define-api-function name arglist body` (LarKC-stripped) installs into `*api-function-table*`; the eval walker dispatches to the table after the predefined-function check. This is how a long client session can build up a working set of helper functions. Persists for the lifetime of the connection (or longer — see `*api-user-variables*` below).

### User variables

```
*api-user-variables*    ; dictionary, persisted across connections
```

Per-cyclist scratch storage. `(put-api-user-variable name value)` stores under the current cyclist's key; `(get-api-user-variable name)` retrieves. `(clear-api-user-variables)` wipes them all. Three of the few API entry points that survived to the LarKC port — they're registered in `eval-in-api.lisp` itself.

This is the only piece of API state that **outlives a connection**. Useful for client-side tools that want to remember query bookmarks or settings across reconnects.

### Trace state

```
*eval-in-api-traced-fns*     ; list of symbols to trace
*eval-in-api-trace-log*      ; accumulator string
*eval-in-api-level*          ; current call depth
*eval-in-api-function-level* ; depth at last function entry (for indenting trace output)
*eval-in-api-macro-stack*    ; macro-expansion frames currently in flight
```

Per-connection. When the interpreter enters a function whose name is on `*eval-in-api-traced-fns*`, it appends a "called X with args Y" line to `*eval-in-api-trace-log*` (with depth indentation). On exit it appends "X returned Z". The client can read the log via the API.

## When does eval-in-api run?

In Cyc the engine, **every** synchronous API request flows through it:

- A connection accepts a form via `read-api-request` ([cyc-api.md](cyc-api.md)).
- `perform-api-request` calls `cyc-api-eval`.
- `cyc-api-eval` checks `*eval-in-api?*` and routes to the walker.

In the LarKC port, the same dispatch fires but the T branch is `missing-larkc 10828`. So in practice eval-in-api is invoked **never** — the port runs the NIL branch and uses host `eval`. Recreating the walker is one of the larger pieces of work for a clean rewrite.

## When does eval-in-api state get created or mutated?

The interesting state is the per-connection environment. Lifecycle:

| Trigger | Effect |
|---|---|
| Connection opens (`api-server-loop` lets) | `*eval-in-api-env*` ← `(initialize-eval-in-api-env)` (NIL); `*eval-in-api-traced-fns*` ← NIL; `*eval-in-api-trace-log*` ← `""`; `*eval-in-api-level*` ← -1 |
| `let` / `let*` in an API form | Dynamically rebinds `*eval-in-api-env*` to a longer alist around the body |
| `setq` / `setf` on a special variable | Mutates the host CL global, gated by `*eval-in-api-mutable-globals*` membership |
| `define-api-function` from API form | Adds to `*api-function-table*` |
| `(trace foo)` / `(untrace foo)` (when registered) | Mutates `*eval-in-api-traced-fns*` |
| Function entry/exit during eval | Pushes/pops `*eval-in-api-level*`, `*eval-in-api-function-level*`, `*eval-in-api-macro-stack*` |
| Connection closes | All per-connection bindings unwind via the `let` form in `api-server-loop` |
| Image-wide `clear-api-user-variables` | Wipes `*api-user-variables*` (the cross-connection storage) |

The persistent state is **only** the four global tables (`*api-special-table*`, `*api-predefined-function-table*` and friends) — populated at startup by registration calls and never mutated at runtime — and `*api-user-variables*`. Everything else is connection-scoped.

## The registrations file: what's exposed

`eval-in-api-registrations.lisp` is a **manifest**, not a code file. It runs at image startup (toplevel forms only) and populates the registration tables. The shape:

```
(register-api-immutable-global '*null-output*)
(register-api-mutable-global '*it-verbose*)
... (~30 mutable / 1 immutable)

(register-api-predefined-macro 'bq-list)
... (~30 predefined macros + 3 host macros)

(dolist (symbol *sublisp-api-predefined-functions*) (register-api-predefined-function symbol))
... (~250 SubL primitive functions)

(dolist (symbol *api-host-access-functions*) (register-api-predefined-host-function symbol))
... (~120 host-access functions, gated by *permit-api-host-access*)

(register-api-predefined-function 'isa)
... (~400 individual Cyc-API functions)
```

The two big alphabetised lists (`*sublisp-api-predefined-functions*`, `*api-host-access-functions*`) are the **complete SubL primitive surface** that API forms can use without further registration. They're effectively SubL's standard library: arithmetic, list ops, string ops, hash-table ops, package ops, stream ops, time ops.

The host-access list is locked behind `*permit-api-host-access*` — operators like `read`, `write`, `open`, `kill-process`, `make-process`, `directory`, `interrupt-process` are not callable by ordinary clients. A privileged session sets the flag and gets a much larger surface.

The individual `register-api-predefined-function` calls expose **named-Cyc functions** — things like `isa`, `genls`, `disjoint-with?`, `removal-ask`, `kb-statistics`. Each is one line. The grouping is informal — calls are clustered by source-file-of-origin, with `;; Batch N` comments marking original Internal-Constant list literals from the Java that were exploded into named registrations during porting.

### The `api-bq-list` reconstruction

One macro got reconstructed from its Internal Constants:

```
(defmacro api-bq-list (&rest args) `(list ,@args))
```

`api-bq-list` is the API-flavoured backquote-list constructor — the API's analogue of `bq-list`. The Java had it as a six-line macro; its Internal Constants made the body unambiguous (`$sym35$LIST` was the only orphan, used to construct the expansion).

## Lookup priority

When the walker resolves an operator, it consults the tables in this order:

```
1. *api-special-table*               (special forms)
2. *api-predefined-macro-table*      (macros — expand and recurse)
3. *api-predefined-function-table*   (functions — eval args, funcall)
4. *api-predefined-host-function-table*  (host functions — gated by *permit-api-host-access*)
5. *api-function-table*              (user-defined via define-api-function)
6. *api-macro-table*                 (user-defined macros)
```

Note the ordering nuance: `register-api-special` warns if the operator is already a predefined function/macro and refuses to add it. `register-api-predefined-function` and `register-api-predefined-macro` skip the registration if the operator is already a special form. The intent is **mutual exclusion** at the table level — an operator should only live in one table.

## When is the verifier used?

The verifier (`verify-in-api`) is a separate walker that returns success/failure without side effects. Its purpose is:

- **Pre-flight validation** for clients that want to gate a UI action on whether a form would be accepted.
- **Reporting unbound symbols** with usable diagnostics rather than runtime errors.
- **Macro expansion check** — the verifier expands macros and verifies the expansion, catching macros that produce invalid forms.

`register-api-special-verify` registers a per-special-form verifier (handles control-flow special forms specially because their args have non-uniform evaluation). The standard set has the same ~25 operators as the eval side, just with verification semantics instead of evaluation semantics.

## Mutable global registrations: what they say about the API

The mutable-global list (`eval-in-api-registrations.lisp:139-167` and `:410-419`) is essentially **a list of session knobs**. Reading the list tells you what the API was designed to expose to a client:

- Output formatting: `*paraphrase-precision*`, `*pph-domain-mt*`, `*pph-language-mt*`, `*pph-link-arg0?*`, etc. (paraphrase = NL generation)
- Identity / authoring: `*the-cyclist*`, `*ke-purpose*`
- Inference control: `*relevant-mt-function*`, `*suppress-sbhl-recaching?*`, `*suspend-sbhl-type-checking?*`
- Progress reporting: `*progress-note*`, `*progress-sofar*`, `*progress-total*`, `*silent-progress?*`
- Error handling: `*ignore-warns?*`, `*ignore-breaks?*`, `*continue-cerror?*`
- I/O: `*standard-output*`, `*error-output*`, `*api-output-protocol*`, `*api-input-protocol*`, `*api-result-method*`
- KB browser history: `*cb-assertion-history*`, `*cb-constant-history*`, `*cb-nat-history*`, `*cb-sentence-history*`
- KE bookkeeping: `*cyc-bookkeeping-info*`, `*the-cyclist*`, `*use-local-queue?*`, `*ke-purpose*`
- Eval-in-api itself: `*eval-in-api-env*`, `*eval-in-api-trace-log*`, `*eval-in-api-traced-fns*`, `*eval-in-api-level*`

A clean rewrite that wants typed session config can read this list as the union of "things a session ought to be able to set." Most are flags (boolean), a few are MT references (constant), a few are functions.

## How other systems consume this

- [cyc-api.md](cyc-api.md) — `cyc-api-eval` is the entry point. The api-kernel doesn't know anything about the interpreter beyond "it's behind `*eval-in-api?*`."
- `(register-cyc-api-function ...)` calls in every source file — these populate `*api-predefined-function-table*` (via `register-api-predefined-function` inside the macro). The source file owns the function; eval-in-api owns the gate.
- `eval-in-api-registrations.lisp` is the only file that references `register-api-mutable-global` and `register-api-immutable-global`. Other files don't expose globals individually.
- `register-external-symbol` (defined in `access-macros.lisp`, ~12 call sites) is a separate but related registry — it marks a *macro symbol* (e.g. `define-after-adding`) as mentionable in API forms. The interpreter uses this to know that the symbol is a defined macro elsewhere even if its expansion isn't an exposed function.
- `task-processor.lisp` — when a queued request fires on a worker thread, it calls `cyc-api-eval` to actually run the form, so the walker (when it exists) is shared between sync and async paths.

## Notes for a clean rewrite

- **Reimplement the interpreter; don't ship `*eval-in-api?* = NIL`.** The `eval` fallback is arbitrary-code-execution-as-a-service. Either build the SubL-subset interpreter (the registration manifest gives you the operator list verbatim) or pick a different sandbox technology (WASM, V8 isolate, Lua sandbox).
- **The registration manifest is the spec.** Every symbol in `eval-in-api-registrations.lisp` is a function or macro the engine considered safe to expose. Use it as a checklist — re-implement each in the clean codebase and re-register it. There are about 850 entry points (registration calls); don't drop them silently.
- **Drop the special / predefined / host-fn / host-macro split.** Five tables is two too many. One registry of operators, each with: `(name, arity-spec, kind, permission-tag, handler)`. `kind` ∈ {`special`, `function`, `macro`}. `permission-tag` ∈ {`public`, `host-access`, `internal`}. Lookup is one hashtable + tag check.
- **Make the env a real lexical environment.** The alist-based `*eval-in-api-env*` is fine for SubL but a clean rewrite should use the host language's lexical scoping if possible. If you're embedding a custom interpreter, structure-share with the host CL environment via `coerce`-to-function for performance.
- **Mutable vs. immutable globals → typed session config.** The two-list split is just "read-only" vs. "read-write". A clean rewrite should expose session config as a typed struct with explicit fields and explicit setters; per-field permissions are then enforced by the setter, not by membership in a list.
- **`*api-user-variables*` is a per-cyclist key/value store with no schema and no expiration.** Replace with a proper key/value store backed by the KB or by an external cache (Redis/etc.). Schema-on-read is fine; schema-on-write is better.
- **Trace logging via two parameters and a string accumulator is too primitive.** Hook into structured logging — emit JSON events with `request-id`, `function`, `args`, `result`, `duration-ms`. Clients read events by streaming a side channel; don't return the trace in the response.
- **The verifier is a real feature; preserve it.** Pre-flight validation of user forms is genuinely useful for IDEs. Make it a first-class capability in the rewrite, not an afterthought.
- **`api-bq-list` is just `list`.** Drop the alias. It existed because SubL had `bq-list` and `bq-cons` as macros that the API needed an analogue for; in a clean rewrite, the wire format isn't s-expressions and macros don't apply.
- **The `*subl-eval-method*` indirection is dead.** It was meant to let the interpreter swap in different eval flavors; it never had a second value. Drop the indirection and call eval directly (or, in the rewrite, call your interpreter directly).
- **Document the priority order.** The five-table lookup-priority sequence is implicit in the code. Make it part of the spec — clients writing rewrites need to know whether `(quote foo)` resolves to the special form or a user-defined function named `quote`.
- **Don't expose `quit` / `exit` / `halt-cyc-image` through the predefined-function table.** They're in the predefined functions list (`*sublisp-api-predefined-functions*`) and that's a foot-gun. A clean rewrite should keep them only in the host-access table, gated by `*permit-api-host-access*`.
