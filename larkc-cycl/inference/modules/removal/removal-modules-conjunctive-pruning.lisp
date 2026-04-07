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

(deflexical *conjunctive-pruning-module-names*
    (list :residual-transformation-non-wff
          :prune-unknown-sentence-literal-inconsistency
          :prune-rt-problems-applicable-when-typed-only-when-specialization
          :prune-circular-term-of-unit))

(defvar *residual-transformation-validation-enabled?* nil
  "[Cyc] Temporary control variable, should eventually stay T.
When non-nil, we add a conjuctive removal pruning tactic that will force no-goodness on non-WFF conjunctions.")

(defparameter *gathering-problem-query-semantically-invalid-reasons?* nil
  "[Cyc] dynamic variable bound to T when gathering reasons why a problem query was deemed semantically invalid")

(defparameter *problem-query-semantically-invalid-reason* :uninitialized
  "[Cyc] A dynamically bound string representing the reason a problem was deemed semantically invalid")

;; Functions in declareFunction order

(defun conjunctive-pruning-module-p (hl-module)
  (and (hl-module-p hl-module)
       (member-eq? (hl-module-name hl-module) *conjunctive-pruning-module-names*)))

;; Memoized: supporting-residual-conjunction-problem-minimal-problem-query
;; wraps _internal, capacity 1024, test eql
(defun-memoized supporting-residual-conjunction-problem-minimal-problem-query (problem)
    (:capacity 1024)
  "[Cyc] Return a problem query that is a minimal set of literals suitable for simplification and pruning algorithms that only need to check local literal consistency (wrt residual problem literals) since they can assume the parent problem would have been simplified or pruned had it been required (see problem-query-semantically-invalid?)  Specifically, take a residual problem of some residual transformation link and add the literals from the problem query that share variables with the residual problem."
  (let ((problem-query (problem-query problem))
        (relevant-hl-vars nil)
        (done? nil))
    ;; Inline expansion of do-set-contents over problem-dependent-links
    (let* ((set-contents-var (problem-dependent-links problem))
           (basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (or done? (do-set-contents-done? basis-object state))
            do (let ((link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state link)
                   (when (problem-link-has-type? link :residual-transformation)
                     (setf done? t)
                     (let ((residual-problem-query
                             (apply-bindings-backwards
                              ;; Likely calls residual-transformation-link-bindings
                              (missing-larkc 35097)
                              (problem-query
                               ;; Likely calls residual-transformation-link-residual-problem or similar
                               (missing-larkc 35087)))))
                       (setf relevant-hl-vars
                             (tree-gather residual-problem-query #'variable-p))))))
               (setf state (do-set-contents-update-state state))))
    (when relevant-hl-vars
      (let ((new-problem-query nil))
        ;; Inline expansion of do-problem-query-literals over problem-query
        (dolist (contextualized-clause problem-query)
          ;; neg lits
          (dolist (contextualized-asent (neg-lits contextualized-clause))
            (destructuring-bind (mt asent) contextualized-asent
              (when (tree-find-any relevant-hl-vars asent)
                (push (make-contextualized-asent mt asent) new-problem-query))))
          ;; pos lits
          (dolist (contextualized-asent (pos-lits contextualized-clause))
            (destructuring-bind (mt asent) contextualized-asent
              (when (tree-find-any relevant-hl-vars asent)
                (push (make-contextualized-asent mt asent) new-problem-query)))))
        (when new-problem-query
          (setf problem-query
                (new-problem-query-from-contextualized-clause
                 (make-clause nil new-problem-query))))))
    problem-query))

(defun residual-transformation-non-wff-applicability (contextualized-dnf-clause)
  (when *residual-transformation-validation-enabled?*
    (let ((problem (currently-active-problem)))
      (when ;; Likely calls problem-is-a-topological-merging? or similar check on residual transformation
          (missing-larkc 32747)
        (let ((residual-conjunction-query
                (supporting-residual-conjunction-problem-minimal-problem-query problem)))
          (when ;; Likely calls problem-query-semantically-invalid? on residual-conjunction-query
              (missing-larkc 32748)
            (list ;; Likely creates a conjunctive-removal-proof-spec or similar
             (missing-larkc 30269))))))))

;; (defun residual-transformation-non-wff-expand (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun problem-is-a-topological-merging? (problem) ...) -- active declareFunction, no body
;; (defun why-problem-query-semantically-invalid (problem-query) ...) -- active declareFunction, no body
;; (defun problem-query-semantically-invalid? (problem-query) ...) -- active declareFunction, no body
;; (defun problem-query-variable-constraint-tuples (problem-query) ...) -- active declareFunction, no body

;; Memoized: dnf-variable-constraint-tuples
;; wraps _internal, capacity 128, test equal
(defun-memoized dnf-variable-constraint-tuples (dnf)
    (:test equal :capacity 128)
  (let ((tuples nil)
        (time nil)
        (time-var (get-internal-real-time)))
    (setf tuples (remove-if #'thing-tuple?
                             (contextualized-dnf-variables-isa-constraint-tuples dnf)))
    (setf time (/ (- (get-internal-real-time) time-var)
                  internal-time-units-per-second))
    tuples))

;; (defun variable-constraint-tuples-for-var (tuples var) ...) -- active declareFunction, no body
;; (defun variable-semantically-invalid? (tuples) ...) -- active declareFunction, no body

(defun thing-tuple? (tuple)
  (let ((collections (third tuple)))
    (equal collections (list #$Thing))))

(defun prune-unknown-sentence-literal-inconsistency-applicability (contextualized-dnf-clause)
  (let* ((problem (currently-active-problem))
         (problem-query (problem-query problem)))
    ;; Inline expansion of do-problem-query-literals over problem-query
    (dolist (contextualized-clause problem-query)
      ;; neg lits
      (dolist (contextualized-asent (neg-lits contextualized-clause))
        (destructuring-bind (mt asent) contextualized-asent
          (when (eq #$unknownSentence (atomic-sentence-predicate asent))
            (let ((unknown-sentence-asent (atomic-sentence-arg1 asent)))
              ;; Inner loop: search all problem-query literals for matching asent2
              (dolist (contextualized-clause-2 problem-query)
                ;; inner neg lits
                (dolist (contextualized-asent-2 (neg-lits contextualized-clause-2))
                  (destructuring-bind (mt2 asent2) contextualized-asent-2
                    (when (equal asent2 unknown-sentence-asent)
                      (return-from prune-unknown-sentence-literal-inconsistency-applicability
                        (list ;; Likely creates a conjunctive-removal-proof-spec
                         (missing-larkc 30270))))))
                ;; inner pos lits
                (dolist (contextualized-asent-2 (pos-lits contextualized-clause-2))
                  (destructuring-bind (mt2 asent2) contextualized-asent-2
                    (when (equal asent2 unknown-sentence-asent)
                      (return-from prune-unknown-sentence-literal-inconsistency-applicability
                        (list ;; Likely creates a conjunctive-removal-proof-spec
                         (missing-larkc 30271)))))))))))
      ;; pos lits
      (dolist (contextualized-asent (pos-lits contextualized-clause))
        (destructuring-bind (mt asent) contextualized-asent
          (when (eq #$unknownSentence (atomic-sentence-predicate asent))
            (let ((unknown-sentence-asent (atomic-sentence-arg1 asent)))
              ;; Inner loop: search all problem-query literals for matching asent2
              (dolist (contextualized-clause-2 problem-query)
                ;; inner neg lits
                (dolist (contextualized-asent-2 (neg-lits contextualized-clause-2))
                  (destructuring-bind (mt2 asent2) contextualized-asent-2
                    (when (equal asent2 unknown-sentence-asent)
                      (return-from prune-unknown-sentence-literal-inconsistency-applicability
                        (list ;; Likely creates a conjunctive-removal-proof-spec
                         (missing-larkc 30272))))))
                ;; inner pos lits
                (dolist (contextualized-asent-2 (pos-lits contextualized-clause-2))
                  (destructuring-bind (mt2 asent2) contextualized-asent-2
                    (when (equal asent2 unknown-sentence-asent)
                      (return-from prune-unknown-sentence-literal-inconsistency-applicability
                        (list ;; Likely creates a conjunctive-removal-proof-spec
                         (missing-larkc 30273))))))))))))
    nil))

;; (defun prune-unknown-sentence-literal-inconsistency-expand (contextualized-dnf-clause) ...) -- active declareFunction, no body

(defun prune-rt-problems-applicable-when-typed-only-when-specialization-applicability (contextualized-dnf-clause)
  (let ((problem (currently-active-problem)))
    ;; Inline expansion of do-set-contents over problem-dependent-links
    (let* ((set-contents-var (problem-dependent-links problem))
           (basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state link)
                   (when (problem-link-has-type? link :residual-transformation)
                     (let ((jo-link
                             ;; Likely calls residual-transformation-link-supporting-join-ordered-link or similar
                             (missing-larkc 35071))
                           (transformation-link
                             ;; Likely calls join-ordered-link-non-focal-link or similar to get the transformation link
                             (missing-larkc 35084)))
                       (if ;; Likely calls transformation-non-applicable-due-to-rule-type-contraint-meta-assertion?
                           (missing-larkc 32750)
                           (return-from prune-rt-problems-applicable-when-typed-only-when-specialization-applicability
                             (list ;; Likely creates a conjunctive-removal-proof-spec
                              (missing-larkc 30274)))
                           (return-from prune-rt-problems-applicable-when-typed-only-when-specialization-applicability
                             nil))))))
               (setf state (do-set-contents-update-state state)))))
  nil)

;; (defun transformation-non-applicable-due-to-rule-type-contraint-meta-assertion? (transformation-link contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun prune-rt-problems-applicable-when-typed-only-when-specialization-expand (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun prune-circular-term-of-unit-applicability (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun prune-circular-term-of-unit-expand (contextualized-dnf-clause) ...) -- active declareFunction, no body

;; Setup phase

(toplevel
  (inference-conjunctive-removal-module :residual-transformation-non-wff
    (list :every-predicates nil
          :applicability 'residual-transformation-non-wff-applicability
          :completeness :complete
          :exclusive t
          :cost-expression 0
          :expand 'residual-transformation-non-wff-expand
          :documentation "(#$and <lit0> ... <litN>)
    which has a dependent residual transformation link
    and is non-wff"
          :example "(#$and
      (#$isa ?AGENT #$City)
      (#$spouse ?AGENT ?SPOUSE))")))

(toplevel
  (note-memoized-function 'supporting-residual-conjunction-problem-minimal-problem-query))

(toplevel
  (note-funcall-helper-function 'residual-transformation-non-wff-applicability))

(toplevel
  (note-funcall-helper-function 'residual-transformation-non-wff-expand))

(toplevel
  (note-memoized-function 'dnf-variable-constraint-tuples))

(toplevel
  (inference-conjunctive-removal-module :prune-unknown-sentence-literal-inconsistency
    (list :every-predicates nil
          :applicability 'prune-unknown-sentence-literal-inconsistency-applicability
          :completeness :complete
          :exclusive t
          :cost-expression 0
          :expand 'prune-unknown-sentence-literal-inconsistency-expand
          :documentation "(#$and <lit0> ... <litN> ... (#$unknownSentence <litN>) ...)"
          :example "(#$and
      (#$children ?ANIMAL ?CHILD)
      (#$unknownSentence (#$children ?ANIMAL ?CHILD)))")))

(toplevel
  (note-funcall-helper-function 'prune-unknown-sentence-literal-inconsistency-applicability))

(toplevel
  (note-funcall-helper-function 'prune-unknown-sentence-literal-inconsistency-expand))

(toplevel
  (inference-conjunctive-removal-module :prune-rt-problems-applicable-when-typed-only-when-specialization
    (list :every-predicates nil
          :applicability 'prune-rt-problems-applicable-when-typed-only-when-specialization-applicability
          :completeness :complete
          :exclusive t
          :cost-expression 0
          :expand 'prune-rt-problems-applicable-when-typed-only-when-specialization-expand
          :documentation "Apply to problems created via residual transformation where the rule has a #$applicableWhenTypedOnlyWhenSpecialization assertion on it.")))

(toplevel
  (note-funcall-helper-function 'prune-rt-problems-applicable-when-typed-only-when-specialization-applicability))

(toplevel
  (note-funcall-helper-function 'prune-rt-problems-applicable-when-typed-only-when-specialization-expand))

(toplevel
  (inference-conjunctive-removal-module :prune-circular-term-of-unit
    (list :every-predicates (list #$termOfUnit)
          :applicability 'prune-circular-term-of-unit-applicability
          :completeness :complete
          :exclusive t
          :cost-expression 0
          :expand 'prune-circular-term-of-unit-expand
          :documentation "Applies to syntactically circular termOfUnit literals, for instance (#$termOfUnit ?var0 (#$MotherFn ?var0))")))

(toplevel
  (note-funcall-helper-function 'prune-circular-term-of-unit-applicability))

(toplevel
  (note-funcall-helper-function 'prune-circular-term-of-unit-expand))
