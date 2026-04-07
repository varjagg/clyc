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

;; Variables (init section)

(defparameter *simplifying-sequence-variables?* nil
  "[Cyc] Dynamically bound to t when we're in simplify-sequence-variables, to avoid unnecessary recursion.")

(defparameter *simplifying-redundancies?* nil
  "[Cyc] Dynamically bound to t when we're in simplify-transitive-redundancies to avoid unnecessary recursion.")

(defparameter *transitive-constraint-preds* (list #$isa #$genls)
  "[Cyc] Transitive (or sort of transitive) predicates that can be used to constrain arguments,
i.e. the argument must bear the relation RELN to something else, where RELN is one of these.
Assumes that they are binary and that the arg1 is constrained to bear the relation to the arg2.")

;; Functions follow declare_simplifier_file() ordering

;; (defun lift-disjuncts (disjuncts) ...) -- no body, commented declareFunction

(defun nlift-disjuncts (disjuncts)
  "[Cyc] A destructive version of @xref lift-disjuncts."
  (let ((last-done nil)
        (undone nil)
        (disjunct nil))
    (setf undone disjuncts)
    (setf disjunct (first-in-sequence undone))
    (loop while undone do
      (if (el-disjunction-p disjunct)
          (let* ((nested-disjuncts (sentence-args disjunct))
                 (still-undone (rest-of-sequence undone))
                 (replacements (nlift-disjuncts nested-disjuncts))
                 (splice-cons (last replacements)))
            (if (null replacements)
                (if (null last-done)
                    (setf disjuncts still-undone)
                    (rplacd last-done still-undone))
                (progn
                  (if (eq replacements splice-cons)
                      (rplaca undone (first-in-sequence replacements))
                      (progn
                        (rplacd splice-cons still-undone)
                        (rplaca undone (first-in-sequence replacements))
                        (rplacd undone (rest-of-sequence replacements))
                        (setf undone splice-cons)))
                  (setf last-done undone))))
          (setf last-done undone))
      (setf undone (rest-of-sequence undone))
      (setf disjunct (first-in-sequence undone)))
    disjuncts))

(defun disjoin (sentence-list &optional simplify?)
  "[Cyc] Returns the disjunction of the sentences in the list SENTENCE-LIST.
If SIMPLIFY? is true, then if any of the sentences in SENTENCE-LIST are disjunctions
themselves, they will be flattened: i.e. no resulting disjunct will itself be a disjunct
(simplification is destructive).
e.g. (<form1> (#$or <form2> <form3>)) will become (<form1> <form2> <form3>),
((#$or (#$or <form1> (#$or <form2> <form3>)) <form4>) <form5>)
will become (<form1> <form2> <form3> <form4> <form5>),
but ((#$and (#$or <form1> (#$or <form2> <form3>)) <form4>) <form5>) will not change.
Also, if SIMPLIFY? is true and SENTENCE-LIST is of length 1, it will return the sentence
in SENTENCE-LIST."
  (ndisjoin (if simplify?
                (copy-tree sentence-list)
                sentence-list)
            simplify?))

(defun ndisjoin (sentence-list &optional (simplify? t))
  "[Cyc] A destructive version of @xref disjoin."
  (check-type sentence-list list)
  (let ((disjuncts (if simplify?
                       (nlift-disjuncts sentence-list)
                       sentence-list)))
    (make-disjunction disjuncts)))

;; (defun simplify-unary-junct (junct) ...) -- no body, commented declareFunction
;; (defun simplify-unary-juncts (sentence) ...) -- no body, commented declareFunction
;; (defun simplify-duplicate-juncts (sentence) ...) -- no body, commented declareFunction
;; (defun lift-conjuncts (conjuncts) ...) -- no body, commented declareFunction
;; (defun nlift-conjuncts (conjuncts) ...) -- no body, commented declareFunction
;; (defun conjoin (sentence-list &optional simplify?) ...) -- no body, commented declareFunction
;; (defun nconjoin (sentence-list &optional simplify?) ...) -- no body, commented declareFunction
;; (defun lift-conjuncts-recursive (conjuncts) ...) -- no body, commented declareFunction
;; (defun liftable-conjuncts? (conjuncts) ...) -- no body, commented declareFunction
;; (defun simplify-el-syntax (sentence &optional var?) ...) -- no body, commented declareFunction
;; (defun try-to-simplify-non-wff-into-wff (non-wff &optional wff-function arg2-to-wff-function) ...) -- no body, commented declareFunction

(defun simplify-cycl-sentence-deep (sentence &optional (var? #'cyc-var?))
  "[Cyc] Performs deeper simplifications on SENTENCE than @xref simplify-cycl-sentence.
Assumes that the EL variable namespace is bound."
  (setf sentence (simplify-sequence-variables-1 sentence))
  (setf sentence (simplify-cycl-sentence sentence var?))
  sentence)

(defun simplify-cycl-sentence (sentence &optional (var? #'cyc-var?))
  "[Cyc]"
  (setf sentence (simplify-special-cases sentence))
  (setf sentence (simplify-cycl-sentence-int sentence var?))
  (when (simplify-transitive-redundancies?)
    (setf sentence (missing-larkc 10691))) ;; likely simplify-transitive-redundancies
  sentence)

(defun simplify-cycl-sentence-syntax (sentence &optional (var? #'cyc-var?))
  "[Cyc] Like @xref simplify-cycl-sentence, but only does syntactic simplification."
  (let ((*simplify-using-semantics?* nil))
    (simplify-cycl-sentence sentence var?)))

(defun simplify-cycl-sentence-int (sentence &optional (var? #'cyc-var?))
  "[Cyc]"
  (let ((result sentence))
    (cond
      ((not *simplify-sentence?*))
      ((eq #$True sentence))
      ((eq #$False sentence))
      ((subl-escape-p sentence))
      ((fast-cycl-quoted-term-p sentence))
      ((funcall var? sentence))
      ((assertion-p sentence))
      ((atom sentence)
       (el-error 4 "~S is not well formed." sentence)
       (missing-larkc 8071)) ;; likely note-wff-violation
      ((el-negation-p sentence)
       (let* ((seqvar (sequence-var sentence))
              (sub-sentence nil))
         (let ((*within-negation?* (not *within-negation?*)))
           (setf sub-sentence (simplify-cycl-sentence-int (sentence-arg1 sentence) var?)))
         (setf result (maybe-add-sequence-var-to-end
                       seqvar
                       (simplify-cycl-negation
                        (make-unary-formula (sentence-arg0 sentence) sub-sentence)
                        var?)))))
      ((el-conjunction-p sentence)
       (if (and (formula-arity= sentence 0 :ignore)
                (formula-arity= sentence 1 :regularize))
           (setf result sentence)
           (let ((*within-conjunction?* t)
                 (*within-negated-conjunction?* *within-negation?*))
             (setf result (simplify-cycl-conjunction
                           (map-formula-args #'simplify-cycl-sentence-int sentence)
                           var?)))))
      ((el-disjunction-p sentence)
       (if (and (formula-arity= sentence 0 :ignore)
                (formula-arity= sentence 1 :regularize))
           (setf result sentence)
           (let ((*within-disjunction?* t)
                 (*within-negated-disjunction?* *within-negation?*))
             (setf result (simplify-cycl-disjunction
                           (map-formula-args #'simplify-cycl-sentence-int sentence)
                           var?)))))
      ((el-implication-p sentence)
       (let* ((seqvar (sequence-var sentence))
              (antecedent nil)
              (consequent nil))
         (let ((*within-disjunction?* t)
               (*within-negated-disjunction?* *within-negation?*))
           (let ((*within-negation?* (not *within-negation?*)))
             (setf antecedent (simplify-cycl-sentence-int (sentence-arg1 sentence) var?)))
           (setf consequent (simplify-cycl-sentence-int (sentence-arg2 sentence) var?)))
         (setf result (maybe-add-sequence-var-to-end
                       seqvar
                       (simplify-cycl-implication
                        (make-binary-formula (sentence-arg0 sentence) antecedent consequent)
                        var?)))))
      ((el-exception-p sentence)
       (setf result (missing-larkc 10684))) ;; likely simplify-exception
      ((el-universal-p sentence)
       (setf result (missing-larkc 10683))) ;; likely simplify-cycl-universal
      ((el-existential-p sentence)
       (setf result (simplify-cycl-existential
                     (make-regularly-quantified-sentence
                      (sentence-quantifier sentence)
                      (quantified-var sentence)
                      (simplify-cycl-sentence-int (quantified-sub-sentence sentence))))))
      ((el-bounded-existential-p sentence)
       (setf result (missing-larkc 30589))) ;; likely simplify bounded existential
      ((atomic-sentence? sentence)
       (setf result (simplify-cycl-literal sentence var?)))
      ((not *simplify-using-semantics?*))
      ((formula-denoting-function? sentence)
       (setf result (missing-larkc 10679))) ;; likely simplify-cycl-relation for denoting function
      ((unreified-skolem-term? sentence)
       (setf result (missing-larkc 10680))) ;; likely simplify-cycl-relation for skolem term
      ((relation-expression? sentence)
       (when *within-wff?*
         (missing-larkc 8072)) ;; likely note-wff-violation
       (multiple-value-bind (simplified-sentence changed?)
           (missing-larkc 10681) ;; likely simplify-cycl-relation
         (if changed?
             (setf result (simplify-cycl-sentence-int simplified-sentence))
             (setf result simplified-sentence))))
      (*within-wff?*
       (missing-larkc 8073))) ;; likely note-wff-violation
    result))

;; (defun simplify-true-sentence (sentence &optional var?) ...) -- no body, commented declareFunction
;; (defun simplify-exception (sentence &optional var?) ...) -- no body, commented declareFunction

(defun simplify-cycl-literal-syntax (literal &optional (var? #'cyc-var?))
  "[Cyc] Like @xref simplify-cycl-literal, but only does syntactic simplification."
  (let ((*simplify-using-semantics?* nil))
    (simplify-cycl-literal literal var?)))

(defun simplify-cycl-literal (literal &optional (var-func #'cyc-var?))
  "[Cyc]"
  (cond
    ((subl-escape-p literal)
     literal)
    ((fast-cycl-quoted-term-p literal)
     literal)
    ((true-sentence? literal)
     (missing-larkc 10695)) ;; likely simplify-true-sentence
    (*recanonicalizingp*
     literal)
    (t
     (when (ist-sentence-p literal)
       (let ((result (missing-larkc 10685))) ;; likely simplify-ist-sentence
         (unless (equal result literal)
           (return-from simplify-cycl-literal (simplify-cycl-sentence result)))))
     (when (not *simplify-literal?*)
       (return-from simplify-cycl-literal literal))
     (when (kappa-asent-p literal)
       (let ((result (missing-larkc 10687))) ;; likely simplify-kappa-asent
         (unless (equal result literal)
           (return-from simplify-cycl-literal (simplify-cycl-sentence result)))))
     (simplify-cycl-literal-int literal var-func))))

(defun simplify-cycl-literal-int (literal &optional (var-func #'cyc-var?))
  "[Cyc]"
  (let ((result nil))
    (if *simplify-using-semantics?*
        (let ((*check-wff-semantics?* t)
              (*check-var-types?* nil)
              (*check-wff-coherence?* nil))
          (if (or (within-assert?)
                  *trying-to-simplify-non-wff-into-wff?*
                  (not *simplify-non-wff-literal?*)
                  (semantically-wf-literal? literal *mt*))
              (setf result (simplify-distributing-out-args
                            (simplify-cycl-literal-terms literal var-func)))
              (if *try-to-simplify-non-wff-into-wff?*
                  (let ((simplified-literal (simplify-distributing-out-args
                                             (simplify-cycl-literal-terms literal var-func))))
                    (if (semantically-wf-literal? simplified-literal *mt*)
                        (setf result simplified-literal)
                        (setf result #$False)))
                  (setf result #$False))))
        (setf result (simplify-cycl-literal-terms literal)))
    result))

;; (defun distributes-out-of-arg? (pred arg mt &optional behavior) ...) -- no body, commented declareFunction

(defun simplify-distributing-out-args (literal)
  "[Cyc]"
  (let ((pred (literal-arg0 literal))
        (arg 0)
        (result nil))
    (unless result
      (dosome (v-term (literal-args literal) result)
        (incf arg)
        (when (el-relation-expression? v-term)
          (let ((reln (formula-arg0 v-term)))
            (when (missing-larkc 10668) ;; likely distributes-out-of-arg?
              (let ((literals nil)
                    (sentence nil))
                (dolist (sub-arg (formula-args v-term))
                  (push (replace-nth arg sub-arg literal) literals))
                (setf sentence (make-el-formula reln (nreverse literals)))
                (when (canon-wff? sentence)
                  (setf result sentence))))))))
    (if result
        (simplify-cycl-sentence-int result)
        literal)))

(defun simplify-cycl-literal-terms (literal &optional (var? #'cyc-var?))
  "[Cyc]"
  (if (mt-designating-literal? literal)
      (missing-larkc 10688) ;; likely simplify-mt-literal-terms
      (simplify-cycl-literal-terms-int literal var?)))

;; (defun simplify-mt-literal-terms (literal var?) ...) -- no body, commented declareFunction

(defun simplify-cycl-literal-terms-int (literal &optional (var? #'cyc-var?))
  "[Cyc]"
  (let* ((mt *mt*)
         (pred (literal-arg0 literal))
         (sequence-var (sequence-var literal))
         (result nil)
         (terms (formula-terms literal :ignore))
         (argnum 0))
    (dolist (v-term terms)
      (let ((*permit-keyword-variables?* (or *permit-keyword-variables?*
                                             (arg-permits-keyword-variables? pred argnum mt)))
            (*permit-generic-arg-variables?* (or *permit-generic-arg-variables?*
                                                 (arg-permits-generic-arg-variables? pred argnum mt))))
        (let* ((sentence-arg? (sentence-arg? pred argnum mt))
               (mal-true-sentence-arg? (and sentence-arg?
                                            (not (missing-larkc 8825)) ;; likely wff check
                                            (true-sentence? v-term))))
          (cond
            (mal-true-sentence-arg?
             (push (simplify-cycl-sentence-int (formula-arg1 v-term) var?) result))
            (sentence-arg?
             (push (simplify-cycl-sentence-int v-term var?) result))
            (t
             (push (simplify-cycl-term v-term var?) result)))))
      (setf argnum (1+ argnum)))
    (setf result (nreverse result))
    (when sequence-var
      (setf result (missing-larkc 30615))) ;; likely nconc with sequence var handling
    result))

(defun simplify-cycl-term (v-term &optional (var? #'cyc-var?))
  "[Cyc]"
  (cond
    ((subl-escape-p v-term)
     v-term)
    ((fast-cycl-quoted-term-p v-term)
     v-term)
    ((naut? v-term)
     (let* ((functor (nat-functor v-term))
            (sequence-var (sequence-var v-term))
            (arg 0)
            (new-term nil)
            (terms (formula-terms v-term :ignore)))
       (dolist (subterm terms)
         (let* ((sentence-arg? (sentence-arg? functor arg *mt*))
                (mal-true-sentence-arg? (and sentence-arg?
                                             (not (missing-larkc 8826)) ;; likely wff check
                                             (true-sentence? subterm))))
           (cond
             (mal-true-sentence-arg?
              (push (simplify-cycl-sentence-int (formula-arg1 subterm) var?) new-term))
             (sentence-arg?
              (push (simplify-cycl-sentence-int subterm var?) new-term))
             (t
              (push (simplify-cycl-term subterm var?) new-term))))
         (incf arg))
       (setf new-term (nreverse new-term))
       (when sequence-var
         (setf new-term (missing-larkc 30616))) ;; likely nconc with sequence var handling
       new-term))
    ((relation-expression? v-term)
     (multiple-value-bind (simplified-term changed?)
         (missing-larkc 10682) ;; likely simplify-cycl-relation
       (if changed?
           (simplify-cycl-term simplified-term)
           simplified-term)))
    (t
     v-term)))

;; (defun el-negate (sentence) ...) -- no body, commented declareFunction

(defun simplify-cycl-negation (negation &optional (var? #'cyc-var?))
  "[Cyc]"
  (cond
    ((not (el-negation-p negation))
     nil)
    ((eq #$False (sentence-arg1 negation))
     #$True)
    ((eq #$True (sentence-arg1 negation))
     #$False)
    ((el-negation-p (sentence-arg1 negation))
     (simplify-cycl-sentence-int (sentence-arg1 (sentence-arg1 negation)) var?))
    (t
     negation)))

(defun simplify-cycl-conjunction (conjunction &optional (var? #'cyc-var?))
  "[Cyc]"
  (cond
    ((not (el-conjunction-p conjunction))
     nil)
    ((null (sentence-args conjunction :regularize))
     #$True)
    ((and (null (sequence-var conjunction))
          (singleton? (sentence-args conjunction :ignore)))
     (sentence-arg1 conjunction :ignore))
    ((member? #$False (sentence-args conjunction :ignore))
     #$False)
    ((member? #$True (sentence-args conjunction :ignore))
     (simplify-cycl-conjunction (remove #$True conjunction) var?))
    ((duplicates? (sentence-args conjunction :ignore) #'equal)
     (let ((seqvar (sequence-var conjunction))
           (new-args (remove-duplicates (sentence-args conjunction :ignore) :test #'equal)))
       (simplify-cycl-conjunction (make-el-formula (sentence-arg0 conjunction) new-args seqvar)
                                  var?)))
    ((find-if #'el-conjunction-p (sentence-args conjunction :ignore))
     (let ((seqvar (sequence-var conjunction)))
       (if seqvar
           (simplify-cycl-conjunction
            (append (missing-larkc 10674) ;; likely lift-conjuncts of args
                    seqvar))
           (simplify-cycl-conjunction
            (missing-larkc 10660))))) ;; likely lift-conjuncts producing conjunction
    (t
     ;; Check for complementary negations
     (let* ((negations (el-negative-sentences (sentence-args conjunction :ignore)))
            (positives (if (or negations (simplify-redundancies?))
                           (el-positive-sentences (sentence-args conjunction :ignore))
                           nil))
            (disjunctions (if (simplify-redundancies?)
                              (remove-if-not #'el-disjunction-p positives)
                              nil))
            (false? nil))
       (dosome (negation negations false?)
         (setf false? (member? (sentence-arg1 negation :ignore) positives #'equal)))
       (when false?
         (return-from simplify-cycl-conjunction #$False))
       (when disjunctions
         (let ((non-disjunctions (delete-if #'el-disjunction-p positives)))
           (declare (ignore non-disjunctions))
           (let ((new-conjuncts nil))
             (dolist (disjunction disjunctions)
               (let ((conjuncts (sentence-args conjunction))
                     (disjuncts (sentence-args disjunction)))
                 (declare (ignore conjuncts disjuncts))
                 (unless (missing-larkc 9121) ;; likely check if disjunction is subsumed
                   (push disjunction new-conjuncts))))
             (return-from simplify-cycl-conjunction
               (missing-larkc 10675))))))  ;; likely rebuild conjunction from new-conjuncts
     ;; equal-symbols simplification
     (when (and *simplify-equal-symbols-literal?*
                (or (not (within-negation?))
                    (within-disjunction?)))
       (let ((argnum 0)
             (args (formula-args conjunction :ignore)))
         (dolist (conjunct args)
           (declare (ignore conjunct))
           (incf argnum)
           (when (missing-larkc 30522) ;; likely equal-symbols literal check
             (multiple-value-bind (equal-op arg1 arg2)
                 (missing-larkc 30686) ;; likely decompose equal-symbols literal
               (declare (ignore equal-op))
               (let* ((var-arg1? (funcall var? arg1))
                      (var-arg (if var-arg1? arg1 arg2))
                      (bound-arg (if var-arg1? arg2 arg1)))
                 (declare (ignore var-arg))
                 (when (ground? bound-arg var?)
                   (return-from simplify-cycl-conjunction
                     (simplify-cycl-conjunction
                      (missing-larkc 29728))))))))))  ;; likely substitute equal symbols
     (when (simplify-transitive-redundancies?)
       (setf conjunction (missing-larkc 10692))) ;; likely simplify-transitive-redundancies
     conjunction)))

(defun simplify-cycl-disjunction (disjunction &optional (var? #'cyc-var?))
  "[Cyc]"
  (let ((result nil))
    (let ((*within-disjunction?* t)
          (*within-negated-disjunction?* *within-negation?*))
      (setf result (simplify-cycl-disjunction-int disjunction var?)))
    (when (simplify-transitive-redundancies?)
      (setf disjunction (missing-larkc 10693))) ;; likely simplify-transitive-redundancies-in-cycl-disjunction
    result))

(defun simplify-cycl-disjunction-int (disjunction &optional (var? #'cyc-var?))
  "[Cyc]"
  (cond
    ((not (el-disjunction-p disjunction))
     nil)
    ((null (sentence-args disjunction :regularize))
     #$False)
    ((and (null (sequence-var disjunction))
          (singleton? (sentence-args disjunction :ignore)))
     (sentence-arg1 disjunction :ignore))
    ((member? #$True (sentence-args disjunction :ignore))
     #$True)
    ((member? #$False (sentence-args disjunction :ignore))
     (simplify-cycl-disjunction-int (remove #$False disjunction) var?))
    ((duplicates? (sentence-args disjunction :ignore) #'equal)
     (let ((seqvar (sequence-var disjunction))
           (new-args (remove-duplicates (sentence-args disjunction :ignore) :test #'equal)))
       (simplify-cycl-disjunction-int (make-el-formula (sentence-arg0 disjunction) new-args seqvar)
                                      var?)))
    ((find-if #'el-disjunction-p (sentence-args disjunction :ignore))
     (let ((seqvar (sequence-var disjunction)))
       (if seqvar
           (simplify-cycl-disjunction-int
            (append (ndisjoin (sentence-args disjunction :ignore) t) seqvar))
           (simplify-cycl-disjunction-int
            (disjoin (sentence-args disjunction) t)))))
    (t
     (let* ((negations (el-negative-sentences (sentence-args disjunction :ignore)))
            (positives (if negations
                           (el-positive-sentences (sentence-args disjunction :ignore))
                           nil))
            (true? nil))
       (dosome (negation negations true?)
         (setf true? (member? (sentence-arg1 negation :ignore) positives #'equal)))
       (if true?
           #$True
           disjunction)))))

(defun simplify-cycl-implication (implication &optional (var? #'cyc-var?))
  "[Cyc]"
  (cond
    ((not (el-implication-p implication))
     nil)
    ((not *simplify-implication?*)
     implication)
    ((singleton? (sentence-args implication))
     (simplify-cycl-sentence-int (negate (sentence-arg1 implication)) var?))
    ((eq #$True (sentence-arg2 implication))
     #$True)
    ((eq #$False (sentence-arg1 implication))
     #$True)
    ((eq #$True (sentence-arg1 implication))
     (sentence-arg2 implication))
    ((eq #$False (sentence-arg2 implication))
     (negate (sentence-arg1 implication)))
    (*within-unassert*
     implication)
    (*recanonicalizingp*
     implication)
    ((equal (sentence-arg1 implication) (sentence-arg2 implication))
     #$True)
    (t
     implication)))

;; (defun equal-implication-args? (implication &optional var?) ...) -- no body, commented declareFunction
;; (defun simplify-cycl-universal (sentence) ...) -- no body, commented declareFunction

(defun simplify-cycl-existential (existential)
  "[Cyc]"
  (let ((var (quantified-var existential))
        (sub-sentence (quantified-sub-sentence existential)))
    (if (expression-find var sub-sentence t)
        existential
        sub-sentence)))

;; (defun simplify-cycl-relation (sentence) ...) -- no body, commented declareFunction

(defun simplify-special-cases (formula)
  "[Cyc]"
  (when *simplify-using-semantics?*
    (setf formula (simplify-nested-collectionsubsetfn-expression formula)))
  formula)

(defun simplify-nested-collectionsubsetfn-expression (formula)
  "[Cyc]"
  (transform formula #'nested-collectionsubsetfn-expression?
             #'transform-nested-collectionsubsetfn-expression))

(defun transform-nested-collectionsubsetfn-expression (expression)
  "[Cyc] @param expression EL formula; assumed to be of the form
(CollectionSubsetFn (CollectionSubsetFn COL (TheSetOf ?X <blah>))
                                            (TheSetOf ?Y <bleh>))
@return EL formula; a simplified version of EXPRESSION, of the form
(CollectionSubsetFn COL (TheSetOf ?X (and <blah> <bleh[?X/?Y]>)))"
  (let* ((nested-expression (formula-arg1 expression))
         (nested-col (formula-arg1 nested-expression))
         (nested-set (formula-arg2 nested-expression))
         (nested-set-var (formula-arg1 nested-set))
         (nested-set-sentence (formula-arg2 nested-set))
         (v-set (formula-arg2 expression))
         (set-var (formula-arg1 v-set))
         (set-sentence (formula-arg2 v-set)))
    (declare (ignore nested-set-sentence))
    (when (and (not (equal set-var nested-set-var))
               (tree-find nested-set-var set-sentence))
      (let ((done nil)
            (new-var (make-el-var
                      (symbol-name
                       (missing-larkc 31892))))) ;; likely generate-unique-variable
        (loop until done do
          (if (not (tree-find new-var set-sentence))
              (progn
                (nsubst new-var nested-set-var set-sentence)
                (setf done t))
              (setf new-var (make-el-var
                             (symbol-name
                              (missing-larkc 31893))))))) ;; likely generate-unique-variable
      )
    (make-binary-formula #$CollectionSubsetFn nested-col
                         (make-binary-formula #$TheSetOf nested-set-var
                                              (missing-larkc 10661))))) ;; likely conjoin nested-set-sentence and set-sentence

(defun nested-collectionsubsetfn-expression? (expression)
  "[Cyc] @return boolean; t iff EXPRESSION is of the form
(CollectionSubsetFn (CollectionSubsetFn COL (TheSetOf ?X <blah>))
                                            (TheSetOf ?Y <bleh>))"
  (and (el-formula-p expression)
       (eq #$CollectionSubsetFn (formula-arg0 expression))
       (el-formula-p (formula-arg1 expression))
       (eq #$CollectionSubsetFn (formula-arg0 (formula-arg1 expression)))
       (el-formula-p (formula-arg2 expression))
       (eq #$TheSetOf (formula-arg0 (formula-arg2 expression)))
       (el-formula-p (formula-arg2 (formula-arg1 expression)))
       (eq #$TheSetOf (formula-arg0 (formula-arg2 (formula-arg1 expression))))))

(defun* simplify-redundancies? () (:inline t)
  "[Cyc]"
  *simplify-redundancies?*)

;; (defun simplify-kappa-asent (sentence) ...) -- no body, commented declareFunction
;; (defun simplify-ist-sentence (sentence) ...) -- no body, commented declareFunction

(defun simplify-sequence-variables (formula)
  "[Cyc] @return EL formula; a recursively simplified version of FORMULA wrt sequence variables."
  (let ((*el-symbol-suffix-table* (or *el-symbol-suffix-table*
                                      (make-hash-table :test #'eql :size 32)))
        (*standardize-variables-memory* (or *standardize-variables-memory* nil)))
    (simplify-sequence-variables-1 formula)))

(defun simplify-sequence-variables-1 (formula)
  "[Cyc] A version of @xref simplify-sequence-variables to call if you already have the EL variable namespace bound."
  (when (not (possibly-sentence-p formula))
    (return-from simplify-sequence-variables-1 formula))
  (let ((result nil))
    (if *simplifying-sequence-variables?*
        (setf result formula)
        (if (formula-find-if #'formula-with-sequence-term? formula nil)
            (if (missing-larkc 30666) ;; likely sequence-var-simplifiable? or related check
                (let ((*simplifying-sequence-variables?* t))
                  (setf result (missing-larkc 10689))) ;; likely simplify-sequence-variables-int
                (setf result nil))
            (setf result formula)))
    result))

;; (defun simplify-sequence-variables-int (formula var? seqvar) ...) -- no body, commented declareFunction
;; (defun possible-sequence-var-simplification (formula var?) ...) -- no body, commented declareFunction
;; (defun simplify-sequence-vars-using-kb-arity? () ...) -- no body, commented declareFunction
;; (defun ignore-sequence-var-if-wff (formula seqvar &optional var?) ...) -- no body, commented declareFunction
;; (defun regularize-sequence-var-if-wff (formula seqvar &optional var?) ...) -- no body, commented declareFunction
;; (defun split-sequence-var-if-wff (formula &optional seqvar var? new-seqvar new-formula split-vars) ...) -- no body, commented declareFunction
;; (defun sequence-var-simplifiable? (formula) ...) -- no body, commented declareFunction
;; (defun simplify-transitive-redundancies (conjunction &optional var?) ...) -- no body, commented declareFunction
;; (defun simplify-transitive-redundancies-in-cycl-disjunction (disjunction &optional var?) ...) -- no body, commented declareFunction
;; (defun subsumed-by-another-conjunct? (conjunct conjunction) ...) -- no body, commented declareFunction
;; (defun conjunct-subsumed-by-conjunct? (conjunct1 conjunct2) ...) -- no body, commented declareFunction
;; (defun subsumed-args-by-consts? (pred args1 args2) ...) -- no body, commented declareFunction
;; (defun subsumed-args? (pred args1 args2) ...) -- no body, commented declareFunction
;; (defun simplify-transitive-redundancies-in-disjunction (disjunction) ...) -- no body, commented declareFunction
;; (defun necessary-constraint-dict (conjunction var?) ...) -- no body, commented declareFunction
;; (defun transitive-constraint-dict (conjunction var?) ...) -- no body, commented declareFunction
;; (defun transitive-constraint-raw-info (conjunct) ...) -- no body, commented declareFunction

(defun simplify-transitive-redundancies? ()
  "[Cyc]"
  (and (simplify-redundancies?)
       *simplify-transitive-redundancies?*
       (not *simplifying-redundancies?*)))

;; (defun simplify-transitive-redundancies-old (conjunction var?) ...) -- no body, commented declareFunction
;; (defun simplify-transitive-redundancies-in-disjunction-old (disjunction var?) ...) -- no body, commented declareFunction
;; (defun simplify-number-expression (expression) ...) -- no body, commented declareFunction

;; Setup section

(toplevel
  ;; define-test-case-table-int is elided (macro-helper to nonexistent macro)
  ;; Original: (define-test-case-table simplify-ist-sentence (:test nil :owner nil :classes nil :kb :tiny :working? t) ...)
  )
