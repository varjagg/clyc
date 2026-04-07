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

;; Convenience macro for kbp state variables, following the def-at-state-var
;; pattern from at-vars.lisp.
(defmacro def-kbp-state-var (name val &body (&optional docstring (definer 'defparameter)))
  `(def-state-var ,name ,val *kbp-state-variables* ,docstring ,definer))

;;; Variables (init phase)

(def-kbp-state-var *kbp-quit?* nil)
(def-kbp-state-var *kbp-result-format* :paths)
(def-kbp-state-var *search-iteration* nil)
(def-kbp-state-var *node-equal?* #'eq)
(def-kbp-state-var *kbp-node?* #'fort-p)
(def-kbp-state-var *kbp-link?* #'assertion-p)
(def-kbp-state-var *kbp-stats* nil)
(def-kbp-state-var *collect-kbp-stats?* t)
(def-kbp-state-var *kbp-node-count* nil)
(def-kbp-state-var *kbp-link-count* nil)
(def-kbp-state-var *kbp-term-count* nil)
(def-kbp-state-var *source-term-args* '(1 2 3 4 5))
;; NOTE: $list16 in Java has (1 2 4 4 5) -- 4 appears twice instead of 3.
;; Preserved as-is from the original source.
(def-kbp-state-var *target-term-args* '(1 2 4 4 5))
(def-kbp-state-var *relevant-node-tree?* #'identity)
(def-kbp-state-var *path-source* nil)
(def-kbp-state-var *path-target* nil)
(def-kbp-state-var *kbp-searcher* nil)
(def-kbp-state-var *kbp-searchers* nil)
(def-kbp-state-var *path-horizon* nil)
(def-kbp-state-var *kbp-common-nodes* nil)
(def-kbp-state-var *path-link-lattice* nil)
(def-kbp-state-var *path-node-lattice* nil)
(def-kbp-state-var *kbp-ancestor* nil)
(def-kbp-state-var *kbp-run-time* nil)
(def-kbp-state-var *node-ancestors* nil)
(def-kbp-state-var *link-ancestors* nil)
(def-kbp-state-var *kbp-depth* nil)
(def-kbp-state-var *kbp-nodes* nil)
(def-kbp-state-var *kbp-links* nil)
(def-kbp-state-var *term-arg* nil)
(def-kbp-state-var *kbp-ancestor-hash* (make-hash-table :size 2048 :test #'equal))
(def-kbp-state-var *kbp-search-hash* (make-hash-table :size 2048))
(def-kbp-state-var *kbp-min-isa-path?* t)
(def-kbp-state-var *kbp-min-genls-path?* t)
(def-kbp-state-var *kbp-designated-node-superiors?* t)
(def-kbp-state-var *kbp-designated-node-superiors* nil)
(def-kbp-state-var *kbp-trace-level* 0)
(def-kbp-state-var *max-search-iterations* 5)
(def-kbp-state-var *limit-path-depth?* t)
(def-kbp-state-var *kbp-max-depth* nil)
(def-kbp-state-var *kbp-max-term-count* 1000)
(def-kbp-state-var *kbp-quit-with-success?* nil)
(def-kbp-state-var *kbp-only-gaf-links?* t)
(def-kbp-state-var *kbp-no-bookkeeping-links?* t)
(def-kbp-state-var *kbp-no-instance-links?* t)
(def-kbp-state-var *kbp-no-bi-scoping-links?* nil)
(def-kbp-state-var *kbp-explode-nats?* nil)
(def-kbp-state-var *kbp-designated-preds?* t)
(def-kbp-state-var *kbp-designated-preds* nil)
(def-kbp-state-var *kbp-restricted-preds?* t)
(def-kbp-state-var *kbp-restricted-preds* nil)
(def-kbp-state-var *kbp-restricted-mts?* nil)
(def-kbp-state-var *kbp-restricted-mts* (list (reader-make-constant-shell "EnglishMt")))
(def-kbp-state-var *kbp-external-link-pred?* nil)
(def-kbp-state-var *kbp-external-link-pred* nil)
(def-kbp-state-var *kbp-genl-bound?* t)
(def-kbp-state-var *kbp-genl-bound* nil)
(def-kbp-state-var *kbp-genls-cardinality-delta-bound?* t)
(def-kbp-state-var *kbp-genls-cardinality-delta-bound* 20)
(def-kbp-state-var *kbp-isa-bound?* t)
(def-kbp-state-var *kbp-isa-bound* nil)
(def-kbp-state-var *kbp-node-isa-bound?* t)
(def-kbp-state-var *kbp-node-isa-bound* nil)
(def-kbp-state-var *kbp-restricted-nodes-as-arg?* t)
(def-kbp-state-var *kbp-restricted-nodes-as-arg*
    (list (list (reader-make-constant-shell "quotedCollection") 1)))
(def-kbp-state-var *kbp-link-reference-set-bound?* t)
(def-kbp-state-var *kbp-link-reference-set-bound* nil)
(def-kbp-state-var *kbp-designated-link-references?* t)
(def-kbp-state-var *kbp-designated-link-references* nil)
(def-kbp-state-var *kbp-bound-gaf-terms?* t)
(def-kbp-state-var *kbp-bound-gaf-terms* '(0))
(def-kbp-state-var *kbp-bound-link-terms?* t)
(def-kbp-state-var *kbp-bound-link-terms* nil)
(def-kbp-state-var *kbp-use-max-mts?* nil)
(def-kbp-state-var *nodes-accessor-fn* nil)
(def-kbp-state-var *path-link-op* nil)
(def-kbp-state-var *path-node-op* nil)
(def-kbp-state-var *relevant-link?* nil)
(def-kbp-state-var *relevant-node?* nil)
(def-kbp-state-var *relevant-link-tree?* nil)
(def-kbp-state-var *exclude-nodes* nil)
(def-kbp-state-var *exclude-links* nil)

;; CR (conceptually-related) variables
(def-kbp-state-var *cr-paths-table* (make-hash-table :size 1024))
(def-kbp-state-var *cr-gaf-count* 0)
(def-kbp-state-var *cr-explained-count* 0)
(def-kbp-state-var *cr-error-count* 0)

;;; Functions (declare phase)

;; The single active declareFunction with a body
(defun fort-name (fort)
  (cond
    ((constant-p fort) (constant-name fort))
    ((nart-p fort)
     ;; Likely returns a string representation of the NART -- evidence:
     ;; parallel to constant-name for constants.
     (missing-larkc 7493))
    (t nil)))

;; Commented-out declareFunction stubs -- all bodies were stripped.

;; (defun kb-paths (source target &optional mt) ...) -- commented declareFunction, no body
;; (defun kb-paths-n (source target &optional mt) ...) -- commented declareFunction, no body
;; (defun kb-paths-in-all-mts (source target) ...) -- commented declareFunction, no body
;; (defun kb-paths-in-just-mt (source target mt) ...) -- commented declareFunction, no body
;; (defun find-paths (&optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun complete-paths-home (&optional arg1) ...) -- commented declareFunction, no body
;; (defun complete-paths-home-from-link (link) ...) -- commented declareFunction, no body
;; (defun complete-paths-home-from-node (node) ...) -- commented declareFunction, no body
;; (defun extract-paths (&optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun kbp-result () ...) -- commented declareFunction, no body
;; (defun kbp-result-links () ...) -- commented declareFunction, no body
;; (defun kbp-result-paths () ...) -- commented declareFunction, no body
;; (defun linearize-lattice (lattice) ...) -- commented declareFunction, no body
;; (defun gather-node-lattice (&optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun gather-link-lattice (link &optional arg1) ...) -- commented declareFunction, no body
;; (defun kbp-neighbors-among (node nodes &optional arg1) ...) -- commented declareFunction, no body
;; (defun kbp-node-links (node) ...) -- commented declareFunction, no body
;; (defun kbp-link-nodes (link) ...) -- commented declareFunction, no body
;; (defun kbp-connecting-links (node1 node2) ...) -- commented declareFunction, no body
;; (defun kbp-node-neighbors (node) ...) -- commented declareFunction, no body
;; (defun kbp-legal-link? (link) ...) -- commented declareFunction, no body
;; (defun kbp-legal-node? (node) ...) -- commented declareFunction, no body
;; (defun ancestor-link? (link) ...) -- commented declareFunction, no body
;; (defun ancestor-node? (node) ...) -- commented declareFunction, no body
;; (defun kbp-under-limit (&optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun mark-next-horizon (searcher &optional arg1 arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun default-link-op (link &optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun default-node-op (node &optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun do-link-nodes (link &optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun default-relevant-link? (link) ...) -- commented declareFunction, no body
;; (defun default-relevant-node? (node) ...) -- commented declareFunction, no body
;; (defun kbp-beyond-genls-cardinality-delta-bound? (node) ...) -- commented declareFunction, no body
;; (defun kbp-beyond-genl-bound? (node) ...) -- commented declareFunction, no body
;; (defun kbp-beyond-isa-bound? (node) ...) -- commented declareFunction, no body
;; (defun kbp-undesignated-node-superior? (node) ...) -- commented declareFunction, no body
;; (defun kbp-node-restricted-as-arg? (node) ...) -- commented declareFunction, no body
;; (defun kbp-node-beyond-isa-bound? (node) ...) -- commented declareFunction, no body
;; (defun kbp-gaf-term-beyond-bound? (link) ...) -- commented declareFunction, no body
;; (defun kbp-undesignated-pred-assertion? (link) ...) -- commented declareFunction, no body
;; (defun kbp-restricted-pred-assertion? (link) ...) -- commented declareFunction, no body
;; (defun kbp-restricted-mt-assertion? (link) ...) -- commented declareFunction, no body
;; (defun kbp-link-terms-beyond-reference-set-bound? (link) ...) -- commented declareFunction, no body
;; (defun kbp-link-terms-w/o-references? (link) ...) -- commented declareFunction, no body
;; (defun kbp-link-satisfies-external-pred? (link) ...) -- commented declareFunction, no body
;; (defun kbp-link-term-beyond-bound? (link) ...) -- commented declareFunction, no body
;; (defun kbp-link-w/o-max-mt? (link) ...) -- commented declareFunction, no body
;; (defun kbp-bi-scoping-link? (link) ...) -- commented declareFunction, no body
;; (defun kbp-bi-scoping-link-1? (link) ...) -- commented declareFunction, no body
;; (defun kbp-bi-scoping-node? (node) ...) -- commented declareFunction, no body
;; (defun kbp-bi-scoping-node-1? (node) ...) -- commented declareFunction, no body
;; (defun scope-direction (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun default-relevant-link-tree? (tree) ...) -- commented declareFunction, no body
;; (defun do-if-term-assertions (term &optional arg1 arg2 arg3) ...) -- commented declareFunction, no body
;; (defun obsolete-tree-do-if (tree fn &optional arg1 arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun assertion-indexed-by (assertion term) ...) -- commented declareFunction, no body
;; (defun all-assertion-terms (assertion &optional arg1) ...) -- commented declareFunction, no body
;; (defun all-assertion-references (assertion &optional arg1) ...) -- commented declareFunction, no body
;; (defun clear-kb-paths () ...) -- commented declareFunction, no body
;; (defun kbp-stats (arg1) ...) -- commented declareFunction, no body
;; (defun kbp-node-count () ...) -- commented declareFunction, no body
;; (defun kbp-link-count () ...) -- commented declareFunction, no body
;; (defun kbp-searched-object-count (arg1) ...) -- commented declareFunction, no body
;; (defun next-iteration () ...) -- commented declareFunction, no body
;; (defun kbp-give-up? (arg1 arg2 arg3) ...) -- commented declareFunction, no body
;; (defun kbp-exhausted? (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun kbp-iteration-bound-met? (arg1) ...) -- commented declareFunction, no body
;; (defun kbp-term-bound-met? () ...) -- commented declareFunction, no body
;; (defun paths-link-count (paths) ...) -- commented declareFunction, no body
;; (defun kbp-searcher? (arg1) ...) -- commented declareFunction, no body
;; (defun equal-nodes? (node1 node2 &optional arg1) ...) -- commented declareFunction, no body
;; (defun instance-btree? (btree) ...) -- commented declareFunction, no body
;; (defun bookkeeping-btree? (btree) ...) -- commented declareFunction, no body
;; (defun kbp-record-ancestor (arg1 &optional arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun kbp-ancestors (arg1 &optional arg2) ...) -- commented declareFunction, no body
;; (defun kbp-ancestors-via-all (arg1 &optional arg2) ...) -- commented declareFunction, no body
;; (defun kbp-ancestor? (arg1 &optional arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun kbp-ancestor-via-any? (arg1 &optional arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun kbp-searched? (arg1) ...) -- commented declareFunction, no body
;; (defun kbp-searched-by? (arg1 &optional arg2 arg3) ...) -- commented declareFunction, no body
;; (defun kbp-searched-by-all? (arg1 &optional arg2 arg3) ...) -- commented declareFunction, no body
;; (defun kbp-searched-by-any? (arg1 &optional arg2 arg3) ...) -- commented declareFunction, no body
;; (defun kbp-searched-by (arg1) ...) -- commented declareFunction, no body
;; (defun kbp-all-searched-by (&optional arg1) ...) -- commented declareFunction, no body
;; (defun kbp-mark-as-searched-by (arg1 &optional arg2 arg3) ...) -- commented declareFunction, no body
;; (defun kbp-mark-as-unsearched-by (arg1 &optional arg2 arg3) ...) -- commented declareFunction, no body
;; (defun kbp-mark-as-searched-by-all (arg1 &optional arg2 arg3) ...) -- commented declareFunction, no body
;; (defun kbp-mark-as-unsearched-by-all (arg1 &optional arg2 arg3) ...) -- commented declareFunction, no body
;; (defun kbp-mark-all-as-unsearched (arg1) ...) -- commented declareFunction, no body
;; (defun kbp-mark-as-unsearched (arg1) ...) -- commented declareFunction, no body
;; (defun kbp-all-searched-by-all (&optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun bookkeeping-gaf-assertion? (assertion) ...) -- commented declareFunction, no body
;; (defun kbp-excluded-node? (node) ...) -- commented declareFunction, no body
;; (defun kbp-excluded-link? (link) ...) -- commented declareFunction, no body
;; (defun kbp-paths-links (paths) ...) -- commented declareFunction, no body
;; (defun kbp-path-links (path) ...) -- commented declareFunction, no body
;; (defun kbp-paths-tuples (paths) ...) -- commented declareFunction, no body
;; (defun kbp-path-tuples (path) ...) -- commented declareFunction, no body
;; (defun kbp-justs-from-tuples (tuples) ...) -- commented declareFunction, no body
;; (defun kbp-just-from-tuples (tuples) ...) -- commented declareFunction, no body
;; (defun kbp-just-from-tuple (tuple) ...) -- commented declareFunction, no body
;; (defun make-gaf-assertion (assertion) ...) -- commented declareFunction, no body
;; (defun kbp-note (level format-string &optional arg1 arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun kbp-error (level format-string &optional arg1 arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun kbp-warn (level format-string &optional arg1 arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun kbp-min-isa-paths (source target &optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun kbp-min-genls-paths (source target &optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun kbp-min-genl-mt-paths (source target &optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun explain-cr-pair (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun explain-cr-gafs-via-paths (&optional arg1) ...) -- commented declareFunction, no body
;; (defun explain-cr-gaf-via-paths (gaf) ...) -- commented declareFunction, no body
;; (defun cr-paths-status () ...) -- commented declareFunction, no body
;; (defun evaluate-cr-path (arg1 arg2 arg3 &optional arg4) ...) -- commented declareFunction, no body
;; (defun fort-name< (fort1 fort2) ...) -- commented declareFunction, no body
;; (defun assertions-fi-equal? (assertion1 assertion2) ...) -- commented declareFunction, no body
;; (defun assertions-fi-formulae (assertions) ...) -- commented declareFunction, no body
;; (defun focuses (col &optional arg1 arg2 arg3 arg4) ...) -- commented declareFunction, no body
;; (defun genls-gather-focus-preds-cols (col) ...) -- commented declareFunction, no body
;; (defun remove-genls-of-all (cols &optional arg1) ...) -- commented declareFunction, no body
;; (defun remove-common-spec-path (cols &optional arg1) ...) -- commented declareFunction, no body
;; (defun remove-common-spec-path-wrt (cols col &optional arg1) ...) -- commented declareFunction, no body
;; (defun remove-specs-of-all (cols &optional arg1) ...) -- commented declareFunction, no body
;; (defun remove-common-genl-path (cols &optional arg1) ...) -- commented declareFunction, no body
;; (defun remove-common-genl-path-wrt (cols col &optional arg1) ...) -- commented declareFunction, no body
;; (defun candidate-focus-collections (col &optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun candidate-focus-collections-strategy-middle (col &optional arg1) ...) -- commented declareFunction, no body
;; (defun candidate-focus-collections-strategy-edge (col &optional arg1) ...) -- commented declareFunction, no body
;; (defun appraise-candidate-focuses (candidates &optional arg1) ...) -- commented declareFunction, no body
;; (defun genls-focus-min-preds (col focus &optional arg1 arg2) ...) -- commented declareFunction, no body
;; (defun genls-gather-focus-preds-of (col) ...) -- commented declareFunction, no body
;; (defun meta-pred-specs (pred &optional arg1) ...) -- commented declareFunction, no body
