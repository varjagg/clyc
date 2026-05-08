# File-vector (on-disk indexed array)

A file-vector is a **two-file random-access array of arbitrary-size CFASL records**. It's the on-disk substrate the LRU object managers (`kb-object-manager`) use to serve individual KB objects on demand without loading the whole `.cfasl` file into memory.

The implementation lives in `file-vector.lisp` (the core array) and `file-vector-utilities.lisp` (the file-vector-reference cell type and the file-vector-backed-map adapter). Together they form the disk side of the swap layer documented in `kb-access/kb-object-manager.md`.

## The two-file shape

A file-vector is two streams:

| File | Element type | Content |
|---|---|---|
| **data stream** | `(unsigned-byte 8)` | Concatenation of CFASL records, each of arbitrary length. |
| **index stream** | `(unsigned-byte 8)` | Packed array of 4-byte big-endian byte offsets into the data stream. |

To read entry `i`: seek the index stream to byte `4*i`, read a 4-byte big-endian offset, seek the data stream to that offset, call `cfasl-input` once.

A few consequences fall out of that shape:

- **Capacity is bounded by 4 GiB of data** because offsets are 4 bytes. The per-element offset width is the design choice; entry count is bounded only by index file size.
- **Random access is two seeks and one CFASL decode.** The index stream is also CFASL-decode-free; `read-32bit-be` is the only primitive needed.
- **Endianness is opposite of CFASL integers.** The index stream is big-endian (`read-32bit-be`); CFASL integer opcodes are little-endian. The comment `;; Read big endian, the opposite order of CFASL-INPUT-INTEGER` calls this out.
- **Length is computed from the index file's byte size**, not stored explicitly: `(ash (file-length index-stream) -2)` = number of 4-byte slots = number of entries. `file-vector-length-from-index` reads just the index file (without opening the data file) for callers that only need the count — `dumper.lisp` uses this when initializing deduction handles, where the count file is missing but the index file exists.

There is no header, no magic number, no version field on either file. The format is implicit: any file pair where the index file is N×4 bytes and the data file's CFASL records line up with the offsets is a valid file-vector. This is fine because the dump directory layout is fixed and per-pair file naming (`assertion.cfasl` + `assertion-index.cfasl`, etc.) carries the type information out-of-band.

## Public API (file-vector.lisp)

| Function | Purpose |
|---|---|
| `new-file-vector data-filename index-filename &optional direction` | Open both files (default `:input`), wrap in an `fvector` struct. |
| `create-file-vector data-stream index-stream` | Wrap two already-open streams. Used when streams come from elsewhere. |
| `close-file-vector fvector` | Close both streams. |
| `file-vector-length fvector` | Number of entries. Computed from index file length / 4. |
| `file-vector-length-from-index index-filename` | Same, but opens the index file just for this query. Errors if the file is missing. |
| `position-file-vector fvector &optional index` | Position the data stream to the offset for entry `index` (or to the next sequential offset if `index` is omitted). Returns the data stream so callers can `cfasl-input` from it. |
| `read-file-vector-index-entry fvector &optional index` | Just read the offset; don't move the data stream. |
| `file-vector-p object` | Predicate. |

The `fvector` struct has only two slots, `data-stream` and `index-stream`. There is no in-memory index cache, no metadata, no LRU; the stream `seek + read` is the cache (the OS page cache).

## Why "missing-larkc" on the write side

The header comment in the file states the design problem:

> Reads are performed by having this position the data-stream to the selected index, and then using external cfasl stuff on the data-stream. Unfortunately, writing seems to be missing-larkc.

Cyc's full implementation supports mutating individual entries. The natural strategy is **append-only with index rewrite**: when entry `i` changes, append the new bytes to the data file's tail, then overwrite the 4-byte slot at offset `4*i` in the index file to point at the new offset. Stale data is left in place; vacuum runs periodically. This works without a per-entry length field because reads don't need to know where an entry ends — `cfasl-input` self-delimits on the type tag.

In the LarKC port, only opens are present (`:direction :input`), the data stream is read-only, the index stream is read-only, and the only mutation path is via the file-vector-reference indirection layer (see below) — which is also `missing-larkc` past the simplest in-memory mutation case. Result: the port can load a dumped KB and serve LRU swap-ins, but it cannot write anything back to disk.

## File-vector references (file-vector-utilities.lisp)

A `file-vector-reference` is a **lazy cell**: a small struct with two slots, `index` (fixnum) and `payload` (the materialized object, or nil). The cell stands in for the real KB object inside a hashtable map until it's needed. There are four states it can be in:

| State | `index` | `payload` | Meaning |
|---|---|---|---|
| **swapped-out** | positive | nil | The entry exists at this offset in the file-vector. Not yet read. |
| **present-pristine** | positive | non-nil | Read once, payload cached, hasn't been mutated. Eligible for eviction. |
| **present-mutated** | negative | non-nil | Mutated in memory; on-disk version is stale. Cannot be evicted without losing the mutation. |
| **deleted** | negative | nil | Logically removed. The slot is held to record the tombstone. |

`new-file-vector-reference index` mints a swapped-out cell (asserts `index > 0`).

The state machine compresses into the sign of `index`:
- `(plusp index)` ⇒ valid file-vector slot (`fvector-ref-valid-index-p`).
- `(minusp index)` ⇒ mutated/deleted (`fvector-ref-mutated-index-p`). Mutation negates the index in place via `mark-file-vector-reference-as-mutated`.
- Payload nil/non-nil distinguishes deleted-vs-present and swapped-vs-pristine.

The four predicate functions answer it as flags:
- `file-vector-reference-present-pristine?` — valid index AND payload in memory.
- `file-vector-reference-present-mutated?` — mutated index AND payload in memory.
- `file-vector-reference-present?` — either of the above.
- `file-vector-reference-swapped-out?` — valid index, no payload.
- `file-vector-reference-deleted?` — mutated index, no payload.

`set-file-vector-reference-referenced-object` sets the payload; `clear-file-vector-reference-referenced-object` zeroes it (used during eviction).

### CFASL integration

File-vector references are themselves CFASL-encodable: opcode 69 (`*cfasl-opcode-fvector-reference*`). On the wire the reference is `index`, optionally followed by a payload if the index is invalid (a "complete" reference where the data lives inline). `cfasl-input-file-vector-reference` reads the index, then either mints an empty reference (lazy) or reads the payload (eager) depending on whether the index is positive.

This is what lets a serialized indexing structure embed *references to other file-vector entries* — the dumper can write either a real reference (lazy) or a complete inline payload (eager) based on what makes sense for that record.

## File-vector-backed map (the LRU bridge)

`file-vector-backed-map-w/-cache-get map fvector cache-strategy key &optional not-found` is the **lookup function the kb-object-manager LRU calls**. The flow:

1. Look up `key` in the underlying `map` (a hashtable-like).
2. If the value isn't a `file-vector-reference`, return it directly (this is the non-swappable case — small objects living in memory full-time).
3. If it's a present-pristine reference, return its payload and (if a real cache strategy is supplied) note a cache hit and a key reference.
4. If it's a deleted reference, return `not-found`.
5. If it's swapped-out: `position-file-vector fvector index`, `cfasl-input` the data stream, install the result in the reference's payload, tell the cache strategy to track the key (potentially evicting the LRU loser), and note a cache miss. Return the payload.
6. Anything else is an invalid state and signals an error.

`file-vector-backed-map-w/-cache-put map cache-strategy key value` and `-touch` are the mutation entry points. They're substantially `missing-larkc`: the only working path is "current value is not a file-vector reference, just `map-put`." The interesting cases — replacing a swapped-out reference, marking a touched reference as mutated to flush back later — invoke `missing-larkc 6215`, `31228`, `31248`, `31250`. A clean rewrite needs to flesh these out for any write workload.

`-remove` works for the no-undo case. `support-undo-p` + reference invokes `missing-larkc 6214`.

`*file-vector-backed-map-read-lock*` gates the seek+read against concurrent access. The lock is `nil` by default — production callers are expected to bind it. The TODO at the declaration calls this out; the `bt:with-lock-held` calls accept the nil lock as a no-op via the BT API.

`swap-out-all-pristine-file-vector-backed-map-objects map` walks every entry, and for each present-pristine reference, clears the payload (returning the reference to the swapped-out state). The count of swapped-out entries is returned as the second value. This is what `swap-out-all-pristine-kb-objects` (in `kb-utilities.lisp`) calls into transitively for each KB object type at the end of `load-kb`.

`potentially-swap-out-pristine-file-vector-backed-map-object value` is the per-value test: returns t and clears the payload if `value` is a pristine reference.

## Backed-map (`backed-map` struct)

`backed-map` is a thin pairing of a map (hashtable), an fvector (the on-disk store), and a list of common-symbols (CFASL compression context). CFASL opcode 76 (`*cfasl-opcode-backed-map*`) serializes one. `*current-backed-map-cache-strategy*` is a dynamic var used during a backed-map operation to specify the LRU strategy.

The `is-map-object-p` defmethod for `backed-map` returns t. The TODO note flags that most of the original defmethods are `missing-larkc` — the polymorphism story for backed-map vs plain hashtable was substantially stripped.

## Where this fits

```
caller (e.g. find-assertion-by-id)
  → kb-object-manager:lookup
    → file-vector-backed-map-w/-cache-get  (file-vector-utilities.lisp)
      → if reference is swapped-out:
        → position-file-vector              (file-vector.lisp)
          → seek index-stream
          → read 4-byte BE offset
          → seek data-stream
        → cfasl-input data-stream            (cfasl.lisp)
        → install payload, update cache strategy
      → return payload
```

The dump-side mirror would be:

```
dumper (stripped)
  → for each entry:
    → cfasl-output payload to data-stream  (records data offset)
    → write 4-byte BE offset to index-stream
```

## Notes for a clean rewrite

- **Drop the two-file split.** The 4-byte index slot inside a separate file is a SubL/Java-era choice that simplified incremental writes (rewriting one slot didn't touch the data file). A single file with a header containing the offset table works just as well; in modern OSes there's no benefit to splitting. (The index file is mmappable, but so is a single file's prefix.)
- **Use 8-byte offsets.** 4 GiB cap is silly — KB images can exceed it. The migration is trivial since the format is private.
- **Or skip the offset table entirely.** Length-prefix each record on the data stream and you don't need an index at all — just a count up front and a linear scan to load. This trades random access for streaming simplicity. Keep the offset table only if random access matters at production scale (and benchmark before deciding).
- **Drop file-vector-reference's sign-bit state encoding.** Use a real enum or a discriminated union. The sign-bit trick saved one fixnum word per reference in 32-bit SubL; on a 64-bit Lisp it's noise.
- **Decide what mutation looks like before touching this code.** The LarKC port can't write file-vectors at all. Cyc's design is presumably append-only with index-slot overwrite + periodic vacuum. A clean rewrite should pick: append-only-with-vacuum, or rewrite-the-whole-file-on-dump (simpler if dumps are infrequent), or a transactional log on top of an immutable base file.
- **Replace `*file-vector-backed-map-read-lock*` with a proper concurrency primitive.** A globally-bindable lock that defaults to nil and is a no-op when nil is fragile. Either always lock (single global) or lock per file-vector (fine-grained). The TODO note is correct that the current state is incoherent.
- **The endianness mismatch (BE index, LE CFASL ints) is a wart.** Pick one.
- **Consider memory-mapping the index file.** Since it's just a packed offset array, mmap + pointer arithmetic is faster than seek+read for hot lookup paths. The data file probably shouldn't be mmapped — too large.
