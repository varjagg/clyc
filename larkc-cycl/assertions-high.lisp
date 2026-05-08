#|
  Copyright (c) 2019-2020 White Flame

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


;; Reconstructed from Internal Constants: $list0 arglist, $sym4$ DO-LIST,
;; $sym5$ ASSERTION-ARGUMENTS.
(defmacro do-assertion-arguments ((argument-var assertion &key done) &body body)
  `(do-list (,argument-var (assertion-arguments ,assertion) :done ,done)
     ,@body))

;; Reconstructed from Internal Constants: $list6 arglist, $sym4$ DO-LIST,
;; $sym7$ ASSERTION-DEPENDENTS.
(defmacro do-assertion-dependents ((deduction-var assertion &key done) &body body)
  `(do-list (,deduction-var (assertion-dependents ,assertion) :done ,done)
     ,@body))

;; Reconstructed from Internal Constants: $list8 arglist ((LIT-VAR ASSERTION &KEY SENSE PREDICATE DONE)),
;; $sym12$ PREDICATE-VAR (gensym), $sym13$ CLET, $sym14$ DO-ASSERTION-LITERALS,
;; $sym15$ PWHEN, $sym16$ ATOMIC-SENTENCE-PREDICATE, $sym17$ CNF-VAR (gensym),
;; $sym18$ ASSERTION-VAR (gensym), $sym19$ ASSERTION-CNF, $sym20$ DO-ALL-LITS-AS-ASENTS.
;; TODO - shape of the :predicate filter is inferred; verify against any future runtime test.
(defmacro do-assertion-literals ((lit-var assertion &key sense predicate done) &body body)
  (let ((assertion-var (gensym "ASSERTION-VAR"))
        (cnf-var (gensym "CNF-VAR"))
        (predicate-var (gensym "PREDICATE-VAR")))
    `(let* ((,assertion-var ,assertion)
            (,cnf-var (assertion-cnf ,assertion-var))
            (,predicate-var ,predicate))
       (do-all-lits-as-asents (,lit-var ,cnf-var :sense ,sense :done ,done)
         (pwhen (or (null ,predicate-var)
                    (eq ,predicate-var (atomic-sentence-predicate ,lit-var)))
           ,@body)))))

;; Reconstructed from Internal Constants: $list139 = ((*ASSERTION-DUMP-ID-TABLE*
;; (CREATE-ASSERTION-DUMP-ID-TABLE)) (*CFASL-ASSERTION-HANDLE-FUNC* 'ASSERTION-DUMP-ID)).
(defmacro with-assertion-dump-id-table (&body body)
  `(let ((*assertion-dump-id-table* (create-assertion-dump-id-table))
         (*cfasl-assertion-handle-func* 'assertion-dump-id))
     ,@body))


;; [Clyc] Java defines each of these accessors as a standalone defun that does
;; checkType(assertion, ASSERTION-P) + assertion-handle-valid? guard + delegates to the
;; corresponding kb-<name> function. Replaced here with a macro that synthesises all of
;; those defuns from a name + docstring. The Java checkType becomes (declare (type ...)).
(defmacro define-valid-assertion-func (name &body (docstring &optional (internal-func (symbolicate "KB-" name))))
  `(defun ,name (assertion)
     ,@(when (stringp docstring) (list docstring))
     (declare (type assertion-p assertion))
     (and (assertion-handle-valid? assertion)
          (,internal-func assertion))))

;; (defun intuitive-assertion-cnf (assertion) ...) -- active declaration, no body

(define-valid-assertion-func assertion-cnf
  "[Cyc] Return the cnf of ASSERTION.
Note: If you know the assertion is a gaf, consider using gaf-formula instead, if you do not explicitly need a CNF.")

(define-valid-assertion-func possibly-assertion-cnf
  "[Cyc] Return the CNF of ASSERTION, or NIL if none can be found.")

(define-valid-assertion-func assertion-mt
  "[Cyc] Return the MT of ASSERTION.")

(define-valid-assertion-func assertion-gaf-hl-formula
  nil)

(define-valid-assertion-func assertion-cons
    "[Cyc] Return a cons list representing ASSERTION's formula in some form, maybe a CNF, maybe a GAF formula, or NIL if it's invalid.
Note: Result is not destructible.")

(define-valid-assertion-func gaf-assertion?
  "[Cyc] Return T iff ASSERTION is a ground atomic formula (gaf).")

(define-valid-assertion-func assertion-direction
  "[Cyc] Return the direction of ASSERTION (either :backward, :forward, or :code).")

(define-valid-assertion-func assertion-truth
  "[Cyc] Return the current truth of ASSERTION -- either :true :false or :unknown.")

(define-valid-assertion-func assertion-strength
  "[Cyc] Return the current argumentation strength of ASSERTION -- either :monotic, :default, or :unknown.")

(define-valid-assertion-func assertion-variable-names
  "[Cyc] Return the variable names for ASSERTION.")

;; TODO - names that don't fit the pattern
(define-valid-assertion-func asserted-by
  "[Cyc] Returns the cyclist who asserted ASSERTION."
  kb-assertion-asserted-by)

(define-valid-assertion-func asserted-when
  "[Cyc] Returns the day when ASSERTION was asserted."
  kb-assertion-asserted-when)

(define-valid-assertion-func asserted-why
  "[Cyc] Returns the reason why ASSERTION was asserted."
  kb-assertion-asserted-why)

(define-valid-assertion-func asserted-second
  "[Cyc] Returns the second of the day when ASSERTION was asserted."
  kb-assertion-asserted-second)

(define-valid-assertion-func assertion-arguments
  "[Cyc] Return a list of the arguments for ASSERTION.")

(define-valid-assertion-func assertion-dependents
  "[Cyc] Return a list of the dependents of ASSERTION.")



(defun cyc-assertion-tv (assertion)
  "[Cyc] Cyc has its own notion of tv (truth + strength) as a legacy of when the Cyc and HL sides were entangled."
  (tv-from-truth-strength (assertion-truth assertion)
                          (assertion-strength assertion)))

(defun assertion-formula (assertion)
  "[Cyc] Return a formula for ASSERTION."
  (declare (type assertion-p assertion))
  (if (gaf-assertion? assertion)
      (gaf-el-formula assertion)
      (when-let ((cnf (assertion-cnf assertion)))
        (and (cnf-p cnf)
             (cnf-formula cnf (assertion-truth assertion))))))

;; (defun assertion-ist-formula (assertion) ...) -- active declaration, no body, Cyc API
;; (defun assertion-to-hl-assertion-spec (assertion) ...) -- active declaration, no body
;; (defun assertion-to-hl-assertibles (assertion) ...) -- active declaration, no body
;; (defun assertion-mentions-term? (assertion term) ...) -- active declaration, no body, Cyc API
;; (defun assertion-mentions-term (assertion term) ...) -- active declaration, no body, obsolete Cyc API
;; (defun assertion-cnf-or-gaf-hl-formula (assertion) ...) -- active declaration, no body

(defun rule-assertion? (assertion)
  "[Cyc] Return T iff ASSERTION is a rule, i.e. not a ground atomic formula (gaf)."
  (and (assertion-p assertion)
       (not (gaf-assertion? assertion))))

;; (defun backward-rule? (assertion) ...) -- active declaration, no body

(defun forward-rule? (assertion)
  (and (rule-assertion? assertion)
       (forward-assertion? assertion)))

;; (defun single-literal-rule? (assertion) ...) -- active declaration, no body
;; (defun backward-gaf? (assertion) ...) -- active declaration, no body
;; (defun forward-gaf? (assertion) ...) -- active declaration, no body

(defun* assertion-type (assertion) (:inline t)
  "[Cyc] Return the current type of ASSERTION -- either :GAF or :RULE."
  (declare (type assertion-p assertion))
  (if (gaf-assertion? assertion)
      :gaf
      :rule))

;; (defun assertion-has-mt? (assertion mt) ...) -- active declaration, no body

(defun* assertion-has-type? (assertion type) (:inline t)
  "[Cyc] Return T iff ASSERTION's current type is TYPE."
  (declare (type assertion-p assertion)
           (type assertion-type-p type))
  (eq type (assertion-type assertion)))

;; (defun assertion-has-type (assertion type) ...) -- active declaration, no body, obsolete
;; (defun ground-assertion? (assertion) ...) -- active declaration, no body
;; (defun atomic-assertion? (assertion) ...) -- active declaration, no body
;; (defun meta-assertion? (assertion) ...) -- active declaration, no body
;; (defun lifting-assertion-p (assertion) ...) -- active declaration, no body
;; (defun assertion-forts (assertion &optional a b c d) ...) -- active declaration, no body
;; (defun assertion-constants (assertion) ...) -- active declaration, no body

(defun* gaf-formula (assertion) (:inline t)
  "[Cyc] Return the formula for ASSERTION, which must be a gaf.
Does not put a #$not around negated gafs."
  (gaf-hl-formula assertion))

(defun* gaf-hl-formula (assertion) (:inline t)
  "[Cyc] Return the formula for ASSERTION, which must be a gaf.
Does not put a #$not around negated gafs."
  (assertion-gaf-hl-formula assertion))

(defun* gaf-el-formula (assertion) (:inline t)
  "[Cyc] Return the formula for ASSERTION, which must be a gaf.
Puts a #$not around negated gafs.
Does not do any uncanonicalization or conversion of HL terms in args to EL."
  (assertion-gaf-el-formula assertion))

(defun assertion-gaf-el-formula (assertion)
  "[Cyc] Returns the EL formula of ASSERTION if it's a gaf, otherwise returns NIL.
This will return (#$not <blah>) for negated gafs."
  (when-let ((formula (assertion-gaf-hl-formula assertion)))
    (if (eq :false (assertion-truth assertion))
        (negate formula)
        formula)))

(defun gaf-args (assertion)
  "[Cyc] Returnargs of the gaf ASSERTION."
  (formula-args (gaf-formula assertion)))

(defun* gaf-arg (assertion n) (:inline t)
  "[Cyc] Return arg N of the gaf ASSERTION."
  (nth n (gaf-formula assertion)))

(defun* gaf-predicate (assertion) (:inline t)
  "[Cyc] Return the predicate of gaf ASSERTION."
  (declare (type assertion-p assertion))
  (formula-arg0 (gaf-hl-formula assertion)))

;; (defun gaf-arg0 (assertion) ...) -- active declaration, no body, Cyc API

(defun* gaf-arg1 (assertion) (:inline t)
  "[Cyc] Return arg 1 of the gaf ASSERTION."
  (declare (type assertion-p assertion))
  (gaf-arg assertion 1))

(defun* gaf-arg2 (assertion) (:inline t)
  "[Cyc] Return arg 2 of the gaf ASSERTION."
  (declare (type assertion-p assertion))
  (gaf-arg assertion 2))

(defun* gaf-arg3 (assertion) (:inline t)
  "[Cyc] Return arg 3 of the gaf ASSERTION."
  (declare (type assertion-p assertion))
  (gaf-arg assertion 3))

;; (defun gaf-arg4 (assertion) ...) -- active declaration, no body, Cyc API
;; (defun gaf-arg5 (assertion) ...) -- active declaration, no body, Cyc API

(defun* assertion-has-direction? (assertion direction) (:inline t)
  "[Cyc] Return T iff ASSERTION has DIRECTION as its direction."
  (declare (type assertion-p assertion)
           (type direction-p direction))
  (eq direction (assertion-direction assertion)))

;; TODO - deprecate
(defun* assertion-has-direction (assertion direction) (:inline t)
  (assertion-has-direction? assertion direction))

(defun forward-assertion? (assertion)
  "[Cyc] Predicate returns T iff ASSERTION's direction is :FORWARD."
  (and (assertion-p assertion)
       (eq :forward (assertion-direction assertion))))

;; (defun backward-assertion? (assertion) ...) -- active declaration, no body, Cyc API
;; (defun code-assertion? (assertion) ...) -- active declaration, no body, Cyc API

(defun* assertion-has-truth? (assertion truth) (:inline t)
  "[Cyc] Return T iff ASSERTION's current truth is TRUTH."
  (declare (type assertion-p assertion)
           (type truth-p truth))
  (eq (assertion-truth assertion) truth))

;; TODO - deprecate
(defun* assertion-has-truth (assertion truth) (:inline t)
  (declare (type assertion-p assertion)
           (type truth-p truth))
  (assertion-has-truth? assertion truth))

(defun* assertion-el-variables (assertion) (:inline t)
  "[Cyc] Return a list of the EL variables, for ASSERTION."
  (mapcar #'intern-el-var (assertion-variable-names assertion)))

;; (defun assertion-hl-variables (assertion) ...) -- active declaration, no body
;; (defun assertion-free-hl-variables (assertion) ...) -- active declaration, no body
;; (defun assertion-el-variable-to-hl (assertion el-var) ...) -- active declaration, no body
;; (defun assertion-hl-variable-to-el (assertion hl-var) ...) -- active declaration, no body

(defun timestamp-asserted-assertion (assertion &optional who when why second)
  (when *recording-hl-transcript-operations?*
    (missing-larkc 32158))
  (timestamp-asserted-assertion-int assertion who when why second))

;; (defun remove-asserted-assertion-timestamp (assertion) ...) -- active declaration, no body
;; (defun tl-timestamp-asserted-assertion (assertion who when why second) ...) -- active declaration, no body
;; (defun tl-cache-assertion (tl-assertion hl-assertion) ...) -- active declaration, no body
;; (defun tl-find-assertion (tl-assertion) ...) -- active declaration, no body

(defglobal *tl-assertion-lookaside-table* nil
    "[Cyc] A lookaside cache for efficiency of tl-timestamp-asserted-assertion.
TL assertion -> HL assertion.")

(deflexical *tl-assertion-capacity* 5)

(defun timestamp-asserted-assertion-int (assertion &optional who when why second)
  (declare (type assertion-p assertion))
  (when (asserted-assertion? assertion)
    (kb-set-assertion-asserted-by assertion who)
    (kb-set-assertion-asserted-when assertion when)
    (kb-set-assertion-asserted-why assertion why)
    (kb-set-assertion-asserted-second assertion second))
  assertion)

(defun invalid-assertion? (assertion &optional robust?)
  (declare (ignore robust?))
  (and (assertion-p assertion)
       (not (valid-assertion? assertion))))

;; (defun invalid-assertion-robust? (assertion) ...) -- active declaration, no body

;; TODO - deprecate
(defun* valid-assertion (assertion &optional robust?) (:inline t)
  (declare (ignore robust?))
  (valid-assertion? assertion))

;; (defun invalid-assertion (assertion &optional robust?) ...) -- active declaration, no body, obsolete
;; (defun assertion-id-from-recipe (recipe mt) ...) -- active declaration, no body

(defun* create-assertion (cnf mt &optional var-names (direction :backward)) (:inline t)
  "[Cyc] Create a new assertion with CNF in MT."
  (declare (type cnf-p cnf)
           (type hlmt-p mt)
           (type direction-p direction))
  (create-assertion-int cnf mt var-names direction))

;; (defun create-gaf (formula mt &optional direction) ...) -- active declaration, no body

(defun find-or-create-assertion (cnf mt &optional var-names (direction :backward))
  "[Cyc] Return assertion in MT with CNF, if it exists -- else create it."
  (declare (type cnf-p cnf)
           (type hlmt-p mt)
           (type direction-p direction))
  (or (find-assertion cnf mt)
      (create-assertion cnf mt var-names direction)))

;; (defun find-or-create-gaf (formula mt &optional direction) ...) -- active declaration, no body

(defun create-assertion-int (cnf mt &optional var-names (direction :backward))
  (let ((assertion (kb-create-assertion cnf mt)))
    (when assertion
      (kb-set-assertion-variable-names assertion var-names)
      (kb-set-assertion-direction assertion direction))
    assertion))

(defun* remove-assertion (assertion) (:inline t)
  "[Cyc] Remove ASSERTION."
  (kb-remove-assertion assertion))

;; (defun remove-broken-assertions () ...) -- active declaration, no body
;; (defun possibly-remove-broken-assertion (assertion) ...) -- active declaration, no body
;; (defun matching-argument-on-assertion (assertion argument) ...) -- active declaration, no body

(defun only-argument-of-assertion-p (assertion argument)
  "[Cyc] Returns T if ARGUMENT is the sole argument for ASSERTION; NIL if there are other, different arguments."
  (declare (type assertion-p assertion)
           (type argument-p argument))
  (not (member? argument (assertion-arguments assertion) :test #'not-eq)))

(defun asserted-assertion? (assertion)
  "[Cyc] Return non-NIL iff ASSERTION has an asserted argument."
  (declare (type assertion-p assertion))
  (find-if #'asserted-argument-p (assertion-arguments assertion)))

;; (defun deduced-assertion? (assertion) ...) -- active declaration, no body, Cyc API
;; (defun forward-deduced-assertion? (assertion) ...) -- active declaration, no body

(defun get-asserted-argument (assertion)
  "[Cyc] Return the asserted argument for ASSERTION, or NIL if none present."
  (declare (type assertion-p assertion))
  (find-if #'asserted-argument-p (assertion-arguments assertion)))

;; (defun assertion-deductions (assertion) ...) -- active declaration, no body

(defun assertion-dependent-count (assertion)
  "[Cyc] Return the number of arguments depending on ASSERTION."
  (length (assertion-dependents assertion)))

;; (defun assertion-has-dependents-p (assertion) ...) -- active declaration, no body, Cyc API
;; (defun random-assertion (&optional state) ...) -- active declaration, no body
;; (defun sample-assertions (&optional a b c) ...) -- active declaration, no body
;; (defun random-rule () ...) -- active declaration, no body
;; (defun random-gaf () ...) -- active declaration, no body
;; (defun assertion-checkpoint-p (object) ...) -- active declaration, no body
;; (defun new-assertion-checkpoint () ...) -- active declaration, no body
;; (defun assertion-checkpoint-current? (checkpoint) ...) -- active declaration, no body

(defparameter *assertion-dump-id-table* nil)

;; (defun assertion-dump-id (assertion) ...) -- active declaration, no body

(defun* find-assertion-by-dump-id (dump-id) (:inline t)
  "[Cyc] Return the assertion with DUMP-ID during a KB load."
  (find-assertion-by-id dump-id))


;;; Setup

(toplevel
  (declare-defglobal '*tl-assertion-lookaside-table*)
  (define-obsolete-register 'assertion-has-type '(assertion-has-type?))
  (define-obsolete-register 'assertion-has-direction '(assertion-has-direction?))
  (define-obsolete-register 'valid-assertion '(valid-assertion?))
  (define-obsolete-register 'invalid-assertion '(invalid-assertion?)))


;;; Cyc API registrations


(register-cyc-api-function 'assertion-cnf '(assertion)
    "Return the cnf of ASSERTION.
   @note If you know the assertion is a gaf,
   consider using gaf-formula instead,
   if you do not explicitly need a CNF."
    '((assertion assertion-p))
    '(cnf-p))


(register-cyc-api-function 'assertion-mt '(assertion)
    "Return the mt of ASSERTION."
    '((assertion assertion-p))
    '(hlmt-p))


(register-cyc-api-function 'assertion-direction '(assertion)
    "Return the direction of ASSERTION (either :backward, :forward or :code)."
    '((assertion assertion-p))
    '(direction-p))


(register-cyc-api-function 'assertion-truth '(assertion)
    "Return the current truth of ASSERTION -- either :true :false or :unknown."
    '((assertion assertion-p))
    '(truth-p))


(register-cyc-api-function 'assertion-strength '(assertion)
    "Return the current argumentation strength of ASSERTION -- either :monotonic, :default, or :unknown."
    '((assertion assertion-p))
    '(el-strength-p))


(register-cyc-api-function 'assertion-variable-names '(assertion)
    "Return the variable names for ASSERTION."
    '((assertion assertion-p))
    '(listp))


(register-cyc-api-function 'asserted-by '(assertion)
    "Returns the cyclist who asserted ASSERTION."
    '((assertion assertion-p))
    'nil)


(register-cyc-api-function 'asserted-when '(assertion)
    "Returns the day when ASSERTION was asserted."
    '((assertion assertion-p))
    '(integerp))


(register-cyc-api-function 'assertion-formula '(assertion)
    "Return a formula for ASSERTION."
    '((assertion assertion-p))
    '(el-formula-p))


(register-cyc-api-function 'assertion-ist-formula '(assertion)
    "Return a formula in #$ist format for ASSERTION."
    '((assertion assertion-p))
    '(el-formula-p))


(register-cyc-api-function 'assertion-mentions-term? '(assertion term)
    "Return T iff ASSERTION's formula or mt contains TERM.
   If assertion is a meta-assertion, recurse down sub-assertions.
   By convention, negated gafs do not necessarily mention the term #$not."
    '((assertion assertion-p) (term hl-term-p))
    '(booleanp))


(register-obsolete-cyc-api-function 'assertion-mentions-term 'nil '(assertion term)
    "@see assertion-mentions-term?"
    '((assertion assertion-p) (term hl-term-p))
    '(booleanp))


(register-cyc-api-function 'gaf-predicate '(assertion)
    "Return the predicate of gaf ASSERTION."
    '((assertion assertion-p))
    'nil)


(register-cyc-api-function 'gaf-arg0 '(assertion)
    "Return arg 0 (the predicate) of the gaf ASSERTION."
    '((assertion assertion-p))
    'nil)


(register-cyc-api-function 'gaf-arg1 '(assertion)
    "Return arg 1 of the gaf ASSERTION."
    '((assertion assertion-p))
    'nil)


(register-cyc-api-function 'gaf-arg2 '(assertion)
    "Return arg 2 of the gaf ASSERTION."
    '((assertion assertion-p))
    'nil)


(register-cyc-api-function 'gaf-arg3 '(assertion)
    "Return arg 3 of the gaf ASSERTION."
    '((assertion assertion-p))
    'nil)


(register-cyc-api-function 'gaf-arg4 '(assertion)
    "Return arg 4 of the gaf ASSERTION."
    '((assertion assertion-p))
    'nil)


(register-cyc-api-function 'gaf-arg5 '(assertion)
    "Return arg 5 of the gaf ASSERTION."
    '((assertion assertion-p))
    'nil)


(register-cyc-api-function 'forward-assertion? '(assertion)
    "Predicate returns T iff ASSERTION's direction is :FORWARD."
    'nil
    '(booleanp))


(register-cyc-api-function 'backward-assertion? '(assertion)
    "Predicate returns T iff ASSERTION's direction is :BACKWARD."
    'nil
    '(booleanp))


(register-cyc-api-function 'code-assertion? '(assertion)
    "Predicate returns T iff ASSERTION's direction is :CODE."
    'nil
    '(booleanp))


(register-cyc-api-function 'assertion-has-truth? '(assertion truth)
    "Return T iff ASSERTION's current truth is TRUTH."
    '((assertion assertion-p) (truth truth-p))
    '(booleanp))


(register-obsolete-cyc-api-function 'assertion-has-truth 'nil '(assertion truth)
    "@see assertion-has-truth?"
    '((assertion assertion-p) (truth truth-p))
    '(booleanp))


(register-cyc-api-function 'asserted-assertion? '(assertion)
    "Return non-nil IFF assertion has an asserted argument."
    '((assertion assertion-p))
    '(booleanp))


(register-cyc-api-function 'deduced-assertion? '(assertion)
    "Return non-nil IFF assertion has some deduced argument"
    '((assertion assertion-p))
    '(booleanp))


(register-cyc-api-function 'get-asserted-argument '(assertion)
    "Return the asserted argument for ASSERTION, or nil if none present."
    '((assertion assertion-p))
    '((nil-or asserted-argument-p)))


(register-cyc-api-function 'assertion-has-dependents-p '(assertion)
    "Return non-nil IFF assertion has dependents."
    '((assertion assertion-p))
    '(booleanp))
