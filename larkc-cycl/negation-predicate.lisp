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

;; (defun local-negation-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun local-negation-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun local-max-negation-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun local-max-negation-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun local-not-negation-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun local-not-negation-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun local-min-not-negation-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun local-min-not-negation-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)

(defun all-negation-predicates (pred &optional mt tv)
  "[Cyc] all of the negation-predicates of PRED"
  (sbhl-all-implied-disjoins (get-sbhl-module #$negationPreds) pred mt tv))

;; Reconstructed macro. Evidence: $list2 = ((negation-pred pred &key mt tv done) &body body),
;; $sym8 = DO-LIST, $sym9 = ALL-NEGATION-PREDICATES.
;; Expands to do-list over all-negation-predicates results.
(defmacro do-all-negation-predicates ((negation-pred pred &key mt tv done) &body body)
  `(do-list (,negation-pred (all-negation-predicates ,pred ,mt ,tv) :done ,done)
     ,@body))

;; (defun all-negation-preds (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun all-negation-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-not-negation-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-not-negation-preds (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun all-not-negation-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)

(defun max-all-negation-predicates (pred &optional mt tv)
  "[Cyc] most-general negation predicates of <pred>"
  (sbhl-implied-max-disjoins (get-sbhl-module #$negationPreds) pred mt tv))

;; (defun negation-preds (pred &optional mt) ...) -- commented declareFunction (1 1)

(defun max-negation-preds (pred &optional mt)
  (max-all-negation-predicates pred mt))

;; (defun max-negation-predicates (pred &optional mt) ...) -- commented declareFunction (1 1)

(defun max-all-negation-inverses (pred &optional mt tv)
  "[Cyc] most-general negation inverses of <pred>"
  (sbhl-implied-max-disjoins (get-sbhl-module #$negationInverse) pred mt tv))

(defun max-negation-inverses (pred &optional mt)
  (max-all-negation-inverses pred mt))

;; (defun min-all-not-negation-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-implied-not-negation-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-all-asserted-not-negation-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun not-negation-preds (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun min-not-negation-preds (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun min-not-negation-predicates (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun min-all-not-negation-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-implied-not-negation-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-all-asserted-not-negation-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-not-negation-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun negation-predicate? (pred1 pred2 &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun negation-pred? (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun negation-inverse? (pred1 pred2 &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-negation-pred? (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun not-negation-predicate? (pred1 pred2 &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-negation-inverse? (pred1 pred2 &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun some-negation-pred-or-inverse? (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun some-negation-pred-or-inverse (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun basis-for-not-negation-pred? (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun basis-for-not-negation-inverse? (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun why-negation-pred? (pred1 pred2 &optional mt tv) ...) -- commented declareFunction (2 3)
;; (defun why-negation-inverse? (pred1 pred2 &optional mt tv) ...) -- commented declareFunction (2 3)
;; (defun max-floor-mts-of-negation-predicate-paths (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun max-floor-mts-of-negation-pred-paths (pred1 pred2) ...) -- commented declareFunction (2 0)
;; (defun min-mts-of-negation-predicate-paths (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-negation-pred-paths (pred1 pred2) ...) -- commented declareFunction (2 0)
;; (defun max-floor-mts-of-not-negation-predicate-paths (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-not-negation-predicate-paths (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun max-floor-mts-of-negation-inverse-paths (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-negation-inverse-paths (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun max-floor-mts-of-not-negation-inverse-paths (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-not-negation-inverse-paths (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun negation-predicate-mts (node) ...) -- commented declareFunction (1 0)
;; (defun asserted-negation-preds (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-not-negation-preds (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-negation-preds (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-not-negation-preds (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun negation-inverse-mts (node) ...) -- commented declareFunction (1 0)
;; (defun asserted-negation-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-not-negation-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-negation-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-not-negation-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun negation-predicate-after-adding (source assertion) ...) -- commented declareFunction (2 0)

(defun negation-inverse-after-adding (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (sbhl-after-adding source assertion (get-sbhl-module #$negationInverse))
  nil)

(defun add-negation-inverse (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see negation-inverse-after-adding."
  (negation-inverse-after-adding source assertion)
  nil)

;; (defun negation-predicate-after-removing (source assertion) ...) -- commented declareFunction (2 0)

(defun negation-inverse-after-removing (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (sbhl-after-removing source assertion (get-sbhl-module #$negationInverse))
  nil)

(defun remove-negation-inverse (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (negation-inverse-after-removing source assertion)
  nil)

;; (defun clear-negation-predicate-graph () ...) -- commented declareFunction (0 0)
;; (defun clear-negation-inverse-graph () ...) -- commented declareFunction (0 0)
;; (defun clear-node-negation-predicate-links (node) ...) -- commented declareFunction (1 0)
;; (defun clear-node-negation-inverse-links (node) ...) -- commented declareFunction (1 0)
;; (defun reset-negation-predicate-links (node) ...) -- commented declareFunction (1 0)
;; (defun reset-negation-inverse-links (node) ...) -- commented declareFunction (1 0)
;; (defun reset-negation-predicate-links-in-mt (node mt) ...) -- commented declareFunction (2 0)
;; (defun reset-negation-inverse-links-in-mt (node mt) ...) -- commented declareFunction (2 0)
;; (defun reset-negation-predicate-graph (&optional mt) ...) -- commented declareFunction (0 1)
;; (defun reset-negation-inverse-graph (&optional mt) ...) -- commented declareFunction (0 1)

;;; ======================================================================
;;; Setup
;;; ======================================================================

(register-kb-function 'negation-predicate-after-adding)
(register-kb-function 'negation-inverse-after-adding)
(register-kb-function 'add-negation-inverse)
(register-kb-function 'negation-predicate-after-removing)
(register-kb-function 'negation-inverse-after-removing)
(register-kb-function 'remove-negation-inverse)
