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


;; (defun sbhl-premark-goal-nodes (node) ...) -- commented declareFunction, no body

(defun sbhl-premark-direction (module)
  "[Cyc] @Hack assumes sbhl modules are cheaper to search forward"
  (declare (ignore module))
  (get-sbhl-forward-search-direction))

(defun sbhl-premark-gather-nodes (node)
  "[Cyc] Used for initial marking for boolean disjoins searches. Applies @see sbhl-sweep, upon NODE, with current *sbhl-module*, forward direction, true search tv, in @see *sbhl-gather-space*, with map-fn sbhl-check-cutoff."
  (sbhl-sweep (get-sbhl-module)
              (sbhl-search-direction-to-link-direction
               (sbhl-premark-direction (get-sbhl-module))
               (get-sbhl-module))
              (sbhl-search-true-tv)
              *sbhl-gather-space*
              'sbhl-check-cutoff
              node
              (sbhl-unmarking-search-p))
  nil)

;; (defun sbhl-gather-premarked-justifications (node) ...) -- commented declareFunction, no body

(defun sbhl-mark-all-forward-true-nodes (module node &optional mt tv)
  "[Cyc] Modifier. Marks the forward true closure of NODE in MODULE with relevance determined by MT and TV. performs this marking in current *sbhl-space* and possibly *sbhl-gather-space*, depending on the search behavior that it binds (as determined by @see determine-sbhl-search-behavior)."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module)
        (*sbhl-suspend-new-spaces?* t))
    (possibly-with-sbhl-mt-relevance (mt)
      (let ((*sbhl-tv* (or tv (get-sbhl-true-tv)))
            (*relevant-sbhl-tv-function* (if tv
                                             'relevant-sbhl-tv-is-general-tv
                                             *relevant-sbhl-tv-function*)))
        (when tv
          (sbhl-check-type tv sbhl-true-tv-p))
        (let ((*sbhl-search-truth* #$True-JustificationTruth)
              (*sbhl-search-direction* (get-sbhl-forward-search-direction))
              (*sbhl-link-direction* (get-sbhl-module-forward-direction (get-sbhl-module))))
          (let ((source (sbhl-new-space-source)))
            (let ((*sbhl-space* (if (eq source :old)
                                    *sbhl-space*
                                    (sbhl-get-new-space source))))
              (unwind-protect
                   (let ((*sbhl-gather-space* (if (eq source :old)
                                                  *sbhl-gather-space*
                                                  (sbhl-get-new-space source))))
                     (unwind-protect
                          (let ((*sbhl-finished?* nil)
                                (*sbhl-stop-search-path?* nil)
                                (*sbhl-search-parent-marking* nil)
                                (*sbhl-nodes-previous-marking* nil)
                                (*genl-inverse-mode-p* nil))
                            (with-rw-read-lock (*sbhl-rw-lock*)
                              (let* ((*sbhl-search-behavior*
                                      (determine-sbhl-search-behavior
                                       (get-sbhl-search-module)
                                       (get-sbhl-search-direction)
                                       (get-sbhl-tv)))
                                    (*sbhl-terminating-marking-space*
                                      (determine-sbhl-terminating-marking-space
                                       *sbhl-search-behavior*)))
                                (sbhl-mark-closure-as-marked node))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*)))))))))
  nil)

;; (defun sbhl-mark-all-backward-true-nodes (module node &optional mt tv) ...) -- commented declareFunction, no body

(defun sbhl-mark-closure-as-marked (node)
  "[Cyc] Modifier: marks all nodes accessible to NODE as marked, in the current search space."
  (if (or (suspend-sbhl-type-checking?)
          (apply-sbhl-module-type-test node (get-sbhl-module)))
      (let ((*sbhl-consider-node-fn* 'sbhl-check-cutoff))
        (apply-sbhl-search-behavior (get-sbhl-search-behavior) node))
      (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                 node (get-sbhl-type-test (get-sbhl-module))))
  nil)

;; (defun sbhl-mark-closure-in-space (node space) ...) -- commented declareFunction, no body

(defun sbhl-mark-forward-true-nodes-in-space (module node &optional
                                                (space *sbhl-space*)
                                                (gather-space *sbhl-gather-space*))
  "[Cyc] Modifier: Binds *sbhl-space* to SPACE and *sbhl-gather-space* to GATHER-SPACE and performs @see sbhl-mark-all-forward-true-nodes."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((*sbhl-space* space)
        (*sbhl-gather-space* gather-space)
        (*sbhl-suspend-new-spaces?* t))
    (sbhl-mark-all-forward-true-nodes module node))
  nil)

;; (defun sbhl-mark-backward-true-nodes-in-space (module node &optional space gather-space) ...) -- commented declareFunction, no body
;; (defun sbhl-mark-proper-all-forward-true-nodes (module node &optional mt tv) ...) -- commented declareFunction, no body

(defun sbhl-mark-proper-closure-as-marked (node)
  "[Cyc] Modifier: marks all nodes properly accessible to NODE as marked, thereby
only marking NODE if it is part of a cycle."
  (if (sbhl-transitive-module-p (get-sbhl-search-module))
      (sbhl-step (get-sbhl-search-module)
                 (get-sbhl-link-direction)
                 (get-sbhl-tv)
                 *sbhl-space*
                 'sbhl-mark-closure-as-marked
                 node
                 t)
      (sbhl-mark-closure-as-marked node))
  nil)

;; (defun sbhl-unmark-all-marked-forward-true-nodes (module node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-all-marked-backward-true-nodes (module node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-marked-closure (node) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-initialized-marked-closure (node) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-proper-marked-closure (node) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-all-backward-true-nodes-and-map (node fn) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-marked-closure-and-gather (node) ...) -- commented declareFunction, no body

(defun sbhl-unmark-marked-closure-and-gather-if (node function)
  "[Cyc] Modifier: unmarks all marked nodes accessible to NODE and pushes them onto
the result if they pass the test FUNCTION."
  (let ((*sbhl-unmarking-search-p* t)
        (*sbhl-compose-fn* function)
        (*sbhl-consider-node-fn* 'sbhl-push-onto-result-if))
    (if (sbhl-module-indicates-predicate-search-p (get-sbhl-search-module))
        (dolist (pred (sbhl-marked-with node))
          (let ((*sbhl-add-unmarked-node-to-result-test*
                  (get-sbhl-add-node-to-result-test (get-sbhl-module pred)))
                (*genl-inverse-mode-p* (eq pred #$genlInverse)))
            (apply-sbhl-search-behavior (get-sbhl-search-behavior) node)))
        (apply-sbhl-search-behavior (get-sbhl-search-behavior) node)))
  nil)

;; (defun sbhl-unmark-marked-closure-and-mark-in-space (node space) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-marked-closure-and-unmark-in-space (node space) ...) -- commented declareFunction, no body
;; (defun sbhl-mark-cyclic-closure (node) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-cyclic-closure (node) ...) -- commented declareFunction, no body
;; (defun sbhl-mark-max-true-disjoins (module node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun sbhl-mark-extremal-disjoins (node) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-max-true-disjoins (module node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-extremal-disjoins (node) ...) -- commented declareFunction, no body
;; (defun determine-sbhl-mark-between-consider-fn () ...) -- commented declareFunction, no body
;; (defun sbhl-mark-forward-true-nodes-between-and-all-their-inherited-nodes (module node1 node2 &optional mt tv) ...) -- commented declareFunction, no body
;; (defun sbhl-unmark-marked-closure-and-target-mark-closure (node) ...) -- commented declareFunction, no body
;; (defun sbhl-mark-closure-in-target-space (node) ...) -- commented declareFunction, no body
;; (defun sbhl-mark-node-and-instances-in-target-space (node) ...) -- commented declareFunction, no body
;; (defun sbhl-record-closure (module node direction &optional mt tv) ...) -- commented declareFunction, no body
;; (defun sbhl-record-all-forward-true-nodes (module node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun sbhl-record-all-backward-true-nodes (module node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun sbhl-record-max-true-disjoins (module node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun sbhl-unrecord-max-true-disjoins (module node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun sbhl-unrecord-all-recorded-forward-true-nodes (module node &optional mt tv) ...) -- commented declareFunction, no body
;; (defun unrecord-all-superiors-as-unsearched-ignore-arg2 (node &optional arg2) ...) -- commented declareFunction, no body
;; (defun sbhl-record-node (node &optional arg) ...) -- commented declareFunction, no body
;; (defun sbhl-recorded-node-p (node &optional arg) ...) -- commented declareFunction, no body
;; (defun sbhl-unrecorded-node-p (node &optional arg) ...) -- commented declareFunction, no body
;; (defun sbhl-record-proper-all-forward-true-nodes (module node &optional mt tv) ...) -- commented declareFunction, no body
