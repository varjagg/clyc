# Interval span (entirely missing-larkc)

> **Implementation status:** of 18 active `declareFunction` entries in the Java, exactly **one** has a body (`interval-span-print-function-trampoline`) and that body is `handleMissingMethodError 29643`. The remaining 17 are LarKC-stripped. Per the project's no-invented-bodies rule, the Lisp port is entirely defstruct + comment stubs + an empty hash table. **Nothing in the LarKC codebase references `interval-span` outside its own file** (a grep across `larkc-cycl/` confirms zero callers — only `system-version.lisp` lists the file by name). The file is design surface with no implementation and no consumers.

An `interval-span` is a **closed numeric range** `[start, end]` — the clean abstraction over a pair of comparable values that delimit an interval. The struct has two slots (`start`, `end`, conc-name `INT-SPAN-`) and the file declares the natural API for ranges: length, total ordering, precedence, and subsumption (does interval A contain interval B?). A hash-consing table (`*interval-span-table*`) is reserved so equal `(start, end)` pairs share an instance.

## What it's *probably* for in real Cyc

The interval-span API surface (`interval-span-precedes?`, `interval-span-subsumes?`, `interval-span-length`, `interval-span->`, `interval-span-<`) is exactly the vocabulary of **Allen's interval algebra** for temporal reasoning. The KB has heavy use of temporal predicates (`#$startsAfterStartingOf`, `#$temporallySubsumes`, etc.) and an interval-span is the obvious in-memory representation for a (universal-date-start, universal-date-end) pair after evaluating one of those predicates. The hash-cons table makes intersection / containment cheap because two intervals with identical bounds become `eq`.

Less likely but not ruled out: numeric ranges (e.g. for the cardinality cache in `cardinality-estimates.lisp`), or page-byte ranges in the file-vector. The naming (`PRECEDES`, `SUBSUMES`) tilts strongly toward temporal use.

In the LarKC port none of these consumers exist — neither the temporal-reasoning code, nor cardinality, nor file-vector, calls `interval-span-*`. The file is a pure design relic.

## API surface (all stubbed unless noted)

| Function / variable | Status | Intended behavior |
|---|---|---|
| `(make-interval-span)` keyword constructor | Provided by defstruct | Allocate. The Java had a `(&optional arglist)` plist-walker; CL's keyword constructor stands in. |
| `(interval-span-p object)` | Provided by defstruct | Predicate. The Java has a `$interval_span_p$UnaryFunction` override pointing at `missing-larkc 29641`. |
| `(int-span-start span)` / `(int-span-end span)` | Provided by defstruct | Slot accessors. |
| `(_csetf-int-span-start span value)` / `-end` | Native CL setf | Slot setters. |
| `(print-interval-span span stream depth)` | **Stub** | Custom printer; `interval-span-print-function-trampoline` body is `missing-larkc 29643`, so CL's default `print-object` is used instead. |
| `(lookup-interval-span start end)` | **Stub** | Hash-cons lookup against `*interval-span-table*`. |
| `(new-interval-span start end)` | **Stub** | Allocate-and-install — likely `(or (lookup-interval-span …) <fresh interval and install>)`. |
| `(get-interval-span start end)` | **Stub** | Public hash-cons accessor — same as `new-interval-span` modulo whether installation happens. |
| `(interval-span-start span)` / `(interval-span-end span)` | **Stub** | Public-facing accessors that wrap the `INT-SPAN-` ones (likely with type-checking that's stripped). |
| `(interval-span-length span)` | **Stub** | `(- end start)`. |
| `(interval-span-> span1 span2)` / `(interval-span-< …)` | **Stub** | Total ordering. Probably lex on `(start, end)`. |
| `(interval-span-precedes? span1 span2)` | **Stub** | Allen's `<` (precedes): `(end1 < start2)`. |
| `(interval-span-subsumes? span1 span2)` | **Stub** | Allen's `during` / `contains`: `start1 ≤ start2 ∧ end2 ≤ end1`. |
| `*dtp-interval-span*` = `'interval-span` | Constant | Type tag for dispatch (legacy SubL idiom; CL doesn't need it). |
| `*interval-span-table*` | Empty hash table (eql) | Hash-cons table keyed by some encoding of `(start, end)` — probably an integer formed from the two bounds when both are integers (the keyspace is `eql` so `(start, end)` cons keys would not collapse correctly; the original Java likely encoded the pair into a single integer or used `:test 'equal`). The LarKC port copies the Java verbatim, which means as-written the table can't be used with cons keys. |

## Why hash-cons?

For temporal subsumption to be efficient, "is interval A contained in interval B" should be answerable in constant time when A == B. Hash-consing makes equal intervals identical (`eq`), so `(eq a b)` short-circuits the containment check on the common case. The same trick collapses memory when many predicates produce the same pair of universal-dates (e.g. every assertion about Year 2000 produces `[20000101, 20001231]`).

The LarKC port has the table but no installer, no lookup, and no eviction policy. A clean rewrite either implements full hash-consing (with a real `:test 'equal` test on cons keys, or a packed-integer encoding) or drops the table and uses fresh allocations.

## Why the dual `int-span-` / `interval-span-` accessors?

`int-span-start` and `interval-span-start` are *separate* declared functions in the Java. The defstruct provides the short form (`int-span-`); the long form was a hand-written wrapper that probably added a type-check or ran the value through a normalisation step. Both are stripped, so the port keeps only the defstruct accessors.

A clean rewrite should use one accessor name. The dual API is a SubL-ism with no surviving justification.

## Notes for a clean rewrite

- **Drop the file or rebuild from scratch.** The LarKC port has nothing to cargo-cult. The API surface and the hash-cons design are documented above; an implementer can write the whole file from the table.
- **If temporal reasoning is the consumer, integrate with `local-time` or the host's date library.** Don't carry universal-time integers into the interval representation — use proper time objects with timezone awareness. Cyc's `numeric-date-utilities.lisp` is the lower-numerical-bound layer; an interval-span over `local-time:timestamp` is the user-facing layer.
- **Hash-consing is right when intervals repeat heavily.** For temporal predicates pulled from the KB this is true. Use a real concurrent map keyed by `(start, end)` pair-equality, or by a packed 64-bit encoding of (`encode-universal-second(start)`, `encode-universal-second(end)`) when both fit.
- **Implement Allen's 13 relations once, not five.** The port declares `precedes?` and `subsumes?`. The full set is precedes / meets / overlaps / starts / during / finishes (and inverses) plus equals — total 13. Build them out of `<` and `=` on the bounds; each is one line. Keep the API minimal at first and grow only when a consumer actually needs `meets?` or `overlaps?`.
- **The `*dtp-interval-span*` type-tag constant is a SubL legacy.** CL's type system doesn't need it. Drop it.
- **The custom printer is missing-larkc 29643.** CL's default print-object yields `#S(INTERVAL-SPAN :START x :END y)` which is fine — no work needed unless a tighter format (`[x..y]`) is wanted in transcripts.
