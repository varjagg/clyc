# Number utilities (numbers, dates, scientific numbers)

Three small files of arithmetic helpers that exist because **SubL did not give CL's full numeric tower**: SubL had no rationals, did not have CL's `format` directives for fixed-width integer output, and had no first-class support for "either a number or `:positive-infinity`" — the third being a thing the inference tactician tracks as a productivity score. The kept utilities in `number-utilities.lisp` are the ones whose semantics are *not* native CL — `potentially-infinite-*` arithmetic, `significant-digits` rounding, and a few small wrappers that exist mostly to be passed as `#'function` arguments. `numeric-date-utilities.lisp` is a packed-integer date encoding used by KB temporal predicates. `scientific-numbers.lisp` is mostly stripped — the file is a registration façade around an EL formula type.

| File | Lines | Status |
|---|---|---|
| `number-utilities.lisp` | 397 | Mostly implemented; 7 `missing-larkc` infinite-arithmetic edge cases. |
| `numeric-date-utilities.lisp` | 305 | Mostly implemented; templated date/time formatting. |
| `scientific-numbers.lisp` | 74 | One real predicate, every other function commented-out (no body). |

> The readme calls out `fraction-utilities` as **elided in favor of CL's native rationals**. The kept files document utilities whose semantics are *not* obvious one-liners over CL.

---

## `number-utilities.lisp`

### Why these wrappers exist

The file's own comment is candid:

> A ton of these functions are very simplistic. I wonder if they're used to pass around as lambdas. Else, it's a lot easier to just type out their effects than remember which fiddly bits are in here under what name.

That's right: `2*`, `onep`, `encode-boolean`, `decode-boolean`, `bytep`, `zero-number-p` are **named function values for HOFs**. SubL didn't have `(constantly 1)` or `(lambda (x) (* 2 x))` as a syntactic shorthand the same way CL does, so a named `2*` was idiomatic. Most stay one-line `(:inline t)` defuns.

The non-trivial groups are:

- **Bit-packing helpers** (`get-bit`, `set-bit`) — used by `inference/harness/inference-datastructures-problem-link.lisp` to pack flags into a single fixnum (avoids per-flag boxing).
- **`significant-digits`** — Cyc's "round to N significant digits" used by `system-benchmarks.lisp` to print elapsed-time / efficiency / CycLOPs numbers cleanly. Has a sub-helper `significant-digits-optimize-float` that picks the shortest decimal representation among nearby float candidates (the `loop for delta from -2 below 3` block).
- **Potentially-infinite arithmetic** — see below; the inference tactician relies on this.
- **`maximum`, `median`, `median-sorted`** — list reductions with optional key. Median uses `sort` (mutating a copy), so allocates.
- **`decode-integer-multiples`** — given an integer and a list of moduli, reduce by each modulus in turn. Used by `decode-elapsed-seconds` to split seconds into `(secs, mins, hours, days)`.
- **Checksum constants** — `*largest-prime-by-binary-width*` is an alist of (bit-width → largest prime under 2^width). `*checksum-base*` is the prime corresponding to `*checksum-implementation-width*`. The actual checksumming functions are stripped; only the table and the running-state defparameters (`*checksum-sum*`, `*checksum-length*`) remain. Likely used by GUID generation or assertion-content fingerprinting in real Cyc.

### Potentially-infinite numbers

The "potentially-infinite" group is the one piece of this file that **must not be replaced by CL natives** — at least not directly. The representation:

| Value | Encoding |
|---|---|
| Any number | the number itself |
| Positive infinity | the keyword `:positive-infinity` |
| Negative infinity | the keyword `:negative-infinity` |

This isn't CL's `single-float-positive-infinity` — those are special floats that propagate through `+ * /`. `:positive-infinity` is a keyword sentinel; every arithmetic op has to dispatch on it explicitly. That's what every `potentially-infinite-number-*` function does.

| Function | Implemented? |
|---|---|
| `(infinite-number-p object)` | Yes |
| `(positive-infinity-p object)` / `(negative-infinity-p object)` / `(positive-infinity)` | Yes |
| `(potentially-infinite-number-p object)` / `-=` / `-<` / `->` / `-max` / `-min` | Yes |
| `(potentially-infinite-number-plus n1 n2)` | Partial — only the both-finite branch works; every infinity branch is `missing-larkc 31726…31745`. |
| `(potentially-infinite-number-times n1 n2)` | Partial — same |
| `(potentially-infinite-number-divided-by n1 n2)` | Partial — same |
| `(potentially-infinite-integer-=)` / `-<` / `->` / `-<=` / `-plus` / `-times` | Yes — these defer to the `-number-` versions; integer-vs-number distinction is documentation only |
| `(potentially-infinite-integer-times-number-rounded i n)` | Yes — multiplies then truncates, infinity-preserving |
| `(potentially-infinite-integer-divided-by-number-rounded i n)` | Yes |

The author's TODO calls out the design choice: SBCL has real infinite floats in `sb-ext`, and using them would let `+ * /` work without dispatch. The downsides are (a) CFASL serialization would have to learn IEEE infinities, (b) `:positive-infinity` reads as a keyword, which is human-friendly in dumps and in inference parameters. The current keyword-sentinel design is the conscious pick.

#### Who consumes potentially-infinite numbers

The inference engine's productivity / happiness / unhappiness scores. Greppable hits in `inference/harness/`:

- `inference-datastructures-enumerated-types.lisp` — productivity has `:positive-infinity` as a normal value; comparisons go through `potentially-infinite-integer-<`.
- `inference-tactician.lisp`, `inference-tactician-utilities.lisp`, `inference-heuristic-balanced-tactician.lisp`, `inference-balanced-tactician-motivation.lisp`, `removal-tactician-motivation.lisp` — happiness/unhappiness ordering and scaling.
- `inference-strategic-heuristics.lisp` — uselessness/usefulness scoring.
- `inference-parameters.lisp` — defaults like `:max-problem-count :positive-infinity`.
- `inference-datastructures-inference.lisp` — pad-seconds (max wall-time) defaults to `:positive-infinity` for "no limit".
- `ask-utilities.lisp` — query timeout / cardinality default.

Use of `infinite-number-p` is the type-test inference uses to decide "is this score already at the top of the lattice."

### Other small constants

| Constant | Value | Purpose |
|---|---|---|
| `*e*` | 2.718281828459045d0 | Base of natural log. |
| `*large-immediate-positive-integer*` | `(ash 1 26)` = 67108864 | Threshold below which integers are guaranteed unboxed (immediate fixnum). |
| `*maximum-float-significant-digits*` | 16 | Used by `significant-digits` to early-exit when the requested precision exceeds float precision. |
| `*valid-number-string-characters*` | `"0123456789.-+deDE"` | Char set for parsing a numeric literal. |
| `*valid-exponent-markers*` | `"deDE"` | The `e`/`E`/`d`/`D` markers (single-vs-double precision). |
| `*valid-sign*` | `"+-"` | |
| `*hex-to-dec-table*` | alist of `(char . digit)` for `a-f`/`A-F` | Lookup for hex parsing. |
| `*largest-prime-by-binary-width*` | 64-row alist | For checksum modulus selection. |
| `*checksum-base*` | derived | Largest prime under `2^*checksum-implementation-width*`. |
| `*checksum-initial-value-sum*` / `-length*` | 1, 0 | Initial values for a Fletcher-style checksum running state. |

### Cyc API

`(register-cyc-api-function 'nil-or-integer-p '(object) "Return T iff OBJECT is either an integer or NIL" 'nil '(booleanp))` — the only Cyc-API export from this file. `nil-or-integer-p` itself is *not defined here*; the registration assumes it's defined elsewhere.

### Where number-utilities is consumed

Spot-check of grep results:

- `2*`, `onep`, `bytep`, `zero-number-p`, `decode-boolean` — light direct use.
- `encode-boolean` — `assertions-low.lisp` (encoding gaf-flag).
- `set-bit` / `get-bit` — `inference/harness/inference-datastructures-problem-link.lisp` for flag-packing.
- `percent` — `kb-utilities.lisp` (cache-coverage diagnostics; multiple call sites).
- `significant-digits` — `system-benchmarks.lisp` (4 call sites).
- `maximum` — outside this file no callers found in `larkc-cycl/` (consumers may exist in inference but use direct `reduce #'max`).
- `median` — `system-benchmarks.lisp`.
- `extremal` — defined elsewhere; this file uses it (`set-utilities.lisp`, `mt-vars.lisp` are the real consumers).
- `potentially-infinite-*` — extensive use in inference (see above).
- `decode-elapsed-seconds`, `*seconds-in-*` constants, `elapsed-time-abbreviation-string`, `timestring`, `universal-timestring`, `get-utc-time-with-milliseconds`, `get-universal-date`, `encode-universal-date`, `universal-time-seconds-from-now`, `elapsed-internal-real-time` — see numeric-date-utilities below.

---

## `numeric-date-utilities.lisp`

### Why a packed-integer date encoding

CL has `decode-universal-time` / `encode-universal-time` (POSIX-equivalent epoch seconds). Cyc layers on top: a "**universal date**" is the 8-digit integer `yyyymmdd` (e.g. `19660214`); a "**universal second**" is the 6-digit integer `hhmmss`. They are integers because the KB stores them in assertions, and integer encoding round-trips cleanly through CFASL while remaining human-readable in dumps.

| Function | Purpose |
|---|---|
| `(get-universal-date &optional universal-time time-zone)` | Current date as `yyyymmdd` integer. |
| `(encode-universal-date day month year)` | Build that integer. Negative year → negate the result (so dates BCE round-trip). |
| `(universal-date-p object)` | Validate format (1≤month≤12, day≤31). |
| `(get-universal-second &optional universal-time)` | Current `hhmmss` integer. |
| `(encode-universal-second second minute hour)` | Build it; asserts ranges 0–59. |
| `(universal-second-p object)` | Validate format. |

Hand-rolled because the KB needs to **assert** "Event X occurred on date 19660214" — and that has to be a serializable integer in a CycL formula, not a Lisp `local-time:timestamp` opaque object.

### Templated date/time string formatting

Every Cyc-side date string goes through templates: `"mm/dd/yyyy hh:mm:ss"`, `"yyyymmddhhmmss"`, etc.

| Function | Purpose |
|---|---|
| `(timestring &optional ut)` | "mm/dd/yyyy hh:mm:ss" of a universal time. |
| `(universal-timestring &optional ut)` | Tightly-packed "yyyymmddhhmmss". Preferred for filenames. |
| `(encode-timestring sec min hr d mo yr)` | Build "mm/dd/yyyy hh:mm:ss" from components. |
| `(encode-universal-timestring sec min hr d mo yr)` | Build the packed form. |
| `(encode-datetime-string-from-template ms s mn hr d mo yr template)` | Generic templated formatter; splits template into a date piece and a time piece by whitespace, dispatches to `encode-date-from-template` / `encode-time-from-template`. |
| `(encode-date-from-template d mo yr template)` | Recursive — match leading run of date tokens (yyyy, yy, mm, dd) and emit zero-padded substring; recurse on the rest. |
| `(encode-time-from-template ms s mn hr template)` | Hard-coded match against the five accepted time templates: `"hh:mm:ss"`, `"hh:mm"`, `"hh:mm:ss.mmm"`, `"hh:mm:ss.mm"`, `"hh:mm:ss.m"`. |
| `(valid-date-template-char ch)` / `valid-date-separator` / `valid-year-token` / `valid-month-token` / `valid-day-token` | Char-class predicates used by the recursive matcher. |
| `(date-template-p template)` / `(time-template-p template)` | Whole-template validators. |
| `(n-digit-template-element-p template n token-checker separator-checker)` | The matcher primitive: does `template` start with `n` chars passing `token-checker`, then either end or have a separator? |
| `(elapsed-time-abbreviation-string elapsed-seconds)` | "5 days 03:42:17" / "03:42:17" / "42:17" depending on magnitude. Used in `dumper.lisp` to print KB-load timings. |
| `(decode-elapsed-seconds elapsed-seconds)` | (seconds, minutes, hours, days) tuple from a duration. Built on `decode-integer-multiples` from number-utilities. |
| `(get-utc-time-with-milliseconds)` | Current UTC ms-since-epoch. Built by combining `get-universal-time` (second resolution) with `get-internal-real-time` (sub-second). Used by `java-api-kernel.lisp` for timeout deadlines. |
| `(elapsed-internal-real-time reference &optional comparison)` | Elapsed `internal-time-units`. |
| `(elapsed-internal-real-time-to-elapsed-seconds elapsed)` | Divide by `internal-time-units-per-second`. |
| `(internal-real-time-p object)` | Type test: non-negative integer. |
| `(time-from-now seconds)` | Legacy alias for `universal-time-seconds-from-now`. |
| `(universal-time-seconds-from-now seconds &optional reference)` | Add seconds to `(get-universal-time)` (truncating fractional). |

### Constants

| Constant | Value | Note |
|---|---|---|
| `*seconds-in-a-leap-year*` | 31622400 | "True" |
| `*seconds-in-a-non-leap-year*` | 31536000 | "Also True" |
| `*seconds-in-a-week*` | 604800 | |
| `*seconds-in-a-day*` | 86400 | |
| `*seconds-in-an-hour*` | 3600 | |
| `*seconds-in-a-minute*` | 60 | |
| `*minutes-in-an-hour*` | 60 | |
| `*hours-in-a-day*` | 24 | |
| `*months-in-a-year*` | 12 | |
| `*month-duration-table*` | `(31 28 31 30 …)` | Days per month (non-leap). |
| `*number-wkday-table*` | `((0 . "Mon") … (6 . "Sun"))` | Weekday names. Note Mon=0, not Sun=0 (ISO 8601). |
| `*number-month-table*` | `((1 . "Jan") … (12 . "Dec"))` | Month names. |
| `*julian-date-reference*` | `(20010801 . 2452122.5d0)` | Anchor for Julian-date offset computation. |
| `*julian-offsets*` | nil | An alist meant to hold "days to add to get Julian date, with different precisions"; the populator is stripped. |
| `*seconds-in-a-century*` | 3155760000 | Marked "HACK" in the source. |
| `*seconds-in-an-odd-millenium*` | 31556908800 | |
| `*seconds-in-an-even-millenium*` | 31556995200 | |

### Where numeric-date-utilities is consumed

- `dumper.lisp` — timestamps every load/dump message with `timestring` / `elapsed-time-abbreviation-string`.
- `task-processor.lisp` — `(timestring)` prefixes every transcript entry.
- `control-vars.lisp` — `cyc-universal-time` is the boot timestamp from `universal-timestring`.
- `fi.lisp` — `get-universal-date` for "today's date" defaults in FI calls.
- `operation-queues.lisp` — `get-universal-date` to record creation date on queued operations.
- `java-api-kernel.lisp` — `get-utc-time-with-milliseconds` for ms-resolution deadlines on async API calls.
- `backward.lisp` — `elapsed-internal-real-time` for inference timing.
- `inference/harness/inference-datastructures-inference.lisp` — `elapsed-internal-real-time` and `-to-elapsed-seconds` for inference-elapsed reporting.

---

## `scientific-numbers.lisp`

### Status

Of 22 declared functions, **one** has a body in the LarKC port: `scientific-number-p`. The rest (`new-scientific-number`, `scientific-number-significand`, `scientific-number-exponent`, `cyc-scientific-number-from-string`, `cyc-scientific-number-to-string`, `cyc-scientific-number-significant-digit-count`, etc.) are commented declareFunctions — no body in Java, no port to CL. The setup phase registers the `cyc-scientific-number-*` family of names as KB functions via `register-kb-function`.

### What's surviving: the predicate

```lisp
(defun scientific-number-p (object)
  "[Cyc] We check that object is a nat with functor #$ScientificNumberFn
and two integer args."
  (and (el-formula-with-operator-p object #$ScientificNumberFn)
       (el-binary-formula-p object)
       (integerp (formula-arg1 object))
       (integerp (formula-arg2 object))))
```

A "scientific number" in Cyc is **not a struct** — it's a CycL formula `(#$ScientificNumberFn significand exponent)` where both args are integers, denoting `significand × 10^exponent`. The implementation hides behind the formula representation: parsing `"1.5e3"`, formatting back to `"1.5e3"`, computing significant digit count, etc., all manipulate the formula. None of those operations survive in the LarKC port.

The predicate is used by `number-utilities.lisp:significant-digits` — which immediately calls `missing-larkc 690` if the number is a scientific number, confirming the rounding logic is also stripped.

### Why two name spellings (`scientific-number-` vs `cyc-scientific-number-`)

`scientific-number-p` is the **internal** type test. The `cyc-scientific-number-*` functions (all stripped) are the **Cyc API exports** registered via `register-kb-function` and `register-api-predefined-function` — these are what KB rules and external API clients invoke. The two-tier naming separates "internals SubL/CL agrees on" from "Cyc-side API surface that has docstrings and arg type registrations." See `eval-in-api-registrations.lisp` for the complete registration list (`cyc-scientific-number-from-string`, `-to-string`, `-from-subl-real`, `-to-subl-real`, `-significant-digit-count`, `-p`).

### Where scientific-numbers is consumed

- `number-utilities.lisp:significant-digits` — checks `scientific-number-p` and bails to `missing-larkc 690`.
- `eval-in-api-registrations.lisp` — six API registrations for `cyc-scientific-number-*` functions, all of which have stripped bodies.

That's it. The file is a registration façade; the operations live somewhere in the missing-larkc gaps of canonicalization.

---

## Notes for a clean rewrite

### number-utilities

- **Drop the trivial wrappers** (`2*`, `onep`, `encode-boolean`, etc.) at call sites. CL has `(* 2 x)`, `(eql x 1)`, `(if b 1 0)` — these are clearer at the call site than a named one-liner.
- **Keep `potentially-infinite-*`** as a small module — but consider replacing the `:positive-infinity` keyword with CL's `single-float-positive-infinity` (or a struct `(infinity sign)`) and let `+ * /` propagate naturally. That's a behavioral change, not just a refactor: CFASL needs to learn IEEE infinities, and the `inference-parameters.lisp` defaults need updating.
- **Reimplement `significant-digits`** atop the host's number-formatting library (`format-floats` / `dragon4`-aware printing). The current code does `loop for delta from -2 below 3` which is a manual shortest-decimal-representation search; modern languages have this built in.
- **The checksum constants suggest a Fletcher-style sum was intended.** If the rewrite needs assertion-content checksums, use a real cryptographic hash (xxHash for fast-and-non-cryptographic, BLAKE3 for cryptographic). Don't reinvent.
- **`maximum` and `median` overlap with `cl:reduce` / `alexandria:median` / sort-then-pick.** Inline the few callers and delete.
- **`bytep` should be `(typep x '(unsigned-byte 8))`** at call sites.

### numeric-date-utilities

- **Replace with `local-time` (or the host's modern date library).** `local-time:timestamp` handles timezones, leap seconds, ISO 8601 round-trips, and the entire formatter ecosystem.
- **The `yyyymmdd` / `hhmmss` packed-integer encodings** must stay if KB content uses them — `#$startsAfterStartingOf` and friends serialize universal-dates as integers in assertions. So the encoder/decoder pair stays; everything else (the templating engine, the `*month-duration-table*` for leap-year math) is replaced by `local-time`.
- **The Julian-date offset table is incomplete** (`*julian-offsets* = nil`). If Julian-date conversion matters, build it from `local-time:timestamp-to-julian-date`.
- **`elapsed-time-abbreviation-string` is one line of `local-time` formatting.**
- **`get-utc-time-with-milliseconds`** is replaceable by `(local-time:now)` then `(local-time:timestamp-to-unix …)` × 1000 + nsec.

### scientific-numbers

- **Decide whether scientific numbers are first-class.** The KB has them as a CycL function term `(#$ScientificNumberFn s e)`. The clean rewrite should either:
  1. **Keep them as a CycL formula** (current design): scientific-number-p stays, the to-/from- string and to-/from-real functions are normal CycL canonicalization rules, no in-memory struct.
  2. **Promote to a struct** (rejected by the existing design): adds a parallel representation but lets arithmetic happen without re-parsing the formula every time.
- **Re-implement the parser/formatter.** `1.5e3` ↔ `(#$ScientificNumberFn 15 2)` is a one-screen function in modern CL — `(parse-integer)` + a regex on the exponent.
- **All six Cyc-API functions need real bodies** before any KB rule using `#$ScientificNumberFn` can run. The registration façade in the LarKC port is a placeholder.
