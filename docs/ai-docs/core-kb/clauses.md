# Clauses, CNF, DNF, and clause-strucs

A **clause** is the HL-canonical form of a single disjunction of literals (CNF) or conjunction of literals (DNF). Clauses are the lowest level at which Cyc reasons — every assertion's formula, every query, every inference goal is a clause or a list of clauses. They sit between the EL (Epistemological Level — human-readable s-expressions with `#$implies`, `#$forAll`, etc.) and the per-rule indexing/match infrastructure.

A **clause-struc** is a per-image reified shared clause: when many assertions across many MTs carry *the same* CNF (the rule asserted in different microtheories, the same fact in equivalent contexts), the CNF is interned into a single `clause-struc` and each assertion points at it. Clause-strucs are KB-resident, ID-keyed, and CFASL-serialized like assertions and NARTs — but unlike them, they exist purely as an optimization, not as a logical object Cyc reasons about.

The **clausifier** is the EL→HL pipeline. Given an EL sentence and an MT, it standardizes variables, eliminates `#$implies` / `#$equiv` / `#$forAll` / `#$thereExists`, distributes negations, skolemizes existentials, lifts universals, and finally distributes conjunctions/disjunctions to produce a list of clauses in conjunctive normal form (or disjunctive normal form for queries that need it).

## Terminology

- **Literal** (`lit`): a single atomic sentence, possibly negated. Literals come in two senses.
- **`asent`** (atomic sentence): a literal stripped of its negation marker — `(pred arg1 ... argN)` only. The "atomic sentence" is the literal's content; the literal carries the additional negation bit.
- **Sense**: `:pos` or `:neg`. Every literal in a clause is filed under one of these.
- **Clause**: a 2-element list `(neg-lits pos-lits)`. The car is the list of negative literals (their atomic sentences), the cadr is the list of positive literals.
- **CNF** (conjunctive normal form): a clause interpreted as a *disjunction* of its literals — `(neg-lits = ¬n₁ ∨ ¬n₂ ∨ …)` and `(pos-lits = p₁ ∨ p₂ ∨ …)` together form `¬n₁ ∨ ¬n₂ ∨ … ∨ p₁ ∨ p₂ ∨ …`. Multiple CNF clauses joined by AND form a CNF formula. **A "CNF" in Cyc usually refers to a single CNF clause**, not a multi-clause CNF — the multi-clause form is a `cnf-clauses` (a list).
- **DNF** (disjunctive normal form): the same 2-tuple structure, interpreted as a *conjunction* of its literals. Used by the inference engine on the query side (a query is a DNF — a conjunction of literals to match — so the answer worker can iterate them as goals).
- **GAF CNF**: a CNF with exactly one positive literal, no negative literals, fully ground. Represents an asserted fact like `(isa Fido Dog)`. Not stored as a CNF clause in practice — assertions store the GAF formula directly and synthesize the CNF on demand via `make-gaf-cnf`.
- **Clause-struc**: an opaque, ID-keyed, KB-resident handle that wraps a CNF and carries a back-pointer list to every assertion sharing it.
- **Subclause-spec**: a 2-list `(neg-indices pos-indices)` selecting a subset of a clause's literals by position. Used by inference workers to refer to "literals 0 and 2 of the negative side, plus literal 1 of the positive side" without copying the literals themselves.

## When does a clause get created?

Cheap, transient, value-typed — created freely. The trigger situations:

1. **Canonicalization of an EL sentence**. The clausifier (`el-cnf` / `el-dnf` / `cnf-clausal-form` in `clausifier.lisp`) consumes an EL sentence and produces clauses. Every assert and every query goes through this. The pipeline is `el-cnf` → `el-cnf-int` → `el-xnf` (push to xnf — operators stripped to `#$and`/`#$or`/`#$not`) → `disjunctions-in` → `cnf-operators-out`. The output is wrapped via `package-xnf-clause` / `npackage-xnf-clause`, which split literals into neg-lits and pos-lits.
2. **Direct construction by inference workers**. `make-clause`, `make-cnf`, `make-dnf`, `make-gaf-cnf`, `make-xnf` are called all over the inference engine (`inference-worker-split.lisp`, `at-var-types.lisp`, `czer-main.lisp`, `backward.lisp`) when synthesizing intermediate goals. Cheap because clauses are just two-element lists.
3. **Lifting a stored GAF formula to a CNF**. When an assertion's formula slot holds a GAF formula (not a CNF) and a caller asks for the CNF view via `assertion-hl-cnf`, `gaf-formula-to-cnf` synthesizes the CNF on the fly via `make-gaf-cnf`.
4. **CFASL load**. When a clause-struc is being deserialized, its CNF field is read directly from the stream as a value-typed list (no `make-cnf` call — the bytes describe the structure).

A clause is an immutable list in normal use, but the `nmake-clause`, `nmake-dnf`, `set-clause-pos-lits` family are destructive variants used by hot paths inside the clausifier where freshly-allocated clauses are being rewritten in place.

## When does a clause-struc get created?

Three situations:

1. **Two assertions share a CNF**. When `kb-create-assertion` finds via `find-cnf-formula-data-hook` that another assertion in any MT already carries the same CNF, it triggers the clause-struc promotion path: build a new `clause-struc` for the shared CNF, point both the existing and the new assertion at it. The actual build (`missing-larkc 11343`) and the existing-assertion redirection (`missing-larkc 11315`/`11316`/`11317`) are LarKC-stripped — only the read-side (consume an existing clause-struc) is intact in this drop. See [the assertions doc](assertions.md#the-clause-struc-sharing-optimization) for the full path.

2. **CFASL load reads a clause-struc off the dump**. `load-clause-struc-defs` (in `dumper.lisp`) iterates the `clause-struc` CFASL file and for each dump-id calls `make-clause-struc-shell cnf dump-id` to allocate the handle, then `reset-clause-struc-assertions clause-struc (cfasl-input stream)` to populate the back-pointer list of assertions sharing this struc.

3. **Internal allocation during hl-storage operations**. Any time the formula-data slot of an assertion is rewritten and a clause-struc layer is being installed, `get-clause-struc` is called. Most of this path is missing-larkc (the build-from-scratch side); the read side is wired up.

**Backward queries do not create clause-strucs.** The query's intermediate clauses are created via `make-clause` and discarded when the query completes.

## Data structures

### Clause (CNF / DNF / XNF)

```lisp
;; A clause is a 2-element list:
(make-clause neg-lits pos-lits)  →  (list neg-lits pos-lits)

(defun clause-p (object)
  (and (listp object)
       (= 2 (length object))
       (listp (first object))
       (listp (second object))))
```

Just a list. There is no struct. The "type" is structural: a 2-element list of two lists. `cnf-p`, `dnf-p`, and `clause-p` are the same predicate — Cyc tells CNF and DNF apart by *context* (where the value came from), not by tag. `make-cnf`, `make-dnf`, `make-xnf` are all aliases for `make-clause`. `nmake-clause` is the destructive variant for in-place rewrites.

Accessors:

```
(neg-lits clause)       ; first
(pos-lits clause)       ; second
(clause-sense-lits c sense)
(unmake-clause c)       ; multiple-value (neg-lits, pos-lits)
```

Mutation (destructive variants for clausifier hot paths):

```
(set-clause-pos-lits clause new-pos-lits)   ; rplaca on (rest clause)
(nmake-clause neg-lits pos-lits clause)
(npackage-xnf-clause clause)
```

The `*empty-clause*` is `(make-clause nil nil)` — the "box" of resolution proofs, the marker for derivation of falsehood.

### Clause shape predicates

```
(ground-clause-p c)               ; clause and fully-bound-p
(atomic-clause-p c)                ; exactly one literal total
(pos-atomic-clause-p c)            ; (length neg-lits)=0, (length pos-lits)=1
(neg-atomic-clause-p c)            ; inverse
(pos-atomic-cnf-p cnf)             ; same as pos-atomic-clause-p, named for CNF context
(gaf-cnf? cnf)                     ; pos-atomic-cnf-p AND ground-clause-p
(clause-with-lit-counts-p c n p)   ; exact length match
(binary-clause-p c)                ; total 2 literals
(empty-clause? c)                  ; clause-equal *empty-clause*
(clause-equal c1 c2)               ; both clause-p AND equal
```

The "GAF CNF" form is the most-commonly checked: a CNF representing an asserted fact. The check is fast (`pos-atomic-cnf-p` is O(1) length, `ground-clause-p` is `fully-bound-p` traversal); `gaf-cnf?` is the one inference workers gate the GAF fast path on.

### Clause iteration helpers

```
(clause-literal-count c)           ; len(neg) + len(pos)
(clause-number-of-literals c)
(all-literals-as-asents c)         ; (append neg-lits pos-lits)
(atomic-cnf-asent c)               ; the single literal of a unary CNF
(atomic-clause-asent c)            ; same, for clause naming
(atomic-cnf-predicate c)           ; the predicate of a unary CNF
(gaf-cnf-literal cnf)              ; first pos-lit (assumes gaf-cnf?)
(clause-free-variables c &optional var? include-sequence-vars?)
```

`clause-free-variables` walks both literal lists and unions their free variables. The TOU-gaf special case rebinds `*within-tou-gaf?*` — the term-of-unit literal exposes some quoted variables that need different scoping.

### Clause→formula rendering

For display and EL-echo:

```
(cnf-formula cnf &optional truth)  ; → EL formula like (#$implies (#$and ¬n) (#$or p))
(dnf-formula dnf)                   ; → EL formula
(cnf-formula-from-clauses cnf-clauses)
(dnf-formula-from-clauses dnf-clauses)
```

`cnf-formula` reconstructs an EL sentence by:
- If both neg and pos lits exist → `(#$implies (#$and ¬n₁ ¬n₂ …) (#$or p₁ p₂ …))`
- If only neg lits → `(#$not <or-of-neg-lits>)`
- If only pos lits → either the single positive literal, or `(#$or p₁ p₂ …)`
- For a single-pos-lit ground CNF with `truth :false`, wraps in `#$not`

### Subclause-specs

A subclause-spec is a 2-list `(neg-indices pos-indices)` selecting positions:

```lisp
(defstruct (subclause-spec (:type list))
  negative-indices
  positive-indices)
```

Used by the inference engine to pass "which literals of this clause" without re-extracting the literals each time. The indices are sorted at construction (`canonicalize-literal-indices`).

```
(new-subclause-spec neg-indices pos-indices)
(new-single-literal-subclause-spec sense index)
(new-complement-subclause-spec spec sample-clause)
(subclause-spec-from-clauses big-clause little-clause)
(subclause-spec-literal-count spec)
(single-literal-subclause-spec? spec)
(index-and-sense-match-subclause-spec? index sense spec)
(subclause-specified-by-spec clause spec)
(complement-of-subclause-specified-by-spec clause spec)
(do-subclause-spec* (asent sense clause spec [invert?]) neg-form pos-form)
```

`do-subclause-spec*` is the workhorse iterator. It walks both literal lists with index, and for each match (or mismatch, with `invert?` true) executes the per-sense form.

### clause-struc

```lisp
(defstruct (clause-struc (:conc-name "CLS-"))
  id
  cnf
  assertions)
```

Three slots:

- `id`: integer handle in `*clause-struc-from-id*`.
- `cnf`: the shared CNF clause (a 2-element list).
- `assertions`: the list of every assertion sharing this clause-struc.

Only the read-side accessors are wired up:

```
(clause-struc-p obj)
(clause-struc-cnf cs)              ; → CNF
(clause-struc-id cs)               ; (cls-id cs)
(find-clause-struc-by-id id)
(reset-clause-struc-id cs new-id)
(reset-clause-struc-assertions cs new-list)
(make-clause-struc-shell cnf &optional id)
```

The free-list and resourcing infrastructure are in place but most build paths are missing-larkc:

```
*clause-struc-free-list*           ; resource pool
*clause-struc-free-lock*           ; bordeaux-threads lock
get-clause-struc                   ; pool/allocate
init-clause-struc                  ; reset slots
make-static-clause-struc           ; allocate in static area
```

`sxhash` for clause-struc is `missing-larkc 11340` — odd, since the obvious implementation is just the integer ID (compare to the deduction `sxhash` which falls back to 786 if id is nil).

## Identifier space

```
ID  → clause-struc          *clause-struc-from-id*       (id-index)
```

There is no LRU-fronted content manager — the clause-struc *is* the content. The CNF list is held in the slot directly. This is unlike assertions, deductions, NARTs, kb-hl-supports — clause-strucs are small enough that the swap-out optimization is unnecessary.

The transient dump-id table:

```lisp
*clause-struc-dump-id-table*               ; declared but use is missing-larkc
*cfasl-clause-struc-handle-lookup-func*    ; used in dumper.lisp during KB load
```

## CFASL serialization

See [cfasl.md](../persistence/cfasl.md). Opcode `*cfasl-opcode-clause-struc*` = 38. Like all the other KB-resident objects, clause-strucs serialize by handle only — recipe and immediate paths are missing-larkc.

| Direction | Code path |
|---|---|
| Output | `cfasl-output-object-clause-struc-method` (missing-larkc) |
| Input | `cfasl-input-clause-struc` → `cfasl-input-clause-struc-handle` → `cfasl-clause-struc-handle-lookup` |

Handle lookup dispatches through `*cfasl-clause-struc-handle-lookup-func*` (`nil` or `'find-clause-struc-by-id` for in-image; `'find-clause-struc-by-dump-id` during KB load).

The clause-struc CFASL stream carries: dump-id, the CNF (as a value-typed list with its own embedded CFASL — the literals serialize by their normal type opcodes), and the assertions list (each by handle). `load-clause-struc-def` reads these as `dump-id → make-clause-struc-shell cnf dump-id → reset-clause-struc-assertions cs (cfasl-input stream)`.

## KB load / dump lifecycle

1. **Setup** — `setup-clause-struc-table size exact?` allocates `*clause-struc-from-id*`.
2. **Load defs** — `load-clause-struc-defs` reads each clause-struc from the CFASL file and registers it.
3. **Finalize** — `finalize-clause-strucs clause-struc-count` either sets the next-id watermark directly or scans the index to determine it; if no max is provided, calls `optimize-id-index`.

`free-all-clause-strucs` is the global teardown but its body is missing-larkc — the per-struc free path is `missing-larkc 11347`.

## The clausifier pipeline

`clausifier.lisp` is a 1057-line file implementing the EL→HL transformation. The high-level entry points:

```
(el-cnf sentence mt)                ; Constructive: returns (cnf, mt) values
(el-cnf-destructive sentence mt)    ; Destructive variant for hot paths
(el-dnf sentence mt)                ; CNF's twin for queries
(el-dnf-destructive sentence mt)
(cnf-clausal-form sentence mt)      ; cached version (cache currently missing-larkc)
(el-xnf sentence mt)                ; common middle stage — operators reduced to and/or/not only
```

The pipeline (`el-xnf-int` → `el-cnf-int`):

1. **Pre-canonicalization** (`precanonicalizations` from `precanonicalizer.lisp`) — sentence-level preprocessing: argument reorderings, NAUT-substitutions, syntactic shortcuts.
2. **Simplify syntax** (`simplify-cycl-sentence-syntax`) — collapse trivial nestings.
3. **Eliminate implications** (`do-implications`) — `(#$implies a b)` becomes `(#$or (#$not a) b)`.
4. **Push negations inward** (`do-negations-destructive`) — `(#$not (#$and a b))` becomes `(#$or (#$not a) (#$not b))`, etc. After this step, `#$not` only encloses atomic sentences.
5. **Standardize variables** (`standardize-variables`) — every variable gets a unique name in this scope.
6. **Explicitify implicit quantifiers** (`czer-explicitify-implicit-quantifiers`) — bare free vars become explicit `#$forAll` or `#$thereExists` per `*assume-free-vars-are-existentially-bound?*`.
7. **Existentials out** (`existentials-out`) — Skolemization: `(#$thereExists ?X (P ?X ?Y))` becomes `(P (SkolemFn ?Y) ?Y)` with a fresh skolem function depending on the enclosing universal scope.
8. **Universals out** (`universals-out`) — universal quantifiers are stripped, leaving only their bound variables (which are now implicitly universally bound at the clause level).
9. **Post-canonicalization** (`postcanonicalizations`) — final rewrites.
10. **Distribute conjunctions/disjunctions** (`disjunctions-in` for CNF, `conjunctions-in` for DNF) — push the boolean operator outward to produce the normal form.
11. **Operators out** (`cnf-operators-out` / `dnf-operators-out`) — the remaining `#$and`/`#$or` are stripped; what remains is a list of clauses, each a list of literals.
12. **Package** (`package-xnf-clause`) — split each literal list into (neg-lits, pos-lits) using `el-negative-sentences` and `el-positive-sentences`.

`canon-fast-gaf?` is the bypass: if the input is a fully-ground predicate sentence with no embedded sentences, no variables, and survives precanonicalization unchanged, skip the whole pipeline and just call `simplify-cycl-literal-syntax`. Most KB content asserts are GAFs, so this fast path matters.

`*czer-bad-exponential-threshold*` (200000) is the disjunction-distribution explosion limit — `bad-exponential-disjunction?` and `bad-exponential-conjunction?` check whether the K^N expansion would exceed it and signal `:bad-exponential-disjunction` / `-conjunction` if so.

The clausifier maintains several dynamic-scope variables:

```
*clausifier-input-sentence*       ; for error reporting
*clausifier-input-mt*
*outermost-implication*           ; recursion-depth marker for do-implications
*innermost-implication*
*newly-introduced-universals*     ; stack used by czer-explicitify-implicit-quantifiers
*quantifier-info-list*            ; quantifier-scope accounting
*eliminate-existential-with-var-only-in-antecedent?*
*use-cnf-cache?*                  ; cache toggle
```

## Public API surface

### Clause construction and destructure

```
(make-clause neg-lits pos-lits)                  ; Cyc API
(make-cnf neg-lits pos-lits)
(make-dnf neg-lits pos-lits)
(make-xnf neg-lits pos-lits)
(make-gaf-cnf asent)                             ; (make-cnf nil (list asent))
(empty-clause)                                    ; Cyc API
(nmake-clause neg-lits pos-lits clause)
(nmake-dnf neg-lits pos-lits dnf)
(set-clause-pos-lits clause new-pos-lits)
(npackage-xnf-clause clause)
(unmake-clause clause)                            ; (values neg-lits pos-lits)
(destructure-clause (neg-lits pos-lits) clause body...)  ; macro
```

### Predicates

```
(clause-p obj)                                    ; Cyc API
(cnf-p obj)                                       ; Cyc API — alias
(dnf-p obj)
(ground-clause-p obj)                             ; Cyc API
(atomic-clause-p obj)                             ; Cyc API
(pos-atomic-cnf-p cnf)
(pos-atomic-clause-p clause)
(neg-atomic-clause-p clause)
(gaf-cnf? cnf)                                    ; Cyc API
(empty-clause? clause)                            ; Cyc API
(clause-equal c1 c2)                              ; Cyc API
(clause-with-lit-counts-p c n p)
(binary-clause-p c)
(atomic-clauses-p obj)
(pos-atomic-clauses-p obj)
(atomic-clause-with-all-var-args? c)
(dnf-clauses-p obj)
(hl-predicate-p obj)
```

### Accessors

```
(neg-lits clause)                                 ; Cyc API
(pos-lits clause)                                 ; Cyc API
(clause-sense-lits clause sense)
(clause-literal-count clause)
(clause-number-of-literals clause)
(all-literals-as-asents clause)
(atomic-cnf-asent clause)
(atomic-clause-asent clause)
(atomic-cnf-predicate clause)
(gaf-cnf-literal cnf)                             ; first pos-lit
(clause-free-variables clause &optional var? include-sequence-vars?)
(clause-literal clause sense num)                 ; Cyc API
(clause-without-literal clause sense num)         ; Cyc API
```

### Rendering (clause → EL formula)

```
(cnf-formula cnf &optional truth)                 ; Cyc API
(dnf-formula dnf)                                  ; Cyc API
(cnf-formula-from-clauses cnf-clauses)            ; Cyc API
(dnf-formula-from-clauses dnf-clauses)            ; Cyc API
```

### Clausifier entry points

```
(el-cnf sentence mt)
(el-cnf-destructive sentence mt)
(el-dnf sentence mt)
(el-dnf-destructive sentence mt)
(el-xnf sentence mt)
(cnf-clausal-form sentence mt)
(canon-fast-gaf? sentence mt)
(force-into-cnf sentence)
(force-into-dnf sentence)
(clausifier-input-sentence)
(clausifier-input-mt)
(clear-cached-cnf-clausal-form)
```

### clause-struc API

```
(clause-struc-p obj)
(clause-struc-cnf cs)
(clause-struc-id cs)
(find-clause-struc-by-id id)
(make-clause-struc-shell cnf &optional id)
(reset-clause-struc-id cs new-id)
(reset-clause-struc-assertions cs new-assertions)
(setup-clause-struc-table size exact?)
(finalize-clause-strucs &optional max-id)
(create-sample-invalid-clause-struc)
```

### Subclause-spec API

```
(new-subclause-spec neg-indices pos-indices)
(new-single-literal-subclause-spec sense index)
(new-complement-subclause-spec spec sample-clause)
(subclause-spec-from-clauses big little)
(subclause-spec-literal-count spec)
(single-literal-subclause-spec? spec)
(subclause-spec-negative-indices spec)
(subclause-spec-positive-indices spec)
(index-and-sense-match-subclause-spec? index sense spec)
(subclause-specified-by-spec clause spec)
(complement-of-subclause-specified-by-spec clause spec)
(do-subclause-spec* (asent sense clause spec [invert?]) neg-form pos-form)  ; macro
```

## Consumers

| Consumer | What it uses |
|---|---|
| **assertions** (`assertions-low.lisp`, `assertions-high.lisp`) | Every assertion's formula is a CNF, GAF formula, or clause-struc. `assertion-cnf` synthesizes a CNF when needed; `assertion-hl-cnf` walks through clause-struc indirection. `connect-assertion-formula-data` dispatches on `clause-struc-p` for the sharing path. |
| **kb-create-assertion** | `find-cnf-formula-data-hook` checks for existing clause-strucs to share; `cnf-to-gaf-formula` shrinks a GAF-shaped CNF to a bare formula. |
| **canonicalization** (`czer-main.lisp`, `czer-utilities.lisp`) | The clausifier is the front end; `make-cnf`, `make-clause`, `unmake-clause` are used throughout to rebuild clauses after term substitutions. |
| **inference workers** (`inference/harness/inference-worker-*.lisp`) | `neg-lits`/`pos-lits` walked exhaustively. `inference-worker-split.lisp` constructs new clauses from per-literal proofs; `inference-worker-removal.lisp` dispatches on per-literal predicates. The DNF form is the canonical query shape for the worker pipeline. |
| **at-var-types.lisp** (argument-type checker) | `cnf-clausal-form` to canonicalize the type-rule sentence; `make-cnf` to assemble per-arg-position clauses. |
| **backward.lisp** (backward inference) | `make-clause`, `make-gaf-cnf`, walks `neg-lits`/`pos-lits` of intermediate dnf clauses. |
| **wff** (`wff.lisp`, `wff-utilities.lisp`) | Validates clause shape after canonicalization. |
| **CFASL** (`cfasl-kb-methods.lisp`) | `cfasl-input-clause-struc`, `cfasl-clause-struc-handle-lookup`. |
| **dumper** (`dumper.lisp`) | `make-clause-struc-shell`, `reset-clause-struc-assertions`, `load-clause-struc-defs`, `finalize-clause-strucs`. |

## Files

| File | Role |
|---|---|
| `clauses.lisp` | The 2-element-list structural definition: `make-clause`, `clause-p`, `neg-lits`, `pos-lits`, `clause-equal`, `cnf-formula`, `dnf-formula`, `gaf-cnf?`, `pos-atomic-cnf-p`, etc. The "what is a clause" file. |
| `clause-utilities.lisp` | Higher-level helpers built on top: `make-gaf-cnf`, `clause-literal-count`, `all-literals-as-asents`, `clause-free-variables`, the entire subclause-spec API. Also the `destructure-clause` and `do-subclause-spec*` macros. |
| `clause-strucs.lisp` | The reified shared-CNF object — defstruct, id-index registration, `make-clause-struc-shell`, lifecycle (`setup-clause-struc-table`, `finalize-clause-strucs`, `clear-clause-struc-table`, `free-all-clause-strucs`). |
| `clausifier.lisp` | The EL→HL pipeline. ~1000 lines covering implication-elimination, negation pushing, variable standardization, skolemization, and CNF/DNF distribution. Most of the structural transformations are intact; the caching layer is missing-larkc. |

## Notes for a clean rewrite

- **Tag CNF and DNF distinctly.** They share representation (`(neg-lits pos-lits)` as a 2-list) but have inverted boolean semantics. Confusing one for the other is undetectable at the type level. A clean design uses two different struct types with the same fields.
- **Drop the `make-cnf` / `make-dnf` / `make-xnf` triplet.** They're all aliases for `make-clause`. Either rename to express the intent (`make-disjunction-clause`, `make-conjunction-clause`) or pick one and remove the others.
- **Subclause-spec should be a struct, not a 2-list.** It's already declared `(:type list)` for compatibility with the Java compilation; the clean version makes it a proper struct or a fixed-size record.
- **Clause-struc deserves a real `sxhash`.** The current `missing-larkc 11340` is bizarre — the obvious implementation is the integer ID. Use it.
- **The clause-struc `assertions` slot maintains a list, not a set.** Adding/removing an assertion is O(N). For shared rules across many MTs (the use case clause-strucs exist for), a set or hash would be more appropriate.
- **The free-list resource pool (`*clause-struc-free-list*`) is configured but never populated** in the LarKC drop. Either remove it or wire up the recycling. As-is it's dead weight.
- **The clausifier pipeline is a series of side-effecting passes over the sentence with destructive mutation.** Each step takes the sentence, mutates it, and passes it to the next. A clean rewrite using immutable transforms would be easier to reason about and test in isolation. Preserving the destructive variant for hot-path use (`el-cnf-destructive`) would mean two parallel pipelines, but the constructive variant is the one that matters semantically.
- **`*use-cnf-cache?*` is true but the cache implementation is missing-larkc.** `cnf-clausal-form` calls `missing-larkc 30284` (likely `cached-cnf-clausal-form`); `note-globally-cached-function` is registered but with no cache backing. The clean rewrite needs to wire this up — every assertion goes through the clausifier, and re-canonicalizing the same EL sentence is the worst-case overhead.
- **`canon-fast-gaf?` is the most-trodden path.** Most asserts are GAFs. Make sure the clean rewrite preserves the bypass (or improves on it — recognizing GAFs at parse time, not after a precanon pass).
- **`bad-exponential-disjunction` / `-conjunction` signaled as catch tags.** A clean rewrite uses conditions, not catch — easier to wrap, easier to instrument.
- **The dynamic-scope variables (`*outermost-implication*`, `*innermost-implication*`, `*newly-introduced-universals*`, `*quantifier-info-list*`) are recursion-state.** Threading them through explicit parameters makes the clausifier reentrant and easier to parallelize across CPUs in a future implementation.
- **`empty-clause` is a memoized constant** (`*empty-clause* = (make-clause nil nil)`), but a fresh `(make-clause nil nil)` would not be `eq` to it. Inference workers that compare to "the empty clause" should use `empty-clause?` (which uses `clause-equal`), not `eq`.
- **The `cnf-formula` reconstructor is rendering, not roundtrip.** It produces an EL formula that *describes* the CNF but is not necessarily what the original EL input was. There is no `el-formula-from-cnf` that can be re-clausified to the same CNF — the standardize/skolemize steps are not invertible. The clean rewrite either provides a true inverse (preserving the original sentence alongside the CNF) or makes clear that clause→EL is for display only.
