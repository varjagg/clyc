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

;; (defun transformation-strategy-motivation-p (object) ...) -- active declareFunction, no body

(defstruct (transformation-strategy-data
            (:conc-name "TRANS-STRAT-DATA-")
            (:constructor make-transformation-strategy-data-int ()))
  link-heads-motivated
  problems-pending
  transformation-strategem-index
  problem-total-strategems-active
  problem-strategems-set-aside
  problem-strategems-thrown-away)

(defconstant *dtp-transformation-strategy-data* 'transformation-strategy-data)

(defun transformation-strategy-data-p (object)
  (typep object 'transformation-strategy-data))

(defun make-transformation-strategy-data (&optional arglist)
  (let ((v-new (make-transformation-strategy-data-int)))
    (loop for next = arglist then (cddr next)
          while next
          for current-arg = (first next)
          for current-value = (second next)
          do (case current-arg
               (:link-heads-motivated
                (setf (trans-strat-data-link-heads-motivated v-new) current-value))
               (:problems-pending
                (setf (trans-strat-data-problems-pending v-new) current-value))
               (:transformation-strategem-index
                (setf (trans-strat-data-transformation-strategem-index v-new) current-value))
               (:problem-total-strategems-active
                (setf (trans-strat-data-problem-total-strategems-active v-new) current-value))
               (:problem-strategems-set-aside
                (setf (trans-strat-data-problem-strategems-set-aside v-new) current-value))
               (:problem-strategems-thrown-away
                (setf (trans-strat-data-problem-strategems-thrown-away v-new) current-value))
               (otherwise
                (error "Invalid slot ~S for construction function" current-arg))))
    v-new))

(defun transformation-strategy-p (object)
  (or (and (strategy-p object)
           (eq :transformation (strategy-type object)))
      (abductive-strategy-p object)))

;; (defun new-transformation-strategy-data (strategy) ...) -- active declareFunction, no body
;; (defun transformation-strategy-link-heads-motivated (strategy) ...) -- active declareFunction, no body
;; (defun transformation-strategy-problems-pending (strategy) ...) -- active declareFunction, no body
;; (defun transformation-strategy-transformation-strategem-index (strategy) ...) -- active declareFunction, no body
;; (defun transformation-strategy-problem-total-strategems-active (strategy) ...) -- active declareFunction, no body
;; (defun transformation-strategy-problem-strategems-set-aside (strategy) ...) -- active declareFunction, no body
;; (defun transformation-strategy-problem-strategems-thrown-away (strategy) ...) -- active declareFunction, no body
;; (defun transformation-strategy-problem-motivated? (strategy problem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-link-head-motivated? (strategy link-head) ...) -- active declareFunction, no body
;; (defun transformation-strategy-problem-pending? (strategy problem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-problem-totally-pending? (strategy problem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-problem-active? (strategy problem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-problem-set-aside? (strategy problem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-strategem-set-aside? (strategy strategem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-strategem-thrown-away? (strategy strategem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-note-problem-motivated (strategy problem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-note-link-head-motivated (strategy link-head) ...) -- active declareFunction, no body
;; (defun transformation-strategy-note-problem-pending (strategy problem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-note-problem-unpending (strategy problem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-activate-strategem (strategy strategem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-note-strategem-set-aside (strategy strategem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-clear-strategems-set-aside (strategy) ...) -- active declareFunction, no body
;; (defun transformation-strategy-note-strategem-thrown-away (strategy strategem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-clear-set-aside-problems (strategy) ...) -- active declareFunction, no body

(note-funcall-helper-function 'transformation-strategy-problem-totally-pending?)
