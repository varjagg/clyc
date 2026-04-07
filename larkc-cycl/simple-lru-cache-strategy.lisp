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

(defstruct (simple-lru-cache-strategy
            (:conc-name "SLRU-CACHESTRAT-")
            (:predicate simple-lru-cache-strategy-p)
            (:constructor make-simple-lru-cache-strategy
                          (&key capacity index payload head tail freelist-head metrics)))
  capacity
  index
  payload
  head
  tail
  freelist-head
  metrics)

(defconstant *dtp-simple-lru-cache-strategy* 'simple-lru-cache-strategy)

(defun simple-lru-cache-strategy-print-function-trampoline (object stream)
  ;; Delegates to print-simple-lru-cache-strategy, which is missing-larkc.
  (missing-larkc 29372))

;; (defun print-simple-lru-cache-strategy (object stream depth) ...) -- active declareFunction, no body
;; (defun new-simple-lru-cache-strategy (capacity &optional metrics) ...) -- active declareFunction, no body
;; (defun clear-simple-lru-cache-strategy (strategy) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-size (strategy) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-capacity (strategy) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-tracked? (strategy object) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-track (strategy object) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-note-reference (strategy object) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-untrack (strategy object) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-peek-most-recent-nth (strategy n) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-peek-most-recent (strategy) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-peek-least-recent (strategy) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-peek-least-recent-nth (strategy n) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-most-recent-items (strategy) ...) -- active declareFunction, no body
;; (defun simple-lru-cache-strategy-least-recent-items (strategy) ...) -- active declareFunction, no body
;; (defun new-simple-lru-cache-current-content-iterator (strategy &optional direction) ...) -- active declareFunction, no body

;; Internal linked-list and index accessors/mutators — all active declareFunction, no body

;; (defun slru-cache-index-datum (index-entry) ...) -- active declareFunction, no body
;; (defun slru-cache-index-backref (index-entry) ...) -- active declareFunction, no body
;; (defun slru-cache-index-fwdref (index-entry) ...) -- active declareFunction, no body
;; (defun slru-cache-payload-size (payload) ...) -- active declareFunction, no body
;; (defun get-slru-cache-index-datum (strategy index) ...) -- active declareFunction, no body
;; (defun get-slru-cache-index-backref (strategy index) ...) -- active declareFunction, no body
;; (defun get-slru-cache-index-fwdref (strategy index) ...) -- active declareFunction, no body
;; (defun get-slru-cache-index-type (index-entry) ...) -- active declareFunction, no body
;; (defun set-slru-cache-payload-index-datum (strategy index datum) ...) -- active declareFunction, no body
;; (defun set-slru-cache-payload-index-backref (strategy index backref) ...) -- active declareFunction, no body
;; (defun set-slru-cache-payload-index-fwdref (strategy index fwdref) ...) -- active declareFunction, no body
;; (defun set-slru-cache-index-datum (strategy index datum) ...) -- active declareFunction, no body
;; (defun set-slru-cache-index-backref (strategy index backref) ...) -- active declareFunction, no body
;; (defun set-slru-cache-index-fwdref (strategy index fwdref) ...) -- active declareFunction, no body

;; Linked list operations — all active declareFunction, no body

;; (defun slru-cache-reset-linked-list (strategy) ...) -- active declareFunction, no body
;; (defun slru-cache-linked-list-dequeue (strategy index) ...) -- active declareFunction, no body
;; (defun slru-cache-linked-list-dequeue-and-resource (strategy index) ...) -- active declareFunction, no body
;; (defun slru-cache-linked-list-insert-new-at-head (strategy datum) ...) -- active declareFunction, no body
;; (defun slru-cache-linked-list-insert-known-at-head (strategy datum index) ...) -- active declareFunction, no body
;; (defun slru-cache-linked-list-insert-recycling-at-head (strategy datum) ...) -- active declareFunction, no body
;; (defun slru-cache-linked-list-recycle-tail-as-head (strategy) ...) -- active declareFunction, no body
;; (defun slru-cache-linked-list-insert-index-at-front (strategy index) ...) -- active declareFunction, no body
;; (defun print-slru-cache-linked-list-status (strategy) ...) -- active declareFunction, no body

;; Freelist operations — all active declareFunction, no body

;; (defun slru-cache-freelist-empty-p (strategy) ...) -- active declareFunction, no body
;; (defun slru-cache-reset-freelist (strategy) ...) -- active declareFunction, no body
;; (defun slru-cache-freelist-dequeue (strategy) ...) -- active declareFunction, no body
;; (defun slru-cache-freelist-enqueue (strategy index) ...) -- active declareFunction, no body

;;; Cache strategy object method implementations
;;; In Java these are registered via Structures.register_method on method tables.
;;; In CL they become defmethod specializations on the CLOS generics from cache-utilities.

(defmethod cache-strategy-object-p ((object simple-lru-cache-strategy))
  t)

(defun cache-strategy-object-reset-simple-lru-cache-strategy-method (strategy)
  ;; Likely delegates to clear-simple-lru-cache-strategy.
  (missing-larkc 29353))

(defun cache-strategy-object-cache-capacity-simple-lru-cache-strategy-method (strategy)
  ;; Likely returns (slru-cachestrat-capacity strategy).
  (missing-larkc 29351))

(defun cache-strategy-object-cache-size-simple-lru-cache-strategy-method (strategy)
  ;; Likely returns (slru-cache-payload-size (slru-cachestrat-payload strategy)).
  (missing-larkc 29352))

(defmethod cache-strategy-object-track ((strategy simple-lru-cache-strategy) object)
  ;; Likely adds the object to the LRU tracking, evicting LRU if at capacity.
  (missing-larkc 29354))

;; (defun cache-strategy-object-tracked?-simple-lru-cache-strategy-method (strategy object) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-untrack-simple-lru-cache-strategy-method (strategy object) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-supports-parameter-p-simple-lru-cache-strategy-method (strategy parameter) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-get-parameter-simple-lru-cache-strategy-method (strategy parameter default) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-set-parameter-simple-lru-cache-strategy-method (strategy parameter value) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-note-reference-simple-lru-cache-strategy-method (strategy object) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-note-references-in-order-simple-lru-cache-strategy-method (strategy objects) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-get-metrics-simple-lru-cache-strategy-method (strategy) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-reset-metrics-simple-lru-cache-strategy-method (strategy) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-gather-metrics-simple-lru-cache-strategy-method (strategy metrics) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-dont-gather-metrics-simple-lru-cache-strategy-method (strategy) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-keeps-metrics-p-simple-lru-cache-strategy-method (strategy) ...) -- active declareFunction, no body
;; (defun new-cache-strategy-object-tracked-content-iterator-simple-lru-cache-strategy-method (strategy) ...) -- active declareFunction, no body
;; (defun map-cache-strategy-object-tracked-content-simple-lru-cache-strategy-method (strategy function) ...) -- active declareFunction, no body
;; (defun cache-strategy-object-untrack-all-simple-lru-cache-strategy-method (strategy function) ...) -- active declareFunction, no body

;;; Delegating "bridge" functions — all active declareFunction, no body
;;; These are the non-method-table versions that delegate to the implementation.

;; (defun cache-strategy-slru-cache-object-cache-capacity (strategy) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-cache-size (strategy) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-dont-gather-metrics (strategy) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-gather-metrics (strategy metrics) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-get-metrics (strategy) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-get-parameter (strategy parameter default) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-keeps-metrics-p (strategy) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-note-reference (strategy object) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-note-references-in-order (strategy objects) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-reset (strategy) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-reset-metrics (strategy) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-set-parameter (strategy parameter value) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-supports-parameter-p (strategy parameter) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-track (strategy object) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-tracked? (strategy object) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-untrack (strategy object) ...) -- active declareFunction, no body
;; (defun cache-strategy-slru-cache-object-untrack-all (strategy function) ...) -- active declareFunction, no body
;; (defun map-cache-strategy-slru-cache-object-tracked-content (strategy function) ...) -- active declareFunction, no body
;; (defun new-cache-strategy-slru-cache-object-tracked-content-iterator (strategy) ...) -- active declareFunction, no body

;;; Test functions — all active declareFunction, no body

;; (defun test-basic-slru-cache-strategy (&optional capacity) ...) -- active declareFunction, no body
;; (defun compare-slru-cache-strategy-with-cache (capacity &optional rounds) ...) -- active declareFunction, no body
;; (defun compare-slru-cache-strategy-speed-with-cache (capacity &optional rounds iterations) ...) -- active declareFunction, no body
;; (defun test-slru-cache-strategy-compare-directions (capacity) ...) -- active declareFunction, no body
;; (defun test-slru-cache-strategy-peek-operators (capacity) ...) -- active declareFunction, no body

;;; Setup phase — define-test-case-table-int calls are elided (macro-helper to nonexistent macro)
