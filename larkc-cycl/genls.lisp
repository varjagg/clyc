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

;; (defun genls (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-genls (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun nat-genls (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun nat-min-genls (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-genls-of-type (col type &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun min-proper-genls-of-type (col type &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun naut-genls (naut &optional mt) ...) -- commented declareFunction (1 1)
;; (defun not-genls (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-not-genls (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun nat-not-genls (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun nat-max-not-genls (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun naut-not-genls (naut &optional mt) ...) -- commented declareFunction (1 1)
;; (defun specs (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun leaf-col? (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-specs (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun not-specs (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-not-specs (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun genl-siblings (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun spec-siblings (col &optional mt tv) ...) -- commented declareFunction (1 2)

(defun all-genls (col &optional mt tv)
  "[Cyc] Returns all genls of collection COL
   (ascending transitive closure; inexpensive)"
  (declare (type el-fort-p col))
  (when (or (not (fort-p col))
            (collection? col))
    (sbhl-all-forward-true-nodes (get-sbhl-module #$genls) col mt tv)))

;; (defun all-genls-in-any-mt (col) ...) -- commented declareFunction (1 0)
;; (defun all-genls-in-mt (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun all-genls-in-mts (col &optional mts) ...) -- commented declareFunction (1 1)
;; (defun nat-all-genls (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-proper-genls (col &optional mt tv) ...) -- commented declareFunction (1 2)

(defun all-specs (col &optional mt tv)
  "[Cyc] Returns all specs of collection COL
   (descending transitive closure; expensive)"
  (declare (type el-fort-p col))
  (when (or (not (fort-p col))
            (collection? col))
    (sbhl-all-backward-true-nodes (get-sbhl-module #$genls) col mt tv)))

;; (defun all-proper-specs (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-proper-specs-in-any-mt (col) ...) -- commented declareFunction (1 0)
;; (defun all-leaf-specs-in-all-mts (col) ...) -- commented declareFunction (1 0)
;; (defun all-specs-with-max (col max) ...) -- commented declareFunction (2 0)
;; (defun count-all-specs (collection &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun count-all-specs-if (fn collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-specs-= (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-specs-> (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-specs->= (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-specs-< (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun count-all-specs-<= (n collection &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-genls-wrt (spec genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun union-all-genls (cols &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun union-min-genls-of-type (type cols &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun union-all-genls-among (cols candidates &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-genl-of-some? (col cols &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun union-all-specs (cols &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun union-all-specs-count (cols &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-cols-beneath (cols col &optional mt) ...) -- commented declareFunction (2 1)
;; (defun all-dependent-specs (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun min-genls-among (col candidates &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-genls-among (col candidates &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-specs-among (col candidates &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-genls-if (function col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-specs-if (function col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-genls-if-with-pruning (function col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-not-genls (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun all-not-specs (col &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun cols-awning (col-1 col-2 &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-all-genls (fn col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-all-specs (fn col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-union-all-genls (fn col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun map-all-genls-if (test fn col &optional mt tv) ...) -- commented declareFunction (3 2)

;; commented declareFunction, but body present in Java — ported for reference
(defun gather-all-genls (fn col &optional mt tv combine-fn)
  "[Cyc] Gather results of applying FN to every (all) genls of COL
   (FN must not effect the current sbhl space)"
  (sbhl-gather-all-forward-true-nodes (get-sbhl-module #$genls) col fn mt tv combine-fn))

;; (defun gather-all-specs (fn col &optional mt tv combine-fn) ...) -- commented declareFunction (2 3)
;; (defun any-all-genls (fn col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-all-specs (fn col &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun sample-leaf-specs (col &optional n mt) ...) -- commented declareFunction (1 3)
;; (defun sample-different-leaf-specs (col n &optional mt tv) ...) -- commented declareFunction (2 3)

(defun genl? (spec genl &optional mt tv)
  "[Cyc] Returns whether (#$genls SPEC GENL) can be inferred.
   (ascending transitive search; inexpensive)"
  (declare (type el-fort-p spec)
           (type el-fort-p genl))
  (when (or (not (fort-p spec))
            (collection? spec))
    (or (sbhl-non-justifying-predicate-relation-p
         (get-sbhl-module #$genls) spec genl mt tv)
        (when (cycl-nat-p spec)
          (missing-larkc 5056)))))

(defun genls? (spec genl &optional mt tv)
  "[Cyc] Is collection GENL a genl of SPEC?
   (ascending transitive search; inexpensive)"
  (genl? spec genl mt tv))

;; (defun genl-in-mts? (spec genl &optional mts) ...) -- commented declareFunction (2 1)
;; (defun genl-in-any-mt? (spec genl) ...) -- commented declareFunction (2 0)

(defun spec? (genl spec &optional mt tv)
  "[Cyc] Returns whether (#$genls SPEC GENL) can be inferred.
   (ascending transitive search; inexpensive)"
  (declare (type el-fort-p genl)
           (type el-fort-p spec))
  (genl? spec genl mt tv))

;; (defun nat-genl? (spec genl &optional mt) ...) -- commented declareFunction (2 1)
;; (defun naut-genl? (spec genl &optional mt) ...) -- commented declareFunction (2 1)
;; (defun result-genl-col? (col genl &optional mt) ...) -- commented declareFunction (2 1)
;; (defun result-genl-arg-col? (col genl &optional mt) ...) -- commented declareFunction (2 1)
;; (defun result-genl-inter-arg-col? (col genl &optional mt) ...) -- commented declareFunction (2 1)
;; (defun result-genl-via-pgia? (col genl &optional mt) ...) -- commented declareFunction (2 1)
;; (defun genl-of? (spec genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-genl? (spec genls &optional mt tv) ...) -- commented declareFunction (2 2)

(defun any-spec? (genl specs &optional mt tv)
  "[Cyc] Returns T iff (spec? genl spec) for some spec in SPECS"
  (declare (type el-fort-p genl)
           (type list specs))
  (let ((result nil))
    (let ((*sbhl-justification-search-p* nil)
          (*sbhl-apply-unwind-function-p* nil)
          (*suspend-sbhl-cache-use?* nil))
      (cond
        ((null specs)
         (setf result nil))
        ((singleton? specs)
         (setf result (spec? genl (first specs) mt tv)))
        (t
         (setf result (sbhl-any-with-predicate-relation-p
                        (get-sbhl-module #$genls) specs genl mt tv)))))
    result))

;; (defun all-genl? (spec genls &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-spec? (genl specs &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-genl-any? (specs genls &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-genl-all? (specs genls &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-spec-any? (specs genls &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-genls? (col not-genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun not-genl? (col not-genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun argue-not-genl? (col not-genl &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-not-spec? (col not-specs &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun any-not-genl? (col not-genls &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun random-genl-of (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun random-spec-of (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun collections-coextensional? (col-1 col-2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun tacit-coextensional? (col-1 col-2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun common-instance? (col-1 col-2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun why-common-instance? (col-1 col-2 &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun collections-intersect? (col-1 col-2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun hierarchical-collections? (col-1 col-2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun genl-of-any-arg? (col pred argnum &optional mt tv fn arg) ...) -- commented declareFunction (3 4)
;; (defun genl-of-any-arg?-int (col pred argnum mt tv fn arg) ...) -- commented declareFunction (7 0)
;; (defun why-genl? (spec genl &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun any-just-of-nat-genl (spec genl &optional mt) ...) -- commented declareFunction (2 1)
;; (defun why-not-genl? (spec genl &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun why-not-assert-genls? (spec genl &optional mt) ...) -- commented declareFunction (2 1)
;; (defun why-collections-intersect? (col-1 col-2 &optional mt tv behavior) ...) -- commented declareFunction (2 3)
;; (defun why-not-assert-mdw? (col-1 col-2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun collection-leaves (col &optional mt tv) ...) -- commented declareFunction (1 2)

(defun min-cols (cols &optional mt tv)
  "[Cyc] Returns the minimally-general (the most specific) among reified collections COLS,
   collections that have no proper specs among COLS"
  (declare (type list-of-collections-p cols))
  (sbhl-min-nodes (get-sbhl-module #$genls) cols mt tv))

;; (defun min-col (cols &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun max-cols (cols &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun nearest-common-genls (cols &optional candidates mt tv) ...) -- commented declareFunction (1 3)
;; (defun min-ceiling-cols (cols &optional candidates mt tv) ...) -- commented declareFunction (1 3)
;; (defun nearest-common-specs (cols &optional candidates mt tv) ...) -- commented declareFunction (1 3)
;; (defun max-floor-cols (cols &optional candidates mt tv) ...) -- commented declareFunction (1 3)
;; (defun floor-of-col-pair? (col-1 col-2 &optional mt) ...) -- commented declareFunction (2 1)
;; (defun any-floor-of-col-pair (col-1 col-2 &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun all-common-specs (cols &optional mt tv) ...) -- commented declareFunction (1 2)
;; (defun any-genl-isa (col isa &optional mt tv) ...) -- commented declareFunction (2 2)
;; (defun lighter-col (col-a col-b) ...) -- commented declareFunction (2 0)
;; (defun lightest-col (col-a col-b) ...) -- commented declareFunction (2 0)
;; (defun lightest-of-cols (cols) ...) -- commented declareFunction (1 0)
;; (defun shallower-col (col-a col-b) ...) -- commented declareFunction (2 0)
;; (defun shallowest-col (col-a col-b) ...) -- commented declareFunction (2 0)
;; (defun max-floor-mts-of-genls-paths-wrt (spec genl mt) ...) -- commented declareFunction (3 0)
;; (defun max-floor-mts-of-genls-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun max-floor-mts-of-nat-genls-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-genls-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun max-floor-mts-of-not-genls-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun min-mts-of-not-genls-paths (spec genl &optional tv) ...) -- commented declareFunction (2 1)
;; (defun genls-mts (col) ...) -- commented declareFunction (1 0)

(defun asserted-genls? (col &optional mt)
  "[Cyc] @return booleanp; whether there are any asserted true genls links for COL."
  (sbhl-any-asserted-true-links (get-sbhl-module #$genls) col mt))

(defun asserted-genls (col &optional mt)
  "[Cyc] @return listp; the asserted true genls links for COL in MT / *mt*."
  (sbhl-asserted-true-links (get-sbhl-module #$genls) col mt))

;; (defun asserted-not-genls (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-genls (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-not-genls (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-specs (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-not-specs (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-specs (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun supported-not-specs (col &optional mt) ...) -- commented declareFunction (1 1)
;; (defun asserted-coextensional? (col-1 col-2 &optional mt) ...) -- commented declareFunction (2 1)

(defun genls-after-adding (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (sbhl-after-adding source assertion (get-sbhl-module #$genls))
  (sbhl-cache-addition-maintainence assertion)
  (possibly-clear-genl-pos assertion)
  (let ((spec (gaf-arg1 assertion))
        (genl (gaf-arg2 assertion)))
    (when (assertion-has-truth assertion :true)
      (handle-added-genl-for-suf-defns spec genl)
      (handle-added-genl-for-suf-quoted-defns spec genl)
      (handle-added-genl-for-suf-functions spec genl)
      (update-cardinality-estimates-wrt-genls spec genl))
    (handle-more-specific-genl spec genl))
  (genls-collection-intersection-after-adding-int assertion)
  (clear-genls-dependent-caches source assertion)
  nil)

(defun handle-more-specific-genl (spec genl)
  "[Cyc] Modifier.  Possibly does TMS when (#$genls SPEC GENL) invalidates some other genls assertion that was deduced from an assertedMoreSpecifically rule."
  (declare (ignore spec genl))
  nil)

;; (defun more-general-genls-assertions (spec genl) ...) -- commented declareFunction (2 0)

(defun genls-after-removing (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (possibly-clear-genl-pos assertion)
  (sbhl-after-removing source assertion (get-sbhl-module #$genls))
  (sbhl-cache-removal-maintainence assertion)
  (let ((spec (gaf-arg1 assertion))
        (genl (gaf-arg2 assertion)))
    (when (assertion-has-truth assertion :true)
      (handle-removed-genl-for-suf-defns spec genl)
      (handle-removed-genl-for-suf-quoted-defns spec genl)
      (handle-removed-genl-for-suf-functions spec genl)))
  nil)

;; (defun clear-genls-graph () ...) -- commented declareFunction (0 0)
;; (defun clear-node-genls-links (node) ...) -- commented declareFunction (1 0)
;; (defun reset-genls-links (node) ...) -- commented declareFunction (1 0)
;; (defun reset-genls-links-in-mt (node mt) ...) -- commented declareFunction (2 0)
;; (defun reset-genls-graph (&optional mt) ...) -- commented declareFunction (0 1)

;;; ======================================================================
;;; Variables
;;; ======================================================================

(defvar *sbhl-infer-intersection-from-instances?* nil
  "[Cyc] Consider #$isa gafs when determining if two collections intersect?")

;;; ======================================================================
;;; Setup — API registrations
;;; ======================================================================

(toplevel
  (register-cyc-api-function 'min-genls '(col &optional mt tv)
    "Returns the most-specific genls of collection COL" nil '((list fort-p)))
  (register-cyc-api-function 'max-not-genls '(col &optional mt tv)
    "Returns the least-specific negated genls of collection COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'max-specs '(col &optional mt tv)
    "Returns the least-specific specs of collection COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'min-not-specs '(col &optional mt tv)
    "Returns the most-specific negated specs of collection COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'genl-siblings '(col &optional mt tv)
    "Returns the direct genls of those direct spec collections of COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'spec-siblings '(col &optional mt tv)
    "Returns the direct specs of those direct genls collections of COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-genls '(col &optional mt tv)
    "Returns all genls of collection COL
   (ascending transitive closure; inexpensive)"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-specs '(col &optional mt tv)
    "Returns all specs of collection COL
   (descending transitive closure; expensive)"
    '((col el-fort-p)) '((list fort-p)))
  (register-external-symbol 'all-specs-with-max)
  (register-cyc-api-function 'count-all-specs '(collection &optional mt tv)
    "Counts the number of specs in COLLECTION and then returns the count."
    '((collection el-fort-p)) '(integerp))
  (register-cyc-api-function 'all-genls-wrt '(spec genl &optional mt tv)
    "Returns all genls of collection SPEC that are also specs of collection GENL (ascending transitive closure; inexpensive)"
    '((spec el-fort-p) (genl el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'union-all-genls '(cols &optional mt tv)
    "Returns all genls of each collection in COLs"
    '((cols listp)) '((list fort-p)))
  (register-cyc-api-function 'union-all-specs '(cols &optional mt tv)
    "Returns all specs of each collection in COLs"
    '((cols listp)) '((list fort-p)))
  (register-cyc-api-function 'all-dependent-specs '(col &optional mt tv)
    "Returns all specs s of COL s.t. every path connecting
   s to any genl of COL must pass through COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-genls-among '(col candidates &optional mt tv)
    "Returns those genls of COL that are included among CANDIDATES"
    '((col el-fort-p) (candidates listp)) '((list fort-p)))
  (register-cyc-api-function 'all-specs-among '(col candidates &optional mt tv)
    "Returns those specs of COL that are included among CANDIDATEs"
    '((col el-fort-p) (candidates listp)) '((list fort-p)))
  (register-cyc-api-function 'all-genls-if '(function col &optional mt tv)
    "Returns all genls of collection COL that satisfy FUNCTION
   (FUNCTION must not effect sbhl search state)"
    '((function function-spec-p) (col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-specs-if '(function col &optional mt tv)
    "Returns all genls of collection COL that satisfy FUNCTION
   (FUNCTION must not effect sbhl search state)"
    '((function function-spec-p) (col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-not-genls '(col &optional mt tv)
    "Returns all negated genls of collection COL
   (descending transitive closure; expensive)"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'all-not-specs '(col &optional mt tv)
    "Returns all negated specs of collection COL
   (ascending transitive closure; inexpensive)"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'map-all-genls '(fn col &optional mt tv)
    "Applies FN to every (all) genls of COL
   (FN must not effect the current sbhl space)"
    '((fn function-spec-p) (col el-fort-p)) nil)
  (register-cyc-api-function 'map-all-specs '(fn col &optional mt tv)
    "Applies FN to every (all) specs of COL
   (FN must not effect the current sbhl space)"
    '((fn function-spec-p) (col el-fort-p)) nil)
  (register-cyc-api-function 'any-all-genls '(fn col &optional mt tv)
    "Return a non-nil result of applying FN to some all-genl of COL
   (FN must not effect the current sbhl space)"
    '((fn function-spec-p) (col el-fort-p)) nil)
  (register-cyc-api-function 'any-all-specs '(fn col &optional mt tv)
    "Return a non-nil result of applying FN to some all-spec of COL
   (FN must not effect the current sbhl space)"
    '((fn function-spec-p) (col el-fort-p)) nil)
  (register-cyc-api-function 'genl? '(spec genl &optional mt tv)
    "Returns whether (#$genls SPEC GENL) can be inferred.
   (ascending transitive search; inexpensive)"
    '((spec el-fort-p) (genl el-fort-p)) '(booleanp))
  (register-cyc-api-function 'spec? '(genl spec &optional mt tv)
    "Returns whether (#$genls SPEC GENL) can be inferred.
   (ascending transitive search; inexpensive)"
    '((genl el-fort-p) (spec el-fort-p)) '(booleanp))
  (register-cyc-api-function 'any-genl? '(spec genls &optional mt tv)
    "(any-genl? spec genls) is t iff (genl? spec genl) for some genl in genls
   (ascending transitive search; inexpensive)"
    '((spec el-fort-p) (genls listp)) '(booleanp))
  (register-cyc-api-function 'any-spec? '(genl specs &optional mt tv)
    "Returns T iff (spec? genl spec) for some spec in SPECS"
    '((genl el-fort-p) (specs listp)) '(booleanp))
  (register-cyc-api-function 'all-genl? '(spec genls &optional mt tv)
    "Returns T iff (genl? spec genl) for every genl in GENLS
   (ascending transitive search; inexpensive)"
    '((spec el-fort-p) (genls listp)) '(booleanp))
  (register-cyc-api-function 'all-spec? '(genl specs &optional mt tv)
    "Returns T iff (spec? genl spec) for every spec in SPECS"
    '((genl el-fort-p) (specs listp)) '(booleanp))
  (register-cyc-api-function 'any-genl-any? '(specs genls &optional mt tv)
    "Return T iff (genl? spec genl mt) for any spec in SPECS, genl in GENLS"
    '((specs listp) (genls listp)) '(booleanp))
  (register-cyc-api-function 'any-genl-all? '(specs genls &optional mt tv)
    "Return T iff (genl? spec genl mt) for any spec in SPECS and all genl in GENLS"
    '((specs listp) (genls listp)) '(booleanp))
  (register-cyc-api-function 'all-spec-any? '(specs genls &optional mt tv)
    "Return T iff for each spec in SPECS there is some genl in GENLS s.t. (genl? spec genl mt)"
    '((specs listp) (genls listp)) '(booleanp))
  (register-cyc-api-function 'not-genl? '(col not-genl &optional mt tv)
    "Return whether collection NOT-GENL is not a genl of COL."
    '((col el-fort-p) (not-genl el-fort-p)) '(booleanp))
  (register-cyc-api-function 'all-not-spec? '(col not-specs &optional mt tv)
    "Return whether every collection in NOT-SPECS is not a spec of COL."
    '((col el-fort-p) (not-specs listp)) '(booleanp))
  (register-cyc-api-function 'any-not-genl? '(col not-genls &optional mt tv)
    "Returns whether any collection in NOT-GENLS is not a genl of COL."
    '((col el-fort-p) (not-genls listp)) '(booleanp))
  (register-cyc-api-function 'collections-coextensional? '(col-1 col-2 &optional mt)
    "Are COL-1 and COL-2 coextensional?"
    '((col-1 el-fort-p) (col-2 el-fort-p)) '(booleanp))
  (register-cyc-api-function 'collections-intersect? '(col-1 col-2 &optional mt)
    "Do collections COL-1 and COL-2 intersect?
   (uses only sbhl graphs: their extensions are not searched
    nor are their sufficient conditions analyzed)"
    '((col-1 el-fort-p) (col-2 el-fort-p)) '(booleanp))
  (register-cyc-api-function 'why-genl? '(spec genl &optional mt tv behavior)
    "Justification of (genls SPEC GENL)"
    '((spec el-fort-p) (genl el-fort-p)) '(listp))
  (register-cyc-api-function 'why-not-genl? '(spec genl &optional mt tv behavior)
    "Justification of (not (genls SPEC GENL))"
    '((spec el-fort-p) (genl el-fort-p)) '(listp))
  (register-cyc-api-function 'why-not-assert-genls? '(spec genl &optional mt)
    "Justification of why asserting (genls SPEC GENL) is not consistent"
    '((spec el-fort-p) (genl el-fort-p)) '(listp))
  (register-cyc-api-function 'collection-leaves '(col &optional mt tv)
    "Returns the minimally-general (the most specific) among all-specs of COL"
    '((col el-fort-p)) '((list fort-p)))
  (register-cyc-api-function 'min-cols '(cols &optional mt tv)
    "Returns the minimally-general (the most specific) among reified collections COLS,
   collections that have no proper specs among COLS"
    '((cols list-of-collections-p)) '((list fort-p)))
  (register-cyc-api-function 'min-col '(cols &optional mt tv)
    "Returns the single minimally-general (the most specific) among reified collections COLS.
Ties are broken by comparing the number of all-genls which is a rough depth estimate."
    '((cols listp)) '(fort-p))
  (register-cyc-api-function 'max-cols '(cols &optional mt tv)
    "Returns the most-general among reified collections COLS, collections
   that have no proper genls among COLS"
    '((cols listp)) '((list fort-p)))
  (register-cyc-api-function 'min-ceiling-cols '(cols &optional candidates mt tv)
    "Returns the most specific common generalizations among reified collections COLS
   (if CANDIDATES is non-nil, then result is a subset of CANDIDATES)"
    '((cols listp)) '((list fort-p)))
  (register-cyc-api-function 'max-floor-cols '(cols &optional candidates mt tv)
    "Returns the most general common specializations among reified collections COLS
   (if CANDIDATES is non-nil, then result is a subset of CANDIDATES)"
    '((cols listp)) '((list fort-p)))
  (register-cyc-api-function 'any-genl-isa '(col isa &optional mt tv)
    "Return some genl of COL that isa instance of ISA (if any such genl exists)"
    '((col el-fort-p) (isa el-fort-p)) '(fort-p))
  (register-cyc-api-function 'lighter-col '(col-a col-b)
    "Return COL-B iff it has fewer specs than COL-A, else return COL-A"
    '((col-a el-fort-p) (col-b el-fort-p)) '(fort-p))
  (register-cyc-api-function 'lightest-of-cols '(cols)
    "Return the collection having the fewest specs given a list of collections."
    '((cols listp)) '(fort-p))
  (register-cyc-api-function 'shallower-col '(col-a col-b)
    "Return COL-B iff it has fewer genls than COL-A, else return COL-A"
    '((col-a el-fort-p) (col-b el-fort-p)) '(fort-p))
  (register-cyc-api-function 'max-floor-mts-of-genls-paths '(spec genl &optional tv)
    "@return listp; Returns in what (most-genl) mts GENL is a genls of SPEC"
    '((spec el-fort-p) (genl el-fort-p)) nil)
  (register-kb-function 'genls-after-adding)
  (register-kb-function 'genls-after-removing))
