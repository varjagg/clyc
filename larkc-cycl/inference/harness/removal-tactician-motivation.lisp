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

;; Reconstructed from Internal Constants:
;; $list0 = ((strategy strategem) &body body) -- arglist
;; $sym1 = uninternedSymbol "PROBLEM" -- gensym for problem var
;; $sym2 = uninternedSymbol "STRATEGEM-VAR" -- gensym for strategem binding
;; $sym3 = CLET -- let binding
;; $sym4 = STRATEGEM-PROBLEM -- function call to get problem from strategem
;; $sym5 = REMOVAL-STRATEGY-DEACTIVATE-STRATEGEM -- called before body
;; $sym6 = REMOVAL-STRATEGY-POSSIBLY-DEACTIVATE-PROBLEM -- called after body
;; Evidence: expansion sites in removal-tactician-execution.lisp lines 114-119, 126-130
;; Pattern: bind strategem-var, get problem, deactivate strategem, run body, possibly deactivate problem
(defmacro removal-strategy-with-strategically-active-strategem
    ((strategy strategem) &body body)
  (with-temp-vars (problem strategem-var)
    `(let* ((,strategem-var ,strategem)
            (,problem (strategem-problem ,strategem-var)))
       (removal-strategy-deactivate-strategem ,strategy ,strategem-var)
       ,@body
       (removal-strategy-possibly-deactivate-problem ,strategy ,problem))))

(defun removal-strategy-possibly-propagate-motivation-to-link-head (strategy link-head)
  "[Cyc] @return booleanp"
  (declare (type motivation-strategem-p link-head))
  (let ((already-motivated? (removal-strategy-link-head-motivated? strategy link-head)))
    (when (not already-motivated?)
      (removal-strategy-propagate-motivation-to-link-head strategy link-head)
      (return-from removal-strategy-possibly-propagate-motivation-to-link-head t))
    nil))

(defun removal-strategy-propagate-motivation-to-link-head (strategy link-head)
  (declare (type removal-strategy-p strategy))
  (declare (type motivation-strategem-p link-head))
  (removal-strategy-note-link-head-motivated strategy link-head)
  (cond
    ((transformation-link-p link-head)
     ;; do nothing for transformation links
     )
    ((motivation-strategem-link-p link-head)
     (let* ((link link-head)
            (supporting-problem (problem-link-sole-supporting-problem link)))
       (removal-strategy-possibly-propagate-motivation-to-problem strategy supporting-problem)))
    (t
     (let ((tactic link-head))
       (if (join-tactic-p tactic)
           (let* ((join-link (join-tactic-link tactic))
                  (first-problem (join-link-first-problem join-link))
                  (second-problem (join-link-second-problem join-link)))
             (removal-strategy-possibly-propagate-motivation-to-problem strategy first-problem)
             (removal-strategy-possibly-propagate-motivation-to-problem strategy second-problem))
           (let ((lookahead-problem (logical-tactic-lookahead-problem tactic)))
             (removal-strategy-possibly-propagate-motivation-to-problem strategy lookahead-problem))))))
  nil)

(defun removal-strategy-link-motivates-problem? (strategy link &optional problem)
  "[Cyc] @return booleanp"
  (if (not (split-link-p link))
      (removal-strategy-link-motivates-lookahead-problem? strategy link)
      ;; For split links, check if any split tactic through dependent links of problem
      ;; has been motivated via removal strategy
      (let ((motivated? nil)
            (problem-var problem)
            (set-contents-var (problem-dependent-links problem)))
        (let* ((basis-object (do-set-contents-basis-object set-contents-var))
               (state (do-set-contents-initial-state basis-object set-contents-var)))
          (loop until (or motivated?
                         (do-set-contents-done? basis-object state))
                do (let ((dependent-link (do-set-contents-next basis-object state)))
                     (when (do-set-contents-element-valid? state dependent-link)
                       (dolist (mapped-problem
                                (problem-link-supporting-mapped-problems dependent-link))
                         (when motivated? (return))
                         (when (do-problem-link-open-match? t dependent-link mapped-problem)
                           (when (eq problem-var (mapped-problem-problem mapped-problem))
                             (let ((supported-problem (problem-link-supported-problem dependent-link)))
                               (dolist (tactic (problem-tactics supported-problem))
                                 (when motivated? (return))
                                 (when (split-tactic-p tactic)
                                   (let ((supporting-mapped-problem
                                           (find-split-tactic-supporting-mapped-problem tactic)))
                                     (when (eq mapped-problem supporting-mapped-problem)
                                       (when (removal-strategy-link-head-motivated? strategy tactic)
                                         (setf motivated? t))))))))))))
                   (setf state (do-set-contents-update-state state))))
        motivated?)))

(defun removal-strategy-link-motivates-lookahead-problem? (strategy link)
  "[Cyc] @return booleanp"
  (cond
    ((motivation-strategem-link-p link)
     (removal-strategy-link-head-motivated? strategy link))
    ((split-link-p link)
     nil)
    ((logical-link-p link)
     (let ((tactic (logical-link-unique-tactic link)))
       (removal-strategy-link-head-motivated? strategy tactic)))
    (t nil)))

(defun removal-strategy-possibly-propagate-motivation-to-problem (strategy problem)
  "[Cyc] @return booleanp"
  (let ((already-motivated? (problem-motivated? problem strategy)))
    (when (not already-motivated?)
      (removal-strategy-note-problem-motivated strategy problem)
      ;; do-problem-dependent-links with :type :join-ordered
      (let* ((problem-var problem)
             (set-contents-var (problem-dependent-links problem))
             (basis-object (do-set-contents-basis-object set-contents-var))
             (state (do-set-contents-initial-state basis-object set-contents-var)))
        (loop until (do-set-contents-done? basis-object state)
              do (let ((join-ordered-link (do-set-contents-next basis-object state)))
                   (when (do-set-contents-element-valid? state join-ordered-link)
                     (when (problem-link-has-type? join-ordered-link :join-ordered)
                       ;; do-problem-link-supporting-mapped-problems with :open? t
                       (dolist (mapped-problem
                                (problem-link-supporting-mapped-problems join-ordered-link))
                         (when (do-problem-link-open-match? t join-ordered-link mapped-problem)
                           (when (eq problem-var (mapped-problem-problem mapped-problem))
                             (when (removal-strategy-link-motivates-problem?
                                    strategy join-ordered-link problem)
                               ;; do-problem-proofs with :proof-status :proven
                               (do-problem-proofs (proof problem :proof-status :proven)
                                 (let* ((restricted-non-focal-mapped-problem
                                          ;; Likely join-ordered-link-restricted-non-focal-mapped-problem
                                          ;; -- evidence: context is iterating proven proofs for
                                          ;; a join-ordered link's supporting problem to propagate
                                          ;; motivation to the restricted non-focal problem
                                          (missing-larkc 36363))
                                        (restricted-non-focal-problem
                                          (mapped-problem-problem
                                           restricted-non-focal-mapped-problem)))
                                   (removal-strategy-possibly-propagate-motivation-to-problem
                                    strategy restricted-non-focal-problem))))))))))
                 (setf state (do-set-contents-update-state state))))
      (when (problem-relevant-to-strategy? problem strategy)
        (removal-strategy-possibly-activate-problem strategy problem))
      (return-from removal-strategy-possibly-propagate-motivation-to-problem t))
    nil))

(defun removal-strategy-possibly-activate-problem (strategy problem)
  "[Cyc] @return booleanp; whether STRATEGY chose to activate PROBLEM."
  (when (removal-strategy-chooses-not-to-examine-problem? strategy problem)
    (return-from removal-strategy-possibly-activate-problem nil))
  (determine-strategic-status-wrt problem strategy)
  (when (removal-strategy-chooses-not-to-activate-problem? strategy problem)
    (return-from removal-strategy-possibly-activate-problem nil))
  (when (problem-is-a-simplification? problem)
    (removal-strategy-possibly-propagate-motivation-to-problem strategy problem))
  (when (removal-strategy-problem-is-the-rest-of-a-removal? problem strategy)
    (removal-strategy-possibly-propagate-motivation-to-problem strategy problem))
  (when (removal-strategy-motivates-problem-via-rewrite? strategy problem)
    (removal-strategy-possibly-propagate-motivation-to-problem strategy problem))
  (when (removal-strategy-problem-is-the-rest-of-a-join-ordered? problem strategy)
    (removal-strategy-possibly-propagate-proof-spec-to-restricted-non-focals strategy problem))
  (let ((activate? (and (problem-motivated? problem strategy)
                        (not (removal-strategy-chooses-not-to-activate-problem? strategy problem)))))
    (when activate?
      (if (removal-strategy-activate-problem strategy problem)
          (return-from removal-strategy-possibly-activate-problem t)
          (progn
            (removal-strategy-make-problem-pending strategy problem)
            (return-from removal-strategy-possibly-activate-problem nil)))))
  nil)

(defun removal-strategy-problem-is-the-rest-of-a-removal? (problem strategy)
  "[Cyc] if you are a restricted non-focal problem of some (open?) join-ordered link which has R,
you get R.  you're the rest of a removal."
  (let* ((set-contents-var (problem-dependent-links problem))
         (basis-object (do-set-contents-basis-object set-contents-var))
         (state (do-set-contents-initial-state basis-object set-contents-var)))
    (loop until (do-set-contents-done? basis-object state)
          do (let ((restriction-link (do-set-contents-next basis-object state)))
               (when (do-set-contents-element-valid? state restriction-link)
                 (when (problem-link-has-type? restriction-link :restriction)
                   (let* ((non-focal-problem (problem-link-supported-problem restriction-link))
                          (set-contents-var-2 (problem-dependent-links non-focal-problem))
                          (basis-object-2 (do-set-contents-basis-object set-contents-var-2))
                          (state-2 (do-set-contents-initial-state basis-object-2 set-contents-var-2)))
                     (loop until (do-set-contents-done? basis-object-2 state-2)
                           do (let ((join-ordered-link (do-set-contents-next basis-object-2 state-2)))
                                (when (do-set-contents-element-valid? state-2 join-ordered-link)
                                  (when (problem-link-has-type? join-ordered-link :join-ordered)
                                    (when (join-ordered-link-restricted-non-focal-link?
                                           join-ordered-link restriction-link)
                                      (when (eq non-focal-problem
                                                (join-ordered-link-non-focal-problem join-ordered-link))
                                        (when (and (problem-link-open? join-ordered-link)
                                                   (removal-strategy-link-motivates-lookahead-problem?
                                                    strategy join-ordered-link))
                                          (return-from removal-strategy-problem-is-the-rest-of-a-removal? t)))))))
                              (setf state-2 (do-set-contents-update-state state-2)))))))
             (setf state (do-set-contents-update-state state)))
    nil))

(defun removal-strategy-problem-is-the-rest-of-a-join-ordered? (problem strategy)
  (let ((part-of-join-ordered? nil)
        (set-contents-var (problem-dependent-links problem)))
    (let* ((basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (or part-of-join-ordered?
                      (do-set-contents-done? basis-object state))
            do (let ((restriction-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state restriction-link)
                   (when (problem-link-has-type? restriction-link :restriction)
                     (let* ((non-focal-problem (problem-link-supported-problem restriction-link))
                            (set-contents-var-2 (problem-dependent-links non-focal-problem))
                            (basis-object-2 (do-set-contents-basis-object set-contents-var-2))
                            (state-2 (do-set-contents-initial-state basis-object-2 set-contents-var-2)))
                       (loop until (or part-of-join-ordered?
                                       (do-set-contents-done? basis-object-2 state-2))
                             do (let ((join-ordered-link (do-set-contents-next basis-object-2 state-2)))
                                  (when (do-set-contents-element-valid? state-2 join-ordered-link)
                                    (when (problem-link-has-type? join-ordered-link :join-ordered)
                                      (when (join-ordered-link-restricted-non-focal-link?
                                             join-ordered-link restriction-link)
                                        (when (eq non-focal-problem
                                                  (join-ordered-link-non-focal-problem join-ordered-link))
                                          (setf part-of-join-ordered? t))))))
                                (setf state-2 (do-set-contents-update-state state-2)))))))
               (setf state (do-set-contents-update-state state))))
    part-of-join-ordered?))

(defun removal-strategy-possibly-propagate-proof-spec-to-restricted-non-focals (strategy problem)
  (declare (ignore strategy problem))
  nil)

(defun removal-strategy-motivates-problem-via-rewrite? (strategy problem)
  "[Cyc] if you are a supporting rewritten problem of a rewrite link whose supported problem has R,
you get R."
  (when (problem-store-rewrite-allowed? (strategy-problem-store strategy))
    (let* ((set-contents-var (problem-dependent-links problem))
           (basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state link)
                   (when (problem-link-has-type? link :rewrite)
                     (when (problem-motivated? (problem-link-supported-problem link) strategy)
                       (return-from removal-strategy-motivates-problem-via-rewrite? t)))))
               (setf state (do-set-contents-update-state state)))))
  nil)

(defun removal-strategy-chooses-not-to-examine-problem? (strategy problem)
  (strategy-deems-problem-tactically-uninteresting? strategy problem))

(defun removal-strategy-chooses-not-to-activate-problem? (strategy problem)
  (or (removal-strategy-problem-active? strategy problem)
      (removal-strategy-problem-pending? strategy problem)))

(defun removal-strategy-activate-problem (strategy problem)
  (declare (type removal-strategy-p strategy))
  (declare (type problem-p problem))
  (plusp (removal-strategy-possibly-activate-strategems strategy problem)))

(defun removal-strategy-possibly-activate-strategems (strategy problem)
  (multiple-value-bind (strategems-to-activate strategems-to-set-aside strategems-to-throw-away)
      (removal-strategy-categorize-strategems strategy problem)
    (dolist (strategem strategems-to-activate)
      (removal-strategy-activate-strategem strategy strategem))
    (dolist (strategem strategems-to-set-aside)
      (removal-strategy-note-strategem-set-aside strategy strategem)
      (when (tactic-p strategem)
        (set-tactic-set-aside-wrt strategem strategy :removal)))
    (dolist (strategem strategems-to-throw-away)
      (removal-strategy-note-strategem-thrown-away strategy strategem)
      (when (tactic-p strategem)
        (set-tactic-thrown-away-wrt strategem strategy :removal)))
    (length strategems-to-activate)))

(defparameter *removal-strategy-rl-tactician-tactic-types*
  '(:generalized-removal :connected-conjunction :split :union)
  "[Cyc] The tactic types to use the RL tactician's ordering for.")

;; (defun merge-removal-and-rl-tactician-strategems (arg1 arg2 arg3 arg4 arg5 arg6) ...) -- active declareFunction, no body
;; (defun removal-strategy-filter-strategems-by-rlt-tactic-types (arg1 arg2) ...) -- active declareFunction, no body
;; (defun removal-strategy-filter-strategems-by-rlt-tactic-types-int (arg1 arg2) ...) -- active declareFunction, no body

(defun removal-strategy-note-new-tactic (strategy tactic)
  (default-compute-strategic-properties-of-tactic strategy tactic)
  (unless (or (and (split-tactic-p tactic)
                   (meta-split-tactics-enabled?))
              (transformation-tactic-p tactic)
              (simple-strategy-chooses-to-ignore-tactic? strategy tactic))
    (removal-strategy-note-new-tactic-possible strategy tactic))
  nil)

(defun removal-strategy-note-split-tactics-strategically-possible (strategy split-tactics)
  (let ((sorted-split-tactics (strategy-sort strategy
                                             (copy-list split-tactics)
                                             #'logical-tactic-better-wrt-removal?)))
    (dolist (split-tactic (nreverse sorted-split-tactics))
      (removal-strategy-note-new-tactic-possible strategy split-tactic)))
  nil)

(defun removal-strategy-note-new-tactic-possible (strategy tactic)
  (let ((problem (tactic-problem tactic)))
    (problem-note-tactic-strategically-possible problem tactic strategy))
  (when (or (and (meta-split-tactics-enabled?)
                 (split-tactic-p tactic))
            (and (transformation-tactic-p tactic)
                 (not (meta-transformation-tactic-p tactic))))
    (let ((problem-already-considered? t))
      (removal-strategy-note-problem-unpending strategy (tactic-problem tactic))
      (cond
        ((removal-strategy-chooses-to-throw-away-tactic?
          strategy tactic problem-already-considered? nil)
         (removal-strategy-note-strategem-thrown-away strategy tactic))
        ((removal-strategy-chooses-to-set-aside-tactic?
          strategy tactic problem-already-considered? nil t)
         (removal-strategy-note-strategem-set-aside strategy tactic))
        (t
         (removal-strategy-activate-strategem strategy tactic)))))
  nil)

(defun removal-strategy-categorize-strategems (strategy problem)
  "[Cyc] @return 0 listp of strategem-p; an ordered list of strategems on PROBLEM which STRATEGY may want to activate wrt removal.
Strategems are ordered in intended order of activation.
@return 1 listp of strategem-p; an ordered list of strategems on PROBLEM which STRATEGY may want to set aside wrt removal.
@return 2 listp of strategem-p; an ordered list of strategems on PROBLEM which STRATEGY may want to throw away wrt removal."
  (let ((strategems-to-activate nil)
        (strategems-to-set-aside nil)
        (strategems-to-throw-away nil)
        (problem-set-aside? (removal-strategy-chooses-to-set-aside-problem? strategy problem))
        (problem-thrown-away? (removal-strategy-chooses-to-throw-away-problem? strategy problem)))
    (multiple-value-bind (best-complete-removal-tactic possible-non-complete-removal-tactics
                          set-aside-removal-tactics thrown-away-removal-tactics)
        (removal-strategy-categorize-removal-tactics
         strategy problem problem-set-aside? problem-thrown-away?)
      (multiple-value-bind (possible-motivation-strategems set-aside-motivation-strategems
                            thrown-away-motivation-strategems)
          (removal-strategy-categorize-motivation-strategems
           strategy problem problem-set-aside? problem-thrown-away?)
        (setf strategems-to-set-aside
              (append set-aside-removal-tactics set-aside-motivation-strategems))
        (setf strategems-to-throw-away
              (append thrown-away-removal-tactics thrown-away-motivation-strategems))
        (setf possible-non-complete-removal-tactics
              (nreverse possible-non-complete-removal-tactics))
        (setf possible-motivation-strategems (nreverse possible-motivation-strategems))
        (dolist (logical-tactic possible-motivation-strategems)
          (push logical-tactic strategems-to-activate))
        (dolist (removal-tactic possible-non-complete-removal-tactics)
          (push removal-tactic strategems-to-activate))
        (when best-complete-removal-tactic
          (push best-complete-removal-tactic strategems-to-activate))
        (dolist (meta-structural-tactic (problem-tactics problem))
          (when (do-problem-tactics-type-match meta-structural-tactic :meta-structural)
            (push meta-structural-tactic strategems-to-activate)))
        (setf strategems-to-activate (nreverse strategems-to-activate))))
    (values strategems-to-activate strategems-to-set-aside strategems-to-throw-away)))

(defun removal-strategy-categorize-motivation-strategems
    (strategy problem problem-set-aside? problem-thrown-away?)
  (let ((possible-motivation-strategems nil)
        (set-aside-motivation-strategems nil)
        (thrown-away-motivation-strategems nil))
    (cond
      ((single-literal-problem-p problem)
       ;; no motivation strategems for single-literal problems
       )
      ((multi-clause-problem-p problem)
       (multiple-value-setq (possible-motivation-strategems
                             set-aside-motivation-strategems
                             thrown-away-motivation-strategems)
         ;; Likely removal-strategy-categorize-disjunctive-tactics -- evidence:
         ;; multi-clause problems dispatch to disjunctive tactic categorization
         (missing-larkc 36391)))
      ((problem-has-split-tactics? problem)
       (multiple-value-setq (possible-motivation-strategems
                             set-aside-motivation-strategems
                             thrown-away-motivation-strategems)
         ;; Likely removal-strategy-categorize-split-tactics -- evidence:
         ;; problems with split tactics dispatch to split tactic categorization
         (missing-larkc 36392)))
      (t
       (multiple-value-setq (possible-motivation-strategems
                             set-aside-motivation-strategems
                             thrown-away-motivation-strategems)
         (removal-strategy-categorize-connected-conjunction-tactics
          strategy problem problem-set-aside? problem-thrown-away?))))
    (values possible-motivation-strategems
            set-aside-motivation-strategems
            thrown-away-motivation-strategems)))

(defun removal-strategy-categorize-removal-tactics
    (strategy problem problem-set-aside? problem-thrown-away?)
  "[Cyc] Possible non-complete removal tactics should be in the reverse intended activation order"
  (let ((best-complete-removal-tactic nil)
        (best-complete-removal-tactic-productivity nil)
        (set-aside-removal-tactics nil)
        (possible-non-complete-removal-tactics nil))
    (unless problem-thrown-away?
      (dolist (removal-tactic (problem-tactics problem))
        (when (and (do-problem-tactics-type-match removal-tactic :generalized-removal-or-rewrite)
                   (do-problem-tactics-status-match removal-tactic :possible))
          (unless (removal-strategy-chooses-to-throw-away-tactic?
                   strategy removal-tactic t)
            (if (or problem-set-aside?
                    (removal-strategy-chooses-to-set-aside-tactic?
                     strategy removal-tactic t))
                (unless best-complete-removal-tactic
                  (push removal-tactic set-aside-removal-tactics))
                (let ((completeness (tactic-strategic-completeness removal-tactic strategy)))
                  (cond
                    ((eql completeness :complete)
                     (let ((productivity (tactic-strategic-productivity removal-tactic strategy)))
                       (when (or (null best-complete-removal-tactic)
                                 (productivity-< productivity
                                                  best-complete-removal-tactic-productivity))
                         (setf best-complete-removal-tactic removal-tactic)
                         (setf best-complete-removal-tactic-productivity productivity)
                         (unless (meta-removal-tactic-p best-complete-removal-tactic)
                           (setf possible-non-complete-removal-tactics nil)
                           (setf set-aside-removal-tactics nil)))))
                    ((or (eql completeness :incomplete)
                         (eql completeness :grossly-incomplete))
                     (when (or (null best-complete-removal-tactic)
                               (meta-removal-tactic-p best-complete-removal-tactic))
                       (push removal-tactic possible-non-complete-removal-tactics)))))))))
      (setf possible-non-complete-removal-tactics
            (strategy-sort strategy possible-non-complete-removal-tactics
                           #'tactic-strategic-productivity-<)))
    (let ((thrown-away-removal-tactics nil))
      (dolist (removal-tactic (problem-tactics problem))
        (when (and (do-problem-tactics-type-match removal-tactic :generalized-removal-or-rewrite)
                   (do-problem-tactics-status-match removal-tactic :possible))
          (unless (or (eq removal-tactic best-complete-removal-tactic)
                      (member-eq? removal-tactic possible-non-complete-removal-tactics)
                      (member-eq? removal-tactic set-aside-removal-tactics))
            (push removal-tactic thrown-away-removal-tactics))))
      (values best-complete-removal-tactic
              possible-non-complete-removal-tactics
              set-aside-removal-tactics
              thrown-away-removal-tactics))))

;; (defun removal-strategy-categorize-disjunctive-tactics (strategy problem problem-set-aside? problem-thrown-away?) ...) -- active declareFunction, no body
;; (defun removal-strategy-categorize-split-tactics (strategy problem problem-set-aside? problem-thrown-away?) ...) -- active declareFunction, no body

(defun removal-strategy-categorize-connected-conjunction-tactics
    (strategy problem problem-set-aside? problem-thrown-away?)
  (let ((possible-motivation-strategems nil)
        (set-aside-motivation-strategems nil)
        (committed-tactic nil)
        (committed-tactic-productivity :positive-infinity)
        (committed-tactic-preference :disallowed)
        (committed-tactic-module-spec :join-ordered)
        (committed-tactic-literal-count 0)
        (cheap-backtracking-tactics nil))
    (unless problem-thrown-away?
      (let* ((problem-var problem)
             (type-var :connected-conjunction)
             (subsuming-join-ordered-tactics
               (problem-maximal-subsuming-multi-focal-literal-join-ordered-tactics
                problem-var type-var)))
        (dolist (candidate-tactic (problem-tactics problem-var))
          (when (do-problem-tactics-type-match candidate-tactic type-var)
            (unless (some-subsuming-join-ordered-tactic?
                     candidate-tactic subsuming-join-ordered-tactics strategy)
              (let* ((link (logical-tactic-link candidate-tactic))
                     (candidate-tactic-module-spec
                       (if (join-tactic-p candidate-tactic) :join :join-ordered)))
                (unless (removal-strategy-link-motivates-problem? strategy link)
                  (unless (removal-strategy-chooses-to-throw-away-connected-conjunction-link?
                           strategy link)
                    (if (or problem-set-aside?
                            (removal-strategy-chooses-to-set-aside-connected-conjunction-link?
                             strategy link))
                        (push candidate-tactic set-aside-motivation-strategems)
                        (let* ((candidate-tactic-productivity
                                 (tactic-max-removal-productivity candidate-tactic strategy))
                               (candidate-tactic-preference
                                 (tactic-strategic-preference-level candidate-tactic strategy))
                               (candidate-tactic-literal-count
                                 (connected-conjunction-tactic-literal-count candidate-tactic))
                               (magic-wand? (magic-wand-tactic? candidate-tactic strategy)))
                          (when magic-wand?
                            (setf candidate-tactic-preference :disallowed))
                          (when (or (null committed-tactic)
                                    (removal-strategy-deems-conjunctive-tactic-spec-better?
                                     strategy
                                     candidate-tactic candidate-tactic-productivity
                                     candidate-tactic-preference candidate-tactic-module-spec
                                     candidate-tactic-literal-count
                                     committed-tactic committed-tactic-productivity
                                     committed-tactic-preference committed-tactic-module-spec
                                     committed-tactic-literal-count))
                            (setf committed-tactic candidate-tactic)
                            (setf committed-tactic-productivity candidate-tactic-productivity)
                            (setf committed-tactic-preference candidate-tactic-preference)
                            (setf committed-tactic-module-spec candidate-tactic-module-spec)
                            (setf committed-tactic-literal-count candidate-tactic-literal-count))
                          (when (and (not magic-wand?)
                                     (removal-strategy-logical-tactic-removal-backtracking-cheap?
                                      candidate-tactic strategy))
                            (push candidate-tactic cheap-backtracking-tactics)))))))))))
      (when committed-tactic
        (if (removal-strategy-commits-to-no-removal-backtracking?
             strategy committed-tactic committed-tactic-preference)
            (setf cheap-backtracking-tactics nil)
            (setf cheap-backtracking-tactics
                  (delete-first committed-tactic cheap-backtracking-tactics #'eq)))
        (push committed-tactic possible-motivation-strategems)
        (dolist (backtracking-tactic cheap-backtracking-tactics)
          (push backtracking-tactic possible-motivation-strategems))
        (setf possible-motivation-strategems
              (strategy-sort strategy possible-motivation-strategems
                             #'logical-tactic-better-wrt-removal?))))
    (let ((thrown-away-motivation-strategems nil)
          (problem-var problem)
          (type-var :connected-conjunction)
          (subsuming-join-ordered-tactics
            (problem-maximal-subsuming-multi-focal-literal-join-ordered-tactics
             problem type-var)))
      (dolist (conjunctive-tactic (problem-tactics problem-var))
        (when (do-problem-tactics-type-match conjunctive-tactic type-var)
          (unless (some-subsuming-join-ordered-tactic?
                   conjunctive-tactic subsuming-join-ordered-tactics strategy)
            (unless (or (member-eq? conjunctive-tactic possible-motivation-strategems)
                        (member-eq? conjunctive-tactic set-aside-motivation-strategems))
              (push conjunctive-tactic thrown-away-motivation-strategems)))))
      (values possible-motivation-strategems
              set-aside-motivation-strategems
              thrown-away-motivation-strategems))))

(defun removal-strategy-deems-conjunctive-tactic-spec-better?
    (strategy
     candidate-tactic candidate-tactic-productivity candidate-tactic-preference
     candidate-tactic-module-spec candidate-tactic-literal-count
     committed-tactic committed-tactic-productivity committed-tactic-preference
     committed-tactic-module-spec committed-tactic-literal-count)
  (when (and (problem-store-transformation-allowed?
              (tactic-store committed-tactic))
             ;; Likely checking if the problem store has RL tactician enabled
             ;; -- evidence: guards a completeness comparison with transformation-allowed
             ;; and preference equality check
             (missing-larkc 36508)
             (eq candidate-tactic-preference committed-tactic-preference))
    (let ((candidate-completeness
            (logical-tactic-generalized-removal-completeness candidate-tactic strategy))
          (committed-completeness
            (logical-tactic-generalized-removal-completeness committed-tactic strategy)))
      (when (completeness-> candidate-completeness committed-completeness)
        (return-from removal-strategy-deems-conjunctive-tactic-spec-better? t))))
  (strategy-deems-conjunctive-tactic-spec-better?
   candidate-tactic-productivity candidate-tactic-preference
   candidate-tactic-module-spec candidate-tactic-literal-count
   committed-tactic-productivity committed-tactic-preference
   committed-tactic-module-spec committed-tactic-literal-count))

(defun removal-strategy-commits-to-no-removal-backtracking?
    (strategy committed-tactic committed-tactic-preference-level)
  (when (if (problem-store-transformation-allowed?
             (tactic-store committed-tactic))
            (eq :complete (logical-tactic-generalized-removal-completeness
                           committed-tactic strategy))
            (eq :preferred committed-tactic-preference-level))
    (when (removal-strategy-logical-tactic-removal-backtracking-cheap?
           committed-tactic strategy)
      (return-from removal-strategy-commits-to-no-removal-backtracking? t)))
  (when (problem-backchain-required? (tactic-problem committed-tactic))
    (return-from removal-strategy-commits-to-no-removal-backtracking? t))
  nil)

(defun removal-strategy-logical-tactic-removal-backtracking-cheap? (logical-tactic strategy)
  (unless (join-tactic-p logical-tactic)
    (let ((removal-backtracking-productivity-threshold
            (removal-strategy-removal-backtracking-productivity-limit strategy)))
      (when removal-backtracking-productivity-threshold
        (let ((productivity (tactic-max-removal-productivity logical-tactic strategy)))
          (return-from removal-strategy-logical-tactic-removal-backtracking-cheap?
            (productivity-<= productivity removal-backtracking-productivity-threshold))))))
  nil)

;; (defun removal-strategy-possibly-reconsider-split-set-asides (strategy arg2) ...) -- active declareFunction, no body
;; (defun removal-strategy-reconsider-one-split-set-aside (strategy arg2) ...) -- active declareFunction, no body
;; (defun removal-strategy-possibly-clear-strategic-status (strategy arg2) ...) -- active declareFunction, no body

(defun removal-strategy-reactivate-executable-strategem (strategy strategem)
  (declare (type removal-strategy-p strategy))
  (declare (type executable-strategem-p strategem))
  (cond
    ((generalized-removal-tactic-p strategem)
     (removal-strategy-activate-strategem strategy strategem))
    ((transformation-tactic-p strategem)
     nil)
    ((meta-structural-tactic-p strategem)
     (removal-strategy-activate-strategem strategy strategem)
     strategem)
    (t
     (removal-strategy-activate-strategem strategy strategem))))

(defun removal-strategy-strategically-deactivate-strategem (strategy strategem)
  (when (strategem-invalid-p strategem)
    (return-from removal-strategy-strategically-deactivate-strategem nil))
  (let* ((strategem-var strategem)
         (problem (strategem-problem strategem-var)))
    (removal-strategy-deactivate-strategem strategy strategem-var)
    (removal-strategy-possibly-deactivate-problem strategy problem))
  (when (tactic-p strategem)
    (consider-strategic-ramifications-of-possibly-executed-tactic strategy strategem))
  nil)

(defun removal-strategy-deactivate-strategem (strategy strategem)
  (declare (type removal-strategy-p strategy))
  (declare (type removal-strategem-p strategem))
  (let* ((problem (strategem-problem strategem))
         (index (removal-strategy-problem-total-strategems-active strategy))
         (count (gethash problem index 0)))
    (setf count (- count 1))
    (if (plusp count)
        (setf (gethash problem index) count)
        (progn
          (remhash problem index)
          (removal-strategy-note-problem-pending strategy problem)))
    count))

(defun removal-strategy-possibly-deactivate-problem (strategy problem)
  (when (not (removal-strategy-problem-active? strategy problem))
    (strategy-note-problem-inactive strategy problem)
    (when (removal-strategy-problem-set-aside? strategy problem)
      (strategy-note-problem-set-aside strategy problem)
      (return-from removal-strategy-possibly-deactivate-problem t)))
  nil)

(defun removal-strategy-consider-that-problem-could-be-strategically-pending (strategy problem)
  (when (removal-strategy-chooses-to-throw-away-problem? strategy problem)
    (removal-strategy-make-problem-pending strategy problem)
    (return-from removal-strategy-consider-that-problem-could-be-strategically-pending t))
  nil)

(defun removal-strategy-make-problem-pending (strategy problem)
  (removal-strategy-note-problem-pending strategy problem)
  (removal-strategy-possibly-deactivate-problem strategy problem)
  nil)

;;;; Setup

(toplevel
  (note-funcall-helper-function 'removal-strategy-note-new-tactic)
  (note-funcall-helper-function 'removal-strategy-note-split-tactics-strategically-possible)
  (note-funcall-helper-function 'removal-strategy-consider-that-problem-could-be-strategically-pending))
