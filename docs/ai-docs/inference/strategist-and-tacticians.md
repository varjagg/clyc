# Strategist and tacticians

The kernel mints datastructures; the workers fire individual tactic types; what sits between them — choosing *which* tactic to fire next, deciding whether a problem is worth pursuing, deciding when an inference is done — is the *strategist*. The strategist runs the inference loop. Inside it, multiple *tacticians* (concrete strategy types) plug in via a property-table dispatch table, each implementing a different search regime.

This is the largest and most complex region of the harness. Five concrete tacticians exist:
- **`:removal`** — pure backward removal-only, no transformation
- **`:heuristic-balanced`** — the default; balances removal, transformation, and new-root work using a happiness scoring system
- **`:balancing`** — newer balancing-tactician with substrategy delegation (gated by `(balancing-tactician-enabled?)`)
- **abductive** — for queries with `:abduction-allowed?` (extends balancing-tactician)
- **forward** — same dispatch shell as `:removal` but configured for forward-direction inference

Source files (8025 lines total):
- `inference/harness/inference-strategist.lisp` (1058) — the run loop, error/abort handling, strategy selection
- `inference/harness/inference-tactician.lisp` (489) — base tactician interface, dispatch helpers, per-tactic selection utilities
- `inference/harness/inference-tactician-utilities.lisp` (262) — preference-level computation, unhappiness arithmetic
- `inference/harness/inference-tactician-strategic-uninterestingness.lisp` (671) — caching of "this is uninteresting" decisions
- `inference/harness/inference-heuristic-balanced-tactician.lisp` (272) — the default tactician
- `inference/harness/inference-balanced-tactician-datastructures.lisp` (652) — balanced strategy data record
- `inference/harness/inference-balanced-tactician-execution.lisp` (286) — the do-one-step loop
- `inference/harness/inference-balanced-tactician-motivation.lisp` (1131) — motivation propagation rules
- `inference/harness/inference-balanced-tactician-strategic-uninterestingness.lisp` (957) — balanced-tactician variant of the uninterestingness cache
- `inference/harness/balancing-tactician.lisp` (222) — newer balancing tactician with substrategies
- `inference/harness/removal-tactician.lisp` (75) — registration + initialiser for `:removal`
- `inference/harness/removal-tactician-datastructures.lisp` (252) — removal-strategy-data record
- `inference/harness/removal-tactician-execution.lisp` (180) — `:removal` do-one-step
- `inference/harness/removal-tactician-motivation.lisp` (676) — `:removal` motivation rules
- `inference/harness/removal-tactician-uninterestingness.lisp` (664) — `:removal` uninterestingness cache
- `inference/harness/new-root-tactician-datastructures.lisp` (69) — substrategy data for new-root substrategy
- `inference/harness/transformation-tactician-datastructures.lisp` (109) — substrategy data for transformation substrategy

## The mental model

A strategist is a controller that, in a loop, picks one *strategem* to act on, executes it, observes the consequences, and repeats. A strategem is a unit of work — a tactic to fire, a problem to make a new root, an answer-link to propagate. The picking is the hard part.

To pick well, the strategist needs to know:

1. **Which problems are even worth thinking about right now?** Out of the thousands of problems in the search graph, which subset is *active* (being worked on) vs. *motivated* (queued to consider) vs. *set-aside* (parked because currently uninteresting but maybe interesting later) vs. *pending* (waiting on subgoals). This is the **problem activity discipline**.

2. **Which tactics on those problems are worth firing?** Tactics have *productivity* (how many results they're estimated to produce) and *completeness* (whether they fully cover the problem or leave gaps), and *preference levels* derived from those. Tactics with productivity above the strategy's `productivity-limit` get thrown away; magic-wand tactics get special treatment. This is the **tactic selection discipline**.

3. **In what order?** Removal-only tacticians use a stack (depth-first). The heuristic-balanced tactician uses three index structures — a removal stack, a new-root queue, and a transformation `problem-happiness-index` — and serves them in a quiesce-prune-pop order. The balancing tactician delegates to substrategies that each have their own index. This is the **execution-order discipline**.

These three disciplines are what differ between tacticians. The kernel run-loop is shared.

## The run loop (`simplest-inference-run-handler`)

After `new-cyc-query` mints the inference and `inference-prepare` canonicalises the query into HL form, the strategist takes over via `inference-run`:

```
inference-run(inference)
 │
 ├─ Push self onto inference's control-process slot
 ├─ Initialize time properties (start-time, end-time computed from max-time)
 │
 ├─ catch-inference-abort:
 │   ├─ with-inference-error-handling:
 │   │   ├─ Set status :running
 │   │   └─ simplest-inference-run-handler(inference)
 │   │       ↓
 │   └─ ...
 │
 └─ inference-suspend(inference, suspend-status)
      Mark :suspended; record suspend-status
```

`simplest-inference-run-handler` is where the work happens:

```
simplest-inference-run-handler(inference):
  let strategy = simplest-inference-strategy(inference)
  let store = inference-problem-store(inference)
  let timeout = inference-abort-max-time(inference)

  with-inference-max-time-timeout(timeout):
    with-problem-store-memoization-state(store):
      bind *resourced-sbhl-marking-spaces* to store's sbhl-resource-space
      bind *problem-store-modification-permitted?* = T

      inference-do-forward-propagation(inference)

      loop:
        possibly-wait-for-inference-to-unblock(inference)
        strategy-do-one-step(strategy)
        simplest-inference-possibly-prune(inference)
        if simplest-inference-done?(inference):
          break

      strategy-throw-away-uninteresting-set-asides(strategy)
      result = simplest-inference-determine-result(inference, pad?)
```

The loop is unconditional. Each iteration:
1. Maybe wait for an external unblock signal.
2. Tell the strategy to take exactly one step (`strategy-do-one-step`).
3. Check if the store has reached its problem/proof count threshold and prune if so.
4. Check if the inference is done.

The inference is done when one of:
- A `*halt-condition*` is reached
- The strategy is exhausted (`simplest-inference-exhausted?` ↔ `strategy-done?`)
- A type-independent halt fires: max-number, max-time, max-step, max-problem-count, max-proof-count, probably-approximately-done, or an interrupt

When the loop ends, throw away set-asides that have aged out and compute the final result via `simplest-inference-determine-result`:
- If `pad?` set: `:probably-approximately-done`
- If a type-independent reason fired: that reason
- Else if exhausted and continuable: `:exhaust`
- Else if exhausted: `:exhaust-total`

### Error and abort handling

`catch-inference-abort` and `with-inference-error-handling` wrap the run with two failure modes:
- **abort** — `(throw :inference-abort-target)` from anywhere inside the body. Any code that wants to bail out of the inference cleanly does this. The handler sets the suspend-status to `:abort` and calls `query-abort` for cleanup.
- **error** — Lisp errors caught via `handler-bind`. The handler stores the error message and converts it into a suspend-status keyword via `new-inference-error-suspend-status`. In `*inference-debug?*` mode, errors propagate to the debugger instead.

Both wrap the *entire* run so a single bad tactic execution does not corrupt the inference state.

`inference-abort-max-time` returns the timeout value to use, but only if **(a)** the timeout flag is on, **(b)** the inference is non-continuable, and **(c)** the problem store is private. The reason is in the docstring: "Aborting might leave the inference and its problem store in an inconsistent state. Hence, if the inference is continuable or if its problem store might be shared, we avoid triggering a hard abort when it runs out of time." The clean rewrite must preserve this: hard timeouts are only safe for one-shot, not-shared inferences.

### Interrupt and abort

External callers can interrupt or abort an inference:
- `inference-interrupt(inference, &optional patience)` — graceful: tells the inference to suspend itself at the next safe point. With patience nil, waits forever; with positive patience, escalates to an abort if the inference doesn't honor the request. With patience zero, immediately aborts.
- `inference-abort(inference)` = `inference-interrupt(inference, 0)`.
- `inference-abort-if-running` — used by `destroy-inference` to ensure no live inference is destroyed while running.

Interruption is signalled via `*controlling-inferences*` and the `interrupting-processes` queue. The control-process (the thread executing the inference) periodically checks `inference-interrupt-signaled?` and bails if so.

### Type-independent halt checks

Each iteration `strategy-do-one-step` is followed by `simplest-inference-done?` which calls `inference-determine-type-independent-result`:

| Check | Suspend-status |
|---|---|
| `inference-interrupt-signaled?` | `:interrupt` |
| `inference-max-number-reached?` (answer count ≥ max-number) | `:max-number` |
| `inference-max-time-reached?` (real-time > end-time) | `:max-time` |
| `inference-max-step-reached?` (step-count ≥ max-step) | `:max-step` |
| `inference-max-problem-count-reached?` (store problem count) | `:max-problem-count` |
| `inference-max-proof-count-reached?` (store proof count) | `:max-proof-count` |
| `inference-probably-approximately-done?` (no answers and PAD time elapsed) | `:probably-approximately-done` |
| `inference-halt-condition-reached?` (custom halt-condition) | the keyword |

The PAD ("probably approximately done") check is unusual: it only fires if the inference has *zero answers so far* and the PAD time has elapsed. It is a "give up if nothing's working" timer separate from `:max-time`.

## Strategy selection

The strategist picks which tactician to instantiate based on the query properties. `strategy-type-from-static-properties` is the dispatch:

```
strategy-type-from-static-properties(static-properties):
  if properties-indicate-forward-inference?(static-properties):
    *forward-strategy-type*  ; :removal
  elif balancing-tactician-enabled?:
    if abduction-allowed:
      *abductive-strategy-type*
    else:
      :balancing
  elif abduction-allowed:
    *abductive-strategy-type*
  elif transformation-allowed-by-properties?:
    *default-strategy-type*  ; :heuristic-balanced
  else:
    *exhaustive-removal-strategy-type*  ; :removal
```

The defaults:
- `*default-strategy-type*` = `:heuristic-balanced`
- `*exhaustive-removal-strategy-type*` = `:removal`
- `*forward-strategy-type*` = `:removal`
- `*abductive-strategy-type*` = a registered abductive type (its registration is elsewhere)

`(balancing-tactician-enabled?)` is a runtime switch (`*balancing-tactician?*`) that flips the engine between the heuristic-balanced and the newer balancing tactician. The clean rewrite should pick one and remove the switch.

### Strategy switching mid-inference

`consider-switching-strategies` is called at every `continue-inference`: it computes `determine-best-strategy-type-for-inference(inference)` and if it differs from the current strategy's type, calls `inference-switch-strategies`. The Lisp port has this function as a no-op (`missing-larkc` body); the real engine reuses the inference object but throws away the old strategy's data and constructs a fresh one. This is what allows e.g. an inference to start in `:minimal` mode and switch to `:maximal` on continuation.

## The strategy type registry

Each tactician registers a property dispatch table via `inference-strategy-type(strategy-type, plist)` (which calls `new-strategy-type` to add an entry to `*strategy-type-store*`). The plist lists the function for each *method type* the tactician implements. `strategy-dispatch(strategy, method-type, args…)` looks up the function and calls it.

The full vocabulary of method types is the union of:
- `*balancing-tactician-strategy-type-properties*` (29 entries) — methods every balancing tactician must implement
- `*legacy-strategy-type-properties*` (13 entries) — methods specific to the legacy `:heuristic-balanced` lineage

Expressed as a table:

### Core dispatch methods (every tactician)

| Method | Purpose |
|---|---|
| `:name`, `:comment` | Documentation strings |
| `:constructor` | Initialise the strategy's `data` slot (called by `new-strategy`) |
| `:done?` | Is the strategy done finding things? |
| `:do-one-step` | Run one strategy step (the main loop body) |
| `:possibly-activate-problem` | Examine a fresh problem and decide whether to activate it |
| `:select-best-strategem` | Pick the next strategem to execute |
| `:initial-relevant-strategies` | Compute initial strategy seeds for the inference |
| `:new-tactic` | Notify when a new candidate tactic is added |
| `:split-tactics-possible` | Notify when split tactics become possible on a problem |
| `:initialize-properties` | Apply initial strategy-static properties |
| `:update-properties` | Apply updated strategy-dynamic properties |
| `:inference-dynamic-properties-updated` | Notify after inference-level dynamic property change |
| `:reconsider-set-asides` | Replenish active set from set-aside set |
| `:throw-away-uninteresting-set-asides` | Final pass before returning |
| `:continuation-possible?` | Are there set-asides worth continuing on? |
| `:quiesce` | Drain stale strategems (those no longer worth firing) |
| `:new-argument-link` | Notify when a new argument link is added to a problem |
| `:relevant-tactics-wrt-removal` | Filter tactics for removal motivation |
| `:problem-could-be-pending` | Hook to mark a problem as possibly pending |
| `:problem-nothing-to-do?` | Predicate for "problem has no work" |
| `:throw-away-tactic` | Decide whether a tactic should be discarded |
| `:set-aside-tactic` | Decide whether a tactic should be parked |
| `:peek-next-strategem` | Look at the next strategem without consuming |
| `:motivate-strategem` | Propagate motivation to a strategem |
| `:activate-strategem` | Add a strategem to the active set |
| `:link-head-motivated?` | Is a link head already motivated? |
| `:reconsider-split-set-asides` | Re-evaluate split tactics that were set aside |
| `:substrategy-strategem-motivated`, `:substrategy-totally-throw-away-tactic`, `:substrategy-allow-split-tactic-set-aside-wrt-removal`, `:substrategy-problem-status-change` | Substrategy hooks (balancing tactician only) |

### Legacy-only methods (`:heuristic-balanced`)

| Method | Purpose |
|---|---|
| `:early-removal-productivity-limit` | Productivity threshold for early removal |
| `:peek-new-root`, `:activate-new-root`, `:pop-new-root`, `:no-new-roots`, `:throw-away-new-root` | New-root index ops |
| `:peek-removal-strategem`, `:activate-removal-strategem`, `:pop-removal-strategem`, `:no-active-removal-strategems` | Removal index ops (the depth-first stack) |
| `:peek-transformation-strategem`, `:activate-transformation-strategem`, `:pop-transformation-strategem`, `:no-active-transformation-strategems` | Transformation index ops (the happiness-priority queue) |

The `:must-override` sentinel in the property table means "the registration MUST supply this method". Other entries have default implementations (e.g. `default-strategy-initialize-properties`, `zero`, `false`, `ignore`).

### Dispatch implementation

`strategy-dispatch(strategy, method-type, &optional arg1 arg2 …)` looks up the function from `*strategy-type-store*[strategy-type][method-type]` and funcalls it with `(strategy …args)`. Variants exist for fixed arities (`strategy-dispatch-funcall-0`, `…-funcall-1`, etc.) for inlining.

The two-level dispatch (strategy-type → method-type → function) is *the* extension point: any clean rewrite that wants to add a new tactician adds a new entry to `*strategy-type-store*` and provides the table of methods. No code changes elsewhere.

## The strategy struct (revisited from "Inference kernel" doc)

The 15-slot `strategy` record holds:
- `suid`, `inference` — identity and parent pointer
- `result-uniqueness-criterion` — `:proof | :bindings`
- `active-problems` (`new-set #'eq`) — currently-being-worked-on
- `motivated-problems` (`new-set-contents 0 #'eq`) — queued for consideration
- `set-aside-problems` (`new-set #'eq`) — parked
- `should-reconsider-set-asides?` — flag set by per-tactician code when a relevant change suggests revisiting
- `productivity-limit` — `*default-productivity-limit*`
- `removal-backtracking-productivity-limit` — `*default-removal-backtracking-productivity-limit*` (200)
- `proof-spec` — `:anything` or a structured spec
- `problem-proof-spec-index`, `problem-strategic-index` — per-problem strategy-private data
- `memoization-state` — strategy-private memoization (separate from store)
- `type` — `:removal | :heuristic-balanced | :balancing | …`
- `data` — type-specific record (`removal-strategy-data`, `balanced-strategy-data`, `balancing-tactician-data`)

The four problem buckets — active, motivated, set-aside, plus a fourth implicit "everyone else" set — are the **problem activity discipline** in concrete form. A problem moves between them based on motivation propagation rules (in `…-motivation.lisp`) and on tactic execution outcomes.

## The `:removal` tactician

The simplest tactician. Used when no transformation is needed and no abduction is allowed. Its data:

```lisp
(defstruct removal-strategy-data
  removal-index)        ; a single stack
```

**Algorithm:**
1. The active-problems set contains a single problem at a time (the top of the depth-first stack).
2. `:do-one-step` pops a strategem from the removal-index, executes it, and processes consequences.
3. When a tactic creates child problems, they get pushed onto the stack.
4. Done when the stack is empty.

This is classical depth-first backward chaining. The "removal" name comes from removing literals from the goal one at a time.

`removal-strategy-initialize` constructs a fresh stack and wraps it in `removal-strategy-data`. The `inference-strategy-type :removal` registration table at the top of `removal-tactician.lisp` lists the methods.

## The `:heuristic-balanced` tactician (the default)

The default tactician for non-trivial backward queries. It uses *three* indexes simultaneously:

```lisp
(defstruct balanced-strategy-data
  problems-motivated-wrt-new-root-table   ; eq-dictionary
  problems-motivated-wrt-removal          ; eq-set
  problems-motivated-wrt-transformation   ; eq-set
  link-heads-motivated-wrt-removal        ; eq-set
  link-heads-motivated-wrt-transformation ; eq-set
  problems-pending-wrt-new-root           ; eq-set
  problems-pending-wrt-removal            ; eq-set
  problems-pending-wrt-transformation     ; eq-set
  new-root-index                          ; queue (FIFO)
  new-root-problems                       ; eq-set (membership)
  removal-strategem-index                 ; stack (depth-first)
  problem-total-strategems-active-wrt-removal           ; eq-dict, problem→count
  current-new-root-wrt-removal            ; for tracking the current focus
  transformation-strategem-index          ; problem-happiness-index (priority queue)
  problem-total-strategems-active-wrt-transformation    ; eq-dict, problem→count
  problem-strategems-set-aside-wrt-removal              ; eq-dict, problem→eq-set
  problem-strategems-set-aside-wrt-transformation       ; eq-dict, problem→eq-set
  problem-strategems-thrown-away-wrt-removal            ; eq-dict, problem→eq-set
  problem-strategems-thrown-away-wrt-transformation)    ; eq-dict, problem→eq-set
```

The naming convention: every motivation/pending/set-aside/thrown-away set is split *wrt-removal*, *wrt-transformation*, and *wrt-new-root*. A problem can be pending wrt removal but motivated wrt transformation. The split is essential — different tactic types have different priorities on the same problem.

### `do-one-step` — the inner loop

`balanced-strategy-do-one-step` keeps calling `balanced-strategy-do-one-step-int` until the result becomes `:done` or `:interesting`. `:uninteresting` results loop. The reason: `select-best-strategem` may pick something that turns out to be quiesced-away, in which case the step does nothing useful and must be retried.

`balanced-strategy-do-one-step-int` algorithm:
1. If `should-reconsider-set-asides?`, run the reconsider pass and return `:uninteresting`.
2. If the strategy is done, return `:done`.
3. Otherwise call `balanced-strategy-select-best-strategem` to pick a `(strategem, motivation)` pair. If nil, return `:done`. Otherwise execute it via `balanced-strategy-execute-strategem` and return its result.

### `select-best-strategem` — the queue priority

`balanced-strategy-default-select-best-strategem` implements the **priority order**:
1. Quiesce the removal queue (drop ignorable strategems). If any remain, pop and return with motivation `:removal`. **Removal wins**.
2. Quiesce the new-root queue. If any remain, pop and return with the appropriate motivation (`:removal` or `:transformation` based on what the new-root needs).
3. Quiesce the transformation queue. If any remain, pop and return with motivation `:transformation`.
4. If there's an answer-link to propagate, return it with motivation `:new-root`.
5. Otherwise return `(nil, nil)`.

The priority is **removal first, then new-root, then transformation, then answer**. Removal is preferred because it is cheap and likely to produce answers fast; transformation is preferred last because it expands the search space.

### `balanced-strategy-execute-strategem` — dispatch

Given a `(strategem, motivation)`:
- **Tactic** (executable: content or meta-structural): execute it, deactivate it, and possibly deactivate the problem.
- **Logical tactic** (split, join, join-ordered, union — these have substructure): unless disallowed, propagate motivation to link-head, execute the tactic, and deactivate.
- **Transformation link**: propagate motivation to link-head, deactivate.
- **Problem** (a new-root): handle as new-root.
- **Answer-link**: propagate motivation to the root problem, then propagate the answer-link up.

### Happiness scoring

The transformation-index uses a `problem-happiness-index` — a priority queue ordered by *happiness* score. Happiness is the negative of unhappiness (lower unhappiness = higher happiness). The score combines a tactic's productivity, its preference level, the module's preference scaling factor, and the literal count of the conjunction.

The *strategic heuristics* contribute additive terms to the happiness score. The tactician advertises which heuristics it uses via `*heuristic-balanced-tactician-heuristics*`:

- `:shallow-and-cheap`
- `:completeness`
- `:occams-razor`
- `:magic-wand`
- `:backtracking-considered-harmful`
- `:backchain-required`
- `:rule-a-priori-utility`
- `:relevant-term`
- `:rule-historical-utility`
- `:literal-count`
- `:rule-literal-count`
- `:skolem-count`

Each heuristic is registered (in `inference-strategic-heuristics.lisp`) with a function that computes a delta and a scaling factor. `heuristic-balanced-strategy-generic-tactic-happiness(tactic, strategy)` walks all registered heuristics, calls each function, multiplies by its scaling factor, and sums.

The clean rewrite should keep the heuristic-pluggable design; it is the right vocabulary for tunable tactical behaviour.

### Preference levels and unhappiness

`*preference-scaling-values*`:
```
:dispreferred           m=2  b=0
:grossly-dispreferred   m=20 b=0
:join-ordered           m=5  b=0
```

`removal-unhappiness(productivity, module-spec, preference, literal-count)` = productivity × scaling factors. A more "preferred" tactic has a smaller unhappiness; a more productive tactic has a larger one. The `removal-unhappiness` heuristic preserves the rule that productivity is the dominant factor and preference is a soft modifier.

Preference levels are computed by `problem-global-preference-level(problem, strategic-context, shared-variables)`:
- If the store disallows removal: `:grossly-dispreferred`
- If the problem is closed: `:preferred`
- If no shared variables: `:preferred` ("nothing to bind, treat as terminal")
- If the problem has no removal-allowed or executed tactics: `:disallowed`
- If single-negative-literal: `:disallowed` or `:grossly-dispreferred`
- If has a complete non-thrown-away removal tactic: `:preferred`
- Multi-literal problem: max preference of conjunctive tactics
- Multi-clause problem: `*union-tactic-preference-level*`
- Otherwise: `problem-preference-level-wrt-modules` (per-module computation)

### Magic wand tactics

`magic-wand-tactic?(tactic, strategic-context)` identifies tactics that look bad (zero productivity) but are uniquely positioned to enable a downstream win. Such a tactic gets boosted preference in spite of its bad numbers. This catches "this single rule is the only way to bind ?X, even though it produces 0 immediate results, fire it because the parent's other branches need ?X."

The clean rewrite must preserve this — without it the engine misses any inference where a unique step is the only way forward.

## The `:balancing` tactician (newer)

`balancing-tactician-data` introduces *substrategies*:

```lisp
(defstruct balancing-tactician-data
  new-root-substrategy
  transformation-substrategy
  removal-substrategies)         ; a list — multiple removal substrategies are possible
```

Instead of the heuristic-balanced tactician's three indexes inlined into one strategy, the balancing tactician has three *substrategies*, each a real `strategy` object with its own data. `controlling-strategy(substrategy)` returns the parent. `do-balancing-tactician-substrategies` and `do-balancing-tactician-spineful-substrategies` iterate them.

Why substrategies? Two reasons:
1. Each substrategy has its own memoization, its own active/motivated/set-aside sets, its own data record. They can be tuned independently.
2. Multiple removal substrategies allow parallel exploration of different areas of the search graph.

The `*balancing-tactician?*` flag (a defparameter, "Whether to use the balancing tactician, except for abduction") is the runtime switch. The historical `*wallenda?*` flag is marked Obsolete in the source.

The balancing tactician inherits `:select-best-strategem`, `:execute-strategem`, etc. from the substrategies' types — its own dispatch table mostly delegates via `controlling-strategy-callback`. The clean rewrite should think of it as a *meta-tactician* whose job is mostly substrategy bookkeeping and whose substrategies do the real per-step work.

## Motivation propagation

When a tactic executes and produces consequences (new problems, new links, new tactics), the strategy must decide: do these new things deserve attention now, or are they uninteresting? This is **motivation propagation**, and it is the heart of why the tactician files are so large. A few thousand lines per tactician are devoted to it.

The general flow:
- A new problem arises. The strategy calls `:possibly-activate-problem`.
- A new tactic is added. The strategy calls `:new-tactic`.
- A new argument-link is added. The strategy calls `:new-argument-link`.
- For each event, the relevant tactician code consults its uninterestingness cache, motivates or sets aside, and may propagate motivation to dependent problems and link heads.

`balanced-strategy-possibly-propagate-motivation-to-link-head` and `…-to-problem` are the workhorses. They walk forward through the search graph, marking link heads and problems as motivated wrt removal/transformation/new-root depending on the path taken.

The set-aside/throw-away decision is captured by `*set-aside-non-continuable-implies-throw-away?*`: if the inference is non-continuable, anything that would be merely set-aside gets upgraded to thrown-away. A continuable inference parks; a one-shot inference deletes.

## Strategic uninterestingness cache

`inference-tactician-strategic-uninterestingness.lisp` and the `-balanced-` and `-removal-` variants implement a cache: "we already decided this strategem is uninteresting, don't re-evaluate." The cache is keyed by problem and motivation, and the strategy's `data` carries dictionaries to look up the cached decision.

The cache is a soft commitment — if the strategy's productivity-limit changes (via `:productivity-limit` dynamic property), the cache may be invalidated for some problems via `set-problem-recompute-thrown-away-wrt-all-relevant-strategies-and-all-motivations`. This is the bookkeeping that lets `inference-update-dynamic-properties` work: when the limit increases, previously-thrown-away tactics may now be acceptable, so the cache is invalidated.

The 8 byte slots in the strategy struct (`*uninterestingness-cache-thrown-away-wrt-removal-byte*` and friends) pack 4 cache states (thrown-away wrt removal/transformation/new-root, set-aside wrt the same) into a single small integer per problem. Bit-banged for compactness.

The clean rewrite should think of this as a *negative cache*: it doesn't say what's interesting; it says what to skip. Computed once, valid until invalidated. Keep the bit-packing, or replace with eq-keyed bitmasks.

## Producing answers

`inference-note-proof(inference, proof)` is called by workers when a proof is generated. It calls `new-inference-answer-from-proof`:

1. `perform-lazy-proof-rejection` — possibly mark proof as rejected via `*proof-reject-reasons*`
2. If proof is `:proven`, compute `inference-answer-bindings-from-proof`
3. Filter via `inference-disallows-answer-from-bindings?` (e.g. indeterminate-results check)
4. Find or create the inference-answer; find or create its justification; attach the proof to the justification
5. `perform-inference-answer-proof-analysis` — note rules used, increment per-rule success counters
6. `possibly-note-proof-processed`

Bindings extraction: `inference-answer-bindings-from-proof(proof, inference)`:
1. `inference-hl-bindings-from-proof` — get HL bindings via the answer-link's variable-map
2. `filter-out-uninteresting-bindings` — keep only bindings for `inference-free-hl-vars`
3. If EL bindings exist, compose with HL bindings to get EL→answer bindings (`compose-el-answer-bindings`); else return HL bindings directly
4. Stable-sort by free EL var ordering for display consistency

The `disjunction-free-el-vars-policy` (`:require-equal | :compute-intersection | :compute-union`) determines what to do when EL variables appear free in disjuncts: require they bind to the same value, or take intersection of bindings, or union.

## Continuable vs. one-shot

A continuable inference (`:continuable? t`) keeps its strategy data alive across suspends. After a suspend, `continue-inference-int` calls:
- `inference-update-properties` — re-extract properties, push dynamic ones into the strategy
- `consider-switching-strategies` — possibly swap to a better strategy type for the new properties
- `reset-inference-new-answers` — move the answer-id-start cursor so the next pull is "new"
- `within-controlling-inference … inference-run` — re-enter the run loop
- `inference-postprocess` — extract results

A one-shot inference is destroyed at the end of the run; its strategy data is `:free`'d.

`query-dynamic-properties-have-strategically-interesting-extension?` is the test for whether the new properties are *more permissive* than the old — i.e. could uncover more answers. If yes, the strategy is told (`strategy-note-inference-dynamic-properties-updated`) and existing thrown-away markers are re-evaluated.

## Cross-system consumers

- **Kernel** (`inference-kernel.lisp`) calls `consider-switching-strategies`, `inference-run`, `inference-postprocess`. Strategy is internal — no external code constructs it directly.
- **Workers** call `inference-note-proof` and the various `strategy-note-tactic-finished` / `strategy-note-argument-link-added` hooks.
- **HL prototypes / abnormal** use the strategy's memoization-state context to scope their lookups.
- **Inference analysis** reads strategy data to compute metrics (transformation rule usage, etc.).

## Notes for the rewrite

- **Pick one tactician.** The dual `:heuristic-balanced` / `:balancing` lineage is a port-time accident. The balancing tactician with substrategies is the more general design; pick it as the only one and remove the heuristic-balanced legacy. The `*balancing-tactician?*` runtime flag goes away.
- **`:removal` stays.** It is genuinely useful for forward inference and zero-backchain removal-only queries. Keep it as a separate, simpler tactician.
- **The strategy-type-store dispatch is the right extension point.** Keep it. A new tactician = a new entry. The clean rewrite can express it as a trait/typeclass with method-table lookup.
- **Move motivation rules out of per-tactician files into a shared library.** Many of the propagation rules in `…-balanced-tactician-motivation.lisp` and `removal-tactician-motivation.lisp` are duplicated. Extract them.
- **The 4-state problem activity machine** (active / motivated / set-aside / nothing) is simple but hidden across many files. Make it a single `enum ProblemActivity` plus state-transition functions.
- **The 3-axis split (removal / transformation / new-root)** is structural, not incidental. Build it into the type system — a tactic *is* one of those three; a problem can be motivated wrt any subset of the three.
- **Uninterestingness cache as bit-packing** is a worthy optimisation. The 4 states × 3 motivations = 12 bits, which fits in a u16. Keep this.
- **`magic-wand-tactic?` is essential.** Without it the strategist undervalues the only-path-to-X tactics. Make sure the rewrite preserves it.
- **`*proof-reject-reasons*`** is the answer side of the same machinery. A proof can be rejected for being circular, ill-formed, non-abducible-rule, having a rejected-subproof, exceeding max-proof-bubbling-depth, or a few other reasons. The rejection logic is in the `perform-lazy-proof-rejection` path.
- **Strategy switching mid-inference** is in the LarKC port as a no-op. The clean rewrite needs it for the "start cheap, escalate to deep" workflow that inference-mode change implies.
- **Strategic heuristics are pluggable.** The 12 named heuristics in the heuristic-balanced lineage are all separately registered. Keep the registration interface even when unifying tacticians.
- **`*strategy-auto-prune-threshold*`** is documented as "Useful for testing"; the production default is nil (no auto-prune). Keep this nil; pruning is driven by problem/proof counts in the store.
