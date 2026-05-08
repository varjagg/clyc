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

(defun removal-lookup-pos-cost (asent &optional sense)
  (declare (ignore sense))
  (if (fully-bound-p asent)
      *cheap-hl-module-check-cost*
      (inference-num-gaf-lookup-index asent :pos)))

(defun removal-completely-asserted-asent? (asent)
  (inference-completely-asserted-asent? asent (inference-relevant-mt)))

;; This is a full inline expansion of do-gaf-lookup-index, matching the Java directly.
;; The macro body for do-gaf-lookup-index is missing-larkc, so we port the expansion.
(defun removal-lookup-pos-iterator (asent)
  (let* ((result nil)
         (l-index (inference-gaf-lookup-index asent :pos))
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
                                           (new-final-index-iterator final-index-spec :gaf (sense-truth :pos) nil))
                                     (let ((done-var-1 nil)
                                           (token-var-2 nil))
                                       (until done-var-1
                                         (let* ((assertion (iteration-next-without-values-macro-helper
                                                            final-index-iterator token-var-2))
                                                (valid-3 (not (eq token-var-2 assertion))))
                                           (when valid-3
                                             (when (direction-is-relevant assertion)
                                               (when (gaf-asent-unify asent (gaf-formula assertion))
                                                 (push assertion result))))
                                           (setf done-var-1 (not valid-3))))))
                                (when final-index-iterator
                                  (destroy-final-index-iterator final-index-iterator)))))
                          (setf done-var (not valid)))))))
                ;; no predicate
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
                                           (new-final-index-iterator final-index-spec :gaf (sense-truth :pos) nil))
                                     (let ((done-var-4 nil)
                                           (token-var-5 nil))
                                       (until done-var-4
                                         (let* ((assertion (iteration-next-without-values-macro-helper
                                                            final-index-iterator token-var-5))
                                                (valid-6 (not (eq token-var-5 assertion))))
                                           (when valid-6
                                             (when (direction-is-relevant assertion)
                                               (when (gaf-asent-unify asent (gaf-formula assertion))
                                                 (push assertion result))))
                                           (setf done-var-4 (not valid-6))))))
                                (when final-index-iterator
                                  (destroy-final-index-iterator final-index-iterator)))))
                          (setf done-var (not valid)))))))))
           ;; no argnum
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
                                       (new-final-index-iterator final-index-spec :gaf (sense-truth :pos) nil))
                                 (let ((done-var-7 nil)
                                       (token-var-8 nil))
                                   (until done-var-7
                                     (let* ((assertion (iteration-next-without-values-macro-helper
                                                        final-index-iterator token-var-8))
                                            (valid-9 (not (eq token-var-8 assertion))))
                                       (when valid-9
                                         (when (direction-is-relevant assertion)
                                           (when (gaf-asent-unify asent (gaf-formula assertion))
                                             (push assertion result))))
                                       (setf done-var-7 (not valid-9))))))
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
                                       (new-final-index-iterator final-index-spec :gaf (sense-truth :pos) nil))
                                 (let ((done-var-10 nil)
                                       (token-var-11 nil))
                                   (until done-var-10
                                     (let* ((assertion (iteration-next-without-values-macro-helper
                                                        final-index-iterator token-var-11))
                                            (valid-12 (not (eq token-var-11 assertion))))
                                       (when valid-12
                                         (when (direction-is-relevant assertion)
                                           (when (gaf-asent-unify asent (gaf-formula assertion))
                                             (push assertion result))))
                                       (setf done-var-10 (not valid-12))))))
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
                                  (new-final-index-iterator final-index-spec :gaf (sense-truth :pos) nil))
                            (let ((done-var-13 nil)
                                  (token-var-14 nil))
                              (until done-var-13
                                (let* ((assertion (iteration-next-without-values-macro-helper
                                                   final-index-iterator token-var-14))
                                       (valid-15 (not (eq token-var-14 assertion))))
                                  (when valid-15
                                    (when (direction-is-relevant assertion)
                                      (when (gaf-asent-unify asent (gaf-formula assertion))
                                        (push assertion result))))
                                  (setf done-var-13 (not valid-15))))))
                       (when final-index-iterator
                         (destroy-final-index-iterator final-index-iterator)))))
                 (setf done-var (not valid))))))))
      (:overlap
       ;; Likely iterates over overlapping GAF assertions from an overlap index.
       (dolist (assertion (missing-larkc 5137))
         (when (or (null (sense-truth :pos))
                   (assertion-has-truth assertion (sense-truth :pos)))
           (when (direction-is-relevant assertion)
             (when (gaf-asent-unify asent (gaf-formula assertion))
               (push assertion result))))))
      (otherwise
       ;; Likely signals an error for an unknown lookup index method.
       (missing-larkc 30370)))
    (when result
      (new-list-iterator result))))

;; (defun removal-lookup-neg-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-lookup-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-lookup-neg-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-lookup-expand-internal (asent sense) ...) -- active declareFunction, no body
;; (defun removal-pred-unbound-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-pred-unbound-iterator (asent) ...) -- active declareFunction, no body
;; (defun pred-unbound-pos-preference (asent bindable-vars strategic-context) ...) -- active declareFunction, no body
;; (defun formula-contains-indexed-term? (formula &optional seqvar-handling) ...) -- active declareFunction, no body

(defun formula-has-indexed-term-arg-p (formula &optional seqvar-handling)
  (sublisp-boolean (find-if #'indexed-term-p (formula-args formula seqvar-handling))))

;; (defun formula-has-fort-arg-p (formula &optional seqvar-handling) ...) -- active declareFunction, no body
;; (defun asent-has-fort-arg-p (asent &optional seqvar-handling) ...) -- active declareFunction, no body

(defun asent-has-indexed-term-arg-p (asent &optional seqvar-handling)
  (formula-has-indexed-term-arg-p asent seqvar-handling))

;; Orphan constants not referenced in method bodies:
;; $kw7$NEG (:neg), $kw8$GROSSLY_INCOMPLETE (:grossly-incomplete),
;; $kw9$INCOMPLETE (:incomplete) — likely used in stripped neg-related function bodies
;; $sym12$RELEVANT_MT_IS_EVERYTHING, $const13$EverythingPSC — with-all-mts pattern,
;;   likely used in removal-lookup-expand-internal or removal-lookup-neg-iterator
;; $kw18$GROSSLY_DISPREFERRED (:grossly-dispreferred),
;; $kw19$DISALLOWED (:disallowed) — likely used in pred-unbound-pos-preference
;; $sym21$FORT_P (fort-p) — likely used in formula-has-fort-arg-p

(toplevel
  (inference-removal-module :removal-lookup-pos
    (list :sense :pos
          :arity nil
          :required-pattern (cons :fort :anything)
          :cost 'removal-lookup-pos-cost
          :complete-pattern (list :test 'removal-completely-asserted-asent?)
          :input-extract-pattern (list :template (list :bind 'asent) (list :value 'asent))
          :output-generate-pattern (list :call 'removal-lookup-pos-iterator :input)
          :output-decode-pattern (list :template (list :bind 'assertion) (list :value 'assertion))
          :output-construct-pattern (list :call 'gaf-formula :input)
          :support-pattern (list (list :value 'assertion))
          :documentation "(<fort> . <whatever>)
using true assertions and GAF indexing in the KB"
          :example "(#$bordersOn #$UnitedStatesOfAmerica ?COUNTRY)
 (#$bordersOn #$UnitedStatesOfAmerica #$Canada)
 (#$resultIsa #$JuvenileFn #$JuvenileAnimal)")))

(toplevel
  (inference-removal-module :removal-lookup-neg
    (list :sense :neg
          :arity nil
          :required-pattern (cons :fort :anything)
          :cost 'removal-lookup-neg-cost
          :completeness-pattern (list :call 'removal-lookup-neg-completeness :input)
          :input-extract-pattern (list :template (list :bind 'asent) (list :value 'asent))
          :output-generate-pattern (list :call 'removal-lookup-neg-iterator :input)
          :output-decode-pattern (list :template (list :bind 'assertion) (list :value 'assertion))
          :output-construct-pattern (list :call 'gaf-formula :input)
          :support-pattern (list (list :value 'assertion))
          :documentation "(#$not (<predicate> . <whatever>))
using false assertions and GAF indexing in the KB")))

(toplevel
  (inference-removal-module :removal-pred-unbound
    (list :sense :pos
          :arity nil
          :required-pattern (list :and
                                  (cons (list :not :fort) :anything)
                                  (list :test 'formula-contains-indexed-term?))
          :cost 'removal-pred-unbound-cost
          :completeness :grossly-incomplete
          :input-extract-pattern (list :template (list :bind 'asent) (list :value 'asent))
          :output-generate-pattern (list :call 'removal-pred-unbound-iterator :input)
          :output-decode-pattern (list :template (list :bind 'assertion) (list :value 'assertion))
          :output-construct-pattern (list :call 'gaf-formula :input)
          :support-pattern (list (list :value 'assertion))
          :documentation "(<variable> ... <fort> ... )
using true assertions and GAF indexing on <fort>.
This is a last-resort if <variable> occurs elsewhere."
          :example "(?PREDICATE #$UnitedStatesOfAmerica #$Canada)")))

(toplevel
  (inference-preference-module :pred-unbound-pos
    (list :sense :pos
          :required-pattern (cons :not-fully-bound :anything)
          :preference 'pred-unbound-pos-preference)))
