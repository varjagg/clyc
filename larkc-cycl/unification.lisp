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

;; Variables

(defvar *unify-term-variable-enabled?* t
  "[Cyc] Temporary control variable; when non-nil, term variables (EL variables) are allowed to unify with other term variables.")

(defparameter *unify-possible-cons-function* :default)
(defparameter *unify-cons-function* :default)

(defparameter *unify-multiple?* nil
  "[Cyc] Do we want UNIFY to find all possible bindings sets, and not just the first?")

(defparameter *computing-variable-map?* nil
  "[Cyc] Do we want to restrict UNIFY to only bind HL variables to other not-yet-bound HL variables in the inverted variable space?")

(defparameter *unify-return-justification?* nil
  "[Cyc] Do we return a justification for the bindings?  Currently this only works if *unify-multiple?* is NIL.")

(defparameter *variable-base-max* 100)

;; Macro — reconstructed from Internal Constants:
;;   $sym1$CLET = CLET
;;   $list2 = ((*UNIFY-RETURN-JUSTIFICATION?* T))
;; Binds *unify-return-justification?* to T for the body.
(defmacro with-unifier-justifications (&body body)
  `(let ((*unify-return-justification?* t))
     ,@body))

;; Functions — following declare_unification_file() ordering

(defun* unify-possible (obj1 obj2) (:inline t)
  "[Cyc] A quick, necessary condition check for whether unification between OBJ1 and OBJ2 could possibly succeed."
  (unify-possible-recursive obj1 obj2))

;; (defun unify-impossible (obj1 obj2) ...) -- active declareFunction, no body

(defun unify-possible-recursive (obj1 obj2)
  "[Cyc] Return T iff the objects OBJ1 and OBJ2 could possibly unify."
  (cond
    ((eql obj1 obj2) t)
    ((variable-p obj1) t)
    ((variable-p obj2) t)
    ((and (term-variable-p obj1)
          (term-variable-p obj2))
     ;; missing-larkc 31782 — likely calls unify-possible-term-variable
     ;; to check if two EL term variables can unify when
     ;; *unify-term-variable-enabled?* is non-nil
     (missing-larkc 31782))
    ((fort-p obj1) (unify-possible-fort obj1 obj2))
    ((fort-p obj2) (unify-possible-fort obj2 obj1))
    ((and (consp obj1) (consp obj2))
     (unify-possible-cons obj1 obj2))
    ((and (atom obj1) (atom obj2))
     (unify-possible-atom obj1 obj2))
    (t nil)))

;; (defun unify-possible-term-variable (obj1 obj2) ...) -- active declareFunction, no body

(defun unify-possible-fort (fort1 obj2)
  "[Cyc] Return T iff fort FORT1 and OBJ2 could possibly unify."
  (cond
    ((null obj2) nil)
    ((constant-p fort1) (unify-possible-constant fort1 obj2))
    ((constant-p obj2) (unify-possible-constant obj2 fort1))
    ((and (fully-bound-p obj2)
          (equals? fort1 obj2))
     t)
    ((consp obj2)
     ;; missing-larkc 10416 — likely nart-el-formula to get the EL formula
     ;; of fort1 (a NART) for structural comparison with obj2
     (let ((formula1 (missing-larkc 10416)))
       (unify-possible-cons formula1 obj2)))
    (t nil)))

(defun unify-possible-constant (constant1 obj2)
  "[Cyc] Return T iff constant CONSTANT1 and OBJ2 could possibly unify."
  (and (fully-bound-p obj2)
       (equals? constant1 obj2)
       t))

(defun unify-possible-cons (cons1 cons2)
  "[Cyc] Return T iff the conses CONS1 and CONS2 could possibly unify."
  (if (eq *unify-possible-cons-function* :default)
      (unify-possible-cons-default cons1 cons2)
      (funcall *unify-possible-cons-function* cons1 cons2)))

(defun unify-possible-cons-default (cons1 cons2)
  (and (unify-possible-recursive (first cons1) (first cons2))
       (unify-possible-recursive (rest cons1) (rest cons2))
       t))

(defun unify-possible-atom (atom1 atom2)
  "[Cyc] Return T iff the atoms ATOM1 and ATOM2 could possibly unify."
  (equal atom1 atom2))

(defun unify (obj-trans obj &optional share-vars? (justify? *unify-return-justification?*))
  "[Cyc] Compute the Most General Unifier between OBJ-TRANS and OBJ.
If SHARE-VARS? is nil, then the HL variables in OBJ-TRANS and OBJ
are assumed to be in different variable spaces, and the ones in OBJ-TRANS
are temporarily converted so as to uniquify all variables.
If JUSTIFY? is non-nil, then a justification will be returned (if appropriate).
@return NIL ; when unification fails
@return unification-success-token-p ; when unification succeeds without bindings
@return bindings-p ; when unification succeeds with bindings
@return set-p of bindings-p ; when *UNIFY-MULTIPLE?* is non-NIL and we find more than one way to bind the variables."
  (multiple-value-bind (v-bindings justifications)
      (unify-assuming-bindings obj-trans obj share-vars? nil justify?)
    (values v-bindings justifications)))

(defun unify-assuming-bindings (obj-trans obj &optional share-vars? assume-bindings (justify? *unify-return-justification?*))
  "[Cyc] Like UNIFY, in which unification is done within the context of assume-bindings, which are pre-existing bindings to assume."
  (increment-unification-attempt-historical-count)
  (when (unify-possible obj-trans obj)
    (unless share-vars?
      (setf obj-trans (pre-unify-replace-variables obj-trans)))
    (let ((result-bindings nil)
          (justification nil)
          (success? nil))
      (let ((*unify-return-justification?* justify?))
        (multiple-value-setq (result-bindings justification success?)
          (unify-internal obj-trans obj assume-bindings)))
      (when success?
        (increment-unification-success-historical-count)
        (cond
          ((null result-bindings)
           (values (unification-success-token) justification))
          ((set-p result-bindings)
           (let ((new-set (new-set #'equal)))
             (do-set (v-bindings result-bindings)
               (set-add (nreverse (copy-tree v-bindings)) new-set))
             (values new-set justification)))
          (t
           (values (nreverse (copy-tree result-bindings)) justification)))))))

(defun unify-internal (obj1 obj2 v-bindings)
  (let ((result-bindings nil)
        (justification nil)
        (success? nil))
    (catch :unify-failure
      (multiple-value-setq (result-bindings justification)
        (unify-recursive obj1 obj2 v-bindings))
      (setf success? t))
    (values result-bindings justification success?)))

(defun unify-failure (obj1 obj2)
  "[Cyc] Note that unification failed due to an inability to unify OBJ1 and OBJ2."
  (declare (ignore obj1 obj2))
  (throw :unify-failure nil))

(defun unify-recursive (obj1 obj2 v-bindings)
  (cond
    ((null *unify-multiple?*)
     (unify-recursive-internal obj1 obj2 v-bindings))
    ((set-p v-bindings)
     (let ((ans-bindings nil)
           (some-success? nil))
       (do-set (one-bindings v-bindings)
         (multiple-value-bind (new-bindings justification success?)
             (unify-internal obj1 obj2 one-bindings)
           (declare (ignore justification))
           (when success?
             (setf some-success? t)
             ;; missing-larkc 31767 — likely add-bindings-to-answer,
             ;; accumulates new-bindings into ans-bindings (a set of binding lists)
             (setf ans-bindings (missing-larkc 31767)))))
       (if some-success?
           (values ans-bindings nil)
           ;; missing-larkc 31773 — likely unify-failure
           (missing-larkc 31773))))
    (t
     (unify-recursive-internal obj1 obj2 v-bindings))))

;; (defun add-bindings-to-answer (bindings answer) ...) -- active declareFunction, no body

(defun unify-recursive-internal (obj1 obj2 v-bindings)
  (cond
    ((eq obj1 obj2)
     (values v-bindings nil))
    ((variable-p obj1)
     (unify-variable obj1 obj2 v-bindings))
    ((variable-p obj2)
     (unify-variable obj2 obj1 v-bindings))
    ((and (term-variable-p obj1)
          (term-variable-p obj2))
     ;; missing-larkc 31783 — likely unify-term-variable
     (missing-larkc 31783))
    ((fort-p obj1)
     ;; missing-larkc 31779 — likely unify-fort for fort obj1 against obj2
     (missing-larkc 31779))
    ((fort-p obj2)
     ;; missing-larkc 31780 — likely unify-fort for fort obj2 against obj1
     (missing-larkc 31780))
    ((and (consp obj1) (consp obj2))
     (unify-cons obj1 obj2 v-bindings))
    ((and (atom obj1) (atom obj2))
     (unify-atom obj1 obj2 v-bindings))
    (t
     ;; missing-larkc 31774 — likely unify-failure
     (missing-larkc 31774))))

(defun unify-variable (variable object v-bindings)
  "[Cyc] Unify VARIABLE with OBJECT."
  (cond
    ((variable-bound-p variable v-bindings)
     ;; missing-larkc 31853 — likely variable-binding to get the current binding
     ;; of variable, then recurse with that value
     (unify-recursive (missing-larkc 31853) object v-bindings))
    ((and (variable-p object)
          (variable-bound-p object v-bindings))
     (unify-variable object variable v-bindings))
    ((unification-occurs-check variable object v-bindings)
     ;; missing-larkc 31775 — likely unify-failure due to occurs check
     (missing-larkc 31775))
    ((and *computing-variable-map?*
          (or (not (variable-p object))
              (eq (not (base-variable-p variable))
                  (not (base-variable-p object)))))
     ;; missing-larkc 31776 — likely unify-failure because variable map
     ;; constraints not met
     (missing-larkc 31776))
    (t
     (values (add-variable-binding variable object v-bindings) nil))))

;; (defun unify-term-variable (term-var1 term-var2 v-bindings) ...) -- active declareFunction, no body
;; (defun unify-fort (fort obj v-bindings) ...) -- active declareFunction, no body
;; (defun unify-constant (constant obj v-bindings) ...) -- active declareFunction, no body

(defun unify-cons (cons1 cons2 v-bindings)
  "[Cyc] Unify conses CONS1 and CONS2 assuming BINDINGS."
  (if (eq *unify-cons-function* :default)
      (unify-cons-default cons1 cons2 v-bindings)
      (funcall *unify-cons-function* cons1 cons2 v-bindings)))

(defun unify-cons-default (cons1 cons2 v-bindings)
  "[Cyc] Unify conses CONS1 and CONS2 assuming BINDINGS."
  (multiple-value-bind (car-bindings car-justification)
      (unify-recursive (first cons1) (first cons2) v-bindings)
    (multiple-value-bind (full-bindings cdr-justification)
        (unify-recursive (rest cons1) (rest cons2) car-bindings)
      (values full-bindings (append car-justification cdr-justification)))))

(defun unify-atom (atom1 atom2 v-bindings)
  "[Cyc] Unify atoms ATOM1 and ATOM2 assuming BINDINGS."
  (if (equal atom1 atom2)
      (values v-bindings nil)
      (unify-failure atom1 atom2)))

;; (defun unify-possibly-justify-equals (obj1 obj2) ...) -- active declareFunction, no body

(defun unification-occurs-check (variable value v-bindings)
  "[Cyc] Return T iff VARIABLE occurs in OBJECT according to BINDINGS."
  (when *perform-unification-occurs-check*
    (unification-occurs-check-recursive variable value v-bindings)))

(defun unification-occurs-check-recursive (variable object v-bindings)
  (cond
    ((eq variable object) t)
    ((null object) nil)
    ((consp object)
     (do ((cons object (rest cons)))
         ((atom cons) nil)
       (when (unification-occurs-check-recursive variable (first cons) v-bindings)
         (return t))
       (let ((cdr (rest cons)))
         (when (and (not (listp cdr))
                    (unification-occurs-check-recursive variable cdr v-bindings))
           (return t)))))
    ((and (variable-p object)
          (variable-bound-p object v-bindings))
     ;; missing-larkc 31854 — likely variable-binding to get the current binding
     ;; of object, then recurse with that value
     (unification-occurs-check-recursive variable (missing-larkc 31854) v-bindings))
    (t nil)))

;; (defun too-many-hl-variables (object) ...) -- active declareFunction, no body

(defun base-variable-p (object)
  (and (variable-p object)
       (< (variable-id object) *variable-base-max*)
       t))

(defun non-base-variable-p (object)
  (and (variable-p object)
       (>= (variable-id object) *variable-base-max*)
       t))

(defun variable-base-version (variable)
  (declare (type variable-p variable))
  (find-variable-by-id (mod (variable-id variable) *variable-base-max*)))

(defun variable-non-base-version (variable)
  (declare (type variable-p variable))
  (find-variable-by-id (+ (mod (variable-id variable) *variable-base-max*)
                          *variable-base-max*)))

(defun variable-base-inverted-version (variable)
  "[Cyc] Convert base VARIABLE to its non-base form, or vice versa."
  (if (base-variable-p variable)
      (variable-non-base-version variable)
      (variable-base-version variable)))

(defun non-base-variable-transform (object)
  (transform object #'base-variable-p #'variable-non-base-version))

;; (defun base-variable-transform (object) ...) -- active declareFunction, no body

(defun variable-base-inversion (object)
  (if (variable-p object)
      (variable-base-inverted-version object)
      (if (atom object)
          object
          (recons (variable-base-inversion (first object))
                  (variable-base-inversion (rest object))
                  object))))

(defun pre-unify-replace-variables (object)
  (non-base-variable-transform object))

(defun* term-variable-p (object) (:inline t)
  (el-var? object))
