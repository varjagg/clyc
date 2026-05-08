# CFASL serialization

CFASL (Cyc Fast-Loading) is the binary serialization format for everything Cyc persists. It's a tag-byte-prefixed protocol with one byte per primitive opcode and a generic-function-style dispatch on output. Both directions of every supported type live behind a small registration interface, which makes CFASL the right hub to describe how *any* serializable object plugs in.

The format is little-endian. The on-disk artifacts (`.cfasl` files in `cyc-tiny/`, OpenCyc, etc.) are streams of CFASL-encoded objects; you can `cfasl-load filename` to read the first one or call `cfasl-input` repeatedly to consume them all.

Compression is **not** included in this port (`cfasl-compression.lisp` defines tags and dispatch but no compressors). The `*cfasl-compress-object?*` path always falls through.

## Streams and modes

CFASL operates on three flavors of stream:

| Stream | Purpose |
|---|---|
| Plain `(unsigned-byte 8)` stream | normal file or socket |
| `cfasl-encoding-stream` | wraps a stream with extra encoding state — slot is `internal-stream` |
| `cfasl-decoding-stream` | wraps a stream with extra decoding state |
| `cfasl-count-stream` | doesn't write — counts bytes; slot is `position` |

The encoding/decoding wrappers are tied to the **stream extensions** path (`*cfasl-stream-extensions-enabled*`), most of which is `missing-larkc` in the port. Plain byte streams are the only working mode at the moment.

`cfasl-raw-write-byte` / `cfasl-raw-read-byte` are the bottom of the IO stack. Above them, `cfasl-output` and `cfasl-input` are the public entry points. `cfasl-input-internal` is the actual dispatcher.

Two output orientations:

| Function | When to use |
|---|---|
| `cfasl-output obj stream` | **In-image** encoding. Constants/NARTs/etc. travel by handle (SUID/ID). Receiver must share the ID space. |
| `cfasl-output-externalized obj stream` | **Cross-image** encoding. Constants travel by GUID; structures travel by recipe. |
| `cfasl-output-maybe-externalized obj stream externalized?` | branch on a flag |

The externalized-vs-handle decision propagates through dynamic vars `*within-cfasl-externalization*` and `*within-complete-cfasl-objects*`; encoders inspect these to pick a body shape.

`cfasl-set-mode-externalized` flips `*perform-cfasl-externalization*` for the duration of a connection (used by `cfasl-server-top-level`).

## Opcode space

Opcodes are 1 byte. The encoding space is partitioned:

| Range | Use |
|---|---|
| 0 – 127 | Tagged opcodes (`*cfasl-max-opcode*` = 128). Each byte selects a specific input function from a 128-entry array. |
| 128 – 255 | Immediate small fixnums. `(- byte 128)` → integer in range `[0, 127]`. No further encoding needed. |
| ≥ 128 (wide) | Reserved for the wide-opcode tag (29) followed by a multi-byte ID looked up in `*cfasl-wide-opcode-input-method-table*`. Not yet used in port. |

`*cfasl-immediate-fixnum-cutoff*` = 128, `*cfasl-immediate-fixnum-offset*` = 128. Anything ≥ 128 in the byte stream is interpreted as a packed immediate fixnum unless preceded by an enclosing opcode that already parsed it as a literal.

### Tagged opcodes used in this port

| # | Name | Carries |
|---|---|---|
| 0 | `*cfasl-opcode-p-8bit-int*` | positive 8-bit integer (1 byte) |
| 1 | `*cfasl-opcode-n-8bit-int*` | negative 8-bit integer |
| 2-3 | p/n-16bit-int | |
| 4-5 | p/n-24bit-int | |
| 6-7 | p/n-32bit-int | |
| 10 | keyword | length-prefixed name |
| 11 | other-symbol | optional package name + symbol name |
| 12 | nil | (no payload) |
| 13 | list | length + N elements |
| 15 | string | length + N bytes |
| 17 | dotted-list | length + N elements + final cdr |
| 18 | hashtable | test, size, N (key,val) pairs |
| 23-24 | p/n-bignum-int | length + N fixnums (low-to-high) |
| 25 | legacy-guid | string-encoded GUID |
| 30 | constant | SUID (handle) or GUID (recipe) |
| 31 | nart | NART id (handle) |
| 32 | complete-constant | GUID + name string |
| 33 | assertion | assertion id |
| 36 | deduction | deduction id |
| 37 | kb-hl-support | id |
| 38 | clause-struc | id |
| 40 | variable | variable id (1..*variable-max*) |
| 42 | complete-variable | extra metadata variant |
| 43 | guid | 16 raw bytes (terse) |
| 44 | defstruct-recipe | constructor-fn, slot-count, (slot-name, slot-value)* |
| 50 | common-symbol | index into `*cfasl-common-symbols*` |
| 51 | externalization | wraps next object as externalized |
| 62 | bag | bag contents |
| 68 | keyhash | (legacy keyhash; read as key→t hashtable) |
| 90 | sbhl-directed-link | predicate-links + inverse-links |
| 91 | sbhl-undirected-link | links |
| 94 | hl-start | (currently missing-larkc) |
| 95 | hl-end | (currently missing-larkc) |

There's also a partially-missing **GUID-denoted type** mechanism (opcode 126 is reserved): a payload tagged with a 16-byte GUID rather than a small integer, dispatched through `*cfasl-guid-denoted-type-input-method-table*`. Used by formula-templates for `template-topic`, `formula-template`, and `arg-position-details`.

## Input dispatch

Every opcode resolves to a 1-arg function `(stream)` registered in `*cfasl-input-method-table*` (a 128-entry array). `register-cfasl-input-function opcode fn` installs an entry; the `declare-cfasl-opcode` macro defines the constant **and** registers the input function in one form:

```lisp
(declare-cfasl-opcode name val func)
;; expands to
(progn
  (defconstant name val)
  (register-cfasl-input-function name func))
```

Unknown opcodes resolve to `'cfasl-input-error`, which signals.

```
(register-cfasl-input-function opcode fn)              ; narrow (0-127)
(register-wide-cfasl-opcode-input-function id fn)      ; wide (≥ 128, multi-byte)
(register-cfasl-guid-denoted-type-input-function guid fn) ; GUID-tagged
```

`cfasl-opcode-peek` lets a caller look at the next opcode without consuming it (one-byte rewind via `file-position`).

## Output dispatch

Output goes through the generic function `cfasl-output-object` (a CLOS `defgeneric`). Each serializable type has a `defmethod cfasl-output-object` specializing on its class. The default method is `(missing-larkc 31000)` — i.e. **the type is not serializable unless its method is defined**.

```lisp
(defpolymorphic cfasl-output-object (object stream) ...)

;; built-in types
(defmethod cfasl-output-object ((object cons) stream)        ...) ; → list or dotted-list
(defmethod cfasl-output-object ((object string) stream)      ...) ; → opcode 15
(defmethod cfasl-output-object ((object symbol) stream)      ...) ; → nil/keyword/common/other
(defmethod cfasl-output-object ((object float) stream)       ...) ; missing-larkc
(defmethod cfasl-output-object ((object character) stream)   ...) ; missing-larkc
(defmethod cfasl-output-object ((object vector) stream)      ...) ; missing-larkc
(defmethod cfasl-output-object ((object package) stream)     ...) ; missing-larkc

;; KB types — defined in cfasl-kb-methods.lisp
(defmethod cfasl-output-object ((object constant) stream) ...)
(defmethod cfasl-output-object ((object nart) stream) ...)
(defmethod cfasl-output-object ((object assertion) stream) ...)
(defmethod cfasl-output-object ((object deduction) stream) ...)
(defmethod cfasl-output-object ((object kb-hl-support) stream) ...)
(defmethod cfasl-output-object ((object clause-struc) stream) ...)
(defmethod cfasl-output-object ((object variable) stream) ...)
(defmethod cfasl-output-object ((object sbhl-directed-link) stream) ...)
(defmethod cfasl-output-object ((object sbhl-undirected-link) stream) ...)

;; ad-hoc types
(defmethod cfasl-output-object ((object template-topic) stream) ...)       ; formula-templates
(defmethod cfasl-output-object ((object formula-template) stream) ...)
(defmethod cfasl-output-object ((object arg-position-details) stream) ...)
(defmethod cfasl-output-object ((object tva-cache) stream) ...)            ; tva-cache.lisp
```

Integers don't go through the generic; `cfasl-output` short-circuits via `cfasl-output-object-integer-method` → `cfasl-output-integer`, which handles all four widths plus bignums.

> **Java vs. Clyc port note.** In SubL/Java, output dispatch was a 256-entry array `*cfasl-output-object-method-table*` populated by `Structures.register_method(...)`. The Lisp port replaces this with a CLOS generic; the array is allocated but unused. A clean rewrite has only one mechanism.

## Registration protocol — how a new type plugs in

To add CFASL serialization for a new type `foo`, in the file that defines `foo`:

1. **Pick an opcode.** Check the opcode table above and `grep "cfasl-opcode-" larkc-cycl/*.lisp` for collisions. Opcodes are global.
2. **Declare it.** `(declare-cfasl-opcode *cfasl-opcode-foo* 99 'cfasl-input-foo)` in a `toplevel` block. This both defines the constant and registers the input function.
3. **Define `cfasl-input-foo stream`** — reads from stream, returns the reconstituted object. Whatever payload format you pick, you call `cfasl-input` recursively for any embedded values; the format is fully self-describing per-byte.
4. **Define a `defmethod cfasl-output-object` specializing on `foo`** that writes the opcode byte and serializes payload.
5. **If your object travels across images**, also define a recipe variant: `cfasl-output-foo-recipe` and `cfasl-input-foo-recipe`, with the recipe path triggered by `(within-cfasl-externalization-p)`. The handle/id-by-default + recipe-on-externalization split is the universal pattern (see "KB-object pattern" below).
6. **If it can be invalid**, define `*sample-invalid-foo*` and have the input function fall back to it for unknown handles. Keep the user's note in mind — they want this replaced by a condition in a clean rewrite.
7. **If your object holds a struct that has no body method, the generic-defstruct-recipe path (opcode 44) is used**. See `cfasl-output-defstruct-recipe-visitorfn` — emits `:begin (constructor-fn slot-count)`, then `:slot (name value)` per slot, then `:end`. Read by `cfasl-input-defstruct-recipe`.

For **GUID-denoted types** (variant: a payload tagged not by small integer but by 128-bit GUID), use `register-cfasl-guid-denoted-type-input-function`. The use case is types that are extended at runtime — formula-template subkinds, for example — where opcode allocation isn't manageable.

## KB-object pattern (constants, NARTs, assertions, deductions, KB-HL-supports, clause-strucs)

These all follow an identical contract, defined in `cfasl-kb-methods.lisp`. For each KB object type, three encodings exist:

| Encoding | Trigger | Payload | Description |
|---|---|---|---|
| **Handle** | default | internal id | uses the SUID/ID directly. Receiver must share id space. |
| **Recipe** | `*within-cfasl-externalization*` is true | external id (GUID for constants, naut-recursive for NARTs, etc.) | portable encoding |
| **Complete** | only constants and variables | recipe + name | self-describing, includes redundant name |

For each type *T* with id-space lookup function *find-T-by-id*:

```lisp
(defconstant *cfasl-opcode-T* OPCODE)              ; one byte
(defglobal *sample-invalid-T* (create-sample-invalid-T))   ; placeholder

(defun cfasl-input-T (stream) ...)                 ; dispatcher
(defun cfasl-input-T-handle (stream) ...)          ; ... → cfasl-T-handle-lookup
(defun cfasl-input-T-recipe (stream) ...)          ; cross-image
(defun cfasl-output-T (T stream) ...)              ; dispatcher
(defun cfasl-output-T-handle (T stream) ...)
(defun cfasl-output-T-recipe (T stream) ...)
(defun cfasl-output-object-T-method (T stream) ...) ; the defmethod target

(defun cfasl-T-handle-lookup (id) ...)             ; dispatches via *cfasl-T-handle-lookup-func*
```

The dispatch through `*cfasl-T-handle-lookup-func*` is what makes **KB load** work. During a normal run, the var is `nil` (or `'find-T-by-id`) and the handle is the live SUID/ID. During load, a `with-T-dump-id-table` macro binds the var to `'find-T-by-dump-id` and binds `*T-dump-id-table*` to a freshly-built map from dump-id → live object. So the same input function code works for both normal and load contexts — the difference is in how a numeric handle resolves.

```lisp
(defmacro with-nart-dump-id-table (&body body)
  `(let ((*nart-dump-id-table* (create-nart-dump-id-table))
         (*cfasl-nart-handle-func* 'nart-dump-id))
     ,@body))
```

(Same shape exists for `with-assertion-dump-id-table`, `with-constant-dump-id-table`, etc.)

The setup at the bottom of `cfasl-kb-methods.lisp` runs at toplevel, registering one input function per KB-object opcode and declaring the `*sample-invalid-*` globals.

### Per-type detail

| Type | Opcode | Handle field | Recipe shape | Complete extra |
|---|---|---|---|---|
| `constant` | 30 | SUID | GUID | + name string (opcode 32) |
| `nart` | 31 | id | (currently `missing-larkc 32172`) | — |
| `assertion` | 33 | id | (currently `missing-larkc 32166`) | — |
| `deduction` | 36 | id | (currently `missing-larkc 32168`) | — |
| `kb-hl-support` | 37 | id | (currently `missing-larkc 32171`) | — |
| `clause-struc` | 38 | id | (currently `missing-larkc 32167`) | — |
| `variable` | 40 | var-id (1..N) | — | + name (opcode 42) |

`*cfasl-externalized-constant-exceptions*` exists for cases where you're externalizing in general but want certain known-shared constants to still travel by SUID. `with-cfasl-externalized-constant-exceptions` binds the set.

The non-constant KB types currently lack output methods entirely (`missing-larkc 32184/32178/32179/32182/32183/32187`); the port can read them but not write. A clean rewrite needs to flesh these out — the recipe shape is symmetric to the read path.

## Built-in encodings (worth keeping for a clean rewrite)

### Integers

| Width | Opcode | Encoding |
|---|---|---|
| `[0, 128)` | (immediate) | byte = 128 + value |
| `[-127, 127]` | 0 / 1 | sign-tagged + 1 byte |
| `[-32767, 32767]` | 2 / 3 | sign-tagged + 2 little-endian bytes |
| `[-2^23, 2^23)` | 4 / 5 | sign-tagged + 3 bytes |
| `[-2^31, 2^31)` | 6 / 7 | sign-tagged + 4 bytes |
| beyond | 23 / 24 | sign-tagged + length + N fixnums via `disassemble-integer-to-fixnums` |

`cfasl-input-integer bytes stream` reads `bytes` (1, 2, 3, 4, or recurse-on-4) little-endian bytes. Negation handled by the n-* opcodes.

### Strings, lists, hashtables

- String: opcode 15, length-prefixed, one byte per char.
- List: opcode 13, length-prefixed, N recursive `cfasl-output` of elements.
- Dotted list: opcode 17, length + elements + final cdr.
- Hashtable: opcode 18, then `(test size (key value)*)`. Reading creates `(make-hash-table :size size :test test)` and inserts each pair.
- Keyhash (legacy set): opcode 68, `(test size key*)`. Read as key→t hashtable; `keyhash.lisp` was elided.

### Symbols

| Kind | Opcode | Encoding |
|---|---|---|
| nil | 12 | (no payload) |
| keyword | 10 | leading-`:`-stripped name string |
| common | 50 | integer index into `*cfasl-common-symbols*` |
| other (Cyc package) | 11 | name string |
| other (other package) | 11 | package + name |

`*cfasl-common-symbols*` is the per-connection compression table for repeated symbols. Sender and receiver agree on a list (via `cfasl-set-common-symbols`); a symbol in the table writes as `(opcode 50, index)` in 2 bytes regardless of name length. Keep this — it's a meaningful compression for KB-heavy traffic.

### Floats, characters, vectors, packages

All defined as `(missing-larkc ...)`. Round-trip in a clean rewrite:
- Float → tag (8 / 9 for sign), 8 bytes IEEE-754
- Character → tag (16), Unicode codepoint integer
- Vector → tag (14 general / 26 byte), length, elements
- Package → tag (28), name string

Unicode strings have their own opcodes (in `unicode-strings.lisp`).

### GUIDs

Two encodings:
- **Terse** (43): 16 raw bytes via `disassemble-guid-to-fixnums`. Gated by `*terse-guid-serialization-enabled?*` (currently `nil` by default; the comment says "should eventually stay T").
- **Legacy** (25): GUID-as-string (e.g. `"bd58dd96-9c29-11b1-9dad-c379636f7270"`).

Output: `cfasl-output-guid` picks based on `*terse-guid-serialization-enabled?*`. Input: opcode 25 routes to `cfasl-input-legacy-guid` (string + parse). Opcode 43 input is currently missing (the user has flagged this as a TODO in the source).

`*cfasl-input-guid-string-resource*` is a per-load reusable 36-char buffer for legacy GUID parsing. `with-new-cfasl-input-guid-string-resource` binds it.

### Defstruct recipe (opcode 44)

The fallback for any `structure-p` object that doesn't have its own `cfasl-output-object` method. Wire format:

```
44, constructor-fn-symbol, num-of-slots, (slot-keyword, slot-value)*N
```

Read back via `cfasl-input-defstruct-recipe`: builds a plist of length `2N`, then `(funcall constructor-fn plist)`. `must` checks that `constructor-fn` is a function spec and each slot key is a keyword.

The output side is currently `missing-larkc 30992`, which is a problem — without it, any unrecognized struct fails to serialize. The visitor function `cfasl-output-defstruct-recipe-visitorfn` (with `:begin`/`:slot`/`:end` phases) is wired up to do the work; the missing piece is the structure-walker that drives it. A clean rewrite that keeps this fallback should plug in CL's `closer-mop` to introspect structure slots.

## Wide opcodes (≥ 128)

Reserved for future extension. Single byte 29 is the "wide opcode follows" marker, then a multi-byte ID looked up in `*cfasl-wide-opcode-input-method-table*` (a regular hashtable rather than a vector since the ID space is sparse and large). `register-wide-cfasl-opcode-input-function` is the registration entry. Currently nothing uses wide opcodes.

## API protocol layer (`cfasl-kernel.lisp`)

The Cyc API server speaks CFASL over TCP. `cfasl-server-top-level in-stream out-stream` binds:

```
*cfasl-common-symbols*       → nil
*perform-cfasl-externalization* → nil
*generate-readable-fi-results*  → nil
*default-api-input-protocol*  → 'read-cfasl-request
*default-api-validate-method* → 'validate-cfasl-request
*default-api-output-protocol* → 'send-cfasl-result
*cfasl-kernel-standard-output* → *standard-output*
```

Request loop:

1. `read-cfasl-request` — `cfasl-input` wrapped in `ignore-errors`.
2. `validate-cfasl-request` — must be a proper list whose `car` is a registered Cyc API function symbol (or `*eval-in-api?*` is set). Otherwise signals.
3. Eval the request via the api-server-top-level loop.
4. `send-cfasl-result` — wraps errors in `(cyc-exception :message string)`, writes a status flag (`(null error)`), then the result, with externalization toggled by `cfasl-externalization-mode?`.

`cfasl-port` returns `*base-tcp-port* + *cfasl-port-offset*`. `cfasl-quit` closes the connection.

`task-processor-request` is the higher-level entry: submits a request to a queue with bindings (cyclist, ke-purpose, eval-in-api state, etc.) and a UUID for the response.

## File-level entry point

`cfasl-utilities.lisp` is one function:

```lisp
(defun cfasl-load (filename)
  "Return the first object saved in FILENAME in CFASL format."
  (with-open-file (stream filename :element-type '(unsigned-byte 8))
    (cfasl-input stream)))
```

For a multi-object file, loop with `cfasl-input stream nil :eof` until you get `:eof`.

## CFASL-related callers worth inspecting

Files that use CFASL beyond the core machinery:

| File | Use |
|---|---|
| `arity.lisp` | dumps/loads the arity hashtables |
| `cardinality-estimates.lisp` | dumps cardinality cache |
| `assertions-low.lisp` | assertion-from-id dump-id table |
| `bag.lisp` | bag opcode (62) |
| `formula-templates.lisp` | GUID-denoted-type registrations + 3 output methods |
| `tva-cache.lisp` | tva-cache CFASL output (within `(toplevel ...)`) |
| `unicode-strings.lisp` | unicode-char and unicode-string opcodes |
| `forts.lisp` | fort-id-index serialization helpers |
| `id-index.lisp` | id-index serialization helpers |
| `dictionary.lisp`, `set.lisp`, `set-contents.lisp` | container-level CFASL helpers (most elided) |
| `dumper.lisp` | high-level KB dump driver |
| `kb-object-manager.lisp` | per-object load/save through the LRU |
| `file-backed-cache.lisp` / `file-backed-cache-setup.lisp` | on-disk file-vector readers using CFASL element decode |
| `file-vector-utilities.lisp` | element-level CFASL on file-vector content |

## Notes for a clean rewrite

- **One dispatch mechanism, not two.** The Lisp port has both a CLOS generic (`cfasl-output-object`) and a residual 256-entry array (`*cfasl-output-object-method-table*`). Pick the generic; drop the array.
- **Conditions, not sentinels.** The whole `*sample-invalid-T*` family for unrecognized handles should be replaced by signaling. The user has flagged this twice in the source.
- **Register-T-handle-lookup-func** is a global flag flipped during KB loads. A cleaner design parameterizes the input function with an explicit context object, so `cfasl-input` is reentrant and parallel.
- **`with-T-dump-id-table` macros** all share a shape — make a single macro `(with-dump-id-tables (assertion nart constant ...) body)` that binds the lot at once. Coordinated dump-id binding is a load-only concern.
- **The defstruct-recipe path needs a working output side.** Without it any port-only struct that lacks an explicit output method silently fails to round-trip. SBCL provides MOP introspection; use it.
- **Float / char / vector / package** are easy and should be filled in immediately — they're stub-level missing.
- **Wide opcodes and GUID-denoted types** exist for extensibility. Choose one mechanism for plug-in types and drop the other.
- **Compression** (CFASL-compress family) is designed in but absent. Skip it in a rewrite — modern transport-level compression (gzip on the stream) is simpler and faster.
- **Externalized vs. handle vs. complete** is three modes that are propagated by special vars. Pass an explicit flag.
- **Common-symbol compression** (opcode 50) is genuinely useful for KB transport and worth keeping; the compression dictionary should be negotiated at connection setup.
- **KB load serializes a dump-id → object map for every type that supports recipes.** A clean rewrite should treat dump-ids as a feature of the loader, not as a flag piped through every input function. The loader keeps the map; input functions don't know about it.

## Files

| File | Role |
|---|---|
| `cfasl.lisp` | core protocol: opcodes, dispatch table, input/output for built-in types |
| `cfasl-kernel.lisp` | TCP API server speaking CFASL; `task-processor-request` |
| `cfasl-kb-methods.lisp` | `cfasl-output-object` defmethods + handle-lookup machinery for KB objects (constants, NARTs, assertions, deductions, KB-HL-supports, clause-strucs, variables, SBHL links) |
| `cfasl-utilities.lisp` | `cfasl-load filename` one-shot helper |
| `cfasl-compression.lisp` | (compression tags only; impl absent) |
