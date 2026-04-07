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

;;; Macros

;; Reconstructed from Internal Constants: $list0 arglist ((NEG-LITS POS-LITS) CLAUSE &BODY BODY)
;; $sym1 CDESTRUCTURING-BIND
;; Expansion visible in clause-free-variables as cdestructuring_bind with $list16 = (NEG-LITS POS-LITS)
(defmacro destructure-clause ((neg-lits pos-lits) clause &body body)
  `(destructuring-bind (,neg-lits ,pos-lits) ,clause
     ,@body))

;; Java declareMacro: DO-SUBCLAUSE-SPEC and DO-SUBCLAUSE-SPEC-COMPLEMENT
;; Original arglists from $list2: ((ASENT SENSE CLAUSE SUBCLAUSE-SPEC) &BODY BODY)
;; DO-SUBCLAUSE-SPEC used $sym5 PWHEN + $sym6 INDEX-AND-SENSE-MATCH-SUBCLAUSE-SPEC? + $sym4 DO-LITERALS-NUMBERED
;; DO-SUBCLAUSE-SPEC-COMPLEMENT used $sym8 PUNLESS instead of PWHEN, otherwise identical
;; DESIGN: Combined into do-subclause-spec* with invert? parameter and separate neg-form/pos-form
;; to avoid unreachable code warnings. Switched to dolistn for indexed iteration.
(defmacro do-subclause-spec* ((asent sense clause subclause-spec &optional invert?)
                              &body (neg-form pos-form))
  (let ((test (if invert? 'unless 'when)))
    (alexandria:with-gensyms (index)
      (alexandria:once-only (clause subclause-spec)
        `(progn
           (let ((,sense :neg))
             (declare (ignorable sense))
             (dolistn (,index ,asent (neg-lits ,clause))
               (,test (index-and-sense-match-subclause-spec? ,index :neg ,subclause-spec)
                      ,neg-form)))
           (let ((,sense :pos))
             (declare (ignorable sense))
             (dolistn (,index ,asent (pos-lits ,clause))
               (,test (index-and-sense-match-subclause-spec? ,index :pos ,subclause-spec)
                      ,pos-form))))))))

;; Reconstructed from Internal Constants: $list9 arglist ((MT ASENT) CONTEXTUALIZED-ASENT &BODY BODY)
;; Expansion visible in inference-datastructures-problem-query.java function bodies
;; as cdestructuring_bind pattern matching $list16 = (MT ASENT)
(defmacro destructure-contextualized-asent ((mt asent) contextualized-asent &body body)
  `(destructuring-bind (,mt ,asent) ,contextualized-asent
     ,@body))

;;; Functions

;; (defun remake-clause (neg-lits pos-lits clause) ...) -- active declareFunction, no body

(defun nmake-clause (neg-lits pos-lits clause)
  "[Cyc] Destructively modify CLAUSE to have NEG-LITS and POS-LITS."
  (unless (eq neg-lits (neg-lits clause))
    (setf (nth 0 clause) neg-lits))
  (unless (eq pos-lits (pos-lits clause))
    (setf (nth 1 clause) pos-lits))
  clause)

;; (defun remake-cnf (neg-lits pos-lits cnf) ...) -- active declareFunction, no body

(defun* make-gaf-cnf (asent) (:inline t)
  "[Cyc] Return a new cnf constructed from the true gaf ASENT."
  (make-cnf nil (list asent)))

;; (defun make-false-gaf-cnf (asent) ...) -- active declareFunction, no body
;; (defun make-gaf-dnf (asent) ...) -- active declareFunction, no body
;; (defun make-false-gaf-dnf (asent) ...) -- active declareFunction, no body
;; (defun make-gaf-cnf-with-truth (asent truth) ...) -- active declareFunction, no body
;; (defun make-gaf-dnf-with-truth (asent truth) ...) -- active declareFunction, no body
;; (defun remake-dnf (neg-lits pos-lits dnf) ...) -- active declareFunction, no body

(defun* nmake-dnf (neg-lits pos-lits dnf) (:inline t)
  "[Cyc] Destructively modify DNF to have NEG-LITS and POS-LITS, and return DNF itself."
  (nmake-clause neg-lits pos-lits dnf))

;; (defun asent-sense-to-literal (asent sense) ...) -- active declareFunction, no body
;; (defun clausal-form-p (object) ...) -- active declareFunction, no body

(defun clause-with-lit-counts-p (clause neg-lit-count pos-lit-count)
  "[Cyc] Return T iff CLAUSE is a clause with exactly NEG-LIT-COUNT neglits and exactly POS-LIT-COUNT poslits."
  (and (clause-p clause)
       (length= (neg-lits clause) neg-lit-count)
       (length= (pos-lits clause) pos-lit-count)))

(defun pos-atomic-cnf-p (cnf)
  "[Cyc] Return T iff CNF is a cnf representation of an atomic formula with exactly one poslit and no neglits. This is much quicker to check than GAF-CNF?."
  (and (cnf-p cnf)
       (clause-with-lit-counts-p cnf 0 1)))

(defun* pos-atomic-clause-p (clause) (:inline t)
  "[Cyc] Return T iff CLAUSE is a clause representation of an atomic formula with exactly one poslit and no neglits."
  (clause-with-lit-counts-p clause 0 1))

;; (defun neg-atomic-cnf-p (cnf) ...) -- active declareFunction, no body

(defun* neg-atomic-clause-p (clause) (:inline t)
  "[Cyc] Return T iff CLAUSE is a clause representation of an atomic formula with exactly one neglit and no poslits."
  (clause-with-lit-counts-p clause 1 0))

(defun atomic-clause-with-all-var-args? (clause)
  "[Cyc] Return T iff CLAUSE is an atomic clause, and all of the arguments to its predicate are variables."
  (when (atomic-clause-p clause)
    (let* ((asent (atomic-clause-asent clause))
           (asent-args (atomic-sentence-args asent)))
      (every-in-list #'cyc-var? asent-args))))

(defun* gaf-cnf-literal (cnf) (:inline t)
  (first (pos-lits cnf)))

;; (defun literals-with-sense (clause sense) ...) -- active declareFunction, no body

(defun atomic-cnf-asent (atomic-clause)
  "[Cyc] Returns the single pos-lit if it's a positive gaf cnf, or the single neg-lit if it's a negated gaf cnf."
  (if (pos-atomic-cnf-p atomic-clause)
      (first (pos-lits atomic-clause))
      (first (neg-lits atomic-clause))))

(defun atomic-clause-asent (atomic-clause)
  "[Cyc] Returns the single pos-lit if it's a positive gaf clause, or the single neg-lit if it's a negated gaf clause."
  (if (pos-atomic-clause-p atomic-clause)
      (first (pos-lits atomic-clause))
      (first (neg-lits atomic-clause))))

(defun atomic-cnf-predicate (atomic-clause)
  (atomic-sentence-predicate (atomic-cnf-asent atomic-clause)))

;; (defun atomic-clause-predicate (atomic-clause) ...) -- active declareFunction, no body
;; (defun negate-clause (clause) ...) -- active declareFunction, no body
;; (defun negate-clauses (clauses) ...) -- active declareFunction, no body

(defun atomic-clauses-p (object)
  "[Cyc] Return T iff OBJECT is a singleton list containing one atomic-clause-p."
  (and (consp object)
       (singleton? object)
       (atomic-clause-p (first object))))

(defun pos-atomic-clauses-p (object)
  "[Cyc] Return T iff OBJECT is a singleton list containing one pos-atomic-clause-p."
  (and (consp object)
       (singleton? object)
       (pos-atomic-clause-p (first object))))

;; (defun neg-atomic-clauses-p (object) ...) -- active declareFunction, no body
;; (defun atomic-clauses-asent (atomic-clauses) ...) -- active declareFunction, no body
;; (defun atomic-clauses-predicate (atomic-clauses) ...) -- active declareFunction, no body
;; (defun group-clauses-having-common-neg-lits (clauses &optional test) ...) -- active declareFunction, no body

(defun* unmake-clause (clause) (:inline t)
  "[Cyc] Return 0: a list of the negative literals (neg-lits) in CLAUSE.
Return 1: a list of the positive literals (pos-lits) in CLAUSE."
  (values (neg-lits clause)
          (pos-lits clause)))

;; (defun cnf? (cnf) ...) -- active declareFunction, no body
;; (defun clause? (clause &optional cnf-or-dnf) ...) -- active declareFunction, no body
;; (defun literals-spec? (literals-spec &optional cnf-or-dnf) ...) -- active declareFunction, no body
;; (defun literal-spec? (literal-spec &optional cnf-or-dnf) ...) -- active declareFunction, no body
;; (defun clause-literals (clause) ...) -- active declareFunction, no body
;; (defun cnf-literals (cnf) ...) -- active declareFunction, no body
;; (defun dnf-literals (dnf) ...) -- active declareFunction, no body
;; (defun clause-from-el-literals (el-literals) ...) -- active declareFunction, no body

(defun* clause-number-of-literals (clause) (:inline t)
  "[Cyc] Returns the number of literals (both positive and negative) in CLAUSE."
  (clause-literal-count clause))

(defun clause-literal-count (clause)
  (+ (length (neg-lits clause))
     (length (pos-lits clause))))

;; (defun unary-clause-p (clause) ...) -- active declareFunction, no body

(defun binary-clause-p (clause)
  (= 2 (clause-number-of-literals clause)))

;; (defun ternary-clause-p (clause) ...) -- active declareFunction, no body

(defun all-literals-as-asents (clause)
  (append (neg-lits clause) (pos-lits clause)))

;; (defun cnf-isa-lits (cnf) ...) -- active declareFunction, no body
;; (defun cnf-tou-lits (cnf) ...) -- active declareFunction, no body
;; (defun cnf-pred-lits (cnf predicate) ...) -- active declareFunction, no body
;; (defun gaf-clause? (clause) ...) -- active declareFunction, no body
;; (defun clause-variables (clause &optional var?) ...) -- active declareFunction, no body
;; (defun clause-free-sequence-variables (clause &optional var?) ...) -- active declareFunction, no body
;; (defun clause-free-term-variables (clause &optional var?) ...) -- active declareFunction, no body

(defun clause-free-variables (clause &optional (var? #'cyc-var?) (include-sequence-vars? t))
  (destructure-clause (neg-lits pos-lits) clause
    (let ((bound nil))
      (if (and (atomic-clause-p clause)
               (tou-lit? (first pos-lits)))
          (let ((*within-tou-gaf?* t))
            (ordered-union (literals-free-variables neg-lits bound var? include-sequence-vars?)
                           (literals-free-variables pos-lits bound var? include-sequence-vars?)))
          (ordered-union (literals-free-variables neg-lits bound var? include-sequence-vars?)
                         (literals-free-variables pos-lits bound var? include-sequence-vars?))))))

;; (defun terms-clauses (terms clauses &optional var?) ...) -- active declareFunction, no body
;; (defun term-clauses (term clauses &optional var?) ...) -- active declareFunction, no body
;; (defun term-clauses-including-refd-vars (term clauses &optional var?) ...) -- active declareFunction, no body
;; (defun clauses-referencing-vars-recursive (vars clauses var?) ...) -- active declareFunction, no body
;; (defun contextualized-literal-to-ist-sentence (contextualized-literal) ...) -- active declareFunction, no body
;; (defun contextualized-dnf-formula (contextualized-clause) ...) -- active declareFunction, no body
;; (defun contextualized-dnf-formula-from-clauses (contextualized-clauses) ...) -- active declareFunction, no body
;; (defun decontextualize-contextualized-clause (contextualized-clause) ...) -- active declareFunction, no body
;; (defun decontextualize-contextualized-clauses (contextualized-clauses) ...) -- active declareFunction, no body

;;; Subclause specs

;; defstruct provides subclause-spec-negative-indices and subclause-spec-positive-indices
;; which match the Java functions (first and second of a 2-element list).
(defstruct (subclause-spec (:type list))
  negative-indices
  positive-indices)

;; (defun subclause-spec-p (subclause-spec) ...) -- active declareFunction, no body

(defun new-subclause-spec (negative-indices positive-indices)
  "[Cyc] Note: this could be memoized"
  (setf negative-indices (canonicalize-literal-indices negative-indices))
  (setf positive-indices (canonicalize-literal-indices positive-indices))
  (list negative-indices positive-indices))

;; (defun new-total-subclause-spec (clause) ...) -- active declareFunction, no body
;; (defun new-pos-subclause-spec (clause) ...) -- active declareFunction, no body
;; (defun new-neg-subclause-spec (clause) ...) -- active declareFunction, no body

(defun new-single-literal-subclause-spec (sense index)
  (new-subclause-spec (when (eq sense :neg)
                        (list index))
                      (when (eq sense :pos)
                        (list index))))

(defun* ncanonicalize-literal-indices (indices) (:inline t)
  (sort indices #'<))

(defun* canonicalize-literal-indices (indices) (:inline t)
  (ncanonicalize-literal-indices (copy-list indices)))

(defun new-complement-subclause-spec (subclause-spec sample-clause)
  (let ((neg-lit-count (length (neg-lits sample-clause)))
        (pos-lit-count (length (pos-lits sample-clause))))
    (destructuring-bind (neg-indices pos-indices) subclause-spec
      (let ((complement-neg-indices nil)
            (complement-pos-indices nil))
        (dotimes (neg-index neg-lit-count)
          (unless (member? neg-index neg-indices)
            (push neg-index complement-neg-indices)))
        (dotimes (pos-index pos-lit-count)
          (unless (member? pos-index pos-indices)
            (push pos-index complement-pos-indices)))
        (new-subclause-spec complement-neg-indices complement-pos-indices)))))

;; subclause-spec-negative-indices — provided by defstruct (Java: first of list)
;; subclause-spec-positive-indices — provided by defstruct (Java: second of list)

;; (defun subclause-spec-subsumes? (subclause-spec-1 subclause-spec-2) ...) -- active declareFunction, no body

(defun index-and-sense-match-subclause-spec? (index sense subclause-spec)
  (member-eq? index (if (eq :neg sense)
                        (subclause-spec-negative-indices subclause-spec)
                        (subclause-spec-positive-indices subclause-spec))))

(defun subclause-specified-by-spec (clause subclause-spec)
  (let ((neg-lits nil)
        (pos-lits nil))
    (do-subclause-spec* (asent sense clause subclause-spec)
      (push asent neg-lits)
      (push asent pos-lits))
    (make-clause (nreverse neg-lits)
                 (nreverse pos-lits))))

(defun complement-of-subclause-specified-by-spec (clause subclause-spec)
  (let ((neg-lits nil)
        (pos-lits nil))
    (do-subclause-spec* (asent sense clause subclause-spec t)
      (push asent neg-lits)
      (push asent pos-lits))
    (make-clause (nreverse neg-lits)
                 (nreverse pos-lits))))

(defun subclause-spec-from-clauses (big-clause little-clause)
  (new-subclause-spec (literal-indices-from-literals (neg-lits big-clause)
                                                     (neg-lits little-clause))
                      (literal-indices-from-literals (pos-lits big-clause)
                                                    (pos-lits little-clause))))

(defun literal-indices-from-literals (big-lits little-lits)
  (loop for lit in little-lits
       collect (position lit big-lits :test #'equal)))

(defun subclause-spec-literal-count (subclause-spec)
  (+ (length (subclause-spec-positive-indices subclause-spec))
     (length (subclause-spec-negative-indices subclause-spec))))

;; (defun empty-subclause-spec? (subclause-spec) ...) -- active declareFunction, no body

(defun single-literal-subclause-spec? (subclause-spec)
  "[Cyc] Return T iff SUBCLAUSE-SPEC specifies a single literal."
  (= 1 (subclause-spec-literal-count subclause-spec)))

;; (defun multi-literal-subclause-spec? (subclause-spec) ...) -- active declareFunction, no body
;; (defun total-subclause-spec? (subclause-spec clause) ...) -- active declareFunction, no body
;; (defun clause-difference (clause-1 clause-2) ...) -- active declareFunction, no body
