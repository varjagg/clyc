# Verbosifier & standard-tokenization

Two tiny stub files, both **near-totally LarKC-stripped** but with a coherent surviving design that documents *what was meant to be there*. Both are NL-flavoured utilities — the verbosifier is for **rewriting CycL formulas with their EL-relation expansions** so a paraphraser sees the expanded form; standard-tokenization is for **breaking input strings into word/punctuation tokens** before they're fed to the parser.

Files covered:

- `verbosifier.lisp` (116 lines) — **EL-relation expansion**. EL relations are predicates with definitional rules (`(elDefn predicate cnf)` assertions); "verbosifying" a formula means recursively replacing each EL-relation occurrence with its definition. Surviving: 2 dynamic parameters, 1 reconstructed macro, 1 active function. **30+ stripped functions.**
- `standard-tokenization.lisp` (126 lines) — **string tokenization with dot-aware punctuation**. The "dot analysis" is a DFA that distinguishes "Mr." vs. "the cat." vs. "10.5" — same character (`.`), different roles. Surviving: 3 character-class lists, 1 defstruct (`dot-analysis`), 1 type tag. **42 stripped functions.**

These are stub-spec files: design surface preserved, implementation gone. The clean rewrite needs to rebuild the implementations from the function names, the surviving variables, and their original semantics.

## Verbosifier

### What "verbosify" means

A CycL formula like:

```
(#$pomeranianBreed ?X)
```

uses the EL-relation `#$pomeranianBreed` which has an EL definition:

```
(#$elDefn #$pomeranianBreed
  (#$and (#$isa ?X #$Pomeranian)
         (#$dogBreedOf ?X #$DomesticDog)))
```

Verbosifying replaces the relation with its definition:

```
(#$and (#$isa ?X #$Pomeranian)
       (#$dogBreedOf ?X #$DomesticDog))
```

The result is **logically equivalent** but uses only primitive predicates — readable by tools that don't know about `#$pomeranianBreed`.

The verbosifier supports recursive expansion (replace nested EL-relations too), one-shot expansion (just the top level), destructive vs. non-destructive (mutate or fresh-cons), and **expansion-justification gathering** — when an expansion happens, accumulate the justification (which `#$elDefn` assertions were used) so the user can see *why* the formula expanded the way it did.

### Surviving entry points

```
verbosify-cycl sentence &optional mt verbosity
verbosify-cycl-justified sentence &optional mt verbosity
el-expansion relation mt
el-expansion-destructive relation mt
el-expansion-one-step relation mt
el-expansion-one-step-destructive relation mt
el-expand-all relation mt
el-expand-all-destructive relation mt
el-expandible-subformula? formula &optional mt
```

All LarKC-stripped (active declareFunctions, no body). Plus the `*-justified` variants that gather expansion justifications.

The one **active surviving function**:

```
(defun expandible-el-relation-expression? (object &optional mt)
  (and (el-formula-p object)
       (isa-el-relation? (formula-arg0 object) mt)))
```

A predicate: returns T iff `object` is an EL formula whose arg0 is an EL-relation in the given `mt`. This is the gate that drives the recursion — the verbosifier calls this at each subexpression to decide whether to expand it.

### The justification mechanism

```
*gather-expansion-justifications?*    ; defparameter, default NIL
*expansion-justification*             ; defparameter, default NIL
```

When `*gather-expansion-justifications?*` is T, every expansion accumulates a record into `*expansion-justification*`. When NIL, the expansion runs but no record is kept (faster, less memory).

The reconstructed macro:

```
(defmacro gathering-expansion-justifications (&body body)
  `(let ((*gather-expansion-justifications?* t)
         (*expansion-justification* nil))
     ,@body))
```

Wraps `body` such that justifications get collected. Combined with the `*-justified` variants of the verbosify functions, this is how a caller asks "verbosify this sentence and tell me which `#$elDefn` rules you used."

`*el-relation-recursion-limit*` = 212 — bounds the recursion depth in case of mutual recursion in EL-relation definitions.

### When does verbosification happen?

In Cyc the engine, the verbosifier is invoked by:

- **The paraphraser** (NL generation) when rendering a formula that uses EL-relations the paraphrase template doesn't recognise. Verbosify first; then paraphrase the expanded primitives.
- **The query analyser** when transforming a query for the inference engine — some inference modules don't dispatch on EL-relations, so verbosifying first avoids "no module knows about this predicate" errors.
- **The KB browser** when displaying a formula in "expanded" mode for users who want to see the full definition.

In the LarKC port, none of these consumers have surviving callers (paraphrase is mostly missing-larkc, the query analyser uses only primitive predicates, the KB browser is stripped). So `expandible-el-relation-expression?` is the only externally-callable hook from this file.

### When does an EL-relation get a definition?

(Note: this is about the predicate definitions, not the verbosifier's runtime state.)

EL-relations are FORTs that have `#$elDefn` assertions naming a CNF that defines them. The definition assertions are ordinary KB assertions, created/modified/destroyed by the normal KE pipeline. The verbosifier reads them at runtime via lookups (presumably `lookup-el-defn` or similar — not in this file).

The verbosifier's own state (`*gather-expansion-justifications?*`, `*expansion-justification*`) is **per-call dynamic** — bound by the macro for the body's duration. No persistent verbosifier state exists.

## Standard-tokenization

### What tokenization means

Input: a string like `"Mr. Smith bought 10.5 pounds of meat."`
Output: a sequence of tokens, classified by type:

```
("Mr." abbreviation)
("Smith" word)
("bought" word)
("10.5" number)
("pounds" word)
("of" word)
("meat" word)
("." sentence-end)
```

The hard part: the same character (`.`) plays different roles. After "Mr" it's an abbreviation marker; after "meat" it's sentence-end; in "10.5" it's a decimal point. The "dot analysis" is the DFA-based routine that decides which.

### Surviving design surface

Three character-class lists:

```
*standard-punctuation-chars* = ; , : " ' ! ? ( ) % $ - ^ *
*standard-word-final-punctuation-chars* = .          ; only treated as punctuation when word-final
*standard-white-space-chars* = (whitespace-chars)
```

The dot is special — it's only punctuation when it ends a word, never when it appears mid-word. So `Mr.` is one token (abbreviation) and `Mr.Smith` (no space) is two tokens with `.` as separator. The split between lists captures this.

### The `dot-analysis` defstruct

```
(defstruct dot-analysis
  found         ; tokens found so far
  remains       ; characters still to process
  accumulator   ; current partial token being built
  state)        ; DFA state (e.g. :word, :number, :seen-dot, :end)
```

This is a DFA-state holder. The DFA states (LarKC-stripped) would be: `:start`, `:word`, `:number`, `:seen-dot-after-letter`, `:seen-dot-after-number`, `:end`. Transitions on character class. On state `:end` the partial token is committed.

`*dtp-dot-analysis*` = `'dot-analysis` is the type tag.

### Surviving functions

None. All 42 declareFunctions in the original Java are commented stubs. The list itself is informative:

| Function | Purpose |
|---|---|
| `standard-raw-tokenization string` | Top-level entry point. Returns list of tokens. |
| `standard-token-chunker sentence` | Combines adjacent tokens into chunks (e.g. multi-word phrases). |
| `standard-string-tokenize string` | Probably calls `standard-raw-tokenization` then unwraps. |
| `tokenize-sentence string &optional punctuation-chars white-space-chars word-final-punctuation-chars` | Tokenize with custom character classes. |
| `scanner-char-classify char ...` | Per-character classifier — returns :punctuation, :white-space, :word-character, etc. |
| `perform-dot-analysis string` | Run the dot DFA. |
| `init-dot-analysis string` | Construct the initial `dot-analysis` for `string`. |
| `find-current-dot-type analysis` | Inspect the analysis to determine what the current `.` is doing. |
| `dot-analysis-dfa analysis` | The state-transition function. |
| `clean-dot-accumulator analysis char` | DFA action on a character. |
| `new-interval-token start end value` | A token expressed as `(start, end, value)` indices into the source string. |
| `interval-token-p`, `-start`, `-end`, `-length`, `-value`, `-value-set` | Accessors for an interval-token. |
| `new-string-token string value` | A token expressed as `(string, value)` — its own copy of the chars. |
| `string-token-p`, `-string`, `-value`, `-string-set`, `-value-set`, `copy-string-token` | Accessors for a string-token. |

The two token representations (interval vs. string) trade copy cost vs. retain-source cost. Interval-tokens reference the original string; string-tokens own their chars. The tokenizer probably defaults to interval (cheap) and converts to string-token only for tokens that survive past the source string's lifetime.

### When does tokenization happen?

In Cyc the engine, the tokenizer is invoked by:

- **The CycL string parser** (NL → CycL conversion) before grammar-driven parsing. The parser wants tokens, not raw characters.
- **The paraphraser**'s reverse-direction utility (CycL → string round-trip via tokenize + re-emit).
- **`rkf-phrase-reader`** and friends in the RKF (Rapid Knowledge Formation) tooling for reading user input.

In the LarKC port, none of these survive in working form. `standard-tokenization.lisp` is design-surface only.

## How other systems consume verbosifier and tokenization

- **Verbosifier** — the only surviving consumer is `expandible-el-relation-expression?` (called from somewhere unknown — most call sites are stripped). The verbosifier is a leaf: nothing else depends on its state.
- **Tokenization** — consumed by the paraphrase / NL pipeline (mostly stripped). The character-class lists `*standard-punctuation-chars*` etc. are referenced only by callers within this same file's stripped functions; they have no live external readers.

## Notes for a clean rewrite

### Verbosifier

- **The verbosifier is a tree walk with a definition-lookup callback.** Reimplementation is straightforward: walk the formula, for each subexpression check `expandible-el-relation-expression?`, if true look up the `#$elDefn`, substitute, recurse. The hard part is the variable hygiene (avoid capture when the definition's vars match the formula's vars) — the LarKC-stripped `el-uniquify-formula-vars-wrt` function family handled this.
- **One-step vs. all is a flag, not a separate function family.** Drop the duplication: one `(verbosify formula &key mt recursion-depth justification)` entry point.
- **Destructive vs. non-destructive shouldn't exist.** Destructive variants existed because SubL conses were expensive to copy. Modern languages either always copy (clear) or share via persistent data structures. Pick one.
- **`*expansion-justification*` should be a return value, not a dynamic parameter.** A clean function returns `(values expanded-formula justification)` — no global state, no macro wrapper needed for justification gathering.
- **`*el-relation-recursion-limit*` = 212 is a magic number.** Either make it a real parameter to the verbosify call or detect cycles directly (track visited relations on the recursion stack). 212 is arbitrary.
- **The verbosifier should be lazy.** If a caller only paraphrases the first arg of a formula, only the first arg's EL-relations need expanding. A clean rewrite should expose a streaming or lazy expansion API.

### Tokenization

- **The dot DFA is a real algorithm.** Reimplement; it's a finite-state classifier with a small transition table. About 6 states, ~20 transitions.
- **Use a real lexer.** Modern languages have lexer generators (ANTLR, lalrpop, regex-based) that handle character classes, lookahead, and Unicode correctly. The Cyc-specific punctuation rules (the `*standard-*-chars*` lists) become the lexer's vocabulary.
- **Drop interval-token vs. string-token split.** Use one representation: a token with `(span, kind, text)`. Span is `(start, end)` indices; text is the substring. The interval-only optimisation matters when tokens outlive their source — rare; most tokens are consumed within the same call frame.
- **`dot-analysis` is the DFA state machine.** A clean rewrite shouldn't expose this; it's an implementation detail. The public API is `tokenize string` returns `[]token`.
- **Whitespace handling should be Unicode-aware.** `(whitespace-chars)` returns ASCII whitespace; modern text has U+00A0 (non-breaking space), U+2003 (em-space), etc. Use the host's Unicode classifier.
- **The chunker is a separate concern.** Tokenization → chunking is a pipeline. A clean rewrite should expose them as separate functions and let callers compose. The current "tokenize-sentence" interface mixed both.
