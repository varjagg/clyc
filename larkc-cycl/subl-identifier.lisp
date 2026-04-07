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

;;; Functions (declare section ordering)

;; (defun sublid-p (object) ...) -- commented declareFunction, no body
;; (defun sublid-domain-p (object) ...) -- commented declareFunction, no body
;; (defun cyc-entity-from-sublid (domain id) ...) -- commented declareFunction, no body
;; (defun sublid-from-cyc-entity (fort) ...) -- commented declareFunction, no body
;; (defun sublid-add-domain-to-forts (domain fort) ...) -- commented declareFunction, no body
;; (defun sublid-remove-domain-to-forts (domain fort) ...) -- commented declareFunction, no body
;; (defun sublid-domain-to-forts-update (domain fort operation) ...) -- commented declareFunction, no body
;; (defun sublid-domain-to-forts-lookup (domain) ...) -- commented declareFunction, no body
;; (defun sublid-add-id-to-forts (id fort) ...) -- commented declareFunction, no body
;; (defun sublid-remove-id-to-forts (id fort) ...) -- commented declareFunction, no body
;; (defun sublid-id-to-forts-update (id fort operation) ...) -- commented declareFunction, no body
;; (defun cleanup-sublid-id-to-forts (id) ...) -- commented declareFunction, no body
;; (defun sublid-id-to-forts-lookup (id) ...) -- commented declareFunction, no body
;; (defun sublid-add-fort-to-id (fort id) ...) -- commented declareFunction, no body
;; (defun sublid-remove-fort-to-id (fort) ...) -- commented declareFunction, no body
;; (defun sublid-fort-to-id-lookup (fort) ...) -- commented declareFunction, no body

(defun initialize-sublid-mappings ()
  "[Cyc] Initialize the SubL identifier mappings from the predicate extents of
#$subLIdentifier and #$uniquelyIdentifiedInType."
  (clrhash *sublid-domain-to-forts-table*)
  (clrhash *sublid-id-to-forts-table*)
  (clrhash *sublid-fort-to-id-table*)
  (when (and (mt? *sublid-mt*)
             (predicate? *sublid-pred*))
    (with-inference-mt-relevance *sublid-mt*
      (do-predicate-extent-index (assertion *sublid-pred* :truth :true)
        ;; Likely populates the sublid mapping tables from this #$subLIdentifier assertion,
        ;; extracting domain, id, and fort from the GAF args.
        ;; Evidence: the 3 tables are cleared above, then this loop iterates all assertions.
        (missing-larkc 11210))
      (do-predicate-extent-index (assertion *sublid-uiit-pred* :truth :true)
        ;; Likely populates the sublid mapping tables from this #$uniquelyIdentifiedInType assertion.
        ;; Evidence: same pattern as above for the UIIT predicate.
        (missing-larkc 11212)))))

;; (defun add-sublidentifier (assertion arg2) ...) -- commented declareFunction, no body
;; (defun remove-sublidentifier (assertion arg2) ...) -- commented declareFunction, no body
;; (defun sublid-mappings-add (assertion) ...) -- commented declareFunction, no body
;; (defun sublid-mappings-remove (assertion) ...) -- commented declareFunction, no body
;; (defun add-uniquelyidentifiedintype (assertion arg2) ...) -- commented declareFunction, no body
;; (defun remove-uniquelyidentifiedintype (assertion arg2) ...) -- commented declareFunction, no body
;; (defun uiit-mappings-add (assertion) ...) -- commented declareFunction, no body
;; (defun uiit-mappings-remove (assertion) ...) -- commented declareFunction, no body

;;; Variables (init phase)

(defglobal *sublid-domain-to-forts-table* (make-hash-table)
  "[Cyc] Maintains a mapping from domains (e.g. #$CycHLTruthValue) to FORTs
(e.g., the NART (#$SubLSymbolEntityFn #$CycHLTruthValue :TRUE-DEF))")

(defglobal *sublid-id-to-forts-table* (make-hash-table)
  "[Cyc] Maintains a mapping from identifiers (e.g. :TRUE-DEF) to forts (e.g., the NART
(#$SubLSymbolEntityFn #$CycHLTruthValue :TRUE-DEF)).")

(defglobal *sublid-fort-to-id-table* (make-hash-table)
  "[Cyc] Maintains a mapping from forts (e.g., the NART
(#$SubLSymbolEntityFn #$CycHLTruthValue :TRUE-DEF))
to identifiers (e.g. :TRUE-DEF).")

(defconstant *sublid-pred* #$subLIdentifier)

(defconstant *sublid-uiit-pred* #$uniquelyIdentifiedInType)

;;; Setup phase

(declare-defglobal '*sublid-domain-to-forts-table*)
(declare-defglobal '*sublid-id-to-forts-table*)
(declare-defglobal '*sublid-fort-to-id-table*)
(register-kb-function 'add-sublidentifier)
(register-kb-function 'remove-sublidentifier)
(register-kb-function 'add-uniquelyidentifiedintype)
(register-kb-function 'remove-uniquelyidentifiedintype)
