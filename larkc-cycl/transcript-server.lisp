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

(defun use-transcript-server ()
  "[Cyc] Accessor for *use-transcript-server*."
  *use-transcript-server*)

;; TODO — with-transcript-server-connection macro
;; Arglist from $list0: ((CHANNEL &KEY OPERATION-TIMEOUT) &BODY BODY)
;; Keywords: $list1 = (:OPERATION-TIMEOUT), $kw2 = :ALLOW-OTHER-KEYS
;; Gensyms: $sym4 = #:ERROR-MESSAGE, $sym5 = #:CONNECTED, $sym6 = #:INCOMPLETE
;; Operators: CLET ($sym7), CATCH-ERROR-MESSAGE ($sym8), WITH-TCP-CONNECTION ($sym9),
;;   CSETQ ($sym11), WITH-TIMEOUT ($sym13), PROGN ($sym14),
;;   PUNLESS ($sym15), PWHEN ($sym17), STRINGP ($sym19), WARN ($sym20)
;; Connection params from $list10: (*MASTER-TRANSCRIPT-LOCK-HOST*
;;   *MASTER-TRANSCRIPT-SERVER-PORT* :TIMEOUT *MASTER-TRANSCRIPT-SERVER-CONNECTION-TIMEOUT*
;;   :ACCESS-MODE :PRIVATE)
;; Error forms: $list16 = ((ERROR "Transcript server connection timeout")),
;;   $list18 = ((ERROR "Transcript server operation timeout"))
;; Warn format: $str21 = "~A: Error while connecting to transcript server!~%~A~%"
;; Warn args: $list22 = (TIMESTRING)
;;
;; Known structure: CLET binds 3 gensyms. CATCH-ERROR-MESSAGE takes (VAR &BODY BODY)
;; per subl_macros.java $list169 — binds VAR to caught error, does NOT return it.
;; WITH-TCP-CONNECTION and WITH-TIMEOUT are also macros from subl-macro-promotions.
;; After the connection block: PUNLESS connected → error; PWHEN stringp error-message → warn.
;;
;; NOT reconstructed because: no visible expansion sites in the Java codebase (all
;; call sites are in commented-out function bodies). The exact nesting of
;; catch-error-message / with-tcp-connection / with-timeout is uncertain without
;; an expansion to verify against. The INCOMPLETE gensym's role is also unclear.

;; TODO — transcript-server-message-body macro
;; Arglist from $list23: (CHANNEL &BODY BODY)
;; Operators: TRANSCRIPT-SERVER-MESSAGE-STARTUP ($sym24),
;;   TRANSCRIPT-SERVER-MESSAGE-SHUTDOWN ($sym25)
;; Error string: $str26 = "Connection to transcript server was not cleanly closed"
;;
;; Likely structure: calls startup, runs body, calls shutdown with cleanup warning.
;; NOT reconstructed because: no visible expansion sites; the exact error-handling
;; structure (unwind-protect? conditional on shutdown return value? warn vs error?)
;; cannot be confirmed without an expansion to verify against.

;; (defun transcript-server-message-startup (channel) ...) -- commented declareFunction, no body
;; (defun transcript-server-message-shutdown (channel) ...) -- commented declareFunction, no body
;; (defun transcript-server-terpri (channel &optional string) ...) -- commented declareFunction, no body
;; (defun transcript-server-read-line (channel) ...) -- commented declareFunction, no body
;; (defun transcript-server-reply-verify (channel expected-reply) ...) -- commented declareFunction, no body
;; (defun ts-ack-server-connection (channel) ...) -- commented declareFunction, no body
;; (defun ts-send-set-image-message (channel) ...) -- commented declareFunction, no body
;; (defun ts-send-set-kb-message (channel) ...) -- commented declareFunction, no body
;; (defun ts-send-set-op-message (channel) ...) -- commented declareFunction, no body
;; (defun ts-send-how-many-ops-message (channel direction) ...) -- commented declareFunction, no body
;; (defun ts-send-send-ops-begin-message (channel num-ops) ...) -- commented declareFunction, no body
;; (defun ts-send-send-ops-op (channel op) ...) -- commented declareFunction, no body
;; (defun ts-send-send-ops-end-message (channel) ...) -- commented declareFunction, no body
;; (defun ts-read-send-ops-reply (channel) ...) -- commented declareFunction, no body
;; (defun ts-send-get-ops-message (channel) ...) -- commented declareFunction, no body
;; (defun ts-send-quit-message (channel) ...) -- commented declareFunction, no body
;; (defun transcript-server-connection-check () ...) -- commented declareFunction, no body
;; (defun transcript-server-check () ...) -- commented declareFunction, no body
;; (defun total-master-transcript-operations (&optional direction) ...) -- commented declareFunction, no body
;; (defun send-operations-to-server () ...) -- commented declareFunction, no body
;; (defun send-operations-to-server-internal (channel) ...) -- commented declareFunction, no body
;; (defun read-operations-from-server () ...) -- commented declareFunction, no body
;; (defun read-operations-from-server-internal (channel) ...) -- commented declareFunction, no body
;; (defun read-one-transcript-operation-from-server (channel) ...) -- commented declareFunction, no body

(deflexical *master-transcript-server-connection-timeout* 10
  "[Cyc] Timeout value (in seconds) when connecting with the transcript server.")

(defvar *transcript-server-protocol-version* 1
  "[Cyc] The version of the transcript server protocol.
0 = initial version
1 = current version")
