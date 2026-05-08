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

;; TVA-TACTIC defstruct
;; print-object is missing-larkc 10214 — CL's default print-object handles this.
(defstruct tva-tactic
  type
  tva-pred
  index-pred
  transitive-pred
  argnum
  term
  cost
  precomputation
  parent-pred
  parent-pred-inverse?)

(defconstant *dtp-tva-tactic* 'tva-tactic)

;; (defun tva-tactic-p (object) ...) -- no body, commented declareFunction
;; (defun tva-type (tactic) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-tva-pred (tactic) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-index-pred (tactic) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-transitive-pred (tactic) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-argnum (tactic) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-term (tactic) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-cost (tactic) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-precomputation (tactic) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-parent-pred (tactic) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-parent-pred-inverse? (tactic) ...) -- no body, commented declareFunction, struct accessor
;; (defun _csetf-tva-type (tactic value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-tva-pred (tactic value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-index-pred (tactic value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-transitive-pred (tactic value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-argnum (tactic value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-term (tactic value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-cost (tactic value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-precomputation (tactic value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-parent-pred (tactic value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-parent-pred-inverse? (tactic value) ...) -- no body, commented declareFunction, struct setter
;; (defun make-tva-tactic (&optional arg1) ...) -- no body, commented declareFunction
;; (defun print-tva-tactic (tactic stream depth) ...) -- no body, commented declareFunction
;; (defun show-tva-tactic (tactic &optional stream) ...) -- no body, commented declareFunction
;; (defun new-tva-tactic (arg1 arg2 arg3 arg4 arg5 arg6 arg7) ...) -- no body, commented declareFunction
;; (defun copy-tva-tactic (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun tva-tactic-tva-pred (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-index-pred (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-transitive-pred (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-parent-pred (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-parent-pred-inverse? (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-argnum (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-term (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-cost (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-type (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-precomputation (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-tva-argnum (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun tva-tactic-direction (tactic) ...) -- no body, commented declareFunction
;; (defun tva-forward-direction-tactic? (tactic) ...) -- no body, commented declareFunction
;; (defun tva-sentence-arg-for-tactic (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun tva-tactic-argnum-to-strategy-argnum (arg1 arg2) ...) -- no body, commented declareFunction

;; do-tva-precomputation-table macro -- commented declareMacro
;; Arglist from $list54: ((ARG-VAR TVA-TACTIC DONE-VAR) &BODY BODY)
;; Uses: DO-SBHL-TABLE, TVA-TACTIC-PRECOMPUTATION, IGNORE, TVA-PRECOMPUTATION-P
;; and makeUninternedSymbol("MARKING-VAR")
;; Iterates over the precomputation table of a tva-tactic.
(defmacro do-tva-precomputation-table (((arg-var tva-tactic done-var) &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore arg-var tva-tactic done-var body))
  (error "do-tva-precomputation-table: TODO macro body not yet reconstructed"))

;; (defun set-tva-tactic-index-pred (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun set-tva-tactic-cost (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun set-tva-tactic-precomputation (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun set-tva-tactic-cost-possible-precomputation (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun sufficient-tactic-p (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic-type-p (arg1) ...) -- no body, commented declareFunction
;; (defun tva-type< (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun tva-lookup-tactic-p (tactic) ...) -- no body, commented declareFunction
;; (defun tva-precomputed-tactic-p (tactic) ...) -- no body, commented declareFunction
;; (defun tva-calculate-closure-tactic-p (tactic) ...) -- no body, commented declareFunction
;; (defun tva-predicate-extent-tactic-p (tactic) ...) -- no body, commented declareFunction
;; (defun tva-tactic< (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun tva-tactic-subsumes-tactic-p (arg1 arg2 &optional arg3) ...) -- no body, commented declareFunction
;; (defun tva-tactics-overlap-p (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun tva-inverse-tactics-overlap-p (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun determine-tva-tactic-type (arg1 arg2 arg3 arg4) ...) -- no body, commented declareFunction
;; (defun determine-tactic-type-from-cardinality (arg1 arg2 arg3 arg4) ...) -- no body, commented declareFunction
;; (defun tva-cost-and-precomputation (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun prune-sbhl-closure-wrt-genl-preds-and-inverse (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun compute-tva-closure (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun tva-closure-cardinality (arg1) ...) -- no body, commented declareFunction
;; (defun tva-closure-cardinality-estimate (arg1 arg2 arg3) ...) -- no body, commented declareFunction

;; tva-do-all-gaf-arg-index macro -- commented declareMacro
;; Arglist from $list75: ((SENTENCE-VAR MT-VAR PRED TERM ARGNUM DONE?-VAR) &BODY BODY)
;; Uses: PROGN, CLET, DO-GAF-ARG-INDEX, PWHEN-FEATURE, :CYC-SKSI, PWHEN,
;;       SKSI-GAF-ARG-POSSIBLE-P, DO-SKSI-GAF-ARG-INDEX-GP
;; Iterates GAF arg index entries, including SKSI if enabled.
(defmacro tva-do-all-gaf-arg-index (((sentence-var mt-var pred term argnum done?-var)
                                      &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore sentence-var mt-var pred term argnum done?-var body))
  (error "tva-do-all-gaf-arg-index: TODO macro body not yet reconstructed"))

;; do-tva-sentences-for-lookup-tactic macro -- commented declareMacro
;; Arglist from $list90: ((SENTENCE-VAR MT-VAR TACTIC DONE?-VAR) &BODY BODY)
;; Uses: TVA-TACTIC-ARGNUM, TVA-TACTIC-TERM, TVA-DO-ALL-GAF-ARG-INDEX
;; and makeUninternedSymbol("PRED"), makeUninternedSymbol("ARG"), makeUninternedSymbol("ARGNUM")
(defmacro do-tva-sentences-for-lookup-tactic (((sentence-var mt-var tactic done?-var)
                                                &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore sentence-var mt-var tactic done?-var body))
  (error "do-tva-sentences-for-lookup-tactic: TODO macro body not yet reconstructed"))

;; do-tva-sentences-for-precomputed-tactic macro -- commented declareMacro
;; Arglist same as lookup: ((SENTENCE-VAR MT-VAR TACTIC DONE?-VAR) &BODY BODY)
;; Uses: DO-TVA-PRECOMPUTATION-TABLE, TVA-TACTIC-TRANSITIVE-PRED,
;;       TVA-DIRECTION-FOR-TVA-PRED, TVA-TACTIC-TVA-PRED, PIF,
;;       GET-SBHL-MODULE, DO-ALL-SIMPLE-TRUE-LINKS-FOR-INVERSES, DO-GHL-CLOSURE, PUNLESS
;; and makeUninternedSymbol("PRED"), makeUninternedSymbol("ARG"), makeUninternedSymbol("ARGNUM"),
;;     makeUninternedSymbol("TRANS-PRED"), makeUninternedSymbol("TRANS-PRED-MODULE"),
;;     makeUninternedSymbol("DIRECTION"), makeUninternedSymbol("LINK-NODE")
(defmacro do-tva-sentences-for-precomputed-tactic (((sentence-var mt-var tactic done?-var)
                                                     &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore sentence-var mt-var tactic done?-var body))
  (error "do-tva-sentences-for-precomputed-tactic: TODO macro body not yet reconstructed"))

;; do-tva-sentences-for-calculate-closure-tactic macro -- commented declareMacro
;; Same arglist pattern as above
(defmacro do-tva-sentences-for-calculate-closure-tactic (((sentence-var mt-var tactic done?-var)
                                                           &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore sentence-var mt-var tactic done?-var body))
  (error "do-tva-sentences-for-calculate-closure-tactic: TODO macro body not yet reconstructed"))

;; do-tva-sentences-for-predicate-extent-tactic macro -- commented declareMacro
;; Uses: DO-PREDICATE-EXTENT-INDEX, TVA-ITERATES-KB-PREDICATE-EXTENT?,
;;       TVA-ITERATES-SKSI-PREDICATE-EXTENT?, DO-SKSI-PREDICATE-EXTENT-INDEX
;; and makeUninternedSymbol("PRED")
(defmacro do-tva-sentences-for-predicate-extent-tactic (((sentence-var mt-var tactic done?-var)
                                                          &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore sentence-var mt-var tactic done?-var body))
  (error "do-tva-sentences-for-predicate-extent-tactic: TODO macro body not yet reconstructed"))

;; (defun possibly-discharge-evaluatable-predicate-meta-tactic (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun discharge-tva-precomputed-tactic (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun discharge-tva-calculate-closure-tactic (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun discharge-tva-predicate-extent-tactic (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun tva-justify-subsumption (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun tva-index-to-parent-pred-justification (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun tva-parent-to-asent-pred-justification (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun genl-inverse-support-in-supports? (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun genl-preds-support-in-supports? (arg1 arg2 arg3) ...) -- no body, commented declareFunction

;; Init
(deflexical *tva-tactic-types* '(:lookup :precomputed-closure :calculate-closure :predicate-extent)
  "[Cyc] The TVA tactic types, in order of intended execution (faster ones first).")
