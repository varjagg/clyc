# Integer sequence generator (ISG)

A locked, monotonic-counter abstraction. Each ISG bundles a current value, a starting value, an optional upper limit, and a step delta with a private mutex, so that multiple threads can mint successive values without colliding. The intended use is **per-domain unique-id minting** — every subsystem that needs its own unique sequence (process IDs, abduction-term IDs, query runstate IDs, guardian-request IDs, CFASL compression codes) makes its own ISG and asks it for the next number. The split of "current" from "start" exists so the same ISG can be reset and replayed without rebuilding the counter.

## When does an ISG get created?

Each consumer subsystem has a single global ISG that is allocated once at file-load time and lives for the life of the image. Every place that needs a fresh stream of integers makes a new generator rather than sharing one global counter — which is the *point* of the abstraction. In the LarKC port the call sites are:

| Caller | Variable | Purpose |
|---|---|---|
| `guardian.lisp` | `*guardian-isg*` | IDs for guardian-request structs (async safety / interruption tracking). |
| `process-utilities.lisp` | `*process-wrapper-isg*` | IDs for OS process wrappers (commented "TODO DESIGN - never used"). |
| `inference/kbq-query-run.lisp` | `*runstate-isg*` | IDs for query-run runstate objects, with a `boundp` guard so reload preserves it. |
| `inference/modules/removal/removal-modules-abduction.lisp` | `*abduction-term-isg*` | The "id uniqueifer for abduced terms" — every abduction step mints a fresh integer to label a hypothesised term. |
| `cfasl-compression.lisp` | `*cfasl-output-compression-code-isg*` | Compression codes for repeated CFASL values during dump. |

There is no factory beyond `new-integer-sequence-generator`; subsystems don't share, and the count of distinct ISG variables across the codebase is the count of ISG-using subsystems.

## API surface

| Function / variable | Status in port | Purpose |
|---|---|---|
| `(new-integer-sequence-generator &optional start limit delta)` | Implemented | Allocate. Defaults: `start=0`, `limit=nil` (unbounded), `delta=1`. Errors if `delta` is zero. Initializes `current` to `start` and a fresh BT lock named "ISG". |
| `(integer-sequence-generator-reset isg)` | Implemented | Re-set `current` to `start` under the lock. Returns the ISG. |
| `(integer-sequence-generator-p isg)` | Provided by defstruct | Predicate. The Java has a `$integer_sequence_generator_p$UnaryFunction` override referencing `missing-larkc 31819` — the override would have specialised something (e.g. the type-byte dispatch for funargs); irrelevant in CL. |
| `(integer-sequence-generator-next isg)` | **Stub (no Java body)** | The advance operation: lock, read `current`, add `delta` to it, error if `limit` exceeded, write back, unlock, return the previous value (or the new one — bodies of all real callers are also stripped, so direction is unverified). |
| `(fast-forward-isg isg target)` | **Stub (no Java body)** | Bulk-advance the counter past `target` without yielding intermediate values. Used when reloading a dumped ISG that has already minted N values — fast-forward to N+1 instead of replaying. |
| `(make-integer-sequence-generator &key …)` | Provided by defstruct | The Java had a plist-walking constructor; CL's keyword constructor stands in. |
| `*cfasl-wide-opcode-isg*` = 130 | Constant | Reserved CFASL opcode for an ISG payload. |
| `cfasl-output-object-integer-sequence-generator-method` | **Stub (`missing-larkc 31817`)** | Serializer. |
| `cfasl-wide-output-isg` / `cfasl-output-isg-internal` / `cfasl-input-isg` | All stubs (no Java body) | The wide-opcode round-trip handlers. |

The five slots (with conc-name `ISG-`) are `lock`, `current`, `start`, `limit`, `delta`.

## Why a struct, not a global counter?

The clear answer is **per-domain isolation**. If guardian-request IDs and abduction-term IDs shared a single global, an ID conflict between two unrelated subsystems would be possible (or, worse, the gaps in one stream would leak into the other and break dump/load reproducibility). Every subsystem that owns an ID space owns its own ISG — same idea as `id-index` for handles, but for integers without a vector table behind them.

The `start` / `limit` / `delta` fields exist so the abstraction can also be used for things that *aren't* "0, 1, 2, …": e.g. a sequence of even numbers (`delta=2`), a numbered range with a known end (`limit` non-nil), or a counter that resets after a checkpoint (`reset` rewinds to `start`). In practice all five LarKC users instantiate with defaults — none of those fields are exercised. The code originally intended a richer counter API and got reduced to "global integer with a lock."

## Why a BT lock?

Cyc is multi-threaded (inference workers, agenda processors, transcript handlers), so the obvious mistake of "two threads call `(incf *counter*)` and one of the increments gets lost" is real. The lock ensures atomic read-modify-write of `current`. The lock-name `"ISG"` is shared across all instances — fine because it's per-instance lock, not a global one; the name is just a debugger hint.

A modern alternative is an atomic counter (`sb-ext:atomic-incf` on SBCL) — single CPU instruction, no lock object. Worth doing in a clean rewrite; the bound-checking against `limit` would still need a CAS loop, but the unbounded case (every LarKC use) is one instruction.

## CFASL

The wire format is reserved as wide opcode 130 (`*cfasl-wide-opcode-isg*`). The dump-side serializer (`cfasl-output-object-integer-sequence-generator-method`) is `missing-larkc 31817`; the load-side reader and the wide-output internals are stripped. The likely shape: opcode + current + start + limit + delta. The lock is not serialized — a fresh one is allocated on input.

This matters because **the LarKC port cannot dump or restore a live ISG** — and the file's TODO comment notes "Other code creates these, but they don't ever seem to be stepped" because the advance function is also missing. The full behavior survives only as a design surface; the port supports allocation, reset, and predicate testing, nothing else.

## Status note from the source

The file's own comment is unusually candid:

> TODO DESIGN - This is a complete conversion from the .java version, but doesn't seem enough to be useful. Other code creates these, but they don't ever seem to be stepped.

That is, the LarKC port preserves only enough of the ISG machinery for the surrounding files to *compile and load*. Nothing in the port can mint a number from one of these. A clean rewrite has to fill in `integer-sequence-generator-next` (and the CFASL round-trip) before any of the five consumers do real work.

## Notes for a clean rewrite

- **Use atomic operations, not a lock.** `(incf counter)` on an atomic word is one CPU instruction. The lock-based design is a 1990s SubL-ism.
- **Drop `start` / `limit` / `delta` unless a real consumer wants them.** All five LarKC users instantiate with defaults; the parameters are unused freight.
- **Per-subsystem ISGs are right.** Don't unify into a single global. The isolation is the feature.
- **Reset semantics matter only if dump/load round-trips ISGs.** If the dumper writes the current value and the loader sets it directly (no replay), reset is just `current := start` and fast-forward is just `current := target`. Both become trivial.
- **CFASL opcode 130 is reserved.** Either implement the round-trip or remove the registration; don't leave the opcode wired up to a stub that errors on any real dump.
- **Pick whether IDs are per-image or persistent across dumps.** For abduction-term IDs (regenerated each query), per-image is fine; for assertion handles (must match across dumps), the ISG state has to be serialized. Different consumers want different things — be explicit about which.
