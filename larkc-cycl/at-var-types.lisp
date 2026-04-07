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

;;; Variables from init section

(deflexical *at-var-type-dnfs-int-cached-caching-state* nil)
(defparameter *at-true-sentence-negation-preds* :uninitialized)
(deflexical *at-argn-int-cached-caching-state* nil)

;;; Functions ordered per declare_at_var_types_file().

;; (defun term-var-types-ok-int? (term mt) ...) -- 2 required, 0 optional, commented declareFunction, no body

(defun formula-var-types-ok-int? (formula mt)
  "[Cyc] Return T iff the variable types in FORMULA are ok."
  (multiple-value-bind (cnfs new-mt) (at-var-type-cnfs-int formula mt t t)
    (and cnfs
         (independent-cnfs-variables-arg-constraints-ok? cnfs new-mt #'el-var?))))

;; (defun inter-formula-var-types-ok? (formula mt) ...) -- 2 required, 0 optional, commented declareFunction, no body
;; (defun inter-formula-var-types-ok-int? (formula mt var? var-types-ok-fn) ...) -- 4 required, 0 optional, commented declareFunction, no body

(defun independent-cnfs-variables-arg-constraints-ok? (cnfs mt &optional (var? #'cyc-var?))
  "[Cyc] Check that the arg constraints on variables in CNFS are ok."
  (let ((ans nil)
        (formula (unexpanded-formula)))
    (if (and *validating-expansion?*
             (genls-lit? formula)
             (sdc? (formula-arg1 formula) (formula-arg2 formula)))
        (let ((*ignoring-sdc?* t))
          (setf ans (independent-cnfs-variables-arg-constraints-ok?-int cnfs mt var?)))
        (setf ans (independent-cnfs-variables-arg-constraints-ok?-int cnfs mt var?)))
    ans))

(defun independent-cnfs-variables-arg-constraints-ok?-int (cnfs mt &optional (var? #'cyc-var?))
  "[Cyc] Implementation of independent-cnfs-variables-arg-constraints-ok?."
  (let ((ok? t)
        (skolem-cnfs nil)
        (done? nil))
    (csome (cnf cnfs done?)
      (if (tree-find-if #'unreified-skolem-term? cnf)
          (push cnf skolem-cnfs)
          (progn
            (setf ok? (and (cnf-variables-arg-constraints-ok? cnf mt var?) ok?))
            (setf done? (at-finished? (not ok?))))))
    (unless done?
      (csome (skolem (tree-gather skolem-cnfs #'unreified-skolem-term? #'equal #'identity nil) done?)
        (let ((cnfs-of-skolem nil))
          (dolist (cnf skolem-cnfs)
            (when (tree-find skolem cnf #'equal)
              (push cnf cnfs-of-skolem)))
          (unless done?
            ;; missing-larkc 30255 likely returns dependent-cnfs derived from the skolem,
            ;; used to gather additional cnfs that depend on this skolem term.
            (csome (dependent-cnfs-of-skolem (missing-larkc 30255) done?)
              ;; missing-larkc 11707 likely checks constraints on the dependent cnf involving the skolem.
              (setf ok? (and (missing-larkc 11707) ok?))
              (setf done? (at-finished? (not ok?))))))))
    ok?))

;; (defun at-var-type-dnfs (sentence mt include-syntax?) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun clear-at-var-type-dnfs-int-cached () ...) -- 0 required, 0 optional, commented declareFunction, no body
;; (defun remove-at-var-type-dnfs-int-cached (sentence mt) ...) -- 2 required, 0 optional, commented declareFunction, no body
;; (defun at-var-type-dnfs-int-cached-internal (sentence mt) ...) -- 2 required, 0 optional, commented declareFunction, no body
;; (defun at-var-type-dnfs-int-cached (sentence mt) ...) -- 2 required, 0 optional, commented declareFunction, no body
;; (defun at-var-type-cnfs (sentence mt) ...) -- 2 required, 0 optional, commented declareFunction, no body

(defun at-var-type-cnfs-int (sentence mt assume-syntax-ok? catch-czer-errors?)
  "[Cyc] Return the CNFs for variable type checking of SENTENCE in MT.
May return NIL if there was a czer problem."
  (let ((cnfs nil))
    (let ((*simplify-literal?* nil)
          (*expand-el-relations?* nil)
          (*encapsulate-var-formula?* nil)
          (*encapsulate-intensional-formula?* nil))
      (when (or assume-syntax-ok?
                (el-wff-syntax? sentence))
        (let ((*mt* (if (mt? mt) mt *mt*))
              (*use-cnf-cache?* nil))
          (let ((error nil))
            (if catch-czer-errors?
                (let ((error (catch :bad-exponential-disjunction
                               (multiple-value-setq (cnfs mt)
                                 (at-var-types-cnfs-clausify sentence))
                               nil)))
                  (when error
                    ;; missing-larkc 7216 likely reports the exponential disjunction error to the WFF machinery.
                    (missing-larkc 7216)
                    (setf cnfs nil)))
                (multiple-value-setq (cnfs mt)
                  (at-var-types-cnfs-clausify sentence)))))))
    (setf cnfs (at-var-type-repackage-cnfs cnfs))
    (values cnfs mt)))

(defun at-var-types-cnfs-clausify (sentence)
  "[Cyc] Clausify SENTENCE for variable type checking."
  (let ((cnfs nil)
        (mt nil))
    (let ((*el-symbol-suffix-table* (make-hash-table :test #'eql :size 4))
          (*standardize-variables-memory* nil))
      (multiple-value-setq (cnfs mt)
        (cnf-clausal-form
         (simplify-cycl-sentence
          (simplify-sequence-variables
           (at-transform-true-sentence-negation-preds sentence *mt*)))
         *mt*)))
    (values cnfs mt)))

(defun opaque-arg-wrt-pragmatic-requirement? (formula argnum)
  "[Cyc] Return boolean; t iff arg number ARGNUM of FORMULA is opaque by the
default criteria, or the arg1 of #$pragmaticRequirement."
  (or (default-opaque-arg? formula argnum)
      (and (= 1 argnum)
           (eq #$pragmaticRequirement (formula-operator formula)))))

(defun at-transform-true-sentence-negation-preds (sentence mt)
  "[Cyc] Transform SENTENCE by negating predicates that are negation-preds of #$trueSentence."
  (let ((result nil))
    (let ((*at-true-sentence-negation-preds* (new-set #'eq)))
      (dolist (negation-pred (all-negation-predicates #$trueSentence mt nil))
        (set-add negation-pred *at-true-sentence-negation-preds*))
      (let ((*opaque-arg-function* #'opaque-arg-wrt-pragmatic-requirement?))
        (setf result (expression-transform sentence #'at-negated? #'at-negate))))
    result))

(defun at-negated? (formula)
  "[Cyc] Return T iff FORMULA's operator is a negation predicate of #$trueSentence."
  (let ((operator (formula-arg0 formula)))
    (when (fort-p operator)
      (set-member? operator *at-true-sentence-negation-preds*))))

;; (defun at-negate (formula) ...) -- 1 required, 0 optional, commented declareFunction, no body

(defun at-var-type-repackage-cnfs (cnfs)
  "[Cyc] Repackage CNFS for variable type checking."
  (let ((result nil))
    (when (consp cnfs)
      (dolist (cnf cnfs)
        (let ((neg-lits (neg-lits cnf))
              (pos-lits (pos-lits cnf)))
          (cond
            ((singleton? pos-lits)
             (pushnew cnf result :test #'equal))
            (pos-lits
             (dolist (pos-lit pos-lits)
               (let ((item (make-cnf neg-lits
                                     (list (transform pos-lit
                                                      #'unreified-skolem-term?
                                                      #'skolem-function-var)))))
                 (pushnew item result :test #'equal))))
            (t
             (pushnew (make-cnf neg-lits nil) result :test #'equal))))))
    result))

;; (defun cnf-var-types-ok? (cnf mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun inter-cnf-var-types-ok? (cnf mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun query-var-types-ok? (query mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun term-variables-arg-constraints (term mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun formula-variables-arg-constraints (formula mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun at-el-expand-all (formula mt) ...) -- 2 required, 0 optional, commented declareFunction, no body
;; (defun parse-constraint (constraint var?) ...) -- 2 required, 0 optional, commented declareFunction, no body
;; (defun formula-variables-arg-constraints-dict (formula mt &optional (var? #'cyc-var?) detailed?) ...) -- 2 required, 2 optional, commented declareFunction, no body
;; (defun inter-formula-variables-arg-constraints (formula mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun independent-formula-variables-arg-constraints (formula mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun old-formula-variables-arg-constraints (formula mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun query-variables-arg-constraints (query mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun inter-query-variables-arg-constraints (query mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun cnfs-variables-arg-constraints (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun independent-cnfs-variables-arg-constraints (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun inter-cnfs-variables-arg-constraints (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun inter-cnfs-variables-isa-constraints (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun inter-cnfs-variables-quoted-isa-constraints (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun inter-cnfs-variables-genl-constraints (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun hl-cnf-variables-arg-constraints (cnf mt) ...) -- 2 required, 0 optional, commented declareFunction, no body
;; (defun cnf-variables-arg-constraints (cnf mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun inter-cnfs-variables-arg-constraints-ok? (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun inter-cnfs-variables-arg-constraints-ok?-int (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun cnfs-variables-arg-constraints-ok? (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body

(defun cnf-variables-arg-constraints-ok? (cnf mt &optional (var? #'cyc-var?))
  "[Cyc] Check that the arg constraints on variables in CNF are ok."
  (let ((isa-constraints (cnf-variables-isa-constraints cnf mt var?)))
    (and (var-types-ok? isa-constraints :isa mt)
         (var-types-ok? (cnf-variables-quoted-isa-constraints cnf mt var?) :quoted-isa mt)
         (var-types-ok? (cnf-variables-genl-constraints cnf mt var?) :genls mt)
         (cnf-var-constraint-implications-ok? cnf isa-constraints mt var?))))

;; (defun var-isa-constraints-wrt-cnfs (var cnfs mt &optional (var? #'cyc-var?)) ...) -- 3 required, 1 optional, commented declareFunction, no body
;; (defun var-genl-constraints-wrt-cnfs (var cnfs mt &optional (var? #'cyc-var?)) ...) -- 3 required, 1 optional, commented declareFunction, no body
;; (defun cnfs-variables-isa-constraints (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun cnfs-variables-quoted-isa-constraints (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun cnfs-variables-genl-constraints (cnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun cnfs-variable-isa-constraints (var cnfs mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun cnfs-variable-quoted-isa-constraints (var cnfs mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun cnfs-variable-genl-constraints (var cnfs mt) ...) -- 3 required, 0 optional, commented declareFunction, no body

(defun cnf-variables-isa-constraints (cnf mt &optional (var? #'variable-p))
  "[Cyc] Return the isa constraints on the variables in CNF."
  (let ((pos-lits (pos-lits cnf)))
    (when pos-lits
      (let ((vars (nreverse (tree-gather cnf var?)))
            (result nil)
            (constraints nil))
        (dolist (var vars)
          (when (or *at-check-inter-arg-isa?*
                    (tree-find var pos-lits #'equal))
            (let ((cols (at-min-cols (cnf-variable-isa-constraints var cnf mt) mt)))
              (push (cons var cols) constraints))))
        (if (and constraints
                 *at-check-inter-arg-isa?*)
            (progn
              (dolist (var vars)
                (let ((cols (at-min-cols (cnf-variable-inter-arg-isa-constraints var cnf constraints mt) mt)))
                  (push (cons var cols) result)))
              result)
            (setf result constraints))
        result))))

(defun cnf-variables-quoted-isa-constraints (cnf mt &optional (var? #'variable-p))
  "[Cyc] Return the quoted-isa constraints on the variables in CNF."
  (let ((pos-lits (pos-lits cnf)))
    (when pos-lits
      (let ((vars (nreverse (tree-gather cnf var?)))
            (result nil)
            (constraints nil))
        (dolist (var vars)
          ;; Note: Java has a tree-find test on var in pos-lits but then falls through
          ;; unconditionally to constraints collection
          (let ((cols (at-min-cols (cnf-variable-quoted-isa-constraints var cnf mt) mt)))
            (push (cons var cols) constraints)))
        (setf result constraints)
        result))))

(defun cnf-variables-genl-constraints (cnf mt &optional (var? #'variable-p))
  "[Cyc] Return the genl constraints on the variables in CNF."
  (let ((pos-lits (pos-lits cnf)))
    (when pos-lits
      (let ((vars (nreverse (tree-gather cnf var?)))
            (result nil)
            (constraints nil))
        (dolist (var vars)
          (when (or *at-check-inter-arg-isa?*
                    (tree-find var pos-lits #'equal))
            (let ((cols (at-min-cols (cnf-variable-genl-constraints var cnf mt) mt)))
              (push (cons var cols) constraints))))
        (if (and constraints
                 *at-check-inter-arg-genl?*)
            (progn
              (dolist (var vars)
                ;; missing-larkc 11690 likely returns cnf-variable-inter-arg-genl-constraints
                ;; for this var, analogous to cnf-variable-inter-arg-isa-constraints.
                (let ((cols (at-min-cols (missing-larkc 11690) mt)))
                  (push (cons var cols) result)))
              result)
            (setf result constraints))
        result))))

(defun cnf-variable-isa-constraints (var cnf mt)
  "[Cyc] Return the isa constraints on VAR in CNF."
  (let ((pos-lits (pos-lits cnf))
        (result nil))
    (when pos-lits
      (let ((*at-arg* var))
        (let ((neg-lits (neg-lits cnf))
              (free-vars (clause-free-variables cnf (variable-predicate-fn var))))
          (let ((*within-disjunction?* (or (and neg-lits pos-lits)
                                           (second neg-lits))))
            (when (or (tree-find var pos-lits #'equal)
                      (not (member? var free-vars)))
              (dolist (literal neg-lits)
                (setf result (nconc result (cnf-neg-lit-variable-isa-constraints var literal mt))))
              (dolist (literal pos-lits)
                (when (mt-designating-literal? literal)
                  (let ((predicate (literal-predicate literal))
                        ;; missing-larkc 30470 likely returns the mt argument from the mt-designating literal
                        (mt-arg (missing-larkc 30470))
                        ;; missing-larkc 30492 likely returns the subformula from the mt-designating literal
                        (subformula (missing-larkc 30492)))
                    (declare (ignore predicate subformula))
                    (let ((lit-mt (if (mt? mt-arg) mt-arg mt)))
                      (declare (ignore lit-mt))
                      (when (or (not (within-ask?))
                                (mt? mt-arg))
                        ;; missing-larkc 11758 likely returns isa constraints on var
                        ;; in the mt-designated subformula within lit-mt.
                        (setf result (nconc result (missing-larkc 11758)))))))
                (setf result (nconc result (cnf-pos-lit-variable-isa-constraints var literal mt))))
              (setf result (delete-duplicate-forts result)))))))
    result))

(defun cnf-variable-quoted-isa-constraints (var cnf mt)
  "[Cyc] Return the quoted-isa constraints on VAR in CNF."
  (let ((pos-lits (pos-lits cnf))
        (result nil))
    (when pos-lits
      (let ((*at-arg* var))
        (let ((neg-lits (neg-lits cnf))
              (free-vars (clause-free-variables cnf (variable-predicate-fn var))))
          (let ((*within-disjunction?* (or (and neg-lits pos-lits)
                                           (second neg-lits))))
            (when (or (tree-find var pos-lits #'equal)
                      (not (member? var free-vars)))
              (dolist (literal neg-lits)
                (setf result (nconc result (cnf-neg-lit-variable-quoted-isa-constraints var literal mt))))
              (dolist (literal pos-lits)
                (when (mt-designating-literal? literal)
                  (let ((predicate (literal-predicate literal))
                        ;; missing-larkc 30471 likely returns the mt argument from the mt-designating literal
                        (mt-arg (missing-larkc 30471))
                        ;; missing-larkc 30493 likely returns the subformula from the mt-designating literal
                        (subformula (missing-larkc 30493)))
                    (declare (ignore predicate subformula))
                    (let ((lit-mt (if (mt? mt-arg) mt-arg mt)))
                      (declare (ignore lit-mt))
                      (when (or (not (within-ask?))
                                (mt? mt-arg))
                        ;; missing-larkc 11762 likely returns quoted-isa constraints on var
                        ;; in the mt-designated subformula within lit-mt.
                        (setf result (nconc result (missing-larkc 11762)))))))
                (setf result (nconc result (cnf-pos-lit-variable-quoted-isa-constraints var literal mt))))
              (setf result (delete-duplicate-forts result)))))))
    result))

(defun cnf-variable-genl-constraints (var cnf mt)
  "[Cyc] Return the genl constraints on VAR in CNF."
  (let ((pos-lits (pos-lits cnf))
        (result nil))
    (when pos-lits
      (let ((*at-arg* var))
        (let ((neg-lits (neg-lits cnf))
              (free-vars (clause-free-variables cnf (variable-predicate-fn var))))
          (let ((*within-disjunction?* (or (and neg-lits pos-lits)
                                           (second neg-lits))))
            (when (or (tree-find var pos-lits #'equal)
                      (not (member? var free-vars)))
              (dolist (literal neg-lits)
                (setf result (nconc result (cnf-neg-lit-variable-genl-constraints var literal mt))))
              (dolist (literal pos-lits)
                (when (mt-designating-literal? literal)
                  (let ((predicate (literal-predicate literal))
                        ;; missing-larkc 30472 likely returns the mt argument from the mt-designating literal
                        (mt-arg (missing-larkc 30472))
                        ;; missing-larkc 30494 likely returns the subformula from the mt-designating literal
                        (subformula (missing-larkc 30494)))
                    (declare (ignore predicate subformula))
                    (let ((lit-mt (if (mt? mt-arg) mt-arg mt)))
                      (declare (ignore lit-mt))
                      (when (or (not (within-ask?))
                                (mt? mt-arg))
                        ;; missing-larkc 11745 likely returns genl constraints on var
                        ;; in the mt-designated subformula within lit-mt.
                        (setf result (nconc result (missing-larkc 11745)))))))
                (setf result (nconc result (cnf-pos-lit-variable-genl-constraints var literal mt))))
              (setf result (delete-duplicate-forts result)))))))
    result))

;; (defun cnfs-variable-inter-arg-isa-constraints (var cnfs constraints mt) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun cnfs-variable-inter-arg-genl-constraints (var cnfs constraints mt) ...) -- 4 required, 0 optional, commented declareFunction, no body

(defun cnf-variable-inter-arg-isa-constraints (var cnf constraints mt)
  "[Cyc] Return the inter-arg-isa constraints on VAR in CNF.
Destroys CONSTRAINTS."
  (let ((result (rest (assoc var constraints))))
    (let ((*at-arg* var)
          (*at-var-isa* constraints))
      (setf result (nconc result (cnf-variable-inter-arg-isa-constraints-int var cnf mt))))
    (setf result (delete-duplicate-forts result))
    result))

;; (defun cnf-variable-inter-arg-genl-constraints (var cnf constraints mt) ...) -- 4 required, 0 optional, commented declareFunction, no body

(defun cnf-variable-inter-arg-isa-constraints-int (var cnf mt)
  "[Cyc] Implementation of cnf-variable-inter-arg-isa-constraints."
  (when (and (atomic-clause-with-all-var-args? cnf)
             (null *at-var-isa*))
    (return-from cnf-variable-inter-arg-isa-constraints-int nil))
  (let ((pos-lits (pos-lits cnf))
        (result nil))
    (when pos-lits
      (let ((neg-lits (neg-lits cnf))
            (free-vars (clause-free-variables cnf (variable-predicate-fn var))))
        (let ((*within-disjunction?* (or (and neg-lits pos-lits)
                                         (second neg-lits))))
          (when (or (tree-find var pos-lits #'equal)
                    (not (member? var free-vars)))
            (dolist (literal neg-lits)
              (setf result (nconc result (neg-lit-variable-inter-arg-isa-constraints var literal mt))))
            (dolist (literal pos-lits)
              (when (mt-designating-literal? literal)
                (let ((predicate (literal-predicate literal))
                      ;; missing-larkc 30473 likely returns the mt argument from the mt-designating literal
                      (mt-arg (missing-larkc 30473))
                      ;; missing-larkc 30495 likely returns the subformula from the mt-designating literal
                      (subformula (missing-larkc 30495)))
                  (declare (ignore predicate subformula))
                  (let ((lit-mt (if (mt? mt-arg) mt-arg mt)))
                    (declare (ignore lit-mt))
                    (when (or (not (within-ask?))
                              (mt? mt-arg))
                      ;; missing-larkc 11754 likely returns inter-arg-isa constraints on var
                      ;; in the mt-designated subformula within lit-mt.
                      (setf result (nconc result (missing-larkc 11754)))))))
              (setf result (nconc result (pos-lit-variable-inter-arg-isa-constraints var literal mt))))
            (setf result (delete-duplicate-forts result))))))
    result))

;; (defun cnf-variable-inter-arg-genl-constraints-int (var cnf mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun cnfs-var-constraint-implications-ok? (cnfs isa-constraints mt &optional (var? #'cyc-var?)) ...) -- 3 required, 1 optional, commented declareFunction, no body

(defun cnf-var-constraint-implications-ok? (cnf isa-constraints mt &optional (var? #'cyc-var?))
  "[Cyc] Whether the interArgIsa constraints FROM the cnfs' variables TO fully-bound collections are ok.
Returns NIL if a contradiction is found."
  (let ((bad? nil))
    (when (and isa-constraints
               *at-check-inter-arg-isa?*
               (not (atomic-clause-with-all-var-args? cnf)))
      (let ((mt-var (with-inference-mt-relevance-validate mt)))
        (let ((*mt* (update-inference-mt-relevance-mt mt-var))
              (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
              (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
          (do* ((rest (pos-lits cnf) (rest rest))
                (asent (first rest) (first rest)))
               ((or bad? (null rest)))
            (let* ((pred (atomic-sentence-predicate asent))
                   (asserted-genl-something? (when (fort-p pred)
                                               (or (asserted-genl-predicates? pred)
                                                   (asserted-genl-inverses? pred)))))
              (let ((*at-reln* pred)
                    (*at-search-genl-preds?* (and *at-check-genl-preds?*
                                                  asserted-genl-something?))
                    (*at-search-genl-inverses?* (and *at-check-genl-inverses?*
                                                     asserted-genl-something?)))
                (let ((ind-argnum 0))
                  (do* ((rest-2 (formula-args asent :ignore) (rest rest-2))
                        (ind-arg (first rest-2) (first rest-2)))
                       ((or bad? (null rest-2)))
                    (incf ind-argnum)
                    (let ((ind-arg-isas (alist-lookup isa-constraints ind-arg)))
                      (when ind-arg-isas
                        (let ((dep-argnum 0))
                          (do* ((rest-3 (formula-args asent :ignore) (rest rest-3))
                                (dep-arg (first rest-3) (first rest-3)))
                               ((or bad? (null rest-3)))
                            (incf dep-argnum)
                            (when (and (/= ind-argnum dep-argnum)
                                       (ground? dep-arg var?))
                              (let ((dep-constraints nil))
                                (csome (ind-arg-isa ind-arg-isas bad?)
                                  (let ((items (inter-arg-isa-from-type pred dep-argnum ind-arg-isa ind-argnum)))
                                    (if (vectorp items)
                                        (dotimes (i (length items))
                                          (push (aref items i) dep-constraints))
                                        (dolist (item items)
                                          (push item dep-constraints)))))
                                ;; missing-larkc 3715 likely checks if the dep-arg violates
                                ;; the dep-constraints (e.g., dep-arg is disjoint from all constraints).
                                (when (missing-larkc 3715)
                                  ;; missing-larkc 7218 likely reports the constraint violation.
                                  (missing-larkc 7218)
                                  (setf bad? t)))))))))))))))
    (not bad?)))

;; (defun dnfs-variables-arg-constraints (dnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun inter-dnfs-variables-arg-constraints (dnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun dnf-variables-arg-constraints (dnf mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun dnfs-variables-arg-constraints-ok? (dnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun dnfs-variables-isa-constraints (dnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun dnfs-variables-genl-constraints (dnfs mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body

(defun contextualized-dnf-variables-isa-constraint-tuples (dnf &optional (var? #'cyc-var?))
  "[Cyc] Return a list of tuples of the form (VAR MT COLLECTIONS), where VAR is constrained to be all of COLLECTIONS in MT."
  (let ((result nil)
        (constraints nil)
        (vars (nreverse (tree-gather dnf var?))))
    (dolist (var vars)
      (let ((tuples (contextualized-dnf-variable-isa-constraint-tuples var dnf)))
        (if (vectorp tuples)
            (dotimes (i (length tuples))
              (push (aref tuples i) constraints))
            (dolist (item tuples)
              (push item constraints)))))
    (setf result constraints)
    result))

;; (defun var-isa-constraints-wrt-dnfs (var dnfs mt &optional (var? #'cyc-var?)) ...) -- 3 required, 1 optional, commented declareFunction, no body
;; (defun var-genl-constraints-wrt-dnfs (var dnfs mt &optional (var? #'cyc-var?)) ...) -- 3 required, 1 optional, commented declareFunction, no body
;; (defun dnfs-variable-isa-constraints (var dnfs mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun dnfs-variable-quoted-isa-constraints (var dnfs mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun dnfs-variable-genl-constraints (var dnfs mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun dnf-variables-isa-constraints (dnf mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun dnf-variables-quoted-isa-constraints (dnf mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun dnf-variables-genl-constraints (dnf mt &optional (var? #'cyc-var?)) ...) -- 2 required, 1 optional, commented declareFunction, no body
;; (defun dnf-variable-isa-constraints (var dnf mt) ...) -- 3 required, 0 optional, commented declareFunction, no body

(defun contextualized-dnf-variable-isa-constraint-tuples (var contextualized-dnf)
  "[Cyc] Based on dnf-variable-isa-constraints.
Return tuples of (VAR MT COLLECTIONS) for the isa constraints on VAR."
  (let ((pos-lits (pos-lits contextualized-dnf))
        (dict (new-dictionary #'equal)))
    (when pos-lits
      (let ((*at-arg* var))
        (let ((neg-lits (neg-lits contextualized-dnf))
              (free-vars (clause-free-variables contextualized-dnf (variable-predicate-fn var))))
          (let ((*within-disjunction?* (or (and neg-lits pos-lits)
                                           (second neg-lits)
                                           (second pos-lits))))
            (when (or (tree-find var pos-lits #'equal)
                      (not (member? var free-vars)))
              (dolist (contextualized-literal neg-lits)
                (destructuring-bind (mt asent) contextualized-literal
                  ;; missing-larkc 11714 likely returns neg-lit isa constraints for var in asent,
                  ;; analogous to cnf-neg-lit-variable-isa-constraints but for DNF contextualized lits.
                  (dolist (col (missing-larkc 11714))
                    (dictionary-push dict mt col))))
              (dolist (contextualized-literal pos-lits)
                (destructuring-bind (mt asent) contextualized-literal
                  (dolist (col (dnf-pos-lit-variable-isa-constraints var asent mt))
                    (dictionary-push dict mt col))))
              ;; Handle isa-x-y patterns
              (when (find-if #'contextualized-isa-x-y-lit? pos-lits)
                (dolist (isa-x-y-contextualized-asent
                         (remove-if-not #'contextualized-isa-x-y-lit? pos-lits))
                  (destructuring-bind (isa-mt isa-x-y-asent) isa-x-y-contextualized-asent
                    (let ((ins-var (atomic-sentence-arg1 isa-x-y-asent)))
                      (when (eq var ins-var)
                        (let ((isa-col-var (atomic-sentence-arg2 isa-x-y-asent)))
                          (dolist (contextualized-literal pos-lits)
                            (destructuring-bind (genls-mt genls-asent) contextualized-literal
                              (when (genls-lit? genls-asent)
                                (let ((genls-col-var (atomic-sentence-arg1 genls-asent)))
                                  (when (eq isa-col-var genls-col-var)
                                    (when (hlmt-equal? isa-mt genls-mt)
                                      (let ((col (atomic-sentence-arg2 genls-asent)))
                                        (when (fort-p col)
                                          (dictionary-push dict isa-mt col)))))))))))))))))))))
    ;; Convert dictionary to result tuples
    (let ((result nil))
      (do-dictionary (mt cols dict)
        (let ((minimized-cols (at-min-cols cols mt)))
          (push (list var mt minimized-cols) result)))
      result)))

(defun contextualized-isa-x-y-lit? (object)
  "[Cyc] Return T iff OBJECT is a contextualized isa-x-y literal."
  (when (hl-contextualized-asent-p object)
    (let ((asent (contextualized-asent-asent object)))
      (isa-hl-var-hl-var-lit? asent))))

;; (defun dnf-variable-quoted-isa-constraints (var dnf mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun dnf-variable-genl-constraints (var dnf mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun dnfs-variable-inter-arg-isa-constraints (var dnfs constraints mt) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun dnfs-variable-inter-arg-genl-constraints (var dnfs constraints mt) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun dnf-variable-inter-arg-isa-constraints (var dnf constraints mt) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun dnf-variable-inter-arg-genl-constraints (var dnf constraints mt) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun dnf-variable-inter-arg-isa-constraints-int (var dnf mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun dnf-variable-inter-arg-genl-constraints-int (var dnf mt) ...) -- 3 required, 0 optional, commented declareFunction, no body

(defun cnf-neg-lit-variable-isa-constraints (var literal mt)
  "[Cyc] Return the isa constraints on VAR in negative literal LITERAL."
  (if (within-disjunction?)
      (neg-lit-variable-isa-constraints var literal mt)
      nil))

(defun cnf-neg-lit-variable-quoted-isa-constraints (var literal mt)
  "[Cyc] Return the quoted-isa constraints on VAR in negative literal LITERAL."
  (if (within-disjunction?)
      (neg-lit-variable-quoted-isa-constraints var literal mt)
      nil))

(defun cnf-neg-lit-variable-genl-constraints (var literal mt)
  "[Cyc] Return the genl constraints on VAR in negative literal LITERAL."
  (if (within-disjunction?)
      (neg-lit-variable-genl-constraints var literal mt)
      nil))

(defun cnf-pos-lit-variable-isa-constraints (var literal mt)
  "[Cyc] Return the isa constraints on VAR in positive literal LITERAL."
  (neg-lit-variable-isa-constraints var literal mt))

(defun cnf-pos-lit-variable-quoted-isa-constraints (var literal mt)
  "[Cyc] Return the quoted-isa constraints on VAR in positive literal LITERAL."
  (neg-lit-variable-quoted-isa-constraints var literal mt))

(defun cnf-pos-lit-variable-genl-constraints (var literal mt)
  "[Cyc] Return the genl constraints on VAR in positive literal LITERAL."
  (neg-lit-variable-genl-constraints var literal mt))

;; (defun dnf-neg-lit-variable-isa-constraints (var literal mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun dnf-neg-lit-variable-quoted-isa-constraints (var literal mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun dnf-neg-lit-variable-genl-constraints (var literal mt) ...) -- 3 required, 0 optional, commented declareFunction, no body

(defun dnf-pos-lit-variable-isa-constraints (var literal mt)
  "[Cyc] Return the isa constraints on VAR in positive literal LITERAL for DNF."
  (neg-lit-variable-isa-constraints var literal mt))

;; (defun dnf-pos-lit-variable-quoted-isa-constraints (var literal mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun dnf-pos-lit-variable-genl-constraints (var literal mt) ...) -- 3 required, 0 optional, commented declareFunction, no body

(defun vt-unskolemize-term (v-term)
  "[Cyc] Unskolemize a term for variable type checking."
  (if (unreified-skolem-term? v-term)
      ;; missing-larkc 22931 likely returns the skolem function variable for the term,
      ;; i.e., the variable that the skolem function replaces.
      (missing-larkc 22931)
      v-term))

(defun neg-lit-variable-isa-constraints (var literal mt)
  "[Cyc] Return the isa constraints on VAR from literal LITERAL."
  (let ((result (pos-lit-variable-isa-constraints var literal mt)))
    (cond
      ((and *at-include-isa-literal-constraints*
            (isa-lit? literal))
       (let ((arg1 (vt-unskolemize-term (literal-arg1 literal)))
             (arg2 (reify-when-closed-naut (literal-arg2 literal))))
         (cond
           ((not (eq var arg1)))
           ((collection? arg2)
            (push arg2 result))
           ((first-order-naut? arg2)
            (if (ground? arg2)
                ;; missing-larkc 6955 likely returns min-isa of the closed NAUT arg2,
                ;; computing the isa constraints from a ground non-atomic term.
                (setf result (nconc result (missing-larkc 6955)))
                ;; missing-larkc 6959 likely returns isa constraints for an open NAUT arg2.
                (setf result (nconc result (missing-larkc 6959))))))))
      ((or (tou-lit? literal)
           (evaluate-lit? literal))
       (let ((arg1 (vt-unskolemize-term (literal-arg1 literal))))
         (when (eq var arg1)
           ;; missing-larkc 6973 likely returns the isa constraints derived from the
           ;; function applied via termOfUnit or evaluate predicate on arg1.
           (setf result (nconc result (missing-larkc 6973)))))))
    (setf result (delete-duplicate-forts result))
    result))

(defun neg-lit-variable-quoted-isa-constraints (var literal mt)
  "[Cyc] Return the quoted-isa constraints on VAR from literal LITERAL."
  (let ((result (pos-lit-variable-quoted-isa-constraints var literal mt)))
    (cond
      ((and *at-include-isa-literal-constraints*
            (quoted-isa-lit? literal))
       (let ((arg1 (vt-unskolemize-term (literal-arg1 literal)))
             (arg2 (reify-when-closed-naut (literal-arg2 literal))))
         (cond
           ((not (eq var arg1)))
           ((collection? arg2)
            (push arg2 result)))))
      ((or (tou-lit? literal)
           (evaluate-lit? literal))
       (let ((arg1 (vt-unskolemize-term (literal-arg1 literal))))
         (when (eq var arg1)
           (let ((nat-functor (nat-functor (literal-arg2 literal)))
                 ;; missing-larkc 6863 likely returns the quoted-isa constraints from evaluating
                 ;; the function NAT, e.g., evaluation-quoted-isas for the functor.
                 (evaluation-quoted-isas (missing-larkc 6863))
                 ;; missing-larkc 7005 likely returns additional quoted-isa constraints
                 ;; from the NAT functor beyond evaluation constraints.
                 (quoted-isas (missing-larkc 7005)))
             (declare (ignore nat-functor))
             (setf result (nconc result evaluation-quoted-isas quoted-isas)))))))
    (setf result (delete-duplicate-forts result))
    result))

(defun neg-lit-variable-genl-constraints (var literal mt)
  "[Cyc] Return the genl constraints on VAR from literal LITERAL."
  (let ((result (pos-lit-variable-genl-constraints var literal mt)))
    (cond
      ((and *at-include-genl-literal-constraints*
            (genls-lit? literal))
       (let ((arg1 (vt-unskolemize-term (literal-arg1 literal)))
             (arg2 (reify-when-closed-naut (literal-arg2 literal))))
         (cond
           ((not (eq var arg1)))
           ((collection? arg2)
            (push arg2 result))
           ((first-order-naut? arg2)
            ;; missing-larkc 6945 likely returns min-genls of the NAUT arg2,
            ;; computing genl constraints from a non-atomic term.
            (setf result (nconc result (missing-larkc 6945)))))))
      ((or (tou-lit? literal)
           (evaluate-lit? literal))
       (let ((arg1 (vt-unskolemize-term (literal-arg1 literal))))
         (when (eq var arg1)
           ;; missing-larkc 6946 likely returns the genl constraints derived from the
           ;; function applied via termOfUnit or evaluate predicate on arg1.
           (setf result (nconc result (missing-larkc 6946)))))))
    (setf result (delete-duplicate-forts result))
    result))

(defun pos-lit-variable-isa-constraints (var literal mt)
  "[Cyc] Return the isa constraints on VAR from positive literal LITERAL."
  (copy-list (pos-lit-variable-isa-constraints-memoized var literal mt)))

(defun pos-lit-variable-isa-constraints-memoized-internal (var literal mt)
  "[Cyc] Internal implementation for pos-lit-variable-isa-constraints-memoized."
  (let ((predicate (literal-predicate literal))
        (result nil))
    (when (tree-find var literal #'equal)
      (unless (fort-p predicate)
        ;; missing-larkc 29731 likely finds the closed NAUT for a non-fort predicate.
        (setf predicate (missing-larkc 29731)))
      (let ((scoping-args (if (fort-p predicate) (scoping-args predicate mt) nil))
            (argnum 0)
            (mt-var mt))
        (let ((*relevant-mt-function* (possibly-in-mt-determine-function mt-var))
              (*mt* (possibly-in-mt-determine-mt mt-var)))
          (let ((asserted-genl-something? (when (fort-p predicate)
                                            (or (asserted-genl-predicates? predicate)
                                                (asserted-genl-inverses? predicate)))))
            (let ((*at-reln* predicate)
                  (*at-search-genl-preds?* (and *at-check-genl-preds?*
                                                asserted-genl-something?))
                  (*at-search-genl-inverses?* (and *at-check-genl-inverses?*
                                                   asserted-genl-something?)))
              (when (eql var (vt-unskolemize-term predicate))
                (let ((done? nil)
                      (has-sentence-arg? nil))
                  (dolist (arg (formula-args literal :ignore))
                    (unless done?
                      (when (sentence? arg)
                        (setf done? t)
                        (setf has-sentence-arg? t))))
                  (if has-sentence-arg?
                      (push #$TruthFunction result)
                      (push #$Predicate result))))
              (dolist (arg (literal-args literal :regularize))
                (incf argnum)
                (cond
                  ((member? argnum scoping-args))
                  ((fast-cycl-quoted-term-p arg))
                  ((relax-arg-type-constraints-for-variables-for-arg? predicate argnum mt))
                  ((equal var arg)
                   (setf result (nconc result (at-argn-isa predicate argnum))))
                  ((modal-in-arg? predicate argnum mt))
                  ((unreified-skolem-term? arg)
                   ;; missing-larkc 29785 likely returns the skolem function variable for the arg.
                   (when (eql var (missing-larkc 29785))
                     (setf result (at-argn-isa predicate argnum)))
                   ;; missing-larkc 22935 likely returns the skolem number for the arg.
                   (let ((skolem-number (missing-larkc 22935)))
                     (when (tree-find var skolem-number)
                       ;; missing-larkc 11787 likely returns isa constraints from within the skolem structure.
                       (setf result (nconc result (missing-larkc 11787))))))
                  ((sentence-arg? predicate argnum mt)
                   ;; missing-larkc 8768 likely tests whether the sentence arg contains var.
                   (when (missing-larkc 8768)
                     (if (mt-designating-literal? literal)
                         (let ((mt-arg (missing-larkc 30474))
                               (subformula (missing-larkc 30496)))
                           (declare (ignore subformula))
                           (let ((lit-mt (if (mt? mt-arg) mt-arg mt)))
                             (declare (ignore lit-mt))
                             (when (or (not (within-ask?))
                                       (mt? mt-arg))
                               ;; missing-larkc 11759 likely returns isa constraints from within
                               ;; the mt-designated subformula.
                               (setf result (nconc result (missing-larkc 11759))))))
                         ;; missing-larkc 11760 likely returns isa constraints from within
                         ;; the sentence arg.
                         (setf result (nconc result (missing-larkc 11760))))))
                  ((arg-types-prescribe-tacit-term-list? predicate argnum))
                  ((tree-find var arg #'equal)
                   ;; missing-larkc 11788/11789/11790 likely returns isa constraints from
                   ;; within the arg structure that contains var.
                   (let ((items (missing-larkc 11788)))
                     (if (vectorp items)
                         (let ((items2 (missing-larkc 11789)))
                           (dotimes (i (length items2))
                             (push (aref items2 i) result)))
                         (dolist (item (missing-larkc 11790))
                           (push item result)))))))
              (setf result (delete-duplicate-forts result)))))))
    result))

(defun pos-lit-variable-isa-constraints-memoized (var literal mt)
  "[Cyc] Memoized version of pos-lit-variable-isa-constraints."
  (let ((v-memoization-state *memoization-state*))
    (when (null v-memoization-state)
      (return-from pos-lit-variable-isa-constraints-memoized
        (pos-lit-variable-isa-constraints-memoized-internal var literal mt)))
    (let ((caching-state (memoization-state-lookup v-memoization-state 'pos-lit-variable-isa-constraints-memoized)))
      (when (null caching-state)
        (setf caching-state (create-caching-state (memoization-state-lock v-memoization-state)
                                                  'pos-lit-variable-isa-constraints-memoized
                                                  3 nil #'equal))
        (memoization-state-put v-memoization-state 'pos-lit-variable-isa-constraints-memoized caching-state))
      (let* ((sxhash (sxhash-calc-3 var literal mt))
             (collisions (caching-state-lookup caching-state sxhash)))
        (unless (eq collisions :&memoized-item-not-found&)
          (dolist (collision collisions)
            (let ((cached-args (first collision))
                  (results2 (second collision)))
              (when (and (equal var (first cached-args))
                         (equal literal (second cached-args))
                         (equal mt (third cached-args))
                         (null (cdddr cached-args)))
                (return-from pos-lit-variable-isa-constraints-memoized
                  (caching-results results2))))))
        (let ((results (multiple-value-list (pos-lit-variable-isa-constraints-memoized-internal var literal mt))))
          (caching-state-enter-multi-key-n caching-state sxhash collisions results (list var literal mt))
          (caching-results results))))))

(defun pos-lit-variable-quoted-isa-constraints (var literal mt)
  "[Cyc] Return the quoted-isa constraints on VAR from positive literal LITERAL."
  (let ((predicate (literal-predicate literal))
        (result nil))
    (unless (fort-p predicate)
      ;; missing-larkc 29732 likely finds the closed NAUT for a non-fort predicate.
      (setf predicate (missing-larkc 29732)))
    (let ((scoping-args (if (fort-p predicate) (scoping-args predicate mt) nil))
          (argnum 0)
          (mt-var mt))
      (let ((*relevant-mt-function* (possibly-in-mt-determine-function mt-var))
            (*mt* (possibly-in-mt-determine-mt mt-var)))
        (let ((asserted-genl-something? (when (fort-p predicate)
                                          (or (asserted-genl-predicates? predicate)
                                              (asserted-genl-inverses? predicate)))))
          (let ((*at-reln* predicate)
                (*at-search-genl-preds?* (and *at-check-genl-preds?*
                                              asserted-genl-something?))
                (*at-search-genl-inverses?* (and *at-check-genl-inverses?*
                                                 asserted-genl-something?)))
            (dolist (arg (literal-args literal :regularize))
              (incf argnum)
              (cond
                ((member? argnum scoping-args))
                ((fast-cycl-quoted-term-p arg))
                ((relax-arg-type-constraints-for-variables-for-arg? predicate argnum mt))
                ((equal var arg)
                 (setf result (nconc result (at-argn-quoted-isa predicate argnum))))
                ((modal-in-arg? predicate argnum mt))
                ((unreified-skolem-term? arg)
                 ;; missing-larkc 29786 likely returns the skolem function variable for the arg.
                 (when (eql var (missing-larkc 29786))
                   (setf result (at-argn-quoted-isa predicate argnum)))
                 ;; missing-larkc 22936 likely returns the skolem number for the arg.
                 (let ((skolem-number (missing-larkc 22936)))
                   (when (tree-find var skolem-number)
                     ;; missing-larkc 11792 likely returns quoted-isa constraints from within
                     ;; the skolem structure.
                     (setf result (nconc result (missing-larkc 11792))))))
                ((sentence-arg? predicate argnum mt)
                 ;; missing-larkc 8769 likely tests whether the sentence arg contains var.
                 (when (missing-larkc 8769)
                   (if (mt-designating-literal? literal)
                       (let ((mt-arg (missing-larkc 30475))
                             (subformula (missing-larkc 30497)))
                         (declare (ignore subformula))
                         (let ((lit-mt (if (mt? mt-arg) mt-arg mt)))
                           (declare (ignore lit-mt))
                           (when (or (not (within-ask?))
                                     (mt? mt-arg))
                             ;; missing-larkc 11763 likely returns quoted-isa constraints from
                             ;; within the mt-designated subformula.
                             (setf result (nconc result (missing-larkc 11763))))))
                       ;; missing-larkc 11764 likely returns quoted-isa constraints from
                       ;; within the sentence arg.
                       (setf result (nconc result (missing-larkc 11764))))))
                ((arg-types-prescribe-tacit-term-list? predicate argnum))
                ((tree-find var arg #'equal)
                 ;; missing-larkc 11793 likely returns quoted-isa constraints from
                 ;; within the arg structure that contains var.
                 (setf result (nconc result (missing-larkc 11793))))))
            (setf result (delete-duplicate-forts result))))))
    result))

(defun pos-lit-variable-genl-constraints (var literal mt)
  "[Cyc] Return the genl constraints on VAR from positive literal LITERAL."
  (let ((predicate (literal-predicate literal))
        (result nil))
    (unless (fort-p predicate)
      (when (closed-naut? predicate)
        (setf predicate (find-closed-naut predicate))))
    (let ((scoping-args (if (fort-p predicate) (scoping-args predicate mt) nil))
          (argnum 0)
          (mt-var mt))
      (let ((*relevant-mt-function* (possibly-in-mt-determine-function mt-var))
            (*mt* (possibly-in-mt-determine-mt mt-var)))
        (let ((asserted-genl-something? (when (fort-p predicate)
                                          (or (asserted-genl-predicates? predicate)
                                              (asserted-genl-inverses? predicate)))))
          (let ((*at-reln* predicate)
                (*at-search-genl-preds?* (and *at-check-genl-preds?*
                                              asserted-genl-something?))
                (*at-search-genl-inverses?* (and *at-check-genl-inverses?*
                                                 asserted-genl-something?)))
            (dolist (arg (literal-args literal :regularize))
              (incf argnum)
              (cond
                ((member? argnum scoping-args))
                ((fast-cycl-quoted-term-p arg))
                ((relax-arg-type-constraints-for-variables-for-arg? predicate argnum mt))
                ((equal var arg)
                 (setf result (nconc result (at-argn-genl predicate argnum))))
                ((modal-in-arg? predicate argnum mt))
                ((unreified-skolem-term? arg)
                 ;; missing-larkc 29787 likely returns the skolem function variable for the arg.
                 (when (eql var (missing-larkc 29787))
                   (setf result (at-argn-genl predicate argnum)))
                 ;; missing-larkc 22937 likely returns the skolem number for the arg.
                 (let ((skolem-number (missing-larkc 22937)))
                   (when (tree-find var skolem-number)
                     ;; missing-larkc 11781 likely returns genl constraints from within
                     ;; the skolem structure.
                     (setf result (nconc result (missing-larkc 11781))))))
                ((sentence-arg? predicate argnum mt)
                 ;; missing-larkc 8770 likely tests whether the sentence arg contains var.
                 (when (missing-larkc 8770)
                   (if (mt-designating-literal? literal)
                       (let ((mt-arg (missing-larkc 30476))
                             (subformula (missing-larkc 30498)))
                         (declare (ignore subformula))
                         (let ((lit-mt (if (mt? mt-arg) mt-arg mt)))
                           (declare (ignore lit-mt))
                           (when (or (not (within-ask?))
                                     (mt? mt-arg))
                             ;; missing-larkc 11746 likely returns genl constraints from
                             ;; within the mt-designated subformula.
                             (setf result (nconc result (missing-larkc 11746))))))
                       ;; missing-larkc 11747 likely returns genl constraints from
                       ;; within the sentence arg.
                       (setf result (nconc result (missing-larkc 11747))))))
                ((arg-types-prescribe-tacit-term-list? predicate argnum))
                ((tree-find var arg #'equal)
                 ;; missing-larkc 11782 likely returns genl constraints from
                 ;; within the arg structure that contains var.
                 (setf result (nconc result (missing-larkc 11782))))))
            (setf result (delete-duplicate-forts result))))))
    result))

(defun neg-lit-variable-inter-arg-isa-constraints (var literal mt)
  "[Cyc] Return the inter-arg-isa constraints on VAR from negative literal LITERAL."
  (if (within-disjunction?)
      (pos-lit-variable-inter-arg-isa-constraints var literal mt)
      nil))

;; (defun neg-lit-variable-inter-arg-genl-constraints (var literal mt) ...) -- 3 required, 0 optional, commented declareFunction, no body

(defun pos-lit-variable-inter-arg-isa-constraints (var literal mt)
  "[Cyc] Return the inter-arg-isa constraints on VAR from positive literal LITERAL."
  (let ((predicate (literal-predicate literal))
        (result nil))
    (unless (fort-p predicate)
      ;; missing-larkc 29733 likely finds the closed NAUT for a non-fort predicate.
      (setf predicate (missing-larkc 29733)))
    (let ((v-arity (literal-arity literal))
          (argnum 0)
          (scoping-args (if (fort-p predicate) (scoping-args predicate mt) nil))
          (mt-var mt))
      (let ((*relevant-mt-function* (possibly-in-mt-determine-function mt-var))
            (*mt* (possibly-in-mt-determine-mt mt-var)))
        (let ((asserted-genl-something? (when (fort-p predicate)
                                          (or (asserted-genl-predicates? predicate)
                                              (asserted-genl-inverses? predicate)))))
          (let ((*at-reln* predicate)
                (*at-search-genl-preds?* (and *at-check-genl-preds?*
                                              asserted-genl-something?))
                (*at-search-genl-inverses?* (and *at-check-genl-inverses?*
                                                 asserted-genl-something?)))
            (dolist (arg (literal-args literal :regularize))
              (incf argnum)
              (cond
                ((member? argnum scoping-args))
                ((fast-cycl-quoted-term-p arg))
                ((relax-arg-type-constraints-for-variables-for-arg? predicate argnum mt))
                ((equal var (vt-unskolemize-term arg))
                 (let ((*at-profile-term* (if (equal var *at-profile-term*)
                                              *at-profile-term*
                                              nil)))
                   (dotimes (index v-arity)
                     (let ((ind-argnum (1+ index)))
                       (unless (= argnum ind-argnum)
                         (let ((ind-arg (literal-arg literal ind-argnum)))
                           (cond
                             ((null ind-arg))
                             ((at-inter-arg-checkable-object? ind-arg)
                              (setf result (nconc result (inter-arg-isa predicate argnum ind-arg ind-argnum))))
                             (t
                              (dolist (ind-type (alist-lookup *at-var-isa* ind-arg))
                                (setf result (nconc result (inter-arg-isa-from-type predicate argnum ind-type ind-argnum))))))))))))
                ((modal-in-arg? predicate argnum mt))
                ((unreified-skolem-term? arg))
                ((sentence-arg? predicate argnum mt)
                 ;; missing-larkc 8771 likely tests whether the sentence arg contains var.
                 (when (missing-larkc 8771)
                   (if (mt-designating-literal? literal)
                       (let ((mt-arg (missing-larkc 30477))
                             (subformula (missing-larkc 30499)))
                         (declare (ignore subformula))
                         (let ((lit-mt (if (mt? mt-arg) mt-arg mt)))
                           (declare (ignore lit-mt))
                           (when (or (not (within-ask?))
                                     (mt? mt-arg))
                             ;; missing-larkc 11755 likely returns inter-arg-isa constraints from
                             ;; within the mt-designated subformula.
                             (setf result (nconc result (missing-larkc 11755))))))
                       ;; missing-larkc 11756 likely returns inter-arg-isa constraints from
                       ;; within the sentence arg.
                       (setf result (nconc result (missing-larkc 11756))))))
                ((arg-types-prescribe-tacit-term-list? predicate argnum))
                ((tree-find var arg #'equal)
                 ;; missing-larkc 11785 likely returns inter-arg-isa constraints from
                 ;; within the arg structure that contains var.
                 (setf result (nconc result (missing-larkc 11785))))))
            (setf result (delete-duplicate-forts result))))))
    result))

(defun at-inter-arg-checkable-object? (object)
  "[Cyc] Return T iff OBJECT is a fort or first-order NAUT."
  (or (fort-p object)
      (first-order-naut? object)))

;; (defun pos-lit-variable-inter-arg-genl-constraints (var literal mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun formula-variable-isa-constraints (var formula mt &optional (var? #'cyc-var?)) ...) -- 3 required, 1 optional, commented declareFunction, no body
;; (defun formula-variable-quoted-isa-constraints (var formula mt &optional (var? #'cyc-var?)) ...) -- 3 required, 1 optional, commented declareFunction, no body
;; (defun formula-variable-genl-constraints (var formula mt &optional (var? #'cyc-var?)) ...) -- 3 required, 1 optional, commented declareFunction, no body
;; (defun formula-variable-arg-constraints (var formula mt type &optional (var? #'cyc-var?)) ...) -- 4 required, 1 optional, commented declareFunction, no body
;; (defun cnf-formula-variable-arg-constraints (var cnf mt type) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun dnf-formula-variable-arg-constraints (var dnf mt type) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun formula-variable-inter-arg-isa-constraints (var formula mt &optional (var? #'cyc-var?)) ...) -- 3 required, 1 optional, commented declareFunction, no body
;; (defun formula-variable-inter-arg-genl-constraints (var formula mt &optional (var? #'cyc-var?)) ...) -- 3 required, 1 optional, commented declareFunction, no body
;; (defun formula-variable-inter-arg-constraints (var formula mt type &optional (var? #'cyc-var?)) ...) -- 4 required, 1 optional, commented declareFunction, no body
;; (defun cnf-formula-variable-inter-arg-constraints (var cnf mt type) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun dnf-formula-variable-inter-arg-constraints (var dnf mt type) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun relation-variable-isa-constraints (var relation mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun relation-variable-quoted-isa-constraints (var relation mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun relation-variable-genl-constraints (var relation mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun relation-variable-inter-arg-isa-constraints (var relation mt) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun relation-variable-inter-arg-genl-constraints (var relation mt) ...) -- 3 required, 0 optional, commented declareFunction, no body

(defun at-min-cols (cols mt)
  "[Cyc] Return the minimum (most specific) collections from COLS."
  (copy-list (at-min-cols-memoized (sort-terms cols t) mt)))

(defun at-min-cols-memoized-internal (cols mt)
  "[Cyc] Internal implementation for at-min-cols-memoized."
  (min-cols cols mt))

(defun at-min-cols-memoized (cols mt)
  "[Cyc] Memoized version of at-min-cols."
  (let ((v-memoization-state *memoization-state*))
    (when (null v-memoization-state)
      (return-from at-min-cols-memoized
        (at-min-cols-memoized-internal cols mt)))
    (let ((caching-state (memoization-state-lookup v-memoization-state 'at-min-cols-memoized)))
      (when (null caching-state)
        (setf caching-state (create-caching-state (memoization-state-lock v-memoization-state)
                                                  'at-min-cols-memoized
                                                  2 nil #'equal))
        (memoization-state-put v-memoization-state 'at-min-cols-memoized caching-state))
      (let* ((sxhash (sxhash-calc-2 cols mt))
             (collisions (caching-state-lookup caching-state sxhash)))
        (unless (eq collisions :&memoized-item-not-found&)
          (dolist (collision collisions)
            (let ((cached-args (first collision))
                  (results2 (second collision)))
              (when (and (equal cols (first cached-args))
                         (null (cddr cached-args))
                         (equal mt (second cached-args)))
                (return-from at-min-cols-memoized
                  (caching-results results2))))))
        (let ((results (multiple-value-list (at-min-cols-memoized-internal cols mt))))
          (caching-state-enter-multi-key-n caching-state sxhash collisions results (list cols mt))
          (caching-results results))))))

;; (defun query-arg? (query argnum var?) ...) -- 3 required, 0 optional, commented declareFunction, no body
;; (defun query-denoting-collection? (query mt) ...) -- 2 required, 0 optional, commented declareFunction, no body
;; (defun at-arg-formula-type (relation argnum mt) ...) -- 3 required, 0 optional, commented declareFunction, no body

(defun at-argn-isa (relation argnum)
  "[Cyc] Assumes mt relevance established from outside,
and that we are within a with-at-reln macro."
  (let ((result nil))
    (let ((*at-constraint-type* :isa)
          (*mapping-assertion-bookkeeping-fn* #'gather-at-data-assertion))
      (setf result (at-argn-int relation argnum nil nil #'argn-isa 2)))
    result))

(defun at-argn-quoted-isa (relation argnum)
  "[Cyc] Assumes mt relevance established from outside,
and that we are within a with-at-reln macro."
  (let ((result nil))
    (let ((*at-constraint-type* :isa)
          (*mapping-assertion-bookkeeping-fn* #'gather-at-data-assertion))
      (setf result (at-argn-int relation argnum nil nil #'argn-quoted-isa 2)))
    result))

(defun at-argn-genl (relation argnum)
  "[Cyc] Assumes mt relevance established from outside,
and that we are within a with-at-reln macro."
  (let ((result nil))
    (let ((*at-constraint-type* :genls)
          (*mapping-assertion-bookkeeping-fn* #'gather-at-data-assertion))
      (setf result (at-argn-int relation argnum nil nil #'argn-genl 2)))
    result))

(defun inter-arg-isa (relation argnum ind-arg ind-argnum)
  "[Cyc] Assumes mt relevance established from outside,
and that we are within a with-at-reln macro."
  (at-argn-int relation argnum ind-arg ind-argnum #'inter-arg-isa-int 4))

;; (defun inter-arg-genl (relation argnum ind-arg ind-argnum) ...) -- 4 required, 0 optional, commented declareFunction, no body

(defun inter-arg-isa-from-type (relation argnum ind-type ind-argnum)
  "[Cyc] Return inter-arg-isa constraints from the type of an independent arg."
  (let ((result nil))
    (if (el-fort-p ind-type)
        (setf result (at-argn-int relation argnum ind-type ind-argnum #'inter-arg-isa-from-type-int 4))
        (setf result nil))
    result))

;; (defun inter-arg-genl-from-type (relation argnum ind-type ind-argnum) ...) -- 4 required, 0 optional, commented declareFunction, no body

(defun at-argn-int (relation argnum ind-arg ind-argnum at-func at-func-arity)
  "[Cyc] Core dispatcher for arg constraint lookup."
  (copy-list (at-argn-int-cached relation argnum ind-arg ind-argnum at-func at-func-arity (mt-info))))

(defun clear-at-argn-int-cached ()
  "[Cyc] Clear the at-argn-int cache."
  (let ((cs *at-argn-int-cached-caching-state*))
    (when cs
      (caching-state-clear cs)))
  nil)

;; (defun remove-at-argn-int-cached (relation argnum ind-arg ind-argnum at-func at-func-arity mt-info) ...) -- 7 required, 0 optional, commented declareFunction, no body

(defun at-argn-int-cached-internal (relation argnum ind-arg ind-argnum at-func at-func-arity mt-info)
  "[Cyc] Internal implementation for at-argn-int-cached."
  (declare (ignore mt-info))
  (let ((result nil))
    (if (or (at-searching-genl-preds?)
            (at-searching-genl-inverses?))
        (progn
          (setf result (at-argn-int-funcall at-func at-func-arity relation argnum ind-arg ind-argnum))
          (when (at-searching-genl-preds?)
            (dolist (pred (all-proper-genl-predicates relation nil nil))
              (setf result (nconc result (at-argn-int-funcall at-func at-func-arity pred argnum ind-arg ind-argnum)))))
          (when (at-searching-genl-inverses?)
            (dolist (inverse (all-proper-genl-inverses relation nil nil))
              (setf result (nconc result (at-argn-int-funcall at-func at-func-arity inverse (inverse-argnum argnum) ind-arg ind-argnum)))))
          (setf result (delete-duplicate-forts result)))
        (when (kb-relation? relation)
          (setf result (at-argn-int-funcall at-func at-func-arity relation argnum ind-arg ind-argnum))))
    result))

(defun at-argn-int-cached (relation argnum ind-arg ind-argnum at-func at-func-arity mt-info)
  "[Cyc] Globally cached version of at-argn-int."
  (let ((caching-state *at-argn-int-cached-caching-state*))
    (when (null caching-state)
      (setf caching-state (create-global-caching-state-for-name 'at-argn-int-cached
                                                                '*at-argn-int-cached-caching-state*
                                                                1024 #'eq 7 0))
      (register-hl-store-cache-clear-callback #'clear-at-argn-int-cached))
    (let* ((sxhash (sxhash-calc-7 relation argnum ind-arg ind-argnum at-func at-func-arity mt-info))
           (collisions (caching-state-lookup caching-state sxhash)))
      (unless (eq collisions :&memoized-item-not-found&)
        (dolist (collision collisions)
          (let ((cached-args (first collision))
                (results2 (second collision)))
            (when (and (eq relation (first cached-args))
                       (eq argnum (second cached-args))
                       (eq ind-arg (third cached-args))
                       (eq ind-argnum (fourth cached-args))
                       (eq at-func (fifth cached-args))
                       (eq at-func-arity (sixth cached-args))
                       (eq mt-info (seventh cached-args))
                       (null (nthcdr 7 cached-args)))
              (return-from at-argn-int-cached
                (caching-results results2))))))
      (let ((results (multiple-value-list (at-argn-int-cached-internal relation argnum ind-arg ind-argnum at-func at-func-arity mt-info))))
        (caching-state-enter-multi-key-n caching-state sxhash collisions results (list relation argnum ind-arg ind-argnum at-func at-func-arity mt-info))
        (caching-results results)))))

(defun at-argn-int-funcall (at-func at-func-arity relation arg ind-arg ind-argnum)
  "[Cyc] Dispatch to the appropriate AT function."
  (let ((result nil))
    (cond
      ((eql at-func-arity 2)
       (cond
         ((eq at-func #'argn-isa)
          (setf result (argn-isa relation arg)))
         ((eq at-func #'argn-genl)
          (setf result (argn-genl relation arg)))
         (t
          (setf result (funcall at-func relation arg)))))
      ((eql at-func-arity 4)
       (cond
         ((eq at-func #'inter-arg-isa-int)
          (setf result (inter-arg-isa-int relation arg ind-arg ind-argnum)))
         ((eq at-func #'inter-arg-genl-int)
          ;; missing-larkc 11776 is inter-arg-genl-int, the genl analogue of inter-arg-isa-int.
          (setf result (missing-larkc 11776)))
         ((eq at-func #'inter-arg-isa-from-type-int)
          (setf result (inter-arg-isa-from-type-int relation arg ind-arg ind-argnum)))
         ((eq at-func #'inter-arg-genl-from-type-int)
          ;; missing-larkc 11775 is inter-arg-genl-from-type-int.
          (setf result (missing-larkc 11775)))
         (t
          (setf result (funcall at-func relation arg ind-arg ind-argnum)))))
      (t
       ;; missing-larkc 7150 likely reports unexpected arity.
       (missing-larkc 7150)))
    result))

(defun inter-arg-isa-int (relation argnum ind-arg ind-argnum)
  "[Cyc] Return inter-arg-isa constraints."
  (let ((at-pred (inter-arg-isa-pred ind-argnum argnum)))
    (when at-pred
      (return-from inter-arg-isa-int
        (inter-arg-type-int :isa relation argnum ind-arg at-pred))))
  nil)

;; (defun inter-arg-genl-int (relation argnum ind-arg ind-argnum) ...) -- 4 required, 0 optional, commented declareFunction, no body

(defun inter-arg-type-int (type relation argnum ind-arg at-pred)
  "[Cyc] Return inter-arg-type constraints.
TYPE is :isa or :genls."
  (let ((candidates nil))
    (when (do-gaf-arg-index-key-validator relation 1 at-pred)
      (let ((iterator-var (new-gaf-arg-final-index-spec-iterator relation 1 at-pred)))
        (do ((done-var nil))
            (done-var)
          (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var nil))
                 (valid (not (null final-index-spec))))
            (when valid
              (let ((final-index-iterator nil))
                (unwind-protect
                     (progn
                       (setf final-index-iterator (new-final-index-iterator final-index-spec :gaf :true nil))
                       (do ((done-var-2 nil))
                           (done-var-2)
                         (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator nil))
                                (valid-2 (not (null assertion))))
                           (when valid-2
                             (let ((ind-col (gaf-arg2 assertion))
                                   (dep-col (gaf-arg3 assertion)))
                               (push (list ind-col dep-col assertion) candidates)))
                           (setf done-var-2 (not valid-2)))))
                  (when final-index-iterator
                    (destroy-final-index-iterator final-index-iterator)))))
            (setf done-var (not valid))))))
    (when candidates
      (return-from inter-arg-type-int
        (inter-arg-type-verify-candidates candidates ind-arg argnum type))))
  nil)

(defun inter-arg-type-verify-candidates (candidates ind-arg argnum type)
  "[Cyc] Verify inter-arg-type candidates.
CANDIDATES is a list of triples of the form (ind-col dep-col assertion).
TYPE is :isa or :genls."
  (let* ((result nil)
         (candidate-collections (mapcar #'first candidates))
         (actual-collections (if (eq type :isa)
                                 (all-isa-among ind-arg candidate-collections)
                                 ;; missing-larkc 4942 likely returns all-genls-among for the :genls case.
                                 (missing-larkc 4942))))
    (when actual-collections
      (dolist (candidate candidates)
        (destructuring-bind (ind-col dep-col assertion) candidate
          (when (member? ind-col actual-collections)
            ;; missing-larkc 7165 likely records the matching constraint for bookkeeping.
            (missing-larkc 7165)
            (let ((*at-constraint-gaf* assertion))
              ;; missing-larkc 7183 likely gathers the constraint data assertion.
              (missing-larkc 7183)
              (push dep-col result))))))
    result))

(defun inter-arg-isa-from-type-int (relation argnum ind-type ind-argnum)
  "[Cyc] Return inter-arg-isa-from-type constraints."
  (let ((at-pred (inter-arg-isa-pred ind-argnum argnum)))
    (when at-pred
      (return-from inter-arg-isa-from-type-int
        (inter-arg-type-int :genls relation argnum ind-type at-pred))))
  nil)

;; (defun inter-arg-genl-from-type-int (relation argnum ind-type ind-argnum) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun constraint-var-types-ok? (var-types-pairs &optional (type :isa) mt) ...) -- 1 required, 2 optional, commented declareFunction, no body

(defun var-types-ok? (var-types-pairs &optional (type :isa) mt)
  "[Cyc] Check that the variable type pairs are ok."
  (cond
    ((eq *at-var-types-standard* :not-disjoint)
     (var-types-not-disjoint? var-types-pairs type mt))
    ((eq *at-var-types-standard* :neglits-subsume-poslits)
     ;; missing-larkc 11797 is var-types-neglits-subsume-poslits?, an alternative check standard.
     (missing-larkc 11797))))

(defun var-types-not-disjoint? (var-types-pairs &optional (type :isa) mt)
  "[Cyc] Check that the variable types in VAR-TYPES-PAIRS are not disjoint."
  (let ((done? nil)
        (disjoint? nil)
        (disjoint nil))
    (csome (var-types var-types-pairs done?)
      (setf disjoint (any-disjoint-collection-pair (rest var-types) mt))
      (when disjoint
        (setf disjoint? t)
        (setf done? (at-finished? t))
        ;; missing-larkc 7219 likely reports the disjoint violation for WFF checking.
        (missing-larkc 7219)))
    (not disjoint?)))

;; (defun var-type-disjoint-violation (var types disjoint type) ...) -- 4 required, 0 optional, commented declareFunction, no body
;; (defun var-types-neglits-subsume-poslits? (var-types-pairs &optional (type :isa) mt) ...) -- 1 required, 2 optional, commented declareFunction, no body

(defun modal-in-arg? (relation index &optional mt)
  "[Cyc] Return T iff RELATION has a #$modalInArg assertion for INDEX."
  (when (fort-p relation)
    (and (some-pred-assertion-somewhere? #$modalInArg relation 1)
         ;; missing-larkc 30023 likely checks if there is a specific modalInArg assertion
         ;; for this relation and index, e.g., via kb-mapping-utilities.
         (missing-larkc 30023))))

;;; Setup phase

(toplevel
  (note-globally-cached-function 'at-var-type-dnfs-int-cached)
  (note-memoized-function 'pos-lit-variable-isa-constraints-memoized)
  (note-memoized-function 'at-min-cols-memoized)
  (note-globally-cached-function 'at-argn-int-cached))
