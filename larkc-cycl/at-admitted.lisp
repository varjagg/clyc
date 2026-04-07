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

(defparameter *at-candidate-relations-table* nil)
(defparameter *at-candidate-relations-argnums-table* nil)
(defparameter *at-candidate-relations-sbhl-space* nil)
(defparameter *at-cr-mapping-result* nil)
(defparameter *at-cr-arg-isa-pred* nil)
(defparameter *at-cr-argnum* nil)

(deflexical *at-candidate-relations-max* 512
  "[Cyc] Estimated max number of candidate relations.")

(defparameter *ira-table* nil
  "[Cyc] Hashtable mapping relations -> boolean.")
(defparameter *ira-argnum* nil
  "[Cyc] An integer.")
(defparameter *ira-relations-estimate* 512
  "[Cyc] Estimated number of applicable relations.")
(defparameter *ira-isa-sbhl-space* nil)
(defparameter *ira-arg-isa-pred* nil
  "[Cyc] One of #$arg1Isa, #$arg2Isa, etc.")
(defparameter *ira-genl-sbhl-space* nil)
(defparameter *ira-arg-genl-pred* nil
  "[Cyc] One of #$arg1Genl, #$arg2Genl, etc.")
(defparameter *ira-mapping-result* nil)

;; Functions (declare section ordering)
;; All functions in this file are commented out in LarKC.

;; (defun admitted-argument?-internal (relation arg argnum &optional v-mt) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 3 required, 1 optional]
;; (defun admitted-argument? (relation arg argnum &optional v-mt) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 3 required, 1 optional]
;; (defun admitted-argument-int? (relation arg argnum v-mt) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 4 required, 0 optional]
;; (defun admitted-formula? (formula &optional v-mt) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 1 optional]
;; (defun admitted-sentence? (sentence &optional v-mt) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 1 optional]
;; (defun admitted-sentence-wrt-asent-arg-constraints? (sentence) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun admitted-atomic-sentence-wrt-arg-constraints? (asent) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun admitted-argument-plus-inter-arg-isa? (relation arg argnum) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 3 required, 0 optional]
;; (defun generic-arg-p (arg) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional; also has $generic_arg_p$UnaryFunction]
;; (defun relations-admitting-fort-as-arg (fort argnum &optional mt estimateP) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 2 required, 2 optional]
;; (defun relations-admitting-fort-as-any-of-args (fort argnums &optional mt) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 2 required, 1 optional]
;; (defun at-candidate-relations-admitting-fort (fort argnum &optional mt) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 2 required, 1 optional]
;; (defun at-cr-hash-relations (col) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun at-cr-hash-relations-by-argnum (col) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun at-cr-all-arg-isa-cached? (relation argnum) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 2 required, 0 optional]
;; (defun at-cr-argisa-col-searched? (col) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun inference-relations-admitting-fort-as-arg (fort argnum &optional mt) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 2 required, 1 optional]
;; (defun inference-relations-admitting-naut-as-arg (naut argnum &optional mt) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 2 required, 1 optional]
;; (defun inference-relations-admitting-term-as-arg-int (term) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun ira-isa-hash-relations (col) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun ira-all-arg-isa-cached? (relation) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun ira-argisa-col-searched? (col) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun ira-genl-hash-relations (col) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun ira-all-arg-genl-cached? (relation) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]
;; (defun ira-arggenl-col-searched? (col) ...) -- present in original Cyc, not in LarKC [commented declareFunction, 1 required, 0 optional]

;; Setup

(toplevel
  (note-memoized-function 'admitted-argument?))

;; Internal Constants accounting:
;; All 24 constants ($sym0 through $sym23) are orphans from the stripped function
;; bodies above. None are referenced in any active code in this file since all
;; functions are commented out. They document the symbols, keywords, and constants
;; that the original function bodies used:
;;   $sym0$ADMITTED_ARGUMENT_ = 'admitted-argument? -- memoized function name (used in setup)
;;   $sym1$INTEGERP = 'integerp -- type check
;;   $kw2$_MEMOIZED_ITEM_NOT_FOUND_ = :&memoized-item-not-found& -- memoization sentinel
;;   $kw3$IGNORE = :ignore -- keyword arg
;;   $sym4$FORT_P = 'fort-p -- type check
;;   $kw5$STRONG_FORT = :strong-fort -- fort type keyword
;;   $kw6$ISA = :isa -- sbhl module keyword
;;   $const7$genls = #$genls -- genls constant
;;   $const8$Thing = #$Thing -- Thing constant
;;   $kw9$GENLS = :genls -- sbhl module keyword
;;   $int10$512 = 512 -- used for *at-candidate-relations-max* and *ira-relations-estimate*
;;   $sym11$CONSP = 'consp -- type check
;;   $sym12$AT_CR_HASH_RELATIONS = 'at-cr-hash-relations -- function symbol
;;   $sym13$AT_CR_HASH_RELATIONS_BY_ARGNUM = 'at-cr-hash-relations-by-argnum -- function symbol
;;   $str14$no_mapping_method_defiend_for_sbh = "no mapping method defiend for sbhl-table ~s" -- error string
;;   $kw15$GAF = :gaf -- assertion type keyword
;;   $kw16$TRUE = :true -- truth value keyword
;;   $const17$argsIsa = #$argsIsa -- arg type constant
;;   $const18$argIsa = #$argIsa -- arg type constant
;;   $sym19$AT_CR_ARGISA_COL_SEARCHED_ = 'at-cr-argisa-col-searched? -- function symbol
;;   $sym20$NAUT_ = 'naut? -- type check
;;   $sym21$IRA_ARGISA_COL_SEARCHED_ = 'ira-argisa-col-searched? -- function symbol
;;   $const22$argsGenl = #$argsGenl -- arg type constant
;;   $sym23$IRA_ARGGENL_COL_SEARCHED_ = 'ira-arggenl-col-searched? -- function symbol
