# Format-nil

`format-nil` is **SubL's compile-time-optimised `(format nil ...)`**. The macro splits its format-control string at compile time on the directives it knows (`~A`, `~S`, `~D`, `~%`, `~~`) and expands into a `cconcatenate` of small dispatch helpers (`format-nil-a`, `format-nil-s`, `format-nil-d`, `format-nil-percent`, `format-nil-tilde`). The whole point is that `(format nil "Foo: ~A bar ~D" x y)` becomes `(cconcatenate "Foo: " (format-nil-a x) " bar " (format-nil-d y))` — no run-time parsing of the control string, no consing inside `format`, just direct calls to type-specialised printers. This was a meaningful win in 1995 SubL where `format` was implemented in-Lisp; in modern CL it's a non-issue. The CL port collapses the macro to one line — `(format nil control-string args)` — because CL's `format` is already compiled. Eight helper functions that the macro originally expanded to remain, registered with `register-macro-helper` to keep call-graph tooling honest.

## Why a custom `format-nil` instead of `cl:format`

Three reasons:

1. **Compile-time directive rewriting.** Original SubL `format-nil` walked the control string at macro-expand time and emitted a `cconcatenate` of pre-resolved helper calls. CL's compiler-macros for `format` do similar work today; SubL's compiler did not.
2. **Guaranteed `nil` destination.** `(format-nil ...)` is `(format nil ...)` always — no chance of accidentally passing `t` or a stream. Saves one branch in the helpers.
3. **Subset of directives.** SubL's `format` supported only `~A`, `~S`, `~D`, `~%`, `~~`. Everything else (`~R`, `~F`, `~T`, etc.) was unsupported — partly because SubL didn't have those primitives, partly because the macro's split-on-directive logic only knew those five. CL's `format` handles vastly more.

In the CL port, the macro becomes a no-op wrapper: `(defmacro format-nil (fmt &rest args) `(format nil ,fmt ,@args))`. CL's `format` handles the same directives correctly (and many more), so the dialect divergence is **none**.

## API surface

| Symbol | Status in port | Purpose |
|---|---|---|
| `(format-nil format-control &rest args)` | Macro, real | Reconstructed from `$list0` / `$sym1$FORMAT` / `$sym24$CCONCATENATE` / split-on-`~` evidence. Expands to `(format nil ...)`. |
| `(format-nil-a object)` | Real defun | Stringify like `~A`. Returns a fresh string for symbols/strings (copies); calls `princ-integer-to-string` for integers; falls through to `princ-to-string` for everything else. |
| `(format-nil-a-no-copy object)` | Real defun | Same dispatch but without copying — returns the original `symbol-name` or `string`. Used inside macro expansions where the result is fed straight to `cconcatenate` (which copies anyway). |
| `(format-nil-s object)` | **Stub** | `~S` directive helper. |
| `(format-nil-s-no-copy object)` | **Stub** | |
| `(format-nil-d object)` | **Stub** | `~D` directive helper. |
| `(format-nil-d-no-copy object)` | **Stub** | |
| `(format-nil-percent)` | **Stub** | Returns `*format-nil-percent*` (a newline). |
| `(format-nil-tilde)` | **Stub** | Returns `*format-nil-tilde*` (`"~"`). |
| `(format-nil-internal control args)` | **Stub** | The runtime fallback when the control string isn't a compile-time literal. Walks the control string, dispatching directives to the helpers above. |
| `(format-nil-control-validator control)` | **Stub** | Compile-time check that the control string contains only the supported directives. |
| `(format-nil-simplify control)` | **Stub** | Compile-time normalisation of the control string. |
| `(format-nil-expand control args)` | **Stub** | The macro's expansion engine — walks the split control and emits the `cconcatenate` form. |
| `(format-nil-control-split control)` / `-internal` | **Stubs** | Splits a control string into a list of literal-or-directive pieces for `format-nil-expand` to consume. |
| `(princ-integer-to-string integer)` | Real defun | Custom integer-to-string that's faster than `princ-to-string` when `*print-base*` is 10 and the integer fits in a fixnum: builds the digits in a stack buffer, writes them in reverse. Falls back to `princ-to-string` for bignums or non-decimal bases. |
| `(integer-decimal-length integer)` | Real defun | Number of base-10 digits (sign excluded) — used by `princ-integer-to-string` to size the output buffer. |
| `(format-one-per-line list &optional stream)` | **Stub** | Print each item on its own line. |
| `(print-one-per-line list &optional stream)` | **Stub** | Same for `princ`. |
| `(print-one-aspect-per-line list aspect-fn &optional stream)` | **Stub** | Each item passed through `aspect-fn`, one per line. |
| `(force-format destination control &optional arg1 … arg8)` | **Stub** | `format` + `force-output`. The 8-arg cap suggests an optimised non-`&rest` path. |

### Constants

| Constant | Value | Purpose |
|---|---|---|
| `*format-nil-percent*` | `(format nil "~%")` (a newline string) | Result of the `~%` directive. |
| `*format-nil-tilde*` | `"~"` | Result of the `~~` directive. |

### Setup phase

```lisp
(register-macro-helper 'format-nil-a 'format-nil)
(register-macro-helper 'format-nil-a-no-copy 'format-nil)
(register-macro-helper 'format-nil-s 'format-nil)
(register-macro-helper 'format-nil-s-no-copy 'format-nil)
(register-macro-helper 'format-nil-d 'format-nil)
(register-macro-helper 'format-nil-d-no-copy 'format-nil)
(register-macro-helper 'format-nil-percent 'format-nil)
(register-macro-helper 'format-nil-tilde 'format-nil)
```

These are call-graph annotations: each helper exists only as part of expanded `format-nil` macro bodies. The Clyc port keeps the registrations even though the macro now expands directly to `cl:format` and never calls them — they document the original intent and let any future tooling recognize the helpers as macro-related.

## Where format-nil is consumed

The CL port has only **three real callers** of the helper functions outside the file itself:

| File | Use |
|---|---|
| `java-name-translation.lisp` | `(format-nil-a-no-copy name-basis)` to build `"sublisp_<name>"` and `"f_<name>"` Java method names without copying the symbol-name. |
| `clausifier.lisp` | `(format-nil-a (variable-name symbol))` and `(format-nil-a-no-copy (object-to-string n))` when generating skolem-variable names for clausified rules. |
| `system-benchmarks.lisp` | `(format-nil-a-no-copy i)` to build benchmark term/collection names like `"Col-7"` and `"Term-3-12"`. |

The macro itself (`(format-nil "..." args)`) is not used in the LarKC-stripped Lisp — every place that wants a formatted string calls `(format nil ...)` directly. The macro exists for backward compatibility with any future-ported code that uses the SubL spelling.

## Why `*print-base*` matters in `princ-integer-to-string`

The fast path bails to `princ-to-string` when `*print-base*` is not 10. Cyc occasionally rebinds `*print-base*` (e.g. when emitting hex in CFASL diagnostics), and the optimised path hard-codes the digit table `"0123456789"`. The fallback preserves correctness in unusual bases at the cost of speed. A clean rewrite either drops the optimisation (CL's `princ-to-string` is already fast on SBCL) or generalises it to any base by computing digits with `(mod magnitude *print-base*)` and a longer digit table — the current early-exit is the lazy compromise.

## Notes for a clean rewrite

- **Delete the macro.** `cl:format` already does compile-time directive rewriting via compiler macros (SBCL has had this for years). The `format-nil` shim adds nothing; just rename every call site to `format`.
- **Keep `princ-integer-to-string` and `integer-decimal-length` only if profiling shows they help.** SBCL's `princ-to-string` on a fixnum is already a few hundred nanoseconds; the manual digit-buffer approach is unlikely to beat it in 2026.
- **Drop `format-nil-a` / `-no-copy` and friends.** They exist to be the targets of macro expansions; once the macro is gone, they have no callers. Replace the three remaining `format-nil-a-no-copy` call sites with `(princ-to-string …)` (which doesn't copy for strings) or `(string …)` (which copies — pick based on whether the caller mutates).
- **`*format-nil-percent*` is `#.(string #\Newline)` and `*format-nil-tilde*` is `"~"`** — neither needs to be a named constant.
- **The `force-format` 8-arg cap is a SubL-ism.** CL's `format` takes any number of args via `&rest`; the optimisation that motivated the cap (avoiding rest-list allocation) doesn't apply on modern CL implementations.
- **No `[Cyc]`-API surface exists for these.** None of the helpers are registered as Cyc API or KB functions; they're purely internal. So removing them has no external consequences.
