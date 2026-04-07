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

(defglobal *sbhl-caches-initialized?* nil
  "[Cyc] Flag for whether the SBHL caches have been initialized")

(defglobal *cached-genl-predicates*
  (list (reader-make-constant-shell "conceptuallyRelated"))
  "[Cyc] The predicates that have their spec-preds and spec-inverses cached")

(defglobal *cached-genl-predicates-set*
  (construct-set-from-list *cached-genl-predicates* #'eq)
  "[Cyc] The predicates that have their spec-preds and spec-inverses cached")

(defglobal *genl-predicate-cache* nil
  "[Cyc] The dictionary of dictionaries of genl-predicate relations")

(defglobal *genl-inverse-cache* nil
  "[Cyc] The dictionary of dictionaries of genl-inverse relations")

(defglobal *all-mts-genl-predicate-cache* nil
  "[Cyc] The dictionary of dictionaries of genl-predicate relations with all mts relevance")

(defglobal *all-mts-genl-inverse-cache* nil
  "[Cyc] The dictionary of dictionaries of genl-inverse relations with all mts relevance")

(defglobal *cached-genls*
  (list (reader-make-constant-shell "CycLExpression")
        (reader-make-constant-shell "CycLFormula")
        (reader-make-constant-shell "CycLIndexedTerm")
        (reader-make-constant-shell "CycLReifiableDenotationalTerm")
        (reader-make-constant-shell "CycLSentence")
        (reader-make-constant-shell "CycLSentence-Askable")
        (reader-make-constant-shell "CycLSentence-Assertible")
        (reader-make-constant-shell "GenericArgTemplate")
        (reader-make-constant-shell "KeywordVariableTemplate")
        (reader-make-constant-shell "Microtheory")
        (reader-make-constant-shell "SubLList"))
  "[Cyc] The collections that have their specs cached.")

(defglobal *cached-genls-set*
  (construct-set-from-list *cached-genls* #'eq)
  "[Cyc] The collections that have their specs cached.")

(defglobal *genls-cache* nil
  "[Cyc] The dictionary of dictionaries of genls relations")

(defglobal *all-mts-genls-cache* nil
  "[Cyc] The dictionary of dictionaries of genls relations")

(defconstant *definitional-fort-typing-collections*
  (list (reader-make-constant-shell "Collection")
        (reader-make-constant-shell "Predicate")
        (reader-make-constant-shell "Function-Denotational")
        (reader-make-constant-shell "Microtheory"))
  "[Cyc] The collections used for fort type definitional typing.")

(defglobal *additional-fort-typing-collections*
  (list (reader-make-constant-shell "AntiSymmetricBinaryPredicate")
        (reader-make-constant-shell "AntiTransitiveBinaryPredicate")
        (reader-make-constant-shell "ArgTypeBinaryPredicate")
        (reader-make-constant-shell "ArgTypeTernaryPredicate")
        (reader-make-constant-shell "AsymmetricBinaryPredicate")
        (reader-make-constant-shell "BookkeepingPredicate")
        (reader-make-constant-shell "BroadMicrotheory")
        (reader-make-constant-shell "CommutativeRelation")
        (reader-make-constant-shell "DistributingMetaKnowledgePredicate")
        (reader-make-constant-shell "DocumentationPredicate")
        (reader-make-constant-shell "ELRelation")
        (reader-make-constant-shell "EvaluatableFunction")
        (reader-make-constant-shell "EvaluatablePredicate")
        (reader-make-constant-shell "ExistentialQuantifier")
        (reader-make-constant-shell "ExistentialQuantifier-Bounded")
        (reader-make-constant-shell "IrreflexiveBinaryPredicate")
        (reader-make-constant-shell "LogicalConnective")
        (reader-make-constant-shell "MicrotheoryDesignatingRelation")
        (reader-make-constant-shell "NLDefinitenessAttribute")
        (reader-make-constant-shell "NLQuantAttribute")
        (reader-make-constant-shell "PartiallyCommutativeRelation")
        (reader-make-constant-shell "ProblemSolvingCntxt")
        (reader-make-constant-shell "Quantifier")
        (reader-make-constant-shell "ReflexiveBinaryPredicate")
        (reader-make-constant-shell "ReifiableFunction")
        (reader-make-constant-shell "RuleMacroPredicate")
        (reader-make-constant-shell "SKSIContentMicrotheory")
        (reader-make-constant-shell "SKSIExternalTermDenotingFunction")
        (reader-make-constant-shell "SKSISupportedComparisonPredicate")
        (reader-make-constant-shell "SKSISupportedFunction")
        (reader-make-constant-shell "SKSISupportedConstant")
        (reader-make-constant-shell "CSQLComparisonPredicate")
        (reader-make-constant-shell "CSQLFunction")
        (reader-make-constant-shell "CSQLConstantFunction")
        (reader-make-constant-shell "CSQLLogicalConnective")
        (reader-make-constant-shell "CSQLQuantifier")
        (reader-make-constant-shell "ScopingRelation")
        (reader-make-constant-shell "SiblingDisjointCollectionType")
        (reader-make-constant-shell "SkolemFunction")
        (reader-make-constant-shell "SpeechPart")
        (reader-make-constant-shell "SymmetricBinaryPredicate")
        (reader-make-constant-shell "TransitiveBinaryPredicate")
        (reader-make-constant-shell "TruthFunction")
        (reader-make-constant-shell "VariableArityRelation"))
  "[Cyc] The additional fort type collections. Those which are not intended to be defining, disjoint types of forts")

(defglobal *implicit-fort-typing-collections*
  (list (reader-make-constant-shell "Relation"))
  "[Cyc] Implicit fort typing collections which are not stored explicitly but can be deduced by the union of other fort types.")

(defglobal *cached-isas*
  (append *definitional-fort-typing-collections*
          *additional-fort-typing-collections*
          *implicit-fort-typing-collections*))

(defglobal *cached-isas-set*
  (construct-set-from-list *cached-isas* #'eq)
  "[Cyc] All of the collections whose instances (via #$isa) are cached")

(defglobal *isa-cache* nil
  "[Cyc] The dictionary of dictionaries of mts of types of forts")

(defglobal *implicit-fort-type-mapping* nil
  "[Cyc] Table mapping implicit fort types to the explicit fort types of which they are composed. This must be the same in all mts.")

(defglobal *all-mts-isa-cache* nil
  "[Cyc] The id-index of forts types")

(defglobal *cached-preds*
  (list (reader-make-constant-shell "isa")
        (reader-make-constant-shell "genls")
        (reader-make-constant-shell "genlPreds")
        (reader-make-constant-shell "genlInverse")))

;;; Functions

(defun note-sbhl-caches-initialized ()
  (setf *sbhl-caches-initialized?* t)
  nil)

(defun sbhl-caches-initialized-p ()
  *sbhl-caches-initialized?*)

;; (defun all-fort-types () ...) -- no body, commented declareFunction (0 0)

(defun valid-fort-type? (type)
  "[Cyc] Accessor. Returns whether TYPE is a member of all-fort-types."
  (cached-node? type #$isa))

;; Reconstructed from Internal Constants: arglist ((NODE-VAR PRED) &BODY BODY),
;; expansion uses DO-SET + GET-CACHED-NODES-SET-FOR-PRED
(defmacro do-sbhl-cached-subsumption-nodes ((node-var pred) &body body)
  `(do-set (,node-var (get-cached-nodes-set-for-pred ,pred))
     ,@body))

(defun cached-node? (node pred)
  "[Cyc] Returns whether NODE is a cached superior node for PRED."
  (set-member? node (get-cached-nodes-set-for-pred pred)))

(defun sbhl-id-index-lookup (v-id-index node)
  "[Cyc] Does a fort-id-index-lookup on ID-INDEX with NODE, provided node is a fort."
  (when (fort-p node)
    (fort-id-index-lookup v-id-index node)))

(defun get-cached-nodes-set-for-pred (pred)
  "[Cyc] Returns the cached subsuming node set for PRED."
  (cond ((eql pred #$isa) *cached-isas-set*)
        ((eql pred #$genls) *cached-genls-set*)
        ((eql pred #$genlPreds) *cached-genl-predicates-set*)
        ((eql pred #$genlInverse) *cached-genl-predicates-set*)
        (t nil)))

(defun get-sbhl-cached-nodes-for-pred (pred)
  "[Cyc] Returns the cached subsuming nodes list for PRED."
  (cond ((eql pred #$isa) *cached-isas*)
        ((eql pred #$genls) *cached-genls*)
        ((eql pred #$genlPreds) *cached-genl-predicates*)
        ((eql pred #$genlInverse) *cached-genl-predicates*)
        (t nil)))

;; (defun valid-cached-predicate-p (pred) ...) -- no body, commented declareFunction (1 0)
;; (defun valid-cached-fort-type-p (type) ...) -- no body, commented declareFunction (1 0)
;; (defun valid-cached-genl-p (genl) ...) -- no body, commented declareFunction (1 0)

(defun sbhl-pred-has-caching-p (pred)
  "[Cyc] Returns whether PRED has any caching."
  (member-eq? pred *cached-preds*))

(defun sbhl-cache-use-possible-p (pred node1 node2)
  "[Cyc] Accessor. Determines whether a cache of the relation (PRED NODE1 NODE2) could exist and can currently be used."
  (and (check-sbhl-caches?)
       (sbhl-pred-has-caching-p pred)
       (fort-p node1)
       (cached-node? node2 pred)
       t))

(defun sbhl-cache-use-possible-for-nodes-p (pred nodes node)
  "[Cyc] Accessor."
  (and (check-sbhl-caches?)
       (sbhl-pred-has-caching-p pred)
       (every-in-list #'fort-p nodes)
       (cached-node? node pred)
       t))

(defun sbhl-cached-predicate-relation-p (pred subnode node &optional mt)
  "[Cyc] Accessor. Returns whether the (PRED SUBNODE NODE):MT relation is cached in the sbhl caches."
  (increment-sbhl-cache-attempt-historical-count)
  (let ((result nil)
        (mt-var mt))
    (let ((*mt* (update-inference-mt-relevance-mt mt-var))
          (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
          (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
      (setf result (sbhl-cached-relation-p pred subnode node)))
    (when result
      (increment-sbhl-cache-success-historical-count))
    result))

;; (defun sbhl-cached-relations-for-node (pred node &optional mt) ...) -- no body, commented declareFunction (2 1)
;; (defun sbhl-all-subnodes-for-cached-node (pred node) ...) -- no body, commented declareFunction (2 0)

(defun sbhl-cached-relation-p (pred subnode node)
  (if (all-mts-are-relevant?)
      (cached-all-mts-relation-p pred subnode node)
      (cached-relation-p pred subnode node)))

;; (defun sbhl-cached-relations (pred node) ...) -- no body, commented declareFunction (2 0)

(defun get-sbhl-cache-for-pred (pred)
  "[Cyc] Accessor. Returns the cached relations associated with PRED."
  (cond ((eql pred #$isa) *isa-cache*)
        ((eql pred #$genlPreds) *genl-predicate-cache*)
        ((eql pred #$genlInverse) *genl-inverse-cache*)
        ((eql pred #$genls) *genls-cache*)
        (t nil)))

(defun get-mts-for-cached-sbhl-relation (pred subnode node)
  "[Cyc] Accessor. Returns the list of mts for the cached (PRED SUBNODE NODE) relations."
  (declare (type sbhl-predicate-p pred))
  (let ((v-cache (get-sbhl-cache-for-pred pred)))
    (when v-cache
      (let ((subnode-store (gethash node v-cache)))
        (when subnode-store
          (gethash subnode subnode-store))))))

(defun cached-relation-p (pred subnode node)
  "[Cyc] Accessor. Returns whether the (PRED SUBNODE NODE):MT relation is valid, considering cached relations."
  (any-relevant-mt? (get-mts-for-cached-sbhl-relation pred subnode node)))

;; TODO - defmacro do-sbhl-cached-relations-for-node
;; Reconstructed from Internal Constants: arglist ((CACHED-NODE-VAR MTS-VAR SUBNODE PRED) &BODY BODY),
;; expansion uses DO-DICTIONARY, GET-SBHL-CACHE-FOR-PRED, PWHEN, DICTIONARY-P,
;; CLET, DICTIONARY-LOOKUP with uninterned SUBNODES-VAR temp var

;; (defun cached-relations-for-node (pred node) ...) -- no body, commented declareFunction (2 0)

(defun cached-relation-in-cache-p (pred subnode node mt)
  "[Cyc] Accessor. Like sbhl-cached-relation-p, except this looks just in the cache for an exact match for (PRED SUBNODE NODE):MT, and is not predicated on mt-relevance."
  (member? mt (gethash subnode (gethash node (get-sbhl-cache-for-pred pred)))
           #'hlmt-equal))

(defun sbhl-pred-all-mts-cache-uses-id-index-p (pred)
  (eq pred #$isa))

;; (defun sbhl-finalize-all-mts-cache (pred) ...) -- no body, commented declareFunction (1 0)

(defun get-sbhl-all-mts-cache-for-pred (pred)
  "[Cyc] Accessor. Returns the cached all-mts relations for PRED."
  (cond ((eql pred #$isa) *all-mts-isa-cache*)
        ((eql pred #$genlPreds) *all-mts-genl-predicate-cache*)
        ((eql pred #$genlInverse) *all-mts-genl-inverse-cache*)
        ((eql pred #$genls) *all-mts-genls-cache*)
        (t nil)))

(defun cached-all-mts-relation-p (pred subnode node)
  "[Cyc] Accessor. Returns whether the (PRED SUBNODE NODE) relation is cached with all-mts relevance."
  (let ((pred-uses-id-index? (sbhl-pred-all-mts-cache-uses-id-index-p pred))
        (all-mts-cache (get-sbhl-all-mts-cache-for-pred pred)))
    (unless all-mts-cache
      (error "All Mts cache is missing for ~A." pred))
    (let ((cached-list (if pred-uses-id-index?
                           (sbhl-id-index-lookup all-mts-cache subnode)
                           (gethash node all-mts-cache))))
      (when (set-p cached-list)
        (if pred-uses-id-index?
            (set-member? node cached-list)
            (set-member? subnode cached-list))))))

(defun cached-all-mts-relations-for-node (pred node)
  "[Cyc] Accessor. Returns the cached-nodes s.t. (PRED NODE CACHED-NODE) relation is valid with all-mts relevance."
  (if (sbhl-pred-all-mts-cache-uses-id-index-p pred)
      (let ((relation-set (sbhl-id-index-lookup (get-sbhl-all-mts-cache-for-pred pred) node)))
        (when (set-p relation-set)
          (set-element-list relation-set)))
      (let ((cached-relations nil))
        (maphash (lambda (cached-node subnodes)
                   (when (set-member? node subnodes)
                     (push cached-node cached-relations)))
                 (get-sbhl-all-mts-cache-for-pred pred))
        cached-relations)))

;; TODO - defmacro do-sbhl-cached-all-mts-relations
;; Reconstructed from Internal Constants: arglist ((LINK-NODE-VAR SUBNODE-VAR PRED) &BODY BODY),
;; expansion uses PIF, FORT-ID-INDEX-P, DO-FORT-ID-INDEX, DO-DICTIONARY,
;; GET-SBHL-ALL-MTS-CACHE-FOR-PRED with uninterned SUBNODES, NODES, CACHE temp vars

;; TODO - defmacro do-sbhl-cached-link-nodes-for-node-in-mt
;; Reconstructed from Internal Constants: arglist ((CACHED-LINK-NODE PRED SUBNODE MT) &BODY BODY),
;; expansion uses MEMBER?, DO-DICTIONARY, GET-SBHL-CACHE-FOR-PRED
;; with uninterned CACHE, CACHED-NODES-STORE temp vars

;; TODO - defmacro do-sbhl-cached-all-mts-relations-for-node
;; Reconstructed from Internal Constants: arglist ((CACHED-LINK-NODE PRED SUBNODE) &BODY BODY),
;; expansion uses SBHL-PRED-ALL-MTS-CACHE-USES-ID-INDEX-P, SBHL-ID-INDEX-LOOKUP,
;; SET-MEMBER?, GET-SBHL-ALL-MTS-CACHE-FOR-PRED, DO-DICTIONARY
;; with uninterned CACHE, SUBNODES temp vars

;; (defun initialize-sbhl-caches () ...) -- no body, commented declareFunction (0 0)
;; (defun initialize-all-mts-sbhl-caches () ...) -- no body, commented declareFunction (0 0)
;; (defun new-sbhl-cache () ...) -- no body, commented declareFunction (0 0)
;; (defun new-sbhl-sub-cache () ...) -- no body, commented declareFunction (0 0)
;; (defun initialize-implicit-fort-type-mapping () ...) -- no body, commented declareFunction (0 0)
;; (defun initialize-all-sbhl-caching () ...) -- no body, commented declareFunction (0 0)
;; (defun initialize-all-mts-caching-for-pred (pred) ...) -- no body, commented declareFunction (1 0)
;; (defun compute-sbhl-cache-from-all-mts-cache (pred) ...) -- no body, commented declareFunction (1 0)
;; (defun extend-sbhl-caches (pred node subnode mt) ...) -- no body, commented declareFunction (4 0)

(defun add-to-sbhl-cache (pred node subnode mt)
  "[Cyc] Modifier. Adds the MT info to the (PRED SUBNODE NODE) cache."
  (let* ((v-cache (get-sbhl-cache-for-pred pred))
         (subnodes (gethash node v-cache)))
    (unless subnodes
      (setf subnodes (make-hash-table :test #'eq)))
    (dictionary-pushnew subnodes subnode mt #'eq)
    (setf (gethash node v-cache) subnodes))
  nil)

;; (defun add-to-sbhl-cache-for-relevant-mts (pred node subnode) ...) -- no body, commented declareFunction (3 0)

(defun add-to-sbhl-all-mts-cache (pred node subnode)
  "[Cyc] Modifier. Adds the (PRED SUBNODE NODE) info to the all-mts cache."
  (let ((v-cache (get-sbhl-all-mts-cache-for-pred pred)))
    (if (sbhl-pred-all-mts-cache-uses-id-index-p pred)
        (let ((nodes (sbhl-id-index-lookup v-cache subnode)))
          (unless nodes
            (setf nodes (new-set #'eq)))
          (set-add node nodes)
          (fort-id-index-enter v-cache subnode nodes))
        (let ((subnodes (gethash node v-cache)))
          (unless subnodes
            (setf subnodes (new-set #'eq)))
          (set-add subnode subnodes)
          (setf (gethash node v-cache) subnodes))))
  nil)

(defun sbhl-cache-addition-maintainence (assertion)
  "[Cyc] Modifier. This is the main accessor for the SBHL to do cache maintainence. It belongs in the after-addings of predicates with cached relations."
  (when (recache-sbhl-caches?)
    (when (assertion-has-truth assertion :true)
      (let ((pred (gaf-predicate assertion)))
        (cond ((eql pred #$isa)
               (isa-cache-addition-maintainence assertion))
              ((eql pred #$genls)
               (genls-cache-addition-maintainence assertion))
              ((eql pred #$genlPreds)
               (sbhl-genl-preds-cache-addition-maintainence assertion))
              ((eql pred #$genlInverse)
               (sbhl-genl-preds-cache-addition-maintainence assertion))))))
  nil)

(defun possibly-add-to-sbhl-caches (assertion term2-check-pred cache-pred)
  "[Cyc] Modifier. Returns whether there was addition to the sbhl-caches on account of adding ASSERTION. This does the general addition maintainence for all preds. Each particular pred may do additional addition maintainence besides this."
  (let ((added? nil))
    (let ((*suspend-sbhl-cache-use?* t))
      (let* ((term1 (gaf-arg1 assertion))
             (term2 (gaf-arg2 assertion))
             (new-cached-relations (sbhl-predicate-relation-to-which-cached-nodes
                                    term2-check-pred term2 cache-pred))
             (old-cached-relations (cached-all-mts-relations-for-node cache-pred term1))
             (cached-relations-gained (set-difference new-cached-relations old-cached-relations
                                                      :test #'eq)))
        (dolist (new-cached-relation cached-relations-gained)
          (setf added? t)
          (add-to-sbhl-all-mts-cache cache-pred new-cached-relation term1))
        (dolist (new-type new-cached-relations)
          (dolist (mt (sbhl-max-floor-mts-of-predicate-paths
                       (get-sbhl-module cache-pred) term1 term2))
            (unless (cached-relation-in-cache-p cache-pred term1 new-type mt)
              (setf added? t)
              (add-to-sbhl-cache cache-pred new-type term1 mt))))))
    added?))

;; (defun retract-cached-relation (pred node subnode mt) ...) -- no body, commented declareFunction (4 0)

(defun retract-from-sbhl-cache (pred node subnode mt)
  "[Cyc] Modifier. Removes MT from the cache for NODE, and returns T iff this was the last MT for the PRED SUBNODE NODE relation."
  (let* ((nodes-cache (gethash node (get-sbhl-cache-for-pred pred)))
         (cached-mts (gethash subnode nodes-cache)))
    (if (and (singleton? cached-mts)
             (eq mt (first cached-mts)))
        (progn
          (remhash subnode nodes-cache)
          t)
        ;; missing-larkc 12425 — likely removes MT from the cached-mts list
        ;; (e.g. (delete mt cached-mts :test #'eq)) and updates the entry.
        ;; Returns NIL since this was not the last MT.
        (progn
          (missing-larkc 12425)
          nil))))

(defun retract-from-sbhl-all-mts-cache (pred node subnode)
  (let ((v-cache (get-sbhl-all-mts-cache-for-pred pred)))
    (if (sbhl-pred-all-mts-cache-uses-id-index-p pred)
        (let ((nodes (sbhl-id-index-lookup v-cache subnode)))
          (set-remove node nodes)
          (if (set-empty? nodes)
              (fort-id-index-remove v-cache subnode)
              (fort-id-index-enter v-cache subnode nodes)))
        (let ((subnodes (gethash node v-cache)))
          (set-remove subnode subnodes)
          (if (set-empty? subnodes)
              (remhash node v-cache)
              (setf (gethash node v-cache) subnodes)))))
  nil)

(defun sbhl-cache-removal-maintainence (assertion)
  "[Cyc] Modifier. This is the main accessor for the SBHL to do cache maintainence. It belongs in the after-removing of predicates with cached relations."
  (when (recache-sbhl-caches?)
    (when (assertion-has-truth assertion :true)
      (let ((pred (gaf-predicate assertion)))
        (cond ((eql pred #$isa)
               (isa-cache-removal-maintainence assertion))
              ((eql pred #$genls)
               (genls-cache-removal-maintainence assertion))
              ((eql pred #$genlPreds)
               (sbhl-genl-preds-cache-removal-maintainence assertion))
              ((eql pred #$genlInverse)
               (sbhl-genl-preds-cache-removal-maintainence assertion))))))
  nil)

(defun possibly-remove-from-sbhl-caches (pred assertion)
  "[Cyc] Modifier. Returns whether there was removal from the sbhl-caches on account of removing ASSERTION. This does the general removal maintainence for all preds. Each particular pred may do additional removal maintainence besides this."
  (let ((retracted? nil))
    (let ((*suspend-sbhl-cache-use?* t))
      (let* ((term1 (gaf-arg1 assertion))
             (mt (assertion-mt assertion))
             (current-cached-relations (cached-all-mts-relations-for-node pred term1))
             (new-cached-relations (sbhl-predicate-relation-to-which-cached-nodes pred term1 pred))
             (cached-relations-lost (set-difference current-cached-relations new-cached-relations
                                                    :test #'eq)))
        (dolist (lost-cached-relation cached-relations-lost)
          (setf retracted? t)
          (retract-from-sbhl-all-mts-cache pred lost-cached-relation term1))
        (let ((mt-matching-isas (sbhl-mt-matching-link-nodes (get-sbhl-module pred) term1 mt))
              (v-cache (get-sbhl-cache-for-pred pred)))
          (maphash (lambda (cached-relation cached-nodes-store)
                     (when (member? mt (gethash term1 cached-nodes-store))
                       (unless (and mt-matching-isas
                                    (sbhl-predicate-relation-p (get-sbhl-module pred)
                                                               term1 cached-relation))
                         (setf retracted? t)
                         (retract-from-sbhl-cache pred cached-relation term1 mt))))
                   v-cache))))
    retracted?))

(defun recache-sbhl-caches? ()
  (and (check-sbhl-caches?)
       (not *suppress-sbhl-recaching?*)
       t))

;; (defun already-in-sbhl-caches-p (pred node subnode mt) ...) -- no body, commented declareFunction (4 0)

(defun sbhl-predicate-relation-to-which-cached-nodes (pred node cache-pred)
  (let ((cached-nodes (get-sbhl-cached-nodes-for-pred cache-pred))
        (result nil))
    (with-all-mts
      (setf result (sbhl-predicate-relation-to-which (get-sbhl-module pred) node cached-nodes)))
    result))

(defun sbhl-predicate-relation-to-which-cached-nodes-excluding-link-node (pred node cache-pred excl-link-node)
  (let ((cached-nodes (get-sbhl-cached-nodes-for-pred cache-pred))
        (result nil))
    (with-all-mts
      (setf result (sbhl-predicate-relation-to-which-excluding-link-node
                     (get-sbhl-module pred) node cached-nodes excl-link-node)))
    result))

;; (defun clear-sbhl-cached-all-mts-relations-for-node (pred node) ...) -- no body, commented declareFunction (2 0)
;; (defun clear-sbhl-cached-relations-for-node (pred node) ...) -- no body, commented declareFunction (2 0)
;; (defun reset-cached-sbhl-relations-for-node (pred node &optional mt) ...) -- no body, commented declareFunction (2 1)
;; (defun initialize-all-mts-cache-for-genl-preds-and-inverse () ...) -- no body, commented declareFunction (0 0)
;; (defun compute-cached-predicates-from-all-mts-cache () ...) -- no body, commented declareFunction (0 0)
;; (defun compute-cached-inverses-from-all-mts-cache () ...) -- no body, commented declareFunction (0 0)

(defun sbhl-genl-preds-cache-addition-maintainence (assertion)
  (let ((extended? nil))
    (let ((pred (gaf-predicate assertion)))
      (cond ((eql pred #$genlPreds)
             (let ((genl-pred-extended? (possibly-add-to-sbhl-caches assertion #$genlPreds #$genlPreds))
                   (genl-inverse-extended? (possibly-add-to-sbhl-caches assertion #$genlInverse #$genlInverse)))
               (setf extended? (or genl-pred-extended? genl-inverse-extended?))))
            ((eql pred #$genlInverse)
             (let ((genl-pred-extended? (possibly-add-to-sbhl-caches assertion #$genlPreds #$genlInverse))
                   (genl-inverse-extended? (possibly-add-to-sbhl-caches assertion #$genlInverse #$genlPreds)))
               (setf extended? (or genl-pred-extended? genl-inverse-extended?))))
            (t
             (sbhl-error 3 "genlPreds / genlInverse after adding used for assertion with predicate ~a."
                         (gaf-predicate assertion)))))
    (when extended?
      (let ((spec-pred (gaf-arg1 assertion)))
        (declare (ignore spec-pred))
        ;; missing-larkc 1754 — likely calls reset-cached-genl-pred-and-inverse-relations
        ;; on spec-pred, updating the spec-preds/spec-inverses cache for the affected predicate
        (missing-larkc 1754))))
  nil)

(defun sbhl-genl-preds-cache-removal-maintainence (assertion)
  (let* ((genl-pred-retracted? (possibly-remove-from-sbhl-caches #$genlPreds assertion))
         (genl-inverse-retracted? (possibly-remove-from-sbhl-caches #$genlInverse assertion))
         (retracted? (or genl-pred-retracted? genl-inverse-retracted?)))
    (when retracted?
      (let ((spec-pred (gaf-arg1 assertion)))
        (declare (ignore spec-pred))
        ;; missing-larkc 1755 — likely calls reset-cached-genl-pred-and-inverse-relations
        ;; on spec-pred, updating the spec-preds/spec-inverses cache after removal
        (missing-larkc 1755))))
  nil)

;; (defun reset-cached-spec-preds-and-spec-inverses (pred) ...) -- no body, commented declareFunction (1 0)
;; (defun reset-cached-genl-pred-and-inverse-relations (pred) ...) -- no body, commented declareFunction (1 0)
;; (defun initialize-all-mts-cache-for-genls () ...) -- no body, commented declareFunction (0 0)
;; (defun compute-cached-genls-from-all-mts-cache () ...) -- no body, commented declareFunction (0 0)

(defun genls-cache-addition-maintainence (assertion)
  (let ((spec (gaf-arg1 assertion))
        (genl (gaf-arg2 assertion))
        (extended? nil))
    (setf extended? (possibly-add-to-sbhl-caches assertion #$genls #$genls))
    (when extended?
      ;; missing-larkc 1752 — likely calls reset-cached-genls-relations on spec,
      ;; updating the genls cache for all specs of the newly linked collection
      (missing-larkc 1752))
    (let ((new-cached-isas (sbhl-predicate-relation-to-which-cached-nodes #$genls spec #$isa))
          (old-cached-isas (sbhl-predicate-relation-to-which-cached-nodes-excluding-link-node
                            #$genls spec #$isa genl)))
      (let ((types-gained (set-difference new-cached-isas old-cached-isas :test #'eq)))
        (when types-gained
          ;; missing-larkc 1756 — likely calls reset-sbhl-types-of-all-instances on spec,
          ;; updating the isa cache for instances that gained new types via the genls link
          (missing-larkc 1756)))))
  nil)

(defun genls-cache-removal-maintainence (assertion)
  (let ((spec (gaf-arg1 assertion))
        (genl (gaf-arg2 assertion))
        (retracted? nil))
    (setf retracted? (possibly-remove-from-sbhl-caches #$genls assertion))
    (when retracted?
      ;; missing-larkc 1753 — likely calls reset-cached-genls-relations on spec,
      ;; updating the genls cache after removal of the genls link
      (missing-larkc 1753))
    (let ((new-cached-isas (sbhl-predicate-relation-to-which-cached-nodes #$genls spec #$isa))
          (old-cached-isas (sbhl-predicate-relation-to-which-cached-nodes #$genls genl #$isa)))
      (let ((types-lost (set-difference old-cached-isas new-cached-isas)))
        (when types-lost
          ;; missing-larkc 1757 — likely calls reset-sbhl-types-of-all-instances on spec,
          ;; updating the isa cache for instances that lost types via the genls unlink
          (missing-larkc 1757)))))
  nil)

;; (defun reset-sbhl-types-of-all-instances (col) ...) -- no body, commented declareFunction (1 0)
;; (defun reset-cached-genls-of-all-specs (col) ...) -- no body, commented declareFunction (1 0)
;; (defun reset-cached-genls-relations (col) ...) -- no body, commented declareFunction (1 0)
;; (defun initialize-all-mts-cache-for-isa () ...) -- no body, commented declareFunction (0 0)
;; (defun compute-cached-isas-from-all-mts-cache () ...) -- no body, commented declareFunction (0 0)

(defun isa-cache-addition-maintainence (assertion)
  (possibly-add-to-sbhl-caches assertion #$genls #$isa)
  nil)

(defun isa-cache-removal-maintainence (assertion)
  (possibly-remove-from-sbhl-caches #$isa assertion)
  nil)

;; (defun reset-cached-isa-relations (node) ...) -- no body, commented declareFunction (1 0)
