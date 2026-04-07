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

(defparameter *balanced-strategy-uninterestingness-explanation* nil
  "[Cyc] Dynamic variable for remembering the most recent explanation of strategic uninterestingness")

(deflexical *the-unknown-balanced-strategy-uninterestingness-explanation*
  '(:unknown-reason nil nil nil nil))

(defparameter *balanced-strategy-gathering-uninterestingness-explanations?* nil
  "[Cyc] Whether we are gathering explanations of strategic uninterestingness")

(deflexical *balanced-strategy-uninterestingness-explanation-table*
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

(defparameter *balanced-strategy-uses-already-thrown-away-cache?* t
  "[Cyc] Bound to NIL when trying to rederive the reason that something was put in the cache.")

(defvar *balanced-strategy-throw-away-problem-with-abduced-term-wrt-transformation?* t)

(defparameter *suppress-balanced-strategy-can-deem-tactics-harmless-wrt-removal-motivation?* t
  "[Cyc] Temporary control variable; should eventually stay T
Disable the code that gives tactics removal motivation when they possibly otherwise would not.")

(defparameter *balanced-strategy-weaken-split-tactic-set-aside-policy?* nil
  "[Cyc] Temporary control parameter;
When non-nil, the set-aside policy for split tactics is weakened to be more conservative.")


;;;; Macros

;; Reconstructed from Internal Constants:
;;   $sym1$CLET = CLET
;;   $list2 = ((*BALANCED-STRATEGY-GATHERING-UNINTERESTINGNESS-EXPLANATIONS?* T))
;; Simple binding macro that enables gathering of uninterestingness explanations.
(defmacro with-balanced-strategy-uninterestingness-explanations (&body body)
  `(clet ((*balanced-strategy-gathering-uninterestingness-explanations?* t))
     ,@body))

;; Reconstructed from Internal Constants:
;;   $list6 = (EXPLANATION-TYPE (&KEY PROBLEM TACTIC LINK SUBEXPLANATION))
;;   $sym13$PWHEN, $sym14$*BALANCED-STRATEGY-GATHERING-UNINTERESTINGNESS-EXPLANATIONS?*
;;   $sym3$BALANCED-STRATEGY-NOTE-UNINTERESTINGNESS-EXPLANATION (registered macro helper)
;; Conditionally notes an uninterestingness explanation when gathering is enabled.
(defmacro balanced-strategy-possibly-note-uninterestingness-explanation
    (explanation-type &key problem tactic link subexplanation)
  `(pwhen *balanced-strategy-gathering-uninterestingness-explanations?*
     (balanced-strategy-note-uninterestingness-explanation
      ,explanation-type ,problem ,tactic ,link ,subexplanation)))


;;;; Functions

(defun balanced-strategy-last-uninterestingness-explanation ()
  (or *balanced-strategy-uninterestingness-explanation*
      *the-unknown-balanced-strategy-uninterestingness-explanation*))

;; Active declareFunction, no body:
;; (defun balanced-strategy-note-uninterestingness-explanation (explanation-type problem tactic link subexplanation) ...) -- active declareFunction, no body
;; (defun balanced-strategy-uninterestingness-explanation-string (explanation-type) ...) -- active declareFunction, no body
;; (defun balanced-strategy-uninterestingness-explanation-type-p (object) ...) -- active declareFunction, no body
;; (defun balanced-strategy-uninterestingness-explanation-p (object) ...) -- active declareFunction, no body
;; (defun balanced-strategy-uninterestingness-subexplanation-p (object) ...) -- active declareFunction, no body
;; (defun make-balanced-strategy-uninterestingness-explanation (type &optional problem tactic link subexplanation) ...) -- active declareFunction, no body
;; (defun balanced-strategy-uninterestingness-explanation-type (explanation) ...) -- active declareFunction, no body

(defun balanced-strategy-set-aside-non-continuable-implies-throw-away-tactic? (tactic motivation)
  "[Cyc] Whether :set-aside plus non-continuable should be strengthened to :throw-away for TACTIC.
This is usually T except for special circumstances, e.g. split tactic removal lookahead when transformation is allowed."
  (if (and (eq :removal motivation)
           (split-tactic-p tactic)
           (problem-store-transformation-allowed? (tactic-store tactic)))
      nil
      *set-aside-non-continuable-implies-throw-away?*))

(defun balanced-strategy-set-aside-non-continuable-implies-throw-away-problem? (problem motivation)
  "[Cyc] Whether :set-aside plus non-continuable should be strengthened to :throw-away for PROBLEM.
This is usually T except for special circumstances, e.g. if PROBLEM is a split problem and transformation is allowed."
  (declare (ignore problem motivation))
  *set-aside-non-continuable-implies-throw-away?*)

;; (defun balanced-strategy-why-problem-already-thrown-away? (strategy problem motivation) ...) -- active declareFunction, no body
;; (defun rederive-why-balanced-strategy-chooses-to-throw-away-problem? (strategy problem motivation) ...) -- active declareFunction, no body

(defun balanced-strategy-chooses-to-throw-away-problem? (strategy problem motivation &optional (consider-all-tactics? t))
  "[Cyc] @return booleanp; whether STRATEGY, after careful deliberation, chooses to throw away PROBLEM wrt MOTIVATION."
  (declare (type symbol motivation))
  (cond
    ((balanced-strategy-chooses-to-throw-away-problem-uncacheable? strategy problem motivation consider-all-tactics?)
     t)
    (t
     (let ((throw-away (problem-thrown-away-cache-status-wrt-motivation problem strategy motivation)))
       (if (booleanp throw-away)
           throw-away
           (let ((throw-away? (balanced-strategy-chooses-to-throw-away-problem-cacheable? strategy problem motivation consider-all-tactics?)))
             (if throw-away?
                 (progn
                   (when *balanced-strategy-gathering-uninterestingness-explanations?*
                     ;; Likely records the uninterestingness explanation for the thrown-away problem
                     (missing-larkc 35583))
                   (set-problem-thrown-away-wrt problem strategy motivation))
                 (set-problem-not-thrown-away-wrt problem strategy motivation))
             throw-away?))))))

(defun balanced-strategy-chooses-to-throw-away-problem-uncacheable? (strategy problem motivation consider-all-tactics?)
  "[Cyc] The parts of throw-away reasoning that must always be recomputed and cannot be cached
because it's too hard to figure out when the cache needs to be cleared.
Or perhaps because they're really cheap to recompute."
  (cond
    ((and (eq motivation :transformation)
          (strategy-throws-away-all-transformation? strategy))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :strategy-throws-away-all-transformation explanation
       (missing-larkc 35584))
     t)
    ((and *balanced-strategy-uses-already-thrown-away-cache?*
          (balanced-strategy-problem-thrown-away? strategy problem motivation))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :problem-already-thrown-away explanation
       (missing-larkc 35585))
     t)
    ((and consider-all-tactics?
          (balanced-strategy-chooses-to-throw-away-all-tactics? strategy problem motivation t))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :all-tactics-thrown-away explanation
       (missing-larkc 35586))
     t)
    ((and (balanced-strategy-set-aside-non-continuable-implies-throw-away-problem? problem motivation)
          (not (strategy-continuable? strategy))
          (balanced-strategy-chooses-to-set-aside-problem? strategy problem motivation t t))
     (let ((subexplanation (balanced-strategy-last-uninterestingness-explanation)))
       (declare (ignore subexplanation))
       (when *balanced-strategy-gathering-uninterestingness-explanations?*
         ;; Likely notes :problem-strategy-not-continuable explanation with subexplanation
         (missing-larkc 35587)))
     t)
    (t nil)))

(defun balanced-strategy-chooses-to-throw-away-problem-cacheable? (strategy problem motivation consider-all-tactics?)
  "[Cyc] The parts of throw-away reasoning that can be cached.
The comments before each clause in the pcond indicate the conditions when the cache for TACTIC should be cleared."
  (declare (ignore consider-all-tactics?))
  (cond
    ((simple-strategy-chooses-to-throw-away-problem? strategy problem)
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes the simple strategy throw-away explanation
       (missing-larkc 35588))
     t)
    ((and (eq motivation :transformation)
          (single-literal-problem-p problem)
          (not (problem-has-transformation-tactics? problem)))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :problem-has-no-transformation-tactics explanation
       (missing-larkc 35589))
     t)
    ((and *balanced-strategy-throw-away-problem-with-abduced-term-wrt-transformation?*
          (eq motivation :transformation)
          (abductive-strategy-p strategy)
          (expression-find-if #'abduced-term-p (problem-query problem)))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :dont-transform-on-problem-with-abduced-term explanation
       (missing-larkc 35590))
     t)
    (t nil)))

(defun balanced-strategy-chooses-to-throw-away-strategem? (strategy strategem motivation &optional (problem-already-considered? nil))
  "[Cyc] @param PROBLEM-ALREADY-CONSIDERED?; whether the caller has already considered that the problem of STRATEGEM
might be thrown away wrt MOTIVATION.  If T, the analysis will not be redone."
  (if (tactic-p strategem)
      (let ((tactic strategem))
        (balanced-strategy-chooses-to-throw-away-tactic? strategy tactic motivation problem-already-considered?))
      (let ((link strategem))
        (balanced-strategy-chooses-to-throw-away-link? strategy link motivation problem-already-considered?))))

(defun balanced-strategy-chooses-to-throw-away-tactic? (strategy tactic motivation &optional (problem-already-considered? nil) (siblings-already-considered? nil))
  "[Cyc] @param PROBLEM-ALREADY-CONSIDERED?; whether the caller has already considered that the problem of TACTIC
might be thrown away wrt MOTIVATION.  If T, the analysis will not be redone."
  (declare (type symbol motivation))
  (cond
    ((and (eq motivation :removal)
          (balanced-strategy-deems-tactic-harmless-wrt-removal-motivation? strategy tactic))
     nil)
    ((balanced-strategy-chooses-to-throw-away-tactic-uncacheable? strategy tactic motivation problem-already-considered? siblings-already-considered?)
     t)
    (t
     (let ((throw-away (tactic-thrown-away-cache-status-wrt-motivation tactic strategy motivation)))
       (if (booleanp throw-away)
           throw-away
           (let ((throw-away? (balanced-strategy-chooses-to-throw-away-tactic-cacheable? strategy tactic motivation problem-already-considered? siblings-already-considered?)))
             (if throw-away?
                 (progn
                   (when *balanced-strategy-gathering-uninterestingness-explanations?*
                     ;; Likely records the tactic throw-away explanation
                     (missing-larkc 35591))
                   (set-tactic-thrown-away-wrt tactic strategy motivation))
                 (set-tactic-not-thrown-away-wrt tactic strategy motivation))
             throw-away?))))))

(defun balanced-strategy-chooses-to-throw-away-tactic-uncacheable? (strategy tactic motivation problem-already-considered? siblings-already-considered?)
  "[Cyc] The parts of throw-away reasoning that must always be recomputed and cannot be cached
because it's too hard to figure out when the cache needs to be cleared.
Or perhaps because they're really cheap to recompute."
  (cond
    ((and *balanced-strategy-uses-already-thrown-away-cache?*
          (balanced-strategy-tactic-thrown-away? strategy tactic motivation))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :tactic-already-thrown-away explanation
       (missing-larkc 35592))
     (return-from balanced-strategy-chooses-to-throw-away-tactic-uncacheable? t))
    ((and (eq motivation :transformation)
          (strategy-throws-away-all-transformation? strategy))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :strategy-throws-away-all-transformation explanation
       (missing-larkc 35593))
     (return-from balanced-strategy-chooses-to-throw-away-tactic-uncacheable? t))
    ((balanced-strategy-chooses-to-throw-away-tactic-hl-module-wrt-motivation? strategy tactic motivation)
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :tactic-hl-module-thrown-away explanation
       (missing-larkc 35594))
     (return-from balanced-strategy-chooses-to-throw-away-tactic-uncacheable? t))
    ((not (strategy-admits-tactic-wrt-proof-spec? strategy tactic))
     (return-from balanced-strategy-chooses-to-throw-away-tactic-uncacheable? t))
    ((and (eq motivation :removal)
          (balanced-strategy-chooses-to-throw-away-meta-removal-tactic-wrt-removal? strategy tactic))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :meta-removal-tactic-thrown-away explanation
       (missing-larkc 35595))
     (return-from balanced-strategy-chooses-to-throw-away-tactic-uncacheable? t)))
  (when (not problem-already-considered?)
    (let ((problem (tactic-problem tactic)))
      (when (balanced-strategy-chooses-to-throw-away-problem? strategy problem motivation nil)
        (let ((subexplanation (balanced-strategy-last-uninterestingness-explanation)))
          (declare (ignore subexplanation))
          (when *balanced-strategy-gathering-uninterestingness-explanations?*
            ;; Likely notes :tactic-thrown-away-because-problem-thrown-away explanation with subexplanation
            (missing-larkc 35596)))
        (return-from balanced-strategy-chooses-to-throw-away-tactic-uncacheable? t))))
  (cond
    ((and (eq :removal motivation)
          (content-tactic-p tactic)
          (tactic-impossible? tactic strategy))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes tactic is impossible explanation
       (missing-larkc 35597))
     t)
    ((and (logical-tactic-p tactic)
          (balanced-strategy-chooses-to-throw-away-tactic-lookahead-problem? strategy tactic motivation))
     (let ((subexplanation (balanced-strategy-last-uninterestingness-explanation)))
       (declare (ignore subexplanation))
       (when *balanced-strategy-gathering-uninterestingness-explanations?*
         ;; Likely notes :tactic-thrown-away-because-lookahead-problem-thrown-away explanation with subexplanation
         (missing-larkc 35598)))
     t)
    ((and (eq motivation :removal)
          (not siblings-already-considered?)
          (split-tactic-p tactic)
          ;; Likely calls balanced-strategy-chooses-to-throw-away-split-tactic-wrt-removal?
          (missing-larkc 35580))
     t)
    ((and (eq motivation :transformation)
          (balanced-strategy-transformation-tactic-generated-enough? strategy tactic))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :tactic-generated-enough explanation
       (missing-larkc 35599))
     t)
    ((and (balanced-strategy-set-aside-non-continuable-implies-throw-away-tactic? tactic motivation)
          (not (strategy-continuable? strategy))
          (balanced-strategy-chooses-to-set-aside-tactic? strategy tactic motivation t (eq motivation :removal) t))
     (let ((subexplanation (balanced-strategy-last-uninterestingness-explanation)))
       (declare (ignore subexplanation))
       (when *balanced-strategy-gathering-uninterestingness-explanations?*
         ;; Likely notes :tactic-strategy-not-continuable explanation with subexplanation
         (missing-larkc 35600)))
     t)
    (t nil)))

(defun balanced-strategy-chooses-to-throw-away-tactic-cacheable? (strategy tactic motivation problem-already-considered? siblings-already-considered?)
  "[Cyc] The parts of throw-away reasoning that can be cached.
The comments before each clause in the pcond indicate the conditions when the cache for TACTIC should be cleared."
  (declare (ignore problem-already-considered? siblings-already-considered?))
  (cond
    ((and (eq motivation :removal)
          (abductive-strategy-p strategy)
          ;; Likely calls some abduction-related predicate on the tactic
          (missing-larkc 36439))
     (when (good-problem-p (tactic-problem tactic) strategy)
       (when *balanced-strategy-gathering-uninterestingness-explanations?*
         ;; Likely notes :dont-do-abduction-on-good-problem explanation
         (missing-larkc 35601))
       (return-from balanced-strategy-chooses-to-throw-away-tactic-cacheable? t))
     (when
         ;; Likely calls some abduction-related predicate checking the transformation link
         (missing-larkc 35379)
       (when *balanced-strategy-gathering-uninterestingness-explanations?*
         ;; Likely notes :problem-has-non-abducible-rule-transformation-link explanation
         (missing-larkc 35602))
       (return-from balanced-strategy-chooses-to-throw-away-tactic-cacheable? t))
     nil)
    ((simple-strategy-chooses-to-throw-away-tactic? strategy tactic)
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes the simple strategy throw-away explanation
       (missing-larkc 35603))
     t)
    ((and (eq motivation :removal)
          (connected-conjunction-tactic-p tactic)
          (problem-has-some-complete-non-thrown-away-removal-tactic? (tactic-problem tactic) strategy))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :tactic-thrown-away-because-complete-sibling-conjunctive-removal explanation
       (missing-larkc 35604))
     t)
    ((and (eq :removal motivation)
          (structural-tactic-p tactic)
          (tactic-disallowed? tactic strategy))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes tactic is disallowed explanation
       (missing-larkc 35605))
     t)
    ((and (join-ordered-tactic-p tactic)
          (problem-backchain-required? (tactic-problem tactic))
          (not (eq tactic
                   ;; Likely calls balanced-strategy-preferred-backchain-required-join-ordered-tactic
                   (missing-larkc 35628))))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :tactic-thrown-away-because-sibling-backchain-required explanation
       (missing-larkc 35606))
     t)
    ((and *simplification-tactics-execute-early-and-pass-down-transformation-motivation?*
          (connected-conjunction-tactic-p tactic)
          (balanced-strategy-chooses-to-throw-away-tactic-with-sibling-simplification-tactic? tactic))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :tactic-thrown-away-because-sibling-is-a-simplification explanation
       (missing-larkc 35607))
     t)
    (t nil)))

(defun balanced-strategy-chooses-to-throw-away-tactic-with-sibling-simplification-tactic? (tactic)
  (let ((result nil)
        (tactic-var tactic))
    (dolist (sibling-tactic (problem-tactics (tactic-problem tactic-var)))
      (when result (return))
      (when (not (eq sibling-tactic tactic-var))
        (when (simplification-tactic-p sibling-tactic)
          (setf result t))))
    result))

(defun balanced-strategy-chooses-to-throw-away-link? (strategy link motivation &optional (problem-already-considered? nil))
  "[Cyc] @param PROBLEM-ALREADY-CONSIDERED?; whether the caller has already considered that the supported problem of LINK
might be thrown away wrt MOTIVATION.  If T, the analysis will not be redone."
  (declare (type symbol motivation))
  (when (not problem-already-considered?)
    (let ((problem (problem-link-supported-problem link)))
      (when (balanced-strategy-chooses-to-throw-away-problem? strategy problem motivation)
        (let ((subexplanation (balanced-strategy-last-uninterestingness-explanation)))
          (declare (ignore subexplanation))
          (when *balanced-strategy-gathering-uninterestingness-explanations?*
            ;; Likely notes :link-supported-problem-thrown-away explanation with subexplanation
            (missing-larkc 35608)))
        (return-from balanced-strategy-chooses-to-throw-away-link? t))))
  (cond
    ((and (eq motivation :transformation)
          (connected-conjunction-link-p link)
          (balanced-strategy-link-has-sibling-early-removal-link? strategy link))
     (let ((subexplanation (balanced-strategy-last-uninterestingness-explanation)))
       (declare (ignore subexplanation))
       (when *balanced-strategy-gathering-uninterestingness-explanations?*
         ;; Likely notes :sibling-early-removal-link explanation with subexplanation
         (missing-larkc 35609)))
     t)
    ((and (eq motivation :transformation)
          (transformation-link-p link)
          (not (inference-allows-use-of-rule? (strategy-inference strategy)
                                              (transformation-link-rule-assertion link))))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :link-rule-disallowed explanation
       (missing-larkc 35610))
     nil)
    (t nil)))

(defun why-balanced-strategy-chooses-to-ignore-new-root (strategy problem)
  (cond
    ((problem-invalid-p problem)
     :invalid)
    ((balanced-strategy-chooses-to-throw-away-new-root? strategy problem)
     :throw-away)
    (t nil)))

(defun balanced-strategy-chooses-to-throw-away-new-root? (strategy problem)
  (strategy-dispatch strategy :throw-away-new-root problem))

(defun balanced-strategy-default-chooses-to-throw-away-new-root? (strategy problem)
  (if (not (balanced-strategy-new-root-next-motivation strategy problem))
      (progn
        (when *balanced-strategy-gathering-uninterestingness-explanations?*
          ;; Likely notes :new-root-pending-wrt-motivation explanation
          (missing-larkc 35611))
        t)
      nil))

(defun balanced-strategy-chooses-to-set-aside-problem? (strategy problem motivation &optional (consider-all-tactics? t) (thrown-away-already-considered? nil))
  "[Cyc] @return booleanp; whether STRATEGY, after careful deliberation, chooses to set aside PROBLEM wrt MOTIVATION."
  (declare (type symbol motivation))
  (cond
    ((balanced-strategy-chooses-to-set-aside-problem-uncacheable? strategy problem motivation consider-all-tactics? thrown-away-already-considered?)
     t)
    (t
     (let ((set-aside (problem-set-aside-cache-status-wrt-motivation problem strategy motivation)))
       (if (booleanp set-aside)
           set-aside
           (let ((set-aside? (balanced-strategy-chooses-to-set-aside-problem-cacheable? strategy problem motivation consider-all-tactics? thrown-away-already-considered?)))
             (if set-aside?
                 (progn
                   (when *balanced-strategy-gathering-uninterestingness-explanations?*
                     ;; Likely records the set-aside explanation
                     (missing-larkc 35612))
                   ;; Likely calls set-problem-set-aside-wrt or similar
                   (missing-larkc 36453))
                 (set-problem-not-set-aside-wrt problem strategy motivation))
             set-aside?))))))

(defun balanced-strategy-chooses-to-set-aside-problem-uncacheable? (strategy problem motivation consider-all-tactics? thrown-away-already-considered?)
  "[Cyc] The parts of set-aside reasoning that must always be recomputed and cannot be cached
because it's too hard to figure out when the cache needs to be cleared.
Or perhaps because they're really cheap to recompute."
  (declare (ignore thrown-away-already-considered?))
  (cond
    ((and (eq motivation :transformation)
          (strategy-sets-aside-all-transformation? strategy))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :strategy-sets-aside-all-transformation explanation
       (missing-larkc 35613))
     t)
    ((balanced-strategy-problem-set-aside? strategy problem motivation)
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :problem-already-set-aside explanation
       (missing-larkc 35614))
     t)
    ((and consider-all-tactics?
          (strategically-possible-problem-p problem strategy)
          (balanced-strategy-chooses-to-set-aside-all-tactics? strategy problem motivation t))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :all-tactics-set-aside explanation
       (missing-larkc 35615))
     t)
    (t nil)))

(defun balanced-strategy-chooses-to-set-aside-problem-cacheable? (strategy problem motivation consider-all-tactics? thrown-away-already-considered?)
  "[Cyc] The parts of set-aside reasoning that can be cached.
The comments before each clause in the pcond indicate the conditions when the cache for TACTIC should be cleared."
  (declare (ignore consider-all-tactics?))
  (cond
    ((and (not thrown-away-already-considered?)
          (simple-strategy-chooses-to-set-aside-problem? strategy problem))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes the simple strategy set-aside explanation
       (missing-larkc 35616))
     t)
    (t nil)))

(defun balanced-strategy-chooses-to-set-aside-strategem? (strategy strategem motivation &optional (problem-already-considered? nil) (thrown-away-already-considered? nil))
  (if (tactic-p strategem)
      (let ((tactic strategem))
        (balanced-strategy-chooses-to-set-aside-tactic? strategy tactic motivation problem-already-considered? nil thrown-away-already-considered?))
      (let ((link strategem))
        (balanced-strategy-chooses-to-set-aside-link? strategy link motivation problem-already-considered? thrown-away-already-considered?))))

(defun balanced-strategy-chooses-to-set-aside-tactic? (strategy tactic motivation &optional (problem-already-considered? nil) (siblings-already-considered? nil) (thrown-away-already-considered? nil))
  "[Cyc] @param PROBLEM-ALREADY-CONSIDERED?; whether the caller has already considered that the problem of TACTIC
might be set aside wrt MOTIVATION.  If T, the analysis will not be redone.
@param THROWN-AWAY-ALREADY-CONSIDERED?; don't redo work if this is being called from balanced-strategy-chooses-to-throw-away-tactic?"
  (declare (type symbol motivation))
  (cond
    ((and (eq motivation :removal)
          (balanced-strategy-deems-tactic-harmless-wrt-removal-motivation? strategy tactic))
     nil)
    ((balanced-strategy-chooses-to-set-aside-tactic-uncacheable? strategy tactic motivation problem-already-considered? siblings-already-considered? thrown-away-already-considered?)
     t)
    (t
     (let ((set-aside (tactic-set-aside-cache-status-wrt-motivation tactic strategy motivation)))
       (if (booleanp set-aside)
           set-aside
           (let ((set-aside? (balanced-strategy-chooses-to-set-aside-tactic-cacheable? strategy tactic motivation problem-already-considered? siblings-already-considered? thrown-away-already-considered?)))
             (if set-aside?
                 (progn
                   (when *balanced-strategy-gathering-uninterestingness-explanations?*
                     ;; Likely records the tactic set-aside explanation
                     (missing-larkc 35617))
                   (set-tactic-set-aside-wrt tactic strategy motivation))
                 (set-tactic-not-set-aside-wrt tactic strategy motivation))
             set-aside?))))))

(defun balanced-strategy-chooses-to-set-aside-tactic-uncacheable? (strategy tactic motivation problem-already-considered? siblings-already-considered? thrown-away-already-considered?)
  "[Cyc] The parts of set-aside reasoning that must always be recomputed and cannot be cached
because it's too hard to figure out when the cache needs to be cleared.
Or perhaps because they're really cheap to recompute."
  (cond
    ((balanced-strategy-tactic-set-aside? strategy tactic motivation)
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :tactic-already-set-aside explanation
       (missing-larkc 35618))
     (return-from balanced-strategy-chooses-to-set-aside-tactic-uncacheable? t))
    ((and (not thrown-away-already-considered?)
          (eq motivation :transformation)
          (strategy-throws-away-all-transformation? strategy))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :strategy-throws-away-all-transformation explanation
       (missing-larkc 35619))
     (return-from balanced-strategy-chooses-to-set-aside-tactic-uncacheable? t))
    ((and (eq motivation :transformation)
          (strategy-sets-aside-all-transformation? strategy))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :strategy-sets-aside-all-transformation explanation
       (missing-larkc 35620))
     (return-from balanced-strategy-chooses-to-set-aside-tactic-uncacheable? t)))
  (when (not problem-already-considered?)
    (let ((problem (tactic-problem tactic)))
      (when (balanced-strategy-chooses-to-set-aside-problem? strategy problem motivation nil thrown-away-already-considered?)
        (let ((subexplanation (balanced-strategy-last-uninterestingness-explanation)))
          (declare (ignore subexplanation))
          (when *balanced-strategy-gathering-uninterestingness-explanations?*
            ;; Likely notes :tactic-set-aside-because-problem-set-aside explanation with subexplanation
            (missing-larkc 35621)))
        (return-from balanced-strategy-chooses-to-set-aside-tactic-uncacheable? t))))
  (cond
    ((and (eq motivation :removal)
          (logical-tactic-p tactic)
          (balanced-strategy-chooses-to-set-aside-tactic-lookahead-problem? strategy tactic motivation))
     (let ((subexplanation (balanced-strategy-last-uninterestingness-explanation)))
       (declare (ignore subexplanation))
       (when *balanced-strategy-gathering-uninterestingness-explanations?*
         ;; Likely notes :tactic-set-aside-because-lookahead-problem-set-aside explanation with subexplanation
         (missing-larkc 35622)))
     t)
    ((and (eq motivation :removal)
          (not siblings-already-considered?)
          (split-tactic-p tactic)
          ;; Likely calls balanced-strategy-chooses-to-set-aside-split-tactic-wrt-removal?
          (missing-larkc 35577))
     t)
    (t nil)))

(defun balanced-strategy-chooses-to-set-aside-tactic-cacheable? (strategy tactic motivation problem-already-considered? siblings-already-considered? thrown-away-already-considered?)
  "[Cyc] The parts of set-aside reasoning that can be cached.
The comments before each clause in the pcond indicate the conditions when the cache for TACTIC should be cleared."
  (declare (ignore problem-already-considered? siblings-already-considered?))
  (cond
    ((and (not thrown-away-already-considered?)
          (simple-strategy-chooses-to-set-aside-tactic? strategy tactic))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes the simple strategy set-aside explanation
       (missing-larkc 35623))
     t)
    ((and (eq motivation :transformation)
          (logical-tactic-p tactic)
          (not (logical-tactic-transformation-allowed-wrt-max-transformation-depth? (strategy-inference strategy) tactic)))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :logical-tactic-exceeds-max-transformation-depth explanation
       (missing-larkc 35624))
     t)
    ((and (eq motivation :removal)
          (join-ordered-tactic-p tactic)
          (balanced-strategy-chooses-to-set-aside-join-ordered-tactic-due-to-conjunctive-removal? strategy tactic))
     (when *balanced-strategy-gathering-uninterestingness-explanations?*
       ;; Likely notes :join-ordered-tactic-leads-to-set-aside-conjunctive-removals explanation
       (missing-larkc 35625))
     t)
    (t nil)))

(defun balanced-strategy-transformation-tactic-generated-enough? (strategy tactic)
  "[Cyc] @return booleanp; whether STRATEGY deems that TACTIC has already generated enough transformation
tactics.  TACTIC must be a transformation tactic generator tactic, like TRANS-PREDICATE-POS."
  (when (transformation-generator-tactic-p tactic)
    (let ((inference (strategy-inference strategy)))
      (when (not (inference-allows-use-of-all-rules? inference))
        (let ((allowed-rule-count
                ;; Likely calls inference-allowed-rule-count or similar
                (missing-larkc 35726)))
          (when (eql 0 allowed-rule-count)
            (return-from balanced-strategy-transformation-tactic-generated-enough? t))
          (when (positive-integer-p allowed-rule-count)
            (let ((count 0)
                  (all-allowed-rule-tactics-already-generated? nil))
              (dolist (transformation-tactic (problem-tactics (tactic-problem tactic)))
                (when all-allowed-rule-tactics-already-generated? (return))
                (when (and (do-problem-tactics-type-match transformation-tactic :transformation)
                           (do-problem-tactics-hl-module-match transformation-tactic (tactic-hl-module tactic)))
                  (let ((rule (transformation-tactic-rule transformation-tactic)))
                    (when rule
                      (when (inference-allows-use-of-rule? inference rule)
                        (setf count (+ count 1))
                        (when (= count allowed-rule-count)
                          (setf all-allowed-rule-tactics-already-generated? t)))))))
              (return-from balanced-strategy-transformation-tactic-generated-enough? all-allowed-rule-tactics-already-generated?)))))))
  nil)

(defun balanced-strategy-chooses-to-set-aside-link? (strategy link motivation &optional (problem-already-considered? nil) (thrown-away-already-considered? nil))
  "[Cyc] @param PROBLEM-ALREADY-CONSIDERED?; whether the caller has already considered that the supported problem of LINK
might be set aside wrt MOTIVATION.  If T, the analysis will not be redone."
  (declare (type symbol motivation))
  (when (not problem-already-considered?)
    (let ((problem (problem-link-supported-problem link)))
      (when (balanced-strategy-chooses-to-set-aside-problem? strategy problem motivation t thrown-away-already-considered?)
        (let ((subexplanation (balanced-strategy-last-uninterestingness-explanation)))
          (declare (ignore subexplanation))
          (when *balanced-strategy-gathering-uninterestingness-explanations?*
            ;; Likely notes :link-supported-problem-set-aside explanation with subexplanation
            (missing-larkc 35626)))
        (return-from balanced-strategy-chooses-to-set-aside-link? t))))
  nil)

;; (defun balanced-strategy-chooses-to-ignore-problem? (strategy problem motivation) ...) -- active declareFunction, no body
;; (defun why-balanced-strategy-chooses-to-ignore-problem (strategy problem motivation) ...) -- active declareFunction, no body
;; (defun balanced-strategy-chooses-to-ignore-strategem? (strategy problem motivation) ...) -- active declareFunction, no body

(defun why-balanced-strategy-chooses-to-ignore-strategem (strategy strategem motivation)
  "[Cyc] @return strategic-uninterestingness-reason-p"
  (cond
    ((strategem-invalid-p strategem)
     :invalid)
    ((and (content-tactic-p strategem)
          (tactic-not-possible? strategem))
     :throw-away)
    ((balanced-strategy-chooses-to-throw-away-strategem? strategy strategem motivation)
     :throw-away)
    ((balanced-strategy-chooses-to-set-aside-strategem? strategy strategem motivation nil t)
     :set-aside)
    ((not (problem-relevant-to-strategy? (strategem-problem strategem) strategy))
     :irrelevant)
    (t nil)))

;; (defun balanced-strategy-chooses-to-ignore-tactic? (strategy tactic motivation) ...) -- active declareFunction, no body
;; (defun balanced-strategy-chooses-to-ignore-link? (strategy link motivation) ...) -- active declareFunction, no body
;; (defun balanced-strategy-chooses-to-throw-away-all-tactics-wrt-removal? (strategy problem &optional problem-already-considered?) ...) -- active declareFunction, no body

(defun balanced-strategy-chooses-to-throw-away-all-tactics? (strategy problem motivation &optional (problem-already-considered? nil))
  (when (not problem-already-considered?)
    (when (balanced-strategy-chooses-to-throw-away-problem? strategy problem motivation)
      (return-from balanced-strategy-chooses-to-throw-away-all-tactics? t)))
  (dolist (tactic (problem-tactics problem))
    (when (not (balanced-strategy-chooses-to-throw-away-tactic? strategy tactic motivation t))
      (return-from balanced-strategy-chooses-to-throw-away-all-tactics? nil)))
  t)

(defun balanced-strategy-chooses-to-set-aside-all-tactics? (strategy problem motivation &optional (problem-already-considered? nil))
  (when (not problem-already-considered?)
    (when (balanced-strategy-chooses-to-set-aside-problem? strategy problem motivation)
      (return-from balanced-strategy-chooses-to-set-aside-all-tactics? t)))
  (dolist (tactic (problem-tactics problem))
    (when (not (balanced-strategy-chooses-to-set-aside-tactic? strategy tactic motivation t))
      (return-from balanced-strategy-chooses-to-set-aside-all-tactics? nil)))
  t)

;; (defun balanced-strategy-chooses-to-set-aside-all-conjunctive-removal-tactics? (strategy problem &optional problem-already-considered?) ...) -- active declareFunction, no body

(defun balanced-strategy-chooses-to-set-aside-join-ordered-tactic-due-to-conjunctive-removal? (strategy jo-tactic &optional (problem-already-considered? nil))
  (declare (ignore strategy problem-already-considered?))
  (let ((lookahead-problem (join-ordered-tactic-lookahead-problem jo-tactic)))
    (and (not (single-literal-problem-p lookahead-problem))
         (problem-has-tactic-of-type? lookahead-problem :removal-conjunctive)
         ;; Likely calls balanced-strategy-chooses-to-set-aside-all-conjunctive-removal-tactics?
         (missing-larkc 35575))))

;; (defun balanced-strategy-chooses-to-throw-away-disjunctive-link-wrt-removal? (strategy link) ...) -- active declareFunction, no body
;; (defun balanced-strategy-chooses-to-set-aside-disjunctive-link-wrt-removal? (strategy link) ...) -- active declareFunction, no body

(defun balanced-strategy-chooses-to-throw-away-connected-conjunction-link-wrt-removal? (strategy link)
  (let ((tactic (connected-conjunction-link-tactic link)))
    (when (balanced-strategy-chooses-to-throw-away-tactic? strategy tactic :removal)
      (return-from balanced-strategy-chooses-to-throw-away-connected-conjunction-link-wrt-removal? t)))
  nil)

(defun balanced-strategy-chooses-to-set-aside-connected-conjunction-link-wrt-removal? (strategy link)
  (let ((tactic (connected-conjunction-link-tactic link)))
    (when (balanced-strategy-chooses-to-set-aside-tactic? strategy tactic :removal)
      (return-from balanced-strategy-chooses-to-set-aside-connected-conjunction-link-wrt-removal? t)))
  nil)

;; (defun balanced-strategy-chooses-to-totally-set-aside-tactic? (strategy tactic &optional problem-already-considered? thrown-away-already-considered?) ...) -- active declareFunction, no body
;; (defun balanced-strategy-chooses-to-totally-throw-away-tactic? (strategy tactic &optional problem-already-considered? thrown-away-already-considered?) ...) -- active declareFunction, no body
;; (defun balanced-strategy-chooses-to-totally-ignore-tactic? (strategy tactic) ...) -- active declareFunction, no body

(defun balanced-strategy-chooses-to-throw-away-tactic-hl-module-wrt-motivation? (strategy tactic motivation)
  "[Cyc] Return T iff STRATEGY throws away all tactics involving the HL module of TACTIC wrt MOTIVATION."
  (declare (ignore strategy))
  (cond
    ((and (eq motivation :transformation)
          (join-tactic-p tactic))
     t)
    ((and (eq motivation :removal)
          (transformation-tactic-p tactic))
     t)
    (t nil)))

;; Memoized function pair, both with no body:
;; (defun balanced-strategy-preferred-backchain-required-join-ordered-tactic-internal (strategy problem) ...) -- active declareFunction, no body
;; (defun balanced-strategy-preferred-backchain-required-join-ordered-tactic (strategy problem) ...) -- active declareFunction, no body
;; (defun balanced-strategy-total-transformation-productivity (strategy problem) ...) -- active declareFunction, no body

(defun balanced-strategy-problem-thrown-away? (strategy problem motivation)
  "[Cyc] @return booleanp; whether PROBLEM has MOTIVATION according to STRATEGY,
but is no longer active or set-aside."
  (and (balanced-strategy-problem-pending? strategy problem motivation)
       (not (balanced-strategy-problem-set-aside? strategy problem motivation))))

(defun balanced-strategy-tactic-thrown-away? (strategy tactic motivation)
  (balanced-strategy-strategem-thrown-away? strategy tactic motivation))

(defun balanced-strategy-tactic-set-aside? (strategy tactic motivation)
  (balanced-strategy-strategem-set-aside? strategy tactic motivation))

;; (defun balanced-strategy-deems-link-harmless-wrt-removal-motivation? (strategy link) ...) -- active declareFunction, no body

(defun balanced-strategy-deems-tactic-harmless-wrt-removal-motivation? (strategy tactic)
  "[Cyc] @return booleanp; whether STRATEGY deems it harmless to propagate removal motivation to TACTIC,
even if it appears pointless to do so.  One such case is the 'law of R',
which states that if TACTIC is a logical tactic whose lookahead problem(s) have R,
then it can't hurt to give R to TACTIC.  This is occasionally necessary, in cases of massive
problem reuse, to trigger the propagation of R to some argument* link via transformation
and/or residual transformation."
  (when *suppress-balanced-strategy-can-deem-tactics-harmless-wrt-removal-motivation?*
    (return-from balanced-strategy-deems-tactic-harmless-wrt-removal-motivation? nil))
  (when (and (join-ordered-tactic-p tactic)
             ;; Likely calls a predicate checking if join-ordered tactic's lookahead problems have removal motivation
             (missing-larkc 35582))
    (return-from balanced-strategy-deems-tactic-harmless-wrt-removal-motivation? t))
  nil)

(defun balanced-strategy-chooses-to-throw-away-tactic-lookahead-problem? (strategy logical-tactic motivation)
  (declare (type symbol motivation))
  (if (join-tactic-p logical-tactic)
      (multiple-value-bind (first-problem second-problem)
          (join-tactic-lookahead-problems logical-tactic)
        (cond
          ((or (null first-problem)
               (null second-problem))
           (return-from balanced-strategy-chooses-to-throw-away-tactic-lookahead-problem? nil))
          ((or (strategically-good-problem-p first-problem strategy)
               (strategically-good-problem-p second-problem strategy))
           (return-from balanced-strategy-chooses-to-throw-away-tactic-lookahead-problem? nil))
          ((or (balanced-strategy-chooses-to-throw-away-lookahead-problem? strategy first-problem motivation)
               (balanced-strategy-chooses-to-throw-away-lookahead-problem? strategy second-problem motivation))
           (return-from balanced-strategy-chooses-to-throw-away-tactic-lookahead-problem? t))))
      (let ((lookahead-problem (logical-tactic-lookahead-problem logical-tactic)))
        (cond
          ((strategically-good-problem-p lookahead-problem strategy)
           (return-from balanced-strategy-chooses-to-throw-away-tactic-lookahead-problem? nil))
          ((and lookahead-problem
                (balanced-strategy-chooses-to-throw-away-lookahead-problem? strategy lookahead-problem motivation))
           (return-from balanced-strategy-chooses-to-throw-away-tactic-lookahead-problem? t)))))
  (when (eq motivation :transformation)
    (let ((link (logical-tactic-link logical-tactic)))
      (when (balanced-strategy-chooses-to-throw-away-link? strategy link motivation t)
        (return-from balanced-strategy-chooses-to-throw-away-tactic-lookahead-problem? t))))
  nil)

(defun balanced-strategy-chooses-to-throw-away-lookahead-problem? (strategy lookahead-problem motivation)
  (let ((answer nil))
    (let ((*balanced-strategy-uses-already-thrown-away-cache?*
            (and (eq motivation :removal)
                 (single-literal-problem-p lookahead-problem)
                 (closed-problem-p lookahead-problem))))
      (setf answer (balanced-strategy-chooses-to-throw-away-problem? strategy lookahead-problem motivation)))
    answer))

;; (defun balanced-strategy-chooses-to-throw-away-split-tactic-wrt-removal? (strategy tactic) ...) -- active declareFunction, no body
;; (defun balanced-strategy-chooses-to-throw-away-sibling-split-tactic-wrt-removal? (strategy tactic sibling-tactic) ...) -- active declareFunction, no body

(defun balanced-strategy-link-has-sibling-early-removal-link? (strategy link)
  (when (not (balanced-strategy-early-removal-link? strategy link))
    (let* ((link-var link)
           (supported-problem (problem-link-supported-problem link-var))
           (set-contents-var (problem-argument-links supported-problem))
           (basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((sibling-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state sibling-link)
                   (when (not (eq link-var sibling-link))
                     (when (balanced-strategy-early-removal-link? strategy sibling-link)
                       (when *balanced-strategy-gathering-uninterestingness-explanations?*
                         ;; Likely notes :sibling-early-removal-link explanation with the early removal link
                         (missing-larkc 35627))
                       (return-from balanced-strategy-link-has-sibling-early-removal-link? t)))))
               (setf state (do-set-contents-update-state state)))))
  nil)

;; (defun balanced-strategy-chooses-not-to-activate-any-strategems-on-problem? (strategy problem motivation) ...) -- active declareFunction, no body

(defun balanced-strategy-chooses-to-set-aside-tactic-lookahead-problem? (strategy logical-tactic motivation)
  (if (join-tactic-p logical-tactic)
      (multiple-value-bind (first-problem second-problem)
          (join-tactic-lookahead-problems logical-tactic)
        (cond
          ((or (null first-problem)
               (null second-problem))
           (return-from balanced-strategy-chooses-to-set-aside-tactic-lookahead-problem? nil))
          ((or (strategically-good-problem-p first-problem strategy)
               (strategically-good-problem-p second-problem strategy))
           (return-from balanced-strategy-chooses-to-set-aside-tactic-lookahead-problem? nil))
          ((or (balanced-strategy-chooses-to-set-aside-problem? strategy first-problem motivation)
               (balanced-strategy-chooses-to-set-aside-problem? strategy second-problem motivation))
           (return-from balanced-strategy-chooses-to-set-aside-tactic-lookahead-problem? t))))
      (let ((lookahead-problem (logical-tactic-lookahead-problem logical-tactic)))
        (cond
          ((strategically-good-problem-p lookahead-problem strategy)
           (return-from balanced-strategy-chooses-to-set-aside-tactic-lookahead-problem? nil))
          ((balanced-strategy-chooses-to-set-aside-problem? strategy lookahead-problem motivation)
           (return-from balanced-strategy-chooses-to-set-aside-tactic-lookahead-problem? t)))))
  nil)

;; (defun balanced-strategy-chooses-to-set-aside-split-tactic-wrt-removal? (strategy tactic) ...) -- active declareFunction, no body

(defun balanced-strategy-chooses-to-throw-away-meta-removal-tactic-wrt-removal? (strategy meta-removal-tactic)
  "[Cyc] STRATEGY should throw away META-REMOVAL-TACTIC if it has a sibling tactic that is tactically possible but disallowed by STRATEGY,
because then the intended completeness of META-REMOVAL-TACTIC is inapplicable."
  (when (meta-removal-tactic-p meta-removal-tactic)
    (let ((sibling-disallowed-tactic? nil))
      (dolist (removal-tactic (problem-tactics (tactic-problem meta-removal-tactic)))
        (when sibling-disallowed-tactic? (return))
        (when (and (do-problem-tactics-type-match removal-tactic :generalized-removal)
                   (do-problem-tactics-status-match removal-tactic :possible))
          (when (not (eq removal-tactic meta-removal-tactic))
            (when (not (inference-allows-use-of-module? (strategy-inference strategy)
                                                        (tactic-hl-module removal-tactic)))
              (setf sibling-disallowed-tactic? t)))))
      (return-from balanced-strategy-chooses-to-throw-away-meta-removal-tactic-wrt-removal? sibling-disallowed-tactic?)))
  nil)

(defun balanced-strategy-throw-away-uninteresting-set-asides (strategy)
  (let ((total-thrown-away-count 0)
        (thrown-away-count (balanced-strategy-throw-away-uninteresting-set-asides-int strategy)))
    (setf total-thrown-away-count (+ total-thrown-away-count thrown-away-count))
    (loop while (plusp thrown-away-count)
          do (setf thrown-away-count (balanced-strategy-throw-away-uninteresting-set-asides-int strategy))
             (setf total-thrown-away-count (+ total-thrown-away-count thrown-away-count)))
    total-thrown-away-count))

(defun balanced-strategy-throw-away-uninteresting-set-asides-int (strategy)
  (let ((set-aside-problems (balanced-strategy-set-aside-problems-to-reconsider strategy)))
    (strategy-clear-set-asides strategy)
    (let ((thrown-away-count 0))
      (dolist (set-aside-problem set-aside-problems)
        (if ;; Likely calls a function to check if the problem should be reconsidered
            (missing-larkc 35574)
            ;; Likely calls a function to re-motivate the problem
            (missing-larkc 35462)
            (setf thrown-away-count (+ thrown-away-count 1))))
      thrown-away-count)))

;; (defun balanced-strategy-chooses-to-leave-problem-set-aside? (strategy problem) ...) -- active declareFunction, no body

(defun balanced-strategy-reconsider-set-asides (strategy)
  (balanced-strategy-clear-set-aside-problems strategy)
  (let ((reactivated-count 0))
    (let ((*reconsidering-set-asides?* t))
      (clear-strategy-should-reconsider-set-asides strategy)
      (let* ((set-aside-problems (strategy-all-valid-set-aside-problems strategy))
             (_ (strategy-clear-set-asides strategy))
             (set-aside-problems-in-order (sort set-aside-problems #'< :key #'problem-suid)))
        (declare (ignore _))
        (dolist (set-aside-problem set-aside-problems-in-order)
          (when ;; Likely calls a function to reconsider the set-aside problem
              (missing-larkc 35629)
            (setf reactivated-count (+ reactivated-count 1))))))
    reactivated-count))

(defun balanced-strategy-set-aside-problems-to-reconsider (strategy)
  (strategy-all-valid-set-aside-problems strategy))

;; (defun balanced-strategy-reconsider-one-set-aside (strategy problem) ...) -- active declareFunction, no body


;;;; Setup

(toplevel
  (register-macro-helper 'balanced-strategy-note-uninterestingness-explanation
                         'balanced-strategy-possibly-note-uninterestingness-explanation))

(toplevel
  (note-memoized-function 'balanced-strategy-preferred-backchain-required-join-ordered-tactic))
