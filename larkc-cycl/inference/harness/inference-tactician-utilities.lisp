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

(defun-memoized memoized-problem-global-preference-level (problem strategic-context shared-variables)
    (:test equal)
  (problem-global-preference-level problem strategic-context shared-variables))

(defun problem-global-preference-level (problem strategic-context shared-variables)
  (declare (type strategic-context-p strategic-context))
  (let ((preference-level nil)
        (justification nil))
    (cond
      ((null (problem-store-removal-allowed? (problem-store problem)))
       (setf preference-level :grossly-dispreferred)
       (setf justification "removal is not allowed in the problem store"))
      ((closed-problem-p problem)
       (setf preference-level :preferred)
       (setf justification "problem is closed"))
      ((null shared-variables)
       (setf preference-level :preferred)
       (setf justification "no variables have any hope of getting bound"))
      (t
       (determine-strategic-status-wrt problem strategic-context)
       (cond
         ((problem-has-no-allowed-or-executed-tactics-wrt-removal? problem strategic-context)
          (setf preference-level :disallowed)
          (setf justification "problem has no removal-allowed or executed tactics"))
         ((single-negative-literal-problem-p problem)
          (setf preference-level (if shared-variables :disallowed :grossly-dispreferred))
          (setf justification "single negative literal"))
         ((problem-has-some-complete-non-thrown-away-removal-tactic? problem strategic-context)
          (setf preference-level :preferred)
          (setf justification "problem has a complete non-ignored removal tactic"))
         ((problem-has-executed-a-complete-removal-tactic? problem strategic-context)
          (setf preference-level :preferred)
          (setf justification "problem has executed a complete removal tactic"))
         ((multi-literal-problem-p problem)
          (multiple-value-setq (preference-level justification)
            (multi-literal-problem-global-preference-level problem :tactical)))
         ((multi-clause-problem-p problem)
          (return-from problem-global-preference-level
            *union-tactic-preference-level*))
         (t
          (multiple-value-setq (preference-level justification)
            (problem-preference-level-wrt-modules problem strategic-context shared-variables))))))
    (values preference-level justification)))

(defun single-negative-literal-problem-p (problem)
  (and (single-literal-problem-p problem)
       (eq :neg (single-literal-problem-sense problem))))

(defun multi-literal-problem-global-preference-level (problem strategic-context)
  (let ((max-preference-level :disallowed)
        (reason "unknown"))
    (let ((tactics (multi-literal-problem-tactics-to-activate problem strategic-context)))
      (dolist (tactic tactics)
        (let ((preference-level (conjunctive-tactic-strategic-preference-level tactic strategic-context)))
          (when preference-level
            (when (preference-level-> preference-level max-preference-level)
              (setf max-preference-level preference-level)
              (setf reason (conjunctive-tactic-strategic-preference-level-justification tactic strategic-context)))))))
    (values max-preference-level reason)))

(defun multi-literal-problem-tactics-to-activate (problem strategic-context)
  (cond
    ((eq :tactical strategic-context)
     (remove-if #'transformation-tactic-p (problem-tactics problem)))
    ((balanced-strategy-p strategic-context)
     (remove-if-not #'tactic-p (balanced-strategy-categorize-strategems-wrt-removal strategic-context problem)))
    (t
     (error "Unexpected strategy type ~s" strategic-context))))

(defun problem-has-some-complete-non-thrown-away-removal-tactic? (problem strategic-context)
  "[Cyc] Return T iff PROBLEM has some :complete non-thrown-away removal tactic."
  (dolist (tactic (problem-tactics problem))
    (when (do-problem-tactics-type-match tactic :generalized-removal)
      (when (tactic-complete? tactic strategic-context)
        (when (or (not (strategy-p strategic-context))
                  (not (legacy-strategy-chooses-to-throw-away-tactic? strategic-context tactic :removal)))
          (return-from problem-has-some-complete-non-thrown-away-removal-tactic? t)))))
  nil)

(defun problem-has-no-allowed-or-executed-tactics-wrt-removal? (problem strategic-context)
  "[Cyc] Return T iff PROBLEM has no removal-relevant tactic with a completeness of anything other than :impossible
or a preference of anything other than :disallowed."
  (dolist (tactic (problem-tactics problem))
    (cond
      ((and (strategy-p strategic-context)
            (tactic-possible? tactic)
            (legacy-strategy-chooses-to-throw-away-tactic? strategic-context tactic :removal))
       ;; skip - thrown away by strategy
       )
      ((tactic-executed? tactic)
       (return-from problem-has-no-allowed-or-executed-tactics-wrt-removal? nil))
      (t
       (if (content-tactic-p tactic)
           (unless (tactic-impossible? tactic strategic-context)
             (return-from problem-has-no-allowed-or-executed-tactics-wrt-removal? nil))
           (unless (tactic-disallowed? tactic strategic-context)
             (return-from problem-has-no-allowed-or-executed-tactics-wrt-removal? nil))))))
  t)

;;                            m      b
(defparameter *preference-scaling-values*
  '((:dispreferred 2 0)
    (:grossly-dispreferred 20 0)
    (:join-ordered 5 0)))

(defun removal-unhappiness (productivity module-spec preference-level literal-count)
  "[Cyc] Assumes zero b-values"
  (let ((unhappiness productivity))
    (setf unhappiness (scale-unhappiness unhappiness (module-scaling-factor module-spec)))
    (setf unhappiness (scale-unhappiness unhappiness (preference-scaling-factor preference-level)))
    (setf unhappiness (scale-unhappiness unhappiness (literal-count-scaling-factor literal-count)))
    unhappiness))

(defun scale-unhappiness (unhappiness scaling-factor)
  (potentially-infinite-integer-times-number-rounded unhappiness scaling-factor))

(defun module-scaling-factor (module-spec)
  "[Cyc] Assumes zero b-values"
  (let ((sf-data (alist-lookup-without-values *preference-scaling-values* module-spec)))
    (when sf-data
      (destructuring-bind (m b) sf-data
        (declare (ignore b))
        (return-from module-scaling-factor m))))
  1)

(defun preference-scaling-factor (preference-level)
  "[Cyc] Assumes zero b-values"
  (let ((sf-data (alist-lookup-without-values *preference-scaling-values* preference-level)))
    (when sf-data
      (destructuring-bind (m b) sf-data
        (declare (ignore b))
        (return-from preference-scaling-factor m))))
  1)

(defparameter *literal-count-scaling-enabled?* t
  "[Cyc] Temporary control variable; when non-NIL we factor the number of focal literals
in a connected conjunction tactic into account when computed the committed tactic.
Should eventually stay T.")

(defun literal-count-scaling-factor (literal-count)
  "[Cyc] Assumes zero b-values"
  (when *literal-count-scaling-enabled?*
    (when (> literal-count 1)
      (return-from literal-count-scaling-factor (/ 1 literal-count))))
  1)

(defun strategy-deems-conjunctive-tactic-spec-better? (candidate-tactic-productivity
                                                       candidate-tactic-preference
                                                       candidate-tactic-module-spec
                                                       candidate-tactic-literal-count
                                                       committed-tactic-productivity
                                                       committed-tactic-preference
                                                       committed-tactic-module-spec
                                                       committed-tactic-literal-count)
  "[Cyc] Return booleanp; whether it prefers a CANDIDATE-TACTIC's
PRODUCTIVITY, PREFERENCE, MODULE-SPEC and LITERAL-COUNT values over
those of a COMMITTED-TACTIC."
  (cond
    ((eq :disallowed candidate-tactic-preference)
     nil)
    ((eq :disallowed committed-tactic-preference)
     t)
    (t
     (let ((candidate-unhappiness (removal-unhappiness candidate-tactic-productivity
                                                       candidate-tactic-preference
                                                       candidate-tactic-module-spec
                                                       candidate-tactic-literal-count))
           (committed-unhappiness (removal-unhappiness committed-tactic-productivity
                                                       committed-tactic-preference
                                                       committed-tactic-module-spec
                                                       committed-tactic-literal-count)))
       (potentially-infinite-integer-< candidate-unhappiness committed-unhappiness)))))

(defun magic-wand-tactic? (tactic strategic-context)
  (when (and (abductive-strategy-p strategic-context)
             (missing-larkc 36530))
    (return-from magic-wand-tactic? t))
  (when (logical-tactic-p tactic)
    (cond
      ((logical-tactic-with-unique-lookahead-problem-p tactic)
       (when (eql 0 (tactic-strategic-productivity tactic strategic-context))
         (let ((tactic-preference-level (tactic-strategic-preference-level tactic strategic-context)))
           (when (under-magic-wand-max-preference-level? tactic-preference-level)
             (when (tactic-strictly-less-preferred-than-some-sibling? tactic strategic-context)
               (return-from magic-wand-tactic? t))))))
      ((join-tactic-p tactic)
       (when (tactic-strictly-less-preferred-than-some-sibling? tactic strategic-context)
         (multiple-value-bind (first-mapped-problem second-mapped-problem)
             (find-or-create-join-tactic-supporting-mapped-problems tactic)
           (let* ((first-problem (mapped-problem-problem first-mapped-problem))
                  (second-problem (mapped-problem-problem second-mapped-problem))
                  (first-productivity (memoized-problem-max-removal-productivity first-problem strategic-context))
                  (second-productivity (memoized-problem-max-removal-productivity second-problem strategic-context))
                  (first-problem-shared-vars (first-problem-shared-vars first-mapped-problem second-mapped-problem))
                  (second-problem-shared-vars (second-problem-shared-vars first-mapped-problem second-mapped-problem)))
             (when (or (and (eql 0 first-productivity)
                            (under-magic-wand-max-preference-level?
                             (memoized-problem-global-preference-level first-problem strategic-context first-problem-shared-vars)))
                       (and (eql 0 second-productivity)
                            (under-magic-wand-max-preference-level?
                             (memoized-problem-global-preference-level second-problem strategic-context second-problem-shared-vars))))
               (return-from magic-wand-tactic? t))))))))
  nil)

(defparameter *magic-wand-max-preference-level* :dispreferred
  "[Cyc] Tactics with a preference level strictly higher than this will not be deemed magic wand tactics.")

(defun under-magic-wand-max-preference-level? (preference-level)
  (preference-level-<= preference-level *magic-wand-max-preference-level*))

(defun tactic-strictly-less-preferred-than-some-sibling? (tactic strategic-context)
  (let ((tactic-preference-level (tactic-strategic-preference-level tactic strategic-context)))
    (dolist (sibling-tactic (problem-tactics (tactic-problem tactic)))
      (when (do-problem-tactics-type-match sibling-tactic :logical)
        (unless (eq tactic sibling-tactic)
          (let ((sibling-preference-level (tactic-strategic-preference-level sibling-tactic strategic-context)))
            (when (preference-level-< tactic-preference-level sibling-preference-level)
              (return-from tactic-strictly-less-preferred-than-some-sibling? t)))))))
  nil)

;; (defun abductive-magic-wand-tactic? (tactic strategic-context) ...) -- active declareFunction, no body
;; (defun abductive-strategy-chooses-only-abductive-tactic? (tactic strategic-context) ...) -- active declareFunction, no body

;; note-memoized-function call: handled by defun-memoized
