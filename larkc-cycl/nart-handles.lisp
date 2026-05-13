#|
  Copyright (c) 2019 White Flame

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
(file "nart-handles")

(defglobal *nart-from-id* nil
    "[Cyc] The ID -> NART mapping table.")

(defun* do-narts-table () (:inline t)
  *nart-from-id*)

(defun setup-nart-table (size exact?)
  (declare (ignore exact?))
  (unless *nart-from-id*
    (setf *nart-from-id* (new-id-index size 0))
    t))

(defun finalize-narts (&optional max-nart-id)
  (set-next-nart-id max-nart-id)
  (unless max-nart-id
    (missing-larkc 30878)))

(defun* clear-nart-table () (:inline t)
  (clear-id-index *nart-from-id*))

(defun nart-count ()
  "[Cyc] Return the total number of NARTs."
  (if *nart-from-id*
      (id-index-count *nart-from-id*)
      0))

(defun* lookup-nart (id) (:inline t)
  (id-index-lookup *nart-from-id* id))

(defun* new-nart-id-threshold () (:inline t)
  "[Cyc] Return the internal ID where new NARTs started."
  (id-index-new-id-threshold *nart-from-id*))

(defun set-next-nart-id (&optional max-nart-id)
  (let ((max -1))
    (if max-nart-id
        (setf max max-nart-id)
        (do-id-index (id nart (do-narts-table)
                         :progress-message "Determining maximum NART ID")
          (ignore id)
          (setf max (max max (n-id nart)))))
    (let ((next-id (1+ max)))
      (set-id-index-next-id *nart-from-id* next-id)
      next-id)))

(defun register-nart-id (nart id)
  "[Cyc] Note that ID will be used as the id for NART."
  (reset-nart-id nart id)
  (id-index-enter *nart-from-id* id nart)
  nart)

(defstruct (nart (:conc-name "N-"))
  id)

(deftype nart-p ()
  'nart)

(defmethod sxhash ((object nart))
  (let ((id (n-id object)))
    (if (integerp id) id 0)))

(defun* get-nart () (:inline t)
  "[Cyc] Make a new nart shell, potentially in static space."
  (make-nart))

(defun valid-nart-handle? (object)
  "[Cyc] Return T iff OBJECT is a valid NART handle."
  (and (nart-p object)
       (missing-larkc 30862)))

(defun make-nart-shell (&optional id)
  (unless id
    (missing-larkc 30861))
  (let ((nart (get-nart)))
    (register-nart-id nart id)
    nart))

(defun create-sample-invalid-nart ()
  "[Cyc] Create a sample invalid NART."
  (get-nart))

(defun free-all-narts ()
  (clear-nart-table))

(defun* reset-nart-id (nart new-id) (:inline t)
  "[Cyc] Primitively change the internal id for NART to NEW-ID."
  (setf (n-id nart) new-id)
  nart)

(defun* find-nart-by-id (id) (:inline t)
  (lookup-nart id))


;;; Cyc API registrations

(register-cyc-api-macro 'do-narts '((var &optional (progress-message makeString("mapping Cyc NARTs")) &key done) &body body)
    "Iterate over all HL NART datastructures, executing BODY within the scope of VAR.
   VAR is bound to the NART.
   PROGRESS-MESSAGE is a progress message string.
   Iteration halts early as soon as DONE becomes non-nil.")


(register-cyc-api-function 'nart-count 'nil
    "Return the total number of NARTs."
    'nil
    '(integerp))


(register-cyc-api-function 'nart-p '(object)
    "Return T iff OBJECT is a datastructure implementing a non-atomic reified term (NART)."
    'nil
    '(booleanp))


(register-cyc-api-function 'nart-id '(nart)
    "Return the id of this NART."
    '((nart nart-p))
    '(integerp))


(register-cyc-api-function 'find-nart-by-id '(id)
    "Return the NART with ID, or NIL if not present."
    '((id integerp))
    '((nil-or nart-p)))
