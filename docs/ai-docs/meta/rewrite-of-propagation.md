# Rewrite-of propagation

`rewrite-of-propagation.lisp` implements **assertion propagation across `#$rewriteOf` links** — when the KB knows that two terms `A` and `B` are *rewriteable into each other* (asserted via `(#$rewriteOf A B)`), an assertion stated about `A` should also be effectively stated about `B`. This file is the propagation engine that, on assertion add/change, walks the assertion's terms looking for any term that participates in a `rewriteOf` relation and produces parallel assertions on the other side of each such link.

**Almost the entire file is missing-larkc.** Only one function has a body in the port:
- `perform-rewrite-of-propagation` — the entry point. It checks the enable flag, gathers the set of forts in the assertion that have outgoing `rewriteOf` assertions, and for each one calls `(missing-larkc 4713)` — the actual per-fort propagation step is stripped.
- `fort-with-some-source-rewrite-of-assertions` — a one-line predicate, calls `some-source-rewrite-of-assertions-somewhere?` from `equality-store.lisp`.

Everything else is a comment stub:
- `rewrite-of-after-adding (source target assertion)` — the after-adding hook (the trigger that fires when a `(#$rewriteOf source target)` assertion enters the KB).
- `rewrite-of-after-adding-internal`
- `propagate-rewrite-of-assertion`
- `perform-rewrite-of-propagation-internal`
- `propagate-assertion-via-rewrite-of (source-term target-term assertion mt)`
- `should-propagate-rewrite-of-cnf (source-term target-term cnf)`
- `note-should-propagate-rewrite-of-cnf`
- `propagate-rewrite-of-cnf` and `propagate-rewrite-of-cnf-internal`
- `propagate-rewrite-of-atomic-sentence`
- `determine-propagate-rewrite-of-mt`

The skeleton is preserved as a spec for the rewrite — the function names lay out the propagation algorithm in stages.

## What `#$rewriteOf` means in the KB

`#$rewriteOf` is the CycL predicate for **definitional equality / rewriting** between two terms. `(#$rewriteOf A B)` says "anywhere A appears, B can be substituted, and vice versa, *for the purposes of propagating assertions*." It is weaker than `#$equals` (which would assert genuine identity reasoned over by the equality engine in [graph-reasoning/named-hierarchies.md](../graph-reasoning/named-hierarchies.md)) — `rewriteOf` is a *propagation directive*, not a logical claim. The directive says "the curator wants every fact about A to also be a fact about B."

The directive is asymmetric per-pair (the `rewriteOf` predicate is in fact symmetric, but the propagation queries for "outgoing" links by treating the indexed term as the *source* and looking up assertions where it appears in arg-2 position — `some-pred-assertion-somewhere? #$rewriteOf OBJ 2`).

Typical use: a constant is renamed, but rather than rewrite every assertion, the curator asserts `(#$rewriteOf NewName OldName)` and lets propagation extend the new constant's facts to cover the old one. Or two separately-developed taxonomies converge and one node is declared a rewrite of another.

## The trigger situations

A propagation step fires in two distinct circumstances:

1. **A non-`rewriteOf` assertion is added/changed and one of its terms has outgoing `rewriteOf` links.** Triggered from `tms.lisp` line 240 — after the TMS marks an assertion as having changed (truth flipped), it calls `(perform-rewrite-of-propagation assertion)`. The propagation walks the assertion's expression with `expression-gather`, collects every fort that has any source `rewriteOf` assertion, and for each one synthesizes and asserts the rewritten version of the original assertion (the missing-larkc step).
2. **A `(#$rewriteOf SOURCE TARGET)` assertion is itself added.** Triggered via the `rewrite-of-after-adding` HL after-adding hook (registered via `(register-kb-function 'rewrite-of-after-adding)` in the setup phase). The hook fires whenever a new `rewriteOf` fact enters the KB, and propagates *all existing assertions about source* to also be about target. This path is entirely missing-larkc in the port — the function is named, registered as a KB function, but has no body.

Both situations end at the same operation: walk the assertion's CNF, substitute source→target in each atomic sentence, and assert the result in an appropriately-determined MT. The MT determination (`determine-propagate-rewrite-of-mt`) is its own subproblem — the rewritten assertion's MT is generally the same as the original but may need narrowing if the `rewriteOf` is itself stated only in a specific MT.

## State the file owns

| Variable | Meaning | Lifecycle |
|---|---|---|
| `*enable-rewrite-of-propagation?*` (defparameter, default `t`) | Master kill switch. When nil, `perform-rewrite-of-propagation` becomes a no-op. | Read at every `perform-rewrite-of-propagation` call. Set by ops/curators when bulk-loading content where propagation would explode. |
| `*propagate-rewrite-of-source-term*` (defparameter, default `nil`) | Dynamic binding of the source term during a propagation step. | Bound by the (stripped) inner propagation function, read by helpers that need to know "which term is being substituted out." |
| `*propagate-rewrite-of-target-term*` (defparameter, default `nil`) | Dynamic binding of the target term during a propagation step. | Same. |
| `*propagate-rewrite-of-assertion*` (defparameter, default `nil`) | Dynamic binding of the assertion currently being propagated. | Same — used by debug/logging code in the stripped bodies. |

The three dynamic bindings are the standard SubL idiom for passing context "out-of-band" through a deep recursive walker without having to thread parameters through every helper. Used to implement the propagation as a self-recursive walk over the assertion's CNF where every leaf substitution can read the current source/target/assertion.

## How other systems consume this

Two consumers, one stripped, one live:

- **`tms.lisp`** (line 240) — the TMS calls `perform-rewrite-of-propagation` from inside `tms-recompute-truth-of-assertion` whenever the assertion's truth value changes. This is the live propagation trigger.
- **The HL after-adding pipeline** — `rewrite-of-after-adding` is registered as a KB function for the `#$rewriteOf` predicate's after-adding hook. Triggered by [kb-access/forward-propagation.md](../kb-access/forward-propagation.md) when a new `rewriteOf` fact is added. Stripped in the port; preserved as a registration intent.
- **`equality-store.lisp`** provides the lookup oracle: `some-source-rewrite-of-assertions-somewhere?` returns true iff a fort has any outgoing `rewriteOf` assertions in any MT.

The `somewhere-cache` for `#$rewriteOf` (in `somewhere-cache.lisp` per the search above) is what makes the lookup cheap: a global cache of "every fort that has at least one `rewriteOf` assertion as its arg-2." Without that cache, `perform-rewrite-of-propagation` would need to query the KB for every assertion's every fort, every time.

## Where this fits among the equality systems

Cyc has multiple ways to say "two terms are the same":

| Predicate | Engine | Treatment |
|---|---|---|
| `#$equals` | The equality store + equality reasoning ([graph-reasoning/named-hierarchies.md](../graph-reasoning/named-hierarchies.md)) | Logical identity; reasoned over by the equality engine. Substitution happens at *query time* when the inference engine matches a literal against `equals`-related terms. |
| `#$coExtensional` | A weaker form of equals (same membership but not necessarily identical) | Similar. |
| `#$rewriteOf` | This file. | Substitution happens at *assertion time*. The KB stores both versions as separate assertions. |
| Constant merge | `kb-content` operations | Two constants are physically unified into one; the loser ceases to exist. |

`rewriteOf` is the **eager propagation** mechanism: write twice, query simply. `equals` is the **lazy reasoning** mechanism: write once, query has to consider all equivalents. Both have their place — the curator picks based on whether the two terms are interchangeable enough that materializing every assertion in both forms is desired.

## Notes for a clean rewrite

- **The entire propagation pipeline is missing-larkc but the spec is the function names.** Reconstructing it: (1) walk the assertion's CNF; (2) at each atomic sentence, look up `rewriteOf` for each fort term; (3) for each `(rewriteOf SRC TGT)` link found, substitute and re-assert the modified atomic sentence; (4) determine the appropriate MT via `determine-propagate-rewrite-of-mt`. The stripped helpers (`should-propagate-rewrite-of-cnf`, `propagate-rewrite-of-atomic-sentence`) suggest the propagation is per-CNF and per-atomic-sentence with intermediate filtering.
- **`*enable-rewrite-of-propagation?*` exists for a reason: bulk loads.** When loading a snapshot, the assertions arrive in some order and propagating each one as it lands creates O(N×M) duplicate-assertion churn. A clean rewrite should disable propagation during bulk load and run a single sweep at the end (or during background quiescence).
- **The dynamic `*propagate-rewrite-of-source/target/assertion*` triple is a SubL workaround.** A clean rewrite should pass these as parameters through a struct or thread them lexically; relying on three dynamic specials makes the propagation hard to nest, hard to parallelize, and hard to debug.
- **Asymmetric source/target despite symmetric predicate.** The implementation uses arg-2 indexing (`some-pred-assertion-somewhere? #$rewriteOf OBJ 2`) which means it queries "is OBJ the *target* of a rewriteOf?" — so propagation flows from source to target. The predicate itself is symmetric (per CycL), but the propagation is one-way. A clean rewrite should make this explicit: either propagate both ways, or define the predicate as asymmetric in the first place. The current state is a hidden directionality decision.
- **MT determination is non-trivial and deserves its own design pass.** `(#$rewriteOf A B)` stated in MT M means "in M, A and B are interchangeable" — but does that mean an assertion about A in MT N (where N inherits from M) should propagate to B in N, or in M? Currently `determine-propagate-rewrite-of-mt` is missing-larkc; the answer needs a real spec.
- **Consider replacing `rewriteOf` with constant merge.** The use case "two terms should be treated identically" is what constant merge solves more cleanly — one canonical term, all assertions automatically about it. `rewriteOf` exists in part because merge is destructive (the loser is gone forever); a clean rewrite that supports non-destructive merge (alias-with-rollback) could subsume `rewriteOf` entirely.
- **The propagation should be journaled.** When propagation creates a derived assertion, the derived assertion needs to remember its source so that retracting the source retracts the derivative. The current design appears to store derived assertions as ordinary assertions (no link back); that means retract-the-source leaves orphaned propagated assertions in the KB. A clean rewrite should either tag propagated assertions as "by `rewriteOf` from X" or treat them as a deduction with a justification, so the TMS can clean up.
- **`fort-with-some-source-rewrite-of-assertions` is just a thin wrapper around `some-source-rewrite-of-assertions-somewhere?`.** Inline it; the wrapper exists because `expression-gather` needs a function-of-one-argument and the underlying function is already that. No need for two names.
