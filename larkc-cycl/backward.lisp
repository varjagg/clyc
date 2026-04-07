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

(defparameter *removal-add-node-method* nil
  "[Cyc] When non-nil, the implementation to funcall inside REMOVAL-ADD-NODE.")

(defparameter *transformation-add-node-method* nil
  "[Cyc] When non-nil, the implementation to funcall inside TRANSFORMATION-ADD-NODE.")

(defparameter *transformation-early-removal-threshold* 8
  "[Cyc] If any non-backchain literals exist in the transformation layer,
and they have an estimated removal cost less than this, force these
removals to be done first.
Since the productivity of join-ordered links is doubled, this is equal to DOUBLE
the number of children that the focal problem can have and still be considered for early removal.
NIL means never perform early removals.
T means always perform early removals first.")

(defparameter *inference-expand-new-children* nil
  "[Cyc] Bound by INFERENCE-EXPAND-INTERNAL")

(defparameter *inference-expand-hl-module* nil
  "[Cyc] Bound by INFERENCE-EXPAND-INTERNAL")

(defparameter *inference-expand-sense* nil
  "[Cyc] Bound by INFERENCE-EXPAND-INTERNAL")

(deflexical *removal-ask-query-properties* '(:max-number
                                             :allowed-modules
                                             :metrics
                                             :allow-abnormality-checking?
                                             :allow-indeterminate-results?))

(defparameter *removal-ask-answers* nil
  "[Cyc] An #'equal dictionary-contents mapping bindings to a list of justifications of those bindings.")

(defparameter *removal-ask-max-number* nil)

(defparameter *removal-ask-disallows-indeterminate-terms?* nil)

(defparameter *removal-ask-first-answer-elapsed-internal-real-time* nil)

(defparameter *removal-ask-last-answer-elapsed-internal-real-time* nil)

(defparameter *removal-ask-start-internal-real-time* nil)

(defparameter *transformation-semantic-pruning-enabled* nil
  "[Cyc] Do we enable the transformation-layer semantic pruning heuristics?")

(defvar *forward-inference-pruning-mode* :legacy)

(defvar *forward-asserted-sentence-pruning-enabled?* t
  "[Cyc] temporary control parameter; @todo eliminate")

(deflexical *literal-set-sense-table* '((:no-pos . :pos)
                                        (:no-neg . :neg)
                                        (:yes-pos . :pos)
                                        (:yes-neg . :neg)))

;;; Functions — ordered per declare section

;; (defun inference-expand-new-children () ...) -- active declareFunction, no body

;; (defun add-to-inference-expand-new-children (child) ...) -- active declareFunction, no body

(defun inference-expand-hl-module ()
  "[Cyc] Returns the current HL module being used during inference expansion."
  *inference-expand-hl-module*)

(defun inference-expand-sense ()
  "[Cyc] Returns the current sense being used during inference expansion."
  *inference-expand-sense*)

(defun transformation-add-node (rule-assertion rule-pivot-asent rule-pivot-sense v-bindings &optional more-supports)
  "[Cyc] @param RULE-PIVOT-ASENT; the asent from RULE-ASSERTION that was used in the transformation.
Computes information for a new link object and a new child node,
creates them, performs unification, and does a bunch of bookkeeping.
If you have (and (p x) (q x)) -> (or (r x) (s x)) and you backchain on (r a),
then the rule-assertion will be (and (p x) (q x)) -> (or (r x) (s x)),
the bindings will be (((x . a))), the new-pos-lits will be ((p a) (q a)), the new-neg-lits
will be ((s a)), more-supports will be, like, an additional genlPreds support if it used one,
no-trans-pos-lits and no-trans-neg-lits will both always be NIL.  Currently no transformation
modules pass these in."
  (when (null v-bindings)
    (setf v-bindings (unification-success-token)))
  (let ((no-trans-pos-lits nil)
        (no-trans-neg-lits nil))
    (multiple-value-bind (new-pos-lits new-neg-lits)
        (transformation-rule-dependent-lits rule-assertion rule-pivot-asent rule-pivot-sense)
      (if *transformation-add-node-method*
          (let ((dependent-dnf (make-clause (append new-neg-lits no-trans-neg-lits)
                                            (append new-pos-lits no-trans-pos-lits))))
            (funcall *transformation-add-node-method*
                     rule-assertion rule-pivot-asent rule-pivot-sense
                     v-bindings dependent-dnf more-supports))
          (error "The legacy harness is no longer supported.")))))

(defun transformation-rule-dependent-lits (rule asent-from-rule asent-sense)
  "[Cyc] @return 0 new-pos-lits
@return 1 new-neg-lits"
  (let ((cnf (assertion-cnf rule)))
    (if (eq :pos asent-sense)
        (values (neg-lits cnf)
                (remove asent-from-rule (pos-lits cnf)))
        (values (remove asent-from-rule (neg-lits cnf))
                (pos-lits cnf)))))

(defun removal-add-node (support &optional v-bindings more-supports)
  "[Cyc] Adds a removal node with the given support, bindings, and additional supports."
  (when (null v-bindings)
    (setf v-bindings (unification-success-token)))
  (when (null *removal-add-node-method*)
    (error "The legacy harness is no longer supported."))
  (removal-add-node-funcall *removal-add-node-method*
                            v-bindings
                            (cons support more-supports)))

(defun removal-add-node-funcall (function v-bindings supports)
  "[Cyc] Dispatches to the appropriate removal add-node handler based on FUNCTION."
  (cond
    ((eql function 'handle-removal-add-node-for-output-generate)
     (handle-removal-add-node-for-output-generate v-bindings supports))
    ((eql function 'handle-removal-add-node-for-expand-results)
     (handle-removal-add-node-for-expand-results v-bindings supports))
    ((eql function 'removal-ask-add-node)
     (removal-ask-add-node v-bindings supports))
    (t
     (funcall *removal-add-node-method* v-bindings supports))))

(defun removal-ask-query-property-p (object)
  "[Cyc] Returns whether OBJECT is a valid removal-ask query property."
  (member-eq? object *removal-ask-query-properties*))

(defun removal-ask (asent &optional mt (truth :true) query-properties)
  "[Cyc] Perform an exhaustive removal-only ask of HL-level ASENT in MT.
If MT is NIL, *default-ask-mt* is used.
TRUTH indicates the truth of asent, either :TRUE or :FALSE.
@return 0 ; a list of tuples of the form : (bindings hl-supports)
@return 1 ; query-halt-reason-p
@return 2 ; metrics values, if :metrics specified in QUERY-PROPERTIES"
  (when (null mt)
    (setf mt *default-ask-mt*))
  (let ((answers nil)
        (halt-reason nil)
        (metrics nil))
    (let ((*removal-add-node-method* 'removal-ask-add-node)
          (*controlling-inferences* (cons nil *controlling-inferences*))
          (*controlling-strategy* nil))
      (let ((mt-var (with-inference-mt-relevance-validate mt)))
        (let ((*mt* (update-inference-mt-relevance-mt mt-var))
              (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
              (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
          (multiple-value-setq (answers halt-reason metrics)
            (removal-ask-int asent truth query-properties)))))
    (values answers halt-reason metrics)))

;; (defun el-removal-ask (asent &optional mt (truth :true) query-properties) ...) -- active declareFunction, no body

;; (defun removal-ask-bindings (asent &optional mt (truth :true) query-properties) ...) -- active declareFunction, no body

;; (defun el-removal-ask-bindings (asent &optional mt (truth :true) query-properties) ...) -- active declareFunction, no body

;; (defun removal-ask-justifications (asent &optional mt (truth :true) query-properties) ...) -- active declareFunction, no body

;; (defun el-removal-ask-justifications (asent &optional mt (truth :true) query-properties) ...) -- active declareFunction, no body

;; (defun removal-ask-template (template asent &optional mt (truth :true) query-properties) ...) -- active declareFunction, no body

;; (defun el-removal-ask-template (template asent &optional mt (truth :true) query-properties) ...) -- active declareFunction, no body

;; (defun el-removal-ask-variable (variable asent &optional mt (truth :true) query-properties) ...) -- active declareFunction, no body

;; (defun removal-ask-variable (variable asent &optional mt (truth :true) query-properties) ...) -- active declareFunction, no body

;; (defun removal-ask-hl-variable (variable asent &optional mt (truth :true) query-properties) ...) -- active declareFunction, no body

;; (defun removal-ask-answer-count () ...) -- active declareFunction, no body

(defun removal-ask-add-node (v-bindings supports)
  "[Cyc] Adds a removal-ask answer, tracking bindings and justifications."
  (when (and *removal-ask-disallows-indeterminate-terms?*
             ;; missing-larkc 35566 likely checks if bindings contain indeterminate terms
             ;; (variables that couldn't be fully resolved), returning T if so
             (missing-larkc 35566))
    (return-from removal-ask-add-node nil))
  (when (dictionary-contents-empty-p *removal-ask-answers*)
    (when *removal-ask-start-internal-real-time*
      (setf *removal-ask-first-answer-elapsed-internal-real-time*
            (elapsed-internal-real-time *removal-ask-start-internal-real-time*))))
  (when *removal-ask-start-internal-real-time*
    (setf *removal-ask-last-answer-elapsed-internal-real-time*
          (elapsed-internal-real-time *removal-ask-start-internal-real-time*)))
  (setf *removal-ask-answers*
        (dictionary-contents-push *removal-ask-answers*
                                  (copy-tree v-bindings)
                                  (copy-tree supports)
                                  #'equal))
  (when (and *removal-ask-max-number*
             ;; missing-larkc 31658 likely returns the current answer count from
             ;; *removal-ask-answers*, used to check if we've reached the max
             (>= (missing-larkc 31658)
                  *removal-ask-max-number*))
    ;; missing-larkc 31657 likely signals :removal-ask-done to halt the ask loop
    (missing-larkc 31657))
  nil)

(defun removal-ask-int (asent truth &optional query-properties)
  "[Cyc] Internal implementation of removal-ask."
  (let ((sense (truth-sense truth))
        (allowed-modules-spec (getf query-properties :allowed-modules :all)))
    (let ((allowed-tactic-specs (removal-ask-tactic-specs asent sense allowed-modules-spec)))
      (if allowed-tactic-specs
          (removal-ask-expand asent sense allowed-tactic-specs query-properties)
          (values nil :exhaust-total nil)))))

(defun removal-ask-tactic-specs (asent sense allowed-modules-spec)
  "[Cyc] Returns the tactic specs for a removal ask of ASENT with SENSE."
  (literal-removal-options asent sense allowed-modules-spec))

(defun removal-ask-expand (asent sense tactic-specs query-properties)
  "[Cyc] Expands tactic specs for a removal ask, collecting answers."
  (let ((answers nil)
        (halt-reason nil)
        (metric-values nil))
    (setf tactic-specs (sort (copy-list tactic-specs) #'< :key #'second))
    (let ((metrics (getf query-properties :metrics nil)))
      (let ((*removal-ask-answers* (new-dictionary-contents 0 #'equal))
            (*removal-ask-max-number* (getf query-properties :max-number nil))
            (*removal-ask-disallows-indeterminate-terms?*
              (not (getf query-properties :allow-indeterminate-results? t)))
            (*removal-ask-start-internal-real-time*
              (if metrics (get-internal-real-time) nil))
            (*removal-ask-first-answer-elapsed-internal-real-time* nil)
            (*removal-ask-last-answer-elapsed-internal-real-time* nil))
        (when (null halt-reason)
          (dolist (tactic-spec tactic-specs)
            (when halt-reason
              (return))
            (setf halt-reason
                  (catch :removal-ask-done
                    (destructuring-bind (hl-module productivity completeness) tactic-spec
                      (let ((cost (cost-for-productivity productivity)))
                        (let ((*inference-expand-hl-module* hl-module))
                          (let ((pattern (hl-module-expand-pattern hl-module))
                                (expand-method (if (null (hl-module-expand-pattern hl-module))
                                                   (hl-module-expand-func hl-module)
                                                   nil)))
                            (unless (inference-hl-module-cost-too-expensive hl-module cost)
                              (let ((*inference-expand-sense* sense))
                                (if pattern
                                    (pattern-transform-formula pattern asent)
                                    (funcall expand-method asent sense))))))))
                    nil))))
        (let ((allow-abnormality-checking?
                (inference-properties-allow-abnormality-checking? query-properties)))
          (do-dictionary-contents (v-bindings justifications *removal-ask-answers*)
            (dolist (justification justifications)
              (unless (and allow-abnormality-checking?
                          (abnormality-except-support-enabled?)
                          (supports-contain-excepted-assertion? justification))
                (push (list v-bindings justification) answers)))))
        (when (null halt-reason)
          (setf halt-reason :exhaust-total))
        (when metrics
          ;; missing-larkc 31661 likely computes metric values from the metrics spec,
          ;; returning values for :answer-count, :time-to-first-answer, etc.
          (setf metric-values (missing-larkc 31661)))))
    (values (nreverse answers) halt-reason metric-values)))

;; (defun removal-ask-compute-metric-values (metrics) ...) -- active declareFunction, no body

;; (defun note-removal-ask-done (halt-reason) ...) -- active declareFunction, no body

(defun inference-hl-module-cost-too-expensive (hl-module cost)
  "[Cyc] Returns whether the cost of HL-MODULE exceeds the removal cost cutoff."
  (case (hl-module-type hl-module)
    (:removal (and *removal-cost-cutoff*
                   (> cost *removal-cost-cutoff*)))
    (otherwise nil)))

;; (defun closed-conjunctive-cycl-sentence-p (sentence) ...) -- active declareFunction, no body

;; (defun cycl-literal-or-conjunction-of-cycl-literals-p (sentence) ...) -- active declareFunction, no body

;; (defun closed-conjunctive-removal-ask (sentence &optional mt query-properties) ...) -- active declareFunction, no body

;; (defun removal-ask-literal (asent sense query-properties) ...) -- active declareFunction, no body

(defun inference-semantically-valid-dnf (dnf &optional mt)
  "[Cyc] Returns whether DNF is semantically valid, checking term-of-unit and closed asents."
  (and (semantically-valid-term-of-unit-asents dnf mt)
       (semantically-valid-closed-asents? dnf mt)))

(defun semantically-valid-closed-asents? (dnf &optional mt)
  "[Cyc] Returns whether the closed asents in DNF are semantically valid."
  (case *forward-inference-pruning-mode*
    (:none t)
    (:legacy (and (semantically-valid-asserted-sentence-asents dnf mt)
                  (semantically-valid-complete-extent-asserted-asents dnf mt)
                  (semantically-valid-isa-asents dnf mt)
                  (semantically-valid-genls-asents dnf mt)))
    (:trivial
     ;; missing-larkc 31664 likely does trivial semantic pruning checks
     (missing-larkc 31664))
    (:inference
     ;; missing-larkc 31665 likely does full inference-level semantic pruning checks
     (missing-larkc 31665))
    (otherwise
     (error "Unexpected pruning mode : ~S" *forward-inference-pruning-mode*))))

;; (defun semantically-valid-closed-asents?-int (dnf mt pruning-mode) ...) -- active declareFunction, no body

(defun semantically-valid-asserted-sentence-asents (dnf &optional mt)
  "[Cyc] Returns whether assertedSentence asents in DNF are semantically valid."
  (let ((invalid? nil))
    (when *forward-asserted-sentence-pruning-enabled?*
      (let ((pos-lits (pos-lits dnf)))
        (when (find #$assertedSentence pos-lits :test #'eql :key #'atomic-sentence-predicate)
          (let ((mt-var mt))
            (let ((*mt* (update-inference-mt-relevance-mt mt-var))
                  (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
                  (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
              (dolist (asent pos-lits)
                (when invalid? (return))
                (when (eq #$assertedSentence (atomic-sentence-predicate asent))
                  (when (semantically-invalid-asserted-sentence-asent asent)
                    (setf invalid? t)))))))))
    (not invalid?)))

(defun forward-complete-extent-asserted-pruning-enabled? ()
  "[Cyc] Returns whether forward complete-extent-asserted pruning is enabled."
  (balancing-tactician-enabled?))

(defun semantically-valid-complete-extent-asserted-asents (dnf &optional mt)
  "[Cyc] Returns whether complete-extent-asserted asents in DNF are semantically valid."
  (let ((invalid? nil))
    (when (forward-complete-extent-asserted-pruning-enabled?)
      (let ((pos-lits (pos-lits dnf))
            (mt-var mt))
        (let ((*mt* (update-inference-mt-relevance-mt mt-var))
              (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
              (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
          (dolist (asent pos-lits)
            (when invalid? (return))
            (let ((pred (atomic-sentence-predicate asent)))
              (when (and (fort-p pred)
                         ;; missing-larkc 6840 likely checks if pred has complete-extent-asserted
                         ;; (i.e., all instances are asserted, not derived), probably
                         ;; complete-extent-asserted-for-value-in-arg
                         (missing-larkc 6840))
                (when (non-asserted-asent? asent)
                  (setf invalid? t))))))))
    (not invalid?)))

(defun semantically-invalid-asserted-sentence-asent (asent)
  "[Cyc] Returns whether an assertedSentence asent is semantically invalid."
  (let ((sentence (atomic-sentence-arg1 asent)))
    (non-asserted-asent? sentence)))

(defun non-asserted-asent? (sentence)
  "[Cyc] Returns whether SENTENCE is a non-asserted asent."
  (when (el-formula-p sentence)
    (when (forward-complete-extent-asserted-pruning-enabled?)
      ;; missing-larkc 31656 likely checks whether the sentence's predicate has
      ;; complete-extent-asserted, returning T if so — meaning all extensions
      ;; should be asserted, and if this asent is not found asserted, it's invalid
      (when (missing-larkc 31656)
        (return-from non-asserted-asent? t)))
    (when (non-asserted-asent-via-gaf-lookup? sentence)
      (return-from non-asserted-asent? t)))
  nil)

;; (defun non-asserted-asent-via-somewhere-cache? (sentence) ...) -- active declareFunction, no body

(defun non-asserted-asent-via-gaf-lookup? (sentence)
  "[Cyc] Returns whether SENTENCE is a non-asserted asent based on GAF lookup."
  (when (forward-complete-extent-asserted-pruning-enabled?)
    ;; missing-larkc 12703 likely looks up the sentence in the somewhere cache,
    ;; returning NIL if the predicate is not somewhere-cached (meaning we can't
    ;; be sure it's not asserted). null of that = T means it IS somewhere-cached
    ;; but not found, so it's non-asserted.
    (return-from non-asserted-asent-via-gaf-lookup?
      (null (missing-larkc 12703))))
  (when (and (fully-bound-p sentence)
             (null (find-gaf-in-relevant-mt sentence)))
    (return-from non-asserted-asent-via-gaf-lookup? t))
  nil)

(defun semantically-valid-isa-asents (dnf &optional mt)
  "[Cyc] Returns whether the #$isa asents in DNF are semantically valid."
  (let ((pos-lits (pos-lits dnf)))
    (when (find #$isa pos-lits :test #'eql :key #'atomic-sentence-predicate)
      (dolist (asent pos-lits)
        (when (eq #$isa (atomic-sentence-predicate asent))
          (let ((arg1 (atomic-sentence-arg1 asent))
                (arg2 (atomic-sentence-arg2 asent)))
            (when (and (fort-p arg1)
                       (fort-p arg2))
              (unless (quiet-has-type-memoized? arg1 arg2 mt)
                (return-from semantically-valid-isa-asents nil))))))))
  t)

(defun semantically-valid-genls-asents (dnf &optional mt)
  "[Cyc] Returns whether the #$genls asents in DNF are semantically valid."
  (let ((pos-lits (pos-lits dnf)))
    (when (find #$genls pos-lits :test #'eql :key #'atomic-sentence-predicate)
      (dolist (asent pos-lits)
        (when (eq #$genls (atomic-sentence-predicate asent))
          (let ((arg1 (atomic-sentence-arg1 asent))
                (arg2 (atomic-sentence-arg2 asent)))
            (when (and (fort-p arg1)
                       (fort-p arg2))
              (unless (genls? arg1 arg2 mt)
                (return-from semantically-valid-genls-asents nil))))))))
  t)

(defun semantically-valid-term-of-unit-asents (dnf &optional mt)
  "[Cyc] Returns whether the #$termOfUnit asents in DNF are semantically valid."
  (declare (ignore mt))
  (syntactically-valid-term-of-unit-asents dnf))

(defun syntactically-valid-term-of-unit-asents (dnf)
  "[Cyc] Returns whether the #$termOfUnit asents in DNF are syntactically valid."
  (dolist (asent (pos-lits dnf))
    (when (atomic-sentence-with-pred-p asent #$termOfUnit)
      ;; missing-larkc 31666 likely validates the term-of-unit asent syntactically,
      ;; checking that arg1 is a variable and arg2 is a NAT/NAUT — returning NIL
      ;; if invalid
      (unless (missing-larkc 31666)
        (return-from syntactically-valid-term-of-unit-asents nil))))
  t)

;; (defun valid-term-of-unit-arg1 (asent) ...) -- active declareFunction, no body

;; (defun valid-term-of-unit-arg2 (asent) ...) -- active declareFunction, no body

;; (defun valid-term-of-unit-args (arg1 arg2) ...) -- active declareFunction, no body

;; (defun valid-term-of-unit-inter-args (arg1 arg2) ...) -- active declareFunction, no body

;; (defun syntactically-valid-term-of-unit-asent (asent) ...) -- active declareFunction, no body

;; (defun literal-set-sense (literal-set) ...) -- active declareFunction, no body

;; (defun literal-set-without (literal-set literal) ...) -- active declareFunction, no body

;;; Setup

(toplevel
  (register-external-symbol 'removal-ask)
  (declare-control-parameter-internal
   '*transformation-semantic-pruning-enabled*
   "Semantic pruning of results of backchaining"
   "This controls whether or not the intermediate results of backchaining
are examined to see if they are provably unsatisfiable.  If so, these
results are pruned from the search.  This test takes time, but usually
provides substantial pruning of the search tree when backchaining."
   '((:value t "Yes") (:value nil "No"))))
