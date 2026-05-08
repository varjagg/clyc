# Bookkeeping store

The bookkeeping store records *who created what, when, and why* for every fact in the KB. Specifically, four binary GAFs in `#$BookkeepingMt` carry this metadata:

| Predicate | Meaning |
|---|---|
| `#$myCreator` | the cyclist who created the term/assertion |
| `#$myCreationTime` | universal date the term/assertion was created |
| `#$myCreationPurpose` | the `#$Cyc-BasedProject` for which it was created |
| `#$myCreationSecond` | universal second of creation (sub-day timestamp) |

These are real CycL assertions, but they bypass the regular KB-assertion machinery:

- They are stored in a **dedicated three-level index** (`pred → arg1 → arg2`), not in the per-term KB indexes.
- They use a **specialized HL storage module** per predicate, registered with `register-solely-specific-hl-storage-module-predicate` so the regular-kb-assertion module never fires on them.
- They have their own dump file (`bookkeeping-assertions.cfasl`) and load path.
- They live in `#$BookkeepingMt` exclusively — a hardwired check.

The two files split responsibilities:

| File | Role |
|---|---|
| `bookkeeping-store.lisp` | The store itself: index data structure, assert/unassert/lookup, the four HL storage modules per predicate, the iterator macros, dump/load helpers. |
| `cyc-bookkeeping.lisp` | The *who-am-I* convenience layer: dynamic context (`*cyc-bookkeeping-info*` plist), the `with-bookkeeping-info` / `with-assertion-bookkeeping-info` / `possibly-with-bookkeeping-info` / `without-bookkeeping` macros, and the `perform-constant-bookkeeping` / `perform-assertion-bookkeeping` callbacks invoked when a new term or assertion is created. |

## When does bookkeeping happen?

Five triggering situations:

1. **A new constant is created.** `perform-constant-bookkeeping constant` fires after `kb-create-constant`. If `do-bookkeeping?` is true (i.e. enabled and there's an active bookkeeping context), it fetches `:who`, `:when`, `:purpose`, `:second` from the dynamic plist and asserts the four `myCreator`/`myCreationTime`/`myCreationPurpose`/`myCreationSecond` GAFs via `fi-timestamp-constant-int`.

2. **A new assertion is created.** `perform-assertion-bookkeeping assertion` fires after `kb-create-assertion`. Same shape as the constant case but routes through `fi-timestamp-assertion-int`.

3. **A user is editing the KB and sets up the bookkeeping context.** `with-bookkeeping-info plist body` binds `*cyc-bookkeeping-info*` to the plist. The plist supplies `:who` (a cyclist), `:when` (a universal date), `:purpose` (a `#$Cyc-BasedProject`), `:second` (a universal second). All four are optional; the assertions record only the supplied fields.

4. **Code wants to do bookkeeping using ambient dynamic state.** `possibly-with-bookkeeping-info body` reads `*the-cyclist*`, `*the-date*`, `*ke-purpose*`, `*the-second*` and constructs a fresh bookkeeping-info from them. Used by KE (Knowledge Editor) where the current cyclist is bound globally.

5. **Code wants to suppress bookkeeping.** `without-bookkeeping body` rebinds `*cyc-bookkeeping-info*` to nil. Used during bulk imports, batch reasoning, etc., where you don't want every operation timestamped.

## What's stored, and where

### Two indexes, both in-memory

`*bookkeeping-binary-gaf-store*` — the **primary store**. A three-level structure:

```
pred → arg1 → arg2 (single value per arg1)
```

The top level is an alist `((pred . intermediate-index) ...)`, fixed at the four predicates. Each intermediate-index is a hash from arg1 (the term being described) to arg2 (the value: a cyclist, a date, etc.). Each pred allows one arg2 per arg1 — `single-entry?` is t in `bookkeeping-intermediate-index-insert`, so re-asserting `(myCreator C #$NewCreator)` *replaces* an existing creator (subject to the conflict-detection in `assert-bookkeeping-binary-gaf`).

`*bookkeeping-binary-gaf-arg2-index*` — the **inverse index**. Same shape but with arg1 and arg2 swapped:

```
pred → arg2 → set-of-arg1s
```

Used to answer "give me every term created by cyclist X" without scanning the primary store. `single-entry?` is nil here because many arg1s can share an arg2 (one cyclist creates many terms).

The arg2 index is built only for arg2-indexed predicates: `*arg2-indexed-bookkeeping-predicates-for-hl-store*` = `(#$myCreator #$myCreationPurpose)`. Date/second predicates aren't useful to invert (you don't typically ask "what was created on date D?"), so they get only the primary index.

`bookkeeping-assertion-count` returns `bookkeeping-top-level-index-count` of the primary store — total number of bookkeeping GAFs.

### Three-level index helpers

```
new-bookkeeping-top-level-index keys     ; allocate empty alist of (key . hash)
bookkeeping-top-level-index-lookup index k → intermediate-index
bookkeeping-top-level-index-insert index top mid leaf single-entry?
bookkeeping-top-level-index-count index → integer

new-bookkeeping-intermediate-index       ; (make-hash-table :test #'eq)
bookkeeping-intermediate-index-lookup index k → value
bookkeeping-intermediate-index-set index k v
bookkeeping-intermediate-index-push index k v   ; for set-valued cells
bookkeeping-intermediate-index-insert index k v single-entry?
bookkeeping-intermediate-index-count index → integer
```

Three iteration macros:

| Macro | Walks |
|---|---|
| `do-bookkeeping-top-level-index (key subindex top-index)` | `do-alist` over the alist |
| `do-bookkeeping-intermediate-index (key value subindex)` | `do-dictionary` over the hashtable |
| `do-bookkeeping-assertions (pred arg1 arg2)` | nested walk over both levels of the primary store |
| `do-bookkeeping-asents (asent)` | same, but yields `(make-binary-formula pred arg1 arg2)` |
| `dumper-do-bookkeeping-top-level-index (pred subindex)` | over `(dumper-bookkeeping-binary-gaf-store)` (missing-larkc accessor) |
| `dumper-do-bookkeeping-intermediate-index (arg1 arg2 index)` | thin `do-dictionary` wrapper |

## Assert / unassert path

`assert-bookkeeping-binary-gaf pred arg1 arg2 mt`:

1. Reject unless `mt` is `#$BookkeepingMt`. (Bookkeeping facts cannot be in any other MT.)
2. Look up the existing arg2 for `(pred, arg1)` via `bookkeeping-fpred-value`.
3. If there's an existing value and it differs from the new one — **conflict, return nil** (doesn't overwrite). This is enforced because, e.g., a constant has *one* `#$myCreator`; re-asserting a different creator silently overwriting would be a bug.
4. Otherwise: `assert-bookkeeping-binary-gaf-int` does the primary-store insert, `add-bookkeeping-binary-gaf-indices` does the arg2-index insert (only for arg2-indexed predicates).

`unassert-bookkeeping-binary-gaf` (active declareFunction, body missing-larkc) — symmetric remove. The clean rewrite must implement.

`unassert-all-bookkeeping-gafs-on-term v-term`:

1. Walks every `(pred . subindex)` in the primary store.
2. For each pred, looks up `subindex[v-term]` — i.e. is there a bookkeeping fact about this term at this pred?
3. If so, calls `missing-larkc 31828` (the unassert path).
4. Walks `terms-created-by v-term` — terms whose creator is `v-term` — and unasserts each (`missing-larkc 31829`).
5. Walks `terms-created-for v-term` — terms whose purpose is `v-term` — and unasserts each (`missing-larkc 31830`).

Used by `tms-remove-fort` cascade: when a constant or NART is removed, every bookkeeping fact mentioning it must go.

## Lookup

`bookkeeping-fpred-value pred arg1 &optional mt` — get the single arg2 value:

```
mt must be #$BookkeepingMt
  arg1-subindex := bookkeeping-binary-gaf-store[pred]
  return arg1-subindex[arg1]
otherwise: missing-larkc 30009
```

`bookkeeping-arg1-pred-values pred arg2 &optional mt` — get the arg1s sharing an arg2 value, via the inverse index:

```
mt must be #$BookkeepingMt
  arg2-subindex := bookkeeping-binary-gaf-arg2-index[pred]
  arg1-set := arg2-subindex[arg2]
  return set-element-list arg1-set
otherwise: missing-larkc 30033
```

`terms-created-by cyclist &optional mt` — `bookkeeping-arg1-pred-values #$myCreator cyclist mt`. Returns every term whose creator is `cyclist`.

`terms-created-for purpose &optional mt` — `bookkeeping-arg1-pred-values #$myCreationPurpose purpose mt`.

The reverse-direction lookups (`creator`, `creation-time`, `creation-date`, `creation-purpose`, `creation-second`, `created-when`, `creation-date-cycl`) are all `missing-larkc` — they would simply be `bookkeeping-fpred-value` with the appropriate predicate. The clean rewrite must implement them.

## HL storage modules

The four bookkeeping predicates each have a dedicated HL storage module, all registered as `solely-specific` (so the regular-kb-assertion module never fires on them):

```lisp
(toplevel
  (register-solely-specific-hl-storage-module-predicate #$myCreator)
  (hl-storage-module :my-creator
    (list :pretty-name "myCreator"
          :argument-type :asserted-argument
          :predicate #$myCreator
          :applicability 'my-creator-hl-storage-module-applicable?
          :incompleteness 'bookkeeping-predicate-hl-storage-module-incompleteness
          :add 'bookkeeping-predicate-hl-storage-module-assert
          :remove 'bookkeeping-predicate-hl-storage-module-unassert
          :remove-all 'bookkeeping-predicate-hl-storage-module-unassert))
  ;; …same for :my-creation-time, :my-creation-purpose, :my-creation-second
```

The four applicability functions delegate to a shared base test:

```lisp
(defun bookkeeping-predicate-hl-storage-module-applicable? (argument-spec cnf mt direction variable-map)
  (when (pos-atomic-cnf-p cnf)
    (let ((asent (gaf-cnf-literal cnf)))
      (when (el-binary-formula-p asent)
        (when (null (sequence-term asent))
          (when (hlmt-equal mt #$BookkeepingMt)
            t))))))
```

i.e. positive atomic CNF, binary formula (no sequence-term), MT is `#$BookkeepingMt`. Then each per-predicate applicability adds a pattern test:

| Module | Pattern |
|---|---|
| `:my-creator` | `(#$myCreator :fort :fort)` |
| `:my-creation-time` | `(#$myCreationTime :fort (:test universal-date-p))` |
| `:my-creation-purpose` | `(#$myCreationPurpose :fort :fort)` |
| `:my-creation-second` | `(#$myCreationSecond :fort (:test universal-second-p))` |

The `:add` handler is the same for all four — `bookkeeping-predicate-hl-storage-module-assert`:

```lisp
(let* ((asent (gaf-cnf-literal cnf))
       (pred (atomic-sentence-predicate asent))
       (arg1 (sentence-arg1 asent))
       (arg2 (sentence-arg2 asent)))
  (hl-assert-bookkeeping-binary-gaf pred arg1 arg2 mt))
```

`hl-assert-bookkeeping-binary-gaf` is itself a `define-hl-modifier` wrapping `assert-bookkeeping-binary-gaf` with the standard preamble/postamble + lock + transcript. See [hl-modifiers.md](hl-modifiers.md).

The `:remove` handler is the same `-unassert` for all four (currently missing-larkc).

## Dynamic bookkeeping context (`cyc-bookkeeping.lisp`)

### Variables

```
*bookkeeping-enabled?*    t      defglobal — master switch; set nil to suppress all bookkeeping
*cyc-bookkeeping-info*    nil    defparameter — the active bookkeeping plist
```

### Macros

`with-bookkeeping-info plist body` — bind `*cyc-bookkeeping-info*` to plist for body. The plist keys: `:who`, `:when`, `:purpose`, `:second`.

`with-assertion-bookkeeping-info assertion body` — extract bookkeeping fields from an existing assertion (`asserted-by`, `asserted-when`, `asserted-why`, `asserted-second`) and bind them as the active context. Used to "do this work as if it were created by the same person/time as this existing assertion."

`possibly-with-bookkeeping-info body` — pull from ambient `*the-cyclist*` / `*the-date*` / `*ke-purpose*` / `*the-second*` and wrap body. Used by KE.

`without-bookkeeping body` — bind `*cyc-bookkeeping-info*` to nil for body. Used during bulk imports.

### Functions

`cyc-bookkeeping-info` — accessor for `*cyc-bookkeeping-info*`.

`do-bookkeeping?` — true iff `*bookkeeping-enabled?*` and `cyc-bookkeeping-info` is non-nil. The standard test all bookkeeping-active code uses to gate.

`new-bookkeeping-info &optional who when why when-sec` — construct a plist from the four fields. Skips nil fields (so a partial info doesn't include nil values).

`cyc-bookkeeping-info-for what` — `getf cyc-bookkeeping-info what`.

`perform-constant-bookkeeping constant` — at constant-creation time, if `do-bookkeeping?`, call `fi-timestamp-constant-int who when purpose when-sec` to assert the four bookkeeping GAFs about the new constant. (`fi-timestamp-constant-int` lives elsewhere — fi.lisp — and ultimately routes through the HL modifier path, calling `hl-assert-bookkeeping-binary-gaf` four times.)

`perform-assertion-bookkeeping assertion` — same shape, calls `fi-timestamp-assertion-int`.

`assertion-bookkeeping-info assertion` — extracts the fields from an existing assertion's argument metadata. Body is missing-larkc.

## CFASL / dump path

The bookkeeping store has its own CFASL file: `bookkeeping-assertions.cfasl` (per [kb-structure.md](../../../.claude/kb-structure.md)). It also has its own indexing file: `bookkeeping-indices.cfasl`.

The dump path:

- `dumper-bookkeeping-binary-gaf-store` (missing-larkc) — return the bookkeeping store in dumpable form.
- `dumper-do-bookkeeping-top-level-index` / `dumper-do-bookkeeping-intermediate-index` — iteration macros for the dumper.
- `dumper-num-top-level-index` / `dumper-num-intermediate-index` (both missing-larkc) — count for size estimation.
- `dumper-dumpable-bookkeeping-index` (missing-larkc) — return the arg2 index in dumpable form.

The load path:

- `dumper-clear-bookkeeping-binary-gaf-store` — reset before load.
- `dumper-load-bookkeeping-binary-gaf pred arg1 arg2` — restore one GAF (calls `assert-bookkeeping-binary-gaf-int`, bypassing the conflict check).
- `dumper-load-bookkeeping-index index` — restore the arg2 index.

The clean rewrite must reconstruct the dumper-side missing-larkc bodies; the load-side is intact.

## Public API surface

```
;; Bookkeeping store (bookkeeping-store.lisp)
(*bookkeeping-binary-gaf-store*)
(*bookkeeping-binary-gaf-arg2-index*)
(*bookkeeping-predicates-for-hl-store*)            ; ($myCreator ... $myCreationSecond)
(*arg2-indexed-bookkeeping-predicates-for-hl-store*); ($myCreator $myCreationPurpose)
(bookkeeping-binary-gaf-store) (bookkeeping-binary-gaf-arg2-index)
(bookkeeping-predicates-for-hl-store)              ; missing-larkc body
(arg2-indexed-bookkeeping-predicates-for-hl-store)
(arg2-indexed-bookkeeping-pred? pred)

;; Index plumbing
(new-bookkeeping-top-level-index keys)
(bookkeeping-top-level-index-lookup idx k)
(bookkeeping-top-level-index-insert idx top mid leaf single-entry?)
(bookkeeping-top-level-index-delete idx top mid leaf single-entry?) ; missing-larkc
(bookkeeping-top-level-index-count idx)
(new-bookkeeping-intermediate-index)
(bookkeeping-intermediate-index-lookup idx k)
(bookkeeping-intermediate-index-set idx k v)
(bookkeeping-intermediate-index-push idx k v)
(bookkeeping-intermediate-index-insert idx k v single?)
(bookkeeping-intermediate-index-num-keys idx)      ; missing-larkc
(bookkeeping-intermediate-index-delete-key idx k)  ; missing-larkc
(bookkeeping-intermediate-index-delete idx k v single?) ; missing-larkc
(bookkeeping-intermediate-index-count idx)

;; Iteration macros
(do-bookkeeping-top-level-index (key sub idx) body)
(do-bookkeeping-intermediate-index (key val idx) body)
(do-bookkeeping-assertions (pred arg1 arg2) body)
(do-bookkeeping-asents (asent) body)
(dumper-do-bookkeeping-top-level-index (pred sub) body)
(dumper-do-bookkeeping-intermediate-index (arg1 arg2 idx) body)

;; Mutation
(clear-bookkeeping-binary-gaf-store)
(assert-bookkeeping-binary-gaf pred arg1 arg2 mt)
(assert-bookkeeping-binary-gaf-int pred arg1 arg2)
(unassert-bookkeeping-binary-gaf pred arg1 arg2 mt)   ; missing-larkc body
(unassert-bookkeeping-binary-gaf-int pred arg1 arg2)  ; missing-larkc body
(add-bookkeeping-binary-gaf-indices pred arg1 arg2)
(remove-bookkeeping-binary-gaf-indices pred arg1 arg2); missing-larkc body
(unassert-all-bookkeeping-gafs-on-term v-term)
(unassert-all-bookkeeping-gafs-for-pred pred)         ; missing-larkc body

;; Lookup
(bookkeeping-fpred-value pred arg1 &optional mt)
(bookkeeping-fpred-value-int pred arg1)
(bookkeeping-arg1-pred-values pred arg2 &optional mt)
(bookkeeping-arg1-pred-values-int pred arg2)
(bookkeeping-arg1-assertion-count pred arg2 &optional mt)  ; missing-larkc body
(bookkeeping-arg1-assertion-count-int pred arg2)            ; missing-larkc body
(bookkeeping-assertion-count)
(num-bookkeeping-binary-gafs-on-term v-term)        ; missing-larkc body
(any-bookkeeping-assertions-on-term? v-term)        ; missing-larkc body
(total-num-assertions-on-term v-term)               ; missing-larkc body

;; Convenience accessors (all missing-larkc; trivial wrappers over bookkeeping-fpred-value)
(creator fort &optional mt)
(creation-time fort &optional mt)
(creation-date fort &optional mt)
(creation-purpose fort &optional mt)
(creation-second fort &optional mt)
(created-when fort &optional mt)
(creation-date-cycl fort)

;; Reverse lookups
(terms-created-by cyclist &optional mt)
(terms-created-for purpose &optional mt)
(num-terms-created-by cyclist &optional mt)         ; missing-larkc body
(num-terms-created-for purpose &optional mt)        ; missing-larkc body

;; Asent / assertible conversion
(bookkeeping-asents-on-term v-term)                 ; missing-larkc body
(bookkeeping-assertibles-on-term v-term)            ; missing-larkc body
(bookkeeping-hl-assertion-specs-on-term v-term)     ; missing-larkc body
(bookkeeping-hl-assertibles-on-term v-term)         ; missing-larkc body
(bookkeeping-asent-to-hl-assertion-spec asent)      ; missing-larkc body
(bookkeeping-asent-to-hl-assertible asent)          ; missing-larkc body
(indexed-terms-mentioned-in-bookkeeping-assertions-of-term term)  ; missing-larkc body
(bookkeeping-asent-truth asent)                     ; missing-larkc body
(bookkeeping-assertion-truth pred arg1 arg2)        ; missing-larkc body
(why-not-bookkeeping-asent asent)                   ; missing-larkc body

;; Reindex
(reindex-all-bookkeeping-assertions)                ; missing-larkc body
(reindex-all-bookkeeping-assertions-for-pred pred)  ; missing-larkc body

;; Storage-module applicability tests (used by regular-kb-assertion-applicable?)
(bookkeeping-predicate-hl-storage-module-applicable? ...)
(bookkeeping-predicate-hl-storage-module-incompleteness ...)  ; missing-larkc body
(bookkeeping-predicate-hl-storage-module-assert ...)
(bookkeeping-predicate-hl-storage-module-unassert ...)        ; missing-larkc body
(my-creator-hl-storage-module-applicable? ...)
(my-creation-time-hl-storage-module-applicable? ...)
(my-creation-purpose-hl-storage-module-applicable? ...)
(my-creation-second-hl-storage-module-applicable? ...)

;; Dumper
(dumper-num-top-level-index)                        ; missing-larkc body
(dumper-num-intermediate-index idx)                 ; missing-larkc body
(dumper-bookkeeping-binary-gaf-store)               ; missing-larkc body
(dumper-clear-bookkeeping-binary-gaf-store)
(dumper-dumpable-bookkeeping-index)                 ; missing-larkc body
(dumper-load-bookkeeping-binary-gaf pred arg1 arg2)
(dumper-load-bookkeeping-index idx)

;; Cyc bookkeeping context (cyc-bookkeeping.lisp)
(*bookkeeping-enabled?*) (*cyc-bookkeeping-info*)
(with-bookkeeping-info plist body)
(with-assertion-bookkeeping-info assertion body)
(possibly-with-bookkeeping-info body)
(without-bookkeeping body)
(cyc-bookkeeping-info)
(do-bookkeeping?)
(new-bookkeeping-info &optional who when why when-sec)
(assertion-bookkeeping-info assertion)              ; missing-larkc body
(cyc-bookkeeping-info-for what)
(perform-constant-bookkeeping constant)
(perform-assertion-bookkeeping assertion)
```

## Consumers

| Consumer | What it uses |
|---|---|
| **constant creation** (`constant-completion-high.lisp`, `constant-handles.lisp`) | `perform-constant-bookkeeping` after `kb-create-constant` |
| **assertion creation** (`assertion-manager.lisp`, `assertions-low.lisp`) | `perform-assertion-bookkeeping` after the new assertion is built |
| **TMS / removal cascades** | `unassert-all-bookkeeping-gafs-on-term` from `tms-remove-fort` |
| **HL storage dispatcher** (`hl-storage-modules.lisp`) | the four `:my-*` modules + `regular-kb-assertion-applicable?` enumerates the bookkeeping applicability tests |
| **KE / user-actions** | `with-bookkeeping-info`, `possibly-with-bookkeeping-info`, `without-bookkeeping` to set/suppress context |
| **Cyc API** | `creator` and `creation-time` are exposed; the rest are missing-larkc but would also be exposed |
| **Dumper / loader** (`dumper.lisp`) | `dumper-load-bookkeeping-binary-gaf` for KB load; the dumper-side dump functions are missing-larkc |
| **cfasl-sexpr exporters** | the bookkeeping store is one of the four authoritative content blobs that must be exported (per kb-structure.md "Reconstructability summary") |

## Notes for a clean rewrite

- **The two-index storage (primary + arg2-inverse) is over-engineered** for a store of this size. Total bookkeeping GAFs ≈ 4 × number of constants/assertions, which on a Cyc-Tiny KB is < 100k — cheap enough to keep in a single `(pred, arg1, arg2)` indexed table with both directions queryable via SQL-style indexes. Using two hand-maintained index structures duplicates write paths.
- **The `single-entry?` flag on insert** is a polymorphism between "single-valued cell" and "set-valued cell" — confusing. The clean rewrite has either single-valued or multi-valued semantics per index, not a runtime flag.
- **Most of the public API is missing-larkc.** `creator`, `creation-time`, `creation-date`, `unassert-bookkeeping-binary-gaf`, `assertion-bookkeeping-info`, etc. are obvious one-liner wrappers over `bookkeeping-fpred-value` / the `int` operators; they were stripped because LarKC didn't expose them. The clean rewrite resurrects them.
- **The four bookkeeping predicates are hardcoded** in `*bookkeeping-predicates-for-hl-store*`. Adding a new bookkeeping predicate requires editing this list, recreating the indexes, registering a new HL storage module. A clean rewrite parameterizes this — adding a predicate is a single declarative call.
- **The conflict check in `assert-bookkeeping-binary-gaf`** silently returns nil when arg2 differs from existing — no error is signaled. This is correct for `myCreationTime` (you can't change when something was created) but possibly wrong for `myCreator` (a re-assignment might be valid). A clean rewrite either (a) errors on conflict, (b) takes a `:overwrite?` flag, or (c) makes the conflict check per-predicate configurable.
- **Bookkeeping predicates are only valid in `#$BookkeepingMt`** — hard-coded check. A clean rewrite treats this as a property of the predicate (`required-mt :BookkeepingMt`) rather than an inline check.
- **`fi-timestamp-constant-int` and `fi-timestamp-assertion-int` live in `fi.lisp`** but the `perform-*-bookkeeping` callers are in `cyc-bookkeeping.lisp`. The split is historical — fi.lisp owned the timestamp-emission code while cyc-bookkeeping.lisp owned the context. A clean rewrite folds them together; there's no reason for the indirection.
- **The dynamic context plist lives in `*cyc-bookkeeping-info*`** but the timestamp emission code reads `*the-cyclist*` / `*the-date*` / `*ke-purpose*` / `*the-second*` for the *fallback* path (`possibly-with-bookkeeping-info`). Two different conventions for "the current bookkeeping fields." A clean design has one — the explicit plist.
- **`with-assertion-bookkeeping-info` extracts from an existing assertion** to "make a new operation look like it was done by the same person." This is sometimes correct (continuing a session) and sometimes wrong (one cyclist editing what another asserted). A clean rewrite makes the intent explicit: `:inherit-creator-from existing-assertion` or `:inherit-purpose-from existing-assertion` etc.
- **The bookkeeping store is conceptually orthogonal to the rest of the KB** — bookkeeping facts have no inferential consequence, only metadata. A modern design might store this in a key-value store with no participation in the regular indexing or canonicalization paths at all.
- **`bookkeeping-assertion-count` is cheap** because it walks the alist+hash sizes. But there's no way to ask "how many bookkeeping facts are about constants vs NARTs" without scanning. A clean rewrite adds counting/filtering primitives.
- **The four bookkeeping HL modules are nearly identical** — same `:add` and `:remove` handlers, only differing in `:applicability` and `:predicate`. Collapse into one module with a `:any-predicates` list of the four bookkeeping predicates.
