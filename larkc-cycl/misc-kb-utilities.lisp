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

(deflexical *kb-handle-internal-method-table* (make-array '(256) :initial-element nil)
  "[Cyc] Method dispatch table for KB-HANDLE-INTERNAL, indexed by type tag.")

(defparameter *find-object-by-kb-handle-methods* nil
  "[Cyc] Alist of (type method) pairs for finding objects by KB handle.")

;;; Functions -- ordered per declare_misc_kb_utilities_file

;; (defun kill-proprietary-constants (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun make-lispy-form (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun cycl-from-id (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun name-of-car (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun kb-handle (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun kb-handle-internal (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body

(defun kb-handle-internal-constant-method (object)
  "[Cyc] Return KB handle values for a constant OBJECT."
  (values :constant (constant-internal-id object)))

(defun kb-handle-internal-nart-method (object)
  "[Cyc] Return KB handle values for a NART OBJECT."
  (declare (ignore object))
  ;; missing-larkc 4609 -- likely returns (values :nart (nart-id object)),
  ;; analogous to the constant/variable/assertion/deduction methods
  (missing-larkc 4609))

;; (defun kb-handle-internal-nart (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body

(defun kb-handle-internal-variable-method (object)
  "[Cyc] Return KB handle values for a variable OBJECT."
  (values :variable (variable-id object)))

(defun kb-handle-internal-assertion-method (object)
  "[Cyc] Return KB handle values for an assertion OBJECT."
  (values :assertion (assertion-id object)))

(defun kb-handle-internal-deduction-method (object)
  "[Cyc] Return KB handle values for a deduction OBJECT."
  (values :deduction (deduction-id object)))

;; (defun find-object-by-kb-handle (type id) ...) -- commented declareFunction, 2 required, 0 optional, no body

(defun register-find-object-by-kb-handle-method (type method)
  "[Cyc] Register METHOD for finding objects of TYPE by KB handle."
  (setf *find-object-by-kb-handle-methods*
        (delete type *find-object-by-kb-handle-methods* :key #'first :test #'eql))
  (push (list type method) *find-object-by-kb-handle-methods*)
  nil)

;; (defun list-kb-handle (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun fi-object-from-handle (arg &optional opt) ...) -- commented declareFunction, 1 required, 1 optional, no body
;; (defun get-term-id (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body. Also has $get_term_id$UnaryFunction (missing-larkc 4607)
;; (defun term-from-id (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun not-a-cyc-constant? (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun gather-constants (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun constant-or-nat? (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun nat-object? (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun remove-mt-assertions (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun empty-mt-p (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun coerce-name (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun terms-in-mt (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun assertion-ids-in-mt (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun try-unassert (arg1 arg2) ...) -- commented declareFunction, 2 required, 0 optional, no body
;; (defun try-assert (arg1 arg2 &optional opt1 opt2) ...) -- commented declareFunction, 2 required, 2 optional, no body
;; (defun try-unassert-now (arg1 arg2) ...) -- commented declareFunction, 2 required, 0 optional, no body
;; (defun try-assert-now (arg1 arg2 &optional opt1 opt2) ...) -- commented declareFunction, 2 required, 2 optional, no body
;; (defun fast-assert-int (arg1 arg2 &optional opt1 opt2 opt3 opt4 opt5) ...) -- commented declareFunction, 2 required, 5 optional, no body

(defun possibly-clear-genl-pos (assertion)
  "[Cyc] Used in various afterAddings that affect genl-pos?"
  (declare (ignore assertion))
  :checked)

;; (defun guess-fort (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun fort-for-string (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun read-terms-from-file (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun read-from-string-ignoring-all-errors (arg &optional opt1 opt2 opt3) ...) -- commented declareFunction, 1 required, 3 optional, no body
;; (defun string-to-formula (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun find-or-create-nart-from-text (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun resolve-constant (arg &optional opt) ...) -- commented declareFunction, 1 required, 1 optional, no body
;; (defun instance-named-fn-expression-p (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun instance-named-fn-term-p (arg) ...) -- commented declareFunction, 1 required, 0 optional, no body

;;; Setup

;; Method table registrations for *kb-handle-internal-method-table*
;; In SubL, these use Structures.register_method with integer type tags ($dtp_constant$, etc.)
;; In CL, the type-tag dispatch mechanism is not ported; these registrations are inert.
;; The individual *-method functions above are callable directly or via typecase dispatch.

(toplevel
  (register-find-object-by-kb-handle-method :constant 'find-constant-by-internal-id)
  (register-find-object-by-kb-handle-method :nart 'find-nart-by-id)
  (register-find-object-by-kb-handle-method :variable 'find-variable-by-id)
  (register-find-object-by-kb-handle-method :assertion 'find-assertion-by-id)
  (register-find-object-by-kb-handle-method :deduction 'find-deduction-by-id))
