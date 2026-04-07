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

(defparameter *default-skolemize-cost* 1)

(defparameter *default-nat-unify-cost* 1)

;; Functions in declareFunction order:

;; Orphan constants :disallowed, :preferred likely used by nat-lookup-pos-preference.
;; Orphan constants :equality, :true-mon likely used by make-term-of-unit-support.

;; (defun nat-lookup-pos-preference (asent bindable-vars strategic-context) ...) -- active declareFunction, no body
;; (defun make-term-of-unit-support (nart naut) ...) -- active declareFunction, no body
;; (defun tou-analog-asents? (asent1 asent2) ...) -- active declareFunction, no body
;; (defun tou-sibling-asents? (asent1 asent2) ...) -- active declareFunction, no body
;; (defun removal-nat-formula-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-formula-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-term-of-unit-unify-impossible? (asent)
  ;; Likely checks if the arg1 and arg2 of a termOfUnit asent could not
  ;; possibly unify -- evidence: used as :test predicate in
  ;; :removal-term-of-unit-fail module's required-pattern.
  (missing-larkc 32745))

;; (defun removal-skolemize-create-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-skolemize-create-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun skolemization-allowed (function)
  (and (current-query-allows-new-terms?)
       (if (within-forward-inference?)
           (or *prefer-forward-skolemization*
               *allow-forward-skolemization*
               (forward-inference-reifiable-function-p function))
           (not *within-assertion-forward-propagation?*))))

;; Orphan constants :complete, :grossly-incomplete likely used by removal-nat-lookup-completeness.
;; Orphan constants :nart-arg, :gaf, :function-extent, :overlap likely used by the lookup/expand functions.

;; (defun removal-nat-lookup-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-nat-lookup-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-lookup-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-unify-expand (asent &optional sense) ...) -- active declareFunction, no body

;; Setup phase

(toplevel
  (register-solely-specific-removal-module-predicate #$termOfUnit))

(toplevel
  (inference-removal-module-use-meta-removal
   #$termOfUnit :meta-removal-completely-enumerable-pos))

(toplevel
  (inference-removal-module-use-meta-removal
   #$termOfUnit :meta-removal-completely-decidable-pos))

(toplevel
  (inference-preference-module :nat-lookup-pos
    (list :sense :pos
          :predicate #$termOfUnit
          :required-pattern (list #$termOfUnit
                                  :not-fully-bound
                                  (cons (list :and :fort
                                              (list :test 'skolemization-allowed))
                                        :not-fully-bound))
          :preference 'nat-lookup-pos-preference)))

(toplevel
  (note-funcall-helper-function 'nat-lookup-pos-preference))

(toplevel
  (inference-removal-module :removal-nat-formula
    (list :sense :pos
          :predicate #$termOfUnit
          :required-pattern (list #$termOfUnit :nart :anything)
          :cost 'removal-nat-formula-cost
          :completeness :complete
          :expand 'removal-nat-formula-expand
          :documentation "(#$termOfUnit <reified NAT> <whatever>)
    using the GAF indexing on <reified NAT>"
          :example "(#$termOfUnit (#$JuvenileFn #$Dog) (#$JuvenileFn ?WHAT))")))

(toplevel
  (inference-removal-module :removal-term-of-unit-fail
    (list :sense :pos
          :predicate #$termOfUnit
          :required-pattern (list :and
                                  (list :not (list :test 'removal-abduction-allowed?))
                                  (list :or
                                        (list #$termOfUnit
                                              (list :and
                                                    (list :test 'atom)
                                                    (list :not :nart)
                                                    (list :not :variable))
                                              :anything)
                                        (list :test 'removal-term-of-unit-unify-impossible?)))
          :exclusive t
          :cost-expression 0
          :completeness :complete
          :documentation "(#$termOfUnit <atom> <whatever>)
    in all cases where <atom> is not a reified NAT or variable, should immediately fail.

    (#$termOfUnit <arg1> <arg2>)
    in all cases where ARG1 and ARG2 could not possibly unify, should immediately fail."
          :example "(#$termOfUnit #$Dog (#$JuvenileFn ?WHAT))
    (#$termOfUnit 1 ?WHAT)
    (#$termOfUnit (#$IdentityFn #$Dog) (#$JuvenileFn ?WHAT))")))

(toplevel
  (inference-removal-module :removal-skolemize-create
    (list :sense :pos
          :predicate #$termOfUnit
          :required-pattern (list #$termOfUnit
                                  :not-fully-bound
                                  (cons :fort :fully-bound))
          :required 'removal-skolemize-create-required
          :cost-expression '*default-skolemize-cost*
          :expand 'removal-skolemize-create-expand
          :documentation "(#$termOfUnit <variable> (<fort> . <fully bound>))"
          :example "(#$termOfUnit ?NAT (#$JuvenileFn #$Cougar))")))

(toplevel
  (inference-removal-module :removal-nat-lookup
    (list :sense :pos
          :predicate #$termOfUnit
          :required-pattern (list #$termOfUnit
                                  :not-fully-bound
                                  (cons :fort :anything))
          :cost 'removal-nat-lookup-cost
          :completeness-pattern (list :call 'removal-nat-lookup-completeness :input)
          :expand 'removal-nat-lookup-expand
          :documentation "(#$termOfUnit <not fully-bound> (<fort> . <whatever>))
    using the function-argument indexing on <fort>"
          :example "(#$termOfUnit ?NAT (#$JuvenileFn ?COL))")))

(toplevel
  (inference-removal-module :removal-nat-unify
    (list :sense :pos
          :predicate #$termOfUnit
          :required-pattern (list #$termOfUnit
                                  (cons :fully-bound :fully-bound)
                                  (cons :anything :anything))
          :cost-expression '*default-nat-unify-cost*
          :expand 'removal-nat-unify-expand
          :documentation "(#$termOfUnit (<fully bound> . <fully bound>) (<whatever . <whatever>))
    via unification"
          :example "(#$termOfUnit (#$JuvenileFn #$Dog) (#$JuvenileFn ?WHAT))")))
