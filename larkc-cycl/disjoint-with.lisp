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
;;; Variables
;;; ======================================================================

(defparameter *maximal-consistent-subsets* nil)
(defparameter *maximal-consistent-subsets-visited-subsets* nil)

;;; ======================================================================
;;; Definitions — following declare section ordering
;;; ======================================================================

;; (defun local-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun local-max-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun local-not-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun local-min-not-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun all-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun all-not-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun max-all-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun max-all-disjoint-with-no-sdc (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun min-all-not-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun min-implied-not-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun min-all-asserted-not-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body

(defun any-disjoint-collection-pair (cols &optional mt)
  "[Cyc] Returns a pair of disjoint elements of COLS (if any exist)"
  (declare (list cols))
  (let ((disjoint nil)
        (n 0))
    (csome (col-1 cols disjoint)
      (incf n)
      (csome (col-2 (nthcdr n cols) disjoint)
        (when (disjoint-with? col-1 col-2 mt)
          (setf disjoint (list col-1 col-2)))))
    disjoint))

;; (defun sbhl-record-max-true-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun sbhl-unrecord-max-true-disjoint-with (col &optional mt tv) ...) -- 1 required, 2 optional, no body
;; (defun instances-of-disjoint-collections? (term1 term2 &optional mt tv) ...) -- 2 required, 2 optional, no body
;; (defun why-instances-of-disjoint-collections (term1 term2 &optional mt tv) ...) -- 2 required, 2 optional, no body

(defun disjoint-with? (c1 c2 &optional mt tv)
  "[Cyc] are collections <c1> and <c2> disjoint?"
  (if (first-order-naut? c1)
      ;; missing-larkc 10979: likely nat-disjoint-with?, which handles disjointness
      ;; checking for NAUTs (non-atomic unreified terms) by reducing to their
      ;; result-type collections before checking sbhl disjointness.
      (missing-larkc 10979)
      (sbhl-implied-disjoins-relation-p (get-sbhl-module #$disjointWith) c1 c2 mt tv)))

;; (defun nat-disjoint-with? (c1 c2 &optional mt tv) ...) -- 2 required, 2 optional, no body

(defun any-disjoint-with? (c1s c2 &optional mt tv)
  "[Cyc] is any c1 in <c1s> disjoint with c2?"
  (sbhl-any-with-implied-disjoins-relation-p (get-sbhl-module #$disjointWith) c1s c2 mt tv))

;; (defun any-disjoint-with-any? (c1s c2s &optional mt tv) ...) -- 2 required, 2 optional, no body
;; (defun not-disjoint-with? (c1 c2 &optional mt tv) ...) -- 2 required, 2 optional, no body
;; (defun disjoint-with-specs? (c1 c2 &optional mt) ...) -- 2 required, 1 optional, no body
;; (defun any-disjoint-collection-pair? (cols &optional mt) ...) -- 1 required, 1 optional, no body
;; (defun collections-disjoint? (col-1 col-2 &optional mt) ...) -- 2 required, 1 optional, no body
;; (defun basis-for-not-mdw? (c1 c2 &optional mt tv) ...) -- 2 required, 2 optional, no body
;; (defun why-disjoint-with? (c1 c2 &optional mt tv behavior) ...) -- 2 required, 3 optional, no body
;; (defun why-collections-disjoint? (c1 c2 &optional mt) ...) -- 2 required, 1 optional, no body
;; (defun why-not-disjoint-with? (c1 c2 &optional mt tv behavior) ...) -- 2 required, 3 optional, no body
;; (defun max-floor-mts-of-disjoint-with-paths (c1 c2 &optional mt) ...) -- 2 required, 1 optional, no body
;; (defun min-mts-of-disjoint-with-paths (c1 c2 &optional mt) ...) -- 2 required, 1 optional, no body
;; (defun max-floor-mts-of-not-disjoint-with-paths (c1 c2 &optional mt) ...) -- 2 required, 1 optional, no body
;; (defun min-mts-of-not-disjoint-with-paths (c1 c2 &optional mt) ...) -- 2 required, 1 optional, no body
;; (defun disjoint-with-mts (col) ...) -- 1 required, 0 optional, no body
;; (defun asserted-disjoint-with (col &optional mt) ...) -- 1 required, 1 optional, no body
;; (defun asserted-not-disjoint-with (col &optional mt) ...) -- 1 required, 1 optional, no body
;; (defun supported-disjoint-with (col &optional mt) ...) -- 1 required, 1 optional, no body
;; (defun supported-not-disjoint-with (col &optional mt) ...) -- 1 required, 1 optional, no body
;; (defun mdw-after-adding (argument assertion) ...) -- 2 required, 0 optional, no body
;; (defun mdw-after-removing (argument assertion) ...) -- 2 required, 0 optional, no body
;; (defun clear-mdw-graph () ...) -- 0 required, 0 optional, no body
;; (defun clear-node-mdw-links (col) ...) -- 1 required, 0 optional, no body
;; (defun reset-mdw-links (col) ...) -- 1 required, 0 optional, no body
;; (defun reset-mdw-links-in-mt (col mt) ...) -- 2 required, 0 optional, no body
;; (defun reset-mdw-graph (&optional mt) ...) -- 0 required, 1 optional, no body
;; (defun maximal-consistent-subsets (cols) ...) -- 1 required, 0 optional, no body
;; (defun maximal-consistent-subset? (cols1 cols2) ...) -- 2 required, 0 optional, no body
;; (defun maximal-consistent-subsets-recursive (cols1 cols2) ...) -- 2 required, 0 optional, no body
;; (defun disjointness-map (cols) ...) -- 1 required, 0 optional, no body
;; (defun first-disjointness (col disjointness-map) ...) -- 2 required, 0 optional, no body

;;; ======================================================================
;;; Setup — API and KB function registrations
;;; ======================================================================

(toplevel
  (register-cyc-api-function 'any-disjoint-collection-pair '(cols &optional mt)
    "Returns a pair of disjoint elements of COLS (if any exist)"
    '((cols listp))
    '((list fort-p)))
  (register-cyc-api-function 'any-disjoint-collection-pair? '(cols &optional mt)
    "Are any two collections in COLS disjoint?"
    '((cols listp))
    '(booleanp))
  (register-obsolete-cyc-api-function 'collections-disjoint? '(disjoint-with?)
    '(col-1 col-2 &optional mt)
    "@see disjoint-with?"
    '((col-1 el-fort-p) (col-2 el-fort-p))
    '(booleanp))
  (register-obsolete-cyc-api-function 'why-collections-disjoint? '(why-disjoint-with?)
    '(c1 c2 &optional mt)
    "@see why-disjoint-with?"
    '((c1 el-fort-p) (c2 el-fort-p))
    '(listp))
  (register-kb-function 'mdw-after-adding)
  (register-kb-function 'mdw-after-removing))
