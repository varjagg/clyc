# Unrepresented terms

An **unrepresented term** in CycL is a *literal value* that appears in an assertion but has no Cyc constant or NART backing it — concretely, a string or a real number. Examples: `"Albert Einstein"`, `42`, `3.14`. CycL needs to know which assertions mention each unrepresented term (so the indexing engine can answer "what do we know about the number 42?"), but unlike constants and NARTs, these terms have no defining structure — they are just SubL atoms.

The two files together implement the **identity and indexing infrastructure for these atomic literal terms**:

- `unrepresented-terms.lisp` — the SUID (system-unique-id) registry and the per-term **assertion index** lookup. This is the analog of `constant-handles.lisp` + `constants-low.lisp` but for strings and numbers instead of constants.
- `unrepresented-term-index-manager.lisp` — the **LRU object manager** for the per-term indices, mirroring the constant-index, NART-index, assertion-content, and deduction-content managers.

Together these are tiny (~150 lines combined) but architecturally essential: they're how the indexing system makes literal values queryable.

## The "represented vs. unrepresented" taxonomy

From `cycl-grammar.lisp`:

| Form | Predicate | Examples |
|---|---|---|
| Represented term | `cycl-represented-term-p` | constants, NATs, variables — terms with structural identity |
| Unrepresented term | `cycl-unrepresented-term-p` | strings, real numbers — literal SubL values |

The split exists because *represented* terms have managed identity (a constant has a GUID, a NART has a handle, a variable has a slot), while *unrepresented* terms are just whatever the SubL reader produced. Both kinds can appear as arguments to predicates and both need indexing, but they need different identity strategies. Constants are equal by GUID; strings are equal by `equal` (string content); numbers are equal by `=` (numeric value), generalized to `equal` for the hashtable.

`indexed-unrepresented-term-p` is the predicate consulted by the indexing layer (`kb-indexing-datastructures.lisp` line 93). It is currently implemented identically to `cycl-unrepresented-term-p`: every unrepresented term is indexed.

## Two registries, one term

For each unrepresented term the system maintains:

1. **A SUID** — a small integer assigned the first time the term is seen. SUIDs are stable across an image's lifetime and survive a KB dump as the term's identity in the dump file.
2. **An assertion index** — the same kind of structure that constants and NARTs have: a record of every CycL assertion that mentions this term, organized by predicate / arg-position / mt for query efficiency.

The two registries are independent in code (different files, different managers) but coupled in lifecycle: a term gets its index only after it has a SUID, and removing a term means tearing down the index then the SUID.

### State owned by `unrepresented-terms.lisp`

| Variable | Purpose |
|---|---|
| `*unrepresented-term-from-suid*` | An `id-index` (vector + overflow hash) mapping `SUID → term`. The forward direction. |
| `*unrepresented-term-to-suid*` | An `equal`-keyed hash table mapping `term → SUID`. The reverse direction. Equal-keyed because string/number identity is by-value. |
| `*unrepresented-term-dump-id-table*` (defparameter, default nil) | Used during KB dump load to remap dump-ids to SUIDs. Currently aliased — `find-unrepresented-term-by-dump-id` simply calls `find-unrepresented-term-by-suid`. The table itself is unused in the LarKC port; the indirection exists so dump-ids and SUIDs can diverge if needed (e.g. SUID compaction across dumps). |

### State owned by `unrepresented-term-index-manager.lisp`

| Variable | Purpose |
|---|---|
| `*unrepresented-term-index-manager*` | A KB object manager (LRU + on-disk file-vector swap) keyed by SUID, holding the indices. Initially `:uninitialized`. |
| `*unrepresented-term-index-lru-size-percentage*` | LRU sizing: 10% of all indices held in memory. Hard-coded constant; comment says "Wild guess." |

The "10%" cap means: at most 10% of indexed unrepresented terms have their indices in memory; the rest are swapped out to disk and faulted in on demand via `load-unrepresented-term-index-from-cache`.

## When does an unrepresented term get a SUID?

A SUID is minted *the first time a term is encountered in a context that needs an index*. This is the trigger:

- **A new assertion is created that mentions the term**, and the indexing layer calls `reset-term-index` on the term with a new index. The dispatch in `kb-indexing-datastructures.lisp:129` routes to `(reset-unrepresented-term-index term index t)`. The `t` is `bootstrap?` — it tells `reset-unrepresented-term-index` to call `find-or-create-unrepresented-term-suid` (mint a fresh SUID if one doesn't exist) rather than `unrepresented-term-suid` (look up only).
- **A KB dump is being loaded**, and the dumper sees an unrepresented term. `dumper.lisp:607` calls `register-unrepresented-term-suid v-term dump-id` to bind the term to the SUID it had in the dump file. This path uses an *exact* SUID rather than the next-available one, because preserving the dump's SUIDs lets index records reference terms by integer ID without re-resolving names.

In both cases the SUID becomes the term's permanent identity; subsequent `unrepresented-term-suid TERM` calls return the same SUID.

A SUID is **deregistered** when the term's index becomes empty — `reset-unrepresented-term-index TERM nil` (no new index) calls `deregister-unrepresented-term-index` then `deregister-unrepresented-term-suid`. The slot is freed for reuse.

## When does an index get swapped in/out of memory?

The index manager wraps a generic [kb-access/kb-object-manager.md](../kb-access/kb-object-manager.md) instance. Lifecycle:

- **Index materialized in memory** when:
  - It's freshly built (a `register-unrepresented-term-index ID INDEX` call from `reset-unrepresented-term-index`).
  - It's faulted in on demand via `load-unrepresented-term-index-from-cache` when a query references a term whose index is currently swapped out.
- **Index marked muted** via `mark-unrepresented-term-index-as-muted ID`. Called from `kb-indexing.lisp:95-96` when the index has been mutated and is no longer pristine.
- **Pristine indices swapped out** via `swap-out-all-pristine-unrepresented-term-indices` — the LRU eviction sweep that frees memory by writing pristine (unmodified-since-load) indices back to file-vector storage.
- **Index destroyed** when its term is being removed from the KB — `reset-unrepresented-term-index TERM NIL` clears the index then deregisters the SUID.

## What's in an unrepresented-term index?

The same shape as a constant or NART index — a structure of `kb-indexing.lisp` indexed-term-records keyed by predicate and argument position, holding the assertion-IDs that mention this term. The query API in [kb-access/kb-indexing.md](../kb-access/kb-indexing.md) treats unrepresented terms uniformly with constants and NARTs via `term-index` and `reset-term-index`.

## How other systems consume this

| System | Use |
|---|---|
| `kb-indexing-datastructures.lisp` | `indexed-term-p` includes `indexed-unrepresented-term-p`. `term-index` and `reset-term-index` dispatch into the unrepresented-term registries. |
| `kb-indexing.lisp` | Dispatches index-mutation events to `mark-unrepresented-term-index-as-muted` for unrepresented terms. |
| `kb-accessors.lisp` | `cycl-unrepresented-term-p` is consulted as part of valid-CycL-term checks. |
| `kb-utilities.lisp`, `nart-index-manager.lisp` | Reference the constant/NART/unrepresented-term trichotomy when deciding which manager to query. |
| `dumper.lisp` | Both reads and writes the SUID registry on dump save/load (`register-unrepresented-term-suid`, `dump-unrepresented-term-index` (stripped), `load-unrepresented-term-index-from-cache`). The HL-store cache for unrepresented-term indices is initialized via `initialize-unrepresented-term-index-hl-store-cache` from `system-kb-initializations`. |
| `cycl-grammar.lisp` | Defines `cycl-unrepresented-term-p` (the type predicate) and references it from grammar rules. |
| `folification.lisp`, `system-version.lisp` | Mention unrepresented terms in passing. |

`misc-utilities.lisp:167` calls `initialize-unrepresented-term-index-hl-store-cache` as part of the HL-store cache startup — that's the entry point that makes the index manager ready to fault things in from disk.

## Notes for a clean rewrite

- **The two-file split is artifact of the SubL compilation, not a real boundary.** SUID management and the index-manager wrapper belong in one module — they always co-vary. A clean rewrite should fold them into one ~120-line file `unrepresented-terms.lisp` with the index manager as an internal slot.
- **The `:uninitialized` initial value for `*unrepresented-term-index-manager*` plus the `unless *unrepresented-term-from-suid*` guards in `setup-unrepresented-term-suid-table` exist because of SubL's idempotent-init dance.** Modern code can construct these eagerly at module load — the guard isn't load-bearing.
- **Use the host language's hashtable for the to-suid map.** Currently it's a `make-hash-table :test #'equal`; a clean rewrite has nothing to gain by indirecting through SubL's hashtable wrapper. The `*unrepresented-term-from-suid*` id-index is the more interesting structure (vector + overflow hash); replace it with a simple growable vector (since SUIDs are dense from 0).
- **Generalize the LRU object manager.** Right now there are five independent managers (constant-index, NART-index, NART-HL-formula, assertion-content, deduction-content, KB-HL-support, unrepresented-term-index — actually seven). A clean rewrite should have *one* parameterized manager type and instantiate it per content kind. The "10% LRU" magic number per manager is a guess that should be tuneable from config.
- **The `*unrepresented-term-dump-id-table*` is dead code in the LarKC port.** Either implement the dump-id↔SUID mapping (so dump compaction is possible) or delete it.
- **`reset-unrepresented-term-index TERM NIL` doing both index-deregister and SUID-deregister is correct but tangled.** A clean rewrite should have explicit `delete-unrepresented-term TERM` that does the cleanup atomically, and reserve `reset-unrepresented-term-index TERM NEW-IDX` for the index-replacement case only.
- **Strings and numbers as terms are a CycL design choice worth examining.** Could the rewrite avoid this entirely by reifying every literal as a constant-with-no-name? Probably not — it would balloon the constant table — but the trade-off is worth considering. Currently strings and numbers occupy a special path through every layer of the indexing system; a different KB design might index them via a different mechanism (full-text, numeric-range index) better suited to their data.
- **The `indexed-unrepresented-term-p` predicate is identical to `cycl-unrepresented-term-p`** in the port. This means *every* string or number that appears in an assertion gets indexed. A clean rewrite could be more selective: only index unrepresented terms that appear in arg positions where indexing is helpful, and bypass the SUID/index machinery for terms that only appear as constant arguments to math predicates. The current "index everything" policy is wasteful.
- **`kb-unrepresented-term-p OBJECT` returns the SUID instead of `t`** — `(and (indexed-unrepresented-term-p object) (unrepresented-term-suid object))` returns the SUID if both are true. This is a SubL "non-nil is truthy" idiom; rename for clarity (`unrepresented-term-suid-or-nil`?) since the function name suggests a boolean.
- **The `register-unrepresented-term-suid` / `id-index-enter` + hash put pattern is racy** without synchronization. If multiple threads can hit `find-or-create-unrepresented-term-suid` for the same term, two SUIDs may be minted and only one wins the hashtable race. A clean rewrite needs a lock or a CAS-based id-index.
