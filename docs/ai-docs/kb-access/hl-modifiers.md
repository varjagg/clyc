# HL modifiers and storage modules

The HL (high-level) modifier layer is the **transaction gateway between higher-level callers and the storage tier**. Every KB write — assert, unassert, deduce, undeduce, create-argument, remove-argument — funnels through this layer, which:

1. Acquires a global lock so writes are serialized.
2. Dispatches local-only / remote-only / both-sides via `*hl-store-modification-and-access*`.
3. Optionally journals the operation to an HL transcript stream.
4. Clears HL-store-dependent caches before and after the body.
5. Selects the right **HL storage module** to actually perform the write — a pluggable handler chosen by predicate and argument-type.

The four files implement four overlapping concerns:

| File | Role |
|---|---|
| `hl-modifiers.lisp` | Concrete modifier entry points: `kb-create-asserted-argument`, `kb-remove-asserted-argument`, `hl-assert-bookkeeping-binary-gaf`, `hl-unassert-bookkeeping-binary-gaf` — thin wrappers around `define-hl-modifier`. |
| `hl-interface-infrastructure.lisp` | The `define-hl-creator` and `define-hl-modifier` macros, the local/remote dispatch knob, the global HL lock, the iterator registry for long-lived iterators carried across remote calls, and the HL transcript stream. |
| `hl-storage-modules.lisp` | Storage-module framework: registry, classification (predicate-specific vs generic, by argument-type), applicability dispatch, "supplants" / "preferred-over" precedence, the `hl-add-argument` / `hl-remove-argument` entry points used by `hl-add-as-kb-assertion`. |
| `hl-storage-module-declarations.lisp` | The concrete storage-module instances: `:regular-kb-assertion`, `:ist`, `:constant-name`, `:assertion-direction`, `:indexical-the-user`, `:perform-subl`. Each declares applicability, add/remove handlers, and (for some) preference info. |

## When does the HL modifier layer run?

Five triggering situations:

1. **A user (or `ke-assert`, or canonicalizer) asserts something.** Top-level entry: `hl-assert cnf mt strength direction &optional variable-map`. This calls `hl-add-argument` with an asserted-argument-spec, which calls `hl-store-perform-action-int :add`, which dispatches to the storage modules.
2. **A user (or unassert path) removes something.** `hl-unassert cnf mt` → `hl-remove-argument` → `hl-store-perform-action-int :remove`.
3. **An inference module concludes a deduction.** `hl-deduce-as-kb-deduction cnf mt supports direction variable-map` from the regular-kb-assertion module's `:add` path.
4. **The bookkeeping store is updated.** `hl-assert-bookkeeping-binary-gaf` / `hl-unassert-bookkeeping-binary-gaf` from the bookkeeping module.
5. **An argument's truth-value is changed.** `kb-create-asserted-argument`, `kb-remove-asserted-argument`, `replace-assertion-asserted-argument-with-tv` (missing-larkc) — replacing the asserted-argument metadata on an existing assertion.

Storage modules themselves register at load time (see [Module declarations](#module-declarations)).

## `define-hl-creator` and `define-hl-modifier`

These two macros are the gates through which all KB mutation passes. They expand to a `defun` plus the surrounding wrapper.

`define-hl-creator name arglist doc type-decls &body body`:

```lisp
(defun ,name ,arglist
  ,doc ,type-decls
  (define-hl-modifier-preamble)              ; clear-hl-store-dependent-caches
  (note-hl-modifier-invocation ',name ...)   ; transcript journal
  (when (hl-modify-anywhere?)                ; some modify mode is active
    (bt:with-lock-held (*hl-lock*)
      (prog1 (progn ,@body)
        (define-hl-modifier-postamble)))))   ; clear caches again
```

`define-hl-modifier name arglist doc type-decls &body body`:

```lisp
(defun ,name ,arglist
  ,doc ,type-decls
  (define-hl-modifier-preamble)
  (note-hl-modifier-invocation ',name ...)
  (when (hl-modify-remote?)
    (missing-larkc 29510))                    ; remote-side write path
  (when (hl-modify-local?)
    (let ((*override-hl-store-remote-access?* t))   ; force local reads for the body
      (bt:with-lock-held (*hl-lock*)
        (prog1 (progn ,@body)
          (define-hl-modifier-postamble))))))
```

Differences:

- **`define-hl-creator`** is "do this if any modification is enabled." Used for new-object-creation paths (e.g. constant creation in `kb-create-constant`).
- **`define-hl-modifier`** is "do remote-side first if remote, then do local-side if local, with a flag forcing reads to be local during the body so the modifier doesn't recurse over the network." Used for paths that mutate existing state (assertion arguments, bookkeeping).

The `define-hl-modifier-preamble` and `-postamble` both call `clear-hl-store-dependent-caches`. So the modifier brackets the work with cache-clear before and after — preventing stale reads inside the body and ensuring downstream consumers see fresh state.

`note-hl-modifier-invocation` is the transcript hook: when `*hl-transcript-stream*` is a stream, the macro outputs the operation's name and args via CFASL. The body is `missing-larkc 29566` — the actual HL operation construction. The clean rewrite must implement this; it's how Cyc replays operations to remote images and replays them to the on-disk transcript log for crash recovery.

## Local/remote knob

```
*hl-store-modification-and-access*  default :local-local
```

Five values:

| Value | Modify | Access |
|---|---|---|
| `:local-local` | local | local |
| `:remote-remote` | remote | remote |
| `:both-local` | both | local |
| `:both-remote` | both | remote |
| `:none-local` | none (read-only) | local |

Predicate helpers — `hl-modify-local?`, `hl-modify-remote?`, `hl-modify-anywhere?`, `hl-access-remote?` — read this variable.

`*override-hl-store-remote-access?*` is a per-body override that the local side of a `define-hl-modifier` sets to t to force reads to be local during the modification body. Without this, an inference query inside a modifier could try to fetch state from the remote side (defeating the purpose of having seized the local lock).

The remote-side path itself is `missing-larkc 29510` and a fleet of helpers (`*remote-hl-store-image*`, `*remote-hl-store-connection-pool*`, `*remote-hl-store-connection-pool-lock*`, `*remote-hl-store-connection-pool-max-size* = 9`). The clean rewrite needs to reconstruct this if remote-image support is desired; the connection-pool size of 9 is the only concrete value preserved.

## HL store iterators

Long-lived iterators that survive across remote-call boundaries. When a query is made via the remote API, the server creates an iterator, registers it in `*hl-store-iterators*` (a process-global hashtable keyed by ID), and returns the ID to the caller. The caller then calls `hl-store-iterator-next id`, `hl-store-iterator-done? id`, `hl-store-iterator-destroy id` over the network, each operating on the registered iterator by ID.

Variables:

```
*hl-store-iterators*           hash       — id → iterator object
*next-hl-store-iterator-id*    fixnum     — monotonic ID allocator
*hl-store-iterator-lock*       lock       — guard for the table
```

API:

| Function | Purpose |
|---|---|
| `note-hl-store-iterator iterator` | register, return ID |
| `lookup-hl-store-iterator id` | fetch by ID |
| `unnote-hl-store-iterator id` | deregister |
| `new-hl-store-iterator-int form` | eval the form, register the resulting iterator |
| `hl-store-iterator-next-int id` | advance, return `(value valid?)` |
| `hl-store-iterator-done-int id` | check exhaustion |
| `hl-store-iterator-destroy-int id` | finalize, deregister |
| `new-hl-store-iterator form &optional buffer-size` | full constructor; if buffer-size > 1, batches multiple values per round-trip (missing-larkc) |

The `new-hl-store-iterator-int` uses `eval` on the form — this is unusual; the form is a SubL/Lisp expression that evaluates to an iterator. Used to package up an iteration spec across the wire.

`candidate-next-hl-store-iterator-id` rolls over at `most-positive-fixnum`. `new-hl-store-iterator-id` keeps trying candidates until it finds one that isn't already registered.

## Storage modules

A **storage module** is a plug-in that knows how to store and retrieve assertions of a particular shape. The dispatcher (`hl-store-perform-action-int`) picks the right module based on the assertion's predicate and argument-spec type, then calls the module's `:add`, `:remove`, or `:remove-all` handler.

### Module structure

A module is a property list with the following keys (defined in `*hl-storage-module-properties*`):

| Property | Meaning |
|---|---|
| `:pretty-name` | human-readable name |
| `:module-subtype` | (further classification) |
| `:module-source` | (origin tag) |
| `:argument-type` | the argument-spec type this module handles (e.g. `:argument`, `:asserted-argument`, `:deduction`) |
| `:sense` | per-sense restriction (`:pos`, `:neg`) |
| `:direction` | per-direction restriction (`:forward`, `:backward`, `:code`) |
| `:required-mt` | if set, module only applies in this MT |
| `:predicate` | predicate this module handles (e.g. `#$ist`, `#$constantName`) |
| `:any-predicates` | if set, list of predicates this module handles |
| `:applicability-pattern` | optional CycL pattern for the asent |
| `:applicability` | function `(argument-spec cnf mt direction variable-map) → boolean`; the actual applicability test |
| `:supplants` | list of module names this module supplants (replaces) |
| `:exclusive` | function `(...) → boolean`; if true, this module is the only applicable one |
| `:preferred-over` | list of module names this module is preferred over |
| `:incompleteness` | function for partial-applicability cases |
| `:add` | function `(argument-spec cnf mt direction variable-map) → boolean`; perform the add |
| `:remove` | function `(argument-spec cnf mt) → boolean`; perform the remove |
| `:remove-all` | function `(cnf mt) → boolean`; perform mass remove |
| `:documentation` | docstring |

The module is registered as an `hl-module` (the generic infrastructure from `modules.lisp`) of `:storage` type.

### Registration

`hl-storage-module name plist` is the public registrar. It:

1. Calls `setup-hl-storage-module` (which destructures the plist for validation, then `register-hl-storage-module`).
2. `register-hl-storage-module` constructs the hl-module via `setup-module name :storage plist`, adds it to `*hl-storage-modules*`, and classifies it.
3. `classify-hl-storage-module` registers in either:
   - `*predicate-specific-hl-storage-modules-table*` (if `:predicate` is set), keyed by predicate
   - or `*predicate-generic-hl-storage-modules*` (if `:predicate` is nil)
   plus always `*argument-type-specific-hl-storage-modules-table*` keyed by argument-type.

`reclassify-hl-storage-modules` rebuilds the indexes from `*hl-storage-modules*`. Used after bulk module changes.

### Solely-specific predicates

`*solely-specific-hl-storage-module-predicate-store*` is a set of predicates for which **only the predicate-specific modules apply, not the generic ones**. Registered via `register-solely-specific-hl-storage-module-predicate predicate`. Currently registered: `#$performSubL` (because `performSubL` shouldn't be stored as a regular KB assertion — it's a meta-construct).

`solely-specific-hl-storage-module-predicate? pred` is the test.

### Module declarations (`hl-storage-module-declarations.lisp`)

The six built-in modules:

| Module | `:predicate` | Applicability | `:add` | What it does |
|---|---|---|---|---|
| `:regular-kb-assertion` | (none — generic) | none of the other specialized modules apply | `hl-add-as-kb-assertion` (creates an assertion via `find-or-create-assertion`) | The default — store as a regular KB assertion |
| `:ist` | `#$ist` | `(#$ist :anything :anything)` matches the asent | `hl-add-as-ist-assertion` (missing-larkc) | Lift the inner formula to the inner MT |
| `:constant-name` | `#$constantName` | `(#$constantName :constant :string)` matches | `constant-name-hl-storage-assert` (missing-larkc) | Side-effect: rename the constant |
| `:assertion-direction` | `#$assertionDirection` | `(#$assertionDirection :assertion (:test cycl-direction-p))` | `assertion-direction-hl-storage-assert` (missing-larkc) | Side-effect: change the assertion's direction |
| `:indexical-the-user` | `#$indexicalReferent` | `(#$indexicalReferent #$TheUser :fully-bound)` | `indexical-the-user-hl-storage-assert` (missing-larkc) | Side-effect: bind the indexical to the bound value |
| `:perform-subl` | `#$performSubL` | `(#$performSubL (or (#$SubLQuoteFn :fully-bound) (#$ExpandSubLFn …)))` | `perform-subl-hl-storage-assert` (missing-larkc) | Side-effect: execute the SubL form (used for runtime hooks) |

(The bookkeeping modules `:my-creator`, `:my-creation-time`, `:my-creation-purpose`, `:my-creation-second` are defined in [bookkeeping-store.md](bookkeeping-store.md).)

The `regular-kb-assertion-applicable?` predicate is the explicit "everything else fell through" test — it returns t iff none of the specialized modules above (plus the bookkeeping ones) report applicable. This ensures regular-kb-assertion only fires when no specialized handler claims the assertion.

`hl-add-as-kb-assertion` is the meaty default-store function:

```
1. Switch on argument-type:
   :asserted-argument → hl-assert-as-kb-assertion (canonicalize, find-or-create-assertion, update tv)
   :deduction          → hl-deduce-as-kb-deduction (canonicalize, tms-add-deduction-for-cnf)
2. signal-fi-error on unknown.
```

`hl-assert-as-kb-assertion`:
1. `fi-canonicalize` the cnf with strength (returns canonicalized cnf, free variables, hl-tv).
2. `find-or-create-assertion canon-cnf mt var-names direction` — get existing or mint new.
3. If success: `hl-assert-update-asserted-argument assertion hl-tv direction` — set the truth/strength on the asserted-argument.

`hl-deduce-as-kb-deduction`:
1. `fi-canonicalize`.
2. `tms-add-deduction-for-cnf canon-cnf mt supports support-truth direction var-names` — adds a deduction with the supports.
3. If `redundant?` — already-present, signal warning, return the existing deduction.

`hl-unassert-as-kb-assertion`:
1. `fi-canonicalize` the cnf.
2. `find-assertion canon-cnf mt` — look up existing.
3. If present and has `get-asserted-argument`: `tms-remove-argument asserted-argument assertion` — TMS cascade.

### The dispatch — `hl-store-perform-action-int`

```
1. Compute argument-type from argument-spec.
2. If cnf is atomic:
     predicate := atomic-cnf-predicate cnf
     predicate-specific-modules := predicate ∩ argument-type modules
     solely-specific? := solely-specific-hl-storage-module-predicate? predicate
     if predicate-specific-modules: try them; success? := result
3. unless success? or solely-specific?:
     predicate-generic-modules := generic ∩ argument-type modules
     if predicate-generic-modules: try them; success? := result
4. return success?
```

The `try-hl-add-modules` / `try-hl-remove-modules` path:

```
applicable-modules, dispreferred-modules := applicable-hl-storage-modules ...
sorted := sort-hl-storage-modules-by-cost applicable-modules ...   ; currently identity
for each module in sorted (until success):
  apply-hl-storage-module module ... action default
  if success: note-successful-hl-storage-module
  return success
unless any succeeded:
  missing-larkc 31649  -- the no-applicable-module error
```

`applicable-hl-storage-modules` walks every candidate, computes the supplanting/dispreferred relations (so a module that's "preferred over" another knocks the loser out of the applicable set), and accumulates the survivors. The "exclusive" property allows a module to declare it's the **only** one for this case — when found, the entire iteration short-circuits.

`update-dispreferred-hl-storage-modules-wrt-applicable-modules` is the precedence-resolution loop: for each module on the current applicable list, look up its `:preferred-over` list, and if those modules are also applicable, demote them to "dispreferred."

The actual cost-sort `sort-hl-storage-modules-by-cost` is the identity function — no cost model implemented. The clean rewrite should add real costing.

### MT canonicalization for decontextualized

```
*robustly-remove-uncanonical-decontextualized-assertibles?*  default t
```

When the user removes a decontextualized assertion in MT M1 but its canonical home is M2, `hl-perform-action-with-storage-modules-int` first tries to remove from `actual-mt = possibly-convention-mt-for-decontextualized-cnf mt cnf` (the canonical MT), and if that fails, robustly tries the user-given `mt`. This handles the case where a predicate was made decontextualized *after* it was already asserted in various MTs.

## Concrete HL modifier entry points (from `hl-modifiers.lisp`)

```lisp
(define-hl-modifier kb-create-asserted-argument (assertion truth strength)
  (let* ((tv (tv-from-truth-strength truth strength))
         (asserted-argument (create-asserted-argument assertion tv)))
    (add-new-assertion-argument assertion asserted-argument)
    asserted-argument))

(define-hl-modifier kb-remove-asserted-argument (assertion asserted-argument)
  (set-assertion-asserted-by assertion nil)
  (set-assertion-asserted-when assertion nil)
  (set-assertion-asserted-why assertion nil)
  (set-assertion-asserted-second assertion nil)
  (remove-assertion-argument assertion asserted-argument)
  (kb-remove-asserted-argument-internal asserted-argument)
  assertion)

(define-hl-modifier hl-assert-bookkeeping-binary-gaf (pred arg1 arg2 mt) ...)
(define-hl-modifier hl-unassert-bookkeeping-binary-gaf (pred arg1 arg2 mt) ...)
```

`possibly-replace-assertion-asserted-argument-with-tv`, `replace-assertion-asserted-argument-with-tv`, `replace-assertion-asserted-argument` are `missing-function-implementation` — the clean rewrite must add them.

`kb-create-asserted-argument-with-tv assertion tv` is a thin convenience that destructures tv into truth+strength.

## Public API surface

```
;; Local/remote knob
*hl-store-modification-and-access*   ; one of :local-local, :remote-remote,
                                     ; :both-local, :both-remote, :none-local
*override-hl-store-remote-access?*
(hl-modify-local?) (hl-modify-remote?) (hl-modify-anywhere?) (hl-access-remote?)

;; Definers
(define-hl-creator name arglist doc type-decls &body body)
(define-hl-modifier name arglist doc type-decls &body body)
(define-hl-modifier-preamble) (define-hl-modifier-postamble)

;; HL transcript
*hl-transcript-stream*
(note-hl-modifier-invocation name &optional arg1 arg2 arg3 arg4 arg5)

;; HL store iterators
*hl-store-iterators*
(new-hl-store-iterator form &optional buffer-size)
(create-hl-store-iterator id)
(hl-store-iterator-done? id) (hl-store-iterator-next id) (hl-store-iterator-destroy id)
(note-hl-store-iterator iter) (lookup-hl-store-iterator id) (unnote-hl-store-iterator id)
(new-hl-store-iterator-int form) (hl-store-iterator-next-int id)
(hl-store-iterator-done-int id) (hl-store-iterator-destroy-int id)

;; Concrete modifiers
(kb-create-asserted-argument assertion truth strength)
(kb-create-asserted-argument-with-tv assertion tv)
(kb-remove-asserted-argument assertion asserted-argument)
(hl-assert-bookkeeping-binary-gaf pred arg1 arg2 mt)
(hl-unassert-bookkeeping-binary-gaf pred arg1 arg2 mt)

;; Storage-module framework
(hl-storage-module name plist)
(setup-hl-storage-module name plist)
(register-hl-storage-module name plist)
(classify-hl-storage-module hl-module pred argument-type)
(reclassify-hl-storage-modules)
(register-solely-specific-hl-storage-module-predicate pred)
(solely-specific-hl-storage-module-predicate? pred)
(*hl-storage-modules*) (*hl-storage-module-properties*)
(*predicate-specific-hl-storage-modules-table*)
(*predicate-generic-hl-storage-modules*)
(*argument-type-specific-hl-storage-modules-table*)
(*solely-specific-hl-storage-module-predicate-store*)

;; Module-property accessors
(hl-storage-module-argument-type m) (hl-storage-module-predicate m)
(hl-storage-module-applicability-func m) (hl-storage-module-exclusive-func m)
(hl-storage-module-preferred-over-info m)
(get-hl-storage-module-property m indicator)
(hl-storage-module-add m argument-spec cnf mt direction variable-map &optional default)
(hl-storage-module-remove m argument-spec cnf mt &optional default)

;; Lookup
(hl-storage-modules-for-predicate pred)
(hl-storage-modules-for-argument-type at)
(hl-storage-modules-for-just-argument-type at)
(hl-storage-modules-for-predicate-and-argument-type pred at)
(hl-storage-module-applicable? m argument-spec cnf mt direction variable-map)
(applicable-hl-storage-modules ms argument-spec cnf mt direction variable-map)

;; Top-level entry points
(hl-add-argument argument-spec cnf mt direction &optional variable-map)
(hl-remove-argument argument-spec cnf mt)
(hl-add-assertible hl-assertible)
(hl-assert cnf mt strength direction &optional variable-map)
(hl-unassert cnf mt)
(hl-store-perform-action-int action argument-spec cnf mt direction variable-map)
(hl-perform-action-with-storage-modules-int action ms ...)
(try-hl-add-modules ...) (try-hl-remove-modules ...)
(hl-add-as-kb-assertion ...) (hl-remove-as-kb-assertion ...)
(hl-assert-as-kb-assertion cnf mt strength direction variable-map)
(hl-deduce-as-kb-deduction cnf mt supports direction variable-map)
(hl-unassert-as-kb-assertion cnf mt)

;; Storage-module spec types
(hl-assertion-spec cnf mt &optional direction variable-map)   ; defstruct (:type list)
(hl-assertible hl-assertion-spec argument-spec)               ; defstruct (:type list)
(*dummy-asserted-argument-spec*)
(*successful-hl-storage-modules*)
(note-successful-hl-storage-module m)

;; Misc applicability tests (called from regular-kb-assertion-applicable?)
(ist-assertion-applicable? ...)
(constant-name-hl-storage-applicable? ...)
(assertion-direction-hl-storage-applicable? ...)
(indexical-the-user-hl-storage-applicable? ...)
(perform-subl-hl-storage-applicable? ...)
```

## Consumers

| Consumer | What it uses |
|---|---|
| **`fi.lisp` / Functional Interface** | `hl-assert`, `hl-unassert`, `hl-add-argument`, `hl-remove-argument` — the user-facing entry points wrap these |
| **Canonicalizer / `ke.lisp`** | calls `hl-assert` / `hl-unassert` after canonicalization |
| **Inference engine** | calls `hl-deduce-as-kb-deduction` (via the modules) when a deduction is being recorded; `kb-create-asserted-argument` for argument creation |
| **TMS** | `kb-remove-asserted-argument` for argument removal cascades |
| **Bookkeeping store** | `hl-assert-bookkeeping-binary-gaf` / `hl-unassert-bookkeeping-binary-gaf`; also defines its own storage modules |
| **Remote-image protocol** | `*hl-store-modification-and-access*` distribution mode |
| **HL transcript replay** | `note-hl-modifier-invocation` records every operation; the transcript stream is consumed by the replay machinery |

## Notes for a clean rewrite

- **The local/remote dispatch is a load-bearing capability** — it lets a Cyc image be a "follower" of another, mirroring writes. Modern equivalents are Raft-style replication. The clean rewrite should either commit to a real replication protocol or drop the feature entirely; the half-implemented `:both-*` modes won't survive scrutiny.
- **`*hl-lock*` is a single global write lock** — fine for read-mostly KBs, but a write-heavy workload will see contention. Modern designs use MVCC or per-table locks. For Cyc's workload (mostly read with periodic batched writes), the global lock is probably correct; just document why.
- **`define-hl-creator` and `define-hl-modifier` are nearly identical macros.** Collapse them — one parameterized macro with `:remote-side` keyword would be enough.
- **The HL transcript (`*hl-transcript-stream*`, `note-hl-modifier-invocation`) is incompletely ported** (`missing-larkc 29566`). The clean rewrite needs this for crash recovery and replication; reconstruct from the call shape.
- **The storage-module dispatch is over-engineered for the current set of modules.** Six modules, only one of which (`:regular-kb-assertion`) handles non-trivial logic; the rest are predicate-specific side-effects that fit a simpler "if predicate is X, run Y" pattern. The `:preferred-over` and `:exclusive` machinery is unused in the current declarations and should be removed unless a future rewrite adds modules that genuinely need precedence.
- **`sort-hl-storage-modules-by-cost` is the identity function.** The cost-sort plumbing exists but no module declares costs. Either remove the plumbing or add real cost annotations.
- **The `register-solely-specific-hl-storage-module-predicate` mechanism is used once** (`#$performSubL`). Generalize or fold into the module declaration directly (`:solely-specific? t`).
- **The destructuring in `setup-hl-storage-module` ignores all the destructured values** — it's just doing structural validation of the plist shape. Either drop the destructuring or wire up the `check-type` calls noted in the comment.
- **The `(:type list)` defstructs for `hl-assertion-spec` and `hl-assertible`** are positional lists. Use real defstructs in the clean rewrite — there's no reason for the list-shape compatibility.
- **`hl-store-perform-action-int` does both classification and dispatch**, mixing "find the right modules" with "try to apply them." Split: `find-applicable-modules` + `apply-modules-in-order`.
- **`note-hl-store-iterator` rolls IDs over fixnum max** — fine for the lifetime of a process. Document that long-running images need to handle ID wrap; if the wrap happens while old IDs are still in use, collisions are possible. The retry loop in `new-hl-store-iterator-id` mostly handles this; but if every fixnum-many IDs are in use simultaneously, the loop is infinite. (Astronomically unlikely; documented for completeness.)
- **`new-hl-store-iterator-int` uses `eval`** — a security smell. Replace with a registered-form-name lookup that selects a function from a known set, so untrusted iteration specs can't be passed.
- **The applicable-modules computation walks dispreference precedence in O(N²)** — for 6 modules, fine; for 60+, it's quadratic. Use a topological sort.
- **The `:regular-kb-assertion-applicable?` test enumerates every other specialized module** — this is fragile. New modules added must be added to the enum. A clean rewrite has the dispatcher pick "the most specific applicable module" without an explicit fallback test.
- **`fi-canonicalize` is called twice on the same CNF** in `hl-assert-as-kb-assertion` and `hl-unassert-as-kb-assertion`. Cache the result during a single user-level call.
- **Robust-decontextualized-removal (`*robustly-remove-uncanonical-decontextualized-assertibles?*`)** is a backwards-compat patch for KB state that pre-existed a predicate's decontextualization. New KBs shouldn't need this; preserve the flag for migration but default it off in clean designs.
