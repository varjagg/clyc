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

;;; Enumerated types for the inference harness: query properties, inference
;;; statuses, problem statuses, tactic types, completeness, productivity, etc.

;; ====== Inference metrics ======

(deflexical *specially-handled-inference-metrics*
  '(:new-root-times
    :new-root-count
    :problem-creation-times
    :inference-answer-query-properties
    :inference-strongest-query-properties
    :inference-most-efficient-query-properties)
  "[Cyc] The set of metrics that have special code support in @xref inference-compute-metrics instead of being declared via @xref declare-inference-metric.")

(deflexical *non-inference-query-metrics*
  '(:complete-user-time
    :complete-system-time
    :complete-total-time)
  "[Cyc] The set of metrics that are not to be gathered from the inference object. These are also not declared via @xref declare-inference-metric.")

(deflexical *arete-query-metrics*
  '(:answer-count
    :time-to-first-answer
    :time-to-last-answer
    :total-time))

(deflexical *removal-ask-query-metrics*
  '(:answer-count
    :time-to-first-answer
    :time-to-last-answer
    :time-per-answer
    :latency-improvement-from-iterativity
    :total-time
    :complete-user-time
    :complete-system-time
    :complete-total-time))

;; ====== Inference static properties ======

(deflexical *inference-static-properties*
  '(:disjunction-free-el-vars-policy
    :result-uniqueness
    :problem-store
    :conditional-sentence?
    :non-explanatory-sentence
    :allow-hl-predicate-transformation?
    :allow-unbound-predicate-transformation?
    :allow-evaluatable-predicate-transformation?
    :allow-indeterminate-results?
    :allowed-rules
    :forbidden-rules
    :allowed-modules
    :allow-abnormality-checking?
    :transitive-closure-mode
    :maintain-term-working-set?
    :events
    :halt-conditions)
  "[Cyc] Necessarily essential properties of an inference that are needed at creation time and cannot change while an inference is suspended.")

(deflexical *inference-allows-hl-predicate-transformation-by-default?* nil)
(deflexical *inference-allows-unbound-predicate-transformation-by-default?* nil)
(deflexical *inference-allows-evaluatable-predicate-transformation-by-default?* nil)
(deflexical *inference-allows-indeterminate-results-by-default?* t)
(deflexical *default-allowed-rules* :all)
(deflexical *default-forbidden-rules* :none)
(deflexical *default-allowed-modules* :all)
(deflexical *inference-allows-abnormality-checking-by-default?* t)

;; ====== Inference resource constraints ======

(deflexical *inference-resource-constraints*
  '(:max-number
    :max-time
    :max-step
    :inference-mode)
  "[Cyc] Constraints on how the inference is to be run. These can change while an inference is suspended, and will be honoured upon its continuation.")

(deflexical *default-max-number* nil)
(deflexical *default-max-time* nil)
(deflexical *default-max-step* nil)
(deflexical *default-forward-max-time* 0)
(deflexical *default-max-proof-depth* nil)
(deflexical *default-max-transformation-depth* 0)
(deflexical *default-probably-approximately-done* 1)

;; ====== Inference other dynamic properties ======

(deflexical *inference-other-dynamic-properties*
  '(:forward-max-time
    :max-proof-depth
    :max-transformation-depth
    :probably-approximately-done
    :return
    :answer-language
    :cache-inference-results?
    :forget-extra-results?
    :browsable?
    :continuable?
    :block?
    :metrics)
  "[Cyc] Other properties that can change during suspension, but are not resource constraints.")

(deflexical *default-inference-metrics-template* nil)

;; ====== Strategy static properties ======

(deflexical *strategy-static-properties*
  '(:removal-backtracking-productivity-limit
    :proof-spec))

(deflexical *default-removal-backtracking-productivity-limit*
  200
  "[Cyc] The default productivity above which tactics will not be considered for removal backtracking. The original value is set to 200.")

(deflexical *default-proof-spec*
  :anything
  "[Cyc] The default proof spec that will be used in inference.")

;; ====== Strategy dynamic properties ======

(deflexical *strategy-dynamic-properties*
  '(:productivity-limit))

(deflexical *default-productivity-limit*
  (* 2 100 *default-removal-cost-cutoff*)
  "[Cyc] The default productivity above which tactics will be ignored instead of executed. The original value was set to 2 * 100 * *default-removal-cost-cutoff*. The 100 is for the productivity to number of children multiplier, and the 2 is for the join-ordered productivity multiplier, because everything in the old harness is basically a join-ordered.")

;; ====== Problem store static properties ======

(deflexical *problem-store-static-properties*
  '(:problem-store-name
    :equality-reasoning-method
    :equality-reasoning-domain
    :intermediate-step-validation-level
    :max-problem-count
    :removal-allowed?
    :transformation-allowed?
    :add-restriction-layer-of-indirection?
    :negation-by-failure?
    :completeness-minimization-allowed?
    :direction
    :evaluate-subl-allowed?
    :rewrite-allowed?
    :abduction-allowed?
    :new-terms-allowed?
    :compute-answer-justifications?)
  "[Cyc] The list of valid properties that you can pass in when creating a new problem store")

(deflexical *problem-store-dynamic-properties* nil)

;; ====== Inference meta properties ======

(deflexical *inference-meta-properties*
  '(:inference-mode)
  "[Cyc] A list of meta-properties that can affect all types of other problem store, strategy, and inference properties.")

;; ====== Inference statuses ======

(deflexical *inference-statuses*
  '(:new :prepared :ready :running :suspended :dead :tautology :contradiction :ill-formed))

(deflexical *continuable-inference-statuses*
  '(:prepared :suspended))

(deflexical *avoided-inference-reasons*
  '(:tautology :contradiction :ill-formed :non-trivial :not-a-query)
  "[Cyc] :not-a-query is used by janus-modification-operation-p which overloads the notion of 'inference'.")

(deflexical *inference-suspend-statuses*
  '(:abort :interrupt :max-number :max-time :max-step :max-problem-count
    :max-proof-count :probably-approximately-done :exhaust :exhaust-total)
  "[Cyc] These are the proper suspend statuses, but there are also the inference-halt-conditions.")

(deflexical *continuable-inference-suspend-statuses*
  '(:interrupt :max-number :max-time :max-step :probably-approximately-done :exhaust)
  "[Cyc] The suspend statuses for which the inference is still continuable.")

(deflexical *exhausted-inference-suspend-statuses*
  '(:exhaust :exhaust-total)
  "[Cyc] The suspend statuses that indicate an exhausted inference.")

;; ====== Tactical and provability statuses ======

(deflexical *tactical-statuses*
  '(:new :unexamined :examined :possible :pending :finished))

(deflexical *provability-statuses*
  '(:good :neutral :no-good))

(deflexical *problem-status-table*
  '((:new :new :neutral)
    (:unexamined :unexamined :neutral)
    (:unexamined-good :unexamined :good)
    (:unexamined-no-good :unexamined :no-good)
    (:examined :examined :neutral)
    (:examined-good :examined :good)
    (:examined-no-good :examined :no-good)
    (:possible :possible :neutral)
    (:possible-good :possible :good)
    (:possible-no-good :possible :no-good)
    (:pending :pending :neutral)
    (:pending-good :pending :good)
    (:pending-no-good :pending :no-good)
    (:finished :finished :neutral)
    (:finished-good :finished :good)
    (:finished-no-good :finished :no-good)))

(deflexical *ordered-tactical-statuses*
  ;; Computed from (delete-duplicates (mapcar #'second *problem-status-table*))
  '(:new :unexamined :examined :possible :pending :finished)
  "[Cyc] An ordered list, from weakest to strongest, of the tactical statuses")

;; ====== Problem store property defaults ======

(deflexical *add-restriction-layer-of-indirection-by-default?* nil)
(deflexical *negation-by-failure-by-default?* nil)
(deflexical *evaluate-subl-allowed-default?* t)
(defparameter *rewrite-allowed-default?*
  nil
  "[Cyc] This is a parameter so it can be bound for tests.")
(deflexical *abduction-allowed-default?* nil)
(deflexical *new-terms-allowed-default?* t)
(deflexical *compute-answer-justifications-default?* t)

;; ====== Inference modes ======

(deflexical *default-inference-mode* :custom)

(deflexical *inference-modes*
  '(:minimal :shallow :extended :maximal :custom)
  "[Cyc] The list of inference modes (inference parameter clusters) known to the Strategist. :custom is the special inference mode meaning 'no inference mode, just use the values of the parameters'")

;; ====== Problem link types ======

(deflexical *problem-link-types*
  '(:removal :transformation :residual-transformation :rewrite
    :join-ordered :join :split :restriction :union
    :disjunctive-assumption :answer :indirection))

;; ====== Problem store naming and equality reasoning ======

(deflexical *default-problem-store-name* nil)
(deflexical *default-equality-reasoning-method* :czer-equal)

(deflexical *problem-store-equality-reasoning-methods*
  '(:equal :czer-equal)
  "[Cyc] The methods of equality reasoning the problem store could use to determine whether a new problem is equal to an existing problem.")

(deflexical *default-equality-reasoning-domain* :all)

(deflexical *problem-store-equality-reasoning-domains*
  '(:all :single-literal :none)
  "[Cyc] The domain of the equality reasoning the problem store performs. Does it try to do equality reasoning on all problems, or just a certain subclass of problems?")

;; ====== Intermediate step validation ======

(deflexical *default-intermediate-step-validation-level* :none)

(deflexical *intermediate-step-validation-levels*
  '(:all :arg-type :minimal :none)
  "[Cyc] The levels of intermediate step (proof) validation that can be handled by problem stores.")

;; ====== Problem count ======

(deflexical *default-max-problem-count* 100000)

;; ====== Removal/transformation allowed ======

(deflexical *removal-allowed-by-default?* t)
(deflexical *transformation-allowed-by-default?* t)

;; ====== Inference direction ======

(deflexical *default-problem-store-inference-direction* :backward)

(deflexical *inference-directions*
  '(:backward :forward))

;; ====== Tactic statuses and types ======

(deflexical *tactic-statuses*
  '(:possible :executed :discarded))

(deflexical *tactic-types*
  '(:removal :meta-removal :transformation :rewrite :structural :removal-conjunctive))

;; ====== Completeness ======

(deflexical *ordered-completenesses*
  '(:impossible :grossly-incomplete :incomplete :complete)
  "[Cyc] These are sorted from least complete to most complete.")

;; ====== Productivity ======

(deflexical *productivity-to-number-table*
  (list (cons 0.5d0 50) (cons 1.5d0 150)))

;; ====== Proof statuses ======

(deflexical *proof-statuses*
  '(:proven :rejected))

(deflexical *proof-reject-reasons*
  '(:circular :ill-formed :non-abducible-rule :rejected-subproof
    :max-proof-bubbling-depth :inconsistent-mt-assumptions
    :excepted-assertion :abnormal :problem-no-good
    :modus-tollens-with-non-wff))

;; ====== Destructibility ======

(deflexical *destructibility-statuses*
  '(:indestructible :destructible :unknown))

;; ====== Balancing tactician ======

(defparameter *wallenda?*
  nil
  "[Cyc] Obsolete. Use *balancing-tactician?* instead.")

(defparameter *balancing-tactician?*
  nil
  "[Cyc] Whether to use the balancing tactician, except for abduction.")

;; ====== Strategy type properties ======

(deflexical *balancing-tactician-strategy-type-properties*
  '((:name . :must-override)
    (:comment . :must-override)
    (:constructor . :must-override)
    (:do-one-step . :must-override)
    (:done? . :must-override)
    (:possibly-activate-problem . :must-override)
    (:select-best-strategem . :must-override)
    (:initial-relevant-strategies . default-strategy-initial-relevant-strategies)
    (:new-tactic . :must-override)
    (:split-tactics-possible . :must-override)
    (:initialize-properties . default-strategy-initialize-properties)
    (:update-properties . default-strategy-update-properties)
    (:inference-dynamic-properties-updated . default-strategy-note-inference-dynamic-properties-updated)
    (:reconsider-set-asides . :must-override)
    (:throw-away-uninteresting-set-asides . :must-override)
    (:continuation-possible? . strategy-has-some-set-aside-problems?)
    (:quiesce . :must-override)
    (:new-argument-link . :must-override)
    (:relevant-tactics-wrt-removal . :must-override)
    (:problem-could-be-pending . :must-override)
    (:problem-nothing-to-do? . problem-no-tactics-strategically-possible?)
    (:throw-away-tactic . :must-override)
    (:set-aside-tactic . :must-override)
    (:peek-next-strategem . :must-override)
    (:motivate-strategem . :must-override)
    (:activate-strategem . :must-override)
    (:link-head-motivated? . :must-override)
    (:reconsider-split-set-asides . zero)
    (:substrategy-strategem-motivated . :must-override)
    (:substrategy-totally-throw-away-tactic . :must-override)
    (:substrategy-allow-split-tactic-set-aside-wrt-removal . :must-override)
    (:substrategy-problem-status-change . :must-override)))

(deflexical *legacy-strategy-type-properties*
  '((:early-removal-productivity-limit . :must-override)
    (:peek-new-root . :must-override)
    (:activate-new-root . :must-override)
    (:pop-new-root . :must-override)
    (:no-new-roots . :must-override)
    (:throw-away-new-root . :must-override)
    (:peek-removal-strategem . :must-override)
    (:activate-removal-strategem . :must-override)
    (:pop-removal-strategem . :must-override)
    (:no-active-removal-strategems . :must-override)
    (:peek-transformation-strategem . :must-override)
    (:activate-transformation-strategem . :must-override)
    (:pop-transformation-strategem . :must-override)
    (:no-active-transformation-strategems . :must-override)))

(deflexical *strategy-type-properties*
  (append *balancing-tactician-strategy-type-properties*
          *legacy-strategy-type-properties*))

;; ====== Return types ======

(deflexical *inference-return-types*
  '(:answer :bindings :supports :bindings-and-supports :bindings-and-hypothetical-bindings))

(deflexical *inference-default-return-type*
  :bindings
  "[Cyc] The default :return type for inference.")

;; ====== Answer languages ======

(deflexical *inference-answer-languages*
  '(:el :hl))

(deflexical *inference-default-answer-language* :el)

;; ====== Result uniqueness ======

(deflexical *result-uniqueness-criteria*
  '(:proof :bindings)
  "[Cyc] Ways in which results can be unique in a strategy")

(deflexical *default-result-uniqueness-criterion* :bindings)

;; ====== Disjunction free EL vars policies ======

(deflexical *inference-disjunction-free-el-vars-policies*
  '(:require-equal :compute-intersection :compute-union)
  "[Cyc] Possible policies for handling the free EL vars in disjunctions")

(deflexical *default-inference-disjunction-free-el-vars-policy*
  :require-equal
  "[Cyc] The policy with respect to the handling of free el variables in disjunctive queries. Must be one of :REQUIRE-EQUAL , :COMPUTE-INTERSECTION , or :COMPUTE-UNION .")

;; ====== Transitive closure modes ======

(deflexical *inference-transitive-closure-modes*
  '(:none :focused :all)
  "[Cyc] Possible modes for generating transitive closures in modules such as TVA. :none - no transitive closures :focused - only focused transitive closures (i.e., not in the fan out direction) :all - full transitive closure generation")

(deflexical *inference-transitive-closure-mode-default* :none)

;; ====== Other defaults ======

(deflexical *maintain-term-working-set-default?* nil)
(deflexical *inference-events-default* nil)

(deflexical *inference-event-types*
  '(:new-answer :status-change :new-transformation-depth-reached)
  "[Cyc] :new-answer tells the inference to signal an :inference-new-answer event when a new inference answer is created. :status-change tells the inference to signal an :inference-status-change event when the inference-status changes. :new-transformation-depth-reached tells the inference to signal an :inference-new-transformation-depth-reached event when it reaches a problem deeper than it has reached before. To be extended.")

(deflexical *inference-halt-conditions-default* nil)

(deflexical *inference-halt-conditions*
  '(:look-no-deeper-for-additional-answers)
  "[Cyc] :look-no-deeper-for-additional-answers tells the inference to halt if it's gotten some answers at a transformation depth N and is considering going to depth N+1. To be extended.")

(deflexical *inference-accumulator-types*
  nil
  "[Cyc] An alist mapping inference accumulator names to their initializers.")

(deflexical *inference-default-forget-extra-results?*
  nil
  "[Cyc] Whether the default is to discard the results that exceed the :max-number cutoff")

(deflexical *inference-default-cache-inference-results?*
  nil
  "[Cyc] Whether the default behaviour is to cache the results of inference in the KB")

(deflexical *inference-default-browsable?*
  nil
  "[Cyc] Whether inferences are browsable by default. This is NIL to avoid memory issues.")

(deflexical *inference-default-continuable?*
  nil
  "[Cyc] Whether inferences are continuable by default. This is NIL to avoid memory issues.")


;;; ======================================================================
;;; Functions
;;; ======================================================================

;; ====== Query property predicates ======

(defun query-property-p (object)
  (or (query-static-property-p object)
      (query-dynamic-property-p object)))

;; (defun query-properties-p (object) ...) -- active declareFunction, no body

(defun all-query-properties ()
  "[Cyc] Return a list of all the query properties.
   @note destructible"
  (nconc (all-query-static-properties)
         (all-query-dynamic-properties)))

;; (defun merge-query-properties (properties1 properties2) ...) -- active declareFunction, no body

(defun query-static-property-p (object)
  (or (inference-static-property-p object)
      (problem-store-static-property-p object)
      (strategy-static-property-p object)))

;; (defun query-static-properties-p (object) ...) -- active declareFunction, no body

(defun extract-query-static-properties (properties)
  "[Cyc] WARNING! This will filter out the :inference-mode property! If you're passing the result of this to new-continuable-inference, call @xref extract-query-static-or-meta-properties instead!"
  (filter-plist properties #'query-static-property-p))

(defun all-query-static-properties ()
  "[Cyc] Return a list of all the static query properties.
   @note destructible"
  (nconc (all-inference-static-properties)
         (all-problem-store-static-properties)
         (all-strategy-static-properties)))

;; (defun query-static-or-meta-property-p (object) ...) -- active declareFunction, no body
;; (defun query-static-or-meta-properties-p (object) ...) -- active declareFunction, no body
;; (defun extract-query-static-or-meta-properties (properties) ...) -- active declareFunction, no body

(defun query-dynamic-property-p (object)
  (or (inference-dynamic-property-p object)
      (problem-store-dynamic-property-p object)
      (strategy-dynamic-property-p object)))

;; (defun query-dynamic-properties-p (object) ...) -- active declareFunction, no body

(defun extract-query-dynamic-properties (properties)
  (filter-plist properties #'query-dynamic-property-p))

(defun all-query-dynamic-properties ()
  "[Cyc] Return a list of all the dynamic query properties.
   @note destructible"
  (nconc (all-inference-dynamic-properties)
         (all-problem-store-dynamic-properties)
         (all-strategy-dynamic-properties)))

;; ====== Query metrics ======

(defun query-metric-p (object)
  (and (keywordp object)
       (or (member-eq? object *specially-handled-inference-metrics*)
           (member-eq? object *non-inference-query-metrics*)
           ;; Likely checks if object is a declared-inference-metric -- evidence: the other two branches
           ;; check the two explicitly listed metric sets, so this third branch would check the
           ;; dynamically declared set.
           (missing-larkc 36316))))

(defun inference-query-metric-p (object)
  (and (query-metric-p object)
       (not (memberp object *non-inference-query-metrics*))))

;; (defun all-query-metrics () ...) -- active declareFunction, no body
;; (defun arete-query-metric-p (object) ...) -- active declareFunction, no body
;; (defun all-arete-query-metrics () ...) -- active declareFunction, no body
;; (defun removal-ask-query-metric-p (object) ...) -- active declareFunction, no body

;; ====== Inference property predicates ======

;; (defun inference-property-p (object) ...) -- active declareFunction, no body
;; (defun inference-properties-p (object) ...) -- active declareFunction, no body

(defun inference-static-property-p (object)
  (member-eq? object *inference-static-properties*))

;; (defun inference-static-properties-p (object) ...) -- active declareFunction, no body

(defun extract-inference-static-properties (properties)
  (filter-plist properties #'inference-static-property-p))

(defun all-inference-static-properties ()
  "[Cyc] Return a list of all the static inference properties.
   @note destructible"
  (copy-list *inference-static-properties*))

;; (defun inference-static-or-meta-property-p (object) ...) -- active declareFunction, no body
;; (defun inference-static-or-meta-properties-p (object) ...) -- active declareFunction, no body
;; (defun extract-inference-static-or-meta-properties (properties) ...) -- active declareFunction, no body

;; ====== Inference static property accessors ======

(defun inference-properties-problem-store (properties)
  (getf properties :problem-store nil))

(defun inference-properties-allow-hl-predicate-transformation? (properties)
  (getf properties :allow-hl-predicate-transformation?
        *inference-allows-hl-predicate-transformation-by-default?*))

(defun inference-properties-allow-unbound-predicate-transformation? (properties)
  (getf properties :allow-unbound-predicate-transformation?
        *inference-allows-unbound-predicate-transformation-by-default?*))

(defun inference-properties-allow-evaluatable-predicate-transformation? (properties)
  (getf properties :allow-evaluatable-predicate-transformation?
        *inference-allows-evaluatable-predicate-transformation-by-default?*))

(defun inference-properties-allow-indeterminate-results? (properties)
  (getf properties :allow-indeterminate-results?
        *inference-allows-indeterminate-results-by-default?*))

(defun inference-properties-allowed-rules (properties)
  (getf properties :allowed-rules *default-allowed-rules*))

(defun inference-properties-forbidden-rules (properties)
  (getf properties :forbidden-rules *default-forbidden-rules*))

(defun inference-properties-allowed-modules (properties)
  (getf properties :allowed-modules *default-allowed-modules*))

(defun inference-properties-allow-abnormality-checking? (properties)
  (getf properties :allow-abnormality-checking?
        *inference-allows-abnormality-checking-by-default?*))

;; ====== Inference resource constraints ======

(defun inference-resource-constraint-p (object)
  (member-eq? object *inference-resource-constraints*))

;; (defun inference-resource-constraints-p (object) ...) -- active declareFunction, no body
;; (defun extract-inference-resource-constraints (properties) ...) -- active declareFunction, no body

(defun inference-properties-max-number (properties)
  (getf properties :max-number *default-max-number*))

(defun inference-properties-max-time (properties)
  (getf properties :max-time *default-max-time*))

(defun inference-properties-max-step (properties)
  (getf properties :max-step *default-max-step*))

(defun inference-properties-mode (properties)
  (getf properties :inference-mode *default-inference-mode*))

(defun inference-properties-forward-max-time (properties)
  (getf properties :forward-max-time *default-forward-max-time*))

(defun inference-properties-max-proof-depth (properties)
  (getf properties :max-proof-depth *default-max-proof-depth*))

(defun inference-properties-max-transformation-depth (properties)
  (getf properties :max-transformation-depth *default-max-transformation-depth*))

(defun inference-properties-probably-approximately-done (properties)
  (getf properties :probably-approximately-done *default-probably-approximately-done*))

;; ====== Inference dynamic properties ======

(defun inference-dynamic-property-p (object)
  (or (inference-resource-constraint-p object)
      (member-eq? object *inference-other-dynamic-properties*)))

;; (defun inference-dynamic-properties-p (object) ...) -- active declareFunction, no body

(defun extract-inference-dynamic-properties (properties)
  (filter-plist properties #'inference-dynamic-property-p))

(defun all-inference-dynamic-properties ()
  "[Cyc] Return a list of all the inference dynamic properties.
   @note destructible"
  (nconc (copy-list *inference-other-dynamic-properties*)
         (copy-list *inference-resource-constraints*)))

(defun inference-properties-metrics (properties)
  (getf properties :metrics *default-inference-metrics-template*))

;; ====== Strategy property predicates ======

;; (defun strategy-property-p (object) ...) -- active declareFunction, no body
;; (defun strategy-properties-p (object) ...) -- active declareFunction, no body

(defun strategy-static-property-p (object)
  (member-eq? object *strategy-static-properties*))

;; (defun strategy-static-properties-p (object) ...) -- active declareFunction, no body

(defun extract-strategy-static-properties (properties)
  (filter-plist properties #'strategy-static-property-p))

(defun all-strategy-static-properties ()
  "[Cyc] Return a list of all the static strategy properties.
   @note destructible"
  (copy-list *strategy-static-properties*))

;; (defun strategy-static-properties-removal-backtracking-productivity-limit (properties) ...) -- active declareFunction, no body
;; (defun strategy-static-properties-proof-spec (properties) ...) -- active declareFunction, no body

(defun strategy-dynamic-property-p (object)
  (member-eq? object *strategy-dynamic-properties*))

;; (defun strategy-dynamic-properties-p (object) ...) -- active declareFunction, no body

(defun extract-strategy-dynamic-properties (properties)
  (filter-plist properties #'strategy-dynamic-property-p))

(defun all-strategy-dynamic-properties ()
  "[Cyc] Return a list of all the dynamic strategy properties.
   @note destructible"
  (copy-list *strategy-dynamic-properties*))

(defun strategy-dynamic-properties-productivity-limit (properties)
  (getf properties :productivity-limit *default-productivity-limit*))

;; ====== Problem store property predicates ======

(defun problem-store-property-p (object)
  ;; Likely checks both static and dynamic problem-store properties -- evidence: pattern
  ;; matches query-static-property-p / query-dynamic-property-p which combine sub-predicates.
  (missing-larkc 36505))

;; (defun problem-store-properties-p (object) ...) -- active declareFunction, no body
;; (defun all-problem-store-properties () ...) -- active declareFunction, no body
;; (defun extract-problem-store-properties (properties) ...) -- active declareFunction, no body

(defun problem-store-static-property-p (object)
  (member-eq? object *problem-store-static-properties*))

;; (defun problem-store-static-properties-p (object) ...) -- active declareFunction, no body
;; (defun extract-problem-store-static-properties (properties) ...) -- active declareFunction, no body

(defun all-problem-store-static-properties ()
  "[Cyc] Return a list of all the static problem-store properties.
   @note destructible"
  (copy-list *problem-store-static-properties*))

(defun problem-store-dynamic-property-p (object)
  (member-eq? object *problem-store-dynamic-properties*))

;; (defun problem-store-dynamic-properties-p (object) ...) -- active declareFunction, no body

(defun all-problem-store-dynamic-properties ()
  "[Cyc] Return a list of all the static problem-store properties.
   @note destructible"
  (copy-list *problem-store-dynamic-properties*))

;; ====== Inference meta properties ======

;; (defun inference-meta-property-p (object) ...) -- active declareFunction, no body
;; (defun all-inference-meta-properties () ...) -- active declareFunction, no body
;; (defun extract-inference-meta-properties (properties) ...) -- active declareFunction, no body

;; ====== Inference status predicates ======

;; (defun query-halt-reason-p (object) ...) -- active declareFunction, no body
;; (defun exhausted-query-halt-reason-p (object) ...) -- active declareFunction, no body
;; (defun inference-status-p (object) ...) -- active declareFunction, no body

(defun continuable-inference-status-p (object)
  (member-eq? object *continuable-inference-statuses*))

;; (defun avoided-inference-reason-p (object) ...) -- active declareFunction, no body
;; (defun inference-suspend-status-p (object) ...) -- active declareFunction, no body

(defun inference-suspend-status-applicable? (status)
  "[Cyc] @return booleanp ; whether STATUS makes sense to have a suspend status."
  (declare (type (satisfies inference-status-p) status))
  (or (eq status :suspended)
      (eq status :tautology)))

;; (defun continuable-inference-suspend-status-p (object) ...) -- active declareFunction, no body
;; (defun exhausted-inference-suspend-status-p (object) ...) -- active declareFunction, no body
;; (defun inference-error-suspend-status-p (object) ...) -- active declareFunction, no body

(defun new-inference-error-suspend-status (message)
  (declare (type string message))
  (list :error message))

;; (defun inference-error-suspend-status-message (object) ...) -- active declareFunction, no body
;; (defun inference-justification-status-p (object) ...) -- active declareFunction, no body
;; (defun new-inference-justification-status (object) ...) -- active declareFunction, no body
;; (defun inference-justification-status-message (object) ...) -- active declareFunction, no body

;; ====== Tactical/problem status predicates ======

;; (defun tactical-status-p (object) ...) -- active declareFunction, no body
;; (defun provability-status-p (object) ...) -- active declareFunction, no body
;; (defun tactical-status-weaker? (status1 status2) ...) -- active declareFunction, no body
;; (defun tactical-status-stronger? (status1 status2) ...) -- active declareFunction, no body
;; (defun problem-status-p (object) ...) -- active declareFunction, no body
;; (defun problem-status-from-tactical-status-and-provability-status (tactical-status provability-status) ...) -- active declareFunction, no body

(defun tactical-status-from-problem-status (status)
  (dolist (triple *problem-status-table*)
    (when (eq status (first triple))
      (return-from tactical-status-from-problem-status (second triple))))
  nil)

(defun provability-status-from-problem-status (status)
  (dolist (triple *problem-status-table*)
    (when (eq status (first triple))
      (return-from provability-status-from-problem-status (third triple))))
  nil)

(defun good-problem-status-p (status)
  "[Cyc] statuses which indicate a goal descendant"
  (eq :good (provability-status-from-problem-status status)))

(defun no-good-problem-status-p (status)
  (eq :no-good (provability-status-from-problem-status status)))

;; (defun neutral-problem-status-p (status) ...) -- active declareFunction, no body

(defun unexamined-problem-status-p (status)
  (eq :unexamined (tactical-status-from-problem-status status)))

(defun examined-problem-status-p (status)
  (eq :examined (tactical-status-from-problem-status status)))

(defun possible-problem-status-p (status)
  (eq :possible (tactical-status-from-problem-status status)))

(defun pending-problem-status-p (status)
  (eq :pending (tactical-status-from-problem-status status)))

(defun finished-problem-status-p (status)
  (eq :finished (tactical-status-from-problem-status status)))

;; ====== Problem store property accessors ======

(defun problem-store-properties-add-restriction-layer-of-indirection? (properties)
  (getf properties :add-restriction-layer-of-indirection?
        *add-restriction-layer-of-indirection-by-default?*))

(defun problem-store-properties-negation-by-failure? (properties)
  (getf properties :negation-by-failure?
        *negation-by-failure-by-default?*))

(defun problem-store-properties-completeness-minimization-allowed? (properties)
  (getf properties :completeness-minimization-allowed?
        *complete-extent-minimization*))

(defun problem-store-properties-evaluate-subl-allowed? (properties)
  (getf properties :evaluate-subl-allowed?
        *evaluate-subl-allowed-default?*))

(defun problem-store-properties-rewrite-allowed? (properties)
  (getf properties :rewrite-allowed?
        *rewrite-allowed-default?*))

(defun problem-store-properties-abduction-allowed? (properties)
  (getf properties :abduction-allowed?
        *abduction-allowed-default?*))

(defun problem-store-properties-new-terms-allowed? (properties)
  (getf properties :new-terms-allowed?
        *new-terms-allowed-default?*))

(defun problem-store-properties-compute-answer-justifications? (properties)
  (getf properties :compute-answer-justifications?
        *compute-answer-justifications-default?*))

;; ====== Inference mode predicates ======

;; (defun all-inference-modes () ...) -- active declareFunction, no body
;; (defun inference-mode-p (object) ...) -- active declareFunction, no body

;; ====== Problem link, problem store naming ======

;; (defun problem-link-type-p (object) ...) -- active declareFunction, no body
;; (defun problem-store-name-p (object) ...) -- active declareFunction, no body

(defun problem-store-properties-name (properties)
  (getf properties :problem-store-name *default-problem-store-name*))

;; (defun problem-store-equality-reasoning-method-p (object) ...) -- active declareFunction, no body

(defun problem-store-properties-equality-reasoning-method (properties)
  (getf properties :equality-reasoning-method *default-equality-reasoning-method*))

;; (defun problem-store-equality-reasoning-domain-p (object) ...) -- active declareFunction, no body

(defun problem-store-properties-equality-reasoning-domain (properties)
  (getf properties :equality-reasoning-domain *default-equality-reasoning-domain*))

;; (defun intermediate-step-validation-level-p (object) ...) -- active declareFunction, no body

(defun problem-store-properties-intermediate-step-validation-level (properties)
  (getf properties :intermediate-step-validation-level
        *default-intermediate-step-validation-level*))

;; (defun max-problem-count-p (object) ...) -- active declareFunction, no body

(defun problem-store-properties-max-problem-count (properties)
  (getf properties :max-problem-count *default-max-problem-count*))

(defun removal-allowed-by-properties? (problem-store-properties)
  (getf problem-store-properties :removal-allowed?
        *removal-allowed-by-default?*))

(defun transformation-allowed-by-properties? (problem-store-properties)
  (getf problem-store-properties :transformation-allowed?
        *transformation-allowed-by-default?*))

;; (defun inference-direction-p (object) ...) -- active declareFunction, no body

(defun problem-store-properties-direction (properties)
  (getf properties :direction *default-problem-store-inference-direction*))

;; ====== Tactic type from HL module ======

;; (defun tactic-status-p (object) ...) -- active declareFunction, no body
;; (defun tactic-type-p (object) ...) -- active declareFunction, no body

(defun tactic-type-from-hl-module (hl-module)
  "[Cyc] @return tactic-type-p"
  (cond
    ((removal-module-p hl-module) :removal)
    ((transformation-module-p hl-module) :transformation)
    ((structural-module-p hl-module) :structural)
    ((meta-structural-module-p hl-module) :structural)
    ((conjunctive-removal-module-p hl-module) :removal-conjunctive)
    ((rewrite-module-p hl-module) :rewrite)
    ((meta-removal-module-p hl-module) :meta-removal)
    ((meta-transformation-module-p hl-module) :transformation)
    (t (error "HL-Module of unknown type: ~s" hl-module))))

;; ====== Completeness ======

;; (defun completeness-string (completeness) ...) -- active declareFunction, no body

(defun completeness-p (object)
  (member-eq? object *ordered-completenesses*))

;; (defun impossible-completeness-p (object) ...) -- active declareFunction, no body

(defun completeness-< (completeness1 completeness2)
  "[Cyc] @return boolean; t iff COMPLETENESS1 is _less_ complete than COMPLETENESS2."
  (declare (type (satisfies completeness-p) completeness1)
           (type (satisfies completeness-p) completeness2))
  (position-< completeness1 completeness2 *ordered-completenesses*))

(defun completeness-> (completeness1 completeness2)
  "[Cyc] @return boolean; t iff COMPLETENESS1 is _more_ complete than COMPLETENESS2."
  (completeness-< completeness2 completeness1))

;; (defun min-completeness (completenesses) ...) -- active declareFunction, no body
;; (defun min2-completeness (completeness1 completeness2) ...) -- active declareFunction, no body
;; (defun max-completeness (completenesses) ...) -- active declareFunction, no body
;; (defun max2-completeness (completeness1 completeness2) ...) -- active declareFunction, no body

;; ====== Productivity ======

(defun productivity-p (object)
  (or (positive-infinity-p object)
      (non-negative-integer-p object)))

(defun infinite-productivity-p (object)
  (positive-infinity-p object))

(defun productivity-for-number-of-children (number-of-children)
  "[Cyc] Converts an expected number of children to a tactic-productivity."
  (if (integerp number-of-children)
      (* 100 number-of-children)
      (let ((productivity (alist-lookup-without-values *productivity-to-number-table*
                                                       number-of-children)))
        (unless productivity
          (setf productivity (truncate (* 100 number-of-children))))
        productivity)))

(defun number-of-children-for-productivity (productivity)
  "[Cyc] Converts a productivity to an expected number of children."
  (truncate productivity 100))

(defun cost-for-productivity (productivity)
  "[Cyc] Converts a productivity to cost, which is like an expected number of children, but it can be fractional."
  (/ productivity 100))

(defun removal-cost-cutoff-for-productivity (productivity)
  (declare (type (satisfies productivity-p) productivity))
  (if (positive-infinity-p productivity)
      nil
      (cost-for-productivity productivity)))

;; (defun productivity-= (productivity1 productivity2) ...) -- active declareFunction, no body

(defun productivity-< (productivity1 productivity2)
  (declare (type (satisfies productivity-p) productivity1)
           (type (satisfies productivity-p) productivity2))
  (potentially-infinite-integer-< productivity1 productivity2))

(defun productivity-<= (productivity1 productivity2)
  (potentially-infinite-integer-<= productivity1 productivity2))

(defun productivity-> (productivity1 productivity2)
  (potentially-infinite-integer-> productivity1 productivity2))

;; (defun productivity->= (productivity1 productivity2) ...) -- active declareFunction, no body
;; (defun productivity-+ (productivity1 productivity2) ...) -- active declareFunction, no body

(defun productivity-max (productivity1 productivity2)
  (if (productivity-< productivity1 productivity2)
      productivity2
      productivity1))

;; (defun productivity-sum (productivities) ...) -- active declareFunction, no body

(defun productivity-times-number (productivity number)
  (potentially-infinite-integer-times-number-rounded productivity number))

(defun productivity-divide-number (productivity number)
  (potentially-infinite-integer-divided-by-number-rounded productivity number))

(defun decrement-productivity-for-number-of-children (productivity &optional (number 1))
  (productivity-for-number-of-children
   (- (number-of-children-for-productivity productivity) number)))

;; ====== Proof statuses ======

;; (defun proof-status-p (object) ...) -- active declareFunction, no body
;; (defun proof-reject-reason-p (object) ...) -- active declareFunction, no body

;; ====== Destructibility ======

;; (defun destructibility-status-string (status) ...) -- active declareFunction, no body
;; (defun destructibility-status-hint (status) ...) -- active declareFunction, no body
;; (defun destructibility-status-p (object) ...) -- active declareFunction, no body
;; (defun destructibility-status-destructible? (object) ...) -- active declareFunction, no body

;; ====== Balancing tactician ======

(defun balancing-tactician-enabled? ()
  (or *wallenda?* *balancing-tactician?*))

;; ====== Strategy type properties ======

;; (defun strategy-type-property-p (object) ...) -- active declareFunction, no body

(defun strategy-default-method-handler (method)
  (declare (type (satisfies strategy-type-property-p) method))
  (let ((handler (alist-lookup *strategy-type-properties* method)))
    (if (eq :must-override handler)
        (error "Strategy must implement method ~s" method)
        handler)))

;; ====== Return types ======

;; (defun inference-simple-return-type-p (object) ...) -- active declareFunction, no body
;; (defun inference-properties-has-simple-return-type? (properties) ...) -- active declareFunction, no body

(defun inference-template-return-type-p (object)
  (and (consp object)
       (eq :template (first object))))

;; (defun inference-format-return-type-p (object) ...) -- active declareFunction, no body
;; (defun inference-return-type-p (object) ...) -- active declareFunction, no body

(defun inference-properties-return-type (properties)
  (getf properties :return *inference-default-return-type*))

;; ====== Answer language ======

;; (defun inference-answer-language-p (object) ...) -- active declareFunction, no body

(defun inference-properties-answer-language (properties)
  "[Cyc] @return inference-answer-language-p"
  (getf properties :answer-language *inference-default-answer-language*))

;; ====== Result uniqueness ======

;; (defun result-uniqueness-criterion-p (object) ...) -- active declareFunction, no body

(defun inference-properties-uniqueness-criterion (properties)
  (getf properties :result-uniqueness *default-result-uniqueness-criterion*))

;; ====== Disjunction free EL vars ======

;; (defun inference-disjunction-free-el-vars-policy-p (object) ...) -- active declareFunction, no body

(defun inference-properties-disjunction-free-el-vars-policy (properties)
  (getf properties :disjunction-free-el-vars-policy
        *default-inference-disjunction-free-el-vars-policy*))

;; ====== Transitive closure mode ======

;; (defun inference-transitive-closure-mode-p (object) ...) -- active declareFunction, no body

(defun inference-properties-transitive-closure-mode (properties)
  (getf properties :transitive-closure-mode *inference-transitive-closure-mode-default*))

;; ====== Working set, events, halt conditions ======

(defun inference-properties-maintain-term-working-set? (properties)
  (getf properties :maintain-term-working-set? *maintain-term-working-set-default?*))

(defun inference-properties-events (properties)
  (getf properties :events *inference-events-default*))

;; (defun inference-event-type-p (object) ...) -- active declareFunction, no body

(defun inference-properties-halt-conditions (properties)
  (getf properties :halt-conditions *inference-halt-conditions-default*))

(defun inference-halt-condition-p (object)
  (member-eq? object *inference-halt-conditions*))

;; ====== Accumulators ======

;; (defun inference-accumulator-type-p (object) ...) -- active declareFunction, no body
;; (defun initialize-inference-accumulator (object) ...) -- active declareFunction, no body

;; ====== Result caching and browsability ======

(defun inference-properties-forget-extra-results? (properties)
  (getf properties :forget-extra-results? *inference-default-forget-extra-results?*))

(defun inference-properties-cache-inference-results? (properties)
  (getf properties :cache-inference-results? *inference-default-cache-inference-results?*))

(defun inference-properties-browsable? (properties)
  (or (getf properties :browsable? *inference-default-browsable?*)
      (inference-properties-continuable? properties)))

(defun inference-properties-continuable? (properties)
  (getf properties :continuable? *inference-default-continuable?*))

(defun inference-properties-block? (properties)
  (getf properties :block? nil))

;; ====== Query property lookup with defaults ======

(defun inference-query-property-lookup (query-properties property)
  (let ((value (getf query-properties property :unspecified)))
    (if (eq :unspecified value)
        (inference-engine-default-for-property property)
        value)))

(defun inference-engine-default-for-property (query-property)
  (declare (type (satisfies query-property-p) query-property))
  (let ((value nil)
        (specified nil))
    (case query-property
      (:disjunction-free-el-vars-policy
       (setf value *default-inference-disjunction-free-el-vars-policy*)
       (setf specified t))
      (:result-uniqueness
       (setf value *default-result-uniqueness-criterion*)
       (setf specified t))
      (:problem-store
       (setf value nil)
       (setf specified nil))
      (:conditional-sentence?
       (setf value nil)
       (setf specified t))
      (:non-explanatory-sentence
       (setf value nil)
       (setf specified t))
      (:allow-hl-predicate-transformation?
       (setf value *inference-allows-hl-predicate-transformation-by-default?*)
       (setf specified t))
      (:allow-unbound-predicate-transformation?
       (setf value *inference-allows-unbound-predicate-transformation-by-default?*)
       (setf specified t))
      (:allow-evaluatable-predicate-transformation?
       (setf value *inference-allows-evaluatable-predicate-transformation-by-default?*)
       (setf specified t))
      (:allow-indeterminate-results?
       (setf value *inference-allows-indeterminate-results-by-default?*)
       (setf specified t))
      (:allowed-rules
       (setf value *default-allowed-rules*)
       (setf specified t))
      (:allowed-modules
       (setf value *default-allowed-modules*)
       (setf specified t))
      (:forbidden-rules
       (setf value *default-forbidden-rules*)
       (setf specified t))
      (:allow-abnormality-checking?
       (setf value *inference-allows-abnormality-checking-by-default?*)
       (setf specified t))
      (:transitive-closure-mode
       (setf value *inference-transitive-closure-mode-default*)
       (setf specified t))
      (:max-number
       (setf value *default-max-number*)
       (setf specified t))
      (:max-time
       (setf value *default-max-time*)
       (setf specified t))
      (:max-step
       (setf value *default-max-step*)
       (setf specified t))
      (:forward-max-time
       (setf value *default-forward-max-time*)
       (setf specified t))
      (:max-proof-depth
       (setf value *default-max-proof-depth*)
       (setf specified t))
      (:max-transformation-depth
       (setf value *default-max-transformation-depth*)
       (setf specified t))
      (:probably-approximately-done
       (setf value *default-probably-approximately-done*)
       (setf specified t))
      (:return
       (setf value *inference-default-return-type*)
       (setf specified t))
      (:metrics
       (setf value *default-inference-metrics-template*)
       (setf specified t))
      (:answer-language
       (setf value *inference-default-answer-language*)
       (setf specified t))
      (:cache-inference-results?
       (setf value *inference-default-cache-inference-results?*)
       (setf specified t))
      (:forget-extra-results?
       (setf value *inference-default-forget-extra-results?*)
       (setf specified t))
      (:browsable?
       (setf value *inference-default-browsable?*)
       (setf specified t))
      (:continuable?
       (setf value *inference-default-continuable?*)
       (setf specified t))
      (:block?
       (setf value nil)
       (setf specified t))
      (:equality-reasoning-method
       (setf value *default-equality-reasoning-method*)
       (setf specified t))
      (:equality-reasoning-domain
       (setf value *default-equality-reasoning-domain*)
       (setf specified t))
      (:intermediate-step-validation-level
       (setf value *default-intermediate-step-validation-level*)
       (setf specified t))
      (:max-problem-count
       (setf value *default-max-problem-count*)
       (setf specified t))
      (:removal-allowed?
       (setf value *removal-allowed-by-default?*)
       (setf specified t))
      (:transformation-allowed?
       (setf value *transformation-allowed-by-default?*)
       (setf specified t))
      (:add-restriction-layer-of-indirection?
       (setf value *add-restriction-layer-of-indirection-by-default?*)
       (setf specified t))
      (:negation-by-failure?
       (setf value *negation-by-failure-by-default?*)
       (setf specified t))
      (:completeness-minimization-allowed?
       (setf value *complete-extent-minimization*)
       (setf specified t))
      (:direction
       (setf value *default-problem-store-inference-direction*)
       (setf specified t))
      (:evaluate-subl-allowed?
       (setf value *evaluate-subl-allowed-default?*)
       (setf specified t))
      (:rewrite-allowed?
       (setf value *rewrite-allowed-default?*)
       (setf specified t))
      (:abduction-allowed?
       (setf value *abduction-allowed-default?*)
       (setf specified t))
      (:new-terms-allowed?
       (setf value *new-terms-allowed-default?*)
       (setf specified t))
      (:inference-mode
       (setf value *default-inference-mode*)
       (setf specified t))
      (:maintain-term-working-set?
       (setf value *maintain-term-working-set-default?*)
       (setf specified t))
      (:events
       (setf value *inference-events-default*)
       (setf specified t))
      (:halt-conditions
       (setf value *inference-halt-conditions-default*)
       (setf specified t))
      (:problem-store-name
       (setf value *default-problem-store-name*)
       (setf specified t))
      (:productivity-limit
       (setf value *default-productivity-limit*)
       (setf specified t))
      (:removal-backtracking-productivity-limit
       (setf value *default-removal-backtracking-productivity-limit*)
       (setf specified t))
      (:proof-spec
       (setf value *default-proof-spec*)
       (setf specified t))
      (otherwise
       (setf value :unknown)
       (setf specified nil)))
    (values value specified)))

;; (defun query-property-is-default? (query-property value) ...) -- active declareFunction, no body
;; (defun inference-input-non-default-query-properties (properties) ...) -- active declareFunction, no body
;; (defun all-default-query-properties () ...) -- active declareFunction, no body
;; (defun explicify-default-query-properties (properties) ...) -- active declareFunction, no body

;;; ======================================================================
;;; Setup
;;; ======================================================================

(toplevel (register-external-symbol 'query-property-p))
(toplevel (register-cyc-api-function 'all-query-properties nil
                                      "Return a list of all the query properties.
   @note destructible"
                                      nil '((list keywordp))))
(toplevel (register-external-symbol 'problem-store-property-p))
