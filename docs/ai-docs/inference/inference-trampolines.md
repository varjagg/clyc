# Inference trampolines

A *trampoline* is a thin wrapper around a lower-level KB function that adds inference-context machinery: memoisation, MT relevance, SBHL marking-space binding, type-checking suspension, recursion-stack tracking. The same logical question gets asked in two contexts:

- **Without inference context:** `transitive-binary-predicate-p(predicate)` — pure KB lookup
- **With inference context:** `inference-transitive-predicate?(predicate)` — same question, but inside the inference-MT relevance frame, with appropriate caching

This file (549 lines) collects the inference-context wrappers. Most are 2-3 line functions; the substance is in the underlying KB lookup. The doc covers what's wrapped and why.

Source file: `larkc-cycl/inference/inference-trampolines.lisp`

## Why trampolines?

Two reasons:

1. **MT relevance.** A `genls` lookup means different things depending on which MT relevance frame is active. The trampoline binds the right MT frame before delegating. Without it, every caller would have to set up `*mt*`, `*relevant-mt-function*`, and `*relevant-mts*` manually.

2. **Memoisation.** The inference engine asks the same predicate-property question many times within a single inference. Trampolines cache results in `defun-memoized` forms keyed by the relevant inputs. The cache is per-image (or per-strategy memoization-state); cleared on KB change via `:clear-when :hl-store-modified`.

3. **SBHL marking-space scoping.** SBHL searches use marking spaces that should be scoped to the current inference. Trampolines wrap the SBHL primitives in `with-inference-mt-relevance` and the resourced-marking-spaces context.

4. **Type-checking suspension.** Some SBHL searches need to bypass type checks (e.g. when checking commutativity of a non-FORT predicate). Trampolines bind `*suspend-sbhl-type-checking?* = t` for the inner call.

## Categories of trampoline

### Type-of-term predicates

Wrapping pure FORT-type queries in inference-context aliases:

| Trampoline | Underlying |
|---|---|
| `inference-collection?(object &optional mt)` | (combination of) `fort-p`, `collection?`, `isa? object #$Collection mt` |
| `inference-predicate-p(object)` | `fort-p` AND `predicate?` |
| `inference-commutative-relation?(relation)` | `commutative-relation-p` |
| `inference-symmetric-predicate?(predicate)` | `symmetric-binary-predicate-p` |
| `inference-commutative-predicate-p(predicate)` | `commutative-predicate-p` |
| `inference-partially-commutative-predicate-p(predicate)` | `partially-commutative-predicate-p` (memoised eq) |
| `inference-at-least-partially-commutative-predicate-p(predicate)` | OR of the above two |
| `inference-transitive-predicate?(predicate)` | `transitive-binary-predicate-p` |
| `inference-evaluatable-predicate?(predicate)` | `evaluatable-predicate?` |
| `inference-reflexive-predicate?(predicate)` | `reflexive-binary-predicate-p` |
| `inference-irreflexive-predicate?(predicate)` | `irreflexive-binary-predicate-p` |

These are essentially renames — the trampoline name advertises "this is the inference engine's view." The underlying KB function is the same. Most don't add caching (the underlying is already fast); a few add `defun-memoized` for hot paths.

`inference-collection?` is the one that actually does work: it accepts both `fort-p` collections and `possibly-naut-p` term expressions, dispatching appropriately.

### Indeterminate-term checking

`inference-indeterminate-term?(value)` — is this term *indeterminate* (i.e. its identity is uncertain, like a skolem)? Dispatches:
- FORT: `indeterminate-term-p(value)` (defun-cached, eq, cleared on `:hl-store-modified`)
- NAUT: either the operator is a known indeterminate-denoting function, or `memoized-inference-indeterminate-term?(value)` (defun-memoized equal)
- else: nil

The cache is critical because indeterminate-term-checking happens on every binding the engine produces — without caching it would be a serious bottleneck.

### Genl/spec-pred reachability

`inference-some-genl-pred-or-inverse?(pred)` — is there at least one genl-pred or inverse for this predicate? Wraps `some-genl-pred-or-inverse?` with `*suspend-sbhl-type-checking?* = t`.

`inference-some-spec-pred-or-inverse?(pred)` — fast path: first check `some-spec-predicate-or-inverse-somewhere?` (cheap), then do the SBHL check only if there might be one.

`inference-all-spec-predicates(predicate)` — wraps `all-spec-predicates(predicate, nil)` with the fast-path check. Memoised via `inference-all-spec-predicates-int` (eq).

`inference-all-spec-inverses(predicate)` — same pattern.

`inference-all-proper-spec-predicates-with-axiom-index(pred, sense)` — returns two values: list of proper specPreds with relevant rule index, plus total rule count. The `-int` is memoised. The `-int-internal` is a 150-line inline expansion of an SBHL backward search over `#$genlPreds` — the SBHL machinery's API doesn't compose cleanly so the search is open-coded. (One of the larger missing-larkc reconstructions.)

### MT bookkeeping

`inference-some-max-floor-mts(mts)` — does the MT set have a max-floor MT? Asks via `some-max-floor-mts?-cached` which is a defun-cached with explicit clearing (because `defun-cached :clear-when :hl-store-modified` only handles the standard clearing path; this needs `:hl-store-modified` and `:strategy-mt-change` semantics).

The pattern:
```lisp
(defvar *some-max-floor-mts?-cached-caching-state* nil)

(defun clear-some-max-floor-mts?-cached () ...)

(defun some-max-floor-mts?-cached (mts) ...)
```

Same pattern for `inference-max-floor-mts-with-cycles-pruned` (and its `-cached` variant): given a set of MTs, prune cycles via the genl-mt graph and return the max-floor set.

### Backchain control

A cluster of memoised predicates that determine whether backchaining should happen for a given predicate/MT/collection combination:

| Function | Purpose |
|---|---|
| `inference-backchain-required-asent?(asent, mt)` | Should this asent require backchaining? |
| `inference-backchain-required-contextualized-asent?(contextualized-asent)` | Same, contextualized version |
| `inference-some-backchain-required-asent-in-clause?(clause)` | Does any literal in this clause require backchain? |
| `inference-predicate-backchain-required?(predicate, mt)` (memoised eq) | Predicate-level: does its definition require backchain? |
| `inference-backchain-forbidden?(predicate, mt)` (memoised eq) | Predicate-level: is backchain forbidden for it? |
| `inference-collection-backchain-required?(col, mt)` (memoised eq) | Collection-level |
| `inference-collection-isa-backchain-required?(col, mt)` (memoised eq) | Collection-level for isa |
| `inference-collection-genls-backchain-required?(col, mt)` (memoised eq) | Collection-level for genls |
| `backchain-control-mt(mt)` | The MT to use for backchain-control queries (always the genl-mt closure) |
| `problem-backchain-required?(problem)` | Problem-level: does the problem require backchain? |

These predicates are consulted by every transformation tactic determination — without memoisation, the engine would re-run the same KB query thousands of times per inference.

### MT relevance

`inference-relevant-mt?(assertion-mt, &optional inference-mt)` — given an assertion's MT and the current inference's MT, is the assertion relevant? Delegates to the MT relevance system.

`inference-irrelevant-mt?` — opposite.

The inference-mt argument is optional because the trampoline can read it from the dynamic context (`*inference-mt*` or similar). When called with explicit inference-mt, no dynamic lookup.

### KB lookup wrappers

| Trampoline | Purpose |
|---|---|
| `inference-gaf-lookup-index(asent, sense)` (memoised equal) | Get the GAF lookup index for an asent |
| `inference-num-gaf-lookup-index(asent, sense)` (memoised equal) | Number of GAFs in the lookup |
| `inference-relevant-num-gaf-lookup-index(asent, sense, mt)` (missing-larkc) | Per-MT count |
| `inference-key-gaf-arg-index(v-term, &optional argnum predicate)` (missing-larkc) | Key GAF arg index |

The macro `do-inference-gaf-lookup-index((assertion-var asent sense …))` wraps `do-gaf-lookup-index` with the inference-context bindings.

### Recursive-ask wrappers

A pile of missing-larkc declarations:
- `inference-known-sentence-removal-query` / `…-recursive-query` — "is this sentence known to be true via removal-only inference?"
- `inference-true-sentence-recursive-query` — same with full backchain
- `inference-mts-where-gaf-sentence-true` — list MTs in which the GAF is asserted/derivable
- `inference-mts-where-gaf-sentence-true-justified` — same with justifications

`*inference-true-sentence-recursion-stack*` (defparameter, default nil) tracks the recursion to avoid cycles. `inference-true-sentence-recursion-cycle?(sentence)` checks the stack.

### Rule utility

| Trampoline | Purpose |
|---|---|
| `inference-rule-has-utility?(assertion, &optional mt)` (missing-larkc) | Is this rule useful per the historical statistics? |
| `inference-rule-utility(assertion, &optional mt)` (missing-larkc) | Utility score |
| `inference-rule-type-constraints-internal(assertion)` (missing-larkc) | Type constraints from the rule's bound variables |

### Backchain-encouraged variants (all missing-larkc)

`inference-collection-isa-backchain-encouraged?`, `inference-collection-genls-backchain-encouraged?`, `inference-collection-backchain-encouraged?` — softer than "required"; "encouraged" means the engine should try harder but isn't forced.

### Sentence-property queries (missing-larkc)

| Trampoline | Purpose |
|---|---|
| `inference-applicable-sdct?(collection)` | Is the collection an SDCT (some kind of definitional collection)? |
| `inference-relevant-assertion?` | Per-assertion relevance |
| `inference-relevant-predicate-assertion?` | Per-predicate relevance |
| `inference-relevant-term?` | Per-term relevance |

### `determine-sentence-recursive-query-properties` (missing-larkc)

Given a sentence and MT, compute the appropriate query-properties for a recursive query. Walks the sentence determining backchain depth, MT relevance, etc.

## Memoisation patterns

The trampolines use three memoisation patterns:

1. **`defun-memoized`** — input-keyed cache, cleared on `:hl-store-modified`. The default pattern. `defun-memoized inference-X (...) (:test eq) ...`.

2. **`defun-cached`** with explicit clearing — when the underlying state is more complex than `:hl-store-modified` can handle. Pattern: `defvar *X-caching-state* nil; defun clear-X (); defun X (...)`. Used for `some-max-floor-mts?-cached` and `inference-max-floor-mts-with-cycles-pruned-cached`.

3. **`defun-cached :clear-when :hl-store-modified`** — eq-keyed, cleared on KB change via the standard hook. Used for `indeterminate-term-p`.

The clean rewrite should standardise these. The third pattern (declarative clear-when) is the cleanest; the second is a workaround for cases the default doesn't cover. The clean rewrite should extend the default to cover those cases.

## When does each piece fire?

These trampolines are *deeply consumed*. Almost every inference pathway calls some of them:

| Caller | Trampolines used |
|---|---|
| Removal modules | predicate-property predicates (transitive, symmetric, commutative) for type-specific dispatch |
| Transformation modules | backchain-required, predicate-backchain-required, collection-backchain-required for rule applicability |
| Workers | gaf-lookup-index, indeterminate-term? for proof construction |
| Strategist | relevant-mt? for MT scoping in tactic determination |
| Argumentation | mts-where-gaf-sentence-true for support computation |
| Forward inference | some-genl-pred-or-inverse? for rule-relevance precheck |
| Canonicalization | inference-at-least-partially-commutative-predicate-p for sort key |

## Cross-system consumers

Essentially every other inference file calls into trampolines.

## Notes for the rewrite

- **The trampolines exist to provide an inference-aware view of pure KB lookups.** They are the boundary between "the KB" (read-only state) and "the engine" (inference-aware caching, MT scoping, recursion bookkeeping).
- **Most are 1-3 line wrappers.** Don't fight the size; the value is in the function-name documentation ("this is the inference-side view of X") and in the centralised caching.
- **Memoisation strategy must be consistent.** Most use `defun-memoized` with `:test eq`. Some need `:test equal` for non-symbol keys. Some need explicit clearing. Pick one default; document the exceptions.
- **`:clear-when :hl-store-modified` is the standard cache-invalidation hook.** Make sure every trampoline that depends on KB state uses it (or the equivalent in the rewrite).
- **`*suspend-sbhl-type-checking?*`** is the bypass for SBHL type-checks during predicate property lookups. Without it, asking "is this predicate transitive?" on a predicate with no SBHL type info would error. Keep this dynamic special.
- **`*inference-true-sentence-recursion-stack*` is essential.** Without it, recursively answering "is sentence X true?" can infinite-loop when X transitively requires Y which requires X. Keep the stack check.
- **The `inference-all-proper-spec-predicates-with-axiom-index-int-internal` open-coded SBHL search** is a port-time accident — the SBHL API doesn't compose well so the search is inlined. The clean rewrite should refactor SBHL to expose a compositional iterator.
- **The "internal vs. external" naming convention** — `X` vs. `X-internal` vs. `X-int` — is inconsistent in the LarKC port. The rewrite should pick one (suggest: `X` is the public, `_X` or `X.impl` is the internal).
- **Many missing-larkc** functions in this file are critical for inference: `determine-sentence-recursive-query-properties`, `inference-rule-utility`, `inference-known-sentence-recursive-query`. The rewrite must reconstruct them. The signatures and contracts are documented in the declareFunction comments.
- **The `inference-mts-where-gaf-sentence-true-*` family** is the API for "in which MTs is this sentence true?" Used by argumentation for justification construction. Implement carefully — the wrong answer changes which MTs the proof is attached to.
- **Trampolines don't own the state — the underlying KB does.** The trampoline only adds caching. Keep this discipline; don't accumulate state in the trampoline layer.
- **Inferring everything inline in trampolines is not acceptable.** A trampoline should be a thin wrapper. If a wrapper needs more than 5-10 lines, the underlying KB function is wrong, not the wrapper.
