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

(defun get-sbhl-marking-state (node &optional (space *sbhl-space*))
  "[Cyc] Accessor: returns the marking state of NODE within SPACE / *sbhl-space*"
  (gethash node space))

(defun sbhl-marked-with (node &optional (space *sbhl-space*))
  "[Cyc] Accessor: returns NODE's current marking state (usually boolean)."
  (get-sbhl-marking-state node space))

;; (defun sbhl-marked-node-p (arg1 &optional arg2)) -- commented declareFunction, no body

(defun sbhl-marked-p (marking)
  "[Cyc] Accessor: whether MARKING has a non-NIL marking state."
  (and marking t))

;; (defun sbhl-unmarked-p (arg1)) -- commented declareFunction, no body
;; (defun sbhl-marking-contains-searcher? (arg1 arg2)) -- commented declareFunction, no body
;; (defun sbhl-marking-contains-all-searchers? (arg1 arg2)) -- commented declareFunction, no body
;; (defun sbhl-temporal-increment ()) -- commented declareFunction, no body
;; (defun sbhl-temporal-tag-increment (arg1)) -- commented declareFunction, no body
;; (defun sbhl-nodes-marking-non-negative-p (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-current-marking-exceeds-pending-marking-or-marking-threshold-p (arg1)) -- commented declareFunction, no body
;; (defun sbhl-nodes-mark-exceeds-temporal-threshold-p (arg1)) -- commented declareFunction, no body
;; (defun sbhl-temporality-path-termination-for-searching-marked-nodes-p (arg1)) -- commented declareFunction, no body
;; (defun sbhl-current-temporal-node-not-yet-considered-p ()) -- commented declareFunction, no body

(defun sbhl-predicate-path-termination-p (marking)
  "[Cyc] Accessor: whether MARKING indicates path termination for predicate search"
  (if (genl-inverse-mode-p)
      (or (genl-inverse-marking-p marking)
          (genl-preds-and-genl-inverse-marking-p marking))
      (or (genl-preds-marking-p marking)
          (genl-preds-and-genl-inverse-marking-p marking))))

(defun set-sbhl-marking-state (node value &optional (space *sbhl-space*))
  "[Cyc] Modifier: sets the hash slot for NODE in SPACE / *sbhl-space* to VALUE"
  (setf (gethash node space) value)
  nil)

(defun set-sbhl-marking-state-to-marked (node &optional (space *sbhl-space*))
  "[Cyc] Modifier: sets the hash slot for NODE in *sbhl-space* / SPACE to T."
  (set-sbhl-marking-state node t space)
  nil)

(defun set-sbhl-marking-state-to-unmarked (node &optional (space *sbhl-space*))
  "[Cyc] Modifier: sets the hash slot for NODE in *sbhl-space* to NIL."
  (set-sbhl-marking-state node nil space)
  nil)

;; (defun sbhl-mark-node (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun adjoin-to-sbhl-marking-state (arg1 arg2 &optional arg3)) -- commented declareFunction, no body
;; (defun prepend-to-sbhl-marking-state (arg1 arg2 &optional arg3)) -- commented declareFunction, no body
;; (defun remove-from-sbhl-marking-state (arg1 arg2 &optional arg3)) -- commented declareFunction, no body
;; (defun increment-sbhl-marking-state (arg1 arg2 &optional arg3)) -- commented declareFunction, no body
;; (defun increment-sbhl-marking-state-by-zero (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun increment-sbhl-marking-state-by-minus-one (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun increment-sbhl-marking-state-by-one (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun increment-sbhl-marking-state-by-two (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun set-sbhl-marking-state-to-zero (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun set-sbhl-marking-state-to-depth (arg1 arg2 &optional arg3)) -- commented declareFunction, no body
;; (defun sbhl-node-marking-greater-than-depth-p (arg1 arg2 &optional arg3)) -- commented declareFunction, no body

(defun sbhl-predicate-marking-fn (node &optional (space *sbhl-space*))
  "[Cyc] Modifier: adds either #$genlPreds or #$genlInverse to NODE's marking, depending on genl-inverse-mode-p"
  (if (genl-inverse-mode-p)
      (genl-inverse-marking-fn node space)
      (genl-preds-marking-fn node space))
  nil)

(defun genl-preds-marking-fn (node &optional (space *sbhl-space*))
  "[Cyc] Modifier: adds #$genlPreds to NODE's marking."
  (let ((current-marking (sbhl-marked-with node space)))
    (cond
      ((null current-marking)
       (set-sbhl-marking-state node *sbhl-genl-preds-marking* space))
      ((eq current-marking *sbhl-genl-inverse-marking*)
       (set-sbhl-marking-state node *sbhl-genl-preds-and-genl-inverse-marking* space))))
  nil)

(defun genl-inverse-marking-fn (node &optional (space *sbhl-space*))
  "[Cyc] Modifier: adds #$genlInverse to NODE's marking."
  (let ((current-marking (sbhl-marked-with node)))
    (cond
      ((null current-marking)
       (set-sbhl-marking-state node *sbhl-genl-inverse-marking* space))
      ((eq current-marking *sbhl-genl-preds-marking*)
       (set-sbhl-marking-state node *sbhl-genl-preds-and-genl-inverse-marking* space))))
  nil)

;; (defun sbhl-predicate-unmarking-fn (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun genl-preds-unmarking-fn (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun genl-inverse-unmarking-fn (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-mark-node-in-precompute-space (arg1)) -- commented declareFunction, no body
;; (defun sbhl-node-marked-precompute-goal-p (arg1)) -- commented declareFunction, no body
;; (defun set-sbhl-boolean-precompute-goal-conditions (arg1)) -- commented declareFunction, no body

(defun sbhl-search-path-termination-p (node &optional (space *sbhl-space*))
  "[Cyc] Accessor: applies *sbhl-module* defined path termination determining fn. Relies on current context of SPACE / *sbhl-space*."
  (when (sbhl-check-for-goal-marking-p)
    ;; TODO - missing-larkc 2084 (goal marking check) and 2088 (goal marking action)
    (when (missing-larkc 2084)
      (missing-larkc 2088)
      (return-from sbhl-search-path-termination-p t)))
  (sbhl-path-terminating-mark-p node space))

(defun sbhl-path-terminating-mark-p (node &optional (space *sbhl-space*))
  "[Cyc] Accessor: applies *sbhl-module* defined path termination determining fn. Relies on current context of SPACE / *sbhl-space*."
  (let ((path-terminating-mark?-fn (get-sbhl-path-terminating-mark?-fn (get-sbhl-module))))
    (case path-terminating-mark?-fn
      (sbhl-marked-p
       (sbhl-marked-p (sbhl-marked-with node space)))
      (sbhl-predicate-path-termination-p
       (sbhl-predicate-path-termination-p (sbhl-marked-with node space)))
      (sbhl-nodes-mark-exceeds-temporal-threshold-p
       ;; TODO - missing-larkc 2085
       (missing-larkc 2085))
      (otherwise
       (funcall path-terminating-mark?-fn node)))))

;; (defun sbhl-path-termination-marking-p (arg1)) -- commented declareFunction, no body

(defun sbhl-marked-in-terminating-space-p (node)
  "[Cyc] Accessor: applies *sbhl-module* defined path-termination-function to NODE's marking within terminating space."
  (sbhl-search-path-termination-p node *sbhl-terminating-marking-space*))

(defun sbhl-marked-in-target-space-p (node)
  "[Cyc] Accessor: applies *sbhl-module* defined path-termination-function to NODE's marking within target space."
  (sbhl-search-path-termination-p node *sbhl-target-space*))

(defun sbhl-mark-node-marked (node &optional (space *sbhl-space*))
  "[Cyc] Modifier: applies *sbhl-module* defined marking fn. Relies on current context of *sbhl-space*."
  (let ((marking-fn (get-sbhl-marking-fn (get-sbhl-module))))
    ;; TODO - isn't this equivalent to funcall?
    (case marking-fn
      (set-sbhl-marking-state-to-marked
       (set-sbhl-marking-state-to-marked node space))
      (sbhl-predicate-marking-fn
       (sbhl-predicate-marking-fn node space))
      (increment-sbhl-marking-state-by-zero
       (missing-larkc 2067))
      (increment-sbhl-marking-state-by-one
       (missing-larkc 2065))
      (increment-sbhl-marking-state-by-two
       (missing-larkc 2066))
      (increment-sbhl-marking-state-by-minus-one
       (missing-larkc 2064))
      (otherwise
       (funcall marking-fn node))))
  nil)

(defun sbhl-mark-node-unmarked (node &optional (space *sbhl-space*))
  "[Cyc] Modifier: applies *sbhl-module* defined unmarking fn. Relies on current context of *sbhl-space*."
  (let ((unmarking-fn (get-sbhl-unmarking-fn (get-sbhl-module))))
    ;; TODO - isn't this equivalent to funcall?
    (case unmarking-fn
      (set-sbhl-marking-state-to-unmarked
       (set-sbhl-marking-state-to-unmarked node space))
      (genl-preds-unmarking-fn
       (missing-larkc 2059))
      (genl-inverse-unmarking-fn
       (missing-larkc 2056))
      (otherwise
       (funcall unmarking-fn node))))
  nil)

;; (defun sbhl-mark-in-target-space (arg1)) -- commented declareFunction, no body
;; (defun sbhl-mark-in-target-gather-space (arg1)) -- commented declareFunction, no body
;; (defun sbhl-apply-mark-in-space (arg1)) -- commented declareFunction, no body
;; (defun sbhl-apply-unmark-in-space (arg1)) -- commented declareFunction, no body
;; (defun sbhl-generational-search-path-termination-p (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-marking-generation (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-generational-mark-node-marked (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-generational-predicate-marking-fn (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun genl-preds-generational-marking-fn (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun genl-inverse-generational-marking-fn (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-any-nodes-marked? (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-all-nodes-marked? (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-any-nodes-unmarked? (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-all-nodes-unmarked? (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun all-unsearched? (arg1)) -- commented declareFunction, no body
;; (defun sbhl-all-marked-nodes (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-all-unmarked-nodes (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-marked-nodes (&optional arg1)) -- commented declareFunction, no body
;; (defun sbhl-mark-all-nodes-marked (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun sbhl-mark-all-nodes-unmarked (arg1 &optional arg2)) -- commented declareFunction, no body

(defun sbhl-mark-nodes-in-target-space (nodes)
  "[Cyc] Modifier: marks each of NODES in *sbhl-target-space*"
  (dolist (node nodes)
    (sbhl-mark-node-marked node *sbhl-target-space*))
  nil)

(defun sbhl-mark-nodes-in-target-space-gp (nodes)
  "[Cyc] Modifier: marks each of NODES in *sbhl-target-space* with genl-inverse mode flipping"
  (let ((*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                   (not *genl-inverse-mode-p*)
                                   *genl-inverse-mode-p*)))
    (dolist (node nodes)
      (sbhl-mark-node-marked node *sbhl-target-space*)))
  nil)

;; (defun sbhl-space-p (arg1)) -- commented declareFunction, no body
;; (defun list-of-sbhl-space-p (arg1)) -- commented declareFunction, no body

(defun clear-sbhl-space (&optional (space *sbhl-space*))
  "[Cyc] Modifier: clears space"
  (clrhash space)
  nil)

;; (defun empty-sbhl-space-p (arg1)) -- commented declareFunction, no body
;; (defun sbhl-marked-cardinality (arg1)) -- commented declareFunction, no body
;; (defun sbhl-space-keys (arg1)) -- commented declareFunction, no body
