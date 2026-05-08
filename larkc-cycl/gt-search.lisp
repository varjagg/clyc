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

;; (defun gt-search-index-arg () ...) -- commented declareFunction, stub with no body
;; (defun gt-search-gather-arg () ...) -- commented declareFunction, stub with no body
;; (defun gt-link-node (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-link-node-and-mt (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-link-values (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-add-to-result (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-link-node (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-link-node-and-mt (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-siblings (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-sibling-node (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-all-accessed (node) ...) -- commented declareFunction, stub with no body
;; (defun tts-all-accessed (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-extremal-accessed (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-extremal-node (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-accesses? (arg1 arg2 &optional arg3) ...) -- commented declareFunction, stub with no body
;; (defun gt-test-link-node (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-node (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-common-horizon (arg1 &optional arg2 arg3) ...) -- commented declareFunction, stub with no body
;; (defun gt-compose-fn-all-accessed (arg1 arg2 &optional arg3) ...) -- commented declareFunction, stub with no body
;; (defun gt-compose-fn-link-node (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-select-all-accessed (arg1 arg2 &optional arg3) ...) -- commented declareFunction, stub with no body
;; (defun gt-select-link-node (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-all-dependent-accessed (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-marked-accessed (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-marked-link-node (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-unselect-all-accessed-as-unsearched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-unselect-link-node-all-accessed-as-unsearched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-compose-pred-all-accessed (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-compose-pred-link-node (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-compose-pred-link-node-int (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-why-accesses? (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-access-just (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-any-access-path (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-access-path (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-min-mts-of-paths (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-maximin-mts-among-lists (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-link-node-and-max-mts (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-link-node-as-unsearched-and-collect-mts (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-as-unsearched-and-collect-all-accessed (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-all-accessed-with-mts (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-link-node-and-store-edges (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-check-for-cycle-edges-to-add () ...) -- commented declareFunction, stub with no body
;; (defun gt-all-edges-to-goal (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-access-all-while-storing-paths (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-link-nodes-and-store-all-paths (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-access-all-while-unifying-mts (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-map-links-rebinding-candidate-mts (arg1 &optional arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-gather-link-nodes-and-unify-mts-along-the-way (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-maxs-of-mt-list (node) ...) -- commented declareFunction, stub with no body
;; (defun is-x-a-path-list-in-y? (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun fort-sets-equal (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun adjudiciate-adding-mt (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-finished (&optional arg1) ...) -- commented declareFunction, stub with no body
;; (defun gt-map-links (arg1 &optional arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-map-assertion-links (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-map-accessors-links (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-map-arg-index (arg1 arg2 arg3 arg4 &optional arg5) ...) -- commented declareFunction, stub with no body
;; (defun gt-gp-mapper (arg1 arg2 arg3 arg4) ...) -- commented declareFunction, stub with no body
;; (defun gt-mapper (arg1 arg2 arg3 arg4 arg5) ...) -- commented declareFunction, stub with no body
;; (defun gt-map-gaf-arg-index-link-nodes (arg1 arg2 arg3 &optional arg4 arg5 arg6) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-as-searched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-as-unsearched (node) ...) -- commented declareFunction, stub with no body

(defun gt-searched? (node)
  (when (gt-term-p node)
    (gethash node *gt-marking-table*)))

;; (defun gt-mark-as-searched-by (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-as-searched-with (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-searched-by? (arg1 arg2 &optional arg3) ...) -- commented declareFunction, stub with no body
;; (defun gt-searched-by-all? (arg1 arg2 &optional arg3) ...) -- commented declareFunction, stub with no body
;; (defun gt-searched-in-target-space? (arg1 &optional arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-as-unsearched-in-space (arg1 &optional arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-as-searched-in-target-space (arg1 arg2 arg3) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-link-node-as-searched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-as-searched-and-step (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-link-node-as-unsearched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-as-unsearched-and-step (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-link-node-as-searched-by (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-as-searched-by-and-step (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-all-superiors-as-searched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-proper-all-superiors-as-searched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-all-inferiors-as-searched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-proper-all-inferiors-as-searched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-all-accessed-as-searched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-proper-all-accessed-as-searched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-all-superiors-as-unsearched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-proper-all-superiors-as-unsearched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-all-inferiors-as-unsearched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-proper-all-inferiors-as-unsearched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-all-accessed-as-unsearched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-proper-all-accessed-as-unsearched (node) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-all-accessed-as-searched-by (arg1 arg2) ...) -- commented declareFunction, stub with no body
;; (defun gt-mark-proper-all-accessed-as-searched-by (arg1 arg2) ...) -- commented declareFunction, stub with no body
