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
;; $list0 = (SUSPEND-STATUS-VAR &BODY BODY) -- arglist
;; $sym1$ABORTED_P = gensym
;; $sym2$CLET, $sym3$CCATCH, $kw4$INFERENCE_ABORT_TARGET
;; $list5 = ((*WITHIN-INFERENCE-CONTROL-PROCESS?* T))
;; $sym6$PWHEN, $sym7$CSETQ
;; $list8 = (:ABORT), $list9 = ((QUERY-ABORT))
;; $kw10$NOT_ABORTED -- not observed in expansion, possibly sentinel
;; Verified against expansion in inference_run (inference_strategist.java)
(defmacro catch-inference-abort (suspend-status-var &body body)
  (with-temp-vars (aborted-p)
    `(let ((,aborted-p
             (catch :inference-abort-target
               (let ((*within-inference-control-process?* t))
                 ,@body
                 nil))))
       (when ,aborted-p
         (setf ,suspend-status-var :abort)
         (query-abort)))))

;; (defun signal-inference-control-process-abort () ...) -- active declareFunction, no body
;; (defun query-abort () ...) -- active declareFunction, no body
;; (defun query-interrupt (&optional patience) ...) -- active declareFunction, no body
;; (defun query-interrupt-int (arg1 arg2 arg3) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; No explicit arglist constant; inferred (error-message-var &body body) from expansion
;; $kw17$INFERENCE_ERROR is the catch tag
;; Verified against expansion in inference_run (inference_strategist.java)
;; In SubL this was ccatch :inference-error around the body; in CL we use catch
(defmacro catch-inference-error (error-message-var &body body)
  `(setf ,error-message-var
         (catch :inference-error
           ,@body
           nil)))

;; Reconstructed from Internal Constants:
;; $sym13$ERROR_MESSAGE = gensym, $sym14$PIF
;; $sym15$*INFERENCE_DEBUG?*, $sym16$PROGN
;; $sym18$WITH_INFERENCE_ERROR_HANDLING (self), $sym19$NEW_INFERENCE_ERROR_SUSPEND_STATUS
;; $sym20$WITH_ERROR_HANDLER, $list21 = (FUNCTION INFERENCE-ERROR-HANDLER)
;; Verified against expansion in inference_run (inference_strategist.java):
;; If debug: body directly. Else: bind error-handler, catch :inference-error.
;; When error-message non-nil, set suspend-status via new-inference-error-suspend-status.
(defmacro with-inference-error-handling (suspend-status-var &body body)
  (with-temp-vars (error-message)
    `(let ((,error-message nil))
       (if *inference-debug?*
           (progn ,@body)
           (catch-inference-error ,error-message
             (handler-bind ((error (lambda (c)
                                     (declare (ignore c))
                                     (inference-error-handler))))
               ,@body)))
       (when ,error-message
         (setf ,suspend-status-var
               (new-inference-error-suspend-status ,error-message))))))

(defun inference-error-handler ()
  (throw :inference-error *error-message*))

;; Reconstructed from Internal Constants:
;; $list22 = ((HALT-REASON-VAR TIMEOUT) &BODY BODY) -- arglist
;; $sym23$ABORT_MAX_TIME = gensym, $sym24$TIMED_OUT = gensym
;; $sym25$PCOND, $sym26$WITH_TIMEOUT
;; $list27 = (:MAX-TIME)
;; Verified against expansion in simplest_inference_run_handler (inference_strategist.java):
;; If timeout: with-timeout wrapping body, set halt-reason to :max-time on timeout
;; Else: body directly
(defmacro with-inference-max-time-timeout ((halt-reason-var timeout) &body body)
  (with-temp-vars (abort-max-time timed-out)
    `(let ((,abort-max-time ,timeout))
       (cond (,abort-max-time
              (let ((,timed-out nil))
                (with-timeout (,abort-max-time ,timed-out)
                  ,@body)
                (when ,timed-out
                  (setf ,halt-reason-var :max-time))))
             (t ,@body)))))

(defparameter *within-inference-control-process?* nil)

(defparameter *inference-max-time-timeout-enabled?* t
  "[Cyc] Temporary control variable; whether or not :MAX-TIME is enforced via timeouts.")

(defun inference-abort-max-time (inference)
  "[Cyc] Aborting might leave the inference and its problem store in an inconsistent state.
Hence, if the inference is continuable or if its problem store might be shared,
we avoid triggering a hard abort when it runs out of time."
  (when *inference-max-time-timeout-enabled?*
    (when (not (inference-continuable? inference))
      (when (inference-problem-store-private? inference)
        (inference-max-time inference)))))

(defun explicify-inference-mode-defaults (query-properties)
  "[Cyc] Uses the :inference-mode property in QUERY-PROPERTIES to fill in values for other
query properties, but only if they were not already explicitly specified."
  (let ((inference-mode (inference-properties-mode query-properties)))
    (merge-plist (query-properties-for-inference-mode inference-mode)
                 query-properties)))

;; (defun implicify-inference-mode-defaults (query-properties) ...) -- active declareFunction, no body
;; (defun query-property-value (properties property) ...) -- active declareFunction, no body

(defun strengthen-query-properties-using-inference (inference)
  "[Cyc] Strengthens the properties of INFERENCE.
@note The inference should be in the preparation stage.
But as it requires the dynamic properties to be set beforehand (to access it through the inference),
this check has to be made before calling this function."
  (declare (type inference inference))
  (let* ((problem-store (inference-problem-store inference))
         (problem-store-private? (inference-problem-store-private? inference))
         (max-transformation-depth (inference-max-transformation-depth inference))
         (transformation-allowed? (problem-store-transformation-allowed? problem-store))
         (continuable? (inference-continuable? inference))
         (return-type (inference-return-type inference)))
    (unless transformation-allowed?
      (set-inference-max-transformation-depth inference 0))
    (when (problem-store-new? problem-store)
      (when (and (inference-problem-store-private-wrt-dynamic-properties? inference)
                 (eql max-transformation-depth 0))
        (set-problem-store-transformation-allowed? problem-store nil)))
    (let ((pcase-var return-type))
      (when (or (eql pcase-var :supports)
                (eql pcase-var :bindings-and-supports))
        (set-inference-answer-language inference :hl))
      (when (and (inference-template-return-type-p return-type)
                 (simple-tree-find? :supports return-type))
        (set-inference-answer-language inference :hl)))
    (when (problem-store-new? problem-store)
      (unless problem-store-private?
        (set-problem-store-add-restriction-layer-of-indirection? problem-store t))
      (when (problem-store-forward? problem-store)
        ;; empty branch in Java
        )
      (let ((hl-query (inference-hl-query inference)))
        (when (and problem-store-private?
                   (single-literal-problem-query-p hl-query))
          (when (and (eql max-transformation-depth 0)
                     (not continuable?))
            (set-problem-store-add-restriction-layer-of-indirection? problem-store nil)))))
    (when (problem-store-abduction-allowed? problem-store)
      (set-inference-result-uniqueness-criterion inference :proof)))
  nil)

(defun inference-prepare (inference disjunction-free-el-vars-policy hypothesize?)
  "[Cyc] Turns a :new inference into a :prepared inference.
Canonicalizes the input MT, EL-QUERY, and NON-EXPLANATORY-QUERY (if any) of inference into
HL-QUERY and EXPLANATORY-HL-QUERY and additional resulting bookkeeping.
Returns a :prepared INFERENCE if all goes well during canonicalization,
otherwise returns #$True, #$False, or NIL."
  (declare (type new-inference inference))
  (prepare-inference-hl-query inference disjunction-free-el-vars-policy hypothesize?)
  (inference-prepare-int inference))

(defun inference-prepare-from-dnf (inference dnf scoped-vars)
  (declare (type new-inference inference))
  (prepare-inference-hl-query-from-dnf inference dnf scoped-vars)
  (inference-prepare-int inference))

(defun inference-prepare-int (inference)
  (when (new-inference-p inference)
    (if (simplest-inference-p inference)
        (simplest-inference-prepare inference)
        (error "can't handle non-simplest inferences like ~a" inference))
    (set-inference-status inference :prepared))
  inference)

(defun simplest-inference-prepare (inference)
  "[Cyc] Virtual subclass constructor for simplest-inference-p"
  (declare (type simplest-inference inference))
  (find-or-create-root-problem-and-link inference)
  nil)

(defun simplest-inference-prepare-new (problem-store el-query mt strategy-type
                                       disjunction-free-el-vars-policy hypothesize?
                                       non-explanatory-el-query problem-store-private?)
  "[Cyc] Creates a new inference object and gets it into the :prepared state."
  (let ((inference (new-simplest-inference-of-type problem-store strategy-type)))
    (set-inference-input-el-query inference el-query)
    (set-inference-input-mt inference mt)
    (set-inference-input-non-explanatory-el-query inference non-explanatory-el-query)
    (set-inference-problem-store-private inference problem-store-private?)
    (inference-prepare inference disjunction-free-el-vars-policy hypothesize?)))

(defun simplest-inference-prepare-new-from-dnf (problem-store dnf mt strategy-type
                                                scoped-vars non-explanatory-el-query
                                                problem-store-private?)
  (let ((inference (new-simplest-inference-of-type problem-store strategy-type)))
    (set-inference-input-mt inference mt)
    (set-inference-input-non-explanatory-el-query inference non-explanatory-el-query)
    (set-inference-problem-store-private inference problem-store-private?)
    (inference-prepare-from-dnf inference dnf scoped-vars)))

;; (defun note-inference-tautology-justification (inference justification) ...) -- active declareFunction, no body

(deflexical *tautology-problem-query* '((nil nil))
  "[Cyc] The problem query that expresses a tautology.")

(deflexical *contradiction-problem-query* nil
  "[Cyc] The problem query that expresses a contradiction.")

(defparameter *preparing-inference?* nil)

(defun preparing-inference? ()
  *preparing-inference?*)

(defun prepare-inference-hl-query (inference disjunction-free-el-vars-policy hypothesize?)
  "[Cyc] Modifies and returns INFERENCE.
If all goes well, sets INFERENCE's hl-query to a canonicalized version of
its EL query.  If there is a problem during canonicalization, it does not
set the hl-query, but instead changes the status of INFERENCE
from :new to either :tautology, :contradiction, or :ill-formed."
  (let ((store (inference-problem-store inference)))
    (with-problem-store-memoization-state (store)
      (let* ((space-var (problem-store-sbhl-resource-space store))
             (*resourced-sbhl-marking-spaces* space-var)
             (*resourcing-sbhl-marking-spaces-p* t)
             (*resourced-sbhl-marking-space-limit*
               (determine-marking-space-limit *resourced-sbhl-marking-spaces*))
             (*preparing-inference?* t))
        (let ((input-mt (inference-input-mt inference))
              (input-el-query (inference-input-el-query inference))
              (input-non-explanatory-el-query (inference-input-non-explanatory-el-query inference)))
          (multiple-value-bind (mt el-query explanatory-el-query hypothetical-bindings
                                tautology-justifications)
              (prepare-inference-hl-query-int input-mt input-el-query
                                             input-non-explanatory-el-query hypothesize?)
            (cond ((and mt (not (hlmt-p mt)))
                   (set-inference-status inference :ill-formed))
                  ((eq :not-an-implication el-query)
                   (set-inference-status inference :ill-formed))
                  ((eq :tautology el-query)
                   (set-inference-status inference :tautology)
                   (set-inference-hl-query inference *tautology-problem-query*)
                   ;; Likely records the tautology justifications for the inference
                   (missing-larkc 35561))
                  (t
                   (set-inference-mt inference mt)
                   (set-inference-el-query inference el-query)
                   (set-inference-hypothetical-bindings inference hypothetical-bindings)))
            (when (new-inference-p inference)
              (multiple-value-bind (czer-result el-bindings free-el-vars)
                  (inference-canonicalize-ask-memoized el-query mt disjunction-free-el-vars-policy)
                (cond ((problem-query-p czer-result)
                       (let ((hl-query czer-result))
                         (set-inference-hl-query inference hl-query)
                         (set-inference-el-bindings inference el-bindings)
                         (let ((free-hl-vars (apply-bindings el-bindings free-el-vars)))
                           (set-inference-free-hl-vars inference free-hl-vars))
                         (if (null input-non-explanatory-el-query)
                             (progn
                               (set-inference-explanatory-subquery inference :all)
                               (set-inference-non-explanatory-subquery inference nil))
                             (progn
                               (multiple-value-bind (explanatory-czer-result explanatory-el-bindings
                                                     explanatory-free-el-vars)
                                   (inference-canonicalize-ask-memoized explanatory-el-query mt
                                                                       disjunction-free-el-vars-policy)
                                 (declare (ignore explanatory-el-bindings explanatory-free-el-vars))
                                 (let ((explanatory-subquery explanatory-czer-result))
                                   (set-inference-explanatory-subquery inference explanatory-subquery)))
                               (multiple-value-bind (non-explanatory-czer-result
                                                     non-explanatory-el-bindings
                                                     non-explanatory-free-el-vars)
                                   (inference-canonicalize-ask-memoized input-non-explanatory-el-query
                                                                       mt disjunction-free-el-vars-policy)
                                 (declare (ignore non-explanatory-free-el-vars))
                                 (let* ((non-explanatory-subquery non-explanatory-czer-result)
                                        (non-explanatory-hl-bindings
                                          (apply-bindings non-explanatory-el-bindings el-bindings)))
                                   (set-inference-non-explanatory-subquery
                                    inference
                                    (apply-bindings non-explanatory-hl-bindings
                                                    non-explanatory-subquery))))))))
                      ((eq #$True czer-result)
                       (set-inference-hl-query inference *tautology-problem-query*)
                       (set-inference-status inference :tautology))
                      ((eq #$False czer-result)
                       (set-inference-hl-query inference *contradiction-problem-query*)
                       (set-inference-status inference :contradiction))
                      ((eq :ill-formed czer-result)
                       (set-inference-hl-query inference *contradiction-problem-query*)
                       (set-inference-status inference :ill-formed)))))))
        (setf space-var *resourced-sbhl-marking-spaces*)
        (set-problem-store-sbhl-resource-space store space-var))))
  inference)

(defun prepare-inference-hl-query-int (input-mt input-el-query input-non-explanatory-el-query hypothesize?)
  "[Cyc] Given INPUT-MT, INPUT-EL-QUERY, INPUT-NON-EXPLANATORY-EL-QUERY and HYPOTHESIZE? for some inference,
determine the MT, EL-QUERY, EXPLANATORY-EL-QUERY and HYPOTHETICAL-BINDINGS to use.
@return 1 the mt (nil or possibly-mt-p)
@return 2 the el-query (:TAUTOLOGY or possibly-inference-sentence-p)
@return 3 the explanatory-el-query (nil or possibly-inference-sentence-p)
@return 4 the hypothetical-bindings (nil or bindings-p)"
  (multiple-value-bind (input-el-query input-mt)
      (unwrap-if-ist-permissive input-el-query input-mt)
    (let ((mt nil)
          (el-query nil)
          (explanatory-el-query nil)
          (hypothetical-bindings nil)
          (tautology-justifications nil))
      (if (not hypothesize?)
          (if (null input-non-explanatory-el-query)
              (progn
                (setf mt (if input-mt (canonicalize-hlmt input-mt) nil))
                (setf el-query input-el-query)
                (setf explanatory-el-query input-el-query)
                (setf hypothetical-bindings nil)
                (setf tautology-justifications nil))
              (progn
                (setf mt (if input-mt (canonicalize-hlmt input-mt) nil))
                (setf el-query (make-conjunction (list input-el-query input-non-explanatory-el-query)))
                (setf explanatory-el-query input-el-query)
                (setf hypothetical-bindings nil)
                (setf tautology-justifications nil)))
          ;; hypothesize? is true
          (multiple-value-bind (consequent hypothetical-context v-bindings failure-reasons)
              ;; Likely decomposes an implication into antecedent/consequent and hypothesizes
              (missing-larkc 35554)
            (cond ((null hypothetical-context)
                   (setf mt (if input-mt (canonicalize-hlmt input-mt) nil))
                   (setf el-query :tautology)
                   (setf explanatory-el-query nil)
                   (setf hypothetical-bindings nil)
                   (setf tautology-justifications failure-reasons))
                  ((null input-non-explanatory-el-query)
                   (setf mt hypothetical-context)
                   (setf el-query consequent)
                   (setf explanatory-el-query consequent)
                   (setf hypothetical-bindings v-bindings)
                   (setf tautology-justifications nil))
                  (t
                   (setf mt hypothetical-context)
                   (setf el-query (make-conjunction (list consequent input-non-explanatory-el-query)))
                   (setf explanatory-el-query consequent)
                   (setf hypothetical-bindings v-bindings)
                   (setf tautology-justifications nil)))))
      (values mt el-query explanatory-el-query hypothetical-bindings tautology-justifications))))

;; (defun hypothesize-antecedent (sentence mt) ...) -- active declareFunction, no body
;; (defun inference-conditional-sentence-p (sentence) ...) -- active declareFunction, no body
;; (defun inference-possibly-simplify-conditional-sentence (sentence) ...) -- active declareFunction, no body

(defun prepare-inference-hl-query-from-dnf (inference input-dnf scoped-vars)
  (declare (type dnf input-dnf)
           (type list scoped-vars))
  (let* ((input-mt (inference-input-mt inference))
         (input-non-explanatory-el-query (inference-input-non-explanatory-el-query inference))
         (explanatory-dnf input-dnf)
         (full-dnf explanatory-dnf))
    (set-inference-mt inference input-mt)
    (set-inference-hypothetical-bindings inference nil)
    (when input-non-explanatory-el-query
      (let ((non-explanatory-clauses (dnf-operators-out input-non-explanatory-el-query)))
        (must (singleton? non-explanatory-clauses)
              "Time to support disjunctive #$pragmaticRequirements")
        (let ((non-explanatory-dnf (first non-explanatory-clauses)))
          (set-inference-non-explanatory-subquery inference
                                                 (dnf-and-mt-to-hl-query non-explanatory-dnf input-mt))
          (setf full-dnf (nmerge-dnf (copy-clause explanatory-dnf) non-explanatory-dnf)))))
    (set-inference-el-query inference nil)
    (set-inference-el-bindings inference nil)
    (if (empty-clause? full-dnf)
        (progn
          (set-inference-hl-query inference *tautology-problem-query*)
          (set-inference-status inference :tautology))
        (let ((hl-query (dnf-and-mt-to-hl-query full-dnf input-mt)))
          (set-inference-hl-query inference hl-query)
          (let* ((all-free-hl-vars (tree-gather full-dnf #'hl-variable-p))
                 (free-hl-vars (fast-set-difference all-free-hl-vars scoped-vars)))
            (set-inference-free-hl-vars inference free-hl-vars))
          (if (null input-non-explanatory-el-query)
              (set-inference-explanatory-subquery inference :all)
              (let ((explanatory-subquery (dnf-and-mt-to-hl-query explanatory-dnf input-mt)))
                (set-inference-explanatory-subquery inference explanatory-subquery))))))
  inference)

(defun inference-initial-relevant-strategies (inference)
  "[Cyc] @return listp; a list of strategies in which the root problem of INFERENCE should be
initially active."
  (if (simplest-inference-p inference)
      (strategy-initial-relevant-strategies (simplest-inference-strategy inference))
      (progn
        (error "can't handle non-simple inference seeding of strategies")
        nil)))

(defun inference-update-dynamic-properties (inference new-query-dynamic-properties)
  (declare (type continuable-inference inference)
           (type query-dynamic-properties new-query-dynamic-properties))
  (when (query-dynamic-properties-have-strategically-interesting-extension? inference
                                                                           new-query-dynamic-properties)
    ;; checkType simplest-inference-p in Java
    (let ((strategy (simplest-inference-strategy inference)))
      (strategy-note-inference-dynamic-properties-updated strategy)))
  (let ((new-inference-dynamic-properties
          (extract-inference-dynamic-properties new-query-dynamic-properties)))
    (inference-set-dynamic-properties inference new-inference-dynamic-properties))
  (do-set (problem (inference-relevant-problems inference))
    (when (valid-problem-p problem)
      (set-problem-recompute-thrown-away-wrt-all-relevant-strategies-and-all-motivations problem)
      (set-problem-tactics-recompute-thrown-away-wrt-all-relevant-strategies-and-all-motivations problem)
      ;; Likely recomputes set-aside status for the problem
      (missing-larkc 36451)
      ;; Likely recomputes set-aside status for the problem's tactics
      (missing-larkc 36456)))
  (set-inference-status inference :ready)
  inference)

(defun query-dynamic-properties-have-strategically-interesting-extension? (inference
                                                                           new-query-dynamic-properties)
  (let ((new-inference-dynamic-properties
          (extract-inference-dynamic-properties new-query-dynamic-properties)))
    (let ((old-max-proof-depth (inference-max-proof-depth inference))
          (new-max-proof-depth (inference-properties-max-proof-depth new-inference-dynamic-properties)))
      (when (depth-cutoff-< old-max-proof-depth new-max-proof-depth)
        (return-from query-dynamic-properties-have-strategically-interesting-extension? t)))
    (let ((old-max-transformation-depth (inference-max-transformation-depth inference))
          (new-max-transformation-depth (inference-properties-max-transformation-depth
                                         new-inference-dynamic-properties)))
      (when (depth-cutoff-< old-max-transformation-depth new-max-transformation-depth)
        (return-from query-dynamic-properties-have-strategically-interesting-extension? t))))
  (let* ((new-strategy-dynamic-properties
           (extract-strategy-dynamic-properties new-query-dynamic-properties))
         (strategy (simplest-inference-strategy inference))
         (old-productivity-limit (strategy-productivity-limit strategy))
         (new-productivity-limit (strategy-dynamic-properties-productivity-limit
                                   new-strategy-dynamic-properties)))
    (when (productivity-< old-productivity-limit new-productivity-limit)
      (return-from query-dynamic-properties-have-strategically-interesting-extension? t)))
  nil)

(defun depth-cutoff-< (depth-cutoff-1 depth-cutoff-2)
  (if (integerp depth-cutoff-1)
      (if (integerp depth-cutoff-2)
          (< depth-cutoff-1 depth-cutoff-2)
          t)
      nil))

(defun inference-set-dynamic-properties (inference dynamic-properties)
  (declare (type inference-dynamic-properties dynamic-properties))
  (let ((return-type (inference-properties-return-type dynamic-properties))
        (answer-language (inference-properties-answer-language dynamic-properties))
        (cache-results? (inference-properties-cache-inference-results? dynamic-properties))
        (browsable? (inference-properties-browsable? dynamic-properties))
        (continuable? (inference-properties-continuable? dynamic-properties))
        (block? (inference-properties-block? dynamic-properties))
        (max-number (inference-properties-max-number dynamic-properties))
        (max-time (inference-properties-max-time dynamic-properties))
        (max-step (inference-properties-max-step dynamic-properties))
        (inference-mode (inference-properties-mode dynamic-properties))
        (forward-max-time (inference-properties-forward-max-time dynamic-properties))
        (max-proof-depth (inference-properties-max-proof-depth dynamic-properties))
        (max-trans-depth (inference-properties-max-transformation-depth dynamic-properties))
        (pad (inference-properties-probably-approximately-done dynamic-properties))
        (metrics-template (inference-properties-metrics dynamic-properties)))
    (set-inference-continuable inference continuable?)
    (set-inference-browsable inference browsable?)
    (set-inference-return-type inference return-type)
    (set-inference-answer-language inference answer-language)
    (set-inference-cache-results inference cache-results?)
    (when block?
      ;; Likely sets the inference to blocking mode
      (missing-larkc 35783))
    (set-inference-max-number inference max-number)
    (set-inference-max-time inference max-time)
    (set-inference-max-step inference max-step)
    (set-inference-mode inference inference-mode)
    (set-inference-forward-max-time inference forward-max-time)
    (set-inference-max-proof-depth inference max-proof-depth)
    (set-inference-max-transformation-depth inference max-trans-depth)
    (set-inference-probably-approximately-done inference pad)
    (set-inference-metrics-template inference metrics-template))
  inference)

(defun inference-run (inference)
  (declare (type ready-inference inference)
           (type simplest-inference inference))
  (possibly-enqueue-asked-query-from-inference inference)
  (set-inference-control-process-to-me inference)
  (initialize-inference-time-properties inference)
  (let ((suspend-status :uninitialized))
    ;; catch-inference-abort sets suspend-status to :abort and calls query-abort on abort
    ;; In original Java, missing-larkc 35564 was called instead of query-abort after abort;
    ;; the macro body already includes (query-abort) which is the original unexpanded form
    (catch-inference-abort suspend-status
      (with-inference-error-handling suspend-status
        (set-inference-status inference :running)
        (setf suspend-status (simplest-inference-run-handler inference))))
    (when (valid-inference-p inference)
      (inference-suspend inference suspend-status))
    inference))

(defun inference-suspend (inference suspend-status)
  "[Cyc] Notes that INFERENCE is suspended."
  (finalize-inference-time-properties inference)
  (set-inference-suspend-status inference suspend-status)
  (set-inference-status inference :suspended)
  (clear-inference-control-process inference)
  inference)

;; (defun inference-suspend-due-to-max-problem-count (inference) ...) -- active declareFunction, no body
;; (defun inference-suspend-due-to-max-number (inference) ...) -- active declareFunction, no body
;; (defun inference-suspend-due-to-max-time (inference) ...) -- active declareFunction, no body
;; (defun inference-suspend-due-to-max-step (inference) ...) -- active declareFunction, no body
;; (defun inference-suspend-due-to-pad (inference) ...) -- active declareFunction, no body

(defun inference-interrupt (inference &optional patience)
  "[Cyc] @param PATIENCE nil or non-negative-number-p.
nil means infinite patience, 0 means no patience.
Tries to gracefully interrupt INFERENCE.  Gives up after PATIENCE
seconds and forcefully aborts it instead."
  (enforce-type inference 'running-inference-p)
  (unless (valid-process-p
           ;; Likely retrieves the control process of the inference
           (missing-larkc 35753))
    (let ((error-message "Inference control process was killed while running."))
      (inference-suspend inference (new-inference-error-suspend-status error-message))
      (return-from inference-interrupt inference)))
  (cond ((null patience)
         (inference-interrupt-int inference))
        ((zerop patience)
         ;; Likely forcefully aborts the inference immediately
         (missing-larkc 35556))
        (t
         ;; checkType positive-number-p in Java
         (let ((my-patience-ran-out-p nil))
           (with-timeout (patience my-patience-ran-out-p)
             (inference-interrupt-int inference))
           (when my-patience-ran-out-p
             ;; Likely forcefully aborts the inference after patience runs out
             (missing-larkc 35557)))
         inference)))

(defun inference-interrupt-int (inference)
  "[Cyc] Wait forever for INFERENCE to interrupt itself gracefully."
  ;; Likely signals the inference to interrupt
  (missing-larkc 35778)
  (process-block)
  inference)

(defun inference-abort (inference)
  "[Cyc] Immediately forcefully aborts INFERENCE."
  (inference-interrupt inference 0))

;; (defun inference-abort-after-delay (inference &optional delay) ...) -- active declareFunction, no body

(defun inference-abort-if-running (inference)
  "[Cyc] Immediately forcefully aborts INFERENCE if it is currently running."
  (when (running-inference-p inference)
    (inference-abort inference)))

;; (defun abort-current-controlling-inference () ...) -- active declareFunction, no body
;; (defun inference-abort-int (inference) ...) -- active declareFunction, no body
;; (defun wait-for-inference-to-unblock () ...) -- active declareFunction, no body
;; (defun signal-inference-to-unblock (inference) ...) -- active declareFunction, no body
;; (defun signal-inference-to-finish (inference) ...) -- active declareFunction, no body

(defun inference-max-number-reached? (inference)
  (let ((max-number (inference-max-number inference)))
    (when max-number
      (let ((number
              ;; Likely retrieves the number of answers found so far
              (missing-larkc 35772)))
        (when (>= number max-number)
          (return-from inference-max-number-reached? t)))))
  nil)

(defun inference-max-time-reached? (inference)
  (let ((end-time (inference-end-internal-real-time inference)))
    (when end-time
      (return-from inference-max-time-reached?
        (internal-real-time-has-arrived? end-time))))
  nil)

;; (defun current-controlling-inference-max-time-reached? () ...) -- active declareFunction, no body
;; (defun current-controlling-inference-time-remaining () ...) -- active declareFunction, no body

(defun inference-max-step-reached? (inference)
  (let ((max-step (inference-max-step inference)))
    (when max-step
      (let ((step-count
              ;; Likely retrieves the step count of the inference
              (missing-larkc 35779)))
        (return-from inference-max-step-reached? (>= step-count max-step)))))
  nil)

(defun inference-max-problem-count-reached? (inference)
  (problem-store-max-problem-count-reached? (inference-problem-store inference)))

(defun inference-max-proof-count-reached? (inference)
  (problem-store-max-proof-count-reached? (inference-problem-store inference)))

;; (defun inference-crazy-max-problem-count-reached? (inference) ...) -- active declareFunction, no body

(defun inference-probably-approximately-done? (inference)
  (when (zerop (inference-answer-count inference))
    (let ((end-time (inference-pad-internal-real-time inference)))
      (when (internal-real-time-p end-time)
        (return-from inference-probably-approximately-done?
          (internal-real-time-has-arrived? end-time)))))
  nil)

(defun inference-halt-condition-reached? (inference)
  "[Cyc] Halt conditions are noted by overloading the suspend-status while the inference is still running."
  (inference-halt-condition-p (inference-suspend-status inference)))

(defun inference-determine-type-independent-result (inference)
  "[Cyc] @return nil or inference-suspend-status-p
Handles the inference-type-independent results; those that can be
determined without knowing the type of INFERENCE.
a NIL return value means that a type-independent result
cannot be determined."
  (cond ((inference-interrupt-signaled? inference)
         :interrupt)
        ((inference-max-number-reached? inference)
         :max-number)
        ((inference-max-time-reached? inference)
         :max-time)
        ((inference-max-step-reached? inference)
         :max-step)
        ((inference-max-problem-count-reached? inference)
         :max-problem-count)
        ((inference-max-proof-count-reached? inference)
         :max-proof-count)
        ((inference-probably-approximately-done? inference)
         :probably-approximately-done)
        ((inference-halt-condition-reached? inference)
         (inference-suspend-status inference))
        (t nil)))

(defvar *default-strategy-type* :heuristic-balanced
  "[Cyc] The strategy type to use unless there is a better one for a
particular type of inference.")

(defvar *exhaustive-removal-strategy-type* :removal
  "[Cyc] The strategy type that is best suited for removal-only zero-backchain asks
with no number or time cutoffs.")

(defvar *forward-strategy-type* :removal
  "[Cyc] The strategy type that is best suited for forward inference.")

(defun strategy-type-from-sentence-and-static-properties (sentence mt static-properties)
  (declare (ignore sentence mt))
  (strategy-type-from-static-properties static-properties))

(defun strategy-type-from-dnf-and-static-properties (dnf mt static-properties)
  (declare (ignore dnf mt))
  (strategy-type-from-static-properties static-properties))

(defun strategy-type-from-static-properties (static-properties)
  (cond ((properties-indicate-forward-inference? static-properties)
         *forward-strategy-type*)
        ((balancing-tactician-enabled?)
         (if (problem-store-properties-abduction-allowed? static-properties)
             *abductive-strategy-type*
             :balancing))
        ((problem-store-properties-abduction-allowed? static-properties)
         *abductive-strategy-type*)
        ((transformation-allowed-by-properties? static-properties)
         *default-strategy-type*)
        (t *exhaustive-removal-strategy-type*)))

(defun properties-indicate-forward-inference? (static-properties)
  (let ((store (inference-properties-problem-store static-properties)))
    (when (and store (problem-store-forward? store))
      (return-from properties-indicate-forward-inference? t)))
  nil)

(defun inference-permits-transformation? (inference)
  (let ((store (inference-problem-store inference)))
    (and (problem-store-transformation-allowed? store)
         (not (eql 0 (inference-max-transformation-depth inference))))))

(defun determine-best-strategy-type-for-inference (inference)
  (when (balancing-tactician-enabled?)
    (return-from determine-best-strategy-type-for-inference
      (if (abductive-inference-p inference)
          *abductive-strategy-type*
          :balancing)))
  (cond ((forward-inference-p inference)
         *forward-strategy-type*)
        ((abductive-inference-p inference)
         *abductive-strategy-type*)
        ((and (not (inference-permits-transformation? inference))
              (not (inference-max-number inference))
              (not (inference-max-time inference))
              (not (inference-max-step inference)))
         *exhaustive-removal-strategy-type*)
        (t *default-strategy-type*)))

(defun consider-switching-strategies (inference)
  (declare (type simplest-inference inference))
  (let ((best-strategy-type (determine-best-strategy-type-for-inference inference)))
    (unless (eq best-strategy-type
                (strategy-type (simplest-inference-strategy inference)))
      (inference-switch-strategies inference best-strategy-type)))
  inference)

(defun inference-switch-strategies (inference new-strategy-type)
  "[Cyc] Causes INFERENCE to switch from its existing strategy to a new strategy of
NEW-STRATEGY-TYPE.  Destroys the old strategy after the switch."
  (declare (type simplest-inference inference)
           (ignore new-strategy-type))
  inference)

(defun simplest-inference-run-handler (inference)
  "[Cyc] A meta-strategy which just tells the strategy to
do a bunch of steps in this thread, i.e. handle lots of :do-one-step events,
optionally block, possibly perform a problem store prune,
and halt when done (e.g. resource constraints exhausted)
@return inference-suspend-status-p; the halt-reason."
  (declare (type simplest-inference inference))
  (let* ((strategy (simplest-inference-strategy inference))
         (store (inference-problem-store inference))
         (timeout (inference-abort-max-time inference))
         (result nil))
    (with-inference-max-time-timeout (result timeout)
      (with-problem-store-memoization-state (store)
        (let* ((space-var (problem-store-sbhl-resource-space store))
               (*resourced-sbhl-marking-spaces* space-var)
               (*resourcing-sbhl-marking-spaces-p* t)
               (*resourced-sbhl-marking-space-limit*
                 (determine-marking-space-limit *resourced-sbhl-marking-spaces*))
               (*problem-store-modification-permitted?* t))
          (inference-do-forward-propagation inference)
          (let ((pad? nil)
                (done? pad?))
            (loop until done? do
              (possibly-wait-for-inference-to-unblock inference)
              (strategy-do-one-step strategy)
              (simplest-inference-possibly-prune inference)
              (setf done? (or pad? (simplest-inference-done? inference))))
            (strategy-throw-away-uninteresting-set-asides strategy)
            (setf result (simplest-inference-determine-result inference pad?))
            (when (eq :interrupt result)
              ;; Likely handles interrupt cleanup for the inference
              (missing-larkc 35762)))
          (setf space-var *resourced-sbhl-marking-spaces*)
          (set-problem-store-sbhl-resource-space store space-var))))
    (must (or (not (eq :exhaust result))
              (inference-continuable? inference))
          "Non-continuable inference should have been :exhaust-total instead of :exhaust")
    result))

(defun inference-do-forward-propagation (inference)
  (let ((forward-max-time (inference-forward-max-time inference))
        (mt (inference-mt inference)))
    (declare (ignore mt))
    (when (and (integerp forward-max-time)
               (> forward-max-time 0))
      (unless (forward-propagate-p
               ;; Likely retrieves the current forward propagation object
               (missing-larkc 35761))
        ;; Likely initializes forward propagation
        (missing-larkc 35789))
      (let ((store (inference-problem-store inference)))
        (with-problem-store-memoization-state (store)
          (let* ((space-var (problem-store-sbhl-resource-space store))
                 (*resourced-sbhl-marking-spaces* space-var)
                 (*resourcing-sbhl-marking-spaces-p* t)
                 (*resourced-sbhl-marking-space-limit*
                   (determine-marking-space-limit *resourced-sbhl-marking-spaces*)))
            ;; Likely performs the actual forward propagation step
            (missing-larkc 80)
            (setf space-var *resourced-sbhl-marking-spaces*)
            (set-problem-store-sbhl-resource-space store space-var))))))
  nil)

(defun simplest-inference-done? (inference)
  (if (simplest-inference-exhausted? inference)
      t
      (and (inference-determine-type-independent-result inference) t)))

(defun possibly-wait-for-inference-to-unblock (inference)
  (when (inference-blocking? inference)
    ;; Likely waits for the inference to be unblocked by another thread
    (missing-larkc 35568)
    t))

(defun simplest-inference-possibly-prune (inference)
  (when (or (inference-max-problem-count-reached? inference)
            (inference-max-proof-count-reached? inference)
            (inference-prune-frequency-reached? inference))
    (when
        ;; Likely checks if a crazy-max problem count has been reached
        (missing-larkc 35558)
      (let ((store (inference-problem-store inference)))
        (error "Crazy amount of problems (~a) in store ~a"
               (problem-store-problem-count store) store)))
    (let ((strategy (simplest-inference-strategy inference)))
      (declare (ignore strategy))
      ;; Likely performs a store prune via the strategy
      (return-from simplest-inference-possibly-prune
        (missing-larkc 35461))))
  nil)

(defun inference-prune-frequency-reached? (inference)
  (declare (ignore inference))
  nil)

(defun simplest-inference-determine-result (inference pad?)
  "[Cyc] @return nil or inference-suspend-status-p,
nil indicates it's not time to suspend yet (still more work to do)"
  (when pad?
    (return-from simplest-inference-determine-result :probably-approximately-done))
  (let ((result (inference-determine-type-independent-result inference)))
    (when result
      (return-from simplest-inference-determine-result result)))
  (unless (simplest-inference-exhausted? inference)
    (return-from simplest-inference-determine-result nil))
  (if (simplest-inference-continuation-possible? inference)
      :exhaust
      :exhaust-total))

(defun simplest-inference-continuation-possible? (inference)
  (let ((strategy (simplest-inference-strategy inference)))
    (strategy-continuation-possible? strategy)))

(defun simplest-inference-exhausted? (inference)
  (let ((strategy (simplest-inference-strategy inference)))
    (strategy-done? strategy)))

;; (defun simplest-inference-totally-exhausted? (inference) ...) -- active declareFunction, no body

(defun inference-note-proof (inference proof)
  (new-inference-answer-from-proof inference proof)
  nil)

(defun inference-note-no-good (inference)
  (declare (ignore inference))
  nil)

(defun new-inference-answer-from-proof (inference proof)
  "[Cyc] @return inference-answer-p or NIL"
  (declare (type inference inference)
           (type proof proof))
  (perform-lazy-proof-rejection proof inference)
  (when (proof-proven? proof)
    (let ((answer-bindings (inference-answer-bindings-from-proof proof inference)))
      (unless (inference-disallows-answer-from-bindings? inference answer-bindings)
        (let ((answer nil))
          (if (inference-compute-answer-justifications? inference)
              (let* ((hl-justification (inference-all-explanatory-proof-supports inference proof))
                     (answer-justification (find-or-create-inference-answer-justification
                                            inference answer-bindings hl-justification)))
                (setf answer (inference-answer-justification-answer answer-justification))
                (add-inference-answer-justification-proof answer-justification proof))
              (setf answer (find-or-create-inference-answer inference answer-bindings)))
          (perform-inference-answer-proof-analysis answer proof)
          (possibly-note-proof-processed proof)
          (return-from new-inference-answer-from-proof answer)))))
  nil)

(defun inference-disallows-answer-from-bindings? (inference answer-bindings)
  (unless (inference-allow-indeterminate-results? inference)
    (when
        ;; Likely checks if any of the answer bindings are indeterminate
        (missing-larkc 35567)
      (return-from inference-disallows-answer-from-bindings? t)))
  nil)

;; (defun inference-disallows-answer-from-proof? (inference proof) ...) -- active declareFunction, no body
;; (defun some-answer-bindings-are-indeterminate? (bindings) ...) -- active declareFunction, no body
;; (defun some-answer-bindings-are-hl? (bindings) ...) -- active declareFunction, no body
;; (defun term-requires-hl-language (term) ...) -- active declareFunction, no body

(defun inference-all-explanatory-proof-supports (inference proof)
  (let ((all-subproofs (all-proof-subproofs proof))
        (non-explanatory-subproofs (inference-proof-non-explanatory-subproofs inference proof))
        (all-supports nil))
    (dolist (subproof all-subproofs)
      (unless (member? subproof non-explanatory-subproofs)
        (let ((supports (proof-supports subproof)))
          (dolist (support supports)
            (unless (member support all-supports :test #'equal)
              (push support all-supports))))))
    (setf all-supports (canonicalize-hl-justification all-supports))
    all-supports))

(defun inference-answer-bindings-from-proof (proof inference)
  "[Cyc] @return bindings which map INFERENCE's EL variables -> answers"
  (let* ((all-hl-bindings (inference-hl-bindings-from-proof proof inference))
         (hl-bindings (filter-out-uninteresting-bindings all-hl-bindings
                                                         (inference-free-hl-vars inference)))
         (all-el-bindings (inference-el-bindings inference))
         (free-el-vars (inference-free-el-vars inference))
         (el-bindings (filter-out-uninteresting-bindings all-el-bindings free-el-vars))
         (disjunction-free-el-vars-policy (inference-disjunction-free-el-vars-policy inference))
         (answer-bindings (if el-bindings
                              (compose-el-answer-bindings el-bindings hl-bindings
                                                          free-el-vars disjunction-free-el-vars-policy)
                              hl-bindings)))
    answer-bindings))

(defun filter-out-uninteresting-bindings (v-bindings interesting-variables)
  (if (all-variables-in-bindings-interesting? v-bindings interesting-variables)
      v-bindings
      (let ((interesting-bindings nil))
        (dolist (binding v-bindings)
          (destructuring-bind (variable . value) binding
            (declare (ignore value))
            (when (member? variable interesting-variables)
              (push binding interesting-bindings))))
        (nreverse interesting-bindings))))

(defun all-variables-in-bindings-interesting? (v-bindings interesting-variables)
  (dolist (binding v-bindings t)
    (destructuring-bind (variable . value) binding
      (declare (ignore value))
      (unless (member? variable interesting-variables)
        (return nil)))))

(defun compose-el-answer-bindings (el-bindings hl-bindings free-el-vars free-el-vars-policy)
  "[Cyc] @param EL-BINDINGS; EL variables -> HL variables
@param HL-BINDINGS; HL variables -> answers
@param FREE-EL-VARS; free EL variables in display preference order
@param FREE-EL-VARS-POLICY; the policy for handling free el variables in disjunctions
@return bindings-p; EL variables -> answers.
Signals an error if the range of EL-BINDINGS and the domain of HL-BINDINGS are not
consistent under FREE-EL-VARS-POLICY."
  (unless (eq :compute-union free-el-vars-policy)
    (let ((hl-vars1 (mapcar #'variable-binding-value el-bindings))
          (hl-vars2 (mapcar #'variable-binding-variable hl-bindings)))
      (must (sets-equal? hl-vars1 hl-vars2)
            "Expected a one-to-one match between EL and HL bindings, got ~a and ~a"
            el-bindings hl-bindings)))
  (let ((el-answer-bindings (compose-bindings el-bindings hl-bindings)))
    (setf el-answer-bindings (stable-sort-bindings el-answer-bindings free-el-vars))
    el-answer-bindings))

(defun inference-hl-bindings-from-proof (proof inference)
  "[Cyc] @return bindings which map INFERENCE's variables -> answers"
  (let* ((proof-hl-bindings (proof-bindings proof))
         (answer-link (inference-root-link inference))
         (mapped-root-problem (problem-link-sole-supporting-mapped-problem answer-link))
         (variable-map (mapped-problem-variable-map mapped-root-problem))
         (hl-bindings (transfer-variable-map-to-bindings variable-map proof-hl-bindings)))
    hl-bindings))

(defparameter *processed-proof-pruning-initial-threshold* 200
  "[Cyc] Once an inference has achieved this many proofs, we consider pruning processed proofs.")

(defparameter *processed-proof-pruning-frequency* 50
  "[Cyc] After the initial pruning threshold is met, we prune processed proofs again every time we get this many new proofs.")

;; (defun inference-processed-proof-pruning-initial-threshold-met? (inference) ...) -- active declareFunction, no body
;; (defun inference-processed-proof-pruning-variable-threshold-met? (inference) ...) -- active declareFunction, no body

(defun inference-possibly-prune-processed-proofs (inference)
  (let ((store (inference-problem-store inference))
        (total-pruned 0))
    (when (problem-store-allows-proof-processing? store)
      (when (or (testing-real-time-pruning?)
                (and
                 ;; Likely checks if the initial pruning threshold is met
                 (missing-larkc 35559)
                 ;; Likely checks if the variable pruning threshold is met
                 (missing-larkc 35560)))
        ;; Likely notes that pruning has occurred
        (missing-larkc 35790)
        (if (balancing-tactician-enabled?)
            (let ((prune-count
                    ;; Likely prunes processed proofs for the balancing tactician
                    (missing-larkc 35263)))
              (setf total-pruned (+ total-pruned prune-count))
              (when (plusp prune-count)
                (setf total-pruned
                      (+ total-pruned
                         ;; Likely prunes orphaned problems after proof pruning
                         (missing-larkc 35329)))))
            (setf total-pruned
                  (+ total-pruned
                     ;; Likely prunes processed proofs for non-balancing tactician
                     (missing-larkc 35262))))))
    total-pruned))

(defun perform-inference-answer-proof-analysis (answer proof)
  (let ((subproofs (all-proof-subproofs proof))
        (rules nil))
    (dolist (subproof subproofs)
      (when (generalized-transformation-proof-p subproof)
        (let ((store (proof-store proof))
              (rule (generalized-transformation-proof-rule-assertion subproof)))
          (unless (member rule rules :test #'eq)
            (push rule rules))
          (problem-store-note-transformation-rule-success store rule))))
    (note-inference-answer-proof-rules rules))
  nil)

;; (defun cache-inference-answer (answer) ...) -- active declareFunction, no body
;; (defun cache-proof (proof) ...) -- active declareFunction, no body
;; (defun cache-proof-supports (proof) ...) -- active declareFunction, no body
;; (defun add-deduction-for-proof (proof answer) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list95 = (TIME &BODY BODY) -- arglist
;; $sym96$TIMER = gensym
;; $sym97$CUNWIND_PROTECT
;; $sym98$WITH_QUERY_ABORT_TIMEOUT_START_TIMER
;; $sym99$WITH_QUERY_ABORT_TIMEOUT_STOP_TIMER
;; Verified against registered macro helpers in setup
(defmacro with-query-abort-timeout (time &body body)
  (with-temp-vars (timer)
    `(let ((,timer nil))
       (unwind-protect
            (progn
              (setf ,timer (with-query-abort-timeout-start-timer ,time))
              ,@body)
         (with-query-abort-timeout-stop-timer ,timer)))))

;; (defun with-query-abort-timeout-start-timer (time) ...) -- active declareFunction, no body
;; (defun with-query-abort-timeout-stop-timer (timer) ...) -- active declareFunction, no body
;; (defun with-query-abort-timeout-timer-thread (time tag client-name timer-name) ...) -- active declareFunction, no body
;; (defun with-query-abort-timeout-signal-query-abort-timeout (process) ...) -- active declareFunction, no body

;; Setup forms
(toplevel (note-funcall-helper-function 'query-interrupt-int))
(toplevel (register-macro-helper 'with-query-abort-timeout-start-timer 'with-query-abort-timeout))
(toplevel (register-macro-helper 'with-query-abort-timeout-stop-timer 'with-query-abort-timeout))
