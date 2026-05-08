# HL prototypes and abnormality checking

Two small but conceptually distinct subsystems that the inference harness uses to control which rules and proofs are valid:

1. **HL prototypes** — a way to amortise forward-rule application: when a brand-new term is asserted as `(isa NEW-TERM Col)`, instead of re-running every forward rule that could fire for `Col`, look up a *prototypical instance* of `Col` and reuse the rule selection it already paid for. A read-side optimisation that saves rule-relevance work.

2. **Abnormality checking** — when a rule is about to fire (forward or backward), check whether the bindings make this an *abnormal* case (a known exception). If so, refuse the proof. The mechanism by which Cyc handles default reasoning ("birds fly, except penguins").

Both are short files (163 + 108 lines) and occupy a niche in the design that is easy to overlook but load-bearing for correctness.

Source files:
- `inference/harness/hl-prototypes.lisp` (163)
- `inference/harness/abnormal.lisp` (108)

## HL prototypes

### What is a prototypical instance?

For a collection `Col`, the *prototypical instance* is a synthesised constant `ThePrototypical<ColName>` that is asserted to be `(isa <prototype> Col)` and `(quotedIsa <prototype> HLPrototypicalTerm)`. It is "the typical member of `Col`," used as a stand-in to compute "what forward rules apply to instances of Col?" — once, and then cached.

The constants `#$hlPrototypicalInstance` and `#$HLPrototypicalTerm` are KB-level: a `(hlPrototypicalInstance <instance> <col>)` GAF marks an instance as the prototype for that collection. The rewrite needs both constants for HL prototypes to function (`hl-prototypes-enabled?` checks `(valid-constant? #$hlPrototypicalInstance)` and `(valid-constant? #$HLPrototypicalTerm)`).

### When is a prototype created?

Two triggers:

1. **Lazy creation on first use.** `find-or-create-hl-prototypical-instance(col)` looks up the existing prototype via `hl-prototypical-instance(col)` (which queries `(hlPrototypicalInstance _ Col)` via `fpred-value`). If it doesn't exist, `create-hl-prototypical-instance(col, use-transcript?)` mints one.
2. **Bulk pre-creation.** `create-hl-prototypical-instances-for-common-collections(n, use-transcript?)` (missing-larkc) seeds prototypes for the N most-used collections at startup. The "common collections" list comes from `n-most-useful-hl-prototype-collections`, which sorts by historical usefulness.

`create-hl-prototypical-instance(col, use-transcript?)`:
1. Generate a name: `ThePrototypical<ColName>` via `hl-prototypical-instance-name(col)`
2. Create the constant: `cyc-create-new-ephemeral` (in-image only, no transcript) or `ke-create-now` (full KB write with transcript)
3. Assert three GAFs in `*anect-mt*` (the assertion-engine-creating-natural-tautologies microtheory):
   - `(quotedIsa <new> HLPrototypicalTerm)` — flags as a prototype
   - `(hlPrototypicalInstance <new> Col)` — registers the instance
   - `(isa <new> Col)` — actual collection membership
4. Each assertion is performed with carefully tuned `*forward-inference-allowed-rules*` to control which rules fire on the prototype itself (see "Carefully scoped allowed-rules" below).

Once created, the prototype is permanent: it lives in the KB across image restarts.

### When is a prototype consulted?

`hl-prototype-allowed-forward-rules(assertions-found-or-created)` is the entry. It runs from forward-inference's after-adding path when a new GAF is being propagated. The fast path:

```
hl-prototype-allowed-forward-rules(assertions):
  if hl-prototypes-enabled?
     and assertions is a singleton (just one new GAF)
     and possibly-hl-prototype-assertion?(the singleton):
    let col = gaf-arg2(the singleton)            ; what's it isa-ing?
    let prototype = find-or-create-hl-prototypical-instance(col)
    increment hl-prototype-hits, dictionary-increment col counter
    return relevant-hl-prototype-rules(prototype)  ; rules already-known for col's prototype
  else:
    increment hl-prototype-misses
    return forward-inference-allowed-rules()       ; the global default
```

### `possibly-hl-prototype-assertion?` — the gate

A new assertion qualifies for the prototype shortcut iff:
1. It's a `(isa _ _)` GAF (`gaf-assertion-with-pred-p assertion #$isa`)
2. Its MT is `*anect-mt*` or `*core-mt-floor*` (the engine's bootstrapping MTs)
3. The arg1 is a brand-new term (`(onep (num-index new-term))` — exactly one fact about it: this new isa).

The third condition is what makes prototypes *new-term* specific: the optimisation only fires when the term has no other facts yet, so its complete behaviour is determined entirely by its `isa Col` membership and the prototype's already-computed rule set is exactly what would apply.

### `relevant-hl-prototype-rules` — the cached rule set

```lisp
(defun relevant-hl-prototype-rules (term)
  (let ((rules (all-forward-rules-relevant-to-term term)))
    (remove (the-hl-prototype-ke-irrelevant-rule) rules :test #'eq)))
```

Take the full set of forward rules relevant to the term, exclude *the* KE-irrelevant rule (the one that asserts `(keIrrelevantTerm ?X)` for any `?X` quotedIsa HLPrototypicalTerm — we don't want to mark *new* terms irrelevant just because their prototype is). The remaining rules are exactly what should fire on the new instance.

`the-hl-prototype-ke-irrelevant-rule` is a defun-cached lookup of the specific rule — its CNF is searched in `#$UniversalVocabularyMt`. The cached lookup is cleared when the rule is changed (which happens rarely).

### Carefully scoped allowed-rules

`create-hl-prototypical-instance` carefully scopes which forward rules fire during each of its three assertions:

| Assertion | `*forward-inference-allowed-rules*` |
|---|---|
| `(quotedIsa <new> HLPrototypicalTerm)` | only `the-hl-prototype-ke-irrelevant-rule` |
| `(hlPrototypicalInstance <new> Col)` | nil (no rules) |
| `(isa <new> Col)` | `:all` |

Rationale:
- The first assertion is what *makes* the new term a prototype — only the KE-irrelevant rule should react (so the prototype doesn't get other side-effects that would happen to a normal term).
- The second is metadata — no rules should fire.
- The third is the actual collection membership — *all* forward rules should fire so the prototype accumulates the consequences. **This is the work that gets cached.** Future `(isa OTHER-NEW-TERM Col)` assertions can skip this work entirely.

### Statistics

`*gather-hl-prototype-statistics?*` (defaults T) — when on, every prototype hit/miss is counted. `*hl-prototype-hits*`, `*hl-prototype-misses*`, and `*hl-prototype-hit-table*` (per-collection hit counters, for the "most useful collections" ranking).

`show-hl-prototype-statistics()` and `clear-hl-prototype-statistics()` are missing-larkc but the counters themselves are populated.

### Lifecycle summary

| Event | Action |
|---|---|
| Image startup | Optionally pre-seed prototypes for top-N collections |
| New `(isa X Col)` asserted in anect/core-mt-floor with X new | `hl-prototype-allowed-forward-rules` short-circuits rule selection, returning Col's prototype's pre-computed rule set |
| First call to `find-or-create-hl-prototypical-instance(Col)` | Mint the prototype, assert its three GAFs, run all forward rules on it once |
| Subsequent forward propagation | Use the prototype's cached rule set |
| Image save | Prototypes persist in the KB |
| KB rewrite | Prototypes might become stale; `clear-hl-prototype-caches` (missing-larkc) is the reset |

The clean rewrite needs:
- A way to opt out per-test (`*hl-prototypes-enabled?*` flag exists)
- A clearing path when the KB schema changes
- Deferred creation: don't pay the cost until first hit

### `hl-prototypical-instance-after-adding` and `…-after-removing`

The after-adding hook is a no-op (declared, body returns nil). The after-removing hook is missing-larkc. Both are registered as KB functions via `register-kb-function` so the engine can invoke them when the prototype assertions themselves change. The clean rewrite should implement them: removing a prototype assertion needs to invalidate the cached rule set.

## Abnormality checking

Cyc supports default reasoning via `#$abnormal`. A rule is associated with exceptions; before firing the rule, the engine checks whether the current bindings are abnormal wrt the rule. If so, the proof is rejected.

### `rule-has-exceptions?` — the gate

A rule has exceptions iff:
1. It's a rule assertion (`rule-assertion?`)
2. It has meta-assertions (`assertion-has-meta-assertions?`)
3. *Either* there's a positive `abnormal` GAF mentioning the rule (`(plusp (num-gaf-arg-index rule 2 #$abnormal))`)
4. *Or* (likely) there's an `except` predicate GAF — the missing-larkc 12775 in the parallel branch
5. *Or* if `abnormality-except-support-enabled?`, the rule is itself excepted (`excepted-assertion?`)

Most rules don't have exceptions — the check is fast (single integer compare via `num-gaf-arg-index`). For rules that do, the check is skipped only if `*abnormality-checking-enabled*` is nil (e.g. test runs).

### Backward abnormality: `rule-bindings-abnormal?`

```
rule-bindings-abnormal?(store, rule, rule-bindings, transformation-mt):
  when rule-has-exceptions?(rule):
    let bound-values = mapcar #'variable-binding-value (canonicalize-proof-bindings rule-bindings)
    perform abnormality query
      with (store, rule, bound-values, transformation-mt)  ; missing-larkc 35171
    return whether the query returns answers (= abnormal)
```

This is called before a backward transformation tactic produces a proof: if the bindings would result in an abnormal case, the proof is rejected via the `:abnormal` `*proof-reject-reasons*` keyword.

### Forward abnormality: `forward-abnormality-check`

```
forward-abnormality-check(propagation-mt, rule, trigger-bindings, inference-bindings):
  when *abnormality-checking-enabled*:
    when rule-has-exceptions?(rule):
      let rule-variables = rule's node variables           ; missing-larkc 31007
      let bound-values = (nsublis inference-bindings
                                   (nsublis trigger-bindings rule-variables))
      unless (fully-bound-p bound-values):
        cerror — abnormality checker can't verify; assume not abnormal
        return nil
      let *within-forward-inference?* = nil               ; the abnormality check is its own inference
      when (abnormality-check-internal …):                ; missing-larkc 35173
        signal-abnormal …                                 ; missing-larkc 35175 (throws :inference-rejected)
```

When forward inference is about to apply a rule, the engine checks abnormality *before* recording the conclusion. If abnormal, throws `:inference-rejected` (caught by `forward-bindings-abnormal?` which converts to a clean boolean).

### `*within-forward-inference?* = nil` for the inner check

The abnormality check is itself a backward query. To prevent it from recursively triggering forward inference on its own assertions, `*within-forward-inference?*` is bound to nil — the inner check pretends it's running outside forward inference, so forward-only modules (those with `:direction :forward`) are skipped.

This is subtle: forward inference is in progress, but the abnormality check runs as a backward subroutine. The flag must be cleared because forward direction filtering would otherwise prune most of the relevant abnormality rules.

### `*abnormality-transformation-depth*` — depth budget

`*abnormality-transformation-depth*` defaults to 1 — the abnormality check uses at most 1 transformation depth. Deeper backchaining for abnormality detection is too expensive and rarely necessary (most abnormality rules are direct: `(abnormal MyRule (isa ?X Penguin))`).

The clean rewrite should expose this as configurable per-query (some queries may need depth 2 for nested exceptions).

### `:abnormal` proof rejection reason

When an abnormality check fires, the inference adds `:abnormal` to the proof's rejection reasons. The proof is then *not* counted as proving an answer; subsequent reasoning in the same query won't depend on it. This is the linkage to the strategist's `*proof-reject-reasons*` taxonomy.

### Per-query control

`:allow-abnormality-checking?` is an inference static property (default T). When false, the entire abnormality machinery is bypassed — useful for explanatory queries where the user wants to see *all* rules that would fire, including exceptions.

The Cyc default is T because abnormality is the engine's mechanism for default reasoning; turning it off changes the *meaning* of queries, not just their efficiency.

## Cross-system consumers

- **Forward inference** (`inference/harness/forward.lisp`, `forward-modules.lisp`) calls `hl-prototype-allowed-forward-rules` and `forward-bindings-abnormal?` in the propagation loop.
- **Backward strategist** calls `rule-bindings-abnormal?` before producing a transformation proof.
- **Inference parameters** has `:allow-abnormality-checking?` as a static property.
- **KB hooks** — `hl-prototypical-instance-after-adding` is registered as a KB function for the `(hlPrototypicalInstance _ _)` predicate.
- **Rule statistics** — successful proofs that survived abnormality checking are what get counted in `inference-analysis.lisp`.

## Notes for the rewrite

### HL prototypes

- **Keep the optimisation**, but make it explicit at registration time. A new collection that is a candidate for prototyping should be registered as such, rather than letting the engine discover it lazily on every isa assertion.
- **The "new term" gate** (`(onep (num-index new-term))`) is fragile — if any other process touches the term first, the prototype is missed. The clean rewrite could explicitly mark new terms as "prototype candidates" until the first isa assertion.
- **`*anect-mt*` and `*core-mt-floor*` are special MTs** — the prototype optimisation only fires for these. The clean rewrite should preserve this; prototypes shouldn't be created for arbitrary user MTs.
- **Statistics infrastructure** is in place but the display/clear functions are missing-larkc. Implement them; without visibility, the optimisation can't be tuned.
- **The KE-irrelevant rule** is a single hardcoded special case. The clean rewrite can generalise: a list of "rules that should not fire on prototypes" with a simple registry.

### Abnormality checking

- **`*abnormality-checking-enabled*` is a master switch.** Don't conflate it with `:allow-abnormality-checking?` (the per-query property). Keep both — the master switch is for engine debugging; the property is for user control.
- **Abnormality is a *separate inference*.** The forward check binds `*within-forward-inference?*` to nil precisely so the inner check can run as a clean backward query. The clean rewrite should treat abnormality as a sub-query and expose a clear API for "check whether bindings B are abnormal wrt rule R."
- **`*abnormality-transformation-depth* = 1`** is the default and should stay there. Most abnormality rules are direct GAFs.
- **`excepted-assertion?` is the entry to the `except` predicate machinery.** Make sure it's wired up; this is how rule-level exceptions (vs. binding-level) are expressed.
- **Forward abnormality short-circuits via `:inference-rejected` throw.** Keep this; it's the cleanest way to bail out of mid-fire without polluting the propagation queue.
- **The `cerror` for "abnormality checker doesn't have all bindings"** is a debug aid — in production, the assumption "if we can't verify, assume not abnormal" is the safe choice. Keep the cerror as a dev-mode warning.
- **`#$abnormal` is the predicate name; `(abnormal Rule Sentence)` is the GAF shape.** This is part of the KB vocabulary, not the engine vocabulary. The clean rewrite must keep them aligned.
- **Both `rule-bindings-abnormal?` and `forward-abnormality-check` have most of their work as missing-larkc in the LarKC port.** The mechanism is documented but the actual checking query construction is in the missing-larkc bodies. The rewrite must reconstruct from the design: build a query of the form `(or (abnormal RULE bound-instance) (except RULE bound-instance))`, run it as a backward query with `*within-forward-inference?* = nil`, and reject the parent proof if any answers come back.
