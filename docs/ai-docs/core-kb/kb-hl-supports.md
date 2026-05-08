# HL-supports and KB-HL-supports

These two systems together implement *non-assertion supports* — the way Cyc represents "this is true because of an HL inference" without it being a CycL rule application stored as a deduction over an assertion. Inference modules (SBHL, transitivity, reflexivity, evaluation, etc.) produce conclusions that aren't backed by an asserted rule the way a transformation deduction is, but which still need to be tracked, indexed, and persisted across image saves.

The split:

- **`hl-support`** is the value-typed transient form — a 4-tuple `(module sentence mt tv)` carried as a list. Every inference module produces these. They are first-class arguments in the `support-p` polymorphism (along with `assertion` and `kb-hl-support`), but they have no identity: two `(make-hl-support :isa <sentence> mt :true-def)` calls produce equal but non-eq lists.
- **`kb-hl-support`** is the reified, identity-bearing, persisted form. When an `hl-support` shows up somewhere that needs to be persisted (most notably as the support of a deduction, or to be referenced from the KB index), the system reifies it into a `kb-hl-support` with its own integer ID, content struct, dump-id channel, and an indexable record in the KB.

The relationship parallels NAUT/NART: an `hl-support` is to a `kb-hl-support` as a NAUT is to a NART. The unreified form is an s-expression; the reified form is an opaque interned object whose body is the unreified form recoverable on demand.

## When does an HL-support get created?

Two situations:

1. **An inference module returns conclusions.** Removal modules (`removal-modules-isa.lisp`, `removal-modules-genls.lisp`, `removal-modules-evaluation.lisp`, `removal-modules-reflexivity.lisp`, `removal-modules-transitivity.lisp`, …) call `make-hl-support` with their module keyword (`:isa`, `:genls`, `:eval`, `:reflexive`, etc.) and a sentence describing what they computed. The transformation worker passes these up as inference-result supports.

2. **HL-justification recursion produces sub-supports.** When an HL module's `:justify` function (e.g. `hl-justify-reflexive`, `hl-justify-eval`, `hl-justify-sbhl`) is asked "what justifies this support?", it builds *more* hl-supports using `make-hl-support` to represent the sub-justifications. These are returned as the justification list of the parent.

`hl-support` creation is unconditional and cheap — it's just `(list module sentence mt tv)`.

## When does a KB-HL-support get created?

Three situations, all funneling into `create-kb-hl-support hl-support justification`:

1. **A deduction needs a non-assertion support that has identity.** When `kb-create-deduction` wires up support-pointers, an `hl-support` in the supports list isn't directly storable — the support slot needs a reified handle. `canonicalize-support` ([`arguments.lisp`](../../../larkc-cycl/arguments.lisp#L353)) detects an `hl-support`, calls `find-or-possibly-create-kb-hl-support`, which calls `find-kb-hl-support` first (lookup-only), and if no match exists, `possibly-create-kb-hl-support` runs the hl-support's `:justify` function and creates the kb-hl-support iff a non-empty justification is computable. The new kb-hl-support's *own* initial justification is a deduction that points back at itself with the computed justification — see [Bootstrapping](#bootstrapping).

2. **KB load reads a kb-hl-support handle off the dump.** Two-phase: `load-kb-hl-support-shells` mints a shell handle for every dump-id 0..N-1, then `load-kb-hl-support-defs` populates each handle's content from the CFASL stream. This is the mass-rehydration path — handles are made via `make-kb-hl-support-shell`, not `create-kb-hl-support`.

3. **A find-or-create with explicit justification.** `find-or-create-kb-hl-support` (currently a commented declareFunction in the LarKC drop) is the upsert for callers that already have both the hl-support and a precomputed justification list, e.g. forward propagation or bookkeeping update paths.

**Backward queries do not reify hl-supports.** A backward-inference run produces hl-supports as transient supports inside the proof tree; if no deduction is being persisted for the conclusion, no kb-hl-support is ever minted. Reification happens iff something else is about to persist a justification that *includes* the hl-support.

## hl-support module taxonomy

An `hl-support` is tagged with a *module keyword* that names the inference rule that produced it. The set of registered modules is bootstrapped in `hl-supports.lisp` setup phase via `setup-hl-support-module name plist`. The plist carries up to four function references:

- `:verify` — validates that the support is well-formed (does the sentence match the module's expectations?).
- `:justify` — given an hl-support, returns a list of supports that justify it. Used by `hl-support-justify` recursively.
- `:validate` — checks the support against a target MT, used during forward propagation.
- `:forward-mt-combos` — given a support, returns alternate supports with different MTs, allowing a single inference to lift the conclusion to all MTs where it's valid.

The current module set:

| Module | Used by | Purpose |
|---|---|---|
| `:assertion` | (special — `*assertion-support-module*`) | An assertion lifted into the hl-support polymorphism. Distinguishes assertion-supports from real hl-supports in `support-module`. |
| `:code` | `find-assertion-or-make-support` fallback | Sentence-level support with no further structure. Created when a query sentence has no matching assertion. |
| `:opaque` | external systems, abduction | Sentinel for "I have a support but don't know its origin." |
| `:abduction` | abduction module | An abduced conclusion — inference run in reverse, treating the conclusion as a hypothesis. |
| `:bookkeeping` | bookkeeping store | Asserted-by/when/why metadata supporting a bookkeeping-derived conclusion. |
| `:defn` | definition module | A definition-based inference (e.g. `(defnSufficient ...)`). |
| `:elementof` / `:subsetof` | set-membership inference | Set-theoretic inferences. |
| `:sibling-disjoint` | disjointWith inference | Disjoint-collections reasoning. |
| `:equality` | equals inference | Equality propagation. |
| `:eval` | evaluation engine | Result of `cyc-evaluate` / `#$evaluate` reasoning. |
| `:reflexive` / `:reflexive-on` | reflexivity inference | `(P x x)` from `(isa P ReflexiveBinaryPredicate)`. |
| `:transitivity` / `:contextual-transitivity` | GT inference | `(P x z)` from `(P x y)` and `(P y z)` for transitive P. |
| `:tva` / `:rtv` | TVA cache | Transitive value access, the cache layer for transitive predicates. |
| `:minimize` | optimization heuristic | Result of a minimization step. |
| `:consistent` | consistency check | A consistency proof. |
| `:conceptually-related` | concept-relevance | `#$conceptuallyRelated` reasoning. |
| `:admit` / `:admitted-argument` / `:admitted-sentence` / `:admitted-nat` | argument-type / WFF | A term/argument was admitted to fill a typed argument position. |
| `:reformulate` | reformulation | Rewrite-based derivation. |
| `:isa` / `:genls` / `:disjointwith` / `:genlmt` / `:genlpreds` / `:negationpreds` | SBHL | Subsumption-based HL inference. The big ones — these cover most of Cyc's structural reasoning. |
| `:time` | temporal reasoning | Time-sentence support. |
| `:asserted-arg1-binary-preds` | indexed-arg1 lookup | Fast-path predicate-extent retrieval. |
| `:fcp` | formula-pattern-match (`removal-fcp-*`) | A formula-pattern-matching inference. |
| `:shop-effect` | SHOP planner | Plan effect. |
| `:parse-tree` | NL parser | A parse-tree relation. |
| `:word-strings` / `:term-phrases` | NL lexicon | Word/string and term/phrase relationships. |
| `:rkf-irrelevant-fort-cache` | RKF inference | An RKF (Rapid Knowledge Formation) cache result. |
| `:query` | meta-query | A query result lifted as a support. |
| `:matrix-of-reaction-type` | chemistry domain | A reaction-type matrix derivation. |
| `:external` / `:external-eval` | external integration | Externally-computed support. |

Most of the verify/justify/forward-mt-combos function bodies are LarKC-stripped (commented declareFunction). The few that have bodies are `hl-justify-eval`, `hl-justify-reflexive`, `hl-justify-transitivity`, `hl-justify-genls`, `hl-justify-sbhl`, `hl-justify-admit`, `hl-forward-mt-combos-genls`, plus `inference-max-floor-mts-of-genls-paths`.

## Data structures

### hl-support

```lisp
(defstruct (hl-support (:type list)
                       (:constructor nil))
  module sentence mt tv)

(defun make-hl-support (hl-module sentence &optional (mt *mt*) (tv :true-def))
  (list hl-module sentence mt tv))
```

A 4-element list. `:type list` gives free positional accessors (`hl-support-module`, `hl-support-sentence`, `hl-support-mt`, `hl-support-tv`); the `(:constructor nil)` suppresses the auto-generated keyword constructor in favor of the explicit positional `make-hl-support`. The default for `mt` is the dynamic `*mt*` and for `tv` is `:true-def`.

`hl-support-p` is structural: `(and (listp object) (proper-list-p object) (length= object 4) (hl-support-module-p (car object)))`. A four-element list whose car is a registered module keyword.

### kb-hl-support handle

```lisp
(defstruct (kb-hl-support (:conc-name "KB-HLS-"))
  id)
```

Same minimal handle pattern as everything else KB-resident. `valid-kb-hl-support-handle?` checks `kb-hl-support-p` plus `kb-hl-support-handle-valid?`. The robust validity check (`valid-kb-hl-support? object t`) is `missing-larkc 11080`.

### kb-hl-support-content

```lisp
(defstruct (kb-hl-support-content (:conc-name "KB-HLSC-"))
  argument
  dependents)
```

Two slots:

- **`argument`**: the kb-hl-support's *own* justification, as a `deduction`. The deduction's conclusion is the kb-hl-support itself; its supports are the hl-support's `:justify`-computed supports. The kb-hl-support and this deduction are created together.
- **`dependents`**: the set of deductions that *use* this kb-hl-support as a support. Inverse pointer for TMS cascade. Maintained by `kb-hl-support-add-dependent` / `kb-hl-support-remove-dependent`, called from `add-deduction-dependents` / `remove-deduction-dependents` in `deductions-low.lisp`.

Note `kb-hl-support-hl-support` walks one indirection: it pulls the deduction out of `argument`, then `(deduction-assertion deduction)` recovers the original hl-support 4-tuple. The hl-support is *not* stored directly on the kb-hl-support — it's reachable via the bootstrapping deduction.

## Identifier space and indexing

```
ID  → kb-hl-support              *kb-hl-supports-from-ids*       (id-index)
ID  → kb-hl-support-content      *kb-hl-support-content-manager* (LRU + on-disk file-vector)
```

`*kb-hl-support-content-manager*` is a `kb-object-manager` with `*kb-hl-support-lru-size-percentage*` = 5 (the smallest of the LRU caches — kb-hl-supports are uncommon enough that minimal in-memory residency suffices). Files: `kb-hl-support` and `kb-hl-support-index`.

### Sentence-content index — `*kb-hl-support-index*`

Distinct from the term-keyed assertion index, kb-hl-supports have their own four-level lookup table:

```
module → mt → tv → indexed-term → set-of-kb-hl-supports
```

Indexed by every `indexed-term-p` in the support's sentence, *excluding* terms in the unindexed-term blacklist (`*kb-hl-support-index-unindexed-terms*` — `#$isa`, `#$genls`, `#$ist`, `#$evaluate`, `#$genlPreds`, `#$genlInverse`, `#$DefaultSemanticsForStringFn`, `#$SubLStringConcatenationFn`, `#$TheList`, `#$TheSet`, `#$ist-Asserted`). These are too-common predicates and constructors that would dominate every index bucket if included.

Lookup (`lookup-kb-hl-support hl-support`) walks `module → mt → tv`, then for each indexed term in the sentence intersects the per-term sets. The intersection is the candidate set; each candidate is then sentence-equality-checked against the request to find the exact match. The intersection is necessary because a kb-hl-support is registered in *every* indexed-term's bucket, so it appears in many places.

Mention-based lookup (`lookup-kb-hl-supports-mentioning-term term`) does two passes: one over the sentence-index (`lookup-kb-hl-supports-mentioning-term-in-sentence`) and one walking the MT field of every support to find the term inside the MT (`lookup-kb-hl-supports-mentioning-term-in-mt`). The union is returned. This is used by `tms-remove-kb-hl-supports-mentioning-term`, which is the cascade triggered when a term is removed from the KB.

The whole index is locked by `*kb-hl-support-index-lock*` (a `bt:make-lock`) — the only place in the assertion/deduction/kb-hl-support tier that uses explicit locking. Other tiers rely on the storage-module preamble to serialize access.

## Lifecycle

### Birth (kb-hl-support)

`create-kb-hl-support hl-support justification` ([kb-hl-supports.lisp:404](../../../larkc-cycl/kb-hl-supports.lisp#L404)):

1. Mint a new ID via `next-kb-hl-support-id`, allocate a shell, allocate a fresh content struct.
2. **Note creation in progress**: `note-kb-hl-support-creation-started hl-support kb-hl-support` writes into `*kb-hl-supports-being-created*` (a hash from hl-support 4-tuple to in-flight kb-hl-support). This is what `find-kb-hl-support-during-creation` reads to short-circuit re-entrant lookups *during* the bootstrapping deduction's creation, which would otherwise infinitely recurse (see [Bootstrapping](#bootstrapping)).
3. Increment the next-id watermark, register the handle in the id-index, register the content in the manager.
4. Canonicalize the justification (sort the supports list — this can recursively reify *other* hl-supports if the justification contains some), then create a deduction whose conclusion is the kb-hl-support itself: `create-deduction-for-hl-support hl-support canon-just`. Set the kb-hl-support-content's `argument` slot to that deduction.
5. `index-kb-hl-support kb-hl-support hl-support` — register in the four-level sentence index for every indexed term in the sentence.
6. `note-kb-hl-support-creation-complete hl-support` — remove from the in-progress hash.

### Bootstrapping

The kb-hl-support's first justification is a deduction *whose conclusion is the kb-hl-support being created*. This is a chicken-and-egg: making the deduction calls `add-deduction-dependents` on each support, which for hl-support supports means reifying *those* into kb-hl-supports — and one of those might be the very kb-hl-support we're in the middle of creating, if the justification is recursive.

The `*kb-hl-supports-being-created*` hash breaks this. `find-kb-hl-support` checks `find-kb-hl-support-during-creation` first; if the in-flight hash has an entry for this hl-support, return it (handle is valid even though content isn't fully populated yet). The recursive reification then sees the existing handle and skips creation, just registering the new deduction as a dependent.

`hl-justify-for-kb-hl-support hl-support` is the helper that computes the bootstrap justification: it calls `hl-support-justify` and then *removes the support itself* from the result (`remove hl-support ... :test #'equal`) — a kb-hl-support cannot have itself in its own justification list.

### Mutation

The kb-hl-support handle is immutable. The content's `dependents` slot mutates as deductions are added or removed (`kb-hl-support-add-dependent` / `kb-hl-support-remove-dependent`); the `argument` slot is set once at creation and only mutated by the LarKC-stripped `kb-hl-support-reset-argument` / `rejustify-kb-hl-support` paths.

Both mutators call `mark-kb-hl-support-content-as-muted` so the LRU dirty bit fires.

### Death

Two entry points:

- **`tms-remove-kb-hl-support kb-hl-support`** — the TMS cascade. Iterates `do-kb-hl-support-dependents-helper` (every dependent deduction), calls `missing-larkc 12446` per dependent (likely `tms-remove-deduction`, propagating the cascade), then `destroy-kb-hl-support`.

- **`destroy-kb-hl-support kb-hl-support`** — the immediate destructor:
  1. `unindex-kb-hl-support` — strip from the four-level sentence index. Walks back up the levels and remhashes empty buckets (cleanup-trickle-up).
  2. `remove-kb-hl-support` — invalidate the bootstrapping deduction (`remove-deduction` on the argument), free both structs.
  3. `deregister-kb-hl-support-id` and `deregister-kb-hl-support-content` from the id and content tables.

`tms-remove-kb-hl-supports-mentioning-term` is the term-removal cascade — when a constant or NART is removed from the KB, every kb-hl-support whose sentence or MT mentions it is destroyed.

`free-all-kb-hl-support` is the global teardown.

## TMS rejustification queue

The macro `with-kb-hl-support-rejustification` ([kb-hl-supports.lisp:529](../../../larkc-cycl/kb-hl-supports.lisp#L529)) wraps a body that may invalidate kb-hl-support justifications. While inside the wrapper, re-justification work is *enqueued* in `*tms-kb-hl-support-queue*` rather than performed inline. When the outermost wrapper exits, `process-tms-kb-hl-support-queue` drains the queue — which calls `missing-larkc 11060` (likely `possibly-rejustify-kb-hl-support` or similar) for each queued kb-hl-support.

The `enqueueing-kb-hl-supports-for-tms?` predicate detects whether the binding is already active; nested wrappers don't allocate a new queue. This is the same design pattern as the assertion-removal protective wrapper — defer cascade work to the outermost scope so re-entry is safe.

## CFASL serialization

See [cfasl.md](../persistence/cfasl.md). Opcode `*cfasl-opcode-kb-hl-support*` = 37. Like assertions, NARTs, and deductions, kb-hl-supports serialize **only by handle** — recipe path is missing-larkc, immediate output is `cfasl-output-object-kb-hl-support-method` (missing-larkc).

| Direction | Code path |
|---|---|
| Output | `cfasl-output-object-kb-hl-support-method` (missing-larkc) |
| Input | `cfasl-input-kb-hl-support` → `cfasl-input-kb-hl-support-handle` → `cfasl-kb-hl-support-handle-lookup` |

Handle lookup dispatches through `*cfasl-kb-hl-support-handle-lookup-func*`:

| Value | Use |
|---|---|
| `nil` or `'find-kb-hl-support-by-id` | normal in-image |
| `'find-kb-hl-support-by-dump-id` | KB load — translates dump IDs to current IDs |

Unknown ID resolves to `*sample-invalid-kb-hl-support*` (created via `create-sample-invalid-kb-hl-support`).

The kb-hl-support **content** flows over CFASL as two values: `argument` (a deduction handle), `dependents` (a set of deduction handles). `load-kb-hl-support-content` reads them and registers a new content struct.

`with-kb-hl-support-dump-id-table` is the macro that binds both `*kb-hl-support-dump-id-table*` and `*cfasl-kb-hl-support-handle-func*` for the duration of a dump.

The **index** itself is serialized separately. `dump-kb-hl-support-indexing-int` (LarKC-stripped) writes the four-level hash; `load-kb-hl-support-indexing-int filename` reads it via `cfasl-load`.

## KB load / dump lifecycle

Mirror of the assertion path:

1. **Setup** — `setup-kb-hl-support-tables size exact?` allocates `*kb-hl-supports-from-ids*`, `*kb-hl-support-content-manager*`, and `*kb-hl-support-index*`.
2. **Pre-allocate shells** — `load-kb-hl-support-shells` reads the count and mints handles 0..N-1 via `make-kb-hl-support-shell` (which directly registers the handle, bypassing `create-kb-hl-support` and its bootstrapping).
3. **Load contents** — `load-kb-hl-support-defs` either lazy-loads via the file-backed cache (default for non-monolithic) or eagerly streams every kb-hl-support-def from the CFASL.
4. **Load index** — `load-kb-hl-support-indexing-int` reads the four-level hash from a dedicated CFASL file.
5. **Finalize** — `finalize-kb-hl-supports kb-hl-support-count` records the next-id watermark.

`free-all-kb-hl-support` is the inverse.

## Public API surface

```
;; Predicates
(hl-support-p obj) (hl-support-module-p obj) (hl-support-modules)
(kb-hl-support-p obj)
(valid-kb-hl-support? obj &optional robust?)
(valid-kb-hl-support-handle? obj)
(opaque-hl-support-p obj)

;; hl-support construction
(make-hl-support hl-module sentence &optional mt tv)
(find-assertion-or-make-support sentence &optional mt)

;; hl-support accessors (struct positional)
(hl-support-module hl-support) (hl-support-sentence hl-support)
(hl-support-mt hl-support) (hl-support-tv hl-support)

;; Justification
(hl-justify support)                        ; dispatches via support-justification
(hl-support-justify hl-support)             ; calls module's :justify func
(hl-trivial-justification support)          ; (list support)
(hl-forward-mt-combos support)              ; list of MT-shifted alternates

;; kb-hl-support find / create
(find-kb-hl-support hl-support)
(find-kb-hl-support-by-id id)
(find-or-possibly-create-kb-hl-support hl-support)
(possibly-create-kb-hl-support hl-support)
(create-kb-hl-support hl-support justification)

;; kb-hl-support readers
(kb-hl-support-id k) (kb-hl-support-count)
(kb-hl-support-hl-support k)                ; recover the original 4-tuple
(kb-hl-support-sentence k) (kb-hl-support-tv k)
(kb-hl-support-content k)
(kb-hl-support-content-get-argument c)
(kb-hl-support-content-get-dependents c)

;; Mutation
(kb-hl-support-add-dependent k deduction)
(kb-hl-support-remove-dependent k deduction)
(remove-kb-hl-support k)
(destroy-kb-hl-support k)
(tms-remove-kb-hl-support k)
(tms-remove-kb-hl-supports-mentioning-term term)

;; Iteration macros
(do-kb-hl-supports (var &key progress-message done) ...)
(do-kb-hl-support-dependents (dep-var k &key done) ...)
(do-kb-hl-support-supports (sup-var k &key done) ...)
(do-kb-hl-support-arguments (arg-var k &key done) ...)

;; Module registration
(setup-hl-support-module name plist)        ; declare a new module
(hl-support-module-justify-func module)
(hl-support-module-forward-mt-combos-func module)

;; Predicate helpers
(hl-predicate-p obj)                        ; the 18 HL predicates
(non-hl-predicate-p obj)

;; Wrappers
(with-kb-hl-support-rejustification ...)
(with-kb-hl-support-dump-id-table ...)
```

## Consumers

| Consumer | What it uses |
|---|---|
| **Removal modules** (`inference/modules/removal/*.lisp`) | `make-hl-support` to wrap each conclusion (`:isa`, `:genls`, `:eval`, `:reflexive`, `:transitivity`, `:fcp`, …) — the workhorse producer. |
| **Inference workers** (`inference/harness/*.lisp`) | Construct hl-supports for proof attribution. The transformation worker passes them up; the answer worker collects them. |
| **arguments.lisp** | `support-p`, `support-module`, `support-sentence`, `support-mt`, `support-justification`, `support-tv`, `support-<`, `support-equal`, `valid-support?` — the polymorphic support API dispatches on `kb-hl-support-p` and `hl-support-p` cases. `canonicalize-support` reifies hl-supports into kb-hl-supports (path #1 above). |
| **deductions** | A deduction's supports list can hold kb-hl-supports; `add-deduction-dependents` / `remove-deduction-dependents` route to `kb-hl-support-add-dependent` / `-remove-dependent`. `create-deduction-for-hl-support` is called from `create-kb-hl-support` for the bootstrapping deduction. `possibly-unreify-kb-hl-supports` (currently a no-op) is the deduction-side flag for whether to materialize the 4-tuple back from the handle on read. |
| **TMS** (`tms.lisp`) | `tms-remove-argument` dispatches on `hl-support-p` argument and finds the corresponding kb-hl-support to propagate removal. `tms-remove-kb-hl-supports-mentioning-term` cascade. |
| **find-assertion-or-make-support** (`hl-supports.lisp`) | Used by the inference engine when a sentence has no matching assertion — fall back to `make-hl-support :code sentence mt`. |
| **CFASL** (`cfasl-kb-methods.lisp`) | `cfasl-input-kb-hl-support`, `cfasl-kb-hl-support-handle-lookup`. |
| **Dumper** (`dumper.lisp`) | `make-kb-hl-support-shell`, `finalize-kb-hl-supports`, `load-kb-hl-support-def`, `load-kb-hl-support-defs`, `load-kb-hl-support-shells`. |
| **eval-in-api-registrations** | `hl-justify`, `hl-justify-expanded` are exposed as Cyc API entry points for query justification reporting. |

## Files

| File | Role |
|---|---|
| `hl-supports.lisp` | hl-support module taxonomy; per-module verify/justify/forward-mt-combos function references; `make-hl-support`, `hl-support-justify`, `hl-support-modules`, `hl-trivial-justification`, `find-assertion-or-make-support`. The setup phase registers ~30 module keywords. |
| `kb-hl-supports.lisp` | kb-hl-support handle and content struct, id-index, four-level sentence index, create/destroy/find/lookup, bootstrapping protocol, TMS rejustification queue, dump-id table. The big one — much of it is missing-larkc but the lifecycle skeleton is intact. |
| `kb-hl-support-manager.lisp` | content swap layer — `*kb-hl-support-content-manager*` (kb-object-manager wrapper), `register/lookup/deregister-kb-hl-support-content`, LRU. |

## Notes for a clean rewrite

- **Collapse hl-support and kb-hl-support unless they really do need separate identity.** The unreified hl-support is a 4-tuple; the reified kb-hl-support is an opaque handle that recovers the same 4-tuple via a bootstrapping deduction. The distinction exists because kb-hl-supports need to be referenced from CFASL by handle and need their own dependent list. A unified design: every hl-support has implicit identity by `(module sentence mt tv)`, hash-consed at creation; "reification" becomes registering the implicit identity in the dependents-tracking index. The bootstrapping deduction goes away.
- **The bootstrapping deduction is awkward.** A kb-hl-support's first justification is a deduction whose conclusion is the kb-hl-support itself. This circular structure exists because the deduction's only purpose is to attach the justification supports list — but supports lists don't need a deduction wrapper, they're just lists. A clean design stores `justification` directly on the kb-hl-support content struct and skips the wrapper deduction entirely. The deduction-spec polymorphism in TMS code can dispatch on kb-hl-support directly.
- **`possibly-unreify-kb-hl-supports` is currently a no-op flag.** The whole "should I serve hl-support 4-tuples or kb-hl-support handles?" toggle should be eliminated by storing one form consistently and providing explicit converters at API boundaries.
- **The four-level index `module → mt → tv → term → set` should be a single graph index.** Same critique as the assertion-vs-meta index split. A graph keyed on `(term, role)` covers all of these uses; the module/mt/tv hierarchy can be represented as roles or as graph node properties.
- **The unindexed-term blacklist is hard-coded.** `#$isa`, `#$genls`, `#$ist`, etc. would dominate the index buckets. A clean design tracks per-term frequency and dynamically excludes the top-N most common, or uses inverted-index techniques designed for skewed distributions.
- **Missing-larkc is widespread here.** Roughly 80 declareFunctions in `kb-hl-supports.lisp` are commented stubs covering: rejustification (`rejustify-kb-hl-support`, `possibly-rejustify-kb-hl-support`, `tms-possibly-rejustify-kb-hl-support`), validation (`valid-kb-hl-support-content?`, `verify-kb-hl-support`), invariant checking (`kb-hl-support-circular?`, `kb-hl-support-has-invalid-dependent?`, `circular-kb-hl-supports`, `duplicate-kb-hl-supports`), and bootstrap utilities (`bootstrap-kb-hl-supports`, `bootstrap-kb-hl-supports-for-deduction`). The clean rewrite needs all of these — they are the parts of the engine that maintain kb-hl-support consistency over time, not optional.
- **`hl-verify-*` functions are nearly all stripped.** Verification is the safety check that an inference module produced a structurally and contextually valid support; without it, malformed supports propagate. The clean rewrite must implement verify per module.
- **The locking is asymmetric.** `*kb-hl-support-index-lock*` is the only explicit lock in the assertion/deduction/kb-hl-support tier. The other tiers rely on the storage-module preamble dispatching one writer at a time. A clean design unifies the locking model.
- **`hl-justify-eval` is a 30-line `cond` over predicates** — `#$evaluate`, `#$different`, default. Each branch builds a different shape of justification. A cleaner design has the evaluation engine return its justification structure directly rather than reconstructing it post-hoc by re-running the evaluation.
