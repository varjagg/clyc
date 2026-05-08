# Memoization & caching

Cyc has **two distinct caching mechanisms** for function results:

1. **Caching** (`defun-cached` / SubL `define-cached-new`) — a **global persistent cache**. Each cached function gets its own `*<name>-caching-state*` deflexical, holding a hashtable of args→result. Always caches; cache outlives any individual call.

2. **Memoization** (`defun-memoized` / SubL `define-memoized`) — a **state-dependent cache**. The cache is held in `*memoization-state*` (a dynamic variable bound by `with-memoization-state`); when no state is bound, the function runs uncached. Cache lifetime is the dynamic extent of the binding.

Both are implemented in `memoization-state.lisp` (483 lines). The companion `cache-utilities.lisp` (217 lines) provides cache-strategy and metrics infrastructure used internally — hit/miss counters and a metered-cache wrapper.

The distinction matters: caching is for "this function's answer never changes given the same args" (e.g. parsing a string, computing a permutation). Memoization is for "this function's answer depends on KB state, but we want to cache results for the duration of *this query* so we don't recompute them per inference step." When inference moves on, the memoization state is dropped and the next query starts fresh.

## Why two mechanisms?

Cyc inference repeatedly asks the same questions of the KB during a single query (e.g. "is X an instance of Y?", "what are the genls of Z?"). KB-state-dependent answers can't be globally cached because the KB might change between queries — but within a single query the KB is read-only, so caching is safe.

The split is:
- **Cached**: answers that are pure functions of their args (no KB lookup).
- **Memoized**: answers that read the KB but the KB won't change during this scope.

The `with-memoization-state` block scopes the assumption "no KB writes will happen here." If a KB write does happen, the user must invalidate or rebuild the memoization state.

## The shared structure: `caching-state`

Both caching and memoization use the same underlying hashtable wrapper:

```
(defstruct caching-state
  store              ; the hashtable (or new-cache for capped)
  zero-arg-results   ; sentinel-tagged slot for nullary functions
  lock               ; per-state lock (NIL = unlocked)
  capacity           ; max size before eviction (NIL = unbounded)
  func-symbol        ; for diagnostics
  test               ; hashtable test function
  args-length)       ; arity (used by the macro for key construction)
```

`zero-arg-results` is special-cased: a 0-arg function has no key to hash against, so the result lives in this slot rather than a hashtable. The sentinel `:&memoized-item-not-found&` distinguishes "uncached" from "cached NIL".

Both 1-arg and N-arg functions hash directly into `store`. For 1-arg, the key is the arg itself. For 2+ args, the key is `(list arg1 arg2 ...)` with `:test 'equal`.

### CL simplification vs. SubL original

The Java original used **per-arity sxhash + collision lists**: SubL hashtables couldn't hash list keys with `equal`, so the cache stored its own sxhash of the args list and walked a collision list comparing each arg individually. The hand-rolled hashing avoided consing a list key on every call.

The CL port relies on `(make-hash-table :test 'equal)` to hash list keys natively, which simplifies the macros but does cons a fresh list per call. The simplification is documented in the file (lines 73-86, 105-117). The `multi-hash` macro and `caching-state-enter-multi-key-n` function are retained for backward compat but unused by the macros.

## Global caching: `defun-cached`

```
(defun-cached compute-something (a b)
    (:capacity 1000 :test 'equal :clear-when :hl-store-modified)
  ... body ...)
```

Expands to:

1. `(defvar *compute-something-caching-state* nil)` — the global cache holder.
2. `(defun clear-compute-something () ...)` — clears the cache.
3. `(toplevel (note-globally-cached-function 'compute-something))` — registers in `*globally-cached-functions*`.
4. The wrapper function that:
   - Lazily initialises `*compute-something-caching-state*` on first call (under `*global-caching-lock*`).
   - Optionally registers a clear-callback if `:clear-when` was specified.
   - Looks up `(list a b)` in the cache; on miss, evaluates the body, stashes the multiple-value-list, returns via `caching-results`.

`caching-results` is the unwrap-multiple-values helper:

```
(defun caching-results (results)
  (if (cdr results)
      (values-list results)
      (car results)))
```

This preserves multi-value returns through the cache.

### `:clear-when` triggers

A cached function can register a callback for one of these triggers:

| Trigger | Variable | Fired when |
|---|---|---|
| `:hl-store-modified` | `*hl-store-cache-clear-callbacks*` | Any HL-level KB modification (assertion add/remove, etc.) |
| `:genl-mt-modified` | `*mt-dependent-cache-clear-callbacks*` (?) | MT structure changes |
| `:genl-preds-modified` | `*genl-preds-dependent-cache-clear-callbacks*` | A `#$genlPreds` or `#$genlInverse` assertion changes |
| `:genls-modified` | `*genls-dependent-cache-clear-callbacks*` | A `#$genls` assertion changes |
| `:isa-modified` | `*isa-dependent-cache-clear-callbacks*` | An `#$isa` assertion changes |
| `:quoted-isa-modified` | `*quoted-isa-dependent-cache-clear-callbacks*` | A `#$quotedIsa` assertion changes |

`*cache-clear-triggers*` is the master list of supported trigger keywords.

When a trigger fires (typically from the KB write side, e.g. `assert.lisp` calls `clear-hl-store-dependent-caches` after a store mutation), each registered callback is invoked. Currently the macro only supports `:hl-store-modified`; the others are reserved for stripped-out code. Cyc the engine would have a richer dispatch.

`*suspend-clearing-mt-dependent-caches?*` (default NIL) is a temporary suspension flag for batch operations. `(without-clearing-mt-dependent-caches body)` rebinds it to T so a batch of MT-touching operations doesn't trigger N redundant clears.

`clear-hl-store-dependent-caches` walks `*hl-store-cache-clear-callbacks*` and calls each one. Caches register via `register-hl-store-cache-clear-callback`.

## State-dependent memoization: `defun-memoized`

```
(defun-memoized lookup-fact (constant pred)
    (:test 'equal)
  ... body ...)
```

Expands to a wrapper that:

1. Reads `*memoization-state*`. If NIL, calls the body directly (no caching).
2. Otherwise looks up the function's caching-state inside the memoization state's `store` (a hashtable keyed by function name). Creates one on miss.
3. Looks up `(list constant pred)` in that caching-state. On miss, evaluates the body, stashes, returns.

The key difference from `defun-cached` is the **scope**: the cache lives only as long as `*memoization-state*` is bound. Outside of `with-memoization-state`, the function is uncached.

```
(defstruct memoization-state
  store              ; hashtable: function-name → caching-state
  current-process    ; tracking which thread owns this state
  lock               ; optional, for shared states
  name               ; diagnostic
  should-clone)      ; whether to clone-on-thread-fork
```

### Entry points

| Macro / function | Behaviour |
|---|---|
| `(create-memoization-state &optional name lock should-clone test)` | Mint a fresh state. |
| `(with-memoization-state state body)` | Dynamically bind `*memoization-state*` to `state` for the body. |
| `(with-new-memoization-state body)` | Mint + bind. Most common form. |
| `(with-possibly-new-memoization-state body)` | If a state is already bound, use it; else mint + bind. |
| `(memoization-state-clear state)` | Wipe all caches in this state. |
| `(clear-all-memoization state)` | Alias. |

`possibly-new-memoization-state` is the polite version — lets a caller offer a state to nested code without forcing a fresh allocation if the caller is already in a memoization scope.

## Shared globals

| Variable | Purpose |
|---|---|
| `*memoization-state*` | Currently-bound state, NIL when not memoizing. |
| `*memoized-functions*` | Master list of all functions defined with `defun-memoized`. |
| `*globally-cached-functions*` | Master list of all functions defined with `defun-cached`. |
| `*global-caching-lock*` | Single lock around the lazy-init of any global cache state. |
| `*function-caching-enabled?*` | If NIL, all caching/memoization is bypassed (debugging knob). |
| `*caching-mode-enabled*` / `*disabled*` | Set of cache mode flags (advanced selective control). |

## Bulk operations on global caches

| Function | Purpose |
|---|---|
| `globally-cached-functions` | Returns the live (still-fbound) entries in `*globally-cached-functions*`. |
| `global-cache-variables` | Returns the `*<name>-caching-state*` symbols — i.e. for each cached function, its variable name. |
| `global-cache-variable-values` | Resolves those symbols to their `caching-state` values. |
| `clear-all-globally-cached-functions` | Walks all global caches and clears each one. Used at KB-load time and as a debugging hammer. |

## Cache strategy & metrics (cache-utilities)

`cache-utilities.lisp` is the **cache-strategy abstraction** — separate from `caching-state` (which is a fixed hashtable wrapper). A "cache strategy" is an interface with operations like `note-cache-hit`, `note-reference`, `track`, `cache-full?` — used by code that wants pluggable caching policies (LRU vs. LFU vs. arbitrary).

The implementation uses CL generic functions:

- `cache-strategy-object-track strategy object` — record that `object` is a cache element. Returns the dropped object if full.
- `cache-strategy-object-tracked? strategy object` — is `object` currently in the cache?
- `cache-strategy-object-note-reference strategy object` — bump access count on `object` (for LRU/LFU).
- `cache-strategy-object-keeps-metrics-p strategy` — does this strategy track hit/miss counts?
- `cache-strategy-object-get-metrics strategy` — the `cache-metrics` struct.
- `cache-strategy-object-gather-metrics strategy metrics` — start gathering metrics into the given struct.
- `cache-strategy-object-p object` — predicate.

Two implementations:

| Struct | Purpose |
|---|---|
| `cache-metrics` (conc-name `CACHEMTR-`) | Just `hit-count` + `miss-count`. |
| `metered-cache` (conc-name `MCACHE-`) | Wraps a `cache` (LRU) with optional metrics. |

The CFASL opcode `*cfasl-wide-opcode-cache-metrics*` = 129 — so cache metrics are a serialisable type. Used when image dumps include cache-warming stats.

`recording-cache-strategy-facade` is a third struct (mostly stripped) — wraps a strategy and records every operation for replay/audit. Useful for testing cache behaviour.

The methods (`cache-strategy-mcache-object-track`, etc.) implement the metered-cache case. The `new-metered-cache` and `new-metered-preallocated-cache` constructors are how callers obtain one.

## How other systems consume this

- **Inference** ([../inference/inference-kernel-and-datastructures.md](../inference/inference-kernel-and-datastructures.md)) — wraps each query in `with-new-memoization-state`. KB-read functions like `min-isa`, `genls`, `disjoint-with?`, `arg1-isa`, `predicate-p` etc. are all defined with `defun-memoized` so a query reuses results across its tactics.
- **Canonicalisation** ([../canonicalization/el-to-hl-canonicalization.md](../canonicalization/el-to-hl-canonicalization.md)) — `defun-cached` for the EL-to-HL pipeline functions where the answer is a pure function of the input form (no KB read).
- **NL generation** (paraphrase-precision macros) — uses memoization heavily; one paraphrase call rebuilds the same templates many times.
- **`clear-hl-store-dependent-caches`** is called after every `assert.lisp` mutation to invalidate caches that depend on KB state.
- **`*memoization-state*`** is consumed by every memoized function on every call. The wrapper checks the binding before doing any work.
- **`global-cache-variables`** is consumed by debugging tools (e.g. KB-statistics commands) that want to enumerate all caches.

## Notes for a clean rewrite

- **Two mechanisms is the right design.** Don't merge them. Cached = global, persistent. Memoized = scoped, transient. The use cases are genuinely different.
- **Drop the per-arity sxhash machinery entirely.** The CL port already simplified to `(list args...)` keys with `:equal` — keep that and delete the dead code paths (`multi-hash`, `caching-state-enter-multi-key-n`, the `*caching-n-sxhash-composite-value*` constant).
- **Use CL hashtables, drop the `caching-state` struct.** A struct with one slot (hashtable) and a couple of conveniences is overkill. Inline the lookup + lock at the macro level.
- **Capacity-bounded caches need a real LRU.** The `new-cache` (LRU) integration is messy because it's "either hashtable OR LRU" via `if (caching-state-capacity cs)`. Pick one mechanism and use it always — modern LRU caches handle the unbounded case fine (just don't evict).
- **Cache-clear triggers should be event-based.** Currently each trigger is a global list of zero-arity callbacks. A clean rewrite should publish events ("hl-store-modified", "isa-modified", ...) and let cached functions subscribe declaratively. The trigger names are right; the wiring isn't.
- **`*function-caching-enabled?*` is a debug-only flag.** Keep it (useful for measuring "is the cache helping?") but make it a build-time conditional that elides the cache code, not a runtime check.
- **Memoization state is per-thread.** The `current-process` slot and `should-clone` flag exist because two threads sharing a memoization state need to avoid stomping each other. The default in inference is per-thread, no clone — keep that. A clean rewrite should not encourage cross-thread sharing of memoization state.
- **The cache-strategy generic-function approach is overengineered for two implementations.** `metered-cache` is the only non-trivial strategy; `recording-cache-strategy-facade` is mostly stripped. Drop the generic-function dispatch; just have `metered-cache` directly.
- **`caching-results` should not exist.** It's a workaround for storing multiple-value-list and unwrapping. A clean rewrite should not memoize multiple-value returns — that's a fringe case that adds complexity. If a function returns multiple values, take only the first.
- **`*memoized-functions*` and `*globally-cached-functions*` lists are debugging aids.** Keep them but make them lazy (build on demand) rather than `pushnew` at toplevel-load time — that's a startup-time tax.
- **Each cached function gets a `*<name>-caching-state*` global variable.** That's hundreds of dynamic variables, each one a separate symbol. A clean rewrite should hold the cache in a single registry hashtable keyed by function symbol, dropping the per-function variable.
- **The macros currently lazy-init the cache on first call.** That moves startup cost to the first user. A clean rewrite should pre-initialize at definition time — startup is when caches are cold anyway.
- **The `:test` keyword has subtle behavior**: 1-arg uses the caller's test, 2+-arg forces `:equal`. Document this clearly or drop the option entirely (always use `:equal` for 1-arg too — the difference matters only for huge numerical caches, which Cyc doesn't have).
- **`cache-strategy-track` returns the dropped object.** That's the right design for LRU eviction notification. Keep it; in a clean rewrite, formalize "cache eviction events" as a first-class concept (callers might want to signal "the dropped item is no longer hot").
