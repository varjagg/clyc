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

;; Struct definition — generates accessors, predicate, constructor, and setf accessors.
;; Covers: cycml-kp-info-p, cycml-kp-info-knowledge-package-id, etc.,
;; _csetf-cycml-kp-info-*, make-cycml-kp-info

;; print-object is missing-larkc 4133 — CL's default print-object handles this.
(defstruct cycml-kp-info
  knowledge-package-id
  knowledge-package-dependencies
  operations)

(defconstant *dtp-cycml-kp-info* 'cycml-kp-info)

;; Declare phase (following declare_cycml_generator_file order)

;; (defun cycml-serialize-knowledge-package-info (info) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-api-request (id formula mt bindings requestor) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-justification (justification) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-truth (truth &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-api-request-requestor (requestor &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-api-request-priority (priority &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-api-request-id (id &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-nonnegativeinteger (n &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-positiveinteger (n &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-new-name (name &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-date (date &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-time (time &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-cyc-image-id (id &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-knowledge-package-id (id &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-sublsymbol (symbol &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-sublstring (string &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-sublrealnumber (number &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-cyclvariable (variable &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-uri (uri &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-namespace (namespace &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-false (object &optional stream) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-true (object &optional stream) ...) -- commented declareFunction, no body

;; (defun cycml-kp-info-p (object) ...) -- commented declareFunction, no body
;; (defun cycml-kp-info-knowledge-package-id (info) ...) -- commented declareFunction, no body
;; (defun cycml-kp-info-knowledge-package-dependencies (info) ...) -- commented declareFunction, no body
;; (defun cycml-kp-info-operations (info) ...) -- commented declareFunction, no body
;; (defun _csetf-cycml-kp-info-knowledge-package-id (info value) ...) -- commented declareFunction, no body
;; (defun _csetf-cycml-kp-info-knowledge-package-dependencies (info value) ...) -- commented declareFunction, no body
;; (defun _csetf-cycml-kp-info-operations (info value) ...) -- commented declareFunction, no body
;; (defun make-cycml-kp-info (&optional arglist) ...) -- commented declareFunction, no body
;; (defun print-cycml-kp-info (object stream depth) ...) -- commented declareFunction, no body
;; (defun cycml-add-create-constant-oper (info constant &optional cyclist cyc-image-id operation-time operation-second purpose) ...) -- commented declareFunction, no body
;; (defun cycml-add-find-or-create-constant-oper (info constant &optional cyclist cyc-image-id operation-time operation-second purpose) ...) -- commented declareFunction, no body
;; (defun cycml-add-rename-constant-oper (info constant new-name &optional cyc-image-id operation-time) ...) -- commented declareFunction, no body
;; (defun cycml-add-merge-fort-oper (info fort-1 fort-2 &optional cyc-image-id operation-time) ...) -- commented declareFunction, no body
;; (defun cycml-add-kill-fort-oper (info fort &optional cyclist cyc-image-id operation-time) ...) -- commented declareFunction, no body
;; (defun cycml-add-assert-oper (info assertion &optional mt strength direction cyclist cyc-image-id operation-time operation-second purpose) ...) -- commented declareFunction, no body
;; (defun cycml-add-reassert-oper (info assertion &optional mt strength direction cyclist cyc-image-id operation-time operation-second purpose) ...) -- commented declareFunction, no body
;; (defun cycml-add-unassert-oper (info assertion &optional mt cyclist cyc-image-id operation-time) ...) -- commented declareFunction, no body
;; (defun cycml-add-blast-assertion-oper (info assertion &optional mt cyclist cyc-image-id operation-time) ...) -- commented declareFunction, no body
;; (defun cycml-add-create-skolem-oper (info external-id unreified-sk-term mt cnfs arg-types cyclist cyc-image-id operation-time) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-knowledge-package (info) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-operation (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-create-constant-oper (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-find-or-create-constant-oper (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-rename-constant-oper (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-merge-forts-oper (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-kill-fort-oper (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-assert-oper (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-reassert-oper (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-unassert-oper (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-blast-assertion-oper (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-create-skolem-oper (oper) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-bookkeeping (cyclist cyc-image-id operation-time operation-second purpose) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-microtheory (mt) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-fort (fort) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-cyclconstant (constant) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-cyclreifiednonatomicterm (nart) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-cyclreifiablenonatomicterm (nat) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-elnonatomicterm (nat) ...) -- commented declareFunction, no body

;; Commented declareMacro: within-cycl-atomic-sentence
;; Reconstructed from evidence: $sym103$CLET, $list104 = ((#:*WITHIN-CYCL-ATOMIC-SENTENCE?* T))
(defmacro within-cycl-atomic-sentence (&body body)
  `(let ((*within-cycl-atomic-sentence?* t))
     ,@body))

;; (defun cycml-serialize-object (object) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-object-to-string (object) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-subllist (list) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-cyclsentence (sentence) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-cyclatomicsentence (sentence) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-purpose (purpose) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-universal-date (date) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-universal-second (second) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-support (support) ...) -- commented declareFunction, no body
;; (defun cycml-serialize-hl-support (support) ...) -- commented declareFunction, no body

;; Init phase

(defparameter *within-cycl-atomic-sentence?* nil
  "[Cyc] When T the serialization context is within an atomic sentence and lists
are more likely to be interpreted as el nats.")

;; Setup phase

(register-external-symbol 'cycml-serialize-object-to-string)
