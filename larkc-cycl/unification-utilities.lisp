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

(defun term-unify (term1 term2 &optional (share-vars t) (justify? *unify-return-justification?*))
  "[Cyc] Unify TERM1 with TERM2, with special handling for variable-to-fort bindings."
  (if (and (variable-p term1)
           (fort-p term2))
      (values (list (make-variable-binding term1 term2)) nil)
      (unify term1 term2 share-vars justify?)))

(defun asent-unify (asent1 asent2 &optional (share-vars nil) (justify *unify-return-justification?*))
  "[Cyc] Unify two atomic sentences."
  (unify asent1 asent2 share-vars justify))

(defun gaf-asent-unify (inference-asent gaf-asent &optional (share-vars t) (justify *unify-return-justification?*))
  "[Cyc] Unify INFERENCE-ASENT with GAF-ASENT, returning bindings, the unified gaf-asent, and justification."
  (multiple-value-bind (v-bindings justification)
      (unify inference-asent gaf-asent share-vars justify)
    (values v-bindings
            (if v-bindings gaf-asent nil)
            justification)))

(defun gaf-asent-args-unify (inference-asent gaf-asent &optional (share-vars t) (justify *unify-return-justification?*))
  "[Cyc] Unify the args of INFERENCE-ASENT with the args of GAF-ASENT."
  (let ((inference-args (atomic-sentence-args inference-asent))
        (gaf-args (atomic-sentence-args gaf-asent)))
    (multiple-value-bind (v-bindings justification)
        (unify inference-args gaf-args share-vars justify)
      (if v-bindings
          (values v-bindings (subst-bindings v-bindings inference-asent) justification)
          (values nil nil nil)))))

;; (defun gaf-asent-inverse-args-unify (inference-asent gaf-asent &optional share-vars justify) ...) -- no body, commented declareFunction

(defun transformation-asent-unify (inference-asent rule-asent)
  "[Cyc] Unify INFERENCE-ASENT with RULE-ASENT for transformation, discarding justification."
  (multiple-value-bind (v-bindings justification)
      (asent-unify inference-asent rule-asent nil nil)
    (declare (ignore justification))
    (values v-bindings nil)))

;; (defun rewrite-asent-unify (inference-asent rule-asent) ...) -- no body, commented declareFunction
;; (defun unify-clauses (clause1 clause2 &optional share-vars justify) ...) -- no body, commented declareFunction
;; (defun clean-up-unify-result (result) ...) -- no body, commented declareFunction
;; (defun unify-clause (clause1 clause2 &optional share-vars justify) ...) -- no body, commented declareFunction
;; (defun unify-clause-literal (literal literals v-bindings justify) ...) -- no body, commented declareFunction
;; (defun compute-variable-map (clause1 clause2) ...) -- no body, commented declareFunction
;; (defun variable-base-inversion-binding (binding) ...) -- no body, commented declareFunction
;; (defun unify-set (set1 set2 &optional share-vars justify) ...) -- no body, commented declareFunction
;; (defun unify-sets (sets1 sets2 &optional share-vars justify) ...) -- no body, commented declareFunction
;; (defun unify-sets-of-sets (sets1 sets2 &optional share-vars justify) ...) -- no body, commented declareFunction
;; (defun unify-set-recursive (set1 set2 v-bindings accumulator justify) ...) -- no body, commented declareFunction
;; (defun unify-element (element set v-bindings justify) ...) -- no body, commented declareFunction
;; (defun parent-to-unify-bindings (parent-bindings unify-bindings) ...) -- no body, commented declareFunction
;; (defun unify-to-child-bindings (unify-bindings) ...) -- no body, commented declareFunction
;; (defun unify-source-bindings (parent-bindings unify-bindings) ...) -- no body, commented declareFunction
;; (defun parent-to-child-bindings (parent-bindings unify-bindings) ...) -- no body, commented declareFunction
;; (defun clear-query-dnf-from-formula () ...) -- no body, commented declareFunction
;; (defun remove-query-dnf-from-formula (formula) ...) -- no body, commented declareFunction
;; (defun query-dnf-from-formula-internal (formula) ...) -- no body, commented declareFunction
;; (defun query-dnf-from-formula (formula) ...) -- no body, commented declareFunction
;; (defun remove-duplicate-formulas (formulas &optional mt) ...) -- no body, commented declareFunction
;; (defun remove-duplicate-or-invalid-formulas (formulas) ...) -- no body, commented declareFunction
;; (defun unify-el (formula1 formula2 &optional mt) ...) -- no body, commented declareFunction
;; (defun unify-el-cnfs (formula1 formula2 &optional mt) ...) -- no body, commented declareFunction
;; (defun unify-one-way (formula1 formula2) ...) -- no body, commented declareFunction
;; (defun genl-mt-unify (mt1 mt2 &optional justify?) ...) -- no body, commented declareFunction
;; (defun genl-mt-unify-no-time (mt1 mt2 justify?) ...) -- no body, commented declareFunction
;; (defun genl-mt-unify-possibly-justify-genl-mt (mt1 mt2) ...) -- no body, commented declareFunction
;; (defun genl-mt-unify-possibly-justify-temporally-subsumes (mt1 mt2) ...) -- no body, commented declareFunction
;; (defun genl-mt-unify-possibly-justify-temporally-subsumes-ins-type (mt1 mt2) ...) -- no body, commented declareFunction
;; (defun genl-mt-unify-possibly-justify-temporally-subsumes-type-type (mt1 mt2) ...) -- no body, commented declareFunction

(deflexical *query-dnf-from-formula-caching-state* nil)

(toplevel
  (note-globally-cached-function 'query-dnf-from-formula))
