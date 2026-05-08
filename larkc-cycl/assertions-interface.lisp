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

;; TODO - all these hl-modify-remote? checks are kinda crappy.  The dispatch mechanism should be more centralized, and maybe use a function naming protocol to automatically generate the tests as to which function to call.

(define-hl-creator kb-create-assertion (cnf mt)
    "[Cyc] Create a new assertion with CNF in MT."
    (declare (type cnf-p cnf)
             (type hlmt-p mt))
  (if (hl-modify-remote?)
      (missing-larkc 32157)
      (kb-create-assertion-local cnf mt)))

;; (defun kb-create-assertion-remote (cnf mt) ...) -- active declaration, no body

(defun kb-create-assertion-local (cnf mt)
  (let ((internal-id (kb-create-assertion-kb-store cnf mt)))
    (find-assertion-by-id internal-id)))

(define-hl-modifier kb-remove-assertion (assertion)
    "[Cyc] Remove ASSERTION from the KB."
    (declare (type assertion-p assertion))
  (kb-remove-assertion-internal assertion))




;; TODO DESIGN - instead of all these remote checks everywhere, can't we manifest a simpler struct cached locally and use the normal local accessors on it?

;; [Clyc] Java defines each kb-<name> as its own defun that does checkType on each
;; parameter, then dispatches hl-access-remote? → missing-larkc vs local internal call.
;; Replaced with a macro that synthesises the defun from a name + parameter list.
;; The Java checkType becomes a (declare (type <p>-p <p>)) inferred from the parameter
;; name — all call sites here use assertion/cnf/mt, which map to the canonical predicates.
(defmacro define-kb-non-remote (name params &body (docstring &optional (internal-func (symbolicate name "-INTERNAL"))))
  "Helper for these annoyingly repetitive functions. Maps the function KB-<name> to <name>-INTERNAL with the same parameters, after a hl-access-remote? check."
  (let ((decls (loop for p in params
                     append (cond ((eq p 'assertion) '((type assertion-p assertion)))
                                  ((eq p 'cnf) '((type cnf-p cnf)))
                                  ((eq p 'mt) '((type hlmt-p mt)))))))
    `(defun ,(symbolicate "KB-" name) ,params
       ,docstring
       ,@(when decls `((declare ,@decls)))
       (if (hl-access-remote?)
           ;; These were different per instantiation, but whatever.
           (missing-larkc 29511)
           (,internal-func ,@params)))))

(define-kb-non-remote assertion-cnf (assertion)
  "[Cyc] Return the CNF for ASSERTION.")

(define-kb-non-remote possibly-assertion-cnf (assertion)
  "[Cyc] Return the CNF for ASSERTION or NIL.")

(define-kb-non-remote assertion-mt (assertion)
  "[Cyc] Return the MT for ASSERTION.")

(define-kb-non-remote lookup-assertion (cnf mt)
  "[Cyc] Return the assertion with CNF and MT, if it exists. Return NIL otherwise."
  find-assertion-internal)

;; TODO - ? vs -P disconnect
(define-kb-non-remote gaf-assertion? (assertion)
  "[Cyc] Return T iff ASSERTION is a ground atomic formula (gaf)."
  assertion-gaf-p)

(define-kb-non-remote assertion-gaf-hl-formula (assertion)
  "[Cyc] Returns the HL clause of ASSERTION if it's a gaf, otherwise returns NIL.
Ignores the truth - i.e. returns <blah> instead of (#$not <blah>) for negated gafs."
  assertion-gaf-hl-formula-internal)

(define-kb-non-remote assertion-cons (assertion)
  "[Cyc] Returns a CNF or GAF HL formula.")

(define-kb-non-remote assertion-direction (assertion)
  "[Cyc] Return the direction of ASSERTION (either :BACKWARD, :FORWARD, or :CODE).")

(define-kb-non-remote assertion-truth (assertion)
  "[Cyc] Return the current truth of ASSERTION -- either :TRUE :FALSE or :UNKNOWN")

(define-kb-non-remote assertion-strength (assertion)
  "[Cyc] Return the current argumentation strength of ASSERTION -- either :MONOTONIC, :DEFAULT, or :UNKNOWN.")

(define-kb-non-remote assertion-variable-names (assertion)
  "[Cyc] Return the variable names for ASSERTION.")

(define-kb-non-remote assertion-asserted-by (assertion)
  "[Cyc] Return the asserted-by bookkeeping info for ASSERTION."
  asserted-by-internal)

(define-kb-non-remote assertion-asserted-when (assertion)
  "[Cyc] Return the asserted-when bookkeeping info for ASSERTION."
  asserted-when-internal)

(define-kb-non-remote assertion-asserted-why (assertion)
  "[Cyc] Return the asserted-why bookkeeping info for ASSERTION."
  asserted-why-internal)

(define-kb-non-remote assertion-asserted-second (assertion)
  "[Cyc] Return the asserted-second bookkeeping info for ASSERTION."
  asserted-second-internal)


;; [Clyc] Java defines each kb-set-* as its own hl-modifier with checkType on each
;; parameter plus the standard lock/preamble dance. Replaced with a macro that forwards
;; to define-hl-modifier and infers declare types from the parameter names.
(defmacro define-kb-hl-modifier (name params &body (docstring &optional (new-func (symbolicate name "-INTERNAL"))))
  (let ((decls (loop for p in params
                     append (cond ((eq p 'assertion) '((type assertion-p assertion)))
                                  ((eq p 'new-direction) '((type direction-p new-direction)))
                                  ((eq p 'new-truth) '((type truth-p new-truth)))
                                  ((eq p 'new-strength) '((type el-strength-p new-strength)))
                                  ((eq p 'new-variable-names) '((type listp new-variable-names)))))))
    `(define-hl-modifier ,(symbolicate "KB-" name) ,params
         ,docstring
         ,(if decls `(declare ,@decls) nil)
       ;; TODO - original code had old-* variables that were unused, which read the overwritten value. Skipping since I don't believe it has side effects.
       (,new-func ,@params))))

(define-kb-hl-modifier set-assertion-direction (assertion new-direction)
  "[Cyc] Change direction of ASSERTION to NEW-DIRECTION."
  kb-set-assertion-direction-internal)

(define-kb-hl-modifier set-assertion-truth (assertion new-truth)
  "[Cyc] Change the truth of ASSERTION to NEW-TRUTH."
  reset-assertion-truth)

(define-kb-hl-modifier set-assertion-strength (assertion new-strength)
  "[Cyc] Change the strength of ASSERTION to NEW-STRENGTH."
  reset-assertion-strength)

(define-kb-hl-modifier set-assertion-variable-names (assertion new-variable-names)
  "[Cyc] Change the variable names for ASSERTION to NEW-VARIABLE-NAMES."
  reset-assertion-variable-names)

(define-kb-hl-modifier set-assertion-asserted-by (assertion assertor)
  "[Cyc] Set the asserted-by-bookkeeping info for ASSERTION to ASSERTOR."
  set-assertion-asserted-by)

(define-kb-hl-modifier set-assertion-asserted-when (assertion universal-date)
  "[Cyc] Set the aserted-when bookkeeping info for ASSERTION to UNIVERSAL-DATE."
  set-assertion-asserted-when)

(define-kb-hl-modifier set-assertion-asserted-why (assertion reason)
  "[Cyc] Set the asserted-why bookkeeping info for ASSERTION to REASON."
  set-assertion-asserted-why)

(define-kb-hl-modifier set-assertion-asserted-second (assertion universal-second)
  "[Cyc] Set the asserted-second bookkeeping info for ASSERTION to UNIVERSAL-SECOND."
  set-assertion-asserted-second)



;; TODO - Not sure why these aren't with the batch above the hl-modifiers. Figure out the grouping from the java declareFunction list.

(define-kb-non-remote assertion-arguments (assertion)
  "[Cyc] Return the arguments for ASSERTION.")

(define-kb-non-remote assertion-dependents (assertion)
  "[Cyc] Return the dependents of ASSERTION.")

;; (defun all-dependent-assertions (assertion) ...) -- active declaration, no body



;;; Cyc API registrations


(register-cyc-api-function 'kb-create-assertion '(cnf mt)
    "Create a new assertion with CNF in MT."
    '((cnf cnf-p) (mt hlmt-p))
    '(assertion-p))


(register-cyc-api-function 'kb-remove-assertion '(assertion)
    "Remove ASSERTION from the KB."
    '((assertion assertion-p))
    '(null))


(register-cyc-api-function 'kb-assertion-cnf '(assertion)
    "Return the CNF for ASSERTION."
    '((assertion assertion-p))
    '(cnf-p))


(register-cyc-api-function 'kb-possibly-assertion-cnf '(assertion)
    "Return the CNF for ASSERTION or NIL."
    '((assertion assertion-p))
    '((nil-or cnf-p)))


(register-cyc-api-function 'kb-assertion-mt '(assertion)
    "Return the MT for ASSERTION."
    '((assertion assertion-p))
    '(hlmt-p))


(register-cyc-api-function 'kb-lookup-assertion '(cnf mt)
    "Return the assertion with CNF and MT, if it exists.
   Return NIL otherwise."
    '((cnf cnf-p) (mt hlmt-p))
    '((nil-or assertion-p)))


(register-cyc-api-function 'kb-gaf-assertion? '(assertion)
    "Return T iff ASSERTION is a ground atomic formula (gaf)."
    '((assertion assertion-p))
    '(booleanp))


(register-cyc-api-function 'kb-assertion-gaf-hl-formula '(assertion)
    "Returns the HL clause of ASSERTION if it's a gaf, otherwise returns nil.
   Ignores the truth - i.e. returns <blah> instead of (#$not <blah>) for negated gafs."
    '((assertion assertion-p))
    '(possibly-sentence-p))


(register-cyc-api-function 'kb-assertion-cons '(assertion)
    "Returns a CNF or GAF HL formula."
    '((assertion assertion-p))
    '(consp))


(register-cyc-api-function 'kb-assertion-direction '(assertion)
    "Return the direction of ASSERTION (either :backward, :forward or :code)."
    '((assertion assertion-p))
    '(direction-p))


(register-cyc-api-function 'kb-assertion-truth '(assertion)
    "Return the current truth of ASSERTION -- either :true :false or :unknown."
    '((assertion assertion-p))
    '(truth-p))


(register-cyc-api-function 'kb-assertion-strength '(assertion)
    "Return the current argumentation strength of ASSERTION -- either :monotonic, :default, or :unknown."
    '((assertion assertion-p))
    '(el-strength-p))


(register-cyc-api-function 'kb-assertion-variable-names '(assertion)
    "Return the variable names for ASSERTION."
    '((assertion assertion-p))
    '(listp))


(register-cyc-api-function 'kb-assertion-asserted-by '(assertion)
    "Return the asserted-by bookkeeping info for ASSERTION."
    '((assertion assertion-p))
    '((nil-or fort-p)))


(register-cyc-api-function 'kb-assertion-asserted-when '(assertion)
    "Return the asserted-when bookkeeping info for ASSERTION."
    '((assertion assertion-p))
    '((nil-or universal-date-p)))


(register-cyc-api-function 'kb-assertion-asserted-why '(assertion)
    "Return the asserted-why bookkeeping info for ASSERTION."
    '((assertion assertion-p))
    '((nil-or fort-p)))


(register-cyc-api-function 'kb-assertion-asserted-second '(assertion)
    "Return the asserted-second bookkeeping info for ASSERTION."
    '((assertion assertion-p))
    '((nil-or universal-second-p)))


(register-cyc-api-function 'kb-set-assertion-direction '(assertion new-direction)
    "Change direction of ASSERTION to NEW-DIRECTION."
    '((assertion assertion-p) (new-direction direction-p))
    '(assertion-p))


(register-cyc-api-function 'kb-set-assertion-truth '(assertion new-truth)
    "Change the truth of ASSERTION to NEW-TRUTH."
    '((assertion assertion-p) (new-truth truth-p))
    '(assertion-p))


(register-cyc-api-function 'kb-set-assertion-strength '(assertion new-strength)
    "Change the strength of ASSERTION to NEW-STRENGTH."
    '((assertion assertion-p) (new-strength el-strength-p))
    '(assertion-p))


(register-cyc-api-function 'kb-set-assertion-variable-names '(assertion new-variable-names)
    "Change the variable names for ASSERTION to NEW-VARIABLE-NAMES."
    '((assertion assertion-p) (new-variable-names listp))
    '(assertion-p))


(register-cyc-api-function 'kb-set-assertion-asserted-by '(assertion assertor)
    "Set the asserted-by bookkeeping info for ASSERTION to ASSERTOR."
    '((assertion assertion-p) (assertor (nil-or fort-p)))
    '(assertion-p))


(register-cyc-api-function 'kb-set-assertion-asserted-when '(assertion universal-date)
    "Set the asserted-when bookkeeping info for ASSERTION to UNIVERSAL-DATE."
    '((assertion assertion-p) (universal-date (nil-or universal-date-p)))
    '(assertion-p))


(register-cyc-api-function 'kb-set-assertion-asserted-why '(assertion reason)
    "Set the asserted-why bookkeeping info for ASSERTION to REASON."
    '((assertion assertion-p) (reason (nil-or fort-p)))
    '(assertion-p))


(register-cyc-api-function 'kb-set-assertion-asserted-second '(assertion universal-second)
    "Set the asserted-second bookkeeping info for ASSERTION to UNIVERSAL-SECOND."
    '((assertion assertion-p) (universal-second (nil-or universal-second-p)))
    '(assertion-p))


(register-cyc-api-function 'kb-assertion-arguments '(assertion)
    "Return the arguments for ASSERTION."
    '((assertion assertion-p))
    '(listp))


(register-cyc-api-function 'kb-assertion-dependents '(assertion)
    "Return the dependents of ASSERTION."
    '((assertion assertion-p))
    '(listp))
