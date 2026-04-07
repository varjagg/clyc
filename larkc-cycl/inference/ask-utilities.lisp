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

;; (defun query-properties-from-legacy-ask-parameters (&optional backchain number time depth) ...) -- commented declareFunction, no body

(defun productivity-limit-from-removal-cost-cutoff (cost-cutoff)
  (if cost-cutoff
      (* 2 100 cost-cutoff)
      (positive-infinity)))

;; (defun query-static-properties-from-legacy-ask-parameters () ...) -- commented declareFunction, no body
;; (defun query-dynamic-properties-from-legacy-ask-parameters (&optional backchain number time depth cost-cutoff) ...) -- commented declareFunction, no body
;; (defun query-justified (sentence &optional mt query-properties) ...) -- commented declareFunction, no body, Cyc API
;; (defun ask-justified (sentence &optional mt backchain number time depth) ...) -- commented declareFunction, no body, Cyc API (obsolete)
;; (defun query-template (template sentence &optional mt query-properties) ...) -- commented declareFunction, no body, Cyc API
;; (defun ask-template (template sentence &optional mt backchain number time depth) ...) -- commented declareFunction, no body, Cyc API (obsolete)
;; (defun query-variable (variable-token sentence &optional mt query-properties) ...) -- commented declareFunction, no body, Cyc API
;; (defun ask-variable (variable-token sentence &optional mt backchain number time depth) ...) -- commented declareFunction, no body, Cyc API (obsolete)
;; (defun query-template-eval (template sentence &optional mt query-properties) ...) -- commented declareFunction, no body, Cyc API
;; (defun ask-template-eval (template sentence &optional mt backchain number time depth) ...) -- commented declareFunction, no body, Cyc API (obsolete)
;; (defun query-boolean (sentence &optional mt query-properties) ...) -- commented declareFunction, no body

(defvar *recursive-queries-in-currently-active-problem-store?* t
  "[Cyc] Temporary control variable; When non-nil, recursive queries are performed in the currently active problem store.")

;; (defun recursive-ask-query-properties-from-legacy-ask-parameters (&optional backchain number time depth) ...) -- commented declareFunction, no body
;; (defun within-recursive-query? () ...) -- commented declareFunction, no body
;; (defun recursive-query (sentence &optional mt query-properties) ...) -- commented declareFunction, no body
;; (defun query-property-inherited-by-recursive-query? (property) ...) -- commented declareFunction, no body
;; (defun filter-query-properties-for-recursive-query (query-properties) ...) -- commented declareFunction, no body
;; (defun recursive-query-problem-store-to-reuse (query-properties) ...) -- commented declareFunction, no body

(deflexical *max-recursive-query-depth* 27
  "[Cyc] A recursive query depth higher than this will yield an error")

(defparameter *recursive-query-depth* nil
  "[Cyc] To avoid infinite recursion and stack overflow")

;; (defun kappa-tuples (variable-list sentence mt &optional query-properties) ...) -- commented declareFunction, no body
;; (defun kappa-tuples-justified (variable-list sentence mt &optional query-properties) ...) -- commented declareFunction, no body
;; (defun inference-recursive-ask (sentence &optional mt backchain number time depth) ...) -- commented declareFunction, no body
;; (defun inference-recursive-query (sentence &optional mt query-properties) ...) -- commented declareFunction, no body
;; (defun inference-recursive-query-unique-bindings (sentence &optional mt query-properties) ...) -- commented declareFunction, no body
;; (defun inference-recursive-ask-unique-bindings (sentence &optional mt backchain number time depth) ...) -- commented declareFunction, no body
;; (defun inference-recursive-query-convert-to-hl-bindings (bindings sentence) ...) -- commented declareFunction, no body
;; (defun inference-literal-truth (literal mt) ...) -- commented declareFunction, no body
;; (defun inference-literal-ask (literal mt) ...) -- commented declareFunction, no body
;; (defun the-set-of-elements (expression &optional mt query-properties) ...) -- commented declareFunction, no body
;; (defun the-set-of-problem-solvable-via-generalized-query? (&optional problem query-properties) ...) -- commented declareFunction, no body
;; (defun the-set-of-elements-via-generalized-query (&optional problem query-properties) ...) -- commented declareFunction, no body
;; (defun compute-the-set-of-elements-generalized-query (&optional problem) ...) -- commented declareFunction, no body
;; (defun find-unrestricted-problem-of-the-set-of-expression-problem (problem) ...) -- commented declareFunction, no body
;; (defun find-jo-link-and-focal-problem-of-supported-problem (problem) ...) -- commented declareFunction, no body
;; (defun-memoized the-set-of-elements-generalized-query-memoized (variable query) ...) -- commented declareFunction for internal + memoized wrapper, no body
;; (defun cyc-query-with-minimal-required-transformation (sentence &optional mt query-properties) ...) -- commented declareFunction, no body

(toplevel
  (register-cyc-api-function 'query-justified
      '(sentence &optional mt query-properties)
    "Ask for bindings for free variables which will satisfy SENTENCE within MT.
   Returns bindings and HL supports.
   Returns a list of binding and justificaion pairs."
    nil
    '(listp query-halt-reason-p))
  (register-obsolete-cyc-api-function 'ask-justified '(query-justified)
    '(sentence &optional mt backchain number time depth)
    "Ask for bindings for free variables which will satisfy SENTENCE within MT.
   Returns bindings and HL supports.
   If BACKCHAIN is NIL, no inference is performed.
   If BACKCHAIN is an integer, then at most that many backchaining steps using rules
   are performed.
   If BACKCHAIN is T, then inference is performed without limit on the number of
   backchaining steps when searching for bindings.
   If NUMBER is an integer, then at most that number of bindings are returned.
   If TIME is an integer, then at most TIME seconds are consumed by the search for bindings.
   If DEPTH is an integer, then the inference paths are limited to that number of total steps.
   Returns a list of binding and justificaion pairs.
   Deprecated in favor of query-justified."
    nil
    '(listp query-halt-reason-p))
  (register-cyc-api-function 'query-template
      '(template sentence &optional mt query-properties)
    "Ask SENTENCE in MT.  Return results of substituting bindings into TEMPLATE."
    nil
    '(listp query-halt-reason-p))
  (register-obsolete-cyc-api-function 'ask-template '(query-template)
    '(template sentence &optional mt backchain number time depth)
    "Ask SENTENCE in MT.  Return results of substituting bindings into TEMPLATE.
   Deprecated in favor of query-template."
    nil
    '(listp query-halt-reason-p))
  (register-cyc-api-function 'query-variable
      '(variable-token sentence &optional mt query-properties)
    "Ask SENTENCE in MT treating VARIABLE-TOKEN as an indicator of the one
   free variable for which a list of answers is desired."
    nil
    '(listp query-halt-reason-p))
  (register-obsolete-cyc-api-function 'ask-variable '(query-variable)
    '(variable-token sentence &optional mt backchain number time depth)
    "Ask SENTENCE in MT treating VARIABLE-TOKEN as an indicator of the one
   free variable for which a list of answers is desired.
   Deprecated in favor of query-variable."
    nil
    '(listp query-halt-reason-p))
  (register-cyc-api-function 'query-template-eval
      '(template sentence &optional mt query-properties)
    "Ask SENTENCE in MT under the resource constraints query-properties
 TEMPLATE is a SubL template which is evaluated once for each set of bindings returned.
 The bindings are substitued into TEMPLATE before evaluation.
 Returns a count of the number of evaluations performed."
    nil
    '(non-negative-integer-p))
  (register-obsolete-cyc-api-function 'ask-template-eval '(query-template-eval)
    '(template sentence &optional mt backchain number time depth)
    "Ask SENTENCE in MT under the resource constraints BACKCHAIN NUMBER TIME DEPTH
 TEMPLATE is a SubL template which is evaluated once for each set of bindings returned.
 The bindings are substitued into TEMPLATE before evaluation.
 Returns a count of the number of evaluations performed.
 Deprecated in favor of query-template-eval."
    nil
    '(non-negative-integer-p))
  (note-memoized-function 'the-set-of-elements-generalized-query-memoized))
