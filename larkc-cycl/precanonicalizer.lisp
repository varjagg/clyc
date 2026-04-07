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

;; No variables in init section.

;; (defun immediate-precanonicalizations? (formula) ...) -- no body, commented declareFunction (1 0)
;; (defun immediate-precanonicalizations (formula) ...) -- no body, commented declareFunction (1 0)

(defun precanonicalizations? (formula mt &optional formula-is-an-asent-with-no-subformulas?)
  "[Cyc] When called by @xref canon-fast-gaf?, we can assume that FORMULA is
an atomic sentence with no subformulas, so some of these tests can be sped up
or bypassed entirely."
  (unless (hlmt-p mt)
    (return-from precanonicalizations? nil))
  (with-inference-mt-relevance mt
    (when (el-formula-p formula)
      (cond
        ((if formula-is-an-asent-with-no-subformulas?
             (expandible-el-relation-expression? formula)
             (formula-find-if #'expandible-el-relation-expression? formula nil))
          t)
        ((and (not formula-is-an-asent-with-no-subformulas?)
              (formula-find-if #'el-evaluatable-expression? formula nil))
          t)
        ((if formula-is-an-asent-with-no-subformulas?
             (el-implicit-meta-literal-sentence-p formula)
             (formula-find-if #'el-implicit-meta-literal-sentence-p formula nil))
          t)))))

(defun safe-precanonicalizations (formula mt)
  "[Cyc] A non-destructive version of @xref precanonicalizations."
  (let ((result formula)
        (result-mt mt))
    (when (precanonicalizations? formula mt)
      (let ((*el-symbol-suffix-table* (or *el-symbol-suffix-table*
                                          (make-hash-table :test #'eql :size 32)))
            (*standardize-variables-memory* (or *standardize-variables-memory*
                                                nil)))
        (let ((local-state *czer-memoization-state*))
          (let ((*memoization-state* local-state))
            (let ((original-memoization-process nil))
              (when (and local-state
                         (null (memoization-state-lock local-state)))
                (setf original-memoization-process
                      (memoization-state-get-current-process-internal local-state))
                (let ((current-proc (current-process)))
                  (if (null original-memoization-process)
                      (memoization-state-set-current-process-internal local-state current-proc)
                      (unless (eq original-memoization-process current-proc)
                        (error "Invalid attempt to reuse memoization state in multiple threads simultaneously.")))))
              (unwind-protect
                  (multiple-value-setq (result result-mt)
                    ;; missing-larkc 7666: likely precanonicalizations-int,
                    ;; the internal destructive precanonicalization implementation
                    (missing-larkc 7666))
                (when (and local-state (null original-memoization-process))
                  (memoization-state-set-current-process-internal local-state nil))))))))
    (values result result-mt)))

(defun precanonicalizations (formula mt)
  "[Cyc] Performs some simplifications on FORMULA to prepare it for canonicalization.
It recursively transforms EL relations, evaluates evaluatable expressions,
and then it removes exceptions and pragmatic requirements.
This is a destructive operation.
Assumes the EL var namespace is bound."
  (let ((new-formula formula)
        (new-mt mt))
    (when (precanonicalizations? formula mt)
      (let ((local-state *czer-memoization-state*))
        (let ((*memoization-state* local-state))
          (let ((original-memoization-process nil))
            (when (and local-state
                       (null (memoization-state-lock local-state)))
              (setf original-memoization-process
                    (memoization-state-get-current-process-internal local-state))
              (let ((current-proc (current-process)))
                (if (null original-memoization-process)
                    (memoization-state-set-current-process-internal local-state current-proc)
                    (unless (eq original-memoization-process current-proc)
                      (error "Invalid attempt to reuse memoization state in multiple threads simultaneously.")))))
            (unwind-protect
                (multiple-value-setq (new-formula new-mt)
                  ;; missing-larkc 7667: likely precanonicalizations-int,
                  ;; the internal destructive precanonicalization implementation
                  (missing-larkc 7667))
              (when (and local-state (null original-memoization-process))
                (memoization-state-set-current-process-internal local-state nil)))))))
    (values new-formula new-mt)))

;; (defun precanonicalizations-int-internal (formula mt) ...) -- no body, commented declareFunction (2 0)
;; (defun precanonicalizations-int (formula mt) ...) -- no body, commented declareFunction (2 0)
;; (defun el-evaluatable-expressions-out (formula) ...) -- no body, commented declareFunction (1 0)
;; (defun transform-evaluation-expression-or-throw (expression) ...) -- no body, commented declareFunction (1 0)
;; (defun transform-evaluation-expression (expression) ...) -- no body, commented declareFunction (1 0)

(defun el-evaluatable-expression? (object &optional mt)
  "[Cyc]"
  (and (el-evaluatable-functor? (formula-arg0 object) mt)
       ;; missing-larkc 30556: likely checks that the expression's arguments are
       ;; evaluatable (possibly evaluatable-expression-args? or similar)
       (missing-larkc 30556)
       ;; missing-larkc 7656: likely checks well-formedness of the evaluatable
       ;; expression (possibly wff-evaluatable-expression? or similar)
       (missing-larkc 7656)
       t))

(defun el-evaluatable-functor? (object &optional mt)
  "[Cyc]"
  (when (fort-p object)
    (and (el-evaluatable-functor-somewhere? object)
         (some-pred-value-in-relevant-mts object #$evaluateAtEL mt)
         t)))

(defun el-evaluatable-functor-somewhere? (object)
  "[Cyc]"
  (some-pred-assertion-somewhere? #$evaluateAtEL object 1))

;; (defun el-evaluatable-subexpressions? (formula &optional mt) ...) -- no body, commented declareFunction (1 1)
;; (defun el-unevaluatable-expression? (object &optional mt) ...) -- no body, commented declareFunction (1 1)
;; (defun immediately-evaluatable-expressions-out (formula) ...) -- no body, commented declareFunction (1 0)
;; (defun immediately-evaluatable-expression? (object) ...) -- no body, commented declareFunction (1 0)
;; (defun immediately-evaluatable-functor? (object) ...) -- no body, commented declareFunction (1 0)
;; (defun immediately-evaluatable-functor-somewhere? (object) ...) -- no body, commented declareFunction (1 0)
;; (defun immediately-evaluatable-subexpressions? (formula) ...) -- no body, commented declareFunction (1 0)
;; (defun immediately-unevaluatable-expression? (object) ...) -- no body, commented declareFunction (1 0)
;; (defun implicit-meta-literals-out (formula) ...) -- no body, commented declareFunction (1 0)
;; (defun implicit-meta-literals-out-int (formula) ...) -- no body, commented declareFunction (1 0)
;; (defun implicit-meta-literals-out-for-implict-meta-literal-sentence (formula) ...) -- no body, commented declareFunction (1 0)

;; Setup
(toplevel
  (note-memoized-function 'precanonicalizations-int))
