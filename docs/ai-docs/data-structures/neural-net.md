# Neural net

A 141-line file that defines two structs (`neural-net` with a single `input-nodes` slot, `nn-input-node` with two slots `value` and `weights`), a hard-coded weights matrix harvested from a file called `Champ0_19.gnm`, a global variable `*rl-tactician-neural-net*` that would hold the live network, and a half-dozen function shells named `rl-tactician-evaluate-neural-net`, `rl-tactician-compute-neural-net-output`, `sigmoid`, etc. **Every function body is missing-larkc**, and **no caller in `larkc-cycl/` references any of these symbols**. The structure is unmistakable: this was the inference-engine **reinforcement-learning tactician's policy network** — a tiny feed-forward net that scored candidate inference tactics so the strategist could prefer the ones the trained model thought would close the proof faster. In the LarKC port, only the trained weights and the module skeleton survive.

## What was here

```
(defstruct neural-net
  input-nodes)

(defstruct nn-input-node
  value
  weights)
```

The shape is one input layer of `nn-input-node`s, each carrying its current `value` (the activation) and a vector of `weights` (the outgoing edges to the next layer's nodes). The weights matrix is a list of 21 rows × 5 columns of `double-float`s — i.e. 20 input features + 1 bias, projecting to 5 outputs. Comment: "From Champ0_19.gnm, with the first list of weights moved to the end (the bias node weights)."

The output layer presumably sums the weighted inputs through `sigmoid`. The architecture is the simplest possible: one hidden-or-output layer, no recurrence, no convolution, just `output = sigmoid(W·input + b)`.

The variable / function naming pattern (`rl-tactician-*`) is the strongest evidence about purpose. In Cyc's inference engine the **reinforcement-learning tactician** is a strategist variant that chose between candidate tactics (transformation vs. removal vs. residual-transformation, etc.) using a learned policy. The 5 outputs match what such a policy net would produce: a per-tactic-class preference score. The 20 inputs are 20 inference-state features (depth, branch count, residual size, etc.) computed by `rl-tactician-compute-neural-net-input-values (a b c d)` — the four-arg signature is suggestive (the four numbers feed the 5-input feature extractor whose 20-element output is the network input vector? — uncertain; the function is stub).

## Public API (neural-net.lisp) — what survives

| Item | Status |
|---|---|
| `defstruct neural-net (input-nodes)` | Present. |
| `defstruct nn-input-node (value weights)` | Present. |
| `*dtp-neural-net*`, `*dtp-nn-input-node*` | Constants. |
| `*rl-tactician-neural-net-weights-list*` | The trained weights — 21 lists of 5 doubles each. Real value, kept verbatim. |
| `*rl-tactician-neural-net*` | `defglobal nil` — would hold the live `neural-net` struct after `rl-tactician-initialize-neural-net` runs. |

Every function entry point is **active declareFunction with no body** (i.e. a stub the rewriter intentionally retained for symbol-existence but did not implement):

| Function | Intent (from name) |
|---|---|
| `new-neural-net weights-list` | Build a `neural-net` struct with one `nn-input-node` per row of weights, plus the bias row. |
| `neural-net-input-node-count nn` | Length of `nn-input-nodes`. |
| `neural-net-set-inputs nn inputs` | Populate each input node's `value`. |
| `sigmoid x` | The activation function (`1 / (1 + exp(-x))`). |
| `new-nn-input-node value weights` | Mint a node. |
| `nn-input-node-set-value node value` | Setter. |
| `rl-tactician-initialize-neural-net` | Allocate `*rl-tactician-neural-net*` from `*rl-tactician-neural-net-weights-list*`. |
| `rl-tactician-neural-net` | Accessor (lazy-init pattern: returns `*rl-tactician-neural-net*` after ensuring it's built). |
| `rl-tactician-evaluate-neural-net a b c d` | Compute the policy output for inference state `(a, b, c, d)`. |
| `rl-tactician-set-neural-net-input-values a b c d e` | Variant taking five inputs. |
| `rl-tactician-compute-neural-net-input-values a b c d` | Feature extractor: turn 4 raw inference-state numbers into the 20-element input vector. |
| `rl-tactician-compute-neural-net-output nn something` | Forward pass: weighted sum + sigmoid → 5 outputs. |
| `rl-tactician-indexes-we-care-about thing` | Pick which subset of the 5 outputs (or which subset of inference state) is read out. |

## Where this fits — and the dead-code finding

**Zero callers in `larkc-cycl/`.** A wide grep for `neural-net`, `nn-input-node`, `rl-tactician-neural`, `sigmoid` in every Lisp file outside `neural-net.lisp` finds exactly one match: `system-version.lisp` line 430 has the string `"neural-net"` in the cycl-module manifest. That is not a call site.

In the Java tree, the only reference outside `neural_net.java` is `cycl.java`'s `SubLFiles.initialize("com.cyc.cycjava.cycl.neural_net");` — the module loader registering the file. **Even the inference balanced tactician motivation files (which do reference an `rl-tactician` strategy) do not call any function from neural-net.java**: the tactician motivation references `*balanced-strategy-rl-tactician-tactic-types*` and `merge-balanced-and-rl-tactician-strategems` (which live in `inference_balanced_tactician_motivation.java`), not anything in `neural_net.java`. The naming is correlated; the linkage is not.

So the file is **functionally dead in both the Java original and the Lisp port** — every body is `handleMissingMethodError` in Java (or comment-stubbed in Lisp), and no other module calls any of these functions. The trained-weights matrix, the module loader registration, and the symbol-table presence are the only things that actually run.

## CFASL

`*dtp-neural-net*` and `*dtp-nn-input-node*` are declared, so the structs round-trip through generic `defstruct` CFASL. There is no dedicated opcode, no per-type CFASL method registration. A serialized neural-net would persist its `input-nodes` slot (a list of `nn-input-node` structs each with a value and a weights list of doubles), which is round-trippable with the default machinery. Not exercised in practice since nothing builds one.

## Notes for a clean rewrite

- **Drop the file entirely.** This is the strongest delete-candidate in the data-structures docs so far. Justification: (1) every body is `missing-larkc`/`handleMissingMethodError`, (2) nothing calls any of the functions, even within the original Java, (3) the only persistent value is a 105-double trained-weights matrix specific to a long-since-replaced inference tactician strategy, (4) the architecture is trivial enough to reproduce in any modern ML library in 5 lines if it ever needed to come back. The clean-rewrite checklist is: confirm the RL tactician strategy is not a target, then delete `neural-net.lisp`.
- **The `Champ0_19.gnm` weights are an artifact of a one-off training run.** Even if a future rewrite wants an RL tactician, it should retrain on the new system, not transplant 1990s weights. The matrix has no archival value.
- **If the RL tactician is brought back, do not reimplement this scaffolding.** Use a real ML library (CL options: `clml`, `cl-mathstats`; Python interop via `py4cl`; or just call out to PyTorch). One-input-layer feed-forward nets are the *smallest* possible NN and writing one by hand is twice the code of calling a library.
- **`sigmoid` is one expression.** Inlining it eliminates the function call entirely; modern frameworks fuse activations with the matmul anyway. Don't keep it as a separate stub.
- **The struct shape (one `input-nodes` list of nodes, each with `value` and `weights`) is the wrong representation for production NN code.** Modern code uses contiguous numerical arrays (CL: `make-array :element-type 'double-float`), not lists of structs. Per-node allocation is GC pressure for no benefit; vectorized matrix operations are the norm. The original SubL representation is a textbook example of how *not* to lay out neural-net data in 2026.
- **Confirm before deleting that no quirk-trampolines or eval-in-API registration mentions any of these symbols.** A grep over `eval-in-api-registrations.lisp` and `quirk-trampolines.lisp` should be clean — the file has no exposed API surface.
- **Document the deletion in `port-status.md`** so future maintainers don't try to "finish" implementing the RL tactician by writing bodies for these stubs. The bodies belong in a real ML stack, not here.
