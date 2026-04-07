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

(defparameter *inference-recursive-query-overhead* 20
  "[Cyc] The overhead of doing any recursive ask.")

(deflexical *directions-for-forward-inference* '(:forward))

(deflexical *directions-for-backward-inference* '(:backward :forward))

;;; Functions (ordered per declare section)

(defun rule-relevant-to-proof (assertion)
  "[Cyc] Returns whether ASSERTION is relevant to the current proof."
  (or (not *proof-checking-enabled*)
      (member assertion *proof-checker-rules*)))

(defun relevant-directions ()
  "[Cyc] Returns the list of relevant assertion directions for the current inference context."
  (if (and (within-forward-inference?)
           (not *within-assertion-forward-propagation?*))
      *directions-for-forward-inference*
      *directions-for-backward-inference*))

(defun direction-is-relevant (assertion)
  "[Cyc] Returns whether the direction of ASSERTION is relevant in the current inference context."
  (declare (type assertion assertion))
  (let ((direction (assertion-direction assertion)))
    (if (and (within-forward-inference?)
             (not *within-assertion-forward-propagation?*))
        (member direction *directions-for-forward-inference*)
        (member direction *directions-for-backward-inference*))))

;; (defun duplicate-literal-cleanup (literal &optional more) ...) -- active declareFunction, no body

(defun additional-source-variable-pos-lits (literal dependent-dnf support)
  "[Cyc] Check for variables mentioned in LITERAL but not also mentioned in DEPENDENT-DNF.
For such variables, compute their type constraints implied by their originating
SUPPORT, or #$Thing if the arg-type code yields no type constraints."
  (let ((literal-vars (tree-gather literal #'variable-p))
        (unintroduced-literal-vars nil))
    (when (null literal-vars)
      (return-from additional-source-variable-pos-lits nil))
    (dolist (literal-var literal-vars)
      (unless (tree-find literal-var dependent-dnf)
        (push literal-var unintroduced-literal-vars)))
    (when (null unintroduced-literal-vars)
      (return-from additional-source-variable-pos-lits nil))
    (let ((support-cnf nil)
          (additional-pos-lits nil))
      (if (assertion-p support)
          (let ((cnf (assertion-cnf support)))
            (setf support-cnf (if (neg-atomic-clause-p cnf)
                                  (make-gaf-cnf (first (neg-lits cnf)))
                                  cnf)))
          (setf support-cnf (make-gaf-cnf literal)))
      (dolist (unintroduced-literal-var unintroduced-literal-vars)
        (when (tree-find unintroduced-literal-var support-cnf)
          (let ((some-additional-pos-lits
                  ;; missing-larkc 30346 likely calls at-var-types function to compute
                  ;; type constraint sentences (isa/genls pos-lits) for a variable
                  ;; within a cnf, given the orphan constants #$isa, #$genls, #$TheList,
                  ;; (#$Thing) in this file's Internal Constants section.
                  (missing-larkc 30346)))
            (setf additional-pos-lits (nconc some-additional-pos-lits additional-pos-lits)))))
      (nreverse additional-pos-lits))))

;; (defun constraint-sentences-for-transformation-variable (variable support-cnf) ...) -- active declareFunction, no body

;; (defun inference-backchain-impossible (asent sense mt) ...) -- active declareFunction, no body

;; (defun transformation-backchain-for-predicate? (predicate) ...) -- active declareFunction, no body

(defun inference-canonicalize-hl-support-asent (asent)
  "[Cyc] Canonicalizes an HL support asent by sorting commutative args if the predicate is commutative."
  (let ((predicate (atomic-sentence-predicate asent)))
    (if (not (inference-commutative-relation? predicate))
        asent
        (inference-make-commutative-asent predicate (atomic-sentence-args asent)))))

(defun inference-make-commutative-asent (predicate args)
  "[Cyc] Creates a canonical commutative asent from PREDICATE and ARGS."
  (declare (type list args))
  (setf args (inference-canonicalize-commutative-args args))
  (cons predicate (append args nil)))

(defun inference-canonicalize-commutative-args (args)
  "[Cyc] Canonicalizes commutative ARGS by sorting them."
  (declare (type list args))
  (sort-terms args t nil nil))

(defun inference-canonicalize-hl-support-literal (asent)
  "[Cyc] Canonicalizes an HL support literal. Obsolete; use inference-canonicalize-hl-support-asent."
  (inference-canonicalize-hl-support-asent asent))

;; (defun inference-make-commutative-literal (predicate args) ...) -- active declareFunction, no body

;; (defun inference-term-free-variables (term) ...) -- active declareFunction, no body

;; (defun inference-literal-free-variables (literal) ...) -- active declareFunction, no body

;; (defun inference-clause-free-variables (clause) ...) -- active declareFunction, no body

;; (defun temp-term-free-variables (term &optional var-filter) ...) -- active declareFunction, no body

;; (defun inference-closed-term? (term) ...) -- active declareFunction, no body

;; (defun inference-closed-literal? (literal) ...) -- active declareFunction, no body

;; (defun inference-closed-clause? (clause) ...) -- active declareFunction, no body

;;; Setup phase

(define-obsolete-register 'inference-canonicalize-hl-support-literal
    '(inference-canonicalize-hl-support-asent))

(define-obsolete-register 'inference-make-commutative-literal
    '(inference-make-commutative-asent))

;;; Internal Constants accounting:
;;   $const4$isa, $const5$genls, $const6$TheList, $list7=(#$Thing),
;;   $const8$abnormal, $kw9$NEG, $kw10$POS, $sym16$CYC_VAR_ —
;;   Orphan constants from stripped function bodies (constraint-sentences-for-
;;   transformation-variable, inference-backchain-impossible, and the
;;   free-variable functions likely used #$isa/#$genls for type constraints,
;;   #$abnormal/:neg/:pos for backchain checking, and cyc-var? for variable detection).
