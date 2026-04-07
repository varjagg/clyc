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

(defun heuristic-balanced-strategy-p (object)
  (and (strategy-p object)
       (eq :heuristic-balanced (strategy-type object))))

(defun heuristic-balanced-strategy-initialize (strategy)
  (let* ((removal-index (create-stack))
         (new-root-index (create-queue))
         (transformation-index (new-problem-happiness-index))
         (data (new-balanced-strategy-data removal-index new-root-index transformation-index)))
    (set-strategy-data strategy data))
  strategy)

(defun heuristic-balanced-strategy-no-strategems-active-wrt-removal? (strategy)
  (stack-empty-p (balanced-strategy-removal-strategem-index strategy)))

(defun heuristic-balanced-strategy-peek-strategem-wrt-removal (strategy)
  "[Cyc] @return nil or removal-strategem-p"
  (let ((removal-index (balanced-strategy-removal-strategem-index strategy)))
    (unless (stack-empty-p removal-index)
      (stack-peek removal-index))))

(defun heuristic-balanced-strategy-no-new-roots? (strategy)
  (queue-empty-p (balanced-strategy-new-root-index strategy)))

(defun heuristic-balanced-strategy-peek-new-root (strategy)
  "[Cyc] @return nil or problem-p"
  (let ((new-root-index (balanced-strategy-new-root-index strategy)))
    (unless (queue-empty-p new-root-index)
      (queue-peek new-root-index))))

(defun heuristic-balanced-strategy-chooses-to-throw-away-new-root? (strategy problem)
  (balanced-strategy-default-chooses-to-throw-away-new-root? strategy problem))

(defun heuristic-balanced-strategy-no-strategems-active-wrt-transformation? (strategy)
  (let ((transformation-index (balanced-strategy-transformation-strategem-index strategy)))
    (problem-happiness-index-empty-p transformation-index)))

(defun heuristic-balanced-strategy-peek-strategem-wrt-transformation (strategy)
  "[Cyc] @return nil or transformation-strategem-p"
  (let ((transformation-index (balanced-strategy-transformation-strategem-index strategy))
        (best-strategem nil))
    (loop while (null best-strategem)
          do (when (problem-happiness-index-empty-p transformation-index)
               (return-from heuristic-balanced-strategy-peek-strategem-wrt-transformation nil))
             (multiple-value-bind (candidate-strategem expected-happiness)
                 (problem-happiness-index-peek transformation-index)
               (if (strategem-invalid-p candidate-strategem)
                   (problem-happiness-index-next transformation-index)
                   (let ((current-happiness (heuristic-balanced-strategy-transformation-strategem-happiness strategy candidate-strategem)))
                     (if (happiness-< current-happiness expected-happiness)
                         (progn
                           (problem-happiness-index-next transformation-index)
                           (problem-happiness-index-add transformation-index current-happiness candidate-strategem))
                         (setf best-strategem candidate-strategem))))))
    best-strategem))

;; (defun heuristic-balanced-strategy-current-contents (strategy) ...) -- active declareFunction, no body

(defun heuristic-balanced-strategy-activate-strategem-wrt-removal (strategy removal-strategem)
  "[Cyc] @return booleanp; whether REMOVAL-STRATEGEM was successfully added to STRATEGY's removal index"
  (let ((removal-index (balanced-strategy-removal-strategem-index strategy)))
    (stack-push removal-strategem removal-index)
    t))

(defun heuristic-balanced-strategy-pop-strategem-wrt-removal (strategy)
  (let ((removal-index (balanced-strategy-removal-strategem-index strategy)))
    (stack-pop removal-index)))

(defun heuristic-balanced-strategy-add-new-root (strategy problem)
  (let ((new-root-index (balanced-strategy-new-root-index strategy)))
    (enqueue problem new-root-index)
    t))

(defun heuristic-balanced-strategy-pop-new-root (strategy)
  (let ((new-root-index (balanced-strategy-new-root-index strategy)))
    (dequeue new-root-index)))

(defun heuristic-balanced-strategy-activate-strategem-wrt-transformation (strategy transformation-strategem)
  "[Cyc] @return booleanp; whether TRANSFORMATION-STRATEGEM was successfully added to STRATEGY's transformation index"
  (let* ((transformation-index (balanced-strategy-transformation-strategem-index strategy))
         (happiness (heuristic-balanced-strategy-transformation-strategem-happiness strategy transformation-strategem)))
    (problem-happiness-index-add transformation-index happiness transformation-strategem)
    t))

(defun heuristic-balanced-strategy-pop-strategem-wrt-transformation (strategy)
  "[Cyc] @return nil or transformation-strategem-p"
  (let ((transformation-index (balanced-strategy-transformation-strategem-index strategy)))
    (multiple-value-bind (best-strategem expected-happiness)
        (problem-happiness-index-next transformation-index)
      (declare (ignore expected-happiness))
      best-strategem)))

;; Variable

(deflexical *heuristic-balanced-tactician-heuristics*
  (construct-set-from-list '(:shallow-and-cheap
                             :completeness
                             :occams-razor
                             :magic-wand
                             :backtracking-considered-harmful
                             :backchain-required
                             :rule-a-priori-utility
                             :relevant-term
                             :rule-historical-utility
                             :literal-count
                             :rule-literal-count
                             :skolem-count)
                           #'eq)
  "[Cyc] The set of heuristics used by the Heuristic Balanced Tactician.")

;; Reconstructed from Internal Constants:
;; $list18 = ((HEURISTIC FUNCTION SCALING-FACTOR &KEY TACTIC DONE) &BODY BODY) — arglist
;; $sym23 = DO-STRATEGIC-HEURISTICS — wraps this macro
;; $sym24 = PWHEN — filters with when
;; $sym25 = HEURISTIC-BALANCED-TACTICIAN-STRATEGIC-HEURISTIC? — filter predicate
;; Visible expansion in heuristic-balanced-strategy-generic-tactic-happiness confirms:
;; iterates over strategic heuristics, filtering by heuristic-balanced-tactician-strategic-heuristic?
(defmacro do-heuristic-balanced-tactician-strategic-heuristics ((heuristic function scaling-factor &key tactic done) &body body)
  `(do-strategic-heuristics (,heuristic ,function ,scaling-factor :tactic ,tactic :done ,done)
     (when (heuristic-balanced-tactician-strategic-heuristic? ,heuristic)
       ,@body)))

(defun heuristic-balanced-tactician-strategic-heuristic? (heuristic)
  (set-member? heuristic *heuristic-balanced-tactician-heuristics*))

(defun heuristic-balanced-strategy-transformation-tactic-happiness (transformation-tactic strategy)
  "[Cyc] The happiness of doing one specific transformation."
  (declare (type transformation-tactic-p transformation-tactic))
  (declare (type heuristic-balanced-strategy-p strategy))
  (heuristic-balanced-strategy-generic-tactic-happiness transformation-tactic strategy))

(defun heuristic-balanced-strategy-transformation-link-happiness (transformation-link strategy)
  "[Cyc] The happiness of introducing a new root problem."
  (declare (type transformation-link-p transformation-link))
  (declare (type heuristic-balanced-strategy-p strategy))
  (let ((transformation-tactic (transformation-link-tactic transformation-link)))
    (heuristic-balanced-strategy-transformation-tactic-happiness transformation-tactic strategy)))

;; (defun heuristic-balanced-strategy-logical-tactic-transformation-happiness (logical-tactic strategy) ...) -- active declareFunction, no body

(defun heuristic-balanced-strategy-generic-tactic-happiness (tactic strategy)
  (declare (type tactic-p tactic))
  (declare (type heuristic-balanced-strategy-p strategy))
  (let ((aggregate-happiness 0))
    (dohash (heuristic value (strategic-heuristic-index))
      (declare (ignore value))
      (let ((function (strategic-heuristic-function heuristic))
            (scaling-factor (strategic-heuristic-scaling-factor heuristic))
            (tactic-type (strategic-heuristic-tactic-type heuristic)))
        (when (do-strategic-heuristics-tactic-match-p tactic tactic-type)
          (when (heuristic-balanced-tactician-strategic-heuristic? heuristic)
            (let* ((raw-happiness (happiness-funcall function strategy tactic))
                   (scaled-happiness (potentially-infinite-integer-times raw-happiness scaling-factor)))
              (setf aggregate-happiness (potentially-infinite-integer-plus aggregate-happiness scaled-happiness)))))))
    aggregate-happiness))

(defun happiness-funcall (function strategy tactic)
  (funcall function strategy tactic))

(defun heuristic-balanced-strategy-transformation-strategem-happiness (strategy strategem)
  (declare (type heuristic-balanced-strategy-p strategy))
  (declare (type strategem-p strategem))
  (cond
    ((transformation-tactic-p strategem)
     (let ((transformation-tactic strategem))
       (heuristic-balanced-strategy-transformation-tactic-happiness transformation-tactic strategy)))
    ((logical-tactic-p strategem)
     ;; Likely computes transformation happiness for a logical tactic -- evidence:
     ;; parallel to the transformation-tactic case, and the sibling function
     ;; heuristic-balanced-strategy-logical-tactic-transformation-happiness exists (no body)
     (missing-larkc 36531))
    ((transformation-link-p strategem)
     (let ((transformation-link strategem))
       (heuristic-balanced-strategy-transformation-link-happiness transformation-link strategy)))
    (t
     (error "~S is not a transformation strategem" strategem))))

;; (defun heuristic-balanced-strategy-happiness-table (strategy tactic) ...) -- active declareFunction, no body

;; Setup

(toplevel
  (inference-strategy-type
   :heuristic-balanced
   (list :name "Heuristic Balanced Search"
         :comment "A balanced Tactician type which uses a depth-first stack for removal problems
and a linear combination of heuristics to choose which transformation-motivated tactics to execute."
         :constructor 'heuristic-balanced-strategy-initialize
         :done? 'balanced-strategy-done?
         :do-one-step 'balanced-strategy-do-one-step
         :possibly-activate-problem 'balanced-strategy-possibly-activate-problem
         :select-best-strategem 'balanced-strategy-default-select-best-strategem
         :throw-away-uninteresting-set-asides 'balanced-strategy-throw-away-uninteresting-set-asides
         :quiesce 'balanced-strategy-quiesce
         :early-removal-productivity-limit 'balanced-strategy-early-removal-productivity-limit
         :new-argument-link 'balanced-strategy-note-argument-link-added
         :new-tactic 'balanced-strategy-note-new-tactic
         :relevant-tactics-wrt-removal 'balanced-strategy-categorize-strategems-wrt-removal
         :split-tactics-possible 'balanced-strategy-note-split-tactics-strategically-possible
         :problem-could-be-pending 'balanced-strategy-consider-that-problem-could-be-strategically-totally-pending
         :problem-nothing-to-do? 'balanced-strategy-problem-totally-pending?
         :peek-removal-strategem 'heuristic-balanced-strategy-peek-strategem-wrt-removal
         :activate-removal-strategem 'heuristic-balanced-strategy-activate-strategem-wrt-removal
         :pop-removal-strategem 'heuristic-balanced-strategy-pop-strategem-wrt-removal
         :no-active-removal-strategems 'heuristic-balanced-strategy-no-strategems-active-wrt-removal?
         :peek-new-root 'heuristic-balanced-strategy-peek-new-root
         :activate-new-root 'heuristic-balanced-strategy-add-new-root
         :pop-new-root 'heuristic-balanced-strategy-pop-new-root
         :no-new-roots 'heuristic-balanced-strategy-no-new-roots?
         :throw-away-new-root 'heuristic-balanced-strategy-chooses-to-throw-away-new-root?
         :peek-transformation-strategem 'heuristic-balanced-strategy-peek-strategem-wrt-transformation
         :activate-transformation-strategem 'heuristic-balanced-strategy-activate-strategem-wrt-transformation
         :pop-transformation-strategem 'heuristic-balanced-strategy-pop-strategem-wrt-transformation
         :no-active-transformation-strategems 'heuristic-balanced-strategy-no-strategems-active-wrt-transformation?)))

(toplevel
  (note-funcall-helper-function 'heuristic-balanced-strategy-initialize)
  (note-funcall-helper-function 'heuristic-balanced-strategy-no-strategems-active-wrt-removal?)
  (note-funcall-helper-function 'heuristic-balanced-strategy-peek-strategem-wrt-removal)
  (note-funcall-helper-function 'heuristic-balanced-strategy-no-new-roots?)
  (note-funcall-helper-function 'heuristic-balanced-strategy-peek-new-root)
  (note-funcall-helper-function 'heuristic-balanced-strategy-chooses-to-throw-away-new-root?)
  (note-funcall-helper-function 'heuristic-balanced-strategy-no-strategems-active-wrt-transformation?)
  (note-funcall-helper-function 'heuristic-balanced-strategy-peek-strategem-wrt-transformation)
  (note-funcall-helper-function 'heuristic-balanced-strategy-activate-strategem-wrt-removal)
  (note-funcall-helper-function 'heuristic-balanced-strategy-pop-strategem-wrt-removal)
  (note-funcall-helper-function 'heuristic-balanced-strategy-add-new-root)
  (note-funcall-helper-function 'heuristic-balanced-strategy-pop-new-root)
  (note-funcall-helper-function 'heuristic-balanced-strategy-activate-strategem-wrt-transformation)
  (note-funcall-helper-function 'heuristic-balanced-strategy-pop-strategem-wrt-transformation))

(toplevel
  (register-macro-helper 'heuristic-balanced-tactician-strategic-heuristic?
                         'do-heuristic-balanced-tactician-strategic-heuristics))
