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

(defstruct (new-root-strategy-data
            (:conc-name "NR-STRAT-DATA-")
            (:constructor make-new-root-strategy-data-int ()))
  new-root-index)

(defconstant *dtp-new-root-strategy-data* 'new-root-strategy-data)

;; (defun new-root-strategy-data-print-function-trampoline (object stream) ...) -- active declareFunction, no body

(defun new-root-strategy-data-p (object)
  (typep object 'new-root-strategy-data))

(defun make-new-root-strategy-data (&optional arglist)
  (let ((v-new (make-new-root-strategy-data-int)))
    (loop for next = arglist then (cddr next)
          while next
          for current-arg = (first next)
          for current-value = (second next)
          do (case current-arg
               (:new-root-index
                (setf (nr-strat-data-new-root-index v-new) current-value))
               (otherwise
                (error "Invalid slot ~S for construction function" current-arg))))
    v-new))

;; (defun new-new-root-strategy-data (new-root-index) ...) -- active declareFunction, no body
;; (defun new-root-strategy-new-root-index (strategy) ...) -- active declareFunction, no body
;; (defun new-root-strategy-problem-active? (strategy problem) ...) -- active declareFunction, no body
;; (defun new-root-strategy-peek-new-root (strategy) ...) -- active declareFunction, no body
;; (defun new-root-strategy-note-problem-motivated (strategy problem) ...) -- active declareFunction, no body
;; (defun new-root-strategy-add-new-root (strategy problem) ...) -- active declareFunction, no body
;; (defun new-root-strategy-pop-new-root (strategy) ...) -- active declareFunction, no body
;; (defun new-root-strategy-no-new-roots? (strategy) ...) -- active declareFunction, no body
