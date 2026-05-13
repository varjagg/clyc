#|
  Copyright (c) 2019 White Flame

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


;; (defun nart-hl-formula (nart) ...) -- commented declareFunction, no body, Cyc API

;; commented declareFunction, but body present in Java -- ported for reference
(defun nart-lookup (nart-hl-formula)
  "[Cyc] Return the NART implementing NART-HL-FORMULA, or NIL if none is present.
No substitutions for sub-NARTs are performed."
  (if (and (not *bootstrapping-kb*)
           (or (not (reifiable-functor? (nat-functor nart-hl-formula)))
               (not (fully-bound-p nart-hl-formula))))
      nil
      (nart-from-hl-formula nart-hl-formula)))

(defun naut-p (object)
  "[Cyc] Return T iff OBJECT is a datastructure implementing a non-atomic unreified term (NAUT).
By definition, this satisfies CYCL-NAT-P but not NART-P."
  (and (possibly-naut-p object)
       (cycl-nat-p object)))

;; (defun invalid-nart? (nart &optional robust?) ...) -- commented declareFunction, no body
;; (defun invalid-nart-robust? (nart) ...) -- commented declareFunction, no body
;; (defun nart-el-formula (nart) ...) -- commented declareFunction, no body, Cyc API

;; commented declareFunction, but body present in Java -- ported for reference
(defun find-nart (nart-hl-formula)
  "[Cyc] Return the nart implementing NART-HL-FORMULA, or NIL if none is present.
Substitutions for existing sub-NARTs are performed."
  (declare (type possibly-naut-p nart-hl-formula))
  (let ((nart (nart-substitute nart-hl-formula)))
    (and (nart-p nart)
         nart)))

;; (defun random-nart (&optional test) ...) -- commented declareFunction, no body, Cyc API
;; (defun hl-find-or-create-nart (nart-hl-formula) ...) -- commented declareFunction, no body
;; (defun tl-find-or-create-nart (nart-hl-formula) ...) -- commented declareFunction, no body
;; (defun find-or-create-nart (nart-hl-formula) ...) -- commented declareFunction, no body

(defun remove-dependent-narts (fort)
  "[Cyc] Remove all current NARTs which are functions of FORT."
  (declare (type fort-p fort))
  (let ((dependencies (dependent-narts fort)))
    (dolist (dependent dependencies)
      ;; missing-larkc 30883 -- likely a predicate gating whether the dependent
      ;; should actually be removed (candidates: useful-nart?, invalid-nart?,
      ;; nart-specified-to-be-retained?, all commented-out in this same file)
      (when (missing-larkc 30883)
        (must (not (eq fort dependent))
              "A horrible and gross circularity has occurred -- ~s is a dependent of itself!" fort)
        (cyc-kill dependent)))))

;; (defun remove-nart (nart) ...) -- commented declareFunction, no body, Cyc API

(defun nart-expand (object)
  "[Cyc] Recursively expand all NARTs in OBJECT into their EL forms (NAUTs)."
  (if (tree-find-if #'nart-p object)
      (transform object #'nart-p #'nart-el-formula)
      object))

(defun nart-substitute (object)
  "[Cyc] Substitute into OBJECT as many NARTs as possible.
If the entire formula can be converted to a NART, it will.
Returns OBJECT itself if no substitutions can be made."
  (if (possibly-naut-p object)
      (nart-substitute-recursive object)
      object))

;; commented declareFunction, but body present in Java -- ported for reference
(defun nart-substitute-recursive (tree)
  (if (subl-escape-p tree)
      tree
      (let ((result tree))
        (if (contains-nat-formula-as-element? tree)
            (let ((new-tree (copy-list tree)))
              (do ((list new-tree (cdr list)))
                  ((atom list)
                   (setf result new-tree))
                (let ((arg (car list)))
                  (when (nat-formula-p arg)
                    (let ((sub-nart (nart-substitute-recursive arg)))
                      (when sub-nart
                        (rplaca list sub-nart)))))))
            (setf result tree))
        (let ((nart (nart-lookup result)))
          (if (nart-p nart)
              nart
              result)))))

;; commented declareFunction, but body present in Java -- ported for reference
(defun contains-nat-formula-as-element? (list)
  "[Cyc] Return T iff LIST contains at least one element that could be reified as a nart. It does not consider whether LIST itself could be reified as a nart, and it does not look deeper than one level of nesting."
  (do ((rest list (cdr rest)))
      ((atom rest))
    (when (nat-formula-p (car rest))
      (return t))))

;; (defun nart-with-functor-p (functor nart) ...) -- commented declareFunction, no body
;; (defun nart-checkpoint-p (object) ...) -- commented declareFunction, no body
;; (defun new-nart-checkpoint () ...) -- commented declareFunction, no body
;; (defun nart-checkpoint-current? (checkpoint) ...) -- commented declareFunction, no body
;; (defun nart-dump-id (nart) ...) -- commented declareFunction, no body

(defparameter *nart-dump-id-table* nil)

(defun find-nart-by-dump-id (dump-id)
  "[Cyc] Return the NART with DUMP-ID during a KB load."
  (find-nart-by-id dump-id))

;; Reconstructed from Internal Constants: $sym29$CLET + $list30 =
;;   ((*NART-DUMP-ID-TABLE* (CREATE-NART-DUMP-ID-TABLE))
;;    (*CFASL-NART-HANDLE-FUNC* 'NART-DUMP-ID))
;; CREATE-NART-DUMP-ID-TABLE is registered as a macro-helper for
;; WITH-NART-DUMP-ID-TABLE in nart-handles.java
;; (access_macros.register_macro_helper $sym17$CREATE_NART_DUMP_ID_TABLE
;;                                      $sym18$WITH_NART_DUMP_ID_TABLE).
;; Parallel to with-assertion-dump-id-table in assertions-high.lisp.
(defmacro with-nart-dump-id-table (&body body)
  `(let ((*nart-dump-id-table* (create-nart-dump-id-table))
         (*cfasl-nart-handle-func* 'nart-dump-id))
     ,@body))

;; (defun useful-nart? (nart) ...) -- commented declareFunction, no body
;; (defun useless-nart? (nart) ...) -- commented declareFunction, no body
;; (defun nart-specified-to-be-retained? (nart) ...) -- commented declareFunction, no body
;; (defun skolemize-forward-nart? (nart) ...) -- commented declareFunction, no body
;; (defun nart-independent-assertions (nart) ...) -- commented declareFunction, no body
;; (defun nart-independent-assertions-internal (nart) ...) -- commented declareFunction, no body
;; (defun nart-id-from-recipe (recipe) ...) -- commented declareFunction, no body
;; (defun nart-knows-its-hl-formula? (nart) ...) -- commented declareFunction, no body
;; (defun all-narts-know-their-hl-formulas? () ...) -- commented declareFunction, no body
;; (defun narts-that-dont-know-their-hl-formulas () ...) -- commented declareFunction, no body
;; (defun nart-findable-by-hl-formula? (nart) ...) -- commented declareFunction, no body

;; Orphan Internal Constants from stripped function bodies:
;;   $sym27$NON_NEGATIVE_INTEGER_P -- checkType inside a stripped fn (likely
;;     find-nart-by-dump-id originally had a non-negative-integer-p type check)
;;   $list28 (CHECKPOINT-COUNT CHECKPOINT-NEXT-ID) -- accessor list for the
;;     stripped nart-checkpoint defstruct (slots removed with the body)
;;   $sym31$RELEVANT_MT_IS_EVERYTHING + $const32$EverythingPSC -- (with-all-mts ...)
;;     expansion that lived inside nart-independent-assertions-internal
;;   $sym33$NART_INDEPENDENT_ASSERTIONS_INTERNAL -- self-reference inside the
;;     stripped nart-independent-assertions wrapper
;;   $str34 "Looking for bad narts" + $sym35$STRINGP + $kw36$SKIP +
;;     $list37 (gensyms START END DELTA) -- progress-reporting macro expansion
;;     inside one of the stripped narts-walk functions



;;; Cyc API registrations

(register-cyc-api-function 'nart-hl-formula '(nart)
    "Return the hl formula of this NART."
    '((nart nart-p))
    '((nil-or consp)))


(register-cyc-api-function 'naut-p '(object)
    "Return T iff OBJECT is a datastructure implementing a non-atomic unreified term (NAUT).
   By definition, this satisies @xref CYCL-NAT-P but not @xref NART-P."
    'nil
    '(booleanp))


(register-cyc-api-function 'nart-el-formula '(nart)
    "Return the el formula of this NART."
    '((nart nart-p))
    '((nil-or consp)))


(register-cyc-api-function 'random-nart '(&optional (test (function true)))
    "Return a randomly chosen NART that satisfies TEST"
    'nil
    '(nart-p))


(define-obsolete-register 'hl-find-or-create-nart '(cyc-find-or-create-nart))


(define-obsolete-register 'find-or-create-nart '(hl-find-or-create-nart))


(register-cyc-api-function 'remove-nart '(nart)
    "Remove NART from the KB."
    '((nart nart-p))
    '(null))
