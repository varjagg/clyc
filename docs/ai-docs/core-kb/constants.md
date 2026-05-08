# Constants

A **constant** is the atomic vocabulary unit of CycL. Every named term in the KB — predicates, collections, individuals, microtheories, function symbols — is a constant. Constants live in a single flat global namespace and are identified by **GUID** externally and **SUID** internally.

In source text constants are written as `#$Foo`. The `#$` reader macro intern-or-creates a constant *shell* by name. Constants are reference-equal singletons: any two references to `#$Dog` resolve to the same struct instance, regardless of where in the codebase they were read.

## Data structure

```
(defstruct (constant (:conc-name "C-"))
  suid    ; integer | nil. nil means "shell, not yet installed in the KB"
  name)   ; string | :unnamed | nil
```

That's the whole struct. Everything else about a constant lives in side tables, looked up by SUID. This is deliberate — constants are passed around by reference everywhere in the inference engine, and the per-constant struct is kept small so the wide-fanout indexing tables aren't bloated.

## Lifecycle

A constant has two semantically distinct lifecycle states — **shell** and **installed** — separated by a single transition called *installation*. The struct is never reallocated; what changes are which side tables it appears in.

### State summary

| State | `suid` | `name` | `*invalid-constants*` | `*constant-from-suid*` | `*constant-from-guid*` | bookkeeping GAFs |
|---|---|---|---|---|---|---|
| **Bare shell** (named) | `nil` | string | yes (by name) | no | no | none |
| **Anonymous shell** | `nil` | `nil` | no | no | no | none |
| **Installed** | integer | string \| `:unnamed` | no | yes | yes | yes (when bookkeeping is on) |
| **Freed** | `nil` | (untouched) | no | no | no | (cascade-removed) |

`valid-constant-handle?` ≡ `(integerp (c-suid c))`. The check is intentionally cheap: SUID either is or isn't an integer; nothing else matters.

### Shell birth

A shell — a constant struct with a name but no SUID and no GUID — exists in exactly one situation: **a name has been mentioned but has not yet been installed in the KB**. In practice this happens when:

- The Lisp reader sees `#$Foo` and `find-constant "Foo"` returns nothing. The reader produces a shell so source code can hold an identity-stable reference even before the KB is loaded.
- Application code calls `make-constant-shell name :use-existing? t` and the name is unknown.
- A bootstrap or test path explicitly constructs an unnamed placeholder via `create-sample-invalid-constant` (e.g. `*sample-invalid-constant*` returned for unknown CFASL handles).

Shells are interned by name in `*invalid-constants*` (a `name → struct` hashtable). This existence is the entire reason the registry is there: without it, two pre-load references to the same name would resolve to two different structs after install, and identity would break. The user has flagged this registry for elimination — a clean rewrite can fold it into the same canonical name-keyed registry that holds installed constants, with the install state encoded in the struct's SUID slot alone.

### Installation — a single moment that binds SUID, GUID, and (optionally) bookkeeping

Installation is the moment a shell becomes a fully-functional KB constant. It happens atomically: SUID gets allocated and bound, GUID gets bound and indexed, the constant gets removed from `*invalid-constants*` and added to the SUID table, and the completion trie is updated. Two situations trigger installation:

1. **A new constant is being created in this image.** Reached through `create-constant`, `cyc-create*`, `fi-create-int`, `ke-create-now`, or any of the other public creators. The creator either supplies an external-id (the cross-image case — see below) or doesn't, in which case a **fresh GUID is minted** at this moment via `new-guid`.

2. **A KB is being loaded from disk.** `load-constant-shell-internal` reads `(dump-id, name, guid)` triples off the CFASL stream and calls the same install path. **No GUID is minted** — the GUID came off the dump. The dump-id is replayed as the SUID via `*constant-dump-id-table*`.

Both paths converge on the same code (`kb-create-constant-int` → `install-constant-external-id` → `install-constant-guid` → `register-constant-guid`), so the side-table state after installation is identical regardless of how the constant got there.

`install-constant-guid` is idempotent — if the constant already has a GUID, the second install is a no-op — so re-installation paths during merge, reload, or duplicate-create are safe.

### When a fresh GUID is minted

The "mint a new GUID" event happens in only one circumstance: **a brand-new constant is being installed locally, and no caller in the chain has supplied an external-id**. The minting happens at the moment of installation, immediately before the side tables are written.

Concretely, this covers:

- A user calling `create-constant name` with no second argument.
- A user calling `cyc-create-new-ephemeral name` (which explicitly does not synchronize across images).
- The FI-layer `fi-create-int name` falling back to a fresh GUID because the caller didn't pass one and the name didn't already exist as an installed constant.
- The KE-layer `ke-create-now` doing the same; the resulting GUID then gets recorded in the transcript queue so other images can replay the same create with that exact GUID.

Every other installation path *adopts* a GUID rather than minting one:

- KB load: GUID came from the dump.
- Cross-image transfer / transcript replay: GUID was supplied by the sender.
- Re-installing a previously known constant (e.g. after an unload): GUID was preserved.
- Constant merge: no new GUID; the absorbed constant's GUID is preserved separately in `*constant-merged-guid-table*` so dump material that referenced the old GUID still resolves.

### Identifier spaces

Constants carry **two** stable identifiers, plus the optional *merged GUIDs* that record absorbed identities:

- **GUID** — globally unique, 128 bits, stable across images and dumps. The canonical cross-image identity. Appears in `.cfasl` files. There is also a vestigial **legacy GUID** form (any `integerp`, predicated by `constant-legacy-id-p`) used by some pre-2009 assertion dumps; the legacy lookup path is `missing-larkc 31626`.
- **SUID** — per-image small integer, monotonically allocated by `make-constant-suid` (a counter wrapped by `id-index`). The internal table-index for everything that needs per-constant storage. **Not portable**: a fresh SUID is allocated on every install in every image, so the same constant has a different SUID in every running Cyc.
- **Merged GUIDs** — when two constants are coalesced (see [Merge](#merge)), the loser's GUID is preserved in `*constant-merged-guid-table*` so old dumped material that referenced the absorbed identity still resolves to the survivor.

Within an image SUID is the working identifier; GUID is the cross-image one.

### What the SUID is actually used for

The SUID has nine distinct jobs that have all been collapsed into one slot. They're worth separating because most of them aren't *intrinsic* to the SUID and a clean rewrite can pick which to keep.

1. **Side-table key.** Every per-constant side table that the struct doesn't carry — `*constant-guid-table*`, `*constant-merged-guid-table*`, `*constant-index-manager*` — is keyed by SUID. This is the dominant use.

2. **Iteration domain.** `do-constants` and `do-id-index` walk `*constant-from-suid*` from 0 upward; the SUID space *is* the enumeration of "every constant in the image". There is no other "all constants" mechanism.

3. **CFASL handle for in-image transport.** When two CFASL endpoints share an image (server + cloned client), constants travel by SUID rather than GUID — cheaper than a 16-byte GUID per constant. The recipe (GUID) encoding is the cross-image fallback only.

4. **Dump-id.** A dumped `.cfasl` file encodes each constant by the SUID it had in the dumping image. On load, those dump-ids are remapped to freshly-allocated SUIDs in the loading image via `*constant-dump-id-table*`. Conceptually a dump-id is just "a SUID from a previous image" using the same handle protocol as live transport.

5. **Cross-image KB-comparison key.** `kb-compare.lisp` indexes the constant intersection of two images by `(local-internal-id, remote-internal-id)` pairs. Without integer handles, the index machinery has nothing to key on.

6. **Generic KB-handle resolver entry.** `register-find-object-by-kb-handle-method :constant 'find-constant-by-internal-id` wires up the system-wide `(:type id)` resolution path — anywhere a generic KB-handle pair is resolved, `:constant` routes to SUID lookup.

7. **`fort-id-index` user-side data.** Application code that wants its own per-FORT data structure uses `fort-id-index` (a struct of two id-indexes — constants by SUID, NARTs by id). This is the official "associate arbitrary data with a FORT" pattern. SUID is the key for the constant half.

8. **Identity hash.** `(defmethod sxhash ((obj constant)) suid)`. With identity-singleton constants, an `eq` hashtable would work without this, but `equal`/`equalp` hashtables need a numeric hash and SUID is the obvious one.

9. **Install-state marker.** `valid-constant-handle?` ≡ `(integerp (c-suid c))`. The slot does double duty: SUID and "this constant is installed". A `nil` SUID means shell.

Of these nine, only **(3) and (4)** require an integer handle as a *necessary* property; all the rest are conveniences that fall out of having one. Side tables (1) collapse to struct slots if you put the GUID and assertion-index there directly. Iteration (2) becomes a walk over the canonical name-keyed registry. Cross-image comparison (5) and the generic handle resolver (6) are reframings of the same dump-handle role as (3) and (4). User-side fort-id-index (7) becomes `(make-hash-table :test 'eq)` keyed on the constant struct directly. Identity hash (8) is irrelevant if you use `eq` hashtables on identity-singleton constants. Install-state (9) is a one-bit boolean that wants its own slot.

So the *necessary* role of the SUID is: a small integer used in serialization transport (CFASL handle and dump-id, which are the same thing). A clean rewrite has three sensible options:

- **Allocate lazily on first serialization** and store in a struct slot. Reused per-session by both endpoints. No global SUID counter; no install-time allocation.
- **Drop SUID entirely; use GUID as the on-the-wire identifier always.** One extra hashtable lookup per constant per receive — negligible. No handle bookkeeping at all.
- **Confine integer handles to the dump format.** The dump file numbers its constants 0..N for compactness; the loader builds the dump-id → constant map. The running image never assigns SUIDs.

The current design has SUIDs everywhere because it had them at all — once you have a per-constant integer, indexing by it is easier than indexing by anything else. A clean rewrite without that choice ends up with much less SUID infrastructure.

### Side tables populated at installation

| Table | Direction | Populated by | Purpose |
|---|---|---|---|
| `*constant-from-suid*` | SUID → struct | `register-constant-suid` (during install) | the SUID lookup |
| `*constant-from-guid*` | GUID → struct | `register-constant-guid` (during install) | GUID lookup; cross-image and CFASL-recipe path |
| `*constant-guid-table*` | SUID → GUID | `register-constant-guid` (during install) | reverse: get an installed constant's GUID |
| `*constant-merged-guid-table*` | SUID → previously-merged GUID | merge operation | preserves identity continuity through merges |
| `*constant-index-manager*` | SUID → assertion-index | LRU-fronted; first touch | per-constant assertion index |
| (completion trie) | name → struct | `add-constant-to-completions` (during install) | prefix completion |

Every table on this list is populated by the same install moment, except the LRU-fronted assertion-index manager, which is populated lazily on first index touch.

### These tables are *not* reflected as KB facts

The GUID is metadata about a constant maintained **outside** the assertion store. There is no `(#$constantID #$Foo "bd58dd96-…")` GAF anywhere in the KB. The reasoning is structural: looking up a constant by GUID requires knowing the constant first, but a fact predicated on the constant cannot exist before the constant exists. Holding the mapping in a side table breaks the circularity. The GUID participates in CFASL serialization (constant-recipe encoding), and in the on-disk KB dump format (per-shell `dump-id name guid` triple), but never in the assertion store.

### Bookkeeping — the parallel facts-based metadata

What *does* land in the assertion store at constant-creation time is **bookkeeping**. When `*bookkeeping-enabled?*` is non-nil and a `*cyc-bookkeeping-info*` plist is bound (typically by `with-bookkeeping-info` or `ke-create-now` populating cyclist + date + purpose + second), `perform-constant-bookkeeping` asserts up to four GAFs in `#$BookkeepingMt`:

```
(#$myCreator         constant cyclist)
(#$myCreationTime    constant date)
(#$myCreationPurpose constant purpose)
(#$myCreationSecond  constant second)
```

So the KB knows *who* created `#$Foo`, *when*, and *why* — but it does not know *which GUID* it has. Identity stays in side tables; provenance stays in the KB. A clean rewrite should preserve this separation: identity is never an assertion.

### Removal and freeing

`remove-constant` walks every side table touched at install time (and several others — see "Removal" below), then `free-constant` clears the SUID slot. The struct itself is left around: any caller still holding a reference now sees an *invalid* constant, and code that traverses long-lived collections is expected to filter with `valid-constant?`.

A clean rewrite should make removal transactional rather than a sequence of side-table updates that can leave dangling references mid-removal.

## Lookups

Both directions, both ID spaces:

| From | To | Function |
|---|---|---|
| SUID | constant | `find-constant-by-internal-id` / `find-constant-by-suid` / `lookup-constant-by-suid` |
| GUID | constant | `find-constant-by-external-id` / `find-constant-by-guid` / `lookup-constant-by-guid` |
| name | constant | `find-constant` / `kb-lookup-constant-by-name` (consults `constant-shell-from-name` then `*invalid-constants*`) |
| dump-id | constant | `find-constant-by-dump-id` (during KB load) |
| constant | SUID | `constant-suid` / `constant-internal-id` |
| constant | GUID | `constant-guid` / `constant-external-id` |
| constant | name | `constant-name` / `kb-constant-name` |
| constant | merged GUID | `constant-merged-guid` |

`find-*` is the public/Cyc-API surface; `kb-*` is the layer that gates remote vs. local access (`hl-access-remote?`); `lookup-*` is the raw table call.

## Naming

A valid constant name (`valid-constant-name-p`):
- string of length ≥ 2
- only `alphanumericp`, `-`, `_`, `:` characters

The `:` is allowed because some constants carry namespace prefixes (e.g. `Foo:Bar`); see `constant-namespace` and `constant-name-within-namespace`.

`constant-name-spec-p` ≡ a valid name string **or** the keyword `:unnamed`. `:unnamed` is how unnamed constants are constructed: `(kb-create-constant :unnamed external-id)` produces a constant with no name (only a GUID).

By convention, names are CamelCase, predicates and relations start lowercase, function constants get the `Fn` suffix, microtheories the `Mt` or `PSC` suffix. None of this is enforced — it's social convention.

`*require-case-insensitive-name-uniqueness*` (default `t`) means the system rejects names that collide case-insensitively with existing names. `constant-name-case-collisions` reports collisions for tooling.

### Renaming

`rename-constant` / `kb-rename-constant` updates the name in place: removes the old name from completions and from `*invalid-constants*`, sets the new name, re-adds to completions and `*invalid-constants*`. The constant struct, SUID, and GUID are unchanged. So callers holding references see no break.

## Public API (constants-high.lisp)

These are the entry points other code is meant to call. Stripped of LarKC bureaucracy:

```
(create-constant name &optional external-id)        ; new constant + new GUID
(find-or-create-constant name &optional external-id); upsert by name
(gentemp-constant start-name &optional prefix)      ; auto-named temp constant
(remove-constant constant)                          ; full KB-aware removal
(find-constant name)                                ; name → constant-or-nil
(constant-name constant)                            ; constant → name
(rename-constant constant new-name)
(constant-internal-id constant)                     ; → SUID
(find-constant-by-internal-id id)                   ; SUID → constant
(constant-external-id constant)                     ; → GUID
(find-constant-by-external-id external-id)          ; GUID → constant
(constant-info-from-guid-strings list)              ; bulk lookup helper
(random-constant &optional test)
(installed-constant-p object) / (uninstalled-constant-p object)
(constant-p object) / (valid-constant? constant)
(do-constants (var ...) body)                       ; iterate all constants
```

The `kb-*` family in `constants-interface.lisp` is one layer below: same operations but explicitly distinguishing local-vs-remote KB store access. In a single-image rewrite these collapse into the high-level versions.

## Removal

`remove-constant` is more than "drop from a table". It cascades:

1. Mark `*forts-being-removed*` so re-entrancy detects the in-progress removal.
2. Reject if the constant is a reified Skolem function in any MT (currently `missing-larkc`).
3. `remove-dependent-narts` — every NART whose NAUT references this constant is killed.
4. `unassert-all-bookkeeping-gafs-on-term` — drop bookkeeping (creator, creation date, comments).
5. `remove-term-indices` — drop the term's indexing (assertion index, GAF/rule indices, inverse uses).
6. `tms-remove-kb-hl-supports-mentioning-term` — invalidate justifications that mention it.
7. `clear-cardinality-estimates`.
8. `kb-remove-constant` → deregister GUID, deregister SUID, free the struct.

Anything that holds a constant reference past removal will see an *invalid* constant (struct still exists, SUID `nil`). Code that walks long-lived collections of FORTs is expected to filter with `valid-constant?`.

## Merge

Merging coalesces two distinct constants into a single identity. The KB ends with one surviving constant; old references to the absorbed constant continue to resolve to the survivor through the merged-GUID redirect.

> The merge entry points (`cyc-merge`, `fi-merge`, and the supporting machinery listed at the end of this section) appear in the port as commented-out `declareFunction`s — the symbols are present but the bodies were not part of the LarKC release. Merge is real Cyc engine functionality, however, and a clean rewrite must implement it. The semantics below are reconstructed from the function names, the surrounding evidence (`*constant-merged-guid-table*` and its readers exist; bookkeeping anticipates merge events), and Cyc's documented behavior.

### When does merge happen?

Merge is a **curatorial decision**, not an automatic response to a name collision. Two constants with the same name **cannot co-exist** in a single running image — shell interning prevents it (see [Lifecycle](#lifecycle)). Two constants with the same GUID also cannot co-exist — `kb-create-constant-kb-store` checks GUID first and returns the existing constant. Merge is for the situation where two **distinct** constants — usually different names, always different GUIDs — turn out to refer to the same concept and a curator decides to unify them.

Triggering situations:

- **Discovered duplicates.** Two constants developed independently turn out to mean the same thing (e.g. `#$AppleFruit` and `#$Apple-TheFruit`).
- **KB merge / cross-image consolidation.** Loading a KB fragment from another image introduces conceptually-duplicate constants under different GUIDs that need unifying with local equivalents.
- **`equals` promotion.** Constants tracked as `(#$equals C1 C2)` are promoted from logical equivalence to identity, so the cost of equality reasoning is paid once, in a structural rewrite, instead of forever, in inference.
- **Skolem cleanup.** Skolems introduced by separate inferences turn out to refer to the same individual.
- **Rename-into-existing.** A rename whose target name already exists is rejected (`kb-rename-constant-internal` errors); the curator may resolve by merging the source into the existing target instead.
- **Case-collision repair.** `*require-case-insensitive-name-uniqueness*` and `constant-name-case-collisions` surface names differing only by case (`#$Apple` vs `#$apple`); the resolution is rename or merge.

What does **not** trigger a merge:

- Same-name same-image — prevented by shell interning, never reaches merge.
- Same-GUID same-image — prevented by GUID-first creation lookup, never reaches merge.
- An `(#$equals C1 C2)` assertion alone — that's a *logical* equivalence the engine reasons over; merge is the *identity* coalescence the curator chooses.
- Automatic deduplication — the engine doesn't merge unless told to.

### What merge does

Merge picks a winner (`keep-fort`) and a loser (`kill-fort`) and rewrites every reference to the loser to point at the winner.

1. **Assertion rewrite.** Every assertion mentioning the loser is rewritten to mention the winner. The engine builds an assertion-map by walking the loser's assertion index (via `make-merge-fort-assertion-map`), then substitutes positionally (`substitute-assertion`, `substitute-asserted-argument`, `substitute-dependents`, `substitute-dependent-assertion`). Each old-assertion → new-assertion mapping is recorded (`add-merge-fort-assertion-mapping`) so dependent justifications can be redirected to the new IDs.

2. **NART consolidation.** Every NART whose NAUT mentions the loser is rebuilt with the winner substituted in (`merge-dependent-narts`). If the rewritten NAUT collides with an existing NART, the loser's NART itself becomes a sub-merge target — sub-merges cascade. The TOU assertions `(#$termOfUnit nart naut)` are rewritten alongside the rest of the assertion store (`substitute-termofunit-assertion`).

3. **Support redirection.** Every KB-HL-support that mentioned the loser is rewritten via `merge-dependent-kb-hl-supports`; deductions backed by those supports get their justification structures updated (`substitute-deduction`).

4. **`equals` cleanup.** Pre-existing `(#$equals winner loser)` assertions become trivially true and are typically pruned during merge.

5. **GUID redirect.** The loser's *current* GUID is moved into `*constant-merged-guid-table*` keyed by the **winner's** SUID. Future `lookup-constant-by-guid` calls on the loser's GUID resolve via this side path to the winner. This is the mechanism that keeps old serialized material valid: a dump produced before the merge that referenced the loser by GUID is still readable, and on read produces the winner.

6. **Loser teardown.** The loser is removed from `*constant-from-suid*`, removed from `*constant-from-guid*` (its current GUID is now in the merged table, not the primary GUID-to-constant map), removed from the completion trie, and freed (`suid` set to `nil`). The struct dangles invalid; in-flight references see invalid state.

7. **Audit trail.** A bookkeeping GAF (typically `(#$cycMergedFrom winner loser-guid)` in `#$BookkeepingMt`) records the merge so it's traceable. The loser's bookkeeping (`#$myCreator`/etc.) is not preserved on the winner; the winner keeps its own.

### Effect on identity

After merge:

- **Name** — the winner's name is canonical; the loser's name is gone. Tools watching the loser's name find nothing; the completion trie no longer offers it.
- **Current GUID** — the winner's GUID is unchanged. The loser's GUID is no longer a primary identity; it resolves to the winner via the merged-GUID side table.
- **Merged-GUID list** — the winner accumulates the loser's GUID, plus any GUIDs the loser had previously absorbed (merge is transitive across the merged-GUID list).
- **Cross-image dumps** — a dump produced before the merge that referenced either GUID still resolves correctly: the winner's GUID directly, the loser's via the merged table on the receiving side.
- **Assertions** — there is no syntactic trace of the loser in the assertion store; every reference has been rewritten.
- **Deductions** — justifications that depended on the loser's assertions now depend on the rewritten assertions; the proof trees are structurally preserved.

### Files

`fi.lisp` is the merge home. The relevant entry points and helpers (all commented `declareFunction` in the port; bodies in real Cyc):

`cyc-merge`, `fi-merge`, `fi-merge-int`, `merge-fort-recursive`, `merge-dependent-narts`, `merge-dependent-kb-hl-supports`, `substitute-assertion`, `substitute-asserted-argument`, `substitute-deduction`, `substitute-dependents`, `substitute-dependent-assertion`, `substitute-termofunit-assertion`, `make-merge-fort-assertion-map`, `merge-fort-assertion-map-valid?`, `add-merge-fort-assertion-mapping`, `get-merge-fort-assertion-mapping`.

`*constant-merged-guid-table*` (in `constants-low.lisp`) and its accessor `lookup-constant-merged-guid` are present in the port and serialize correctly; they're the persistent half of the merge story that survives in dumps.

## Setup, finalize, clear

The lifecycle hooks called by KB load/init code:

```
(setup-constant-tables size exact?)     ; allocates *constant-from-suid*, *constant-from-guid*, index manager
(finalize-constants &optional max-suid) ; sets next-id, optimizes id-index
(clear-constant-tables)                 ; drops everything (image reset)
```

`size` is a hint (initial id-index capacity); `exact?` controls whether to force the LRU caches to the exact size or treat it as a starting hint.

## Per-constant indexing (constant-index-manager)

Every installed constant has an associated **constant-index** — the per-term assertion index pointing at every assertion that mentions it. Indexes are large and many constants are never touched during a query, so they're stored in a `kb-object-manager`: an LRU-fronted swap cache backed by a file-vector. This file's whole job is to make that swap-in transparent.

```
*constant-index-manager*                     ; the manager singleton
*permanently-cached-constant-indices*        ; #$isa, #$genls — never swapped out
(lookup-constant-index id)                   ; SUID → index, swapping in if needed
(register-constant-index id index)
(deregister-constant-index id)
(mark-constant-index-as-permanently-cached id)
(swap-out-all-pristine-constant-indices)     ; reclaim memory after a snapshot
(initialize-constant-index-hl-store-cache)   ; wires up "indices"/"indices-index" file-vector pair
```

LRU sizing is `*constant-index-lru-size-percentage*` (default 16, "based on arete experiments"). For a clean rewrite this whole layer is optional — if everything fits in RAM, a plain hash on SUID does the job.

## Completion (tries)

Constant names are interned in a character-trie (`tries.lisp`) so that prefix-complete operations are fast. The completion store is built up incrementally by `add-constant-to-completions` / `remove-constant-from-completions`. Public API is in `constant-completion-high.lisp`:

```
(constant-complete prefix &optional case-sensitive? exact-length? start end)
(constant-complete-exact string &optional start end)
(valid-constant-name-p string)
(valid-constant-name-char-p char)
(constant-name-spec-p object)               ; name string or :unnamed
(constant-name-case-collisions string)
```

The trie is also seeded by `initialize-constant-names-in-code` with every name that appeared in source via `#$`, so prefix-completion works before the KB has been loaded.

## CFASL serialization

See [cfasl.md](../persistence/cfasl.md) for the broader protocol. A constant has two encodings:

| Opcode | Mode | Payload | Read function |
|---|---|---|---|
| `*cfasl-opcode-constant*` (30) | handle (in-image only) | SUID | `cfasl-input-constant` |
| `*cfasl-opcode-constant*` (30) under `*within-cfasl-externalization*` | recipe (cross-image) | GUID | `cfasl-input-constant` → `cfasl-input-constant-recipe` |
| `*cfasl-opcode-complete-constant*` (32) | recipe + name | GUID, then name string (ignored) | `cfasl-input-complete-constant` |

On output, `cfasl-output-constant` picks the encoding by inspecting `*within-complete-cfasl-objects*` and `*within-cfasl-externalization*`. `*cfasl-externalized-constant-exceptions*` lets specific constants opt out of recipe-encoding back to handle-encoding (e.g. for transcripts where the receiver is known to share the SUID space).

On input, an unknown SUID/GUID resolves to `*sample-invalid-constant*` rather than signaling. The user has flagged this as wrong — a clean rewrite should signal a condition instead.

The handle-lookup is dispatched through `*cfasl-constant-handle-lookup-func*`:

| Value | Use |
|---|---|
| `nil` or `'find-constant-by-internal-id` | normal in-image |
| `'find-constant-by-dump-id` | KB load — dump-ids may not equal current SUIDs, so we go through `*constant-dump-id-table*` |
| any other function | custom transport (e.g. transcript replay) |

The `with-constant-dump-id-table` macro binds this for the duration of a KB load.

## Cyc API surface

Functions registered via `register-cyc-api-function` (so they're callable over the CFASL API protocol):

`constant-count`, `constant-p`, `valid-constant?`, `valid-constant-name-p`, `create-constant`, `find-or-create-constant`, `gentemp-constant`, `remove-constant`, `find-constant`, `constant-name`, `rename-constant`, `constant-internal-id`, `find-constant-by-internal-id`, `constant-external-id`, `find-constant-by-external-id`, `constant-info-from-guid-strings`, `constant-info-from-name-strings`, `constant-namespace`, `constant-name-within-namespace`, `random-constant`, `kb-create-constant`, `kb-remove-constant`, `kb-lookup-constant-by-name`, `kb-constant-name`, `kb-lookup-constant-by-guid`, `kb-constant-guid`, `kb-constant-merged-guid`, `kb-rename-constant`, `do-constants` (macro).

Obsolete-registered (back-compat aliases): `valid-constant` → `valid-constant?`, `valid-constant-name` → `valid-constant-name-p`.

## Files

| File | Role |
|---|---|
| `constant-handles.lisp` | struct, SUID table, shell registry, `valid-constant-handle?` |
| `constants-low.lisp` | GUID table, GUID install/deregister, `kb-create-constant-kb-store` |
| `constants-high.lisp` | public API: `create-constant`, `find-constant`, `constant-name`, etc. |
| `constants-interface.lisp` | `kb-*` layer (local vs. remote dispatch) |
| `constant-index-manager.lisp` | LRU-fronted per-constant assertion index store |
| `constant-completion.lisp` | `*constant-names-in-code*` seed list |
| `constant-completion-high.lisp` | name validation, public completion API |
| `constant-completion-interface.lisp`, `constant-completion-low.lisp` | trie integration |
| `constant-reader.lisp` | `#$` reader macro + `make-constant-shell` glue |

## Notes for a clean rewrite

> Reminder: the rewrite targets full Cyc semantics, not the LarKC subset that the port reflects. Functionality marked `missing-larkc` in the port is real engine behavior the rewrite must support — most notably merge. Port-only artifacts (e.g. handler dispatch through global vars, pre-allocated method tables, externalize/handle-mode special-var threading) are LarKC's particular implementation choices, not Cyc's required semantics, and don't need to be preserved.

**Identity model**

- Decide what to do with the SUID first; the rest follows. See "What the SUID is actually used for" above. The minimal rewrite eliminates the SUID counter, install-time SUID allocation, and SUID-keyed side tables, retaining at most a per-session integer handle assigned lazily for CFASL transport.
- If SUIDs are dropped or made transport-only, GUID becomes a struct slot, the assertion-index becomes a struct slot (or hashtable keyed on the constant struct), and `*constant-from-suid*` disappears in favor of `*constant-from-name*` or a name-keyed registry as the iteration backbone.
- Collapse `*constant-from-suid*` and `*invalid-constants*` (string→shell) into a single canonical name-keyed registry. The shell/install distinction can be encoded in a one-bit `installed?` slot.
- Name is enforced as unique within an image, but only by silent shell interning. The rewrite should make this enforcement **explicit**: a chokepoint that signals on duplicate-name create rather than silently returning the existing constant or burning an unused identifier. Distinguish the two distinct user intents — "give me the constant called X (find-or-create)" and "create a new constant called X (error on collision)" — at the API surface, instead of conflating them.

**Merge is required**

- Implement merge. It is not optional. A KB without merge cannot consolidate duplicates, cross-image-merge, or promote `equals` to identity — all standard knowledge-engineering operations. See [Merge](#merge) for the semantics.
- A clean rewrite should treat merge as a **transactional graph rewrite** rather than the sequence-of-side-table-updates the port hints at: build the rewrite plan (assertion map, NART map, support redirects, GUID redirect), validate it, then apply atomically. Half-applied merge is unrecoverable.
- The merged-GUID redirect can be a list-valued slot on the survivor or a sparse side table keyed on the survivor's identity (only merged constants need an entry). Either is fine; the port's id-index is overkill given that merges are rare.
- Merge transitivity matters: if A is merged into B, then B is merged into C, A's GUID must redirect to C, not to the now-defunct B. The rewrite should flatten merged-GUID lists at merge time so resolution is one hop.
- Bookkeeping the merge (`#$cycMergedFrom` or equivalent) is required for audit; without it, a curator looking at the survivor has no record of what was absorbed or when.

**Identifier discipline**

- GUID is identity, never an assertion. Preserve the side-table-vs-KB-fact split — facts about identity create circular bootstrap problems. Bookkeeping (`#$myCreator`, `#$myCreationTime`, etc.) is the right shape for identity-adjacent facts.
- Legacy GUID handling (`constant-legacy-id-p`) is dead-weight from pre-2009 dumps; drop unless you're loading those specific archives.
- GUID storage as a 16-byte vector via `equalp` hash is fine, but a structured GUID type with a stable hash and a printer that emits the canonical hex form is cleaner.

**API surface**

- The two-layer `kb-*` vs. high-level API is overhead from the local/remote KB-store split that Cyc historically supported. Single-image: drop one layer. Most `kb-X` functions are 1:1 wrappers over `X`.
- Multiple obsolete-aliased function pairs (`valid-constant` ↔ `valid-constant?`, `find-or-create-nart` ↔ `hl-find-or-create-nart` ↔ `cyc-find-or-create-nart`). Pick one each.

**Storage**

- The constant-index LRU is only meaningful with disk-backed indices. If RAM is sufficient (which is the case for OpenCyc-scale KBs on modern machines), replace `lookup-constant-index` with a direct hash lookup and drop the manager entirely. Re-introduce LRU only if Cyc-scale KBs are ever back in scope.
- The `*permanently-cached-constant-indices*` pin list (currently `#$isa`, `#$genls`) is irrelevant once the LRU is gone.

**Transactional concerns**

- Removal cascades through several side tables (assertions, NARTs, indices, supports, cardinality estimates, then the GUID/SUID tables, then the struct slot reset). Make removal a single transactional path so partial failure doesn't leave dangling references.
- Install is similarly a sequence (allocate SUID → register SUID → install GUID → register GUID → add to completion trie → optionally bookkeep). Install can be made transactional cheaply; the lock is already there (`*hl-lock*`).

**CFASL handling**

- Replace `*sample-invalid-constant*` and the other `*sample-invalid-T*` placeholders with a signaled condition on unknown handle. The current return-a-placeholder approach pushes "is this real?" checks to every consumer.
- The dump-id remapping pattern (a load-time map from dump-handle → live-object) generalizes across all KB types. Make it a property of the loader, not a special var threaded through every input function.
