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

;; This is a PARTIAL PORT. lucene_session.java has all 31 declareFunction
;; entries active, but only lucene_session_print_function_trampoline has a
;; Java method body (and that body is handleMissingMethodError 29219). Every
;; other function had its body stripped by LarKC, so each is preserved as a
;; one-line comment stub with its declared arity. The defstruct, variables,
;; with-lucene-session macro (reconstructed from Internal Constants), and
;; print-object defmethod are ported directly.


;;;; Variables

(defparameter *lucene-host* "semanticsearch")

(defparameter *lucene-port* 1928)

(defparameter *lucene-host-override* nil
  "[Cyc] Specifying a value for this will override any other setting that might get bound elsewhere")

(defparameter *lucene-port-override* nil
  "[Cyc] Specifying a value for this will override any other settings that might get bound elsewhere")

(deflexical *init-lucene-session* 0)

(deflexical *add-document* 1)

(deflexical *query* 2)

(deflexical *optimize* 3)

(deflexical *close-index* 4)

(deflexical *new-index-writer* 5)


;;;; LUCENE-SESSION defstruct
;; 6 slots: host, port, connection, session-type, index, overwrite.
;; Java _csetf_ accessor names are LUCENE-HOST, LUCENE-PORT, LUCENE-CONNECTION,
;; LUCENE-SESSION-TYPE, LUCENE-INDEX, LUCENE-OVERWRITE (per $list14), so
;; the defstruct conc-name is "LUCENE-".
;; print-object is missing-larkc 29219 — CL's default print-object handles this.

(defstruct (lucene-session (:conc-name "LUCENE-"))
  host
  port
  connection
  session-type
  index
  overwrite)

(defconstant *dtp-lucene-session* 'lucene-session)


;;;; Functions (ordered by declare_lucene_session_file)

;; (defun get-lucene-host () ...) -- active declareFunction, no body
;; (defun get-lucene-port () ...) -- active declareFunction, no body

;;; Macro (reconstructed from Internal Constants evidence)
;; $list2 = ((SESSION INDEX TYPE &OPTIONAL (HOST (GET-LUCENE-HOST)) (PORT (GET-LUCENE-PORT))) &BODY BODY)
;; Orphan constants: $sym3$CLET, $sym4$CUNWIND_PROTECT, $sym5$PROGN, $sym6$CSETQ,
;;   $sym7$NEW_LUCENE_SESSION, $sym8$PWHEN, $sym9$LUCENE_SESSION_P, $sym10$LUCENE_FINALIZE
;; Reconstruction: binds SESSION via NEW-LUCENE-SESSION, with CUNWIND-PROTECT to
;; LUCENE-FINALIZE on cleanup.
(defmacro with-lucene-session ((session index type &optional (host '(get-lucene-host))
                                                             (port '(get-lucene-port)))
                               &body body)
  `(clet ((,session nil))
     (cunwind-protect
         (progn
           (csetq ,session (new-lucene-session ,host ,port ,index ,type))
           ,@body)
       (pwhen (lucene-session-p ,session)
         (lucene-finalize ,session)))))


;; (defun lucene-session-p (object) ...) -- active declareFunction, no body (provided by defstruct)
;; (defun lucene-host (session) ...) -- active declareFunction, no body (accessor provided by defstruct)
;; (defun lucene-port (session) ...) -- active declareFunction, no body (accessor provided by defstruct)
;; (defun lucene-connection (session) ...) -- active declareFunction, no body (accessor provided by defstruct)
;; (defun lucene-session-type (session) ...) -- active declareFunction, no body (accessor provided by defstruct)
;; (defun lucene-index (session) ...) -- active declareFunction, no body (accessor provided by defstruct)
;; (defun lucene-overwrite (session) ...) -- active declareFunction, no body (accessor provided by defstruct)
;; _csetf-lucene-host -- active declareFunction, no body (CL setf handles natively)
;; _csetf-lucene-port -- active declareFunction, no body (CL setf handles natively)
;; _csetf-lucene-connection -- active declareFunction, no body (CL setf handles natively)
;; _csetf-lucene-session-type -- active declareFunction, no body (CL setf handles natively)
;; _csetf-lucene-index -- active declareFunction, no body (CL setf handles natively)
;; _csetf-lucene-overwrite -- active declareFunction, no body (CL setf handles natively)
;; (defun make-lucene-session (&optional arglist) ...) -- active declareFunction, no body (constructor provided by defstruct)
;; (defun new-lucene-session (host port index type &optional overwrite) ...) -- active declareFunction, no body
;; (defun lucene-finalize (session) ...) -- active declareFunction, no body
;; (defun lucene-print (object stream depth) ...) -- active declareFunction, no body
;; (defun lucene-init (session host port) ...) -- active declareFunction, no body
;; (defun lucene-new-index-writer (session &optional overwrite) ...) -- active declareFunction, no body
;; (defun lucene-close-index-writer (session) ...) -- active declareFunction, no body
;; (defun default-lucene-confirmed-terms-boost () ...) -- active declareFunction, no body
;; (defun lucene-add-document (session term-string concept-string confirmed-terms-string boost-value &optional document-id non-linking-phrase-string) ...) -- active declareFunction, no body
;; (defun lucene-optimize (session) ...) -- active declareFunction, no body
;; (defun lucene-query (session query-string &optional max-results) ...) -- active declareFunction, no body
;; (defun lucene-send (session message-type message) ...) -- active declareFunction, no body
;; (defun lucene-receive (session) ...) -- active declareFunction, no body
;; (defun lucene-execute (session message-type message) ...) -- active declareFunction, no body
;; (defun interpret-lucene-response (response) ...) -- active declareFunction, no body


;;;; Setup
;; Elided: def_csetf calls (CL setf on defstruct accessors is native).
;; Elided: register_method(print_object_method_table, ...) (replaced by defmethod print-object above).
;; Equality.identity(LUCENE-SESSION) is a no-op identity marker; no Lisp equivalent needed.
