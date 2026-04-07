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

;;; ======================================================================
;;; Commented-out functions — stubs (present in original Cyc, not in LarKC)
;;; ======================================================================

;; (defun genl-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-genl-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun genl-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-genl-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun not-genl-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-not-genl-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun not-genl-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-not-genl-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun spec-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-spec-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun spec-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-spec-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun not-spec-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-not-spec-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun not-spec-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-not-spec-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun genl-predicate-siblings (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun genl-inverse-siblings (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun spec-predicate-siblings (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun spec-inverse-siblings (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun genl-predicate-roots (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun genl-inverse-roots (pred &optional mt tv) ...) -- commented declareFunction (1 2)

(defun all-genl-predicates (pred &optional mt tv)
  "[Cyc] Returns all genlPreds of predicate PRED
   (ascending transitive closure; inexpensive)"
  (declare (type fort-p pred))
  (sbhl-all-forward-true-nodes (get-sbhl-module #$genlPreds) pred mt tv))

;; (defun all-genl-predicates-and-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)

(defun all-genl-preds (pred &optional mt tv)
  "[Cyc] Alias for ALL-GENL-PREDICATES."
  (all-genl-predicates pred mt tv))

(defun all-genl-inverses (pred &optional mt tv)
  "[Cyc] Returns all genlPreds of predicate PRED
   (ascending transitive closure; inexpensive)"
  (declare (type fort-p pred))
  (sbhl-all-forward-true-nodes (get-sbhl-module #$genlInverse) pred mt tv))

(defun all-spec-predicates (pred &optional mt tv)
  "[Cyc] Returns all predicates having PRED as a genlPred
   (descending transitive closure; expensive)"
  (declare (type fort-p pred))
  (sbhl-all-backward-true-nodes (get-sbhl-module #$genlPreds) pred mt tv))

(defun all-spec-preds (pred &optional mt tv)
  "[Cyc] Alias for ALL-SPEC-PREDICATES."
  (all-spec-predicates pred mt tv))

(defun all-spec-inverses (pred &optional mt tv)
  "[Cyc] Returns all predicates having PRED as a genlInverse
   (descending transitive closure; expensive)"
  (declare (type fort-p pred))
  (sbhl-all-backward-true-nodes (get-sbhl-module #$genlInverse) pred mt tv))

;; (defun all-spec-predicates-and-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)

(defun all-proper-genl-predicates (pred &optional mt tv)
  "[Cyc] Returns all genlPreds of predicate PRED, except for PRED.
   (ascending transitive closure; inexpensive)"
  (delete pred (all-genl-predicates pred mt tv)))

(defun all-proper-genl-inverses (pred &optional mt tv)
  "[Cyc] Returns all genlInverses of predicate PRED,
   but will not return PRED if it is a genlInverse of itself.
   (ascending transitive closure; inexpensive)"
  (delete pred (all-genl-inverses pred mt tv)))

;; (defun all-proper-genl-predicates-and-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-proper-spec-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-proper-spec-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-proper-spec-predicates-and-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-genl-preds-among (pred candidates &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-spec-predicates-among (pred candidates &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-genl-inverses-among (pred candidates &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-spec-inverses-among (pred candidates &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-not-genl-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-not-genl-preds (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-not-genl-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-not-spec-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-not-spec-preds (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-not-spec-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun union-all-genl-predicates (preds &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun union-all-spec-predicates (preds &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun union-all-genl-inverses (preds &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun union-all-spec-inverses (preds &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun union-all-spec-predicates-and-inverses (preds &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun map-all-genl-preds (pred fn &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun some-all-genl-preds (pred fn &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun some-all-genl-inverses (pred fn &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun some-all-genl-preds-and-inverses (pred fn &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-all-spec-preds (pred fn &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-spec-preds (pred fn &optional mt) ...) -- commented declareFunction (2 1)
;; (defun map-all-spec-preds-and-inverses (pred fn &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun some-all-spec-preds (pred fn &optional mt tv) ...) -- commented declareFunction (2 2)

(defun some-all-spec-preds-and-inverses (pred fn &optional mt tv)
  "[Cyc] No body -- active declareFunction (2 2)"
  (sbhl-simply-gather-first-among-all-backward-true-nodes
   (get-sbhl-module #$genlPreds) pred fn mt tv))

;; (defun count-all-genl-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun count-all-genl-predicates-and-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun count-all-spec-predicates (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun count-all-spec-predicates-and-inverses (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-spec-preds-wrt-type (pred col arg &optional mt tv) ...) -- commented declareFunction (3 2)
;; (defun all-spec-preds-wrt-arg (pred fort arg &optional mt tv) ...) -- commented declareFunction (3 2)
;; (defun gather-if-searched-arg-constraints (node) ...) -- commented declareFunction (1 0)
;; (defun get-sbhl-arg-type-alist () ...) -- commented declareFunction (0 0)
;; with-sbhl-arg-type-alist -- commented declareMacro
;; (defun get-sbhl-arg-type-store (key) ...) -- commented declareFunction (1 0)
;; with-new-sbhl-arg-type-genls-stores -- commented declareMacro
;; (defun sbhl-initialize-arg-type-genls-stores (alist) ...) -- commented declareFunction (1 0)
;; (defun sbhl-arg-types-alist-satisfied-p (node) ...) -- commented declareFunction (1 0)
;; (defun leaf-predicates-wrt-arg-type (pred alist) ...) -- commented declareFunction (2 0)
;; (defun sbhl-add-leaf-predicates-to-result (node) ...) -- commented declareFunction (1 0)
;; (defun pred-is-typed-spec-pred-p (node alist) ...) -- commented declareFunction (2 0)
;; (defun typed-spec-predicates-wrt-arg-type (pred alist) ...) -- commented declareFunction (2 0)
;; (defun leaf-predicates-mark-and-sweep (pred) ...) -- commented declareFunction (1 0)

(defun min-predicates (preds &optional mt tv)
  "[Cyc] Returns the most-specific predicates in PREDS"
  (declare (type listp preds))
  (sbhl-min-nodes (get-sbhl-module #$genlPreds) preds mt tv))

(defun max-predicates (preds &optional mt tv)
  "[Cyc] Returns the most-general predicates in PREDS"
  (declare (type listp preds))
  (sbhl-max-nodes (get-sbhl-module #$genlPreds) preds mt tv))

;; (defun min-ceiling-predicates (preds &optional candidates mt tv) ...) -- commented declareFunction (1 3)
;; (defun max-floor-predicates (preds &optional candidates mt tv) ...) -- commented declareFunction (1 3)

(defun some-spec-predicate-or-inverse-somewhere? (pred)
  "[Cyc] No body"
  (or (some-pred-assertion-somewhere? #$genlPreds pred 2)
      (some-pred-assertion-somewhere? #$genlInverse pred 2)))

(defun genl-predicate? (spec genl &optional mt tv)
  "[Cyc] Is GENL a genlPred of SPEC?
   (ascending transitive search; inexpensive)"
  (declare (type fort-p spec)
           (type fort-p genl))
  (when (or (eq spec genl)
            (some-spec-predicate-or-inverse-somewhere? genl))
    (sbhl-predicate-relation-p (get-sbhl-module #$genlPreds) spec genl mt tv)))

;; (defun genl-predicate-in-any-mt? (spec genl) ...) -- commented declareFunction (2 0)
;; (defun genl-pred? (spec genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun spec-pred? (spec genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun spec-predicate? (genl spec &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun genl-inverse? (spec genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun spec-inverse? (genl spec &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun genl-predicate-of? (genl spec &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun genl-inverse-of? (genl spec &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-genl-predicate? (spec genls &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-genl-pred? (spec genls &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-genl-predicate-in-any-mt? (spec genls) ...) -- commented declareFunction (2 0)
;; (defun any-genl-inverse? (spec genls &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-genl-predicate? (spec not-genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-genl-pred? (spec not-genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-spec-predicate? (genl spec &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun argue-not-genl-predicate? (spec not-genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-genl-inverse? (spec not-genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-spec-inverse? (genl spec &optional mt) ...) -- commented declareFunction (2 1)
;; (defun argue-not-genl-inverse? (spec not-genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-not-genl-predicate? (pred not-genls &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun random-genl-predicate-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-spec-predicate-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-proper-genl-predicate-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-proper-spec-predicate-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-genl-inverse-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-spec-inverse-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-proper-genl-inverse-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-proper-spec-inverse-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-genl-predicate-or-inverse-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-spec-predicate-or-inverse-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-proper-genl-predicate-or-inverse-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun random-proper-spec-predicate-or-inverse-of (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun any-spec-pred? (spec genls &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-spec-inverse? (spec genls &optional mt tv) ...) -- commented declareFunction (2 2)

(defun some-genl-pred-or-inverse? (pred &optional mt tv)
  "[Cyc] @return booleanp; whether PRED has some genlPred (other than itself) or some genlInverse?"
  (some-genl-pred-or-inverse?-int pred mt tv))

(defun some-genl-pred-or-inverse?-int (pred &optional mt tv)
  "[Cyc] @hack. does pred p have some genlPred (other than p) or some genlInverse?"
  (or (sbhl-forward-true-link-nodes (get-sbhl-module #$genlPreds) pred mt tv)
      (sbhl-forward-true-link-nodes (get-sbhl-module #$genlInverse) pred mt tv)))

(defun some-spec-pred-or-inverse? (pred &optional mt tv)
  "[Cyc] @return booleanp; whether PRED is the genlPred of some other pred or genlInverse of some other pred?"
  (some-spec-pred-or-inverse?-int pred mt tv))

(defun some-spec-pred-or-inverse?-int (pred &optional mt tv)
  "[Cyc] @hack. is pred p the genlPred of some pred other than p or genlInverse of some pred?"
  (or (sbhl-backward-true-link-nodes (get-sbhl-module #$genlPreds) pred mt tv)
      (sbhl-backward-true-link-nodes (get-sbhl-module #$genlInverse) pred mt tv)))

;; (defun intersecting-predicates? (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun predicates-intersect? (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun preds-intersect? (pred1 pred2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun why-genl-predicate? (spec genl &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun why-not-genl-predicate? (spec genl &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun why-genl-inverse? (pred genl-inverse &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun why-spec-inverse? (pred genl-inverse &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun why-not-genl-inverse? (spec genl &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun why-some-genl-predicate-among? (spec genls &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun why-some-genl-inverse-among? (spec genls &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun max-floor-mts-of-genl-predicate-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun max-floor-mts-of-genl-pred-paths (spec genl) ...) -- commented declareFunction (2 0)
;; (defun min-mts-of-genl-predicate-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-genl-pred-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun max-floor-mts-of-not-genl-predicate-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-not-genl-predicate-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun max-floor-mts-of-genl-inverse-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-genl-inverse-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun max-floor-mts-of-not-genl-inverse-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-not-genl-inverse-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun min-candidate-genl-preds (pred &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun cached-min-candidate-genl-preds (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun cached-min-candidate-genl-preds-in-mt (pred mt &optional tv) ...) -- commented declareFunction (2 1)
;; (defun clear-cached-candidate-genl-preds () ...) -- commented declareFunction (0 0)
;; (defun remove-cached-candidate-genl-preds (pred) ...) -- commented declareFunction (1 0)
;; (defun cached-candidate-genl-preds-internal (pred) ...) -- commented declareFunction (1 0)
;; (defun cached-candidate-genl-preds (pred) ...) -- commented declareFunction (1 0)
;; (defun clear-cached-candidate-genl-preds-in-mt () ...) -- commented declareFunction (0 0)
;; (defun remove-cached-candidate-genl-preds-in-mt (pred mt) ...) -- commented declareFunction (2 0)
;; (defun cached-candidate-genl-preds-in-mt-internal (pred mt) ...) -- commented declareFunction (2 0)
;; (defun cached-candidate-genl-preds-in-mt (pred mt) ...) -- commented declareFunction (2 0)
;; (defun candidate-genl-preds (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun candidate-preds-for-arg-type (pred type &optional arg-isa-preds arg-genl-preds) ...) -- commented declareFunction (2 2)
;; (defun candidate-preds-for-arg-isa (pred) ...) -- commented declareFunction (1 0)
;; (defun candidate-preds-for-arg-genl (pred) ...) -- commented declareFunction (1 0)
;; (defun min-preds-wrt-arg-types (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun min-preds-wrt-arg-isa (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun min-preds-wrt-arg-genl (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun genl-predicate-mts (pred) ...) -- commented declareFunction (1 0)
;; (defun genl-predicate-forward-mts (pred) ...) -- commented declareFunction (1 0)
;; (defun genl-predicate-backward-mts (pred) ...) -- commented declareFunction (1 0)

(defun asserted-genl-predicates? (pred &optional mt)
  "[Cyc] @return booleanp; whether there are any asserted true genl-predicate links for PRED."
  (sbhl-any-asserted-true-links (get-sbhl-module #$genlPreds) pred mt))

;; (defun asserted-genl-predicates (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-not-genl-predicates (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-genl-predicates (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-not-genl-predicates (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-spec-predicates (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-not-spec-predicates (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-spec-predicates (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-not-spec-predicates (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun genl-inverse-mts (pred) ...) -- commented declareFunction (1 0)
;; (defun genl-inverse-forward-mts (pred) ...) -- commented declareFunction (1 0)
;; (defun genl-inverse-backward-mts (pred) ...) -- commented declareFunction (1 0)

(defun asserted-genl-inverses? (pred &optional mt)
  "[Cyc] @return booleanp; whether there are any asserted true genl-inverse links for PRED."
  (sbhl-any-asserted-true-links (get-sbhl-module #$genlInverse) pred mt))

;; (defun asserted-genl-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-not-genl-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-genl-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-not-genl-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-spec-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-not-spec-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-spec-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-not-spec-inverses (pred &optional mt) ...) -- commented declareFunction (1 1)

(defun genl-predicate-after-adding (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (sbhl-after-adding source assertion (get-sbhl-module #$genlPreds))
  (sbhl-cache-addition-maintainence assertion)
  (clear-genl-pred-dependent-caches source assertion)
  nil)

(defun add-genl-predicate (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (genl-predicate-after-adding source assertion)
  nil)

(defun genl-inverse-after-adding (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (sbhl-after-adding source assertion (get-sbhl-module #$genlInverse))
  (sbhl-cache-addition-maintainence assertion)
  (clear-genl-pred-dependent-caches source assertion)
  nil)

(defun add-genl-inverse (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (genl-inverse-after-adding source assertion)
  nil)

(defun remove-genl-predicate (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (genl-predicate-after-removing source assertion)
  nil)

(defun remove-genl-inverse (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (genl-inverse-after-removing source assertion)
  nil)

(defun genl-predicate-after-removing (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (sbhl-after-removing source assertion (get-sbhl-module #$genlPreds))
  (sbhl-cache-removal-maintainence assertion)
  (clear-genl-pred-dependent-caches source assertion)
  nil)

(defun genl-inverse-after-removing (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (sbhl-after-removing source assertion (get-sbhl-module #$genlInverse))
  (sbhl-cache-removal-maintainence assertion)
  (clear-genl-pred-dependent-caches source assertion)
  nil)

;; (defun clear-predicate-graph () ...) -- commented declareFunction (0 0)
;; (defun clear-genl-predicate-graph () ...) -- commented declareFunction (0 0)
;; (defun clear-genl-inverse-graph () ...) -- commented declareFunction (0 0)
;; (defun clear-node-genl-predicate-links (node) ...) -- commented declareFunction (1 0)
;; (defun clear-node-genl-inverse-links (node) ...) -- commented declareFunction (1 0)
;; (defun reset-genl-predicate-links (node) ...) -- commented declareFunction (1 0)
;; (defun reset-genl-inverse-links (node) ...) -- commented declareFunction (1 0)
;; (defun reset-predicate-genls-links-in-mt (node mt) ...) -- commented declareFunction (2 0)
;; (defun reset-genl-predicate-links-in-mt (node mt) ...) -- commented declareFunction (2 0)
;; (defun reset-genl-inverse-links-in-mt (node mt) ...) -- commented declareFunction (2 0)
;; (defun reset-predicate-graph (&optional mt) ...) -- commented declareFunction (0 1)
;; (defun reset-genl-predicate-graph (&optional mt) ...) -- commented declareFunction (0 1)
;; (defun reset-genl-inverse-graph (&optional mt) ...) -- commented declareFunction (0 1)

;;; ======================================================================
;;; Variables
;;; ======================================================================

(defparameter *sbhl-arg-type-alist* nil
  "[Cyc] Parameter used for arg type constraints in leaf predicate wrt arg-type searches")

(defparameter *sbhl-arg-type-genls-stores* nil
  "[Cyc] Precomputed all-genls of each of the constraint collections for leaf predicate wrt arg-type searches.")

(deflexical *cached-candidate-genl-preds-caching-state* nil)
(deflexical *cached-candidate-genl-preds-in-mt-caching-state* nil)

;;; ======================================================================
;;; Setup — API and KB function registrations
;;; ======================================================================

(toplevel
  (register-cyc-api-function 'genl-predicates '(pred &optional mt tv)
    "Returns the local genlPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'min-genl-predicates '(pred &optional mt tv)
    "Returns the most-specific local genlPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'genl-inverses '(pred &optional mt tv)
    "Returns the local genlInverses of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'min-genl-inverses '(pred &optional mt tv)
    "Returns the most-specific local genlInverses of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'not-genl-predicates '(pred &optional mt tv)
    "Returns the local negated genlPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'max-not-genl-predicates '(pred &optional mt tv)
    "Returns the most-general local negated genlPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'not-genl-inverses '(pred &optional mt tv)
    "Returns the local negated genlPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'max-not-genl-inverses '(pred &optional mt tv)
    "Returns the most-general local negated genlPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'spec-predicates '(pred &optional mt tv)
    "Returns the specPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'max-spec-predicates '(pred &optional mt tv)
    "Returns the most-general specPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'spec-inverses '(pred &optional mt tv)
    "Returns the specInverses of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'max-spec-inverses '(pred &optional mt tv)
    "Returns the most-general specInverses of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'not-spec-predicates '(pred &optional mt tv)
    "Returns the negated specPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'min-not-spec-predicates '(pred &optional mt tv)
    "Returns the most-specific negated specPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'not-spec-inverses '(pred &optional mt tv)
    "Returns the most-specific negated specPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'min-not-spec-inverses '(pred &optional mt tv)
    "Returns the most-specific negated specPreds of PRED" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'genl-predicate-siblings '(pred &optional mt tv)
    "Returns the direct #$genlPreds of those predicates having direct spec-preds PRED"
    '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'genl-inverse-siblings '(pred &optional mt tv)
    "Returns the direct #$genlInverse of those predicates having direct spec-inverses PRED"
    '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'spec-predicate-siblings '(pred &optional mt tv)
    "Returns the direct spec-preds of those collections having direct #$genlPreds PRED"
    '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'spec-inverse-siblings '(pred &optional mt tv)
    "Returns the direct spec-inverses of those collections having direct #$genlInverse PRED"
    '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'genl-predicate-roots '(pred &optional mt tv)
    "Returns the most general genlPreds of PRED." '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'genl-inverse-roots '(pred &optional mt tv)
    "Returns the most general genlInverses of PRED." '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-genl-predicates '(pred &optional mt tv)
    "Returns all genlPreds of predicate PRED
   (ascending transitive closure; inexpensive)" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-genl-inverses '(pred &optional mt tv)
    "Returns all genlPreds of predicate PRED
   (ascending transitive closure; inexpensive)" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-spec-predicates '(pred &optional mt tv)
    "Returns all predicates having PRED as a genlPred
   (descending transitive closure; expensive)" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-spec-inverses '(pred &optional mt tv)
    "Returns all predicates having PRED as a genlInverse
   (descending transitive closure; expensive)" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-genl-preds-among '(pred candidates &optional mt tv)
    "Returns those genlPreds of PRED that are included among CANDIDATEs"
    '((pred el-fort-p) (candidates listp)) '((list fort-p)))
  (register-cyc-api-function 'all-not-genl-predicates '(pred &optional mt tv)
    "Returns all negated genlPreds of predicate PRED
   (descending transitive closure; expensive)" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-not-genl-inverses '(pred &optional mt tv)
    "Returns all negated genlPreds of predicate PRED
   (descending transitive closure; expensive)" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-not-spec-predicates '(pred &optional mt tv)
    "Returns all negated specPreds of predicate PRED
   (ascending transitive closure; inexpensive)" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-not-spec-inverses '(pred &optional mt tv)
    "Returns all predicates having PRED as a negated genlInverse
   (ascending transitive closure; inexpensive)" '((pred fort-p)) '((list fort-p)))
  (register-cyc-api-function 'union-all-genl-predicates '(preds &optional mt tv)
    "Returns all genl-predicates of each predicate in PREDS" '((preds listp)) '((list fort-p)))
  (register-cyc-api-function 'union-all-spec-predicates '(preds &optional mt tv)
    "Returns all spec-predicates of each predicate in PREDS" '((preds listp)) '((list fort-p)))
  (register-cyc-api-function 'union-all-genl-inverses '(preds &optional mt tv)
    "Returns all genl-inverses of each predicate in PREDS" '((preds listp)) '((list fort-p)))
  (register-cyc-api-function 'union-all-spec-inverses '(preds &optional mt tv)
    "Returns all specs of each predicate in PREDS" '((preds listp)) '((list fort-p)))
  (register-cyc-api-function 'map-all-genl-preds '(pred fn &optional mt tv)
    "Apply FN to each genlPred of PRED" '((pred fort-p) (fn function-spec-p)) nil)
  (register-cyc-api-function 'some-all-genl-preds '(pred fn &optional mt tv)
    "Apply FN to each genlPred of PRED until FN returns a non-nil result"
    '((pred fort-p) (fn function-spec-p)) nil)
  (register-cyc-api-function 'some-all-genl-inverses '(pred fn &optional mt tv)
    "Apply FN to each genlPred of PRED until FN returns a non-nil result"
    '((pred fort-p) (fn function-spec-p)) nil)
  (register-cyc-api-function 'map-all-spec-preds '(pred fn &optional mt tv)
    "Apply FN to each genlPred of PRED" '((pred fort-p) (fn function-spec-p)) nil)
  (register-cyc-api-function 'some-all-spec-preds '(pred fn &optional mt tv)
    "Apply FN to each genlPred of PRED until FN returns a non-nil result"
    '((pred fort-p) (fn function-spec-p)) nil)
  (register-cyc-api-function 'all-spec-preds-wrt-type '(pred col arg &optional mt tv)
    "Returns those all-spec-preds of PRED for which instances
of COL are legal in arguments in position ARG"
    '((pred fort-p) (col fort-p) (arg integerp)) '((list fort-p)))
  (register-cyc-api-function 'all-spec-preds-wrt-arg '(pred fort arg &optional mt tv)
    "Returns those all-spec-preds of PRED for which FORT
is legal as arguments in position ARG"
    '((pred fort-p) (fort fort-p) (arg integerp)) '((list fort-p)))
  (register-cyc-api-function 'min-predicates '(preds &optional mt tv)
    "Returns the most-specific predicates in PREDS" '((preds listp)) '((list fort-p)))
  (register-cyc-api-function 'max-predicates '(preds &optional mt tv)
    "Returns the most-general predicates in PREDS" '((preds listp)) '((list fort-p)))
  (register-cyc-api-function 'min-ceiling-predicates '(preds &optional candidates mt tv)
    "Returns the most-specific common generalizations (ceilings) of PREDS"
    '((preds listp)) '((list fort-p)))
  (register-cyc-api-function 'max-floor-predicates '(preds &optional candidates mt tv)
    "Returns the most-general common specializations (floors) of PREDS"
    '((preds listp)) '((list fort-p)))
  (register-cyc-api-function 'genl-predicate? '(spec genl &optional mt tv)
    "Is GENL a genlPred of SPEC?
   (ascending transitive search; inexpensive)"
    '((spec fort-p) (genl fort-p)) '(booleanp))
  (register-cyc-api-function 'spec-predicate? '(genl spec &optional mt tv)
    "Is GENL a genlPred of SPEC?
   (ascending transitive search; inexpensive)"
    '((genl fort-p) (spec fort-p)) '(booleanp))
  (register-cyc-api-function 'genl-inverse? '(spec genl &optional mt tv)
    "Is GENL a genlInverse of SPEC?
   (ascending transitive search; inexpensive)"
    '((spec fort-p) (genl fort-p)) '(booleanp))
  (register-cyc-api-function 'spec-inverse? '(genl spec &optional mt tv)
    "Is GENL a genlInverse of SPEC?
   (ascending transitive search; inexpensive)"
    '((spec fort-p) (genl fort-p)) '(booleanp))
  (register-cyc-api-function 'any-genl-predicate? '(spec genls &optional mt tv)
    "Returns T iff (genl-predicate? SPEC GENL) for some genl in GENLS
   (ascending transitive search; inexpensive)"
    '((spec fort-p) (genls listp)) '(booleanp))
  (register-cyc-api-function 'not-genl-predicate? '(spec not-genl &optional mt tv)
    "Is NOT-GENL known to be not a genlPred of SPEC?
   (descending transitive search; expensive)"
    '((spec fort-p) (not-genl fort-p)) '(booleanp))
  (register-cyc-api-function 'not-genl-inverse? '(spec not-genl &optional mt tv)
    "Is NOT-GENL a negated genlInverse of SPEC?
   (descending transitive search; expensive)"
    '((spec fort-p) (not-genl fort-p)) '(booleanp))
  (register-cyc-api-function 'any-not-genl-predicate? '(pred not-genls &optional mt tv)
    "Is any predicate in NOT-GENLS not a genlPred of PRED?
   (descending transitive search; expensive)"
    '((pred fort-p) (not-genls listp)) '(booleanp))
  (register-cyc-api-function 'intersecting-predicates? '(pred1 pred2 &optional mt)
    "Does the extension of PRED1 include some tuple in the extension of PRED2?"
    '((pred1 fort-p) (pred2 fort-p)) '(booleanp))
  (register-cyc-api-function 'why-genl-predicate? '(spec genl &optional mt tv behavior)
    "A justification of (genlPreds SPEC GENL)"
    '((spec fort-p) (genl fort-p)) '(listp))
  (register-cyc-api-function 'why-not-genl-predicate? '(spec genl &optional mt tv behavior)
    "A justification of (not (genlPreds SPEC GENL))"
    '((spec fort-p) (genl fort-p)) '(listp))
  (register-cyc-api-function 'why-genl-inverse? '(pred genl-inverse &optional mt tv behavior)
    "A justification of (genlInverse PRED GENL-INVERSE)"
    '((pred fort-p) (genl-inverse fort-p)) '(listp))
  (register-cyc-api-function 'why-not-genl-inverse? '(spec genl &optional mt tv behavior)
    "A justification of (not (genlInverse SPEC GENL)"
    '((spec fort-p) (genl fort-p)) '(listp))
  (register-cyc-api-function 'max-floor-mts-of-genl-predicate-paths '(spec genl &optional tv)
    "@return listp; In what (most-genl) mts is GENL a genlPred of SPEC?"
    '((spec fort-p) (genl fort-p)) nil)
  (register-cyc-api-function 'max-floor-mts-of-genl-inverse-paths '(spec genl-inverse &optional tv)
    "In what (most-genl) mts is GENL-INVERSE a genlInverse of SPEC?"
    '((spec fort-p) (genl-inverse fort-p)) nil)

  (note-globally-cached-function 'cached-candidate-genl-preds)
  (note-globally-cached-function 'cached-candidate-genl-preds-in-mt)

  (register-kb-function 'genl-predicate-after-adding)
  (register-kb-function 'add-genl-predicate)
  (register-kb-function 'genl-inverse-after-adding)
  (register-kb-function 'add-genl-inverse)
  (register-kb-function 'remove-genl-predicate)
  (register-kb-function 'remove-genl-inverse)
  (register-kb-function 'genl-predicate-after-removing)
  (register-kb-function 'genl-inverse-after-removing))
