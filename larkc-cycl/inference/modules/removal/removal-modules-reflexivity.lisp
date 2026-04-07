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

(defparameter *default-reflexive-both-cost* *hl-module-check-cost*)

(defparameter *default-reflexive-one-arg-cost* 1)

;; (defun removal-reflexive-both-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-reflexive-one-arg-expand (asent &optional sense)
  (declare (ignore sense))
  (let ((*at-admit-consistent-nauts?* nil))
    (let ((arg1 (atomic-sentence-arg1 asent))
          (arg2 (atomic-sentence-arg2 asent)))
      (multiple-value-bind (v-bindings justification)
          (term-unify arg1 arg2 t t)
        (when v-bindings
          (let ((formula (subst-bindings v-bindings asent)))
            (removal-add-node (make-hl-support :reflexive formula)
                              v-bindings
                              justification)))))))

;; (defun removal-reflexive-map-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-reflexive-map-iterator (asent) ...) -- active declareFunction, no body
;; (defun best-reflexive-pred-arg-type (pred) ...) -- active declareFunction, no body

(defparameter *default-irreflexive-both-cost* *hl-module-check-cost*)

(defparameter *default-irreflexive-one-arg-cost* 1)

;; (defun removal-irreflexive-both-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-irreflexive-one-arg-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-irreflexive-one-arg-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-irreflexive-map-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-irreflexive-map-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-irreflexive-map-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-irreflexive-map-support (asent result) ...) -- active declareFunction, no body

(defun prune-reflexive-use-of-irreflexive-predicate-required (asent &optional sense)
  (declare (ignore sense))
  (and (eq (atomic-sentence-arg1 asent)
           (atomic-sentence-arg2 asent))
       (irreflexive-predicate? (atomic-sentence-predicate asent))))

;; (defun prune-reflexive-use-of-irreflexive-predicate-expand (asent &optional sense) ...) -- active declareFunction, no body

(toplevel
  (inference-removal-module :removal-reflexive-both
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :fully-bound :fully-bound)
                                   ((:test inference-reflexive-predicate?) . :anything))
          :cost-expression '*default-reflexive-both-cost*
          :completeness :incomplete
          :expand 'removal-reflexive-both-expand
          :documentation "(<reflexive predicate> <fully-bound> <fully-bound>)
    by unification of <arg1> and <arg2>"
          :example "(#$notFarFrom #$Italy #$Italy)
in
 #$WorldGeographyMt
via
 (#$isa #$notFarFrom #$ReflexiveBinaryPredicate)

(#$geographicalSubRegions (#$SchemaObjectFn #$Nima-Gns-LS -4463449) (#$SchemaObjectFn #$Nima-Gns-LS -4463449))
in
 (#$ContentMtFn #$Nima-KS)
via
 (#$isa (#$geographicalSubRegions #$ReflexiveBinaryPredicate))
")))

(toplevel
  (inference-removal-module :removal-reflexive-one-arg
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything)
                                   (:or (:anything :fully-bound :not-fully-bound)
                                        (:anything :not-fully-bound :fully-bound))
                                   ((:test inference-reflexive-predicate?) . :anything))
          :cost-expression '*default-reflexive-one-arg-cost*
          :completeness :grossly-incomplete
          :expand 'removal-reflexive-one-arg-expand
          :documentation "(<reflexive predicate> <fully-bound> <not-fully-bound>) and
    (<reflexive predicate> <not-fully-bound> <fully-bound>)
by unification of <not-fully-bound> and <fully-bound>
"
          :example "(#$notFarFrom #$Italy ?WHERE)
in
 #$WorldGeographyMt
via
 (#$isa #$notFarFrom #$ReflexiveBinaryPredicate)

(#$geographicalSubRegions (#$SchemaObjectFn #$Nima-Gns-LS -4463449) ?WHERE)
in
 (#$ContentMtFn #$Nima-KS)
via
 (#$isa #$geographicalSubRegions #$ReflexiveBinaryPredicate)")))

(toplevel
  (inference-removal-module :removal-reflexive-map
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :not-fully-bound :not-fully-bound)
                                   ((:test inference-reflexive-predicate?) . :anything))
          :cost 'removal-reflexive-map-cost
          :completeness :grossly-incomplete
          :input-extract-pattern '(:template ((:bind predicate) :anything :anything)
                                             (:value predicate))
          :output-generate-pattern '(:call removal-reflexive-map-iterator :input)
          :output-decode-pattern '((:value predicate) :input :input)
          :support-module :reflexive
          :support-strength :default
          :documentation "(<reflexive predicate> <not-fully-bound> <not-fully-bound>)
by iterating over the instances of the arg-types of <reflexive predicate>"
          :example "(#$subCultures ?X ?Y)")))

(toplevel
  (inference-removal-module :removal-irreflexive-both
    (list :sense :neg
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :fully-bound :fully-bound)
                                   ((:test inference-irreflexive-predicate?) . :anything))
          :cost-expression '*default-irreflexive-both-cost*
          :completeness :incomplete
          :expand 'removal-irreflexive-both-expand
          :documentation "(#$not (<irreflexive predicate> <fully-bound> <fully-bound>))
by unification of <arg1> and <arg2>"
          :example "(#$not (#$farFrom #$Italy #$Italy))
in
 #$WorldGeographyMt
via
 (#$isa #$farFrom #$IrreflexiveBinaryPredicate)

(#$not (#$farFrom (#$SchemaObjectFn #$Nima-Gns-LS -4463449) (#$SchemaObjectFn #$Nima-Gns-LS -4463449)))
in
 (#$ContentMtFn #$Nima-KS)
via
 (#$isa #$farFrom #$IrreflexiveBinaryPredicate)")))

(toplevel
  (inference-removal-module :removal-irreflexive-one-arg
    (list :sense :neg
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything)
                                   (:or (:anything :fully-bound :not-fully-bound)
                                        (:anything :not-fully-bound :fully-bound))
                                   ((:test inference-irreflexive-predicate?) . :anything))
          :cost-expression '*default-irreflexive-one-arg-cost*
          :completeness-pattern '(:call removal-irreflexive-one-arg-completeness :input)
          :expand 'removal-irreflexive-one-arg-expand
          :documentation "(#$not (<irreflexive predicate> <fully-bound> <not-fully-bound>)) and
    (#$not (<irreflexive predicate> <not-fully-bound> <fully-bound>))
by unification of <not-fully-bound> and <fully-bound>
"
          :example "(#$not (#$farFrom ?WHERE #$Italy))
in
 #$WorldGeographyMt
via
 (#$isa #$farFrom #$IrreflexiveBinaryPredicate)

(#$not (#$farFrom ?WHERE (#$SchemaObjectFn #$Nima-Gns-LS -4463449)))
in
 (#$ContentMtFn #$Nima-KS)
via
 (#$isa #$farFrom #$IrreflexiveBinaryPredicate)")))

(toplevel
  (inference-removal-module :removal-irreflexive-map
    (list :sense :neg
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :not-fully-bound :not-fully-bound)
                                   ((:test inference-irreflexive-predicate?) . :anything))
          :cost 'removal-irreflexive-map-cost
          :completeness-pattern '(:call removal-irreflexive-map-completeness :input)
          :input-extract-pattern '(:template ((:bind predicate) :anything :anything)
                                             (:value predicate))
          :output-generate-pattern '(:call removal-irreflexive-map-iterator :input)
          :output-decode-pattern '((:value predicate) :input :input)
          :support 'removal-irreflexive-map-support
          :documentation "(#$not (<irreflexive predicate> <not-fully-bound> <not-fully-bound>))
by iterating over the instances of the arg-types of <irreflexive predicate>")))

(toplevel
  (inference-removal-module :prune-reflexive-use-of-irreflexive-predicate
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) . :anything)
                                   ((:test inference-irreflexive-predicate?) . :anything))
          :required 'prune-reflexive-use-of-irreflexive-predicate-required
          :completeness :complete
          :cost-expression 0
          :expand 'prune-reflexive-use-of-irreflexive-predicate-expand
          :documentation "(<irreflexive-predicate> <anything> <anything>) pruned when <arg1> and <arg2> are equal."
          :example "(#$sisters ?var0 ?var0)")))

(toplevel
  (note-funcall-helper-function 'prune-reflexive-use-of-irreflexive-predicate-required))

(toplevel
  (note-funcall-helper-function 'prune-reflexive-use-of-irreflexive-predicate-expand))
