#|
  Copyright (c) 2019 White Flame

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

(defun clause-p (object)
  "[Cyc] Returns T iff OBJECT is either a CNF or DNF clause."
  (and (listp object)
       (= 2 (length object))
       (listp (first object))
       (listp (second object))))

(defun make-clause (neg-lits pos-lits)
  "[Cyc] Construct a clause from NEG-LITS and POS-LITS, each of which are lists of literals."
  (declare (type list neg-lits pos-lits))
  (list neg-lits pos-lits))

(defun neg-lits (clause)
  "[Cyc] Return the neg-lits of CLAUSE."
  (declare (type (satisfies clause-p) clause))
  (first clause))

;; (defun set-clause-neg-lits (clause neg-lits) ...) -- active declaration, no body

(defun pos-lits (clause)
  "[Cyc] Return the pos-lits of CLAUSE."
  (declare (type (satisfies clause-p) clause))
  (second clause))

(defun set-clause-pos-lits (clause pos-lits)
  "[Cyc] Destructively modify the pos-lits of CLAUSE to be POS-LITS."
  (rplaca (rest clause) pos-lits)
  clause)

(defun clause-sense-lits (clause sense)
  "[Cyc] Return the SENSE literal list of CLAUSE."
  (declare (type (satisfies clause-p) clause)
           (type (satisfies sense-p) sense))
  (ccase sense
    (:neg (neg-lits clause))
    (:pos (pos-lits clause))))

(defun ground-clause-p (clause)
  "[Cyc] Return T iff CLAUSE is a ground clause."
  (and (clause-p clause)
       (fully-bound-p clause)))

(defun atomic-clause-p (clause)
  "[Cyc] Return T iff CLAUSE is an atomic clause."
  (when (clause-p clause)
    (let ((neg-lits (neg-lits clause))
          (pos-lits (pos-lits clause)))
      (or (and (null neg-lits) (singletonp pos-lits))
          (and (null pos-lits) (singletonp neg-lits))))))

;; (defun lifting-clause-p (clause) ...) -- active declaration, no body

(defun clause-equal (clause1 clause2)
  "[Cyc] Return T iff CLAUSE1 and CLAUSE2 are both equivalent clauses."
  (and (clause-p clause1)
       (equal clause1 clause2)))

(defparameter *empty-clause* (make-clause nil nil)
  "[Cyc] The empty clause (commonly called 'box')")

(defun empty-clause ()
  "[Cyc] Return the empty clause."
  *empty-clause*)

(defun empty-clause? (clause)
  "[Cyc] Return T iff CLAUSE is empty."
  (declare (type (satisfies clause-p) clause))
  (clause-equal clause *empty-clause*))

;; (defun clause-literal (clause sense num) ...) -- active declaration, no body, Cyc API
;; (defun clause-without-literal (clause sense num) ...) -- active declaration, no body, Cyc API

(defun make-xnf (neg-lits pos-lits)
  "[Cyc] Construct an xnf (either cnf or dnf) clause from NEG-LITS and POS-LITS, each of which are lists of literals."
  (make-clause neg-lits pos-lits))

(defun cnf-p (object)
  "[Cyc] Returns T iff OBJECT is a canonicalized CycL formula in conjunctive normal form."
  (clause-p object))

(defun dnf-p (object)
  "[Cyc] Returns T iff OBJECT is a canonicalized CycL formula in disjunctive normal form."
  (clause-p object))

(defun gaf-cnf? (cnf)
  "[Cyc] Return T iff CNF is a cnf representation of a gaf formula."
  (and (pos-atomic-cnf-p cnf)
       (ground-clause-p cnf)))

;; (defun clauses-p (object) ...) -- active declaration, no body

(defun dnf-clauses-p (object)
  "[Cyc] @return boolean; t iff OBJECT is a non-empty list of DNF clauses."
  (when (non-dotted-list-p object)
    (dolist (clause object t)
      (unless (dnf-p clause)
        (return nil)))))

(defun make-cnf (neg-lits pos-lits)
  "[Cyc] Construct a cnf clause from NEG-LITS and POS-LITS, each of which are lists of literals."
  (make-clause neg-lits pos-lits))

;; (defun cnf-equal (cnf1 cnf2) ...) -- active declaration, no body

;; CYC constants used in cnf-formula / dnf-formula
(deflexical *cnf-formula-and* (reader-make-constant-shell "and"))
(deflexical *cnf-formula-or* (reader-make-constant-shell "or"))
(deflexical *cnf-formula-implies* (reader-make-constant-shell "implies"))
(deflexical *cnf-formula-not* (reader-make-constant-shell "not"))

(defun cnf-formula (cnf &optional (truth :true))
  "[Cyc] Return a readable formula of CNF.
   TRUTH only gets looked at for ground, single pos lit cnfs
   in which case TRUTH gives the truth of the gaf."
  (declare (type (satisfies cnf-p) cnf)
           (type (satisfies truth-p) truth))
  (setf cnf (possibly-escape-quote-hl-vars cnf))
  (let ((pos-lits (pos-lits cnf))
        (neg-lits (neg-lits cnf)))
    (if (rest neg-lits)
        (setf neg-lits (cons *cnf-formula-and* neg-lits))
        (setf neg-lits (first neg-lits)))
    (if (rest pos-lits)
        (setf pos-lits (cons *cnf-formula-or* pos-lits))
        (setf pos-lits (first pos-lits)))
    (cond
      ((and pos-lits neg-lits)
       (list *cnf-formula-implies* neg-lits pos-lits))
      (neg-lits
       (list *cnf-formula-not* neg-lits))
      (pos-lits
       (if (or (rest (pos-lits cnf))
               (not (fully-bound-p pos-lits))
               (not (eq truth :false)))
           pos-lits
           (list *cnf-formula-not* pos-lits))))))

;; (defun cnf-formula-from-clauses (cnf-clauses) ...) -- active declaration, no body, Cyc API

(defun make-dnf (neg-lits pos-lits)
  "[Cyc] Construct a dnf clause from NEG-LITS and POS-LITS, each of which are lists of literals."
  (make-clause neg-lits pos-lits))

;; (defun literal-of-dnf (dnf sense num) ...) -- active declaration, no body

(defun dnf-formula (dnf)
  "[Cyc] Return a readable formula of DNF."
  (let ((pos-lits (pos-lits dnf))
        (neg-lits (mapcar #'negate (neg-lits dnf))))
    (cond
      ((null neg-lits)
       (if (rest pos-lits)
           (cons *cnf-formula-and* (append pos-lits nil))
           (first pos-lits)))
      ((null pos-lits)
       (if (rest neg-lits)
           (cons *cnf-formula-and* (append neg-lits nil))
           (first neg-lits)))
      (t
       (cons *cnf-formula-and* (append (append neg-lits pos-lits) nil))))))

;; (defun dnf-formula-from-clauses (dnf-clauses) ...) -- active declaration, no body, Cyc API

(register-cyc-api-function 'clause-p '(object) "Returns T iff OBJECT is either a CNF or DNF clause." nil '(booleanp))
(register-cyc-api-function 'make-clause '(neg-lits pos-lits) "Construct a clause from NEG-LITS and POS-LITS, each of which are lists of literals." '((neg-lits listp) (pos-lits listp)) '(clause-p))
(register-cyc-api-function 'neg-lits '(clause) "Return the neg-lits of CLAUSE." '((clause clause-p)) '(listp))
(register-cyc-api-function 'pos-lits '(clause) "Return the pos-lits of CLAUSE." '((clause clause-p)) '(listp))
(register-cyc-api-function 'ground-clause-p '(clause) "Return T iff CLAUSE is a ground clause." nil '(booleanp))
(register-cyc-api-function 'atomic-clause-p '(clause) "Return T iff CLAUSE is an atomic clause." nil '(booleanp))
(register-cyc-api-function 'clause-equal '(clause1 clause2) "Return T iff CLAUSE1 and CLAUSE2 are both equivalent clauses." nil '(booleanp))
(register-cyc-api-function 'empty-clause '() "Return the empty clause." nil '(clause-p))
(register-cyc-api-function 'empty-clause? '(clause) "Return T iff CLAUSE is empty." '((clause clause-p)) '(booleanp))
(register-cyc-api-function 'clause-literal '(clause sense num) "Return literal in CLAUSE specified by SENSE and NUM.\n  SENSE must be either :pos or :neg." '((clause clause-p) (sense sense-p) (num integerp)) nil)
(register-cyc-api-function 'clause-without-literal '(clause sense num) "Return a new clause which is CLAUSE without the literal specified by SENSE and NUM.\n  SENSE must be either :pos or :neg." '((clause clause-p) (sense sense-p) (num integerp)) '(clause-p))
(register-cyc-api-function 'cnf-p '(object) "Returns T iff OBJECT is a canonicalized CycL formula in conjunctive normal form." nil '(booleanp))
(register-cyc-api-function 'gaf-cnf? '(cnf) "Return T iff CNF is a cnf representation of a gaf formula." nil '(booleanp))
(register-cyc-api-function 'cnf-formula '(cnf &optional (truth :true)) "Return a readable formula of CNF\n   TRUTH only gets looked at for ground, single pos lit cnfs\n   in which case TRUTH gives the truth of the gaf." '((cnf cnf-p) (truth truth-p)) '(el-formula-p))
(register-cyc-api-function 'cnf-formula-from-clauses '(cnf-clauses) "Return a readable formula from a list of CNF-CLAUSES." '((cnf-clauses listp)) '(el-formula-p))
(register-cyc-api-function 'dnf-formula '(dnf) "Return a readable formula of DNF." nil '(el-formula-p))
(register-cyc-api-function 'dnf-formula-from-clauses '(dnf-clauses) "Return a readable formula from a list of DNF-CLAUSES." '((dnf-clauses listp)) '(el-formula-p))
