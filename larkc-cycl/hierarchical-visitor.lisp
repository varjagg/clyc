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

(deflexical *default-hierarchical-visitor-noop-callback* #'false
  "[Cyc] The default value to use for a hierarchical visitor when the callback is not supposed to do anything.")

;; print-object is missing-larkc 30458 — CL's default print-object handles this.
(defstruct (hierarchical-visitor (:conc-name "HIER-VISIT-"))
  begin-path-fn
  end-path-fn
  accept-node-fn
  begin-visit-fn
  end-visit-fn
  param)

(defconstant *dtp-hierarchical-visitor* 'hierarchical-visitor)

;; hierarchical-visitor-p - active declareFunction, provided by defstruct (1 0)
;; hier-visit-begin-path-fn - active declareFunction, provided by defstruct (1 0)
;; hier-visit-end-path-fn - active declareFunction, provided by defstruct (1 0)
;; hier-visit-accept-node-fn - active declareFunction, provided by defstruct (1 0)
;; hier-visit-begin-visit-fn - active declareFunction, provided by defstruct (1 0)
;; hier-visit-end-visit-fn - active declareFunction, provided by defstruct (1 0)
;; hier-visit-param - active declareFunction, provided by defstruct (1 0)
;; _csetf-hier-visit-begin-path-fn - active declareFunction, provided by defstruct via (setf hier-visit-begin-path-fn) (2 0)
;; _csetf-hier-visit-end-path-fn - active declareFunction, provided by defstruct via (setf hier-visit-end-path-fn) (2 0)
;; _csetf-hier-visit-accept-node-fn - active declareFunction, provided by defstruct via (setf hier-visit-accept-node-fn) (2 0)
;; _csetf-hier-visit-begin-visit-fn - active declareFunction, provided by defstruct via (setf hier-visit-begin-visit-fn) (2 0)
;; _csetf-hier-visit-end-visit-fn - active declareFunction, provided by defstruct via (setf hier-visit-end-visit-fn) (2 0)
;; _csetf-hier-visit-param - active declareFunction, provided by defstruct via (setf hier-visit-param) (2 0)
;; make-hierarchical-visitor - active declareFunction, provided by defstruct (0 1)

;; (defun print-hierachical-visitor (object stream depth) ...) -- active declareFunction, no body

;; (defun new-hiearchical-visitor (begin-path-fn end-path-fn accept-node-fn begin-visit-fn end-visit-fn &optional param) ...) -- active declareFunction, no body

;; (defun new-simple-hierarchical-visitor (begin-path-fn accept-node-fn end-path-fn &optional param) ...) -- active declareFunction, no body

;; (defun hierarchical-visitor-begin-visit (visitor) ...) -- active declareFunction, no body

;; (defun hierarchical-visitor-end-visit (visitor) ...) -- active declareFunction, no body

;; (defun show-hierarchical-visitor-node (visitor node) ...) -- active declareFunction, no body

;; (defun show-hierarchical-visitor-path-begin (visitor path) ...) -- active declareFunction, no body

;; (defun show-hierarchical-visitor-path-end (visitor path) ...) -- active declareFunction, no body

;; (defun set-hierarchical-visitor-parameter (visitor param) ...) -- active declareFunction, no body

;; (defun get-hierarchical-visitor-parameter (visitor) ...) -- active declareFunction, no body

;; (defun new-hierarchical-print-visitor () ...) -- active declareFunction, no body

;; (defun print-hier-visitor-begin-visit (visitor) ...) -- active declareFunction, no body

;; (defun print-hier-visitor-end-visit (visitor) ...) -- active declareFunction, no body

;; (defun print-hier-visitor-begin-path (visitor path) ...) -- active declareFunction, no body

;; (defun print-hier-visitor-end-path (visitor path) ...) -- active declareFunction, no body

;; (defun print-hier-visitor-accept-node (visitor node) ...) -- active declareFunction, no body

;; (defun new-no-op-hierarchical-visitor () ...) -- active declareFunction, no body
