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

;;; Functions follow declare_cyc_kernel_file ordering.

;; (defun cyc-create-new-permanent (name) ...) -- active declareFunction, no body

(defun cyc-create-new-ephemeral (name)
  "[Cyc] Creates a new constant with name NAME, but makes
   no effort to synchronize its external ID with
   other Cyc images.  This is intended for constants
   that will not be transmitted to other Cyc images."
  (declare (type new-constant-name-spec-p name))
  (cyc-create name (make-constant-external-id)))

(defun cyc-create (name external-id)
  "[Cyc] Create a new constant with id EXTERNAL-ID.
   If NAME is anything other than :unnamed,
   the new constant will be given the name NAME."
  (declare (type new-constant-name-spec-p name))
  (let ((result nil))
    (setf result (fi-create-int name external-id))
    (perform-constant-bookkeeping result)
    result))

;; (defun cyc-find-or-create (name external-id) ...) -- active declareFunction, no body

;; (defun cyc-find-or-create-new-permanent (name) ...) -- active declareFunction, no body

;; (defun cyc-rename (constant name) ...) -- active declareFunction, no body

;; (defun cyc-recreate (constant) ...) -- active declareFunction, no body

;; (defun new-constant-name-spec-p (object) ...) -- active declareFunction, no body

(defun cyc-kill (fort)
  "[Cyc] Kill FORT and all its uses from the KB.  If FORT is a microtheory, all assertions
   in that microtheory are removed."
  (declare (type fort-p fort))
  (fi-kill-int fort))

;; (defun cyc-rewrite (source-fort target-fort) ...) -- active declareFunction, no body

;; (defun cyc-merge (kill-fort keep-fort) ...) -- active declareFunction, no body

;; (defun assert-properties-p (object) ...) -- active declareFunction, no body

(defun get-assert-property (properties indicator &optional default)
  "[Cyc] Get a property from an assert properties plist."
  (getf properties indicator default))

(defun cyc-assert (sentence &optional mt properties)
  "[Cyc] Assert SENTENCE in the specified MT.
   properties; :strength el-strength-p (:default or :monotonic)
               :direction direction-p  (:forward or :backward)
   GAF assertion direction defaults to :forward, and rule
   assertion direction defaults to :backward.
   @return booleanp; t iff the assert succeeded.  If the assertion
   already existed, it is considered a success."
  (declare (type possibly-sentence-p sentence)
           (type assert-properties-p properties))
  (let* ((result nil)
         (strength (get-assert-property properties :strength :default))
         (direction (get-assert-property properties :direction)))
    (multiple-value-bind (right-sentence right-mt)
        (unwrap-if-ist sentence mt)
      (setf result (fi-assert-int right-sentence right-mt strength direction))
      (perform-assertion-bookkeeping result))
    result))

(defun cyc-assert-wff (sentence &optional mt properties)
  "[Cyc] Like @xref CYC-ASSERT, but SENTENCE is assumed well-formed."
  (let ((result nil))
    (let ((*assume-assert-sentence-is-wf?* t))
      (setf result (cyc-assert sentence mt properties)))
    result))

(defun cyc-unassert (sentence &optional mt)
  "[Cyc] Remove the assertions canonicalized from FORMULA in the microtheory MT.
   Return T if the operation succeeded, otherwise return NIL."
  (declare (type possibly-sentence-p sentence))
  (let ((result nil))
    (multiple-value-bind (right-sentence right-mt)
        (unwrap-if-ist sentence mt)
      (setf result (fi-unassert-int right-sentence right-mt)))
    result))

;; (defun cyc-edit (old-sentence new-sentence &optional old-mt new-mt properties) ...) -- active declareFunction, no body

;; (defun cyc-add-argument (sentence cycl-supports &optional mt properties verify-supports) ...) -- active declareFunction, no body

;; (defun cyc-remove-argument (sentence cycl-supports &optional mt) ...) -- active declareFunction, no body

;; (defun cyc-remove-all-arguments (sentence &optional mt) ...) -- active declareFunction, no body

;; (defun legacy-query-properties-p (object) ...) -- active declareFunction, no body

;; (defun query-results-p (object) ...) -- active declareFunction, no body

;; (defun cyc-query (sentence &optional mt properties) ...) -- active declareFunction, no body

;; (defun query-success-result-p (object) ...) -- active declareFunction, no body

;; (defun open-query-result-p (object) ...) -- active declareFunction, no body

;; (defun open-query-success-result-p (object) ...) -- active declareFunction, no body

;; (defun closed-query-bindings-p (object) ...) -- active declareFunction, no body

;; (defun closed-query-justified-bindings-p (object) ...) -- active declareFunction, no body

;; (defun closed-query-success-token () ...) -- active declareFunction, no body

;; (defun closed-query-success-token-p (object) ...) -- active declareFunction, no body

;; (defun closed-query-success-result-p (object) ...) -- active declareFunction, no body

;; (defun closed-query-justified-success-result-p (object) ...) -- active declareFunction, no body

;; (defun query-id-p (object) ...) -- active declareFunction, no body

;; (defun cyc-continue-query (&optional query-id properties) ...) -- active declareFunction, no body

;; (defun cyc-tms-reconsider-sentence (sentence &optional mt) ...) -- active declareFunction, no body

;; (defun cyc-tms-reconsider-term (term &optional mt) ...) -- active declareFunction, no body

;; (defun cyc-tms-reconsider-mt (mt) ...) -- active declareFunction, no body

;; (defun cyc-rename-variables (sentence rename-variable-list &optional mt) ...) -- active declareFunction, no body

;;; Init section

(deflexical *closed-query-bindings* nil)
(deflexical *closed-query-success-token* (list *closed-query-bindings*))

;;; Setup section

(register-cyc-api-function 'cyc-create-new-permanent '(name)
  "Creates a new constant with name NAME, gives it a
   permanent unique external ID, and adds the constant
   creation operation to the transcript queue."
  '((name new-constant-name-spec-p))
  '(constant-p))

(register-cyc-api-function 'cyc-create-new-ephemeral '(name)
  "Creates a new constant with name NAME, but makes
   no effort to synchronize its external ID with
   other Cyc images.  This is intended for constants
   that will not be transmitted to other Cyc images."
  '((name new-constant-name-spec-p))
  '(constant-p))

(register-cyc-api-function 'cyc-create '(name external-id)
  "Create a new constant with id EXTERNAL-ID.
   If NAME is anything other than :unnamed,
   the new constant will be given the name NAME."
  '((name new-constant-name-spec-p) (external-id (nil-or constant-external-id-p)))
  '(constant-p))

(register-cyc-api-function 'cyc-find-or-create '(name external-id)
  "Return constant with NAME if it is present.
   If not present, then create constant with NAME, using EXTERNAL-ID if given.
   If EXTERNAL-ID is not given, generate a new one for the new constant."
  '((name valid-constant-name-p) (external-id (nil-or constant-external-id-p)))
  '(constant-p))

(register-cyc-api-function 'cyc-rename '(constant name)
  "Change name of CONSTANT to NAME. Return the constant if no error, otherwise return NIL."
  '((constant constant-p) (name valid-constant-name-p))
  '((nil-or constant-p)))

(register-cyc-api-function 'cyc-recreate '(constant)
  "Doesn't unassert the bookkeeping info,
   but it might actually move it, or change
   its format somehow."
  '((constant constant-p))
  '(constant-p))

(register-cyc-api-function 'cyc-kill '(fort)
  "Kill FORT and all its uses from the KB.  If FORT is a microtheory, all assertions
   in that microtheory are removed."
  '((fort fort-p))
  '(booleanp))

(register-cyc-api-function 'cyc-rewrite '(source-fort target-fort)
  "'moves' all asserted arguments from SOURCE-FORT to TARGET-FORT
   @return fort-p; TARGET-FORT"
  '((source-fort fort-p) (target-fort fort-p))
  '(fort-p))

(register-cyc-api-function 'cyc-merge '(kill-fort keep-fort)
  "Move asserted assertions on KILL-TERM onto KEEP-TERM before killing KILL-TERM.
   @return fort-p; KEEP-FORT"
  '((kill-fort fort-p) (keep-fort fort-p))
  '(fort-p))

(register-cyc-api-function 'cyc-assert '(sentence &optional mt properties)
  "Assert SENTENCE in the specified MT.
   properties; :strength el-strength-p (:default or :monotonic)
               :direction direction-p  (:forward or :backward)
   GAF assertion direction defaults to :forward, and rule
   assertion direction defaults to :backward.
   @return booleanp; t iff the assert succeeded.  If the assertion
   already existed, it is considered a success."
  '((sentence possibly-sentence-p) (mt (nil-or possibly-mt-p)) (properties assert-properties-p))
  '(booleanp))

(register-cyc-api-function 'cyc-unassert '(sentence &optional mt)
  "Remove the assertions canonicalized from FORMULA in the microtheory MT.
   Return T if the operation succeeded, otherwise return NIL."
  '((sentence possibly-sentence-p) (mt (nil-or possibly-mt-p)))
  '(booleanp))

(register-cyc-api-function 'cyc-edit '(old-sentence new-sentence &optional old-mt (new-mt old-mt) properties)
  "Unassert OLD-SENTENCE in OLD-MT, and assert NEW-SENTENCE in the specified NEW-MT.
   @see cyc-unassert and @xref cyc-assert"
  '((old-sentence possibly-sentence-p) (new-sentence possibly-sentence-p) (old-mt (nil-or possibly-mt-p)) (new-mt (nil-or possibly-mt-p)))
  '(booleanp))

(register-cyc-api-function 'cyc-add-argument '(sentence cycl-supports &optional mt properties verify-supports)
  "Tell Cyc to conclude SENTENCE (optionally in MT) based on the list of CYCL-SUPPORTS which should themselves be assertions or
   otherwise valid for support-p. If VERIFY-SUPPORTS is non-nil, then this function will attempt to verify the list of supports
   before making the assertion.
   Properties: :direction :forward or :backward"
  '((sentence possibly-sentence-p) (cycl-supports list-of-cycl-support-p) (mt (nil-or possibly-mt-p)) (properties assert-properties-p) (verify-supports booleanp))
  '(booleanp))

(register-cyc-api-function 'cyc-remove-argument '(sentence cycl-supports &optional mt)
  "Remove the argument for SENTENCE specified by CYCL-SUPPORTS."
  '((sentence possibly-sentence-p) (cycl-supports list-of-cycl-support-p) (mt (nil-or possibly-mt-p)))
  '(booleanp))

(register-cyc-api-function 'cyc-remove-all-arguments '(sentence &optional mt)
  "Remove all arguments for SENTENCE within MT, including both those
   arguments resulting the direct assertion of SENTENCE, and
   those arguments supporting SENTENCE which were derived through inference.
   Return T if successful, otherwise return NIL."
  '((sentence possibly-sentence-p) (mt (nil-or possibly-mt-p)))
  '(booleanp))

(register-cyc-api-function 'cyc-query '(sentence &optional mt properties)
  "Query for bindings for free variables which will satisfy SENTENCE within MT.
   Properties: :backchain NIL or an integer or T
               :number    NIL or an integer
               :time      NIL or an integer
               :depth     NIL or an integer
               :conditional-sentence boolean
   If :backchain is NIL, no backchaining is performed.
   If :backchain is an integer, then at most that many backchaining steps using rules
   are performed.
   If :backchain is T, then inference is performed without limit on the number of
   backchaining steps when searching for bindings.
   If :number is an integer, then at most that number of bindings are returned.
   If :time is an integer, then at most that many seconds are consumed by the search for
   bindings.
   If :depth is an integer, then the inference paths are limited to that number of
   total steps.
   Returns NIL if the operation had an error.  Otherwise returns a (possibly empty)
   binding set.  In the case where the SENTENCE has no free variables,
   the form (NIL), the empty binding set is returned, indicating that the gaf is either
   directly asserted in the KB, or that it can be derived via rules in the KB.
   If it fails to be proven, NIL will be returned.
   The second return value indicates the reason why the query halted.
   If SENTENCE is an implication, or an ist wrapped around an implication,
   and the :conditional-sentence property is non-nil, cyc-query will attempt to
   prove SENTENCE by reductio ad absurdum."
  '((sentence possibly-sentence-p) (mt (nil-or possibly-mt-p)) (properties legacy-query-properties-p))
  '(query-results-p))

(register-obsolete-cyc-api-function 'cyc-continue-query '(continue-inference)
  '(&optional (query-id :last) properties)
  "Continues a query started by @xref cyc-query.
   If QUERY-ID is :last, the most recent query is continued."
  '((query-id query-id-p) (properties legacy-query-properties-p))
  '(query-results-p))

(register-cyc-api-function 'cyc-tms-reconsider-sentence '(sentence &optional mt)
  "Reconsider all arguments for SENTENCE within MT.  Return T if the
   operation succeeded, NIL if there was an error."
  '((sentence possibly-sentence-p) (mt (nil-or possibly-mt-p)))
  '(booleanp))

(register-cyc-api-function 'cyc-rename-variables '(sentence rename-variable-list &optional mt)
  "Rename the variables in SENTENCE by resetting the EL variable names of SENTENCE assertion,
   if it is provably possible to do so without changing the logical intent of SENTENCE.
   @see simple-variable-rename-impossible?
   @return booleanp; T if the operation succeeded, NIL if there was an error."
  '((sentence possibly-sentence-p) (mt (nil-or possibly-mt-p)) (rename-variable-list alist-p))
  '(booleanp))
