# Clyc: A port of Cyc to Common Lisp

## Project Intent

The primary purpose of Clyc is to explore the internals of Cyc, a uniquely mature and scalable commercial inference engine, from its only known open source release. Cycorp donated source code portions of a [circa 2009 Java version of Cyc](https://sourceforge.net/p/larkc/code/HEAD/tree/trunk/platform/src/main/java/com/cyc/cycjava/cycl/) to the Large Knowledge Collider project ("LarKC", [larkc.eu](https://web.archive.org/web/20141217165050/http://larkc.org/) archived), released under the permissive Apache License 2.0.  Random documentation publicly found on cyc.com (live or through archive.org) is also consulted.

This native Common Lisp version will be refactored, documented, and modernized yielding a much smaller and easier to modify system. It should also run inferences faster than the layered and semi-interpreted Java version, which emulates a Lisp-like environment (SubL).

100% compatibility with Cyc is not sought, and this will not be a drop-in replacement for any of Cycorp's offerings, but rather a reimplementation of open source raw inference tools. The Cyc "common sense" knowledge base is also not open source, nor available to or through this project, beyond the minimal ["cyc-tiny"](https://sourceforge.net/p/larkc/code/HEAD/tree/trunk/platform/src/main/resources/cyc-tiny/) subset included in LarKC. However, OpenCyc's larger KB subset is also Apache licensed and will be integrated into Clyc at some point.

"Clyc" is pronounced `klaɪk`, as if "clock" rhymed with "like".

## License

Clyc is licensed under the GNU Affero General Public License v3. Some files derive from LarKC's Apache v2 licensed files, with the modifications licensed under the AGPL v3.

The AGPL is the most forced-open major license of which we're aware. If there was a standardized "no commercial use allowed" open source software license[*], we would use it here to respect Cycorp's commercial interests. The Clyc developers have no affiliation with Cycorp, its employees, or its customers.

[*]: Creative Commons is [not recommended](https://creativecommons.org/faq/#can-i-apply-a-creative-commons-license-to-software) for software, and does not mandate making source code available.

## Current Status
All of the files have been converted to Lisp. The project loads without errors and with many warnings, but has not been tested much.

Many of the macro sites remain expanded as they were in Java, and need to be reconstructed back to their macro call forms. References to dynamic variable bindings can usually roughly indicate which macro is in use, and many of the defmacros have already been reconstructed.

The original LarKC distribution has most of its Cyc source code in a flat directory, which is reflected here in `larkc-cycl` (named after the `com/cyc/cycjava/cycl/` originating directory). This will be reorganized after things are up & running.

The `cyc-testing` directory contains test harness & registration, but no actual test function bodies.

### AI Slop

AI assistance has gotten this project past the automation complexity humps, and all AI ported files are meticulously (at least the earlier ones) human-reviewed. AI is commonly munging some Cyc-originated comments, which will be mechanically fixed later, but also commenting ideas for some of the redacted function calls, and successfully reconstructing `defmacro`s from leftover internal constant literals and corresponding expanded instances. While it's catching some macroexpansions and reverting them back to their original forms, I'm leaving most of the missed ones to be scanned individually after everything has had its initial port. It simply can't keep all of them "in mind" as it ports each file, and the more visible Lisp examples the better.

## Rough Plan

1. Convert code as-is to loadable, hopefully runnable Common Lisp
  - leave as-is dependency ordering problems, repetitive complexity, orphaned vars/funs, etc
  - implement basic stdlib file, thread, networking, etc functions from SubL and/or Java layers
  - sparingly prune code that references missing-larkc features to untangle some problematic dependencies and references
  - hopefully get cyc-tiny .cfasl files loading and assertions & queries working at this stage, even if manual intervention is required
2. Resolve load order dependencies
  - finish & use cross-referencing tools
  - hoist necessary declarations and move some functions around
  - organize into subdirectories
  - maybe eliminate degenerately small functions to make source code more orthogonally readable
  - hopefully load & operate without any warnings at this stage
3. Refactor
  - utilize lambdas and closures instead of toplevel `-INT` DEFUNs, symbolic function names, and dynamic bindings
  - reevaluate what macros should be written and where they're needed
  - separate intended-public APIs from internal functions based on the Java declarations
  - apply deprecations, eliminate redundancies, and pare down protocols
  - create more technical documentation
4. Profile and optimize particularly egregious sections
  - major refactoring of algorithms and infrastructure is allowable
  - eliminate some source-heavy optimizations that might not be necessary on modern hardware
5. Add new code, including based on commented-out function/macro names

## Requirements

Clyc currently loads only on SBCL, as a small number of its extensions and low-level implementation details are used. In the future these dependencies could be refactored out as the codebase matures past the specifics of the initial direct port, or else portability shims for other Common Lisp implementations will be added.

Compilation warnings can be made visible by evaluating the following before quickloading:

```
(setf quicklisp-client:*quickload-verbose* t)
```

[The modern Common Lisp + Quicklisp modus operandi is to add a symlink in `~/quicklisp/local-projects/` to projects like Clyc, and run `(ql:quickload "clyc")` from the REPL to load a project.]

## General Mechanism Notes

`Disk persistence` - KB CFASL files can be read, but writing is missing-larkc. A `cyc-tiny` bootstrap KB is included in LarKC, but that will never expand on-disk. Everything ends up RAM-resident only.  
`Transcripts` - no actual output or evaluation code, just skeleton.  
`cyc-testing/` - Test harness & registration, but no actual test function bodies.  
`Hash functions` - CFASL doesn't store hash values, so we can defer to SBCL `sxhash` and still load abitrary saved KBs.  
`Worlds` - There doesn't seem to be any notion of a single-file world export, just a directory of fine-grained cfasl files.  
`SKSI` - Not included, a very minimal set of hooks remains.  
`CFASL compression` - Not included. Definitions for compression tags remain.  
`Janus` - Not included. A framework for recording & playing back inference for testing?  

## Data Structures

*These are listed by their* `.java`/`.lisp` *filenames.*

`tries` - Character-based trie used to intern and prefix-complete Constant names from strings.  
`id-index` - Key/value storage with incrementally allocated integer keys.  Backed by a vector, which can be grown, with a hashtable storing entries whose keys are out of range.  
`set` - Wrapped set-contents for some reason, maybe for its cfasl interface? Replaced with a key->key hashtable implementation.  
`cache` - A hashtable with LRU discarding to keep a fixed size. (LRU discarding might be missing-larkc)  
`queue` - A FIFO queue (cons-backed), and a priority FIFO queue (b-tree backed).  
`binary-tree` - A standard binary tree, and an AVL tree which is missing-larkc.  
`stacks` - A LIFO stack which also maintains a count of elements.  
`deck` - A push/pop interface manually dispatched to either a queue or stack.  
`fvector` - file-vector, an indexed on-disk array of arbitrary-length elements. However, writing seems to be missing-larkc.  
`kb-object-manager` - In-memory cache for a fixed percentage of a `fvector`. Forms the basis of most high-level storage.  

### Deprecated

`dictionary` - Key/value storage backed by an a-list when small, and a hashtable when large. Elided in preference to standard hashtables.  
`keyhash` - A set, stored in a manually-implemented hash table so as not to store a value. Elided in preference to standard hashtables.  
`set-contents` - A set, stored in a list when small, keyhash when large.  Converted to use only a hashtable backend, though should be deprecated in favor of `set`.  
`fraction-utilities` - Elided, since CL already natively supports rational numbers.  

### Files Exist But the Implementation is missing-larkc

`bijection` - A key/value mapping that also supports reversed value→key lookups.  A-list for small maps, pair of hashtables for large maps.  No given implementation, but can be easily recreated.  
`shelfs` - Some data container that supports "finalize", "rearrange", "bsearch", etc.  
`glob` - Some dual-indexed data container.  
`bag` - A multi-set. Possible to recreate.  
`accumulation` - A data accumulation interface that can append its values to various different concrete datastructures.  Probably reconstructable.  
`red-*` - Some form of generic on-disk data repository, maybe similar to the Windows registry?  
`file-hash-table` - On-disk key/value store. Huge function list.  
`sparse-matrix` `sparse-vector` `heap` - Self explanatory.  

## Utilities

`structure resourcing` - Object pooling for reusing structure instances. Generally missing-larkc, but took a while to figure out what the term meant.  
`cfasl` - Serialization & deserialization tools.  
`memoization-state.lisp` - Memoizes function calls.  
`special-variable-state.lisp` - Snapshots a list of CL special variables.  
`misc-utilities.lisp` - Startup code.  


## Glossary

**Cyc:**  
`Term` = a constant, NAT, variable, others.  
`Constant` = atomic vocabulary word, in a flat global namespace.  Prefixed with `#$`.  
`Predicate` = relationship between constants, itself named via constant starting with a lowercase letter.  
`Sentence` = cyc s-expression, including logical connectives and predicates.  
`Assertion` = KB storage item comprising a sentence, microtheory, truth value, direction, support.  
`Logical Connective` = `#$and`, `#$or`, `#$not`, `#$implies`, etc.  
`Rule` or `Conditional` = an `#$implies` sentence.  
`Microtheory` = a partition of a KB that can be independently scoped in & out of inferential visibility.  
`Arity` = the number of terms in a predicate not including the first (the operator).  
`Sequence` = a cons list.  
`Sequence term` = a term holding the remainder of a sequence, as in a dotted list. Also `sequence variable` if the term is a variable.  
`Shell` = an empty structure for KB content, lazily filled and LRU cached from CFASLs.  
`Def` = a filled structure with KB content, referenced by a shell.  
`Cyc API` = a subset of SubL which is intended to be the public API. It is not a separate language. The actual validation of the Cyc API subset is missing-larkc, but all the API declarations are present.  

**Inference:**
`Removal` = directly answer a query literal with bindings, removing that literal from the query.  
`Transformation` = substitute a query literal with an antecedent expansion or alternative, to explore finding other query strategies.  
`Productivity` = an estimate for the number of results an inference module will produce.  

**Clyc:**  
`missing-larkc` = specific term for things in Cyc that were not provided to the LarKC project, distinguished from unimplemented or unfinished things in Clyc.  

## Acronyms & Abbreviations

`MT` = MicroTheory.  
`PSC` = Problem Solving Context, related to which microtheories are in view.  
`GAF` = Ground Atomic Formula, a sentence that contains no variables or logical connectives.  
`NAT` = Non-Atomic Term, a parameterized function representing a term. `(#$FruitFn #$AppleTree)` is the collection of fruit from apple trees, as opposed to the atomic term `#$Apples` or something.  
`NAUT` = Non-Atomic Unreified Term. A function NAT, before reification, having only the Fn and args.  
`NART` = Non-Atomic Reified Term. Internal identifier that a NAUT resolved to.  
`TOU` = Term Of Unit, predicate that maps a NART to a NAUT.  
`FORT` = First-Order Reified Term, which is a constant or a NART.  
`WFF` = Well-Formed Formula.  Arity, argument types, connectives, MT it's in, semantics are all checked, valid, and coherent.  
`EL` = Epistemological Level, expressive human-editable form.  
`HL` = Heuristic Level, efficient low-level form.  
`TL` = Transcript Level, a serializable transform of HL for transcripts.  
`SBHL` = Subsumption Based HL, meta predicates like `#$isa`, `#$genls`, `#$genlAttributes`.  
`FOL` = First-Order Logic, the full sentence style of EL.  
`CNF` = Conjunctive Normal Form, the style of HL. `(#$and (#$or ?term+)+)`, where terms may also be negated.  
`GUID` = Globally Unique ID, external identifier.  
`SUID` = (System?) Unique ID, internal identifier.  
`TV` = Truth value. Default or monotonically true or false, unknown truth, etc.  
`CZER` = Canonicalizer.  
`AT` = the `arg-type` mechanisms.  
`GT` = General Transitivity, the transitive predicate reasoning dispatch layer.  
`GHL` = Graph Hierarchy Link, the abstract general graph search infrastructure underlying GT.  
`ASENT` = Atomic Sentence, a sentence that contains no variables or logical connectives.  
`KE` = Knowledge Editor, high-level API for KB modifications.  
`FI` = Functional Interface, older interface for KB operations, superseded by KE and Cyc API.  

