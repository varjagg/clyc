# TMS — Truth Maintenance System

The TMS coordinates **what happens to dependent state when a piece of the KB is added or removed**. Its three jobs:

1. When an argument (asserted-argument or deduction) is added to or removed from an assertion, recompute the assertion's truth-value, propagate to dependents, and either keep the assertion alive or remove it.
2. When an assertion is removed, cascade the removal: invalidate every deduction that used it as a support, recursively recompute the dependent assertions' truth-values, and possibly remove them.
3. When the KB has been modified, detect **circular justifications** — assertions whose only justification path returns to themselves, with no asserted root — and remove them.

The implementation is small but recursive. The shape:

- `tms-add-deduction-for-cnf` / `tms-add-deduction-for-assertion` — add path.
- `tms-remove-argument`, `tms-remove-assertion`, `tms-remove-assertion-list` — remove paths.
- `tms-recompute-assertion-tv`, `tms-recompute-dependents`, `tms-remove-dependents` — propagation.
- `some-belief-justification` + `gather-circular-deduction` + `mark-circular-assertion` — the circularity-detection algorithm.

A large fraction of the file (`tms-reconsider-*`, `tms-recompute-deduction-tv`, `tms-reprove-deduction-*`, `tms-deduction-stale-wrt-*`, `remove-circularly-supported-assertions`, `independently-deducible-assertion?`) is missing-larkc — the **reconsideration** subsystem (re-evaluating whether stale deductions are still valid after KB change) and the **periodic circularity audit**. The clean rewrite must implement these.

## When does the TMS run?

Five triggering situations:

1. **A new argument is added to an assertion.** `tms-create-asserted-argument-with-tv assertion tv`, `tms-add-new-deduction assertion supports tv`, `tms-add-deduction-for-assertion assertion supports truth`, `tms-add-deduction-for-cnf cnf mt supports truth direction var-names`. After creating the new argument, the TMS recomputes the assertion's TV, fires `handle-after-addings`, and rolls back if anything fails.

2. **An argument is removed.** `tms-remove-argument argument assertion`. The argument is removed; the assertion's TV is recomputed; if the assertion now has no surviving justifications, it's queued for removal; the dependents of the (possibly-removed) assertion are processed.

3. **An assertion is removed.** `tms-remove-assertion assertion` or `tms-remove-assertion-list list`. Walks the assertion's arguments, removes each, then strips the assertion from the indices and storage.

4. **A direction-change.** `tms-change-direction assertion direction` — sets a new direction (`:forward` / `:backward` / `:code`) and queues for forward propagation if newly-forward.

5. **A circular-justification audit.** `some-belief-justification assertion` walks the deduction graph from the assertion, gathering circular deductions and asserted-assertion roots; if no asserted root is reachable, the assertion is "purely circularly supported" and should be removed. Called from inside `tms-propagate-removed-argument` when `*check-for-circular-justs*` is set.

## Add path

`tms-add-deduction-for-cnf cnf mt supports &optional truth direction var-names`:

```
1. find-or-create-assertion cnf mt var-names direction
2. tms-add-deduction-for-assertion assertion supports truth
3. → returns (deduction, redundant?)
```

`tms-add-deduction-for-assertion assertion supports &optional truth`:

```
1. tms-direct-circularity assertion supports?
   → if assertion ∈ supports: return (nil, t)  -- redundant, can't add a self-supporting deduction
2. find-deduction assertion supports truth
   → if existing: return (existing, t)
3. tv := compute-supports-tv supports truth
4. new-argument := tms-add-new-deduction assertion supports tv
5. return (new-argument, nil)
```

`tms-add-new-deduction`:

```
1. deduction := create-deduction-with-tv assertion supports tv
2. tms-postprocess-new-argument assertion deduction
3. return deduction
```

`tms-postprocess-new-argument`:

```
unwind-protect:
  tms-recompute-assertion-tv assertion           -- TV may change due to new argument
  handle-after-addings argument assertion        -- forward-propagation hook
  successful? = t
on failure (successful? still nil):
  tms-remove-argument argument assertion         -- roll back
```

`tms-create-asserted-argument-with-tv assertion tv`:

```
1. new-asserted-argument := kb-create-asserted-argument-with-tv assertion tv
2. tms-postprocess-new-argument assertion new-asserted-argument
```

The asserted-argument case is the same shape as the deduction case — both go through `tms-postprocess-new-argument`, which is the universal "after argument added" entry point.

## Remove path

### `tms-remove-argument argument assertion`

```
when (valid-argument argument) and (not tms-argument-being-removed?):
  tms-note-argument-being-removed (argument)
    remove-argument argument assertion          -- detach from assertion
    if assertion is an assertion:
      if still valid: assertion-removed? := tms-propagate-removed-argument argument assertion
      else: assertion-removed? := t
    if assertion is an hl-support:
      kb-hl-support := find-kb-hl-support assertion
      if kb-hl-support: assertion-removed? := missing-larkc 11075   -- tms-remove-kb-hl-support
      else: assertion-removed? := t
  return assertion-removed?
```

The `tms-note-argument-being-removed` macro adjoins `argument` to `*tms-deductions-being-removed*` (if it's a deduction) for the duration of the body. The `tms-argument-being-removed?` test breaks recursive cycles in the cascade.

### `tms-propagate-removed-argument argument assertion`

The core of the cascade:

```
with-kb-hl-support-rejustification
  assertion-removed? := tms-recompute-assertion-tv assertion
  when (valid-assertion? assertion):
    unwind-protect:
      if assertion-removed?:
        tms-note-assertion-being-removed (assertion)
          handle-after-removings argument assertion    -- forward-propagation removal hook
      else:
        handle-after-removings argument assertion
    on exit:
      if assertion-removed?:
        if (valid-assertion assertion):
          if tms-assertion-being-removed?:
            tms-remove-assertion-int-2 assertion       -- final removal step (skips re-cascade)
          else:
            tms-remove-assertion-int assertion         -- full removal cascade
      else (assertion not removed by tv):
        when *check-for-circular-justs* and not (some-belief-justification assertion):
          tms-remove-assertion assertion              -- circularity-detected removal
          assertion-removed? := t
  return assertion-removed?
```

Two paths to removal:
- **TV says the assertion has no truth value anymore** (`tms-recompute-assertion-tv` returns t): expected.
- **TV is still valid but every justification is circular** (no asserted root): kicks in only when `*check-for-circular-justs*` is on.

The wrapping `with-kb-hl-support-rejustification` defers kb-hl-support rejustification to the outermost scope so re-entrant cascades coalesce. See [kb-hl-supports.md](../core-kb/kb-hl-supports.md).

### `tms-remove-assertion assertion`

The user-callable wrapper:

```
when (valid-assertion? assertion) and (not tms-assertion-being-removed?):
  tms-remove-assertion-int assertion
```

`tms-remove-assertion-int`:

```
with-kb-hl-support-rejustification
  tms-note-assertion-being-removed (assertion)
    arguments := assertion-arguments assertion
    if no arguments:
      tms-remove-assertion-int-2 assertion         -- already a stub assertion, just delete
    else:
      for each argument:
        tms-remove-argument argument assertion     -- triggers cascade
return nil
```

`tms-remove-assertion-int-2`:

```
remove-term-indices assertion                      -- strip from KB indexes
remqueue-forward-assertion assertion               -- remove from forward-propagation queue
when (rule-assertion? assertion):
  clear-transformation-rule-statistics assertion   -- inference-cost cache cleanup
unless (tou-assertion? assertion):
  remove-assertion assertion                       -- final dispatch to assertion-low storage
```

`tou-assertion?` (termOfUnit) — these are skipped at the final-remove step because TOU assertions own a NART; removing them needs special handling done elsewhere.

### `tms-remove-dependents assertion`

For each `dependent-deduction` in `assertion-dependents`:
- if `valid-deduction?`: `tms-remove-argument dependent-deduction (deduction-assertion dependent-deduction)`.

Effectively: walk every deduction that listed this assertion as a support, and remove each of those deductions. Each removal recursively triggers `tms-recompute-assertion-tv` on the deduction's conclusion.

### `tms-remove-assertion-list assertions`

Tail call to `tms-remove-nonempty-assertion-list` which iterates `tms-remove-assertion`. Used by `remove-term-indices` cascades and other bulk-removal paths.

## TV recomputation

`tms-recompute-assertion-tv assertion`:

```
if assertion has no arguments:
  tms-note-assertion-being-removed:
    tms-remove-dependents assertion
  remove? := t
else:
  old-tv := cyc-assertion-tv assertion
  new-tv := compute-assertion-tv assertion
  cond:
    *bootstrapping-kb?*: (no-op — KB load suppresses TMS)
    old-tv == new-tv:    (no-op — nothing changed)
    truth(old) == truth(new):
      missing-larkc 12462                  -- update strength only (truth-value unchanged but strength shifted)
    else:
      tms-remove-dependents assertion      -- truth value changed; dependents must reprove
      changed? := t
when changed?:
  perform-rewrite-of-propagation assertion -- propagate equality/rewrite-of conclusions
  when (assertion is :forward):
    queue-forward-assertion assertion       -- re-queue for forward inference
return remove?
```

`compute-assertion-tv` (defined elsewhere) reads the assertion's arguments and combines their TVs (most-specific-tv-first, with strength composition). If the result is "no TV at all" (no surviving argument supports any truth-value), the assertion has nothing to assert.

## Circular-justification detection

When an assertion's only justifications are deductions whose supports trace back to itself — without going through any asserted-assertion — it's "purely circularly supported." Such an assertion should be removed because it has no anchor in the asserted KB.

The algorithm:

```
some-belief-justification assertion &optional asserted-assertions-to-ignore:
  if assertion is asserted (and not in ignore-list): return t
  if assertion has no arguments: return nil

  (let ((*circular-deductions* nil)
        (*circular-assertions* nil)
        (*circular-local-assertions* nil)
        (*circular-target-assertion* assertion)
        (*circular-complexity-count* 0))
    (catch :just-found
      ;; phase 1: gather all deductions and supporting assertions reachable from this
      ;;          assertion's arguments
      for each argument of assertion:
        when deduction:
          gather-circular-deduction argument

      ;; phase 2: for each gathered supporting assertion that is asserted,
      ;;          mark every assertion reachable backward from it; if we reach
      ;;          *circular-target-assertion*, throw :just-found
      for each supported-assertion in *circular-assertions*:
        when asserted? and not in ignore: mark-circular-assertion supported-assertion

      nil))   -- if no throw: not circularly believable
```

`gather-circular-deduction deduction asserted-assertions-to-ignore`:

```
unless deduction in *circular-deductions*:
  push deduction *circular-deductions*
  inc-circular-complexity-count
  for each support of deduction:
    when assertion?:
      push support *circular-assertions*
      inc-circular-complexity-count
      unless (asserted? and not in ignore):
        for each argument of support:
          when deduction?: gather-circular-deduction argument
```

`mark-circular-assertion assertion`:

```
when assertion == *circular-target-assertion*: throw :just-found t
unless assertion in *circular-local-assertions*:
  push assertion *circular-local-assertions*
  for each deduction in (circular-deductions-with-assertion assertion):
    when (believed-circular-deduction deduction):
      mark-circular-assertion (deduction-assertion deduction)
```

`believed-circular-deduction deduction`:

```
ans := nil
for each support of deduction:
  when assertion? and support not in *circular-local-assertions*:
    ans := t
    break
return (not ans)
```

A deduction is *believed* iff every assertion-support of it is in the local-assertions set (i.e. provably reachable backward from an asserted root).

`*circular-complexity-count*` is a budget — stops the search at `*circular-complexity-count-limit*` (default 50) to bound runtime. When exceeded, throws `:just-found t` (treating it as believable, conservative).

The whole algorithm runs in `some-belief-justification`'s catch block:
- If the search throws `:just-found`, the assertion has a believable justification (either an asserted root or an exceeded complexity budget).
- If the search completes without throwing, the assertion is purely circularly supported and should be removed.

## Variables

```
*tms-assertions-being-removed*    nil  defparameter — currently-removing assertions (cycle break)
*tms-deductions-being-removed*    nil  defparameter — currently-removing deductions
*circular-deductions*             nil  defparameter — gathered during circularity check
*circular-assertions*             nil  defparameter — supporting assertions seen
*circular-target-assertion*       nil  defparameter — the assertion being checked
*circular-local-assertions*       nil  defparameter — backward-reachable from an asserted root
*circular-complexity-count*       0    defparameter — circular-search budget counter
*circular-complexity-count-limit* 50   defparameter — circular-search budget cap (nil for unlimited)
```

## Macros

`tms-note-assertion-being-removed (assertion) body` — binds `*tms-assertions-being-removed*` with `assertion` adjoined for the body.

`tms-note-deduction-being-removed (deduction) body` — same for deductions.

`tms-note-argument-being-removed (argument) body` — dispatches: if `argument` is a deduction, wraps in the deduction macro; otherwise just runs body in a progn.

These three macros use `let`/`adjoin` (per-thread dynamic) to mark "this is currently being removed" so re-entrant cascade calls can detect and skip.

## Public API surface

```
;; Variables
(*tms-assertions-being-removed*) (*tms-deductions-being-removed*)
(*check-for-circular-justs*)        ; defined elsewhere, gates circularity check
(*circular-complexity-count*) (*circular-complexity-count-limit*)
(*circular-deductions*) (*circular-assertions*) (*circular-target-assertion*)
(*circular-local-assertions*)

;; Predicates
(tms-assertion-being-removed? assertion)
(tms-deduction-being-removed? deduction)
(tms-argument-being-removed? argument)

;; Add path
(tms-create-asserted-argument-with-tv assertion tv)
(tms-add-new-deduction assertion supports tv)
(tms-add-deduction-for-assertion assertion supports &optional truth)
(tms-add-deduction-for-cnf cnf mt supports &optional truth direction var-names)
(tms-postprocess-new-argument assertion argument)
(tms-direct-circularity assertion supports)

;; Remove path
(tms-remove-argument argument assertion)
(tms-propagate-removed-argument argument assertion)
(tms-remove-assertion assertion)
(tms-remove-assertion-int assertion)
(tms-remove-assertion-int-2 assertion)
(tms-remove-assertion-list assertions)
(tms-remove-nonempty-assertion-list assertions)
(tms-remove-deduction deduction)            ; missing-larkc body
(tms-remove-mt-arguments assertion &optional mt) ; missing-larkc body
(tms-remove-deduction-for-assertion assertion supports &optional truth) ; missing-larkc body
(tms-remove-dependents assertion)

;; TV recomputation
(tms-recompute-assertion-tv assertion)
(tms-recompute-dependents-tv assertion)     ; missing-larkc body
(tms-recompute-deduction-tv deduction)      ; missing-larkc body
(tms-recompute-dependents assertion)        ; missing-larkc body

;; Direction
(tms-change-direction assertion direction)
(tms-change-asserted-argument-tv assertion argument tv)  ; missing-larkc body

;; Reconsideration (mostly missing-larkc)
(tms-reconsider-assertion-deductions assertion)
(tms-reconsider-assertion-dependents assertion)
(tms-reconsider-deduction deduction)
(tms-deduction-stale-wrt-supports? deduction)
(tms-deduction-stale-wrt-exceptions? deduction)
(tms-reprove-deduction-query-sentence deduction)
(tms-reprove-deduction-query-mt deduction)
(tms-reprove-deduction-query-properties ...)
(tms-reconsider-assertion assertion)
(tms-reconsider-mt mt)
(tms-reconsider-term-gafs term &optional mt)
(tms-reconsider-predicate-extent pred &optional mt)
(tms-reconsider-gaf-args pred arg &optional argnum mt)
(tms-reconsider-term term &optional mt)
(tms-reconsider-all-assertions)

;; Triviality / staleness (missing-larkc)
(atomic-cnf-trivially-derivable cnf mt)
(gaf-trivially-derivable gaf mt truth)
(true-gaf-trivially-derivable gaf mt)
(false-gaf-trivially-derivable gaf mt)
(stale-support support)
(stale-support-mt? support mt)
(support-mt-ok? support mt)

;; Circularity
(some-belief-justification assertion &optional asserted-assertions-to-ignore)
(inc-circular-complexity-count)
(gather-circular-deduction deduction asserted-assertions-to-ignore)
(mark-circular-assertion assertion)
(circular-deductions-with-assertion assertion)
(believed-circular-deduction deduction)
(remove-circularly-supported-assertions &optional stream)        ; missing-larkc body
(remove-if-circularly-supported-assertion assertion &optional stream) ; missing-larkc body
(independently-deducible-assertion? assertion)                   ; missing-larkc body
(tms-directly-circular-deduction deduction)                      ; missing-larkc body

;; Macros
(tms-note-assertion-being-removed (assertion) body)
(tms-note-deduction-being-removed (deduction) body)
(tms-note-argument-being-removed (argument) body)

;; Misc
(assertion-asserted-more-specifically-deductions assertion)      ; missing-larkc body
(tms-possibly-replace-asserted-argument-with-tv assertion tv)    ; missing-larkc body
```

## Consumers

| Consumer | What it uses |
|---|---|
| **HL storage modules** (`hl-storage-modules.lisp`, `hl-storage-module-declarations.lisp`) | `tms-add-deduction-for-cnf` from `hl-deduce-as-kb-deduction`; `tms-remove-argument` from `hl-unassert-as-kb-assertion` |
| **assertion-manager / assertions-low** | `tms-remove-assertion-int-2` for the final-remove step |
| **kb-indexing `remove-term-indices`** | `tms-remove-assertion-list` for batch removal of every assertion mentioning a term |
| **forward propagation / after-adding / after-removing** | `tms-postprocess-new-argument` calls `handle-after-addings`; `tms-propagate-removed-argument` calls `handle-after-removings`; both fire forward-propagation rules |
| **kb-hl-supports** | `tms-remove-kb-hl-support`, `tms-remove-kb-hl-supports-mentioning-term` are TMS-style cascades; `with-kb-hl-support-rejustification` is the TMS-deferral wrapper |
| **rewrite-of propagation** | `perform-rewrite-of-propagation` is called from `tms-recompute-assertion-tv` when TV changes |
| **arguments.lisp** | `valid-argument`, `argument-truth`, `compute-supports-tv` are read-side |
| **Cyc API** | `tms-remove-assertion`, `tms-add-deduction-for-cnf` are exposed for external KE clients |

## Notes for a clean rewrite

- **The cascade is a graph traversal with cycle-break flags** — `*tms-assertions-being-removed*`, `*tms-deductions-being-removed*` are dynamic-binding sets that detect re-entry. Modern designs use explicit visit-set parameters or implement removal as a transactional, batched operation that resolves the entire cascade before committing.
- **`*check-for-circular-justs*` is a global toggle** that determines whether circularity checking happens during every removal cascade. The clean rewrite probably wants this on by default (correctness over speed) with opt-out for batch operations.
- **The reconsideration subsystem is mostly missing-larkc** — `tms-reconsider-*`, `tms-deduction-stale-wrt-*`, `tms-reprove-deduction-*`. These are the "after a KB change, walk all the deductions that may now be invalid and re-evaluate them" path. Without it, KB consistency degrades over time as supports become stale. The clean rewrite must implement this as a periodic audit job or as an incremental check on each removal.
- **`compute-assertion-tv`'s strength-only-update path** (`missing-larkc 12462`) is interesting — when truth doesn't change but strength does, dependents don't need to be invalidated, only the assertion's stored TV needs updating. The clean rewrite should preserve this optimization.
- **The circularity-detection algorithm is correct but complex**. It runs on every assertion-removal where `*check-for-circular-justs*` is on. Modern designs use Tarjan's strongly-connected-components or persistent justifications-graph indexing to make this O(N) amortized rather than O(N) per check.
- **`*circular-complexity-count-limit*` = 50** is a heuristic budget. Conservative behavior on exceeding (treating it as believable) can leave actual circular support undetected. The clean rewrite should either remove the limit (with a real cycle-detection algorithm, no bound is needed) or surface it as a config knob.
- **`tms-add-deduction-for-cnf` calls `find-or-create-assertion`** — meaning a TMS add can mint a new assertion if none exists. This is correct for the deduce path (the deduction conclusion is the new assertion) but mixes two responsibilities. The clean rewrite separates "find or create assertion" from "add a deduction for an assertion."
- **`tms-postprocess-new-argument` uses `unwind-protect` to roll back** if `handle-after-addings` fails. Modern designs use transactional commits — the entire add operation either succeeds atomically or doesn't happen.
- **`*bootstrapping-kb?*` short-circuits TV recomputation** during KB load to avoid running the full TMS for every loaded assertion (which would be N² in KB size). The clean rewrite preserves this loophole but should make it explicit: an "import mode" that disables TMS, with a finalize step that re-establishes invariants.
- **`tms-remove-mt-arguments`** (missing-larkc) is the "remove all arguments asserted in MT X" — needed for MT-removal cascades. Reconstruct.
- **The `:just-found` catch is ad-hoc.** A clean rewrite uses an explicit return-from or a state machine with `:found / :not-found / :budget-exceeded` outcomes, distinguishing the budget-exceeded case from a real find.
- **`gather-circular-deduction` builds three lists in dynamic state** — `*circular-deductions*`, `*circular-assertions*`, plus the local-assertions set during marking. A clean rewrite uses an explicit `circular-search-state` struct passed along.
- **The HL-support branch in `tms-remove-argument`** dispatches on `(hl-support-p assertion)` — meaning the "assertion" parameter can actually be an hl-support 4-tuple (since hl-supports are not first-class assertion objects). This polymorphism is awkward; the clean rewrite either makes hl-supports proper objects or moves the hl-support cascade to its own function.
- **`remove-circularly-supported-assertions`** (missing-larkc) is the **periodic audit** — walk every assertion, check if circularly supported, remove if so. The clean rewrite needs this for KB hygiene; it's not just per-removal cascade but a consistency sweep.
- **The TMS doesn't track *why* an assertion was removed.** When debugging "where did my fact go?", the user has no audit trail. A modern design records removal reasons (TV-fell-to-nil, circularly-supported, term-removed, user-unasserted) for inspection.
