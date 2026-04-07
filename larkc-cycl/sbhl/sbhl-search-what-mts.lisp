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


;; The current mts gathered along the path to goal
(defparameter *sbhl-path-mts* nil)

;; Reconstructed macro: sbhl-rebind-path-mts
;; Internal Constants evidence:
;;   $list0 = (MT &BODY BODY) — arglist
;;   $sym1$CLET, $sym2$*SBHL-PATH-MTS*, $sym3$POSSIBLY_UPDATE_SBHL_PATH_MTS, $list4 = (*SBHL-PATH-MTS*) — body uses clet to rebind *sbhl-path-mts*
;; Reconstruction: binds *sbhl-path-mts* to (possibly-update-sbhl-path-mts mt *sbhl-path-mts*), executes body
(defmacro sbhl-rebind-path-mts (mt &body body)
  `(let ((*sbhl-path-mts* (possibly-update-sbhl-path-mts ,mt *sbhl-path-mts*)))
     ,@body))

(defun possibly-update-sbhl-path-mts (mt path-mts)
  "[Cyc] Returns PATH-MTS updated with MT if MT is non-nil and not already a member."
  (if mt
      (if (member-eq? mt path-mts)
          path-mts
          (cons mt path-mts))
      path-mts))

;; Hashtable used during what mts search to store path mts to a node
(defparameter *sbhl-what-mts-mt-paths* nil)

;; Hashtable used during what mts search to store inverse path mts to a node
(defparameter *sbhl-what-mts-inverse-mt-paths* nil)

;; Store for path mts results for straightforward searches
(defparameter *sbhl-primary-what-mts-mt-paths* nil)

;; Store for inverse path mts results for straightforward searches
(defparameter *sbhl-primary-what-mts-inverse-mt-paths* nil)

;; Store for path mts results for searches which require two marking spaces
(defparameter *sbhl-secondary-what-mts-mt-paths* nil)

;; Store for inverse path mts results for searches which require two marking spaces
(defparameter *sbhl-secondary-what-mts-inverse-mt-paths* nil)

;; Reconstructed macro: with-new-sbhl-what-mts-marking-spaces
;; Internal Constants evidence:
;;   $list6 = ((*sbhl-primary-what-mts-mt-paths* (instantiate-sbhl-marking-space))
;;             (*sbhl-primary-what-mts-inverse-mt-paths* (instantiate-sbhl-marking-space))
;;             (*sbhl-secondary-what-mts-mt-paths* (instantiate-sbhl-marking-space))
;;             (*sbhl-secondary-what-mts-inverse-mt-paths* (instantiate-sbhl-marking-space)))
;; Reconstruction: clet binding all four what-mts spaces to fresh marking spaces
(defmacro with-new-sbhl-what-mts-marking-spaces (&body body)
  `(let ((*sbhl-primary-what-mts-mt-paths* (instantiate-sbhl-marking-space))
         (*sbhl-primary-what-mts-inverse-mt-paths* (instantiate-sbhl-marking-space))
         (*sbhl-secondary-what-mts-mt-paths* (instantiate-sbhl-marking-space))
         (*sbhl-secondary-what-mts-inverse-mt-paths* (instantiate-sbhl-marking-space)))
     ,@body))

(defun sbhl-primary-what-mts-spaces ()
  "[Cyc] Accessor: returns the keyword :primary. used to determine which what-mts-paths to use."
  :primary)

;; (defun sbhl-secondary-what-mts-spaces () ...) -- commented declareFunction (0 0), no body

;; Reconstructed macro: within-sbhl-what-mts-spaces
;; Internal Constants evidence:
;;   $list9 = (SPACE-ID &BODY BODY)
;;   $sym10$*SBHL-WHAT-MTS-MT-PATHS*, $sym11$FIF, $list12 = (:PRIMARY),
;;   $list13 = (*SBHL-PRIMARY-WHAT-MTS-MT-PATHS* *SBHL-SECONDARY-WHAT-MTS-MT-PATHS*)
;;   $sym14$*SBHL-WHAT-MTS-INVERSE-MT-PATHS*,
;;   $list15 = (*SBHL-PRIMARY-WHAT-MTS-INVERSE-MT-PATHS* *SBHL-SECONDARY-WHAT-MTS-INVERSE-MT-PATHS*)
;; Reconstruction: binds *sbhl-what-mts-mt-paths* and *sbhl-what-mts-inverse-mt-paths*
;; based on whether space-id is :primary
(defmacro within-sbhl-what-mts-spaces (space-id &body body)
  `(let ((*sbhl-what-mts-mt-paths* (if (eq ,space-id :primary)
                                       *sbhl-primary-what-mts-mt-paths*
                                       *sbhl-secondary-what-mts-mt-paths*))
         (*sbhl-what-mts-inverse-mt-paths* (if (eq ,space-id :primary)
                                               *sbhl-primary-what-mts-inverse-mt-paths*
                                               *sbhl-secondary-what-mts-inverse-mt-paths*)))
     ,@body))

(defun get-sbhl-what-mts-marking-space ()
  "[Cyc] Accessor: @return hash-table-p; the space for what mts marking. @hack genl-inverse-mode-p."
  (if (genl-inverse-mode-p)
      *sbhl-what-mts-inverse-mt-paths*
      *sbhl-what-mts-mt-paths*))

(defun get-sbhl-what-mts-marking (node)
  "[Cyc] Accessor: @return listp; the current what mts marking for NODE. @hack genl-inverse-mode-p."
  (if (genl-inverse-mode-p)
      (gethash node *sbhl-what-mts-inverse-mt-paths*)
      (gethash node *sbhl-what-mts-mt-paths*)))

(defun sbhl-what-mts-mark-mt-paths-to-node (node)
  "[Cyc] Modifier. changes the mt-path marking for NODE based on *sbhl-path-mts*.
*sbhl-path-mts* is added to the what-mts-marking for NODE, and every path which is a
proper superset of *sbhl-path-mts* is removed from the marking."
  (let ((what-mts-space (get-sbhl-what-mts-marking-space))
        (redundant-mt-paths nil))
    (dolist (mt-path (get-sbhl-what-mts-marking node))
      (when (proper-subsetp *sbhl-path-mts* mt-path)
        (push mt-path redundant-mt-paths)))
    (dolist (mt-path redundant-mt-paths)
      (delete-hash node mt-path what-mts-space #'equal))
    (push-hash node *sbhl-path-mts* what-mts-space))
  nil)

(defun sbhl-what-mts-marking-subsumes-marking-p (node)
  "[Cyc] Accessor. @return booleanp; whether the current *sbhl-path-mts* is a superset
of the path-mts markings of NODE."
  (dolist (mt-path (get-sbhl-what-mts-marking node))
    (when (subsetp mt-path *sbhl-path-mts*)
      (return t))))

(defun determine-sbhl-link-mt (node link-node)
  "[Cyc] Determines the link mt for NODE to LINK-NODE."
  (declare (ignore link-node))
  (if (or (fort-p node)
          (and (consp node)
               ;; missing-larkc 10356 — likely naut-p or reifiable-nat? check,
               ;; since this tests whether a cons-form node has a valid link mt
               (missing-larkc 10356)))
      (get-sbhl-link-mt)
      nil))

(defparameter *sbhl-verify-naut-mt-relevance* nil)

;; (defun sbhl-encountered-difficult-naut-mt-generator () ...) -- commented declareFunction (0 0), no body

;; Reconstructed macro: with-new-naut-mt-relevance-verification
;; Internal Constants evidence:
;;   $list16 = ((*SBHL-VERIFY-NAUT-MT-RELEVANCE* NIL))
;; Reconstruction: binds *sbhl-verify-naut-mt-relevance* to nil
(defmacro with-new-naut-mt-relevance-verification (&body body)
  `(let ((*sbhl-verify-naut-mt-relevance* nil))
     ,@body))

(defun sbhl-verify-naut-mt-relevance-p ()
  "[Cyc] Returns *sbhl-verify-naut-mt-relevance*."
  *sbhl-verify-naut-mt-relevance*)

;; Function used in multistep searches
(defparameter *sbhl-what-mts-map-function* nil)

;; Reconstructed macro: with-sbhl-what-mts-map-function
;; Internal Constants evidence:
;;   $list17 = (FN &BODY BODY)
;;   $sym18$*SBHL-WHAT-MTS-MAP-FUNCTION*
;; Reconstruction: binds *sbhl-what-mts-map-function* to fn
(defmacro with-sbhl-what-mts-map-function (fn &body body)
  `(let ((*sbhl-what-mts-map-function* ,fn))
     ,@body))

(defun get-sbhl-what-mts-map-function ()
  "[Cyc] Accessor: returns *sbhl-what-mts-map-function*."
  *sbhl-what-mts-map-function*)

(defun sbhl-what-mts-not-mapping-p ()
  "[Cyc] Accessor: @return booleanp; whether *sbhl-what-mts-map-function* is null."
  (null *sbhl-what-mts-map-function*))

(defun sbhl-apply-what-mts-map-function (node)
  "[Cyc] @hack reduces funcalls. applies *sbhl-what-mts-map-function* to NODE."
  ;; TODO - defmethod: case dispatch on map-fn symbol
  (let ((map-fn (get-sbhl-what-mts-map-function)))
    (when map-fn
      (case map-fn
        (sbhl-false-what-mts-step
         ;; missing-larkc 1920 — sbhl-false-what-mts-step, called during false what-mts searches
         (missing-larkc 1920))
        (sbhl-false-what-mts-sweep
         ;; missing-larkc 1921 — sbhl-false-what-mts-sweep, called during false what-mts searches
         (missing-larkc 1921))
        (sbhl-what-mts-tt-sweep
         (sbhl-what-mts-tt-sweep node))
        (sbhl-what-mts-tt-step
         ;; missing-larkc 1963 — sbhl-what-mts-tt-step, step phase of transfers-through what-mts
         (missing-larkc 1963))
        (sbhl-what-mts-step-across-marked-disjoins
         ;; missing-larkc 1953 — sbhl-what-mts-step-across-marked-disjoins, disjoin step search
         (missing-larkc 1953))
        (sbhl-what-mts-sweep-marked-disjoins
         ;; missing-larkc 1960 — sbhl-what-mts-sweep-marked-disjoins, disjoin sweep search
         (missing-larkc 1960))
        (sbhl-what-mts-sweep-forward-step-and-sweep-false-disjoins
         ;; missing-larkc 1958 — sbhl-what-mts-sweep-forward-step-and-sweep-false-disjoins
         (missing-larkc 1958))
        (sbhl-what-mts-sweep-false-disjoins
         ;; missing-larkc 1957 — sbhl-what-mts-sweep-false-disjoins
         (missing-larkc 1957))
        (otherwise
         (funcall map-fn node)))))
  nil)

;; the goal node for a what mts search
(defparameter *sbhl-what-mts-goal* nil)

(defun get-sbhl-what-mts-goal ()
  "[Cyc] @return sbhl-node-object-p; *sbhl-what-mts-goal*."
  *sbhl-what-mts-goal*)

;; Reconstructed macro: with-sbhl-what-mts-goal
;; Internal Constants evidence:
;;   $list27 = (NODE &BODY BODY)
;;   $sym28$*SBHL-WHAT-MTS-GOAL*
;; Reconstruction: binds *sbhl-what-mts-goal* to node
(defmacro with-sbhl-what-mts-goal (node &body body)
  `(let ((*sbhl-what-mts-goal* ,node))
     ,@body))

(defun sbhl-what-mts-goal-p (node)
  "[Cyc] Accessor: @return booleanp; whether the search context allows goal checking
and if NODE is the *sbhl-what-mts-goal*."
  (if (sbhl-what-mts-not-mapping-p)
      (let ((add-node-test (get-sbhl-search-add-node-test))
            (check-goal? t))
        (when add-node-test
          (setf check-goal? (funcall add-node-test)))
        (when check-goal?
          (eq node *sbhl-what-mts-goal*)))
      nil))

;; (defun sbhl-what-mts-proper-mark-p (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-what-mts-proper-goal-mark-p (node) ...) -- commented declareFunction (1 0), no body

(defun sbhl-what-mts-mark-and-sweep (node)
  "[Cyc] Modifier. recursive workhorse that accumulates mt paths from NODE to goal."
  (unless (sbhl-what-mts-marking-subsumes-marking-p node)
    (sbhl-what-mts-mark-mt-paths-to-node node)
    (sbhl-apply-what-mts-map-function node)
    (unless (sbhl-what-mts-goal-p node)
      (dolist (module-var (get-sbhl-accessible-modules (get-sbhl-module)))
        (let ((*sbhl-module* module-var)
              (*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                         (not *genl-inverse-mode-p*)
                                         *genl-inverse-mode-p*)))
          (with-relevant-sbhl-link-nodes (link-nodes node
                                          (get-sbhl-link-direction)
                                          (get-sbhl-module))
            (dolist (link-node link-nodes)
              (sbhl-rebind-path-mts (determine-sbhl-link-mt node link-node)
                (sbhl-what-mts-mark-and-sweep link-node))))))))
  nil)

;; (defun sbhl-what-mts-mark-and-sweep-marked-nodes (node) ...) -- commented declareFunction (1 0), no body

(defun sbhl-what-mts-step-across-links (node)
  "[Cyc] Modifier. steps across links, updating the mt path."
  (dolist (module-var (get-sbhl-accessible-modules (get-sbhl-module)))
    (let ((*sbhl-module* module-var)
          (*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                     (not *genl-inverse-mode-p*)
                                     *genl-inverse-mode-p*)))
      (with-relevant-sbhl-link-nodes (link-nodes node
                                      (get-sbhl-link-direction)
                                      (get-sbhl-module))
        (dolist (link-node link-nodes)
          (sbhl-rebind-path-mts (determine-sbhl-link-mt node link-node)
            (sbhl-apply-what-mts-map-function link-node))))))
  nil)

;; (defun sbhl-what-mts-step-across-marked-links (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-what-mts-step-and-update-links (node) ...) -- commented declareFunction (1 0), no body

(defun sbhl-what-mts-sweep (module link-direction tv spaces map-fn node)
  "[Cyc] Binds its arguments in setup for sbhl-what-mts-mark-and-sweep."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((*sbhl-module* module)
        (*sbhl-link-direction* link-direction)
        (*sbhl-tv* tv)
        (*sbhl-what-mts-mt-paths* (if (eq spaces :primary)
                                      *sbhl-primary-what-mts-mt-paths*
                                      *sbhl-secondary-what-mts-mt-paths*))
        (*sbhl-what-mts-inverse-mt-paths* (if (eq spaces :primary)
                                              *sbhl-primary-what-mts-inverse-mt-paths*
                                              *sbhl-secondary-what-mts-inverse-mt-paths*))
        (*sbhl-what-mts-map-function* map-fn))
    (sbhl-what-mts-mark-and-sweep node))
  nil)

;; (defun sbhl-what-mts-sweep-marked (module link-direction tv spaces map-fn marking node) ...) -- commented declareFunction (7 0), no body

(defun sbhl-what-mts-step (module link-direction tv map-fn node)
  "[Cyc] Binds its arguments in setup for sbhl-what-mts-step-across-links."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((*sbhl-module* module)
        (*sbhl-link-direction* link-direction)
        (*sbhl-tv* tv)
        (*sbhl-what-mts-map-function* map-fn))
    (sbhl-what-mts-step-across-links node))
  nil)

;; (defun sbhl-what-mts-step-marked (module link-direction tv map-fn marking node) ...) -- commented declareFunction (6 0), no body
;; (defun sbhl-what-mts-step-and-update-mts (module link-direction tv map-fn marking node) ...) -- commented declareFunction (6 0), no body

(defun sbhl-simple-true-what-mts-search (node)
  "[Cyc] Used for true what mts searches of simple predicates, sweeping nodes accessible to NODE."
  (sbhl-what-mts-sweep (get-sbhl-search-module)
                       (get-sbhl-link-direction)
                       (sbhl-search-true-tv)
                       (sbhl-primary-what-mts-spaces)
                       nil
                       node)
  nil)

;; (defun sbhl-simple-false-what-mts-search (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-false-what-mts-step (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-false-what-mts-sweep (node) ...) -- commented declareFunction (1 0), no body

(defun sbhl-tt-what-mts-search (node)
  "[Cyc] Used for forward transfers through what mts searches. Steps across accessible links."
  (sbhl-what-mts-step (get-sbhl-search-module)
                      (get-sbhl-module-forward-direction (get-sbhl-search-module))
                      (get-sbhl-tv)
                      'sbhl-what-mts-tt-sweep
                      node)
  nil)

(defun sbhl-what-mts-tt-sweep (node)
  "[Cyc] Used as second part of forward transfers through what mts searches.
Sweeps all nodes accessible to NODE."
  (sbhl-what-mts-sweep (get-sbhl-transfers-through-module (get-sbhl-search-module))
                       (if (sbhl-true-search-p)
                           (get-sbhl-link-direction)
                           (get-sbhl-opposite-link-direction))
                       (sbhl-search-true-tv)
                       (sbhl-primary-what-mts-spaces)
                       nil
                       node)
  nil)

;; (defun sbhl-what-mts-tt-backward-search (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-what-mts-tt-step (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-what-mts-premark-disjoins (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-what-mts-true-disjoins-search (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-what-mts-step-across-marked-disjoins (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-what-mts-sweep-marked-disjoins (node) ...) -- commented declareFunction (1 0), no body
;; (defun get-sbhl-what-mts-sweep-disjoins-module () ...) -- commented declareFunction (0 0), no body
;; (defun sbhl-what-mts-false-disjoins-search (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-what-mts-sweep-forward-step-and-sweep-false-disjoins (node) ...) -- commented declareFunction (1 0), no body
;; (defun sbhl-what-mts-sweep-false-disjoins (node) ...) -- commented declareFunction (1 0), no body

(defun determine-sbhl-what-mts-behavior (module direction tv)
  "[Cyc] Accessor: @return function-spec-p. Returns the name of the search function to call,
as determined by PRED's type, DIRECTION, and TV."
  (declare (type (satisfies sbhl-module-p) module))
  (cond
    ((sbhl-simple-module-p module)
     (if (sbhl-true-tv-p tv)
         'sbhl-simple-true-what-mts-search
         'sbhl-simple-false-what-mts-search))
    ((sbhl-transfers-through-module-p module)
     (if (sbhl-forward-search-direction-p direction)
         'sbhl-tt-what-mts-search
         'sbhl-what-mts-tt-backward-search))
    ((sbhl-disjoins-module-p module)
     (if (sbhl-true-tv-p tv)
         'sbhl-what-mts-true-disjoins-search
         'sbhl-what-mts-false-disjoins-search))
    (t
     (sbhl-error 1 "Search behavior not recognized. Sorry."))))

;; The initial function to call for what-mts search.
(defparameter *sbhl-what-mts-behavior* nil)

(defun get-sbhl-what-mts-behavior ()
  "[Cyc] Accessor. @return function-spec-p. *sbhl-what-mts-behavior*."
  *sbhl-what-mts-behavior*)

;; Reconstructed macro: bind-sbhl-what-mts-behavior
;; Internal Constants evidence:
;;   $list42 = ((*SBHL-WHAT-MTS-BEHAVIOR* (DETERMINE-SBHL-WHAT-MTS-BEHAVIOR
;;               (GET-SBHL-SEARCH-MODULE) (GET-SBHL-SEARCH-DIRECTION) (GET-SBHL-TV))))
;; Reconstruction: binds *sbhl-what-mts-behavior* to the determined behavior
(defmacro bind-sbhl-what-mts-behavior (&body body)
  `(let ((*sbhl-what-mts-behavior* (determine-sbhl-what-mts-behavior
                                    (get-sbhl-search-module)
                                    (get-sbhl-search-direction)
                                    (get-sbhl-tv))))
     ,@body))

(defun sbhl-apply-what-mts-behavior (node)
  "[Cyc] @hack reduces funcalls. applies to NODE *sbhl-what-mts-behavior*."
  ;; TODO - defmethod: case dispatch on behavior symbol
  (let ((behavior (get-sbhl-what-mts-behavior)))
    (case behavior
      (sbhl-simple-true-what-mts-search
       (sbhl-simple-true-what-mts-search node))
      (sbhl-simple-false-what-mts-search
       ;; missing-larkc 1946 — sbhl-simple-false-what-mts-search
       (missing-larkc 1946))
      (sbhl-tt-what-mts-search
       (sbhl-tt-what-mts-search node))
      (sbhl-what-mts-tt-backward-search
       ;; missing-larkc 1962 — sbhl-what-mts-tt-backward-search
       (missing-larkc 1962))
      (sbhl-what-mts-true-disjoins-search
       ;; missing-larkc 1961 — sbhl-what-mts-true-disjoins-search
       (missing-larkc 1961))
      (sbhl-what-mts-false-disjoins-search
       ;; missing-larkc 1947 — sbhl-what-mts-false-disjoins-search
       (missing-larkc 1947))
      (otherwise
       (sbhl-error 1 "Unsupported what mts behavior ~a" behavior))))
  nil)

(defun sbhl-what-mts-terminating-space ()
  "[Cyc] Accessor. @return keywordp; the tag indicating which set of marking spaces
holds the correct marking information for the goal."
  ;; TODO - defmethod: case dispatch on behavior symbol
  (let ((behavior (get-sbhl-what-mts-behavior)))
    (case behavior
      (sbhl-simple-true-what-mts-search
       (sbhl-primary-what-mts-spaces))
      (sbhl-simple-false-what-mts-search
       ;; missing-larkc 1942 — terminating space for simple false search
       (missing-larkc 1942))
      (sbhl-tt-what-mts-search
       (sbhl-primary-what-mts-spaces))
      (sbhl-what-mts-tt-backward-search
       ;; missing-larkc 1943 — terminating space for tt backward search
       (missing-larkc 1943))
      (sbhl-what-mts-true-disjoins-search
       ;; missing-larkc 1944 — terminating space for true disjoins search
       (missing-larkc 1944))
      (sbhl-what-mts-false-disjoins-search
       ;; missing-larkc 1945 — terminating space for false disjoins search
       (missing-larkc 1945))
      (otherwise
       (sbhl-error 1 "Unsupported what mts behavior ~a" behavior)))))

(defun sbhl-what-mts-final-mt-paths (node)
  "[Cyc] @hack explicitly references behavior for #$genlInverse and #$negationInverse.
Accessor: @return listp; the final path mts for NODE."
  (let ((result nil))
    (within-sbhl-what-mts-spaces (sbhl-what-mts-terminating-space)
      (if (or (eq (get-sbhl-module-link-pred (get-sbhl-search-module)) #$genlInverse)
              (eq (get-sbhl-module-link-pred (get-sbhl-search-module)) #$negationInverse))
          (setf result (gethash node *sbhl-what-mts-inverse-mt-paths*))
          (setf result (gethash node *sbhl-what-mts-mt-paths*))))
    result))

(defun sbhl-what-mts-goal-final-mt-paths ()
  "[Cyc] Accessor: @return listp; the list of path mts for *sbhl-what-mts-goal*.
See sbhl-what-mts-final-mt-paths."
  (sbhl-what-mts-final-mt-paths (get-sbhl-what-mts-goal)))

(defun sbhl-predicate-mt-paths (module node goal-node &optional tv)
  "[Cyc] @return listp; the mt paths from NODE to GOAL-NODE via MODULE, optionally constrained by TV."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil)
        (*sbhl-search-module* module)
        (*sbhl-search-module-type* (get-sbhl-module-type module))
        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
        (*genl-inverse-mode-p* nil)
        (*sbhl-module* module))
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
                            (setf result (sbhl-what-mt-paths-from-node-to-node node goal-node))))
                     (when (eq source :resource)
                       (update-sbhl-resourced-spaces *sbhl-gather-space*))))
              (when (eq source :resource)
                (update-sbhl-resourced-spaces *sbhl-space*)))))))
    result))

;; (defun sbhl-inverse-mt-paths (module node goal-node &optional tv) ...) -- commented declareFunction (3 1), no body
;; (defun sbhl-false-predicate-mt-paths (module node goal-node &optional tv) ...) -- commented declareFunction (3 1), no body
;; (defun sbhl-false-inverse-mt-paths (module node goal-node &optional tv) ...) -- commented declareFunction (3 1), no body

(defun sbhl-what-mt-paths-from-node-to-node (node1 node2)
  "[Cyc] @return listp; the mt paths from NODE1 to NODE2."
  (let ((result nil))
    (if (equal node1 node2)
        (setf result (list (list *mt-root*)))
        (let ((*sbhl-search-type* :what-mts)
              (*relevant-mt-function* 'relevant-mt-is-everything)
              (*mt* #$EverythingPSC)
              (*sbhl-primary-what-mts-mt-paths* (instantiate-sbhl-marking-space))
              (*sbhl-primary-what-mts-inverse-mt-paths* (instantiate-sbhl-marking-space))
              (*sbhl-secondary-what-mts-mt-paths* (instantiate-sbhl-marking-space))
              (*sbhl-secondary-what-mts-inverse-mt-paths* (instantiate-sbhl-marking-space))
              (*sbhl-what-mts-goal* node2)
              (*sbhl-what-mts-behavior* (determine-sbhl-what-mts-behavior
                                         (get-sbhl-search-module)
                                         (get-sbhl-search-direction)
                                         (get-sbhl-tv))))
          (sbhl-apply-what-mts-behavior node1)
          (setf result (sbhl-what-mts-goal-final-mt-paths))))
    result))

(defun sbhl-min-mt-paths (mt-paths)
  "[Cyc] @return listp; the minimal mts of each of the path mts in MT-PATHS."
  (let ((result nil))
    (dolist (mt-path mt-paths)
      (setf mt-path (minimize-mts-wrt-core mt-path))
      (let ((min-mts-of-path (sbhl-min-nodes (get-sbhl-module #$genlMt) mt-path))
            (fail? nil))
        (unless fail?
          (dolist (result-mt-path result)
            (when (subsetp result-mt-path min-mts-of-path)
              (setf fail? t)
              (return))
            (when (and (not fail?)
                       (subsetp min-mts-of-path result-mt-path))
              (setf result (remove result-mt-path result :test #'equal)))))
        (unless fail?
          (push min-mts-of-path result))))
    result))

(defun sbhl-min-mts-of-predicate-paths (module node goal-node &optional tv)
  "[Cyc] @return listp; the list of independent mts for which there is a true MODULE
relation between NODE and GOAL-NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-min-mt-paths (sbhl-predicate-mt-paths module node goal-node tv)))

;; (defun sbhl-min-mts-of-inverse-paths (module node goal-node &optional tv) ...) -- commented declareFunction (3 1), no body
;; (defun sbhl-min-mts-of-false-predicate-paths (module node goal-node &optional tv) ...) -- commented declareFunction (3 1), no body
;; (defun sbhl-min-mts-of-false-inverse-paths (module node goal-node &optional tv) ...) -- commented declareFunction (3 1), no body

(defun sbhl-max-floor-mts (mts)
  "[Cyc] helper for sbhl-max-floor-mts-of-paths."
  (sbhl-max-floors (get-sbhl-module #$genlMt) mts))

(defun sbhl-max-floor-mts-of-paths (paths)
  "[Cyc] @return listp; the most general mt(s) by which all of PATH's mts are visible."
  (let ((result nil)
        (*sbhl-verify-naut-mt-relevance* nil))
    (setf result (sbhl-max-nodes (get-sbhl-module #$genlMt)
                                 (reduce #'union
                                         (delete nil (mapcar #'sbhl-max-floor-mts paths))
                                         :initial-value nil)))
    (when (sbhl-verify-naut-mt-relevance-p)
      (sbhl-warn 1 "Mts might not be valid because initial node was a NAUT which used complicated link generation."))
    result))

(defun sbhl-max-floor-mts-of-predicate-paths (module node goal-node &optional tv)
  "[Cyc] @return listp; the most general mt(s) by which all true MODULE relations
between NODE and GOAL-NODE are visible."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-max-floor-mts-of-paths (sbhl-min-mts-of-predicate-paths module node goal-node tv)))

;; (defun sbhl-max-floor-mts-of-inverse-paths (module node goal-node &optional tv) ...) -- commented declareFunction (3 1), no body
;; (defun sbhl-max-floor-mts-of-false-predicate-paths (module node goal-node &optional tv) ...) -- commented declareFunction (3 1), no body
;; (defun sbhl-max-floor-mts-of-false-inverse-paths (module node goal-node &optional tv) ...) -- commented declareFunction (3 1), no body
;; (defun sbhl-mt-table-of-floors-for-predicate-path (module node goal-node &optional tv marking) ...) -- commented declareFunction (3 2), no body
;; (defun sbhl-floors-in-space (module mts space &optional tv marking) ...) -- commented declareFunction (3 2), no body
;; (defun sbhl-closure-intersection-in-space (module space) ...) -- commented declareFunction (2 0), no body
;; (defun sbhl-sort-by-least-inverse-cardinality (nodes &optional module) ...) -- commented declareFunction (1 1), no body
;; (defun sbhl-inverse-cardinality< (node1 node2) ...) -- commented declareFunction (2 0), no body


;;;; Setup

(register-macro-helper 'possibly-update-sbhl-path-mts 'sbhl-rebind-path-mts)
