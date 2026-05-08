# Encapsulation (cross-image transport)

Encapsulation is the **portable representation of FORTs** for crossing image boundaries via the API or transcript stream. Where CFASL externalization solves "how do I serialize a constant onto a byte stream", encapsulation solves "how do I rewrite a CycL form so its constant references travel by GUID + name and survive being read by a different image". The two systems both use GUIDs as the underlying identity, but encapsulation produces a **CycL-readable s-expression**, not a binary stream.

The implementation is `encapsulation.lisp`. The full Cyc engine has both directions; the LarKC port has the encapsulate side working for constants and most of unencapsulate stripped.

A separate concept also called "encapsulate" lives in canonicalization (`*encapsulate-var-formula?*`, `encapsulate-formula?` in `czer-utilities.lisp`, `encapsulate-formula` in clausifier) and is unrelated — that's the logical-operator-wrapping for variables in CycL formulas. Don't conflate them. This doc covers cross-image transport encapsulation only.

## Port status: encapsulate works, unencapsulate doesn't

| Direction | State |
|---|---|
| `encapsulate` cons | working |
| `encapsulate` constant | working |
| `encapsulate` NART | calls `missing-larkc 30834` |
| `encapsulate-constant-internal` | working |
| `encapsulate-nart-internal` | active declareFunction, no body |
| `unencapsulate` and all helpers | active declareFunctions, no bodies |

A clean rewrite needs both. The encapsulate side is small enough that the unencapsulate side is mechanically derivable from the wire formats listed below plus the constant/NART tables.

## What gets encapsulated

`encapsulate object`:

| Object type | Result |
|---|---|
| `cons` | `(recons (encapsulate car) (encapsulate cdr) object)` — recursive descent. |
| `constant` | `(:hp <name-or-:unnamed> <guid>)` |
| `nart` | (stripped — would be a `:nat` form, see below) |
| anything else | the object unchanged |

The `recons` call (rather than naked `cons`) preserves the cons-cell identity when no descendant changed — important for forms that are uneconomical to rebuild and for cycle preservation if the input had structural sharing.

The dispatch is a `typecase`. The Java original used a 256-element `*encapsulate-method-table*` indexed by SubL type tag, with `register_method` calls to install the per-type encoder. The CL port collapses this to direct typecase. `*encapsulate-method-table*` is preserved as a commented-out deflexical and the per-type entry points (`encapsulate-cons-method`, `encapsulate-constant-method`, `encapsulate-nart-method`) survive as defuns that just dispatch to the worker.

## The constant encapsulation form

`encapsulate-constant constant`:
1. Validate `(valid-constant? constant)`.
2. Validate `(constant-external-id-p (constant-external-id constant))` — the constant must have a GUID.
3. Validate that the name is either `:unnamed` or a string.
4. Build `(:hp <name> <external-id>)` via `encapsulate-constant-internal`.

The result is a 3-element list:

```
(:hp <name>          <external-id>)
   keyword tag       16-byte GUID
              constant name string, or :unnamed
```

The `:hp` keyword (originally `$kw9$HP`) is the discriminator — every encapsulated constant starts with `:hp` so the unencapsulator can dispatch. Why "HP" — it's a Cyc-internal abbreviation; the formal expansion is "handle pointer" / "handle plus". The choice predates this code.

Constants without names (the `:unnamed` case) — e.g. internal anonymous constants used during inference scratch space — still encapsulate, just with the `:unnamed` keyword in the name slot. The id-fail-name-fall-back path on the unencapsulate side relies on the name being there for cases where the GUID has been merged or invalidated, but `:unnamed` constants always need GUID resolution.

## The NART encapsulation form (stripped, but recoverable)

NART encapsulation is `missing-larkc 30834`. The intended wire format is recoverable from the orphan Internal Constants:

| Constant | Value | Use |
|---|---|---|
| `$kw10$NAT` | `:nat` | Discriminator keyword for NART encapsulations. |
| `$str8$Attempt_to_encapsulate_the_NART__` | error string | Validation failure message. |
| `$list14` | `(NAT NART-HL-FORMULA-SPEC &OPTIONAL ID)` | Destructuring pattern for the corresponding `unencapsulate-nart-marker`. |

So the NART form is `(:nat <hl-formula-spec> [<id>])`:
- `:nat` discriminator
- the NART's HL formula spec (a recursively-encapsulated CycL list — the `(<reified-function> arg1 arg2 ...)` form)
- optional dump-id for fast in-image lookup

Unencapsulating a NART works by re-canonicalizing the formula spec (which finds-or-creates the NART), with the optional id used as a cache hint when the receiving image happens to share the dump-id space.

## Reverse direction: unencapsulate (stripped)

The unencapsulate path is entirely missing-larkc, but the orphan constants and helper signatures suggest the design:

| Function (signature) | Purpose |
|---|---|
| `unencapsulate object` | Top-level — dispatches by car keyword. |
| `unencapsulate-partial object` | Variant that doesn't fully resolve (leaves stubs). |
| `unencapsulate-internal object full?` | Worker; `full?` controls partial-vs-full. |
| `unencapsulate-token-equal-p tok1 tok2` | Match keyword tags case-insensitively. |
| `unencapsulate-common-symbol object` | Pass-through for the small list of self-encapsulated symbols (`:monotonic`, `:default`, `:forward`, `:backward`, `:code` from `*unencapsulated-common-symbols*`). |
| `unencapsulate-cons object full?` | Recursive descent on cons cells. |
| `unencapsulate-constant-marker object full?` | Handle `(:hp name external-id)` — find or create the constant. |
| `unencapsulate-constant-marker-int` | Inner step. |
| `unencapsulate-find-constant object` | The lookaside-cached lookup; uses `*unencapsulate-find-constant-lookaside-table*`. |
| `unencapsulate-nart-marker object full?` | Handle `(:nat hl-formula-spec [id])`. |
| `handle-unencapsulate-constant-problem` | Triggered when GUID resolution fails. Decides whether to consult the name (per `*unencapsulate-believe-names*`) or report an error. |
| `handle-unencapsulate-unnamed-constant-problem` | Same, for `:unnamed` constants — name fallback impossible. |
| `handle-unencapsulate-nart-problem` | Same, for NARTs. |
| `handle-unencapsulation-error` | Signal a continuable error, with `cerror` restart string `"Skip this operation"` and message format `"~%Last operation: ~S ~%This object did not yield a term: ~S"` (orphans `$str16` / `$str17` / `$str18`). |

Two control parameters drive the resolution policy:

| Variable | Default | Purpose |
|---|---|---|
| `*unencapsulate-believe-names*` | nil | When t and the GUID lookup fails, fall back to name lookup. The default is to fail loudly — names are mutable, GUIDs are not, so name-based recovery is a soft compromise. |
| `*unencapsulate-constant-via-name-optimization?*` | nil | When t, lookup by name first (faster) and verify the GUID after. Useful when the receiving image is known to have all the constants by name. |
| `*unencapsulate-find-constant-lookaside-table*` | nil (defglobal) | A small memoization cache, capped at `*unencapsulate-find-constant-capacity*` = 20 entries. Speeds repeat lookups in the same encapsulated tree. |

## Common-symbol passthrough

`*unencapsulated-common-symbols*` is a 5-element alist:

```
((monotonic :monotonic)
 (default   :default)
 (forward   :forward)
 (backward  :backward)
 (code      :code))
```

These are paired symbols where the runtime form is the unprefixed symbol and the wire form is the keyword. Because Cyc uses both forms in different contexts (transcript ops use `monotonic`/`forward` as bare symbols, but the externalized form prefers keywords for portability across packages), the table tells `unencapsulate-common-symbol` to pass these through unchanged when they appear in already-correct form. The five entries cover the assertion direction tokens (`:monotonic` for monotonic assertions, `:default` for default-true, `:forward`/`:backward` for inference direction, `:code` for code-supported assertions).

## When does encapsulation happen?

There are exactly **three situations** where a CycL form gets encapsulated in this system:

1. **An API/transcript operation needs to be transmitted** — `form-to-api-op` (`operation-queues.lisp`) is called when adding to the local or remote queue, and it encapsulates the form (optionally wrapping it first in `with-bookkeeping-info`). The encapsulated form is then enqueued for execution on the receiver, which unencapsulates and `eval`s it.
2. **A KE (knowledge editor) operation is being recorded** — `tl-encapsulate` in `canon-tl.lisp` first transforms HL terms to TL form, then encapsulates. Used by `ke.lisp` for `fi-create`, `fi-assert`, `fi-kill`, `fi-timestamp-constant`, `fi-timestamp-assertion` operations. The encapsulated TL form is what goes into the transcript file — a permanent log of edits, replayable on a freshly-loaded KB.
3. **A cyclist record is being attached to a transcript entry** — `add-to-transcript-queue` calls `(encapsulate (the-cyclist))` so the cyclist constant is portable across images.

There is no other path. Encapsulation is invoked at the API/transcript boundary, never inside the inference engine or KB store directly. A clean rewrite should preserve this — the encapsulation/unencapsulation pair should be a thin adapter at network/disk-format boundaries, not a pervasive transformation.

## Why this exists alongside CFASL externalization

Both systems answer "how do FORTs travel between images." They differ on shape:

| | Encapsulation | CFASL externalization |
|---|---|---|
| Output | s-expression (`(:hp ... ...)`) | binary opcode stream |
| Reader | `read` + `unencapsulate` | `cfasl-input` |
| Self-describing? | yes (keyword tag) | yes (opcode byte) |
| Used by | API queue, transcript, KE | dump files, externalized CFASL streams |
| Round-trip cost | Lisp reader runs | bit-level decoder runs |
| Human-readable? | yes | no |
| Embeddable in CycL? | yes (it *is* a CycL list) | no |
| Cycle support | via `recons` (preserves shared structure) | via complete-constant opcode |

Transcripts and API operations are CycL forms by their nature — the receiver reads them and `eval`s them as Cyc commands. Encapsulating a transcript form keeps it as a CycL form; binary CFASL would make the transcript unreadable. Conversely, dumps want compactness and don't need human-readability, so CFASL externalization is the right hammer there.

## How encapsulated forms get evaluated

On the receiving side (mostly stripped in the port), the lifecycle is:

1. Read s-expression from API socket / transcript file.
2. `unencapsulate` it, replacing every `(:hp ...)` with the local constant handle and every `(:nat ...)` with the local NART. New constants are created on-demand if not present locally — or fail per the `*unencapsulate-believe-names*` policy.
3. The result is a normal CycL form referring to local handles.
4. `eval` it against the API.

The transformation is purely syntactic: nothing semantic changes. A cross-image `(fi-assert (#$genls #$Dog #$Mammal) #$BiologyMt)` stays semantically the same; only the constant references go through `(:hp "Dog" <guid>)` → local handle on the wire.

## Cyclist string variant

`encapsulated-cyclist-string` and `unencapsulate-to-string` / `unencapsulate-string` (all stripped) suggest a string-form variant where an encapsulated form is rendered as a string for storage and parsed back. Likely used by `transcript-utilities` for transcript files where each line is a single encapsulated form rendered to a string with normal CL printing. The string variant is just `(format nil "~S" (encapsulate form))` and back; no separate code is needed in a clean rewrite.

## Notes for a clean rewrite

- **Cleanly separate transport-encapsulation from formula-encapsulation.** They share a name and nothing else. Pick distinct names — maybe `externalize`/`internalize` for transport, `encapsulate-formula`/`encapsulate-var` for the canonicalizer's logical wrapping. The current ambiguity confuses readers in two unrelated parts of the system.
- **Use a real algebraic data type, not list-with-keyword-discriminator.** `(:hp name guid)` is what you write in a wire format you have to keep readable; in the running image, parse it once at the boundary into a struct (or class instance, or tagged record) and stop pattern-matching on it everywhere.
- **The 5-entry `*unencapsulated-common-symbols*` table is a smell.** It exists because keyword symbols were treated specially by SubL's package system. CL doesn't have that constraint. Either pick keyword form everywhere or symbol form everywhere; drop the table.
- **The lookaside cache (capacity 20) is too small to matter and too big to skip.** Either drop it (constants lookups are already O(1) by GUID hashtable) or make it per-encapsulated-tree, not global. The global form has lifecycle problems — when does it get cleared?
- **`*unencapsulate-believe-names*` should be a per-call argument, not a dynamic var.** The decision of "should we fall back to name lookup" depends on the use case; an API server might say no, a transcript replay might say yes. Threading a `:believe-names?` keyword through is cleaner.
- **The NART stripping is the painful gap.** Without `encapsulate-nart-internal` and the unencapsulate-nart-marker pair, no transcript that contains a NART can survive cross-image transport. A clean rewrite must rebuild this from `$list14` = `(NAT NART-HL-FORMULA-SPEC &OPTIONAL ID)` — the formula-spec is a recursively-encapsulated `(<reified-function> <arg1>...)` list, the optional id is a hint, and the worker calls `find-nart-by-hl-formula` on the receiver side to materialize.
- **Constants that don't have a name (`:unnamed`) are a real case but rare.** A clean rewrite should make sure unencapsulate handles the unnamed case before falling back to name. The `handle-unencapsulate-unnamed-constant-problem` slot exists for this.
- **`recons` is correct and worth keeping** — preserving cons identity across no-op transformations matters for memoization, structure sharing, and equality preservation in the calling canonicalizer.
- **Store a version field.** As soon as you ship encapsulated transcripts, format changes break old transcripts. A leading version on the encapsulated form (`(:hp/v2 ...)`) gives you a migration path.
- **Consider externalizing more types.** Right now only constants and NARTs need transport identity. Variables (which have global ids only inside an image) are encoded by leaving them as bare `?X` symbols, which is correct because variables don't need cross-image identity. But assertions, deductions, and KB-HL-supports do — they are already encapsulated by serializing their formula and looking them up on the other side, which is implicit in CycL's form structure. Make this explicit so the rewriter doesn't accidentally re-implement it.
