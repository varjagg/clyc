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

;; Defstruct for removal-link-data
(defstruct (removal-link-data (:conc-name "REMOV-LINK-DATA-"))
  hl-module
  bindings
  supports)

(defun removal-link-data-p (object)
  (typep object 'removal-link-data))

(defun new-removal-link (problem hl-module removal-bindings supports)
  "[Cyc] Return removal-link-p.
This is a link to goal by virtue of the fact that it has no supporting mapped problems."
  (declare (type problem-p problem))
  (let ((removal-link (new-removal-link-int problem hl-module removal-bindings supports)))
    (propagate-problem-link removal-link)
    removal-link))

(defun new-removal-link-int (problem hl-module removal-bindings supports)
  "[Cyc] Returns a new :removal link
with its data properties set to HL-MODULE, BINDINGS, and SUPPORTS,
with a supported problem of PROBLEM, and no supporting problems yet."
  (let ((removal-link (new-problem-link :removal problem)))
    (new-removal-link-data removal-link)
    (set-removal-link-hl-module removal-link hl-module)
    (set-removal-link-bindings removal-link removal-bindings)
    (set-removal-link-supports removal-link supports)
    (index-problem-argument-link problem removal-link)
    removal-link))

(defun new-removal-link-data (removal-link)
  (let ((data (make-removal-link-data)))
    (set-problem-link-data removal-link data))
  removal-link)

;; (defun destroy-removal-link (removal-link) ...) -- active declareFunction, no body

(defun removal-link-hl-module (removal-link)
  (declare (type removal-link-p removal-link))
  (let ((data (problem-link-data removal-link)))
    (remov-link-data-hl-module data)))

(defun removal-link-bindings (removal-link)
  "[Cyc] The first elements of these bindings are in the space of REMOVAL-LINK's
supported problem, and their second elements are in the space of
REMOVAL-LINK's unique supporting problem."
  (declare (type removal-link-p removal-link))
  (let ((data (problem-link-data removal-link)))
    (remov-link-data-bindings data)))

(defun removal-link-supports (removal-link)
  (declare (type removal-link-p removal-link))
  (let ((data (problem-link-data removal-link)))
    (remov-link-data-supports data)))

(defun set-removal-link-hl-module (removal-link hl-module)
  (declare (type removal-link-p removal-link)
           (type hl-module-p hl-module))
  (let ((data (problem-link-data removal-link)))
    (setf (remov-link-data-hl-module data) hl-module))
  removal-link)

(defun set-removal-link-bindings (removal-link v-bindings)
  (declare (type removal-link-p removal-link)
           (type binding-list-p v-bindings))
  (let ((data (problem-link-data removal-link)))
    (setf (remov-link-data-bindings data) v-bindings))
  removal-link)

(defun set-removal-link-supports (removal-link supports)
  (declare (type removal-link-p removal-link)
           (type hl-justification-p supports))
  (when (problem-store-compute-answer-justifications? (problem-link-store removal-link))
    (let ((data (problem-link-data removal-link)))
      (setf (remov-link-data-supports data) supports)))
  removal-link)

(defun removal-link-tactic (removal-link)
  (declare (type removal-link-p removal-link))
  (let ((hl-module (removal-link-hl-module removal-link))
        (problem (problem-link-supported-problem removal-link))
        (store (problem-link-store removal-link)))
    (if (removal-module-p hl-module)
        (progn
          (dolist (candidate-tactic (problem-tactics problem))
            (when (do-problem-tactics-type-match candidate-tactic :removal)
              (when (eq (tactic-hl-module candidate-tactic) hl-module)
                (return-from removal-link-tactic candidate-tactic))))
          (when (and (problem-store-add-restriction-layer-of-indirection? store)
                     (closed-problem-p problem))
            (do-set (restriction-link (problem-dependent-links problem))
              (when (problem-link-has-type? restriction-link :restriction)
                (let ((unrestricted-problem (problem-link-supported-problem restriction-link)))
                  (dolist (candidate-tactic (problem-tactics unrestricted-problem))
                    (when (do-problem-tactics-type-match candidate-tactic :removal)
                      (when (eq (tactic-hl-module candidate-tactic) hl-module)
                        (return-from removal-link-tactic candidate-tactic)))))))))
        ;; conjunctive removal case
        (do-set (split-link (problem-dependent-links problem))
          (when (problem-link-has-type? split-link :split)
            (let ((split-problem (problem-link-supported-problem split-link)))
              (dolist (candidate-tactic (problem-tactics split-problem))
                (when (do-problem-tactics-type-match candidate-tactic :removal-conjunctive)
                  (when (eq (tactic-hl-module candidate-tactic) hl-module)
                    (return-from removal-link-tactic candidate-tactic))))
              (do-set (restriction-link (problem-dependent-links split-problem))
                (when (problem-link-has-type? restriction-link :restriction)
                  (let ((unrestricted-problem (problem-link-supported-problem restriction-link)))
                    (dolist (candidate-tactic (problem-tactics unrestricted-problem))
                      (when (do-problem-tactics-type-match candidate-tactic :removal-conjunctive)
                        (when (eq (tactic-hl-module candidate-tactic) hl-module)
                          (return-from removal-link-tactic candidate-tactic)))))))))))
    nil))

(defun removal-link-data-equals-spec? (removal-link removal-bindings supports)
  (let ((link-removal-bindings (removal-link-bindings removal-link))
        (link-supports (removal-link-supports removal-link)))
    (and (equal removal-bindings link-removal-bindings)
         (justification-equal supports link-supports))))

(defun generalized-removal-tactic-p (object)
  (or (removal-tactic-p object)
      (conjunctive-removal-tactic-p object)
      (meta-removal-tactic-p object)))

(defun conjunctive-removal-tactic-p (tactic)
  (and (tactic-p tactic)
       (eq :removal-conjunctive (tactic-type tactic))))

(defun conjunctive-removal-link-p (link)
  (and (removal-link-p link)
       (conjunctive-removal-module-p
        ;; Likely retrieves hl-module from removal-link — evidence: removal-link-hl-module accessor
        (missing-larkc 36238))))

;; (defun conjunctive-removal-proof-p (proof) ...) -- active declareFunction, no body

(defun determine-new-conjunctive-removal-tactics (problem dnf-clause)
  "[Cyc] Determines tactics which can solve all of the conjunctive problem PROBLEM at once."
  (when (problem-store-removal-allowed? (problem-store problem))
    (let ((supplanted-hl-modules nil)
          (tactic-specs nil)
          (exclusive-found? nil)
          (common-mt (contextualized-dnf-clause-common-mt dnf-clause)))
      (with-inference-mt-relevance common-mt
        (let ((hl-modules (determine-applicable-conjunctive-removal-modules dnf-clause)))
          (setf hl-modules (sort-applicable-conjunctive-removal-modules-by-priority hl-modules))
          (csome (hl-module hl-modules exclusive-found?)
            (unless (and supplanted-hl-modules
                        (member hl-module supplanted-hl-modules))
              (let ((exclusive-func (hl-module-exclusive-func hl-module)))
                (when (or (null exclusive-func)
                          (and (function-spec-p exclusive-func)
                               (funcall exclusive-func dnf-clause)))
                  (when exclusive-func
                    (multiple-value-setq (exclusive-found? tactic-specs supplanted-hl-modules)
                      ;; Likely handles exclusive module logic for conjunctive removal
                      (missing-larkc 36243)))
                  (let ((cost ;; Likely computes conjunctive removal module cost
                              (missing-larkc 36414)))
                    (when cost
                      (let* ((productivity (productivity-for-number-of-children cost))
                             (completeness ;; Likely computes conjunctive removal module completeness
                                           (missing-larkc 36413))
                             (tactic-spec (list hl-module productivity completeness)))
                        (push tactic-spec tactic-specs))))))))
          (dolist (tactic-spec tactic-specs)
            (destructuring-bind (hl-module productivity completeness) tactic-spec
              ;; Likely creates a new conjunctive removal tactic
              (missing-larkc 36233)))))
      tactic-specs)))

(defun sort-applicable-conjunctive-removal-modules-by-priority (hl-modules)
  "[Cyc] Help determine-new-conjunctive-removal-tactics do better by ordering pruning modules before simplification modules and simplification modules before everything else.  This prevents an exclusive simplification module from trumping an exclusive pruning module, for example."
  (sort hl-modules #'conjunctive-removal-module-priority<))

(defun conjunctive-removal-module-priority< (hl-module1 hl-module2)
  (cond ((and (conjunctive-pruning-module-p hl-module1)
              (not (conjunctive-pruning-module-p hl-module2)))
         t)
        ((and (conjunctive-pruning-module-p hl-module2)
              (not (conjunctive-pruning-module-p hl-module1)))
         nil)
        ((and (simplification-module-p hl-module1)
              (not (simplification-module-p hl-module2)))
         t)
        ((and (simplification-module-p hl-module2)
              (not (simplification-module-p hl-module1)))
         nil)
        (t t)))

(defun determine-applicable-conjunctive-removal-modules (contextualized-dnf-clause)
  (let ((some-backchain-required? (inference-some-backchain-required-asent-in-clause? contextualized-dnf-clause))
        (applicable-modules nil))
    (do-set (hl-module (removal-modules-conjunctive))
      (when (or (not some-backchain-required?)
                (conjunctive-pruning-module-p hl-module)
                (and *simplification-tactics-execute-early-and-pass-down-transformation-motivation?*
                     (simplification-module-p hl-module)))
        (when (hl-module-direction-relevant? hl-module)
          (let ((new-subclause-specs (hl-module-applicable-subclause-specs hl-module contextualized-dnf-clause)))
            (dolist (subclause-spec new-subclause-specs)
              ;; Likely checks that subclause-spec covers more than one literal
              (when (missing-larkc 30281)
                (push hl-module applicable-modules)))))))
    applicable-modules))

(defun motivated-multi-literal-subclause-specs (contextualized-dnf-clause)
  (let ((subclause-specs nil))
    (unless (inference-some-backchain-required-asent-in-clause? contextualized-dnf-clause)
      (do-set (hl-module (removal-modules-conjunctive))
        (unless (or (conjunctive-pruning-module-p hl-module)
                    (simplification-module-p hl-module))
          (when (hl-module-direction-relevant? hl-module)
            (let ((new-subclause-specs (hl-module-applicable-subclause-specs hl-module contextualized-dnf-clause)))
              (dolist (subclause-spec new-subclause-specs)
                ;; Likely checks that subclause-spec covers more than one literal
                (unless (missing-larkc 30282)
                  (pushnew subclause-spec subclause-specs :test #'equal))))))))
    (nreverse subclause-specs)))

(defun hl-module-applicable-subclause-specs (hl-module contextualized-dnf-clause)
  (dolist (predicate (hl-module-every-predicates hl-module))
    (unless (contextualized-clause-has-literal-with-predicate? contextualized-dnf-clause predicate)
      (return-from hl-module-applicable-subclause-specs nil)))
  (let ((subclause-specs nil)
        (applicability-pattern (hl-module-applicability-pattern hl-module)))
    (if applicability-pattern
        (setf subclause-specs (pattern-transform-formula applicability-pattern contextualized-dnf-clause))
        (let ((applicability-method (hl-module-applicability-func hl-module)))
          (when (function-spec-p applicability-method)
            (setf subclause-specs (funcall applicability-method contextualized-dnf-clause)))))
    (dolist (subclause-spec subclause-specs)
      ;; Likely checks that subclause-spec is valid (more than one literal)
      (must (missing-larkc 30264)
            "~s stated its applicability to the subclause spec ~s, which does not specify more than one literal.~%Conjunctive removal modules must apply to more than one literal in the clause."
            hl-module subclause-spec))
    subclause-specs))

;; (defun new-conjunctive-removal-tactic (problem hl-module productivity completeness) ...) -- active declareFunction, no body
;; (defun compute-strategic-properties-of-conjunctive-removal-tactic (tactic strategy) ...) -- active declareFunction, no body
;; (defun execute-conjunctive-removal-tactic (tactic) ...) -- active declareFunction, no body
;; (defun maybe-make-conjunctive-removal-tactic-progress-iterator (tactic) ...) -- active declareFunction, no body
;; (defun maybe-make-conjunctive-removal-tactic-progress-expand-iterative-iterator (tactic) ...) -- active declareFunction, no body
;; (defun new-conjunctive-removal-tactic-progress-expand-iterative-iterator (tactic expand-results) ...) -- active declareFunction, no body
;; (defun handle-one-conjunctive-removal-tactic-expand-iterative-result (tactic expand-result) ...) -- active declareFunction, no body
;; (defun maybe-make-conjunctive-removal-tactic-progress-expand-iterator (tactic) ...) -- active declareFunction, no body
;; (defun new-conjunctive-removal-tactic-progress-expand-iterator (tactic expand-results) ...) -- active declareFunction, no body
;; (defun conjunctive-removal-callback (removal-bindings justifications) ...) -- active declareFunction, no body
;; (defun handle-one-conjunctive-removal-tactic-expand-result (tactic expand-result) ...) -- active declareFunction, no body
;; (defun handle-one-conjunctive-removal-tactic-result (tactic removal-bindings justifications) ...) -- active declareFunction, no body
;; (defun maybe-new-simplification-link (problem tactic supports) ...) -- active declareFunction, no body
;; (defun maybe-new-restriction-split-and-removal-links (problem tactic removal-bindings supports) ...) -- active declareFunction, no body
;; (defun reorder-conjunctive-removal-justifications (tactic dnf-clause removal-bindings justifications) ...) -- active declareFunction, no body
;; (defun maybe-new-split-and-removal-links (problem tactic supports) ...) -- active declareFunction, no body
;; (defun maybe-new-removal-link-for-split-link (problem tactic split-link removal-bindings supports) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants: $list40=(STORE &BODY BODY),
;; $sym41$STORE_VAR (gensym), $sym42$CLET, $sym43$*NEGATION-BY-FAILURE*,
;; $sym44$PROBLEM-STORE-NEGATION-BY-FAILURE?
;; Expansion: binds *negation-by-failure* from the problem store
(defmacro with-problem-store-removal-assumptions ((store) &body body)
  (with-temp-vars (store-var)
    `(let* ((,store-var ,store)
            (*negation-by-failure* (problem-store-negation-by-failure? ,store-var)))
       ,@body)))

(defun meta-removal-tactic-p (object)
  (and (tactic-p object)
       (eq :meta-removal (tactic-type object))))

;; (defun compute-strategic-properties-of-meta-removal-tactic (tactic strategy) ...) -- active declareFunction, no body

(defun removal-link-p (object)
  (and (problem-link-p object)
       (eq :removal (problem-link-type object))))

(defun removal-tactic-p (object)
  (and (tactic-p object)
       (eq :removal (tactic-type object))))

;; (defun removal-proof-p (proof) ...) -- active declareFunction, no body

(defun removal-module-exclusive-func-funcall (func asent sense)
  (possibly-cyc-api-funcall-2 func asent sense))

(defun removal-module-required-func-funcall (func asent sense)
  (cond ((eq func 'meta-removal-completely-decidable-pos-required)
         (meta-removal-completely-decidable-pos-required asent sense))
        ((eq func 'meta-removal-completely-enumerable-pos-required)
         (meta-removal-completely-enumerable-pos-required asent sense))
        ((eq func 'removal-abduction-pos-required)
         (removal-abduction-pos-required asent sense))
        ((eq func 'removal-evaluatable-fcp-unify-required)
         (removal-evaluatable-fcp-unify-required asent sense))
        ((eq func 'removal-fcp-check-required)
         (removal-fcp-check-required asent sense))
        ((eq func 'removal-isa-defn-pos-required)
         ;; Likely checks defn relevance for ISA removal
         (missing-larkc 32811))
        ((eq func 'removal-tva-check-required)
         (removal-tva-check-required asent sense))
        ((eq func 'removal-tva-unify-required)
         (removal-tva-unify-required asent sense))
        (t
         (possibly-cyc-api-funcall-2 func asent sense))))

(defun removal-module-expand-func-funcall (func asent sense)
  (cond ((eq func 'removal-asserted-term-sentences-arg-index-unify-expand)
         ;; Likely expands asserted term sentence lookups by arg index
         (missing-larkc 32642))
        ((eq func 'removal-eval-expand)
         (removal-eval-expand asent sense))
        ((eq func 'removal-evaluate-bind-expand)
         ;; Likely expands evaluation with binding
         (missing-larkc 1326))
        ((eq func 'removal-isa-collection-check-neg-expand)
         ;; Likely expands negative ISA collection checks
         (missing-larkc 32809))
        ((eq func 'removal-isa-collection-check-pos-expand)
         (removal-isa-collection-check-pos-expand asent sense))
        ((eq func 'removal-nat-argument-lookup-expand)
         (removal-nat-argument-lookup-expand asent sense))
        ((eq func 'removal-nat-formula-expand)
         ;; Likely expands NAT formula lookups
         (missing-larkc 32743))
        ((eq func 'removal-nat-function-lookup-expand)
         ;; Likely expands NAT function lookups
         (missing-larkc 32771))
        ((eq func 'removal-nat-lookup-expand)
         ;; Likely expands NAT lookups
         (missing-larkc 32744))
        ((eq func 'removal-reflexive-on-expand)
         ;; Likely expands reflexive-on checks
         (missing-larkc 32705))
        ((eq func 'removal-tva-check-expand)
         ;; Likely expands TVA checks
         (missing-larkc 32696))
        (t
         (possibly-cyc-api-funcall-2 func asent sense))))

(defun determine-new-literal-removal-tactics (problem asent sense)
  (when (problem-store-removal-allowed? (problem-store problem))
    (let ((store (problem-store problem))
          (tactics nil))
      (with-problem-store-removal-assumptions (store)
        (determine-new-literal-simple-removal-tactics problem asent sense)
        (determine-new-literal-meta-removal-tactics problem asent sense))
      tactics)))

(defun determine-new-literal-meta-removal-tactics (problem asent sense)
  "[Cyc] Figure out all applicable inference meta removal tactics for ASENT with SENSE, and add them to PROBLEM."
  (let ((hl-modules (literal-meta-removal-candidate-hl-modules asent sense)))
    (determine-new-removal-tactics-from-hl-modules hl-modules problem asent sense)))

(defun determine-new-literal-simple-removal-tactics (problem asent sense)
  "[Cyc] Figure out all applicable inference removal tactics for ASENT with SENSE, and add them to PROBLEM."
  (let ((hl-modules (literal-simple-removal-candidate-hl-modules asent sense)))
    (determine-new-removal-tactics-from-hl-modules hl-modules problem asent sense)))

(defun literal-removal-options (asent sense &optional (allowed-modules-spec :all))
  "[Cyc] Return a list of inference removal options for ASENT with SENSE."
  (let ((hl-modules (literal-removal-options-hl-modules asent sense allowed-modules-spec)))
    (determine-new-removal-tactic-specs-from-hl-modules hl-modules asent sense)))

(defun literal-removal-options-hl-modules (asent sense allowed-modules-spec)
  (let ((candidate-hl-modules (literal-removal-options-candidate-hl-modules asent sense allowed-modules-spec)))
    (filter-modules-wrt-allowed-modules-spec candidate-hl-modules allowed-modules-spec)))

(defun filter-modules-wrt-allowed-modules-spec (candidate-hl-modules allowed-modules-spec)
  (let ((hl-modules nil))
    (if (eq allowed-modules-spec :all)
        (setf hl-modules candidate-hl-modules)
        (progn
          (dolist (module candidate-hl-modules)
            (when (or (hl-module-allowed-by-allowed-modules-spec? module allowed-modules-spec)
                      (hl-module-exclusive-func module))
              (push module hl-modules)))
          (setf hl-modules (nreverse hl-modules))))
    hl-modules))

(defun literal-removal-options-candidate-hl-modules (asent sense allowed-modules-spec)
  (cond ((eq allowed-modules-spec :all)
         (literal-simple-removal-candidate-hl-modules asent sense))
        ((simple-allowed-modules-spec-p allowed-modules-spec)
         (get-modules-from-simple-allowed-modules-spec allowed-modules-spec))
        (t
         (literal-simple-removal-candidate-hl-modules asent sense))))

(defun hl-module-applicable-to-asent? (hl-module asent)
  (and (hl-module-predicate-relevant-p hl-module (atomic-sentence-predicate asent))
       (hl-module-arity-relevant-p hl-module asent)
       (hl-module-required-pattern-matched-p hl-module asent)
       (hl-module-required-mt-relevant? hl-module)
       (hl-module-direction-relevant? hl-module)))

(defun determine-new-removal-tactics-from-hl-modules (hl-modules problem asent sense)
  "[Cyc] Using HL-MODULES, figure out applicable inference removal tactics
   for ASENT with SENSE, and add them to PROBLEM.
   HL-MODULES is a list of the applicable removal modules to try."
  (let ((tactic-specs (determine-new-removal-tactic-specs-from-hl-modules hl-modules asent sense)))
    (dolist (tactic-spec tactic-specs)
      (destructuring-bind (hl-module productivity completeness) tactic-spec
        (new-removal-tactic problem hl-module productivity completeness)))
    tactic-specs))

(defun determine-new-removal-tactic-specs-from-hl-modules (hl-modules asent sense)
  "[Cyc] Using HL-MODULES, figure out applicable inference removal tactic-specs
   for ASENT with SENSE.
   HL-MODULES is a list of the applicable removal modules to try."
  (hl-module-guts :determine-new-removal-tactic-specs-from-hl-modules hl-modules asent sense))

(defun determine-new-removal-tactic-specs-from-hl-modules-guts (candidate-hl-modules asent sense)
  "[Cyc] map over the hl-modules, determining our tactics for this literal"
  (let ((applicable-hl-modules (determine-applicable-hl-modules-for-asent candidate-hl-modules asent sense))
        (tactic-specs nil))
    (setf tactic-specs (compute-tactic-specs-for-asent applicable-hl-modules asent sense))
    tactic-specs))

(defun determine-applicable-hl-modules-for-asent (candidate-hl-modules asent sense)
  (let ((supplanted-hl-modules nil)
        (applicable-hl-modules nil)
        (totally-exclusive-found? nil))
    ;; First pass: non-exclusive modules
    (csome (hl-module candidate-hl-modules totally-exclusive-found?)
      (when (null (hl-module-exclusive-func hl-module))
        (multiple-value-setq (totally-exclusive-found? applicable-hl-modules supplanted-hl-modules)
          (update-applicable-hl-modules hl-module asent sense applicable-hl-modules supplanted-hl-modules))))
    ;; Second pass: exclusive modules
    (unless totally-exclusive-found?
      (csome (hl-module candidate-hl-modules totally-exclusive-found?)
        (when (hl-module-exclusive-func hl-module)
          (multiple-value-setq (totally-exclusive-found? applicable-hl-modules supplanted-hl-modules)
            (update-applicable-hl-modules hl-module asent sense applicable-hl-modules supplanted-hl-modules)))))
    applicable-hl-modules))

(defun update-applicable-hl-modules (hl-module asent sense applicable-hl-modules supplanted-hl-modules)
  "[Cyc] Determine if HL-MODULE applies to ASENT with SENSE
   @return 0 boolean ; whether HL-MODULE is completely exclusive, allowing us to ignore checking other hl-modules.
   @return 1 applicable-hl-modules ; updated version of APPLICABLE-HL-MODULES
   @return 2 supplanted-hl-modules ; updated version of SUPPLANTED-HL-MODULES if HL-MODULE is at least partially exclusive."
  (let ((totally-exclusive-found? nil))
    (unless (and supplanted-hl-modules
                 (member-eq? hl-module supplanted-hl-modules))
      (when (hl-module-applicable-to-asent? hl-module asent)
        (let ((exclusive-func (hl-module-exclusive-func hl-module)))
          (when (or (null exclusive-func)
                    (and (possibly-cyc-api-function-spec-p exclusive-func)
                         (removal-module-exclusive-func-funcall exclusive-func asent sense)))
            (when exclusive-func
              (multiple-value-setq (totally-exclusive-found? applicable-hl-modules supplanted-hl-modules)
                (update-supplanted-hl-modules hl-module applicable-hl-modules supplanted-hl-modules)))
            (let ((required-func (hl-module-required-func hl-module)))
              (when (or (null required-func)
                        (and (possibly-cyc-api-function-spec-p required-func)
                             (removal-module-required-func-funcall required-func asent sense)))
                (push hl-module applicable-hl-modules)))))))
    (values totally-exclusive-found? applicable-hl-modules supplanted-hl-modules)))

(defun update-supplanted-hl-modules (hl-module applicable-hl-modules supplanted-hl-modules)
  "[Cyc] Update the set of APPLICABLE-HL-MODULES and SUPPLANTED-HL-MODULES using the :supplants info on HL-MODULE.
   @return 0 boolean ; T iff HL-MODULE supplants all other hl-modules
   @return 1 applicable-hl-modules ; updated version
   @return 2 supplanted-modules    ; updated version"
  (let ((supplants-info (hl-module-supplants-info hl-module))
        (totally-exclusive-found? nil))
    (if (eq supplants-info :all)
        (progn
          (setf applicable-hl-modules nil)
          (setf totally-exclusive-found? t))
        (let ((newly-supplanted-hl-module-patterns supplants-info))
          (dolist (supplanted-hl-module-pattern newly-supplanted-hl-module-patterns)
            (if (consp supplanted-hl-module-pattern)
                (let ((patterns (list supplanted-hl-module-pattern))
                      (negate? nil)
                      (pattern nil))
                  (loop while patterns do
                    (setf pattern (first patterns))
                    (setf patterns (rest patterns))
                    (let ((directive (first pattern))
                          (rest (rest pattern)))
                      (cond ((eq directive :not)
                             (setf negate? (not negate?))
                             (push (first rest) patterns))
                            ((eq directive :module-subtype)
                             (let ((subtype (first rest))
                                   (newly-supplanted-hl-modules applicable-hl-modules))
                               (dolist (supplanted-hl-module newly-supplanted-hl-modules)
                                 (when (or (and (not negate?)
                                                ;; Likely checks hl-module subtypes
                                                (member-eq? subtype (missing-larkc 36418)))
                                           (and negate?
                                                ;; Likely checks hl-module subtypes
                                                (not (member-eq? subtype (missing-larkc 36419)))))
                                   (setf applicable-hl-modules
                                         (delete-first supplanted-hl-module applicable-hl-modules #'eq))))))))))
                (let ((supplanted-hl-module (find-hl-module-by-name supplanted-hl-module-pattern)))
                  (pushnew supplanted-hl-module supplanted-hl-modules :test #'eq)
                  (when (member-eq? supplanted-hl-module applicable-hl-modules)
                    (setf applicable-hl-modules
                          (delete-first supplanted-hl-module applicable-hl-modules #'eq))))))))
    (values totally-exclusive-found? applicable-hl-modules supplanted-hl-modules)))

;; (defun update-supplanted-modules-wrt-tactic-specs (hl-module tactic-specs supplanted-hl-modules) ...) -- active declareFunction, no body

(defun compute-tactic-specs-for-asent (applicable-hl-modules asent sense)
  (let ((tactic-specs nil))
    (dolist (hl-module applicable-hl-modules)
      (let ((cost (hl-module-cost hl-module asent sense)))
        (when cost
          (when (and *maximum-hl-module-check-cost*
                     (fully-bound-p asent)
                     (> cost *maximum-hl-module-check-cost*))
            (error "For sentence :~%~S~%Maximum HL Module check cost exceeded by ~A (~A)."
                   asent hl-module cost))
          (let* ((productivity (productivity-for-number-of-children cost))
                 (completeness (hl-module-completeness hl-module asent))
                 (tactic-spec (list hl-module productivity completeness)))
            (push tactic-spec tactic-specs)))))
    tactic-specs))

(defun literal-simple-removal-candidate-hl-modules (asent sense)
  (let ((predicate (atomic-sentence-predicate asent)))
    (if (fort-p predicate)
        (literal-removal-candidate-hl-modules-for-predicate-with-sense predicate sense)
        (generic-removal-modules-for-sense sense))))

(defun literal-removal-candidate-hl-modules-for-predicate-with-sense (predicate sense)
  (let ((inference (current-controlling-inference)))
    (when (and inference
               (inference-problem-store-private? inference))
      (let ((allowed-modules-spec (inference-allowed-modules inference)))
        (return-from literal-removal-candidate-hl-modules-for-predicate-with-sense
          (literal-removal-candidate-hl-modules-for-predicate-with-sense-int predicate sense allowed-modules-spec)))))
  (literal-removal-candidate-hl-modules-for-predicate-with-sense-int predicate sense :all))

(defun-memoized literal-removal-candidate-hl-modules-for-predicate-with-sense-int
    (predicate sense allowed-modules-spec)
    (:test eq)
  (let* ((predicate-specific-removal-modules (removal-modules-specific-for-sense predicate sense))
         (universal-removal-modules (removal-modules-universal-for-predicate-and-sense predicate sense))
         (v-modules nil))
    (if (solely-specific-removal-module-predicate? predicate)
        (setf v-modules (nconc predicate-specific-removal-modules universal-removal-modules))
        (setf v-modules (nconc predicate-specific-removal-modules
                               (generic-removal-modules-for-sense sense)
                               universal-removal-modules)))
    (setf v-modules (filter-modules-wrt-allowed-modules-spec v-modules allowed-modules-spec))
    v-modules))

(defun literal-meta-removal-candidate-hl-modules (asent sense)
  (when (eq sense :neg)
    (return-from literal-meta-removal-candidate-hl-modules nil))
  (let ((predicate (atomic-sentence-predicate asent)))
    (if (fort-p predicate)
        (literal-meta-removal-candidate-hl-modules-for-predicate predicate)
        ;; Likely retrieves generic meta removal modules
        (missing-larkc 36420))))

(defun-memoized literal-meta-removal-candidate-hl-modules-for-predicate
    (predicate)
    (:test equal)
  (let ((v-meta-removal-modules nil))
    (dolist (meta-removal-module (meta-removal-modules))
      (when (predicate-uses-meta-removal-module? predicate meta-removal-module)
        (push meta-removal-module v-meta-removal-modules)))
    (nreverse v-meta-removal-modules)))

(defun literal-level-removal-tactic-p (tactic)
  (and (removal-tactic-p tactic)
       (literal-level-tactic-p tactic)))

(defun literal-level-meta-removal-tactic-p (tactic)
  (and (meta-removal-tactic-p tactic)
       (literal-level-tactic-p tactic)))

(defun new-removal-tactic (problem hl-module productivity completeness)
  (let ((tactic (new-tactic problem hl-module)))
    (set-tactic-productivity tactic productivity)
    (set-tactic-completeness tactic completeness)
    (do-problem-relevant-strategies (strategy problem)
      (strategy-note-new-tactic strategy tactic))
    tactic))

(defun compute-strategic-properties-of-removal-tactic (tactic strategy)
  tactic)

;; Reconstructed from Internal Constants: $list74=((TACTIC MT SENSE) &BODY BODY),
;; $sym75$TACTIC_VAR (gensym), $sym76$WITH-INFERENCE-MT-RELEVANCE,
;; $sym77$*INFERENCE-EXPAND-HL-MODULE*, $sym78$TACTIC-HL-MODULE,
;; $sym79$*INFERENCE-EXPAND-SENSE*, $sym80$WITH-PROBLEM-STORE-REMOVAL-ASSUMPTIONS,
;; $sym81$TACTIC-STORE
;; Expansion: sets up mt relevance, hl module, sense, and store removal assumptions
(defmacro with-removal-tactic-execution-assumptions ((tactic mt sense) &body body)
  (with-temp-vars (tactic-var)
    `(let ((,tactic-var ,tactic))
       (with-inference-mt-relevance ,mt
         (let ((*inference-expand-hl-module* (tactic-hl-module ,tactic-var))
               (*inference-expand-sense* ,sense))
           (with-problem-store-removal-assumptions ((tactic-store ,tactic-var))
             ,@body))))))

(defun execute-literal-level-removal-tactic (tactic mt asent sense)
  (with-removal-tactic-execution-assumptions (tactic mt sense)
    (if (tactic-in-progress? tactic)
        (tactic-in-progress-next tactic)
        (let ((progress-iterator (maybe-make-removal-tactic-progress-iterator tactic asent sense)))
          (cond ((null progress-iterator)
                 nil)
                ((listp progress-iterator)
                 (dolist (execution-result progress-iterator)
                   (handle-one-removal-tactic-expand-result tactic execution-result)))
                (t
                 (note-tactic-progress-iterator tactic progress-iterator))))))
  tactic)

(defun maybe-make-removal-tactic-progress-iterator (tactic asent sense)
  (if (hl-module-output-generate-pattern (tactic-hl-module tactic))
      (maybe-make-removal-tactic-output-generate-progress-iterator tactic asent)
      (maybe-make-removal-tactic-expand-results-progress-iterator tactic asent sense)))

(defun maybe-make-removal-tactic-output-generate-progress-iterator (tactic cycl-input-asent)
  (let ((hl-module (tactic-hl-module tactic)))
    (multiple-value-bind (output-iterator encoded-bindings)
        (maybe-make-inference-output-iterator hl-module cycl-input-asent)
      (when output-iterator
        (possibly-update-tactic-productivity-from-iterator tactic output-iterator)
        (return-from maybe-make-removal-tactic-output-generate-progress-iterator
          (new-removal-tactic-output-generate-progress-iterator tactic output-iterator encoded-bindings)))))
  nil)

(defun new-removal-tactic-output-generate-progress-iterator (tactic output-iterator encoded-bindings)
  (new-tactic-progress-iterator :removal-output-generate tactic (list output-iterator encoded-bindings)))

(defun handle-one-removal-tactic-output-generate-result (removal-tactic output-iterator encoded-bindings)
  (let ((result nil)
        (hl-module (tactic-hl-module removal-tactic))
        (problem (tactic-problem removal-tactic))
        (cycl-input-asent (single-literal-problem-atomic-sentence (tactic-problem removal-tactic))))
    (multiple-value-bind (raw-output valid?)
        (iteration-next output-iterator)
      (when valid?
        (let ((*removal-add-node-method* 'handle-removal-add-node-for-output-generate))
          (decrement-tactic-productivity-for-number-of-children removal-tactic)
          (setf result (handle-one-output-generate-result cycl-input-asent hl-module raw-output encoded-bindings)))))
    result))

(defun handle-removal-add-node-for-output-generate (removal-bindings supports)
  "[Cyc] Return nil or removal-link-p.
REMOVAL-BINDINGS: current tactic's problem vars -> content"
  (setf removal-bindings (inference-simplify-unification-bindings removal-bindings))
  (let ((removal-tactic (currently-executing-tactic)))
    (handle-one-removal-tactic-result removal-tactic removal-bindings supports)))

(defparameter *removal-tactic-iteration-threshold* 2
  "[Cyc] The number of expected removal tactic results at which we generate them iteratively.")

(defparameter *removal-tactic-expand-results-queue* nil)

(defun maybe-make-removal-tactic-expand-results-progress-iterator (tactic asent sense)
  (let ((expand-results (hl-module-guts :maybe-make-removal-tactic-expand-results-progress-iterator
                                        tactic asent sense)))
    (let ((new-productivity (productivity-for-number-of-children (length expand-results))))
      (update-tactic-productivity tactic new-productivity))
    (when (length>= expand-results *removal-tactic-iteration-threshold*)
      (setf expand-results (new-removal-tactic-expand-results-progress-iterator tactic expand-results)))
    expand-results))

(defun maybe-make-removal-tactic-expand-results-progress-iterator-guts (tactic asent sense)
  (let ((expand-results nil))
    (let ((*removal-tactic-expand-results-queue* nil))
      (let ((*removal-add-node-method* 'handle-removal-add-node-for-expand-results))
        (let ((hl-module (tactic-hl-module tactic))
              (pattern nil))
          (setf pattern (hl-module-expand-pattern hl-module))
          (if pattern
              (pattern-transform-formula pattern asent)
              (let ((function (hl-module-expand-func hl-module)))
                (when (possibly-cyc-api-function-spec-p function)
                  (removal-module-expand-func-funcall function asent sense))))))
      (when *removal-tactic-expand-results-queue*
        (setf expand-results (nreverse *removal-tactic-expand-results-queue*))))
    expand-results))

(defun handle-removal-add-node-for-expand-results (removal-bindings supports)
  "[Cyc] Return nil or removal-link-p.
REMOVAL-BINDINGS: current tactic's problem vars -> content"
  (setf removal-bindings (inference-simplify-unification-bindings removal-bindings))
  (push (list removal-bindings supports) *removal-tactic-expand-results-queue*)
  nil)

(defun new-removal-tactic-expand-results-progress-iterator (tactic expand-results)
  (new-tactic-progress-iterator :removal-expand tactic expand-results))

(defun handle-one-removal-tactic-expand-result (removal-tactic expand-result)
  (destructuring-bind (removal-bindings supports) expand-result
    (decrement-tactic-productivity-for-number-of-children removal-tactic)
    (handle-one-removal-tactic-result removal-tactic removal-bindings supports)))

(defun handle-one-removal-tactic-result (removal-tactic removal-bindings supports)
  (let* ((problem (tactic-problem removal-tactic))
         (store (problem-store problem))
         (result nil))
    (setf supports (possibly-replace-ist-supports problem removal-bindings supports))
    (if (not (fully-bound-p supports))
        ;; Likely handles open supports by ignoring the result
        (missing-larkc 32090)
        (multiple-value-bind (mt asent sense)
            (mt-asent-sense-from-single-literal-problem problem)
          (with-removal-tactic-execution-assumptions (removal-tactic mt sense)
            (if (and removal-bindings
                     (problem-store-add-restriction-layer-of-indirection? store))
                (setf result (maybe-new-restriction-and-removal-link problem removal-tactic removal-bindings supports))
                (setf result (maybe-new-removal-link problem removal-tactic removal-bindings supports))))))
    result))

(defun possibly-replace-ist-supports (problem removal-bindings supports)
  (when (ist-problem-p problem)
    (let* ((asent (single-literal-problem-atomic-sentence problem))
           (sentence (apply-bindings removal-bindings asent)))
      ;; Likely computes IST supports from the bound sentence
      (setf supports (missing-larkc 1272))))
  supports)

(defun maybe-new-restriction-and-removal-link (problem tactic removal-bindings supports)
  "[Cyc] REMOVAL-BINDINGS: PROBLEM's vars -> content"
  (let ((restricted-mapped-problem (find-or-create-restricted-problem problem removal-bindings)))
    (maybe-new-removal-link (mapped-problem-problem restricted-mapped-problem) tactic nil supports)
    (maybe-new-restriction-link problem restricted-mapped-problem removal-bindings)))

(defun maybe-new-removal-link (problem tactic removal-bindings supports)
  "[Cyc] Return nil or removal-link-p.
Creates a new removal link to goal iff it would be interesting to do so."
  (declare (type problem-p problem))
  (let ((hl-module (tactic-hl-module tactic)))
    (cond ((not (tactically-good-problem-p problem))
           (new-removal-link problem hl-module removal-bindings supports))
          ((and (removal-tactic-p tactic)
                (not (problem-store-add-restriction-layer-of-indirection? (problem-store problem))))
           (new-removal-link problem hl-module removal-bindings supports))
          (t
           (let ((existing-link (find-removal-link problem tactic removal-bindings supports)))
             (if (problem-link-p existing-link)
                 existing-link
                 (new-removal-link problem hl-module removal-bindings supports)))))))

(defun find-removal-link (problem tactic v-bindings supports)
  (let ((candidate-argument-links (problem-argument-links-lookup problem v-bindings)))
    (when candidate-argument-links
      (dolist (link candidate-argument-links)
        (when (and (removal-link-p link)
                   (eq tactic (removal-link-tactic link))
                   (removal-link-data-equals-spec? link v-bindings supports))
          (return-from find-removal-link link)))))
  nil)

(defun new-removal-proof (removal-link)
  (let ((removal-bindings (removal-link-bindings removal-link)))
    (propose-new-proof-with-bindings removal-link removal-bindings nil)))

;; (defun execute-literal-level-meta-removal-tactic (tactic mt asent sense) ...) -- active declareFunction, no body

(defun inference-remove-check-default (cycl-input-asent &optional sense)
  (let ((hl-module (inference-current-hl-module)))
    (multiple-value-bind (cycl-input extracted-bindings)
        (inference-input-extractor hl-module cycl-input-asent nil)
      (when (inference-input-verifier hl-module cycl-input)
        (multiple-value-bind (raw-input encoded-bindings)
            (inference-input-encoder hl-module cycl-input extracted-bindings)
          (when (inference-output-checker hl-module raw-input encoded-bindings)
            (multiple-value-bind (support more-supports)
                (inference-support-constructor hl-module cycl-input-asent encoded-bindings)
              (removal-add-node support nil more-supports)))))))
  nil)

;; Reconstructed from Internal Constants: $list91=((RAW-OUTPUT RAW-OUTPUT-ITERATOR) &BODY BODY),
;; $sym92$ITERATOR (gensym), $sym93$PIF, $sym94$ITERATOR-P,
;; $sym95$CUNWIND-PROTECT, $sym96$DO-ITERATOR, $sym97$ITERATION-FINALIZE, $sym98$DO-LIST
;; Expansion: iterates RAW-OUTPUT over RAW-OUTPUT-ITERATOR, which may be
;; an iterator-p (using do-iterator with finalize) or a list (using dolist)
(defmacro do-all-legacy-inference-outputs ((raw-output raw-output-iterator) &body body)
  (with-temp-vars (iterator)
    `(let ((,iterator ,raw-output-iterator))
       (if (iterator-p ,iterator)
           (unwind-protect
                (do-iterator-without-values-internal (,raw-output ,iterator)
                  ,@body)
             (iteration-finalize ,iterator))
           (dolist (,raw-output ,iterator)
             ,@body)))))

(defun inference-remove-unify-default (cycl-input-asent &optional sense)
  (let ((hl-module (inference-current-hl-module)))
    (multiple-value-bind (output-iterator encoded-bindings)
        (maybe-make-inference-output-iterator hl-module cycl-input-asent)
      (when output-iterator
        (do-all-legacy-inference-outputs (raw-output output-iterator)
          (handle-one-output-generate-result cycl-input-asent hl-module raw-output encoded-bindings)))))
  nil)

(defun maybe-make-inference-output-iterator (hl-module cycl-input-asent)
  (hl-module-guts :maybe-make-inference-output-iterator hl-module cycl-input-asent))

(defun maybe-make-inference-output-iterator-guts (hl-module cycl-input-asent)
  (multiple-value-bind (cycl-input extracted-bindings)
      (inference-input-extractor hl-module cycl-input-asent nil)
    (when (inference-input-verifier hl-module cycl-input)
      (multiple-value-bind (raw-input encoded-bindings)
          (inference-input-encoder hl-module cycl-input extracted-bindings)
        (let ((output-iterator (inference-output-generator hl-module raw-input encoded-bindings)))
          (return-from maybe-make-inference-output-iterator-guts
            (values output-iterator encoded-bindings))))))
  nil)

(defun handle-one-output-generate-result (cycl-input-asent hl-module raw-output encoded-bindings)
  (multiple-value-bind (success? support unify-bindings more-supports)
      (hl-module-guts :handle-one-output-generate-result cycl-input-asent hl-module raw-output encoded-bindings)
    (when success?
      (removal-add-node support unify-bindings more-supports))))

(defun handle-one-output-generate-result-guts (cycl-input-asent hl-module raw-output encoded-bindings)
  (multiple-value-bind (cycl-output decoded-bindings)
      (inference-output-decoder hl-module raw-output encoded-bindings)
    (when (inference-output-verifier hl-module cycl-output)
      (multiple-value-bind (cycl-output-asent constructed-bindings)
          (inference-output-constructor hl-module cycl-output decoded-bindings)
        (multiple-value-bind (unify-bindings unify-justification)
            (term-unify cycl-input-asent cycl-output-asent t t)
          (when unify-bindings
            (multiple-value-bind (support more-supports)
                (inference-support-constructor hl-module cycl-output-asent constructed-bindings)
              (return-from handle-one-output-generate-result-guts
                (values t support unify-bindings (append more-supports unify-justification)))))))))
  (values nil nil nil nil))

(defun inference-current-hl-module ()
  "[Cyc] If this is ever used outside of an expand function, we will need something more general."
  (inference-expand-hl-module))

(defun inference-current-sense ()
  "[Cyc] If this is ever used outside of an expand function, we will need something more general."
  (inference-expand-sense))

(defun inference-input-extractor (hl-module cycl-input-asent &optional (v-bindings nil))
  (let ((pattern (hl-module-input-extract-pattern hl-module)))
    (pattern-transform-formula pattern cycl-input-asent v-bindings)))

(defun inference-input-verifier (hl-module cycl-input)
  (let ((pattern (hl-module-input-verify-pattern hl-module)))
    (pattern-matches-formula-without-bindings pattern cycl-input)))

(defun inference-input-encoder (hl-module cycl-input &optional (v-bindings nil))
  (let ((pattern (hl-module-input-encode-pattern hl-module)))
    (pattern-transform-tree pattern cycl-input v-bindings)))

(defun inference-output-checker (hl-module raw-input &optional (v-bindings nil))
  (let ((pattern (hl-module-output-check-pattern hl-module)))
    (when (null pattern)
      (return-from inference-output-checker nil))
    (let ((output (pattern-transform-tree pattern raw-input v-bindings)))
      (and output t))))

(defun inference-output-generator (hl-module raw-input &optional (v-bindings nil))
  (let ((pattern (hl-module-output-generate-pattern hl-module)))
    (when (null pattern)
      (return-from inference-output-generator nil))
    (let ((output (pattern-transform-tree pattern raw-input v-bindings)))
      (cond ((iterator-p output)
             output)
            ((listp output)
             (new-list-iterator output))
            (t nil)))))

(defun inference-output-decoder (hl-module raw-output &optional (v-bindings nil))
  (let ((pattern (hl-module-output-decode-pattern hl-module)))
    (pattern-transform-tree pattern raw-output v-bindings)))

(defun inference-output-verifier (hl-module cycl-output)
  (let ((pattern (hl-module-output-verify-pattern hl-module)))
    (pattern-matches-formula-without-bindings pattern cycl-output)))

(defun inference-output-constructor (hl-module cycl-output &optional (v-bindings nil))
  (let ((pattern (hl-module-output-construct-pattern hl-module)))
    (pattern-transform-tree pattern cycl-output v-bindings)))

(defun inference-support-constructor (hl-module cycl-output-asent &optional (v-bindings nil))
  (let* ((support-sense (inference-current-sense))
         (support-sentence (asent-and-sense-to-literal cycl-output-asent support-sense))
         (support-mt (hl-module-support-mt-result hl-module))
         (pattern (hl-module-support-pattern hl-module)))
    (when pattern
      (destructuring-bind (&optional support &rest more-supports)
          (pattern-transform-formula pattern cycl-output-asent v-bindings)
        (return-from inference-support-constructor
          (values support more-supports))))
    (let ((support-func (hl-module-support-func hl-module)))
      (when (possibly-cyc-api-function-spec-p support-func)
        (multiple-value-bind (support more-supports)
            (possibly-cyc-api-funcall-2 support-func support-sentence support-mt)
          (return-from inference-support-constructor
            (values support more-supports)))))
    (let* ((support-module (hl-module-support-module hl-module))
           (support-strength (hl-module-support-strength hl-module))
           (support-tv (tv-from-truth-strength :true support-strength))
           (support (make-hl-support support-module support-sentence support-mt support-tv))
           (more-supports nil))
      (values support more-supports))))

(defun hl-module-guts (type &optional arg1 arg2 arg3 arg4 arg5)
  (case type
    (:determine-new-removal-tactic-specs-from-hl-modules
     (determine-new-removal-tactic-specs-from-hl-modules-guts arg1 arg2 arg3))
    (:maybe-make-removal-tactic-expand-results-progress-iterator
     (maybe-make-removal-tactic-expand-results-progress-iterator-guts arg1 arg2 arg3))
    (:handle-one-output-generate-result
     (handle-one-output-generate-result-guts arg1 arg2 arg3 arg4))
    (:maybe-make-inference-output-iterator
     (maybe-make-inference-output-iterator-guts arg1 arg2))
    (otherwise
     (error "unknown thing to do in the HL module guts: ~s" type))))

;; Variables

(defconstant *dtp-removal-link-data* 'removal-link-data)
(defparameter *conjunctive-removal-tactic-expand-results-queue* nil)
(defparameter *conjunctive-removal-suppress-split-justification?* t
  "[Cyc] Suppress the creation of a split link and child problems for conjunctive removals.  This can vastly reduce the number of problems and proofs for queries with excessive amounts of conjunctive removal.")
(defparameter *conjunctive-removal-optimize-when-no-justifications?* t
  "[Cyc] Temporary control variable, eventually should stay T.
   When non-nil, we skip the restriction/closed problem indirection for answers when we aren't computing justifications.")

;; Setup phase
;; Struct print registration for removal-link-data: handled by defstruct
;; def-csetf registrations: elided (CL setf handles this)
;; note-memoized-function calls: handled by defun-memoized
