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

(defparameter *require-cached-gaf-mt-from-supports* nil
  "[Cyc] Whether forward inference requires that a computed placement mt for
a forward deduction be the mt of one of its supports.")

(defvar *forward-inference-browsing-callback* nil
  "[Cyc] A function-spec-p to call on each browsable forward inference.
It will be passed an inference-p as its arg1 (the forward inference object)
and a rule-assertion? as its arg2 (the forward rule being used).")

(defparameter *forward-inference-browsing-callback-more-info?* nil
  "[Cyc] Optionally, store more info about each forward inference by passing it to the callback.  Additions are stored in a plist and are: target-asent target-truth trigger-bindings trigger-supports forward-results.  @see forward-propagate-dnf.")

(defvar *block-forward-inferences?* nil
  "[Cyc] Variable for debugging")

(defparameter *tracing-forward-inference* nil)

(defun current-forward-inference-environment ()
  *forward-inference-environment*)

(defun get-forward-inference-environment ()
  (new-forward-inference-environment))

;; (defun free-forward-inference-enviornment (environment) ...) -- active declareFunction, no body

(defun clear-forward-inference-environment (environment)
  (clear-queue environment))

(defun new-forward-inference-environment ()
  (create-queue))

(defun initialize-forward-inference-environment ()
  "[Cyc] Initialize global forward inference environment."
  (setf *forward-inference-environment* (get-forward-inference-environment))
  nil)

;; Reconstructed from Internal Constants:
;; $list0 = (GAF &BODY BODY), $sym1$CLET, $sym2$*FORWARD-INFERENCE-GAF*
;; Expansion visible in forward-propagate-gaf: *forward-inference-gaf* bound to source-gaf-assertion
(defmacro with-forward-inference-gaf ((gaf) &body body)
  `(clet ((*forward-inference-gaf* ,gaf))
     ,@body))

(defparameter *forward-inference-gaf* nil)

;; Reconstructed from Internal Constants:
;; $list3 = (RULE &BODY BODY), $sym1$CLET, $sym4$*FORWARD-INFERENCE-RULE*
;; Expansion visible in forward-propagate-rule and forward-propagate-gaf-internal
(defmacro with-forward-inference-rule ((rule) &body body)
  `(clet ((*forward-inference-rule* ,rule))
     ,@body))

(defparameter *forward-inference-rule* nil)

;; (defun current-forward-inference-gaf () ...) -- active declareFunction, no body

(defun current-forward-inference-rule ()
  *forward-inference-rule*)

;; (defun current-forward-inference-assertion () ...) -- active declareFunction, no body

(deflexical *forward-problem-store-properties*
  (list :transformation-allowed? nil
        :intermediate-step-validation-level :none
        :negation-by-failure? nil
        :add-restriction-layer-of-indirection? t
        :direction :forward)
  "[Cyc] Problem store properties assumed by forward inference.")

(defun new-forward-problem-store ()
  "[Cyc] @return problem-store-p ; a new problem-store suitable for forward inference."
  (increment-forward-problem-store-historical-count)
  (new-problem-store *forward-problem-store-properties*))

(defun destroy-forward-problem-store (store)
  (update-forward-problem-historical-count store)
  (update-maximum-forward-problem-store-historical-problem-count store)
  (destroy-problem-store store))

(defparameter *forward-inference-shares-same-problem-store?* t
  "[Cyc] temp control variable")

(defun forward-inference-shares-same-problem-store? ()
  *forward-inference-shares-same-problem-store?*)

(defun get-forward-problem-store ()
  (let ((store (if (forward-inference-shares-same-problem-store?)
                   *current-forward-problem-store*
                   nil)))
    (when (null store)
      (setf store (new-forward-problem-store))
      (when (forward-inference-shares-same-problem-store?)
        (setf *current-forward-problem-store* store)))
    store))

(defun clear-current-forward-problem-store ()
  "[Cyc] Clear and destroy the current forward problem store (if any)"
  (when *current-forward-problem-store*
    (unwind-protect
         (unless (browse-forward-inferences?)
           (destroy-forward-problem-store *current-forward-problem-store*))
      (setf *current-forward-problem-store* nil)))
  nil)

(defun clear-current-forward-inference-environment ()
  (clear-forward-inference-environment (current-forward-inference-environment)))

(defun queue-forward-assertion (assertion)
  (declare (type assertion-p assertion))
  (when *forward-inference-enabled?*
    (let ((environment (current-forward-inference-environment)))
      (enqueue assertion environment))
    (when *tracing-forward-inference*
      (format t "~%~S" assertion)))
  assertion)

(defun remqueue-forward-assertion (assertion)
  (declare (type assertion-p assertion))
  (let ((environment (current-forward-inference-environment)))
    (when environment
      (remqueue assertion environment))))

(defparameter *forward-inference-recursion-depth* 0)

(defun perform-forward-inference ()
  "[Cyc] Exhaustively complete all pending forward inference"
  (let ((result nil))
    (when *forward-inference-enabled?*
      (let ((environment (current-forward-inference-environment)))
        (let ((*current-forward-problem-store* nil))
          (unwind-protect
               (let ((*forward-inference-recursion-depth*
                       (1+ *forward-inference-recursion-depth*)))
                 (when (and *inference-debug?*
                            (>= *forward-inference-recursion-depth* 20))
                   (break "Forward inference recursion problem? depth = ~S"
                          *forward-inference-recursion-depth*))
                 (loop until (queue-empty-p environment) do
                   (let* ((assertion (dequeue environment))
                          (some-results (forward-propagate-assertion assertion)))
                     (setf result (nconc (nreverse some-results) result)))))
            (clear-current-forward-problem-store)))))
    (nreverse result)))

;; (defun repropagate-forward-assertion (assertion) ...) -- active declareFunction, no body

(defparameter *forward-inference-assertibles-queue* nil
  "[Cyc] The queue of new assertibles (hl-assertible-p) computed during one forward theory revision cycle.")

(defun forward-inference-assertibles-queue ()
  *forward-inference-assertibles-queue*)

(defun note-new-forward-assertible (hl-assertible)
  (enqueue hl-assertible *forward-inference-assertibles-queue*)
  nil)

(defun forward-propagate-assertion (assertion &optional (propagation-mt #$InferencePSC))
  "[Cyc] @note When *current-forward-problem-store* is NIL, this function will set it as a side-effect (to support forward problem store reuse.)  This can be very bad if it's not dynamically bound as a global forward problem store will exist, quickly become stale, and cause incorrectness.  Be safe and wrap rogue calls to forward-propagate-assertion with the with-normal-forward-inference macro (or at least with-clean-forward-problem-store-environment if you're tweaking forward inference behavior.)"
  (let ((assertibles nil))
    (when (and *forward-inference-enabled?*
               (valid-assertion assertion))
      (unless (and (equal #$InferencePSC propagation-mt)
                   (not (forward-assertion? assertion)))
        (let ((store-var (get-forward-problem-store)))
          (with-problem-store-memoization-state (store-var)
            (let* ((space-var (problem-store-sbhl-resource-space store-var))
                   (*resourced-sbhl-marking-spaces* space-var)
                   (*resourcing-sbhl-marking-spaces-p* t)
                   (*resourced-sbhl-marking-space-limit*
                     (determine-marking-space-limit *resourced-sbhl-marking-spaces*)))
              (let ((*within-forward-inference?* t)
                    (*recursive-ist-justifications?* nil)
                    (*forward-inference-assertibles-queue* (create-queue)))
                (if (gaf-assertion? assertion)
                    (forward-propagate-gaf assertion propagation-mt)
                    (forward-propagate-rule assertion propagation-mt))
                (unless (queue-empty-p (forward-inference-assertibles-queue))
                  (unless (or *within-assertion-forward-propagation?*
                              *prefer-forward-skolemization*)
                    (clear-current-forward-problem-store))
                  (let ((*current-forward-problem-store* nil))
                    (unwind-protect
                         (let ((*within-assertion-forward-propagation?* nil)
                               (*prefer-forward-skolemization* nil))
                           (let ((done? nil)
                                 (rest nil))
                             (do* ((rest (do-queue-elements-queue-elements
                                         (forward-inference-assertibles-queue))
                                        (cdr rest)))
                                  ((or done? (null rest)))
                               (let ((hl-assertible (car rest)))
                                 (if (invalid-assertion? assertion)
                                     (progn
                                       (warn "~s was removed by its own forward propagation"
                                             assertion)
                                       (setf done? t))
                                     (let* ((hl-assertible-var hl-assertible)
                                            (argument-spec (hl-assertible-argument-spec hl-assertible-var))
                                            (hl-assertion-spec-var (hl-assertible-hl-assertion-spec hl-assertible-var))
                                            (cnf (hl-assertion-spec-cnf hl-assertion-spec-var))
                                            (mt (hl-assertion-spec-mt hl-assertion-spec-var))
                                            (direction (hl-assertion-spec-direction hl-assertion-spec-var))
                                            (variable-map (hl-assertion-spec-variable-map hl-assertion-spec-var)))
                                       (declare (ignore cnf mt direction variable-map))
                                       (if (tree-find-if #'invalid-assertion? argument-spec)
                                           (warn "invalid hl-assertible ~s encountered during forward inference")
                                           (let ((*within-forward-inference?* nil))
                                             (let ((var (hl-add-assertible hl-assertible)))
                                               (when var
                                                 (push var assertibles)))))))))))
                      (clear-current-forward-problem-store)))))
              (setf space-var *resourced-sbhl-marking-spaces*)
              (set-problem-store-sbhl-resource-space store-var space-var))))))
    (nreverse assertibles)))

(defun forward-propagate-rule (rule propagation-mt)
  (let ((*forward-inference-rule* rule))
    (let* ((rule-cnf (assertion-cnf rule))
           (pragmatic-dnf (forward-rule-pragmatic-dnf rule propagation-mt)))
      (handle-forward-propagation rule-cnf pragmatic-dnf propagation-mt nil rule nil)))
  nil)

(defun forward-propagate-gaf (source-gaf-assertion propagation-mt)
  (let ((*forward-inference-gaf* source-gaf-assertion))
    (let* ((source-sense (truth-sense (assertion-truth source-gaf-assertion))))
      (when (or (eq :pos source-sense)
                *forward-propagate-from-negations*)
        (let ((source-asent (copy-tree (gaf-formula source-gaf-assertion))))
          (let ((*relax-type-restrictions-for-nats*
                  (or *relax-type-restrictions-for-nats*
                      (tou-asent? source-asent))))
            (forward-propagate-gaf-expansions source-asent source-sense propagation-mt source-gaf-assertion))))))
  nil)

(defun forward-propagate-gaf-expansions (source-asent source-sense propagation-mt source-gaf-assertion)
  (dolist (forward-tactic-spec (forward-tactic-specs source-asent source-sense propagation-mt))
    (destructuring-bind (trigger-asent trigger-sense examine-asent examine-sense rule
                         &optional additional-supports)
        forward-tactic-spec
      (declare (ignore trigger-sense))
      (when (or (eq :neg examine-sense)
                *forward-propagate-from-negations*)
        (let ((trigger-supports (make-forward-trigger-supports source-gaf-assertion additional-supports)))
          (forward-propagate-gaf-internal trigger-asent examine-asent examine-sense propagation-mt rule trigger-supports)))))
  nil)

(defun make-forward-trigger-supports (source-gaf-assertion additional-supports)
  (let ((trigger-supports (copy-list additional-supports)))
    (when source-gaf-assertion
      (setf trigger-supports (cons source-gaf-assertion trigger-supports)))
    trigger-supports))

(defparameter *type-filter-forward-dnf* t
  "[Cyc] Should we bother to type-filter a prospective forward DNF.")

(defun forward-inference-allowed-rules ()
  *forward-inference-allowed-rules*)

(defun forward-inference-all-rules-allowed? ()
  (eq *forward-inference-allowed-rules* :all))

(defun forward-inference-rule-allowed? (rule)
  (or (forward-inference-all-rules-allowed?)
      (member-eq? rule *forward-inference-allowed-rules*)))

(defun forward-propagate-gaf-internal (trigger-asent examine-asent examine-sense propagation-mt rule trigger-supports)
  (when (not (forward-inference-rule-allowed? rule))
    (return-from forward-propagate-gaf-internal nil))
  (let ((*forward-inference-rule* rule))
    (let* ((cnf (assertion-cnf rule))
           (pos-lits (pos-lits cnf))
           (neg-lits (neg-lits cnf))
           (examine-lits (if (eq :pos examine-sense) pos-lits neg-lits))
           (other-lits (if (eq :pos examine-sense) neg-lits pos-lits))
           (pragmatic-dnf (forward-rule-pragmatic-dnf rule propagation-mt)))
      (when (or (equal (atomic-sentence-predicate trigger-asent)
                       (atomic-sentence-predicate examine-asent))
                (and (unbound-predicate-literal examine-asent)
                     ;; Likely checks if the unbound predicate can be unified with the trigger
                     (missing-larkc 30637)))
        (multiple-value-bind (trigger-bindings gaf-asent unify-justification)
            (gaf-asent-unify trigger-asent examine-asent t t)
          (declare (ignore gaf-asent))
          (when trigger-bindings
            (let (remainder-neg-lits remainder-pos-lits)
              (if (eq :pos examine-sense)
                  (progn
                    (setf remainder-neg-lits other-lits)
                    (setf remainder-pos-lits (remove examine-asent examine-lits)))
                  (progn
                    (setf remainder-neg-lits (remove examine-asent examine-lits))
                    (setf remainder-pos-lits other-lits)))
              (handle-forward-propagation-from-gaf
               examine-asent remainder-neg-lits remainder-pos-lits pragmatic-dnf
               propagation-mt trigger-bindings rule
               (append trigger-supports unify-justification))))))))
  nil)

(defparameter *forward-non-trigger-literal-restricted-examine-asent* nil)

(defun handle-forward-propagation-from-gaf (examine-asent remainder-neg-lits remainder-pos-lits pragmatic-dnf propagation-mt trigger-bindings rule trigger-supports)
  "[Cyc] Assume TRIGGER-ASENT is the sentence that triggered this forward propagation.
   @param EXAMINE-ASENT; the literal of RULE that unified with TRIGGER-ASENT
   @param REMAINDER-NEG-LITS; the other neg-lits of RULE, minus EXAMINE-ASENT (if TRIGGER-ASENT is a neg-lit).
   @param REMAINDER-POS-LITS; the other pos-lits of RULE, minus EXAMINE-ASENT (if TRIGGER-ASENT is a pos-lit).
   @param PRAGMATIC-DNF; a DNF of additional pragmatic constraints on RULE in PROPAGATION-MT.
   @param PROPAGATION-MT; the microtheory of the forward inference propagation.
   @param TRIGGER-BINDINGS; bindings resulting from unifying the TRIGGER-ASENT with EXAMINE-ASENT from RULE.
   @param RULE; the rule assertion that being triggerd by the TRIGGER-ASENT.
   @param TRIGGER-SUPPORTS; the supports that justify TRIGGER-ASENT."
  (let* ((restricted-remainder-neg-lits (apply-bindings trigger-bindings remainder-neg-lits))
         (restricted-remainder-pos-lits (apply-bindings trigger-bindings remainder-pos-lits))
         (restricted-rule-remainder-cnf (make-cnf restricted-remainder-neg-lits restricted-remainder-pos-lits))
         (restricted-pragmatic-dnf (apply-bindings trigger-bindings pragmatic-dnf)))
    (let ((*forward-non-trigger-literal-restricted-examine-asent*
            (apply-bindings trigger-bindings examine-asent)))
      (handle-forward-propagation restricted-rule-remainder-cnf restricted-pragmatic-dnf propagation-mt trigger-bindings rule trigger-supports)))
  nil)

;; (defun creation-template-forward-rules-via-exemplars (template) ...) -- active declareFunction, no body
;; (defun creation-template-exemplars (template) ...) -- active declareFunction, no body
;; (defun creation-template-allowable-rules (template) ...) -- active declareFunction, no body
;; (defun all-genl-creation-templates (template) ...) -- active declareFunction, no body
;; (defun creation-template-allowable-rules-internal (template) ...) -- active declareFunction, no body

(defun handle-forward-propagation (rule-remainder-cnf pragmatic-dnf propagation-mt trigger-bindings rule trigger-supports)
  (when (forward-propagation-supports-doomed? rule trigger-supports)
    (return-from handle-forward-propagation nil))
  (let* ((rule-remainder-neg-lits (neg-lits rule-remainder-cnf))
         (rule-remainder-pos-lits (pos-lits rule-remainder-cnf)))
    (dolist (target-asent rule-remainder-pos-lits)
      (let* ((other-pos-lits (remove target-asent rule-remainder-pos-lits))
             (query-dnf (make-dnf other-pos-lits rule-remainder-neg-lits)))
        (handle-one-forward-propagation query-dnf pragmatic-dnf propagation-mt target-asent :true trigger-bindings rule trigger-supports)))
    (when *forward-propagate-to-negations*
      (dolist (target-asent rule-remainder-neg-lits)
        (let* ((other-neg-lits (remove target-asent rule-remainder-neg-lits))
               (query-dnf (make-dnf rule-remainder-pos-lits other-neg-lits)))
          (handle-one-forward-propagation query-dnf pragmatic-dnf propagation-mt target-asent :false trigger-bindings rule trigger-supports)))))
  nil)

(defun handle-one-forward-propagation (query-dnf pragmatic-dnf propagation-mt target-asent target-truth trigger-bindings rule trigger-supports)
  (catch :inference-rejected
    (cond ((and (empty-clause? query-dnf)
                (empty-clause? pragmatic-dnf))
           (add-empty-forward-propagation-result target-asent target-truth propagation-mt trigger-bindings rule trigger-supports))
          ((or (not (semantically-valid-forward-dnf query-dnf propagation-mt))
               (not (semantically-valid-forward-dnf pragmatic-dnf propagation-mt)))
           nil)
          (t
           (let ((filtered-pragmatic-dnf (filter-forward-pragmatic-dnf pragmatic-dnf)))
             (forward-propagate-dnf query-dnf filtered-pragmatic-dnf propagation-mt target-asent target-truth trigger-bindings rule trigger-supports)))))
  nil)

(defun filter-forward-pragmatic-dnf (pragmatic-dnf)
  "[Cyc] Removes #$forwardNonTriggerLiteral pos-lits from PRAGMATIC-DNF."
  (let ((pos-lits (pos-lits pragmatic-dnf)))
    (if (not (find-if #'forward-non-trigger-literal-lit? pos-lits))
        pragmatic-dnf
        (let ((new-pos-lits (remove-if #'forward-non-trigger-literal-lit? pos-lits)))
          (make-dnf (neg-lits pragmatic-dnf) new-pos-lits)))))

(defun forward-propagate-dnf (query-dnf pragmatic-dnf propagation-mt target-asent target-truth trigger-bindings rule trigger-supports)
  (multiple-value-bind (forward-results inference query-time)
      (new-forward-query-from-dnf query-dnf pragmatic-dnf propagation-mt)
    (when *forward-inference-browsing-callback*
      (if *forward-inference-browsing-callback-more-info?*
          (funcall *forward-inference-browsing-callback* inference rule
                   ;; Likely builds a plist with :target-asent, :target-truth,
                   ;; :trigger-bindings, :trigger-supports, :forward-results
                   (missing-larkc 9148))
          (funcall *forward-inference-browsing-callback* inference rule)))
    (increment-forward-inference-historical-count)
    (increment-forward-inference-metrics rule query-time inference)
    (when forward-results
      (increment-successful-forward-inference-historical-count))
    (dolist (forward-result forward-results)
      (add-forward-propagation-result target-asent target-truth propagation-mt trigger-bindings rule trigger-supports forward-result)))
  nil)

(defun new-forward-query-from-dnf (query-dnf pragmatic-dnf propagation-mt &optional overriding-query-properties)
  (let* ((query-properties (forward-inference-query-properties pragmatic-dnf overriding-query-properties))
         (forward-results nil)
         (halt-reason nil)
         (inference nil)
         (query-time nil)
         (time-var (get-internal-real-time)))
    (declare (ignorable halt-reason))
    (multiple-value-setq (forward-results halt-reason inference)
      (new-cyc-query-from-dnf query-dnf propagation-mt nil query-properties))
    (setf query-time (/ (- (get-internal-real-time) time-var)
                        internal-time-units-per-second))
    (values forward-results inference query-time)))

;; (defun new-cyc-trivial-forward-query-from-dnf (query-dnf propagation-mt &optional pragmatic-dnf overriding-query-properties) ...) -- active declareFunction, no body
;; (defun new-forward-query (sentence &optional mt query-properties) ...) -- active declareFunction, no body

(defun forward-inference-query-properties (pragmatic-dnf &optional overriding-query-properties)
  (let* ((store (get-forward-problem-store))
         (non-explanatory-sentence (if (empty-clause? pragmatic-dnf)
                                       nil
                                       (dnf-formula pragmatic-dnf)))
         (browsable? (and (browse-forward-inferences?) t))
         (block? (and *block-forward-inferences?* t))
         (max-time *forward-inference-time-cutoff*)
         (productivity-limit (productivity-limit-from-removal-cost-cutoff *forward-inference-removal-cost-cutoff*))
         (new-terms-allowed *prefer-forward-skolemization*))
    (must (problem-store-p store)
          "Tried to do forward inference outside of a problem store")
    (let ((query-properties (list :problem-store store
                                  :non-explanatory-sentence non-explanatory-sentence
                                  :allow-indeterminate-results? t
                                  :browsable? browsable?
                                  :block? block?
                                  :productivity-limit productivity-limit
                                  :probably-approximately-done 1
                                  :max-time max-time
                                  :result-uniqueness :proof
                                  :return :bindings-and-supports
                                  :new-terms-allowed? new-terms-allowed)))
      (when overriding-query-properties
        (setf query-properties (merge-plist query-properties overriding-query-properties)))
      query-properties)))

;; (defun trivial-forward-inference-query-properties (pragmatic-dnf &optional overriding-query-properties) ...) -- active declareFunction, no body

(defun add-forward-propagation-result (target-asent target-truth propagation-mt trigger-bindings rule trigger-supports forward-result)
  (destructuring-bind (inference-bindings inference-supports) forward-result
    (let ((concluded-asent (apply-bindings inference-bindings target-asent)))
      (when (hl-ground-tree-p concluded-asent)
        (unless (forward-bindings-abnormal? propagation-mt rule trigger-bindings inference-bindings)
          (let ((concluded-supports (new-forward-concluded-supports rule trigger-supports inference-supports)))
            (add-forward-deductions-from-supports propagation-mt concluded-asent target-truth concluded-supports))))))
  nil)

(defun add-empty-forward-propagation-result (target-asent target-truth propagation-mt trigger-bindings rule trigger-supports)
  (add-forward-propagation-result target-asent target-truth propagation-mt trigger-bindings rule trigger-supports (list nil nil)))

(defun new-forward-concluded-supports (rule trigger-supports &optional inference-supports)
  "[Cyc] Combine RULE, TRIGGER-SUPPORTS and INFERENCE-SUPPORTS (if any)
   into a single list of support-p that represents one complete justification for
   a new forward conclusion."
  (cons rule (append (when trigger-supports (copy-list trigger-supports))
                     (when inference-supports (copy-list inference-supports)))))

(defun add-forward-deductions-from-supports (propagation-mt concluded-asent concluded-truth concluded-supports)
  (if (decontextualized-literal? concluded-asent)
      (let ((convention-mt (decontextualized-literal-convention-mt concluded-asent)))
        (if (equal #$InferencePSC propagation-mt)
            (let ((support-combinations (compute-decontextualized-support-combinations concluded-supports)))
              (dolist (support-combination support-combinations)
                (handle-forward-deduction-in-mt concluded-asent concluded-truth convention-mt support-combination)))
            (handle-forward-deduction-in-mt concluded-asent concluded-truth convention-mt concluded-supports)))
      (if (equal #$InferencePSC propagation-mt)
          (let ((mt-support-combinations (compute-all-mt-and-support-combinations concluded-supports)))
            (dolist (mt-support-combination mt-support-combinations)
              (destructuring-bind (concluded-mts support-combination) mt-support-combination
                (dolist (concluded-mt concluded-mts)
                  (handle-forward-deduction-in-mt concluded-asent concluded-truth concluded-mt support-combination)))))
          (handle-forward-deduction-in-mt concluded-asent concluded-truth propagation-mt concluded-supports)))
  nil)

(defun handle-forward-deduction-in-mt (asent truth mt supports)
  (unless (and (abnormality-except-support-enabled?)
               (supports-contain-excepted-assertion-in-mt? supports mt))
    (destructuring-bind (rule &rest other-supports) supports
      (declare (ignore other-supports))
      (if (constraint-rule? rule mt)
          ;; Likely handles a forward deduction as a constraint verification
          (missing-larkc 36390)
          (handle-forward-deduction-in-mt-as-assertible asent truth mt supports))))
  nil)

(defvar *assume-forward-deduction-is-wf?* nil
  "[Cyc] When non-NIL, the deductions that result from forward inference are assumed to be WFF.")

(defun handle-forward-deduction-in-mt-as-assertible (asent truth mt supports)
  (let* ((gaf-formula (possibly-negate asent truth))
         (canon-cnfs nil))
    (if *assume-forward-deduction-is-wf?*
        (multiple-value-setq (canon-cnfs mt)
          ;; Likely calls canonicalize-gaf-wff-assert or similar
          (missing-larkc 31067))
        (multiple-value-setq (canon-cnfs mt)
          (canonicalize-gaf gaf-formula mt)))
    (unless (cycl-truth-value-p canon-cnfs)
      (cond ((find-if #'invalid-assertion? supports)
             (warn "Canonicalization of ~s in ~s invalidated the forward supports ~s"
                   gaf-formula mt supports)
             (setf canon-cnfs nil))
            ((null canon-cnfs)
             ;; Likely reports a forward inference WFF failure
             (missing-larkc 780)
             (return-from handle-forward-deduction-in-mt-as-assertible nil)))
      (dolist (canon-cnf-bind-list-pair canon-cnfs)
        (destructuring-bind (canon-cnf &optional binding-list) canon-cnf-bind-list-pair
          (declare (type cnf-p canon-cnf))
          (unless (and *filter-deductions-for-trivially-derivable-gafs*
                       (atomic-clause-p canon-cnf)
                       ;; Likely checks if the gaf is trivially derivable
                       (missing-larkc 12453))
            (handle-forward-deduction-in-mt-as-assertible-int canon-cnf mt supports binding-list))))))
  nil)

(defun handle-forward-deduction-in-mt-as-assertible-int (cnf mt supports &optional variable-map)
  (let* ((deduction-spec (create-deduction-spec supports))
         (hl-assertion-spec (new-hl-assertion-spec cnf mt :forward variable-map))
         (hl-assertible (new-hl-assertible hl-assertion-spec deduction-spec)))
    (note-new-forward-assertible hl-assertible))
  nil)

(defvar *forward-constraint-inference-enabled?* nil
  "[Cyc] Temporary control variable;  When non-nil, forward rules labelled with #$constraint are treated
   as constraints that must be already true rather than mechanisms to add deductions to the KB.")

(defun constraint-rule? (rule &optional mt)
  "[Cyc] Return T iff RULE is a rule assertion labelled as a #$constraint in MT"
  (and (rule-assertion? rule)
       (some-pred-value-in-relevant-mts rule #$constraint mt 1 :true)))

;; (defun handle-forward-deduction-in-mt-as-constraint (asent truth mt supports) ...) -- active declareFunction, no body
;; (defun verify-forward-deduction-constraint (asent truth) ...) -- active declareFunction, no body

(defvar *forward-non-trigger-literal-pruning-enabled?* t
  "[Cyc] temporary control parameter; @todo eliminate")

(defun syntactically-valid-forward-non-trigger-asents (dnf)
  (let ((invalid? nil))
    (when *forward-non-trigger-literal-pruning-enabled?*
      (let ((pos-lits (pos-lits dnf)))
        (when (find-if #'forward-non-trigger-literal-lit? pos-lits)
          (dolist (asent pos-lits)
            (when invalid? (return))
            (when (eq #$forwardNonTriggerLiteral (atomic-sentence-predicate asent))
              (when (and (fully-bound-p asent)
                         (equal (atomic-sentence-arg1 asent)
                                *forward-non-trigger-literal-restricted-examine-asent*))
                (setf invalid? t)))))))
    (not invalid?)))

(defun semantically-valid-forward-dnf (dnf propagation-mt)
  (when (not (syntactically-valid-forward-non-trigger-asents dnf))
    (return-from semantically-valid-forward-dnf nil))
  (when (not *type-filter-forward-dnf*)
    (return-from semantically-valid-forward-dnf t))
  (inference-semantically-valid-dnf dnf propagation-mt))

(defparameter *forward-leafy-mt-threshold* -1
  "[Cyc] integerp; Reified microtheories whose spec-cardinality is at or below this
   threshold are considered to be sufficiently close to being a leaf microtheory
   as to warrant eager forward inference mt-pruning analysis.
   A negative value therefore disables this feature.")

;; (defun forward-leafy-mt-p (mt) ...) -- active declareFunction, no body

(defun forward-propagation-supports-doomed? (rule trigger-supports)
  (when (minusp *forward-leafy-mt-threshold*)
    (return-from forward-propagation-supports-doomed? nil))
  (let ((mts (cons (assertion-mt rule)
                   (mapcar #'support-mt trigger-supports))))
    (setf mts (delete #$InferencePSC mts))
    (setf mts (delete-duplicates mts :test #'hlmt-equal))
    (when (length>= mts 2)
      (setf mts (min-mts mts))
      (when (length>= mts 2)
        ;; Likely checks whether there are no common spec MTs among the leafy mts
        (let ((result (missing-larkc 36389)))
          (return-from forward-propagation-supports-doomed? result)))))
  nil)

;; (defun forward-propagation-mts-doomed? (mts) ...) -- active declareFunction, no body
;; (defun forward-possibly-some-common-spec-mt?-internal (mts) ...) -- active declareFunction, no body
;; (defun forward-possibly-some-common-spec-mt? (mts) ...) -- active declareFunction, no body
;; (defun leafy-mt-p (mt &optional threshold) ...) -- active declareFunction, no body

(defun compute-all-mt-and-support-combinations (supports)
  (when (some-support-combinations-extensionally-possible supports)
    (let ((support-combinations (all-forward-support-mt-combinations supports))
          (answer nil))
      (dolist (support-combination support-combinations)
        (setf support-combination (delete-duplicates support-combination :test #'equal))
        (let ((mts (compute-mts-from-supports support-combination)))
          (push (list mts support-combination) answer)))
      (nreverse answer))))

(defun compute-decontextualized-support-combinations (supports)
  (when (some-support-combinations-theoretically-possible supports)
    (let ((support-combinations (all-forward-support-mt-combinations supports))
          (answer nil))
      (dolist (support-combination support-combinations)
        (setf support-combination (delete-duplicates support-combination :test #'equal))
        (push support-combination answer))
      (nreverse answer))))

(defparameter *verify-some-support-combinations-possible* t)

(defun some-support-combinations-theoretically-possible (supports)
  "[Cyc] We don't care whether there exists an mt that can see all the SUPPORTS,
but could there possibly exist one?  This should return t most of the time,
unless two of the supports are in negationMts of each other or something."
  (declare (ignore supports))
  t)

(defun some-support-combinations-extensionally-possible (supports)
  (when (not *verify-some-support-combinations-possible*)
    (return-from some-support-combinations-extensionally-possible t))
  (setf supports (remove-if-not #'assertion-p supports))
  (if (null supports)
      t
      (let ((mts (mapcar #'assertion-mt supports)))
        (inference-some-max-floor-mts mts))))

(defun all-forward-support-mt-combinations (supports)
  (if (null supports)
      (list nil)
      (destructuring-bind (first &rest rest) supports
        (let ((first-combos (forward-support-mt-combinations first)))
          (when first-combos
            (let ((rest-combos (all-forward-support-mt-combinations rest)))
              (mapcar-product #'cons first-combos rest-combos)))))))

(defun forward-support-mt-combinations (support)
  (if (assertion-p support)
      (list support)
      (hl-forward-mt-combos support)))

(defun compute-mts-from-supports (supports &optional (require-from-list? *require-cached-gaf-mt-from-supports*))
  "[Cyc] From SUPPORTS, compute the microtheories in which such an argument should be placed."
  (multiple-value-bind (assume-wff-supports compute-where-wff-supports)
      (separate-supports-for-mt-placement supports)
    (let ((mts-from-assumed-wff-supports (mapcar #'support-mt assume-wff-supports)))
      (if (null compute-where-wff-supports)
          (forward-mt-placements-from-support-mts mts-from-assumed-wff-supports require-from-list?)
          (let* ((additional-mt-combinations
                   ;; Likely computes mts where the tou supports are WFF
                   (missing-larkc 36383))
                 (answer-mts nil))
            (dolist (additional-mts additional-mt-combinations)
              (setf answer-mts (union answer-mts
                                      (forward-mt-placements-from-support-mts
                                       (append additional-mts mts-from-assumed-wff-supports)
                                       require-from-list?))))
            (when answer-mts
              (setf answer-mts (delete-subsumed-items answer-mts #'spec-mt?))
              answer-mts))))))

(defun separate-supports-for-mt-placement (supports)
  "[Cyc] Separate SUPPORTS into two lists, which are returned as multiple values:
   @return 0 ; supports where we can safely assume the support is WFF.
   @return 1 ; supports where can must compute the mts where the support is WFF."
  (let ((assume-wff-supports nil)
        (compute-where-wff-supports nil))
    (dolist (support supports)
      (if (assertion-p support)
          (if (term-of-unit-assertion-p support)
              (push support compute-where-wff-supports)
              (push support assume-wff-supports))
          (if (tou-lit? (support-formula support))
              (push support compute-where-wff-supports)
              (push support assume-wff-supports))))
    (values (nreverse assume-wff-supports)
            (nreverse compute-where-wff-supports))))

(defun forward-mt-placements-from-support-mts (mts &optional require-from-list?)
  (when (within-forward-inference?)
    (setf mts (remove #$InferencePSC mts)))
  (inference-max-floor-mts-with-cycles-pruned mts (when require-from-list? mts)))

;; (defun all-computed-wff-mt-combinations (supports) ...) -- active declareFunction, no body
;; (defun computed-wff-mt-combinations (support) ...) -- active declareFunction, no body

;; Setup
(toplevel (initialize-forward-inference-environment))
(toplevel (note-memoized-function 'forward-possibly-some-common-spec-mt?))
