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

(defparameter *removal-strategy-uses-already-thrown-away-cache?* t
  "[Cyc] Bound to NIL when trying to rederive the reason that something was put in the cache.")

(defparameter *removal-strategy-weaken-split-tactic-set-aside-policy?* nil
  "[Cyc] Temporary control parameter;
When non-nil, the set-aside policy for split tactics is weakened to be more conservative.")


;;;; Functions

(defun removal-strategy-set-aside-non-continuable-implies-throw-away-tactic? (tactic)
  "[Cyc] Whether :set-aside plus non-continuable should be strengthened to :throw-away for TACTIC.
This is usually T except for special circumstances, e.g. split tactic removal lookahead when transformation is allowed."
  (if (and (split-tactic-p tactic)
           (problem-store-transformation-allowed? (tactic-store tactic)))
      nil
      *set-aside-non-continuable-implies-throw-away?*))

(defun removal-strategy-set-aside-non-continuable-implies-throw-away-problem? (problem)
  "[Cyc] Whether :set-aside plus non-continuable should be strengthened to :throw-away for PROBLEM.
This is usually T except for special circumstances, e.g. if PROBLEM is a split problem and transformation is allowed."
  *set-aside-non-continuable-implies-throw-away?*)

;; (defun removal-strategy-why-problem-already-thrown-away? (strategy problem) ...) -- active declareFunction, no body
;; (defun rederive-why-removal-strategy-chooses-to-throw-away-problem? (strategy problem) ...) -- active declareFunction, no body

(defun removal-strategy-chooses-to-throw-away-problem? (strategy problem &optional (consider-all-tactics? t))
  "[Cyc] @return booleanp; whether STRATEGY, after careful deliberation, chooses to throw away PROBLEM wrt removal."
  (if (removal-strategy-chooses-to-throw-away-problem-uncacheable? strategy problem consider-all-tactics?)
      t
      (let ((throw-away (problem-thrown-away-cache-status problem strategy)))
        (if (booleanp throw-away)
            throw-away
            (let ((throw-away? (removal-strategy-chooses-to-throw-away-problem-cacheable? strategy problem consider-all-tactics?)))
              (if throw-away?
                  (progn
                    (when *strategy-gathering-uninterestingness-explanations?*
                      ;; Likely records uninterestingness explanation for problem throw-away
                      (missing-larkc 35504))
                    (set-problem-thrown-away problem strategy))
                  (set-problem-not-thrown-away problem strategy))
              throw-away?)))))

(defun removal-strategy-chooses-to-throw-away-problem-uncacheable? (strategy problem consider-all-tactics?)
  "[Cyc] The parts of throw-away reasoning that must always be recomputed and cannot be cached
because it's too hard to figure out when the cache needs to be cleared.
Or perhaps because they're really cheap to recompute."
  (cond
    ((and *removal-strategy-uses-already-thrown-away-cache?*
          (removal-strategy-problem-thrown-away? strategy problem))
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records :problem-already-thrown-away explanation
       (missing-larkc 35505))
     t)
    ((and consider-all-tactics?
          (removal-strategy-chooses-to-throw-away-all-tactics? strategy problem t))
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records :all-tactics-thrown-away explanation
       (missing-larkc 35506))
     t)
    ((and (removal-strategy-set-aside-non-continuable-implies-throw-away-problem? problem)
          (not (strategy-continuable? strategy))
          (removal-strategy-chooses-to-set-aside-problem? strategy problem t t))
     (let ((subexplanation (strategy-last-uninterestingness-explanation)))
       (declare (ignore subexplanation))
       (when *strategy-gathering-uninterestingness-explanations?*
         ;; Likely records :problem-strategy-not-continuable with subexplanation
         (missing-larkc 35507)))
     t)
    (t nil)))

(defun removal-strategy-chooses-to-throw-away-problem-cacheable? (strategy problem consider-all-tactics?)
  "[Cyc] The parts of throw-away reasoning that can be cached.
The comments before each clause in the pcond indicate the conditions when the cache for TACTIC should be cleared."
  (declare (ignore consider-all-tactics?))
  (if (simple-strategy-chooses-to-throw-away-problem? strategy problem)
      (progn
        (when *strategy-gathering-uninterestingness-explanations?*
          ;; Likely records simple-strategy throw-away explanation
          (missing-larkc 35508))
        t)
      nil))

(defun removal-strategy-chooses-to-throw-away-strategem? (strategy strategem &optional (problem-already-considered? nil))
  "[Cyc] @param PROBLEM-ALREADY-CONSIDERED?; whether the caller has already considered that the problem of STRATEGEM
might be thrown away wrt removal.  If T, the analysis will not be redone."
  (if (tactic-p strategem)
      (let ((tactic strategem))
        (removal-strategy-chooses-to-throw-away-tactic? strategy tactic problem-already-considered?))
      (let ((link strategem))
        (declare (ignore link))
        ;; Likely calls removal-strategy-chooses-to-throw-away-link? for the link case
        (missing-larkc 35693))))

(defun removal-strategy-chooses-to-throw-away-tactic? (strategy tactic &optional (problem-already-considered? nil) (siblings-already-considered? nil))
  "[Cyc] @param PROBLEM-ALREADY-CONSIDERED?; whether the caller has already considered that the problem of TACTIC
might be thrown away wrt removal..  If T, the analysis will not be redone."
  (if (removal-strategy-chooses-to-throw-away-tactic-uncacheable? strategy tactic problem-already-considered? siblings-already-considered?)
      t
      (let ((throw-away (tactic-thrown-away-cache-status tactic strategy)))
        (if (booleanp throw-away)
            throw-away
            (let ((throw-away? (removal-strategy-chooses-to-throw-away-tactic-cacheable? strategy tactic problem-already-considered? siblings-already-considered?)))
              (if throw-away?
                  (progn
                    (when *strategy-gathering-uninterestingness-explanations?*
                      ;; Likely records uninterestingness explanation for tactic throw-away
                      (missing-larkc 35509))
                    (set-tactic-thrown-away tactic strategy))
                  (set-tactic-not-thrown-away tactic strategy))
              throw-away?)))))

(defun removal-strategy-chooses-to-throw-away-tactic-uncacheable? (strategy tactic problem-already-considered? siblings-already-considered?)
  "[Cyc] The parts of throw-away reasoning that must always be recomputed and cannot be cached
because it's too hard to figure out when the cache needs to be cleared.
Or perhaps because they're really cheap to recompute."
  (cond
    ((and *removal-strategy-uses-already-thrown-away-cache?*
          (removal-strategy-tactic-thrown-away? strategy tactic))
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records :tactic-already-thrown-away explanation
       (missing-larkc 35510))
     t)
    ((removal-strategy-chooses-to-throw-away-tactic-hl-module? strategy tactic)
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records :tactic-hl-module-thrown-away explanation
       (missing-larkc 35511))
     t)
    ((not (strategy-admits-tactic-wrt-proof-spec? strategy tactic))
     t)
    ((removal-strategy-chooses-to-throw-away-meta-removal-tactic? strategy tactic)
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records :meta-removal-tactic-thrown-away explanation
       (missing-larkc 35512))
     t)
    (t
     (when (not problem-already-considered?)
       (let ((problem (tactic-problem tactic)))
         (when (removal-strategy-chooses-to-throw-away-problem? strategy problem nil)
           (let ((subexplanation (strategy-last-uninterestingness-explanation)))
             (declare (ignore subexplanation))
             (when *strategy-gathering-uninterestingness-explanations?*
               ;; Likely records :tactic-thrown-away-because-problem-thrown-away with subexplanation
               (missing-larkc 35513)))
           (return-from removal-strategy-chooses-to-throw-away-tactic-uncacheable? t))))
     (cond
       ((and (content-tactic-p tactic)
             (tactic-impossible? tactic strategy))
        (when *strategy-gathering-uninterestingness-explanations?*
          ;; Likely records "tactic is impossible" explanation
          (missing-larkc 35514))
        t)
       ((and (logical-tactic-p tactic)
             (removal-strategy-chooses-to-throw-away-tactic-lookahead-problem? strategy tactic))
        (let ((subexplanation (strategy-last-uninterestingness-explanation)))
          (declare (ignore subexplanation))
          (when *strategy-gathering-uninterestingness-explanations?*
            ;; Likely records :tactic-thrown-away-because-lookahead-problem-thrown-away with subexplanation
            (missing-larkc 35515)))
        t)
       ((and (not siblings-already-considered?)
             (split-tactic-p tactic)
             (removal-strategy-chooses-to-throw-away-split-tactic? strategy tactic))
        t)
       ((and (removal-strategy-set-aside-non-continuable-implies-throw-away-tactic? tactic)
             (not (strategy-continuable? strategy))
             (removal-strategy-chooses-to-set-aside-tactic? strategy tactic t t t))
        (let ((subexplanation (strategy-last-uninterestingness-explanation)))
          (declare (ignore subexplanation))
          (when *strategy-gathering-uninterestingness-explanations?*
            ;; Likely records :tactic-strategy-not-continuable with subexplanation
            (missing-larkc 35516)))
        t)
       (t nil)))))

(defun removal-strategy-chooses-to-throw-away-tactic-cacheable? (strategy tactic problem-already-considered? siblings-already-considered?)
  "[Cyc] The parts of throw-away reasoning that can be cached.
The comments before each clause in the pcond indicate the conditions when the cache for TACTIC should be cleared."
  (declare (ignore problem-already-considered? siblings-already-considered?))
  (cond
    ((simple-strategy-chooses-to-throw-away-tactic? strategy tactic)
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records simple-strategy throw-away tactic explanation
       (missing-larkc 35517))
     t)
    ((and (connected-conjunction-tactic-p tactic)
          (problem-has-some-complete-non-thrown-away-removal-tactic? (tactic-problem tactic) strategy))
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records :tactic-thrown-away-because-complete-sibling-conjunctive-removal explanation
       (missing-larkc 35518))
     t)
    ((and (structural-tactic-p tactic)
          (tactic-disallowed? tactic strategy))
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records "tactic is disallowed" explanation
       (missing-larkc 35519))
     t)
    (t nil)))

;; (defun removal-strategy-chooses-to-throw-away-tactic-with-sibling-simplification-tactic? (tactic) ...) -- active declareFunction, no body
;; (defun removal-strategy-chooses-to-throw-away-link? (strategy link &optional problem-already-considered?) ...) -- active declareFunction, no body

(defun removal-strategy-chooses-to-set-aside-problem? (strategy problem &optional (consider-all-tactics? t) (thrown-away-already-considered? nil))
  "[Cyc] @return booleanp; whether STRATEGY, after careful deliberation, chooses to set aside PROBLEM wrt removal."
  (if (removal-strategy-chooses-to-set-aside-problem-uncacheable? strategy problem consider-all-tactics? thrown-away-already-considered?)
      t
      (let ((set-aside (problem-set-aside-cache-status problem strategy)))
        (if (booleanp set-aside)
            set-aside
            (let ((set-aside? (removal-strategy-chooses-to-set-aside-problem-cacheable? strategy problem consider-all-tactics? thrown-away-already-considered?)))
              (if set-aside?
                  (progn
                    (when *strategy-gathering-uninterestingness-explanations?*
                      ;; Likely records uninterestingness explanation for problem set-aside
                      (missing-larkc 35521))
                    (set-problem-set-aside problem strategy))
                  (set-problem-not-set-aside problem strategy))
              set-aside?)))))

(defun removal-strategy-chooses-to-set-aside-problem-uncacheable? (strategy problem consider-all-tactics? thrown-away-already-considered?)
  "[Cyc] The parts of set-aside reasoning that must always be recomputed and cannot be cached
because it's too hard to figure out when the cache needs to be cleared.
Or perhaps because they're really cheap to recompute."
  (declare (ignore thrown-away-already-considered?))
  (cond
    ((removal-strategy-problem-set-aside? strategy problem)
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records :problem-already-set-aside explanation
       (missing-larkc 35522))
     t)
    ((and consider-all-tactics?
          (strategically-possible-problem-p problem strategy)
          (removal-strategy-chooses-to-set-aside-all-tactics? strategy problem t))
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records :all-tactics-set-aside explanation
       (missing-larkc 35523))
     t)
    (t nil)))

(defun removal-strategy-chooses-to-set-aside-problem-cacheable? (strategy problem consider-all-tactics? thrown-away-already-considered?)
  "[Cyc] The parts of set-aside reasoning that can be cached.
The comments before each clause in the pcond indicate the conditions when the cache for TACTIC should be cleared."
  (declare (ignore consider-all-tactics?))
  (if (and (not thrown-away-already-considered?)
           (simple-strategy-chooses-to-set-aside-problem? strategy problem))
      (progn
        (when *strategy-gathering-uninterestingness-explanations?*
          ;; Likely records simple-strategy set-aside problem explanation
          (missing-larkc 35524))
        t)
      nil))

(defun removal-strategy-chooses-to-set-aside-strategem? (strategy strategem &optional (problem-already-considered? nil) (thrown-away-already-considered? nil))
  (if (tactic-p strategem)
      (let ((tactic strategem))
        (removal-strategy-chooses-to-set-aside-tactic? strategy tactic problem-already-considered? nil thrown-away-already-considered?))
      (let ((link strategem))
        (declare (ignore link))
        ;; Likely calls removal-strategy-chooses-to-set-aside-link? for the link case
        (missing-larkc 35691))))

(defun removal-strategy-chooses-to-set-aside-tactic? (strategy tactic &optional (problem-already-considered? nil) (siblings-already-considered? nil) (thrown-away-already-considered? nil))
  "[Cyc] @param PROBLEM-ALREADY-CONSIDERED?; whether the caller has already considered that the problem of TACTIC
might be set aside wrt removal.  If T, the analysis will not be redone.
@param THROWN-AWAY-ALREADY-CONSIDERED?; don't redo work if this is being called from removal-strategy-chooses-to-throw-away-tactic?"
  (if (removal-strategy-chooses-to-set-aside-tactic-uncacheable? strategy tactic problem-already-considered? siblings-already-considered? thrown-away-already-considered?)
      t
      (let ((set-aside (tactic-set-aside-cache-status tactic strategy)))
        (if (booleanp set-aside)
            set-aside
            (let ((set-aside? (removal-strategy-chooses-to-set-aside-tactic-cacheable? strategy tactic problem-already-considered? siblings-already-considered? thrown-away-already-considered?)))
              (if set-aside?
                  (progn
                    (when *strategy-gathering-uninterestingness-explanations?*
                      ;; Likely records uninterestingness explanation for tactic set-aside
                      (missing-larkc 35525))
                    ;; Likely calls set-tactic-set-aside
                    (missing-larkc 36465))
                  (set-tactic-not-set-aside tactic strategy))
              set-aside?)))))

(defun removal-strategy-chooses-to-set-aside-tactic-uncacheable? (strategy tactic problem-already-considered? siblings-already-considered? thrown-away-already-considered?)
  "[Cyc] The parts of set-aside reasoning that must always be recomputed and cannot be cached
because it's too hard to figure out when the cache needs to be cleared.
Or perhaps because they're really cheap to recompute."
  (cond
    ((removal-strategy-tactic-set-aside? strategy tactic)
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records :tactic-already-set-aside explanation
       (missing-larkc 35526))
     t)
    (t
     (when (not problem-already-considered?)
       (let ((problem (tactic-problem tactic)))
         (when (removal-strategy-chooses-to-set-aside-problem? strategy problem nil thrown-away-already-considered?)
           (let ((subexplanation (strategy-last-uninterestingness-explanation)))
             (declare (ignore subexplanation))
             (when *strategy-gathering-uninterestingness-explanations?*
               ;; Likely records :tactic-set-aside-because-problem-set-aside with subexplanation
               (missing-larkc 35527)))
           (return-from removal-strategy-chooses-to-set-aside-tactic-uncacheable? t))))
     (cond
       ((and (logical-tactic-p tactic)
             (removal-strategy-chooses-to-set-aside-tactic-lookahead-problem? strategy tactic))
        (let ((subexplanation (strategy-last-uninterestingness-explanation)))
          (declare (ignore subexplanation))
          (when *strategy-gathering-uninterestingness-explanations?*
            ;; Likely records :tactic-set-aside-because-lookahead-problem-set-aside with subexplanation
            (missing-larkc 35528)))
        t)
       ((and (not siblings-already-considered?)
             (split-tactic-p tactic)
             (removal-strategy-chooses-to-set-aside-split-tactic? strategy tactic))
        t)
       (t nil)))))

(defun removal-strategy-chooses-to-set-aside-tactic-cacheable? (strategy tactic problem-already-considered? siblings-already-considered? thrown-away-already-considered?)
  "[Cyc] The parts of set-aside reasoning that can be cached.
The comments before each clause in the pcond indicate the conditions when the cache for TACTIC should be cleared."
  (declare (ignore problem-already-considered? siblings-already-considered?))
  (cond
    ((and (not thrown-away-already-considered?)
          (simple-strategy-chooses-to-set-aside-tactic? strategy tactic))
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records simple-strategy set-aside tactic explanation
       (missing-larkc 35529))
     t)
    ((and (join-ordered-tactic-p tactic)
          (removal-strategy-chooses-to-set-aside-join-ordered-tactic-due-to-conjunctive-removal? strategy tactic))
     (when *strategy-gathering-uninterestingness-explanations?*
       ;; Likely records :join-ordered-tactic-leads-to-set-aside-conjunctive-removals explanation
       (missing-larkc 35530))
     t)
    (t nil)))

;; (defun removal-strategy-chooses-to-set-aside-link? (strategy link &optional problem-already-considered? thrown-away-already-considered?) ...) -- active declareFunction, no body
;; (defun removal-strategy-chooses-to-ignore-problem? (strategy problem) ...) -- active declareFunction, no body

(defun why-removal-strategy-chooses-to-ignore-problem (strategy problem)
  "[Cyc] @return strategic-uninterestingness-reason-p"
  (cond
    ((removal-strategy-chooses-to-throw-away-problem? strategy problem)
     :throw-away)
    ((removal-strategy-chooses-to-set-aside-problem? strategy problem t t)
     :set-aside)
    ((not (problem-relevant-to-strategy? problem strategy))
     :irrelevant)
    (t nil)))

;; (defun removal-strategy-chooses-to-ignore-strategem? (strategy strategem) ...) -- active declareFunction, no body

(defun why-removal-strategy-chooses-to-ignore-strategem (strategy strategem)
  "[Cyc] @return strategic-uninterestingness-reason-p"
  (cond
    ((strategem-invalid-p strategem)
     :invalid)
    ((and (content-tactic-p strategem)
          (tactic-not-possible? strategem))
     :throw-away)
    ((removal-strategy-chooses-to-throw-away-strategem? strategy strategem)
     :throw-away)
    ((removal-strategy-chooses-to-set-aside-strategem? strategy strategem nil t)
     :set-aside)
    ((not (problem-relevant-to-strategy? (strategem-problem strategem) strategy))
     :irrelevant)
    (t nil)))

;; (defun removal-strategy-chooses-to-ignore-tactic? (strategy tactic) ...) -- active declareFunction, no body
;; (defun removal-strategy-chooses-to-ignore-link? (strategy link) ...) -- active declareFunction, no body

(defun removal-strategy-chooses-to-throw-away-all-tactics? (strategy problem &optional (problem-already-considered? nil))
  (when (not problem-already-considered?)
    (when (removal-strategy-chooses-to-throw-away-problem? strategy problem)
      (return-from removal-strategy-chooses-to-throw-away-all-tactics? t)))
  (dolist (tactic (problem-tactics problem))
    (unless (removal-strategy-chooses-to-throw-away-tactic? strategy tactic t)
      (return-from removal-strategy-chooses-to-throw-away-all-tactics? nil)))
  t)

(defun removal-strategy-chooses-to-set-aside-all-tactics? (strategy problem &optional (problem-already-considered? nil))
  (when (not problem-already-considered?)
    (when (removal-strategy-chooses-to-set-aside-problem? strategy problem)
      (return-from removal-strategy-chooses-to-set-aside-all-tactics? t)))
  (dolist (tactic (problem-tactics problem))
    (unless (removal-strategy-chooses-to-set-aside-tactic? strategy tactic t)
      (return-from removal-strategy-chooses-to-set-aside-all-tactics? nil)))
  t)

;; (defun removal-strategy-chooses-to-set-aside-all-conjunctive-removal-tactics? (strategy problem &optional problem-already-considered?) ...) -- active declareFunction, no body

(defun removal-strategy-chooses-to-set-aside-join-ordered-tactic-due-to-conjunctive-removal? (strategy jo-tactic &optional (problem-already-considered? nil))
  (declare (ignore problem-already-considered?))
  (let ((lookahead-problem (join-ordered-tactic-lookahead-problem jo-tactic)))
    (and (not (single-literal-problem-p lookahead-problem))
         (problem-has-tactic-of-type? lookahead-problem :removal-conjunctive)
         ;; Likely checks if all conjunctive removal tactics are set aside
         (missing-larkc 35689))))

;; (defun removal-strategy-chooses-to-throw-away-disjunctive-link? (strategy link) ...) -- active declareFunction, no body
;; (defun removal-strategy-chooses-to-set-aside-disjunctive-link? (strategy link) ...) -- active declareFunction, no body

(defun removal-strategy-chooses-to-throw-away-connected-conjunction-link? (strategy link)
  (let ((tactic (connected-conjunction-link-tactic link)))
    (when (removal-strategy-chooses-to-throw-away-tactic? strategy tactic)
      (return-from removal-strategy-chooses-to-throw-away-connected-conjunction-link? t)))
  nil)

(defun removal-strategy-chooses-to-set-aside-connected-conjunction-link? (strategy link)
  (let ((tactic (connected-conjunction-link-tactic link)))
    (when (removal-strategy-chooses-to-set-aside-tactic? strategy tactic)
      (return-from removal-strategy-chooses-to-set-aside-connected-conjunction-link? t)))
  nil)

(defun removal-strategy-chooses-to-totally-set-aside-tactic? (strategy tactic &optional (problem-already-considered? nil) (siblings-already-considered? nil))
  (declare (ignore strategy tactic problem-already-considered? siblings-already-considered?))
  nil)

(defun removal-strategy-chooses-to-totally-throw-away-tactic? (strategy tactic &optional (problem-already-considered? nil) (siblings-already-considered? nil))
  (controlling-strategy-callback strategy :substrategy-totally-throw-away-tactic tactic problem-already-considered? siblings-already-considered?))

;; (defun removal-strategy-chooses-to-totally-ignore-tactic? (strategy tactic) ...) -- active declareFunction, no body

(defun removal-strategy-chooses-to-throw-away-tactic-hl-module? (strategy tactic)
  "[Cyc] Return T iff STRATEGY throws away all tactics involving the HL module of TACTIC."
  (declare (ignore strategy))
  (if (transformation-tactic-p tactic)
      t
      nil))

;; (defun removal-strategy-preferred-backchain-required-join-ordered-tactic-internal (strategy problem) ...) -- active declareFunction, no body
;; (defun removal-strategy-preferred-backchain-required-join-ordered-tactic (strategy problem) ...) -- active declareFunction, no body
;; (defun removal-strategy-total-transformation-productivity (strategy problem) ...) -- active declareFunction, no body

(defun removal-strategy-problem-thrown-away? (strategy problem)
  "[Cyc] @return booleanp; whether PROBLEM has motivation according to STRATEGY,
but is no longer active or set-aside."
  (declare (type removal-strategy-p strategy))
  (declare (type problem problem))
  (and (removal-strategy-problem-pending? strategy problem)
       (not (removal-strategy-problem-set-aside? strategy problem))))

(defun removal-strategy-tactic-thrown-away? (strategy tactic)
  (removal-strategy-strategem-thrown-away? strategy tactic))

(defun removal-strategy-tactic-set-aside? (strategy tactic)
  (removal-strategy-strategem-set-aside? strategy tactic))

(defun removal-strategy-chooses-to-throw-away-tactic-lookahead-problem? (strategy logical-tactic)
  (cond
    ((join-tactic-p logical-tactic)
     (multiple-value-bind (first-problem second-problem)
         (join-tactic-lookahead-problems logical-tactic)
       (cond
         ((or (null first-problem) (null second-problem))
          nil)
         ((or (strategically-good-problem-p first-problem strategy)
              (strategically-good-problem-p second-problem strategy))
          nil)
         ((or (removal-strategy-chooses-to-throw-away-lookahead-problem? strategy first-problem)
              (removal-strategy-chooses-to-throw-away-lookahead-problem? strategy second-problem))
          t)
         (t nil))))
    (t
     (let ((lookahead-problem (logical-tactic-lookahead-problem logical-tactic)))
       (cond
         ((strategically-good-problem-p lookahead-problem strategy)
          nil)
         (lookahead-problem
          (when (union-tactic-p logical-tactic)
            (determine-strategic-status-wrt lookahead-problem strategy))
          (when (removal-strategy-chooses-to-throw-away-lookahead-problem? strategy lookahead-problem)
            (return-from removal-strategy-chooses-to-throw-away-tactic-lookahead-problem? t))
          nil)
         (t nil))))))

(defun removal-strategy-chooses-to-throw-away-lookahead-problem? (strategy lookahead-problem)
  (let ((answer nil))
    (let ((*removal-strategy-uses-already-thrown-away-cache?*
            (and (single-literal-problem-p lookahead-problem)
                 (closed-problem-p lookahead-problem))))
      (setf answer (removal-strategy-chooses-to-throw-away-problem? strategy lookahead-problem)))
    answer))

(defun removal-strategy-chooses-to-throw-away-split-tactic? (strategy split-tactic)
  (do-tactic-sibling-tactics (sibling-tactic split-tactic :type :split)
    (when (removal-strategy-chooses-to-throw-away-sibling-split-tactic? strategy split-tactic sibling-tactic)
      (return-from removal-strategy-chooses-to-throw-away-split-tactic? t))
    (let ((lookahead-problem (split-tactic-lookahead-problem sibling-tactic)))
      (when (and (pending-problem-p lookahead-problem strategy)
                 (closed-problem-p lookahead-problem)
                 (not (good-problem-p lookahead-problem strategy))
                 (not (problem-has-some-open-obviously-neutral-argument-link? lookahead-problem nil strategy nil)))
        (return-from removal-strategy-chooses-to-throw-away-split-tactic? t))))
  nil)

(defun removal-strategy-chooses-to-throw-away-sibling-split-tactic? (strategy split-tactic sibling-tactic)
  (declare (ignore split-tactic))
  (let ((result nil))
    (let ((*set-aside-non-continuable-implies-throw-away?* nil))
      (when (removal-strategy-chooses-to-totally-throw-away-tactic? strategy sibling-tactic t t)
        (let ((subexplanation (strategy-last-uninterestingness-explanation)))
          (declare (ignore subexplanation))
          (when *strategy-gathering-uninterestingness-explanations?*
            ;; Likely records :split-tactic-thrown-away-because-sibling-tactic-thrown-away with subexplanation
            (missing-larkc 35532)))
        (setf result t)))
    result))

;; (defun removal-strategy-chooses-not-to-activate-any-strategems-on-problem? (strategy problem) ...) -- active declareFunction, no body

(defun removal-strategy-chooses-to-set-aside-tactic-lookahead-problem? (strategy logical-tactic)
  (cond
    ((join-tactic-p logical-tactic)
     (multiple-value-bind (first-problem second-problem)
         (join-tactic-lookahead-problems logical-tactic)
       (cond
         ((or (null first-problem) (null second-problem))
          nil)
         ((or (strategically-good-problem-p first-problem strategy)
              (strategically-good-problem-p second-problem strategy))
          nil)
         ((or (removal-strategy-chooses-to-set-aside-problem? strategy first-problem)
              (removal-strategy-chooses-to-set-aside-problem? strategy second-problem))
          t)
         (t nil))))
    (t
     (let ((lookahead-problem (logical-tactic-lookahead-problem logical-tactic)))
       (cond
         ((strategically-good-problem-p lookahead-problem strategy)
          nil)
         ((removal-strategy-chooses-to-set-aside-problem? strategy lookahead-problem)
          t)
         (t nil))))))

(defun removal-strategy-chooses-to-set-aside-split-tactic? (strategy split-tactic)
  (if *removal-strategy-weaken-split-tactic-set-aside-policy?*
      (progn
        (do-tactic-sibling-tactics (sibling-tactic split-tactic :type :split)
          (when (removal-strategy-chooses-to-totally-set-aside-tactic? strategy sibling-tactic t t)
            (let ((subexplanation (strategy-last-uninterestingness-explanation)))
              (declare (ignore subexplanation))
              (when *strategy-gathering-uninterestingness-explanations?*
                ;; Likely records :split-tactic-set-aside-because-sibling-tactic-set-aside with subexplanation
                (missing-larkc 35533)))
            (return-from removal-strategy-chooses-to-set-aside-split-tactic? t)))
        nil)
      (progn
        (do-tactic-sibling-tactics (sibling-tactic split-tactic :type :split)
          (when (controlling-strategy-allows-split-tactic-to-be-set-aside? strategy sibling-tactic)
            (let ((lookahead-problem (split-tactic-lookahead-problem sibling-tactic)))
              (cond
                ((or (removal-strategy-chooses-to-throw-away-tactic? strategy sibling-tactic t t)
                     (and (totally-finished-problem-p lookahead-problem strategy)
                          (not (good-problem-p lookahead-problem strategy))))
                 (let ((subexplanation (strategy-last-uninterestingness-explanation)))
                   (declare (ignore subexplanation))
                   (when *strategy-gathering-uninterestingness-explanations?*
                     ;; Likely records :split-tactic-set-aside-because-sibling-tactic-thrown-away with subexplanation
                     (missing-larkc 35534)))
                 (return-from removal-strategy-chooses-to-set-aside-split-tactic? t))
                ((removal-strategy-chooses-to-totally-set-aside-tactic? strategy sibling-tactic t t)
                 (let ((subexplanation (strategy-last-uninterestingness-explanation)))
                   (declare (ignore subexplanation))
                   (when *strategy-gathering-uninterestingness-explanations?*
                     ;; Likely records :split-tactic-set-aside-because-sibling-tactic-set-aside with subexplanation
                     (missing-larkc 35535)))
                 (return-from removal-strategy-chooses-to-set-aside-split-tactic? t))))))
        nil)))

(defun controlling-strategy-allows-split-tactic-to-be-set-aside? (strategy split-tactic)
  (if (substrategy? strategy)
      (controlling-strategy-callback strategy :substrategy-allow-split-tactic-set-aside-wrt-removal split-tactic)
      t))

(defun removal-strategy-chooses-to-throw-away-meta-removal-tactic? (strategy meta-removal-tactic)
  "[Cyc] STRATEGY should throw away META-REMOVAL-TACTIC if it has a sibling tactic that is tactically possible but disallowed by STRATEGY,
because then the intended completeness of META-REMOVAL-TACTIC is inapplicable."
  (when (meta-removal-tactic-p meta-removal-tactic)
    (let ((sibling-disallowed-tactic? nil))
      (do-problem-tactics (removal-tactic (tactic-problem meta-removal-tactic)
                           :done sibling-disallowed-tactic?
                           :type :generalized-removal
                           :status :possible)
        (unless (eq removal-tactic meta-removal-tactic)
          (unless (inference-allows-use-of-module? (strategy-inference strategy)
                                                   (tactic-hl-module removal-tactic))
            (setf sibling-disallowed-tactic? t))))
      sibling-disallowed-tactic?)))

(defun removal-strategy-throw-away-uninteresting-set-asides (strategy)
  (let ((total-thrown-away-count 0)
        (thrown-away-count (removal-strategy-throw-away-uninteresting-set-asides-int strategy)))
    (incf total-thrown-away-count thrown-away-count)
    (loop while (plusp thrown-away-count)
          do (setf thrown-away-count (removal-strategy-throw-away-uninteresting-set-asides-int strategy))
             (incf total-thrown-away-count thrown-away-count))
    total-thrown-away-count))

(defun removal-strategy-throw-away-uninteresting-set-asides-int (strategy)
  (let ((set-aside-problems (removal-strategy-set-aside-problems-to-reconsider strategy)))
    (strategy-clear-set-asides strategy)
    (let ((thrown-away-count 0))
      (dolist (set-aside-problem set-aside-problems)
        (if (removal-strategy-chooses-to-leave-problem-set-aside? strategy set-aside-problem)
            ;; Likely re-marks the problem as set-aside
            (missing-larkc 35463)
            (incf thrown-away-count)))
      thrown-away-count)))

(defun removal-strategy-chooses-to-leave-problem-set-aside? (strategy set-aside-problem)
  (eq :set-aside (why-removal-strategy-chooses-to-ignore-problem strategy set-aside-problem)))

;; (defun removal-strategy-reconsider-set-asides (strategy) ...) -- active declareFunction, no body
;; (defun removal-strategy-reconsider-one-set-aside (strategy problem) ...) -- active declareFunction, no body

(defun removal-strategy-set-aside-problems-to-reconsider (strategy)
  (strategy-all-valid-set-aside-problems strategy))


;;;; Setup

(toplevel
  (note-memoized-function 'removal-strategy-preferred-backchain-required-join-ordered-tactic))
