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

;;; Variables

(defvar *translator-output-enabled?* t
  "[Cyc] When non-nil, the backend actually writes to output files.
   When T, the backend just writes to /dev/null.")

(deflexical *translator-backends* '(:sl2c :sl2java))

(defvar *current-system-translation* nil)

;;; SYSTEM-TRANSLATION defstruct
;;; Slots and conc-name SYS-TR- per Java $list4 / $list6 accessor names.
;;; The print_object_method_table register_method call is elided per Clyc
;;; convention; the print trampoline body is missing-larkc so we do not
;;; hook in a defmethod print-object.

(defstruct (system-translation (:conc-name "SYS-TR-"))
  system
  backend
  features
  input-directory
  output-directory
  manifest-file
  modules
  module-filename-table
  module-features-table
  module-initialization-table
  xref-database
  secure-id-database
  last-translation-time)

(defconstant *dtp-system-translation* 'system-translation)

(defparameter *translation-trace-stream* t)

(deflexical *default-secure-id-database-filename* "translation-secure-id-database-file.cfasl"
  "[Cyc] The default target for saving the secure translation's ID database file.")

;;; Functions (ordered per declare_system_translation_file)

;; (defun translator-output-enabled-p () ...) -- commented declareFunction, no body
;; (defun translator-backend-p (object) ...) -- commented declareFunction, no body

(defun current-system-translation ()
  *current-system-translation*)

;; (defun current-system-translation-secure? () ...) -- commented declareFunction, no body
;; (defun current-system-translation-security-level () ...) -- commented declareFunction, no body

(defun system-translation-print-function-trampoline (object stream)
  ;; Likely called (print-system-translation object stream 0) — the trampoline
  ;; invoked the stripped print-system-translation method via the Java
  ;; print_object_method_table dispatch.
  (declare (ignore object stream))
  (missing-larkc 8676))

;; (defun system-translation-p (object) ...) -- commented declareFunction, no body
;;   UnaryFunction override calls missing-larkc 8756
;; (defun sys-tr-system (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-backend (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-features (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-input-directory (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-output-directory (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-manifest-file (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-modules (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-module-filename-table (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-module-features-table (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-module-initialization-table (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-xref-database (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-secure-id-database (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun sys-tr-last-translation-time (translation) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun _csetf-sys-tr-system (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-system ...) ...)
;; (defun _csetf-sys-tr-backend (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-backend ...) ...)
;; (defun _csetf-sys-tr-features (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-features ...) ...)
;; (defun _csetf-sys-tr-input-directory (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-input-directory ...) ...)
;; (defun _csetf-sys-tr-output-directory (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-output-directory ...) ...)
;; (defun _csetf-sys-tr-manifest-file (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-manifest-file ...) ...)
;; (defun _csetf-sys-tr-modules (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-modules ...) ...)
;; (defun _csetf-sys-tr-module-filename-table (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-module-filename-table ...) ...)
;; (defun _csetf-sys-tr-module-features-table (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-module-features-table ...) ...)
;; (defun _csetf-sys-tr-module-initialization-table (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-module-initialization-table ...) ...)
;; (defun _csetf-sys-tr-xref-database (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-xref-database ...) ...)
;; (defun _csetf-sys-tr-secure-id-database (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-secure-id-database ...) ...)
;; (defun _csetf-sys-tr-last-translation-time (translation new) ...) -- commented declareFunction, no body, replaced by (setf (sys-tr-last-translation-time ...) ...)
;; (defun make-system-translation (&optional arglist) ...) -- commented declareFunction, no body, provided by defstruct
;; (defun print-system-translation (object stream depth) ...) -- commented declareFunction, no body
;; (defun new-system-translation (system backend features input-directory output-directory manifest-file security-level) ...) -- commented declareFunction, no body
;; (defun destroy-system-translation (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-system (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-backend (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-features (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-input-directory (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-output-directory (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-manifest-file (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-xref-database (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-secure-id-database (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-modules (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-set-modules (translation modules) ...) -- commented declareFunction, no body
;; (defun sys-tran-set-last-translation-time (translation &optional time) ...) -- commented declareFunction, no body
;; (defun sys-tran-security-level (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-secure? (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-includes-module? (translation module) ...) -- commented declareFunction, no body
;; (defun sys-tran-module-input-filename (translation module) ...) -- commented declareFunction, no body
;; (defun sys-tran-module-output-filename (translation module) ...) -- commented declareFunction, no body
;; (defun sys-tran-relative-input-filename (translation module) ...) -- commented declareFunction, no body
;; (defun sys-tran-module-features (translation module) ...) -- commented declareFunction, no body
;; (defun sys-tran-module-declare-function (translation module) ...) -- commented declareFunction, no body
;; (defun sys-tran-module-init-function (translation module) ...) -- commented declareFunction, no body
;; (defun sys-tran-module-setup-function (translation module) ...) -- commented declareFunction, no body
;; (defun sys-tran-all-init-functions (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-system-default-path (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-secure-module-id (translation module) ...) -- commented declareFunction, no body
;; (defun sys-tran-secure-method-id (translation method) ...) -- commented declareFunction, no body
;; (defun sys-tran-secure-global-id (translation global) ...) -- commented declareFunction, no body
;; (defun sys-tran-secure-symbol-name (translation symbol) ...) -- commented declareFunction, no body
;; (defun current-system-translation-secure-symbol-name (symbol) ...) -- commented declareFunction, no body
;; (defun sys-tran-note-module-filenames (translation module input-filename output-filename) ...) -- commented declareFunction, no body
;; (defun sys-tran-note-module-features (translation module features) ...) -- commented declareFunction, no body
;; (defun sys-tran-initialize-last-translation-time (translation) ...) -- commented declareFunction, no body
;; (defun translator-possibly-update-current-system-modules () ...) -- commented declareFunction, no body
;; (defun translator-possibly-translate-one-module (module) ...) -- commented declareFunction, no body
;; (defun translator-possibly-output-system-level-files () ...) -- commented declareFunction, no body
;; (defun translator-possibly-output-secure-id-database-file () ...) -- commented declareFunction, no body
;; (defun sys-tran-possibly-note-module-initialization-methods (translation module declare-fn init-fn) ...) -- commented declareFunction, no body
;; (defun translate-one-system (options) ...) -- commented declareFunction, no body
;; (defun sys-tran-initialize-xref-database (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-initialize-module-info (translation) ...) -- commented declareFunction, no body
;; (defun translator-compute-relevant-modules-from-manifest (translation manifest features system-default-path) ...) -- commented declareFunction, no body
;; (defun translator-compute-module-input-file (translation module path) ...) -- commented declareFunction, no body
;; (defun sys-tran-compute-module-output-file (translation module path) ...) -- commented declareFunction, no body
;; (defun translate-backend-compute-output-module-path (backend module-name default-path) ...) -- commented declareFunction, no body
;; (defun translator-backend-output-file-extension (backend) ...) -- commented declareFunction, no body
;; (defun sys-tran-backend-output-module-filename (translation module path) ...) -- commented declareFunction, no body
;; (defun java-backend-output-module-filename (module-name &optional secure-id) ...) -- commented declareFunction, no body
;; (defun translator-compute-full-filename (directory path module extension) ...) -- commented declareFunction, no body
;; (defun translator-module-feature-expression-match (features module-features) ...) -- commented declareFunction, no body
;; (defun sys-tran-possibly-update-xref-module-features (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-trace-format (format-control &optional arg1 arg2 arg3) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants:
;;   $list82 = ((NAME FORMAT-CONTROL &REST FORMAT-ARGS) &BODY BODY) -- arglist
;;   $sym83$DONE = makeUninternedSymbol("DONE") -- gensym
;;   $sym84$CLET, $sym85$WHILE, $sym86$CNOT, $sym87$WITH-SIMPLE-RESTART, $sym88$CSETQ
;;   $list89 = (T) -- orphan (unexplained; possibly the CSETQ value form 't)
;; This is a loop that keeps presenting a simple-restart around BODY until
;; BODY runs to completion without the restart being invoked.
(defmacro with-simple-restart-loop ((name format-control &rest format-args) &body body)
  (with-temp-vars (done)
    `(clet ((,done nil))
       (while (cnot ,done)
         (with-simple-restart (,name ,format-control ,@format-args)
           ,@body
           (csetq ,done t))))))

;; (defun sys-tran-perform-initial-translation (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-translate-modules (translation modules) ...) -- commented declareFunction, no body
;; (defun translate-one-module (translation module input-file output-file features) ...) -- commented declareFunction, no body
;; (defun translate-one-system-module (translation module) ...) -- commented declareFunction, no body
;; (defun translator-parse-manifest-file (filename) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants:
;;   $list107 = ((MANIFEST-SYSTEM-VAR MANIFEST) &BODY BODY) -- arglist
;;   $sym108$CDOLIST -- operator
;; Simple cdolist wrapper iterating over the systems in MANIFEST.
(defmacro do-manifest-systems ((manifest-system-var manifest) &body body)
  `(cdolist (,manifest-system-var ,manifest)
     ,@body))

;; (defun manifest-system-name (system) ...) -- commented declareFunction, no body
;; (defun manifest-system-lookup (system key) ...) -- commented declareFunction, no body
;; (defun manifest-system-modules (system) ...) -- commented declareFunction, no body
;; (defun manifest-system-default-path (system) ...) -- commented declareFunction, no body
;; (defun manifest-module-name (module) ...) -- commented declareFunction, no body
;; (defun manifest-module-relative-path (module) ...) -- commented declareFunction, no body
;; (defun manifest-module-features (module) ...) -- commented declareFunction, no body
;; (defun manifest-module-path (module default-path) ...) -- commented declareFunction, no body
;; (defun manifest-module-features-allowed? (module system-features module-features) ...) -- commented declareFunction, no body
;; (defun translator-regenerate-manifest-file (translation) ...) -- commented declareFunction, no body
;; (defun translator-generate-manifest-file (translation) ...) -- commented declareFunction, no body
;; (defun translator-generate-manifest-to-stream (stream) ...) -- commented declareFunction, no body
;; (defun translator-generate-manifest-system-to-stream (stream system) ...) -- commented declareFunction, no body
;; (defun translator-system-module-specs (system) ...) -- commented declareFunction, no body
;; (defun translator-system-directory (system) ...) -- commented declareFunction, no body
;; (defun translator-system-package (system) ...) -- commented declareFunction, no body
;; (defun translator-system-required-systems (system) ...) -- commented declareFunction, no body
;; (defun translator-system-modules (system) ...) -- commented declareFunction, no body
;; (defun translator-system-module-directory (system module) ...) -- commented declareFunction, no body
;; (defun translator-system-module-features (system module) ...) -- commented declareFunction, no body
;; (defun untransformed-feature-symbol-p (symbol) ...) -- commented declareFunction, no body
;; (defun transform-feature-symbol (symbol) ...) -- commented declareFunction, no body
;; (defun sys-tran-output-system-level-files (translation) ...) -- commented declareFunction, no body
;; (defun sys-tran-possibly-output-secure-id-database-file (translation) ...) -- commented declareFunction, no body
;; (defun translator-system-directory-module-map (system features system-directory directory) ...) -- commented declareFunction, no body
;; (defun translator-libraries-from-directory-module-map (directory-module-map directory) ...) -- commented declareFunction, no body
;; (defun translator-paths-from-directory-module-map (directory-module-map) ...) -- commented declareFunction, no body
;; (defun retranslate-modules (modules) ...) -- commented declareFunction, no body
;; (defun module-damaged-wrt-introspection? (module) ...) -- commented declareFunction, no body
;; (defun test-translate-and-output-form (form &optional backend stream verbose?) ...) -- commented declareFunction, no body
;; (defun test-translate-and-output-form-to-string (form &optional backend verbose?) ...) -- commented declareFunction, no body

;;; Setup phase

(toplevel
  ;; print_object_method_table register_method elided per Clyc convention.
  ;; def_csetf calls elided -- defstruct-generated setf expanders replace them.
  (identity 'system-translation))
