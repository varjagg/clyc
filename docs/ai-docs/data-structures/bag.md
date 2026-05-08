# Bag (multiset, missing-larkc)

> **Implementation status:** the readme lists `bag` under "Files Exist But the Implementation is missing-larkc" with the note *"A multi-set. Possible to recreate."* The Clyc port preserves the `defstruct`, the constants, three reconstructed iteration macros, and a comment stub for every other declared function. **No bag operations are implemented.** A clean rewrite reimplements the file from the API surface alone — the names, signatures, and wire format are documented; the bodies are not.

A `bag` is a **multiset**: each element has an associated repetition count. Adding the same element twice doesn't dedup — the count goes up. The struct factors the storage in two:

```
(defstruct (bag (:conc-name "BAG-STRUCT-"))
  unique-contents     ; a set-contents — the distinct elements
  repeat-contents     ; a dictionary element → count for repeated elements
  repeat-size         ; cached total of all repeat-contents counts
  test)               ; equality test for membership
```

The two-store split is presumably a watermark scheme: while every element appears once, only `unique-contents` carries data and `repeat-contents` is empty / lightweight. Once any element appears ≥2 times, that element migrates into `repeat-contents` with its count. This is the multiset analogue of `set-contents`'s small-list-vs-keyhash promotion. The watermark for the iterator side is given as `*bag-repeat-contents-iterator-watermark*` = 8.

## When does a bag get created?

In Cyc the engine, a multiset is needed wherever a system tracks **counted occurrences with arbitrary keys**. Likely consumers:

- **Inference statistics** — counting how many times a rule fires in a session, how many proofs hit a particular cardinality, etc.
- **NL processing** — word-frequency, sense-frequency tables.
- **KB diagnostics** — counts of assertions matching some pattern across the KB.

In the LarKC port nothing instantiates a bag — there are zero `make-bag` / `new-bag` / `new-bag-from-elements` call sites outside of `bag.lisp` itself. The file is a vestigial type.

## Public API (from declarations and Internal Constants)

The Java declares these functions; in the port they are all comment stubs unless flagged otherwise. Documenting the *intended* API, since the readme says it's reconstructable:

| Function / macro | Intended behavior |
|---|---|
| `(new-bag &optional size test)` | Allocate. Defaults: size 0, test `*new-bag-default-test-function*` (`#'eql`). |
| `(copy-bag bag)` | Deep copy of unique-contents and repeat-contents. |
| `(new-bag-from-elements elements &optional size test)` | Construct and populate from a list. |
| `(bag-test bag)` | Return the equality test. |
| `(bag-size bag)` | Total count (unique + repeat-size). |
| `(bag-unique-size bag)` | Number of distinct elements. |
| `(bag-empty? bag)` / `(empty-bag-p bag)` / `(non-empty-bag-p bag)` | Empty predicates. |
| `(bag-member? bag element)` | Is `element` in the bag at all? |
| `(bag-member-count bag element)` | How many times? |
| `(bag-matching-element bag element)` | The actual stored element matching under `test` (since `test` may be coarser than identity). |
| `(bag-random-element bag)` | Sample an element weighted by count. |
| `(bag-add bag element)` | Increment count by 1. |
| `(bag-remove bag element)` | Decrement count by 1; clear if it hits zero. |
| `(bag-remove-all bag element)` | Clear count for `element`. |
| `(clear-bag bag)` | Reset to empty. |
| `(new-bag-iterator bag)` | Iterator yielding each element once per occurrence. |
| `(map-bag function bag &optional arg)` | Apply `function` to each element-with-multiplicity. |
| `(bag-element-list bag)` | List with repetitions. |
| `(bag-unique-element-list bag)` | List of distinct elements. |
| `(bag-element-count-list bag)` | List of `(element . count)` pairs. |
| **Macros** | |
| `(do-bag-repeat-contents-unique (element-var element-count repeat-contents &key done) body…)` | **Defined** — iterate the repeat-contents dictionary as `(elt, count)` pairs. Expands to `do-dictionary-contents`. |
| `(do-bag-repeat-contents (element-var repeat-contents &key done) body…)` | **Defined** — yield `element-var` *count* times for each `(elt, count)` pair. Uses `cdotimes`. The expansion has a TODO note that `$list42` (a `(times element contents-iterator)` binding list) is unverified. |
| `(do-bag-unique-contents (element-var bag-unique-contents &key done) body…)` | **Defined** — expands to `do-set-contents`. |
| `(do-bag (element-var element-count bag &key done) body…)` | **Stubbed** — body raises an error at expansion. The shape relies on a `do-bag-repeat-internal` macro-helper (`register-macro-helper` is called) whose expansion site doesn't exist for verification. |
| `(do-bag-unique (element-var bag &key done) body…)` | **Stubbed** — same hazard via `do-bag-unique-internal`. |
| `(map-bag function bag &optional arg)` | Stripped. |

The two macros that are *not* defined (`do-bag` / `do-bag-unique`) intentionally signal an error at expansion time rather than guess at the dispatch shape — this matches the project rule against inventing function bodies. Each is a few lines from being correct but the surrounding orphan-constant evidence (`$list59`, `$list52`, `$sym54`, etc.) doesn't pin down the exact form.

## Sub-structure operations (all stripped)

The `unique-contents` is a set-contents and the `repeat-contents` is a dictionary; the file declares per-substore wrappers (`bag-repeat-contents-add`, `bag-unique-contents-member?`, etc.) so callers don't have to know the storage type. Every one is a comment stub.

## CFASL

| Opcode | Symbol | Reader / Writer |
|---|---|---|
| 62 | `*cfasl-opcode-bag*` | `cfasl-input-bag` (stripped), `cfasl-output-object-bag-method` (`missing-larkc 6694`) |

The setup form does call `(register-cfasl-input-function *cfasl-opcode-bag* 'cfasl-input-bag)`, which means a dump containing a bag would dispatch to a missing function and fail at load. The likely on-wire shape (per the file's comment on `cfasl-output-object-bag-method`): `opcode, unique-size, total-size, test, then each (element, count) pair`.

## Where bag is consumed

**Nowhere.** A grep for `\bbag\b` or `\bbag-` across `larkc-cycl/` excluding `bag.lisp` finds two hits, both incidental:

- `system-version.lisp` — version string contains the word "bag." Not an API reference.
- `inference/harness/inference-czer.lisp` — also a string match in a comment, not an API call.

Bag has zero working call sites in the port. Its existence is preserved entirely so that:

1. The defstruct exists (the symbol can be referenced by other files, though none do).
2. The CFASL opcode is reserved (so future dump formats don't reuse 62).
3. A reader knows what to reconstruct.

## Setup phase

```
(toplevel
  (register-macro-helper 'do-bag-repeat-internal 'do-bag-unique)
  (register-macro-helper 'do-bag-unique-internal 'do-bag-unique)
  (register-cfasl-input-function *cfasl-opcode-bag* 'cfasl-input-bag))
```

The macro-helper registrations name two functions that don't have bodies; they exist as design surface only.

## Notes for a clean rewrite

- **Replace with the host's multiset / Counter / `Map<K, Int>`.** The two-store optimization is premature — count = 1 vs ≥2 is a one-bit distinction that doesn't justify a separate set-contents instance.
- **One backing structure: `Map<element, count>` with `count ≥ 1` invariant.** `bag-add` increments, `bag-remove` decrements (deleting at 0), `bag-size` is `sum(values)`, `bag-unique-size` is `len(map)`. Every API function falls out of this.
- **`bag-matching-element` is non-trivial.** When `test` is `equal`, two distinct cons-equal lists hash to the same key but only one is stored. Returning *the stored representative* matters for callers that want a canonical handle. Don't lose this in the rewrite.
- **`bag-random-element` is weighted random sampling.** Naive implementation: walk keys, accumulate counts, pick by total. Fancier: alias method or precomputed CDF. Pick based on whether sampling is on a hot path.
- **CFASL opcode 62 stays.** Even if no dump currently contains a bag, the opcode is reserved. A clean rewrite either implements input/output for it or removes the registration entirely (since nothing produces it).
- **The macros `do-bag` and `do-bag-unique` need to be reconstructed.** Their expansion shape (single dispatch on whether the bag has nonempty repeat-contents) is straightforward once a real implementation exists; the port couldn't write them because there are no expansion sites to verify against.
- **Watermark `*bag-repeat-contents-iterator-watermark*` = 8.** This is documented as "back-of-the-envelope" math in the source; in a clean rewrite, the value is irrelevant if the dual-store optimization is dropped.
- **`bag.java` is in `larkc-java/`** — the original SubL output. A reimplementer can pull behavioral details from there if the API contracts here are ambiguous. The Lisp port can't because the bodies were stripped, but the Java retains call structures (with `handleMissingMethodError` placeholders in some methods).
