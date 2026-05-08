# FI — Functional Interface

FI is the **older, lower-level KB modification API** that the higher-level KE layer (see [ke-and-user-actions.md](ke-and-user-actions.md)) wraps. While KE adds cyclist-permission, transcript-recording, and the "never-throw" contract, FI does the actual work: argument-type-checking, canonicalization, finding-or-creating the assertion, and routing to the HL layer.

The FI layer is also a **dispatch table**: every operation has a public name (`fi-create`), an internal name (`fi-create-int`), and a "modifies KB?" flag. The public dispatcher looks up the operation, optionally enqueues to the transcript queue, then calls the internal function. The internal functions are the ones that actually do the work.

The dispatcher itself (`fi`, `fi-1`, `safe-fi`, `possibly-add-to-transcript-queues`) is missing-larkc — only the dispatch table and the per-operation `-int` functions survive. The clean rewrite must reconstruct the dispatcher; its shape is documented from the table.

## When does FI run?

Three triggering situations:

1. **A KE operation delegates.** `ke-create-now`, `ke-kill-now`, `ke-rename-now`, `ke-assert-now-int`, etc. all call into `fi-*-int` for the actual work. KE adds the wrappers (cyclist check, transcript, error capture).

2. **The Cyc API receives an FI request.** External callers using the FI API directly (older Cyc clients) invoke operations like `(fi :create "Foo")`. The FI dispatcher decodes this into `fi-create-int`. The dispatcher also enforces the modifies-KB flag (so read-only callers don't accidentally invoke a mutating op).

3. **The HL layer needs canonicalization.** `fi-canonicalize`, `fi-canonicalize-el-term`, `fi-convert-to-assert-hlmt`, `fi-convert-to-fort` are the canonicalization-side helpers used by HL storage modules (e.g. `hl-assert-as-kb-assertion` calls `fi-canonicalize`).

## The dispatch table

`*fi-dispatch-table*` ([`fi.lisp:43`](../../../larkc-cycl/fi.lisp#L43)) is a list of `(:op-key public-fn-symbol internal-fn-symbol modifies-kb?)` entries:

| `:op-key` | Public | Internal | Modifies KB? |
|---|---|---|---|
| `:get-warning` | `fi-get-warning` | `fi-get-warning-int` | nil |
| `:get-error` | `fi-get-error` | `fi-get-error-int` | nil |
| `:find` | `fi-find` | `fi-find-int` | nil |
| `:complete` | `fi-complete` | `fi-complete-int` | nil |
| `:create` | `fi-create` | `fi-create-int` | t |
| `:find-or-create` | `fi-find-or-create` | `fi-find-or-create-int` | t |
| `:create-skolem` | `fi-create-skolem` | `fi-create-skolem-int` | t |
| `:merge` | `fi-merge` | `fi-merge-int` | t |
| `:kill` | `fi-kill` | `fi-kill-int` | t |
| `:rename` | `fi-rename` | `fi-rename-int` | t |
| `:lookup` | `fi-lookup` | `fi-lookup-int` | nil |
| `:assert` | `fi-assert` | `fi-assert-int` | t |
| `:reassert` | `fi-reassert` | `fi-reassert-int` | t |
| `:unassert` | `fi-unassert` | `fi-unassert-int` | t |
| `:edit` | `fi-edit` | `fi-edit-int` | t |
| `:rename-variables` | `fi-rename-variables` | `fi-rename-variables-int` | t |
| `:justify` | `fi-justify` | `fi-justify-int` | nil |
| `:add-argument` | `fi-add-argument` | `fi-add-argument-int` | t |
| `:remove-argument` | `fi-remove-argument` | `fi-remove-argument-int` | t |
| `:blast` | `fi-blast` | `fi-blast-int` | t |
| `:ask` | `fi-ask` | `fi-ask-int` | t |
| `:continue-last-ask` | `fi-continue-last-ask` | `fi-continue-last-ask-int` | t |
| `:ask-status` | `fi-ask-status` | `fi-ask-status-int` | nil |
| `:tms-reconsider-formula` | `fi-tms-reconsider-formula` | `fi-tms-reconsider-formula-int` | t |
| `:tms-reconsider-mt` | `fi-tms-reconsider-mt` | `fi-tms-reconsider-mt-int` | t |
| `:tms-reconsider-gafs` | `fi-tms-reconsider-gafs` | `fi-tms-reconsider-gafs-int` | t |
| `:tms-reconsider-term` | `fi-tms-reconsider-term` | `fi-tms-reconsider-term-int` | t |
| `:hypothesize` | `fi-hypothesize` | `fi-hypothesize-int` | t |
| `:prove` | `fi-prove` | `fi-prove-int` | t |
| `:timestamp-constant` | `fi-timestamp-constant` | `fi-timestamp-constant-int` | t |
| `:timestamp-assertion` | `fi-timestamp-assertion` | `fi-timestamp-assertion-int` | t |
| `:remove-timestamp` | `fi-remove-timestamp` | `fi-remove-timestamp-int` | t |
| `:get-parameter` | `fi-get-parameter` | `fi-get-parameter-int` | nil |
| `:set-parameter` | `fi-set-parameter` | `fi-set-parameter-int` | t |
| `:eval` | `fi-eval` | `fi-eval-int` | t |
| `:local-eval` | `fi-local-eval` | `fi-local-eval-int` | nil |

Note that `:ask` and `:continue-last-ask` are flagged as KB-modifying — they're not, structurally, but they update internal query state (last-ask cache).

The dispatcher (`fi op &rest args`):

```
1. lookup *fi-dispatch-table* op
2. dispatch-entry := (op public-fn int-fn modifies?)
3. *current-fi-op* := op
4. if not modifies? OR transcript-replay-active:
     just call int-fn with args
5. else (modifies KB and not in replay):
     possibly-add-to-transcript-queues op
     within-fi-operation:
       call int-fn with args
6. return result, possibly with fi-error / fi-warning
```

`safe-fi op &rest args` is the never-throw variant (handler-case wrapping `fi`).

## Error and warning state

Two dynamic variables track the most recent error/warning:

```
*fi-error*    nil  defparameter  -- error list (e.g. (:arg-error "Expected X, got Y"))
*fi-warning*  nil  defparameter  -- warning list (same shape)
```

Operations clear these at entry (`reset-fi-error-state`), set them via `signal-fi-error`/`signal-fi-warning`, and downstream code reads via `fi-error-signaled?`/`fi-get-error-int`/`fi-get-warning-int`.

`with-clean-fi-error-state body` rebinds both to nil for body — used so a nested FI op doesn't see its parent's error state.

`fi-error-signaled?` — `(and *fi-error* t)`, the predicate.

The error format is `(error-type format-string &rest format-args)`:
- `:arg-error` — wrong type/shape of argument.
- `:fatal-error` — exception caught.
- `:tautology` — formula reduced to True.
- `:contradiction` — formula reduced to False.
- `:could-not-assert` — HL layer rejected the assertion.
- `:assertion-not-present` — unassert target not in KB.
- `:assertion-not-local` — present but not asserted in target MT.
- `:formula-not-well-formed` — WFF check failed.
- `:redundant-local-assertion` — TV is unchanged.
- `:already-timestamped` — bookkeeping conflict.
- `:invalid-cyclist`, `:invalid-time`, `:invalid-purpose`, `:invalid-second` — bookkeeping arg errors.
- `:no-constant`, `:no-assertions`, `:tautology`, `:contradiction` — internal state errors.
- `:unknown-error` — fall-through.

## Within-FI guard

`*within-fi-operation?*` — set to t while inside an FI op. Used by:
- The transcript code: skip recording during nested FI calls (only the outermost operation goes to the transcript).
- The TMS / inference: detect re-entrancy.
- Callers of `cyc-assert` / `cyc-assert-wff` (which themselves go through fi-assert-int).

`within-fi-operation body` macro — let-binds `*within-fi-operation?* = t` for body.

## Per-operation internals

### `fi-find-int name`

```
1. reset-fi-error-state
2. unless (stringp name): signal-fi-error :arg-error
3. transformed-name := transform-tl-terms-to-hl name
4. find-constant-by-name transformed-name
   (or possibly some other lookup variant)
```

The body in the file appears truncated; `fi-find-int`'s actual implementation is mostly there.

### `fi-create-int name &optional external-id`

The constant minter. Reads the cyclist context, allocates a new constant, mints SUID and external-id (if not given), registers in the constant-completion trie. The result is set into `*fi-last-constant*` so subsequent `fi-timestamp-constant-int` knows what to timestamp.

### `fi-kill-int fort`

The deleter. Cascade-removes via TMS (`tms-remove-fort`-equivalent). Also removes constant-completion entries.

### `fi-rename-int constant name`

Changes the constant's name (preserves external-id).

### `fi-assert-int formula mt &optional strength direction`

The big one. Steps:

```
1. reset-fi-error-state
2. validate formula is a cons (el-formula-p), mt is valid, strength/direction valid
3. transform-tl-terms-to-hl formula and mt        -- TL-form → HL-form conversion
4. fi-convert-to-assert-hlmt mt                   -- ensure MT is in canonical HLMT form
5. canonicalize the sentence (assume-wf or full canonicalize)
   (canon-versions, canon-mt) := canonicalize-assert-sentence formula mt
6. handle the special canonical results:
   - nil       → fi-not-wff-assert-error (well-formedness failure)
   - #$True    → :tautology
   - #$False   → :contradiction
   - otherwise → for each canon-version (cnf, variable-map, query-free-vars):
       direction := (or direction (fi-cnf-default-direction cnf))
       assertion := hl-assert cnf canon-mt strength direction variable-map
       if assertion-p: push to assertions-found-or-created
       if nil:        signal-fi-error :could-not-assert
7. setf *fi-last-assertions-asserted* (nreverse assertions-found-or-created)
8. unless error: forward inference:
       *forward-inference-allowed-rules* := (hl-prototype-allowed-forward-rules ...)
       deductions := perform-forward-inference
9. perform-assert-post-processing assertions deductions    -- skolem function setup
10. janus-note-assert-finished                              -- experimental janus integration
11. return (not fi-error-signaled?)
```

The `*janus-extraction-deduce-specs*` and `janus-note-assert-finished` are integration points for the **Janus** module (mostly missing-larkc; see [Inference index](../README.md#inference-engine--inference-pending)). Janus is a meta-inference module that watches assert-side activity to extract abductive/explanatory inferences.

`fi-cnf-default-direction cnf`:

- For positive atomic clauses where the asent is `#$ist`-wrapped: recurse on the inner sentence; if any inner branch is `:backward`, return `:backward`; else `:forward`.
- For ground atomic clauses: `:forward`.
- Otherwise: `:backward`.

i.e. ground GAFs forward-propagate by default; rules and non-ground assertions backward by default.

### `fi-not-wff-assert-error formula mt`

Builds the error list. When `*generate-precise-fi-wff-errors?*` is t (default): includes the explanation from `explanation-of-why-not-wff-assert formula mt`. When nil: just "Formula was not well formed" without explanation.

### `fi-assert-update-asserted-argument assertion hl-tv direction`

Called from `hl-assert-as-kb-assertion` (see [hl-modifiers.md](hl-modifiers.md)) once an assertion has been found-or-created. Steps:

```
1. push assertion to *fi-last-assertions-asserted*
2. existing := get-asserted-argument assertion
3. if existing:
     if (eq hl-tv (argument-tv existing)):
       if (eq direction current-direction): signal-fi-warning :redundant-local-assertion
       (otherwise: tv same, direction changes — let direction-change handle below)
     else:
       missing-larkc 12457   -- tms-change-asserted-argument-tv
4. else:
     tms-create-asserted-argument-with-tv assertion hl-tv
5. when direction differs: tms-change-direction assertion direction
```

`hl-assert-update-asserted-argument` is a thin alias to `fi-assert-update-asserted-argument`.

### `fi-unassert-int sentence mt`

Symmetric to `fi-assert-int`. Canonicalizes the unassert sentence (which may need different canonicalization than assert; see `canonicalize-fi-unassert-sentence` → `canonicalize-fi-remove-sentence`), then for each canon-version: `hl-unassert cnf mt`. Forward-propagates after success.

### `canonicalize-fi-remove-sentence sentence mt check-for-asserted-argument?`

Looks up the assertion via `find-assertions-cycl el-sentence mt` (after TL→HL transform and ist-unwrap). For each found assertion:
- If `check-for-asserted-argument?` and no asserted-argument exists: signal-fi-warning :assertion-not-local, `deduced-argument? := t`.
- Otherwise: build a canon-version from the assertion's existing CNF.

The function returns `(canon-versions, mt, deduced-argument?)`.

### `canonicalize-unassert-hlmt mt`

`(nart-substitute (tlmt-to-hlmt mt))` — converts TLMT (text-level MT) to HLMT (high-level MT) and substitutes any NART references.

### `fi-timestamp-constant-int cyclist time &optional why second`

Writes the four bookkeeping GAFs (`#$myCreator`, `#$myCreationTime`, `#$myCreationPurpose`, `#$myCreationSecond`) for `*fi-last-constant*`:

```
1. transform-tl-terms-to-hl cyclist, why
2. validate: cyclist is fort, time is integer, why is constant or nil,
             second is universal-second or nil, *fi-last-constant* is constant,
             not already timestamped
3. timestamp-constant *fi-last-constant* cyclist time why second
4. clear *fi-last-constant* and *fi-last-assertions-asserted*
```

`constant-timestamped? constant` — checks any of the four `#$my*` predicates have a value for the constant in any MT.

`timestamp-constant constant cyclist time &optional why second`:

```
v-properties := (:strength :monotonic :direction :backward)
cyc-assert-wff (#$myCreator constant cyclist) #$BookkeepingMt v-properties
cyc-assert-wff (#$myCreationTime constant time) #$BookkeepingMt v-properties
when (constant-p why):
  cyc-assert-wff (#$myCreationPurpose constant why) #$BookkeepingMt v-properties
when (universal-second-p second):
  cyc-assert-wff (#$myCreationSecond constant second) #$BookkeepingMt v-properties
```

Each `cyc-assert-wff` ultimately routes through the `:my-creator`/`:my-creation-*` HL storage modules into the bookkeeping store ([bookkeeping-store.md](bookkeeping-store.md)).

### `fi-timestamp-assertion-int cyclist time &optional why second`

Mirror for `*fi-last-assertions-asserted*` — for each newly-created assertion, write its bookkeeping GAFs about the assertion handle. Validation steps mirror `fi-timestamp-constant-int`, plus the predicate `asserted-assertion-timestamped?` to skip already-timestamped ones.

### `the-date`, `the-second`, `ke-purpose`

Accessors for `*the-date*`, `*the-second*`, `*ke-purpose*` — dynamic vars set by KE before calling `fi-timestamp-*-int`. If the dynamic var is nil, `the-date` and `the-second` return today's universal-date and universal-second.

### Canonicalization helpers

`fi-convert-to-assert-hlmt el-term` — convert an EL-form MT specification into an HLMT for assertion. Calls `fi-convert-to-fort` plus tlmt-to-hlmt.

`fi-convert-to-fort el-term` — find the FORT corresponding to an EL term.

`fi-canonicalize-el-term el-term` — canonicalize an EL term (folds constant references, NAUT-to-NART conversion, etc.).

`fi-canonicalize canon-info &optional canon-gaf strength` — full canonicalization of a CNF + variable-map: applies the canonicalizer, returns `(canon-cnf v-variables hl-tv)`. Used by `hl-assert-as-kb-assertion` and `hl-deduce-as-kb-deduction`.

### Assertion → formula readback

`assertion-fi-formula assertion &optional substitute-vars?` — reconstruct the EL formula from an assertion handle, applying variable substitutions if `substitute-vars?`. Reads:

- the dynamic `*assertion-fi-formula-mt-scope*` for MT context.
- `assertion-cnf` and `assertion-variables`.
- Calls `perform-fi-substitutions` to substitute variables.

`assertion-hl-formula assertion &optional substitute-vars?` — same but returns HL form (no symbol-variable conversion).

`perform-fi-substitutions object &optional symbol-variables` — walk the formula substituting per the variable-map.

`assertion-expand object` — expand any folded references.

## Public API surface

```
;; Dispatch table and dispatcher
(*fi-dispatch-table*)
(fi op &optional arg1 arg2 arg3 arg4 arg5 arg6 arg7 arg8)   ; missing-larkc body
(fi-1 op int-fun modifies-kb?)                              ; missing-larkc body
(safe-fi op &rest args)                                     ; missing-larkc body
(possibly-add-to-transcript-queues op)                      ; missing-larkc body

;; Error/warning state
(*fi-warning*) (*fi-error*)
(*generate-precise-fi-wff-errors?*)
(reset-fi-error-state) (reset-fi-warning) (reset-fi-error)
(signal-fi-warning fi-warning) (signal-fi-error fi-error)
(fi-error-signaled?) (fi-warning-signaled?)                 ; -signaled? body missing-larkc
(fi-get-error-int) (fi-get-warning-int)                     ; -warning-int body missing-larkc
(fi-error-string error)                                     ; missing-larkc body
(fi-get-error-string-int)                                   ; missing-larkc body
(with-clean-fi-error-state &body body)
(fi-get-error)                                              ; public version, missing-larkc body
(fi-get-warning)                                            ; public version, missing-larkc body

;; Within-FI guard
(*within-fi-operation?*) (*current-fi-op*)
(within-fi-operation &body body)
(already-within-fi-operation?)                              ; missing-larkc body

;; Output channels
(*fi-last-constant*)
(*fi-last-assertions-asserted*)
(*merge-fort-assertion-map*)
(*assume-assert-sentence-is-wf?*)
(*the-date*) (*the-second*)
(the-date) (the-second) (ke-purpose)

;; Operation entry points (-int versions; public versions mostly missing-larkc)
(fi-find-int name)
(fi-create-int name &optional external-id)
(fi-create-skolem-int ...)                                  ; missing-larkc body
(fi-find-or-create-int name &optional external-id)          ; missing-larkc body
(fi-merge-int constant-keep constant-merge)                 ; missing-larkc body
(fi-kill-int fort)
(fi-rename-int constant name)
(fi-lookup-int ...)                                         ; missing-larkc body
(fi-complete-int ...)                                       ; missing-larkc body
(fi-assert-int formula mt &optional strength direction)
(fi-reassert-int old-formula new-formula old-mt new-mt)     ; missing-larkc body
(fi-reassert-hl-tv assertion strength)                      ; missing-larkc body
(fi-rededuce-deduction-assertion deduction assertion)       ; missing-larkc body
(fi-unassert-int sentence mt)
(canonicalize-fi-unassert-sentence sentence mt)
(canonicalize-fi-blast-sentence sentence mt)                ; missing-larkc body
(canonicalize-fi-remove-sentence sentence mt check-for-asserted-argument?)
(canonicalize-unassert-hlmt mt)
(fi-edit-int ...)                                           ; missing-larkc body
(careful-fi-edit-int ...)                                   ; missing-larkc body
(fi-rename-variables-int ...)                               ; missing-larkc body
(fi-justify-int formula mt &optional backchain)             ; missing-larkc body
(formula-justify formula mt &optional backchain)            ; missing-larkc body
(gaf-justify sentence mt truth)                             ; missing-larkc body
(one-step-gaf-justify sentence mt)                          ; missing-larkc body
(justify-support support)                                   ; missing-larkc body
(fi-add-argument-int sentence mt support &optional strength direction)  ; missing-larkc body
(convert-hl-support-to-el-support hl-support)               ; missing-larkc body
(convert-hl-support-to-fi-support hl-support)               ; missing-larkc body
(convert-hl-support-to-tl-support hl-support)               ; missing-larkc body
(make-el-support module formula &optional mt tv)            ; missing-larkc body
(fi-canonicalize-el-supports el-supports &optional mt)      ; missing-larkc body
(el-support-assertions el-support mt)                       ; missing-larkc body
(fi-remove-argument-int sentence mt support &optional strength) ; missing-larkc body
(fi-blast-int formula mt)                                   ; missing-larkc body
(fi-ask-int formula &optional mt backchain number time depth) ; missing-larkc body
(fi-ask-ist-query-p formula)                                ; missing-larkc body
(fi-ask-int-new-cyc-query-trampoline ...)                   ; missing-larkc body
(fi-continue-last-ask-int ...)                              ; missing-larkc body
(fi-ask-status-int)                                         ; missing-larkc body
(fi-tms-reconsider-formula-int formula mt)                  ; missing-larkc body
(fi-tms-reconsider-mt-int mt)                               ; missing-larkc body
(fi-tms-reconsider-gafs-int term &optional arg predicate mt) ; missing-larkc body
(fi-tms-reconsider-term-int term &optional mt)              ; missing-larkc body
(fi-hypothesize-int ...)                                    ; missing-larkc body
(fi-prove-int ...)                                          ; missing-larkc body
(fi-eval-int ...)                                           ; missing-larkc body
(fi-local-eval-int ...)                                     ; missing-larkc body
(fi-get-parameter-int ...)                                  ; missing-larkc body
(fi-set-parameter-int ...)                                  ; missing-larkc body

;; Timestamp
(fi-timestamp-constant-int cyclist time &optional why second)
(constant-timestamped? constant)
(timestamp-constant constant cyclist time &optional why second)
(untimestamp-constant constant)                             ; missing-larkc body
(retimestamp-constant constant cyclist time &optional why second) ; missing-larkc body
(fi-timestamp-assertion-int cyclist time &optional why second)
(fi-remove-timestamp-int ...)                               ; missing-larkc body

;; Post-processing
(perform-assert-post-processing assertions deductions)
(perform-assert-post-processing-for-skolem ...)             ; missing-larkc body
(fi-perform-assert-post-processing-for-skolem ...)          ; missing-larkc body
(fi-cnf-default-direction cnf)
(fi-not-wff-assert-error formula mt)
(fi-not-wff-error formula mt)                               ; missing-larkc body
(fi-assert-update-asserted-argument assertion hl-tv direction)
(hl-assert-update-asserted-argument assertion hl-tv direction)

;; Canonicalization
(fi-convert-to-assert-hlmt el-term)
(fi-convert-to-fort el-term)
(fi-canonicalize-el-term el-term)
(fi-canonicalize canon-info &optional canon-gaf strength)
(*cached-fi-canonicalize-gaf-caching-state*)

;; Assertion ↔ formula
(assertion-fi-formula assertion &optional substitute-vars?)
(assertion-hl-formula assertion &optional substitute-vars?)
(assertion-expand object)
(perform-fi-substitutions object &optional symbol-variables)
(*assertion-fi-formula-mt-scope*)

;; GAF helpers
(gaf-sentence-assertion sentence mt)                        ; missing-larkc body
```

## Consumers

| Consumer | What it uses |
|---|---|
| **KE** (`ke.lisp`) | `fi-create-int`, `fi-kill-int`, `fi-rename-int`, `fi-find-int`, `fi-error-signaled?`, `fi-get-error-int`, the `*fi-last-*` dynamics |
| **HL storage modules** | `fi-canonicalize` from `hl-assert-as-kb-assertion` / `hl-deduce-as-kb-deduction` |
| **Bookkeeping** | `fi-timestamp-constant-int`, `fi-timestamp-assertion-int` from `perform-constant-bookkeeping` / `perform-assertion-bookkeeping` |
| **Canonicalizer** | `fi-convert-to-assert-hlmt`, `fi-convert-to-fort`, `fi-canonicalize-el-term` |
| **Inference** (`inference/harness/inference-czer.lisp`) | uses `fi-canonicalize` for query canonicalization |
| **Cyc API** | the `fi` dispatcher is exposed for older clients; `fi-ask-int`, `fi-justify-int`, etc. are query operations |
| **Forward inference** | `fi-assert-int` calls `perform-forward-inference` after a successful assert |
| **Skolemization** | `perform-assert-post-processing` finds skolem NARTs in the new assertions and sets up their definitions |

## Notes for a clean rewrite

- **The dispatcher is missing-larkc.** `fi`, `fi-1`, `safe-fi`, `possibly-add-to-transcript-queues` need to be reconstructed. Shape: lookup operation in `*fi-dispatch-table*`, optionally enqueue to transcript, set `*current-fi-op*`, call internal function with `within-fi-operation` wrapper, return result with error/warning state.
- **The dispatch table mixes operations of very different shapes** — query operations (`:ask`), modifications (`:assert`), state queries (`:get-warning`), and parameter accessors (`:get-parameter`/`:set-parameter`). A clean rewrite separates these into distinct dispatchers.
- **The `:ask` and `:continue-last-ask` operations are flagged as KB-modifying** but they're not. The flag was probably intended to mean "transcript-worthy" — `:ask` operations are recorded in the query log. The clean rewrite distinguishes the two semantics.
- **Most `fi-*` operations are missing-larkc.** `fi-edit-int`, `fi-blast-int`, `fi-justify-int`, `fi-add-argument-int`, `fi-remove-argument-int`, the `fi-tms-reconsider-*-int` family, `fi-ask-int`, `fi-hypothesize-int`, `fi-prove-int`, `fi-eval-int`, the parameter-setting operations — all must be reconstructed.
- **`fi-assert-int` is rich and mostly intact** — it covers canonicalization, special-result handling (tautology/contradiction/well-formedness), HL routing, and forward-inference. Preserve the structure.
- **Tautology/contradiction handling at canonicalization time** is a valuable optimization — short-circuit before reaching HL. The clean rewrite keeps this.
- **`fi-cnf-default-direction` recursively walks `#$ist`-wrapped sentences** — the direction of an `(#$ist M (P x y))` is determined by the inner `(P x y)`'s direction. This matters for ist-decontextualization. Preserve.
- **Forward-inference happens unconditionally after assert** — every `fi-assert-int` triggers forward propagation of the new assertion. Clean rewrite either preserves this default or makes it a parameter (`:forward-propagate? t`).
- **The Janus integration** (`*janus-extraction-deduce-specs*`, `janus-note-assert-finished`) is mostly missing-larkc but the assert-side hook is in place. Janus is described in the inference docs (pending).
- **`*assume-assert-sentence-is-wf?*` skips well-formedness check** for `cyc-assert-wff` — useful when the caller has already validated. Should be a `:wf?` keyword instead of a dynamic global.
- **`fi-not-wff-assert-error` calls `explanation-of-why-not-wff-assert`** which is missing-larkc. The clean rewrite needs detailed WFF errors.
- **The `*the-date*` / `*the-second*` overrides** allow scripts to assert with arbitrary timestamps (e.g. for back-dated imports). The accessors return today's date if unset. Preserve as a controlled overrides mechanism.
- **`timestamp-constant` is hard-coded `:strength :monotonic :direction :backward`** for all four bookkeeping GAFs. The strength choice (monotonic) prevents these from being overridden by default-strength reassertions. Document this.
- **`perform-assert-post-processing` is mostly missing-larkc** — the skolem-function-defining-assertion path. Without this, forward-skolemization in rules doesn't generate the supporting `(isa Sk-1 SkolemFunction)`/`(arity Sk-1 N)` etc. assertions. Critical for rule reasoning.
- **Error format `(error-type format-string &rest args)`** is a structured-error pattern that's reasonable. Preserve. Consider extending to richer error metadata (caller frame, transcript reference) for debugging.
- **The error/warning state is dynamic-bindings** — fragile in concurrent contexts. The clean rewrite has each op return its own error/warning along with the result, instead of side-effecting global state.
- **The `*fi-last-constant*` and `*fi-last-assertions-asserted*` output channels** are how FI tells KE/bookkeeping about newly-created entities. Modern designs return these from the operation directly. The dynamic plumbing exists because each operation could create multiple entities (especially `fi-assert-int` which expands one EL formula into multiple HL assertions).
- **`canonicalize-fi-unassert-sentence` vs `canonicalize-assert-sentence`** — different paths because unassert needs to find an existing assertion (matching its CNF in the KB) rather than canonicalize fresh. Preserve the asymmetry.
- **The `:eval` and `:local-eval` operations** allow remote-side and local-side SubL form evaluation through FI. Security-sensitive — these expose `eval` over the FI API. Clean rewrite must lock these down by registered-form-name only, not arbitrary code.
- **`assertion-fi-formula` and `assertion-hl-formula`** are the read-back path — given an assertion handle, return the formula. Two variants because EL form (with symbol variables like `?X`) and HL form (with HL variable handles) differ. Keep both for round-tripping.
- **`*assertion-fi-formula-mt-scope*`** is used for rendering — when displaying an assertion, the surrounding MT scope affects how the formula renders. A cleaner design passes scope explicitly.
- **`fi-error-string` and `fi-get-error-string-int`** (both missing-larkc) format errors for display. The clean rewrite has a single `error-to-string` that takes the structured error and formats it.
- **`possibly-add-to-transcript-queues op`** decides whether to record the operation. Conditional on transcript mode (recording or replaying), with replays skipping recording to avoid loop. Preserve the gate.
