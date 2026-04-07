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

;; Struct definition — generates accessors (RMCT-*), predicate (REMOVAL-MODULE-COST-TEST-P),
;; constructor (MAKE-REMOVAL-MODULE-COST-TEST), and setf accessors (_CSETF-RMCT-*).
;; Covers: removal-module-cost-test-p, rmct-*, _csetf-rmct-*, make-removal-module-cost-test

(defstruct (removal-module-cost-test (:conc-name "RMCT-"))
  hl-module
  id
  sentence
  mt
  comment
  kb
  owner
  bug-number
  creation-date
  creator
  working?)

(defconstant *dtp-removal-module-cost-test* 'removal-module-cost-test)

(defmethod print-object ((object removal-module-cost-test) stream)
  (removal-module-cost-test-print-function-trampoline object stream))

;; Declare phase (following declare_removal_module_cost_tests_file order)

;; Active declareFunction with body — delegates to the default struct print function.
(defun removal-module-cost-test-print-function-trampoline (object stream)
  (default-struct-print-function object stream 0)
  nil)

;; removal-module-cost-test-p — provided by defstruct
;; (Java's $removal_module_cost_test_p$UnaryFunction was a handleMissingMethodError
;;  dispatch stub, number 32511; replaced by the CL struct predicate.)
;; rmct-hl-module, rmct-id, rmct-sentence, rmct-mt, rmct-comment,
;; rmct-kb, rmct-owner, rmct-bug-number, rmct-creation-date, rmct-creator, rmct-working?
;;   — all provided by defstruct
;; _csetf-rmct-* — all provided by defstruct (setf rmct-*)
;; make-removal-module-cost-test — provided by defstruct

;; (defun removal-modules-with-removal-module-cost-tests () ...) -- active declareFunction, no body
;; (defun removal-module-cost-tests (hl-module) ...) -- active declareFunction, no body
;; (defun some-removal-module-cost-tests? (hl-module) ...) -- active declareFunction, no body
;; (defun removal-module-cost-test-name (test) ...) -- active declareFunction, no body
;; (defun removal-module-cost-test-mt (test) ...) -- active declareFunction, no body
;; (defun removal-module-cost-test-sentence (test) ...) -- active declareFunction, no body
;; (defun removal-module-cost-test-owner (test) ...) -- active declareFunction, no body
;; (defun removal-module-cost-test-comment (test) ...) -- active declareFunction, no body
;; (defun removal-module-cost-test-kb (test) ...) -- active declareFunction, no body
;; (defun removal-module-cost-test-working? (test) ...) -- active declareFunction, no body
;; (defun removal-module-cost-test-predicate (test) ...) -- active declareFunction, no body
;; (defun removal-module-cost-test-mentions-invalid-constant? (test) ...) -- active declareFunction, no body

;; define-removal-module-cost-test — active declareMacro, registered as macro-helper only
;; (no register-cyc-api-macro call in Java setup, unlike sister file removal-module-tests).
;; Reconstructed from Internal Constants evidence:
;; $list49 = (NAME ID SENTENCE &KEY (MT #$EverythingPSC) (KB :TINY)
;;                                  OWNER COMMENT BUG CREATED CREATOR (WORKING? T))
;;   — the macro arglist
;; $list50 = (:MT :KB :OWNER :COMMENT :BUG :CREATED :CREATOR :WORKING?)
;;   — the keyword list
;; $kw51$ALLOW_OTHER_KEYS → &allow-other-keys permitted in keyword-args
;; $sym56$DEFINE_REMOVAL_MODULE_COST_TEST_INT — registered macro-helper target (arity 11,0)
;; No docstring constant (unlike sister file which has $str60).
;; The 11 positional args to the helper correspond exactly to the 11 struct slots
;; (name/id/sentence/mt/kb/owner/comment/bug/created/creator/working?).
(defmacro define-removal-module-cost-test (name id sentence
                                           &key (mt #$EverythingPSC) (kb :tiny)
                                             owner comment bug created creator (working? t)
                                           &allow-other-keys)
  `(define-removal-module-cost-test-int ',name ,id ',sentence ,mt ,kb ,owner ,comment ,bug ,created ,creator ,working?))

;; (defun define-removal-module-cost-test-int (name id sentence mt kb owner comment bug created creator working?) ...) -- active declareFunction, no body
;; (defun clear-removal-module-cost-tests () ...) -- active declareFunction, no body
;; (defun run-all-removal-module-cost-tests (&optional output-stream output-format since options) ...) -- active declareFunction, no body
;; (defun run-removal-module-cost-tests-for-pred (pred &optional output-stream output-format) ...) -- active declareFunction, no body
;; (defun run-removal-module-cost-tests-blocking (hl-module &optional output-stream output-format) ...) -- active declareFunction, no body
;; (defun run-removal-module-cost-tests (hl-module &optional output-stream output-format) ...) -- active declareFunction, no body
;; (defun run-removal-module-cost-tests-int (hl-module output-stream output-format) ...) -- active declareFunction, no body
;; (defun run-removal-module-cost-test-number-blocking (hl-module number &optional output-stream output-format) ...) -- active declareFunction, no body
;; (defun run-removal-module-cost-test-number (hl-module number &optional output-stream output-format) ...) -- active declareFunction, no body
;; (defun run-removal-module-cost-test (test &optional output-stream output-format) ...) -- active declareFunction, no body
;; (defun run-removal-module-cost-test? (test) ...) -- active declareFunction, no body
;; (defun run-removal-module-cost-test-comparison (test output-stream output-format) ...) -- active declareFunction, no body
;; (defun generic-cost-test-comparison (test output-stream) ...) -- active declareFunction, no body
;; (defun print-removal-module-cost-test-preamble (test output-stream output-format) ...) -- active declareFunction, no body
;; (defun print-removal-module-cost-test-result (test result output-stream output-format) ...) -- active declareFunction, no body

;; Init phase

(defglobal *removal-module-cost-tests*
    (if (and (boundp '*removal-module-cost-tests*)
             (hash-table-p *removal-module-cost-tests*))
        *removal-module-cost-tests*
        (make-hash-table :size 100)))

;; Setup phase
;; Struct print registration for removal-module-cost-test: handled by defmethod print-object
;; def-csetf registrations: elided (CL setf handles this)
;; Equality.identity for struct symbol: elided (CL struct definition is sufficient)

(toplevel
  (declare-defglobal '*removal-module-cost-tests*)
  (register-macro-helper 'define-removal-module-cost-test-int 'define-removal-module-cost-test))
