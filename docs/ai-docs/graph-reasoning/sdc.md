# SDC — Sibling-Disjoint Collections

SDC is **second-order disjointness reasoning**: instead of asking "are two specific collections C1 and C2 disjoint?" (the [disjoint-with](named-hierarchies.md#disjoint-with----disjointwith) question), SDC asks "is there some *collection-type* — a `#$SiblingDisjointCollectionType` — such that C1 and C2 are both instances of it, making them disjoint *as siblings under that type*?" Plus an exception system that permits specific (C1, C2) pairs to escape the rule even when they share such a type.

The implementation is `sdc.lisp` (589 lines). About 60% missing-larkc (most of the meta-API: `sdc`, `max-sdc`, `all-sdc`, `isa-sdct`, `applicable-sdct`, the `why-*` justification family, the `sdct-elements` family); the **core decision predicate `sdc?` and its workhorse `any-isa-common-sdct` are fully ported**, so SDC is functionally usable in the LarKC port.

The clean rewrite needs SDC because it's the disjointness-by-default rule that prevents Cyc from accepting absurd type combinations like "this animal is also a chair." Without SDC, every disjointness pair would have to be asserted explicitly.

## What "sibling-disjoint collection type" means

A `#$SiblingDisjointCollectionType` is a *type-of-types* whose instances are taken to be pairwise disjoint by default. Examples (from Cyc's KB):
- `#$BiologicalLifeStage` — `Adult`, `Infant`, `Adolescent` are siblings under it; an organism in one stage isn't simultaneously in another.
- `#$Sex` — `MaleAnimal`, `FemaleAnimal` are sibling instances; an organism with one isn't simultaneously the other.
- `#$BasicForm` — `LiquidStateOfMatter`, `SolidStateOfMatter`, `GasStateOfMatter` — water can't be both ice and steam at once.

The rule: if C1 and C2 are both instances of some same SD-collection-type T, then `(disjointWith C1 C2)` is taken as a default conclusion. This is enormously cheaper than asserting `(disjointWith Adult Infant)` and `(disjointWith Adult Adolescent)` and so on for every pair under every SD type.

The exception is `#$siblingDisjointExceptions` — a binary predicate that *carves out* specific pairs that violate the default. The canonical example: "printer-copier" (a thing that's both a `Printer` and a `Copier` even though those would normally be sibling-disjoint instances of `OfficeMachine` or similar). When `(siblingDisjointExceptions Printer Copier)` is asserted, the SDC rule no longer fires for that pair.

## The decision: `(sdc? c1 c2 &optional mt)`

The signed entry point is `sdc? c1 c2`. It returns true iff C1 is sibling-disjoint with C2 in the relevant mt. Implementation walks four cases:

```
sdc? c1 c2 mt
  if (ground-naut? c1) -> sdc? <substituted-c1> c2 mt          ; reify and recurse
  if (ground-naut? c2) -> sdc? c1 <substituted-c2> mt          ; same
  if (not (collection? c1)) -> nil
  if (not (collection? c2)) -> nil
  else -> sdc-int? c1 c2 (within mt-relevance binding)
```

`sdc-int? c1 c2` is the actual logic:

```
sdc-int? c1 c2
  if *ignoring-sdc?*                  -> nil          ; opt-out flag
  if (not (isa-common-sdct? c1 c2))   -> nil          ; no shared SD type → no SDC
  if (establishing-superset? c1 c2)   -> nil          ; we're asserting genls — would contradict
  if (establishing-superset? c2 c1)   -> nil          ; same, swapped
  if (establishing-instance-of? c1 c2) -> nil         ; we're asserting a common instance — would contradict
  else -> t
```

The four guard clauses are critical:

| Guard | Reason |
|---|---|
| `*ignoring-sdc?*` | Caller-controlled bypass. Set by AT routines (see "Consumers" below) when they want disjointness checks suspended. |
| `isa-common-sdct?` | Cheap pre-test: if there's no SD-collection-type they both inherit, SDC trivially fails. The expensive search is skipped. |
| `establishing-superset?` | If the *current* assertion-in-progress is `(genls c1 c2)` or some path that subsumes one to the other, returning `t` here would block the very assertion being added. The SDC check pretends-to-be-false in that context. |
| `establishing-instance-of?` | Same idea for `(isa X c1)` and `(isa X c2)` — if some specific X is being declared as an instance of *both*, the user is implicitly declaring they're not sibling-disjoint after all (e.g. printer-copier). Defer to the user. |

The "establishing" guards are why SDC is integrated tightly with the [arg-type/AT system](../canonicalization/arg-type.md): they read the *currently being processed* assertion (`*added-assertion*`) and bail if it's the cause of the apparent disjointness violation.

## The SD search

`isa-common-sdct? c1 c2` is the cheap-yes/cheap-no test. The real work is `any-isa-common-sdct c1 c2 &optional mt tv` — find a *witness* collection-type T such that:

1. T is a `#$SiblingDisjointCollectionType` (i.e. `(isa T SiblingDisjointCollectionType)`).
2. There exists some intermediate G such that `(genls c1 G)` and `(genls c2 G)` *both fail* — they don't share G as a common supertype.
3. There exists some intermediate G such that `(genls c2 G)` and `(isa G T)` — G is an instance of T.
4. `c1` is below G in the genls graph (so `c1` is "in T's region of the type lattice").
5. There are no `#$siblingDisjointExceptions` between any (c2-genl, x) where x is in c1's genls-cone.

This is implemented over the [SBHL](sbhl.md) marking-space machinery: four marking spaces are bound at the top of `any-isa-common-sdct`, used to mark the `genls(c1)` set, the `genls(c2)` set, the `genls-isas(c1)` set (genls of c1's genls — i.e. *types* of c1's supertypes), and a candidate-store hashtable mapping potential goal SD types to their relevant exceptions.

The marking spaces are local to one call — allocated by `get-sbhl-marking-space`, freed in reverse order at the end. This is critical for re-entrancy: nested SDC queries don't clobber each other.

### The candidate-store mechanism

When a candidate SD-collection-type G is found that *would* satisfy the rule but has relevant exceptions, the search doesn't return it — it stores `G → (list of exception-sets)` in `*sd-candidate-store*` and keeps looking. Two follow-up paths then:

1. **`sbhl-determine-sd-path-with-no-exceptions c1`** — for each stored candidate, check if there's a genls-isa path from c1 to that candidate that *avoids* the exception-pair siblings. If yes, that path proves SDC despite the exceptions.
2. **`sbhl-determine-sd-path-with-no-exceptions-among c1s`** — same but ranges over multiple c1 candidates (the "any-isa-common-sdct-among" variant for "is *any* of these c1s sibling-disjoint with c2?").

This two-phase approach (gather candidates, then check exception bypass) is why the search can't short-circuit on first-found — it has to be completionist enough to know whether *some* path through the graph avoids exceptions.

## Data: the four marking spaces and the candidate store

| Special | Purpose |
|---|---|
| `*sd-c1-genls-space*` | Marks `(genls c1 *)` — the supertypes of c1. |
| `*sd-c2-genls-space*` | Marks `(genls c2 *)` — the supertypes of c2. |
| `*sd-genls-isas-space*` | Marks `(isa G *)` for every G that is a genls of c1 — the "what types do c1's supertypes inhabit?" set. The candidate SD types live in here. |
| `*sd-candidate-store*` | Hashtable: SD-type → list of relevant exception-pair sets. Filled when a candidate has exceptions; consulted by the path-with-no-exceptions resolution. |

All four are dynamically rebound at every entry to `any-isa-common-sdct` / `any-isa-common-sdct-among`. They're nil at top level — the binding happens with `(let ((*sd-c1-genls-space* (get-sbhl-marking-space))) ...)` at each call.

`*sd-c2-genl*` is a fifth special — the *current* c2-genl being inspected during the inner gather loop, used as a context variable for nested calls.

## Exceptions

`direct-sdc-exceptions collection &optional mt` (line 499) is the single ported gateway to exception data:

```
(nunion (pred-values-in-relevant-mts collection #$siblingDisjointExceptions mt 1 2)
        (pred-values-in-relevant-mts collection #$siblingDisjointExceptions mt 2 1))
```

That is: look up `(siblingDisjointExceptions C ?X)` and `(siblingDisjointExceptions ?X C)` in any relevant mt, union the values. The predicate is symmetric, so both arg-positions matter.

`sdc-exceptions collection mt` calls `sdc-exceptions-int`, which extends with `*sdc-common-spec-exception?*` mode (missing-larkc 12564 — `sdc-exceptions-of-genls`): when set, the rule "if X has a common spec with C, X transitively inherits C's exceptions" applies. Off by default; expensive enough that the file flags it as such.

## The two control parameters

| Parameter | Default | Effect |
|---|---|---|
| `*sdc-exception-transfers-thru-specs?*` | nil | If t, `(sdcException x y) ∧ (genls z y) → (sdcException x z)`. I.e. an exception "leaks down" to specs. Expensive. |
| `*sdc-common-spec-exception?*` | nil | If t, `(genls z x) ∧ (genls z y) → (sdcException x y)`. I.e. having a common spec is itself an exception (anything two types share a child of can't be sibling-disjoint). Even more expensive. |
| `*ignoring-sdc?*` | nil | If t, `sdc?` returns nil unconditionally. Opt-out for callers that don't want disjointness reasoning at all. |

The first two are off by default because they each broaden the exception set, weakening the SDC default. Cyc's KB curators presumably only enable them when reasoning about a domain where the looser semantics are needed.

## Consumers

SDC is consumed in three places in the port:

1. **AT (arg-type) routines** — [`at-routines.lisp`](../canonicalization/arg-type.md) at six sites (lines 219, 250, 345, 382, 507, 526) wrap arg-type-checking blocks in `(let ((*ignoring-sdc?* (not *at-check-not-sdc?*))) ...)`. AT uses SDC to validate that an argument's type doesn't violate sibling-disjointness with an existing constraint (e.g. asserting "this thing isa Mammal" after it was already declared "isa Plant").

2. **AT control variable** — [`at-vars.lisp:103`](../../../larkc-cycl/at-vars.lisp#L103) defines `*at-check-not-sdc?*` (default t). This is the user-facing toggle for whether AT performs SDC checks at all. AT-state-var, so it can be bound per AT-pass.

3. **Independent CNFs check** — [`at-var-types.lisp:64`](../../../larkc-cycl/at-var-types.lisp#L64) — when validating a `(genls C1 C2)` formula's CNF expansion, if `(sdc? C1 C2)`, then disable SDC for the recursive arg-constraints check. The reasoning: if we're in the middle of asserting that `C1` is a subtype of `C2`, the prior SDC inference is by-construction false — don't let it propagate.

There are no consumers in the inference engine proper (no `inference/`-tree calls). SDC is exclusively a [canonicalization](../canonicalization/) / arg-type concern in the LarKC port — it gates which assertions are *allowed*, not which inferences fire.

## Public API surface

Working entry points (have bodies):

```
(sdc? c1 c2 &optional mt)                              ; central — sibling-disjoint?
(sdc-int? c1 c2)                                       ; mt-already-bound variant
(any-sdc-wrt? c1s c2 &optional mt)                     ; any of c1s vs c2
(any-isa-common-sdct c1 c2 &optional mt tv)            ; the witness search
(any-isa-common-sdct-among c1s c2 &optional mt tv)     ; multi-c1 variant
(isa-common-sdct? c1 c2 &optional mt)                  ; cheap predicate
(sdc-exceptions collection &optional mt)
(sdc-exceptions-int collection &optional mt)
(direct-sdc-exceptions collection &optional mt)
(establishing-superset? c1 c2 &optional mt assertion)
(establishing-instance-of? c1 c2 &optional mt assertion)
(clear-cached-all-isa-sdct)
```

Helper (used in marking pipeline):

```
(sbhl-mark-sd-c1-genls-and-non-c2-genls-isas c1 c2)
(sbhl-mark-sd-c1s-genls-and-non-c2-genls-isas c1s c2)
(sbhl-mark-sd-genls-isas c1-genl)
(sbhl-gather-first-sd-or-store-sd-candidates c2)
(sbhl-gather-sd-candidates c2-genl)
(sbhl-determine-sd-and-store-candidates c2-genl-isa)
(sbhl-sd-relevant-c2-genl-isa-candidate? c2-genl-isa)
(sbhl-determine-sd-path-with-no-exceptions c1)
(sbhl-determine-sd-path-with-no-exceptions-among c1s)
```

Stripped (have signatures, no bodies — design-truth, not absent):

```
(sdc c1 mt)               ; "the SD types that c1 inhabits" (collection of)
(max-sdc c1 mt)           ; most-specific SD types
(all-sdc c1 mt)            ; all SD types
(max-sdc-int c1)
(all-sdc-int c1)
(remote-sdc-wrt c1 c2 mt) ; SDC via genls transfer
(isa-sdct c &optional mt) ; SD-collection-types c is an instance of
(max-isa-sdct c &optional mt)
(applicable-sdct c &optional mt)
(gather-sdct-isas c)
(gather-if-sdct? c)
(all-isa-sdct c &optional mt)
(union-all-isa-sdct c &optional mt)
(sdc-element? x &optional mt)
(sdct-element? x &optional mt)         ; x is an instance of some SD-collection-type
(safe-sdct-element? x &optional mt)
(applicable-sdct? c &optional mt)
(declared-sdc-exceptions c &optional mt)
(sdc-exceptions-of-genls c &optional mt)
(direct-sdc-exception? c1 c2 &optional mt)
(sdc-exception? c1 c2 &optional mt)
(declared-sdc-exception? c1 c2 &optional mt)
(remote-sdc-exception? c1 c2 &optional mt)
(any-remote-sdc-exception-pair c1 c2 &optional mt)
(sdc-common-spec? c1 c2 &optional mt)
(remote-sdc-common-spec? c1 c2 &optional mt)
(sdct-elements c &optional mt)
(cols-with-applicable-sdct c &optional mt)
(why-sdc? c1 c2 mt behavior)            ; justifications
(assemble-sdc-just c1 c2)
(any-just-of-sdc c1 c2 mt)
(any-just-of-isa-sdct c &optional mt)
(why-sdc-exception? c1 c2 mt)
(why-declared-sdc-exception? c1 c2 mt)
(why-direct-sdc-exception? c1 c2 mt)
(why-remote-sdc-exception? c1 c2 mt)
(why-sdc-common-spec? c1 c2 mt)
(why-remote-common-spec? c1 c2 mt)
(isa-common-sdct-among? c1s c2 &optional mt)
(sdw-error tv ...)                      ; sibling-disjoint warning errors
(any-sdc-wrt c1s c2 mt)                 ; non-? variant — returns the witness, not just bool
(any-sdc-any? c1s c2s mt)
(any-sdc-any c1s c2s mt)
```

Plus two missing macros: `with-sbhl-sd-marking-spaces`, `with-sbhl-sd-genls-isas-spaces` (declared at the top of the file, no bodies). These would be the user-friendly wrappers around the four-deep `let` of marking-space allocations seen in `any-isa-common-sdct`.

## Caches

Two global caches:

| Cache | Purpose |
|---|---|
| `*cached-sbhl-sd-relevant-c2-genl-isa-candidate?-caching-state*` | Memoizes the per-candidate "is this in the genls-isas space and a sibling-disjoint collection?" check. |
| `*cached-all-isa-sdct-caching-state*` | Memoizes `(all-isa-sdct c)` — "what SD-collection-types is c an instance of?" |

Both registered at toplevel via `note-globally-cached-function`. The clear-functions are stripped except for `clear-cached-all-isa-sdct`. Cache invalidation lives in the SBHL module's after-adding hooks (when the genls or isa graph changes, these caches are stale) but the integration code is missing-larkc.

## Trace levels

```
*sdw-trace-level*  default 1
*sdw-test-level*   default 1
```

Diagnostic verbosity dials. Higher values cause `sdw-error` (stripped) to print intermediate marking-space contents during a query. The `sdw` prefix throughout (`why-sdw-...` would have been `why-sdc-...`; `sdw-error` should probably be `sdc-error`) is a typo / abbreviation drift; the original SubL name was something like "SD-warner" or "sibling-disjoint-warner."

## When does the SDC search run?

Three triggering situations:

1. **Asserting `(isa X C2)` when X is already known to be `isa C1`** — the AT (arg-type) check fires `sdc? C1 C2`. If true, the assertion is rejected as a sibling-disjointness violation. (Unless `*ignoring-sdc?*` is set or `establishing-instance-of?` returns true because the user is *currently* declaring this very co-instance relationship.)

2. **Asserting `(genls C1 C2)`** — the AT independent-CNFs check ([`at-var-types.lisp:64`](../../../larkc-cycl/at-var-types.lisp#L64)) calls `sdc? C1 C2` to spot the case where we're declaring a subtype relationship between two siblings of an SD-collection-type. The result is *suspending* SDC for the recursive validation pass — explicitly allowing the otherwise-contradictory assertion to be added. This is by design: a user asserting `(genls Whale Mammal)` knowing that Whale was previously typed as a SiblingDisjointCollection sibling of Mammal is *redoing the typing*, and SDC must defer.

3. **Diagnostic / introspection queries** — the `why-sdc?` family (all stripped) would have allowed querying *why* a particular SDC conclusion was reached (which SD-type, which path, which exceptions). These are part of Cyc's general justification infrastructure, gone in LarKC.

There is **no inference-time consumer** — SDC is not a removal-module or transformation-module input. It exists purely to gate KB editing.

## CFASL / persistence

SDC owns no CFASL-serialized data. The marking spaces are runtime-only; the candidate store is per-call. The `siblingDisjointExceptions` predicate's data is stored as ordinary KB assertions and reaches SDC via [kb-mapping](../kb-access/kb-mapping.md)'s `pred-values-in-relevant-mts`. The two caches are runtime memoization, not persisted.

So a clean rewrite carries no persistence baggage from this module.

## Notes for a clean rewrite

- **The two-phase exception-bypass machinery is the load-bearing complexity.** A simpler "find any common SD-type, check it has no relevant exception" wouldn't model the real Cyc semantics — exceptions can be carved through the genls graph, so the search has to gather candidates and then prove a path through the type lattice that doesn't cross any exception pair. A clean rewrite should preserve this two-phase structure.
- **The four marking spaces should be one struct** rather than four dynamic vars. The `*sd-c1-genls-space*` / `*sd-c2-genls-space*` / `*sd-genls-isas-space*` / `*sd-candidate-store*` family is always allocated together, freed together, and never used outside this file. A `sd-search-context` struct passed explicitly is cleaner and re-entrant by construction.
- **The two missing macros (`with-sbhl-sd-marking-spaces`, `with-sbhl-sd-genls-isas-spaces`) are the right abstraction** — implement them in the rewrite. They wrap the marking-space allocate/free in a `with-` form so the four-deep `let` ladder in `any-isa-common-sdct` becomes one-line.
- **`establishing-superset?` / `establishing-instance-of?` are KB-edit-time defenses.** They consult `*added-assertion*` to detect when the user's *current* edit would contradict an SDC inference. A clean rewrite should keep this — without it, SDC actively blocks legitimate KB edits.
- **The `*ignoring-sdc?*` opt-out** is heavily used by AT routines to disable SDC for specific check passes. A clean rewrite should make this *less* of a special var and more of a parameter on the entry points: `(sdc? c1 c2 :enabled? t)` rather than a dynamic-binding gymnastic.
- **`*sdc-exception-transfers-thru-specs?*` and `*sdc-common-spec-exception?*` are off by default for performance.** Document this explicitly; KB curators who need broader exception semantics should know they're paying a price. Better still: make them per-mt configuration so different KB regions can have different SDC strictness.
- **The justification family (`why-*`) is entirely missing.** A clean rewrite that wants to explain SDC conclusions to users (e.g. via the KE) needs to rebuild this — for each `(sdc? c1 c2)` true, return the witness SD-type, the genls path, and the exceptions checked. The Cyc engine has this; the LarKC port stripped it.
- **The `sdw-` prefix is inconsistent** with `sdc-` everywhere else. Likely an early-Cyc renaming that wasn't completed. Clean it up.
- **The `clear-cached-all-isa-sdct` is the only ported cache-clear.** A clean rewrite needs cache invalidation tied to genls/isa graph mutations (after-adding/after-removing hooks). Currently this is stripped except for the manual clear.
- **The `:tv` (truth-value) parameter is plumbed throughout `any-isa-common-sdct` but is mostly used to set `*sbhl-tv*`** — most callers pass nil. A clean rewrite can drop the parameter from the public API and make it a `:tv` keyword on the rare callers that need non-default TV.
- **SDC is conceptually a [named-hierarchies.md](named-hierarchies.md) sibling** — it's a disjointness predicate just like `disjointWith`. The reason it's its own doc is mechanical (large, with self-contained machinery); the reason it lives next to `disjoint-with` in the source is conceptual. A clean rewrite might unify them as `disjointness` with sub-cases for "directly asserted" vs. "via SD-collection-type."
- **Default-disjointness vs. asserted-disjointness is a real semantic split.** `disjointWith` is "C1 and C2 are disjoint, period." SDC is "C1 and C2 are disjoint *unless someone says otherwise*." Many systems conflate these; Cyc separates them deliberately. The rewrite must preserve the distinction.
