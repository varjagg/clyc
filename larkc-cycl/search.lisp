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

;; SEARCH-STRUC defstruct — generic search state container with function slots
(defstruct (search-struc (:print-function print-search))
  tree
  leaves
  goals
  no-leaves-p-func
  next-node-func
  goal-p-func
  add-goal-func
  options-func
  expand-func
  add-node-func
  too-deep-func
  state
  print-func
  limbo
  current-node)

(defconstant *dtp-search-struc* 'search-struc)

(defun search-struc-print-function-trampoline (object stream)
  "[Cyc] Trampoline for printing search-struc objects."
  (missing-larkc 12679))

;; (defun search-struc-p (object) ...) -- no body, commented declareFunction
;; (defun search-tree (search-struc) ...) -- no body, struct accessor
;; (defun search-leaves (search-struc) ...) -- no body, struct accessor
;; (defun search-goals (search-struc) ...) -- no body, struct accessor
;; (defun search-no-leaves-p-func (search-struc) ...) -- no body, struct accessor
;; (defun search-next-node-func (search-struc) ...) -- no body, struct accessor
;; (defun search-goal-p-func (search-struc) ...) -- no body, struct accessor
;; (defun search-add-goal-func (search-struc) ...) -- no body, struct accessor
;; (defun search-options-func (search-struc) ...) -- no body, struct accessor
;; (defun search-expand-func (search-struc) ...) -- no body, struct accessor
;; (defun search-add-node-func (search-struc) ...) -- no body, struct accessor
;; (defun search-too-deep-func (search-struc) ...) -- no body, struct accessor
;; (defun search-state (search-struc) ...) -- no body, struct accessor
;; (defun search-print-func (search-struc) ...) -- no body, struct accessor
;; (defun search-limbo (search-struc) ...) -- no body, struct accessor
;; (defun search-current-node (search-struc) ...) -- no body, struct accessor
;; (defun _csetf-search-tree (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-leaves (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-goals (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-no-leaves-p-func (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-next-node-func (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-goal-p-func (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-add-goal-func (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-options-func (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-expand-func (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-add-node-func (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-too-deep-func (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-state (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-print-func (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-limbo (search-struc value) ...) -- no body, struct setter
;; (defun _csetf-search-current-node (search-struc value) ...) -- no body, struct setter
;; (defun make-search-struc (&rest args) ...) -- no body, struct constructor
;; (defun print-search (search-struc stream depth) ...) -- no body
;; (defun make-static-search-struc () ...) -- no body
;; (defun init-search-struc (search-struc) ...) -- no body
;; (defun free-search-struc-p (search-struc) ...) -- no body
;; (defun free-search-struc (search-struc) ...) -- no body
;; (defun get-search-struc () ...) -- no body
;; (defun new-search (no-leaves-p-func next-node-func goal-p-func add-goal-func too-deep-func options-func expand-func add-node-func &optional search-state print-func) ...) -- no body

(deflexical *search-struc-free-list* nil
  "[Cyc] Free list for SEARCH-STRUC objects.")
(deflexical *search-struc-free-lock* (bt:make-lock "SEARCH-STRUC resource lock")
  "[Cyc] Lock for SEARCH-STRUC object free list.")

;; SEARCH-NODE defstruct — node in a search tree
(defstruct (search-node (:conc-name "SNODE-")
                        (:print-function print-snode))
  search
  parent
  children
  depth
  options
  state)

(defconstant *dtp-search-node* 'search-node)

(defun search-node-print-function-trampoline (object stream)
  "[Cyc] Trampoline for printing search-node objects."
  (missing-larkc 12680))

;; (defun search-node-p (object) ...) -- no body, commented declareFunction
;; (defun snode-search (search-node) ...) -- no body, struct accessor
;; (defun snode-parent (search-node) ...) -- no body, struct accessor
;; (defun snode-children (search-node) ...) -- no body, struct accessor
;; (defun snode-depth (search-node) ...) -- no body, struct accessor
;; (defun snode-options (search-node) ...) -- no body, struct accessor
;; (defun snode-state (search-node) ...) -- no body, struct accessor
;; (defun _csetf-snode-search (search-node value) ...) -- no body, struct setter
;; (defun _csetf-snode-parent (search-node value) ...) -- no body, struct setter
;; (defun _csetf-snode-children (search-node value) ...) -- no body, struct setter
;; (defun _csetf-snode-depth (search-node value) ...) -- no body, struct setter
;; (defun _csetf-snode-options (search-node value) ...) -- no body, struct setter
;; (defun _csetf-snode-state (search-node value) ...) -- no body, struct setter
;; (defun make-search-node (&rest args) ...) -- no body, struct constructor
;; (defun print-snode (search-node stream depth) ...) -- no body
;; (defun make-static-search-node () ...) -- no body
;; (defun init-search-node (search-node) ...) -- no body
;; (defun free-search-node-p (search-node) ...) -- no body
;; (defun free-search-node (search-node) ...) -- no body
;; (defun get-search-node () ...) -- no body
;; (defun free-entire-search-node (search-node &optional reclaim-search-node-function) ...) -- no body
;; (defun dead-end-node-p (search-node) ...) -- no body
;; (defun reclaim-search-node (search-node) ...) -- no body

(deflexical *search-node-free-list* nil
  "[Cyc] Free list for SEARCH-NODE objects.")
(deflexical *search-node-free-lock* (bt:make-lock "SEARCH-NODE resource lock")
  "[Cyc] Lock for SEARCH-NODE object free list.")

(defparameter *reclaim-dead-end-search-nodes* t
  "[Cyc] Whether to reclaim dead end search nodes.")
(defparameter *dead-end-node-function* 'dead-end-node-p)
(defparameter *reclaim-dead-end-node-function* 'reclaim-search-node)

(defparameter *within-generic-search* nil)
(defparameter *interrupt-generic-search* nil)

;; (defun interrupt-generic-search () ...) -- no body
;; (defun abort-generic-search () ...) -- no body

;; do-generic-search macro — reconstructed from Internal Constants evidence:
;;   $list93 = ((REASON SEARCH &KEY NUMBER-CUT TIME-CUT DEPTH-CUT) NO-LEAVES-P-FUNC
;;              NEXT-NODE-FUNC GOAL-P-FUNC ADD-GOAL-FUNC TOO-DEEP-FUNC OPTIONS-FUNC
;;              EXPAND-FUNC ADD-NODE-FUNC)
;;   $list94 = (:NUMBER-CUT :TIME-CUT :DEPTH-CUT)
;;   $kw95 = :ALLOW-OTHER-KEYS
;;   Uninterneds: NUMBER, TIME, DEPTH-LIMIT-CROSSED, ABORTED, NEXT, NEW-LEAVES,
;;                PREVIOUS-GOALS, NEW-GOALS
;; The macro wraps generic-search with cutoff handling and iteration bindings.
;; Full body reconstruction not possible without call-site evidence; stub provided.
(defmacro do-generic-search (((reason search &key number-cut time-cut depth-cut
                                      &allow-other-keys)
                               no-leaves-p-func next-node-func goal-p-func
                               add-goal-func too-deep-func options-func
                               expand-func add-node-func)
                              &body body)
  ;; TODO: Reconstruct macro body. Arglist recovered from Internal Constants.
  ;; Body expansion unknown — need call-site evidence to reconstruct.
  ;; The macro likely binds REASON and SEARCH, calls generic-search with the
  ;; function arguments, and provides NUMBER-CUT/TIME-CUT/DEPTH-CUT bindings
  ;; for controlling search termination.
  (declare (ignore reason search number-cut time-cut depth-cut
                   no-leaves-p-func next-node-func goal-p-func add-goal-func
                   too-deep-func options-func expand-func add-node-func body))
  (error "do-generic-search: TODO macro body not yet reconstructed"))

;; (defun generic-search (search &optional number-cutoff time-cutoff depth-cutoff) ...) -- no body
;; (defun generic-search-reclaim-node (search-node) ...) -- no body
;; (defun generic-search-link-child-to-parent (child parent) ...) -- no body
;; (defun reset-search-node-state (search-node new-state) ...) -- no body
;; (defun new-search-node (search) ...) -- no body
;; (defun new-search-start-node (search) ...) -- no body
;; (defun register-search-start-node (search search-node) ...) -- no body
;; (defun add-search-start-node (search search-node) ...) -- no body
;; (defun remove-search-start-node (search search-node) ...) -- no body
;; (defun reconsider-limbo (search search-node) ...) -- no body
;; (defun valid-snode-options (search-node) ...) -- no body
;; (defun set-valid-snode-options (search-node options) ...) -- no body
;; (defun doomed-search-node-p (search-node) ...) -- no body
;; (defun mark-node-as-doomed (search-node) ...) -- no body
;; (defun search-current-path (search) ...) -- no body
;; (defun search-current-path-internal (search-node) ...) -- no body
;; (defun remaining-time-cutoff (elapsed time-cutoff) ...) -- no body
;; (defun search-size (search) ...) -- no body
;; (defun search-node-size (search-node) ...) -- no body

;; Setup
(toplevel
  (note-funcall-helper-function 'print-snode))
