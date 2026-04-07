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


;;; Runstate dynamic variables

(defparameter *kct-set-runstate* nil
  "[Cyc] If non-nil, the runstate of the outer call to kct-run-test-set.")

(defparameter *kct-runstate* nil
  "[Cyc] If non-nil, the runstate of the outer call to kct-run-test.")

(defparameter *kbq-runstate* nil
  "[Cyc] If non-nil, the runstate of the outer call to kbq-run-query.")


;;; CFASL common-symbol tables

(deflexical *kbq-old-cfasl-common-symbols*
    '(:answer-count-at-60-seconds :problem-store-problem-count :problem-store-proof-count
      :error :max-number :max-time :answer-count-at-30-seconds :probably-approximately-done
      :total-time :time-to-last-answer :time-to-first-answer :answer-count :exhaust-total
      :halt-reason :query :query-run)
  "[Cyc] for backward compatibility")

(deflexical *kbq-new-cfasl-common-symbols*
    (append *kbq-old-cfasl-common-symbols*
            '(:time-per-answer :wasted-time-after-last-answer :latency-improvement-from-iterativity
              :problem-count :proof-count :link-count :content-link-count :removal-link-count
              :rewrite-link-count :transformation-link-count :structural-link-count
              :join-ordered-link-count :join-link-count :split-link-count :restriction-link-count
              :residual-transformation-link-count :union-link-count :good-problem-count
              :neutral-problem-count :no-good-problem-count :single-literal-problem-count
              :conjunctive-problem-count :join-problem-count :split-problem-count
              :disjunctive-problem-count :unexamined-problem-count :examined-problem-count
              :possible-problem-count :pending-problem-count :unexamined-good-problem-count
              :examined-good-problem-count :possible-good-problem-count :pending-good-problem-count
              :unexamined-neutral-problem-count :examined-neutral-problem-count
              :possible-neutral-problem-count :pending-neutral-problem-count
              :unexamined-no-good-problem-count :examined-no-good-problem-count
              :possible-no-good-problem-count :pending-no-good-problem-count
              :good-single-literal-problem-count :good-conjunctive-problem-count
              :good-join-problem-count :good-split-problem-count :good-disjunctive-problem-count
              :neutral-single-literal-problem-count :neutral-conjunctive-problem-count
              :neutral-join-problem-count :neutral-split-problem-count
              :neutral-disjunctive-problem-count :no-good-single-literal-problem-count
              :no-good-conjunctive-problem-count :no-good-join-problem-count
              :no-good-split-problem-count :no-good-disjunctive-problem-count
              :unexamined-single-literal-problem-count :unexamined-conjunctive-problem-count
              :unexamined-join-problem-count :unexamined-split-problem-count
              :unexamined-disjunctive-problem-count :examined-single-literal-problem-count
              :examined-conjunctive-problem-count :examined-join-problem-count
              :examined-split-problem-count :examined-disjunctive-problem-count
              :possible-single-literal-problem-count :possible-conjunctive-problem-count
              :possible-join-problem-count :possible-split-problem-count
              :possible-disjunctive-problem-count :finished-single-literal-problem-count
              :finished-conjunctive-problem-count :finished-join-problem-count
              :finished-split-problem-count :finished-disjunctive-problem-count))
  "[Cyc] See *query-metrics*")

(deflexical *kbq-cfasl-common-symbols*
    (append *kbq-old-cfasl-common-symbols* *kbq-new-cfasl-common-symbols*))

(deflexical *kct-old-cfasl-common-symbols*
    (append *kbq-old-cfasl-common-symbols* '(:success :failure :status :test))
  "[Cyc] for backward compatibility")

(deflexical *kct-cfasl-common-symbols*
    (append *kbq-old-cfasl-common-symbols*
            '(:success :failure :status :test)
            *kbq-new-cfasl-common-symbols*))

(defparameter *kbq-outlier-timeout* 600)

(defparameter *kbq-internal-time-units-per-second* nil
  "[Cyc] bound to the internal time units per second of the encompassing query set run")

(defparameter *kbq-run-number* 1
  "[Cyc] The number of times the kbq harness runs the query.  Useful for profiling.")


;;; Macros

;; Reconstructed from Internal Constants: arglist $list9 ((QUERY-SET-RUN) &BODY BODY),
;; operators $sym10 CLET, $sym11 *KBQ-INTERNAL-TIME-UNITS-PER-SECOND*,
;; $sym12 KBQ-QUERY-SET-RUN-INTERNAL-TIME-UNITS-PER-SECOND.
;; Binds the dynamic *kbq-internal-time-units-per-second* to the scaling factor
;; carried by the query-set-run, so nested metric calls can convert internal real
;; time to seconds.
(defmacro with-kbq-query-set-run ((query-set-run) &body body)
  "[Cyc] Use the 'with-kbq-query-set-run' macro to provide the scaling factor from internal real time to seconds."
  `(clet ((*kbq-internal-time-units-per-second*
           (kbq-query-set-run-internal-time-units-per-second ,query-set-run)))
     ,@body))


;;; kct-test-metric table (TestMetric-XXX constant -> keyword)

(deflexical *kct-test-metric-table*
    (list (cons (reader-make-constant-shell "TestMetric-TotalTime") :total-time)
          (cons (reader-make-constant-shell "TestMetric-TimeToFirstAnswer") :time-to-first-answer)
          (cons (reader-make-constant-shell "TestMetric-TimeToLastAnswer") :time-to-last-answer)
          (cons (reader-make-constant-shell "TestMetric-AnswerCount") :answer-count)
          (cons (reader-make-constant-shell "TestMetric-AnswerCountAt30Seconds") :answer-count-at-30-seconds)
          (cons (reader-make-constant-shell "TestMetric-AnswerCountAt60Seconds") :answer-count-at-60-seconds)
          (cons (reader-make-constant-shell "TestMetric-ProblemStoreProofCount") :proof-count)
          (cons (reader-make-constant-shell "TestMetric-ProblemStoreProblemCount") :problem-count)))

(deflexical *kbq-default-outlier-timeout* 600)

(deflexical *kbq-test-collection-to-query-set-query*
    (list (reader-make-constant-shell "evaluate") :set
          (list (reader-make-constant-shell "SetExtentFn")
                (list (reader-make-constant-shell "TheSetOf") '?query
                      (list (reader-make-constant-shell "thereExists") '?test
                            (list (reader-make-constant-shell "and")
                                  (list (reader-make-constant-shell "knownSentence")
                                        (list (reader-make-constant-shell "isa")
                                              '?test :test-collection))
                                  (list (reader-make-constant-shell "assertedSentence")
                                        (list (reader-make-constant-shell "testQuerySpecification")
                                              '?test '?query))))))))

(deflexical *last-query-set-run*
    (if (boundp '*last-query-set-run*)
        *last-query-set-run*
        nil))

(deflexical *last-test-set-run*
    (if (boundp '*last-test-set-run*)
        *last-test-set-run*
        nil))

(deflexical *runstate-isg*
    (if (boundp '*runstate-isg*)
        *runstate-isg*
        (new-integer-sequence-generator))
  "[Cyc] A sequence generator for IDs for runstate objects")

(deflexical *runstate-index*
    (if (boundp '*runstate-index*)
        *runstate-index*
        (make-hash-table))
  "[Cyc] An index to support lookup of runstate objects by ID")


;;; Runstate API

(defun kbq-runstate-valid? ()
  (kbq-runstate-p *kbq-runstate*))

;; (defun kbq-runstate-inference-already-set? () ...) -- commented declareFunction, no body
;; (defun set-kbq-runstate-inference (inference) ...) -- commented declareFunction, no body

(defun possibly-set-kbq-runstate-inference (inference)
  (when (kbq-runstate-valid?)
    ;; 3195: likely kbq-runstate-inference-already-set?
    ;; 3351: likely set-kbq-runstate-inference
    (unless (missing-larkc 3195)
      (return-from possibly-set-kbq-runstate-inference
        (missing-larkc 3351))))
  nil)

;; (defun find-kbq-runstate-by-id (id) ...) -- commented declareFunction, no body
;; (defun find-kbq-runstate-by-id-string (id-string) ...) -- commented declareFunction, no body
;; (defun find-kct-runstate-by-id (id) ...) -- commented declareFunction, no body
;; (defun find-kct-runstate-by-id-string (id-string) ...) -- commented declareFunction, no body
;; (defun find-kct-set-runstate-by-id (id) ...) -- commented declareFunction, no body
;; (defun find-kct-set-runstate-by-id-string (id-string) ...) -- commented declareFunction, no body
;; (defun next-runstate-id () ...) -- commented declareFunction, no body
;; (defun runstate-add-object (id runstate) ...) -- commented declareFunction, no body
;; (defun runstate-rem-object (runstate) ...) -- commented declareFunction, no body
;; (defun runstate-find-object-by-id (id) ...) -- commented declareFunction, no body
;; (defun runstate-constant (runstate) ...) -- commented declareFunction, no body
;; (defun runstate-result-status (runstate) ...) -- commented declareFunction, no body
;; (defun runstate-result-text (runstate) ...) -- commented declareFunction, no body
;; (defun runstate-run-status (runstate) ...) -- commented declareFunction, no body
;; (defun runstate-inference (runstate) ...) -- commented declareFunction, no body
;; (defun runstate-start (runstate) ...) -- commented declareFunction, no body
;; (defun runstate-end (runstate) ...) -- commented declareFunction, no body
;; (defun set-runstate-run-status (runstate status) ...) -- commented declareFunction, no body
;; (defun destroy-runstate (runstate) ...) -- commented declareFunction, no body


;;; Struct: kbq-runstate

(defstruct (kbq-runstate
            (:conc-name "KBQR-")
            (:constructor make-kbq-runstate
                (&key id lock query-spec inference result test-runstate run-status)))
  id
  lock
  query-spec
  inference
  result
  test-runstate
  run-status)

(defconstant *dtp-kbq-runstate* 'kbq-runstate)

;; (defun kbq-runstate-print-function-trampoline (object stream) ...) -- active declareFunction, no body

;; (defun new-kbq-runstate (query-spec test-runstate) ...) -- commented declareFunction, no body
;; (defun destroy-kbq-runstate (runstate) ...) -- commented declareFunction, no body
;; (defun kbq-runstate-query-spec (runstate) ...) -- commented declareFunction, no body
;; (defun kbq-runstate-lock (runstate) ...) -- commented declareFunction, no body
;; (defun kbq-runstate-inference (runstate) ...) -- commented declareFunction, no body
;; (defun kbq-runstate-result (runstate) ...) -- commented declareFunction, no body
;; (defun kbq-runstate-test-runstate (runstate) ...) -- commented declareFunction, no body
;; (defun kbq-runstate-run-status (runstate) ...) -- commented declareFunction, no body
;; (defun set-kbqr-inference (runstate inference) ...) -- commented declareFunction, no body
;; (defun set-kbqr-result (runstate result) ...) -- commented declareFunction, no body
;; (defun set-kbqr-run-status (runstate status) ...) -- commented declareFunction, no body
;; (defun possibly-set-kbqr-run-status (runstate status) ...) -- commented declareFunction, no body


;;; Struct: kct-runstate

(defstruct (kct-runstate
            (:conc-name "KCTR-")
            (:constructor make-kct-runstate
                (&key id lock test-spec result query-runstate test-set-runstate run-status start end)))
  id
  lock
  test-spec
  result
  query-runstate
  test-set-runstate
  run-status
  start
  end)

(defconstant *dtp-kct-runstate* 'kct-runstate)

;; (defun kct-runstate-print-function-trampoline (object stream) ...) -- active declareFunction, no body
;; (defun kct-runstate-p (object) ...) -- commented declareFunction, body was missing-larkc 3279

;; (defun new-kct-runstate (test-spec &optional test-set-runstate) ...) -- commented declareFunction, no body
;; (defun destroy-kct-runstate (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-test-spec (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-lock (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-result (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-query-runstate (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-test-set-runstate (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-inference (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-result-status (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-failure-explanation (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-metric-value (runstate metric) ...) -- commented declareFunction, no body
;; (defun kct-runstate-run-status (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-start (runstate) ...) -- commented declareFunction, no body
;; (defun kct-runstate-end (runstate) ...) -- commented declareFunction, no body
;; (defun set-kctr-result (runstate result) ...) -- commented declareFunction, no body
;; (defun set-kctr-query-runstate (runstate query-runstate) ...) -- commented declareFunction, no body
;; (defun set-kctr-test-set-runstate (runstate test-set-runstate) ...) -- commented declareFunction, no body
;; (defun set-kctr-run-status (runstate status) ...) -- commented declareFunction, no body
;; (defun set-kctr-start (runstate &optional start) ...) -- commented declareFunction, no body
;; (defun set-kctr-end (runstate &optional end) ...) -- commented declareFunction, no body


;;; Struct: kct-set-runstate

(defstruct (kct-set-runstate
            (:conc-name "KCTSR-")
            (:constructor make-kct-set-runstate
                (&key id lock test-set result test-runstates run-status start end)))
  id
  lock
  test-set
  result
  test-runstates
  run-status
  start
  end)

(defconstant *dtp-kct-set-runstate* 'kct-set-runstate)

;; (defun kct-set-runstate-print-function-trampoline (object stream) ...) -- active declareFunction, no body
;; (defun kct-set-runstate-p (object) ...) -- commented declareFunction, body was missing-larkc 3294

;; (defun new-kct-set-runstate (test-set) ...) -- commented declareFunction, no body
;; (defun destroy-kct-set-runstate (runstate) ...) -- commented declareFunction, no body
;; (defun kct-set-runstate-test-set (runstate) ...) -- commented declareFunction, no body
;; (defun kct-set-runstate-lock (runstate) ...) -- commented declareFunction, no body
;; (defun kct-set-runstate-result (runstate) ...) -- commented declareFunction, no body
;; (defun kct-set-runstate-test-runstates (runstate) ...) -- commented declareFunction, no body
;; (defun kct-set-runstate-result-status (runstate) ...) -- commented declareFunction, no body
;; (defun kct-set-runstate-run-status (runstate) ...) -- commented declareFunction, no body
;; (defun kct-set-runstate-start (runstate) ...) -- commented declareFunction, no body
;; (defun kct-set-runstate-end (runstate) ...) -- commented declareFunction, no body
;; (defun set-kctsr-result (runstate result) ...) -- commented declareFunction, no body
;; (defun kctsr-test-runstate-add (runstate runstate-to-add) ...) -- commented declareFunction, no body
;; (defun kctsr-test-runstate-remove (runstate runstate-to-remove) ...) -- commented declareFunction, no body
;; (defun set-kctsr-run-status (runstate status) ...) -- commented declareFunction, no body
;; (defun set-kctsr-start (runstate &optional start) ...) -- commented declareFunction, no body
;; (defun set-kctsr-end (runstate &optional end) ...) -- commented declareFunction, no body


;;; Query set / test set run save functions

(deflexical *query-set-run-file-extension* ".cfasl")

;; (defun kbq-save-query-set-run (query-set-run filename) ...) -- commented declareFunction, no body
;; (defun kct-save-test-set-run (test-set-run filename) ...) -- commented declareFunction, no body
;; (defun kbq-save-query-set-run-without-results (query-set-run filename) ...) -- commented declareFunction, no body
;; (defun kbq-open-query-set-run-output-stream (filename &optional if-exists) ...) -- commented declareFunction, no body
;; (defun kct-open-test-set-run-output-stream (filename &optional if-exists) ...) -- commented declareFunction, no body
;; (defun kbq-save-query-set-run-preamble (query-set-run &optional stream) ...) -- commented declareFunction, no body
;; (defun kct-save-test-set-run-preamble (test-set-run &optional stream) ...) -- commented declareFunction, no body
;; (defun kbq-save-query-run (query-run stream) ...) -- commented declareFunction, no body
;; (defun kct-save-test-run (test-run stream) ...) -- commented declareFunction, no body


;;; Macros: do-query-set-run / do-query-set-run-query-runs

;; TODO - reconstructed from Internal Constants: arglist $list324 ((QUERY-SET-RUN QUERY-RUN FILENAME &KEY DONE) &BODY BODY),
;; gensyms $sym327 STREAM, $sym328 DONE-VAR; operators $sym329 PROGN, $sym330 CHECK-TYPE,
;; $sym332 WITH-PRIVATE-BINARY-FILE, $sym334 WITH-CFASL-COMMON-SYMBOLS,
;; $sym336 WITH-NEW-CFASL-INPUT-GUID-STRING-RESOURCE, $sym337 KBQ-LOAD-QUERY-SET-RUN-INT,
;; $sym339 WHILE, $sym340 CNOT, $sym341 KBQ-LOAD-QUERY-RUN-INT, $sym342 PWHEN,
;; $sym344 CSETQ, $sym346 PUNLESS, $sym347 KBQ-NCLEAN-QUERY-RUN, $kw353 :EOF.
;; No visible expansion sites; loop structure below (while/pwhen/punless) is a best guess.
;; Opens FILENAME as a binary cfasl stream, loads the query-set-run header, then
;; iterates loading query-runs while not DONE and not EOF, binding each to
;; QUERY-RUN for BODY, with cleanup via kbq-nclean-query-run.
(defmacro do-query-set-run ((query-set-run query-run filename &key done) &body body)
  (with-temp-vars (stream done-var)
    `(progn
       (check-type ,filename stringp)
       (with-private-binary-file (,stream ,filename :input)
         (with-cfasl-common-symbols (kbq-cfasl-common-symbols)
           (with-new-cfasl-input-guid-string-resource
             (clet ((,query-set-run (kbq-load-query-set-run-int ,stream))
                    (,done-var ,done))
               (while (cnot ,done-var)
                 (clet ((,query-run (kbq-load-query-run-int ,stream)))
                   (pwhen (eq :eof ,query-run)
                     (csetq ,done-var t))
                   (punless ,done-var
                     ,@body
                     (kbq-nclean-query-run ,query-run)))))))))))

;; TODO - reconstructed from Internal Constants: arglist $list348 ((QUERY-RUN FILENAME &KEY DONE) &BODY BODY),
;; gensyms $sym349 QUERY-SET-RUN, $sym350 IGNORE; operators $sym329 PROGN,
;; $sym332 WITH-PRIVATE-BINARY-FILE, $sym334 WITH-CFASL-COMMON-SYMBOLS,
;; $sym336 WITH-NEW-CFASL-INPUT-GUID-STRING-RESOURCE, $sym337 KBQ-LOAD-QUERY-SET-RUN-INT,
;; $sym338 CSOME, $sym341 KBQ-LOAD-QUERY-RUN-INT, $sym342 PWHEN, $sym347 KBQ-NCLEAN-QUERY-RUN.
;; No visible expansion sites; csome loop structure is a best guess.
;; Variant of do-query-set-run that ignores the query-set-run header and only
;; iterates over query-runs.
(defmacro do-query-set-run-query-runs ((query-run filename &key done) &body body)
  (with-temp-vars (stream query-set-run-var)
    `(progn
       (check-type ,filename stringp)
       (with-private-binary-file (,stream ,filename :input)
         (with-cfasl-common-symbols (kbq-cfasl-common-symbols)
           (with-new-cfasl-input-guid-string-resource
             (clet ((,query-set-run-var (kbq-load-query-set-run-int ,stream)))
               (declare (ignore ,query-set-run-var))
               (csome (,query-run (kbq-load-query-run-int ,stream) ,done)
                 (pwhen (eq :eof ,query-run)
                   (return-from do-query-set-run-query-runs nil))
                 ,@body
                 (kbq-nclean-query-run ,query-run)))))))))

;; (defun kbq-load-query-set-run (filename) ...) -- commented declareFunction, no body
;; (defun kbq-load-query-set-run-int (stream) ...) -- commented declareFunction, no body
;; (defun kbq-load-query-run-int (stream) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-nmerge-query-runs (query-set-run query-runs) ...) -- commented declareFunction, no body
;; (defun kct-load-test-set-run (filename) ...) -- commented declareFunction, no body
;; (defun kct-test-set-run-nmerge-test-runs (test-set-run test-runs) ...) -- commented declareFunction, no body
;; (defun kbq-nclean-query-set-run (query-set-run) ...) -- commented declareFunction, no body
;; (defun kct-nclean-test-set-run (test-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-nclean-query-run (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-strip-results-from-query-set-run-file (filename &optional new-filename) ...) -- commented declareFunction, no body
;; (defun kbq-strip-suffix-from-filename (filename) ...) -- commented declareFunction, no body
;; (defun kct-strip-suffix-from-filename (filename) ...) -- commented declareFunction, no body
;; (defun kbq-filter-query-set-run-by-property-value (query-set-run property value comparison &optional args) ...) -- commented declareFunction, no body
;; (defun kbq-filter-query-set-run-by-test (query-set-run property test &optional args) ...) -- commented declareFunction, no body
;; (defun kct-filter-test-set-run-by-test (test-set-run property test &optional args) ...) -- commented declareFunction, no body
;; (defun kbq-answerable-query-set-run (query-set-run) ...) -- commented declareFunction, no body
;; (defun kct-succeeding-test-set-run (test-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-unanswerable-query-set-run (query-set-run) ...) -- commented declareFunction, no body
;; (defun kct-failing-test-set-run (test-set-run) ...) -- commented declareFunction, no body
;; (defun kct-common-sense-test-set-run (test-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-same-property-value-queries (query-set-run1 query-set-run2 property &optional args extra) ...) -- commented declareFunction, no body
;; (defun kbq-mutually-answerable-queries (query-set-runs) ...) -- commented declareFunction, no body
;; (defun kbq-mutually-unanswerable-queries (query-set-runs) ...) -- commented declareFunction, no body
;; (defun kbq-fast-queries (query-set-run &optional threshold) ...) -- commented declareFunction, no body
;; (defun kct-mutually-succeeding-tests (test-set-runs) ...) -- commented declareFunction, no body
;; (defun kct-mutually-failing-tests (test-set-runs) ...) -- commented declareFunction, no body
;; (defun kbq-mutually-answerable-query-set-runs (query-set-run1 query-set-run2) ...) -- commented declareFunction, no body
;; (defun kbq-mutually-unanswerable-query-set-runs (query-set-run1 query-set-run2) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-runs-common-queries (query-set-runs) ...) -- commented declareFunction, no body
;; (defun kbq-common-queries-query-set-runs (query-set-runs) ...) -- commented declareFunction, no body
;; (defun kbq-common-queries-two-query-set-runs (query-set-run1 query-set-run2) ...) -- commented declareFunction, no body
;; (defun kct-common-tests-test-set-runs (test-set-runs) ...) -- commented declareFunction, no body
;; (defun kct-mutually-succeeding-test-set-runs (test-set-run1 test-set-run2) ...) -- commented declareFunction, no body
;; (defun kct-mutually-failing-test-set-runs (test-set-run1 test-set-run2) ...) -- commented declareFunction, no body
;; (defun kbq-same-answer-count-query-set-runs (query-set-run1 query-set-run2) ...) -- commented declareFunction, no body
;; (defun kbq-different-answer-count-query-set-runs (query-set-run1 query-set-run2) ...) -- commented declareFunction, no body
;; (defun kbq-filter-to-queries-int (query-set-run queries invertP) ...) -- commented declareFunction, no body
;; (defun kbq-filter-query-set-run-to-queries-lambda (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-filter-query-set-run-to-queries-not-lambda (query-run) ...) -- commented declareFunction, no body


;;; Filter control parameters

(defparameter *kbq-filter-query-set-run-to-queries* nil)

(defparameter *kct-filter-test-set-run-to-tests* nil)

;; (defun kbq-filter-query-set-run-to-queries (query-set-run queries &optional invertP) ...) -- commented declareFunction, no body
;; (defun kct-filter-test-set-run-to-tests-lambda (test-run) ...) -- commented declareFunction, no body
;; (defun kct-filter-test-set-run-to-tests-not-lambda (test-run) ...) -- commented declareFunction, no body
;; (defun kct-filter-test-set-run-to-tests (test-set-run tests &optional invertP) ...) -- commented declareFunction, no body
;; (defun kbq-filter-query-set-run-to-query-collection (query-set-run collection &optional mt) ...) -- commented declareFunction, no body
;; (defun kct-filter-test-set-run-to-test-collection (test-set-run collection &optional mt) ...) -- commented declareFunction, no body


;;; Cached all-instances-among

(deflexical *cached-all-instances-among-caching-state* nil)

;; (defun clear-cached-all-instances-among () ...) -- commented declareFunction, body was missing-larkc 3001
;; (defun remove-cached-all-instances-among (collection-a collection-b mt) ...) -- commented declareFunction, no body
;; (defun cached-all-instances-among-internal (collection-a collection-b mt) ...) -- commented declareFunction, no body
;; (defun cached-all-instances-among (collection-a collection-b mt) ...) -- commented declareFunction, no body
;; (defun kbq-queries-common-to-all-query-set-runs (query-set-runs) ...) -- commented declareFunction, no body
;; (defun kct-tests-common-to-all-test-set-runs (test-set-runs) ...) -- commented declareFunction, no body
;; (defun kct-consistently-succeeding-tests (test-set-runs) ...) -- commented declareFunction, no body
;; (defun kct-consistently-succeeding-test-set-runs (test-set-runs) ...) -- commented declareFunction, no body


;;; Summary statistics

(deflexical *kbq-summary-statistics*
    '(:total :increase
      :total-success :increase
      :total-failure :decrease
      :total-error :decrease
      :total-lumpy :decrease
      :total-answerable :increase
      :total-unanswerable :decrease
      :sum-answer-count :increase
      :mean-answer-count :increase
      :median-answer-count :increase
      :mean-time-to-first-answer :decrease
      :median-time-to-first-answer :decrease
      :stdev-time-to-first-answer :neither
      :mean-complete-time-to-first-answer :decrease
      :median-complete-time-to-first-answer :decrease
      :stdev-complete-time-to-first-answer :neither
      :mean-time-to-last-answer :decrease
      :median-time-to-last-answer :decrease
      :stdev-time-to-last-answer :neither
      :sum-answerability-time :decrease
      :mean-answerability-time :decrease
      :stdev-answerability-time :neither
      :median-answerability-time :decrease
      :sum-total-time :decrease
      :mean-total-time :decrease
      :stdev-total-time :neither
      :median-total-time :decrease
      :sum-complete-total-time :decrease
      :mean-complete-total-time :decrease
      :stdev-complete-total-time :neither
      :median-complete-total-time :decrease
      :median-time-per-answer :decrease
      :median-complete-time-per-answer :decrease)
  "[Cyc] The statistics we want to see in the summary, and whether it's good for them to increase or decrease.")

(defparameter *kbq-progress-stream* nil)

(defparameter *kbq-benchmark-outlier-timeout* 3600)


;;; Macros: run-kbq-experiment / run-kct-experiment

;; TODO - reconstructed from Internal Constants: arglist $list172, operator $sym10 CLET,
;; helper $sym187 RUN-KBQ-EXPERIMENT-INTERNAL. Registered as macro-helper at
;; setup with register-macro-helper $sym190 RUN-KBQ-EXPERIMENT.
;; No visible expansion sites; exact keyword-to-plist shape is a best guess.
;; The macro collects its keyword arguments into a plist and dispatches to the
;; helper function run-kbq-experiment-internal.
(defmacro run-kbq-experiment (&key query-spec-set filename analysis-filename
                                keepalive-filename comment overriding-query-properties
                                (metrics '(all-arete-query-metrics))
                                (outlier-timeout '*kbq-default-outlier-timeout*)
                                incremental (include-results t) (randomize nil)
                                (skip 0) count (if-file-exists :overwrite))
  (list 'run-kbq-experiment-internal
        (list 'list :query-spec-set query-spec-set
              :filename filename
              :analysis-filename analysis-filename
              :keepalive-filename keepalive-filename
              :comment comment
              :overriding-query-properties overriding-query-properties
              :metrics metrics
              :outlier-timeout outlier-timeout
              :incremental incremental
              :include-results include-results
              :randomize randomize
              :skip skip
              :count count
              :if-file-exists if-file-exists)))

;; (defun run-kbq-experiment-internal (args) ...) -- commented declareFunction, no body
;; (defun print-kbq-experiment-analysis-to-file (query-set-run analysis-filename experiment-args) ...) -- commented declareFunction, no body
;; (defun kbq-erroring-queries (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-erroring-query-count (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-count-erroring-query-runs (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-erroring-query-run? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-if-file-exists-handling-p (object) ...) -- commented declareFunction, no body
;; (defun kbq-experiment-augmentability-status (filename args) ...) -- commented declareFunction, no body
;; (defun kbq-setup-file-handling (filename if-file-exists args) ...) -- commented declareFunction, no body
;; (defun kbq-queries-not-yet-run (filename query-specs) ...) -- commented declareFunction, no body
;; (defun kbq-compute-rerun-errors-filename (filename) ...) -- commented declareFunction, no body
;; (defun kbq-candidate-rerun-errors-filename (filename n) ...) -- commented declareFunction, no body
;; (defun kbq-load-query-set-run-and-merge-reruns (filename) ...) -- commented declareFunction, no body
;; (defun kbq-merge-query-set-run-with-rerun (query-set-run rerun-query-set-run) ...) -- commented declareFunction, no body

;; TODO - reconstructed from Internal Constants: arglist $list204, operator $sym10 CLET,
;; helper $sym210 RUN-KCT-EXPERIMENT-INTERNAL. Registered as macro-helper at
;; setup with register-macro-helper $sym212 RUN-KCT-EXPERIMENT.
;; No visible expansion sites; exact keyword-to-plist shape is a best guess.
;; The macro collects its keyword arguments into a plist and dispatches to the
;; helper function run-kct-experiment-internal.
(defmacro run-kct-experiment (&key test-spec-set filename analysis-filename
                                keepalive-filename comment overriding-query-properties
                                (overriding-metrics '(all-arete-query-metrics))
                                (outlier-timeout '*kbq-outlier-timeout*)
                                incremental (include-results t)
                                (if-file-exists :overwrite) (expose-runstate nil)
                                (randomize nil) (skip 0) count)
  (list 'run-kct-experiment-internal
        (list 'list :test-spec-set test-spec-set
              :filename filename
              :analysis-filename analysis-filename
              :keepalive-filename keepalive-filename
              :comment comment
              :overriding-query-properties overriding-query-properties
              :overriding-metrics overriding-metrics
              :outlier-timeout outlier-timeout
              :incremental incremental
              :include-results include-results
              :if-file-exists if-file-exists
              :expose-runstate expose-runstate
              :randomize randomize
              :skip skip
              :count count)))

;; (defun run-kct-experiment-internal (args) ...) -- commented declareFunction, no body
;; (defun print-kct-experiment-analysis-to-file (test-set-run analysis-filename experiment-args) ...) -- commented declareFunction, no body
;; (defun kct-erroring-tests (test-set-run) ...) -- commented declareFunction, no body
;; (defun kct-erroring-test-count (test-set-run) ...) -- commented declareFunction, no body
;; (defun kct-count-erroring-test-runs (test-set-run) ...) -- commented declareFunction, no body
;; (defun kct-erroring-test-run? (test-run) ...) -- commented declareFunction, no body
;; (defun kct-setup-file-handling (filename if-file-exists args) ...) -- commented declareFunction, no body
;; (defun kct-tests-not-yet-run (filename test-specs) ...) -- commented declareFunction, no body
;; (defun kct-compute-rerun-errors-filename (filename) ...) -- commented declareFunction, no body
;; (defun kct-candidate-rerun-errors-filename (filename n) ...) -- commented declareFunction, no body
;; (defun kct-load-test-set-run-and-merge-reruns (filename) ...) -- commented declareFunction, no body
;; (defun kct-merge-test-set-run-with-rerun (test-set-run rerun-test-set-run) ...) -- commented declareFunction, no body


;;; Commented-out stubs — grouped by subject, from the declareFunctions block

;; (defun kct-success-result-p (object) ...) -- commented declareFunction, no body
;; (defun kct-failure-result-p (object) ...) -- commented declareFunction, no body
;; (defun kct-error-result-p (object) ...) -- commented declareFunction, no body
;; (defun kbq-cfasl-common-symbols () ...) -- commented declareFunction, no body
;; (defun kbq-query-run-p (object) ...) -- commented declareFunction, no body
;; (defun kbq-discard-query-run-result (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-discard-query-run-properties (query-run properties) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-query (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-result (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-extract-query-run-metric-value (query-run metric &optional default) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-answerable? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-unanswerable? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-answer-count (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-complete-total-time (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-time-to-first-answer (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-time-to-last-answer (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-complete-time-to-first-answer (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-complete-time-to-last-answer (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-steps (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-steps-to-first-answer (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-steps-to-last-answer (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-extract-query-run-property-value (query-run property) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-property-value (query-run property &optional default) ...) -- commented declareFunction, no body
;; (defun kbq-internal-real-time-to-seconds (internal-real-time) ...) -- commented declareFunction, no body
;; (defun kbq-seconds-to-internal-real-time (seconds) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-halt-reason (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-timed-out? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-tautology? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-less-than-1000-seconds? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-less-than-100-seconds? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-less-than-10-seconds? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-less-than-a-second? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-less-than-a-tenth-of-a-second? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-less-than-a-hundredth-of-a-second? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-more-than-1000-seconds? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-more-than-100-seconds? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-more-than-10-seconds? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-more-than-a-second? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-more-than-a-tenth-of-a-second? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-total-time-more-than-a-hundredth-of-a-second? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-more-than-1000-answers? (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-run-inference-proof-spec-cons-count (query-run) ...) -- commented declareFunction, no body
;; (defun kbq-sentence-truth-query-run? (query-run) ...) -- commented declareFunction, no body
;; (defun compute-new-root-relative-answer-times (new-root-times answer-times) ...) -- commented declareFunction, no body
;; (defun kct-test-run-p (object) ...) -- commented declareFunction, no body
;; (defun kct-make-test-run (test query-run status) ...) -- commented declareFunction, no body
;; (defun kct-test-run-test (test-run) ...) -- commented declareFunction, no body
;; (defun kct-test-run-query-run (test-run) ...) -- commented declareFunction, no body
;; (defun kct-test-run-status (test-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-p (object) ...) -- commented declareFunction, no body
;; (defun kbq-make-query-set-run (query-set &optional args) ...) -- commented declareFunction, no body
;; (defun kbq-nmerge-query-set-runs (query-set-runs &optional comment) ...) -- commented declareFunction, no body
;; (defun kbq-discard-query-set-run-results (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-discard-query-set-run-properties (query-set-run properties) ...) -- commented declareFunction, no body
;; (defun kbq-make-query-set-run-from-test-set-run (test-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-property-value (query-set-run property &optional default) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-comment (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-query-runs (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-patch-level (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-internal-time-units-per-second (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-put-query-run-property (query-set-run query-run property) ...) -- commented declareFunction, no body
;; (defun kbq-extract-query-property-values (query-set-run property) ...) -- commented declareFunction, no body
;; (defun kbq-extract-metric-values (query-set-run metric &optional default) ...) -- commented declareFunction, no body
;; (defun kbq-extract-property-values (query-set-run property &optional default) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-queries (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-query-count (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-valid-queries (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-runnable-queries (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-remove-invalid-queries (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-remove-unrunnable-queries (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-compute-pad-table (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-queries-within-n-of-median (query-set-run n &optional metric) ...) -- commented declareFunction, no body
;; (defun kbq-median-metric (metric) ...) -- commented declareFunction, no body
;; (defun kbq-mean-metric (metric) ...) -- commented declareFunction, no body
;; (defun kbq-function-for-metric (metric) ...) -- commented declareFunction, no body
;; (defun kct-test-set-run-p (object) ...) -- commented declareFunction, no body
;; (defun kct-make-test-set-run (test-set &optional args) ...) -- commented declareFunction, no body
;; (defun kct-nmerge-test-set-runs (test-set-runs &optional comment) ...) -- commented declareFunction, no body
;; (defun kct-test-set-run-comment (test-set-run) ...) -- commented declareFunction, no body
;; (defun kct-test-set-run-internal-time-units-per-second (test-set-run) ...) -- commented declareFunction, no body
;; (defun kct-test-set-run-test-runs (test-set-run) ...) -- commented declareFunction, no body
;; (defun kct-test-set-run-tests (test-set-run) ...) -- commented declareFunction, no body
;; (defun kct-test-set-run-valid-tests (test-set-run) ...) -- commented declareFunction, no body
;; (defun kct-test-set-run-remove-invalid-tests (test-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-run-query (query-spec &optional override-properties outlier-timeout extra1 extra2) ...) -- commented declareFunction, no body
;; (defun kbq-run-query-and-maybe-destroy (query-spec override-properties outlier-timeout destroy?) ...) -- commented declareFunction, no body
;; (defun kbq-run-query-int (query-spec override-properties outlier-timeout) ...) -- commented declareFunction, no body
;; (defun any-kct-followup-test-formula-gafs? (test) ...) -- commented declareFunction, no body
;; (defun kct-run-test (test-spec &optional override-properties overriding-metrics outlier-timeout extra1 extra2) ...) -- commented declareFunction, no body
;; (defun kb-test-metrics-to-query-metrics (test-metrics) ...) -- commented declareFunction, no body
;; (defun kb-test-metric-to-query-metric (test-metric) ...) -- commented declareFunction, no body
;; (defun kct-compute-test-status (test-spec query-run) ...) -- commented declareFunction, no body
;; (defun kct-compute-janus-test-status (test-spec query-run) ...) -- commented declareFunction, no body
;; (defun kct-followup-test-formula-all-holds? (test-spec query-run formula mt backchain number time depth) ...) -- commented declareFunction, no body
;; (defun kct-followup-test-formula-some-holds? (test-spec query-run formula mt backchain number) ...) -- commented declareFunction, no body
;; (defun kct-followup-test-formula-none-holds? (test-spec query-run formula mt backchain number) ...) -- commented declareFunction, no body
;; (defun kct-followup-test-formula-result (test-spec query-run formula mt backchain number) ...) -- commented declareFunction, no body
;; (defun kct-test-query-results-satisfy-exact-set-of-binding-sets (results expected) ...) -- commented declareFunction, no body
;; (defun kct-test-query-results-satisfy-wanted-binding-sets (results wanted) ...) -- commented declareFunction, no body
;; (defun kct-test-query-results-satisfy-unwanted-binding-sets (results unwanted) ...) -- commented declareFunction, no body
;; (defun kct-test-query-results-satisfy-binding-sets-cardinality (results cardinality) ...) -- commented declareFunction, no body
;; (defun kct-test-query-results-satisfy-binding-sets-min-cardinality (results min) ...) -- commented declareFunction, no body
;; (defun kct-test-query-results-satisfy-binding-sets-max-cardinality (results max) ...) -- commented declareFunction, no body
;; (defun why-kct-failure (test-spec query-run) ...) -- commented declareFunction, no body
;; (defun why-kct-binding-cardinality-failure (test-spec query-run) ...) -- commented declareFunction, no body
;; (defun why-kct-binding-match-failure (test-spec query-run) ...) -- commented declareFunction, no body
;; (defun kct-format-binding-sets-list (binding-sets-list) ...) -- commented declareFunction, no body
;; (defun kbq-run-query-set (query-spec-set &optional filename analysis-filename keepalive-filename comment overriding-query-properties metrics outlier-timeout incremental include-results randomize skip count) ...) -- commented declareFunction, no body
;; (defun abort-kbq-run-query-set () ...) -- commented declareFunction, no body
;; (defun kbq-query-spec-set-elements (query-spec-set &optional randomize skip) ...) -- commented declareFunction, no body
;; (defun all-instantiations-via-inference (expression mt) ...) -- commented declareFunction, no body
;; (defun kbq-test-collection-to-query-set (test-collection) ...) -- commented declareFunction, no body
;; (defun kct-run-test-set (test-spec-set &optional filename analysis-filename keepalive-filename comment overriding-query-properties overriding-metrics outlier-timeout incremental include-results expose-runstate randomize skip count) ...) -- commented declareFunction, no body
;; (defun abort-kct-run-test-set () ...) -- commented declareFunction, no body
;; (defun kct-test-spec-set-elements (test-spec-set &optional randomize skip) ...) -- commented declareFunction, no body
;; (defun show-query-runs-that-became-unanswerable (query-set-run1 query-set-run2 &optional stream mt args) ...) -- commented declareFunction, no body
;; (defun show-query-runs-that-changed-answer-count (query-set-run1 query-set-run2 &optional stream mt args) ...) -- commented declareFunction, no body
;; (defun show-query-runs-int (query-set-run1 query-set-run2 predicate stream message args) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-answerable-counts (query-set-run property) ...) -- commented declareFunction, no body
;; (defun kct-compare-test-set-run-statuses (test-set-run1 test-set-run2) ...) -- commented declareFunction, no body
;; (defun kct-summarize-compare-test-set-run-statuses (test-set-run1 test-set-run2) ...) -- commented declareFunction, no body
;; (defun kct-lookup-test-run (test-run test-set-run) ...) -- commented declareFunction, no body
;; (defun kct-test-equal (test-run1 test-run2) ...) -- commented declareFunction, no body
;; (defun kct-compare-test-run-statuses (test-run1 test-run2) ...) -- commented declareFunction, no body
;; (defun kbq-analyze-query-set-runs (query-set-run1 query-set-run2 &optional statistics) ...) -- commented declareFunction, no body
;; (defun kct-analyze-test-set-runs (test-set-run1 test-set-run2 &optional statistics) ...) -- commented declareFunction, no body
;; (defun kbq-compare-analysis (analysis1 analysis2) ...) -- commented declareFunction, no body
;; (defun significant-digits-if-float (number digits) ...) -- commented declareFunction, no body
;; (defun kbq-print-analysis (analysis) ...) -- commented declareFunction, no body
;; (defun kbq-analyze-query-set-run (query-set-run &optional statistics) ...) -- commented declareFunction, no body
;; (defun kct-analyze-test-set-run (test-set-run &optional statistics) ...) -- commented declareFunction, no body
;; (defun kbq-analyze-query-runs (query-runs statistics) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-total-answerable (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-last-query-from-file (filename) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-identify-probable-segfault-from-file (filename stream) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-identify-probable-segfault (query-set-run stream) ...) -- commented declareFunction, no body
;; (defun kbq-query-set-run-identify-probable-segfault-int (query-set-run stream) ...) -- commented declareFunction, no body
;; (defun kct-analyze-test-runs (test-runs statistics) ...) -- commented declareFunction, no body
;; (defun kct-test-set-run-identify-probable-segfault (test-set-run stream) ...) -- commented declareFunction, no body
;; (defun analyze-kbq-experiments (filenames output-filename &optional arg1 arg2 arg3 arg4 arg5) ...) -- commented declareFunction, no body
;; (defun kbq-non-lumpy-query-set-run (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-lumpy-queries (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-lumpy-query-count (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-count-lumpy-query-runs (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-lumpy-query-run? (query-run) ...) -- commented declareFunction, no body
;; (defun show-kct-test-set-run-summary (test-set-run &optional stream) ...) -- commented declareFunction, no body
;; (defun kbq-show-halt-reason-histogram (query-set-run) ...) -- commented declareFunction, no body
;; (defun kbq-query-literal-count (query) ...) -- commented declareFunction, no body
;; (defun kbq-single-literal-query-p (query) ...) -- commented declareFunction, no body
;; (defun kbq-progress-stream () ...) -- commented declareFunction, no body
;; (defun kbq-benchmark-run-and-report (tests overriding-query-properties overriding-metrics) ...) -- commented declareFunction, no body
;; (defun kbq-benchmark-run-in-background (tests overriding-query-properties overriding-metrics) ...) -- commented declareFunction, no body
;; (defun kbq-benchmark-run (tests overriding-query-properties overriding-metrics &optional extra1 extra2 extra3) ...) -- commented declareFunction, no body
;; (defun kbq-benchmark-report (filename &optional extra) ...) -- commented declareFunction, no body
;; (defun kbq-benchmark-report-for-test (filename test &optional extra) ...) -- commented declareFunction, no body


;;; Print trampolines — stubs for stripped LarKC bodies

;; (defun kbq-runstate-print-function-trampoline (object stream) ...) -- active declareFunction, no body
;; (defun kct-runstate-print-function-trampoline (object stream) ...) -- active declareFunction, no body
;; (defun kct-set-runstate-print-function-trampoline (object stream) ...) -- active declareFunction, no body


;;; Setup toplevel

(toplevel
  ;; access-macros registrations
  (register-macro-helper 'kbq-cfasl-common-symbols 'do-query-set-run)
  (declare-defglobal '*last-query-set-run*)
  (register-macro-helper 'run-kbq-experiment-internal 'run-kbq-experiment)
  (declare-defglobal '*last-test-set-run*)
  (register-macro-helper 'run-kct-experiment-internal 'run-kct-experiment)
  (declare-defglobal '*runstate-isg*)
  (declare-defglobal '*runstate-index*)
  (register-macro-helper 'kbq-load-query-set-run-int 'do-query-set-run)
  (register-macro-helper 'kbq-load-query-run-int 'do-query-set-run)
  (register-macro-helper 'kbq-nclean-query-run 'do-query-set-run)
  (note-globally-cached-function 'cached-all-instances-among))
