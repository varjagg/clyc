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

;; (defun transcript-eval (form &optional options) ...) -- commented declareFunction, no body
;; (defun transcript-form (form &optional options) ...) -- commented declareFunction, no body
;; (defun transcript-form-int (form options level) ...) -- commented declareFunction, no body
;; (defun form-to-transcript-form (form) ...) -- commented declareFunction, no body

(defun initialize-transcript-handling ()
  "[Cyc] Initialize or reinitialize the handling of transcripts."
  (set-master-transcript-already-exists nil)
  (new-local-transcript)
  (set-master-transcript)
  (set-read-transcript (master-transcript))
  (when (use-transcript-server)
    (setf *auto-increment-kb* t))
  t)

(defparameter *transcript-suffix* "ts")

(defun transcript-suffix ()
  *transcript-suffix*)

;; (defun master-transcript-already-exists () ...) -- commented declareFunction, no body

(defparameter *master-transcript-already-exists* nil
  "[Cyc] Boolean: has the master transcript been accessed -- probed, touched, written to, or read from -- yet?")

(defun set-master-transcript-already-exists (number)
  (setf *master-transcript-already-exists* number))

(defglobal *local-transcript-version* 0)

(defun local-transcript-version ()
  *local-transcript-version*)

;; (defun inc-local-transcript-version () ...) -- commented declareFunction, no body
;; (defun local-transcript-history () ...) -- commented declareFunction, no body
;; (defun local-transcript-history-add (entry) ...) -- commented declareFunction, no body

(defglobal *local-transcript-history* nil)

;; (defun local-hl-transcript-version () ...) -- commented declareFunction, no body
;; (defun inc-local-hl-transcript-version () ...) -- commented declareFunction, no body
;; (defun local-hl-transcript-history () ...) -- commented declareFunction, no body
;; (defun local-hl-transcript-history-add (entry) ...) -- commented declareFunction, no body

(defglobal *local-hl-transcript-version* 0)
(defglobal *local-hl-transcript-history* nil)

;; (defun read-transcript-position () ...) -- commented declareFunction, no body
;; (defun set-read-transcript-position (position) ...) -- commented declareFunction, no body

(defglobal *read-transcript-position* 0)

;; (defun approx-chars-per-op () ...) -- commented declareFunction, no body
;; (defun set-approx-chars-per-op (value) ...) -- commented declareFunction, no body

(defparameter *approx-chars-per-op* 206)

(defglobal *local-transcript* nil
  "[Cyc] A transcript containing operations from an individual Cyc image")

(defun local-transcript ()
  "[Cyc] Accessor for *local-transcript*."
  *local-transcript*)

;; (defun mark-local-transcript (mark) ...) -- commented declareFunction, no body
;; (defun roll-local-transcript () ...) -- commented declareFunction, no body

(defun new-local-transcript ()
  "[Cyc] Clear local-operation-storage-queue and set *local-transcript* to a new file."
  (clear-local-operation-storage-queue)
  (new-local-transcript-int))

(defun new-local-transcript-int ()
  "[Cyc] Set *local-transcript* to a new file."
  (when (and *local-transcript*
             (probe-file *local-transcript*))
    ;; 6062 likely archives/renames the existing transcript file (maybe
    ;; mark-local-transcript with "ROLLED"), since this is called just before
    ;; replacing *local-transcript* with a new filename.
    (missing-larkc 6062)
    ;; 6055 likely records the old transcript in the history list
    ;; (*local-transcript-history*), since local-transcript-history-add exists
    ;; as a commented stub and this is the natural point to call it.
    (missing-larkc 6055))
  (setf *local-transcript*
        (construct-transcript-filename
         (make-local-transcript-filename (local-transcript-version))))
  *local-transcript*)

(defglobal *read-transcript* nil
  "[Cyc] transcript file from which ops are currently being read.")

;; (defun read-transcript () ...) -- commented declareFunction, no body

(defun set-read-transcript (filename)
  (setf *read-transcript* filename)
  *read-transcript*)

(defglobal *master-transcript* nil
  "[Cyc] The master transcript file, containing operations from all communicating Cyc images.")

(defun master-transcript ()
  "[Cyc] Accessor for *master-transcript*."
  *master-transcript*)

(defun set-master-transcript (&optional (name (make-master-transcript-filename)))
  (unless (use-transcript-server)
    (setf *master-transcript* (construct-transcript-filename name)))
  *master-transcript*)

;; (defun get-all-transcripts-image () ...) -- commented declareFunction, no body

(defglobal *local-hl-transcript* nil
  "[Cyc] A hl-transcript containing operations from an individual Cyc image")

;; (defun local-hl-transcript () ...) -- commented declareFunction, no body
;; (defun mark-local-hl-transcript (mark) ...) -- commented declareFunction, no body
;; (defun roll-local-hl-transcript () ...) -- commented declareFunction, no body
;; (defun new-local-hl-transcript () ...) -- commented declareFunction, no body
;; (defun new-local-hl-transcript-int () ...) -- commented declareFunction, no body

(defun make-master-transcript-filename (&optional (version (kb-loaded)))
  (format nil "cyc-kb-~a" version))

(defun make-local-transcript-filename (version-number)
  "[Cyc] Produces the base of a transcript filename based on the cyc-image-id and a version number"
  (unless (cyc-image-id)
    (set-cyc-image-id))
  (format nil "~a-local-~a" (cyc-image-id) version-number))

;; (defun make-local-hl-transcript-filename (version-number) ...) -- commented declareFunction, no body

(defun construct-transcript-filename (name)
  "[Cyc] Adds on the directory and suffix to a transcript filename"
  (concatenate 'string (transcript-directory) name "." (transcript-suffix)))

(defun transcript-directory ()
  "[Cyc] Returns a relative pathname to the current transcript directory, creating it if necessary."
  (transcript-directory-int (kb-loaded)))

;; (defun next-transcript-directory () ...) -- commented declareFunction, no body

(defun transcript-directory-int (kb-number)
  (let ((directory (cyc-home-subdirectory
                    (list "transcripts" (format nil "~4,'0D" kb-number)))))
    (unless (directory-p directory)
      (make-directory-recursive directory t))
    directory))

;; (defun mark-transcript-filename (transcript mark) ...) -- commented declareFunction, no body
;; (defun get-count-ops-data (transcript) ...) -- commented declareFunction, no body
;; (defun get-current-op-count (transcript) ...) -- commented declareFunction, no body
;; (defun get-current-position (transcript) ...) -- commented declareFunction, no body
;; (defun update-count-ops-data (transcript op-count position) ...) -- commented declareFunction, no body
;; (defun really-count-ops (transcript) ...) -- commented declareFunction, no body
;; (defun count-operations (transcript) ...) -- commented declareFunction, no body
;; (defun estimate-number-of-ops (transcript) ...) -- commented declareFunction, no body
;; (defun collect-ops-in-range (transcript start &optional end count) ...) -- commented declareFunction, no body
;; (defun bp-count-ops (transcript) ...) -- commented declareFunction, no body
;; (defun constant-modifications-in-transcript (transcript) ...) -- commented declareFunction, no body
;; (defun report-constant-modifications-in-transcript (&optional transcript stream) ...) -- commented declareFunction, no body
;; (defun report-constant-modifications-in-transcript-to-file (filename &optional transcript) ...) -- commented declareFunction, no body
;; (defun encapsulated-cyclist-string (op) ...) -- commented declareFunction, no body
;; (defun reset-transcript-rename-hash () ...) -- commented declareFunction, no body
;; (defun sort-transcript-renames () ...) -- commented declareFunction, no body
;; (defun add-transcript-rename-info (op-num external-id old-name new-name who when) ...) -- commented declareFunction, no body
;; (defun rem-transcript-rename-info (external-id) ...) -- commented declareFunction, no body
;; (defun reset-transcript-create-hash () ...) -- commented declareFunction, no body
;; (defun sort-transcript-creates () ...) -- commented declareFunction, no body
;; (defun add-transcript-create-info (op-num external-id name who when) ...) -- commented declareFunction, no body
;; (defun constant-created-in-transcript (external-id) ...) -- commented declareFunction, no body
;; (defun rem-transcript-create-info (external-id) ...) -- commented declareFunction, no body
;; (defun write-specific-transcript-file-as-ke-text (transcript-filename output-filename) ...) -- commented declareFunction, no body, Cyc API
;; (defun transcript-file-to-ke-text (transcript) ...) -- commented declareFunction, no body
;; (defun unencapsulate-to-string (object &optional stream) ...) -- commented declareFunction, no body
;; (defun unencapsulate-string (string) ...) -- commented declareFunction, no body

(defglobal *count-ops-table* nil)
(defglobal *transcript-rename-hash* nil)
(defglobal *transcript-create-hash* nil)

(toplevel
  (register-cyc-api-function 'write-specific-transcript-file-as-ke-text
                             '(transcript-filename output-filename)
                             "Generate a KE Text file from a transcript and write it to a file."
                             '((transcript-filename stringp)
                               (output-filename stringp))
                             nil))
