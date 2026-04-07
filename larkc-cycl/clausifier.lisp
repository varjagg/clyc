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

(defparameter *canonical-variable-name-stem* "el-var"
  "[Cyc] used for standardizing EL variables in the canonicalizer")

(defparameter *use-cnf-cache?* t
  "[Cyc] Whether to cache the function that converts EL sentences to CNF clausal form")

(defparameter *newly-introduced-universals* :error
  "[Cyc] a temporary stack to record universals introduced by the clausifier")

(defparameter *outermost-implication* :uninitialized
  "[Cyc] bound to the outermost implication in the do-implications recursive descent")

(defparameter *innermost-implication* :uninitialized
  "[Cyc] bound to the innermost implication in the do-implications recursive descent")

(defparameter *eliminate-existential-with-var-only-in-antecedent?* t
  "[Cyc] Temporary control variable, @todo hard-code to t")

(defparameter *quantifier-info-list* nil
  "[Cyc] private dynamic variable used for quantification information")

(deflexical *czer-bad-exponential-threshold* 200000
  "[Cyc] The K^N over which a wff violation will be thrown rather than
descending into exponential madness.")

(defparameter *clausifier-input-sentence* nil
  "[Cyc] Stores the sentence provided as input to el-xnf.  Used while reporting wff violations.")

(defparameter *clausifier-input-mt* nil
  "[Cyc] Stores the mt provided as input to el-xnf.  Used while reporting wff violations.")

(deflexical *cached-cnf-clausal-form-caching-state* nil)

;; Functions (declare section ordering)

(defun do-implications (sentence)
  "[Cyc] Removes implications from SENTENCE."
  (let (result)
    (let ((*outermost-implication* sentence))
      (setf result (do-implications-recursive sentence)))
    result))

(defun do-implications-recursive (sentence)
  "[Cyc] Removes all implications and equivalences from SENTENCE,
returning a logically equivalent sentence.
Converts (#$implies <form1> <form2>) to (#$or (#$not <form1>) <form2>).
Does not simplify nested negations, disjunctions, or conjunctions."
  (cond
    ((encapsulate-formula? sentence)
     (if (missing-larkc 30299) ;; likely handles encapsulated formula implications
         (quantified-sub-sentence sentence)
         (missing-larkc 8799))) ;; likely returns the encapsulated sentence unchanged
    ((not (el-formula-p sentence))
     sentence)
    (t
     (let* ((seqvar (sequence-var sentence))
            (tempformula sentence)
            (sentence-1 (if seqvar
                            (missing-larkc 30654) ;; likely strips sequence var from formula
                            tempformula))
            (result nil))
       (cond
         ((and (el-implication-p sentence-1)
               (el-meets-pragmatic-requirement-p (sentence-arg2 sentence-1)))
          (let (disjunct-1)
            (let ((*innermost-implication* sentence-1))
              (let ((*within-ask* t))
                (setf disjunct-1 (make-negation (funcall-formula-arg #'do-implications-recursive sentence-1 1))))
              (setf result (make-disjunction (list disjunct-1
                                                   (funcall-formula-arg #'do-implications-recursive sentence-1 2)))))))
         ((el-implication-p sentence-1)
          (let (disjunct-1)
            (let ((*innermost-implication* sentence-1))
              (let ((*within-disjunction?* t)
                    (*within-negated-disjunction?* *within-negation?*)
                    (*within-negation?* (not *within-negation?*)))
                (setf disjunct-1 (make-negation (funcall-formula-arg #'do-implications-recursive sentence-1 1))))
              (setf result (make-disjunction (list disjunct-1
                                                   (funcall-formula-arg #'do-implications-recursive sentence-1 2)))))))
         (t
          (setf result (pass-through-if-logical-op-or-quantified #'do-implications-recursive sentence-1))))
       (if seqvar
           (missing-larkc 30604) ;; likely re-adds sequence var to result
           result)))))

;; (defun eliminate-existential-with-var-only-in-antecedent? (arg1 arg2 arg3) ...) -- active declareFunction, no body
;; (defun do-negations (sentence) ...) -- active declareFunction, no body

(defun do-negations-destructive (sentence)
  "[Cyc] A destructive version of @xref do-negations."
  (let* ((seqvar (sequence-var sentence))
         (tempformula sentence)
         (sentence-4 (if seqvar
                         (missing-larkc 30655) ;; likely strips sequence var from formula
                         tempformula))
         (result nil))
    (cond
      ((encapsulate-formula? sentence-4)
       (setf result (missing-larkc 8800))) ;; likely handles encapsulated formula negations
      ((not (el-formula-p sentence-4))
       (setf result sentence-4))
      ((true-negated-var? sentence-4)
       (setf result (missing-larkc 30307))) ;; likely handles negated variable case
      ((true-negated-formula? sentence-4)
       (if (within-disjunction?)
           (setf result (missing-larkc 30308)) ;; likely handles negated formula within disjunction
           (let ((*encapsulate-var-formula?* nil)
                 (*encapsulate-intensional-formula?* nil))
             (setf result (make-unary-formula (formula-operator sentence-4)
                                              (funcall-formula-arg #'do-negations-destructive sentence-4 1))))))
      ((el-implication-p sentence-4)
       (setf result (do-negations-destructive (do-implications sentence-4))))
      ((el-negation-p sentence-4)
       (if (opaque-arg? sentence-4 1)
           (setf result sentence-4)
           (let (new-sentence)
             (let ((*within-negation?* (not *within-negation?*)))
               (setf new-sentence (negation-in sentence-4)))
             (if (el-negation-p new-sentence)
                 (setf result new-sentence)
                 (setf result (do-negations-destructive new-sentence))))))
      (t
       (setf result (pass-through-if-logical-op-or-quantified #'do-negations-destructive sentence-4))))
    (if seqvar
        (missing-larkc 30605) ;; likely re-adds sequence var to result
        result)))

(defun negate-formula (sentence)
  "[Cyc] Negates SENTENCE by using the following transformations:
1. #$True becomes #$False
2. #$False becomes #$True
3. (#$and <form1> <form2>) becomes (#$or (#$not <form1>) (#$not <form2>))
4. (#$or <form1> <form2>) becomes (#$and (#$not <form1>) (#$not <form2>))
5. (#$not <form1>) becomes <form1>, but <form1> is recursively simplified
6. (#$forAll ?X <form1>) becomes (#$thereExists ?X (#$not <form1>))
7. (#$thereExists ?X <form1>) becomes (#$forAll ?X (#$not <form1>))
8. (#$thereExistAtLeast NUM ?X <form1>) becomes (#$thereExistAtMost (- NUM 1) ?X (#$not <form1>))
9. (#$thereExistAtMost NUM ?X <form1>) becomes (#$thereExistAtLeast (+ NUM 1) ?X (#$not <form1>))
10. (#$thereExistExactly NUM ?X <form1>) becomes (#$or (#$thereExistAtLeast (+ NUM 1) ?X <form1>)
                                                       (#$thereExistAtMost  (- NUM 1) ?X <form1>)
Any sentence not meeting any of the above criteria is negated by simply wrapping a #$not around it."
  (cond
    ((eq sentence #$True) #$False)
    ((eq sentence #$False) #$True)
    ((encapsulate-formula? sentence)
     (missing-larkc 30311)) ;; likely negates an encapsulated formula
    ((el-conjunction-p sentence)
     (negate-conjunction sentence))
    ((el-disjunction-p sentence)
     (missing-larkc 30310)) ;; likely negate-disjunction: (#$or ...) -> (#$and (#$not ...) ...)
    ((el-negation-p sentence)
     (let (result)
       (let ((*within-negation?* (not *within-negation?*)))
         (setf result (negation-in (missing-larkc 30320)))) ;; likely (formula-arg1 sentence :regularize) to unwrap the negation
       result))
    ((cycl-universal-p sentence)
     (missing-larkc 30322)) ;; likely negate-universal: (#$forAll ?X form) -> (#$thereExists ?X (#$not form))
    ((el-existential-p sentence)
     (missing-larkc 30312)) ;; likely negate-existential: (#$thereExists ?X form) -> (#$forAll ?X (#$not form))
    ((el-existential-min-p sentence)
     (missing-larkc 30318)) ;; likely negate-existential-min
    ((el-existential-max-p sentence)
     (missing-larkc 30316)) ;; likely negate-existential-max
    ((el-existential-exact-p sentence)
     (missing-larkc 30314)) ;; likely negate-existential-exact
    ((true-negated-var? sentence)
     (missing-larkc 30309)) ;; likely handles negated variable
    ((true-negated-formula? sentence)
     (missing-larkc 30321)) ;; likely handles negated formula
    ((el-implication-p sentence)
     (missing-larkc 4215)) ;; likely handles negation of implication
    (t
     (make-negation sentence))))

(defun negation-in (sentence)
  "[Cyc] Moves a negation inwards by the following transformations:
1. (#$not #$True) becomes #$False
2. (#$not #$False) becomes #$True
3. (#$not (#$and <form1> <form2>)) becomes (#$or (#$not <form1>) (#$not <form2>))
4. (#$not (#$or <form1> <form2>)) becomes (#$and (#$not <form1>) (#$not <form2>))
5. (#$not (#$not <form1>)) becomes <form1>, but <form1> is recursively simplified
6. (#$not (#$forAll ?X <form1>)) becomes (#$thereExists ?X (#$not <form1>))
7. (#$not (#$thereExists ?X <form1>)) becomes (#$forAll ?X (#$not <form1>))
8. (#$not (#$thereExistAtLeast NUM ?X <form1>)) becomes (#$thereExistAtMost (- NUM 1) ?X (#$not <form1>))
9. (#$not (#$thereExistAtMost NUM ?X <form1>)) becomes (#$thereExistAtLeast (+ NUM 1) ?X (#$not <form1>))
10. (#$not (#$thereExistExactly NUM ?X <form1>)) becomes (#$or (#$thereExistAtLeast (+ NUM 1) ?X <form1>)
                                                                (#$thereExistAtMost  (- NUM 1) ?X <form1>)
Note that negated implications or other forms are not simplified.
If this function does make a simplification, it is guaranteed to return something that is not a negation.
If you pass a sentence that is not a negation, it will return that sentence without any changes."
  (if (not (el-negation-p sentence))
      sentence
      (negate-formula (formula-arg1 sentence :regularize))))

;; (defun negate-quantified-sentence (sentence) ...) -- active declareFunction, no body

(defun negate-atomic (sentence)
  "[Cyc] @return EL sentence; negation of SENTENCE.
Assumes that SENTENCE is atomic and does no simplification."
  (make-negation sentence))

;; (defun negate-negation (sentence) ...) -- active declareFunction, no body
;; (defun negate-negations (sentence) ...) -- active declareFunction, no body

(defun negate-conjunction (conjunction)
  "[Cyc] Assumes that CONJUNCTION is a conjunction.
Moves negations inwards by the following transformation:
(#$and <form1> <form2>) becomes (#$or (#$not <form1>) (#$not <form2>))"
  (ndisjoin (mapcar #'negate-formula (formula-args conjunction))))

;; (defun negate-conjunction-destructive (conjunction) ...) -- active declareFunction, no body
;; (defun negate-disjunction-destructive (disjunction) ...) -- active declareFunction, no body
;; (defun negate-universal (sentence) ...) -- active declareFunction, no body
;; (defun negate-existential (sentence) ...) -- active declareFunction, no body
;; (defun negate-existential-min (sentence) ...) -- active declareFunction, no body
;; (defun negate-existential-max (sentence) ...) -- active declareFunction, no body
;; (defun negate-existential-exact (sentence) ...) -- active declareFunction, no body
;; (defun negate-true-sentence (sentence) ...) -- active declareFunction, no body
;; (defun negate-encapsulate-sentence (sentence) ...) -- active declareFunction, no body
;; (defun lift-negation (sentence) ...) -- active declareFunction, no body

(defun czer-explicitify-implicit-quantifiers (sentence)
  "[Cyc] Explicitifies implicit quantifiers in SENTENCE."
  (if (assume-free-vars-are-existentially-bound?)
      (missing-larkc 30286) ;; likely czer-explicitify-implicit-existential-quantifiers
      (czer-explicitify-implicit-universal-quantifiers sentence)))

(defun czer-explicitify-implicit-universal-quantifiers (sentence)
  "[Cyc] Wraps SENTENCE in #$forAll statements (if needed) to quantify all the free variables within SENTENCE.
Should appear within a binding of *newly-introduced-universals*
@see explicitify-implicit-universal-quantifiers"
  (let ((free-vars (sentence-free-variables sentence)))
    (dolist (var free-vars)
      (setf sentence (make-universal var sentence))
      (when (listp *newly-introduced-universals*)
        (push var *newly-introduced-universals*))))
  sentence)

;; (defun czer-explicitify-implicit-existential-quantifiers (sentence) ...) -- active declareFunction, no body

(defun assume-free-vars-are-existentially-bound? ()
  "[Cyc] Returns whether free variables should be assumed to be existentially bound."
  *assume-free-vars-are-existentially-bound?*)

;; (defun standardize-sentence-variables (sentence) ...) -- active declareFunction, no body

(defun standardize-variables (sentence)
  "[Cyc] Renames all variables into a canonical order, with the innermost variables having smaller indices.
Assumes that all universal quantification is explicit.
Assumes that the EL variable namespace is bound.
@todo check if the variables are already named with a prefix of *canonical-variable-name-stem*"
  (when (ground? sentence)
    (return-from standardize-variables sentence))
  (let* ((seqvar (sequence-var sentence))
         (tempformula sentence)
         (sentence-5 (if seqvar
                         (missing-larkc 30656) ;; likely strips sequence var from formula
                         tempformula))
         (result nil))
    (initialize-symbol-suffix-table sentence-5)
    (setf result (recursively-standardize-variables sentence-5))
    (setf result (el-nununiquify-vars-int result t))
    (if seqvar
        (missing-larkc 30606) ;; likely re-adds sequence var to result
        result)))

(defun recursively-standardize-variables (sentence)
  "[Cyc] Renames all quantified variables into a canonical order, with the innermost variables having smaller indices.
Variables at the same depth are ordered from left to right.
Assumes that *standardize-variables-memory* is bound.
Also assumes that implications and other weird logical operators have been removed."
  (cond
    ((not (el-formula-p sentence))
     sentence)
    ((or (fast-escape-quote-term-p sentence)
         (fast-quasi-quote-term-p sentence))
     (let (standardized)
       (let ((*inside-quote* nil))
         (setf standardized (make-unary-formula (formula-arg0 sentence)
                                                (recursively-standardize-variables (formula-arg1 sentence)))))
       standardized))
    ((fast-quote-term-p sentence)
     (if (not (tree-find-if #'cyc-var? sentence))
         sentence
         (let (standardized)
           (let ((*inside-quote* t))
             (setf standardized (make-unary-formula #$Quote
                                                    (recursively-standardize-variables (formula-arg1 sentence)))))
           standardized)))
    ((possibly-el-regularly-quantified-sentence-p sentence)
     (multiple-value-bind (quantifier old-var subform)
         (unmake-binary-formula sentence)
       (declare (ignore subform))
       (let* ((standardized-subform (funcall-formula-arg 'recursively-standardize-variables sentence 2))
              (new-var (el-uniquify-standardize old-var))
              (replace-old-var (el-var-without-quote old-var))
              (replace-new-var (el-var-without-quote new-var))
              (standardized nil))
         (remember-variable-rename replace-old-var replace-new-var)
         (let ((*canonicalize-variables?* nil))
           (setf standardized (make-binary-formula quantifier new-var
                                                   (expression-nsubst-free-vars replace-new-var replace-old-var standardized-subform))))
         standardized)))
    ((el-bounded-existential-p sentence)
     (multiple-value-bind (quantifier bound old-var subform)
         (missing-larkc 30693) ;; likely unmake-quaternary-formula for bounded existentials
       (declare (ignore subform))
       (let* ((standardized-subform (funcall-formula-arg 'recursively-standardize-variables sentence 3))
              (new-var (missing-larkc 30294)) ;; likely el-uniquify-standardize for bounded existential var
              (replace-old-var (missing-larkc 30297)) ;; likely el-var-without-quote on old-var
              (replace-new-var (missing-larkc 30298)) ;; likely el-var-without-quote on new-var
              (standardized nil))
         (declare (ignore old-var))
         (missing-larkc 30324) ;; likely remember-variable-rename for bounded existential
         (let ((*canonicalize-variables?* nil))
           (setf standardized (make-ternary-formula quantifier bound new-var
                                                    (missing-larkc 29702)))) ;; 4th arg likely expression-nsubst-free-vars result
         standardized)))
    ((czer-scoping-formula? sentence)
     (let* ((scoped-vars (missing-larkc 30890)) ;; likely scoping-variables from sentence
            (unique-vars (mapcar #'el-uniquify-standardize scoped-vars))
            (scoping-args (missing-larkc 30891)) ;; likely scoping-arg-positions
            (replace-scoped-vars (mapcar #'el-var-without-quote scoped-vars))
            (replace-unique-vars (mapcar #'el-var-without-quote unique-vars))
            (new-sentence nil))
       (declare (ignore replace-scoped-vars replace-unique-vars))
       (let ((terms (formula-terms sentence :ignore))
             (argnum 0))
         (dolist (arg terms)
           (if (member? argnum scoping-args)
               (push arg new-sentence)
               (push (funcall-formula-arg 'recursively-standardize-variables sentence argnum) new-sentence))
           (setf argnum (1+ argnum))))
       (missing-larkc 30325) ;; likely remember-variables-rename for scoping vars
       (nreverse (missing-larkc 29720)))) ;; likely expression-nsubst for scoped vars
    (t
     (pass-through-if-relation-syntax 'recursively-standardize-variables sentence))))

(defun el-uniquify-standardize (var)
  "[Cyc] Standardizes VAR by uniquifying it, handling quote contexts."
  (cond
    ((not *inside-quote*)
     (el-uniquify var))
    ((or (fast-escape-quote-term-p var)
         (fast-quasi-quote-term-p var))
     (make-unary-formula (formula-arg0 var) (el-uniquify (formula-arg1 var))))
    (t
     var)))

(defun el-var-without-quote (var)
  "[Cyc] Returns VAR stripped of any quote wrapper."
  (if (or (fast-escape-quote-term-p var)
          (fast-quasi-quote-term-p var))
      (formula-arg1 var)
      var))

(defun remember-variable-rename (old-var new-var)
  "[Cyc] Remembers which variables are being renamed, and what their new names are.
Assumes that *standardize-variables-memory* is bound."
  (push (cons old-var new-var) *standardize-variables-memory*)
  nil)

;; (defun remember-variables-rename (old-vars new-vars) ...) -- active declareFunction, no body

(defun el-uniquify (var)
  "[Cyc] Assumes that *el-symbol-suffix-table* is bound."
  (multiple-value-bind (integer symbol)
      (extract-name-uniquifying-post-hyphen-integer var)
    (when (null symbol)
      (setf symbol var))
    (when (null integer)
      (setf integer 0))
    (let ((n (gethash symbol *el-symbol-suffix-table*)))
      (when (null n)
        (setf n -1))
      (setf n (max n integer))
      (setf n (+ n 1))
      (setf (gethash symbol *el-symbol-suffix-table*) n)
      (let ((unique-string (if (zerop n)
                               (format-nil-a (variable-name symbol))
                               (concatenate 'string
                                            (format-nil-a-no-copy (variable-name symbol))
                                            "-"
                                            (format-nil-a-no-copy (object-to-string n))))))
        (if (keyword-var? symbol)
            (make-keyword-var unique-string)
            (make-el-var unique-string))))))

(defun existentials-out (sentence)
  "[Cyc] Removes all existentials by replacing them with Skolem constants or Skolem sentences."
  (when *turn-existentials-into-skolems?*
    (when (not (tree-find-if #'cyc-const-general-existential-operator-p sentence))
      (return-from existentials-out sentence))
    (let ((error
            (catch :too-many-sequence-vars-in-skolem-scope
              (catch :ambiguous-var-type-in-skolem-scope
                (catch :quantified-sequence-variable
                  (let ((*quantifier-info-list* nil))
                    (setf sentence (existentials-out-int sentence)))
                  nil)
                nil)
              nil)))
      (when error
        (when *accumulating-wff-violations?*
          (missing-larkc 8023)) ;; likely note-wff-violation
        (return-from existentials-out nil))))
  sentence)

(defun existentials-out-int (sentence)
  "[Cyc] Removes all existentials by replacing them with Skolem constants or Skolem sentences.
Keeps a list of the quantifiers whose scope we are within to determine the free variables in the Skolem sentences.
Assumes that *quantifier-info-list* is bound."
  (let ((result sentence))
    (let ((*quantifier-info-list* *quantifier-info-list*)
          (*noting-at-violations?* nil)
          (*accumulating-at-violations?* nil)
          (*noting-wff-violations?* nil)
          (*accumulating-wff-violations?* nil))
      (cond
        ((cycl-universal-p sentence)
         (multiple-value-bind (quantifier var subform)
             (unmake-binary-formula sentence)
           (push (list quantifier nil var
                       (sentence-free-term-variables subform)
                       (sentence-free-sequence-variables subform))
                 *quantifier-info-list*)
           (setf result (make-universal var (funcall-formula-arg #'existentials-out-int sentence 2)))))
        ((el-existential-p sentence)
         (multiple-value-bind (quantifier var subform)
             (unmake-binary-formula sentence)
           (push (list quantifier nil var
                       (sentence-free-term-variables subform)
                       (sentence-free-sequence-variables subform))
                 *quantifier-info-list*)
           (setf result (funcall-formula-arg #'existentials-out-int sentence 2))))
        ((el-bounded-existential-p sentence)
         (multiple-value-bind (quantifier num var subform)
             (unmake-ternary-formula sentence)
           (push (list quantifier num var
                       (sentence-free-term-variables subform)
                       (sentence-free-sequence-variables subform))
                 *quantifier-info-list*)
           (setf result (funcall-formula-arg #'existentials-out-int sentence 3))))
        ((el-logical-operator-formula-p sentence)
         (setf result (pass-through-if-logical-op #'existentials-out-int sentence)))
        ((and (within-ask?)
              (ist-sentence-p sentence))
         (multiple-value-bind (ist mt subsentence)
             (unmake-binary-formula sentence)
           (declare (ignore ist))
           (let ((canonical-subsentence (existentials-out-int subsentence)))
             (setf result (skolemize-atomic-sentence (make-ist-sentence mt canonical-subsentence)
                                                     *quantifier-info-list*)))))
        ((cycl-atomic-sentence-p sentence)
         (setf result (skolemize-atomic-sentence sentence *quantifier-info-list*)))
        ((el-non-formula-sentence-p sentence)
         (setf result (skolemize-atomic-sentence sentence *quantifier-info-list*)))
        (t
         (el-error 4 "Unexpected sentence type in existentials-out-int: ~S" sentence))))
    result))

(defun skolemize-atomic-sentence (sentence quantifier-info-list)
  "[Cyc] Skolemizes an atomic sentence given the quantifier info list."
  (let ((result sentence))
    (do ((quantifier-info-list-in-scope quantifier-info-list (rest quantifier-info-list-in-scope)))
        ((null quantifier-info-list-in-scope))
      (let* ((curr-quant-info (first quantifier-info-list-in-scope))
             (curr-quant (first curr-quant-info))
             (curr-num (second curr-quant-info))
             (curr-var (third curr-quant-info))
             (curr-free-term-vars (fourth curr-quant-info))
             (curr-free-sequence-vars (fifth curr-quant-info)))
        (when (cyc-const-general-existential-operator-p curr-quant)
          (setf result (skolemize-variable result curr-quant curr-num curr-var
                                           curr-free-term-vars curr-free-sequence-vars
                                           quantifier-info-list-in-scope)))))
    result))

(defun skolemize-variable (sentence curr-quant curr-num curr-var curr-free-term-vars curr-free-sequence-vars quantifier-info-list-in-scope)
  "[Cyc] Skolemizes a single variable in a sentence."
  (cond
    ((drop-all-existentials?)
     sentence)
    ((and (occurs-as-sequence-variable? curr-var sentence)
          (forbid-quantified-sequence-variables?))
     (throw :quantified-sequence-variable
       (list :quantified-sequence-variable curr-var sentence)))
    (t
     (let ((curr-dependent-term-vars nil)
           (curr-dependent-sequence-vars nil))
       (dolist (quant-info quantifier-info-list-in-scope)
         (let ((quant (first quant-info))
               (var (third quant-info))
               (free-term-vars (fourth quant-info))
               (free-sequence-vars (fifth quant-info)))
           (when (eq #$forAll quant)
             (let ((var-status (determine-skolem-var-status var curr-free-term-vars free-term-vars
                                                            curr-free-sequence-vars free-sequence-vars)))
               (cond
                 ((eql var-status :neither))
                 ((eql var-status :term)
                  (push var curr-dependent-term-vars))
                 ((eql var-status :seq)
                  (push var curr-dependent-sequence-vars))
                 ((eql var-status :both)
                  (throw :ambiguous-var-type-in-skolem-scope
                    (list :ambiguous-var-type-in-skolem-scope var curr-var sentence)))
                 ((eql var-status :undetermined)
                  (el-error 1 "Skolemizer failed to classify variable ~a in sentence ~a~%" var sentence)))))))
       (cond
         ((> (length curr-dependent-sequence-vars) 1)
          (throw :too-many-sequence-vars-in-skolem-scope
            (list :too-many-sequence-vars-in-skolem-scope curr-var curr-dependent-sequence-vars)))
         ((and (leave-skolem-constants-alone?)
               (null curr-dependent-term-vars)
               (null curr-dependent-sequence-vars))
          sentence)
         (t
          (expression-nsubst-free-vars
           (make-skolem-fn-fn curr-var curr-dependent-term-vars curr-quant curr-num
                              (first curr-dependent-sequence-vars))
           curr-var
           (copy-expression sentence)
           #'equal)))))))

(defun determine-skolem-var-status (var subsent-free-term-vars free-term-vars-in-scope subsent-free-seqvars free-seqvars-in-scope)
  "[Cyc] @param VAR; the universally scoped variable whose status we need to determine wrt an existential.
@return keywordp; :neither, :term, :seq, :both, or :undetermined"
  (let ((var-status :undetermined))
    (cond
      ((member var subsent-free-term-vars)
       (if (or (member? var subsent-free-seqvars)
               (member var free-seqvars-in-scope))
           (setf var-status :both)
           (setf var-status :term)))
      ((member var subsent-free-seqvars)
       (if (member? var free-term-vars-in-scope)
           (setf var-status :both)
           (setf var-status :seq)))
      (t
       (if *minimal-skolem-arity?*
           (setf var-status :neither)
           (cond
             ((member var free-term-vars-in-scope)
              (if (member? var free-seqvars-in-scope)
                  (setf var-status :both)
                  (setf var-status :term)))
             ((member var free-seqvars-in-scope)
              (setf var-status :seq))
             (t
              (setf var-status :neither))))))
    var-status))

(defun make-skolem-fn-fn (var dependent-term-vars quant num dependent-sequence-var)
  "[Cyc] @param DEPENDENT-SEQUENCE-VAR; nil or cycl-variable-p"
  (if (and (null dependent-term-vars)
           (null dependent-sequence-var)
           *use-skolem-constants?*)
      (progn
        (warn "skolem constants not yet supported")
        nil)
      (let ((result nil))
        (cond
          ((eq #$thereExists quant)
           (setf result (make-ternary-formula #$SkolemFunctionFn dependent-term-vars var dependent-sequence-var)))
          (t
           (el-error 4 "make-skolem-fn-fn doesn't know how to handle the quantifier ~S" quant)
           (return-from make-skolem-fn-fn nil)))
        result)))

(defun drop-all-existentials? ()
  "[Cyc] @return booleanp; whether the clausifier should, when canonicalizing
existentials, simply drop them (like it does by default during asks)?"
  (or (and *within-ask*
           (not *skolemize-during-asks?*))
      *drop-all-existentials?*))

(defun leave-skolem-constants-alone? ()
  "[Cyc] Returns whether to leave skolem constants alone."
  (or (drop-all-existentials?)
      *leave-skolem-constants-alone?*))

(defun forbid-quantified-sequence-variables? ()
  "[Cyc] Returns whether quantified sequence variables are forbidden."
  (cond
    ((eq t *forbid-quantified-sequence-variables?*) t)
    ((null *forbid-quantified-sequence-variables?*) nil)
    ((eq :assert-only *forbid-quantified-sequence-variables?*)
     (within-assert?))
    (t
     (error "Unexpected value for *forbid-quantified-sequence-variables?*: ~s"
            *forbid-quantified-sequence-variables?*))))

(defun universals-out (sentence)
  "[Cyc] removes all #$forAll statements from SENTENCE, unless they are inside an atomic sentence.
Assumes that the only logical operators in SENTENCE are #$forAll, #$and, #$or, and #$not,
and that #$not only appears around an atomic sentence.
Also assumes that the outermost #$ist's have been removed."
  (cond
    ((cycl-universal-p sentence)
     (let ((result (funcall-formula-arg 'universals-out sentence (quantified-sub-sentence-argnum sentence))))
       (cond
         (*implicitify-universals?*
          result)
         ((not (listp *newly-introduced-universals*))
          result)
         ((member (quantified-var sentence) *newly-introduced-universals*)
          result)
         (t
          (make-universal (quantified-var sentence) result)))))
    ((or (el-conjunction-p sentence)
         (el-disjunction-p sentence))
     (pass-through-if-junction 'universals-out sentence))
    ((or (possibly-el-quantified-sentence-p sentence)
         (el-logical-operator-formula-p sentence))
     sentence)
    ((cycl-literal-p sentence)
     sentence)
    ((el-non-formula-sentence-p sentence)
     sentence)
    (t
     (el-error 4 "Got the unexpected sentence ~S in universals-out." sentence)
     sentence)))

(defun disjunctions-in (sentence)
  "[Cyc] Moves disjunctions inwards inside SENTENCE."
  (if (bad-exponential-disjunction? sentence)
      (missing-larkc 30304) ;; likely handle-bad-exponential-disjunction
      (disjunctions-in-int sentence)))

(defun disjunctions-in-int (sentence)
  "[Cyc] Moves disjunctions inwards inside SENTENCE by repeatedly applying the following transformation:
(#$or <form1> (#$and <form2> <form3>)) becomes (#$and (#$or <form1> <form2>) (#$or <form1> <form3>)).
Assumes that the only logical operators in SENTENCE are #$and, #$or, and #$not,
and that #$not only encloses atomic sentences.
The order is scrambled when the disjunctions are pushed inwards.
@note this is exponential in the worst case."
  (let ((result nil))
    (let ((*noting-at-violations?* nil)
          (*accumulating-at-violations?* nil)
          (*noting-wff-violations?* nil)
          (*accumulating-wff-violations?* nil))
      (cond
        ((el-conjunction-p sentence)
         (setf result (nmap-formula-args 'disjunctions-in sentence)))
        ((el-disjunction-p sentence)
         (if (opaque-arg? sentence 1)
             (setf result sentence)
             (progn
               (setf sentence (nmap-formula-args 'disjunctions-in sentence))
               (let ((nested-conjunction (first-conjunction (formula-args sentence))))
                 (if nested-conjunction
                     (let ((other-disjuncts (delete nested-conjunction (formula-args sentence))))
                       (if other-disjuncts
                           (let ((new-conjuncts nil))
                             (dolist (conjunct (formula-args nested-conjunction :ignore))
                               (let ((new-disjuncts (cons conjunct other-disjuncts)))
                                 (push (disjoin new-disjuncts) new-conjuncts)))
                             (setf result (missing-larkc 10673))) ;; likely (nconjoin (nmapcar 'disjunctions-in new-conjuncts))
                           (setf result nested-conjunction)))
                     (setf result sentence))))))
        ((or (possibly-el-quantified-sentence-p sentence)
             (el-logical-operator-formula-p sentence))
         (setf result sentence))
        ((el-literal-p sentence)
         (setf result sentence))
        ((el-non-formula-sentence-p sentence)
         (setf result sentence))
        (t
         (el-error 4 "Got the unexpected sentence ~S in disjunctions-in." sentence)
         (setf result sentence))))
    result))

(defun first-conjunction (sentences)
  "[Cyc] Returns the first conjunction in the list SENTENCES."
  (find-if #'el-conjunction-p sentences))

(defun bad-exponential-disjunction? (sentence)
  "[Cyc] @return booleanp; whether SENTENCE is too explosive to be put
into CNF using the straightforward algorithm."
  (when (el-disjunction-p sentence)
    (bad-exponential-sentence? sentence #'el-conjunction-p)))

;; (defun handle-bad-exponential-disjunction (sentence) ...) -- active declareFunction, no body

(defun bad-exponential-sentence? (sentence arg-test-func)
  "[Cyc] Checks whether SENTENCE is too explosive for normal form conversion."
  (let ((n (count-if arg-test-func (formula-args sentence))))
    (when (>= n 5)
      (let ((problem-args (remove-if-not arg-test-func (formula-args sentence))))
        (when problem-args
          (let ((k (missing-larkc 30283))) ;; likely average-arity of problem-args
            (when (and k (> k 1))
              (let ((k^n (expt k n)))
                (when (> k^n *czer-bad-exponential-threshold*)
                  (return-from bad-exponential-sentence? t)))))))))
  nil)

;; (defun average-arity (sentences) ...) -- active declareFunction, no body

(defun force-into-cnf (sentence)
  "[Cyc] Assumes that SENTENCE is a subset of CNF (either in cnf, a disjunction, or a literal)
and returns a version of SENTENCE that is in strict CNF form.
For example, (#$genls #$Dog #$Mammal) would be forced into (#$and (#or (#$genls #$Dog #$Mammal))).
Also, it scrambles the order of the arguments inside the conjunctions and disjunctions."
  (unless (el-conjunction-p sentence)
    (setf sentence (make-conjunction (list sentence))))
  (let ((new-args nil))
    (dolist (arg (formula-args sentence :ignore))
      (if (el-disjunction-p arg)
          (push arg new-args)
          (push (make-disjunction (list arg)) new-args)))
    (make-conjunction new-args)))

(defun cnf-operators-out (sentence)
  "[Cyc] @param sentence EL sentence; a conjunction of possibly disjoined literals.
@return clauses; a list of cnf-clauses, each of which is a pair: ( (<neg-lits> <pos-lits>) ...)
Removes #$and, #$or and #$not while translating to clause form."
  (when (or (null sentence)
            (eq sentence #$True)
            (eq sentence #$False))
    (return-from cnf-operators-out sentence))
  (when (el-var? sentence)
    (setf sentence (missing-larkc 8802))) ;; likely wraps a var sentence into proper form
  (setf sentence (force-into-cnf sentence))
  (unless (el-conjunction-p sentence)
    (el-error 4 "~s is not a conjunction, so it is not a CNF sentence." sentence)
    (return-from cnf-operators-out nil))
  (let ((clause-list nil))
    (dolist (conjunct (formula-args sentence :ignore))
      (unless (el-disjunction-p conjunct)
        (el-error 4 "~s is not a disjunction, so ~S is not a CNF sentence." conjunct sentence)
        (return-from cnf-operators-out nil))
      (push (package-xnf-clause (formula-args conjunct)) clause-list))
    (nreverse clause-list)))

;; (defun package-cnf-clause (clause) ...) -- active declareFunction, no body

(defun npackage-cnf-clause (clause)
  "[Cyc] A destructive version of @xref package-cnf-clause."
  (npackage-xnf-clause clause))

(defun conjunctions-in (sentence)
  "[Cyc] Moves conjunctions inwards inside SENTENCE."
  (if (bad-exponential-conjunction? sentence)
      (missing-larkc 30303) ;; likely handle-bad-exponential-conjunction
      (conjunctions-in-int sentence)))

(defun conjunctions-in-int (sentence)
  "[Cyc] Moves conjunctions inwards inside SENTENCE by repeatedly applying the following transformation:
(#$and <form1> (#$or <form2> <form3>)) becomes (#$or (#$and <form1> <form2>) (#$and <form1> <form3>)).
Assumes that the only logical operators in SENTENCE are #$and, #$or, and #$not,
and that #$not only encloses atomic sentences.
The order is scrambled when the conjunctions are pushed inwards.
@note this is exponential in the worse case, see disjunctions-in for details."
  (let ((result nil))
    (let ((*noting-at-violations?* nil)
          (*accumulating-at-violations?* nil)
          (*noting-wff-violations?* nil)
          (*accumulating-wff-violations?* nil))
      (cond
        ((el-disjunction-p sentence)
         (setf result (nmap-formula-args 'conjunctions-in sentence)))
        ((el-conjunction-p sentence)
         (if (opaque-arg? sentence 1)
             (setf result sentence)
             (progn
               (setf sentence (nmap-formula-args 'conjunctions-in sentence))
               (let ((nested-disjunction (first-disjunction (formula-args sentence))))
                 (if nested-disjunction
                     (let ((other-conjuncts (delete nested-disjunction (formula-args sentence)
                                                    :test #'equal)))
                       (if other-conjuncts
                           (let ((new-disjuncts nil))
                             (dolist (disjunct (formula-args nested-disjunction :ignore))
                               (let ((new-conjuncts (cons disjunct other-conjuncts)))
                                 (push (missing-larkc 10655) new-disjuncts))) ;; likely (conjoin new-conjuncts)
                             (setf result (ndisjoin (nmapcar #'conjunctions-in new-disjuncts))))
                           (setf result nested-disjunction)))
                     (setf result sentence))))))
        ((or (possibly-el-quantified-sentence-p sentence)
             (el-logical-operator-formula-p sentence))
         (setf result sentence))
        ((el-literal-p sentence)
         (setf result sentence))
        ((el-non-formula-sentence-p sentence)
         (setf result sentence))
        (t
         (el-error 4 "Got the unexpected formula ~S in conjunctions-in." sentence)
         (setf result sentence))))
    result))

(defun first-disjunction (sentences)
  "[Cyc] Returns the first disjunction in the list SENTENCES."
  (find-if #'el-disjunction-p sentences))

(defun bad-exponential-conjunction? (sentence)
  "[Cyc] @return booleanp; whether SENTENCE is too explosive to be put
into DNF using the straightforward algorithm."
  (when (el-conjunction-p sentence)
    (bad-exponential-sentence? sentence #'el-disjunction-p)))

;; (defun handle-bad-exponential-conjunction (sentence) ...) -- active declareFunction, no body

(defun force-into-dnf (sentence)
  "[Cyc] Assumes that SENTENCE is a subset of DNF (either in dnf, a conjunction, or a literal)
and returns a version of SENTENCE that is in strict DNF form.
For example, (#$genls #$Dog #$Mammal) would be forced into (#$or (#$and (#$genls #$Dog #$Mammal))).
Also, it scrambles the order of the arguments inside the disjunctions and conjunctions.
@hack this function is dumb."
  (unless (el-disjunction-p sentence)
    (setf sentence (make-disjunction (list sentence))))
  (let ((new-args nil))
    (dolist (arg (formula-args sentence :ignore))
      (if (el-conjunction-p arg)
          (push arg new-args)
          (push (make-conjunction (list arg)) new-args)))
    (make-disjunction new-args)))

(defun dnf-operators-out (sentence)
  "[Cyc] @param sentence EL sentence; a disjunction of possibly conjoined literals.
@return clauses; a list of dnf-clauses, each of which is a pair: ( (<neg-lits> <pos-lits>) ...)
Removes #$or, #$and and #$not while translating to clause form."
  (when (or (null sentence)
            (eq sentence #$True)
            (eq sentence #$False))
    (return-from dnf-operators-out sentence))
  (when (el-var? sentence)
    (setf sentence (missing-larkc 8803))) ;; likely wraps a var sentence into proper form
  (setf sentence (force-into-dnf sentence))
  (unless (el-disjunction-p sentence)
    (el-error 4 "~s is not a disjunction, so it is not a DNF sentence." sentence)
    (return-from dnf-operators-out nil))
  (let ((clause-list nil))
    (dolist (disjunct (formula-args sentence :ignore))
      (unless (el-conjunction-p disjunct)
        (el-error 4 "~s is not a conjunction, so ~S is not a DNF sentence." disjunct sentence)
        (return-from dnf-operators-out nil))
      (push (package-xnf-clause (formula-args disjunct)) clause-list))
    (nreverse clause-list)))

;; (defun package-dnf-clause (clause) ...) -- active declareFunction, no body

(defun clausifier-input-sentence ()
  "[Cyc] Returns the clausifier input sentence."
  *clausifier-input-sentence*)

(defun clausifier-input-mt ()
  "[Cyc] Returns the clausifier input mt."
  *clausifier-input-mt*)

(defun el-xnf (sentence mt)
  "[Cyc] Transforms an EL sentence so that it is ready to be put into either CNF or DNF form.
At the end of this step, the only operators in SENTENCE will be #$and, #$or, and #$not,
and #$not will only enclose atomic sentences.
Most transformations are syntactic except for the precanonicalizations.
@return 0 EL sentence
Assumes the EL var namespace is bound."
  (let ((*clausifier-input-sentence* sentence)
        (*clausifier-input-mt* mt))
    (multiple-value-setq (sentence mt)
      (el-xnf-int sentence mt))
    (multiple-value-setq (sentence mt)
      (postcanonicalizations sentence mt)))
  (setf sentence (simplify-cycl-sentence-syntax sentence))
  (values sentence mt))

(defun el-xnf-int (sentence mt)
  "[Cyc] Internal implementation of el-xnf."
  (multiple-value-setq (sentence mt)
    (precanonicalizations sentence mt))
  (setf sentence (simplify-cycl-sentence-syntax sentence))
  (setf sentence (do-implications sentence))
  (setf sentence (simplify-cycl-sentence-syntax sentence))
  (setf sentence (do-negations-destructive sentence))
  (setf sentence (standardize-variables sentence))
  (let ((*newly-introduced-universals* nil))
    (setf sentence (czer-explicitify-implicit-quantifiers sentence))
    (setf sentence (existentials-out sentence))
    (setf sentence (universals-out sentence)))
  (values sentence mt))

;; (defun package-xnf-clauses (clauses) ...) -- active declareFunction, no body

(defun package-xnf-clause (clause)
  "[Cyc] @param clause list; a list of literals.
Goes through CLAUSE looking for negated atomic sentences.
It puts them into <neg-lits> and puts the rest into <pos-lits>.
@return list; (<neg-lits> <pos-lits>)"
  (let ((neg-lits (mapcar #'formula-arg1 (el-negative-sentences clause)))
        (pos-lits (el-positive-sentences clause)))
    (make-xnf neg-lits pos-lits)))

(defun npackage-xnf-clause (clause)
  "[Cyc] A destructive version of @xref package-xnf-clause."
  (let ((neg-lits (nmapcar #'formula-arg1 (el-negative-sentences clause)))
        (pos-lits (el-positive-sentences clause)))
    (make-xnf neg-lits pos-lits)))

(defun canon-fast-gaf? (sentence mt)
  "[Cyc] Tests whether SENTENCE is a fast GAF that can bypass full canonicalization."
  (let* ((seqvar (sequence-var sentence))
         (tempformula (if seqvar
                         (append (missing-larkc 30657) ;; likely formula-without-sequence-var
                                 (list seqvar))
                         sentence))
         (sentence-12 tempformula))
    (and (el-formula-p sentence-12)
         (not (find-if #'el-formula-p sentence-12))
         (not (find-if #'el-var? sentence-12))
         (predicate? (formula-arg0 sentence-12))
         (not (precanonicalizations? sentence-12 mt t)))))

(defun el-cnf (sentence mt)
  "[Cyc] Constructively transforms an EL sentence into conjunctive normal form.
Returns a well-formed EL sentence, or NIL if there was an error.
Semantic checks are performed only at the beginning and end - all internal processing is purely syntactic.
@return 0 EL sentence"
  (let ((*el-symbol-suffix-table* (or *el-symbol-suffix-table*
                                      (make-hash-table :size 32 :test #'eql)))
        (*standardize-variables-memory* (or *standardize-variables-memory* nil)))
    (multiple-value-setq (sentence mt)
      (el-cnf-int sentence mt nil)))
  (values sentence mt))

(defun el-cnf-destructive (sentence mt)
  "[Cyc] Destructively transforms an EL sentence into conjunctive normal form.
Returns a well-formed EL sentence, or NIL if there was an error.
Semantic checks are performed only at the beginning and end - all internal processing is purely syntactic.
@return 0 EL sentence
Assumes the EL variable namespace is bound."
  (el-cnf-int sentence mt t))

(defun el-cnf-int (sentence mt destructive?)
  "[Cyc] Assumes the EL variable namespace is bound."
  (unless destructive?
    (setf sentence (copy-sentence sentence)))
  (if (canon-fast-gaf? sentence mt)
      (setf sentence (simplify-cycl-literal-syntax sentence))
      (progn
        (multiple-value-setq (sentence mt)
          (el-xnf sentence mt))
        (if (within-wff?)
            (setf sentence (disjunctions-in sentence))
            (let ((error (catch :bad-exponential-disjunction
                           (setf sentence (disjunctions-in sentence))
                           nil)))
              (when error
                (setf sentence nil))))
        (setf sentence (simplify-cycl-sentence-syntax sentence))))
  (values sentence mt))

;; (defun el-dnf (sentence mt) ...) -- active declareFunction, no body

(defun el-dnf-destructive (sentence mt)
  "[Cyc] Destructively transforms an EL sentence into disjunctive normal form.
Returns a well-formed EL sentence, or NIL if there was an error.
Semantic checks are performed only at the beginning and end - all internal processing is purely syntactic.
@return 0 EL sentence
Assumes the EL variable namespace is bound."
  (el-dnf-int sentence mt t))

(defun el-dnf-int (sentence mt destructive?)
  "[Cyc] Assumes the EL variable namespace is bound."
  (unless destructive?
    (setf sentence (copy-sentence sentence)))
  (if (canon-fast-gaf? sentence mt)
      (setf sentence (simplify-cycl-literal-syntax sentence))
      (progn
        (multiple-value-setq (sentence mt)
          (el-xnf sentence mt))
        (if (within-wff?)
            (setf sentence (conjunctions-in sentence))
            (let ((error (catch :bad-exponential-conjunction
                           (setf sentence (conjunctions-in sentence))
                           nil)))
              (when error
                (setf sentence nil))))
        (setf sentence (simplify-cycl-sentence-syntax sentence))))
  (values sentence mt))

;; (defun leading-universal-variables (sentence mt) ...) -- active declareFunction, no body
;; (defun leading-universal-variables-1 (sentence) ...) -- active declareFunction, no body
;; (defun sort-vars (vars) ...) -- active declareFunction, no body
;; (defun distribute-conjunction (sentence mt &optional conjuncts) ...) -- active declareFunction, no body
;; (defun clausal-form (sentence mt &optional direction) ...) -- active declareFunction, no body

(defun cnf-clausal-form (sentence mt)
  "[Cyc] @return 0 EL sentence; the CNF form of the EL sentence SENTENCE."
  (if *use-cnf-cache?*
      (missing-larkc 30284) ;; likely cached-cnf-clausal-form
      (cnf-clausal-form-int sentence mt)))

(defun clear-cached-cnf-clausal-form ()
  "[Cyc] Clears the cached-cnf-clausal-form caching state."
  (let ((cs *cached-cnf-clausal-form-caching-state*))
    (when cs
      (caching-state-clear cs)))
  nil)

;; (defun remove-cached-cnf-clausal-form (sentence mt) ...) -- active declareFunction, no body
;; (defun cached-cnf-clausal-form-internal (sentence mt) ...) -- active declareFunction, no body
;; (defun cached-cnf-clausal-form (sentence mt) ...) -- active declareFunction, no body

(defun cnf-clausal-form-int (sentence mt)
  "[Cyc] Internal implementation of cnf-clausal-form."
  (multiple-value-bind (cnf new-mt)
      (el-cnf sentence mt)
    (values (cnf-operators-out cnf) new-mt)))

;; (defun dnf-clausal-form (sentence mt) ...) -- active declareFunction, no body

;; Setup

(toplevel
  (note-globally-cached-function 'cached-cnf-clausal-form))
