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

;; This is a near-total stub port — standard_tokenization.java has 42 commented
;; declareFunction entries and only 1 active one (dot-analysis-print-function-trampoline,
;; whose body is handleMissingMethodError 9013). The tokenizer, chunker, dot-analysis
;; DFA, and interval/string token accessors all had their bodies stripped by LarKC.
;; What remains is: 3 character-class constants, the DOT-ANALYSIS defstruct, the
;; *DTP-DOT-ANALYSIS* defconstant, the print-function trampoline, and comment stubs.


;;;; Variables

(deflexical *standard-punctuation-chars*
  (list #\; #\, #\: #\" #\' #\! #\? #\( #\) #\% #\$ #\- #\^ #\*))

(deflexical *standard-word-final-punctuation-chars*
  (list #\.)
  "[Cyc] chars that are only punctuation if they are word-final")

(deflexical *standard-white-space-chars*
  (whitespace-chars))


;;;; DOT-ANALYSIS struct
;; Slots FOUND REMAINS ACCUMULATOR STATE per $list11, with default conc-name
;; DOT-ANALYSIS- per $list13 accessor names. Print function is pprint-dot-analysis
;; per $sym15$PPRINT_DOT_ANALYSIS in the struct decl.

(defstruct (dot-analysis (:print-function pprint-dot-analysis))
  found
  remains
  accumulator
  state)

(defconstant *dtp-dot-analysis* 'dot-analysis)


;;;; Functions (declare section ordering)

;; (defun standard-raw-tokenization (string) ...) -- commented declareFunction, no body
;; (defun standard-token-chunker (sentence) ...) -- commented declareFunction, no body
;; (defun standard-string-tokenize (string) ...) -- commented declareFunction, no body
;; (defun standard-punctuation-chars () ...) -- commented declareFunction, no body
;; (defun standard-white-space-chars () ...) -- commented declareFunction, no body
;; (defun tokenize-sentence (string &optional punctuation-chars white-space-chars word-final-punctuation-chars) ...) -- commented declareFunction, no body
;; (defun scanner-char-classify (char punctuation-chars white-space-chars word-final-punctuation-chars) ...) -- commented declareFunction, no body

(defun dot-analysis-print-function-trampoline (object stream depth)
  ;; Likely calls pprint-dot-analysis (the struct's print function per
  ;; $sym15$PPRINT_DOT_ANALYSIS) or otherwise emits the format fragments
  ;; $str30..$str33 ("#<AP:Found ... Remains ... Accumulator ... State ...>"
  ;; from Internal Constants). Java declareFunction arity is 2 (object stream),
  ;; but CL :print-function requires the 3-arg (object stream depth) signature.
  (declare (ignore object stream depth))
  (missing-larkc 9013))

;; (defun dot-analysis-p (object) ...) -- commented declareFunction, no body (accessor provided by defstruct)
;; (defun dot-analysis-found (object) ...) -- commented declareFunction, no body (accessor provided by defstruct)
;; (defun dot-analysis-remains (object) ...) -- commented declareFunction, no body (accessor provided by defstruct)
;; (defun dot-analysis-accumulator (object) ...) -- commented declareFunction, no body (accessor provided by defstruct)
;; (defun dot-analysis-state (object) ...) -- commented declareFunction, no body (accessor provided by defstruct)
;; _csetf-dot-analysis-found -- commented declareFunction, no body (CL setf handles natively)
;; _csetf-dot-analysis-remains -- commented declareFunction, no body (CL setf handles natively)
;; _csetf-dot-analysis-accumulator -- commented declareFunction, no body (CL setf handles natively)
;; _csetf-dot-analysis-state -- commented declareFunction, no body (CL setf handles natively)
;; (defun make-dot-analysis (&optional arglist) ...) -- commented declareFunction, no body (constructor provided by defstruct)
;; (defun pprint-dot-analysis (object stream depth) ...) -- commented declareFunction, no body
;; (defun perform-dot-analysis (string) ...) -- commented declareFunction, no body
;; (defun init-dot-analysis (string) ...) -- commented declareFunction, no body
;; (defun find-current-dot-type (analysis) ...) -- commented declareFunction, no body
;; (defun dot-analysis-dfa (analysis) ...) -- commented declareFunction, no body
;; (defun dot-analysis-default (analysis) ...) -- commented declareFunction, no body
;; (defun dot-analysis-dot-string (analysis) ...) -- commented declareFunction, no body
;; (defun dot-analysis-string (analysis) ...) -- commented declareFunction, no body
;; (defun dot-analysis-dot-integer (analysis) ...) -- commented declareFunction, no body
;; (defun dot-analysis-integer (analysis) ...) -- commented declareFunction, no body
;; (defun clean-dot-accumulator (analysis char) ...) -- commented declareFunction, no body
;; (defun new-interval-token (&optional start end value) ...) -- commented declareFunction, no body
;; (defun interval-token-p (object) ...) -- commented declareFunction, no body
;; (defun interval-token-start (token) ...) -- commented declareFunction, no body
;; (defun interval-token-end (token) ...) -- commented declareFunction, no body
;; (defun interval-token-length (token) ...) -- commented declareFunction, no body
;; (defun interval-token-value (token) ...) -- commented declareFunction, no body
;; (defun interval-token-value-set (token value) ...) -- commented declareFunction, no body
;; (defun string-token-p (object) ...) -- commented declareFunction, no body
;; (defun new-string-token (&optional string value) ...) -- commented declareFunction, no body
;; (defun string-token-string (token) ...) -- commented declareFunction, no body
;; (defun string-token-value (token) ...) -- commented declareFunction, no body
;; (defun copy-string-token (token) ...) -- commented declareFunction, no body
;; (defun string-token-string-set (token string) ...) -- commented declareFunction, no body
;; (defun string-token-value-set (token value) ...) -- commented declareFunction, no body


;;;; Setup

(toplevel
  ;; Structures.register_method for print-object-method-table and def_csetf
  ;; calls are elided — CL defstruct provides print-object and setf accessors.
  (identity 'dot-analysis))
