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

(defstruct (removal-strategy-data
            (:conc-name "REM-STRAT-DATA-")
            (:constructor make-removal-strategy-data-int ()))
  link-heads-motivated
  problems-pending
  removal-strategem-index
  problem-total-strategems-active
  problem-strategems-set-aside
  problem-strategems-thrown-away)

(defconstant *dtp-removal-strategy-data* 'removal-strategy-data)

(defun removal-strategy-data-p (object)
  (typep object 'removal-strategy-data))

(defun make-removal-strategy-data (&optional arglist)
  (let ((v-new (make-removal-strategy-data-int)))
    (loop for next = arglist then (cddr next)
          while next
          for current-arg = (first next)
          for current-value = (second next)
          do (case current-arg
               (:link-heads-motivated
                (setf (rem-strat-data-link-heads-motivated v-new) current-value))
               (:problems-pending
                (setf (rem-strat-data-problems-pending v-new) current-value))
               (:removal-strategem-index
                (setf (rem-strat-data-removal-strategem-index v-new) current-value))
               (:problem-total-strategems-active
                (setf (rem-strat-data-problem-total-strategems-active v-new) current-value))
               (:problem-strategems-set-aside
                (setf (rem-strat-data-problem-strategems-set-aside v-new) current-value))
               (:problem-strategems-thrown-away
                (setf (rem-strat-data-problem-strategems-thrown-away v-new) current-value))
               (otherwise
                (error "Invalid slot ~S for construction function" current-arg))))
    v-new))

(defun new-removal-strategy-data (removal-index)
  (let ((data (make-removal-strategy-data)))
    (setf (rem-strat-data-link-heads-motivated data) (new-set #'eq))
    (setf (rem-strat-data-problems-pending data) (new-set #'eq))
    (setf (rem-strat-data-removal-strategem-index data) removal-index)
    (setf (rem-strat-data-problem-total-strategems-active data) (new-dictionary #'eq))
    (setf (rem-strat-data-problem-strategems-set-aside data) (new-dictionary #'eq))
    (setf (rem-strat-data-problem-strategems-thrown-away data) (new-dictionary #'eq))
    data))

(defun removal-strategy-link-heads-motivated (strategy)
  "[Cyc] @return set-p of motivation-strategem-p"
  (declare (type removal-strategy-p strategy))
  (let ((data (strategy-data strategy)))
    (rem-strat-data-link-heads-motivated data)))

(defun removal-strategy-problems-pending (strategy)
  "[Cyc] @return set-p of problem-p"
  (declare (type removal-strategy-p strategy))
  (let ((data (strategy-data strategy)))
    (rem-strat-data-problems-pending data)))

(defun removal-strategy-strategem-index (strategy)
  (declare (type removal-strategy-p strategy))
  (let ((data (strategy-data strategy)))
    (rem-strat-data-removal-strategem-index data)))

(defun removal-strategy-problem-total-strategems-active (strategy)
  "[Cyc] @return #'EQ dictionary of problem-p -> non-negative-integer-p"
  (declare (type removal-strategy-p strategy))
  (let ((data (strategy-data strategy)))
    (rem-strat-data-problem-total-strategems-active data)))

(defun removal-strategy-problem-strategems-set-aside (strategy)
  "[Cyc] @return #'EQ dictionary of problem-p -> #'EQ set of strategem-p"
  (declare (type removal-strategy-p strategy))
  (let ((data (strategy-data strategy)))
    (rem-strat-data-problem-strategems-set-aside data)))

(defun removal-strategy-problem-strategems-thrown-away (strategy)
  "[Cyc] @return #'EQ dictionary of problem-p -> #'EQ set of strategem-p"
  (declare (type removal-strategy-p strategy))
  (let ((data (strategy-data strategy)))
    (rem-strat-data-problem-strategems-thrown-away data)))

(defun removal-strategy-link-head-motivated? (strategy link-head)
  "[Cyc] Return T iff removal motivation should propagate through LINK-HEAD in STRATEGY"
  (declare (type motivation-strategem-p link-head))
  (set-member? link-head (removal-strategy-link-heads-motivated strategy)))

;; (defun removal-strategy-connected-conjunction-link-motivated? (strategy link) ...) -- active declareFunction, no body

(defun removal-strategy-problem-pending? (strategy problem)
  "[Cyc] Return T iff PROBLEM is pending in STRATEGY"
  (declare (type problem-p problem))
  (set-member? problem (removal-strategy-problems-pending strategy)))

(defun removal-strategy-problem-active? (strategy problem)
  "[Cyc] @return booleanp; whether PROBLEM is actively being considered for removal by STRATEGY."
  (declare (type problem-p problem))
  (let ((index (removal-strategy-problem-total-strategems-active strategy)))
    (plusp (gethash problem index 0))))

(defun removal-strategy-problem-set-aside? (strategy problem)
  "[Cyc] @return booleanp; whether PROBLEM has been set aside for later removal consideration by STRATEGY."
  (declare (type problem-p problem))
  (when (not (removal-strategy-problem-active? strategy problem))
    (let* ((index (removal-strategy-problem-strategems-set-aside strategy))
           (v-set (gethash problem index)))
      (when (and v-set
                 (not (set-empty? v-set)))
        (return-from removal-strategy-problem-set-aside? t))))
  nil)

(defun removal-strategy-strategem-set-aside? (strategy strategem)
  "[Cyc] @return booleanp; whether STRATEGEM has been set aside for later removal consideration by STRATEGY."
  (declare (type strategem-p strategem))
  (let* ((problem (strategem-problem strategem))
         (index (removal-strategy-problem-strategems-set-aside strategy))
         (v-set (gethash problem index)))
    (and (set-p v-set)
         (set-member? strategem v-set)
         t)))

(defun removal-strategy-strategem-thrown-away? (strategy strategem)
  "[Cyc] @return booleanp; whether STRATEGEM has been thrown away by STRATEGY."
  (declare (type strategem-p strategem))
  (let* ((problem (strategem-problem strategem))
         (index (removal-strategy-problem-strategems-thrown-away strategy))
         (v-set (gethash problem index)))
    (and (set-p v-set)
         (set-member? strategem v-set)
         t)))

(defun removal-strategy-removal-backtracking-productivity-limit (strategy)
  "[Cyc] @return nil or productivity-p"
  (strategy-removal-backtracking-productivity-limit strategy))

(defun removal-strategy-peek-strategem (strategy)
  "[Cyc] @return nil or removal-strategem-p"
  (let ((removal-index (removal-strategy-strategem-index strategy)))
    (unless (stack-empty-p removal-index)
      (stack-peek removal-index))))

(defun removal-strategy-note-problem-motivated (strategy problem)
  "[Cyc] note R"
  (declare (type removal-strategy-p strategy))
  (declare (type problem-p problem))
  (strategy-note-problem-motivated strategy problem))

(defun removal-strategy-note-link-head-motivated (strategy link-head)
  "[Cyc] note R"
  (declare (type removal-strategy-p strategy))
  (declare (type motivation-strategem-p link-head))
  (set-add link-head (removal-strategy-link-heads-motivated strategy)))

(defun removal-strategy-note-problem-pending (strategy problem)
  (declare (type removal-strategy-p strategy))
  (declare (type problem-p problem))
  (set-add problem (removal-strategy-problems-pending strategy)))

(defun removal-strategy-note-problem-unpending (strategy problem)
  (declare (type removal-strategy-p strategy))
  (declare (type problem-p problem))
  (set-remove problem (removal-strategy-problems-pending strategy)))

(defun removal-strategy-activate-strategem (strategy strategem)
  "[Cyc] note that STRATEGEM is in STRATEGY's R-box"
  (declare (type removal-strategy-p strategy))
  (declare (type removal-strategem-p strategem))
  (let ((removal-index (removal-strategy-strategem-index strategy)))
    (stack-push strategem removal-index))
  (let* ((problem (strategem-problem strategem))
         (index (removal-strategy-problem-total-strategems-active strategy))
         (count (gethash problem index 0)))
    (setf count (+ count 1))
    (when (= 1 count)
      (removal-strategy-note-problem-unpending strategy problem))
    (setf (gethash problem index) count)
    count))

;; (defun removal-strategy-current-contents (strategy) ...) -- active declareFunction, no body

(defun removal-strategy-pop-strategem (strategy)
  (let ((removal-index (removal-strategy-strategem-index strategy)))
    (stack-pop removal-index)))

(defun removal-strategy-note-strategem-set-aside (strategy strategem)
  (declare (type removal-strategy-p strategy))
  (declare (type removal-strategem-p strategem))
  (let* ((index (removal-strategy-problem-strategems-set-aside strategy))
         (problem (strategem-problem strategem))
         (v-set (gethash problem index)))
    (unless (set-p v-set)
      (setf v-set (new-set #'eq))
      (setf (gethash problem index) v-set))
    (set-add strategem v-set)))

;; (defun removal-strategy-clear-strategems-set-aside (strategy) ...) -- active declareFunction, no body

(defun removal-strategy-note-strategem-thrown-away (strategy strategem)
  (declare (type removal-strategy-p strategy))
  (declare (type removal-strategem-p strategem))
  (let* ((index (removal-strategy-problem-strategems-thrown-away strategy))
         (problem (strategem-problem strategem))
         (v-set (gethash problem index)))
    (unless (set-p v-set)
      (setf v-set (new-set #'eq))
      (setf (gethash problem index) v-set))
    (set-add strategem v-set)))

(defun removal-strategy-no-strategems-active? (strategy)
  (declare (type removal-strategy-p strategy))
  (stack-empty-p (removal-strategy-strategem-index strategy)))

;; (defun removal-strategy-clear-set-aside-problems (strategy) ...) -- active declareFunction, no body
