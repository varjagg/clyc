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

;;;; NOTE: This is a PARTIAL port. The bijection file is listed in readme.md
;;;; under "File Exists But the Implementation is missing-larkc" — almost all
;;;; function bodies are missing-larkc. Only the defstruct, constants,
;;;; variables, two reconstructable macros, and comment stubs for every
;;;; declared function are ported here. Functional bijection operations
;;;; (add/lookup/remove/etc.) are NOT reimplemented.


;;;; Variables

(deflexical *bijection-high-water-mark* 40)

(deflexical *bijection-low-water-mark* 30)


;;;; BIJECTION struct — 4 slots: size, database, inverse-database, test
;; The Java _csetf_ accessor names are BIJECTION-SIZE, BIJECTION-DATABASE,
;; BIJECTION-INVERSE-DATABASE, BIJECTION-TEST, so the defstruct conc-name
;; is the default "BIJECTION-".

(defstruct bijection
  size
  database
  inverse-database
  test)

(defconstant *dtp-bijection* 'bijection)

;; bijection-p is provided by defstruct
;; bijection-size is provided by defstruct
;; bijection-database is provided by defstruct
;; bijection-inverse-database is provided by defstruct
;; bijection-test is provided by defstruct
;; _csetf-bijection-size is setf of bijection-size
;; _csetf-bijection-database is setf of bijection-database
;; _csetf-bijection-inverse-database is setf of bijection-inverse-database
;; _csetf-bijection-test is setf of bijection-test
;; make-bijection is provided by defstruct

;; (defun bijection-style (bijection) ...) -- commented declareFunction, no body
;; (defun bijection-style-error (bijection) ...) -- commented declareFunction, no body
;; (defun bijection-lookup-alist-style (bijection key default) ...) -- commented declareFunction, no body
;; (defun bijection-enter-alist-style (bijection key value) ...) -- commented declareFunction, no body
;; (defun bijection-remove-alist-style (bijection key) ...) -- commented declareFunction, no body
;; (defun bijection-inverse-lookup-alist-style (bijection value default) ...) -- commented declareFunction, no body
;; (defun bijection-inverse-enter-alist-style (bijection value key) ...) -- commented declareFunction, no body
;; (defun bijection-inverse-remove-alist-style (bijection value) ...) -- commented declareFunction, no body
;; (defun make-hashtable-bijection-from-alist (bijection) ...) -- commented declareFunction, no body
;; (defun bijection-lookup-hashtable-style (bijection key default) ...) -- commented declareFunction, no body
;; (defun bijection-enter-hashtable-style (bijection key value) ...) -- commented declareFunction, no body
;; (defun bijection-remove-hashtable-style (bijection key) ...) -- commented declareFunction, no body
;; (defun bijection-inverse-lookup-hashtable-style (bijection value default) ...) -- commented declareFunction, no body
;; (defun bijection-inverse-enter-hashtable-style (bijection value key) ...) -- commented declareFunction, no body
;; (defun bijection-inverse-remove-hashtable-style (bijection value) ...) -- commented declareFunction, no body
;; (defun bijection-remove-hashtable-style-int (bijection key value) ...) -- commented declareFunction, no body
;; (defun make-alist-bijection-from-hashtable (bijection) ...) -- commented declareFunction, no body
;; (defun new-bijection (&optional initial-size test) ...) -- commented declareFunction, no body
;; (defun clear-bijection (bijection) ...) -- commented declareFunction, no body
;; (defun bijection-empty-p (bijection) ...) -- commented declareFunction, no body
;; (defun non-empty-bijection-p (bijection) ...) -- commented declareFunction, no body
;; (defun bijection-lookup (bijection key &optional default) ...) -- commented declareFunction, no body
;; (defun bijection-inverse-lookup (bijection value &optional default) ...) -- commented declareFunction, no body
;; (defun bijection-enter (bijection key value) ...) -- commented declareFunction, no body
;; (defun bijection-inverse-enter (bijection value key) ...) -- commented declareFunction, no body
;; (defun bijection-remove (bijection key) ...) -- commented declareFunction, no body
;; (defun bijection-inverse-remove (bijection value) ...) -- commented declareFunction, no body
;; (defun new-bijection-iterator (bijection) ...) -- commented declareFunction, no body

;; do-bijection — commented declareMacro
;; Reconstructed from Internal Constants:
;;   $list30 = ((KEY VALUE BIJECTION &KEY DONE) &BODY BODY) — macro arglist
;;   $list31 = (:DONE), $kw32$ALLOW_OTHER_KEYS, $kw33$DONE — keyword validation
;;   $sym34$BIJECTION_VAR = makeUninternedSymbol("BIJECTION-VAR") — gensym
;;   $sym35$CLET, $sym36$PCASE, $sym41$OTHERWISE — operators in expansion
;;   $sym37$DO_BIJECTION_STYLE, $sym38$DO_ALIST, $sym39$DO_BIJECTION_DATABASE,
;;   $sym40$DO_HASH_TABLE, $sym42$BIJECTION_STYLE_ERROR — dispatch helpers
;; DO-BIJECTION-STYLE and DO-BIJECTION-DATABASE are registered as macro-helpers
;; for DO-BIJECTION via register-macro-helper in setup.
(defmacro do-bijection ((key value bijection &key done) &body body)
  "[Cyc] Iterate BIJECTION, binding KEY and VALUE to each mapping pair."
  (with-temp-vars (bijection-var)
    `(let ((,bijection-var ,bijection))
       (case (do-bijection-style ,bijection-var)
         (:alist (do-alist (,key ,value (do-bijection-database ,bijection-var))
                   ,@body))
         (:hashtable (do-hash-table (,key ,value (do-bijection-database ,bijection-var)
                                      :done ,done)
                       ,@body))
         (otherwise (bijection-style-error ,bijection-var))))))

;; do-bijection-inverse — commented declareMacro
;; Reconstructed from Internal Constants:
;;   $list43 = ((VALUE KEY BIJECTION &KEY DONE) &BODY BODY) — macro arglist
;;     (note: VALUE and KEY are swapped vs do-bijection)
;;   $sym44$BIJECTION_VAR — separate gensym constant
;;   $sym45$DO_BIJECTION_INVERSE_DATABASE — inverse-database helper
;; DO-BIJECTION-INVERSE-DATABASE is registered as a macro-helper for DO-BIJECTION
;; in setup (alongside the forward helpers).
(defmacro do-bijection-inverse ((value key bijection &key done) &body body)
  "[Cyc] Iterate BIJECTION inverse, binding VALUE and KEY to each mapping pair."
  (with-temp-vars (bijection-var)
    `(let ((,bijection-var ,bijection))
       (case (do-bijection-style ,bijection-var)
         (:alist (do-alist (,value ,key (do-bijection-inverse-database ,bijection-var))
                   ,@body))
         (:hashtable (do-hash-table (,value ,key (do-bijection-inverse-database ,bijection-var)
                                      :done ,done)
                       ,@body))
         (otherwise (bijection-style-error ,bijection-var))))))

;; do-bijection-style (bijection) — active declareFunction, no body (macro-helper for do-bijection)
;; (defun do-bijection-style (bijection) ...) -- active declareFunction, no body
;; do-bijection-database (bijection) — active declareFunction, no body (macro-helper for do-bijection)
;; (defun do-bijection-database (bijection) ...) -- active declareFunction, no body
;; do-bijection-inverse-database (bijection) — active declareFunction, no body (macro-helper for do-bijection)
;; (defun do-bijection-inverse-database (bijection) ...) -- active declareFunction, no body

;; (defun bijection-keys (bijection) ...) -- commented declareFunction, no body
;; (defun bijection-values (bijection) ...) -- commented declareFunction, no body
;; (defun bijection-to-alist (bijection) ...) -- commented declareFunction, no body
;; (defun bijection-to-hashtable (bijection) ...) -- commented declareFunction, no body
;; (defun print-bijection-contents (bijection &optional stream) ...) -- commented declareFunction, no body


;;;; Setup

(toplevel
  ;; Structures.register_method for print-object-method-table is expressed as the
  ;; defmethod print-object on bijection above. def_csetf calls are elided —
  ;; CL setf handles defstruct accessors natively.
  (register-macro-helper 'do-bijection-style 'do-bijection)
  (register-macro-helper 'do-bijection-database 'do-bijection)
  (register-macro-helper 'do-bijection-inverse-database 'do-bijection))
