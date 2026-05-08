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


;;;; Variables

(defglobal *guardian-process* nil)

(defglobal *guarding-requests* nil)

(deflexical *guardian-timeslice* 2)

(defglobal *guardian-isg*
    (new-integer-sequence-generator))


;;;; GUARDIAN-REQUEST struct — 6 slots
;; print-object is missing-larkc 29594 — CL's default print-object handles this.

(defstruct guardian-request
  id
  checker-fn
  parameter
  notification-fn
  interrupt-p
  process)

(defconstant *dtp-guardian-request* 'guardian-request)

;; guardian-request-p is provided by defstruct
;; guardian-request-id is provided by defstruct
;; guardian-request-checker-fn is provided by defstruct
;; guardian-request-parameter is provided by defstruct
;; guardian-request-notification-fn is provided by defstruct
;; guardian-request-interrupt-p is provided by defstruct
;; guardian-request-process is provided by defstruct
;; _csetf-guardian-request-id is setf of guardian-request-id
;; _csetf-guardian-request-checker-fn is setf of guardian-request-checker-fn
;; _csetf-guardian-request-parameter is setf of guardian-request-parameter
;; _csetf-guardian-request-notification-fn is setf of guardian-request-notification-fn
;; _csetf-guardian-request-interrupt-p is setf of guardian-request-interrupt-p
;; _csetf-guardian-request-process is setf of guardian-request-process
;; make-guardian-request is provided by defstruct

;; new-guardian-request (id checker-fn parameter notification-fn interrupt-p) — active declareFunction, no body
;; (defun new-guardian-request (id checker-fn parameter notification-fn interrupt-p) ...) -- active declareFunction, no body

(defun print-guardian-request (object stream depth)
  "[Cyc] Print function for guardian-request structs."
  (declare (ignore depth))
  (declare (ignore object stream))
  ;; Printed format string was "#<GUARDIAN-REQUEST ~A: check ~A argument ~A notify ~A via ~A using ~A>"
  ;; but the body was stripped by LarKC.
  (missing-larkc 29594))

;; schedule-guardian-request (checker-fn parameter notification-fn &optional process interrupt-p)
;; Cyc API, active declareFunction, no body
;; (defun schedule-guardian-request (checker-fn parameter notification-fn &optional process interrupt-p) ...) -- active declareFunction, no body

;; guardian-request-id-p (request-id) — Cyc API, active declareFunction, no body
;; (defun guardian-request-id-p (request-id) ...) -- active declareFunction, no body

;; cancel-guardian-request (request-id) — Cyc API, active declareFunction, no body
;; (defun cancel-guardian-request (request-id) ...) -- active declareFunction, no body

;; with-guardian-request — active declareMacro
;; Reconstructed from Internal Constants evidence:
;; $list50 = ((CHECKER-FN PARAMETER NOTIFICATION-FN) &BODY BODY) — the macro arglist
;; $sym51$REQUEST_ID = makeUninternedSymbol("REQUEST-ID") — gensym for the request id
;; $sym52$PROGN, $list53 = (ENSURE-GUARDIAN-RUNNING),
;; $sym54$CLET, $sym55$CUNWIND_PROTECT, $sym56$PWHEN — operators in expansion
;; $str58 "Setup a guardian request and cancel if necessary." — docstring
;; Registered via register-cyc-api-macro with $list50 as pattern.
(defmacro with-guardian-request ((checker-fn parameter notification-fn) &body body)
  "[Cyc] Setup a guardian request and cancel if necessary."
  (with-temp-vars (request-id)
    `(progn
       (ensure-guardian-running)
       (let ((,request-id (schedule-guardian-request ,checker-fn ,parameter ,notification-fn)))
         (unwind-protect
              (progn ,@body)
           (when ,request-id
             (cancel-guardian-request ,request-id)))))))

;; active-guardian-requests () — Cyc API, active declareFunction, no body
;; (defun active-guardian-requests () ...) -- active declareFunction, no body

;; print-active-guardian-requests (&optional stream) — active declareFunction, no body
;; (defun print-active-guardian-requests (&optional stream) ...) -- active declareFunction, no body

;; current-guardian-process () — active declareFunction, no body
;; (defun current-guardian-process () ...) -- active declareFunction, no body

;; initialize-guardian () — Cyc API, active declareFunction, no body
;; (defun initialize-guardian () ...) -- active declareFunction, no body

(defglobal *guardian-shutdown-marker*
    (make-symbol "Guardian Shutdown Marker"))

;; stop-guardian () — Cyc API, active declareFunction, no body
;; (defun stop-guardian () ...) -- active declareFunction, no body

;; start-guardian () — Cyc API, active declareFunction, no body
;; (defun start-guardian () ...) -- active declareFunction, no body

;; ensure-guardian-running () — Cyc API, active declareFunction, no body
;; (defun ensure-guardian-running () ...) -- active declareFunction, no body

;; is-guardian-shutdown-marker (marker) — active declareFunction, no body
;; (defun is-guardian-shutdown-marker (marker) ...) -- active declareFunction, no body

;; guardian-handler () — active declareFunction, no body
;; (defun guardian-handler () ...) -- active declareFunction, no body

;; check-guardian-request (request) — active declareFunction, no body
;; (defun check-guardian-request (request) ...) -- active declareFunction, no body

(defglobal *guardian-sleep-marker*
    (make-symbol "Guardian Sleep Marker"))


;;;; Setup

(toplevel
  (declare-defglobal '*guardian-process*)
  (declare-defglobal '*guarding-requests*)
  (declare-defglobal '*guardian-isg*)
  (register-cyc-api-function 'schedule-guardian-request
                             '(checker-fn parameter notification-fn &optional process interrupt-p)
                             "Schedule a guardian request. (funcall checker-fn parameter) will be called
   until it returns NIL.
   In this case, the requesting process is notified, either via FUNCALL or INTERRUPT-PROCESS-WITH-ARGS
   and passed the parameter one last time; the INTERRUPT-P flag decides which one it is; FUNCALL is default.
   @note use FUNCALL when the function invoked cannot or need not run in the process being notified;
   for example, TERMINATE-ACTIVE-TASK-PROCESS already calls INTERRRUPT-PROCESS, and not all LISP implementation
   actually handle that gracefully, so there FUNCALL is sufficient.
   @return the ticked for the guardian request"
                             '((checker-fn function-spec-p)
                               (notification-fn function-spec-p)
                               (interrupt-p booleanp))
                             '(fixnump))
  (register-cyc-api-function 'guardian-request-id-p
                             '(request-id)
                             "Determine whether this is a proper guardian request id."
                             nil
                             '(booleanp))
  (register-cyc-api-function 'cancel-guardian-request
                             '(request-id)
                             "Abort a guardian request that is currently scheduled to be checked.
   @return T"
                             '((request-id fixnump))
                             '(symbolp))
  (register-cyc-api-macro 'with-guardian-request
                          '((checker-fn parameter notification-fn) &body body)
                          "Setup a guardian request and cancel if necessary.")
  (register-cyc-api-function 'active-guardian-requests
                             nil
                             "The active guardian requests.
   @return 0 the elements on the request queue
   @return 1 the UnivTime Stamp of the contents"
                             nil
                             nil)
  (register-cyc-api-function 'initialize-guardian
                             nil
                             "Starts the guardian unless it is running."
                             nil
                             '(booleanp))
  (declare-defglobal '*guardian-shutdown-marker*)
  (register-cyc-api-function 'stop-guardian
                             nil
                             "Tell the guardian to shut itself down."
                             nil
                             '(booleanp))
  (register-cyc-api-function 'start-guardian
                             nil
                             "Launch the guardian process, potentially overwriting an existing guardian."
                             nil
                             '(booleanp))
  (register-cyc-api-function 'ensure-guardian-running
                             nil
                             "Launch the guardian process if it is not currently running."
                             nil
                             '(booleanp))
  (declare-defglobal '*guardian-sleep-marker*))
