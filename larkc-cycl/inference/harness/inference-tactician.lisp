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

(defun strategy-do-one-step (strategy)
  (strategy-possibly-auto-prune strategy)
  (within-controlling-strategy strategy
    (increment-inference-step-count (strategy-inference strategy))
    (increment-inference-cumulative-step-count (strategy-inference strategy))
    (strategy-dispatch strategy :do-one-step))
  nil)

(defun strategy-done? (strategy)
  (strategy-dispatch strategy :done?))

(defun strategy-note-tactic-finished (strategy tactic)
  "[Cyc] Called after all A-Brain consequences of a tactic have been followed through."
  (problem-note-tactic-not-strategically-possible (tactic-problem tactic) tactic strategy)
  (consider-strategic-ramifications-of-executed-tactic strategy tactic)
  nil)

(defun strategy-possibly-activate-problem (strategy problem)
  (strategy-dispatch strategy :possibly-activate-problem problem))

(defun strategy-note-argument-link-added (strategy link)
  "[Cyc] Gets called actually before stuff starts propagating from LINK"
  (strategy-dispatch strategy :new-argument-link link))

;; (defun strategy-do-problem-store-prune (strategy) ...) -- active declareFunction, no body

(defparameter *strategy-auto-prune-threshold* nil
  "[Cyc] Useful for testing problem-store-pruning.")

(defvar *strategy-auto-prune-step-count* 0)

(defun clear-strategy-step-count ()
  (setf *strategy-auto-prune-step-count* 0)
  nil)

(defun strategy-possibly-auto-prune (strategy)
  (inference-possibly-prune-processed-proofs (strategy-inference strategy))
  (when *strategy-auto-prune-threshold*
    (when (>= *strategy-auto-prune-step-count* *strategy-auto-prune-threshold*)
      ;; Likely calls problem-store-prune on the strategy's problem store -- evidence:
      ;; the threshold guards a pruning call, and clear-strategy-step-count follows.
      (missing-larkc 35331)
      (clear-strategy-step-count))
    (setf *strategy-auto-prune-step-count*
          (+ *strategy-auto-prune-step-count* 1))
    (return-from strategy-possibly-auto-prune *strategy-auto-prune-step-count*))
  nil)

(defparameter *strategy-sort-strategy* nil)
(defparameter *strategy-sort-predicate* nil)

(defun strategy-sort (strategy sequence predicate)
  "[Cyc] Stable-sort SEQUENCE wrt STRATEGY using PREDICATE as the comparison function.
PREDICATE must have an arg-signature of (OBJ1 OBJ2 STRATEGY)."
  (declare (type strategy-p strategy))
  (let ((*strategy-sort-strategy* strategy)
        (*strategy-sort-predicate* predicate))
    (setf sequence (stable-sort sequence #'strategy-sort-predicate?)))
  sequence)

(defun strategy-sort-predicate? (object1 object2)
  (funcall *strategy-sort-predicate* object1 object2 *strategy-sort-strategy*))

(defun tactic-strategic-productivity-< (tactic1 tactic2 strategy)
  (productivity-< (tactic-strategic-productivity tactic1 strategy)
                  (tactic-strategic-productivity tactic2 strategy)))

(defun logical-tactic-better-wrt-removal? (logical-tactic1 logical-tactic2 strategy)
  (let ((lookahead-problem1 (logical-tactic-lookahead-problem-wrt-removal logical-tactic1 strategy))
        (lookahead-problem2 (logical-tactic-lookahead-problem-wrt-removal logical-tactic2 strategy)))
    (productivity-< (memoized-problem-max-removal-productivity lookahead-problem1 strategy)
                    (memoized-problem-max-removal-productivity lookahead-problem2 strategy))))

(defun logical-tactic-lookahead-problem-wrt-removal (logical-tactic strategy)
  (if (join-tactic-p logical-tactic)
      (multiple-value-bind (first-problem second-problem)
          (join-tactic-lookahead-problems logical-tactic)
        (if (productivity-< (memoized-problem-max-removal-productivity first-problem strategy)
                            (memoized-problem-max-removal-productivity second-problem strategy))
            second-problem
            first-problem))
      (logical-tactic-lookahead-problem logical-tactic)))

(defun controlling-strategic-context (strategic-context)
  "[Cyc] @return strategy-p or :tactical
@see controlling-strategy"
  (if (eq :tactical strategic-context)
      :tactical
      (controlling-strategy strategic-context)))

(defun controlling-strategy (strategy)
  "[Cyc] @return strategy-p; the controlling strategy of STRATEGY.  May be STRATEGY itself
if STRATEGY is not a substrategy of some other strategy."
  (simplest-inference-strategy (strategy-inference strategy)))

(defun controlling-strategy? (strategy)
  "[Cyc] @return booleanp; whether STRATEGY is a substrategy of some other strategy."
  (and (strategy-p strategy)
       (eq strategy (controlling-strategy strategy))))

(defun substrategy? (strategy)
  "[Cyc] @return booleanp; whether STRATEGY is a substrategy of some other strategy."
  (and (strategy-p strategy)
       (not (eq strategy (controlling-strategy strategy)))))

(defun strategy-controls-problem-store? (strategy)
  (and (controlling-strategy? strategy)
       (inference-problem-store-private? (strategy-inference strategy))))

;;; Macro: do-problem-unsubsumed-tactics
;; Reconstructed from Internal Constants:
;; $list9 = arglist: ((TACTIC-VAR PROBLEM STRATEGIC-CONTEXT &KEY STATUS HL-MODULE TYPE DONE) &BODY BODY)
;; $sym19 = DO-PROBLEM-TACTICS (inner iteration macro)
;; $sym21 = PROBLEM-VAR (uninternedSymbol), $sym22 = TYPE-VAR (uninternedSymbol),
;; $sym23 = SUBSUMING-JOIN-ORDERED-TACTICS (uninternedSymbol)
;; $sym24 = CLET, $sym25 = PROBLEM-MAXIMAL-SUBSUMING-MULTI-FOCAL-LITERAL-JOIN-ORDERED-TACTICS
;; $sym26 = PUNLESS (→ unless), $sym27 = SOME-SUBSUMING-JOIN-ORDERED-TACTIC?
;; Verified from expansion sites in inference_balanced_tactician_motivation.java lines 1422-1429
;; and removal_tactician_motivation.java lines 765-772.
(defmacro do-problem-unsubsumed-tactics ((tactic-var problem strategic-context
                                          &key status hl-module type done)
                                         &body body)
  (with-temp-vars (problem-var type-var subsuming-join-ordered-tactics)
    `(let ((,problem-var ,problem)
           (,type-var ,type))
       (let ((,subsuming-join-ordered-tactics
               (problem-maximal-subsuming-multi-focal-literal-join-ordered-tactics ,problem-var ,type-var)))
         (do-problem-tactics (,tactic-var ,problem-var
                              :type ,type-var
                              :status ,status
                              :hl-module ,hl-module
                              :done ,done)
           (unless (some-subsuming-join-ordered-tactic? ,tactic-var ,subsuming-join-ordered-tactics ,strategic-context)
             ,@body))))))

(defun problem-maximal-subsuming-multi-focal-literal-join-ordered-tactics (problem relevant-tactic-type)
  (let ((result nil))
    (when (or (null relevant-tactic-type)
              (eq relevant-tactic-type :join-ordered)
              (eq relevant-tactic-type :connected-conjunction))
      (do-problem-tactics (join-ordered-tactic problem :type :join-ordered)
        (unless (single-focal-literal-join-ordered-tactic-p join-ordered-tactic)
          (push join-ordered-tactic result)))
      (setf result (delete-subsumed-items result #'join-ordered-tactic-subsumes?))
      (setf result (nreverse result)))
    result))

(defun some-subsuming-join-ordered-tactic? (join-ordered-tactic subsuming-join-ordered-tactics strategic-context)
  (declare (ignore strategic-context))
  (let ((subsumed? nil))
    (when subsuming-join-ordered-tactics
      (when (join-ordered-tactic-p join-ordered-tactic)
        (dolist (candidate-subsuming-tactic subsuming-join-ordered-tactics)
          (when subsumed?
            (return))
          (unless (eq join-ordered-tactic candidate-subsuming-tactic)
            ;; Likely checks whether candidate-subsuming-tactic subsumes join-ordered-tactic
            ;; for a join-ordered relationship -- evidence: this is the subsuming filter
            ;; for do-problem-unsubsumed-tactics.
            (when (missing-larkc 36368)
              ;; Likely checks whether the tactic is strategically uninteresting after
              ;; subsumption -- evidence: the double-filter pattern (subsumes + not-interesting).
              (unless (missing-larkc 35446)
                (setf subsumed? t)))))))
    subsumed?))

;; (defun consider-subsumed-join-ordered-tactic? (join-ordered-tactic subsuming-join-ordered-tactic strategic-context) ...) -- active declareFunction, no body
;; (defun select-problem-tactic (problem strategy completeness-preference productivity-preference removal-completeness-preference &optional transformation-completeness-preference transformation-productivity-preference join-ordered-completeness-preference join-ordered-productivity-preference) ...) -- active declareFunction, no body
;; (defun choose-between-tactics (tactic1 tactic2 strategy preference-function) ...) -- active declareFunction, no body
;; (defun select-best-tactic-for-problem (problem strategy &optional completeness-preference productivity-preference transformation-completeness-preference transformation-productivity-preference) ...) -- active declareFunction, no body
;; (defun productivity-and-completeness-worse? (productivity1 completeness1 productivity2 completeness2) ...) -- active declareFunction, no body
;; (defun productivity-and-completeness-better? (productivity1 completeness1 productivity2 completeness2) ...) -- active declareFunction, no body
;; (defun tactic-productivity-and-completeness-worse? (tactic1 tactic2 strategy) ...) -- active declareFunction, no body
;; (defun tactic-productivity-and-completeness-better? (tactic1 tactic2 strategy) ...) -- active declareFunction, no body
;; (defun tactic-productivity-and-completeness-sufficiently-good? (tactic strategy) ...) -- active declareFunction, no body
;; (defun choose-less-productive-tactic (tactic1 tactic2 strategy) ...) -- active declareFunction, no body
;; (defun tactic-productivity-higher? (tactic1 tactic2 strategy) ...) -- active declareFunction, no body
;; (defun tactic-productivity-lower? (tactic1 tactic2 strategy) ...) -- active declareFunction, no body
;; (defun tactic-productivity-sufficiently-good? (tactic strategy) ...) -- active declareFunction, no body
;; (defun early-removal-productivity-limit (strategy) ...) -- active declareFunction, no body
;; (defun strategy-early-removal-productivity-limit (strategy) ...) -- active declareFunction, no body
;; (defun candidate-early-removal-tactic? (tactic) ...) -- active declareFunction, no body
;; (defun join-ordered-tactic-early-removal-cheap? (join-ordered-tactic) ...) -- active declareFunction, no body
;; (defun join-ordered-link-early-removal-cheap? (join-ordered-link problem) ...) -- active declareFunction, no body
;; (defun problem-has-a-non-sksi-tactic? (problem) ...) -- active declareFunction, no body
;; (defun strategy-quiesce (strategy) ...) -- active declareFunction, no body

(deflexical *sufficiently-good-tactic-productivity-threshold* 10
  "[Cyc] The total productivity threshold below or equal to which we don't bother
looking for anything better, and quit early.")

(defvar *default-early-removal-productivity-limit*
  (productivity-for-number-of-children *transformation-early-removal-threshold*))

(defun strategy-execute-tactic (strategy tactic)
  "[Cyc] Execute TACTIC under the control of STRATEGY.
Return TACTIC."
  (declare (type strategy-p strategy))
  (declare (type tactic-p tactic))
  (when (tactic-possible? tactic)
    (inference-note-tactic-executed (strategy-inference strategy) tactic)
    (within-controlling-strategy strategy
      (execute-tactic tactic))
    (return-from strategy-execute-tactic tactic))
  nil)

(defun strategy-possibly-execute-tactic (strategy tactic)
  "[Cyc] @return booleanp; whether STRATEGY actually just executed TACTIC."
  (sublisp-boolean (strategy-execute-tactic strategy tactic)))

;; (defun strategy-make-problem-set-aside (strategy problem) ...) -- active declareFunction, no body
;; (defun possibly-clear-strategic-status-wrt (problem strategy) ...) -- active declareFunction, no body
;; (defun clear-strategic-status-wrt (problem strategy) ...) -- active declareFunction, no body

(defparameter *set-aside-non-continuable-implies-throw-away?* t
  "[Cyc] Whether :set-aside plus non-continuable should be strengthened to :throw-away")

(defun strategy-throw-away-uninteresting-set-asides (strategy)
  (strategy-dispatch strategy :throw-away-uninteresting-set-asides))

(defun strategy-throws-away-all-transformation? (strategy)
  "[Cyc] Return T iff STRATEGY would throw away all transformation."
  (or (not (problem-store-transformation-allowed? (strategy-problem-store strategy)))
      (and *set-aside-non-continuable-implies-throw-away?*
           (not (inference-continuable? (strategy-inference strategy)))
           (strategy-sets-aside-all-transformation? strategy))))

(defun strategy-sets-aside-all-transformation? (strategy)
  "[Cyc] Return T iff STRATEGY would set aside all transformation."
  (not (problem-transformation-allowed-wrt-max-transformation-depth?
        (strategy-inference strategy)
        (strategy-root-problem strategy))))

(defun strategy-continuation-possible? (strategy)
  "[Cyc] @return booleanp; Whether STRATEGY deems continuation possible.
This is usually true whenn STRATEGY has some set-aside problems to continue work on."
  (strategy-dispatch strategy :continuation-possible?))

(defvar *better-term-chosen-handling?* t)

(defvar *better-backchain-forbidden-when-unbound-in-arg-handling?* nil
  "[Cyc] Temporary control parameter, not ready yet, should stay NIL for now")

(defun better-term-chosen-handling? ()
  *better-term-chosen-handling?*)

;; (defun transformation-link-leads-to-term-chosen-dead-end? (transformation-link) ...) -- active declareFunction, no body
;; (defun transformation-link-term-chosen-dead-end-vars (transformation-link) ...) -- active declareFunction, no body
;; (defun problem-term-chosen-dead-end-vars (problem) ...) -- active declareFunction, no body
;; (defun all-restricted-non-focals-around-transformation-link (transformation-link) ...) -- active declareFunction, no body
;; (defun supported-problem-needed-term-chosen-vars (problem-link) ...) -- active declareFunction, no body
;; (defun focal-problem-binds-all-vars? (focal-problem vars) ...) -- active declareFunction, no body
;; (defun strategem-p (object) ...) -- active declareFunction, no body

(defun executable-strategem-p (object)
  (or (content-tactic-p object)
      (meta-structural-tactic-p object)))

(defun strategem-invalid-p (strategem)
  (cond ((tactic-p strategem)
         (tactic-invalid-p strategem))
        ((problem-link-p strategem)
         (problem-link-invalid-p strategem))
        ((problem-p strategem)
         (problem-invalid-p strategem))
        (t (error "Unexpected strategem type ~s" strategem))))

(defun strategem-problem (strategem)
  "[Cyc] @return nil or problem-p.  It will be NIL for an answer link"
  (cond ((tactic-p strategem)
         (tactic-problem strategem))
        ((problem-link-p strategem)
         (problem-link-supported-problem strategem))
        ((problem-p strategem)
         strategem)
        (t (error "Unexpected strategem type ~s" strategem))))

;; (defun motivation-strategem-p (object) ...) -- active declareFunction, no body

(defun motivation-strategem-link-p (object)
  "[Cyc] Strategems that make a new root.
The answer link is a special case of a new root, because the root problem
doesn't necessarily have T."
  (or (transformation-link-p object)
      (answer-link-p object)))

;; (defun removal-strategem-p (object) ...) -- active declareFunction, no body
;; (defun transformation-strategem-p (object) ...) -- active declareFunction, no body

(defun inference-strategy-type (strategy-type plist)
  "[Cyc] Declares a strategy type to the inference engine."
  (new-strategy-type strategy-type plist))

(defun strategy-type-dispatch-handler (strategy-type method-type)
  "[Cyc] @return function-spec-p"
  (strategy-type-property strategy-type method-type))

;; (defun happiness-p (happiness) ...) -- active declareFunction, no body

(defun happiness-= (happiness1 happiness2)
  (potentially-infinite-integer-= happiness1 happiness2))

(defun happiness-< (happiness1 happiness2)
  (potentially-infinite-integer-< happiness1 happiness2))

(defun happiness-> (happiness1 happiness2)
  (potentially-infinite-integer-> happiness1 happiness2))

;; (defun happiness-min (happiness1 happiness2) ...) -- active declareFunction, no body
;; (defun happiness-max (happiness1 happiness2) ...) -- active declareFunction, no body
;; (defun minimal-happiness () ...) -- active declareFunction, no body
;; (defun problem-happiness-index-p (object) ...) -- active declareFunction, no body

(defun new-problem-happiness-index ()
  (let ((happiness-to-objects (make-hash-table :test #'eql))
        (greatest-happiness-index (create-p-queue nil #'identity #'happiness->)))
    (vector happiness-to-objects greatest-happiness-index)))

(defun problem-happiness-index-empty-p (happiness-index)
  (let ((greatest-happiness-index (aref happiness-index 1)))
    (p-queue-empty-p greatest-happiness-index)))

(defun problem-happiness-index-add (happiness-index happiness object)
  (declare (type happiness-p happiness))
  (let* ((happiness-to-objects (aref happiness-index 0))
         (object-stack (gethash happiness happiness-to-objects)))
    (unless object-stack
      (setf object-stack (create-stack))
      (setf (gethash happiness happiness-to-objects) object-stack))
    (when (stack-empty-p object-stack)
      (let ((greatest-happiness-index (aref happiness-index 1)))
        (p-enqueue happiness greatest-happiness-index)))
    (stack-push object object-stack))
  happiness-index)

(defun problem-happiness-index-peek (happiness-index)
  (let ((object nil)
        (expected-happiness nil)
        (happiness-to-objects (aref happiness-index 0))
        (greatest-happiness-index (aref happiness-index 1))
        (greatest-happiness (p-queue-best (aref happiness-index 1))))
    (declare (ignore greatest-happiness-index))
    (let ((object-stack (gethash greatest-happiness happiness-to-objects :error)))
      (cond ((eq :error object-stack)
             (error "No object-stack for happiness ~S" greatest-happiness))
            ((stack-empty-p object-stack)
             (error "No objects for happiness ~S" greatest-happiness))
            (t
             (setf object (stack-peek object-stack))
             (setf expected-happiness greatest-happiness))))
    (values object expected-happiness)))

(defun problem-happiness-index-next (happiness-index)
  (let ((object nil)
        (expected-happiness nil)
        (happiness-to-objects (aref happiness-index 0))
        (greatest-happiness-index (aref happiness-index 1))
        (greatest-happiness (p-queue-best (aref happiness-index 1))))
    (let ((object-stack (gethash greatest-happiness happiness-to-objects :error)))
      (cond ((eq :error object-stack)
             (error "No object-stack for happiness ~S" greatest-happiness))
            ((stack-empty-p object-stack)
             (error "No objects for happiness ~S" greatest-happiness))
            (t
             (setf object (stack-pop object-stack))
             (setf expected-happiness greatest-happiness)
             (when (stack-empty-p object-stack)
               (let ((removed-happiness (p-dequeue greatest-happiness-index)))
                 (must (happiness-= removed-happiness greatest-happiness)
                       "Removed ~S but ~S was lowest happiness"
                       removed-happiness greatest-happiness))))))
    (values object expected-happiness)))

;; (defun problem-happiness-index-contents (happiness-index) ...) -- active declareFunction, no body

(defun strategy-initialize-properties (strategy strategy-static-properties)
  (strategy-dispatch strategy :initialize-properties strategy-static-properties))

(defun default-strategy-initialize-properties (strategy strategy-static-properties)
  (set-strategy-properties strategy strategy-static-properties)
  nil)

(defun strategy-update-properties (strategy strategy-dynamic-properties)
  (strategy-dispatch strategy :update-properties strategy-dynamic-properties))

(defun default-strategy-update-properties (strategy strategy-dynamic-properties)
  (set-strategy-properties strategy strategy-dynamic-properties)
  nil)

(defun strategy-note-inference-dynamic-properties-updated (strategy)
  "[Cyc] Callback for STRATEGY to note that its inference's dynamic properties have been updated."
  (strategy-dispatch strategy :inference-dynamic-properties-updated))

(defun default-strategy-note-inference-dynamic-properties-updated (strategy)
  (note-strategy-should-reconsider-set-asides strategy)
  nil)

(defun strategy-initial-relevant-strategies (strategy)
  "[Cyc] By default, this is simply the list (STRATEGY), but can be overridden"
  (strategy-dispatch strategy :initial-relevant-strategies))

(defun default-strategy-initial-relevant-strategies (strategy)
  (list strategy))

(defun strategy-note-split-tactics-strategically-possible (strategy split-tactics)
  (strategy-dispatch strategy :split-tactics-possible split-tactics))

(defun strategy-note-tactic-discarded (strategy tactic)
  (unless (simple-strategy-chooses-to-ignore-tactic? strategy tactic)
    (problem-note-tactic-not-strategically-possible (tactic-problem tactic) tactic strategy))
  nil)

(defun strategy-note-new-tactic (strategy tactic)
  "[Cyc] Depending on what type of tactic TACTIC is,
compute its strategic properties wrt STRATEGY."
  (strategy-dispatch strategy :new-tactic tactic))

(defun strategy-no-possible-strategems-for-problem? (strategy problem)
  (strategy-dispatch strategy :problem-nothing-to-do? problem))

(defun strategy-consider-that-problem-could-be-strategically-pending (strategy problem)
  (strategy-dispatch strategy :problem-could-be-pending problem))

(defun strategy-consider-that-problem-could-be-no-good (strategy problem consider-deep? consider-transformation-tactics?)
  (default-consider-that-problem-could-be-no-good strategy problem consider-deep? consider-transformation-tactics?))

;; (defun strategy-reconsider-set-asides (strategy) ...) -- active declareFunction, no body
;; (defun substrategy-do-one-step (strategy) ...) -- active declareFunction, no body
;; (defun substrategy-peek-next-strategem (strategy) ...) -- active declareFunction, no body
;; (defun substrategy-motivate-strategem (strategy strategem) ...) -- active declareFunction, no body
;; (defun substrategy-activate-strategem (strategy strategem) ...) -- active declareFunction, no body
;; (defun substrategy-link-head-motivated? (strategy link) ...) -- active declareFunction, no body
;; (defun substrategy-reconsider-split-set-asides (strategy split-tactic) ...) -- active declareFunction, no body

;;; Setup phase

(toplevel
  (note-funcall-helper-function 'strategy-sort-predicate?)
  (note-funcall-helper-function 'tactic-strategic-productivity-<)
  (note-funcall-helper-function 'logical-tactic-better-wrt-removal?)
  (register-macro-helper 'problem-maximal-subsuming-multi-focal-literal-join-ordered-tactics
                         'do-problem-unsubsumed-connected-conjunction-tactics)
  (register-macro-helper 'some-subsuming-join-ordered-tactic?
                         'do-problem-unsubsumed-connected-conjunction-tactics)
  (note-funcall-helper-function 'tactic-productivity-and-completeness-worse?)
  (note-funcall-helper-function 'tactic-productivity-higher?)
  (note-funcall-helper-function 'tactic-productivity-lower?)
  (note-funcall-helper-function 'tactic-productivity-sufficiently-good?)
  (note-funcall-helper-function 'default-strategy-initialize-properties)
  (note-funcall-helper-function 'default-strategy-update-properties)
  (note-funcall-helper-function 'default-strategy-note-inference-dynamic-properties-updated))
