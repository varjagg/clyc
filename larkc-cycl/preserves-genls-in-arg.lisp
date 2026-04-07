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

;; Parameters used during PGIA (preserves-genls-in-arg) processing.
(defparameter *pgia-fn* nil)
(defparameter *pgia-gaf* nil)
(defparameter *pgia-arg* nil)
(defparameter *pgia-done* nil)
(defparameter *pgia-nat* nil)
(defparameter *pgia-nat-fort* nil)
(defparameter *pgia-col* nil)
(defparameter *pgia-genl* nil)
(defparameter *pgia-genl-nat* nil)
(defparameter *pgia-genl-nats* nil)
(defparameter *pgia-spec* nil)
(defparameter *pgia-spec-nat* nil)
(defparameter *pgia-spec-nats* nil)
(defparameter *candidate-pgia-genls* nil)
(defparameter *candidate-pgia-specs* nil)
(defparameter *consider-current-pgia?* nil)
(defparameter *current-pgia-genls* nil)
(defparameter *current-pgia-specs* nil)

(defglobal *pgia-mt* #$BaseKB)

(defparameter *pgia-rule*
  (list #$implies
        (list #$and
              (list #$preservesGenlsInArg
                    (list #$FormulaArgFn 0 '?nat-1)
                    '?arg)
              (list #$equals
                    (list #$FormulaArgFn 0 '?nat-1)
                    (list #$FormulaArgFn 0 '?nat-2))
              (list #$different '?nat-1 '?nat-2)
              (list #$genls
                    (list #$FormulaArgFn '?arg '?nat-1)
                    (list #$FormulaArgFn '?arg '?nat-2)))
        (list #$genls '?nat-1 '?nat-2)))

;; Functions, in declare section order.

;; (defun pgia-after-adding-pgia (argument assertion) ...) -- commented declareFunction (2 0)
;; (defun pgia-after-adding-pgia-1 (nat) ...) -- commented declareFunction (1 0)
;; (defun pgia-after-adding-pgia-2 (genl-col) ...) -- commented declareFunction (1 0)
;; (defun pgia-after-adding-pgia-3 (spec-col) ...) -- commented declareFunction (1 0)

(defun pgia-after-adding-isa (argument assertion)
  "[Cyc] PGIA after-adding for #$isa assertions. Checks if a NAT has been asserted to
be an instance of a collection type, and if so, propagates genls links based on
preservesGenlsInArg constraints."
  (when *pgia-active?*
    (unless (member? argument (assertion-arguments assertion) :test #'not-eq)
      (let ((*added-source* argument))
        (when (true-assertion? assertion)
          (let* ((mt (assertion-mt assertion))
                 (nat-fort (gaf-arg1 assertion))
                 (col-type (gaf-arg2 assertion))
                 (nat (missing-larkc 10747))
                 (redundant? (missing-larkc 2045)))
            (unless redundant?
              (let ((*relevant-mt-function* #'relevant-mt-is-everything)
                    (*mt* #$EverythingPSC))
                (setf redundant? (member? col-type (missing-larkc 3661) :test #'not-eq)))
              (unless redundant?
                (when (and nat
                           (genls? col-type #$Collection mt))
                  (let ((*pgia-fn* (nat-functor nat))
                        (*pgia-nat-fort* nat-fort)
                        (*pgia-nat* nat)
                        (*relevant-mt-function* #'relevant-mt-is-everything)
                        (*mt* #$EverythingPSC))
                    (missing-larkc 9452))))))))))
  nil)

;; (defun pgia-after-adding-isa-1 (gaf) ...) -- commented declareFunction (1 0)
;; (defun pgia-after-adding-isa-2 (gaf) ...) -- commented declareFunction (1 0)

(defun pgia-after-removing-genls (deduction assertion)
  "[Cyc] PGIA after-removing for #$genls assertions. When a genls link is removed,
checks if the spec and genl are NATs with the same functor, and if so removes
the corresponding PGIA-derived genls links."
  (when *pgia-active?*
    (when (missing-larkc 3748)
      (let* ((axiom (gaf-formula assertion))
             (truth (assertion-truth assertion))
             (mt (assertion-mt assertion)))
        (let ((*pgia-spec* (second axiom))
              (*pgia-genl* (third axiom)))
          (unless (assertion-still-there? assertion truth)
            (let ((*pgia-spec-nat* (missing-larkc 10748))
                  (*pgia-genl-nat* (missing-larkc 10749)))
              (when (and *pgia-spec-nat* *pgia-genl-nat*)
                (let ((*pgia-fn* (nat-functor *pgia-spec-nat*)))
                  (when (eq *pgia-fn* (nat-functor *pgia-genl-nat*))
                    (let ((*relevant-mt-function* #'relevant-mt-is-genl-mt)
                          (*mt* mt))
                      (missing-larkc 9453)))))))))))
  nil)

;; (defun pgia-after-removing-genls-1 (gaf) ...) -- commented declareFunction (1 0)
;; (defun candidate-pgia (fn col genl-nat nat-fort mt &optional rule) ...) -- commented declareFunction (5 1)
;; (defun pgia-true-in-mts (genl-nat nat-fort mt) ...) -- commented declareFunction (3 0)
;; (defun recompute-functor-pgia (fn) ...) -- commented declareFunction (1 0)
;; (defun recompute-functor-pgia-1 (gaf) ...) -- commented declareFunction (1 0)
;; (defun recompute-nat-pgia (nat) ...) -- commented declareFunction (1 0)
;; (defun recompute-nat-pgia-1 (gaf) ...) -- commented declareFunction (1 0)
;; (defun current-pgia-specs (col mt) ...) -- commented declareFunction (2 0)
;; (defun current-pgia-genls (col mt) ...) -- commented declareFunction (2 0)
;; (defun gather-pgia (gaf) ...) -- commented declareFunction (1 0)
;; (defun pgia-assertion? (assertion &optional mt) ...) -- commented declareFunction (1 1)
;; (defun pgia-support? (support) ...) -- commented declareFunction (1 0)
;; (defun pgia-deduction? (deduction &optional assertion) ...) -- commented declareFunction (1 1)
;; (defun assert-candidate-pgia-genls () ...) -- commented declareFunction (0 0)
;; (defun assert-candidate-pgia-specs () ...) -- commented declareFunction (0 0)
;; (defun known-pgia? (spec genl mt) ...) -- commented declareFunction (3 0)
;; (defun candidate-pgia? (spec genl mt) ...) -- commented declareFunction (3 0)
;; (defun map-tous-of-fn-arg (fn arg pred func) ...) -- commented declareFunction (4 0)

;; Setup phase
(declare-defglobal '*pgia-mt*)
(note-mt-var '*pgia-mt*)
(register-kb-function 'pgia-after-adding-pgia)
(register-kb-function 'pgia-after-adding-isa)
(register-kb-function 'pgia-after-removing-genls)
