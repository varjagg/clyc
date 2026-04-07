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

;; Variables

(deflexical *sbhl-graph-equality-test* #'eq
  "[Cyc] Temporary -- the equality test used for sbhl-graphs.")

(defglobal *sbhl-backing-file-vector* nil
  "[Cyc] The file vector that backs the SBHL graph.")

(defglobal *sbhl-backing-file-vector-caches-for-modules* nil
  "[Cyc] An ALIST-P that houses the association map from caches on a per-module basis.")

(defparameter *sbhl-backing-file-vector-cache-size-percentage* 2
  "[Cyc] The percentage of the graph size for the module that should be cached in memory.")

(defparameter *sbhl-backing-file-vector-cache-minimum-size* 100
  "[Cyc] The minimal size of the cache, in the case of small population (e.g. #$negationMt or #$successorStrict-HL-TimePrecedence).")

(defparameter *sbhl-backing-file-vector-cache-gather-cache-metrics?* t
  "[Cyc] Whether the caches are supposed to keep metrics of their performance or not.")

(defglobal *sbhl-file-vector-data-stream-lock*
    (bt:make-lock "SBHL File Vector Data Stream lock")
  "[Cyc] The lock for ensuring that CFASL input against the stream is uninterrupted.")

(deflexical *sbhl-backing-file-vector-cache-constructor* 'new-metered-preallocated-cache
  "[Cyc] The allocator to use to get the new caches. Each constructor takes a capacity and an optional equality test.")

(deflexical *default-number-of-concurrent-readers* 20)

(deflexical *default-number-of-terms-checked* 500)

;; Functions — following declare section order

;; (defun optimize-sbhl-store () ...) -- present in original Cyc, not in LarKC
;; (defun sbhl-graph-object-p (object) ...) -- present in original Cyc, not in LarKC

(defun make-new-sbhl-graph ()
  "[Cyc] Create a new SBHL graph (hash table)."
  (make-hash-table :test *sbhl-graph-equality-test*))

;; (defun clear-sbhl-graph (graph) ...) -- present in original Cyc, not in LarKC

(defun initialize-sbhl-graph-caches ()
  "[Cyc] Initialize the SBHL graph caches from file-vector data and index files."
  (let ((data-file (get-hl-store-cache-filename "sbhl-module-graphs" "cfasl"))
        (index-file (get-hl-store-cache-filename "sbhl-module-graphs-index" "cfasl")))
    (if (and (probe-file data-file)
             (probe-file index-file))
        (progn
          (initialize-sbhl-graph-caches-file-vector data-file index-file)
          :initialized)
        :uninitialized)))

;; commented declareFunction, but body present in Java — ported for reference
(defun initialize-sbhl-graph-caches-file-vector (data-file index-file)
  "[Cyc] Initialize the SBHL graph caches from DATA-FILE and INDEX-FILE."
  (when (file-vector-p *sbhl-backing-file-vector*)
    (close-file-vector *sbhl-backing-file-vector*))
  (setf *sbhl-backing-file-vector* (new-file-vector data-file index-file))
  nil)

(defun new-cache-strategy-for-sbhl-module (sbhl-module &optional capacity)
  "[Cyc] Allocate the cache strategy object for the SBHL graph file vector."
  (let* ((cache-capacity (if (non-negative-integer-p capacity)
                             capacity
                             (cache-capacity-for-cache-strategy-for-sbhl-module sbhl-module)))
         (cache-strategy (funcall *sbhl-backing-file-vector-cache-constructor* cache-capacity)))
    (when *sbhl-backing-file-vector-cache-gather-cache-metrics?*
      (cache-strategy-gather-metrics cache-strategy))
    cache-strategy))

(defun get-cache-strategy-for-sbhl-module (sbhl-module)
  "[Cyc] Either fetch or allocate the CACHE-STRATEGY-P for the SBHL module provided.
Assumes that the SBHL lock has already been acquired."
  (let ((cache (alist-lookup-without-values *sbhl-backing-file-vector-caches-for-modules*
                                            sbhl-module)))
    (unless cache
      (setf cache (new-cache-strategy-for-sbhl-module sbhl-module))
      (set-cache-strategy-for-sbhl-module sbhl-module cache))
    cache))

(defun set-cache-strategy-for-sbhl-module (sbhl-module cache-strategy)
  ;; TODO: Java has checkType(cache_strategy, CACHE_STRATEGY_OR_SYMBOL_P)
  (setf *sbhl-backing-file-vector-caches-for-modules*
        (alist-enter *sbhl-backing-file-vector-caches-for-modules*
                     sbhl-module cache-strategy))
  sbhl-module)

(defun cache-capacity-for-cache-strategy-for-sbhl-module (sbhl-module)
  "[Cyc] Compute the cache capacity as a percentage of the known size of the SBHL module
graph, but clamp it to the minimum from below.
@return POSITIVE-INTEGER-P"
  (let* ((graph (get-sbhl-module-graph sbhl-module))
         (graph-size (map-size graph))
         (estimated-cache-size (truncate (* graph-size
                                            *sbhl-backing-file-vector-cache-size-percentage*)
                                         100)))
    (max *sbhl-backing-file-vector-cache-minimum-size* estimated-cache-size)))

;; commented declareFunction, but body present in Java — ported for reference
(defun initialize-sbhl-graph-caches-during-load-kb (data-file index-file)
  "[Cyc] This is called by the load KB command after swapping in the references."
  (initialize-sbhl-graph-caches-file-vector data-file index-file))

;; (defun sbhl-graph-completely-cached? () ...) -- present in original Cyc, not in LarKC
;; (defun get-sbhl-module-caching-ratio (module) ...) -- present in original Cyc, not in LarKC
;; (defun get-sbhl-modules-caching-ratios () ...) -- present in original Cyc, not in LarKC

(defun get-sbhl-graph-link-from-graph (node graph cache)
  "[Cyc] Get the graph link from the graph, potentially swapping it in from the file vector backing."
  (let ((*file-vector-backed-map-read-lock* *sbhl-file-vector-data-stream-lock*)
        (*cfasl-common-symbols* nil))
    (cfasl-set-common-symbols-simple (get-hl-store-caches-shared-symbols))
    (file-vector-backed-map-w/-cache-get graph *sbhl-backing-file-vector* cache node)))

(defun put-sbhl-graph-link-into-graph (node graph cache value)
  "[Cyc] Modify the graph in such a fashion that the file vector backed map can track the modification."
  (let ((*file-vector-backed-map-read-lock* *sbhl-file-vector-data-stream-lock*)
        (*cfasl-common-symbols* nil))
    (cfasl-set-common-symbols-simple (get-hl-store-caches-shared-symbols))
    (file-vector-backed-map-w/-cache-put graph cache node value)))

(defun remove-sbhl-graph-link-from-graph (node graph cache)
  "[Cyc] Remove that node from the graph, with potential modifications that can be tracked by the file vector backing infrastructure."
  (let ((*file-vector-backed-map-read-lock* *sbhl-file-vector-data-stream-lock*)
        (*cfasl-common-symbols* nil))
    (cfasl-set-common-symbols-simple (get-hl-store-caches-shared-symbols))
    (file-vector-backed-map-w/-cache-remove graph cache node)))

(defun touch-sbhl-link-graph (node graph cache)
  "[Cyc] Inform the file vector backing infrastructure that the entry for the node in the graph is mutated."
  (let ((*file-vector-backed-map-read-lock* *sbhl-file-vector-data-stream-lock*)
        (*cfasl-common-symbols* nil))
    (cfasl-set-common-symbols-simple (get-hl-store-caches-shared-symbols))
    (file-vector-backed-map-w/-cache-touch graph cache node *sbhl-backing-file-vector*)))

(defun get-sbhl-graph-link (node module)
  "[Cyc] Accessor: @return direction-link-p; the sbhl-direction-link structure for NODE within graph corresponding to PRED. Uses MODULE / *sbhl-module* to access sbhl graph."
  (declare (type (satisfies sbhl-module-p) module))
  (with-rw-read-lock (*sbhl-rw-lock*)
    (get-sbhl-graph-link-from-graph node
                                    (get-sbhl-graph module)
                                    (get-cache-strategy-for-sbhl-module module))))

(defun set-sbhl-graph-link (node direction-link module)
  "[Cyc] Modifier: Sets the value corresponding to NODE in graph determined by MODULE / *sbhl-module* to DIRECTION-LINK, if it is an sbhl-direction-link-p."
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-check-type direction-link sbhl-direction-link-p)
  (sbhl-check-type node sbhl-node-object-p)
  (with-rw-write-lock (*sbhl-rw-lock*)
    (put-sbhl-graph-link-into-graph node
                                    (get-sbhl-graph module)
                                    (get-cache-strategy-for-sbhl-module module)
                                    direction-link))
  nil)

(defun touch-sbhl-graph-link (node direction-link module)
  "[Cyc] Modifier: Notifies the SBHL swapping infrastructure that the NODE has been modified and that the swapping mechanism needs to treat this as mutated."
  (declare (ignore direction-link)
           (type (satisfies sbhl-module-p) module))
  (sbhl-check-type node sbhl-node-object-p)
  (with-rw-write-lock (*sbhl-rw-lock*)
    (touch-sbhl-link-graph node
                          (get-sbhl-graph module)
                          (get-cache-strategy-for-sbhl-module module)))
  nil)

(defun remove-sbhl-graph-link (node module)
  "[Cyc] Modifier: performs (remhash NODE graph) on graph determined by MODULE / *sbhl-module*."
  (declare (type (satisfies sbhl-module-p) module))
  (with-rw-write-lock (*sbhl-rw-lock*)
    (remove-sbhl-graph-link-from-graph node
                                       (get-sbhl-graph module)
                                       (get-cache-strategy-for-sbhl-module module)))
  nil)

;; TODO: (defmacro do-sbhl-graph-links ((node-var link-var &key module done) &body body) ...)
;; Macro arglist from Internal Constants: ((NODE-VAR LINK-VAR &KEY MODULE DONE) &BODY BODY)
;; Expansion uses WITH-CFASL-COMMON-SYMBOLS-SIMPLE, GET-SBHL-GRAPH, DO-FILE-VECTOR-BACKED-MAP
;; with &ALLOW-OTHER-KEYS and gensym MAP variable

;; (defun swap-in-all-graph-links (module) ...) -- present in original Cyc, not in LarKC

(defun swap-out-all-pristine-graph-links (module)
  (swap-out-all-pristine-file-vector-backed-map-objects (get-sbhl-graph module))
  module)

(defun swap-out-all-pristine-sbhl-module-graph-links ()
  (dolist (sbhl-module (get-sbhl-module-list))
    (swap-out-all-pristine-graph-links sbhl-module))
  t)

;; (defun get-sbhl-module-cache-strategy-metrics (module) ...) -- present in original Cyc, not in LarKC
;; (defun get-all-sbhl-module-cache-strategy-metrics () ...) -- present in original Cyc, not in LarKC
;; (defun get-sbhl-module-cache-strategy-information (module) ...) -- present in original Cyc, not in LarKC
;; (defun show-all-sbhl-module-cache-strategies () ...) -- present in original Cyc, not in LarKC
;; (defun stress-test-sbhl-graph-concurrent-swapping (&optional readers terms) ...) -- present in original Cyc, not in LarKC
;; (defun stress-test-read-randomly-from-sbhl (terms-checked problems) ...) -- present in original Cyc, not in LarKC
;; (defun stress-test-sbhl-graph-concurrent-cache-strategy-update (&optional threads) ...) -- present in original Cyc, not in LarKC
;; (defun stress-test-check-same-specs (node problems mt) ...) -- present in original Cyc, not in LarKC
