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

;; Reconstructed macro. Evidence: $list0=(VAR &BODY BODY), $sym1$CLET,
;; $list2=(*GHL-TABLE*). Binds VAR to the current *ghl-table* value.
(defmacro with-ghl-table-var (var &body body)
  `(let ((,var *ghl-table*))
     ,@body))

;; Reconstructed macro. Evidence: $list3=(NAME &BODY BODY),
;; $list4=((*GHL-TABLE* (GHL-INSTANTIATE-NEW-SPACE))), $sym5$WITH-GHL-TABLE-VAR.
;; Creates a new GHL space, binds *ghl-table* to it, then binds NAME to that space.
(defmacro with-new-ghl-table-named (name &body body)
  `(let ((*ghl-table* (ghl-instantiate-new-space)))
     (with-ghl-table-var ,name
       ,@body)))

;; Reconstructed macro. Evidence: shares $list4=((*GHL-TABLE* (GHL-INSTANTIATE-NEW-SPACE)))
;; with WITH-NEW-GHL-TABLE-NAMED but has no NAME parameter. Just binds *ghl-table*
;; to a new space.
(defmacro with-new-ghl-table (&body body)
  `(let ((*ghl-table* (ghl-instantiate-new-space)))
     ,@body))

;; Reconstructed macro. Evidence: $list6=((KEY-VAR MARKING-VAR) &BODY BODY),
;; $sym7$CDOHASH, $list2=(*GHL-TABLE*). Iterates over the *ghl-table* hash table.
(defmacro do-ghl-marking-table ((key-var marking-var) &body body)
  `(dohash (,key-var ,marking-var *ghl-table*)
     ,@body))

;; (defun ghl-marking-table-marked-nodes () ...) -- active declareFunction, no body
;; (defun ghl-instantiate-new-space () ...) -- active declareFunction, body below

(defun ghl-instantiate-new-space ()
  (make-hash-table :size 200))

(defun get-ghl-marking (search node)
  (gethash node (ghl-space search)))

;; (defun get-ghl-goal-marking (search node) ...) -- active declareFunction, no body
;; (defun ghl-marked-node-p (search node) ...) -- active declareFunction, no body
;; (defun ghl-goal-marked-node-p (search node) ...) -- active declareFunction, no body
;; (defun ghl-node-marked-in-space-p (node space) ...) -- active declareFunction, no body

(defun ghl-mark-node-in-space (node mark space)
  (setf (gethash node space) mark)
  nil)

(defun ghl-mark-node (search node mark)
  (let ((space (ghl-space search)))
    (ghl-mark-node-in-space node mark space))
  nil)

;; (defun ghl-goal-mark-node (search node mark) ...) -- active declareFunction, no body
;; (defun ghl-mark-node-in-ghl-table (node mark) ...) -- active declareFunction, no body
;; (defun ghl-unmark-node (search node) ...) -- active declareFunction, no body
;; (defun ghl-node-with-equal-or-shallower-depth-p (search node depth) ...) -- active declareFunction, no body
;; (defun ghl-goal-node-with-equal-or-shallower-depth-p (search node depth) ...) -- active declareFunction, no body
;; (defun prepend-to-ghl-marking-state (search node new-state) ...) -- active declareFunction, no body
;; (defun ghl-goal-mark-node-as-searched (search node) ...) -- active declareFunction, no body
;; (defun ghl-marked-cardinality (search) ...) -- active declareFunction, no body

(defparameter *ghl-table* nil)
