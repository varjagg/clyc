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

(defun balanced-strategy-done? (strategy)
  (and (balanced-strategy-no-strategems-active-wrt-removal? strategy)
       (balanced-strategy-no-new-roots? strategy)
       (balanced-strategy-no-strategems-active-wrt-transformation? strategy)
       (not (strategy-should-propagate-answer-link? strategy))))

(defun balanced-strategy-do-one-step (strategy)
  (let ((result :uninteresting))
    (loop while (eq :uninteresting result)
          do (setf result (balanced-strategy-do-one-step-int strategy)))
    (when *inference-debug?*
      (when (eq :done result)
        (unless (balanced-strategy-no-strategems-active-wrt-transformation? strategy)
          (cerror "continue anyway" "~s says it's done, but its T-box is nonempty" strategy))
        (unless (balanced-strategy-no-strategems-active-wrt-removal? strategy)
          (cerror "continue anyway" "~s says it's done, but its R-box is nonempty" strategy))))
    (eq :done result)))

(defun balanced-strategy-do-one-step-int (strategy)
  "[Cyc] @return one of (:done :interesting, :uninteresting)"
  (let ((result nil))
    (cond
      ((strategy-should-reconsider-set-asides? strategy)
       (balanced-strategy-reconsider-set-asides strategy)
       (setf result :uninteresting))
      ((strategy-done? strategy)
       (setf result :done))
      (t
       (multiple-value-bind (strategem motivation)
           (balanced-strategy-select-best-strategem strategy)
         (if strategem
             (setf result (balanced-strategy-execute-strategem strategy strategem motivation))
             (setf result :done)))))
    result))

(defun balanced-strategy-select-best-strategem (strategy)
  "[Cyc] @return 0 strategem-p
@return 1 nil or balanced-strategy-motivation-p
remove from boxes during selection if necessary. (quiescence)
@note don't assume you're only looking at possible tactics, because of reuse (use case #2)."
  (strategy-dispatch strategy :select-best-strategem))

(defun balanced-strategy-default-select-best-strategem (strategy)
  (balanced-strategy-possibly-prune-current-new-root-wrt-removal strategy)
  (balanced-strategy-quiesce-wrt-removal strategy)
  (unless (balanced-strategy-no-strategems-active-wrt-removal? strategy)
    (return-from balanced-strategy-default-select-best-strategem
      (values (balanced-strategy-pop-strategem-wrt-removal strategy) :removal)))
  (balanced-strategy-quiesce-new-root strategy)
  (unless (balanced-strategy-no-new-roots? strategy)
    (let* ((new-root (balanced-strategy-pop-new-root strategy))
           (motivation (balanced-strategy-new-root-next-motivation strategy new-root)))
      (return-from balanced-strategy-default-select-best-strategem
        (values new-root motivation))))
  (balanced-strategy-quiesce-wrt-transformation strategy)
  (unless (balanced-strategy-no-strategems-active-wrt-transformation? strategy)
    (return-from balanced-strategy-default-select-best-strategem
      (values (balanced-strategy-pop-strategem-wrt-transformation strategy) :transformation)))
  (when (strategy-should-propagate-answer-link? strategy)
    (return-from balanced-strategy-default-select-best-strategem
      (values (strategy-answer-link strategy) :new-root)))
  (values nil nil))

(defun balanced-strategy-new-root-next-motivation (strategy new-root)
  (cond
    ((and (problem-store-removal-allowed? (strategy-problem-store strategy))
          (not (balanced-strategy-problem-motivated-wrt-removal? strategy new-root)))
     :removal)
    ((strategy-throws-away-all-transformation? strategy)
     nil)
    ((not (balanced-strategy-problem-motivated-wrt-transformation? strategy new-root))
     :transformation)
    (t
     nil)))

;; (defun balanced-strategy-quiesce (strategy) ...) -- active declareFunction, no body

(defun balanced-strategy-quiesce-wrt-removal (strategy)
  "[Cyc] @return nil or strategem-p"
  (loop
    (let ((candidate-strategem (balanced-strategy-peek-strategem-wrt-removal strategy)))
      (unless candidate-strategem
        (return nil))
      (let ((reason (why-balanced-strategy-chooses-to-ignore-strategem strategy candidate-strategem :removal)))
        (unless reason
          (return candidate-strategem))
        (cond
          ((eql reason :set-aside)
           ;; Likely sets aside the strategem for later reconsideration
           (missing-larkc 36523))
          ((eql reason :throw-away)
           (balanced-strategy-note-strategem-thrown-away-wrt-removal strategy candidate-strategem)))
        (balanced-strategy-pop-strategem-wrt-removal strategy)
        (balanced-strategy-strategically-deactivate-strategem strategy candidate-strategem :removal)
        (consider-pruning-ramifications-of-ignored-strategem strategy candidate-strategem)))))

(defun balanced-strategy-quiesce-new-root (strategy)
  "[Cyc] @return nil or strategem-p"
  (loop
    (let ((candidate-new-root (balanced-strategy-peek-new-root strategy)))
      (unless candidate-new-root
        (return nil))
      (let ((reason (why-balanced-strategy-chooses-to-ignore-new-root strategy candidate-new-root)))
        (unless reason
          (return candidate-new-root))
        (balanced-strategy-pop-new-root strategy)))))

(defun balanced-strategy-quiesce-wrt-transformation (strategy)
  "[Cyc] @return nil or strategem-p"
  (loop
    (let ((candidate-strategem (balanced-strategy-peek-strategem-wrt-transformation strategy)))
      (unless candidate-strategem
        (return nil))
      (let ((reason (why-balanced-strategy-chooses-to-ignore-strategem strategy candidate-strategem :transformation)))
        (unless reason
          (return candidate-strategem))
        (cond
          ((eql reason :set-aside)
           ;; Likely sets aside the strategem for later reconsideration wrt transformation
           (missing-larkc 36525))
          ((eql reason :throw-away)
           ;; No-op in Java for throw-away wrt transformation
           ))
        (balanced-strategy-pop-strategem-wrt-transformation strategy)
        (balanced-strategy-strategically-deactivate-strategem strategy candidate-strategem :transformation)))))

(defparameter *balanced-strategy-does-not-activate-disallowed-tactics-wrt-removal?* t)

(defun balanced-strategy-execute-strategem (strategy strategem &optional motivation)
  "[Cyc] @return one of (:interesting, :uninteresting)"
  (declare (type balanced-strategy-p strategy))
  (declare (type strategem-p strategem))
  (let ((result :uninteresting))
    (cond
      ((executable-strategem-p strategem)
       (let* ((tactic strategem)
              (strategem-var tactic)
              (problem (strategem-problem strategem-var)))
         (balanced-strategy-deactivate-strategem strategy strategem-var motivation)
         (balanced-strategy-execute-tactic strategy tactic)
         (balanced-strategy-possibly-deactivate-problem strategy problem)
         (setf result :interesting)))
      ((logical-tactic-p strategem)
       (let ((tactic strategem))
         (declare (type balanced-strategy-motivation-p motivation))
         (unless (and *balanced-strategy-does-not-activate-disallowed-tactics-wrt-removal?*
                      (eq motivation :removal)
                      (tactic-disallowed? strategem strategy))
           (balanced-strategy-possibly-propagate-motivation-to-link-head strategy motivation tactic)
           (let* ((strategem-var tactic)
                  (problem (strategem-problem strategem-var)))
             (balanced-strategy-deactivate-strategem strategy strategem-var motivation)
             (strategy-possibly-execute-tactic strategy tactic)
             (balanced-strategy-possibly-deactivate-problem strategy problem))
           (setf result :interesting))))
      ((transformation-link-p strategem)
       (must (eq :transformation motivation)
             "We expect to only propagate T to transformation links, not ~S" motivation)
       (let ((transformation-link strategem))
         (balanced-strategy-possibly-propagate-motivation-to-link-head strategy motivation transformation-link)
         (balanced-strategy-strategically-deactivate-strategem strategy transformation-link motivation)
         (setf result :interesting)))
      ((problem-p strategem)
       (let ((problem strategem))
         (balanced-strategy-handle-new-root strategy problem motivation)
         (setf result :interesting)))
      ((answer-link-p strategem)
       (let* ((answer-link strategem)
              (root-problem (answer-link-supporting-problem answer-link)))
         (balanced-strategy-possibly-propagate-motivation-to-problem strategy :new-root root-problem)
         (possibly-propagate-answer-link answer-link)
         (setf result :interesting)))
      (t
       (return-from balanced-strategy-execute-strategem
         (error "~S was an unexpected strategem" strategem))))
    result))

(defparameter *balanced-strategy-removal-tactic-iterativity-enabled?* t
  "[Cyc] If this is NIL, removal tactics will always be executed exhaustively before moving on to other tactics.
Useful for experimentation, very bad for time to first answer.")

(defun balanced-strategy-execute-tactic (strategy tactic)
  (if (content-tactic-p tactic)
      (balanced-strategy-execute-content-tactic strategy tactic)
      ;; Likely executes a meta-structural tactic -- evidence: mirrors removal-strategy-execute-tactic
      (missing-larkc 36512)))

;; (defun balanced-strategy-execute-meta-structural-tactic (strategy tactic) ...) -- active declareFunction, no body

(defun balanced-strategy-execute-content-tactic (strategy content-tactic)
  (if (and (not *balanced-strategy-removal-tactic-iterativity-enabled?*)
           (removal-tactic-p content-tactic))
      (progn
        (strategy-execute-tactic strategy content-tactic)
        (when (tactic-in-progress? content-tactic)
          (balanced-strategy-reactivate-executable-strategem strategy content-tactic)))
      (balanced-strategy-execute-executable-strategem strategy content-tactic))
  strategy)

(defun balanced-strategy-execute-executable-strategem (strategy strategem)
  (let ((already-in-progress? (tactic-in-progress? strategem)))
    (when already-in-progress?
      (balanced-strategy-reactivate-executable-strategem strategy strategem))
    (strategy-execute-tactic strategy strategem)
    (when (and (not already-in-progress?)
               (tactic-in-progress? strategem))
      (balanced-strategy-reactivate-executable-strategem strategy strategem)))
  strategem)

(defun balanced-strategy-handle-new-root (strategy new-root motivation)
  (cond
    ((eql motivation :removal)
     (let ((result nil))
       (setf result (balanced-strategy-possibly-propagate-motivation-to-problem strategy :removal new-root))
       (balanced-strategy-note-new-root-activated-wrt-removal strategy new-root)
       (balanced-strategy-add-new-root strategy new-root)
       result))
    ((eql motivation :transformation)
     (let ((result nil))
       (setf result (balanced-strategy-possibly-propagate-motivation-to-problem strategy :transformation new-root))
       (balanced-strategy-add-new-root strategy new-root)
       result))
    (t
     (error "unexpected motivation ~s" motivation))))

(defvar *balanced-strategy-prune-current-new-root-wrt-removal-timeout* nil)

(defun balanced-strategy-possibly-prune-current-new-root-wrt-removal (strategy)
  (let ((result nil))
    (when *balanced-strategy-prune-current-new-root-wrt-removal-timeout*
      (unless (balanced-strategy-no-strategems-active-wrt-transformation? strategy)
        (let ((new-root
                ;; Likely gets the current new root being processed wrt removal
                (missing-larkc 36517)))
          (when new-root
            (unless (good-problem-p new-root strategy)
              (let ((elapsed-time
                      ;; Likely gets the elapsed time for the current new root wrt removal
                      (missing-larkc 36518)))
                (when (>= elapsed-time *balanced-strategy-prune-current-new-root-wrt-removal-timeout*)
                  (setf result
                        ;; Likely prunes the current new root problem
                        (missing-larkc 36513))
                  ;; Likely resets or clears state after pruning
                  (missing-larkc 36515))))))))
    result))

;; (defun balanced-strategy-flush-wrt-removal (strategy) ...) -- active declareFunction, no body
