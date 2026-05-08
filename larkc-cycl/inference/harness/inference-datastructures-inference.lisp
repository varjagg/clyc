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

;; Inference datastructures: the inference object, inference answers, and
;; inference answer justifications. This is the core of the inference harness's
;; result tracking.

;;; Variables

(deflexical *inference-types* '(:simplest))

;;; inference defstruct -- 68 slots, conc-name "infrnc-"
;;; print-object is missing-larkc 35787 — CL's default print-object handles this.

(defstruct (inference
            (:conc-name "infrnc-")
            (:predicate inference-p))
  suid
  problem-store
  forward-propagate
  input-mt
  input-el-query
  input-non-explanatory-el-query
  input-query-properties
  mt
  el-query
  el-bindings
  hl-query
  explanatory-subquery
  non-explanatory-subquery
  free-hl-vars
  hypothetical-bindings
  answer-id-index
  answer-bindings-index
  new-answer-id-start
  new-answer-justifications
  status
  suspend-status
  root-link
  relevant-problems
  strategy-set
  control-process
  interrupting-processes
  max-transformation-depth-reached
  disjunction-free-el-vars-policy
  result-uniqueness-criterion
  allow-hl-predicate-transformation?
  allow-unbound-predicate-transformation?
  allow-evaluatable-predicate-transformation?
  allow-indeterminate-results?
  allowed-rules
  forbidden-rules
  allowed-modules
  allow-abnormality-checking?
  transitive-closure-mode
  problem-store-private?
  continuable?
  browsable?
  return-type
  answer-language
  cache-results?
  blocking?
  max-number
  max-time
  max-step
  mode
  forward-max-time
  max-proof-depth
  max-transformation-depth
  probably-approximately-done
  metrics-template
  start-universal-time
  start-internal-real-time
  end-internal-real-time
  pad-internal-real-time
  cumulative-time
  step-count
  cumulative-step-count
  events
  halt-conditions
  accumulators
  proof-watermark
  problem-working-time-data
  type
  data)


(defun sxhash-inference-method (object)
  (infrnc-suid object))

(defun inference-type-p (object)
  "[Cyc] Returns T if OBJECT is a valid inference type."
  (and (member object *inference-types* :test #'eq) t))

(defun valid-inference-p (object)
  (and (inference-p object)
       (not (inference-invalid-p object))))

(defun inference-invalid-p (inference)
  (eq :dead (inference-status inference)))

;; (defun invalid-inference-p (object) ...) -- active declareFunction, no body
;; (defun print-inference (object stream depth) ...) -- active declareFunction, no body

(defun new-inference-p (object)
  (and (inference-p object)
       (eq :new (inference-status object))))

(defun prepared-inference-p (object)
  (and (inference-p object)
       (eq :prepared (inference-status object))))

;; (defun ready-inference-p (object) ...) -- active declareFunction, no body

(defun running-inference-p (object)
  (and (inference-p object)
       (eq :running (inference-status object))))

;; (defun suspended-inference-p (object) ...) -- active declareFunction, no body

(defun continuable-inference-p (object)
  (when (inference-p object)
    (let ((status (inference-status object)))
      (when (continuable-inference-status-p status)
        (if (eq :suspended status)
            (when (inference-continuable? object)
              (let ((suspend-status (inference-suspend-status object)))
                ;; Likely checks continuable-inference-suspend-status-p
                (missing-larkc 36495)))
            t)))))

;; (defun exhausted-inference-p (object) ...) -- active declareFunction, no body

;;; Macros (declared via declareMacro)
;; TODO: do-inference-relevant-problems - macro declared, needs reconstruction
;; Evidence: $sym366$INFERENCE_VAR (gensym), needs investigation of expansion sites

;; TODO: do-inference-new-answer-justifications - macro declared, needs reconstruction
;; Helpers: inference-new-answer-justifications

;; TODO: do-inference-new-answers - macro declared, needs reconstruction
;; Evidence: $sym279$START_ID, $sym280$END_ID, $sym281$ID, $sym282$INF (gensyms)
;; Helpers: inference-new-answer-id-start, inference-next-new-answer-id

;; TODO: do-inference-answers - macro declared, needs reconstruction
;; Evidence: $sym294$ID (gensym)
;; Helpers: inference-answer-id-index

;; TODO: do-inference-answers-from-index - macro declared, needs reconstruction
;; Evidence: $sym299$START_ID, $sym300$END_ID, $sym301$ID, $sym302$INF, $sym304$ANSWER (gensyms)

;; TODO: do-inference-justifications - macro declared, needs reconstruction

;; TODO: do-inference-interrupting-processes - macro declared, needs reconstruction

;; TODO: do-inference-root-proofs - macro declared, needs reconstruction
;; Evidence: $sym313$ROOT_PROBLEM (gensym)

;; TODO: do-inference-allowed-rules - macro declared, needs reconstruction

;; TODO: with-inference-problem-working-time-lock - macro declared, needs reconstruction
;; Evidence: $sym514$INFERENCE_VAR (gensym)
;; Helper: inference-problem-working-time-lock

;; TODO: with-inference-ids - macro declared, needs reconstruction

;;; Functions — new-inference and related

(defun new-inference (store)
  "[Cyc] Allocates a new inference object and sets up its internal datastructures."
  (declare (type problem-store store))
  (let ((inf (make-inference))
        (suid (problem-store-new-inference-id store)))
    (increment-inference-historical-count)
    (setf (infrnc-suid inf) suid)
    (setf (infrnc-problem-store inf) store)
    (setf (infrnc-forward-propagate inf) nil)
    (setf (infrnc-hypothetical-bindings inf) nil)
    (setf (infrnc-answer-id-index inf) (new-id-index 10 0))
    (setf (infrnc-answer-bindings-index inf) (make-hash-table :test #'equal))
    (setf (infrnc-new-answer-justifications inf) (create-queue))
    (reset-inference-new-answers inf)
    (set-inference-status inf :new)
    (setf (infrnc-relevant-problems inf) (new-set #'eq))
    (setf (infrnc-strategy-set inf) (new-set #'eq))
    (clear-inference-control-process inf)
    (setf (infrnc-interrupting-processes inf) (create-queue))
    (setf (infrnc-max-transformation-depth-reached inf) 0)
    (set-inference-answer-language inf *inference-default-answer-language*)
    (set-inference-disjunction-free-el-vars-policy inf *default-inference-disjunction-free-el-vars-policy*)
    (set-inference-cache-results inf nil)
    (set-inference-continuable inf *inference-default-continuable?*)
    (set-inference-browsable inf *inference-default-browsable?*)
    (set-inference-max-number inf *default-max-number*)
    (set-inference-max-time inf *default-max-time*)
    (set-inference-max-step inf *default-max-step*)
    (set-inference-mode inf *default-inference-mode*)
    (set-inference-forward-max-time inf *default-forward-max-time*)
    (set-inference-cumulative-time inf 0)
    (set-inference-step-count inf 0)
    (set-inference-cumulative-step-count inf 0)
    (set-inference-max-proof-depth inf *default-max-proof-depth*)
    (set-inference-max-transformation-depth inf *default-max-transformation-depth*)
    (set-inference-probably-approximately-done inf *default-probably-approximately-done*)
    (set-inference-metrics-template inf *default-inference-metrics-template*)
    (setf (infrnc-accumulators inf) (make-hash-table :test #'eq))
    (setf (infrnc-proof-watermark inf) 0)
    (clear-inference-blocking inf)
    (add-problem-store-inference store inf)
    inf))

;; (defun new-tautological-inference (store) ...) -- active declareFunction, no body

;; (defun destroy-all-inferences () ...) -- active declareFunction, no body

(defun destroy-inference (inference)
  "[Cyc] Disposes of the INFERENCE datastructure. This gets rid of all pointers to its referenced substructures so that the GC can collect them all."
  (when (valid-inference-p inference)
    (unwind-protect
         (inference-abort-if-running inference)
      (let ((*is-thread-performing-cleanup?* t))
        (note-inference-invalid inference)
        (do-set (strategy (inference-strategy-set inference))
          (destroy-inference-strategy strategy))
        (let ((root-link (inference-root-link inference)))
          (destroy-problem-link root-link))
        (let ((store (inference-problem-store inference)))
          (remove-problem-store-inference store inference))
        (destroy-inference-int inference))))
  nil)

;; (defun destroy-inference-and-problem-store (inference) ...) -- active declareFunction, no body

(defun destroy-problem-store-inference (inference)
  (when (valid-inference-p inference)
    (inference-abort-if-running inference)
    (note-inference-invalid inference)
    (destroy-inference-int inference)))

(defun destroy-inference-int (inf)
  (destroy-forward-propagate (infrnc-forward-propagate inf))
  (setf (infrnc-problem-store inf) :free)
  (setf (infrnc-forward-propagate inf) :free)
  (setf (infrnc-input-mt inf) :free)
  (setf (infrnc-input-el-query inf) :free)
  (setf (infrnc-input-non-explanatory-el-query inf) :free)
  (setf (infrnc-input-query-properties inf) :free)
  (setf (infrnc-mt inf) :free)
  (setf (infrnc-el-query inf) :free)
  (setf (infrnc-el-bindings inf) :free)
  (setf (infrnc-hl-query inf) :free)
  (setf (infrnc-explanatory-subquery inf) :free)
  (setf (infrnc-non-explanatory-subquery inf) :free)
  (setf (infrnc-free-hl-vars inf) :free)
  (setf (infrnc-hypothetical-bindings inf) :free)
  (clear-id-index (infrnc-answer-id-index inf))
  (setf (infrnc-answer-id-index inf) :free)
  (clrhash (infrnc-answer-bindings-index inf))
  (setf (infrnc-answer-bindings-index inf) :free)
  (setf (infrnc-new-answer-id-start inf) :free)
  (clear-queue (infrnc-new-answer-justifications inf))
  (setf (infrnc-new-answer-justifications inf) :free)
  (setf (infrnc-suspend-status inf) :free)
  (setf (infrnc-root-link inf) :free)
  (clear-inference-relevant-problems inf)
  (setf (infrnc-relevant-problems inf) :free)
  (clear-inference-strategy-set inf)
  (setf (infrnc-strategy-set inf) :free)
  (clear-inference-control-process inf)
  (setf (infrnc-control-process inf) :free)
  (clear-queue (infrnc-interrupting-processes inf))
  (setf (infrnc-interrupting-processes inf) :free)
  (setf (infrnc-max-transformation-depth-reached inf) :free)
  (clear-inference-blocking inf)
  (setf (infrnc-blocking? inf) :free)
  (setf (infrnc-disjunction-free-el-vars-policy inf) :free)
  (setf (infrnc-result-uniqueness-criterion inf) :free)
  (setf (infrnc-allow-hl-predicate-transformation? inf) :free)
  (setf (infrnc-allow-unbound-predicate-transformation? inf) :free)
  (setf (infrnc-allow-evaluatable-predicate-transformation? inf) :free)
  (setf (infrnc-allow-indeterminate-results? inf) :free)
  (setf (infrnc-allowed-rules inf) :free)
  (setf (infrnc-forbidden-rules inf) :free)
  (setf (infrnc-allowed-modules inf) :free)
  (setf (infrnc-allow-abnormality-checking? inf) :free)
  (setf (infrnc-transitive-closure-mode inf) :free)
  (setf (infrnc-problem-store-private? inf) :free)
  (setf (infrnc-continuable? inf) :free)
  (setf (infrnc-browsable? inf) :free)
  (setf (infrnc-return-type inf) :free)
  (setf (infrnc-answer-language inf) :free)
  (setf (infrnc-cache-results? inf) :free)
  (setf (infrnc-max-number inf) :free)
  (setf (infrnc-max-time inf) :free)
  (setf (infrnc-max-step inf) :free)
  (setf (infrnc-mode inf) :free)
  (setf (infrnc-forward-max-time inf) :free)
  (setf (infrnc-max-proof-depth inf) :free)
  (setf (infrnc-max-transformation-depth inf) :free)
  (setf (infrnc-probably-approximately-done inf) :free)
  (setf (infrnc-metrics-template inf) :free)
  (setf (infrnc-start-universal-time inf) :free)
  (setf (infrnc-start-internal-real-time inf) :free)
  (setf (infrnc-end-internal-real-time inf) :free)
  (setf (infrnc-pad-internal-real-time inf) :free)
  (setf (infrnc-cumulative-time inf) :free)
  (setf (infrnc-step-count inf) :free)
  (setf (infrnc-cumulative-step-count inf) :free)
  (setf (infrnc-events inf) :free)
  (setf (infrnc-halt-conditions inf) :free)
  (setf (infrnc-accumulators inf) :free)
  (setf (infrnc-proof-watermark inf) :free)
  (let ((lock (inference-problem-working-time-lock inf)))
    (unless (bt:lock-p lock)
      (setf lock nil))
    (if lock
        (bt:with-lock-held (lock)
          (setf (infrnc-problem-working-time-data inf) :free))
        (setf (infrnc-problem-working-time-data inf) :free)))
  (setf (infrnc-type inf) :free)
  (setf (infrnc-data inf) :free)
  nil)

(defun note-inference-invalid (inference)
  (set-inference-status inference :dead)
  inference)

;;; Public accessors (checkType wrappers around struct accessors)

(defun inference-suid (inference)
  (declare (type inference inference))
  (infrnc-suid inference))

(defun inference-problem-store (inference)
  (declare (type inference inference))
  (infrnc-problem-store inference))

;; (defun inference-forward-propagate (inference) ...) -- active declareFunction, no body

(defun inference-input-mt (inference)
  (declare (type inference inference))
  (infrnc-input-mt inference))

(defun inference-input-el-query (inference)
  (declare (type inference inference))
  (infrnc-input-el-query inference))

(defun inference-input-non-explanatory-el-query (inference)
  (declare (type inference inference))
  (infrnc-input-non-explanatory-el-query inference))

(defun inference-input-query-properties (inference)
  "[Cyc] Return query-properties-p; the input query properties for INFERENCE."
  (declare (type inference inference))
  (infrnc-input-query-properties inference))

(defun inference-mt (inference)
  (declare (type inference inference))
  (infrnc-mt inference))

;; (defun inference-el-query (inference) ...) -- active declareFunction, no body

(defun inference-el-bindings (inference)
  "[Cyc] Returns bindings which map HL proven query wrt INFERENCE -> EL proven query wrt INFERENCE"
  (declare (type inference inference))
  (infrnc-el-bindings inference))

(defun inference-hl-query (inference)
  (declare (type inference inference))
  (infrnc-hl-query inference))

(defun inference-explanatory-subquery (inference)
  (declare (type inference inference))
  (infrnc-explanatory-subquery inference))

;; (defun inference-non-explanatory-subquery (inference) ...) -- active declareFunction, no body

(defun inference-free-hl-vars (inference)
  (declare (type inference inference))
  (infrnc-free-hl-vars inference))

;; (defun inference-hypothetical-bindings (inference) ...) -- active declareFunction, no body

(defun inference-answer-id-index (inference)
  (declare (type inference inference))
  (infrnc-answer-id-index inference))

(defun inference-answer-bindings-index (inference)
  (declare (type inference inference))
  (infrnc-answer-bindings-index inference))

(defun inference-new-answer-id-start (inference)
  (declare (type inference inference))
  (infrnc-new-answer-id-start inference))

(defun inference-new-answer-justifications (inference)
  (declare (type inference inference))
  (infrnc-new-answer-justifications inference))

(defun inference-status (inference)
  (declare (type inference inference))
  (infrnc-status inference))

(defun inference-suspend-status (inference)
  (declare (type inference inference))
  (infrnc-suspend-status inference))

(defun inference-root-link (inference)
  (declare (type inference inference))
  (infrnc-root-link inference))

(defun inference-relevant-problems (inference)
  (declare (type inference inference))
  (infrnc-relevant-problems inference))

(defun inference-strategy-set (inference)
  (declare (type inference inference))
  (infrnc-strategy-set inference))

;; (defun inference-control-process (inference) ...) -- active declareFunction, no body

(defun inference-interrupting-processes (inference)
  (declare (type inference inference))
  (infrnc-interrupting-processes inference))

(defun inference-max-transformation-depth-reached (inference)
  (declare (type inference inference))
  (infrnc-max-transformation-depth-reached inference))

(defun inference-answer-language (inference)
  (declare (type inference inference))
  (infrnc-answer-language inference))

(defun inference-cache-results? (inference)
  (declare (type inference inference))
  (infrnc-cache-results? inference))

(defun inference-blocking? (inference)
  (declare (type inference inference))
  (infrnc-blocking? inference))

(defun inference-disjunction-free-el-vars-policy (inference)
  (declare (type inference inference))
  (infrnc-disjunction-free-el-vars-policy inference))

(defun inference-result-uniqueness-criterion (inference)
  (declare (type inference inference))
  (infrnc-result-uniqueness-criterion inference))

(defun inference-allow-hl-predicate-transformation? (inference)
  (declare (type inference inference))
  (infrnc-allow-hl-predicate-transformation? inference))

(defun inference-allow-unbound-predicate-transformation? (inference)
  (declare (type inference inference))
  (infrnc-allow-unbound-predicate-transformation? inference))

(defun inference-allow-evaluatable-predicate-transformation? (inference)
  (declare (type inference inference))
  (infrnc-allow-evaluatable-predicate-transformation? inference))

(defun inference-allow-indeterminate-results? (inference)
  (declare (type inference inference))
  (infrnc-allow-indeterminate-results? inference))

(defun inference-allowed-rules (inference)
  (declare (type inference inference))
  (infrnc-allowed-rules inference))

(defun inference-forbidden-rules (inference)
  (declare (type inference inference))
  (infrnc-forbidden-rules inference))

(defun inference-allowed-modules (inference)
  (declare (type inference inference))
  (infrnc-allowed-modules inference))

(defun inference-allow-abnormality-checking? (inference)
  (declare (type inference inference))
  (infrnc-allow-abnormality-checking? inference))

(defun inference-transitive-closure-mode (inference)
  (declare (type inference inference))
  (infrnc-transitive-closure-mode inference))

(defun inference-problem-store-private? (inference)
  (declare (type inference inference))
  (infrnc-problem-store-private? inference))

(defun inference-continuable? (inference)
  "[Cyc] @return booleanp, whether INFERENCE was specified to be continuable."
  (declare (type inference inference))
  (infrnc-continuable? inference))

(defun inference-browsable? (inference)
  "[Cyc] @return booleanp, whether INFERENCE was specified to be browsable."
  (declare (type inference inference))
  (infrnc-browsable? inference))

(defun inference-return-type (inference)
  "[Cyc] @return inference-return-type-p, the return type of inference stored in :return."
  (declare (type inference inference))
  (infrnc-return-type inference))

(defun inference-max-time (inference)
  "[Cyc] @return nil or universal-time-p NIL indicates there is no time cutoff"
  (declare (type inference inference))
  (infrnc-max-time inference))

(defun inference-max-step (inference)
  "[Cyc] @return nil or non-negative-integer-p NIL indicates there is no step cutoff"
  (declare (type inference inference))
  (infrnc-max-step inference))

;; (defun inference-mode (inference) ...) -- active declareFunction, no body

(defun inference-forward-max-time (inference)
  "[Cyc] @return nil or universal-time-p NIL indicates there is no time cutoff"
  (declare (type inference inference))
  (infrnc-forward-max-time inference))

(defun inference-max-number (inference)
  "[Cyc] @return nil or non-negative-integer-p NIL indicates there is no number limit"
  (declare (type inference inference))
  (infrnc-max-number inference))

(defun inference-max-proof-depth (inference)
  "[Cyc] @return nil or non-negative-integer-p NIL indicates there is no limit on proof depth"
  (declare (type inference inference))
  (infrnc-max-proof-depth inference))

(defun inference-max-transformation-depth (inference)
  (declare (type inference inference))
  (infrnc-max-transformation-depth inference))

(defun inference-probably-approximately-done (inference)
  "[Cyc] @return probability-p 1 means we must be 100% sure we are done before halting"
  (declare (type inference inference))
  (infrnc-probably-approximately-done inference))

(defun inference-metrics-template (inference)
  (declare (type inference inference))
  (infrnc-metrics-template inference))

;; (defun inference-start-universal-time (inference) ...) -- active declareFunction, no body

(defun inference-start-internal-real-time (inference)
  (declare (type inference inference))
  (infrnc-start-internal-real-time inference))

(defun inference-end-internal-real-time (inference)
  (declare (type inference inference))
  (infrnc-end-internal-real-time inference))

(defun inference-pad-internal-real-time (inference)
  (declare (type inference inference))
  (infrnc-pad-internal-real-time inference))

(defun inference-cumulative-time (inference)
  "[Cyc] This is the total time spent in all of INFERENCE's previous continuations. Use @xref inference-cumulative-time-so-far if you want to include the time spent so far in the current continuation."
  (declare (type inference inference))
  (infrnc-cumulative-time inference))

;; (defun inference-step-count (inference) ...) -- active declareFunction, no body

(defun inference-cumulative-step-count (inference)
  "[Cyc] The number of inference steps performed so far for this inference, summed over all continuations"
  (declare (type inference inference))
  (infrnc-cumulative-step-count inference))

(defun inference-problem-working-time-data (inference)
  (declare (type inference inference))
  (infrnc-problem-working-time-data inference))

;; (defun inference-events (inference) ...) -- active declareFunction, no body
;; (defun inference-accumulators (inference) ...) -- active declareFunction, no body
;; (defun inference-proof-watermark (inference) ...) -- active declareFunction, no body

(defun inference-type (inference)
  (declare (type inference inference))
  (infrnc-type inference))

(defun inference-data (inference)
  (declare (type inference inference))
  (infrnc-data inference))

;;; Setters

;; (defun set-inference-forward-propagate (inference forward-propagate) ...) -- active declareFunction, no body

(defun set-inference-input-mt (inference mt)
  (declare (type inference inference))
  (setf (infrnc-input-mt inference) mt)
  inference)

(defun set-inference-input-el-query (inference el-query)
  (declare (type inference inference))
  (setf (infrnc-input-el-query inference) el-query)
  inference)

(defun set-inference-input-non-explanatory-el-query (inference el-query)
  (declare (type inference inference))
  (setf (infrnc-input-non-explanatory-el-query inference) el-query)
  inference)

(defun set-inference-input-query-properties (inference query-properties)
  (declare (type inference inference))
  (setf (infrnc-input-query-properties inference) query-properties)
  inference)

(defun set-inference-mt (inference mt)
  (declare (type inference inference))
  (setf (infrnc-mt inference) mt)
  inference)

(defun set-inference-el-query (inference el-query)
  (declare (type inference inference))
  (setf (infrnc-el-query inference) el-query)
  inference)

(defun set-inference-el-bindings (inference el-bindings)
  (declare (type inference inference))
  (declare (type list el-bindings))
  (setf (infrnc-el-bindings inference) el-bindings)
  inference)

(defun set-inference-hl-query (inference hl-query)
  (declare (type inference inference))
  (setf (infrnc-hl-query inference) hl-query)
  inference)

(defun set-inference-explanatory-subquery (inference explanatory-subquery)
  (declare (type inference inference))
  (setf (infrnc-explanatory-subquery inference) explanatory-subquery)
  inference)

(defun set-inference-non-explanatory-subquery (inference non-explanatory-subquery)
  (declare (type inference inference))
  (setf (infrnc-non-explanatory-subquery inference) non-explanatory-subquery)
  inference)

(defun set-inference-free-hl-vars (inference free-hl-vars)
  (declare (type inference inference))
  (declare (type list free-hl-vars))
  (setf (infrnc-free-hl-vars inference) free-hl-vars)
  inference)

(defun set-inference-hypothetical-bindings (inference hypothetical-bindings)
  (declare (type inference inference))
  (setf (infrnc-hypothetical-bindings inference) hypothetical-bindings)
  inference)

(defun set-inference-status (inference status)
  (declare (type inference inference))
  (setf (infrnc-status inference) status)
  (unless (inference-suspend-status-applicable? status)
    (setf (infrnc-suspend-status inference) nil))
  (possibly-signal-inference-status-change inference)
  inference)

(defun set-inference-suspend-status (inference suspend-status)
  (declare (type inference inference))
  (setf (infrnc-suspend-status inference) suspend-status)
  inference)

(defun set-inference-root-link (inference root-link)
  (declare (type inference inference))
  (setf (infrnc-root-link inference) root-link)
  inference)

(defun set-inference-control-process (inference process)
  (declare (type inference inference))
  (setf (infrnc-control-process inference) process)
  inference)

(defun set-inference-max-transformation-depth-reached (inference depth)
  (declare (type inference inference))
  (setf (infrnc-max-transformation-depth-reached inference) depth)
  inference)

(defun set-inference-disjunction-free-el-vars-policy (inference disjunction-free-el-vars-policy)
  (declare (type inference inference))
  (setf (infrnc-disjunction-free-el-vars-policy inference) disjunction-free-el-vars-policy)
  inference)

(defun set-inference-result-uniqueness-criterion (inference criterion)
  (declare (type inference inference))
  (setf (infrnc-result-uniqueness-criterion inference) criterion)
  inference)

(defun set-inference-allow-hl-predicate-transformation (inference allow?)
  (declare (type inference inference))
  (setf (infrnc-allow-hl-predicate-transformation? inference) allow?)
  inference)

(defun set-inference-allow-unbound-predicate-transformation (inference allow?)
  (declare (type inference inference))
  (setf (infrnc-allow-unbound-predicate-transformation? inference) allow?)
  inference)

(defun set-inference-allow-evaluatable-predicate-transformation (inference allow?)
  (declare (type inference inference))
  (setf (infrnc-allow-evaluatable-predicate-transformation? inference) allow?)
  inference)

(defun set-inference-allow-indeterminate-results (inference allow?)
  (declare (type inference inference))
  (setf (infrnc-allow-indeterminate-results? inference) allow?)
  inference)

(defun set-inference-allowed-rules (inference allowed-rules)
  (declare (type inference inference))
  (setf (infrnc-allowed-rules inference) allowed-rules)
  inference)

(defun set-inference-forbidden-rules (inference forbidden-rules)
  (declare (type inference inference))
  (setf (infrnc-forbidden-rules inference) forbidden-rules)
  inference)

(defun set-inference-allowed-modules (inference allowed-modules)
  (declare (type inference inference))
  (setf (infrnc-allowed-modules inference) allowed-modules)
  inference)

(defun set-inference-allow-abnormality-checking (inference allow?)
  (declare (type inference inference))
  (setf (infrnc-allow-abnormality-checking? inference) allow?)
  inference)

(defun set-inference-transitive-closure-mode (inference transitive-closure-mode)
  (declare (type inference inference))
  (setf (infrnc-transitive-closure-mode inference) transitive-closure-mode)
  inference)

(defun set-inference-problem-store-private (inference private?)
  (declare (type inference inference))
  (setf (infrnc-problem-store-private? inference) private?)
  inference)

(defun set-inference-continuable (inference continuable?)
  (setf (infrnc-continuable? inference) continuable?)
  inference)

(defun set-inference-browsable (inference browsable?)
  (setf (infrnc-browsable? inference) browsable?)
  inference)

(defun set-inference-return-type (inference return-type)
  (setf (infrnc-return-type inference) return-type)
  inference)

(defun set-inference-answer-language (inference answer-language)
  (declare (type inference inference))
  (setf (infrnc-answer-language inference) answer-language)
  inference)

(defun set-inference-cache-results (inference cache-results?)
  (declare (type inference inference))
  (setf (infrnc-cache-results? inference) cache-results?)
  inference)

;; (defun note-inference-blocking (inference) ...) -- active declareFunction, no body

(defun clear-inference-blocking (inference)
  (declare (type inference inference))
  (setf (infrnc-blocking? inference) nil)
  inference)

(defun set-inference-max-number (inference max-number)
  (setf (infrnc-max-number inference) max-number)
  inference)

(defun set-inference-max-time (inference max-time)
  (setf (infrnc-max-time inference) max-time)
  inference)

(defun set-inference-max-step (inference max-step)
  (setf (infrnc-max-step inference) max-step)
  inference)

(defun set-inference-mode (inference mode)
  (setf (infrnc-mode inference) mode)
  inference)

(defun set-inference-forward-max-time (inference forward-max-time)
  (let ((max-time (inference-max-time inference)))
    (when (and (integerp max-time)
               (integerp forward-max-time)
               (< max-time forward-max-time))
      (error "Forward max time ~s cannot be greater than max time ~s"
             forward-max-time max-time)))
  (setf (infrnc-forward-max-time inference) forward-max-time)
  inference)

(defun set-inference-max-proof-depth (inference max-proof-depth)
  (setf (infrnc-max-proof-depth inference) max-proof-depth)
  inference)

(defun set-inference-max-transformation-depth (inference max-transformation-depth)
  (setf (infrnc-max-transformation-depth inference) max-transformation-depth)
  inference)

(defun set-inference-probably-approximately-done (inference probability)
  (setf (infrnc-probably-approximately-done inference) probability)
  inference)

(defun set-inference-metrics-template (inference metrics-template)
  (setf (infrnc-metrics-template inference) metrics-template)
  inference)

(defun set-inference-start-universal-time (inference universal-time)
  (declare (type inference inference))
  (setf (infrnc-start-universal-time inference) universal-time)
  inference)

(defun set-inference-start-internal-real-time (inference internal-real-time)
  (declare (type inference inference))
  (setf (infrnc-start-internal-real-time inference) internal-real-time)
  inference)

(defun set-inference-end-internal-real-time (inference end-internal-real-time)
  (declare (type inference inference))
  (setf (infrnc-end-internal-real-time inference) end-internal-real-time)
  inference)

(defun set-inference-pad-internal-real-time (inference pad-internal-real-time)
  (declare (type inference inference))
  (setf (infrnc-pad-internal-real-time inference) pad-internal-real-time)
  inference)

(defun set-inference-cumulative-time (inference cumulative-time)
  (declare (type inference inference))
  (setf (infrnc-cumulative-time inference) cumulative-time)
  inference)

(defun set-inference-step-count (inference step-count)
  (setf (infrnc-step-count inference) step-count)
  inference)

(defun increment-inference-step-count (inference)
  (setf (infrnc-step-count inference)
        (+ (infrnc-step-count inference) 1))
  inference)

(defun set-inference-cumulative-step-count (inference cumulative-step-count)
  (setf (infrnc-cumulative-step-count inference) cumulative-step-count)
  inference)

(defun increment-inference-cumulative-step-count (inference)
  (setf (infrnc-cumulative-step-count inference)
        (+ (infrnc-cumulative-step-count inference) 1))
  inference)

;; (defun set-inference-problem-working-time-data (inference data) ...) -- active declareFunction, no body

(defun set-inference-events (inference event-types)
  (declare (type inference inference))
  (setf (infrnc-events inference) event-types)
  inference)

(defun set-inference-halt-conditions (inference halt-conditions)
  (declare (type inference inference))
  (setf (infrnc-halt-conditions inference) halt-conditions)
  inference)

(defun set-inference-type (inference type)
  (declare (type inference inference))
  (setf (infrnc-type inference) type)
  inference)

;; (defun set-inference-data (inference data) ...) -- active declareFunction, no body

;;; Derived accessors and queries

(defun inference-ids (inference)
  (declare (type inference inference))
  (list (missing-larkc 35773)
        (inference-suid inference)))

;; (defun inference-problem-store-suid (inference) ...) -- active declareFunction, no body
;; (defun all-inferences () ...) -- active declareFunction, no body
;; (defun inference-strategies (inference) ...) -- active declareFunction, no body
;; (defun inference-hl-mts (inference) ...) -- active declareFunction, no body
;; (defun inference-first-hl-query-mt (inference) ...) -- active declareFunction, no body

(defun inference-no-free-hl-vars? (inference)
  (null (inference-free-hl-vars inference)))

(defun inference-free-el-vars (inference)
  (let ((el-bindings (inference-el-bindings inference))
        (free-hl-vars (inference-free-hl-vars inference)))
    (apply-bindings-backwards el-bindings free-hl-vars)))

;; (defun inference-input-query-property (inference property &optional default) ...) -- active declareFunction, no body
;; (defun inference-to-new-cyc-query-arguments (inference) ...) -- active declareFunction, no body
;; (defun inference-to-new-cyc-query-form (inference) ...) -- active declareFunction, no body
;; (defun inference-to-new-cyc-query-form-string (inference) ...) -- active declareFunction, no body
;; (defun inference-args-to-new-cyc-query-form-string (mt query properties) ...) -- active declareFunction, no body

(defun inference-root-mapped-problem (inference)
  (let ((root-link (inference-root-link inference)))
    (when root-link
      (answer-link-supporting-mapped-problem root-link))))

(defun inference-root-problem (inference)
  (let ((root-mapped-problem (inference-root-mapped-problem inference)))
    (when root-mapped-problem
      (mapped-problem-problem root-mapped-problem))))

;; (defun inference-unique-wrt-proofs? (inference) ...) -- active declareFunction, no body

(defun inference-unique-wrt-bindings? (inference)
  (eq :bindings (inference-result-uniqueness-criterion inference)))

(defun inference-compute-answer-justifications? (inference)
  (problem-store-compute-answer-justifications? (inference-problem-store inference)))

;; (defun inference-computes-metrics? (inference) ...) -- active declareFunction, no body
;; (defun inference-computes-metric? (inference metric) ...) -- active declareFunction, no body

(defun inference-problem-store-private-wrt-dynamic-properties? (inference)
  "[Cyc] Return T iff INFERENCE not only has a private problem store, but the current set of dynamic properties will never be extended."
  (and (inference-problem-store-private? inference)
       (not (inference-continuable? inference))))

;; (defun inference-dynamic-properties-exhaustive? (inference) ...) -- active declareFunction, no body

(defun inference-allows-use-of-all-rules? (inference)
  (and (eq :all (inference-allowed-rules inference))
       (eq :none (inference-forbidden-rules inference))))

(defun inference-allows-use-of-rule? (inference rule)
  (cond ((inference-allows-use-of-all-rules? inference) t)
        ((eq :none (inference-forbidden-rules inference))
         (set-member? rule (inference-allowed-rules inference)))
        ((eq :all (inference-allowed-rules inference))
         (not (set-member? rule (inference-forbidden-rules inference))))
        (t nil)))

;; (defun inference-filter-rules (inference rules) ...) -- active declareFunction, no body

(defun inference-allows-use-of-all-modules? (inference)
  (eq :all (inference-allowed-modules inference)))

(defun inference-allows-use-of-module? (inference hl-module)
  (or (inference-allows-use-of-all-modules? inference)
      ;; Likely checks if hl-module is in the allowed-modules spec
      (missing-larkc 36412)))

(defun inference-forget-extra-results? (inference)
  (inference-properties-forget-extra-results? (inference-input-query-properties inference)))

(defun inference-has-some-answer? (inference)
  (let ((v-id-index (inference-answer-id-index inference)))
    (plusp (id-index-count v-id-index))))

(defun find-inference-answer-by-id (inference id)
  (let ((v-id-index (inference-answer-id-index inference)))
    (id-index-lookup v-id-index id)))

;; (defun find-inference-answer-by-ids (store-id inference-id answer-id) ...) -- active declareFunction, no body
;; (defun inference-first-answer (inference) ...) -- active declareFunction, no body
;; (defun inference-last-answer (inference) ...) -- active declareFunction, no body
;; (defun inference-first-answer-elapsed-time (inference) ...) -- active declareFunction, no body
;; (defun inference-first-answer-step-count (inference) ...) -- active declareFunction, no body
;; (defun inference-last-answer-elapsed-time (inference) ...) -- active declareFunction, no body
;; (defun inference-last-answer-step-count (inference) ...) -- active declareFunction, no body
;; (defun inference-answer-count-at-elapsed-time (inference elapsed-time) ...) -- active declareFunction, no body
;; (defun inference-answer-count-at-30-seconds (inference) ...) -- active declareFunction, no body
;; (defun inference-answer-count-at-60-seconds (inference) ...) -- active declareFunction, no body
;; (defun inference-answer-times (inference) ...) -- active declareFunction, no body
;; (defun inference-answer-step-counts (inference) ...) -- active declareFunction, no body
;; (defun inference-end-universal-time (inference) ...) -- active declareFunction, no body

(defun inference-maintain-term-working-set? (inference)
  (declare (type inference inference))
  (and (inference-problem-working-time-data inference) t))

(defun inference-halt-condition-present? (inference halt-condition)
  (declare (type inference inference))
  (member-eq? halt-condition (infrnc-halt-conditions inference)))

;; (defun add-inference-accumulator (inference key value) ...) -- active declareFunction, no body
;; (defun inference-accumulator (inference key) ...) -- active declareFunction, no body
;; (defun inference-accumulator-contents (inference key) ...) -- active declareFunction, no body
;; (defun inference-accumulate (inference key value) ...) -- active declareFunction, no body
;; (defun set-inference-proof-watermark (inference watermark) ...) -- active declareFunction, no body

(defun compute-inference-pad-internal-real-time (inference)
  (let ((pad-probability (inference-probably-approximately-done inference))
        (pad-seconds (probably-approximately-done-cutoff-time pad-probability)))
    (if (positive-infinity-p pad-seconds)
        (positive-infinity)
        (let* ((pad-seconds-remaining (- pad-seconds (inference-cumulative-time inference)))
               (start-time (inference-start-internal-real-time inference))
               ;; Likely computes start-time + pad-seconds-remaining * internal-time-units-per-second
               (pad-time (missing-larkc 23122)))
          pad-time))))

(deflexical *pad-times-to-first-answer*
  (if (and (boundp '*pad-times-to-first-answer*)
           (not (eq *pad-times-to-first-answer* :uninitialized)))
      *pad-times-to-first-answer*
      :uninitialized))

(defun initialize-pad-table (filename)
  (let ((scaled-times-to-first-answer (scale-by-bogomips
                                       *non-tkb-final-times-to-first-answer*
                                       *non-tkb-final-bogomips*)))
    (setf *pad-times-to-first-answer* scaled-times-to-first-answer))
  (length *pad-times-to-first-answer*))

;; (defun pad-table-initialized? () ...) -- active declareFunction, no body

(defun probably-approximately-done-cutoff-time (probability)
  "[Cyc] @return positive-potentially-infinite-number-p (seconds or :positive-infinity)"
  (if (or (safe-= 1 probability)
          ;; Likely checks if pad table is initialized
          (not (missing-larkc 35784)))
      :positive-infinity
      ;; Likely computes cutoff from pad table
      (missing-larkc 31738)))

;; (defun compute-pad-from-time (time) ...) -- active declareFunction, no body

(defun inference-note-transformation-depth (inference depth)
  (let ((max-transformation-depth-reached (inference-max-transformation-depth-reached inference)))
    (when (> depth max-transformation-depth-reached)
      (inference-note-new-transformation-depth-reached inference depth))))

(defun inference-note-new-transformation-depth-reached (inference depth)
  (set-inference-max-transformation-depth-reached inference depth)
  (possibly-signal-inference-new-transformation-depth-reached inference depth)
  (when (inference-halt-condition-present? inference :look-no-deeper-for-additional-answers)
    (when (positive-integer-p (inference-answer-count inference))
      (set-inference-suspend-status inference :look-no-deeper-for-additional-answers)
      :look-no-deeper-for-additional-answers)))

(defun find-inference-answer-by-bindings (inference v-bindings)
  (let ((dict (inference-answer-bindings-index inference)))
    (gethash v-bindings dict)))

(defun new-inference-answer-id (inference)
  (let ((v-id-index (inference-answer-id-index inference)))
    (id-index-reserve v-id-index)))

(defun inference-all-answers (inference)
  (let ((answers nil)
        (idx (inference-answer-id-index inference)))
    (when (not (id-index-objects-empty-p idx :skip))
      (do-id-index (id answer idx)
        (push answer answers)))
    (nreverse answers)))

(defun inference-all-new-answers (inference)
  (let ((answers nil)
        (inf inference)
        (start-id (inference-new-answer-id-start inference))
        (end-id (inference-next-new-answer-id inference)))
    (do ((id start-id (1+ id)))
        ((>= id end-id))
      (let ((answer (find-inference-answer-by-id inf id)))
        (must (answer) "got a null answer for ~s" inference)
        (push answer answers)))
    (nreverse answers)))

;; (defun inference-allowed-rules-list (inference) ...) -- active declareFunction, no body
;; (defun inference-allowed-rule-count (inference) ...) -- active declareFunction, no body
;; (defun inference-forbidden-rules-list (inference) ...) -- active declareFunction, no body
;; (defun inference-forbidden-rule-count (inference) ...) -- active declareFunction, no body

(defun inference-interrupt-signaled? (inference)
  (not (queue-empty-p (inference-interrupting-processes inference))))

;; (defun inference-no-interrupt-signaled? (inference) ...) -- active declareFunction, no body
;; (defun inference-interrupt-handled? (inference) ...) -- active declareFunction, no body

(defun inference-answer-count (inference)
  (id-index-count (inference-answer-id-index inference)))

;; (defun inference-new-answer-count (inference) ...) -- active declareFunction, no body
;; (defun inference-new-justification-count (inference) ...) -- active declareFunction, no body
;; (defun inference-new-result-count (inference) ...) -- active declareFunction, no body

(defun forward-inference-p (inference)
  (and (inference-p inference)
       (problem-store-forward? (inference-problem-store inference))))

;; (defun backward-inference-p (inference) ...) -- active declareFunction, no body

(defun abductive-inference-p (inference)
  (and (inference-p inference)
       (problem-store-abduction-allowed? (inference-problem-store inference))))

;; (defun inference-provability-status (inference) ...) -- active declareFunction, no body
;; (defun good-inference-p (inference) ...) -- active declareFunction, no body
;; (defun neutral-inference-p (inference) ...) -- active declareFunction, no body
;; (defun no-good-inference-p (inference) ...) -- active declareFunction, no body
;; (defun closed-inference-p (inference) ...) -- active declareFunction, no body

;;; Static and dynamic property setting

(defun inference-set-static-properties (inference static-properties)
  (let ((disjunction-free-el-vars-policy
          (inference-properties-disjunction-free-el-vars-policy static-properties)))
    (set-inference-disjunction-free-el-vars-policy inference disjunction-free-el-vars-policy))
  (let ((uniqueness-criterion
          (inference-properties-uniqueness-criterion static-properties)))
    (set-inference-result-uniqueness-criterion inference uniqueness-criterion))
  (let ((allow-hl-predicate-transformation?
          (inference-properties-allow-hl-predicate-transformation? static-properties)))
    (set-inference-allow-hl-predicate-transformation inference allow-hl-predicate-transformation?))
  (let ((allow-unbound-predicate-transformation?
          (inference-properties-allow-unbound-predicate-transformation? static-properties)))
    (set-inference-allow-unbound-predicate-transformation inference allow-unbound-predicate-transformation?))
  (let ((allow-evaluatable-predicate-transformation?
          (inference-properties-allow-evaluatable-predicate-transformation? static-properties)))
    (set-inference-allow-evaluatable-predicate-transformation inference allow-evaluatable-predicate-transformation?))
  (let ((allow-indeterminate-results?
          (inference-properties-allow-indeterminate-results? static-properties)))
    (set-inference-allow-indeterminate-results inference allow-indeterminate-results?))
  (let ((allowed-rules (inference-properties-allowed-rules static-properties)))
    (if (eq :all allowed-rules)
        (set-inference-allowed-rules inference :all)
        (set-inference-allowed-rules inference
                                     (construct-set-from-list allowed-rules #'eq))))
  (let ((forbidden-rules (inference-properties-forbidden-rules static-properties)))
    (if (eq :none forbidden-rules)
        (set-inference-forbidden-rules inference :none)
        (set-inference-forbidden-rules inference
                                       (construct-set-from-list forbidden-rules #'eq))))
  (let ((allowed-modules (inference-properties-allowed-modules static-properties)))
    (set-inference-allowed-modules inference allowed-modules))
  (let ((allow-abnormality-checking?
          (inference-properties-allow-abnormality-checking? static-properties)))
    (set-inference-allow-abnormality-checking inference allow-abnormality-checking?))
  (let ((transitive-closure-mode
          (inference-properties-transitive-closure-mode static-properties)))
    (set-inference-transitive-closure-mode inference transitive-closure-mode))
  (let ((maintain-term-working-set?
          (inference-properties-maintain-term-working-set? static-properties)))
    (when maintain-term-working-set?
      ;; Likely initializes inference-problem-working-time-data
      (missing-larkc 35782)))
  (let ((events (inference-properties-events static-properties)))
    (set-inference-events inference events))
  (let ((halt-conditions (inference-properties-halt-conditions static-properties)))
    (set-inference-halt-conditions inference halt-conditions))
  inference)

(defun update-inference-input-query-properties (inference input-dynamic-properties)
  (let* ((input-query-properties (infrnc-input-query-properties inference))
         (static-mode (inference-properties-mode input-query-properties))
         (dynamic-mode (inference-properties-mode input-dynamic-properties))
         (mode-mismatch? (not (eq static-mode dynamic-mode))))
    (when mode-mismatch?
      (setf input-query-properties
            (extract-query-static-properties
             (explicify-inference-mode-defaults input-query-properties)))
      (setf input-query-properties
            (putf input-query-properties :inference-mode dynamic-mode))
      ;; Likely merges properties
      (setf input-query-properties (missing-larkc 35555)))
    (do ((remainder input-dynamic-properties (cddr remainder)))
        ((null remainder))
      (let ((property (first remainder))
            (value (second remainder)))
        (setf input-query-properties
              (putf input-query-properties property value))))
    (set-inference-input-query-properties inference input-query-properties))
  nil)

;;; Inference relevant problems and strategies

(defun add-inference-relevant-problem (inference problem)
  (declare (type inference inference))
  (set-add problem (infrnc-relevant-problems inference))
  inference)

(defun remove-inference-relevant-problem (inference problem)
  (declare (type inference inference))
  (set-remove problem (infrnc-relevant-problems inference))
  inference)

(defun clear-inference-relevant-problems (inference)
  (declare (type inference inference))
  (clear-set (infrnc-relevant-problems inference))
  inference)

(defun add-inference-strategy (inference strategy)
  (declare (type inference inference))
  (set-add strategy (infrnc-strategy-set inference))
  inference)

;; (defun remove-inference-strategy (inference strategy) ...) -- active declareFunction, no body

(defun clear-inference-strategy-set (inference)
  (declare (type inference inference))
  (clear-set (infrnc-strategy-set inference))
  inference)

;;; Answer management

(defun reset-inference-new-answer-id (inference)
  (let ((next-id (inference-next-new-answer-id inference)))
    (setf (infrnc-new-answer-id-start inference) next-id))
  inference)

(defun inference-next-new-answer-id (inference)
  (let ((v-id-index (inference-answer-id-index inference)))
    (id-index-next-id v-id-index)))

(defun add-inference-new-answer-by-id (inference answer)
  (let ((id (inference-answer-suid answer))
        (v-id-index (inference-answer-id-index inference)))
    (id-index-enter-autoextend v-id-index id answer))
  inference)

;; (defun remove-inference-new-answer-by-id (inference answer) ...) -- active declareFunction, no body

(defun add-inference-new-answer-by-bindings (inference answer)
  (let ((v-bindings (inference-answer-bindings answer))
        (index (inference-answer-bindings-index inference)))
    (setf (gethash v-bindings index) answer))
  inference)

;; (defun remove-inference-new-answer-by-bindings (inference answer) ...) -- active declareFunction, no body

(defun reset-inference-new-answer-justifications (inference)
  (clear-queue (inference-new-answer-justifications inference))
  inference)

(defun add-inference-new-answer-justification (inference answer-justification)
  "[Cyc] Does not check for duplication with existing new justifications"
  (enqueue answer-justification (inference-new-answer-justifications inference))
  inference)

;; (defun remove-inference-new-answer-justification (inference answer-justification) ...) -- active declareFunction, no body

(defun clear-inference-control-process (inference)
  (set-inference-control-process inference nil))

(defun set-inference-control-process-to-me (inference)
  (set-inference-control-process inference (bt:current-thread)))

;; (defun note-inference-interrupt-signaled (inference process) ...) -- active declareFunction, no body

(defun increment-inference-cumulative-time (inference time-delta)
  (let ((cumulative-time (inference-cumulative-time inference)))
    (setf cumulative-time (+ cumulative-time time-delta))
    (set-inference-cumulative-time inference cumulative-time))
  inference)

;; (defun reorder-inference-free-hl-vars (inference new-ordering) ...) -- active declareFunction, no body
;; (defun reorder-inference-free-el-vars (inference new-ordering) ...) -- active declareFunction, no body

(defun reset-inference-new-answers (inference)
  (reset-inference-new-answer-id inference)
  (reset-inference-new-answer-justifications inference)
  inference)

(defun add-inference-new-answer (inference answer)
  (add-inference-new-answer-by-id inference answer)
  (add-inference-new-answer-by-bindings inference answer)
  inference)

;; (defun remove-inference-new-answer (inference answer) ...) -- active declareFunction, no body

;;; Time management

(defun initialize-inference-time-properties (inference)
  (let ((real-time-now (get-internal-real-time))
        (now (get-universal-time)))
    (set-inference-start-internal-real-time inference real-time-now)
    (set-inference-start-universal-time inference now)
    (let* ((max-time (inference-max-time inference))
           ;; Likely computes real-time-now + max-time * internal-time-units-per-second
           (end-time (when max-time (missing-larkc 23123))))
      (set-inference-end-internal-real-time inference end-time))
    (let ((pad-time (compute-inference-pad-internal-real-time inference)))
      (set-inference-pad-internal-real-time inference pad-time)))
  inference)

(defun finalize-inference-time-properties (inference)
  (let ((delta-time (inference-time-so-far inference nil)))
    (increment-inference-cumulative-time inference delta-time))
  inference)

(defun inference-elapsed-internal-real-time-since-start (inference)
  (let* ((start (inference-start-internal-real-time inference))
         (elapsed (elapsed-internal-real-time start)))
    elapsed))

;; (defun inference-elapsed-universal-time-since-start (inference) ...) -- active declareFunction, no body

(defun inference-time-so-far (inference &optional (seconds-granularity? t))
  "[Cyc] @return the time spent so far on the current continuation of this INFERENCE."
  (let ((seconds 0))
    (when (running-inference-p inference)
      (if seconds-granularity?
          ;; Likely rounds elapsed time to seconds
          (setf seconds (missing-larkc 35755))
          (let ((elapsed (inference-elapsed-internal-real-time-since-start inference)))
            (setf seconds (elapsed-internal-real-time-to-elapsed-seconds elapsed)))))
    seconds))

;; (defun inference-remaining-time (inference &optional seconds-granularity?) ...) -- active declareFunction, no body
;; (defun inference-cumulative-time-so-far (inference &optional seconds-granularity?) ...) -- active declareFunction, no body
;; (defun inference-signal-interrupt (inference) ...) -- active declareFunction, no body
;; (defun inference-handle-interrupts (inference) ...) -- active declareFunction, no body

;;; Simplest inference

(defun simplest-inference-p (object)
  (and (inference-p object)
       (eq :simplest (inference-type object))))

(defun new-simplest-inference (store)
  (declare (type problem-store store))
  (let ((inference (new-inference store)))
    (set-inference-type inference :simplest)
    inference))

(defun simplest-inference-strategy (inference)
  (inference-data inference))

(defun set-simplest-inference-strategy (inference strategy)
  (setf (infrnc-data inference) strategy)
  inference)

(defun new-simplest-inference-of-type (store strategy-type)
  (declare (type problem-store store))
  (let* ((inference (new-simplest-inference store))
         (strategy (new-strategy strategy-type inference)))
    (set-simplest-inference-strategy inference strategy)
    (clear-strategy-step-count)
    inference))

;; (defun new-simplest-inference-with-new-store (strategy-type) ...) -- active declareFunction, no body

;;; inference-answer defstruct -- 6 slots, conc-name "inf-answer-"

(defstruct (inference-answer
            (:conc-name "inf-answer-")
            (:predicate inference-answer-p))
  suid
  inference
  bindings
  justifications
  elapsed-creation-time
  step-count)

;; (defun valid-inference-answer-p (object) ...) -- active declareFunction, no body
;; (defun inference-answer-invalid-p (answer) ...) -- active declareFunction, no body
;; (defun print-inference-answer (object stream depth) ...) -- active declareFunction, no body
;; (defun sxhash-inference-answer-method (object) ...) -- active declareFunction, no body

(defun new-inference-answer (inference v-bindings)
  (declare (type inference inference))
  (let* ((answer (make-inference-answer))
         (suid (new-inference-answer-id inference)))
    (when (zerop suid)
      (increment-successful-inference-historical-count))
    (setf (inf-answer-suid answer) suid)
    (setf (inf-answer-inference answer) inference)
    (set-inference-answer-bindings answer v-bindings)
    (setf (inf-answer-justifications answer) nil)
    (initialize-inference-answer-elapsed-creation-time answer)
    (let ((step-count (inference-cumulative-step-count inference)))
      (set-inference-answer-step-count answer step-count))
    (add-inference-new-answer inference answer)
    (possibly-signal-new-inference-answer inference answer)
    answer))

(defun find-or-create-inference-answer (inference v-bindings)
  "[Cyc] @return 0 inference-answer-p
@return 1 booleanp; whether a new answer was created"
  (declare (type inference inference))
  (let ((answer (find-inference-answer-by-bindings inference v-bindings))
        (new? nil))
    (unless answer
      (setf answer (new-inference-answer inference v-bindings))
      (setf new? t))
    (values answer new?)))

;; TODO: do-inference-answer-justifications - macro declared, needs reconstruction
;; Helper: inference-answer-justifications

;; TODO: do-inference-answer-justifications-numbered - macro declared, needs reconstruction

;; (defun destroy-inference-answer (answer) ...) -- active declareFunction, no body
;; (defun destroy-inference-answer-int (answer) ...) -- active declareFunction, no body
;; (defun note-inference-answer-invalid (answer) ...) -- active declareFunction, no body

;;; Inference answer accessors

(defun inference-answer-suid (inference-answer)
  (declare (type inference-answer inference-answer))
  (inf-answer-suid inference-answer))

(defun inference-answer-inference (inference-answer)
  (declare (type inference-answer inference-answer))
  (inf-answer-inference inference-answer))

(defun inference-answer-bindings (inference-answer)
  (declare (type inference-answer inference-answer))
  (inf-answer-bindings inference-answer))

(defun inference-answer-justifications (inference-answer)
  (declare (type inference-answer inference-answer))
  (inf-answer-justifications inference-answer))

;; (defun inference-answer-elapsed-creation-time (inference-answer) ...) -- active declareFunction, no body
;; (defun inference-answer-step-count (inference-answer) ...) -- active declareFunction, no body

(defun set-inference-answer-bindings (inference-answer v-bindings)
  (setf (inf-answer-bindings inference-answer) v-bindings)
  inference-answer)

(defun set-inference-answer-elapsed-creation-time (inference-answer elapsed-creation-time)
  (setf (inf-answer-elapsed-creation-time inference-answer) elapsed-creation-time)
  inference-answer)

(defun set-inference-answer-step-count (inference-answer step-count)
  (setf (inf-answer-step-count inference-answer) step-count)
  inference-answer)

;; (defun inference-answer-problem-store (inference-answer) ...) -- active declareFunction, no body
;; (defun inference-answer-free-el-vars (inference-answer) ...) -- active declareFunction, no body
;; (defun inference-answer-elapsed-time (inference-answer &optional seconds-granularity?) ...) -- active declareFunction, no body
;; (defun inference-answer-creation-time (inference-answer) ...) -- active declareFunction, no body

(defun find-inference-answer-justification (inference-answer hl-justification)
  "[Cyc] @return nil or inference-answer-justification-p"
  (let ((existing-justifications (inference-answer-justifications inference-answer)))
    (find hl-justification existing-justifications
          :test #'justification-equal
          :key #'inference-answer-justification-supports)))

(defun inference-answer-result-bindings (answer)
  (let* ((inference (inference-answer-inference answer))
         (answer-language (inference-answer-language inference)))
    (cond ((eq :hl answer-language)
           (inference-answer-bindings answer))
          ((eq :el answer-language)
           (inference-answer-el-bindings answer))
          (t (error "~S was not an inference-answer-language-p" answer-language)))))

;; (defun inference-answer-bindings-equal? (answer1 answer2) ...) -- active declareFunction, no body
;; (defun inference-answer-new? (answer) ...) -- active declareFunction, no body
;; (defun inference-answer-< (answer1 answer2) ...) -- active declareFunction, no body
;; (defun inference-answer-el-sentence (answer) ...) -- active declareFunction, no body

(defun add-inference-answer-justification (inference-answer justification)
  (setf (inf-answer-justifications inference-answer)
        (cons justification (inf-answer-justifications inference-answer)))
  inference-answer)

;; (defun remove-inference-answer-justification (inference-answer justification) ...) -- active declareFunction, no body

(defun initialize-inference-answer-elapsed-creation-time (inference-answer)
  (let* ((inference (inference-answer-inference inference-answer))
         (start (inference-start-internal-real-time inference))
         (elapsed (elapsed-internal-real-time start)))
    (set-inference-answer-elapsed-creation-time inference-answer elapsed)
    inference-answer))

;;; inference-answer-justification defstruct -- 3 slots, conc-name "inf-ans-just-"

(defstruct (inference-answer-justification
            (:conc-name "inf-ans-just-")
            (:predicate inference-answer-justification-p))
  answer
  supports
  proofs)

;; (defun valid-inference-answer-justification-p (object) ...) -- active declareFunction, no body
;; (defun inference-answer-justification-invalid-p (justification) ...) -- active declareFunction, no body
;; (defun print-inference-answer-justification (object stream depth) ...) -- active declareFunction, no body
;; (defun sxhash-inference-answer-justification-method (object) ...) -- active declareFunction, no body
;; (defun list-of-inference-answer-justification-p (object) ...) -- active declareFunction, no body

(defun new-inference-answer-justification (answer supports)
  (let ((just (make-inference-answer-justification)))
    (setf (inf-ans-just-answer just) answer)
    (setf (inf-ans-just-supports just) supports)
    (add-inference-answer-justification answer just)
    just))

(defun find-or-create-inference-answer-justification (inference v-bindings supports)
  "[Cyc] @return 0 inference-answer-justification-p
@return 1 booleanp; whether a new justification was created"
  (declare (type inference inference))
  (let ((answer (find-or-create-inference-answer inference v-bindings))
        (justification nil)
        (new? nil))
    (setf justification (find-inference-answer-justification answer supports))
    (unless justification
      (setf justification (new-inference-answer-justification answer supports))
      (add-inference-new-answer-justification inference justification)
      (setf new? t))
    (values justification new?)))

;; (defun destroy-inference-answer-justification (justification) ...) -- active declareFunction, no body
;; (defun destroy-inference-answer-justification-int (justification) ...) -- active declareFunction, no body
;; (defun note-inference-answer-justification-invalid (justification) ...) -- active declareFunction, no body

(defun inference-answer-justification-answer (justification)
  (declare (type inference-answer-justification justification))
  (inf-ans-just-answer justification))

(defun inference-answer-justification-supports (justification)
  (declare (type inference-answer-justification justification))
  (inf-ans-just-supports justification))

;; (defun inference-answer-justification-proofs (justification) ...) -- active declareFunction, no body

;; TODO: do-inference-answer-justification-proofs - macro declared, needs reconstruction
;; Evidence: $sym481$INFERENCE, $sym482$ANSWER, $sym483$PROOF_VAR (gensyms)

;; TODO: do-proof-dependent-inference-answer-justifications - macro declared, needs reconstruction
;; Evidence: $sym489$ANSWER, $sym490$JUSTIFICATION, $sym491$PROOF (gensyms)

;; TODO: do-inference-all-subproofs - macro declared, needs reconstruction

;; (defun inference-answer-first-justification (inference-answer) ...) -- active declareFunction, no body
;; (defun inference-answer-justification-first-proof (justification) ...) -- active declareFunction, no body
;; (defun inference-first-proof (inference) ...) -- active declareFunction, no body
;; (defun inference-answer-justification-inference (justification) ...) -- active declareFunction, no body
;; (defun inference-answer-justification-store (justification) ...) -- active declareFunction, no body
;; (defun inference-answer-justification-rules (justification) ...) -- active declareFunction, no body

(defun add-inference-answer-justification-proof (justification proof)
  (setf (inf-ans-just-proofs justification)
        (cons proof (inf-ans-just-proofs justification)))
  justification)

;; (defun new-inference-answer-justification-from-proof (inference v-bindings proof) ...) -- active declareFunction, no body
;; (defun inference-answer-justification-to-tms-deduction-spec (justification tv) ...) -- active declareFunction, no body
;; (defun inference-answer-justification-to-true-tms-deduction-spec (justification) ...) -- active declareFunction, no body
;; (defun inference-answer-justification-to-false-tms-deduction-spec (justification) ...) -- active declareFunction, no body
;; (defun destroy-proof-inference-answer-justifications (proof) ...) -- active declareFunction, no body

;;; Metrics

;; (defun inference-time-per-answer (inference) ...) -- active declareFunction, no body
;; (defun inference-steps-per-answer (inference) ...) -- active declareFunction, no body
;; (defun inference-wasted-time-after-last-answer (inference) ...) -- active declareFunction, no body
;; (defun inference-latency-improvement-from-iterativity (inference) ...) -- active declareFunction, no body

(defun inference-compute-metrics (inference)
  (let* ((template (inference-metrics-template inference))
         (metrics (tree-gather template #'inference-query-metric-p))
         (answer (copy-tree template))
         (metrics-bindings (inference-compute-metrics-alist inference metrics)))
    (setf answer (nsublis metrics-bindings answer :test #'eq))
    answer))

;; (defun inference-compute-metrics-plist (inference metrics) ...) -- active declareFunction, no body

(defun inference-compute-metrics-alist (inference metrics)
  "[Cyc] Return an alist of the form (METRIC . VALUE) where METRIC is a metric in METRICS and VALUE is the result of that metric when computed on INFERENCE."
  (let ((store (inference-problem-store inference))
        (metrics-bindings nil)
        (answer-query-properties nil))
    (declare (ignore store))
    (dolist (metric metrics)
      (let ((metric-object (missing-larkc 36314)))
        (if metric-object
            (let ((result (missing-larkc 36313)))
              (push (cons metric result) metrics-bindings))
            (cond
              ((eq metric :new-root-times)
               (let ((strategy (simplest-inference-strategy inference)))
                 (when (balanced-strategy-p strategy)
                   (let ((new-root-times (missing-larkc 36521)))
                     (push (cons :new-root-times new-root-times) metrics-bindings)))))
              ((eq metric :new-root-count)
               (let ((strategy (simplest-inference-strategy inference)))
                 (when (balanced-strategy-p strategy)
                   (let ((new-root-count (missing-larkc 36520)))
                     (push (cons :new-root-count new-root-count) metrics-bindings)))))
              ((eq metric :problem-creation-times)
               (let ((problem-creation-times (missing-larkc 2781)))
                 (push (cons :problem-creation-times problem-creation-times) metrics-bindings)))
              ((eq metric :inference-answer-query-properties)
               (unless answer-query-properties
                 (setf answer-query-properties (missing-larkc 35138)))
               (push (cons :inference-answer-query-properties answer-query-properties) metrics-bindings))
              ((eq metric :inference-strongest-query-properties)
               (unless answer-query-properties
                 (setf answer-query-properties (missing-larkc 35139)))
               (when answer-query-properties
                 (push (cons :inference-strongest-query-properties
                             (missing-larkc 35129))
                       metrics-bindings)))
              ((eq metric :inference-most-efficient-query-properties)
               (let ((proof-query-properties (missing-larkc 35141))
                     (strengthened-properties (missing-larkc 35130)))
                 (declare (ignore proof-query-properties))
                 (push (cons :inference-most-efficient-query-properties
                             strengthened-properties)
                       metrics-bindings)))
              (t (break "time to implement metric ~S" metric))))))
    metrics-bindings))

;; (defun inference-transformation-rules-in-answers (inference) ...) -- active declareFunction, no body
;; (defun inference-all-answer-proofs (inference) ...) -- active declareFunction, no body
;; (defun inference-all-answer-subproofs (inference) ...) -- active declareFunction, no body
;; (defun inference-all-answer-modules (inference) ...) -- active declareFunction, no body
;; (defun problem-relevant-to-some-strategy? (problem) ...) -- active declareFunction, no body
;; (defun first-problem-relevant-strategy (problem) ...) -- active declareFunction, no body
;; (defun problem-or-inference-p (object) ...) -- active declareFunction, no body

;; TODO: with-inference-problem-working-time-table - macro declared, needs reconstruction

(defun inference-problem-working-time-lock (inference)
  (let ((data (inference-problem-working-time-data inference)))
    (first data)))

;; (defun inference-problem-working-time-table (inference) ...) -- active declareFunction, no body
;; (defun initialize-inference-problem-working-time-data (inference) ...) -- active declareFunction, no body

(defun inference-note-tactic-executed (inference tactic)
  (let ((result nil))
    (when (inference-maintain-term-working-set? inference)
      (let ((problem (tactic-problem tactic))
            (now (get-internal-real-time))
            (lock (inference-problem-working-time-lock inference)))
        (bt:with-lock-held (lock)
          (let ((table (missing-larkc 35774)))
            (let ((already-being-worked-on (gethash problem table)))
              (unless already-being-worked-on
                (setf (gethash problem table) now)
                (setf result t)))))))
    result))

(defun inference-note-problem-pending (inference problem)
  (let ((result nil))
    (when (inference-maintain-term-working-set? inference)
      (let ((lock (inference-problem-working-time-lock inference)))
        (bt:with-lock-held (lock)
          (let ((table (missing-larkc 35775)))
            (remhash problem table)
            (setf result t)))))
    result))

;; (defun signal-inference-event? (inference event-type) ...) -- active declareFunction, no body

(defun possibly-signal-new-inference-answer (inference new-answer)
  "[Cyc] Called immediately after the creation of NEW-ANSWER"
  (declare (ignore inference new-answer))
  nil)

(defun possibly-signal-inference-status-change (inference)
  "[Cyc] Called immediately after the status change"
  (declare (ignore inference))
  nil)

(defun possibly-signal-inference-new-transformation-depth-reached (inference new-depth)
  (declare (ignore inference new-depth))
  nil)

;; TODO: inference-within-sksi-query-execution - macro declared, needs reconstruction
;; Helpers: possibly-signal-sksi-query-start, possibly-signal-sksi-query-end,
;;          possibly-increment-inference-sksi-query-total-time,
;;          possibly-add-inference-sksi-query-start-time

;; (defun possibly-signal-sksi-query-start (inference tactic) ...) -- active declareFunction, no body
;; (defun possibly-signal-sksi-query-end (inference tactic) ...) -- active declareFunction, no body
;; (defun possibly-increment-inference-sksi-query-total-time (inference tactic) ...) -- active declareFunction, no body
;; (defun possibly-add-inference-sksi-query-start-time (inference tactic) ...) -- active declareFunction, no body
;; (defun possibly-signal-sksi-query (inference tactic event &optional data) ...) -- active declareFunction, no body

;; TODO: inference-within-sparql-query-execution - macro declared, needs reconstruction
;; Helper: possibly-add-inference-sparql-query-profile

;; (defun possibly-add-inference-sparql-query-profile (inference source-module sql elapsed-time) ...) -- active declareFunction, no body
;; (defun increment-inference-sksi-query-total-time (inference time-delta) ...) -- active declareFunction, no body
;; (defun add-inference-sksi-query-start-time (inference start-time) ...) -- active declareFunction, no body
;; (defun add-inference-sparql-query-profile (inference profile) ...) -- active declareFunction, no body

;;; Setup-phase toplevel forms

(toplevel
  (register-macro-helper 'inference-answer-id-index 'do-inference-answers)
  (register-macro-helper 'inference-new-answer-id-start 'do-inference-new-answers)
  (register-macro-helper 'inference-new-answer-justifications 'do-inference-new-answer-justifications)
  (register-macro-helper 'inference-next-new-answer-id 'do-inference-new-answers)
  (register-macro-helper 'inference-answer-justifications 'do-inference-answer-justifications)
  (register-macro-helper 'inference-problem-working-time-lock 'with-inference-problem-working-time-lock)
  (register-macro-helper 'possibly-signal-sksi-query-start 'inference-within-sksi-query-execution)
  (register-macro-helper 'possibly-signal-sksi-query-end 'inference-within-sksi-query-execution)
  (register-macro-helper 'possibly-increment-inference-sksi-query-total-time 'inference-within-sksi-query-execution)
  (register-macro-helper 'possibly-add-inference-sksi-query-start-time 'inference-within-sksi-query-execution)
  (register-macro-helper 'possibly-add-inference-sparql-query-profile 'inference-within-sparql-query-execution)
  (register-external-symbol 'inference-answer-el-sentence)
  (declare-defglobal '*pad-times-to-first-answer*))
