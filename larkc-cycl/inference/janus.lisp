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


;; (defun janus-operation-p (op) ...) -- commented declareFunction, no body
;; (defun janus-operation-type (op) ...) -- commented declareFunction, no body
;; (defun janus-create-operation-p (op) ...) -- commented declareFunction, no body
;; (defun janus-assert-operation-p (op) ...) -- commented declareFunction, no body
;; (defun janus-query-operation-p (op) ...) -- commented declareFunction, no body
;; (defun janus-modification-operation-p (op) ...) -- commented declareFunction, no body
;; (defun new-janus-create-op (name external-id &optional tag) ...) -- commented declareFunction, no body
;; (defun new-janus-deduce-spec (arg1 arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun new-janus-assert-op (sentence mt strength direction expected-deduce-specs allowed-rules &optional tag) ...) -- commented declareFunction, no body
;; (defun new-janus-query-op (sentence mt query-properties expected-result expected-halt-reason &optional tag) ...) -- commented declareFunction, no body
;; (defun janus-create-op-name (op) ...) -- commented declareFunction, no body
;; (defun janus-create-op-external-id (op) ...) -- commented declareFunction, no body
;; (defun janus-create-op-tag (op) ...) -- commented declareFunction, no body
;; (defun janus-assert-op-sentence (op) ...) -- commented declareFunction, no body
;; (defun janus-assert-op-mt (op) ...) -- commented declareFunction, no body
;; (defun janus-assert-op-strength (op) ...) -- commented declareFunction, no body
;; (defun janus-assert-op-direction (op) ...) -- commented declareFunction, no body
;; (defun janus-assert-op-expected-deduce-specs (op) ...) -- commented declareFunction, no body
;; (defun janus-assert-op-allowed-rules (op) ...) -- commented declareFunction, no body
;; (defun janus-assert-op-tag (op) ...) -- commented declareFunction, no body
;; (defun janus-query-op-sentence (op) ...) -- commented declareFunction, no body
;; (defun janus-query-op-mt (op) ...) -- commented declareFunction, no body
;; (defun janus-query-op-query-properties (op) ...) -- commented declareFunction, no body
;; (defun janus-query-op-expected-result (op) ...) -- commented declareFunction, no body
;; (defun janus-query-op-expected-halt-reason (op) ...) -- commented declareFunction, no body
;; (defun janus-query-op-tag (op) ...) -- commented declareFunction, no body
;; (defun janus-new-constant? (constant) ...) -- commented declareFunction, no body
;; (defun janus-dwim-constant (constant) ...) -- commented declareFunction, no body
;; (defun janus-dwimmed-constant-id (constant) ...) -- commented declareFunction, no body
;; (defun janus-dwimmed-constant? (constant) ...) -- commented declareFunction, no body
;; (defun janus-dwim-expression (expression) ...) -- commented declareFunction, no body
;; (defun set-janus-tag (tag) ...) -- commented declareFunction, no body

(defun janus-test-case-logging? ()
  *janus-test-case-logging?*)

;; (defun janus-within-something? () ...) -- commented declareFunction, no body
;; (defun janus-transcript-full-filename (filename) ...) -- commented declareFunction, no body
;; (defun save-janus-transcript (arg1 arg2 &optional arg3) ...) -- commented declareFunction, no body
;; (defun load-janus-transcript (filename) ...) -- commented declareFunction, no body
;; (defun janus-op-index (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun janus-op-indices (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun extract-janus-operations (arg1) ...) -- commented declareFunction, no body

(defun janus-note-create-finished (new-constant)
  (when (janus-test-case-logging?)
    (when (valid-constant? new-constant)
      (let ((new-cons (cons new-constant nil))
            (list *janus-new-constants*))
        (if list
            (rplacd-last list new-cons)
            (setf *janus-new-constants* new-cons)))
      (let ((name (constant-name new-constant))
            (external-id (constant-external-id new-constant)))
        (declare (ignore name external-id))
        ;; Likely constructs a janus create-op struct from name+external-id and
        ;; conses it onto *janus-operations*. The Java builds a cons with
        ;; handleMissingMethodError 3402 — that was new-janus-create-op applied
        ;; to the constant name and external-id (and the current *janus-tag*).
        (setf *janus-operations* (cons (missing-larkc 3402) *janus-operations*)))
      (return-from janus-note-create-finished t)))
  nil)

(defun janus-note-assert-finished (sentence mt strength direction deduce-specs)
  (when (janus-test-case-logging?)
    ;; The Java wraps this body in (when (not (missing-larkc 3398))) — likely
    ;; a predicate asking whether this assert is already known/duplicate, so we
    ;; skip logging when it returns true.
    (unless (missing-larkc 3398)
      ;; Likely transforms/canonicalizes the raw deduce-specs into Janus-op form
      ;; (call #3379 probably maps raw deduction specs → janus deduce-spec objects).
      (setf deduce-specs (missing-larkc 3379))
      (let ((allowed-rules *forward-inference-allowed-rules*))
        (if (or (expression-find-if #'invalid-constant? sentence)
                (expression-find-if #'invalid-constant? mt)
                (expression-find-if #'invalid-constant? deduce-specs)
                (and (not (eq :all allowed-rules))
                     (find-if #'invalid-assertion? allowed-rules)))
            (progn
              (warn "invalid term in assert op: ~s ~s ~s"
                    sentence mt deduce-specs *forward-inference-allowed-rules*)
              nil)
            (progn
              ;; Likely constructs a janus assert-op record from the canonical
              ;; arguments and conses it on *janus-operations* — call #3401
              ;; is new-janus-assert-op of sentence/mt/strength/direction/etc.
              (setf *janus-operations*
                    (cons (missing-larkc 3401) *janus-operations*))
              t))))))

(defun janus-note-query-finished (sentence mt query-properties result halt-reason)
  (declare (ignore halt-reason))
  (when (janus-test-case-logging?)
    ;; Java outer guard is (when (not (missing-larkc 3399))) — likely a
    ;; predicate such as janus-query-already-logged? or query-ignorable?
    (unless (missing-larkc 3399)
      ;; Likely transforms raw result into Janus-op form (call #3380 maps
      ;; inference result → janus expected-result).
      (setf result (missing-larkc 3380))
      (when (or (expression-find-if #'invalid-constant? sentence)
                (expression-find-if #'invalid-constant? mt))
        (warn "invalid constant in query op: ~s ~s" sentence mt)
        (return-from janus-note-query-finished nil))
      (when (getf query-properties :problem-store)
        (warn "ignoring problem store reuse for query ~s ~s ~s"
              sentence mt query-properties)
        (setf query-properties (remf (copy-list query-properties) :problem-store)))
      ;; Likely constructs a janus query-op record from sentence/mt/
      ;; query-properties/result/halt-reason and conses it onto
      ;; *janus-operations*. Call #3405 is new-janus-query-op.
      (setf *janus-operations*
            (cons (missing-larkc 3405) *janus-operations*))))
  nil)

;; (defun janus-note-new-continuable-inference (arg1 arg2 arg3) ...) -- commented declareFunction, no body

(defun janus-note-argument (argument-spec cnf mt direction variable-map)
  (declare (ignore direction variable-map))
  (when (or (janus-test-case-logging?)
            (janus-test-case-running?))
    ;; The Java dwims cnf and mt through two (missing-larkc N) calls before the
    ;; type dispatch. Call #3381 likely maps cnf → janus-dwim-expression, and
    ;; call #3382 likely maps mt the same way.
    (setf cnf (missing-larkc 3381))
    (setf mt (missing-larkc 3382))
    (when (eq :deduction (argument-spec-type argument-spec))
      (if (janus-test-case-running?)
          ;; Likely constructs a janus deduce-spec from argument-spec/cnf/mt and
          ;; conses it on *janus-testing-deduce-specs*. Call #3403 is
          ;; new-janus-deduce-spec (or equivalent) for the testing path.
          (setf *janus-testing-deduce-specs*
                (cons (missing-larkc 3403) *janus-testing-deduce-specs*))
          ;; Likely the same construction but for the extraction path.
          ;; Call #3404 is new-janus-deduce-spec for extraction.
          (setf *janus-extraction-deduce-specs*
                (cons (missing-larkc 3404) *janus-extraction-deduce-specs*)))
      (return-from janus-note-argument t)))
  nil)

;; (defun janus-experiment-full-filename (filename) ...) -- commented declareFunction, no body

;; TODO - Reconstructed from Internal Constants evidence: arglist (&KEY
;; TRANSCRIPT-FILENAME EXPERIMENT-FILENAME COMMENT OVERRIDING-QUERY-PROPERTIES
;; (METRICS '(ALL-QUERY-METRICS)) (OUTLIER-TIMEOUT '*ARETE-OUTLIER-TIMEOUT*)
;; (SKIP 0) COUNT), operator RUN-KCT-EXPERIMENT, keyword args :TEST-SPEC-SET,
;; :FILENAME, :INCREMENTAL, :OVERRIDING-METRICS, integer 600. No visible
;; expansion found in other Java files — body shape below is speculative.
;; Macro must wrap some form of RUN-KCT-EXPERIMENT call built from these keys.
(defmacro run-janus-experiment (&key transcript-filename experiment-filename
                                comment overriding-query-properties
                                (metrics '(all-query-metrics))
                                (outlier-timeout '*arete-outlier-timeout*)
                                (skip 0)
                                count)
  (declare (ignore transcript-filename experiment-filename comment
                   overriding-query-properties metrics outlier-timeout
                   skip count))
  ;; TODO - no body reconstruction evidence for run-janus-experiment macro.
  nil)

(defun janus-test-case-running? ()
  *janus-test-case-running?*)

;; (defun execute-janus-operations (arg1 &optional arg2 arg3 arg4 arg5 arg6 arg7) ...) -- commented declareFunction, no body
;; (defun execute-janus-operation (arg1 &optional arg2 arg3 arg4 arg5) ...) -- commented declareFunction, no body
;; (defun execute-janus-create-operations (arg1) ...) -- commented declareFunction, no body
;; (defun execute-janus-modification-operation (arg1) ...) -- commented declareFunction, no body
;; (defun kill-janus-constants (arg1) ...) -- commented declareFunction, no body
;; (defun execute-janus-create (arg1) ...) -- commented declareFunction, no body
;; (defun execute-janus-assert (arg1) ...) -- commented declareFunction, no body
;; (defun dwim-janus-assert-operation (arg1) ...) -- commented declareFunction, no body
;; (defun dwim-janus-query-properties (arg1) ...) -- commented declareFunction, no body
;; (defun janus-operation-success? (arg1 arg2 &optional arg3) ...) -- commented declareFunction, no body
;; (defun janus-create-success? (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun janus-assert-success? (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun janus-query-success? (arg1 arg2 &optional arg3) ...) -- commented declareFunction, no body
;; (defun janus-query-result-success? (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun load-janus-experiment (arg1) ...) -- commented declareFunction, no body
;; (defun janus-experiment-p (arg1) ...) -- commented declareFunction, no body
;; (defun janus-failure-analysis (arg1) ...) -- commented declareFunction, no body
;; (defun janus-newly-failing-op-failure-reasons (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun janus-categorize-failing-asserts (arg1) ...) -- commented declareFunction, no body
;; (defun janus-categorize-failing-assert (arg1) ...) -- commented declareFunction, no body
;; (defun janus-categorize-failing-assert-int (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun janus-valid-test-set-run (arg1) ...) -- commented declareFunction, no body
;; (defun janus-valid-test-run? (arg1) ...) -- commented declareFunction, no body
;; (defun janus-more-complete-test-runs (arg1) ...) -- commented declareFunction, no body
;; (defun janus-equally-complete-test-runs (arg1) ...) -- commented declareFunction, no body
;; (defun janus-less-complete-test-runs (arg1) ...) -- commented declareFunction, no body
;; (defun janus-different-test-runs (arg1) ...) -- commented declareFunction, no body
;; (defun janus-test-runs-with-assert-failure-status (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun janus-test-runs-that-started-failing (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun janus-test-runs-that-started-succeeding (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun janus-test-runs-that-became-status (arg1 arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun janus-operations-that-became-status (arg1 arg2 arg3) ...) -- commented declareFunction, no body
;; (defun janus-compare-test-set-run-statuses (arg1 arg2) ...) -- commented declareFunction, no body

(deflexical *janus-transcript-directory* "/cyc/projects/inference/janus/transcripts/")

(deflexical *janus-experiment-directory* "/cyc/projects/inference/janus/experiments/")

(toplevel
  (note-funcall-helper-function 'janus-categorize-failing-assert-int))
