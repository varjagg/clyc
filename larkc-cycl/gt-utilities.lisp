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

(defun gt-term-p (obj)
  "[Cyc] @return booleanp; Whether OBJ is a valid term in GT searches."
  (if (reified-term-p obj)
      t
      nil))

;; (defun gt-mode? (mode) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun gt-type-fn (mode) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun gt-reflexive? () ...) -- 0 required, 0 optional; commented declareFunction, no body
;; (defun gt-index-arg-ok? (arg) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun gt-gather-arg-ok? (arg) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun tt-index-arg-ok? (arg) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun tt-gather-arg-ok? (arg) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun gt-either-arg-ok? (arg) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun gt-type-violation (term predicate) ...) -- 2 required, 0 optional; commented declareFunction, no body
;; (defun gt-assertion-type-violation (term predicate) ...) -- 2 required, 0 optional; commented declareFunction, no body
;; (defun make-gt-search-space (&optional size) ...) -- 0 required, 1 optional; commented declareFunction, no body
;; (defun gt-not-all-predecessors-searched? (node) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun gt-all-predecessors-searched? (node) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun gt-each-link-node? (node) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun gt-check-type-internal (arg1 arg2 arg3) ...) -- 3 required, 0 optional; commented declareFunction, no body
;; (defun gt-step-fn-funcall (node) ...) -- 1 required, 0 optional; commented declareFunction, no body
;; (defun gt-compare-fn-funcall (arg1 arg2) ...) -- 2 required, 0 optional; commented declareFunction, no body
;; (defun gt-gp-mapper-funcall (arg1 arg2) ...) -- 2 required, 0 optional; commented declareFunction, no body
;; (defun gt-note (level format-string &optional arg1 arg2 arg3 arg4 arg5) ...) -- 2 required, 5 optional; commented declareFunction, no body
;; (defun gt-error (level format-string &optional arg1 arg2 arg3 arg4 arg5) ...) -- 2 required, 5 optional; commented declareFunction, no body
;; (defun gt-cerror (continue-string level format-string &optional arg1 arg2 arg3 arg4 arg5) ...) -- 3 required, 5 optional; commented declareFunction, no body
;; (defun gt-warn (level format-string &optional arg1 arg2 arg3 arg4 arg5) ...) -- 2 required, 5 optional; commented declareFunction, no body
