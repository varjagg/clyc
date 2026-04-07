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

(defvar *new-cyc-trivial-query-enabled?* t
  "[Cyc] Temporary control variable. When non-nil, new-cyc-query uses
new-cyc-trivial-query-int for trivial queries. Eventually should stay T.")

;; (defun new-browsable-cyc-query (sentence &optional mt query-properties) ...) -- active declareFunction, no body
;; (defun new-browsable-cyc-query-from-dnf (dnf mt &optional scoped-vars query-properties) ...) -- active declareFunction, no body

(defun new-cyc-query (sentence &optional mt query-properties)
  "[Cyc] Creates, runs, and destroys an inference.  Returns the results,
whose format is specified by the :return property of QUERY-PROPERTIES.
If :problem-store is specified in QUERY-PROPERTIES, uses that store,
otherwise creates a new one and destroys it afterwards.
@param QUERY-PROPERTIES query-properties-p; see the definition of
  query-properties-p for explanations of all query properties.
@return 0 results, format specified by :return property
@return 1 query-halt-reason-p, why the query halted
@return 2 nil or inference-p; the inference object used to carry out
this inference, if the inference was specified to be :continuable?
or :browsable?.  This inference object can be examined or continued.
One example use of the inference object is for sharing a problem store;
one can extract the problem store from the inference
 (@see inference-problem-store), and then start a new cyc query passing
in the :problem-store property with the value you got from the first
inference.  Don't forget to @xref destroy-problem-store when you're done.
@return 3 metrics, format specified by :metrics property"
  (let ((result nil)
        (halt-reason nil)
        (inference nil)
        (metrics nil)
        (timing-info nil)
        (timing-info-1 nil)
        (clock-time nil)
        (time-var (get-internal-real-time)))
    (let ((resource-tracking-env-var (get-internal-real-time)))
      (let ((*janus-within-something?* t))
        (catch-inference-abort halt-reason
          (when *new-cyc-trivial-query-enabled?*
            (multiple-value-setq (result halt-reason metrics)
              (new-cyc-trivial-query-int sentence mt query-properties)))
          (when (or (not *new-cyc-trivial-query-enabled?*)
                    (eq :non-trivial halt-reason))
            (let* ((input-query-properties (copy-list query-properties))
                   (input-static-properties (extract-query-static-properties input-query-properties))
                   (input-dynamic-properties (extract-query-dynamic-properties input-query-properties))
                   (overridden-query-properties (explicify-inference-mode-defaults query-properties))
                   (query-static-properties (extract-query-static-properties overridden-query-properties))
                   (query-dynamic-properties (extract-query-dynamic-properties overridden-query-properties))
                   (problem-store-private? (null (inference-properties-problem-store query-static-properties))))
              (setf inference (new-continuable-inference-int sentence mt input-static-properties query-static-properties))
              (set-inference-input-query-properties inference input-query-properties)
              (possibly-set-kbq-runstate-inference inference)
              (multiple-value-setq (result halt-reason inference metrics)
                (new-cyc-query-int inference input-dynamic-properties query-dynamic-properties problem-store-private?))))))
      (janus-note-query-finished sentence mt query-properties result halt-reason)
      (setf timing-info-1 (compute-with-process-resource-tracking-results resource-tracking-env-var)))
    (setf clock-time (/ (- (get-internal-real-time) time-var) internal-time-units-per-second))
    (setf timing-info (convert-process-resource-tracking-timing-info-to-seconds
                        (nadd-clock-time-to-process-resource-timing-info clock-time timing-info-1)))
    (setf metrics (update-query-metrics-wrt-timing-info metrics timing-info))
    (values result halt-reason inference metrics)))

(defun update-query-metrics-wrt-timing-info (metrics timing-info)
  (when metrics
    (let (;; Likely extracts user time from timing-info
          (complete-user-time (missing-larkc 10258))
          ;; Likely extracts system time from timing-info
          (complete-system-time (missing-larkc 10257))
          ;; Likely extracts total time from timing-info
          (complete-total-time (missing-larkc 10259)))
      (setf metrics (nsubstitute complete-user-time :complete-user-time metrics))
      (setf metrics (nsubstitute complete-system-time :complete-system-time metrics))
      (setf metrics (nsubstitute complete-total-time :complete-total-time metrics))))
  metrics)

(defun new-cyc-query-from-dnf (dnf mt &optional scoped-vars query-properties)
  "[Cyc] Like @xref new-cyc-query except skips the canonicalization step by taking a
canonicalized DNF as input.
@param SCOPED-VARS; the variables assumed to be scoped (i.e. not free) in DNF.
@param QUERY-PROPERTIES query-properties-p; see the definition of
  query-properties-p for explanations of all query properties."
  (declare (type list scoped-vars))
  (let ((result nil)
        (halt-reason nil)
        (inference nil)
        (metrics nil)
        (timing-info nil)
        (timing-info-1 nil)
        (clock-time nil)
        (time-var (get-internal-real-time)))
    (let ((resource-tracking-env-var (get-internal-real-time)))
      (catch-inference-abort halt-reason
        (when *new-cyc-trivial-query-enabled?*
          (multiple-value-setq (result halt-reason metrics)
            (new-cyc-trivial-query-from-dnf-int dnf mt scoped-vars query-properties)))
        (when (or (not *new-cyc-trivial-query-enabled?*)
                  (eq :non-trivial halt-reason))
          (let* ((input-query-properties (copy-list query-properties))
                 (input-static-properties (extract-query-static-properties input-query-properties))
                 (input-dynamic-properties (extract-query-dynamic-properties input-query-properties))
                 (overridden-query-properties (explicify-inference-mode-defaults query-properties))
                 (query-static-properties (extract-query-static-properties overridden-query-properties))
                 (query-dynamic-properties (extract-query-dynamic-properties overridden-query-properties))
                 (problem-store-private? (null (inference-properties-problem-store query-static-properties))))
            (setf inference (new-continuable-inference-from-dnf-int dnf mt scoped-vars input-static-properties query-static-properties))
            (set-inference-input-query-properties inference input-query-properties)
            (multiple-value-setq (result halt-reason inference metrics)
              (new-cyc-query-int inference input-dynamic-properties query-dynamic-properties problem-store-private?)))))
      (setf timing-info-1 (compute-with-process-resource-tracking-results resource-tracking-env-var)))
    (setf clock-time (/ (- (get-internal-real-time) time-var) internal-time-units-per-second))
    (setf timing-info (convert-process-resource-tracking-timing-info-to-seconds
                        (nadd-clock-time-to-process-resource-timing-info clock-time timing-info-1)))
    (setf metrics (update-query-metrics-wrt-timing-info metrics timing-info))
    (values result halt-reason inference metrics)))

(defun new-cyc-query-int (inference input-dynamic-properties query-dynamic-properties problem-store-private?)
  (let* ((inference-dynamic-properties (extract-inference-dynamic-properties query-dynamic-properties))
         (destroy-store? (and problem-store-private?
                              (not (inference-properties-browsable? inference-dynamic-properties))))
         (browsable? (inference-properties-browsable? inference-dynamic-properties)))
    (when destroy-store?
      (let ((store (inference-problem-store inference)))
        (note-problem-store-destruction-imminent store)))
    (let ((results nil)
          (halt-reason nil)
          (continued-inference nil)
          (metrics nil))
      (if (continuable-inference-p inference)
          (multiple-value-setq (results halt-reason continued-inference metrics)
            (continue-inference-int inference input-dynamic-properties query-dynamic-properties))
          (multiple-value-setq (results halt-reason metrics)
            ;; Likely runs the inference as a non-continuable query
            (missing-larkc 36247)))
      (let ((inference-problem-store (inference-problem-store inference))
            (destroy-inference? (not browsable?)))
        (when destroy-inference?
          (destroy-inference inference))
        (when destroy-store?
          (destroy-problem-store inference-problem-store)))
      (if browsable?
          (values results halt-reason inference metrics)
          (values results halt-reason nil metrics)))))

;; (defun new-continuable-inference (sentence &optional mt query-properties) ...) -- active declareFunction, no body

(defun new-continuable-inference-int (sentence &optional mt input-static-properties query-static-properties)
  (multiple-value-bind (inference-static-properties non-explanatory-sentence problem-store-private? store)
      (extract-some-inference-properties query-static-properties)
    (let* ((hypothesize? (getf inference-static-properties :conditional-sentence?))
           (disjunction-free-el-vars-policy (inference-properties-disjunction-free-el-vars-policy inference-static-properties))
           (strategy-type (strategy-type-from-sentence-and-static-properties sentence mt query-static-properties))
           (inference (simplest-inference-prepare-new store sentence mt strategy-type disjunction-free-el-vars-policy hypothesize? non-explanatory-sentence problem-store-private?)))
      (initialize-inference-properties inference input-static-properties inference-static-properties query-static-properties)
      inference)))

;; (defun new-continuable-inference-from-dnf (dnf mt &optional scoped-vars query-properties) ...) -- active declareFunction, no body

(defun new-continuable-inference-from-dnf-int (dnf mt scoped-vars input-static-properties query-static-properties)
  (multiple-value-bind (inference-static-properties non-explanatory-sentence problem-store-private? store)
      (extract-some-inference-properties query-static-properties)
    (let* ((strategy-type (strategy-type-from-dnf-and-static-properties dnf mt query-static-properties))
           (inference (simplest-inference-prepare-new-from-dnf store dnf mt strategy-type scoped-vars non-explanatory-sentence problem-store-private?)))
      (initialize-inference-properties inference input-static-properties inference-static-properties query-static-properties)
      inference)))

(defun extract-some-inference-properties (query-static-properties)
  (let* ((inference-static-properties (extract-inference-static-properties query-static-properties))
         (non-explanatory-sentence (getf inference-static-properties :non-explanatory-sentence))
         (problem-store-private? (null (inference-properties-problem-store query-static-properties)))
         (store (problem-store-from-properties query-static-properties)))
    (values inference-static-properties non-explanatory-sentence problem-store-private? store)))

(defun initialize-inference-properties (inference input-static-properties inference-static-properties query-static-properties)
  (set-inference-input-query-properties inference input-static-properties)
  (inference-set-static-properties inference inference-static-properties)
  (let* ((strategy (simplest-inference-strategy inference))
         (strategy-static-properties (extract-strategy-static-properties query-static-properties)))
    (strategy-initialize-properties strategy strategy-static-properties))
  inference)

(defun problem-store-from-properties (static-properties)
  (let ((problem-store (inference-properties-problem-store static-properties)))
    (if problem-store
        problem-store
        (let ((problem-store-properties (extract-problem-store-properties-from-query-static-properties static-properties)))
          (new-problem-store problem-store-properties)))))

(defun extract-problem-store-properties-from-query-static-properties (query-static-properties)
  (filter-plist query-static-properties #'problem-store-property-p))

;; (defun continue-inference (inference &optional query-properties) ...) -- active declareFunction, no body

(defun continue-inference-int (inference input-dynamic-properties overridden-dynamic-properties)
  (inference-update-properties inference input-dynamic-properties overridden-dynamic-properties)
  (consider-switching-strategies inference)
  (reset-inference-new-answers inference)
  (within-controlling-inference inference
    (inference-run inference))
  (inference-postprocess inference))

(defun inference-update-properties (inference input-dynamic-properties query-dynamic-properties)
  (let ((inference-dynamic-properties (extract-inference-dynamic-properties query-dynamic-properties)))
    (if (prepared-inference-p inference)
        (progn
          (inference-update-dynamic-properties inference inference-dynamic-properties)
          (strengthen-query-properties-using-inference inference))
        (inference-update-dynamic-properties inference inference-dynamic-properties)))
  (update-inference-input-query-properties inference input-dynamic-properties)
  (let* ((strategy-dynamic-properties (extract-strategy-dynamic-properties query-dynamic-properties))
         (strategy (simplest-inference-strategy inference)))
    (strategy-update-properties strategy strategy-dynamic-properties))
  (finalize-problem-store-properties (inference-problem-store inference))
  inference)

(defun inference-postprocess (inference)
  (declare (type inference inference))
  (let ((result nil)
        (halt-reason nil)
        (return-inference nil)
        (metrics nil))
    (with-inference-error-handling halt-reason
      (when (not (valid-inference-p inference))
        (error "Inference was destroyed while running."))
      (let ((answers (inference-all-new-answers inference)))
        (setf halt-reason (inference-suspend-status inference))
        (when (inference-browsable? inference)
          (setf return-inference inference))
        (setf metrics (inference-compute-metrics inference))
        (setf result (inference-result-from-answers inference answers))
        (when (inference-forget-extra-results? inference)
          ;; Likely filters down to max-number results;
          ;; debug path: 36245, non-debug path: 36246
          (setf result (missing-larkc 36245)))
        (when (inference-cache-results? inference)
          (dolist (answer answers)
            ;; Likely caches each answer result;
            ;; debug path: 35551, non-debug path: 35552
            (missing-larkc 35551)))))
    (values result halt-reason return-inference metrics)))

(defun inference-result-from-answers (inference answers)
  (let ((answer-language (inference-answer-language inference))
        (return-type (inference-return-type inference))
        (result nil))
    (declare (ignore answer-language))
    (let ((pcase-var return-type))
      (cond
        ((eql pcase-var :answer)
         (setf result answers))
        ((eql pcase-var :bindings)
         (setf result (inference-result-from-answers-via-template answers :bindings)))
        ((eql pcase-var :supports)
         (setf result (inference-result-from-answers-via-template answers :supports)))
        ((eql pcase-var :bindings-and-supports)
         (setf result (inference-result-from-answers-via-template answers '(:bindings :supports))))
        ((eql pcase-var :bindings-and-hypothetical-bindings)
         (let ((hypothetical-bindings
                 ;; Likely extracts hypothetical bindings from the inference
                 (missing-larkc 35766)))
           (setf result (list
                          ;; Likely extracts regular bindings from answers
                          (missing-larkc 36248)
                          hypothetical-bindings))))
        (t
         (cond
           ((inference-template-return-type-p return-type)
            (let ((template
                    ;; Likely extracts the template from the return type spec
                    (missing-larkc 36251)))
              (setf result (inference-result-from-answers-via-template answers template))))
           ;; Likely checks for some other special return type
           ((missing-larkc 36499)
            (setf result
                  ;; Likely computes result from answers using this special type
                  (missing-larkc 36249)))
           (t
            (error "Unexpected return type specified: ~a" return-type))))))
    result))

;; (defun inference-result-from-all-answers (inference) ...) -- active declareFunction, no body
;; (defun inference-template-return-type-template (return-type) ...) -- active declareFunction, no body

(defun inference-result-from-answers-via-template (answers template)
  (let ((process-supports? (simple-tree-find? :supports template))
        (results nil))
    (dolist (answer answers)
      (let* ((v-bindings (inference-answer-result-bindings answer))
             (result (inference-one-result-from-bindings-via-template v-bindings template)))
        (if process-supports?
            (dolist (justification (inference-answer-justifications answer))
              (let* ((supports (inference-answer-justification-supports justification))
                     (support-result (subst supports :supports result)))
                (push support-result results)))
            (push result results))))
    (nreverse results)))

;; (defun inference-result-from-binding-lists-via-template (binding-lists template) ...) -- active declareFunction, no body

(defun inference-one-result-from-bindings-via-template (v-bindings template)
  (let ((result template))
    (setf result (apply-bindings v-bindings result))
    (when (simple-tree-find? :bindings result)
      (setf result (subst v-bindings :bindings result)))
    result))

;; (defun inference-answers-via-format (inference format) ...) -- active declareFunction, no body
;; (defun inference-all-answer-result-bindings (inference) ...) -- active declareFunction, no body
;; (defun filter-out-extra-inference-results (result inference) ...) -- active declareFunction, no body
;; (defun handle-non-continuable-inference-status (inference) ...) -- active declareFunction, no body
;; (defun inference-answers-to-bindings (answers answer-language) ...) -- active declareFunction, no body
;; (defun inference-answer-to-bindings (answer answer-language) ...) -- active declareFunction, no body

(defun inference-answer-el-bindings (answer)
  (let ((answer-bindings (inference-answer-bindings answer)))
    (inference-bindings-hl-to-el answer-bindings)))

(defun inference-bindings-hl-to-el (hl-bindings)
  (let ((el-bindings nil))
    (dolist (binding hl-bindings)
      (destructuring-bind (variable . value) binding
        (let ((el-value (inference-answer-hl-to-el value)))
          (push (make-variable-binding variable el-value) el-bindings))))
    (setf el-bindings (nreverse el-bindings))
    el-bindings))

(defun inference-answer-hl-to-el (expression)
  (setf expression (assertion-expand expression))
  (setf expression (nart-expand expression))
  expression)

;; (defun inference-answer-supports (answer) ...) -- active declareFunction, no body
;; (defun inference-answer-bindings-and-supports (answer) ...) -- active declareFunction, no body
;; (defun inference-answer-el-bindings-and-supports (answer) ...) -- active declareFunction, no body
