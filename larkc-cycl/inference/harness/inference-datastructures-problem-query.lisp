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

(defun hl-contextualized-asent-p (object)
  (and (consp object)
       (length= object 2)
       (inference-context-spec-p (first object))
       (possibly-sentence-p (second object))))

(defun inference-context-spec-p (object)
  (possibly-hlmt-p object))

(defun make-contextualized-asent (mt asent)
  (list mt asent))

(defun* contextualized-asent-mt (contextualized-asent) (:inline t)
  (first contextualized-asent))

(defun* contextualized-asent-asent (contextualized-asent) (:inline t)
  (second contextualized-asent))

(defun contextualized-asent-predicate (contextualized-asent)
  (atomic-sentence-predicate (contextualized-asent-asent contextualized-asent)))

(defun contextualized-dnf-clause-p (object)
  (when (dnf-p object)
    (dolist (asent (neg-lits object))
      (unless (hl-contextualized-asent-p asent)
        (return-from contextualized-dnf-clause-p nil)))
    (dolist (asent (pos-lits object))
      (unless (hl-contextualized-asent-p asent)
        (return-from contextualized-dnf-clause-p nil)))
    t))

;; Reconstructed from Internal Constants:
;; $list0 arglist: ((ASENT-VAR MT-VAR SENSE-VAR CONTEXTUALIZED-CLAUSE &KEY INDEX DONE) &BODY BODY)
;; $sym5 gensym INDEX-VAR, $sym8 gensym CONTEXTUALIZED-ASENT
;; $sym9 PROGN, $sym10 CLET, $sym7 IGNORE
;; $list11 (:NEG), $sym12 DO-NEG-LITS-NUMBERED, $sym13 DESTRUCTURE-CONTEXTUALIZED-ASENT
;; $list14 (:POS), $sym15 DO-POS-LITS-NUMBERED
;; Expansion verified against contextualized-clause-has-literal-with-predicate? body
(defmacro do-contextualized-clause-literals ((asent-var mt-var sense-var contextualized-clause
                                              &key index done)
                                             &body body)
  (with-temp-vars (contextualized-asent)
    (let ((neg-block
            `(dolist (,contextualized-asent (neg-lits ,contextualized-clause))
               ,@(when done `((when ,done (return))))
               (destructure-contextualized-asent (,mt-var ,asent-var) ,contextualized-asent
                 (let ((,sense-var :neg))
                   ,@body)
                 ,@(when index `((incf ,index))))))
          (pos-block
            `(dolist (,contextualized-asent (pos-lits ,contextualized-clause))
               ,@(when done `((when ,done (return))))
               (destructure-contextualized-asent (,mt-var ,asent-var) ,contextualized-asent
                 (let ((,sense-var :pos))
                   ,@body)
                 ,@(when index `((incf ,index)))))))
      (if index
          `(block nil
             (let ((,index 0))
               ,neg-block
               ,pos-block))
          `(block nil
             ,neg-block
             ,pos-block)))))

(defun contextualized-clause-has-literal-with-predicate? (contextualized-clause predicate)
  (do-contextualized-clause-literals (asent mt sense contextualized-clause)
    (declare (ignore mt sense))
    (when (atomic-sentence-with-pred-p asent predicate)
      (return-from contextualized-clause-has-literal-with-predicate? t)))
  nil)

(defun mt-asent-sense-from-atomic-contextualized-clause (contextualized-clause)
  "[Cyc] assumes CONTEXTUALIZED-CLAUSE is an atomic-clause-p"
  (if (pos-atomic-clause-p contextualized-clause)
      (destructure-contextualized-asent (mt asent)
          (atomic-clause-asent contextualized-clause)
        (values mt asent :pos))
      (if (neg-atomic-clause-p contextualized-clause)
          (destructure-contextualized-asent (mt asent)
              (atomic-clause-asent contextualized-clause)
            (values mt asent :neg))
          (error "~a was not an atomic contextualized-clause" contextualized-clause))))

(defun contextualized-dnf-clauses-p (object)
  (when (dnf-clauses-p object)
    (dolist (dnf-clause object)
      (unless (contextualized-dnf-clause-p dnf-clause)
        (return-from contextualized-dnf-clauses-p nil)))
    t))

;; Reconstructed from Internal Constants:
;; $list20 arglist: ((ASENT-VAR MT-VAR SENSE-VAR QUERY &KEY DONE) &BODY BODY)
;; $sym22 gensym CONTEXTUALIZED-CLAUSE, $sym23 DO-CLAUSES
;; $sym6 DO-CONTEXTUALIZED-CLAUSE-LITERALS (called from expansion)
;; Iterates over all clauses in a contextualized-clauses list, expanding each
;; via do-contextualized-clause-literals.
(defmacro do-contextualized-clauses-literals ((asent-var mt-var sense-var query &key done)
                                              &body body)
  (with-temp-vars (contextualized-clause)
    `(block nil
       (dolist (,contextualized-clause ,query)
         ,@(when done `((when ,done (return))))
         (do-contextualized-clause-literals (,asent-var ,mt-var ,sense-var ,contextualized-clause
                                             :done ,done)
           ,@body)))))

;; (defun sole-contextualized-asent-from-contextualized-clauses (contextualized-clauses) ...) -- active declareFunction, no body
;; (defun sole-contextualized-clause-from-singleton-contextualized-clauses (contextualized-clauses) ...) -- active declareFunction, no body

(defun problem-query-p (object)
  (contextualized-dnf-clauses-p object))

;; (defun explanatory-subquery-spec-p (object) ...) -- active declareFunction, no body
;; (defun non-explanatory-subquery-spec-p (object) ...) -- active declareFunction, no body

(defun new-problem-query-from-contextualized-clause (contextualized-clause)
  (list contextualized-clause))

;; (defun new-problem-query-without-literal (contextualized-clause sense index) ...) -- active declareFunction, no body

(defun new-problem-query-from-subclause-spec (contextualized-clause subclause-spec)
  ;; Java: checkType(subclause_spec, SUBCLAUSE_SPEC_P)
  (let ((contextualized-subclause (subclause-specified-by-spec contextualized-clause subclause-spec)))
    (new-problem-query-from-contextualized-clause contextualized-subclause)))

(defun new-problem-query-without-subclause-spec (contextualized-clause subclause-spec)
  ;; Java: checkType(subclause_spec, SUBCLAUSE_SPEC_P)
  (let ((contextualized-subclause (complement-of-subclause-specified-by-spec contextualized-clause subclause-spec)))
    (new-problem-query-from-contextualized-clause contextualized-subclause)))

(defun new-problem-query-from-contextualized-asent-sense (contextualized-asent sense)
  (cond
    ((eq sense :pos)
     (new-problem-query-from-contextualized-clause
      (make-clause nil (list contextualized-asent))))
    ((eq sense :neg)
     (new-problem-query-from-contextualized-clause
      (make-clause (list contextualized-asent) nil)))))

;; (defun new-problem-query-from-mt-asent-sense (mt asent sense) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list20 arglist (shared with do-contextualized-clauses-literals)
;; $sym28 DO-CONTEXTUALIZED-CLAUSES-LITERALS — expansion delegates directly
;; A problem-query IS a contextualized-dnf-clauses, so this is a direct alias.
(defmacro do-problem-query-literals ((asent-var mt-var sense-var query &key done) &body body)
  `(do-contextualized-clauses-literals (,asent-var ,mt-var ,sense-var ,query :done ,done)
     ,@body))

(defun problem-query-in-equality-reasoning-domain? (query equality-reasoning-domain)
  (cond
    ((eq equality-reasoning-domain :none) nil)
    ((eq equality-reasoning-domain :all) t)
    ((eq equality-reasoning-domain :single-literal)
     (atomic-clauses-p query))
    (t (error "Unexpected equality reasoning domain ~a" equality-reasoning-domain))))

(defun problem-query-variables (query)
  (expression-gather query #'hl-variable-p))

(defun single-clause-problem-query-p (object)
  (and (problem-query-p object)
       (singleton? object)))

;; (defun sole-contextualized-clause-from-single-clause-problem-query (query) ...) -- active declareFunction, no body

(defun single-literal-problem-query-p (object)
  "[Cyc] @return boolean; whether OBJECT is a problem query consisting of
a single contextualized literal (either positive or negative)."
  (and (problem-query-p object)
       (problem-query-has-single-literal-p object)))

(defun problem-query-has-single-literal-p (problem-query)
  "[Cyc] @return boolean; whether PROBLEM-QUERY has only
a single contextualized literal (either positive or negative)."
  (and (singleton? problem-query)
       (atomic-clause-p (first problem-query))))

;; (defun asent-sense-and-mt-to-problem-query (asent sense mt) ...) -- active declareFunction, no body

(defun single-literal-problem-query-sense (query)
  "[Cyc] @param QUERY atomic-clauses-p;
@return sense-p;  Returns the sense of query."
  (if (pos-atomic-clauses-p query)
      :pos
      :neg))

(defun single-literal-problem-query-mt (query)
  (let ((dnf-clause (first query)))
    (destructure-contextualized-asent (mt asent)
        (atomic-clause-asent dnf-clause)
      (declare (ignore asent))
      mt)))

(defun single-literal-problem-query-atomic-sentence (query)
  (let* ((dnf-clause (first query))
         (contextualized-asent (atomic-clause-asent dnf-clause)))
    (when contextualized-asent
      (destructure-contextualized-asent (mt asent) contextualized-asent
        (declare (ignore mt))
        asent))))

(defun single-literal-problem-query-predicate (query)
  "[Cyc] Assuming QUERY is a @xref single-literal-problem-query-p,
returns the predicate of its single contextualized literal."
  (let ((asent (single-literal-problem-query-atomic-sentence query)))
    (atomic-sentence-predicate asent)))

(defun mt-asent-sense-from-singleton-query (query)
  "[Cyc] assumes QUERY is a singleton contextualized-dnf-clauses-p
whose single element is an atomic-clause-p"
  (mt-asent-sense-from-atomic-contextualized-clause (first query)))

(defparameter *formula-term-signature-counts* nil)

;; (defun formula-term-signature (formula &optional var?) ...) -- active declareFunction, no body
;; (defun problem-query-term-signature (query) ...) -- active declareFunction, no body
;; (defun problem-query-term-signature-estimated-size (query) ...) -- active declareFunction, no body

(defun formula-term-signature-visit (object)
  ;; Likely increments a count for each term in a formula signature —
  ;; evidence: *formula-term-signature-counts* defparameter, postprocess-formula-term-signature
  (missing-larkc 35434))

;; (defun postprocess-formula-term-signature (counts) ...) -- active declareFunction, no body

;;; Setup
(toplevel
  (note-funcall-helper-function 'formula-term-signature-visit))
