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

;; Variables

(deflexical *gather-inference-answer-query-properties*
  '(:bindings
    :intermediate-step-validation-level
    :max-problem-count
    :transformation-allowed?
    :negation-by-failure?
    :completeness-minimization-allowed?
    :evaluate-subl-allowed?
    :rewrite-allowed?
    :abduction-allowed?
    :new-terms-allowed?
    :allow-hl-predicate-transformation?
    :allow-unbound-predicate-transformation?
    :allow-evaluatable-predicate-transformation?
    :allow-indeterminate-results?
    :allow-abnormality-checking?
    :transitive-closure-mode
    :max-proof-depth
    :max-transformation-depth
    :probably-approximately-done
    :answer-language
    :max-number
    :max-time
    :max-step
    :removal-backtracking-productivity-limit
    :productivity-limit))

(deflexical *boolean-query-properties-to-include-on-merge*
  '(:abduction-allowed?
    :add-restriction-layer-of-indirection?
    :allow-abnormality-checking?
    :allow-evaluatable-predicate-transformation?
    :allow-hl-predicate-transformation?
    :allow-indeterminate-results?
    :allow-unbound-predicate-transformation?
    :completeness-minimization-allowed?
    :evaluate-subl-allowed?
    :negation-by-failure?
    :new-terms-allowed?
    :rewrite-allowed?
    :transformation-allowed?))

(deflexical *query-properties-efficiency-hierarchy*
  '((:abduction-allowed? nil t)
    (:add-restriction-layer-of-indirection? nil t)
    (:allow-abnormality-checking? nil t)
    (:allow-evaluatable-predicate-transformation? nil t)
    (:allow-hl-predicate-transformation? nil t)
    (:allow-indeterminate-results? t nil)
    (:allow-unbound-predicate-transformation? nil t)
    (:answer-language :hl :el)
    (:completeness-minimization-allowed? t nil)
    (:evaluate-subl-allowed? nil t)
    (:inference-mode :minimal :shallow :extended :maximal :custom)
    (:intermediate-step-validation-level :none :minimal :arg-type :all)
    (:negation-by-failure? t nil)
    (:new-terms-allowed? nil t)
    (:rewrite-allowed? nil t)
    (:transformation-allowed? nil t)
    (:transitive-closure-mode :none :focused :all)))

(deflexical *numeric-query-properties*
  '(:max-problem-count
    :max-proof-depth
    :max-transformation-depth
    :probably-approximately-done
    :max-number
    :max-time
    :max-step
    :removal-backtracking-productivity-limit
    :productivity-limit))

(deflexical *numeric-query-properties-that-max-out-at-positive-infinity*
  '(:max-problem-count
    :productivity-limit
    :removal-backtracking-productivity-limit))

(deflexical *proof-query-properties-to-override*
  '(:intermediate-step-validation-level
    :max-time
    :max-step
    :probably-approximately-done
    :allow-indeterminate-results?
    :answer-language
    :bindings))

(deflexical *inference-mode-query-properties-table*
  '((:minimal
     :new-terms-allowed? nil
     :max-proof-depth 15
     :removal-backtracking-productivity-limit 200
     :add-restriction-layer-of-indirection? t
     :transitive-closure-mode :none
     :max-problem-count 100000
     :productivity-limit 20000000
     :allow-unbound-predicate-transformation? nil
     :allow-evaluatable-predicate-transformation? nil
     :allow-hl-predicate-transformation? nil
     :max-transformation-depth 0
     :transformation-allowed? nil)
    (:shallow
     :new-terms-allowed? nil
     :max-proof-depth nil
     :removal-backtracking-productivity-limit 200
     :add-restriction-layer-of-indirection? t
     :transitive-closure-mode :none
     :max-problem-count 100000
     :productivity-limit 20000000
     :allow-unbound-predicate-transformation? nil
     :allow-evaluatable-predicate-transformation? t
     :allow-hl-predicate-transformation? nil
     :max-transformation-depth 1
     :transformation-allowed? t)
    (:extended
     :new-terms-allowed? t
     :max-proof-depth nil
     :removal-backtracking-productivity-limit 200
     :add-restriction-layer-of-indirection? t
     :transitive-closure-mode :none
     :max-problem-count 100000
     :productivity-limit 20000000
     :allow-unbound-predicate-transformation? nil
     :allow-evaluatable-predicate-transformation? t
     :allow-hl-predicate-transformation? nil
     :max-transformation-depth 2
     :transformation-allowed? t)
    (:maximal
     :new-terms-allowed? t
     :max-proof-depth nil
     :removal-backtracking-productivity-limit :positive-infinity
     :add-restriction-layer-of-indirection? t
     :transitive-closure-mode :all
     :max-problem-count :positive-infinity
     :productivity-limit :positive-infinity
     :allow-unbound-predicate-transformation? t
     :allow-evaluatable-predicate-transformation? t
     :allow-hl-predicate-transformation? t
     :max-transformation-depth nil
     :transformation-allowed? t)))

;; Functions

;; (defun explicify-inference-engine-query-property-defaults (query-properties) ...) -- active declareFunction, no body
;; (defun remove-inference-engine-query-property-defaults (query-properties) ...) -- active declareFunction, no body
;; (defun inference-merge-query-properties (query-properties-1 query-properties-2) ...) -- active declareFunction, no body
;; (defun union-plist-properties (plist-1 plist-2) ...) -- active declareFunction, no body
;; (defun inference-conservatively-select-property-value-for-merge (property value-1 value-2) ...) -- active declareFunction, no body
;; (defun gather-inference-answer-query-property? (property) ...) -- active declareFunction, no body
;; (defun gather-inference-answer-query-properties () ...) -- active declareFunction, no body
;; (defun boolean-query-property-to-include-on-merge? (property) ...) -- active declareFunction, no body
;; (defun query-property-in-efficiency-hierarchy? (property) ...) -- active declareFunction, no body
;; (defun query-properties-efficiency-hierarchy () ...) -- active declareFunction, no body
;; (defun numeric-query-properties () ...) -- active declareFunction, no body
;; (defun numeric-query-property-p (property) ...) -- active declareFunction, no body
;; (defun numeric-query-property-max (property) ...) -- active declareFunction, no body
;; (defun query-property-value-more-efficient? (property value-1 value-2) ...) -- active declareFunction, no body
;; (defun query-property-value-more-complete? (property value-1 value-2) ...) -- active declareFunction, no body
;; (defun query-property-value-at-least-as-efficient? (property value-1 value-2) ...) -- active declareFunction, no body
;; (defun query-property-value-at-least-as-complete? (property value-1 value-2) ...) -- active declareFunction, no body
;; (defun most-efficient-value-for-query-property (property) ...) -- active declareFunction, no body
;; (defun most-efficient-value-for-query-property? (property value) ...) -- active declareFunction, no body
;; (defun most-complete-value-for-query-property (property) ...) -- active declareFunction, no body
;; (defun most-complete-value-for-query-property? (property value) ...) -- active declareFunction, no body
;; (defun problem-store-allows-reuse-wrt-query-properties? (store query-properties) ...) -- active declareFunction, no body
;; (defun problem-store-allows-reuse-wrt-query-property (store property value) ...) -- active declareFunction, no body
;; (defun inference-compute-all-answers-query-properties (inference) ...) -- active declareFunction, no body
;; (defun inference-compute-some-answer-query-properties (inference) ...) -- active declareFunction, no body
;; (defun inference-compute-proof-query-properties (proof) ...) -- active declareFunction, no body
;; (defun inference-compute-inference-answer-query-properties (inference) ...) -- active declareFunction, no body
;; (defun compute-most-complete-query-properties (query-properties-list) ...) -- active declareFunction, no body
;; (defun compute-most-efficient-query-properties (query-properties-list) ...) -- active declareFunction, no body
;; (defun compute-extremal-query-properties-int (query-properties-list selector) ...) -- active declareFunction, no body
;; (defun inference-compute-inference-answer-query-properties-int (inference answer-properties-list) ...) -- active declareFunction, no body
;; (defun inference-answer-compute-inference-answer-query-properties (inference inference-answer answer-properties) ...) -- active declareFunction, no body
;; (defun inference-answer-compute-inference-answer-query-properties-int (inference-answer proof-properties-list) ...) -- active declareFunction, no body
;; (defun distribute-answer-properties-over-proof-properties-list (answer-properties proof-properties-list) ...) -- active declareFunction, no body
;; (defun compute-proof-query-properties-list (inference-answer query-properties) ...) -- active declareFunction, no body
;; (defun proof-query-properties (proof inference query-properties) ...) -- active declareFunction, no body
;; (defun prepare-proof-query-properties () ...) -- active declareFunction, no body
;; (defun get-most-efficient-query-properties (query-properties-1 query-properties-2) ...) -- active declareFunction, no body
;; (defun get-least-efficient-query-properties (query-properties-1 query-properties-2) ...) -- active declareFunction, no body
;; (defun query-properties-more-efficient? (query-properties-1 query-properties-2) ...) -- active declareFunction, no body
;; (defun query-properties-less-efficient? (query-properties-1 query-properties-2) ...) -- active declareFunction, no body
;; (defun get-query-properties-efficiency-count (query-properties-1 query-properties-2) ...) -- active declareFunction, no body
;; (defun most-efficient-query-properties (query-properties-list) ...) -- active declareFunction, no body
;; (defun most-complete-query-properties (query-properties-list) ...) -- active declareFunction, no body
;; (defun least-efficient-query-properties (query-properties-list) ...) -- active declareFunction, no body
;; (defun least-complete-query-properties (query-properties-list) ...) -- active declareFunction, no body

(defun query-properties-for-inference-mode (inference-mode)
  ;; checkType inference-mode inference-mode-p
  (alist-lookup *inference-mode-query-properties-table* inference-mode))
