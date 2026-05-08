# Skolems

Skolem functions are the **canonicalizer's reification mechanism for existential quantifiers**. When the canonicalizer encounters a sentence like `(forall ?x (exists ?y (P ?x ?y)))`, it eliminates the existential by inventing a fresh function `Sk-N` such that the equivalent skolemized form is `(forall ?x (P ?x (Sk-N ?x)))`. The existential is replaced by a *concrete-but-arbitrary* term; reasoning about `?y` becomes reasoning about `(Sk-N ?x)`.

Cyc's KB contains tens of thousands of these skolem functions, each with:
- A name like `#$SKF-12370394` (or `#$SKF-` followed by a digit-string).
- An arity (matching the universally-quantified vars it depends on).
- A *definition* — the rule from which it was generated, recording which existential it came from and which variables it depends on.
- Bookkeeping assertions (creator, time) like any other constant.

The skolem **defn table** is the per-skolem record of definition assertions. It must persist across image saves so a skolem name in a saved KB still maps to its semantic definition when the KB is reloaded.

This file is **almost entirely missing-larkc** in the LarKC distribution: 768 lines, of which only the variable declarations, two large skolem-name lists (`*skolems-with-known-issues*` and `*skolems-safe-to-recanonicalize-at-el*` — the project-specific lists tracking ~150 known-problematic skolems and ~400 safe-to-recanonicalize ones), and the `(toplevel)` setup are intact. The clean rewrite must reconstruct the entire skolem-defn machinery, which is described here from the function signatures.

## When does skolemization run?

Five triggering situations:

1. **The canonicalizer encounters an existentially-quantified subformula** during assertion. `canonicalize-fns-in-sk-term` is called from the canonicalizer's existential-elimination phase. It either reuses an existing skolem (if the same shape has been seen before) or invents a new one via `create-skolem`.
2. **A new skolem is invented.** `create-skolem var arg-types fmla mt key` allocates a fresh `#$SKF-NNNNNNNN`-style constant, creates the defining assertions (`(skolemFunctionDefn …)`), and registers in the skolem-defn table.
3. **A `skolem-defn` assertion is added or removed.** `pgia-after-adding-pgia` and equivalents trigger; the skolem table is updated to reflect the new definition.
4. **The KB is loaded.** The skolem axiom table from `misc.cfasl` is read, populating `*skolem-defn-table*` with the saved skolem-name → defn mapping. Per [kb-structure.md](../../../.claude/kb-structure.md), this table is **not reconstructable from the assertions alone** — skolem names are arbitrary identifiers chosen at canonicalization time.
5. **A skolem is referenced.** `skolem-defn skolem`, `skolem-args skolem n mt`, `skolem-defn-mt skolem` look up the per-skolem record.

## Concept: skolem-defn structure

A skolem-defn records (rough shape, reconstructed from accessor names):

| Field | Meaning |
|---|---|
| `var` (`skolem-defn-var`) | the existential variable being skolemized |
| `mt` (`skolem-defn-mt`) | the MT where the skolem was created |
| `cnfs` (`cnfs-of-skolem-defn`, `skolem-defn-cnfs`) | the CNF form(s) of the originating rule |
| `args` (`skolem-defn-args`) | the universal vars the skolem depends on |
| `seqvar` (`skolem-defn-seqvar`) | sequence-variable, if any |
| `number` (`skolem-defn-number`) | the integer ID |
| `key` (`skolem-defn-key`) | hash key for table lookup |

The `make-sk-defn` constructor takes these and produces the per-skolem record stored in the defn-table.

`unreified-sk-term` is the EL-form of the skolem term — `(Sk-N arg1 arg2 …)` as a list, before reification into a NART.

`opaquify-unreified-skolem-terms` walks an EL formula and converts skolem-NAUTs to opaque terms (used during query construction to suppress skolem-rewriting).

## Variables

```
*skolem-arg-sort*                       nil   variable mapping for current skolem defn
*formula-constant-str-caching-state*    nil   cache state for formula-constant-str
*recompute-skolem-defn-info*            nil   bound during defn recomputation
*skolems-with-known-issues*             list  ~150 SKFs with known canonicalization bugs
*skolems-safe-to-recanonicalize-at-el*  list  ~400 SKFs safe for EL-form re-canonicalization
*target-consequent-literal-count*       :uninitialized
```

The two large skolem-lists are project-specific data, baked into the source. They identify:

- **`*skolems-with-known-issues*`** — skolems that should be skipped during diagnostic-cleanup passes because their issues are known and can't be auto-fixed.
- **`*skolems-safe-to-recanonicalize-at-el*`** — skolems whose definitions can be re-derived from EL form without losing information.

These lists are KB-distribution-specific (a different Cyc KB would have a different list). The clean rewrite either externalizes them to a config file, derives them from KB content, or accepts them as provided.

## Public surface

(Almost all of these are missing-larkc bodies; signatures preserved for reference.)

```
;; Skolem creation and lifecycle
(create-skolem var arg-types fmla mt key)              ; missing-larkc body
(canonicalize-fns-in-sk-term term)                     ; missing-larkc body
(canonicalize-skolem-term term mt vars var-map)        ; missing-larkc body
(reify-skolems-in formula mt vars var-map)             ; missing-larkc body
(replace-unreified-skolem-terms-with-variables formula); missing-larkc body
(make-sk-defn var arg-types fmla mt)                   ; missing-larkc body
(make-unreified-sk-nat var fn arg-types args)          ; missing-larkc body

;; Defn lookup
(lookup-sk-constant-from-defns var mt key)             ; missing-larkc body
(defn-unreified-sk-term var mt key)                    ; missing-larkc body
(skolem-defn skolem)                                   ; missing-larkc body
(skolem-defn&key skolem)                               ; missing-larkc body
(skolem-defn-key skolem)                               ; missing-larkc body
(skolem-of-defn defn)                                  ; missing-larkc body (active)
(unreified-sk-term skolem)                             ; missing-larkc body (active)
(skolem-defn-mt defn)                                  ; missing-larkc body
(skolem-seqvar skolem)                                 ; missing-larkc body (active)
(skolem-defn-seqvar defn)                              ; missing-larkc body (active)
(skolem-number skolem)                                 ; missing-larkc body (active)
(skolem-defn-number defn)                              ; missing-larkc body
(skolem-defn-args defn)                                ; missing-larkc body
(skolem-var skolem)                                    ; missing-larkc body (active)
(skolem-args skolem n mt)                              ; missing-larkc body
(skolem-collection skolem)                             ; missing-larkc body
(sk-arity skolem &optional mt)                         ; missing-larkc body
(skolem-function-var skolem)                           ; missing-larkc body (active)
(skolem-function-dependent-vars skolem)                ; missing-larkc body (active)

;; Skolem table lookup keys
(skolem-table-key-from-defn defn)                      ; missing-larkc body (active)
(skolem-table-key-from-constant constant)              ; missing-larkc body (active)
(skolem-hash-key key1 key2)                            ; missing-larkc body (active)
(skolem-defns-from-key-specification spec mt)          ; missing-larkc body (active)

;; Defn assertion lookup
(skolem-defn-assertions skolem &optional mt)           ; missing-larkc body
(skolems-defn-assertions skolems)                      ; missing-larkc body (active)
(skolem-defining-bookkeeping-assertion skolem)         ; missing-larkc body
(skolem-defn-assertion? assertion skolem &optional mt) ; missing-larkc body
(gaf-has-corresponding-cnf-in-skolem-defn? gaf skolem &optional mt) ; missing-larkc body
(constant-denoting-reified-skolem-fn? constant)        ; missing-larkc body
(computed-skolem-assertion? assertion)                 ; missing-larkc body
(skolem-defining-assertion? assertion)                 ; missing-larkc body
(defn-assertion-of-skolem? assertion skolem)           ; missing-larkc body
(assertion-skolems assertion)                          ; missing-larkc body
(defn-assertion-skolems assertion)                     ; missing-larkc body
(all-skolem-mt-defn-assertions skolem mt &optional tv) ; missing-larkc body
(skolem-function-has-no-defn-assertions-robust? skolem); missing-larkc body (active)
(skolem-function-has-no-defn-assertions? skolem)       ; missing-larkc body (active)

;; Defn siblings
(skolem-defn-siblings defn)                            ; missing-larkc body (active)
(skolem-defn-proper-siblings defn)                     ; missing-larkc body
(skolem-canonical-sibling skolem)                      ; missing-larkc body

;; MT-related
(skolems-min-mt skolem)                                ; missing-larkc body (active)
(skolem-only-mentioned-in-el-templates? skolem mt)     ; missing-larkc body (active)

;; Recomputation
(recompute-skolem-defn skolem var mt cnfs vars args)   ; missing-larkc body
(recompute-functor-pgia fn)                            ; missing-larkc body
(recompute-nat-pgia nat)                               ; missing-larkc body
(recomputing-skolem-defn?)                             ; missing-larkc body
(recomputing-defn-of-skolem? skolem)                   ; missing-larkc body
(recomputing-skolem-defn-of? skolem)                   ; missing-larkc body
(recomputing-skolem-defn-info-constant)                ; missing-larkc body
(recomputing-skolem-defn-info-var)                     ; missing-larkc body
(really-recomputing-skolem-defn?)                      ; missing-larkc body
(recomputing-skolem-defn-info-defn)                    ; missing-larkc body
(recomputing-skolem-defn-info-key)                     ; missing-larkc body
(recomputing-skolem-defn-info-blist)                   ; missing-larkc body
(set-recomputing-skolem-defn-result old new)           ; missing-larkc body
(set-recomputing-skolem-defn-blist blist)              ; missing-larkc body
(note-skolem-binding key skolem)                       ; missing-larkc body

;; Modify operations
(remove-defn-of-skolem skolem &optional mt)            ; missing-larkc body
(add-skolem-defn defn &optional mt)                    ; missing-larkc body
(reset-skolem-defn-table &optional skolem mt)          ; missing-larkc body
(reset-defn-of-skolem skolem &optional mt)             ; missing-larkc body
(skolem-defn-from-assertions skolem &optional mt)      ; missing-larkc body
(reset-skolem-defn-from-assertions skolem &optional mt mt2) ; missing-larkc body

;; Diagnostics
(skolem-table-contains-old-format-skolems?)            ; missing-larkc body (active)
(kb-skolems)                                           ; missing-larkc body
(modernize-skolem-axiom-table)                         ; missing-larkc body
(possibly-modernize-unreified-sk-term term)            ; missing-larkc body
(skolems-with-mismatched-unreified-sk-terms)           ; missing-larkc body (active)
(skolem-unreified-sk-terms-match? skolem)              ; missing-larkc body (active)
(possibly-nrepair-skolems-with-duplicate-vars vars)    ; missing-larkc body
(possibly-nrepair-skolem-with-duplicate-vars skolem)   ; missing-larkc body
(nrepair-skolem-with-duplicate-vars skolem)            ; missing-larkc body
(possibly-nrepair-skolems-with-malformed-numbers ns)   ; missing-larkc body
(possibly-nrepair-skolem-with-malformed-numbers s)     ; missing-larkc body
(nrepair-skolem-with-malformed-numbers s)              ; missing-larkc body
(tmi-skolem? skolem)                                   ; missing-larkc body (active)
(recanonicalize-tmi-skolems skolem)                    ; missing-larkc body
(recanonicalize-tmi-skolem skolem)                     ; missing-larkc body
(diagnose-all-skolems)                                 ; missing-larkc body
(diagnose-skolems skolems &optional verbose?)          ; missing-larkc body
(diagnose-skolem skolem)                               ; missing-larkc body
(diagnose-just-this-skolem-internal skolem)            ; missing-larkc body
(diagnose-just-this-skolem skolem)                     ; (memoized; missing-larkc body)
(recanonicalize-skolem-defn-assertions skolem)         ; missing-larkc body
(skolem-safe-to-recanonicalize-at-el? skolem)          ; missing-larkc body (active)

;; WFF / arg-type-types
(skolem-wff? skolem)                                   ; missing-larkc body (active)
(skolem-not-wff? skolem)                               ; missing-larkc body (active)
(why-skolem-not-wff skolem)                            ; missing-larkc body (active)
(skolem-defn-wff? defn)                                ; missing-larkc body (active)
(skolem-defn-not-wff? defn)                            ; missing-larkc body
(why-skolem-defn-not-wff defn)                         ; missing-larkc body (active)
(skolem-all-good? skolem)                              ; missing-larkc body
(skolem-function-skolem-assertion-good? skolem)        ; missing-larkc body (active)
(skolem-functions-with-bad-skolem-assertions)          ; missing-larkc body (active)
(skolem-result-types-from-cnfs cnfs vars &optional mt args) ; missing-larkc body (active)
(skolem-var-isa-constraints-wrt-cnfs cnfs vars &optional mt) ; missing-larkc body (active)
(skolem-var-genl-constraints-wrt-cnfs cnfs vars &optional mt) ; missing-larkc body (active)
(skolem-arg-isa-constraints skolem args &optional mt)  ; missing-larkc body
(install-skolem-arg-types &optional skolem args)       ; missing-larkc body
(skolems-of-arity &optional arity)                     ; missing-larkc body (active)
(skolem-hosed? skolem)                                 ; missing-larkc body (active)
(skolem-ill-formed? skolem)                            ; missing-larkc body (active)
(skolem-rule-hosed? skolem rule)                       ; missing-larkc body (active)
(all-hosed-skolems)                                    ; missing-larkc body
(multi-skolem-skolems)                                 ; missing-larkc body
(misindexed-skolem-keys &optional verbose?)            ; missing-larkc body
(sk-defns-w/o-sk-constants &optional verbose?)         ; missing-larkc body
(sk-keys-w/o-sk-defns &optional verbose?)              ; missing-larkc body
(sk-defns-w/o-mts &optional verbose?)                  ; missing-larkc body
(install-skolemfunction-fn-in-skolem-defns &optional ...) ; missing-larkc body

;; Helpers
(formula-constant-str term)                            ; missing-larkc body (globally cached)
(formula-constant-str-internal term)                   ; missing-larkc body
(clear-formula-constant-str)                           ; missing-larkc body
(remove-formula-constant-str term)                     ; missing-larkc body
(cyc-var-except-for-x-0? var)                          ; missing-larkc body
(old-format-skolem? skolem)                            ; missing-larkc body
(el-unreified-sk-term skolem)                          ; missing-larkc body
(compute-unreified-sk-term-via-hl skolem)              ; missing-larkc body
(compute-skolem-info-from-assertions skolem args)      ; missing-larkc body
(skolem-variable-from-assertions assertions args)      ; missing-larkc body (active)
(skolem-scalar-term? term &optional mt)                ; missing-larkc body (active)
(subst-skolem-in formula skolem replacement)           ; missing-larkc body (active)
(alpha-sort-clauses clauses)                           ; missing-larkc body
(rename-skolem-clause-vars clauses vars &optional alist) ; missing-larkc body
(sk-defn-var)                                          ; missing-larkc body
(sk-defn-from-clauses clauses vars &optional sense)    ; missing-larkc body
(cnf-fn-argn-isa cnf fn n &optional mt)                ; missing-larkc body
(cnf-fn-argn-var cnf fn n)                             ; missing-larkc body
(interpolate-arg-type type &optional mt)               ; missing-larkc body
(max-skolem-arity)                                     ; missing-larkc body
(compute-target-consequent-literal-count cnf)          ; missing-larkc body
(conjunction-of-literals? clause)                      ; missing-larkc body
(possibly-rehabilitate-skolem-defn-table)              ; missing-larkc body
```

## Consumers

| Consumer | What it would use (when reconstructed) |
|---|---|
| **Canonicalizer** (`czer-main.lisp`, `canon-tl.lisp`) | `canonicalize-fns-in-sk-term`, `canonicalize-skolem-term`, `make-sk-defn`, `make-unreified-sk-nat` to replace existentials with skolems |
| **FI / KE assert path** | `perform-assert-post-processing` (in [fi.md](../kb-access/fi.md)) finds skolem NARTs in new assertions and calls into the skolem defn-table to set up `(isa Sk-N SkolemFunction)`, `(arity Sk-N M)`, etc. |
| **Inference engine** | Reads `skolem-args`, `skolem-defn-mt`, `unreified-sk-term` for query expansion; respects `*forward-skolemization*` toggle |
| **CFASL dump/load** | `misc.cfasl` contains the skolem axiom table; load reconstructs `*skolem-defn-table*` |
| **Diagnostic tools** | `diagnose-all-skolems`, `kb-skolems`, `all-hosed-skolems`, `misindexed-skolem-keys`, `sk-defns-w/o-sk-constants`, `sk-keys-w/o-sk-defns` for KB consistency reports |
| **WFF** (`wff.lisp`) | `skolem-wff?`, `skolem-not-wff?` validate skolem terms during type-checking |
| **Cyc API** | The skolem table is reflected via certain accessors (`creator`-style; mostly missing) |
| **HL inference modules** | The skolem result-types from `skolem-result-types-from-cnfs` are used by inference to type-resolve skolem outputs |

## Notes for a clean rewrite

- **Skolemization is fundamentally a canonicalizer concern**, not a graph-reasoning concern, but the file is grouped here because skolems participate in the genls/isa lattice as collections (`skolem-collection`, `skolem-result-types-from-cnfs`) and feed into SBHL for type-checking.
- **The file is overwhelmingly missing-larkc.** Only the variable declarations, two SKF-name lists, and the toplevel-setup are intact. The clean rewrite must implement the entire skolem-defn machinery from the function signatures and from the canonicalizer's contract.
- **The skolem-defn table must persist across image saves.** Per [kb-structure.md](../../../.claude/kb-structure.md) "Reconstructability summary," `misc.cfasl` is one of the four authoritative content blobs that must be dumped — the skolem table is **not** reconstructable from assertions alone. The clean rewrite preserves this property.
- **`*skolems-with-known-issues*` and `*skolems-safe-to-recanonicalize-at-el*` are KB-distribution-specific.** A clean rewrite either:
  - Externalizes these to a config file alongside the KB.
  - Stores them as KB facts (e.g. `(skolemHasKnownIssues SKF-N)`).
  - Computes them dynamically at startup by running diagnostic checks.
  The current hard-coded approach is fragile — adding a new known-issue skolem requires a code change.
- **The skolem name format `#$SKF-NNNNNNNN`** is conventional but not enforced. The clean rewrite either commits to this format and validates, or generalizes to any constant tagged `(isa <c> #$SkolemFunction)`.
- **The "defn-key" / "hash-key" mechanism** lets multiple skolems share a key prefix when they were generated from the same originating rule. The clean rewrite must implement `skolem-table-key-from-defn` / `skolem-table-key-from-constant` consistently — keys must canonicalize to the same value for identical defns.
- **The `recomputing-*` family** is a re-entrancy-detection mechanism for defn recomputation. When a skolem defn references another skolem, the recomputation may recurse; the dynamic guards detect cycles. Preserve.
- **The `tmi-skolem?` predicate** ("too much information") and `recanonicalize-tmi-skolems` handle skolems whose definitions accumulated too many cnfs over time and need to be simplified. A maintenance operation, not a normal-path concern.
- **`possibly-nrepair-*` family** are KB-cleanup operations — repair skolems with duplicate vars or malformed numbers. The clean rewrite preserves the *interface* (so old broken KBs can be loaded) but new KBs shouldn't generate broken skolems.
- **`skolem-only-mentioned-in-el-templates?`** distinguishes skolems that appear only in EL-form rule templates (cosmetic / paraphrase concerns) from skolems used in real reasoning. Used to prune unused skolems during cleanup.
- **`skolem-result-types-from-cnfs` and `skolem-var-isa/genl-constraints-wrt-cnfs`** compute the type system constraints for a skolem from its definition CNFs. These feed into the WFF / arg-type system. Critical for type-checking; the clean rewrite must reconstruct from the CNF traversal patterns.
- **`note-globally-cached-function 'formula-constant-str`** marks `formula-constant-str` as a globally-cached helper. The clean rewrite implements with explicit memoization, ideally typed so the cache contains formula → string only.
- **The entire `skolems.lisp` file is a candidate for full rewrite** rather than incremental reconstruction — the missing-larkc gaps are too large for partial fixes, and the design is canonicalization-coupled. The clean rewrite likely places this in the canonicalizer module rather than as a standalone file.
- **Bookkeeping integration**: `skolem-defining-bookkeeping-assertion` retrieves the assertion (creator/timestamp) for the skolem-defining act. Skolems are bookkeeping-tracked like any constant.
- **`max-skolem-arity` is a KB-level diagnostic** — the maximum arity of any skolem in the KB. Used to size things; not normally consulted in hot paths.
- **`opaquify-unreified-skolem-terms`** is consulted by query construction — when running a query about a NART that happens to be a skolem instance, opaquification prevents the inference engine from rewriting through the skolem and losing the originating identity.
