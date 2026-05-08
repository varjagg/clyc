# File utilities

A small (164-line) collection of **filename and pathname-string manipulation** helpers, plus one directory-creation routine and a `chmod` shim. Not a filesystem abstraction — every function in the file operates on **strings** treated as paths, never on CL `pathname` objects (those live in `subl-promotions.lisp` as `ensure-physical-pathname` and similar). The reason is SubL: SubL handed code raw strings and let you construct paths by concatenation, so this file's job is to do that portably (Unix vs DOS) without involving the host's pathname grammar.

## API surface

| Function | Purpose |
|---|---|
| `cyc-home-filename subdirectory-list filename &optional extension` | Build `<*cyc-home-directory*>/<sub1>/<sub2>/.../<filename>.<ext>` as a single string. |
| `cyc-home-subdirectory subdirectory-list` | Build the directory string `<*cyc-home-directory*>/<sub1>/<sub2>/.../`. |
| `relative-filename directory-string filename &optional extension` | Concatenate `directory-string` (which **must** end with the platform separator) with `(basic-filename filename extension)`. |
| `basic-filename filename &optional extension` | Append `.<ext>` if extension provided; else return `filename` unchanged. Internally calls `construct-filename` from `subl-support.lisp`. |
| `temp-directory` | Inline accessor returning `*temp-directory*` (default `"/tmp/"`). |
| `file-exists? filename` | `(ignore-errors (probe-file filename))` — non-erroring `probe-file`. |
| `guess-path-type path` | Return `:unix` if `path` contains `#\/`, `:dos` if it contains `#\\`, else `nil`. |
| `absolute-path? path` | T iff the path is absolute under its guessed type: starts with `/` (Unix), starts with `<drive>:` or `\\` (DOS). |
| `path-separator-char path-type` | `#\/` for `:unix`, `#\\` for `:dos`. |
| `deconstruct-path path` | Split into `(values path-list filename path-type)`. |
| `reconstruct-path path-list filename &optional path-type` | Rebuild a path string from the deconstructed pieces. Default `path-type :unix`. |
| `make-directory-recursive directory-path &optional force? permissions` | `mkdir -p` equivalent. `force?` deletes any non-directory file in the way. `permissions` is a string passed to `chmod`. |
| `chmod pathname permissions-string` | Spawns an external `chmod` process if `external-processes-supported?` is T. Marked TODO — `sb-posix:chmod` exists but takes a bitmask; this wants a `chmod`(1) string. |

State variables:

| Variable | Default | Purpose |
|---|---|---|
| `*temp-directory*` | `"/tmp/"` | Where Cyc writes scratch files. Marked TODO ("registers in the red-infrastructure stuff, which got elided"). |
| `*random-path-chars*` | `"0123456789abcdefghijklmnopqrstuvwxyz"` | Charset for randomly-named temp files. **Unused in the port** — no caller — but the name suggests a stripped `make-temp-filename` consumer. |

`*cyc-home-directory*` itself is defined in `system-info.lisp:40` as the ASDF system source directory of `:clyc`. `cyc-home-filename` and `cyc-home-subdirectory` are the canonical way Cyc code locates files relative to the install root.

## Why these functions exist

### Why string-path manipulation rather than CL pathnames

CL pathnames are portable but **not byte-equivalent across implementations**: `(merge-pathnames "foo/bar" "/etc/")` may yield different printed forms on SBCL, ECL, ABCL, and CCL. CL's pathname grammar also collapses some platform-specific cases (Windows drive letters, UNC paths) into structural fields that don't round-trip cleanly back to the OS-native form a `chmod` or `system` call expects.

SubL had no `pathname` type. SubL programs pass paths as strings and concatenate them. The Cyc engine accumulated a body of code that **constructs path strings explicitly** — `relative-filename`, `basic-filename`, `construct-filename` (in `subl-support.lisp`), and the `deconstruct-path`/`reconstruct-path` pair. The whole file is the "string-path API" SubL shipped with: a thin layer over `concatenate 'string` plus a path-type guesser to switch separators.

### Why `guess-path-type` instead of `*features*`

The Java SubL runtime ran on both Unix and Windows. A single Cyc image, dumped on one OS and loaded on another, may carry path strings that don't match the host's separator. `guess-path-type` makes per-string decisions (look at the first slash/backslash you find) rather than per-process decisions. That way a config file referencing `C:\Cyc\kbs\` deserializes correctly on Linux even if the runtime can't act on it.

In a clean rewrite this is mostly defensive — paths shouldn't cross OS boundaries — but the design rationale is real.

### Why `relative-filename` requires a trailing separator

```
(relative-filename "/home/cyc/" "kb" "cfasl")  =>  "/home/cyc/kb.cfasl"
(relative-filename "/home/cyc"  "kb" "cfasl")  =>  "/home/cycKB.cfasl"  ;; bug
```

The function literally does `(concatenate 'string directory-string (basic-filename filename extension))` with no separator handling. The docstring's "DIRECTORY-STRING should include the appropriate directory separator character at the end" is a contract, not a check. Callers that build directories via `cyc-home-subdirectory` or `construct-filename` get the trailing separator for free; raw callers must remember.

### Why `deconstruct-path` returns three values

```
(deconstruct-path "/home/cyc/kbs/world.cfasl")
=> (values ("" "home" "cyc" "kbs") "world.cfasl" :unix)
```

The leading empty string in `path-list` carries the leading-slash → absolute-path information through the round-trip. `reconstruct-path` uses `path-type` to pick the joiner. Splitting and rejoining is how `make-directory-recursive` walks the prefix tree, calling `(directory-p each-prefix)` and `make-directory` for each.

### Why the `chmod` shim is external-process

`sb-posix:chmod` exists on SBCL but takes a bitmask integer. `chmod`(1) accepts the symbolic-or-octal mode-string form (`"0755"`, `"u+x"`, `"a-w"`) that Cyc's API exposes. Rather than implement a mode-string parser, the shim calls out to the `chmod` binary via `system-eval-using-make-os-process-successful?` (defined elsewhere in the OS-process layer). This skips the parser at the cost of a fork/exec per chmod and a hard "Unix only" constraint.

## What uses each function

Grep across `larkc-cycl/`:

| Caller | Function used | Why |
|---|---|---|
| `dumper.lisp:114` | `relative-filename` | Build the data filename for a dump record. |
| `system-parameters.lisp:100-102` | (commented) `cyc-home-filename` | The original Java passed paths via `cyc-home-filename`; the CL port adapted it to native pathnames. |
| `transcript-utilities.lisp:182, 185` | `cyc-home-subdirectory`, `make-directory-recursive` | Ensure the transcript directory exists before writing. |
| `tva-cache.lisp:413` | `file-exists?` | Check both the data file and index file before opening a TVA cache. |
| `misc-utilities.lisp:203` | `absolute-path?` | Branch on whether a directory argument is absolute (used in path-resolution helpers). |
| `inference/kbq-query-run.lisp:522, 537, 565, 578` | `:if-file-exists` keyword | Standard CL keyword, **not** `file-exists?` from this file. Listed here only because grep matched. |

Internal cohesion: `cyc-home-filename`/`-subdirectory` both call `relative-filename`. `relative-filename` calls `basic-filename`. `basic-filename` calls `construct-filename` (from `subl-support.lisp`). `make-directory-recursive` calls `deconstruct-path`, `reconstruct-path`, `path-separator-char`, `chmod`, `ensure-physical-pathname`, `nadd-to-end`, `directory-p`, `make-directory`. The string-manipulation helpers form the leaves; `make-directory-recursive` is the only routine that does I/O beyond `probe-file`.

## CFASL

No CFASL opcodes registered. Path strings serialize as ordinary SubL strings (opcode 15).

## Notes for a clean rewrite

- **Replace the whole file with `uiop`.** UIOP ships with CL and provides:
  - `uiop:file-exists-p` → `file-exists?`
  - `uiop:directory-exists-p` → `directory-p` (currently elsewhere)
  - `uiop:ensure-all-directories-exist` → `make-directory-recursive`
  - `uiop:merge-pathnames*`, `uiop:subpathname` → `cyc-home-filename`, `relative-filename`
  - `uiop:run-program` for the `chmod` shim
  - `uiop:absolute-pathname-p` → `absolute-path?`
  - `uiop:split-name-type`, `uiop:pathname-directory-pathname` → `deconstruct-path`
  
  The string-path layer becomes a thin wrapper: convert at the boundary, use pathname objects internally.

- **Drop the Unix/DOS path-type guessing.** Cyc dumps shouldn't carry OS-specific paths in the first place — they should carry **logical paths** (relative to a configured root) that resolve at load time on the host OS. If a path crosses OSes, that's a configuration error to surface, not silently translate.

- **Keep `*cyc-home-directory*` and `cyc-home-filename` as a façade** — the name "cyc-home-filename" is widely used. Implement it as `(uiop:subpathname *cyc-home-directory* (apply #'uiop:relativize-pathname-directory subdirectory-list))` (or similar) so callers don't change.

- **`*temp-directory*`'s `/tmp/` default is wrong on Windows and unprivileged Unix.** Use `uiop:default-temporary-directory` instead. The TODO in the file flags that this was supposed to register through the `red-infrastructure` config layer (which got elided); a clean rewrite picks one mechanism and uses it.

- **The `chmod` external-process call is a security and portability footgun.** Use `sb-posix:chmod` (or per-host equivalent) with a small `parse-mode-string` helper. Bypassing the host's syscall layer to spawn a binary is wrong by 2010-era standards, let alone modern.

- **`*random-path-chars*` is dead code.** Drop it. If a clean rewrite needs random temp filenames, `uiop:with-temporary-file` does the right thing.

- **`reconstruct-path`'s use of `format nil` of a `format nil`-built control string is a smell.** Two calls to `format` to build "join with separator". Replace with `(format nil "~{~A~^~A~}~A" path-list (string sep) filename)` — one format call, no string-built control string. Or use `uiop:join-strings`.
