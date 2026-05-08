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

;;; NOTE: All non-trampoline functions in this file had their bodies stripped
;;; by LarKC. The Java file contains only the declareFunction entries for them,
;;; with no method definitions. Only SECURE-ID-DATABASE-PRINT-FUNCTION-TRAMPOLINE
;;; has a real body. Bodies cannot be ported from what does not exist.

(deflexical *translator-security-levels* '(:none :low :medium :high)
  "[Cyc] The possible security (obfuscation) levels possible in the translator.")

;;; SECURE-ID-DATABASE struct — 10 slots, conc-name SID-DB- (per Java $list5 accessor names)
(defstruct (secure-id-database (:conc-name "SID-DB-"))
  security-level
  id-module-table
  module-id-table
  id-method-table
  method-id-table
  id-global-table
  global-id-table
  symbol-exceptions
  id-symbol-table
  symbol-id-table)

(defconstant *dtp-secure-id-database* 'secure-id-database)

;; (defun secure-id-database-p (object) ...) -- active declareFunction, no body
;;   UnaryFunction override calls missing-larkc 32137
;; (defun translator-security-level-p (object) ...) -- active declareFunction, no body
;; sid-db-security-level, sid-db-id-module-table, sid-db-module-id-table,
;; sid-db-id-method-table, sid-db-method-id-table, sid-db-id-global-table,
;; sid-db-global-id-table, sid-db-symbol-exceptions, sid-db-id-symbol-table,
;; sid-db-symbol-id-table — all 10 are active declareFunction, no body, provided
;; by defstruct conc-name SID-DB-
;; _csetf-sid-db-security-level, _csetf-sid-db-id-module-table,
;; _csetf-sid-db-module-id-table, _csetf-sid-db-id-method-table,
;; _csetf-sid-db-method-id-table, _csetf-sid-db-id-global-table,
;; _csetf-sid-db-global-id-table, _csetf-sid-db-symbol-exceptions,
;; _csetf-sid-db-id-symbol-table, _csetf-sid-db-symbol-id-table — all 10 are
;; active declareFunction, no body, replaced by (setf (sid-db-slot ...) ...)
;; make-secure-id-database (&optional arglist) -- active declareFunction, no body,
;; provided by defstruct
;; (defun new-secure-id-database (security-level) ...) -- active declareFunction, no body
;; (defun set-secure-id-database-slots (db sl imt mit idmt midt igt git se ist sit) ...) -- active declareFunction, no body
;; (defun destroy-secure-id-database (db) ...) -- active declareFunction, no body
;; (defun secure-id-database-security-level (db) ...) -- active declareFunction, no body
;; (defun secure-id-database-lookup-module (db id) ...) -- active declareFunction, no body
;; (defun secure-id-database-lookup-method (db id) ...) -- active declareFunction, no body
;; (defun secure-id-database-lookup-global (db id) ...) -- active declareFunction, no body
;; (defun secure-id-database-excepted-symbol? (db symbol) ...) -- active declareFunction, no body
;; (defun secure-id-database-lookup-symbol (db id) ...) -- active declareFunction, no body
;; (defun secure-id-database-symbol-name (db symbol) ...) -- active declareFunction, no body
;; (defun secure-id-database-name-sensitive-symbol? (symbol) ...) -- active declareFunction, no body
;; (defun sublisp-symbol-p (symbol) ...) -- active declareFunction, no body
;; (defun save-secure-id-database-to-file (db filename) ...) -- active declareFunction, no body
;; (defun save-secure-id-database (db stream) ...) -- active declareFunction, no body
;; (defun construct-recipe-for-secure-id-database (db) ...) -- active declareFunction, no body
;; (defun restore-secure-id-database-from-file (filename) ...) -- active declareFunction, no body
;; (defun restore-secure-id-database (stream) ...) -- active declareFunction, no body
;; (defun load-secure-id-database-recipe (stream) ...) -- active declareFunction, no body
;; (defun sid-db-recipe-get (recipe key &optional default) ...) -- active declareFunction, no body
;; (defun interpret-secure-id-database-recipe-by-version (recipe version) ...) -- active declareFunction, no body
;; (defun interpret-secure-id-database-recipe-v1p0 (recipe) ...) -- active declareFunction, no body
;; (defun fetch-valid-secure-id-database-table (recipe key) ...) -- active declareFunction, no body
;; (defun secure-id-database-module-id (db module) ...) -- active declareFunction, no body
;; (defun secure-id-database-method-id (db method) ...) -- active declareFunction, no body
;; (defun secure-id-database-global-id (db global) ...) -- active declareFunction, no body
;; (defun secure-id-database-symbol-id (db symbol) ...) -- active declareFunction, no body
;; (defun secure-id-database-populate-symbol-exceptions (db) ...) -- active declareFunction, no body
;; (defun secure-id-database-note-symbol-exception (db symbol) ...) -- active declareFunction, no body
;; (defun current-system-translation-secure-module-lookup (id) ...) -- active declareFunction, no body
;; (defun current-system-translation-secure-method-lookup (id) ...) -- active declareFunction, no body
;; (defun current-system-translation-secure-global-lookup (id) ...) -- active declareFunction, no body
;; (defun current-system-translation-secure-symbol-lookup (id) ...) -- active declareFunction, no body
;; (defun sid-db-symbol-exceptions-add-all (db) ...) -- active declareFunction, no body
;; (defun sid-db-symbol-exceptions-add-for-api (db) ...) -- active declareFunction, no body
;; (defun sid-db-symbol-exceptions-add-symbols (db symbols) ...) -- active declareFunction, no body
;; (defun sid-db-symbol-exceptions-add-for-external (db) ...) -- active declareFunction, no body
;; (defun sid-db-symbol-exceptions-add-for-system-parameters (db) ...) -- active declareFunction, no body
;; (defun sid-db-symbol-exceptions-add-for-kb-function-symbols (db) ...) -- active declareFunction, no body
;; (defun sid-db-symbol-exceptions-add-for-misc-symbols (db) ...) -- active declareFunction, no body
;; (defun sid-db-symbol-exceptions-register-and-retranslate-misc (&optional db) ...) -- active declareFunction, no body

(deflexical *secure-id-database-type-marker* "c3edef08-eef1-11dd-9624-00219b50e0e5"
  "[Cyc] The GUID for the serialization type.")

(deflexical *misc-symbols-not-to-obfuscate*
  '(*cache-inference-results* *hl-failure-backchaining*
    *enable-rewrite-of-propagation?* *forward-propagate-from-negations*
    kb-statistics server-summary halt-cyc-image all none
    *init-file-loaded?* *thesaurus-filename* *thesaurus-filename-extension*
    *thesaurus-subdirectories* initialize-agenda initialize-transcript-handling
    load-system-parameters load-thesaurus-init-file probe-file
    system-code-initializations system-kb-initializations load-api
    core-kb-finalization core-kb-finish-bootstrapping core-kb-finish-definitions
    core-kb-initialization core-kb-start-bootstrapping core-kb-start-definitions
    cyc-function-to-arg fi-assert-int hl-external-id-string-p
    hl-find-or-create-nart low-assert-literal relevant-mt?
    dump-standard-kb dump-kb load-kb *standard-input* read-ignoring-errors
    *inference-trace-port* api-port api-server-top-level cfasl-port
    cfasl-server-top-level cyc-html-feature cyc-thesaurus-feature
    enable-tcp-server finish-output html-port html-server-top-level
    robust-enable-tcp-server start-agenda
    thesaurus-manager-access-protocol-server-top-level tmap-port
    *eval-in-api?* *require-api-remote-cycl*))
