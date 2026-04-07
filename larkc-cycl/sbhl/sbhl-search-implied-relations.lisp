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


(defun get-sbhl-sibling-disjoint-closure-fn (module)
  "[Cyc] @return function-spec-p"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((pcase-var (get-sbhl-module-link-pred module)))
    (cond
      ((eql pcase-var #$genls) 'all-sdc)
      (t nil))))

(defun sbhl-all-sibling-disjoint-nodes (module node &optional mt tv)
  "[Cyc] @hack. the various sibling disjoint behaviors need modularization."
  (declare (type (satisfies sbhl-module-p) module)
           (ignore tv))
  (let ((sd-closure-fn (get-sbhl-sibling-disjoint-closure-fn module))
        (result nil))
    (when sd-closure-fn
      (setf result (funcall sd-closure-fn node mt)))
    result))

(defun get-sbhl-sibling-disjoint-max-nodes-fn (module)
  "[Cyc] @return function-spec-p"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((pcase-var (get-sbhl-module-link-pred module)))
    (cond
      ((eql pcase-var #$genls) 'max-sdc)
      (t nil))))

(defun sbhl-max-sibling-disjoint-nodes (module node &optional mt tv)
  "[Cyc] @hack. the various sibling disjoint behaviors need modularization."
  (declare (type (satisfies sbhl-module-p) module)
           (ignore tv))
  (let ((sd-max-fn (get-sbhl-sibling-disjoint-max-nodes-fn module))
        (result nil))
    (when sd-max-fn
      (setf result (funcall sd-max-fn node mt)))
    result))

(defun get-sbhl-sibling-disjoint-boolean-fn (module)
  "[Cyc] @return function-spec-p"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((pcase-var (get-sbhl-module-link-pred module)))
    (cond
      ((eql pcase-var #$genls) 'sdc?)
      (t nil))))

(defun sbhl-sibling-disjoint-relation-p (module node1 node2 &optional mt tv)
  "[Cyc] @hack. the various sibling disjoint behaviors need modularization."
  (declare (type (satisfies sbhl-module-p) module)
           (ignore tv))
  (let ((sd-boolean-fn (get-sbhl-sibling-disjoint-boolean-fn module))
        (result nil))
    (when sd-boolean-fn
      (setf result (funcall sd-boolean-fn node1 node2 mt)))
    result))

(defun get-sbhl-sibling-disjoint-any-boolean-fn (module)
  "[Cyc] @return function-spec-p"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((pcase-var (get-sbhl-module-link-pred module)))
    (cond
      ((eql pcase-var #$genls) 'any-sdc-wrt?)
      (t nil))))

(defun sbhl-any-with-sibling-disjoint-relation-p (module nodes1 node2 &optional mt tv)
  "[Cyc] @hack. the various sibling disjoint behaviors need modularization."
  (declare (type (satisfies sbhl-module-p) module)
           (ignore tv))
  (let ((sd-any-boolean-fn (get-sbhl-sibling-disjoint-any-boolean-fn module))
        (result nil))
    (when sd-any-boolean-fn
      (setf result (funcall sd-any-boolean-fn nodes1 node2 mt)))
    result))

;; (defun get-sbhl-sibling-disjoint-any-boolean-any-fn (module)) -- commented declareFunction (1 0), no body
;; (defun sbhl-sibling-disjoint-relation-between-any-p (module nodes1 nodes2 &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun get-sbhl-sibling-disjoint-justification-fn (module)) -- commented declareFunction (1 0), no body
;; (defun sbhl-sibling-disjoint-justification (module node1 node2 &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-disjoins-of-backward-closure (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-gather-all-disjoins (node)) -- commented declareFunction (1 0), no body
;; (defun sbhl-all-sibling-disjoint-nodes-of-backward-closure (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-disjoins-of-tt-closure (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-all-sibling-disjoint-nodes-of-tt (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-tt-closure-of-disjoins (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-all-tt-nodes-of-sibling-disjoint-nodes (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-all-implied-forward-false-nodes (module node &optional mt tv)) -- commented declareFunction (2 2), no body
;; (defun sbhl-all-implied-backward-false-nodes (module node &optional mt tv)) -- commented declareFunction (2 2), no body

(defun sbhl-all-implied-disjoins (module node &optional mt tv)
  "[Cyc] @hack. could reuse spaces. gathers all disjoins and sibling disjoins."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((tt-module (get-sbhl-disjoins-search-tt-module module))
        (disjoin-nodes nil)
        (sibling-disjoins nil))
    (setf disjoin-nodes (sbhl-all-forward-true-nodes module node mt tv))
    (setf sibling-disjoins (sbhl-all-sibling-disjoint-nodes tt-module node mt tv))
    (nunion disjoin-nodes sibling-disjoins)))

(defun sbhl-implied-max-disjoins (module node &optional mt tv)
  "[Cyc] @hack. could reuse spaces. gathers all max disjoins and max sibling disjoins, and maximizes among these."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((tt-module (get-sbhl-disjoins-search-tt-module module))
        (max-disjoin-nodes nil)
        (max-sibling-disjoins nil))
    (setf max-disjoin-nodes (sbhl-max-true-disjoins module node mt tv))
    (setf max-sibling-disjoins (sbhl-max-sibling-disjoint-nodes tt-module node mt tv))
    (sbhl-max-nodes tt-module (nconc max-disjoin-nodes max-sibling-disjoins) mt tv)))

(defun sbhl-disjoins-relation-with-backward-nodes-p (module node not-node &optional mt tv)
  "[Cyc] @return booleanp; whether NOT-NODE is disjoint with some spec of NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((disjoins-module (get-sbhl-disjoins-module module))
        (result nil))
    (let ((*sbhl-search-module* disjoins-module)
          (*sbhl-search-module-type* (get-sbhl-module-type disjoins-module))
          (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test disjoins-module))
          (*genl-inverse-mode-p* nil)
          (*sbhl-module* disjoins-module)
          (*sbhl-search-type* :boolean))
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
                                (let ((premarking? (sbhl-module-premarks-gather-nodes-p))
                                      (goal-fn 'sbhl-node-is-goal-node)
                                      (goal-node not-node)
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
                                        (*sbhl-result* nil))
                                    (unwind-protect
                                         (let ((*sbhl-target-space* (get-sbhl-marking-space)))
                                           (unwind-protect
                                                (sbhl-check-disjoins-of-all-backward-nodes node)
                                             (free-sbhl-marking-space *sbhl-target-space*)))
                                      (setf result *sbhl-result*))))))
                         (when (eq source :resource)
                           (update-sbhl-resourced-spaces *sbhl-gather-space*))))
                  (when (eq source :resource)
                    (update-sbhl-resourced-spaces *sbhl-space*)))))))))
    result))

(defun sbhl-disjoins-with-tt-nodes-relation-p (module node not-node &optional mt tv)
  "[Cyc] @return booleanp; whether NOT-NODE is disjoint with some tt node of NODE. @hack"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((tt-module (get-sbhl-transfers-through-module module))
        (disjoins-module (get-sbhl-disjoins-module
                          (get-sbhl-transfers-through-module module)))
        (link-nodes (sbhl-forward-true-link-nodes module node mt tv))
        (result nil))
    (setf result (sbhl-any-with-predicate-relation-p disjoins-module link-nodes not-node mt tv))
    (when (and (sbhl-justification-search-p)
               *sbhl-justification-result*)
      (missing-larkc 2476)
      ;; Justification assembly: prepends link info from module/node to the
      ;; link-node found in the justification result
      (let ((link-node (second (first (first *sbhl-justification-result*)))))
        (setf *sbhl-justification-result*
              (cons (list (list (get-sbhl-module-link-pred module) node link-node)
                          (or mt *mt*)
                          (if tv
                              (sbhl-true-tv tv)
                              (sbhl-search-true-tv)))
                    *sbhl-justification-result*))))
    result))

;; (defun sbhl-sibling-disjoint-with-backward-nodes-justification (module node not-node &optional mt tv)) -- commented declareFunction (3 2), no body

(defun sbhl-sibling-disjoint-relation-with-backward-nodes-p (module node not-node &optional mt tv)
  "[Cyc] @return booleanp; whether NOT-NODE is sibling disjoint with some spec of NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((sd-boolean-fn (get-sbhl-sibling-disjoint-boolean-fn module))
        (result nil))
    (when sd-boolean-fn
      (let ((backward-nodes (sbhl-all-backward-true-nodes module node mt tv))
            (disjoint? nil))
        (dolist (back-node backward-nodes)
          (when disjoint? (return))
          (setf result (funcall sd-boolean-fn back-node not-node mt))
          (when result
            (setf disjoint? t)))))
    result))

(defun sbhl-sibling-disjoint-relation-tt-p (module node not-node &optional mt tv)
  "[Cyc] @hack. we can reuse spaces rather than reinitiating searches for each link-node. returns whether NOT-NODE is disjoint with some tt node of NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((tt-module (get-sbhl-transfers-through-module module))
        (link-nodes (sbhl-forward-true-link-nodes module node mt tv))
        (result nil))
    (let ((sd-boolean-fn (get-sbhl-sibling-disjoint-boolean-fn tt-module)))
      (dolist (link-node link-nodes)
        (when result (return))
        (setf result (funcall sd-boolean-fn link-node not-node mt))))
    result))

;; (defun sbhl-sibling-disjoint-tt-justification (module node not-node &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-argumentation-false-predicate-relation-p (module node not-node &optional mt tv)) -- commented declareFunction (3 2), no body

(defun sbhl-implied-false-predicate-relation-p (module node not-node &optional mt tv)
  "[Cyc] @hack. @return booleanp; whether NOT-NODE is known to have a false MODULE relation with NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((coerced-tv tv)
        (result nil))
    (when (sbhl-false-tv-p tv)
      (setf coerced-tv (sbhl-opposite-tv tv)))
    (cond
      ((sbhl-simple-module-p module)
       (setf result (sbhl-false-inverse-relation-p module not-node node mt tv))
       (unless (or result
                   (and (sbhl-justification-search-p)
                        *sbhl-justification-result*))
         (setf result (sbhl-disjoins-relation-with-backward-nodes-p module node not-node mt coerced-tv)))
       (unless (or result
                   (and (sbhl-justification-search-p)
                        *sbhl-justification-result*))
         (if (sbhl-justification-search-p)
             (let ((*sbhl-justification-search-p* nil)
                   (*sbhl-apply-unwind-function-p* nil)
                   (*suspend-sbhl-cache-use?* nil))
               ;; missing-larkc 1708 — likely sbhl-sibling-disjoint-relation-with-backward-nodes-justification
               (setf result (missing-larkc 1708)))
             (setf result (sbhl-sibling-disjoint-relation-with-backward-nodes-p module node not-node mt coerced-tv))))
       result)

      ((sbhl-transfers-through-module-p module)
       (setf result (sbhl-false-inverse-relation-p module not-node node mt tv))
       (unless (or result
                   (and (sbhl-justification-search-p)
                        *sbhl-justification-result*))
         (setf result (sbhl-disjoins-with-tt-nodes-relation-p module node not-node mt coerced-tv)))
       (unless (or result
                   (and (sbhl-justification-search-p)
                        *sbhl-justification-result*))
         (if (sbhl-justification-search-p)
             (let ((*sbhl-justification-search-p* nil)
                   (*sbhl-apply-unwind-function-p* nil)
                   (*suspend-sbhl-cache-use?* nil))
               ;; missing-larkc 1707 — likely sbhl-sibling-disjoint-tt-justification
               (setf result (missing-larkc 1707)))
             (setf result (sbhl-sibling-disjoint-relation-tt-p module node not-node mt coerced-tv))))
       result)

      (t
       (sbhl-error 1 "Method only valid for simple and transfer-through modules, not ~a" module)
       result))))

;; (defun sbhl-implied-false-inverse-relation-p (module node not-node &optional mt tv)) -- commented declareFunction (3 2), no body

(defun sbhl-implied-disjoins-relation-p (module node1 node2 &optional mt tv)
  "[Cyc] @hack. @return booleanp; whether NODE1 and NODE2 are disjoint wrt module relations."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil))
    (cond
      ((sbhl-disjoins-module-p module)
       (setf result (sbhl-predicate-relation-p module node1 node2 mt tv))
       (unless (or result
                   (and (sbhl-justification-search-p)
                        *sbhl-justification-result*))
         (let ((tt-module (get-sbhl-disjoins-search-tt-module module)))
           (if (sbhl-justification-search-p)
               (let ((*sbhl-justification-search-p* nil)
                     (*sbhl-apply-unwind-function-p* nil)
                     (*suspend-sbhl-cache-use?* nil))
                 ;; missing-larkc 1706 — likely sbhl-sibling-disjoint-justification
                 (setf result (missing-larkc 1706)))
               (setf result (sbhl-sibling-disjoint-relation-p tt-module node1 node2 mt tv))))
         (when (sbhl-justification-search-p)
           (missing-larkc 2475))
         (return-from sbhl-implied-disjoins-relation-p result)))
      (t
       (sbhl-error 1 "Method only valid for disjoins modules, not ~a" module)))
    result))

;; (defun sbhl-any-with-implied-false-inverse-relation-p (module nodes not-node &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-implied-false-predicate-relation-with-any-p (module node not-nodes &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun sbhl-all-with-implied-false-inverse-relation-p (module nodes not-node &optional mt tv)) -- commented declareFunction (3 2), no body

(defun sbhl-any-with-implied-disjoins-relation-p (module nodes node &optional mt tv)
  "[Cyc] @hack. @return booleanp. @example any-disjoint-with?"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil))
    (cond
      ((sbhl-disjoins-module-p module)
       (setf result (sbhl-any-with-predicate-relation-p module nodes node mt tv))
       (unless (or result
                   (sbhl-justification-search-p))
         (let ((tt-module (get-sbhl-disjoins-search-tt-module module)))
           (setf result (sbhl-any-with-sibling-disjoint-relation-p tt-module nodes node mt tv))))
       (return-from sbhl-any-with-implied-disjoins-relation-p result))
      (t
       (sbhl-error 1 "Method only valid for disjoins modules, not ~a" module)))
    result))

;; (defun sbhl-implied-disjoins-relation-between-any-p (module nodes1 nodes2 &optional mt tv)) -- commented declareFunction (3 2), no body
;; (defun why-sbhl-implied-false-predicate-relation-p (module node not-node &optional mt tv behavior)) -- commented declareFunction (3 3), no body
;; (defun why-sbhl-implied-false-inverse-relation-p (module node not-node &optional mt tv behavior)) -- commented declareFunction (3 3), no body
;; (defun why-sbhl-implied-disjoins-relation-p (module node1 node2 &optional mt tv behavior)) -- commented declareFunction (3 3), no body
