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

;; Struct definition — generates svs-variables, svs-values, make-special-variable-state,
;; special-variable-state-p, and setf accessors (covering Java declare entries 5-10)

(defstruct (special-variable-state (:conc-name "SVS-"))
  variables
  values)

;; Declare phase (following declare_special_variable_state_file order)

;; (defun bound-symbol-p (object) ...) -- active declaration, no body
;; (defun bound-special-variable-p (object) ...) -- active declaration, no body
;; (defun bound-special-variable-list-p (object) ...) -- active declaration, no body

;; special-variable-state-print-function-trampoline — missing-larkc 31670
;; special-variable-state-p — provided by defstruct
;; svs-variables — provided by defstruct
;; svs-values — provided by defstruct
;; _csetf-svs-variables — provided by defstruct (setf svs-variables)
;; _csetf-svs-values — provided by defstruct (setf svs-values)
;; make-special-variable-state — provided by defstruct

;; (defun print-special-variable-state (object stream depth) ...) -- active declaration, no body

;; TODO - SubL sxhash is a generic function, so this should be a method. Otherwise, a :test #'equalp hashtable is required, as that is the only one which descends through structs, but also ignores string case
;; TODO - a reasonable fix is to make this struct a :type list to support #'equal hashing, but that would also break special-variable-state-p
;; however, if svs objects are never stored in hashtables, which they might not, then this is a moot point anyway
(defun sxhash-special-variable-state-method (object)
  (logxor (sxhash (svs-variables object)) (sxhash (svs-values object))))

(defun new-special-variable-state (special-variables)
  "[Cyc] Return a new SPECIAL-VARIABLE-STATE-P based on the current values for SPECIAL-VARIABLES."
  (declare (type list special-variables))
  (let ((svs (make-special-variable-state :variables (copy-list special-variables)
                                          :values (make-list (length special-variables)))))
    (update-special-variable-state svs)))

;; (defun special-variable-state-variables (svs) ...) -- active declaration, no body
;; (defun special-variable-state-variable-value (svs variable &optional default) ...) -- active declaration, no body

;; Reconstructed macro. Evidence: $list22 = (SVS &BODY BODY),
;; $sym23 = SVS-VAR (uninternedSymbol), $sym24 = CLET, $sym25 = CHECK-TYPE,
;; $list26 = (SPECIAL-VARIABLE-STATE-P), $sym27 = CPROGV,
;; $sym28 = WITH-SPECIAL-VARIABLE-STATE-VARIABLES,
;; $sym29 = WITH-SPECIAL-VARIABLE-STATE-VALUES.
;; Binds the SVS arg to a temp var, check-types it, then uses progv (SubL CPROGV)
;; to dynamically bind the variables in the SVS to their stored values.
(defmacro with-special-variable-state (svs &body body)
  (with-temp-vars (svs-var)
    `(let ((,svs-var ,svs))
       (check-type ,svs-var special-variable-state)
       (progv (with-special-variable-state-variables ,svs-var)
              (with-special-variable-state-values ,svs-var)
         ,@body))))

;; These are macro helpers for with-special-variable-state. The names match because
;; they exist to be called inside the macro expansion — not a weird naming convention.
(defun* with-special-variable-state-variables (svs) (:inline t)
  (svs-variables svs))

(defun* with-special-variable-state-values (svs) (:inline t)
  (svs-values svs))

(defun update-special-variable-state (svs)
  "[Cyc] Update SPECIAL-VARIABLE-STATE SVS with the current binding values for all its special-variables."
  (declare (type special-variable-state svs))
  (update-special-variable-value-list (svs-values svs) (svs-variables svs))
  svs)

;; (defun special-variable-state-push (svs variable value) ...) -- active declaration, no body

(defun update-special-variable-value-list (values variables)
  (loop for variable in variables
        for rest-values on values
        do (rplaca rest-values (symbol-value variable)))
  values)

;; (defun show-special-variable-state (svs &optional stream) ...) -- active declaration, no body

;; Init phase

(defconstant *dtp-special-variable-state* 'special-variable-state)

;; Setup phase

(register-macro-helper 'with-special-variable-state-variables 'with-special-variable-state)
(register-macro-helper 'with-special-variable-state-values 'with-special-variable-state)
