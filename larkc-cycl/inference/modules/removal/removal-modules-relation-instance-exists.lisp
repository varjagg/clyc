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

(defun some-relation-instance-for-predicate (relation-instance-pred predicate &optional mt)
  (when (some-pred-value-in-relevant-mts predicate relation-instance-pred mt 1)
    t))

;; (defun removal-relation-instance-support-direction-relevant? (support) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-support-sentence (support) ...) -- active declareFunction, no body
;; (defun sksi-relation-instance-cost (asent) ...) -- active declareFunction, no body
;; (defun removal-all-spec-or-inverse-predicates (predicate mode) ...) -- active declareFunction, no body

(defun removal-some-relation-instance-exists-for-predicate (predicate mode &optional mt)
  (cond
    ((eq mode :both)
     (or (some-relation-instance-exists-for-predicate-and-spec predicate mt)
         (some-relation-instance-exists-for-predicate-and-inverse predicate mt)))
    ((eq mode :genl-preds)
     (some-relation-instance-exists-for-predicate-and-spec predicate mt))
    ((eq mode :genl-inverse)
     (some-relation-instance-exists-for-predicate-and-inverse predicate mt))))

(defun some-relation-instance-exists-for-predicate (predicate &optional mt)
  (some-relation-instance-for-predicate #$relationInstanceExists predicate mt))

(defun some-relation-instance-exists-for-predicate-and-spec (predicate mt)
  (let ((spec-predicates (inference-all-spec-predicates predicate)))
    (dolist (spec-predicate spec-predicates)
      (when (some-relation-instance-exists-for-predicate spec-predicate mt)
        (return t)))))

(defun some-relation-instance-exists-for-predicate-and-inverse (predicate mt)
  (let ((inv-predicates (inference-all-spec-inverses predicate)))
    (dolist (inv-predicate inv-predicates)
      (when (some-relation-instance-exists-for-predicate inv-predicate mt)
        (return t)))))

(defun removal-relation-instance-exists-required (asent mode require-new-terms-allowed?)
  (when (and require-new-terms-allowed?
             (not (current-query-allows-new-terms?)))
    (return-from removal-relation-instance-exists-required nil))
  (let ((predicate (atomic-sentence-predicate asent)))
    (and (not (hl-predicate-p predicate))
         (or (not require-new-terms-allowed?)
             (skolemization-allowed #$RelationInstanceExistsFn))
         (removal-some-relation-instance-exists-for-predicate predicate mode nil)
         t)))

(deflexical *relation-instance-exists-rule*
  (list-to-elf '(#$implies
                 (#$relationInstanceExists ?PRED ?THING ?COLL)
                 (?PRED ?THING (#$RelationInstanceExistsFn ?PRED ?THING ?COLL)))))

(defglobal *relation-instance-exists-defining-mt* #$BaseKB)

;; (defun make-relation-instance-exists-support () ...) -- active declareFunction, no body
;; (defun make-relation-instance-exists-term (predicate term coll) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-prune (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-check-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-check-expand-internal (predicate term coll asent mode) ...) -- active declareFunction, no body

(deflexical *default-relation-instance-exists-check-cost*
  *expensive-hl-module-check-cost*)

(defun removal-relation-instance-exists-unify-arg1-required (asent &optional sense)
  (declare (ignore sense))
  (removal-relation-instance-exists-required asent :genl-inverse t))

(defun removal-relation-instance-exists-unify-arg2-required (asent &optional sense)
  (declare (ignore sense))
  (removal-relation-instance-exists-required asent :genl-preds t))

(deflexical *minimum-relation-instance-exists-unify-cost*
  *expensive-hl-module-check-cost*)

;; (defun removal-relation-instance-exists-unify-cost (asent mode argnum) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unify-arg1-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unify-arg2-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unify-expand (asent mode argnum sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unify-arg1-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unify-arg2-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun relation-instance-exists-sksi-cost () ...) -- active declareFunction, no body
;; (defun relation-instance-exists-predicate-cost-estimate (predicate mode &optional mt) ...) -- active declareFunction, no body
;; (defun relation-instance-exists-object-cost-estimate (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unify-via-predicate-expand (asent mode argnum sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unify-via-object-expand (asent mode argnum) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unify-expand-guts (asent support-term support) ...) -- active declareFunction, no body

(defun removal-relation-instance-exists-unbound-required (asent mode)
  (removal-relation-instance-exists-required asent mode t))

(defun removal-relation-instance-exists-unbound-arg1-required (asent &optional sense)
  (declare (ignore sense))
  (removal-relation-instance-exists-unbound-required asent :genl-preds))

(defun removal-relation-instance-exists-unbound-arg2-required (asent &optional sense)
  (declare (ignore sense))
  (removal-relation-instance-exists-unbound-required asent :genl-inverse))

;; (defun removal-relation-instance-exists-unbound-cost (asent mode) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unbound-arg1-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unbound-arg2-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unbound-expand (asent mode) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unbound-arg1-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-unbound-arg2-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-some-relation-exists-instance-for-predicate (predicate mode &optional mt)
  (cond
    ((eq mode :both)
     (or (some-relation-exists-instance-for-predicate-and-spec predicate mt)
         (some-relation-exists-instance-for-predicate-and-inverse predicate mt)))
    ((eq mode :genl-preds)
     (some-relation-exists-instance-for-predicate-and-spec predicate mt))
    ((eq mode :genl-inverse)
     (some-relation-exists-instance-for-predicate-and-inverse predicate mt))))

(defun some-relation-exists-instance-for-predicate (predicate &optional mt)
  (some-relation-instance-for-predicate #$relationExistsInstance predicate mt))

(defun some-relation-exists-instance-for-predicate-and-spec (predicate mt)
  (let ((spec-predicates (inference-all-spec-predicates predicate)))
    (dolist (spec-predicate spec-predicates)
      (when (some-relation-exists-instance-for-predicate spec-predicate mt)
        (return t)))))

(defun some-relation-exists-instance-for-predicate-and-inverse (predicate mt)
  (let ((inv-predicates (inference-all-spec-inverses predicate)))
    (dolist (inv-predicate inv-predicates)
      (when (some-relation-exists-instance-for-predicate inv-predicate mt)
        (return t)))))

(defun removal-relation-exists-instance-required (asent mode require-new-terms-allowed?)
  (when (and require-new-terms-allowed?
             (not (current-query-allows-new-terms?)))
    (return-from removal-relation-exists-instance-required nil))
  (let ((predicate (atomic-sentence-predicate asent)))
    (and (not (hl-predicate-p predicate))
         (or (not require-new-terms-allowed?)
             (skolemization-allowed #$RelationExistsInstanceFn))
         (removal-some-relation-exists-instance-for-predicate predicate mode nil)
         t)))

(deflexical *relation-exists-instance-rule*
  (list-to-elf '(#$implies
                 (#$relationExistsInstance ?PRED ?COLL ?THING)
                 (?PRED (#$RelationExistsInstanceFn ?PRED ?COLL ?THING) ?THING))))

(defglobal *relation-exists-instance-defining-mt* #$BaseKB)

;; (defun make-relation-exists-instance-support () ...) -- active declareFunction, no body
;; (defun make-relation-exists-instance-term (predicate coll term) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-prune (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-check-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-check-expand-internal (predicate coll term asent mode) ...) -- active declareFunction, no body

(deflexical *default-relation-exists-instance-check-cost*
  *expensive-hl-module-check-cost*)

(defun removal-relation-exists-instance-unify-required (asent mode)
  (removal-relation-exists-instance-required asent mode t))

(defun removal-relation-exists-instance-unify-arg1-required (asent &optional sense)
  (declare (ignore sense))
  (removal-relation-exists-instance-unify-required asent :genl-preds))

(defun removal-relation-exists-instance-unify-arg2-required (asent &optional sense)
  (declare (ignore sense))
  (removal-relation-exists-instance-unify-required asent :genl-inverse))

(deflexical *minimum-relation-exists-instance-unify-cost*
  *expensive-hl-module-check-cost*)

;; (defun removal-relation-exists-instance-unify-cost (asent mode argnum) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unify-arg1-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unify-arg2-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unify-expand (asent mode argnum sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unify-arg1-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unify-arg2-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun relation-exists-instance-sksi-cost () ...) -- active declareFunction, no body
;; (defun relation-exists-instance-predicate-cost-estimate (predicate mode &optional mt) ...) -- active declareFunction, no body
;; (defun relation-exists-instance-object-cost-estimate (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unify-via-predicate-expand (asent mode argnum sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unify-via-object-expand (asent mode argnum) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unify-expand-guts (asent support-term support) ...) -- active declareFunction, no body

(defun removal-relation-exists-instance-unbound-required (asent mode)
  (removal-relation-exists-instance-required asent mode t))

(defun removal-relation-exists-instance-unbound-arg1-required (asent &optional sense)
  (declare (ignore sense))
  (removal-relation-exists-instance-unbound-required asent :genl-inverse))

(defun removal-relation-exists-instance-unbound-arg2-required (asent &optional sense)
  (declare (ignore sense))
  (removal-relation-exists-instance-unbound-required asent :genl-preds))

;; (defun removal-relation-exists-instance-unbound-cost (asent mode) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unbound-arg1-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unbound-arg2-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unbound-expand (asent mode) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unbound-arg1-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-unbound-arg2-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-via-exemplar-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-via-exemplar-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-via-exemplar-query (asent &optional sense) ...) -- active declareFunction, no body
;; (defun make-relation-instance-exists-via-exemplar-support (asent) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-via-exemplar-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-via-exemplar-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-instance-via-exemplar-query (asent &optional sense) ...) -- active declareFunction, no body
;; (defun make-relation-exists-instance-via-exemplar-support (asent) ...) -- active declareFunction, no body

(defun removal-relation-instance-exists-expansion-applicability (contextualized-dnf-clause)
  (let ((subclause-specs nil))
    (when (current-query-allows-new-terms?)
      (let ((index0 0))
        (dolist (contextualized-asent0 (pos-lits contextualized-dnf-clause))
          (destructuring-bind (mt0 asent0) contextualized-asent0
            (let ((*mt* (update-inference-mt-relevance-mt mt0))
                  (*relevant-mt-function* (update-inference-mt-relevance-function mt0))
                  (*relevant-mts* (update-inference-mt-relevance-mt-list mt0)))
              (when (eq #$isa (atomic-sentence-predicate asent0))
                (let ((isa-arg1 (atomic-sentence-arg1 asent0))
                      (isa-arg2 (atomic-sentence-arg2 asent0)))
                  (when (fully-bound-p isa-arg2)
                    (when (not-fully-bound-p isa-arg1)
                      (let ((index1 0))
                        (dolist (contextualized-asent1 (pos-lits contextualized-dnf-clause))
                          (unless (eql index0 index1)
                            (destructuring-bind (mt1 asent1) contextualized-asent1
                              (when (relevant-mt? mt1)
                                (let ((*mt* (update-inference-mt-relevance-mt mt1))
                                      (*relevant-mt-function* (update-inference-mt-relevance-function mt1))
                                      (*relevant-mts* (update-inference-mt-relevance-mt-list mt1)))
                                  (let ((pred1 (atomic-sentence-predicate asent1)))
                                    (when (and (non-hl-predicate-p pred1)
                                               (binary-predicate? pred1))
                                      (let ((pred1-arg1 (atomic-sentence-arg1 asent1))
                                            (pred1-arg2 (atomic-sentence-arg2 asent1)))
                                        (when (and (not-fully-bound-p pred1-arg2)
                                                   (equal pred1-arg2 isa-arg1)
                                                   ;; Likely checks whether a relation-instance-exists assertion
                                                   ;; is available for the predicate and collection
                                                   (missing-larkc 32730))
                                          (if (< index0 index1)
                                              (push (list nil (list index0 index1)) subclause-specs)
                                              (push (list nil (list index1 index0)) subclause-specs))))))))))
                          (incf index1)))))))))
          (incf index0))))
    (fast-delete-duplicates subclause-specs #'equal)))

;; (defun removal-relation-instance-exists-expansion-cost (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-exists-expansion-expand (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun destructure-relation-instance-exists-expansion (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun relation-instance-exists-unifiable? (predicate term coll mt) ...) -- active declareFunction, no body
;; (defun relation-instance-exists-unify (predicate term coll mt) ...) -- active declareFunction, no body

;;; Setup

(toplevel
  (declare-defglobal '*relation-instance-exists-defining-mt*))

(toplevel
  (note-mt-var '*relation-instance-exists-defining-mt* #$relationInstanceExists))

(toplevel
  (inference-removal-module :removal-relation-instance-exists-prune
    (list :sense :pos
          :required-pattern '(:and (:fort . :anything)
                                   (:tree-find #$RelationInstanceExistsFn))
          :exclusive 'removal-relation-instance-exists-prune
          :cost-expression 0
          :completeness :complete
          :documentation "@todo write this"
          :example "@todo write this")))

(toplevel
  (inference-removal-module :removal-relation-instance-exists-check
    (list :sense :pos
          :arity 2
          :required-pattern '(:or (:fort :fully-bound (#$RelationInstanceExistsFn :fort :fully-bound :fully-bound))
                                  (:fort (#$RelationInstanceExistsFn :fort :fully-bound :fully-bound) :fully-bound))
          :required 'removal-relation-instance-exists-check-required
          :cost-expression '*default-relation-instance-exists-check-cost*
          :expand 'removal-relation-instance-exists-check-expand
          :documentation "(<predicate> <object> (#$RelationInstanceExistsFn <predicate> <object> <coll>))
where <object> is a TERM
from (#$relationInstanceExists <spec-predicate> <object> <coll>)
and (#$genlPreds <spec-predicate> <predicate)

or

(<predicate> (#$RelationInstanceExistsFn <predicate> <object> <coll>) <object>)
where <object> is a TERM
from (#$relationInstanceExists <inv-predicate> <object> <coll>)
and (#$genlInverse <inv-predicate> <predicate)
"
          :example "(#$owns #$Sean
      (#$RelationInstanceExistsFn #$owns #$Sean #$Holster))
from (#$relationInstanceExists #$owns #$Sean #$Holster)")))

(toplevel
  (inference-removal-module :removal-relation-instance-exists-unify-arg1
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :not-fully-bound :fully-bound)
          :required 'removal-relation-instance-exists-unify-arg1-required
          :cost 'removal-relation-instance-exists-unify-arg1-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-instance-exists-unify-arg1-expand
          :documentation "(<predicate> <not fully-bound> <object>)
from (#$relationInstanceExists <inv-predicate> <object> <coll>)
and (#$genlInverse <inv-predicate> <predicate)"
          :example "")))

(toplevel
  (inference-removal-module :removal-relation-instance-exists-unify-arg2
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :fully-bound :not-fully-bound)
          :required 'removal-relation-instance-exists-unify-arg2-required
          :cost 'removal-relation-instance-exists-unify-arg2-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-instance-exists-unify-arg2-expand
          :documentation "(<predicate> <object> <not fully-bound>)
from (#$relationInstanceExists <spec-predicate> <object> <coll>)
and (#$genlPreds <spec-predicate> <predicate)"
          :example "(#$owns #$Sean ?ITEM)
from (#$relationInstanceExists #$owns #$Sean #$Holster)")))

(toplevel
  (inference-removal-module :removal-relation-instance-exists-unbound-arg1
    (list :sense :pos
          :arity 2
          :required-pattern '(:or (:fort :not-fully-bound :variable)
                                  (:fort :not-fully-bound (:nat (#$RelationInstanceExistsFn . :anything))))
          :required 'removal-relation-instance-exists-unbound-arg1-required
          :cost 'removal-relation-instance-exists-unbound-arg1-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-instance-exists-unbound-arg1-expand
          :documentation "(<predicate> <not fully-bound> <anything>)
from (#$relationInstanceExists <spec-predicate> <object> <coll>)
and (#$genlPreds <spec-predicate> <predicate)"
          :example "(#$owns ?WHO ?ITEM)
from (#$relationInstanceExists #$owns #$Sean #$Holster)")))

(toplevel
  (inference-removal-module :removal-relation-instance-exists-unbound-arg2
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :anything :not-fully-bound)
          :required 'removal-relation-instance-exists-unbound-arg2-required
          :cost 'removal-relation-instance-exists-unbound-arg2-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-instance-exists-unbound-arg2-expand
          :documentation "(<predicate> <anything> <not fully-bound>)
from (#$relationInstanceExists <inv-predicate> <object> <coll>
and (#$genlInverse <inv-predicate> <predicate)"
          :example "")))

(toplevel
  (declare-defglobal '*relation-exists-instance-defining-mt*))

(toplevel
  (note-mt-var '*relation-exists-instance-defining-mt* #$relationExistsInstance))

(toplevel
  (inference-removal-module :removal-relation-exists-instance-prune
    (list :sense :pos
          :required-pattern '(:and (:fort . :anything)
                                   (:tree-find #$RelationExistsInstanceFn))
          :exclusive 'removal-relation-exists-instance-prune
          :cost-expression 0
          :completeness :complete
          :documentation "@todo write this"
          :example "@todo write this")))

(toplevel
  (inference-removal-module :removal-relation-exists-instance-check
    (list :sense :pos
          :arity 2
          :required-pattern '(:or (:fort (#$RelationExistsInstanceFn :fort :fully-bound :fully-bound) :fully-bound)
                                  (:fort :fully-bound (#$RelationExistsInstanceFn :fort :fully-bound :fully-bound)))
          :required 'removal-relation-exists-instance-check-required
          :cost-expression '*default-relation-exists-instance-check-cost*
          :expand 'removal-relation-exists-instance-check-expand
          :documentation "(<predicate> (#$RelationExistsInstanceFn <predicate> <coll> <object>) <object>)
from (#$relationExistsInstance <spec-predicate> <coll> <object>)
and (#$genlPreds <spec-predicate> <predicate)

or

(<predicate> <object> (#$RelationExistsInstanceFn <predicate> <coll> <object>))
from (#$relationExistsInstance <inv-predicate> <coll> <object>)
and (#$genlInverse <inv-predicate> <predicate)"
          :example "(#$inRegion (#$RelationExistsInstanceFn #$inRegion #$Subway #$CityOfMadridSpain)
                #$CityOfMadridSpain)
from (#$relationExistsInstance #$inRegion #$Subway #$CityOfMadridSpain)")))

(toplevel
  (inference-removal-module :removal-relation-exists-instance-unify-arg1
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :not-fully-bound :fully-bound)
          :required 'removal-relation-exists-instance-unify-arg1-required
          :cost 'removal-relation-exists-instance-unify-arg1-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-exists-instance-unify-arg1-expand
          :documentation "(<predicate> <not fully-bound> <object>)
from (#$relationExistsInstance <spec-predicate> <coll> <object>)
and (#$genlPreds <spec-predicate> <predicate>"
          :example "(#$inRegion ?WHAT #$CityOfMadridSpain)
from (#$relationExistsInstance #$inRegion #$Subway #$CityOfMadridSpain)")))

(toplevel
  (inference-removal-module :removal-relation-exists-instance-unify-arg2
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :fully-bound :not-fully-bound)
          :required 'removal-relation-exists-instance-unify-arg2-required
          :cost 'removal-relation-exists-instance-unify-arg2-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-exists-instance-unify-arg2-expand
          :documentation "(<predicate> <object> <not fully-bound>)
from (#$relationExistsInstance <inv-predicate> <coll> <object>)
and (#$genlInverse <inv-predicate> <predicate>"
          :example "")))

(toplevel
  (inference-removal-module :removal-relation-exists-instance-unbound-arg1
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :not-fully-bound :anything)
          :required 'removal-relation-exists-instance-unbound-arg1-required
          :cost 'removal-relation-exists-instance-unbound-arg1-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-exists-instance-unbound-arg1-expand
          :documentation "(<predicate> <not fully-bound> <anything>)
from (#$relationExistsInstance <inv-predicate> <object> <coll>)
and (#$genlInverse <inv-predicate> <predicate)"
          :example "")))

(toplevel
  (inference-removal-module :removal-relation-exists-instance-unbound-arg2
    (list :sense :pos
          :arity 2
          :required-pattern '(:or (:fort :variable :not-fully-bound)
                                  (:fort (:nat (#$RelationExistsInstanceFn . :anything)) :not-fully-bound))
          :required 'removal-relation-exists-instance-unbound-arg2-required
          :cost 'removal-relation-exists-instance-unbound-arg2-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-exists-instance-unbound-arg2-expand
          :documentation "(<predicate> <anything> <not fully-bound>)
from (#$relationExistsInstance <spec-predicate> <object> <coll>)
and (#$genlPreds <spec-predicate> <predicate)"
          :example "(#$inRegion ?OBJ1 ?OBJ2)
from (#$relationExistsInstance #$inRegion #$Subway #$CityOfMadridSpain)")))

(toplevel
  (inference-removal-module :removal-relation-instance-exists-via-exemplar
    (list :sense :pos
          :predicate #$relationInstanceExists
          :required-pattern `(,#$relationInstanceExists :predicate-fort :fort (:and :fully-bound :collection-fort))
          :cost 'removal-relation-instance-exists-via-exemplar-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-instance-exists-via-exemplar-expand
          :documentation "(#$relationInstanceExists <predicate> <term> <collection>)
from (<spec-predicate> <term> <collection-instance>)
(#$genlPreds <spec-predicate> <predicate>)
and (#$isa <collection-instance> <collection>)
or
from (<inv-predicate> <collection-instance> <term>)
(#$genlInverse <inv-predicate> <predicate>)
and (#$isa <collection-instance> <collection>)
"
          :example "")))

(toplevel
  (inference-removal-module :removal-relation-exists-instance-via-exemplar
    (list :sense :pos
          :predicate #$relationExistsInstance
          :required-pattern `(,#$relationExistsInstance :predicate-fort (:and :fully-bound :collection-fort) :fort)
          :cost 'removal-relation-exists-instance-via-exemplar-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-exists-instance-via-exemplar-expand
          :documentation "(#$relationExistsInstance <predicate> <collection> <term>)
from (<spec-predicate> <collection-instance> <term>)
(#$genlPreds <spec-predicate> <predicate>)
and (#$isa <collection-instance> <collection>)
or
from (<inv-predicate> <term> <collection-instance>)
(#$genlInverse <inv-predicate> <predicate>)
and (#$isa <collection-instance> <collection>)
"
          :example "")))

(toplevel
  (inference-conjunctive-removal-module :removal-relation-instance-exists-expansion
    (list :every-predicates (list #$isa)
          :applicability 'removal-relation-instance-exists-expansion-applicability
          :cost 'removal-relation-instance-exists-expansion-cost
          :expand 'removal-relation-instance-exists-expansion-expand
          :completeness :grossly-incomplete
          :documentation "(#$and (<fort> <anything> <not-fully-bound-N>)
           (#$isa <not-fully-bound-N> <fully-bound>))"
          :example "(#$and (#$organismKilled ?EVENT ?PERSON)
           (#$isa ?PERSON #$UnitedStatesPerson))")))
