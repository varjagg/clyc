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

(deflexical *nat-arguments-equal-enabled* nil
  "[Cyc] Temporary -- remove after natArgumentsEqual cleanup is complete.")

(deflexical *default-nat-function-check-cost* *hl-module-check-cost*)

(defparameter *nat-function-code-rule*
  '(#$implies (#$termOfUnit ?NAT (?FUNCTION . ?ARGS))
              (#$natFunction ?NAT ?FUNCTION)))

;; (defun removal-nat-function-check-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-function-check-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun additional-nat-function-supports () ...) -- active declareFunction, no body
;; (defun nat-function-hl-support () ...) -- active declareFunction, no body
;; (defun removal-nat-function-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-function-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-function-lookup-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-function-lookup-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-function-lookup-internal (nart) ...) -- active declareFunction, no body

(deflexical *default-nat-argument-check-cost* *hl-module-check-cost*)

(defparameter *nat-argument-code-rule*
  '(#$implies (#$and (#$termOfUnit ?NAT ?FORMULA)
                     (#$evaluate ?TERM (#$FormulaArgFn ?ARG ?FORMULA)))
              (#$natArgument ?NAT ?ARG ?TERM)))

;; (defun removal-nat-argument-check-pos-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-argument-check-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-argument-check-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun additional-nat-argument-supports () ...) -- active declareFunction, no body
;; (defun nat-argument-hl-support () ...) -- active declareFunction, no body
;; (defun removal-nat-argument-term-unify-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-argument-term-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-argument-term-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-argument-arg-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-argument-arg-unify-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-nat-argument-lookup-cost (asent &optional sense)
  (declare (ignore sense))
  (let ((fort (atomic-sentence-arg3 asent))
        (argnum (atomic-sentence-arg2 asent))
        (function? (function? fort)))
    (cond ((variable-p argnum)
           (if function?
               (+ (num-nart-arg-index fort)
                  ;; Likely counts something related to function arity
                  (missing-larkc 12781))
               (num-nart-arg-index fort)))
          ((zerop argnum)
           (if function?
               (num-nart-arg-index fort)
               0))
          (t
           (num-nart-arg-index fort argnum)))))

(defun removal-nat-argument-lookup-expand (asent &optional sense)
  (declare (ignore sense))
  (let ((fort (atomic-sentence-arg3 asent))
        (argnum (atomic-sentence-arg2 asent))
        (function? (function? fort)))
    (let ((*inference-literal* asent))
      (when function?
        (when (or (variable-p argnum)
                  (zerop argnum))
          ;; Likely iterates over function nart args for argnum=0 or variable case
          (missing-larkc 9450)))
      (if (variable-p argnum)
          (map-nart-arg-index #'removal-nat-argument-lookup-internal fort)
          (when (plusp argnum)
            (map-nart-arg-index #'removal-nat-argument-lookup-internal fort argnum)))))
  nil)

;; (defun removal-nat-argument-lookup-internal (nart) ...) -- active declareFunction, no body

(defparameter *nat-arguments-equal-code-rule*
  '(#$implies (#$and (#$termOfUnit ?NAT1 ?FORMULA1)
                     (#$termOfUnit ?NAT2 ?FORMULA2)
                     (#$evaluate ?ARGS-LIST (#$FormulaArgListFn ?FORMULA1))
                     (#$evaluate ?ARGS-LIST (#$FormulaArgListFn ?FORMULA2)))
              (#$natArgumentsEqual ?NAT1 ?NAT2)))

;; (defun removal-nat-arguments-equal-check-pos-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-arguments-equal-check-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-arguments-equal-check-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-nat-arguments-equal-check-cost (asent) ...) -- active declareFunction, no body
;; (defun nat-arguments-equal-hl-support () ...) -- active declareFunction, no body
;; (defun removal-nat-function-nat-argument-applicability (contextualized-asent) ...) -- active declareFunction, no body
;; (defun removal-nat-func-asents-with-not-fully-bound-arg1-dict-internal (contextualized-asent) ...) -- active declareFunction, no body (memoized-internal)
;; (defun removal-nat-func-asents-with-not-fully-bound-arg1-dict (contextualized-asent) ...) -- active declareFunction, no body (memoized)
;; (defun removal-nat-function-contextualized-asent-p-internal (contextualized-asent) ...) -- active declareFunction, no body (memoized-internal)
;; (defun removal-nat-function-contextualized-asent-p (contextualized-asent) ...) -- active declareFunction, no body (memoized)
;; (defun removal-nat-argument-contextualized-asent-p-internal (contextualized-asent) ...) -- active declareFunction, no body (memoized-internal)
;; (defun removal-nat-argument-contextualized-asent-p (contextualized-asent) ...) -- active declareFunction, no body (memoized)
;; (defun removal-nat-function-nat-argument-cost (contextualized-asent) ...) -- active declareFunction, no body
;; (defun removal-nat-function-nat-argument-expand (contextualized-asent) ...) -- active declareFunction, no body
;; (defun removal-nat-function-nat-argument-supports (contextualized-asent) ...) -- active declareFunction, no body

(toplevel
  (register-solely-specific-removal-module-predicate #$natFunction))

(toplevel
  (inference-preference-module :nat-function-lookup-pos
    (list :sense :pos
          :predicate #$natFunction
          :required-pattern (list #$natFunction :not-fully-bound :fully-bound)
          :preference-level :grossly-dispreferred)))

(toplevel
  (inference-removal-module :removal-nat-function-check-pos
    (list :sense :pos
          :predicate #$natFunction
          :required-pattern (list #$natFunction :nart :fully-bound)
          :cost 'removal-nat-function-check-pos-cost
          :completeness :complete
          :expand 'removal-nat-function-check-pos-expand
          :documentation "(#$natFunction <reified NAT> <fully-bound>)"
          :example "(#$natFunction (#$JuvenileFn #$Dog) #$JuvenileFn)")))

(toplevel
  (inference-removal-module :removal-nat-function-unify
    (list :sense :pos
          :predicate #$natFunction
          :required-pattern (list #$natFunction :nart :not-fully-bound)
          :cost 'removal-nat-function-unify-cost
          :completeness :complete
          :expand 'removal-nat-function-unify-expand
          :documentation "(#$natFunction <reified NAT> <not fully-bound>)"
          :example "(#$natFunction (#$JuvenileFn #$Dog) ?WHAT)")))

(toplevel
  (inference-removal-module :removal-nat-function-lookup
    (list :sense :pos
          :predicate #$natFunction
          :required-pattern (list #$natFunction :not-fully-bound :fort)
          :cost 'removal-nat-function-lookup-cost
          :completeness :complete
          :expand 'removal-nat-function-lookup-expand
          :documentation "(#$natFunction <not fully-bound> <fort>)"
          :example "(#$natFunction ?NAT #$JuvenileFn)")))

(toplevel
  (register-solely-specific-removal-module-predicate #$natArgument))

(toplevel
  (inference-preference-module :nat-argument-lookup-pos
    (list :sense :pos
          :predicate #$natArgument
          :required-pattern (list #$natArgument :not-fully-bound :anything :fully-bound)
          :preference-level :grossly-dispreferred)))

(toplevel
  (inference-removal-module :removal-nat-argument-check-pos
    (list :sense :pos
          :predicate #$natArgument
          :required-pattern (list #$natArgument :nart :integer :fully-bound)
          :required 'removal-nat-argument-check-pos-required
          :cost 'removal-nat-argument-check-pos-cost
          :completeness :complete
          :expand 'removal-nat-argument-check-pos-expand
          :documentation "(#$natArgument <reified NAT> <non-negative integer> <fully bound>)"
          :example "(#$natArgument (#$JuvenileFn #$Dog) 1 #$Dog)")))

(toplevel
  (inference-removal-module :removal-nat-argument-term-unify
    (list :sense :pos
          :predicate #$natArgument
          :required-pattern (list #$natArgument :nart :integer :not-fully-bound)
          :required 'removal-nat-argument-term-unify-required
          :cost 'removal-nat-argument-term-unify-cost
          :completeness :complete
          :expand 'removal-nat-argument-term-unify-expand
          :documentation "(#$natArgument <reified NAT> <non-negative integer> <not fully-bound>)"
          :example "(#$natArgument (#$JuvenileFn #$Dog) 1 ?WHAT)")))

(toplevel
  (inference-removal-module :removal-nat-argument-arg-unify
    (list :sense :pos
          :predicate #$natArgument
          :required-pattern (list #$natArgument :nart :not-fully-bound :anything)
          :cost 'removal-nat-argument-arg-unify-cost
          :completeness :complete
          :expand 'removal-nat-argument-arg-unify-expand
          :documentation "(#$natArgument <reified NAT> <not fully-bound> <anything>)"
          :example "(#$natArgument (#$JuvenileFn #$Dog) ?ARG ?WHAT)
    (#$natArgument (#$JuvenileFn #$Dog) ?ARG #$Dog)")))

(toplevel
  (inference-removal-module :removal-nat-argument-lookup
    (list :sense :pos
          :predicate #$natArgument
          :required-pattern (list #$natArgument :not-fully-bound
                                  (list :or (list :test 'non-negative-integer-p) :variable)
                                  :fort)
          :cost 'removal-nat-argument-lookup-cost
          :completeness :complete
          :expand 'removal-nat-argument-lookup-expand
          :documentation "(#$natArgument <not fully-bound> <variable> <fort>)
    (#$natArgument <not fully-bound> <integer>  <fort>)"
          :example "(#$natArgument ?NAT 1    #$Dog)
    (#$natArgument ?NAT ?ARG #$Dog)")))

(toplevel
  (register-solely-specific-removal-module-predicate #$natArgumentsEqual))

(toplevel
  (inference-removal-module :removal-nat-arguments-equal-check-pos
    (list :sense :pos
          :predicate #$natArgumentsEqual
          :required-pattern (list #$natArgumentsEqual :nart :nart)
          :required 'removal-nat-arguments-equal-check-pos-required
          :cost 'removal-nat-arguments-equal-check-pos-cost
          :completeness :complete
          :expand 'removal-nat-arguments-equal-check-pos-expand
          :documentation "(#$natArgumentsEqual <reified NAT> <reified NAT>)"
          :example "(#$natArgumentsEqual (#$LeftFn #$Leg) (#$RightFn #$Leg))")))

(toplevel
  (note-memoized-function 'removal-nat-func-asents-with-not-fully-bound-arg1-dict))

(toplevel
  (note-memoized-function 'removal-nat-function-contextualized-asent-p))

(toplevel
  (note-memoized-function 'removal-nat-argument-contextualized-asent-p))
