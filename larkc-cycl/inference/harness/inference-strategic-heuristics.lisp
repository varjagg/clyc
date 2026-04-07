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


(deflexical *strategic-heuristic-index*
  (if (and (boundp '*strategic-heuristic-index*)
           (hash-table-p *strategic-heuristic-index*))
      *strategic-heuristic-index*
      (make-hash-table :test #'eq)))

(defun strategic-heuristic-index ()
  *strategic-heuristic-index*)

;; Reconstructed from Internal Constants:
;; $list3 = ((HEURISTIC FUNCTION SCALING-FACTOR &KEY TACTIC DONE) &BODY BODY) -- arglist
;; $sym8$TACTIC_TYPE = gensym "TACTIC-TYPE"
;; $sym9$DO_DICTIONARY_KEYS -- iterates over dictionary keys
;; $list10 = (STRATEGIC-HEURISTIC-INDEX) -- the dictionary to iterate
;; $sym11$CLET -- binds variables
;; $sym12$STRATEGIC_HEURISTIC_FUNCTION -- accessor for function
;; $sym13$STRATEGIC_HEURISTIC_SCALING_FACTOR -- accessor for scaling factor
;; $sym14$STRATEGIC_HEURISTIC_TACTIC_TYPE -- accessor for tactic type
;; $sym15$PWHEN -- conditional execution
;; $sym16$DO_STRATEGIC_HEURISTICS_TACTIC_MATCH_P -- tactic filtering
;; Helpers: strategic-heuristic-index, do-strategic-heuristics-tactic-match-p
(defmacro do-strategic-heuristics ((heuristic function scaling-factor &key tactic done) &body body)
  (with-temp-vars (tactic-type)
    `(block do-strategic-heuristics
       (maphash (lambda (,heuristic ignore-val)
                  (declare (ignore ignore-val))
                  ,@(when done `((when ,done (return-from do-strategic-heuristics))))
                  (let ((,function (strategic-heuristic-function ,heuristic))
                        (,scaling-factor (strategic-heuristic-scaling-factor ,heuristic))
                        (,tactic-type (strategic-heuristic-tactic-type ,heuristic)))
                    (declare (ignorable ,tactic-type))
                    (when (do-strategic-heuristics-tactic-match-p ,tactic ,tactic-type)
                      ,@body)))
                (strategic-heuristic-index)))))

(defun do-strategic-heuristics-tactic-match-p (tactic tactic-type)
  (or (null tactic)
      (tactic-matches-type-spec? tactic tactic-type)))

(defun new-strategic-heuristic-data (function scaling-factor pretty-name comment tactic-type)
  (list function scaling-factor pretty-name comment tactic-type))

(defun declare-strategic-heuristic (heuristic plist)
  "[Cyc] @param HEURISTIC keywordp; a token for the heuristic being declared.
@param FUNCTION symbolp; a function with the arglist (strategy tactic) which returns a happiness-p.
@param SCALING-FACTOR potentially-infinite-integer-p; how important this heuristic is
  relative to the other heuristics.  A relative weight.
@param TACTIC-TYPE tactic-type-spec-p; the type of tactics HEURISTIC applies to.
The happiness returned by FUNCTION should be between -100 and 100.  (although some extant heuristics disobey this.)
-100 = strongly disfavor (estimated 0% chance of success)
   0 = agnostic          (estimated A% chance of success, i.e. random chance)
 100 = strongly favor    (estimated 100% chance of success)
'A%' in the above guidelines is the probability that executing an arbitrary tactic will lead to success.
The happiness should be proportional to the estimated likelihood, according to this heuristic,
that executing TACTIC will lead toward success (i.e. proofs).  For example, if A were 10%, and a tactic that
is guessed to be 20% likely to succeed yields a happiness of 25, then a tactic that is guessed to be 30% likely
to succeed should have a happiness of 50.  It's okay for it to scale off more steeply at 100% because success is relatively rare."
  (declare (type keyword heuristic))
  (destructuring-bind (&key function scaling-factor pretty-name comment tactic-type
                       &allow-other-keys) plist
    (let ((data (new-strategic-heuristic-data function scaling-factor pretty-name comment tactic-type)))
      (setf (gethash heuristic *strategic-heuristic-index*) data)))
  heuristic)

;; (defun undeclare-strategic-heuristic (heuristic) ...) -- active declareFunction, no body

(defun strategic-heuristic-function (heuristic)
  "[Cyc] @return nil or symbolp"
  (let ((data (gethash heuristic *strategic-heuristic-index*)))
    (when data
      (first data))))

(defvar *overriding-strategic-heuristic-scaling-factors* nil
  "[Cyc] property-list-p; a plist of overriding scaling factors for heuristics.
If any of these are specified, they override the declared scaling factors.
The indicators are the heuristics, e.g. :occams-razor, and the values are integers.")

(defun strategic-heuristic-scaling-factor (heuristic)
  "[Cyc] @return nil or potentially-infinite-integer-p"
  (let ((overriding-scaling-factor (getf *overriding-strategic-heuristic-scaling-factors* heuristic nil)))
    (if overriding-scaling-factor
        overriding-scaling-factor
        (let ((data (gethash heuristic *strategic-heuristic-index*)))
          (when data
            (second data))))))

;; (defun strategic-heuristic-name (heuristic) ...) -- active declareFunction, no body
;; (defun strategic-heuristic-pretty-name (heuristic) ...) -- active declareFunction, no body
;; (defun strategic-heuristic-comment (heuristic) ...) -- active declareFunction, no body

(defun strategic-heuristic-tactic-type (heuristic)
  "[Cyc] @return nil or tactic-type-spec-p; the type of tactic that HEURISTIC applies to"
  (let ((data (gethash heuristic *strategic-heuristic-index*)))
    (when data
      (fifth data))))

(defun strategic-heuristic-shallow-and-cheap (strategy content-tactic)
  (let* ((productivity (productivity-for-shallow-and-cheap-heuristic content-tactic strategy))
         (uselessness (tactic-strategic-uselessness-based-on-proof-depth content-tactic strategy))
         (unhappiness (if (and (eql 0 productivity)
                               (positive-infinity-p uselessness))
                          (positive-infinity)
                          (productivity-times-number productivity uselessness)))
         (happiness (productivity-times-number unhappiness -1)))
    happiness))

(defun productivity-for-shallow-and-cheap-heuristic (content-tactic strategy)
  (when (transformation-strategy-p strategy)
    ;; Likely retrieves the corresponding removal strategy from the transformation strategy
    ;; Evidence: transforms strategy before using it for productivity lookup
    (setf strategy (missing-larkc 33101)))
  (tactic-strategic-productivity content-tactic strategy))

(defun tactic-strategic-uselessness-based-on-proof-depth (tactic strategy)
  (let* ((inference (strategy-inference strategy))
         (problem (tactic-problem tactic))
         (min-proof-depth (problem-min-proof-depth problem inference)))
    (if (eq :undetermined min-proof-depth)
        (positive-infinity)
        (tactic-strategic-uselessness-based-on-proof-depth-math-memoized min-proof-depth))))

(defun-cached tactic-strategic-uselessness-based-on-proof-depth-math-memoized (min-proof-depth)
    (:test eql)
  (max 1 (round (log (1+ min-proof-depth) 2))))

(defun strategic-heuristic-completeness (strategy content-tactic)
  (if (and (content-tactic-p content-tactic)
           (eq :complete (tactic-strategic-completeness content-tactic strategy)))
      1
      0))

(deflexical *strategic-heuristic-occams-razor-table*
  '((0 . 0) (1 . -10) (2 . -20) (3 . -30) (4 . -40) (5 . -50)
    (6 . -60) (7 . -70) (8 . -75) (9 . -80) (10 . -85) (15 . -90)
    (20 . -95) (30 . -99) (:positive-infinity . -100)))

(deflexical *strategic-heuristic-occams-razor-table-default* -100)

(defun strategic-heuristic-occams-razor (strategy content-tactic)
  (let* ((inference (strategy-inference strategy))
         (happiness 0))
    (when (inference-permits-transformation? inference)
      (let ((*transformation-depth-computation* :intuitive))
        (let* ((problem (tactic-problem content-tactic))
               (min-depth (problem-min-transformation-depth problem inference)))
          (cond ((or (eq :undetermined min-depth)
                     (null min-depth))
                 (when (transformation-tactic-p content-tactic)
                   (setf happiness *strategic-heuristic-occams-razor-table-default*)))
                (t
                 (when (transformation-tactic-p content-tactic)
                   (setf min-depth (+ min-depth 1)))
                 (setf happiness (numeric-table-lookup min-depth *strategic-heuristic-occams-razor-table*)))))))
    happiness))

(defun strategic-heuristic-magic-wand (strategy generalized-removal-tactic)
  (if (and (generalized-removal-tactic-p generalized-removal-tactic)
           (eq :incomplete (tactic-strategic-completeness generalized-removal-tactic strategy))
           ;; Likely checks if the tactic has zero expected productivity
           (missing-larkc 36507))
      -100
      0))

(defvar *backtracking-considered-harmful?* t
  "[Cyc] Temporary control parameter")

(deflexical *strategic-heuristic-backtracking-table*
  '((0 . 0) (1 . -20) (2 . -40) (3 . -60) (4 . -80)))

(deflexical *strategic-heuristic-backtracking-table-default* -100)

;; (defun strategic-heuristic-backtracking (strategy content-tactic) ...) -- active declareFunction, no body
;; (defun executed-connected-conjunction-tactics-that-matter-count (problem strategy) ...) -- active declareFunction, no body

(defvar *early-removal-productivity-threshold* 400)

(defun strategic-heuristic-backchain-required (strategy transformation-tactic)
  "[Cyc] @return happiness-p; return 100 iff TRANSFORMATION-TACTIC transforms a
single literal problem with a #$backchainRequired predicate.
Otherwise, return 0."
  (let ((inference (strategy-inference strategy)))
    (when (inference-permits-transformation? inference)
      (let ((problem (tactic-problem transformation-tactic)))
        (when (single-literal-problem-p problem)
          (let ((asent (single-literal-problem-atomic-sentence problem))
                (mt (single-literal-problem-mt problem)))
            (when (inference-backchain-required-asent? asent mt)
              (return-from strategic-heuristic-backchain-required 100)))))))
  0)

(defparameter *heuristic-rule-a-priori-utility-problem-recursion-stack* nil
  "[Cyc] A set of problems that are currently being evaluated for relevance,
to avoid infinite recursion.")

(defun strategic-heuristic-rule-a-priori-utility (strategy content-tactic)
  "[Cyc] @return happiness-p; between -100 and 100.
positive if CONTENT-TACTIC's problem has any supported* problem with a dependent transformation link
   which used a highlyRelevantAssertion.
negative if CONTENT-TACTIC's problem has any supported* problem with a dependent transformation link
   which used an irrelevantAssertion.
If there is a mix, it will take a percentage, with -100/+100 being 100% irrelevant/relevant.
 0 indicates agnostic.
A special case is that zero dependent* transformation links yield a value of 100 instead
of 0, otherwise the Tactician will prefer highly relevant transformations over removals."
  (let ((happiness 100)
        (inference (strategy-inference strategy)))
    (when (inference-permits-transformation? inference)
      (let ((problem (tactic-problem content-tactic)))
        (when (or (not (eql 0 (problem-min-transformation-depth problem inference)))
                  (transformation-tactic-p content-tactic))
          (let ((*heuristic-rule-a-priori-utility-problem-recursion-stack*
                  (new-set #'eq)))
            (multiple-value-bind (relevance-count total-count)
                (count-a-priori-utility-recursive problem inference)
              (when (not (eq :loop total-count))
                (multiple-value-bind (relevance-count-delta total-count-delta)
                    (determine-tactic-heuristic-relevance-delta content-tactic)
                  (setf relevance-count (+ relevance-count relevance-count-delta))
                  (setf total-count (+ total-count total-count-delta)))
                (when (not (zerop total-count))
                  (setf happiness (truncate (* 100 relevance-count) total-count)))))))))
    happiness))

(defun push-problem-onto-heuristic-rule-a-priori-utility-stack (problem)
  (set-add problem *heuristic-rule-a-priori-utility-problem-recursion-stack*))

(defun problem-on-heuristic-rule-a-priori-utility-stack? (problem)
  (set-member? problem *heuristic-rule-a-priori-utility-problem-recursion-stack*))

(defun count-a-priori-utility-recursive-internal (problem inference)
  "[Cyc] @return 0; the number of PROBLEM's dependent* highly relevant assertions
minus the number of PROBLEM's dependent* irrelevant assertions (wrt INFERENCE).
@return 1; the total number of PROBLEM's dependent* assertions (for now, only rules).
This is equal to the total number of PROBLEM's dependent* transformation links."
  (let ((best-relevance-count 0)
        (best-total-count 0)
        (best-ratio most-negative-fixnum)
        (found-a-loop? nil)
        (found-a-non-loop? nil))
    (when (problem-on-heuristic-rule-a-priori-utility-stack? problem)
      (return-from count-a-priori-utility-recursive-internal (values :loop :loop)))
    (push-problem-onto-heuristic-rule-a-priori-utility-stack problem)
    (let* ((set-contents-var (problem-dependent-links problem))
           (basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((dependent-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state dependent-link)
                   (let ((supported-problem (problem-link-supported-problem dependent-link))
                         (relevance-count 0)
                         (total-count 0)
                         (loop? nil))
                     (when (transformation-link-p dependent-link)
                       (setf total-count (+ total-count 1))
                       (when (problem-relevant-to-inference? problem inference)
                         (cond
                           ;; Likely checks if the transformation link's rule is highlyRelevantAssertion
                           ((missing-larkc 36263)
                            (setf relevance-count (+ relevance-count 1)))
                           ;; Likely checks if the transformation link's rule is irrelevantAssertion
                           ((missing-larkc 36262)
                            (setf relevance-count (- relevance-count 1)))
                           ;; Likely checks if the transformation link's rule has utility
                           ((missing-larkc 36261)
                            ;; Likely returns the a priori utility value for the transformation link's rule
                            (setf relevance-count (+ relevance-count (missing-larkc 36264)))))))
                     (unless (answer-link-p dependent-link)
                       (multiple-value-bind (best-sub-relevance-count best-sub-total-count)
                           (count-a-priori-utility-recursive supported-problem inference)
                         (if (eq :loop best-sub-total-count)
                             (progn
                               (setf loop? t)
                               (setf found-a-loop? t))
                             (progn
                               (setf found-a-non-loop? t)
                               (setf relevance-count (+ relevance-count best-sub-relevance-count))
                               (setf total-count (+ total-count best-sub-total-count))))))
                     (unless loop?
                       (let ((ratio (if (zerop total-count) 0 (/ relevance-count total-count))))
                         (when (or (> ratio best-ratio)
                                   (and (= ratio best-ratio)
                                        (< total-count best-total-count)))
                           (setf best-relevance-count relevance-count)
                           (setf best-total-count total-count)
                           (setf best-ratio ratio)))))))
               (setf state (do-set-contents-update-state state))))
    (if (and found-a-loop? (not found-a-non-loop?))
        (values :loop :loop)
        (values best-relevance-count best-total-count))))

(defun-memoized count-a-priori-utility-recursive (problem inference) (:test eq)
  (count-a-priori-utility-recursive-internal problem inference))

(defun determine-tactic-heuristic-relevance-delta (tactic)
  (let ((relevance-count 0)
        (total-count 0))
    (cond
      ((not (transformation-tactic-p tactic)))
      ((transformation-tactic-relevant? tactic)
       (setf relevance-count (+ relevance-count 1))
       (setf total-count (+ total-count 1)))
      ((transformation-tactic-irrelevant? tactic)
       (setf relevance-count (- relevance-count 1))
       (setf total-count (+ total-count 1)))
      ((transformation-tactic-has-utility? tactic)
       ;; Likely returns the a priori utility happiness value for the transformation tactic
       (setf relevance-count (+ relevance-count (missing-larkc 36271)))
       (setf total-count (+ total-count 1)))
      ((transformation-tactic-lookahead-rule tactic)
       (setf total-count (+ total-count 1))))
    (values relevance-count total-count)))

;; (defun transformation-link-relevant? (link) ...) -- active declareFunction, no body
;; (defun transformation-link-irrelevant? (link) ...) -- active declareFunction, no body
;; (defun transformation-link-has-rule-utility? (link) ...) -- active declareFunction, no body
;; (defun transformation-link-rule-utility (link) ...) -- active declareFunction, no body

(defun transformation-tactic-relevant? (transformation-tactic)
  "[Cyc] @return boolean; TRANSFORMATION-TACTIC's rule has a #$highlyRelevantAssertion
meta-assertion on it, and the mt of the meta-assertion is visible from the mt of
TRANSFORMATION-TACTIC's problem. If there is no rule, be conservative and return NIL."
  (let ((rule (transformation-tactic-lookahead-rule transformation-tactic)))
    (when rule
      (let ((problem (tactic-problem transformation-tactic)))
        (rule-relevant-to-problem? rule problem)))))

(defun transformation-tactic-irrelevant? (transformation-tactic)
  "[Cyc] @return boolean; TRANSFORMATION-TACTIC's rule has an #$irrelevantAssertion
meta-assertion on it, and the mt of the meta-assertion is visible from the mt of
TRANSFORMATION-TACTIC's problem. If there is no rule, be conservative and return NIL."
  (let ((rule (transformation-tactic-lookahead-rule transformation-tactic)))
    (when rule
      (let ((problem (tactic-problem transformation-tactic)))
        (rule-irrelevant-to-problem? rule problem)))))

(defun transformation-tactic-has-utility? (transformation-tactic)
  (let ((rule (transformation-tactic-lookahead-rule transformation-tactic)))
    (when rule
      (let ((problem (tactic-problem transformation-tactic)))
        (rule-has-utility-wrt-problem? rule problem)))))

;; (defun transformation-tactic-utility (transformation-tactic) ...) -- active declareFunction, no body

(defun rule-relevant-to-problem? (rule problem)
  (let ((problem-mt (single-literal-problem-mt problem))
        (rule-mt (assertion-mt rule)))
    (cond ((inference-relevant-mt? rule-mt problem-mt) t)
          ((not (assertion-has-meta-assertions? rule)) nil)
          ;; Likely checks if the rule has a highlyRelevantAssertion meta-assertion
          ;; that is visible from the problem mt
          ((missing-larkc 3438) t)
          (t (let ((predicate (single-literal-problem-predicate problem)))
               (declare (ignorable predicate))
               ;; Likely checks if the predicate is marked as highly relevant
               (missing-larkc 3440))))))

(defun rule-irrelevant-to-problem? (rule problem)
  (let ((problem-mt (single-literal-problem-mt problem))
        (rule-mt (assertion-mt rule)))
    (cond ((inference-irrelevant-mt? rule-mt problem-mt) t)
          ((not (assertion-has-meta-assertions? rule)) nil)
          ;; Likely checks if the rule has an irrelevantAssertion meta-assertion
          ;; that is visible from the problem mt
          ((missing-larkc 3426) t)
          (t (let ((predicate (single-literal-problem-predicate problem)))
               (declare (ignorable predicate))
               ;; Likely checks if the predicate is marked as irrelevant
               (missing-larkc 3428))))))

(defun rule-has-utility-wrt-problem? (rule problem)
  (let ((problem-mt (single-literal-problem-mt problem)))
    (declare (ignorable problem-mt))
    (cond ((not (assertion-has-meta-assertions? rule)) nil)
          ;; Likely checks if the rule has a utility-valued meta-assertion
          ((missing-larkc 3442) t))))

;; (defun transformation-rule-a-priori-utility (rule) ...) -- active declareFunction, no body
;; (defun transformation-rule-a-priori-utility-happiness-internal (rule) ...) -- active declareFunction, no body
;; (defun transformation-rule-a-priori-utility-happiness (rule) ...) -- active declareFunction, no body

(defvar *highly-relevant-term-enabled?* nil
  "[Cyc] When t, the Heuristic tactician will prefer problems which
mention highlyRelevantTerms.")

(defun strategic-heuristic-relevant-term (strategy content-tactic)
  "[Cyc] @return happiness-p; between -100 and 100.  Gets +20 for each
#$highlyRelevantTerm in CONTENT-TACTIC's problem (relevance determined
from the context of the appropriate contextualized literal)
and -20 for each #$irrelevantTerm.  Maxes/mins out at -100/100."
  (declare (ignore strategy))
  (if (null *highly-relevant-term-enabled?*)
      0
      (let ((problem (tactic-problem content-tactic)))
        ;; Likely calls (problem-relevant-or-irrelevant-term-count problem)
        ;; to count the net relevant vs irrelevant terms
        (declare (ignore problem))
        (let* ((relevance-count (missing-larkc 36258))
               (heuristic (* relevance-count 20)))
          (setf heuristic (min heuristic 100))
          (setf heuristic (max heuristic -100))
          heuristic))))

(defparameter *relevant-or-irrelevant-term-count* 0
  "[Cyc] lambda")

;; (defun problem-relevant-or-irrelevant-term-count (problem) ...) -- active declareFunction, no body
;; (defun expression-relevant-or-irrelevant-term-count (expression) ...) -- active declareFunction, no body
;; (defun accumulate-relevant-or-irrelevant-term-count (object) ...) -- active declareFunction, no body

(defvar *strategic-heuristic-rule-historical-utility-enabled?* t
  "[Cyc] When non-nil, the Heuristic tactician will use rule historical utility as
one of its heuristics.")

;; (defun strategic-heuristic-rule-historical-utility-enabled? () ...) -- active declareFunction, no body
;; (defun enable-strategic-heuristic-rule-historical-utility () ...) -- active declareFunction, no body
;; (defun disable-strategic-heuristic-rule-historical-utility () ...) -- active declareFunction, no body

(defparameter *heuristic-rule-historical-utility-problem-recursion-stack* nil
  "[Cyc] A set of problems that are currently being evaluated for rule-historical-utility,
to avoid infinite recursion.")

(defun strategic-heuristic-rule-historical-utility (strategy content-tactic)
  "[Cyc] @return happiness-p; between -100 and 100.
positive if CONTENT-TACTIC's problem has any supported* problem with a dependent transformation link
   which uses a historically useful rule.
negative if CONTENT-TACTIC's problem has any supported* problem with a dependent transformation link
   which uses a historically useless rule.
If there is a mix, it will take a percentage, with -100/+100 being 100% irrelevant/relevant.
 0 indicates agnostic.
A special case is that zero dependent* transformation links yield a value of 100 instead
of 0, otherwise the Tactician will prefer relevant transformations over removals."
  (if (null *strategic-heuristic-rule-historical-utility-enabled?*)
      0
      (let ((happiness 100)
            (inference (strategy-inference strategy)))
        (when (inference-permits-transformation? inference)
          (let ((problem (tactic-problem content-tactic)))
            (when (or (problem-has-been-transformed? problem inference)
                      (transformation-tactic-p content-tactic))
              (let ((*heuristic-rule-historical-utility-problem-recursion-stack*
                      (new-set #'eq)))
                (multiple-value-bind (total-utility total-count)
                    (compute-problem-rule-historical-utility-recursive problem inference)
                  (when (not (eq :loop total-count))
                    (multiple-value-bind (delta-utility delta-count)
                        (compute-tactic-rule-historical-utility content-tactic)
                      (setf total-utility (+ total-utility delta-utility))
                      (setf total-count (+ total-count delta-count)))
                    (when (not (zerop total-count))
                      (setf happiness (truncate total-utility total-count)))))))))
        happiness)))

(defun push-problem-onto-rule-historical-utility-stack (problem)
  (set-add problem *heuristic-rule-historical-utility-problem-recursion-stack*))

(defun problem-on-rule-historical-utility-stack? (problem)
  (set-member? problem *heuristic-rule-historical-utility-problem-recursion-stack*))

(defun compute-problem-rule-historical-utility-recursive-internal (problem inference)
  "[Cyc] @return 0; the number of PROBLEM's dependent* highly relevant assertions
minus the number of PROBLEM's dependent* irrelevant assertions (wrt INFERENCE).
@return 1; the total number of PROBLEM's dependent* assertions (for now, only rules).
This is equal to the total number of PROBLEM's dependent* transformation links."
  (let ((best-utility 0)
        (best-total-count 0)
        (best-ratio most-negative-fixnum)
        (found-a-loop? nil)
        (found-a-non-loop? nil))
    (when (problem-on-rule-historical-utility-stack? problem)
      (return-from compute-problem-rule-historical-utility-recursive-internal (values :loop :loop)))
    (push-problem-onto-rule-historical-utility-stack problem)
    (let* ((set-contents-var (problem-dependent-links problem))
           (basis-object (do-set-contents-basis-object set-contents-var))
           (state (do-set-contents-initial-state basis-object set-contents-var)))
      (loop until (do-set-contents-done? basis-object state)
            do (let ((dependent-link (do-set-contents-next basis-object state)))
                 (when (do-set-contents-element-valid? state dependent-link)
                   (let ((supported-problem (problem-link-supported-problem dependent-link))
                         (utility 0)
                         (total-count 0)
                         (loop? nil))
                     (when (generalized-transformation-link-p dependent-link)
                       (setf total-count (+ total-count 1))
                       (when (problem-relevant-to-inference? problem inference)
                         (let* ((rule-assertion (generalized-transformation-link-rule-assertion dependent-link))
                                (local-utility (transformation-rule-historical-utility rule-assertion)))
                           (setf utility (+ utility local-utility)))))
                     (unless (answer-link-p dependent-link)
                       (multiple-value-bind (best-sub-utility best-sub-total-count)
                           (compute-problem-rule-historical-utility-recursive supported-problem inference)
                         (if (eq :loop best-sub-total-count)
                             (progn
                               (setf loop? t)
                               (setf found-a-loop? t))
                             (progn
                               (setf found-a-non-loop? t)
                               (setf utility (+ utility best-sub-utility))
                               (setf total-count (+ total-count best-sub-total-count))))))
                     (unless loop?
                       (let ((ratio (if (zerop total-count) 0 (/ utility total-count))))
                         (when (or (> ratio best-ratio)
                                   (and (= ratio best-ratio)
                                        (< total-count best-total-count)))
                           (setf best-utility utility)
                           (setf best-total-count total-count)
                           (setf best-ratio ratio)))))))
               (setf state (do-set-contents-update-state state))))
    (if (and found-a-loop? (not found-a-non-loop?))
        (values :loop :loop)
        (values best-utility best-total-count))))

(defun-memoized compute-problem-rule-historical-utility-recursive (problem inference)
    (:test eq)
  (compute-problem-rule-historical-utility-recursive-internal problem inference))

(defun compute-tactic-rule-historical-utility (tactic)
  (let ((delta-utility 0)
        (delta-count 0))
    (when (transformation-tactic-p tactic)
      (let ((rule (transformation-tactic-lookahead-rule tactic)))
        (when rule
          (setf delta-utility (+ delta-utility (transformation-rule-historical-utility rule)))
          (setf delta-count (+ delta-count 1)))))
    (values delta-utility delta-count)))

;; (defun inference-rule-preference-> (rule1 rule2 inference) ...) -- active declareFunction, no body
;; (defun transformation-rule-utility-> (rule1 rule2) ...) -- active declareFunction, no body
;; (defun transformation-rule-utility->-with-tiebreaker (rule1 rule2) ...) -- active declareFunction, no body
;; (defun transformation-rule-utility-internal (rule) ...) -- active declareFunction, no body
;; (defun transformation-rule-utility (rule) ...) -- active declareFunction, no body

(defparameter *strategic-heuristic-rule-historical-connectedness-enabled?* nil)

;; (defun strategic-heuristic-rule-historical-connectedness (strategy content-tactic) ...) -- active declareFunction, no body
;; (defun problem-link-paths-relevant-to-inference (problem inference) ...) -- active declareFunction, no body
;; (defun cached-problem-link-paths-relevant-to-inference-internal (problem inference) ...) -- active declareFunction, no body
;; (defun cached-problem-link-paths-relevant-to-inference (problem inference) ...) -- active declareFunction, no body
;; (defun problem-link-paths-relevant-to-inference-recursive (problem inference path) ...) -- active declareFunction, no body
;; (defun problem-rule-sets-relevant-to-inference (problem inference) ...) -- active declareFunction, no body
;; (defun tactic-lookahead-rule-sets-relevant-to-inference (tactic inference) ...) -- active declareFunction, no body
;; (defun problem-link-path-rule-set (path) ...) -- active declareFunction, no body
;; (defun strategic-heuristic-literal-count (strategy logical-tactic) ...) -- active declareFunction, no body

(defun strategic-heuristic-rule-literal-count (strategy transformation-tactic)
  (declare (ignore strategy))
  (if (not (transformation-tactic-p transformation-tactic))
      0
      (let ((rule-assertion (transformation-tactic-lookahead-rule transformation-tactic)))
        (if rule-assertion
            (let* ((literal-count (rule-literal-count rule-assertion))
                   (happiness (strategic-heuristic-happiness-due-to-literal-count literal-count)))
              happiness)
            0))))

(defun strategic-heuristic-happiness-due-to-literal-count (literal-count)
  (numeric-table-lookup literal-count *strategic-heuristic-literal-count-lookup-table*))

(deflexical *strategic-heuristic-literal-count-lookup-table*
  '((1 . 0) (2 . -15) (3 . -25) (4 . -30) (5 . -35) (6 . -40)
    (7 . -45) (8 . -50) (9 . -55) (10 . -60) (13 . -70) (17 . -80)
    (23 . -85) (30 . -90) (50 . -95) (70 . -97) (100 . -99)
    (:positive-infinity . -100)))

(defun numeric-table-lookup (n lookup-table &optional default)
  "[Cyc] Return a value associated with the numeric argument N via a table lookup.
LOOKUP-TABLE is a list of (input . output) pairs.
The symbol :positive-infinity represents infinity as the input value of the last pair.
All numeric lookup tables should end with :positive-infinity."
  (dolist (pair lookup-table default)
    (destructuring-bind (input . output) pair
      (when (potentially-infinite-number-<= n input)
        (return output)))))

(defun strategic-heuristic-skolem-count (strategy logical-tactic)
  (declare (ignore strategy))
  (let* ((problem (tactic-problem logical-tactic))
         (skolem-count (problem-skolem-count problem))
         (happiness (strategic-heuristic-happiness-due-to-skolem-count skolem-count)))
    happiness))

(defun problem-skolem-count (problem)
  (let ((query (problem-query problem)))
    (tree-count-if #'skolem-function-p query)))

(defun strategic-heuristic-happiness-due-to-skolem-count (skolem-count)
  (numeric-table-lookup skolem-count *strategic-heuristic-skolem-count-lookup-table*))

(deflexical *strategic-heuristic-skolem-count-lookup-table*
  '((0 . 0) (1 . -1) (2 . -2) (3 . -4) (4 . -8) (5 . -16)
    (6 . -32) (7 . -64) (8 . -99) (:positive-infinity . -100)))

;; (defun strategic-heuristic-happiness-table (strategy content-tactic happiness-table) ...) -- active declareFunction, no body

;;; Setup

(toplevel (declare-defglobal '*strategic-heuristic-index*))
(toplevel (register-macro-helper 'strategic-heuristic-index 'do-strategic-heuristics))
(toplevel (register-macro-helper 'do-strategic-heuristics-tactic-match-p 'do-strategic-heuristics))

(toplevel
  (declare-strategic-heuristic :shallow-and-cheap
    (list :function 'strategic-heuristic-shallow-and-cheap
          :scaling-factor 1
          :pretty-name "Shallow And Cheap"
          :comment "Prefer tactics which are shallower,
i.e. have a lower min-proof-depth, and which are cheap,
i.e. have a lower productivity.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-shallow-and-cheap))

(toplevel (note-globally-cached-function 'tactic-strategic-uselessness-based-on-proof-depth-math-memoized))

(toplevel
  (declare-strategic-heuristic :completeness
    (list :function 'strategic-heuristic-completeness
          :scaling-factor 1
          :pretty-name "Completeness"
          :comment "Prefer tactics which are complete.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-completeness))

(toplevel
  (declare-strategic-heuristic :occams-razor
    (list :function 'strategic-heuristic-occams-razor
          :scaling-factor 250
          :pretty-name "Occam's Razor"
          :comment "The simplest explanation is best.  Our measure
of simplicity is the shallowest transformation depth.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-occams-razor))

(toplevel
  (declare-strategic-heuristic :magic-wand
    (list :function 'strategic-heuristic-magic-wand
          :scaling-factor 1000
          :pretty-name "Magic Wand"
          :comment "Disprefer 'magic wand' tactics, which are
incomplete (conjunctive) removal tactics which are expected
to yield no answers, i.e. they have a productivity of 0.
Since they are incomplete, they can't even yield the benefit
of pruning, so unless the estimate of 0 is wrong, it's
a waste of time to execute them.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-magic-wand))

(toplevel
  (declare-strategic-heuristic :backtracking-considered-harmful
    (list :function 'strategic-heuristic-backtracking
          :scaling-factor 10000
          :tactic-type :connected-conjunction
          :pretty-name "Backtracking Considered Harmful"
          :comment "If we've already executed some non-trivial
connected conjunction tactics on this problem, then disprefer
executing any more connected conjunction tactics on it.
A connected conjunction tactic is deemed trivial if
it's expected to generate 4 or fewer subproblems.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-backtracking))

(toplevel
  (declare-strategic-heuristic :backchain-required
    (list :function 'strategic-heuristic-backchain-required
          :scaling-factor 10000
          :tactic-type :transformation
          :pretty-name "backchainRequired"
          :comment "Prefer transformation tactics on backchainRequired predicates.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-backchain-required))

(toplevel
  (declare-strategic-heuristic :rule-a-priori-utility
    (list :function 'strategic-heuristic-rule-a-priori-utility
          :scaling-factor 10000
          :pretty-name "highlyRelevantAssertion"
          :comment "Prefer proof paths using higher proportions of
highlyRelevantAssertions.  Assume that proof paths using no rules
are 100% relevant.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-rule-a-priori-utility))

(toplevel (note-memoized-function 'count-a-priori-utility-recursive))
(toplevel (note-memoized-function 'transformation-rule-a-priori-utility-happiness))

(toplevel
  (declare-strategic-heuristic :relevant-term
    (list :function 'strategic-heuristic-relevant-term
          :scaling-factor 10000
          :pretty-name "highlyRelevantTerm"
          :comment "Prefer working on problems that contain more
highlyRelevantTerms.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-relevant-term))
(toplevel (note-funcall-helper-function 'accumulate-relevant-or-irrelevant-term-count))

(toplevel
  (declare-strategic-heuristic :rule-historical-utility
    (list :function 'strategic-heuristic-rule-historical-utility
          :scaling-factor 20000
          :pretty-name "Historical Utility"
          :comment "Prefer proof paths using rules that have worked well in the past,
without considering the situations in which they were used, i.e.
prior probability.  Consider proof paths using no rules to be at 100%.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-rule-historical-utility))

(toplevel (note-memoized-function 'compute-problem-rule-historical-utility-recursive))
(toplevel (note-memoized-function 'transformation-rule-utility))

(toplevel
  (declare-strategic-heuristic :rule-historical-connectedness
    (list :function 'strategic-heuristic-rule-historical-connectedness
          :scaling-factor 20000
          :pretty-name "Rule Connectedness"
          :comment "Prefer proof paths using sets of rules that have a larger fraction that have pairwise worked together in the past.
Consider proof paths using fewer than 2 rules to be at 100%.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-rule-historical-connectedness))

(toplevel (note-memoized-function 'cached-problem-link-paths-relevant-to-inference))

(toplevel
  (declare-strategic-heuristic :literal-count
    (list :function 'strategic-heuristic-literal-count
          :scaling-factor 10000
          :tactic-type :logical
          :pretty-name "# of Literals"
          :comment "Prefer working on problems with a smaller number of literals.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-literal-count))

(toplevel
  (declare-strategic-heuristic :rule-literal-count
    (list :function 'strategic-heuristic-rule-literal-count
          :scaling-factor 10000
          :tactic-type :transformation
          :pretty-name "# of Rule Literals"
          :comment "Prefer using rules with a smaller number of literals.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-rule-literal-count))

(toplevel
  (declare-strategic-heuristic :skolem-count
    (list :function 'strategic-heuristic-skolem-count
          :scaling-factor 300000
          :pretty-name "# of Skolems"
          :comment "Prefer working on problems with a smaller number of skolem functions.")))
(toplevel (note-funcall-helper-function 'strategic-heuristic-skolem-count))
