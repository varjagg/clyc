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

(defun regular-kb-assertion-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] Returns whether the regular KB assertion HL storage module is applicable.
Applicable when none of the specialized modules (bookkeeping, ist, direction, performSubL,
indexical, constantName) apply."
  (and (not (my-creator-hl-storage-module-applicable? argument-spec cnf mt direction variable-map))
       (not (my-creation-time-hl-storage-module-applicable? argument-spec cnf mt direction variable-map))
       (not (my-creation-purpose-hl-storage-module-applicable? argument-spec cnf mt direction variable-map))
       (not (my-creation-second-hl-storage-module-applicable? argument-spec cnf mt direction variable-map))
       (not (ist-assertion-applicable? argument-spec cnf mt direction variable-map))
       (not (assertion-direction-hl-storage-applicable? argument-spec cnf mt direction variable-map))
       (not (perform-subl-hl-storage-applicable? argument-spec cnf mt direction variable-map))
       (not (indexical-the-user-hl-storage-applicable? argument-spec cnf mt direction variable-map))
       (not (constant-name-hl-storage-applicable? argument-spec cnf mt direction variable-map))))

;; (defun regular-kb-assertion-incompleteness (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body

(defun hl-add-as-kb-assertion (argument-spec cnf mt direction variable-map)
  "[Cyc] Add an argument as a KB assertion, dispatching on argument type."
  (let* ((argument-type (argument-spec-type argument-spec))
         (pcase-var argument-type))
    (cond
      ((eql pcase-var :asserted-argument)
       (check-type argument-spec (satisfies asserted-argument-spec-p))
       (let ((strength-spec (asserted-argument-spec-strength-spec argument-spec)))
         (hl-assert-as-kb-assertion cnf mt strength-spec direction variable-map)))
      ((eql pcase-var :deduction)
       (check-type argument-spec (satisfies deduction-spec-p))
       (let ((supports (deduction-spec-supports argument-spec)))
         (hl-deduce-as-kb-deduction cnf mt supports direction variable-map)))
      (t
       (signal-fi-error (list :generic-error "Unknown argument type ~S"))
       nil))))

(defun hl-assert-as-kb-assertion (cnf mt strength direction variable-map)
  "[Cyc] @return boolean; whether the assert succeeded"
  (let ((canon-version (list cnf variable-map)))
    (multiple-value-bind (cnf-1 v-variables hl-tv)
        (fi-canonicalize canon-version t strength)
      (let* ((var-names (mapcar #'variable-name v-variables))
             (assertion (find-or-create-assertion cnf-1 mt var-names direction)))
        (when assertion
          (hl-assert-update-asserted-argument assertion hl-tv direction))))))

(defun hl-deduce-as-kb-deduction (cnf mt supports direction variable-map)
  "[Cyc] @return boolean; whether the deduce succeeded"
  (let ((canon-version (list cnf variable-map)))
    (multiple-value-bind (cnf-2 v-variables hl-tv)
        (fi-canonicalize canon-version t)
      (let* ((var-names (mapcar #'variable-name v-variables))
             (support-truth (tv-truth hl-tv))
             (supports-copy (copy-tree supports)))
        (multiple-value-bind (deduction redundant?)
            (tms-add-deduction-for-cnf cnf-2 mt supports-copy support-truth direction var-names)
          (if (or redundant? (deduction-p deduction))
              (progn
                (when redundant?
                  (let ((formula (cnf-formula cnf-2)))
                    (signal-fi-warning (list :argument-already-present
                                            "Argument for ~S in ~S is already present"
                                            formula mt))))
                deduction)
              (let ((formula (cnf-formula cnf-2)))
                (signal-fi-error (list :generic-error
                                       "Unable to add argument for ~S in ~S"
                                       formula mt))
                nil)))))))

(defun hl-remove-as-kb-assertion (argument-spec cnf mt)
  "[Cyc] Remove an argument from a KB assertion, dispatching on argument type."
  (let* ((argument-type (argument-spec-type argument-spec))
         (pcase-var argument-type))
    (cond
      ((eql pcase-var :asserted-argument)
       (check-type argument-spec (satisfies asserted-argument-spec-p))
       (let ((strength-spec (asserted-argument-spec-strength-spec argument-spec)))
         (declare (ignore strength-spec))
         (hl-unassert-as-kb-assertion cnf mt)))
      ((eql pcase-var :deduction)
       (check-type argument-spec (satisfies deduction-spec-p))
       (let ((supports (deduction-spec-supports argument-spec)))
         (declare (ignore supports))
         (missing-larkc 31971)))
      (t
       (signal-fi-error (list :generic-error "Unknown argument type ~S"))
       nil))))

(defun hl-unassert-as-kb-assertion (cnf mt)
  "[Cyc] Unassert a KB assertion."
  (let ((canon-version (list cnf nil)))
    (multiple-value-bind (cnf-3 v-variables hl-tv)
        (fi-canonicalize canon-version t)
      (declare (ignore v-variables hl-tv))
      (let ((already-there? (find-assertion cnf-3 mt)))
        (if (null already-there?)
            (let ((formula (cnf-formula cnf-3)))
              (signal-fi-warning (list :assertion-not-present
                                       "Formula ~S in mt ~S is not in the KB"
                                       formula mt)))
            (let ((asserted-argument (get-asserted-argument already-there?)))
              (if (null asserted-argument)
                  (let ((formula (cnf-formula cnf-3)))
                    (signal-fi-warning (list :assertion-not-local
                                             "Formula ~S in mt ~S is not locally in the KB"
                                             formula mt)))
                  (tms-remove-argument asserted-argument already-there?)))))))
  t)

;; (defun hl-undeduce-as-kb-deduction (cnf mt supports) ...) -- active declareFunction, no body
;; (defun hl-remove-all-as-kb-assertion (cnf mt) ...) -- active declareFunction, no body

(defun ist-assertion-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] Returns whether the ist HL storage module is applicable."
  (declare (ignore argument-spec mt direction variable-map))
  (when (atomic-clause-p cnf)
    (let ((asent (atomic-cnf-asent cnf)))
      (when (el-formula-with-operator-p asent #$ist)
        (pattern-matches-formula-without-bindings
         '(#$ist :anything :anything)
         asent)))))

;; (defun ist-assertion-incompleteness (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body
;; (defun hl-add-as-ist-assertion (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body
;; (defun hl-remove-as-ist-assertion (argument-spec cnf mt) ...) -- active declareFunction, no body
;; (defun hl-remove-all-as-ist-assertion (cnf mt) ...) -- active declareFunction, no body

(defun constant-name-hl-storage-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] @return booleanp; Returns whether the hl-storage-module for #$constantName is applicable."
  (declare (ignore argument-spec mt direction variable-map))
  (when (pos-atomic-cnf-p cnf)
    (let ((asent (gaf-cnf-literal cnf)))
      (when (el-formula-with-operator-p asent #$constantName)
        (pattern-matches-formula-without-bindings
         '(#$constantName :constant :string)
         asent)))))

;; (defun constant-name-hl-storage-incompleteness (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body
;; (defun constant-name-hl-storage-assert (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body
;; (defun constant-name-hl-storage-unassert (argument-spec cnf mt) ...) -- active declareFunction, no body

(defun assertion-direction-hl-storage-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] @return booleanp; Returns whether the hl-storage-module for #$assertionDirection is applicable."
  (declare (ignore argument-spec mt direction variable-map))
  (when (pos-atomic-cnf-p cnf)
    (let ((asent (gaf-cnf-literal cnf)))
      (when (el-formula-with-operator-p asent #$assertionDirection)
        (pattern-matches-formula-without-bindings
         '(#$assertionDirection :assertion (:test cycl-direction-p))
         asent)))))

;; (defun assertion-direction-hl-storage-incompleteness (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body
;; (defun assertion-direction-hl-storage-assert (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body
;; (defun assertion-direction-hl-storage-unassert (argument-spec cnf mt) ...) -- active declareFunction, no body

(defun indexical-the-user-hl-storage-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] @return booleanp; Returns whether the hl-storage-module for #$indexicalReferent #$TheUser is applicable."
  (declare (ignore argument-spec mt direction variable-map))
  (when (pos-atomic-cnf-p cnf)
    (let ((asent (gaf-cnf-literal cnf)))
      (when (el-formula-with-operator-p asent #$indexicalReferent)
        (pattern-matches-formula-without-bindings
         '(#$indexicalReferent #$TheUser :fully-bound)
         asent)))))

;; (defun indexical-the-user-hl-storage-incompleteness (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body
;; (defun indexical-the-user-hl-storage-assert (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body
;; (defun indexical-the-user-hl-storage-unassert (argument-spec cnf mt) ...) -- active declareFunction, no body

(defun perform-subl-hl-storage-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] @return booleanp; Returns whether the hl-storage-module for #$performSubL is applicable."
  (declare (ignore argument-spec mt direction variable-map))
  (when (pos-atomic-cnf-p cnf)
    (let ((asent (gaf-cnf-literal cnf)))
      (when (el-formula-with-operator-p asent #$performSubL)
        (pattern-matches-formula-without-bindings
         '(#$performSubL (:or (#$SubLQuoteFn :fully-bound)
                              (#$ExpandSubLFn (:and :fully-bound (:test listp))
                                              :fully-bound)))
         asent)))))

;; (defun perform-subl-hl-storage-incompleteness (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body
;; (defun perform-subl-hl-storage-assert (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body
;; (defun perform-subl-hl-storage-unassert (argument-spec cnf mt) ...) -- active declareFunction, no body

;;; Setup

(toplevel
  (hl-storage-module :regular-kb-assertion
                     (list :pretty-name "Regular KB Assertion"
                           :argument-type :argument
                           :applicability 'regular-kb-assertion-applicable?
                           :incompleteness 'regular-kb-assertion-incompleteness
                           :add 'hl-add-as-kb-assertion
                           :remove 'hl-remove-as-kb-assertion
                           :remove-all 'hl-remove-all-as-kb-assertion))
  (hl-storage-module :ist
                     (list :pretty-name "ist"
                           :argument-type :argument
                           :predicate #$ist
                           :applicability 'ist-assertion-applicable?
                           :incompleteness 'ist-assertion-incompleteness
                           :add 'hl-add-as-ist-assertion
                           :remove 'hl-remove-as-ist-assertion
                           :remove-all 'hl-remove-all-as-ist-assertion))
  (hl-storage-module :constant-name
                     (list :pretty-name "constantName"
                           :argument-type :argument
                           :predicate #$constantName
                           :applicability 'constant-name-hl-storage-applicable?
                           :incompleteness 'constant-name-hl-storage-incompleteness
                           :add 'constant-name-hl-storage-assert
                           :remove 'constant-name-hl-storage-unassert
                           :remove-all 'constant-name-hl-storage-unassert))
  (hl-storage-module :assertion-direction
                     (list :pretty-name "assertionDirection"
                           :argument-type :argument
                           :predicate #$assertionDirection
                           :applicability 'assertion-direction-hl-storage-applicable?
                           :incompleteness 'assertion-direction-hl-storage-incompleteness
                           :add 'assertion-direction-hl-storage-assert
                           :remove 'assertion-direction-hl-storage-unassert
                           :remove-all 'assertion-direction-hl-storage-unassert))
  (hl-storage-module :indexical-the-user
                     (list :pretty-name "indexicalReferent TheUser"
                           :argument-type :argument
                           :predicate #$indexicalReferent
                           :applicability 'indexical-the-user-hl-storage-applicable?
                           :incompleteness 'indexical-the-user-hl-storage-incompleteness
                           :add 'indexical-the-user-hl-storage-assert
                           :remove 'indexical-the-user-hl-storage-unassert
                           :remove-all 'indexical-the-user-hl-storage-unassert))
  (register-solely-specific-hl-storage-module-predicate #$performSubL)
  (hl-storage-module :perform-subl
                     (list :pretty-name "performSubL"
                           :argument-type :argument
                           :predicate #$performSubL
                           :applicability 'perform-subl-hl-storage-applicable?
                           :incompleteness 'perform-subl-hl-storage-incompleteness
                           :add 'perform-subl-hl-storage-assert
                           :remove 'perform-subl-hl-storage-unassert
                           :remove-all 'perform-subl-hl-storage-unassert)))
