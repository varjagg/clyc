# Bijection (key↔value bidirectional map, missing-larkc)

> **Implementation status:** the readme lists `bijection` under "Files Exist But the Implementation is missing-larkc" with the note *"A key/value mapping that also supports reversed value→key lookups. A-list for small maps, pair of hashtables for large maps. No given implementation, but can be easily recreated."* The Clyc port preserves the `defstruct`, the high/low watermarks, two reconstructed iteration macros, and a comment stub for every other declared function. **No bijection operations are implemented.**

A bijection is a **two-way map**: every `(key, value)` pair can be looked up either by key (`bijection-lookup`) or by value (`bijection-inverse-lookup`), in O(1) amortized for the hashtable backend or O(n) for the alist backend.

```
(defstruct bijection
  size                 ; cached element count
  database             ; key → value store (alist or hashtable, depending on style)
  inverse-database     ; value → key store (alist or hashtable, depending on style)
  test)                ; equality test for both directions
```

Every mutation has to touch both stores in lockstep; the bijection invariant is that the two stores represent the inverse of each other.

## The two-style design

Bijection is a **promotion-style polymorphic container**: starts as a-list (one alist for forward, another for inverse), promotes to a pair of hashtables once size crosses `*bijection-high-water-mark*` (40), demotes back if the alist becomes denser than `*bijection-low-water-mark*` (30). The hysteresis prevents thrashing at the boundary.

Each operation has two implementations — `*-alist-style` and `*-hashtable-style` — and a top-level dispatcher that picks the right one based on the bijection's current style. Every public operation runs through this dispatch:

| Public function | Forward-style helpers (stripped) | Inverse-style helpers (stripped) |
|---|---|---|
| `bijection-lookup` | `bijection-lookup-alist-style`, `bijection-lookup-hashtable-style` | n/a |
| `bijection-enter` | `bijection-enter-alist-style`, `bijection-enter-hashtable-style` | n/a |
| `bijection-remove` | `bijection-remove-alist-style`, `bijection-remove-hashtable-style` | n/a |
| `bijection-inverse-lookup` | n/a | `bijection-inverse-lookup-alist-style`, `bijection-inverse-lookup-hashtable-style` |
| `bijection-inverse-enter` | n/a | `bijection-inverse-enter-alist-style`, `bijection-inverse-enter-hashtable-style` |
| `bijection-inverse-remove` | n/a | `bijection-inverse-remove-alist-style`, `bijection-inverse-remove-hashtable-style` |

The promotion / demotion happens through `make-hashtable-bijection-from-alist` and `make-alist-bijection-from-hashtable` (both stripped). The expected pattern: each `enter`/`remove` checks size against the watermark and triggers a one-shot conversion if the threshold is crossed.

`bijection-style` (an active declareFunction with no body) is the introspection helper — returns `:alist` or `:hashtable` so the dispatcher knows which style to call. The reconstructed `do-bijection` macro depends on this function existing.

## Public API (intended, from declarations)

| Function / macro | Intended behavior |
|---|---|
| `(new-bijection &optional initial-size test)` | Allocate empty bijection. Defaults: size 0, test `#'eql`. Backing starts as alist style. |
| `(clear-bijection bijection)` | Reset to empty. |
| `(bijection-empty-p bijection)` / `(non-empty-bijection-p bijection)` | Empty predicates. |
| `(bijection-lookup bijection key &optional default)` | key → value, with optional default. |
| `(bijection-inverse-lookup bijection value &optional default)` | value → key, with optional default. |
| `(bijection-enter bijection key value)` | Insert/replace `(key, value)` pair. Both directions. |
| `(bijection-inverse-enter bijection value key)` | Same, with arguments reversed. (Convenience.) |
| `(bijection-remove bijection key)` | Remove the pair containing `key`. |
| `(bijection-inverse-remove bijection value)` | Remove the pair containing `value`. |
| `(bijection-keys bijection)` | All keys. |
| `(bijection-values bijection)` | All values. |
| `(bijection-to-alist bijection)` | List of `(key . value)` pairs. |
| `(bijection-to-hashtable bijection)` | A standalone forward hashtable. |
| `(new-bijection-iterator bijection)` | Iterator yielding `(key, value)` tuples. |
| `(print-bijection-contents bijection &optional stream)` | Pretty-print. |
| **Macros** | |
| `(do-bijection (key value bijection &key done) body…)` | **Defined** — dispatches on `(do-bijection-style bijection)`: `:alist` calls `do-alist`, `:hashtable` calls `do-hash-table`, otherwise `bijection-style-error`. |
| `(do-bijection-inverse (value key bijection &key done) body…)` | **Defined** — same shape, iterating `do-bijection-inverse-database`. Note the variable order is `(value key)` — reversed from the forward macro. |

The two iteration macros are the only fully-reconstructed code in the file. Their structural inputs (Internal Constants `$list30`, `$list43`, the dispatch helpers `$sym37$DO_BIJECTION_STYLE`, `$sym38$DO_ALIST`, `$sym40$DO_HASH_TABLE`) gave enough information to write them with confidence. The three helpers they call (`do-bijection-style`, `do-bijection-database`, `do-bijection-inverse-database`) are active declareFunctions with no body — they're macro-expansion-time helpers that are themselves stripped.

The setup form registers the helper symbols:

```
(toplevel
  (register-macro-helper 'do-bijection-style 'do-bijection)
  (register-macro-helper 'do-bijection-database 'do-bijection)
  (register-macro-helper 'do-bijection-inverse-database 'do-bijection))
```

## CFASL

There is no `*cfasl-opcode-bijection*` constant in the file and no `register-cfasl-input-function` call. Bijection has **no CFASL serialization** in the LarKC port. If a dumped KB needed to round-trip a bijection, it would have to be reduced to a pair of dictionaries by the dumper.

## Where bijection is consumed

**Nowhere.** A grep for `bijection` across `larkc-cycl/` excluding `bijection.lisp` returns zero call sites. Like `bag`, the file exists for design completeness and to reserve the name; nothing in the port creates or queries a bijection.

In Cyc the engine, a bijection would be the natural fit for:

- **Constant-name ↔ constant-id maps** at startup — but that work is done by the trie + id-index combo (see [tries](../runtime/) and [id-index](./)), not a bijection.
- **Externalization tables** — encapsulation maps a runtime object id to a portable name and back. The encapsulation system uses dedicated structures rather than a generic bijection.
- **Skolem-name ↔ skolem-term maps**, **rule-name ↔ rule maps**. Likely candidates that don't currently use the type.

## Notes for a clean rewrite

- **Use two host hashtables.** The polymorphic alist/hashtable promotion is not worth the complexity. Modern hashtables are cheap enough at small sizes that the watermark scheme adds nothing. A `(forward, inverse)` pair behind a thin wrapper covers every operation.
- **The wrapper enforces invariants the two-map approach doesn't naturally have.** Specifically: `(enter K V)` must `(remove K)` first if `K` is already mapped (otherwise the inverse side keeps an old `V'`-pointing-back-to-`K` slot pointing at a now-shadowed K), and similarly `remove` must be paired. The naive "two hashtables" implementation is buggy without those guard rails.
- **Decide on duplicate-value behavior.** A bijection means values are unique just like keys; `(enter K1 V), (enter K2 V)` should remove the K1 mapping. Spec this explicitly — the SubL behavior isn't visible from the names.
- **Drop the `*-style` dispatch and helpers.** `bijection-style`, `do-bijection-style`, `do-bijection-database`, `do-bijection-inverse-database`, `bijection-style-error` — none of these survive a single-style implementation.
- **The `do-bijection` macro can keep its shape** (`(key value bijection)`) but with no style dispatch — just a `(maphash (lambda (k v) …) (bijection-forward b))`. `do-bijection-inverse` similarly maps the inverse table.
- **Add a CFASL opcode** if the rewrite needs to dump bijections. Reserved opcodes 62 (`bag`) and 60–61 (`set`/`dictionary`) are taken; pick a fresh number.
- **High and low watermarks (40 and 30) are tuning constants for an obsolete scheme.** Drop both `*bijection-high-water-mark*` and `*bijection-low-water-mark*` along with the promotion logic.
- **`bijection.java`** in `larkc-java/` is the SubL-output reference. A clean rewrite that wants behavioral details (especially the exact replace-on-duplicate-key semantics) can mine it.
