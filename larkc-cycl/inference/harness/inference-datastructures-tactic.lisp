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

(defvar *leviathan-avoid-logical-tactic-productivity-computation?* nil
  "[Cyc] When non-nil, we don't bother to compute the tactic productivity for logical tactics.")


;;; Struct: tactic

(defstruct (tactic
            (:conc-name "tact-")
            (:constructor make-tactic (&key suid problem type hl-module
                                            completeness preference-level-justification
                                            productivity original-productivity
                                            status progress-iterator data)))
  suid
  problem
  type
  hl-module
  completeness
  preference-level-justification
  productivity
  original-productivity
  status
  progress-iterator
  data)

;; Reconstructed print-object from Internal Constants:
;; $str44 = "<Invalid TACTIC ~s>"
;; $str45 = "<~a TACTIC ~a.~a.~a:(~a ~a)>"
;; Pattern: status TACTIC store-suid.problem-suid.tactic-suid:(type module-name)
(defmethod print-object ((object tactic) stream)
  (if (eq :free (tact-status object))
      (format stream "<Invalid TACTIC ~s>" (tact-suid object))
      (format stream "<~a TACTIC ~a.~a.~a:(~a ~a)>"
              (tact-status object)
              (when (tact-problem object)
                (problem-store-suid (problem-store (tact-problem object))))
              (when (tact-problem object)
                (prob-suid (tact-problem object)))
              (tact-suid object)
              (tact-type object)
              (when (tact-hl-module object)
                (hl-module-name (tact-hl-module object))))))

(defun sxhash-tactic-method (object)
  (let ((problem (tactic-problem object)))
    (if (valid-problem-p problem)
        (logxor (problem-suid problem) (tactic-suid object))
        0)))


;;; Constructor & lifecycle

(defun valid-tactic-p (tactic)
  (and (tactic-p tactic)
       (not (tactic-invalid-p tactic))))

(defun tactic-invalid-p (tactic)
  (eq :free (tactic-status tactic)))

;; (defun print-tactic (object stream depth) ...) -- active declareFunction, no body

(defun new-tactic (problem hl-module &optional data)
  "[Cyc] Create a new tactic for PROBLEM using HL-MODULE."
  (declare (type problem problem))
  (let ((tactic (make-tactic))
        (suid (problem-next-tactic-suid problem)))
    (setf (tact-suid tactic) suid)
    (setf (tact-problem tactic) problem)
    (setf (tact-type tactic) (tactic-type-from-hl-module hl-module))
    (setf (tact-hl-module tactic) hl-module)
    (set-tactic-status tactic :possible)
    (setf (tact-progress-iterator tactic) nil)
    (set-tactic-data tactic data)
    (add-problem-tactic problem tactic)
    (increment-tactic-historical-count)
    tactic))

(defun destroy-problem-tactic (tactic)
  (when (valid-tactic-p tactic)
    (destroy-tactic-progress-iterator tactic)
    (note-tactic-invalid tactic)
    (destroy-tactic-int tactic)))

;; (defun destroy-problem-tactic-and-backpointers (tactic) ...) -- active declareFunction, no body

(defun destroy-tactic-progress-iterator (tactic)
  (let ((progress-iterator (tactic-progress-iterator tactic)))
    (when (tactic-progress-iterator-p progress-iterator)
      (finalize-tactic-progress-iterator progress-iterator)
      (setf (tact-progress-iterator tactic) nil)))
  tactic)

(defun destroy-tactic-int (tactic)
  (setf (tact-data tactic) :free)
  (setf (tact-progress-iterator tactic) :free)
  (setf (tact-completeness tactic) :free)
  (setf (tact-preference-level-justification tactic) :free)
  (setf (tact-productivity tactic) :free)
  (setf (tact-original-productivity tactic) :free)
  (setf (tact-hl-module tactic) :free)
  (setf (tact-problem tactic) :free)
  nil)

(defun note-tactic-invalid (tactic)
  (setf (tact-status tactic) :free)
  tactic)


;;; Accessors

(defun tactic-suid (tactic)
  "[Cyc] Return an SUID for tactic that is unique wrt its problem."
  (declare (type tactic tactic))
  (tact-suid tactic))

(defun tactic-problem (tactic)
  (declare (type tactic tactic))
  (tact-problem tactic))

(defun tactic-hl-module (tactic)
  (declare (type tactic tactic))
  (tact-hl-module tactic))

(defun tactic-type (tactic)
  "[Cyc] @return tactic-type-p; the type of tactic, deducible from HL-MODULE, but stored anyway for efficiency"
  (declare (type tactic tactic))
  (tact-type tactic))

(defun tactic-completeness (tactic)
  (declare (type tactic tactic))
  (let ((completeness-or-preference (tact-completeness tactic)))
    (when (preference-level-p completeness-or-preference)
      ;; Likely converts preference-level back to completeness
      (setf completeness-or-preference (missing-larkc 32938)))
    completeness-or-preference))

(defun tactic-preference-level (tactic)
  (declare (type tactic tactic))
  (let ((completeness-or-preference (tact-completeness tactic)))
    (when (completeness-p completeness-or-preference)
      (setf completeness-or-preference
            (completeness-to-preference-level completeness-or-preference)))
    completeness-or-preference))

(defun tactic-preference-level-justification (tactic)
  (declare (type tactic tactic))
  (tact-preference-level-justification tactic))

(defun tactic-productivity (tactic)
  (declare (type tactic tactic))
  (when (and *leviathan-avoid-logical-tactic-productivity-computation?*
             (logical-tactic-p tactic))
    (error "tactical productivity being referenced on ~S" tactic))
  (tact-productivity tactic))

(defun tactic-original-productivity (tactic)
  (declare (type tactic tactic))
  (when (and *leviathan-avoid-logical-tactic-productivity-computation?*
             (logical-tactic-p tactic))
    (error "tactical productivity being referenced on ~S" tactic))
  (tact-original-productivity tactic))

(defun tactic-status (tactic)
  (declare (type tactic tactic))
  (tact-status tactic))

(defun tactic-progress-iterator (tactic)
  (declare (type tactic tactic))
  (tact-progress-iterator tactic))

(defun tactic-data (tactic)
  (declare (type tactic tactic))
  (tact-data tactic))


;;; Setters

(defun set-tactic-completeness (tactic completeness)
  (declare (type tactic tactic))
  (setf (tact-completeness tactic) completeness)
  (setf (tact-preference-level-justification tactic) "")
  tactic)

(defun set-tactic-preference-level (tactic preference-level justification)
  (declare (type tactic tactic))
  (setf (tact-completeness tactic) preference-level)
  (setf (tact-preference-level-justification tactic) justification)
  tactic)

(defun set-tactic-productivity (tactic productivity &optional (set-original? t))
  (declare (type tactic tactic))
  (when (and *leviathan-avoid-logical-tactic-productivity-computation?*
             (logical-tactic-p tactic))
    (return-from set-tactic-productivity tactic))
  (setf (tact-productivity tactic) productivity)
  (when set-original?
    (setf (tact-original-productivity tactic) productivity))
  tactic)

(defun set-tactic-status (tactic status)
  (declare (type tactic tactic))
  (setf (tact-status tactic) status)
  tactic)

(defun set-tactic-data (tactic data)
  (declare (type tactic tactic))
  (setf (tact-data tactic) data)
  tactic)

(defun set-meta-split-tactic-data (tactic data)
  (set-tactic-data tactic data))


;;; Macros

;; Reconstructed from Internal Constants:
;; $list57 = arglist ((strategy-var tactic) &body body)
;; $sym58 = DO-PROBLEM-RELEVANT-STRATEGIES, $sym59 = TACTIC-PROBLEM
;; Simple delegation: iterate strategies relevant to the tactic's problem.
(defmacro do-tactic-relevant-strategies ((strategy-var tactic) &body body)
  `(do-problem-relevant-strategies (,strategy-var (tactic-problem ,tactic))
     ,@body))

;; Reconstructed from Internal Constants:
;; $list60 = arglist ((sibling-tactic-var tactic &key done status completeness
;;                     preference-level hl-module type productivity) &body body)
;; $sym65 = TACTIC-VAR (uninternedSymbol), $sym66 = CLET, $sym67 = DO-PROBLEM-TACTICS,
;; $sym68 = PUNLESS
;; Iterates sibling tactics on the same problem, skipping the given tactic itself.
(defmacro do-tactic-sibling-tactics ((sibling-tactic-var tactic &key done status completeness
                                      preference-level hl-module type productivity)
                                     &body body)
  (with-temp-vars (tactic-var)
    `(let ((,tactic-var ,tactic))
       (do-problem-tactics (,sibling-tactic-var (tactic-problem ,tactic-var)
                            :done ,done :status ,status :completeness ,completeness
                            :preference-level ,preference-level :hl-module ,hl-module
                            :type ,type :productivity ,productivity)
         (unless (eq ,sibling-tactic-var ,tactic-var)
           ,@body)))))


;;; No-body stubs

;; (defun tactic-ids (tactic) ...) -- active declareFunction, no body
;; (defun find-tactic-by-id (problem tactic-suid) ...) -- active declareFunction, no body
;; (defun find-tactic-by-ids (store-id problem-id tactic-id) ...) -- active declareFunction, no body


;;; Query functions

(defun tactic-hl-module-name (tactic)
  (hl-module-name (tactic-hl-module tactic)))

(defun tactic-possible? (tactic)
  (eq :possible (tactic-status tactic)))

(defun tactic-in-progress? (tactic)
  (and (tactic-possible? tactic)
       (tactic-progress-iterator-p (tactic-progress-iterator tactic))))

(defun tactic-not-possible? (tactic)
  (not (tactic-possible? tactic)))

(defun tactic-executed? (tactic)
  (eq :executed (tactic-status tactic)))

(defun tactic-discarded? (tactic)
  (eq :discarded (tactic-status tactic)))

(defun tactic-has-status? (tactic status-spec)
  (case status-spec
    (:non-discarded (not (tactic-discarded? tactic)))
    (:in-progess (tactic-in-progress? tactic))
    (otherwise (eq status-spec (tactic-status tactic)))))

;; (defun abductive-tactic? (tactic) ...) -- active declareFunction, no body

(defun tactic-store (tactic)
  (problem-store (tactic-problem tactic)))

;; (defun tactic-problem-query (tactic) ...) -- active declareFunction, no body
;; (defun tactic-problem-sole-clause (tactic) ...) -- active declareFunction, no body


;;; Productivity

(defun update-tactic-productivity (tactic new-productivity)
  (set-tactic-productivity tactic new-productivity nil)
  tactic)

(defun decrement-tactic-productivity-for-number-of-children (tactic &optional (number 1))
  (let* ((old-productivity (tactic-productivity tactic))
         (new-productivity (decrement-productivity-for-number-of-children old-productivity number)))
    (setf new-productivity (max new-productivity 0))
    (set-tactic-productivity tactic new-productivity nil)
    new-productivity))


;;; Status transitions

(defun note-tactic-executed (tactic)
  (set-tactic-status tactic :executed)
  (increment-executed-tactic-historical-count)
  tactic)

(defun note-tactic-discarded (tactic)
  (clear-tactic-progress-iterator tactic)
  (set-tactic-status tactic :discarded)
  (increment-discarded-tactic-historical-count)
  tactic)

(defun note-tactic-progress-iterator (tactic progress-iterator)
  (setf (tact-progress-iterator tactic) progress-iterator)
  tactic)

(defun clear-tactic-progress-iterator (tactic)
  (destroy-tactic-progress-iterator tactic)
  tactic)

(defun tactic-in-progress-next (tactic)
  (let ((progress-iterator (tactic-progress-iterator tactic))
        (success? nil))
    (unwind-protect
         (unless (iteration-done progress-iterator)
           (iteration-next progress-iterator)
           (setf success? t))
      (when (or (null success?)
                (iteration-done progress-iterator))
        (when (tactic-possible? tactic)
          (clear-tactic-progress-iterator tactic))))
    success?))

(defun possibly-update-tactic-productivity-from-iterator (tactic output-iterator)
  (let ((number-of-children nil)
        (new-productivity nil))
    (when (list-iterator-p output-iterator)
      (setf number-of-children (list-iterator-size output-iterator)))
    (when number-of-children
      (setf new-productivity (productivity-for-number-of-children number-of-children)))
    (when (productivity-p new-productivity)
      (update-tactic-productivity tactic new-productivity)
      (return-from possibly-update-tactic-productivity-from-iterator t))
    nil))

;; (defun select-least-productive-tactic (tactics) ...) -- active declareFunction, no body
;; (defun total-productivity-of-tactics (tactics) ...) -- active declareFunction, no body
;; (defun total-productivity-of-problem-possible-tactics (problem) ...) -- active declareFunction, no body
;; (defun min-productivity-of-problem-possible-tactics (problem) ...) -- active declareFunction, no body

(defun note-tactic-most-recent-executed (tactic)
  (declare (type tactic tactic))
  (note-problem-store-most-recent-tactic-executed (tactic-store tactic) tactic)
  tactic)

;; (defun problem-store-tactic-execution-count (tactic) ...) -- active declareFunction, no body
;; (defun tactic-execution-count (tactic) ...) -- active declareFunction, no body


;;; Tactic progress iterators

(defun tactic-progress-iterator-p (object)
  (iterator-p object))

(defun new-tactic-progress-iterator (iteration-type tactic sub-state)
  (new-iterator (make-tactic-progress-iterator-state iteration-type tactic sub-state)
                #'tactic-progress-done?
                #'tactic-progress-next
                #'tactic-progress-finalize))

(defun make-tactic-progress-iterator-state (iteration-type tactic sub-state)
  (list sub-state iteration-type tactic))

(defun tactic-progress-done? (state)
  (destructuring-bind (current iteration-type tactic) state
    (declare (ignore tactic))
    (case iteration-type
      (:removal-expand
       (null current))
      (:removal-output-generate
       (destructuring-bind (output-iterator bindings) current
         (declare (ignore bindings))
         (iteration-done output-iterator)))
      (:conjunctive-removal-expand
       (null current))
      (:conjunctive-removal-expand-iterative
       (iteration-done current))
      (:transformation-rule-select
       (null current))
      (:meta-structural
       (meta-structural-progress-iterator-done? tactic))
      (otherwise
       (error "Time to implement tactic-progress-done? for ~S" iteration-type)))))

(defun tactic-progress-next (state)
  (destructuring-bind (current iteration-type tactic) state
    (case iteration-type
      (:removal-expand
       (let ((expand-result (first current))
             (update (rest current)))
         (rplaca state update)
         (let ((side-effect-result (handle-one-removal-tactic-expand-result tactic expand-result)))
           (values side-effect-result state))))
      (:removal-output-generate
       (destructuring-bind (output-iterator encoded-bindings) current
         (let ((side-effect-result (handle-one-removal-tactic-output-generate-result
                                    tactic output-iterator encoded-bindings)))
           (values side-effect-result state))))
      (:conjunctive-removal-expand
       (let ((expand-result (first current))
             (update (rest current)))
         (rplaca state update)
         ;; Likely handle-one-conjunctive-removal-tactic-expand-result
         (let ((side-effect-result (missing-larkc 36228)))
           (values side-effect-result state))))
      (:conjunctive-removal-expand-iterative
       ;; Likely handle-one-conjunctive-removal-tactic-expand-iterative-result
       (let ((side-effect-result (missing-larkc 36227)))
         (values side-effect-result state)))
      (:transformation-rule-select
       (let ((rule (first current))
             (update (rest current)))
         (rplaca state update)
         (let ((side-effect-result (handle-one-transformation-tactic-rule-select-result tactic rule)))
           (values side-effect-result state))))
      (:meta-structural
       (execute-meta-split-tactic tactic)
       (values nil state))
      (otherwise
       (error "Time to implement tactic-progress-next for ~S" iteration-type)))))

(defun tactic-progress-finalize (state)
  (destructuring-bind (current iteration-type tactic) state
    (declare (ignore tactic))
    (case iteration-type
      (:removal-expand
       t)
      (:removal-output-generate
       (destructuring-bind (output-iterator encoded-bindings) current
         (declare (ignore encoded-bindings))
         (iteration-finalize output-iterator)))
      (:conjunctive-removal-expand
       t)
      (:conjunctive-removal-expand-iterative
       (iteration-finalize current))
      (:transformation-rule-select
       t)
      (:meta-structural
       t)
      (otherwise
       (error "Time to implement tactic-progress-finalize for ~S" iteration-type)))))

(defun finalize-tactic-progress-iterator (progress-iterator)
  (iteration-finalize progress-iterator)
  progress-iterator)


;;; Setup phase

(toplevel
  (note-funcall-helper-function 'tactic-progress-done?)
  (note-funcall-helper-function 'tactic-progress-next)
  (note-funcall-helper-function 'tactic-progress-finalize))
