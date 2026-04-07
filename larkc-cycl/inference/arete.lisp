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

(defparameter *arete-log-kb-touches?* nil
  "[Cyc] When non-nil, logs every KB access in one of three dictionaries")

(deflexical *arete-experiment-directory* "/cyc/projects/inference/arete/experiments/")

(deflexical *arete-analysis-directory* "/cyc/projects/inference/arete/analysis/")

(deflexical *kbq-control-query-set-run*
  (if (boundp '*kbq-control-query-set-run*)
      *kbq-control-query-set-run*
      :uninitialized))

;; TODO: forward reference to unported kbq-query-run: *kbq-default-outlier-timeout*.
;; Java reads kbq_query_run.$kbq_default_outlier_timeout$.getGlobalValue() at
;; init time; guarded with boundp until kbq-query-run is ported.
(deflexical *arete-outlier-timeout*
  (if (boundp '*kbq-default-outlier-timeout*)
      (symbol-value '*kbq-default-outlier-timeout*)
      nil))


;;; Stripped function stubs (LarKC)

;; arete-experiment-full-filename (1 1) -- commented declareFunction, no body
;; arete-analysis-full-filename (1 0) -- commented declareFunction, no body
;; load-arete-experiment (1 0) -- commented declareFunction, no body
;; suggest-filename-for-query-set-run (1 0) -- commented declareFunction, no body
;; kbq-load-control-query-set-run (0 1) -- commented declareFunction, no body
;; kbq-compare-query-set-run-answers-to-control (1 0) -- commented declareFunction, no body

;; TODO: Reconstruct macro RUN-ARETE-EXPERIMENT from Internal Constants.
;; Arglist ($list11): (&KEY QUERY-SPEC-SET FILENAME COMMENT OVERRIDING-QUERY-PROPERTIES
;;                          (METRICS '(ALL-ARETE-QUERY-METRICS))
;;                          (OUTLIER-TIMEOUT '*ARETE-OUTLIER-TIMEOUT*)
;;                          INCREMENTAL (INCLUDE-RESULTS T) (SKIP 0) COUNT
;;                          (DIRECTORY *ARETE-EXPERIMENT-DIRECTORY*))
;; Gensyms: FILENAME-VAR, FULL-FILENAME
;; Operators: CLET, FWHEN
;; Referenced functions: ARETE-EXPERIMENT-FULL-FILENAME, RUN-KBQ-EXPERIMENT
;; No visible call-site expansions found in ported Java (arete is the only file
;; referencing this macro; leviathan has a parallel RUN-LEVIATHAN-EXPERIMENT
;; with identical gensyms/operators, also stripped).
;; (defmacro run-arete-experiment (&key query-spec-set filename comment
;;                                      overriding-query-properties
;;                                      (metrics '(all-arete-query-metrics))
;;                                      (outlier-timeout '*arete-outlier-timeout*)
;;                                      incremental (include-results t) (skip 0)
;;                                      count (directory *arete-experiment-directory*)) ...)

;; kbq-query-set-run-scaling-factors (2 1) -- commented declareFunction, no body
;; kbq-compute-scaling-factors-from-analysis (1 0) -- commented declareFunction, no body
;; kbq-scale-analysis (3 0) -- commented declareFunction, no body
;; multiply-scaling-factors (2 0) -- commented declareFunction, no body
;; invert-scaling-factors (1 0) -- commented declareFunction, no body
;; kbq-save-report (2 1) -- commented declareFunction, no body
;; kbq-print-report (1 1) -- commented declareFunction, no body
;; kbq-print-histogram (3 0) -- commented declareFunction, no body
;; kbq-print-data (3 0) -- commented declareFunction, no body
;; kbq-print-tuples (3 0) -- commented declareFunction, no body
;; kbq-print-func-of-tuples (4 0) -- commented declareFunction, no body
;; kbq-compute-tuples (2 0) -- commented declareFunction, no body
;; kbq-print-error-queries (1 0) -- commented declareFunction, no body
;; arete-generate-property-correlation-plot (3 2) -- commented declareFunction, no body
;; arete-generate-sorted-property-comparison (3 3) -- commented declareFunction, no body
;; arete-generate-sorted-properties-comparison (2 3) -- commented declareFunction, no body
;; arete-generate-sorted-property-display (2 3) -- commented declareFunction, no body
;; assertion-cons-sharing-dictionary (0 0) -- commented declareFunction, no body
;; conses-saved-and-total-conses (1 0) -- commented declareFunction, no body
;; nauts-shared-and-unshared (1 0) -- commented declareFunction, no body
;; kbq-hybridize-query-set-runs (1 4) -- commented declareFunction, no body
;; kbq-tag-query-set-runs (2 0) -- commented declareFunction, no body
;; kbq-hybridize-two-query-set-runs (2 3) -- commented declareFunction, no body
;; kbq-better-query-run (2 2) -- commented declareFunction, no body
;; kbq-query-run-better? (2 1) -- commented declareFunction, no body
;; kbq-query-run-better-per-answer? (2 1) -- commented declareFunction, no body
;; kbq-query-run-better-wrt-time? (2 1) -- commented declareFunction, no body
;; kbq-may-have-harmful-side-effects? (1 0) -- commented declareFunction, no body
;; query-may-have-harmful-side-effects? (1 2) -- commented declareFunction, no body
;; sentence-contains-subl-performative? (1 0) -- commented declareFunction, no body
;; subl-performative-p (1 0) -- commented declareFunction, no body
;; conditional-sentence-with-closed-decontextualized-antecedent-literal? (2 0) -- commented declareFunction, no body
;; kbq-numeric-quantification-query? (1 0) -- commented declareFunction, no body
;; kbq-not-numeric-quantification-query? (1 0) -- commented declareFunction, no body


;;; Setup phase

(toplevel
  (declare-defglobal '*kbq-control-query-set-run*)
  (define-obsolete-register 'arete-generate-property-correlation-plot
                            '(kbq-generate-property-correlation-plot))
  (define-obsolete-register 'arete-generate-sorted-property-comparison
                            '(kbq-generate-sorted-property-comparison))
  (define-obsolete-register 'arete-generate-sorted-properties-comparison
                            '(kbq-generate-sorted-properties-comparison))
  (define-obsolete-register 'arete-generate-sorted-property-display
                            '(kbq-generate-sorted-property-display)))
