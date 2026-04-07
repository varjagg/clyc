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

(defparameter *current-ts-file* nil)

(defstruct (trans-subl-file (:conc-name "TSF-"))
  module-name
  filename
  internal-constants
  referenced-globals
  referenced-functions
  definitions
  top-level-forms
  defined-globals
  defined-functions
  defined-macros
  arglist-table
  binding-type-table
  method-visibility-table
  global-visibility-table
  rwbc-methods)

(defconstant *dtp-trans-subl-file* 'trans-subl-file)

;; (defun current-ts-file () ...) -- active declareFunction, no body

(defun trans-subl-file-print-function-trampoline (object stream)
  "[Cyc] Print function trampoline for trans-subl-file."
  (missing-larkc 29304))

;; trans-subl-file-p - active declareFunction, provided by defstruct (1 0)
;; tsf-module-name - active declareFunction, provided by defstruct (1 0)
;; tsf-filename - active declareFunction, provided by defstruct (1 0)
;; tsf-internal-constants - active declareFunction, provided by defstruct (1 0)
;; tsf-referenced-globals - active declareFunction, provided by defstruct (1 0)
;; tsf-referenced-functions - active declareFunction, provided by defstruct (1 0)
;; tsf-definitions - active declareFunction, provided by defstruct (1 0)
;; tsf-top-level-forms - active declareFunction, provided by defstruct (1 0)
;; tsf-defined-globals - active declareFunction, provided by defstruct (1 0)
;; tsf-defined-functions - active declareFunction, provided by defstruct (1 0)
;; tsf-defined-macros - active declareFunction, provided by defstruct (1 0)
;; tsf-arglist-table - active declareFunction, provided by defstruct (1 0)
;; tsf-binding-type-table - active declareFunction, provided by defstruct (1 0)
;; tsf-method-visibility-table - active declareFunction, provided by defstruct (1 0)
;; tsf-global-visibility-table - active declareFunction, provided by defstruct (1 0)
;; tsf-rwbc-methods - active declareFunction, provided by defstruct (1 0)
;; _csetf-tsf-module-name - active declareFunction, provided by defstruct via (setf tsf-module-name) (2 0)
;; _csetf-tsf-filename - active declareFunction, provided by defstruct via (setf tsf-filename) (2 0)
;; _csetf-tsf-internal-constants - active declareFunction, provided by defstruct via (setf tsf-internal-constants) (2 0)
;; _csetf-tsf-referenced-globals - active declareFunction, provided by defstruct via (setf tsf-referenced-globals) (2 0)
;; _csetf-tsf-referenced-functions - active declareFunction, provided by defstruct via (setf tsf-referenced-functions) (2 0)
;; _csetf-tsf-definitions - active declareFunction, provided by defstruct via (setf tsf-definitions) (2 0)
;; _csetf-tsf-top-level-forms - active declareFunction, provided by defstruct via (setf tsf-top-level-forms) (2 0)
;; _csetf-tsf-defined-globals - active declareFunction, provided by defstruct via (setf tsf-defined-globals) (2 0)
;; _csetf-tsf-defined-functions - active declareFunction, provided by defstruct via (setf tsf-defined-functions) (2 0)
;; _csetf-tsf-defined-macros - active declareFunction, provided by defstruct via (setf tsf-defined-macros) (2 0)
;; _csetf-tsf-arglist-table - active declareFunction, provided by defstruct via (setf tsf-arglist-table) (2 0)
;; _csetf-tsf-binding-type-table - active declareFunction, provided by defstruct via (setf tsf-binding-type-table) (2 0)
;; _csetf-tsf-method-visibility-table - active declareFunction, provided by defstruct via (setf tsf-method-visibility-table) (2 0)
;; _csetf-tsf-global-visibility-table - active declareFunction, provided by defstruct via (setf tsf-global-visibility-table) (2 0)
;; _csetf-tsf-rwbc-methods - active declareFunction, provided by defstruct via (setf tsf-rwbc-methods) (2 0)
;; make-trans-subl-file - active declareFunction, provided by defstruct (0 1)

;; (defun print-trans-subl-file (object stream depth) ...) -- active declareFunction, no body

(defun sxhash-trans-subl-file-method (object)
  "[Cyc] Sxhash method for trans-subl-file."
  (sxhash (missing-larkc 29327)))

;; (defun new-ts-file (module-name filename) ...) -- active declareFunction, no body

;; (defun destroy-trans-subl-file (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-module-name (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-filename (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-definitions (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-internal-constant-count (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-next-internal-constant-id (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-internal-constants-info (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-all-referenced-globals (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-all-defined-globals (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-all-referenced-functions (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-all-defined-functions (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-all-defined-private-functions (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-function-arglist (ts-file function-name) ...) -- active declareFunction, no body

;; (defun current-ts-file-defined-function-arglist (function-name) ...) -- active declareFunction, no body

;; (defun ts-file-defined-global-binding-type (ts-file global-name) ...) -- active declareFunction, no body

;; (defun ts-file-global-binding-type (ts-file global-name) ...) -- active declareFunction, no body

;; (defun current-ts-file-global-binding-type (global-name) ...) -- active declareFunction, no body

;; (defun ts-file-defined-method-visibility (ts-file method-name) ...) -- active declareFunction, no body

;; (defun ts-file-defined-private-method-p (ts-file method-name) ...) -- active declareFunction, no body

;; (defun current-ts-file-defined-private-method-p (method-name) ...) -- active declareFunction, no body

;; (defun ts-file-defined-global-visibility (ts-file global-name) ...) -- active declareFunction, no body

;; (defun ts-file-defined-private-global-p (ts-file global-name) ...) -- active declareFunction, no body

;; (defun current-ts-file-defined-private-global-p (global-name) ...) -- active declareFunction, no body

;; (defun ts-file-private-global-definition-p (ts-file definition) ...) -- active declareFunction, no body

;; (defun ts-file-private-global-definitions (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-method-returns-within-binding-construct? (ts-file method-name) ...) -- active declareFunction, no body

;; (defun ts-file-internal-constant-id-lookup (ts-file internal-id) ...) -- active declareFunction, no body

;; (defun ts-file-note-function-definition (ts-file name definition) ...) -- active declareFunction, no body

;; (defun ts-file-note-macro-definition (ts-file name definition) ...) -- active declareFunction, no body

;; (defun ts-file-note-global-definition (ts-file name definition) ...) -- active declareFunction, no body

;; (defun ts-file-note-class-definition (ts-file name definition) ...) -- active declareFunction, no body

;; (defun ts-file-note-top-level-form (ts-file form) ...) -- active declareFunction, no body

;; with-translator-output-file - declareMacro
;; Reconstructed from Internal Constants evidence:
;; $list69 = ((STREAM-VAR FILENAME) &BODY BODY) -> arglist
;; $sym70 = FILENAME-VAR (uninternedSymbol)
;; $sym71 = CLET
;; $sym72 = WITH-PRIVATE-TEXT-FILE
;; $list73 = (:OUTPUT)
;; Expansion wraps body in a file output context
(defmacro with-translator-output-file ((stream-var filename) &body body)
  `(let ((,stream-var (open ,filename :direction :output :if-exists :supersede)))
     (unwind-protect
          (progn ,@body)
       (close ,stream-var))))

;; (defun possibly-delete-file (filename) ...) -- active declareFunction, no body

;; (defun show-trans-subl-file (ts-file &optional stream) ...) -- active declareFunction, no body

;; (defun print-subl-expression (expression &optional stream pretty-p) ...) -- active declareFunction, no body

;; (defun function-signature-info (function-name) ...) -- active declareFunction, no body

;; (defun function-arglist-signature-info (arglist) ...) -- active declareFunction, no body

;; (defun tsf-possibly-convert-internal-constant (form) ...) -- active declareFunction, no body

;; (defun tsf-possibly-note-referenced-global (form) ...) -- active declareFunction, no body

;; (defun tsf-possibly-note-referenced-function (form) ...) -- active declareFunction, no body

;; (defun tsf-possibly-note-defined-function-arglist (name arglist) ...) -- active declareFunction, no body

;; (defun tsf-possibly-note-defined-global-binding-type (name binding-type) ...) -- active declareFunction, no body

;; (defun tsf-possibly-note-defined-method-visibility (name visibility) ...) -- active declareFunction, no body

;; (defun tsf-possibly-note-defined-global-visibility (name visibility) ...) -- active declareFunction, no body

;; (defun tsf-possibly-note-method-returns-within-binding-construct (name) ...) -- active declareFunction, no body

;; (defun translate-file (input-file output-file) ...) -- active declareFunction, no body

;; (defun ts-file-translate-form (ts-file form) ...) -- active declareFunction, no body

;; (defun handle-file-form (ts-file form) ...) -- active declareFunction, no body

;; (defun finalize-ts-file (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-compute-initialization-methods (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-declare-method (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-init-method (ts-file) ...) -- active declareFunction, no body

;; (defun ts-file-setup-method (ts-file) ...) -- active declareFunction, no body

;; (defun current-ts-file-initializer? (form) ...) -- active declareFunction, no body

;; (defun translate-constant-initialization-form (form) ...) -- active declareFunction, no body

;; (defun translator-symbol-for-function (function-name) ...) -- active declareFunction, no body

;; (defun predefined-constant-p (object) ...) -- active declareFunction, no body

(deflexical *trans-subl-global-definers*
  '(defconstant deflexical defglobal defparameter defvar))

(deflexical *predefined-constants*
  ;; NOTE: In Java this was a large list of predefined constants (T, NIL,
  ;; comparison functions, integers 0-20, all standard characters).
  ;; Not meaningful in the CL port since these are native CL objects.
  nil)
