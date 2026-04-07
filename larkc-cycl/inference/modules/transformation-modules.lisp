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

;; Functions in declareFunction order:

;; (defun additional-genls-supports (genls mt) ...) -- active declareFunction, no body
;; (defun additional-genl-mt-supports (genl-mt mt) ...) -- active declareFunction, no body
;; (defun additional-genlpreds-supports (genlpreds predicate) ...) -- active declareFunction, no body
;; (defun additional-negationpreds-supports (negation-preds predicate) ...) -- active declareFunction, no body
;; (defun additional-asymmetry-supports (predicate) ...) -- active declareFunction, no body

(defun additional-predicate-commutativity-supports (predicate)
  (cond ((inference-symmetric-predicate? predicate)
         (additional-isa-supports predicate #$SymmetricBinaryPredicate))
        ((inference-commutative-predicate-p predicate)
         (additional-isa-supports predicate #$CommutativePredicate))
        ((inference-partially-commutative-predicate-p predicate)
         (append (additional-isa-supports predicate #$PartiallyCommutativePredicate)
                 ;; Likely returns commutativeInArgs supports for the predicate
                 (missing-larkc 32752)))
        (t
         (error "Unexpected commutative predicate ~s" predicate))))

;; (defun transformation-gaf-truth-known (asent) ...) -- active declareFunction, no body
;; (defun gaf-truth-known (asent) ...) -- active declareFunction, no body

(defparameter *transformation-gaf-truth-known-disabled* t
  "[Cyc] Temporary control variable; controls whether or not we bother to try to call gaf-truth-known.")

(defun modus-tollens-transformation-module-p (object)
  (and (transformation-module-p object)
       (eq :neg (hl-module-sense object))))

(defun modus-tollens-transformation-proof-p (object)
  (and (transformation-proof-p object)
       (modus-tollens-transformation-module-p (content-proof-hl-module object))))

;; Reconstructed from Internal Constants:
;; $list18 = ((direction-var) &body body) -- arglist
;; $sym19$DO_LIST = DO-LIST
;; $list20 = ((relevant-directions)) -- the do-list list-form
;; Expansion visible in trans-predicate-rule-select-int-internal: iterates over (relevant-directions)
(defmacro do-transformation-relevant-directions ((direction-var) &body body)
  `(dolist (,direction-var (relevant-directions))
     ,@body))

;; Reconstructed from Internal Constants:
;; $list21 = ((rule-asent-var rule sense &key predicate) &body body) -- arglist
;; $sym25$PREDICATE_VAR = gensym PREDICATE-VAR
;; $sym30$RULE_VAR = gensym RULE-VAR
;; $sym26$CLET = CLET (= let)
;; $sym28$PWHEN = PWHEN (= when)
;; $sym29$ATOMIC_SENTENCE_PREDICATE = ATOMIC-SENTENCE-PREDICATE
;; $sym31$RULE_RELEVANT_TO_PROOF = RULE-RELEVANT-TO-PROOF
;; $sym32$DO_ASSERTION_LITERALS = DO-ASSERTION-LITERALS
;; $kw33$SENSE = :SENSE
;; Expansion visible in trans-predicate-rule-filter and trans-predicate-expand:
;;   binds predicate-var, rule-var, checks rule-relevant-to-proof,
;;   gets assertion-cnf, iterates literals by sense, optionally filters by predicate
(defmacro do-transformation-rule-literals ((rule-asent-var rule sense &key predicate) &body body)
  (with-temp-vars (predicate-var rule-var)
    `(let ((,predicate-var ,predicate)
           (,rule-var ,rule))
       (when (rule-relevant-to-proof ,rule-var)
         (do-assertion-literals (,rule-asent-var ,rule-var :sense ,sense)
           (when (eq ,predicate-var (atomic-sentence-predicate ,rule-asent-var))
             ,@body))))))

;; Reconstructed from Internal Constants:
;; $list34 = ((rule-asent-var rule-var predicate sense) &body body) -- arglist
;; $sym35$DIRECTION_VAR = gensym DIRECTION-VAR
;; $sym36$SENSE_VAR = gensym SENSE-VAR
;; $sym37$PREDICATE_VAR = gensym PREDICATE-VAR
;; $sym38$DO_TRANSFORMATION_RELEVANT_DIRECTIONS = DO-TRANSFORMATION-RELEVANT-DIRECTIONS
;; $sym39$DO_PREDICATE_RULE_INDEX = DO-PREDICATE-RULE-INDEX
;; $kw40$DIRECTION = :DIRECTION
;; Expansion visible in trans-predicate-rule-select-int-internal and
;;   trans-predicate-commutativity-rule-select:
;;   iterates over relevant-directions, then do-predicate-rule-index for each direction
(defmacro do-transformation-predicate-rule-index ((rule-asent-var rule-var predicate sense) &body body)
  (with-temp-vars (direction-var sense-var predicate-var)
    `(let ((,sense-var ,sense)
           (,predicate-var ,predicate))
       (do-transformation-relevant-directions (,direction-var)
         (do-predicate-rule-index (,rule-var ,predicate-var
                                   :sense ,sense-var
                                   :direction ,direction-var)
           ,@body)))))

(defun new-selected-rules ()
  (new-set-contents 0 #'eq))

(defun add-selected-rule (rule selected-rules)
  (set-contents-add rule selected-rules))

(defun finalize-selected-rules (selected-rules)
  (let ((rules (set-contents-element-list selected-rules)))
    (sort-rules-via-current-inference-rule-preference rules)))

(defun sort-rules-via-current-inference-rule-preference (rules)
  (if (current-controlling-inference)
      (sort rules #'current-inference-rule-preference->)
      (sort rules #'transformation-rule-utility->)))

(defun current-inference-rule-preference-> (rule1 rule2)
  ;; Likely compares inference rule preference scores for sorting
  (missing-larkc 36255))

(defun trans-predicate-pos-required (asent)
  (trans-predicate-required asent))

(defun trans-predicate-pos-cost (asent)
  (trans-predicate-cost asent :pos))

(defun trans-predicate-pos-rule-select (asent)
  (trans-predicate-rule-select asent :pos))

(defun trans-predicate-pos-rule-filter (asent rule)
  (trans-predicate-rule-filter asent :pos rule))

(defun trans-predicate-pos-expand (asent rule)
  (trans-predicate-expand asent :pos rule))

;; (defun trans-predicate-neg-required (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-neg-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-neg-expand (asent rule) ...) -- active declareFunction, no body

(defun trans-predicate-required (asent)
  (not (and *unique-inference-result-bindings*
            (fully-bound-p asent)
            ;; Likely checks if the GAF truth is already known
            (missing-larkc 32889))))

(defun trans-predicate-cost (asent sense)
  (relevant-num-predicate-rule-index (atomic-sentence-predicate asent) sense))

(defun trans-predicate-rule-select (asent sense)
  (copy-list (trans-predicate-rule-select-int (atomic-sentence-predicate asent) sense)))

(defun-memoized trans-predicate-rule-select-int (predicate sense) (:test eq)
  (let ((rules (new-selected-rules)))
    (do-transformation-relevant-directions (direction)
      (do-predicate-rule-index (rule predicate :sense sense :direction direction)
        (setf rules (add-selected-rule rule rules))))
    (finalize-selected-rules rules)))

(defun trans-predicate-rule-filter (asent sense rule)
  (let ((predicate (atomic-sentence-predicate asent)))
    (do-transformation-rule-literals (examine rule sense :predicate predicate)
      (when (unify-possible asent examine)
        (return-from trans-predicate-rule-filter t))))
  nil)

(defun trans-predicate-expand (asent sense rule)
  (let ((predicate (atomic-sentence-predicate asent)))
    (do-transformation-rule-literals (examine rule sense :predicate predicate)
      (let ((v-bindings (transformation-asent-unify asent examine)))
        (when v-bindings
          (transformation-add-node rule examine sense v-bindings)))))
  nil)

(defun trans-predicate-genlpreds-pos-required (asent)
  (trans-predicate-genlpreds-required asent))

(defun trans-predicate-genlpreds-pos-cost (asent)
  (let ((predicate (atomic-sentence-predicate asent)))
    (multiple-value-bind (spec-preds cost)
        (inference-all-proper-spec-predicates-with-axiom-index predicate :pos)
      (declare (ignore spec-preds))
      cost)))

(defun trans-predicate-genlpreds-pos-rule-select (asent)
  (copy-list (trans-predicate-genlpreds-pos-rule-select-int (atomic-sentence-predicate asent))))

(defun-memoized trans-predicate-genlpreds-pos-rule-select-int (predicate) (:test eq)
  (let ((rules (new-selected-rules)))
    (dolist (index-pred (inference-all-proper-spec-predicates-with-axiom-index predicate :pos))
      (do-transformation-relevant-directions (direction)
        (do-predicate-rule-index (rule index-pred :sense :pos :direction direction)
          (setf rules (add-selected-rule rule rules)))))
    (finalize-selected-rules rules)))

;; (defun trans-predicate-genlpreds-neg-required (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-genlpreds-neg-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-genlpreds-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-genlpreds-pos-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-genlpreds-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-genlpreds-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-genlpreds-neg-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-genlpreds-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-genlpreds-neg-expand (asent rule) ...) -- active declareFunction, no body

(defun trans-predicate-genlpreds-required (asent)
  (not (and *unique-inference-result-bindings*
            (fully-bound-p asent)
            ;; Likely checks if the GAF truth is already known
            (missing-larkc 32890))))

;; (defun inference-proper-genl-predicate? (predicate genl-predicate &optional mt) ...) -- active declareFunction, no body
;; (defun trans-predicate-negationpreds-neg-required (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-negationpreds-neg-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-negationpreds-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-negationpreds-neg-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-negationpreds-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-negationpreds-neg-expand (asent rule) ...) -- active declareFunction, no body

(defun trans-predicate-commutativity-cost (asent sense)
  (let ((cost 0)
        (source-formula-var asent))
    (if (el-binary-formula-p source-formula-var)
        (let ((permuted-asent (symmetric-asent source-formula-var)))
          (setf cost (+ cost (trans-predicate-cost permuted-asent sense))))
        ;; Likely calls all-permutations or similar for commutative predicates
        (dolist (permuted-asent (missing-larkc 29753))
          (unless (equal permuted-asent source-formula-var)
            (setf cost (+ cost (trans-predicate-cost permuted-asent sense))))))
    cost))

(defun trans-predicate-commutativity-rule-select (asent sense)
  (let ((predicate (atomic-sentence-predicate asent))
        (rules (new-selected-rules)))
    (do-transformation-relevant-directions (direction)
      (do-predicate-rule-index (rule predicate :sense sense :direction direction)
        (setf rules (add-selected-rule rule rules))))
    (finalize-selected-rules rules)))

(defun trans-predicate-commutativity-expand-int (asent sense rule)
  (let ((predicate (atomic-sentence-predicate asent))
        (source-formula-var asent))
    (if (el-binary-formula-p source-formula-var)
        (let ((permuted-asent (symmetric-asent source-formula-var)))
          (do-transformation-rule-literals (examine rule sense :predicate predicate)
            (let ((v-bindings (transformation-asent-unify permuted-asent examine)))
              (when v-bindings
                (return-from trans-predicate-commutativity-expand-int
                  (values v-bindings examine predicate))))))
        ;; Likely calls all-permutations or similar for commutative predicates
        (dolist (permuted-asent (missing-larkc 29754))
          (unless (equal permuted-asent source-formula-var)
            (do-transformation-rule-literals (examine rule sense :predicate predicate)
              (let ((v-bindings (transformation-asent-unify permuted-asent examine)))
                (when v-bindings
                  (return-from trans-predicate-commutativity-expand-int
                    (values v-bindings examine predicate)))))))))
  (values nil nil nil))

(defun trans-predicate-commutativity-rule-filter (asent sense rule)
  (multiple-value-bind (v-bindings examine predicate)
      (trans-predicate-commutativity-expand-int asent sense rule)
    (declare (ignore examine predicate))
    (if v-bindings t nil)))

(defun trans-predicate-commutativity-expand (asent sense rule)
  (multiple-value-bind (v-bindings examine predicate)
      (trans-predicate-commutativity-expand-int asent sense rule)
    (when v-bindings
      (transformation-add-node rule examine sense v-bindings
                               (additional-predicate-commutativity-supports predicate))))
  nil)

(defun trans-predicate-symmetry-pos-cost (asent)
  (trans-predicate-commutativity-cost asent :pos))

(defun trans-predicate-symmetry-pos-rule-select (asent)
  (trans-predicate-commutativity-rule-select asent :pos))

(defun trans-predicate-symmetry-pos-rule-filter (asent rule)
  (trans-predicate-commutativity-rule-filter asent :pos rule))

(defun trans-predicate-symmetry-pos-expand (asent rule)
  (trans-predicate-commutativity-expand asent :pos rule))

;; (defun trans-predicate-symmetry-neg-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-symmetry-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-symmetry-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-symmetry-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-commutative-pos-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-commutative-neg-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-commutative-pos-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-commutative-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-commutative-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-commutative-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-commutative-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-commutative-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-partially-commutative-pos-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-partially-commutative-neg-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-partially-commutative-pos-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-partially-commutative-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-partially-commutative-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-partially-commutative-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-partially-commutative-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-partially-commutative-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-asymmetry-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-asymmetry-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-predicate-asymmetry-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-asymmetry-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-predicate-asymmetry-expand (asent rule) ...) -- active declareFunction, no body

(deflexical *unbound-predicate-transformation-required-modules*
  '(:trans-unbound-predicate-pos :trans-unbound-predicate-neg)
  "[Cyc] Modules which require :allow-unbound-predicate-transformation? to be t to be used")

(defun trans-unbound-predicate-module-p (hl-module)
  (let ((name (hl-module-name hl-module)))
    (member-eq? name *unbound-predicate-transformation-required-modules*)))

;; (defun module-requires-unbound-predicate-transformation? (hl-module) ...) -- active declareFunction, no body

(defun trans-unbound-predicate-pos-required (asent)
  (trans-unbound-predicate-required asent))

(defun trans-unbound-predicate-pos-cost (asent)
  (declare (ignore asent))
  (trans-unbound-predicate-cost :pos))

;; (defun trans-unbound-predicate-neg-required (asent) ...) -- active declareFunction, no body
;; (defun trans-unbound-predicate-neg-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-unbound-predicate-pos-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-unbound-predicate-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-unbound-predicate-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-unbound-predicate-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-unbound-predicate-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-unbound-predicate-neg-expand (asent rule) ...) -- active declareFunction, no body

(defun trans-unbound-predicate-required (asent)
  (and *unbound-rule-backchain-enabled*
       (not (and *unique-inference-result-bindings*
                 (fully-bound-p asent)
                 ;; Likely checks if the GAF truth is already known
                 (missing-larkc 32891)))))

(defun trans-unbound-predicate-cost (sense)
  (relevant-num-unbound-rule-index sense))

;; (defun trans-unbound-predicate-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-unbound-predicate-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-unbound-predicate-expand (asent sense rule) ...) -- active declareFunction, no body

(deflexical *hl-predicate-transformation-required-modules*
  '(:trans-isa-pos :trans-isa-neg :trans-genls-pos :trans-genls-neg
    :trans-genl-mt-pos :trans-genl-mt-neg)
  "[Cyc] Transformation modules which require :allow-hl-predicate-transformation? to be t to be used. Exception is trans-isa-pos - which can be used when #$collectionBackchainEncouraged.")

;; (defun module-requires-hl-predicate-transformation? (hl-module) ...) -- active declareFunction, no body
;; (defun trans-isa-pos-required (asent) ...) -- active declareFunction, no body
;; (defun trans-isa-neg-required (asent) ...) -- active declareFunction, no body
;; (defun trans-isa-pos-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-isa-neg-cost (asent) ...) -- active declareFunction, no body
;; (defun inference-memoized-all-specs-internal (collection &optional mt) ...) -- active declareFunction, no body
;; (defun inference-memoized-all-specs (collection &optional mt) ...) -- active declareFunction, no body
;; (defun trans-isa-pos-rule-select-count-internal (collection mt) ...) -- active declareFunction, no body
;; (defun trans-isa-pos-rule-select-count (collection mt) ...) -- active declareFunction, no body
;; (defun trans-isa-pos-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-isa-pos-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-isa-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-isa-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-isa-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-isa-neg-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-isa-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-isa-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genls-pos-required (asent) ...) -- active declareFunction, no body
;; (defun trans-genls-neg-required (asent) ...) -- active declareFunction, no body
;; (defun trans-genls-pos-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-genls-neg-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-genls-pos-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-genls-pos-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genls-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genls-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genls-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-genls-neg-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genls-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genls-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-pos-required (asent) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-neg-required (asent) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-pos-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-neg-cost (asent) ...) -- active declareFunction, no body
;; (defun inference-memoized-all-spec-mts-internal (mt &optional mt-mt) ...) -- active declareFunction, no body
;; (defun inference-memoized-all-spec-mts (mt &optional mt-mt) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-pos-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-pos-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-neg-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-genl-mt-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun trans-abnormal-cost (asent) ...) -- active declareFunction, no body
;; (defun trans-abnormal-rule-select (asent) ...) -- active declareFunction, no body
;; (defun trans-abnormal-expand-int (asent rule) ...) -- active declareFunction, no body
;; (defun trans-abnormal-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun trans-abnormal-expand (asent rule) ...) -- active declareFunction, no body
;; (defun transformation-abduction-to-specs-required (asent &optional mt) ...) -- active declareFunction, no body
;; (defun find-genls-definitional-rules () ...) -- active declareFunction, no body
;; (defun transformation-abduction-to-specs-rule-select (asent) ...) -- active declareFunction, no body
;; (defun transformation-abduction-to-specs-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun transformation-abduction-to-specs-expand (asent rule) ...) -- active declareFunction, no body

(defparameter *genls-definitional-sentence*
  (list #$implies
        (list #$and
              (list #$isa '?obj '?subset)
              (list #$genls '?subset '?superset))
        (list #$isa '?obj '?superset)))

(defparameter *genls-definitional-rules* nil)

;; Setup phase (toplevel forms)

(toplevel
  (inference-transformation-module :trans-predicate-pos
    (list :sense :pos
          :required-pattern (cons :fort :anything)
          :required 'trans-predicate-pos-required
          :cost 'trans-predicate-pos-cost
          :rule-select 'trans-predicate-pos-rule-select
          :rule-filter 'trans-predicate-pos-rule-filter
          :expand 'trans-predicate-pos-expand
          :documentation "(<predicate> . <whatever>)
where <predicate> is a FORT
from a rule concluding to <predicate>
using the predicate rule indexing in the KB"
          :example "(#$likesAsFriend #$AbrahamLincoln ?WHO)
from a rule concluding to #$likesAsFriend")))

(toplevel
  (inference-transformation-module :trans-predicate-neg
    (list :sense :neg
          :required-pattern (cons :fort :anything)
          :required 'trans-predicate-neg-required
          :cost 'trans-predicate-neg-cost
          :rule-select 'trans-predicate-neg-rule-select
          :rule-filter 'trans-predicate-neg-rule-filter
          :expand 'trans-predicate-neg-expand
          :documentation "(#$not (<predicate> . <whatever>))
where <predicate> is a FORT
from a rule concluding from <predicate>
using the predicate rule indexing in the KB"
          :example "(#$not (#$likesAsFriend #$AbrahamLincoln ?WHO))
from a rule concluding from #$likesAsFriend")))

(toplevel (note-memoized-function 'trans-predicate-rule-select-int))
(toplevel (note-memoized-function 'trans-predicate-genlpreds-pos-rule-select-int))

(toplevel
  (inference-transformation-module :trans-predicate-genlpreds-pos
    (list :sense :pos
          :required-pattern (cons (list :and :fort (list :test 'inference-some-spec-pred-or-inverse?)) :anything)
          :required 'trans-predicate-genlpreds-pos-required
          :cost 'trans-predicate-genlpreds-pos-cost
          :rule-select 'trans-predicate-genlpreds-pos-rule-select
          :rule-filter 'trans-predicate-genlpreds-pos-rule-filter
          :expand 'trans-predicate-genlpreds-pos-expand
          :documentation "(<predicate> . <whatever>)
where <predicate> is a FORT with some spec-preds
from a rule concluding to a spec-pred of <predicate>
using the predicate rule indexing in the KB"
          :example "(#$acquaintedWith #$AbrahamLincoln ?WHO)
from (#$genlPreds #$likesAsFriend #$acquaintedWith)
and a rule concluding to #$likesAsFriend")))

(toplevel
  (inference-transformation-module :trans-predicate-genlpreds-neg
    (list :sense :neg
          :required-pattern (cons (list :and :fort (list :test 'inference-some-genl-pred-or-inverse?)) :anything)
          :required 'trans-predicate-genlpreds-neg-required
          :cost 'trans-predicate-genlpreds-neg-cost
          :rule-select 'trans-predicate-genlpreds-neg-rule-select
          :rule-filter 'trans-predicate-genlpreds-neg-rule-filter
          :expand 'trans-predicate-genlpreds-neg-expand
          :documentation "(#$not (<predicate> . <whatever>))
where <predicate> is a FORT with some genl-preds
from a rule concluding from a genl-pred of <predicate>
using the predicate rule indexing in the KB"
          :example "(#$not (#$likesAsFriend #$AbrahamLincoln ?WHO))
from (#$genlPreds #$likesAsFriend #$acquaintedWith)
and a rule concluding from #$acquaintedWith")))

(toplevel
  (inference-transformation-module :trans-predicate-negationpreds-neg
    (list :sense :neg
          :required-pattern (cons (list :and :fort (list :test 'inference-some-negation-pred-or-inverse?)) :anything)
          :required 'trans-predicate-negationpreds-neg-required
          :cost 'trans-predicate-negationpreds-neg-cost
          :rule-select 'trans-predicate-negationpreds-neg-rule-select
          :rule-filter 'trans-predicate-negationpreds-neg-rule-filter
          :expand 'trans-predicate-negationpreds-neg-expand
          :documentation "(#$not (<predicate> . <whatever>))
where <predicate> is a FORT with some negationPreds,
either asserted or inferrable via genlPreds,
from a rule concluding to a negationPred of <predicate>
using the predicate rule indexing in the KB"
          :example "(#$not (#$likesAsFriend #$AbrahamLincoln ?WHO))
from (#$negationPreds #$likesAsFriend #$hates)
and a rule concluding to #$hates")))

(toplevel
  (inference-transformation-module :trans-predicate-symmetry-pos
    (list :sense :pos
          :required-pattern (list :and
                                  (list :fort :anything :anything)
                                  (cons (list :test 'inference-symmetric-predicate?) :anything))
          :cost 'trans-predicate-symmetry-pos-cost
          :rule-select 'trans-predicate-symmetry-pos-rule-select
          :rule-filter 'trans-predicate-symmetry-pos-rule-filter
          :expand 'trans-predicate-symmetry-pos-expand
          :documentation "(<predicate> <whatever> <whatever>)
where <predicate> is a FORT
and (#$isa <predicate> #$SymmetricBinaryPredicate)
from a rule concluding to <predicate>
using the predicate rule indexing in the KB"
          :example "(#$bordersOn #$Canada ?WHAT)
from (#$isa #$bordersOn #$SymmetricBinaryPredicate)
and a rule concluding to #$bordersOn")))

(toplevel
  (inference-transformation-module :trans-predicate-symmetry-neg
    (list :sense :neg
          :required-pattern (list :and
                                  (list :fort :anything :anything)
                                  (cons (list :test 'inference-symmetric-predicate?) :anything))
          :cost 'trans-predicate-symmetry-neg-cost
          :rule-select 'trans-predicate-symmetry-neg-rule-select
          :rule-filter 'trans-predicate-symmetry-neg-rule-filter
          :expand 'trans-predicate-symmetry-neg-expand
          :documentation "(#$not (<predicate> <whatever> <whatever>))
where <predicate> is a FORT
and (#$isa <predicate> #$SymmetricBinaryPredicate)
from a rule concluding from <predicate>
using the predicate rule indexing in the KB"
          :example "(#$not (#$bordersOn #$Canada ?WHAT))
from (#$isa #$bordersOn #$SymmetricBinaryPredicate)
and a rule concluding from #$bordersOn")))

(toplevel
  (inference-transformation-module :trans-predicate-commutative-pos
    (list :sense :pos
          :required-pattern (list :and
                                  (list* :fort :anything :anything :anything :anything)
                                  (cons (list :test 'inference-commutative-predicate-p) :anything))
          :cost 'trans-predicate-commutative-pos-cost
          :rule-select 'trans-predicate-commutative-pos-rule-select
          :rule-filter 'trans-predicate-commutative-pos-rule-filter
          :expand 'trans-predicate-commutative-pos-expand
          :documentation "(<predicate> . <args>)
where <predicate> is a FORT
there are at least 3 args in <args>
and (#$isa <predicate> #$CommutativePredicate)
from a rule concluding to <predicate>
using the predicate rule indexing in the KB"
          :example "(#$collinear <point A> <point B> <point C>)
from (#$isa #$collinear #$CommutativePredicate)
and a rule concluding to #$collinear")))

(toplevel
  (inference-transformation-module :trans-predicate-commutative-neg
    (list :sense :neg
          :required-pattern (list :and
                                  (list* :fort :anything :anything :anything :anything)
                                  (cons (list :test 'inference-commutative-predicate-p) :anything))
          :cost 'trans-predicate-commutative-neg-cost
          :rule-select 'trans-predicate-commutative-neg-rule-select
          :rule-filter 'trans-predicate-commutative-neg-rule-filter
          :expand 'trans-predicate-commutative-neg-expand
          :documentation "(#$not (<predicate> . <args>))
where <predicate> is a FORT
there are at least 3 args in <args>
and (#$isa <predicate> #$CommutativePredicate)
from a rule concluding from <predicate>
using the predicate rule indexing in the KB"
          :example "(#$not (#$collinear <point A> <point B> <point C>))
from (#$isa #$collinear #$CommutativePredicate)
and a rule concluding from #$collinear")))

(toplevel
  (inference-transformation-module :trans-predicate-partially-commutative-pos
    (list :sense :pos
          :required-pattern (list :and
                                  (list* :fort :anything :anything :anything :anything)
                                  (cons (list :test 'inference-partially-commutative-predicate-p) :anything))
          :cost 'trans-predicate-partially-commutative-pos-cost
          :rule-select 'trans-predicate-partially-commutative-pos-rule-select
          :rule-filter 'trans-predicate-partially-commutative-pos-rule-filter
          :expand 'trans-predicate-partially-commutative-pos-expand
          :documentation "(<predicate> <whatever> <whatever>)
where <predicate> is a FORT
and (#$isa <predicate> #$PartiallyCommutativePredicate)
from a rule concluding to <predicate>
using the predicate rule indexing in the KB"
          :example "(distanceBetween PlanetEarth Sun ((Mega Mile) 93))
from (#$isa #$distanceBetween #$PartiallyCommutativePredicate)
and  (#$commutativeInArgs #$distanceBetween 1 2)
and a rule concluding to #$distanceBetween")))

(toplevel
  (inference-transformation-module :trans-predicate-partially-commutative-neg
    (list :sense :neg
          :required-pattern (list :and
                                  (list* :fort :anything :anything :anything :anything)
                                  (cons (list :test 'inference-partially-commutative-predicate-p) :anything))
          :cost 'trans-predicate-partially-commutative-neg-cost
          :rule-select 'trans-predicate-partially-commutative-neg-rule-select
          :rule-filter 'trans-predicate-partially-commutative-neg-rule-filter
          :expand 'trans-predicate-partially-commutative-neg-expand
          :documentation "(#$not (<predicate> <whatever> <whatever>))
where <predicate> is a FORT
and (#$isa <predicate> #$PartiallyCommutativePredicate)
from a rule concluding from <predicate>
using the predicate rule indexing in the KB"
          :example "(not (distanceBetween PlanetEarth Sun (Inch 93)))
from (#$isa #$distanceBetween #$PartiallyCommutativePredicate)
and  (#$commutativeInArgs #$distanceBetween 1 2)
and a rule concluding from #$distanceBetween")))

(toplevel
  (inference-transformation-module :trans-predicate-asymmetry
    (list :sense :neg
          :required-pattern (list :and
                                  (list :fort :anything :anything)
                                  (cons (list :test 'inference-asymmetric-predicate?) :anything))
          :cost 'trans-predicate-asymmetry-cost
          :rule-select 'trans-predicate-asymmetry-rule-select
          :rule-filter 'trans-predicate-asymmetry-rule-filter
          :expand 'trans-predicate-asymmetry-expand
          :documentation "(#$not (<predicate> <whatever> <whatever>))
where <predicate> is a FORT
and (#$isa <predicate> #$AsymmetricBinaryPredicate)
from a rule concluding to <predicate>
using the predicate rule indexing in the KB"
          :example "(#$not (#$northOf ?WHAT #$Canada))
from (#$isa #$northOf #$AsymmetricBinaryPredicate)
and a rule concluding to #$northOf")))

(toplevel
  (inference-transformation-module :trans-unbound-predicate-pos
    (list :sense :pos
          :required 'trans-unbound-predicate-pos-required
          :cost 'trans-unbound-predicate-pos-cost
          :rule-select 'trans-unbound-predicate-pos-rule-select
          :rule-filter 'trans-unbound-predicate-pos-rule-filter
          :expand 'trans-unbound-predicate-pos-expand
          :documentation "(<whatever> . <whatever>)
from a rule concluding to a sentence with a variable as the predicate
using the unbound predicate rule indexing in the KB"
          :example "(#$implies
      (#$and (#$isa ?ORDER #$MathematicalOrdering) (#$baseSet ?ORDER ?SET)
       (#$orderingRelations ?ORDER ?PRED) (#$elementOf ?X ?SET)
       (#$elementOf ?Y ?SET) (?PRED ?X ?Y) (#$elementOf ?Z ?SET)
       (?PRED ?Y ?Z))
      (?PRED ?X ?Z))")))

(toplevel
  (inference-transformation-module :trans-unbound-predicate-neg
    (list :sense :neg
          :required 'trans-unbound-predicate-neg-required
          :cost 'trans-unbound-predicate-neg-cost
          :rule-select 'trans-unbound-predicate-neg-rule-select
          :rule-filter 'trans-unbound-predicate-neg-rule-filter
          :expand 'trans-unbound-predicate-neg-expand
          :documentation "(#$not (<whatever> . <whatever>))
from a rule concluding from a sentence with a variable as the predicate
using the unbound predicate rule indexing in the KB"
          :example "no current example")))

(toplevel (note-memoized-function 'inference-memoized-all-specs))
(toplevel (note-memoized-function 'trans-isa-pos-rule-select-count))

(toplevel
  (inference-transformation-module :trans-isa-pos
    (list :sense :pos
          :predicate #$isa
          :required-pattern (list #$isa :anything :fort)
          :required 'trans-isa-pos-required
          :cost 'trans-isa-pos-cost
          :rule-select 'trans-isa-pos-rule-select
          :rule-filter 'trans-isa-pos-rule-filter
          :expand 'trans-isa-pos-expand
          :documentation "(#$isa <whatever> <collection>)
where <collection> is a FORT
from a rule concluding to a spec of <collection>
using the isa rule indexing in the KB"
          :example "(#$isa #$AbrahamLincoln #$FamousPerson)
from (#$genls #$UnitedStatesPresident #$FamousPerson)
and a rule concluding to #$isa #$UnitedStatesPresident")))

(toplevel
  (inference-transformation-module :trans-isa-neg
    (list :sense :neg
          :predicate #$isa
          :required-pattern (list #$isa :anything :fort)
          :required 'trans-isa-neg-required
          :cost 'trans-isa-neg-cost
          :rule-select 'trans-isa-neg-rule-select
          :rule-filter 'trans-isa-neg-rule-filter
          :expand 'trans-isa-neg-expand
          :documentation "(#$not (#$isa <whatever> <collection>))
where <collection> is a FORT
from a rule concluding from a genl of <collection>
using the isa rule indexing in the KB"
          :example "(#$not (#$isa #$AbrahamLincoln #$FrenchPerson))
from (#$genls #$FrenchPerson #$EuropeanPerson)
and a rule concluding from #$isa #$EuropeanPerson")))

(toplevel
  (inference-transformation-module :trans-genls-pos
    (list :sense :pos
          :predicate #$genls
          :required-pattern (list #$genls :anything :fort)
          :required 'trans-genls-pos-required
          :cost 'trans-genls-pos-cost
          :rule-select 'trans-genls-pos-rule-select
          :rule-filter 'trans-genls-pos-rule-filter
          :expand 'trans-genls-pos-expand
          :documentation "(#$genls <whatever> <collection>)
where <collection> is a FORT
from a rule concluding to a spec of <collection>
using the genls rule indexing in the KB"
          :example "(#$genls #$UnitedStatesPresident #$FamousPerson)
from (#$genls #$WorldLeader #$FamousPerson)
and a rule concluding to (#$genls ?X #$WorldLeader)")))

(toplevel
  (inference-transformation-module :trans-genls-neg
    (list :sense :neg
          :predicate #$genls
          :required-pattern (list #$genls :anything :fort)
          :required 'trans-genls-neg-required
          :cost 'trans-genls-neg-cost
          :rule-select 'trans-genls-neg-rule-select
          :rule-filter 'trans-genls-neg-rule-filter
          :expand 'trans-genls-neg-expand
          :documentation "(#$not (#$genls <whatever> <collection>))
where <collection> is a FORT
from a rule concluding from a genl of <collection>
using the genls rule indexing in the KB"
          :example "(#$not (#$genls #$UnitedStatesPresident #$FrenchPerson))
from (#$genls #$FrenchPerson #$EuropeanPerson)
and a rule concluding from (#$genls ?X #$EuropeanPerson)")))

(toplevel (note-memoized-function 'inference-memoized-all-spec-mts))

(toplevel
  (inference-transformation-module :trans-genl-mt-pos
    (list :sense :pos
          :predicate #$genlMt
          :required-pattern (list #$genlMt :anything (list :test 'hlmt-p))
          :required 'trans-genl-mt-pos-required
          :cost 'trans-genl-mt-pos-cost
          :rule-select 'trans-genl-mt-pos-rule-select
          :rule-filter 'trans-genl-mt-pos-rule-filter
          :expand 'trans-genl-mt-pos-expand
          :documentation "(#$genlMt <whatever> <microtheory>)
where <microtheory> is a FORT
from a rule concluding to a spec of <microtheory>
using the genlMt rule indexing in the KB"
          :example "(#$genlMt #$UnitedStatesPresidentsMt #$FamousPeopleMt)
from (#$genlMt #$WorldLeadersMt #$FamousPeopleMt)
and a rule concluding to (#$genlMt ?X #$WorldLeadersMt)")))

(toplevel
  (inference-transformation-module :trans-genl-mt-neg
    (list :sense :neg
          :predicate #$genlMt
          :required-pattern (list #$genlMt :anything (list :test 'hlmt-p))
          :required 'trans-genl-mt-neg-required
          :cost 'trans-genl-mt-neg-cost
          :rule-select 'trans-genl-mt-neg-rule-select
          :rule-filter 'trans-genl-mt-neg-rule-filter
          :expand 'trans-genl-mt-neg-expand
          :documentation "(#$not (#$genlMt <whatever> <microtheory>))
where <microtheory> is a FORT
from a rule concluding from a genl of <microtheory>
using the genlMt rule indexing in the KB"
          :example "(#$not (#$genlMt #$UnitedStatesPresidentsMt #$FrenchPeopleMt))
from (#$genlMt #$FrenchPeopleMt #$EuropeanPeopleMt)
and a rule concluding from (#$genlMt ?X #$EuropeanPeopleMt)")))

(toplevel
  (inference-transformation-module :trans-abnormal
    (list :sense :pos
          :predicate #$abnormal
          :required-pattern (list #$abnormal :anything :assertion)
          :exclusive t
          :cost 'trans-abnormal-cost
          :rule-select 'trans-abnormal-rule-select
          :rule-filter 'trans-abnormal-rule-filter
          :expand 'trans-abnormal-expand)))

(toplevel
  (inference-transformation-module :transformation-abduction-to-specs
    (list :sense :pos
          :arity 2
          :predicate #$isa
          :required-pattern (list #$isa :fort :fully-bound)
          :required 'transformation-abduction-to-specs-required
          :cost-expression '*default-abduction-cost*
          :rule-select 'transformation-abduction-to-specs-rule-select
          :rule-filter 'transformation-abduction-to-specs-rule-filter
          :expand 'transformation-abduction-to-specs-expand
          :documentation "(#$isa <fort> <fully-bound>)
   where the asent is deemed abducible, and the problem store allows abduction,
   using #$genls rules."
          :example "(#$isa #$GeorgeWBush #$Parent)")))
