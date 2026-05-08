# String utilities

A 424-line bag of string helpers, character predicates, and tokenizers. Most entries either wrap a CL primitive in a SubL-flavored name, encode a small idiom (whitespace handling, "starts/ends with") in three lines, or implement one of two bigger operations that CL genuinely lacks: a multi-pattern substring substitutor and a configurable string tokenizer. The file also owns the `cyclify-status` struct used by the CycL-text reader (defined elsewhere) and the `*string-read-buffer*` shared scratch buffer.

There is no data structure to invariant-check here. The file is a function library.

## Constants and shared state

| Symbol | Purpose |
|---|---|
| `*point-char*`, `*space-char*`, `*tab-char*` | The literal `#\.` `#\Space` `#\Tab`. Named for readability at call sites. |
| `*empty-string*` | The literal `""`. |
| `*new-line-string*` | A one-character string containing `#\Newline`. |
| `*test-char*` | Unused dynamic var (declared, no consumers). |
| `*char-set*` | Dynamic var bound by `char-set-position` (the function is missing in the surviving port — only the var declaration remains). |
| `*raw-whitespace-chars*` | List of whitespace chars before deduplication: `(#\Space #\Tab #\Return #\Newline #\Newline)`. The duplicate `#\Newline` is a SubL/CL portability quirk. |
| `*whitespace-chars*` | The deduplicated form via `delete-duplicates :test #'char-equal`. |
| `*grammatical-punctuation-chars*` | `(#\, #\? #\! #\& #\\ #\/ #\" #\; #\: #\( #\))` — punctuation outside word interiors (note: no period, so number expressions stay together). |
| `*trigraph-metric*`, `*trigraph-tables*` | State for `string-trigraph-match-p` (the function is LarKC-stripped — only the parameters remain). |
| `*cyclify-string-expand-subl-fn-strings*`, `*cyclify-string-subl-quote-fn-strings*`, `*cyclify-string-quote-chars*` | Reader-table strings used by the CycL-text cyclifier. |
| `*string-read-buffer*` (1024 chars) and `*string-read-buffer-size*` | Reusable scratch buffer for reader callers. |
| `*target-characters*`, `*plistlist-sort-indicator*` | Dynamic vars bound by callers; both have no surviving definitions in this file's body. |

## API surface, by purpose

The 50-odd functions sort cleanly into seven groups.

### Predicates

| Function | Purpose |
|---|---|
| `empty-string-p object` | `(string= object *empty-string*)`. |
| `whitespacep char` | T if `char` is in `*whitespace-chars*`. |
| `non-whitespace-p char` | Negation. |
| `not-digit-char-p thing` | Negation of `digit-char-p`. |
| `upper-case-alphanumeric-p object` | Uppercase letter or digit. |
| `starts-with w starting`, `ends-with w ending` | Prefix / suffix tests against another string. |
| `substring? little big &optional test start-index end-index` | Is `little` a substring of `big`? Special-cases length-1 to `find` instead of `search`. The `test` parameter is **ignored** (TODO at top: "remove all TEST parameters"). |
| `substring-match? big little start` | Is `little` at position `start` in `big`? |

### Construction and coercion

| Function | Purpose |
|---|---|
| `to-string value` | `(princ-to-string value)`. SubL idiom; CL has the primitive directly. |
| `str object` | `(format nil "~a" object)`. Equivalent to `to-string`. |
| `object-to-string object` | Memoized `princ-to-string` via `defun-cached` (initial size 1000). |
| `str-by-type object` | Stringp → object; constant-p → `constant-name`; else `str`. |
| `strcat string-list` | `(apply #'concatenate 'string string-list)`. The TODO notes it returns NIL on empty input rather than `""`. |
| `char-list-to-string chars` | `(coerce chars 'string)`. |
| `first-char string` | `(char string 0)`. |
| `set-nth-char n string new-char &optional safe?` | Mutate `(char string n)` to `new-char`, with optional length check. |
| `stringify-terms terms &optional separator last-separator` | Joins terms via `fort-print-name`. Delegates to `stringify-items` (defined elsewhere). |

### Searching

| Function | Purpose |
|---|---|
| `char-position char string &optional n` | Position of first `char` in `string` from index `n`. |
| `char-type-position char-type string &optional start end` | First position satisfying `char-type` predicate. |
| `string-upto string &optional char` | Substring up to first occurrence of `char` (default `#\Space`). |

### Substitution

| Function | Purpose |
|---|---|
| `replace-substring string substring new` | Single-pattern substitution (TODO: deprecated in favor of `string-substitute`). |
| `do-string-substitutions-robust string subst-list` | Multi-pattern substitution; pattern list need not be in order of appearance. Allocates a working buffer of `(max 256 (* 4 (length string)))` and walks. |

`do-string-substitutions-robust` is the file's most non-trivial function. The `* 4` capacity assumption is called out as dangerous in the TODO; a clean rewrite should size dynamically.

### Tokenization

| Function | Purpose |
|---|---|
| `break-words string &optional non-break-char-test leave-embedded-strings?` | Splits a string on chars failing `non-break-char-test`. Optionally treats double-quoted regions as atomic. |
| `string-tokenize in-string &optional break-list embed-list include-stops? ignore-empty-strings? quote-chars break-list-to-return` | The general tokenizer. Trampolines to `string-tokenize-int`. |
| `string-tokenize-int` | The tokenizer body. Configurable in seven dimensions: break list, return-as-token break list, embedded-region pairs (e.g. `("(" ")")`), inclusion of break tokens in output, suppression of empty strings, quote-escaping characters, and break priority. Sees use both for whitespace splitting and for parsing structured-text input. |
| `string-tokenize-break-length break` | Length of one break (1 if char, `length` if string). |
| `string-tokenize-break-match? in-string break pos` | Single break match at position. |

`string-tokenize` is the heaviest function in the file (~70 lines) and the only one with a substantial state machine. Its capabilities map roughly onto a configurable POSIX `strtok` plus quoted-string awareness — the use cases include both human-text word-splitting and CycL surface-syntax fragmentation.

### Constant-name munging

| Function | Purpose |
|---|---|
| `make-valid-constant-name in-string &optional upcase-initial-letter?` | Camelcase a free-text string into a valid CycL constant name. Strips invalid chars, preserves alphanumerics, capitalizes after every non-alphanumeric. Example: `"this is a fake constant! 200 #$"` → `"ThisIsAFakeConstant200"`. |

This is the only entry that's strongly coupled to Cyc-the-engine — it depends on `valid-constant-name-char-p` from `constants-low.lisp`. The rest of the file is generic string handling.

### Whitespace inventory

| Function | Purpose |
|---|---|
| `whitespace-chars` | Returns a fresh copy of `*whitespace-chars*`. |

### Cyclifier struct

`cyclify-status` is a 12-slot struct used by the CycL-text reader (in standard-tokenization.lisp / wff.lisp) to thread parser state through a string-walking pass. Slots: `out-string-list`, `references-added`, `inside-quote?`, `inside-el-var-name?`, `already-cyclified?`, `escape?`, `inside-subl-quote-fn?`, `inside-expand-subl-fn?`, `inside-expand-subl-fn-arg1?`, `inside-expand-subl-fn-arg2?`, `immediately-following-paren?`, `paren-count`. The struct is defined here because string-utilities is loaded before the consumers and the cyclifier walk is conceptually a string operation; behaviorally it belongs to the CycL reader.

### Intentionally elided

The TODO comment at line 206 records: *"DESIGN - base64 tools elided in preference to external libraries."* SubL had base64 encode/decode here; the port relies on Quicklisp libraries (e.g. `cl-base64`) instead.

## Why these specific helpers

Three forces produced this surface:

- **SubL naming.** `to-string`, `str`, `first-char`, `char-position` are SubL spellings for what CL writes as `princ-to-string`, `format ~a`, `(char s 0)`, `position char string`. Direct ports keep the SubL names so callers don't shift; in a clean codebase these are pure rename wrappers.
- **Idiom shorthand.** `starts-with`, `ends-with`, `empty-string-p`, `whitespacep`, `not-digit-char-p`, `upper-case-alphanumeric-p` are three-line idioms repeated often enough to deserve names. `alexandria` ships several (`starts-with-subseq`, `ends-with-subseq`, `emptyp`); `serapeum` ships more. They're not specific to Cyc.
- **Genuine gaps.** `do-string-substitutions-robust` (multi-pattern substitution), `string-tokenize` (configurable tokenizer with embed/quote/include-stops), `make-valid-constant-name` (Cyc-specific), and the `cyclify-status` reader scaffold are operations CL doesn't ship. A clean rewrite should keep these — or reach for `cl-ppcre` for the substitution and tokenization cases.

The TODO at the top — *"remove all TEST parameters from the string interfaces, since it will always be character comparisons"* — is a deliberate deviation from SubL's polymorphic-test API. SubL passed `:test #'char=` everywhere; CL's primitives default to `char=` for chars and `eql` for sequences, so the parameter is redundant noise.

## What uses these

Consumers cluster by feature area:

- **CycL surface-syntax processing.** `wff.lisp`, `standard-tokenization.lisp`, `cycl-grammar.lisp` (via `cyclify-status`), `eval-in-api-registrations.lisp` — the cyclifier and tokenizer family. These are the heaviest consumers.
- **Constant-name handling.** `constants-low.lisp` (`valid-constant-name-char-p`), and any code that needs to coerce free text into a constant name (`make-valid-constant-name`).
- **External-format generation.** `numeric-date-utilities.lisp` (date string formatting), `web-utilities.lisp` (URL parts), `file-utilities.lisp` (path manipulation), `evaluation-defns.lisp` (printing), `inference/harness/hl-prototypes.lisp` (prototype names).
- **General printing / debug.** Any code that builds an error message or a name uses `to-string` / `str` / `strcat`. ~50 sites for the trio combined.

`object-to-string` is heavily used as the printable form of arbitrary objects (memoized for speed); `string-tokenize` is used by the few places that parse structured text from external sources.

## Notes for a clean rewrite

- **Replace SubL-name wrappers with their CL primitives.** `to-string` → `princ-to-string`, `str` → `format ~a`, `first-char` → `(char s 0)`, `char-position` → `position`, `char-list-to-string` → `(coerce list 'string)`. These exist purely for SubL fidelity and have no semantic content of their own. A clean codebase deletes them and renames at every call site.
- **Replace idiom shorthands with library equivalents.** `alexandria:starts-with-subseq`, `alexandria:ends-with-subseq`, `alexandria:emptyp`. `serapeum:trim-whitespace`. Drop the helpers, add the dependency.
- **Drop the `test` parameter** from `substring?` etc. — the TODO at the top of the file says so; CL's character comparisons are fixed.
- **Replace `do-string-substitutions-robust` with `cl-ppcre:regex-replace-all`** if regex is acceptable, or with a clean (size-correctly) substitutor if not. The current `4 * length` capacity heuristic is unsafe for substitutions that grow the string by more than 4×.
- **Replace `string-tokenize` with `cl-ppcre:split`** for the simple cases. The embed-list / quote-chars / include-stops combinations don't have a clean PPCRE equivalent — for those, the tokenizer is genuine, keep it. Document its semantics carefully because the seven optional arguments interact non-obviously.
- **Keep `make-valid-constant-name`** — it's Cyc-specific and meaningful. But share it with the constant-name validation predicate (`valid-constant-name-char-p`) so the two stay in sync.
- **Move `cyclify-status` to the cyclifier file** (`standard-tokenization.lisp` or wherever the cyclifier lives). It's a parser scratch struct, not a string utility; living here is a load-order accident.
- **Fix `*raw-whitespace-chars*` not to have the duplicate `#\Newline`** — the current code papers over the duplicate by deduplicating via `char-equal`. The original probably distinguished `#\Linefeed` and `#\Newline` on a SubL implementation where they were different chars; on SBCL they're identical.
- **Drop `*test-char*`, `*char-set*`, `*target-characters*`, `*plistlist-sort-indicator*`** if their consumers are still missing-larkc. Each is a dynamic var declared without a corresponding bound use in the surviving code.
- **Drop `*string-read-buffer*` as a global.** Shared scratch buffers are a thread-safety hazard; per-call allocation is fine in modern Lisp.
- **`object-to-string` memoization is suspect.** Memoizing `princ-to-string` of arbitrary objects holds them live, defeating GC. Verify that the cache keys are restricted to printable-without-side-effects values, or drop the memoization.
