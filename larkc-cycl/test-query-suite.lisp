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

;; Struct definition — generates accessors, predicate, constructor, and setf accessors.
;; Covers: test-query-suite-p, test-ste-*, _csetf-test-ste-*, make-test-query-suite
;; print-object is missing-larkc 23172 — CL's default print-object handles this.

(defstruct (test-query-suite (:conc-name "TEST-STE-"))
  cycl-id
  comment
  mt
  queries)

(defconstant *dtp-test-query-suite* 'test-query-suite)

;; Declare phase (following declare_test_query_suite_file order)

;; test-query-suite-p — provided by defstruct
;; test-ste-cycl-id — provided by defstruct
;; test-ste-comment — provided by defstruct
;; test-ste-mt — provided by defstruct
;; test-ste-queries — provided by defstruct
;; _csetf-test-ste-cycl-id — provided by defstruct (setf test-ste-cycl-id)
;; _csetf-test-ste-comment — provided by defstruct (setf test-ste-comment)
;; _csetf-test-ste-mt — provided by defstruct (setf test-ste-mt)
;; _csetf-test-ste-queries — provided by defstruct (setf test-ste-queries)
;; make-test-query-suite — provided by defstruct

;; (defun test-query-suite-cycl-id (suite) ...) -- active declareFunction, no body

;; (defun test-query-suite-comment (suite) ...) -- active declareFunction, no body

;; (defun test-query-suite-mt (suite) ...) -- active declareFunction, no body

;; (defun test-query-suite-queries (suite) ...) -- active declareFunction, no body

;; (defun test-query-suite-print (object stream depth &optional length) ...) -- active declareFunction, no body

;; (defun test-query-suite-get (cycl-id &optional mt) ...) -- active declareFunction, no body

;; (defun test-query-suite-find-query-by-id (suite query-id) ...) -- active declareFunction, no body

;; (defun test-query-suite-set-queries (suite queries) ...) -- active declareFunction, no body

;; (defun test-query-suite-find-query-siblings (suite query) ...) -- active declareFunction, no body

;; (defun test-query-suite-new (cycl-id mt) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-comment-comparator (spec-a spec-b) ...) -- active declareFunction, no body

;; (defun test-query-suite-sort-by-comment (suite) ...) -- active declareFunction, no body
