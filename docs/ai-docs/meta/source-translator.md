# SubL → Java/C source translator

Three files implement what was Cycorp's **build-time tool** for compiling SubL source into other target languages — primarily Java (the `larkc-java/` we are reverse-engineering from) and C. The system is **almost entirely missing-larkc**: virtually every function in all three files is a body-less active declareFunction. What survives is the **shape of the data structures** that the translator manipulates and a few macros that other translator code uses for their host bookkeeping.

The three files:

| File | Role |
|---|---|
| `file-translation.lisp` | Per-source-file accumulator — the `trans-subl-file` (TSF) struct that holds everything the translator learns about one input file as it walks. |
| `secure-translation.lisp` | Symbol-obfuscation for "secure" builds — the `secure-id-database` struct and the symbol-exception machinery for keeping certain names un-obfuscated. |
| `system-translation.lisp` | The system-level orchestrator — the `system-translation` struct holding a manifest, set of modules, target backend, output directory, and the secure-id database. The top of the build pipeline. |

**No file outside this triplet (and the related backend files `java-name-translation`, `c-name-translation`, `java-backend`, `c-backend`, `java-api-kernel`) consumes any of this.** The translator is *fully self-contained build infrastructure* with no runtime role in the LarKC port.

This document covers what the data structures *look like* and what the lifecycle of a translation run *would have been*, since that is the spec a clean rewrite needs if it wants to regenerate alternate target languages from SubL source. The function bodies are gone; only the names and signatures remain as a design surface.

## What the translator was for

Cycorp's primary deployment target was a custom Lisp environment, but they shipped builds in C and Java for performance and embedding. The translator took SubL source and produced Java (`.java`) or C (`.c`) source files, with the build pipeline:

1. Read SubL source files.
2. For each file, produce a `trans-subl-file` accumulator.
3. Walk every form in the file, classifying it (`defconstant` / `deflexical` / `defun` / `defmacro` / `(toplevel ...)`) and noting referenced globals/functions, defined globals/functions/macros, internal-constant uses, etc.
4. Possibly obfuscate symbols (the "secure" path) — replace human-readable names with opaque IDs, using the secure-id-database to maintain consistent mappings across translator runs.
5. Run a backend (Java, C) over the accumulated TSF to emit target-language code that, when compiled, reproduces the SubL behavior.

The compiled Java in `larkc-java/` is the output of this exact pipeline. We are reverse-engineering its output back to its input. The translator is the *forward* direction.

## `trans-subl-file` (TSF) — the per-file accumulator

Defined in `file-translation.lisp` with conc-name `TSF-`. Slots:

| Slot | Holds |
|---|---|
| `module-name` | The module symbol (e.g. `'access-macros`). |
| `filename` | The source file path. |
| `internal-constants` | Table of constants (`$listN`, `$symN`, `$strN`, etc.) introduced for this file's compile-time literal interning. |
| `referenced-globals` | Globals this file reads/writes that were defined elsewhere. |
| `referenced-functions` | Functions this file calls that were defined elsewhere. |
| `definitions` | The list of all top-level definitions in this file, in source order. |
| `top-level-forms` | Bare top-level expressions (calls, registrations) that aren't `def*` forms. |
| `defined-globals` | Globals defined in this file. |
| `defined-functions` | Functions defined in this file. |
| `defined-macros` | Macros defined in this file. |
| `arglist-table` | Per-defined-function arglist record (because Java/C lose CL arglist metadata). |
| `binding-type-table` | Per-defined-global storage class (defconstant / deflexical / defparameter / defvar / defglobal). |
| `method-visibility-table` | Per-defined-function access level (public/protected/private). |
| `global-visibility-table` | Per-defined-global access level. |
| `rwbc-methods` | "Returns Within Binding Construct" methods — functions whose `return` semantics need special handling because they return out of a `let`/`progn`. Used by the Java backend, which emits these as throw-of-result patterns. |

The TSF is the single source of truth for "what's in this file" once the front-end pass is done. The backend reads the TSF to emit Java/C.

`*current-ts-file*` is a dynamic binding pointing at the currently-being-translated TSF. Many of the (stripped) `tsf-possibly-note-X` functions read from this dynamic variable — they're called from the form walker without having to thread the TSF through every recursive descent. Same SubL convention as the propagation system in [meta/rewrite-of-propagation.md](rewrite-of-propagation.md).

`*trans-subl-global-definers*` lists the storage classes the translator recognizes: `defconstant`, `deflexical`, `defglobal`, `defparameter`, `defvar`. The list maps to TSF binding-type entries.

`*predefined-constants*` was a large list of things like `t`, `nil`, integers 0-20, single characters — values the translator treated as built-in rather than as internal constants needing explicit interning. **Empty in the CL port** because these are all native CL objects already; the translator concept doesn't apply.

## `secure-id-database` (SID-DB) — the symbol-obfuscation map

Defined in `secure-translation.lisp` with conc-name `SID-DB-`. Slots — five bidirectional ID↔name maps:

| Slot | Maps |
|---|---|
| `security-level` | `:none`, `:low`, `:medium`, `:high`. Higher levels obfuscate more aggressively. |
| `id-module-table`, `module-id-table` | Module name ↔ obfuscated module ID. |
| `id-method-table`, `method-id-table` | Function (method) name ↔ obfuscated method ID. |
| `id-global-table`, `global-id-table` | Global variable name ↔ obfuscated global ID. |
| `symbol-exceptions` | Set of symbols that should NOT be obfuscated even at high security level. |
| `id-symbol-table`, `symbol-id-table` | All-symbols name ↔ obfuscated ID for symbols that aren't modules/methods/globals (e.g. macro names, special operators). |

The bidirectional structure exists because the translator needs both directions: forward (look up the ID for a name when emitting code) and reverse (look up the name from an ID when re-translating after a manifest change).

The four `*translator-security-levels*` `(:none :low :medium :high)` are an ordered enumeration consumed by the obfuscation logic — `none` does nothing, `high` maximally obfuscates everything except the exceptions list.

`*secure-id-database-type-marker*` is a GUID `c3edef08-eef1-11dd-9624-00219b50e0e5` — the CFASL serialization marker so a saved-and-reloaded SID-DB can be identified across versions.

### `*misc-symbols-not-to-obfuscate*`

A hard-coded list of ~40 symbols that the secure-id-database keeps unobfuscated regardless of security level. This is the **public API surface that survives obfuscation**:

- KB-control flags: `*cache-inference-results*`, `*hl-failure-backchaining*`, `*enable-rewrite-of-propagation?*`, `*forward-propagate-from-negations*`.
- Initialization & loading: `kb-statistics`, `system-code-initializations`, `system-kb-initializations`, `core-kb-finalization`, `load-kb`, `dump-kb`, `dump-standard-kb`.
- Servers: `enable-tcp-server`, `start-agenda`, `api-server-top-level`, `cfasl-server-top-level`, `html-server-top-level`.
- API helpers: `low-assert-literal`, `fi-assert-int`, `cyc-function-to-arg`, `relevant-mt?`, `hl-find-or-create-nart`, `hl-external-id-string-p`.
- Standard streams and ports: `*standard-input*`, `*inference-trace-port*`, `api-port`, `cfasl-port`, `html-port`, `tmap-port`, `read-ignoring-errors`, `finish-output`.
- Feature flags: `cyc-html-feature`, `cyc-thesaurus-feature`, `*eval-in-api?*`, `*require-api-remote-cycl*`.
- Init-file infrastructure: `*init-file-loaded?*`, `*thesaurus-filename*`, `*thesaurus-filename-extension*`, `*thesaurus-subdirectories*`, `load-system-parameters`, `load-thesaurus-init-file`, `probe-file`.
- Misc: `server-summary`, `halt-cyc-image`, `all`, `none`, `initialize-agenda`, `initialize-transcript-handling`, `load-api`, `core-kb-start-bootstrapping`, `core-kb-finish-bootstrapping`, `core-kb-start-definitions`, `core-kb-finish-definitions`, `core-kb-initialization`, `thesaurus-manager-access-protocol-server-top-level`, `robust-enable-tcp-server`.

This list is **the de facto specification of Cyc's stable external surface** — everything not on this list could be renamed; everything on it must keep its name across builds. For the clean rewrite, this is the closest thing the codebase has to a public API manifest.

## `system-translation` (SYS-TR) — the build orchestrator

Defined in `system-translation.lisp` with conc-name `SYS-TR-`. Slots:

| Slot | Holds |
|---|---|
| `system` | The system descriptor (which manifest defines this build). |
| `backend` | `:sl2c` (SubL→C) or `:sl2java` (SubL→Java). |
| `features` | Build-time feature flags (which conditional code is included). |
| `input-directory` | Where SubL source lives. |
| `output-directory` | Where Java/C output goes. |
| `manifest-file` | Path to the manifest declaring all modules in this system. |
| `modules` | Resolved module list. |
| `module-filename-table` | Module → input/output filename map. |
| `module-features-table` | Per-module feature flags (some modules are conditionally included). |
| `module-initialization-table` | Per-module declare/init/setup function names (the three-phase loading protocol from [the SubL→Java compilation reference](../../../.claude/projects/-home-davidh-git-clyc/memory/project_subl_java_compilation.md)). |
| `xref-database` | The cross-reference database — what defines what, what calls what. |
| `secure-id-database` | The obfuscation map for this build (or nil for non-secure builds). |
| `last-translation-time` | Timestamp for incremental rebuilds. |

`*current-system-translation*` is a dynamic binding for the currently-running translation pass. `*translation-trace-stream*` is where progress messages go (default `t` = stdout).

`*translator-output-enabled?*` (defparameter, default `t`) gates actual file writes — when nil, the backend runs but throws output away (used for dry-run / validation runs).

`*translator-backends*` is `'(:sl2c :sl2java)` — the two output targets. Adding a backend means extending this list and writing the corresponding `c-backend.lisp` / `java-backend.lisp` files.

`*default-secure-id-database-filename*` is `"translation-secure-id-database-file.cfasl"` — the on-disk persisted SID-DB. Saved as CFASL between runs so secure builds reuse the same obfuscation IDs across iterations.

## Macros that survived the strip

Three macros have reconstructed bodies in the port:

- **`with-translator-output-file ((stream-var filename) &body body)`** — opens `filename` for output, binds `stream-var`, runs body, closes the stream on unwind. Standard `unwind-protect`-around-`open` pattern. Consumed by the (stripped) backend code that emits Java/C source files.
- **`with-simple-restart-loop ((name format-control . format-args) &body body)`** — wraps body in a `with-simple-restart` and repeats until body completes without the restart firing. Used by translator passes where the user (or harness) might invoke the restart to retry a failed module without aborting the whole system translation.
- **`do-manifest-systems ((manifest-system-var manifest) &body body)`** — `cdolist` over a manifest's systems. Trivial sugar.

All other macros and functions are stripped. The five files combined have ~50 lines of live code and ~600 lines of stub-comments documenting what was there.

## Lifecycle of a translation pass (reconstructed from function names)

1. **Parse manifest** — `translator-parse-manifest-file FILENAME` reads a manifest declaring systems, modules, and dependencies.
2. **Build system-translation** — `new-system-translation` constructs a SYS-TR with the requested system, backend, features, and security level. `sys-tran-initialize-xref-database` and `sys-tran-initialize-module-info` populate the per-module tables.
3. **For each module** (within `with-simple-restart-loop` for retryability):
   - **Read source file**, construct a fresh TSF.
   - **Walk every form**, calling `ts-file-translate-form` per top-level form. This dispatches: `defun` → `tsf-possibly-note-defined-function-arglist`; `defparameter` etc. → `tsf-possibly-note-defined-global-binding-type`; references → `tsf-possibly-note-referenced-global` / `tsf-possibly-note-referenced-function`; literals → `tsf-possibly-convert-internal-constant` (intern as `$listN` etc.).
   - **Finalize TSF** — `finalize-ts-file` resolves referenced/defined sets and computes the three initialization methods (`ts-file-declare-method`, `ts-file-init-method`, `ts-file-setup-method`).
   - **Run backend** — `translator-possibly-translate-one-module` calls into `c-backend.lisp` or `java-backend.lisp` with the TSF and output filename, emitting target-language source.
4. **Output system-level files** — `sys-tran-output-system-level-files` writes manifest-derived metadata: the module list, the dependency graph, the SID-DB file (if secure).
5. **Update last-translation-time** — `sys-tran-set-last-translation-time` so an incremental retranslate can skip unmodified modules.

## Notes for a clean rewrite

- **Don't include this in the runtime.** The translator is build infrastructure, not engine code. A clean rewrite hosted in CL doesn't need the translator at all — the source language *is* the runtime language. If the rewrite wants to support Java/C output, that becomes a separate compiler project, not part of the engine.
- **The SubL → Java/C compilation as a project is itself worth questioning.** In 2009 Cycorp needed Java/C builds for speed and embedding. In a clean-rewrite era you would: (a) host on a fast Lisp like SBCL natively for the engine, (b) expose RPC (gRPC, REST) for embedded use cases. The cross-compile is a 90s artifact. Don't recreate it.
- **The TSF accumulator pattern is generically useful** — "walk forms, accumulate metadata into a struct, hand to a backend." Keep the *idea* (visitor pattern with a state record) for any future code-emit work, but don't preserve the specific slot list, which is overfit to SubL semantics.
- **The `*misc-symbols-not-to-obfuscate*` list is the highest-value artifact in this entire triplet.** It documents the API surface that Cycorp committed to as stable. Any clean rewrite that wants to preserve API compatibility should treat this list as the floor of public symbols. Most are still relevant: `system-code-initializations`, `load-kb`, `enable-tcp-server`, `start-agenda`, `*hl-failure-backchaining*`, etc.
- **The five-symbol-class split (module / method / global / symbol / exception) is clean.** A modern obfuscator would still want this granularity — module-level renames, function-level renames, and a separate "leave these alone" exception list. Preserve the design.
- **The `:sl2c` and `:sl2java` backend tags suggest Cycorp at one point also had `:sl2lisp` for self-hosted output.** That backend (which would be trivially the identity if it existed) is not present. A clean rewrite hosted on CL wouldn't need it.
- **`with-simple-restart-loop` is genuinely useful** — wrap any retryable action in a restart that the user can invoke to retry without aborting. Worth preserving as a general utility, separate from the translator.
- **The `last-translation-time` timestamp is an incremental-build optimization** that any modern build tool (Bazel, Make, Cargo) handles natively. Don't reinvent.
- **The xref-database slot points at a deep structure** (tracked in `xref-database.lisp`, separately) that records cross-references between modules — what defines symbol X, who references it, etc. The xref database is the basis for "find all callers of foo" and dead-code analysis. A clean rewrite hosted in CL gets this from SLIME / SLY / source-location queries; don't reinvent.
- **`sxhash-trans-subl-file-method` calls `(missing-larkc 29327)` and is registered as the sxhash method for the struct.** Likely the stripped body hashed `(filename . module-name)` — the natural identity of a TSF. Inert in the port.
- **All three structs use `defstruct` with custom conc-names (TSF-, SID-DB-, SYS-TR-).** The Java forms `_csetf-X` setters are `(setf X)` expanders in CL; they're ported as comments since `defstruct` provides them automatically.
- **The CFASL persistence of SID-DB** (`save-secure-id-database-to-file`, `restore-secure-id-database-from-file`, `construct-recipe-for-secure-id-database`, `interpret-secure-id-database-recipe-by-version`) is actually load-bearing: secure builds must reuse the same obfuscation IDs across iterations or the C/Java compilation breaks ABI. The "recipe" indirection (a versioned data form, parsed by `interpret-secure-id-database-recipe-vXpY`) is the upgrade path so an old SID-DB file can still be read by a newer translator. Preserve this pattern if the rewrite supports any persistent metadata that crosses tool versions.
