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

;; All functions in this file except the print trampoline are missing-larkc —
;; the Java has active declareFunction entries with no bodies, so they are
;; ported as one-line comment stubs. The two declareMacro entries
;; (DO-INFERENCE-UNIT-TESTS and DEFINE-INFERENCE-UNIT-TEST) are reconstructed
;; from Internal Constants evidence below.

;;; inference-unit-test defstruct
;;; 15 slots, conc-name "IUT-"
(defstruct (inference-unit-test (:conc-name "IUT-"))
  name
  comment
  sentence
  properties
  result
  halt-reason
  result-test
  followups
  bindings
  kb
  owner
  bug-number
  creation-date
  creator
  working?)

(defparameter *within-inference-unit-test?* nil)

(defparameter *inference-unit-test-assertions-created* :uninitialized
  "[Cyc] Accumulates a list of assertions created by side effect during the execution
of an inference unit test, so they can be optionally cleaned up later.")

(defconstant *dtp-inference-unit-test* 'inference-unit-test)

(defconstant *cfasl-wide-opcode-inference-unit-test* 513)

(defglobal *inference-unit-test-names-in-order*
  (if (boundp '*inference-unit-test-names-in-order*)
      *inference-unit-test-names-in-order*
      nil))

(defglobal *inference-unit-tests-by-name*
  (if (boundp '*inference-unit-tests-by-name*)
      *inference-unit-tests-by-name*
      (make-hash-table :size 212 :test #'eq)))

;;; Declare-phase function ports (all missing-larkc)

;; (defun within-inference-unit-test? () ...) -- active declareFunction, no body
;; (defun note-assertion-for-inference-unit-test (assertion) ...) -- active declareFunction, no body
;; (defun inference-unit-test-cleanup () ...) -- active declareFunction, no body

(defun inference-unit-test-p (object)
  ;; UnaryFunction wrapper's handleMissingMethodError was number 32335.
  ;; Clyc uses the defstruct-generated predicate instead.
  (typep object 'inference-unit-test))

;; iut-name, iut-comment, iut-sentence, iut-properties, iut-result, iut-halt-reason,
;; iut-result-test, iut-followups, iut-bindings, iut-kb, iut-owner, iut-bug-number,
;; iut-creation-date, iut-creator, iut-working? — all provided by defstruct.
;; _csetf-iut-* functions — struct setf expansions, elided.
;; make-inference-unit-test — provided by defstruct.

;; (defun inference-unit-test-name (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-comment (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-sentence (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-properties (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-expected-result (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-expected-halt-reason (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-result-test (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-followups (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-bindings (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-kb (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-owner (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-bug-number (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-creation-date (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-creator (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-working? (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-mentions-invalid-constant? (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-test-recipe (iut) ...) -- active declareFunction, no body
;; (defun inference-unit-result-test-recipe (iut) ...) -- active declareFunction, no body
;; (defun new-inference-unit-test-from-recipe (recipe) ...) -- active declareFunction, no body
;; (defun cfasl-output-object-inference-unit-test-method (object stream) ...) -- active declareFunction, no body
;; (defun cfasl-output-inference-unit-test (object stream) ...) -- active declareFunction, no body
;; (defun cfasl-output-inference-unit-test-internal (object stream) ...) -- active declareFunction, no body
;; (defun cfasl-input-inference-unit-test (stream) ...) -- active declareFunction, no body
;; (defun test-inference-unit-test-serialization (iut) ...) -- active declareFunction, no body
;; (defun find-inference-unit-test-by-name (name) ...) -- active declareFunction, no body
;; (defun store-inference-unit-test (iut) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list65 = ((TEST-VAR &KEY DONE) &BODY BODY) — macro arglist
;; $list66 = (:DONE) — allowed keyword args
;; $sym69$NAME = makeUninternedSymbol("NAME") — gensym
;; $sym70$DO-LIST, $sym71$CLET, $sym72$FIND-INFERENCE-UNIT-TEST-BY-NAME — operators
;; Iterates *inference-unit-test-names-in-order* and binds TEST-VAR to the
;; looked-up test; :DONE exits early. Evidence: the only list variable in scope
;; is *inference-unit-test-names-in-order* and the gensym NAME is passed to
;; find-inference-unit-test-by-name.
(defmacro do-inference-unit-tests ((test-var &key done) &body body)
  (with-temp-vars (name)
    `(do-list (,name *inference-unit-test-names-in-order* :done ,done)
       (clet ((,test-var (find-inference-unit-test-by-name ,name)))
         ,@body))))

;; (defun all-inference-unit-test-names () ...) -- active declareFunction, no body
;; (defun inference-unit-test-followup-p (object) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list76 = (NAME &KEY SENTENCE PROPERTIES EXPECTED-RESULT
;;            (EXPECTED-HALT-REASON :EXHAUST-TOTAL) EXPECTED-RESULT-TEST COMMENT
;;            FOLLOWUPS BINDINGS (KB :TINY) OWNER BUG CREATED CREATOR (WORKING? T))
;; $list77 = (:SENTENCE :PROPERTIES :EXPECTED-RESULT :EXPECTED-HALT-REASON
;;            :EXPECTED-RESULT-TEST :COMMENT :FOLLOWUPS :BINDINGS :KB :OWNER
;;            :BUG :CREATED :CREATOR :WORKING?) — allowed keys
;; $sym84$DEFINE-INFERENCE-UNIT-TEST-INTERNAL is registered as the macro helper
;; for this macro (see setup). Its arity is 15 — matching the 14 keyword slots
;; plus the NAME positional arg, which aligns with the defstruct's 15 fields
;; in declaration order (excluding RESULT and HALT-REASON which are assigned
;; at test-run time, and including EXPECTED-RESULT/EXPECTED-HALT-REASON which
;; drive them). Expands to a call to the registered helper.
;; The type-check predicates in orphans ($sym88$KEYWORDP..$sym104$BOOLEANP) are
;; invoked inside define-inference-unit-test-internal, not at macro-expansion
;; time.
(defmacro define-inference-unit-test (name &key sentence properties expected-result
                                           (expected-halt-reason :exhaust-total)
                                           expected-result-test comment followups
                                           bindings (kb :tiny) owner bug created
                                           creator (working? t))
  `(define-inference-unit-test-internal ',name ,sentence ,properties ,expected-result
                                        ,expected-halt-reason ,expected-result-test
                                        ,comment ,followups ,bindings ,kb ,owner
                                        ,bug ,created ,creator ,working?))

;; (defun undefine-inference-unit-test (name) ...) -- active declareFunction, no body
;; (defun undefine-all-inference-unit-tests () ...) -- active declareFunction, no body
;; (defun define-inference-unit-test-internal (name sentence properties expected-result expected-halt-reason expected-result-test comment followups bindings kb owner bug created creator working?) ...) -- active declareFunction, no body
;; (defun canonicalize-inference-unit-test-followups (followups) ...) -- active declareFunction, no body
;; (defun run-all-inference-unit-tests (&optional output-stream halt-on-failure? format verbosity continue-after-failure? allowed-test-names) ...) -- active declareFunction, no body
;; (defun run-inference-unit-tests (&optional test-names output-stream halt-on-failure? format verbosity continue-after-failure? allowed-test-names) ...) -- active declareFunction, no body
;; (defun run-inference-unit-test (name &optional output-stream halt-on-failure? format verbosity continue-after-failure? allowed-test-names) ...) -- active declareFunction, no body
;; (defun run-inference-unit-test-int (iut output-stream halt-on-failure? format verbosity continue-after-failure? allowed-test-names) ...) -- active declareFunction, no body
;; (defun run-inference-unit-test? (iut allowed-test-names) ...) -- active declareFunction, no body
;; (defun run-inference-unit-test-followup-query (iut followup output-stream halt-on-failure? format verbosity parent-sentence parent-properties parent-expected-result parent-expected-halt-reason parent-expected-result-test parent-bindings parent-hypothetical-bindings) ...) -- active declareFunction, no body
;; (defun followup-substitute-hypothetical-bindings (followup hypothetical-bindings) ...) -- active declareFunction, no body
;; (defun run-inference-unit-test-query (iut sentence properties expected-result expected-halt-reason expected-result-test bindings output-stream halt-on-failure? format verbosity browsable?) ...) -- active declareFunction, no body
;; (defun boolean-to-test-result (boolean) ...) -- active declareFunction, no body
;; (defun halt-reason-matches-spec? (halt-reason spec) ...) -- active declareFunction, no body
;; (defun iut-result-test-passes? (iut result-test actual) ...) -- active declareFunction, no body
;; (defun print-inference-unit-test-preamble (iut format verbosity stream) ...) -- active declareFunction, no body
;; (defun print-inference-unit-test-postamble (iut format verbosity result stream) ...) -- active declareFunction, no body
;; (defun print-inference-unit-test-failure (iut sentence properties expected-result expected-halt-reason expected-result-test actual-result actual-halt-reason stream) ...) -- active declareFunction, no body
;; (defun previous-query-inference () ...) -- active declareFunction, no body
;; (defun previous-query-root-problem-and-strategy () ...) -- active declareFunction, no body
;; (defun previous-query-root-problem () ...) -- active declareFunction, no body

;;; Setup phase
(toplevel
  ;; CVS-ID "Id: inference-unit-tests.lisp 128656 2009-08-31 17:37:30Z pace "
  ;; Java: Structures.register_method($print_object_method_table$, ...) —
  ;; replaced by the defmethod print-object above.
  ;; def-csetf for each IUT accessor — struct setf expansions handle this natively.
  (identity 'inference-unit-test)
  (register-wide-cfasl-opcode-input-function *cfasl-wide-opcode-inference-unit-test*
                                             'cfasl-input-inference-unit-test)
  ;; Java: Structures.register_method($cfasl_output_object_method_table$, ...) —
  ;; CL port uses defmethod on the cfasl-output-object generic function instead.
  (declare-defglobal '*inference-unit-test-names-in-order*)
  (declare-defglobal '*inference-unit-tests-by-name*)
  (declare-indention-pattern 'define-inference-unit-test
                             '(name &body body))
  (register-macro-helper 'define-inference-unit-test-internal
                         'define-inference-unit-test)
  (register-macro-helper 'canonicalize-inference-unit-test-followups
                         'define-inference-unit-test))
