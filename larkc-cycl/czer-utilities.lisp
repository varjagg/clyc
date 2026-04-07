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

;; (defun some-canonicalizer-directive-assertions? (relation &optional mt) ...) -- no body, active decl commented in Java (1 1)

(defun some-canonicalizer-directive-assertions-somewhere? (relation)
  "[Cyc] Return T iff RELATION is known to have any canonicalizer-directive assertions stated about it at all."
  (when (fort-p relation)
    (some (lambda (czer-pred)
            (some-pred-assertion-somewhere? czer-pred relation 1))
          *canonicalizer-directive-predicates*)))

(defun canonicalizer-directive-for-arg? (relation argnum directive mt)
  "[Cyc] Return booleanp; t iff the canonicalizer should respect DIRECTIVE when
canonicalizing the ARGNUMth argument position of RELATION in MT."
  (let ((result? nil))
    (when (null (some-canonicalizer-directive-assertions-somewhere? relation))
      (return-from canonicalizer-directive-for-arg? nil))
    (possibly-in-mt (mt)
      ;; Check #$canonicalizerDirectiveForArg
      (do-gaf-arg-index (ass relation :index 1 :predicate #$canonicalizerDirectiveForArg
                                      :truth :true :done result?)
        (let ((asserted-argnum (gaf-arg2 ass))
              (asserted-directive (gaf-arg3 ass)))
          (setf result? (and (eql argnum asserted-argnum)
                             (eq directive asserted-directive)))))
      ;; Check #$canonicalizerDirectiveForArgAndRest
      (do-gaf-arg-index (ass relation :index 1 :predicate #$canonicalizerDirectiveForArgAndRest
                                      :truth :true :done result?)
        (let ((asserted-argnum (gaf-arg2 ass))
              (asserted-directive (gaf-arg3 ass)))
          (setf result? (and (non-negative-integer-p asserted-argnum)
                             (>= argnum asserted-argnum)
                             (eq directive asserted-directive)))))
      ;; Check #$canonicalizerDirectiveForAllArgs
      (do-gaf-arg-index (ass relation :index 1 :predicate #$canonicalizerDirectiveForAllArgs
                                      :truth :true :done result?)
        (let ((asserted-directive (gaf-arg2 ass)))
          (setf result? (eq directive asserted-directive)))))
    ;; Check spec directives via missing-larkc 8796
    (unless result?
      ;; missing-larkc 8796 likely returns spec canonicalizer directives of DIRECTIVE
      ;; (e.g. direct-spec-canonicalizer-directives), since this recursively checks
      ;; whether any spec-directive also applies to the arg position.
      (csome (spec-directive (missing-larkc 8796) result?)
        (when (canonicalizer-directive-for-arg? relation argnum spec-directive mt)
          (setf result? t))))
    result?))

;; (defun direct-genl-canonicalizer-directives (directive) ...) -- no body, active decl commented in Java (1 0)
;; (defun direct-spec-canonicalizer-directives (directive) ...) -- no body, active decl commented in Java (1 0)

(defun get-nth-canonical-variable (n &optional (type *canonical-variable-type*))
  (case type
    (:el-var (make-el-var (format nil "X-~d" n)))
    (:kb-var (find-variable-by-id n))))

;; (defun canonical-variable-number (var) ...) -- no body, active decl commented in Java (1 0)

(defun arg-permits-generic-arg-variables? (reln argnum &optional mt)
  "[Cyc] Return boolean; t iff the arg constraints on arg position ARGNUM of relation RELN permit generic args as variables."
  (when (> argnum 0)
    (canonicalizer-directive-for-arg? reln argnum #$AllowGenericArgVariables mt)))

(defun arg-permits-keyword-variables? (reln argnum &optional mt)
  "[Cyc] Return boolean; t iff the arg constraints on arg position ARGNUM of relation RELN permit keywords as variables."
  (when (> argnum 0)
    (canonicalizer-directive-for-arg? reln argnum #$AllowKeywordVariables mt)))

(defun relax-arg-type-constraints-for-variables-for-arg? (relation argnum &optional mt)
  (canonicalizer-directive-for-arg? relation argnum #$RelaxArgTypeConstraintsForVariables mt))

(defun dont-reorder-commutative-terms-for-args (relation &optional mt)
  (let ((argnums nil))
    (when (null (some-canonicalizer-directive-assertions-somewhere? relation))
      (return-from dont-reorder-commutative-terms-for-args nil))
    (possibly-in-mt (mt)
      ;; missing-larkc 30015 likely returns assertions about
      ;; #$DontReOrderCommutativeTerms for specific args of RELATION
      (let ((assertions (missing-larkc 30015)))
        (dolist (ass assertions)
          (let ((asserted-argnum (gaf-arg2 ass)))
            (when (non-negative-integer-p asserted-argnum)
              (push asserted-argnum argnums)))))
      ;; missing-larkc 30016 likely returns assertions about
      ;; #$DontReOrderCommutativeTerms for arg-and-rest of RELATION
      (let ((assertions (missing-larkc 30016)))
        (dolist (ass assertions)
          (let ((asserted-argnum (gaf-arg2 ass))
                (v-arity (arity relation)))
            (when (non-negative-integer-p asserted-argnum)
              (do ((argnum asserted-argnum (1+ argnum)))
                  ((>= argnum (+ v-arity 1)))
                (push argnum argnums))))))
      ;; missing-larkc 30017 likely returns assertions about
      ;; #$DontReOrderCommutativeTerms for all args of RELATION
      (let ((assertions (missing-larkc 30017)))
        (when assertions
          (let ((v-arity (arity relation)))
            (do ((argnum 1 (1+ argnum)))
                ((>= argnum (+ v-arity 1)))
              (push argnum argnums))))))
    (fast-delete-duplicates argnums)))

;; (defun possibly-assertion-arg? (relation argnum &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun assertion-arg? (relation argnum &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun indexed-arg? (relation argnum) ...) -- no body, active decl commented in Java (2 0)

(defun expression-arg? (relation argnum &optional mt)
  "[Cyc] Return boolean; t iff arg number ARGNUM of RELATION is a CycLExpression.
(note: such args need only pass syntactic wf tests)"
  (when (and (fort-p relation)
             (numberp argnum)
             (> argnum 0))
    (if (cyc-const-logical-operator-p relation)
        t
        (or (any-spec? #$CycLExpression (argn-isa relation argnum mt) mt)
            (any-spec? #$CycLExpression (argn-quoted-isa relation argnum mt) mt)))))

;; (defun formula-arg? (relation argnum &optional mt) ...) -- no body, active decl commented in Java (2 1)

;; formula-arg-int? is a globally-cached function (defun-cached pattern).
;; The body (formula-arg-int?-internal) is stripped, so the entire group is stubs:
;;   *formula-arg-int?-caching-state* — deflexical, caching state variable
;;   clear-formula-arg-int? (0 0) — clears the caching state
;;   remove-formula-arg-int? (2 1) — removes a single entry
;;   formula-arg-int?-internal (3 0) — the actual computation (stripped)
;;   formula-arg-int? (2 1) — the cached wrapper
;; All have commented declareFunction, no body.

;; quoted-formula-arg-int? is a globally-cached function (defun-cached pattern).
;; The body (quoted-formula-arg-int?-internal) is stripped, so the entire group is stubs:
;;   *quoted-formula-arg-int?-caching-state* — deflexical, caching state variable
;;   clear-quoted-formula-arg-int? (0 0) — clears the caching state
;;   remove-quoted-formula-arg-int? (2 1) — removes a single entry
;;   quoted-formula-arg-int?-internal (3 0) — the actual computation (stripped)
;;   quoted-formula-arg-int? (2 1) — the cached wrapper
;; All have commented declareFunction, no body.

(defun sentence-arg? (relation argnum &optional (mt *mt*))
  "[Cyc] Return boolean; t iff RELATION's ARGNUMth arg is constrained to be a collection whose instances are Cyc sentences."
  (when (and (fort-p relation)
             (integerp argnum)
             (> argnum 0))
    (if (cyc-const-logical-operator-p relation)
        t
        (or (sentence-arg-int? relation argnum mt)
            (quoted-sentence-arg-int? relation argnum mt)))))

;; (defun clear-sentence-arg-int? () ...) -- no body, active decl commented in Java (0 0)
;; (defun remove-sentence-arg-int? (relation argnum mt) ...) -- no body, active decl commented in Java (3 0)

(defun-cached sentence-arg-int? (relation argnum mt) (:test eq :capacity 1024)
  (any-spec? #$CycLSentence (argn-isa relation argnum mt) mt))

;; (defun clear-quoted-sentence-arg-int? () ...) -- no body, active decl commented in Java (0 0)
;; (defun remove-quoted-sentence-arg-int? (relation argnum mt) ...) -- no body, active decl commented in Java (3 0)

(defun-cached quoted-sentence-arg-int? (relation argnum mt) (:test eq :capacity 1024)
  (any-spec? #$CycLSentence (argn-quoted-isa relation argnum mt) mt))

;; (defun askable-formula-arg? (relation argnum &optional mt) ...) -- no body, active decl commented in Java (2 1)

(defun assertable-formula-arg? (relation argnum &optional mt)
  "[Cyc] Return boolean; t iff arg number ARGNUM of RELATION is an assertable formula.
(note: such args need pass semantic wf tests)"
  (when (and (fort-p relation)
             (numberp argnum)
             (> argnum 0))
    (if (cyc-const-logical-operator-p relation)
        t
        (or (any-spec? #$CycLSentence-Assertible (argn-isa relation argnum mt) mt)
            (any-spec? #$CycLSentence-Assertible (argn-quoted-isa relation argnum mt) mt)))))

;; (defun askable-sentence-arg? (relation argnum &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun assertable-sentence-arg? (relation argnum &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun denotational-term-arg? (relation argnum &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun leave-some-terms-at-el-for-arg? (relation argnum &optional mt) ...) -- no body, active decl commented in Java (2 1)

(defun leave-variables-at-el-for-arg? (relation argnum &optional mt)
  (canonicalizer-directive-for-arg? relation argnum #$LeaveVariablesAtEL mt))

;; (defun arg-isa-quoted? (relation argnum &optional mt) ...) -- no body, active decl commented in Java (2 1)

(defun distributing-meta-pred? (pred)
  "[Cyc] Returns t iff PRED is a #$DistributingMetaKnowledgePredicate."
  (distributing-meta-knowledge-predicate-p pred))

;; (defun find-hl-gaf (formula &optional mt) ...) -- no body, active decl commented in Java (1 1)
;; (defun find-hl-gaf-if (test formula) ...) -- no body, active decl commented in Java (2 0)
;; (defun safe-find-gaf-genl-mts (formula mt) ...) -- no body, active decl commented in Java (2 0)
;; (defun nput-back-clause-el-variables (clause) ...) -- no body, active decl commented in Java (1 0)
;; (defun put-back-clause-el-variables (clause) ...) -- no body, active decl commented in Java (1 0)

(defun list-of-clause-binding-list-pairs-p (object)
  "[Cyc] Return boolean; t iff OBJECT is a list of clause/binding list pairs, e.g.
((<clause1> <blist1>) (<clause2> <blist2>)), or they could also be triples and the
third elements are ignored.
This is the return value of @xref canonicalize-cycl."
  (when (consp object)
    (dolist (pair object t)
      (unless (and (length<= pair 3)
                   (cnf-p (first pair))
                   (binding-list-p (second pair)))
        (return nil)))))

;; (defun nextract-el-clauses (thing) ...) -- no body, active decl commented in Java (1 0)
;; (defun extract-el-clauses (thing) ...) -- no body, active decl commented in Java (1 0)

(defun extract-hl-clauses (thing)
  "[Cyc] This is not destructive.
@param thing list; a list of clause/binding-list pairs
@return list; a list of clauses with the blists ignored and the clauses unmodified."
  (if (list-of-clause-binding-list-pairs-p thing)
      (mapcar #'first thing)
      thing))

;; (defun nextract-hl-clauses (thing) ...) -- no body, active decl commented in Java (1 0)

(defun extract-blists (thing)
  "[Cyc] This is not destructive.
@param thing list; a list of clause/binding-list pairs
@return list; a list of blists with the clauses ignored and the blists unmodified."
  (if (list-of-clause-binding-list-pairs-p thing)
      (mapcar #'second thing)
      thing))

;; (defun nextract-blists (thing) ...) -- no body, active decl commented in Java (1 0)
;; (defun fn-tou-lit (fn var) ...) -- no body, active decl commented in Java (2 0)
;; (defun fn-equals-lit (fn var) ...) -- no body, active decl commented in Java (2 0)
;; (defun fn-evaluate-lit (fn var &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun fn-some-non-evaluatable-reference? (fn formula &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun make-nart-var-tou-lit (naut) ...) -- no body, active decl commented in Java (1 0)
;; (defun make-nart-var-for-tou-lit (naut) ...) -- no body, active decl commented in Java (1 0)
;; (defun make-nart-var-equals-lit (naut) ...) -- no body, active decl commented in Java (1 0)
;; (defun make-nart-var-evaluate-lit (naut) ...) -- no body, active decl commented in Java (1 0)
;; (defun clause-new-el-var-name (clause) ...) -- no body, active decl commented in Java (1 0)
;; (defun unique-var-name-wrt (var expression) ...) -- no body, active decl commented in Java (2 0)
;; (defun unique-el-var-wrt-expression (expression &optional prefix) ...) -- no body, active decl commented in Java (1 1)
;; (defun unique-hl-var-wrt-expression (expression &optional prefix) ...) -- no body, active decl commented in Java (1 1)
;; (defun make-czer-el-var-name (name) ...) -- no body, active decl commented in Java (1 0)

(defparameter *czer-evaluatable-predicate-fix-enabled?* nil
  "[Cyc] Temporary control variable; should eventually stay T.")

(defun canon-var? (candidate-variable)
  "[Cyc] Return boolean; t iff CANDIDATE-VARIABLE is a variable, according to whatever
definition of variable the canonicalizer is using at the time."
  (and candidate-variable
       (if (eq *canon-var-function* :default)
           (cyc-var? candidate-variable)
           (funcall *canon-var-function* candidate-variable))))

(defun true-sentence? (formula)
  (when (not (el-negation-p formula))
    (true-sentence-lit? formula)))

(defun true-negated-var? (formula &optional (var? #'cyc-var?))
  (and (true-sentence? formula)
       (el-negation-p (formula-arg1 formula))
       (funcall var? (formula-arg1 (formula-arg1 formula)))))

(defun true-negated-formula? (formula)
  (when (true-sentence? formula)
    (or (el-negation-p (formula-arg1 formula))
        ;; missing-larkc 30528 likely tests for some other negation-like form
        ;; of formula-arg1, perhaps el-holds-p or a similar syntactic check
        (missing-larkc 30528))))

;; (defun true-var-formula? (formula &optional var?) ...) -- no body, active decl commented in Java (1 1)

(defun encapsulate-formula? (formula)
  (cond
    ((sequence-var formula)
     (if (and *encapsulate-var-formula?*
              (el-formula-p formula)
              (cyc-const-logical-operator-p (formula-operator formula))
              (el-wff-syntax? formula))
         *encapsulate-var-formula?*
         (let ((result nil)
               ;; missing-larkc 30663 likely strips the sequence variable from the formula
               ;; (e.g. strip-sequence-var or similar), since the code then recurses
               ;; on the stripped formula to check encapsulation.
               (tempformula (if (sequence-var formula)
                                (missing-larkc 30663)
                                formula)))
           (setf result (encapsulate-formula? tempformula))
           result)))
    ((and *encapsulate-var-formula?*
          (el-var? formula))
     *encapsulate-var-formula?*)
    ((and *encapsulate-intensional-formula?*
          (intensional-formula? formula))
     *encapsulate-intensional-formula?*)))

;; (defun encapsulate-formula (formula &optional mt) ...) -- no body, active decl commented in Java (1 1)

(defun intensional-formula? (formula)
  (or (and (within-disjunction?)
           (not (within-negated-disjunction?))
           (or (and (el-universal-p formula)
                    (or (not (missing-larkc 30529))
                        (not (within-negation?))))
               (and (or (el-existential-p formula)
                        (el-bounded-existential-p formula))
                    (or (within-negation?)
                        (missing-larkc 30530)))))
      (and (within-ask?)
           (or (and (within-negation?)
                    (or (el-existential-p formula)
                        (el-bounded-existential-p formula)))
               (and (not (within-negation?))
                    (el-universal-p formula))))))

;; (defun make-var-formula-lit (formula) ...) -- no body, active decl commented in Java (1 0)
;; (defun make-intensional-lit (formula) ...) -- no body, active decl commented in Java (1 0)
;; (defun make-intensional-lit-int (formula) ...) -- no body, active decl commented in Java (1 0)
;; (defun formula-has-expansion? (relation &optional mt) ...) -- no body, active decl commented in Java (1 1)
;; (defun relation-has-expansion? (relation &optional mt) ...) -- no body, active decl commented in Java (1 1)

(defun* within-negation? () (:inline t)
  *within-negation?*)

(defun* within-disjunction? () (:inline t)
  *within-disjunction?*)

;; (defun within-conjunction? () ...) -- no body, active decl commented in Java (0 0)

(defun within-negated-disjunction? ()
  *within-negated-disjunction?*)

;; (defun commuting-functions? (fn1 fn2 &optional mt) ...) -- no body, active decl commented in Java (2 1)

(defun reifiable-functor? (functor &optional mt)
  "[Cyc] Is FUNCTOR a reifiable functor? The two ways FUNCTOR can be reifiable are:
1. FUNCTOR is a fort which is directly asserted to be reifiable
2. FUNCTOR is a reifiable-function-denoting naut,
   i.e. a naut with a fort as its functor (call that fort INNER-FUNCTOR),
   such that INNER-FUNCTOR denotes a reifiable function."
  (and (or (fort-p functor)
           (first-order-naut? functor))
       (isa-reifiable-function? functor mt)))

(defun reifiable-function-term? (v-term &optional mt)
  (and (el-formula-p v-term)
       (if *gathering-quantified-fn-terms?*
           (or (cyc-var? (nat-functor v-term))
               (reifiable-functor? (nat-functor v-term) mt))
           (and (reifiable-functor? (nat-functor v-term) mt)
                ;; missing-larkc 31557 likely checks well-formedness of the naut args
                ;; (e.g. wf-naut-args? or similar), since this is a full reifiability check
                (missing-larkc 31557)))))

;; (defun wf-reifiable-function-term? (v-term &optional mt) ...) -- no body, active decl commented in Java (1 1)
;; (defun reifiable-term? (v-term) ...) -- no body, active decl commented in Java (1 0)
;; (defun reifiable-nat-term? (v-term) ...) -- no body, active decl commented in Java (1 0)
;; (defun unreified-reifiable-nat-term? (v-term) ...) -- no body, active decl commented in Java (1 0)
;; (defun fort-or-naut-with-corresponding-nart? (v-term) ...) -- no body, active decl commented in Java (1 0)
;; (defun list-of-fort-or-naut-with-corresponding-nart? (object) ...) -- no body, active decl commented in Java (1 0)

;; commented declareFunction, but body present in Java — ported for reference
(defun naut-with-corresponding-nart? (v-term)
  "[Cyc] Return booleanp; t iff TERM is a naut which has an already-reified NART counterpart."
  (when (ground-naut? v-term #'variable-p)
    (and (find-nart v-term) t)))

(defun reifiable-naut? (v-term &optional (var? #'cyc-var?) mt)
  (when (closed-naut? v-term var?)
    (or (reifiable-function-term? v-term mt)
        ;; missing-larkc 10335 likely checks if v-term is a naut
        ;; with a corresponding NART (e.g. naut-with-corresponding-nart?),
        ;; providing a fallback reifiability check for already-reified terms.
        (missing-larkc 10335))))

(defun evaluatable-function-symbol? (symbol &optional mt)
  (declare (ignore mt))
  (and (fort-p symbol)
       (evaluatable-function-p symbol)))

(defun evaluatable-function-term? (v-term &optional mt)
  (declare (ignore mt))
  (and (el-formula-p v-term)
       (evaluatable-function-symbol? (nat-functor v-term))))

;; (defun unpackage-cnf-clause (clause) ...) -- no body, active decl commented in Java (1 0)

;; equals-el-memoized? is a state-dependent memoized function (defun-memoized pattern).
;; The body (equals-el-memoized?-internal) is stripped, so the entire group is stubs:
;;   equals-el-memoized?-internal (2 2) — the actual computation (stripped)
;;   equals-el-memoized? (2 2) — the memoized wrapper
;; Both have commented declareFunction, no body.
;; (defun queries-equal-at-el? (query1 query2 &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun equals-el? (object1 object2 &optional mt clausal-form) ...) -- no body, active decl commented in Java (2 2)
;; (defun equals-el-int? (object1 object2 mt clausal-form verbosify?) ...) -- no body, active decl commented in Java (5 0)
;; (defun el-expression-equal? (object1 object2 &optional mt clausal-form verbosify?) ...) -- no body, active decl commented in Java (2 3)
;; (defun canonicalize-for-equals-el (sentence mt clausal-form verbosify?) ...) -- no body, active decl commented in Java (4 0)
;; (defun el-expression-equal-unification-successful? (blist) ...) -- no body, active decl commented in Java (1 0)
;; (defun non-null-closed-term? (object) ...) -- no body, active decl commented in Java (1 0)
;; (defun delete-el-duplicates (clauses) ...) -- no body, active decl commented in Java (1 0)
;; (defun cnfs-reorder-equal? (cnf1 cnf2 &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun cnfs-reorder-literals-equal? (cnf1 cnf2 &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun cnfs-reorder-terms-equal? (cnf1 cnf2 &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun ordered-cnf-unify? (cnf1 cnf2) ...) -- no body, active decl commented in Java (2 0)
;; (defun ordered-literals-unify (literals1 literals2) ...) -- no body, active decl commented in Java (2 0)
;; (defun ordered-literals-unify-int (literals1 literals2) ...) -- no body, active decl commented in Java (2 0)
;; (defun el-find-nart (nart) ...) -- no body, active decl commented in Java (1 0)
;; (defun el-find-if-nart (nart) ...) -- no body, active decl commented in Java (1 0)
;; (defun recanonicalized-candidate-nat-equals-nat-formula? (candidate-nat nat-formula) ...) -- no body, active decl commented in Java (2 0)
;; (defun recanonicalize-candidate-nat (candidate-nat) ...) -- no body, active decl commented in Java (1 0)
;; (defun robust-nart-lookup? () ...) -- no body, active decl commented in Java (0 0)
;; (defun sort-forts-external (forts) ...) -- no body, active decl commented in Java (1 0)
;; (defun definitional-lits-to-front (clause) ...) -- no body, active decl commented in Java (1 0)
;; (defun evaluatable-expressions-out (clause) ...) -- no body, active decl commented in Java (1 0)

(defun* unwrap-if-ist (sentence mt) (:inline t)
  "[Cyc] @return 0 sentence; SENTENCE, with any outermost #$ists stripped.
@return 1 mt; MT, unless SENTENCE is an #$ist sentence, in which case the
innermost mt specified by #$ist is returned, and MT is ignored.
Yields an error if the mt is not specified in either of these two ways."
  (unwrap-if-ist-int sentence mt t))

(defun* unwrap-if-ist-permissive (sentence &optional mt) (:inline t)
  "[Cyc] Like @xref unwrap-if-ist except doesn't error if no mt is specified."
  (unwrap-if-ist-int sentence mt nil))

;; (defun unwrap-if-ist-canonical (sentence &optional mt) ...) -- no body, active decl commented in Java (1 1)

(defun* unwrap-if-ist-permissive-canonical (sentence &optional mt) (:inline t)
  "[Cyc] Like @xref unwrap-if-ist-permissive except canonicalizes the returned mt
if it's different from MT."
  (unwrap-if-ist-canonical-int sentence mt nil))

(defun unwrap-if-ist-canonical-int (sentence mt error?)
  (let ((original-mt mt))
    (multiple-value-setq (sentence mt) (unwrap-if-ist-int sentence mt error?))
    (unless (hlmt-equal original-mt mt)
      (setf mt (canonicalize-mt mt))))
  (values sentence mt))

(defun unwrap-if-ist-int (sentence mt error?)
  (multiple-value-setq (sentence mt) (unwrap-if-ist-recursive sentence mt))
  (when error?
    (must (not (null mt)) "~s ~s does not adequately specify a microtheory." sentence mt))
  (values sentence mt))

(defun unwrap-if-ist-recursive (sentence mt)
  "[Cyc] @return 0 sentence; SENTENCE, with any outermost #$ists stripped.
@return 1 mt; MT, unless SENTENCE is an #$ist sentence, in which case the
innermost mt specified by #$ist is returned, and MT is ignored."
  (if (and (ist-sentence-p sentence)
           ;; missing-larkc 12254 likely validates the ist mt argument
           ;; (e.g. hlmt-p or valid-mt?), checking that the mt in the ist is well-formed
           (missing-larkc 12254))
      (unwrap-if-ist-recursive (sentence-arg2 sentence) (sentence-arg1 sentence))
      (values sentence mt)))

;; (defun possibly-quoted-cycl-formula-p (object) ...) -- no body, active decl commented in Java (1 0)
;; (defun unwrap-quotes (object) ...) -- no body, active decl commented in Java (1 0)

(defun quoted-term-with-hl-var? (object)
  (and (fast-quote-term-p object)
       (expression-find-if #'hl-var? object)))

;; (defun escape-term (v-term) ...) -- no body, active decl commented in Java (1 0)

(defun possibly-escape-quote-hl-vars (object &optional destructive?)
  (cond
    ((not (expression-find-if #'quoted-term-with-hl-var? object))
     object)
    (destructive?
     ;; missing-larkc 8847 likely is nescape-quote-hl-vars (destructive version)
     (missing-larkc 8847))
    (t
     ;; missing-larkc 8811 likely is escape-quote-hl-vars (non-destructive version)
     (missing-larkc 8811))))

;; (defun escape-quote-hl-vars (object) ...) -- no body, active decl commented in Java (1 0)
;; (defun nescape-quote-hl-vars (object) ...) -- no body, active decl commented in Java (1 0)
;; (defun decontextualized-clauses? (clauses) ...) -- no body, active decl commented in Java (1 0)
;; (defun decontextualized-clause? (clause) ...) -- no body, active decl commented in Java (1 0)

(defun generalized-ist-clauses-p (v-clauses)
  (when (not (cycl-truth-value-p v-clauses))
    (every-in-list #'generalized-ist-clause-p v-clauses)))

(defun generalized-ist-clause-p (clause)
  (let ((non-ist? nil))
    (dolist (asent (neg-lits clause))
      (when non-ist? (return))
      (unless (generalized-ist-literal-p asent)
        (setf non-ist? t)))
    (dolist (asent (pos-lits clause))
      (when non-ist? (return))
      (unless (generalized-ist-literal-p asent)
        (setf non-ist? t)))
    (not non-ist?)))

(defun generalized-ist-literal-p (object)
  (atomic-sentence-with-any-of-preds-p object (list #$ist #$ist-Asserted)))

(defparameter *opaque-arg-wrt-quoting-target* nil)

;; (defun opaque-arg-wrt-quoting-seeker (formula target) ...) -- no body, active decl commented in Java (2 0)
;; (defun note-opaque-reference-to-term (formula target) ...) -- no body, active decl commented in Java (2 0)
;; (defun formula-references-term-opaquely? (formula target &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun assertion-references-term-opaquely? (assertion target &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun kb-hl-support-references-term-opaquely? (support target &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun hl-support-references-term-opaquely? (support target &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun support-references-term-opaquely? (support target &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun deduction-references-term-opaquely? (deduction target &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun term-opaque-assertions (v-term &optional mt) ...) -- no body, active decl commented in Java (1 1)
;; (defun all-term-opaque-assertions (v-term) ...) -- no body, active decl commented in Java (1 0)
;; (defun term-opaque-deductions (v-term &optional mt) ...) -- no body, active decl commented in Java (1 1)
;; (defun all-term-opaque-deductions (v-term) ...) -- no body, active decl commented in Java (1 0)
;; (defun canonicalize-el-sentence (sentence mt) ...) -- no body, active decl commented in Java (2 0)
;; (defun canon-equal? (object1 object2 &optional mt clausal-form verbosify?) ...) -- no body, active decl commented in Java (2 3)
;; (defun canon-query-equal? (object1 object2 &optional mt clausal-form verbosify?) ...) -- no body, active decl commented in Java (2 3)
;; (defun canon-assert-equal? (object1 object2 &optional mt clausal-form verbosify?) ...) -- no body, active decl commented in Java (2 3)
;; (defun canon-assert-isomorphic? (object1 object2 &optional mt clausal-form verbosify?) ...) -- no body, active decl commented in Java (2 3)
;; (defun canon-forms-equal? (cnfs1 cnfs2 &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun canon-forms-isomorphic? (cnfs1 cnfs2 &optional mt) ...) -- no body, active decl commented in Java (2 1)
;; (defun canon-equal-hl-names? (hl-name1 hl-name2 &optional mt clausal-form verbosify? destructive?) ...) -- no body, active decl commented in Java (2 4)
;; (defun constant-occurs-in-formula? (constant formula) ...) -- no body, active decl commented in Java (2 0)
;; (defun canonicalize-and-return-skolem-vars (formula &optional mt) ...) -- no body, active decl commented in Java (1 1)
;; (defun find-anywhere (item tree &optional test substitutions) ...) -- no body, active decl commented in Java (2 2)
;; (defun find-all-anywhere (item tree &optional test substitutions result) ...) -- no body, active decl commented in Java (2 3)
;; (defun return-uncanon (formula mt) ...) -- no body, active decl commented in Java (2 0)
;; (defun uncanon-original-test (formula mt) ...) -- no body, active decl commented in Java (2 0)
;; (defun uncanon-test (formula mt &optional clausal-form verbosify?) ...) -- no body, active decl commented in Java (2 2)
;; (defun assert-return-uncanon (formula mt direction) ...) -- no body, active decl commented in Java (3 0)
;; (defun canon-mal-result? (result &optional clausal-form) ...) -- no body, active decl commented in Java (1 1)
;; (defun canon-ask-mal-result? (result &optional clausal-form) ...) -- no body, active decl commented in Java (1 1)
;; (defun canon-query-mal-result? (result &optional clausal-form) ...) -- no body, active decl commented in Java (1 1)
;; (defun canon-assert-mal-result? (result &optional clausal-form) ...) -- no body, active decl commented in Java (1 1)
;; (defun canon-form-mal-result? (result) ...) -- no body, active decl commented in Java (1 0)

;;; Setup

(note-funcall-helper-function 'opaque-arg-wrt-quoting-seeker)
