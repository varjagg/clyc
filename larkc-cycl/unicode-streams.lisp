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

;; Definitions

(defconstant unicode-linefeed 10)
(defconstant unicode-carriage-return 13)

;; UTF8-STREAM defstruct
;; print-object is missing-larkc 7064 — CL's default print-object handles this.
(defstruct utf8-stream
  stream
  cache)

(defconstant *dtp-utf8-stream* 'utf8-stream)

;; (defun utf8-stream-p (object) ...) -- active declareFunction, no body
;; (defun utf8-stream-stream (utf8-stream) ...) -- no body
;; (defun utf8-stream-cache (utf8-stream) ...) -- no body
;; (defun _csetf-utf8-stream-stream (utf8-stream value) ...) -- no body
;; (defun _csetf-utf8-stream-cache (utf8-stream value) ...) -- no body
;; (defun make-utf8-stream (&optional arglist) ...) -- no body
;; (defun utf8-stream-create (stream) ...) -- no body
;; (defun print-utf8-stream (object stream depth) ...) -- no body
;; (defun open-utf8 (filename direction) ...) -- no body
;; (defun close-utf8 (utf8-stream) ...) -- no body
;; (defun write-unicode-char-to-utf8 (unicode-char &optional utf8-stream) ...) -- no body
;; (defun write-unicode-string-to-utf8 (unicode-string &optional start end utf8-stream) ...) -- no body
;; (defun write-unicode-string-to-utf8-line (unicode-string &optional start end utf8-stream) ...) -- no body
;; (defun read-utf8-char (&optional utf8-stream eof-error-p eof-value recursive-p) ...) -- no body
;; (defun read-utf8-char-helper (&optional utf8-stream eof-error-p eof-value recursive-p) ...) -- no body
;; (defun read-utf8-line (&optional utf8-stream eof-error-p eof-value recursive-p) ...) -- no body
