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

;; Variables

(defparameter *ghl-mark-and-sweep-recursion-limit* 24)

;; Functions — following declare_ghl_search_methods_file() ordering

;; (defun ghl-search (v-search start-node) ...) -- commented declareFunction, no body
;; (defun transitive-ghl-search (v-search start-node) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep (v-search start-node) ...) -- commented declareFunction, no body
;; (defun ghl-unmark-and-sweep (v-search start-node) ...) -- commented declareFunction, no body
;; (defun ghl-mark-sweep-until-goal (v-search start-node) ...) -- commented declareFunction, no body
;; (defun ghl-unmark-sweep-and-map (v-search start-node) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep-df (v-search start-node) ...) -- commented declareFunction, no body
;; (defun ghl-unmark-and-sweep-df (v-search start-node) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep-bf (v-search start-node) ...) -- commented declareFunction, no body
;; (defun ghl-unmark-and-sweep-bf (v-search start-node) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep-df-purely-recursive (v-search node search-deck) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep-df-hybrid (v-search node search-deck max-depth) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep-recursive-df (v-search node search-deck max-depth) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep-iterative-df (v-search start-node search-deck) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep-iterative-bf (v-search start-node search-deck) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep-iterative (v-search start-node search-deck depth-first?) ...) -- commented declareFunction, no body

(defun ghl-add-accessible-link-nodes-to-deck (v-search node node-deck)
  "[Cyc] Add all accessible link nodes of NODE in V-SEARCH to NODE-DECK."
  ;; Direct port of ghl_search_methods.java:114-439. Java's inline expansion of
  ;; do-ghl-accessible-link-nodes is preserved here (special-var let-bindings +
  ;; nested dictionary/iterator loops) rather than collapsed back to the macro,
  ;; because the do-ghl/do-sbhl/do-gt macros in ghl-link-iterators.lisp still
  ;; reference unported macros (with-sbhl-search-module etc.).
  (let ((count 0))
    (dolist (pred (ghl-relevant-predicates v-search))
      (let ((*ghl-link-pred* pred))
        (cond
          ;; SBHL predicate branch
          ((sbhl-predicate-p pred)
           (let ((node-37 (naut-to-nart node)))
             (let ((*sbhl-search-module* (get-sbhl-module pred))
                   (*sbhl-search-module-type* (get-sbhl-module-type (get-sbhl-module pred)))
                   (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test (get-sbhl-module pred)))
                   (*genl-inverse-mode-p* nil)
                   (*sbhl-module* (get-sbhl-module pred)))
               (let ((*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                                (not *genl-inverse-mode-p*)
                                                *genl-inverse-mode-p*)))
                 (cond
                   ((fort-p node-37)
                    (let ((d-link (get-sbhl-graph-link node-37 (get-sbhl-module pred))))
                      (if d-link
                          (dolist (search-direction (determine-graphl-relevant-directions (ghl-direction v-search)))
                            (let* ((link-direction (sbhl-search-direction-to-link-direction search-direction (get-sbhl-module pred)))
                                   (mt-links (get-sbhl-mt-links d-link link-direction (get-sbhl-module pred))))
                              (when mt-links
                                (maphash (lambda (mt tv-links)
                                           (when (relevant-mt? mt)
                                             (let ((*sbhl-link-mt* mt))
                                               (maphash (lambda (tv link-nodes-var)
                                                          (when (relevant-sbhl-tv? tv)
                                                            (let ((*sbhl-link-tv* tv))
                                                              (dolist (link-node link-nodes-var)
                                                                (incf count)
                                                                (deck-push link-node node-deck)))))
                                                        tv-links))))
                                         mt-links))))
                          (sbhl-error 5 "attempting to bind direction link" nil nil nil nil))))
                   ((closed-naut? node-37)
                    (dolist (search-direction (determine-graphl-relevant-directions (ghl-direction v-search)))
                      (let ((link-direction (sbhl-search-direction-to-link-direction search-direction (get-sbhl-module pred))))
                        (declare (ignore link-direction))
                        (let ((new-list (if (sbhl-randomize-lists-p)
                                            (missing-larkc 9258)
                                            (missing-larkc 2557))))
                          (dolist (generating-fn new-list)
                            (let ((*sbhl-link-generator* generating-fn))
                              (let ((link-nodes-var (funcall generating-fn node-37)))
                                (dolist (link-node link-nodes-var)
                                  (incf count)
                                  (deck-push link-node node-deck))))))))))))))
          ;; GT predicate branch
          ((gt-predicate-p pred)
           (let ((truth (tv-truth (ghl-tv v-search)))
                 (strength (tv-strength (ghl-tv v-search))))
             (let ((*gt-args-swapped-p* nil))
               (dolist (search-direction (determine-graphl-relevant-directions (ghl-direction v-search)))
                 (let* ((index-argnum (gt-index-argnum-for-direction search-direction))
                        (gather-argnum (other-binary-arg index-argnum)))
                   ;; Unswapped pass
                   (let ((*gt-relevant-pred* pred)
                         (*relevant-pred-function* #'relevant-pred-wrt-gt?))
                     (let ((pred-var nil))
                       (when (do-gaf-arg-index-key-validator node index-argnum pred-var)
                         (let ((iterator-var (new-gaf-arg-final-index-spec-iterator node index-argnum pred-var))
                               (done nil)
                               (token nil))
                           (loop until done do
                             (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token))
                                    (valid (not (eq token final-index-spec))))
                               (when valid
                                 (let ((final-index-iterator nil))
                                   (unwind-protect
                                        (progn
                                          (setf final-index-iterator
                                                (new-final-index-iterator final-index-spec :gaf truth nil))
                                          (let ((done2 nil) (token2 nil))
                                            (loop until done2 do
                                              (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token2))
                                                     (valid2 (not (eq token2 assertion))))
                                                (when valid2
                                                  (when (or (not (assertion-p assertion))
                                                            (el-strength-implies (assertion-strength assertion) strength))
                                                    (let ((link-node (formula-arg assertion gather-argnum nil)))
                                                      (incf count)
                                                      (deck-push link-node node-deck))))
                                                (setf done2 (not valid2))))))
                                     (when final-index-iterator
                                       (destroy-final-index-iterator final-index-iterator)))))
                               (setf done (not valid))))))))
                   ;; Swapped pass (only when ghl-uses-spec-preds-p)
                   (when (ghl-uses-spec-preds-p)
                     (let ((*gt-args-swapped-p* t)
                           (*gt-relevant-pred* pred)
                           (*relevant-pred-function* #'relevant-pred-wrt-gt?))
                       (let ((pred-var nil))
                         (when (do-gaf-arg-index-key-validator node gather-argnum pred-var)
                           (let ((iterator-var (new-gaf-arg-final-index-spec-iterator node gather-argnum pred-var))
                                 (done nil)
                                 (token nil))
                             (loop until done do
                               (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token))
                                      (valid (not (eq token final-index-spec))))
                                 (when valid
                                   (let ((final-index-iterator nil))
                                     (unwind-protect
                                          (progn
                                            (setf final-index-iterator
                                                  (new-final-index-iterator final-index-spec :gaf truth nil))
                                            (let ((done2 nil) (token2 nil))
                                              (loop until done2 do
                                                (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token2))
                                                       (valid2 (not (eq token2 assertion))))
                                                  (when valid2
                                                    (when (or (not (assertion-p assertion))
                                                              (el-strength-implies (assertion-strength assertion) strength))
                                                      (let ((link-node (formula-arg assertion index-argnum nil)))
                                                        (incf count)
                                                        (deck-push link-node node-deck))))
                                                  (setf done2 (not valid2))))))
                                       (when final-index-iterator
                                         (destroy-final-index-iterator final-index-iterator)))))
                                 (setf done (not valid)))))))))))))))))
    count))

;; (defun ghl-add-accessible-link-nodes-and-supports-to-deck (v-search node supports node-deck) ...) -- commented declareFunction, no body
;; (defun ghl-remove-unneeded-supports (supports) ...) -- commented declareFunction, no body
;; (defun ghl-add-support-to-result (v-search support) ...) -- commented declareFunction, no body

(defun ghl-add-justification-to-result (v-search justification)
  "[Cyc] Add each support in JUSTIFICATION to the result of V-SEARCH, de-duping with EQUAL."
  ;; Java body: iterate justification, call ghl-add-to-result with #'equal for each support.
  (dolist (support justification)
    (ghl-add-to-result v-search support #'equal))
  nil)

(defun ghl-create-justification (v-search supports)
  "[Cyc] Build a justification list from SUPPORTS for the search V-SEARCH, adding genl-pred/genl-inverse HL supports where needed, then de-duping with EQUAL."
  (let* ((search-preds (let ((sp (ghl-search-predicates v-search)))
                         (if (listp sp) sp (list sp))))
         (search-mt *mt*)
         (search-tv (ghl-tv v-search))
         (sbhl-tv (support-tv-to-sbhl-tv search-tv))
         (justification nil))
    (dolist (support supports)
      (when (support-p support)
        (setf justification (cons support justification)))
      (let ((support-pred (cond
                            ((assertion-p support) (gaf-predicate support))
                            ((hl-support-p support) (formula-operator (hl-support-sentence support)))
                            ((el-formula-p support) (formula-operator support))
                            (t nil))))
        (unless (member-eq? support-pred search-preds)
          (let ((genl-pred nil)
                (genl-inverse nil))
            (unless genl-pred
              (csome (search-pred search-preds genl-pred)
                (when (genl-predicate? support-pred search-pred search-mt sbhl-tv)
                  (setf genl-pred search-pred))))
            (unless genl-inverse
              (csome (search-pred search-preds genl-inverse)
                ;; missing-larkc 7102 — likely a genl-inverse? style check paralleling
                ;; the genl-predicate? call just above, determining if support-pred
                ;; is a genl-inverse of search-pred in search-mt under sbhl-tv.
                (when (missing-larkc 7102)
                  (setf genl-inverse search-pred))))
            (when genl-pred
              (let* ((support-sentence (make-binary-formula #$genlPreds support-pred genl-pred))
                     (hl-support (make-hl-support :genlpreds support-sentence search-mt search-tv)))
                (setf justification (cons hl-support justification))))
            (when genl-inverse
              (let* ((support-sentence (make-binary-formula #$genlInverse support-pred genl-inverse))
                     (hl-support (make-hl-support :genlpreds support-sentence search-mt search-tv)))
                (setf justification (cons hl-support justification))))))))
    (fast-delete-duplicates (nreverse justification) #'equal)))

;; (defun ghl-mark-and-sweep-depth-cutoff-initializer (v-search start-node depth-cutoff) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep-depth-cutoff (v-search start-node depth-cutoff) ...) -- commented declareFunction, no body
;; (defun ghl-all-edges-iterative-deepening-initializer (v-search start-node depth-cutoff) ...) -- commented declareFunction, no body
;; (defun ghl-mark-and-sweep-depth-cutoff-all-edges-unwound (v-search start-node depth-cutoff) ...) -- commented declareFunction, no body

;; TODO - do-ghl-closure -- commented declareMacro, body not reconstructed
;; Evidence from Internal Constants:
;;   $list15 arglist: ((LINK-NODE PRED NODE DIRECTION &KEY MT TV DONE (ORDER :DEPTH-FIRST)) &BODY BODY)
;;   $list16 allowed keys: (:MT :TV :DONE :ORDER)
;;   $kw17$ALLOW-OTHER-KEYS
;;   gensym $sym23$ITERATOR
;;   $sym24$CLET, $sym25$NEW-GHL-CLOSURE-ITERATOR, $sym26$DO-ITERATOR
;; Likely expansion shape:
;;   (clet ((,iterator (new-ghl-closure-iterator pred node direction mt tv order)))
;;     (do-iterator (,link-node ,iterator :done ,done) ,@body))
;; No visible expansion site exists in the Java tree (only referenced by symbol in
;; tva_tactic.java as $sym115$DO_GHL_CLOSURE). DO-ITERATOR macro is not defined in
;; the ported tree, so reconstruction is not safe — leaving as TODO.

(defun new-ghl-closure-iterator (pred node direction &optional mt tv
                                                       (search-order :breadth-first)
                                                       (return-non-transitive-results? t))
  "[Cyc] Create a new GHL closure iterator over PRED relation from NODE in DIRECTION."
  (let* ((v-search (new-ghl-search (list :predicates (list pred)
                                         :type :transitive-reasoning
                                         :order search-order
                                         :direction direction
                                         :tv tv
                                         :marking :simple
                                         :marking-space (ghl-instantiate-new-space))))
         (reflexive? (reflexive-binary-predicate-p pred)))
    (new-ghl-closure-search-iterator v-search node mt reflexive?
                                     return-non-transitive-results?)))

(defun new-removal-ghl-closure-iterator (pred node direction &optional mt)
  "[Cyc] Create a new removal GHL closure iterator (non-transitive results suppressed)."
  (new-ghl-closure-iterator pred node direction mt nil :breadth-first nil))

(defun new-ghl-closure-search-iterator (v-search start-node mt reflexive?
                                        return-non-transitive-results?)
  "[Cyc] Wrap a GHL closure search iterator state in an iterator object."
  (let ((state (ghl-closure-search-iterator-state v-search start-node mt
                                                  reflexive?
                                                  return-non-transitive-results?)))
    (new-iterator state
                  #'ghl-closure-search-iterator-done
                  #'ghl-closure-search-iterator-next
                  #'ghl-closure-search-iterator-finalize)))

(defun ghl-closure-search-iterator-state (v-search start-node mt reflexive?
                                          return-non-transitive-results?)
  "[Cyc] Initialize the state (search, deck, mt) for a GHL closure search iterator."
  ;; Direct port of ghl_search_methods.java:561-779. Both do-gt-accessible-link-nodes
  ;; and with-inference-mt-relevance are expanded inline to avoid calling macros
  ;; that reference unported names.
  (let ((search-deck (if (ghl-depth-first-search-p v-search)
                         (create-deck :stack)
                         (create-deck :queue))))
    (cond
      ((null return-non-transitive-results?)
       (let ((mt-var mt))
         (let ((*mt* (update-inference-mt-relevance-mt mt-var))
               (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
               (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
           (ghl-mark-node v-search start-node :start)
           (let ((pred (first (ghl-relevant-predicates v-search)))
                 (truth (tv-truth (ghl-tv v-search)))
                 (strength (tv-strength (ghl-tv v-search))))
             (let ((*gt-args-swapped-p* nil))
               (dolist (search-direction (determine-graphl-relevant-directions (ghl-direction v-search)))
                 (let* ((index-argnum (gt-index-argnum-for-direction search-direction))
                        (gather-argnum (other-binary-arg index-argnum)))
                   ;; Unswapped pass
                   (let ((*gt-relevant-pred* pred)
                         (*relevant-pred-function* #'relevant-pred-wrt-gt?))
                     (let ((pred-var nil))
                       (when (do-gaf-arg-index-key-validator start-node index-argnum pred-var)
                         (let ((iterator-var (new-gaf-arg-final-index-spec-iterator start-node index-argnum pred-var))
                               (done nil)
                               (token nil))
                           (loop until done do
                             (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token))
                                    (valid (not (eq token final-index-spec))))
                               (when valid
                                 (let ((final-index-iterator nil))
                                   (unwind-protect
                                        (progn
                                          (setf final-index-iterator
                                                (new-final-index-iterator final-index-spec :gaf truth nil))
                                          (let ((done2 nil) (token2 nil))
                                            (loop until done2 do
                                              (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token2))
                                                     (valid2 (not (eq token2 assertion))))
                                                (when valid2
                                                  (when (or (not (assertion-p assertion))
                                                            (el-strength-implies (assertion-strength assertion) strength))
                                                    (let ((one-step-node (formula-arg assertion gather-argnum nil)))
                                                      (ghl-mark-node v-search one-step-node :start)
                                                      (ghl-add-accessible-link-nodes-to-deck v-search one-step-node search-deck))))
                                                (setf done2 (not valid2))))))
                                     (when final-index-iterator
                                       (destroy-final-index-iterator final-index-iterator)))))
                               (setf done (not valid))))))))
                   ;; Swapped pass (only when ghl-uses-spec-preds-p)
                   (when (ghl-uses-spec-preds-p)
                     (let ((*gt-args-swapped-p* t)
                           (*gt-relevant-pred* pred)
                           (*relevant-pred-function* #'relevant-pred-wrt-gt?))
                       (let ((pred-var nil))
                         (when (do-gaf-arg-index-key-validator start-node gather-argnum pred-var)
                           (let ((iterator-var (new-gaf-arg-final-index-spec-iterator start-node gather-argnum pred-var))
                                 (done nil)
                                 (token nil))
                             (loop until done do
                               (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token))
                                      (valid (not (eq token final-index-spec))))
                                 (when valid
                                   (let ((final-index-iterator nil))
                                     (unwind-protect
                                          (progn
                                            (setf final-index-iterator
                                                  (new-final-index-iterator final-index-spec :gaf truth nil))
                                            (let ((done2 nil) (token2 nil))
                                              (loop until done2 do
                                                (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token2))
                                                       (valid2 (not (eq token2 assertion))))
                                                  (when valid2
                                                    (when (or (not (assertion-p assertion))
                                                              (el-strength-implies (assertion-strength assertion) strength))
                                                      (let ((one-step-node (formula-arg assertion index-argnum nil)))
                                                        (ghl-mark-node v-search one-step-node :start)
                                                        (ghl-add-accessible-link-nodes-to-deck v-search one-step-node search-deck))))
                                                  (setf done2 (not valid2))))))
                                       (when final-index-iterator
                                         (destroy-final-index-iterator final-index-iterator)))))
                                 (setf done (not valid))))))))))))))))
      ((null reflexive?)
       (let ((mt-var mt))
         (let ((*mt* (update-inference-mt-relevance-mt mt-var))
               (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
               (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
           (ghl-mark-node v-search start-node :start)
           (ghl-add-accessible-link-nodes-to-deck v-search start-node search-deck))))
      (t
       (deck-push start-node search-deck)))
    (list v-search search-deck mt)))

(defun ghl-closure-search-iterator-done (state)
  "[Cyc] Test whether the GHL closure search iterator is done."
  (destructuring-bind (v-search search-deck mt) state
    (declare (ignore v-search mt))
    (deck-empty-p search-deck)))

(defun ghl-closure-search-iterator-next (state)
  "[Cyc] Return the next result from the GHL closure search iterator."
  (destructuring-bind (v-search search-deck mt) state
    (let ((result nil))
      (loop until (or result (deck-empty-p search-deck)) do
        (let* ((node (deck-pop search-deck))
               (mark (get-ghl-marking v-search node)))
          (cond
            ((null mark)
             (ghl-mark-node v-search node t)
             (with-inference-mt-relevance (mt)
               (ghl-add-accessible-link-nodes-to-deck v-search node search-deck))
             (setf result node))
            ((eq mark :start)
             (ghl-mark-node v-search node t)
             (setf result node)))))
      (values result state (null result)))))

(defun ghl-closure-search-iterator-finalize (state)
  "[Cyc] Finalize the GHL closure search iterator."
  (destructuring-bind (v-search search-deck mt) state
    (declare (ignore mt))
    (destroy-ghl-search v-search)
    (clear-deck search-deck)
    t))

;; (defun ghl-closure (v-search start-node &optional mt tv search-order) ...) -- commented declareFunction, no body
;; (defun ghl-all-backward-true-nodes (pred node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun ghl-all-forward-true-nodes (pred node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun ghl-record-closure (pred node direction &optional mt tv) ...) -- commented declareFunction, no body
;; (defun ghl-record-all-backward-true-nodes (pred node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun ghl-record-all-forward-true-nodes (pred node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun ghl-predicate-relation-p (pred node1 node2 &optional mt tv return-non-transitive-results?) ...) -- commented declareFunction, no body

(defun gt-predicate-relation-p (pred node1 node2 &optional mt tv
                                                   return-non-transitive-results?)
  "[Cyc] Return whether PRED transitively relates NODE1 to NODE2 using GT search."
  (let ((result nil))
    (with-inference-mt-relevance (mt)
      (cond
        ((and (equal node1 node2) (reflexive-binary-predicate-p pred))
         (setf result t))
        ((and (equal node1 node2) (irreflexive-binary-predicate-p pred))
         (setf result nil))
        (t
         (let* ((direction (ghl-direction-for-predicate-relation pred))
                (forward? (ghl-forward-direction-p direction))
                (start-node (if forward? node1 node2))
                (goal-node (if forward? node2 node1))
                (v-search (new-ghl-search (list :predicates (list pred)
                                                :order :breadth-first
                                                :type :transitive-reasoning
                                                :direction direction
                                                :tv tv
                                                :marking :simple
                                                :goal-search-p t
                                                :goal (list goal-node)))))
           (reset-graphl-finished)
           (let ((search-deck (if (ghl-depth-first-search-p v-search)
                                  (create-deck :stack)
                                  (create-deck :queue)))
                 (resolve-goal-node? (or return-non-transitive-results?
                                         (reflexive-binary-predicate-p pred))))
             (ghl-mark-node v-search start-node :start)
             (gt-predicate-relation-p-add-accessible-link-nodes-to-deck
              v-search start-node search-deck resolve-goal-node?)
             (let ((node (deck-pop search-deck)))
               (loop until (or *graphl-finished?* (null node)) do
                 (let ((mark (get-ghl-marking v-search node)))
                   (cond
                     ((null mark)
                      (ghl-mark-node v-search node t)
                      (unless *graphl-finished?*
                        (gt-predicate-relation-p-add-accessible-link-nodes-to-deck
                         v-search node search-deck t)))
                     ((eq mark :start)
                      (ghl-mark-node v-search node t))))
                 (setf node (deck-pop search-deck)))))
           (setf result (sublisp-boolean (ghl-result v-search)))
           (destroy-ghl-search v-search)))))
    result))

(defun gt-predicate-relation-p-add-accessible-link-nodes-to-deck
    (v-search node v-deck resolve-goal-node?)
  "[Cyc] Add link nodes accessible from NODE to V-DECK, resolving goal-found when RESOLVE-GOAL-NODE?."
  ;; Direct port of ghl_search_methods.java:993-1181. do-gt-accessible-link-nodes
  ;; is expanded inline from the compiled Java. *graphl-finished?* acts as an
  ;; early-exit flag throughout the nested iteration.
  (let ((pred (first (ghl-relevant-predicates v-search)))
        (truth (tv-truth (ghl-tv v-search)))
        (strength (tv-strength (ghl-tv v-search))))
    (let ((*gt-args-swapped-p* nil))
      (unless *graphl-finished?*
        (dolist (search-direction (determine-graphl-relevant-directions (ghl-direction v-search)))
          (when *graphl-finished?* (return))
          (let* ((index-argnum (gt-index-argnum-for-direction search-direction))
                 (gather-argnum (other-binary-arg index-argnum)))
            ;; Unswapped pass
            (let ((*gt-relevant-pred* pred)
                  (*relevant-pred-function* #'relevant-pred-wrt-gt?))
              (let ((pred-var nil))
                (when (do-gaf-arg-index-key-validator node index-argnum pred-var)
                  (let ((iterator-var (new-gaf-arg-final-index-spec-iterator node index-argnum pred-var))
                        (done *graphl-finished?*)
                        (token nil))
                    (loop until done do
                      (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token))
                             (valid (not (eq token final-index-spec))))
                        (when valid
                          (let ((final-index-iterator nil))
                            (unwind-protect
                                 (progn
                                   (setf final-index-iterator
                                         (new-final-index-iterator final-index-spec :gaf truth nil))
                                   (let ((done2 *graphl-finished?*) (token2 nil))
                                     (loop until done2 do
                                       (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token2))
                                              (valid2 (not (eq token2 assertion))))
                                         (when valid2
                                           (when (or (not (assertion-p assertion))
                                                     (el-strength-implies (assertion-strength assertion) strength))
                                             (let ((link-node (formula-arg assertion gather-argnum nil)))
                                               (if (and (ghl-goal-node? v-search link-node) resolve-goal-node?)
                                                   (ghl-resolve-goal-found v-search link-node)
                                                   (deck-push link-node v-deck)))))
                                         (setf done2 (or (not valid2) *graphl-finished?*))))))
                              (when final-index-iterator
                                (destroy-final-index-iterator final-index-iterator)))))
                        (setf done (or (not valid) *graphl-finished?*))))))))
            ;; Swapped pass (only when ghl-uses-spec-preds-p)
            (when (ghl-uses-spec-preds-p)
              (let ((*gt-args-swapped-p* t)
                    (*gt-relevant-pred* pred)
                    (*relevant-pred-function* #'relevant-pred-wrt-gt?))
                (let ((pred-var nil))
                  (when (do-gaf-arg-index-key-validator node gather-argnum pred-var)
                    (let ((iterator-var (new-gaf-arg-final-index-spec-iterator node gather-argnum pred-var))
                          (done *graphl-finished?*)
                          (token nil))
                      (loop until done do
                        (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token))
                               (valid (not (eq token final-index-spec))))
                          (when valid
                            (let ((final-index-iterator nil))
                              (unwind-protect
                                   (progn
                                     (setf final-index-iterator
                                           (new-final-index-iterator final-index-spec :gaf truth nil))
                                     (let ((done2 *graphl-finished?*) (token2 nil))
                                       (loop until done2 do
                                         (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token2))
                                                (valid2 (not (eq token2 assertion))))
                                           (when valid2
                                             (when (or (not (assertion-p assertion))
                                                       (el-strength-implies (assertion-strength assertion) strength))
                                               (let ((link-node (formula-arg assertion index-argnum nil)))
                                                 (if (and (ghl-goal-node? v-search link-node) resolve-goal-node?)
                                                     (ghl-resolve-goal-found v-search link-node)
                                                     (deck-push link-node v-deck)))))
                                           (setf done2 (or (not valid2) *graphl-finished?*))))))
                                (when final-index-iterator
                                  (destroy-final-index-iterator final-index-iterator)))))
                          (setf done (or (not valid) *graphl-finished?*))))))))))))))
  v-deck)

;; (defun ghl-predicate-relation-within-multiple-searches-p (pred node1 node2 searches mt &optional tv return-non-transitive-results?) ...) -- commented declareFunction, no body
;; (defun ghl-path-from-node-to-node-within-previous-searches (pred node1 node2 searches direction mt) ...) -- commented declareFunction, no body
;; (defun ghl-unmark-closure-in-space-and-map (v-search node direction space fn) ...) -- commented declareFunction, no body
;; (defun why-ghl-predicate-relation-p (pred node1 node2 &optional mt tv) ...) -- commented declareFunction, no body

(defun why-gt-predicate-relation-p (pred node1 node2 &optional mt tv)
  "[Cyc] Return the justification for why PRED transitively relates NODE1 to NODE2."
  (let ((result nil))
    (with-inference-mt-relevance (mt)
      (cond
        ((and (equal node1 node2) (reflexive-binary-predicate-p pred))
         (setf result (list (make-hl-support :reflexive
                                             (make-binary-formula pred node1 node2)
                                             mt tv))))
        ((and (equal node1 node2) (irreflexive-binary-predicate-p pred))
         (setf result nil))
        (t
         (let* ((direction (ghl-direction-for-predicate-relation pred))
                (forward? (ghl-forward-direction-p direction))
                (start-node (if forward? node1 node2))
                (goal-node (if forward? node2 node1))
                (v-search (new-ghl-search (list :predicates (list pred)
                                                :order :breadth-first
                                                :type :transitive-reasoning
                                                :direction direction
                                                :tv tv
                                                :marking :simple
                                                :goal-search-p t
                                                :goal (list goal-node)
                                                :justify? t))))
           (reset-graphl-finished)
           (let ((search-deck (if (ghl-depth-first-search-p v-search)
                                  (create-deck :stack)
                                  (create-deck :queue))))
             (ghl-mark-node v-search start-node :start)
             (gt-why-predicate-relation-p-add-accessible-link-nodes-to-deck
              v-search start-node nil search-deck t)
             (unless (deck-empty-p search-deck)
               (destructuring-bind (node supports) (deck-pop search-deck)
                 (loop until (or *graphl-finished?* (null node)) do
                   (let ((mark (get-ghl-marking v-search node)))
                     (cond
                       ((null mark)
                        (ghl-mark-node v-search node t)
                        (gt-why-predicate-relation-p-add-accessible-link-nodes-to-deck
                         v-search node supports search-deck t))
                       ((eq mark :start)
                        (ghl-mark-node v-search node t))))
                   (let ((popped (deck-pop search-deck)))
                     (setf node (first popped))
                     (setf supports (second popped)))))))
           (setf result (ghl-result v-search))
           (destroy-ghl-search v-search)))))
    result))

(defun gt-why-predicate-relation-p-add-accessible-link-nodes-to-deck
    (v-search node supports v-deck resolve-goal-node?)
  "[Cyc] Extend deck with accessible link nodes, adding a justification (ASSERTION . SUPPORTS) when resolving goal nodes."
  ;; Direct port of ghl_search_methods.java:1274-1470. do-gt-accessible-link-nodes
  ;; is expanded inline. Structurally identical to gt-predicate-relation-p-add-accessible-
  ;; link-nodes-to-deck, but at each assertion the justification carries (assertion . supports).
  (let ((pred (first (ghl-relevant-predicates v-search)))
        (truth (tv-truth (ghl-tv v-search)))
        (strength (tv-strength (ghl-tv v-search))))
    (let ((*gt-args-swapped-p* nil))
      (unless *graphl-finished?*
        (dolist (search-direction (determine-graphl-relevant-directions (ghl-direction v-search)))
          (when *graphl-finished?* (return))
          (let* ((index-argnum (gt-index-argnum-for-direction search-direction))
                 (gather-argnum (other-binary-arg index-argnum)))
            ;; Unswapped pass
            (let ((*gt-relevant-pred* pred)
                  (*relevant-pred-function* #'relevant-pred-wrt-gt?))
              (let ((pred-var nil))
                (when (do-gaf-arg-index-key-validator node index-argnum pred-var)
                  (let ((iterator-var (new-gaf-arg-final-index-spec-iterator node index-argnum pred-var))
                        (done *graphl-finished?*)
                        (token nil))
                    (loop until done do
                      (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token))
                             (valid (not (eq token final-index-spec))))
                        (when valid
                          (let ((final-index-iterator nil))
                            (unwind-protect
                                 (progn
                                   (setf final-index-iterator
                                         (new-final-index-iterator final-index-spec :gaf truth nil))
                                   (let ((done2 *graphl-finished?*) (token2 nil))
                                     (loop until done2 do
                                       (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token2))
                                              (valid2 (not (eq token2 assertion))))
                                         (when valid2
                                           (when (or (not (assertion-p assertion))
                                                     (el-strength-implies (assertion-strength assertion) strength))
                                             (let ((link-node (formula-arg assertion gather-argnum nil)))
                                               (if (and (ghl-goal-node? v-search link-node) resolve-goal-node?)
                                                   (let ((justification (ghl-create-justification v-search (cons assertion supports))))
                                                     (ghl-resolve-goal-found v-search link-node)
                                                     (ghl-add-justification-to-result v-search justification))
                                                   (deck-push (list link-node (cons assertion supports)) v-deck)))))
                                         (setf done2 (or (not valid2) *graphl-finished?*))))))
                              (when final-index-iterator
                                (destroy-final-index-iterator final-index-iterator)))))
                        (setf done (or (not valid) *graphl-finished?*))))))))
            ;; Swapped pass (only when ghl-uses-spec-preds-p)
            (when (ghl-uses-spec-preds-p)
              (let ((*gt-args-swapped-p* t)
                    (*gt-relevant-pred* pred)
                    (*relevant-pred-function* #'relevant-pred-wrt-gt?))
                (let ((pred-var nil))
                  (when (do-gaf-arg-index-key-validator node gather-argnum pred-var)
                    (let ((iterator-var (new-gaf-arg-final-index-spec-iterator node gather-argnum pred-var))
                          (done *graphl-finished?*)
                          (token nil))
                      (loop until done do
                        (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token))
                               (valid (not (eq token final-index-spec))))
                          (when valid
                            (let ((final-index-iterator nil))
                              (unwind-protect
                                   (progn
                                     (setf final-index-iterator
                                           (new-final-index-iterator final-index-spec :gaf truth nil))
                                     (let ((done2 *graphl-finished?*) (token2 nil))
                                       (loop until done2 do
                                         (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token2))
                                                (valid2 (not (eq token2 assertion))))
                                           (when valid2
                                             (when (or (not (assertion-p assertion))
                                                       (el-strength-implies (assertion-strength assertion) strength))
                                               (let ((link-node (formula-arg assertion index-argnum nil)))
                                                 (if (and (ghl-goal-node? v-search link-node) resolve-goal-node?)
                                                     (let ((justification (ghl-create-justification v-search (cons assertion supports))))
                                                       (ghl-resolve-goal-found v-search link-node)
                                                       (ghl-add-justification-to-result v-search justification))
                                                     (deck-push (list link-node (cons assertion supports)) v-deck)))))
                                           (setf done2 (or (not valid2) *graphl-finished?*))))))
                                (when final-index-iterator
                                  (destroy-final-index-iterator final-index-iterator)))))
                          (setf done (or (not valid) *graphl-finished?*))))))))))))))
  v-deck)

;; (defun ghl-max-floor-mts-of-predicate-paths (pred node1 node2 &optional mt) ...) -- commented declareFunction, no body
;; (defun gt-max-floor-mts-of-predicate-paths (pred node1 node2 &optional mt) ...) -- commented declareFunction, no body
;; (defun gt-max-floor-mts-of-predicate-paths-add-accessible-link-nodes-to-deck (v-search node supports v-deck) ...) -- commented declareFunction, no body
;; (defun gt-max-floor-mts-of-predicate-paths-supports-still-relevant? (v-search supports) ...) -- commented declareFunction, no body
;; (defun gt-max-floor-mts-of-predicate-paths-support-still-relevant? (v-search support) ...) -- commented declareFunction, no body
