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

;; Macros (commented declareMacro)
;; (defmacro with-new-testing-environement ...) -- commented declareMacro, no body
;; (defmacro timing-no-functions ...) -- commented declareMacro, no body
;; (defmacro timing-all-functions ...) -- commented declareMacro, no body
;; (defmacro timing-these-functions (functions &body body) ...) -- commented declareMacro, no body
;; (defun report-fun (fun) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun report-time (fun) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun report-timing-info (&optional stream) ...) -- commented declareFunction, 0 required, 1 optional, no body
;; (defun report-time-testing-info () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun clear-timing-info () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun clear-time-testing-info () ...) -- commented declareFunction, 0 required, 0 optional, no body

(defun timing-info-print-function-trampoline (object stream)
  "[Cyc] Trampoline for printing timing-info objects."
  (missing-larkc 12094))

;; (defun timing-info-p (object) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun timing-info-count (object) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun timing-info-total (object) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun timing-info-max (object) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun _csetf-timing-info-count (object value) ...) -- commented declareFunction, 2 required, 0 optional, no body
;; (defun _csetf-timing-info-total (object value) ...) -- commented declareFunction, 2 required, 0 optional, no body
;; (defun _csetf-timing-info-max (object value) ...) -- commented declareFunction, 2 required, 0 optional, no body
;; (defun make-timing-info (&optional plist) ...) -- commented declareFunction, 0 required, 1 optional, no body
;; (defun print-timing-info (object stream depth) ...) -- commented declareFunction, 3 required, 0 optional, no body
;; (defun time-function? (fun) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun record-time (fun time) ...) -- commented declareFunction, 2 required, 0 optional, no body
;; (defun new-timing-info (time) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun update-timing-info (timing-info time) ...) -- commented declareFunction, 2 required, 0 optional, no body

;; Macros (commented declareMacro)
;; (defmacro deftimed-generic ...) -- commented declareMacro, no body
;; (defmacro deftimed-private ...) -- commented declareMacro, no body
;; (defmacro deftimed-protected ...) -- commented declareMacro, no body
;; (defmacro deftimed ...) -- commented declareMacro, no body
;; (defmacro deftimed-public ...) -- commented declareMacro, no body
;; (defmacro deftimed-api ...) -- commented declareMacro, no body

;; Variables

(defparameter *time-testing-environment* (make-hash-table :size 10)
  "[Cyc] The storage place for timing runs, parameterized by some key")

(defparameter *timing-table* (make-hash-table :size 10)
  "[Cyc] The storage place for the timing info in this run pertaining to a function")

(defparameter *utilize-timing-hooks* t
  "[Cyc] Do we want to time anything at all?")

(defparameter *all-currently-active* nil
  "[Cyc] a boolean describing scope of timing focus.. if true, everything deftimed contributes to timing reports")

(defparameter *timed-funs* nil
  "[Cyc] Those specific functions you're interested in timing")

;; Struct

(defstruct timing-info
  count
  total
  max)

(defconstant *dtp-timing-info* 'timing-info)
