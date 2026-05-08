# System info, parameters, version, benchmarks

Four files of **build-time / startup-time / introspection metadata**:

- `system-info.lisp` (118 lines) — feature-flag registry (`cyc-*-feature` predicates), revision-string accessors, image-uptime tracking, and the `*cyc-home-directory*` / `*kbs-directory*` path constants.
- `system-parameters.lisp` (175 lines) — **typed knob registry**: `define-system-parameter` for declaring config variables with types and defaults, plus the file-load mechanism for reading config from disk. Distinct from `control-vars.lisp` which is a flat `defparameter` list.
- `system-version.lisp` (654 lines) — **the file manifest**: long lists of source-file names organized by system (`cycl`, `subl-translator`, `cyc-tests`). At image startup, `create-system` registers each system and `create-module` registers each file. Plus revision-number constants for sub-systems.
- `system-benchmarks.lisp` (491 lines) — **CycLOPs benchmark suite**: builds a synthetic family-tree ontology, runs queries against it, measures elapsed time, normalizes by bogomips. Used to compare hardware/software configurations.

These are housekeeping concerns — important for diagnostics and configuration, but not load-bearing for the runtime.

## System info: features and revisions

`system-info.lisp` defines the **feature-flag system** — a list of named features that this image supports. The pattern is:

```
(note-translation-feature 'cyc-html-feature)     ; this image was built with HTML support
(note-translation-feature 'cyc-pph-feature)      ; this image has paraphrase
...
```

`*available-cyc-features*` is the list of declared features. `note-translation-feature` is LarKC-stripped, but the surviving `note-translation-features` macro (reconstructed) takes a `&body` of feature names and notes each:

```
(defmacro note-translation-features (&body features)
  `(progn ,@(mapcar (lambda (f) `(note-translation-feature ',f)) features)))
```

Each feature has a corresponding `(cyc-X-feature)` predicate that returns whether this image supports that feature. The 20+ features documented:

```
cyc-html-feature, cyc-date-feature, cyc-quant-feature, cyc-pph-feature,
cyc-lexicon-feature, cyc-nl-feature, cyc-hpsg-feature, cyc-external-feature,
cyc-wordnet-feature, cyc-retrieval-feature, cyc-thesaurus-feature,
cyc-maint-feature, cyc-secure-feature, cyc-hitek-feature, cyc-hpkb-feature,
cyc-qa-feature, cyc-kbi-feature, cyc-opencyc-feature, cyc-researchcyc-feature,
cyc-sksi-feature
```

These split Cyc's functionality into shippable subsets. `cyc-opencyc-feature` is the LarKC build's headline answer — it returns NIL because LarKC is not OpenCyc-flavoured. Most other predicates are LarKC-stripped (have no body), so calling them errors. The clean rewrite needs to reimplement the predicates or drop the abstraction.

`check-for-feature` (a stripped macro reconstructed as a no-op) was the build-time gate: code wrapped in `(check-for-feature 'cyc-pph-feature) ...` would only be present in builds with that feature. With the macro stripped, all feature-gated code is unconditionally present (or, rather, the gates are no-ops).

### `cyc-revision-string` and friends

```
*cyc-raw-revision-string* = "$Revision: 128948 $"      (in system-version.lisp)
*cyc-major-version-number* = 10
*cyc-revision-numbers* = (extract-cyc-revision-numbers ...)
*cyc-revision-string* = (construct-cyc-revision-string-from-numbers ...)
```

These four parameters are computed at load time from `*cyc-raw-revision-string*`. The result is something like `"10.128948"` — major version 10, build 128948.

`(cyc-revision-string)` and `(cyc-revision-numbers)` are the public accessors. Both registered as external symbols.

### Uptime

```
*cycl-start-time*        = NIL initially; set by reset-cycl-start-time
(reset-cycl-start-time)  = sets *cycl-start-time* to current universal-time
(cycl-start-time)        = accessor (LarKC-stripped)
(cycl-uptime)            = (- (get-universal-time) *cycl-start-time*) (LarKC-stripped)
```

Used for diagnostic display ("this image has been up for X hours").

### Paths

```
*cyc-home-directory*  ; the source directory (asdf system path)
*kbs-directory*       ; ~/clyc-kbs/ — where loadable KB dump files live
```

`*cyc-home-directory*` is a deflexical computed at load time using `asdf:system-source-directory`. The CL port uses asdf; the Java port had a different mechanism. `*kbs-directory*` is `~/clyc-kbs/` by default — the user's home directory's `clyc-kbs/` subdir, where dump files load from.

`*subl-initial-continuation*` = NIL — a back-pointer to the SubL "initial continuation" that the boot sequence resumed at the very start. In the CL port this is dead — there's no SubL continuation system.

## System parameters: typed knobs

`system-parameters.lisp` is a **typed alternative to `defparameter`** for system-level configuration. Each parameter has a name, default value, type, and description; the registry validates types and enables config-file loading.

### `define-system-parameter`

```
(define-system-parameter *base-tcp-port* 3600 'integer
  "[Cyc] The base port offset for all the TCP services for the Cyc image.")
```

Expands to:
1. `(defvar *base-tcp-port* :unset "...")` — make the variable, marker `:unset` until the registry sets it.
2. `(register-system-parameter '*base-tcp-port* 3600 'integer "...")` — push onto `*system-parameters*` with the metadata.

The valid types are:

```
*valid-system-parameter-types* = (t-or-nil nil-or-string string full-path integer symbol none)
```

`none` is the escape hatch for "I don't want type-checking." `t-or-nil` is the boolean alias.

### Lifecycle

| Trigger | Effect |
|---|---|
| Source files load | Each `define-system-parameter` form registers metadata and creates the variable with `:unset` value. |
| `(load-system-parameters)` | Reads a config file from `*cyc-home-directory*`/`config-filename`, sets each parameter to its file value. |
| `(setup-system-parameters directory &optional config-filename)` | Same but specify a different directory — used when overriding defaults at startup. (LarKC-stripped) |
| `(check-system-parameters)` | After load, walk `*system-parameters*` and warn for any that are `:unset` (no default applied) or whose value doesn't match its declared type. |
| `(remove-system-parameter name)` | Drop a parameter from the registry. |

`system-parameter-value-unset-p val` is `(eq val :unset)` — the sentinel test.

### What gets registered as a system parameter

System parameters are the **deployment-tunable subset** of Cyc's globals — things a sysadmin might want to set in a config file. Examples:

```
*base-tcp-port* = 3600
*fi-port-offset* = 1
*cfasl-port-offset* = 14
*tcp-localhost-only?* = NIL
*permit-api-host-access* = T
*use-transcript-server* = NIL
*master-transcript-lock-host* = NIL
*master-transcript-server-port* = 3608
*allow-guest-to-edit?* = NIL
*default-cyclist-name* = "Guest"
*startup-communication-mode* = :deaf
*start-agenda-at-startup?* = T
*continue-agenda-on-error* = T
... and ~30 more
```

In contrast, the variables in `control-vars.lisp` ([control-vars.md](control-vars.md)) are **inference-tunable** — flags meant to be rebound per-query, not configured at deployment time. The split is editorial but real: anything in `system-parameters.lisp` is "set this at startup and forget it"; anything in `control-vars.lisp` is "rebind this for the dynamic extent of an operation."

## System version: the file manifest

`system-version.lisp` is **the master list of source files**, organized by system. The file's bulk is one giant `dolist` over a list of ~250 file names that creates a `module` record for each:

```
(toplevel
  (create-system "cycl")
  (dolist (name '("cyc-cvs-id" "meta-macros" "access-macros" ... ~250 entries ...))
    (create-module name "cycl" t))
  (create-system "cycl-tests")
  (dolist (name '("test-query-suite" ...))
    (create-module name "cycl-tests" t))
  ...)
```

This populates `*module-index*` and `*system-index*` (see [modules-and-subl.md](modules-and-subl.md)). The point: at any moment, the running image has a complete inventory of what files belong to what system, used by:

- The cross-compiler (SubL → Java) to know what to translate.
- The test runner to know what tests are in the `cycl-tests` system.
- The diagnostic banner ("this is a `cycl` image with N modules").

In the LarKC port the cross-compiler is stripped, so the manifest is mostly cosmetic.

### Per-subsystem revision constants

```
*cycl-common-revision* = "1.269"
*cycl-crtl-revision* = "1.555"
*cycl-translator-revision* = "1.69"
*cycl-opencyc-revision* = "1.391"
*cycl-framework-revision* = "1.1767"
*cycl-sublisp-revision* = "1.319"
*cycl-tests-revision* = "1.907"
*cycl-mysentient-revision* = "1.437"
*cycl-butler-revision* = "1.277"
*cycl-tool-revision* = "1.652"
*cycl-=======-revision* = ""  ; literally the merge-conflict marker captured as a name
```

These are SVN revision numbers per-subsystem at the time of the LarKC release. `*cycl-=======-revision*` is hilariously the **merge-conflict marker** — somewhere along the way, an SVN merge conflict left `=======` in the source as if it were a real subsystem name. Kept as a historical artifact.

### When does the manifest change?

Never, post-startup. The `dolist` runs once at load time and never executes again. There's no `delete-module` or `update-module` API. A clean rewrite that wants dynamic modules (e.g. plugin loading) needs to add this.

## System benchmarks: CycLOPs

`system-benchmarks.lisp` implements **CycLOPs** — a Cyc-specific benchmark for measuring the speed of the inference engine on a synthetic family-tree ontology.

### What CycLOPs does

1. **Setup**: `benchmark-cyclops-setup` builds a fixed-shape ontology:
   - Two MTs (`mt-1`, `mt-2`)
   - A collection hierarchy (top → sub-collections → bottom-collection)
   - Predicates: parent, ancestor, sibling, family
   - Family-tree relationships among individuals of the bottom collection
2. **Run guts**: `benchmark-cyclops-guts` runs a battery of queries against the ontology — reachability through transitive relations (ancestor), siblings (commutative), family (symmetric+transitive). Times the elapsed wall clock.
3. **Compute score**: `(/ reference-time elapsed-time)` × normalisation = a single number (CycLOPs).
4. **Teardown**: clean up the ontology so the KB is unchanged.
5. **Repeat**: run N times (with throw-away-first-n initial runs to warm caches), return the median.

The "CycLOPs power" parameter (`*benchmark-cyclops-power*` = 6) controls problem size — the ontology has ~`2^power` entities. `*cyclops-throwaway-default*` = 33 — first 33 runs discarded.

### Key entry points

```
benchmark-cyclops-compensating-for-paging &optional throwaway-n sample-n power stream
benchmark-cyclops-n-times n &optional power stream throw-away-first-n
median-cyclops n &optional power stream throw-away-first-n
```

`median-cyclops` returns two values: the median CycLOPs score and the bogomips/cyclops ratio (a normalisation that lets you compare across machines with different CPUs).

### When does CycLOPs run?

A user explicitly invokes it. Not part of normal startup. Intended for:

- **Performance-regression testing**: "did this change make Cyc slower?"
- **Hardware comparison**: "how much faster is server A than server B?"
- **CI gating**: "fail the build if CycLOPs drops below threshold."

A few internal functions are LarKC-stripped (e.g. the median computation involves `missing-larkc 31856` when N > 1, suggesting the multi-sample stat path is incomplete).

### Side effects

CycLOPs **mutates the KB** during setup (asserts thousands of relations) and **restores it** during teardown. The teardown is wrapped in `*is-thread-performing-cleanup?*` so error paths don't accidentally skip it. If teardown fails, the KB is left dirty — manual recovery needed.

## How other systems consume these

- **`*cyc-home-directory*`** is consumed by `transcript-utilities.lisp`, `system-parameters.lisp` (config file path), and other path-relative functions.
- **`(cyc-revision-string)`** appears in startup banners and in CFASL dump headers (so dumps are tagged with the producing image's version).
- **`(cyc-X-feature)` predicates** are consumed by feature-gated code paths — most are LarKC-stripped, but `(cyc-opencyc-feature)` and `(cyc-researchcyc-feature)` are referenced in the API registrations and elsewhere.
- **System parameters** are consumed by `tcp-server-utilities.lisp` (port), `transcript-server.lisp` (master-transcript host/port), `eval-in-api.lisp` (`*permit-api-host-access*`), and `system-code-initializations` (which calls `set-the-cyclist *default-cyclist-name*`).
- **The module manifest** is consumed by tooling (cross-compiler, doc generator, test runner) — mostly stripped in LarKC.
- **CycLOPs** is consumed by no other code; it's a leaf utility invoked by humans.

## Notes for a clean rewrite

### Feature flags

- **Drop the `cyc-X-feature` predicate family.** Use a host-language conditional-compilation mechanism (CL's `#+`/`#-`, Rust's `#[cfg]`, etc.) or a single `*features*` set with a query API. The current implementation has 20 predicates, most stripped, none with a clear flag-set/flag-clear protocol.
- **Or use a real plugin system.** If features are runtime-loadable, define a `Plugin` type with a name and a `register` callback; the image loads plugins from a directory and tracks them in `*registered-plugins*`. Feature predicates become `(plugin-installed-p :pph)`.

### System parameters

- **The typed-parameter idea is right.** Keep `define-system-parameter`. Move from a flat list to a TOML/YAML schema with sections (`[network]`, `[kb]`, `[inference]`).
- **`:unset` as a default value sentinel is fragile.** Use the host language's "this hasn't been initialized" mechanism — CL's `slot-boundp`, Rust's `Option<T>`, etc.
- **Drop `setup-system-parameters` directory argument.** In a clean rewrite, the config file location is determined by deployment (env var, command-line arg, conventional path). One way, not many.
- **Run `check-system-parameters` at startup, not on demand.** Type errors at startup are loud and immediate; type errors discovered later are obscure.

### System version / file manifest

- **Drop the file manifest entirely.** Modern build systems track sources. Clyc uses asdf; asdf already knows what files are in the system. Don't duplicate the list in source code.
- **Drop the per-subsystem revision constants.** SVN revisions are not the right granularity. Use git commits, package versions, or build identifiers.
- **Delete `*cycl-=======-revision*`.** That's a merge conflict in source.

### Benchmarks

- **CycLOPs is a useful benchmark.** Keep it as a separate harness invoked by CI / ops. Don't ship it in the runtime image.
- **The synthetic-ontology approach is fine.** It's a known-shape problem the inference engine should solve quickly. A clean rewrite should add benchmarks for query types CycLOPs doesn't cover — e.g. assertion throughput, memoization-hit-rate-under-load, transcript-replay rate.
- **Bogomips normalisation is bogus** (see [misc-utilities.md](misc-utilities.md)). Use a real CPU benchmark (sustained MIPS, single-thread integer score) or just report wall-clock time and let the analysis script normalize.
- **The KB-mutating setup is risky.** A clean rewrite should isolate benchmark assertions in an MT that gets entirely dropped on teardown — even partial-cleanup failures don't leak into BaseKB.
