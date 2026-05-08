# Forward propagation

When an assertion is added to or removed from the KB, three classes of follow-on work are triggered automatically:

1. **`#$afterAdding` / `#$afterRemoving` GAF hooks** — predicate-keyed callbacks. When you assert a GAF whose predicate is, e.g. `#$genls`, all functions registered as `#$afterAdding` for `#$genls` fire. Used to keep derived caches (SBHL graphs, defns cache, equality-store) in sync.
2. **`#$ruleAfterAdding` / `#$ruleAfterRemoving` rule hooks** — same, but fire when a *rule* is added or removed (the predicate is one used in the rule's literals).
3. **Forward propagation through forward rules** — when a forward-direction rule's trigger literal is matched by the new GAF, run the rule and add its conclusions as deductions.

The three files implement these three concerns:

| File | Role |
|---|---|
| `after-adding.lisp` | The dispatcher. `handle-after-addings argument assertion` and `handle-after-removings argument assertion` are the entry points called from TMS after every successful add/remove. They dispatch to GAF and rule paths. The GAF path is fully ported here; the rule-after-adding path is dispatched. |
| `rule-after-adding.lisp` | Mirror of `after-adding` but for rule assertions: walks the rule's literals and fires hooks per predicate. Most of the per-pred handler bodies are missing-larkc. |
| `forward.lisp` | The forward-rule-execution engine. Pulls forward-direction assertions off the queue, computes their pragmatic DNF, and runs the inference engine to compute conclusions, which are then assertibled and re-injected. |

## When does forward propagation run?

Three phases:

1. **Synchronous, post-mutation.** Every successful TMS add or remove ends with `tms-postprocess-new-argument` (for adds) or `tms-propagate-removed-argument` (for removes), each of which calls `handle-after-addings` / `handle-after-removings`. The hooks fire **inline**, holding the `*hl-lock*`. This must be fast — the hook body should be a small cache update, not heavy reasoning.

2. **Queued, asynchronous.** When a forward-direction assertion is added, it's also enqueued in `*forward-inference-environment*` via `queue-forward-assertion`. When the queue is later drained — `(perform-forward-inference)` — each queued assertion is `forward-propagate-assertion`'d, which runs the full inference engine on it and produces new HL-assertibles, which get added back to the KB.

3. **Bulk rebuild.** `rebuild-after-adding-caches`, `rebuild-gaf-after-adding-caches`, `rebuild-rule-after-adding-caches`, `initialize-gaf-after-addings-hash`, `initialize-rule-after-addings-hash` walk every `#$afterAdding` (resp. `#$afterRemoving`, `#$ruleAfterAdding`, `#$ruleAfterRemoving`) GAF in every MT and populate the cache hashes. Done after KB load.

## After-adding GAF hooks

### What they are

A GAF hook is registered via:

```
(#$afterAdding <predicate> <function-symbol>)
```

When asserted in MT `M`: whenever a GAF whose predicate is `<predicate>` is added, in any MT relevant to `M`, call `(<function-symbol> argument assertion)`.

`#$afterRemoving` works the same way for removals.

The system has built-in hooks for, e.g., `#$genls` → `propagate-genls-after-adding` (updates the SBHL `genls` graph), `#$disjointWith` → `propagate-disjoint-after-adding`, `#$arity` → cache update, etc. User-extensible: any module can register additional hooks via `(ke-assert ((#$afterAdding <pred> <fn>) <mt>))`.

### Storage

`*gaf-after-addings-hash*` is a per-process hashtable keyed by predicate. The value is a list of `(function-symbol . mt)` pairs.

`*gaf-after-removings-hash*` is the parallel structure for `#$afterRemoving`.

The hashes are **lazily initialized** on first lookup (`get-gaf-after-addings`, `get-gaf-after-removings`). Re-initialized after KB load via `rebuild-gaf-after-adding-caches`.

`somewhere-cached-pred-p pred` — when the predicate participates in the somewhere-cache, `*somewhere-cache-gaf-after-adding-info*` is automatically prepended to the hook list. So the somewhere-cache's invalidate-on-add hook fires for every cached predicate.

### Initialization

`initialize-gaf-after-addings-hash`:

```
clear or allocate *gaf-after-addings-hash*
with-all-mts:
  do-predicate-extent-index (ass #$afterAdding):
    (gaf-after-adding-pred PRED FN-SYMBOL) := gaf-formula ass
    when (valid-fort? PRED):
      (let* ((fn (cycl-subl-symbol-symbol FN-SYMBOL))   ; CycL #$Fn → SubL fn
             (item (cons fn (assertion-mt ass))))
        (pushnew item (gethash PRED *gaf-after-addings-hash*)))
```

The walk is over **all MTs** — the cache is global across MTs because dispatch reads `relevant-mt?` at fire time.

`cycl-subl-symbol-symbol` converts a CycL function-symbol constant (like `#$propagate-genls-after-adding-Subl`) into a SubL function symbol that can be `funcall`ed.

### Dispatch

`handle-after-addings argument assertion`:

```
1. handle-gaf-after-addings argument assertion          -- if assertion is a GAF
2. when (valid-assertion? assertion):
     handle-rule-after-addings argument assertion       -- if assertion is a rule
```

Both fire even for the same assertion if it's a rule (the rule-after-adding path) or a GAF (the gaf-after-adding path).

`handle-gaf-after-addings argument assertion`:

```
unless *after-addings-disabled?*:
  when (gaf-assertion? assertion):
    pred := gaf-arg assertion 0
    mt   := assertion-mt assertion
    when (fort-p pred):
      with-inference-mt-relevance mt:
        for each (fn . fn-mt) in (get-gaf-after-addings pred):
          when (function-spec-p fn) and (relevant-mt? fn-mt):
            if not *debug-after-addings?*:
              ignore-errors:
                handle-gaf-after-adding fn argument assertion
            else:
              handle-gaf-after-adding fn argument assertion       -- propagate errors
```

`handle-gaf-after-adding fn argument assertion`:

```
bt:with-lock-held *hl-lock*:
  funcall fn argument assertion
```

Hooks run **synchronously** holding the global HL lock. The lock is **already held** by the modifier that triggered the after-adding, so this is a re-entrant acquire (bordeaux-threads locks are recursive on most implementations; verify in clean rewrite).

`*after-addings-disabled?*` is the master suppression switch (and for `disable-after-addings body` macro). Used during bulk import where running every hook would dominate runtime, with a finalize step rebuilding caches in batch.

`*debug-after-addings?*` — when t, errors in hooks propagate; when nil (default), they're swallowed by `ignore-errors` so a buggy hook doesn't crash the assertion.

### `handle-after-removings`

Mirror of `handle-after-addings`. Note: `handle-gaf-after-removings` does *not* check `*after-addings-disabled?*`. Removals always fire their hooks. (This may be a bug or intentional — a clean rewrite should decide.)

## Rule-after-adding hooks

Mirror of GAF hooks but for rule assertions. The rule's CNF is walked literal-by-literal; for each literal whose predicate matches a registered hook, the hook fires.

`*rule-after-addings-hash*`, `*rule-after-removings-hash*` — same shape as the GAF tables.

`initialize-rule-after-addings-hash` walks `#$ruleAfterAdding` GAFs in `with-all-mts` and registers them.

`handle-rule-after-addings argument assertion`:

```
unless *after-addings-disabled?*:
  when (rule-assertion? assertion):
    cnf := assertion-cnf assertion
    for each literal in (neg-lits cnf): handle-rule-after-addings-int argument literal assertion
    for each literal in (pos-lits cnf): handle-rule-after-addings-int argument literal assertion
```

`handle-rule-after-addings-int` looks up the literal's predicate in the rule-after-addings table, fires each registered handler. The body of the per-handler dispatch is `missing-larkc 33042` (the actual handler invocation). The clean rewrite calls `(funcall fn argument literal assertion)` mirroring the GAF case, with the `*hl-lock*` held.

`handle-rule-after-removings-int` has a known-bug note: Java passes `assertion` (not `literal`) as first arg to `literal-arg`. The port preserves the bug pending verification of intent.

## Forward propagation engine

The forward engine is the **inference-driven side of write propagation**: after a forward-direction assertion is added, run all forward rules whose triggers match it.

### Forward inference environment

```
*forward-inference-environment*  default (create-queue)  -- the queue of pending assertions
*current-forward-problem-store*                          -- shared problem store for inference
*forward-inference-shares-same-problem-store?*  default t -- reuse problem store across calls
*forward-inference-recursion-depth*  default 0           -- recursion guard
*forward-inference-enabled?*  default t                  -- master switch
*forward-propagate-from-negations*  default nil          -- forward-propagate from neg gafs?
*forward-propagate-to-negations*  default nil            -- conclude neg gafs?
*forward-inference-time-cutoff*  default nil             -- per-FI time cap
*forward-inference-allowed-rules*  default :all          -- :all or list
*within-forward-inference?*  default nil                 -- predicate
*within-assertion-forward-propagation?*  default nil
*tracing-forward-inference*  default nil                 -- print-trace toggle
*forward-leafy-mt-threshold*  default -1                 -- something MT-cardinality related
*forward-inference-assertibles-queue*  default nil       -- per-cycle queue
```

### Queueing

`queue-forward-assertion assertion`:

```
when *forward-inference-enabled?*:
  enqueue assertion *forward-inference-environment*
  when *tracing-forward-inference*:
    print
```

Called by `tms-recompute-assertion-tv` when a forward-direction assertion's TV changes (it gets re-queued for re-propagation), and by `tms-change-direction` when an assertion becomes forward.

`remqueue-forward-assertion assertion` — called by `tms-remove-assertion-int-2` to remove a removed assertion from the pending queue.

### Drain

`perform-forward-inference`:

```
when *forward-inference-enabled?*:
  *current-forward-problem-store* := nil
  unwind-protect:
    *forward-inference-recursion-depth* := previous + 1
    when *inference-debug?* and depth ≥ 20: break
    until queue empty:
      assertion := dequeue
      results   := forward-propagate-assertion assertion
      result    := nconc (nreverse results) result
  on exit:
    clear-current-forward-problem-store
return (nreverse result)
```

Drains the queue completely. Each iteration re-enters the engine (see [Forward-propagate-assertion](#forward-propagate-assertion)), which may add more assertions to the queue; the loop continues until the queue is empty.

### `forward-propagate-assertion`

The core. Given an assertion that's just become forward:

```
unless propagation-mt is #$InferencePSC and assertion isn't a forward-asserter:
  store-var := get-forward-problem-store           -- shared or fresh
  with-problem-store-memoization-state store-var:
    bind SBHL marking spaces, *within-forward-inference?* := t,
         *recursive-ist-justifications?* := nil,
         *forward-inference-assertibles-queue* := (create-queue)
    if (gaf-assertion? assertion):
      forward-propagate-gaf assertion propagation-mt
    else:
      forward-propagate-rule assertion propagation-mt
    -- collect any new assertibles produced
    unless queue empty:
      unless within forward propagation already or forward skolem preferring:
        clear current forward problem store    -- prevent stale problem-store reuse
      with cleared store:
        for each hl-assertible in queue:
          if assertion still valid:
            hl-add-assertible hl-assertible    -- assert it back into the KB
            collect into assertibles
return assertibles
```

The shared problem store across the whole queue drain means the inference engine can reuse SBHL-marking-space data across assertions, which dominates inference cost.

The `*forward-inference-assertibles-queue*` is per-call: each `forward-propagate-assertion` call gathers its produced assertibles separately. They're committed to the KB at the end of that single call, not at the end of the entire drain.

### `forward-propagate-rule rule propagation-mt`

For an added rule:

```
*forward-inference-rule* := rule
rule-cnf := assertion-cnf rule
pragmatic-dnf := forward-rule-pragmatic-dnf rule propagation-mt
handle-forward-propagation rule-cnf pragmatic-dnf propagation-mt nil rule nil
```

The rule's pragmatic DNF (a transformed form that handles `#$abnormal` exceptions and `#$meetsPragmaticRequirement` constraints inline) drives the rule's evaluation against the current KB.

### `forward-propagate-gaf source-gaf-assertion propagation-mt`

For an added GAF:

```
source-sense := truth-sense (assertion-truth source-gaf-assertion)
when source-sense is :pos OR *forward-propagate-from-negations*:
  source-asent := copy-tree (gaf-formula source-gaf-assertion)
  with *relax-type-restrictions-for-nats* if applicable:
    forward-propagate-gaf-expansions source-asent source-sense propagation-mt source-gaf-assertion
```

The fired GAF's atomic sentence is matched against every forward-rule trigger via `forward-propagate-gaf-expansions` → `forward-tactic-specs` (computed for this asent and sense and MT) → `forward-propagate-gaf-internal` for each match.

### Per-rule firing — `forward-propagate-gaf-internal`

```
trigger-asent      := the rule literal that matched
examine-asent      := the conclusion literal
examine-sense      := :pos or :neg
propagation-mt     := the MT in which we're propagating
rule               := the rule whose conclusion fires
trigger-supports   := the new gaf assertion (and any additional supports)

skip if rule not allowed (forward-inference-rule-allowed? rule)
unify trigger-asent against examine-asent if their predicates differ
  (same predicate or unbound-predicate match — missing-larkc 30637)
compute trigger-bindings via unification
handle-forward-propagation-from-gaf:
  remove trigger-asent from the rule's CNF
  remainder-neg-lits, remainder-pos-lits := remaining literals
  pragmatic-dnf := the rule's pragmatic DNF
  handle-forward-propagation rule-remainder-cnf pragmatic-dnf
                              propagation-mt trigger-bindings rule trigger-supports
```

### Conclusion handling

`handle-forward-propagation` runs the inference engine on the rule remainder (with the trigger pre-substituted by `trigger-bindings`). For each successful proof:

```
handle-one-forward-propagation query-dnf pragmatic-dnf propagation-mt
                                target-asent target-truth
                                trigger-bindings rule trigger-supports
```

`forward-propagate-dnf` runs the actual inference query. Conclusions are accumulated.

`add-forward-propagation-result target-asent target-truth propagation-mt trigger-bindings rule trigger-supports forward-result`:
- Builds a deduction with the rule + trigger as supports + the inference proof as additional supports.
- For each MT in `compute-all-mt-and-support-combinations` (handles MT-decontextualization and inheritance):
  - `add-forward-deductions-from-supports propagation-mt concluded-asent concluded-truth concluded-supports`
  - `handle-forward-deduction-in-mt asent truth mt supports`
  - `handle-forward-deduction-in-mt-as-assertible` builds an HL-assertible and `note-new-forward-assertible` enqueues it.

`note-new-forward-assertible` adds to `*forward-inference-assertibles-queue*` — the queue drained at the end of `forward-propagate-assertion` to commit all new assertibles atomically (per source-assertion).

### Doomed-supports check

`forward-propagation-supports-doomed? rule trigger-supports` — short-circuit predicate that decides whether the supports are likely to fail every conclusion (e.g. one of the supports is invalid, or the rule depends on a contradictory MT). When t, skip propagation entirely.

`compute-all-mt-and-support-combinations` and `compute-decontextualized-support-combinations` — for decontextualized predicates, the conclusion can apply in many MTs simultaneously; this enumerates them.

### Type filtering

`*type-filter-forward-dnf*` (default t) — gate forward-DNF candidates on argument type-checking. Rejects derivations that would conclude type-incompatible asserts. When off, type errors propagate further downstream.

`semantically-valid-forward-dnf dnf propagation-mt` — checks each variable's type constraint (per arg-type system) holds for the candidate.

### Constraint rules

`constraint-rule? rule &optional mt` — a rule whose conclusion is a constraint (e.g. `#$disjointWith` derivation), used to detect KB inconsistency rather than to add a new fact. Forward-propagated constraint rules trigger TMS removal of the offending support.

## Public API surface

```
;; after-adding
(*debug-after-addings?*) (*after-addings-disabled?*)
(*gaf-after-adding-predicates*)         ; ($afterAdding $afterRemoving)
(*gaf-after-addings-hash*) (*gaf-after-removings-hash*)
(disable-after-addings &body body)
(handle-after-addings argument assertion)
(handle-after-removings argument assertion)
(handle-gaf-after-addings argument assertion)
(handle-gaf-after-removings argument assertion)
(handle-gaf-after-adding fn argument assertion)
(handle-gaf-after-removing fn argument assertion)
(get-gaf-after-addings pred)
(get-gaf-after-removings pred)
(clear-after-addings) (clear-after-removings)
(clear-gaf-after-addings) (clear-gaf-after-removings)
(rebuild-after-adding-caches) (rebuild-gaf-after-adding-caches)
(initialize-gaf-after-addings-hash) (initialize-gaf-after-removings-hash)
(recache-gaf-after-addings pred) (recache-gaf-after-removings pred)   ; missing-larkc
(propagate-gaf-after-adding pred fn)                                   ; missing-larkc
(repropagate-gaf-after-adding pred fn mt)                              ; missing-larkc
(repropagate-gaf-after-adding-internal assertion)                      ; missing-larkc

;; rule-after-adding
(*rule-after-adding-predicates*)
(*rule-after-addings-hash*) (*rule-after-removings-hash*)
(handle-rule-after-addings argument assertion)
(handle-rule-after-removings argument assertion)
(handle-rule-after-addings-int argument literal assertion)
(handle-rule-after-removings-int argument literal assertion)
(get-rule-after-addings pred)
(get-rule-after-removings pred)                                        ; missing-larkc body
(handle-rule-after-adding pred fn assertion mt)                        ; missing-larkc body
(handle-rule-after-removing pred fn assertion mt)                      ; missing-larkc body
(clear-rule-after-addings) (clear-rule-after-removings)
(rebuild-rule-after-adding-caches)
(initialize-rule-after-addings-hash) (initialize-rule-after-removings-hash)
(recache-rule-after-addings pred) (recache-rule-after-removings pred) ; missing-larkc
(propagate-rule-after-adding assertion pred)                          ; missing-larkc
(repropagate-rule-after-adding pred fn mt)                            ; missing-larkc
(repropagate-rule-after-adding-internal assertion pred)               ; missing-larkc
(gather-literals-with-pred cnf pred)                                  ; missing-larkc

;; forward
(*require-cached-gaf-mt-from-supports*)
(*forward-inference-browsing-callback-more-info?*)
(*tracing-forward-inference*)
(current-forward-inference-environment)
(get-forward-inference-environment)
(clear-forward-inference-environment env)
(new-forward-inference-environment)
(initialize-forward-inference-environment)
(with-forward-inference-gaf (gaf) &body body)
(with-forward-inference-rule (rule) &body body)
(*forward-inference-gaf*) (*forward-inference-rule*)
(current-forward-inference-rule)
(*forward-problem-store-properties*)
(new-forward-problem-store) (destroy-forward-problem-store store)
(*forward-inference-shares-same-problem-store?*)
(forward-inference-shares-same-problem-store?)
(get-forward-problem-store) (clear-current-forward-problem-store)
(clear-current-forward-inference-environment)
(queue-forward-assertion assertion) (remqueue-forward-assertion assertion)
(perform-forward-inference)
(repropagate-forward-assertion assertion)                             ; missing-larkc
(*forward-inference-assertibles-queue*)
(forward-inference-assertibles-queue)
(note-new-forward-assertible hl-assertible)
(forward-propagate-assertion assertion &optional propagation-mt)
(forward-propagate-rule rule propagation-mt)
(forward-propagate-gaf source-gaf-assertion propagation-mt)
(forward-propagate-gaf-expansions ...)
(forward-propagate-gaf-internal ...)
(make-forward-trigger-supports source-gaf-assertion additional-supports)
(*type-filter-forward-dnf*)
(forward-inference-allowed-rules)
(forward-inference-all-rules-allowed?)
(forward-inference-rule-allowed? rule)
(handle-forward-propagation-from-gaf ...)
(handle-forward-propagation rule-remainder-cnf pragmatic-dnf propagation-mt
                            trigger-bindings rule trigger-supports)
(handle-one-forward-propagation ...)
(filter-forward-pragmatic-dnf pragmatic-dnf)
(forward-propagate-dnf ...)
(new-forward-query-from-dnf query-dnf pragmatic-dnf propagation-mt
                            &optional overriding-query-properties)
(forward-inference-query-properties pragmatic-dnf &optional overriding)
(add-forward-propagation-result ...)
(add-empty-forward-propagation-result ...)
(new-forward-concluded-supports rule trigger-supports &optional inference-supports)
(add-forward-deductions-from-supports propagation-mt concluded-asent concluded-truth concluded-supports)
(handle-forward-deduction-in-mt asent truth mt supports)
(handle-forward-deduction-in-mt-as-assertible asent truth mt supports)
(handle-forward-deduction-in-mt-as-assertible-int cnf mt supports &optional variable-map)
(constraint-rule? rule &optional mt)
(syntactically-valid-forward-non-trigger-asents dnf)
(semantically-valid-forward-dnf dnf propagation-mt)
(*forward-leafy-mt-threshold*)
(forward-propagation-supports-doomed? rule trigger-supports)
(compute-all-mt-and-support-combinations supports)
(compute-decontextualized-support-combinations supports)
```

## Consumers

| Consumer | What it uses |
|---|---|
| **TMS** | `handle-after-addings` / `handle-after-removings` from `tms-postprocess-new-argument` and `tms-propagate-removed-argument` |
| **kb-utilities clear** | `clear-after-addings`, `clear-after-removings`, `rebuild-after-adding-caches`, `clear-current-forward-inference-environment` |
| **kb-control-vars** | `*forward-inference-enabled?*`, `*forward-inference-environment*`, `*forward-inference-time-cutoff*`, `*forward-inference-allowed-rules*` are declared there but used here |
| **inference engine harness** | `forward-propagate-assertion`, `forward-propagate-rule`, `forward-propagate-gaf`, `perform-forward-inference` are called from the inference dispatcher when triggering forward inference programmatically |
| **SBHL** | many SBHL caches are kept fresh via `#$afterAdding`/`#$afterRemoving` GAF hooks tied to `#$genls`/`#$isa`/`#$disjointWith`/etc. |
| **rewrite-of propagation** | `perform-rewrite-of-propagation` (called from TMS) is conceptually a sibling of forward propagation — it propagates equality consequences |
| **somewhere-cache** | `*somewhere-cache-gaf-after-adding-info*` is auto-prepended to the hooks for cached predicates |
| **bookkeeping** | `disable-after-addings` is used during bulk imports to skip hook firing |

## Notes for a clean rewrite

- **Three propagation paths is two too many.** `#$afterAdding` GAF hooks, `#$ruleAfterAdding` rule hooks, and forward propagation are conceptually one thing: "code that runs when the KB changes." A clean design unifies them: declare a *change handler* with a predicate trigger or a rule trigger or a forward direction trigger, and let the dispatcher decide what fires when.
- **The dispatch holds the global HL lock.** Hooks must therefore be fast — but the assertion that the hook-body authors enforce this is implicit. A clean rewrite either documents the constraint or moves heavy hooks to a queued path with the lock released.
- **`ignore-errors` swallowing handler errors silently** is a pragmatic choice that makes debugging hard. A clean rewrite has structured logging plus per-hook error counting; failures should be visible without running with `*debug-after-addings?*` on.
- **The `*forward-inference-enabled?*` master switch is binary.** A more nuanced design lets you disable per-class (only forward GAFs, only forward rules, only specific predicates) so bulk imports can keep cache-sync hooks running while skipping rule firing.
- **`forward-propagate-assertion` does shared problem-store reuse** across the whole drain — necessary for performance but the lifecycle is gnarly. The doc note in the source ("Be safe and wrap rogue calls...") flags this. The clean rewrite makes the problem-store explicit (passed as a parameter) rather than implicit (read from a dynamic var).
- **The recursion-depth check at 20** (`when (>= *forward-inference-recursion-depth* 20) (break …)`) catches infinite forward-rule firing loops. In a clean rewrite, infinite-loop detection is part of the dispatcher (not just a depth check) — Cyc's KB has rule cycles that *should* fixpoint, and a depth limit alone doesn't distinguish "deep but converging" from "deep and diverging."
- **`handle-rule-after-addings-int` and `-removings-int` have missing-larkc bodies** — the actual handler invocation. Clean rewrite calls `(funcall fn argument literal assertion)` with HL lock held.
- **`handle-rule-after-removings-int` has a bug** (per source comment): it passes `assertion` to `literal-arg` instead of `literal`. The Java was wrong; the port preserves it. The clean rewrite must pick one — the literal version is presumably the intent.
- **The `cycl-subl-symbol-symbol` conversion** is a smell — handlers are stored as CycL constants whose names happen to be valid SubL symbols. A clean rewrite registers handlers by SubL symbol directly, with a side-table mapping from CycL constant for KE assertion.
- **`*current-forward-problem-store*` is a global** — meaning concurrent forward-propagation calls would clobber each other. In practice the HL lock prevents concurrency, but the sharing pattern is fragile. Make it a parameter or thread-local.
- **`compute-all-mt-and-support-combinations`** is the workhorse for MT-decontextualization in the conclusion side — when a forward conclusion applies to multiple MTs, all combinations of (concluded-mt, support-mt) tuples are enumerated. This can be combinatorial. A clean rewrite should profile this for KBs with many decontextualized predicates.
- **`*forward-leafy-mt-threshold*` = -1** has no comment. The variable is referenced but its purpose is unclear. The clean rewrite either documents or removes.
- **`*after-addings-disabled?*` does NOT gate `handle-gaf-after-removings`** — only the addings path. Removals always fire. This is either intentional (cache invalidation must always happen) or a bug. Test and document.
- **The pragmatic-DNF computation** (`forward-rule-pragmatic-dnf`, `filter-forward-pragmatic-dnf`) lifts `#$abnormal` and `#$meetsPragmaticRequirement` from the rule body into the candidate-filtering step. This is correct but expensive — a clean rewrite caches the pragmatic-DNF on the rule object so it's computed once per rule, not per fire.
- **Constraint rules** (`constraint-rule?`) — rules whose conclusion is a contradiction-detector — should probably be a separate rule subtype with explicit semantics, not a derived predicate over the conclusion shape.
- **The `*debug-after-addings?*` flag** is a process-global. Per-hook debug toggling would be more useful when investigating a specific cache invalidation bug.
- **`handle-gaf-after-adding`/-removing each grab `*hl-lock*`** explicitly — but the caller (TMS) already holds it via `define-hl-modifier`. Either the lock is recursive (works on most CL impls) or this is a redundant acquire. The clean rewrite should make the locking pattern explicit.
