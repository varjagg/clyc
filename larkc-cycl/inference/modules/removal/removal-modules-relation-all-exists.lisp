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

;; (defun sbhl-isa-source-object-p (object) ...) -- active declareFunction, no body

(defun relation-all-exists-pos-preference (asent bindable-vars strategic-context)
  (declare (ignore bindable-vars strategic-context))
  (cond
    ((not (current-query-allows-new-terms?)) nil)
    ((not (removal-relation-all-exists-required asent t)) nil)
    ((formula-matches-pattern asent '(:fully-bound :fully-bound :fully-bound))
     :preferred)
    ((formula-matches-pattern asent '(:fully-bound :not-fully-bound (#$RelationAllExistsFn . :fully-bound)))
     :dispreferred)
    ((formula-matches-pattern asent '(:fully-bound :not-fully-bound :fully-bound))
     :preferred)
    ((formula-matches-pattern asent '(:fully-bound :fully-bound :not-fully-bound))
     :preferred)
    ((formula-matches-pattern asent '(:fully-bound :not-fully-bound :not-fully-bound))
     :dispreferred)
    (t nil)))

(defun removal-some-relation-all-exists-for-predicate (predicate &optional mt)
  (when (fort-p predicate)
    (some-pred-value-in-relevant-mts predicate #$relationAllExists mt 1)))

;; (defun removal-some-relation-all-exists-for-collection (collection &optional mt) ...) -- active declareFunction, no body
;; (defun relation-all-exists-predicate-cost-estimate (predicate) ...) -- active declareFunction, no body
;; (defun relation-all-exists-collection-cost-estimate (predicate) ...) -- active declareFunction, no body

(deflexical *estimated-per-collection-relation-all-exists-count* 2)

(defun removal-relation-all-exists-required (asent require-new-terms-allowed?)
  (when (and require-new-terms-allowed?
             (not (current-query-allows-new-terms?)))
    (return-from removal-relation-all-exists-required nil))
  (let ((predicate (atomic-sentence-predicate asent)))
    (and (or (eq #$isa predicate)
             (not (hl-predicate-p predicate)))
         (or (not require-new-terms-allowed?)
             (skolemization-allowed #$RelationAllExistsFn))
         (removal-some-relation-all-exists-for-predicate predicate nil))))

(deflexical *relation-all-exists-rule*
  (list-to-elf '(#$implies (#$and (#$relationAllExists ?PRED ?INDEP-COL ?DEP-COL)
                                   (#$isa ?TERM ?INDEP-COL))
                            (?PRED ?TERM (#$RelationAllExistsFn ?TERM ?PRED ?INDEP-COL ?DEP-COL)))))

;; (defun make-relation-all-exists-support () ...) -- active declareFunction, no body
;; (defun make-relation-all-exists-term (term predicate indep-col dep-col) ...) -- active declareFunction, no body

(defglobal *relation-all-exists-defining-mt*
  (if (and (boundp '*relation-all-exists-defining-mt*)
           (typep *relation-all-exists-defining-mt* 't))
      *relation-all-exists-defining-mt*
      #$BaseKB))

;; (defun removal-relation-all-exists-prune (asent &optional sense) ...) -- active declareFunction, no body

(deflexical *default-relation-all-exists-check-cost* *expensive-hl-module-check-cost*)

;; (defun removal-relation-all-exists-check-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-all-exists-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-all-exists-check-expand-internal (asent sense) ...) -- active declareFunction, no body

(defun removal-relation-all-exists-unify-required (asent &optional sense)
  (declare (ignore sense))
  (when (removal-relation-all-exists-required asent t)
    (let ((arg1 (atomic-sentence-arg1 asent)))
      (declare (ignore arg1))
      ;; Likely checks if arg1 is an sbhl-isa source object, returning T if so.
      (missing-larkc 32690))))

(deflexical *minimum-relation-all-exists-unify-cost* *expensive-hl-module-check-cost*)

;; (defun removal-relation-all-exists-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-all-exists-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-all-exists-unify-via-predicate-expand (predicate asent) ...) -- active declareFunction, no body
;; (defun removal-relation-all-exists-unify-via-collection-expand (collection asent) ...) -- active declareFunction, no body
;; (defun removal-relation-all-exists-unify-expand-guts (relation-all-exists-asent asent) ...) -- active declareFunction, no body

(defun relation-exists-all-pos-preference (asent bindable-vars strategic-context)
  (declare (ignore bindable-vars strategic-context))
  (cond
    ((not (current-query-allows-new-terms?)) nil)
    ((not (removal-relation-exists-all-required asent t)) nil)
    ((formula-matches-pattern asent '(:fully-bound :fully-bound :fully-bound))
     :preferred)
    ((formula-matches-pattern asent '(:fully-bound (#$RelationExistsAllFn . :fully-bound) :not-fully-bound))
     :dispreferred)
    ((formula-matches-pattern asent '(:fully-bound :fully-bound :not-fully-bound))
     :preferred)
    ((formula-matches-pattern asent '(:fully-bound :not-fully-bound :fully-bound))
     :preferred)
    ((formula-matches-pattern asent '(:fully-bound :not-fully-bound :not-fully-bound))
     :dispreferred)
    (t nil)))

(defun removal-some-relation-exists-all-for-predicate (predicate &optional mt)
  (when (fort-p predicate)
    (some-pred-value-in-relevant-mts predicate #$relationExistsAll mt 1)))

;; (defun removal-some-relation-exists-all-for-collection (collection &optional mt) ...) -- active declareFunction, no body
;; (defun relation-exists-all-predicate-cost-estimate (predicate) ...) -- active declareFunction, no body
;; (defun relation-exists-all-collection-cost-estimate (predicate) ...) -- active declareFunction, no body

(deflexical *estimated-per-collection-relation-exists-all-count* 2)

(defun removal-relation-exists-all-required (asent require-new-terms-allowed?)
  (when (and require-new-terms-allowed?
             (not (current-query-allows-new-terms?)))
    (return-from removal-relation-exists-all-required nil))
  (let ((predicate (atomic-sentence-predicate asent)))
    (and (or (eq #$isa predicate)
             (not (hl-predicate-p predicate)))
         (or (not require-new-terms-allowed?)
             (skolemization-allowed #$RelationExistsAllFn))
         (removal-some-relation-exists-all-for-predicate predicate nil))))

(deflexical *relation-exists-all-rule*
  (list-to-elf '(#$implies (#$and (#$relationExistsAll ?PRED ?DEP-COL ?INDEP-COL)
                                   (#$isa ?TERM ?INDEP-COL))
                            (?PRED (#$RelationExistsAllFn ?TERM ?PRED ?DEP-COL ?INDEP-COL) ?TERM))))

;; (defun make-relation-exists-all-support () ...) -- active declareFunction, no body
;; (defun make-relation-exists-all-term (term predicate dep-col indep-col) ...) -- active declareFunction, no body

(defglobal *relation-exists-all-defining-mt*
  (if (and (boundp '*relation-exists-all-defining-mt*)
           (typep *relation-exists-all-defining-mt* 't))
      *relation-exists-all-defining-mt*
      #$BaseKB))

;; (defun removal-relation-exists-all-prune (asent &optional sense) ...) -- active declareFunction, no body

(deflexical *default-relation-exists-all-check-cost* *expensive-hl-module-check-cost*)

;; (defun removal-relation-exists-all-check-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-all-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-all-check-expand-internal (asent sense) ...) -- active declareFunction, no body

(defun removal-relation-exists-all-unify-required (asent &optional sense)
  (declare (ignore sense))
  (when (removal-relation-exists-all-required asent t)
    (let ((arg2 (atomic-sentence-arg2 asent)))
      (declare (ignore arg2))
      ;; Likely checks if arg2 is an sbhl-isa source object, returning T if so.
      (missing-larkc 32691))))

(deflexical *minimum-relation-exists-all-unify-cost* *expensive-hl-module-check-cost*)

;; (defun removal-relation-exists-all-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-all-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-all-unify-via-predicate-expand (predicate asent) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-all-unify-via-collection-expand (collection asent) ...) -- active declareFunction, no body
;; (defun removal-relation-exists-all-unify-expand-guts (relation-exists-all-asent asent) ...) -- active declareFunction, no body

;;; Setup phase

(toplevel
  (declare-defglobal '*relation-all-exists-defining-mt*))

(toplevel
  (note-mt-var '*relation-all-exists-defining-mt* #$relationAllExists))

(toplevel
  (inference-preference-module :relation-all-exists-pos
    (list :sense :pos
          :required-pattern '(:fully-bound :anything :anything)
          :preference 'relation-all-exists-pos-preference)))

(toplevel
  (inference-removal-module :removal-relation-all-exists-prune
    (list :sense :pos
          :required-pattern '(:and (:fort . :anything)
                                   (:tree-find #$RelationAllExistsFn))
          :exclusive 'removal-relation-all-exists-prune
          :cost-expression 0
          :completeness :complete
          :documentation ""
          :example "")))

(toplevel
  (inference-removal-module :removal-relation-all-exists-check
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :fully-bound
                              (#$RelationAllExistsFn :fully-bound :fort :fully-bound :fully-bound))
          :required 'removal-relation-all-exists-check-required
          :cost-expression '*default-relation-all-exists-check-cost*
          :expand 'removal-relation-all-exists-check-expand
          :documentation "(<predicate> <object>
  (#$RelationAllExistsFn <object> <predicate> <indep-col> <dep-col>))
where <object> is a TERM
from (#$relationAllExists <predicate> <indep-col> <dep-col>)
and  (#$isa <object> <indep-col>)"
          :example "(#$grandfathers #$AbrahamLincoln
  (#$RelationAllExistsFn #$AbrahamLincoln #$grandfathers #$Animal #$MaleAnimal))
from (#$relationAllExists #$grandfathers #$Animal #$MaleAnimal)
and (#$isa #$AbrahamLincoln #$Animal)")))

(toplevel
  (inference-removal-module :removal-relation-all-exists-unify
    (list :sense :pos
          :arity 2
          :required-pattern '(:or (:fort :fully-bound :variable)
                                  (:fort :fully-bound (:nat (#$RelationAllExistsFn . :not-fully-bound))))
          :required 'removal-relation-all-exists-unify-required
          :cost 'removal-relation-all-exists-unify-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-all-exists-unify-expand
          :documentation "(<predicate> <object> <not fully-bound>)
where <object> is a TERM
from (#$relationAllExists <predicate> <indep-col> <dep-col>)
and (#$isa <object> <indep-col>)"
          :example "(#$grandfathers #$AbrahamLincoln ?RELATIVE)
from (#$relationAllExists #$grandfathers #$Animal #$MaleAnimal)
and (#$isa #$AbrahamLincoln #$Animal)")))

(toplevel
  (declare-defglobal '*relation-exists-all-defining-mt*))

(toplevel
  (note-mt-var '*relation-exists-all-defining-mt* #$relationExistsAll))

(toplevel
  (inference-preference-module :relation-exists-all-pos
    (list :sense :pos
          :required-pattern '(:fully-bound :anything :anything)
          :preference 'relation-exists-all-pos-preference)))

(toplevel
  (inference-removal-module :removal-relation-exists-all-prune
    (list :sense :pos
          :required-pattern '(:and (:fort . :anything)
                                   (:tree-find #$RelationExistsAllFn))
          :exclusive 'removal-relation-exists-all-prune
          :cost-expression 0
          :completeness :complete
          :documentation ""
          :example "")))

(toplevel
  (inference-removal-module :removal-relation-exists-all-check
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort
                              (#$RelationExistsAllFn :fully-bound :fort :fully-bound :fully-bound)
                              :fully-bound)
          :required 'removal-relation-exists-all-check-required
          :cost-expression '*default-relation-exists-all-check-cost*
          :expand 'removal-relation-exists-all-check-expand
          :documentation "(<predicate> (#$RelationExistsAllFn <object> <predicate> <dep-col> <indep-col>) <object>)
where <object> is a TERM
from (#$relationExistsAll <predicate> <dep-col> <indep-col>)
and (#$isa <object> <indep-col>)"
          :example "(#$citizens (#$RelationExistsAllFn #$AbrahamLincoln #$citizens #$Country #$Person)
  #$AbrahamLincoln)
from (#$relationExistsAll #$citizens #$Country #$Person)
and (#$isa #$AbrahamLincoln #$Person)")))

(toplevel
  (inference-removal-module :removal-relation-exists-all-unify
    (list :sense :pos
          :arity 2
          :required-pattern '(:or (:fort :variable :fully-bound)
                                  (:fort (:nat (#$RelationExistsAllFn . :not-fully-bound)) :fully-bound))
          :required 'removal-relation-exists-all-unify-required
          :cost 'removal-relation-exists-all-unify-cost
          :completeness :grossly-incomplete
          :expand 'removal-relation-exists-all-unify-expand
          :documentation "(<predicate> <not fully-bound> <object>)
where <object> is a TERM
from (#$relationExistsAll <predicate> <dep-col> <indep-col>)
and (#$isa <object> <indep-col>)"
          :example "(#$citizens ?WHERE #$AbrahamLincoln)
from (#$relationExistsAll #$citizens #$Country #$Person)
and (#$isa #$AbrahamLincoln #$Person)")))
