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

(defstruct (balancing-tactician-data
            (:conc-name "BAL-TAC-DATA-")
            (:constructor make-balancing-tactician-data-int ()))
  new-root-substrategy
  transformation-substrategy
  removal-substrategies)

(defconstant *dtp-balancing-tactician-data* 'balancing-tactician-data)

(defun balancing-tactician-data-p (object)
  (typep object 'balancing-tactician-data))

(defun make-balancing-tactician-data (&optional arglist)
  (let ((v-new (make-balancing-tactician-data-int)))
    (loop for next = arglist then (cddr next)
          while next
          for current-arg = (first next)
          for current-value = (second next)
          do (case current-arg
               (:new-root-substrategy
                (setf (bal-tac-data-new-root-substrategy v-new) current-value))
               (:transformation-substrategy
                (setf (bal-tac-data-transformation-substrategy v-new) current-value))
               (:removal-substrategies
                (setf (bal-tac-data-removal-substrategies v-new) current-value))
               (otherwise
                (error "Invalid slot ~S for construction function" current-arg))))
    v-new))

(defun balancing-tactician-p (object)
  (and (strategy-p object)
       (member-eq? (strategy-type object) '(:balancing))))

;; Reconstructed from Internal Constants:
;; $list21 = arglist: ((SUBSTRATEGY-VAR STRATEGY &KEY DONE) &BODY BODY)
;; $sym25$CSOME, $sym26$BALANCING_TACTICIAN_ALL_SUBSTRATEGIES
;; Expands to csome iteration over all substrategies with done as exit test.
(defmacro do-balancing-tactician-substrategies ((substrategy-var strategy &key done) &body body)
  `(csome (,substrategy-var (balancing-tactician-all-substrategies ,strategy) ,done)
     ,@body))

;; Reconstructed from Internal Constants:
;; $sym27$DO_BALANCING_TACTICIAN_SUBSTRATEGIES — wraps do-balancing-tactician-substrategies
;; $sym28$PUNLESS — filters out spineless substrategies
;; $sym29$BALANCING_TACTICIAN_SPINELESS_SUBSTRATEGY_P — the filter predicate
;; Expands to do-balancing-tactician-substrategies with an unless guard
;; that skips spineless substrategies.
(defmacro do-balancing-tactician-spineful-substrategies ((substrategy-var strategy &key done) &body body)
  `(do-balancing-tactician-substrategies (,substrategy-var ,strategy :done ,done)
     (unless (balancing-tactician-spineless-substrategy-p ,substrategy-var)
       ,@body)))

;; (defun new-balancing-tactician-data (new-root-substrategy transformation-substrategy removal-substrategies) ...) -- active declareFunction, no body
;; (defun balancing-tactician-initialize (strategy) ...) -- active declareFunction, no body
;; (defun new-balancing-tactician-data-from-inference (inference) ...) -- active declareFunction, no body
;; (defun balancing-tactician-new-root-substrategy (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-transformation-substrategy (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-removal-substrategies (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-sole-removal-substrategy (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-all-substrategies (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-problem-motivated-wrt-n? (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-problem-motivated-wrt-r? (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-problem-motivated-wrt-t? (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-link-head-motivated-wrt-r? (strategy link-head) ...) -- active declareFunction, no body

(defun balancing-tactician-substrategy-p (object)
  (and (strategy-p object)
       (balancing-tactician-p (controlling-strategy object))))

;; (defun balancing-tactician-proper-substrategy-p (object) ...) -- active declareFunction, no body
;; (defun balancing-tactician-spineless-substrategy-p (object) ...) -- active declareFunction, no body
;; (defun balancing-tactician-done? (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-do-one-step (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-do-one-step-int (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-should-reconsider-set-asides? (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-reconsider-set-asides (strategy) ...) -- active declareFunction, no body
;; (defun substrategy-do-one-step-interestingness (substrategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-continuation-possible? (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-chooses-to-throw-away-tactic? (strategy tactic problem motivation) ...) -- active declareFunction, no body
;; (defun balancing-tactician-chooses-to-set-aside-tactic? (strategy tactic problem motivation) ...) -- active declareFunction, no body
;; (defun balancing-tactician-throw-away-uninteresting-set-asides (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-note-inference-dynamic-properties-updated (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-initialize-properties (strategy strategy-properties) ...) -- active declareFunction, no body
;; (defun balancing-tactician-update-properties (strategy strategy-properties) ...) -- active declareFunction, no body
;; (defun balancing-tactician-initial-relevant-strategies (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-possibly-activate-problem (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-problem-is-the-rest-of-an-early-removal? (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-chooses-to-propagate-new-root-motivation-to-restricted-non-focal-problem? (strategy problem motivation-link) ...) -- active declareFunction, no body
;; (defun balancing-tactician-treats-restricted-non-focal-as-new-root? (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-early-removal-link? (strategy link) ...) -- active declareFunction, no body
;; (defun substrategy-connected-conjunction-link-motivated? (substrategy link) ...) -- active declareFunction, no body
;; (defun balancing-tactician-note-argument-link (strategy argument-link) ...) -- active declareFunction, no body
;; (defun balancing-tactician-early-removal-productivity-limit (strategy) ...) -- active declareFunction, no body
;; (defun balancing-tactician-substrategy-strategem-motivated (strategy substrategy strategem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-substrategy-problem-motivated (strategy substrategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-substrategy-link-motivated (strategy substrategy link) ...) -- active declareFunction, no body
;; (defun balancing-tactician-chooses-to-make-d-a-new-root? (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-residual-conjunction-new-root-candidates (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-transformation-new-root-candidates (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-possibly-make-new-root (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-substrategy-tactic-motivated (strategy substrategy tactic) ...) -- active declareFunction, no body
;; (defun balancing-tactician-substrategy-connected-conjunction-tactic-motivated (strategy substrategy tactic) ...) -- active declareFunction, no body
;; (defun balancing-tactician-possibly-motivate-new-root-via-residual-transformation-link (strategy link) ...) -- active declareFunction, no body
;; (defun balancing-tactician-substrategy-split-tactic-motivated (strategy substrategy tactic) ...) -- active declareFunction, no body
;; (defun balancing-tactician-possibly-propagate-new-root-motivation-down-split-link (strategy link) ...) -- active declareFunction, no body
;; (defun balancing-tactician-substrategy-union-tactic-motivated (strategy substrategy tactic) ...) -- active declareFunction, no body
;; (defun balancing-tactician-possibly-propagate-new-root-motivation-down-union-link (strategy link) ...) -- active declareFunction, no body
;; (defun balancing-tactician-allows-split-tactic-to-be-set-aside-wrt-removal? (strategy substrategy tactic) ...) -- active declareFunction, no body
;; (defun balancing-tactician-chooses-to-totally-throw-away-tactic? (strategy substrategy tactic problem motivation) ...) -- active declareFunction, no body
;; (defun balancing-tactician-substrategy-problem-status-change (strategy substrategy problem old-status new-status) ...) -- active declareFunction, no body
;; (defun balancing-tactician-recompute-problem-status (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-make-problem-no-good (strategy problem) ...) -- active declareFunction, no body
;; (defun balancing-tactician-make-problem-pending (strategy problem) ...) -- active declareFunction, no body
;; (defun transformation-strategy-sibling-removal-strategy (strategy) ...) -- active declareFunction, no body

(defvar *balancing-tactician-early-removal-productivity-limit*
  (productivity-for-number-of-children *transformation-early-removal-threshold*))

(defparameter *balancing-tactician-self-looping-rule-fix-enabled?* t
  "[Cyc] When deciding whether a problem is motivated via residual transformation, if
the rule used on the transformation link is a self looping rule and this fix is
enabled, prevents the motivation from flowing.")

(defvar *balancing-tactician-new-roots-check-for-t-on-jo-link?* t
  "[Cyc] It seems correct to ensure that the motivating join-ordered link has T before using it
to motivate the creation of a new root.  However, turning this to NIL causes 13 haystacks
to become answerable.  Leviathan @todo investigate why, and try to come up with a more
principled fix.")

(defparameter *balancing-tactician-new-roots-triggered-by-t-on-jo-link?* t
  "[Cyc] There ought to be two triggers for new root creation via an RT link:
the motivation transformation link getting T, or the motivating join-ordered link
getting T.  Leviathan experiments indicated that we actually gain
more completeness by refraining from triggering via join-ordered T,
but more recent work requires this to be T for correctness.")

(toplevel
  (inference-strategy-type
   :balancing
   (list :name "Balancing Tactician"
         :comment "A balancing tactician type which delegates to a new-root tactician,
 a transformation tactician, and multiple removal tacticians."
         :constructor 'balancing-tactician-initialize
         :done? 'balancing-tactician-done?
         :do-one-step 'balancing-tactician-do-one-step
         :initial-relevant-strategies 'balancing-tactician-initial-relevant-strategies
         :initialize-properties 'balancing-tactician-initialize-properties
         :update-properties 'balancing-tactician-update-properties
         :inference-dynamic-properties-updated 'balancing-tactician-note-inference-dynamic-properties-updated
         :continuation-possible? 'balancing-tactician-continuation-possible?
         :throw-away-uninteresting-set-asides 'balancing-tactician-throw-away-uninteresting-set-asides
         :early-removal-productivity-limit 'balancing-tactician-early-removal-productivity-limit
         :possibly-activate-problem 'balancing-tactician-possibly-activate-problem
         :throw-away-tactic 'balancing-tactician-chooses-to-throw-away-tactic?
         :set-aside-tactic 'balancing-tactician-chooses-to-set-aside-tactic?
         :new-argument-link 'balancing-tactician-note-argument-link
         :new-tactic 'ignore
         :split-tactics-possible 'ignore
         :problem-could-be-pending 'ignore
         :link-head-motivated? 'false
         :substrategy-strategem-motivated 'balancing-tactician-substrategy-strategem-motivated
         :substrategy-totally-throw-away-tactic 'balancing-tactician-chooses-to-totally-throw-away-tactic?
         :substrategy-allow-split-tactic-set-aside-wrt-removal 'balancing-tactician-allows-split-tactic-to-be-set-aside-wrt-removal?
         :substrategy-problem-status-change 'balancing-tactician-substrategy-problem-status-change)))

(toplevel
  (note-funcall-helper-function 'balancing-tactician-initialize)
  (note-funcall-helper-function 'balancing-tactician-done?)
  (note-funcall-helper-function 'balancing-tactician-do-one-step)
  (note-funcall-helper-function 'balancing-tactician-continuation-possible?)
  (note-funcall-helper-function 'balancing-tactician-chooses-to-throw-away-tactic?)
  (note-funcall-helper-function 'balancing-tactician-chooses-to-set-aside-tactic?)
  (note-funcall-helper-function 'balancing-tactician-throw-away-uninteresting-set-asides)
  (note-funcall-helper-function 'balancing-tactician-note-inference-dynamic-properties-updated)
  (note-funcall-helper-function 'balancing-tactician-initialize-properties)
  (note-funcall-helper-function 'balancing-tactician-update-properties)
  (note-funcall-helper-function 'balancing-tactician-initial-relevant-strategies)
  (note-funcall-helper-function 'balancing-tactician-possibly-activate-problem)
  (note-funcall-helper-function 'balancing-tactician-note-argument-link)
  (note-funcall-helper-function 'balancing-tactician-early-removal-productivity-limit)
  (note-funcall-helper-function 'balancing-tactician-substrategy-strategem-motivated)
  (note-funcall-helper-function 'balancing-tactician-allows-split-tactic-to-be-set-aside-wrt-removal?)
  (note-funcall-helper-function 'balancing-tactician-chooses-to-totally-throw-away-tactic?)
  (note-funcall-helper-function 'balancing-tactician-substrategy-problem-status-change))
