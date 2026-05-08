# Backward inference (the `removal-ask` shallow path)

The harness has two distinct entry points for backward queries:

1. **`new-cyc-query`** — full strategist + tactician + workers. Goes through canonicalization, problem store, multi-step strategy. Used for any non-trivial query. Documented in "Inference kernel & datastructures."
2. **`removal-ask`** — exhaustive removal-only ask, no strategy, no transformation, no problem store. The shallow path used by:
   - The trivial-query fast path (when the query is a single atomic literal)
   - HL modules that need to ask sub-queries during their own expansion (recursive ask)
   - Forward-inference rule firing
   - Various utility entry points (e.g. `at-routines` arg-type checking)

This file documents the second path. It is a separate piece of code from the strategist — it sets up dynamic specials, walks the candidate removal modules in cost order, fires each one's `:expand` (which calls back into `removal-add-node`), accumulates answers in a dictionary, and returns. No problem-store, no proof DAG, no tactics — just bindings.

Source files:
- `larkc-cycl/backward.lisp` (452) — `removal-ask` and friends, plus forward-inference semantic pruning helpers
- `larkc-cycl/backward-utilities.lisp` (147) — `relevant-directions`, `transformation-rule-dependent-lits`, commutative-asent canonicalization
- `larkc-cycl/backward-results.lisp` (50) — `*inference-intermediate-step-validation-level*`, mostly missing-larkc

## The shallow path: `removal-ask`

```
removal-ask(asent, &optional mt (truth :true) query-properties):
  set mt to *default-ask-mt* if nil
  bind:
    *removal-add-node-method* = 'removal-ask-add-node
    *controlling-inferences* = (cons nil *controlling-inferences*)
    *controlling-strategy* = nil
  with-inference-mt-relevance-validate(mt):
    bind *mt*, *relevant-mt-function*, *relevant-mts*
    return (removal-ask-int asent truth query-properties)
```

Three things to note:

- **`*removal-add-node-method*` is bound to `'removal-ask-add-node`.** The HL module's `:expand` function calls `removal-add-node` (in this file). That function dispatches to whatever `*removal-add-node-method*` is set to. By binding it here, `removal-ask` redirects all node-creation to its own answer accumulator (`removal-ask-add-node`).
- **`*controlling-inferences*` gets a nil pushed.** A nil controlling inference means "no parent inference owns this work" — so the engine's interrupt-routing and metric-recording bypass this query.
- **`*controlling-strategy* = nil`.** No strategy is active during the ask.

The return is a 3-tuple: `(answers halt-reason metrics)`.

### `removal-ask-int(asent, truth, query-properties)`

```
removal-ask-int(asent, truth, query-properties):
  let sense = truth-sense(truth)                         ; :true→:pos, :false→:neg
  let allowed-modules-spec = getf(query-properties, :allowed-modules, :all)
  let tactic-specs = removal-ask-tactic-specs(asent, sense, allowed-modules-spec)
  if tactic-specs:
    return (removal-ask-expand asent sense tactic-specs query-properties)
  else:
    return (values nil :exhaust-total nil)
```

The candidate tactic-specs come from `literal-removal-options(asent, sense, allowed-modules-spec)` (in `inference-worker-removal.lisp`) — the same machinery as the regular tactic-determination path, so the same module classification and exclusivity rules apply.

### `removal-ask-expand(asent, sense, tactic-specs, query-properties)`

```
removal-ask-expand:
  sort tactic-specs by productivity (cheaper first)
  bind *removal-ask-answers* = new-dictionary-contents (equal)
  bind *removal-ask-max-number* = (getf query-properties :max-number)
  bind *removal-ask-disallows-indeterminate-terms?* = (not (getf query-properties :allow-indeterminate-results? t))
  bind metrics start time if metrics requested
  for tactic-spec in tactic-specs:
    catch :removal-ask-done:
      bind *inference-expand-hl-module* = hl-module
      bind *inference-expand-sense* = sense
      get the module's :expand pattern or function
      if cost is not too expensive (cost-cutoff check):
        if pattern: pattern-transform-formula(pattern, asent)
        else: funcall expand-method(asent, sense)
      ; expand calls removal-add-node which writes to *removal-ask-answers*
  for each (bindings, justifications) in *removal-ask-answers*:
    for each justification:
      unless allow-abnormality-checking? AND supports-contain-excepted-assertion?(justification):
        push (bindings, justification) to answers
  set halt-reason :exhaust-total if not already set
  if metrics: compute metric values
  return (nreverse answers, halt-reason, metric-values)
```

Key observations:

- **Tactic-specs are sorted by cost (productivity[1] is the cost field).** Cheaper modules fire first.
- **Each tactic fires inside a `catch :removal-ask-done`.** When the answer count reaches `*removal-ask-max-number*`, `removal-ask-add-node` throws `:removal-ask-done` to break out.
- **Cost cutoff:** `inference-hl-module-cost-too-expensive` checks the module's cost against `*removal-cost-cutoff*` — modules above the cutoff are skipped entirely. The cutoff is bound by the caller (or set by the trivial-query fast path).
- **Pattern vs. function dispatch:** if the module has an `:expand-pattern`, use the pattern interpreter (`pattern-transform-formula`); otherwise call the `:expand-func` directly with `(asent sense)`.
- **Excepted-assertion filtering:** after collecting answers, drop justifications that include excepted assertions (the `(except ...)` mechanism). This is the abnormality-on-the-cheap path — the full abnormality check (`forward-abnormality-check`) is too expensive for removal-ask.
- **Halt reason defaults to `:exhaust-total`** if no max-number was hit. Removal-ask is *exhaustive* by design — it tries every applicable module unless cost-capped.

### `removal-add-node(support, &optional v-bindings, more-supports)`

The callback HL modules use to register a result. Its body delegates via `*removal-add-node-method*`:

```
removal-add-node(support, &optional v-bindings, more-supports):
  if v-bindings is nil: use unification-success-token
  if *removal-add-node-method* is nil: error "legacy harness no longer supported"
  removal-add-node-funcall(*removal-add-node-method*, v-bindings, (cons support more-supports))
```

`removal-add-node-funcall` is a switch table:

| Method symbol | Used by |
|---|---|
| `'handle-removal-add-node-for-output-generate` | the regular harness's pattern-driven removal worker |
| `'handle-removal-add-node-for-expand-results` | iterative-removal-tactic execution |
| `'removal-ask-add-node` | this file's `removal-ask` shallow path |
| else | direct funcall (extension hook) |

The reason for the indirection: the HL module doesn't know whether it's being called by the full harness (where its result becomes a removal-link with proof bubbling), or by removal-ask (where its result becomes a dictionary entry), or by some other context. The dynamic special routes the result to the right place.

### `removal-ask-add-node(v-bindings, supports)`

```
removal-ask-add-node:
  if disallowing indeterminate terms AND bindings contain indeterminate: skip
  if first answer: record first-answer-elapsed-internal-real-time
  always: record last-answer-elapsed-internal-real-time
  push (v-bindings → supports) into *removal-ask-answers* dictionary
  if max-number reached: throw :removal-ask-done with halt-reason :max-number
```

The dictionary is keyed by bindings (under `equal`); values are lists of justifications. Multiple justifications for the same bindings accumulate.

The first/last answer time recording feeds the `:time-to-first-answer` and `:time-to-last-answer` metrics. Without metrics requested, the times are not computed (the start-time would be nil and the conditionals skip).

## `transformation-add-node` — the parallel for transformation

The transformation worker has its own `transformation-add-node(rule-assertion, rule-pivot-asent, rule-pivot-sense, v-bindings, &optional more-supports)`. It computes the new positive and negative literals (via `transformation-rule-dependent-lits`) and dispatches via `*transformation-add-node-method*`.

The "legacy harness no longer supported" error in both add-node functions reflects the cleanup the port has done: only the new (pattern-driven) harness path remains. The clean rewrite should keep the dispatch indirection but can remove the legacy comment.

`transformation-rule-dependent-lits(rule, asent-from-rule, asent-sense)`:
- Get the rule's CNF
- If `:pos` sense: new pos-lits = rule's neg-lits, new neg-lits = (rule's pos-lits minus pivot)
- If `:neg` sense: new pos-lits = (rule's neg-lits minus pivot), new neg-lits = rule's pos-lits

This is the standard "remove the literal we matched, the rest becomes the antecedent." For a rule `(impl (and A B) C)` matched on `C`, the dependent lits are `A AND B` (which become a join-ordered subproblem).

## Transformation early-removal threshold

`*transformation-early-removal-threshold* = 8`:
> If any non-backchain literals exist in the transformation layer, and they have an estimated removal cost less than this, force these removals to be done first. Since the productivity of join-ordered links is doubled, this is equal to DOUBLE the number of children that the focal problem can have and still be considered for early removal.

In a transformation tactic that produces a join-ordered subproblem, if some literals are cheap removals, do those first before continuing the transformation. Saves work — early removal might eliminate the whole branch.

`nil` = never; `t` = always; integer = the threshold.

## Backward-utilities

### `relevant-directions()`

Returns the list of `:direction` values relevant to the current inference context:
- Within forward inference (and not within assertion forward propagation): `(:forward)` only
- Otherwise: `(:backward :forward)` — both

Forward inference uses forward-direction rules; backward inference uses both. This is the gate that prevents backward-direction rules from firing during forward propagation.

`direction-is-relevant(assertion)` — same logic but checks a specific assertion's direction.

### `rule-relevant-to-proof(assertion)`

```
or (not *proof-checking-enabled*)
   (member assertion *proof-checker-rules*)
```

For proof-checking mode (verifying a known proof rather than searching for one), filter rules to only those in the proof being checked.

### `inference-canonicalize-hl-support-asent(asent)`

For commutative predicates, sort the args into canonical order. For non-commutative, return as-is.

`inference-make-commutative-asent(predicate, args)` builds the canonical form: sort the args via `inference-canonicalize-commutative-args` (which uses `sort-terms`).

This canonicalization is what allows the engine to recognise `(equal A B)` and `(equal B A)` as the same support without duplicating proofs.

### `additional-source-variable-pos-lits(literal, dependent-dnf, support)`

For variables mentioned in the literal but not in the dependent-dnf, compute their type constraints from the originating support's CNF. Returns additional pos-lits (typically `(isa ?V Thing)` or `(isa ?V <Type>)`) to attach to the dependent dnf.

This is what keeps unbound variables from being lost: when a transformation produces a child clause that mentions a variable not introduced by any current literal, the child needs type information for that variable.

## Backward-results

A small file with two specials and missing-larkc reject functions:

- `*inference-intermediate-step-validation-level*` — `:all | :arg-type | :minimal | :none` — controls how aggressively to validate intermediate proof steps. Default `:none` (no validation; fastest). `:all` validates every step's arg-types and well-formedness — slow but catches bad rules.
- `*inference-answer-template*` — used to format answers per a template (defparameter, default nil)
- `reject-inference(inference)`, `note-inference-rejected(inference)` — both missing-larkc; these are the entry points to mark an inference as rejected after the fact

## Forward-inference semantic pruning (in `backward.lisp`)

The bottom half of `backward.lisp` is forward-inference semantic pruning — checks that fire during forward propagation to avoid recording trivially-bad new conclusions.

`semantically-valid-closed-asents?(dnf, &optional mt)` is the entry, dispatching on `*forward-inference-pruning-mode*`:

| Mode | Behaviour |
|---|---|
| `:none` | always valid (no pruning) |
| `:legacy` | run the four legacy checks (asserted-sentence, complete-extent-asserted, isa, genls) |
| `:trivial` | trivial pruning (missing-larkc 31664) |
| `:inference` | full inference-level pruning (missing-larkc 31665) |

The four legacy checks:

- **`semantically-valid-asserted-sentence-asents`** — for `(assertedSentence S)` lits, check that S is actually asserted
- **`semantically-valid-complete-extent-asserted-asents`** — for predicates with complete-extent-asserted, check that the asent appears in GAFs (else it's known-false)
- **`semantically-valid-isa-asents`** — for `(isa A B)` lits where both A and B are FORTs, check that A is actually an instance of B in the KB
- **`semantically-valid-genls-asents`** — analogous for `(genls A B)`

Each is a fast-fail predicate: return T if all checks pass; return nil if any fails.

`*forward-asserted-sentence-pruning-enabled?*` and `forward-complete-extent-asserted-pruning-enabled?` are the gates for the corresponding individual checks. The latter is gated by `(balancing-tactician-enabled?)` — it's only reliable when the balancing tactician is the active strategy.

## When does each piece fire?

| Operation | Triggered by |
|---|---|
| `removal-ask` (full) | Trivial-query fast path; HL modules calling sub-asks; forward-inference rule firing |
| `removal-ask-int` | Direct call inside `removal-ask` |
| `removal-ask-expand` | Direct call inside `removal-ask-int` after tactic-specs computed |
| `removal-add-node` | Every HL module that completes a successful expansion |
| `removal-ask-add-node` | Bound when `removal-add-node-method` is set (i.e. inside `removal-ask`) |
| `transformation-add-node` | Every transformation HL module that completes a rule application |
| `relevant-directions` | Every forward/backward dispatch in workers and modules |
| `inference-canonicalize-hl-support-asent` | Every HL support construction for a commutative predicate |
| `semantically-valid-closed-asents?` | Forward-inference's after-adding pipeline before recording a new conclusion |

## Cross-system consumers

- **Trivial-query fast path** (`inference-trivial.lisp`) — calls `removal-ask` directly.
- **HL modules** (`removal-modules-*.lisp`) — call `removal-add-node` to register their results.
- **Forward inference** (`forward.lisp`) — uses `transformation-add-node` for rule firing, and the semantic-pruning checks before recording new GAFs.
- **Inference parameters** has `:allow-indeterminate-results?` and `:allow-abnormality-checking?` that this path consumes.
- **TVA inference** (`tva-inference.lisp`) — uses `removal-ask` for its baseline lookups.
- **Argumentation** can be triggered indirectly by the supports `removal-ask` returns.

## Notes for the rewrite

- **The shallow `removal-ask` path is essential.** It is the direct query interface that bypasses problem-store overhead. Most HL modules' sub-queries go through this path. Keep it as a separate entry point from the full strategist.
- **Dynamic-special dispatch via `*removal-add-node-method*` is awkward but load-bearing.** The HL module doesn't know who is calling it. The clean rewrite should consider replacing the dispatch with a callback parameter passed explicitly to the module's `:expand` function. But this requires changing every module — a large surgical change.
- **The "legacy harness no longer supported" error** is dead code from the LarKC cleanup. Remove the conditional; the clean rewrite has only the modern path.
- **`removal-ask` is exhaustive by default.** Halt reason `:exhaust-total` means "tried everything, here's all answers." Don't change this default; users who want bounded results pass `:max-number`.
- **Cost-cutoff is the per-query throttle.** `*removal-cost-cutoff*` is bound in the trivial-query path from `:productivity-limit`. This is what prevents removal-ask from going into expensive modules during a quick sub-query.
- **Excepted-assertion filtering at the end** is the cheap abnormality path for removal-ask. Full abnormality check happens in the backward strategist; here it's just "does any support have an `(except ...)` GAF?"
- **`relevant-directions` is the core of forward/backward isolation.** Don't accidentally let a backward-only rule fire during forward propagation; the `relevant-directions` check is what prevents this. Keep it consulted by every rule iteration in workers and modules.
- **`inference-canonicalize-hl-support-asent`** is what makes `(equal A B)` and `(equal B A)` produce the same support. Without it, proofs would deduplicate poorly.
- **Forward-inference semantic pruning has 4 modes.** The default is `:legacy` in production. The newer `:inference` mode (missing-larkc) presumably runs more aggressive checks. The clean rewrite should pick `:legacy` as default and consider whether `:inference` is worth implementing.
- **`:transformation-early-removal-threshold = 8`** is a tuned constant. It pairs with the doubled productivity of join-ordered tactics. If you change one, change the other; the relationship matters.
- **Many `removal-ask-*` variants are missing-larkc** (`removal-ask-bindings`, `removal-ask-justifications`, `removal-ask-template`, `removal-ask-variable`, etc.). They are convenience wrappers that filter the answer tuples. The clean rewrite can implement them as one-liners over `removal-ask`.
- **`*inference-recursive-query-overhead* = 20`** in backward-utilities is a productivity cost added to recursive sub-queries. Keep it; otherwise the strategist underestimates the cost of nested asks.
