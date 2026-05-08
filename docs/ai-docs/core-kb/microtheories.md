# Microtheories (MT)

A **microtheory** is a partition of the KB that can be independently scoped in or out of inferential visibility. Every assertion lives in exactly one MT; every query runs *relative to* an MT and inherits visibility into that MT and its parents (via `#$genlMt`). The MT lattice is how Cyc lets contradictory information coexist (assertions valid in one context but not in another), how it imposes scoping on default rules, and how it segregates the engine's own bookkeeping (`#$BaseKB`, `#$UniversalVocabularyMt`) from domain knowledge.

The MT subsystem is layered:

- **Plain monad MTs**: a FORT (constant or NART) that *is* a microtheory because `(isa MyMt #$Microtheory)` holds. Most MTs in the KB are this — `#$BaseKB`, `#$BiologyMt`, `#$EnglishMt`, etc.
- **HLMTs (Heuristic Level Microtheories)**: NAUT-shaped MTs constructed from dimensional context functions like `(MtSpace MyMonad TimeDim)`. A way to project a single MT through orthogonal dimensions (time, monad, …) so an assertion can be lifted to "in MyMonad as of TimeDim".
- **MT relevance**: the dynamic-scope mechanism that says "for the duration of this evaluation, treat MT X and its genls as in-scope, everything else as out-of-scope". Implemented via `*mt*` and `*relevant-mt-function*` plus a family of macros (`with-mt`, `with-all-mts`, `with-just-mt`, `with-inference-mt-relevance`, `possibly-in-mt`, `possibly-with-just-mt`).
- **PSCs (Problem-Solving Contexts)**: special-purpose MTs that bypass the genlMt lattice. `#$EverythingPSC` opens visibility to every assertion regardless of MT; `#$InferencePSC` allows any MT to satisfy an inference; `#$AnytimePSC` strips the time dimension. Selecting a PSC as the relevance MT switches the relevance function from genlMt-based to a wider-cast variant.
- **MT vocabulary**: a fixed set of "where-do-X-assertions-go" globals that hard-code the metatheory location of various kinds of metadata. `*tou-mt*` is where `#$termOfUnit` GAFs land, `*arity-mt*` is where `#$arity` assertions go, `*mt-mt*` is where MT-isa assertions go, etc. Roughly 25 such globals.

## When does an MT come into being?

MTs are FORTs (or NAUT formulas built from FORTs), so they come into being the same way any other FORT does — see [constants.md](constants.md#shell-birth) and [narts.md](narts.md). What makes a FORT *also* an MT is the presence of an `(isa fort #$Microtheory)` GAF in `*mt-mt*`. There is no separate "create-mt" pipeline; the MT-ness is a typing fact like any other.

A FORT becomes an MT in three situations:

1. **An asserter declares it**. `(isa MyNewMt #$Microtheory)` is asserted in `*mt-mt*` (default `#$UniversalVocabularyMt`), and `mt?` immediately returns true for `MyNewMt`. From that point on, `MyNewMt` can be passed as the second arg to any assertion, and inference can be scoped relative to it.
2. **KB load**. `(isa X #$Microtheory)` GAFs read off the dump are processed like any other assertion; the MT vocabulary globals (`*mt-root*`, `*tou-mt*`, etc.) get re-bound to the FORTs that the dump's KB declares them as via the `note-mt-var-basis` mechanism (see below).
3. **An MT is constructed via NAUT-shape**. `(MtSpace MyMonad TimeDim)` is an HLMT — a non-atomic term that names a microtheory by composing dimensional context functions. The HLMT is canonicalized through `canonicalize-hlmt` (in `hlmt-czer.lisp`) and either reified into a NART (if the `MtSpace` functor is reifiable) or kept as a NAUT for transient use.

**MTs do not get a separate ID space.** They are identified by their FORT identity — for monad MTs that's just the constant or NART ID. HLMTs are identified by structural equality of their NAUT.

## When does an MT go out of existence?

Same as any FORT: `cyc-kill` on the FORT, which cascades to remove every assertion in or about it. The MT subsystem doesn't have a separate "demote-from-MT-status" path; you remove the `(isa MyMt #$Microtheory)` GAF (or you remove `MyMt` itself) and the MT-ness disappears as a side effect.

## The MT lattice — `#$genlMt` and the SBHL

MTs form a partial order under `#$genlMt`. `(genlMt SpecMt GenlMt)` reads as "anything true in `GenlMt` is also true in `SpecMt`". Inference scoped to `SpecMt` therefore visits `GenlMt`'s assertions, and `GenlMt`'s `GenlMt`s, and so on, transitively up to `#$BaseKB` (the root).

The lattice is implemented by the **SBHL** (Subsumption-Based HL) module under the `#$genlMt` predicate. `genl-mts.lisp` is mostly a thin layer of named entry points dispatching to `sbhl-all-forward-true-nodes`, `sbhl-non-justifying-predicate-relation-p`, `sbhl-min-nodes`, `sbhl-max-floors`, etc. The SBHL itself ([sbhl/](../../../larkc-cycl/sbhl/) — separate doc) handles the graph traversal and caching.

The wired-up entry points:

```
(all-genl-mts mt &optional mt-mt tv)        ; ascending transitive closure
(genl-mt? spec genl &optional mt-mt tv)     ; "is genl above spec?"
(proper-genl-mt? spec genl)                 ; strict ancestor (not equal)
(monad-genl-mt? spec genl)                  ; same, with-all-mts wrapper
(min-mts mts &optional mt-mt)               ; most-specific subset
(max-floor-mts mts &optional candidates mt-mt)  ; greatest lower bounds
(max-floor-mts-with-cycles-pruned ...)
(do-base-mts mt body...)                    ; macro: iterate base mts of mt
(add-genl-mt source assertion)              ; sbhl-after-adding
(remove-genl-mt source assertion)           ; sbhl-after-removing
```

About 50 declareFunctions in `genl-mts.lisp` are LarKC-stripped — `min-genl-mts`, `not-genl-mts`, `spec-mts`, `leaf-mt?`, `random-genl-mt`, `mts-intersect?`, `why-genl-mt?`, etc. The skeleton is intact (every `genlMt` query routes to the same SBHL module); the variants are stubs.

### Core MTs — the upper bound of the lattice

A small set of "core" MTs sits near the top of the genlMt graph:

```
#$LogicalTruthMt
#$LogicalTruthImplementationMt
#$CoreCycLMt
#$CoreCycLImplementationMt
#$UniversalVocabularyMt
#$UniversalVocabularyImplementationMt
#$BaseKB
```

`*core-mts*` is the ordered list (max → min); `*ordered-core-mts*` is an alist mapping each to a level number 0..3 (lower is higher in the lattice). These are recognized via `core-microtheory-p` and ordered via `core-microtheory-<` / `core-microtheory->`. The motivation for special-casing core MTs (`*core-mt-optimization-enabled?*` = T) is:

- They are visited by *every* relevance computation. Skipping the SBHL graph traversal for them is a significant speedup.
- They are constants, not subject to runtime change. The hard-coded total order is correct.

`minimize-mts-wrt-core` and `maximize-mts-wrt-core` are MT-set reducers that honor the core ordering — when a set contains both core and non-core MTs, the non-core ones win in `minimize` (they are properly-spec of the cores), and a single representative core wins in `maximize`.

`*special-loop-core-mts*` is `(#$UniversalVocabularyMt #$BaseKB)` — these have a self-loop in the `genlMt` graph that needs special handling (they are mutually genlMt of each other in the lattice's interpretation, even if not asserted). `core-genl-mt?` short-circuits the test for these.

## MT relevance — the dynamic scope

The pivotal pair:

```lisp
(defparameter *mt* *assertible-theory-mt-root*
  "[Cyc] A ubiquitous parameter used to dynamically bind the current mt assumptions.")
(defparameter *relevant-mt-function* nil)
```

Together they describe "for this dynamic scope, *which MTs count as relevant*". `*mt*` names the central MT; `*relevant-mt-function*` is a function symbol that decides, given any other MT, whether it's relevant. The pair drives every assertion-lookup and inference-step.

The relevance functions:

| Function | Predicate |
|---|---|
| `relevant-mt-is-eq` | `(hlmt-equal *mt* mt)` — only the bound MT counts |
| `relevant-mt-is-genl-mt` | `mt` is a genlMt of `*mt*`, or `*mt*` itself (the standard case) |
| `relevant-mt-is-any-mt` | `mt` is anything; used by `#$InferencePSC` |
| `relevant-mt-is-everything` | `mt` is anything; used by `#$EverythingPSC` |
| `relevant-mt-is-in-list` | `mt` is in `*relevant-mts*` (an MtUnion) |
| `relevant-mt-is-genl-mt-of-list-member` | `mt` is a genlMt of any member of `*relevant-mts*` |
| `relevant-mt-is-genl-mt-with-any-time` | genlMt match ignoring time dimension; for AnytimePSC |

`relevant-mt?` is the dispatcher: when `*relevant-mt-function*` is NIL, it defaults to `relevant-mt-is-genl-mt`. Otherwise it `case`s on the function symbol and calls the matching variant.

The wrapper macros:

| Macro | Effect |
|---|---|
| `(with-mt mt body)` | `*mt* = mt`, function = `relevant-mt-is-genl-mt` |
| `(with-genl-mts mt body)` | same as `with-mt` |
| `(with-all-mts body)` | `*mt* = #$EverythingPSC`, function = `relevant-mt-is-everything` |
| `(with-any-mt body)` | function = `relevant-mt-is-any-mt` |
| `(with-just-mt mt body)` | `*mt* = mt`, function = `relevant-mt-is-eq` |
| `(with-mt-list mts body)` | `*relevant-mts* = mts`, function = `relevant-mt-is-in-list` |
| `(with-inference-mt-relevance mt body)` | dispatches on `mt-inference-function mt` to pick the right relevance function (`with-all-mts` for `#$EverythingPSC`, `with-any-mt` for `#$InferencePSC`, etc.) |
| `(possibly-in-mt (mt) body)` | if `mt` is non-nil, run as `with-mt`; else inherit current scope |
| `(possibly-with-just-mt (mt) body)` | if `mt` is non-nil, run as `with-just-mt`; else inherit |

`with-inference-mt-relevance` is the most-used because it's PSC-aware. Most consumer call sites (canonicalization, kb-mapping, hl-supports) wrap their work in this macro because they're given an arbitrary MT and need the right relevance behavior.

The mt-inference-function dispatcher (`psc.lisp`):

```lisp
(defun mt-inference-function (mt)
  (cond ((eq mt #$EverythingPSC)            'all-mts-inference)
        ((eq mt #$InferencePSC)             'psc-inference)
        ((not (possibly-naut-p mt))         'normal-inference)
        ((mt-union-naut-p mt)               'mt-union-inference)
        ((hlmt-with-anytime-psc-p mt)       'anytime-psc-inference)
        (t                                  'normal-inference)))
```

This is consulted by `with-inference-mt-relevance` to set up the right `*relevant-mt-function*` for the duration of the body.

`inference-relevant-mt` is the read-back: given the current `*mt*` / `*relevant-mt-function*` state, return an MT that, if passed to `with-inference-mt-relevance`, would re-establish the same scope. Useful for recording the current relevance and re-installing it later.

## The MT relevance cache

Resolving `(genl-mt? spec genl)` for a non-core pair requires SBHL graph traversal. This is too expensive to do on every assertion lookup. The MT relevance cache (`mt-relevance-cache.lisp`) caches `(mt → genl-mts)` for monad MTs:

```lisp
(defglobal *monad-mt-fort-cache* (new-cache 256 #'eq))    ; for FORT MTs
(defglobal *monad-mt-naut-cache* (new-cache 256 #'equal)) ; for NAUT MTs
```

`monad-mt-fort-cache-base-mt mt basemt`: looks up `mt` in the FORT cache; if not present, computes `(all-genl-mts mt)` once, caches the result as a set, and tests membership. Subsequent queries are O(1) hash lookups.

The cache invalidates whenever assertions about `genlMt` are added or removed. `update-mt-relevance-cache argument assertion` is wired into the assertion-add/remove path; it currently `clear-mt-relevance-cache`s wholesale. A cleaner version would invalidate only the affected MTs.

`bind-mt-indexicals mt` is the indexical resolver — Cyc allows MTs to be expressed as indexicals like `#$TheCurrentMt` that resolve to a different concrete MT depending on context. For FORT MTs this is currently a no-op; the NAUT case is `missing-larkc`.

## HLMTs (Heuristic-Level Microtheories)

Most MTs are plain FORTs, but Cyc supports a richer NAUT-shaped MT representation that lets a single "monad" MT be projected through orthogonal dimensions:

- **Monad dimension**: the underlying conceptual MT (e.g. `#$BiologyMt`).
- **Time dimension**: a time-interval term like `(MtTimeDimFn (YearFn 1990))`.
- **Time-with-granularity dimension**: a time interval plus a granularity.

An HLMT is a NAUT formed from one of:

```
*context-space-functions* = (#$MtSpace #$MtDim #$MtTimeDimFn #$MtTimeWithGranularityDimFn)
```

For example, `(MtSpace #$BiologyMt (MtTimeDimFn ...))` is an HLMT representing biology-as-of-some-time. The full HLMT API:

```
(hlmt-p obj)                       ; is OBJ an HLMT?
(closed-hlmt-p obj)                ; HLMT and ground
(possibly-hlmt-p obj)
(monad-mt-p obj)                   ; FORT or MtUnion-NAUT, no time dimension
(hlmt-monad-mt hlmt)               ; extract the monad — defaults to *default-monad-mt*
(hlmt-temporal-mt hlmt)            ; extract the time dimension
(hlmt-equal a b)                   ; equal under structure
(hlmt-equal? a b)                  ; equal at every dimension
(get-hlmt-dimension dim hlmt)      ; lookup by :monad / :time / :unknown
(reduce-hlmt hlmt &opt minimize?)  ; strip default-valued dimensions
(canonicalize-hlmt mt)             ; pre-canonicalize, reduce, reify-when-closed
(valid-hlmt-p hlmt &optional robust)
(mt-union-naut-p obj)              ; (MtUnionFn ...)
(mt-union-function-p f)            ; eq #$MtUnionFn
(anytime-psc-p obj)                ; eq #$AnytimePSC
(hlmt-with-anytime-psc-p hlmt)
```

`hlmts-supported?` (currently T) gates whether the HLMT machinery is active. Setting it to NIL via `disable-hlmts` falls back to monad-only MT handling; `hlmt-equal` becomes `eq` instead of `equal`, `hlmt-p` becomes `valid-fort?` plus `mt-union-naut-p`, etc.

About 30 declareFunctions in `hlmt.lisp` are missing-larkc — most of the dimension-extraction internals and the NAUT-canonicalization helpers (`12260`, `12270`-`12350`, `29822`-`29824`). The structure-walking is intact; the per-dimension projections are stubs.

`canonicalize-hlmt` (in `hlmt-czer.lisp`) is the HLMT entry from canonicalization: pre-canonicalize, reduce dimensions, reify when closed (turn the NAUT into a NART if the MtSpace functor is reifiable), and finalize. Used by KE/FI when an MT is supplied as input.

## MT vocabulary — the hard-coded metatheory locations

Cyc's KB has a self-referential structure: facts about MTs are themselves stored *in* MTs. The `*mt-mt*` global tells the engine "which MT do you look in to find `(isa X #$Microtheory)` assertions?" Default: `#$UniversalVocabularyMt`. The full vocabulary:

| Variable | Default | Basis predicate | Purpose |
|---|---|---|---|
| `*mt-root*` | `#$BaseKB` | — | root of the MT hierarchy |
| `*theory-mt-root*` | `#$BaseKB` | — | highest theory MT for assertions/deductions |
| `*assertible-mt-root*` | `#$BaseKB` | — | highest MT where asserts normally allowed |
| `*assertible-theory-mt-root*` | `#$BaseKB` | — | the default `*mt*` value |
| `*core-mt-floor*` | `#$BaseKB` | — | minimum core MT |
| `*mt-mt*` | `#$UniversalVocabularyMt` | `#$Microtheory` | where `(isa X Microtheory)` and `genlMt` go |
| `*defining-mt-mt*` | `#$BaseKB` | `#$definingMt` | where `definingMt` assertions go |
| `*decontextualized-predicate-mt*` | `#$BaseKB` | `#$decontextualizedPredicate` | where `decontextualizedPredicate` goes |
| `*decontextualized-collection-mt*` | `#$BaseKB` | `#$decontextualizedCollection` | where `decontextualizedCollection` goes |
| `*ephemeral-term-mt*` | `#$BaseKB` | `#$ephemeralTerm` | where `ephemeralTerm` GAFs go |
| `*ist-mt*` | `#$BaseKB` | `#$ist` | where `#$ist` code-supports come from |
| `*inference-related-bookkeeping-predicate-mt*` | `#$BaseKB` | `#$InferenceRelatedBookkeepingPredicate` | for inference bookkeeping isa |
| `*anect-mt*` | `#$UniversalVocabularyMt` | `#$AtemporalNecessarilyEssentialCollectionType` | where ANECT isa goes |
| `*broad-mt-mt*` | `#$BaseKB` | `#$BroadMicrotheory` | where `BroadMicrotheory` isa goes |
| `*psc-mt*` | `#$BaseKB` | `#$ProblemSolvingCntxt` | where `ProblemSolvingContext` isa goes |
| `*tou-mt*` | `#$BaseKB` | `#$termOfUnit` | where NART-reification GAFs go |
| `*skolem-mt*` | `#$BaseKB` | `#$skolem` | where skolem GAFs go |
| `*thing-defining-mt*` | `#$BaseKB` | `#$Thing` | where `#$Thing` is defined |
| `*relation-defining-mt*` | `#$BaseKB` | `#$Relation` | where `#$Relation` is defined |
| `*equals-defining-mt*` | `#$BaseKB` | `#$equals` | where `#$equals` is defined |
| `*element-of-defining-mt*` | `#$BaseKB` | `#$elementOf` | where `#$elementOf` is defined |
| `*subset-of-defining-mt*` | `#$BaseKB` | `#$subsetOf` | where `#$subsetOf` is defined |
| `*arity-mt*` | `#$UniversalVocabularyMt` | `#$arity` | where `#$arity` assertions go |
| `*sublid-mt*` | `#$CycAPIMt` | `#$subLIdentifier` | where SubL-identity assertions are visible |
| `*not-assertible-mt-convention-mt*` | `#$UniversalVocabularyMt` | `#$notAssertibleMt` | where `notAssertibleMt` goes |
| `*default-ask-mt*` | `#$BaseKB` | — | default MT for asks |
| `*default-assert-mt*` | `#$BaseKB` | — | default MT for asserts |
| `*default-clone-mt*` | `#$BaseKB` | — | for cloning sentences |
| `*default-support-mt*` | `#$BaseKB` | — | fallback for HL supports |
| `*default-comment-mt*` | `#$BaseKB` | — | for comments and cyclistNotes |
| `*default-convention-mt*` | `#$UniversalVocabularyMt` | — | for decontextualized predicate/collection conventions |

The `defglobal-mt-var` macro (in `mt-vars.lisp`) is the declaration sugar — it expands to a `defglobal` plus a `note-mt-var-basis` call recording the basis predicate in `*mt-var-basis-table*`. The basis is *the constant* whose semantics determine "which MT should this variable point to" — at KB-load time, the engine can re-resolve each variable to the MT where its basis predicate's metadata is stored. This is the mechanism by which different KBs can declare different "where do bookkeeping facts go" without code changes.

## Public API surface

### Predicates and identity

```
(mt? fort)                         ; FORT is an MT
(mt-in-any-mt? fort)               ; isa Microtheory in any MT
(isa-mt? term &optional mt)        ; works for FORTs and HLMT NAUTs
(broad-microtheory-p fort)         ; isa BroadMicrotheory
(core-microtheory-p obj)
(special-core-loop-mt-p obj)
(monad-mt-p obj) (monad-mt? obj)
(hlmt-p obj) (hlmt? obj) (closed-hlmt-p obj)
(possibly-mt-p obj) (possibly-hlmt-p obj)
(possibly-hlmt-naut-p obj)
(hlmt-naut-p obj) (mt-space-naut-p obj) (mt-union-naut-p obj)
(anytime-psc-p obj) (anytime-during-psc-fn-naut-p obj)
(valid-hlmt-p hlmt &optional robust)
(valid-monad-mt-p mt)
```

### HLMT structure

```
(make-formula #$MtUnionFn mts)
(canonicalize-hlmt mt)
(reduce-hlmt hlmt &optional minimize?)
(transform-mt-union-nauts hlmt minimize?)
(hlmt-monad-mt hlmt) (hlmt-monad-mt-without-default hlmt)
(hlmt-temporal-mt hlmt)
(get-hlmt-dimension dim hlmt)
(hlmt-equal a b) (hlmt-equal? a b)
(hlmts-supported?) (disable-hlmts)
```

### genlMt lattice

```
(all-genl-mts mt &optional mt-mt tv)
(genl-mt? spec genl &optional mt-mt tv)
(proper-genl-mt? spec genl)
(monad-genl-mt? spec genl)
(min-mts mts &optional mt-mt)
(max-floor-mts mts &optional candidates mt-mt)
(max-floor-mts-with-cycles-pruned mts &optional candidates mt-mt)
(any-genl-mt? spec genls &optional mt-mt tv)        ; Cyc API
(do-base-mts mt body...)                             ; macro
(add-genl-mt source assertion)
(remove-genl-mt source assertion)
(add-base-mt source assertion)
(remove-base-mt source assertion)
```

### Core-MT helpers

```
(core-microtheory-< mt1 mt2)
(core-microtheory-> mt1 mt2)
(core-genl-mt? mt1 mt2)
(minimize-mts-wrt-core mts)
(maximize-mts-wrt-core mts)
(minimize-mt-sets-wrt-core mt-sets)
```

### Relevance scope

```
(relevant-mt? mt)
(relevant-mt-is-everything mt)
(relevant-mt-is-any-mt mt)
(relevant-mt-is-eq mt)
(relevant-mt-is-genl-mt mt)
(genl-mts-are-relevant?)
(any-mt-is-relevant?) (all-mts-are-relevant?)
(any-or-all-mts-are-relevant?)
(genl-mts-of-listed-mts-are-relevant?)
(any-time-is-relevant?)
(only-specified-mt-is-relevant?)
(any-or-all-mts-relevant-to-mt? mt)
(conservative-constraint-mt mt)
(any-relevant-mt? mts)
(inference-relevant-mt)
(current-mt-relevance-mt)
(mt-info &optional mt)
(mt-inference-function mt)
```

### Relevance scope macros

```
(with-mt mt body...)               ; Cyc API
(with-genl-mts mt body...)         ; Cyc API
(with-all-mts body...)             ; Cyc API
(with-any-mt body...)              ; Cyc API
(with-just-mt mt body...)          ; Cyc API
(with-mt-list mts body...)         ; Cyc API
(with-inference-mt-relevance mt body...)  ; Cyc API
(map-mts (var) body...)            ; Cyc API
(possibly-in-mt (mt) body...)
(possibly-with-just-mt (mt) body...)
```

### Cache management

```
(clear-mt-relevance-cache)
(update-mt-relevance-cache argument assertion)
(basemt? mt basemt)
(monad-basemt? mt basemt)
(bind-mt-indexicals mt)
```

### MT vocabulary

```
*mt-root* *theory-mt-root* *assertible-mt-root* *assertible-theory-mt-root*
*core-mt-floor* *mt-mt* *defining-mt-mt* *decontextualized-predicate-mt*
*decontextualized-collection-mt* *ephemeral-term-mt* *ist-mt*
*inference-related-bookkeeping-predicate-mt* *anect-mt* *broad-mt-mt*
*psc-mt* *tou-mt* *skolem-mt* *thing-defining-mt* *relation-defining-mt*
*equals-defining-mt* *element-of-defining-mt* *subset-of-defining-mt*
*arity-mt* *sublid-mt* *not-assertible-mt-convention-mt*
*default-ask-mt* *default-assert-mt* *default-clone-mt*
*default-support-mt* *default-comment-mt* *default-convention-mt*
*core-mts* *ordered-core-mts* *special-loop-core-mts*
*mt-var-basis-table*
(note-mt-var var &optional basis)
(note-mt-var-basis var basis)
(defglobal-mt-var var default &optional basis comment)  ; macro
```

### Dynamic-scope variables

```
*mt*                            ; the bound MT
*relevant-mt-function*          ; the relevance test function symbol
*relevant-mts*                  ; for MtUnion-relevance
```

### Dynamic-scope variables

```
*hlmts-supported?*              ; HLMT machinery toggle
*default-monad-mt*              ; #$UniversalVocabularyMt
*default-mt-time-interval*      ; #$Always-TimeInterval
*default-mt-time-parameter*     ; #$Null-TimeParameter
*context-space-functions*       ; HLMT functor whitelist
*mt-dimension-functions*
*mt-dimension-types*            ; (:monad :time)
*temporal-dimension-predicates*
*temporal-dimension-functions*
*unindexed-hlmt-syntax-constants*
*core-mt-optimization-enabled?*
*min-mts-2-enabled?*
*anytime-psc*                   ; #$AnytimePSC
*anytime-during-psc-fn*         ; #$AnytimeDuringPSCFn
*mt-space-function*             ; #$MtSpace
```

## Consumers

| Consumer | What it uses |
|---|---|
| **Every assertion read** (`assertions-low.lisp`, `assertions-high.lisp`) | `with-inference-mt-relevance`, `relevant-mt?`, `assertion-mt`. The MT context is consulted before every assertion is admitted as a query result. |
| **kb-mapping** (`kb-mapping.lisp`, `kb-mapping-utilities.lisp`) | Heavy user of `with-mt`, `with-all-mts`, `possibly-in-mt`. Most of the `do-X-for-term` iterators wrap their body in MT-relevance scope. |
| **Inference workers** (`inference/harness/*.lisp`) | Each worker is given a problem with an MT context; the worker establishes that scope via `with-inference-mt-relevance` before iterating its rule index. The `mt-inference-function` dispatcher decides whether the worker uses normal genlMt-based scope or one of the PSC modes. |
| **Canonicalization** (`czer-main.lisp`, `czer-trampolines.lisp`, `canon-tl.lisp`) | `canonicalize-hlmt`, `reduce-hlmt`, `*default-monad-mt*`. MT-shaped sentences (`#$ist mt sentence`) are folded through MT canonicalization before being clausified. |
| **HL supports** (`hl-supports.lisp`) | Every hl-support's MT is consulted via `hl-support-mt`; relevance is established via `with-inference-mt-relevance` inside `hl-support-justify`. |
| **kb-hl-supports** (`kb-hl-supports.lisp`) | The four-level index is keyed on MT — `module → mt → tv → term → set`. |
| **GenlMt graph mutation** (assertion add/remove paths) | When a `(genlMt ...)` GAF is added, `add-genl-mt` is called via `register-kb-function`, which propagates to the SBHL graph. `update-mt-relevance-cache` clears the cache. |
| **Forward propagation** (`inference/harness/forward.lisp`) | `hl-forward-mt-combos` lifts an hl-support to all its valid MTs. The per-module `:forward-mt-combos` function (e.g. `hl-forward-mt-combos-genls`) computes the alternates. |
| **Bookkeeping** (`bookkeeping-store.lisp`, `cyc-bookkeeping.lisp`) | `*tou-mt*`, `*defining-mt-mt*`, `*ephemeral-term-mt*`, `*default-comment-mt*` are read to decide where to lay down bookkeeping facts. |
| **WFF** (`wff.lisp`, `wff-utilities.lisp`) | `mt?`, `valid-hlmt-p`, `monad-mt-p` for type-checking the MT slot of asserts and `#$ist`-formed sentences. |
| **NART removal** (`narts-high.lisp`) | `*tou-mt*` is the MT containing `(termOfUnit nart naut)` GAFs that the NART removal cascade needs to find. |
| **AT system** (`arg-type.lisp`, `at-defns.lisp`, `at-cache.lisp`) | Several `with-all-mts` wrappers around argument-type checks; type rules are looked up across the entire MT lattice. |

## Files

| File | Role |
|---|---|
| `mt-vars.lisp` | The 30+ `*<name>-mt*` global variables, their basis-predicate registrations via `defglobal-mt-var`, the `*core-mts*` ordering, `core-microtheory-p` / `core-microtheory-<` / `minimize-mts-wrt-core`. The "where do MTs go" book. |
| `mt-relevance-macros.lisp` | `*mt*`, `*relevant-mt-function*`, `*relevant-mts*`, the relevance-test functions, all the `with-X` macros, `update-inference-mt-relevance-*` helpers, `inference-relevant-mt`. The dynamic-scope plumbing. |
| `mt-relevance-cache.lisp` | `*monad-mt-fort-cache*`, `*monad-mt-naut-cache*`, `clear-mt-relevance-cache`, `update-mt-relevance-cache`, `basemt?`, `monad-basemt?`, `bind-mt-indexicals`. |
| `genl-mts.lisp` | The `#$genlMt` lattice — `all-genl-mts`, `genl-mt?`, `min-mts`, `max-floor-mts`, `do-base-mts`, plus the SBHL plumbing for adding/removing `genlMt` assertions. ~50 declareFunctions are LarKC-stripped here. |
| `hlmt.lisp` | The HLMT NAUT-shape MT representation — `hlmt-p`, `hlmt-monad-mt`, `hlmt-temporal-mt`, `reduce-hlmt`, `transform-mt-union-nauts`, the dimension projections. ~30 missing-larkc internals. |
| `hlmt-czer.lisp` | `canonicalize-hlmt`, the HLMT canonicalization entry. Tiny (60 lines) — most of the work is delegated to the general canonicalizer. |
| `psc.lisp` | The PSC dispatcher — `mt-inference-function`. Just one function; the actual semantics live in `with-inference-mt-relevance` and the dispatchers it calls. |

## Notes for a clean rewrite

- **The `*mt*` / `*relevant-mt-function*` pair as dynamic scope is awkward** — every call that consults MT relevance has to be wrapped in the right macro, and forgetting to do so silently uses whatever scope is in effect. A cleaner design threads an MT-context object through inference calls explicitly. The wrapping macros become record-construction.
- **The relevance-function `case` in `relevant-mt?` is a fixed dispatch** that could be replaced by a polymorphic relevance type. `(relevant-mt-is-genl-mt . *mt*)`, `(relevant-mt-is-eq . *mt*)`, `(relevant-mt-in-list . *relevant-mts*)`, etc. — each is a small struct or sum type variant.
- **The MT vocabulary globals (`*tou-mt*`, `*arity-mt*`, etc.) are 30 separate variables** that all answer "where does this kind of assertion live?". A single `*mt-locations*` hash from basis-predicate to MT would replace them, with `(mt-location-of #$arity)` as the lookup. The `defglobal-mt-var` macro could remain as the registration sugar, but the storage would be unified.
- **The MT relevance cache invalidates wholesale on every `genlMt` change.** This is correct but pessimistic. Targeted invalidation — only the affected MTs and their descendants — is straightforward given the SBHL knows the affected subgraph.
- **Core-MT optimization is hand-coded.** Seven specific MTs get a shortcut path. A clean rewrite either folds this into the general SBHL caching (the cache already supports prefilling with ground-truth ancestors), or makes it a configurable list rather than a hard-wired one.
- **HLMTs are heavily missing-larkc.** The structural tests (`hlmt-p`, `hlmt-naut-p`, `mt-union-naut-p`) work, but most of the dimension-extraction internals (`get-hlmt-dimension` for non-monad cases, `valid-hlmt-p` robust mode, `hlmt-equal?` non-trivial cases) are stubs. A clean rewrite needs to implement these because HLMTs are how Cyc represents temporal and contextual scoping — the core feature, not an optional extension.
- **`hlmts-supported?` as a runtime toggle is suspicious.** Either HLMTs are part of the engine or they aren't. The toggle exists because supporting HLMTs everywhere requires touching every relevance check; making it optional was a perf/complexity hedge. The clean rewrite picks a side.
- **`bind-mt-indexicals` is a no-op for FORT MTs.** Indexical resolution (`#$TheCurrentMt`, `#$TheUserMt`) is missing-larkc for the NAUT case. This is a real feature that's stripped here; the clean rewrite needs the contextual-resolution path.
- **PSCs (`#$EverythingPSC`, `#$InferencePSC`, `#$AnytimePSC`) are constants treated specially by the relevance dispatcher.** Making PSCs first-class as their own MT subtype (rather than special FORTs detected by `eq` in `mt-inference-function`) would simplify the dispatch and let new PSC kinds be added without modifying the dispatcher.
- **MtUnionFn is special-cased in `mt-union-function-p`** as `(eq object #$MtUnionFn)`. Other MT-constructing functors (`#$MtSpace`, `#$MtTimeDimFn`, etc.) are treated more uniformly via the `*context-space-functions*` whitelist. The asymmetry is historical; the clean rewrite folds them.
- **`update-mt-relevance-cache` is wired into the assertion add/remove path but the cache it updates is separate from the SBHL cache.** Two caches for related data is a maintenance hazard. Unify into a single MT-graph cache that the SBHL queries directly.
- **The `defglobal-mt-var` mechanism with basis predicates is interesting.** It's a way for the engine's hardcoded knowledge of "where does X go" to be re-resolved against the loaded KB at startup, so different KBs can have different "this MT is the X-location" choices. The clean rewrite should preserve this — it's how the engine stays decoupled from any particular KB's metatheory layout.
- **The `core-microtheory-<` comment notes "this is actually a `<=` comparison, not `<`"** — a clean rewrite either renames it or changes the semantics. As-is the name lies.
