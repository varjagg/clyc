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

(defun symmetric-asent (asent)
  (list (atomic-sentence-predicate asent)
        (atomic-sentence-arg2 asent)
        (atomic-sentence-arg1 asent)))

;; (defun symmetric-literal (asent) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list2 = arglist ((PERMUTED-FORMULA SOURCE-FORMULA &KEY DONE) &BODY BODY)
;; $sym6 = gensym SOURCE-FORMULA-VAR
;; $sym7 = CLET, $sym8 = PIF, $sym9 = EL-BINARY-FORMULA-P
;; $sym10 = SYMMETRIC-ASENT, $sym11 = DO-LIST
;; $sym12 = FORMULA-COMMUTATIVE-PERMUTATIONS, $sym13 = PUNLESS
;; When source is binary, binds permuted-formula to (symmetric-asent source),
;; otherwise iterates over (formula-commutative-permutations source).
;; :done key provides early termination.
(defmacro do-formula-commutative-permutations ((permuted-formula source-formula
                                                &key done)
                                               &body body)
  (with-temp-vars (source-formula-var)
    `(let ((,source-formula-var ,source-formula))
       (if (el-binary-formula-p ,source-formula-var)
           (let ((,permuted-formula (symmetric-asent ,source-formula-var)))
             (unless ,done
               ,@body))
           (dolist (,permuted-formula (formula-commutative-permutations ,source-formula-var))
             (unless ,done
               ,@body))))))

;; Reconstructed from Internal Constants:
;; $list14 = arglist ((PERMUTED-FORMULA SOURCE-FORMULA &KEY DONE PENETRATE-ARGS?) &BODY BODY)
;; $sym17 = gensym SOURCE-FORMULA-VAR
;; $sym18 = CANONICAL-COMMUTATIVE-PERMUTATIONS
;; $list19 = (FUNCTION HL-VAR?) — passes #'hl-var? to canonical-commutative-permutations
;; Iterates over canonical commutative permutations with #'hl-var? and penetrate-args?.
(defmacro do-formula-canonical-commutative-permutations ((permuted-formula source-formula
                                                          &key done penetrate-args?)
                                                         &body body)
  (with-temp-vars (source-formula-var)
    `(let ((,source-formula-var ,source-formula))
       (dolist (,permuted-formula (canonical-commutative-permutations
                                   ,source-formula-var #'hl-var? ,penetrate-args?))
         (unless ,done
           ,@body)))))

;; (defun commutative-in-args-supports (asent) ...) -- active declareFunction, no body

(defun removal-commutativity-lookup-cost (asent truth)
  (if (fully-bound-p asent)
      ;; Likely computes the check cost for a fully-bound commutative asent
      ;; by counting matching GAF assertions.
      (missing-larkc 32753)
      (removal-commutativity-generate-cost asent truth)))

;; (defun removal-commutativity-check-cost (asent truth) ...) -- active declareFunction, no body

(defun removal-commutativity-generate-cost (asent truth)
  (let ((cost 0))
    (do-formula-canonical-commutative-permutations (permuted-asent asent)
      (incf cost (num-best-gaf-lookup-index permuted-asent truth)))
    cost))

;; This is a full inline expansion of do-gaf-lookup-index, matching the Java directly.
;; The outer loop iterates over canonical-commutative-permutations of asent.
(defun removal-commutativity-lookup-iterator (asent sense)
  (let ((result nil))
    (do-formula-canonical-commutative-permutations (permuted-asent asent)
      (let* ((l-index (inference-gaf-lookup-index permuted-asent sense))
             (method (do-gli-extract-method l-index)))
        (case method
          (:gaf-arg
           (multiple-value-bind (term argnum predicate) (do-gli-vga-extract-keys l-index)
             (cond
               (argnum
                (if predicate
                    (let ((pred-var predicate))
                      (when (do-gaf-arg-index-key-validator term argnum pred-var)
                        (let ((iterator-var (new-gaf-arg-final-index-spec-iterator term argnum pred-var))
                              (done-var nil)
                              (token-var nil))
                          (until done-var
                            (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                                   (valid (not (eq token-var final-index-spec))))
                              (when valid
                                (let ((final-index-iterator nil))
                                  (unwind-protect
                                       (progn
                                         (setf final-index-iterator
                                               (new-final-index-iterator final-index-spec :gaf (sense-truth sense) nil))
                                         (let ((done-var-9 nil)
                                               (token-var-10 nil))
                                           (until done-var-9
                                             (let* ((assertion (iteration-next-without-values-macro-helper
                                                                final-index-iterator token-var-10))
                                                    (valid-11 (not (eq token-var-10 assertion))))
                                               (when valid-11
                                                 (when (direction-is-relevant assertion)
                                                   (multiple-value-bind (v-bindings gaf-asent unify-justification)
                                                       (gaf-asent-unify permuted-asent (gaf-formula assertion) t t)
                                                     (declare (ignore gaf-asent unify-justification))
                                                     (when v-bindings
                                                       (push (list v-bindings assertion) result)))))
                                               (setf done-var-9 (not valid-11))))))
                                    (when final-index-iterator
                                      (destroy-final-index-iterator final-index-iterator)))))
                              (setf done-var (not valid)))))))
                    ;; argnum but no predicate
                    (let ((pred-var nil))
                      (when (do-gaf-arg-index-key-validator term argnum pred-var)
                        (let ((iterator-var (new-gaf-arg-final-index-spec-iterator term argnum pred-var))
                              (done-var nil)
                              (token-var nil))
                          (until done-var
                            (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                                   (valid (not (eq token-var final-index-spec))))
                              (when valid
                                (let ((final-index-iterator nil))
                                  (unwind-protect
                                       (progn
                                         (setf final-index-iterator
                                               (new-final-index-iterator final-index-spec :gaf (sense-truth sense) nil))
                                         (let ((done-var-12 nil)
                                               (token-var-13 nil))
                                           (until done-var-12
                                             (let* ((assertion (iteration-next-without-values-macro-helper
                                                                final-index-iterator token-var-13))
                                                    (valid-14 (not (eq token-var-13 assertion))))
                                               (when valid-14
                                                 (when (direction-is-relevant assertion)
                                                   (multiple-value-bind (v-bindings gaf-asent unify-justification)
                                                       (gaf-asent-unify permuted-asent (gaf-formula assertion) t t)
                                                     (declare (ignore gaf-asent unify-justification))
                                                     (when v-bindings
                                                       (push (list v-bindings assertion) result)))))
                                               (setf done-var-12 (not valid-14))))))
                                    (when final-index-iterator
                                      (destroy-final-index-iterator final-index-iterator)))))
                              (setf done-var (not valid)))))))))
               ;; no argnum, predicate
               (predicate
                (let ((pred-var predicate))
                  (when (do-gaf-arg-index-key-validator term nil pred-var)
                    (let ((iterator-var (new-gaf-arg-final-index-spec-iterator term nil pred-var))
                          (done-var nil)
                          (token-var nil))
                      (until done-var
                        (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                               (valid (not (eq token-var final-index-spec))))
                          (when valid
                            (let ((final-index-iterator nil))
                              (unwind-protect
                                   (progn
                                     (setf final-index-iterator
                                           (new-final-index-iterator final-index-spec :gaf (sense-truth sense) nil))
                                     (let ((done-var-15 nil)
                                           (token-var-16 nil))
                                       (until done-var-15
                                         (let* ((assertion (iteration-next-without-values-macro-helper
                                                            final-index-iterator token-var-16))
                                                (valid-17 (not (eq token-var-16 assertion))))
                                           (when valid-17
                                             (when (direction-is-relevant assertion)
                                               (multiple-value-bind (v-bindings gaf-asent unify-justification)
                                                   (gaf-asent-unify permuted-asent (gaf-formula assertion) t t)
                                                 (declare (ignore gaf-asent unify-justification))
                                                 (when v-bindings
                                                   (push (list v-bindings assertion) result)))))
                                           (setf done-var-15 (not valid-17))))))
                                (when final-index-iterator
                                  (destroy-final-index-iterator final-index-iterator)))))
                          (setf done-var (not valid))))))))
               ;; no argnum, no predicate
               (t
                (let ((pred-var nil))
                  (when (do-gaf-arg-index-key-validator term nil pred-var)
                    (let ((iterator-var (new-gaf-arg-final-index-spec-iterator term nil pred-var))
                          (done-var nil)
                          (token-var nil))
                      (until done-var
                        (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                               (valid (not (eq token-var final-index-spec))))
                          (when valid
                            (let ((final-index-iterator nil))
                              (unwind-protect
                                   (progn
                                     (setf final-index-iterator
                                           (new-final-index-iterator final-index-spec :gaf (sense-truth sense) nil))
                                     (let ((done-var-18 nil)
                                           (token-var-19 nil))
                                       (until done-var-18
                                         (let* ((assertion (iteration-next-without-values-macro-helper
                                                            final-index-iterator token-var-19))
                                                (valid-20 (not (eq token-var-19 assertion))))
                                           (when valid-20
                                             (when (direction-is-relevant assertion)
                                               (multiple-value-bind (v-bindings gaf-asent unify-justification)
                                                   (gaf-asent-unify permuted-asent (gaf-formula assertion) t t)
                                                 (declare (ignore gaf-asent unify-justification))
                                                 (when v-bindings
                                                   (push (list v-bindings assertion) result)))))
                                           (setf done-var-18 (not valid-20))))))
                                (when final-index-iterator
                                  (destroy-final-index-iterator final-index-iterator)))))
                          (setf done-var (not valid)))))))))))
          (:predicate-extent
           (let ((pred-var (do-gli-vpe-extract-key l-index)))
             (when (do-predicate-extent-index-key-validator pred-var)
               (let ((iterator-var (new-predicate-extent-final-index-spec-iterator pred-var))
                     (done-var nil)
                     (token-var nil))
                 (until done-var
                   (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                          (valid (not (eq token-var final-index-spec))))
                     (when valid
                       (let ((final-index-iterator nil))
                         (unwind-protect
                              (progn
                                (setf final-index-iterator
                                      (new-final-index-iterator final-index-spec :gaf (sense-truth sense) nil))
                                (let ((done-var-21 nil)
                                      (token-var-22 nil))
                                  (until done-var-21
                                    (let* ((assertion (iteration-next-without-values-macro-helper
                                                       final-index-iterator token-var-22))
                                           (valid-23 (not (eq token-var-22 assertion))))
                                      (when valid-23
                                        (when (direction-is-relevant assertion)
                                          (multiple-value-bind (v-bindings gaf-asent unify-justification)
                                              (gaf-asent-unify permuted-asent (gaf-formula assertion) t t)
                                            (declare (ignore gaf-asent unify-justification))
                                            (when v-bindings
                                              (push (list v-bindings assertion) result)))))
                                      (setf done-var-21 (not valid-23))))))
                           (when final-index-iterator
                             (destroy-final-index-iterator final-index-iterator)))))
                     (setf done-var (not valid))))))))
          (:overlap
           ;; Likely iterates over overlapping GAF assertions from an overlap index.
           (dolist (assertion (missing-larkc 5144))
             (when (or (null (sense-truth sense))
                       (assertion-has-truth assertion (sense-truth sense)))
               (when (direction-is-relevant assertion)
                 (multiple-value-bind (v-bindings gaf-asent unify-justification)
                     (gaf-asent-unify permuted-asent (gaf-formula assertion) t t)
                   (declare (ignore gaf-asent unify-justification))
                   (when v-bindings
                     (push (list v-bindings assertion) result)))))))
          (otherwise
           ;; Likely signals an error for an unknown lookup index method.
           (missing-larkc 30377)))))
    (when result
      (new-list-iterator result))))

(defun removal-symmetric-lookup-pos-cost (asent &optional sense)
  (declare (ignore sense))
  (removal-commutativity-lookup-cost asent :true))

;; (defun removal-symmetric-lookup-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-symmetric-lookup-neg-completeness (asent) ...) -- active declareFunction, no body

(defun removal-symmetric-lookup-pos-iterator (asent)
  (removal-commutativity-lookup-iterator asent :pos))

;; (defun removal-symmetric-lookup-neg-iterator (asent) ...) -- active declareFunction, no body

(defun removal-symmetric-supports (assertion)
  (let ((predicate (gaf-predicate assertion)))
    (list assertion (additional-isa-support predicate #$SymmetricBinaryPredicate))))

;; (defun removal-commutative-lookup-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-commutative-lookup-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-commutative-lookup-neg-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-commutative-lookup-pos-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-commutative-lookup-neg-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-commutative-supports (asent) ...) -- active declareFunction, no body
;; (defun removal-partially-commutative-lookup-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-partially-commutative-lookup-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-partially-commutative-lookup-neg-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-partially-commutative-lookup-pos-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-partially-commutative-lookup-neg-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-partially-commutative-supports (asent) ...) -- active declareFunction, no body
;; (defun removal-asymmetric-lookup-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asymmetric-lookup-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-asymmetric-lookup-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-asymmetric-supports (asent) ...) -- active declareFunction, no body

(toplevel
  (define-obsolete-register 'symmetric-literal '(symmetric-asent)))

(toplevel
  (inference-removal-module :removal-symmetric-lookup-pos
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything)
                                   ((:test inference-symmetric-predicate?) . :anything))
          :cost 'removal-symmetric-lookup-pos-cost
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-symmetric-lookup-pos-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-symmetric-supports (:value assertion))
          :documentation "(<symmetric predicate> <whatever> <whatever>)
from (<symmetric predicate> <arg2> <arg1>) assertion"
          :example "(#$bordersOn #$Canada #$UnitedStatesOfAmerica)")))

(toplevel
  (inference-removal-module :removal-symmetric-lookup-neg
    (list :sense :neg
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything)
                                   ((:test inference-symmetric-predicate?) . :anything))
          :cost 'removal-symmetric-lookup-neg-cost
          :completeness-pattern '(:call removal-symmetric-lookup-neg-completeness :input)
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-symmetric-lookup-neg-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-symmetric-supports (:value assertion))
          :documentation "(#$not (<symmetric predicate> <whatever> <whatever>))
from (#$not (<symmetric predicate> <arg2> <arg1>)) assertion")))

(toplevel
  (inference-removal-module :removal-commutative-lookup-pos
    (list :sense :pos
          :arity nil
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything . (:anything . :anything))
                                   ((:test inference-commutative-predicate-p) . :anything))
          :cost 'removal-commutative-lookup-pos-cost
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-commutative-lookup-pos-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-commutative-supports (:value assertion))
          :documentation "(<commutative predicate> . <args>)
from (<commutative predicate> . <reordered args>) assertion"
          :example "(#$collinear <some point> <some other point> <some other other point>)")))

(toplevel
  (inference-removal-module :removal-commutative-lookup-neg
    (list :sense :neg
          :arity nil
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything . (:anything . :anything))
                                   ((:test inference-commutative-predicate-p) . :anything))
          :cost 'removal-commutative-lookup-neg-cost
          :completeness-pattern '(:call removal-commutative-lookup-neg-completeness :input)
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-commutative-lookup-neg-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-commutative-supports (:value assertion))
          :documentation "(<commutative predicate> . <args>)
from (<commutative predicate> . <reordered args>) assertion"
          :example "(#$not (#$collinear <some point> <some other point> <some other other point>))")))

(toplevel
  (inference-removal-module :removal-partially-commutative-lookup-pos
    (list :sense :pos
          :arity nil
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything . (:anything . :anything))
                                   ((:test inference-partially-commutative-predicate-p) . :anything))
          :cost 'removal-partially-commutative-lookup-pos-cost
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-partially-commutative-lookup-pos-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-partially-commutative-supports (:value assertion))
          :documentation "(<partially commutative predicate> . <args>)
from (<partially commutative predicate> . <reordered args>) assertion"
          :example "(distanceBetween PlanetEarth Sun ((Mega Mile) 93))
    from
    (distanceBetween Sun PlanetEarth ((Mega Mile) 93))")))

(toplevel
  (inference-removal-module :removal-partially-commutative-lookup-neg
    (list :sense :neg
          :arity nil
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything . (:anything . :anything))
                                   ((:test inference-partially-commutative-predicate-p) . :anything))
          :cost 'removal-partially-commutative-lookup-neg-cost
          :completeness-pattern '(:call removal-partially-commutative-lookup-neg-completeness :input)
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-partially-commutative-lookup-neg-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-partially-commutative-supports (:value assertion))
          :documentation "(<partially commutative predicate> . <args>)
from (<partially commutative predicate> . <reordered args>) assertion"
          :example "(not (distanceBetween PlanetEarth Sun (Inch 93)))
    from
    (not (distanceBetween Sun PlanetEarth (Inch 93)))")))

(toplevel
  (inference-removal-module :removal-asymmetric-lookup
    (list :sense :neg
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) (:not :fort) (:not :fort))
                                   ((:test inference-asymmetric-predicate?) . :anything))
          :cost 'removal-asymmetric-lookup-cost
          :completeness-pattern '(:call removal-asymmetric-lookup-completeness :input)
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-asymmetric-lookup-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-asymmetric-supports (:value assertion))
          :documentation "(#$not (<asymmetric predicate> <non-fort> <non-fort>))
from (<asymmetric predicate> <arg2> <arg1>) assertion.
NB: the case in which either arg is a FORT is subsumed by
negationInverse modules."
          :example "(#$not (#$northOf #$UnitedStatesOfAmerica #$Canada))")))
