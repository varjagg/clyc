# Java/C name translation and backends

This is the **runtime support for the SubL → Java / SubL → C source-code translator**, plus the live network kernel that lets a Java client speak the Cyc API. The translator itself is largely `missing-larkc` (it lived in `file-translation.lisp` / `secure-translation.lisp` / `system-translation.lisp` and is documented under `meta/`); what survives in this category is:

1. The **lookup tables** mapping every primitive SubL symbol (functions, globals, constants, characters, numbers) to the native identifier the translator will emit for Java or C — `java-name-translation.lisp`, `c-name-translation.lisp`.
2. The **emitter glue** for actually writing C source (`c-backend.lisp`) — almost entirely stripped; only the per-character identifier-name converter survives.
3. The **Java API kernel** (`java-api-kernel.lisp`) — the live-server side of the Java client API: socket persistence, lease monitoring, resource cleanup. This piece is functional, not build-time, despite living next to the translator tables.

These are four files but two utterly different concerns. A clean rewrite should split them: name translation is a build-time concern that should not exist at all after the SubL→host transition, while the Java API kernel is a runtime concern that belongs with `tcp.lisp` and the API-dispatch system in [runtime/](../runtime/). They are colocated here only because both files have "java" in the name.

## What problem does name translation solve?

Cyc's source language is SubL, but Cyc historically shipped as compiled Java (the LarKC distribution) and earlier as compiled C. The SubL→Java/C compiler — which is the bulk of `meta/` — needed a deterministic way to choose a host-language identifier for every SubL function and global it encountered. Some symbols were predefined in the host runtime's standard library; some had to be invented; some had host-language naming conflicts (e.g. SubL `*print-base*` becomes Java `$print_base$` because Java identifiers can't contain `*`).

The tables in `java-name-translation.lisp` and `c-name-translation.lisp` are the answer to "what host name does this SubL symbol get?" They are consulted at translation time and again at link time when the translator emits cross-references between modules.

In the running Cyc image these tables are essentially dead data. They are populated at startup (`initialize-java-backend-function-tables` / `initialize-c-backend-function-name-table`) and queried only by translator code, which is missing-larkc. They survive because the SubL self-host translator is in principle re-runnable from inside the image (Cyc's build system emits a standalone Java/C tree from a running Cyc image, not from a separate compiler binary), so a complete clean rewrite either drops these tables entirely (no more SubL → host translation needed) or moves them next to the translator they serve.

## Port status

| File | Functional bodies | Comment stubs | Notes |
|---|---|---|---|
| `java-name-translation.lisp` | 14 (mostly initializers and computed-name logic) | ~25 | Most lookup wrappers stripped; raw tables intact |
| `c-name-translation.lisp` | 4 initializers | ~12 | Strict subset of Java: tables only, all wrappers stripped |
| `c-backend.lisp` | 2 (`c-backed-convert-identifier-name`, `c-backend-convert-char`) | ~149 | Translator emitter almost completely stripped |
| `java-api-kernel.lisp` | ~12 functional, lease monitor running | ~28 | Live API-kernel functions intact; RED launch helpers stripped |

## The four naming domains

Every SubL identifier translates into one of four native-name categories. Each category has its own table.

### 1. Predefined functions (host stdlib has them)

Symbols in `*java-backend-defined-function-class-data*` / `*c-backend-defined-function-name-data*` already exist in the host runtime's standard library and merely need a name. The Java table groups them by class:

```
("Numbers" (* + - / /= < <= = > >= ABS ACOS ASH ASIN ...))
("Strings" (CHAR MAKE-STRING NSTRING-CAPITALIZE ...))
```

The C table is flatter (no class structure) and emits a single `(SYMBOL "c_name")` pair: C has no namespaces, so all SubL symbols collapse into a single global namespace with `dp_` (data-predicate), `gv_` (global-var), or unprefixed translations.

The actual **per-function name** comes from one of three sources, in priority order:

1. An exception table (`*java-backend-defined-function-name-exception-data*` etc.) — operators that don't have legal host-identifier names. `*` becomes `multiply`, `<=` becomes `numLE`, `LIST*` becomes `listS`.
2. A "secure method id" — the secure translation's renaming pass produces obfuscated `f<id>` names; only used when a `*current-system-translation*` is in secure mode. (The lookup function bodies are stripped; `missing-larkc 8750` is the marker.)
3. The default — `c-backed-convert-identifier-name` strips leading/trailing `*`, lowercases, and substitutes characters by `*c-backend-convert-char-map*` (e.g. `?` → `P`, `-` → `_`, `<` → `L`, `=` → `E`, `>` → `G`). The Java backend uses `format-nil-a-no-copy` and prepends `sublisp_` if the result is a Java reserved word, or `f_` if it starts with a digit.

This last point is the only piece of non-trivial logic that survived the LarKC strip on the C side — `c-backed-convert-identifier-name` is used by both Java and C backends as the canonical identifier sanitizer. The Java side calls it via the wrapper `java-backend-convert-identifier-name`. The "backed" typo (instead of "backend") is preserved from the original SubL source.

### 2. Undefined functions (host runtime defines them, name needs explicit binding)

`*java-backend-undefined-function-name-data*` and the C equivalent contain `(SUBL-SYMBOL "Class" "javaName" (ARGLIST))` quadruples for functions whose host-runtime name doesn't match the SubL name by transformation alone. Examples:

- `OPEN` ↔ `StreamsLow.open`
- `%CINTERN` ↔ `:IMPORTED.makeSymbol` (the `:IMPORTED` keyword means this lives in the runtime's main package, no class qualification needed)
- `%THREAD-MVAL-3` ↔ `Values.thirdMultipleValue` (special name for the third multiple-value slot)

The arglist tail is the function's parameter list — needed at translation time so the emitter can lay out call sites with the right number of slots and the `&optional` / `&rest` semantics.

### 3. Arity-versioned functions

Some SubL primitives compile to specialized Java/C functions per arity for performance. Example: SubL `(+ 1 2)` compiles to `Numbers.add(1, 2)` but actually uses an arity-2 fast path `Numbers.%add2(1, 2)`. The transformation lives in two tables:

- `*java-backend-function-arity-version-table*` — maps `(SUBL-FUN ARITY)` to a placeholder symbol like `%ADD2`.
- `*java-backend-undefined-arity-function-name-data*` — maps each placeholder to its actual host name (`%ADD2 → "Numbers" "add" (NUM1 NUM2)`).

The translator's arity-transform pass (stripped: `java-backend-function-call-arity-transform`) walks the call form, looks up the arity-versioned name, and rewrites `(+ a b)` to `(%ADD2 a b)`. The downstream emitter then resolves `%ADD2` via the second table. The two-step indirection lets the `*…function-arity-version-table*` be data-only without baking in the host name.

The C version is much smaller (only `+ - * / FUNCALL MAX MIN` get arity specialization) — the C runtime has fewer per-arity fast paths than the Java runtime.

### 4. Boolean dispatch (Java only)

`*java-backend-function-boolean-method-table*` maps SubL predicates to **Java boolean instance methods** rather than function calls. SubL `(consp x)` compiles to Java `x.isCons()` instead of `Conses.consp(x)` — the Java runtime represents SubL types as a Java class hierarchy where every type-test is a virtual method.

The transformation is: when emitting an `if (PRED X) ...`, the translator looks up `PRED` in the boolean-method table and emits `if (X.isPRED())` instead of `if (PRED(X))`. This is purely an emitter-time optimization; the *function* form `PRED` still exists for places where a function value is needed.

C has an equivalent system (`*c-backend-function-boolean-version-table*` → `*c-backend-undefined-boolean-function-name-data*`) but uses C functions, not method calls — same idea, no inheritance.

There's also a `*java-backend-function-to-method-table*` with four entries (`CAR/FIRST → "first"`, `CDR/REST → "rest"`) — these are the only data-accessor SubL functions that compile to instance methods rather than function calls. Java cons cells expose `.first()` and `.rest()` so the translator emits those directly.

## Predefined constants and globals

`*java-backend-predefined-constant-table*` / `*c-backend-predefined-constant-table*` map literal Lisp values to names of host constants. The host runtime pre-allocates `T`, `NIL`, the small fixnums (-1 through 20), and every printable ASCII character as named constants. The translator emits references to these names rather than re-allocating each literal:

```
(t . "T")
(0 . "ZERO_INTEGER")
(#\Space . "Characters.CHAR_space")
```

`*java-backend-defined-global-name-data*` (and the C equivalent) handles the same for SubL globals. Each entry is `(SUBL-VAR "Class" "javaName")`, where `javaName` is the runtime's static-field name. SubL globals like `*print-base*` become `print_high.$print_base$` — the `$…$` braces are the translator's convention for "this is a SubL dynamic var represented as a Java static field."

`*java-backend-undefined-global-name-data*` covers the long-tail globals plus a binding-type tag (`:DYNAMIC`, `:LEXICAL`, `:CONSTANT`). The binding type is critical because Java/C don't distinguish dynamic from lexical scope at the language level — the translator emits a `Dynamic.bind`/`Dynamic.rebind` wrapper for `:DYNAMIC` globals and a plain assignment for `:LEXICAL` ones.

## When does a name-translation lookup happen?

Three situations enumerated:

1. **A `current-system-translation` is being run** — the SubL self-host translator iterates source files; for each call form it consults the function-name tables, for each variable reference it consults the global-name tables. The translator is missing-larkc but its callers in `system-translation.lisp` are present (`*current-system-translation*` defvar).
2. **An identifier is being secure-renamed** — when secure translation is on, every user function gets a `f<digest>` name. The lookup goes through `java-backend-computed-function-name-internal` (present, but the secure-id branch is missing-larkc 8750 / 29621).
3. **An interactive query about translation maps** — these survive only as the `(initialize-...)` calls; the lookup wrappers are stripped, so there's no live entry point in the running image. A clean rewrite should not bother preserving these as runtime queryable.

In a system where Cyc is no longer the source of its own Java/C output (clean-rewrite case), categories 1 and 3 vanish entirely; category 2 vanishes if secure translation is dropped (it's a build-time obfuscation pass, not a runtime feature).

## Package collision: SubL vs. default vs. SUBLISP

The Java tables contain symbols from both the default package and a second package called `SUBLISP`. Clyc has no `:sublisp` package, so port-time the symbols collapse into `:clyc` alongside their default-package counterparts. This produces three known eq-collisions in `*c-backend-defined-function-name-data*`:

- `FILE-LENGTH` listed twice
- `GET-FILE-POSITION` listed twice
- `STREAM-LINE-COLUMN` listed twice

The first occurrence wins for hashtable lookup; the duplicate entries are inert. **TODO note in the port file:** once a `:sublisp` package is defined, restore the package-qualified symbol identities. A clean rewrite should either define the package explicitly or drop the SUBLISP-namespaced rows entirely (Cyc no longer needs both namespaces internally; SUBLISP was a SubL-machine-specific package separate from the user's CYC package).

## Live system: the Java API kernel

`java-api-kernel.lisp` is operationally **alive** in the LarKC port — unlike everything else in this category, it is not a translator artifact. It implements:

### Lease management

A Java client connects, acquires an "API services lease" of a duration up to one hour. The lease is keyed by a UUID string the client provides. The **lease monitor** (`*java-api-lease-monitor*`) is a background thread that wakes every 2 seconds, walks `*java-api-leases*` (a synchronized dictionary mapping UUID → expiration timestamp in milliseconds-since-epoch), and for each expired lease calls `release-resources-for-java-api-client` to close sockets and kill in-flight tasks.

| Variable | Default | Role |
|---|---|---|
| `*java-api-leases*` | empty synchronized dict | UUID → expiration ms-since-epoch |
| `*java-api-sockets*` | empty synchronized dict | UUID → `(in-stream out-stream lock)` triple |
| `*java-api-lease-monitor*` | nil until first lease | background thread that expires leases |
| `*java-api-lease-monitor-sleep-seconds*` | 2 | scan period |
| `*maximum-api-services-lease-duration-in-milliseconds*` | 3,600,000 (1 hour) | hard cap on requested lease |
| `*lease-timeout-cushion-factor*` | 3 | actual expiration = (request × 3) so clients get headroom past the formal cap |

The cushion factor is interesting — a client asks for *N* milliseconds, but the server actually keeps the lease alive for *3N*. This is to forgive clock skew, network delay, and clients that renew slightly late.

### Persistent CFASL sockets

A Java client establishes one TCP connection (per `tcp.lisp`'s server) and sends the `initialize-java-api-passive-socket UUID` API call. That call:
1. Stores the (in-stream, out-stream, lock) triple in `*java-api-sockets*` keyed by the UUID.
2. Replies `nil` over CFASL.
3. Sets `*retain-client-socket?*` so the API task processor doesn't close the socket on return.
4. Calls `cfasl-quit` to end the API request without closing the connection.

The socket then sits in `*java-api-sockets*` indefinitely; subsequent outbound CFASL messages to that client are pushed onto its out-stream by other API operations. The lock in the triple is held during each push to serialize multi-thread writes.

### Cleanup paths

Two paths into `release-resources-for-java-api-client`:

1. **Lease expired** — monitor fires, calls release with `abnormal? = t`. Logs a warning, closes the socket, kills active tasks. Lease entry is preserved (so a re-arrival can detect "your lease was forcibly released" via UUID lookup).
2. **Client explicitly disconnected** — releases via `release-resources-for-java-api-client` with `abnormal? = nil`. Lease entry is removed.

`cleanup-broken-java-api-sockets` runs at the start of every new client `initialize-java-api-passive-socket` call. It walks every existing socket and tries to send a CFASL ping (`'(ignore)` form). If the send fails, the socket is closed and removed. This is the GC for sockets whose Java client died without notifying the server.

### RED launch helpers (all stripped)

The `*java-{home,lib,vm,...}-red-key-name*` family of deflexicals plus the `get-red-value-for-default-java-*` no-body stubs constitute a **RED-config-driven Java VM launcher** — Cyc could spawn fresh Java instances with the configured home/lib/VM paths, useful when Cyc-the-server wanted to delegate work to a worker Java process. The RED key names give a clean rewrite a complete config schema:

| Key | Default | Use |
|---|---|---|
| `JAVA_HOME`, `JAVA_RE_HOME` | nil | Java install path (full + JRE-only) |
| `JAVA_LIB`, `JAVA_RE_LIB` | nil | Java classpath roots |
| `JAVA_VM`, `JAVA_RE_VM` | nil | Path to the JVM binary |
| `path_separator` | nil | OS classpath delimiter |
| Subtree key | `"java"` | RED database subtree where these live |
| Default version | `(1 4 2)` | If no version-specific entry, use Java 1.4.2 |
| `java-main-class`, `java-classpath`, `java-arguments` | per-app | Per-application launch profile |

A clean rewrite should drop the RED bridge entirely and use whatever the host language's standard subprocess launch mechanism is (Java's `ProcessBuilder`, `runtime/process-utilities.lisp`, etc.).

## Cyc-API registrations

`java-api-kernel.lisp`'s toplevel registers eight functions with `register-cyc-api-function` so they can be invoked from over-the-wire API calls. This is the public API surface for clients managing their own connection:

| API function | Args | Use |
|---|---|---|
| `initialize-java-api-lease-monitor` | none | Force-restart the monitor |
| `halt-java-api-lease-monitor` | none | Stop the monitor |
| `release-resources-for-java-api-client` | `uuid-string &optional abnormal?` | Manual release |
| `acquire-api-services-lease` | `lease-duration-in-milliseconds uuid-string` | Establish a lease |
| `show-java-api-service-leases` | none | Diagnostic display (body stripped) |
| `initialize-java-api-passive-socket` | `uuid-string` | Promote current connection to persistent |
| `close-java-api-socket` | `uuid-string` | Manual socket close |
| `show-java-api-sockets` | none | Diagnostic display (body stripped) |
| `reset-java-api-kernel` | none | Halt monitor, clear both dicts |

A Java client code path: connect → request lease → call `initialize-java-api-passive-socket` → server pushes async results → client polls / listens. Lease auto-renews on traffic-bearing API calls (the monitor sees recent activity).

## Notes for a clean rewrite

### Name translation

- **Almost certainly delete the entire concern.** The clean rewrite ships its source as the host language directly — there's no SubL-to-Java translation to support. If the rewrite chooses to keep SubL as a source language, the translator becomes a separate build-time tool with its own naming tables, not a runtime kernel concern.
- If kept: collapse the four name-tables-per-domain into a single `name-translation` struct per host with one method per query rather than five hashtables. The current shape (separate tables for predefined, undefined, arity-versioned, boolean) fragments the lookup unnecessarily.
- The `*c-backend-convert-char-map*` (one-off chars like `?` → `P`, `<` → `L`) is the only piece of code-not-data that's worth carrying forward. Same in any host: identifiers must avoid certain chars; the map is the spec for the substitution.
- The "secure translation" fork (renaming user functions to `f<digest>`) is build-time obfuscation, not a runtime concern. Cut it from the running image.
- Drop the `:IMPORTED` sentinel for "this lives in the host's main namespace, no class qualification." A clean rewrite shouldn't have a sentinel value mixed into a name table — use `nil` or a separate flag.
- The **package-collision TODO** (SUBLISP-vs.-default duplicates) is a maintenance smell. Either define the SubL/SUBLISP package distinction the original SubL had, or fully merge.

### Java API kernel

- **Pull this out of `external/`** — it is part of the runtime API dispatch, not part of name translation. It belongs alongside `tcp.lisp`, `api-kernel.lisp`, `task-processor.lisp` in [runtime/](../runtime/).
- **The lease-cushion-factor 3 is a workaround for clients with bad clocks.** A clean rewrite should keep it (network-tolerance cushion is real) but make it configurable per-deployment, and document that the *advertised* lease length is not the *enforced* one. Currently clients have no visibility into the cushion.
- **The `*java-api-leases*` and `*java-api-sockets*` dicts are coupled by UUID but live separately.** A clean rewrite should make them one struct (`api-client { uuid, expiration, in-stream, out-stream, lock }`) so the cleanup paths can't desync.
- **`cleanup-broken-java-api-sockets` reactively GCs zombie sockets at every new connect.** Better: make the lease monitor ALSO ping each socket on its 2s tick. The current design only purges zombies when a new client arrives, which means a long quiet period leaves zombies hanging.
- **Replace the synchronized-dictionary wrapper with a concurrent hashmap** (or whatever the host gives natively). The SubL synchronized-dict layer adds a `with-locked-hash-table` wrap around every operation and a Java-style external lock — it's slower than necessary on platforms that have first-class concurrent maps.
- **The `(ignore)` ping form is a CFASL convention not a TCP keepalive.** Document this. A clean rewrite might want to use TCP-level keepalive instead, freeing the application from a heartbeat protocol.
- **`*retain-client-socket?*` is a special var consulted by the API task processor.** It's effectively a return-channel for "don't close the connection, I'm reusing it." A clean rewrite should make this explicit in the API-result protocol, not a side-channel dynamic var.
- **The `:abnormal?` parameter on `release-resources` controls whether the warn fires and whether the lease entry survives.** This is two different policy decisions encoded in one boolean. Split them: `(release :reason expired|client-requested|server-shutdown)`.
