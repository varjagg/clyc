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

;; Struct definition — generates accessors (RMT-*), predicate (REMOVAL-MODULE-TEST-P),
;; constructor (MAKE-REMOVAL-MODULE-TEST), and setf accessors (_CSETF-RMT-*).
;; Covers: removal-module-test-p, rmt-*, _csetf-rmt-*, make-removal-module-test

(defstruct (removal-module-test (:conc-name "RMT-"))
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

(defconstant *dtp-removal-module-test* 'removal-module-test)

;; Declare phase (following declare_removal_module_tests_file order)

;; removal-module-test-p — provided by defstruct
;; rmt-hl-module, rmt-id, rmt-sentence, rmt-mt, rmt-properties, rmt-comment,
;; rmt-kb, rmt-owner, rmt-bug-number, rmt-creation-date, rmt-creator, rmt-working?
;;   — all provided by defstruct
;; _csetf-rmt-* — all provided by defstruct (setf rmt-*)
;; make-removal-module-test — provided by defstruct

;; (defun removal-modules-with-removal-module-tests () ...) -- active declareFunction, no body
;; (defun removal-module-tests (removal-module) ...) -- active declareFunction, no body
;; (defun some-removal-module-tests? (removal-module) ...) -- active declareFunction, no body
;; (defun removal-module-test-name (test) ...) -- active declareFunction, no body
;; (defun removal-module-test-mt (test) ...) -- active declareFunction, no body
;; (defun removal-module-test-sentence (test) ...) -- active declareFunction, no body
;; (defun removal-module-test-owner (test) ...) -- active declareFunction, no body
;; (defun removal-module-test-comment (test) ...) -- active declareFunction, no body
;; (defun removal-module-test-kb (test) ...) -- active declareFunction, no body
;; (defun removal-module-test-working? (test) ...) -- active declareFunction, no body
;; (defun removal-module-test-predicate (test) ...) -- active declareFunction, no body
;; (defun removal-module-test-mentions-invalid-constant? (test) ...) -- active declareFunction, no body

;; define-removal-module-test — active declareMacro, registered via register-cyc-api-macro
;; Reconstructed from Internal Constants evidence:
;; $list51 = (NAME ID SENTENCE &KEY (MT #$EverythingPSC) PROPERTIES (KB :TINY)
;;                                  OWNER COMMENT BUG CREATED CREATOR (WORKING? T))
;;   — the macro arglist (register-cyc-api-macro pattern argument)
;; $list52 = (:MT :PROPERTIES :KB :OWNER :COMMENT :BUG :CREATED :CREATOR :WORKING?)
;;   — the keyword list
;; $kw53$ALLOW_OTHER_KEYS → &allow-other-keys permitted in keyword-args
;; $sym58$DEFINE_REMOVAL_MODULE_TEST_INT — registered macro-helper target (arity 12,0)
;; $str60 — verbatim docstring (below)
;; The 12 positional args to the helper correspond exactly to the 12 struct slots
;; (name/id/sentence/mt/properties/kb/owner/comment/bug/created/creator/working?).
(defmacro define-removal-module-test (name id sentence
                                      &key (mt #$EverythingPSC) properties (kb :tiny)
                                        owner comment bug created creator (working? t)
                                      &allow-other-keys)
  "[Cyc] Define a removal module test number ID for the module named NAME.
   The test queries SENTENCE in MT and verifies that a removal module named NAME was used in some goal path.
  PROPERTIES, if not nil, specifies additional query properties to pass in."
  `(define-removal-module-test-int ',name ,id ',sentence ,mt ,properties ,kb ,owner ,comment ,bug ,created ,creator ,working?))

;; (defun define-removal-module-test-int (name id sentence mt properties kb owner comment bug created creator working?) ...) -- active declareFunction, no body
;; (defun undefine-removal-module-test-number (name id) ...) -- active declareFunction, no body
;; (defun clear-removal-module-tests () ...) -- active declareFunction, no body
;; (defun run-all-removal-module-tests (&optional output-format browsable? cache-inference-results? block?) ...) -- active declareFunction, no body
;; (defun run-removal-module-tests-for-pred (pred &optional output-format browsable? cache-inference-results? block?) ...) -- active declareFunction, no body
;; (defun run-removal-module-tests-browsable (removal-module &optional output-format cache-inference-results?) ...) -- active declareFunction, no body
;; (defun run-removal-module-tests-blocking (removal-module &optional output-format cache-inference-results?) ...) -- active declareFunction, no body
;; (defun run-removal-module-tests (removal-module &optional output-format browsable? cache-inference-results? block?) ...) -- active declareFunction, no body
;; (defun run-removal-module-tests-int (removal-module output-format browsable? cache-inference-results? block?) ...) -- active declareFunction, no body
;; (defun run-removal-module-test-number-browsable (name id &optional output-format cache-inference-results?) ...) -- active declareFunction, no body
;; (defun run-removal-module-test-number-blocking (name id &optional output-format cache-inference-results?) ...) -- active declareFunction, no body
;; (defun run-removal-module-test-number (name id &optional output-format browsable? cache-inference-results? block?) ...) -- active declareFunction, no body
;; (defun run-removal-module-test (test &optional output-format browsable? cache-inference-results? block?) ...) -- active declareFunction, no body
;; (defun run-removal-module-test? (test) ...) -- active declareFunction, no body
;; (defun run-removal-module-test-query (test output-format &optional browsable? cache-inference-results? block? conditional-sentence? abort-if-invalid? verbose?) ...) -- active declareFunction, no body
;; (defun run-removal-module-test-query-int (test output-format browsable? cache-inference-results? block? conditional-sentence? abort-if-invalid? verbose?) ...) -- active declareFunction, no body
;; (defun removal-module-test-query-inference (test &optional browsable? cache-inference-results? conditional-sentence?) ...) -- active declareFunction, no body
;; (defun print-removal-module-test-preamble (test output-format stream) ...) -- active declareFunction, no body
;; (defun print-removal-module-test-result (test result output-format stream) ...) -- active declareFunction, no body

;; Init phase

(defglobal *removal-module-tests*
    (if (and (boundp '*removal-module-tests*)
             (hash-table-p *removal-module-tests*))
        *removal-module-tests*
        (make-hash-table :size 100)))

;; Setup phase
;; Struct print registration for removal-module-test: handled by defstruct
;; def-csetf registrations: elided (CL setf handles this)
;; Equality.identity for struct symbol: elided (CL struct definition is sufficient)

(toplevel
  (declare-defglobal '*removal-module-tests*)
  (register-cyc-api-macro 'define-removal-module-test
                          '(name id sentence &key (mt #$EverythingPSC) properties (kb :tiny)
                            owner comment bug created creator (working? t))
                          "Define a removal module test number ID for the module named NAME.
   The test queries SENTENCE in MT and verifies that a removal module named NAME was used in some goal path.
  PROPERTIES, if not nil, specifies additional query properties to pass in.")
  (register-external-symbol 'define-removal-module-test-int)
  (register-macro-helper 'define-removal-module-test-int 'define-removal-module-test)
  (register-external-symbol 'run-removal-module-tests-for-pred))
