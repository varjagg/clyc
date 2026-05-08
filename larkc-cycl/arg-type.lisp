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

;; Init phase — variables that are referenced by function bodies must be declared first

(defparameter *relation-arg-ok-argnum* nil
  "[Cyc] Dynamic variable to work around the lack of 'ignore-this' arguments to cached functions.")
(deflexical *cached-relation-arg-ok?-caching-state* nil)
(deflexical *cached-format-ok?-caching-state* nil)
(defconstant *dtp-arg-constraint* 'arg-constraint)
(defparameter *arg-constraint-struct-printing-verbose?* nil)
(deflexical *sorted-arg-constraint-predicates-caching-state* nil)

;; Declare phase — ordered per declare_arg_type_file()

(defun formula-args-ok-wrt-type? (formula &optional mt)
  (if (mt-designating-literal? formula)
      (missing-larkc 23217) ;; likely calls mt-literal-args-ok-wrt-type? to handle mt-designating literals
      (formula-args-ok-wrt-type-int? formula mt)))

;; (defun why-not-formula-args-ok-wrt-type? (formula &optional mt) ...) -- no body, active declareFunction
;; (defun mt-literal-args-ok-wrt-type? (formula mt) ...) -- no body, active declareFunction

(defun seqvars-inhibited-by-relation-expression (relation)
  "[Cyc] Returns the variables that are not allowed to occur as sequence variables within RELATION."
  (if (and (scoping-relation-expression? relation)
           (not (eq #$forAll (formula-operator relation)))
           (not (eq #$thereExists (formula-operator relation))))
      (scoped-vars relation)
      nil))

(defun new-inhibited-seqvars (relation)
  "[Cyc] Updates the dynamic variable stack of variables that are currently not allowed to appear as sequence variables."
  (append *variables-that-cannot-be-sequence-variables*
          (seqvars-inhibited-by-relation-expression relation)))

;; (defun at-considering-atomic-sentence-p () ...) -- no body, active declareFunction

(defun formula-args-ok-wrt-type-int? (formula &optional mt)
  (let ((args (formula-args formula))
        (seqvar (sequence-var formula))
        (ok? t)
        (done? nil))
    (let ((*fag-search-limit* *at-gaf-search-limit*)
          (*at-argnum* 0))
      (let ((ground? (null (sentence-free-variables formula))))
        (let ((*at-check-arg-format?* (and *at-check-arg-format?*
                                           (not (or *appraising-disjunct?*
                                                    *within-function?*
                                                    *within-predicate?*
                                                    (within-negation?)))
                                           ground?))
              (*at-check-relator-constraints?* (and *at-check-relator-constraints?*
                                                    (not (or *appraising-disjunct?*
                                                             *within-function?*
                                                             *within-predicate?*
                                                             (within-negation?)))
                                                    ground?))
              (*at-formula* formula)
              (*at-reln* (reify-when-closed-naut (formula-arg0 formula)))
              (*variables-that-cannot-be-sequence-variables* (new-inhibited-seqvars formula)))
          (when (member? seqvar *variables-that-cannot-be-sequence-variables*)
            (missing-larkc 8022) ;; likely reports inhibited-sequence-variable violation
            (setf ok? nil))
          (when (fort-p *at-reln*)
            (setf ok? (and (defining-mts-ok? *at-reln* mt)
                           (relator-constraints-ok? formula)
                           ok?))
            (setf done? (at-finished? (not ok?)))
            (let ((*distributing-meta-knowledge?* (distributing-meta-pred? *at-reln*)))
              (when (not done?)
                (dolist (arg args)
                  (when done? (return))
                  (incf *at-argnum*)
                  (let ((*within-negation?* (at-within-negation? *at-reln* *at-argnum*))
                        (*within-function?* (at-within-function? *at-reln*))
                        (*within-predicate?* (at-within-predicate? *at-reln*))
                        (*within-disjunction?* (at-within-disjunct? formula *at-argnum*))
                        (*check-arity?* (check-arity? *at-reln* *at-argnum*))
                        (*at-check-arg-types?* (at-check-arg-types? *at-reln* *at-argnum* mt))
                        (*at-check-defining-mts?* (at-check-defining-mts? formula *at-argnum*))
                        (*appraising-disjunct?* (appraising-disjunct? formula mt))
                        (*within-decontextualized?* (at-within-decontextualized? formula)))
                    (setf ok? (and (relation-arg-ok? *at-reln* arg *at-argnum*
                                                     (arg-type-mt *at-reln* args *at-argnum* mt))
                                   ok?)))
                  (setf done? (at-finished? (not ok?)))))))
          ok?)))))

(defun relation-arg-ok? (relation arg argnum &optional mt)
  (if (and (within-wff?)
           (logical-connective-p relation))
      t
      (let ((ok? nil))
        (let ((*permit-keyword-variables?* (or *permit-keyword-variables?*
                                               (arg-permits-keyword-variables? relation argnum mt)))
              (*permit-generic-arg-variables?* (or *permit-generic-arg-variables?*
                                                   (arg-permits-generic-arg-variables? relation argnum mt))))
          (when (variable-wrt-arg-type? arg)
            (setf ok? (variable-arg-ok? relation arg argnum mt)))
          (when (not ok?)
            (setf ok? (relation-arg-ok-int? relation arg argnum mt))))
        ok?)))

;; (defun clear-cached-relation-arg-ok? () ...) -- no body, active declareFunction
;; (defun remove-cached-relation-arg-ok? (v1 v2 v3 v4 v5 v6) ...) -- no body, active declareFunction
;; (defun cached-relation-arg-ok?-internal (v1 v2 v3 v4 v5 v6) ...) -- no body, active declareFunction
;; (defun cached-relation-arg-ok? (v1 v2 v3 v4 v5 v6) ...) -- no body, active declareFunction

(defun relation-arg-ok-int? (relation arg argnum &optional mt)
  (let ((ok? nil))
    (let ((*at-reln* relation)
          (*at-arg* arg)
          (*at-argnum* argnum))
      (setf ok? (defining-mts-ok? arg mt))
      (cond
        ((at-finished? (not ok?)))
        ((tou-wrt-arg-type? arg)
         (setf ok? (and (missing-larkc 23239) ;; likely tou-arg-ok?
                        ok?)))
        ((weak-fort-wrt-arg-type? arg)
         (setf ok? (and (weak-fort-arg-ok? relation arg argnum mt)
                        ok?)))
        ((nat-function-wrt-arg-type? arg)
         (setf ok? (and (missing-larkc 23219) ;; likely nat-function-arg-ok?
                        ok?)))
        ((nat-argument-wrt-arg-type? arg)
         (setf ok? (and (missing-larkc 23218) ;; likely nat-argument-arg-ok?
                        ok?)))
        ((naut-wrt-arg-type? arg mt)
         (setf ok? (and (missing-larkc 23220) ;; likely naut-arg-ok?
                        ok?)))
        ((strong-fort-wrt-arg-type? arg)
         (setf ok? (and (strong-fort-arg-ok? relation arg argnum mt)
                        ok?)))
        (t
         (setf ok? (and (opaque-arg-ok? relation arg argnum mt)
                        ok?)))))
    ok?))

(defun at-within-negation? (formula-arg0 arg)
  (if (or (eq formula-arg0 #$not)
          (and (implication-op? formula-arg0)
               (eql arg 1)))
      (not (within-negation?))
      (within-negation?)))

(defun at-within-predicate? (formula-arg0)
  (or *within-predicate?*
      (predicate-spec? formula-arg0)))

(defun at-within-function? (&optional formula-arg0)
  (or *within-function?*
      (functor? formula-arg0)))

(defun at-check-arg-types? (&optional relation argnum mt)
  "[Cyc] Return booleanp; t iff arg-type analysis should in fact impose type checks on args of nats."
  (and *at-check-arg-types?*
       (or (not (expression-arg? relation argnum mt))
           (assertable-formula-arg? relation argnum mt))))

(defun at-check-defining-mts? (formula argnum)
  "[Cyc] Return booleanp; t iff defining-mt should be applied to arg ARGNUM of relation RELATION."
  (when (and *at-possibly-check-defining-mts?*
             (missing-larkc 32208)) ;; likely checks if defining-mt checking is applicable
    (let ((relation (formula-arg0 formula)))
      (cond
        ((not (fort-p relation)) t)
        ((quoted-argument? relation argnum) nil)
        (t t)))))

(defun appraising-disjunct? (formula &optional mt)
  (when *relax-arg-constraints-for-disjunctions?*
    (when (not (reifiable-function-term? formula mt))
      (or *appraising-disjunct?*
          (within-disjunction?)))))

(defun at-within-disjunct? (formula argnum)
  (or (within-disjunction?)
      (and (formula-arity>= formula 2)
           (if (within-negation?)
               (or (el-conjunction-p formula)
                   (and (el-implication-p formula)
                        (eql argnum 1)))
               (or (el-disjunction-p formula)
                   (el-implication-p formula)
                   (holds-in-lit? formula)
                   (el-exception-p formula))))))

;; (defun appraising-disjunct-cnf? (cnf) ...) -- no body, active declareFunction

(defun at-within-decontextualized? (formula)
  (or *within-decontextualized?*
      (decontextualized-literal? formula)))

(defun variable-arg-ok? (relation arg argnum &optional mt)
  "[Cyc] Returns t iff ARG satisfies arg-types as a variable.
Variables are assumed to satisfy each local arg-type.
Nats that reference variables are considered variables
wrt (i.e., are assumed to satisfy) applicable arg-types
but each of their args must be ok."
  (cond
    ((eql relation #$termOfUnit)
     (missing-larkc 23240)) ;; likely tou-arg-ok? for variable case
    ((and (first-order-naut? arg)
          (not (unreified-skolem-term? arg)))
     (if (missing-larkc 23221) ;; likely checks if naut args are ok for variable
         t
         nil))
    (t t)))

(defun weak-fort-arg-ok? (relation arg argnum &optional mt)
  (weak-fort-types-ok? relation arg argnum mt))

;; (defun naut-arg-ok? (relation arg argnum mt) ...) -- no body, active declareFunction
;; (defun at-nat-ok? (naut &optional mt) ...) -- no body, active declareFunction
;; (defun nat-functor-ok? (naut &optional mt) ...) -- no body, active declareFunction
;; (defun nat-args-ok? (naut &optional mt) ...) -- no body, active declareFunction
;; (defun nart-or-reify-forward-naut? (naut mt) ...) -- no body, active declareFunction
;; (defun tou-arg-ok? (v-term argnum) ...) -- no body, active declareFunction
;; (defun nat-function-arg-ok? (v-term argnum) ...) -- no body, active declareFunction
;; (defun nat-argument-arg-ok? (v-term argnum) ...) -- no body, active declareFunction
;; (defun tou-naut-ok? (naut) ...) -- no body, active declareFunction

(defun strong-fort-arg-ok? (relation arg argnum mt)
  "[Cyc] Returns t iff ARG satisfies the stronger arg-types as a fort.
Adopts negation-as-failure while establishing ARG is
an instance of every applicable arg-type."
  (strong-fort-arg-types-ok? relation arg argnum mt))

(defun opaque-arg-ok? (relation arg argnum mt)
  "[Cyc] Returns t iff ARG satisfies arg-types as an opaque arg.
Opaque args must satisfy defns of each applicable arg-type.
Adopts negation-as-failure while establishing ARG is
an instance of every applicable arg-type."
  (opaque-arg-types-ok? relation arg argnum mt))

;; (defun naut-functor-ok? (naut &optional mt) ...) -- no body, active declareFunction
;; (defun naut-args-ok? (naut &optional mt) ...) -- no body, active declareFunction
;; (defun naut-args-ok-wrt-type? (naut &optional mt) ...) -- no body, active declareFunction

(defun weak-fort-types-ok? (reln arg argnum &optional mt)
  (let ((isa-ok? (not *at-check-not-isa-disjoint?*))
        (quoted-isa-ok? (not *at-check-not-quoted-isa-disjoint?*))
        (not-isa-ok? (not *at-check-arg-not-isa?*))
        (genls-ok? (not *at-check-not-genls-disjoint?*))
        (different-ok? (not *at-check-inter-arg-different?*))
        (nat (if (arg-types-prescribe-unreified? reln argnum)
                 nil
                 (find-closed-naut arg)))
        (admit-consistent-nart? (and *at-admit-consistent-narts?*
                                     (nart-p arg))))
    (if (nart-p nat)
        (relation-arg-ok? reln nat argnum mt)
        (progn
          (when (not (and isa-ok? quoted-isa-ok? genls-ok? different-ok?))
            (let ((*mt* (update-inference-mt-relevance-mt mt))
                  (*relevant-mt-function* (update-inference-mt-relevance-function mt))
                  (*relevant-mts* (update-inference-mt-relevance-mt-list mt))
                  (*at-arg-type* :weak-fort))
              (when (not isa-ok?)
                (if (or admit-consistent-nart?
                        (asserted-isa? arg mt))
                    (setf isa-ok? (arg-test-ok? reln arg argnum :not-isa-disjoint))
                    (let ((*at-check-arg-quoted-isa?* nil)
                          (*at-check-arg-genls?* nil)
                          (*at-check-arg-format?* nil))
                      (setf isa-ok? (opaque-arg-types-ok? reln arg argnum mt)))))
              (when (not (at-finished? (not isa-ok?)))
                (when (not quoted-isa-ok?)
                  (if (or admit-consistent-nart?
                          (asserted-quoted-isa? arg mt))
                      (setf quoted-isa-ok? (arg-test-ok? reln arg argnum :not-quoted-isa-disjoint))
                      (let ((*at-check-arg-isa?* nil)
                            (*at-check-arg-genls?* nil)
                            (*at-check-arg-format?* nil))
                        (setf quoted-isa-ok? (opaque-arg-types-ok? reln arg argnum mt))))))
              (when (not (at-finished? (not (and isa-ok? quoted-isa-ok?))))
                (when (not not-isa-ok?)
                  (setf not-isa-ok? (arg-test-ok? reln arg argnum :not-isa))))
              (when (not (at-finished? (not (and isa-ok? quoted-isa-ok? not-isa-ok?))))
                (when (not genls-ok?)
                  (if (or admit-consistent-nart?
                          (asserted-genls? arg mt))
                      (setf genls-ok? (arg-test-ok? reln arg argnum :not-genls-disjoint))
                      (setf genls-ok? (arg-test-ok? reln arg argnum :genls)))))
              (when (not (at-finished? (not (and isa-ok? quoted-isa-ok? not-isa-ok? genls-ok?))))
                (when (not different-ok?)
                  (setf different-ok? (arg-test-ok? reln arg argnum :different))))))
          (and isa-ok? quoted-isa-ok? not-isa-ok? genls-ok? different-ok?)))))

;; (defun naut-arg-types-ok? (reln arg argnum mt) ...) -- no body, active declareFunction
;; (defun naut-arg-types-consistent? (reln arg argnum mt) ...) -- no body, active declareFunction
;; (defun naut-arg-types-true? (reln arg argnum mt) ...) -- no body, active declareFunction

(defun strong-fort-arg-types-ok? (&optional
                                    (reln *at-reln*)
                                    (arg *at-arg*)
                                    (argnum *at-argnum*)
                                    (mt *mt*))
  (let ((isa-ok? (not *at-check-arg-isa?*))
        (quoted-isa-ok? (not *at-check-arg-quoted-isa?*))
        (not-isa-ok? (not *at-check-arg-not-isa?*))
        (genls-ok? (not *at-check-arg-genls?*))
        (format-ok? (not *at-check-arg-format?*))
        (different-ok? (not *at-check-inter-arg-different?*)))
    (when (not (and isa-ok? quoted-isa-ok? genls-ok? format-ok? different-ok?))
      (let ((*mt* (update-inference-mt-relevance-mt mt))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt))
            (*at-arg-type* :strong-fort))
        (when (not isa-ok?)
          (setf isa-ok? (arg-test-ok? reln arg argnum :isa)))
        (when (not (at-finished? (not isa-ok?)))
          (when (not quoted-isa-ok?)
            (setf quoted-isa-ok? (arg-test-ok? reln arg argnum :quoted-isa))))
        (when (not (at-finished? (not (and isa-ok? quoted-isa-ok?))))
          (when (not not-isa-ok?)
            (setf not-isa-ok? (arg-test-ok? reln arg argnum :not-isa))))
        (when (not (at-finished? (not (and isa-ok? quoted-isa-ok? not-isa-ok?))))
          (when (not genls-ok?)
            (setf genls-ok? (arg-test-ok? reln arg argnum :genls))))
        (when (not (at-finished? (not (and isa-ok? quoted-isa-ok? not-isa-ok? genls-ok?))))
          (when (not format-ok?)
            (setf format-ok? (arg-test-ok? reln arg argnum :format))))
        (when (not (at-finished? (not (and isa-ok? quoted-isa-ok? not-isa-ok? genls-ok? format-ok?))))
          (when (not different-ok?)
            (setf different-ok? (arg-test-ok? reln arg argnum :different))))))
    (and isa-ok? quoted-isa-ok? not-isa-ok? genls-ok? format-ok? different-ok?
         (or (not *at-ensure-consistency?*)
             (weak-fort-types-ok? reln arg argnum mt)))))

(defun opaque-arg-types-ok? (&optional
                               (reln *at-reln*)
                               (arg *at-arg*)
                               (argnum *at-argnum*)
                               (mt *mt*))
  (let ((isa-ok? (not *at-check-arg-isa?*))
        (quoted-isa-ok? (not *at-check-arg-quoted-isa?*))
        (not-isa-ok? (not *at-check-arg-not-isa?*))
        (genls-ok? (not *at-check-arg-genls?*))
        (format-ok? (not *at-check-arg-format?*))
        (different-ok? (not *at-check-inter-arg-different?*)))
    (when (not (and isa-ok? quoted-isa-ok? genls-ok? format-ok? different-ok?))
      (let ((*mt* (update-inference-mt-relevance-mt mt))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt))
            (*at-arg-type* :opaque))
        (when (not isa-ok?)
          (setf isa-ok? (arg-test-ok? reln arg argnum :isa)))
        (when (not (at-finished? (not isa-ok?)))
          (when (not quoted-isa-ok?)
            (setf quoted-isa-ok? (arg-test-ok? reln arg argnum :quoted-isa))))
        (when (not (at-finished? (not (and isa-ok? quoted-isa-ok?))))
          (when (not not-isa-ok?)
            (setf not-isa-ok? (arg-test-ok? reln arg argnum :not-isa))))
        (when (not (at-finished? (not (and isa-ok? quoted-isa-ok? not-isa-ok?))))
          (when (not genls-ok?)
            ;; Allocate a new sbhl marking space for genls check
            (let ((resourcing-p (resourcing-sbhl-marking-spaces-p)))
              (let ((*resourcing-sbhl-marking-spaces-p* nil)
                    (*sbhl-table* (get-sbhl-marking-space)))
                (let ((*at-genls-space* *sbhl-table*)
                      (*resourcing-sbhl-marking-spaces-p* resourcing-p))
                  (setf genls-ok? (arg-test-ok? reln arg argnum :genls)))
                (free-sbhl-marking-space *sbhl-table*)))))
        (when (not (at-finished? (not (and isa-ok? quoted-isa-ok? not-isa-ok? genls-ok?))))
          (when (not format-ok?)
            (setf format-ok? (arg-test-ok? reln arg argnum :format))))
        (when (not (at-finished? (not (and isa-ok? quoted-isa-ok? not-isa-ok? genls-ok? format-ok?))))
          (when (not different-ok?)
            (setf different-ok? (arg-test-ok? reln arg argnum :different))))))
    (and isa-ok? quoted-isa-ok? not-isa-ok? genls-ok? format-ok? different-ok?)))

;; (defun arg-isa-arg-types-ok? (&optional reln arg argnum mt) ...) -- no body, active declareFunction

(defun arg-test-ok? (reln arg argnum &optional (test :isa))
  (let ((not-ok? nil))
    (if (eq reln #$Quote)
        (let ((*within-quote-form* t))
          (when (not (and (eq :opaque *at-arg-type*)
                          *at-relax-arg-constraints-for-opaque-expansion-nats?*
                          (validating-expansion?)
                          (missing-larkc 4385))) ;; likely checks if expansion nat
            (let ((*sbhl-table* (get-sbhl-marking-space)))
              (cond
                ((member? test '(:isa :not-isa-disjoint))
                 (when *at-check-inter-arg-isa?*
                   (setf not-ok? (inter-arg-test-fails? reln arg argnum test))))
                ((and *at-check-inter-arg-not-isa?*
                      (eql test :not-isa))
                 (setf not-ok? (inter-arg-test-fails? reln arg argnum test)))
                ((and *at-check-inter-arg-genl?*
                      (member? test '(:genls :not-genls-disjoint)))
                 (setf not-ok? (inter-arg-test-fails? reln arg argnum test)))
                ((and *at-check-inter-arg-format?*
                      (eql test :format))
                 (clear-cached-format-ok?)
                 (setf not-ok? (inter-arg-test-fails? reln arg argnum test)))
                ((and *at-check-inter-arg-different?*
                      (eql test :different))
                 (setf not-ok? (inter-arg-test-fails? reln arg argnum test))))
              (when (not (at-finished? not-ok?))
                (setf not-ok? (or (mal-intra-arg? reln arg argnum test)
                                  not-ok?)))
              (free-sbhl-marking-space *sbhl-table*))))
        ;; Non-Quote case
        (when (not (and (eq :opaque *at-arg-type*)
                        *at-relax-arg-constraints-for-opaque-expansion-nats?*
                        (validating-expansion?)
                        (missing-larkc 4386))) ;; likely checks if expansion nat
          (let ((*sbhl-table* (get-sbhl-marking-space)))
            (cond
              ((member? test '(:isa :not-isa-disjoint))
               (when *at-check-inter-arg-isa?*
                 (setf not-ok? (inter-arg-test-fails? reln arg argnum test))))
              ((and *at-check-inter-arg-not-isa?*
                    (eql test :not-isa))
               (setf not-ok? (inter-arg-test-fails? reln arg argnum test)))
              ((and *at-check-inter-arg-genl?*
                    (member? test '(:genls :not-genls-disjoint)))
               (setf not-ok? (inter-arg-test-fails? reln arg argnum test)))
              ((and *at-check-inter-arg-format?*
                    (eql test :format))
               (clear-cached-format-ok?)
               (setf not-ok? (inter-arg-test-fails? reln arg argnum test)))
              ((and *at-check-inter-arg-different?*
                    (eql test :different))
               (setf not-ok? (inter-arg-test-fails? reln arg argnum test))))
            (when (not (at-finished? not-ok?))
              (setf not-ok? (or (mal-intra-arg? reln arg argnum test)
                                not-ok?)))
            (free-sbhl-marking-space *sbhl-table*))))
    (not not-ok?)))

(defun inter-arg-test-fails? (reln arg argnum &optional (test :isa))
  (let ((ind-argnum 0)
        (not-ok? nil)
        (done? nil))
    (dolist (ind-arg (formula-args *at-formula*))
      (when done? (return))
      (incf ind-argnum)
      (when (not (eql argnum ind-argnum))
        (setf not-ok? (or (mal-inter-arg? reln ind-arg ind-argnum arg argnum test)
                          not-ok?))
        (setf done? (at-finished? not-ok?))))
    not-ok?))

(defun mal-intra-arg? (reln arg argnum test)
  (case test
    (:isa (mal-arg-isa? reln arg argnum))
    (:quoted-isa (mal-arg-quoted-isa? reln arg argnum))
    (:genls (mal-arg-genls? reln arg argnum))
    (:not-isa-disjoint (mal-arg-not-isa-disjoint? reln arg argnum))
    (:not-quoted-isa-disjoint (mal-arg-not-quoted-isa-disjoint? reln arg argnum))
    (:not-genls-disjoint (mal-arg-not-genls-disjoint? reln arg argnum))
    (:format (mal-arg-format? reln arg argnum))
    (:different nil)
    (otherwise
     (el-error 3 "invalid at test ~s in mal-intra-arg?" test)
     nil)))

(defun mal-inter-arg? (reln ind-arg ind-argnum dep-arg dep-argnum test)
  (case test
    (:isa (mal-inter-arg-isa? reln ind-arg ind-argnum dep-arg dep-argnum))
    (:not-isa (mal-inter-arg-not-isa? reln ind-arg ind-argnum dep-arg dep-argnum))
    (:not-isa-disjoint (mal-inter-arg-not-isa-disjoint? reln ind-arg ind-argnum dep-arg dep-argnum))
    (:genls (missing-larkc 11255)) ;; likely mal-inter-arg-genls?
    (:not-genls-disjoint (missing-larkc 11256)) ;; likely mal-inter-arg-not-genls-disjoint?
    (:format (mal-inter-arg-format? reln ind-arg ind-argnum dep-arg dep-argnum))
    (:different
     (and (> ind-argnum dep-argnum)
          (mal-inter-arg-different? reln ind-arg ind-argnum dep-arg dep-argnum)))
    (otherwise
     (el-error 3 "invalid at test ~s in mal-inter-arg?" test)
     nil)))

(defun defining-mts-ok? (fort &optional mt)
  "[Cyc] Return booleanp; t iff FORT is ok wrt defining-mt constraints."
  (cond
    ((not (and (fort-p fort) (at-check-defining-mts-p)))
     t)
    ((within-wff?)
     (missing-larkc 23216)) ;; likely memoized-defining-mts-ok? within wff
    (t
     (missing-larkc 23205)))) ;; likely defining-mts-ok-int?

;; (defun memoized-defining-mts-ok?-internal (fort mt) ...) -- no body, active declareFunction
;; (defun memoized-defining-mts-ok? (fort mt) ...) -- no body, active declareFunction
;; (defun defining-mts-ok-int? (fort &optional mt) ...) -- no body, active declareFunction

(defun relator-constraints-ok? (relation &optional mt)
  (let ((relator (formula-arg0 relation))
        (ok? t))
    (cond
      ((not *at-check-relator-constraints?*))
      ((not (fort-p relator)))
      ((kb-predicate? relator)
       (setf ok? (predicate-constraints-ok? relation mt))))
    ok?))

(defun predicate-constraints-ok? (literal &optional mt)
  (let ((ok? t)
        (predicate (literal-predicate literal))
        (done? nil))
    (let ((*at-mode* nil))
      (dolist (mode *at-pred-constraints*)
        (when done? (return))
        (setf *at-mode* mode)
        (case *at-mode*
          (:asymmetric-predicate
           (when (asymmetric-predicate? predicate)
             (let ((*gather-at-predicate-violations?* t)
                   (*at-predicate-violations* nil))
               (setf ok? (and (missing-larkc 23211) ;; likely gaf-ok-wrt-asymmetric-pred?
                              ok?)))))
          (:anti-symmetric-predicate
           (when (anti-symmetric-predicate? predicate)
             (let ((*gather-at-predicate-violations?* t)
                   (*at-predicate-violations* nil))
               (setf ok? (and (missing-larkc 23209) ;; likely gaf-ok-wrt-anti-symmetric-pred?
                              ok?)))))
          (:irreflexive-predicate
           (when (irreflexive-predicate? predicate)
             (let ((*gather-at-predicate-violations?* t)
                   (*at-predicate-violations* nil))
               (setf ok? (and (gaf-ok-wrt-irreflexive-pred? literal mt)
                              ok?)))))
          (:anti-transitive-predicate
           (when (anti-transitive-predicate? predicate)
             (let ((*gather-at-predicate-violations?* t)
                   (*at-predicate-violations* nil))
               (setf ok? (and (missing-larkc 23210) ;; likely gaf-ok-wrt-anti-transitive-pred?
                              ok?)))))
          (:negation-preds
           (let ((*gather-at-predicate-violations?* t)
                 (*at-predicate-violations* nil))
             (setf ok? (and (gaf-ok-wrt-negation-preds? literal mt)
                            ok?))))
          (:negation-inverses
           (let ((*gather-at-predicate-violations?* t)
                 (*at-predicate-violations* nil))
             (setf ok? (and (gaf-ok-wrt-negation-inverses? literal mt)
                            ok?))))
          (otherwise
           (el-error 3 "unknown predicate constraint: ~s" *at-mode*)))
        (when (not ok?)
          (when (not *accumulating-at-violations?*)
            (setf done? t)))))
    ok?))

;; (defun gaf-ok-wrt-asymmetric-pred? (gaf &optional mt) ...) -- no body, active declareFunction
;; (defun asymmetric-violations (gaf mt) ...) -- no body, active declareFunction
;; (defun gather-asymmetric-violations (pred arg1 arg2) ...) -- no body, active declareFunction
;; (defun select-asymmetric-pred-violation (assertion) ...) -- no body, active declareFunction
;; (defun gaf-ok-wrt-anti-symmetric-pred? (gaf &optional mt) ...) -- no body, active declareFunction
;; (defun anti-symmetric-violations (gaf mt) ...) -- no body, active declareFunction

(defun gaf-ok-wrt-irreflexive-pred? (gaf &optional mt)
  (let ((ok? t)
        (arg1 (reify-arg-when-closed-naut gaf 1))
        (arg2 (reify-arg-when-closed-naut gaf 2)))
    (let ((*mt* (update-inference-mt-relevance-mt mt))
          (*relevant-mt-function* (update-inference-mt-relevance-function mt))
          (*relevant-mts* (update-inference-mt-relevance-mt-list mt)))
      (when (equals? arg1 arg2)
        (setf ok? nil)
        (let ((*at-pred* #$isa))
          (when *at-pred*
            (missing-larkc 7154)))) ;; likely reports at-violation
      (when (or ok? *accumulating-at-violations?*)
        (let ((pred (reify-arg-when-closed-naut gaf 0)))
          (when (and (transitive-predicate? pred)
                     (gtm pred :completes-cycle? arg1 arg2 mt))
            (setf ok? nil)
            (when *gather-at-predicate-violations?*
              (setf *at-predicate-violations*
                    (gtm pred :why-completes-cycle? arg1 arg2))
              (when *at-predicate-violations*
                (setf *at-predicate-violations*
                      (nconc (missing-larkc 5082) ;; likely creates hl-support for the violation
                             *at-predicate-violations*))))
            (let ((*at-pred* #$isa))
              (when *at-pred*
                (missing-larkc 7155)))))) ;; likely reports at-violation
    ok?)))

;; (defun gaf-ok-wrt-anti-transitive-pred? (gaf &optional mt) ...) -- no body, active declareFunction
;; (defun anti-transitive-violations (gaf mt) ...) -- no body, active declareFunction
;; (defun gather-anti-transitive-violations (pred arg1 arg2) ...) -- no body, active declareFunction
;; (defun search-for-anti-transitive-pred-violation (assertion) ...) -- no body, active declareFunction
;; (defun search-for-anti-transitive-pred-violation-pivot (assertion) ...) -- no body, active declareFunction
;; (defun search-for-anti-transitive-pred-violation-swap (assertion) ...) -- no body, active declareFunction
;; (defun select-anti-transitive-pred-violation (assertion) ...) -- no body, active declareFunction
;; (defun select-anti-transitive-pred-violation-via-pred (assertion) ...) -- no body, active declareFunction

(defun find-accessible-gaf (gaf &optional index mt (truth :true))
  (let ((assertion nil))
    (let ((*mapping-target* gaf)
          (*mapping-answer* nil))
      (let ((*relevant-mt-function* (possibly-in-mt-determine-function mt))
            (*mt* (possibly-in-mt-determine-mt mt)))
        (cond
          ((eql 0 index)
           (missing-larkc 9471)) ;; likely maps predicate extent index
          (index
           (gp-map-arg-index 'select-target-gaf
                                            (literal-arg gaf index)
                                            index
                                            (literal-predicate gaf)))
          (t
           (let ((best-count (num-best-gaf-lookup-index gaf truth '(:predicate-extent :gaf-arg))))
             (when (or (not (numberp *fag-search-limit*))
                       (>= *fag-search-limit* best-count))
               (let ((lookup-index (best-gaf-lookup-index gaf truth '(:predicate-extent :gaf-arg))))
                 (let ((index-type (lookup-index-get-type lookup-index)))
                   (case index-type
                     (:predicate-extent
                      (let ((predicate (missing-larkc 12758))) ;; likely lookup-index-predicate-extent-value
                        (missing-larkc 9472))) ;; likely maps predicate extent
                     (:gaf-arg
                      (multiple-value-bind (v-term argnum predicate)
                          (lookup-index-gaf-arg-values lookup-index)
                        (gp-map-arg-index 'select-target-gaf v-term argnum predicate)))))))))))
      (setf assertion *mapping-answer*))
    assertion))

;; (defun select-target-gaf (assertion) ...) -- no body, active declareFunction

(defun gaf-ok-wrt-negation-preds? (gaf &optional mt)
  (let ((pred (reify-arg-when-closed-naut gaf 0))
        (arg1 (reify-arg-when-closed-naut gaf 1))
        (arg2 (reify-arg-when-closed-naut gaf 2))
        (violations nil))
    (let ((*mt* (update-inference-mt-relevance-mt mt))
          (*relevant-mt-function* (update-inference-mt-relevance-function mt))
          (*relevant-mts* (update-inference-mt-relevance-mt-list mt)))
      (setf violations (negation-pred-violations pred arg1 arg2)))
    (null violations)))

(defun negation-pred-violations (pred arg1 arg2)
  (let ((done? nil)
        (violations nil)
        (args (list arg1 arg2)))
    (dolist (negation-pred (max-negation-preds pred))
      (when done? (return))
      (let ((assertion (find-accessible-gaf
                        (canonicalize-literal-commutative-terms
                         (make-el-literal negation-pred args)))))
        (when (kb-assertion? assertion)
          (let ((*gather-at-predicate-violations?* t)
                (*at-predicate-violations* nil))
            (pushnew assertion *at-predicate-violations* :test #'eql)
            (let ((*at-pred* #$negationPreds))
              (when *at-pred*
                (missing-larkc 7157)))) ;; likely reports at-violation
          (push negation-pred violations)
          (when (not *accumulating-at-violations?*)
            (setf done? t)))))
    violations))

(defun gaf-ok-wrt-negation-inverses? (gaf &optional mt)
  (let ((pred (reify-arg-when-closed-naut gaf 0))
        (arg1 (reify-arg-when-closed-naut gaf 1))
        (arg2 (reify-arg-when-closed-naut gaf 2))
        (violations nil))
    (let ((*mt* (update-inference-mt-relevance-mt mt))
          (*relevant-mt-function* (update-inference-mt-relevance-function mt))
          (*relevant-mts* (update-inference-mt-relevance-mt-list mt)))
      (setf violations (negation-inverse-violations pred arg1 arg2)))
    (null violations)))

(defun negation-inverse-violations (pred arg1 arg2)
  (let ((done? nil)
        (violations nil)
        (args (list arg2 arg1)))
    (dolist (negation-inverse (max-negation-inverses pred))
      (when done? (return))
      (let ((assertion (find-accessible-gaf
                        (canonicalize-literal-commutative-terms
                         (make-el-literal negation-inverse args)))))
        (when (kb-assertion? assertion)
          (let ((*gather-at-predicate-violations?* t)
                (*at-predicate-violations* nil))
            (pushnew assertion *at-predicate-violations* :test #'eql)
            (let ((*at-pred* #$negationInverse))
              (when *at-pred*
                (missing-larkc 7158)))) ;; likely reports at-violation
          (push negation-inverse violations)
          (when (not *accumulating-at-violations?*)
            (setf done? t)))))
    violations))

(defun clear-cached-format-ok? ()
  (let ((cs *cached-format-ok?-caching-state*))
    (when cs
      (caching-state-clear cs)))
  nil)

;; (defun remove-cached-format-ok? (v1) ...) -- no body, active declareFunction
;; (defun cached-format-ok?-internal (v1) ...) -- no body, active declareFunction
;; (defun cached-format-ok? (v1) ...) -- no body, active declareFunction

(defun memoized-format-ok?-internal (format literal argnum mt)
  (at-format-ok? format literal argnum mt))

(defun memoized-format-ok? (format literal argnum mt)
  (let ((v-memoization-state *memoization-state*))
    (if (null v-memoization-state)
        (memoized-format-ok?-internal format literal argnum mt)
        (let ((caching-state (memoization-state-lookup v-memoization-state 'memoized-format-ok?)))
          (when (null caching-state)
            (setf caching-state (create-caching-state (memoization-state-lock v-memoization-state)
                                                      'memoized-format-ok? 4 nil #'equal))
            (memoization-state-put v-memoization-state 'memoized-format-ok? caching-state))
          (let* ((sxhash (sxhash-calc-4 format literal argnum mt))
                 (collisions (caching-state-lookup caching-state sxhash)))
            (if (not (eq collisions :&memoized-item-not-found&))
                (dolist (collision collisions
                         ;; Fall through: compute and cache
                         (let ((results (multiple-value-list (memoized-format-ok?-internal format literal argnum mt))))
                           (caching-state-enter-multi-key-n caching-state sxhash collisions results
                                                            (list format literal argnum mt))
                           (caching-results results)))
                  (let ((cached-args (first collision))
                        (results2 (second collision)))
                    (when (and (equal format (pop cached-args))
                               (equal literal (pop cached-args))
                               (equal argnum (pop cached-args))
                               cached-args
                               (null (rest cached-args))
                               (equal mt (first cached-args)))
                      (return (caching-results results2)))))
                (let ((results (multiple-value-list (memoized-format-ok?-internal format literal argnum mt))))
                  (caching-state-enter-multi-key-n caching-state sxhash collisions results
                                                   (list format literal argnum mt))
                  (caching-results results))))))))

(defun at-format-ok? (format &optional
                        (literal *at-formula*)
                        (argnum *at-argnum*)
                        (mt *mt*))
  (case format
    (#$SingleEntry (single-entry-ok? literal argnum mt))
    (#$IntervalEntry (missing-larkc 23213)) ;; likely interval-entry-ok?
    (#$SetTheFormat (set-entry-ok? literal argnum mt))
    (#$singleEntryFormatInArgs (single-entry-ok? literal argnum mt))
    (#$intervalEntryFormatInArgs (missing-larkc 23214)) ;; likely interval-entry-ok?
    (#$openEntryFormatInArgs (set-entry-ok? literal argnum mt))
    (#$temporallyIntersectingEntryFormatInArgs (missing-larkc 23238)) ;; likely temporally-intersecting-ok?
    (#$spatiallyIntersectingEntryFormatInArgs (missing-larkc 23236)) ;; likely spatially-intersecting-ok?
    (#$spatioTemporallyIntersectingEntryFormatInArgs (missing-larkc 23237)) ;; likely spatio-temporally-intersecting-ok?
    (otherwise
     (el-error 3 "unknown entry format: ~s" format)
     t)))

(defun single-entry-ok? (literal argnum mt)
  (when *at-check-sef?*
    (null (sef-violations literal argnum mt))))

;; (defun literal-single-entry-ok? (literal argnum mt) ...) -- no body, active declareFunction
;; (defun why-not-literal-single-entry-ok? (literal argnum mt &optional v4) ...) -- no body, active declareFunction

(defun sef-violations (literal argnum mt)
  (let ((violations nil)
        (find-formula (replace-nth argnum (find-variable-by-id 0) literal))
        (arg (reify-arg-when-closed-naut literal argnum)))
    (unless (and (validating-expansion?)
                 (asent-unify (unexpanded-formula) find-formula t))
      (let ((*mt* (update-inference-mt-relevance-mt mt))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt)))
        (let ((lookup-index (best-gaf-lookup-index find-formula :true '(:predicate-extent :gaf-arg)))
              (done? nil))
          (let ((*within-at-mapping?* t))
            (let ((index-type (lookup-index-get-type lookup-index)))
              (case index-type
                (:predicate-extent
                 (let ((predicate (missing-larkc 12759))) ;; likely lookup-index-predicate-extent-value
                   (when (missing-larkc 23202) ;; likely check-inter-assert-format-w/o-arg-index?
                     (when (do-predicate-extent-index-key-validator predicate)
                       (let ((iterator-var (new-predicate-extent-final-index-spec-iterator predicate)))
                         (do ((done-var done?)
                              (token-var nil))
                             (done-var)
                           (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                                  (valid (not (eq token-var final-index-spec))))
                             (when valid
                               (let ((final-index-iterator nil))
                                 (unwind-protect
                                      (progn
                                        (setf final-index-iterator
                                              (new-final-index-iterator final-index-spec :gaf nil nil))
                                        (do ((done-var-2 done?)
                                             (token-var-2 nil))
                                            (done-var-2)
                                          (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                                 (valid-2 (not (eq token-var-2 assertion))))
                                            (when valid-2
                                              (when (sef-violating-assertion? assertion find-formula arg argnum)
                                                (push assertion violations)
                                                (when (not *accumulating-at-violations?*)
                                                  (setf done? t))))
                                            (setf done-var-2 (or (not valid-2) done?)))))
                                   (when final-index-iterator
                                     (destroy-final-index-iterator final-index-iterator)))))
                             (setf done-var (or (not valid) done?)))))))))
                (:gaf-arg
                 (multiple-value-bind (v-term largnum predicate)
                     (lookup-index-gaf-arg-values lookup-index)
                   (when (do-gaf-arg-index-key-validator v-term largnum predicate)
                     (let ((iterator-var (new-gaf-arg-final-index-spec-iterator v-term largnum predicate)))
                       (do ((done-var done?)
                            (token-var nil))
                           (done-var)
                         (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                                (valid (not (eq token-var final-index-spec))))
                           (when valid
                             (let ((final-index-iterator nil))
                               (unwind-protect
                                    (progn
                                      (setf final-index-iterator
                                            (new-final-index-iterator final-index-spec :gaf nil nil))
                                      (do ((done-var-2 done?)
                                           (token-var-2 nil))
                                          (done-var-2)
                                        (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                               (valid-2 (not (eq token-var-2 assertion))))
                                          (when valid-2
                                            (when (sef-violating-assertion? assertion find-formula arg argnum)
                                              (push assertion violations)
                                              (when (not *accumulating-at-violations?*)
                                                (setf done? t))))
                                          (setf done-var-2 (or (not valid-2) done?)))))
                                 (when final-index-iterator
                                   (destroy-final-index-iterator final-index-iterator)))))
                           (setf done-var (or (not valid) done?))))))))))))))
    violations))

;; (defun check-inter-assert-format-w/o-arg-index? (predicate) ...) -- no body, active declareFunction

(defun sef-violating-assertion? (assertion find-formula arg argnum)
  (when (gaf-assertion? assertion)
    (let ((gaf (gaf-formula assertion)))
      (when (asent-unify find-formula gaf t)
        (when (not (equals? arg (reify-arg-when-closed-naut gaf argnum)))
          (when *gather-at-format-violations?*
            (pushnew assertion *at-format-violations* :test #'eql))
          t)))))

;; (defun temporally-intersecting-ok? (literal argnum mt) ...) -- no body, active declareFunction
;; (defun tief-violations (literal argnum mt) ...) -- no body, active declareFunction
;; (defun spatially-intersecting-ok? (literal argnum mt) ...) -- no body, active declareFunction
;; (defun sief-violations (literal argnum mt) ...) -- no body, active declareFunction
;; (defun sief-violating-assertion? (assertion find-formula arg argnum) ...) -- no body, active declareFunction
;; (defun spatio-temporally--intersecting-ok? (literal argnum mt) ...) -- no body, active declareFunction
;; (defun stief-violations (literal argnum mt) ...) -- no body, active declareFunction
;; (defun interval-entry-ok? (literal argnum mt) ...) -- no body, active declareFunction

(defun set-entry-ok? (literal argnum mt)
  (declare (ignore literal argnum mt))
  t)

(defun variable-wrt-arg-type? (arg)
  (cond
    ((not *recognize-variables?*) nil)
    ((variable-term-wrt-arg-type? arg) t)
    ((and (first-order-naut? arg)
          (or (missing-larkc 6981)  ;; likely formula-with-sequence-termP
              (missing-larkc 6985)  ;; likely expression-find-if for variables
              (missing-larkc 6989))) ;; likely expression-find-if for variables
     nil)
    ((and (naut? arg)
          (formula-find-if 'variable-term-wrt-arg-type? arg))
     t)
    (t nil)))

(defun variable-term-wrt-arg-type? (v-term)
  (or (el-var? v-term)
      (kb-var? v-term)
      (and *permit-generic-arg-variables?*
           (missing-larkc 3469)) ;; likely generic-arg-variable-p
      (and *permit-keyword-variables?*
           (keywordp v-term))
      (reified-skolem-term? v-term)
      (unreified-skolem-term? v-term)
      (and *relax-type-restrictions-for-nats*
           (nart-p v-term))))

(defun naut-wrt-arg-type? (v-term mt)
  (declare (ignore mt))
  (or (and *within-decontextualized?*
           (naut-p v-term))
      (and (not (nart-p v-term))
           (function-term? v-term)
           (or (fort-p (nat-functor v-term))
               (not (missing-larkc 8828)))))) ;; likely checks if functor is closable

(defun tou-wrt-arg-type? (v-term)
  (declare (ignore v-term))
  (eql *at-reln* #$termOfUnit))

(defun nat-function-wrt-arg-type? (v-term)
  (declare (ignore v-term))
  (eq *at-reln* #$natFunction))

(defun nat-argument-wrt-arg-type? (v-term)
  (declare (ignore v-term))
  (eq *at-reln* #$natArgument))

(defun strong-fort-wrt-arg-type? (v-term &optional mt)
  (declare (ignore mt))
  (fort-p v-term))

(defun weak-fort-wrt-arg-type? (v-term)
  (or (and (or *appraising-disjunct?*
               *within-decontextualized?*
               (wff-lenient?))
           (fort-p v-term))
      (and *at-admit-consistent-narts?*
           (or (nart-p v-term)
               (and (reifiable-naut? v-term)
                    (missing-larkc 10319)))))) ;; likely nart-lookup

;; (defun semantically-valid-dnf? (dnf &optional mt v3) ...) -- no body, active declareFunction
;; (defun semantically-valid-dnf-type-literals? (dnf &optional mt v3) ...) -- no body, active declareFunction
;; (defun semantically-valid-literal? (literal &optional mt v3) ...) -- no body, active declareFunction
;; (defun semantically-valid-literal-int? (literal &optional mt v3) ...) -- no body, active declareFunction
;; (defun why-not-assertion-semantically-valid? (assertion) ...) -- no body, active declareFunction
;; (defun why-not-cnf-semantically-valid? (cnf &optional mt) ...) -- no body, active declareFunction
;; (defun why-not-cnf-semantically-valid-int (cnf mt) ...) -- no body, active declareFunction
;; (defun why-not-literal-semantically-valid? (literal &optional mt) ...) -- no body, active declareFunction

;; arg-constraint struct definition
;; print-object is missing-larkc 23227 — CL's default print-object handles this.
(defstruct (arg-constraint (:conc-name "ARGCONST-"))
  sentence
  mt
  test-function
  test-args
  closed?
  atomic?)

;; (defun arg-constraint-p (object) ...) -- generated by defstruct
;; (defun argconst-sentence (arg-constraint) ...) -- generated by defstruct
;; (defun argconst-mt (arg-constraint) ...) -- generated by defstruct
;; (defun argconst-test-function (arg-constraint) ...) -- generated by defstruct
;; (defun argconst-test-args (arg-constraint) ...) -- generated by defstruct
;; (defun argconst-closed? (arg-constraint) ...) -- generated by defstruct
;; (defun argconst-atomic? (arg-constraint) ...) -- generated by defstruct
;; (defun _csetf-argconst-sentence (arg-constraint val) ...) -- setf of slot accessor
;; (defun _csetf-argconst-mt (arg-constraint val) ...) -- setf of slot accessor
;; (defun _csetf-argconst-test-function (arg-constraint val) ...) -- setf of slot accessor
;; (defun _csetf-argconst-test-args (arg-constraint val) ...) -- setf of slot accessor
;; (defun _csetf-argconst-closed? (arg-constraint val) ...) -- setf of slot accessor
;; (defun _csetf-argconst-atomic? (arg-constraint val) ...) -- setf of slot accessor
;; (defun make-arg-constraint (&optional v1) ...) -- generated by defstruct
;; (defun print-arg-constraint (object stream depth) ...) -- no body, active declareFunction
;; (defun arg-constraint-sentence (arg-constraint) ...) -- no body, active declareFunction
;; (defun arg-constraint-mt (arg-constraint) ...) -- no body, active declareFunction
;; (defun arg-constraint-test-function (arg-constraint) ...) -- no body, active declareFunction
;; (defun arg-constraint-test-args (arg-constraint) ...) -- no body, active declareFunction
;; (defun arg-constraint-open-p (arg-constraint) ...) -- no body, active declareFunction
;; (defun arg-constraint-closed-p (arg-constraint) ...) -- no body, active declareFunction
;; (defun arg-constraint-atomic-p (arg-constraint) ...) -- no body, active declareFunction
;; (defun arg-constraint-non-atomic-p (arg-constraint) ...) -- no body, active declareFunction
;; (defun arg-constraint-gaf-p (arg-constraint) ...) -- no body, active declareFunction
;; (defun arg-constraint-type-string (arg-constraint) ...) -- no body, active declareFunction
;; (defun new-arg-constraint (sentence mt test-function test-args &optional closed? atomic?) ...) -- no body, active declareFunction
;; (defun determine-arg-constraint-closed? (sentence mt) ...) -- no body, active declareFunction
;; (defun determine-arg-constraint-atomic? (sentence mt) ...) -- no body, active declareFunction
;; (defun new-isa-arg-constraint (sentence mt assertion) ...) -- no body, active declareFunction
;; (defun new-genls-arg-constraint (sentence mt assertion) ...) -- no body, active declareFunction
;; (defun clear-sorted-arg-constraint-predicates () ...) -- no body, active declareFunction
;; (defun remove-sorted-arg-constraint-predicates () ...) -- no body, active declareFunction
;; (defun sorted-arg-constraint-predicates-internal () ...) -- no body, active declareFunction
;; (defun sorted-arg-constraint-predicates () ...) -- no body, active declareFunction
;; (defun sorted-top-level-arg-constraints-on-formula (formula) ...) -- no body, active declareFunction
;; (defun inside-out-arg-constraints-on-formula (formula) ...) -- no body, active declareFunction
;; (defun arg-constraint-satisfied? (arg-constraint) ...) -- no body, active declareFunction
;; (defun arg-constraints-on-formula-with-variable-operator (formula) ...) -- no body, active declareFunction
;; (defun compute-constraint-for-assertion-and-formula (assertion formula) ...) -- no body, active declareFunction

;; Setup phase

(toplevel
  (note-globally-cached-function 'cached-relation-arg-ok?)
  (note-memoized-function 'memoized-defining-mts-ok?)
  (note-globally-cached-function 'cached-format-ok?)
  (note-memoized-function 'memoized-format-ok?)
  (note-globally-cached-function 'sorted-arg-constraint-predicates))
