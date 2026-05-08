# Builder utilities

`builder-utilities.lisp` is the **build-time and image-startup configuration layer**: identifying which Cyc product is running, configuring SBHL caching policies for the loaded KB, and orchestrating world-building (transcript catchup, image writing). The "builder" in the name refers to *building a Cyc image* — the offline process of loading the KB, applying tuning parameters, and writing out a runnable image.

The system is mostly missing-larkc in the LarKC port — most build-orchestration functions are stripped because LarKC images are built differently. What survives is the *runtime* part: product identification, caching-policy templates, and the SBHL-policy proposal functions.

The placement of this file in the canonicalization category is somewhat arbitrary (it doesn't really canonicalize anything). It's grouped here because the SBHL-caching-policy templates affect canonical-form lookups and KB indexing.

Source file: `larkc-cycl/builder-utilities.lisp` (241 lines)

## Cyc product identification

A *cyc product* is the four-tuple `(<cyc-product> <code-product> <kb-product> <branch-tag>)` identifying a specific build:
- **cyc-product** — high-level identifier (e.g. `:head`, `:research`, `:opencyc`)
- **code-product** — the code build (`:standard` typically)
- **kb-product** — the KB variant (e.g. `:full`, `:tiny`, `:opencyc`)
- **branch-tag** — version control tag ("head", "1.0", etc.)

```lisp
(defparameter *all-cyc-products* nil)              ; list of cyc-product keywords
(defparameter *cyc-product-definitions* nil)       ; list of (cyc-product code-product kb-product branch-tag)
(defglobal *cyc-product* nil)                       ; current image's product
(defconstant *code-product* :standard)              ; this code build
(defglobal *kb-product* nil)                        ; set at KB load time
(defconstant *branch-tag* "head")                   ; this code branch
```

### Declaring products

```lisp
(declare-cyc-product cyc-product code-product kb-product branch-tag)
```

Registers a new product definition. Errors if:
- The exact same definition already exists (warning only)
- A *different* product already has this (code, kb, branch) tuple
- A different definition already exists for this `cyc-product` keyword

The toplevel form:
```lisp
(toplevel
  (register-external-symbol 'cyc-build-world-verify)
  (declare-cyc-product :head :standard :full "head"))
```

So one product is pre-declared: `(:head :standard :full "head")`. This is the LarKC default product.

### Looking up products

```
(cyc-product-definition-present? cyc-product code-product kb-product branch-tag)
  → t/nil; is this exact 4-tuple present?

(find-cyc-product code-product kb-product branch-tag)
  → cyc-product or nil; reverse lookup

(detect-cyc-product)
  → cyc-product or nil; based on current code-product, kb-product, branch-tag

(initialize-cyc-product)
  → set *cyc-product*; called at image startup
```

`initialize-cyc-product` runs `detect-cyc-product` and either sets `*cyc-product*` to the detected value or to `:unknown-cyc-product` if none matches.

### Public accessors

```
(cyc-product)        → *cyc-product*
(code-product)       → *code-product*
(kb-product)         → *kb-product*
(branch-tag)         → *branch-tag*
(set-cyc-product p)  → set and return
```

Used by code that gates behaviour on the product (e.g. "this feature is only enabled for `:research` builds").

## SBHL caching policy templates

`*generic-sbhl-caching-policy-templates*` is the *production-tuned* default caching policies for SBHL graph traversal:

```lisp
(list
  (specify-sbhl-caching-policy-template :default :sticky :undefined :all)
  (specify-sbhl-caching-policy-template #$genlMt :sticky :undefined :all :all)
  (specify-sbhl-caching-policy-template #$genlPreds :swapout 500 500 200)
  (specify-sbhl-caching-policy-template #$negationPreds :swapout 500 100 0)
  (specify-sbhl-caching-policy-template #$disjointWith :swapout 500 500 200)
  (specify-sbhl-caching-policy-template #$genlInverse :swapout 500 500 200)
  (specify-sbhl-caching-policy-template #$negationInverse :swapout 500 100 0)
  (specify-sbhl-caching-policy-template #$genls :swapout 5000 5000 2000)
  (specify-sbhl-caching-policy-template #$isa :swapout 10000 8000 2000)
  (specify-sbhl-caching-policy-template #$quotedIsa :swapout 5000 4000 1000))
```

Each template is `(link-predicate policy capacity exempts prefetch)`:
- `link-predicate` — the SBHL link (`#$genls`, `#$isa`, `#$genlMt`, etc., or `:default`)
- `policy` — `:sticky` (never swap out) or `:swapout` (LRU)
- `capacity` — max entries; `:undefined` for unbounded
- `exempts` — number of "exempt" entries that won't be swapped
- `prefetch` — number to prefetch on first miss; `:all` for full prefetch

The defaults reflect production tuning:
- `:default` is sticky, full prefetch (most-stable case)
- `#$genlMt` is sticky too (MT graph is small, doesn't change)
- `#$isa` has the largest cache (10000 entries) — most-queried
- `#$genls` is second-largest (5000)
- Quoted-isa, genl-preds, etc. are smaller (500-5000)

### Constructor

```lisp
(specify-sbhl-caching-policy-template link-predicate policy capacity &optional (exempts 0) (prefetch 0))
  → (link-predicate policy capacity exempts prefetch)
```

Just constructs the 5-element list.

### Policy proposal generators

`get-all-sbhl-module-link-predicates()` — return all SBHL link predicates registered in the engine.

`propose-all-sticky-kb-sbhl-caching-policies(link-predicates, with-prefetch-p)`:
For each link predicate, create a `:sticky` policy with `:undefined` capacity. If `with-prefetch-p`, prefetch all on first miss.

```lisp
(propose-legacy-kb-sbhl-caching-policies &optional link-predicates)
  ; "Generate a KB SBHL caching policy proposal that reflects the state of the
  ;  the system before the introduction of swap-out support--i.e. all modules
  ;  are handled as sticky and nothing is pre-fetched."
  (propose-all-sticky-kb-sbhl-caching-policies link-predicates nil))
```

The "legacy" proposal makes everything sticky with no prefetch — the pre-swap-out behaviour. Useful for benchmarking the impact of swap-out vs. legacy.

Other proposers are missing-larkc:
- `generate-kb-sbhl-caching-policies(arg1, arg2, &optional arg3)` — generate based on KB size and tuning data
- `generate-legacy-kb-sbhl-caching-policies(arg1, &optional arg2)` — legacy version
- `generate-completely-cached-kb-sbhl-caching-policies(arg1, &optional arg2)` — opposite extreme: cache everything
- `propose-kb-sbhl-caching-policies-from-tuning-data(arg1, &optional arg2)` — proposal from empirical tuning data
- `propose-completely-cached-kb-sbhl-caching-policies(&optional arg1)` — propose the everything-cached variant

The naming convention: `generate-*` produces policies for one specific KB; `propose-*` produces a *recommendation* for the user.

## Build-time orchestration (mostly missing-larkc)

These are the offline-build operations:

### World building

- `cyc-build-world(name, options)` — main world-building entry
- `cyc-build-world-verify(name, options)` — same with verification
- `verify-cyc-build()` — verify the current image
- `close-old-areas()` — release deprecated KB areas

### Image writing

- `build-write-image(filename)` — write the current image to disk
- `build-write-image-versioned(filename)` — versioned filename
- `cyc-versioned-world-name()` — compute the versioned filename
- `cyc-install-directory-name(...)`, `cyc-install-directory(...)` — install path computation
- `builder-log-directory()` — where build logs go
- `builder-forward-inference-metrics-log()` — forward-inference timing log

### Transcript catchup

- `catchup-to-rollover-and-write-image(...)` — catch up to KB rollover and write
- `catchup-to-rollover()` — catch up only
- `catchup-to-rollover-setup()` — preparation
- `load-submitted-transcripts-and-write-image(...)` — load + write
- `catchup-to-current-and-write-image-versioned(...)` — versioned variant
- `catchup-to-current-and-write-image(...)` — non-versioned
- `catchup-to-current-kb()` — catch up only

The `catchup-to-rollover` family is what turns a master-transcript-driven KB into a runnable image: load all transcripts since the last rollover, apply them, write the resulting image.

### Fact sheets

- `enumerate-fact-sheets-for-kb-to-file(filename)` — write fact sheets for all relevant terms
- `enumerate-fact-sheets-for-kb(&optional filter)` — same without file
- `fact-sheet-path-for-term-filter-and-transform(args)` — compute path

A *fact sheet* is a per-term summary: the term plus its asserted properties. Used for documentation and debugging.

### KB clipping

- `select-clippable-collections(&optional ...)` — find collections eligible for clipping
- `gather-tabu-collections-for-clipping(...)` — find collections that *cannot* be clipped
- `clip-kb-percentage(percentage, ...)` — clip the KB to retain only a percentage of nodes
- `clip-kb-given-tabu-term-list(tabu-list)` — clip while preserving the tabu list
- `higher-order-collection?(collection)` — predicate for higher-order collections (always tabu)

KB clipping is a build-time operation: produce a *smaller* KB by removing low-value content while preserving high-value content. Used to produce variants like `cyc-tiny`.

### KB mini-dump

- `get-kb-mini-dump-timestamp()` — timestamp for the dump
- `prepare-kb-mini-dump()` — preparation phase
- `perform-kb-mini-dump(filename)` — actual dump
- `launch-asynchronous-kb-mini-dump(filename)` — async variant
- `mark-kb-mini-dump-as-successful(filename)` — completion marker

A "mini dump" is a smaller, faster image-write that only captures the essential KB state. Used for periodic snapshots without the full image-write overhead.

### SBHL cache tuning

- `gather-data-for-sbhl-cache-tuning(test-list)` — collect tuning data
- `run-sbhl-cache-tuning-data-gathering(test-list)` — run the tests
- `sbhl-cache-tuning-data-gathering-prologue()` / `…-epilogue()` — setup/teardown
- `sbhl-cache-tuning-experiment-prologue()` / `…-epilogue(experiment)` — per-experiment
- `sbhl-cache-tuning-data-gathering-generate-report(data, file)` — produce report

`*cyc-tests-to-use-for-sbhl-cache-tuning*` and `*kb-queries-to-use-for-sbhl-cache-tuning*` are configuration: which tests/queries to use for tuning.

`*run-cyclops-for-sbhl-cache-tuning?*` — when t, also run the CycLOPS benchmark.

The tuning workflow:
1. Run the test suite with default policies
2. Gather hit/miss/swap statistics per link-predicate
3. Generate a tuned set of caching policies
4. Re-run with the tuned policies; verify improvement
5. Persist the tuned policies as the new defaults

## When does each piece fire?

| Operation | Trigger |
|---|---|
| `initialize-cyc-product` | Image startup, after KB load |
| `*generic-sbhl-caching-policy-templates*` consultation | SBHL initialization |
| `propose-legacy-kb-sbhl-caching-policies` | When a build wants the legacy policy set |
| `cyc-build-world` | Offline build runs |
| `catchup-to-rollover` | Build-time KB sync |
| `clip-kb-*` | Build-time KB reduction |
| SBHL cache tuning | Periodic re-tuning runs |

## Cross-system consumers

- **Image startup** calls `initialize-cyc-product` to identify the build
- **SBHL** consumes `*generic-sbhl-caching-policy-templates*` for its initial policies
- **Build scripts** (offline) call `cyc-build-world`, `catchup-to-current-and-write-image`, etc.
- **Cache-tuning runs** consume `*cyc-tests-to-use-for-sbhl-cache-tuning*` and produce updated policies
- **KB clipping** for variant builds uses `select-clippable-collections` and `clip-kb-percentage`

## Notes for the rewrite

- **The product-identification machinery is small and clean.** Keep it; downstream code legitimately needs to know "am I running OpenCyc, ResearchCyc, or something custom?"
- **`(declare-cyc-product :head :standard :full "head")`** is the only registered product in the LarKC distribution. The clean rewrite should declare any new products explicitly via this mechanism.
- **`*generic-sbhl-caching-policy-templates*` is empirically tuned.** The numbers (10000 for isa, 5000 for genls, 500 for genlPreds, etc.) reflect production performance. Don't change without benchmarking.
- **`#$genlMt` is sticky** because the MT graph is small and queried constantly. Other links can swap out. Keep this distinction.
- **`:swapout` policies have prefetch counts.** Higher prefetch reduces miss latency at the cost of memory. The defaults (200-2000) are tuned for a typical image; adjust per-deployment if needed.
- **`propose-legacy-kb-sbhl-caching-policies` is a benchmarking tool.** Lets you measure "what happens if I disable swap-out?" Useful for regression testing the swap-out code path. Keep it.
- **Most build-time functions are missing-larkc.** The clean rewrite needs to decide:
  - Is this rewrite going to support *image building*? If yes, reconstruct the build pipeline (cyc-build-world, catchup, write-image).
  - If no, drop these functions; the rewrite assumes someone else builds the image.
- **The transcript-driven build process** is Cyc-specific. The rewrite may want to use a different mechanism (e.g. Lisp `save-image` directly, or a containerised build).
- **KB clipping** is a real feature: produce smaller KB variants for resource-constrained deployments. Keep this if you ship multiple KB sizes.
- **`*run-cyclops-for-sbhl-cache-tuning?* = nil`** with comment "@hack Currently not implemented." CycLOPS is a benchmark suite. The clean rewrite should either implement it or remove the flag.
- **`*kb-queries-to-use-for-sbhl-cache-tuning* = nil`** also "@hack Currently not implemented." Same comment.
- **The fact-sheets functionality is documentation generation.** Keep it if documentation matters; otherwise drop.
- **`set-kb-product`** is missing-larkc. The clean rewrite must implement; called at KB load time to set `*kb-product*`.
- **`*branch-tag* = "head"`** as a `defconstant` means it can't be changed at runtime. The build process must change it via build-time code generation. This is correct; don't make it a defparameter.
- **`*code-product* = :standard`** likewise constant. Build-time code generation can change it to e.g. `:research` for a different build.
- **`register-external-symbol 'cyc-build-world-verify`** registers the build entry as part of the public API. Keep this; build automation depends on it.
