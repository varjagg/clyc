# SKSI (Semantic Knowledge Source Integration)

**SKSI is the Cyc-to-external-database bridge.** In a full Cyc image it is the layer that makes a row in an external SQL table queryable as if it were an assertion in the KB: declare a mapping from a Cyc predicate to a table+columns, and `(isa ?x #$Person)` transparently runs as a SELECT against the source.

In this port SKSI is **almost entirely missing**. The project [readme.md](../../readme.md) calls it out explicitly: *"SKSI - Not included, a very minimal set of hooks remains."* What survives is a single file — [`larkc-cycl/sksi/sksi-macros.lisp`](../../larkc-cycl/sksi/sksi-macros.lisp) — containing the macro layer that the rest of the (stripped) SKSI module would have bound around its real work.

The Java original of the full SKSI module lives under `larkc-java/.../com/cyc/cycjava/cycl/sksi/`, but everything beneath it has been LarKC-stripped. The macros in `sksi-macros.lisp` are a hint at the shape of the surrounding system, not a working module on their own.

## What's actually here

Three macros, three defparameters. That's the whole file.

### Defparameters (resource caches)

| Variable | Purpose |
|---|---|
| `*sksi-sql-connection-cache*` | Cache of open JDBC-style SQL connections, keyed by external-knowledge-source FORT. Pool entries are reused across queries to avoid the connect/auth/handshake cost. |
| `*sksi-sql-statement-cache*` | Cache of prepared/parsed SQL statements, keyed by query shape. A repeating query against the same external source pays the parse cost once. |
| `*sksi-sql-statement-pool-lock*` | Mutex protecting the two caches against concurrent rebuild. The full SKSI runtime is multi-threaded — multiple inference workers can hit the same external source simultaneously. |

All three default to `nil`; the full SKSI infrastructure is responsible for populating them at startup. With the surrounding code stripped they remain `nil` for the lifetime of the image, which is fine because the macros that consume them are also stripped.

### `with-sksi-reformulation-caching` / `without-sksi-reformulation-caching`

```lisp
(with-sksi-reformulation-caching
  ...body...)
;; ⇒ binds *memoize-sksi-reformulate?* = t around body

(without-sksi-reformulation-caching
  ...body...)
;; ⇒ binds *memoize-sksi-reformulate?* = nil around body
```

`*memoize-sksi-reformulate?*` is the on/off switch for caching the **reformulation** step — the rewrite that turns a CycL query into the underlying SQL query (or other backend protocol) for an external source. Reformulation is expensive (it consults the source-mapping assertions, applies arg-isa narrowings, generates the SQL skeleton), so callers wrap a query batch in `with-sksi-reformulation-caching` to share that work across the batch.

The `without-` variant exists for the case where reformulation is *itself* part of what's being measured or debugged — turning the cache off forces a fresh compile each call.

The variable `*memoize-sksi-reformulate?*` itself is **not declared in this file**. It's expected to live in the (stripped) larger SKSI infrastructure. In the current port these macros bind a name that resolves at expansion time only.

### `with-sksi-sql-connection-resourcing`

```lisp
(with-sksi-sql-connection-resourcing
  ...body...)
```

In the full system this macro bracketed body in connection-pool acquisition: pull a connection out of `*sksi-sql-connection-cache*` (with `*sksi-sql-statement-pool-lock*` held), execute the body with that connection bound dynamically, release the connection back to the pool on exit (even on non-local exit).

In the port the macro body is stubbed to `(progn ,@body)` because the Internal Constants in the Java file don't carry enough evidence to reconstruct the binding form. The compiled Java has only `$sym0$CLET` and `$sym3$PROGN` symbols — there is no `$listN` capturing the actual binding list, and there are no surviving call sites in the port that show what bindings were established. The reconstruction comment in the source file flags this gap. A clean rewrite must either rediscover the original from a different SubL trace or design fresh.

## How SKSI works conceptually (for the missing rest)

Even though the SKSI runtime isn't here, the design context matters for anyone deciding what to do with these hooks.

A Cyc deployment with SKSI declares **content mappings** in the KB: assertions like

```
(microtheoryStorageStrategy MyExternalSourceMt SQLStorageStrategy)
(physicalSchemaForExternalKB MyExternalSourceMt my_db_schema)
(physicalFieldForLogicalField (TheList ?Pred ?Arg1Slot ?Arg2Slot) my_table some_col)
```

When inference asks `(MyPred X Y)` in `MyExternalSourceMt`, the SKSI removal-modules would:

1. **Match the mapping.** Recognize that `MyPred` lives in an externally backed MT.
2. **Reformulate.** Build a SQL query from the mapping assertions. The result is cached if `*memoize-sksi-reformulate?*` is `t`.
3. **Resource a connection.** Pull from `*sksi-sql-connection-cache*` (or open one). This is what `with-sksi-sql-connection-resourcing` brackets.
4. **Execute.** Run the SQL, get rows back.
5. **Lift.** Convert each row's column values into Cyc terms (via the encapsulation system — strings to constants, numbers to numbers, dates to date-formula-trees). Each row becomes a tuple of bindings for the query variables.
6. **Source the assertions.** Each binding tuple is wrapped as a virtual assertion with an HL-support tagging it as backed by `MyExternalSourceMt`. Inference treats it like any other assertion.

`reformulate-unknown-fet-term` (registered in [eval-in-api-registrations.lisp](../../larkc-cycl/eval-in-api-registrations.lisp), part of [Formula Entry Templates](../kb-access/formula-templates.md)) and `sksi-supported-external-term?` are the visible API hooks where FET-driven UI integrates with SKSI: a user typing into a template form against an SKSI-backed term.

Of all of that, only the macro brackets and the cache variables remain in the port. The matching, reformulation, JDBC, lifting, and HL-support tagging are all stripped.

## Where it's referenced

`sksi-macros.lisp` is loaded by [`clyc.asd`](../../clyc.asd). Outside that, **no remaining file in the port consumes its exports** — the macros and the variables have zero call sites in `larkc-cycl/`. They survive only as the API stub for a future SKSI port.

The one Cyc API entry that names SKSI — `sksi-supported-external-term?`, registered in `eval-in-api-registrations.lisp` — is itself a missing-larkc body. The hook is declared, not implemented.

## Notes for a clean rewrite

- **Decide whether SKSI is a goal.** A Cyc-style KB without external knowledge sources is a complete system on its own. If the rewrite isn't going to talk to external databases, delete `sksi/` entirely — these files are placeholder.
- **If keeping SKSI: it's a removal-module plus a reformulator plus a connection pool.** Removal-modules are the inference-side hook (see [inference/removal-modules.md](../inference/removal-modules.md)); SKSI registers per-source removal-modules that route into the SQL backend. The reformulator turns a CycL query plus mapping assertions into a backend query. The connection pool is plumbing.
- **JDBC isn't load-bearing.** The Java original used JDBC. A modern rewrite can target whatever DB driver the host language has. The cache abstraction (one connection-cache, one statement-cache, one pool lock) is fine; the wire protocol underneath is replaceable.
- **`*memoize-sksi-reformulate?*` is a per-batch knob.** Reformulation results are query-shape-keyed, not parameter-keyed — same query template, different bindings, same compiled SQL. A clean rewrite preserves this: cache the *plan*, not the *result rows*.
- **The connection-resourcing macro must guarantee release.** In the port the body is `progn` — wrong, but harmless because there's nothing to release. Any real implementation uses `unwind-protect` so a non-local exit returns the connection.
- **Source-mapping assertions are KB content, not config.** SKSI's "what does this predicate map to in SQL?" is asserted in CycL, not stored in a config file. Preserve this — it's what makes a Cyc-with-SKSI image relocatable: dump the KB, load it elsewhere, everything still resolves (assuming the external DB is reachable).
- **Lifting and HL-support tagging is the hard part.** The Cyc layer that converts a SQL row into a virtual assertion with a defensible HL-support is non-trivial. It must answer "where did this fact come from?" for any TMS user who follows the support chain. The lifted assertion is *not* persisted in the KB — it's recomputed every time the source is queried.
- **Rebuild from the macros outward.** The three surviving macros frame "before" and "after" hooks for SKSI work. A new port can use them as the integration points for the new infrastructure.
- **The `with-sksi-sql-connection-resourcing` reconstruction is genuinely unknown.** The TODO comment in the source records this: no Internal Constants binding evidence, no surviving call sites. A reimplementer designs fresh; nothing about the original's binding shape is recoverable from this file.
