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

;; Reconstructed macro. Evidence: $sym0$CLET, $list1 = ((*WITHIN-WFF?* T)).
(defmacro within-wff (&body body)
  `(let ((*within-wff?* t))
     ,@body))

(defun* within-wff? () (:inline t)
  "[Cyc] Return T iff currently within wff checking."
  *within-wff?*)

;; Reconstructed macro. Evidence: $list2 = (FORMULA &BODY BODY),
;; $sym3 = *WFF-FORMULA*, $sym4 = *WFF-ORIGINAL-FORMULA*, $sym5 = FIF,
;; $list6 = (CAND (WITHIN-WFF?) (WFF-ORIGINAL-FORMULA)),
;; $list7 = (WFF-ORIGINAL-FORMULA).
;; Binds *wff-formula* to FORMULA, and *wff-original-formula* to the
;; existing original formula if already within WFF, else to FORMULA.
(defmacro with-wff-formula (formula &body body)
  `(let ((*wff-formula* ,formula)
         (*wff-original-formula* (if (and (within-wff?) (wff-original-formula))
                                     (wff-original-formula)
                                     ,formula)))
     ,@body))

;; Reconstructed macro. Evidence: $list8 = (EXPANSION &BODY BODY),
;; $sym9 = *WFF-EXPANSION-FORMULA*,
;; $list10 = (CAND (WITHIN-WFF?) (WFF-EXPANSION-FORMULA)),
;; $list11 = (WFF-EXPANSION-FORMULA).
;; Same pattern as with-wff-formula but for expansion formulas.
(defmacro with-wff-expansion (expansion &body body)
  `(let ((*wff-expansion-formula* (if (and (within-wff?) (wff-expansion-formula))
                                      (wff-expansion-formula)
                                      ,expansion)))
     ,@body))

;; Reconstructed macro. Evidence: $list12 = (STATE &BODY BODY),
;; $sym13 = *WFF-MEMOIZATION-STATE*, $sym14 = WITH-MEMOIZATION-STATE,
;; $list15 = (*WFF-MEMOIZATION-STATE*),
;; $list16 = (PUNLESS (WITHIN-WFF?) (RESET-WFF-STATE)).
;; Verified from wff.java el_wffP lines 178-221: the punless is the protected form
;; of an unwind-protect, and the body runs in the cleanup (always executes).
;; This ensures the body runs even if reset-wff-state signals.
(defmacro with-specified-wff-memoization-state (state &body body)
  `(let ((*wff-memoization-state* ,state))
     (with-memoization-state *wff-memoization-state*
       (unwind-protect
           (unless (within-wff?)
             (reset-wff-state))
         ,@body))))

;; Reconstructed macro. Evidence: $sym17 = WITH-SPECIFIED-WFF-MEMOIZATION-STATE,
;; $list18 = (POSSIBLY-NEW-WFF-MEMOIZATION-STATE).
(defmacro with-wff-memoization-state (&body body)
  `(with-specified-wff-memoization-state (possibly-new-wff-memoization-state)
     ,@body))

(defun* possibly-new-wff-memoization-state () (:inline t)
  (or *wff-memoization-state*
      (new-memoization-state)))

;; Reconstructed macro. Evidence: $sym21 = *UNEXPANDED-FORMULA*,
;; $list22 = ((*VALIDATE-EXPANSIONS?* NIL) (*VALIDATING-EXPANSION?* T)).
;; Verified from wff.java lines 508-528: _prev_bind_0_18, _prev_bind_1_19,
;; _prev_bind_2_20 (consecutive suffixes = one clet) bind *unexpanded-formula*,
;; *validate-expansions?*, *validating-expansion?*. The separate _prev_bind_3
;; (different suffix shape) binds *wff-expansion-formula* from with-wff-expansion
;; in the caller, NOT from this macro. The macro argument is the formula (thing
;; to expand), not the expansion itself — confirmed by Java binding
;; *unexpanded-formula* to `sentence` (the SubL compiler is a literal transpiler).
(defmacro validating-expansion-of (formula &body body)
  `(let ((*unexpanded-formula* ,formula)
         (*validate-expansions?* nil)
         (*validating-expansion?* t))
     ,@body))

;; Reconstructed macro. Evidence: $list23 = ((*RELAX-ARG-CONSTRAINTS-FOR-DISJUNCTIONS?* NIL)),
;; $sym24 = VALIDATING-EXPANSION-OF.
;; Like validating-expansion-of but also relaxes arg constraints for disjunctions.
(defmacro validating-expansion-of-nat (formula &body body)
  `(let ((*relax-arg-constraints-for-disjunctions?* nil))
     (validating-expansion-of ,formula ,@body)))

;; Reconstructed macro. Evidence: $list25 = (VARIABLE KEYWORD INITIALIZATION DOCUMENTATION
;; &OPTIONAL (VACCESS (QUOTE PROTECTED))), $sym26 = PROTECTED, $sym27-30 = compile-time
;; checks (SYMBOLP KEYWORDP SELF-EVALUATING-FORM-P STRINGP), $sym31 = PROGN,
;; $sym32 = PROCLAIM, $sym33 = QUOTE, $sym34 = VACCESS, $sym35 = DEFPARAMETER,
;; $sym36 = NOTE-WFF-PROPERTY.
;; Defines a defparameter and registers it as a WFF property. The VACCESS arg was for
;; SubL's access control (public/protected/private) and is ignored in CL.
(defmacro defparameter-wff (variable keyword initialization documentation
                            &optional (vaccess 'protected))
  (declare (ignore vaccess))
  `(progn
     (defparameter ,variable ,initialization ,documentation)
     (note-wff-property ,keyword ',variable ,initialization)))

;; Reconstructed macro. Evidence: $list37 = (PROPERTIES &BODY BODY),
;; $sym38 = WFF-SVS (uninternedSymbol), $sym39 = NEW-WFF-SPECIAL-VARIABLE-STATE.
;; Creates a WFF special-variable-state from properties and delegates to
;; with-wff-special-variable-state.
(defmacro with-wff-properties (properties &body body)
  (with-temp-vars (wff-svs)
    `(let ((,wff-svs (new-wff-special-variable-state ,properties)))
       (with-wff-special-variable-state ,wff-svs
         ,@body))))

(defun new-wff-special-variable-state (properties)
  (check-wff-properties properties)
  (let ((svs (new-special-variable-state nil)))
    (dohash (indicator data (wff-properties-table))
      (destructuring-bind (var default) data
        (when var
          (let ((desired-value (getf properties indicator default)))
            (unless (equal desired-value default)
              (missing-larkc 31672))))))
    svs))

;; Reconstructed macro. Evidence: $list43 = (WFF-SVS &BODY BODY),
;; $sym44 = SVS (uninternedSymbol), $sym45 = *WFF-PROPERTIES*,
;; $sym46 = WITH-SPECIAL-VARIABLE-STATE.
;; Binds *wff-properties* to the SVS and delegates to with-special-variable-state
;; which does the check-type and progv binding.
(defmacro with-wff-special-variable-state (wff-svs &body body)
  (with-temp-vars (svs)
    `(let* ((,svs ,wff-svs)
            (*wff-properties* ,svs))
       (with-special-variable-state ,svs
         ,@body))))

;; Setup phase
(register-macro-helper 'possibly-new-wff-memoization-state 'with-wff-memoization-state)
(register-macro-helper 'new-wff-special-variable-state 'with-wff-properties)
