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

(defun init-sbhl-module-data (predicate data)
  "[Cyc] Modifier: initialize and store the DATA for PREDICATE. DATA is an alist"
  (declare (type (satisfies fort-p) predicate))
  (let ((module (new-sbhl-module predicate)))
    (dolist (data-association data)
      (let ((property (first data-association))
            (property-data (second data-association)))
        (set-sbhl-module-property module property property-data)))
    (new-sbhl-module-graph module)
    (add-sbhl-module predicate module))
  nil)

(defun-cached get-sbhl-predicates () (:test eq)
  (get-sbhl-predicates-internal))

;; (defun remove-get-sbhl-predicates ()) -- commented declareFunction, no body

(defun get-sbhl-predicates-internal ()
  (get-sbhl-predicates-int))

(defun sbhl-predicate-p (object)
  "[Cyc] Whether PRED is a member of *sbhl-predicates*"
  (member-eq? object (get-sbhl-predicates)))

;; (defun sbhl-module-or-predicate-p (object)) -- commented declareFunction, no body
;; (defun sbhl-non-time-module-p (object)) -- commented declareFunction, no body

(defun sbhl-non-time-predicate-p (object)
  "[Cyc] Whether PRED is a member of *sbhl-predicates* and not an sbhl-time-module"
  (and (sbhl-predicate-p object)
       (not (sbhl-time-module-p (get-sbhl-module object)))
       t))

;; (defun sbhl-graph-p (object)) -- commented declareFunction, no body

(defun get-sbhl-link-pred (module)
  "[Cyc] Accessor: the link predicate associated with MODULE / *sbhl-module*"
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-mod-link-pred module))

(defun get-sbhl-link-style (module)
  "[Cyc] Accessor: whether MODULE / *sbhl-module* entails directed or undirected direction links"
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-mod-link-style module))

;; (defun get-sbhl-module-naut-forward-true-generators (module)) -- commented declareFunction, no body

(defun get-sbhl-module-type (module)
  "[Cyc] Accessor: the type of module that MODULE / *sbhl-module* is."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-mod-module-type module))

(defun get-sbhl-path-terminating-mark?-fn (module)
  "[Cyc] Accessor: the function determining whether to terminate a search path, associated with MODULE / *sbhl-module*"
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-mod-path-terminating-mark-fn module))

(defun get-sbhl-marking-fn (module)
  "[Cyc] Accessor: the marking function associated with MODULE / *sbhl-module*"
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-mod-marking-fn module))

(defun get-sbhl-unmarking-fn (module)
  "[Cyc] Accessor: the unmarking function associated with MODULE / *sbhl-module*"
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-mod-unmarking-fn module))

;; (defun get-sbhl-module-marking-increment (module)) -- commented declareFunction, no body

(defun get-sbhl-index-arg (module)
  "[Cyc] Accessor: the number corresponding to the index-arg position for MODULE / *sbhl-module*."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-mod-index-arg module))

;; (defun get-sbhl-gather-arg (module)) -- commented declareFunction, no body

(defun get-sbhl-add-node-to-result-test (module)
  "[Cyc] Accessor: the function applied to a node's marking before pushing it onto the result"
  (declare (type (satisfies sbhl-module-p) module))
  (get-sbhl-module-property module :add-node-to-result-test))

;; (defun get-sbhl-add-unmarked-node-to-result-test (module)) -- commented declareFunction, no body

(defun get-sbhl-type-test (module)
  "[Cyc] Accessor: the function used to test the type of objects used in *sbhl-module* / MODULE"
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-mod-type-test module))

;; (defun get-sbhl-module-root (module)) -- commented declareFunction, no body
;; (defun get-sbhl-transfers-via-arg (module)) -- commented declareFunction, no body

(defun get-sbhl-accessible-link-preds (module)
  "[Cyc] Accessor: the list of sbhl predicates allowed by MODULE / *sbhl-module* for following links."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-mod-accessible-link-preds module))

(defun sbhl-module-indicates-predicate-search-p (module)
  "[Cyc] Accessor: whether module indicates a predicate search."
  (declare (type (satisfies sbhl-module-p) module))
  (get-sbhl-module-property module :predicate-search-p))

;; (defun get-sbhl-node-modules (object)) -- commented declareFunction, no body

(defun sbhl-disjoins-search-p ()
  "[Cyc] Accessor: whether the current search module is a disjoins module"
  (sbhl-disjoins-module-type-p (get-sbhl-search-module-type)))

(defun sbhl-time-search-p ()
  "[Cyc] Accessor: whether the current module is a time module."
  (sbhl-time-module-type-p (get-sbhl-search-module-type)))

;; (defun sbhl-root-p (node module)) -- commented declareFunction, no body
;; (defun get-sbhl-inverse-link-module (module)) -- commented declareFunction, no body
;; (defun get-sbhl-module-relevant-naut-link-generators (arg1 arg2 arg3)) -- commented declareFunction, no body

(defun sbhl-simple-module-p (module)
  "[Cyc] Accessor: does module type of MODULE / *sbhl-module* satisfy
sbhl-simple-reflexive-module-type-p or sbhl-simple-non-reflexive-module-type-p."
  (declare (type (satisfies sbhl-module-p) module))
  (or (sbhl-simple-reflexive-module-type-p (get-sbhl-module-type module))
      (sbhl-simple-non-reflexive-module-type-p (get-sbhl-module-type module))))

(defun sbhl-time-module-p (module)
  "[Cyc] Accessor: does module type of MODULE / *sbhl-module* satisfy sbhl-time-module-type-p."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-time-module-type-p (get-sbhl-module-type module)))

(defun sbhl-transitive-module-p (module)
  "[Cyc] Accessor: does module type of MODULE / *sbhl-module* satisfy sbhl-transitive-module-type-p"
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-transitive-module-type-p (get-sbhl-module-type module)))

(defun sbhl-inverse-module-p (module)
  "[Cyc] Accessor: is MODULE / *sbhl-module* one which is defined by the fact that it inverts the argument order of another module."
  (declare (type (satisfies sbhl-module-p) module))
  (and (get-sbhl-module-which-this-module-inverts-arguments-of module) t))

;; (defun get-sbhl-inverse-module (module)) -- commented declareFunction, no body
;; (defun get-sbhl-module-with-inverted-arguments (module)) -- commented declareFunction, no body

(defun get-sbhl-module-which-this-module-inverts-arguments-of (module)
  "[Cyc] Accessor: the module which MODULE / *sbhl-module* inverts arguments of."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((inverts-arguments-of-module (get-sbhl-module-property module :inverts-arguments-of-module)))
    (cond
      ((sbhl-module-p inverts-arguments-of-module)
       inverts-arguments-of-module)
      ((null inverts-arguments-of-module)
       nil)
      ((sbhl-predicate-p inverts-arguments-of-module)
       (setf inverts-arguments-of-module (get-sbhl-module inverts-arguments-of-module))
       (set-sbhl-module-property module :inverts-arguments-of-module inverts-arguments-of-module)
       inverts-arguments-of-module)
      (t nil))))

;; (defun get-sbhl-module-tag (module)) -- commented declareFunction, no body

(defun new-sbhl-module-graph (module)
  "[Cyc] Modifier: stores a hash-table in the :graph field of MODULE"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((graph (make-new-sbhl-graph)))
    (set-sbhl-module-property module :graph graph))
  module)

(defun get-sbhl-graph (module)
  "[Cyc] Accessor: the table containing the graph corresponding to link predicate of MODULE / *sbhl-module*."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-mod-graph module))

;; (defun get-sbhl-graphs ()) -- commented declareFunction, no body

(defun sbhl-disjoins-module-p (module)
  "[Cyc] Accessor: does module type of MODULE / *sbhl-module* satisfy sbhl-disjoins-module-type-p."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-disjoins-module-type-p (get-sbhl-module-type module)))

(defun get-sbhl-disjoins-module (module)
  "[Cyc] Accessor: the associated module to MODULE / *sbhl-module* for disjoins."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((disjoins-module (get-sbhl-module-property module :disjoins-module)))
    (cond
      ((sbhl-module-p disjoins-module)
       disjoins-module)
      ((null disjoins-module)
       nil)
      ((sbhl-predicate-p disjoins-module)
       (setf disjoins-module (get-sbhl-module disjoins-module))
       (set-sbhl-module-property module :disjoins-module disjoins-module)
       disjoins-module)
      (t nil))))

(defun sbhl-transfers-through-module-p (module)
  "[Cyc] Accessor: does module type of MODULE / *sbhl-module* satisfy sbhl-transfers-through-module-type-p."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-transfers-through-module-type-p (get-sbhl-module-type module)))

(defun get-sbhl-transfers-through-module (module)
  "[Cyc] Returns the module, if any, that MODULE uses to transfer through."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((tt-module (get-sbhl-module-property module :transfers-through-module)))
    (cond
      ((sbhl-module-p tt-module)
       tt-module)
      ((null tt-module)
       nil)
      ((sbhl-predicate-p tt-module)
       (setf tt-module (get-sbhl-module tt-module))
       (set-sbhl-module-property module :transfers-through-module tt-module)
       tt-module)
      (t nil))))

(defun sbhl-reflexive-module-p (module)
  "[Cyc] Accessor: whether MODULE is for a reflexive predicate or not."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-simple-reflexive-module-type-p (get-sbhl-module-type module)))

(defun get-sbhl-disjoins-search-tt-module (module)
  "[Cyc] Accessor: if current search is a disjoins search, returns the module it transfers through."
  (declare (type (satisfies sbhl-module-p) module))
  (if (sbhl-disjoins-module-p module)
      (get-sbhl-transfers-through-module module)
      module))

(defun get-sbhl-reductions-module (module)
  "[Cyc] Accessor: module for minimizations and maximizations."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((tt-module (get-sbhl-transfers-through-module module))
        (search-module (or module (get-sbhl-search-module))))
    (if tt-module
        tt-module
        (if (eq (sbhl-mod-link-pred search-module) #$genlInverse)
            (get-sbhl-module #$genlPreds)
            search-module))))

(defun get-sbhl-premark-module (module)
  "[Cyc] Accessor: the module corresponding to MODULE to be used for premarking in searches."
  (declare (type (satisfies sbhl-module-p) module))
  (if (sbhl-disjoins-module-p module)
      (get-sbhl-transfers-through-module module)
      module))

;; (defun sbhl-search-direction-p (direction)) -- commented declareFunction, no body
;; (defun sbhl-forward-direction-for-module-p (direction module)) -- commented declareFunction, no body

(defun get-sbhl-module-forward-direction (module)
  "[Cyc] Accessor: the keyword that relates MODULE / *sbhl-module* to either :predicate or :link direction"
  (declare (type (satisfies sbhl-module-p) module))
  (if (sbhl-module-directed-links? module)
      (get-sbhl-forward-directed-direction)
      (get-sbhl-undirected-direction)))

(defun get-sbhl-module-backward-direction (module)
  "[Cyc] Accessor: the keyword that relates MODULE to either :inverse or :link direction"
  (declare (type (satisfies sbhl-module-p) module))
  (if (sbhl-module-directed-links? module)
      (get-sbhl-backward-directed-direction)
      (get-sbhl-undirected-direction)))

;; (defun get-sbhl-opposite-search-direction (&optional direction)) -- commented declareFunction, no body

(defun sbhl-module-directed-links? (module)
  "[Cyc] Accessor: whether MODULE / *sbhl-module* is a directed or undirected graph"
  (declare (type (satisfies sbhl-module-p) module))
  (fort-denotes-sbhl-directed-graph-p (get-sbhl-link-style module)))

(defun sbhl-search-direction-to-link-direction (direction module)
  "[Cyc] Accessor: the keyword for links in direction DIRECTION corresponding to MODULE / *sbhl-module*."
  (declare (type (satisfies sbhl-module-p) module))
  (cond
    ((sbhl-forward-search-direction-p direction)
     (get-sbhl-module-forward-direction module))
    ((sbhl-backward-search-direction-p direction)
     (get-sbhl-module-backward-direction module))
    (t
     (sbhl-error 1 "invalid sbhl-search-direction ~a" direction)
     nil)))

;; (defun sbhl-search-direction-to-opposite-link-direction (direction module)) -- commented declareFunction, no body

(defun get-relevant-sbhl-directions (module)
  "[Cyc] Accessor: list of the keywords for relevant directions for links of MODULE / *sbhl-module*. If *sbhl-link-direction* is specified, it will return with a list of either the forward-direction for MODULE / *sbhl-module* or the backward-direction for MODULE / *sbhl-module*"
  (declare (type (satisfies sbhl-module-p) module))
  (if (and (get-sbhl-link-direction) module)
      ;; TODO - this was a missing-larkc 2481 call; likely sbhl-search-direction-to-link-direction
      ;; called with (get-sbhl-link-direction) and module, returning a list of the result
      (missing-larkc 2481)
      (if (sbhl-module-directed-links? module)
          (get-sbhl-directed-directions)
          (get-sbhl-undirected-direction-as-list))))

(defun sbhl-predicate-cardinality (module node)
  "[Cyc] The cardinality of NODE with MODULE in the predicate direction"
  (declare (type (satisfies sbhl-module-p) module))
  (if (not (sbhl-node-object-p node))
      0
      (genl-cardinality node)))

(defun sbhl-inverse-cardinality (module node)
  "[Cyc] The cardinality of NODE with PRED in the inverse direction"
  (declare (type (satisfies sbhl-module-p) module))
  (if (not (sbhl-node-object-p node))
      0
      (spec-cardinality node)))

;; (defun sbhl-module-hl-support-module (module)) -- commented declareFunction, no body
;; (defun sbhl-pred-hl-support-module (pred)) -- commented declareFunction, no body
;; (defun sbhl-old-mode (arg1 arg2)) -- commented declareFunction, no body

(defun sbhl-pred-get-hl-module (pred)
  (declare (type (satisfies sbhl-predicate-p) pred))
  (cond
    ((eq pred #$genls) :genls)
    ((eq pred #$isa) :isa)
    ((eq pred #$quotedIsa) :isa)
    ((eq pred #$genlPreds) :genlpreds)
    ((eq pred #$genlInverse) :genlpreds)
    ((eq pred #$genlMt) :genlmt)
    ((eq pred #$disjointWith) :disjointwith)
    ((eq pred #$negationPreds) :negationpreds)
    ((eq pred #$negationInverse) :negationpreds)
    ((eq pred #$negationMt) :genlmt)
    (t nil)))

;; (defun sbhl-old-module (module)) -- commented declareFunction, no body
;; (defun sbhl-predicate-for-hl-module (hl-module)) -- commented declareFunction, no body
;; (defun sbhl-predicate-from-fort-type (fort-type)) -- commented declareFunction, no body
;; (defun sbhl-node-has-type-associated-to-predicate-p (node predicate)) -- commented declareFunction, no body
;; (defun determine-sbhl-predicate-from-fort-type (fort-type &optional arg)) -- commented declareFunction, no body
;; (defun determine-sbhl-module-from-fort-type (fort-type &optional arg)) -- commented declareFunction, no body
;; (defun sbhl-node-with-any-sbhl-type-p (node &optional arg)) -- commented declareFunction, no body
;; (defun sbhl-fort? (fort)) -- commented declareFunction, no body

(defun sbhl-isa-collection-p (node)
  (isa-collection? (naut-to-nart node)))

(defun sbhl-isa-microtheory-p (node)
  (isa-mt? (naut-to-nart node)))

(defun sbhl-isa-predicate-p (node)
  (isa-predicate? (naut-to-nart node)))

(defun apply-sbhl-module-type-test (node module)
  "[Cyc] @hack reduce funcalls. Applies to NODE the get-sbhl-module-type-test."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((test-fn (get-sbhl-type-test module)))
    (if test-fn
        (cond
          ((eq test-fn 'collection-p) (sbhl-isa-collection-p node))
          ((eq test-fn 'microtheory-p) (sbhl-isa-microtheory-p node))
          ((eq test-fn 'predicate-p) (sbhl-isa-predicate-p node))
          (t nil))
        t)))

;; (defun sbhl-module-meets-requisites? (module)) -- commented declareFunction, no body
