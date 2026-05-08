# Modules registration & SubL primitives

This doc covers the **SubL-language plumbing** that supports the rest of the codebase: module/system bookkeeping, SubL identifier mappings, and a small set of SubL macros and promotions that bridge SubL idioms to host CL.

These files are infrastructure — most of Cyc never uses them directly. The clean rewrite either drops them entirely (because the host language already has the equivalent) or simplifies them dramatically.

Files covered:

- `modules.lisp` (122 lines) — the **build-time module registry**. `module` and `system` defstructs that track which `.lisp` files belong to which Cyc system. Used historically by the SubL build tools to translate sources to Java/C; in the LarKC port, mostly dormant.
- `subl-identifier.lisp` (113 lines) — the **subLIdentifier KB-fact mapping**. Maps `(domain, id)` pairs declared in the KB (`#$subLIdentifier`, `#$uniquelyIdentifiedInType`) to FORTs. Lets SubL code refer to KB entities by symbolic id rather than constant name.
- `subl-macros.lisp` (56 lines) — three tiny utilities. Mostly empty post-LarKC.
- `subl-macro-promotions.lisp` (169 lines) — **macros that bridge SubL constructs to host CL**: `catch-error-message`, `with-timeout`, `with-tcp-connection`, `code-comment`. Reconstructed from Internal Constants.
- `subl-promotions.lisp` (87 lines) — **functions that bridge SubL primitives to host CL**: `function-symbol-p`, `function-symbol-arglist`, `member?`, `rsublis`, `positive-integer-p`, etc. Hand-written CL implementations.

## The module/system registry

A **system** is a top-level grouping (e.g. `cycl`, `subl-translator`, `cycl-test`). A **module** is one `.lisp` file (or one logical compilation unit). Each module belongs to exactly one system.

```
(defstruct module
  basis name system pathname test-cases test-suites provisional-p)

(defstruct system
  basis name default-pathname modules provisional-p)
```

`*module-index*` is `(name . system) → module` (hashtable, equalp test).
`*system-index*` is a list of `system` structs.

The lifecycle:

| Trigger | Effect |
|---|---|
| `(create-system name)` → `system-new` | Mints a system struct, downcases the name, pushnews onto `*system-index*` (under `*system-lock*`). |
| `(create-module name system-name)` → `module-new` | Looks up the parent system; mints a module struct; calls `module-store` (under `*module-lock*`) which puts it into `*module-index*`; calls `system-add-module` which pushnews it onto `(system-modules system)`. |
| `(system-lookup name)` | Linear scan of `*system-index*` for a system with this name. |

The two locks (`*module-lock*`, `*system-lock*`) serialise table mutations. The reverse direction (`module-get-name`, `module-get-system`) is just struct-accessor dispatch.

`provisional-p` is the "this module came in via the C-translated path, not the original file load" flag — lets the system track which modules are "real" vs. dynamically-added during cross-compile. In the LarKC Lisp port, every module is provisional (we never went through the SubL→C translator). Comment in `system-add-module`: "This is only called when MODULE is a provisional module, or we are running translated C code!"

### Why this exists

Cyc was originally a SubL codebase that got translated to Java for distribution. The module/system registry tracked what got translated, what was being translated next, and which test suites belonged where. The translator (`file-translation.lisp`, `secure-translation.lisp`, `system-translation.lisp` — mostly missing-larkc) consumed this registry to decide which files to emit Java for.

In the LarKC port we don't run the translator, so the registry is mostly dormant. A few startup paths still call `create-system` / `create-module` for catalog purposes (e.g. `cyc-revision-extraction.lisp` populates a system entry per release), but most live KB code never touches it.

A clean rewrite drops module/system entirely — the host build system (asdf, Cargo, npm, ...) already manages compilation units.

## SubL identifier mappings

`subl-identifier.lisp` is **a KB-fact-driven mapping** from `(domain, id)` pairs to FORTs. The intent: KB code has a fact like

```
(#$subLIdentifier (#$SubLSymbolEntityFn #$CycHLTruthValue :TRUE-DEF) :TRUE-DEF)
```

which says "the constant `(SubLSymbolEntityFn CycHLTruthValue :TRUE-DEF)` is uniquely identified within domain `#$CycHLTruthValue` by the SubL symbol `:TRUE-DEF`". The lookup tables let runtime code do `(sublid-id-to-forts-lookup :TRUE-DEF)` to find the FORT for a given symbol id, and `(sublid-fort-to-id-lookup fort)` for the inverse.

### The three tables

```
*sublid-domain-to-forts-table*   ; domain → list of forts in that domain
*sublid-id-to-forts-table*       ; id     → list of forts with that id (across domains)
*sublid-fort-to-id-table*        ; fort   → id (the unique id for this fort)
```

Plus two predicates that drive population:

```
*sublid-pred*       = #$subLIdentifier
*sublid-uiit-pred*  = #$uniquelyIdentifiedInType
```

### When does a sublid mapping come into being?

| Trigger | Effect |
|---|---|
| Image startup `initialize-sublid-mappings` | Clears the three tables; if `*sublid-mt*` and `*sublid-pred*` are bound, iterates `do-predicate-extent-index` for both predicates and populates the tables from each matching assertion. The actual population is `missing-larkc 11210` and `missing-larkc 11212` — Cyc's real impl extracts `(domain id fort)` from the assertion's GAF args and writes all three table entries. |
| KB fact `(#$subLIdentifier ...)` is asserted | After-adding hook calls `add-sublidentifier` (LarKC-stripped), which calls `sublid-mappings-add` (LarKC-stripped), which writes new entries to all three tables. Registered as a `kb-function` so the KB layer knows to dispatch to it. |
| KB fact `(#$subLIdentifier ...)` is unasserted | After-removing hook calls `remove-sublidentifier`, then `sublid-mappings-remove`, removing the entries. |
| Same for `#$uniquelyIdentifiedInType` via `add-uniquelyidentifiedintype` / `remove-uniquelyidentifiedintype`. |

The four `register-kb-function` calls at the bottom announce these four functions to the KB layer's after-X hook dispatch (see [../kb-access/forward-propagation.md](../kb-access/forward-propagation.md)).

In the LarKC port, since the implementations are stripped, the runtime tables stay empty. The hooks register but the work is no-ops.

## Where sublid mappings get used

Code that needs to refer to a KB entity by a symbolic id (rather than by constant name) reads from `*sublid-id-to-forts-table*` or `*sublid-fort-to-id-table*`. The use case is bidirectional bridge between SubL data values and CycL terms:

- A SubL form like `:TRUE-DEF` is a keyword. The corresponding KB entity is `(SubLSymbolEntityFn #$CycHLTruthValue :TRUE-DEF)`. The mapping handles the round-trip without name lookups.
- KB-defined SubL functions: `(#$subLIdentifier <Fn-NART> some-symbol)` says "this NART implements the SubL function named `some-symbol`". Inference modules that dispatch on SubL symbols use the mapping to find the implementing NART.

In the LarKC port the consumers are stripped along with the populators — the mapping is end-to-end nonfunctional but the schema survives.

## SubL macro promotions

`subl-macro-promotions.lisp` reconstructs four macros that bridge SubL constructs to host CL. Each was a `defmacro` in SubL with a particular runtime mechanism that doesn't exist in CL; the port replaces the body with a CL-native implementation that has the same observable behaviour.

### `catch-error-message`

```
(defmacro catch-error-message ((var) &body body)
  `(setf ,var (handler-case (progn ,@body nil)
                (error (c) (princ-to-string c)))))
```

SubL's original used `ccatch` + `with-error-handler` to install an error handler around `body`; on error, the handler threw to a tag and the catch returned the error message. The CL version uses `handler-case`, which is the same shape. Result: `,var` is bound to NIL on success, or to the error message string on failure.

This is the **standard error-capture idiom** in the codebase — used in `api-server-one-complete-request` ([cyc-api.md](cyc-api.md)) for each step of the request pipeline, in `task-processor-handler` ([task-processor.md](task-processor.md)) for the eval phase, and in many other places where "do this, set err if it failed" is needed.

The associated parameter `*error-message*` holds the most-recent error message (set by `catch-error-message-handler` when triggered). `*catch-error-message-target*` is the throw target (a unique uninterned symbol). Both are mostly vestigial in the CL port since `handler-case` doesn't need an external target.

### `with-timeout`

```
(defmacro with-timeout ((time timed-out-var) &body body)
  ...catch + unwind-protect + start/stop timer thread...)
```

Reconstructed but **non-functional** — the helper functions (`with-timeout-make-tag`, `with-timeout-start-timer`, `with-timeout-stop-timer`) are missing-larkc. The macro structurally compiles but the timeout never fires.

The SubL implementation spawned a watchdog thread that, after `time` seconds, threw to a tag, unwinding the body. The macro uses an unique tag per invocation (so nested `with-timeout` calls don't interfere) and tracks nesting depth via `*with-timeout-nesting-depth*`.

In a clean rewrite, use the host language's timeout primitive (CL has `bt:with-timeout` from `bordeaux-threads`, Python has `asyncio.wait_for`, etc.). The SubL-specific "tag-thread" mechanism doesn't translate.

### `with-tcp-connection`

```
(defmacro with-tcp-connection ((bi-stream host port &key timeout (access-mode :public))
                               &body body)
  `(let ((,bi-stream (open-tcp-stream-with-timeout ,host ,port ,timeout ,access-mode)))
     (unwind-protect
         (progn ,@body)
       (when ,bi-stream
         (close ,bi-stream)))))
```

A standard "open + body + close-on-exit" macro. Used by [tcp-transport.md](tcp-transport.md) consumers for outbound TCP. The `:access-mode` slot is a feature-of-the-original that's not currently meaningful (`:public` vs. `:private` had different file-system permissions implications historically).

`open-tcp-stream-with-timeout` itself is LarKC-stripped — the timeout part doesn't work, but `open-tcp-stream` (in `tcp.lisp`) does, so the macro currently runs without enforcing the timeout argument.

### `code-comment`

```
(defmacro code-comment (comment-string)
  (declare (ignore comment-string))
  '(progn))
```

Compile-time annotation that produces no runtime code. The original SubL macro existed so source-level comments could be programmatically extracted by tooling (e.g. building doc indices). The LarKC port treats it as a no-op.

### Macros not reconstructed

The file lists three macros that **could not be reconstructed** without expansion sites to verify against:

- `with-tcp-connection-with-timeout` — wraps `with-tcp-connection` inside `with-timeout`. Arglist unknown.
- `with-space-profiling` — runs body with a memory-usage profiler attached. Body uses SubL's `add-space-probe` / `remove-space-probe` / `interpret-cspace-results` — none of which have host-CL equivalents.
- `cmultiple-value-setq` — was equivalent to `multiple-value-setq` directly. The CL version commented out with the rationale "DO NOT USE THIS, USE MULTIPLE-VALUE-SETQ DIRECTLY INSTEAD!" — i.e. a clean rewrite drops the SubL alias entirely.

## SubL function promotions

`subl-promotions.lisp` is small — six functions that fill SubL primitives the host CL doesn't provide identically:

| Function | Purpose |
|---|---|
| `function-symbol-p obj` | T iff obj is a symbol with an fboundp definition that is a function. Stricter than `(and (symbolp obj) (fboundp obj))` because it rejects macros. |
| `function-symbol-arglist symbol` | Return the arglist of a function symbol. SBCL-only via `sb-impl::%fun-lambda-list` — errors on other implementations. |
| `reverse-alist-pairs alist` | `((K . V) ...)` → `((V . K) ...)`. Used by `rsublis` / `nrsublis`. |
| `rsublis alist tree` | Like `sublis` but the alist is interpreted as `(VALUE . KEY)` rather than `(KEY . VALUE)`. SubL needed both directions; CL provides only `sublis`. |
| `elapsed-universal-time past &optional now` | `now - past`. |
| `ensure-physical-pathname pathname` | `(truename pathname)`. |
| `member? item list &optional test key` | `member` with test/key keyword args. |
| `positive-integer-p obj`, `non-negative-integer-p obj` | `typep` shortcuts. |

These are minor convenience wrappers. A clean rewrite drops most of them — the host's standard library covers them. `function-symbol-arglist` is the one with implementation-specific code; in modern CL it would use `closer-mop` or just not be needed.

## `subl-macros.lisp` minus structural macros

`subl-macros.lisp` itself is small after LarKC stripping. What survived:

| Surviving | Purpose |
|---|---|
| `do-sequence-index-done? index end-index sequence` | "Has a sequence iterator finished?" — list-vs-other dispatch. Used by macro-expansions that iterate uniformly over lists and vectors. |
| `*ignore-assert-types?*` (T by default) | When NIL, `assert-type` and `assert-must` SubL forms expand into runtime `check-type` / `must`. When T (default), they're elided for performance. |
| `rplacd-last list new-cdr` | Mutate the last cons of a non-empty list to point at `new-cdr`. |

The bulk of "SubL-style macros" (`cdolist`, `cdotimes`, `csome`, `cdo`, ...) live in `utilities-macros.lisp` and were reconstructed there from Internal Constants. This file got the leftovers.

## How other systems consume this

- **`catch-error-message`** is the most-used surviving piece — every place in the codebase that wants "run this, capture errors as a string, continue" uses it. Several hundred call sites.
- **`with-tcp-connection`** is consumed by ([tcp-transport.md](tcp-transport.md)) outbound clients. ~5 call sites.
- **`with-timeout`** is consumed where bounded-time operations are needed: `inference-trivial.lisp` for trivial-inference timeouts, the transcript-server connection routine. ~20 call sites. **Currently broken** because helpers are stripped.
- **`module-new` / `system-new`** are called by `cyc-revision-extraction.lisp` and a few startup files to populate the registry. Not consumed at runtime.
- **`*sublid-*-table*`** consumers were stripped along with the populators. The schema survives but no live code reads or writes them.
- **`subl-promotions` functions** are used everywhere — `member?` and `non-negative-integer-p` especially are common. Maybe a few hundred call sites total.

## Notes for a clean rewrite

- **Drop module/system bookkeeping entirely.** The host language's build system manages compilation units. The Cyc-side registry was needed only for the SubL→Java/C cross-compiler, which isn't part of a clean rewrite.
- **The sublid mapping schema is real KB design.** It's how SubL-side code references KB entities by symbolic id. The implementation (three globals + populator hooks) is fine for a clean rewrite; just port the populator (read `#$subLIdentifier` assertions, build the tables) and the lookup functions.
- **`catch-error-message` becomes `try/except`.** The macro is fine but the `*error-message*` / `*catch-error-message-target*` parameters are dead in the CL port — they're vestiges of the SubL implementation. Drop them.
- **Use the host's timeout primitive for `with-timeout`.** CL has `bt:with-timeout`. The hand-rolled tag-thread mechanism is dead weight.
- **`with-tcp-connection` can stay in shape.** Resource-acquisition macros are the right pattern. Drop `:access-mode`; pass a `Connection` builder closure that knows how to authenticate.
- **`code-comment` is dead.** No tooling in the LarKC port uses it. Drop.
- **`subl-promotions.lisp` is implementation-shimming.** Most of its functions are one-liners over CL standard. Inline at the call sites and drop the file. The exception is `function-symbol-arglist` if you need it — but most callers don't.
- **`*ignore-assert-types?*` is a build-time switch leaking into runtime.** A clean rewrite should compile out type checks at the build level, not via a global flag. Either always check (debug build) or always elide (release build).
- **The "promotions" naming is from SubL.** "Promotion" meant "elevate this primitive to be a SubL macro/function". Rename to something normal in a clean rewrite — `compat.lisp` or `polyfill.lisp` or just inline.
- **`rsublis` / `nrsublis` are convenience but rarely needed.** Most callers can reverse the alist once at the call site rather than carrying around a "reverse" version of `sublis`.
- **The SubL-shaped `member?` predicate is actually inferior to CL's `find`.** `(member? x list)` returns the tail-cons; `(find x list)` returns the element. Most callers want `find`. A clean rewrite should audit the call sites and prefer `find` where appropriate.
