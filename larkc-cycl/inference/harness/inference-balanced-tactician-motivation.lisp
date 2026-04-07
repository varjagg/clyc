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
;;   $list0 = ((STRATEGY STRATEGEM MOTIVATION) &BODY BODY) -- arglist
;;   $sym1$PROBLEM = uninternedSymbol("PROBLEM") -- gensym
;;   $sym2$STRATEGEM_VAR = uninternedSymbol("STRATEGEM-VAR") -- gensym
;;   $sym3$CLET = CLET
;;   $sym4$STRATEGEM_PROBLEM = STRATEGEM-PROBLEM
;;   $sym5$BALANCED_STRATEGY_DEACTIVATE_STRATEGEM = BALANCED-STRATEGY-DEACTIVATE-STRATEGEM
;;   $sym6$BALANCED_STRATEGY_POSSIBLY_DEACTIVATE_PROBLEM = BALANCED-STRATEGY-POSSIBLY-DEACTIVATE-PROBLEM
;; Expansion evidence: inference_balanced_tactician_execution.java lines 306-310, 322-326
;; Pattern: (let ((strategem-var STRATEGEM)) (let ((problem (strategem-problem strategem-var)))
;;           (balanced-strategy-deactivate-strategem STRATEGY strategem-var MOTIVATION)
;;           BODY
;;           (balanced-strategy-possibly-deactivate-problem STRATEGY problem)))
(defmacro balanced-strategy-with-strategically-active-strategem ((strategy strategem motivation)
                                                                 &body body)
  (with-temp-vars (problem strategem-var)
    `(let ((,strategem-var ,strategem))
       (let ((,problem (strategem-problem ,strategem-var)))
         (balanced-strategy-deactivate-strategem ,strategy ,strategem-var ,motivation)
         ,@body
         (balanced-strategy-possibly-deactivate-problem ,strategy ,problem)))))

(defun balanced-strategy-possibly-propagate-motivation-to-link-head (strategy motivation link-head)
  "[Cyc] @return booleanp"
  (declare (type motivation-strategem-p link-head))
  (let ((already-motivated? (balanced-strategy-link-head-motivated? strategy motivation link-head)))
    (when (not already-motivated?)
      (balanced-strategy-propagate-motivation-to-link-head strategy motivation link-head)
      (return-from balanced-strategy-possibly-propagate-motivation-to-link-head t))
    nil))

(defparameter *balanced-strategy-new-roots-triggered-by-t-on-jo-link?* t
  "[Cyc] There ought to be two triggers for new root creation via an RT link:
the motivation transformation link getting T, or the motivating join-ordered link
getting T.  Leviathan experiments indicated that we actually gain
more completeness by refraining from triggering via join-ordered T,
but more recent work requires this to be T for correctness.")

(defvar *balanced-strategy-new-roots-check-for-t-on-jo-link?* t
  "[Cyc] It seems correct to ensure that the motivating join-ordered link has T before using it
to motivate the creation of a new root.  However, turning this to NIL causes 13 haystacks
to become answerable.  Leviathan @todo investigate why, and try to come up with a more
principled fix.")

(defun balanced-strategy-propagate-motivation-to-link-head (strategy motivation link-head)
  (declare (type balanced-strategy-p strategy))
  (declare (type motivation-strategem-p link-head))
  (balanced-strategy-note-link-head-motivated strategy motivation link-head)
  (cond
    ((transformation-link-p link-head)
     ;; no-op for transformation links
     )
    ((motivation-strategem-link-p link-head)
     (let* ((link link-head)
            (supporting-problem (problem-link-sole-supporting-problem link)))
       (balanced-strategy-possibly-propagate-motivation-to-problem strategy motivation supporting-problem)))
    (t
     (let ((tactic link-head))
       (if (join-tactic-p tactic)
           (let* ((join-link (join-tactic-link tactic))
                  (first-problem (join-link-first-problem join-link))
                  (second-problem (join-link-second-problem join-link)))
             (balanced-strategy-possibly-propagate-motivation-to-problem strategy motivation first-problem)
             (balanced-strategy-possibly-propagate-motivation-to-problem strategy motivation second-problem))
           (let ((lookahead-problem (logical-tactic-lookahead-problem tactic)))
             (balanced-strategy-possibly-propagate-motivation-to-problem strategy motivation lookahead-problem))))))
  ;; connected conjunction section
  (when (connected-conjunction-tactic-p link-head)
    (let* ((tactic link-head)
           (link (connected-conjunction-tactic-link tactic)))
      (when (balanced-strategy-early-removal-link? strategy link)
        (let* ((link-var link)
               (set-contents-var (problem-argument-links
                                  (join-ordered-link-non-focal-problem link-var))))
          (let* ((basis-object (do-set-contents-basis-object set-contents-var))
                 (state (do-set-contents-initial-state basis-object set-contents-var)))
            (loop until (do-set-contents-done? basis-object state)
                  do (let ((restriction-link (do-set-contents-next basis-object state)))
                       (when (do-set-contents-element-valid? state restriction-link)
                         (when (problem-link-has-type? restriction-link :restriction)
                           (when (non-focal-restriction-link-with-corresponding-focal-proof? restriction-link link-var)
                             (let ((restricted-non-focal-problem (problem-link-sole-supporting-problem restriction-link)))
                               (balanced-strategy-possibly-make-new-root strategy restricted-non-focal-problem))))))
                     (setf state (do-set-contents-update-state state))))))
      (when (eq :transformation motivation)
        (when *balanced-strategy-new-roots-triggered-by-t-on-jo-link?*
          (when (join-ordered-link-p link)
            (let* ((jo-link-var link)
                   (motivating-conjunction-problem (problem-link-supported-problem jo-link-var))
                   (set-contents-var (problem-argument-links motivating-conjunction-problem)))
              (let* ((basis-object (do-set-contents-basis-object set-contents-var))
                     (state (do-set-contents-initial-state basis-object set-contents-var)))
                (loop until (do-set-contents-done? basis-object state)
                      do (let ((rt-link (do-set-contents-next basis-object state)))
                           (when (do-set-contents-element-valid? state rt-link)
                             (when (problem-link-has-type? rt-link :residual-transformation)
                               ;; Likely checks if the RT link is motivated -- evidence: guards new root creation
                               (when (missing-larkc 35059)
                                 ;; Likely creates a new root via the RT link -- evidence: triggered by T on JO link
                                 (missing-larkc 35706)))))
                         (setf state (do-set-contents-update-state state))))))))))
  (when (eq :transformation motivation)
    (when (transformation-link-p link-head)
      (balanced-strategy-propagate-transformation-motivation-to-transformation-link strategy link-head))
    (when (split-tactic-p link-head)
      (let ((split-tactic link-head))
        ;; Likely propagates transformation motivation down a split link -- evidence: split tactic handling during T motivation
        (missing-larkc 35707)
        (when (balanced-strategy-problem-motivated-wrt-removal? strategy (tactic-problem split-tactic))
          ;; Likely propagates removal motivation through the split tactic -- evidence: conditional on R motivation
          (missing-larkc 35711))))
    (when (union-tactic-p link-head)
      (let ((union-tactic link-head))
        (declare (ignore union-tactic))
        ;; Likely propagates transformation motivation down a union link -- evidence: union tactic handling during T motivation
        (missing-larkc 35709))))
  nil)

(defun balanced-strategy-propagate-transformation-motivation-to-transformation-link (strategy t-link)
  (if (balanced-strategy-chooses-to-make-d-a-new-root? strategy t-link)
      (let ((residual-problem (transformation-link-supporting-problem t-link)))
        (balanced-strategy-possibly-make-new-root strategy residual-problem))
      (let ((count 0))
        (dolist (new-root
                 ;; Likely computes transformation-link new root candidates -- evidence: iterates over new roots for T link
                 (missing-larkc 35713))
          (when (balanced-strategy-possibly-make-new-root strategy new-root)
            (incf count)))
        count)))

(defun balanced-strategy-chooses-to-make-d-a-new-root? (strategy t-link)
  "[Cyc] @return booleanp; whether STRATEGY chooses that 'D', rather than '(^ A D), should
be a new root.  'D' is the supporting transformed problem of T-LINK, and '(^ A D) is
a residual conjunction problem of some residual transformation argument link of D."
  (null (balanced-strategy-residual-conjunction-new-root-candidates strategy t-link)))

(defparameter *balanced-strategy-self-expanding-rule-fix-enabled?* t
  "[Cyc] When deciding whether a problem is motivated via residual transformation, if
the rule used on the transformation link is a self expanding rule and this fix is
enabled, prevents the motivation from flowing.")

(defun balanced-strategy-residual-conjunction-new-root-candidates (strategy t-link)
  (let ((new-roots nil))
    (when (or (not *balanced-strategy-self-expanding-rule-fix-enabled?*)
              (not (self-expanding-rule? (transformation-link-rule-assertion t-link))))
      (let* ((t-link-var t-link)
             (supported-problem (problem-link-supported-problem t-link-var))
             (set-contents-var (problem-dependent-links supported-problem)))
        (let* ((basis-object (do-set-contents-basis-object set-contents-var))
               (state (do-set-contents-initial-state basis-object set-contents-var)))
          (loop until (do-set-contents-done? basis-object state)
                do (let ((jo-link-var (do-set-contents-next basis-object state)))
                     (when (do-set-contents-element-valid? state jo-link-var)
                       (when (problem-link-has-type? jo-link-var :join-ordered)
                         (let* ((jo-link-var-1 jo-link-var)
                                (motivating-conjunction-problem (problem-link-supported-problem jo-link-var-1))
                                (set-contents-var-2 (problem-argument-links motivating-conjunction-problem)))
                           (let* ((basis-object-3 (do-set-contents-basis-object set-contents-var-2))
                                  (state-4 (do-set-contents-initial-state basis-object-3 set-contents-var-2)))
                             (loop until (do-set-contents-done? basis-object-3 state-4)
                                   do (let ((rt-link (do-set-contents-next basis-object-3 state-4)))
                                        (when (do-set-contents-element-valid? state-4 rt-link)
                                          (when (problem-link-has-type? rt-link :residual-transformation)
                                            ;; Likely checks if RT link is open/valid -- evidence: guards new root candidate selection
                                            (when (missing-larkc 35060)
                                              ;; Likely checks if the RT link's supporting problem is relevant -- evidence: another guard before candidate selection
                                              (when (missing-larkc 35064)
                                                (let ((candidate-new-root
                                                        ;; Likely gets the supporting problem of the RT link -- evidence: becomes a new root candidate
                                                        (missing-larkc 35095)))
                                                  (when (problem-relevant-to-strategy? candidate-new-root strategy)
                                                    (let* ((jo-link
                                                             ;; Likely gets the associated JO link for the RT link -- evidence: used to check JO tactic motivation
                                                             (missing-larkc 35067))
                                                           (jo-tactic (join-ordered-link-tactic jo-link)))
                                                      (when (or (not *balanced-strategy-new-roots-check-for-t-on-jo-link?*)
                                                                (balanced-strategy-link-head-motivated-wrt-transformation? strategy jo-tactic))
                                                        (push candidate-new-root new-roots))))))))))
                                      (setf state-4 (do-set-contents-update-state state-4))))))))
                   (setf state (do-set-contents-update-state state))))))
    (nreverse new-roots)))

;; (defun balanced-strategy-possibly-propagate-new-root-motivation-down-split-link (strategy split-link) ...) -- active declareFunction, no body
;; (defun balanced-strategy-possibly-propagate-new-root-motivation-down-union-link (strategy union-link) ...) -- active declareFunction, no body
;; (defun balanced-strategy-transformation-new-root-candidates (strategy t-link) ...) -- active declareFunction, no body
;; (defun balanced-strategy-possibly-motivate-new-root-via-residual-transformation-link (strategy rt-link &optional jo-link) ...) -- active declareFunction, no body
;; (defun balanced-strategy-allows-transformation-link-to-propagate-new-root-motivation? (strategy t-link) ...) -- active declareFunction, no body
;; (defun balanced-strategy-allows-problem-to-propagate-new-root-motivation? (strategy problem) ...) -- active declareFunction, no body
;; (defun balanced-strategy-link-motivates-problem-wrt-removal? (strategy link &optional problem) ...) -- active declareFunction, no body
;; (defun balanced-strategy-link-motivates-problem-wrt-transformation? (strategy link &optional problem) ...) -- active declareFunction, no body

(defun balanced-strategy-link-motivates-problem? (strategy link motivation &optional problem)
  "[Cyc] @return booleanp"
  (if (not (split-link-p link))
      (balanced-strategy-link-motivates-lookahead-problem? strategy link motivation)
      (let ((motivated? nil)
            (problem-var problem)
            (set-contents-var (problem-dependent-links problem)))
        (let* ((basis-object (do-set-contents-basis-object set-contents-var))
               (state (do-set-contents-initial-state basis-object set-contents-var)))
          (loop until (or motivated?
                         (do-set-contents-done? basis-object state))
                do (let ((dependent-link (do-set-contents-next basis-object state)))
                     (when (do-set-contents-element-valid? state dependent-link)
                       (let ((link-var dependent-link))
                         (dolist (mapped-problem (problem-link-supporting-mapped-problems link-var))
                           (when motivated? (return))
                           (when (do-problem-link-open-match? t link-var mapped-problem)
                             (when (eq problem-var (mapped-problem-problem mapped-problem))
                               (let ((supported-problem (problem-link-supported-problem dependent-link)))
                                 (dolist (tactic (problem-tactics supported-problem))
                                   (when motivated? (return))
                                   (when (split-tactic-p tactic)
                                     (let ((supporting-mapped-problem (find-split-tactic-supporting-mapped-problem tactic)))
                                       (when (eq mapped-problem supporting-mapped-problem)
                                         (when (balanced-strategy-link-head-motivated? strategy motivation tactic)
                                           (setf motivated? t)))))))))))))
                   (setf state (do-set-contents-update-state state))))
        motivated?)))

(defun balanced-strategy-link-motivates-lookahead-problem? (strategy link motivation)
  "[Cyc] @return booleanp"
  (cond
    ((motivation-strategem-link-p link)
     (balanced-strategy-link-head-motivated? strategy motivation link))
    ((split-link-p link)
     nil)
    ((logical-link-p link)
     (let ((tactic (logical-link-unique-tactic link)))
       (balanced-strategy-link-head-motivated? strategy motivation tactic)))
    (t nil)))

(defun balanced-strategy-possibly-propagate-motivation-to-problem (strategy motivation problem)
  "[Cyc] @return booleanp"
  (cond
    ((eql motivation :new-root)
     (balanced-strategy-possibly-propagate-new-root-motivation-to-problem strategy problem))
    ((eql motivation :removal)
     (balanced-strategy-possibly-propagate-removal-motivation-to-problem strategy problem))
    ((eql motivation :transformation)
     (balanced-strategy-possibly-propagate-transformation-motivation-to-problem strategy problem))
    (t
     (error "unexpected motivation ~s" motivation))))

(defun balanced-strategy-possibly-make-new-root (strategy problem)
  "[Cyc] @return booleanp"
  (balanced-strategy-possibly-propagate-new-root-motivation-to-problem strategy problem))

(defun balanced-strategy-possibly-propagate-new-root-motivation-to-problem (strategy problem)
  "[Cyc] @return booleanp"
  (let ((already-motivated? (balanced-strategy-problem-motivated-wrt-new-root? strategy problem)))
    (when (not already-motivated?)
      (balanced-strategy-propagate-new-root-motivation-to-problem strategy problem)
      (return-from balanced-strategy-possibly-propagate-new-root-motivation-to-problem t))
    nil))

(defun balanced-strategy-propagate-new-root-motivation-to-problem (strategy problem)
  (balanced-strategy-note-problem-motivated-wrt-new-root strategy problem)
  ;; iterate over split links
  (let ((set-contents-var (problem-argument-links problem)))
    (let* ((basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((split-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state split-link)
                   (when (problem-link-has-type? split-link :split)
                     ;; Likely propagates new-root motivation down split link -- evidence: iterating argument links for split type
                     (missing-larkc 35708))))
               (setf state (do-set-contents-update-state state)))))
  ;; iterate over union links
  (let ((set-contents-var (problem-argument-links problem)))
    (let* ((basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((union-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state union-link)
                   (when (problem-link-has-type? union-link :union)
                     ;; Likely propagates new-root motivation down union link -- evidence: iterating argument links for union type
                     (missing-larkc 35710))))
               (setf state (do-set-contents-update-state state)))))
  ;; iterate over join-ordered links with early removal
  (let ((set-contents-var (problem-argument-links problem)))
    (let* ((basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state link)
                   (when (problem-link-has-type? link :join-ordered)
                     (when (balanced-strategy-early-removal-link? strategy link)
                       (let* ((link-var link)
                              (set-contents-var-6 (problem-argument-links
                                                   (join-ordered-link-non-focal-problem link-var))))
                         (let* ((basis-object-7 (do-set-contents-basis-object set-contents-var-6))
                                (state-8 (do-set-contents-initial-state basis-object-7 set-contents-var-6)))
                           (loop until (do-set-contents-done? basis-object-7 state-8)
                                 do (let ((restriction-link (do-set-contents-next basis-object-7 state-8)))
                                      (when (do-set-contents-element-valid? state-8 restriction-link)
                                        (when (problem-link-has-type? restriction-link :restriction)
                                          (when (non-focal-restriction-link-with-corresponding-focal-proof? restriction-link link-var)
                                            (let ((restricted-non-focal-problem (problem-link-sole-supporting-problem restriction-link)))
                                              (balanced-strategy-possibly-make-new-root strategy restricted-non-focal-problem))))))
                                    (setf state-8 (do-set-contents-update-state state-8)))))))))
               (setf state (do-set-contents-update-state state)))))
  (when (problem-relevant-to-strategy? problem strategy)
    (balanced-strategy-possibly-activate-problem-wrt-new-root strategy problem))
  nil)

(defun balanced-strategy-possibly-propagate-removal-motivation-to-problem (strategy problem)
  "[Cyc] @return booleanp"
  (let ((already-motivated? (balanced-strategy-problem-motivated-wrt-removal? strategy problem)))
    (when (not already-motivated?)
      (balanced-strategy-propagate-removal-motivation-to-problem strategy problem)
      (return-from balanced-strategy-possibly-propagate-removal-motivation-to-problem t))
    nil))

(defun balanced-strategy-propagate-removal-motivation-to-problem (strategy problem)
  (balanced-strategy-note-problem-motivated-wrt-removal strategy problem)
  ;; iterate over dependent join-ordered links
  (let ((problem-var problem)
        (set-contents-var (problem-dependent-links problem)))
    (let* ((basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((join-ordered-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state join-ordered-link)
                   (when (problem-link-has-type? join-ordered-link :join-ordered)
                     (let ((link-var join-ordered-link))
                       (dolist (mapped-problem (problem-link-supporting-mapped-problems link-var))
                         (when (do-problem-link-open-match? t link-var mapped-problem)
                           (when (eq problem-var (mapped-problem-problem mapped-problem))
                             ;; Likely checks if join-ordered link is the focal link -- evidence: guards proof-based motivation propagation
                             (when (missing-larkc 35704)
                               (let ((status-var :proven))
                                 (maphash (lambda (v-bindings proof-list)
                                            (declare (ignore v-bindings))
                                            (dolist (proof proof-list)
                                              (when (proof-has-status? proof status-var)
                                                (let* ((restricted-non-focal-mapped-problem
                                                         ;; Likely gets the restricted non-focal mapped problem for the proof -- evidence: feeds into removal motivation propagation
                                                         (missing-larkc 36362))
                                                       (restricted-non-focal-problem (mapped-problem-problem restricted-non-focal-mapped-problem)))
                                                  (balanced-strategy-possibly-propagate-removal-motivation-to-problem strategy restricted-non-focal-problem)))))
                                          (problem-proof-bindings-index problem)))))))))))
               (setf state (do-set-contents-update-state state)))))
  ;; iterate over transformation argument links
  (let ((set-contents-var (problem-argument-links problem)))
    (let* ((basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((transformation-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state transformation-link)
                   (when (problem-link-has-type? transformation-link :transformation)
                     ;; Likely checks if the transformation link should propagate motivation -- evidence: guards new root creation
                     (when (missing-larkc 35698)
                       (let ((supporting-transformed-problem (transformation-link-supporting-problem transformation-link)))
                         (balanced-strategy-possibly-make-new-root strategy supporting-transformed-problem))))))
               (setf state (do-set-contents-update-state state)))))
  (when (problem-relevant-to-strategy? problem strategy)
    (balanced-strategy-possibly-activate-problem-wrt-removal strategy problem))
  nil)

(defun balanced-strategy-possibly-propagate-transformation-motivation-to-problem (strategy problem)
  "[Cyc] @return booleanp"
  (must (not (strategy-throws-away-all-transformation? strategy))
        "~s tried to propagate T to ~s but it throws away all transformation" strategy problem)
  (let ((already-motivated? (balanced-strategy-problem-motivated-wrt-transformation? strategy problem)))
    (when (not already-motivated?)
      (balanced-strategy-propagate-transformation-motivation-to-problem strategy problem)
      (return-from balanced-strategy-possibly-propagate-transformation-motivation-to-problem t)))
  nil)

(defun balanced-strategy-propagate-transformation-motivation-to-problem (strategy problem)
  (balanced-strategy-note-problem-motivated-wrt-transformation strategy problem)
  ;; iterate over join-ordered links with early removal
  (let ((set-contents-var (problem-argument-links problem)))
    (let* ((basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state link)
                   (when (problem-link-has-type? link :join-ordered)
                     (when (balanced-strategy-early-removal-link? strategy link)
                       (let* ((link-var link)
                              (set-contents-var-10 (problem-argument-links
                                                    (join-ordered-link-non-focal-problem link-var))))
                         (let* ((basis-object-11 (do-set-contents-basis-object set-contents-var-10))
                                (state-12 (do-set-contents-initial-state basis-object-11 set-contents-var-10)))
                           (loop until (do-set-contents-done? basis-object-11 state-12)
                                 do (let ((restriction-link (do-set-contents-next basis-object-11 state-12)))
                                      (when (do-set-contents-element-valid? state-12 restriction-link)
                                        (when (problem-link-has-type? restriction-link :restriction)
                                          (when (non-focal-restriction-link-with-corresponding-focal-proof? restriction-link link-var)
                                            (let ((restricted-non-focal-problem (problem-link-sole-supporting-problem restriction-link)))
                                              (balanced-strategy-possibly-make-new-root strategy restricted-non-focal-problem))))))
                                    (setf state-12 (do-set-contents-update-state state-12)))))))))
               (setf state (do-set-contents-update-state state)))))
  (when (problem-relevant-to-strategy? problem strategy)
    (balanced-strategy-possibly-activate-problem-wrt-transformation strategy problem))
  nil)

(defun balanced-strategy-possibly-activate-problem (strategy problem)
  "[Cyc] @return booleanp; whether STRATEGY chose to activate PROBLEM."
  (when (balanced-strategy-chooses-not-to-examine-problem? strategy problem)
    (return-from balanced-strategy-possibly-activate-problem nil))
  (determine-strategic-status-wrt problem strategy)
  (when (balanced-strategy-chooses-not-to-activate-problem? strategy problem)
    (return-from balanced-strategy-possibly-activate-problem nil))
  (when (problem-is-a-simplification? problem)
    (balanced-strategy-possibly-propagate-removal-motivation-to-problem strategy problem)
    (when (not (strategy-throws-away-all-transformation? strategy))
      (when *simplification-tactics-execute-early-and-pass-down-transformation-motivation?*
        (balanced-strategy-possibly-propagate-transformation-motivation-to-problem strategy problem))))
  (when (balanced-strategy-problem-is-the-rest-of-a-removal? problem strategy)
    (balanced-strategy-possibly-propagate-removal-motivation-to-problem strategy problem))
  (when (balanced-strategy-motivates-problem-via-rewrite? strategy problem)
    (balanced-strategy-possibly-propagate-removal-motivation-to-problem strategy problem))
  (when (balanced-strategy-problem-is-the-rest-of-a-join-ordered? problem strategy)
    (balanced-strategy-possibly-propagate-proof-spec-to-restricted-non-focals strategy problem))
  (when (not (strategy-throws-away-all-transformation? strategy))
    (when (balanced-strategy-problem-is-the-rest-of-an-early-removal? problem strategy)
      (balanced-strategy-possibly-propagate-new-root-motivation-to-problem strategy problem)))
  (let ((activated? nil))
    (when (balanced-strategy-possibly-activate-problem-wrt-new-root strategy problem)
      (setf activated? t))
    (when (balanced-strategy-possibly-activate-problem-wrt-removal strategy problem)
      (setf activated? t))
    (when (balanced-strategy-possibly-activate-problem-wrt-transformation strategy problem)
      (setf activated? t))
    activated?))

(defun balanced-strategy-problem-is-the-rest-of-a-removal? (problem strategy)
  "[Cyc] if you are a restricted non-focal problem of some (open?) join-ordered link which has R,
   you get R.  you're the rest of a removal."
  (let ((set-contents-var (problem-dependent-links problem)))
    (let* ((basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((restriction-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state restriction-link)
                   (when (problem-link-has-type? restriction-link :restriction)
                     (let* ((non-focal-problem (problem-link-supported-problem restriction-link))
                            (set-contents-var-13 (problem-dependent-links non-focal-problem)))
                       (let* ((basis-object-14 (do-set-contents-basis-object set-contents-var-13))
                              (state-15 (do-set-contents-initial-state basis-object-14 set-contents-var-13)))
                         (loop until (do-set-contents-done? basis-object-14 state-15)
                               do (let ((join-ordered-link (do-set-contents-next basis-object-14 state-15)))
                                    (when (do-set-contents-element-valid? state-15 join-ordered-link)
                                      (when (problem-link-has-type? join-ordered-link :join-ordered)
                                        (when (join-ordered-link-restricted-non-focal-link? join-ordered-link restriction-link)
                                          (when (eq non-focal-problem (join-ordered-link-non-focal-problem join-ordered-link))
                                            (when (and (problem-link-open? join-ordered-link)
                                                       (balanced-strategy-link-motivates-lookahead-problem? strategy join-ordered-link :removal))
                                              (return-from balanced-strategy-problem-is-the-rest-of-a-removal? t)))))))
                                  (setf state-15 (do-set-contents-update-state state-15))))))))
               (setf state (do-set-contents-update-state state)))))
  nil)

(defun balanced-strategy-problem-is-the-rest-of-an-early-removal? (problem strategy)
  "[Cyc] if you are a restricted non-focal problem of some early removal link,
   you get N.  you're the rest of an early removal."
  (let ((set-contents-var (problem-dependent-links problem)))
    (let* ((basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((restriction-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state restriction-link)
                   (when (problem-link-has-type? restriction-link :restriction)
                     (let* ((non-focal-problem (problem-link-supported-problem restriction-link))
                            (set-contents-var-16 (problem-dependent-links non-focal-problem)))
                       (let* ((basis-object-17 (do-set-contents-basis-object set-contents-var-16))
                              (state-18 (do-set-contents-initial-state basis-object-17 set-contents-var-16)))
                         (loop until (do-set-contents-done? basis-object-17 state-18)
                               do (let ((join-ordered-link (do-set-contents-next basis-object-17 state-18)))
                                    (when (do-set-contents-element-valid? state-18 join-ordered-link)
                                      (when (problem-link-has-type? join-ordered-link :join-ordered)
                                        (when (join-ordered-link-restricted-non-focal-link? join-ordered-link restriction-link)
                                          (when (eq non-focal-problem (join-ordered-link-non-focal-problem join-ordered-link))
                                            (when (balanced-strategy-chooses-to-propagate-new-root-motivation-to-restricted-non-focal-problem? strategy problem join-ordered-link)
                                              (return-from balanced-strategy-problem-is-the-rest-of-an-early-removal? t)))))))
                                  (setf state-18 (do-set-contents-update-state state-18))))))))
               (setf state (do-set-contents-update-state state)))))
  nil)

(defun balanced-strategy-problem-is-the-rest-of-a-join-ordered? (problem strategy)
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
                            (set-contents-var-19 (problem-dependent-links non-focal-problem)))
                       (let* ((basis-object-20 (do-set-contents-basis-object set-contents-var-19))
                              (state-21 (do-set-contents-initial-state basis-object-20 set-contents-var-19)))
                         (loop until (or part-of-join-ordered?
                                       (do-set-contents-done? basis-object-20 state-21))
                               do (let ((join-ordered-link (do-set-contents-next basis-object-20 state-21)))
                                    (when (do-set-contents-element-valid? state-21 join-ordered-link)
                                      (when (problem-link-has-type? join-ordered-link :join-ordered)
                                        (when (join-ordered-link-restricted-non-focal-link? join-ordered-link restriction-link)
                                          (when (eq non-focal-problem (join-ordered-link-non-focal-problem join-ordered-link))
                                            (setf part-of-join-ordered? t))))))
                                  (setf state-21 (do-set-contents-update-state state-21))))))))
               (setf state (do-set-contents-update-state state))))
    part-of-join-ordered?))

(defun balanced-strategy-possibly-propagate-proof-spec-to-restricted-non-focals (strategy problem)
  (declare (ignore strategy problem))
  nil)

;; (defun balanced-strategy-problem-motivated-without-join-ordered-wrt-removal? (strategy problem) ...) -- active declareFunction, no body

(defun balanced-strategy-motivates-problem-via-rewrite? (strategy problem)
  "[Cyc] if you are a supporting rewritten problem of a rewrite link whose supported problem has R,
   you get R."
  (when (problem-store-rewrite-allowed? (strategy-problem-store strategy))
    (let ((set-contents-var (problem-dependent-links problem)))
      (let* ((basis-object (do-set-contents-basis-object set-contents-var))
             (state (do-set-contents-initial-state basis-object set-contents-var)))
        (loop until (do-set-contents-done? basis-object state)
              do (let ((link (do-set-contents-next basis-object state)))
                   (when (do-set-contents-element-valid? state link)
                     (when (problem-link-has-type? link :rewrite)
                       (when (balanced-strategy-problem-motivated-wrt-removal? strategy (problem-link-supported-problem link))
                         (return-from balanced-strategy-motivates-problem-via-rewrite? t)))))
                 (setf state (do-set-contents-update-state state))))))
  nil)

(defun balanced-strategy-chooses-to-propagate-new-root-motivation-to-restricted-non-focal-problem? (strategy problem join-ordered-link)
  (declare (ignore problem))
  (cond
    ((balanced-strategy-treats-restricted-non-focal-as-new-root? strategy join-ordered-link) t)
    ((balanced-strategy-early-removal-link? strategy join-ordered-link) t)
    (t nil)))

(defun balanced-strategy-treats-restricted-non-focal-as-new-root? (strategy join-ordered-link)
  (declare (ignore strategy))
  (or (join-ordered-link-with-non-focal-unbound-predicate? join-ordered-link)
      (join-ordered-link-with-non-focal-isa-unbound-unbound-where-arg2-is-restricted? join-ordered-link)
      nil))

(defun balanced-strategy-chooses-not-to-examine-problem? (strategy problem)
  (strategy-deems-problem-tactically-uninteresting? strategy problem))

(defun balanced-strategy-chooses-not-to-activate-problem? (strategy problem)
  (and (balanced-strategy-chooses-not-to-activate-problem-wrt-new-root? strategy problem)
       (balanced-strategy-chooses-not-to-activate-problem-wrt-removal? strategy problem)
       (balanced-strategy-chooses-not-to-activate-problem-wrt-transformation? strategy problem)))

(defun balanced-strategy-chooses-not-to-activate-problem-wrt-new-root? (strategy problem)
  (or (balanced-strategy-problem-active? strategy problem :new-root)
      (balanced-strategy-problem-pending? strategy problem :new-root)))

(defun balanced-strategy-chooses-not-to-activate-problem-wrt-removal? (strategy problem)
  (or (balanced-strategy-problem-active? strategy problem :removal)
      (balanced-strategy-problem-pending? strategy problem :removal)))

(defun balanced-strategy-chooses-not-to-activate-problem-wrt-transformation? (strategy problem)
  (or (balanced-strategy-problem-active? strategy problem :transformation)
      (balanced-strategy-problem-pending? strategy problem :transformation)))

(defun balanced-strategy-possibly-activate-problem-wrt-new-root (strategy problem)
  (let ((activate? (and (balanced-strategy-problem-motivated-wrt-new-root? strategy problem)
                        (not (balanced-strategy-chooses-not-to-activate-problem-wrt-new-root? strategy problem)))))
    (when activate?
      (if (balanced-strategy-activate-problem-wrt-new-root strategy problem)
          (return-from balanced-strategy-possibly-activate-problem-wrt-new-root t)
          (progn
            (balanced-strategy-make-problem-pending strategy problem :new-root)
            (return-from balanced-strategy-possibly-activate-problem-wrt-new-root nil)))))
  nil)

(defun balanced-strategy-possibly-activate-problem-wrt-removal (strategy problem)
  (let ((activate? (and (balanced-strategy-problem-motivated-wrt-removal? strategy problem)
                        (not (balanced-strategy-chooses-not-to-activate-problem-wrt-removal? strategy problem)))))
    (when activate?
      (if (balanced-strategy-activate-problem-wrt-removal strategy problem)
          (return-from balanced-strategy-possibly-activate-problem-wrt-removal t)
          (progn
            (balanced-strategy-make-problem-pending strategy problem :removal)
            (return-from balanced-strategy-possibly-activate-problem-wrt-removal nil)))))
  nil)

(defun balanced-strategy-possibly-activate-problem-wrt-transformation (strategy problem)
  (let ((activate? (and (balanced-strategy-problem-motivated-wrt-transformation? strategy problem)
                        (not (balanced-strategy-chooses-not-to-activate-problem-wrt-transformation? strategy problem)))))
    (when activate?
      (if (balanced-strategy-activate-problem-wrt-transformation strategy problem)
          (return-from balanced-strategy-possibly-activate-problem-wrt-transformation t)
          (progn
            (balanced-strategy-make-problem-pending strategy problem :transformation)
            (return-from balanced-strategy-possibly-activate-problem-wrt-transformation nil)))))
  nil)

(defun balanced-strategy-activate-problem-wrt-new-root (strategy problem)
  (declare (type balanced-strategy-p strategy))
  (declare (type problem-p problem))
  (plusp (balanced-strategy-possibly-activate-strategems-wrt-new-root strategy problem)))

(defun balanced-strategy-activate-problem-wrt-removal (strategy problem)
  (declare (type balanced-strategy-p strategy))
  (declare (type problem-p problem))
  (plusp (balanced-strategy-possibly-activate-strategems-wrt-removal strategy problem)))

(defun balanced-strategy-activate-problem-wrt-transformation (strategy problem)
  "[Cyc] add all transformation strategems to the R-box or set-asides.
@return booleanp; T unless STRATEGY chooses to throw away PROBLEM."
  (declare (type balanced-strategy-p strategy))
  (declare (type problem-p problem))
  (plusp (balanced-strategy-possibly-activate-strategems-wrt-transformation strategy problem)))

(defun balanced-strategy-possibly-activate-strategems-wrt-new-root (strategy problem)
  (balanced-strategy-add-new-root strategy problem)
  2)

(defun balanced-strategy-possibly-activate-strategems-wrt-removal (strategy problem)
  (multiple-value-bind (strategems-to-activate strategems-to-set-aside strategems-to-throw-away)
      (balanced-strategy-categorize-strategems-wrt-removal strategy problem)
    (dolist (strategem strategems-to-activate)
      (balanced-strategy-activate-strategem-wrt-removal strategy strategem))
    (dolist (strategem strategems-to-set-aside)
      ;; Likely notes strategem as set-aside in balanced strategy -- evidence: parallel to throw-away pattern below
      (missing-larkc 36524)
      (when (tactic-p strategem)
        (set-tactic-set-aside-wrt strategem strategy :removal)))
    (dolist (strategem strategems-to-throw-away)
      (balanced-strategy-note-strategem-thrown-away-wrt-removal strategy strategem)
      (when (tactic-p strategem)
        (set-tactic-thrown-away-wrt strategem strategy :removal)))
    (length strategems-to-activate)))

(defparameter *balanced-strategy-rl-tactician-tactic-types*
  '(:generalized-removal :connected-conjunction :split :union)
  "[Cyc] The tactic types to use the RL tactician's ordering for.")

;; (defun merge-balanced-and-rl-tactician-strategems (strategy strategems-to-activate strategems-to-set-aside strategems-to-throw-away problem motivation) ...) -- active declareFunction, no body
;; (defun balanced-strategy-filter-strategems-by-rlt-tactic-types (strategy strategems) ...) -- active declareFunction, no body
;; (defun balanced-strategy-filter-strategems-by-rlt-tactic-types-int (strategy strategems) ...) -- active declareFunction, no body

(defun balanced-strategy-possibly-activate-strategems-wrt-transformation (strategy problem)
  (multiple-value-bind (strategems-to-activate strategems-to-set-aside strategems-to-throw-away)
      (balanced-strategy-categorize-strategems-wrt-transformation strategy problem)
    (dolist (strategem strategems-to-activate)
      (balanced-strategy-activate-strategem-wrt-transformation strategy strategem))
    (dolist (strategem strategems-to-set-aside)
      ;; Likely notes strategem as set-aside in balanced strategy -- evidence: parallel to removal set-aside pattern
      (missing-larkc 36526)
      (when (tactic-p strategem)
        (set-tactic-set-aside-wrt strategem strategy :transformation)))
    (dolist (strategem strategems-to-throw-away)
      ;; Likely notes strategem as thrown-away in balanced strategy -- evidence: parallel to removal throw-away pattern
      (missing-larkc 36529)
      (when (tactic-p strategem)
        (set-tactic-thrown-away-wrt strategem strategy :transformation)))
    (length strategems-to-activate)))

;; (defun balanced-strategy-activate-transformation-argument-links-wrt-transformation (strategy problem) ...) -- active declareFunction, no body

(defun balanced-strategy-note-argument-link-added (strategy link)
  (when (transformation-link-p link)
    (balanced-strategy-possibly-activate-transformation-link strategy link))
  nil)

(defun balanced-strategy-possibly-activate-transformation-link (strategy transformation-link)
  (when (problem-link-with-supporting-problem-p transformation-link)
    (unless (balanced-strategy-link-head-motivated-wrt-transformation? strategy transformation-link)
      (balanced-strategy-activate-transformation-link strategy transformation-link)))
  nil)

(defun balanced-strategy-activate-transformation-link (strategy transformation-link)
  (balanced-strategy-note-problem-unpending-wrt-transformation strategy (problem-link-supported-problem transformation-link))
  (let ((transformation-tactic (transformation-link-tactic transformation-link)))
    (unless (balanced-strategy-chooses-to-throw-away-tactic? strategy transformation-tactic :transformation)
      (if (balanced-strategy-chooses-to-set-aside-tactic? strategy transformation-tactic :transformation nil nil t)
          ;; Likely notes transformation link set-aside -- evidence: parallel to activation below
          (missing-larkc 36527)
          (balanced-strategy-activate-strategem-wrt-transformation strategy transformation-link))))
  nil)

(defun balanced-strategy-note-new-tactic (strategy tactic)
  (default-compute-strategic-properties-of-tactic strategy tactic)
  (unless (or (and (split-tactic-p tactic)
                   (meta-split-tactics-enabled?))
              (simple-strategy-chooses-to-ignore-tactic? strategy tactic))
    (balanced-strategy-note-new-tactic-possible strategy tactic))
  nil)

;; (defun balanced-strategy-note-split-tactics-strategically-possible (strategy problem) ...) -- active declareFunction, no body

(defun balanced-strategy-note-new-tactic-possible (strategy tactic)
  (let ((problem (tactic-problem tactic)))
    (problem-note-tactic-strategically-possible problem tactic strategy))
  (when (or (and (meta-split-tactics-enabled?)
                 (split-tactic-p tactic))
            (and (transformation-tactic-p tactic)
                 (not (meta-transformation-tactic-p tactic))))
    (let ((problem-already-considered? t))
      (dolist (motivation (if (split-tactic-p tactic)
                              '(:removal :transformation)
                              '(:transformation)))
        (balanced-strategy-note-problem-unpending strategy (tactic-problem tactic) motivation)
        (cond
          ((balanced-strategy-chooses-to-throw-away-tactic? strategy tactic motivation problem-already-considered? nil)
           ;; Likely notes tactic thrown-away for this motivation -- evidence: throw-away case
           (missing-larkc 36528))
          ((balanced-strategy-chooses-to-set-aside-tactic? strategy tactic motivation problem-already-considered? nil t)
           ;; Likely notes tactic set-aside for this motivation -- evidence: set-aside case
           (missing-larkc 36522))
          (t
           (balanced-strategy-activate-strategem strategy tactic motivation))))))
  nil)

;; (defun balanced-strategy-categorize-strategems (strategy problem motivation) ...) -- active declareFunction, no body

(defun balanced-strategy-categorize-strategems-wrt-removal (strategy problem)
  "[Cyc] @return 0 listp of strategem-p; an ordered list of strategems on PROBLEM which STRATEGY may want to activate wrt removal.
   Strategems are ordered in intended order of activation.
   @return 1 listp of strategem-p; an ordered list of strategems on PROBLEM which STRATEGY may want to set aside wrt removal.
   @return 2 listp of strategem-p; an ordered list of strategems on PROBLEM which STRATEGY may want to throw away wrt removal."
  (let ((strategems-to-activate nil)
        (strategems-to-set-aside nil)
        (strategems-to-throw-away nil)
        (problem-set-aside-wrt-removal? (balanced-strategy-chooses-to-set-aside-problem? strategy problem :removal))
        (problem-thrown-away-wrt-removal? (balanced-strategy-chooses-to-throw-away-problem? strategy problem :removal)))
    (multiple-value-bind (best-complete-removal-tactic possible-non-complete-removal-tactics
                          set-aside-removal-tactics thrown-away-removal-tactics)
        (balanced-strategy-categorize-removal-tactics-wrt-removal strategy problem problem-set-aside-wrt-removal? problem-thrown-away-wrt-removal?)
      (multiple-value-bind (possible-motivation-strategems set-aside-motivation-strategems
                            thrown-away-motivation-strategems)
          (balanced-strategy-categorize-motivation-strategems-wrt-removal strategy problem problem-set-aside-wrt-removal? problem-thrown-away-wrt-removal?)
        (setf strategems-to-set-aside (append set-aside-removal-tactics set-aside-motivation-strategems))
        (setf strategems-to-throw-away (append thrown-away-removal-tactics thrown-away-motivation-strategems))
        (setf possible-non-complete-removal-tactics (nreverse possible-non-complete-removal-tactics))
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

(defun balanced-strategy-categorize-motivation-strategems-wrt-removal (strategy problem problem-set-aside-wrt-removal? problem-thrown-away-wrt-removal?)
  (let ((possible-motivation-strategems nil)
        (set-aside-motivation-strategems nil)
        (thrown-away-motivation-strategems nil))
    (cond
      ((single-literal-problem-p problem)
       ;; no motivation strategems for single literal problems
       )
      ((multi-clause-problem-p problem)
       (multiple-value-setq (possible-motivation-strategems set-aside-motivation-strategems
                             thrown-away-motivation-strategems)
         ;; Likely categorizes disjunctive tactics wrt removal -- evidence: multi-clause problems dispatch to disjunctive categorization
         (missing-larkc 35699)))
      ((problem-has-split-tactics? problem)
       (multiple-value-setq (possible-motivation-strategems set-aside-motivation-strategems
                             thrown-away-motivation-strategems)
         ;; Likely categorizes split tactics wrt removal -- evidence: split-tactic problems dispatch to split categorization
         (missing-larkc 35700)))
      (t
       (multiple-value-setq (possible-motivation-strategems set-aside-motivation-strategems
                             thrown-away-motivation-strategems)
         (balanced-strategy-categorize-connected-conjunction-tactics-wrt-removal strategy problem problem-set-aside-wrt-removal? problem-thrown-away-wrt-removal?))))
    (values possible-motivation-strategems set-aside-motivation-strategems thrown-away-motivation-strategems)))

(defun balanced-strategy-categorize-removal-tactics-wrt-removal (strategy problem problem-set-aside-wrt-removal? problem-thrown-away-wrt-removal?)
  "[Cyc] Possible non-complete removal tactics should be in the reverse intended activation order"
  (let ((best-complete-removal-tactic nil)
        (best-complete-removal-tactic-productivity nil)
        (set-aside-removal-tactics nil)
        (possible-non-complete-removal-tactics nil))
    (unless problem-thrown-away-wrt-removal?
      (dolist (removal-tactic (problem-tactics problem))
        (when (and (do-problem-tactics-type-match removal-tactic :generalized-removal-or-rewrite)
                   (do-problem-tactics-status-match removal-tactic :possible))
          (unless (balanced-strategy-chooses-to-throw-away-tactic? strategy removal-tactic :removal t)
            (if (or problem-set-aside-wrt-removal?
                    (balanced-strategy-chooses-to-set-aside-tactic? strategy removal-tactic :removal t))
                (unless best-complete-removal-tactic
                  (push removal-tactic set-aside-removal-tactics))
                (let ((completeness (tactic-strategic-completeness removal-tactic strategy)))
                  (cond
                    ((eql completeness :complete)
                     (let ((productivity (tactic-strategic-productivity removal-tactic strategy)))
                       (when (or (not best-complete-removal-tactic)
                                 (productivity-< productivity best-complete-removal-tactic-productivity))
                         (setf best-complete-removal-tactic removal-tactic)
                         (setf best-complete-removal-tactic-productivity productivity)
                         (unless (meta-removal-tactic-p best-complete-removal-tactic)
                           (setf possible-non-complete-removal-tactics nil)
                           (setf set-aside-removal-tactics nil)))))
                    ((or (eql completeness :incomplete)
                         (eql completeness :grossly-incomplete))
                     (when (or (not best-complete-removal-tactic)
                               (meta-removal-tactic-p best-complete-removal-tactic))
                       (push removal-tactic possible-non-complete-removal-tactics)))))))))
      (setf possible-non-complete-removal-tactics
            (strategy-sort strategy possible-non-complete-removal-tactics #'tactic-strategic-productivity-<)))
    (let ((thrown-away-removal-tactics nil))
      (dolist (removal-tactic (problem-tactics problem))
        (when (and (do-problem-tactics-type-match removal-tactic :generalized-removal-or-rewrite)
                   (do-problem-tactics-status-match removal-tactic :possible))
          (unless (or (eq removal-tactic best-complete-removal-tactic)
                      (member-eq? removal-tactic possible-non-complete-removal-tactics)
                      (member-eq? removal-tactic set-aside-removal-tactics))
            (push removal-tactic thrown-away-removal-tactics))))
      (values best-complete-removal-tactic possible-non-complete-removal-tactics set-aside-removal-tactics thrown-away-removal-tactics))))

;; (defun balanced-strategy-categorize-disjunctive-tactics-wrt-removal (strategy problem problem-set-aside-wrt-removal? problem-thrown-away-wrt-removal?) ...) -- active declareFunction, no body
;; (defun balanced-strategy-categorize-split-tactics-wrt-removal (strategy problem problem-set-aside-wrt-removal? problem-thrown-away-wrt-removal?) ...) -- active declareFunction, no body

(defun balanced-strategy-categorize-connected-conjunction-tactics-wrt-removal (strategy problem problem-set-aside-wrt-removal? problem-thrown-away-wrt-removal?)
  (let ((possible-motivation-strategems nil)
        (set-aside-motivation-strategems nil)
        (committed-tactic nil)
        (committed-tactic-productivity :positive-infinity)
        (committed-tactic-preference :disallowed)
        (committed-tactic-module-spec :join-ordered)
        (committed-tactic-literal-count 0)
        (cheap-backtracking-tactics nil))
    (unless problem-thrown-away-wrt-removal?
      (let* ((problem-var problem)
             (type-var :connected-conjunction)
             (subsuming-join-ordered-tactics (problem-maximal-subsuming-multi-focal-literal-join-ordered-tactics problem-var type-var)))
        (dolist (candidate-tactic (problem-tactics problem-var))
          (when (do-problem-tactics-type-match candidate-tactic type-var)
            (unless (some-subsuming-join-ordered-tactic? candidate-tactic subsuming-join-ordered-tactics strategy)
              (let* ((link (logical-tactic-link candidate-tactic))
                     (candidate-tactic-module-spec (if (join-tactic-p candidate-tactic) :join :join-ordered)))
                (unless (balanced-strategy-link-motivates-problem? strategy link :removal)
                  (unless (balanced-strategy-chooses-to-throw-away-connected-conjunction-link-wrt-removal? strategy link)
                    (if (or problem-set-aside-wrt-removal?
                            (balanced-strategy-chooses-to-set-aside-connected-conjunction-link-wrt-removal? strategy link))
                        (push candidate-tactic set-aside-motivation-strategems)
                        (let* ((candidate-tactic-productivity (tactic-max-removal-productivity candidate-tactic strategy))
                               (candidate-tactic-preference (tactic-strategic-preference-level candidate-tactic strategy))
                               (candidate-tactic-literal-count (connected-conjunction-tactic-literal-count candidate-tactic))
                               (magic-wand? (magic-wand-tactic? candidate-tactic strategy)))
                          (when magic-wand?
                            (setf candidate-tactic-preference :disallowed))
                          (when (or (not committed-tactic)
                                    (strategy-deems-conjunctive-tactic-spec-better?
                                     candidate-tactic-productivity candidate-tactic-preference
                                     candidate-tactic-module-spec candidate-tactic-literal-count
                                     committed-tactic-productivity committed-tactic-preference
                                     committed-tactic-module-spec committed-tactic-literal-count))
                            (setf committed-tactic candidate-tactic)
                            (setf committed-tactic-productivity candidate-tactic-productivity)
                            (setf committed-tactic-preference candidate-tactic-preference)
                            (setf committed-tactic-module-spec candidate-tactic-module-spec)
                            (setf committed-tactic-literal-count candidate-tactic-literal-count))
                          (when (and (not magic-wand?)
                                     (balanced-strategy-logical-tactic-removal-backtracking-cheap? candidate-tactic strategy))
                            (push candidate-tactic cheap-backtracking-tactics)))))))))))
      (when committed-tactic
        (if (balanced-strategy-commits-to-no-removal-backtracking? strategy committed-tactic committed-tactic-preference)
            (setf cheap-backtracking-tactics nil)
            (setf cheap-backtracking-tactics (delete-first committed-tactic cheap-backtracking-tactics #'eq)))
        (push committed-tactic possible-motivation-strategems)
        (dolist (backtracking-tactic cheap-backtracking-tactics)
          (push backtracking-tactic possible-motivation-strategems))
        (setf possible-motivation-strategems
              (strategy-sort strategy possible-motivation-strategems #'logical-tactic-better-wrt-removal?))))
    (let ((thrown-away-motivation-strategems nil))
      (let* ((problem-var problem)
             (type-var :connected-conjunction)
             (subsuming-join-ordered-tactics (problem-maximal-subsuming-multi-focal-literal-join-ordered-tactics problem-var type-var)))
        (dolist (conjunctive-tactic (problem-tactics problem-var))
          (when (do-problem-tactics-type-match conjunctive-tactic type-var)
            (unless (some-subsuming-join-ordered-tactic? conjunctive-tactic subsuming-join-ordered-tactics strategy)
              (unless (or (member-eq? conjunctive-tactic possible-motivation-strategems)
                          (member-eq? conjunctive-tactic set-aside-motivation-strategems))
                (push conjunctive-tactic thrown-away-motivation-strategems))))))
      (values possible-motivation-strategems set-aside-motivation-strategems thrown-away-motivation-strategems))))

(defun balanced-strategy-commits-to-no-removal-backtracking? (strategy committed-tactic committed-tactic-preference-level)
  (when (if (problem-store-transformation-allowed? (tactic-store committed-tactic))
            (eq :complete (logical-tactic-generalized-removal-completeness committed-tactic strategy))
            (eq :preferred committed-tactic-preference-level))
    (when (balanced-strategy-logical-tactic-removal-backtracking-cheap? committed-tactic strategy)
      (return-from balanced-strategy-commits-to-no-removal-backtracking? t)))
  (when (problem-backchain-required? (tactic-problem committed-tactic))
    (return-from balanced-strategy-commits-to-no-removal-backtracking? t))
  nil)

(defun balanced-strategy-categorize-strategems-wrt-transformation (strategy problem)
  "[Cyc] @return 0 listp of strategem-p; an ordered list of strategems on PROBLEM which STRATEGY may want to activate wrt transformation.
   Strategems are ordered in intended order of activation.
   @return 1 listp of strategem-p; an ordered list of strategems on PROBLEM which STRATEGY may want to set aside wrt transformation.
   @return 2 listp of strategem-p; an ordered list of strategems on PROBLEM which STRATEGY may want to throw away wrt transformation."
  (let ((strategems-to-activate nil)
        (strategems-to-set-aside nil))
    (unless (balanced-strategy-chooses-to-throw-away-problem? strategy problem :transformation)
      (let ((problem-set-aside-wrt-transformation? (balanced-strategy-chooses-to-set-aside-problem? strategy problem :transformation)))
        ;; transformation tactics
        (dolist (transformation-tactic (problem-tactics problem))
          (when (and (do-problem-tactics-type-match transformation-tactic :transformation)
                     (do-problem-tactics-status-match transformation-tactic :possible))
            (unless (balanced-strategy-chooses-to-throw-away-tactic? strategy transformation-tactic :transformation t)
              (if (or problem-set-aside-wrt-transformation?
                      (balanced-strategy-chooses-to-set-aside-tactic? strategy transformation-tactic :transformation t))
                  (push transformation-tactic strategems-to-set-aside)
                  (push transformation-tactic strategems-to-activate)))))
        ;; transformation argument links
        (let ((set-contents-var (problem-argument-links problem)))
          (let* ((basis-object (do-set-contents-basis-object set-contents-var))
                 (state (do-set-contents-initial-state basis-object set-contents-var)))
            (loop until (do-set-contents-done? basis-object state)
                  do (let ((transformation-link (do-set-contents-next basis-object state)))
                       (when (do-set-contents-element-valid? state transformation-link)
                         (when (problem-link-has-type? transformation-link :transformation)
                           (when (problem-link-with-supporting-problem-p transformation-link)
                             (unless (balanced-strategy-link-head-motivated-wrt-transformation? strategy transformation-link)
                               (let ((transformation-tactic (transformation-link-tactic transformation-link)))
                                 (unless (balanced-strategy-chooses-to-throw-away-tactic? strategy transformation-tactic :transformation t)
                                   (if (or problem-set-aside-wrt-transformation?
                                           (balanced-strategy-chooses-to-set-aside-tactic? strategy transformation-tactic :transformation t))
                                       (push transformation-tactic strategems-to-set-aside)
                                       (push transformation-tactic strategems-to-activate)))))))))
                     (setf state (do-set-contents-update-state state)))))
        ;; logical tactics (for non-single-literal problems)
        (unless (single-literal-problem-p problem)
          (dolist (logical-tactic (problem-tactics problem))
            (when (do-problem-tactics-type-match logical-tactic :logical)
              (unless (balanced-strategy-link-head-motivated-wrt-transformation? strategy logical-tactic)
                (unless (balanced-strategy-chooses-to-throw-away-tactic? strategy logical-tactic :transformation t)
                  (if (or problem-set-aside-wrt-transformation?
                          (balanced-strategy-chooses-to-set-aside-tactic? strategy logical-tactic :transformation t))
                      (push logical-tactic strategems-to-set-aside)
                      (push logical-tactic strategems-to-activate)))))))))
    (setf strategems-to-activate (nreverse strategems-to-activate))
    (setf strategems-to-set-aside (nreverse strategems-to-set-aside))
    ;; thrown-away strategems
    (let ((strategems-to-throw-away nil))
      ;; transformation tactics
      (dolist (transformation-tactic (problem-tactics problem))
        (when (and (do-problem-tactics-type-match transformation-tactic :transformation)
                   (do-problem-tactics-status-match transformation-tactic :possible))
          (unless (or (member-eq? transformation-tactic strategems-to-activate)
                      (member-eq? transformation-tactic strategems-to-set-aside))
            (push transformation-tactic strategems-to-throw-away))))
      ;; transformation links
      (let ((set-contents-var (problem-argument-links problem)))
        (let* ((basis-object (do-set-contents-basis-object set-contents-var))
               (state (do-set-contents-initial-state basis-object set-contents-var)))
          (loop until (do-set-contents-done? basis-object state)
                do (let ((transformation-link (do-set-contents-next basis-object state)))
                     (when (do-set-contents-element-valid? state transformation-link)
                       (when (problem-link-has-type? transformation-link :transformation)
                         (unless (or (member-eq? transformation-link strategems-to-activate)
                                     (member-eq? transformation-link strategems-to-set-aside))
                           (push transformation-link strategems-to-throw-away)))))
                   (setf state (do-set-contents-update-state state)))))
      ;; logical tactics
      (dolist (logical-tactic (problem-tactics problem))
        (when (do-problem-tactics-type-match logical-tactic :logical)
          (unless (or (member-eq? logical-tactic strategems-to-activate)
                      (member-eq? logical-tactic strategems-to-set-aside))
            (push logical-tactic strategems-to-throw-away))))
      (values strategems-to-activate strategems-to-set-aside strategems-to-throw-away))))

(defun balanced-strategy-logical-tactic-removal-backtracking-cheap? (logical-tactic strategy)
  (unless (join-tactic-p logical-tactic)
    (let ((removal-backtracking-productivity-threshold (balanced-strategy-removal-backtracking-productivity-limit strategy)))
      (when removal-backtracking-productivity-threshold
        (let ((productivity (tactic-max-removal-productivity logical-tactic strategy)))
          (productivity-<= productivity removal-backtracking-productivity-threshold))))))

;; (defun balanced-strategy-problem-estimated-global-productivity-wrt-removal-strategems (strategy problem) ...) -- active declareFunction, no body
;; (defun balanced-strategy-problem-estimated-global-removal-productivity (strategy problem) ...) -- active declareFunction, no body
;; (defun balanced-strategy-possibly-reconsider-split-set-asides-wrt-removal (strategy problem) ...) -- active declareFunction, no body
;; (defun balanced-strategy-reconsider-one-split-set-aside-wrt-removal (strategy tactic) ...) -- active declareFunction, no body
;; (defun balanced-strategy-possibly-clear-strategic-status-wrt-removal (strategy problem) ...) -- active declareFunction, no body

(defun balanced-strategy-reactivate-executable-strategem (strategy strategem)
  (declare (type balanced-strategy-p strategy))
  (declare (type executable-strategem-p strategem))
  (cond
    ((generalized-removal-tactic-p strategem)
     (balanced-strategy-activate-strategem-wrt-removal strategy strategem))
    ((transformation-tactic-p strategem)
     (balanced-strategy-activate-strategem-wrt-transformation strategy strategem))
    ((meta-structural-tactic-p strategem)
     (balanced-strategy-activate-strategem-wrt-removal strategy strategem)
     strategem)
    (t
     (balanced-strategy-activate-strategem-wrt-removal strategy strategem))))

(defun balanced-strategy-strategically-deactivate-strategem (strategy strategem motivation)
  (when (strategem-invalid-p strategem)
    (return-from balanced-strategy-strategically-deactivate-strategem nil))
  (let* ((strategem-var strategem)
         (problem (strategem-problem strategem-var)))
    (balanced-strategy-deactivate-strategem strategy strategem-var motivation)
    (balanced-strategy-possibly-deactivate-problem strategy problem))
  (when (tactic-p strategem)
    (consider-strategic-ramifications-of-possibly-executed-tactic strategy strategem))
  nil)

(defun balanced-strategy-deactivate-strategem (strategy strategem motivation)
  (cond
    ((eql motivation :removal)
     (balanced-strategy-deactivate-strategem-wrt-removal strategy strategem))
    ((eql motivation :transformation)
     (balanced-strategy-deactivate-strategem-wrt-transformation strategy strategem))
    (t
     (error "unexpected motivation ~s" motivation))))

(defun balanced-strategy-deactivate-strategem-wrt-removal (strategy removal-strategem)
  (declare (type balanced-strategy-p strategy))
  (declare (type removal-strategem-p removal-strategem))
  (let* ((problem (strategem-problem removal-strategem))
         (index (balanced-strategy-problem-total-strategems-active-wrt-removal strategy))
         (count (gethash problem index 0)))
    (setf count (- count 1))
    (if (plusp count)
        (setf (gethash problem index) count)
        (progn
          (remhash problem index)
          (balanced-strategy-note-problem-pending strategy problem :removal)))
    count))

(defun balanced-strategy-deactivate-strategem-wrt-transformation (strategy transformation-strategem)
  (declare (type balanced-strategy-p strategy))
  (declare (type transformation-strategem-p transformation-strategem))
  (let* ((problem (strategem-problem transformation-strategem))
         (index (balanced-strategy-problem-total-strategems-active-wrt-transformation strategy))
         (count (gethash problem index 0)))
    (setf count (- count 1))
    (if (plusp count)
        (setf (gethash problem index) count)
        (progn
          (remhash problem index)
          (balanced-strategy-note-problem-pending strategy problem :transformation)))
    count))

(defun balanced-strategy-possibly-deactivate-problem (strategy problem)
  (when (and (not (balanced-strategy-problem-active? strategy problem :new-root))
             (not (balanced-strategy-problem-active? strategy problem :removal))
             (not (balanced-strategy-problem-active? strategy problem :transformation)))
    (strategy-note-problem-inactive strategy problem)
    (when (or (balanced-strategy-problem-set-aside? strategy problem :new-root)
              (balanced-strategy-problem-set-aside? strategy problem :removal)
              (balanced-strategy-problem-set-aside? strategy problem :transformation))
      (strategy-note-problem-set-aside strategy problem)
      (return-from balanced-strategy-possibly-deactivate-problem t)))
  nil)

(defun balanced-strategy-consider-that-problem-could-be-strategically-totally-pending (strategy problem)
  (let ((pending-wrt-new-root? (balanced-strategy-consider-that-problem-could-be-strategically-pending strategy problem :new-root))
        (pending-wrt-removal? (balanced-strategy-consider-that-problem-could-be-strategically-pending strategy problem :removal))
        (pending-wrt-transformation? (balanced-strategy-consider-that-problem-could-be-strategically-pending strategy problem :transformation)))
    (or pending-wrt-new-root?
        pending-wrt-removal?
        pending-wrt-transformation?
        nil)))

(defun balanced-strategy-consider-that-problem-could-be-strategically-pending (strategy problem motivation)
  (when (balanced-strategy-chooses-to-throw-away-problem? strategy problem motivation)
    (balanced-strategy-make-problem-pending strategy problem motivation)
    (return-from balanced-strategy-consider-that-problem-could-be-strategically-pending t))
  nil)

(defun balanced-strategy-make-problem-pending (strategy problem motivation)
  (balanced-strategy-note-problem-pending strategy problem motivation)
  (balanced-strategy-possibly-deactivate-problem strategy problem)
  nil)

(defun balanced-strategy-early-removal-link? (strategy link)
  "[Cyc] you're join-ordered, you have R, your supported problem has N, your lookahead problem is complete, you're cheap, and you're open."
  (declare (type balanced-strategy-p strategy))
  (declare (type problem-link-p link))
  (and (join-ordered-link-p link)
       (problem-link-open? link)
       (balanced-strategy-connected-conjunction-link-motivated-wrt-removal? strategy link)
       (balanced-strategy-problem-motivated-wrt-new-root? strategy (problem-link-supported-problem link))
       (eq :complete (problem-generalized-removal-completeness
                      (join-ordered-tactic-lookahead-problem (join-ordered-link-tactic link))
                      strategy))
       ;; Likely checks if the lookahead problem is cheap for removal -- evidence: guards early removal qualification
       (missing-larkc 35448)))

(toplevel
  (note-funcall-helper-function 'balanced-strategy-note-new-tactic)
  (note-funcall-helper-function 'balanced-strategy-note-split-tactics-strategically-possible))
