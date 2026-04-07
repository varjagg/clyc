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

;; Used every time a new problem is about to be created.
(defun canonicalize-problem-query (query)
  "[Cyc] Used every time a new problem is about to be created."
  (let* ((query (copy-tree query))
         (simplified-query (inference-simplify-problem-query query))
         (sorted-query (inference-sort-clauses-and-literals simplified-query))
         (reduced-literals-query (inference-delete-duplicate-literals sorted-query))
         (reduced-clauses-query (inference-delete-duplicate-clauses reduced-literals-query)))
    (contiguize-hl-vars-in-clauses reduced-clauses-query)))

(defun inference-delete-duplicate-literals (contextualized-dnf-clauses)
  (let ((any-reduced? nil))
    (dolist (contextualized-dnf-clause contextualized-dnf-clauses)
      (let ((literals (neg-lits contextualized-dnf-clause)))
        (when (not (or (null literals)
                       (singleton? literals)))
          (multiple-value-bind (reduced-literals reduced?)
              (delete-duplicate-sorted-literals literals)
            ;; Likely sets neg-lits of the clause — missing-larkc 32152
            (missing-larkc 32152)
            (when reduced?
              (setf any-reduced? t)))))
      (let ((literals (pos-lits contextualized-dnf-clause)))
        (when (not (or (null literals)
                       (singleton? literals)))
          (multiple-value-bind (reduced-literals reduced?)
              (delete-duplicate-sorted-literals literals)
            (set-clause-pos-lits contextualized-dnf-clause reduced-literals)
            (when reduced?
              (setf any-reduced? t))))))
    (when any-reduced?
      (setf contextualized-dnf-clauses (inference-sort-clauses-and-literals contextualized-dnf-clauses)))
    contextualized-dnf-clauses))

(defun inference-delete-duplicate-clauses (contextualized-dnf-clauses)
  (if (singleton? contextualized-dnf-clauses)
      contextualized-dnf-clauses
      (multiple-value-bind (reduced-clauses reduced?)
          ;; Likely calls delete-duplicate-sorted-clauses — missing-larkc 35646
          (missing-larkc 35646)
        (when reduced?
          (setf reduced-clauses (inference-sort-clauses-and-literals reduced-clauses)))
        reduced-clauses)))

(defun delete-duplicate-sorted-literals (literals)
  (let* ((literal-count (length literals))
         (reduced-literals (delete-duplicates-sorted literals #'equal))
         (reduced-literal-count (length reduced-literals))
         (reduced? (< reduced-literal-count literal-count)))
    (values reduced-literals reduced?)))

;; (defun delete-duplicate-sorted-clauses (contextualized-dnf-clauses) ...) -- active declareFunction, no body

(defun inference-simplify-problem-query (contextualized-dnf-clauses)
  "[Cyc] Destructive."
  (dolist (contextualized-dnf-clause contextualized-dnf-clauses)
    (inference-simplify-contextualized-dnf-clause contextualized-dnf-clause))
  contextualized-dnf-clauses)

(defun inference-simplify-contextualized-dnf-clause (contextualized-clause)
  "[Cyc] Destructive."
  (let ((neglits-to-become-poslits nil))
    (do* ((rest-neglits (contextualized-neg-lits contextualized-clause) (rest rest-neglits)))
         ((atom rest-neglits))
      (let ((asent (first rest-neglits)))
        (if (true-sentence-p (contextualized-asent-asent asent))
            (push asent neglits-to-become-poslits)
            (rplaca rest-neglits (inference-simplify-contextualized-asent asent)))))
    (when neglits-to-become-poslits
      (let ((new-neglits (contextualized-neg-lits contextualized-clause)))
        (dolist (moving-lit neglits-to-become-poslits)
          (setf new-neglits (delete moving-lit new-neglits)))
        ;; Likely sets neg-lits of the clause — missing-larkc 32153
        (missing-larkc 32153))
      (let ((canonicalized-new-poslits (nmapcar #'inference-simplify-negated-true-sentence neglits-to-become-poslits)))
        (set-clause-pos-lits contextualized-clause
                             (nconc canonicalized-new-poslits
                                    (contextualized-pos-lits contextualized-clause))))))
  (do* ((rest-poslits (contextualized-pos-lits contextualized-clause) (rest rest-poslits)))
       ((atom rest-poslits))
    (let ((asent (first rest-poslits)))
      (rplaca rest-poslits (inference-simplify-contextualized-asent asent))))
  contextualized-clause)

;; (defun inference-simplify-negated-true-sentence (contextualized-asent) ...) -- active declareFunction, no body
;; (defun inference-el-dnf (sentence mt &optional disjunction-free-el-vars-policy) ...) -- active declareFunction, no body

(defun inference-simplify-contextualized-asent (contextualized-asent)
  (destructuring-bind (mt asent) contextualized-asent
    (cond ((and (ist-of-atomic-sentence-p asent)
                (fully-bound-p
                 ;; Likely extracts the mt from an ist sentence — missing-larkc 30489
                 (missing-larkc 30489)))
           (let ((subsentence
                   ;; Likely extracts the subsentence from an ist sentence — missing-larkc 30512
                   (missing-larkc 30512))
                 (sub-mt
                   ;; Likely extracts the mt from an ist sentence — missing-larkc 30490
                   (missing-larkc 30490)))
             (convert-to-hl-contextualized-asent subsentence sub-mt)))
          ((true-sentence-of-atomic-sentence-p asent)
           (let ((subsentence (sentence-arg1 asent)))
             (convert-to-hl-contextualized-asent subsentence mt)))
          ((and (eq #$elementOf (atomic-sentence-predicate asent))
                (pattern-matches-formula-without-bindings
                 '(#$elementOf :variable (#$TheSetOf :anything (#$isa :anything :anything)))
                 asent))
           (let* ((hl-var (atomic-sentence-arg1 asent))
                  (el-var-1 (atomic-sentence-arg1 (atomic-sentence-arg2 asent)))
                  (isa-asent (atomic-sentence-arg2 (atomic-sentence-arg2 asent)))
                  (el-var-2 (atomic-sentence-arg1 isa-asent))
                  (collection (atomic-sentence-arg2 isa-asent)))
             (when (and (hl-variable-p hl-var)
                        (el-variable-p el-var-1)
                        (el-variable-p el-var-2)
                        (eq el-var-1 el-var-2))
               (convert-to-hl-contextualized-asent (list #$isa hl-var collection) mt))))
          (t contextualized-asent))))

(defun inference-sort-clauses-and-literals (contextualized-dnf-clauses)
  "[Cyc] Treats variables as opaque.  Destructive."
  (if (singleton? contextualized-dnf-clauses)
      (let* ((contextualized-dnf-clause (first contextualized-dnf-clauses))
             (sorted-contextualized-dnf-clause (inference-sort-contextualized-clause-literals contextualized-dnf-clause)))
        (list sorted-contextualized-dnf-clause))
      (let ((sorted-contextualized-dnf-clauses nil))
        (dolist (contextualized-dnf-clause contextualized-dnf-clauses)
          (push (inference-sort-contextualized-clause-literals contextualized-dnf-clause)
                sorted-contextualized-dnf-clauses))
        ;; Likely sorts the clauses — missing-larkc 35651
        (missing-larkc 35651))))

(defun inference-sort-contextualized-clause-literals (contextualized-clause)
  (let* ((neg-lits (contextualized-neg-lits contextualized-clause))
         (pos-lits (contextualized-pos-lits contextualized-clause))
         (new-neg-lits (inference-sort-contextualized-literals neg-lits))
         (new-pos-lits (inference-sort-contextualized-literals pos-lits)))
    (if (and (eq neg-lits new-neg-lits)
             (eq pos-lits new-pos-lits))
        contextualized-clause
        (make-clause new-neg-lits new-pos-lits))))

;; (defun inference-sort-contextualized-clauses (contextualized-clauses) ...) -- active declareFunction, no body

(defun inference-sort-contextualized-literals (literals)
  (inference-awesome-sort-contextualized-literals literals))

(defun inference-simple-sort-contextualized-literals (literals)
  (sort literals #'inference-contextualized-asent-<))

;; (defun inference-clause-< (clause1 clause2) ...) -- active declareFunction, no body

(defun inference-contextualized-asent-< (asent1 asent2)
  (inference-list-< asent1 asent2))

(defun inference-list-< (list1 list2)
  (inference-formula-< list1 list2))

(defun inference-formula-< (formula1 formula2)
  (cond ((formula-arity< formula1 formula2) t)
        ((formula-arity> formula1 formula2) nil)
        (t
         (let ((seqvar1? (formula-with-sequence-term? formula1))
               (seqvar2? (formula-with-sequence-term? formula2)))
           (cond ((and (not seqvar1?) seqvar2?) t)
                 ((and seqvar1? (not seqvar2?)) nil)
                 (t
                  (do* ((terms1 (formula-terms formula1) (rest terms1))
                        (terms2 (formula-terms formula2) (rest terms2))
                        (term1 (first terms1) (first terms1))
                        (term2 (first terms2) (first terms2)))
                       ((and (null terms1) (null terms2)) nil)
                    (cond ((inference-term-< term1 term2) (return t))
                          ((inference-term-> term1 term2) (return nil))))))))))

(defun inference-term-< (term1 term2)
  (when (not (eq term1 term2))
    (let ((type-code-1 (inference-term-type-code term1))
          (type-code-2 (inference-term-type-code term2)))
      (cond ((< type-code-1 type-code-2) t)
            ((> type-code-1 type-code-2) nil)
            ((constant-p term1)
             (inference-constant-< term1 term2))
            ((nart-p term1)
             ;; Likely compares NARTs — missing-larkc 35650
             (missing-larkc 35650))
            ((fixed-variable-p term1)
             (< (fixed-variable-id term1) (fixed-variable-id term2)))
            ((variable-p term1)
             (if *inference-sort-principled?*
                 nil
                 (< (variable-id term1) (variable-id term2))))
            ((el-var? term1) nil)
            ((permissible-keyword-var? term1) nil)
            ((el-formula-p term1)
             (inference-formula-< term1 term2))
            ((numberp term1)
             (< term1 term2))
            ((stringp term1)
             (string< term1 term2))
            ((symbolp term1)
             (string< (symbol-name term1) (symbol-name term2)))
            ((characterp term1)
             (char< term1 term2))
            ((assertion-p term1)
             (inference-term-< (assertion-hl-formula term1) (assertion-hl-formula term2)))
            (t
             (error "The type of object ~a cannot be sorted" term1))))))

(defun inference-term-> (term1 term2)
  (inference-term-< term2 term1))

(defun inference-term-type-code (v-term)
  (cond ((constant-p v-term) 0)
        ((nart-p v-term) 1)
        ((fixed-variable-p v-term) 11)
        ((variable-p v-term) 2)
        ((el-var? v-term) 3)
        ((permissible-keyword-var? v-term) 4)
        ((el-formula-p v-term) 5)
        ((numberp v-term) 6)
        ((stringp v-term) 7)
        ((symbolp v-term) 8)
        ((characterp v-term) 9)
        ((assertion-p v-term) 10)
        (t (error "Got a CycL term of unknown inference type: ~a" v-term))))

(defun inference-constant-< (constant1 constant2)
  (let ((suid1 (constant-suid constant1))
        (suid2 (constant-suid constant2)))
    (< suid1 suid2)))

;; (defun inference-nart-< (nart1 nart2) ...) -- active declareFunction, no body

(defparameter *inference-sort-principled?* t
  "[Cyc] Whether the inference czer sorts in a principled way.  This entails treating
variables as opaque tokens.")

(defparameter *inference-czer-fixed-vars-table* (uninitialized))

(defparameter *inference-czer-next-fixed-var-id* (uninitialized))

(defun non-fixed-variable-p (object)
  "[Cyc] An HL variable that is not a member of *inference-czer-fixed-vars-table*"
  (and (alist-p *inference-czer-fixed-vars-table*)
       (hl-variable-p object)
       (not (alist-has-key? *inference-czer-fixed-vars-table* object #'eq))))

(defun fixed-variable-p (object)
  "[Cyc] An HL variable that is a member of *inference-czer-fixed-vars-table*"
  (and (alist-p *inference-czer-fixed-vars-table*)
       (hl-variable-p object)
       (alist-has-key? *inference-czer-fixed-vars-table* object #'eq)))

(defun fully-fixed-p (tree)
  (not (tree-find-if #'non-fixed-variable-p tree)))

(defun fixed-variable-id (fixed-var)
  (alist-lookup-without-values *inference-czer-fixed-vars-table* fixed-var #'eq))

;; (defun fixed-variable-token (fixed-var) ...) -- active declareFunction, no body
;; (defun fixed-variable-token-p (object) ...) -- active declareFunction, no body
;; (defun fixed-variable-for-token (token) ...) -- active declareFunction, no body

(defparameter *inference-czer-at-least-partially-commutative-relations-alist* (uninitialized))

(defun inference-czer-at-least-partially-commutative-relation-p (pred)
  (let* ((result? nil)
         (cached-result (alist-lookup-without-values *inference-czer-at-least-partially-commutative-relations-alist*
                                                     pred #'eq :cache-miss)))
    (if (eq :cache-miss cached-result)
        (progn
          (setf result? (or (variable-p pred)
                            (sbhl-cached-predicate-relation-p #$isa pred #$CommutativeRelation)
                            (sbhl-cached-predicate-relation-p #$isa pred #$PartiallyCommutativeRelation)))
          (setf *inference-czer-at-least-partially-commutative-relations-alist*
                (alist-enter *inference-czer-at-least-partially-commutative-relations-alist*
                             pred result? #'eq)))
        (setf result? cached-result))
    result?))

(defun inference-czer-not-at-all-commutative-relation-p (pred)
  (not (inference-czer-at-least-partially-commutative-relation-p pred)))

(defun not-at-all-commutative-contextualized-asent-p (contextualized-asent)
  (let* ((asent (contextualized-asent-asent contextualized-asent))
         (pred (atomic-sentence-predicate asent)))
    (inference-czer-not-at-all-commutative-relation-p pred)))

(defun at-least-partially-commutative-contextualized-asent-p (contextualized-asent)
  (let* ((asent (contextualized-asent-asent contextualized-asent))
         (pred (atomic-sentence-predicate asent)))
    (inference-czer-at-least-partially-commutative-relation-p pred)))

(defun inference-awesome-sort-contextualized-literals (literals)
  (let ((result nil))
    (let ((*inference-czer-fixed-vars-table* nil)
          (*inference-czer-next-fixed-var-id* 0)
          (*inference-czer-at-least-partially-commutative-relations-alist* nil))
      (setf result (inference-awesome-sort-contextualized-literals-iterative nil literals)))
    result))

(defun inference-awesome-sort-contextualized-literals-iterative (already-sorted-literals not-yet-sorted-literals)
  (let ((done? nil)
        (skip-fully-fixed-this-time? nil))
    (while (not done?)
      (if (null not-yet-sorted-literals)
          (setf done? t)
          (multiple-value-bind (new-awesome-literals skip-fully-fixed-next-time?)
              (pick-some-awesome-lits not-yet-sorted-literals skip-fully-fixed-this-time?)
            (setf skip-fully-fixed-this-time? skip-fully-fixed-next-time?)
            (setf already-sorted-literals (nconc already-sorted-literals new-awesome-literals))
            (setf not-yet-sorted-literals (set-difference not-yet-sorted-literals new-awesome-literals :test #'eq))
            (when not-yet-sorted-literals
              (inference-update-fixed-vars-table new-awesome-literals))))))
  already-sorted-literals)

(defun pick-some-awesome-lits (not-yet-sorted-literals skip-fully-fixed?)
  "[Cyc] Result is top-level destructible.  Result is sorted and awesome.
@param SKIP-FULLY-FIXED? booleanp; if we just got some fully fixed literals last time, we won't get any this time."
  (if (singleton? not-yet-sorted-literals)
      (values (copy-list not-yet-sorted-literals) nil)
      (let ((awesome-literals nil)
            (skip-fully-fixed-next-time? nil)
            (principled? t))
        (unless skip-fully-fixed?
          (setf awesome-literals (inference-fully-fixed-literals not-yet-sorted-literals)))
        (if awesome-literals
            (setf skip-fully-fixed-next-time? t)
            (setf awesome-literals (inference-unique-commutative-literals not-yet-sorted-literals)))
        (unless awesome-literals
          (setf awesome-literals (inference-uniquely-constrained-literals not-yet-sorted-literals)))
        (unless awesome-literals
          (setf awesome-literals not-yet-sorted-literals)
          (setf principled? nil))
        (let ((*inference-sort-principled?* principled?))
          (setf awesome-literals (inference-simple-sort-contextualized-literals awesome-literals)))
        (values awesome-literals skip-fully-fixed-next-time?))))

(defun inference-fully-fixed-literals (not-yet-sorted-literals)
  "[Cyc] Return any literals that are fully fixed.  Fully fixed means fully bound or a fixed variable.
Assumes *inference-czer-fixed-vars-table* is bound."
  (let ((fully-fixed-literals nil))
    (dolist (literal not-yet-sorted-literals)
      (when (and (fully-fixed-p literal)
                 (not-at-all-commutative-contextualized-asent-p literal))
        (push literal fully-fixed-literals)))
    fully-fixed-literals))

(deflexical *variable-token* (if (and (boundp '*variable-token*)
                                       (symbolp *variable-token*))
                                  *variable-token*
                                  (make-symbol "var")))

(defun variable-token (&optional dummy)
  (declare (ignore dummy))
  *variable-token*)

(defun var-tokenized-contextualized-asent-predicate (contextualized-asent)
  (let ((pred (contextualized-asent-predicate contextualized-asent)))
    (if (variable-p pred)
        *variable-token*
        pred)))

(defun inference-unique-commutative-literals (not-yet-sorted-literals)
  "[Cyc] Sort commutative literals by their predicates and fort bags.  This is pretty conservative, especially wrt
partial commutativity, but much better than nothing."
  (let ((commutative-literals-alist nil))
    (dolist (literal not-yet-sorted-literals)
      (when (at-least-partially-commutative-contextualized-asent-p literal)
        (setf commutative-literals-alist
              (alist-push commutative-literals-alist
                          (var-tokenized-contextualized-asent-predicate literal)
                          literal #'eq))))
    (when (null commutative-literals-alist)
      (return-from inference-unique-commutative-literals nil))
    (let ((unique-commutative-literals nil))
      (dolist (cons commutative-literals-alist)
        (destructuring-bind (key . literals) cons
          (declare (ignore key))
          (when (singleton? literals)
            (push (only-one literals) unique-commutative-literals))))
      (when (null unique-commutative-literals)
        (let ((fort-id-alist nil))
          (dolist (cons commutative-literals-alist)
            (destructuring-bind (key . literals) cons
              (declare (ignore key))
              (dolist (literal literals)
                (setf fort-id-alist
                      (alist-push fort-id-alist
                                  ;; Likely computes a fort-id-bag for the literal — missing-larkc 29840
                                  (missing-larkc 29840)
                                  literal #'equal)))))
          (dolist (cons fort-id-alist)
            (destructuring-bind (key . literals) cons
              (declare (ignore key))
              (when (singleton? literals)
                (push (only-one literals) unique-commutative-literals))))))
      unique-commutative-literals)))

(defun inference-uniquely-constrained-literals (not-yet-sorted-literals)
  "[Cyc] Returns literals with not-at-all-commutative predicates that appear uniquely in NOT-YET-SORTED-LITERALS
assuming that all non-fixed variables are considered to be equal.
Assumes *inference-czer-fixed-vars-table* is bound."
  (let ((uniquely-constrained-literals nil)
        (alist nil))
    (dolist (literal not-yet-sorted-literals)
      (when (not-at-all-commutative-contextualized-asent-p literal)
        (let* ((dwimmed-literal (transform literal #'non-fixed-variable-p #'variable-token))
               (alist-entry (assoc dwimmed-literal alist :test #'equal)))
          (if alist-entry
              (rplacd alist-entry :not-unique)
              (let ((new-alist-entry (cons dwimmed-literal literal)))
                (push new-alist-entry alist))))))
    (dolist (cons alist)
      (destructuring-bind (key . literal) cons
        (declare (ignore key))
        (unless (eq :not-unique literal)
          (push literal uniquely-constrained-literals))))
    uniquely-constrained-literals))

(defun inference-update-fixed-vars-table (new-uniquely-constrained-literals)
  "[Cyc] Assumes *inference-czer-fixed-vars-table* is bound"
  (dolist (var (tree-gather new-uniquely-constrained-literals #'variable-p :test #'eq))
    (when (non-fixed-variable-p var)
      (setf *inference-czer-fixed-vars-table*
            (alist-enter *inference-czer-fixed-vars-table* var *inference-czer-next-fixed-var-id* #'eq))
      (setf *inference-czer-next-fixed-var-id*
            (+ *inference-czer-next-fixed-var-id* 1))))
  nil)

(defun contiguize-hl-vars-in-clauses (contextualized-dnf-clauses)
  "[Cyc] Destructive"
  (if (hl-ground-tree-p contextualized-dnf-clauses)
      (values contextualized-dnf-clauses nil)
      (multiple-value-bind (all-good? largest-hl-var-num)
          (all-hl-vars-contiguous-and-in-order? contextualized-dnf-clauses)
        (if all-good?
            (values contextualized-dnf-clauses (identity-variable-map largest-hl-var-num))
            (let ((hl-var-blist (hl-var-contiguity-alist contextualized-dnf-clauses)))
              (values (napply-bindings hl-var-blist contextualized-dnf-clauses)
                      (invert-bindings hl-var-blist)))))))

(defun identity-variable-map (largest-var-num)
  (hl-identity-bindings (1+ largest-var-num)))

(defparameter *largest-hl-var-num-so-far* :lambda
  "[Cyc] lambda used in @xref non-contiguous-hl-var? and possibly-note-hl-var-contiguity-pair")

(defun non-contiguous-hl-var? (object)
  (when (hl-variable-p object)
    (let ((var-num (variable-id object)))
      (cond ((<= var-num *largest-hl-var-num-so-far*) nil)
            ((= var-num (1+ *largest-hl-var-num-so-far*))
             (setf *largest-hl-var-num-so-far* var-num)
             nil)
            (t t)))))

(defun all-hl-vars-contiguous-and-in-order? (contextualized-dnf-clauses)
  (let ((result nil)
        (largest-num nil))
    (let ((*largest-hl-var-num-so-far* -1))
      (setf result (not (tree-find-if #'non-contiguous-hl-var? contextualized-dnf-clauses)))
      (setf largest-num *largest-hl-var-num-so-far*))
    (values result largest-num)))

(defparameter *hl-var-contiguity-alist* :lambda
  "[Cyc] lambda used in @xref possibly-note-hl-var-contiguity-pair")

(defun possibly-note-hl-var-contiguity-pair (object)
  (when (hl-variable-p object)
    (let ((new-var-cons (assoc object *hl-var-contiguity-alist*)))
      (when (null new-var-cons)
        (let* ((next-var-num (1+ *largest-hl-var-num-so-far*))
               (next-var (get-variable next-var-num)))
          (setf *largest-hl-var-num-so-far* next-var-num)
          (push (cons object next-var) *hl-var-contiguity-alist*)))))
  nil)

(defun hl-var-contiguity-alist (contextualized-dnf-clauses)
  "[Cyc] A mapping from old to new.  Will be flipped later."
  (let ((result nil))
    (let ((*largest-hl-var-num-so-far* -1)
          (*hl-var-contiguity-alist* nil))
      (tree-find-if #'possibly-note-hl-var-contiguity-pair contextualized-dnf-clauses)
      (setf result (nreverse *hl-var-contiguity-alist*)))
    result))

;; (defun inference-apply-disjunction-free-el-vars-policy (disjunction-free-el-vars-policy el-vars1 el-vars2) ...) -- active declareFunction, no body

;; inference-canonicalize-ask-memoized-internal and inference-canonicalize-ask-memoized
;; form a memoized pair with note_memoized_function in setup.
(defun-memoized inference-canonicalize-ask-memoized (cycl-query mt disjunction-free-el-vars-policy)
    (:test equal)
  (inference-canonicalize-ask-int cycl-query mt disjunction-free-el-vars-policy))

(defun inference-canonicalize-ask-int (cycl-query mt disjunction-free-el-vars-policy)
  "[Cyc] Computes the hl-query based on CYCL-QUERY and MT
This is only used for the initial input to the inference
@return 0 :ill-formed, problem-query-p, or cycl-truth-value-p
@return 1 binding-list-p; EL vars -> HL vars
@return 2 listp; a list of free EL vars"
  (let ((czer-result nil))
    (unless mt
      (setf mt *mt*))
    (let ((*create-narts-regardless-of-whether-within-assert?* t))
      (multiple-value-bind (czer-result-4 mt-5)
          (canonicalize-ask-sentence cycl-query mt)
        (setf czer-result czer-result-4)
        (setf mt mt-5)))
    (cond ((null czer-result)
           (values :ill-formed nil nil))
          ((cycl-truth-value-p czer-result)
           (values czer-result nil nil))
          ((consp czer-result)
           (let ((contextualized-clauses nil))
             (multiple-value-bind (v-clauses blist free-el-vars)
                 (inference-standardize-canonicalize-ask-result czer-result disjunction-free-el-vars-policy cycl-query)
               (if (eq :ill-formed v-clauses)
                   (values :ill-formed nil nil)
                   (progn
                     (dolist (clause v-clauses)
                       (let ((contextualized-clause (contextualize-clause clause mt disjunction-free-el-vars-policy)))
                         (push contextualized-clause contextualized-clauses)))
                     (values contextualized-clauses blist free-el-vars))))))
          (t (error "Got a czer-result of unexpected type: ~s" czer-result)))))

(defun inference-standardize-canonicalize-ask-result (czer-result disjunction-free-el-vars-policy cycl-query)
  (let ((v-clauses nil)
        (master-el-to-hl-variable-map nil)
        (all-free-el-vars nil))
    (if (singleton? czer-result)
        (destructuring-bind (tuple) czer-result
          (destructuring-bind (clause el-to-hl-variable-map free-el-vars) tuple
            (setf v-clauses (list clause))
            (setf master-el-to-hl-variable-map el-to-hl-variable-map)
            (setf all-free-el-vars free-el-vars)))
        (progn
          (multiple-value-bind (master-el-to-hl-variable-map-8 all-free-el-vars-9)
              ;; Likely computes a master el-to-hl variable map — missing-larkc 35649
              (missing-larkc 35649)
            (setf master-el-to-hl-variable-map master-el-to-hl-variable-map-8)
            (setf all-free-el-vars all-free-el-vars-9))
          (when (eq master-el-to-hl-variable-map :ill-formed)
            (return-from inference-standardize-canonicalize-ask-result
              (values :ill-formed nil nil)))
          (dolist (tuple czer-result)
            (destructuring-bind (local-hl-clause local-el-to-hl-variable-map local-free-el-vars) tuple
              (declare (ignore local-free-el-vars))
              (let* ((master-el-clause (apply-bindings-backwards local-el-to-hl-variable-map local-hl-clause))
                     (master-hl-clause (apply-bindings master-el-to-hl-variable-map master-el-clause)))
                (push master-hl-clause v-clauses))))
          (setf v-clauses (nreverse v-clauses))))
    (setf all-free-el-vars (canonicalize-free-el-var-ordering all-free-el-vars cycl-query))
    (setf master-el-to-hl-variable-map (stable-sort-bindings master-el-to-hl-variable-map all-free-el-vars))
    (values v-clauses master-el-to-hl-variable-map all-free-el-vars)))

;; (defun inference-master-el-to-hl-variable-map (czer-result disjunction-free-el-vars-policy) ...) -- active declareFunction, no body
;; (defun inference-sort-el-variables (el-vars) ...) -- active declareFunction, no body

(defun canonicalize-free-el-var-ordering (free-el-vars cycl-query)
  "[Cyc] Sort FREE-EL-VARS based on the apperance order of EL variables in CYCL-QUERY."
  (let* ((all-el-vars-in-appearance-order (tree-gather cycl-query #'el-variable-p))
         (free-el-vars-in-appearance-order (sort-via-position free-el-vars all-el-vars-in-appearance-order)))
    free-el-vars-in-appearance-order))

;; (defun decontextualize-clauses-with-best-mt (contextualized-clauses) ...) -- active declareFunction, no body
;; (defun decontextualize-clauses (contextualized-clauses mt) ...) -- active declareFunction, no body
;; (defun decontextualize-clause (contextualized-clause mt) ...) -- active declareFunction, no body
;; (defun contextualize-clauses (clauses mt &optional disjunction-free-el-vars-policy) ...) -- active declareFunction, no body

(defun dnf-and-mt-to-hl-query (dnf-clause mt)
  "[Cyc] @return problem-query-p"
  (list (contextualize-clause dnf-clause mt)))

(defun contextualize-clause (clause mt &optional (disjunction-free-el-vars-policy
                                                   *default-inference-disjunction-free-el-vars-policy*))
  (let* ((contextualized-neg-lits (convert-to-hl-contextualized-asents (neg-lits clause) mt))
         (contextualized-pos-lits (convert-to-hl-contextualized-asents (pos-lits clause) mt))
         (contextualized-clause (make-clause contextualized-neg-lits contextualized-pos-lits)))
    (canonicalize-contextualized-clause contextualized-clause disjunction-free-el-vars-policy)))

(defun canonicalize-contextualized-clause (contextualized-clause &optional (disjunction-free-el-vars-policy
                                                                             *default-inference-disjunction-free-el-vars-policy*))
  (if (not (and (atomic-clause-p contextualized-clause)
                (cyc-const-sentential-relation-p
                 (atomic-sentence-predicate
                  (contextualized-asent-asent
                   (atomic-clause-asent contextualized-clause))))))
      contextualized-clause
      (let* ((not-really-asent (atomic-clause-asent contextualized-clause))
             (subsentence (contextualized-asent-asent not-really-asent))
             (sub-mt (contextualized-asent-mt not-really-asent))
             (contextualized-clauses (inference-canonicalize-ask-memoized subsentence sub-mt disjunction-free-el-vars-policy)))
        (must (singleton? contextualized-clauses)
              "Something weird happened when trying to distribute #$ist across logical operators with ~s"
              contextualized-clause)
        (first contextualized-clauses))))

(defun convert-to-hl-contextualized-asents (asents mt)
  (let ((contextualized-asents nil))
    (dolist (asent asents)
      (let ((contextualized-asent (convert-to-hl-contextualized-asent asent mt)))
        (push contextualized-asent contextualized-asents)))
    (setf contextualized-asents (nreverse contextualized-asents))
    contextualized-asents))

(defun convert-to-hl-contextualized-asent (asent mt)
  "[Cyc] @return hl-contextualized-asent-p"
  (when (cyc-var? asent)
    (setf asent (make-unary-formula #$trueSentence asent)))
  (let ((contextualized-asent (make-contextualized-asent mt asent)))
    (inference-simplify-contextualized-asent contextualized-asent)))

;; (defun find-problem-by-el-query (store el-query &optional mt) ...) -- active declareFunction, no body
;; (defun problem-query-el-formula (problem-query) ...) -- active declareFunction, no body
;; (defun problem-query-formula (problem-query) ...) -- active declareFunction, no body
;; (defun contextualized-dnf-clauses-formula (contextualized-dnf-clauses &optional clause-level-mt) ...) -- active declareFunction, no body
;; (defun contextualized-cnf-clauses-formula (contextualized-cnf-clauses &optional clause-level-mt) ...) -- active declareFunction, no body

(defun contextualized-dnf-clause-formula (contextualized-dnf-clause &optional (clause-level-mt :unspecified))
  "[Cyc] Uncanonicalize CONTEXTUALIZED-DNF-CLAUSE into an equivalent CycL sentence.
@return el-sentence-p"
  (contextualized-clause-formula contextualized-dnf-clause clause-level-mt :dnf))

;; (defun contextualized-cnf-clause-formula (contextualized-cnf-clause &optional clause-level-mt) ...) -- active declareFunction, no body

;; (defun contextualized-dnf-clauses-common-mt (contextualized-dnf-clauses) ...) -- active declareFunction, no body

(defun contextualized-dnf-clause-common-mt (contextualized-dnf-clause)
  "[Cyc] Return the shared MT for CONTEXTUALIZED-DNF-CLAUSE if there is one, otherwise #$BaseKB.  Be conservative."
  (let ((formula (contextualized-dnf-clause-formula contextualized-dnf-clause)))
    (if (and (ist-sentence-p formula)
             (not (expression-find-if #'ist-sentence-with-chlmt-p (formula-arg2 formula))))
        (formula-arg1 formula)
        *core-mt-floor*)))

(defun contextualized-clause-formula (contextualized-clause clause-level-mt type)
  "[Cyc] Uncanonicalize CONTEXTUALIZED-CLAUSE into an equivalent CycL sentence.
@param TYPE keywordp; either :DNF or :CNF.
@return el-sentence-p"
  (let ((contextualized-neg-lits (contextualized-neg-lits contextualized-clause))
        (contextualized-pos-lits (contextualized-pos-lits contextualized-clause)))
    (cond ((and (null contextualized-neg-lits)
                (null contextualized-pos-lits))
           #$True)
          ((and (null contextualized-neg-lits)
                (singleton? contextualized-pos-lits))
           (contextualized-asent-formula (first contextualized-pos-lits) clause-level-mt))
          ((and (null contextualized-pos-lits)
                (singleton? contextualized-neg-lits))
           ;; Likely returns a negated formula — missing-larkc 35635
           (missing-larkc 35635))
          ((eq type :dnf)
           (contextualized-clause-conjunction-formula contextualized-clause clause-level-mt))
          ((eq type :cnf)
           ;; Likely returns a disjunction formula — missing-larkc 35638
           (missing-larkc 35638)))))

(defun contextualized-neg-lits (contextualized-clause)
  (neg-lits contextualized-clause))

(defun contextualized-pos-lits (contextualized-clause)
  (pos-lits contextualized-clause))

(defun contextualized-asent-formula (contextualized-asent &optional (clause-level-mt :unspecified))
  "[Cyc] @return EL-FORMULA-P; A decontextualized version of CONTEXTUALIZED-ASENT, assuming CLAUSE-LEVEL-MT
if specified."
  (destructuring-bind (mt asent) contextualized-asent
    (if (equal mt clause-level-mt)
        asent
        (make-binary-formula #$ist mt asent))))

;; (defun contextualized-asent-negated-formula (contextualized-asent &optional clause-level-mt) ...) -- active declareFunction, no body
;; (defun contextualized-dnf-clauses-disjunction-formula (contextualized-dnf-clauses &optional clause-level-mt) ...) -- active declareFunction, no body
;; (defun contextualized-cnf-clauses-conjunction-formula (contextualized-cnf-clauses &optional clause-level-mt) ...) -- active declareFunction, no body

(defun contextualized-clause-conjunction-formula (contextualized-clause &optional (clause-level-mt :unspecified))
  "[Cyc] @param CONTEXTUALIZED-CLAUSE clause-p; a logical conjunction.
@return EL-SENTENCE-P representation of CONTEXTUALIZED-CLAUSE assuming CLAUSE-LEVEL-MT."
  (contextualized-clause-juncts-formula contextualized-clause clause-level-mt :conjunction))

;; (defun contextualized-clause-disjunction-formula (contextualized-clause &optional clause-level-mt) ...) -- active declareFunction, no body

(defun contextualized-clause-juncts-formula (contextualized-clause clause-level-mt type)
  (let ((neg-lit-formulas nil)
        (pos-lit-formulas nil)
        (add-ist-wrapper? (not (hlmt-p clause-level-mt))))
    (when add-ist-wrapper?
      (setf clause-level-mt (determine-best-clause-level-mt contextualized-clause)))
    (dolist (contextualized-asent (neg-lits contextualized-clause))
      ;; sense is always :neg here, so neg-lit-formulas path is always taken
      (push
       ;; Likely negated formula — missing-larkc 35636
       (missing-larkc 35636)
       neg-lit-formulas))
    (dolist (contextualized-asent (pos-lits contextualized-clause))
      ;; sense is always :pos here, so pos-lit-formulas path is always taken
      (push (contextualized-asent-formula contextualized-asent clause-level-mt)
            pos-lit-formulas))
    (setf neg-lit-formulas (nreverse neg-lit-formulas))
    (setf pos-lit-formulas (nreverse pos-lit-formulas))
    (let* ((juncts (nconc neg-lit-formulas pos-lit-formulas))
           (decontextualized-formula (if (eq type :conjunction)
                                         (make-conjunction juncts)
                                         (make-disjunction juncts))))
      (if add-ist-wrapper?
          (make-binary-formula #$ist clause-level-mt decontextualized-formula)
          decontextualized-formula))))

(defun determine-best-clause-level-mt (contextualized-clause)
  (determine-best-clauses-level-mt (list contextualized-clause)))

(defun determine-best-clauses-level-mt (contextualized-clauses)
  (let ((frequency-map nil))
    (dolist (contextualized-clause contextualized-clauses)
      (dolist (contextualized-asent (neg-lits contextualized-clause))
        (destructuring-bind (mt asent) contextualized-asent
          (declare (ignore asent))
          (let ((total-data (assoc mt frequency-map :test #'equal)))
            (unless total-data
              (setf total-data (cons mt 0))
              (push total-data frequency-map))
            (rplacd total-data (+ (cdr total-data) 1)))))
      (dolist (contextualized-asent (pos-lits contextualized-clause))
        (destructuring-bind (mt asent) contextualized-asent
          (declare (ignore asent))
          (let ((total-data (assoc mt frequency-map :test #'equal)))
            (unless total-data
              (setf total-data (cons mt 0))
              (push total-data frequency-map))
            (rplacd total-data (+ (cdr total-data) 1))))))
    (setf frequency-map (nreverse frequency-map))
    (setf frequency-map (stable-sort frequency-map #'> :key #'cdr))
    (first (first frequency-map))))

;; (defun canonicalize-hypothesis (sentence mt) ...) -- active declareFunction, no body
;; (defun canonicalize-hypothesis-recursive (sentence mt) ...) -- active declareFunction, no body
;; (defun categorize-hypothesis-formulas (formulas) ...) -- active declareFunction, no body
;; (defun canonicalize-hypothetical-ask (sentence &optional mt) ...) -- active declareFunction, no body

(toplevel
  (declare-defglobal '*variable-token*))
