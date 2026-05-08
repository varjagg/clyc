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

(deflexical *cycl-functions-used-as-evaluation-defns* '(asserted-when))

(deflexical *max-supported-formula-arity* 1000
  "[Cyc] Formulas longer than this cause more trouble than they're worth.
See, e.g. bug 18429.
@todo - Move to more general file if other cases are discovered.")

(defparameter *bug-18769-switch?* nil
  "[Cyc] Determines whether #$MakeFormulaFn, #$SubstituteFormulaArgFn and #$SubstituteFormulaFn take and return explicitly quoted formula")

(deflexical *word-strings-fn* nil)

(deflexical *word-sequence-fn* nil)

(defparameter *cyc-ordering-relation* nil)

(deflexical *term-to-isg-table-lock* (bt:make-lock "term -> isg table lock"))

(defglobal *term-to-isg-table* (make-hash-table :test #'equal))

(deflexical *term-to-isg-w/start-table-lock* (bt:make-lock "term -> isg w/ start table lock"))

(defglobal *term-to-isg-w/start-table* (make-hash-table :test #'equal))

;;; Functions (declare section ordering)

;; (defun evaluatable-predicate-count () ...) -- no body, commented declareFunction
;; (defun cyc-true-subl (arg) ...) -- no body, commented declareFunction

(defun cyc-different (args)
  "[Cyc] #$evaluationDefn for #$different"
  (let ((result (different? args :unknown)))
    (if (eq result :unknown)
        ;; missing-larkc 30339 likely called a deeper evaluation or inference
        ;; to determine difference when equals/different? returns :unknown,
        ;; since the predicate evaluator needs a definite T/NIL answer.
        (missing-larkc 30339)
        result)))

;; (defun cyc-different-symbols (arg) ...) -- no body, commented declareFunction
;; (defun cyc-substring-predicate (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-substring-case-insensitive-predicate (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-substring-predicate-internal (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-prefix-substring (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-suffix-substring (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-subword-predicate (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-find-constant (arg) ...) -- no body, commented declareFunction
;; (defun evaluatable-function-count () ...) -- no body, commented declareFunction
;; (defun cyc-evaluate-subl (arg) ...) -- no body, commented declareFunction
;; (defun cyc-string-upcase (arg) ...) -- no body, commented declareFunction
;; (defun string-upcase-defn (arg) ...) -- no body, commented declareFunction
;; (defun cyc-string-downcase (arg) ...) -- no body, commented declareFunction
;; (defun cyc-substring (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-string-concat (arg) ...) -- no body, commented declareFunction
;; (defun cyc-strings-to-phrase (arg) ...) -- no body, commented declareFunction
;; (defun cyc-pre-remove (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-replace-substring (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun unicode-naut-or-ascii-string-p (arg) ...) -- no body, commented declareFunction
;; (defun unicode-naut-or-string-to-unicode-vector (arg) ...) -- no body, commented declareFunction
;; (defun cyc-remove-substring (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-post-remove (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-trim-whitespace (arg) ...) -- no body, commented declareFunction
;; (defun cyc-string-search (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-length (arg) ...) -- no body, commented declareFunction
;; (defun cyc-string-to-integer (arg) ...) -- no body, commented declareFunction
;; (defun cyc-integer-to-string (arg) ...) -- no body, commented declareFunction
;; (defun cyc-string-to-real-number (arg) ...) -- no body, commented declareFunction
;; (defun cyc-real-number-to-string (arg) ...) -- no body, commented declareFunction
;; (defun max-supported-formula-arity () ...) -- no body, commented declareFunction
;; (defun cyc-string-tokenize (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-http-url-encode (arg) ...) -- no body, commented declareFunction
;; (defun cyc-html-image (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun html-image-plist (arg) ...) -- no body, commented declareFunction
;; (defun cyc-html-table-data (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-html-table-data-variable-arity (arg) ...) -- no body, commented declareFunction
;; (defun html-table-data-plist (arg) ...) -- no body, commented declareFunction
;; (defun cyc-html-table-row (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-html-table-row-variable-arity (arg) ...) -- no body, commented declareFunction
;; (defun html-table-row-plist (arg) ...) -- no body, commented declareFunction
;; (defun cyc-html-table (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-html-table-variable-arity (arg) ...) -- no body, commented declareFunction
;; (defun html-table-plist (arg) ...) -- no body, commented declareFunction
;; (defun cyc-html-division (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-html-division-variable-arity (arg) ...) -- no body, commented declareFunction
;; (defun html-division-plist (arg) ...) -- no body, commented declareFunction
;; (defun decode-html-option (arg) ...) -- no body, commented declareFunction
;; (defun parse-html-attribute (arg) ...) -- no body, commented declareFunction
;; (defun parse-html-attribute-value (arg) ...) -- no body, commented declareFunction
;; (defun cyc-contextual-url (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun url-string (arg) ...) -- no body, commented declareFunction
;; (defun cyc-remove-html-tags (arg) ...) -- no body, commented declareFunction
;; (defun cyc-capitalize-smart (arg) ...) -- no body, commented declareFunction
;; (defun cyc-recapitalize-smart (arg) ...) -- no body, commented declareFunction
;; (defun cyc-relation-arg (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-relation-args-list (arg) ...) -- no body, commented declareFunction
;; (defun cyc-relation-arg-set (arg) ...) -- no body, commented declareFunction
;; (defun cyc-relation-expression-arity (arg) ...) -- no body, commented declareFunction
;; (defun cyc-identity (arg) ...) -- no body, commented declareFunction
;; (defun cyc-relation-tuples (arg) ...) -- no body, commented declareFunction
;; (defun cyc-relation-tuples-internal (arg &optional arg2) ...) -- no body, commented declareFunction
;; (defun convert-relation-to-kappa (arg) ...) -- no body, commented declareFunction
;; (defun cyc-substitute-formula (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-bilateral-form-of-sentence-left (arg) ...) -- no body, commented declareFunction
;; (defun symmetric-part-type? (arg) ...) -- no body, commented declareFunction
;; (defun left-form-of-symmetric-part-type (arg) ...) -- no body, commented declareFunction
;; (defun cyc-bilateral-form-of-sentence-right (arg) ...) -- no body, commented declareFunction
;; (defun symmetry-neutralized-el-sentence-p (arg) ...) -- no body, commented declareFunction
;; (defun right-form-of-symmetric-part-type (arg) ...) -- no body, commented declareFunction
;; (defun neutralize-symmetric-formula (arg) ...) -- no body, commented declareFunction
;; (defun side-fn-naut-p (arg) ...) -- no body, commented declareFunction
;; (defun cyc-substitute-formula-arg (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-substitute-formula-arg-position (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-make-formula (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-substitute-quoted-formula-arg (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-substitute-quoted-formula-arg-position (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-make-quoted-formula (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cycl-to-el-fn (arg) ...) -- no body, commented declareFunction
;; (defun cyc-substitute-nlte (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun sem-trans-template-defn (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-word-strings (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun word-strings-fn () ...) -- no body, commented declareFunction
;; (defun word-sequence-fn () ...) -- no body, commented declareFunction
;; (defun cyc-strings-of-word-sequence (arg) ...) -- no body, commented declareFunction
;; (defun cyc-instantiate (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-find-or-instantiate (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-instantiate-set-formula (arg) ...) -- no body, commented declareFunction
;; (defun cyc-instantiate-formula (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun cyc-individual-denoting-unary-function-for (arg) ...) -- no body, commented declareFunction
;; (defun cyc-collection-denoting-unary-function-for (arg) ...) -- no body, commented declareFunction
;; (defun unary-functions-for (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun unary-function? (arg) ...) -- no body, commented declareFunction
;; (defun individual-denoting-fn? (arg) ...) -- no body, commented declareFunction
;; (defun cyc-el-variable-fn (arg) ...) -- no body, commented declareFunction
;; (defun cyc-add-english-suffix (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun state-or-province-for-city-defn (arg) ...) -- no body, commented declareFunction
;; (defun cyc-html-url-encode (arg) ...) -- no body, commented declareFunction
;; (defun cyc-url-source (arg) ...) -- no body, commented declareFunction
;; (defun cyc-get-from-http-source (arg) ...) -- no body, commented declareFunction
;; (defun encode-list-for-simple-http-server (arg) ...) -- no body, commented declareFunction
;; (defun cyc-term-uri-fn (arg) ...) -- no body, commented declareFunction
;; (defun city-named-fn-defn (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun city-in-region? (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun text-topic-structure (arg) ...) -- no body, commented declareFunction
;; (defun el-list-to-subl-list (arg) ...) -- no body, commented declareFunction
;; (defun cyc-ordering-result (arg) ...) -- no body, commented declareFunction
;; (defun ordering-< (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-ordering-result-internal (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-seconds-since-1970-to-date (arg) ...) -- no body, commented declareFunction
;; (defun cyc-types-most-often-asserted-using-tool (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun types-most-often-asserted-using-tool (arg &optional arg2 arg3 arg4) ...) -- no body, commented declareFunction
;; (defun assertion-generating-tool-p (arg) ...) -- no body, commented declareFunction
;; (defun cyc-html-for-text-containing-strings (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-html-for-text-containing-strings-count-bold-tags (arg) ...) -- no body, commented declareFunction
;; (defun cyc-format (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-next-integer-in-sequence (arg) ...) -- no body, commented declareFunction
;; (defun cyc-next-integer-in-sequence-starting-at (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-concatenate-strings (arg) ...) -- no body, commented declareFunction
;; (defun strings-to-display-vector-strings (arg) ...) -- no body, commented declareFunction
;; (defun cyc-term-similarity-metric (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-kb-orthogonal (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun cyc-content-of-file (arg) ...) -- no body, commented declareFunction
;; (defun cyc-transform-relation-tuples (arg) ...) -- no body, commented declareFunction
;; (defun unlist (arg) ...) -- no body, commented declareFunction

;;; Setup

(toplevel
  ;; Loop over *cycl-functions-used-as-evaluation-defns* registering each
  (dolist (symbol *cycl-functions-used-as-evaluation-defns*)
    (register-kb-function symbol))
  (register-kb-function 'cyc-true-subl)
  (register-kb-function 'cyc-different)
  (register-kb-function 'cyc-different-symbols)
  (register-kb-function 'cyc-substring-predicate)
  (register-kb-function 'cyc-substring-case-insensitive-predicate)
  (register-kb-function 'cyc-prefix-substring)
  (register-kb-function 'cyc-suffix-substring)
  (register-kb-function 'cyc-subword-predicate)
  (register-kb-function 'cyc-find-constant)
  (register-kb-function 'cyc-evaluate-subl)
  (register-kb-function 'cyc-string-upcase)
  (define-obsolete-register 'string-upcase-defn '(cyc-string-upcase))
  (register-kb-function 'cyc-string-downcase)
  (register-kb-function 'cyc-substring)
  (register-kb-function 'cyc-string-concat)
  (register-kb-function 'cyc-strings-to-phrase)
  (register-kb-function 'cyc-pre-remove)
  (register-kb-function 'cyc-replace-substring)
  (register-kb-function 'cyc-remove-substring)
  (register-kb-function 'cyc-post-remove)
  (register-kb-function 'cyc-trim-whitespace)
  (register-kb-function 'cyc-string-search)
  (register-kb-function 'cyc-length)
  (register-kb-function 'cyc-string-to-integer)
  (register-kb-function 'cyc-integer-to-string)
  (register-kb-function 'cyc-string-to-real-number)
  (register-kb-function 'cyc-real-number-to-string)
  (register-kb-function 'cyc-string-tokenize)
  (register-kb-function 'cyc-http-url-encode)
  (register-kb-function 'cyc-html-image)
  (register-kb-function 'cyc-html-table-data)
  (register-kb-function 'cyc-html-table-data-variable-arity)
  (register-kb-function 'cyc-html-table-row)
  (register-kb-function 'cyc-html-table-row-variable-arity)
  (register-kb-function 'cyc-html-table)
  (register-kb-function 'cyc-html-table-variable-arity)
  (register-kb-function 'cyc-html-division)
  (register-kb-function 'cyc-html-division-variable-arity)
  (register-kb-function 'cyc-contextual-url)
  (register-kb-function 'cyc-remove-html-tags)
  (register-kb-function 'cyc-capitalize-smart)
  (register-kb-function 'cyc-recapitalize-smart)
  (register-kb-function 'cyc-relation-arg)
  (register-kb-function 'cyc-relation-args-list)
  (register-kb-function 'cyc-relation-arg-set)
  (register-kb-function 'cyc-relation-expression-arity)
  (register-kb-function 'cyc-identity)
  (register-kb-function 'cyc-relation-tuples)
  (register-kb-function 'cyc-substitute-formula)
  (register-kb-function 'cyc-bilateral-form-of-sentence-left)
  (register-kb-function 'cyc-bilateral-form-of-sentence-right)
  (register-kb-function 'cyc-substitute-formula-arg)
  (register-kb-function 'cyc-substitute-formula-arg-position)
  (register-kb-function 'cyc-make-formula)
  (register-kb-function 'cyc-substitute-quoted-formula-arg)
  (register-kb-function 'cyc-substitute-quoted-formula-arg-position)
  (register-kb-function 'cyc-make-quoted-formula)
  (register-kb-function 'cycl-to-el-fn)
  (register-kb-function 'cyc-substitute-nlte)
  (register-kb-function 'sem-trans-template-defn)
  (register-kb-function 'cyc-word-strings)
  (register-kb-function 'cyc-strings-of-word-sequence)
  (register-kb-function 'cyc-instantiate)
  (register-kb-function 'cyc-find-or-instantiate)
  (register-kb-function 'cyc-individual-denoting-unary-function-for)
  (register-kb-function 'cyc-collection-denoting-unary-function-for)
  (register-kb-function 'cyc-el-variable-fn)
  (register-kb-function 'cyc-add-english-suffix)
  (register-kb-function 'state-or-province-for-city-defn)
  (register-kb-function 'cyc-html-url-encode)
  (register-kb-function 'cyc-url-source)
  (register-kb-function 'cyc-get-from-http-source)
  (register-kb-function 'cyc-term-uri-fn)
  (register-kb-function 'city-named-fn-defn)
  (register-kb-function 'text-topic-structure)
  (register-kb-function 'el-list-to-subl-list)
  (register-kb-function 'cyc-ordering-result)
  (register-kb-function 'cyc-seconds-since-1970-to-date)
  (register-kb-function 'cyc-types-most-often-asserted-using-tool)
  (register-kb-function 'cyc-html-for-text-containing-strings)
  (register-kb-function 'cyc-format)
  (declare-defglobal '*term-to-isg-table*)
  (register-kb-function 'cyc-next-integer-in-sequence)
  (declare-defglobal '*term-to-isg-w/start-table*)
  (register-kb-function 'cyc-next-integer-in-sequence-starting-at)
  (register-kb-function 'cyc-concatenate-strings)
  ;; [Clyc] Java setup calls (define_test_case_table_int CYC-CONCATENATE-STRINGS
  ;; (:test nil :owner nil :classes nil :kb :full :working? t) <5 input/expected tuples>)
  ;; but new-generic-test-case-table's check-types invoke the missing-larkc stubs
  ;; test-case-name-p and cyc-test-kb-p, so the call cannot run at load time.
  ;; Restore once those predicates have bodies.
  (register-kb-function 'cyc-term-similarity-metric)
  (register-kb-function 'cyc-kb-orthogonal)
  (register-kb-function 'cyc-content-of-file)
  (register-kb-function 'cyc-transform-relation-tuples))
