#|
  Copyright (c) 2019-2026 White Flame

  This file is part of Clyc

  Clyc is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  Clyc is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Affero General Public License for more details.

  You should have received a copy of the GNU Affero General Public License
  along with Clyc.  If not, see <https://www.gnu.org/licenses/>.

This file derives from work covered by the following copyright
and permission notice:

  Copyright (c) 1995-2009 Cycorp Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
|#

(in-package :clyc)

;;; Variables

(defparameter *concept-filter-default-mt* #$InferencePSC
  "[Cyc] If no mt is specified, what Mt should be used for semantic tests for a concept-filter")
(defparameter *default-concept-filter* #$TaxonomyOfEasilyUnderstandableConcepts)
(defparameter *default-concept-filter-specification* nil)
(defparameter *concept-filter-memoization-state* nil)

;;; Macros (reconstructed from Internal Constants evidence)

;; $sym2$CLET, $list3 = ((*CONCEPT-FILTER-MEMOIZATION-STATE* (NEW-MEMOIZATION-STATE))),
;; $sym4$WITH_MEMOIZATION_STATE, $list5 = (*CONCEPT-FILTER-MEMOIZATION-STATE*)
;; These two macros set up a memoization context for concept-filter operations.

(defmacro with-new-concept-filter-memoization-state (&body body)
  "[Cyc] Execute BODY with a fresh concept-filter memoization state."
  `(clet ((*concept-filter-memoization-state* (new-memoization-state)))
     (with-memoization-state (*concept-filter-memoization-state*)
       ,@body)))

(defmacro with-concept-filter-memoization-state (&body body)
  "[Cyc] Execute BODY with the current concept-filter memoization state."
  `(with-memoization-state (*concept-filter-memoization-state*)
     ,@body))

;;; Function stubs — all declareFunction entries are commented out in Java

;; (defun clear-concept-filter-caches () ...) -- present in original Cyc, not in LarKC
;; (defun clear-concept-filter-specification-p () ...) -- present in original Cyc, not in LarKC
;; (defun remove-concept-filter-specification-p (object) ...) -- present in original Cyc, not in LarKC

;; concept-filter-specification-p is a globally-cached function (defun-cached pattern).
;; The body (concept-filter-specification-p-internal) is stripped, so the entire group is stubs:
;;   *concept-filter-specification-p-caching-state* -- deflexical, caching state variable
;;   clear-concept-filter-specification-p (0 0) -- clears the caching state
;;   remove-concept-filter-specification-p (1 0) -- removes a single entry
;;   concept-filter-specification-p-internal (1 0) -- the actual computation (stripped)
;;   concept-filter-specification-p (1 0) -- the cached wrapper
;; All have commented declareFunction, no body.
;; Orphan constants: $const7$ConceptFilterSpecificationFn, $const8$isa, $list9 (#$ConceptFilterSpecification),
;;   $sym10$, $int11$50, $kw12$, $list13 (#$ConceptOnlyFilterParameter #$TriggerFromConcept)

;; (defun concept-filter-specification-p-internal (object) ...) -- present in original Cyc, not in LarKC
;; (defun concept-filter-specification-p (object) ...) -- present in original Cyc, not in LarKC

;; (defun get-default-concept-filter-specification () ...) -- present in original Cyc, not in LarKC
;; (defun nodes-for-concept-filter-after-adding (argument assertion) ...) -- present in original Cyc, not in LarKC
;; (defun nodes-for-concept-filter-after-removing (argument assertion) ...) -- present in original Cyc, not in LarKC

;; concept-filter-all-isa is a globally-cached function (defun-cached pattern).
;; The body (concept-filter-all-isa-internal) is stripped, so the entire group is stubs:
;;   *concept-filter-all-isa-caching-state* -- deflexical, caching state variable
;;   clear-concept-filter-all-isa (0 0) -- clears the caching state; also has ZeroArityFunction (missing-larkc 5465)
;;   remove-concept-filter-all-isa (2 0) -- removes a single entry
;;   concept-filter-all-isa-internal (2 0) -- the actual computation (stripped)
;;   concept-filter-all-isa (2 0) -- the cached wrapper
;; All have commented declareFunction, no body.
;; Orphan constants: $sym17$NART_SUBSTITUTE, $sym18$_VAR0, $list19, $sym20$, $int21$500, $sym22$

;; (defun clear-concept-filter-all-isa () ...) -- present in original Cyc, not in LarKC
;; (defun remove-concept-filter-all-isa (term mt) ...) -- present in original Cyc, not in LarKC
;; (defun concept-filter-all-isa-internal (term mt) ...) -- present in original Cyc, not in LarKC
;; (defun concept-filter-all-isa (term mt) ...) -- present in original Cyc, not in LarKC

;; specified-nodes-in-filter is a globally-cached function (defun-cached pattern).
;; The body (specified-nodes-in-filter-internal) is stripped, so the entire group is stubs:
;;   *specified-nodes-in-filter-caching-state* -- deflexical, caching state variable
;;   clear-specified-nodes-in-filter (0 0) -- clears the caching state
;;   remove-specified-nodes-in-filter (2 0) -- removes a single entry
;;   specified-nodes-in-filter-internal (2 0) -- the actual computation (stripped)
;;   specified-nodes-in-filter (2 0) -- the cached wrapper
;; All have commented declareFunction, no body.
;; Orphan constants: $sym24$_X, $const25$nodeInSystem, $list26, $str27$, $kw28$GAF, $kw29$TRUE,
;;   $kw30$BREADTH, $kw31$QUEUE, $kw32$STACK, $sym33$, $kw34$ERROR, $str35$, $sym36$,
;;   $kw37$CERROR, $str38$, $kw39$WARN, $str40$, $const41$genls, $str42$, $str43$, $sym44$,
;;   $const45$TheSetOf

;; (defun clear-specified-nodes-in-filter () ...) -- present in original Cyc, not in LarKC
;; (defun remove-specified-nodes-in-filter (concept-filter mt) ...) -- present in original Cyc, not in LarKC
;; (defun specified-nodes-in-filter-internal (concept-filter mt) ...) -- present in original Cyc, not in LarKC
;; (defun specified-nodes-in-filter (concept-filter mt) ...) -- present in original Cyc, not in LarKC
;; (defun specified-nodes-in-filter-cached-p (concept-filter mt) ...) -- present in original Cyc, not in LarKC
;; (defun specified-node-in-filter? (node &optional concept-filter mt) ...) -- present in original Cyc, not in LarKC
;; (defun query-for-individual-terms-from-filter? (concept-filter) ...) -- present in original Cyc, not in LarKC
;; (defun node-suppressed-from-filter? (node concept-filter mt) ...) -- present in original Cyc, not in LarKC

;; nodes-suppressed-from-filter is a globally-cached function (defun-cached pattern).
;; The body (nodes-suppressed-from-filter-internal) is stripped, so the entire group is stubs:
;;   *nodes-suppressed-from-filter-caching-state* -- deflexical, caching state variable
;;   clear-nodes-suppressed-from-filter (0 0) -- clears the caching state; also has ZeroArityFunction (missing-larkc 5466)
;;   remove-nodes-suppressed-from-filter (2 0) -- removes a single entry
;;   nodes-suppressed-from-filter-internal (2 0) -- the actual computation (stripped)
;;   nodes-suppressed-from-filter (2 0) -- the cached wrapper
;; All have commented declareFunction, no body.
;; Orphan constants: $sym47$_NODE, $const48$suppressIndividualNode, $list49, $sym50$, $sym51$

;; (defun clear-nodes-suppressed-from-filter () ...) -- present in original Cyc, not in LarKC
;; (defun remove-nodes-suppressed-from-filter (concept-filter mt) ...) -- present in original Cyc, not in LarKC
;; (defun nodes-suppressed-from-filter-internal (concept-filter mt) ...) -- present in original Cyc, not in LarKC
;; (defun nodes-suppressed-from-filter (concept-filter mt) ...) -- present in original Cyc, not in LarKC

;; organizing-nodes-for-filter is a globally-cached function (defun-cached pattern).
;; The body (organizing-nodes-for-filter-internal) is stripped, so the entire group is stubs:
;;   *organizing-nodes-for-filter-caching-state* -- deflexical, caching state variable
;;   clear-organizing-nodes-for-filter (0 0) -- clears the caching state
;;   remove-organizing-nodes-for-filter (2 0) -- removes a single entry
;;   organizing-nodes-for-filter-internal (2 0) -- the actual computation (stripped)
;;   organizing-nodes-for-filter (2 0) -- the cached wrapper
;; All have commented declareFunction, no body.
;; Orphan constants: $const53$classifyingNodeInFilter, $sym54$

;; (defun clear-organizing-nodes-for-filter () ...) -- present in original Cyc, not in LarKC
;; (defun remove-organizing-nodes-for-filter (concept-filter mt) ...) -- present in original Cyc, not in LarKC
;; (defun organizing-nodes-for-filter-internal (concept-filter mt) ...) -- present in original Cyc, not in LarKC
;; (defun organizing-nodes-for-filter (concept-filter mt) ...) -- present in original Cyc, not in LarKC

;; (defun complete-extent-should-be-queried-from-kb? (concept-filter) ...) -- present in original Cyc, not in LarKC
;; Orphan constant: $const55$DecisionTreeConceptFilter

;; (defun decision-tree-filter? (concept-filter) ...) -- present in original Cyc, not in LarKC

;; filter-defn is a globally-cached function (defun-cached pattern).
;; The body (filter-defn-internal) is stripped, so the entire group is stubs:
;;   *filter-defn-caching-state* -- deflexical, caching state variable
;;   clear-filter-defn (0 0) -- clears the caching state
;;   remove-filter-defn (2 0) -- removes a single entry
;;   filter-defn-internal (2 0) -- the actual computation (stripped)
;;   filter-defn (2 0) -- the cached wrapper
;; All have commented declareFunction, no body.
;; Orphan constants: $sym57$BAD_FOR_TAGGING_DEFN, $const58$PredicateTaxonomy,
;;   $sym59$PREDICATE_FILTER_TAGGING_DEFN, $const60$TheCycOntology, $sym61$IGNORE,
;;   $sym62$TERM_FAILS_CLASSIFICATION_TREE_FILTER_, $sym63$

;; (defun clear-filter-defn () ...) -- present in original Cyc, not in LarKC
;; (defun remove-filter-defn (concept-filter defn-type) ...) -- present in original Cyc, not in LarKC
;; (defun filter-defn-internal (concept-filter defn-type) ...) -- present in original Cyc, not in LarKC
;; (defun filter-defn (concept-filter defn-type) ...) -- present in original Cyc, not in LarKC

;; (defun concept-tagging-irrelevant-term? (term) ...) -- present in original Cyc, not in LarKC
;; (defun predicate-filter-tagging-defn (term concept-filter &optional mt) ...) -- present in original Cyc, not in LarKC
;; (defun bad-for-tagging-defn (term concept-filter &optional mt) ...) -- present in original Cyc, not in LarKC

;; bad-for-tagging? is a globally-cached function (defun-cached pattern).
;; The body (bad-for-tagging?-internal) is stripped, so the entire group is stubs:
;;   *bad-for-tagging?-caching-state* -- deflexical, caching state variable
;;   clear-bad-for-tagging? (0 0) -- clears the caching state
;;   remove-bad-for-tagging? (1 1) -- removes a single entry
;;   bad-for-tagging?-internal (2 0) -- the actual computation (stripped)
;;   bad-for-tagging? (1 1) -- the cached wrapper
;; All have commented declareFunction, no body.
;; Orphan constants: $list66 (#$InstanceNamedFn #$InstanceNamedFn-Ternary #$ThingDescribableAsFn #$Kappa),
;;   $sym67$, $str68$

;; (defun clear-bad-for-tagging? () ...) -- present in original Cyc, not in LarKC
;; (defun remove-bad-for-tagging? (term &optional concept-filter) ...) -- present in original Cyc, not in LarKC
;; (defun bad-for-tagging?-internal (term concept-filter) ...) -- present in original Cyc, not in LarKC
;; (defun bad-for-tagging? (term &optional concept-filter) ...) -- present in original Cyc, not in LarKC

;; (defun organizing-node-for-filter? (node &optional concept-filter mt) ...) -- present in original Cyc, not in LarKC

;; valid-concept-filter-nodes-memoized is a state-dependent memoized function (defun-memoized pattern).
;; The body (valid-concept-filter-nodes-memoized-internal) is stripped, so the entire group is stubs:
;;   valid-concept-filter-nodes-memoized-internal (2 0) -- the actual computation (stripped)
;;   valid-concept-filter-nodes-memoized (2 0) -- the memoized wrapper
;; All have commented declareFunction, no body.
;; Orphan constants: $list70 = (CONCEPT-FILTER ALLOW-SPECS ALLOW-INSTANCES RETURN-INSTANCES MT)
;;   -- likely a destructuring pattern for the concept-filter-spec decomposition

;; (defun valid-concept-filter-nodes (concept-filter &optional mt) ...) -- present in original Cyc, not in LarKC
;; (defun valid-concept-filter-nodes-memoized-internal (concept-filter mt) ...) -- present in original Cyc, not in LarKC
;; (defun valid-concept-filter-nodes-memoized (concept-filter mt) ...) -- present in original Cyc, not in LarKC

;; decompose-concept-filter-spec is a globally-cached function (defun-cached pattern).
;; The body (decompose-concept-filter-spec-internal) is stripped, so the entire group is stubs:
;;   *decompose-concept-filter-spec-caching-state* -- deflexical, caching state variable
;;   clear-decompose-concept-filter-spec (0 0) -- clears the caching state
;;   remove-decompose-concept-filter-spec (1 1) -- removes a single entry
;;   decompose-concept-filter-spec-internal (2 0) -- the actual computation (stripped)
;;   decompose-concept-filter-spec (1 1) -- the cached wrapper
;; All have commented declareFunction, no body.
;; Orphan constants: $const72$conceptFilterSpecificationFilter, $sym73$,
;;   $sym74$_MT, $const75$conceptFilterSpecificationDefiningMt, $list76, $kw77$PROBLEM_STORE,
;;   $sym78$_TRIGGER, $const79$conceptFilterSpecificationTrigger, $list80, $list81, $list82,
;;   $sym83$_MODE, $const84$conceptFilterSpecificationMode, $list85,
;;   $const86$ConceptAndInstancesFilterParameter, $list87, $list88,
;;   $const89$specificationForConceptFilter, $sym90$_FILTER, $list91, $list92

;; (defun clear-decompose-concept-filter-spec () ...) -- present in original Cyc, not in LarKC
;; (defun remove-decompose-concept-filter-spec (concept-filter-spec &optional mt) ...) -- present in original Cyc, not in LarKC
;; (defun decompose-concept-filter-spec-internal (concept-filter-spec mt) ...) -- present in original Cyc, not in LarKC
;; (defun decompose-concept-filter-spec (concept-filter-spec &optional mt) ...) -- present in original Cyc, not in LarKC
;; (defun decompose-concept-filter-spec-new (concept-filter-spec mt) ...) -- present in original Cyc, not in LarKC
;; (defun decompose-concept-filter-spec-old (concept-filter-spec mt) ...) -- present in original Cyc, not in LarKC
;; (defun concept-filter-specification-filter (concept-filter-spec &optional mt) ...) -- present in original Cyc, not in LarKC

;; (defun new-adhoc-concept-filter-spec (collection &optional mt) ...) -- present in original Cyc, not in LarKC
;; Orphan constants: $sym94$CYCL_TERM_P, $sym95$HLMT_P, $const96$ConceptFilterSpecificationWithMtFn,
;;   $list97 = (#$ConceptOnlyFilterParameter #$TriggerFromConcept MT)

;; (defun new-adhoc-isa-concept-filter-spec (collection &optional mt) ...) -- present in original Cyc, not in LarKC
;; Orphan constants: $sym99$ISA_COLLECTION_, $sym100$_TERM, $const101$ConceptOnlyFilterParameter,
;;   $const102$TriggerFromConcept, $const103$ConceptFilterSpecificatioFn

;; (defun new-adhoc-genls-concept-filter-spec (collection &optional mt) ...) -- present in original Cyc, not in LarKC

;;; Setup phase

(note-globally-cached-function 'concept-filter-specification-p)
(register-kb-function 'nodes-for-concept-filter-after-adding)
(register-kb-function 'nodes-for-concept-filter-after-removing)
(note-globally-cached-function 'concept-filter-all-isa)
(note-globally-cached-function 'specified-nodes-in-filter)
(note-globally-cached-function 'nodes-suppressed-from-filter)
(note-globally-cached-function 'organizing-nodes-for-filter)
(note-globally-cached-function 'filter-defn)
(register-kb-function 'concept-tagging-irrelevant-term?)
(note-globally-cached-function 'bad-for-tagging?)
(note-memoized-function 'valid-concept-filter-nodes-memoized)
(note-globally-cached-function 'decompose-concept-filter-spec)
(register-external-symbol 'new-adhoc-concept-filter-spec)
(register-external-symbol 'new-adhoc-isa-concept-filter-spec)
(register-external-symbol 'new-adhoc-genls-concept-filter-spec)
