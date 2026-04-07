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

(defparameter *it-output-format* :standard)

(defparameter *cyc-test-debug?* nil
  "[Cyc] Set this to T if you want to debug the tests (not catch errors)")

(defparameter *run-tiny-kb-tests-in-full-kb?* t
  "[Cyc] Whether to run tests that only require the tiny KB in the full KB. The default is T so that it's easy to run all tests on a full KB, but should be bound to NIL when testing on both a tiny and a full KB.")

(defparameter *test-real-time-pruning?* nil
  "[Cyc] Whether to test real-time while-inference-is-running pruning. This will force :COMPUTE-ANSWER-JUSTIFICATIONS? to NIL and will only run tests where that makes sense.")

(defun testing-real-time-pruning? ()
  *test-real-time-pruning?*)

(deflexical *cyc-test-verbosity-levels* (list :silent :terse :verbose)
  "[Cyc] The possible levels of verbosity for Cyc tests.")

(defparameter *cyc-test-filename* nil
  "[Cyc] Bound to the current file being loaded, so that the tests can know what file they're in")

(defparameter *warn-on-duplicate-cyc-test-names?* nil
  "[Cyc] Whether we should warn if a test has the same name as another test. This often happens when tests are redefined or updated, so we only want to do it when we're loading tests from a clean initial state.")

(deflexical *cyc-test-result-success-values* '(:success :regression-success)
  "[Cyc] Test results that mean that the test succeeded.")

(deflexical *cyc-test-result-failure-values* '(:failure :regression-failure :abnormal :error)
  "[Cyc] Test results that mean that the test failed.")

(deflexical *cyc-test-result-ignore-values* '(:non-regression-success :non-regression-failure :not-run :invalid)
  "[Cyc] Test results that mean that the test was ignored, or that the test results should be ignored, and counted as neither a success nor a failure.")

(deflexical *cyc-test-result-values* (append *cyc-test-result-success-values*
                                             *cyc-test-result-failure-values*
                                             *cyc-test-result-ignore-values*)
  "[Cyc] All possible results for tests.")

(deflexical *cyc-test-type-table* '((:iut "inference unit test")
                                    (:it "inference test")
                                    (:rmt "removal module test")
                                    (:tmt "transformation module test")
                                    (:rmct "removal module cost test")
                                    (:ert "evaluatable relation test")
                                    (:tct "test case table")
                                    (:kct "KB content test"))
  "[Cyc] The table of known Cyc test types. Column 1 is a uniquely identifying keyword. Column 2 is a string description of the test type.")

;; (defun cyc-test-kb-p (object) ...) -- active declareFunction, no body
;; (defun cyc-test-verbosity-level-p (object) ...) -- active declareFunction, no body
;; (defun cyc-test-output-format-p (object) ...) -- active declareFunction, no body
;; (defun cyc-test-result-p (object) ...) -- active declareFunction, no body
;; (defun cyc-test-success-result-p (object) ...) -- active declareFunction, no body
;; (defun cyc-test-failure-result-p (object) ...) -- active declareFunction, no body
;; (defun cyc-test-ignore-result-p (object) ...) -- active declareFunction, no body
;; (defun cyc-test-result-< (result1 result2) ...) -- active declareFunction, no body
;; (defun cyc-test-type-p (object) ...) -- active declareFunction, no body
;; (defun cyc-test-type-spec-p (object) ...) -- active declareFunction, no body
;; (defun cyc-test-type-pretty-name (type) ...) -- active declareFunction, no body

(defglobal *cyc-tests*
  (if (boundp '*cyc-tests*)
      *cyc-tests*
      nil)
  "[Cyc] The master ordered list of all Cyc test objects.")

(defun cyc-tests ()
  *cyc-tests*)

;; (defun undefine-all-cyc-tests () ...) -- active declareFunction, no body

;; TODO - Macro DO-CYC-TESTS
;; Evidence: $list12 = ((CYC-TEST &KEY DONE) &BODY BODY)
;; $sym16$CSOME, $list17 = (CYC-TESTS)
;; Reconstructed from Internal Constants:
(defmacro do-cyc-tests ((cyc-test &key done) &body body)
  `(csome (,cyc-test (cyc-tests) ,done)
     ,@body))

;; TODO - Macro PROGRESS-DO-CYC-TESTS
;; Evidence: $list18 = ((CYC-TEST &OPTIONAL (MESSAGE "Iterating over all Cyc tests")) &BODY BODY)
;; $sym20$PROGRESS_CDOLIST, $list17 = (CYC-TESTS)
(defmacro progress-do-cyc-tests ((cyc-test &optional (message "Iterating over all Cyc tests")) &body body)
  `(progress-cdolist (,cyc-test (cyc-tests) ,message)
     ,@body))

;; (defun cyc-test-count () ...) -- active declareFunction, no body
;; (defun no-cyc-tests-defined? () ...) -- active declareFunction, no body

(defglobal *cyc-test-by-name*
  (if (and (boundp '*cyc-test-by-name*)
           (hash-table-p *cyc-test-by-name*))
      *cyc-test-by-name*
      (make-hash-table :size 212 :test #'equal))
  "[Cyc] An index from NAME -> Cyc Test object")

(defglobal *cyc-test-by-dwimmed-name*
  (if (and (boundp '*cyc-test-by-dwimmed-name*)
           (hash-table-p *cyc-test-by-dwimmed-name*))
      *cyc-test-by-dwimmed-name*
      (make-hash-table :size 212 :test #'equal))
  "[Cyc] An index from DWIMMED-NAME -> list of Cyc Test objects")

(defun index-cyc-test-by-name (ct name)
  (when (and *warn-on-duplicate-cyc-test-names?*
             (gethash name *cyc-test-by-name*))
    (warn "A Cyc test named ~a already existed; overwriting" name))
  (setf (gethash name *cyc-test-by-name*) ct)
  (setf (gethash name *cyc-test-by-dwimmed-name*)
        (nconc (gethash name *cyc-test-by-dwimmed-name*) (list ct)))
  (when (consp name)
    (missing-larkc 32431))
  (when (cyc-tests-initialized?)
    (let ((rmt (cyc-test-guts ct)))
      (when (funcall 'removal-module-test-p rmt)
        (missing-larkc 32432))))
  (when (cyc-tests-initialized?)
    (let ((rmct (cyc-test-guts ct)))
      (when (funcall 'removal-module-cost-test-p rmct)
        (missing-larkc 32433))))
  ct)

;; (defun unindex-cyc-test-by-name (ct name) ...) -- active declareFunction, no body
;; (defun my-pushnew-to-end-hash (key value table) ...) -- active declareFunction, no body
;; (defun my-delete-value-from-hash (key value table) ...) -- active declareFunction, no body

(defun index-all-cyc-tests-by-name ()
  (dolist (ct (cyc-tests))
    (index-cyc-test-by-name ct (cyc-test-name ct))))

(defstruct (cyc-test
            (:conc-name "CT-")
            (:constructor make-cyc-test-struct)
            (:print-function print-cyc-test))
  file
  guts)

(defun make-cyc-test (&optional arglist)
  (let ((obj (make-cyc-test-struct)))
    (loop for (key value) on arglist by #'cddr do
      (case key
        (:file (setf (ct-file obj) value))
        (:guts (setf (ct-guts obj) value))
        (otherwise (error "Invalid slot ~S for construction function" key))))
    obj))

(defun cyc-test-print-function-trampoline (object stream)
  ;; Likely calls print-cyc-test -- evidence: $sym35$PRINT_CYC_TEST is the print function
  (missing-larkc 32446))

;; (defun print-cyc-test (object stream depth) ...) -- active declareFunction, no body

(defun new-cyc-test (file guts)
  (when file
    (check-type file string))
  (if (cyc-tests-initialized?)
      (must (funcall 'cyc-test-guts-p guts)
            "~s is not a CYC-TEST-GUTS-P" guts)
      (check-type guts (satisfies generic-test-case-table-p)))
  (let ((ct (make-cyc-test)))
    (setf (ct-file ct) file)
    (setf (ct-guts ct) guts)
    (let* ((name (if (cyc-tests-initialized?)
                     (funcall 'cyc-test-name ct)
                     (generic-test-case-table-name guts)))
           (existing-ct (find-cyc-test-by-exact-name name)))
      (when existing-ct
        (setf *cyc-tests* (delete existing-ct *cyc-tests* :test #'eq))
        (missing-larkc 32458))
      (push-last ct *cyc-tests*)
      (index-cyc-test-by-name ct name))
    ct))

;; (defun cyc-test-file (ct) ...) -- active declareFunction, no body
;; This is NOT the defstruct accessor ct-file; it's a higher-level wrapper.

(defun cyc-test-guts (ct)
  (ct-guts ct))

(defun cyc-test-type (ct)
  (or (cyc-test-type-permissive ct)
      (error "Cyc test of unexpected type: ~s" ct)))

;; (defun cyc-test-guts-p (guts) ...) -- active declareFunction, no body

(defun cyc-test-type-permissive (ct)
  (let ((guts (cyc-test-guts ct)))
    (cyc-test-guts-type guts)))

(defun cyc-test-guts-type (guts)
  (cond
    ((generic-test-case-table-p guts) :tct)
    ((progn (missing-larkc 32334)) :iut)
    ((progn (missing-larkc 32476)) :rmt)
    ((progn (missing-larkc 32510)) :rmct)
    ((progn (missing-larkc 32552)) :tmt)
    ((progn (missing-larkc 32268)) :ert)
    ((progn (missing-larkc 1237)) :it)
    ((progn (missing-larkc 1431)) :kct)
    (t nil)))

(defun cyc-test-name (ct)
  "[Cyc] Names are assumed to be unique, even across type"
  (let ((guts (cyc-test-guts ct)))
    (case (cyc-test-type ct)
      (:iut (missing-larkc 32325))
      (:it guts)
      (:rmt (missing-larkc 32474))
      (:tmt (missing-larkc 32551))
      (:rmct (missing-larkc 32508))
      (:ert (missing-larkc 32265))
      (:tct (generic-test-case-table-name guts))
      (:kct (missing-larkc 1))
      (otherwise (error "Cyc test of unexpected type: ~s" guts)))))

;; (defun cyc-test-kb (ct) ...) -- active declareFunction, no body
;; (defun cyc-test-owner (ct) ...) -- active declareFunction, no body
;; (defun cyc-test-working? (ct) ...) -- active declareFunction, no body
;; (defun cyc-test-comment (ct) ...) -- active declareFunction, no body
;; (defun cyc-test-project (ct) ...) -- active declareFunction, no body
;; (defun cyc-test-names-mentioning-invalid-constants (&optional type) ...) -- active declareFunction, no body
;; (defun cyc-test-mentions-invalid-constant? (ct) ...) -- active declareFunction, no body
;; (defun cyc-test-invalid-constant-test-names (ct) ...) -- active declareFunction, no body
;; (defun tiny-kb-cyc-test-p (ct) ...) -- active declareFunction, no body
;; (defun full-kb-cyc-test-p (ct) ...) -- active declareFunction, no body
;; (defun non-working-cyc-tests (&optional type) ...) -- active declareFunction, no body

(defun find-cyc-test-by-exact-name (name)
  "[Cyc] @return cyc-test-run-p"
  (gethash name *cyc-test-by-name*))

;; (defun find-cyc-test (name) ...) -- active declareFunction, no body
;; (defun find-cyc-tests (name) ...) -- active declareFunction, no body
;; (defun find-cyc-tests-by-name (name) ...) -- active declareFunction, no body
;; (defun find-cyc-test-filename (name) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list68 = (NAME &KEY (VERBOSITY :TERSE) BROWSABLE? BLOCK? (OUTPUT-FORMAT :STANDARD)
;;                      (STREAM (QUOTE *STANDARD-OUTPUT*)) (RUN-TINY-KB-TESTS-IN-FULL-KB? (QUOTE *RUN-TINY-KB-TESTS-IN-FULL-KB?*)))
;; $sym79$RUN_CYC_TEST_INT registered as macro helper
(defmacro run-cyc-test (name &key (verbosity :terse) browsable? block?
                                   (output-format :standard)
                                   (stream '*standard-output*)
                                   (run-tiny-kb-tests-in-full-kb? '*run-tiny-kb-tests-in-full-kb?*))
  `(run-cyc-test-int ,name ,verbosity ,browsable? ,block? ,output-format ,stream ,run-tiny-kb-tests-in-full-kb?))

;; Reconstructed from Internal Constants:
;; $list80 = (NAME &KEY BROWSABLE? BLOCK? (OUTPUT-FORMAT :STANDARD)
;;                      (STREAM (QUOTE *STANDARD-OUTPUT*)) (RUN-TINY-KB-TESTS-IN-FULL-KB? (QUOTE *RUN-TINY-KB-TESTS-IN-FULL-KB?*)))
(defmacro run-cyc-test-verbose (name &key browsable? block?
                                          (output-format :standard)
                                          (stream '*standard-output*)
                                          (run-tiny-kb-tests-in-full-kb? '*run-tiny-kb-tests-in-full-kb?*))
  `(run-cyc-test-int ,name :verbose ,browsable? ,block? ,output-format ,stream ,run-tiny-kb-tests-in-full-kb?))

;; (defun run-cyc-test-int (name verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list88 = (NAME &KEY (NTHREADS 4) (NTIMES 10) (VERBOSITY :TERSE) BROWSABLE? BLOCK?
;;                      (OUTPUT-FORMAT :STANDARD) (STREAM (QUOTE *STANDARD-OUTPUT*))
;;                      (RUN-TINY-KB-TESTS-IN-FULL-KB? (QUOTE *RUN-TINY-KB-TESTS-IN-FULL-KB?*)))
;; $sym92$RUN_CYC_TEST_PARALLEL_INT registered as macro helper
(defmacro run-cyc-test-parallel (name &key (nthreads 4) (ntimes 10) (verbosity :terse)
                                           browsable? block? (output-format :standard)
                                           (stream '*standard-output*)
                                           (run-tiny-kb-tests-in-full-kb? '*run-tiny-kb-tests-in-full-kb?*))
  `(run-cyc-test-parallel-int ,name ,nthreads ,ntimes ,verbosity ,browsable? ,block?
                              ,output-format ,stream ,run-tiny-kb-tests-in-full-kb?))

;; (defun run-cyc-test-parallel-int (name nthreads ntimes verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body
;; (defun run-cyc-test-object-parallel (ct nthreads ntimes verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body
;; (defun run-cyc-test-object (ct verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body
;; (defun run-cyc-test-iut (ct verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body
;; (defun run-cyc-test-it (ct verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body
;; (defun run-cyc-test-it-int (inference-test browsable? stream output-format) ...) -- active declareFunction, no body
;; (defun run-cyc-test-rmt (ct verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body
;; (defun run-cyc-test-tmt (ct verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body
;; (defun run-cyc-test-rmct (ct verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body
;; (defun run-cyc-test-ert (ct verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body
;; (defun run-cyc-test-tct (ct verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body
;; (defun run-cyc-test-kct (ct verbosity browsable? block? output-format stream run-tiny-kb-tests-in-full-kb?) ...) -- active declareFunction, no body

;; (defun cfasl-output-object-cyc-test-method (object stream) ...) -- active declareFunction, no body
;; (defun cfasl-wide-output-cyc-test (ct stream) ...) -- active declareFunction, no body
;; (defun cfasl-output-cyc-test-internal (ct stream) ...) -- active declareFunction, no body
;; (defun cfasl-input-cyc-test (stream) ...) -- active declareFunction, no body

(defconstant *cfasl-wide-opcode-cyc-test* 514)

;; (defun new-cyc-test-run (type name result time) ...) -- active declareFunction, no body
;; (defun cyc-test-run-p (object) ...) -- active declareFunction, no body
;; (defun cyc-test-run-type (run) ...) -- active declareFunction, no body
;; (defun cyc-test-run-name (run) ...) -- active declareFunction, no body
;; (defun cyc-test-run-result (run) ...) -- active declareFunction, no body
;; (defun cyc-test-run-time (run) ...) -- active declareFunction, no body
;; (defun cyc-test-run-cyc-test (run) ...) -- active declareFunction, no body
;; (defun cyc-test-runs-overall-result (runs) ...) -- active declareFunction, no body
;; (defun cyc-test-result-update (old-result new-result) ...) -- active declareFunction, no body
;; (defun cyc-test-runs-total-time (runs) ...) -- active declareFunction, no body
;; (defun failing-cyc-test-run-p (run) ...) -- active declareFunction, no body
;; (defun succeeding-cyc-test-run-p (run) ...) -- active declareFunction, no body
;; (defun ignored-cyc-test-run-p (run) ...) -- active declareFunction, no body
;; (defun cyc-test-run-owner (run) ...) -- active declareFunction, no body
;; (defun cyc-test-run-project (run) ...) -- active declareFunction, no body
;; (defun print-cyc-test-run-summary (run verbosity stream output-format) ...) -- active declareFunction, no body
;; (defun cyc-test-run-summary (run stream output-format) ...) -- active declareFunction, no body

(defglobal *cyc-test-files*
  (if (boundp '*cyc-test-files*)
      *cyc-test-files*
      nil)
  "[Cyc] The master ordered list of all Cyc test file objects.")

;; (defun cyc-test-files () ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list129 = ((CYC-TEST-FILE) &BODY BODY)
;; $sym130$CDOLIST, $list131 = ((CYC-TEST-FILES))
(defmacro do-cyc-test-files ((cyc-test-file) &body body)
  `(cdolist (,cyc-test-file (cyc-test-files))
     ,@body))

;; Reconstructed from Internal Constants:
;; $list132 = ((CYC-TEST-FILE &OPTIONAL (MESSAGE "Iterating over all test files")) &BODY BODY)
;; $sym20$PROGRESS_CDOLIST, $list134 = (CYC-TEST-FILES)
(defmacro progress-do-cyc-test-files ((cyc-test-file &optional (message "Iterating over all test files")) &body body)
  `(progress-cdolist (,cyc-test-file (cyc-test-files) ,message)
     ,@body))

;; (defun cyc-test-file-count () ...) -- active declareFunction, no body

(defstruct (cyc-test-file
            (:conc-name "CTF-")
            (:print-function print-cyc-test-file))
  filename
  kb)

(defun cyc-test-file-print-function-trampoline (object stream)
  ;; Likely calls print-cyc-test-file -- evidence: $sym141$PRINT_CYC_TEST_FILE is the print function
  (missing-larkc 32447))

;; (defun print-cyc-test-file (object stream depth) ...) -- active declareFunction, no body
;; (defun new-cyc-test-file (filename kb) ...) -- active declareFunction, no body
;; (defun cyc-test-file-filename (ctf) ...) -- active declareFunction, no body
;; (defun find-cyc-test-file (filename) ...) -- active declareFunction, no body

(defglobal *most-recent-cyc-test-runs*
  (if (boundp '*most-recent-cyc-test-runs*)
      *most-recent-cyc-test-runs*
      nil)
  "[Cyc] The most recent runs are saved here for the cases where they're not returned directly")

(defglobal *most-recent-cyc-test-file-load-failures*
  (if (boundp '*most-recent-cyc-test-file-load-failures*)
      *most-recent-cyc-test-file-load-failures*
      nil)
  "[Cyc] The Cyc test files which failed to load the last time LOAD-ALL-CYC-TESTS was evaluated.")

;; (defun most-recent-cyc-test-runs () ...) -- active declareFunction, no body
;; (defun most-recent-failing-cyc-test-runs () ...) -- active declareFunction, no body
;; (defun most-recent-failing-cyc-tests () ...) -- active declareFunction, no body
;; (defun most-recent-cyc-test-file-load-failures () ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list155 = (PATH &KEY (STREAM (QUOTE *STANDARD-OUTPUT*)) (VERBOSITY :TERSE)
;;                       (STOP-AT-FIRST-FAILURE? NIL) (OUTPUT-FORMAT :STANDARD)
;;                       (RUN-TINY-KB-TESTS-IN-FULL-KB? (QUOTE *RUN-TINY-KB-TESTS-IN-FULL-KB?*))
;;                       (RUN-TEST-CASE-TABLES? T) (RETURN-TEST-RUNS? NIL) (TYPE :ALL)
;;                       (RUN-NON-WORKING-TESTS NIL))
;; $sym162$RUN_ALL_CYC_TESTS_INT is NOT registered as macro helper -- no registration in setup
(defmacro run-all-cyc-tests (path &key (stream '*standard-output*) (verbosity :terse)
                                       (stop-at-first-failure? nil) (output-format :standard)
                                       (run-tiny-kb-tests-in-full-kb? '*run-tiny-kb-tests-in-full-kb?*)
                                       (run-test-case-tables? t) (return-test-runs? nil)
                                       (type :all) (run-non-working-tests nil))
  `(run-all-cyc-tests-int ,path :stream ,stream :verbosity ,verbosity
                          :stop-at-first-failure? ,stop-at-first-failure?
                          :output-format ,output-format
                          :run-tiny-kb-tests-in-full-kb? ,run-tiny-kb-tests-in-full-kb?
                          :run-test-case-tables? ,run-test-case-tables?
                          :return-test-runs? ,return-test-runs?
                          :type ,type
                          :run-non-working-tests ,run-non-working-tests))

;; (defun run-all-cyc-tests-int (path &optional stream verbosity stop-at-first-failure? output-format run-tiny-kb-tests-in-full-kb? run-test-case-tables? return-test-runs? type run-non-working-tests) ...) -- active declareFunction, no body

;; TODO - Macro RERUN-FAILING-CYC-TESTS
;; Evidence: $list163 = (&KEY (STREAM (QUOTE *STANDARD-OUTPUT*)) (VERBOSITY :VERBOSE) ...)
;; No registered macro helper found
(defmacro rerun-failing-cyc-tests (&key (stream '*standard-output*) (verbosity :verbose)
                                         (stop-at-first-failure? nil) (output-format :standard)
                                         (return-test-runs? nil) (type :all)
                                         (run-non-working-tests nil))
  `(run-all-loaded-cyc-tests :stream ,stream :verbosity ,verbosity
                             :stop-at-first-failure? ,stop-at-first-failure?
                             :output-format ,output-format
                             :return-test-runs? ,return-test-runs?
                             :type ,type
                             :run-non-working-tests ,run-non-working-tests))

;; Reconstructed from Internal Constants:
;; $list167 = (FILENAME &KEY KB)
;; $sym169$DECLARE_CYC_TEST_FILE_INT registered as macro helper
(defmacro declare-cyc-test-file (filename &key kb)
  `(declare-cyc-test-file-int ,filename ,kb))

;; Reconstructed from Internal Constants:
;; $list170 = (NAMES &KEY (STREAM (QUOTE *STANDARD-OUTPUT*)) (VERBOSITY :VERBOSE) ...)
;; $sym171$FIND_CYC_TESTS_BY_NAME suggests wrapping names in find-cyc-tests-by-name
(defmacro run-cyc-tests (names &key (stream '*standard-output*) (verbosity :verbose)
                                     (stop-at-first-failure? nil) (output-format :standard)
                                     (return-test-runs? nil) (type :all)
                                     (run-non-working-tests nil))
  `(run-all-loaded-cyc-tests :stream ,stream :verbosity ,verbosity
                             :stop-at-first-failure? ,stop-at-first-failure?
                             :output-format ,output-format
                             :return-test-runs? ,return-test-runs?
                             :type ,type
                             :run-non-working-tests ,run-non-working-tests))

;; (defun load-all-cyc-tests (path &optional stream verbosity stop-at-first-failure?) ...) -- active declareFunction, no body
;; (defun parse-testdcl-path (path) ...) -- active declareFunction, no body
;; (defun run-all-loaded-cyc-tests (&optional stream verbosity stop-at-first-failure? output-format run-tiny-kb-tests-in-full-kb? run-test-case-tables? return-test-runs? type run-non-working-tests run-all-loaded-cyc-tests-int-arg) ...) -- active declareFunction, no body
;; (defun undeclare-all-cyc-test-files () ...) -- active declareFunction, no body
;; (defun undeclare-cyc-test-file (filename) ...) -- active declareFunction, no body
;; (defun declare-cyc-test-file-int (filename kb) ...) -- active declareFunction, no body
;; (defun load-cyc-test-file (ctf stream verbosity stop-at-first-failure?) ...) -- active declareFunction, no body
;; (defun load-testdcl (path &optional stream) ...) -- active declareFunction, no body
;; (defun run-all-loaded-cyc-tests-int (stream verbosity stop-at-first-failure? output-format run-tiny-kb-tests-in-full-kb? run-test-case-tables? return-test-runs? type &optional run-non-working-tests) ...) -- active declareFunction, no body
;; (defun new-cyc-test-null-run (ct) ...) -- active declareFunction, no body
;; (defun new-cyc-test-invalid-run (ct) ...) -- active declareFunction, no body
;; (defun run-cyc-test? (ct type run-tiny-kb-tests-in-full-kb? run-non-working-tests) ...) -- active declareFunction, no body
;; (defun run-all-loaded-cyc-tests-print-header (stream run-tiny-kb-tests-in-full-kb? type) ...) -- active declareFunction, no body
;; (defun run-all-loaded-cyc-tests-print-footer (runs stream verbosity output-format non-working-tests) ...) -- active declareFunction, no body
;; (defun print-failing-cyc-tests-message (runs stream &optional verbosity output-format) ...) -- active declareFunction, no body
;; (defun print-succeeding-cyc-tests-message (runs stream &optional verbosity output-format) ...) -- active declareFunction, no body
;; (defun print-ignored-cyc-tests-message (runs stream &optional verbosity output-format) ...) -- active declareFunction, no body
;; (defun show-cyc-test-run (run verbosity stream output-format) ...) -- active declareFunction, no body

(deflexical *tests-that-dont-work-with-real-time-pruning*
  (list :canonicalize-inference-answer-justifications :non-explanatory-sentence-supports :non-explanatory-variable-map-supports :true-sentence-not-canonicalization :true-sentence-of-atomic-sentence-reduction :ist-of-atomic-sentence-reduction :relation-all-instance-iterate-2 :relation-instance-all-iterate-2 :reject-previously-proven-proofs :inference-harness-overhead :tactically-unexamined-no-good-implies-strategically-unexamined-no-good :the-set-of-elements-returns-hl-narts :the-collection-of-instances-returns-hl-narts :genlpreds-lookup-generates-correct-supports :kappa-removal-works :dont-reopen-answer-link :removal-true-sentence-universal-disjunction-14a :closed-asent-with-3-children :simple-except-when :simple-except-when-residual-transformation :partial-except-when :variable-map-except-when :true-sentence-implies-var-canonicalization :exception-tms-backward-no-op :multiple-transformation-proofs-for-closed-problem :backchain-to-removal-true-sentence-universal-disjunction-1 :backchain-to-removal-true-sentence-universal-disjunction-2 :backchain-to-removal-true-sentence-universal-disjunction-3 :collection-isa-backchain-required-4 :collection-genls-backchain-required-4 :collection-backchain-required-3 :collection-backchain-required-4 :early-removal-of-8-restricted-problems-requiring-transformation :early-new-root-of-9-restricted-problems-requiring-transformation :forward-indeterminate-result :simple-forward-pragmatic-requirement :simple-forward-pragmatic-requirement-supports :nart-isa-in-right-mt :forward-problem-store-destruction-on-conflict :forward-rule-concluding-consequent-in-wrong-mt :skolemize-forward :forward-inference-with-defns :completeness-in-low-mt-doesnt-hose-forward-inference :hypothetical-mt-completeness-assertion-doesnt-hose-forward-inference :except-mt-in-mid-mt-blocks-high-mt-from-low-mt :except-mt-in-high-mt-hoses-backward-inference :cyc-assert-with-reifiable-monad-mt :forward-rule-concluding-false :skolem-result-arg :unassert-reifiable-nat-mt :unassert-nart-mt-sentence-with-nart :unassert-reifiable-nat-mt-via-tl :canonicalize-nested-mt :function-test :nat-removal :resulttype-change :meta-assertion-removal :arg-type-mt-denoting-function :max-floor-mts-of-nat :contextualized-collection-specpred-of-isa :use-defns-to-check-inference-semantically-valid-dnf :sbhl-trumps-defns :skolemize-forward-naut-genl-mt-wff-exception :one-step :two-step :two-step :two-step-arg-1 :two-step-arg-1 :many-step :cross-mt :disjunctive-syllogism :argumentation :tms-loop :reconsider-deduction :reconsider-deduction :hl-support-mt-handling :there-exists :except-when :except-when :strength-propagation :sequence-variables-inference :inference-answer-template :forward-propagate-mt :forward-propagate-mt-continue :ist-triggers-forward-inference-simple :forward-non-trigger-literal-honored :except-blocks-backward :except-blocks-forward :true-sentence-universal-disjunction-scoping :tms-reconsideration-with-backchain-forbidden :tms-for-hl-supports :assertion-direction :merge-ignores-opaque-references :mt-floors-wrt-isa-paths :min-genl-mts :min-genl-predicates :min-genls-collection :split-no-goodness-propagation :lazily-manifest-non-focals :consider-no-good-after-determining-tactics :removal-all-isa-of-type-2 :avoid-lookup-on-indeterminates :irrelevant-does-not-imply-pending :asserted-instance-of-disjoint-collections :chaining-skolem-straightforward :chaining-skolem-shallow :chaining-skolem-deep :chaining-skolem :except-decontextualized :problem-store-pruning-max-insufficient :restricted-closed-good-problems-stay-unexamined :genls-between :conjunctive-integer-between-1 :conjunctive-integer-between-2 :conjunctive-integer-between-3 :conjunctive-integer-between-4 :conjunctive-integer-between-5 :conjunctive-integer-between-6 :conjunctive-integer-between-7 :conjunctive-integer-between-8 :conjunctive-followup-additional-join-ordered :conjunctive-followup-additional-join-ordered-without-inference :circular-proofs)
  "[Cyc] A list of tests that will fail if :COMPUTE-ANSWER-JUSTIFICATIONS? is forced to NIL and/or if problem store pruning happens while they're running.")

(toplevel
  (declare-defglobal '*cyc-tests*)
  (declare-defglobal '*cyc-test-by-name*)
  (declare-defglobal '*cyc-test-by-dwimmed-name*)
  (register-macro-helper 'run-cyc-test-int 'run-cyc-test)
  (register-macro-helper 'run-cyc-test-parallel-int 'run-cyc-test-parallel)
  (register-wide-cfasl-opcode-input-function *cfasl-wide-opcode-cyc-test* 'cfasl-input-cyc-test)
  (declare-defglobal '*cyc-test-files*)
  (declare-defglobal '*most-recent-cyc-test-runs*)
  (declare-defglobal '*most-recent-cyc-test-file-load-failures*)
  (register-macro-helper 'declare-cyc-test-file-int 'declare-cyc-test-file))
