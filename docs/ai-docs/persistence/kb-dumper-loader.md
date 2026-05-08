# KB dumper / loader

This system reads and writes the **complete on-disk image of the KB** — the directory full of `.cfasl` and `.text` files that ships in `cyc-tiny/`, OpenCyc, ResearchCyc, etc. It is the boundary between an empty Cyc image and a populated one. Every constant, NART, assertion, deduction, KB-HL support, clause-struc, unrepresented term, and every cached derived structure (SBHL, indexing, arg-type, defns, somewhere, arity, TVA, cardinality estimates, rule statistics) goes through here on its way to and from disk.

The implementation lives in `dumper.lisp`. There are no other files in this system — `file-translation.lisp`, `secure-translation.lisp`, and `system-translation.lisp` are unrelated; they belong to the SubL→Java/C source translator (the build-time tool that compiled the SubL sources into the Java now in `larkc-java/`), and don't participate in KB I/O.

## Port status: load-only

The LarKC port preserves the **load** path completely. The **dump** path is stripped — every `dump-*` function in this file is a commented-out `declareFunction` with no body, plus a few macros (`with-kb-dump-ids`, `with-kb-load-ids`, `with-kb-load-area-allocation`, `without-kb-load-area-allocation`, `not-computing-arg-type-cache`) whose bodies were not reconstructible. A clean rewrite needs both directions; this doc describes the design of both, but flags which side currently runs and which is gone.

The asymmetry is by design: LarKC distributions are read-only — they ship a pre-built KB and expect the user to query, not edit-and-save. Cyc the engine has full dump support, used by the standard Cycorp build process to materialize a `.cfasl` directory from a running image.

## Top-level entry points

| Function | Direction | Purpose |
|---|---|---|
| `load-kb directory-path` | in | Top-level loader. Reads everything, then runs initializations and either swaps to file-backed cache mode or pins the whole KB in memory. |
| `kb-load-from-directory directory-path` | in | Internal driver. Sets up dump-id lookup bindings, calls `load-essential-kb` then `load-computable-content`. |
| `dump-kb &optional directory-path` | out | (stripped) Top-level dumper. Counterpart to `load-kb`. |
| `kb-dump-to-directory directory-path` | out | (stripped) Internal driver. |

`load-kb` is called once at startup from `larkc-init.lisp` (see `kb-initialization-architecture.md`). The post-load step branches on `*force-monolithic-kb-assumption*`:

- **monolithic** (single fully-resident image, no disk swapping): a finalization step (LarKC-stripped, `missing-larkc 2354`) and a GC checkpoint.
- **swappable** (the normal case): `swap-out-all-pristine-kb-objects` evicts everything that's still pristine — assertion/deduction content, constant/NART/unrepresented-term indices, NART HL-formulas, KB-HL supports, SBHL graph links — into the file-backed cache layer (see `kb-access/kb-object-manager.md`). After swap, `enforce-standard-kb-sbhl-caching-policies` configures SBHL caching levels.

`load-kb` returns the value of `(kb-loaded)`, which the loader writes from the `misc.cfasl` file (via `set-build-kb-loaded`). That value is the KB version number; nil means no KB.

## Dump directory layout

A KB dump is a single directory of files. File names are fixed; the helpers `kb-dump-file name dir &optional ext` (extension defaults to `"cfasl"`) and the dead `kb-dump-product-file` build the paths. Three filename suffixes are used:

| Suffix | Role |
|---|---|
| `.text` | Plain-text count files. One ASCII integer; read with `read`. |
| `.cfasl` | Binary CFASL stream. The bulk of the KB. |
| (no ext) | Index sidecar for the `kb-object-manager` LRU swap layer (`*-index.cfasl`, paired with the data file). |

There are seven kinds of files in a dump, arranged conceptually:

**Counts** — text, one integer each. Pre-allocate the per-type id-index arrays.
- `constant-count.text`, `nart-count.text`, `assertion-count.text`, `deduction-count.text`, `kb-hl-support-count.text`, `clause-struc-count.text`, `unrepresented-term-count.text`

**Special** — bootstrap data the rest of the load needs first.
- `special.cfasl` — the common-symbol table (used by CFASL compression). Loaded via `load-special-objects` with `*cfasl-common-symbols*` bound to nil so the file itself can't try to use the table.

**Shells** — handle objects with just an ID and (for constants) a GUID + name. No content yet.
- `constant-shell.cfasl` (+ a human-readable `constant-shell.text`), plus N-shaped initializers from the count files for NARTs, assertions, KB-HL-supports.

**Definitions** — the actual content for each shell.
- `clause-struc.cfasl`, `deduction.cfasl` (+ `deduction-index.cfasl`), `assertion.cfasl` (+ `assertion-index.cfasl`), `kb-hl-support.cfasl` (+ `kb-hl-support-index.cfasl`), `nart-hl-formula.cfasl` (+ `nart-hl-formula-index.cfasl`), `unrepresented-terms.cfasl`.

**Indexing** — the per-FORT inverted indices that drive `kb-mapping`.
- `indices.cfasl` (constant) (+ `indices-index.cfasl`), `nat-indices.cfasl` (NART) (+ `nat-indices-index.cfasl`), `unrepresented-term-indices.cfasl` (+ `unrepresented-term-indices-index.cfasl`), `assertion-indices.cfasl`, `auxiliary-indices.cfasl`, `bookkeeping-indices.cfasl`.

**Bookkeeping & experience** — orthogonal stores.
- `bookkeeping-assertions.cfasl` (binary GAFs about who-asserted-what), `rule-utility-experience.cfasl` (rule statistics).

**Caches** — derived structures dumped to skip recomputation on load.
- `sbhl-modules.cfasl` (+ `sbhl-module-graphs.cfasl` + `sbhl-module-graphs-index.cfasl`), `sbhl-cache.cfasl`, `arg-type-cache.cfasl`, `arity-cache.cfasl`, `cardinality-estimates.cfasl`, `defns-cache.cfasl`, `somewhere-cache.cfasl`, `tva-cache.cfasl` (+ `tva-cache-contents.cfasl` + `tva-cache-contents-index.cfasl`), `misc.cfasl`, `rule-set.cfasl`, `kb-hl-support-indexing.cfasl`.

The `cyc-tiny/` directory in the LarKC distribution is a complete reference example — 717 constants, 8,899 assertions, 4,113 deductions, 2 NARTs, 46 files total.

## When does a dump file get loaded?

The triggering situation is **a fresh Cyc image is being booted from a known-good KB image on disk**. There is no incremental load; KBs are loaded once, top to bottom. Re-loading a different KB into a populated image is not supported.

Within a single load, each file is loaded exactly once, in a fixed order driven by inter-file references:

1. `special.cfasl` first — it defines the common-symbol table that all other files depend on for compact symbol references.
2. The HL-store-cache directory is wired up next (when not monolithic) so the file-vector swap layer can serve subsequent reads.
3. Counts come before shells — the shells need the count to size the id-index.
4. All shells come before any definitions — definitions reference handles by id, and the handles must already exist (this is the **two-phase load**, see below).
5. Within definitions, `clause-struc` precedes `deduction` (deductions cite clause-strucs), `deduction` precedes `assertion` (assertions cite deductions for justification), and `kb-hl-support` follows.
6. Bookkeeping and experience are loaded after assertions, since they reference assertion handles.
7. Computable content (indexing, NART HL-formulas, caches) comes after essential KB.
8. SBHL data and SBHL cache are loaded together near the end.
9. Initializations run last — `load-kb-initializations` rebuilds anything that wasn't dumpable (see below).

If `*force-monolithic-kb-assumption*` is true, the *-from-cache helpers are bypassed: every dump file is read straight into memory rather than being read into the file-backed cache layer.

## Two-phase load: shells then definitions

The defining invariant of the loader is that **all shells exist before any definition is read**. A "shell" is a handle object — typed identifier, no content. A "definition" is the content (constant index, assertion CNF + microtheory + supports, deduction proof, etc.).

Why: definitions reference each other by handle id. An assertion's clause-struc reference, a deduction's supporting-assertion reference, an SBHL link — they all serialize as just an id (CFASL opcode 30/31/33/36/37/38). On read, the id is looked up via `*cfasl-constant-handle-lookup-func*` and friends, which are bound to `find-constant-by-dump-id` etc. for the duration of the load. If the target shell doesn't exist yet, the lookup fails. Loading shells first makes every cross-reference resolvable in one pass.

Each per-type loader has the same shape:
- `load-X-shells` — for each id in 0..count-1, mint an empty handle and `finalize-X` to bake the id-index. Every id is allocated even if the file doesn't carry one (sparse ids would be lost). Shells for constants additionally read `name` and `guid` from the shell file.
- `load-X-defs` — for each (id, content) in the data file, look up the handle via `find-X-by-dump-id` and call the content setter (`reset-constant-index`, `load-assertion-content`, `load-deduction-content`, `load-kb-hl-support-content`, etc.).

The per-id form `(load-copyright stream) ; (do ((dump-id (cfasl-input s nil) ...)) ((eq dump-id :eof)) (when (integerp dump-id) ...))` is a stock loop reused in nearly every loader.

## Two-mode load: in-memory vs file-backed cache

Most definition and indexing files have a sidecar index file (`<name>-index.cfasl`) that lets the `kb-object-manager` LRU layer serve individual records on demand without loading the whole `.cfasl` file. The loader chooses mode per-file:

- If `(null *force-monolithic-kb-assumption*)` and the index sidecar exists → call `initialize-X-hl-store-cache` and skip the data-file read entirely. The data file will be read on demand by the LRU manager (see `kb-access/kb-object-manager.md`).
- Otherwise → fall back to verifying the data file and reading every record into memory.

This is the on-load equivalent of the swap-out path. `*structure-resourcing-make-static*` and `*cfasl-input-to-static-area*` are bound to T while reading shells and indexing — they tell CFASL and the structure allocator to use the static (long-lived) area, since these objects will live for the rest of the image's life. Inside the LRU `from-cache` wrapper functions, both vars are toggled per record.

Files that participate in the two-mode load: `assertion`, `deduction`, `kb-hl-support`, `nart-hl-formula`, `indices` (constant), `nat-indices` (NART), `unrepresented-term-indices`, `tva-cache-contents`. Files that don't (always-monolithic): the special / shell / count files, the bookkeeping files, sbhl-modules, sbhl-cache, the smaller caches, `misc`, `rule-set`.

## Handle lookup bindings

While `kb-load-from-directory` is running, six dynamic vars route CFASL handle decoders to the live shell tables:

```
*cfasl-constant-handle-lookup-func*       → find-constant-by-dump-id
*cfasl-nart-handle-lookup-func*           → find-nart-by-dump-id
*cfasl-assertion-handle-lookup-func*      → find-assertion-by-dump-id
*cfasl-deduction-handle-lookup-func*      → find-deduction-by-dump-id
*cfasl-kb-hl-support-handle-lookup-func*  → find-kb-hl-support-by-dump-id
*cfasl-clause-struc-handle-lookup-func*   → find-clause-struc-by-dump-id
```

These are how CFASL opcodes 30/31/33/36/37/38 (the typed-handle opcodes) reach the in-memory shell. Outside of load, the same opcodes wouldn't be useful — handle ids on the wire are dump-time ids, which only mean something inside the directory's namespace. (See `cfasl.md` for the wire format and the `complete-constant`/`complete-variable` recipe forms used cross-image.)

The `commented //declareMacro with-kb-dump-ids / with-kb-load-ids` were the macroized version of these bindings. Their bodies aren't reconstructible from this file alone, but the load path expands them open-coded inside `kb-load-from-directory`, so the macro shape is recoverable from that expansion.

## Counts: text files vs cfasl recovery

Each count is read by `load-kb-object-count directory filename`, which opens `<filename>.text` and `read`s a single integer. The function returns nil if the file is missing.

`load-constant-count` has a fallback: if `constant-count.text` is missing, it opens `constant-shell.cfasl` and reads the count off the second cfasl object in the stream (the shell file embeds the count up front). The other types don't have this fallback; if the count file is missing for them, `setup-kb-state-from-dump` reaches the `(t (missing-larkc 4883))` arm — Cyc's full implementation reports the missing file by name.

`setup-kb-state-from-dump` calls `setup-kb-tables-int` with all seven counts, which sizes every per-type id-index, then `clear-kb-state-int` to reset any leftover global state.

## Initializations after load

`load-kb-initializations` runs the **non-dumpable but computable** rebuilds. These are structures that are too cheap to be worth dumping (or too entangled to dump cleanly) — they're computed from what's already in memory:

- `clean-sbhl-modules` — purge stale SBHL data
- `compute-bogus-constant-names-in-code` — pre-compute the `bogus-constant-name?` cache
- `initialize-kb-state-hashes` — re-key state hashtables to the loaded KB
- `initialize-old-constant-names` — name-renaming history map
- `initialize-kb-variables` — variables-by-id table
- `rebuild-computable-but-not-dumpable-yet` — large rebuild block (memoization state, marking spaces); the docstring on this function is itself a TODO note left by the original Cycorp authors

There are three subdivisions to mirror the dump-side rebuild functions:

- `load-essential-kb-initializations` (after shells + defs): `initialize-kb-features` → `initialize-kct-kb-feature` (KB content tester registration).
- `load-computable-kb-initializations` (after indexing + rule-set): currently a no-op placeholder.
- `load-computable-remaining-hl-low-initializations` (after SBHL + caches): `initialize-sublid-mappings`.

After the third call, `load-kb` decides between monolithic and swap-out paths.

## Per-type loader summary

| File on disk | Loader | Content writer | Mode |
|---|---|---|---|
| `special.cfasl` | `load-special-objects` | `cfasl-set-common-symbols` | monolithic |
| `constant-count.text` | `load-constant-count` | `setup-kb-tables-int` | text |
| `constant-shell.cfasl` | `load-constant-shells` → `load-constant-shell` → `load-constant-shell-internal` | `make-constant-shell` + `load-install-constant-ids` | monolithic |
| `nart-count.text` | `load-nart-count` | `setup-kb-tables-int` | text |
| (none) | `load-nart-shells` → `initialize-nart-shells` | `make-nart-shell` per id | counted |
| `assertion-count.text` | `load-assertion-count` | `setup-kb-tables-int` | text |
| (none) | `load-assertion-shells` → `initialize-assertion-shells` | `make-assertion-shell` per id | counted |
| `kb-hl-support-count.text` | `load-kb-hl-support-count` | `setup-kb-tables-int` | text |
| (none) | `load-kb-hl-support-shells` → `initialize-kb-hl-support-shells` | `make-kb-hl-support-shell` per id | counted |
| `clause-struc-count.text` | `load-clause-struc-count` | `setup-kb-tables-int` | text |
| `clause-struc.cfasl` | `load-clause-struc-defs` → `load-clause-struc-def` | `make-clause-struc-shell` + `reset-clause-struc-assertions` | monolithic |
| `deduction.cfasl` (+ `deduction-index.cfasl`) | `load-deduction-defs` (or `initialize-deduction-hl-store-cache`) | `load-deduction-content` | two-mode |
| `assertion.cfasl` (+ `assertion-index.cfasl`) | `load-assertion-defs` (or `initialize-assertion-hl-store-cache`) | `load-assertion-content` | two-mode |
| `kb-hl-support.cfasl` (+ `kb-hl-support-index.cfasl`) | `load-kb-hl-support-defs` (or `initialize-kb-hl-support-hl-store-cache`) | `load-kb-hl-support-content` | two-mode |
| `kb-hl-support-indexing.cfasl` | `load-kb-hl-support-indexing` → `load-kb-hl-support-indexing-int` | (in `kb-hl-support-manager`) | monolithic |
| `bookkeeping-assertions.cfasl` | `load-bookkeeping-assertions` → `load-bookkeeping-assertion` | `dumper-load-bookkeeping-binary-gaf` | monolithic |
| `rule-utility-experience.cfasl` | `load-experience` → `load-rule-utility-experience` | `load-transformation-rule-statistics` | monolithic |
| `unrepresented-term-count.text` | `load-kb-unrepresented-term-count` | `setup-kb-tables-int` | text |
| `unrepresented-terms.cfasl` | `load-kb-unrepresented-terms` → `load-kb-unrepresented-term` | `register-unrepresented-term-suid` | monolithic |
| `indices.cfasl` (+ `indices-index.cfasl`) | `load-constant-indices` (or `initialize-constant-index-hl-store-cache`) | `reset-constant-index` | two-mode |
| `nat-indices.cfasl` (+ `nat-indices-index.cfasl`) | `load-nart-indices` (or `initialize-nart-index-hl-store-cache`) | (`load-nart-index` is `missing-larkc 10571`) | two-mode |
| `unrepresented-term-indices.cfasl` (+ `unrepresented-term-indices-index.cfasl`) | `load-unrepresented-term-indices` (or `initialize-unrepresented-term-index-hl-store-cache`) | `reset-unrepresented-term-index` | two-mode |
| `assertion-indices.cfasl` | `load-assertion-indices` → `load-assertion-index` | `reset-assertion-index` | monolithic |
| `auxiliary-indices.cfasl` | `load-auxiliary-indices-file` | `load-auxiliary-indices` | monolithic |
| `bookkeeping-indices.cfasl` | `load-bookkeeping-indices-file` → `load-bookkeeping-indices` | `dumper-load-bookkeeping-index` | monolithic |
| `rule-set.cfasl` | `load-rule-set` | `load-rule-set-from-stream` | monolithic |
| `nart-hl-formula.cfasl` (+ `nart-hl-formula-index.cfasl`) | `load-nart-hl-formulas` (or `initialize-nart-hl-formula-hl-store-cache`) | (`load-nart-hl-formula` is `missing-larkc 10568`) | two-mode |
| `misc.cfasl` | `load-miscellaneous` | inline: skolem-axiom-table, build-kb-loaded | monolithic |
| `sbhl-modules.cfasl` (+ `sbhl-module-graphs.cfasl` + `sbhl-module-graphs-index.cfasl`) | `load-sbhl-data` → `load-sbhl-miscellany` | `set-sbhl-module-property module :graph`, `set-non-fort-isa-table`, etc. | data-file is two-mode |
| `sbhl-cache.cfasl` | `load-sbhl-cache` | inline: 8 caches `*isa-cache*` … `*all-mts-genl-inverse-cache*` | monolithic |
| `cardinality-estimates.cfasl` | `load-cardinality-estimates` | `load-cardinality-estimates-from-stream` | monolithic |
| `arg-type-cache.cfasl` | `load-arg-type-cache` | `*arg-type-cache*` (+ 3 dummy cfasl reads, the discarded slots) | monolithic |
| `defns-cache.cfasl` | `load-defns-cache` | `load-defns-cache-from-stream` | monolithic |
| `somewhere-cache.cfasl` | `load-somewhere-cache` | `load-somewhere-cache-from-stream` | monolithic |
| `arity-cache.cfasl` | `load-arity-cache` | `load-arity-cache-from-stream` | monolithic |
| `tva-cache.cfasl` (+ `tva-cache-contents.cfasl` + `tva-cache-contents-index.cfasl`) | `load-tva-cache` | `load-tva-cache-from-stream`; then `reconnect-tva-cache-registry` to wire up the contents file-vector | monolithic-header + two-mode-contents |

The `load-X-from-cache` family (`load-constant-index-from-cache`, `load-assertion-def-from-cache`, `load-deduction-def-from-cache`, `load-kb-hl-support-def-from-cache`, `load-unrepresented-term-index-from-cache`, `load-nart-index-from-cache`, `load-nart-hl-formula-from-cache`) are the per-record entry points the `kb-object-manager` LRU calls back into when serving a swap-in. They wrap the regular `load-X-def`/`load-X-index` in a `(let ((*within-cfasl-externalization* nil)) ...)` so the swap-in always reads in-image (handle-id) form, never externalized form. They are registered with `note-funcall-helper-function` at file end so the dispatcher can `funcall` them by symbol.

## File-IO scaffolding

Every file loader has the same skeleton:

```
(let ((cfasl-file (kb-dump-file <name> directory))
      (filename-var cfasl-file)
      (stream nil))
  (unwind-protect
       (progn
         (let ((*stream-requires-locking* nil))
           (setf stream (open-binary filename-var :input)))
         (unless (streamp stream)
           (error "Unable to open ~S" filename-var))
         (let* ((stream-NN stream)
                (total (file-length stream-NN)))
           (load-copyright stream-NN)
           ...))
    (let ((*is-thread-performing-cleanup?* t))
      (when (streamp stream)
        (close stream))))
  (discard-dump-filename filename-var))
```

The `unwind-protect` ensures the stream is closed on error. `*is-thread-performing-cleanup?*` is bound to T during the cleanup form so structure-allocation routines know not to fight the close. `discard-dump-filename` overwrites the filename string with spaces — a defensive measure to keep the (possibly large, possibly secret) filename out of memory after use, since the same string variable was used as a key into a dump-id table on the dump side.

The macros `with-kb-dump-filename`, `with-kb-dump-binary-file`, `with-kb-dump-text-file` were intended to package this skeleton (their bodies are reconstructed in the port; `with-kb-dump-filename` is the unwind-protect wrapper, the other two layer it over `with-private-binary-file` / `with-private-text-file`). The load paths in this file expand them open-coded.

`load-copyright` reads the first cfasl object (a string) from each `.cfasl` file and discards it. Every dump file therefore begins with a copyright string. The dumped value isn't preserved — only its consumption position in the stream matters.

`load-unit-file directory filename load-func progress-message` is a small helper used for `bookkeeping-indices`, `rule-set`, `cardinality-estimates`, and `tva-cache` — the simple "open binary file, read copyright, call one loader, complain about leftover bytes" pattern.

## Progress reporting

Loads are user-visible at the console; `*dump-verbose*` (default T) gates the timestamps and per-phase banners. Each phase prints `;;; Loading <phase> at <timestring>`. Inside a phase, the per-record loops use `noting-percent-progress` (with `note-percent-progress` updating against `(file-length stream)`) for byte-position progress, or against object counts when the count is known up front (`(constant-count)`, `(nart-count)`, etc.). Smaller files use `noting-progress-preamble` / `noting-progress-postamble` to bracket the phase. `*silent-progress?*` and `*noting-progress-start-time*` parameterize this.

`*kb-load-gc-checkpoints-enabled?*` (default nil) gates a per-phase GC checkpoint hook — `kb-load-gc-checkpoint`. The hook itself has its body stripped (Java empty branch), but the call sites are dense throughout the load (one between every two phase steps), so a clean rewrite can either GC there or no-op there.

## "Stuff after the end" warnings

After every monolithic file's main read loop, the loader does `(unless (eq (cfasl-input stream nil :eof) :eof) (warn ...))`. This catches truncated or corrupt files where extra unread bytes remain after the structurally-defined end of the loop. The warning includes the byte count and the filename. Two-mode files don't do this check on the slow path because the LRU layer reads on demand.

## What the dump path looks like (stripped)

The full set of stripped dump entry points, as commented `declareFunction` lines in this file, mirrors the load path:

- Top-level: `dump-kb`, `kb-dump-to-directory`, `dump-standard-kb`, `preprocess-experience-and-dump-standard-kb`, `dump-non-computable-kb`, `dump-computable-kb-and-content`, `kb-dump-directory`, `kb-dump-product-file`, `dump-estimated-size`, `validate-dump-directory`, `perform-standard-pre-dump-kb-cleanups`, `perform-kb-cleanups`.
- IDs: `dump-kb-ids`.
- Phases (mirror the load phases): `dump-essential-kb`, `dump-computable-content`, `dump-computable-kb`, `dump-computable-remaining-hl`, `dump-special-objects`, `dump-copyright`, `dump-kb-object-count`, `kb-dump-common-symbols`, `dump-special-objects-internal`.
- Per-type shells: `dump-constant-shells`/`dump-constant-shell`/`dump-constant-shell-internal`, `dump-nart-count`, `dump-nart-shell`, `dump-assertion-count`, `dump-assertion-shell`, `dump-kb-hl-support-count`, `dump-kb-hl-support-shell`.
- Per-type definitions: `dump-clause-struc-defs`/`dump-clause-struc-def`, `dump-deduction-defs`/`dump-deduction-def`, `dump-assertion-defs`/`dump-assertion-def`, `dump-kb-hl-support-defs`/`dump-kb-hl-support-def`, `dump-kb-unrepresented-terms`/`dump-kb-unrepresented-term`.
- Bookkeeping & experience: `dump-bookkeeping-assertions`, `dump-bookkeeping-assertion`, `dump-bookkeeping-assertions-for-pred`, `dump-experience`, `dump-rule-utility-experience`, `reload-experience`.
- Indexing: `dump-kb-indexing`, `rebuild-kb-indexing`, `test-dump-kb-indexing`/`test-load-kb-indexing`, `dump-constant-indices`/`dump-constant-index`, `dump-nart-indices`/`dump-nart-index`, `dump-unrepresented-term-indices`/`dump-unrepresented-term-index`, `dump-assertion-indices`/`dump-assertion-index`, `dump-auxiliary-indices-file`, `dump-bookkeeping-indices-file`/`dump-bookkeeping-indices`, `dump-kb-hl-support-indexing`.
- Other: `dump-rule-set`, `dump-nart-hl-formulas`/`dump-nart-hl-formula`, `dump-miscellaneous`, `dump-sbhl-data`/`old-dump-sbhl-data`, `rebuild-sbhl-data`, `dump-sbhl-miscellany`, `dump-isa-arg2-naut-table`, `dump-non-fort-isa-table`, `dump-non-fort-instance-table`, `dump-sbhl-cache`, `rebuild-sbhl-cache`, `dump-cardinality-estimates`, `dump-arg-type-cache`, `rebuild-arg-type-cache`, `dump-defns-cache`, `dump-tva-cache`, `dump-somewhere-cache`, `dump-arity-cache`, `dump-kb-activities`, `show-kb-features`.
- Macros: `with-kb-dump-ids`, `with-kb-load-ids`, `with-kb-load-area-allocation`, `without-kb-load-area-allocation`, `not-computing-arg-type-cache`.
- Rebuilds (the dump→re-dump pipeline): `rebuild-computable-content`, `rebuild-computable-content-dumpable`, `rebuild-computable-content-dumpable-low`, `rebuild-computable-kb`, `rebuild-computable-remaining-hl`, `rebuild-computable-remaining-hl-low`, `rebuild-computable-remaining-hl-high`.
- Image roundtrip: `load-non-computable-kb-and-rebuild-computable-kb-and-write-image`, `load-non-computable-kb`.

By symmetry with the load functions and the surviving per-record skeleton (open file, write copyright, write count, do dolist over objects, write closing eof, close), each of these is mechanically reconstructible in a clean rewrite. The hard part — the on-disk format — is fully specified by the load side and by `cfasl.md`.

## Required state from elsewhere

The dumper/loader is a thin orchestrator over other systems. The interesting work happens in:

- **CFASL** (`persistence/cfasl.md`) — every byte of every `.cfasl` file passes through `cfasl-input` / `cfasl-output`.
- **KB object manager** (`kb-access/kb-object-manager.md`) — the LRU cache layer that the `*-index.cfasl` sidecar files feed into. `initialize-X-hl-store-cache` is the bridge.
- **id-index** (the data structure underlying every shell table) — dumper relies on `setup-kb-tables-int` to size them, `finalize-X` to bake them.
- **Per-type handles** (`core-kb/constants.md`, `core-kb/narts.md`, `core-kb/assertions.md`, `core-kb/deductions.md`, `core-kb/kb-hl-supports.md`, `core-kb/clauses.md`) — `make-X-shell`, `find-X-by-dump-id`, `load-X-content`, `reset-X-index`.
- **KB indexing** (`kb-access/kb-indexing.md`, `kb-access/auxiliary-indexing.md`, `kb-access/bookkeeping-store.md`) — content of the indexing/bookkeeping files.
- **SBHL** (`graph-reasoning/sbhl.md`) — content of the `sbhl-*` files.
- **Caches** — `arg-type-cache` (`canonicalization/arg-type.md`), `defns-cache`, `somewhere-cache`, `arity-cache`, `tva-cache` (`inference/tva.md`), `cardinality-estimates` (`inference/cardinality-and-pattern-match.md`).
- **Bookkeeping** (`kb-access/bookkeeping-store.md`).
- **Rule-set** — see backward inference / forward propagation docs.
- **Skolems & misc** — the `misc.cfasl` stream contains `*skolem-axiom-table*` and the build-kb version among other things; see `graph-reasoning/skolems.md`.

## Notes for a clean rewrite

- **Drop the special.cfasl bootstrap** — the common-symbol table is a CFASL compression optimization. A modern format with built-in symbol interning (like FlatBuffers schemas, or just a length-prefixed symbol pool at the head of each file) makes it unnecessary.
- **One file or many?** — The 46-file split exists because each file maps to a separate dump phase and each phase can be re-run independently for incremental rebuilds. A clean rewrite can keep the split (good for parallel reads, partial reloads, version-skewed files) or fold everything into a single archive (simpler, atomic). The two-mode load (whole-file vs LRU sidecar) only matters per-file, so the archive form would need an internal directory.
- **Drop `load-copyright`** — embed copyright in the archive header once.
- **Drop `discard-dump-filename`** — the spaces-fill defensive measure was a SubL-era memory hygiene practice. Modern GC handles this.
- **Drop the `from-cache` wrappers** — they exist to flip `*within-cfasl-externalization*`. A clean rewrite distinguishes externalized vs internal at the codec level instead of via dynamic vars.
- **Make dump symmetric to load by construction** — every type has a load function but the dump side was stripped. A modern design defines a single per-type codec (encode + decode) and has the dump and load orchestrators iterate over the same registry. This eliminates the drift opportunity that lets the LarKC distribution ship without dump.
- **Replace the count files with embedded headers** — the seven `.text` files exist because shells need sizes before the data files can be opened. A modern format puts the count in the data file's header and reads it before the body. Removes seven redundant files and the `load-kb-object-count` / fallback logic.
- **The two-mode boundary is the right design.** Keep it. Some KB objects are needed eagerly (constants, NARTs, shells); others (assertion content, deduction content, KB-HL supports, large indices) want random-access lazy loading. The per-record file-vector is the right shape for that — see `kb-object-manager.md` for the LRU side.
- **`kb-load-initializations` is a smell.** Each rebuilt-on-load structure is a place where dumping was punted. A clean rewrite should aim to dump everything and skip this phase, or at least cut it to a small list of cheap finalizers.
- **`*force-monolithic-kb-assumption*` and the swap-out branch are mutually exclusive design choices that overlap conceptually**: monolithic = "the whole KB fits in memory and stays there", swappable = "the LRU layer evicts cold objects". A clean rewrite picks one or unifies them — most likely the swappable path is correct for any non-toy KB, and the monolithic path can become the special case where the LRU's working set equals the whole KB.
