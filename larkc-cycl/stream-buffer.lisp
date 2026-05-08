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

;; (defun stream-buffer-read-sequence (stream-buffer string &optional start end) ...) -- commented declareFunction, no body
;; (defun string-buffer-replace (string-buffer string &optional tgt-start tgt-end src-start src-end) ...) -- commented declareFunction, no body
;; (defun read-text-into-vector (stream count &optional start end) ...) -- commented declareFunction, no body
;; (defun replace-string-from-vector (string vector &optional tgt-start tgt-end src-start src-end) ...) -- commented declareFunction, no body

;; string-buffer defstruct
;; Slots: string, position
;; conc-name: strbuf-
;; print-function: print-string-buffer
(defstruct (string-buffer
            (:conc-name "STRBUF-"))
  string
  position)

(defconstant *dtp-string-buffer* 'string-buffer)


;; (defun string-buffer-p (object) ...) -- commented declareFunction, no body. UnaryFunction: missing-larkc 10485
;; (defun strbuf-string (string-buffer) ...) -- commented declareFunction, no body (struct accessor)
;; (defun strbuf-position (string-buffer) ...) -- commented declareFunction, no body (struct accessor)
;; _csetf-strbuf-string and _csetf-strbuf-position are struct setf expansions, elided.
;; (defun make-string-buffer (&optional initializer) ...) -- commented declareFunction, no body (struct constructor)
;; (defun print-string-buffer (object stream depth) ...) -- commented declareFunction, no body
;; (defun new-string-buffer (&optional capacity) ...) -- commented declareFunction, no body
;; (defun destroy-string-buffer (string-buffer) ...) -- commented declareFunction, no body
;; (defun string-buffer-string (string-buffer) ...) -- commented declareFunction, no body
;; (defun string-buffer-position (string-buffer) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list20 = ((BUFFER-STRING-VAR BUFFER-END-VAR) STRING-BUFFER &BODY BODY)
;; $sym21$CLET, $sym22$STRING_BUFFER_STRING, $sym23$STRING_BUFFER_POSITION
;; Binds destructured variables to string-buffer accessors.
(defmacro with-string-buffer (((buffer-string-var buffer-end-var) string-buffer) &body body)
  `(let ((,buffer-string-var (string-buffer-string ,string-buffer))
         (,buffer-end-var (string-buffer-position ,string-buffer)))
     ,@body))

;; (defun string-buffer-capacity (string-buffer) ...) -- commented declareFunction, no body
;; (defun string-buffer-write (string-buffer &optional stream) ...) -- commented declareFunction, no body
;; (defun string-buffer-read (string-buffer &optional stream eof-error-p eof-value) ...) -- commented declareFunction, no body
;; (defun string-buffer-reset (string-buffer) ...) -- commented declareFunction, no body
;; (defun string-buffer-add (string-buffer char) ...) -- commented declareFunction, no body
;; (defun string-buffer-add-sequence (string-buffer string &optional start end) ...) -- commented declareFunction, no body

;; stream-buffer defstruct
;; Slots: stream, buffer, end, position
;; conc-name: strm-buf-
;; print-function: print-stream-buffer
(defstruct (stream-buffer
            (:conc-name "STRM-BUF-"))
  stream
  buffer
  end
  position)

(defconstant *dtp-stream-buffer* 'stream-buffer)


;; (defun stream-buffer-p (object) ...) -- commented declareFunction, no body. UnaryFunction: missing-larkc 10483
;; (defun strm-buf-stream (stream-buffer) ...) -- commented declareFunction, no body (struct accessor)
;; (defun strm-buf-buffer (stream-buffer) ...) -- commented declareFunction, no body (struct accessor)
;; (defun strm-buf-end (stream-buffer) ...) -- commented declareFunction, no body (struct accessor)
;; (defun strm-buf-position (stream-buffer) ...) -- commented declareFunction, no body (struct accessor)
;; _csetf-strm-buf-stream, _csetf-strm-buf-buffer, _csetf-strm-buf-end, _csetf-strm-buf-position are struct setf expansions, elided.
;; (defun make-stream-buffer (&optional initializer) ...) -- commented declareFunction, no body (struct constructor)
;; (defun print-stream-buffer (object stream depth) ...) -- commented declareFunction, no body
;; (defun new-stream-buffer (stream &optional block-size) ...) -- commented declareFunction, no body
;; (defun destroy-stream-buffer (stream-buffer) ...) -- commented declareFunction, no body
;; (defun stream-buffer-stream (stream-buffer) ...) -- commented declareFunction, no body
;; (defun stream-buffer-block-size (stream-buffer) ...) -- commented declareFunction, no body
;; (defun stream-buffer-reset (stream-buffer) ...) -- commented declareFunction, no body
;; (defun stream-buffer-load (stream-buffer) ...) -- commented declareFunction, no body
;; (defun read-line-into-string-buffer (stream &optional string-buffer eof-error-p eof-value) ...) -- commented declareFunction, no body
;; (defun stream-buffer-read-line-into-string-buffer (stream-buffer &optional string-buffer eof-error-p eof-value) ...) -- commented declareFunction, no body
;; (defun read-line-into-string-buffer-int (string-buffer stream) ...) -- commented declareFunction, no body
;; (defun stream-buffer-read-line-into-string-buffer-int (stream-buffer string-buffer) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list48 = ((LINE-BUFFER-VAR FILENAME &KEY BLOCK-SIZE DONE) &BODY BODY)
;; $sym53$STREAM_VAR (gensym), $sym54$WITH_PRIVATE_TEXT_FILE, $list55=(:INPUT),
;; $sym56$PWHEN, $sym57$DO_STREAM_LINES_BUFFERED
;; Opens filename for reading via with-private-text-file, then delegates
;; to do-stream-lines-buffered.
(defmacro do-file-lines-buffered ((line-buffer-var filename &key block-size done) &body body)
  (with-temp-vars (stream-var)
    `(with-private-text-file (,stream-var ,filename :input)
       (when ,stream-var
         (do-stream-lines-buffered (,line-buffer-var ,stream-var
                                    ,@(when block-size `(:block-size ,block-size))
                                    ,@(when done `(:done ,done)))
           ,@body)))))

;; Reconstructed from Internal Constants:
;; $list58 = ((LINE-BUFFER-VAR STREAM &KEY BLOCK-SIZE DONE) &BODY BODY)
;; $sym59$DONE_VAR (gensym), $sym60$STREAM_BUFFER_VAR (gensym),
;; $sym61$CMULTIPLE_VALUE_BIND, $sym62$DO_STREAM_LINES_BUFFERED_INITIALIZE,
;; $sym63$CUNWIND_PROTECT, $sym64$WHILE, $sym65$CNOT, $sym66$PIF,
;; $sym67$DO_STREAM_LINES_BUFFERED_NEXT, $sym68$PROGN, $sym69$CSETQ,
;; $list70=(T), $sym71$DO_STREAM_LINES_BUFFERED_FINALIZE
;; Initializes a stream-buffer and string-buffer (line-buffer) pair, iterates
;; lines via do-stream-lines-buffered-next, and finalizes in an unwind-protect.
(defmacro do-stream-lines-buffered ((line-buffer-var stream &key block-size done) &body body)
  (with-temp-vars (done-var stream-buffer-var)
    `(multiple-value-bind (,stream-buffer-var ,line-buffer-var)
         (do-stream-lines-buffered-initialize ,stream ,block-size)
       (unwind-protect
            (while (not ,done-var)
              (if (do-stream-lines-buffered-next ,stream-buffer-var ,line-buffer-var)
                  (progn ,@body)
                  (setf ,done-var t))
              ,@(when done `((when ,done (setf ,done-var t)))))
         (do-stream-lines-buffered-finalize ,stream-buffer-var ,line-buffer-var)))))

;; (defun do-stream-lines-buffered-initialize (stream &optional block-size) ...) -- commented declareFunction, no body
;; (defun do-stream-lines-buffered-next (stream-buffer line-buffer) ...) -- commented declareFunction, no body
;; (defun do-stream-lines-buffered-finalize (stream-buffer line-buffer) ...) -- commented declareFunction, no body
;; (defun new-stream-line-iterator (stream &optional block-size) ...) -- commented declareFunction, no body
;; (defun make-stream-line-iterator-state (stream-buffer line-buffer) ...) -- commented declareFunction, no body
;; (defun stream-line-iterator-done? (state) ...) -- commented declareFunction, no body
;; (defun stream-line-iterator-next (state) ...) -- commented declareFunction, no body
;; (defun stream-line-iterator-finalize (state) ...) -- commented declareFunction, no body

(toplevel
  (register-macro-helper 'do-stream-lines-buffered-initialize 'do-stream-lines-buffered)
  (register-macro-helper 'do-stream-lines-buffered-next 'do-stream-lines-buffered)
  (register-macro-helper 'do-stream-lines-buffered-finalize 'do-stream-lines-buffered)
  (note-funcall-helper-function 'stream-line-iterator-done?)
  (note-funcall-helper-function 'stream-line-iterator-next)
  (note-funcall-helper-function 'stream-line-iterator-finalize))
