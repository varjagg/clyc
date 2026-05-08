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


;;; Variables

(deflexical *leviathan-directory* "/cyc/projects/inference/leviathan/")

(deflexical *leviathan-experiment-directory*
  (concatenate 'string *leviathan-directory* "experiments/"))

(deflexical *standard-leviathan-query-metrics*
  '(:answer-count :time-to-first-answer :total-time :problem-count :proof-count
    :link-count :tactic-count :removal-link-count :transformation-link-count
    :residual-transformation-link-count :join-ordered-link-count :join-link-count
    :split-link-count :restriction-link-count :good-problem-count
    :neutral-problem-count :no-good-problem-count :new-root-count)
  "[Cyc] A set of experiment analysis and comparison metrics that's large enough to
be useful but small enough to be manageable.")

;; TODO: forward reference to unported kbq-query-run: *kbq-default-outlier-timeout*.
;; Java reads kbq_query_run.$kbq_default_outlier_timeout$.getGlobalValue() at
;; init time; guarded with boundp until kbq-query-run is ported.
(deflexical *leviathan-outlier-timeout*
  (if (boundp '*kbq-default-outlier-timeout*)
      (symbol-value '*kbq-default-outlier-timeout*)
      nil))

(deflexical *cached-load-all-haystacks-caching-state* nil)

(deflexical *cached-load-all-instantiated-haystacks-caching-state* nil)

(deflexical *cached-load-all-crippled-haystacks-caching-state* nil)

(deflexical *sorted-rule-analyses*
  '(:sucky-skolem-rule :negative-utility-skolem-rule :sucky-rule :inert-skolem-rule
    :never-considered-forward-skolem-rule :never-considered-backward-skolem-rule
    :inert-rule :unsuccessful-forward-rule
    :unsuccessful-backward-rule-with-dependents :successful-skolem-rule
    :backward-successful-backward-rule :backward-successful-forward-rule
    :successful-forward-rule :other))

(deflexical *rule-bindings-wff-table*
  (if (boundp '*rule-bindings-wff-table*)
      *rule-bindings-wff-table*
      nil))

(defparameter *rule-bindings-to-closed-wff-pruning-enabled?* nil)

(defparameter *maintain-problem-creation-times?* nil)

;; Javadoc: "@todo lock this or bind it or make it an inference slot or something"
(deflexical *problem-creation-times*
  (if (boundp '*problem-creation-times*)
      *problem-creation-times*
      nil))

(deflexical *leviathan-crtl-internal-time-units-per-second* 1000000)


;;; Stripped function stubs (LarKC)

;; basic-leviathan-query-metrics (0 0) -- commented declareFunction, no body
;; standard-leviathan-query-metrics (0 0) -- commented declareFunction, no body
;; all-leviathan-query-metrics (0 0) -- commented declareFunction, no body
;; leviathan-experiment-full-filename (1 1) -- commented declareFunction, no body

;; TODO: Reconstruct macro RUN-LEVIATHAN-EXPERIMENT from Internal Constants.
;; Arglist ($list5): (&KEY QUERY-SPEC-SET FILENAME COMMENT OVERRIDING-QUERY-PROPERTIES
;;                         (METRICS '(ALL-LEVIATHAN-QUERY-METRICS))
;;                         (OUTLIER-TIMEOUT '*LEVIATHAN-OUTLIER-TIMEOUT*)
;;                         (INCREMENTAL T) (INCLUDE-RESULTS NIL) (SKIP 0) COUNT
;;                         (DIRECTORY *LEVIATHAN-EXPERIMENT-DIRECTORY*))
;; Gensyms: FILENAME-VAR, FULL-FILENAME
;; Operators: CLET, FWHEN
;; Referenced functions: LEVIATHAN-EXPERIMENT-FULL-FILENAME, RUN-KBQ-EXPERIMENT
;; No visible call-site expansions found; arete has an identical parallel macro
;; RUN-ARETE-EXPERIMENT, also stripped.
;; (defmacro run-leviathan-experiment (&key query-spec-set filename comment
;;                                          overriding-query-properties
;;                                          (metrics '(all-leviathan-query-metrics))
;;                                          (outlier-timeout '*leviathan-outlier-timeout*)
;;                                          (incremental t) (include-results nil)
;;                                          (skip 0) count
;;                                          (directory *leviathan-experiment-directory*)) ...)

;; load-leviathan-experiment (1 0) -- commented declareFunction, no body
;; save-leviathan-experiment (2 0) -- commented declareFunction, no body
;; leviathan-kb-content-query-set-run (1 0) -- commented declareFunction, no body
;; leviathan-halo-query-set-run (1 0) -- commented declareFunction, no body
;; leviathan-haystack-query-set-run (1 0) -- commented declareFunction, no body
;; leviathan-kb-content-query? (1 0) -- commented declareFunction, no body
;; leviathan-halo-query? (1 0) -- commented declareFunction, no body
;; leviathan-haystack-query? (1 0) -- commented declareFunction, no body
;; save-haystack (1 0) -- commented declareFunction, no body
;; load-haystack (1 0) -- commented declareFunction, no body
;; load-all-haystacks (0 1) -- commented declareFunction, no body
;; clear-cached-load-all-haystacks (0 0) -- commented declareFunction, no body
;; remove-cached-load-all-haystacks (0 0) -- commented declareFunction, no body
;; cached-load-all-haystacks-internal (0 0) -- commented declareFunction, no body
;; cached-load-all-haystacks (0 0) -- commented declareFunction, no body
;; load-all-haystacks-int (0 0) -- commented declareFunction, no body
;; show-haystack-statistics (0 0) -- commented declareFunction, no body
;; load-all-instantiated-haystacks (0 1) -- commented declareFunction, no body
;; clear-cached-load-all-instantiated-haystacks (0 0) -- commented declareFunction, no body
;; remove-cached-load-all-instantiated-haystacks (0 0) -- commented declareFunction, no body
;; cached-load-all-instantiated-haystacks-internal (0 0) -- commented declareFunction, no body
;; cached-load-all-instantiated-haystacks (0 0) -- commented declareFunction, no body
;; load-all-instantiated-haystacks-int (0 0) -- commented declareFunction, no body
;; show-instantiated-haystack-statistics (0 0) -- commented declareFunction, no body
;; save-good-instantiated-haystack (1 0) -- commented declareFunction, no body
;; make-haystacks-good (0 2) -- commented declareFunction, no body
;; load-all-crippled-haystacks (0 1) -- commented declareFunction, no body
;; clear-cached-load-all-crippled-haystacks (0 0) -- commented declareFunction, no body
;; remove-cached-load-all-crippled-haystacks (0 0) -- commented declareFunction, no body
;; cached-load-all-crippled-haystacks-internal (0 0) -- commented declareFunction, no body
;; cached-load-all-crippled-haystacks (0 0) -- commented declareFunction, no body
;; load-all-crippled-haystacks-int (0 0) -- commented declareFunction, no body
;; show-crippled-haystack-statistics (0 0) -- commented declareFunction, no body
;; make-haystacks-crippled (0 2) -- commented declareFunction, no body
;; reify-all-haystacks (0 0) -- commented declareFunction, no body
;; reify-all-instantiated-haystacks (0 0) -- commented declareFunction, no body
;; reify-all-crippled-haystacks (0 0) -- commented declareFunction, no body
;; reify-haystack (2 0) -- commented declareFunction, no body
;; haystack-constant-name-from-filename (1 0) -- commented declareFunction, no body
;; haystack-id-string-from-filename (1 0) -- commented declareFunction, no body
;; haystack-id-string-from-query (1 0) -- commented declareFunction, no body
;; haystack-size-from-query (1 0) -- commented declareFunction, no body
;; haystack-filename-from-query (1 0) -- commented declareFunction, no body
;; instantiated-haystack-filename-from-query (1 0) -- commented declareFunction, no body
;; crippled-haystack-filename-from-query (1 0) -- commented declareFunction, no body
;; remove-haystack-files (1 0) -- commented declareFunction, no body
;; remove-all-duplicate-haystack-files (0 1) -- commented declareFunction, no body
;; remove-duplicate-haystack-files-int (2 0) -- commented declareFunction, no body
;; kill-duplicate-and-broken-reified-haystacks (0 1) -- commented declareFunction, no body
;; finalize-haystack-corpus (0 0) -- commented declareFunction, no body
;; initialize-kb-content-leviathan-queries (0 0) -- commented declareFunction, no body
;; determine-leviathan-training-and-blind-sets (0 0) -- commented declareFunction, no body
;; determine-leviathan-training-and-blind-sets-int (3 0) -- commented declareFunction, no body
;; unassert-assertion (1 0) -- commented declareFunction, no body
;; unassert-assertion-via-cyc (1 0) -- commented declareFunction, no body
;; unassert-assertion-via-hl (1 0) -- commented declareFunction, no body
;; unassert-assertion-via-tms (1 0) -- commented declareFunction, no body
;; assert-allowed-rules-for-justified-queries (0 1) -- commented declareFunction, no body
;; allowed-rules-utilities (0 0) -- commented declareFunction, no body
;; allowed-rules-sorted-utility-tuples (0 0) -- commented declareFunction, no body
;; skolem-rule? (1 0) -- commented declareFunction, no body
;; all-skolem-rules (0 0) -- commented declareFunction, no body
;; negative-utility-skolem-rules (0 0) -- commented declareFunction, no body
;; sorted-rule-utilities (1 0) -- commented declareFunction, no body
;; rule-utility-tuples (1 0) -- commented declareFunction, no body
;; rule-consideration-tuples (1 0) -- commented declareFunction, no body
;; rule-success-tuples (1 0) -- commented declareFunction, no body
;; skolem-rules-used-in-justified-queries (0 1) -- commented declareFunction, no body
;; skolem-allowed-rules (0 0) -- commented declareFunction, no body
;; kill-all-skolem-rules (0 0) -- commented declareFunction, no body
;; kill-all-negative-utility-skolem-rules (0 0) -- commented declareFunction, no body
;; inert-rules (0 0) -- commented declareFunction, no body
;; inert-rule? (1 0) -- commented declareFunction, no body
;; assertion-has-non-skolem-assertion-dependents? (1 0) -- commented declareFunction, no body
;; kill-all-inert-rules (0 0) -- commented declareFunction, no body
;; rules-that-totally-suck (0 0) -- commented declareFunction, no body
;; kill-all-rules-that-totally-suck (0 0) -- commented declareFunction, no body
;; never-successful-rule? (1 0) -- commented declareFunction, no body
;; successful-rule? (1 0) -- commented declareFunction, no body
;; never-considered-rule? (1 0) -- commented declareFunction, no body
;; considered-rule? (1 0) -- commented declareFunction, no body
;; considered-but-not-successful-rule? (1 0) -- commented declareFunction, no body
;; leviathan-rule-statistics (1 0) -- commented declareFunction, no body
;; rule-analysis-< (2 0) -- commented declareFunction, no body
;; leviathan-rule-statistics-int (6 0) -- commented declareFunction, no body
;; leviathan-allowed-rules (0 0) -- commented declareFunction, no body
;; leviathan-kb-content-allowed-rules (0 0) -- commented declareFunction, no body
;; leviathan-haystack-allowed-rules (0 0) -- commented declareFunction, no body
;; leviathan-haystack-all-allowed-rules (0 0) -- commented declareFunction, no body
;; conditional-queries (0 0) -- commented declareFunction, no body
;; queries-that-probably-ought-to-be-conditional (0 0) -- commented declareFunction, no body
;; fix-queries-that-probably-ought-to-be-conditional (0 0) -- commented declareFunction, no body
;; rule-bindings-to-closed-summary (0 1) -- commented declareFunction, no body
;; rule-bindings-wff? (3 0) -- commented declareFunction, no body
;; rule-bindings-wff-analysis (0 1) -- commented declareFunction, no body
;; initialize-rule-bindings-wff-table (0 1) -- commented declareFunction, no body


;;; Active functions

(defun rule-bindings-wff-cached? (rule transformation-bindings mt)
  (declare (ignore transformation-bindings))
  (when *rule-bindings-wff-table*
    (let ((v-set (gethash rule *rule-bindings-wff-table*)))
      (when v-set
        ;; Originally a method call replaced for LarKC purposes.
        ;; Likely computes a transformation-bindings-to-closed-wff form
        ;; from TRANSFORMATION-BINDINGS, since the result is consed with MT
        ;; and looked up via SET-MEMBER? in v-set.
        (let ((rule-bindings-to-closed (missing-larkc 36438)))
          (when (set-member? (cons mt rule-bindings-to-closed) v-set)
            (when *rule-bindings-to-closed-wff-pruning-enabled?*
              (return-from rule-bindings-wff-cached? nil)))))))
  t)


;;; Stripped function stubs (LarKC) continued

;; leviathan-generate-answerable-vs-unanswerable-comparison (2 0) -- commented declareFunction, no body
;; generate-all-leviathan-answerable-vs-unanswerable-comparisons (1 0) -- commented declareFunction, no body
;; leviathan-answerability-data (1 1) -- commented declareFunction, no body
;; leviathan-generate-answerability-prediction-graph (3 0) -- commented declareFunction, no body
;; generate-all-leviathan-answerability-prediction-graphs (2 0) -- commented declareFunction, no body
;; leviathan-win-at-solitaire (2 0) -- commented declareFunction, no body
;; clear-problem-creation-times (0 0) -- commented declareFunction, no body


;;; Active functions continued

(defun note-new-problem-created ()
  (let ((result nil))
    (when *maintain-problem-creation-times?*
      (setf result (get-internal-real-time))
      (setf *problem-creation-times* (cons result *problem-creation-times*)))
    result))


;;; Stripped function stubs (LarKC) continued

;; historical-problem-creation-times (0 0) -- commented declareFunction, no body
;; initialize-halo-leviathan-queries (0 0) -- commented declareFunction, no body
;; analyze-leviathan-experiment (1 4) -- commented declareFunction, no body
;; analyze-leviathan-experiments (2 5) -- commented declareFunction, no body
;; leviathan-generate-sorted-property-comparison (5 3) -- commented declareFunction, no body
;; leviathan-generate-sorted-property-display (3 2) -- commented declareFunction, no body
;; ylabel-for-property (1 0) -- commented declareFunction, no body
;; problem-query-relational-complexity-analysis (0 1) -- commented declareFunction, no body
;; problem-query-fort-analysis (0 1) -- commented declareFunction, no body
;; elapsed-crtl-internal-real-time-to-elapsed-seconds (1 0) -- commented declareFunction, no body
;; elapsed-crtl-internal-real-times-to-elapsed-seconds (1 0) -- commented declareFunction, no body
;; compute-n-way-parallelism-total-time (2 0) -- commented declareFunction, no body
;; compute-n-way-parallelism-time-to-first-answer (2 0) -- commented declareFunction, no body
;; compute-n-way-parallelism-times (2 0) -- commented declareFunction, no body
;; earliest-free-processor-number (1 0) -- commented declareFunction, no body
;; new-root-first-answer-times (1 0) -- commented declareFunction, no body
;; generate-new-root-first-answer-times-graph (1 1) -- commented declareFunction, no body
;; new-root-total-times (1 0) -- commented declareFunction, no body
;; generate-new-root-total-times-graph (1 1) -- commented declareFunction, no body
;; haystack-transformation-fanout-estimate (1 0) -- commented declareFunction, no body
;; inference-transformation-fanout-estimate (1 0) -- commented declareFunction, no body
;; problem-standard-transformation-fanout (1 0) -- commented declareFunction, no body
;; literal-standard-transformation-fanout (1 0) -- commented declareFunction, no body
;; inference-top-level-removal-fanout (1 0) -- commented declareFunction, no body
;; balanced-strategy-root-initial-removal-fanout (2 0) -- commented declareFunction, no body
;; inference-new-root-initial-removal-fanouts (1 0) -- commented declareFunction, no body


;;; Setup phase

(toplevel
  ;; note-globally-cached-function calls for cached-load-all-haystacks,
  ;; cached-load-all-instantiated-haystacks, cached-load-all-crippled-haystacks
  ;; are elided because all three defun-cached bodies are missing-larkc.
  (declare-defglobal '*rule-bindings-wff-table*)
  (declare-defglobal '*problem-creation-times*))
