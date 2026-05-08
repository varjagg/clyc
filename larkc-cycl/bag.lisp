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

;; This is a PARTIAL PORT — bag.java is listed under
;; "File Exists But the Implementation is missing-larkc" in readme.md.
;; Function bodies (except cfasl-output-object-bag-method) are stripped. CL has
;; no native multi-set, so the defstruct, stubs, and setup scaffolding are
;; preserved here. A native reimplementation is deliberately NOT written — this
;; file is a direct Java port only.

;; --- defstruct bag ---
;; print-object is missing-larkc 6700 — CL's default print-object handles this.

(defstruct (bag (:conc-name "BAG-STRUCT-"))
  unique-contents
  repeat-contents
  repeat-size
  test)

;; (defun bag-p (object) ...) -- commented declareFunction, no body
;; (defun bag-struct-unique-contents (bag) ...) -- commented declareFunction, no body (accessor provided by defstruct)
;; (defun bag-struct-repeat-contents (bag) ...) -- commented declareFunction, no body (accessor provided by defstruct)
;; (defun bag-struct-repeat-size (bag) ...) -- commented declareFunction, no body (accessor provided by defstruct)
;; (defun bag-struct-test (bag) ...) -- commented declareFunction, no body (accessor provided by defstruct)
;; _csetf-bag-struct-unique-contents -- commented declareFunction, no body (CL setf handles natively)
;; _csetf-bag-struct-repeat-contents -- commented declareFunction, no body (CL setf handles natively)
;; _csetf-bag-struct-repeat-size -- commented declareFunction, no body (CL setf handles natively)
;; _csetf-bag-struct-test -- commented declareFunction, no body (CL setf handles natively)
;; (defun make-bag (&optional arglist) ...) -- commented declareFunction, no body (constructor provided by defstruct)
;; (defun print-bag (bag stream depth) ...) -- commented declareFunction, no body
;; (defun make-new-bag (unique-contents repeat-contents repeat-size test) ...) -- commented declareFunction, no body
;; (defun new-bag-repeat-contents (repeat-size test) ...) -- commented declareFunction, no body
;; (defun copy-bag-repeat-contents (repeat-contents) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-unique-size (repeat-contents) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-empty? (repeat-contents) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-member-count (repeat-contents element test) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-member? (repeat-contents element test) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-matching-element (repeat-contents element test) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-random-element (repeat-contents) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-add (repeat-contents element test) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-delete (repeat-contents element test) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-delete-all (repeat-contents element test) ...) -- commented declareFunction, no body
;; (defun clear-bag-repeat-contents (repeat-contents) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants: $list30 arglist
;; ((ELEMENT-VAR ELEMENT-COUNT BAG-REPEAT-CONTENTS &KEY DONE) &BODY BODY),
;; $sym34$ DO-DICTIONARY-CONTENTS — iterates the repeat-contents dictionary
;; binding element-var to the key (element) and element-count to the value (count).
(defmacro do-bag-repeat-contents-unique ((element-var element-count bag-repeat-contents &key done) &body body)
  `(do-dictionary-contents (,element-var ,element-count ,bag-repeat-contents :done ,done)
     ,@body))

;; Reconstructed from Internal Constants: $list35 arglist
;; ((ELEMENT-VAR BAG-REPEAT-CONTENTS &KEY DONE) &BODY BODY),
;; gensyms $sym36$ CURR-ELEMENT, $sym37$ ELEMENT-COUNT, $sym38$ INDEX;
;; operators $sym39$ DO-BAG-REPEAT-CONTENTS-UNIQUE, $sym40$ CDOTIMES.
;; $list42 (TIMES ELEMENT CONTENTS-ITERATOR) and $kw43$ UNINITIALIZED appear in
;; the orphans but their precise placement in the expansion is unclear; the
;; structurally-natural expansion is to iterate (element, count) pairs and
;; yield element-var element-count times.
;; TODO - $list42 binding-list placement unverified.
(defmacro do-bag-repeat-contents ((element-var bag-repeat-contents &key done) &body body)
  (with-temp-vars (curr-element element-count index)
    `(do-bag-repeat-contents-unique (,curr-element ,element-count ,bag-repeat-contents :done ,done)
       (cdotimes (,index ,element-count)
         (declare (ignore ,index))
         (let ((,element-var ,curr-element))
           ,@body)))))

;; (defun map-bag-repeat-contents (function repeat-contents &optional arg) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-element-list (repeat-contents) ...) -- commented declareFunction, no body
;; (defun bag-repeat-contents-unique-element-list (repeat-contents) ...) -- commented declareFunction, no body
;; (defun make-bag-iterator-state (bag) ...) -- commented declareFunction, no body
;; (defun iterate-bag-done (state) ...) -- commented declareFunction, no body
;; (defun iterate-bag-next (state) ...) -- commented declareFunction, no body
;; (defun new-bag-repeat-contents-iterator (repeat-contents) ...) -- commented declareFunction, no body
;; (defun new-bag-unique-contents (size test) ...) -- commented declareFunction, no body
;; (defun copy-bag-unique-contents (unique-contents) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-unique-size (unique-contents) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-empty? (unique-contents) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-member? (unique-contents element test) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-member-count (unique-contents element test) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-matching-element (unique-contents element test) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-random-element (unique-contents) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-add (unique-contents element test) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-delete (unique-contents element test) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-delete-all (unique-contents element test) ...) -- commented declareFunction, no body
;; (defun clear-bag-unique-contents (unique-contents) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants: $list47 arglist
;; ((ELEMENT-VAR BAG-UNIQUE-CONTENTS &KEY DONE) &BODY BODY),
;; $sym48$ DO-SET-CONTENTS — iterates over unique-contents via do-set-contents,
;; binding element-var to each element.
(defmacro do-bag-unique-contents ((element-var bag-unique-contents &key done) &body body)
  `(do-set-contents (,element-var ,bag-unique-contents :done ,done)
     ,@body))

;; (defun map-bag-unique-contents (function unique-contents &optional arg) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-element-list (unique-contents) ...) -- commented declareFunction, no body
;; (defun bag-unique-contents-unique-element-list (unique-contents) ...) -- commented declareFunction, no body
;; (defun new-bag-unique-contents-iterator (unique-contents) ...) -- commented declareFunction, no body
;; (defun new-bag-contents-iterator (unique-contents repeat-contents) ...) -- commented declareFunction, no body
;; (defun new-bag (&optional size test) ...) -- commented declareFunction, no body
;; (defun copy-bag (bag) ...) -- commented declareFunction, no body
;; (defun new-bag-from-elements (elements &optional size test) ...) -- commented declareFunction, no body
;; (defun bag-test (bag) ...) -- commented declareFunction, no body
;; (defun bag-size (bag) ...) -- commented declareFunction, no body
;; (defun bag-unique-size (bag) ...) -- commented declareFunction, no body
;; (defun bag-empty? (bag) ...) -- commented declareFunction, no body
;; (defun empty-bag-p (bag) ...) -- commented declareFunction, no body
;; (defun non-empty-bag-p (bag) ...) -- commented declareFunction, no body
;; (defun bag-member? (bag element) ...) -- commented declareFunction, no body
;; (defun bag-member-count (bag element) ...) -- commented declareFunction, no body
;; (defun bag-matching-element (bag element) ...) -- commented declareFunction, no body
;; (defun bag-random-element (bag) ...) -- commented declareFunction, no body
;; (defun bag-add (bag element) ...) -- commented declareFunction, no body
;; (defun bag-remove (bag element) ...) -- commented declareFunction, no body
;; (defun bag-remove-all (bag element) ...) -- commented declareFunction, no body
;; (defun clear-bag (bag) ...) -- commented declareFunction, no body
;; (defun new-bag-iterator (bag) ...) -- commented declareFunction, no body

;; Arglist reconstructed from $list59 = ((ELEMENT-VAR BAG &KEY DONE) &BODY BODY).
;; Evidence: $sym57$ DO-BAG-UNIQUE-CONTENTS, $sym58$ DO-BAG-UNIQUE-INTERNAL
;; (registered macro-helper via access_macros.register_macro_helper in setup).
;; The macro should dispatch on bag's unique-contents representation: either
;; do-bag-unique-contents when a set-contents exists, or do-bag-unique-internal
;; when iterating through repeat-contents unique keys.
;; TODO - dispatch shape uncertain without an expansion site to verify.
(defmacro do-bag-unique ((element-var bag &key done) &body body)
  (declare (ignore element-var bag done body))
  (error "do-bag-unique: macro body unreconstructed; relies on do-bag-unique-internal helper whose shape is unverified."))

;; Arglist reconstructed from $list52 = ((ELEMENT-VAR ELEMENT-COUNT BAG &KEY DONE) &BODY BODY).
;; Evidence: $sym54$ DO-BAG-REPEAT-INTERNAL (registered macro-helper),
;; $sym53$ PROGN, $sym55$ PUNLESS, $list56 (1). Dispatches through
;; do-bag-repeat-internal to iterate element-var over each element, element-count
;; over the count.
;; TODO - dispatch shape uncertain without an expansion site to verify.
(defmacro do-bag ((element-var element-count bag &key done) &body body)
  (declare (ignore element-var element-count bag done body))
  (error "do-bag: macro body unreconstructed; relies on do-bag-repeat-internal helper whose shape is unverified."))

;; (defun do-bag-repeat-internal (form) ...) -- commented declareFunction, no body (macro-helper for DO-BAG-UNIQUE)
;; (defun do-bag-unique-internal (form) ...) -- commented declareFunction, no body (macro-helper for DO-BAG-UNIQUE)
;; (defun map-bag (function bag &optional arg) ...) -- commented declareFunction, no body
;; (defun bag-element-list (bag) ...) -- commented declareFunction, no body
;; (defun bag-unique-element-list (bag) ...) -- commented declareFunction, no body
;; (defun bag-element-count-list (bag) ...) -- commented declareFunction, no body

(defun cfasl-output-object-bag-method (object stream)
  ;; Likely serializes bag as: opcode, unique-size, total-size, test, then
  ;; each unique (element, count) pair. Evidence: $cfasl-opcode-bag$ = 62.
  (declare (ignore object stream))
  (missing-larkc 6694))

;; (defun cfasl-output-bag (object stream) ...) -- commented declareFunction, no body
;; (defun cfasl-input-bag (stream) ...) -- commented declareFunction, no body
;; (defun bag-unit-test-kitchen-sink (colors total-count) ...) -- commented declareFunction, no body

;; --- init phase (initializeVariables) ---

(defconstant *dtp-bag* 'bag)

;; @note there is no empirical evidence for this number yet,
;; this is based on back of the envelope math
(deflexical *bag-repeat-contents-iterator-watermark* 8)

(deflexical *new-bag-default-test-function* (symbol-function 'eql))

(defconstant *cfasl-opcode-bag* 62)

;; --- setup phase (runTopLevelForms) ---

(toplevel
  ;; Structures.register_method(print_high.$print_object_method_table$, ...):
  ;; expressed as the defmethod print-object on bag above.
  ;; Structures.def_csetf(...) calls: elided (CL setf handles natively).
  ;; Equality.identity($sym0$BAG): elided (no-op DTP registration).
  (register-macro-helper 'do-bag-repeat-internal 'do-bag-unique)
  (register-macro-helper 'do-bag-unique-internal 'do-bag-unique)
  (register-cfasl-input-function *cfasl-opcode-bag* 'cfasl-input-bag)
  ;; Structures.register_method for $cfasl_output_object_method_table$ is the
  ;; dispatch-registration equivalent of a defmethod cfasl-output-object on
  ;; the bag type, which would call cfasl-output-object-bag-method.
  ;; generic_testing.define_test_case_table_int call is elided
  ;; (macro-helper to nonexistent macro).
  )
