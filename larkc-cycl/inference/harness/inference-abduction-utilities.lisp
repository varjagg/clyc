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


(defun reject-proof-due-to-non-abducible-rule? (link supported-problem subproofs)
  (and (problem-store-abduction-allowed? (problem-store supported-problem))
       (transformation-link-p link)
       ;; TODO - missing-larkc 6923: likely checks a property on LINK (transformation link)
       ;;   such as whether its rule is non-abducible; immediately follows transformation-link-p.
       (missing-larkc 6923)
       ;; TODO - missing-larkc 33038: likely iterates SUBPROOFS and checks abducibility there.
       (missing-larkc 33038)))

;; (defun some-abductive-subproof? (subproofs) ...) -- active declareFunction, no body
;; (defun abduction-allowed-on-asent? (asent &optional sense mt) ...) -- active declareFunction, no body
;; (defun non-abducible-sentence? (asent mt) ...) -- active declareFunction, no body
;; (defun non-abducible-relation? (asent &optional mt) ...) -- active declareFunction, no body
;; (defun non-abducible-predicate? (asent &optional mt) ...) -- active declareFunction, no body
;; (defun non-abducible-collection? (asent &optional mt) ...) -- active declareFunction, no body
;; (defun non-abducible-for-argnum? (asent argnum &optional mt) ...) -- active declareFunction, no body
;; (defun non-abducible-wrt-value-in-argnum? (asent argnum value &optional mt) ...) -- active declareFunction, no body
;; (defun non-abducible-wrt-value-in-argnum-via-type? (asent argnum value &optional mt) ...) -- active declareFunction, no body
;; (defun valid-abduction-asent? (asent sense mt arg) ...) -- active declareFunction, no body
;; (defun abduction-admitted-formula (formula mt) ...) -- active declareFunction, no body
;; (defun known-to-be-true-or-false? (asent sense mt) ...) -- active declareFunction, no body
;; (defun provably-false-contextualized-isa-asent? (asent sense mt) ...) -- active declareFunction, no body
;; (defun provably-false-contextualized-tou-asent? (asent mt) ...) -- active declareFunction, no body

(defparameter *abductive-strategy-type* :abductive
  "[Cyc] The strategy type that is best suited for an abductive inference.")

(defun abductive-strategy-p (object)
  (and (strategy-p object)
       (eq :abductive (strategy-type object))))

(defparameter *prune-semantically-bad-new-roots?* nil)

;; (defun abductive-strategy-initialize (strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-no-strategems-active-wrt-removal? (strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-peek-strategem-wrt-removal (strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-no-new-roots? (strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-peek-new-root (strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-chooses-to-throw-away-new-root? (strategy new-root) ...) -- active declareFunction, no body
;; (defun abductive-strategy-new-root-provably-false? (new-root) ...) -- active declareFunction, no body
;; (defun abductive-strategy-no-strategems-active-wrt-transformation? (strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-peek-strategem-wrt-transformation (strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-current-contents (strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-activate-strategem-wrt-removal (strategy strategem) ...) -- active declareFunction, no body
;; (defun abductive-strategy-pop-strategem-wrt-removal (strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-add-new-root (strategy new-root) ...) -- active declareFunction, no body
;; (defun abductive-strategy-pop-new-root (strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-activate-strategem-wrt-transformation (strategy strategem) ...) -- active declareFunction, no body
;; (defun abductive-strategy-pop-strategem-wrt-transformation (strategy) ...) -- active declareFunction, no body

(deflexical *abductive-tactician-removal-heuristics*
  (construct-set-from-list '(:strategic-productivity
                             :delay-abduction)
                           #'eq)
  "[Cyc] The set of heuristics used by the Abductive Balanced Tactician for removal.")

(deflexical *abductive-tactician-transformation-heuristics*
  (construct-set-from-list '(:shallow-and-cheap
                             :completeness
                             :occams-razor
                             :magic-wand
                             :backchain-required
                             :rule-a-priori-utility
                             :relevant-term
                             :rule-historical-utility
                             :literal-count)
                           #'eq)
  "[Cyc] The set of heuristics used by the Abductive Balanced Tactician for transformation.")

;; (defun abductive-tactician-heuristics (tactic-type) ...) -- active declareFunction, no body

;; TODO - active declareMacro, body stripped. Reconstruct from Internal Constants:
;; $list41 = ((HEURISTIC FUNCTION SCALING-FACTOR MOTIVATION &KEY TACTIC DONE) &BODY BODY) -- arglist
;; $list42 = (:TACTIC :DONE) -- known keys
;; $kw43$ALLOW_OTHER_KEYS
;; $sym46$DO_STRATEGIC_HEURISTICS -- wraps this macro
;; $sym47$PWHEN -- filters with when
;; $sym48$ABDUCTIVE_TACTICIAN_STRATEGIC_HEURISTIC_ -- filter predicate
;; $sym49$DO_ABDUCTIVE_TACTICIAN_STRATEGIC_HEURISTICS -- registered as a macro-helper for it
;; Pattern parallels do-heuristic-balanced-tactician-strategic-heuristics (in
;; inference-heuristic-balanced-tactician.lisp) but adds a MOTIVATION positional
;; parameter. The binding of MOTIVATION is not determinable from visible evidence
;; (all downstream consumers have stripped bodies and no strategic-heuristic-motivation
;; accessor exists). Leaving as TODO per "a wrong macro is worse than a TODO".
(defmacro do-abductive-tactician-strategic-heuristics ((heuristic function scaling-factor motivation &key tactic done) &body body)
  (declare (ignore heuristic function scaling-factor motivation tactic done body))
  (error "TODO: do-abductive-tactician-strategic-heuristics macro body not yet reconstructed"))

;; (defun abductive-tactician-strategic-heuristic? (heuristic tactic-type) ...) -- active declareFunction, no body

;; (defun abductive-strategy-removal-strategem-happiness (strategy strategem) ...) -- active declareFunction, no body
;; (defun abductive-strategy-new-root-happiness (strategy new-root) ...) -- active declareFunction, no body
;; (defun abductive-strategy-transformation-tactic-happiness (transformation-tactic strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-transformation-link-happiness (transformation-link strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-logical-tactic-transformation-happiness (logical-tactic strategy) ...) -- active declareFunction, no body
;; (defun abductive-strategy-generic-tactic-happiness (tactic strategy tactic-type) ...) -- active declareFunction, no body
;; (defun abductive-strategy-transformation-strategem-happiness (strategy strategem) ...) -- active declareFunction, no body
;; (defun abductive-strategy-happiness-table (strategy tactic tactic-type) ...) -- active declareFunction, no body
;; (defun strategic-heuristic-strategic-productivity (strategy tactic) ...) -- active declareFunction, no body
;; (defun strategic-heuristic-delay-abduction (strategy tactic) ...) -- active declareFunction, no body
;; (defun transformation-problem-rule-abductive-utility (problem rule) ...) -- active declareFunction, no body
;; (defun push-problem-onto-rule-abductive-utility-stack (problem) ...) -- active declareFunction, no body
;; (defun problem-on-rule-abductive-utility-stack? (problem) ...) -- active declareFunction, no body
;; (defun strategic-heuristic-rule-abductive-utility (strategy tactic) ...) -- active declareFunction, no body
;; (defun compute-problem-rule-abductive-utility (problem rule) ...) -- active declareFunction, no body
;; (defun compute-tactic-rule-abductive-utility (tactic) ...) -- active declareFunction, no body

(defparameter *heuristic-rule-abductive-utility-problem-recursion-stack* nil
  "[Cyc] A set of problems that are currently being evaluated for rule-abductive-utility,
to avoid infinite recursion.")

;; Setup

(toplevel
  (inference-strategy-type
   :abductive
   (list :name "Abductive Search"
         :comment "Similar to the heuristic-balanced Tactician, except the transformation heuristics
are optimized to support the needs of the abductive inference modules."
         :constructor 'abductive-strategy-initialize
         :done? 'balanced-strategy-done?
         :do-one-step 'balanced-strategy-do-one-step
         :possibly-activate-problem 'balanced-strategy-possibly-activate-problem
         :select-best-strategem 'balanced-strategy-default-select-best-strategem
         :throw-away-uninteresting-set-asides 'balanced-strategy-throw-away-uninteresting-set-asides
         :quiesce 'balanced-strategy-quiesce
         :early-removal-productivity-limit 'balanced-strategy-early-removal-productivity-limit
         :new-argument-link 'balanced-strategy-note-argument-link-added
         :new-tactic 'balanced-strategy-note-new-tactic
         :relevant-tactics-wrt-removal 'balanced-strategy-categorize-strategems-wrt-removal
         :split-tactics-possible 'balanced-strategy-note-split-tactics-strategically-possible
         :problem-could-be-pending 'balanced-strategy-consider-that-problem-could-be-strategically-totally-pending
         :problem-nothing-to-do? 'balanced-strategy-problem-totally-pending?
         :peek-removal-strategem 'abductive-strategy-peek-strategem-wrt-removal
         :activate-removal-strategem 'abductive-strategy-activate-strategem-wrt-removal
         :pop-removal-strategem 'abductive-strategy-pop-strategem-wrt-removal
         :no-active-removal-strategems 'abductive-strategy-no-strategems-active-wrt-removal?
         :peek-new-root 'abductive-strategy-peek-new-root
         :activate-new-root 'abductive-strategy-add-new-root
         :pop-new-root 'abductive-strategy-pop-new-root
         :no-new-roots 'abductive-strategy-no-new-roots?
         :throw-away-new-root 'abductive-strategy-chooses-to-throw-away-new-root?
         :peek-transformation-strategem 'abductive-strategy-peek-strategem-wrt-transformation
         :activate-transformation-strategem 'abductive-strategy-activate-strategem-wrt-transformation
         :pop-transformation-strategem 'abductive-strategy-pop-strategem-wrt-transformation
         :no-active-transformation-strategems 'abductive-strategy-no-strategems-active-wrt-transformation?)))

(toplevel
  (note-funcall-helper-function 'abductive-strategy-no-strategems-active-wrt-removal?)
  (note-funcall-helper-function 'abductive-strategy-peek-strategem-wrt-removal)
  (note-funcall-helper-function 'abductive-strategy-no-new-roots?)
  (note-funcall-helper-function 'abductive-strategy-peek-new-root)
  (note-funcall-helper-function 'abductive-strategy-chooses-to-throw-away-new-root?)
  (note-funcall-helper-function 'abductive-strategy-no-strategems-active-wrt-transformation?)
  (note-funcall-helper-function 'abductive-strategy-peek-strategem-wrt-transformation)
  (note-funcall-helper-function 'abductive-strategy-activate-strategem-wrt-removal)
  (note-funcall-helper-function 'abductive-strategy-pop-strategem-wrt-removal)
  (note-funcall-helper-function 'abductive-strategy-add-new-root)
  (note-funcall-helper-function 'abductive-strategy-pop-new-root)
  (note-funcall-helper-function 'abductive-strategy-activate-strategem-wrt-transformation)
  (note-funcall-helper-function 'abductive-strategy-pop-strategem-wrt-transformation))

(toplevel
  (register-macro-helper 'abductive-tactician-strategic-heuristic?
                         'do-abductive-tactician-strategic-heuristics))

(toplevel
  (declare-strategic-heuristic :strategic-productivity
    (list :function 'strategic-heuristic-strategic-productivity
          :scaling-factor 100
          :tactic-type :generalized-removal-or-rewrite
          :pretty-name "Strategic Productivity"
          :comment "Prefer removal tactics with lesser productivity over more productive tactics")))

(toplevel
  (declare-strategic-heuristic :delay-abduction
    (list :function 'strategic-heuristic-delay-abduction
          :scaling-factor 10000
          :tactic-type :generalized-removal-or-rewrite
          :pretty-name "Delay Abductive Tactics"
          :comment "Prefer deductive removal tactics over abductive removal tactics.")))

(toplevel
  (declare-strategic-heuristic :rule-abductive-utility
    (list :function 'strategic-heuristic-rule-abductive-utility
          :scaling-factor 500
          :pretty-name "Abductive Utility"
          :comment "Prefer proof paths using rules that work well for generative abductive inferences,
without considering the situations in which they were used, i.e.
prior probability.  Consider proof paths using no rules to be at 100%.")))
