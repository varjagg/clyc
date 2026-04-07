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

(defun removal-strategy-done? (strategy)
  (and (removal-strategy-no-strategems-active? strategy)
       (not (strategy-should-propagate-answer-link? strategy))))

(defun removal-strategy-do-one-step (strategy)
  (let ((result :uninteresting))
    (loop while (eq :uninteresting result)
          do (setf result (removal-strategy-do-one-step-int strategy)))
    (when *inference-debug?*
      (when (eq :done result)
        (unless (removal-strategy-no-strategems-active? strategy)
          (cerror "continue anyway" "~s says it's done, but its R-box is nonempty" strategy))))
    (eq :done result)))

(defun removal-strategy-do-one-step-int (strategy)
  "[Cyc] @return one of (:done :interesting, :uninteresting)"
  (let ((result nil))
    (cond
      ((strategy-should-reconsider-set-asides? strategy)
       ;; Likely reconsiders set-aside strategems -- evidence: called when
       ;; strategy-should-reconsider-set-asides? is true, before checking done
       (missing-larkc 35464)
       (setf result :uninteresting))
      ((strategy-done? strategy)
       (setf result :done))
      (t
       (let ((strategem (removal-strategy-select-best-strategem strategy)))
         (if strategem
             (setf result (removal-strategy-execute-strategem strategy strategem))
             (setf result :done)))))
    result))

(defun removal-strategy-select-best-strategem (strategy)
  "[Cyc] @return strategem-p
remove from boxes during selection if necessary. (quiescence)
@note don't assume you're only looking at possible tactics, because of reuse (use case #2)."
  (strategy-dispatch strategy :select-best-strategem))

(defun removal-strategy-default-select-best-strategem (strategy)
  (removal-strategy-quiesce strategy)
  (unless (removal-strategy-no-strategems-active? strategy)
    (return-from removal-strategy-default-select-best-strategem
      (removal-strategy-pop-strategem strategy)))
  (when (strategy-should-propagate-answer-link? strategy)
    (return-from removal-strategy-default-select-best-strategem
      (strategy-answer-link strategy)))
  nil)

(defun removal-strategy-quiesce (strategy)
  "[Cyc] @return nil or strategem-p"
  (declare (type removal-strategy-p strategy))
  (loop
    (let ((candidate-strategem (removal-strategy-peek-strategem strategy)))
      (unless candidate-strategem
        (return nil))
      (let ((reason (why-removal-strategy-chooses-to-ignore-strategem strategy candidate-strategem)))
        (unless reason
          (return candidate-strategem))
        (cond
          ((eql reason :set-aside)
           (removal-strategy-note-strategem-set-aside strategy candidate-strategem))
          ((eql reason :throw-away)
           (removal-strategy-note-strategem-thrown-away strategy candidate-strategem)))
        (removal-strategy-pop-strategem strategy)
        (removal-strategy-strategically-deactivate-strategem strategy candidate-strategem)))))

(defparameter *removal-strategy-does-not-activate-disallowed-tactics?* t)

(defun removal-strategy-execute-strategem (strategy strategem)
  "[Cyc] @return one of (:interesting, :uninteresting)"
  (declare (type removal-strategy-p strategy))
  (declare (type strategem-p strategem))
  (let ((result :uninteresting))
    (cond
      ((executable-strategem-p strategem)
       (let* ((tactic strategem)
              (strategem-var tactic)
              (problem (strategem-problem strategem-var)))
         (removal-strategy-deactivate-strategem strategy strategem-var)
         (removal-strategy-execute-tactic strategy tactic)
         (removal-strategy-possibly-deactivate-problem strategy problem)
         (setf result :interesting)))
      ((logical-tactic-p strategem)
       (let ((tactic strategem))
         (unless (and *removal-strategy-does-not-activate-disallowed-tactics?*
                      (tactic-disallowed? strategem strategy))
           (removal-strategy-possibly-propagate-motivation-to-link-head strategy tactic)
           (let* ((strategem-var tactic)
                  (problem (strategem-problem strategem-var)))
             (removal-strategy-deactivate-strategem strategy strategem-var)
             (strategy-possibly-execute-tactic strategy tactic)
             (removal-strategy-possibly-deactivate-problem strategy problem))
           (setf result :interesting))))
      ((transformation-link-p strategem)
       (return-from removal-strategy-execute-strategem
         (error "removal tactician does not handle transformation link ~a" strategem)))
      ((answer-link-p strategem)
       (let* ((answer-link strategem)
              (root-problem (answer-link-supporting-problem answer-link)))
         (removal-strategy-possibly-propagate-motivation-to-problem strategy root-problem)
         (possibly-propagate-answer-link answer-link)
         (setf result :interesting)))
      (t
       (return-from removal-strategy-execute-strategem
         (error "~S was an unexpected strategem" strategem))))
    result))

(defparameter *removal-strategy-removal-tactic-iterativity-enabled?* t
  "[Cyc] If this is NIL, removal tactics will always be executed exhaustively before moving on to other tactics.
Useful for experimentation, very bad for time to first answer.")

(defun removal-strategy-execute-tactic (strategy tactic)
  (if (content-tactic-p tactic)
      (removal-strategy-execute-content-tactic strategy tactic)
      (removal-strategy-execute-meta-structural-tactic strategy tactic)))

(defun removal-strategy-execute-content-tactic (strategy content-tactic)
  (if (and (not *removal-strategy-removal-tactic-iterativity-enabled?*)
           (removal-tactic-p content-tactic))
      (progn
        (strategy-execute-tactic strategy content-tactic)
        (when (tactic-in-progress? content-tactic)
          (removal-strategy-reactivate-executable-strategem strategy content-tactic)))
      (removal-strategy-execute-executable-strategem strategy content-tactic))
  strategy)

(defun removal-strategy-execute-meta-structural-tactic (strategy meta-structural-tactic)
  (removal-strategy-execute-executable-strategem strategy meta-structural-tactic))

(defun removal-strategy-execute-executable-strategem (strategy strategem)
  (let ((already-in-progress? (tactic-in-progress? strategem)))
    (when already-in-progress?
      (removal-strategy-reactivate-executable-strategem strategy strategem))
    (strategy-execute-tactic strategy strategem)
    (when (and (not already-in-progress?)
               (tactic-in-progress? strategem))
      (removal-strategy-reactivate-executable-strategem strategy strategem)))
  strategem)

(toplevel
  (note-funcall-helper-function 'removal-strategy-done?)
  (note-funcall-helper-function 'removal-strategy-do-one-step))
