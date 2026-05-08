# Hash-table utilities

A tiny (87-line) bag of helpers around CL's native `hash-table`. The whole file exists because SubL's hashtable surface was thinner than CL's and a handful of idioms (test-symbol/test-function bidirectional naming, push-onto-hash-bucket, key/value listing) didn't ship as primitives. Every entry here either wraps a CL primitive in a SubL-style name or implements one of those idioms in three lines. There are no data-structure invariants here — the underlying hashtables are CL's.

The file is **not** the deprecated `dictionary` layer; that lives in `dictionary.lisp` / `dictionary-utilities.lisp` and is being phased out in favour of these (see the dictionary doc). This file is the *destination* of that migration.

## Public API

| Function / constant | Purpose |
|---|---|
| `*valid-hash-test-symbols*` | The four symbols `(eq eql equal equalp)`. |
| `*valid-hash-test-functions*` | The four function objects matching those symbols. |
| `valid-hash-test-symbols` | Returns `*valid-hash-test-symbols*`. |
| `hash-test-to-symbol test` | Given a function or symbol, returns the symbol form. Used when reading or writing test-tagged hashtables (e.g. CFASL). |
| `hash-table-empty-p table` | `(zerop (hash-table-count table))`. |
| `rehash table` | No-op stub. Comment: "Relying on CL doing a good job on its own." |
| `push-hash key item table` | `(push item (gethash key table))` — adds to the list bucket at `key`. |
| `pop-hash key table` | `(pop (gethash key table))`. |
| `delete-hash key item table &optional test test-key` | `(setf bucket (delete item bucket :test :key))`. |
| `hash-table-keys hash-table` | Returns the list of keys. |
| `hash-table-values hash-table` | Returns the list of values. |

## Why these specific helpers

Three patterns explain almost every entry:

- **Test-symbol/function bidirection.** CFASL serializes a hashtable's test as a symbol (`'eq`), but `make-hash-table :test ...` accepts either symbol or function; identity comparisons against a stored test sometimes have one and sometimes the other. `hash-test-to-symbol` plus the two `*valid-hash-test-...*` constants normalize both directions. `valid-hash-test-p` (defined elsewhere via `(satisfies ...)`) gates the input.
- **Push/pop/delete on a list-bucket.** Cyc has many "key → list of values" tables (e.g. `*defn-stack*` in `at-defns.lisp`, the auxiliary indexing per-FORT lists, the SBHL marking-vars buckets). The `push-hash` / `pop-hash` / `delete-hash` trio gives those a consistent surface so callers don't open-code `(setf (gethash k h) (cons x (gethash k h)))` everywhere. Note that they're *not* atomic — concurrent callers must lock externally.
- **Materializing keys/values.** CL's `loop for ... being the hash-key` idiom is verbose at every call site; `hash-table-keys` and `hash-table-values` shorten it. They allocate a fresh list each call.

`rehash` is a stub — SubL had a manual rehash entry point that CL handles automatically.

## What uses these

Roughly thirty files across the codebase, but the consumers cluster into four groups:

- **List-bucketed indexes.** `at-defns.lisp` (`*defn-stack*`), `at-utilities.lisp`, `auxiliary-indexing.lisp`, `defns.lisp`, `sdc.lisp`, `kb-hl-supports.lisp`, `kb-indexing-datastructures.lisp` — these all maintain hashtables whose values are lists, and use `push-hash` / `pop-hash` / `delete-hash` to mutate buckets. This is the original use case.
- **The deprecated container layer.** `dictionary-utilities.lisp`, `set.lisp`, `set-contents.lisp`, `map-utilities.lisp` — wrappers being phased out in favour of native hashtables. They call `hash-table-keys` / `hash-table-values` / `hash-table-empty-p` to implement their own walk and emptiness operations.
- **SBHL marking.** `sbhl/sbhl-marking-vars.lisp`, `sbhl/sbhl-search-what-mts.lisp`, `sbhl/sbhl-module-vars.lisp` — graph-marking tables where `hash-table-keys` snapshots the marked-node set.
- **CFASL and dump.** `dumper.lisp`, `constant-handles.lisp`, `somewhere-cache.lisp` — `valid-hash-test-symbols` / `hash-test-to-symbol` normalize the test field before serialization.

`hash-table-empty-p` and `hash-table-keys` are the two functions with the most callers (both ~20–30 sites). `rehash` is unused outside this file.

## Notes for a clean rewrite

- **Most of these go away.** `hash-table-empty-p` and `hash-table-keys`/`-values` are one-liners — replace with `alexandria:hash-table-keys`, `alexandria:hash-table-values`, and an inline `(zerop (hash-table-count h))`. `rehash` is a stub; delete it.
- **Keep the test-symbol bidirection.** As long as CFASL serializes test as a symbol and CL's hashtables store the test internally as a function, *some* mapping function is needed. `alexandria` doesn't provide it, so `hash-test-to-symbol` is genuine SubL-specific glue.
- **Keep `push-hash` / `pop-hash` / `delete-hash` if list-bucketed-hashtables remain a common pattern**, or replace them with a tiny `multimap` abstraction. They're trivial individually but the *naming* makes call sites readable. Either reuse them or commit to a different idiom (e.g. `serapeum:push-into-table`).
- **No threading or locking.** None of these functions take a lock; concurrent callers must wrap externally. A modern rewrite should pick one approach (always-locked, lock-free with concurrent hashtable, or external-lock convention) and document it. The current code leaves it implicit.
- **Drop `*valid-hash-test-symbols*` / `-functions*` as constants.** The four CL test functions are well-known; using a list is overhead. CFASL and the few callers that test "is this a valid test?" can use a `case`. The list-of-functions form (`*valid-hash-test-functions*`) only exists so `hash-test-to-symbol` can do `(find test ... :key #'symbol-function)` and is otherwise unused.
