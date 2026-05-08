# Misc helpers

Two grab-bag files: `misc-utilities.lisp` and `misc-kb-utilities.lisp`. They contain bits of glue that don't fit anywhere else — startup orchestration, the `:uninitialized` sentinel pattern, machine-speed measurement, copyright boilerplate, KB-handle dispatch — but unlike most "utility" files in the codebase, both are **load-bearing**: the first owns the system-startup sequence, and the second owns the polymorphic `kb-handle` mechanism by which any KB object can be reduced to a `(type, id)` pair and reconstituted.

## What's in each file

### `misc-utilities.lisp`

| Section | What it does |
|---|---|
| `*kb-content-copyright-notice*` | A static string holding Cyc's KB-content copyright boilerplate. **Unreferenced** in the LarKC port — no code emits it. The three `copyright-notice` / `kb-content-copyright-notice` / `write-kb-content-copyright-notice` functions that would consume it are stripped. |
| `system-code-initializations` (and family) | The **top-level startup orchestrator**. One function, called by external callers (transcript loader, REPL boot), that runs the entire startup pipeline: image-init → HL-init → inference-init → API-init → optional app-init → KB-init (if a KB is loaded). |
| HL-store cache initialization | Sets up the on-disk caches that back the LRU object managers (constants, NARTs, assertions, deductions, KB-HL-supports, NART HL formulas, unrepresented-term index). Driven by `initialize-hl-store-caches-from-directory`. |
| `*hl-store-caches-directory*` | Where the on-disk file-vector swap files live. |
| `other-binary-arg` | `(case arg (1 2) (2 1))` — the reciprocal of a binary predicate's argument index. Heavily used in GHL/TVA/SBHL "given the index arg, what's the gather arg" computations. |
| `machine-bogomips`, `compute-machine-bogomips`, `scale-by-bogomips`, `clear-machine-bogomips` | Read `/proc/cpuinfo` for processor speed, then scale benchmark-derived timeouts so a slower machine gets longer time budgets. Used by inference timing (`inference-datastructures-inference.lisp`) and the benchmarking system. |
| `uninitialized`, `uninitialized-p`, `initialized-p` | The `:uninitialized` sentinel keyword. The trio is used everywhere an out-of-band "I haven't been computed yet" marker is needed — `at-macros`, `at-defns`, `kb-object-manager`, `sbhl-link-methods`. Distinct from `nil` because some valid initialized values *are* `nil`. |
| `warn-unless` | `(warn-unless TEST FMT . ARGS)` — `(unless TEST (warn FMT ARGS))`. Tiny but used in error-tolerant code paths. |

The bulk of `misc-utilities.lisp` is the startup pipeline. Everything else is a single small primitive that other files depend on.

### `misc-kb-utilities.lisp`

| Section | What it does |
|---|---|
| `*kb-handle-internal-method-table*` | A 256-element vector indexed by SubL type tag, intended to hold per-type `kb-handle-internal` methods. **Inert in the port** — Common Lisp doesn't expose SubL's integer type tags, so the vector is allocated but never written. The per-type methods (`kb-handle-internal-constant-method`, `-nart-method`, `-variable-method`, `-assertion-method`, `-deduction-method`) are still defined and callable, just not dispatched through the table. |
| `*find-object-by-kb-handle-methods*` | Alist of `(TYPE METHOD-FN)` pairs. The reverse direction — given `(type, id)`, look up the method that turns it back into an object. Populated at setup time. |
| `kb-handle-internal-X-method` (one per type) | Each returns `(values TYPE-KW ID)` for an object of its type — e.g. `kb-handle-internal-constant-method` returns `(values :constant id)`. The wrapper functions `kb-handle` and `kb-handle-internal` (both stripped) would have done the dispatch; with the type table inert, callers must use `typecase` directly. |
| `register-find-object-by-kb-handle-method` | Push-or-replace registration for the reverse-direction alist. |
| `possibly-clear-genl-pos` | A stub returning `:checked`. The real body (stripped) cleared a genl-pos cache during after-adding. Preserved as a no-op so the cache invalidation hooks fire without error. |

The 25-odd commented stubs at the bottom (`kill-proprietary-constants`, `try-assert`, `try-unassert`, `string-to-formula`, `find-or-create-nart-from-text`, etc.) are user-facing convenience wrappers that the LarKC strip removed. Their names are preserved as a spec; they are *not* internal infrastructure but rather the kind of "easy assertion API" that a KB-editor would build on.

## When does each piece come into play?

### Startup pipeline (`system-code-initializations`)

The entry point fires **once per image start**, called by `secure-translation.lisp` (which sets up the API surface and is itself the early bootstrap target). The phase ordering is fixed:

1. `initialize-cyc-product` — bootstrap product-identity flags.
2. `system-code-image-initializations` — image-distinct state: random seed, start time, image ID, machine bogomips, TCP server validation, OS process tracking. These are the things that vary between an image-snapshot's saver and its loader.
3. `system-code-hl-initializations` — disable HLMTs (the HL microtheory system, lazy-init), initialize SBHL modules.
4. `system-code-inference-initializations` — reclassify removal modules, reclassify HL storage modules, destroy any leftover problem stores, initialize the PAD (pattern-associated-data) table.
5. `system-code-api-initializations` — reset the Java API kernel (a no-op in the port; left because the call exists).
6. (Optional) `system-code-application-initializations` — clear the asked-query queue. Skipped if the caller passes `nil`.
7. (If `(kb-loaded)` is positive) `system-kb-initializations` — initialize HL-store caches, set the cyclist, initialize transcript handling, initialize the agenda, initialize global locks, run cyc-testing initializations, initialize KCT (KB content tests), kick off file-backed cache initialization on a background thread, sleep half a second.

Each phase is a **gathering point** for cross-cutting initializers. Files all over the codebase add their own initializer to one of these phases by either (a) defining a `register-X` form that adds them to a shared registry consumed during the phase, or (b) simply being called directly by the phase function above. The structure is *not* declarative — `system-code-hl-initializations` literally hard-codes `(initialize-sbhl-modules)`, so adding a new HL initializer means editing this file. The TODO at line 44 explicitly flags this: "it makes more sense for loaded code to register its initializers, than to have to bake in all these calls here."

`*system-code-initializations-marker*` is set to the current process ID at the end. The companion `system-code-initializations-run-p` (stripped) would compare that marker against the current PID — non-equal → "we're in a different process than the one that ran initializations, re-run them." This is how a `.image` save/load handles re-init: the saved marker is the saving process's PID; the loading process has a different PID so the check fails and re-init runs.

### HL-store cache initialization

`initialize-hl-store-caches` is called from `system-kb-initializations` (above). It checks `hl-store-content-completely-cached?` (currently mostly missing-larkc — only `deduction-content-completely-cached?` actually has a body) and, if not, calls `initialize-hl-store-caches-from-directory` which initializes one cache per major KB-object type:
- Deduction
- Assertion
- Constant index
- NART index
- NART HL formula
- Unrepresented-term index
- KB-HL-support
- SBHL graph caches
- TVA cache registry

The directory comes from `*hl-store-caches-directory*` (set explicitly via `set-hl-store-caches-directory`, with a warning if absolute). The directory is the on-disk swap location for the file-backed caches that the LRU object managers use ([kb-access/kb-object-manager.md](../kb-access/kb-object-manager.md)).

### KB-handle dispatch

The `kb-handle` mechanism is the **uniform identity protocol** for KB objects. Every constant, NART, variable, assertion, and deduction can be turned into a `(:type id)` pair via `kb-handle-internal`, and reconstituted via `find-object-by-kb-handle`. The five per-type methods (one each for constant/NART/variable/assertion/deduction) are the dispatch leaves. Used wherever code needs to refer to a KB object across an image boundary or in a serializable structure — e.g. encapsulation, transcript output, RPC.

The per-type methods are *defined* in this file but the dispatch wrappers (`kb-handle`, `kb-handle-internal`, `find-object-by-kb-handle`) are stripped. In SubL the dispatch was via the type-tag table; in CL a clean rewrite would use `typecase` or `defgeneric`.

The reverse-direction alist is populated at file load:
```
:constant → find-constant-by-internal-id
:nart     → find-nart-by-id
:variable → find-variable-by-id
:assertion → find-assertion-by-id
:deduction → find-deduction-by-id
```

These are the five primary KB object types that participate in cross-image identity. Microtheories, EL variables, and HL-supports are *not* in this set — MT and EL var are constants/symbols (they pass through trivially), and HL-support uses its own GUID-based identity (see [persistence/encapsulation.md](../persistence/encapsulation.md)).

### `:uninitialized` sentinel pattern

`*machine-bogomips*` starts as `:uninitialized` (a deflexical default). On first call to `(machine-bogomips)`, the test `(eq :uninitialized *machine-bogomips*)` triggers a one-shot computation and caches the result. The same pattern is used throughout the codebase wherever lazy initialization is needed and `nil` is a meaningful "not available" value. `clear-machine-bogomips` resets to `:uninitialized` (called during `system-code-image-initializations` so a saved image re-measures on the new machine).

The `uninitialized` / `uninitialized-p` / `initialized-p` trio is the API surface. Consumers include:
- `at-macros.lisp` — AT (arg-type) variable defaults.
- `at-defns.lisp` — DEFN-stack lazy init.
- `kb-object-manager.lisp` — content slot lazy init.
- `sbhl-link-methods.lisp` — non-FORT isa/instance tables.

Two callers (TVA, GHL, SBHL link iterators) use `other-binary-arg` for the same idiom: "I have an index argument number; what's the *other* one?" Always 1↔2 because Cyc's binary predicates have args 1 and 2.

### `scale-by-bogomips`

The pattern: a benchmark on machine X observed a "good" timing of N seconds. To translate that budget to machine Y, multiply N by `bogomips_X / bogomips_Y`. Faster Y → smaller budget; slower Y → larger budget. `nil` bogomips → no scaling.

Used by inference time budgets — the strategist computes a "this query should take ~T" budget and scales it to the current machine before enforcing.

## Cross-cutting consumers

`misc-utilities.lisp`:
- `system-code-initializations` is called from `secure-translation.lisp`'s startup orchestration — it's *the* image-init entry point.
- `other-binary-arg` is hot-path code in GHL/TVA/SBHL search.
- `uninitialized`/`uninitialized-p`/`initialized-p` are scattered across ~10 files for lazy-init patterns.
- `scale-by-bogomips` is called from the inference-datastructures and system-benchmarks.
- `warn-unless` is used in a handful of file-loader and tolerant-init paths.

`misc-kb-utilities.lisp`:
- `kb-handle-internal-X-method` functions are called from any code that needs a KB-object → `(type, id)` reduction. With the dispatch table inert, callers `typecase` directly.
- `register-find-object-by-kb-handle-method` registrations populate the alist consumed by the (stripped) `find-object-by-kb-handle`. The alist is dead in the port but the registrations land in case the dispatcher gets ported back.
- `possibly-clear-genl-pos` is called from after-adding hooks for predicates that affect `genl-pos?`. The no-op body is harmless.

## Notes for a clean rewrite

- **The startup pipeline should be declarative, not hand-coded.** Replace `system-code-X-initializations` with a registry: each subsystem registers `(define-init-step :phase :hl :priority 100 (lambda () ...))` and the orchestrator topologically sorts and runs them. The current hand-coded ordering means adding an SBHL initializer requires editing this file, which is a common cross-cutting headache.
- **`*system-code-initializations-marker*` is image-snapshot defensive code.** If the rewrite drops save-image / load-image (modern Cyc would use a fresh-load model), the marker is unnecessary. If save/load is preserved, prefer SBCL's `sb-ext:*save-hooks*` / `*init-hooks*` over a homegrown PID check.
- **`*hl-store-caches-directory*` should not be a global.** It's a per-image config, but it's read and written by ~5 different files. A clean rewrite should pass the cache directory through an explicit context object (like a `kb-handle` or `kb-config` parameter) so multiple KBs can be loaded into one image — currently that's impossible.
- **Drop the `*kb-handle-internal-method-table*` entirely.** It's an inert vector that exists because the SubL dispatch model used type-tag indexing. CL has `typecase` and `defgeneric`; use one. The five per-type methods become methods on a generic function, the alist becomes the `defmethod` dispatch.
- **The `:uninitialized` sentinel is genuinely useful and worth keeping.** A clean rewrite should formalize it as a reusable type (e.g. `(deftype lazy-initialized (T) '(or T (eql :uninitialized)))`) with a macro `(let-lazy ((var INIT-EXPR)) BODY)` that hides the dispatch.
- **`other-binary-arg` is the hottest path.** `(logxor arg 3)` would compute it without the case dispatch (1 XOR 3 = 2; 2 XOR 3 = 1). The TODO in the source notes this. Do the optimization in the rewrite, but only for binary predicates (which is the only context).
- **`machine-bogomips` from `/proc/cpuinfo` is Linux-specific and outdated.** Bogomips is a 90s-era CPU-speed proxy that modern OSes don't really export meaningfully. A clean rewrite should benchmark a representative workload at startup and use that as the scaling factor — actual measurement, not an OS-reported number.
- **`*kb-content-copyright-notice*` should be deleted, or moved to a central legal-notices module.** It's dead code; the LarKC distribution doesn't use it. If the rewrite is open-source under AGPL (per the file headers), the Cycorp boilerplate is no longer applicable — the AGPL terms govern.
- **`possibly-clear-genl-pos`'s `:checked` return is opaque.** If the after-adding hooks check the return value, document what `:checked` means; if not, return `nil`. The function exists only because callers expect *something*; clean it up.
- **Split `misc-utilities` into three files** in the rewrite: (1) startup pipeline, (2) the `:uninitialized` sentinel, (3) machine-speed measurement. They have distinct lifecycles and consumers; co-locating them is purely historical.
- **Split `misc-kb-utilities`** into the kb-handle dispatch (which is real infrastructure) and the convenience wrappers (which are user-facing API). The current grouping conflates infrastructure with sugar.
