# Xref database

A static-analysis cross-reference database for SubL source code. In real Cyc this was the **build-time tooling** that walked SubL source files, recorded every method/global definition, every call (method→method, method→global, global→method, top-level→anywhere), every reference / modification / rebinding of a global, and produced a queryable graph used by the SubL→Java/C source translators (`file-translation`, `system-translation`, `c-backend`, `java-name-translation`, `secure-translation`). The Lisp port contains only the two struct shells (`xref-module` with 19 slots, `xref-system` with 15 slots), the dynamic-scope variables, one trivial body (`sxhash-xref-module-method`), and a setup form. **Every defining function, accessor wrapper, recording call, query, sort, and merge function is missing-larkc**, and **no caller in `larkc-cycl/` references any of these**.

## What the engine does with these

`xref-module` is a per-source-file record. The 19 slots split into three groups:

| Group | Slots | What they hold |
|---|---|---|
| Identity | `name`, `xref-system`, `features` | The module's name, its containing system, and feature flags. |
| Method side | `method-definitions`, `method-position-table`, `method-method-table`, `method-global-reference-table`, `method-global-modification-table`, `method-global-binding-table`, `method-formal-arglist-table` | Per-method definition lists and call-graph edges. `method-position-table` keys by method symbol → file offset; `method-method-table` keys caller→callees; `method-global-*` tables key method→globals it touches in three ways (read, write, rebind). |
| Global side | `global-definitions`, `global-position-table`, `global-method-table`, `global-global-reference-table`, `global-binding-type-table` | Per-global lists, file offsets, methods called from that global's value-form, global→global references, and the binding type (`defvar`/`deflexical`/`defparameter`/etc.) of each. |
| Top-level | `top-method-table`, `top-global-reference-table`, `top-global-modification-table`, `top-global-binding-table` | Top-level (non-defining) statements that call methods, reference globals, modify globals, or rebind globals — these are the file-load-time effects. |

`xref-system` is the per-system aggregator. Its 15 slots roll the per-module data up into reverse indexes:

| Slot | Inversion |
|---|---|
| `xref-module-table` | name → xref-module. |
| `method-definition-table` / `global-definition-table` | symbol → list of defining xref-modules. |
| `method-called-by-method-table` / `method-called-by-global-table` / `method-called-at-top-level-table` | callee method → list of callers (by kind). |
| `global-referenced-by-method-table` / `global-referenced-by-global-table` / `global-referenced-at-top-level-table` | global → list of referencers (by kind). |
| `global-modified-by-method-table` / `global-modified-at-top-level-table` | global → list of modifiers. |
| `global-rebound-by-method-table` / `global-rebound-at-top-level-table` | global → list of rebinders. |

The point of having both `xref-module` and `xref-system` is **incremental update**: a single module re-translation produces a new `xref-module`, and `xrs-merge-xref-module` / `xrs-remove-old-xrm` patch the system-level tables in place rather than recomputing from scratch. The "merge" and "remove" function families (the `xrs-merge-new-*` and `xrs-remove-old-*` blocks in the file) are the per-edge-table merge primitives.

## Public API (xref-database.lisp) — what survives

| Item | Status |
|---|---|
| `defstruct xref-module` (19 slots, conc-name `XREF-M-`) | Present. |
| `defstruct xref-system` (15 slots, conc-name `XREF-S-`) | Present. |
| `*dtp-xref-module*`, `*dtp-xref-system*` | Constants. |
| `*current-xref-module*`, `*xref-module-scope*`, `*xref-file-position-scope*`, `*xref-method-scope*`, `*xref-global-scope*` | Dynamic-scope variables threaded through the recording macros. Bound during a translation pass to "the file we're walking now / the offset we're at / the method we're inside / the global initializer we're inside". |
| `*xref-trace*` | Trace-flag defvar. |
| `*empty-set-contents*` | Pre-allocated empty `set-contents`. |
| `sxhash-xref-module-method object` | One-line wrapper around `(sxhash (missing-larkc 8380))`; registered with the structures sxhash-method-table for `*dtp-xref-module*`. The body is itself stripped — likely should hash the `xref-m-name` slot. |
| Setup form: `register-macro-helper` for `xrm-method-definitions`/`xrm-method-position-table`/`xrm-global-definitions`/`xrm-global-position-table`/`current-xref-module`; `note-memoized-function` for `xref-module-relative-input-filename`. | Present. |

Every other function and macro is a stub. The complete catalog is below.

### Macros (TODO — body reconstruction pending)

| Macro | Intent (from arglist + Internal Constants) |
|---|---|
| `do-xrm-method-definitions ((method xrm &key done) &body body)` | Iterate over `xrm-method-definitions`, binding `method` per entry. |
| `do-xrm-methods ((method xrm &key done) &body body)` | Iterate the method-position-table. |
| `do-xrm-global-definitions ((global xrm &key done) &body body)` | Iterate over `xrm-global-definitions`. |
| `do-xrm-globals ((global xrm &key done) &body body)` | Iterate the global-position-table. |
| `within-new-xref-module (&key name features) &body body` | Bind `*current-xref-module*` to a fresh module, run body, merge module into the current xref-system. |
| `with-current-xref-module (xrm &body body)` | Bind `*current-xref-module*` to xrm for body. |
| `xref-within-module (module-name &body body)` | Bind `*xref-module-scope*` to module-name (stringp) for body. |
| `xref-within-file-position (file-position &body body)` | Bind `*xref-file-position-scope*` to file-position (non-negative integer) for body. |
| `xref-within-define (name &body body)` / `xref-within-defmacro (name &body body)` | Sugar over `xref-within-method`. |
| `xref-within-method (method &body body)` | Bind `*xref-method-scope*` to method (symbolp) for body. |
| `xref-within-global (global &body body)` | Bind `*xref-global-scope*` to global (symbolp) for body. |

### Per-module (xrm-) functions — stubs

Lookup and counts:
- `xrm-method-definition-count xrm method`, `xrm-total-method-definition-count xrm`, `xrm-total-method-count xrm`, `xrm-has-multiple-method-definitions? xrm`
- Same family for globals: `xrm-global-definition-count`, `xrm-total-global-definition-count`, `xrm-total-global-count`, `xrm-has-multiple-global-definitions?`
- `xrm-method-definition-postion` (sic) / `xrm-method-definition-positions`, `xrm-global-definition-postion` (sic) / `xrm-global-definition-positions`
- `xrm-method-formal-arglist xrm method`, `xrm-global-binding-type xrm global`

Recording:
- `xrm-record-method-definition`, `xrm-unrecord-method-definition`, `xrm-record-method-formal-arglist`
- `xrm-record-global-definition`, `xrm-unrecord-global-definition`, `xrm-record-global-binding-type`
- `xrm-record-method-calls-method`, `xrm-record-method-references-global`, `xrm-record-method-modifies-global`, `xrm-record-method-rebinds-global`
- `xrm-record-global-calls-method`, `xrm-record-global-references-global`
- `xrm-record-top-calls-method`, `xrm-record-top-references-global`, `xrm-record-top-modifies-global`, `xrm-record-top-rebinds-global`

### Per-system (xrs-) and global functions — stubs

Constructors and lookup:
- `new-xref-system`, `new-xref-module`
- `xrs-name`, `xrs-features`, `xrs-module-count`, `xrs-lookup-module`
- `xrs-method-defining-xrm`/`xrs-method-defining-xrms`, `xrs-method-definition-count`
- `xrs-global-defining-xrm`/`xrs-global-defining-xrms`, `xrs-global-definition-count`
- `xrs-possibly-note-module-features`
- `current-xref-system`, `current-xref-system-modules`, `current-xref-system-features`, `current-xref-system-relevant-modules`
- `current-xref-module-p`, `xref-find-xrm-by-module`, `xref-module-features`, `xref-module-input-filename`

Definition and call queries (per-method, per-global, per-module variants):
- `xref-predefined-method-p`, `xref-predefined-global-p`, `xref-method-formal-arglist`, `method-formal-arglist`, `xref-global-binding-type`
- `xref-method-definition-count`, `xref-method-undefined?`, `xref-method-defining-xrm`, `xref-method-defining-module`, `xref-method-has-multiple-definitions?`, `xref-method-defining-modules` — same family for globals
- `xref-method-definition-position`, `xref-method-definition-positions` — same for globals
- `xref-methods-defined-by-module`, `xref-module-method-definition-count`, `xref-module-method-definition-positions` — same for globals

Reverse-call queries:
- `xref-method-called-by-method?`, `xref-methods-called-by-method`, `xref-globals-referenced-by-method`, `xref-globals-modified-by-method`, `xref-globals-rebound-by-method`, `xref-globals-accessed-by-method`
- `xref-method-called-by-global?`, `xref-methods-called-by-global`, `xref-globals-referenced-by-global`
- `xref-method-called-by-module?`, `xref-module-positions-calling-method`, `xref-methods-called-by-module`, `xref-module-positions-referencing-global`, `xref-globals-referenced-by-module`, `xref-module-positions-modifying-global`, `xref-globals-modified-by-module`, `xref-module-positions-rebinding-global`, `xref-globals-rebound-by-module`, `xref-module-positions-accessing-global`, `xref-globals-accessed-by-module`

Forward-call queries (who calls / references X):
- `xref-methods-that-call-method`, `xref-globals-that-call-method`, `xrms-that-call-method`, `xref-modules-that-call-method`, `xref-method-call-count`, `xref-method-unused-p`
- Same family for `-reference-global`, `-modify-global`, `-rebind-global`, `-access-global` (and the `-never-*-p` predicates)

Cross-module access (for the privacy / encapsulation analysis):
- `xref-xrms-accessed-by-method`, `xref-modules-accessed-by-method`, `xref-xrms-accessed-by-global`, `xref-modules-accessed-by-global`
- `xref-xrms-accessed-by-xrm`, `xref-modules-accessed-by-module`, `xref-xrms-accessed-anywhere-by-xrm`, `xref-modules-accessed-anywhere-by-module`, `xref-globals-accessed-anywhere-by-module`, `xref-methods-accessed-anywhere-by-module`
- `xrms-that-access-method`, `xref-modules-that-access-method`, `xrms-that-access-global-anywhere`, `xref-modules-that-access-global-anywhere`, `xrms-that-access-xrm-anywhere`, `xref-modules-that-access-module-anywhere`
- `xref-justify-module-referencing-module`, `xref-some-external-module-accesses-method-anywhere?`, `xref-method-potentially-private-p`, `xref-module-potentially-private-methods` — same for globals

Source-info / filename:
- `xref-method-source-definition-info`, `xref-global-source-definition-info`, `xref-method-source-definition-comment`, `xref-global-source-definition-comment`, `xref-source-definition-comment`
- `xref-module-relative-input-filename-internal`, `xref-module-relative-input-filename` (memoized)

Merge / remove (system-level patching):
- `xrs-merge-xref-module`, `xrs-merge-new-xrm`, `xrs-merge-definition`, `xrs-merge-new-method-definitions`, `xrs-merge-new-global-definitions`, `xrs-merge-update-backpointer`
- `xrs-merge-new-method-called-by-method`, `xrs-merge-new-method-called-by-global`, `xrs-merge-new-method-called-at-top-level`, `xrs-merge-new-global-referenced-by-method`, `xrs-merge-new-global-referenced-by-global`, `xrs-merge-new-global-referenced-at-top-level`, `xrs-merge-new-global-modified-by-method`, `xrs-merge-new-global-modified-at-top-level`, `xrs-merge-new-global-rebound-by-method`, `xrs-merge-new-global-rebound-at-top-level`
- Symmetric `xrs-remove-old-*` family
- `xrs-unrecord-global-backpointers`, `xrs-unrecord-method-backpointers`, `xref-possibly-record-global-undefinition`, `xref-possibly-record-method-undefinition`

Recording-during-walk (called from the source translator as it scans a file):
- `xref-note-global-definition`, `xref-note-macro-definition`, `xref-note-function-definition`
- `xref-note-method-formal-arglist`, `xref-note-global-binding-type`
- `xref-note-global-reference`, `xref-note-global-modification`, `xref-note-global-binding`
- `xref-note-macro-use`, `xref-note-function-call`, `xref-note-module-removal`

Diagnostics and sorting:
- `xref-trace`
- `xref-sort-called-globals`, `xref-sort-called-methods`, `xref-sort-referenced-xrms`, `xref-sort-referenced-modules`, `xref-sort-calling-globals`, `xref-sort-calling-methods`, `xref-sort-calling-xrms`, `xref-sort-calling-modules`

## Where this fits

**Zero callers in `larkc-cycl/`.** The grep finds:

- `system-version.lisp` line 642 — string `"xref-database"` in the cycl-module manifest, not a call site.
- `system-translation.lisp` — declares an `xref-database` slot in its `system-translation` struct (`sys-tr-xref-database`, `sys-tran-initialize-xref-database`). All bodies are stubs, so the slot exists but no live code reads or writes it.

In the Java tree the consumers are exclusively the **SubL→Java/C source-translator family** (build-time tools, themselves mostly missing-larkc — see [meta/source-translator.md](../meta/source-translator.md)):

| Java caller | Role |
|---|---|
| `file_translation.java` | Walks one source file and populates an xref-module. |
| `system_translation.java` | Aggregates per-file xref-modules into an xref-system (the `$xref_database` slot on the system-translation struct). |
| `secure_translation.java` | Variant of system_translation. |
| `c_backend.java` | Reads the xref-system to emit C names and link-time visibility decisions. |
| `java_name_translation.java` | Reads the xref-system to map SubL symbols to Java identifier names. |

So the xref-database's role is **whole-system static analysis driving cross-language code emission** — a traditional compiler symbol-table / call-graph layer.

## CFASL

`*dtp-xref-module*` and `*dtp-xref-system*` are declared and the structs round-trip through generic `defstruct` CFASL by default. There is no dedicated opcode. The `sxhash-xref-module-method` is registered in the structures' sxhash-method-table — useful when xref-modules are keys in EQUAL hashtables or `set`s.

## Notes for a clean rewrite

- **The xref database is build-time tooling, not a runtime KB system.** A clean rewrite of Cyc proper does not need to reimplement xref-database — it's only needed if the project also reimplements the SubL→Java/C source translator. If the rewrite drops the source translator (likely — modern projects don't transcompile to two backends), drop xref-database with it.
- **Modern equivalents are abundant.** A from-scratch port should use the host language's symbol-table / module system / linker. CL has `cl-walker` and the implementation's introspection. If a SubL-style xref over user code is wanted, treat it as a static-analysis pass over the AST, not a hand-rolled 19-slot struct.
- **The 19/15-slot struct shape is one denormalized table per edge type.** That's the *implementation* a clean rewrite would replace. The right data model is a relational triple-store: `(subject predicate object)` rows with predicates like `:defines-method`, `:calls-method`, `:references-global`, `:modifies-global`, `:rebinds-global`. SQL or an in-memory relational table beats the 30+ recording functions.
- **The dynamic-scope vars (`*xref-method-scope*` etc.) are the recording context.** When the translator is walking a method body and sees a function call, it grabs `*xref-method-scope*` (the enclosing method) and writes a "method calls method" edge. A clean rewrite using the AST keeps the context explicit (a `Visitor` class with a `currentMethod` field), not as dynamic vars.
- **All function bodies are missing-larkc.** The full Cyc engine implements them; the LarKC port stripped them because the LarKC distribution didn't ship with the source translator. A clean rewrite that implements the source translator must also implement these — but again, the translator itself is likely better replaced wholesale, not ported.
- **The naming inconsistency `xrm-method-definition-postion`/`-positions` (sic, "postion" not "position") is a typo in the original SubL.** Fix at the rename pass; nobody calls it.
- **The macros (`do-xrm-method-definitions` et al.) are sugar for iteration.** A clean rewrite that uses real iteration constructs gets these for free.
- **Drop the merge/remove machinery if the rewrite isn't doing incremental compilation.** A whole-system rebuild on every save is fine for projects of LarKC's size; the merge code exists to amortize across iterative re-translations and is significant complexity.
