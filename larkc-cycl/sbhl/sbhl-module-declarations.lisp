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

(defun initialize-genls-module ()
  "[Cyc] Initialize the #$genls SBHL module."
  (init-sbhl-module-data #$genls
    (list (list :link-pred #$genls)
          (list :link-style #$DirectedMultigraph)
          (list :naut-forward-true-generators
                '(sbhl-result-genl
                  result-genl-args
                  result-inter-arg-genl
                  result-inter-arg-genl-reln
                  result-genl-via-arg-arg-genl))
          (list :module-type :simple-reflexive)
          (list :type-test 'collection-p)
          (list :disjoins-module #$disjointWith)
          (list :path-terminating-mark?-fn 'sbhl-marked-p)
          (list :marking-fn 'set-sbhl-marking-state-to-marked)
          (list :unmarking-fn 'set-sbhl-marking-state-to-unmarked)
          (list :root #$Thing)
          (list :index-arg 1)))
  nil)

(defun initialize-disjoint-with-module ()
  "[Cyc] Initialize the #$disjointWith SBHL module."
  (init-sbhl-module-data #$disjointWith
    (list (list :link-pred #$disjointWith)
          (list :link-style #$Multigraph)
          (list :module-type :disjoins)
          (list :type-test 'collection-p)
          (list :path-terminating-mark?-fn 'sbhl-marked-p)
          (list :marking-fn 'set-sbhl-marking-state-to-marked)
          (list :unmarking-fn 'set-sbhl-marking-state-to-unmarked)
          (list :index-arg 1)
          (list :transfers-through-module #$genls)
          (list :transfers-via-arg 1)))
  nil)

(defun initialize-isa-module ()
  "[Cyc] Initialize the #$isa SBHL module."
  (init-sbhl-module-data #$isa
    (list (list :link-pred #$isa)
          (list :link-style #$DirectedMultigraph)
          (list :naut-forward-true-generators
                '(sbhl-result-isa
                  result-isa-args
                  result-inter-arg-isa
                  result-inter-arg-isa-reln
                  result-isa-via-arg-arg-isa
                  result-isa-arg-isas
                  result-isa-via-closed-under))
          (list :module-type :transfers-through)
          (list :path-terminating-mark?-fn 'sbhl-marked-p)
          (list :marking-fn 'set-sbhl-marking-state-to-marked)
          (list :unmarking-fn 'set-sbhl-marking-state-to-unmarked)
          (list :index-arg 1)
          (list :transfers-through-module #$genls)
          (list :transfers-via-arg 2)))
  (initialize-isa-arg2-naut-table)
  nil)

(defun initialize-quoted-isa-module ()
  "[Cyc] Initialize the #$quotedIsa SBHL module."
  (init-sbhl-module-data #$quotedIsa
    (list (list :link-pred #$quotedIsa)
          (list :link-style #$DirectedMultigraph)
          (list :naut-forward-true-generators
                '(sbhl-evaluation-result-quoted-isa
                  sbhl-result-quoted-isa))
          (list :module-type :transfers-through)
          (list :path-terminating-mark?-fn 'sbhl-marked-p)
          (list :marking-fn 'set-sbhl-marking-state-to-marked)
          (list :unmarking-fn 'set-sbhl-marking-state-to-unmarked)
          (list :index-arg 1)
          (list :transfers-through-module #$genls)
          (list :transfers-via-arg 2)))
  (initialize-quoted-isa-arg2-naut-table)
  nil)

(defun initialize-genl-mt-module ()
  "[Cyc] Initialize the #$genlMt SBHL module."
  (init-sbhl-module-data #$genlMt
    (list (list :link-pred #$genlMt)
          (list :link-style #$DirectedMultigraph)
          (list :naut-forward-true-generators
                '(sbhl-naut-forward-genl-mts))
          (list :module-type :simple-reflexive)
          (list :type-test 'microtheory-p)
          (list :disjoins-module #$negationMt)
          (list :path-terminating-mark?-fn 'sbhl-marked-p)
          (list :marking-fn 'set-sbhl-marking-state-to-marked)
          (list :unmarking-fn 'set-sbhl-marking-state-to-unmarked)
          (list :root *mt-root*)
          (list :index-arg 1)))
  nil)

(defun initialize-negation-mt-module ()
  "[Cyc] Initialize the #$negationMt SBHL module."
  (init-sbhl-module-data #$negationMt
    (list (list :link-pred #$negationMt)
          (list :link-style #$Multigraph)
          (list :module-type :disjoins)
          (list :type-test 'microtheory-p)
          (list :path-terminating-mark?-fn 'sbhl-marked-p)
          (list :marking-fn 'set-sbhl-marking-state-to-marked)
          (list :unmarking-fn 'set-sbhl-marking-state-to-unmarked)
          (list :index-arg 1)
          (list :transfers-through-module #$genlMt)
          (list :transfers-via-arg 1)))
  nil)

(defun initialize-genl-preds-module ()
  "[Cyc] Initialize the #$genlPreds SBHL module."
  (init-sbhl-module-data #$genlPreds
    (list (list :link-pred #$genlPreds)
          (list :link-style #$DirectedMultigraph)
          (list :module-type :simple-reflexive)
          (list :type-test 'predicate-p)
          (list :disjoins-module #$negationPreds)
          (list :module-inverts-arguments #$genlInverse)
          (list :path-terminating-mark?-fn 'sbhl-predicate-path-termination-p)
          (list :marking-fn 'sbhl-predicate-marking-fn)
          (list :unmarking-fn 'sbhl-predicate-unmarking-fn)
          (list :predicate-search-p t)
          (list :add-node-to-result-test 'not-genl-inverse-mode-p)
          (list :accessible-link-preds (list #$genlPreds #$genlInverse))
          (list :index-arg 1)))
  nil)

(defun initialize-genl-inverse-module ()
  "[Cyc] Initialize the #$genlInverse SBHL module."
  (init-sbhl-module-data #$genlInverse
    (list (list :link-pred #$genlInverse)
          (list :link-style #$DirectedMultigraph)
          (list :module-type :simple-non-reflexive)
          (list :type-test 'predicate-p)
          (list :inverts-arguments-of-module #$genlPreds)
          (list :disjoins-module #$negationInverse)
          (list :path-terminating-mark?-fn 'sbhl-predicate-path-termination-p)
          (list :marking-fn 'sbhl-predicate-marking-fn)
          (list :unmarking-fn 'sbhl-predicate-unmarking-fn)
          (list :predicate-search-p t)
          (list :add-node-to-result-test 'genl-inverse-mode-p)
          (list :accessible-link-preds (list #$genlInverse #$genlPreds))
          (list :index-arg 1)))
  nil)

(defun initialize-negation-preds-module ()
  "[Cyc] Initialize the #$negationPreds SBHL module."
  (init-sbhl-module-data #$negationPreds
    (list (list :link-pred #$negationPreds)
          (list :link-style #$Multigraph)
          (list :module-type :disjoins)
          (list :type-test 'predicate-p)
          (list :module-inverts-arguments #$negationInverse)
          (list :path-terminating-mark?-fn 'sbhl-predicate-path-termination-p)
          (list :marking-fn 'sbhl-predicate-marking-fn)
          (list :unmarking-fn 'sbhl-predicate-unmarking-fn)
          (list :predicate-search-p t)
          (list :add-node-to-result-test 'not-genl-inverse-mode-p)
          (list :accessible-link-preds (list #$negationPreds #$negationInverse))
          (list :index-arg 1)
          (list :transfers-through-module #$genlPreds)
          (list :transfers-via-arg 1)))
  nil)

(defun initialize-negation-inverse-module ()
  "[Cyc] Initialize the #$negationInverse SBHL module."
  (init-sbhl-module-data #$negationInverse
    (list (list :link-pred #$negationInverse)
          (list :link-style #$Multigraph)
          (list :module-type :disjoins)
          (list :type-test 'predicate-p)
          (list :inverts-arguments-of-module #$negationPreds)
          (list :path-terminating-mark?-fn 'sbhl-predicate-path-termination-p)
          (list :marking-fn 'sbhl-predicate-marking-fn)
          (list :unmarking-fn 'sbhl-predicate-unmarking-fn)
          (list :predicate-search-p t)
          (list :add-node-to-result-test 'genl-inverse-mode-p)
          (list :accessible-link-preds (list #$negationInverse #$negationPreds))
          (list :index-arg 1)
          (list :transfers-through-module #$genlPreds)
          (list :transfers-via-arg 1)))
  nil)

;; Variable

(defglobal *sbhl-modules-initialized?* nil
  "[Cyc] Flag for whether the SBHL modules have been initialized.")

(defun sbhl-modules-initialized? ()
  "[Cyc] Return whether the SBHL modules have been initialized."
  *sbhl-modules-initialized?*)

(defun note-sbhl-modules-initialized ()
  "[Cyc] Note that the SBHL modules have been initialized."
  (setf *sbhl-modules-initialized?* t)
  nil)

(defun initialize-sbhl-modules (&optional force?)
  "[Cyc] Initialize all SBHL modules. If FORCE? is non-nil, reinitialize even if already done."
  (when (or force?
            (not (sbhl-modules-initialized?)))
    (reset-sbhl-modules)
    (initialize-genls-module)
    (initialize-disjoint-with-module)
    (initialize-isa-module)
    (initialize-quoted-isa-module)
    (initialize-genl-mt-module)
    (initialize-negation-mt-module)
    (initialize-genl-preds-module)
    (initialize-genl-inverse-module)
    (initialize-negation-preds-module)
    (initialize-negation-inverse-module)
    (note-sbhl-modules-initialized))
  nil)

;; (defun convert-legacy-sbhl-modules-to-structs (&optional force?) ...) -- commented declareFunction (0 1), no body
;; (defun verify-sbhl-modules (&optional verbose?) ...) -- commented declareFunction (0 1), no body
