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

(deflexical *residual-transformation-link-motivating-object-test* #'equal
  "[Cyc] The test used in the set-contents for the data of residual transformation links")

(defun residual-transformation-link-p (object)
  (and (problem-link-p object)
       (eq :residual-transformation (problem-link-type object))))

;; (defun find-residual-transformation-link (join-ordered-link transformation-link) ...) -- active declareFunction, no body
;; (defun new-residual-transformation-link (store supported-problem join-ordered-link transformation-link variable-map) ...) -- active declareFunction, no body
;; (defun destroy-residual-transformation-link (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun destroy-join-ordered-link-wrt-residual-transformation-links (join-ordered-link) ...) -- active declareFunction, no body
;; (defun destroy-transformation-link-wrt-residual-transformation-links (transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-supporting-mapped-problem (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-supporting-problem (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-supporting-variable-map (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-motivating-join-ordered-link (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-motivating-transformation-link (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-conjunctive-problem-dont-care-variable-map (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-residual-conjunction-literal-map (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-motivated-by-link-pair? (residual-transformation-link join-ordered-link transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-motivated-by-join-ordered-link? (residual-transformation-link join-ordered-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-motivated-by-transformation-link? (residual-transformation-link transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-residual-problem (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-rule-assertion (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun set-residual-transformation-link-data (residual-transformation-link join-ordered-link transformation-link dont-care-variable-map conjunction-literal-map) ...) -- active declareFunction, no body

(defun maybe-possibly-add-residual-transformation-links-via-join-ordered-link (join-ordered-link)
  (when (problem-store-transformation-allowed?
         (problem-link-store join-ordered-link))
    (possibly-add-residual-transformation-links-via-join-ordered-link join-ordered-link)))

(defun maybe-possibly-add-residual-transformation-links-via-transformation-link (transformation-link)
  (when (problem-store-transformation-allowed?
         (problem-link-store transformation-link))
    (when (problem-link-with-supporting-problem-p transformation-link)
      (possibly-add-residual-transformation-links-via-transformation-link transformation-link))))

(defun possibly-add-residual-transformation-links-via-join-ordered-link (join-ordered-link)
  (let ((focal-problem (join-ordered-link-focal-problem join-ordered-link))
        (total 0))
    (do-set (transformation-link (problem-argument-links focal-problem))
      (when (problem-link-has-type? transformation-link :transformation)
        (when (problem-link-with-supporting-problem-p transformation-link)
          ;; Likely calls possibly-add-residual-transformation-link with join-ordered-link
          ;; and transformation-link, returning whether one was added.
          ;; Evidence: the parallel function below has the same structure and same missing-larkc pattern.
          (when (missing-larkc 35056)
            (incf total)))))
    total))

(defun possibly-add-residual-transformation-links-via-transformation-link (transformation-link)
  (let* ((supported-problem (problem-link-supported-problem transformation-link))
         (total 0)
         (problem-var supported-problem))
    (do-set (join-ordered-link (problem-dependent-links supported-problem))
      (when (problem-link-has-type? join-ordered-link :join-ordered)
        (do-problem-link-supporting-mapped-problems
            (conjunct-mapped-problem join-ordered-link :open? t)
          (when (eq problem-var (mapped-problem-problem conjunct-mapped-problem))
            ;; Likely calls possibly-add-residual-transformation-link with join-ordered-link
            ;; and transformation-link, returning whether one was added.
            ;; Evidence: parallel to the function above; both iterate links and conditionally add rt links.
            (when (missing-larkc 35057)
              (incf total))))))
    total))

;; (defun possibly-add-residual-transformation-link (join-ordered-link transformation-link) ...) -- active declareFunction, no body
;; (defun compute-residual-transformation-link-query (join-ordered-link transformation-link) ...) -- active declareFunction, no body
;; (defun compute-residual-conjunction-literal-map (residual-conjunction-query motivating-conjunction-query residual-conjunction-variable-map motivating-conjunction-variable-map) ...) -- active declareFunction, no body
;; (defun compute-residual-conjunction-literal-map-internal (residual-conjunction-query motivating-conjunction-query residual-conjunction-variable-map motivating-conjunction-variable-map) ...) -- active declareFunction, no body
;; (defun new-residual-transformation-proof (residual-transformation-link supporting-proof rule-bindings) ...) -- active declareFunction, no body
;; (defun residual-transformation-proof-rule-bindings (residual-transformation-proof) ...) -- active declareFunction, no body
;; (defun residual-transformation-proof-motivating-transformation-link (residual-transformation-proof) ...) -- active declareFunction, no body
;; (defun residual-transformation-link-residual-conjunction-to-motivating-conjunction-variable-map (residual-transformation-link) ...) -- active declareFunction, no body
;; (defun conjoin-problem-queries (problem1 problem2) ...) -- active declareFunction, no body
;; (defun rt-apply-bindings (bindings formula) ...) -- active declareFunction, no body
;; (defun compute-conjunctive-problem-dont-care-variable-map (conjunction-query residual-query variable-map) ...) -- active declareFunction, no body
;; (defun transformation-link-first-unused-extended-var-number (transformation-link) ...) -- active declareFunction, no body
;; (defun filter-transformation-link-bindings (transformation-link) ...) -- active declareFunction, no body

(defun residual-transformation-proof-p (object)
  (and (proof-p object)
       (residual-transformation-link-p (proof-link object))))

;; (defun residual-transformation-proof-rule-assertion (residual-transformation-proof) ...) -- active declareFunction, no body
;; (defun residual-transformation-proof-subproof (residual-transformation-proof) ...) -- active declareFunction, no body
;; (defun bubble-up-proof-to-residual-transformation-link (residual-transformation-link proof supporting-proof) ...) -- active declareFunction, no body
;; (defun residual-transformation-proof-abnormal? (proof) ...) -- active declareFunction, no body
;; (defun problem-is-a-residual-conjunction? (problem) ...) -- active declareFunction, no body
;; (defun problem-store-problematic-residual-transformation-links (store) ...) -- active declareFunction, no body
;; (defun problem-store-problematic-residual-transformation-link-count (store) ...) -- active declareFunction, no body

(defvar *residual-transformation-proof-bubbling-triggers-additional-restrictions?* nil)
(defvar *residual-transformation-proof-bubbling-opens-split-links?* nil)

(toplevel
  (define-obsolete-register 'problem-store-problematic-residual-transformation-links '(null))
  (define-obsolete-register 'problem-store-problematic-residual-transformation-link-count '(zero)))
