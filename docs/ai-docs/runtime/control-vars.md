# Control vars, cyc-kernel, revision extraction

Three files that together carry **the high-level Cyc API entry points and the runtime knobs that govern them**:

- `control-vars.lisp` (431 lines) — **the runtime knob bag**. Almost entirely `defparameter`/`defglobal`/`deflexical` declarations of dynamic variables that influence inference, KB access, mapping, paraphrase, KE, transcripts, and ad-hoc subsystems (Janus, RKF, ACIP). ~190 declarations.
- `cyc-kernel.lisp` (300 lines) — **the canonical "Cyc API" entry points**: `cyc-create`, `cyc-assert`, `cyc-unassert`, `cyc-query`, `cyc-merge`, `cyc-rewrite`, `cyc-edit`, `cyc-kill`, etc. Each is a thin wrapper that publishes the underlying `fi-X-int` ([../kb-access/fi.md](../kb-access/fi.md)) function as a registered API entry, with arglist + arg-type + return-type metadata.
- `cyc-revision-extraction.lisp` (71 lines) — **revision-string parsing**. Three small functions for reading version-control revision strings (e.g. SVN `$Revision: 1234 $` keywords) and producing structured `(major minor patch)` lists.

These three files don't form a tight system; they're collected here because the README's index groups them under "Control vars". The connection: they're all **runtime/configuration concerns**, not domain concerns.

## Control vars: the runtime knob registry

`control-vars.lisp` is **not** a "system" in the architectural sense. It's a flat list of ~190 dynamic variables that subsystems read or rebind. Most have a docstring; many have no consumer in the LarKC port (they're vestigial); the live ones are referenced from across the codebase.

The variables fall into rough categories:

### KB-mutation gating

| Variable | Default | Purpose |
|---|---|---|
| `*read-require-constant-exists*` | NIL (CL port; T in Java) | If T, the `#$Foo` reader errors when `Foo` doesn't exist. NIL during bootstrap so KB load can read constant-references before all constants are loaded. |
| `*hl-lock*` | a lock | Serialises HL-store mutations. |
| `*bootstrapping-kb?*` | NIL | T during the initial KB load so check-once-only-during-bootstrap operations can be skipped or fast-paths taken. |
| `*table-area*` | NIL | Storage area for KB-handle tables (deflexical tables that need explicit setup). |
| `*ignore-assert-types?*` | T (in subl-macros) | Compile-out runtime type checks on assert calls. |

### Matching/comparison predicates

| Variable | Default | Purpose |
|---|---|---|
| `*cnf-matching-predicate*` | `'equal` | Predicate for assertion-lookup-by-CNF. |
| `*gaf-matching-predicate*` | `'equal` | Predicate for GAF assertion lookup. |
| `*nat-matching-predicate*` | `'equal` | Predicate for reified-NAT lookup. |

These are dynamic so a per-query test can swap in `eq` for speed when the caller knows objects are reference-identical.

### Mapping iteration state

The `*mapping-*` family — used by `kb-mapping.lisp` (see [../kb-access/kb-mapping.md](../kb-access/kb-mapping.md)) and friends. About 15 variables that hold per-iteration state:

```
*mapping-answer*, *mapping-pred*, *mapping-source*, *mapping-target*,
*mapping-target-arg*, *mapping-index-arg*, *mapping-gather-arg*,
*mapping-gather-args*, *mapping-output-stream*, *mapping-equality-test*,
*mapping-any-answer?*, *mapping-relation*, *mapping-finished-fn*,
*mapping-path*, *mapping-data-1*, *mapping-data-2*, *mapping-pivot-arg*,
*mapping-gather-key*, *mapping-gather-key-args*,
*mapping-assertion-selection-fn*, *mapping-assertion-bookkeeping-fn*,
*mapping-fn*, *mapping-fn-arg*, *mapping-fn-arg1* ... *mapping-fn-arg8*
```

These are dynamic globals because the mapping iterators were written without closures — instead the body of each iteration consults the global. The variables are bound by `with-mapping-X` macros; the inner mapping function reads them. A clean rewrite should pass mapping state through closures or structs.

### Inference knobs (hundreds)

The bulk of the file is inference-control parameters:

```
*allow-forward-skolemization*, *prefer-forward-skolemization*,
*perform-unification-occurs-check*, *perform-equals-unification*,
*allow-backward-gafs*, *cached-ask-result-direction*,
*check-for-circular-justs*, *filter-deductions-for-trivially-derivable-gafs*,
*inference-debug?*, *browse-forward-inferences?*,
*query-properties-inherited-by-recursive-queries*,
*proof-checking-enabled*, *proof-checker-rules*,
*inference-propagate-mt-scope*, *inference-current-node-mt-scope*,
*inference-literal*, *inference-sense*, *inference-arg*,
*inference-more-supports*, *inference-highly-relevant-assertions*,
*inference-highly-relevant-mts*, *within-hl-failure-backchaining?*,
*hl-failure-backchaining*, *evaluatable-backchain-enabled*,
*negation-by-failure*, *complete-extent-minimization*,
*unbound-rule-backchain-enabled*, *removal-cost-cutoff*,
*forward-inference-removal-cost-cutoff*,
...
```

Each is documented inline. The non-obvious ones are flagged with `declare-control-parameter-internal` so a UI can present them with their human-readable name and value-spec — the toplevel form at the bottom of the file declares ~30 of them. Future-facing UIs (the user-side knob editor) consume these declarations.

### Misc subsystems

Janus (`*janus-*`), ACIP (`*acip-*`), RKF (`*rkf-*`), DBM (`*dbm-*`), CB (`*cb-*` for the constant browser). Mostly stripped or experimental.

## When does a control-var change?

These are **dynamic parameters**, not globals — typical pattern is `let`-bound around a section of code. A few examples:

| Trigger | Effect |
|---|---|
| User-supplied `:cache-inference-results T` query property | `cyc-query` (or its query-runner) rebinds `*cache-inference-results*` for the body of the inference. |
| `with-bookkeeping-info` macro | Rebinds `*cyc-bookkeeping-info*` for an assertion. |
| `with-paraphrase-precision n` | Rebinds `*paraphrase-precision*`. |
| Image startup | Defaults are set by the `defparameter` forms; some variables get `declare-defglobal` registration so the loader knows they're meant to be global. |

`declare-defglobal` is a SubL form that records the variable as global so the dump/load can re-init it. `register-global-lock` registers a lock variable so `initialize-global-locks` (in misc-utilities, see [misc-utilities.md](misc-utilities.md)) can re-create the lock at image startup (locks are not persistable across image saves).

`declare-control-parameter-internal` is the user-knob declaration:

```
(declare-control-parameter-internal *hl-failure-backchaining*
  "Enable HL predicate backchaining"
  "This controls whether or not we allow backchaining ..."
  '((:value nil "No") (:value t "Yes (expensive)")))
```

Records: variable, fancy display name, description, allowed values + labels. The settings spec is a list of `(:value V "Label")` pairs — used by the UI to render a dropdown. See `utilities-macros.lisp:declare-control-parameter-internal`.

## Cyc kernel: the canonical API entry points

`cyc-kernel.lisp` is **the registration layer that exposes the FI** ([../kb-access/fi.md](../kb-access/fi.md)) **as the public API**. Pattern: each `cyc-X` function is a thin wrapper around `fi-X-int` that:

1. Type-checks the args.
2. Calls `fi-X-int`.
3. Performs bookkeeping (`perform-constant-bookkeeping`, `perform-assertion-bookkeeping`).
4. Returns the result.

Each `cyc-X` is then registered as a Cyc API function with arglist, doc, arg-types, and return-types via `register-cyc-api-function`.

The published API surface (examples):

| API function | Purpose | Underlying FI call |
|---|---|---|
| `cyc-create-new-permanent name` | Create constant + log to transcript | `fi-create-int` then permanent op |
| `cyc-create-new-ephemeral name` | Create constant, no transcript | `cyc-create name (make-constant-external-id)` |
| `cyc-create name external-id` | Create constant with specific GUID | `fi-create-int` |
| `cyc-find-or-create name &optional external-id` | Idempotent create | LarKC-stripped |
| `cyc-rename constant name` | Rename constant | LarKC-stripped |
| `cyc-recreate constant` | Re-perform bookkeeping for a constant | LarKC-stripped |
| `cyc-kill fort` | Delete a FORT and all its uses | `fi-kill-int` |
| `cyc-rewrite source-fort target-fort` | Move asserts from source to target | LarKC-stripped |
| `cyc-merge kill-fort keep-fort` | Merge kill into keep | LarKC-stripped |
| `cyc-assert sentence &optional mt properties` | Assert sentence | `fi-assert-int` |
| `cyc-assert-wff sentence &optional mt properties` | Same, but assume well-formed (skips wff check) | `fi-assert-int` |
| `cyc-unassert sentence &optional mt` | Remove sentence | `fi-unassert-int` |
| `cyc-edit old-sentence new-sentence &optional old-mt new-mt properties` | Atomic unassert + assert | LarKC-stripped |
| `cyc-add-argument sentence supports &optional mt properties verify-supports` | Add an argument (justification) for an existing sentence | LarKC-stripped |
| `cyc-remove-argument sentence supports &optional mt` | Remove an argument | LarKC-stripped |
| `cyc-remove-all-arguments sentence &optional mt` | Remove all args for sentence | LarKC-stripped |
| `cyc-query sentence &optional mt properties` | Query for bindings | LarKC-stripped (delegates to inference engine) |
| `cyc-continue-query &optional query-id properties` | Resume an inference (obsolete) | LarKC-stripped |
| `cyc-tms-reconsider-sentence sentence &optional mt` | TMS reconsider a sentence | LarKC-stripped |
| `cyc-tms-reconsider-term term &optional mt` | TMS reconsider a term | LarKC-stripped |
| `cyc-tms-reconsider-mt mt` | TMS reconsider an entire MT | LarKC-stripped |
| `cyc-rename-variables sentence rename-variable-list &optional mt` | Rename variables in a sentence | LarKC-stripped |

Each call has a strict arg-type spec: `((sentence possibly-sentence-p) (mt (nil-or possibly-mt-p)) (properties assert-properties-p))` etc. The return-type is similarly specified: `(constant-p)`, `(booleanp)`, `(query-results-p)`, etc. These metadata are consumed by:

- The eval-in-api validator ([eval-in-api.md](eval-in-api.md)) to gate calls and produce useful error messages.
- API documentation tools that generate human-readable docs from the registry.
- Type-checked client bindings (the Java API code-generator, see [../external/java-c-name-translation-and-backends.md](../external/java-c-name-translation-and-backends.md)).

The split between `cyc-X` (this file) and `fi-X-int` ([../kb-access/fi.md](../kb-access/fi.md)) is: **`cyc-X` is the publicly-named, type-checked, API-registered entry point; `fi-X-int` is the internal implementation called from many places besides the API.** The cyc-kernel layer is the API surface; the FI layer is the implementation.

`unwrap-if-ist` (referenced in `cyc-assert` and `cyc-unassert`) handles the case where the user passes a sentence wrapped in `(#$ist mt sentence)` — it splits the sentence and the mt apart so the call can pass them separately to the FI.

`*assume-assert-sentence-is-wf?*` is the dynamic flag set by `cyc-assert-wff` to skip the well-formedness check (faster but unsafe).

`register-obsolete-cyc-api-function` is for deprecated entries (`cyc-continue-query` here) — same registration as `register-cyc-api-function` but with a deprecation warning at call time.

## Revision extraction

`cyc-revision-extraction.lisp` is **a tiny string-parsing utility for SVN/CVS revision keyword extraction**. Three functions:

```
(extract-cyc-revision-string raw-revision-string)
;; Given "$Revision: 12345 $", returns "12345".
;; Returns NIL if the string doesn't contain two spaces.

(extract-cyc-revision-numbers revision-string &optional (system-version 10))
;; Parses "12.3.4" into (12 3 4).
;; If only one number, prepends system-version: "5" → (10 5).

(construct-cyc-revision-string-from-numbers revision-numbers)
;; (12 3 4) → "12.3.4".
```

Used at image startup to extract a version string from the source code's `$Revision: ... $` SVN keywords (substituted at checkout time by SVN). The version string then appears in the boot banner and is reported by `cyc-revision-string` ([system-info.md](system-info.md)).

The default `system-version` of 10 is the OpenCyc 10 version line — historically Cyc was released as a numbered series and 10 was the LarKC-era version.

This file is dead in the LarKC port — the source is no longer in SVN, so there are no `$Revision: ... $` keywords to parse. The functions exist as utility but nothing calls them anymore.

## How other systems consume control-vars / cyc-kernel / revision-extraction

- **Inference engine** ([../inference/](../inference/)) — reads dozens of `*inference-*`, `*hl-*`, `*proof-*`, `*backchain-*` parameters from `control-vars.lisp` on every step.
- **Mapping** ([../kb-access/kb-mapping.md](../kb-access/kb-mapping.md)) — the `*mapping-*` family is consumed by every `do-X-for-term` iterator.
- **KE / KB browser** — reads the `*cb-*` and `*ke-*` parameters for display formatting.
- **The API itself** — registers all the `cyc-*` entry points; clients call `cyc-create`, `cyc-assert`, `cyc-query`, etc. as their primary KB-mutation API.
- **System startup** ([misc-utilities.md](misc-utilities.md)) — `system-code-initializations` runs `set-the-cyclist *default-cyclist-name*`, `initialize-global-locks` (consumes `register-global-lock` registrations), and triggers control-var resets.
- **Revision extraction** — consumed only by the boot banner (currently unreachable in LarKC).

## Notes for a clean rewrite

### Control vars

- **The `defparameter` flat list is unmaintainable.** ~190 dynamic variables with no organization is the biggest red flag in the runtime. A clean rewrite should group these into typed config structs (one per subsystem) — `InferenceConfig`, `MappingConfig`, `KEConfig`, etc.
- **Dynamic binding for everything is the wrong tool.** Use dynamic binding for "scope this for the body" (e.g. `with-mt-relevance`); use struct fields for "this is part of the system's identity" (e.g. inference cost cutoffs).
- **The `*mapping-*` family is closure-or-struct-shaped.** Replace 25 dynamic globals with a single `MappingState` struct passed through the iteration. This is the textbook case for "stop using global state."
- **`declare-control-parameter-internal` is the right idea.** Knob declarations (name, description, value-spec) are valuable metadata for UIs and docs. Keep but make it part of the per-subsystem config struct: each field has a description and a value-spec.
- **Drop the experimental subsystem variables (Janus, ACIP, RKF, DBM).** They're stripped or unused. A clean rewrite shouldn't carry their globals.
- **`*read-require-constant-exists*`** is a bootstrap-time switch. Make explicit: `(load-kb :require-constants T)` vs. NIL. Don't leave a global flag flapping.

### Cyc kernel

- **The `cyc-X` / `fi-X-int` split is right.** Public API at one layer, implementation at another. Keep the pattern.
- **Type-spec tuples are a real registry.** `((sentence possibly-sentence-p) (mt (nil-or possibly-mt-p)) ...)` is a hand-rolled type schema. A clean rewrite should use a real schema language and have the registration system parse it once into a structured form.
- **Register the unimplemented APIs anyway.** Many `cyc-X` functions are LarKC-stripped (`cyc-find-or-create`, `cyc-edit`, `cyc-merge`, `cyc-rewrite`, `cyc-add-argument`, `cyc-query`, etc.). These are critical KB-management operations. The clean rewrite must rebuild them.
- **Bookkeeping should be a callback list, not an embedded call.** `(perform-constant-bookkeeping result)` is hardcoded after every constant-create. A clean rewrite should let the bookkeeping system register a "post-create" hook so it doesn't appear in every API call.
- **`unwrap-if-ist`** is a clever convenience but it conflates "this sentence is in mt M" with "the user said `(#$ist M sentence)`". Make the convenience explicit at the API surface (or better, drop it — clients should pass mt separately).
- **`*assume-assert-sentence-is-wf?*`** is a fast-path flag. Making it a parameter to `cyc-assert :verify-wff NIL` is cleaner than a dynamic global.
- **`cyc-continue-query` is marked obsolete.** `cyc-query` returns binding sets; for streaming, the modern API is "open an inference, iterate answers, close inference." Drop the obsolete API entirely.

### Revision extraction

- **The whole file is dead.** SVN keywords aren't substituted in this distribution. A clean rewrite should report version from the build system (Cargo.toml / asdf system version / package.json), not from a string parsed out of source code.
- **Keep the `(major minor patch)` data shape.** Semver-style versions are the standard. The number-list representation is fine.
