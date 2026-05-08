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
;; Covers: new-cycl-query-specification-p, new-cycl-query-spec-*, _csetf-new-cycl-query-spec-*,
;; make-new-cycl-query-specification
;; print-object is missing-larkc 7959 — CL's default print-object handles this.

(defstruct (new-cycl-query-specification (:conc-name "NEW-CYCL-QUERY-SPEC-"))
  cycl-id
  formula
  mt
  comment
  properties
  indexicals
  edited)

(defconstant *dtp-new-cycl-query-specification* 'new-cycl-query-specification)

;; Declare phase (following declare_new_cycl_query_specification_file order)

;; (defun new-cycl-query-specification-p (object) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-spec-cycl-id (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-spec-formula (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-spec-mt (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-spec-comment (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-spec-properties (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-spec-indexicals (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-spec-edited (spec) ...) -- commented declareFunction, no body
;; (defun _csetf-new-cycl-query-spec-cycl-id (spec value) ...) -- commented declareFunction, no body
;; (defun _csetf-new-cycl-query-spec-formula (spec value) ...) -- commented declareFunction, no body
;; (defun _csetf-new-cycl-query-spec-mt (spec value) ...) -- commented declareFunction, no body
;; (defun _csetf-new-cycl-query-spec-comment (spec value) ...) -- commented declareFunction, no body
;; (defun _csetf-new-cycl-query-spec-properties (spec value) ...) -- commented declareFunction, no body
;; (defun _csetf-new-cycl-query-spec-indexicals (spec value) ...) -- commented declareFunction, no body
;; (defun _csetf-new-cycl-query-spec-edited (spec value) ...) -- commented declareFunction, no body
;; (defun make-new-cycl-query-specification (&optional arglist) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-print (object stream depth) ...) -- commented declareFunction, no body
;; (defun xml-serialize-new-cycl-query-specification (spec &optional stream) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-cycl-id (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-formula (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-mt (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-comment (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-properties (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-indexicals (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-edited (spec) ...) -- commented declareFunction, no body
;; (defun set-new-cycl-query-specification-cycl-id (spec value) ...) -- commented declareFunction, no body
;; (defun set-new-cycl-query-specification-formula (spec formula) ...) -- commented declareFunction, no body
;; (defun set-new-cycl-query-specification-mt (spec mt) ...) -- commented declareFunction, no body
;; (defun set-new-cycl-query-specification-comment (spec comment) ...) -- commented declareFunction, no body
;; (defun set-new-cycl-query-specification-properties (spec properties) ...) -- commented declareFunction, no body
;; (defun set-new-cycl-query-specification-properties-eliminating-defaults (spec properties) ...) -- commented declareFunction, no body
;; (defun set-new-cycl-query-specification-indexicals (spec indexicals) ...) -- commented declareFunction, no body
;; (defun set-cycl-query-specification-edited (spec) ...) -- commented declareFunction, no body
;; (defun templated-new-cycl-query-specification-p (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-edited-p (spec) ...) -- commented declareFunction, no body
;; (defun mark-new-cycl-query-specification-modified (spec) ...) -- commented declareFunction, no body
;; (defun update-query-spec-params-using-defaults (spec defaults) ...) -- commented declareFunction, no body
;; (defun reset-new-cycl-query-specification-formula (spec formula) ...) -- commented declareFunction, no body
;; (defun reset-new-cycl-query-specification-mt (spec mt) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-indexical-p (object) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-indexical-formula-p (formula) ...) -- commented declareFunction, no body
;; (defun create-new-cycl-query-specification () ...) -- commented declareFunction, no body
;; (defun load-new-cycl-query-specification-from-kb (cycl-id &optional mt) ...) -- commented declareFunction, no body
;; (defun analyse-new-cycl-query-specification-for-indexicals (spec) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-load-sentence (spec cycl-id) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-load-mt (spec cycl-id) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-load-inference-parameters (spec cycl-id) ...) -- commented declareFunction, no body
;; (defun copy-new-cycl-query-specification (spec) ...) -- commented declareFunction, no body
;; (defun instantiate-new-cycl-query-specification-from-template (spec substitutions &optional mt) ...) -- commented declareFunction, no body
;; (defun new-cycl-query-specification-ask (spec &optional mt properties substitutions) ...) -- commented declareFunction, no body
;; (defun get-new-cycl-query-parameter-set () ...) -- commented declareFunction, no body
;; (defun ensure-new-cycl-query-parameter-set-initialized () ...) -- commented declareFunction, no body
;; (defun is-new-cycl-query-parameter-set-initialized? () ...) -- commented declareFunction, no body
;; (defun new-cycl-query-parameter-set () ...) -- commented declareFunction, no body
;; (defun ncq-inference-parameter-p (object) ...) -- commented declareFunction, no body
;; (defun initialize-new-cycl-query-parameter-set () ...) -- commented declareFunction, no body
;; (defun compute-new-cycl-query-parameter-set () ...) -- commented declareFunction, no body
;; (defun new-cycl-query-get-all-parameters () ...) -- commented declareFunction, no body
;; (defun new-cycl-query-get-internal-encoding-for-parameter (param) ...) -- commented declareFunction, no body

;; Init phase

;; deflexical + boundp guard → defglobal
(defglobal *new-cycl-query-parameter-set* nil
  "[Cyc] Contains all of the code mappings for permissible CycL query parameters.")

(deflexical *new-cycl-query-encoding-extent* #$CycAPIMt
  "[Cyc] The Mt where the SubL encoding for inference parameters are stored.")

;; Setup phase

(declare-defglobal '*new-cycl-query-parameter-set*)
