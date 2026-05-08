# Somewhere-cache

A **negative-existence cache for predicate-extent membership.** For ~140 specifically-listed predicates, the somewhere cache stores: "the set of terms that appear in argument position N of *some* assertion using this predicate." When inference asks "is there *any* `(genlPreds ?X foo)` assertion?", the cache can answer "no, definitively" in O(1) without touching the indexing system. This dodges enormous quantities of repeated, expensive empty-extent lookups during canonicalization and inference: the predicates in the cached list are the ones that get queried *constantly* but *rarely* match anything.

The "somewhere" in the name is literal: it doesn't tell you *which* assertion or *what* MT — it tells you the term shows up *somewhere* in *some* assertion of that predicate. That's enough for the existential check most callers actually need ("is this predicate worth looking up at all?"), and storing nothing else keeps the cache compact: one set of FORTs per predicate, indexed by argnum.

The file lives in `larkc-cycl/somewhere-cache.lisp` and is a separate module from `cache.lisp` because the data structure is fundamentally different — there is no LRU, no capacity, no eviction. It's a complete, persistent (through the dump cycle) membership cache. The name "cache" is mildly inaccurate; "somewhere index" or "predicate-extent existence index" would describe the shape better.

## When does the somewhere cache come into being?

The cache exists at the **lifetime of the loaded KB**. Concrete events:

| Trigger | Effect |
|---|---|
| Image starts, no KB loaded | `*some-pred-assertion-somewhere-cache*` is `:uninitialized`; `somewhere-cache-unbuilt?` is true. |
| `load-somewhere-cache` runs during KB load | Reads the dumped cache off `cfasl` from the dump directory; binds the global to a hash-table of pred→set. |
| `clear-all-somewhere-caches` runs | Allocates a fresh empty hashtable sized to the length of `*somewhere-cached-preds-table*` (~140). |
| `kb-utilities.lisp` `possibly-clear-dumpable-kb-state-hashes` runs at clear-kb time | Calls `clear-all-somewhere-caches` if the cache is unbuilt — the safety initializer. |
| First call to `some-pred-assertion-somewhere?` for a pred whose set isn't in the table yet | `lookup-somewhere-set-for-pred` calls `initialize-somewhere-cache pred`, which scans the predicate's full extent index using `kmu-do-index-iteration` and populates the set. This is the **lazy initialization** path. |
| A new GAF is asserted for a somewhere-cached pred | `recache-some-pred-assertion-somewhere` is called via the gaf-after-adding hook (registered out-of-band — see "How after-adding wires it" below). The newly added GAF's argnum-th argument is added to the pred's set. |
| A GAF for a somewhere-cached pred is removed | Same hook fires for after-removing. `recache-some-pred-assertion-somewhere-int` removes the term from the set and re-checks the predicate's extent for any other assertions of this term still standing — if any are still there, the term goes back in. |

The pre-`load-somewhere-cache` initialization function `possibly-initialize-dumpable-kb-state-hashes` in `kb-utilities.lisp` calls `missing-larkc 32146` for the somewhere case — the full Cyc engine's dump-time recompute step is stripped. So in the LarKC port, the cache is either loaded from disk, lazily filled per-pred, or rebuilt with `clear-all-somewhere-caches` followed by lazy fills.

## The cached-preds table — what gets cached and why

`*somewhere-cached-preds-table*` is a deflexical alist of ~140 entries, each `(predicate . argnum)`. The entries fall into roughly six categories:

| Category | Examples | Why cache "is X mentioned by this pred?" |
|---|---|---|
| AT-system meta-predicates | `argsIsa`, `argAndRestIsa`, `interArgResultIsa`, `interArgGenl1-2`, `modalInArg` | AT canonicalization checks every term against many AT predicates; most terms are not the subject of any AT assertion. Negative answers are the common case. |
| Canonicalizer directives | `canonicalizerDirectiveForArg`, `canonicalizerDirectiveForAllArgs`, `evaluateAtEL`, `evaluateImmediately` | Same: most preds have no canonicalizer directive. Cyc's canonicalizer wants to know fast. |
| Predicate metadata | `genlPreds`, `genlInverse`, `functionCorrespondingPredicate`, `interArgDifferent`, `notAssertible` | Walk-up genl-pred lookups for inference; mostly no genl-pred chain exists. |
| Naming & strings | ~50 entries on `nameString`, `acronymString`, `posForms`, `denotation`, `multiWordString`, `placeName-*`, `countryName-*` | NL generation queries every term for every name string; almost all terms have none. |
| Existence claims | `relationAllExists*`, `requiredActorSlots`, `rolesForEventType`, `subjectRoles`, `directObjectRoles` | Frame-semantic queries that mostly say "no" for arbitrary collections. |
| Trivial-for-justification & paraphrase exclusions | `predTrivialForJustificationParaphrase`, `assertionTrivialForJustificationParaphrase`, `mtTrivialForJustificationParaphrase`, `ruleTrivialForJustificationParaphrase` | Justification paraphrase walks every step; only certain explicitly-listed steps are flagged trivial. |

For each pred, only **one argnum** can be cached (the value next to the pred in the alist) — the comment at `*somewhere-cached-preds-table*` explicitly says "Currently a predicate CANNOT have more than one cached argnum." This is a deliberate design simplification: a single-argnum index is one set per pred; multi-argnum would need either a set per (pred, argnum) (multiplicative storage) or a join structure. The chosen argnum is the position queried by the dominant caller.

Several entries appear with argnum `2` (e.g., `genlPreds`, `genlInverse`, `rewriteOf`, `relationAllExists*`, `genStringAssertion*`) — these cache the second argument because the typical query is "is there any `(genlPreds X foo)`?" — answered by checking whether `foo` appears in argnum 2. Most entries are argnum 1 (cache the first/main argument).

A handful — `interArgResultGenl . 3`, `quantifiedBinaryPredicateForPredWithMacro . 3`, `applicableWhenTypedOnlyWhenSpecialization . 3`, `denotation . 4`, `compoundString . 4`, `hyphenString . 4`, `multiWordString . 4`, `headMedialString . 5`, `codeMapping . 3` — cache higher argnums where domain-specific lookup queries that position.

## Data structures

```lisp
*somewhere-cached-preds-table*  ; deflexical alist (pred . argnum)
*some-pred-assertion-somewhere-cache*
  ; defglobal — :uninitialized, or a hashtable: pred → set of FORTs
*inter-arg-result-isa-somewhere-cache*
  ; defglobal — separately-managed set for inter-arg-result-isa
  ; (a TODO/uninitialized companion in the LarKC port)
*somewhere-cache-gaf-after-adding-info*
  ; deflexical (recache-some-pred-assertion-somewhere . #$UniversalVocabularyMt)
  ; — the after-adding/after-removing dispatch info, hard-coded into get-after-adding
```

The set stored per-pred is a `set` (see [data-structures/set.md](set.md)) keyed by `#'eq` — FORT identity is the key. Every term appearing in the cached argnum of any assertion under that pred is added to the set; nothing else is recorded (no MT, no count, no assertion handle).

`valid-somewhere-cache-item?` is the gatekeeper for what enters the set: only `reified-term-p` objects (FORTs and similar reified entities). Variables, formulas, numbers, and strings can't be cached because the cache is set-of-FORTs.

## Public API

| Function | Purpose |
|---|---|
| `(some-pred-assertion-somewhere? pred term argnum &optional initialize-if-uninitialized?)` | The query: T iff some assertion `(pred ... term ...)` exists with `term` in position `argnum`. **The argnum must match the cached argnum** for this pred — otherwise the dispatch returns `:maybe` and `missing-larkc 32142` fires (full Cyc presumably falls back to a real index lookup). |
| `(some-pred-assertion-somewhere?-internal pred term argnum initialize?)` | Returns `:yes`, `:no`, or `:maybe` — exposes the three-valued result. |
| `(somewhere-cached-pred-p object)` | T iff the pred is in `*somewhere-cached-preds-table*`. |
| `(some-pred-assertion-somewhere-argnum pred)` | Returns the cached argnum for a cached pred, NIL otherwise. |
| `(valid-somewhere-cache-item? object)` | Is this term storable? Inline; equivalent to `reified-term-p`. |
| `(clear-all-somewhere-caches)` | Reset to a fresh empty hashtable sized to predicate count; returns 0. |
| `(somewhere-cache-unbuilt?)` | True iff cache is `:uninitialized` or empty. Used by KB-load gating. |
| `(load-somewhere-cache-from-stream stream)` | Read four CFASL blobs off `stream` (cache + three more — TODO comment in source confirms the loader reads four objects, the latter three are ignored). |
| `(recache-some-pred-assertion-somewhere argument assertion)` | The after-adding / after-removing entry point. Called by `inference/harness/after-adding.lisp`'s `get-gaf-after-addings` whenever a GAF for a cached pred is asserted or retracted. |

### Internal helpers (not part of the consumer API)

| Function | Role |
|---|---|
| `lookup-somewhere-set-for-pred pred initialize?` | Get the set for pred, lazily building if missing and `initialize?` is true. |
| `initialize-somewhere-cache pred` | Scan the entire predicate-extent index of `pred` (via `kmu-do-index-iteration` in `*relevant-mt-function* = relevant-mt-is-everything` / `*mt* = #$EverythingPSC`) and add every term in the cached argnum to a fresh set sized via `num-predicate-extent-index`. |
| `recache-some-pred-assertion-somewhere-int pred term` | Re-validate one term: remove it from the set, then re-walk the index for `(pred …term…)` assertions; if any survive, re-add. |
| `cache-some-pred-assertion-somewhere set gaf` | Inner per-GAF callback: if the assertion is still alive (`assertion-still-there?`), valid (`hlmt-p` MT), and the argnum's value is a reified term, add to set; return T iff added. |

## How after-adding wires it (the HL hook)

The somewhere cache **does not register itself with the KB as a real `afterAdding`/`afterRemoving` predicate-level fact**. The comment in `*somewhere-cache-gaf-after-adding-info*` says so explicitly: *"This is not asserted as an afterAdding and afterRemoving in the KB, it's hard-coded specially in get-after-adding and get-after-removing."*

Concretely, in `inference/harness/after-adding.lisp` the functions `get-gaf-after-addings` and `get-gaf-after-removings` look up the normal after-adding hash, then **append `*somewhere-cache-gaf-after-adding-info*`** if the predicate is `somewhere-cached-pred-p`. The result is a list of `(function . mt)` pairs that the HL post-mutation pass calls in order. So for any GAF on a cached pred, `recache-some-pred-assertion-somewhere` runs alongside whatever real after-adding/after-removing functions are asserted.

This is a design optimization: putting the after-adding fact in the KB would mean walking the assertion-handle hierarchy of `afterAdding`/`afterRemoving` predicates for every modification of every cached pred, which is the very sort of overhead the somewhere cache is supposed to eliminate. Hard-coding the dispatch sidesteps the lookup.

## Persistence

| Phase | What happens |
|---|---|
| **Save** | `dumper.lisp` line 1527 has a commented `dump-somewhere-cache` declareFunction with no body — full Cyc dumps the cache; the LarKC port's dump path is stripped. |
| **Load** | `dumper.lisp` `load-somewhere-cache directory-path` opens `somewhere-cache.cfasl` from the dump directory and calls `load-somewhere-cache-from-stream`, which reads four CFASL objects: the main hashtable (pred → set) and three trailers (TODO — likely `*inter-arg-result-isa-somewhere-cache*` plus two related caches). |
| **Recompute on demand** | If load fails or the cache is missing, the lazy per-pred path in `lookup-somewhere-set-for-pred` rebuilds each pred's set on first query. |
| **Re-dump preparation** | `kb-utilities.lisp` `possibly-clear-dumpable-kb-state-hashes` clears it; `possibly-initialize-dumpable-kb-state-hashes` is `missing-larkc 32146` — full Cyc rebuilds before saving so the dump is canonical, but the port can't run that step. |

**CFASL registration:** The somewhere cache itself doesn't register a CFASL opcode. The hashtable and the contained `set` objects use the standard hashtable and set opcodes (sets have opcode 60 — see [data-structures/set.md](set.md)). The cache's persistence is therefore a "container of standard objects" file rather than its own custom format.

## Where the somewhere cache is consumed

`some-pred-assertion-somewhere?` is called from across the KB-access and reasoning stacks:

| File | Use |
|---|---|
| `at-cache.lisp` | `(some-pred-assertion-somewhere? #$argsIsa relation 1)` and `#$argAndRestIsa` — gate AT cache population. |
| `at-routines.lisp` | `#$interArgNotIsa1-2`, `#$interArgNotIsa2-1`, `#$interArgDifferent` — short-circuit AT inter-arg checks. |
| `at-var-types.lisp` | `#$modalInArg` — gate modal-arg detection. |
| `cycl-utilities.lisp` | `#$functionalInArgs`, `#$strictlyFunctionalInArgs` — gate functional-pred handling. |
| `czer-utilities.lisp` | Generic czer-pred check during canonicalization. |
| `precanonicalizer.lisp` | `#$evaluateAtEL` — gate EL evaluation during precanonicalization. |
| `assertion-utilities.lisp` | `#$exceptMt`, `#$except` — gate exception handling on assertions/MTs. |
| `equality-store.lisp` | `#$rewriteOf` argnum 2 — gate rewrite-of lookup. |
| `tva-utilities.lisp` | TVA-cache predicate gates. |
| `genl-predicates.lisp` | `#$genlPreds`, `#$genlInverse` argnum 2 — short-circuit genl-pred chain walks. |
| `inference/modules/removal/removal-modules-reflexive-on.lisp` | `#$reflexiveOn` — gate reflexive removal applicability. |

The pattern is uniform: **before doing real work for predicate P on term T, ask "is there even any P-assertion mentioning T?" — if no, skip.** This is exactly the negative-existence cache use-case.

`somewhere-cached-pred-p` and `some-pred-assertion-somewhere-argnum` are introspection helpers, used by the after-adding registration in `inference/harness/after-adding.lisp` and by `recache-some-pred-assertion-somewhere` itself.

`clear-all-somewhere-caches` and `somewhere-cache-unbuilt?` are called by `kb-utilities.lisp` during the KB-state-hash clear/init dance.

`load-somewhere-cache-from-stream` is called only by `dumper.lisp` at KB load.

## Why this is distinct from `cache.lisp`

The two files share the word "cache" but otherwise have nothing in common:

| | `cache.lisp` | `somewhere-cache.lisp` |
|---|---|---|
| Purpose | Bounded-size LRU eviction store | Unbounded predicate-extent membership index |
| Capacity | Fixed at construction | Grows with the number of cached preds and tracked terms |
| Eviction | LRU (LarKC-stripped) | Never |
| Keys | Arbitrary; per-instance test | (pred, term) — predicate hash + set membership |
| Values | Arbitrary | Implicit: presence in a set means "yes, somewhere" |
| Persistence | Reserved opcode 63, no handler | Loaded from `somewhere-cache.cfasl` at KB load |
| Eligibility for caller | "I have a key/value workload and want to cap memory" | "I'm doing predicate-extent existence queries on one of these ~140 predicates" |
| Updated by | Caller `cache-set` / `cache-remove` | KB after-adding/after-removing hook |

Calling this a "cache" follows the Cyc convention where any precomputed lookup table is a "cache." A more modern name would be **predicate-extent-existence index** or **somewhere-index**.

## Notes for a clean rewrite

- **Keep the file. The data structure is right.** A pred → set-of-cached-argument mapping is the minimal shape for "does any assertion exist with this predicate and term?" and it's exactly what dozens of callers need.
- **Implement the dump side (`dump-somewhere-cache`).** The load side works; the save side is `missing-larkc`. Without it, every KB save loses the cache and every load triggers a full per-pred rebuild on first query. A cleanup sweep before save (`possibly-initialize-dumpable-kb-state-hashes`'s `missing-larkc 32146`) should rebuild any preds that were lazy-loaded so the dump is complete and canonical.
- **Decide whether to permit multi-argnum caching per pred.** The current single-argnum constraint is a deliberate simplification — easy to lift if a pred has multiple "common existential lookup positions." Add a second hashtable layer if needed, or expand the set value to a vector-of-sets indexed by argnum.
- **The `:maybe` return path on argnum mismatch should fall back to a real index lookup, not error.** The `missing-larkc 32142` should become "consult the predicate-extent index" — non-cached argnums need answers too.
- **Wire after-adding through the KB rather than hard-coding.** The "this is not asserted as afterAdding in the KB" comment is a performance optimization that the original author flagged. A modern engine could register a synthetic after-adding fact at startup; the lookup cost would be negligible because only ~140 preds are involved, and the dispatch becomes uniform with all other after-adding work. Keep the optimization only if profiling demands it.
- **The hard-coded list is fine.** ~140 preds; any modern KB system has a similar "preds we know to special-case for performance" list. Make it a CSV or small config rather than inlined into Lisp source — the only reason it's inlined is that SubL didn't have config-file support.
- **Consider deriving the cached-preds list from KB metadata** (e.g. `(somewhereCachedPredicate ?P ?ArgNum)`) instead of hard-coding it. Then the cache regenerates correctly when the KB designer adds a new high-frequency predicate. This is more aligned with Cyc's general "everything is asserted" philosophy than the deflexical alist.
- **Drop `set-rebuild`-style bookkeeping.** The cache is a hashtable of sets; both backends are stable, no rebalancing needed.
- **Per-pred set initialization sets the size to `num-predicate-extent-index` of the pred.** Right call — the extent count is the upper bound on the set size. Keep that sizing.
- **The loader reading four CFASL objects from one file is brittle.** Use a struct-shaped header (count + payload) so trailing items are explicit, not implicit.
