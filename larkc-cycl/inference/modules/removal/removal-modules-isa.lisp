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

(deflexical *isa-fort-collection-cost* (- *cheap-hl-module-check-cost* 0.1)
  "[Cyc] Slightly favor SBHL isa checking for forts.")

(deflexical *isa-non-fort-collection-cost* *cheap-hl-module-check-cost*
  "[Cyc] Do not favor SBHL isa checking for non-forts.")

(defparameter *default-not-isa-collection-check-cost* 1)

(deflexical *isa-fort-defn-cost* *cheap-hl-module-check-cost*
  "[Cyc] Do not favor defn checking for forts.")

(deflexical *isa-non-fort-defn-cost* (- *cheap-hl-module-check-cost* 0.1)
  "[Cyc] Slightly favor defn checking for non-forts.")

(defparameter *all-instances-lazy-iteration-threshold* 2300)

(deflexical *subcollection-functors* (list #$SubcollectionOfWithRelationToFn
                                           #$SubcollectionOfWithRelationFromFn
                                           #$SubcollectionOfWithRelationToTypeFn
                                           #$SubcollectionOfWithRelationFromTypeFn
                                           #$SubcollectionOccursAtFn
                                           #$CollectionSubsetFn
                                           #$CollectionIntersection2Fn
                                           #$CollectionDifferenceFn))

(deflexical *quoted-isa-fort-collection-cost* (- *cheap-hl-module-check-cost* 0.1)
  "[Cyc] Slightly favor SBHL quoted isa checking for forts.")

(deflexical *quoted-isa-non-fort-collection-cost* *cheap-hl-module-check-cost*
  "[Cyc] Do not favor SBHL quoted isa checking for non-forts.")

(defparameter *default-not-quoted-isa-collection-check-cost* 1)

(deflexical *quoted-isa-fort-defn-cost* *cheap-hl-module-check-cost*
  "[Cyc] Do not favor quoted defn checking for forts.")

(deflexical *quoted-isa-non-fort-defn-cost* (- *cheap-hl-module-check-cost* 0.1)
  "[Cyc] Slightly favor quoted defn checking for non-forts.")

;; Functions in declareFunction order:

(defun all-instances-pos-preference (asent bindable-vars strategic-context)
  (declare (ignore bindable-vars strategic-context))
  (let ((col (atomic-sentence-arg2 asent)))
    (cond ((and (cycl-nat-p col)
                ;; Likely checks if collection is a reifiable NAT -- evidence: parallel to genls module pattern.
                (missing-larkc 32825))
           :preferred)
          ((collection-p col)
           (completeness-to-preference-level
            (inference-collection-iteration-completeness col)))
          (t :grossly-dispreferred))))

;; (defun inference-all-isas-of-type (arg1 arg2 &optional arg3) ...) -- active declareFunction, no body

(defun removal-isa-collection-check-pos-cost (asent &optional sense)
  (declare (ignore sense))
  (if (fort-p (atomic-sentence-arg1 asent))
      *isa-fort-collection-cost*
      *isa-non-fort-collection-cost*))

;; (defun removal-isa-collection-check-neg-cost (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-isa-collection-check-pos-expand (asent &optional sense)
  (declare (ignore sense))
  (removal-isa-collection-check-expand asent))

;; (defun removal-isa-collection-check-neg-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-isa-collection-check-expand (asent)
  (let ((object (atomic-sentence-arg1 asent))
        (collection (atomic-sentence-arg2 asent)))
    (unless (>= (term-functional-complexity object) 30)
      (when (isa? object collection)
        (removal-add-node (make-hl-support :isa asent)))))
  nil)

;; (defun removal-not-isa-collection-check-cost (asent) ...) -- active declareFunction, no body
;; (defun removal-not-isa-collection-check-expand (asent) ...) -- active declareFunction, no body
;; (defun removal-isa-naut-collection-check-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-naut-collection-check-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-naut-collection-lookup-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-naut-collection-lookup-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-defn-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-defn-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-defn-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-defn-neg-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-defn-pos-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-defn-check-expand (asent) ...) -- active declareFunction, no body
;; (defun removal-isa-defn-reject-expand (asent) ...) -- active declareFunction, no body

(defun removal-all-isa-expand (asent &optional sense)
  (declare (ignore sense))
  (let* ((predicate (atomic-sentence-predicate asent))
         (object (atomic-sentence-arg1 asent))
         (arg2 (atomic-sentence-arg2 asent))
         (collections (all-isa object)))
    (dolist (collection collections)
      (multiple-value-bind (v-bindings unify-justification)
          (term-unify arg2 collection t t)
        (when v-bindings
          (let* ((unified-arg2 (subst-bindings v-bindings arg2))
                 (formula (make-binary-formula predicate object unified-arg2)))
            (removal-add-node (make-hl-support :isa formula)
                              v-bindings
                              unify-justification))))))
  nil)

(defun removal-all-instances-cost (asent &optional sense)
  (declare (ignore sense))
  (let ((collection (atomic-sentence-arg2 asent)))
    (inference-all-instances-cost collection)))

(defun removal-all-instances-completeness (asent)
  (inference-collection-iteration-completeness (atomic-sentence-arg2 asent)))

(defun inference-collection-iteration-completeness (collection)
  "[Cyc] @return completeness-p ; the inferential completness of iterating over all instances of COLLECTION."
  (cond ((not (fort-p collection))
         :grossly-incomplete)
        ((or (any-sufficient-defn-anywhere? collection)
             (any-sufficient-quoted-defn-anywhere? collection))
         :grossly-incomplete)
        ((completely-enumerable-collection? collection)
         :complete)
        (t :grossly-incomplete)))

(defun removal-all-instances-iterator (collection)
  (if (> (instance-cardinality collection) *all-instances-lazy-iteration-threshold*)
      ;; Likely constructs a lazy iterator over instances -- evidence: threshold guards against eager collection.
      (missing-larkc 288)
      (new-list-iterator (all-instances collection))))

(defun inference-all-instances-cost (collection)
  (let ((instance-iteration-cost (instance-iteration-cost collection)))
    (if (zerop instance-iteration-cost)
        (relevant-num-gaf-arg-index collection 2 #$isa)
        instance-iteration-cost)))

;; (defun removal-elementof-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-not-elementof-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-elementof-collection-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-elementof-collection-defn-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-elementof-set-check-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-not-elementof-collection-check-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-not-elementof-collection-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-not-elementof-collection-defn-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-not-elementof-set-check-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-not-elementof-set-check-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-not-elementof-set-check-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-elementof-thesetof-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun inference-elementof-thesetof-check (element setof-expr &optional mt) ...) -- active declareFunction, no body
;; (defun removal-isa-thecollectionof-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-not-elementof-thesetof-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-not-isa-thecollectionof-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-all-elementof-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-all-elementof-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-elementof-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-elementof-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-elementof-collection-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-elementof-collection-unify-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-elementof-collection-unify-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-elementof-set-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-elementof-set-unify-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-elementof-thesetof-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-elementof-thesetof-unify-cost-smart (asent v-bindings) ...) -- active declareFunction, no body
;; (defun removal-elementof-thesetof-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-thecollectionof-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-thecollectionof-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-collection-subset-fn-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-subcollection-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-subcollection-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-isa-subcollection-construct-query (functor-formula object) ...) -- active declareFunction, no body
;; (defun subcollection-functor-p (functor) ...) -- active declareFunction, no body
;; (defun removal-all-isa-of-type-completeness (asent1 mt1 asent2 mt2) ...) -- active declareFunction, no body

(defun removal-all-isa-of-type-applicability (contextualized-dnf-clause)
  (removal-sbhl-between-applicability contextualized-dnf-clause #$isa))

;; (defun removal-all-isa-of-type-cost (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun removal-all-isa-of-type-expand (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun removal-all-isa-of-type-categorize-asents (asent1 asent2) ...) -- active declareFunction, no body
;; (defun all-quoted-instances-pos-preference (asent bindable-vars strategic-context) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-collection-check-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-collection-check-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-collection-check-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-collection-check-neg-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-collection-check-expand (asent) ...) -- active declareFunction, no body
;; (defun removal-not-quoted-isa-collection-check-cost (asent) ...) -- active declareFunction, no body
;; (defun removal-not-quoted-isa-collection-check-expand (asent) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-defn-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-defn-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-defn-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-defn-neg-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-defn-pos-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-defn-check-expand (asent) ...) -- active declareFunction, no body
;; (defun removal-quoted-isa-defn-reject-expand (asent) ...) -- active declareFunction, no body
;; (defun removal-nat-quoted-isa-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-all-quoted-isa-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-fort-all-quoted-isa-expand (asent) ...) -- active declareFunction, no body
;; (defun removal-nat-all-quoted-isa-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-all-quoted-instances-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-all-quoted-instances-completeness (asent) ...) -- active declareFunction, no body
;; (defun inference-quoted-collection-iteration-completeness (collection) ...) -- active declareFunction, no body
;; (defun removal-all-quoted-instances-iterator (collection) ...) -- active declareFunction, no body
;; (defun inference-all-quoted-instances-cost (collection) ...) -- active declareFunction, no body

;; Setup phase (toplevel forms)

(toplevel
  (register-solely-specific-removal-module-predicate #$isa))

(toplevel
  (inference-removal-module-use-meta-removal #$isa :meta-removal-completely-enumerable-pos))
(toplevel
  (inference-removal-module-use-meta-removal #$isa :meta-removal-completely-decidable-pos))
(toplevel
  (inference-removal-module-use-generic #$isa :removal-completely-decidable-neg))
(toplevel
  (inference-removal-module-use-generic #$isa :removal-abduction-pos-check))
(toplevel
  (inference-removal-module-use-generic #$isa :removal-abduction-pos-unify))
(toplevel
  (inference-removal-module-use-generic #$isa :removal-relation-all-exists-check))
(toplevel
  (inference-removal-module-use-generic #$isa :removal-relation-all-exists-unify))
(toplevel
  (inference-removal-module-use-generic #$isa :removal-relation-exists-all-check))
(toplevel
  (inference-removal-module-use-generic #$isa :removal-backchain-required-prune))

(toplevel
  (inference-preference-module :isa-x-y-pos
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound :not-fully-bound)
          :preference-level :disallowed)))

(toplevel
  (inference-preference-module :all-instances-pos
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound :fully-bound)
          :preference 'all-instances-pos-preference)))

(toplevel
  (inference-preference-module :all-isa-pos
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound :not-fully-bound)
          :preference-level :dispreferred)))

(toplevel
  (inference-preference-module :all-elementof-pos
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fully-bound :not-fully-bound)
          :preference-level :grossly-dispreferred)))

(toplevel
  (inference-removal-module :removal-isa-collection-check-pos
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound :fort)
          :cost 'removal-isa-collection-check-pos-cost
          :expand 'removal-isa-collection-check-pos-expand
          :documentation "(#$isa <fully-bound> <fort>)"
          :example "(#$isa #$Dog #$Collection)
(#$isa (#$JuvenileFn #$Dog) #$Collection)")))

(toplevel
  (inference-removal-module :removal-isa-collection-check-neg
    (list :sense :neg
          :predicate #$isa
          :required-pattern (list #$isa :fort :fort)
          :cost 'removal-isa-collection-check-neg-cost
          :expand 'removal-isa-collection-check-neg-expand
          :documentation "(#$not (#$isa <fort> <fort>))"
          :example "(#$not (#$isa #$Dog #$Predicate))")))

(toplevel
  (inference-removal-module :removal-isa-naut-collection-check-pos
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fort :closed-naut)
          :cost 'removal-isa-naut-collection-check-pos-cost
          :expand 'removal-isa-naut-collection-check-pos-expand
          :documentation ""
          :example "")))

(toplevel
  (inference-removal-module :removal-isa-naut-collection-lookup-pos
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa (list :not :fort) :closed-naut)
          :completeness :grossly-incomplete
          :cost 'removal-isa-naut-collection-lookup-pos-cost
          :expand 'removal-isa-naut-collection-lookup-pos-expand
          :documentation ""
          :example "")))

(toplevel
  (inference-removal-module :removal-isa-defn-pos
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound :fort)
          :required 'removal-isa-defn-pos-required
          :cost 'removal-isa-defn-pos-cost
          :expand 'removal-isa-defn-pos-expand
          :documentation "(#$isa <fully-bound> <fort>)
via passing a #$defnIff or a #$defnSufficient"
          :example "(#$isa 42 #$Integer)")))

(toplevel
  (inference-removal-module :removal-isa-defn-neg
    (list :sense :neg
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound :fort)
          :cost 'removal-isa-defn-neg-cost
          :expand 'removal-isa-defn-neg-expand
          :documentation "(#$not (#$isa <fully-bound> <fort>))
via failing a #$defnIff or a #$defnNecessary"
          :example "(#$not (#$isa 42 #$SubLString))")))

(toplevel
  (inference-removal-module :removal-all-isa
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound :not-fully-bound)
          :cost-expression '*average-all-isa-count*
          :expand 'removal-all-isa-expand
          :documentation "(#$isa <fort> <not fully-bound>)"
          :example "(#$isa #$Dog ?COL)
(#$isa (#$JuvenileFn #$Cougar) ?COL)")))

(toplevel
  (note-funcall-helper-function 'removal-all-isa-expand))

(toplevel
  (inference-removal-module :removal-all-instances
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound :fort)
          :cost 'removal-all-instances-cost
          :completeness-pattern (list :call 'removal-all-instances-completeness :input)
          :input-extract-pattern (list :template
                                       (list #$isa :anything (list :bind 'collection))
                                       (list :value 'collection))
          :output-generate-pattern (list :call 'removal-all-instances-iterator :input)
          :output-construct-pattern (list #$isa :input (list :value 'collection))
          :support-module :isa
          :support-strength :default
          :documentation "(#$isa <not fully-bound> <fort>)"
          :example "(#$isa ?DOG #$Dog)")))

(toplevel
  (register-solely-specific-removal-module-predicate #$elementOf))

(toplevel
  (inference-removal-module :removal-elementof-check
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fully-bound (cons #$TheSet :fully-bound))
          :cost-expression '*hl-module-check-cost*
          :completeness :complete
          :expand 'removal-elementof-check-expand
          :documentation "(#$elementOf <fully-bound> (#$TheSet . <fully-bound>))"
          :example "(#$elementOf #$Dog (#$TheSet #$Dog #$Cat))")))

(toplevel
  (inference-removal-module :removal-not-elementof-check
    (list :sense :neg
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fully-bound (cons #$TheSet :fully-bound))
          :cost-expression '*hl-module-check-cost*
          :completeness :complete
          :expand 'removal-not-elementof-check-expand
          :documentation "(#$not (#$elementOf <fully-bound> (#$TheSet . <fully-bound>)))"
          :example "(#$not (#$elementOf #$Bird (#$TheSet #$Dog #$Cat)))")))

(toplevel
  (inference-removal-module :removal-elementof-collection-check
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fort :collection-fort)
          :cost-expression '*hl-module-check-cost*
          :expand 'removal-elementof-collection-check-expand
          :documentation "(#$elementOf <fort> <fort>)
 where <fort> is a collection "
          :example "(#$elementOf #$Dog #$Collection)")))

(toplevel
  (inference-removal-module :removal-elementof-collection-defn-check
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fully-bound :collection-fort)
          :cost-expression '*hl-module-check-cost*
          :expand 'removal-elementof-collection-defn-check-expand
          :documentation "(#$elementOf <fully-bound> <fort>)
 where <fort> is a collection"
          :example "(#$elementOf 42 #$Integer))
via passing a #$defnIff or a #$defnSufficient")))

(toplevel
  (inference-removal-module :removal-elementof-set-check
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fully-bound
                                  (list :and :fort (list :not (list :test 'collection-p))))
          :cost-expression '*hl-module-check-cost*
          :complete-pattern (list :test 'removal-completely-asserted-asent?)
          :input-extract-pattern (list :template
                                       (list :bind 'asent)
                                       (list :value 'asent))
          :output-generate-pattern (list :call 'removal-elementof-set-check-iterator :input)
          :output-decode-pattern (list :template
                                       (list :bind 'assertion)
                                       (list :value 'assertion))
          :output-construct-pattern (list :call 'gaf-formula :input)
          :support-pattern (list (list :value 'assertion))
          :documentation "(#$elementOf <fully-bound> <fort>)
 where <fort> is fort set but not a collection"
          :example "(#$elementOf #$GrayColor #$BlackAndWhiteColorScheme)
via the KB assertion (#$elementOf #$GrayColor #$BlackAndWhiteColorScheme)")))

(toplevel
  (inference-removal-module :removal-not-elementof-collection-check
    (list :sense :neg
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fort :collection-fort)
          :cost 'removal-not-elementof-collection-check-cost
          :expand 'removal-not-elementof-collection-check-expand
          :documentation "(#$not (#$elementOf <fort> <fort>))
where arg2 is a collection"
          :example "(#$not (#$elementOf #$Dog #$Predicate))")))

(toplevel
  (inference-removal-module :removal-not-elementof-collection-defn-check
    (list :sense :neg
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fully-bound :collection-fort)
          :cost-expression '*hl-module-check-cost*
          :expand 'removal-not-elementof-collection-defn-check-expand
          :documentation "(#$not (#$elementOf <fully-bound> <fort>))
where arg2 is a collection"
          :example "(#$not (#$elementOf 42 #$SubLString))
via failing a #$defnIff or a #$defnNecessary")))

(toplevel
  (inference-removal-module :removal-not-elementof-set-check
    (list :sense :neg
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fully-bound
                                  (list :and :fort (list :not (list :test 'collection-p))))
          :cost 'removal-not-elementof-set-check-cost
          :completeness-pattern (list :call 'removal-not-elementof-set-check-completeness :input)
          :input-extract-pattern (list :template
                                       (list :bind 'asent)
                                       (list :value 'asent))
          :output-generate-pattern (list :call 'removal-not-elementof-set-check-iterator :input)
          :output-decode-pattern (list :template
                                       (list :bind 'assertion)
                                       (list :value 'assertion))
          :output-construct-pattern (list :call 'gaf-formula :input)
          :support-pattern (list (list :value 'assertion))
          :documentation "(#$not (#$elementOf <fully-bound> <fort>))
where <fort> is a set but not a collection"
          :example "(#$not (#$elementOf #$RedColor #$BlackAndWhiteColorScheme))
via the KB assertion
 (#$not (#$elementOf #$RedColor #$BlackAndWhiteColorScheme))")))

(toplevel
  (inference-removal-module :removal-elementof-thesetof-check
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fully-bound (cons #$TheSetOf :fully-bound))
          :cost-expression '*expensive-hl-module-check-cost*
          :expand 'removal-elementof-thesetof-check-expand
          :documentation "(#$elementOf <fully-bound> (#$TheSetOf <variable> <fully-bound>))"
          :example "(#$elementOf #$France
  (#$TheSetOf ?COUNTRY
    (#$bordersOn ?COUNTRY #$Germany)))")))

(toplevel
  (inference-removal-module :removal-isa-thecollectionof-check
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound
                                  (list :nat (cons #$TheCollectionOf :fully-bound)))
          :exclusive t
          :supplants (list :removal-all-instances)
          :cost-expression '*expensive-hl-module-check-cost*
          :expand 'removal-isa-thecollectionof-check-expand
          :documentation "(#$isa <fully-bound> (#$TheCollectionOf <variable> <fully-bound>))"
          :example "(#$isa #$France
  (#$TheCollectionOf ?COUNTRY
    (#$politiesBorderEachOther ?COUNTRY #$Germany)))")))

(toplevel
  (inference-removal-module :removal-not-elementof-thesetof-check
    (list :sense :neg
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fully-bound (cons #$TheSetOf :fully-bound))
          :cost-expression '*inference-recursive-query-overhead*
          :expand 'removal-not-elementof-thesetof-check-expand
          :documentation "(#$not (#$elementOf <fully-bound> (#$TheSetOf <variable> <fully-bound>)))"
          :example "(#$not
  (#$elementOf #$Spain
    (#$TheSetOf ?COUNTRY
      (#$bordersOn ?COUNTRY #$Germany))))")))

(toplevel
  (inference-removal-module :removal-not-isa-thecollectionof-check
    (list :sense :neg
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound
                                  (list :nat (cons #$TheCollectionOf :fully-bound)))
          :cost-expression '*inference-recursive-query-overhead*
          :expand 'removal-not-isa-thecollectionof-check-expand
          :documentation "(#$not (#$isa <fully-bound> (#$TheCollectionOf <variable> <fully-bound>)))"
          :example "(#$not
  (#$elementOf #$Spain
    (#$TheSetOf ?COUNTRY
      (#$politiesBorderEachOther ?COUNTRY #$Germany))))")))

(toplevel
  (inference-removal-module :removal-all-elementof
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :fort :not-fully-bound)
          :cost-expression '*average-all-isa-count*
          :completeness :grossly-incomplete
          :expand 'removal-all-elementof-expand
          :documentation "(#$elementOf <fort> <not fully-bound>)"
          :example "(#$elementOf #$Dog ?WHAT)")))

(toplevel
  (inference-removal-module :removal-nat-all-elementof
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf (cons :fully-bound :fully-bound) :not-fully-bound)
          :cost-expression '*average-all-isa-count*
          :completeness :grossly-incomplete
          :expand 'removal-nat-all-elementof-expand
          :documentation "(#$elementOf (<fully-bound> . <fully-bound>) <not fully-bound>)
via #$resultIsa and #$resultIsaArg"
          :example "(#$elementOf (#$JuvenileFn #$Cougar) ?WHAT)")))

(toplevel
  (inference-removal-module :removal-elementof-unify
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :not-fully-bound (cons #$TheSet :fully-bound))
          :cost 'removal-elementof-unify-cost
          :completeness :complete
          :expand 'removal-elementof-unify-expand
          :documentation "(#$elementOf <not fully-bound> (#$TheSet . <fully-bound>))"
          :example "(#$elementOf ?WHAT (#$TheSet #$Dog #$Cat))")))

(toplevel
  (inference-removal-module :removal-elementof-collection-unify
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :not-fully-bound :collection-fort)
          :cost 'removal-elementof-collection-unify-cost
          :completeness-pattern (list :call 'removal-elementof-collection-unify-completeness :input)
          :input-extract-pattern (list :template
                                       (list #$elementOf :anything (list :bind 'collection))
                                       (list :value 'collection))
          :output-generate-pattern (list :call 'removal-elementof-collection-unify-iterator :input)
          :output-construct-pattern (list #$elementOf :input (list :value 'collection))
          :support-module :isa
          :support-strength :default
          :documentation "(#$elementOf <not fully-bound> <fort>)
where arg2 is a collection"
          :example "(#$elementOf ?DOG #$Dog)")))

(toplevel
  (inference-removal-module :removal-elementof-set-unify
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :not-fully-bound
                                  (list :and :fort (list :not (list :test 'collection-p))))
          :cost 'removal-elementof-set-unify-cost
          :complete-pattern (list :test 'removal-completely-asserted-asent?)
          :input-extract-pattern (list :template
                                       (list :bind 'asent)
                                       (list :value 'asent))
          :output-generate-pattern (list :call 'removal-elementof-set-unify-iterator :input)
          :output-decode-pattern (list :template
                                       (list :bind 'assertion)
                                       (list :value 'assertion))
          :output-construct-pattern (list :call 'gaf-formula :input)
          :support-pattern (list (list :value 'assertion))
          :documentation "(#$elementOf <not fully-bound> <fort>)
where arg2 is not a collection"
          :example "(#$elementOf ?ELEM #$BlackAndWhiteColorScheme)")))

(toplevel
  (inference-removal-module :removal-elementof-thesetof-unify
    (list :sense :pos
          :predicate #$elementOf
          :required-pattern (list #$elementOf :not-fully-bound (cons #$TheSetOf :fully-bound))
          :cost 'removal-elementof-thesetof-unify-cost
          :expand 'removal-elementof-thesetof-unify-expand
          :documentation "(#$elementOf <not fully-bound> (#$TheSetOf <variable> <fully-bound>))"
          :example "(#$elementOf ?WHAT
  (#$TheSetOf ?COUNTRY
    (#$bordersOn ?COUNTRY #$Germany)))")))

(toplevel
  (inference-removal-module :removal-isa-thecollectionof-unify
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound
                                  (list :nat (cons #$TheCollectionOf :fully-bound)))
          :exclusive t
          :supplants (list :removal-all-instances)
          :cost 'removal-isa-thecollectionof-unify-cost
          :expand 'removal-isa-thecollectionof-unify-expand
          :documentation "(#$isa <not fully-bound> (#$TheCollectionOf <variable> <fully-bound>))"
          :example "(#$isa ?WHAT
  (#$TheCollectionOf ?COUNTRY
    (#$politiesBorderEachOther ?COUNTRY #$Germany)))")))

(toplevel
  (inference-removal-module :removal-isa-subcollection-of-with-relation-to-fn-unify
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound
                                  (list :nat (cons #$SubcollectionOfWithRelationToFn :fully-bound)))
          :cost 'removal-isa-subcollection-cost
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <not fully-bound> (#$SubcollectionOfWithRelationToFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-subcollection-of-with-relation-to-fn-check
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound
                                  (list :nat (cons #$SubcollectionOfWithRelationToFn :fully-bound)))
          :cost-expression '*expensive-hl-module-check-cost*
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <fully-bound> (#$SubcollectionOfWithRelationToFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-subcollection-of-with-relation-from-fn-unify
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound
                                  (list :nat (cons #$SubcollectionOfWithRelationFromFn :fully-bound)))
          :cost 'removal-isa-subcollection-cost
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <not fully-bound> (#$SubcollectionOfWithRelationFromFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-subcollection-of-with-relation-from-fn-check
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound
                                  (list :nat (cons #$SubcollectionOfWithRelationFromFn :fully-bound)))
          :cost-expression '*expensive-hl-module-check-cost*
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <fully-bound> (#$SubcollectionOfWithRelationFromFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-subcollection-of-with-relation-to-type-fn-unify
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound
                                  (list :nat (cons #$SubcollectionOfWithRelationToTypeFn :fully-bound)))
          :cost 'removal-isa-subcollection-cost
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <not fully-bound> (#$SubcollectionOfWithRelationToTypeFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-subcollection-of-with-relation-to-type-fn-check
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound
                                  (list :nat (cons #$SubcollectionOfWithRelationToTypeFn :fully-bound)))
          :cost-expression '*expensive-hl-module-check-cost*
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <fully-bound> (#$SubcollectionOfWithRelationToTypeFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-subcollection-of-with-relation-from-type-fn-unify
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound
                                  (list :nat (cons #$SubcollectionOfWithRelationFromTypeFn :fully-bound)))
          :cost 'removal-isa-subcollection-cost
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <not fully-bound> (#$SubcollectionOfWithRelationFromTypeFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-subcollection-of-with-relation-from-type-fn-check
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound
                                  (list :nat (cons #$SubcollectionOfWithRelationFromTypeFn :fully-bound)))
          :cost-expression '*expensive-hl-module-check-cost*
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <fully-bound> (#$SubcollectionOfWithRelationFromTypeFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-subcollection-occurs-at-fn-unify
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound
                                  (list :nat (cons #$SubcollectionOccursAtFn :fully-bound)))
          :cost 'removal-isa-subcollection-cost
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <not fully-bound> (#$SubcollectionOccursAtFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-subcollection-occurs-at-fn-check
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound
                                  (list :nat (cons #$SubcollectionOccursAtFn :fully-bound)))
          :cost-expression '*expensive-hl-module-check-cost*
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <fully-bound> (#$SubcollectionOccursAtFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-collection-subset-fn-unify
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound
                                  (list :nat (cons #$CollectionSubsetFn :fully-bound)))
          :cost 'removal-collection-subset-fn-cost
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <not fully-bound> (#$CollectionSubsetFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-collection-subset-fn-check
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound
                                  (list :nat (cons #$CollectionSubsetFn :fully-bound)))
          :cost-expression '*expensive-hl-module-check-cost*
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <fully-bound> (#$CollectionSubsetFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-collection-intersection-2-fn-unify
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound
                                  (list :nat (cons #$CollectionIntersection2Fn :fully-bound)))
          :cost 'removal-isa-subcollection-cost
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <not fully-bound> (#$CollectionIntersection2Fn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-collection-intersection-2-fn-check
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound
                                  (list :nat (cons #$CollectionIntersection2Fn :fully-bound)))
          :cost-expression '*expensive-hl-module-check-cost*
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <fully-bound> (#$CollectionIntersection2Fn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-collection-difference-fn-unify
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :not-fully-bound
                                  (list :nat (cons #$CollectionDifferenceFn :fully-bound)))
          :cost 'removal-isa-subcollection-cost
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <not fully-bound> (#$CollectionDifferenceFn . <fully-bound>))")))

(toplevel
  (inference-removal-module :removal-isa-collection-difference-fn-check
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :fully-bound
                                  (list :nat (cons #$CollectionDifferenceFn :fully-bound)))
          :cost-expression '*expensive-hl-module-check-cost*
          :completeness :grossly-incomplete
          :expand 'removal-isa-subcollection-unify-expand
          :documentation "(#$isa <fully-bound> (#$CollectionDifferenceFn . <fully-bound>))")))

(toplevel
  (inference-conjunctive-removal-module :removal-all-isa-of-type
    (list :every-predicates (list #$isa)
          :applicability 'removal-all-isa-of-type-applicability
          :completeness-pattern (list :template
                                      (list nil
                                            (list (list (list :bind 'mt-1)
                                                        (list :bind 'asent-1))
                                                  (list (list :bind 'mt-2)
                                                        (list :bind 'asent-2))))
                                      (list :call 'removal-all-isa-of-type-completeness
                                            (list :value 'asent-1)
                                            (list :value 'mt-1)
                                            (list :value 'asent-2)
                                            (list :value 'mt-2)))
          :cost 'removal-all-isa-of-type-cost
          :expand 'removal-all-isa-of-type-expand
          :documentation "(#$and (#$isa <fort1> <varN>)
           (#$isa <varN> <fort2>))"
          :example "(#$and (#$isa #$AbrahamLincoln ?OCCUPATION)
           (#$isa ?OCCUPATION #$PersonTypeByOccupation))")))

;; quotedIsa modules

(toplevel
  (register-solely-specific-removal-module-predicate #$quotedIsa))

(toplevel
  (inference-removal-module-use-meta-removal #$quotedIsa :meta-removal-completely-enumerable-pos))
(toplevel
  (inference-removal-module-use-meta-removal #$quotedIsa :meta-removal-completely-decidable-pos))
(toplevel
  (inference-removal-module-use-generic #$quotedIsa :removal-completely-decidable-neg))

(toplevel
  (inference-preference-module :quoted-isa-x-y-pos
    (list :sense :pos
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa :not-fully-bound :not-fully-bound)
          :preference-level :disallowed)))

(toplevel
  (inference-preference-module :all-quoted-instances-pos
    (list :sense :pos
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa :not-fully-bound :fully-bound)
          :preference 'all-quoted-instances-pos-preference)))

(toplevel
  (inference-preference-module :all-quoted-isa-pos
    (list :sense :pos
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa :fully-bound :not-fully-bound)
          :preference-level :dispreferred)))

(toplevel
  (inference-removal-module :removal-quoted-isa-collection-check-pos
    (list :sense :pos
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa :fort :fort)
          :cost 'removal-quoted-isa-collection-check-pos-cost
          :expand 'removal-quoted-isa-collection-check-pos-expand
          :documentation "(#$quotedIsa <fort> <fort>)")))

(toplevel
  (inference-removal-module :removal-quoted-isa-collection-check-neg
    (list :sense :neg
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa :fort :fort)
          :cost 'removal-quoted-isa-collection-check-neg-cost
          :expand 'removal-quoted-isa-collection-check-neg-expand
          :documentation "(#$not (#$quotedIsa <fort> <fort>))"
          :example "(#$not (#$quotedIsa #$Dog #$Predicate))")))

(toplevel
  (inference-removal-module :removal-quoted-isa-defn-pos
    (list :sense :pos
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa :fully-bound :fort)
          :required 'removal-quoted-isa-defn-pos-required
          :cost 'removal-quoted-isa-defn-pos-cost
          :expand 'removal-quoted-isa-defn-pos-expand
          :documentation "(#$quotedIsa <fully-bound> <fort>)
via passing a #$defnIff or a #$defnSufficient"
          :example "(#$quotedIsa 42 #$SubLInteger)")))

(toplevel
  (inference-removal-module :removal-quoted-isa-defn-neg
    (list :sense :neg
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa :fully-bound :fort)
          :cost 'removal-quoted-isa-defn-neg-cost
          :expand 'removal-quoted-isa-defn-neg-expand
          :documentation "(#$not (#$quotedIsa <fully-bound> <fort>))
via failing a #$defnIff or a #$defnNecessary"
          :example "(#$not (#$quotedIsa 42 #$SubLString))")))

(toplevel
  (inference-removal-module :removal-nat-quoted-isa
    (list :sense :pos
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa (cons :fully-bound :fully-bound) :fort)
          :cost-expression '*hl-module-check-cost*
          :expand 'removal-nat-quoted-isa-expand
          :documentation "(#$quotedIsa (<fully-bound> . <fully-bound>) <fort>)")))

(toplevel
  (inference-removal-module :removal-all-quoted-isa
    (list :sense :pos
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa :fort :not-fully-bound)
          :cost-expression '*average-all-isa-count*
          :expand 'removal-all-quoted-isa-expand
          :documentation "(#$quotedIsa <fort> <not fully-bound>)"
          :example "(#$quotedIsa #$Dog ?COL)")))

(toplevel
  (inference-removal-module :removal-nat-all-quoted-isa
    (list :sense :pos
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa (cons :fully-bound :fully-bound) :not-fully-bound)
          :cost-expression '*average-all-isa-count*
          :expand 'removal-nat-all-quoted-isa-expand
          :documentation "(#$quotedIsa (<fully-bound> . <fully-bound>) <not fully-bound>)"
          :example "(#$quotedIsa (#$JuvenileFn #$Cougar) ?COL)")))

(toplevel
  (inference-removal-module :removal-all-quoted-instances
    (list :sense :pos
          :predicate #$quotedIsa
          :required-pattern (list #$quotedIsa :not-fully-bound :fort)
          :cost 'removal-all-quoted-instances-cost
          :completeness-pattern (list :call 'removal-all-quoted-instances-completeness :input)
          :input-extract-pattern (list :template
                                       (list #$quotedIsa :anything (list :bind 'collection))
                                       (list :value 'collection))
          :output-generate-pattern (list :call 'removal-all-quoted-instances-iterator :input)
          :output-construct-pattern (list #$quotedIsa :input (list :value 'collection))
          :support-module :isa
          :support-strength :default
          :documentation "(#$quotedIsa <not fully-bound> <fort>)")))
