# Morphology

English-language morphology utilities — vowel/consonant classification, syllable counting, regular-suffix application (plural, past tense, gerund, third-singular, comparative, superlative), agentive→infinitive de-inflection, stemming, possessive-pronoun lookup, locative-preposition lookup, and part-of-speech probes (`nounp`, `verbp`, `adjectivep`, `adverbp`, `proper-nounp`). In real Cyc this is the core string-level NL morphology library that the natural-language paraphrase generator and parser call when they need to inflect a root or recover a root from an inflected form. The LarKC port retains **all the lexical tables** (vowel sets, sibilant endings, doublers, unstressed prefixes, special-case verbs, comparative-syllable cutoffs, the orthographic-change-fn dispatch table, the possessive-pronoun map, the supported part-of-speech keywords) but **every function body is missing-larkc**, and **no caller in `larkc-cycl/` references any morphology function**.

## What the engine does

The function names plus the data tables plus the Internal Constants in `morphology.java` together describe a complete English regular-morphology engine:

| KB constant referenced (Internal Constants) | Role |
|---|---|
| `comparativeDegree`, `superlativeDegree`, `comparativeAdverb`, `superlativeAdverb` | Predicates that name the morphological forms produced by `comparative-reg`, `superlative-reg`, etc. |
| `regularSuffix` | Generic regular-suffix predicate. |
| `pastTense-Universal`, `infinitive`, `gerund`, `thirdPersonSg-Present`, `plural`, `singular`, `presentParticiple` | Form predicates the generator selects on. |
| `EnglishLexiconMt`, `EnglishMt` | The mts the loader reads suffix rules and word entries from. |
| `GeographicalRegion`, `SurfaceRegion-Underspecified` | Used by `english-locative-preposition-for-denot` (a region's denot determines whether "in" or "at" is right). |
| `Number-SP` | The Spanish-counterpart number constant; used by tests and possibly the `numberspp` probe. |

So morphology supports both directions: **inflect** (`infinitive-to-pres-participle`, `past-tense-reg`, `pluralize-string`, `comparative-reg`, `most-form`, …) and **deflect** (`find-stem`, `inflected-verb-to-infinitive`, `agentive-to-infinitive`, `third-sg-verb-to-infinitive`, `plural-noun-to-sg`, `singular-reg`, `expand-contracted-root`). It also supports POS detection (`nounp`, `verbp`, etc.) by querying the lexicon for the string's existence as a member of a given POS class.

The `aes-` (add-english-suffix) machinery is the **orthographic-change pipeline**: when applying a suffix, the engine runs a sequence of orthographic-change functions (each tagged `:base` or `:suffix` or `:both`) that handle the spelling rules — `aes-change-y-to-i` ("happy" + "ness" → "happiness"), `aes-strip-final-e` ("write" + "ing" → "writing"), `aes-geminate-last` ("run" + "ing" → "running"), `aes-add-e-before-s` ("box" + "s" → "boxes"), etc. The list of change functions and their type tags is in `*aes-do-orthographic-change-fns*`, which is one of the few real, non-stub data structures in the file:

```
((aes-change-y-to-i             . :both)
 (aes-able-to-ate               . :base)
 (aes-geminate-last             . :base)
 (aes-ble-to-bil-before-ity     . :base)
 (aes-change-ceive-to-cept      . :base)
 (aes-change-aic-to-ac          . :base)
 (aes-strip-final-e             . :base)
 (aes-strip-final-vowels-before-ic . :base)
 (aes-change-ie-to-y            . :base)
 (aes-change-ism-to-ist         . :base)
 (aes-remove-able-le-before-ly  . :base)
 (aes-add-e-before-s            . :suffix))
```

Each named function is itself a stub (most are also `handleMissingMethodError #1288x` in the Java), but the orchestration table is preserved.

## Public API (morphology.lisp) — what survives

### Data tables (real, non-stub)

| Constant / lexical | Value | Use |
|---|---|---|
| `*vowels*` | `"aeiou"` | Set of vowel characters. |
| `*vowels*-plus-y*` | `"aeiouy"` | Sometimes y is treated as a vowel (e.g. `"happy"`). |
| `*bigraph-vowels*` | 16 two-letter sequences (`"ai" "au" "ay" "ea" …`) | Vowel pairs that occur within a single syllable. Used by syllable-count heuristics. |
| `*sibilant-endings*` | `("ss" "x" "sh" "ch" "z" "s")` | Endings that need `-es` for plural / 3rd-singular. |
| `*consonants*` | `"bcdfghjklmnprstvxz"` | Set of consonant characters. |
| `*doublers*` | `"bdfgklmnprtvz"` | Final consonants that are doubled before a vowel suffix in CVC monosyllables ("run" → "running"). |
| `*unstressed-latin-pfxs*` | `("re" "de" "dis" "mis" "un" "in" "ex")` | Prefixes whose syllable is unstressed; affects gemination decisions. |
| `*special-ate-cases*` | `("evaporate" "appreciate" "associate" …)` | Verbs that end in -ate but don't follow the normal -able→-ate rule. |
| `*liquids*` | `("l" "r")` | Liquids; used in coda-classification. |
| `*aes-do-orthographic-change-fns*` | (12-entry alist above) | Pipeline of orthographic-change functions. |
| `*comparative-syllable-cutoff*` | `2` | Words ≤ 2 syllables get `-er`/`-est`; longer words get `more`/`most`. |
| `*more-prefix*` / `*most-prefix*` | `"more "` / `"most "` | Comparative/superlative prefixes for polysyllabic words. |
| `*english-possessive-pronouns*` | 16-entry alist (`"I" → "my"`, `"he" → "his"`, …) | Hand-built; covers nominative and accusative forms in source. |
| `*pos-keywords*` | `(:noun :proper-noun :verb :adjective :adverb :preposition)` | Supported POS keyword set. |
| `*find-stem-memoized-caching-state*` | nil | Lexical for the `find-stem-memoized` cache. |
| `*preserve-case-in-singular-reg?*` | nil (defparameter) | Flag with author-comment "@hack, but I have no idea what the consequences of a larger fix might be... or why downcasing occurs at all. --TW". |

### Setup

```
(toplevel
  (note-globally-cached-function 'find-stem-memoized)
  (register-external-symbol 'plural-noun-to-sg))
```

`find-stem-memoized` is registered as globally cached (because stemming a word is deterministic and called repeatedly during paraphrase). `plural-noun-to-sg` is registered as an external symbol — i.e. it's expected to be called from the API (tying back to `nl-api-datastructures.lisp`, which lives next to morphology in the system-version manifest).

### Functions — every body is missing-larkc

Grouped by intent:

**Syllable / character classification**
- `vowel-char? char &optional include-y?`, `consonant-char? char`
- `get-vowel-positions string`, `get-consonant-positions string`
- `ends-with-vowel? string`, `starts-with-vowel? string`, `ends-with-consonant? string`, `starts-with-consonant? string`
- `single-c-coda? string`, `ends-with-doubler? string`, `starts-with-unstressed-pfx? string`
- `ends-in-cvc? string`, `ends-in-quvc? string` (CVC / Q-U-V-C ending checks for gemination)
- `ends-with-sibilant? string`
- `make-geminate string char`, `geminate-last string`
- `correct-capitalization new-string old-string`
- `estimated-syllable-count string`, `monosyllabic? string`, `polysyllabic? string &optional syllable-count`

**Suffix-rule pipeline**
- `regular-string-function form`, `suffix-rules-for-pred pred`
- `generate-regular-string-from-form string pred form &optional mt`
- `generate-regular-strings-from-form string pred form &optional suffix-rules mt fast?`
- `generate-regular-strings-from-form-int string pred form suffix-rules mt fast?`
- `add-english-suffix string suffix`
- `aes-do-orthographic-changes string suffix`, `aes-do-orthographic-change-fns`, `aes-do-orthographic-change string suffix change-fn type`
- All twelve `aes-*` orthographic-change implementations (with `handleMissingMethodError 12883`–`12896`).

**Adjective / adverb morphology**
- `try-regular-adj-morphology? string`
- `most-form string`, `more-form string`, `most-form-p string`, `more-form-p string`, `more-or-most-form-p string prefix`
- `comparative-reg string`, `comparative-adverb-reg string`, `superlative-reg string`, `superlative-adverb-reg string`

**Verb morphology**
- `past-tense-reg string`, `gerund-reg string`, `third-sg-reg string`
- `infinitive-to-third-sing string`, `infinitive-to-pres-participle string`
- `inflected-verb-to-infinitive string`, `agentive-to-infinitive string`, `third-sg-verb-to-infinitive string`

**Noun morphology**
- `plural-reg string`, `pn-plural-reg string`
- `pluralize-string string &optional mt`, `singularize-string string &optional mt`
- `plural-noun-to-sg string &optional mt`, `singular-reg string`, `plural-noun? string`

**Possessive / locative**
- `possessivize-string string &optional capitalize?`
- `english-lexical-possessive-version-of-string string`, `english-possessive-suffix-for-string string &optional capitalize?`
- `locativize-string string denot`, `not-locativizable-english-string? string`, `english-locative-preposition-for-denot denot`

**Lexicon probes**
- `is-word string`, `is-noun string`, `is-verb string`, `is-noun-or-verb string`
- `has-word-for-string-and-pos string pos`, `has-word-for-string-and-pos-list string pos-list`

**Stemming**
- `find-stem string &optional pos`
- `find-stem-memoized string &optional pos` / `find-stem-memoized-internal string pos` / `clear-find-stem-memoized` / `remove-find-stem-memoized`

**Form classification (POS detection by morphological shape)**
- `infinitive-verb? string`, `progressive-string? string`, `perfect-string? string`, `3sg-string? string`
- `comparative-degree? string`, `superlative-degree? string`
- `numberspp string` (number-as-Spanish-suffixed predicate)
- `pos-of-unknown-word string`
- `proper-nounp string`, `verbp string`, `nounp string`, `adjectivep string`, `adverbp string`
- `pos-keyword-p object`, `root-predicate pos`
- `get-root-of-head string &optional pos`, `get-root string &optional pos`, `expand-contracted-root string`

## Where this fits

**Zero callers in `larkc-cycl/`.** Grep finds only:

- `system-version.lisp` line 626 — the string `"morphology"` in the cycl-module manifest.

In the Java tree the only caller is `evaluation_defns.java`, which has `import com.cyc.cycjava.cycl.morphology;` — its bodies are themselves missing-larkc. The connection is real but unused in the port: `evaluation-defns.lisp` defines KB-side evaluatable predicates, and several morphology functions (`pluralize-string`, `singularize-string`, `find-stem`, `nounp`, `pos-of-unknown-word`) are registered as evaluatable so a CycL formula like `(plural "cat" ?P)` can be evaluated by calling into morphology.

The wider picture: morphology is consumed by **the natural-language generator and parser** — `nl-api-datastructures.lisp`, the (missing) NL paraphrase machinery, the (missing) lexification engine, and any KB subsystem that needs to coerce between root form and surface form. None of those consumers survive in working form in the LarKC port; morphology is a leaf in a subtree of stripped functionality.

## CFASL

No structs in this file, no opcode registrations. The file is pure functions plus data tables.

## Notes for a clean rewrite

- **Real engine functionality is missing-larkc here.** This is the single largest gap in the port's NL-morphology layer. A clean rewrite that targets full Cyc parity must reimplement every function. The Internal-Constants list and the data tables (vowel sets, sibilant endings, orthographic-change pipeline) provide a strong starting spec — the pipeline is well-known applied-linguistics material (English regular morphology with orthographic exception rules).
- **Use an existing morphology library if possible.** Modern NLP toolkits (CMU Pronouncing Dictionary, Hunspell, Lemma, NLTK, SpaCy lemmatizers, Stanford CoreNLP, …) cover this well and handle far more corner cases than 12 hand-rolled `aes-*` functions can. A clean rewrite should adopt a library, not re-derive Eric Pinker's 1990s rule list.
- **Preserve the `*aes-do-orthographic-change-fns*` ordering as a spec.** The 12-stage pipeline is the only place in the codebase that documents the order in which orthographic exceptions apply — this is genuinely useful for a from-scratch reimplementation if the rewrite chooses to keep its own engine.
- **The `*english-possessive-pronouns*` map is fine and tiny.** Keep it; no library does pronoun possessivization differently.
- **`*preserve-case-in-singular-reg?*`'s author-comment is a code smell.** "I have no idea what the consequences of a larger fix might be... or why downcasing occurs at all" — the rewrite should not preserve this hack. Lemma comparison should be case-insensitive at the algorithm level; surface case should be reapplied at output, not gated by a parameter.
- **The `find-stem` memoization is well-motivated.** Stemming the same word repeatedly is a common pattern (paraphrase regenerates strings during query result formatting). Preserve memoization in any reimplementation.
- **`pos-keyword-p` and `*pos-keywords*` should be a CL `member` lookup or a `defenum`.** The dispatch is small enough that a hash-table is overkill.
- **Drop `numberspp`** unless the rewrite supports the Spanish-number-suffix feature — the function is named for an old, almost-certainly stripped, Spanish handling.
- **Drop `correct-capitalization`** and replace it with a host-language `capitalize` that respects the existing word's case pattern. Modern Unicode-aware libraries do this correctly.
- **Drop the `is-word` / `is-noun` / `is-verb` / `nounp` / `verbp` / `adjectivep` / `adverbp` family in favor of a single `(has-pos? string pos)` API.** The five-way split is SubL-era code-bloat.
