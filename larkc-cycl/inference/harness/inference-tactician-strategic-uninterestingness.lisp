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


;;;; Variables

(defparameter *strategy-uninterestingness-explanation* nil
  "[Cyc] Dynamic variable for remembering the most recent explanation of strategic uninterestingness")

(deflexical *the-unknown-strategy-uninterestingness-explanation*
  '(:unknown-reason nil nil nil nil))

(defparameter *strategy-gathering-uninterestingness-explanations?* nil
  "[Cyc] Whether we are gathering explanations of strategic uninterestingness")

(deflexical *strategy-uninterestingness-explanation-table*
  '((:strategy-throws-away-all-transformation ":strategy does not permit transformation at all")
    (:strategy-sets-aside-all-transformation ":strategy does not permit transformation with the current resource constraints")
    (:problem-already-thrown-away ":problem was already noted to be pending")
    (:problem-has-no-transformation-tactics ":problem has no transformation tactics")
    (:problem-strategy-not-continuable ":strategy is not continuable, and :problem was set aside because :subexplanation")
    (:problem-has-no-more-active-removal-strategems ":problem has deactivated all its active removal strategems")
    (:problem-has-no-more-active-transformation-strategems ":problem has deactivated all its active transformation strategems")
    (:problem-has-no-activatible-removal-strategems "when determining removal strategems for :problem, :strategy found none it wished to activate")
    (:problem-has-no-activatible-transformation-strategems "when determining transformation strategems for :problem, :strategy found none it wished to activate")
    (:problem-has-non-abducible-rule-transformation-link "rules associated with tranformation links for :problem were #$NonAbducibleRule so :strategy discarded the abduction strategm")
    (:dont-do-abduction-on-good-problem "problem :problem already deemed good so :strategy discarded the abduction strategm")
    (:dont-transform-on-problem-with-abduced-term "problem :problem has an abduced term so :strategy discarded problem wrt transformation")
    (:all-tactics-thrown-away "all of :problem's tactics are thrown away")
    (:new-root-pending-wrt-motivation ":problem has already propagated both R and T")
    (:problem-already-set-aside ":problem was already noted to be set aside")
    (:all-tactics-set-aside "all of :problem's tactics are set aside")
    (:tactic-already-thrown-away ":tactic was already noted to be finished")
    (:tactic-thrown-away-because-problem-thrown-away ":tactic is thrown away because :subexplanation")
    (:tactic-hl-module-thrown-away ":tactic uses module :tactic-hl-module, which is always thrown away")
    (:tactic-thrown-away-because-lookahead-problem-thrown-away "executing :tactic would motivate a problem that is thrown away because :subexplanation")
    (:split-tactic-thrown-away-because-sibling-tactic-thrown-away ":tactic has a sibling split tactic that is thrown away because :subexplanation")
    (:tactic-strategy-not-continuable ":strategy is not continuable, and :tactic was set aside because :subexplanation")
    (:meta-removal-tactic-thrown-away ":tactic is a meta-removal tactic, and some other tactically possible tactics on the problem are strategically disallowed")
    (:tactic-thrown-away-because-complete-sibling-conjunctive-removal ":tactic has a sibling conjunctive removal tactic that is complete")
    (:tactic-thrown-away-because-sibling-backchain-required ":tactic has a sibling join-ordered tactic that focuses on a backchain required problem")
    (:tactic-thrown-away-because-sibling-is-a-simplification ":tactic has a sibling tactic that is a simplification")
    (:tactic-already-set-aside ":tactic was already noted to be set aside")
    (:tactic-set-aside-because-problem-set-aside ":tactic is set aside because :subexplanation")
    (:tactic-generated-enough ":tactic has already generated enough transformation tactics")
    (:tactic-set-aside-because-lookahead-problem-set-aside "executing :tactic would motivate a problem that is set aside because :subexplanation")
    (:split-tactic-set-aside-because-sibling-tactic-thrown-away ":tactic has a sibling split tactic that is thrown away because :subexplanation")
    (:split-tactic-set-aside-because-sibling-tactic-set-aside ":tactic has a sibling split tactic that is set aside wrt both removal and transformation, because :subexplanation")
    (:logical-tactic-exceeds-max-transformation-depth ":tactic leads past the :max-transformation-depth")
    (:join-ordered-tactic-leads-to-set-aside-conjunctive-removals ":tactic leads to a conjunctive focal problem where all conjunctive removals are set aside")
    (:link-supported-problem-thrown-away ":link's supported problem is thrown away because :subexplanation")
    (:sibling-early-removal-link ":link has a sibling link :subexplanation")
    (:early-removal-link ":link, which is an early removal link")
    (:link-rule-disallowed ":link uses a disallowed rule")
    (:link-supported-problem-set-aside ":link's supported problem is set aside because :subexplanation")
    (:link-exceeds-max-transformation-depth ":link leads past the :max-transformation-depth")
    (:unknown-reason "for an unknown reason")))


;;;; Functions

;; (defun strategic-uninterestingness-reason-p (object) ...) -- active declareFunction, no body
;; (defun strategy-chooses-to-throw-away-problem? (strategy problem &optional motivation) ...) -- active declareFunction, no body
;; (defun why-strategy-chooses-to-throw-away-problem (strategy problem) ...) -- active declareFunction, no body
;; (defun strategy-chooses-to-throw-away-tactic? (strategy tactic motivation justification) ...) -- active declareFunction, no body
;; (defun why-strategy-chooses-to-throw-away-tactic (strategy tactic) ...) -- active declareFunction, no body

(defun legacy-strategy-chooses-to-throw-away-tactic? (strategy tactic &optional motivation)
  (if (balanced-strategy-p strategy)
      (if motivation
          (balanced-strategy-chooses-to-throw-away-tactic? strategy tactic motivation)
          ;; Likely dispatches to all motivations -- evidence: the else branch covers simple-strategy
          (missing-larkc 35581))
      (simple-strategy-chooses-to-throw-away-tactic? strategy tactic)))

;; (defun strategy-chooses-to-set-aside-problem? (strategy problem) ...) -- active declareFunction, no body
;; (defun why-strategy-chooses-to-set-aside-problem (strategy problem) ...) -- active declareFunction, no body
;; (defun strategy-chooses-to-set-aside-tactic? (strategy tactic motivation justification) ...) -- active declareFunction, no body
;; (defun legacy-strategy-chooses-to-set-aside-tactic? (strategy tactic &optional motivation) ...) -- active declareFunction, no body
;; (defun why-strategy-chooses-to-set-aside-tactic (strategy tactic) ...) -- active declareFunction, no body
;; (defun strategy-chooses-to-ignore-tactic? (strategy tactic &optional motivation) ...) -- active declareFunction, no body

(defun simple-strategy-chooses-to-throw-away-problem? (strategy problem)
  (simple-strategy-chooses-to-throw-away-problem-int strategy problem nil))

;; (defun why-simple-strategy-chooses-to-throw-away-problem (strategy problem) ...) -- active declareFunction, no body

(defun simple-strategy-chooses-to-throw-away-problem-int (strategy problem justify?)
  (when (strategy-deems-problem-tactically-uninteresting? strategy problem)
    (if justify?
        (return-from simple-strategy-chooses-to-throw-away-problem-int
          "problem is tactically uninteresting")
        (return-from simple-strategy-chooses-to-throw-away-problem-int t)))
  (let ((inference-chooses-to-throw-away-problem-reason
          (why-inference-chooses-to-throw-away-problem
           (strategy-inference strategy) problem)))
    (when inference-chooses-to-throw-away-problem-reason
      (if justify?
          (return-from simple-strategy-chooses-to-throw-away-problem-int
            inference-chooses-to-throw-away-problem-reason)
          (return-from simple-strategy-chooses-to-throw-away-problem-int t))))
  (when (not (inference-continuable? (strategy-inference strategy)))
    (let ((set-aside-reason (why-simple-strategy-chooses-to-set-aside-problem strategy problem)))
      (when set-aside-reason
        (if justify?
            (return-from simple-strategy-chooses-to-throw-away-problem-int
              (concatenate 'string "inference is not continuable, and " set-aside-reason))
            (return-from simple-strategy-chooses-to-throw-away-problem-int t)))))
  nil)

(defun simple-strategy-chooses-to-throw-away-tactic? (strategy tactic)
  (simple-strategy-chooses-to-throw-away-tactic-int strategy tactic nil))

;; (defun why-simple-strategy-chooses-to-throw-away-tactic (strategy tactic) ...) -- active declareFunction, no body

(defun simple-strategy-chooses-to-throw-away-tactic-int (strategy tactic justify?)
  (when (and (not (good-problem-p (tactic-problem tactic) strategy))
             (problem-has-executed-a-complete-removal-tactic? (tactic-problem tactic) strategy))
    (if justify?
        (return-from simple-strategy-chooses-to-throw-away-tactic-int
          "non-good problem has already executed a complete removal tactic")
        (return-from simple-strategy-chooses-to-throw-away-tactic-int t)))
  (when (simple-strategy-deems-rewrite-tactic-redundant? strategy tactic)
    (if justify?
        (return-from simple-strategy-chooses-to-throw-away-tactic-int
          "rewrite tactic is redundant")
        (return-from simple-strategy-chooses-to-throw-away-tactic-int t)))
  (when (and (transformation-tactic-p tactic)
             (simple-strategy-chooses-to-throw-away-transformation-tactic? strategy tactic))
    (if justify?
        ;; Likely calls why-simple-strategy-chooses-to-throw-away-transformation-tactic -- evidence: parallel pattern in set-aside-tactic-int
        (return-from simple-strategy-chooses-to-throw-away-tactic-int
          (missing-larkc 35546))
        (return-from simple-strategy-chooses-to-throw-away-tactic-int t)))
  (when (not (strategy-allows-use-of-tactic-hl-module? strategy tactic))
    (if justify?
        (return-from simple-strategy-chooses-to-throw-away-tactic-int
          "HL module is forbidden")
        (return-from simple-strategy-chooses-to-throw-away-tactic-int t)))
  (when (not (inference-continuable? (strategy-inference strategy)))
    (let ((strategy-chooses-to-set-aside-tactic-reason
            (why-simple-strategy-chooses-to-set-aside-tactic strategy tactic)))
      (when strategy-chooses-to-set-aside-tactic-reason
        (if justify?
            (return-from simple-strategy-chooses-to-throw-away-tactic-int
              (concatenate 'string "inference is not continuable, and " strategy-chooses-to-set-aside-tactic-reason))
            (return-from simple-strategy-chooses-to-throw-away-tactic-int t)))))
  nil)

(defun problem-has-executed-a-complete-removal-tactic? (problem strategic-context)
  (problem-has-executed-a-complete-tactic? problem strategic-context :generalized-removal))

;; (defun lookahead-problem-has-executed-a-complete-removal-tactic? (problem strategic-context) ...) -- active declareFunction, no body
;; (defun problem-or-lookahead-problem-has-executed-a-complete-removal-tactic? (problem strategic-context) ...) -- active declareFunction, no body
;; (defun problem-has-executed-a-generalized-removal-tactic? (problem) ...) -- active declareFunction, no body

(defun strategy-allows-use-of-tactic-hl-module? (strategy tactic)
  (strategy-allows-use-of-hl-module? strategy (tactic-hl-module tactic)))

(defun strategy-allows-use-of-hl-module? (strategy hl-module)
  (inference-allows-use-of-module? (strategy-inference strategy) hl-module))

(defun simple-strategy-chooses-to-set-aside-problem? (strategy problem)
  (simple-strategy-chooses-to-set-aside-problem-int strategy problem nil))

(defun why-simple-strategy-chooses-to-set-aside-problem (strategy problem)
  (simple-strategy-chooses-to-set-aside-problem-int strategy problem t))

(defun simple-strategy-chooses-to-set-aside-problem-int (strategy problem justify?)
  (when (strategically-totally-no-good-problem-p problem strategy)
    (if justify?
        (return-from simple-strategy-chooses-to-set-aside-problem-int
          "problem is strategically no-good")
        (return-from simple-strategy-chooses-to-set-aside-problem-int t)))
  (let ((inference-chooses-to-set-aside-problem-reason
          (why-inference-chooses-to-set-aside-problem
           (strategy-inference strategy) problem)))
    (when inference-chooses-to-set-aside-problem-reason
      (if justify?
          (return-from simple-strategy-chooses-to-set-aside-problem-int
            inference-chooses-to-set-aside-problem-reason)
          (return-from simple-strategy-chooses-to-set-aside-problem-int t))))
  nil)

(defun simple-strategy-chooses-to-set-aside-tactic? (strategy tactic)
  (simple-strategy-chooses-to-set-aside-tactic-int strategy tactic nil))

(defun why-simple-strategy-chooses-to-set-aside-tactic (strategy tactic)
  (simple-strategy-chooses-to-set-aside-tactic-int strategy tactic t))

(defun simple-strategy-chooses-to-set-aside-tactic-int (strategy tactic justify?)
  (when (and (or (content-tactic-p tactic)
                 (not (problem-store-transformation-allowed?
                       (strategy-problem-store strategy))))
             (tactic-exceeds-productivity-limit? tactic strategy))
    (if justify?
        (return-from simple-strategy-chooses-to-set-aside-tactic-int
          "tactic exceeds productivity limit")
        (return-from simple-strategy-chooses-to-set-aside-tactic-int t)))
  (when (transformation-tactic-p tactic)
    (let ((strategy-chooses-to-set-aside-transformation-tactic-reason
            (why-simple-strategy-chooses-to-set-aside-transformation-tactic strategy tactic)))
      (when strategy-chooses-to-set-aside-transformation-tactic-reason
        (if justify?
            (return-from simple-strategy-chooses-to-set-aside-tactic-int
              strategy-chooses-to-set-aside-transformation-tactic-reason)
            (return-from simple-strategy-chooses-to-set-aside-tactic-int t)))))
  nil)

;; (defun simple-strategy-chooses-to-ignore-problem? (strategy problem) ...) -- active declareFunction, no body

(defun simple-strategy-chooses-to-ignore-tactic? (strategy tactic)
  (and (or (simple-strategy-chooses-to-throw-away-tactic? strategy tactic)
           (and (inference-continuable? (strategy-inference strategy))
                (simple-strategy-chooses-to-set-aside-tactic? strategy tactic)))
       t))

;; (defun problem-strategically-pending? (problem strategy) ...) -- active declareFunction, no body

(defun strategy-deems-problem-tactically-uninteresting? (strategy problem)
  (and (or (tactically-uninteresting-problem-p problem)
           (strategy-has-enough-proofs-for-problem? strategy problem))
       t))

(defun strategy-has-enough-proofs-for-problem? (strategy problem)
  (and (tactically-good-problem-p problem)
       (or (strategy-wants-one-answer? strategy)
           (and (strategy-unique-wrt-bindings? strategy)
                (or (closed-problem-p problem)
                    (and (eq problem (strategy-root-problem strategy))
                         (inference-no-free-hl-vars?
                          (strategy-inference strategy))))))
       t))

(defun tactically-uninteresting-problem-p (problem)
  (and (or (tactically-no-good-problem-p problem)
           (tactically-examined-problem-p problem)
           (and (tactically-unexamined-problem-p problem)
                (tactically-good-problem-p problem)
                (closed-problem-p problem)))
       t))

;; (defun strategy-deems-problem-strategically-uninteresting? (strategy problem) ...) -- active declareFunction, no body
;; (defun strategically-uninteresting-problem-p (problem strategy) ...) -- active declareFunction, no body

(defun problem-has-relevant-supporting-problem? (problem strategic-context consider-transformation-tactics?)
  (declare (type strategic-context-p strategic-context))
  (if (strategy-p strategic-context)
      (let* ((set-contents-var (problem-argument-links problem))
             (basis-object (do-set-contents-basis-object set-contents-var))
             (state (do-set-contents-initial-state basis-object set-contents-var)))
        (loop until (do-set-contents-done? basis-object state)
              do (let ((argument-link (do-set-contents-next basis-object state)))
                   (when (do-set-contents-element-valid? state argument-link)
                     (when (or consider-transformation-tactics?
                               (not (transformation-link-p argument-link)))
                       (let ((link-var argument-link))
                         (dolist (supporting-mapped-problem
                                  (problem-link-supporting-mapped-problems link-var))
                           (when (do-problem-link-open-match? nil link-var supporting-mapped-problem)
                             (let ((supporting-problem (mapped-problem-problem supporting-mapped-problem))
                                   (variable-map (mapped-problem-variable-map supporting-mapped-problem)))
                               (declare (ignore variable-map))
                               (when (problem-relevant-to-strategy? supporting-problem strategic-context)
                                 (return-from problem-has-relevant-supporting-problem? t))))))))
                 (setf state (do-set-contents-update-state state)))
              finally (return nil))
      (problem-has-argument-link-p problem))))

;; (defun problem-has-interesting-transformation-tactics? (problem strategy) ...) -- active declareFunction, no body
;; (defun problem-no-tactics-strategically-possible? (problem strategy) ...) -- active declareFunction, no body
;; (defun inference-chooses-to-set-aside-problem? (inference problem) ...) -- active declareFunction, no body

(defun why-inference-chooses-to-set-aside-problem (inference problem)
  (inference-chooses-to-set-aside-problem-int inference problem t))

(defun inference-chooses-to-set-aside-problem-int (inference problem justify?)
  (when (not (problem-strictly-within-max-proof-depth? inference problem))
    (if justify?
        (return-from inference-chooses-to-set-aside-problem-int
          "problem exceeds max proof depth")
        (return-from inference-chooses-to-set-aside-problem-int t)))
  nil)

;; (defun inference-chooses-to-throw-away-problem? (inference problem) ...) -- active declareFunction, no body

(defun why-inference-chooses-to-throw-away-problem (inference problem)
  (inference-chooses-to-throw-away-problem-int inference problem t))

(defun inference-chooses-to-throw-away-problem-int (inference problem justify?)
  (when (and (not (inference-allows-use-of-all-rules? inference))
             ;; Likely checks whether all dependent links use forbidden transformations -- evidence: error msg mentions "allowed rules" and "link to this problem"
             (missing-larkc 35378)
             ;; Likely checks whether the problem was linked via transformation -- evidence: the pair of checks combined test rule-linkage
             (missing-larkc 35466))
    (if justify?
        (return-from inference-chooses-to-throw-away-problem-int
          "proof checker mode is enabled and no allowed rules were used to link to this problem")
        (return-from inference-chooses-to-throw-away-problem-int t)))
  nil)

;; (defun all-dependent-links-are-forbidden-transformations? (problem inference) ...) -- active declareFunction, no body
;; (defun transformation-forbidden-by-inference? (transformation-link inference) ...) -- active declareFunction, no body

(defun-memoized inference-chooses-to-throw-away-all-transformations-on-problem?
    (inference problem) (:test eq)
  (inference-chooses-to-throw-away-all-transformations-on-problem-int inference problem nil))

;; (defun why-inference-chooses-to-throw-away-all-transformations-on-problem (inference problem) ...) -- active declareFunction, no body

(defun inference-chooses-to-throw-away-all-transformations-on-problem-int (inference problem justify?)
  (let ((allow-hl-predicate-transformation?
          (inference-allow-hl-predicate-transformation? inference))
        (allow-unbound-predicate-transformation?
          (inference-allow-unbound-predicate-transformation? inference))
        (allow-evaluatable-predicate-transformation?
          (inference-allow-evaluatable-predicate-transformation? inference)))
    (when (not allow-unbound-predicate-transformation?)
      (when (not allow-hl-predicate-transformation?)
        (when (problem-uses-hl-predicate? problem)
          ;; Likely checks collection-backchain-encouraged-problem? -- evidence: error msg says "collectionBackchainEncouraged does not apply"
          (when (not (missing-larkc 35468))
            (if justify?
                (return-from inference-chooses-to-throw-away-all-transformations-on-problem-int
                  "problem uses an HL predicate, HL and unbound predicate transformation are forbidden, and #$collectionBackchainEncouraged does not apply")
                (return-from inference-chooses-to-throw-away-all-transformations-on-problem-int t)))))
      (when (not allow-evaluatable-predicate-transformation?)
        (when (problem-uses-evaluatable-predicate? problem)
          (if justify?
              (return-from inference-chooses-to-throw-away-all-transformations-on-problem-int
                "problem uses an evaluatable predicate and evaluatable predicate transformation is forbidden")
              (return-from inference-chooses-to-throw-away-all-transformations-on-problem-int t)))))
    nil))

;; (defun collection-backchain-encouraged-problem? (problem) ...) -- active declareFunction, no body

(defun problem-uses-hl-predicate? (problem)
  (when (single-literal-problem-p problem)
    (let ((predicate (single-literal-problem-predicate problem)))
      (hl-predicate-p predicate))))

(defun problem-uses-evaluatable-predicate? (problem)
  (when (single-literal-problem-p problem)
    (let ((predicate (single-literal-problem-predicate problem)))
      (and (fort-p predicate)
           (inference-evaluatable-predicate? predicate)
           t))))

(defun simple-strategy-deems-rewrite-tactic-redundant? (strategy tactic)
  "[Cyc] @return booleanp; Whether TACTIC is redundant for STRATEGY to execute, because
the problem store topology indicates that such a rewrite has already been done."
  (when (rewrite-tactic-p tactic)
    (let ((inference (strategy-inference strategy))
          (problem (tactic-problem tactic))
          (new-module (tactic-hl-module tactic)))
      (when (single-literal-problem-p problem)
        (let ((redundant? nil)
              (set-contents-var (problem-dependent-links problem)))
          (let* ((basis-object (do-set-contents-basis-object set-contents-var))
                 (state (do-set-contents-initial-state basis-object set-contents-var)))
            (loop until (or redundant?
                            (do-set-contents-done? basis-object state))
                  do (let ((rewrite-link (do-set-contents-next basis-object state)))
                       (when (do-set-contents-element-valid? state rewrite-link)
                         (when (problem-link-has-type? rewrite-link :rewrite)
                           (let ((old-tactic
                                   ;; Likely calls rewrite-link-tactic -- evidence: accessing the tactic from a rewrite link
                                   (missing-larkc 32968)))
                             (let ((old-module (tactic-hl-module old-tactic)))
                               (when (eq old-module new-module)
                                 (let ((supported-problem (problem-link-supported-problem rewrite-link)))
                                   (when (problem-relevant-to-inference? supported-problem inference)
                                     (setf redundant? t)))))))))
                     (setf state (do-set-contents-update-state state))))
          redundant?)))))

(defun tactic-exceeds-productivity-limit? (tactic strategic-context)
  (when (not (strategy-p strategic-context))
    (return-from tactic-exceeds-productivity-limit? nil))
  (let ((productivity-limit (strategy-productivity-limit strategic-context)))
    (if (infinite-productivity-p productivity-limit)
        nil
        (let ((productivity (tactic-strategic-productivity tactic strategic-context)))
          (productivity-G productivity productivity-limit)))))

;; (defun simple-strategy-chooses-to-set-aside-transformation-tactic? (strategy transformation-tactic) ...) -- active declareFunction, no body

(defun why-simple-strategy-chooses-to-set-aside-transformation-tactic (strategy transformation-tactic)
  (simple-strategy-chooses-to-set-aside-transformation-tactic-int strategy transformation-tactic t))

(defun simple-strategy-chooses-to-set-aside-transformation-tactic-int (strategy transformation-tactic justify?)
  (let ((inference (strategy-inference strategy)))
    (if justify?
        (why-inference-chooses-to-set-aside-transformation-tactic inference transformation-tactic)
        ;; Likely calls inference-chooses-to-set-aside-transformation-tactic? -- evidence: parallel pattern in throw-away-transformation-tactic-int
        (missing-larkc 35475))))

;; (defun inference-chooses-to-set-aside-transformation-tactic? (inference transformation-tactic) ...) -- active declareFunction, no body

(defun why-inference-chooses-to-set-aside-transformation-tactic (inference transformation-tactic)
  (inference-chooses-to-set-aside-transformation-tactic-int inference transformation-tactic t))

(defun inference-chooses-to-set-aside-transformation-tactic-int (inference transformation-tactic justify?)
  (let ((problem (tactic-problem transformation-tactic)))
    (when (not (problem-transformation-allowed-wrt-max-transformation-depth? inference problem))
      (if justify?
          (return-from inference-chooses-to-set-aside-transformation-tactic-int
            "problem exceeds max transformation depth")
          (return-from inference-chooses-to-set-aside-transformation-tactic-int t))))
  nil)

(defun-memoized simple-strategy-chooses-to-throw-away-transformation-tactic?
    (strategy transformation-tactic) (:test eq)
  (simple-strategy-chooses-to-throw-away-transformation-tactic-int strategy transformation-tactic nil))

;; (defun why-simple-strategy-chooses-to-throw-away-transformation-tactic (strategy transformation-tactic) ...) -- active declareFunction, no body

(defun simple-strategy-chooses-to-throw-away-transformation-tactic-int (strategy transformation-tactic justify?)
  (let ((inference (strategy-inference strategy)))
    (if justify?
        ;; Likely calls why-inference-chooses-to-throw-away-transformation-tactic -- evidence: parallel pattern in set-aside variant
        (missing-larkc 35541)
        (inference-chooses-to-throw-away-transformation-tactic? inference transformation-tactic))))

(defun inference-chooses-to-throw-away-transformation-tactic? (inference transformation-tactic)
  (inference-chooses-to-throw-away-transformation-tactic-int inference transformation-tactic nil))

;; (defun why-inference-chooses-to-throw-away-transformation-tactic (inference transformation-tactic) ...) -- active declareFunction, no body

(defun inference-chooses-to-throw-away-transformation-tactic-int (inference transformation-tactic justify?)
  (let ((rule (transformation-tactic-rule transformation-tactic)))
    (when rule
      (when (not (inference-allows-use-of-all-rules? inference))
        (when (not (inference-allows-use-of-rule? inference rule))
          (if justify?
              (return-from inference-chooses-to-throw-away-transformation-tactic-int
                "proof checker mode is enabled, and the rule for this tactic is forbidden")
              (return-from inference-chooses-to-throw-away-transformation-tactic-int t))))
      (when (transformation-rule-has-insufficient-historical-utility? rule)
        (if justify?
            (return-from inference-chooses-to-throw-away-transformation-tactic-int
              "the rule for this tactic has an insuffiently high historical utility")
            (return-from inference-chooses-to-throw-away-transformation-tactic-int t)))))
  (when (meta-transformation-tactic-p transformation-tactic)
    (let ((problem (tactic-problem transformation-tactic)))
      (when (inference-chooses-to-throw-away-all-transformations-on-problem? inference problem)
        (if justify?
            ;; Likely calls why-inference-chooses-to-throw-away-all-transformations-on-problem -- evidence: pattern in other justify paths
            (return-from inference-chooses-to-throw-away-transformation-tactic-int
              (missing-larkc 35540))
            (return-from inference-chooses-to-throw-away-transformation-tactic-int t)))))
  (let ((allow-hl-predicate-transformation? (inference-allow-hl-predicate-transformation? inference)))
    (when (and (not allow-hl-predicate-transformation?)
               (tactic-requires-hl-predicate-transformation? transformation-tactic))
      (if justify?
          (return-from inference-chooses-to-throw-away-transformation-tactic-int
            "tactic requires HL predicate transformation, which is forbidden")
          (return-from inference-chooses-to-throw-away-transformation-tactic-int t))))
  (let ((allow-unbound-predicate-transformation? (inference-allow-unbound-predicate-transformation? inference)))
    (when (and (not allow-unbound-predicate-transformation?)
               (tactic-requires-unbound-predicate-transformation? transformation-tactic))
      (if justify?
          (return-from inference-chooses-to-throw-away-transformation-tactic-int
            "tactic requires unbound predicate transformation, which is forbidden")
          (return-from inference-chooses-to-throw-away-transformation-tactic-int t))))
  (let ((allow-evaluatable-predicate-transformation? (inference-allow-evaluatable-predicate-transformation? inference)))
    (when (and (not allow-evaluatable-predicate-transformation?)
               (tactic-requires-evaluatable-predicate-transformation? transformation-tactic))
      (if justify?
          (return-from inference-chooses-to-throw-away-transformation-tactic-int
            "tactic requires evaluatable predicate transformation, which is forbidden")
          (return-from inference-chooses-to-throw-away-transformation-tactic-int t))))
  nil)

;; (defun strategy-disallows-use-of-hl-module-on-problem? (strategy hl-module problem) ...) -- active declareFunction, no body

(defun tactic-requires-hl-predicate-transformation? (tactic)
  (let ((hl-module (tactic-hl-module tactic))
        (problem (tactic-problem tactic)))
    (hl-module-requires-hl-predicate-transformation? hl-module problem)))

(defun hl-module-requires-hl-predicate-transformation? (hl-module problem)
  (when (transformation-module-p hl-module)
    (cond ((hl-module-only-applies-to-hl-predicates? hl-module)
           (and (not (and (single-literal-problem-p problem)
                          ;; Likely checks whether the problem's predicate is the same as the module's predicate -- evidence: similar pattern checking predicate match
                          (missing-larkc 35469)))
                t))
          ((problem-uses-hl-predicate? problem)
           (and (not (meta-transformation-module-p hl-module))
                t))
          (t nil))))

;; (defun collection-backchain-encouraged-tactic? (tactic) ...) -- active declareFunction, no body
;; (defun collection-backchain-encouraged-asent? (asent mt) ...) -- active declareFunction, no body
;; (defun tactic-problem-uses-hl-predicate? (tactic) ...) -- active declareFunction, no body
;; (defun transformation-tactic-only-applies-to-hl-predicates? (tactic) ...) -- active declareFunction, no body

(defun hl-module-only-applies-to-hl-predicates? (hl-module)
  (let ((predicate (hl-module-predicate hl-module)))
    (hl-predicate-p predicate)))

(defun tactic-requires-unbound-predicate-transformation? (tactic)
  (when (transformation-tactic-p tactic)
    (let ((hl-module (tactic-hl-module tactic)))
      (hl-module-requires-unbound-predicate-transformation? hl-module))))

(defun hl-module-requires-unbound-predicate-transformation? (hl-module)
  (trans-unbound-predicate-module-p hl-module))

(defun tactic-requires-evaluatable-predicate-transformation? (tactic)
  (when (transformation-tactic-p tactic)
    (let ((problem (tactic-problem tactic)))
      (problem-uses-evaluatable-predicate? problem))))

(defun tactic-complete? (tactic strategic-context)
  (eq :complete (tactic-strategic-completeness tactic strategic-context)))

;; (defun tactic-incomplete? (tactic strategic-context) ...) -- active declareFunction, no body

(defun tactic-impossible? (tactic strategic-context)
  (eq :impossible (tactic-strategic-completeness tactic strategic-context)))

(defun tactic-preferred? (tactic strategic-context)
  (eq :preferred (tactic-strategic-preference-level tactic strategic-context)))

;; (defun tactic-dispreferred? (tactic strategic-context) ...) -- active declareFunction, no body

(defun tactic-disallowed? (tactic strategic-context)
  (eq :disallowed (tactic-strategic-preference-level tactic strategic-context)))

(defun problem-has-executed-a-complete-tactic? (problem strategic-context &optional (type :content))
  (when (not (problem-store-removal-allowed? (problem-store problem)))
    (return-from problem-has-executed-a-complete-tactic? nil))
  (dolist (tactic (problem-tactics problem))
    (when (and (do-problem-tactics-type-match tactic type)
               (do-problem-tactics-status-match tactic :executed))
      (when (tactic-complete? tactic strategic-context)
        (return-from problem-has-executed-a-complete-tactic? t))))
  nil)

;; (defun lookahead-problem-has-executed-a-complete-tactic? (problem strategic-context &optional type) ...) -- active declareFunction, no body
;; (defun problem-or-lookahead-problem-has-executed-a-complete-tactic? (problem strategic-context &optional type) ...) -- active declareFunction, no body
;; (defun problem-has-executed-a-preferred-tactic? (problem strategic-context &optional type) ...) -- active declareFunction, no body
;; (defun problem-has-executed-a-tactic-of-type? (problem type) ...) -- active declareFunction, no body

(defun strategy-admits-tactic-wrt-proof-spec? (strategy tactic)
  (when (strategy-admits-all-tactics-wrt-proof-spec? strategy)
    (return-from strategy-admits-tactic-wrt-proof-spec? t))
  (let ((proof-spec
          ;; Likely calls strategy-proof-spec -- evidence: the next function checks against :anything
          (missing-larkc 36473)))
    ;; Likely calls proof-spec-admits-tactic? -- evidence: the function exists as a stub
    (missing-larkc 35496)))

(defun strategy-admits-all-tactics-wrt-proof-spec? (strategy)
  (eq :anything (strategy-proof-spec strategy)))

;; (defun proof-spec-admits-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun meta-tactic-p (tactic) ...) -- active declareFunction, no body
;; (defun disjunctive-proof-spec-admits-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun proof-spec-admits-removal-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun proof-spec-admits-join-ordered-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun proof-spec-admits-join-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun proof-spec-admits-split-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun proof-spec-admits-simplification-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun proof-spec-admits-conjuctive-removal-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun proof-spec-admits-transformation-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun proof-spec-admits-union-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun removal-proof-spec-admits-removal-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun restriction-proof-spec-admits-removal-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun split-proof-spec-admits-split-proof-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun restriction-proof-spec-admits-simplification-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun conjunctive-removal-proof-spec-admits-conjunctive-removal-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun join-ordered-proof-spec-admits-join-ordered-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun union-proof-spec-admits-union-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun residual-transformation-proof-spec-admits-join-ordered-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun join-proof-spec-admits-join-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun transformation-proof-spec-admits-transformation-tactic? (proof-spec tactic) ...) -- active declareFunction, no body
;; (defun ist-sentences-from-clause (clause) ...) -- active declareFunction, no body
;; (defun single-literal-pattern-p (object) ...) -- active declareFunction, no body
;; (defun literal-spec-admits-single-literal-problem? (literal-spec problem) ...) -- active declareFunction, no body
;; (defun mt-asent-sense-from-ist-literal (ist-literal) ...) -- active declareFunction, no body
;; (defun removal-module-spec-admits-removal-module (spec module) ...) -- active declareFunction, no body
;; (defun transformation-module-spec-admits-transformation-module (spec module) ...) -- active declareFunction, no body
;; (defun proof-spec-mt-spec-admits-mt? (mt-spec mt) ...) -- active declareFunction, no body
;; (defun proof-spec-asent-spec-admits-asent? (asent-spec asent) ...) -- active declareFunction, no body
;; (defun hl-module-spec-admits-hl-module (spec module) ...) -- active declareFunction, no body
;; (defun rule-spec-admits-rule (spec rule) ...) -- active declareFunction, no body

(defun strategy-last-uninterestingness-explanation ()
  (or *strategy-uninterestingness-explanation*
      *the-unknown-strategy-uninterestingness-explanation*))


;;;; Macros

;; Reconstructed from Internal Constants:
;; $sym63$CLET -> let binding
;; $list64 -> ((*strategy-gathering-uninterestingness-explanations?* t))
;; This macro binds the gathering flag to T during execution of body.
(defmacro with-strategy-uninterestingness-explanations (&body body)
  `(let ((*strategy-gathering-uninterestingness-explanations?* t))
     ,@body))

;; Reconstructed from Internal Constants:
;; $list68 -> (EXPLANATION-TYPE (&KEY PROBLEM TACTIC LINK SUBEXPLANATION))
;; $list69 -> (:PROBLEM :TACTIC :LINK :SUBEXPLANATION)
;; $kw70$ALLOW_OTHER_KEYS -> &allow-other-keys
;; $sym75$PWHEN -> conditional guard
;; $sym76$ -> *strategy-gathering-uninterestingness-explanations?*
;; $sym65$STRATEGY_NOTE_UNINTERESTINGNESS_EXPLANATION -> the helper function call
;; This macro conditionally calls strategy-note-uninterestingness-explanation
;; when *strategy-gathering-uninterestingness-explanations?* is non-nil.
(defmacro strategy-possibly-note-uninterestingness-explanation
    (explanation-type &key problem tactic link subexplanation)
  `(when *strategy-gathering-uninterestingness-explanations?*
     (strategy-note-uninterestingness-explanation
      ,explanation-type ,problem ,tactic ,link ,subexplanation)))

;; (defun strategy-note-uninterestingness-explanation (explanation-type problem tactic link subexplanation) ...) -- active declareFunction, no body
;; (defun strategy-uninterestingness-explanation-string (explanation) ...) -- active declareFunction, no body
;; (defun strategy-uninterestingness-explanation-type-p (object) ...) -- active declareFunction, no body
;; (defun strategy-uninterestingness-explanation-p (object) ...) -- active declareFunction, no body
;; (defun strategy-uninterestingness-subexplanation-p (object) ...) -- active declareFunction, no body
;; (defun make-strategy-uninterestingness-explanation (explanation-type &optional problem tactic link subexplanation) ...) -- active declareFunction, no body
;; (defun strategy-uninterestingness-explanation-type (explanation) ...) -- active declareFunction, no body


;;;; Setup

(toplevel
  (note-memoized-function 'inference-chooses-to-throw-away-all-transformations-on-problem?)
  (note-memoized-function 'simple-strategy-chooses-to-throw-away-transformation-tactic?)
  (register-macro-helper 'strategy-note-uninterestingness-explanation
                         'strategy-possibly-note-uninterestingness-explanation))
