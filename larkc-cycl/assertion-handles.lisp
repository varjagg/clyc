#|
  Copyright (c) 2019-2020 White Flame

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


(defglobal *assertion-from-id* nil
  ;; This is an id-index
  "[Cyc] The ID -> ASSERTION mapping table.")

;; Reconstructed from Internal Constants: $list1$ arglist, $sym6$ DO-KB-SUID-TABLE,
;; $list7$ (DO-ASSERTIONS-TABLE).
(defmacro do-assertions ((var &optional (progress-message "mapping Cyc assertions")
                              &key done)
                         &body body)
  `(do-kb-suid-table (,var (do-assertions-table)
                      :progress-message ,progress-message :done ,done)
     ,@body))

;; Reconstructed from Internal Constants: $list11$ arglist, $sym13$ DO-KB-SUID-TABLE-OLD-OBJECTS.
(defmacro do-old-assertions ((assertion &key progress-message done) &body body)
  `(do-kb-suid-table-old-objects (,assertion (do-assertions-table)
                                  :progress-message ,progress-message :done ,done)
     ,@body))

;; Reconstructed from Internal Constants: $list11$ arglist, $sym14$ DO-KB-SUID-TABLE-NEW-OBJECTS.
(defmacro do-new-assertions ((assertion &key progress-message done) &body body)
  `(do-kb-suid-table-new-objects (,assertion (do-assertions-table)
                                  :progress-message ,progress-message :done ,done)
     ,@body))

;; (defun new-assertions-iterator () ...) -- active declaration, no body

(defun* do-assertions-table () (:inline t)
  *assertion-from-id*)

(defun setup-assertion-table (size exact?)
  (declare (ignore exact?))
  (unless *assertion-from-id*
    (setf *assertion-from-id* (new-id-index size 0))
    t))

;; (defun optimize-assertion-table () ...) -- active declaration, no body

(defun finalize-assertions (&optional max-assertion-id)
  (set-next-assertion-id max-assertion-id)
  (unless max-assertion-id
    (missing-larkc 30896)))

(defun clear-assertion-table ()
  (clear-id-index *assertion-from-id*))

;; (defun create-assertion-dump-id-table () ...) -- active declaration, no body
;; (defun new-dense-assertion-id-index () ...) -- active declaration, no body

(defun assertion-count ()
  "[Cyc] Return the total number of assertions."
  (if *assertion-from-id*
      (id-index-count *assertion-from-id*)
      0))

(defun* lookup-assertion (id) (:inline t)
  (id-index-lookup *assertion-from-id* id))

;; (defun next-assertion-id () ...) -- active declaration, no body
;; (defun new-assertion-id-threshold () ...) -- active declaration, no body
;; (defun old-assertion-count () ...) -- active declaration, no body
;; (defun new-assertion-count () ...) -- active declaration, no body
;; (defun missing-old-assertion-ids () ...) -- active declaration, no body

(defun set-next-assertion-id (&optional max-assertion-id)
  (let ((max -1))
    (if max-assertion-id
        (setf max max-assertion-id)
        (do-id-index (id assertion (do-assertions-table)
                         :progress-message "Determining maximum assertion ID")
          (setf max (max max (assertion-id assertion)))))
    (let ((next-id (+ max 1)))
      (set-id-index-next-id *assertion-from-id* next-id)
      next-id)))

(defun register-assertion-id (assertion id)
  "[Cyc] Note that ID will be used as the id for ASSERTION."
  (reset-assertion-id assertion id)
  (id-index-enter *assertion-from-id* id assertion)
  assertion)

(defun deregister-assertion-id (id)
  "[Cyc] Note that ID is not in use as an assertion id."
  (id-index-remove *assertion-from-id* id))

(defun make-assertion-id ()
  "[Cyc] Return a new integer id for an assertion."
  (id-index-reserve *assertion-from-id*))

(defstruct (assertion (:conc-name as-))
  id)

(deftype assertion-p ()
  'assertion)

(defconstant *dtp-assertion* 'assertion)

(defparameter *print-assertions-in-cnf* nil)

;; (defun print-assertion (object stream depth) ...) -- active declaration, no body

;; [Clyc] Java registers SXHASH-ASSERTION-METHOD on $sxhash-method-table$ via
;; Structures.register_method. Expressed here as a CLOS defmethod on CL's own sxhash,
;; so callers of (sxhash assertion) dispatch correctly without the SubL method table.
;; TODO - sbcl custom :test function can compare IDs directly, need custom hash function then as well
(defmethod sxhash ((object assertion))
  (let ((id (as-id object)))
    (if (integerp id)
        id
        23)))

(defun* get-assertion () (:inline t)
  "[Cyc] Make a new assertion shell, potentially in static space."
  (make-assertion))

(defun* free-assertion (assertion) (:inline t)
  "[Cyc] Invalidate ASSERTION."
  (setf (as-id assertion) nil)
  assertion)

(defun valid-assertion-handle? (object)
  "[Cyc] Return T iff OBJECT is a valid assertion handle."
  (and (assertion-p object)
       (assertion-handle-valid? object)))

(defun* valid-assertion? (assertion &optional robust?) (:inline t)
  "[Cyc] Return T if ASSERTION is a valid assertion."
  (declare (ignore robust?))
  (valid-assertion-handle? assertion))

;; (defun assertion-id-p (object) ...) -- active declaration, no body

(defun make-assertion-shell (&optional id)
  (unless id
    (setf id (make-assertion-id)))
  (check-type id fixnum)
  (let ((assertion (get-assertion)))
    (register-assertion-id assertion id)
    assertion))

(defun* create-sample-invalid-assertion () (:inline t)
  "[Cyc] Create a sample invalid-assertion."
  (get-assertion))

;; (defun partition-create-invalid-assertion () ...) -- active declaration, no body

(defun free-all-assertions ()
  (do-id-index (id assertion (do-assertions-table)
                   :progress-message "Freeing assertions")
    (free-assertion assertion))
  (clear-assertion-table)
  (clear-assertion-content-table)) 

(defun* assertion-id (assertion) (:inline t)
  "[Cyc] Return the id of this ASSERTION."
  (declare (type assertion-p assertion))
  (as-id assertion))

(defun* reset-assertion-id (assertion new-id) (:inline t)
  "[Cyc] Primitively change the assertion id for ASSERTION to NEW-ID."
  (setf (as-id assertion) new-id)
  assertion)

(defun* assertion-handle-valid? (assertion) (:inline t)
  (integerp (as-id assertion)))

(defun* find-assertion-by-id (id) (:inline t)
  "[Cyc] Return the assertion with ID, or NIL if not present."
  (declare (type integer id))
  (lookup-assertion id))


;;; Setup

(toplevel
  (declare-defglobal '*assertion-from-id*)
  (register-macro-helper 'do-assertions-table 'do-assertions)
  (register-macro-helper 'create-assertion-dump-id-table 'with-assertion-dump-id-table))


;;; Cyc API registrations


(register-cyc-api-macro 'do-assertions '((var &optional (progress-message "mapping Cyc assertions") &key done) &body body)
    "Iterate over all HL assertion datastructures, executing BODY within the scope of VAR.
   VAR is bound to the assertion.
   PROGRESS-MESSAGE is a progress message string.
   Iteration halts early as soon as DONE becomes non-nil.")


(register-cyc-api-function 'assertion-count 'nil
    "Return the total number of assertions."
    'nil
    '(integerp))


(register-cyc-api-function 'assertion-p '(object)
    "Return T iff OBJECT is an HL assertion"
    'nil
    '(booleanp))


(register-cyc-api-function 'assertion-id '(assertion)
    "Return the id of this ASSERTION."
    '((assertion assertion-p))
    '(integerp))


(register-cyc-api-function 'find-assertion-by-id '(id)
    "Return the assertion with ID, or NIL if not present."
    '((id integerp))
    '((nil-or assertion-p)))
