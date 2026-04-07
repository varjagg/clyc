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

;; Inference worker for transformation (rule application) tactics and links.

(defstruct (transformation-link-data (:conc-name "TRANS-LINK-DATA-"))
  hl-module
  bindings
  supports
  non-explanatory-subquery)

(defconstant *dtp-transformation-link-data* 'transformation-link-data)

(defun new-transformation-link (supported-problem supporting-mapped-problem
                                hl-module transformation-bindings
                                rule-assertion more-supports
                                non-explanatory-subquery)
  "[Cyc] @return transformation-link-p"
  (declare (type problem supported-problem))
  (let* ((supports (cons rule-assertion more-supports))
         (transformation-link (new-transformation-link-int supported-problem hl-module
                                                          transformation-bindings supports
                                                          non-explanatory-subquery)))
    (when supporting-mapped-problem
      (connect-supporting-mapped-problem-with-dependent-link supporting-mapped-problem
                                                            transformation-link))
    (problem-link-open-all transformation-link)
    (propagate-problem-link transformation-link)
    transformation-link))

(defun new-transformation-link-int (problem hl-module transformation-bindings
                                    supports non-explanatory-subquery)
  "[Cyc] Returns a new :transformation link
with its data properties set to HL-MODULE, BINDINGS, and SUPPORTS,
with a supported problem of PROBLEM, and no supporting problems yet."
  (let ((transformation-link (new-problem-link :transformation problem)))
    (new-transformation-link-data transformation-link)
    (set-transformation-link-hl-module transformation-link hl-module)
    (set-transformation-link-bindings transformation-link transformation-bindings)
    (set-transformation-link-supports transformation-link supports)
    (set-transformation-link-non-explanatory-subquery transformation-link non-explanatory-subquery)
    (when non-explanatory-subquery
      ;; Likely marks non-explanatory subquery on the problem store
      (missing-larkc 35020))
    transformation-link))

(defun new-transformation-link-data (transformation-link)
  (let ((data (make-transformation-link-data)))
    (set-problem-link-data transformation-link data))
  transformation-link)

;; (defun destroy-transformation-link (transformation-link) ...) -- active declareFunction, no body

(defun transformation-link-hl-module (transformation-link)
  (declare (type problem-link transformation-link))
  (let ((data (problem-link-data transformation-link)))
    (trans-link-data-hl-module data)))

(defun transformation-link-bindings (transformation-link)
  "[Cyc] The first elements of these bindings are in the space of TRANSFORMATION-LINK's
supported problem, and their second elements are in the space of
TRANSFORMATION-LINK's unique supporting problem."
  (declare (type problem-link transformation-link))
  (let ((data (problem-link-data transformation-link)))
    (trans-link-data-bindings data)))

(defun transformation-link-supports (transformation-link)
  (declare (type problem-link transformation-link))
  (let ((data (problem-link-data transformation-link)))
    (trans-link-data-supports data)))

(defun transformation-link-rule-assertion (transformation-link)
  (first (transformation-link-supports transformation-link)))

;; (defun transformation-link-more-supports (transformation-link) ...) -- active declareFunction, no body
;; (defun transformation-link-non-explanatory-subquery (transformation-link) ...) -- active declareFunction, no body

(defun set-transformation-link-hl-module (transformation-link hl-module)
  (declare (type hl-module hl-module))
  (let ((data (problem-link-data transformation-link)))
    (setf (trans-link-data-hl-module data) hl-module))
  transformation-link)

(defun set-transformation-link-bindings (transformation-link v-bindings)
  ;; checkType: binding-list-p
  (let ((data (problem-link-data transformation-link)))
    (setf (trans-link-data-bindings data) v-bindings))
  transformation-link)

(defun set-transformation-link-supports (transformation-link supports)
  ;; checkType: hl-justification-p
  (let ((data (problem-link-data transformation-link)))
    (setf (trans-link-data-supports data) supports))
  transformation-link)

(defun set-transformation-link-non-explanatory-subquery (transformation-link subquery)
  ;; checkType: non-explanatory-subquery-spec-p
  (let ((data (problem-link-data transformation-link)))
    (setf (trans-link-data-non-explanatory-subquery data) subquery))
  transformation-link)

(defun transformation-link-tactic (transformation-link)
  (declare (type problem-link transformation-link))
  (let* ((problem (problem-link-supported-problem transformation-link))
         (hl-module (transformation-link-hl-module transformation-link))
         (rule (transformation-link-rule-assertion transformation-link)))
    (do-problem-tactics (candidate-tactic problem :type :transformation)
      (when (and (eq hl-module (tactic-hl-module candidate-tactic))
                 (eq rule (transformation-tactic-rule candidate-tactic)))
        (return-from transformation-link-tactic candidate-tactic)))
    (unless (tactically-unexamined-problem-p problem)
      (return-from transformation-link-tactic
        (error "No tactic found for ~S" transformation-link))))
  nil)

;; (defun transformation-link-pragmatic-requirements (transformation-link) ...) -- active declareFunction, no body

(defun transformation-link-supporting-mapped-problem (transformation-link)
  "[Cyc] @return nil or mapped-problem-p"
  (problem-link-first-supporting-mapped-problem transformation-link))

(defun transformation-link-supporting-problem (transformation-link)
  "[Cyc] @return nil or problem-p"
  (let ((supporting-mapped-problem (transformation-link-supporting-mapped-problem transformation-link)))
    (when supporting-mapped-problem
      (mapped-problem-problem supporting-mapped-problem))))

(defun transformation-link-supporting-variable-map (transformation-link)
  "[Cyc] @return variable-map-p"
  (let ((supporting-mapped-problem (transformation-link-supporting-mapped-problem transformation-link)))
    (when supporting-mapped-problem
      (mapped-problem-variable-map supporting-mapped-problem))))

(defun transformation-link-transformation-mt (transformation-link)
  (let ((problem (problem-link-supported-problem transformation-link)))
    (single-literal-problem-mt problem)))

;; (defun transformation-link-supporting-problem-wholly-explanatory? (transformation-link) ...) -- active declareFunction, no body
;; (defun transformed-problem-using-rule (problem rule) ...) -- active declareFunction, no body
;; (defun transformed-problem-using-rule-and-hl-module (problem rule hl-module) ...) -- active declareFunction, no body
;; (defun transformation-link-rule-bindings-to-closed (transformation-link) ...) -- active declareFunction, no body
;; (defun transformation-rule-bindings-to-closed (bindings) ...) -- active declareFunction, no body

;;; Macro: with-problem-store-transformation-assumptions
;; Reconstructed from Internal Constants:
;; $list32=(STORE &BODY BODY), $sym33$STORE_VAR=gensym,
;; $sym34$CLET, $list35=(*HL-FAILURE-BACKCHAINING* T),
;; $list36=(*UNBOUND-RULE-BACKCHAIN-ENABLED* T),
;; $list37=(*EVALUATABLE-BACKCHAIN-ENABLED* T),
;; $sym38$*NEGATION-BY-FAILURE*, $sym39$PROBLEM-STORE-NEGATION-BY-FAILURE?
;; Expansion verified against execute-literal-level-transformation-tactic body.
(defmacro with-problem-store-transformation-assumptions ((store) &body body)
  (with-temp-vars (store-var)
    `(let ((,store-var ,store))
       (let ((*hl-failure-backchaining* t)
             (*unbound-rule-backchain-enabled* t)
             (*evaluatable-backchain-enabled* t)
             (*negation-by-failure* (problem-store-negation-by-failure? ,store-var)))
         ,@body))))

(defun meta-transformation-tactic-p (object)
  (and (tactic-p object)
       (meta-transformation-module-p (tactic-hl-module object))))

(deflexical *determine-new-transformation-tactics-module*
  (if (and (boundp '*determine-new-transformation-tactics-module*)
           *determine-new-transformation-tactics-module*)
      *determine-new-transformation-tactics-module*
      (inference-meta-transformation-module :determine-new-transformation-tactics)))

(defun add-tactic-to-determine-new-literal-transformation-tactics (problem asent sense mt)
  "[Cyc] First we add a tactic which, if executed, determines the rest of the transformation tactics for PROBLEM."
  (unless (inference-backchain-forbidden-asent? asent mt)
    (new-meta-transformation-tactic problem asent sense)
    t))

(defun inference-backchain-forbidden-asent? (asent mt)
  (let ((predicate (atomic-sentence-predicate asent)))
    (cond ((and (fort-p predicate)
                (inference-backchain-forbidden? predicate mt))
           t)
          ((inference-complete-asent? asent mt) t)
          (t nil))))

(defun new-meta-transformation-tactic (problem asent sense)
  (let* ((tactic (new-tactic problem *determine-new-transformation-tactics-module*))
         (productivity 0))
    (set-tactic-completeness tactic :grossly-incomplete)
    (set-tactic-productivity tactic productivity)
    (do-problem-relevant-strategies (strategy problem)
      (strategy-note-new-tactic strategy tactic))
    tactic))

;; (defun compute-strategic-properties-of-meta-transformation-tactic (tactic strategy) ...) -- active declareFunction, no body

(defun transformation-link-p (object)
  (and (problem-link-p object)
       (eq :transformation (problem-link-type object))))

(defun transformation-tactic-p (tactic)
  (and (tactic-p tactic)
       (eq :transformation (tactic-type tactic))))

(defun transformation-tactic-rule (transformation-tactic)
  "[Cyc] @return rule-assertion?; the rule assertion associated with TACTIC
temporarily sometimes returns NIL while transformation modules are in transition."
  (tactic-data transformation-tactic))

;; (defun transformation-rule-tactic-p (tactic) ...) -- active declareFunction, no body

(defun transformation-generator-tactic-p (object)
  "[Cyc] @return booleanp; whether OBJECT is a transformation tactic that generates other
transformation tactics."
  (when (transformation-tactic-p object)
    (null (transformation-tactic-rule object))))

(defun transformation-generator-tactic-lookahead-rule (transformation-generator-tactic)
  "[Cyc] Return the next rule that TRANSFORMATION-GENERATOR-TACTIC would generate, if any."
  ;; checkType: transformation-generator-tactic-p
  (let ((iterator (tactic-progress-iterator transformation-generator-tactic)))
    (when (iterator-p iterator)
      (let ((state
              ;; Likely accesses the iterator's internal state
              (missing-larkc 22963)))
        (when (listp state)
          (let ((rules (first state)))
            (when (listp rules)
              (let ((rule (first rules)))
                (when (assertion-p rule)
                  (return-from transformation-generator-tactic-lookahead-rule rule)))))))))
  nil)

(defun transformation-tactic-lookahead-rule (transformation-tactic)
  "[Cyc] Return the rule to use for lookahead heuristic analysis of TRANSFORMATION-TACTIC."
  (let ((rule (transformation-tactic-rule transformation-tactic)))
    (unless rule
      (setf rule (transformation-generator-tactic-lookahead-rule transformation-tactic)))
    rule))

(defun transformation-proof-p (object)
  (and (proof-p object)
       (transformation-link-p (proof-link object))))

(defun transformation-proof-rule-assertion (proof)
  ;; checkType: transformation-proof-p
  (first (proof-supports proof)))

;; (defun transformation-proof-additional-supports (proof) ...) -- active declareFunction, no body

(defun transformation-proof-subproof (proof)
  "[Cyc] @return nil or proof-p"
  ;; checkType: transformation-proof-p
  (proof-first-subproof proof))

(defun generalized-transformation-link-p (object)
  (or (transformation-link-p object)
      (residual-transformation-link-p object)))

(defun generalized-transformation-link-rule-assertion (link)
  (cond ((transformation-link-p link)
         (transformation-link-rule-assertion link))
        ((residual-transformation-link-p link)
         ;; Likely calls residual-transformation-link-rule-assertion
         (missing-larkc 35091))
        (t (error "generalized transformation link of unexpected type: ~s" link))))

(defun generalized-transformation-link-unaffected-by-exceptions? (link)
  (not (rule-has-exceptions? (generalized-transformation-link-rule-assertion link))))

(defun generalized-transformation-proof-p (object)
  (and (proof-p object)
       (generalized-transformation-link-p (proof-link object))))

(defun generalized-transformation-proof-rule-assertion (proof)
  (cond ((transformation-proof-p proof)
         (transformation-proof-rule-assertion proof))
        ((residual-transformation-proof-p proof)
         ;; Likely calls residual-transformation-proof-rule-assertion
         (missing-larkc 35104))
        (t (error "generalized transformation proof of unexpected type: ~s" proof))))

;; (defun generalized-transformation-proof-transformation-link (proof) ...) -- active declareFunction, no body
;; (defun determine-new-literal-transformation-tactics (problem asent sense) ...) -- active declareFunction, no body
;; (defun determine-new-literal-transformation-tactics-int (problem asent sense &optional disabled-modules) ...) -- active declareFunction, no body

(defun determine-rules-for-literal-transformation-tactics (problem asent hl-module)
  (let ((candidate-rules nil))
    (multiple-value-bind (inference non-continuable-private-problem-store?)
        (problem-inference-and-non-continuable-problem-store-private problem)
      (if (and non-continuable-private-problem-store?
               (not (inference-allows-use-of-all-rules? inference)))
          (let ((rules nil))
            (do-set (rule (inference-allowed-rules inference))
              (push rule rules))
            (setf candidate-rules (sort-rules-via-current-inference-rule-preference rules)))
          (let ((rule-select-method (hl-module-rule-select-func hl-module)))
            (when (function-spec-p rule-select-method)
              (setf candidate-rules (funcall rule-select-method asent)))))
      (let ((rule-filter-method (hl-module-rule-filter-func hl-module))
            (rules nil))
        (if (not (function-spec-p rule-filter-method))
            (setf rules (copy-list candidate-rules))
            (progn
              (dolist (rule candidate-rules)
                (when (funcall rule-filter-method asent rule)
                  (push rule rules)))
              (setf rules (nreverse rules))))
        (setf rules (delete-if #'inference-excepted-assertion? rules))
        (when (genl-rules-enabled?)
          (setf rules (max-rules rules)))
        rules))))

(defun inference-excepted-assertion? (assertion)
  (memoized-inference-excepted-assertion? assertion (current-mt-relevance-mt)))

(defun-memoized memoized-inference-excepted-assertion? (assertion mt) (:test equal)
  (excepted-assertion-in-mt? assertion (conservative-constraint-mt mt)))

(defun problem-inference-and-non-continuable-problem-store-private (problem)
  "[Cyc] Given a problem get its inference if the problem store it is in is private for its inference
Also return whether the problem store is private and the inference is non-continuable."
  (let* ((problem-store (problem-store problem))
         (non-continuable? nil)
         (problem-store-private? nil)
         (inference nil))
    (when (problem-store-has-only-one-inference? problem-store)
      (setf inference (first-problem-store-inference problem-store))
      (setf problem-store-private? (inference-problem-store-private? inference))
      (setf non-continuable? (not (inference-continuable? inference))))
    (values inference (and problem-store-private?
                          non-continuable?))))

;; (defun single-literal-problem-candidate-transformation-tactic-specs (problem) ...) -- active declareFunction, no body

(defun determine-literal-transformation-tactic-specs (asent sense disabled-modules)
  "[Cyc] Returns lists of the form (hl-module productivity), :complete is the assumed completeness"
  (determine-literal-transformation-tactic-specs-int asent sense disabled-modules :tactic-specs))

(defun determine-literal-transformation-tactic-specs-int (asent sense disabled-modules return-type)
  "[Cyc] @param RETURN-TYPE keywordp; either :tactic-spec or :total-productivity.
If :tactic-specs, returns lists of the form (hl-module productivity), where :complete is the assumed completeness.
If :total-productivity, returns a productivity-p which is the sum of all the applicable productivities."
  (let ((tactic-specs nil)
        (total-productivity 0)
        (predicate (atomic-sentence-predicate asent))
        (supplanted-modules nil)
        (exclusive-found? nil))
    (do* ((rest (transformation-modules) (rest rest)))
         ((or exclusive-found? (null rest)))
      (let ((hl-module (first rest)))
        (when (hl-module-active? hl-module disabled-modules)
          (unless (and supplanted-modules
                       (member hl-module supplanted-modules))
            (when (and (hl-module-sense-relevant-p hl-module sense)
                       (hl-module-predicate-relevant-p hl-module predicate)
                       (hl-module-required-pattern-matched-p hl-module asent)
                       (hl-module-required-mt-relevant? hl-module)
                       (hl-module-direction-relevant? hl-module))
              (let ((exclusive-func (hl-module-exclusive-func hl-module)))
                (when (or (null exclusive-func)
                          (and (function-spec-p exclusive-func)
                               (funcall exclusive-func asent)))
                  (when exclusive-func
                    (multiple-value-bind (exclusive-found?-val tactic-specs-val supplanted-modules-val)
                        ;; Likely handles exclusive module logic
                        (missing-larkc 36244)
                      (setf exclusive-found? exclusive-found?-val)
                      (setf tactic-specs tactic-specs-val)
                      (setf supplanted-modules supplanted-modules-val)))
                  (let ((required-func (hl-module-required-func hl-module)))
                    (when (or (null required-func)
                              (and (function-spec-p required-func)
                                   (funcall required-func asent)))
                      (let ((cost (hl-module-asent-cost hl-module asent)))
                        (when cost
                          (let ((productivity (productivity-for-number-of-children cost)))
                            (case return-type
                              (:tactic-specs
                               (let ((tactic-spec (list hl-module productivity)))
                                 (push tactic-spec tactic-specs)))
                              (:total-productivity
                               (setf total-productivity
                                     ;; Likely adds productivity values
                                     (missing-larkc 36510))))))))))))))))
    (case return-type
      (:tactic-specs tactic-specs)
      (:total-productivity total-productivity)
      (otherwise (error "unexpected tactic-specs return type ~a" return-type)))))

(defun literal-level-transformation-tactic-p (tactic)
  (and (transformation-tactic-p tactic)
       (literal-level-tactic-p tactic)))

(defun maybe-new-transformation-link (supported-problem supporting-mapped-problem
                                      tactic transformation-bindings
                                      rule-assertion more-supports
                                      non-explanatory-subquery)
  "[Cyc] @return nil or transformation-link-p
Creates a new transformation link iff it would be interesting to do so."
  (let ((mt (single-literal-problem-mt supported-problem)))
    (unless (rule-bindings-wff-cached? rule-assertion transformation-bindings mt)
      (warn "pruning ~s ~s ~s" rule-assertion mt transformation-bindings)
      (return-from maybe-new-transformation-link nil)))
  (let* ((hl-module (tactic-hl-module tactic))
         (transformation-link (new-transformation-link supported-problem supporting-mapped-problem
                                                       hl-module transformation-bindings
                                                       rule-assertion more-supports
                                                       non-explanatory-subquery))
         (store (problem-store supported-problem)))
    (problem-store-note-transformation-rule-considered store rule-assertion)
    (maybe-possibly-add-residual-transformation-links-via-transformation-link transformation-link)
    (when supporting-mapped-problem
      (recompute-thrown-away-due-to-new-transformation-link
       (mapped-problem-problem supporting-mapped-problem)))
    transformation-link))

(defun recompute-thrown-away-due-to-new-transformation-link (problem)
  (do-problem-relevant-strategies (strategy problem)
    (set-problem-recompute-thrown-away-wrt-all-motivations problem strategy)
    (when (abductive-strategy-p strategy)
      (dolist (sibling-tactic (problem-tactics problem))
        ;; Likely reconsiders sibling tactics for abduction
        (missing-larkc 36463)))))

(defun new-transformation-tactic (problem hl-module productivity rule)
  (let* ((tactic (new-tactic problem hl-module rule))
         (completeness :grossly-incomplete))
    (set-tactic-productivity tactic productivity)
    (set-tactic-completeness tactic completeness)
    (do-problem-relevant-strategies (strategy problem)
      (strategy-note-new-tactic strategy tactic))
    tactic))

(defun compute-strategic-properties-of-transformation-tactic (tactic strategy)
  tactic)

;;; Macro: with-transformation-tactic-execution-assumptions
;; Reconstructed from Internal Constants:
;; $list58=((TACTIC MT SENSE) &BODY BODY), $sym59$TACTIC_VAR=gensym,
;; $sym60$WITH-INFERENCE-MT-RELEVANCE, $sym61$*INFERENCE-EXPAND-HL-MODULE*,
;; $sym62$TACTIC-HL-MODULE, $sym63$*INFERENCE-EXPAND-SENSE*,
;; $sym64$WITH-PROBLEM-STORE-TRANSFORMATION-ASSUMPTIONS, $sym65$TACTIC-STORE
;; Expansion verified against execute-literal-level-transformation-tactic body.
(defmacro with-transformation-tactic-execution-assumptions (((tactic mt sense)) &body body)
  (with-temp-vars (tactic-var)
    `(let ((,tactic-var ,tactic))
       (with-inference-mt-relevance ,mt
         (let ((*inference-expand-hl-module* (tactic-hl-module ,tactic-var))
               (*inference-expand-sense* ,sense))
           (with-problem-store-transformation-assumptions ((tactic-store ,tactic-var))
             ,@body))))))

(defun execute-literal-level-transformation-tactic (tactic mt asent sense)
  (with-transformation-tactic-execution-assumptions ((tactic mt sense))
    (if (tactic-in-progress? tactic)
        (tactic-in-progress-next tactic)
        (let ((progress-iterator (maybe-make-transformation-tactic-progress-iterator
                                  tactic asent sense)))
          (cond ((null progress-iterator))
                ((listp progress-iterator)
                 (dolist (rule progress-iterator)
                   (handle-one-transformation-tactic-rule-select-result tactic rule)))
                (t (note-tactic-progress-iterator tactic progress-iterator))))))
  tactic)

(defun maybe-make-transformation-tactic-progress-iterator (tactic asent sense)
  (cond ((meta-transformation-tactic-p tactic)
         (maybe-make-meta-transformation-progress-iterator tactic asent sense))
        ((null (transformation-tactic-rule tactic))
         (maybe-make-transformation-rule-select-progress-iterator tactic asent))
        (t (maybe-make-transformation-expand-progress-iterator tactic asent))))

(defun maybe-make-meta-transformation-progress-iterator (tactic asent sense)
  (let ((name (tactic-hl-module-name tactic)))
    (must (eq name :determine-new-transformation-tactics)
        "time to add meta-transformation support for ~S" name))
  (let ((progress-iterator nil)
        (problem (tactic-problem tactic))
        (tactic-specs (determine-literal-transformation-tactic-specs asent sense nil)))
    (dolist (tactic-spec tactic-specs)
      (destructuring-bind (hl-module productivity) tactic-spec
        (new-transformation-tactic problem hl-module productivity nil)))
    progress-iterator))

(defparameter *transformation-tactic-iteration-threshold* 2
  "[Cyc] The number of expected transformation tactic results at which we generate them iteratively.")

(defun maybe-make-transformation-rule-select-progress-iterator (tactic asent)
  (let* ((rules nil)
         (problem (tactic-problem tactic))
         (hl-module (tactic-hl-module tactic)))
    (setf rules (determine-rules-for-literal-transformation-tactics problem asent hl-module))
    (let ((new-productivity (productivity-for-number-of-children (length rules))))
      (set-tactic-productivity tactic new-productivity nil))
    (when (length>= rules *transformation-tactic-iteration-threshold*)
      ;; Likely creates an iterator from the rules list
      (setf rules (missing-larkc 36431)))
    rules))

;; (defun new-transformation-rule-select-progress-iterator (tactic asent) ...) -- active declareFunction, no body

(defun handle-one-transformation-tactic-rule-select-result (transformation-tactic rule)
  (let ((existing-rule (transformation-tactic-rule transformation-tactic)))
    (must (null existing-rule)
        "transformation tactic ~S already has rule ~S" transformation-tactic existing-rule))
  (let* ((problem (tactic-problem transformation-tactic))
         (hl-module (tactic-hl-module transformation-tactic))
         (productivity (productivity-for-number-of-children 1)))
    (decrement-tactic-productivity-for-number-of-children transformation-tactic)
    (new-transformation-tactic problem hl-module productivity rule)))

(defun maybe-make-transformation-expand-progress-iterator (tactic asent)
  (let ((progress-iterator nil))
    (let ((*transformation-add-node-method* 'handle-transformation-add-node-for-expand-results))
      (let* ((hl-module (tactic-hl-module tactic))
             (rule (transformation-tactic-rule tactic))
             (expand-method (hl-module-expand-func hl-module)))
        (when (function-spec-p expand-method)
          (funcall expand-method asent rule))))
    progress-iterator))

(defun handle-transformation-add-node-for-expand-results (rule-assertion rule-pivot-asent
                                                          rule-pivot-sense unification-bindings
                                                          unification-dependent-dnf more-supports)
  "[Cyc] @param UNIFICATION-BINDINGS; current tactic's problem vars -> something
@param UNIFICATION-DEPENDENT-DNF the new transformed query"
  (setf unification-bindings (inference-simplify-unification-bindings unification-bindings))
  (setf unification-bindings (possibly-optimize-bindings-wrt-equivalence unification-bindings))
  (let* ((tactic (currently-executing-tactic))
         (unification-explanatory-dnf (copy-clause unification-dependent-dnf)))
    (when (rule-assertion-has-some-pragmatic-requirement? rule-assertion nil)
      (let ((pragmatic-requirements-dnf
              ;; Likely computes pragmatic requirements DNF for the rule
              (missing-larkc 36427)))
        (setf unification-dependent-dnf (nmerge-dnf unification-dependent-dnf pragmatic-requirements-dnf))))
    (when (rule-assertion-worth-adding-type-constraints? rule-assertion)
      (let ((type-constraint-dnf
              ;; Likely computes type constraint DNF from the rule
              (missing-larkc 3444)))
        (setf unification-dependent-dnf (nmerge-dnf unification-dependent-dnf type-constraint-dnf))))
    (let ((dont-care-constraints (transformation-additional-dont-care-constraints
                                  rule-pivot-asent unification-dependent-dnf
                                  rule-assertion unification-bindings)))
      (when dont-care-constraints
        (let ((dont-care-dnf (make-dnf nil dont-care-constraints)))
          (setf unification-dependent-dnf (nmerge-dnf unification-dependent-dnf dont-care-dnf)))))
    (let* ((unrestricted-transformation-dependent-dnf
             (unification-dependent-dnf-to-transformation-dependent-dnf unification-dependent-dnf))
           (unrestricted-transformation-explanatory-dnf
             (unification-dependent-dnf-to-transformation-dependent-dnf unification-explanatory-dnf))
           (transformation-bindings
             (unification-bindings-to-transformation-bindings unification-bindings)))
      (complete-execution-of-transformation-tactic tactic transformation-bindings rule-assertion
                                                   more-supports
                                                   unrestricted-transformation-dependent-dnf
                                                   unrestricted-transformation-explanatory-dnf))))

(defparameter *inference-transformation-type-checking-enabled?* nil
  "[Cyc] Whether we allow the possibility of adding type constraints
during transformation.")

(defun rule-assertion-worth-adding-type-constraints? (rule-assertion)
  (when (null *inference-transformation-type-checking-enabled?*)
    (return-from rule-assertion-worth-adding-type-constraints? nil))
  t)

(defun transformation-additional-dont-care-constraints (rule-pivot-asent unification-dependent-dnf
                                                        rule-assertion unification-bindings)
  (let ((source-var-pos-lits (additional-source-variable-pos-lits rule-pivot-asent
                                                                   unification-dependent-dnf
                                                                   rule-assertion))
        (dont-care-constraints nil))
    (dolist (source-var-pos-lit source-var-pos-lits)
      (let ((substituted-pos-lit (apply-bindings unification-bindings source-var-pos-lit)))
        (unless (fully-bound-p substituted-pos-lit)
          (push source-var-pos-lit dont-care-constraints))))
    (nreverse dont-care-constraints)))

(defun nmerge-dnf (existing-dnf added-dnf)
  "[Cyc] Destructively modify EXISTING-DNF by merging ADDED-DNF into it.
Return the modified EXISTING-DNF."
  (make-dnf (append (neg-lits existing-dnf) (neg-lits added-dnf))
            (append (pos-lits existing-dnf) (pos-lits added-dnf))))

;; (defun merge-dnf (existing-dnf added-dnf) ...) -- active declareFunction, no body

(defun complete-execution-of-transformation-tactic (tactic transformation-bindings rule-assertion
                                                    more-supports
                                                    unrestricted-transformation-dependent-dnf
                                                    unrestricted-transformation-explanatory-dnf)
  (let* ((supported-problem (tactic-problem tactic))
         (store (problem-store supported-problem))
         (restricted-transformation-dependent-dnf (apply-bindings transformation-bindings
                                                               unrestricted-transformation-dependent-dnf))
         (supporting-mapped-problem nil))
    (unless (empty-clause? restricted-transformation-dependent-dnf)
      (let* ((dependent-query (dnf-and-mt-to-hl-query restricted-transformation-dependent-dnf *mt*))
             (abduction-allowed? (problem-store-abduction-allowed?
                                  (problem-store (tactic-problem tactic)))))
        (unless (potentially-wf-transformation-dependent-query dependent-query abduction-allowed?)
          (return-from complete-execution-of-transformation-tactic nil))
        (setf supporting-mapped-problem (find-or-create-problem store dependent-query))))
    (let ((non-explanatory-subquery
            (compute-transformation-non-explanatory-subquery
             unrestricted-transformation-dependent-dnf
             unrestricted-transformation-explanatory-dnf
             restricted-transformation-dependent-dnf
             transformation-bindings
             supporting-mapped-problem)))
      (maybe-new-transformation-link supported-problem supporting-mapped-problem tactic
                                     transformation-bindings rule-assertion more-supports
                                     non-explanatory-subquery))))

(defun compute-transformation-non-explanatory-subquery (unrestricted-transformation-dependent-dnf
                                                        unrestricted-transformation-explanatory-dnf
                                                        restricted-transformation-dependent-dnf
                                                        transformation-bindings
                                                        supporting-mapped-problem)
  (when (equal unrestricted-transformation-dependent-dnf
               unrestricted-transformation-explanatory-dnf)
    (return-from compute-transformation-non-explanatory-subquery nil))
  (let* ((non-explanatory-dnf
           ;; Likely computes the DNF difference between dependent and explanatory
           (missing-larkc 30248))
         (restricted-non-explanatory-dnf (apply-bindings transformation-bindings non-explanatory-dnf))
         (non-explanatory-query (dnf-and-mt-to-hl-query restricted-non-explanatory-dnf *mt*))
         (non-explanatory-subquery (apply-bindings-backwards
                                    (mapped-problem-variable-map supporting-mapped-problem)
                                    non-explanatory-query)))
    non-explanatory-subquery))

(defun potentially-wf-transformation-dependent-query (dependent-query abduction-allowed?)
  (dolist (contextualized-dnf dependent-query)
    (dolist (contextualized-asent (neg-lits contextualized-dnf))
      (unless (potentially-wf-restricted-transformation-dependent-asent
               contextualized-asent :neg abduction-allowed?)
        (return-from potentially-wf-transformation-dependent-query nil)))
    (dolist (contextualized-asent (pos-lits contextualized-dnf))
      (unless (potentially-wf-restricted-transformation-dependent-asent
               contextualized-asent :pos abduction-allowed?)
        (return-from potentially-wf-transformation-dependent-query nil))))
  t)

(defun potentially-wf-restricted-transformation-dependent-asent (contextualized-asent sense
                                                                  abduction-allowed?)
  (declare (ignore sense))
  (destructuring-bind (mt asent) contextualized-asent
    (declare (ignore mt))
    (and (syntactically-valid-asent asent)
         (or (not (and (null abduction-allowed?)
                       (atomic-sentence-with-pred-p asent #$termOfUnit)))
             ;; Likely validates the term-of-unit asent is syntactically valid
             (missing-larkc 36434)))))

(defun syntactically-valid-asent (asent)
  (cycl-atomic-sentence-p asent))

;; (defun syntactically-valid-contextualized-term-of-unit-asent (contextualized-asent sense) ...) -- active declareFunction, no body

(defun new-transformation-proof (transformation-link subproof variable-map)
  "[Cyc] @param SUBPROOF nil or proof-p
@param VARIABLE-MAP; TRANSFORMATION-LINK's supporting problem -> TRANSFORMATION-LINK's extended supported problem
@return 0 proof-p
@return 1 whether the returned proof was newly created
@note see the unit test :heinous-unification-backchain for an example walkthrough of
the bindings processing of this function."
  ;; checkType: transformation-link-p
  (let* ((transformation-bindings (transformation-link-bindings transformation-link))
         (supporting-subproof-bindings (if subproof (proof-bindings subproof) nil))
         (subproofs (if subproof (list subproof) nil))
         (canonical-proof-bindings (compute-canonical-transformation-proof-bindings
                                    variable-map transformation-bindings
                                    supporting-subproof-bindings)))
    (propose-new-proof-with-bindings transformation-link canonical-proof-bindings subproofs)))

(defun compute-canonical-transformation-proof-bindings (t-link-variable-map
                                                        transformation-bindings
                                                        supporting-subproof-bindings)
  "[Cyc] @param T-LINK-VARIABLE-MAP; TRANSFORMATION-LINK's supporting problem -> TRANSFORMATION-LINK's extended supported problem
@param TRANSFORMATION-BINDINGS; TRANSFORMATION-LINK's extended supported problem vars -> extended supported problem vars or new contents
@param SUPPORTING-SUBPROOF-BINDINGS; TRANSFORMATION-LINK's supporting problem vars -> old contents"
  (let* ((subproof-bindings (transfer-variable-map-to-bindings-filtered
                             t-link-variable-map supporting-subproof-bindings))
         (final-combined-bindings (unify-transformation-and-subproof-bindings
                                   transformation-bindings subproof-bindings))
         (proof-bindings (extended-supported-problem-bindings-to-supported-problem-bindings
                          final-combined-bindings))
         (canonical-proof-bindings (canonicalize-proof-bindings proof-bindings)))
    canonical-proof-bindings))

(defun unification-dependent-dnf-to-transformation-dependent-dnf (unification-dependent-dnf)
  (variable-base-inversion unification-dependent-dnf))

(defun unification-bindings-to-transformation-bindings (unification-bindings)
  "[Cyc] @param UNIFICATION-BINDINGS; the bindings returned by @xref transformation-add-node.
UNIFICATION-BINDINGS has the base variables (0-99) being the variables of the support (the rule),
and the non-base vars (100-199) being the variables of the supported problem.
This swaps the base and non-base variables.
It also does a little bit of bindings simplification."
  (let ((swapped-unification-bindings (swap-variable-spaces-of-unification-bindings unification-bindings)))
    (let ((bindings-to-closed (bindings-to-closed swapped-unification-bindings)))
      (when bindings-to-closed
        (let ((transformation-bindings nil))
          (dolist (binding swapped-unification-bindings)
            (let* ((old-value (variable-binding-value binding))
                   (new-value (apply-bindings bindings-to-closed old-value)))
              (push (make-variable-binding (variable-binding-variable binding) new-value)
                    transformation-bindings)))
          (setf swapped-unification-bindings (nreverse transformation-bindings)))))
    swapped-unification-bindings))

(defun swap-variable-spaces-of-unification-bindings (unification-bindings)
  "[Cyc] Adds or subtracts 100 from all variables in UNIFICATION-BINDINGS.
This is tied with the assumptions inside the transformation modules about how they
call transformation-asent-unify."
  (variable-base-inversion unification-bindings))

(defun transformation-proof-rule-bindings (transformation-proof)
  "[Cyc] @return bindings-p; TRANSFORMATION-LINK's rule assertion vars -> contents
i.e. the variables in the TRANSFORMATION-LINK's rule assertion that were bound by SUBPROOF"
  ;; checkType: transformation-proof-p
  (let* ((transformation-link (proof-link transformation-proof))
         (subproof (transformation-proof-subproof transformation-proof))
         (supporting-subproof-bindings (if subproof (proof-bindings subproof) nil))
         (rule-bindings (compute-transformation-link-rule-bindings transformation-link
                                                                   supporting-subproof-bindings)))
    rule-bindings))

(defun compute-transformation-link-rule-bindings (transformation-link supporting-subproof-bindings)
  ;; checkType: transformation-link-p
  ;; checkType: bindings-p
  (let* ((t-link-variable-map (transformation-link-supporting-variable-map transformation-link))
         (transformation-bindings (transformation-link-bindings transformation-link))
         (subproof-bindings (transfer-variable-map-to-bindings-filtered
                             t-link-variable-map supporting-subproof-bindings))
         (final-combined-bindings (unify-transformation-and-subproof-bindings
                                   transformation-bindings subproof-bindings))
         (rule-bindings (extended-supported-problem-bindings-to-rule-bindings final-combined-bindings)))
    rule-bindings))

;; (defun transformation-proof-rule-el-bindings (transformation-proof) ...) -- active declareFunction, no body
;; (defun transformation-proof-el-bindings (transformation-proof) ...) -- active declareFunction, no body

(defun unify-transformation-and-subproof-bindings (transformation-bindings subproof-bindings)
  "[Cyc] @param TRANSFORMATION-BINDINGS; TRANSFORMATION-LINK's extended supported problem vars -> extended supported problem vars or new contents
@param SUBPROOF-BINDINGS;       TRANSFORMATION-LINK's extended supported problem vars -> old contents
This function recursively reduces all loops and dependencies between TRANSFORMATION-BINDINGS and SUBPROOF-BINDINGS
until all bindings have fully-bound values."
  (let ((combined-bindings (append subproof-bindings transformation-bindings)))
    (when (all-bindings-ground-out? combined-bindings)
      (return-from unify-transformation-and-subproof-bindings combined-bindings))
    (let* ((new-unified-bindings (unify-all-equal-bindings combined-bindings))
           (recombined-bindings (append new-unified-bindings combined-bindings))
           (final-bindings nil)
           (working-bindings nil))
      (dolist (binding recombined-bindings)
        (if (binding-ground-out? binding)
            (push binding final-bindings)
            (push binding working-bindings)))
      (setf final-bindings (nreverse final-bindings))
      (setf working-bindings (nreverse working-bindings))
      (unless final-bindings
        (error "Could not ground out ~s and ~s" transformation-bindings subproof-bindings))
      (let ((substituted-bindings (apply-bindings-to-values final-bindings working-bindings)))
        (when (and (equal transformation-bindings substituted-bindings)
                   (equal subproof-bindings final-bindings))
          (error "Could not unify transformation bindings ~a with subproof bindings ~a"
                 transformation-bindings subproof-bindings))
        (unify-transformation-and-subproof-bindings substituted-bindings final-bindings)))))

(defun extended-supported-problem-bindings-to-supported-problem-bindings
    (extended-supported-problem-bindings)
  "[Cyc] Extended supported problem bindings include both base and non-base variables;
the base variables are the variables of the supported problem and the non-base
variables are the variables of the rule assertion.  This function filters out
the non-base variables, leaving only the bindings whose variables are in the space
of the supported problem.  In other words:
@param EXTENDED-SUPPORTED-PROBLEM-BINDINGS; TRANSFORMATION-LINK's extended supported problem bindings -> content
@return         SUPPORTED-PROBLEM-BINDINGS; TRANSFORMATION-LINK's supported problem bindings -> content"
  (let ((supported-problem-bindings nil))
    (dolist (binding extended-supported-problem-bindings)
      (let ((variable (variable-binding-variable binding)))
        (when (supported-problem-variable-p variable)
          (push binding supported-problem-bindings))))
    (nreverse supported-problem-bindings)))

(defun supported-problem-variable-p (variable)
  (base-variable-p variable))

(defun extended-supported-problem-bindings-to-rule-bindings
    (extended-supported-problem-bindings)
  "[Cyc] Extended supported problem bindings include both base and non-base variables;
the base variables are the variables of the supported problem and the non-base
variables are the variables of the rule assertion.  This function filters out
the base variables, leaving only the bindings whose variables are in the space
of the rule assertion.  In other words:
@param EXTENDED-SUPPORTED-PROBLEM-BINDINGS; TRANSFORMATION-LINK's extended supported problem bindings -> content
@return                      RULE-BINDINGS; TRANSFORMATION-LINK's rule assertion bindings -> content"
  (let ((rule-bindings nil))
    (dolist (binding extended-supported-problem-bindings)
      (let ((variable (variable-binding-variable binding)))
        (when (rule-assertion-variable-p variable)
          (push binding rule-bindings))))
    (nreverse rule-bindings)))

(defun rule-assertion-variable-p (variable)
  (non-base-variable-p variable))

;; (defun rule-assertion-variable-map (bindings) ...) -- active declareFunction, no body

(defun rule-assertion-has-some-pragmatic-requirement? (rule-assertion &optional mt)
  "[Cyc] Return T iff RULE-ASSERTION has some relevant #$pragmaticRequirement in MT"
  ;; checkType: rule-assertion?
  (let ((answer nil))
    (possibly-in-mt (mt)
      (setf answer (plusp (relevant-num-pragma-rule-index rule-assertion))))
    answer))

(deflexical *forward-pragmatic-requirement-enabled?* t
  "[Cyc] Temporary control variable; whether or not #$pragmaticRequirement is enabled for forward inference.")

;; (defun backward-rule-pragmatic-dnf (rule &optional mt) ...) -- active declareFunction, no body

(defun forward-rule-pragmatic-dnf (rule propagation-mt)
  (let* ((pragmatics-mt (if (equal #$InferencePSC propagation-mt)
                            (assertion-mt rule)
                            propagation-mt))
         (pragmatic-dnf (if (and *forward-pragmatic-requirement-enabled?*
                                (rule-assertion-has-some-pragmatic-requirement? rule pragmatics-mt))
                            (rule-assertion-pragmatic-requirements-dnf rule pragmatics-mt)
                            (empty-clause))))
    pragmatic-dnf))

(defun rule-assertion-pragmatic-requirements-dnf (rule-assertion &optional mt)
  "[Cyc] Return a DNF clause expressing all the known #$pragmaticRequirements for RULE-ASSERTION in MT"
  (declare (type assertion rule-assertion))
  (let ((dnf (make-dnf nil nil)))
    (possibly-in-mt (mt)
      (when (do-pragma-rule-index-key-validator rule-assertion nil)
        (let ((iterator-var (new-pragma-rule-final-index-spec-iterator rule-assertion nil)))
          (do* ((done-var nil)
                (token-var nil))
               (done-var)
            (let* ((final-index-spec (iteration-next-without-values-macro-helper
                                      iterator-var token-var))
                   (valid (not (eq token-var final-index-spec))))
              (when valid
                (let ((final-index-iterator nil))
                  (unwind-protect
                       (progn
                         (setf final-index-iterator
                               (new-final-index-iterator final-index-spec :rule nil nil))
                         (do* ((done-var-2 nil)
                               (token-var-2 nil))
                              (done-var-2)
                           (let* ((pragma-assertion (iteration-next-without-values-macro-helper
                                                     final-index-iterator token-var-2))
                                  (valid-2 (not (eq token-var-2 pragma-assertion))))
                             (when valid-2
                               (setf dnf (merge-pragmatic-requirement rule-assertion
                                                                       pragma-assertion dnf)))
                             (setf done-var-2 (not valid-2)))))
                    (when final-index-iterator
                      (destroy-final-index-iterator final-index-iterator)))))
              (setf done-var (not valid)))))))
    dnf))

(defun merge-pragmatic-requirement (rule-assertion pragma-assertion merge-dnf)
  "[Cyc] Merge the pragmatic requirements for RULE-ASSERTION expressed in PRAGMA-ASSERTION into MERGE-DNF and return it."
  (let ((neg-lits (neg-lits merge-dnf))
        (pos-lits (pos-lits merge-dnf))
        (rule-cnf (assertion-cnf rule-assertion))
        (pragma-cnf (assertion-cnf pragma-assertion)))
    (dolist (pragmatic-lit (neg-lits pragma-cnf))
      (setf pragmatic-lit (compute-pragmatic-literal-for-merge pragmatic-lit merge-dnf rule-cnf))
      (unless (member pragmatic-lit pos-lits :test #'equal)
        (push pragmatic-lit pos-lits)))
    (dolist (pragmatic-lit (pos-lits pragma-cnf))
      (unless (el-meets-pragmatic-requirement-p pragmatic-lit)
        (setf pragmatic-lit (compute-pragmatic-literal-for-merge pragmatic-lit merge-dnf rule-cnf))
        (unless (member pragmatic-lit neg-lits :test #'equal)
          (push pragmatic-lit neg-lits))))
    (nmake-dnf neg-lits pos-lits merge-dnf)))

(defparameter *merge-dnf-lambda-var* nil)
(defparameter *rule-dnf-lambda-var* nil)

(defun compute-pragmatic-literal-for-merge (literal merge-dnf rule-dnf)
  "[Cyc] If LITERAL contains any HL variables that are not mentioned in RULE-DNF
but _are_ mentioned in MERGE-DNF, returns a new literal which is LITERAL
with those HL variables substituted with new HL variables which do not occur
in either MERGE-DNF or RULE-DNF.  Otherwise returns LITERAL."
  (let ((result literal))
    (let ((*merge-dnf-lambda-var* merge-dnf)
          (*rule-dnf-lambda-var* rule-dnf))
      (let ((conflicting-hl-var
              (expression-find-if #'hl-variable-not-mentioned-in-rule-dnf-but-mentioned-in-merge-dnf
                                  literal nil)))
        (when conflicting-hl-var
          (let ((unique-hl-var
                  ;; Likely generates a unique HL variable not in either DNF
                  (missing-larkc 8860))
                (new-literal
                  ;; Likely substitutes conflicting-hl-var with unique-hl-var in literal
                  (missing-larkc 29724)))
            (setf result (compute-pragmatic-literal-for-merge new-literal merge-dnf rule-dnf))))))
    result))

(defun hl-variable-not-mentioned-in-rule-dnf-but-mentioned-in-merge-dnf (object)
  (and (hl-variable-p object)
       (not (expression-find object *rule-dnf-lambda-var* nil))
       (expression-find object *merge-dnf-lambda-var* nil)))

(defun bubble-up-proof-to-transformation-link (supporting-proof variable-map transformation-link)
  ;; checkType: problem-link-with-single-supporting-problem-p
  (multiple-value-bind (proof new?)
      (new-transformation-proof transformation-link supporting-proof variable-map)
    (if new?
        (bubble-up-proof proof)
        (possibly-note-proof-processed supporting-proof))
    proof))

(defun-memoized transformation-proof-abnormal? (transformation-proof) (:test eq)
  (transformation-proof-abnormal-int? transformation-proof))

(defun transformation-proof-abnormal-int? (transformation-proof)
  ;; checkType: transformation-proof-p
  (let* ((link (proof-link transformation-proof))
         (store (problem-link-store link))
         (rule (transformation-link-rule-assertion link))
         (transformation-mt (transformation-link-transformation-mt link))
         (rule-bindings (transformation-proof-rule-bindings transformation-proof)))
    (rule-bindings-abnormal? store rule rule-bindings transformation-mt)))

(defun proof-depends-on-excepted-assertion? (proof)
  (supports-contain-excepted-assertion? (proof-supports proof)))

(defun supports-contain-excepted-assertion? (supports)
  (dolist (support supports)
    (when (and (assertion-p support)
               (inference-excepted-assertion? support))
      (return-from supports-contain-excepted-assertion? t)))
  nil)

(defun supports-contain-excepted-assertion-in-mt? (supports mt)
  (let ((result nil))
    (with-inference-mt-relevance mt
      (setf result (supports-contain-excepted-assertion? supports)))
    result))

;; (defun inference-backchain-forbidden-unless-arg-chosen-argnums (predicate mt) ...) -- active declareFunction, no body
;; (defun inference-backchain-forbidden-unless-arg-chosen-argnums-memoized-internal (predicate mt) ...) -- active declareFunction, no body
;; (defun inference-backchain-forbidden-unless-arg-chosen-argnums-memoized (predicate mt) ...) -- active declareFunction, no body
;; (defun inference-backchain-forbidden-unless-arg-chosen-asent? (asent mt) ...) -- active declareFunction, no body
;; (defun inference-backchain-forbidden-unless-arg-chosen-asent-variables (asent mt) ...) -- active declareFunction, no body
;; (defun inference-backchain-forbidden-unless-arg-chosen-asent-variables-int (asent mt argnums) ...) -- active declareFunction, no body

(defvar *genl-rules-enabled?* t
  "[Cyc] Temporary control variable; when non-nil #$genlRules is used to filter the
use of overly specific rules in transformation when a more general rule
is also applicable.  Eventually should stay T.")

(defun genl-rules-enabled? ()
  *genl-rules-enabled?*)

;; (defun genl-rules (rule &optional mt) ...) -- active declareFunction, no body

(defun max-rules (rules &optional mt)
  "[Cyc] Returns the most-general rules (via #$genlRules) among RULES,
which are those rules that have no proper genlRule among RULES."
  (unless (valid-constant? #$genlRules)
    (return-from max-rules rules))
  (gt-max-nodes #$genlRules rules mt))

;;; Setup forms

(toplevel (declare-defglobal '*determine-new-transformation-tactics-module*))
(toplevel (note-memoized-function 'memoized-inference-excepted-assertion?))
(toplevel (note-memoized-function 'transformation-proof-abnormal?))
(toplevel (note-memoized-function 'inference-backchain-forbidden-unless-arg-chosen-argnums-memoized))
