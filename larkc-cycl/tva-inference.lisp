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

;;; Defstruct
;;; print-object is missing-larkc 4648 — CL's default print-object handles this.

(defstruct (tva-inference (:conc-name "tva-inf-")
                          (:constructor make-tva-inference (&key problem asent-pred
                                                                asent-args args-admitted
                                                                term-argnums var-argnums
                                                                precomputations reused-spaces
                                                                one-answer? justify?
                                                                restricted-assertion answers)))
  problem
  asent-pred
  asent-args
  args-admitted
  term-argnums
  var-argnums
  precomputations
  reused-spaces
  one-answer?
  justify?
  restricted-assertion
  answers)

;;; Variables

(deflexical *tva-max-time-enabled?* t
  "[Cyc] Whether the inner loop of TVA-UNIFY checks its current controlling inference to see if its :MAX-TIME parameter has been exceeded.")

(defconstant *dtp-tva-inference* 'tva-inference)

(defparameter *tva-inference* nil
  "[Cyc] The current TVA inference.")

(defparameter *tva-reuse-spaces?* nil
  "[Cyc] Reuse search spaces when the same transitive predicate and goal-node are used multiple times.  Saves time and space.")

;;; Functions

(defun determine-term-argnums (asent)
  "[Cyc] @return listp. Determines the argnums for each of the fully bound terms in ASENT."
  (let ((result nil))
    (dolist (num (rest (num-list (formula-length asent))))
      (when (fully-bound-p (atomic-sentence-arg asent num))
        (push num result)))
    (nreverse result)))

;; Reconstructed from Internal Constants:
;;   $sym48$CLET = CLET
;;   $list49 = ((*TVA-INFERENCE* (MAKE-TVA-INFERENCE)))
;; Standard with-new-* binding pattern.
(defmacro with-new-tva-inference (&body body)
  `(let ((*tva-inference* (make-tva-inference)))
     ,@body))

;;; Commented stubs

;; (defun print-tva-inference (object stream depth) ...) -- commented declareFunction, no body
;; (defun initialize-tva-inference (asent one-answer? justify?) ...) -- commented declareFunction, no body
;; (defun tva-inference-asent-pred (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-asent-args (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-args-admitted (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-term-argnums (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-var-argnums (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-precomputations (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-reused-spaces (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-justify? (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-one-answer? (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-restricted-assertion (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-answers (tva-inference) ...) -- commented declareFunction, no body
;; (defun tva-inference-asent-arg (tva-inference argnum) ...) -- commented declareFunction, no body
;; (defun tva-inference-arg-admitted (tva-inference argnum) ...) -- commented declareFunction, no body
;; (defun store-tva-inference-precomputation (tva-inference key value) ...) -- commented declareFunction, no body
;; (defun store-tva-inference-reused-spaces (tva-inference key value) ...) -- commented declareFunction, no body
;; (defun set-tva-inference-arg-admitted (tva-inference argnum value) ...) -- commented declareFunction, no body
;; (defun tva-asent-pred () ...) -- commented declareFunction, no body
;; (defun tva-var-argnums () ...) -- commented declareFunction, no body
;; (defun tva-var-argnum (index) ...) -- commented declareFunction, no body
;; (defun tva-term-argnums () ...) -- commented declareFunction, no body
;; (defun tva-asent-arg (argnum) ...) -- commented declareFunction, no body
;; (defun tva-asent-arg-admitted (argnum) ...) -- commented declareFunction, no body
;; (defun set-tva-asent-arg-admitted (argnum) ...) -- commented declareFunction, no body
;; (defun set-tva-asent-arg-failed (argnum) ...) -- commented declareFunction, no body
;; (defun tva-return-one-answer? () ...) -- commented declareFunction, no body
;; (defun tva-compute-justifications? () ...) -- commented declareFunction, no body
;; (defun tva-tactic-precomputations (tactic) ...) -- commented declareFunction, no body
;; (defun tva-store-precomputation (key value) ...) -- commented declareFunction, no body
;; (defun tva-restricted-assertion-p (assertion) ...) -- commented declareFunction, no body
;; (defun tva-reused-spaces () ...) -- commented declareFunction, no body
;; (defun tva-store-reused-spaces (key value) ...) -- commented declareFunction, no body
;; (defun tva-reused-spaces-for-relation (key default) ...) -- commented declareFunction, no body
;; (defun tva-answers () ...) -- commented declareFunction, no body
;; (defun add-to-tva-answers (answer) ...) -- commented declareFunction, no body
;; (defun determine-var-argnums (asent) ...) -- commented declareFunction, no body
;; (defun determine-restricted-assertion (asent) ...) -- commented declareFunction, no body
;; (defun initialize-tva-asent-vector (asent) ...) -- commented declareFunction, no body
;; (defun initialize-tva-args-admitted-vector (asent) ...) -- commented declareFunction, no body
;; (defun tva-unify (asent &optional one-answer? justify? v-bindings hypothetical-bindings restricted-assertion) ...) -- commented declareFunction, no body
;; (defun tva-unify-from-cache (asent cached-tva-cache &optional one-answer? justify?) ...) -- commented declareFunction, no body
;; (defun tva-unify-closure (node tva-precomputation) ...) -- commented declareFunction, no body
;; (defun tva-marked-p (node search-space) ...) -- commented declareFunction, no body
;; (defun tva-mark-node-marked (node search-space) ...) -- commented declareFunction, no body
;; (defun tva-mark-and-sweep (node tva-precomputation) ...) -- commented declareFunction, no body
;; (defun tva-unify-closure-iterator (asent &optional one-answer? justify?) ...) -- commented declareFunction, no body
;; (defun tva-unify-closure-iterator-int (asent var-argnums) ...) -- commented declareFunction, no body
;; (defun tva-unify-closure-iterator-state (asent var-argnums) ...) -- commented declareFunction, no body
;; (defun tva-unify-closure-iterator-done (state) ...) -- commented declareFunction, no body
;; (defun tva-unify-closure-iterator-next (state) ...) -- commented declareFunction, no body
;; (defun tva-unify-closure-iterator-finalize (state) ...) -- commented declareFunction, no body
;; (defun new-tva-unify-closure-answer-iterator (iterator var-argnums) ...) -- commented declareFunction, no body
;; (defun new-tva-unify-closure-bindings-iterators (asent var-argnums) ...) -- commented declareFunction, no body
;; (defun new-tva-unify-closure-var-bindings-iterator (var-argnum tva-precomputation) ...) -- commented declareFunction, no body
;; (defun tva-unify-closure-var-bindings-iterator-done (state) ...) -- commented declareFunction, no body
;; (defun tva-unify-closure-var-bindings-iterator-next (state) ...) -- commented declareFunction, no body
;; (defun tva-unify-closure-var-bindings-iterator-finalize (state) ...) -- commented declareFunction, no body
