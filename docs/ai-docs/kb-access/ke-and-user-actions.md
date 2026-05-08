# KE (Knowledge Editor) and user-actions

KE is the **user-facing API for editing the KB** — the layer humans (or scripts impersonating humans) use to assert, unassert, create constants, kill constants, rename, merge, and audit. Each operation:

1. Records the cyclist who did it (cyclist-permission check, transcript log).
2. Routes through the FI (Functional Interface) layer, which handles canonicalization and constraint checking.
3. Adds the operation to the **transcript queue** so it can be replayed in another image.
4. Wraps each operation with KE-level error capture so the API is *guaranteed not to throw*.

The user-actions system is a parallel infrastructure for **representing** queued/pending KE-style operations as first-class objects (a `user-action` struct), with a registry by ID and per-cyclist filtering. Used for KE workflow tools that need to display, summarize, or batch-replay edits.

The two files split:

| File | Role |
|---|---|
| `ke.lisp` | The KE entry points — `ke-create-now`, `ke-find-or-create-now`, `ke-kill-now`, `ke-rename-now`, `ke-assert`, `ke-assert-now`, `ke-assert-wff-now`, `ke-assert-now-int`, `ke-unassert-now`, `do-edit-op`, `cyclist-is-guest`, `ensure-cyclist-ok`. Plus the old-constant-names cache. The `-now` suffix means "execute immediately"; non-`-now` versions queue the operation. |
| `user-actions.lisp` | `action-type` and `user-action` defstructs, the `defaction-type` macro, the registries (`*action-types-by-key*`, `*user-actions*`, `*user-actions-by-id-string*`), the `*user-actions-lock*`. The bulk of the body is missing-larkc — only struct definitions and the `defaction-type` macro survived the LarKC strip. |

## When does KE run?

Five user-driven situations:

1. **A user creates a constant.** `ke-create-now name &optional external-id` — mints a new constant with the given name, records bookkeeping (creator, time, purpose, second), adds to transcript.
2. **A user looks up or creates.** `ke-find-or-create-now name &optional external-id` — returns the existing constant if it exists, otherwise creates it.
3. **A user kills (deletes) a constant or NART.** `ke-kill-now fort` — `fi-kill-int fort`, transcript-records the operation. Cascades through the TMS to remove every assertion mentioning the FORT.
4. **A user renames a constant.** `ke-rename-now constant new-name` — calls `fi-rename-int`, which preserves the constant's external-id but changes its name. Optionally records the old name as `(#$oldConstantName constant old-name)` in `#$BookkeepingMt` (governed by `*note-old-constant-name*`).
5. **A user asserts/unasserts.** `ke-assert formula mt &optional strength direction` — canonicalize, route through `cyc-assert` / `cyc-assert-wff`, record in transcript, timestamp the assertion. The `-now` variants are immediate; the non-`-now` queues via `do-edit-op` if `*use-local-queue?*`.

## KE entry points

### Constant lifecycle

`ke-create-now name &optional external-id`:

```
1. handler-case to capture errors.
2. *fi-last-constant* := nil
3. result := fi-create-int name external-id   -- the actual create, in fi.lisp
4. on success:
     transcript-queue := tl-encapsulate (fi-create 'name external-id)
     fi-timestamp-constant-int (the-cyclist) (the-date) (ke-purpose) (the-second)
       -- writes the four bookkeeping GAFs
     transcript-queue := tl-encapsulate (fi-timestamp-constant ...)
     return constant
5. on caught error: return (nil, (:fatal-error message))
6. on FI error signal: return (nil, (error-type . format-args))
7. otherwise: return (nil, (:unknown-error "..."))
```

The contract: `ke-create-now` *never throws*. It always returns either the new constant or an error list. This is critical for batch scripts and the API — a bug in one creation shouldn't kill the whole batch.

`ke-find-or-create-now name &optional external-id`:

```
constant := fi-find-int name
if constant: return (constant, nil)
else:        ke-create-now name external-id
```

`ke-kill-now fort`:

```
1. fort := eval fort                       -- yes, eval — see notes
2. transcript-op := tl-encapsulate (fi-kill 'fort)
3. handler-case:
     result := fi-kill-int fort
4. on success: add-to-transcript-queue, return result
5. on error / fi-error / unknown — same shape as ke-create-now
```

`fi-kill-int` cascades through TMS removal. The pre-`eval` of fort is a workaround for the case where `fort` is a quoted form — if the caller passes `'(quote SomeConstant)`, the eval unwraps it.

`ke-rename-now constant new-name`:

```
1. old-name := constant-name constant
2. transcript-op := tl-encapsulate (fi-rename 'constant 'new-name)
3. result := fi-rename-int constant new-name
4. on success:
     a. transcript-queue
     b. when *note-old-constant-name* and old-name is a string:
        - in #$BookkeepingMt, find existing #$oldConstantName GAFs for this constant
          and remove them (currently missing-larkc 10961 — likely fi-blast / ke-blast)
        - ke-assert-now (#$oldConstantName constant old-name) #$BookkeepingMt
     c. return result
5. on error: same shape
```

The `oldConstantName` mechanism is for *constant-name lookup persistence* — if the user renames `#$Cat` to `#$Cat-Mammal`, looking up `"Cat"` later should still find `#$Cat-Mammal`. The `*old-constant-names-table*` cache is a hash from old-name string → list of constants currently referencing it.

`initialize-old-constant-names`:

```
total := num-predicate-extent-index #$oldConstantName #$BookkeepingMt
allocate (or clear) *old-constant-names-table*
with relevant-mt-is-eq, *mt* = #$BookkeepingMt:
  do-predicate-extent-index gaf #$oldConstantName, truth :true:
    if gaf-assertion?:
      constant := gaf-arg gaf 1
      string   := gaf-arg gaf 2
      cache-old-constant-name string constant
return hash-count
```

`old-constant-names string` returns the list of constants previously named `string`.

`cache-old-constant-name string constant` adjoins to the entry; `decache-old-constant-name string constant` removes.

### Assert / unassert

`ke-assert formula mt &optional strength direction`:

```
1. when null strength: strength := :default
2. when ensure-cyclist-ok:                -- cyclist permission check
     mt := canonicalize-hlmt mt
     ans := do-edit-op (fi-assert 'formula 'mt 'strength ['direction])
     unless ans is :queued:
       error := fi-get-error-int
     do-edit-op (fi-timestamp-assertion 'cyclist 'date 'purpose 'second)
     unless :queued: signal-fi-error error
     return ans
```

`ke-assert-now formula mt &optional strength direction` — calls `ke-assert-now-int formula mt strength direction nil` (wff? = nil).

`ke-assert-wff-now formula mt &optional strength direction` — calls `ke-assert-now-int formula mt strength direction t` (wff? = t, skips well-formedness check).

`ke-assert-now-int formula mt strength direction wff?`:

```
1. v-hlmt := canonicalize-hlmt mt
2. handler-case (or unguarded if *inference-debug?*):
     *fi-last-assertions-asserted* := nil
     v-properties := (:strength strength :direction direction)
     result := if wff?: cyc-assert-wff formula v-hlmt v-properties
               else:    cyc-assert formula v-hlmt v-properties
     assertions := *fi-last-assertions-asserted*
3. on success:
     transcript-queue := tl-encapsulate (fi-assert ...)
     for each new assertion: timestamp via fi-timestamp-assertion-int (queued)
     return result
4. on error: same shape
```

`*fi-last-assertions-asserted*` is the dynamic accumulator that the FI layer fills with each assertion it creates during the canonicalization expansion (one EL formula can produce multiple HL assertions).

`ke-unassert-now` (registered with the API but the body is missing-larkc) — the symmetric case, calling `cyc-unassert`.

### Transcript and edit-op routing

`do-edit-op form`:

```
if *use-local-queue?*:
  add-to-local-queue form t              -- queue for batched apply
else:
  eval form                              -- immediate
```

The local-queue mode lets a script accumulate operations and apply them as a batch at the end (with rollback on any failure). The default is immediate execution.

`add-to-transcript-queue` enqueues onto the running transcript so the operation can be replayed in another image.

`tl-encapsulate form` wraps a form for transcript serialization — handles constants, NARTs, formula references via the encapsulation system (see [persistence/encapsulation.md](../persistence/) — pending).

### Cyclist permissions

`*allow-guest-to-edit?*` — boolean knob for whether `#$Guest` can edit.

`cyclist-is-guest` — `(equalp (the-cyclist) #$Guest)`, unless allowed.

`ensure-cyclist-ok` — `(error "...not allowed...")` if guest, else t.

`(the-cyclist)` reads the dynamic `*the-cyclist*` (set by login or by `with-bookkeeping-info`). This is the agent recorded as the creator/asserter.

## User-actions

A separate infrastructure intended for queueing and tracking edit operations as first-class objects. Two struct types:

```lisp
(defstruct action-type
  key         ; keyword: :ke-create, :ke-assert, etc.
  summary-fn  ; function: (action) → string ("user X created Y")
  display-fn  ; function: (action stream) → display
  handler-fn) ; function: (action) → execute the action

(defstruct user-action
  id-string       ; unique string ID (UUID-style)
  type-key        ; the action-type key
  cyclist         ; who initiated
  creation-time   ; universal-second
  data)           ; per-action payload
```

### `defaction-type` macro

`(defaction-type :ke-create :summary-fn #'summarize-create :display-fn ... :handler-fn ...)`:

```
new-action-type := make-action-type
(setf (action-type-key new-action-type) ':ke-create)
;; for each (key val) in arglist: assign slot
(setf (gethash ':ke-create *action-types-by-key*) new-action-type)
return new-action-type
```

Registers a new action-type in the global registry.

### Registries

```
*action-types-by-key*       hash test eql, size 64        -- registry of action types
*user-actions*              nil                            -- list of all user actions
*user-actions-by-id-string* hash test equal, size 64      -- index by id-string
*user-actions-lock*         lock                           -- thread-safety
```

### Operations (mostly missing-larkc)

| Function | Purpose |
|---|---|
| `print-action-type` | (active declareFunction, no body) |
| `action-type-by-key key` | (active declareFunction, no body) |
| `print-user-action object stream depth` | `missing-larkc 29498` |
| `user-actions-empty?` | (no body) |
| `user-actions-size` | (no body) |
| `new-user-action type-key` | (no body) |
| `delete-user-action user-action` | (no body) |
| `user-action-by-id-string id-string` | (no body) |
| `user-action-type user-action` | (no body) |
| `user-action-summary-fn-lookup user-action` | (no body) — lookup summary-fn via action-type |
| `user-action-display-fn-lookup user-action` | (no body) |
| `user-action-handler-fn-lookup user-action` | (no body) |
| `all-actions-for-cyclist cyclist` | (no body) |
| `all-actions-for-cyclist-of-type cyclist type-key` | (no body) |

The clean rewrite must implement these to support workflow tooling. The shape is straightforward — each function is a simple lookup or filter on `*user-actions*` / `*user-actions-by-id-string*`.

## Public API surface

```
;; KE entry points
(ke-create name)                          ; missing-larkc body
(ke-create-from-serialization arg1 arg2)  ; missing-larkc body
(ke-create-internal name &optional external-id)  ; missing-larkc body
(ke-create-now name &optional external-id)
(ke-find-or-create-now name &optional external-id)
(ke-recreate-now arg1)                    ; missing-larkc body
(ke-merge arg1 arg2)                      ; missing-larkc body
(ke-merge-now arg1 arg2)                  ; missing-larkc body
(ke-kill fort)                            ; missing-larkc body
(ke-kill-now fort)
(ke-recreate fort)                        ; missing-larkc body
(rename-code-constant constant name)      ; missing-larkc body
(ke-rename constant name)                 ; missing-larkc body
(ke-rename-code-constant constant name)   ; missing-larkc body
(ke-rename-internal constant name)        ; missing-larkc body
(note-old-constant-name constant name)    ; missing-larkc body
(ke-rename-now constant name)
(ke-assert formula mt &optional strength direction)
(ke-assert-now formula mt &optional strength direction)
(ke-assert-wff-now formula mt &optional strength direction)
(ke-assert-now-int formula mt strength direction wff?)
(ke-unassert-now formula mt)              ; registered as Cyc API; missing-larkc body
(ke-reassert-assertion-now arg1 arg2 arg3)         ; missing-larkc body
(ke-reassert-assertion-now-int ...)                ; missing-larkc body
(ke-reassert-assertion arg1 arg2 arg3)             ; missing-larkc body
(ke-repropagate-assertion-now assertion)           ; missing-larkc body
(ke-repropagate-assertion assertion)               ; missing-larkc body

;; Form mutators
(ke-blast formula mt)                              ; missing-larkc body
(ke-blast-assertion assertion)                     ; missing-larkc body
(ke-blast-all-dependents assertion)                ; missing-larkc body
(ke-rename-variables formula mt rename-alist)      ; missing-larkc body
(ke-remove-argument formula mt argument)           ; missing-larkc body
(ke-remove-deduction deduction)                    ; missing-larkc body
(ke-tms-reconsider-term fort &optional mt)         ; missing-larkc body
(ke-tms-reconsider-formula formula mt)             ; missing-larkc body
(ke-tms-reconsider-assertion assertion)            ; missing-larkc body
(ke-change-assertion-direction assertion direction); missing-larkc body
(ke-change-assertion-strength assertion strength)  ; missing-larkc body
(ke-change-assertion-mt assertion mt &optional also-change-meta-assertions?) ; missing-larkc body
(ke-convert-assertion assertion new-type &optional new-mt new-direction)     ; missing-larkc body
(ke-eval-now form)                                 ; missing-larkc body

;; Form helpers (mostly missing)
(formulas-differ-only-in-strings f1 f2)            ; missing-larkc body
(tree-equal-ignoring-type t1 t2 type &optional test) ; missing-larkc body
(find-assertions-via-tl formula mt)                ; missing-larkc body
(ke-assertion-edit-formula assertion)              ; missing-larkc body
(ke-assertion-find-formula assertion)              ; missing-larkc body

;; Old-constant-names cache
(old-constant-names string)
(initialize-old-constant-names)
(cache-old-constant-name string constant)
(decache-old-constant-name string constant)

;; Edit-op routing
(do-edit-op form)
(cyclist-is-guest)
(ensure-cyclist-ok)

;; Variables
(*note-merged-constant-name*)
(*note-old-constant-name*)
(*check-if-already-ke-unasserted?*)
(*ke-edit-use-fi-edit*)
(*old-constant-names-table*)
(*ke-assertion-edit-formula-find-func*)            ; default 'assertion-tl-ist-formula
(*ke-assertion-edit-formula-display-func*)         ; default 'assertion-el-formula

;; user-actions
(*action-types-by-key*) (*user-actions*) (*user-actions-by-id-string*) (*user-actions-lock*)
(defaction-type name &rest arglist)
(action-type-by-key key)                           ; missing-larkc body
(user-actions-empty?)                              ; missing-larkc body
(user-actions-size)                                ; missing-larkc body
(new-user-action type-key)                         ; missing-larkc body
(delete-user-action user-action)                   ; missing-larkc body
(user-action-by-id-string id-string)               ; missing-larkc body
(user-action-type user-action)                     ; missing-larkc body
(user-action-summary-fn-lookup user-action)        ; missing-larkc body
(user-action-display-fn-lookup user-action)        ; missing-larkc body
(user-action-handler-fn-lookup user-action)        ; missing-larkc body
(all-actions-for-cyclist cyclist)                  ; missing-larkc body
(all-actions-for-cyclist-of-type cyclist type-key) ; missing-larkc body
(print-user-action object stream depth)            ; missing-larkc body
```

## Consumers

| Consumer | What it uses |
|---|---|
| **Cyc API** | `ke-create-now`, `ke-kill-now`, `ke-assert-now`, `ke-assert-wff-now`, `ke-unassert-now` are registered API entry points |
| **Transcript replay** | `tl-encapsulate`, `add-to-transcript-queue` from every -now operation; the replay engine reads transcripts and re-invokes |
| **`fi.lisp`** | KE delegates to `fi-create-int`, `fi-kill-int`, `fi-rename-int`, `cyc-assert`, `cyc-assert-wff`, `fi-timestamp-constant-int`, `fi-timestamp-assertion-int` |
| **bookkeeping** | Every -now op timestamps via `fi-timestamp-*-int` |
| **TMS** | `ke-kill-now` cascades through `tms-remove-fort`; `ke-tms-reconsider-*` (missing-larkc) would call into `tms-reconsider-*` |
| **Workflow tooling (probable)** | `user-action`, `defaction-type`, the registries — for displaying queued/recent edits |

## Notes for a clean rewrite

- **Most KE entry points are missing-larkc.** Only `ke-create-now`, `ke-find-or-create-now`, `ke-kill-now`, `ke-rename-now`, `ke-assert`, `ke-assert-now`, `ke-assert-wff-now`, `ke-assert-now-int` survived. The clean rewrite needs to reconstruct `ke-blast`, `ke-rename-variables`, `ke-remove-argument`, `ke-remove-deduction`, `ke-change-assertion-*`, etc. — these are core editing operations.
- **The "never throws" contract is good** — every public KE function returns `(value error-list)` and catches all errors. Preserve this in the rewrite; it's what makes batch scripts reliable.
- **`ke-kill-now` does `(eval fort)` on its argument.** This is a hack to handle the case where the caller wraps the FORT in `'`. The clean rewrite either takes only unwrapped FORTs or uses an explicit `:eval-arg?` keyword.
- **The `*fi-last-constant*` and `*fi-last-assertions-asserted*` dynamics are output channels** — FI fills them, KE reads them. A modern design returns the values directly. The dynamic plumbing is from a time when CL macroexpansion was awkward.
- **`*use-local-queue?*` lets KE batch operations** — useful for scripts that want to pre-flight a batch and apply atomically. The clean rewrite supports both modes but with explicit `with-edit-batch` macros instead of a global toggle.
- **The transcript queue is fragile** — a `tl-encapsulate` failure midway through a multi-step KE op leaves a half-committed transcript. The clean rewrite uses two-phase commit: build the entire transcript-op tree, then commit atomically.
- **`*note-old-constant-name*` and `*note-merged-constant-name*`** are debug/tracking switches. Document semantics; possibly fold into a single `:track-history` setting.
- **The user-actions infrastructure is mostly stub.** The struct definitions and `defaction-type` macro are intact; the operations are missing-larkc. The clean rewrite should decide whether to keep this — it's a parallel queueing system to the transcript, useful for UIs that need to show "operations pending review by user X."
- **`*action-types-by-key*` is allocated at file-load time** (`make-hash-table :test #'eql :size 64`). The clean rewrite either initializes lazily or in a setup phase.
- **Cyclist-permission checking is binary** — guest vs not-guest. Modern KBs need finer-grained access (per-MT permissions, per-predicate edit rights). Preserve the hook (`ensure-cyclist-ok`) and extend.
- **`(the-cyclist)`, `(the-date)`, `(ke-purpose)`, `(the-second)`** are dynamic-var accessors used to fill bookkeeping fields. This is an awkward indirection — the clean rewrite passes the bookkeeping context explicitly via `:bookkeeping` keyword args.
- **`canonicalize-hlmt mt` is called from every KE entry point.** This handles MT canonicalization (turning `#$BaseKB` into the canonical HLMT). Pre-canonicalize once at the boundary; KE shouldn't re-canonicalize on every call.
- **The KE/FI split is historical.** KE = bookkeeping + transcript + permission; FI = canonicalization + actual KB modification. A clean rewrite could fold them: a single `assert / unassert / create / kill / rename` API with bookkeeping/transcript wrappers as middleware. The current FI `-int` suffix marking "no transcript / no permission check" is enough for inner uses.
- **`ke-edit-use-fi-edit`** (defglobal, default nil) is a "temporary" toggle that's stuck around. Either commit to one path or remove the dead branch.
- **The "fi-error-signaled?" check pattern is brittle** — relies on dynamic state from FI. Modern designs return errors as values from the inner functions.
