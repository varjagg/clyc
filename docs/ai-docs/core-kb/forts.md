# FORTs (First-Order Reified Terms)

A **FORT** is a constant or a NART — anything that has a **stable interned identity** in the KB and can serve as the subject of a `(predicate <fort> ...)` GAF. The name disambiguates from EL variables, EL keywords, atomic literals, and unreified NAUTs (which are s-expressions but not interned). Whenever Cyc code says "this slot must be a constant or a NART", it says **fort**.

The "first-order" in the name distinguishes FORTs from higher-order objects (sentences, formulas) — but in practice, FORTs are exactly "the things you can `eq`-compare for KB identity". A constant has identity via its SUID/GUID; a NART has identity via its integer ID; both compare with `eq` in normal use. EL variables, atomic literals, and unreified terms do not.

The **FORT** layer in the codebase is thin — `forts.lisp` is 169 lines, mostly polymorphic dispatchers (`fort-p`, `valid-fort?`, `remove-fort`, `reset-fort-index`) that case on whether the argument is a `constant-p` or a `nart-p`. The dispatchers are awkward in this drop because the NART branches are mostly `missing-larkc`. **`fort-types-interface.lisp`** is the type-test layer — about 50 predicates that ask "is this FORT a `<X>`?" by routing through `fort-has-type? fort type` over the SBHL `#$isa` graph.

## Why FORT exists as an abstraction

The FORT layer is *the type-erased polymorphism* between constants and NARTs:

- A constant (`#$Dog`) and a NART (the reified `(MotherFn Bart)`) are both first-class subjects in CycL.
- They have different storage, different IDs, different printers, different lifecycles — but for almost every purpose downstream, the difference doesn't matter.
- Indexing (term-index, kb-hl-support-index), type checks (`isa`, `genls`), MT-relevance, predicate evaluation, removal cascades — all of these handle FORTs uniformly.

Cyc could have unified them earlier (made every NAUT a NART; made every NART a constant) but the NART/constant split exists for valid reasons: NARTs are produced by the engine and don't need GUIDs; constants are user-vocabulary and need stable cross-image identity. The FORT layer is the bridge. Code that only cares about "do you have an interned KB-identity object?" uses `fort-p`; code that needs constant-specific or NART-specific behavior dispatches further.

## When does a FORT come into being?

It doesn't, distinctly. FORTs come into being via the constant or NART paths described in [constants.md](constants.md#shell-birth) and [narts.md](narts.md):

1. **A new constant is created** — `#$NewName` is read by the parser, or `kb-create-constant` is called. The shell is allocated, a SUID is reserved, eventually a GUID is bound. The result is a `constant`, which is also a `fort`.
2. **A NAUT is reified into a NART** — `nart-substitute` finds a closed NAUT under a reifiable functor and either looks it up or creates a fresh NART for it. The result is a `nart`, which is also a `fort`.
3. **KB load** — both paths replay during `load-essential-kb`. Constants come back via `load-constant-shells` + `load-constant-defs`; NARTs come back via the analogous nart paths.

A FORT does not have its own birth situation. The polymorphism is pure dispatch — nothing constructs "a FORT" without going through one of the two underlying constructors.

## When does a FORT go out of existence?

When the underlying constant or NART is removed:

- `remove-fort fort` dispatches: if `constant-p`, calls `remove-constant fort`; if `nart-p`, missing-larkc 10431 (currently — this would call `remove-nart`).
- `reset-fort-index fort new-index` is the polymorphic index update used during indexing rewrite paths; constants delegate to `reset-constant-index`, NARTs are missing-larkc 208.
- `valid-fort?` returns false post-removal (returns `valid-constant?` for constants, missing-larkc 30880 for NARTs — would call `valid-nart?`).

The constant and NART removal cascades manage everything (indices, dependents, asserted-by chains, etc.); the FORT layer doesn't add its own cleanup.

## Data structures

FORT is **not a struct**. There is no `(defstruct fort ...)`. FORT is a polymorphic union — `fort-p` is `(or (constant-p obj) (nart-p obj))`, and that's the type definition. The constant and NART structs are independent.

The one FORT-specific data structure:

### fort-id-index — keyed lookup over both spaces

```lisp
(defstruct fort-id-index
  constants     ; an id-index keyed on constant-internal-id
  narts)        ; an id-index keyed on nart-id
```

A two-channel id-index for "table that maps any FORT to any value, regardless of constant-or-NART". Conceptually a hashmap from `fort` to value, but split into two id-indices because the two ID spaces overlap (constant ID 5 and NART ID 5 are different things).

`fort-id-index-lookup`, `fort-id-index-enter`, `fort-id-index-remove` dispatch on `constant-p` to pick which underlying id-index to use. The constant branch uses `constant-internal-id`; the NART branch uses `(missing-larkc 30869/30870/30871)` — would call `nart-id`.

The size of each underlying id-index is sized at construction via `new-constant-internal-id-threshold` and `new-nart-id-threshold` — chosen to match the per-type maximums so the id-indices don't need to grow.

CFASL: opcode 99, registered via `declare-cfasl-opcode`. Serialized as `(count, [fort, value]*)` — count first, then alternating FORT and value cells. The reader (`cfasl-input-fort-id-index`) makes a fresh `fort-id-index` and populates it via `fort-id-index-enter`.

The fort-id-index is used by various per-FORT side tables — anything that needs to map "FORT to thing" without splitting the lookup logic across the two ID spaces.

## fort-has-type? — the polymorphic isa check

The most-called function over FORTs is `fort-has-type? fort type &optional mt`. It answers "does FORT have ISA TYPE in MT (default current relevance)?" by dispatching to the SBHL `#$isa` module:

```lisp
(defun fort-has-type? (fort type &optional mt)
  (when (fort-p fort)
    (let ((*mt* (update-inference-mt-relevance-mt mt))
          (*relevant-mt-function* (update-inference-mt-relevance-function mt))
          (*relevant-mts* (update-inference-mt-relevance-mt-list mt))
          (*sbhl-justification-search-p* nil)
          (*sbhl-apply-unwind-function-p* nil)
          (*suspend-sbhl-cache-use?* nil))
      (sbhl-predicate-relation-p (get-sbhl-module #$isa) fort type mt))))
```

The let-binding establishes the MT relevance scope; the SBHL module then walks the `#$isa` graph. Result: a single predicate boolean.

`fort-has-type-in-any-mt? fort type` is the wide-open variant — wraps the call in `with-all-mts` so visibility is across the entire KB.

These two are the foundation of the type-test layer. Every "is this FORT a `<X>`?" predicate routes through one of them.

## The type-test layer (`fort-types-interface.lisp`)

A flat set of ~50 predicates that all call `fort-has-type-in-any-mt? fort #$<TypeConstant>` or `fort-has-type? fort #$<TypeConstant> mt`. They exist because:

- These types are queried *constantly* by inference — every time the engine asks "is this thing a predicate? a relation? a microtheory? a quantifier?", a FORT type test fires.
- Naming them as functions instead of inlining the `fort-has-type-in-any-mt?` call makes call sites readable.
- Many are also exposed as the Cyc API. The wire protocol calls `(commutative-relation? X)` rather than `(fort-has-type-in-any-mt? X #$CommutativeRelation)`.

The catalog (each entry: `(<predicate> fort)` returns true iff `fort` has `isa <Type>`):

| Predicate | Type tested | Purpose |
|---|---|---|
| `mt?` | `#$Microtheory` | Is this a microtheory? |
| `mt-in-any-mt?` | `#$Microtheory` (any MT) | wrapped variant |
| `isa-mt?` | dispatches: FORT, HLMT-NAUT, or general `isa?` | full MT detection including HLMTs |
| `collection?` / `collection-p` | `#$Collection` | A class/category. |
| `collection-in-any-mt?` | `#$Collection` (any MT) | |
| `isa-collection?` | dispatches | full collection detection |
| `predicate?` / `predicate-p` | `#$Predicate` | binary predicate, takes args |
| `predicate-in-any-mt?` | `#$Predicate` (any MT) | |
| `isa-predicate?` | dispatches | |
| `function?` / `non-predicate-function?` / `functor?` | `#$Function-Denotational` | A function (NAUT functor). |
| `function-in-any-mt?` | `#$Function-Denotational` (any MT) | |
| `relation-p` | `#$Relation` | predicate or function |
| `sentential-relation-p` | logical-connective OR quantifier | |
| `anti-symmetric-binary-predicate-p` | `#$AntiSymmetricBinaryPredicate` | (a R b) and (b R a) ⇒ a = b |
| `anti-transitive-binary-predicate-p` | `#$AntiTransitiveBinaryPredicate` | |
| `asymmetric-binary-predicate-p` | `#$AsymmetricBinaryPredicate` | (a R b) ⇒ ¬(b R a) |
| `bookkeeping-predicate-p` | `#$BookkeepingPredicate` | metadata predicate (asserted-by, ...) |
| `broad-microtheory-p` | `#$BroadMicrotheory` | a wide-scoping MT |
| `commutative-relation-p` / `commutative-relation?` | `#$CommutativeRelation` | argument order doesn't matter |
| `commutative-predicate-p` | commutative AND predicate | |
| `distributing-meta-knowledge-predicate-p` | `#$DistributingMetaKnowledgePredicate` | |
| `el-relation-p` / `isa-el-relation?` | `#$ELRelation` | EL-only operator (ist, etc.) |
| `evaluatable-function-p` | `#$EvaluatableFunction` | computable like `PlusFn` |
| `evaluatable-predicate-p` | `#$EvaluatablePredicate` | |
| `irreflexive-binary-predicate-p` | `#$IrreflexiveBinaryPredicate` | ¬(a R a) |
| `logical-connective-p` / `isa-logical-connective?` | `#$LogicalConnective` | and, or, not, implies |
| `microtheory-designating-relation-p` | `#$MicrotheoryDesignatingRelation` | constructs an MT name |
| `partially-commutative-relation-p` | `#$PartiallyCommutativeRelation` | |
| `partially-commutative-predicate-p` | `#$PartiallyCommutativePredicate` (in `*anect-mt*`) | |
| `quantifier-p` | `#$Quantifier` | forAll, thereExists |
| `isa-quantifier?` | dispatches | |
| `reflexive-binary-predicate-p` | `#$ReflexiveBinaryPredicate` | (a R a) holds |
| `reifiable-function-p` / `isa-reifiable-function?` | `#$ReifiableFunction` | NART-eligible functor |
| `scoping-relation-p` / `isa-scoping-relation?` | `#$ScopingRelation` | introduces a scope (ist, KE-binding, …) |
| `sibling-disjoint-collection-p` | `#$SiblingDisjointCollectionType` | mutually-exclusive children |
| `skolem-function-p` | `#$SkolemFunction` | introduced by clausifier existentials |
| `symmetric-binary-predicate-p` | `#$SymmetricBinaryPredicate` | (a R b) ⇔ (b R a) |
| `transitive-binary-predicate-p` | `#$TransitiveBinaryPredicate` | (a R b) ∧ (b R c) ⇒ (a R c) |
| `variable-arity-relation-p` / `isa-variable-arity-relation?` | `#$VariableArityRelation` | varargs predicate |
| `bounded-existential-quantifier-p` | `#$ExistentialQuantifier-Bounded` | |
| `evaluatable-relation-contextualized-p` | `#$EvaluatableRelation-Contextualized` | |

The pattern of `*-p` and `*?` siblings (`predicate-p` and `predicate?`) is from SubL convention — `?` for "asks a question, may incur computation" and `-p` for "is this a predicate?". They are the same function in the port.

The pattern of `isa-X?` *vs* `X-p` is more meaningful: `X-p` requires the argument be a FORT. `isa-X?` accepts any term — if it's a FORT, dispatch to the FORT predicate; otherwise, fall through to `isa? term #$X mt` (the general inference path) or to a sufficient-defns admission check (`quiet-sufficient-defns-admit?`). The `isa-` prefix is "lift this type test to work on arbitrary terms".

## Public API surface

```
(fort-p obj)                                       ; Cyc API
(non-fort-p obj)
(valid-fort? fort)
(fort-count)                                       ; Cyc API
(remove-fort fort)                                 ; Cyc API
(reset-fort-index fort new-index)
(do-forts (var &key progress-message done) body)   ; Cyc API macro (currently no defmacro body)
(fort-el-formula fort)                             ; Cyc API (currently no defun body)

;; The fort-id-index
(make-fort-id-index)
(new-fort-id-index)
(fort-id-index-lookup index fort)
(fort-id-index-enter index fort obj)
(fort-id-index-remove index fort)

;; Type tests
(fort-has-type? fort type &optional mt)
(fort-has-type-in-any-mt? fort type)

;; ~50 type-specific predicates listed above
```

Note: `do-forts` is registered as a Cyc API macro but no defmacro body exists in the port. The intended expansion is "iterate over `do-constants` then `do-narts`" but this is currently missing-larkc. Same for `fort-el-formula` — registered as Cyc API but no defun in the port. The expected behavior is "if FORT is a constant, return its name as a symbol; if FORT is a NART, return its NAUT (fully expanded)".

## Consumers

| Consumer | What it uses |
|---|---|
| **Every assertion-related path** | `fort-p` to test slot validity; `valid-fort?` before mutating fort-related state. |
| **Inference modules** | Type tests (`predicate-p`, `collection-p`, `quantifier-p`, etc.) gate which inference path applies. |
| **Canonicalization** (`czer-utilities.lisp`) | `reifiable-function-p` for the NAUT-to-NART decision; `quantifier-p`, `logical-connective-p` to identify operators. |
| **Argument-type system** (`arg-type.lisp`, `at-routines.lisp`) | `fort-has-type? arg col` to test whether a term satisfies a typed argument-position constraint. |
| **MT subsystem** | `fort-p`, `valid-fort?` in HLMT validation; the genlMt SBHL graph indexes FORTs. |
| **Removal cascades** | `remove-fort` is the polymorphic entry; the NART/constant cascades both call into `dependent-narts` and `dependent-constants`. |
| **kb-hl-supports** | `fort-or-chlmt-p` is used in MT-validity checks; the index keys are FORTs. |
| **Skolem subsystem** (`skolems.lisp`) | `skolem-function-p` to recognize compiler-introduced functors. |
| **Indexing** (`kb-indexing.lisp`) | `fort-p` gates whether to use term-index or fall through to assertion-internal indexing. |
| **CFASL** | `fort-id-index` opcode 99. |

## Files

| File | Role |
|---|---|
| `forts.lisp` | The polymorphic dispatch layer — `fort-p`, `valid-fort?`, `remove-fort`, `reset-fort-index`, `fort-id-index` struct + CFASL. About half its declared functions (`fort-el-formula`, `do-forts`) are Cyc API registrations without bodies in the port. |
| `fort-types-interface.lisp` | The flat type-test catalog — ~50 predicates dispatching to `fort-has-type?` over the SBHL `#$isa` graph. |

## Notes for a clean rewrite

- **The polymorphism could be a sealed sum type.** `(or constant nart)` is exactly two variants; a sealed sum over `constant | nart` would make every dispatcher syntactic instead of `(if (constant-p ...) ... ...)`.
- **The NART branches in `forts.lisp` are mostly missing-larkc.** This is an artifact of the LarKC drop, not the design — the equivalent of `(constant-internal-id c)` for a NART is just `(nart-id n)`, which exists. Wire these up before the FORT layer is useful.
- **`fort-id-index` is a two-channel hashmap.** A clean rewrite either uses a single hashtable keyed on the FORT directly (with `eq` test, since FORTs are interned), or keeps the dual-channel design but exposes only the abstract `fort → value` operations. The current API leaks the constant/NART split; consumers shouldn't have to know which channel their FORT lands in.
- **The 50 type predicates are repetitive.** A code-gen macro `(define-fort-type-predicate name type)` would replace the 50 hand-written defuns. The port has many similar one-liners; the original SubL almost certainly had this macro and the LarKC compiler expanded it inline.
- **`fort-has-type?` re-establishes MT relevance bindings on every call.** This is correct — the type test must respect the caller's intended MT scope — but for a hot inner-loop predicate it's expensive. A clean rewrite either caches the relevance state or has a fast path for the common case where the caller already established the right scope.
- **`valid-fort?` is the only obviously-wrong-in-this-port function.** It returns `valid-constant?` for constants but `missing-larkc 30880` for NARTs, which means *any NART check fails or errors*. Fixing this is essential for any NART-containing code to behave correctly.
- **`fort-el-formula` and `do-forts` are Cyc API registrations with no implementation.** The Cyc API surface advertises them; calling them through the API layer dispatches to nothing. Either implement them or remove the registrations.
- **`reset-fort-index` is one of the two index-mutation paths.** The other is `assertion-indexing-store-set` (for assertion-as-meta-target), and elsewhere there are per-system index mutators. A unified "rewrite the term index for this term" entry would simplify the consumer code, which currently dispatches manually.
- **`fort-or-chlmt-p` (in `hlmt.lisp`)** is a curious type — "either a FORT or a closed HLMT". MTs that aren't FORTs (the HLMT NAUTs) behave like FORTs in many ways but aren't covered by the type. A clean rewrite either makes HLMTs into a third FORT-like variant or is explicit about why the predicate exists as a separate name.
- **The `*-p` / `*?` naming dichotomy** is SubL convention, not CL convention. Pick one for the rewrite — probably `*-p` for boolean predicates (CL convention) — and rename. The synonyms (`predicate-p` and `predicate?` being identical functions) should be removed.
