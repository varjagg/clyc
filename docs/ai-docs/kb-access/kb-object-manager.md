# KB object manager and access metering

A **kb-object-manager** is the LRU swap layer that lets the engine treat KB content (assertion content structs, NART HL formulas, deduction content, kb-hl-support content, indexing data) as if it were always in memory while actually paging in only the working set from an on-disk file-vector. Every per-type "content table" in the KB — assertion content, deduction content, kb-hl-support content, constant indexing, NART indexing, NART HL formulas, unrepresented-term indexing, SBHL module graph links — is a kb-object-manager.

This file is the *generic* object-manager. The per-type managers (`*assertion-content-manager*`, `*kb-hl-support-content-manager*`, etc.) are instances of this struct, parameterized by name, sizing, LRU percentage, and a per-type load-func.

The companion file **kb-access-metering** is an instrumentation layer that records which KB objects were accessed during a measured scope (typically an inference query), so callers can post-process the metering table to learn what was hot.

## When does the object manager engage?

Always running, but events trigger work:

1. **A KB object is referenced by ID.** `lookup-kb-object-content kbom id` is the universal getter. Three cases:
   - Object is in the in-memory `content-table`: return it, update LRU + usage counts.
   - Object isn't in `content-table` but its ID is below `id-threshold` (i.e. came from the on-disk file-vector at load time): swap it in via `swap-in-kb-object-content`, return it.
   - Object isn't in `content-table` and ID is above `id-threshold` (newly created in this session): return nil.

2. **An object is created.** `register-kb-object-content kbom id content` enters the new content into the `content-table` under the given ID. New IDs are above `id-threshold`, so they're never swapped to disk (they're "dirty" relative to the on-disk file).

3. **An object is removed.** `deregister-kb-object-content kbom id` removes from `content-table`, drops from LRU and usage tables.

4. **An LRU eviction fires.** When `swap-in` adds an entry that exceeds the LRU cap, `cache-set-return-dropped` returns the loser ID; `swap-out-pristine-kb-object-content` removes the loser from the in-memory `content-table`. The data is preserved on disk (it's a *pristine* swap-out — the in-memory copy hasn't been mutated since load), so future accesses re-read from the file.

5. **An object is mutated.** `mark-kb-object-content-as-muted kbom id` removes the ID from the LRU information so it can never be evicted as pristine. Now the in-memory copy is canonical; on save, the dirty copy is written back to disk.

6. **A KB save flushes pristine objects.** `swap-out-all-pristine-kb-objects-int kbom` walks the LRU and evicts every entry — frees memory before serialization. Objects that were marked muted (and thus aren't in the LRU) stay in memory and get written to disk by the dumper.

7. **The KB resets.** `clear-kb-object-content-table kbom` clears everything: usage table, LRU information, content table.

## Data structure

```lisp
(defstruct (kb-object-manager (:conc-name "KBOM-"))
  name                  ; e.g. "Assertion content"
  content-lock          ; bordeaux-threads lock
  lru-size-percentage   ; LRU is this percent of total table size
  content-table         ; id-index: id → content struct
  usage-table           ; id-index: id → access counter (optional)
  lru-information       ; cache: id → id (membership only — order is the cache state)
  file-vector           ; on-disk indexed CFASL store
  id-threshold          ; ids < threshold came from disk; ids ≥ threshold are runtime
  load-func             ; per-type loader (id → content)
  meter-swap-time?      ; collect timing data for swaps?
  swap-time             ; accumulator if meter is on
  dummy1 dummy2 dummy3) ; reserved
```

The lock guards every mutating operation on the content table. The LRU `cache` is a separate object (from `cache.lisp`) keyed by ID; its purpose is membership tracking, not value storage — when an ID is in the LRU, the **value** is fetched from the content-table. The cache size is `max(212, (table-size / 100) * lru-percentage)`.

## Constructor and setup

```
(new-kb-object-manager name size lru-size-percentage load-func exact-size?)
```

- `name`: string, used in lock name and progress messages.
- `size`: estimated total number of objects.
- `lru-size-percentage`: e.g. 5 means LRU holds 5% of total. `*kb-hl-support-content-manager*` uses 5; assertion content uses larger fractions; constant indexing larger still.
- `load-func`: `(load-func id stream)` — the per-type CFASL deserializer. For assertions, this is `load-assertion-content`. For NARTs, `load-nart-hl-formula`. For each kbom, exactly one.
- `exact-size?`: when t, allocate the underlying id-index in static space sized to exactly `size`. When nil, optimize-id-index will defer allocation until the table fills.

`setup-kb-object-content-support` is the inner setup — initializes the usage table (if requested) and the LRU cache. Re-entrant safe: only initializes if not already.

## File-vector binding

`initialize-kb-object-hl-store-cache kbom content-filename index-filename`:

- Closes any old file-vector.
- Constructs a new `file-vector` from the CFASL data file plus the offset-index file.
- Sets `id-threshold = (file-vector-length file-vector)` — every ID below this came from the on-disk file at load time and is swappable; every ID at or above this is runtime-allocated and lives only in memory.

The two filenames must be extensionless — `must-not (ends-with content-filename "cfasl")`. The `.cfasl` extension is appended internally via `get-hl-store-cache-filename`. This is so the same name can refer to multiple files (the data, the index, possibly other auxiliary files).

## Lookup path: `lookup-kb-object-content`

```
1. Hold content-lock.
2. content := id-index-lookup content-table id (uninitialized)
3. if content is uninitialized (i.e. ID isn't in content-table):
     if id is lru-cachable (i.e. id < id-threshold):
       swap-in-kb-object-content kbom id    ; populates content-table
       content := id-index-lookup content-table id
     else:
       content := nil                        ; no on-disk record exists
   else:
     update-kb-object-usage kbom id          ; bump LRU + usage count
4. Release lock; return content.
```

`is-lru-cachable-kb-object-content-id? kbom id` is `(< id (kb-object-manager-id-threshold kbom))`. Only on-disk-backed IDs are LRU-cacheable; new objects are always memory-resident.

## Swap path: `swap-in-kb-object-content`

```
1. Save & nil out *cfasl-<type>-handle-lookup-func* dynamic vars
   for constant, nart, assertion, deduction, kb-hl-support, clause-struc.
2. If meter-swap-time?, missing-larkc 32087 (timing wrapper).
3. Otherwise: swap-in-kb-object-content-internal kbom id.
4. Restore dynamics.
```

Step 1 is critical: during a swap, CFASL needs to **not** translate handles. The lookup funcs would otherwise call back into the very system trying to swap. Suppression by `let` binding to nil makes handles read as raw IDs, which is what the loader expects.

`swap-in-kb-object-content-internal`:

```
1. *cfasl-common-symbols* := (get-hl-store-caches-shared-symbols)  -- the agreed-upon
                                                                      symbol set for
                                                                      compact CFASL
2. position-file-vector kbom.file-vector id    -- seek into the data file at id's offset
3. cfasl-input stream → kb-object-id           -- the file's first cell is the id
4. assert (= kb-object-id id)                  -- consistency check
5. (load-func id stream)                       -- type-specific deserializer
                                                  populates content-table
6. increment-kb-object-usage-count
7. cache-set lru-information id id             -- mark as recently used; eviction returns
                                                  the loser
8. if loser is non-nil: swap-out-pristine-kb-object-content kbom loser
```

Step 5 is dispatched per type: the load-func writes the deserialized content struct into the content-table.

Step 8 is the eviction: when the LRU is full and a new entry arrives, the oldest entry's ID is returned. `swap-out-pristine-kb-object-content` removes that ID from the content-table, freeing the memory. Future accesses to that ID will swap-in again.

## Mutation path

When the in-memory content of an object is mutated (assertion arguments updated, kb-hl-support dependents changed, indexing changed), the caller calls `mark-kb-object-content-as-muted kbom id`. This **removes the ID from the LRU** (`cache-remove`), so eviction will never pick it as a loser. The dirty entry stays in `content-table` until `clear-kb-object-content-table` (KB reset) or explicit unloading.

The semantic: pristine objects (matching their on-disk form) are LRU-managed and may be evicted at any time. Dirty objects are pinned in memory and survive until the next save flushes them.

This is the full Read-LRU-with-write-back-pinning policy. There is no "write-through to file" — dirty pages stay in memory and are persisted via the KB save path, not via the LRU machinery.

## Pristine flush: `swap-out-all-pristine-kb-objects-int`

Called from KB save (`swap-out-all-pristine-kb-objects` in [kb-accessors.md](kb-accessors.md)) before serialization to free memory:

```
1. Walk LRU information, collect all IDs into pristine-ids list.
2. Sort ascending (sequential file-position is faster than scattered).
3. For each id with progress-message:
     cache-remove id
     swap-out-pristine-kb-object-content id
4. Return count.
```

Only pristine entries are flushed; dirty ones aren't in the LRU and stay. After the save completes, all IDs are pristine again and can be re-paged on demand.

## Usage counting

`*usage-table*` is an optional per-id counter recording how many times each object was accessed. Enabled per-kbom via `setup-kb-object-content-support kbom :initialize-usage-counts? t`. Used by:

- Cache analysis: which objects are hot? Tells the operator how to set LRU sizes per type.
- Heuristics: the planner could prefer assertions with high access count.

The counter is integer-valued and never decays — it's a cumulative session count.

`kb-object-usage-counts-enabled? kbom` — true iff usage table is an id-index (vs `:uninitialized`).

`increment-kb-object-usage-count kbom id` — usage_table[id]++. Called by `update-kb-object-usage` and by every LRU-promotion via `swap-in-kb-object-content-internal`.

## Public API surface

```
;; Constructor
(new-kb-object-manager name size lru-size-percentage load-func exact-size?)
(setup-kb-object-content-table kbom size exact?)
(setup-kb-object-content-support kbom &optional initialize-usage-counts? size)
(initialize-kb-object-hl-store-cache kbom content-filename index-filename)
(clear-kb-object-content-table kbom)

;; Predicates
(kb-object-manager-p obj)
(kb-object-content-file-vector-p obj)
(kb-object-usage-counts-enabled? kbom)
(kb-object-manager-unbuilt? kbom)
(is-lru-cachable-kb-object-content-id? kbom id)

;; Accessors (defstruct + inline)
(kbom-name k) (kbom-content-lock k) (kbom-lru-size-percentage k)
(kbom-content-table k) (kbom-usage-table k) (kbom-lru-information k)
(kbom-file-vector k) (kbom-id-threshold k) (kbom-load-func k)
(kbom-meter-swap-time? k) (kbom-swap-time k)

;; Lookup / mutation
(lookup-kb-object-content kbom id)
(register-kb-object-content kbom id content)
(deregister-kb-object-content kbom id)
(mark-kb-object-content-as-muted kbom id)
(update-kb-object-usage kbom id)
(drop-kb-object-usage kbom id)
(increment-kb-object-usage-count kbom id)
(cached-kb-object-count kbom)

;; File-vector
(new-kb-object-content-file-vector cfasl-file index-file)
(kb-object-content-file-vector-lookup kbom id)

;; Swap
(swap-in-kb-object-content kbom id)
(swap-in-kb-object-content-internal kbom id)
(swap-out-pristine-kb-object-content kbom loser)
(swap-out-all-pristine-kb-objects-int kbom)

;; Constants
(*min-kb-object-lru-size*)            ; 212
```

## Consumers

| Per-type kbom | Defined in | What it manages |
|---|---|---|
| `*assertion-content-manager*` | `assertion-manager.lisp` | Assertion content structs |
| `*deduction-content-manager*` | `deduction-manager.lisp` | Deduction content structs |
| `*kb-hl-support-content-manager*` | `kb-hl-support-manager.lisp` | kb-hl-support content structs |
| `*nart-hl-formula-manager*` | `nart-hl-formula-manager.lisp` | NART HL formulas |
| `*constant-index-manager*` | `constant-index-manager.lisp` | per-constant index structs |
| `*nart-index-manager*` | `nart-index-manager.lisp` | per-NART index structs |
| `*unrepresented-term-index-manager*` | `unrepresented-term-index-manager.lisp` | per-unrepresented-term index structs |
| (sbhl-module-graph manager) | `sbhl/sbhl-module-graphs.lisp` | SBHL graph links |

Each instance is a kbom. The per-type files implement the load-func, the file-naming convention, and a thin lookup layer (`lookup-assertion-content`, `lookup-deduction-content`, etc.) on top of `lookup-kb-object-content`.

## Notes for a clean rewrite — kb-object-manager

- **The split of "membership in LRU" vs "value lookup in content-table" is awkward.** The LRU cache stores `id → id` (a tautology), only because the `cache` abstraction was adopted as-is. A clean rewrite uses an LRU that stores nothing for value (just maintains order), or fuses the LRU with the content-table.
- **The `meter-swap-time?` path is missing-larkc.** Worth implementing — measuring the swap-time per object lets the operator tune LRU sizes empirically.
- **The dummy1/dummy2/dummy3 slots are reserved space** for unknown future use; remove unless the rewrite has a documented purpose.
- **The "pristine vs dirty" pinning policy is correct but ad-hoc.** `mark-kb-object-content-as-muted` removes the ID from the LRU; this is the entire dirty-pin mechanism. A cleaner design has an explicit `dirty-bit` slot in the content-table entry, with the LRU checking it before evicting.
- **`swap-in-kb-object-content` clears six `*cfasl-*-handle-lookup-func*` dynamic vars** to prevent re-entrant CFASL handle resolution. This is essential but invisible in the type signature. A modern design has an explicit "loading" flag on the kbom (or a `with-loading-context` macro) that clearly marks entry into a swap.
- **The id-threshold = file-vector-length convention** elegantly distinguishes on-disk IDs from runtime IDs by numeric value — every runtime ID is allocated above the threshold by the id-index. This works because id-allocation is monotonic per-type and the next-id watermark is set during KB load. Preserve the convention.
- **`*min-kb-object-lru-size*` = 212** is a magic constant. It's there to ensure even a tiny KB has a big enough LRU to hold the working set during, e.g., an inference query. A modern design may parameterize this per-type or compute it from machine memory.
- **The load-func parameterization is essentially a poor man's polymorphism.** A modern design has each type implement a `kb-object-protocol` interface and the manager dispatches via that. The single-function load-func is enough for now though.

## kb-access-metering

A small instrumentation file. Records which KB objects were accessed during a measured scope.

### Variables

```
*kb-access-metering-enabled?*    nil  -- master switch (defglobal)
*kb-access-metering-domains*     nil  -- which kinds to record (e.g. :assertion, :sbhl)
*kb-access-metering-table*       nil  -- the recorded access set
```

### `with-kb-access-metering`

```lisp
(with-kb-access-metering (result :domains '(:assertion :sbhl) :options ...)
  ...body...)
;; result is bound after body to the postprocessed metering table
```

The macro:

1. Binds `*kb-access-metering-domains*`, `*kb-access-metering-table*` for the body.
2. Allocates a fresh metering table via `new-kb-access-metering-table` (missing-larkc).
3. Runs body.
4. Postprocesses the table via `postprocess-kb-access-metering-table` (missing-larkc), writing the result to `result-var`.

### Notification hooks

Per-domain notify functions are inserted at access points throughout the engine:

| Hook | Domain | Inserted at |
|---|---|---|
| `possibly-note-kb-access-assertion` | `:assertion` | `lookup-assertion-content`, etc. |
| `possibly-note-kb-access-constant` | (constant) | (missing-larkc) |
| `possibly-note-kb-access-nart` | (nart) | (missing-larkc) |
| `possibly-note-kb-access-sbhl-link` (macro) | `:sbhl` | SBHL link traversal |

Each is gated by `*kb-access-metering-enabled?*` and the domain test, so it's a no-op when metering is off. The body inside the gate is missing-larkc — the actual table-update logic.

### Asserted-assertions analysis (missing-larkc)

A family of date-aware analyses on a metering table:

- `kb-access-metering-asserted-assertions table` — extract the set of assertions accessed.
- `mean-asserted-assertion-dates assertions` — average creation date.
- `median-asserted-assertion-dates assertions` — median creation date.
- `weighted-mean-asserted-assertion-dates assertions` — weighted by some property (likely access count).
- `weighted-median-asserted-assertion-dates assertions` — weighted median.
- `percent-before-date assertions date` — what fraction of accesses were on assertions older than `date`.
- `weighted-percent-before-date assertions date` — same, weighted.
- `print-asserted-assertions-by-date table &optional stream` — dump access histogram by date.

These are diagnostic tools — given a measured query, they tell you whether the reasoning was driven by old or new content. Useful for "how stale is the working set?" analysis.

### Notes for the clean rewrite — kb-access-metering

- **Most of this file is stub.** The macro shape and the gating hooks survive; the implementation must be reconstructed.
- **The macro is correctly shaped** — it takes a `:domains` keyword listing which kinds of access to record. The default `'(:assertion)` is reasonable.
- **Reconstruct the metering table as a hash from object → access-count.** No need for the full Cyc design; the simple shape covers the use cases.
- **The date-analysis functions are valuable diagnostic** for understanding query characteristics — implement them in the rewrite, ideally as separate utilities operating on a metering-result object rather than as kbom-coupled functions.
- **`possibly-note-kb-access-sbhl-link` as a macro vs the others as functions** is a microoptimization — the SBHL link traversal is hot enough to want the gate inlined. Modern compilers can usually inline a small function with the `inline` declaration; the macro form is unnecessary.
