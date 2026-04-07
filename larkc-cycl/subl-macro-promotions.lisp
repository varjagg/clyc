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

;; DEFGLOBAL macro and DECLARE-DEFGLOBAL function are defined in subl-support.lisp
;; since they are fundamental forms needed before any cycl file loads.
;; They originate from this file in the Java source.

;; Reconstructed from Internal Constants:
;; $list11 = ((VAR) &BODY BODY) — arglist
;; $sym12 = CCATCH, $sym13 = WITH-ERROR-HANDLER
;; $list14 = (QUOTE CATCH-ERROR-MESSAGE-HANDLER)
;; Verified against expansion sites in ke.java:146, api_kernel.java:288,
;; cfasl_kernel.java:189, java_api_kernel.java:169, etc.
;; Pattern: try { with-error-handler binding... body } catch { handleThrowable(tag) }
;; CL version uses handler-case directly instead of SubL's ccatch+with-error-handler.
(defmacro catch-error-message ((var) &body body)
  `(setf ,var (handler-case (progn ,@body nil)
                (error (c) (princ-to-string c)))))

;; SubL runtime variable; set by the error system when an error occurs.
;; Referenced by catch-error-message-handler. Defined in Errors.java as $error_message$.
(defvar *error-message* nil)

(defun catch-error-message-handler ()
  "[Cyc] Internal function for CATCH-ERROR-MESSAGE"
  (throw *catch-error-message-target* *error-message*))

;; Reconstructed from Internal Constants:
;; $list15 = ((TIME TIMED-OUT-VAR) &BODY BODY) — arglist
;; $sym16 = TAG (uninternedSymbol), $sym17 = TIMER (uninternedSymbol) — gensyms
;; $sym18 = CLET, $list19 = ((WITH-TIMEOUT-MAKE-TAG))
;; $list20 = (*WITHIN-WITH-TIMEOUT* T)
;; $sym21 = CUNWIND-PROTECT, $list22 = ((*WITH-TIMEOUT-NESTING-DEPTH* (+ 1 *WITH-TIMEOUT-NESTING-DEPTH*)))
;; $sym23 = CSETQ, $sym24 = WITH-TIMEOUT-START-TIMER, $sym25 = WITH-TIMEOUT-STOP-TIMER
;; Verified against expansion site in inference_trivial.java:190-287
;; Note: helper functions (with-timeout-make-tag, with-timeout-start-timer,
;; with-timeout-stop-timer) are missing-larkc; this macro is structurally correct
;; but the timeout mechanism will not function without them.
;; TODO - maybe use SBCL calls for this than manually implement it?
(defmacro with-timeout ((time timed-out-var) &body body)
  (with-temp-vars (tag timer)
    `(let ((,tag (with-timeout-make-tag)))
       (setf ,timed-out-var
             (catch ,tag
               (let ((*within-with-timeout* t))
                 (let ((,timer nil))
                   (unwind-protect
                       (let ((*with-timeout-nesting-depth* (+ 1 *with-timeout-nesting-depth*)))
                         (setf ,timer (with-timeout-start-timer ,time ,tag))
                         ,@body
                         nil)
                     (with-timeout-stop-timer ,timer)))))))))

;; (defun with-timeout-internal (time tag body-fn) ...) -- commented declareFunction, no body
;; (defun with-timeout-make-tag () ...) -- commented declareFunction, no body
;; (defun with-timeout-start-timer (time tag) ...) -- commented declareFunction, no body
;; (defun timeout-tag-nesting-depth (tag) ...) -- commented declareFunction, no body
;; (defun with-timeout-stop-timer (timer) ...) -- commented declareFunction, no body
;; (defun with-timeout-timer-thread (time tag client-name timer-name timer-desc) ...) -- commented declareFunction, no body
;; (defun with-timeout-signal-timeout (tag client-thread) ...) -- commented declareFunction, no body
;; (defun with-timeout-throw (tag) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list34 = ((BI-STREAM HOST PORT &KEY TIMEOUT (ACCESS-MODE :PUBLIC)) &BODY BODY) — arglist
;; $sym40 = OPEN-TCP-STREAM-WITH-TIMEOUT, $sym41 = PWHEN, $sym42 = CLOSE
;; $kw36 = ALLOW-OTHER-KEYS, $kw37 = TIMEOUT, $kw38 = ACCESS-MODE, $kw39 = PUBLIC
;; Note: open-tcp-stream-with-timeout is a commented declareFunction in subl-promotions.
;; TODO - reimplement this with CL libs
(defmacro with-tcp-connection ((bi-stream host port &key timeout (access-mode :public))
                               &body body)
  `(let ((,bi-stream (open-tcp-stream-with-timeout ,host ,port ,timeout ,access-mode)))
     (unwind-protect
         (progn ,@body)
       (when ,bi-stream
         (close ,bi-stream)))))

;; TODO - WITH-TCP-CONNECTION-WITH-TIMEOUT macro
;; Insufficient evidence for exact form. Constants:
;; $sym43 = WITH-TCP-CONNECTION-WITH-TIMEOUT
;; $list44 = (WITH-TCP-CONNECTION) — likely indentation pattern or macro reference
;; $sym45 = WITH-TCP-CONNECTION
;; Probably wraps WITH-TCP-CONNECTION inside WITH-TIMEOUT, but arglist unknown.

;; Reconstructed from Internal Constants:
;; $list46 = (VARIABLES EXPRESSION) — arglist
;; $sym47 = LISTP — assertion check on VARIABLES
;; $sym48 = CMULTIPLE-VALUE-BIND — expansion operator
;; $list50 (indentation) = (VARIABLES EXPRESSION &BODY BODY)
;; SubL's cmultiple-value-setq maps directly to CL's multiple-value-setq.
;; DO NOT USE THIS, USE MULTIPLE-VALUE-SETQ DIRECTLY INSTEAD!
;;(defmacro cmultiple-value-setq (variables expression)
;;  `(multiple-value-setq ,variables ,expression))

;; TODO - WITH-SPACE-PROFILING macro
;; Arglist from $list52 = ((&KEY (STREAM (QUOTE *STANDARD-OUTPUT*))) &BODY BODY)
;; Uses SUBLISP package profiling functions:
;; $list58 = ((ADD-SPACE-PROBE)), $sym59 = REMOVE-SPACE-PROBE, $sym60 = %INTERPRET-CSPACE-RESULTS
;; $sym57 = SPACE-INFO (uninternedSymbol) — gensym for temp var
;; Helper: with-space-profiling-sl2c (commented declareFunction)
;; Cannot reconstruct without SUBLISP profiling infrastructure.

;; (defun with-space-profiling-sl2c (space-info stream) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list61 = (COMMENT-STRING) — arglist
;; $sym62 = STRINGP — assertion check
;; $list63 = (PROGN) — the expansion: empty progn
;; CODE-COMMENT is a compile-time annotation that produces no runtime code.
(defmacro code-comment (comment-string)
  (declare (ignore comment-string))
  '(progn))


;;;; Variables

(defglobal *catch-error-message-target* (make-symbol "ERROR")
  "[Cyc] The target thrown to by errors inside CATCH-ERROR-MESSAGE")

(defparameter *within-with-timeout* nil)

(defparameter *with-timeout-nesting-depth* 0)


;;;; Setup

(toplevel
  (declare-defglobal '*catch-error-message-target*)
  (register-macro-helper 'with-timeout-make-tag 'with-timeout)
  (register-macro-helper 'with-timeout-start-timer 'with-timeout)
  (register-macro-helper 'with-timeout-stop-timer 'with-timeout)
  (declare-indention-pattern 'cmultiple-value-setq '(variables expression &body body))
  (register-external-symbol 'with-space-profiling)
  (register-macro-helper 'with-space-profiling-sl2c 'with-space-profiling))
