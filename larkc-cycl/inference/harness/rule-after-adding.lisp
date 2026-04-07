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

(deflexical *rule-after-adding-predicates* nil
  "[Cyc] The predicates whose extent implement the ruleAfterAdding and ruleAfterRemoving support.")

(defglobal *rule-after-addings-hash* nil)

(defglobal *rule-after-removings-hash* nil)

;;; Functions

(defun clear-rule-after-addings ()
  (when *rule-after-addings-hash*
    (clrhash *rule-after-addings-hash*))
  nil)

(defun clear-rule-after-removings ()
  (when *rule-after-removings-hash*
    (clrhash *rule-after-removings-hash*))
  nil)

(defun handle-rule-after-addings (argument assertion)
  (declare (type (satisfies argument-p) argument)
           (type (satisfies assertion-p) assertion))
  (unless *after-addings-disabled?*
    (when (rule-assertion? assertion)
      (let ((cnf (assertion-cnf assertion)))
        (dolist (literal (neg-lits cnf))
          (handle-rule-after-addings-int argument literal assertion))
        (dolist (literal (pos-lits cnf))
          (handle-rule-after-addings-int argument literal assertion)))))
  nil)

(defun handle-rule-after-addings-int (argument literal assertion)
  (let ((pred (literal-arg literal 0))
        (mt (assertion-mt assertion)))
    (when (fort-p pred)
      (with-inference-mt-relevance mt
        (dolist (info (get-rule-after-addings pred))
          (destructuring-bind (fun . fun-mt) info
            (when (and (function-spec-p fun)
                       (relevant-mt? fun-mt))
              (ignore-errors
                ;; Likely calls fun with argument, literal, and assertion
                ;; in the context of the rule-after-adding
                (missing-larkc 33042))))))))
  nil)

(defun handle-rule-after-removings (argument assertion)
  (declare (type (satisfies argument-p) argument)
           (type (satisfies assertion-p) assertion))
  (when (rule-assertion? assertion)
    (let ((cnf (assertion-cnf assertion)))
      (dolist (literal (neg-lits cnf))
        (handle-rule-after-removings-int argument literal assertion))
      (dolist (literal (pos-lits cnf))
        (handle-rule-after-removings-int argument literal assertion))))
  nil)

(defun handle-rule-after-removings-int (argument literal assertion)
  ;; NOTE: Java passes assertion (not literal) as first arg to literal-arg.
  ;; This appears to be a bug in the original Java, but we port it as-is.
  (let ((pred (literal-arg assertion 0))
        (mt (assertion-mt assertion)))
    (when (fort-p pred)
      (with-inference-mt-relevance mt
        ;; Likely calls get-rule-after-removings on pred
        (dolist (info (missing-larkc 33041))
          (destructuring-bind (fun . fun-mt) info
            (when (and (function-spec-p fun)
                       (relevant-mt? fun-mt))
              (ignore-errors
                ;; Likely calls fun with argument, literal, and assertion
                ;; in the context of the rule-after-removing
                (missing-larkc 33044))))))))
  nil)

(defun get-rule-after-addings (pred)
  (when (null *rule-after-addings-hash*)
    (initialize-rule-after-addings-hash))
  (gethash pred *rule-after-addings-hash*))

;; (defun get-rule-after-removings (pred) ...) -- active declareFunction, no body
;; (defun handle-rule-after-adding (pred fun assertion mt) ...) -- active declareFunction, no body
;; (defun handle-rule-after-removing (pred fun assertion mt) ...) -- active declareFunction, no body

(defun rebuild-rule-after-adding-caches ()
  (initialize-rule-after-addings-hash)
  (initialize-rule-after-removings-hash)
  nil)

(defun initialize-rule-after-addings-hash ()
  (if *rule-after-addings-hash*
      (clrhash *rule-after-addings-hash*)
      (setf *rule-after-addings-hash* (make-hash-table :size 100)))
  (with-all-mts
    (do-predicate-extent-index (ass #$ruleAfterAdding)
      (let ((formula (gaf-formula ass)))
        (destructuring-bind (rule-after-adding-pred pred v-rule-after-adding) formula
          (declare (ignore rule-after-adding-pred))
          (when (valid-fort? pred)
            (let* ((v-rule-after-adding (cycl-subl-symbol-symbol v-rule-after-adding))
                   (item-var (cons v-rule-after-adding (assertion-mt ass))))
              (unless (member item-var (gethash pred *rule-after-addings-hash*) :test #'eql :key #'identity)
                (push item-var (gethash pred *rule-after-addings-hash*)))))))))
  nil)

(defun initialize-rule-after-removings-hash ()
  (if (not (hash-table-p *rule-after-removings-hash*))
      (setf *rule-after-removings-hash* (make-hash-table :size 100))
      (clrhash *rule-after-removings-hash*))
  (with-all-mts
    (do-predicate-extent-index (ass #$ruleAfterRemoving)
      (let ((formula (gaf-formula ass)))
        (destructuring-bind (rule-after-removing-pred pred rule-after-removing) formula
          (declare (ignore rule-after-removing-pred))
          (when (valid-fort? pred)
            (let* ((rule-after-removing (cycl-subl-symbol-symbol rule-after-removing))
                   (item-var (cons rule-after-removing (assertion-mt ass))))
              (unless (member item-var (gethash pred *rule-after-removings-hash*) :test #'eql :key #'identity)
                (push item-var (gethash pred *rule-after-removings-hash*)))))))))
  nil)

;; (defun recache-rule-after-addings (pred) ...) -- active declareFunction, no body
;; (defun recache-rule-after-removings (pred) ...) -- active declareFunction, no body
;; (defun propagate-rule-after-adding (assertion pred) ...) -- active declareFunction, no body
;; (defun repropagate-rule-after-adding (pred fun mt) ...) -- active declareFunction, no body
;; (defun repropagate-rule-after-adding-internal (assertion pred) ...) -- active declareFunction, no body
;; (defun gather-literals-with-pred (cnf pred) ...) -- active declareFunction, no body

;;; Setup

(toplevel
  (declare-defglobal '*rule-after-addings-hash*)
  (declare-defglobal '*rule-after-removings-hash*))
