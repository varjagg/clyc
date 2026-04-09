# HL Inference Modules Reference

This document catalogs every HL (Heuristic Level) inference module registered in the
Clyc codebase, organized by type and functional group. For each module, the source file,
sense, predicate (if specific), required-pattern, and cost are listed.

## Architecture Overview

HL modules are the primitive reasoning steps of the Cyc inference engine. They are
registered at load time via `inference-removal-module`, `inference-transformation-module`,
`forward-module`, `inference-meta-removal-module`, `inference-conjunctive-removal-module`,
and `hl-storage-module` calls. Each module is stored in `*hl-module-store*` (a global
hash table keyed by name).

### Module Selection

When a query literal arrives, the engine selects applicable modules by:
1. Matching **predicate** — predicate-specific modules are checked first, then universal,
   then generic modules
2. Matching **sense** — `:pos` or `:neg`
3. Matching **required-pattern** — the sentence structure must match
4. Matching **required-mt** — microtheory constraint (if any)
5. Evaluating **required** function — custom applicability check
6. Ranking by **cost** — lowest cost modules are preferred

### Cost Constants
- `*hl-module-simplification-cost*` = 0.01 (nearly free)
- `*cheap-hl-module-check-cost*` = 0.4
- `*hl-module-check-cost*` = 0.8
- `*typical-hl-module-check-cost*` = 1.0
- `*expensive-hl-module-check-cost*` = 1.5

### Pattern Language

The `:required-pattern` uses a declarative matching language:
- `:anything` — matches anything
- `:fort` — matches a FORT (First-Order Reified Term)
- `:fully-bound` — all variables are bound
- `:not-fully-bound` — at least one variable unbound
- `:variable` — matches a variable
- `:nart` — matches a NART (Non-Atomic Reified Term)
- `:collection-fort` — matches a FORT that is a collection
- `:predicate-fort` — matches a FORT that is a predicate
- `:closed-naut` — matches a fully-bound NAUT
- `:integer` — matches an integer
- `(:test fn)` — calls fn on the subexpression
- `(:and p1 p2 ...)` — conjunction of patterns
- `(:or p1 p2 ...)` — disjunction of patterns
- `(:not p)` — negation of pattern
- `(:nat p)` — matches a NAUT whose formula matches p
- `(:tree-find x)` — matches if x appears anywhere in the tree
- `(cons p1 p2)` — matches a cons cell
- `(list p1 p2 ...)` — matches a list of exactly that length

---

## 1. REMOVAL MODULES

Removal modules directly answer atomic queries without backward chaining through rules.
They are the workhorses of inference — every query that can be answered from the KB
index, by computation, or by exploiting predicate properties goes through a removal
module.

Registered via: `(inference-removal-module :name (list ...))`

### 1.1 KB Lookup (Generic)

**What they share:** These are the most fundamental modules. They have no `:predicate`
restriction and apply to any predicate with a FORT as predicate. They look up GAF
(Ground Atomic Formula) assertions directly in the KB index.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-lookup.lisp`

| Module | Sense | Required Pattern | Cost | Completeness |
|--------|-------|-----------------|------|-------------|
| `:removal-lookup-pos` | `:pos` | `(:fort . :anything)` | `removal-lookup-pos-cost` (cheap if fully-bound, else index size) | complete if `removal-completely-asserted-asent?` |
| `:removal-lookup-neg` | `:neg` | `(:fort . :anything)` | `removal-lookup-neg-cost` | dynamic |
| `:removal-pred-unbound` | `:pos` | `((:not :fort) . :anything)` AND `formula-contains-indexed-term?` | `removal-pred-unbound-cost` | `:grossly-incomplete` |

**`:removal-lookup-pos`** is the default positive GAF lookup — given `(P x y)` where P
is a FORT, it searches the GAF index for matching assertions. If fully bound, it's a
cheap check; if not, it iterates over the index.

**`:removal-lookup-neg`** does the same for negative sense (looking for false assertions).

**`:removal-pred-unbound`** is a last-resort module for when the predicate position is a
variable but at least one argument is an indexed term. It iterates over all GAFs
mentioning the indexed term and checks for unification.

### 1.2 Type Hierarchy — isa

**What they share:** All are specific to `#$isa` (or `#$quotedIsa` / `#$elementOf`).
They exploit the type hierarchy (isa graph, defns, collection functions) to answer
instance-of queries.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-isa.lisp`

#### 1.2.1 Core isa modules

| Module | Sense | Required Pattern | Cost | Notes |
|--------|-------|-----------------|------|-------|
| `:removal-isa-collection-check-pos` | `:pos` | `(#$isa :fully-bound :fort)` | `removal-isa-collection-check-pos-cost` | Check: is X an instance of collection Y? |
| `:removal-isa-collection-check-neg` | `:neg` | `(#$isa :fort :fort)` | `removal-isa-collection-check-neg-cost` | Negated isa check |
| `:removal-isa-naut-collection-check-pos` | `:pos` | `(#$isa :fort :closed-naut)` | `removal-isa-naut-collection-check-pos-cost` | Isa check where collection is a NAUT |
| `:removal-isa-naut-collection-lookup-pos` | `:pos` | `(#$isa (:not :fort) :closed-naut)` | `removal-isa-naut-collection-lookup-pos-cost` | `:grossly-incomplete` |
| `:removal-isa-defn-pos` | `:pos` | `(#$isa :fully-bound :fort)` | `removal-isa-defn-pos-cost` | Via collection definitions (defns) |
| `:removal-isa-defn-neg` | `:neg` | `(#$isa :fully-bound :fort)` | `removal-isa-defn-neg-cost` | Negated defn check |
| `:removal-all-isa` | `:pos` | `(#$isa :fully-bound :not-fully-bound)` | `*average-all-isa-count*` | Enumerate all types of X |
| `:removal-all-instances` | `:pos` | `(#$isa :not-fully-bound :fort)` | `removal-all-instances-cost` | Enumerate all instances of collection |

#### 1.2.2 Collection function modules

These handle `#$isa` queries where the collection is a NAUT constructed by a
collection-manipulating function.

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-isa-thecollectionof-check` | `:pos` | `(#$isa :fully-bound (:nat (#$TheCollectionOf . :fully-bound)))` | `*inference-recursive-query-overhead*` |
| `:removal-isa-thecollectionof-unify` | `:pos` | `(#$isa :not-fully-bound (:nat (#$TheCollectionOf . :fully-bound)))` | `*inference-recursive-query-overhead*` |
| `:removal-not-isa-thecollectionof-check` | `:neg` | `(#$isa :fully-bound (:nat (#$TheCollectionOf . :fully-bound)))` | `*inference-recursive-query-overhead*` |
| `:removal-isa-collection-subset-fn-check` | `:pos` | `(#$isa :fully-bound (:nat (#$CollectionSubsetFn . :fully-bound)))` | `*expensive-hl-module-check-cost*` |
| `:removal-isa-collection-subset-fn-unify` | `:pos` | `(#$isa :not-fully-bound (:nat (#$CollectionSubsetFn . :fully-bound)))` | `removal-collection-subset-fn-cost` |
| `:removal-isa-collection-intersection-2-fn-check` | `:pos` | `(#$isa :fully-bound (:nat (#$CollectionIntersection2Fn . :fully-bound)))` | `*expensive-hl-module-check-cost*` |
| `:removal-isa-collection-intersection-2-fn-unify` | `:pos` | `(#$isa :not-fully-bound (:nat (#$CollectionIntersection2Fn . :fully-bound)))` | `removal-isa-subcollection-cost` |
| `:removal-isa-collection-difference-fn-check` | `:pos` | `(#$isa :fully-bound (:nat (#$CollectionDifferenceFn . :fully-bound)))` | `*expensive-hl-module-check-cost*` |
| `:removal-isa-collection-difference-fn-unify` | `:pos` | `(#$isa :not-fully-bound (:nat (#$CollectionDifferenceFn . :fully-bound)))` | `removal-isa-subcollection-cost` |

#### 1.2.3 Subcollection function modules

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-isa-subcollection-of-with-relation-to-fn-check` | `:pos` | `(#$isa :fully-bound (:nat (#$SubcollectionOfWithRelationToFn . :fully-bound)))` | `*expensive-hl-module-check-cost*` |
| `:removal-isa-subcollection-of-with-relation-to-fn-unify` | `:pos` | `(#$isa :not-fully-bound (:nat (#$SubcollectionOfWithRelationToFn . :fully-bound)))` | `removal-isa-subcollection-cost` |
| `:removal-isa-subcollection-of-with-relation-from-fn-check` | `:pos` | `(#$isa :fully-bound (:nat (#$SubcollectionOfWithRelationFromFn . :fully-bound)))` | `*expensive-hl-module-check-cost*` |
| `:removal-isa-subcollection-of-with-relation-from-fn-unify` | `:pos` | `(#$isa :not-fully-bound (:nat (#$SubcollectionOfWithRelationFromFn . :fully-bound)))` | `removal-isa-subcollection-cost` |
| `:removal-isa-subcollection-of-with-relation-to-type-fn-check` | `:pos` | `(#$isa :fully-bound (:nat (#$SubcollectionOfWithRelationToTypeFn . :fully-bound)))` | `*expensive-hl-module-check-cost*` |
| `:removal-isa-subcollection-of-with-relation-to-type-fn-unify` | `:pos` | `(#$isa :not-fully-bound (:nat (#$SubcollectionOfWithRelationToTypeFn . :fully-bound)))` | `removal-isa-subcollection-cost` |
| `:removal-isa-subcollection-of-with-relation-from-type-fn-check` | `:pos` | `(#$isa :fully-bound (:nat (#$SubcollectionOfWithRelationFromTypeFn . :fully-bound)))` | `*expensive-hl-module-check-cost*` |
| `:removal-isa-subcollection-of-with-relation-from-type-fn-unify` | `:pos` | `(#$isa :not-fully-bound (:nat (#$SubcollectionOfWithRelationFromTypeFn . :fully-bound)))` | `removal-isa-subcollection-cost` |
| `:removal-isa-subcollection-occurs-at-fn-check` | `:pos` | `(#$isa :fully-bound (:nat (#$SubcollectionOccursAtFn . :fully-bound)))` | `*expensive-hl-module-check-cost*` |
| `:removal-isa-subcollection-occurs-at-fn-unify` | `:pos` | `(#$isa :not-fully-bound (:nat (#$SubcollectionOccursAtFn . :fully-bound)))` | `removal-isa-subcollection-cost` |

#### 1.2.4 quotedIsa modules

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-quoted-isa-collection-check-pos` | `:pos` | `(#$quotedIsa :fort :fort)` | `removal-quoted-isa-collection-check-pos-cost` |
| `:removal-quoted-isa-collection-check-neg` | `:neg` | `(#$quotedIsa :fort :fort)` | `removal-quoted-isa-collection-check-neg-cost` |
| `:removal-quoted-isa-defn-pos` | `:pos` | `(#$quotedIsa :fully-bound :fort)` | `removal-quoted-isa-defn-pos-cost` |
| `:removal-quoted-isa-defn-neg` | `:neg` | `(#$quotedIsa :fully-bound :fort)` | `removal-quoted-isa-defn-neg-cost` |
| `:removal-all-quoted-isa` | `:pos` | `(#$quotedIsa :fort :not-fully-bound)` | `*average-all-isa-count*` |
| `:removal-all-quoted-instances` | `:pos` | `(#$quotedIsa :not-fully-bound :fort)` | `removal-all-quoted-instances-cost` |
| `:removal-nat-quoted-isa` | `:pos` | `(#$quotedIsa (:fully-bound . :fully-bound) :fort)` | `*hl-module-check-cost*` |
| `:removal-nat-all-quoted-isa` | `:pos` | `(#$quotedIsa (:fully-bound . :fully-bound) :not-fully-bound)` | `*average-all-isa-count*` |

#### 1.2.5 elementOf modules

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-elementof-check` | `:pos` | `(#$elementOf :fully-bound (#$TheSet . :fully-bound))` | `*hl-module-check-cost*` |
| `:removal-elementof-unify` | `:pos` | `(#$elementOf :not-fully-bound (#$TheSet . :fully-bound))` | `removal-elementof-unify-cost` |
| `:removal-elementof-set-check` | `:pos` | `(#$elementOf :fully-bound (:and :fort (:not (:test collection-p))))` | `*hl-module-check-cost*` |
| `:removal-elementof-set-unify` | `:pos` | `(#$elementOf :not-fully-bound (:and :fort (:not (:test collection-p))))` | `removal-elementof-set-unify-cost` |
| `:removal-elementof-collection-check` | `:pos` | `(#$elementOf :fort :collection-fort)` | `*hl-module-check-cost*` |
| `:removal-elementof-collection-defn-check` | `:pos` | `(#$elementOf :fully-bound :collection-fort)` | `*hl-module-check-cost*` |
| `:removal-elementof-collection-unify` | `:pos` | `(#$elementOf :not-fully-bound :collection-fort)` | `removal-elementof-collection-unify-cost` |
| `:removal-elementof-thesetof-check` | `:pos` | `(#$elementOf :fully-bound (#$TheSetOf . :fully-bound))` | `*expensive-hl-module-check-cost*` |
| `:removal-elementof-thesetof-unify` | `:pos` | `(#$elementOf :not-fully-bound (#$TheSetOf . :fully-bound))` | `removal-elementof-thesetof-unify-cost` |
| `:removal-not-elementof-check` | `:neg` | `(#$elementOf :fully-bound (#$TheSet . :fully-bound))` | `*hl-module-check-cost*` |
| `:removal-not-elementof-set-check` | `:neg` | `(#$elementOf :fully-bound (:and :fort (:not (:test collection-p))))` | `removal-not-elementof-set-check-cost` |
| `:removal-not-elementof-collection-check` | `:neg` | `(#$elementOf :fort :collection-fort)` | `removal-not-elementof-collection-check-cost` |
| `:removal-not-elementof-collection-defn-check` | `:neg` | `(#$elementOf :fully-bound :collection-fort)` | `*hl-module-check-cost*` |
| `:removal-not-elementof-thesetof-check` | `:neg` | `(#$elementOf :fully-bound (#$TheSetOf . :fully-bound))` | `*inference-recursive-query-overhead*` |
| `:removal-all-elementof` | `:pos` | `(#$elementOf :fort :not-fully-bound)` | `*average-all-isa-count*` |
| `:removal-nat-all-elementof` | `:pos` | `(#$elementOf (:fully-bound . :fully-bound) :not-fully-bound)` | `*average-all-isa-count*` |

### 1.3 Generalization Hierarchy — genls

**What they share:** All specific to `#$genls` or `#$genlsDown`. They exploit the
genls subsumption hierarchy.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-genls.lisp`

| Module | Sense | Predicate | Required Pattern | Cost |
|--------|-------|-----------|-----------------|------|
| `:removal-superset` | `:pos` | `#$genls` | `(#$genls :fort :fully-bound)` | `*default-superset-cost*` |
| `:removal-not-superset` | `:neg` | `#$genls` | `(#$genls (:or :fort (:fully-bound . :fully-bound)) :fully-bound)` | depends on `*negation-by-failure*` |
| `:removal-all-genls` | `:pos` | `#$genls` | `(#$genls :fort :not-fully-bound)` | `removal-all-genls-cost` (genl-cardinality) |
| `:removal-all-specs` | `:pos` | `#$genls` | `(#$genls :not-fully-bound :fort)` | `removal-all-specs-cost` — `:grossly-incomplete` |
| `:removal-nat-genls` | `:pos` | `#$genls` | `(#$genls (:fully-bound . :fully-bound) :fully-bound)` | `*default-superset-cost*` |
| `:removal-nat-all-genls` | `:pos` | `#$genls` | `(#$genls (:fully-bound . :fully-bound) :not-fully-bound)` | `*default-nat-all-genls-cost*` |
| `:removal-genls-collection-subset-fn-pos-check` | `:pos` | `#$genls` | both args `(:nat (#$CollectionSubsetFn . :fully-bound))` | `*expensive-hl-module-check-cost*` |
| `:removal-genls-collection-subset-fn-neg-check` | `:neg` | `#$genls` | both args `(:nat (#$CollectionSubsetFn . :fully-bound))` | `*expensive-hl-module-check-cost*` |
| `:removal-genls-down-arg2-bound` | `:pos` | `#$genlsDown` | `(#$genlsDown :anything :fully-bound)` | `removal-genls-down-arg2-bound-cost` |
| `:removal-genls-down-arg2-unify` | `:pos` | `#$genlsDown` | `(#$genlsDown :fully-bound :not-fully-bound)` | 1 — `:complete` (reflexive) |

### 1.4 Predicate Hierarchy — genlPreds / genlInverse / negationPreds

**What they share:** These modules exploit the predicate generalization and negation
hierarchies to look up assertions under related predicates. They have no `:predicate`
restriction (they are generic modules) and work by walking the genlPreds/genlInverse
SBHL graphs.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-genlpreds-lookup.lisp`

| Module | Sense | Arity | Required Pattern | Cost |
|--------|-------|-------|-----------------|------|
| `:removal-genlpreds-lookup-pos` | `:pos` | any | `non-hl-predicate-p` AND `asent-has-indexed-term-arg-p` AND `inference-some-spec-pred-or-inverse?` | `removal-genlpreds-lookup-pos-cost` |
| `:removal-genlpreds-lookup-neg` | `:neg` | any | `non-hl-predicate-p` AND `asent-has-indexed-term-arg-p` AND `inference-some-genl-pred-or-inverse?` | `removal-genlpreds-lookup-neg-cost` |
| `:removal-genlpreds-pred-index-pos` | `:pos` | any | `non-hl-predicate-p` AND NOT `asent-has-indexed-term-arg-p` AND `inference-some-spec-pred-or-inverse?` | `removal-genlpreds-pred-index-pos-cost` |
| `:removal-genlpreds-pred-index-neg` | `:neg` | any | `non-hl-predicate-p` AND NOT `asent-has-indexed-term-arg-p` AND `inference-some-genl-pred-or-inverse?` | `removal-genlpreds-pred-index-neg-cost` |
| `:removal-genlinverse-lookup-pos` | `:pos` | 2 | `non-hl-predicate-p` AND `asent-has-indexed-term-arg-p` AND `inference-some-spec-pred-or-inverse?` | `removal-genlinverse-lookup-pos-cost` |
| `:removal-genlinverse-lookup-neg` | `:neg` | 2 | `non-hl-predicate-p` AND `asent-has-indexed-term-arg-p` AND `inference-some-genl-pred-or-inverse?` | `removal-genlinverse-lookup-neg-cost` |
| `:removal-genlinverse-pred-index-pos` | `:pos` | 2 | `non-hl-predicate-p` AND NOT `asent-has-indexed-term-arg-p` AND `inference-some-spec-pred-or-inverse?` | `removal-genlinverse-pred-index-pos-cost` |
| `:removal-genlinverse-pred-index-neg` | `:neg` | 2 | `non-hl-predicate-p` AND NOT `asent-has-indexed-term-arg-p` AND `inference-some-genl-pred-or-inverse?` | `removal-genlinverse-pred-index-neg-cost` |
| `:removal-negationpreds-lookup` | `:neg` | any | `non-hl-predicate-p` AND `asent-has-indexed-term-arg-p` AND `inference-some-negation-pred-or-inverse?` | `removal-negationpreds-lookup-cost` |
| `:removal-negationinverse-lookup` | `:neg` | any | `non-hl-predicate-p` AND `asent-has-indexed-term-arg-p` AND `inference-some-negation-pred-or-inverse?` | `removal-negationpreds-lookup-cost` |

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-genlpreds.lisp`

| Module | Sense | Predicate | Required Pattern | Cost |
|--------|-------|-----------|-----------------|------|
| `:removal-genlpreds-check` | `:pos` | `#$genlPreds` | `(#$genlPreds :predicate-fort :predicate-fort)` | `*default-genlpreds-check-cost*` |
| `:removal-all-genlpreds` | `:pos` | `#$genlPreds` | `(#$genlPreds :predicate-fort :variable)` | `removal-all-genlpreds-cost` |
| `:removal-all-spec-preds` | `:pos` | `#$genlPreds` | `(#$genlPreds :variable :predicate-fort)` | `removal-all-spec-preds-cost` |
| `:removal-not-genlpreds-check` | `:neg` | `#$genlPreds` | `(#$genlPreds :predicate-fort :predicate-fort)` | `*default-not-genlpreds-check-cost*` |

### 1.5 Predicate Properties — Symmetry, Commutativity, Asymmetry

**What they share:** These exploit algebraic properties of predicates (symmetry,
commutativity, partial commutativity, asymmetry) to find answers by permuting
arguments. All require `non-hl-predicate-p` and the corresponding property test.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-symmetry.lisp`

| Module | Sense | Arity | Required Pattern | Cost |
|--------|-------|-------|-----------------|------|
| `:removal-symmetric-lookup-pos` | `:pos` | 2 | `non-hl-predicate-p` AND `inference-symmetric-predicate?` | `removal-symmetric-lookup-pos-cost` |
| `:removal-symmetric-lookup-neg` | `:neg` | 2 | `non-hl-predicate-p` AND `inference-symmetric-predicate?` | `removal-symmetric-lookup-neg-cost` |
| `:removal-commutative-lookup-pos` | `:pos` | 3+ | `non-hl-predicate-p` AND `inference-commutative-predicate-p` | `removal-commutative-lookup-pos-cost` |
| `:removal-commutative-lookup-neg` | `:neg` | 3+ | `non-hl-predicate-p` AND `inference-commutative-predicate-p` | `removal-commutative-lookup-neg-cost` |
| `:removal-partially-commutative-lookup-pos` | `:pos` | 3+ | `non-hl-predicate-p` AND `inference-partially-commutative-predicate-p` | `removal-partially-commutative-lookup-pos-cost` |
| `:removal-partially-commutative-lookup-neg` | `:neg` | 3+ | `non-hl-predicate-p` AND `inference-partially-commutative-predicate-p` | `removal-partially-commutative-lookup-neg-cost` |
| `:removal-asymmetric-lookup` | `:neg` | 2 | `non-hl-predicate-p` AND both args `(:not :fort)` AND `inference-asymmetric-predicate?` | `removal-asymmetric-lookup-cost` |

### 1.6 Reflexivity / Irreflexivity

**What they share:** Exploit reflexive or irreflexive properties of binary predicates.
For reflexive predicates, `(P x x)` is always true; for irreflexive, `(P x x)` is
always false.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-reflexivity.lisp`

| Module | Sense | Required Pattern | Cost | Completeness |
|--------|-------|-----------------|------|-------------|
| `:removal-reflexive-both` | `:pos` | `non-hl-predicate-p`, both args `:fully-bound`, `inference-reflexive-predicate?` | `*default-reflexive-both-cost*` | `:incomplete` |
| `:removal-reflexive-one-arg` | `:pos` | one `:fully-bound`, one `:not-fully-bound`, `inference-reflexive-predicate?` | `*default-reflexive-one-arg-cost*` | `:grossly-incomplete` |
| `:removal-reflexive-map` | `:pos` | both `:not-fully-bound`, `inference-reflexive-predicate?` | `removal-reflexive-map-cost` | `:grossly-incomplete` |
| `:removal-irreflexive-both` | `:neg` | both `:fully-bound`, `inference-irreflexive-predicate?` | `*default-irreflexive-both-cost*` | `:incomplete` |
| `:removal-irreflexive-one-arg` | `:neg` | one `:fully-bound`, one `:not-fully-bound`, `inference-irreflexive-predicate?` | `*default-irreflexive-one-arg-cost*` | dynamic |
| `:removal-irreflexive-map` | `:neg` | both `:not-fully-bound`, `inference-irreflexive-predicate?` | `removal-irreflexive-map-cost` | dynamic |
| `:prune-reflexive-use-of-irreflexive-predicate` | `:pos` | `inference-irreflexive-predicate?`, required: arg1 = arg2 | 0 | `:complete` (pruning) |

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-reflexive-on.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-reflexive-on` | `:pos` | arity 2, at least one `:fully-bound`, `reflexive-on-predicate?` | `*hl-module-check-cost*` |

### 1.7 Transitivity

**What they share:** These walk the transitive closure of a transitive binary predicate
using the GHL (General Hierarchy Library) graph walker.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-transitivity.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-transitive-check` | `:pos` | both args `gt-required-arg-type-p`, `inference-transitive-predicate?` | `*default-transitive-check-cost*` |
| `:removal-transitive-arg1-walk` | `:pos` | arg1 `gt-required-arg-type-p`, arg2 `:variable`, `inference-transitive-predicate?` | `removal-transitive-arg1-walk-cost` (SBHL estimate) |
| `:removal-transitive-arg2-walk` | `:pos` | arg1 `:variable`, arg2 `gt-required-arg-type-p`, `inference-transitive-predicate?` | `removal-transitive-arg2-walk-cost` (SBHL estimate) |

### 1.8 Evaluation

**What they share:** These handle computable predicates that have an `evaluationDefn`
— the system calls SubL code to evaluate the predicate rather than looking it up in
the KB.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-evaluation.lisp`

| Module | Sense | Required Pattern | Cost | Notes |
|--------|-------|-----------------|------|-------|
| `:removal-eval` | `:pos` | `(:fort . :anything)`, exclusive: `inference-evaluatable-predicate?`, required: `fully-bound-p` | `*default-eval-cost*` | `:complete` |
| `:removal-not-eval` | `:neg` | `(:fort . :anything)`, exclusive: `not-eval-exclusive`, required: `not-eval-required` | `*default-eval-cost*` | `:complete` |

### 1.9 Function Corresponding Predicate (FCP)

**What they share:** These exploit the `functionCorrespondingPredicate` relationship,
which links a predicate to a function. E.g., `(#$biologicalMother X Y)` can be
answered if `Y = (#$BiologicalMotherFn X)`.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-function-corresponding-predicate.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-fcp-check` | `:pos` | required: `removal-fcp-check-required` (all args bound, NAT arg is nart/naut) | 0 |
| `:removal-fcp-find-nat` | `:pos` | required: `removal-fcp-find-nat-required` (only NAT arg unbound) | 0 |
| `:removal-evaluatable-fcp-unify` | `:pos` | required: `removal-evaluatable-fcp-unify-required` | 1 — `:complete` |

### 1.10 Difference / Identity

**What they share:** Specific to `#$different` and `#$differentSymbols`. These handle
the identity/difference predicates.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-different.lisp`

| Module | Sense | Predicate | Required Pattern | Cost |
|--------|-------|-----------|-----------------|------|
| `:removal-different-duplicate` | `:pos` | `#$different` | `(#$different . :anything)`, exclusive: `asent-duplicate-args-p` | 0 — supplants `:all` |
| `:removal-different-symbols-duplicate` | `:pos` | `#$differentSymbols` | `(#$differentSymbols . :anything)`, exclusive: `removal-different-symbols-duplicate-exclusive` | 0 — supplants `:all` |

### 1.11 Backchain Required

**What they share:** These prune or delay evaluation of literals that are marked as
backchain-required.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-backchain-required.lisp`

| Module | Sense | Required Pattern | Cost | Notes |
|--------|-------|-----------------|------|-------|
| `:removal-backchain-required-prune` | `:pos` | `(:test inference-backchain-required-asent-in-relevant-mt?)` | 0 | exclusive, pruning — produces no answers |

### 1.12 TVA (Transitive Via Argument)

**What they share:** These use TVA constraints (predicate argument constraints that
propagate transitively) to restrict or compute bindings.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-tva-lookup.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-tva-check` | `:pos` | `(:fort . :fully-bound)`, required: `removal-tva-check-required` | `*default-tva-check-cost*` |
| `:removal-tva-unify` | `:pos` | `(:fort . :not-fully-bound)`, required: `removal-tva-unify-required` | `removal-tva-unify-cost` |
| `:removal-tva-unify-closure` | `:pos` | `(:fort . :not-fully-bound)`, required: `removal-tva-unify-closure-required` | `removal-tva-unify-closure-cost` |

### 1.13 Relation Quantification — Instance/Exists, All/Exists, All/Instance

**What they share:** These handle the Cyc quantified-relation functions
(`RelationInstanceExistsFn`, `RelationExistsInstanceFn`, `RelationAllExistsFn`,
`RelationExistsAllFn`) which express constrained existential/universal quantification
over binary predicates.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-relation-instance-exists.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-relation-instance-exists-prune` | `:pos` | `(:tree-find #$RelationInstanceExistsFn)` | 0 (exclusive pruning) |
| `:removal-relation-instance-exists-check` | `:pos` | arity 2, one arg is `(#$RelationInstanceExistsFn :fort :fully-bound :fully-bound)` | `*default-relation-instance-exists-check-cost*` |
| `:removal-relation-instance-exists-unify-arg1` | `:pos` | `(:fort :not-fully-bound :fully-bound)`, required fn | dynamic |
| `:removal-relation-instance-exists-unify-arg2` | `:pos` | `(:fort :fully-bound :not-fully-bound)`, required fn | dynamic |
| `:removal-relation-instance-exists-unbound-arg1` | `:pos` | `(:fort :not-fully-bound :variable)` or nested RIEF | dynamic |
| `:removal-relation-instance-exists-unbound-arg2` | `:pos` | `(:fort :anything :not-fully-bound)` | dynamic |
| `:removal-relation-exists-instance-prune` | `:pos` | `(:tree-find #$RelationExistsInstanceFn)` | 0 (exclusive pruning) |
| `:removal-relation-exists-instance-check` | `:pos` | arity 2, one arg is `(#$RelationExistsInstanceFn ...)` | `*default-relation-exists-instance-check-cost*` |
| `:removal-relation-exists-instance-unify-arg1` | `:pos` | `(:fort :not-fully-bound :fully-bound)`, required fn | dynamic |
| `:removal-relation-exists-instance-unify-arg2` | `:pos` | `(:fort :fully-bound :not-fully-bound)`, required fn | dynamic |
| `:removal-relation-exists-instance-unbound-arg1` | `:pos` | `(:fort :not-fully-bound :anything)`, required fn | dynamic |
| `:removal-relation-exists-instance-unbound-arg2` | `:pos` | `(:fort :variable :not-fully-bound)` or nested REIF | dynamic |
| `:removal-relation-instance-exists-via-exemplar` | `:pos` | predicate `#$relationInstanceExists`, args are forts/collections | dynamic — `:grossly-incomplete` |
| `:removal-relation-exists-instance-via-exemplar` | `:pos` | predicate `#$relationExistsInstance` | dynamic — `:grossly-incomplete` |

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-relation-all-exists.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-relation-all-exists-prune` | `:pos` | `(:tree-find #$RelationAllExistsFn)` | 0 (exclusive pruning) |
| `:removal-relation-all-exists-check` | `:pos` | `(:fort :fully-bound (#$RelationAllExistsFn ...))` | `*default-relation-all-exists-check-cost*` |
| `:removal-relation-all-exists-unify` | `:pos` | `(:fort :fully-bound :variable)` or nested RAEF | dynamic |
| `:removal-relation-exists-all-prune` | `:pos` | `(:tree-find #$RelationExistsAllFn)` | 0 (exclusive pruning) |
| `:removal-relation-exists-all-check` | `:pos` | `(:fort (#$RelationExistsAllFn ...) :fully-bound)` | `*default-relation-exists-all-check-cost*` |
| `:removal-relation-exists-all-unify` | `:pos` | `(:fort :variable :fully-bound)` or nested REAF | dynamic |

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-relation-all-instance.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-relation-all-instance-check` | `:pos` | `(:fort :fully-bound :fully-bound)`, required fn | `*removal-relation-all-instance-check-cost*` |
| `:removal-relation-all-instance-unify` | `:pos` | `(:fort :anything :not-fully-bound)`, required fn | dynamic |
| `:removal-relation-all-instance-iterate` | `:pos` | `(:fort :not-fully-bound :fort)`, required fn | dynamic — `:incomplete` |
| `:removal-relation-instance-all-check` | `:pos` | `(:fort :fully-bound :fully-bound)`, required fn | `*removal-relation-instance-all-check-cost*` |
| `:removal-relation-instance-all-unify` | `:pos` | `(:fort :not-fully-bound :anything)`, required fn | dynamic |
| `:removal-relation-instance-all-iterate` | `:pos` | `(:fort :fort :not-fully-bound)`, required fn | dynamic — `:incomplete` |

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-relation-all.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-relation-all-check` | `:pos` | arity 1, `(:fort :fort)`, required fn | `*removal-relation-all-check-cost*` |

### 1.14 NAT / termOfUnit

**What they share:** These handle `#$termOfUnit` (which links NARTs to their formulas)
and the process of looking up or creating reified non-atomic terms.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-termofunit.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-nat-formula` | `:pos` | `(#$termOfUnit :nart :anything)` | `removal-nat-formula-cost` — `:complete` |
| `:removal-term-of-unit-fail` | `:pos` | `(#$termOfUnit ...)` where abduction not allowed and args don't match | 0 — pruning |
| `:removal-skolemize-create` | `:pos` | `(#$termOfUnit :not-fully-bound (:fort . :fully-bound))`, required fn | dynamic — `:complete` |
| `:removal-nat-lookup` | `:pos` | `(#$termOfUnit :not-fully-bound (:fort . :anything))` | `removal-nat-lookup-cost` |
| `:removal-nat-unify` | `:pos` | `(#$termOfUnit (:fully-bound . :fully-bound) (:anything . :anything))` | `*default-nat-unify-cost*` |

### 1.15 natFunction / natArgument

**What they share:** Specific to `#$natFunction` and `#$natArgument` — query the
function or arguments of a NART.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-natfunction.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-nat-function-check-pos` | `:pos` | `(#$natFunction :nart :fully-bound)` | dynamic — `:complete` |
| `:removal-nat-function-unify` | `:pos` | `(#$natFunction :nart :not-fully-bound)` | dynamic — `:complete` |
| `:removal-nat-function-lookup` | `:pos` | `(#$natFunction :not-fully-bound :fort)` | dynamic — `:complete` |
| `:removal-nat-argument-check-pos` | `:pos` | `(#$natArgument :nart :integer :fully-bound)` | dynamic — `:complete` |
| `:removal-nat-argument-term-unify` | `:pos` | `(#$natArgument :nart :integer :not-fully-bound)` | dynamic — `:complete` |
| `:removal-nat-argument-arg-unify` | `:pos` | `(#$natArgument :nart :not-fully-bound :anything)` | dynamic — `:complete` |
| `:removal-nat-argument-lookup` | `:pos` | `(#$natArgument :not-fully-bound (:or integer :variable) :fort)` | dynamic — `:complete` |
| `:removal-nat-arguments-equal-check-pos` | `:pos` | `(#$natArgumentsEqual :nart :nart)` | dynamic — `:complete` |

### 1.16 Asserted Sentence / Predicate Arg / Term Sentences

**What they share:** These handle meta-predicates that query the KB about what is
asserted: `#$assertedSentence`, `#$exactlyAssertedSentence`, `#$assertedPredicateArg`,
`#$assertedTermSentences`, `#$assertedTermSetSentences`, `#$termFormulas`.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-asserted-formula.lisp`

| Module | Sense | Predicate | Required Pattern | Cost |
|--------|-------|-----------|-----------------|------|
| `:removal-asserted-sentence-lookup-pos` | `:pos` | `#$assertedSentence` | inner sentence has known pred | dynamic |
| `:removal-asserted-sentence-lookup-neg` | `:neg` | `#$assertedSentence` | inner sentence fully bound | dynamic |
| `:removal-asserted-sentence-unbound-lookup-pos` | `:pos` | `#$assertedSentence` | pred unbound, has fort arg | dynamic |
| `:removal-exactly-asserted-sentence-lookup-pos` | `:pos` | `#$exactlyAssertedSentence` | inner sentence has known pred | dynamic |
| `:removal-exactly-asserted-sentence-lookup-neg` | `:neg` | `#$exactlyAssertedSentence` | inner sentence fully bound | dynamic |
| `:removal-exactly-asserted-sentence-unbound-lookup-pos` | `:pos` | `#$exactlyAssertedSentence` | pred unbound, has fort arg | dynamic |
| `:removal-asserted-predicate-arg-prune` | `:pos` | `#$assertedPredicateArg` | any arg is non-fort/non-integer | 0 (pruning) |
| `:removal-asserted-predicate-arg-pos-check` | `:pos` | `#$assertedPredicateArg` | `(:fort :integer :fort)` | dynamic — `:complete` |
| `:removal-asserted-predicate-arg-neg-check` | `:neg` | `#$assertedPredicateArg` | `(:fort :integer :fort)` | dynamic — `:complete` |
| `:removal-asserted-predicate-term-arg-var` | `:pos` | `#$assertedPredicateArg` | `(:fort :integer (:not :fort))` | dynamic — `:complete` |
| `:removal-asserted-predicate-term-var-var` | `:pos` | `#$assertedPredicateArg` | `(:fort (:not :integer) :anything)` | dynamic — `:complete` |
| `:removal-asserted-predicate-var-arg-pred` | `:pos` | `#$assertedPredicateArg` | `((:not :fort) :integer :fort)` | dynamic — `:complete` |
| `:removal-term-formulas-check-pos` | `:pos` | `#$termFormulas` | both args `:fully-bound` | dynamic — `:complete` |
| `:removal-term-formulas-check-neg` | `:neg` | `#$termFormulas` | both args `:fully-bound` | dynamic — `:complete` |
| `:removal-term-formulas-unify` | `:pos` | `#$termFormulas` | arg1 `:not-fully-bound`, arg2 `:fully-bound` | dynamic — `:complete` |
| `:removal-asserted-term-sentences-gaf-check-pos` | `:pos` | `#$assertedTermSentences` | term `:fully-bound`, inner `:fully-bound` | dynamic — `:complete` |
| `:removal-asserted-term-sentences-gaf-check-neg` | `:neg` | `#$assertedTermSentences` | term `:fully-bound`, inner `:fully-bound` | dynamic — `:complete` |
| `:removal-asserted-term-sentences-gaf-iterate` | `:pos` | `#$assertedTermSentences` | term `:not-fully-bound`, inner `:fully-bound` | dynamic — `:complete` |
| `:removal-asserted-term-sentences-arg-index-unify` | `:pos` | `#$assertedTermSentences` | term `:fort`, inner has unbound args | dynamic — `:complete` |
| `:removal-asserted-term-sentences-index-unify` | `:pos` | `#$assertedTermSentences` | term `:fort`, inner pred unbound but has fort arg | dynamic — `:complete` |
| `:removal-asserted-term-sentences-index-variable` | `:pos` | `#$assertedTermSentences` | term `:fort`, inner is `:variable` | dynamic — `:complete` |
| `:removal-asserted-term-set-sentences-index-variable` | `:pos` | `#$assertedTermSetSentences` | set `:fully-bound`, inner `:variable` | dynamic — `:complete` |
| `:removal-asserted-term-set-sentences-gaf-check-pos` | `:pos` | `#$assertedTermSetSentences` | set `:fully-bound`, inner `:fully-bound` | dynamic — `:complete` |
| `:removal-asserted-term-set-sentences-gaf-check-neg` | `:neg` | `#$assertedTermSetSentences` | set `:fully-bound`, inner `:fully-bound` | dynamic — `:complete` |

### 1.17 Indexical Referent

**What they share:** Specific to `#$indexicalReferent`. Resolves indexical terms
(e.g., `#$TheUser`, `#$QueryMt`, `#$Now`) to their referents.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-indexical-referent.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-indexical-referent-pos` | `:pos` | `(#$indexicalReferent (:and :fully-bound (:test indexical-referent-term-p)) :anything)` | `*default-indexical-referent-cost*` — `:complete` |

### 1.18 Abduction

**What they share:** These provide hypothetical/abductive reasoning. They only fire
when the problem store has abduction enabled. Module subtype is `:abduction`.

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-abduction.lisp`

| Module | Sense | Required Pattern | Cost |
|--------|-------|-----------------|------|
| `:removal-abduction-pos-check` | `:pos` | `(:fort . :fully-bound)`, required: `removal-abduction-pos-required` | `*default-abduction-cost*` — `:grossly-incomplete` |
| `:removal-abduction-pos-unify` | `:pos` | `(:fort . :anything)` AND NOT `(:fort . :fully-bound)` | `*default-abduction-cost*` — `:grossly-incomplete` |
| `:removal-exclusive-abduction-pos` | `:pos` | `(:fort . :anything)` AND `(:tree-find #$AbducedTermFn)` | `*default-abduction-cost*` — `:complete` (exclusive) |
| `:removal-abduction-neg-check` | `:neg` | `(:fort . :fully-bound)`, required fn | `*default-abduction-cost*` — `:grossly-incomplete` |

---

## 2. TRANSFORMATION MODULES

Transformation modules rewrite a query into sub-queries for backward chaining via
KB rules. They find applicable rules and create subproblems.

Registered via: `(inference-transformation-module :name (list ...))`

**Source:** `larkc-cycl/inference/modules/transformation-modules.lisp`

**What they share:** All transformation modules have `:direction :backward` and work
by selecting rules whose consequent matches the query literal, then creating
subproblems from the rule's antecedent. They use `:rule-select`, `:rule-filter`, and
`:expand` functions.

| Module | Sense | Predicate | Required Pattern | Notes |
|--------|-------|-----------|-----------------|-------|
| `:trans-predicate-pos` | `:pos` | — | `(:fort . :anything)` | Standard backward chaining using rules whose consequent matches |
| `:trans-predicate-neg` | `:neg` | — | `(:fort . :anything)` | Backward chaining for negated literals |
| `:trans-predicate-genlpreds-pos` | `:pos` | — | `((:and :fort inference-some-spec-pred-or-inverse?) . :anything)` | Backward chain using rules for spec-preds |
| `:trans-predicate-genlpreds-neg` | `:neg` | — | `((:and :fort inference-some-genl-pred-or-inverse?) . :anything)` | Backward chain using rules for genl-preds |
| `:trans-predicate-negationpreds-neg` | `:neg` | — | `((:and :fort inference-some-negation-pred-or-inverse?) . :anything)` | Backward chain via negation predicates |
| `:trans-predicate-symmetry-pos` | `:pos` | — | `(:fort :anything :anything)` AND `inference-symmetric-predicate?` | Backward chain via symmetric rules |
| `:trans-predicate-symmetry-neg` | `:neg` | — | `(:fort :anything :anything)` AND `inference-symmetric-predicate?` | Negated symmetric backward chain |
| `:trans-predicate-commutative-pos` | `:pos` | — | 3+ args, `inference-commutative-predicate-p` | Backward chain via commutative rules |
| `:trans-predicate-commutative-neg` | `:neg` | — | 3+ args, `inference-commutative-predicate-p` | Negated commutative backward chain |
| `:trans-predicate-partially-commutative-pos` | `:pos` | — | 3+ args, `inference-partially-commutative-predicate-p` | Backward chain via partially commutative rules |
| `:trans-predicate-partially-commutative-neg` | `:neg` | — | 3+ args, `inference-partially-commutative-predicate-p` | Negated partially commutative backward chain |
| `:trans-predicate-asymmetry` | `:neg` | — | `(:fort :anything :anything)` AND `inference-asymmetric-predicate?` | Backward chain via asymmetry |
| `:trans-unbound-predicate-pos` | `:pos` | — | required: `trans-unbound-predicate-pos-required` | Predicate is a variable |
| `:trans-unbound-predicate-neg` | `:neg` | — | required: `trans-unbound-predicate-neg-required` | Predicate is a variable (negated) |
| `:trans-isa-pos` | `:pos` | `#$isa` | `(#$isa :anything :fort)` | isa-specific backward chaining |
| `:trans-isa-neg` | `:neg` | `#$isa` | `(#$isa :anything :fort)` | Negated isa backward chaining |
| `:trans-genls-pos` | `:pos` | `#$genls` | `(#$genls :anything :fort)` | genls-specific backward chaining |
| `:trans-genls-neg` | `:neg` | `#$genls` | `(#$genls :anything :fort)` | Negated genls backward chaining |
| `:trans-genl-mt-pos` | `:pos` | `#$genlMt` | `(#$genlMt :anything (:test hlmt-p))` | genlMt backward chaining |
| `:trans-genl-mt-neg` | `:neg` | `#$genlMt` | `(#$genlMt :anything (:test hlmt-p))` | Negated genlMt backward chaining |
| `:trans-abnormal` | `:pos` | `#$abnormal` | `(#$abnormal :anything :assertion)` | Handle abnormality predicates |
| `:transformation-abduction-to-specs` | `:pos` | `#$isa` | arity 2, requires abduction allowed | Abductive transformation |

---

## 3. FORWARD MODULES

Forward modules fire proactively when new assertions are added to the KB. They match
the trigger assertion against rule antecedents and propagate conclusions.

Registered via: `(forward-module :name (list ...))`

**Source:** `larkc-cycl/inference/modules/forward-modules.lisp`

**What they share:** All forward modules have `:direction :forward`. Each specifies
`:rule-select` (find applicable rules), `:rule-filter` (narrow down), and `:expand`
(execute). Some also specify `:required-pattern` or `:required` for pre-filtering.

| Module | Sense | Predicate | Required Pattern | Notes |
|--------|-------|-----------|-----------------|-------|
| `:forward-normal-pos` | `:pos` | — | — | Standard forward rule propagation for positive triggers |
| `:forward-normal-neg` | `:neg` | — | — | Standard forward rule propagation for negative triggers |
| `:forward-isa` | `:pos` | `#$isa` | — | Propagate consequences of new isa assertions |
| `:forward-not-isa` | `:neg` | `#$isa` | — | Propagate consequences of isa retractions |
| `:forward-quoted-isa` | `:pos` | `#$quotedIsa` | — | Propagate quotedIsa assertions |
| `:forward-not-quoted-isa` | `:neg` | `#$quotedIsa` | — | Propagate quotedIsa retractions |
| `:forward-genls` | `:pos` | `#$genls` | — | Propagate genls assertions |
| `:forward-not-genls` | `:neg` | `#$genls` | — | Propagate genls retractions |
| `:forward-genlmt` | `:pos` | `#$genlMt` | — | Propagate genlMt assertions |
| `:forward-not-genlmt` | `:neg` | `#$genlMt` | — | Propagate genlMt retractions |
| `:forward-symmetric-pos` | `:pos` | — | `inference-symmetric-predicate?`, arity 2 | Auto-generate symmetric counterpart |
| `:forward-symmetric-neg` | `:neg` | — | `inference-symmetric-predicate?`, arity 2 | Symmetric retraction |
| `:forward-asymmetric` | `:pos` | — | required: `forward-asymmetric-required` | Generate asymmetric consequences |
| `:forward-commutative-pos` | `:pos` | — | 3+ args, `inference-at-least-partially-commutative-predicate-p` | Generate commutative variants |
| `:forward-commutative-neg` | `:neg` | — | 3+ args, `inference-at-least-partially-commutative-predicate-p` | Commutative retraction |
| `:forward-genlpreds-gaf` | `:pos` | `#$genlPreds` | `(#$genlPreds :fully-bound (:and :fort inference-some-genl-pred-or-inverse?))` | Propagate via genlPreds assertions |
| `:forward-not-genlpreds-gaf` | `:neg` | `#$genlPreds` | — | Retract genlPreds consequences |
| `:forward-genlpreds-pos` | `:pos` | — | `non-hl-predicate-p` AND `inference-some-genl-pred-or-inverse?` | Forward chain any predicate via genlPreds |
| `:forward-genlinverse-gaf` | `:pos` | `#$genlInverse` | `(#$genlInverse :fully-bound (:and :fort inference-some-genl-pred-or-inverse?))` | Propagate via genlInverse assertions |
| `:forward-not-genlinverse-gaf` | `:neg` | `#$genlInverse` | — | Retract genlInverse consequences |
| `:forward-genlinverse-pos` | `:pos` | — | `non-hl-predicate-p` AND `inference-some-genl-pred-or-inverse?`, arity 2 | Forward chain via genlInverse |
| `:forward-negationpreds` | `:pos` | — | required: `forward-negationpreds-required` | Forward chain via negation predicates |
| `:forward-negationinverse` | `:pos` | — | required: `forward-negationinverse-required` | Forward chain via negation inverses |
| `:forward-eval-pos` | `:pos` | — | exclusive: `forward-eval-exclusive-pos` | Forward evaluation of computable predicates |
| `:forward-eval-neg` | `:neg` | — | exclusive: `forward-eval-exclusive-neg` | Forward evaluation (negative) |
| `:forward-term-of-unit` | `:pos` | `#$termOfUnit` | — | Reify NATs when termOfUnit is asserted |
| `:forward-nat-function` | `:pos` | `#$termOfUnit` | — | Propagate natFunction consequences |
| `:forward-unbound-pred-pos` | `:pos` | — | required: `forward-unbound-pred-pos-required` | Forward with unbound predicate |
| `:forward-unbound-pred-neg` | `:neg` | — | required: `forward-unbound-pred-neg-required` | Forward with unbound predicate (neg) |
| `:forward-ist-pos` | `:pos` | — | — | Forward chain ist (context lifting) |
| `:forward-ist-neg` | `:neg` | — | — | Forward chain ist retraction |

---

## 4. META-REMOVAL MODULES

Meta-removal modules reason about which other removal modules to use. They provide
completeness guarantees by exploiting meta-knowledge about predicates.

Registered via: `(inference-meta-removal-module :name (list ...))`

**Source:** `larkc-cycl/inference/modules/removal/meta-removal-modules.lisp`

**What they share:** Both modules check whether a predicate is completely enumerable or
decidable (via KB assertions like `#$completeExtentEnumerable` or
`#$completeExtentDecidable`). They only apply when there are already possible removal
tactics but none is complete, and they promote the combined result to `:complete`.

| Module | Sense | Required Pattern | Required Function | Notes |
|--------|-------|-----------------|-------------------|-------|
| `:meta-removal-completely-enumerable-pos` | `:pos` | `(:fort . :not-fully-bound)` | `meta-removal-completely-enumerable-pos-required` | If predicate is completely enumerable, existing removal tactics yield complete answers |
| `:meta-removal-completely-decidable-pos` | `:pos` | `(:fort . :fully-bound)` | `meta-removal-completely-decidable-pos-required` | If predicate is completely decidable, existing removal tactics are authoritative |

---

## 5. CONJUNCTIVE REMOVAL MODULES

Conjunctive removal modules handle multi-literal conjunctive queries as a unit. They
are selected based on the conjunction of predicates in the clause, not individual
literals.

Registered via: `(inference-conjunctive-removal-module :name (list ...))`

### 5.1 Structural Pruning

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-conjunctive-pruning.lisp`

| Module | Every-Predicates | Notes |
|--------|-----------------|-------|
| `:residual-transformation-non-wff` | nil (any) | Prune residual transformation results that are not well-formed; exclusive, cost 0, complete |
| `:prune-unknown-sentence-literal-inconsistency` | nil (any) | Prune clauses with contradictory unknown-sentence literals; exclusive, cost 0, complete |
| `:prune-rt-problems-applicable-when-typed-only-when-specialization` | nil (any) | Prune RT problems applicable when typed only during specialization; exclusive, cost 0, complete |
| `:prune-circular-term-of-unit` | `(#$termOfUnit)` | Prune circular NAT references; exclusive, cost 0, complete |

### 5.2 Genls Between

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-genls.lisp`

| Module | Every-Predicates | Notes |
|--------|-----------------|-------|
| `:removal-genls-between` | `(#$genls)` | Solve `(#$and (#$genls X ?V) (#$genls ?V Y))` by computing genls-between |

### 5.3 Relation Instance Exists Expansion

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-relation-instance-exists.lisp`

| Module | Every-Predicates | Notes |
|--------|-----------------|-------|
| `:removal-relation-instance-exists-expansion` | `(#$isa)` | Expand existential relation conjunctions — `:grossly-incomplete` |

### 5.4 TVA Closure Conjunction

**Source:** `larkc-cycl/inference/modules/removal/removal-modules-tva-lookup.lisp`

| Module | Every-Predicates | Notes |
|--------|-----------------|-------|
| `:removal-tva-unify-closure-conjunction` | (none specified) | Solve a conjunction of positive literals each solvable with TVA — `:incomplete` |

### 5.5 Simplification

**Source:** `larkc-cycl/inference/modules/simplification-modules.lisp`

| Module | Every-Predicates | Notes |
|--------|-----------------|-------|
| `:removal-simplification-conjunction-duplicate-literals-via-functionality` | nil (any) | Simplify by binding variables when functional predicates prove equivalence; exclusive, cost 0, complete |

---

## 6. HL STORAGE MODULES

Storage modules handle writing assertions to the KB. They are not inference modules
per se but use the same registration mechanism.

Registered via: `(hl-storage-module :name (list ...))`

**Source:** `larkc-cycl/hl-storage-module-declarations.lisp`

| Module | Predicate | Pretty Name | Notes |
|--------|-----------|-------------|-------|
| `:regular-kb-assertion` | — (any) | "Regular KB Assertion" | Standard assertion storage; the default |
| `:ist` | `#$ist` | "ist" | Store assertions with ist (context lifting) |
| `:constant-name` | `#$constantName` | "constantName" | Store constant name mappings |
| `:assertion-direction` | `#$assertionDirection` | "assertionDirection" | Store assertion direction metadata |
| `:indexical-the-user` | `#$indexicalReferent` | "indexicalReferent TheUser" | Resolve and store TheUser indexical |
| `:perform-subl` | `#$performSubL` | "performSubL" | Execute SubL code as storage side-effect |

---

## 7. PREFERENCE MODULES

Preference modules do not produce answers — they influence module selection by
assigning preference levels to literals based on their binding state.

Registered via: `(inference-preference-module :name (list ...))`

**Source:** various (registered alongside the removal modules they influence)

Preference levels (least to most preferred):
- `:disallowed` — cannot generate answers in current binding state
- `:grossly-dispreferred` — most answers will be missed
- `:dispreferred` — some answers may be missed
- `:preferred` — everything decidable is enumerable

Notable preference modules:

| Module | Predicate | Sense | Pattern | Level/Function | Source |
|--------|-----------|-------|---------|----------------|--------|
| `:pred-unbound-pos` | — | `:pos` | `(:not-fully-bound . :anything)` | `pred-unbound-pos-preference` | removal-modules-lookup.lisp |
| `:genls-x-y-pos` | `#$genls` | `:pos` | both args `:not-fully-bound` | `:disallowed` | removal-modules-genls.lisp |
| `:all-specs-of-fort-pos` | `#$genls` | `:pos` | `(:not-fully-bound :fort)` | `:dispreferred` | removal-modules-genls.lisp |
| `:all-genls-pos` | `#$genls` | `:pos` | `(:fully-bound :not-fully-bound)` | `:dispreferred` | removal-modules-genls.lisp |
| `:backchain-required-pos` | — | `:pos` | `inference-backchain-required-asent-in-relevant-mt?` | `:preferred`, supplants `:all` | removal-modules-backchain-required.lisp |
| `:evaluatable-predicate-delay-until-closed` | — | `:pos` | evaluatable pred with unbound args | `:disallowed` | removal-modules-evaluation.lisp |
| `:different-delay-pos` | `#$different` | `:pos` | unbound args | `different-delay-pos-preference` | removal-modules-different.lisp |

---

## File Index

| File | Module Types |
|------|-------------|
| `inference/harness/inference-modules.lisp` | Core HL module infrastructure, struct, store |
| `inference/harness/removal-module-utilities.lisp` | Removal module utility functions |
| `inference/modules/removal/removal-modules-lookup.lisp` | KB lookup (pos/neg/pred-unbound) |
| `inference/modules/removal/removal-modules-isa.lisp` | isa, quotedIsa, elementOf, collection fns |
| `inference/modules/removal/removal-modules-genls.lisp` | genls, genlsDown, genls-between |
| `inference/modules/removal/removal-modules-genlpreds.lisp` | genlPreds check/enumerate |
| `inference/modules/removal/removal-modules-genlpreds-lookup.lisp` | genlPreds/genlInverse/negationPreds lookup |
| `inference/modules/removal/removal-modules-symmetry.lisp` | Symmetric/commutative/asymmetric lookup |
| `inference/modules/removal/removal-modules-reflexivity.lisp` | Reflexive/irreflexive predicates |
| `inference/modules/removal/removal-modules-reflexive-on.lisp` | reflexiveOn predicates |
| `inference/modules/removal/removal-modules-transitivity.lisp` | Transitive predicate closure |
| `inference/modules/removal/removal-modules-evaluation.lisp` | Evaluatable predicates (eval/not-eval) |
| `inference/modules/removal/removal-modules-function-corresponding-predicate.lisp` | FCP modules |
| `inference/modules/removal/removal-modules-different.lisp` | different/differentSymbols |
| `inference/modules/removal/removal-modules-backchain-required.lisp` | Backchain-required pruning |
| `inference/modules/removal/removal-modules-tva-lookup.lisp` | TVA constraint modules |
| `inference/modules/removal/removal-modules-relation-instance-exists.lisp` | RelationInstanceExists/ExistsInstance |
| `inference/modules/removal/removal-modules-relation-all-exists.lisp` | RelationAllExists/ExistsAll |
| `inference/modules/removal/removal-modules-relation-all-instance.lisp` | RelationAllInstance/InstanceAll |
| `inference/modules/removal/removal-modules-relation-all.lisp` | RelationAll (unary) |
| `inference/modules/removal/removal-modules-termofunit.lisp` | termOfUnit / NAT reification |
| `inference/modules/removal/removal-modules-natfunction.lisp` | natFunction / natArgument |
| `inference/modules/removal/removal-modules-asserted-formula.lisp` | assertedSentence, assertedPredicateArg, etc. |
| `inference/modules/removal/removal-modules-indexical-referent.lisp` | indexicalReferent |
| `inference/modules/removal/removal-modules-abduction.lisp` | Abductive reasoning |
| `inference/modules/removal/removal-modules-conjunctive-pruning.lisp` | Conjunctive pruning modules |
| `inference/modules/removal/meta-removal-modules.lisp` | Meta-removal (completeness reasoning) |
| `inference/modules/transformation-modules.lisp` | All transformation modules |
| `inference/modules/forward-modules.lisp` | All forward modules |
| `inference/modules/simplification-modules.lisp` | Simplification via functionality |
| `inference/modules/preference-modules.lisp` | Preference module infrastructure |
| `hl-storage-module-declarations.lisp` | HL storage modules |
