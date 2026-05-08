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

;; interval_span.java is nearly entirely missing-larkc: of 18 active
;; declareFunctions, only interval_span_print_function_trampoline has a
;; Java method body (and that body is handleMissingMethodError 29643).
;; The $interval_span_p$UnaryFunction inner class holds a missing-larkc predicate
;; override referencing number 29641. The remaining 16 functions exist only
;; as declareFunction entries with no corresponding method — they are ported
;; as comment stubs per the DIRECT PORT rule (no inventing bodies).

;; --- defstruct interval-span ---
;; struct-decl $list2 = (START END) — slot names
;; struct-decl $list4 = (INT-SPAN-START INT-SPAN-END) — accessor names (conc-name INT-SPAN-)
;; print-object is missing-larkc 29643 — CL's default print-object handles this.
(defstruct (interval-span (:conc-name "INT-SPAN-"))
  start
  end)

(defconstant *dtp-interval-span* 'interval-span)

;; (defun interval-span-p (object) ...) -- active declareFunction, no body (predicate provided by defstruct; $interval_span_p$UnaryFunction overrides with missing-larkc 29641)
;; (defun int-span-start (interval-span) ...) -- active declareFunction, no body (accessor provided by defstruct)
;; (defun int-span-end (interval-span) ...) -- active declareFunction, no body (accessor provided by defstruct)
;; _csetf-int-span-start -- active declareFunction, no body (CL setf handles natively)
;; _csetf-int-span-end -- active declareFunction, no body (CL setf handles natively)
;; (defun make-interval-span (&optional arglist) ...) -- active declareFunction, no body (constructor provided by defstruct)
;; (defun print-interval-span (interval-span stream depth) ...) -- active declareFunction, no body
;; (defun lookup-interval-span (start end) ...) -- active declareFunction, no body
;; (defun new-interval-span (start end) ...) -- active declareFunction, no body
;; (defun get-interval-span (start end) ...) -- active declareFunction, no body
;; (defun interval-span-start (interval-span) ...) -- active declareFunction, no body
;; (defun interval-span-end (interval-span) ...) -- active declareFunction, no body
;; (defun interval-span-length (interval-span) ...) -- active declareFunction, no body
;; (defun interval-span-> (interval-span-1 interval-span-2) ...) -- active declareFunction, no body
;; (defun interval-span-< (interval-span-1 interval-span-2) ...) -- active declareFunction, no body
;; (defun interval-span-precedes? (interval-span-1 interval-span-2) ...) -- active declareFunction, no body
;; (defun interval-span-subsumes? (interval-span-1 interval-span-2) ...) -- active declareFunction, no body

;; --- init phase ---
;; $interval_span_table$ is a dictionary (hash-table per clyc convention) keyed by EQL.
(deflexical *interval-span-table* (make-hash-table :test 'eql))

;; --- setup phase ---
;; Structures.register_method for print-object-method-table is now expressed as
;; the defmethod print-object above.
;; Structures.def_csetf calls are elided — CL setf handles defstruct accessors natively.
(toplevel
  (identity 'interval-span))
