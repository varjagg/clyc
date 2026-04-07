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

(defstruct (forward-propagate (:conc-name "fpmt-"))
  old-queue
  new-queue)

(defmethod print-object ((object forward-propagate) stream)
  ;; Likely calls print-forward-propagate, which is missing-larkc 35122
  (if (forward-propagate-p object)
      (format stream "<Forward Propagate old=~a new=~a"
              (fpmt-old-queue object)
              (fpmt-new-queue object))
      (format stream "<Invalid Forward Propagate ~s>" object)))

(defconstant *dtp-forward-propagate* 'forward-propagate)

;; (defun print-forward-propagate (object stream depth) ...) -- active declareFunction, no body
;; (defun new-forward-propagate (&optional mt) ...) -- active declareFunction, no body
;; (defun forward-propagate-old-queue (forward-propagate) ...) -- active declareFunction, no body
;; (defun set-forward-propagate-old-queue (forward-propagate queue) ...) -- active declareFunction, no body
;; (defun clear-forward-propagate-old-queue (forward-propagate) ...) -- active declareFunction, no body
;; (defun forward-propagate-new-queue (forward-propagate) ...) -- active declareFunction, no body
;; (defun set-forward-propagate-new-queue (forward-propagate queue) ...) -- active declareFunction, no body
;; (defun swap-forward-propagate-queues (forward-propagate) ...) -- active declareFunction, no body
;; (defun enqueue-forward-propagate-assertions-to-new-queue (forward-propagate assertions) ...) -- active declareFunction, no body
;; (defun dequeue-forward-propagate-assertion-from-old-queue (forward-propagate) ...) -- active declareFunction, no body

(defun destroy-forward-propagate (forward-propagate)
  (when (forward-propagate-p forward-propagate)
    ;; Likely calls forward-propagate-old-queue to get queue, then clears it
    (clear-queue (missing-larkc 35119))
    ;; Likely calls forward-propagate-new-queue to get queue, then clears it
    (clear-queue (missing-larkc 35118))
    ;; Likely sets old-queue to :free via set-forward-propagate-old-queue or _csetf
    (missing-larkc 35111)
    ;; Likely sets new-queue to :free via set-forward-propagate-new-queue or _csetf
    (missing-larkc 35108))
  nil)
