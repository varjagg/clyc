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


;;; transformation-module-test defstruct
;;; Slots: hl-module, id, sentence, mt, properties, comment, kb, owner, bug-number, creation-date, creator, working?
;;; conc-name: tmt-
(defstruct (transformation-module-test
            (:conc-name "TMT-"))
  hl-module
  id
  sentence
  mt
  properties
  comment
  kb
  owner
  bug-number
  creation-date
  creator
  working?)

(defconstant *dtp-transformation-module-test* 'transformation-module-test)

(defmethod print-object ((object transformation-module-test) stream)
  (transformation-module-test-print-function-trampoline object stream))

(defun transformation-module-test-print-function-trampoline (object stream)
  ;; [Cyc] body preserved in Java — delegates to the default struct print function.
  (default-struct-print-function object stream 0)
  nil)

;; (defun transformation-module-test-p (object) ...) -- active declareFunction, no body. UnaryFunction: missing-larkc 32553
;; (defun tmt-hl-module (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-id (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-sentence (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-mt (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-properties (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-comment (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-kb (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-owner (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-bug-number (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-creation-date (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-creator (tmt) ...) -- active declareFunction, no body (struct accessor)
;; (defun tmt-working? (tmt) ...) -- active declareFunction, no body (struct accessor)
;; _csetf-tmt-hl-module, _csetf-tmt-id, _csetf-tmt-sentence, _csetf-tmt-mt, _csetf-tmt-properties, _csetf-tmt-comment, _csetf-tmt-kb, _csetf-tmt-owner, _csetf-tmt-bug-number, _csetf-tmt-creation-date, _csetf-tmt-creator, _csetf-tmt-working? are struct setf expansions, elided.
;; (defun make-transformation-module-test (&optional initializer) ...) -- active declareFunction, no body (struct constructor)

(defglobal *transformation-module-tests*
  (if (boundp '*transformation-module-tests*)
      *transformation-module-tests*
      (make-hash-table :size 100))
  "[Cyc]")

;; (defun transformation-modules-with-transformation-module-tests () ...) -- active declareFunction, no body
;; (defun transformation-module-tests (hl-module) ...) -- active declareFunction, no body
;; (defun some-transformation-module-tests? (hl-module) ...) -- active declareFunction, no body
;; (defun transformation-module-test-name (tmt) ...) -- active declareFunction, no body
;; (defun transformation-module-test-mt (tmt) ...) -- active declareFunction, no body
;; (defun transformation-module-test-sentence (tmt) ...) -- active declareFunction, no body
;; (defun transformation-module-test-owner (tmt) ...) -- active declareFunction, no body
;; (defun transformation-module-test-comment (tmt) ...) -- active declareFunction, no body
;; (defun transformation-module-test-kb (tmt) ...) -- active declareFunction, no body
;; (defun transformation-module-test-working? (tmt) ...) -- active declareFunction, no body
;; (defun transformation-module-test-mentions-invalid-constant? (tmt) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list51 = (NAME ID SENTENCE &KEY (MT #$EverythingPSC) PROPERTIES (KB :TINY) OWNER COMMENT BUG CREATED CREATOR (WORKING? T))
;; $list52 = (:MT :PROPERTIES :KB :OWNER :COMMENT :BUG :CREATED :CREATOR :WORKING?)
;; $kw53$ALLOW-OTHER-KEYS
;; $sym58$DEFINE-TRANSFORMATION-MODULE-TEST-INT is a registered macro-helper
;; for this macro (see setup). Arity 12.
;; Expands to a call to the registered helper with the user's 12 arguments.
(defmacro define-transformation-module-test (name id sentence
                                             &key (mt #$EverythingPSC) properties (kb :tiny)
                                                  owner comment bug created creator (working? t))
  `(define-transformation-module-test-int ',name ,id ',sentence
                                          ,mt ,properties ,kb ,owner ,comment
                                          ,bug ,created ,creator ,working?))

;; (defun define-transformation-module-test-int (name id sentence mt properties kb owner comment bug-number creation-date creator working?) ...) -- active declareFunction, no body. Registered macro-helper for define-transformation-module-test.

;; (defun clear-transformation-module-tests () ...) -- active declareFunction, no body
;; (defun run-all-transformation-module-tests (&optional verbosity halt-on-failure? format output-stream) ...) -- active declareFunction, no body
;; (defun run-transformation-module-tests-browsable (hl-module &optional verbosity halt-on-failure?) ...) -- active declareFunction, no body
;; (defun run-transformation-module-tests-blocking? (hl-module &optional verbosity halt-on-failure?) ...) -- active declareFunction, no body
;; (defun run-transformation-module-tests (hl-module &optional verbosity halt-on-failure? format block?) ...) -- active declareFunction, no body
;; (defun run-transformation-module-tests-int (hl-module verbosity halt-on-failure? format block?) ...) -- active declareFunction, no body
;; (defun run-transformation-module-test-number-browsable (hl-module id &optional verbosity halt-on-failure?) ...) -- active declareFunction, no body
;; (defun run-transformation-module-test-number-blocking (hl-module id &optional verbosity halt-on-failure?) ...) -- active declareFunction, no body
;; (defun run-transformation-module-test-number (hl-module id &optional verbosity halt-on-failure? format block?) ...) -- active declareFunction, no body
;; (defun run-transformation-module-test (tmt &optional verbosity halt-on-failure? format block?) ...) -- active declareFunction, no body
;; (defun run-transformation-module-test? (tmt) ...) -- active declareFunction, no body
;; (defun run-transformation-module-test-query (tmt verbosity halt-on-failure? format browsable? block?) ...) -- active declareFunction, no body
;; (defun transformation-module-test-query-inference (tmt &optional browsable? block? verbosity) ...) -- active declareFunction, no body
;; (defun print-transformation-test-preamble (tmt format stream) ...) -- active declareFunction, no body
;; (defun print-transformation-module-test-result (tmt result format stream) ...) -- active declareFunction, no body

(toplevel
  (declare-defglobal '*transformation-module-tests*)
  (register-macro-helper 'define-transformation-module-test-int
                         'define-transformation-module-test))
