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

;; Two struct types for SBHL direction links:
;; - sbhl-directed-link: for predicates with :predicate/:inverse directions
;; - sbhl-undirected-link: for predicates with a single :link direction

(defstruct (sbhl-directed-link (:print-function print-sbhl-directed-link))
  "[Cyc] A link node for directed SBHL graphs, with predicate and inverse slots."
  predicate-links
  inverse-links)

(defun print-sbhl-directed-link (object stream depth)
  "[Cyc] Print function for sbhl-directed-link. Original print-link was missing-larkc 2047."
  (declare (ignore depth))
  (print-unreadable-object (object stream :type t :identity t)))

(defstruct (sbhl-undirected-link (:print-function print-sbhl-undirected-link))
  "[Cyc] A link node for undirected SBHL graphs, with a single links slot."
  links)

(defun print-sbhl-undirected-link (object stream depth)
  "[Cyc] Print function for sbhl-undirected-link. Original print-link was missing-larkc 2048."
  (declare (ignore depth))
  (print-unreadable-object (object stream :type t :identity t)))

;; (defun print-link (arg1 arg2 arg3)) -- commented declareFunction, no body

(defun create-sbhl-directed-link (direction mt-links)
  "[Cyc] Constructor: returns sbhl-directed-link-p with MT-LINKS in the DIRECTION field"
  (let ((direction-link (make-sbhl-directed-link)))
    (set-sbhl-directed-link direction-link direction mt-links)
    direction-link))

(defun create-sbhl-undirected-link (mt-links)
  "[Cyc] Constructor: returns sbhl-undirected-link-p with MT-LINKS in the links field"
  (let ((direction-link (make-sbhl-undirected-link)))
    (set-sbhl-undirected-link direction-link mt-links)
    direction-link))

(defun create-sbhl-direction-link (direction mt-links module)
  "[Cyc] Constructor: returns sbhl-direction-link-p with direction field DIRECTION filled with MT-LINKS. Uses MODULE / *sbhl-module* to assess whether links are directed"
  (declare (type (satisfies sbhl-module-p) module))
  (if (sbhl-module-directed-links? module)
      (create-sbhl-directed-link direction mt-links)
      (create-sbhl-undirected-link mt-links)))

(defun sbhl-direction-link-p (d-link)
  "[Cyc] Accessor: is D-LINK either an sbhl-directed-link or sbhl-undirected-link."
  (or (sbhl-directed-link-p d-link)
      (sbhl-undirected-link-p d-link)))

;; (defun any-sbhl-links-p (arg1 arg2)) -- commented declareFunction, no body

(defun any-sbhl-predicate-links-p (node pred)
  "[Cyc] Accessor: whether NODE has any forward sbhl links in PRED / *sbhl-module*"
  (sbhl-check-type pred sbhl-predicate-p)
  (let* ((module (get-sbhl-module pred))
         (direction-link (get-sbhl-graph-link node module)))
    (when direction-link
      (if (sbhl-module-directed-links? module)
          (and (sbhl-directed-link-predicate-links direction-link) t)
          (and (sbhl-undirected-link-links direction-link) t)))))

(defun get-sbhl-directed-mt-links (directed-link direction)
  "[Cyc] Accessor: the mt-links in the DIRECTION field of DIRECTED-LINK"
  (cond
    ((eq direction (get-sbhl-forward-directed-direction))
     (sbhl-directed-link-predicate-links directed-link))
    ((eq direction (get-sbhl-backward-directed-direction))
     (sbhl-directed-link-inverse-links directed-link))
    (t
     (sbhl-check-type direction sbhl-directed-direction-p)
     nil)))

(defun get-sbhl-undirected-mt-links (undirected-link)
  "[Cyc] Accessor: the mt-links in the links field of UNDIRECTED-LINK"
  (sbhl-undirected-link-links undirected-link))

(defun get-sbhl-mt-links (direction-link direction module)
  "[Cyc] Accessor: the sbhl-mt-links in the DIRECTION field of DIRECTION-LINK. Uses MODULE / *sbhl-module* to assess whether links are directed."
  (declare (type (satisfies sbhl-module-p) module))
  (if (sbhl-module-directed-links? module)
      (get-sbhl-directed-mt-links direction-link direction)
      (get-sbhl-undirected-mt-links direction-link)))

(defun set-sbhl-directed-link (directed-link direction value)
  "[Cyc] Modifier: sets the DIRECTION field of DIRECTED-LINK to be VALUE"
  (sbhl-check-type directed-link sbhl-directed-link-p)
  (sbhl-check-type direction sbhl-directed-direction-p)
  (when value
    (sbhl-check-type value sbhl-mt-links-object-p))
  (cond
    ((eq direction (get-sbhl-forward-directed-direction))
     (setf (sbhl-directed-link-predicate-links directed-link) value))
    ((eq direction (get-sbhl-backward-directed-direction))
     (setf (sbhl-directed-link-inverse-links directed-link) value)))
  nil)

(defun set-sbhl-undirected-link (undirected-link value)
  "[Cyc] Modifier: sets the links field of UNDIRECTED-LINK to be VALUE. Ensures DIRECTION is :link"
  (sbhl-check-type undirected-link sbhl-undirected-link-p)
  (when value
    (sbhl-check-type value sbhl-mt-links-object-p))
  (setf (sbhl-undirected-link-links undirected-link) value)
  nil)

(defun set-sbhl-direction-link (direction-link direction value module)
  "[Cyc] Modifier: sets the DIRECTION field of DIRECTION-LINK to be VALUE. Uses MODULE / *sbhl-module* to assess whether links are directed."
  (declare (type (satisfies sbhl-module-p) module))
  (if (sbhl-module-directed-links? module)
      (set-sbhl-directed-link direction-link direction value)
      (set-sbhl-undirected-link direction-link value))
  nil)

(defun remove-sbhl-direction-link (direction-link direction module)
  "[Cyc] Modifier: sets the DIRECTION field of DIRECTION-LINK to NIL."
  (declare (type (satisfies sbhl-module-p) module))
  (set-sbhl-direction-link direction-link direction nil module)
  nil)

(defun create-sbhl-mt-links (mt tv-links)
  "[Cyc] Constructor: returns sbhl-mt-links with an entry with key MT and value TV-LINKS"
  (sbhl-check-type tv-links sbhl-tv-links-object-p)
  (sbhl-check-type mt sbhl-mt-object-p)
  (let ((mt-links (make-hash-table :test #'equal)))
    (setf (gethash mt mt-links) tv-links)
    mt-links))

(defun sbhl-mt-links-object-p (object)
  "[Cyc] Accessor: whether OBJECT is a dictionary (hash-table in our port)."
  (hash-table-p object))

;; (defun sbhl-wf-mt-links-p (arg1)) -- commented declareFunction, no body
;; (defun get-sbhl-graph-mt-links (arg1 arg2 arg3)) -- commented declareFunction, no body
;; (defun get-sbhl-graph-link-mts (arg1 arg2 arg3)) -- commented declareFunction, no body

(defun get-sbhl-tv-links (mt-links mt)
  "[Cyc] Accessor: the tv-links structure after hashing on MT within MT-LINKS"
  (gethash mt mt-links))

(defun set-sbhl-mt-links (mt-links mt tv-links)
  "[Cyc] Modifier: sets the value corresponding to key MT in MT-LINKS to be TV-LINKS"
  (if tv-links
      (progn
        (sbhl-check-type tv-links sbhl-tv-links-object-p)
        (sbhl-check-type mt sbhl-mt-object-p)
        (setf (gethash mt mt-links) tv-links))
      (remhash mt mt-links))
  nil)

;; (defun remove-sbhl-mt-link-from-graph (arg1 arg2 arg3 arg4)) -- commented declareFunction, no body
;; (defun remove-sbhl-mt-link-from-relevant-directions (arg1 arg2 arg3)) -- commented declareFunction, no body

(defun remove-sbhl-mt-link (mt-links mt)
  "[Cyc] Modifier: removes data from the MT slot of MT-LINKS."
  (sbhl-check-type mt-links sbhl-mt-links-object-p)
  (sbhl-check-type mt sbhl-mt-object-p)
  (remhash mt mt-links)
  nil)

(defun create-sbhl-tv-links (truth node)
  "[Cyc] Constructor: returns new sbhl-truth-value-link with value at TRUTH set to '(NODE)"
  (sbhl-check-type truth sbhl-link-truth-value-p)
  (sbhl-check-type node sbhl-node-object-p)
  (let ((tv-links (make-hash-table :test #'eq)))
    (push-onto-sbhl-tv-links tv-links truth node)
    tv-links))

(defun sbhl-tv-links-object-p (object)
  "[Cyc] Accessor: whether OBJECT is a dictionary (hash-table in our port)."
  (hash-table-p object))

;; (defun sbhl-wf-tv-links-p (arg1)) -- commented declareFunction, no body
;; (defun get-sbhl-graph-tv-links (arg1 arg2 arg3 arg4)) -- commented declareFunction, no body

(defun get-sbhl-link-nodes (tv-links truth)
  "[Cyc] Accessor: the list within the value at TRUTH in TV-LINKS"
  (gethash truth tv-links))

(defun member-of-tv-links? (node truth tv-links)
  "[Cyc] Accessor: whether NODE is a member of TV-LINKS corresponding to TRUTH."
  (when (hash-table-p tv-links)
    (member? node (get-sbhl-link-nodes tv-links truth))))

;; (defun any-sbhl-true-link-nodes-p (arg1)) -- commented declareFunction, no body
;; (defun set-sbhl-tv-links (arg1 arg2 arg3)) -- commented declareFunction, no body

(defun push-onto-sbhl-tv-links (tv-links truth node)
  "[Cyc] Modifier: pushes NODE onto head of value at TRUTH in TV-LINKS."
  (sbhl-check-type tv-links sbhl-tv-links-object-p)
  (sbhl-check-type truth sbhl-link-truth-value-p)
  (sbhl-check-type node sbhl-node-object-p)
  (push node (gethash truth tv-links))
  tv-links)

(defun remove-sbhl-tv-link-node (tv-links truth node)
  "[Cyc] Modifier: removes NODE from the links corresponding to TRUTH within TV-LINKS."
  (sbhl-check-type tv-links sbhl-tv-links-object-p)
  (sbhl-check-type truth sbhl-link-truth-value-p)
  (sbhl-check-type node sbhl-node-object-p)
  (let ((nodes (gethash truth tv-links)))
    (setf (gethash truth tv-links) (delete node nodes :count 1)))
  tv-links)

(defun remove-sbhl-tv-link (tv-links truth)
  "[Cyc] Modifier: removes data corresponding to TRUTH within TV-LINKS."
  (sbhl-check-type tv-links sbhl-tv-links-object-p)
  (sbhl-check-type truth sbhl-link-truth-value-p)
  (remhash truth tv-links)
  nil)
