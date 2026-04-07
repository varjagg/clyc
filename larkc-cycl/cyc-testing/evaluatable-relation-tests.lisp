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

;;; evaluatable-relation-test defstruct
;;; Slots: relation, id, sentence, kb, owner
;;; conc-name: ert-
(defstruct (evaluatable-relation-test
            (:conc-name "ERT-"))
  relation
  id
  sentence
  kb
  owner)

(defconstant *dtp-evaluatable-relation-test* 'evaluatable-relation-test)

(defmethod print-object ((object evaluatable-relation-test) stream)
  (evaluatable-relation-test-print-function-trampoline object stream))

(defun evaluatable-relation-test-print-function-trampoline (object stream)
  (default-struct-print-function object stream 0)
  nil)

;; (defun evaluatable-relation-test-p (object) ...) -- active declareFunction, no body. UnaryFunction: missing-larkc 32269
;; (defun ert-relation (ert) ...) -- active declareFunction, no body (struct accessor)
;; (defun ert-id (ert) ...) -- active declareFunction, no body (struct accessor). UnaryFunction: missing-larkc 32245
;; (defun ert-sentence (ert) ...) -- active declareFunction, no body (struct accessor)
;; (defun ert-kb (ert) ...) -- active declareFunction, no body (struct accessor)
;; (defun ert-owner (ert) ...) -- active declareFunction, no body (struct accessor)
;; _csetf-ert-relation, _csetf-ert-id, _csetf-ert-sentence, _csetf-ert-kb, _csetf-ert-owner are struct setf expansions, elided.
;; (defun make-evaluatable-relation-test (&optional initializer) ...) -- active declareFunction, no body (struct constructor)

(defglobal *evaluatable-relation-tests*
    (if (and (boundp '*evaluatable-relation-tests*)
             (hash-table-p *evaluatable-relation-tests*))
        *evaluatable-relation-tests*
        (make-hash-table :size 100)))

;; (defun clear-evaluatable-relation-tests () ...) -- active declareFunction, no body
;; (defun evaluatable-relations-with-evaluatable-relation-tests () ...) -- active declareFunction, no body
;; (defun evaluatable-relation-tests (relation) ...) -- active declareFunction, no body
;; (defun some-evaluatable-relation-tests? (relation) ...) -- active declareFunction, no body
;; (defun evaluatable-relation-test-name (ert) ...) -- active declareFunction, no body
;; (defun evaluatable-relation-test-owner (ert) ...) -- active declareFunction, no body
;; (defun evaluatable-relation-test-comment (ert) ...) -- active declareFunction, no body
;; (defun evaluatable-relation-test-relation (ert) ...) -- active declareFunction, no body
;; (defun evaluatable-relation-test-sentence (ert) ...) -- active declareFunction, no body
;; (defun evaluatable-relation-test-kb (ert) ...) -- active declareFunction, no body
;; (defun evaluatable-relation-test-working? (ert) ...) -- active declareFunction, no body
;; (defun evaluatable-relation-test-mentions-invalid-constant? (ert) ...) -- active declareFunction, no body
;; (defun evaluatable-relation-test-count (relation) ...) -- active declareFunction, no body
;; (defun total-evaluatable-relation-test-count () ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list30 = (FUNCTION ID SENTENCE &KEY (KB :FULL) OWNER)
;; $list31 = (:KB :OWNER), $kw32$ALLOW-OTHER-KEYS
;; $sym34$DEFINE-EVALUATABLE-RELATION-TEST-INT (5-arg function)
;; Expands to a call to define-evaluatable-relation-test-int with
;; the function symbol, id, sentence, kb, and owner.
(defmacro define-evaluatable-function-test (function id sentence &key (kb :full) owner)
  `(define-evaluatable-relation-test-int ',function ,id ',sentence ,kb ,owner))

;; Reconstructed from Internal Constants:
;; $list37 = (PREDICATE ID SENTENCE &KEY (KB :FULL) OWNER)
;; $list31 = (:KB :OWNER), $kw32$ALLOW-OTHER-KEYS
;; $sym34$DEFINE-EVALUATABLE-RELATION-TEST-INT (5-arg function)
;; Expands to a call to define-evaluatable-relation-test-int with
;; the predicate symbol, id, sentence, kb, and owner.
(defmacro define-evaluatable-predicate-test (predicate id sentence &key (kb :full) owner)
  `(define-evaluatable-relation-test-int ',predicate ,id ',sentence ,kb ,owner))

;; (defun define-evaluatable-relation-test-int (relation id sentence kb owner) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list44 = (FUNCTION ID EXPRESSION &KEY (RESULT :DONT-CARE) (KB :FULL) MT OWNER)
;; $list45 = (:RESULT :KB :MT :OWNER), $kw32$ALLOW-OTHER-KEYS
;; $sym49$DEFINE-SIMPLE-EVALUATABLE-FUNCTION-TEST-INT is a registered macro-helper
;; for this macro (see setup).
;; Expands to a call to the registered helper with the user's 7 arguments.
(defmacro define-simple-evaluatable-function-test (function id expression
                                                   &key (result :dont-care) (kb :full) mt owner)
  `(define-simple-evaluatable-function-test-int ',function ,id ',expression
                                                ,result ,kb ,mt ,owner))

;; (defun define-simple-evaluatable-function-test-int (function id expression result kb mt owner) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list51 = (FUNCTION START-ID &KEY (MT #$InferencePSC) (KB :FULL) TESTS OWNER (WORKING? T))
;; $list52 = (:MT :KB :TESTS :OWNER :WORKING?), $kw32$ALLOW-OTHER-KEYS
;; $sym56$DEFINE-SIMPLE-EVALUATABLE-FUNCTION-TEST-BLOCK-INT is a registered
;; macro-helper for this macro (see setup).
;; Expands to a call to the registered helper with the user's 7 arguments.
(defmacro define-simple-evaluatable-function-test-block (function start-id
                                                         &key (mt #$InferencePSC) (kb :full)
                                                              tests owner (working? t))
  `(define-simple-evaluatable-function-test-block-int ',function ,start-id
                                                      ,mt ,kb ',tests ,owner ,working?))

;; (defun define-simple-evaluatable-function-test-block-int (function start-id mt kb tests owner working?) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list72 = (PREDICATE ID SENTENCE &KEY (RESULT :DONT-CARE) MT (KB :FULL) OWNER)
;; $list73 = (:RESULT :MT :KB :OWNER), $kw32$ALLOW-OTHER-KEYS
;; $sym74$DEFINE-SIMPLE-EVALUATABLE-PREDICATE-TEST-INT is a registered
;; macro-helper for this macro (see setup).
;; Expands to a call to the registered helper with the user's 7 arguments.
(defmacro define-simple-evaluatable-predicate-test (predicate id sentence
                                                    &key (result :dont-care) mt (kb :full) owner)
  `(define-simple-evaluatable-predicate-test-int ',predicate ,id ',sentence
                                                 ,result ,mt ,kb ,owner))

;; Reconstructed from Internal Constants:
;; $list76 = (PREDICATE START-ID &KEY (MT #$InferencePSC) (KB :FULL) OWNER TESTS)
;; $list77 = (:MT :KB :OWNER :TESTS), $kw32$ALLOW-OTHER-KEYS
;; $sym78$DEFINE-SIMPLE-EVALUATABLE-PREDICATE-TEST-BLOCK-INT is a registered
;; macro-helper for this macro (see setup). Arity 6.
;; Expands to a call to the registered helper with the user's 6 arguments.
(defmacro define-simple-evaluatable-predicate-test-block (predicate start-id
                                                          &key (mt #$InferencePSC) (kb :full)
                                                               owner tests)
  `(define-simple-evaluatable-predicate-test-block-int ',predicate ,start-id
                                                       ,mt ,kb ,owner ',tests))

;; (defun define-simple-evaluatable-predicate-test-int (predicate id sentence result mt kb owner) ...) -- active declareFunction, no body
;; (defun define-simple-evaluatable-predicate-test-block-int (predicate start-id mt kb owner tests) ...) -- active declareFunction, no body

;; (defun run-all-evaluatable-relation-tests (&optional verbosity halt-on-failure? format output-stream) ...) -- active declareFunction, no body
;; (defun run-evaluatable-relation-tests (relation &optional verbosity halt-on-failure? format) ...) -- active declareFunction, no body
;; (defun run-evaluatable-relation-test-number (relation id &optional verbosity halt-on-failure? format) ...) -- active declareFunction, no body
;; (defun run-evaluatable-relation-test-number-browsable (relation id &optional verbosity halt-on-failure?) ...) -- active declareFunction, no body
;; (defun run-evaluatable-relation-test (ert &optional verbosity halt-on-failure? format) ...) -- active declareFunction, no body
;; (defun run-evaluatable-relation-test? (ert) ...) -- active declareFunction, no body
;; (defun run-evaluatable-relation-test-query (ert browsable?) ...) -- active declareFunction, no body
;; (defun evaluatable-relation-test-query-inference (ert &optional browsable?) ...) -- active declareFunction, no body
;; (defun print-evaluatable-relation-test-preamble (ert format stream) ...) -- active declareFunction, no body
;; (defun print-evaluatable-relation-test-result (ert result format stream) ...) -- active declareFunction, no body

(toplevel
  (declare-defglobal '*evaluatable-relation-tests*)
  (declare-indention-pattern 'define-evaluatable-function-test
                             '(function id &body body))
  (declare-indention-pattern 'define-evaluatable-predicate-test
                             '(predicate id &body body))
  (declare-indention-pattern 'define-simple-evaluatable-function-test
                             '(function id &body body))
  (declare-indention-pattern 'define-simple-evaluatable-function-test-block
                             '(function start-id &body body))
  (register-macro-helper 'define-simple-evaluatable-function-test-int
                         'define-simple-evaluatable-function-test)
  (register-macro-helper 'define-simple-evaluatable-function-test-block-int
                         'define-simple-evaluatable-function-test-block)
  (declare-indention-pattern 'define-simple-evaluatable-predicate-test
                             '(predicate id &body body))
  (declare-indention-pattern 'define-simple-evaluatable-predicate-test-block
                             '(predicate start-id &body body))
  (register-macro-helper 'define-simple-evaluatable-predicate-test-int
                         'define-simple-evaluatable-predicate-test)
  (register-macro-helper 'define-simple-evaluatable-predicate-test-block-int
                         'define-simple-evaluatable-predicate-test-block))
