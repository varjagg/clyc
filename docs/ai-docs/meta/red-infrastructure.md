# RED infrastructure

The RED infrastructure is a **REgistry-style configuration store** for SubL variables — a separate naming and lookup system that lives alongside the host's variable bindings, where each variable is associated with a string `key` (think config-file path) and is initialized from a "RED repository" rather than from an in-source initializer. The system is **almost entirely missing-larkc**: of the ~25 functions in the design, only a handful have bodies in the port, and there are **no consumers outside its own files**. It is preserved as a spec and as a generator of the test variables that exist solely to verify `red-def-helper` works.

The two files together implement:

- `red-infrastructure.lisp` — the `red-symbol` defstruct, the `register-red` updater that maintains three indices, and the (mostly stripped) lookup/reload/callback machinery.
- `red-infrastructure-macros.lisp` — 24 `define-red-X-Y` macros (4 storage classes × 3 access levels × 2 list-or-not flavors) plus `red-reinitialize-variable`.

## What "RED" appears to be

RED is **not** an acronym defined anywhere visible in the source. From the design surface — keys, monikers, repositories, reload callbacks — it appears to be a system for **decoupling variable definitions from their values**, where:

1. The variable's *name* is declared in the source via `define-red-X-Y`.
2. The variable's *current value* comes from a "RED repository" (a separate file or service) keyed by the variable's `red-key`.
3. When the repository is reloaded (e.g. config file changed), the variable's value is re-read and *registered callbacks* (under monikers) fire.

This is the canonical shape of a **dynamic-config / feature-flag / runtime-tunable system**. The naming ("RED" being typed in lowercase as a proper noun in source comments) suggests a Cycorp-internal product or codename. The Cycorp test default values include `"/cyc/CycC/Linux/head/run/world/latest.load"`, suggesting RED was tied to Cyc's *world file* / image-resurrection loader configuration — which world to load, where the dump lives, etc.

## The `red-symbol` defstruct

The single non-trivial data structure:

```
(defstruct red-symbol
  name              ; the variable's symbol (e.g. 'reddef-lex-publ)
  red-key           ; the lookup key in the repository (a string or list)
  default-value     ; fallback when the repository has no entry
  ltype             ; storage class: :parameter / :lexical / :global / :var,
                    ; optionally with :list flag → '(:lexical :list) etc.
  set-from-red      ; t if the variable's value came from the RED repository,
                    ; nil if from default-value
  valuetype)        ; :simple by default; otherwise (e.g. :list)
```

Constructors: `make-red-symbol-struct` (the defstruct constructor) and `make-red-symbol` (a hand-written keyword-arg constructor that checks slot validity). `new-red-symbol` is the one used in practice — sets all the slots and returns the struct.

## State owned by `red-infrastructure.lisp`

| Variable | Purpose |
|---|---|
| `*red-variables-dictionary*` | Hash table `name → red-symbol`. Primary index keyed by variable name. |
| `*red-symbols-list*` | Flat list of all known red-symbols, ordered by registration. |
| `*red-keys-dictionary*` | Hash table `red-key → list of red-symbols`. Inverse index — given a repository key, which variables draw from it? Used by the (stripped) repository-reload path to know which variables to re-set when a key's value changes. |
| `*red-reload-callback-moniker-dictionary*` | Hash table `moniker → list of callback function-specs`. Used by `red-reload-callback-define` to register code that should run when a particular moniker fires (presumably "key X has been reloaded → run callbacks under moniker M"). |
| `*repositories-loaded*` | Flag set to `t` once the RED repositories have been loaded. The mechanism that sets it (`def-red-set-vars`) is missing-larkc. |

All five use the SubL `(if (boundp 'X) X initform)` idiom for **load-once semantics across image saves** — when a saved image reloads this file, the existing dictionaries are preserved rather than reset, so registered red-symbols survive the round-trip.

The three index dictionaries (`*red-variables-dictionary*`, `*red-symbols-list*`, `*red-keys-dictionary*`) are kept consistent by `register-red`, the only live mutator. `register-red` is interesting: it handles both the **first-registration** case (new variable) and the **re-registration** case (existing variable, possibly with a different key). In the re-registration case it carefully migrates the old entry from the old key's bucket to the new key's bucket while preserving identity. This is *the* place where a variable's `red-key` can change during a re-init.

## When does a `red-symbol` come into being?

Three trigger situations:

1. **A `define-red-X-Y` macro form runs at file load.** The macro expands into a host `def<storage>-<access>` form whose initializer is a call to `red-def-helper KEY NAME DEFAULTVALUE LTYPE [VALUETYPE]`. The helper calls `new-red-symbol` to construct the struct, then `register-red` to install it in the three indices, then `red-value` to extract the current default value as the variable's initial value. This is the only path the LarKC port exercises (the test variables at the bottom of `red-infrastructure-macros.lisp` are the only places the macros are used).

2. **A repository reload occurs and a variable's red-key has a new value in the repository** (`red-update-def-red-from-repository`, missing-larkc). This path would re-set an existing red-symbol's `default-value` and `set-from-red` flag. Stripped.

3. **`set-red-symbols`** (missing-larkc) — a bulk-init path that walks the list of registered red-symbols and pulls each one's current value from the repository. Stripped.

The `red-def-helper` path is what *actually* runs in this image. Everything else is design intent.

## When does a callback fire?

`red-repository-register-reload-callback MONIKER FUNCSPEC` adds `FUNCSPEC` to the list under `MONIKER` in `*red-reload-callback-moniker-dictionary*`. `red-execute-callbacks MONIKER RED-KEY` (missing-larkc) is the dispatch — when a key reloads, callbacks under matching monikers fire with the key as argument.

`red-reload-callback-define NAME ARGLIST MONIKERS BODY` is sugar: define a function `NAME` and register it as a callback under each of `MONIKERS`. The arglist must be empty (the macro errors otherwise) — callbacks take no arguments because all context comes from the moniker and red-key.

## The 24 `define-red-X-Y` macros

A regular grid:

|         | Public | Protected | Private |
|---------|---|---|---|
| **`-parameter`** (re-init on reload) | `define-red-parameter-public` | `define-red-parameter-protected` | `define-red-parameter-private` |
| **`-lexical`** (lexical, reinit on reload) | `define-red-lexical-public` | … | … |
| **`-global`** (global, init-once) | `define-red-global-public` | … | … |
| **`-var`** (defvar, init-once) | `define-red-var-public` | … | … |

Each has a `-list-` variant that adds `:list` to the ltype, indicating the value is a list rather than a scalar (the repository would parse it as such). 24 macros total: 4 storage × 3 access × 2 list-or-not.

Every macro expands to the corresponding `def<storage>-<access>` access-macro from [meta/access-macros.md](access-macros.md), with the initializer being a call to `red-def-helper`. The `description` argument is unused — it exists so the source documents the variable's purpose, but the macro discards it.

The `(fif (symbolp ',KEY) (symbol-value ',KEY) ',KEY)` indirection lets `KEY` be either a literal value (used directly) or a symbol-naming-the-key (look up its current value). This is so a key can be defined once as a constant and referenced by name from many `define-red-X-Y` sites — change the constant, the key changes everywhere.

## Test variables

The bottom of `red-infrastructure-macros.lisp` contains **12 test variables** (all named `reddef-X-Y`, one per storage×access combination) that exercise every macro shape. They use `*red-infrastructure-test-key*` as their key and `*red-infrastructure-test-default*` ("dflt") as their default. These are the only call sites of the `define-red-X-Y` macros in the entire LarKC port.

`*red-infrastructure-test-red-value*` is set to `"/cyc/CycC/Linux/head/run/world/latest.load"`. This was presumably the *expected* value the test variables would have if a real RED repository were attached — i.e. the repository would override "dflt" with this path. It serves no runtime function; it documents what the test was supposed to verify.

## Cross-cutting consumers

**There are none.** Grep confirms no file outside `red-infrastructure*.lisp` references any RED-* symbol. The system is fully self-contained in the port and entirely defunct as a runtime mechanism. The only exposure is the test variables, which the test for the RED system would have read.

## Notes for a clean rewrite

- **The clean rewrite probably should not include this.** RED was Cyc's internal config-via-repository system; nothing in the LarKC distribution actually uses it, and a modern rewrite would solve the same problem with environment variables, a TOML/YAML config file, or a feature-flag service. The 24-macro grid is purely a SubL artifact (because SubL had no abstraction over storage class × access level), and the registry indices are duplicating what a real config library does.
- **If the rewrite needs config-driven variable initialization**, build it on existing libraries (e.g. envy, py-configparser-equivalent for CL) rather than reinventing this. The valuable design ideas from RED to preserve are: (a) variables can re-initialize on config reload, (b) callbacks fire when a key changes, (c) variables track whether their value came from config or fallback. These are 90s-era versions of patterns that modern frameworks handle natively.
- **The `set-from-red` flag is a useful introspection bit** — "did the operator override this, or is it the default?" Worth preserving in any tunable system; surface it through diagnostics endpoints.
- **The reload-callback system collapses to a normal pub/sub.** Monikers are topic names; callbacks are subscribers; reload is publish. Use a real event bus.
- **The `*red-keys-dictionary*` reverse index is needed for "what variables consume key K?"** but it's hand-maintained by `register-red`. A clean rewrite using a database/dict-of-objects can derive this lazily.
- **The `register-red` update path mixing first-registration and re-registration** is the one tricky function with a real body. The careful list-migration logic for `*red-keys-dictionary*` (delete from old bucket, possibly remove the bucket entirely if empty, push to new bucket) is the kind of code that *should* be replaced with a real dict-of-sets primitive in a clean rewrite — it's correct here but easy to get wrong.
- **`red-def-helper` is registered as a macro-helper** for all 24 `define-red-X-Y` macros (see the `(toplevel (register-macro-helper 'red-def-helper ...))` block). This is the macro-helper system from [meta/access-macros.md](access-macros.md) doing what it was designed for.
- **`*red-infrastructure-test-red-value*` is a constant pointing at `/cyc/CycC/...` — a Cycorp-internal NFS path.** Useless to anyone outside Cycorp. Either delete the test variables in the rewrite or replace the path with a self-contained example.
- **`red-conditional-set` (missing-larkc) likely sets a variable only if the repository value differs from the current value** — i.e. avoids spurious change notifications. If the rewrite implements reload, preserve this.
- **`red-make-list` (missing-larkc) is presumably for list-typed values** — it would parse a repository entry into a list. The presence of `(:lexical :list)` etc. ltype shapes confirms list-valued config is a first-class concept. A clean rewrite using TOML/YAML gets this for free.
- **The `valuetype :simple` default** suggests other valuetypes existed (perhaps `:bag`, `:set`, `:dictionary`?). Not enough evidence in the port to reconstruct what they were.
- **The `(boundp '*X*) X initform` idiom in deflexicals** is SubL's "preserve across image save" trick. A clean rewrite shouldn't save and restore a running image as the deployment model; if it does, use the host's snapshot mechanism rather than per-variable boundp dance.
- **Don't preserve the test variables** — they were vestigial smoke tests for the macro generation. A clean rewrite that *doesn't* include RED at all has nothing to test.
