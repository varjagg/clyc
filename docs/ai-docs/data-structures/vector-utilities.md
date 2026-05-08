# Vector utilities

A 53-line file with **two functions**. Everything else SubL had for vectors is either a CL primitive (`length`, `aref`, `make-array`, `replace`, `copy-seq`, `vector-push-extend`) or has been elided here. The file exists to provide two convenience operations CL doesn't ship in its core sequence API.

## Public API

| Function | Purpose |
|---|---|
| `vector-elements vector &optional start-index` | Convert a vector to a list, starting at `start-index` (default 0). |
| `extend-vector-to vector new-length &optional initial-value` | Allocate a fresh vector of `new-length` whose first `(length vector)` cells are copied from `vector`, with the rest filled by `initial-value`. |

`make-vector` (used by `extend-vector-to`) is a SubL primitive in `subl-support.lisp`, not defined here — it's `(make-array length :initial-element initial-value)`. The "vector" here means a simple, non-adjustable, non-fill-pointered CL vector — Cyc uses these as fixed-size random-access arrays, not as dynamic stacks.

## Why these two functions

- **`vector-elements`** is sugar for "I have a vector, I need a list now." CL has `(coerce vector 'list)` which does this exactly when `start-index` is 0; the helper exists only because the optional `start-index` argument lets you skip a prefix without an additional `subseq` call. The TODO-free body is `(loop for i from start-index below (length v) collect (aref v i))`.
- **`extend-vector-to`** is "grow this fixed-size vector to a new size, padding with a default." This is the operation `vector-push-extend` would do for adjustable vectors, but Cyc's vectors aren't adjustable — they're fixed-size with a manual reallocate-and-copy step on growth. The helper centralizes that pattern so callers don't open-code `make-array` + `replace`.

The second function is the more interesting one. It reflects a Cyc style choice: rather than make every vector adjustable (which adds an indirection on every access), Cyc uses fixed simple vectors and reallocates explicitly when a slot table needs to grow. The use site in inference (`tactic-properties-vector` in `inference-datastructures-strategy.lisp`) is exactly this pattern: when a new tactic-property index exceeds the current vector length, the strategy struct's vector is reallocated to fit.

## What uses these

Both functions are **near-orphans** in the surviving port:

- `extend-vector-to` has one consumer outside this file: `inference/harness/inference-datastructures-strategy.lisp` line 698, growing a tactic-properties vector when a property at a higher index than the current length is set.
- `vector-elements` has no surviving callers in `larkc-cycl/`. Originally it was probably used by debugging / printing code that was LarKC-stripped, plus a few CFASL output paths that were rewritten to walk the vector directly with `aref`.

The minimal use is consistent with vector-utilities being scaffolding for a library that mostly didn't ship. Cyc's full implementation likely had per-element insertion, sorted-vector binary search, parallel-vector zip, and similar — all stripped.

## Notes for a clean rewrite

- **Drop `vector-elements`.** `(coerce vector 'list)` covers the no-prefix case. For the prefix-skipping case, `(coerce (subseq vector start-index) 'list)` is two more characters. There is no caller to support.
- **Decide whether fixed-size + reallocate is the right pattern.** CL has adjustable vectors with fill pointers (`make-array :adjustable t :fill-pointer 0`) and `vector-push-extend`, which gives the same growth semantics with one less function. The Cyc style chose simple vectors for raw-access speed; a clean rewrite should benchmark before keeping it.
- **If keeping fixed-size growth, keep `extend-vector-to`** — but consider shipping a one-shot reallocator that handles the realloc-when-too-small logic at the use site, so the call site reads `(grow-to vector index)` rather than open-coding the length test plus reallocation. The strategy.lisp consumer already encodes that wrapper inline.
- **Element type.** Neither function preserves the element-type of the source vector — both produce general (T-element) vectors. A clean rewrite that uses specialized `(unsigned-byte 8)` or `(simple-array fixnum (*))` vectors would need this preserved or it silently boxes everything.
