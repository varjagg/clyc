# Argumentation

The argumentation system is the **truth-value combinator** for assertions. Given a set of arguments (justifications) for an assertion, decide what the assertion's truth-value should be. Used by the TMS (truth maintenance system) when an assertion's argument list changes — adding or removing a deduction may flip the assertion from believed to unknown to disbelieved.

The file is small (116 lines) but the algorithm is the core of how Cyc reconciles multiple lines of evidence about the same fact.

Source file: `inference/harness/argumentation.lisp`

## Truth values

A *truth value* (TV) is one of:

- `:true-mon` — monotonically true (a strict logical proof; cannot be defeated by adding more facts)
- `:false-mon` — monotonically false
- `:true-def` — true by default (defeasible; could be defeated)
- `:false-def` — false by default
- `:unknown` — no opinion

The TV partitions into three axes:
- **Polarity:** true vs. false (vs. unknown)
- **Strength:** monotonic vs. default (vs. unknown)
- **Combined:** these are five points in a 2×2+1 product

`tv-truth(tv)` extracts polarity (`:true | :false | :unknown`); `tv-strength(tv)` extracts strength (`:monotonic | :default | :unknown`); `tv-from-truth-strength(truth, strength)` constructs.

## What is an argument?

An *argument* is a justification for the assertion: a deduction (proof from rules) or an assertion (the fact was directly asserted). Each argument has its own truth value (`argument-tv`) and strength (`support-strength`).

`asserted-argument-p(arg)` distinguishes asserted arguments from deduced ones — an asserted argument has higher precedence in argumentation.

## `compute-assertion-tv` — the entry point

```
compute-assertion-tv(assertion):
  let arguments = assertion-arguments(assertion)
  let old-tv = cyc-assertion-tv(assertion)
  let new-tv = perform-argumentation(arguments)
  if old-tv ≠ new-tv:
    kb-set-assertion-truth(assertion, tv-truth(new-tv))
    kb-set-assertion-strength(assertion, tv-strength(new-tv))
    possibly-update-sbhl-links-tv(assertion, old-tv)
  return new-tv
```

This is what the TMS calls when an assertion's argument list changes. The new TV is computed from arguments, written back to the KB if changed, and SBHL links (the subsumption-graph indexes) are updated to reflect the new truth.

`possibly-update-sbhl-links-tv` is the propagation step — when a `(genls A B)` GAF flips truth, the SBHL graph for `genls` must be refreshed because the link is no longer valid.

## `perform-argumentation` — the algorithm

The decision procedure when the assertion has multiple arguments:

```
perform-argumentation(arguments):
  if no arguments: return :unknown
  if one argument: return its argument-tv
  ; multiple arguments — apply precedence rules
  
  ; Step 1: agreement check
  let tv = (first argument).tv
  if all arguments agree on tv: return tv
  
  ; Step 2: monotonic contradiction
  if both :true-mon and :false-mon present:
    resolve-contradiction (missing-larkc 35548)
  
  ; Step 3: monotonic precedence
  if any :true-mon present: return :true-mon
  if any :false-mon present: return :false-mon
  
  ; Step 4: asserted argument precedence
  if any asserted-argument present:
    return its argument-tv
  
  ; Step 5: default contradiction
  if both :true-def and :false-def present:
    resolve-contradiction (missing-larkc 35547)
  
  ; Step 6: default precedence
  if any :true-def present: return :true-def
  if any :false-def present: return :false-def
  
  ; Step 7: nothing decisive
  return :unknown
```

The precedence rules in plain English:

1. **Agreement is consensus.** If every argument concludes the same TV, that's the answer. No conflict resolution needed.
2. **Monotonic beats default.** A strict logical proof can't be overridden by a default rule. If any argument gives `:true-mon`, the assertion is true even if other defaults disagree.
3. **Monotonic contradictions are exceptional.** If both `:true-mon` and `:false-mon` are present, the KB has a strict contradiction — call the resolver (and probably emit a warning). `*tms-treat-monotonic-contradiction-as-unknown?*` (default nil) controls whether to treat this as `:unknown` or as an error.
4. **Asserted arguments beat deduced.** A direct assertion in the KB takes precedence over any deduction's TV, *if* monotonic arguments are absent.
5. **Default contradictions resolve via the resolver.** Two defaults disagreeing is the classical "default reasoning conflict" — typically resolved via `more-specific-than` ordering or by abnormality.
6. **Defaults dominate `:unknown`.** Any default TV beats `:unknown`.

The `:unknown` outcome is what you get when arguments are weak or absent — the assertion is "no opinion."

## Strength combination

`strength-combine(s1, s2)` for combining the strengths of multiple supports:

| s1 | s2 | result |
|---|---|---|
| any | `:unknown` | `:unknown` |
| `:unknown` | any | `:unknown` |
| any | `:default` | `:default` |
| `:default` | any | `:default` |
| `:monotonic` | `:monotonic` | `:monotonic` |

A chain of supports is only as strong as its weakest link. If any support is `:unknown`, the chain is unknown. If any is `:default`, the chain is default. Only when *all* supports are monotonic is the chain monotonic.

`compute-supports-tv(supports, &optional truth)` is the public combinator: given a list of HL supports, compute the resulting TV. Walks the list, accumulates strength via `strength-combine`, then constructs the final TV via `tv-from-truth-strength`.

## When does argumentation fire?

| Trigger | Caller |
|---|---|
| Assertion's argument list changes | TMS, which calls `compute-assertion-tv` |
| Argumentation result differs from current | Triggers SBHL link update |
| Inference produces a new proof | The proof's TV is computed via `compute-supports-tv` |
| Worker creates a removal/transformation link | The link's TV uses argumentation if multiple supports |

The TMS is the dominant caller — it runs argumentation continuously as the KB evolves. Fresh deductions add arguments; retracted assertions remove them. Each change triggers a recomputation for the affected assertion.

## Cross-system consumers

- **TMS** (`tms.lisp` in `kb-access/`) — calls `compute-assertion-tv` on every assertion-argument change.
- **Workers** — `compute-supports-tv` is used by removal and transformation workers when constructing the link's `support-strength`.
- **HL modules** — return `support-strength` values that argumentation consumes.
- **SBHL** — is updated downstream when argumentation flips a TV.
- **Argumentation tests** — `*tms-treat-monotonic-contradiction-as-unknown?*` is rebound for tests that intentionally set up contradictions.

## Notes for the rewrite

- **TVs are a 2-axis enum.** Express them in the rewrite as a struct or two-field record, not a flat keyword. The current keyword form (`:true-mon`, etc.) collapses two dimensions into one.
- **The precedence ordering is fixed.** Monotonic > asserted > default > unknown. Don't break this — it's the core of how Cyc handles default reasoning.
- **`resolve-contradiction` is the missing piece.** The LarKC port stubs out both the monotonic and default contradiction resolvers. The clean rewrite must implement them. The monotonic resolver should *report* the contradiction (it's a KB error); the default resolver should consult `more-specific-than` and abnormality to pick a winner.
- **`*tms-treat-monotonic-contradiction-as-unknown?*` is a debug flag.** Production should error on monotonic contradictions; tests can rebind to silence them.
- **`compute-supports-tv` and `perform-argumentation` are different.** The first computes a TV from a single chain of supports; the second arbitrates across multiple competing arguments. Keep them separate.
- **`possibly-update-sbhl-links-tv` is the only assertion → SBHL hook.** Make sure this fires on every TV change; otherwise SBHL gets stale.
- **Assertion vs. deduction asymmetry.** An asserted argument outranks a deduced argument of equal strength. The clean rewrite must preserve this rule.
- **Strength combination is a min-lattice.** Unknown < default < monotonic. The combinator is the meet operation. Don't reinvent — use a sealed enum and a min function.
- **Argumentation runs hot.** Every assertion change causes one. Profile the rewrite; the keyword equality checks in `perform-argumentation` could be a hotspot if the assertion has many arguments.
- **`asserted-argument-p` distinguishes assertion arguments from deduction arguments.** Keep the predicate; the `find-if` in step 4 is what makes assertion-precedence work.
- **The 5 truth values + the strength axis cover the design space.** Resist adding new TVs (e.g. probabilistic). Cyc's design is committed to this 2-axis taxonomy.
