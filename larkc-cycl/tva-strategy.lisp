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

;; TVA-STRATEGY defstruct
(defstruct (tva-strategy (:conc-name "TVA-STRAT-")
                         (:print-function print-tva-strategy))
  inverse-mode-p
  argnums-unified
  argnums-remaining
  tactics
  tactics-considered)

(defconstant *dtp-tva-strategy* 'tva-strategy)

(defun tva-strategy-print-function-trampoline (object stream)
  "[Cyc] Trampoline for printing tva-strategy objects."
  (missing-larkc 4330))

;; (defun tva-strategy-p (object) ...) -- no body, commented declareFunction
;; (defun tva-strat-inverse-mode-p (strategy) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-strat-argnums-unified (strategy) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-strat-argnums-remaining (strategy) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-strat-tactics (strategy) ...) -- no body, commented declareFunction, struct accessor
;; (defun tva-strat-tactics-considered (strategy) ...) -- no body, commented declareFunction, struct accessor
;; (defun _csetf-tva-strat-inverse-mode-p (strategy value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-strat-argnums-unified (strategy value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-strat-argnums-remaining (strategy value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-strat-tactics (strategy value) ...) -- no body, commented declareFunction, struct setter
;; (defun _csetf-tva-strat-tactics-considered (strategy value) ...) -- no body, commented declareFunction, struct setter
;; (defun make-tva-strategy (&optional arg1) ...) -- no body, commented declareFunction
;; (defun print-tva-strategy (strategy stream depth) ...) -- no body, commented declareFunction
;; (defun show-tva-strategy (strategy &optional stream) ...) -- no body, commented declareFunction
;; (defun new-tacticless-strategy () ...) -- no body, commented declareFunction
;; (defun new-strategy-with-tactics (tactics) ...) -- no body, commented declareFunction
;; (defun strategy-inverse-mode-p (strategy) ...) -- no body, commented declareFunction
;; (defun strategy-tactics (strategy) ...) -- no body, commented declareFunction
;; (defun strategy-considered-tactics (strategy) ...) -- no body, commented declareFunction
;; (defun strategy-argnums-unified (strategy) ...) -- no body, commented declareFunction
;; (defun strategy-argnums-remaining (strategy) ...) -- no body, commented declareFunction

;; do-strategy-remaining-argnums macro -- commented declareMacro
;; Arglist from $list34: ((ARGNUM-VAR STRATEGY) &BODY BODY)
;; Uses: CDOLIST, STRATEGY-ARGNUMS-REMAINING
(defmacro do-strategy-remaining-argnums (((argnum-var strategy) &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore argnum-var strategy body))
  (error "do-strategy-remaining-argnums: TODO macro body not yet reconstructed"))

;; do-strategy-tactics macro -- commented declareMacro
;; Arglist from $list37: ((TACTIC-VAR STRATEGY &KEY DONE) &BODY BODY)
;; Uses: CSOME, STRATEGY-TACTICS
;; $list38 = (:DONE), $kw39 = :ALLOW-OTHER-KEYS
(defmacro do-strategy-tactics (((tactic-var strategy &key done) &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore tactic-var strategy done body))
  (error "do-strategy-tactics: TODO macro body not yet reconstructed"))

;; do-strategy-tactics-after-tactic macro -- commented declareMacro
;; Arglist from $list43: ((TACTIC-VAR START-TACTIC STRATEGY &KEY DONE) &BODY BODY)
;; Uses: CDR, MEMBER, CSOME, STRATEGY-TACTICS
(defmacro do-strategy-tactics-after-tactic (((tactic-var start-tactic strategy &key done)
                                             &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore tactic-var start-tactic strategy done body))
  (error "do-strategy-tactics-after-tactic: TODO macro body not yet reconstructed"))

;; do-strategy-remaining-tactics macro -- commented declareMacro
;; Arglist from $list46: ((TACTIC-VAR STRATEGY-ARGNUM-VAR STRATEGY DONE?-VAR) &BODY BODY)
;; Uses: CDO, CAR, COR, NULL, PUNLESS, STRATEGY-CONSIDERED-TACTIC?,
;;       STRATEGY-UNIFIED-TACTIC-ARGNUM?, NOTE-STRATEGY-CONSIDERED-TACTIC,
;;       CLET, TVA-TACTIC-ARGNUM-TO-STRATEGY-ARGNUM, STRATEGY-INVERSE-MODE-P
;; and makeUninternedSymbol("SUBSTRATEGY")
(defmacro do-strategy-remaining-tactics (((tactic-var strategy-argnum-var strategy done?-var)
                                          &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore tactic-var strategy-argnum-var strategy done?-var body))
  (error "do-strategy-remaining-tactics: TODO macro body not yet reconstructed"))

;; (defun tva-strategy-inverse-mode-p (strategy) ...) -- no body, commented declareFunction
;; (defun tva-strategy-initial-tactic (strategy) ...) -- no body, commented declareFunction
;; (defun tva-strategy-tacticless? (strategy) ...) -- no body, commented declareFunction
;; (defun strategy-considered-tactic? (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun strategy-unified-tactic-argnum? (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun tva-strategy-subsumes-strategy-p (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun tactic-subsumed-in-strategy? (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun last-tactic-for-argnum? (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun no-strategy-argnums-remaining? (strategy) ...) -- no body, commented declareFunction
;; (defun strategy-complete-p (strategy) ...) -- no body, commented declareFunction
;; (defun strategy-considered-all-tactics? (strategy) ...) -- no body, commented declareFunction
;; (defun strategy-unified-all-tva-asent-args? (strategy) ...) -- no body, commented declareFunction
;; (defun arg-matching-tactics-remain-in-strategy? (strategy) ...) -- no body, commented declareFunction
;; (defun set-strategy-inverse-mode (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun set-strategy-argnums-unified (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun set-strategy-argnums-remaining (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun remove-tva-strategy-tactic (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun set-strategy-tactics (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun push-tva-tactic-onto-strategy (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun revert-strategy-argnums-and-tactics (arg1 arg2 arg3 arg4) ...) -- no body, commented declareFunction
;; (defun note-strategy-considered-tactic (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun add-strategy-argnum-to-remaining (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun delete-strategy-argnum-from-remaining (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun add-strategy-argnum-to-unified (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun delete-strategy-argnum-from-unified (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun note-strategy-argnum-unified (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun note-strategy-argnum-remaining (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun remove-tactics-subsumed-by-tactic (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun remove-tactics-for-matching-args (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun copy-strategy-possibly-flip-argnums (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun make-tva-simple-strategy () ...) -- no body, commented declareFunction

;; with-new-tva-strategy macro -- commented declareMacro
;; Arglist from $list61: (STRATEGY-VAR &BODY BODY)
;; $list62 = ((MAKE-TVA-DEFAULT-STRATEGY)) — the init form for CLET binding
;; Likely expands to (clet ((strategy-var (make-tva-default-strategy))) . body)
(defmacro with-new-tva-strategy ((strategy-var &body body))
  ;; Reconstructed arglist from Internal Constants; body expansion unknown.
  (declare (ignore strategy-var body))
  (error "with-new-tva-strategy: TODO macro body not yet reconstructed"))

;; (defun make-tva-default-strategy () ...) -- no body, commented declareFunction
;; (defun insert-new-tactic-into-strategy (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun remove-lookup-tactic-for-argnum (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun tva-restrategize (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun possibly-modify-strategy-tactics (arg1 arg2 arg3 arg4 arg5) ...) -- no body, commented declareFunction
;; (defun add-sentence-to-justs (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun add-subsumptions-to-justs (arg1 arg2 arg3 arg4 arg5) ...) -- no body, commented declareFunction
;; (defun proceed-with-tva-strategy (strategy) ...) -- no body, commented declareFunction
;; (defun sentence-subsumes-tva-asent-with-strategy (arg1 arg2) ...) -- no body, commented declareFunction
