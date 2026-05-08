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

;; The following defglobals have boundp-guards in init and declare_defglobal
;; calls in setup; they are populated by (initialize-ctest).
(defglobal *default-email-notify-style-id* nil)
(defglobal *default-test-id* nil)
(defglobal *default-string-binding-set* nil)
(defglobal *default-binding-set* nil)
(defglobal *default-binding-set2* nil)
(defglobal *default-set-of-binding-sets* nil)
(defglobal *default-set-of-binding-sets2* nil)
(defglobal *default-set-of-binding-sets3* nil)
(defglobal *default-module-sentence* nil)
(defglobal *default-module-mt* nil)
(defglobal *default-module-mt2* nil)
(defglobal *default-dependency-test-id* nil)
(defglobal *default-dependency-test-id2* nil)
(defglobal *default-isa-id* nil)
(defglobal *default-isa-id2* nil)
(defglobal *default-test-query* nil)
(defglobal *default-test-mt* nil)
(defglobal *default-collection-id* nil)

(defun initialize-ctest ()
  (setf *default-email-notify-style-id*
        (to-string (constant-external-id (reader-make-constant-shell "TestResultNotification-EmailBrief"))))
  (setf *default-test-id*
        (to-string (constant-external-id (reader-make-constant-shell "TKBTemplateTestForMissingMt"))))
  (setf *default-string-binding-set*
        "(#$TheSet (#$ELInferenceBindingFn ?SOMETHING \"A SOMETHING\"))")
  (setf *default-binding-set*
        (make-kb-binding-set (list (make-kb-binding '?SOMETHING "A SOMETHING"))))
  (setf *default-binding-set2*
        (make-kb-binding-set (list (make-kb-binding '?OTHERTHING "ANOTHER THING"))))
  (setf *default-set-of-binding-sets*
        (make-kb-set-of-binding-sets (list (make-kb-binding-set (list (make-kb-binding '?SOMETHING "A SOMETHING"))))))
  (setf *default-set-of-binding-sets2*
        (make-kb-set-of-binding-sets (list (make-kb-binding-set (list (make-kb-binding '?OTHERTHING "ANOTHER THING"))))))
  (setf *default-set-of-binding-sets3*
        (make-kb-set-of-binding-sets (list (make-kb-binding-set (list (make-kb-binding '?ANOTHERTHING "YET ANOTHER THING"))))))
  (setf *default-module-sentence*
        (list (reader-make-constant-shell "genls")
              (reader-make-constant-shell "Collection")
              (reader-make-constant-shell "Thing")))
  (setf *default-module-mt* (reader-make-constant-shell "BaseKB"))
  (setf *default-module-mt2* (reader-make-constant-shell "UniversalVocabularyMt"))
  (setf *default-dependency-test-id*
        (to-string (constant-external-id (reader-make-constant-shell "TKBTemplateTestForMissingExplanation"))))
  (setf *default-dependency-test-id2*
        (to-string (constant-external-id (reader-make-constant-shell "TKBTemplateTestForMissingExample"))))
  (setf *default-isa-id*
        (to-string (constant-external-id (reader-make-constant-shell "TKBTemplateIntegrityTest"))))
  (setf *default-isa-id2*
        (to-string (constant-external-id (reader-make-constant-shell "TKB-RTVQueries"))))
  (setf *default-test-query*
        (list (reader-make-constant-shell "genls")
              (reader-make-constant-shell "Collection")
              '?WHAT))
  (setf *default-test-mt* (reader-make-constant-shell "BaseKB"))
  (setf *default-collection-id*
        (to-string (constant-external-id (reader-make-constant-shell "TKBTemplateIntegrityTest"))))
  t)

(defconstant *ctest-output-formats* (list :text :html))
(defconstant *ctest-output-styles* (list :brief :verbose :post-build))
(defconstant *max-test-retry-time* 60)
(defconstant *csc-table-name* "cyc_system_config")
(defconstant *max-image-type-len* 50)
(defconstant *max-image-version-len* 50)
(defconstant *max-system-version-num-len* 10)
(defconstant *max-kb-number-len* 12)
(defconstant *mc-table-name* "machine_config")
(defconstant *max-machine-name-len* 100)
(defconstant *max-machine-type-len* 50)
(defconstant *max-machine-hardware-type-len* 20)
(defconstant *max-os-type-len* 50)
(defconstant *te-table-name* "test_execution")
(defconstant *max-test-id-len* 100)
(defconstant *max-test-type-len* 20)
(defconstant *max-date-len* 19)
(defconstant *max-test-status-len* 10)
(defconstant *max-test-execution-type-len* 1)
(defconstant *ctest-test-types* (list "KBCONTENT"))
(defconstant *ctest-test-statuses* (list "SUCCESS" "FAILURE" "DFAILURE" "ERROR" "SKIPPED" "PROBLEM"))
(defconstant *ctest-success-status* "SUCCESS")
(defconstant *ctest-failure-status* "FAILURE")
(defconstant *ctest-dfailure-status* "DFAILURE")
(defconstant *ctest-error-status* "ERROR")
(defconstant *ctest-skipped-status* "SKIPPED")
(defconstant *ctest-problem-status* "PROBLEM")
(defconstant *kct-test-type* "KBCONTENT")
(defconstant *tcmr-table-name* "test_collection_metric_result")
(defconstant *max-metric-id-len* 100)
(defconstant *tmr-table-name* "test_metric_result")
(defconstant *tem-table-name* "test_execution_member")
(defconstant *kcte-table-name* "kct_execution")
(defconstant *max-exec-type-len* 1)
(defconstant *collection-execution-type* "C")
(defconstant *individual-execution-type* "I")
(defconstant *kctem-table-name* "kct_execution_member")
(defconstant *max-exec-mode-len* 1)

(defconstant *sampling-execution-mode* "S"
  "[Cyc] Tests having query formulas which are in the form of an implication, which are run by locating existing objects in the KB that satisfy the LHS, substituting them into the RHS, and performing a query using the substituted RHS.")

(defconstant *hypothesize-execution-mode* "H"
  "[Cyc] Tests having query formulas which are in the form of an implication, which are run by hypothesizing terms to satisfy the LHS, substituting them into the RHS, and performing a query using the substituted RHS.")

(defconstant *simple-execution-mode* "X"
  "[Cyc] Tests having query formulas which are not in the form of an implication, which are run by performing a query using the query formula.")

(defconstant *kctc-table-name* "kct_config")
(defconstant *kcts-project-desc* "KB Content Test System")
(defconstant *kctcc-table-name* "kct_collection_config")
(defconstant *max-collection-type-len* 1)

(defconstant *collection-test-collection-type* "C"
  "[Cyc] A C collection type denotes a collection of KB Content Tests.")

(defconstant *system-test-collection-type* "S"
  "[Cyc] An S collection type denotes a system wide collection of KB Content Tests.")

(defconstant *tcrc-table-name* "test_cyclist_responsible_config")
(defconstant *max-cyclist-id-len* 100)
(defconstant *max-email-notify-style-id-len* 100)
(defconstant *kctccbs-table-name* "kct_config_cycl_binding_set")
(defconstant *max-binding-designation-len* 1)
(defconstant *kct-exact-binding-set-designation* "E")
(defconstant *kct-wanted-binding-set-designation* "W")
(defconstant *kct-unwanted-binding-set-designation* "N")
(defconstant *kct-unimportant-binding-set-designation* "U")
(defconstant *kct-binding-set-designations* (list "E" "W" "N" "U"))
(defconstant *kctcas-table-name* "kct_config_answer_support")
(defconstant *max-support-type-len* 1)
(defconstant *max-support-designation-len* 1)
(defconstant *ctest-support-types* (list "M" "S"))
(defconstant *ctest-support-designations* (list "W" "N"))
(defconstant *kct-wanted-support-designation* "W")
(defconstant *kct-unwanted-support-designation* "N")
(defconstant *kct-support-support-type* "S")
(defconstant *kct-module-support-type* "M")
(defconstant *ipc-table-name* "inference_param_config")
(defconstant *max-inference-param-id-len* 100)
(defconstant *tmc-table-name* "test_metric_config")
(defconstant *max-test-metric-type-len* 1)
(defconstant *ctest-metric-types* (list "C" "Q" "B"))

(defconstant *ctest-collection-level-metric* "C"
  "[Cyc] Type designator for test collection level metrics.")

(defconstant *ctest-query-level-metric* "Q"
  "[Cyc] Type designator for query level metrics.")

(defconstant *ctest-binding-level-metric* "B"
  "[Cyc] Type designator for query level metrics.")

(defconstant *tdc-table-name* "test_dependency_config")
(defconstant *kctcg-table-name* "kct_config_genls")
(defconstant *kctci-table-name* "kct_config_isas")

(defparameter *ctest-storing-p* nil
  "[Cyc] If T, we are in a test running environment in which we are storing to the Cyc Test Repository.")

(defparameter *ctest-storing-configs-p* nil
  "[Cyc] If T, we maintain, in the repository, a versioned history of how tests were configured.
   This was the default until October 2004, but was disabled due to problems with completing
   the storage of config info within the 4-hour SDBC timeout.")

(defparameter *ctest-required-metrics* nil
  "[Cyc] NIL or a list of #$IndividualTestMetric instances.  Metrics in this list will be collected
   for every individual test, whether the test is configured to collect them or not.")

(defparameter *tests-in-process* nil
  "[Cyc] Index of guids for tests and test collections which are currently being
   constructed.  This will help avoid tests in the same collection from attempting to
   insert config records for the same test or same parent collection when that test
   and/or test collection is currently being saved to the Repository.")

(defparameter *ctest-field-maxima*
  (list (list "binding_designation" *max-binding-designation-len*)
        (list "cyclist_id" *max-cyclist-id-len*)
        (list "email_notify_style_id" *max-email-notify-style-id-len*)
        (list "execution_type" *max-exec-type-len*)
        (list "genls_id" *max-test-id-len*)
        (list "image_type" *max-image-type-len*)
        (list "image_version" *max-image-version-len*)
        (list "inference_metric_id" *max-metric-id-len*)
        (list "isa_id" *max-test-id-len*)
        (list "kb_number" *max-kb-number-len*)
        (list "machine_hardware_type" *max-machine-hardware-type-len*)
        (list "machine_name" *max-machine-name-len*)
        (list "machine_type" *max-machine-type-len*)
        (list "os_type" *max-os-type-len*)
        (list "support-type" *max-support-type-len*)
        (list "system_version_num" *max-system-version-num-len*)
        (list "test_id" *max-test-id-len*)
        (list "test_status" *max-test-status-len*)
        (list "test_type" *max-test-type-len*)))

;; Active declareFunction entries — all bodies are missing-larkc except initialize-ctest above.
;; (defun kct-valid-execution-type (execution-type) ...) -- active declareFunction, no body
;; (defun kct-valid-execution-mode (execution-mode) ...) -- active declareFunction, no body
;; (defun kct-valid-collection-type (collection-type) ...) -- active declareFunction, no body
;; (defun add-in-process-test (test) ...) -- active declareFunction, no body
;; (defun find-in-process-test (test) ...) -- active declareFunction, no body
;; (defun ctest-truncate-value-for-field (value field) ...) -- active declareFunction, no body
;; (defun valid-ctest-output-format (format) ...) -- active declareFunction, no body
;; (defun valid-ctest-output-style (style) ...) -- active declareFunction, no body
;; (defun valid-ctest-type (type) ...) -- active declareFunction, no body
;; (defun valid-ctest-status (status) ...) -- active declareFunction, no body
;; (defun valid-ctest-support-type (support-type) ...) -- active declareFunction, no body
;; (defun valid-ctest-support-designation (support-designation) ...) -- active declareFunction, no body
;; (defun valid-ctest-suppport-tv (tv) ...) -- active declareFunction, no body
;; (defun valid-ctest-binding-designation (binding-designation) ...) -- active declareFunction, no body
;; (defun add-leading-and-trailing-text (text leading trailing) ...) -- active declareFunction, no body
;; (defun escape-double-quotes (string) ...) -- active declareFunction, no body
;; (defun kct-test-metric-from-keyword (keyword) ...) -- active declareFunction, no body
;; (defun kct-collection-test-metric-from-keyword (keyword) ...) -- active declareFunction, no body
;; (defun kct-keyword-from-test-metric (metric) ...) -- active declareFunction, no body
;; (defun ctest-kb-test-metric-p (metric) ...) -- active declareFunction, no body
;; (defun ctest-unsupported-metric? (metric) ...) -- active declareFunction, no body
;; (defun ctest-all-kb-test-metric-constants () ...) -- active declareFunction, no body
;; (defun ctest-all-kb-collection-test-metric-constants () ...) -- active declareFunction, no body

(toplevel
  ;; CVS-ID "Id: ctest-utils.lisp 126640 2008-12-04 13:39:36Z builder "
  (declare-defglobal '*default-email-notify-style-id*)
  (declare-defglobal '*default-test-id*)
  (declare-defglobal '*default-string-binding-set*)
  (declare-defglobal '*default-binding-set*)
  (declare-defglobal '*default-binding-set2*)
  (declare-defglobal '*default-set-of-binding-sets*)
  (declare-defglobal '*default-set-of-binding-sets2*)
  (declare-defglobal '*default-set-of-binding-sets3*)
  (declare-defglobal '*default-module-sentence*)
  (declare-defglobal '*default-module-mt*)
  (declare-defglobal '*default-module-mt2*)
  (declare-defglobal '*default-dependency-test-id*)
  (declare-defglobal '*default-dependency-test-id2*)
  (declare-defglobal '*default-isa-id*)
  (declare-defglobal '*default-isa-id2*)
  (declare-defglobal '*default-test-query*)
  (declare-defglobal '*default-test-mt*)
  (declare-defglobal '*default-collection-id*))
