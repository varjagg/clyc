# Access macros and definitional metadata

This doc covers four files that together form the **definitional layer** of SubL — the macros, helpers, and registries used to *declare* functions, macros, and variables at top level. Every other file in the codebase builds on this layer: `define-public foo (...)` and `defparameter-protected *bar* ...` are how almost every Cyc symbol comes into the world.

| File | Role |
|---|---|
| `access-macros.lisp` | Visibility-annotated wrappers for `defun`, `defmacro`, `defconstant`, `deflexical`, `defparameter`, `defglobal`, `defvar`. |
| `meta-macros.lisp` | The smallest building blocks: `with-temp-vars`, `make-temp-var`, `declare-indention-pattern`. |
| `subl-macros.lisp` | One residual SubL helper, `do-sequence-index-done?`, plus `*ignore-assert-types?*` and `rplacd-last`. Mostly LarKC-stripped. |
| `utilities-macros.lisp` | The Cyc-API registration tables, the macro-helper registry, the KB-variable registry, the progress-printing helpers, the `*unprovided*` sentinel — large grab-bag of cross-cutting infrastructure built on the access macros. |

The four are grouped because in a clean rewrite they will collapse into one **definitional infrastructure** module — visibility, registration, and the supporting metadata go together. None of them carries KB *content*; they all carry the machinery that the rest of the system uses to declare itself.

## What problem the access macros solve

In the original SubL, every top-level definition carried an *access level* — `public`, `protected`, `private`, plus an orthogonal `external` flag — that the SubL compiler enforced at module boundaries. The compiled Java rendered each access level as a different definitional macro: `define-public`, `define-protected`, `define-private`, etc., for functions, and parallel families for `defmacro`, `defconstant`, `deflexical`, `defparameter`, `defglobal`, `defvar`. The result is twenty-some lookalike macros, all of which expand to the same underlying form (`defun`, `defmacro`, etc.) wrapped in a `proclaim` of the access level.

In the Lisp port, the `proclaim` is a no-op — Common Lisp ignores unknown declaration specifiers — so the access macros are presently **visibility annotations stripped of their enforcement**. Every `define-public` is just a `defun` with a paint-can label. The Cycorp source still relied on the labels for documentation and for generating module headers; preserving them in the port preserves the visibility intent that future tooling can re-enforce.

Each of `define-X` and `defmacro-X` and `def<storageclass>-X` exists in three flavors (`-public`, `-protected`, `-private`) plus an `-external` flavor that additionally calls `register-external-symbol`. The external flag means "this symbol is part of Cyc's public API surface," which is a stronger statement than `-public` (which is only "exported from this module"). External symbols are accumulated into `*external-symbols*`, a hash table.

There are also two helper-flavored variants:

- `define-macro-helper NAME ARGLIST (:macro M) BODY` — defines a function and registers it as the implementation helper for macro `M`. The macro-helper registry (`*macro-helpers*` in `subl-support.lisp`) is what lets a macro split its expansion logic out into named functions while still tracking the dependency.
- `defmacro-macro-helper`, `defparameter-macro-helper` — same idea for macros and parameters.

The `define-obsolete` macro flags a function as deprecated and registers a replacement list via `define-obsolete-register`. Used sparingly. (`defmacro-obsolete` was in original Cyc but stripped by LarKC.)

## When does a registration happen?

Every registration table in this group is populated **at file-load time**, in either the init phase (variable initializations) or the setup phase (`(toplevel ...)` forms in the port; `runTopLevelForms()` in Java).

| Table | Populated when | By |
|---|---|---|
| `*external-symbols*` | A `define-external`, `defmacro-external`, `def<storage>-external` form runs at load time. Also via direct `(toplevel (register-external-symbol 'X))` for symbols whose definitions are absent (e.g. stripped macros that other code expects to know about). | `register-external-symbol` |
| `*macro-helpers*` (in `subl-support.lisp`) | A `define-macro-helper`, `defmacro-macro-helper`, `defparameter-macro-helper` form runs. Also via the `macro-helpers` block (an alternative grouping form used heavily in `utilities-macros.lisp`). | `register-macro-helper` |
| `*api-special-table*` | A module's `(register-api-special op handler)` runs in setup. Marks a SubL operator as needing a special-cased translation when invoked through `eval-in-api`. | `register-api-special` |
| `*api-predefined-function-table*` / `*api-predefined-host-function-table*` | A `register-cyc-api-function NAME ARGS DOC ARG-TYPES RETURN-TYPES` runs in setup, indirectly via the (stripped) `define-api`/`define-api-provisional` macros. The host variants are for SubL primitives the API can call directly when `*permit-api-host-access*` is true. | `register-api-predefined-function` / `register-api-predefined-host-function` |
| `*api-predefined-macro-table*` / `*api-predefined-host-macro-table*` | Same, for macros. | `register-api-predefined-macro` / `register-api-predefined-host-macro` |
| `*api-symbols*` | Whenever any of the above runs. The list is the union of every symbol marked as a Cyc API entity. | `register-cyc-api-symbol` |
| `*api-types*` | When `validate-return-type` is called from `register-cyc-api-return-types`. | `validate-return-type` |
| `*kb-function-table*` | A `define-kb` form (stripped) runs, calling `register-kb-function`. Marks a function as one the KB references symbolically (the KB stores function-symbol values, so the KB needs to know which symbols are "intended to be called"). | `register-kb-function` via `register-kb-symbol` |
| Symbol plist `:cyc-api-symbol`, `:cyc-api-args`, `:cyc-api-arg-types`, `:cyc-api-return-types`, `:obsolete-cyc-api-replacements` | Same trigger as `*api-symbols*` — `register-cyc-api-function` and `register-cyc-api-macro` write all the metadata onto the symbol's plist. | The respective `register-cyc-api-*` functions |
| `*kb-var-initializations*` | A `def-kb-variable` form (stripped) runs, calling `register-kb-variable-initialization` with `(VAR-SYMBOL . INIT-FN)`. | `register-kb-variable-initialization` via `def-kb-variable` macro-helper |
| `*global-locks*` | A `defglobal-lock` form (stripped) runs, calling `register-global-lock` with `(GLOBAL-SYMBOL . LOCK-NAME)`. | `register-global-lock` |
| `*fi-state-variables*` / `*gt-state-variables*` / `*at-state-variables*` / `*defn-state-variables*` / `*kbp-state-variables*` | A `def-state-variable` form (stripped) runs in the corresponding subsystem, calling `note-state-variable-documentation`. The subsystem-specific `defvar-X` macros (also stripped) push onto the per-subsystem list. | `note-state-variable-documentation` and per-subsystem `defvar-*` macros |
| `*funcall-helper-property*` (the property `:funcall-helper`) | A `define-private-funcall` form (stripped) runs, calling `note-funcall-helper-function`, which puts `:funcall-helper t` on the symbol's plist. | `note-funcall-helper-function` |

All of these tables are **load-time accumulators**. Nothing here is mutated after startup (with the trivial exception of `register-external-symbol` being callable from REPL).

## The macro-helper pattern

A "macro helper" is a function that one or more macros expand-into a call to. The `define-macro-helper` family pairs each helper with the macro(s) it serves so that:

1. Tooling can find all helpers for a given macro (used by docs, debugger, refactoring).
2. The helper itself isn't accidentally called by user code (it's `protected` by convention).
3. If the macro changes, the helpers it relies on are easy to enumerate.

Two sibling forms exist:

- `define-macro-helper NAME ARGLIST (:macro M) BODY` — explicit per-helper registration.
- `(macro-helpers MACRO-NAME (defun A ...) (defun B ...) ...)` — a block form that registers every contained `defun` as a helper for `MACRO-NAME`. Heavily used in `utilities-macros.lisp` to bundle the helper functions for `noting-progress`, `noting-percent-progress`, `with-process-resource-tracking-in-seconds`, etc.

The block form is the primary idiom in the port. It maps cleanly to "this macro and all the named functions it expands into live in one place."

## The Cyc API registration spine

`utilities-macros.lisp` houses the Cyc-API metadata layer. The intent of the API system is documented under [kb-access/fi.md](../kb-access/fi.md) and the to-be-written runtime/api docs; what lives *here* is the bookkeeping side — every registered API function has:

- A symbol plist entry `:cyc-api-symbol t` saying "this is a Cyc-API entity."
- A plist entry `:cyc-api-args` carrying the original SubL arglist (because Common Lisp doesn't preserve arglists for macros — and the API needs arglists for both functions and macros uniformly, so it stores them explicitly).
- A plist entry `:cyc-api-arg-types` carrying a list of type expressions, one per argument.
- A plist entry `:cyc-api-return-types` carrying a list of return-type expressions, validated by `validate-return-type` (which permits atoms or two-element `(list T)` / `(nil-or T)` constructions).
- Optionally `:obsolete-cyc-api-replacements` if the function was registered via `register-obsolete-cyc-api-function`.

The four parallel tables (`*api-predefined-function-table*`, `*api-predefined-host-function-table*`, `*api-predefined-macro-table*`, `*api-predefined-host-macro-table*`) implement a 2×2 of {function, macro} × {Cyc-defined, host-primitive}. The host tables only "count" as predefined when `*permit-api-host-access*` is true — that flag exists so an external caller can be restricted to Cyc-defined operators (the safer surface) while internal callers can use SubL primitives directly.

`*api-special-table*` is for operators whose API translation is custom (registered with a handler function). The check `register-api-predefined-*` skips registration if the operator is already in `*api-special-table*` to avoid the special handler being shadowed.

## The `*unprovided*` sentinel

`*unprovided*` is a unique uninterned symbol used as the default value for optional arguments where `nil` is a meaningful explicit value. `(unprovided-argument-p arg)` checks for it. The convention: a function with `(&optional (x *unprovided*))` can distinguish "caller said nothing" from "caller said nil." Used pervasively across the codebase.

This is a SubL convention; modern CL would use `(&optional (x nil x-supplied-p))`. Preserve the *intent* (callers can detect omission) but switch to the supplied-p idiom in a clean rewrite.

## Progress reporting

`noting-progress` and `noting-percent-progress` are the two macros for wrapping a long-running computation with start/end messages or with periodic percent updates. The implementation lives in `utilities-macros.lisp` because the macro-helper functions (preamble, postamble, `note-percent-progress`, `compute-percent-progress`, `print-progress-percent`) need to be loaded early — many systems use these for KB load progress.

`progress-dolist` is the user-facing iteration form: walks a list, printing a percent indicator. The Java name was `PROGRESS-CDOLIST` (renamed to `PROGRESS-DOLIST` in the port for CL convention).

The progress system is a hard dependency of the KB loader, the dumper, and several test harnesses. Preserve it but a clean rewrite should use a structured progress channel (callback / event stream) rather than printing to `*standard-output*`.

## Global lock registry

`*global-locks*` is an alist of `(GLOBAL-SYMBOL . LOCK-NAME)` pairs. The `defglobal-lock` macro (stripped) was the SubL form that declared "this global variable holds a lock"; the registry exists so that `initialize-global-locks` (called once at startup) can sweep through and create a fresh lock object for each registered global. The actual lock construction is `make-lock NAME`.

This pattern lets locks be re-created on image start without the lock-declaration site needing to re-run; in the clean rewrite this is just `defvar *foo* (bordeaux-threads:make-lock "foo")`.

## What lives in `meta-macros.lisp`

Three short forms:

- `with-temp-vars VARS BODY` — binds each name in `VARS` to a fresh uninterned symbol via `make-temp-var`. The classic gensym pattern, named for SubL convention.
- `make-temp-var NAME` — `(make-symbol (string NAME))`. The string `"TEMP"` from Java setup phase appears unused; the Java compiler hoisted it but the function body does not consult it.
- `declare-indention-pattern OPERATOR PATTERN` — register an indentation hint for `OPERATOR`. The body is `nil`; the hint is read by external editor integrations (Emacs SLIME, etc.). Preserved as a documentation-only no-op.

`subl-macros.lisp` contains:
- `do-sequence-index-done?` — the loop-termination predicate used by `do-sequence` (in `subl-support.lisp`); a list is done when nil, a vector is done at the end index.
- `*ignore-assert-types?*` (deflexical, default `t`) — when non-nil, `ASSERT-TYPE` and `ASSERT-MUST` (both stripped) are no-ops; when nil they expand into `CHECK-TYPE`/`MUST`. The SubL build distinguished "checked release build" from "stripped release build" via this flag.
- `rplacd-last LIST NEW-CDR` — destructively sets the cdr of the last cell.

These three files are tiny because most of `meta-macros` and `subl-macros` was either inlined into the port's `subl-support.lisp` or stripped by LarKC. What remains is what couldn't be inlined.

## Cross-cutting consumers

Almost every file in `larkc-cycl/` calls something from this layer:

- Every `defun`, `defmacro`, `defparameter` etc. in the codebase originated as a `define-X`, `defmacro-X`, `def<storage>-X` access-macro. After porting, most of those expand to plain `defun`/`defmacro` because the access annotations are no-ops.
- Every Cyc-API entry point is registered via `register-cyc-api-function` or `register-cyc-api-macro` (typically via the now-stripped `define-api`/`defmacro-api` macros). The runtime API dispatch (in `api-control-vars.lisp` / `api-kernel.lisp`, eventually documented under `runtime/`) reads from these tables and the per-symbol plist entries.
- The macro-helper registry is consulted by tooling (debugger, source-cross-reference) and by the `register-macro-helper` mechanism itself when a macro is redefined.
- The KB-variable registry (`*kb-var-initializations*`) is consumed by `initialize-kb-variables` at KB load time — a one-shot sweep that calls each registered initialization function and `set`s the variable to the result. This is how KB-dependent globals are seeded from the loaded KB's content.

## Notes for a clean rewrite

- **Collapse the access-macro families into one parameterized macro plus a visibility argument.** Instead of 24 macros (`define-public`, `define-protected`, `define-private`, `define-external`, `defmacro-public`, …, `defvar-private`), have one `(define :public/:protected/:private/:external NAME …)` form that dispatches internally. The flat namespace is a compilation-output artifact, not an intentional design.
- **Re-introduce real visibility enforcement, or drop the labels entirely.** The `proclaim` declarations are dead weight without a checker. Either build a static analyzer that warns on cross-module access of `private` symbols, or stop pretending and just use the host language's package system.
- **Move the API registration into a declarative `defapi` form per entry point.** Instead of `define-api` macros (stripped) plus a chain of `register-cyc-api-*` calls, have one `(defapi NAME (ARGS) :doc "..." :arg-types (...) :return-types (...))` that does the registration as a side effect of `defun`-ing the function. The four predefined-function/macro/host tables collapse to one with a `:host?` flag.
- **Replace the `*unprovided*` sentinel with `&optional (x nil x-supplied-p)`.** No new symbols, no global, no `eq` check; the host language already provides the distinction.
- **Replace `*global-locks*` registration with direct `(defvar *foo* (make-lock "foo"))`.** The deferred-initialization pattern was needed because SubL had a separate "compile this code" / "initialize this image" split; modern CL doesn't.
- **The KB-variable registry is a real abstraction worth keeping** — it's not "lazy global init," it's "compute this from the loaded KB." Recast as a hook that fires on KB-load completion and writes into the variable. Keep the registry; rename it for clarity.
- **Drop the `*api-symbols*` accumulator list** — `*api-predefined-function-table*` plus the symbol-plist `:cyc-api-symbol` flag is enough. The list is a redundant index.
- **The progress macros want a real event channel.** A clean rewrite should expose `(with-progress (TITLE) ...)` and `(progress-step PERCENT)` as forms that publish to a configurable observer (default observer = print to stderr), not as forms that hardcode `format t`.
- **`declare-indention-pattern` belongs in editor metadata, not in the source.** A clean rewrite would emit a `.dir-locals.el` / IDE plugin file from a list of forms, not have each file call a no-op at load.
- **The whole "macro-helper" concept is structurally sound but verbosely realized.** Modern Lisp uses `flet`/`labels` inside a macro for one-off helpers and just `defun` for shared ones. The registry is useful only if a tool reads it; otherwise drop the formality.
- **`*ignore-assert-types?*` is a build-time flag pretending to be a runtime flag.** Make it a feature gate at compile time and let `assert-type` expand to nothing or `check-type` based on `*features*`.
