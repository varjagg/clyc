# Obsolete

`obsolete.lisp` is the **dead-letter file** — a tiny home for functions that should be removed but are still called from somewhere in the codebase. Four surviving functions, all aliases or trivial wrappers around their replacements:

```
(defun cycl-system-number () (or (first (cyc-revision-numbers)) 0))
(defun cycl-patch-number () (or (second (cyc-revision-numbers)) 0))
(defun reifiable-nat? (term &optional (var? #'cyc-var?) mt) (reifiable-naut? term var? mt))
(defun cnat-p (object &optional (var? #'cyc-var?)) (closed-naut? object var?))
```

The header comment is the design intent:

> TODO - mark everything as deprecated. Presumably things in this file are still referenced.

The four entries are kept because **somewhere in the codebase a call site uses them**, and rather than chase down all the call sites in one go, the obsolete versions are quarantined here as one-line forwarders. A clean rewrite gets to delete the file once all call sites are updated.

## What's here and why

### `cycl-system-number` / `cycl-patch-number`

The original Cyc had `cycl-system-number` (e.g. 10) and `cycl-patch-number` (e.g. 128948) as separate functions. Newer code uses `cyc-revision-numbers` ([control-vars.md](control-vars.md)) which returns the whole list `(10 128948 ...)` — first is system-number, second is patch-number, third+ are sub-revisions. The obsolete two-function API is preserved for callers that hard-code the split.

`(or ... 0)` defends against `cyc-revision-numbers` returning NIL — if the revision string didn't parse (no SVN keyword substituted), the revision-numbers list is empty.

Both are registered via `register-api-predefined-function` in `eval-in-api-registrations.lisp` so the API still exposes them — meaning external clients depend on the names. Renaming would break wire-compat.

### `reifiable-nat?` / `cnat-p`

The Cyc terminology evolved:

- **NAT** (Non-Atomic Term) is the older term — any compound CycL expression like `(GovernmentFn USA)`.
- **NAUT** (Non-Atomic Un-Reified Term) is the newer term, distinguishing a "raw" un-reified compound expression from a NART (Non-Atomic Reified Term, which is a NAT that got an internal id).

The renaming wasn't applied uniformly — some old call sites still ask `(reifiable-nat? form)` instead of `(reifiable-naut? form)`. The obsolete file just forwards the call.

`cnat-p` is "closed NAT predicate"; `closed-naut?` is its replacement. Same story.

## When does an obsolete function come into being or disappear?

| Trigger | Effect |
|---|---|
| A Cyc release renames or splits an API function | The old name is moved to `obsolete.lisp` as a trivial wrapper. |
| Call sites are updated to use the new name | The wrapper has no callers. It can be removed. |
| All call sites are updated in one release | The whole file can be deleted (or shrunk further). |

The file is **monotonically shrinking** — the only operations on it are "remove an entry that no longer has callers." Adding a new entry is also possible (deprecating a fresh function) but that's rare in the LarKC-era codebase.

## How obsolete is consumed

Searching the codebase for the four functions:

- `cycl-system-number`, `cycl-patch-number` — referenced in `eval-in-api-registrations.lisp` (registration) and possibly in some test code. Both are still externally exposed via the API.
- `reifiable-nat?`, `cnat-p` — used in a few older `el-utilities.lisp` paths and the canonicaliser ([../canonicalization/term-and-formula-utilities.md](../canonicalization/term-and-formula-utilities.md)).

A clean rewrite should grep for these and update each call site.

## Notes for a clean rewrite

- **Use the host language's deprecation mechanism.** CL has `style-warning` on call; many languages have `@Deprecated` annotations or `#[deprecated]` attributes. A clean rewrite should mark old entries with deprecation warnings so the compiler logs every call site for cleanup.
- **`cycl-system-number` / `cycl-patch-number` should go.** Callers can call `(first (cyc-revision-numbers))` and `(second (cyc-revision-numbers))` directly — there's no abstraction worth preserving in the wrappers.
- **`reifiable-nat?` / `cnat-p` should go.** Same as above — call the new names. The semantics are identical.
- **`obsolete.lisp` as a quarantine pattern is fine but tedious.** Modern languages express deprecation inline (annotation/attribute on the actual function) — keeps the deprecated name with its replacement, avoids cross-file lookups, and makes deprecation removable in one diff.
- **The file's existence is a signal of incomplete refactoring.** Eventually it should be empty and deleted. Track this as a real chore, not as "presumably things in this file are still referenced."
- **Once cycl uses semver and a release notes process,** the obsolete-file-pattern can be replaced by "removed in 2.0; use X instead" entries in changelog. No backward-compat wrappers in source.
