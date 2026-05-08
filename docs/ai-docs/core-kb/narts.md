# NARTs (and NAUTs)

A **NAT** (Non-Atomic Term) is a function-shaped term: a list `(functor arg1 ... argN)` whose meaning is the value the functor produces. CycL distinguishes:

- **NAUT** (Non-Atomic Unreified Term) — the literal list `(MotherFn Bart)`. Just an s-expression.
- **NART** (Non-Atomic Reified Term) — an opaque interned object that *stands for* a particular NAUT. Two reads of the same `(MotherFn Bart)` form yield the same NART struct.

A NART exists when the NAUT was reified — meaning a concrete identity was minted for that exact functor+args expression. The reification is recorded by an assertion `(#$termOfUnit nart naut)` in `*tou-mt*` (default `#$BaseKB`). The NART is the singleton; the NAUT is its body. Printing a NART writes its NAUT.

Reification requires:
1. The functor must be `(isa functor #$ReifiableFunction)` — see `reifiable-function-p` / `reifiable-functor?`.
2. The NAUT must be **closed** — `fully-bound-p` (no variables anywhere).
3. Sub-NARTs nested inside are themselves reified (recursively).

Non-reifiable functors are typically `#$EvaluatableFunction`s (e.g. `#$PlusFn`) whose semantics are computed, not stored. `(PlusFn 2 3)` evaluates to `5`; there's no NART for it.

NART **identity does not reflect referent equality**. `(MotherFn Bart)` and `(MotherFn Lisa)` are different NARTs even when both refer to the same individual (Marge); the `equals` assertion is the mechanism for declaring referent-equality.

A NART is "dependent on" every FORT mentioned anywhere inside its NAUT (recursively, including the functor and any sub-NARTs). `dependent-narts` traverses this graph; removing a constant cascades to all NARTs that mention it.

## Data structure

```
(defstruct (nart (:conc-name "N-"))
  id)    ; integer | nil
```

Even simpler than `constant`. The NART struct is just an identity holder; the NAUT body lives in a separate side table managed by the **nart-hl-formula-manager** (LRU-fronted, cache-backed). Asking a NART for its body is a swap-in operation.

`valid-nart-handle?` exists but is currently `missing-larkc 30862`; in practice valid is determined by `(integerp (n-id nart))`.

## Identifier space

NARTs use a single per-image integer ID. There is **no GUID for a NART** — when a KB is dumped, NARTs are dumped by recipe (their NAUT, with constants written by GUID and sub-NARTs recursively) rather than by stable cross-image identity. This is consistent with NARTs being a per-image internal optimization for NAUTs.

The lookup tables:

```
ID  → nart                     *nart-from-id*               (id-index)
ID  → nart-hl-formula (NAUT)   *nart-hl-formula-manager*    (LRU-fronted)
ID  → nart-index (assertion)   *nart-index-manager*         (LRU-fronted)
```

NAUT → NART lookup goes through `*nart-hl-formula-table*` (`nart-lookup`), itself reachable via `find-nart` after `nart-substitute` recursively reifies sub-NARTs. Both `nart-lookup` and most of the nart-hl-formula table operations are currently `missing-larkc` in the port — the lookup table is read from CFASL on KB load, but the build-from-scratch path was stripped.

## NAUT vs. NART predicates

```
(possibly-naut-p obj)        ; "could be a NAT formula" — list with non-FORT car or non-FORT-functor
(cycl-nat-p obj)             ; full NAT check (see term.lisp)
(naut-p obj)                 ; possibly-naut-p AND cycl-nat-p AND not nart-p
(nart-p obj)                 ; NART struct
(fort-p obj)                 ; constant-p OR nart-p
(fully-bound-p obj)          ; no variables anywhere
(nat-formula-p obj)          ; alias for possibly-naut-p
(contains-nat-formula-as-element? list)  ; one-level scan for nested NAUTs
```

## NART ↔ NAUT conversion

| Direction | Function | Behavior |
|---|---|---|
| NAUT → NART | `nart-lookup` | exact lookup by HL formula, no sub-substitution |
| NAUT → NART | `find-nart` | substitutes existing sub-NARTs first, then looks up |
| NAUT → NART (creating) | `find-or-create-nart` / `hl-find-or-create-nart` | upsert (commented in port; LarKC-stripped) |
| NART → NAUT | `nart-hl-formula` | the HL formula (Cyc API; body in port is missing-larkc) |
| NART → EL formula | `nart-el-formula` | EL view, recursively expanding sub-NARTs |
| Anything → expanded | `nart-expand obj` | recursively replace every NART in `obj` with its EL formula |
| Anything → NART-where-possible | `nart-substitute obj` / `nart-substitute-recursive obj` | recursively reify sub-NAUTs into NARTs |
| NAUT → NART-or-self | `naut-to-nart obj` | reify if possible; else return as-is |

`nart-substitute-recursive` is a destructive-then-replace traversal: it walks the list, copies it on first NAUT-detection, recurses into nested NAUTs, replaces them with NARTs in place, then performs a final `nart-lookup` on the rewritten list to see if the whole thing reifies.

## Removal

```
(remove-nart nart)              ; Cyc API entry — body LarKC-stripped
(remove-dependent-narts fort)   ; cascade from constant/NART removal
```

`remove-dependent-narts fort` walks `(dependent-narts fort)` — every NART whose NAUT mentions `fort` at any depth — and `cyc-kill`s those that pass an internal "should we actually drop this" gate (the gate is itself `missing-larkc 30883`, almost certainly one of `useful-nart?` / `nart-specified-to-be-retained?` / `useless-nart?` / `invalid-nart?`, all stripped). Self-dependency aborts (`must (not (eq fort dependent))`). After this cascade, the constant or NART itself is freed.

## Per-NART tables

### nart-hl-formula-manager

Maps `nart-id` → its NAUT body. Manages a fixed-percentage (`*nart-hl-formula-lru-size-percentage*` = 5) of NART bodies in RAM, swapping the rest to/from the on-disk file-vector keyed by ID.

```
*nart-hl-formula-manager*                 ; the singleton
(setup-nart-hl-formula-table size exact?)
(clear-nart-hl-formula-table)
(cached-nart-hl-formula-count)
(nart-hl-formulas-unbuilt?)               ; true if NART table populated but formulas not yet
(swap-out-all-pristine-nart-hl-formulas)
(initialize-nart-hl-formula-hl-store-cache)  ; "nart-hl-formula"/"nart-hl-formula-index" file pair
```

### nart-index-manager

Maps `nart-id` → assertion index (every assertion that mentions this NART). Same shape as the constant-index-manager (`*nart-index-lru-size-percentage*` = 20). Storage paths: `nat-indices` and `nat-indices-index`.

## Lifecycle hooks

```
(setup-nart-table size exact?)         ; allocates *nart-from-id*
(finalize-narts &optional max-id)      ; sets next-id (full path missing-larkc 30878)
(clear-nart-table)
(register-nart-id nart id)             ; install a NART with a known ID (KB load)
(reset-nart-id nart new-id)            ; primitive ID rewrite
(make-nart-shell &optional id)         ; allocate; ID is mandatory in port (missing-larkc 30861)
(create-sample-invalid-nart)           ; placeholder (no-id) for CFASL invalid markers
(free-all-narts)                       ; LarKC-stripped
```

## CFASL serialization

See [cfasl.md](../persistence/cfasl.md). The opcode is `*cfasl-opcode-nart*` = 31. NARTs serialize **only by handle** (recipe path is `missing-larkc 32172`), so cross-image transport requires the receiver to share the NART ID space. For genuine cross-image dumps, code on the writing side substitutes NARTs with their NAUTs first (where each constant inside the NAUT goes by GUID).

| Direction | Code path |
|---|---|
| Output | `cfasl-output-object-nart-method` (currently missing-larkc 32184) |
| Input handle | `cfasl-input-nart` → `cfasl-input-nart-handle` → `cfasl-nart-handle-lookup` |

Handle lookup dispatches through `*cfasl-nart-handle-lookup-func*`:

| Value | Use |
|---|---|
| `nil` or `'find-nart-by-id` | normal in-image |
| `'find-nart-by-dump-id` | KB load — dump-ids → current IDs via `*nart-dump-id-table*` |

`with-nart-dump-id-table` is the macro that binds both `*nart-dump-id-table*` and `*cfasl-nart-handle-func*` for the duration of a KB load. Parallel structure to `with-assertion-dump-id-table`.

Unknown ID resolves to `*sample-invalid-nart*` rather than signaling — the user has flagged this same pattern (in constants) for replacement with a condition in a clean rewrite.

## Term complexity

`function-terms.lisp` defines polymorphic complexity walkers used by inference cost estimation:

```
(term-functional-complexity obj)         ; max depth of NAT nesting in obj
(term-relational-complexity-internal obj); per-method, no default
(term-of-unit-assertion-p assertion)     ; true iff assertion is a (#$termOfUnit ...) GAF
(nat-formula-p obj)                      ; alias for possibly-naut-p
```

`term-functional-complexity-internal` defmethods:
- `constant`: 0
- `nart`: missing-larkc 10746 (would walk `nart-hl-formula`, take max of arg complexities, +1)
- `cons`: 0 if functor is a non-predicate-function (the result is "just" the function value); else 1 + max of arg complexities

Used by inference module productivity estimates and by canonicalization to bound recursion.

## Public API

```
(nart-p obj) (nart-id nart) (find-nart-by-id id)
(nart-count) (do-narts (var ...) body)
(nart-hl-formula nart)              ; → NAUT
(nart-el-formula nart)              ; → EL formula (recursively expanded)
(naut-p obj)
(find-nart hl-formula)              ; lookup, with sub-NART substitution
(nart-lookup hl-formula)            ; lookup, no substitution
(nart-substitute obj) (nart-expand obj)
(naut-to-nart naut)                 ; reify if possible, else return naut
(remove-nart nart)
(random-nart &optional test)
(find-or-create-nart hl-formula)    ; obsolete-registered → hl-find-or-create-nart → cyc-find-or-create-nart
```

Obsolete chain in port: `find-or-create-nart` → `hl-find-or-create-nart` → `cyc-find-or-create-nart`. A clean rewrite picks one name.

## Files

| File | Role |
|---|---|
| `nart-handles.lisp` | struct, ID table, register/reset/find-by-id |
| `narts-high.lisp` | NAUT↔NART conversion, expand/substitute, remove-dependent-narts |
| `nart-hl-formula-manager.lisp` | LRU-fronted ID → NAUT body store |
| `nart-index-manager.lisp` | LRU-fronted ID → assertion-index store |
| `function-terms.lisp` | NAUT predicates, term-of-unit, complexity |

## Notes for a clean rewrite

- The `nart` struct could just **be** the NAUT body in many implementations. The current split exists because (a) the body lives in a swap-cached on-disk store, (b) Java needed an opaque handle to keep references stable across swaps. If memory is sufficient, store the body in the struct.
- `*sample-invalid-nart*`-as-error-marker should be replaced by a condition.
- The "dependent NART" cascade is a graph operation that should be made first-class (forward graph: term → narts depending on term).
- NART vs NAUT distinction is a printer/internment optimization. A clean implementation can build NART around an interned cons (e.g. via a hash-cons on `(functor . args)`) and skip the explicit `id` ↔ struct mapping.
- Multiple obsolete chains for "find or create NART". Pick one.
- The dump-id table is a generic deserialization concern — see [cfasl.md](../persistence/cfasl.md) for the proposed unified design.
