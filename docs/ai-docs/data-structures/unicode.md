# Unicode (strings, streams, subsets)

Three small files implementing the **boundary between SubL's 8-bit `string` and Cyc's Unicode-aware text path**: a wrapper struct around a 32-bit codepoint vector, a UTF-8-on-top-of-a-byte-stream reader/writer, and a 19-table package of character-class ranges modeled on `java.lang.Character`. **Almost the entire surface is `missing-larkc`** — the LarKC drop kept the type declarations, constants, range tables, and CFASL opcode registration, but stripped every codepoint conversion, predicate, and stream operation. What survives is the *intent* of a Unicode subsystem; the bodies are absent.

| File | Lines | What's actually implemented |
|---|---|---|
| `unicode-strings.lisp` | 323 | Two `defstruct`s, two CFASL opcodes (52, 53), a unicode→ASCII fold table, the HTML-4 character-entity name table, two real defuns (`ascii-string-p`, `ascii-char-p-int`); ~50 functions stubbed |
| `unicode-streams.lisp` | 67 | One `defstruct` (`utf8-stream`), two constants (LF=10, CR=13); 14 functions stubbed |
| `unicode-subsets.lisp` | 496 | 14 `deflexical` codepoint-range tables; 19 functions stubbed |

The system exists because **SubL strings are 8-bit byte sequences** — the language was built for 7-bit ASCII with maybe Latin-1 in some build configs. Cyc the engine needed real Unicode for non-English NL processing, HTML/XML I/O, and international constant names. The Unicode subsystem is a parallel-track text type that the rest of Cyc converts to/from a SubL string at the boundaries.

---

## `unicode-strings.lisp` — the wrapper types

### Why a struct around a vector

`unicode-string` is a single-slot struct wrapping a `vect`:

```
(defstruct unicode-string vect)
(defstruct unicode-char uchar)
```

The `vect` is a vector of codepoints (presumably `(unsigned-byte 32)`, since `max-unicode-value` = 1,114,111 won't fit in 16 bits). It is **not** a CL string — CL strings are character sequences, but this is an integer codepoint sequence. `unicode-char` wraps a single codepoint integer.

The struct wrappers exist for three reasons:

1. **Type-disjointness from SubL strings.** A SubL `stringp` returns false for a `unicode-string`; predicates like `unicode-vector-string-p` and `utf8-vector-string-p` partition the world. Code that takes "either a SubL string or a Unicode string" can dispatch on which struct flavor it got.
2. **CFASL identity.** Each wrapper has its own CFASL opcode (52 for char, 53 for string) so the dump/load path round-trips them as distinct types — a serialized `unicode-string` doesn't decay into a SubL string at restore. (SubL string CFASL opcode is 15.)
3. **Migration path for in-place mutation.** A bare codepoint vector can be `setf`'d, but a struct field can't be confused with the bare vector at call sites. The accessors (`unicode-string-vect`, `unicode-string-set-vector`) are the controlled mutation surface.

### What's actually implemented

| Function | Status |
|---|---|
| `ascii-string-p object` | Implemented. T iff `object` is a CL string and every char has `char-code ≤ 127`. |
| `ascii-char-p-int v-char` | Implemented. T iff `(char-code v-char) ≤ 127`. |
| `display-to-subl-string display &optional placeholder-char subst-alist` | Partially implemented — body uses `missing-larkc 30908` (`display-to-unicode-vector`) for the actual codepoint extraction. The fold loop itself is real: codepoints ≥128 with an entry in `*default-unicode-to-ascii-code-map*` get folded (e.g. `É` → `E`); codepoints ≥128 without a mapping become `placeholder-char` (default `#\~`); ASCII codepoints copy through. |
| `utf8-string-to-subl-string utf8-string` | Trampoline over `display-to-subl-string` and `missing-larkc 30945`. Effectively `missing-larkc`. |
| `cfasl-output-object-unicode-char-method`, `cfasl-output-object-unicode-string-method` | Active defuns wrapping `missing-larkc 30904` / `30905`. |

Every other function is a comment stub.

### The two data tables

`*default-unicode-to-ascii-code-map*` (an alist) maps Latin-1 / Latin-Extended codepoints to plain-ASCII fallbacks: 192–197 (`ÀÁÂÃÄÅ`) → 65 (`A`), 224–229 (`àáâãäå`) → 97 (`a`), and so on. **Why this table exists:** when a Unicode-bearing entity needs to be written to a SubL-string-only sink (legacy export, ASCII transcript), accented forms degrade to their unaccented base instead of being replaced wholesale with the placeholder. The table is rough-and-ready (no normalization, no full case-folding) but covers the common Western European cases.

`*html-40-character-entity-table*` is the HTML 4.0 named-entity → codepoint mapping (`Aacute` → 193, `nbsp` → 160, `alpha` → 945, etc.). **Why:** HTML-aware functions (`html-escaped-to-unicode-vector`, `unicode-display-to-html`, `map-character-entity-to-decimal-value` — all stubbed) needed it for entity decoding/encoding. The table has 252 entries and is interned at file load time. In a clean rewrite this is a one-liner using a host HTML library.

### The 50-function intent surface

The stubbed names are a near-complete encoding/decoding matrix:

- **Format predicates**: `unicode-vector-string-p`, `utf8-vector-string-p`, `display-vector-string-p`, `non-ascii-string-p`, `unicode-character-p`.
- **Codepoint plumbing**: `unicode-char-create`, `unicode-char-code-fn`, `unicode-code-char`, `unicode-string-create`.
- **UTF-8 ↔ codepoint vector**: `to-utf8-vector`, `utf8-vector-to-unicode-vector`, `unicode-vector-to-utf8-vector`, `length-utf8-vector-codepoint`, `length-utf8-from-first-byte`, `to-utc8-vector-internal` (typo preserved from Java), `number-utf8-bytes`.
- **UTF-8 indexing**: `get-unicode-char-at-or-after-offset`, `get-unicode-char-at-or-before-offset`, `get-unicode-char-at-offset`, `utf8-char-p-fn`.
- **Display ↔ UTF-8 ↔ HTML**: `unicode-vector-to-display`, `display-to-utf8-string`, `unicode-display-to-utf8`, `unicode-display-to-html`, `html-escaped-to-utf8-vector`, `html-escaped-to-utf8-string`, `html-escaped-to-display`, `html-escaped-to-unicode-vector`, `unicode-to-html-escaped`.
- **Surface-level conversions**: `unicode-string-to-utf8`, `unicode-string-to-subl-string`, `utf8-string-to-display`, `utf8-string-to-unicode-vector`.
- **Concatenation**: `unicode-string-concatenate`.
- **Display fallback**: `display-vector-is-ascii-p`, `display-to-unicode-vector`.

A "display vector" appears to be **a third encoding** alongside codepoint-vectors and UTF-8 bytes — most likely a renderable sequence (presentation-form-substituted, ligatured, bidi-resolved). The naming is consistent enough across the predicates and converters that the type partitioning is real.

### CFASL registration

```
(defconstant *cfasl-opcode-unicode-char* 52)
(defconstant *cfasl-opcode-unicode-string* 53)

(toplevel
  (register-cfasl-input-function *cfasl-opcode-unicode-char* #'cfasl-input-unicode-char)
  (register-cfasl-input-function *cfasl-opcode-unicode-string* #'cfasl-input-unicode-string))
```

The setup registers reader functions that don't exist (both are stubbed). The result: a dumped KB containing a Unicode object can't be loaded — the opcode dispatcher will resolve to a missing function. The output side (`cfasl-output-object-unicode-char-method`, `-unicode-string-method`) is `missing-larkc 30904`/`30905` — likewise nonfunctional. The opcode numbers and registration shape are documented; the wire format is whatever a `unicode-string`'s `vect` slot serializes to via the standard CFASL vector path.

The CFASL serialization of plain SubL strings (opcode 15, in `cfasl.lisp:492`) is unrelated and works fine.

---

## `unicode-streams.lisp` — UTF-8 over a byte stream

```
(defstruct utf8-stream
  stream    ; an underlying byte stream (CL stream of (unsigned-byte 8))
  cache)    ; a small lookahead buffer
```

**Why a wrapper:** UTF-8 is variable-length (1–4 bytes per codepoint). Reading a single codepoint requires reading 1 byte, branching on the high bits to determine the rest, then reading 0–3 more. The `cache` slot holds bytes already pulled past the current codepoint boundary (e.g. when the caller reads char-by-char but the underlying stream is buffered larger). The `stream` slot is the underlying byte source/sink.

The two constants:

```
(defconstant unicode-linefeed 10)
(defconstant unicode-carriage-return 13)
```

are the codepoints used by `read-utf8-line` for line termination. ASCII line terms remain ASCII line terms in UTF-8.

The intended surface (all stubbed):

| Function | Intent |
|---|---|
| `open-utf8 filename direction` | Open a `utf8-stream` over a file. Mirrors `open` for the UTF-8 case. |
| `close-utf8 utf8-stream` | Close. |
| `write-unicode-char-to-utf8 unicode-char &optional utf8-stream` | Encode codepoint to bytes, write through. |
| `write-unicode-string-to-utf8 unicode-string &optional start end utf8-stream` | Bulk write with optional sub-range. |
| `write-unicode-string-to-utf8-line` | Bulk write + LF. |
| `read-utf8-char &optional utf8-stream eof-error-p eof-value recursive-p` | Read one codepoint. Mirrors `read-char` shape. |
| `read-utf8-char-helper` | Internal multi-byte continuation reader. |
| `read-utf8-line` | Read up to LF/CR; return as `unicode-string`. |

In a clean rewrite this whole file disappears: modern CL has `:external-format :utf-8` on `open` and the host stream becomes a character stream automatically. The byte-cache layer is artifact of an era when Cyc opened streams as bytes and decoded by hand.

---

## `unicode-subsets.lisp` — character-class membership tables

Fourteen `deflexical` vectors, each a packed run-length encoding of a character-class membership predicate. The format:

```
#(<min-codepoint> <count-or-0> start1 count1 start2 count2 ...)
```

Element 0 is the minimum codepoint covered; element 1 is a count or 0; pairs after that are inclusive ranges (`start`, `count`). For example `*unicode-isspacechar*` is:

```
#(0 0 32 1 160 1 5760 1 6158 1 8192 12 8232 2 8239 1 8287 1 12288 1)
```

— space at U+0020, NBSP at U+00A0, OGHAM SPACE MARK at U+1680, MONGOLIAN VOWEL SEPARATOR at U+180E, twelve codepoints starting at U+2000 (en-quad through hair space), two starting at U+2028 (line/paragraph separator), narrow no-break, medium mathematical, and ideographic space.

The 14 tables encode (this is `java.lang.Character`'s API verbatim — every name is a Java method):

| Table | Codepoints in |
|---|---|
| `*unicode-isdefined*` | All assigned codepoints. |
| `*unicode-isdigit*` | Decimal digits in any script. |
| `*unicode-isidentifierignorable*` | Default-ignorable + format chars. |
| `*unicode-isisocontrol*` | C0/C1 control chars. |
| `*unicode-isjavaidentifierpart*` | Java identifier continuation. |
| `*unicode-isjavaidentifierstart*` | Java identifier start (letter / `$` / `_` / etc.). |
| `*unicode-isletter*` | Any letter. |
| `*unicode-isletterordigit*` | Letter ∪ digit. |
| `*unicode-islowercase*` | Lowercase letters. |
| `*unicode-ismirrored*` | Bidi-mirrored chars (parens, brackets, etc.). |
| `*unicode-isspacechar*` | Unicode SPACE category. |
| `*unicode-issupplementarycodepoint*` | Codepoints ≥ U+10000. |
| `*unicode-istitlecase*` | Titlecase letters. |
| `*unicode-isunicodeidentifierpart*` | Unicode identifier continuation. |
| `*unicode-isunicodeidentifierstart*` | Unicode identifier start. |
| `*unicode-isuppercase*` | Uppercase letters. |
| `*unicode-isvalidcodepoint*` | The full range 0–U+10FFFF. |
| `*unicode-iswhitespace*` | Java whitespace (space + control whitespace). |

### Why the tables exist

The names match `java.lang.Character.isXxx(int)` exactly. The Java port translated each Java predicate into a SubL function, and the 19 functions all share the same shape: take a codepoint, binary-search the corresponding `*unicode-isXXX*` vector for membership in any (start, start+count-1) range, return T/NIL. The orphan constant `$int0$_2 = -2` noted in the file header was likely the binary-search "key not found" sentinel.

**Why explicit tables instead of CL's char predicates:**

- **CL's `alpha-char-p`, `digit-char-p`, etc. operate on `character` — not on integer codepoints.** Running them requires a `code-char` round-trip and only covers what the host implementation supports.
- **The behavior must be portable.** Tokenizing CycL source on machine A and B should produce the same tokens. SBCL, ABCL, CCL, and the Java SubL runtime won't agree on every host predicate's coverage. Bundling the tables makes classification version-independent.
- **`isJavaIdentifierStart` / `isJavaIdentifierPart` aren't standard CL.** SubL's tokenizer was modeled on Java's lexical grammar, so the tokenizer needs Java's classification, not CL's.
- **`isMirrored`, `isTitlecase`, `isSupplementaryCodepoint` aren't in CL at all.** These are Unicode-spec features that the Cyc engine needed for bidi rendering, case-mapping, and surrogate handling.

### What's stubbed

All 19 functions (one per table, plus `is-unicode-char-type codepoint type` as the dispatch front door) are active declareFunctions with no body:

```
;; (defun unicode-isdefined (codepoint) ...) -- active declareFunction, no body
;; (defun unicode-isdigit (codepoint) ...) -- active declareFunction, no body
;; ...
;; (defun is-unicode-char-type (codepoint type) ...) -- active declareFunction, no body
```

The intended dispatcher likely takes a keyword (`:digit`, `:letter`, etc.) and calls the right table-search function. **Reconstruction is mechanical:** each function is a binary search over the corresponding vector. The data is preserved; only the lookup loop is missing.

### Use sites

Grepping the LarKC port for `unicode-isspacechar`, `unicode-isletter`, `is-unicode-char-type`, etc. yields **zero hits outside `unicode-subsets.lisp`**. In the surviving Cyc code, the only character-class call site that matters is `*whitespace-chars*` in `string-utilities.lisp`, which is hand-rolled. Every consumer that would want these tables — the CycL tokenizer, identifier validators, NL morphology, HTML/XML name validators — is itself stripped.

In real Cyc the consumers are:

- **`standard-tokenization.lisp`** — defining what counts as a token break vs continuation needs `isWhitespace` / `isLetterOrDigit` / `isJavaIdentifierPart`.
- **The CycL parser** — symbol/constant name validation needs `isJavaIdentifierStart` / `Part` (CycL identifiers borrow Java's lexical class).
- **`xml-utilities.lisp`** — `valid-ascii-xml-name-p` / `valid-non-ascii-xml-name-p` are stubs that need character-class lookups.
- **`morphology.lisp`** (if it survives) — case-folding via `isLowercase` / `isUppercase` / `isTitlecase`.
- **`web-utilities.lisp`** / `html-ascii-glyph-p` — HTML-class predicates depend on this.

---

## How other systems consume Unicode

Searching the LarKC port for external references to the Unicode types and predicates:

| Caller | Surface used |
|---|---|
| `system-version.lisp:99-102` | Lists `unicode-strings`, `unicode-subsets`, `unicode-support`, `unicode-streams` as Cyc subsystems for translation features. Reference only — registration, not invocation. |
| `system-version.lisp:252` | Lists `unicode-nauts` — a separate (unported) file. |
| `eval-in-api-registrations.lisp:448, 612` | Registers `cyc-ascii-string-p`, `cyc-unicode-denoting-ascii-string-p` as API-callable functions. Both are themselves `missing-larkc` stubs in `collection-defns.lisp:249-250`. |
| `collection-defns.lisp:446-447` | Same two functions registered as KB functions. |
| `evaluation-defns.lisp:98-99` | Comments mention `unicode-naut-or-ascii-string-p`, `unicode-naut-or-string-to-unicode-vector` — both commented out. |
| `xml-utilities.lisp:170-176` | Stubs for `valid-ascii-xml-name-p`, `valid-non-ascii-xml-name-p`, `remove-invalid-xml-name-chars-from-ascii-string`, `remove-invalid-xml-name-chars-from-non-ascii-string`. Names imply Unicode classification but bodies are stripped. |
| `web-utilities.lisp:288, 290` | Stubs `html-ascii-glyph-decode`, `html-ascii-glyph-p`. |
| `cycl-grammar.lisp:52, 69-70` | `*grammar-permits-non-ascii-strings?*` — a config flag controlling whether the parser accepts non-ASCII string literals. |

**Net:** zero working external consumers in the LarKC port. The Unicode subsystem is a complete dead branch — the data tables and types are loaded; nothing reaches them.

---

## Notes for a clean rewrite

### Discard everything except possibly the fold table

- **Drop `unicode-string` and `unicode-char` entirely.** Modern CL strings (`(simple-array character)`) handle full Unicode codepoints already on every modern implementation (SBCL, CCL, ECL, ABCL). The two-string-type partition is a SubL-era artifact. There is no benefit to wrapping a vector in a struct just to call it Unicode.
- **Drop `utf8-stream`.** Use `(open path :direction :input :external-format :utf-8)` — the host gives you a character stream that handles UTF-8 transparently. The hand-rolled byte-cache + decode loop is unnecessary work.
- **Drop `unicode-subsets.lisp`.** Use `cl:alpha-char-p`, `cl:digit-char-p`, `cl:upper-case-p`, `cl:lower-case-p`, `cl:both-case-p`, plus a lightweight Unicode library (cl-unicode, cl-ppcre's class support) for the more exotic categories (`mirrored`, `titlecase`, `identifier-part`). The hand-built range tables are 1995-era data that's been superseded multiple times by Unicode revisions.
- **Drop the HTML-40 entity table.** Use a host HTML library (cl-html5-parser, plump, etc.) — they ship with full HTML5 entity tables that supersede HTML 4's 252.
- **`*default-unicode-to-ascii-code-map*` is salvageable** — a "best-effort ASCII degradation" table is genuinely useful for legacy export sinks and isn't easily synthesized from Unicode normalization (NFKD strips diacritics correctly but loses ligatures and asymmetric mappings). Keep it as a lookup table behind one function (e.g. `unicode-to-ascii-fallback`). Or just use `cl-unicode:simple-uppercase-mapping` plus NFKD — that's also fine.

### CFASL opcodes 52 and 53

Reusing them for a hypothetical "Unicode payload" serialization is wasteful in a clean rewrite — there's no Unicode payload distinct from a CL string. **Reclaim the two opcodes** and serialize all strings under opcode 15 (the existing SubL-string opcode). Make sure the dump-loader for any preserved KB images can no longer encounter 52/53 — if such dumps exist, run a one-shot migration.

### One thing worth carrying forward

The **`display`-vs-`unicode-vector`-vs-`utf8-string` partition** in the function names suggests Cyc had a real distinction between *renderable presentation form* and *abstract codepoint sequence*. If a clean rewrite needs that distinction (e.g. for bidi-aware NL output), the names from this file are a good API skeleton — `display-to-utf8-string`, `utf8-string-to-display`, `unicode-display-to-html` etc. The implementation should be a pass-through to `cl-unicode` / a real bidi library, not hand-coded.
