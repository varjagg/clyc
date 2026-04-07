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

;;; SQL-CONNECTION defstruct

(defstruct (sql-connection (:conc-name "SQLC-")
                           (:print-function sqlc-print))
  db
  user
  dbms-server
  port
  channel
  statements
  lock
  subprotocol
  proxy-server
  error-handling
  tickets
  mailman)

;;; SQL-TICKET defstruct

(defstruct sql-ticket
  semaphore
  result)

;;; SDBC-ERROR defstruct

(defstruct (sdbc-error (:print-function sdbc-error-print))
  type
  message
  code)

;;; SQL-RESULT-SET defstruct

(defstruct (sql-result-set (:conc-name "SQLRS-")
                           (:print-function sqlrs-print))
  rows
  current
  last
  start
  connection
  block-size
  id)

;;; SQL-STATEMENT defstruct

(defstruct (sql-statement (:conc-name "SQLS-"))
  connection
  id
  sql
  settings
  batch
  rs)

;;; Variables

(deflexical *dbms-server* "db-server.cyc.com"
  "[Cyc] The DBMS server machine.")

(deflexical *sdbc-proxy-server* "db-server.cyc.com"
  "[Cyc] The Java proxy server machine.")

(deflexical *sql-port* 9999
  "[Cyc] The database server port.")

(deflexical *sql-protocol* "jdbc")
(deflexical *sql-subprotocol* "postgresql")
(deflexical *sql-connection-timeout* 5)
(deflexical *connection-id* "CONNECTION")

(defparameter *result-set-block-size* 1000
  "[Cyc] The maximum number of rows that will reside locally in a result set at a given time.")

;; Command codes
(deflexical *quit* 0)
(deflexical *execute-update* 1)
(deflexical *execute-query* 2)
(deflexical *prepare-statement* 3)
(deflexical *create-statement* 4)
(deflexical *set-bytes* 5)
(deflexical *ps-execute-update* 6)
(deflexical *ps-execute-query* 7)
(deflexical *set-int* 8)
(deflexical *close-statement* 9)
(deflexical *new-connection* 10)
(deflexical *set-string* 11)
(deflexical *set-long* 12)
(deflexical *set-double* 13)
(deflexical *set-float* 14)
(deflexical *execute-batch* 15)
(deflexical *get-rows* 16)
(deflexical *close-result-set* 17)
(deflexical *execute-update-auto-keys* 18)
(deflexical *get-generated-keys* 19)
(deflexical *set-auto-commit* 20)
(deflexical *commit* 21)
(deflexical *rollback* 22)
(deflexical *get-transaction-isolation* 23)
(deflexical *set-transaction-isolation* 24)
(deflexical *get-auto-commit* 25)
(deflexical *get-tables* 26)
(deflexical *get-columns* 27)
(deflexical *get-primary-keys* 28)
(deflexical *get-imported-keys* 29)
(deflexical *get-exported-keys* 30)
(deflexical *get-index-info* 31)
(deflexical *cancel* 32)
(deflexical *get-max-connections* 33)

;; Response codes
(deflexical *stop-response* 0)
(deflexical *integer-response* 1)
(deflexical *result-set-response* 2)
(deflexical *void-response* 3)
(deflexical *connection* 4)
(deflexical *update-counts* 5)
(deflexical *transaction-isolation-level* 6)
(deflexical *boolean* 7)

;; Error codes
(deflexical *io-error* -1)
(deflexical *sql-error* -2)
(deflexical *unknown-error* -3)
(deflexical *client-error* -4)
(deflexical *commit-error* -5)
(deflexical *rollback-error* -6)
(deflexical *transaction-error* -7)
(deflexical *batch-update-error* -8)

(defconstant *dtp-sql-connection* 'sql-connection)
(defconstant *dtp-sql-ticket* 'sql-ticket)
(defconstant *dtp-sdbc-error* 'sdbc-error)

(defparameter *sdbc-error-decoding*
  (list (cons *io-error* "-IO")
        (cons *sql-error* "-SQL")
        (cons *unknown-error* "")
        (cons *client-error* "-CLIENT")
        (cons *transaction-error* "-TRANSACTION")
        (cons *rollback-error* "-ROLLBACK")
        (cons *batch-update-error* "-BATCH-UPDATE")))

(defconstant *dtp-sql-result-set* 'sql-result-set)
(defconstant *dtp-sql-statement* 'sql-statement)

(deflexical *sdbc-test-row-cardinality* 25
  "[Cyc] The number of rows created and validated in each separate sdbc test.")

;;; Functions (ordered by declare_sdbc_file)

;; sql-proxy-server-running? (0 3) -- commented, no body
;; (defun sql-proxy-server-running? (&optional host port timeout) ...) -- no body

(defun sql-connection-print-function-trampoline (object stream)
  "[Cyc] Print function trampoline for SQL-CONNECTION."
  (declare (ignore object stream))
  (missing-larkc 12022))

;; sql-connection-p (1 0) -- commented, no body
;; (defun sql-connection-p (object) ...) -- no body
;; Struct accessors sqlc-db .. sqlc-mailman and _csetf_ setters generated by defstruct

;; make-sql-connection (0 1) -- commented, no body
;; (defun make-sql-connection (&optional arglist) ...) -- no body
;; sqlc-print (3 0) -- commented, no body
;; (defun sqlc-print (object stream depth) ...) -- no body
;; sqlc-print-string (1 0) -- commented, no body
;; (defun sqlc-print-string (connection) ...) -- no body
;; new-sql-connection (3 1) -- commented, no body
;; (defun new-sql-connection (db user password &optional options) ...) -- no body
;; sql-open-connection-p (1 0) -- commented, no body
;; (defun sql-open-connection-p (connection) ...) -- no body
;; sqlc-open-p (1 0) -- commented, no body
;; (defun sqlc-open-p (connection) ...) -- no body
;; sqlc-close (1 0) -- commented, no body
;; (defun sqlc-close (connection) ...) -- no body
;; sqlc-create-statement (1 0) -- commented, no body
;; (defun sqlc-create-statement (connection) ...) -- no body
;; sqlc-prepare-statement (2 0) -- commented, no body
;; (defun sqlc-prepare-statement (connection sql) ...) -- no body
;; sqlc-set-auto-commit (2 0) -- commented, no body
;; (defun sqlc-set-auto-commit (connection value) ...) -- no body
;; sqlc-get-auto-commit (1 0) -- commented, no body
;; (defun sqlc-get-auto-commit (connection) ...) -- no body
;; sqlc-commit (1 0) -- commented, no body
;; (defun sqlc-commit (connection) ...) -- no body
;; sqlc-rollback (1 0) -- commented, no body
;; (defun sqlc-rollback (connection) ...) -- no body
;; sqlc-get-transaction-isolation (1 0) -- commented, no body
;; (defun sqlc-get-transaction-isolation (connection) ...) -- no body
;; sqlc-set-transaction-isolation (2 0) -- commented, no body
;; (defun sqlc-set-transaction-isolation (connection level) ...) -- no body

(defun sql-ticket-print-function-trampoline (object stream)
  "[Cyc] Print function trampoline for SQL-TICKET."
  (compatibility-default-struct-print-function object stream 0)
  nil)

;; sql-ticket-p (1 0) -- commented, no body
;; (defun sql-ticket-p (object) ...) -- no body
;; Struct accessors sql-ticket-semaphore, sql-ticket-result and _csetf_ setters generated by defstruct

;; make-sql-ticket (0 1) -- commented, no body
;; (defun make-sql-ticket (&optional arglist) ...) -- no body
;; new-sql-ticket (0 0) -- commented, no body
;; (defun new-sql-ticket () ...) -- no body
;; sql-ticket-retrieve (1 0) -- commented, no body
;; (defun sql-ticket-retrieve (ticket) ...) -- no body
;; launch-sql-mailman (1 0) -- commented, no body
;; (defun launch-sql-mailman (connection) ...) -- no body
;; sqlc-deliver (1 0) -- commented, no body
;; (defun sqlc-deliver (connection) ...) -- no body
;; sqlc-execute (3 0) -- commented, no body
;; (defun sqlc-execute (connection command args) ...) -- no body
;; sqlc-send (4 0) -- commented, no body
;; (defun sqlc-send (connection ticket command args) ...) -- no body
;; sqlc-receive (1 0) -- commented, no body
;; (defun sqlc-receive (connection) ...) -- no body
;; sqlc-handle-error (2 0) -- commented, no body
;; (defun sqlc-handle-error (connection error) ...) -- no body
;; sql-transaction-level-p (1 0) -- commented, no body
;; (defun sql-transaction-level-p (object) ...) -- no body
;; sqlc-set-error-handling (2 0) -- commented, no body
;; (defun sqlc-set-error-handling (connection handling) ...) -- no body
;; new-sql-response (2 0) -- commented, no body
;; (defun new-sql-response (code value) ...) -- no body
;; sql-response-code (1 0) -- commented, no body
;; (defun sql-response-code (response) ...) -- no body
;; sql-response-value (1 0) -- commented, no body
;; (defun sql-response-value (response) ...) -- no body
;; sql-null-p (1 0) -- commented, no body
;; (defun sql-null-p (object) ...) -- no body
;; sql-true-p (1 0) -- commented, no body
;; (defun sql-true-p (object) ...) -- no body
;; sql-false-p (1 0) -- commented, no body
;; (defun sql-false-p (object) ...) -- no body

(defun sdbc-error-print-function-trampoline (object stream)
  "[Cyc] Print function trampoline for SDBC-ERROR."
  (declare (ignore object stream))
  (missing-larkc 11943))

;; sdbc-error-p (1 0) -- commented, no body
;; (defun sdbc-error-p (object) ...) -- no body
;; Struct accessors sdbc-error-type, sdbc-error-message, sdbc-error-code and _csetf_ setters generated by defstruct

;; make-sdbc-error (0 1) -- commented, no body
;; (defun make-sdbc-error (&optional arglist) ...) -- no body
;; sdbc-error-throw (1 0) -- commented, no body
;; (defun sdbc-error-throw (error) ...) -- no body
;; sdbc-error-warn (1 0) -- commented, no body
;; (defun sdbc-error-warn (error) ...) -- no body
;; sdbc-server-error-p (1 0) -- commented, no body
;; (defun sdbc-server-error-p (error) ...) -- no body
;; sdbc-client-error-p (1 0) -- commented, no body
;; (defun sdbc-client-error-p (error) ...) -- no body
;; sdbc-sql-error-p (1 0) -- commented, no body
;; (defun sdbc-sql-error-p (error) ...) -- no body
;; sdbc-io-error-p (1 0) -- commented, no body
;; (defun sdbc-io-error-p (error) ...) -- no body
;; sdbc-transaction-error-p (1 0) -- commented, no body
;; (defun sdbc-transaction-error-p (error) ...) -- no body
;; sdbc-batch-update-error-p (1 0) -- commented, no body
;; (defun sdbc-batch-update-error-p (error) ...) -- no body
;; sdbc-other-error-p (1 0) -- commented, no body
;; (defun sdbc-other-error-p (error) ...) -- no body
;; new-sdbc-error (2 1) -- commented, no body
;; (defun new-sdbc-error (type message &optional code) ...) -- no body
;; sdbc-error-print (3 0) -- commented, no body
;; (defun sdbc-error-print (object stream depth) ...) -- no body
;; decode-sdbc-error-code (1 0) -- commented, no body
;; (defun decode-sdbc-error-code (code) ...) -- no body

(defun sql-result-set-print-function-trampoline (object stream)
  "[Cyc] Print function trampoline for SQL-RESULT-SET."
  (declare (ignore object stream))
  (missing-larkc 12057))

;; sql-result-set-p (1 0) -- commented, no body
;; (defun sql-result-set-p (object) ...) -- no body
;; Struct accessors sqlrs-rows .. sqlrs-id and _csetf_ setters generated by defstruct

;; make-sql-result-set (0 1) -- commented, no body
;; (defun make-sql-result-set (&optional arglist) ...) -- no body
;; sqlrs-print (3 0) -- commented, no body
;; (defun sqlrs-print (object stream depth) ...) -- no body
;; sql-open-result-set-p (1 0) -- commented, no body
;; (defun sql-open-result-set-p (result-set) ...) -- no body
;; sqlrs-close (1 0) -- commented, no body
;; (defun sqlrs-close (result-set) ...) -- no body
;; sqlrs-empty? (1 0) -- commented, no body
;; (defun sqlrs-empty? (result-set) ...) -- no body
;; sqlrs-absolute (2 0) -- commented, no body
;; (defun sqlrs-absolute (result-set row) ...) -- no body
;; sqlrs-next (1 0) -- commented, no body
;; (defun sqlrs-next (result-set) ...) -- no body
;; sqlrs-previous (1 0) -- commented, no body
;; (defun sqlrs-previous (result-set) ...) -- no body
;; sqlrs-is-last (1 0) -- commented, no body
;; (defun sqlrs-is-last (result-set) ...) -- no body
;; sqlrs-is-first (1 0) -- commented, no body
;; (defun sqlrs-is-first (result-set) ...) -- no body
;; sqlrs-column-count (1 0) -- commented, no body
;; (defun sqlrs-column-count (result-set) ...) -- no body
;; sqlrs-row-count (1 0) -- commented, no body
;; (defun sqlrs-row-count (result-set) ...) -- no body
;; sqlrs-get-row (1 0) -- commented, no body
;; (defun sqlrs-get-row (result-set) ...) -- no body
;; sqlrs-get-object (2 0) -- commented, no body
;; (defun sqlrs-get-object (result-set column) ...) -- no body
;; sqlrs-get-object-tuple (1 0) -- commented, no body
;; (defun sqlrs-get-object-tuple (result-set) ...) -- no body
;; new-sql-result-set (3 0) -- commented, no body
;; (defun new-sql-result-set (connection rows id) ...) -- no body
;; sqlrs-closed-p (1 0) -- commented, no body
;; (defun sqlrs-closed-p (result-set) ...) -- no body
;; sqlrs-open-p (1 0) -- commented, no body
;; (defun sqlrs-open-p (result-set) ...) -- no body
;; sqlrs-valid-row-p (1 0) -- commented, no body
;; (defun sqlrs-valid-row-p (result-set) ...) -- no body
;; sqlrs-valid-column-p (2 0) -- commented, no body
;; (defun sqlrs-valid-column-p (result-set column) ...) -- no body
;; sqlrs-block (2 0) -- commented, no body
;; (defun sqlrs-block (result-set row) ...) -- no body
;; sqlrs-row-local-p (1 0) -- commented, no body
;; (defun sqlrs-row-local-p (result-set) ...) -- no body
;; sqlrs-row-remote-p (1 0) -- commented, no body
;; (defun sqlrs-row-remote-p (result-set) ...) -- no body
;; sqlrs-local-close (1 0) -- commented, no body
;; (defun sqlrs-local-close (result-set) ...) -- no body

(defun sql-statement-print-function-trampoline (object stream)
  "[Cyc] Print function trampoline for SQL-STATEMENT."
  (compatibility-default-struct-print-function object stream 0)
  nil)

;; sql-statement-p (1 0) -- commented, no body
;; (defun sql-statement-p (object) ...) -- no body
;; Struct accessors sqls-connection .. sqls-rs and _csetf_ setters generated by defstruct

;; make-sql-statement (0 1) -- commented, no body
;; (defun make-sql-statement (&optional arglist) ...) -- no body
;; sqls-open-p (1 0) -- commented, no body
;; (defun sqls-open-p (statement) ...) -- no body
;; sql-open-statement-p (1 0) -- commented, no body
;; (defun sql-open-statement-p (statement) ...) -- no body
;; sqls-execute-query (2 1) -- commented, no body
;; (defun sqls-execute-query (statement sql &optional block-size) ...) -- no body
;; sqls-execute-update (2 0) -- commented, no body
;; (defun sqls-execute-update (statement sql) ...) -- no body
;; sqls-cancel (1 0) -- commented, no body
;; (defun sqls-cancel (statement) ...) -- no body
;; sqls-get-generated-keys (1 1) -- commented, no body
;; (defun sqls-get-generated-keys (statement &optional block-size) ...) -- no body
;; sqls-close (1 0) -- commented, no body
;; (defun sqls-close (statement) ...) -- no body
;; sqls-add-batch (2 0) -- commented, no body
;; (defun sqls-add-batch (statement sql) ...) -- no body
;; sqls-clear-batch (1 0) -- commented, no body
;; (defun sqls-clear-batch (statement) ...) -- no body
;; sqls-execute-batch (1 0) -- commented, no body
;; (defun sqls-execute-batch (statement) ...) -- no body
;; sql-prepared-statement-p (1 0) -- commented, no body
;; (defun sql-prepared-statement-p (statement) ...) -- no body
;; sql-prepared-open-statement-p (1 0) -- commented, no body
;; (defun sql-prepared-open-statement-p (statement) ...) -- no body
;; sqlps-execute-query (1 1) -- commented, no body
;; (defun sqlps-execute-query (statement &optional block-size) ...) -- no body
;; sqlps-execute-update (1 0) -- commented, no body
;; (defun sqlps-execute-update (statement) ...) -- no body
;; sqlps-set-bytes (3 0) -- commented, no body
;; (defun sqlps-set-bytes (statement index value) ...) -- no body
;; sqlps-set-int (3 0) -- commented, no body
;; (defun sqlps-set-int (statement index value) ...) -- no body
;; sqlps-set-long (3 0) -- commented, no body
;; (defun sqlps-set-long (statement index value) ...) -- no body
;; sqlps-set-float (3 0) -- commented, no body
;; (defun sqlps-set-float (statement index value) ...) -- no body
;; sqlps-set-double (3 0) -- commented, no body
;; (defun sqlps-set-double (statement index value) ...) -- no body
;; sqlps-set-string (3 0) -- commented, no body
;; (defun sqlps-set-string (statement index value) ...) -- no body
;; new-sql-statement (1 0) -- commented, no body
;; (defun new-sql-statement (connection) ...) -- no body
;; sqls-get-connection (1 0) -- commented, no body
;; (defun sqls-get-connection (statement) ...) -- no body
;; sqls-local-close (1 0) -- commented, no body
;; (defun sqls-local-close (statement) ...) -- no body
;; sqlps-set (4 0) -- commented, no body
;; (defun sqlps-set (statement command index value) ...) -- no body
;; new-sql-prepared-statement (2 0) -- commented, no body
;; (defun new-sql-prepared-statement (connection sql) ...) -- no body
;; new-statement-id (0 0) -- commented, no body
;; (defun new-statement-id () ...) -- no body
;; new-result-set-id (0 0) -- commented, no body
;; (defun new-result-set-id () ...) -- no body
;; sqlc-get-tables (5 0) -- commented, no body
;; (defun sqlc-get-tables (connection catalog schema table-name-pattern types block-size) ...) -- no body
;; sqlc-get-tables-meta-data (5 0) -- commented, no body
;; (defun sqlc-get-tables-meta-data (connection catalog schema table-name-pattern types block-size) ...) -- no body
;; sqlc-get-columns (5 0) -- commented, no body
;; (defun sqlc-get-columns (connection catalog schema table-name-pattern column-name-pattern block-size) ...) -- no body
;; sqlc-get-columns-meta-data (5 0) -- commented, no body
;; (defun sqlc-get-columns-meta-data (connection catalog schema table-name-pattern column-name-pattern block-size) ...) -- no body
;; sqlc-get-primary-keys (4 0) -- commented, no body
;; (defun sqlc-get-primary-keys (connection catalog schema table-name block-size) ...) -- no body
;; sqlc-get-primary-keys-meta-data (4 0) -- commented, no body
;; (defun sqlc-get-primary-keys-meta-data (connection catalog schema table-name block-size) ...) -- no body
;; sqlc-get-imported-keys (4 0) -- commented, no body
;; (defun sqlc-get-imported-keys (connection catalog schema table-name block-size) ...) -- no body
;; sqlc-get-imported-keys-meta-data (4 0) -- commented, no body
;; (defun sqlc-get-imported-keys-meta-data (connection catalog schema table-name block-size) ...) -- no body
;; sqlc-get-exported-keys (4 0) -- commented, no body
;; (defun sqlc-get-exported-keys (connection catalog schema table-name block-size) ...) -- no body
;; sqlc-get-exported-keys-meta-data (4 0) -- commented, no body
;; (defun sqlc-get-exported-keys-meta-data (connection catalog schema table-name block-size) ...) -- no body
;; sqlc-get-index-info (6 0) -- commented, no body
;; (defun sqlc-get-index-info (connection catalog schema table-name unique approximate block-size) ...) -- no body
;; sqlc-get-index-info-meta-data (6 0) -- commented, no body
;; (defun sqlc-get-index-info-meta-data (connection catalog schema table-name unique approximate block-size) ...) -- no body
;; sqlc-get-max-connections (1 0) -- commented, no body
;; (defun sqlc-get-max-connections (connection) ...) -- no body
;; sdbc-error-handling-tag-p (1 0) -- commented, no body
;; (defun sdbc-error-handling-tag-p (object) ...) -- no body
;; new-db-url (5 0) -- commented, no body
;; (defun new-db-url (subprotocol dbname user password dbms-server) ...) -- no body
;; java-integerp (1 0) -- commented, no body
;; (defun java-integerp (value) ...) -- no body
;; java-longp (1 0) -- commented, no body
;; (defun java-longp (value) ...) -- no body
;; java-floatp (1 0) -- commented, no body
;; (defun java-floatp (value) ...) -- no body
;; java-doublep (1 0) -- commented, no body
;; (defun java-doublep (value) ...) -- no body

;;; Macros (all commented-out declareMacro entries)
;; with-sql-connection - macro, no body
;; with-sql-statement - macro, no body
;; with-prepared-sql-statement - macro, no body
;; sqls-execute-transaction - macro, no body
;; with-sql-transaction - macro, no body
;; with-sql-result-set - macro, no body
;; do-sql-result-set - macro, no body

;; sqls-handle-commit-error (1 0) -- commented, no body
;; (defun sqls-handle-commit-error (error) ...) -- no body
;; sqls-handle-rollback (1 0) -- commented, no body
;; (defun sqls-handle-rollback (connection) ...) -- no body
;; sqls-handle-transaction-errors (1 0) -- commented, no body
;; (defun sqls-handle-transaction-errors (errors) ...) -- no body

;; sql-export (4 5) -- commented, no body
;; (defun sql-export (result-set stream col-separator &rest options) ...) -- no body
;; sdbc-test (3 5) -- commented, no body
;; (defun sdbc-test (db user password &rest options) ...) -- no body
;; sdbc-test-prepared (3 5) -- commented, no body
;; (defun sdbc-test-prepared (db user password &rest options) ...) -- no body
;; sdbc-test-created (3 5) -- commented, no body
;; (defun sdbc-test-created (db user password &rest options) ...) -- no body
;; sdbc-test-batch (3 5) -- commented, no body
;; (defun sdbc-test-batch (db user password &rest options) ...) -- no body

;;; Setup phase

(register-macro-helper 'sqlc-set-error-handling 'sqls-execute-transaction)
(register-macro-helper 'sqls-get-connection 'sqls-execute-transaction)
(register-macro-helper 'sqls-handle-commit-error 'sqls-execute-transaction)
(register-macro-helper 'sqls-handle-rollback 'sqls-execute-transaction)
(register-macro-helper 'sqls-handle-transaction-errors 'sqls-execute-transaction)
