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

;; (defun isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-isa-in-mt (v-term mt) ...) -- commented declareFunction (2 0)
;; (defun nat-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun naut-isa (naut &optional mt) ...) -- commented declareFunction (1 1)
;; (defun not-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-not-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun nat-max-not-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun instances (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-instances (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-instances-with-max (col max) ...) -- commented declareFunction (2 0)
;; (defun not-instances (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-not-instances (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun isa-siblings (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun instance-siblings (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun map-isa (function v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-min-isa (function v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-instances (function v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun min-isas-of-type (v-term type &optional mt tv) ...) -- commented declareFunction (2 2)

(defun all-isa (v-term &optional mt tv)
  "[Cyc] Returns all collections that include TERM (inexpensive)"
  (declare (type hl-term-p v-term))
  (let ((result (sbhl-all-forward-true-nodes (get-sbhl-module #$isa) v-term mt tv)))
    ;; For non-forts, merge in additional isa types. missing-larkc 1792 likely
    ;; returns non-fort isa collections (e.g. from nat-isa or non-fort-isa),
    ;; since sbhl only covers forts and this branch handles the non-fort case.
    (when (non-fort-p v-term)
      (setf result (fast-delete-duplicates
                    (nconc (missing-larkc 1792) result))))
    result))

;; (defun all-isa-in-any-mt (v-term) ...) -- commented declareFunction (1 0)
;; (defun all-isa-in-mt (v-term &optional mt) ...) -- commented declareFunction (1 1)
;; (defun all-isa-in-mts (v-term &optional mts) ...) -- commented declareFunction (1 1)
;; (defun nat-all-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)

(defun all-instances (col &optional mt tv)
  "[Cyc] Returns all instances of COLLECTION (expensive)"
  (declare (type el-fort-p col))
  (sbhl-all-backward-true-nodes (get-sbhl-module #$isa) col mt tv))

;; (defun all-instances-in-all-mts (col) ...) -- commented declareFunction (1 0)
;; (defun all-fort-instances (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-fort-instances-in-all-mts (col) ...) -- commented declareFunction (1 0)
;; (defun all-isas-wrt (v-term isa &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun gather-isa-wrt-isa (node) ...) -- commented declareFunction (1 0)
;; (defun union-all-isa (terms &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun union-all-instances (cols &optional mt tv) ...) -- commented declareFunction (1 2)

(defun all-isa-among (v-term collections &optional mt tv)
  "[Cyc] Returns those elements of COLLECTIONS that include TERM as an all-instance"
  (declare (type hl-term-p v-term)
           (type list collections))
  (cond
    ((null collections)
     nil)
    ((singleton? collections)
     (when (isa? v-term (first collections) mt tv)
       collections))
    ;; For multiple collections, missing-larkc 1529 likely performs a bulk
    ;; sbhl search to find which of COLLECTIONS include TERM, rather than
    ;; testing each one individually.
    (t
     (missing-larkc 1529))))

;; (defun min-isa-among (v-term collections &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-instances-among (col terms &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-instances-among-fast (col terms &optional mt) ...) -- commented declareFunction (2 1)
;; (defun all-isa-if (function v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-instances-if (function col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-isa-if-with-pruning (function v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-not-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-not-instances (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun not-isa-among (v-term collections &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-instances-among () ...) -- commented declareFunction (0 0)
;; (defun map-all-isa (fn v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-all-instances (fn col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-all-isa (fn v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-wrt-all-isa (function v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-all-forward-true-nodes-isa (fn v-term collection &optional mt tv) ...) -- commented declareFunction (3 2)
;; (defun sample-leaf-instances (col &optional n mt tv) ...) -- commented declareFunction (1 3)
;; (defun sample-different-leaf-instances (col n &optional mt tv count) ...) -- commented declareFunction (2 3)
;; (defun sbhl-record-all-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun count-all-instances (collection &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun count-all-instances-if (fn collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-instances-= (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-instances-> (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-instances->= (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-instances-< (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-instances-<= (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-quoted-instances (collection &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun count-all-quoted-instances-if (fn collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-quoted-instances-= (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-quoted-instances-> (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-quoted-instances->= (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-quoted-instances-< (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-quoted-instances-<= (n collection &optional mt tv) ...) -- commented declareFunction (2 2)

(defun isa? (v-term collection &optional mt tv)
  "[Cyc] Returns whether TERM is an instance of COLLECTION via the SBHL, i.e. isa and genls assertions.
@note This function does _not_ use defns to determine membership in COLLECTION.
@see has-type?
@see quiet-has-type?"
  (declare (type el-fort-p collection))
  (when (sbhl-non-justifying-predicate-relation-p
         (get-sbhl-module #$isa) v-term collection mt tv)
    (return-from isa? t))
  ;; If v-term is a stored NAUT, check if collection is a spec of the NAUT's
  ;; result-isa type. missing-larkc 1784 was the second arg to any-spec?, so it
  ;; likely returned the isa collections of the NAUT (probably naut-isa or similar).
  (when (and (isa-stored-naut-arg2-p v-term)
             (any-spec? collection (missing-larkc 1784) mt tv))
    (return-from isa? t))
  (when (and (cycl-nat-p collection)
             (eq (formula-operator collection) #$CollectionIntersectionFn)
             (el-extensional-set-p (formula-arg1 collection)))
    ;; The collection is (#$CollectionIntersectionFn <extensional-set> ...),
    ;; and missing-larkc 30562 extracts the individual collections from that set.
    ;; Likely el-extensional-set-elements or similar, since el-extensional-set-p
    ;; was just tested on (formula-arg1 collection).
    (let ((colls (missing-larkc 30562)))
      (dolist (sub-coll colls)
        (unless (and (el-fort-p sub-coll)
                     (isa? v-term sub-coll mt tv))
          (return-from isa? nil)))
      (return-from isa? t)))
  (when (and (non-fort-p v-term)
             (non-fort-isa? v-term collection mt tv))
    (return-from isa? t))
  nil)

;; (defun isa-in-mts? (v-term collection mts) ...) -- commented declareFunction (3 0)

(defun isa-in-any-mt? (v-term collection)
  "[Cyc] is <term> an element of <collection> in any mt"
  (let ((*relevant-mt-function* #'relevant-mt-is-everything)
        (*mt* #$EverythingPSC))
    (isa? v-term collection)))

;; (defun nat-isa? (v-term collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun nat-isa-int? (v-term collection mt) ...) -- commented declareFunction (3 0)
;; (defun result-isa-col? (col isa &optional mt) ...) -- commented declareFunction (2 1)
;; (defun weak-not-result-isa-col? (col isa &optional mt) ...) -- commented declareFunction (2 1)
;; (defun result-isa-arg-col? (col isa &optional mt) ...) -- commented declareFunction (2 1)
;; (defun weak-not-result-isa-arg-col? (col isa &optional mt) ...) -- commented declareFunction (2 1)
;; (defun result-isa-inter-arg-col? (col isa &optional mt) ...) -- commented declareFunction (2 1)
;; (defun result-isa-inter-arg-reln-col? (col isa &optional mt) ...) -- commented declareFunction (2 1)
;; (defun isa?-goal (node) ...) -- commented declareFunction (1 0)
;; (defun any-isa? (v-term collections &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun isa-any? (v-term collections &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun nat-any-isa? (v-term collections &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun find-if-isa? (v-term collections) ...) -- commented declareFunction (2 0)
;; (defun all-isa? (v-term collections &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-instances? (col terms &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-isa-any? (terms collections &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-isa? (v-term collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-isa-some? (v-term collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-isa-by-sbhl? (v-term collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-isa-by-extent-known? (v-term collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun argue-not-isa? (v-term collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-isa-in-any-mt? (v-term collection) ...) -- commented declareFunction (2 0)
;; (defun nat-not-isa? (v-term collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun why-isa? (v-term collection &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun any-just-of-isa (v-term collection &optional mt) ...) -- commented declareFunction (2 1)
;; (defun any-just-of-nat-isa (v-term collection &optional mt) ...) -- commented declareFunction (2 1)
;; (defun why-not-isa? (v-term collection &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun any-just-of-not-isa (v-term collection &optional mt) ...) -- commented declareFunction (2 1)
;; (defun any-just-of-nat-not-isa (v-term collection &optional mt) ...) -- commented declareFunction (2 1)
;; (defun instances? (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun instances?-int (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun forts-of-type (col v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-isa-mts (v-term) ...) -- commented declareFunction (1 0)
;; (defun gather-genls-mts (node) ...) -- commented declareFunction (1 0)
;; (defun partial-isa-extension? (collection &optional mt) ...) -- commented declareFunction (1 1)
;; (defun random-instance-of (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun min-ceiling-isa (v-term &optional candidates mt tv) ...) -- commented declareFunction (1 3)
;; (defun nearest-common-isa (v-term &optional candidates mt tv) ...) -- commented declareFunction (1 3)
;; (defun max-floor-instances (cols &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-floor-mts-of-isa-paths-wrt (v-term collection mt) ...) -- commented declareFunction (3 0)
;; (defun max-floor-mts-of-isa-paths (v-term collection &optional tv) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-isa-paths (v-term collection &optional tv) ...) -- commented declareFunction (2 1)
;; (defun nat-min-mts-of-isa-paths (v-term collection) ...) -- commented declareFunction (2 0)
;; (defun min-mts-of-quoted-isa-paths (v-term collection &optional tv) ...) -- commented declareFunction (2 1)
;; (defun nat-min-mts-of-quoted-isa-paths (v-term collection) ...) -- commented declareFunction (2 0)
;; (defun gather-min-mts-of-paths-between (node) ...) -- commented declareFunction (1 0)
;; (defun cache-mts-of-arg (node) ...) -- commented declareFunction (1 0)
;; (defun max-floor-mts-of-not-isa-paths (v-term collection &optional tv) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-not-isa-paths (v-term collection &optional tv) ...) -- commented declareFunction (2 1)
;; (defun instantiation? (v-term collection &optional mt) ...) -- commented declareFunction (2 1)
;; (defun instantiations (collection &optional mt) ...) -- commented declareFunction (1 1)
;; (defun all-instantiations (collection &optional mt) ...) -- commented declareFunction (1 1)
;; (defun random-instantiation (collection &optional mt) ...) -- commented declareFunction (1 1)
;; (defun set-naut-p (v-term) ...) -- commented declareFunction (1 0)
;; (defun member-of-cycl-set? (v-term set-naut) ...) -- commented declareFunction (2 0)
;; (defun members-of-cycl-set (set-naut) ...) -- commented declareFunction (1 0)
;; (defun random-member-of-cycl-set (set-naut) ...) -- commented declareFunction (1 0)
;; (defun isas-mts (v-term) ...) -- commented declareFunction (1 0)
;; (defun isa-mts (v-term) ...) -- commented declareFunction (1 0)
;; (defun type-mts (v-term) ...) -- commented declareFunction (1 0)

(defun asserted-isa? (v-term &optional mt)
  "[Cyc] @return booleanp; whether there are any asserted true isa links for TERM."
  (sbhl-any-asserted-true-links (get-sbhl-module #$isa) v-term mt))

(defun asserted-isa (v-term &optional mt)
  "[Cyc] @return listp; the asserted true isa links for TERM in MT / *mt*."
  (sbhl-asserted-true-links (get-sbhl-module #$isa) v-term mt))

;; (defun asserted-not-isa (v-term &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-isa (v-term &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-not-isa (v-term &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-instance (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-not-instance (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-instance (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-not-instance (col &optional mt) ...) -- commented declareFunction (1 1)

(defun instanceof-after-adding (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (isa-after-adding source assertion))

(defun isa-after-adding (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (sbhl-after-adding source assertion (get-sbhl-module #$isa))
  (sbhl-cache-addition-maintainence assertion)
  (clear-isa-dependent-caches source assertion)
  (possibly-propagate-isa-collection-subset-fn-the-set-of assertion)
  (possibly-propagate-isa-the-collection-of assertion)
  (possibly-add-non-fort-isa assertion)
  nil)

(defun possibly-propagate-isa-collection-subset-fn-the-set-of (assertion)
  "[Cyc] If ASSERTION is of the form (#$isa <term> (#$CollectionSubsetFn <col> (#$TheSetOf ?X <prop>))),
   substitutes <term> into <prop> and creates a new deduction.
   Copied-n-edited from @xref possibly-propagate-isa-the-collection-of."
  (when (true-assertion? assertion)
    (let ((isa-formula (assertion-fi-formula assertion)))
      (destructuring-bind (v-isa v-term subset-expr) isa-formula
        (when (and (eq v-isa #$isa)
                   (el-formula-with-operator-p subset-expr #$CollectionSubsetFn))
          (destructuring-bind (csfn col colexpr) subset-expr
            (declare (ignore csfn col colexpr))
            ;; missing-larkc 3719 — the propagation logic that substitutes
            ;; v-term into the TheSetOf proposition and creates a new deduction.
            (missing-larkc 3719))))))
  nil)

(defun possibly-propagate-isa-the-collection-of (assertion)
  "[Cyc] If ASSERTION is of the form (#$isa <term> (#$TheCollectionOf ?X <prop>)),
   substitutes <term> into <prop> and creates a new deduction.
   Copied-n-edited from @xref cyc-add-element-of."
  (when (true-assertion? assertion)
    (let ((isa-formula (assertion-fi-formula assertion)))
      (destructuring-bind (v-isa v-term colexpr) isa-formula
        (declare (ignore v-term))
        (when (and (eq v-isa #$isa)
                   (el-formula-with-operator-p colexpr #$TheCollectionOf))
          ;; missing-larkc 3720 — the propagation logic that substitutes
          ;; v-term into the TheCollectionOf proposition and creates a new deduction.
          (missing-larkc 3720)))))
  nil)

;; (defun possibly-propagate-isa-the-set-of (assertion mt v-term) ...) -- commented declareFunction (3 0)

(defun instanceof-after-removing (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (isa-after-removing source assertion))

(defun isa-after-removing (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (declare (ignore source))
  (sbhl-after-removing source assertion (get-sbhl-module #$isa))
  (sbhl-cache-removal-maintainence assertion)
  (possibly-remove-non-fort-isa assertion)
  nil)

;; (defun clear-isa-graph () ...) -- commented declareFunction (0 0)
;; (defun clear-node-isa-links (node) ...) -- commented declareFunction (1 0)
;; (defun reset-isa-links (node) ...) -- commented declareFunction (1 0)
;; (defun reset-isa-links-in-mt (node mt) ...) -- commented declareFunction (2 0)
;; (defun reset-isa-graph (&optional mt) ...) -- commented declareFunction (0 1)
;; (defun quoted-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun nat-quoted-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun not-quoted-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)

(defun quoted-isa? (v-term collection &optional mt tv)
  "[Cyc] Returns whether TERM is a quoted instance of COLLECTION via the SBHL, i.e. quotedIsa and genls assertions.
@note This function does _not_ use defns to determine membership in COLLECTION.
@see has-type?
@see quiet-has-type?"
  (declare (type el-fort-p collection))
  (or (sbhl-non-justifying-predicate-relation-p
       (get-sbhl-module #$quotedIsa) v-term collection mt tv)
      ;; Parallel to isa? logic: if v-term is a stored quoted-isa NAUT,
      ;; missing-larkc 1801 likely returns the quoted-isa collections of
      ;; the NAUT (analogous to missing-larkc 1784 in isa?).
      (when (quoted-isa-stored-naut-arg2-p v-term)
        (any-spec? collection (missing-larkc 1801) mt tv))))

(defun quoted-isa-in-any-mt? (v-term collection)
  "[Cyc] is <term> an element of <collection> in any mt"
  (let ((*relevant-mt-function* #'relevant-mt-is-everything)
        (*mt* #$EverythingPSC))
    (quoted-isa? v-term collection)))

;; (defun any-quoted-isa? (v-term collections &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun quoted-isa-any? (v-term collections &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-quoted-isa? (v-term collections &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-quoted-isa? (v-term collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-quoted-isa-by-sbhl? (v-term collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-quoted-isa-by-extent-known? (v-term collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun quoted-instances (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun union-all-quoted-instances (cols &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun map-all-quoted-isa (fn v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-all-quoted-instances (fn col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-quoted-isa (function v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-min-quoted-isa (function v-term &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-quoted-isa (v-term &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-quoted-isa-in-any-mt (v-term) ...) -- commented declareFunction (1 0)
;; (defun all-quoted-isa-in-mt (v-term &optional mt) ...) -- commented declareFunction (1 1)
;; (defun all-quoted-isa-in-mts (v-term &optional mts) ...) -- commented declareFunction (1 1)
;; (defun all-quoted-isas-wrt (v-term isa &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-quoted-instances (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-quoted-instances-in-all-mts (col) ...) -- commented declareFunction (1 0)
;; (defun all-quoted-isa-among (v-term collections &optional mt tv) ...) -- commented declareFunction (2 2)

(defun asserted-quoted-isa? (v-term &optional mt)
  "[Cyc] @return booleanp; whether there are any asserted true isa links for TERM."
  (sbhl-any-asserted-true-links (get-sbhl-module #$quotedIsa) v-term mt))

;; (defun asserted-quoted-isa (v-term &optional mt) ...) -- commented declareFunction (1 1)

(defun quoted-instanceof-after-adding (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (declare (ignore source))
  (sbhl-after-adding source assertion (get-sbhl-module #$quotedIsa))
  (sbhl-cache-addition-maintainence assertion)
  (clear-quoted-isa-dependent-caches source assertion)
  nil)

;; (defun quoted-instanceof-after-removing (source assertion) ...) -- commented declareFunction (2 0)
;; (defun all-instances-via-indexing (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun instances-via-indexing (col &optional mt) ...) -- commented declareFunction (1 1)

;;; ======================================================================
;;; Variables
;;; ======================================================================

(defparameter *all-isas-wrt* nil
  "[Cyc] Result accumulator for all-isas-wrt")

(defparameter *all-isas-wrt-isa* nil
  "[Cyc] Term which other terms must be instances to be included in the all-isas-wrt.")

(deflexical *random-instance-of-sampling-ratio* 20
  "[Cyc] If COLLECTION has more than (FORT-COUNT / THIS) many instances, sample instead of
   generating all the instances.")

;;; ======================================================================
;;; Setup — API registrations
;;; ======================================================================

(toplevel
  (register-cyc-api-function 'min-isa '(term &optional mt tv)
    "Returns most-specific collections that include TERM (inexpensive)"
    '((term hl-term-p)) '((list fort-p)))
  (register-cyc-api-function 'max-not-isa '(term &optional mt tv)
    "Returns most-general collections that do not include TERM (expensive)"
    '((term hl-term-p)) '((list fort-p)))
  (register-cyc-api-function 'instances '(col &optional mt tv)
    "Returns the asserted instances of COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'max-instances '(col &optional mt tv)
    "Returns the maximal among the asserted instances of COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-external-symbol 'all-instances-with-max)
  (register-cyc-api-function 'min-not-instances '(col &optional mt tv)
    "Returns the most-specific negated instances of collection COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'isa-siblings '(term &optional mt tv)
    "Returns the direct isas of those collections of which TERM is a direct instance"
    '((term hl-term-p)) '((list fort-p)))
  (register-cyc-api-function 'instance-siblings '(term &optional mt tv)
    "Returns the direct instances of those collections having direct isa TERM"
    '((term el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'map-instances '(function term &optional mt tv)
    "apply FUNCTION to every (least general) #$isa of TERM"
    '((function function-spec-p) (term el-fort-p)) nil)
  (register-cyc-api-function 'all-isa '(term &optional mt tv)
    "Returns all collections that include TERM (inexpensive)"
    '((term hl-term-p)) '((list fort-p)))
  (register-cyc-api-function 'all-instances '(col &optional mt tv)
    "Returns all instances of COLLECTION (expensive)"
    '((col el-fort-p)) '((list hl-term-p)))
  (register-cyc-api-function 'all-instances-in-all-mts '(collection)
    "@return listp; all instances of COLLECTION in all mts."
    '((collection el-fort-p)) '((list hl-term-p)))
  (define-obsolete-register 'all-fort-instances '(all-fort-instances))
  (register-external-symbol 'all-fort-instances)
  (define-obsolete-register 'all-fort-instances-in-all-mts '(all-instances-in-all-mts))
  (register-cyc-api-function 'all-isas-wrt '(term isa &optional mt tv)
    "Returns all isa of term TERM that are also instances of collection ISA (ascending transitive closure; inexpensive)"
    '((term el-fort-p) (isa el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'union-all-isa '(terms &optional mt tv)
    "Returns all collections that include any term in TERMS (inexpensive)"
    '((terms listp)) '((list fort-p)))
  (register-cyc-api-function 'union-all-instances '(cols &optional mt tv)
    "Returns set of all instances of each collection in COLS (expensive)"
    '((cols listp)) '((list fort-p)))
  (register-cyc-api-function 'all-isa-among '(term collections &optional mt tv)
    "Returns those elements of COLLECTIONS that include TERM as an all-instance"
    '((term hl-term-p) (collections listp)) '((list fort-p)))
  (register-cyc-api-function 'all-instances-among '(col terms &optional mt tv)
    "Returns those elements of TERMS that include COL as an all-isa"
    '((col hl-term-p) (terms listp)) '((list hl-term-p)))
  (register-cyc-api-function 'all-not-isa '(term &optional mt tv)
    "Returns all collections that do not include TERM (expensive)"
    '((term hl-term-p)) '((list fort-p)))
  (register-cyc-api-function 'all-not-instances '(col &optional mt tv)
    "Returns all terms that are not members of col (by assertion)"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'not-isa-among '(term collections &optional mt tv)
    "Returns those elements of COLLECTIONS that do NOT include TERM"
    '((term hl-term-p) (collections listp)) '((list fort-p)))
  (register-cyc-api-function 'map-all-isa '(fn term &optional mt tv)
    "Apply FUNCTION to every all-isa of TERM
   (FUNCTION must not affect the current sbhl search state)"
    '((fn function-spec-p) (term hl-term-p)) nil)
  (register-cyc-api-function 'map-all-instances '(fn col &optional mt tv)
    "Apply FUNCTION to each unique instance of all specs of COLLECTION."
    '((fn function-spec-p) (col el-fort-p)) nil)
  (register-cyc-api-function 'any-wrt-all-isa '(function term &optional mt tv)
    "Return the first encountered non-nil result of applying FUNCTION to the all-isa of TERM
   (FUNCTION may not affect the current sbhl search state)"
    '((function function-spec-p) (term hl-term-p)) nil)
  (register-cyc-api-function 'count-all-instances '(collection &optional mt tv)
    "Counts the number of instances in COLLECTION and then returns the count."
    '((collection el-fort-p)) '(integerp))
  (register-cyc-api-function 'count-all-quoted-instances '(collection &optional mt tv)
    "Counts the number of quoted instances in COLLECTION and then returns the count."
    '((collection el-fort-p)) '(integerp))
  (register-cyc-api-function 'isa? '(term collection &optional mt tv)
    "Returns whether TERM is an instance of COLLECTION via the SBHL, i.e. isa and genls assertions.
@note This function does _not_ use defns to determine membership in COLLECTION.
@see has-type?
@see quiet-has-type?"
    '((collection el-fort-p)) '(booleanp))
  (register-cyc-api-function 'isa-in-mts? '(term collection mts)
    "is <term> an element of <collection> via assertions in any mt in <mts>"
    '((collection el-fort-p)) '(booleanp))
  (register-cyc-api-function 'isa-in-any-mt? '(term collection)
    "is <term> an element of <collection> in any mt"
    nil '(booleanp))
  (register-cyc-api-function 'any-isa? '(term collections &optional mt tv)
    "Returns whether TERM is an instance of any collection in COLLECTIONS"
    '((term hl-term-p) (collections listp)) '(booleanp))
  (register-cyc-api-function 'isa-any? '(term collections &optional mt tv)
    "Returns whether TERM is an instance of any collection in COLLECTIONS"
    '((term hl-term-p) (collections listp)) '(booleanp))
  (register-cyc-api-function 'any-isa-any? '(terms collections &optional mt tv)
    "@return booleanp; whether any term in TERMS is an instance of any collection in COLLECTIONS"
    '((terms listp) (collections listp)) '(booleanp))
  (register-cyc-api-function 'not-isa? '(term collection &optional mt tv)
    "@return booleanp; whether TERM is known to not be an instance of COLLECTION"
    '((term hl-term-p) (collection el-fort-p)) '(booleanp))
  (register-cyc-api-function 'why-isa? '(term collection &optional mt tv behavior)
    "Returns justification of (isa TERM COLLECTION)"
    '((term hl-term-p) (collection el-fort-p)) '(listp))
  (register-cyc-api-function 'why-not-isa? '(term collection &optional mt tv behavior)
    "Returns justification of (not (isa TERM COLLECTION))"
    '((term hl-term-p) (collection el-fort-p)) '(listp))
  (register-cyc-api-function 'instances? '(collection &optional mt tv)
    "Returns whether COLLECTION has any direct instances"
    '((collection el-fort-p)) '(booleanp))
  (register-cyc-api-function 'max-floor-mts-of-isa-paths '(term collection &optional tv)
    "Returns in what (most-genl) mts TERM is an instance of COLLECTION"
    '((term hl-term-p) (collection el-fort-p)) nil)
  (register-kb-function 'instanceof-after-adding)
  (register-kb-function 'isa-after-adding)
  (register-kb-function 'instanceof-after-removing)
  (register-kb-function 'isa-after-removing)
  (register-cyc-api-function 'quoted-isa? '(term collection &optional mt tv)
    "Returns whether TERM is a quoted instance of COLLECTION via the SBHL, i.e. quotedIsa and genls assertions.
@note This function does _not_ use defns to determine membership in COLLECTION.
@see has-type?
@see quiet-has-type?"
    '((collection el-fort-p)) '(booleanp))
  (register-cyc-api-function 'quoted-isa-in-any-mt? '(term collection)
    "is <term> an element of <collection> in any mt"
    nil '(booleanp))
  (register-cyc-api-function 'any-quoted-isa? '(term collections &optional mt tv)
    "Returns whether TERM is an instance of any collection in COLLECTIONS"
    '((term hl-term-p) (collections listp)) '(booleanp))
  (register-cyc-api-function 'quoted-isa-any? '(term collections &optional mt tv)
    "Returns whether TERM is an instance of any collection in COLLECTIONS"
    '((term hl-term-p) (collections listp)) '(booleanp))
  (register-cyc-api-function 'all-quoted-isa? '(term collections &optional mt tv)
    "Returns whether TERM is a quoted instance of all collections in COLLECTIONS"
    '((term hl-term-p) (collections listp)) '(booleanp))
  (register-cyc-api-function 'not-quoted-isa? '(term collection &optional mt tv)
    "@return booleanp; whether TERM is known to not be an instance of COLLECTION"
    '((term hl-term-p) (collection el-fort-p)) '(booleanp))
  (register-cyc-api-function 'quoted-instances '(col &optional mt tv)
    "Returns the asserted instances of COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'union-all-quoted-instances '(cols &optional mt tv)
    "Returns set of all quoted instances of each collection in COLS (expensive)"
    '((cols listp)) '((list fort-p)))
  (register-cyc-api-function 'map-all-quoted-isa '(fn term &optional mt tv)
    "Apply FUNCTION to every all-quoted-isa of TERM
   (FUNCTION must not affect the current sbhl search state)"
    '((fn function-spec-p) (term hl-term-p)) nil)
  (register-cyc-api-function 'all-quoted-isa '(term &optional mt tv)
    "Returns all collections that include TERM (inexpensive)"
    '((term hl-term-p)) '((list fort-p)))
  (register-cyc-api-function 'all-quoted-isas-wrt '(term isa &optional mt tv)
    "Returns all isa of term TERM that are also instances of collection ISA (ascending transitive closure; inexpensive)"
    '((term el-fort-p) (isa el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-quoted-instances '(col &optional mt tv)
    "Returns all instances of COLLECTION (expensive)"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-quoted-isa-among '(term collections &optional mt tv)
    "Returns those elements of COLLECTIONS that include TERM as an all-quoted-instance"
    '((term hl-term-p) (collections listp)) '((list fort-p)))
  (register-kb-function 'quoted-instanceof-after-adding)
  (register-kb-function 'quoted-instanceof-after-removing))
