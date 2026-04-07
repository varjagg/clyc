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

;; Value tables, value table columns, and variable mapping tables for
;; managing query-driven tabular data and variable-to-variable mappings.

;;; value-table-column struct

(defstruct (value-table-column
            (:conc-name "VALUE-TABLE-COLUMN-")
            (:constructor make-value-table-column (&key query label values)))
  query
  label
  values)

(defconstant *dtp-value-table-column* 'value-table-column)

(defun value-table-column-print-function-trampoline (object stream)
  ;; Likely calls print-value-table-column -- evidence: registered as print method in setup
  (declare (ignore object stream))
  (missing-larkc 4824))

;; (defun value-table-column-p (object) ...) -- commented declareFunction, no body
;; Accessors value-table-column-query, value-table-column-label, value-table-column-values
;; and their setf counterparts are provided by defstruct.
;; (defun make-value-table-column (&optional arglist) ...) -- provided by defstruct
;; (defun print-value-table-column (object stream depth) ...) -- commented declareFunction, no body
;; (defun new-value-table-column (query) ...) -- commented declareFunction, no body
;; (defun load-value-table-column-from-kb (column term mt) ...) -- commented declareFunction, no body
;; (defun xml-serialize-value-table-column (column &optional stream) ...) -- commented declareFunction, no body
;; (defun get-vtbl-query-result-values (column term mt) ...) -- commented declareFunction, no body
;; (defun get-vtbl-query-result-sets (column term mt) ...) -- commented declareFunction, no body

;;; value-table struct

(defstruct (value-table
            (:conc-name "VALUE-TABLE-")
            (:constructor make-value-table (&key id label input-columns output-column assignments)))
  id
  label
  input-columns
  output-column
  assignments)

(defconstant *dtp-value-table* 'value-table)

(defun value-table-print-function-trampoline (object stream)
  ;; Likely calls print-value-table -- evidence: registered as print method in setup
  (declare (ignore object stream))
  (missing-larkc 4823))

;; (defun value-table-p (object) ...) -- commented declareFunction, no body
;; Accessors value-table-id, value-table-label, value-table-input-columns,
;; value-table-output-column, value-table-assignments and their setf counterparts
;; are provided by defstruct.
;; (defun make-value-table (&optional arglist) ...) -- provided by defstruct
;; (defun print-value-table (object stream depth) ...) -- commented declareFunction, no body
;; (defun new-value-table (term) ...) -- commented declareFunction, no body
;; (defun load-value-table-from-kb (table mt) ...) -- commented declareFunction, no body
;; (defun xml-serialize-value-table (table &optional stream) ...) -- commented declareFunction, no body
;; (defun get-vtbl-input-queries (table mt) ...) -- commented declareFunction, no body
;; (defun get-vtbl-output-query (table mt) ...) -- commented declareFunction, no body
;; (defun load-value-table-assignments-from-kb (table mt) ...) -- commented declareFunction, no body

;;; variable-mapping-table struct

(defstruct (variable-mapping-table
            (:conc-name "VARIABLE-MAPPING-TABLE-")
            (:constructor make-variable-mapping-table (&key id source-query target-query source-variables target-variables incompatibles assignments)))
  id
  source-query
  target-query
  source-variables
  target-variables
  incompatibles
  assignments)

(defconstant *dtp-variable-mapping-table* 'variable-mapping-table)

(defun variable-mapping-table-print-function-trampoline (object stream)
  ;; Likely calls print-varmap-table -- evidence: registered as print method in setup
  (declare (ignore object stream))
  (missing-larkc 4825))

;; (defun variable-mapping-table-p (object) ...) -- commented declareFunction, no body
;; Accessors variable-mapping-table-id, variable-mapping-table-source-query,
;; variable-mapping-table-target-query, variable-mapping-table-source-variables,
;; variable-mapping-table-target-variables, variable-mapping-table-incompatibles,
;; variable-mapping-table-assignments and their setf counterparts are provided by defstruct.
;; (defun make-variable-mapping-table (&optional arglist) ...) -- provided by defstruct
;; (defun print-varmap-table (object stream depth) ...) -- commented declareFunction, no body
;; (defun xml-serialize-variable-mapping-table (table &optional stream) ...) -- commented declareFunction, no body
;; (defun new-variable-mapping-table (term) ...) -- commented declareFunction, no body
;; (defun load-variable-mapping-table-from-kb (table mt &optional source-formula target-formula) ...) -- commented declareFunction, no body
;; (defun get-variable-mapping-table-for-formulas (term source-formula target-formula &optional source-mt target-mt) ...) -- commented declareFunction, no body
;; (defun varmaptbl-assign-queries (table source-query target-query mt) ...) -- commented declareFunction, no body
;; (defun varmaptbl-load-source-query-information (table mt) ...) -- commented declareFunction, no body
;; (defun varmaptbl-load-target-query-information (table mt) ...) -- commented declareFunction, no body
;; (defun varmaptbl-assign-variable-information (table mt) ...) -- commented declareFunction, no body
;; (defun varmaptbl-assign-variable-information-from-formulas (table source-formula target-formula mt &optional source-mt target-mt) ...) -- commented declareFunction, no body
;; (defun any-disjoint-with-any?-memoized-internal (isas genls mt) ...) -- commented declareFunction, no body
;; (defun any-disjoint-with-any?-memoized (isas genls mt) ...) -- commented declareFunction, no body
;; (defun varmaptbl-store-variable-information (table var isas genls) ...) -- commented declareFunction, no body
;; (defun varmaptbl-load-query-variable-information (table mt) ...) -- commented declareFunction, no body
;; (defun varmaptbl-assign-current-assignments (table mt) ...) -- commented declareFunction, no body
;; (defun varmaptbl-load-current-assignments (table source-var target-var mt) ...) -- commented declareFunction, no body
;; (defun varmap-autocombine-literals (table &optional source-mt target-mt combine-fn) ...) -- commented declareFunction, no body
;; (defun varmap-uniquify-source-vars (formula vars) ...) -- commented declareFunction, no body
;; (defun varmap-unique-el-var-wrt-vars (var vars) ...) -- commented declareFunction, no body
;; (defun varmap-attempt-to-combine-variables (source-var target-var table &optional source-mt target-mt) ...) -- commented declareFunction, no body

;;; Setup phase

(toplevel
  (note-memoized-function 'any-disjoint-with-any?-memoized)
  (register-external-symbol 'varmap-unique-el-var-wrt-vars))
