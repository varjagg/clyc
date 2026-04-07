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

(defglobal *test-case-table-index*
  (if (and (boundp '*test-case-table-index*)
           (hash-table-p *test-case-table-index*))
      *test-case-table-index*
      (make-hash-table :size 212))
  "[Cyc] An index of test case names (keywords) -> tables (lists) of (args-to-eval . expected-results) tuples.")

(defglobal *ordered-test-cases*
  (if (boundp '*ordered-test-cases*)
      *ordered-test-cases*
      nil)
  "[Cyc] An ordered list of test case names, in order of definition.")

(deflexical *test-case-tables-by-class* (make-hash-table :size 64)
  "[Cyc] All the test-cases sorted by what classes they belong to.")

(deflexical *generic-test-results* '(:success :failure :error :not-run :invalid)
  "[Cyc] The possible statuses for generic tests.")

(deflexical *generic-test-verbosity-levels* '(:silent :terse :verbose :post-build)
  "[Cyc] The possible levels of verbosity for generic tests.")

(deflexical *test-case-table-post-build-token* :tct
  "[Cyc] The token identifying 'test case table' in the space of post-build tests.")

;; (defun all-generic-test-cases () ...) -- active declareFunction, no body

(defstruct (generic-test-case-table
            (:conc-name "GTCT-")
            (:constructor make-generic-test-case-table-struct)
            (:print-function default-struct-print-function))
  name
  tuples
  test
  owner
  classes
  kb
  working?)

(defun make-generic-test-case-table (&optional arglist)
  (let ((obj (make-generic-test-case-table-struct)))
    (loop for (key value) on arglist by #'cddr do
      (case key
        (:name (setf (gtct-name obj) value))
        (:tuples (setf (gtct-tuples obj) value))
        (:test (setf (gtct-test obj) value))
        (:owner (setf (gtct-owner obj) value))
        (:classes (setf (gtct-classes obj) value))
        (:kb (setf (gtct-kb obj) value))
        (:working? (setf (gtct-working? obj) value))
        (otherwise (error "Invalid slot ~S for construction function" key))))
    obj))

(defun new-generic-test-case-table (name tuples test owner &optional classes (kb :tiny) (working? t))
  (when (null test)
    (setf test #'equal))
  (check-type name (satisfies test-case-name-p))
  (check-type tuples (satisfies non-dotted-list-p))
  (check-type test (satisfies function-spec-p))
  (when owner
    (check-type owner string))
  (when classes
    (check-type classes list))
  (check-type kb (satisfies cyc-test-kb-p))
  (dolist (tuple tuples)
    (must (and (proper-list-p tuple)
               (length>= tuple 2))
          "~S was not a valid (<input> . <expected-results>) tuple" tuple))
  (let ((gtct (make-generic-test-case-table)))
    (setf (gtct-name gtct) name)
    (setf (gtct-tuples gtct) tuples)
    (setf (gtct-test gtct) test)
    (setf (gtct-owner gtct) owner)
    (setf (gtct-classes gtct) classes)
    (setf (gtct-kb gtct) kb)
    (setf (gtct-working? gtct) working?)
    gtct))

(defun generic-test-case-table-name (gtct)
  (gtct-name gtct))

;; (defun generic-test-case-table-tuples (gtct) ...) -- active declareFunction, no body
;; (defun generic-test-case-table-kb (gtct) ...) -- active declareFunction, no body
;; (defun generic-test-case-table-owner (gtct) ...) -- active declareFunction, no body
;; (defun generic-test-case-table-working? (gtct) ...) -- active declareFunction, no body
;; (defun generic-test-case-table-comment (gtct) ...) -- active declareFunction, no body
;; (defun generic-test-case-table-tuples-mentioning-some-invalid-constant (gtct) ...) -- active declareFunction, no body
;; (defun generic-test-case-table-tuple-mentions-invalid-constant? (tuple) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list47 = (TEST-CASE-NAME (&KEY TEST OWNER CLASSES (KB :TINY) (WORKING? T)) &BODY TUPLES)
;; $sym50$DEFINE_TEST_CASE_TABLE_INT is registered as macro helper for DEFINE-TEST-CASE-TABLE
;; $sym51$QUOTE, $sym52$LIST suggest quoting the name and wrapping tuples in LIST
(defmacro define-test-case-table (test-case-name (&key test owner classes (kb :tiny) (working? t)) &body tuples)
  `(define-test-case-table-int ',test-case-name
                               (list :owner ,owner :test ,test :classes ,classes :kb ,kb :working? ,working?)
                               (list ,@tuples)))

;; (defun undefine-test-case-table (name) ...) -- active declareFunction, no body
;; (defun undefine-all-test-case-tables () ...) -- active declareFunction, no body
;; (defun run-test-case-table (name &optional verbosity stream output-format) ...) -- active declareFunction, no body
;; (defun run-all-test-case-tables (&optional stream verbosity output-format stop-at-first-failure? output-format2) ...) -- active declareFunction, no body
;; (defun run-test-case-tables-of-class (class &optional stream verbosity output-format) ...) -- active declareFunction, no body
;; (defun run-test-case-tables (tables &optional stream verbosity output-format) ...) -- active declareFunction, no body
;; (defun generic-test-result-p (object) ...) -- active declareFunction, no body
;; (defun generic-test-success-result-p (object) ...) -- active declareFunction, no body
;; (defun generic-test-failure-result-p (object) ...) -- active declareFunction, no body
;; (defun generic-test-error-result-p (object) ...) -- active declareFunction, no body
;; (defun generic-test-not-run-result-p (object) ...) -- active declareFunction, no body
;; (defun generic-test-invalid-result-p (object) ...) -- active declareFunction, no body
;; (defun generic-test-verbosity-level-p (object) ...) -- active declareFunction, no body
;; (defun test-cases-of-class (class) ...) -- active declareFunction, no body
;; (defun test-case-name-p (object) ...) -- active declareFunction, no body
;; (defun possibly-function-symbol-p (object) ...) -- active declareFunction, no body

(defun define-test-case-table-int (test-case-name properties tuples)
  (destructuring-bind (&key owner test classes (kb nil) (working? t) &allow-other-keys) properties
    (let ((gtct (new-generic-test-case-table test-case-name tuples test owner classes kb working?)))
      (dolist (class classes)
        (setf (gethash class *test-case-tables-by-class*)
              (adjoin test-case-name (gethash class *test-case-tables-by-class*))))
      (pushnew-last test-case-name *ordered-test-cases* (function eql))
      (setf (gethash test-case-name *test-case-table-index*) gtct)
      (new-cyc-test *cyc-test-filename* gtct)
      test-case-name)))

;; (defun run-generic-test-case-int (gtct verbosity stream output-format) ...) -- active declareFunction, no body
;; (defun run-test-case-table-int (name gtct tuples verbosity stream output-format stop-at-first-failure?) ...) -- active declareFunction, no body
;; (defun run-test-case-table? (gtct) ...) -- active declareFunction, no body
;; (defun run-test-case-tuple-int (name tuple test verbosity stream output-format) ...) -- active declareFunction, no body
;; (defun determine-run-test-case-tuple-result (tuple test output-format) ...) -- active declareFunction, no body
;; (defun generic-test-result-update (old-result new-result) ...) -- active declareFunction, no body
;; (defun get-gtct-by-name (name) ...) -- active declareFunction, no body
;; (defun test-case-classes (name) ...) -- active declareFunction, no body
;; (defun run-test-case-table-print-header (name verbosity stream) ...) -- active declareFunction, no body
;; (defun run-test-case-table-print-footer (name result owner verbosity stream) ...) -- active declareFunction, no body
;; (defun run-test-case-tuple-print-header (name tuple verbosity stream) ...) -- active declareFunction, no body
;; (defun run-test-case-tuple-print-footer (name result test verbosity stream) ...) -- active declareFunction, no body
;; (defun cfasl-output-object-generic-test-case-table-method (object stream) ...) -- active declareFunction, no body
;; (defun cfasl-wide-output-generic-test-case-table (gtct stream) ...) -- active declareFunction, no body
;; (defun cfasl-output-generic-test-case-table (gtct stream) ...) -- active declareFunction, no body
;; (defun cfasl-input-generic-test-case-table (stream) ...) -- active declareFunction, no body

(defconstant *cfasl-wide-opcode-generic-test-case-table* 512)

(toplevel
  (declare-defglobal '*test-case-table-index*)
  (declare-defglobal '*ordered-test-cases*)
  (register-macro-helper 'define-test-case-table-int 'define-test-case-table)
  (register-wide-cfasl-opcode-input-function *cfasl-wide-opcode-generic-test-case-table* 'cfasl-input-generic-test-case-table))
