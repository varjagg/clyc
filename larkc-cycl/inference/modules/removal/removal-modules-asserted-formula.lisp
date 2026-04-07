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

(defun removal-asserted-sentence-cost (asent)
  (let ((gaf-sentence (atomic-sentence-arg1 asent)))
    (if (fully-bound-p gaf-sentence)
        *hl-module-check-cost*
        (let* ((sub-literal (literal-atomic-sentence gaf-sentence))
               (sub-sense (literal-sense gaf-sentence))
               (cost 0))
          (do-formula-canonical-commutative-permutations (permuted-asent sub-literal
                                                          :penetrate-args? t)
            (incf cost (inference-num-gaf-lookup-index permuted-asent sub-sense)))
          cost))))

(defun removal-asserted-sentence-lookup-pos-cost (asent &optional sense)
  (declare (ignore sense))
  (removal-asserted-sentence-cost asent))

;; This is a full inline expansion of do-gaf-lookup-index, matching the Java directly.
;; The outer loop iterates over canonical-commutative-permutations of the sub-asent.
(defun removal-asserted-sentence-lookup-iterator (asent)
  (let* ((result nil)
         (sub-literal (atomic-sentence-arg1 asent))
         (sub-asent (literal-atomic-sentence sub-literal))
         (sub-sense (literal-sense sub-literal)))
    (do-formula-canonical-commutative-permutations (permuted-asent sub-asent
                                                    :penetrate-args? t)
      (let* ((l-index (inference-gaf-lookup-index permuted-asent sub-sense))
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
                                               (new-final-index-iterator final-index-spec :gaf (sense-truth sub-sense) nil))
                                         (let ((done-var-1 nil)
                                               (token-var-2 nil))
                                           (until done-var-1
                                             (let* ((assertion (iteration-next-without-values-macro-helper
                                                                final-index-iterator token-var-2))
                                                    (valid-3 (not (eq token-var-2 assertion))))
                                               (when valid-3
                                                 (when (direction-is-relevant assertion)
                                                   (multiple-value-bind (v-bindings gaf-asent unify-justification)
                                                       (gaf-asent-unify permuted-asent (gaf-formula assertion))
                                                     (declare (ignore gaf-asent unify-justification))
                                                     (when v-bindings
                                                       (push (list v-bindings assertion) result)))))
                                               (setf done-var-1 (not valid-3))))))
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
                                               (new-final-index-iterator final-index-spec :gaf (sense-truth sub-sense) nil))
                                         (let ((done-var-4 nil)
                                               (token-var-5 nil))
                                           (until done-var-4
                                             (let* ((assertion (iteration-next-without-values-macro-helper
                                                                final-index-iterator token-var-5))
                                                    (valid-6 (not (eq token-var-5 assertion))))
                                               (when valid-6
                                                 (when (direction-is-relevant assertion)
                                                   (multiple-value-bind (v-bindings gaf-asent unify-justification)
                                                       (gaf-asent-unify permuted-asent (gaf-formula assertion))
                                                     (declare (ignore gaf-asent unify-justification))
                                                     (when v-bindings
                                                       (push (list v-bindings assertion) result)))))
                                               (setf done-var-4 (not valid-6))))))
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
                                           (new-final-index-iterator final-index-spec :gaf (sense-truth sub-sense) nil))
                                     (let ((done-var-7 nil)
                                           (token-var-8 nil))
                                       (until done-var-7
                                         (let* ((assertion (iteration-next-without-values-macro-helper
                                                            final-index-iterator token-var-8))
                                                (valid-9 (not (eq token-var-8 assertion))))
                                           (when valid-9
                                             (when (direction-is-relevant assertion)
                                               (multiple-value-bind (v-bindings gaf-asent unify-justification)
                                                   (gaf-asent-unify permuted-asent (gaf-formula assertion))
                                                 (declare (ignore gaf-asent unify-justification))
                                                 (when v-bindings
                                                   (push (list v-bindings assertion) result)))))
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
                                           (new-final-index-iterator final-index-spec :gaf (sense-truth sub-sense) nil))
                                     (let ((done-var-10 nil)
                                           (token-var-11 nil))
                                       (until done-var-10
                                         (let* ((assertion (iteration-next-without-values-macro-helper
                                                            final-index-iterator token-var-11))
                                                (valid-12 (not (eq token-var-11 assertion))))
                                           (when valid-12
                                             (when (direction-is-relevant assertion)
                                               (multiple-value-bind (v-bindings gaf-asent unify-justification)
                                                   (gaf-asent-unify permuted-asent (gaf-formula assertion))
                                                 (declare (ignore gaf-asent unify-justification))
                                                 (when v-bindings
                                                   (push (list v-bindings assertion) result)))))
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
                                      (new-final-index-iterator final-index-spec :gaf (sense-truth sub-sense) nil))
                                (let ((done-var-13 nil)
                                      (token-var-14 nil))
                                  (until done-var-13
                                    (let* ((assertion (iteration-next-without-values-macro-helper
                                                       final-index-iterator token-var-14))
                                           (valid-15 (not (eq token-var-14 assertion))))
                                      (when valid-15
                                        (when (direction-is-relevant assertion)
                                          (multiple-value-bind (v-bindings gaf-asent unify-justification)
                                              (gaf-asent-unify permuted-asent (gaf-formula assertion))
                                            (declare (ignore gaf-asent unify-justification))
                                            (when v-bindings
                                              (push (list v-bindings assertion) result)))))
                                      (setf done-var-13 (not valid-15))))))
                           (when final-index-iterator
                             (destroy-final-index-iterator final-index-iterator)))))
                     (setf done-var (not valid))))))))
          (:overlap
           ;; Likely iterates over overlapping GAF assertions from an overlap index.
           (dolist (assertion (missing-larkc 5122))
             (when (or (null (sense-truth sub-sense))
                       (assertion-has-truth assertion (sense-truth sub-sense)))
               (when (direction-is-relevant assertion)
                 (multiple-value-bind (v-bindings gaf-asent unify-justification)
                     (gaf-asent-unify permuted-asent (gaf-formula assertion))
                   (declare (ignore gaf-asent unify-justification))
                   (when v-bindings
                     (push (list v-bindings assertion) result)))))))
          (otherwise
           ;; Likely signals an error for an unknown lookup index method.
           (missing-larkc 30356)))))
    (when result
      (new-list-iterator result))))

;; (defun removal-asserted-sentence-unbound-lookup-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-sentence-unbound-lookup-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-asserted-sentence-lookup-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-sentence-lookup-neg-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-sentence-lookup-neg-expand-internal (asent sense) ...) -- active declareFunction, no body
;; (defun removal-exactly-asserted-sentence-cost (asent) ...) -- active declareFunction, no body
;; (defun removal-exactly-asserted-sentence-lookup-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-exactly-asserted-sentence-lookup-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-exactly-asserted-sentence-unbound-lookup-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-exactly-asserted-sentence-unbound-lookup-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-exactly-asserted-sentence-lookup-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-exactly-asserted-sentence-lookup-neg-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-arg-pos-check-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-arg-pos-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-arg-check-cost (asent) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-arg-check (asent) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-arg-neg-check-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-arg-neg-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-term-arg-var-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-term-arg-var-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-term-var-var-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-term-var-var-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-var-arg-pred-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-predicate-var-arg-pred-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun make-term-formulas-support (term) ...) -- active declareFunction, no body
;; (defun inference-term-formulas-find (term formula) ...) -- active declareFunction, no body
;; (defun inference-term-formulas-gather (term) ...) -- active declareFunction, no body
;; (defun inference-term-formulas-count (term) ...) -- active declareFunction, no body
;; (defun removal-term-formulas-check-cost-pos (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-term-formulas-check-expand-pos (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-term-formulas-check (asent) ...) -- active declareFunction, no body
;; (defun removal-term-formulas-check-cost (asent) ...) -- active declareFunction, no body
;; (defun removal-term-formulas-check-cost-neg (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-term-formulas-check-expand-neg (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-term-formulas-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-term-formulas-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-sentence-cost (asent) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-term-index-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-gaf-check-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-gaf-check-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-gaf-check-cost (asent) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-gaf-check-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-gaf-check-neg-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-gaf-check-neg-expand-internal (asent sense term) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-gaf-iterate-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-gaf-iterate-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-gaf-iterate-expand-internal (asent sense term) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-arg-index-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-arg-index-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-unify-expand-internal (asent sense term) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-index-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-index-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-index-variable-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-sentences-index-variable-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-set-sentences-terms-index-cost (asent) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-set-sentences-arg1-bound-asent-cost (asent) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-set-sentences-index-variable-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-set-sentences-index-variable-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-set-sentences-gaf-check-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-set-sentences-gaf-check-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-set-sentences-gaf-check-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-set-sentences-gaf-check-neg-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-asserted-term-set-sentences-gaf-check-neg-expand-internal (asent sense term) ...) -- active declareFunction, no body

;; Variables

(defglobal *term-formulas-defining-mt* #$BaseKB)

;; Setup / toplevel forms

(toplevel
  (register-solely-specific-removal-module-predicate #$assertedSentence))

(toplevel
  (inference-removal-module :removal-asserted-sentence-lookup-pos
    (list :sense :pos
          :predicate #$assertedSentence
          :required-pattern `(,#$assertedSentence
                              (:or ((:test inference-predicate-p) . :anything)
                                   (,#$not ((:test inference-predicate-p) . :anything))))
          :cost 'removal-asserted-sentence-lookup-pos-cost
          :completeness :complete
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-asserted-sentence-lookup-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '((:value assertion))
          :documentation "(#$assertedSentence (<predicate> . <anything>))
    using only the KB GAF indexing and explicit assertions involving <predicate>"
          :example "(#$assertedSentence (#$genls #$Predicate ?WHAT))
    (#$assertedSentence (#$genls #$Predicate #$TruthFunction))")))

(toplevel
  (inference-removal-module :removal-asserted-sentence-unbound-lookup-pos
    (list :sense :pos
          :predicate #$assertedSentence
          :required-pattern `(,#$assertedSentence
                              (:or (:and ((:not :fort) . :anything)
                                         (:test asent-has-fort-arg-p))
                                   (,#$not (:and ((:not :fort) . :anything)
                                                 (:test asent-has-fort-arg-p)))))
          :cost 'removal-asserted-sentence-unbound-lookup-pos-cost
          :completeness :complete
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-asserted-sentence-unbound-lookup-iterator :input)
          :output-decode-pattern '(:template (:bind assertion) (:value assertion))
          :output-construct-pattern `(,#$assertedSentence (:call gaf-el-formula (:value assertion)))
          :documentation "(#$assertedSentence (<not fully-bound> ... <fort> ...))
    using only the KB GAF indexing and explicit assertions involving <fort>"
          :example "(#$assertedSentence (?PRED #$Predicate ?WHAT))")))

(toplevel
  (inference-removal-module :removal-asserted-sentence-lookup-neg
    (list :sense :neg
          :predicate #$assertedSentence
          :required-pattern `(,#$assertedSentence
                              (:or ((:test inference-predicate-p) . :fully-bound)
                                   (,#$not ((:test inference-predicate-p) . :fully-bound))))
          :cost 'removal-asserted-sentence-lookup-neg-cost
          :completeness :complete
          :expand 'removal-asserted-sentence-lookup-neg-expand
          :documentation "(#$not (#$assertedSentence (<predicate> . <fully-bound>)))
    using only the KB GAF indexing and explicit assertions involving <predicate>"
          :example "(#$not (#$assertedSentence (#$genls #$Predicate #$Thing)))")))

(toplevel
  (register-solely-specific-removal-module-predicate #$exactlyAssertedSentence))

(toplevel
  (inference-removal-module :removal-exactly-asserted-sentence-lookup-pos
    (list :sense :pos
          :predicate #$exactlyAssertedSentence
          :required-pattern `(,#$exactlyAssertedSentence
                              (:or ((:test inference-predicate-p) . :anything)
                                   (,#$not ((:test inference-predicate-p) . :anything))))
          :cost 'removal-exactly-asserted-sentence-lookup-pos-cost
          :completeness :complete
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-exactly-asserted-sentence-lookup-iterator :input)
          :output-decode-pattern '(:template (:bind assertion) (:value assertion))
          :output-construct-pattern `(,#$exactlyAssertedSentence (:call gaf-el-formula (:value assertion)))
          :support-pattern '((:value assertion))
          :documentation "(#$exactlyAssertedSentence (<predicate> . <anything>))
    using only the KB GAF indexing and explicit assertions involving <predicate>"
          :example "(#$exactlyAssertedSentence (#$genls #$Predicate ?WHAT))
    (#$exactlyAssertedSentence (#$genls #$Predicate #$TruthFunction))")))

(toplevel
  (inference-removal-module :removal-exactly-asserted-sentence-unbound-lookup-pos
    (list :sense :pos
          :predicate #$exactlyAssertedSentence
          :required-pattern `(,#$exactlyAssertedSentence
                              (:or (:and ((:not :fort) . :anything)
                                         (:test asent-has-fort-arg-p))
                                   (,#$not (:and ((:not :fort) . :anything)
                                                 (:test asent-has-fort-arg-p)))))
          :cost 'removal-exactly-asserted-sentence-unbound-lookup-pos-cost
          :completeness :complete
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-exactly-asserted-sentence-unbound-lookup-iterator :input)
          :output-decode-pattern '(:template (:bind assertion) (:value assertion))
          :output-construct-pattern `(,#$exactlyAssertedSentence (:call gaf-el-formula (:value assertion)))
          :documentation "(#$exactlyAssertedSentence (<not fully-bound> ... <fort> ...))
    using only the KB GAF indexing and explicit assertions involving <fort>"
          :example "(#$exactlyAssertedSentence (?PRED #$Predicate ?WHAT))")))

(toplevel
  (inference-removal-module :removal-exactly-asserted-sentence-lookup-neg
    (list :sense :neg
          :predicate #$exactlyAssertedSentence
          :required-pattern `(,#$exactlyAssertedSentence
                              (:or ((:test inference-predicate-p) . :fully-bound)
                                   (,#$not ((:test inference-predicate-p) . :fully-bound))))
          :cost 'removal-exactly-asserted-sentence-lookup-neg-cost
          :completeness :complete
          :expand 'removal-exactly-asserted-sentence-lookup-neg-expand
          :documentation "(#$not (#$exactlyAssertedSentence (<predicate> . <fully-bound>)))
    using only the KB GAF indexing and explicit assertions involving <predicate>"
          :example "(#$not (#$exactlyAssertedSentence (#$genls #$Predicate #$Thing)))")))

(toplevel
  (register-solely-specific-removal-module-predicate #$assertedPredicateArg))

(toplevel
  (inference-removal-module :removal-asserted-predicate-arg-prune
    (list :sense :pos
          :predicate #$assertedPredicateArg
          :required-pattern `(:or (,#$assertedPredicateArg (:and :fully-bound (:not :fort)) :anything :anything)
                                  (,#$assertedPredicateArg :anything (:and :fully-bound (:not :integer)) :anything)
                                  (,#$assertedPredicateArg :anything :anything (:and :fully-bound (:not :fort))))
          :cost-expression 0
          :completeness :complete
          :documentation "prune these cases :
    (#$assertedPredicateArg <non-fort>  <whatever>   <whatever>)
    (#$assertedPredicateArg <whatever> <non-integer> <whatever>)
    (#$assertedPredicateArg <whatever>  <whatever>   <non-fort>)"
          :example "(#$assertedPredicateArg (#$YearFn 2002) 1 #$isa)
    (#$assertedPredicateArg #$Predicate (#$PlusFn 1 1) #$genls)
    (#$assertedPredicateArg #$Predicate 1 \"genls\")
   ")))

(toplevel
  (inference-removal-module :removal-asserted-predicate-arg-pos-check
    (list :sense :pos
          :predicate #$assertedPredicateArg
          :required-pattern `(,#$assertedPredicateArg :fort :integer :fort)
          :cost 'removal-asserted-predicate-arg-pos-check-cost
          :completeness :complete
          :expand 'removal-asserted-predicate-arg-pos-check-expand
          :documentation "(#$assertedPredicateArg <fort> <integer> <fort>)
    using only the KB GAF indexing and explicit assertions"
          :example "(#$assertedPredicateArg #$Predicate 1 #$genls)")))

(toplevel
  (inference-removal-module :removal-asserted-predicate-arg-neg-check
    (list :sense :neg
          :predicate #$assertedPredicateArg
          :required-pattern `(,#$assertedPredicateArg :fort :integer :fort)
          :cost 'removal-asserted-predicate-arg-neg-check-cost
          :completeness :complete
          :expand 'removal-asserted-predicate-arg-neg-check-expand
          :documentation "(#$not (#$assertedPredicateArg <fort> <integer> <fort>))
     using only the KB GAF indexing and explicit assertions"
          :example "(#$not (#$assertedPredicateArg #$and 1 #$arity))")))

(toplevel
  (inference-removal-module :removal-asserted-predicate-term-arg-var
    (list :sense :pos
          :predicate #$assertedPredicateArg
          :required-pattern `(,#$assertedPredicateArg :fort :integer (:not :fort))
          :cost 'removal-asserted-predicate-term-arg-var-cost
          :completeness :complete
          :expand 'removal-asserted-predicate-term-arg-var-expand
          :documentation "(#$assertedPredicateArg <fort> <integer> <non-fort>)
    using only the KB GAF indexing and explicit assertions"
          :example "(#$assertedPredicateArg #$Predicate 1 ?WHAT)")))

(toplevel
  (inference-removal-module :removal-asserted-predicate-term-var-var
    (list :sense :pos
          :predicate #$assertedPredicateArg
          :required-pattern `(,#$assertedPredicateArg :fort (:not :integer) :anything)
          :cost 'removal-asserted-predicate-term-var-var-cost
          :completeness :complete
          :expand 'removal-asserted-predicate-term-var-var-expand
          :documentation "(#$assertedPredicateArg <fort> <non-integer> <whatever>)
    using only the KB GAF indexing and explicit assertions"
          :example "(#$assertedPredicateArg #$Predicate ?ARG ?PRED)")))

(toplevel
  (inference-removal-module :removal-asserted-predicate-var-arg-pred
    (list :sense :pos
          :predicate #$assertedPredicateArg
          :required-pattern `(,#$assertedPredicateArg (:not :fort) :integer :fort)
          :cost 'removal-asserted-predicate-var-arg-pred-cost
          :completeness :complete
          :expand 'removal-asserted-predicate-var-arg-pred-expand
          :documentation "(#$assertedPredicateArg <non-fort> <integer> <fort>)
    using only the KB GAF indexing and explicit assertions"
          :example "(#$assertedPredicateArg ?X 1 #$expansion)")))

(toplevel
  (register-solely-specific-removal-module-predicate #$termFormulas))

(toplevel
  (declare-defglobal '*term-formulas-defining-mt*))

(toplevel
  (note-mt-var '*term-formulas-defining-mt* #$termFormulas))

(toplevel
  (inference-removal-module :removal-term-formulas-check-pos
    (list :sense :pos
          :predicate #$termFormulas
          :required-pattern `(,#$termFormulas :fully-bound (:and :fully-bound (:test possibly-quoted-cycl-formula-p)))
          :cost 'removal-term-formulas-check-cost-pos
          :completeness :complete
          :expand 'removal-term-formulas-check-expand-pos
          :documentation "(#$termFormulas <fully-bound> <fully-bound>)"
          :example "(#$termFormulas #$Predicate (#$genls #$Predicate #$TruthFunction))")))

(toplevel
  (inference-removal-module :removal-term-formulas-check-neg
    (list :sense :neg
          :predicate #$termFormulas
          :required-pattern `(,#$termFormulas :fully-bound (:and :fully-bound (:test possibly-quoted-cycl-formula-p)))
          :cost 'removal-term-formulas-check-cost-neg
          :completeness :complete
          :expand 'removal-term-formulas-check-expand-neg
          :documentation "(#$not (#$termFormulas <fully-bound> <fully-bound>))"
          :example "(#$not (#$termFormulas #$Predicate (#$genls #$Quantifier #$TruthFunction)))")))

(toplevel
  (inference-removal-module :removal-term-formulas-unify
    (list :sense :pos
          :predicate #$termFormulas
          :required-pattern `(,#$termFormulas :not-fully-bound (:and :fully-bound (:test possibly-quoted-cycl-formula-p)))
          :cost 'removal-term-formulas-unify-cost
          :completeness :complete
          :expand 'removal-term-formulas-unify-expand
          :documentation "(#$termFormulas <not-fully-bound> <fully-bound>)"
          :example "(#$termFormulas ?TERM (#$genls #$Predicate #$TruthFunction))")))

(toplevel
  (register-solely-specific-removal-module-predicate #$assertedTermSentences))

(toplevel
  (inference-removal-module :removal-asserted-term-sentences-gaf-check-pos
    (list :sense :pos
          :predicate #$assertedTermSentences
          :required-pattern `(,#$assertedTermSentences :fully-bound ((:test inference-predicate-p) . :fully-bound))
          :cost 'removal-asserted-term-sentences-gaf-check-pos-cost
          :completeness :complete
          :expand 'removal-asserted-term-sentences-gaf-check-pos-expand
          :documentation "(#$assertedTermSentences <fully-bound> (<predicate> . <fully-bound>))
     using only the KB GAF indexing and explicit assertions involving <predicate>"
          :example "(#$assertedTermSentences #$Predicate (#$genls #$Predicate #$TruthFunction)))")))

(toplevel
  (inference-removal-module :removal-asserted-term-sentences-gaf-check-neg
    (list :sense :neg
          :predicate #$assertedTermSentences
          :required-pattern `(,#$assertedTermSentences :fully-bound ((:test inference-predicate-p) . :fully-bound))
          :cost 'removal-asserted-term-sentences-gaf-check-neg-cost
          :completeness :complete
          :expand 'removal-asserted-term-sentences-gaf-check-neg-expand
          :documentation "(#$not (#$assertedTermSentences <fully-bound> (<predicate> . <fully-bound>)))
    using only the KB GAF indexing and explicit assertions involving <predicate>"
          :example "(#$not (#$assertedTermSentences #$Quantifier (#$genls #$Predicate #$TruthFunction)))
    (#$not (#$assertedTermSentences #$Predicate  (#$genls #$TruthFunction #$Predicate)))
    ")))

(toplevel
  (inference-removal-module :removal-asserted-term-sentences-gaf-iterate
    (list :sense :pos
          :predicate #$assertedTermSentences
          :required-pattern `(,#$assertedTermSentences :not-fully-bound ((:test inference-predicate-p) . :fully-bound))
          :cost 'removal-asserted-term-sentences-gaf-iterate-cost
          :completeness :complete
          :expand 'removal-asserted-term-sentences-gaf-iterate-expand
          :documentation "(#$assertedTermSentences <not fully-bound> (<predicate> . <fully-bound>))
     using only the KB GAF indexing and explicit assertions involving <predicate>"
          :example "(#$assertedTermSentences ?TERM (#$genls #$Predicate #$TruthFunction)))")))

(toplevel
  (inference-removal-module :removal-asserted-term-sentences-arg-index-unify
    (list :sense :pos
          :predicate #$assertedTermSentences
          :required-pattern `(,#$assertedTermSentences :fort ((:test inference-predicate-p) . :not-fully-bound))
          :cost 'removal-asserted-term-sentences-arg-index-unify-cost
          :completeness :complete
          :expand 'removal-asserted-term-sentences-arg-index-unify-expand
          :documentation "(#$assertedTermSentences <fort> (<predicate> . <not fully-bound>))
    using only the KB GAF indexing and explicit assertions involving <predicate> and <fort>"
          :example "(#$assertedTermSentences #$Predicate (#$genls #$Predicate ?GENL)))
    (#$assertedTermSentences #$Predicate (#$genls ?SPEC ?GENL))
    (#$assertedTermSentences #$Predicate (#$genls ?SPEC #$TruthFunction))
    ")))

(toplevel
  (inference-removal-module :removal-asserted-term-sentences-index-unify
    (list :sense :pos
          :predicate #$assertedTermSentences
          :required-pattern `(,#$assertedTermSentences :fort (:and ((:not :fort) . :anything)
                                                                   (:test asent-has-fort-arg-p)))
          :cost 'removal-asserted-term-sentences-index-unify-cost
          :completeness :complete
          :expand 'removal-asserted-term-sentences-index-unify-expand
          :documentation "(#$assertedTermSentences <fort> (<not fully-bound> ... <fort> ...))
    using only the KB GAF indexing and explicit assertions involving the two FORTs"
          :example "(#$assertedTermSentences #$Predicate (?PRED #$Predicate ?TERM))
    (#$assertedTermSentences #$Predicate (?PRED ?TERM #$Collection))
    (#$assertedTermSentences #$Predicate (?PRED ?TERM #$TruthFunction))
    ")))

(toplevel
  (inference-removal-module :removal-asserted-term-sentences-index-variable
    (list :sense :pos
          :predicate #$assertedTermSentences
          :required-pattern `(,#$assertedTermSentences :fort :variable)
          :cost 'removal-asserted-term-sentences-index-variable-cost
          :completeness :complete
          :expand 'removal-asserted-term-sentences-index-variable-expand
          :documentation "(#$assertedTermSentences <fort> <variable>)
    using only the KB GAF indexing and explicit assertions involving <fort>"
          :example "(#$assertedTermSentences #$Predicate ?SENTENCE)")))

(toplevel
  (register-solely-specific-removal-module-predicate #$assertedTermSetSentences))

(toplevel
  (inference-removal-module :removal-asserted-term-set-sentences-index-variable
    (list :sense :pos
          :predicate #$assertedTermSetSentences
          :required-pattern `(,#$assertedTermSetSentences :fully-bound :variable)
          :cost 'removal-asserted-term-set-sentences-index-variable-cost
          :completeness :complete
          :expand 'removal-asserted-term-set-sentences-index-variable-expand
          :documentation "(#$assertedTermSetSentences <fully-dound> <variable>)
    using the overlap indexing and explicit assertions involving the terms in <fully-bound>."
          :example "(#$assertedTermSetSentences (#$TheSet #$Dog #$Mammal) ?SENTENCE)")))

(toplevel
  (inference-removal-module :removal-asserted-term-set-sentences-gaf-check-pos
    (list :sense :pos
          :predicate #$assertedTermSetSentences
          :required-pattern `(,#$assertedTermSetSentences :fully-bound ((:test inference-predicate-p) . :fully-bound))
          :cost 'removal-asserted-term-set-sentences-gaf-check-pos-cost
          :completeness :complete
          :expand 'removal-asserted-term-set-sentences-gaf-check-pos-expand
          :documentation "(#$assertedTermSetSentences <fully-dound> ([predicate] . [fully-bound]))
    using only the KB GAF indexing and explicit assertions involving the terms in <fully-bound>."
          :example "(#$assertedTermSetSentences (#$TheSet #$Dog #$Mammal) (#$genls #$Dog #$Mammal))")))

(toplevel
  (inference-removal-module :removal-asserted-term-set-sentences-gaf-check-neg
    (list :sense :neg
          :predicate #$assertedTermSetSentences
          :required-pattern `(,#$assertedTermSetSentences :fully-bound ((:test inference-predicate-p) . :fully-bound))
          :cost 'removal-asserted-term-set-sentences-gaf-check-neg-cost
          :completeness :complete
          :expand 'removal-asserted-term-set-sentences-gaf-check-neg-expand
          :documentation "(#$not (#$assertedTermSetSentences <fully-dound> ([predicate] . [fully-bound])))
    using only the overlap indexing and explicit assertions involving the terms in <fully-bound>."
          :example "(#$not (#$assertedTermSetSentences (#$TheSet #$Predicate) (#$isa #$Collection #$Thing)))
    (#$not (#$assertedTermSetSentences (#$TheSet #$Predicate #$arity) (#$arity #$Predicate 2))) ")))
