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

;; Variables

(defparameter *default-superset-cost* *hl-module-check-cost*)

(defparameter *default-nat-all-genls-cost* *average-all-genls-count*)

(defparameter *all-specs-lazy-iteration-threshold* 550)

(defparameter *default-not-superset-cost* 1)

;; Functions in declareFunction order:

(defun inference-genl? (spec genl &optional mt tv)
  (and (inference-collection? spec mt)
       (or (equal spec genl)
           (and (inference-collection? genl mt)
                (genl? spec genl mt tv)))))

;; (defun inference-not-genl? (spec genl &optional mt tv) ...) -- active declareFunction, no body

(defun inference-all-genls (spec &optional mt tv)
  (when (inference-collection? spec mt)
    (all-genls spec mt tv)))

(defun inference-all-specs (genl &optional mt tv)
  (when (inference-collection? genl mt)
    (all-specs genl mt tv)))

;; (defun inference-genls-between (arg1 arg2 &optional arg3) ...) -- active declareFunction, no body

(defun removal-superset-expand (asent &optional sense)
  (declare (ignore sense))
  (let ((spec (atomic-sentence-arg1 asent))
        (genl (atomic-sentence-arg2 asent)))
    (when (inference-genl? spec genl)
      (removal-add-node (make-hl-support :genls asent))))
  nil)

;; (defun removal-nat-genls-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-all-genls-cost (asent &optional sense)
  (declare (ignore sense))
  (genl-cardinality (atomic-sentence-arg1 asent)))

(defun removal-all-genls-expand (asent &optional sense)
  (declare (ignore sense))
  (let* ((subset (atomic-sentence-arg1 asent))
         (arg2 (atomic-sentence-arg2 asent))
         (collections (inference-all-genls subset)))
    (dolist (collection collections)
      (multiple-value-bind (v-bindings unify-justification)
          (term-unify arg2 collection t t)
        (when v-bindings
          (let* ((unify-arg2 (subst-bindings v-bindings arg2))
                 (formula (list #$genls subset unify-arg2)))
            (removal-add-node (make-hl-support :genls formula)
                              v-bindings
                              unify-justification))))))
  nil)

;; (defun removal-nat-all-genls-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-all-specs-cost (asent &optional sense)
  (declare (ignore sense))
  (let ((collection (atomic-sentence-arg2 asent)))
    (max (spec-cardinality collection)
         (relevant-num-gaf-arg-index collection 2 #$genls))))

(defun removal-all-specs-iterator (collection)
  (if (> (spec-cardinality collection) *all-specs-lazy-iteration-threshold*)
      ;; Likely constructs a lazy iterator over specs -- evidence: threshold guards against eager collection.
      (missing-larkc 287)
      (new-list-iterator (inference-all-specs collection))))

;; (defun removal-not-superset-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-genls-between-applicability (contextualized-dnf-clause)
  (removal-sbhl-between-applicability contextualized-dnf-clause #$genls))

;; (defun removal-genls-between-cost (subclause-spec) ...) -- active declareFunction, no body
;; (defun removal-genls-between-completeness () ...) -- active declareFunction, no body
;; (defun removal-genls-between-expand (subclause-spec) ...) -- active declareFunction, no body

(defun removal-sbhl-between-applicability (contextualized-dnf-clause predicate)
  (let ((subclause-specs nil))
    (multiple-value-bind (pos-pred-indices-var-arg1 pos-pred-indices-var-arg2)
        (find-pos-pred-indices-for-pred-between contextualized-dnf-clause predicate)
      (when (and pos-pred-indices-var-arg1
                 pos-pred-indices-var-arg2)
        (let ((var2-index (new-dictionary #'eq)))
          (dolist (pair pos-pred-indices-var-arg2)
            (destructuring-bind (index variable) pair
              (dictionary-push var2-index variable index)))
          (dolist (pair pos-pred-indices-var-arg1)
            (destructuring-bind (index variable) pair
              (let ((paired-indices (gethash variable var2-index)))
                (dolist (paired-index paired-indices)
                  (let ((subclause-spec (new-subclause-spec nil (list index paired-index))))
                    (push subclause-spec subclause-specs)))))))))
    (nreverse subclause-specs)))

(defun find-pos-pred-indices-for-pred-between (contextualized-dnf-clause predicate)
  (let ((pos-pred-indices-var-arg1 nil)
        (pos-pred-indices-var-arg2 nil)
        (index 0))
    (dolist (contextualized-asent (pos-lits contextualized-dnf-clause))
      (destructuring-bind (mt asent) contextualized-asent
        (declare (ignore mt))
        (when (atomic-sentence-with-pred-p asent predicate)
          (let ((arg1 (atomic-sentence-arg1 asent))
                (arg2 (atomic-sentence-arg2 asent)))
            (cond ((and (variable-p arg1)
                        (fort-p arg2))
                   (push (list index arg1) pos-pred-indices-var-arg1))
                  ((and (fort-p arg1)
                        (variable-p arg2))
                   (push (list index arg2) pos-pred-indices-var-arg2))))))
      (incf index))
    (setf pos-pred-indices-var-arg1 (nreverse pos-pred-indices-var-arg1))
    (setf pos-pred-indices-var-arg2 (nreverse pos-pred-indices-var-arg2))
    (values pos-pred-indices-var-arg1 pos-pred-indices-var-arg2)))

;; (defun removal-genls-between-categorize-asents (arg1 arg2) ...) -- active declareFunction, no body
;; (defun removal-genls-collection-subset-check-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-genls-collection-subset-check-neg-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-genls-collection-subset-construct-query (asent) ...) -- active declareFunction, no body
;; (defun removal-genls-down-arg2-bound-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-genls-down-arg2-bound-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-genls-down-arg2-bound-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun destructure-genls-down-asent (asent) ...) -- active declareFunction, no body

;; Setup phase (toplevel forms)

(toplevel
  (register-solely-specific-removal-module-predicate #$genls))

(toplevel
  (inference-removal-module-use-generic #$genls :removal-backchain-required-prune))

(toplevel
  (inference-preference-module :genls-x-y-pos
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls :not-fully-bound :not-fully-bound)
          :preference-level :disallowed)))

(toplevel
  (inference-preference-module :all-specs-of-fort-pos
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls :not-fully-bound :fort)
          :preference-level :dispreferred)))

(toplevel
  (inference-preference-module :all-specs-of-non-fort-pos
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls :not-fully-bound
                                  (list :and :fully-bound (list :not :fort)))
          :preference-level :grossly-dispreferred)))

(toplevel
  (inference-preference-module :all-genls-pos
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls :fully-bound :not-fully-bound)
          :preference-level :dispreferred)))

(toplevel
  (inference-removal-module :removal-superset
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls :fort :fully-bound)
          :cost-expression '*default-superset-cost*
          :expand 'removal-superset-expand
          :documentation "(#$genls <fort> <fully-bound>)"
          :example "(#$genls #$Dog #$Animal)")))

(toplevel
  (inference-removal-module :removal-nat-genls
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls (cons :fully-bound :fully-bound) :fully-bound)
          :cost-expression '*default-superset-cost*
          :expand 'removal-nat-genls-expand
          :documentation "(#$genls (<fully-bound> . <fully-bound>) <fully-bound>)
    via #$resultGenl and #$resultGenlArg"
          :example "(#$genls (#$JuvenileFn #$Cougar) #$Animal)")))

(toplevel
  (inference-removal-module :removal-all-genls
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls :fort :not-fully-bound)
          :cost 'removal-all-genls-cost
          :expand 'removal-all-genls-expand
          :documentation "(#$genls <fort> <not fully-bound>)"
          :example "(#$genls #$Dog ?WHAT)")))

(toplevel
  (inference-removal-module :removal-nat-all-genls
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls (cons :fully-bound :fully-bound) :not-fully-bound)
          :cost-expression '*default-nat-all-genls-cost*
          :expand 'removal-nat-all-genls-expand
          :documentation "(#$genls (<fully-bound> . <fully-bound>) <not fully-bound>)
    via #$resultGenl and #$resultGenlArg"
          :example "(#$genls (#$JuvenileFn #$Cougar) ?WHAT)")))

(toplevel
  (inference-removal-module :removal-all-specs
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls :not-fully-bound :fort)
          :cost 'removal-all-specs-cost
          :completeness :grossly-incomplete
          :input-extract-pattern '(:template (#$genls :anything (:bind collection))
                                             (:value collection))
          :output-generate-pattern '(:call removal-all-specs-iterator :input)
          :output-construct-pattern (list #$genls :input '(:value collection))
          :support-module :genls
          :support-strength :default
          :documentation "(#$genls <not fully-bound> <fort>)"
          :example "(#$genls ?WHAT #$Animal)")))

(toplevel
  (inference-removal-module :removal-not-superset
    (list :sense :neg
          :predicate #$genls
          :required-pattern (list #$genls (list :or :fort (cons :fully-bound :fully-bound)) :fully-bound)
          :cost-expression '(fif *negation-by-failure* *default-superset-cost* *default-not-superset-cost*)
          :expand 'removal-not-superset-expand
          :documentation "(#$not (#$genls <fort> <fully-bound>))
    (#$not (#$genls (<fully-bound> . <fully-bound>) <fully-bound>))"
          :example "(#$not (#$genls #$Collection #$Individual))
    (#$not (#$genls (#$JuvenileFn #$Cougar) #$Individual))")))

(toplevel
  (inference-conjunctive-removal-module :removal-genls-between
    (list :every-predicates (list #$genls)
          :applicability 'removal-genls-between-applicability
          :cost 'removal-genls-between-cost
          :completeness-pattern '(:call removal-genls-between-completeness)
          :expand 'removal-genls-between-expand
          :documentation "(#$and (#$genls <fort1> <varN>)
           (#$genls <varN> <fort2>))"
          :example "(#$and (#$genls #$Dog ?COL)
           (#$genls ?COL #$Animal))")))

(toplevel
  (note-funcall-helper-function 'removal-genls-between-completeness))

(toplevel
  (inference-removal-module :removal-genls-collection-subset-fn-pos-check
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls
                                  (list :nat (cons #$CollectionSubsetFn :fully-bound))
                                  (list :nat (cons #$CollectionSubsetFn :fully-bound)))
          :cost-expression '*expensive-hl-module-check-cost*
          :completeness :grossly-incomplete
          :expand 'removal-genls-collection-subset-check-pos-expand
          :documentation "(#$genls (#$CollectionSubsetFn . <fully-bound>) (#$CollectionSubsetFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-genls-collection-subset-fn-neg-check
    (list :sense :neg
          :predicate #$genls
          :required-pattern (list #$genls
                                  (list :nat (cons #$CollectionSubsetFn :fully-bound))
                                  (list :nat (cons #$CollectionSubsetFn :fully-bound)))
          :cost-expression '*expensive-hl-module-check-cost*
          :completeness :grossly-incomplete
          :expand 'removal-genls-collection-subset-check-neg-expand
          :documentation "(#$not (#$genls (#$CollectionSubsetFn . <fully-bound>) (#$CollectionSubsetFn . <fully-bound>)))")))

(toplevel
  (register-solely-specific-removal-module-predicate #$genlsDown))

(toplevel
  (inference-removal-module :removal-genls-down-arg2-bound
    (list :sense :pos
          :predicate #$genlsDown
          :required-pattern (list #$genlsDown :anything :fully-bound)
          :cost 'removal-genls-down-arg2-bound-cost
          :completeness-pattern '(:call removal-genls-down-arg2-bound-completeness :input)
          :expand 'removal-genls-down-arg2-bound-expand
          :documentation "(#$genlsDown <fully-bound> <fully-bound>)
(#$genlsDown <not-fully-bound> <fully-bound>)"
          :example "(#$genlsDown #$Dog #$Animal)
(#$genlsDown ?WHAT #$Dog)")))

(toplevel
  (note-funcall-helper-function 'removal-genls-down-arg2-bound-cost))
(toplevel
  (note-funcall-helper-function 'removal-genls-down-arg2-bound-completeness))
(toplevel
  (note-funcall-helper-function 'removal-genls-down-arg2-bound-expand))

(toplevel
  (inference-removal-module :removal-genls-down-arg2-unify
    (list :sense :pos
          :predicate #$genlsDown
          :required-pattern (list #$genlsDown :fully-bound :not-fully-bound)
          :cost-expression 1
          :completeness :complete
          :input-extract-pattern '(:template (#$genlsDown (:bind term) :anything)
                                             (:value term))
          :output-generate-pattern (list (list #$genlsDown :input :input))
          :support-module :reflexive
          :documentation "(#$genlsDown <fully-bound> <not-fully-bound>)"
          :example "(#$genlsDown #$Dog ?WHAT)")))
