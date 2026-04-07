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

;;; XREF-MODULE struct — 19 slots
(defstruct (xref-module (:conc-name "XREF-M-")
                        (:print-function print-xref-module))
  name
  xref-system
  features
  method-definitions
  method-position-table
  method-method-table
  method-global-reference-table
  method-global-modification-table
  method-global-binding-table
  global-definitions
  global-position-table
  global-method-table
  global-global-reference-table
  top-method-table
  top-global-reference-table
  top-global-modification-table
  top-global-binding-table
  method-formal-arglist-table
  global-binding-type-table)

(defconstant *dtp-xref-module* 'xref-module)

;;; XREF-SYSTEM struct — 15 slots
(defstruct (xref-system (:conc-name "XREF-S-")
                        (:print-function print-xref-system))
  name
  features
  xref-module-table
  method-definition-table
  global-definition-table
  method-called-by-method-table
  method-called-by-global-table
  method-called-at-top-level-table
  global-referenced-by-method-table
  global-modified-by-method-table
  global-rebound-by-method-table
  global-referenced-by-global-table
  global-referenced-at-top-level-table
  global-modified-at-top-level-table
  global-rebound-at-top-level-table)

(defconstant *dtp-xref-system* 'xref-system)

;;; Variables

(deflexical *empty-set-contents* (new-set-contents 0))

(defparameter *current-xref-module* nil)

(defparameter *xref-module-scope* nil)

(defparameter *xref-file-position-scope* nil)

(defparameter *xref-method-scope* nil)

(defparameter *xref-global-scope* nil)

(defvar *xref-trace* nil
  "[Cyc] When T, trace the progress of translation.")

;;; Functions (ordered by declare_xref_database_file)

(defun xref-module-print-function-trampoline (object stream)
  ;; Likely prints the XREF-MODULE struct via its registered print method.
  ;; Evidence: registered with Structures.register_method on $print_object_method_table$
  ;; for $dtp_xref_module$ in setup.
  (declare (ignore object stream))
  (missing-larkc 8269))

;; xref-module-p (object) -- commented declareFunction, UnaryFunction: missing-larkc 8434
;; xref-m-name (xref-module) -- commented declareFunction, no body
;; xref-m-xref-system (xref-module) -- commented declareFunction, no body
;; xref-m-features (xref-module) -- commented declareFunction, no body
;; xref-m-method-definitions (xref-module) -- commented declareFunction, no body
;; xref-m-method-position-table (xref-module) -- commented declareFunction, no body
;; xref-m-method-method-table (xref-module) -- commented declareFunction, no body
;; xref-m-method-global-reference-table (xref-module) -- commented declareFunction, no body
;; xref-m-method-global-modification-table (xref-module) -- commented declareFunction, no body
;; xref-m-method-global-binding-table (xref-module) -- commented declareFunction, no body
;; xref-m-global-definitions (xref-module) -- commented declareFunction, no body
;; xref-m-global-position-table (xref-module) -- commented declareFunction, no body
;; xref-m-global-method-table (xref-module) -- commented declareFunction, no body
;; xref-m-global-global-reference-table (xref-module) -- commented declareFunction, no body
;; xref-m-top-method-table (xref-module) -- commented declareFunction, no body
;; xref-m-top-global-reference-table (xref-module) -- commented declareFunction, no body
;; xref-m-top-global-modification-table (xref-module) -- commented declareFunction, no body
;; xref-m-top-global-binding-table (xref-module) -- commented declareFunction, no body
;; xref-m-method-formal-arglist-table (xref-module) -- commented declareFunction, no body
;; xref-m-global-binding-type-table (xref-module) -- commented declareFunction, no body
;; _csetf-xref-m-name (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-xref-system (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-features (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-method-definitions (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-method-position-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-method-method-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-method-global-reference-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-method-global-modification-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-method-global-binding-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-global-definitions (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-global-position-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-global-method-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-global-global-reference-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-top-method-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-top-global-reference-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-top-global-modification-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-top-global-binding-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-method-formal-arglist-table (xref-module value) -- commented declareFunction, no body
;; _csetf-xref-m-global-binding-type-table (xref-module value) -- commented declareFunction, no body
;; make-xref-module (&optional arglist) -- commented declareFunction, no body
;; print-xref-module (object stream depth) -- commented declareFunction, no body

(defun sxhash-xref-module-method (object)
  ;; Likely computes sxhash of the xref-module's name slot.
  ;; Evidence: registered with Structures.register_method on $sxhash_method_table$
  ;; for $dtp_xref_module$ in setup.
  (declare (ignore object))
  (sxhash (missing-larkc 8380)))

;; new-xref-module (name xref-system features) -- commented declareFunction, no body

;; do-xrm-method-definitions ((method xrm &key done) &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: $list75 arglist, uninterned XRM-VAR DEFINITION POSITION gensyms, CLET, DO-LIST,
;;   XRM-METHOD-DEFINITIONS, CDESTRUCTURING-BIND, IGNORE. Registered as macro-helper for
;;   XRM-METHOD-DEFINITIONS. Iterates method-definitions list yielding (method . position)
;;   pairs, binding method to each entry.

;; xrm-method-definitions (xref-module) -- commented declareFunction, no body
;; do-xrm-methods ((method xrm &key done) &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: uninterned XRM-VAR POSITION gensyms, DO-DICTIONARY, XRM-METHOD-POSITION-TABLE.
;;   Registered as macro-helper for XRM-METHOD-POSITION-TABLE. Iterates dictionary keyed
;;   on method.

;; xrm-method-position-table (xref-module) -- commented declareFunction, no body
;; do-xrm-global-definitions ((global xrm &key done) &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: $list93 arglist, uninterned XRM-VAR DEFINITION POSITION gensyms,
;;   XRM-GLOBAL-DEFINITIONS. Registered as macro-helper for XRM-GLOBAL-DEFINITIONS.

;; xrm-global-definitions (xref-module) -- commented declareFunction, no body
;; do-xrm-globals ((global xrm &key done) &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: uninterned XRM-VAR POSITION gensyms, XRM-GLOBAL-POSITION-TABLE.
;;   Registered as macro-helper for XRM-GLOBAL-POSITION-TABLE.

;; xrm-global-position-table (xref-module) -- commented declareFunction, no body
;; xrm-name (xref-module) -- commented declareFunction, no body
;; xrm-xref-system (xref-module) -- commented declareFunction, no body
;; xrm-module-features (xref-module) -- commented declareFunction, no body
;; xrm-method-definition-count (xref-module method) -- commented declareFunction, no body
;; xrm-total-method-definition-count (xref-module) -- commented declareFunction, no body
;; xrm-total-method-count (xref-module) -- commented declareFunction, no body
;; xrm-has-multiple-method-definitions? (xref-module) -- commented declareFunction, no body
;; xrm-global-definition-count (xref-module global) -- commented declareFunction, no body
;; xrm-total-global-definition-count (xref-module) -- commented declareFunction, no body
;; xrm-total-global-count (xref-module) -- commented declareFunction, no body
;; xrm-has-multiple-global-definitions? (xref-module) -- commented declareFunction, no body
;; xrm-method-definition-postion (xref-module method) -- commented declareFunction, no body
;; xrm-method-definition-positions (xref-module method) -- commented declareFunction, no body
;; xrm-global-definition-postion (xref-module global) -- commented declareFunction, no body
;; xrm-global-definition-positions (xref-module global) -- commented declareFunction, no body
;; xrm-method-formal-arglist (xref-module method) -- commented declareFunction, no body
;; xrm-global-binding-type (xref-module global) -- commented declareFunction, no body
;; xrm-record-method-definition (xref-module method position) -- commented declareFunction, no body
;; xrm-unrecord-method-definition (xref-module method) -- commented declareFunction, no body
;; xrm-record-method-formal-arglist (xref-module method arglist) -- commented declareFunction, no body
;; xrm-record-global-binding-type (xref-module global binding-type) -- commented declareFunction, no body
;; xrm-record-global-definition (xref-module global position) -- commented declareFunction, no body
;; xrm-unrecord-global-definition (xref-module global) -- commented declareFunction, no body
;; xrm-record-method-calls-method (xref-module caller callee) -- commented declareFunction, no body
;; xrm-record-method-references-global (xref-module method global) -- commented declareFunction, no body
;; xrm-record-method-modifies-global (xref-module method global) -- commented declareFunction, no body
;; xrm-record-method-rebinds-global (xref-module method global) -- commented declareFunction, no body
;; xrm-record-global-calls-method (xref-module global method) -- commented declareFunction, no body
;; xrm-record-global-references-global (xref-module caller callee) -- commented declareFunction, no body
;; xrm-record-top-calls-method (xref-module top method) -- commented declareFunction, no body
;; xrm-record-top-references-global (xref-module top global) -- commented declareFunction, no body
;; xrm-record-top-modifies-global (xref-module top global) -- commented declareFunction, no body
;; xrm-record-top-rebinds-global (xref-module top global) -- commented declareFunction, no body

(defun xref-system-print-function-trampoline (object stream)
  ;; Likely prints the XREF-SYSTEM struct via its registered print method.
  ;; Evidence: registered with Structures.register_method on $print_object_method_table$
  ;; for $dtp_xref_system$ in setup.
  (declare (ignore object stream))
  (missing-larkc 8270))

;; xref-system-p (object) -- commented declareFunction, UnaryFunction: missing-larkc 8493
;; xref-s-name (xref-system) -- commented declareFunction, no body
;; xref-s-features (xref-system) -- commented declareFunction, no body
;; xref-s-xref-module-table (xref-system) -- commented declareFunction, no body
;; xref-s-method-definition-table (xref-system) -- commented declareFunction, no body
;; xref-s-global-definition-table (xref-system) -- commented declareFunction, no body
;; xref-s-method-called-by-method-table (xref-system) -- commented declareFunction, no body
;; xref-s-method-called-by-global-table (xref-system) -- commented declareFunction, no body
;; xref-s-method-called-at-top-level-table (xref-system) -- commented declareFunction, no body
;; xref-s-global-referenced-by-method-table (xref-system) -- commented declareFunction, no body
;; xref-s-global-modified-by-method-table (xref-system) -- commented declareFunction, no body
;; xref-s-global-rebound-by-method-table (xref-system) -- commented declareFunction, no body
;; xref-s-global-referenced-by-global-table (xref-system) -- commented declareFunction, no body
;; xref-s-global-referenced-at-top-level-table (xref-system) -- commented declareFunction, no body
;; xref-s-global-modified-at-top-level-table (xref-system) -- commented declareFunction, no body
;; xref-s-global-rebound-at-top-level-table (xref-system) -- commented declareFunction, no body
;; _csetf-xref-s-name (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-features (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-xref-module-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-method-definition-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-global-definition-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-method-called-by-method-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-method-called-by-global-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-method-called-at-top-level-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-global-referenced-by-method-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-global-modified-by-method-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-global-rebound-by-method-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-global-referenced-by-global-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-global-referenced-at-top-level-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-global-modified-at-top-level-table (xref-system value) -- commented declareFunction, no body
;; _csetf-xref-s-global-rebound-at-top-level-table (xref-system value) -- commented declareFunction, no body
;; make-xref-system (&optional arglist) -- commented declareFunction, no body
;; print-xref-system (object stream depth) -- commented declareFunction, no body
;; new-xref-system (name features) -- commented declareFunction, no body
;; xrs-name (xref-system) -- commented declareFunction, no body
;; xrs-features (xref-system) -- commented declareFunction, no body
;; xrs-module-count (xref-system) -- commented declareFunction, no body
;; xrs-lookup-module (xref-system module-name) -- commented declareFunction, no body
;; xrs-method-defining-xrm (xref-system method) -- commented declareFunction, no body
;; xrs-method-defining-xrms (xref-system method) -- commented declareFunction, no body
;; xrs-method-definition-count (xref-system method) -- commented declareFunction, no body
;; xrs-global-defining-xrm (xref-system global) -- commented declareFunction, no body
;; xrs-global-defining-xrms (xref-system global) -- commented declareFunction, no body
;; xrs-global-definition-count (xref-system global) -- commented declareFunction, no body
;; xrs-possibly-note-module-features (xref-system module features) -- commented declareFunction, no body
;; current-xref-system () -- commented declareFunction, no body
;; current-xref-system-modules () -- commented declareFunction, no body
;; current-xref-system-features () -- commented declareFunction, no body
;; current-xref-system-relevant-modules (features) -- commented declareFunction, no body
;; current-xref-module-p (object) -- commented declareFunction, no body
;; xref-find-xrm-by-module (module-name) -- commented declareFunction, no body
;; xref-module-features (xref-module) -- commented declareFunction, no body
;; xref-module-input-filename (xref-module) -- commented declareFunction, no body
;; xref-predefined-method-p (method) -- commented declareFunction, no body
;; xref-predefined-global-p (global) -- commented declareFunction, no body
;; xref-method-formal-arglist (method) -- commented declareFunction, no body
;; method-formal-arglist (method) -- commented declareFunction, no body
;; xref-global-binding-type (global) -- commented declareFunction, no body
;; xref-method-definition-count (method) -- commented declareFunction, no body
;; xref-method-undefined? (method) -- commented declareFunction, no body
;; xref-method-defining-xrm (method) -- commented declareFunction, no body
;; xref-method-defining-module (method) -- commented declareFunction, no body
;; xref-method-has-multiple-definitions? (method) -- commented declareFunction, no body
;; xref-method-defining-modules (method) -- commented declareFunction, no body
;; xref-global-definition-count (global) -- commented declareFunction, no body
;; xref-global-undefined? (global) -- commented declareFunction, no body
;; xref-global-defining-xrm (global) -- commented declareFunction, no body
;; xref-global-defining-module (global) -- commented declareFunction, no body
;; xref-global-has-multiple-definitions? (global) -- commented declareFunction, no body
;; xref-global-defining-modules (global) -- commented declareFunction, no body
;; xref-method-definition-position (method) -- commented declareFunction, no body
;; xref-method-definition-positions (method) -- commented declareFunction, no body
;; xref-global-definition-position (global) -- commented declareFunction, no body
;; xref-global-definition-positions (global) -- commented declareFunction, no body
;; xref-methods-defined-by-module (module-name) -- commented declareFunction, no body
;; xref-module-method-definition-count (module-name method) -- commented declareFunction, no body
;; xref-module-method-definition-positions (module-name method) -- commented declareFunction, no body
;; xref-globals-defined-by-module (module-name) -- commented declareFunction, no body
;; xref-module-global-definition-count (module-name global) -- commented declareFunction, no body
;; xref-module-global-definition-positions (module-name global) -- commented declareFunction, no body
;; xref-method-called-by-method? (caller callee) -- commented declareFunction, no body
;; xref-methods-called-by-method (method) -- commented declareFunction, no body
;; xref-globals-referenced-by-method (method) -- commented declareFunction, no body
;; xref-globals-modified-by-method (method) -- commented declareFunction, no body
;; xref-globals-rebound-by-method (method) -- commented declareFunction, no body
;; xref-globals-accessed-by-method (method) -- commented declareFunction, no body
;; xref-method-called-by-global? (caller callee) -- commented declareFunction, no body
;; xref-methods-called-by-global (global) -- commented declareFunction, no body
;; xref-globals-referenced-by-global (global) -- commented declareFunction, no body
;; xref-method-called-by-module? (module-name method) -- commented declareFunction, no body
;; xref-module-positions-calling-method (module-name method) -- commented declareFunction, no body
;; xref-methods-called-by-module (module-name) -- commented declareFunction, no body
;; xref-module-positions-referencing-global (module-name global) -- commented declareFunction, no body
;; xref-globals-referenced-by-module (module-name) -- commented declareFunction, no body
;; xref-module-positions-modifying-global (module-name global) -- commented declareFunction, no body
;; xref-globals-modified-by-module (module-name) -- commented declareFunction, no body
;; xref-module-positions-rebinding-global (module-name global) -- commented declareFunction, no body
;; xref-globals-rebound-by-module (module-name) -- commented declareFunction, no body
;; xref-module-positions-accessing-global (module-name global) -- commented declareFunction, no body
;; xref-globals-accessed-by-module (module-name) -- commented declareFunction, no body
;; xref-methods-that-call-method (method) -- commented declareFunction, no body
;; xref-globals-that-call-method (method) -- commented declareFunction, no body
;; xrms-that-call-method (method) -- commented declareFunction, no body
;; xref-modules-that-call-method (method) -- commented declareFunction, no body
;; xref-method-call-count (method) -- commented declareFunction, no body
;; xref-method-unused-p (method) -- commented declareFunction, no body
;; xref-methods-that-reference-global (global) -- commented declareFunction, no body
;; xref-globals-that-reference-global (global) -- commented declareFunction, no body
;; xrms-that-reference-global (global) -- commented declareFunction, no body
;; xref-modules-that-reference-global (global) -- commented declareFunction, no body
;; xref-global-reference-count (global) -- commented declareFunction, no body
;; xref-global-never-referenced-p (global) -- commented declareFunction, no body
;; xref-methods-that-modify-global (global) -- commented declareFunction, no body
;; xrms-that-modify-global (global) -- commented declareFunction, no body
;; xref-modules-that-modify-global (global) -- commented declareFunction, no body
;; xref-global-modification-count (global) -- commented declareFunction, no body
;; xref-global-never-modified-p (global) -- commented declareFunction, no body
;; xref-methods-that-rebind-global (global) -- commented declareFunction, no body
;; xrms-that-rebind-global (global) -- commented declareFunction, no body
;; xref-modules-that-rebind-global (global) -- commented declareFunction, no body
;; xref-global-binding-count (global) -- commented declareFunction, no body
;; xref-global-never-rebound-p (global) -- commented declareFunction, no body
;; xref-methods-that-access-global (global) -- commented declareFunction, no body
;; xrms-that-access-global (global) -- commented declareFunction, no body
;; xref-modules-that-access-global (global) -- commented declareFunction, no body
;; xref-global-access-count (global) -- commented declareFunction, no body
;; xref-global-never-accessed-p (global) -- commented declareFunction, no body
;; xref-xrms-accessed-by-method (method) -- commented declareFunction, no body
;; xref-modules-accessed-by-method (method) -- commented declareFunction, no body
;; xref-xrms-accessed-by-global (global) -- commented declareFunction, no body
;; xref-modules-accessed-by-global (global) -- commented declareFunction, no body
;; xref-xrms-accessed-by-xrm (xrm) -- commented declareFunction, no body
;; xref-modules-accessed-by-module (module-name) -- commented declareFunction, no body
;; xref-xrms-accessed-anywhere-by-xrm (xrm) -- commented declareFunction, no body
;; xref-modules-accessed-anywhere-by-module (module-name) -- commented declareFunction, no body
;; xref-globals-accessed-anywhere-by-module (module-name) -- commented declareFunction, no body
;; xref-methods-accessed-anywhere-by-module (module-name) -- commented declareFunction, no body
;; xrms-that-access-method (method) -- commented declareFunction, no body
;; xref-modules-that-access-method (method) -- commented declareFunction, no body
;; xrms-that-access-global-anywhere (global) -- commented declareFunction, no body
;; xref-modules-that-access-global-anywhere (global) -- commented declareFunction, no body
;; xrms-that-access-xrm-anywhere (xrm) -- commented declareFunction, no body
;; xref-modules-that-access-module-anywhere (module-name) -- commented declareFunction, no body
;; xref-justify-module-referencing-module (referencer referencee) -- commented declareFunction, no body
;; xref-some-external-module-accesses-method-anywhere? (method) -- commented declareFunction, no body
;; xref-method-potentially-private-p (method) -- commented declareFunction, no body
;; xref-module-potentially-private-methods (module-name) -- commented declareFunction, no body
;; xref-some-external-module-accesses-global-anywhere? (global) -- commented declareFunction, no body
;; xref-global-potentially-private-p (global) -- commented declareFunction, no body
;; xref-module-potentially-private-globals (module-name) -- commented declareFunction, no body
;; xref-method-source-definition-info (method) -- commented declareFunction, no body
;; xref-global-source-definition-info (global) -- commented declareFunction, no body
;; xref-method-source-definition-comment (method) -- commented declareFunction, no body
;; xref-global-source-definition-comment (global) -- commented declareFunction, no body
;; xref-source-definition-comment (name kind) -- commented declareFunction, no body
;; xref-module-relative-input-filename-internal (module-name) -- commented declareFunction, no body
;; xref-module-relative-input-filename (module-name) -- commented declareFunction, no body
;; xrs-merge-xref-module (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-xrm (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-definition (xref-system name definition) -- commented declareFunction, no body
;; xrs-merge-new-method-definitions (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-global-definitions (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-update-backpointer (xref-system key value) -- commented declareFunction, no body
;; xrs-merge-new-method-called-by-method (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-method-called-by-global (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-method-called-at-top-level (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-global-referenced-by-method (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-global-referenced-by-global (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-global-referenced-at-top-level (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-global-modified-by-method (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-global-modified-at-top-level (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-global-rebound-by-method (xref-system xref-module) -- commented declareFunction, no body
;; xrs-merge-new-global-rebound-at-top-level (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-xrm (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-definition (xref-system name definition) -- commented declareFunction, no body
;; xrs-remove-old-method-definitions (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-global-definitions (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-update-backpointer (xref-system key value) -- commented declareFunction, no body
;; xrs-remove-old-method-called-by-method (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-method-called-by-global (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-method-called-at-top-level (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-global-referenced-by-method (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-global-referenced-by-global (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-global-referenced-at-top-level (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-global-modified-by-method (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-global-modified-at-top-level (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-global-rebound-by-method (xref-system xref-module) -- commented declareFunction, no body
;; xrs-remove-old-global-rebound-at-top-level (xref-system xref-module) -- commented declareFunction, no body
;; xref-possibly-record-global-undefinition (name definition) -- commented declareFunction, no body
;; xrs-unrecord-global-backpointers (xref-system global xref-module) -- commented declareFunction, no body
;; xref-possibly-record-method-undefinition (name definition) -- commented declareFunction, no body
;; xrs-unrecord-method-backpointers (xref-system method xref-module) -- commented declareFunction, no body

;; within-new-xref-module ((&key name features) &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: $list180 arglist, $list181 keys (:NAME :FEATURES), uninterned SYSTEM-VAR MODULE-VAR,
;;   $list184 (CURRENT-XREF-SYSTEM), FWHEN, NEW-XREF-MODULE, *CURRENT-XREF-MODULE*, PWHEN,
;;   XRS-MERGE-XREF-MODULE. Likely binds *current-xref-module* to a new module and merges
;;   it into the current xref system after body runs.

;; with-current-xref-module (xrm &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: $list190 arglist (XRM &BODY BODY). Registered as macro-helper for
;;   CURRENT-XREF-MODULE. Likely binds *current-xref-module* to xrm for body.

;; current-xref-module () -- commented declareFunction, no body

;; xref-within-module (module-name &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: $list194 arglist, uninterned NAME-VAR, CHECK-TYPE, $list197 (STRINGP),
;;   *XREF-MODULE-SCOPE*. Likely binds *xref-module-scope* to module-name (checked stringp)
;;   for body.

;; xref-module-scope () -- commented declareFunction, no body

;; xref-within-file-position (file-position &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: $list199 arglist, uninterned POSITION-VAR, $list201 (NON-NEGATIVE-INTEGER-P),
;;   *XREF-FILE-POSITION-SCOPE*. Likely binds *xref-file-position-scope* to file-position
;;   (checked non-negative-integer-p) for body.

;; xref-file-position-scope () -- commented declareFunction, no body

;; xref-within-define (name &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: $list203 arglist (NAME &BODY BODY), $sym204$XREF-WITHIN-METHOD. Likely expands
;;   to (xref-within-method name body...).

;; xref-within-defmacro (name &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: shares $list203 arglist (NAME &BODY BODY). Likely expands to
;;   (xref-within-method name body...).

;; xref-within-method (method &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: $list205 arglist (METHOD &BODY BODY), uninterned METHOD-VAR, $list207 (SYMBOLP),
;;   *XREF-METHOD-SCOPE*. Likely binds *xref-method-scope* to method (checked symbolp)
;;   for body.

;; xref-method-scope () -- commented declareFunction, no body

;; xref-within-global (global &body body) -- TODO: commented declareMacro, body reconstruction pending
;; Evidence: $list209 arglist (GLOBAL &BODY BODY), uninterned GLOBAL-VAR, *XREF-GLOBAL-SCOPE*.
;;   Likely binds *xref-global-scope* to global (checked symbolp) for body.

;; xref-global-scope () -- commented declareFunction, no body
;; xref-reference-scope () -- commented declareFunction, no body
;; xref-note-global-definition (name) -- commented declareFunction, no body
;; xref-note-macro-definition (name) -- commented declareFunction, no body
;; xref-note-function-definition (name) -- commented declareFunction, no body
;; xref-note-method-formal-arglist (method arglist) -- commented declareFunction, no body
;; xref-note-global-binding-type (global binding-type) -- commented declareFunction, no body
;; xref-note-global-reference (global) -- commented declareFunction, no body
;; xref-note-global-modification (global) -- commented declareFunction, no body
;; xref-note-global-binding (global) -- commented declareFunction, no body
;; xref-note-macro-use (name) -- commented declareFunction, no body
;; xref-note-function-call (name) -- commented declareFunction, no body
;; xref-note-module-removal (module-name) -- commented declareFunction, no body
;; xref-trace (format-control &optional arg1 arg2) -- commented declareFunction, no body
;; xref-sort-called-globals (globals) -- commented declareFunction, no body
;; xref-sort-called-methods (methods) -- commented declareFunction, no body
;; xref-sort-referenced-xrms (xrms) -- commented declareFunction, no body
;; xref-sort-referenced-modules (modules) -- commented declareFunction, no body
;; xref-sort-calling-globals (globals) -- commented declareFunction, no body
;; xref-sort-calling-methods (methods) -- commented declareFunction, no body
;; xref-sort-calling-xrms (xrms) -- commented declareFunction, no body
;; xref-sort-calling-modules (modules) -- commented declareFunction, no body

;;; Setup forms

(toplevel
 (register-macro-helper 'xrm-method-definitions 'do-xrm-method-definitions)
 (register-macro-helper 'xrm-method-position-table 'do-xrm-methods)
 (register-macro-helper 'xrm-global-definitions 'do-xrm-global-definitions)
 (register-macro-helper 'xrm-global-position-table 'do-xrm-globals)
 (note-memoized-function 'xref-module-relative-input-filename)
 (register-macro-helper 'current-xref-module 'with-current-xref-module))
