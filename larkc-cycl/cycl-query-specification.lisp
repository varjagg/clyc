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
;; Covers: cycl-query-specification-p, cycl-query-spec-*, _csetf-cycl-query-spec-*,
;; make-cycl-query-specification

(defstruct (cycl-query-specification (:conc-name "CYCL-QUERY-SPEC-"))
  cycl-id
  formula
  mt
  comment
  max-number-of-results
  back-chaining
  time-cutoff-secs
  max-depth
  removal-cost-cutoff
  enable-negation-by-failure
  enable-hl-predicate-backchaining
  enable-cache-backwards-query-results
  enable-unbound-predicate-backchaining
  enable-semantic-pruning
  enable-consideration-of-disjunctive-temporal-relations)

(defconstant *dtp-cycl-query-specification* 'cycl-query-specification)

;; Declare phase (following declare_cycl_query_specification_file order)

;; cycl-query-specification-print-function-trampoline — missing-larkc 23853
(defun cycl-query-specification-print-function-trampoline (object stream)
  "[Cyc] Trampoline for print method."
  (declare (ignore object stream))
  (missing-larkc 23853))

;; cycl-query-specification-p — provided by defstruct
;; cycl-query-spec-cycl-id — provided by defstruct
;; cycl-query-spec-formula — provided by defstruct
;; cycl-query-spec-mt — provided by defstruct
;; cycl-query-spec-comment — provided by defstruct
;; cycl-query-spec-max-number-of-results — provided by defstruct
;; cycl-query-spec-back-chaining — provided by defstruct
;; cycl-query-spec-time-cutoff-secs — provided by defstruct
;; cycl-query-spec-max-depth — provided by defstruct
;; cycl-query-spec-removal-cost-cutoff — provided by defstruct
;; cycl-query-spec-enable-negation-by-failure — provided by defstruct
;; cycl-query-spec-enable-hl-predicate-backchaining — provided by defstruct
;; cycl-query-spec-enable-cache-backwards-query-results — provided by defstruct
;; cycl-query-spec-enable-unbound-predicate-backchaining — provided by defstruct
;; cycl-query-spec-enable-semantic-pruning — provided by defstruct
;; cycl-query-spec-enable-consideration-of-disjunctive-temporal-relations — provided by defstruct
;; _csetf-cycl-query-spec-cycl-id — provided by defstruct (setf cycl-query-spec-cycl-id)
;; _csetf-cycl-query-spec-formula — provided by defstruct (setf cycl-query-spec-formula)
;; _csetf-cycl-query-spec-mt — provided by defstruct (setf cycl-query-spec-mt)
;; _csetf-cycl-query-spec-comment — provided by defstruct (setf cycl-query-spec-comment)
;; _csetf-cycl-query-spec-max-number-of-results — provided by defstruct (setf cycl-query-spec-max-number-of-results)
;; _csetf-cycl-query-spec-back-chaining — provided by defstruct (setf cycl-query-spec-back-chaining)
;; _csetf-cycl-query-spec-time-cutoff-secs — provided by defstruct (setf cycl-query-spec-time-cutoff-secs)
;; _csetf-cycl-query-spec-max-depth — provided by defstruct (setf cycl-query-spec-max-depth)
;; _csetf-cycl-query-spec-removal-cost-cutoff — provided by defstruct (setf cycl-query-spec-removal-cost-cutoff)
;; _csetf-cycl-query-spec-enable-negation-by-failure — provided by defstruct (setf cycl-query-spec-enable-negation-by-failure)
;; _csetf-cycl-query-spec-enable-hl-predicate-backchaining — provided by defstruct (setf cycl-query-spec-enable-hl-predicate-backchaining)
;; _csetf-cycl-query-spec-enable-cache-backwards-query-results — provided by defstruct (setf cycl-query-spec-enable-cache-backwards-query-results)
;; _csetf-cycl-query-spec-enable-unbound-predicate-backchaining — provided by defstruct (setf cycl-query-spec-enable-unbound-predicate-backchaining)
;; _csetf-cycl-query-spec-enable-semantic-pruning — provided by defstruct (setf cycl-query-spec-enable-semantic-pruning)
;; _csetf-cycl-query-spec-enable-consideration-of-disjunctive-temporal-relations — provided by defstruct (setf ...)
;; make-cycl-query-specification — provided by defstruct

;; (defun cycl-query-specification-cycl-id (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-formula (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-mt (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-comment (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-max-number-of-results (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-back-chaining (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-time-cutoff-secs (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-max-depth (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-conditional-sentence? (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-removal-cost-cutoff (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-enable-negation-by-failure (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-enable-hl-predicate-backchaining (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-enable-cache-backwards-query-results (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-enable-unbound-predicate-backchaining (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-enable-semantic-pruning (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-enable-consideration-of-disjunctive-temporal-relations (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-copy (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-print (object stream depth) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-new () ...) -- active declareFunction, no body

;; (defun cycl-query-specification-assign-param (spec param value) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-get (cycl-id &optional mt) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-ask-int (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-ask (spec) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-set-mt (spec mt) ...) -- active declareFunction, no body

;; (defun cycl-query-specification-new-query-from-old (old-spec formula mt) ...) -- active declareFunction, no body

;; (defun new-continuable-inference-from-cycl-query-spec (spec) ...) -- active declareFunction, no body

;; (defun continue-cycl-query-spec-inference (spec inference) ...) -- active declareFunction, no body

;; (defun static-query-properties-from-cycl-query-spec (spec) ...) -- active declareFunction, no body

;; (defun dynamic-query-properties-from-cycl-query-spec (spec) ...) -- active declareFunction, no body
