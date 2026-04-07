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

;;; Variables

(defglobal *active-sbhl-caching-policies* (make-hash-table)
  "[Cyc] The current caching policies that are active for the respective caches.")

(deflexical *valid-sbhl-caching-instruction-verb*
    '(:link-predicate :policy :capacity :exempt :prefetch)
  "[Cyc] The list of valid SBHL caching instruction action verbs.")

(deflexical *valid-sbhl-caching-policy-types* '(:sticky :swapout)
  "[Cyc] The list of the valid SBHL caching policy types.")

;;; Functions — declare section order

;; (defun valid-sbhl-caching-instruction-verb-p (verb)) -- commented declareFunction (1 0), no body
;; (defun valid-sbhl-caching-policy-type-p (type)) -- commented declareFunction (1 0), no body

(defun new-sbhl-caching-policy (link-predicate policy-type &optional
                                (capacity *sbhl-backing-file-vector-cache-minimum-size*)
                                exemptions prefetch)
  "[Cyc] Create a new SBHL caching policy plist."
  (check-type policy-type (member :sticky :swapout))
  (let ((policy nil))
    (setf policy (putf policy :link-predicate link-predicate))
    (setf policy (putf policy :policy policy-type))
    (setf policy (flesh-out-sbhl-caching-policy policy capacity exemptions prefetch))
    policy))

(defun flesh-out-sbhl-caching-policy (policy capacity exemptions prefetch)
  "[Cyc] Interpret the arguments and see if they are sensible with respect to the policy."
  (let ((policy-type (getf policy :policy :unknown)))
    (cond
      ((eq policy-type :sticky)
       (unless capacity
         (setf capacity :undefined))
       (must (eq capacity :undefined)
              "Sticky policy does not support capacity ~A, only :undefined." capacity)
       (setf policy (putf policy :capacity capacity))
       (unless exemptions
         (setf exemptions :all))
       (must (eq exemptions :all)
              "Invalid exemption specification ~A. Only :all is permitted for sticky policy."
              exemptions)
       (setf policy (putf policy :exempt exemptions))
       (must (or (eq prefetch :all)
                 (list-of-type-p #'fort-p prefetch))
              "Invalid prefetch specification ~A. Only :ALL or lists of FORT-P (incl NIL) are permitted."
              prefetch)
       (setf policy (putf policy :prefetch prefetch)))

      ((eq policy-type :swapout)
       (must (positive-integer-p capacity)
              "Swapout policy does not support capacity ~A, only positive integer capacities are supported."
              capacity)
       (setf policy (putf policy :capacity capacity))
       (must (or (eq exemptions :all)
                 (list-of-type-p #'fort-p exemptions))
              "Invalid exemption specification ~A. Only lists of FORT-P (incl NIL) or :all are permitted."
              exemptions)
       (setf policy (putf policy :exempt exemptions))
       (must (list-of-type-p #'fort-p prefetch)
              "Invalid prefetch specification ~A. Only lists of FORT-P (incl NIL) are permitted."
              prefetch)
       (setf policy (putf policy :prefetch prefetch)))

      (t
       (error "Unknown policy type ~A ... dont know what to do." policy))))
  policy)

;; (defun clone-sbhl-caching-policy (policy)) -- commented declareFunction (1 0), no body

(defun get-sbhl-caching-policy-link-predicate (policy)
  (getf policy :link-predicate))

(defun get-sbhl-caching-policy-type (policy)
  (getf policy :policy))

;; (defun get-sbhl-caching-policy-capacity (policy)) -- commented declareFunction (1 0), no body
;; (defun get-sbhl-caching-policy-terms-to-exempt (policy)) -- commented declareFunction (1 0), no body
;; (defun set-sbhl-caching-policy-terms-to-exempt (policy terms)) -- commented declareFunction (2 0), no body

(defun get-sbhl-caching-policy-terms-to-prefetch (policy)
  (getf policy :prefetch))

;; (defun set-sbhl-caching-policy-terms-to-prefetch (policy terms)) -- commented declareFunction (2 0), no body

(defun reset-sbhl-caching-policy (policy)
  "[Cyc] Implements the cache policy after having reset the existing
infrastructure relevant to the policy.
@return the policy"
  (let* ((predicate (get-sbhl-caching-policy-link-predicate policy))
         (module (get-sbhl-module predicate)))
    (swap-out-all-pristine-graph-links module)
    (implement-sbhl-caching-policy policy)))

(defun implement-sbhl-caching-policy (policy)
  "[Cyc] Apply the policy to the current caching infrastructure for the
SBHL module, paging in whatever needs to be loaded, in the
fashion specified by the policy.
@return the POLICY"
  (with-rw-write-lock (*sbhl-rw-lock*)
    (let* ((predicate (get-sbhl-caching-policy-link-predicate policy))
           (module (get-sbhl-module predicate))
           (policy-type (get-sbhl-caching-policy-type policy)))
      (cond
        ((eq policy-type :sticky)
         (set-cache-strategy-for-sbhl-module module :dont-cache))

        ((eq policy-type :swapout)
         (let* ((capacity (missing-larkc 2357))
                (cache-strategy (new-cache-strategy-for-sbhl-module module capacity)))
           (set-cache-strategy-for-sbhl-module module cache-strategy))
         (seed-sbhl-module-graph-cache-with-nodes module (missing-larkc 2358) :touch))

        (t
         (error "Caching policy of type ~A not yet implemented." policy-type)))
      (seed-sbhl-module-graph-cache-with-nodes module
                                               (get-sbhl-caching-policy-terms-to-prefetch policy))
      (setf (gethash predicate *active-sbhl-caching-policies*) policy)))
  policy)

(defun seed-sbhl-module-graph-cache-with-nodes (module nodes &optional touch-p)
  "[Cyc] @note this method ignores invalid fort types on its own
@param nodes LIST-OF-TYPE-P FORT-P or :all"
  (when (null nodes)
    (return-from seed-sbhl-module-graph-cache-with-nodes
      (values module 0 touch-p)))
  (let ((paged-in 0)
        (term-list nodes))
    (when (eq term-list :all)
      (setf term-list (missing-larkc 2356)))
    (dolist (v-term term-list)
      (when (valid-fort? v-term)
        (get-sbhl-graph-link v-term module)
        (incf paged-in)
        (when touch-p
          (touch-sbhl-graph-link v-term (get-sbhl-graph-link v-term module) module))))
    (values module paged-in touch-p)))

;; (defun get-all-nodes-for-sbhl-module-graph (module)) -- commented declareFunction (1 0), no body

(defun create-sbhl-caching-policy-from-term-recommendation-list
    (link-predicate policy-type capacity term-list &optional (exempt 0) (prefetch 0))
  "[Cyc] Given a list of terms and some of the basic information for a caching policy,
construct one that will meet the structural requirements of the sbhl caching policy
description.
@param exempt the first N of the term list to exempt from caching
@param prefetch the first N AFTER the exempt of the term list to prefetch
@return the SBHL caching policy"
  (declare (type list term-list))
  (let ((exemptions nil)
        (prefetchers nil))
    (if (eq exempt :all)
        (progn
          (setf exemptions :all)
          (if (eq prefetch :all)
              (setf prefetchers :all)
              (setf prefetchers (when (integerp prefetch)
                                  (first-n prefetch term-list)))))
        (progn
          (setf exemptions (when (integerp exempt)
                             (first-n exempt term-list)))
          (setf prefetchers (when (and (integerp exempt) (integerp prefetch))
                              ;; missing-larkc 9124 — likely (first-n prefetch (nthcdr exempt term-list))
                              (missing-larkc 9124)))))
    (new-sbhl-caching-policy link-predicate policy-type capacity exemptions prefetchers)))

;; (defun save-sbhl-caching-policies (policies file &optional append?)) -- commented declareFunction (2 1), no body

;; commented declareFunction, but body present in Java
(defun load-sbhl-caching-policies (policies-file)
  "[Cyc] Load the SBHL caching policies in the most effective way.
Return LISTP of caching policies."
  (cfasl-load policies-file))

;; (defun reset-sbhl-caching-policies (policies)) -- commented declareFunction (1 0), no body

(defun reset-sbhl-caching-policies-internal (policies)
  "[Cyc] Do the actual reset of the SBHL caching policies."
  (setf *sbhl-backing-file-vector-caches-for-modules* nil)
  (clrhash *active-sbhl-caching-policies*)
  (dolist (policy policies)
    (reset-sbhl-caching-policy policy))
  :reset)

;; (defun enforce-monolithic-kb-sbhl-caching-policies ()) -- commented declareFunction (0 0), no body

(defun enforce-standard-kb-sbhl-caching-policies (dump-directory)
  "[Cyc] Attempt to load a standard KB sbhl caching policy file from the
dump directory. If no such file exists, revert to the legacy
SBHL caching policy."
  (let ((policies-file (get-standard-kb-sbhl-caching-policies-filename dump-directory))
        (policies nil))
    (when (probe-file policies-file)
      (let ((msg (handler-case
                     (progn (setf policies (load-sbhl-caching-policies policies-file))
                            nil)
                   (error (e) (princ-to-string e)))))
        (when (stringp msg)
          (warn "~&Skipping invalid SBHL caching policies file ~A.~%Load attempt caused error: ~A.~%"
                policies-file msg))))
    (unless policies
      (setf policies (propose-legacy-kb-sbhl-caching-policies)))
    (reset-sbhl-caching-policies-internal policies))
  :enforced)

;; (defun dump-active-kb-sbhl-caching-policies (dir &optional policies)) -- commented declareFunction (1 1), no body

(defun get-standard-kb-sbhl-caching-policies-filename (dump-directory)
  (kb-dump-file "standard-kb-sbhl-caching-policies" dump-directory))

;; (defun gather-active-kb-sbhl-caching-policies ()) -- commented declareFunction (0 0), no body
;; (defun gather-one-active-kb-sbhl-caching-policy (module)) -- commented declareFunction (1 0), no body
;; (defun prepare-kb-sbhl-caching-policy-term-list-for-dumping (term-list)) -- commented declareFunction (1 0), no body
;; (defun setup-sbhl-graphs-for-sbhl-cache-tuning-data-gathering ()) -- commented declareFunction (0 0), no body
;; (defun setup-sbhl-graphs-for-sbhl-cache-tuning-experiment ()) -- commented declareFunction (0 0), no body
;; (defun tear-down-sbhl-graphs-for-sbhl-cache-tuning-experiment (data)) -- commented declareFunction (1 0), no body
;; (defun contribute-sbhl-graphs-data-for-sbhl-cache-tuning-experiment (module data)) -- commented declareFunction (2 0), no body
;; (defun tear-down-sbhl-graphs-for-sbhl-cache-tuning-data-gathering ()) -- commented declareFunction (0 0), no body
;; (defun facade-sbhl-module-cache-strategies-for-recording (&optional module)) -- commented declareFunction (0 1), no body
;; (defun unfacade-sbhl-module-cache-strategies-facaded-for-recording (&optional module)) -- commented declareFunction (0 1), no body
;; (defun recommend-sbhl-caching-preference-term-list-from-recordings (module ref-counts)) -- commented declareFunction (2 0), no body
;; (defun recommend-sbhl-caching-preference-term-list-from-ref-counts (module ref-counts)) -- commented declareFunction (2 0), no body
;; (defun count-references-in-sbhl-cache-strategy-recordings (recordings &optional limit)) -- commented declareFunction (1 1), no body

;;; Setup

(declare-defglobal '*active-sbhl-caching-policies*)
