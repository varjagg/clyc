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

(defparameter *debug-after-addings?* nil
  "[Cyc] Set this to T if you want to see errors caused by afterAddings instead of catching them")

(deflexical *gaf-after-adding-predicates*
  (list #$afterAdding #$afterRemoving)
  "[Cyc] The predicates whose extent implement the afterAdding and afterRemoving support.")

(defglobal *gaf-after-addings-hash* nil)

(defglobal *gaf-after-removings-hash* nil)

(defparameter *after-addings-disabled?* nil
  "[Cyc] When non-nil, afterAddings are disabled.")

;;; Functions

(defun clear-after-addings ()
  (clear-gaf-after-addings)
  (clear-rule-after-addings)
  nil)

(defun clear-gaf-after-addings ()
  (when *gaf-after-addings-hash*
    (clrhash *gaf-after-addings-hash*))
  nil)

(defun clear-after-removings ()
  (clear-gaf-after-removings)
  (clear-rule-after-removings)
  nil)

(defun clear-gaf-after-removings ()
  (when *gaf-after-removings-hash*
    (clrhash *gaf-after-removings-hash*))
  nil)

;; Reconstructed from Internal Constants:
;;   $sym3$CLET = makeSymbol("CLET")
;;   $list4 = list(list(makeSymbol("*AFTER-ADDINGS-DISABLED?*"), T))
;; The macro binds *after-addings-disabled?* to T around the body.
(defmacro disable-after-addings (&body body)
  `(let ((*after-addings-disabled?* t))
     ,@body))

(defun handle-after-addings (argument assertion)
  (handle-gaf-after-addings argument assertion)
  (when (valid-assertion? assertion)
    (handle-rule-after-addings argument assertion))
  nil)

(defun handle-gaf-after-addings (argument assertion)
  (declare (type argument argument)
           (type assertion assertion))
  (unless *after-addings-disabled?*
    (when (gaf-assertion? assertion)
      (let ((pred (gaf-arg assertion 0))
            (mt (assertion-mt assertion)))
        (when (fort-p pred)
          (with-inference-mt-relevance mt
            (dolist (info (get-gaf-after-addings pred))
              (destructuring-bind (fun . fun-mt) info
                (when (and (function-spec-p fun)
                           (relevant-mt? fun-mt))
                  (if (not *debug-after-addings?*)
                      (ignore-errors
                        (handle-gaf-after-adding fun argument assertion))
                      (handle-gaf-after-adding fun argument assertion))))))))))
  nil)

(defun handle-after-removings (argument assertion)
  (handle-gaf-after-removings argument assertion)
  (when (valid-assertion? assertion)
    (handle-rule-after-removings argument assertion))
  nil)

(defun handle-gaf-after-removings (argument assertion)
  (declare (type argument argument)
           (type assertion assertion))
  (when (gaf-assertion? assertion)
    (let ((pred (gaf-arg assertion 0))
          (mt (assertion-mt assertion)))
      (when (fort-p pred)
        (with-inference-mt-relevance mt
          (dolist (info (get-gaf-after-removings pred))
            (destructuring-bind (fun . fun-mt) info
              (when (and (function-spec-p fun)
                         (relevant-mt? fun-mt))
                (if (not *debug-after-addings?*)
                    (ignore-errors
                      (handle-gaf-after-removing fun argument assertion))
                    (handle-gaf-after-removing fun argument assertion)))))))))
  nil)

(defun get-gaf-after-addings (pred)
  (when (null *gaf-after-addings-hash*)
    (initialize-gaf-after-addings-hash))
  (let ((result (gethash pred *gaf-after-addings-hash*)))
    (when (somewhere-cached-pred-p pred)
      (setf result (cons *somewhere-cache-gaf-after-adding-info* result)))
    result))

(defun get-gaf-after-removings (pred)
  (when (null *gaf-after-removings-hash*)
    (initialize-gaf-after-removings-hash))
  (let ((result (gethash pred *gaf-after-removings-hash*)))
    (when (somewhere-cached-pred-p pred)
      (setf result (cons *somewhere-cache-gaf-after-adding-info* result)))
    result))

(defun handle-gaf-after-adding (function argument assertion)
  (bt:with-lock-held (*hl-lock*)
    (funcall function argument assertion))
  nil)

(defun handle-gaf-after-removing (function argument assertion)
  (bt:with-lock-held (*hl-lock*)
    (funcall function argument assertion))
  nil)

(defun rebuild-after-adding-caches ()
  (rebuild-gaf-after-adding-caches)
  (rebuild-rule-after-adding-caches)
  nil)

(defun rebuild-gaf-after-adding-caches ()
  (initialize-gaf-after-addings-hash)
  (initialize-gaf-after-removings-hash)
  nil)

(defun initialize-gaf-after-addings-hash ()
  (if *gaf-after-addings-hash*
      (clrhash *gaf-after-addings-hash*)
      (setf *gaf-after-addings-hash* (make-hash-table :size 100)))
  (with-all-mts
    (do-predicate-extent-index (ass #$afterAdding)
      (let ((formula (gaf-formula ass)))
        (destructuring-bind (gaf-after-adding-pred pred gaf-after-adding) formula
          (declare (ignore gaf-after-adding-pred))
          (when (valid-fort? pred)
            (let* ((gaf-after-adding (cycl-subl-symbol-symbol gaf-after-adding))
                   (item-var (cons gaf-after-adding (assertion-mt ass))))
              (unless (member item-var (gethash pred *gaf-after-addings-hash*))
                (push item-var (gethash pred *gaf-after-addings-hash*)))))))))
  nil)

(defun initialize-gaf-after-removings-hash ()
  (if (not (hash-table-p *gaf-after-removings-hash*))
      (setf *gaf-after-removings-hash* (make-hash-table :size 100))
      (clrhash *gaf-after-removings-hash*))
  (with-all-mts
    (do-predicate-extent-index (ass #$afterRemoving)
      (let ((formula (gaf-formula ass)))
        (destructuring-bind (gaf-after-removing-pred pred gaf-after-removing) formula
          (declare (ignore gaf-after-removing-pred))
          (when (valid-fort? pred)
            (let* ((gaf-after-removing (cycl-subl-symbol-symbol gaf-after-removing))
                   (item-var (cons gaf-after-removing (assertion-mt ass))))
              (unless (member item-var (gethash pred *gaf-after-removings-hash*))
                (push item-var (gethash pred *gaf-after-removings-hash*)))))))))
  nil)

;; Orphan constants for stripped functions:
;;   $sym18$FORT_P, $kw19$TRUE, $sym20$PROPAGATE_GAF_AFTER_ADDING,
;;   $sym21$SYMBOLP, $sym22$HLMT_P, $sym23$RELEVANT_MT_IS_SPEC_MT,
;;   $sym24$REPROPAGATE_GAF_AFTER_ADDING_INTERNAL, $sym25$RELEVANT_MT_IS_GENL_MT

;; (defun recache-gaf-after-addings (pred) ...) -- active declareFunction, no body
;; (defun recache-gaf-after-removings (pred) ...) -- active declareFunction, no body
;; (defun propagate-gaf-after-adding (pred gaf-after-adding) ...) -- active declareFunction, no body
;; (defun repropagate-gaf-after-adding (pred gaf-after-adding mt) ...) -- active declareFunction, no body
;; (defun repropagate-gaf-after-adding-internal (assertion) ...) -- active declareFunction, no body

;;; Setup

(toplevel
  (declare-defglobal '*gaf-after-addings-hash*)
  (declare-defglobal '*gaf-after-removings-hash*))
