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


(defun sbhl-all-forward-true-nodes (module node &optional mt tv)
  "[Cyc] @return listp; all forward true nodes accessible to NODE via MODULE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
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
                              (let ((*sbhl-search-behavior*
                                      (determine-sbhl-search-behavior
                                       (get-sbhl-search-module)
                                       (get-sbhl-search-direction)
                                       (get-sbhl-tv)))
                                    (*sbhl-terminating-marking-space*
                                      (determine-sbhl-terminating-marking-space
                                       *sbhl-search-behavior*))
                                    (*sbhl-consider-node-fn* 'sbhl-push-onto-result))
                                (setf result (sbhl-transitive-closure node)))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*))))))))
    result))

;; (defun sbhl-all-forward-false-nodes (module node &optional mt tv)) -- commented declareFunction (2 2), no body

(defun sbhl-all-backward-true-nodes (module node &optional mt tv)
  "[Cyc] @return listp; all backward true nodes accessible to NODE via MODULE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
    (possibly-with-sbhl-mt-relevance (mt)
      (let ((*sbhl-tv* (or tv (get-sbhl-true-tv)))
            (*relevant-sbhl-tv-function* (if tv
                                             'relevant-sbhl-tv-is-general-tv
                                             *relevant-sbhl-tv-function*)))
        (when tv
          (sbhl-check-type tv sbhl-true-tv-p))
        (let ((*sbhl-search-truth* #$True-JustificationTruth)
              (*sbhl-search-direction* (get-sbhl-backward-search-direction))
              (*sbhl-link-direction* (get-sbhl-module-backward-direction (get-sbhl-module))))
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
                              (let ((*sbhl-search-behavior*
                                      (determine-sbhl-search-behavior
                                       (get-sbhl-search-module)
                                       (get-sbhl-search-direction)
                                       (get-sbhl-tv)))
                                    (*sbhl-terminating-marking-space*
                                      (determine-sbhl-terminating-marking-space
                                       *sbhl-search-behavior*))
                                    (*sbhl-consider-node-fn* 'sbhl-push-onto-result))
                                (setf result (sbhl-transitive-closure node)))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*))))))))
    result))

;; (defun sbhl-all-backward-false-nodes (module node &optional mt tv)) -- commented declareFunction (2 2), no body

(defun sbhl-transitive-closure (node)
  "[Cyc] @return listp; the transitive closure of NODE with current search module,
direction, and truth."
  (let ((result nil))
    (let ((*sbhl-result* nil))
      (unwind-protect
           (if (or (suspend-sbhl-type-checking?)
                   (apply-sbhl-module-type-test node (get-sbhl-module)))
               (let ((*sbhl-unmarking-search-p* nil))
                 (apply-sbhl-search-behavior (get-sbhl-search-behavior) node))
               (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                          node (get-sbhl-type-test (get-sbhl-module))))
        (setf result *sbhl-result*)))
    result))

;; (defun sbhl-all-forward-true-nodes-with-prune (module node prune-fn &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-all-backward-true-nodes-with-prune (module node prune-fn &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-union-all-forward-true-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-union-all-backward-true-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-union-nodes-transitive-closures (nodes)) -- commented declareFunction (1 0), no body
;; (defun sbhl-gather-dead-end-nodes (node)) -- commented declareFunction (1 0), no body
;; (defun sbhl-extremes (nodes)) -- commented declareFunction (1 0), no body
;; (defun sbhl-leaf-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-root-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body

(defun sbhl-max-true-disjoins (module node &optional mt tv)
  "[Cyc] @return listp; the max/summary MODULE relations for NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
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
                              (let ((*sbhl-consider-node-fn* 'sbhl-push-onto-result)
                                    (*sbhl-result* nil))
                                (unwind-protect
                                     (if (or (suspend-sbhl-type-checking?)
                                             (apply-sbhl-module-type-test node (get-sbhl-module)))
                                         (setf result (sbhl-sweep-and-gather-disjoins node))
                                         (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                                                    node (get-sbhl-type-test (get-sbhl-module))))
                                  (setf result *sbhl-result*)))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*))))))))
    (setf result (sbhl-max-nodes (get-sbhl-reductions-module module) result mt tv))
    result))

;; (defun sbhl-min-asserted-false-disjoins (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-min-implied-false-disjoins (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-implied-min-false-disjoins (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-gather-first-true-disjoin (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-sample-leaf-nodes (module node &optional mt tv n)) -- commented declareFunction (2 3), no body
;; (defun sbhl-sample-different-leaf-nodes (module node n &optional mt tv n2)) -- commented declareFunction (3 3), no body
;; (defun sbhl-sample-extremal-nodes (module nodes &optional n)) -- commented declareFunction (2 1), no body

(defun sbhl-map-all-forward-true-nodes (module node function &optional mt tv)
  "[Cyc] Applies FUNCTION to each element of NODE's forward true transitive closure."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
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
                              (sbhl-check-type function function-spec-p)
                              (let ((*sbhl-search-behavior*
                                      (determine-sbhl-search-behavior
                                       (get-sbhl-search-module)
                                       (get-sbhl-search-direction)
                                       (get-sbhl-tv)))
                                    (*sbhl-terminating-marking-space*
                                      (determine-sbhl-terminating-marking-space
                                       *sbhl-search-behavior*))
                                    (*sbhl-compose-fn* function)
                                    (*sbhl-consider-node-fn* 'sbhl-apply-compose-fn)
                                    (*sbhl-search-type* :closure))
                                (if (or (suspend-sbhl-type-checking?)
                                        (apply-sbhl-module-type-test node (get-sbhl-module)))
                                    (apply-sbhl-search-behavior (get-sbhl-search-behavior) node)
                                    (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                                               node (get-sbhl-type-test (get-sbhl-module)))))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*)))))))))
  nil)

;; (defun sbhl-map-all-forward-true-nodes-if (module node function test &optional mt tv)) -- commented declareFunction (4 2), no body

(defun sbhl-map-and-mark-forward-true-nodes-in-space (module node fn &optional
                                                        (space *sbhl-space*)
                                                        (gather-space *sbhl-gather-space*))
  "[Cyc] Binds *sbhl-space* to SPACE and *sbhl-gather-space* to GATHER-SPACE and
performs sbhl-map-all-forward-true-nodes."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((*sbhl-space* space)
        (*sbhl-gather-space* gather-space)
        (*sbhl-suspend-new-spaces?* t))
    (sbhl-map-all-forward-true-nodes module node fn))
  nil)

;; (defun sbhl-map-all-backward-true-nodes (module node function &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-simply-map-all-backward-true-nodes (module node function &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-map-union-all-forward-true-nodes (module nodes function &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-map-union-all-backward-true-nodes (module nodes function &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-simply-union-all-backward-true-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-union-simply-all-backward-true-edges (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-simply-union-all-backward-true-nodes-such-that (module nodes test &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-gather-all-forward-true-nodes (module node function &optional mt tv combine-fn)) -- commented declareFunction (3 3), no body
;; (defun sbhl-gather-all-backward-true-nodes (module node function &optional mt tv combine-fn)) -- commented declareFunction (3 3), no body
;; (defun sbhl-gather-closure (node function combine-fn)) -- commented declareFunction (3 0), no body

(defun sbhl-gather-first-among-all-forward-true-nodes (module node fn &optional mt tv combine-fn)
  "[Cyc] Applies FUNCTION to each element of NODE's forward true closure, returning
the first non-nil result. @see sbhl-gather-first-among-closure"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((combiner (or combine-fn *sbhl-combine-fn*))
        (result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
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
                              (sbhl-check-type fn function-spec-p)
                              (let ((*sbhl-search-behavior*
                                      (determine-sbhl-search-behavior
                                       (get-sbhl-search-module)
                                       (get-sbhl-search-direction)
                                       (get-sbhl-tv)))
                                    (*sbhl-terminating-marking-space*
                                      (determine-sbhl-terminating-marking-space
                                       *sbhl-search-behavior*)))
                                (setf result (sbhl-gather-first-among-closure node fn combiner)))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*))))))))
    result))

;; (defun sbhl-gather-first-among-forward-true-nodes-in-space (module node fn &optional mt tv combine-fn)) -- commented declareFunction (3 3), no body
;; (defun sbhl-gather-first-among-all-backward-true-nodes (module node fn &optional mt tv combine-fn)) -- commented declareFunction (3 3), no body
;; (defun sbhl-simply-gather-first-among-all-forward-true-nodes (module node fn &optional mt tv combine-fn)) -- commented declareFunction (3 3), no body

(defun sbhl-simply-gather-first-among-all-backward-true-nodes (module node fn &optional mt tv
                                                                 (combine-fn *sbhl-combine-fn*))
  "[Cyc]"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
    (possibly-with-sbhl-mt-relevance (mt)
      (let ((*sbhl-tv* (or tv (get-sbhl-true-tv)))
            (*relevant-sbhl-tv-function* (if tv
                                             'relevant-sbhl-tv-is-general-tv
                                             *relevant-sbhl-tv-function*)))
        (when tv
          (sbhl-check-type tv sbhl-true-tv-p))
        (let ((*sbhl-search-truth* #$True-JustificationTruth)
              (*sbhl-search-direction* (get-sbhl-backward-search-direction))
              (*sbhl-link-direction* (get-sbhl-module-backward-direction (get-sbhl-module))))
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
                              (sbhl-check-type fn function-spec-p)
                              (let ((*sbhl-add-node-to-result-test* nil)
                                    (*sbhl-search-behavior*
                                      (determine-sbhl-search-behavior
                                       (get-sbhl-search-module)
                                       (get-sbhl-search-direction)
                                       (get-sbhl-tv)))
                                    (*sbhl-terminating-marking-space*
                                      (determine-sbhl-terminating-marking-space
                                       *sbhl-search-behavior*)))
                                (setf result (sbhl-gather-first-among-closure node fn combine-fn)))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*))))))))
    result))

(defun sbhl-gather-first-among-closure (node compose-fn combine-fn)
  "[Cyc] @binds *sbhl-compose-fn*. @binds *sbhl-combine-fn*. @binds *sbhl-consider-node-fn*,
to sbhl-gather-first-non-nil-result. Then performs sbhl-transitive-closure."
  (let ((result nil)
        (*sbhl-compose-fn* compose-fn)
        (*sbhl-combine-fn* combine-fn)
        (*sbhl-consider-node-fn* 'sbhl-gather-first-non-nil-result))
    (setf result (sbhl-transitive-closure node))
    result))

;; (defun sbhl-simply-gather-first-among-all-forward-true-nodes-with-prune (module node fn &optional mt tv combine-fn)) -- commented declareFunction (3 3), no body

(defun sbhl-simply-gather-first-among-all-backward-true-nodes-with-prune (module node fn &optional mt tv
                                                                            (combine-fn *sbhl-combine-fn*))
  "[Cyc]"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
    (possibly-with-sbhl-mt-relevance (mt)
      (let ((*sbhl-tv* (or tv (get-sbhl-true-tv)))
            (*relevant-sbhl-tv-function* (if tv
                                             'relevant-sbhl-tv-is-general-tv
                                             *relevant-sbhl-tv-function*)))
        (when tv
          (sbhl-check-type tv sbhl-true-tv-p))
        (let ((*sbhl-search-truth* #$True-JustificationTruth)
              (*sbhl-search-direction* (get-sbhl-backward-search-direction))
              (*sbhl-link-direction* (get-sbhl-module-backward-direction (get-sbhl-module))))
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
                              (sbhl-check-type fn function-spec-p)
                              (let ((*sbhl-add-node-to-result-test* nil)
                                    (*sbhl-search-behavior*
                                      (determine-sbhl-search-behavior
                                       (get-sbhl-search-module)
                                       (get-sbhl-search-direction)
                                       (get-sbhl-tv)))
                                    (*sbhl-terminating-marking-space*
                                      (determine-sbhl-terminating-marking-space
                                       *sbhl-search-behavior*)))
                                (setf result (sbhl-gather-first-among-closure-with-prune node fn combine-fn)))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*))))))))
    result))

(defun sbhl-gather-first-among-closure-with-prune (node compose-fn combine-fn)
  "[Cyc]"
  (let ((result nil)
        (*sbhl-compose-fn* compose-fn)
        (*sbhl-combine-fn* combine-fn)
        (*sbhl-consider-node-fn* 'sbhl-gather-first-non-nil-result-with-prune))
    (setf result (sbhl-transitive-closure node))
    result))

;; (defun sbhl-all-forward-true-nodes-if (module node test &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-all-backward-true-nodes-if (module node test &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-closure-if (node test)) -- commented declareFunction (2 0), no body
;; (defun sbhl-all-forward-true-nodes-if-with-pruning (module node test &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-all-backward-true-nodes-if-with-pruning (module node test &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-closure-if-and-stop-unless (node test)) -- commented declareFunction (2 0), no body

(defun sbhl-extremal-nodes (nodes)
  "[Cyc] @return listp; Marks proper closures of nodes, noting cycles. Filters
non-extremal cycles, and then unmarks the cyclic closure of the extremal cycles.
All unmarked nodes are returned, as they are the extremal ones."
  (let ((unique-nodes (fast-delete-duplicates nodes))
        (result nil))
    (dolist (node unique-nodes)
      (unless (sbhl-search-path-termination-p node)
        (sbhl-mark-proper-closure-as-marked node)
        (when (sbhl-search-path-termination-p node)
          (let ((*sbhl-link-direction* (get-sbhl-opposite-link-direction)))
            ;; missing-larkc 1496 — likely unmarks the cyclic closure of node
            ;; so that cycle members are not treated as extremal
            (missing-larkc 1496)))))
    (dolist (node unique-nodes)
      (unless (sbhl-search-path-termination-p node)
        (push node result)))
    result))

(defun max-nodes-backward (module nodes &optional mt tv)
  "[Cyc] @return listp; the most superordinate among NODES."
  (declare (type (satisfies sbhl-module-p) module))
  (if (length<= nodes 1)
      nodes
      (let ((result nil)
            (*sbhl-search-module* module)
            (*sbhl-search-module-type* (get-sbhl-module-type module))
            (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
            (*genl-inverse-mode-p* nil)
            (*sbhl-module* module))
        (possibly-with-sbhl-mt-relevance (mt)
          (let ((*sbhl-tv* (or tv (get-sbhl-true-tv)))
                (*relevant-sbhl-tv-function* (if tv
                                                 'relevant-sbhl-tv-is-general-tv
                                                 *relevant-sbhl-tv-function*)))
            (when tv
              (sbhl-check-type tv sbhl-true-tv-p))
            (let ((*sbhl-search-truth* #$True-JustificationTruth)
                  (*sbhl-search-direction* (get-sbhl-backward-search-direction))
                  (*sbhl-link-direction* (get-sbhl-module-backward-direction (get-sbhl-module))))
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
                                  (let ((*sbhl-search-behavior*
                                          (determine-sbhl-search-behavior
                                           (get-sbhl-search-module)
                                           (get-sbhl-search-direction)
                                           (get-sbhl-tv)))
                                        (*sbhl-terminating-marking-space*
                                          (determine-sbhl-terminating-marking-space
                                           *sbhl-search-behavior*)))
                                    (setf result (sbhl-extremal-nodes nodes)))))
                           (when (eq source :resource)
                             (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                    (when (eq source :resource)
                      (update-sbhl-resourced-spaces *sbhl-space*))))))))
        result)))

(defun sbhl-independent-cycles (nodes)
  "[Cyc] @return listp; a list of lists. Each list is a group of nodes among NODES
which are coextensional."
  (let ((cycles nil))
    (let ((*sbhl-target-space* (get-sbhl-marking-space)))
      (let ((*sbhl-target-gather-space* (get-sbhl-marking-space)))
        (sbhl-mark-nodes-in-target-space nodes)
        (dolist (node nodes)
          (unless (tree-find node cycles)
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
                                (sbhl-mark-proper-closure-as-marked node)
                                (when (sbhl-search-path-termination-p node)
                                  (let ((*sbhl-link-direction* (get-sbhl-opposite-link-direction)))
                                    (let ((result nil))
                                      (let ((*sbhl-result* nil))
                                        (unwind-protect
                                             (sbhl-unmark-marked-closure-and-gather-if
                                              node 'sbhl-marked-in-target-space-p)
                                          (setf result *sbhl-result*)))
                                      (when result
                                        (push result cycles)))))))
                         (when (eq source :resource)
                           (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                  (when (eq source :resource)
                    (update-sbhl-resourced-spaces *sbhl-space*)))))))
        (free-sbhl-marking-space *sbhl-target-gather-space*))
      (free-sbhl-marking-space *sbhl-target-space*))
    cycles))

(defun max-nodes-forward (module nodes &optional mt tv)
  "[Cyc] @return listp; the maximal nodes among NODES wrt module MODULE. Checks to see
if each node of NODES has any node subsuming it (and not coextensional) among the other nodes."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((unique-nodes (fast-delete-duplicates nodes))
        (cycles nil)
        (visited-nodes nil)
        (max-nodes nil))
    (if (length<= unique-nodes 1)
        unique-nodes
        (let ((*sbhl-search-module* module)
              (*sbhl-search-module-type* (get-sbhl-module-type module))
              (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
              (*genl-inverse-mode-p* nil)
              (*sbhl-module* module))
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
                                    (let ((*sbhl-search-behavior*
                                            (determine-sbhl-search-behavior
                                             (get-sbhl-search-module)
                                             (get-sbhl-search-direction)
                                             (get-sbhl-tv)))
                                          (*sbhl-terminating-marking-space*
                                            (determine-sbhl-terminating-marking-space
                                             *sbhl-search-behavior*)))
                                      (setf cycles (sbhl-independent-cycles unique-nodes))
                                      (dolist (node unique-nodes)
                                        (let ((source2 (sbhl-new-space-source)))
                                          (let ((*sbhl-space* (if (eq source2 :old)
                                                                  *sbhl-space*
                                                                  (sbhl-get-new-space source2))))
                                            (unwind-protect
                                                 (let ((*sbhl-gather-space* (if (eq source2 :old)
                                                                               *sbhl-gather-space*
                                                                               (sbhl-get-new-space source2))))
                                                   (unwind-protect
                                                        (let ((*sbhl-finished?* nil)
                                                              (*sbhl-stop-search-path?* nil)
                                                              (*sbhl-search-parent-marking* nil)
                                                              (*sbhl-nodes-previous-marking* nil)
                                                              (*genl-inverse-mode-p* nil))
                                                          (with-rw-read-lock (*sbhl-rw-lock*)
                                                            (let* ((cyclic-nodes (first (member node cycles :test #'member?)))
                                                                   (other-nodes (if cyclic-nodes
                                                                                    (set-difference unique-nodes cyclic-nodes)
                                                                                    (remove node unique-nodes))))
                                                              (unless (member? node visited-nodes)
                                                                (setf visited-nodes (nconc (copy-list cyclic-nodes) visited-nodes))
                                                                (unless (sbhl-path-from-node-to-any-of-nodes-p node other-nodes)
                                                                  (if cyclic-nodes
                                                                      (setf max-nodes (nconc (copy-list cyclic-nodes) max-nodes))
                                                                      (push node max-nodes)))))))
                                                     (when (eq source2 :resource)
                                                       (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                                              (when (eq source2 :resource)
                                                (update-sbhl-resourced-spaces *sbhl-space*)))))))))
                             (when (eq source :resource)
                               (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                      (when (eq source :resource)
                        (update-sbhl-resourced-spaces *sbhl-space*))))))))
          max-nodes))))

(defun max-nodes-direction (nodes)
  "[Cyc] @return keywordp; whether to do max-nodes :forward or :backward."
  (let ((others (1- (length nodes)))
        (up-cost 0)
        (down-cost 0))
    (dolist (node nodes)
      (incf down-cost (spec-cardinality node))
      (incf up-cost (+ others (genl-cardinality node))))
    (if (< up-cost down-cost)
        :forward
        :backward)))

(defun sbhl-min-nodes (module nodes &optional mt tv)
  "[Cyc] @return listp; the most subordinate among NODES."
  (declare (type (satisfies sbhl-module-p) module))
  (setf nodes (fast-delete-duplicates nodes))
  (if (length<= nodes 1)
      nodes
      (let ((result nil)
            (*sbhl-search-module* module)
            (*sbhl-search-module-type* (get-sbhl-module-type module))
            (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
            (*genl-inverse-mode-p* nil)
            (*sbhl-module* module))
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
                                  (let ((*sbhl-search-behavior*
                                          (determine-sbhl-search-behavior
                                           (get-sbhl-search-module)
                                           (get-sbhl-search-direction)
                                           (get-sbhl-tv)))
                                        (*sbhl-terminating-marking-space*
                                          (determine-sbhl-terminating-marking-space
                                           *sbhl-search-behavior*)))
                                    (setf result (sbhl-extremal-nodes nodes)))))
                           (when (eq source :resource)
                             (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                    (when (eq source :resource)
                      (update-sbhl-resourced-spaces *sbhl-space*))))))))
        result)))

(defun sbhl-max-nodes (module nodes &optional mt tv direction)
  "[Cyc] @return listp; the most superordinate among NODES. DIRECTION :backward uses
sbhl-extremal-nodes, and may be expensive. @hack DIRECTION :forward will clobber maximal cycles."
  (declare (type (satisfies sbhl-module-p) module))
  (setf nodes (fast-delete-duplicates nodes))
  (if (singleton? nodes)
      nodes
      (let ((dir (or direction (max-nodes-direction nodes))))
        (case dir
          (:backward (max-nodes-backward module nodes mt tv))
          (:forward (max-nodes-forward module nodes mt tv))))))

;; (defun sbhl-min-forward-true-link-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-max-forward-true-link-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-min-forward-false-link-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-max-forward-false-link-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-min-backward-true-link-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-max-backward-true-link-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-min-backward-false-link-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-max-backward-false-link-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-stop-at-horizon (node)) -- commented declareFunction (1 0), no body
;; (defun sbhl-mark-closure-up-to-horizon (node)) -- commented declareFunction (1 0), no body
;; (defun sbhl-common-horizon (node &optional node2)) -- commented declareFunction (1 1), no body
;; (defun sbhl-min-ceilings (module nodes &optional candidates mt tv)) -- commented declareFunction (2 3), no body

(defun sbhl-max-floors (module nodes &optional candidates mt tv direction)
  "[Cyc] @return listp; the most superordinate nodes which are backward accessible by NODES.
@see sbhl-floors. @see sbhl-max-nodes."
  (declare (type (satisfies sbhl-module-p) module))
  (let* ((min-nodes (sbhl-min-nodes module nodes mt tv))
         (floors (sbhl-floors module min-nodes candidates mt tv)))
    (sbhl-max-nodes (get-sbhl-reductions-module module) floors mt tv direction)))

(defun sbhl-max-floors-pruning-cycles (module nodes &optional candidates mt tv)
  "[Cyc] @return listp; the most superordinate nodes which are backward accessible by NODES.
Prunes all cyclic nodes from result except those from NODES and CANDIDATES or keeps
just one arbitrary node from each cycle."
  (declare (type (satisfies sbhl-module-p) module))
  (let* ((max-floors (sbhl-max-floors module nodes candidates mt tv))
         (cycle-preferred-members (append nodes candidates)))
    (sbhl-prune-unwanted-extremal-cycles module max-floors cycle-preferred-members mt tv)))

(defun sbhl-prune-unwanted-extremal-cycles (module nodes cycle-preferred-members &optional mt tv)
  "[Cyc] Does the pruning for sbhl-max-floors-pruning-cycles.
@hack roll this into a different max-floors implementation."
  (declare (type (satisfies sbhl-module-p) module))
  (if (not (length> nodes 1))
      nodes
      (let ((result nil)
            (*sbhl-table* (get-sbhl-marking-space)))
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
                                    (let ((*sbhl-search-behavior*
                                            (determine-sbhl-search-behavior
                                             (get-sbhl-search-module)
                                             (get-sbhl-search-direction)
                                             (get-sbhl-tv)))
                                          (*sbhl-terminating-marking-space*
                                            (determine-sbhl-terminating-marking-space
                                             *sbhl-search-behavior*)))
                                      (dolist (node nodes)
                                        ;; missing-larkc 1489 — likely sbhl-marked-in-table-p, checks
                                        ;; if node is already marked in *sbhl-table*
                                        (unless (missing-larkc 1489)
                                          (let ((*sbhl-space* (get-sbhl-marking-space)))
                                            (sbhl-mark-proper-closure-as-marked node)
                                            (if (sbhl-search-path-termination-p node)
                                                (let ((cycle nil)
                                                      (pushed? nil))
                                                  (let ((*sbhl-result* nil))
                                                    (unwind-protect
                                                         (let ((*sbhl-link-direction* (get-sbhl-opposite-link-direction)))
                                                           ;; missing-larkc 1501 — likely sbhl-unmark-marked-closure-and-gather,
                                                           ;; gathers all nodes in the cycle
                                                           (missing-larkc 1501))
                                                      (setf cycle *sbhl-result*)))
                                                  (dolist (cycle-node cycle)
                                                    ;; missing-larkc 1479 — likely sbhl-mark-node-in-table,
                                                    ;; marks cycle-node in *sbhl-table* so it's skipped next time
                                                    (missing-larkc 1479)
                                                    (when (member? cycle-node cycle-preferred-members)
                                                      (setf pushed? t)
                                                      (push cycle-node result)))
                                                  (unless pushed?
                                                    (push node result)))
                                                (push node result))
                                            (free-sbhl-marking-space *sbhl-space*)))))))
                             (when (eq source :resource)
                               (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                      (when (eq source :resource)
                        (update-sbhl-resourced-spaces *sbhl-space*)))))))))
        (free-sbhl-marking-space *sbhl-table*)
        result)))

;; (defun sbhl-ceilings (module nodes &optional candidates mt tv)) -- commented declareFunction (2 3), no body

(defun sbhl-floors (module nodes &optional candidates mt tv)
  "[Cyc] @return listp; the nodes which are a member of the intersection of the backward
true closures of each of NODES. If CANDIDATES are provided, the answer will subset them."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil))
    (setf nodes (fast-delete-duplicates nodes))
    (cond
      ((null nodes) nil)
      ((not (singleton? nodes))
       (let ((*sbhl-search-module* module)
             (*sbhl-search-module-type* (get-sbhl-module-type module))
             (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
             (*genl-inverse-mode-p* nil)
             (*sbhl-module* module))
         (possibly-with-sbhl-mt-relevance (mt)
           (let ((*sbhl-tv* (or tv (get-sbhl-true-tv)))
                 (*relevant-sbhl-tv-function* (if tv
                                                  'relevant-sbhl-tv-is-general-tv
                                                  *relevant-sbhl-tv-function*)))
             (when tv
               (sbhl-check-type tv sbhl-true-tv-p))
             (let ((*sbhl-search-truth* #$True-JustificationTruth)
                   (*sbhl-search-direction* (get-sbhl-backward-search-direction))
                   (*sbhl-link-direction* (get-sbhl-module-backward-direction (get-sbhl-module))))
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
                                   (let ((*sbhl-search-behavior*
                                           (determine-sbhl-search-behavior
                                            (get-sbhl-search-module)
                                            (get-sbhl-search-direction)
                                            (get-sbhl-tv)))
                                         (*sbhl-terminating-marking-space*
                                           (determine-sbhl-terminating-marking-space
                                            *sbhl-search-behavior*)))
                                     ;; missing-larkc 1551 — likely sbhl-sweep-step-and-gather-floors,
                                     ;; finds the intersection of backward closures of all nodes
                                     (setf result (missing-larkc 1551)))))
                            (when (eq source :resource)
                              (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                     (when (eq source :resource)
                       (update-sbhl-resourced-spaces *sbhl-space*)))))))))
       result)
      ((null candidates)
       (if (sbhl-transfers-through-module-p module)
           ;; missing-larkc 1601 — likely sbhl-all-backward-true-nodes for the
           ;; single node, gathering its full backward closure
           (setf result (missing-larkc 1601))
           (setf result nodes))
       result)
      (t
       ;; missing-larkc 1577 — likely sbhl-predicate-relation-to-which with
       ;; the single node and candidates list
       (setf result (missing-larkc 1577))
       result))))

(defun sbhl-predicate-relation-to-which (module node candidates &optional mt tv excl-link-node)
  "[Cyc] @return listp; the members of CANDIDATES which are accessible to NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
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
                              (let ((*sbhl-search-behavior*
                                      (determine-sbhl-search-behavior
                                       (get-sbhl-search-module)
                                       (get-sbhl-search-direction)
                                       (get-sbhl-tv)))
                                    (*sbhl-terminating-marking-space*
                                      (determine-sbhl-terminating-marking-space
                                       *sbhl-search-behavior*)))
                                (when excl-link-node
                                  (sbhl-mark-node-marked excl-link-node))
                                (sbhl-mark-closure-as-marked node)
                                (when excl-link-node
                                  (sbhl-mark-node-unmarked excl-link-node))
                                (dolist (candidate candidates)
                                  (let ((*genl-inverse-mode-p*
                                          (if (eq (get-sbhl-module-link-pred module)
                                                  #$genlInverse)
                                              t
                                              nil)))
                                    (when (sbhl-marked-in-terminating-space-p candidate)
                                      (push candidate result)))))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*))))))))
    result))

;; (defun sbhl-which-with-predicate-relation (module node candidates &optional mt tv)) -- commented declareFunction (3 2), no body

(defun sbhl-predicate-relation-to-which-excluding-link-node (module node candidates excl-link-node &optional mt tv)
  "[Cyc]"
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-predicate-relation-to-which module node candidates mt tv excl-link-node))

;; (defun sbhl-inverse-relation-to-which (module node candidates &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-gather-first-target-marked-node (node)) -- commented declareFunction (1 0), no body
;; (defun sbhl-first-common-horizon (node1 node2)) -- commented declareFunction (2 0), no body
;; (defun sbhl-first-floor-of-node-pair (module node1 node2 &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-first-ceiling-of-node-pair (module node1 node2 &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-forward-true-goals-with-no-path-from-nodes (module node nodes &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-all-goals-with-no-path-from-nodes (node nodes)) -- commented declareFunction (2 0), no body
;; (defun sbhl-all-forward-true-nodes-between (module node1 node2 &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-closure-between (node1 node2)) -- commented declareFunction (2 0), no body
;; (defun sbhl-all-forward-true-nodes-among (module node candidates &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-all-backward-true-nodes-among (module node candidates &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-closure-among (node candidates)) -- commented declareFunction (2 0), no body
;; (defun sbhl-gather-dependent-nodes (node)) -- commented declareFunction (1 0), no body
;; (defun sbhl-push-dependent-nodes-onto-result (node)) -- commented declareFunction (1 0), no body
;; (defun sbhl-check-target-marking-for-dependence (node)) -- commented declareFunction (1 0), no body
;; (defun sbhl-dependent-nodes (node)) -- commented declareFunction (1 0), no body
;; (defun sbhl-all-dependent-backward-true-nodes (module nodes &optional mt tv)) -- commented declareFunction (2 2), no body

(defun sbhl-predicate-relation-p (module node1 node2 &optional mt tv)
  "[Cyc] @return booleanp; whether there is a forward true path from NODE1 to NODE2."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
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
                              (setf result (sbhl-path-from-node-to-node-p node1 node2))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*))))))))
    result))

;; (defun sbhl-predicate-relation-in-space-p (module node1 node2 &optional mt tv)) -- commented declareFunction (3 2), no body

(defun sbhl-non-justifying-predicate-relation-p (module node1 node2 &optional mt tv)
  "[Cyc] @return booleanp; ensures no justification is done within sbhl-predicate-relation-p,
and ensures that a new sbhl space is used."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((*sbhl-justification-search-p* nil)
        (*sbhl-apply-unwind-function-p* nil)
        (*suspend-sbhl-cache-use?* nil)
        (*sbhl-suspend-new-spaces?* nil))
    (sbhl-predicate-relation-p module node1 node2 mt tv)))

;; (defun sbhl-predicate-relation-within-multiple-searches-p (module node1 node2 mt tv)) -- commented declareFunction (5 0), no body
;; (defun sbhl-inverse-relation-p (module node1 node2 &optional mt tv)) -- commented declareFunction (3 2), no body

(defun sbhl-false-predicate-relation-p (module node1 node2 &optional mt tv)
  "[Cyc] @return booleanp; whether there is a forward false path from NODE1 to NODE2."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
    (possibly-with-sbhl-mt-relevance (mt)
      (let ((*sbhl-tv* (or tv (get-sbhl-false-tv)))
            (*relevant-sbhl-tv-function* (if tv
                                             'relevant-sbhl-tv-is-general-tv
                                             *relevant-sbhl-tv-function*)))
        (when tv
          (sbhl-check-type tv sbhl-false-tv-p))
        (let ((*sbhl-search-truth* #$False-JustificationTruth)
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
                              (setf result (sbhl-path-from-node-to-node-p node1 node2))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*))))))))
    result))

(defun sbhl-false-inverse-relation-p (module node1 node2 &optional mt tv)
  "[Cyc] @return booleanp; whether there is a backward false path from NODE1 to NODE2."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
    (possibly-with-sbhl-mt-relevance (mt)
      (let ((*sbhl-tv* (or tv (get-sbhl-false-tv)))
            (*relevant-sbhl-tv-function* (if tv
                                             'relevant-sbhl-tv-is-general-tv
                                             *relevant-sbhl-tv-function*)))
        (when tv
          (sbhl-check-type tv sbhl-false-tv-p))
        (let ((*sbhl-search-truth* #$False-JustificationTruth)
              (*sbhl-search-direction* (get-sbhl-backward-search-direction))
              (*sbhl-link-direction* (get-sbhl-module-backward-direction (get-sbhl-module))))
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
                              (setf result (sbhl-path-from-node-to-node-p node1 node2))))
                       (when (eq source :resource)
                         (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                (when (eq source :resource)
                  (update-sbhl-resourced-spaces *sbhl-space*))))))))
    result))

(defun sbhl-path-from-node-to-node-p (node1 node2)
  "[Cyc] @return booleanp; whether there is a path from NODE1 to NODE2."
  (increment-sbhl-graph-attempt-historical-count)
  (let ((result nil)
        (*sbhl-search-type* :boolean)
        (*sbhl-search-behavior*
          (determine-sbhl-search-behavior
           (get-sbhl-search-module)
           (get-sbhl-search-direction)
           (get-sbhl-tv)))
        (*sbhl-terminating-marking-space*
          (determine-sbhl-terminating-marking-space *sbhl-search-behavior*)))
    (let ((premarking? (sbhl-module-premarks-gather-nodes-p))
          (goal-fn 'sbhl-node-is-goal-node)
          (goal-node node2)
          (goal-space *sbhl-space*))
      (when premarking?
        (let ((*sbhl-module* (get-sbhl-transfers-through-module (get-sbhl-search-module)))
              (*genl-inverse-mode-p* (if (eq (get-sbhl-link-pred (get-sbhl-search-module))
                                             #$negationInverse)
                                         t
                                         *genl-inverse-mode-p*)))
          (sbhl-premark-gather-nodes goal-node))
        (setf goal-fn 'sbhl-node-marked-as-goal-node)
        (setf goal-space *sbhl-gather-space*))
      (let ((*sbhl-search-parent-marking* nil)
            (*genl-inverse-mode-p* nil)
            (*sbhl-consider-node-fn* goal-fn)
            (*sbhl-goal-node* goal-node)
            (*sbhl-goal-space* goal-space)
            (*sbhl-unmarking-search-p* nil))
        (setf result (sbhl-transitive-closure node1))))
    (when result
      (increment-sbhl-graph-success-historical-count))
    result))

;; (defun sbhl-disjoins-relation-p (module node1 node2 &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun why-sbhl-predicate-relation-p (module node1 node2 &optional mt tv behavior)) -- commented declareFunction (3 3), no body
;; (defun why-sbhl-false-predicate-relation-p (module node1 node2 &optional mt tv behavior)) -- commented declareFunction (3 3), no body

(defun why-sbhl-relation? (module node1 node2 &optional mt tv behavior)
  "[Cyc]"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((bool-fn nil))
    (cond
      ((or (sbhl-true-tv-p tv)
           (and (null tv) (sbhl-true-tv-p *sbhl-tv*)))
       (cond
         ((or (sbhl-simple-module-p module)
              (sbhl-transfers-through-module-p module))
          (setf bool-fn 'sbhl-predicate-relation-p))
         ((sbhl-disjoins-module-p module)
          (setf bool-fn 'sbhl-implied-disjoins-relation-p))
         ((sbhl-time-module-p module))))
      ((or (sbhl-false-tv-p tv)
           (and (null tv) (sbhl-false-tv-p *sbhl-tv*)))
       (cond
         ((or (sbhl-simple-module-p module)
              (sbhl-transfers-through-module-p module))
          (setf bool-fn 'sbhl-implied-false-predicate-relation-p))
         ((sbhl-disjoins-module-p module)
          (setf bool-fn 'sbhl-false-predicate-relation-p))
         ((sbhl-time-module-p module))))
      (t
       (sbhl-error 3 "Invalid TV argument ~a, or *sbhl-tv* ~a" tv *sbhl-tv*)))
    (when bool-fn
      (sbhl-handle-justification bool-fn module node1 node2 mt tv behavior))))

;; (defun sbhl-predicate-relation-with-any-p (module node nodes &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun why-some-sbhl-predicate-relation-among-p (module node nodes &optional mt tv behavior)) -- commented declareFunction (3 3), no body
;; (defun sbhl-inverse-relation-with-any-p (module node nodes &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-false-predicate-relation-with-any-p (module node nodes &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-premark-union-nodes-closures (nodes)) -- commented declareFunction (1 0), no body

(defun sbhl-path-from-node-to-any-of-nodes-p (node nodes)
  "[Cyc] @return booleanp; whether there is a path from NODE to any of NODES."
  (let ((result nil)
        (*sbhl-search-behavior*
          (determine-sbhl-search-behavior
           (get-sbhl-search-module)
           (get-sbhl-search-direction)
           (get-sbhl-tv)))
        (*sbhl-terminating-marking-space*
          (determine-sbhl-terminating-marking-space *sbhl-search-behavior*))
        (*sbhl-target-space* (get-sbhl-marking-space)))
    (let ((*sbhl-target-gather-space* (get-sbhl-marking-space)))
      (if (sbhl-module-premarks-gather-nodes-p)
          ;; missing-larkc 1649 — likely sbhl-premark-union-nodes-closures
          ;; for premarking when the module requires it
          (missing-larkc 1649)
          (sbhl-mark-nodes-in-target-space-gp nodes))
      (let ((*sbhl-goal-space* *sbhl-target-space*)
            (*sbhl-goal-node* nodes)
            (*sbhl-consider-node-fn* 'sbhl-node-marked-as-goal-node)
            (*sbhl-search-type* :boolean))
        (setf result (sbhl-transitive-closure node)))
      (free-sbhl-marking-space *sbhl-target-gather-space*))
    (free-sbhl-marking-space *sbhl-target-space*)
    result))

;; (defun sbhl-disjoins-relation-with-any-p (module node nodes &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-predicate-relation-with-all-p (module node nodes &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-path-from-node-to-all-of-nodes-p (node nodes)) -- commented declareFunction (2 0), no body

(defun sbhl-any-with-predicate-relation-p (module nodes node &optional mt tv)
  "[Cyc] @return booleanp; whether there is a forward true path from any of NODES to NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((pred (get-sbhl-module-link-pred module))
        (result nil))
    (if (sbhl-cache-use-possible-for-nodes-p pred nodes node)
        (possibly-with-sbhl-mt-relevance (mt)
          (dolist (subnode nodes)
            (when (setf result (sbhl-cached-predicate-relation-p pred subnode node))
              (return))))
        (let ((*sbhl-search-module* module)
              (*sbhl-search-module-type* (get-sbhl-module-type module))
              (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
              (*genl-inverse-mode-p* nil)
              (*sbhl-module* module))
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
                                    (setf result (sbhl-path-from-any-of-nodes-to-node-p nodes node))))
                             (when (eq source :resource)
                               (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                      (when (eq source :resource)
                        (update-sbhl-resourced-spaces *sbhl-space*))))))))))
    result))

;; (defun sbhl-any-with-false-inverse-relation-p (module nodes node &optional mt tv)) -- commented declareFunction (3 2), no body

(defun sbhl-premark-node-closure (node)
  "[Cyc] Modifier. Marks the forward closure of NODE in target space."
  (let* ((premark-module (get-sbhl-premark-module (get-sbhl-search-module)))
         (*sbhl-search-module* premark-module)
         (*sbhl-search-module-type* (get-sbhl-module-type premark-module))
         (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test premark-module))
         (*genl-inverse-mode-p* nil)
         (*sbhl-module* premark-module)
         (*sbhl-tv* (sbhl-search-true-tv))
         (*sbhl-search-direction* (get-sbhl-forward-search-direction))
         (*sbhl-link-direction* (get-sbhl-module-forward-direction (get-sbhl-search-module)))
         (*sbhl-search-behavior*
           (determine-sbhl-search-behavior
            (get-sbhl-search-module)
            (get-sbhl-search-direction)
            (get-sbhl-tv)))
         (*sbhl-terminating-marking-space*
           (determine-sbhl-terminating-marking-space *sbhl-search-behavior*))
         (*sbhl-space* *sbhl-target-space*))
    (sbhl-mark-closure-as-marked node))
  nil)

(defun sbhl-path-from-any-of-nodes-to-node-p (nodes node)
  "[Cyc] @return booleanp; whether there is a path from any of NODES to NODE."
  (let ((result nil)
        (*sbhl-search-type* :boolean)
        (*sbhl-search-behavior*
          (determine-sbhl-search-behavior
           (get-sbhl-search-module)
           (get-sbhl-search-direction)
           (get-sbhl-tv)))
        (*sbhl-terminating-marking-space*
          (determine-sbhl-terminating-marking-space *sbhl-search-behavior*))
        (*sbhl-goal-node* node))
    (if (sbhl-module-premarks-gather-nodes-p)
        (let ((*sbhl-target-space* (get-sbhl-marking-space)))
          (sbhl-premark-node-closure node)
          (let ((*sbhl-goal-space* *sbhl-target-space*)
                (*sbhl-consider-node-fn* 'sbhl-node-marked-as-goal-node))
            (unless *sbhl-finished?*
              (dolist (start nodes)
                (when *sbhl-finished?* (return))
                (setf result (sbhl-transitive-closure start)))))
          (free-sbhl-marking-space *sbhl-target-space*))
        (let ((*sbhl-consider-node-fn* 'sbhl-node-is-goal-node))
          (unless *sbhl-finished?*
            (dolist (start nodes)
              (when *sbhl-finished?* (return))
              (setf result (sbhl-transitive-closure start))))))
    result))

;; (defun sbhl-any-with-disjoins-relation-p (module nodes node &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-all-with-predicate-relation-p (module nodes node &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-all-with-false-predicate-relation-p (module nodes node &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-all-with-false-inverse-relation-p (module nodes node &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-path-from-all-of-nodes-to-node-p (nodes node)) -- commented declareFunction (2 0), no body
;; (defun sbhl-all-with-disjoins-relation-p (module nodes node &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-predicate-relation-between-any-p (module nodes1 nodes2 &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-path-from-any-of-nodes-to-any-of-nodes-p (nodes1 nodes2)) -- commented declareFunction (2 0), no body
;; (defun sbhl-all-with-predicate-relation-with-any-p (module nodes1 nodes2 &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-path-from-all-of-nodes-to-any-of-nodes-p (nodes1 nodes2)) -- commented declareFunction (2 0), no body
;; (defun sbhl-any-predicate-relation-with-all-p (module nodes1 nodes2 &optional mt tv)) -- commented declareFunction (3 2), no body
