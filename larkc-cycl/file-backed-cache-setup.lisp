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

(defglobal *registered-file-backed-caches* nil
  "[Cyc] List of registered file backed caches as file-backed-cache-registration-p's.")

(defparameter *file-backed-cache-default-temp-dir* "tmp/"
  "[Cyc] The directoy for tempory files.")

(deflexical *fbc-registration-lock* (bt:make-lock "fbc-registration-lock")
  "[Cyc] Lock used to ensure registrations are done atomically.")

(defstruct (file-backed-cache-registration (:conc-name "FBCR-"))
  generation-function
  initialization-function
  reset-function
  default-fht-name-function
  test-suite-name
  module-name
  system-name)

(defconstant *dtp-file-backed-cache-registration* 'file-backed-cache-registration)

;; file-backed-cache-registration-p - commented, no body (1 0)
;; fbcr-generation-function - commented, no body (1 0)
;; fbcr-initialization-function - commented, no body (1 0)
;; fbcr-reset-function - commented, no body (1 0)
;; fbcr-default-fht-name-function - commented, no body (1 0)
;; fbcr-test-suite-name - commented, no body (1 0)
;; fbcr-module-name - commented, no body (1 0)
;; fbcr-system-name - commented, no body (1 0)
;; _csetf-fbcr-generation-function - commented, no body (2 0)
;; _csetf-fbcr-initialization-function - commented, no body (2 0)
;; _csetf-fbcr-reset-function - commented, no body (2 0)
;; _csetf-fbcr-default-fht-name-function - commented, no body (2 0)
;; _csetf-fbcr-test-suite-name - commented, no body (2 0)
;; _csetf-fbcr-module-name - commented, no body (2 0)
;; _csetf-fbcr-system-name - commented, no body (2 0)
;; make-file-backed-cache-registration - commented, no body (0 1)
;; register-file-backed-cache - commented, no body (7 0)
;; lookup-file-backed-cache-by-name - commented, no body (1 0)
;; generate-test-install-all-file-backed-caches - commented, no body (0 2)
;; generate-all-file-backed-caches - commented, no body (0 2)
;; test-all-file-backed-caches - commented, no body (0 2)
;; install-all-file-backed-caches - commented, no body (0 2)
;; generate-test-install-file-backed-cache - commented, no body (4 2)
;; ensure-file-backed-cache-directory - commented, no body (0 0)

(defun initialize-all-file-backed-caches ()
  "[Cyc] Initialize all registered file backed caches."
  (when (not (kb-loaded))
    (return-from initialize-all-file-backed-caches nil))
  (when *registered-file-backed-caches*
    (format t "~&Initializing file-backed caches.~%")
    (force-output *standard-output*))
  (dolist (v-cache *registered-file-backed-caches*)
    (let ((message-var nil))
      (handler-case
          (funcall (missing-larkc 10736))
        (error (e)
          (setf message-var (princ-to-string e))))
      (when (stringp message-var)
        (warn "~A" message-var))))
  nil)

;; reset-all-file-backed-caches - commented, no body (0 0)

(declare-defglobal '*registered-file-backed-caches*)
(register-external-symbol 'generate-test-install-all-file-backed-caches)
