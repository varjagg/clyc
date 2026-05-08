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


;; CFASL serialization methods for KB objects: constants, NARTs, assertions,
;; deductions, KB-HL-supports, clause-strucs, variables, and SBHL links.
;; Each object type follows a pattern: output/input with both recipe (externalized)
;; and handle (internal ID) variants, plus a handle-lookup dispatch function.


;;; Variables

(defparameter *within-complete-cfasl-objects* nil)

(defparameter *cfasl-externalized-constant-exceptions* nil
  "[Cyc] A set of constants for which is it OK to output as an internal handle rather than as an external recipe.")

(defconstant *cfasl-opcode-constant* 30)
(defconstant *cfasl-opcode-complete-constant* 32)
(defglobal *sample-invalid-constant* (create-sample-invalid-constant))

(defconstant *cfasl-opcode-nart* 31)
(defglobal *sample-invalid-nart* (create-sample-invalid-nart))

(defconstant *cfasl-opcode-assertion* 33)
(defglobal *sample-invalid-assertion* (create-sample-invalid-assertion))

(defconstant *cfasl-opcode-deduction* 36)
(defglobal *sample-invalid-deduction* (create-sample-invalid-deduction))

(defconstant *cfasl-opcode-kb-hl-support* 37)
(defglobal *sample-invalid-kb-hl-support* (create-sample-invalid-kb-hl-support))

(defconstant *cfasl-opcode-clause-struc* 38)
(defglobal *sample-invalid-clause-struc* (create-sample-invalid-clause-struc))

(defconstant *cfasl-opcode-variable* 40)
(defconstant *cfasl-opcode-complete-variable* 42)

(defconstant *cfasl-opcode-sbhl-directed-link* 90)
(defconstant *cfasl-opcode-sbhl-undirected-link* 91)

(defconstant *cfasl-opcode-hl-start* 94)
(defconstant *cfasl-opcode-hl-end* 95)


;;; Macro

;; Reconstructed from Internal Constants: arglist (CONSTANTS &BODY BODY),
;; uses CLET and *CFASL-EXTERNALIZED-CONSTANT-EXCEPTIONS*.
(defmacro with-cfasl-externalized-constant-exceptions (constants &body body)
  `(let ((*cfasl-externalized-constant-exceptions* ,constants))
     ,@body))


;;; Functions — Constants

(defun within-complete-cfasl-objects-p ()
  "[Cyc] Return T iff we are assuming complete CFASL constants (having guid and name) and complete variables (having only a name)."
  *within-complete-cfasl-objects*)

(defun cfasl-externalized-constant-exception-p (constant)
  "[Cyc] Return T iff CONSTANT is in the set of externalized constant exceptions."
  (and *cfasl-externalized-constant-exceptions*
       (set-member? constant *cfasl-externalized-constant-exceptions*)))

(defun cfasl-output-constant (constant stream)
  "[Cyc] Output CONSTANT to STREAM in CFASL format."
  (if (within-complete-cfasl-objects-p)
      (progn
        (cfasl-raw-write-byte *cfasl-opcode-complete-constant* stream)
        (cfasl-output-constant-recipe constant stream)
        (cfasl-output-string (constant-name constant) stream))
      (progn
        (cfasl-raw-write-byte *cfasl-opcode-constant* stream)
        (if (within-cfasl-externalization-p)
            (cfasl-output-constant-recipe constant stream)
            (missing-larkc 32180))))
  constant)

(defun cfasl-output-object-constant-method (object stream)
  "[Cyc] CFASL output method for constants."
  (cfasl-output-constant object stream))

(defun cfasl-invalid-constant ()
  "[Cyc] Return a sample invalid constant for use as a placeholder."
  *sample-invalid-constant*)

(defun cfasl-input-constant (stream)
  "[Cyc] Input a constant from STREAM in CFASL format."
  (let ((constant nil))
    (if (within-cfasl-externalization-p)
        (setf constant (cfasl-input-constant-recipe stream))
        (setf constant (cfasl-input-constant-handle stream)))
    (unless constant
      (setf constant *sample-invalid-constant*))
    constant))

(defun cfasl-input-complete-constant (stream)
  "[Cyc] Input the complete CFASL constant, assuming within-cfasl-externalization-p, and ignoring the constant name."
  (let ((constant nil))
    (setf constant (cfasl-input-constant-recipe stream))
    (cfasl-input-object stream)
    (unless constant
      (setf constant *sample-invalid-constant*))
    constant))

(defun cfasl-output-constant-recipe (constant stream)
  "[Cyc] Output CONSTANT as an externalized recipe (by external ID)."
  (if (cfasl-externalized-constant-exception-p constant)
      (missing-larkc 32181)
      (let ((external-id (constant-external-id constant)))
        (cfasl-output external-id stream)))
  constant)

(defun cfasl-input-constant-recipe (stream)
  "[Cyc] Input a constant recipe (external ID) from STREAM."
  (let ((id (cfasl-input stream)))
    (cond ((constant-external-id-p id)
           (find-constant-by-external-id id))
          ;; missing-larkc 31625 was a legacy ID check
          ((missing-larkc 31625)
           (cfasl-constant-handle-lookup id))
          (t nil))))

;; cfasl-output-constant-handle (constant stream) — active, no body
;; cfasl-input-constant-handle has body below

(defun cfasl-input-constant-handle (stream)
  "[Cyc] Input a constant by internal handle from STREAM."
  (let ((handle (cfasl-input stream)))
    (cfasl-constant-handle-lookup handle)))

;; cfasl-constant-handle (constant) — active, no body

(defun cfasl-constant-handle-lookup (id)
  "[Cyc] Look up a constant by internal ID, using the configured lookup method."
  (if (not (non-negative-integer-p id))
      *sample-invalid-constant*
      (let ((method *cfasl-constant-handle-lookup-func*))
        (cond ((null method)
               (find-constant-by-internal-id id))
              ((eq method 'find-constant-by-internal-id)
               (find-constant-by-internal-id id))
              ((eq method 'find-constant-by-dump-id)
               (find-constant-by-dump-id id))
              (t (funcall method id))))))


;;; Functions — NARTs

;; cfasl-output-nart (nart stream) — active, no body

(defun cfasl-output-object-nart-method (object stream)
  "[Cyc] CFASL output method for NARTs."
  (declare (ignore object stream))
  (missing-larkc 32184))

;; cfasl-invalid-nart () — active, no body

(defun cfasl-input-nart (stream)
  "[Cyc] Input a NART from STREAM in CFASL format."
  (let ((nart nil))
    (if (within-cfasl-externalization-p)
        (setf nart (missing-larkc 32172))
        (setf nart (cfasl-input-nart-handle stream)))
    (unless nart
      (setf nart *sample-invalid-nart*))
    nart))

;; cfasl-output-nart-recipe (nart stream) — active, no body
;; cfasl-input-nart-recipe (stream) — active, no body
;; cfasl-output-nart-handle (nart stream) — active, no body

(defun cfasl-input-nart-handle (stream)
  "[Cyc] Input a NART by internal handle from STREAM."
  (let ((handle (cfasl-input stream)))
    (cfasl-nart-handle-lookup handle)))

;; cfasl-nart-handle (nart) — active, no body

(defun cfasl-nart-handle-lookup (id)
  "[Cyc] Look up a NART by internal ID, using the configured lookup method."
  (if (not (non-negative-integer-p id))
      *sample-invalid-nart*
      (let ((method *cfasl-nart-handle-lookup-func*))
        (cond ((null method)
               (find-nart-by-id id))
              ((eq method 'find-nart-by-id)
               (find-nart-by-id id))
              ((eq method 'find-nart-by-dump-id)
               (find-nart-by-dump-id id))
              (t (funcall method id))))))


;;; Functions — Assertions

;; cfasl-output-assertion (assertion stream) — active, no body

(defun cfasl-output-object-assertion-method (object stream)
  "[Cyc] CFASL output method for assertions."
  (declare (ignore object stream))
  (missing-larkc 32178))

;; cfasl-invalid-assertion () — active, no body

(defun cfasl-input-assertion (stream)
  "[Cyc] Input an assertion from STREAM in CFASL format."
  (let ((assertion nil))
    (if (within-cfasl-externalization-p)
        (setf assertion (missing-larkc 32166))
        (setf assertion (cfasl-input-assertion-handle stream)))
    (unless assertion
      (setf assertion *sample-invalid-assertion*))
    assertion))

;; cfasl-output-assertion-recipe (assertion stream) — active, no body
;; cfasl-input-assertion-recipe (stream) — active, no body
;; cfasl-output-assertion-handle (assertion stream) — active, no body

(defun cfasl-input-assertion-handle (stream)
  "[Cyc] Input an assertion by internal handle from STREAM."
  (let ((handle (cfasl-input stream)))
    (cfasl-assertion-handle-lookup handle)))

;; cfasl-assertion-handle (assertion) — active, no body

(defun cfasl-assertion-handle-lookup (id)
  "[Cyc] Look up an assertion by internal ID, using the configured lookup method."
  (if (not (non-negative-integer-p id))
      *sample-invalid-assertion*
      (let ((method *cfasl-assertion-handle-lookup-func*))
        (cond ((null method)
               (find-assertion-by-id id))
              ((eq method 'find-assertion-by-id)
               (find-assertion-by-id id))
              ((eq method 'find-assertion-by-dump-id)
               (find-assertion-by-dump-id id))
              (t (funcall method id))))))


;;; Functions — Deductions

;; cfasl-output-deduction (deduction stream) — active, no body

(defun cfasl-output-object-deduction-method (object stream)
  "[Cyc] CFASL output method for deductions."
  (declare (ignore object stream))
  (missing-larkc 32182))

;; cfasl-invalid-deduction () — active, no body

(defun cfasl-input-deduction (stream)
  "[Cyc] Input a deduction from STREAM in CFASL format."
  (let ((deduction nil))
    (if (within-cfasl-externalization-p)
        (setf deduction (missing-larkc 32168))
        (setf deduction (cfasl-input-deduction-handle stream)))
    (unless deduction
      (setf deduction *sample-invalid-deduction*))
    deduction))

;; cfasl-output-deduction-recipe (deduction stream) — active, no body
;; cfasl-input-deduction-recipe (stream) — active, no body
;; cfasl-output-deduction-handle (deduction stream) — active, no body

(defun cfasl-input-deduction-handle (stream)
  "[Cyc] Input a deduction by internal handle from STREAM."
  (let ((handle (cfasl-input stream)))
    (cfasl-deduction-handle-lookup handle)))

;; cfasl-deduction-handle (deduction) — active, no body

(defun cfasl-deduction-handle-lookup (id)
  "[Cyc] Look up a deduction by internal ID, using the configured lookup method."
  (if (not (non-negative-integer-p id))
      *sample-invalid-deduction*
      (let ((method *cfasl-deduction-handle-lookup-func*))
        (cond ((null method)
               (find-deduction-by-id id))
              ((eq method 'find-deduction-by-id)
               (find-deduction-by-id id))
              ((eq method 'find-deduction-by-dump-id)
               (find-deduction-by-dump-id id))
              (t (funcall method id))))))


;;; Functions — KB-HL-Supports

;; cfasl-output-kb-hl-support (kb-hl-support stream) — active, no body

(defun cfasl-output-object-kb-hl-support-method (object stream)
  "[Cyc] CFASL output method for KB-HL-supports."
  (declare (ignore object stream))
  (missing-larkc 32183))

;; cfasl-invalid-kb-hl-support () — active, no body

(defun cfasl-input-kb-hl-support (stream)
  "[Cyc] Input a KB-HL-support from STREAM in CFASL format."
  (let ((kb-hl-support nil))
    (if (within-cfasl-externalization-p)
        (setf kb-hl-support (missing-larkc 32171))
        (setf kb-hl-support (cfasl-input-kb-hl-support-handle stream)))
    (unless kb-hl-support
      (setf kb-hl-support *sample-invalid-kb-hl-support*))
    kb-hl-support))

;; cfasl-output-kb-hl-support-recipe (kb-hl-support stream) — active, no body
;; cfasl-input-kb-hl-support-recipe (stream) — active, no body
;; cfasl-output-kb-hl-support-handle (kb-hl-support stream) — active, no body

(defun cfasl-input-kb-hl-support-handle (stream)
  "[Cyc] Input a KB-HL-support by internal handle from STREAM."
  (let ((handle (cfasl-input stream)))
    (cfasl-kb-hl-support-handle-lookup handle)))

;; cfasl-kb-hl-support-handle (kb-hl-support) — active, no body

(defun cfasl-kb-hl-support-handle-lookup (id)
  "[Cyc] Look up a KB-HL-support by ID, using the configured lookup method."
  (let ((method (or *cfasl-kb-hl-support-handle-lookup-func*
                    'find-kb-hl-support-by-id)))
    (cond ((eq method 'find-kb-hl-support-by-id)
           (find-kb-hl-support-by-id id))
          ((eq method 'find-kb-hl-support-by-dump-id)
           (find-kb-hl-support-by-dump-id id))
          (t (funcall method id)))))


;;; Functions — Clause-Strucs

;; cfasl-output-clause-struc (clause-struc stream) — active, no body

(defun cfasl-output-object-clause-struc-method (object stream)
  "[Cyc] CFASL output method for clause-strucs."
  (declare (ignore object stream))
  (missing-larkc 32179))

;; cfasl-invalid-clause-struc () — active, no body

(defun cfasl-input-clause-struc (stream)
  "[Cyc] Input a clause-struc from STREAM in CFASL format."
  (let ((clause-struc nil))
    (if (within-cfasl-externalization-p)
        (setf clause-struc (missing-larkc 32167))
        (setf clause-struc (cfasl-input-clause-struc-handle stream)))
    (unless clause-struc
      (setf clause-struc *sample-invalid-clause-struc*))
    clause-struc))

;; cfasl-output-clause-struc-recipe (clause-struc stream) — active, no body
;; cfasl-input-clause-struc-recipe (stream) — active, no body
;; cfasl-output-clause-struc-handle (clause-struc stream) — active, no body

(defun cfasl-input-clause-struc-handle (stream)
  "[Cyc] Input a clause-struc by internal handle from STREAM."
  (let ((handle (cfasl-input stream)))
    (cfasl-clause-struc-handle-lookup handle)))

;; cfasl-clause-struc-handle (clause-struc) — active, no body

(defun cfasl-clause-struc-handle-lookup (id)
  "[Cyc] Look up a clause-struc by internal ID, using the configured lookup method."
  (if (not (non-negative-integer-p id))
      *sample-invalid-clause-struc*
      (let ((method *cfasl-clause-struc-handle-lookup-func*))
        (cond ((null method)
               (find-clause-struc-by-id id))
              ((eq method 'find-clause-struc-by-id)
               (find-clause-struc-by-id id))
              ((eq method 'find-clause-struc-by-dump-id)
               ;; Java calls missing-larkc 11345 for find-clause-struc-by-dump-id
               (missing-larkc 11345))
              (t (funcall method id))))))


;;; Functions — Variables

;; cfasl-output-variable (variable stream) — active, no body

(defun cfasl-output-object-variable-method (object stream)
  "[Cyc] CFASL output method for variables."
  (declare (ignore object stream))
  (missing-larkc 32187))

(defun cfasl-input-variable (stream)
  "[Cyc] Input a variable from STREAM in CFASL format."
  (find-variable-by-id (cfasl-input stream)))

;; cfasl-input-complete-variable (stream) — active, no body


;;; Functions — SBHL Links

(defun cfasl-output-object-sbhl-directed-link-method (object stream)
  "[Cyc] CFASL output method for SBHL directed links."
  (declare (ignore object stream))
  (missing-larkc 32185))

;; cfasl-output-sbhl-directed-link (link stream) — active, no body

(defun cfasl-input-sbhl-directed-link (stream)
  "[Cyc] Input an SBHL directed link from STREAM in CFASL format."
  (let ((d-link (make-sbhl-directed-link)))
    (setf (sbhl-directed-link-predicate-links d-link) (cfasl-input stream))
    (setf (sbhl-directed-link-inverse-links d-link) (cfasl-input stream))
    d-link))

(defun cfasl-output-object-sbhl-undirected-link-method (object stream)
  "[Cyc] CFASL output method for SBHL undirected links."
  (declare (ignore object stream))
  (missing-larkc 32186))

;; cfasl-output-sbhl-undirected-link (link stream) — active, no body

(defun cfasl-input-sbhl-undirected-link (stream)
  "[Cyc] Input an SBHL undirected link from STREAM in CFASL format."
  (let ((d-link (make-sbhl-undirected-link)))
    (setf (sbhl-undirected-link-links d-link) (cfasl-input stream))
    d-link))


;;; Functions — HL Start/End markers

(defun cfasl-input-hl-start (stream)
  "[Cyc] Input an HL-start marker from STREAM."
  (declare (ignore stream))
  (missing-larkc 32170))

(defun cfasl-input-hl-end (stream)
  "[Cyc] Input an HL-end marker from STREAM."
  (declare (ignore stream))
  (missing-larkc 32169))


;;; Setup — register CFASL input functions and output methods

;; TODO - invalid constants should probably raise conditions instead of returning a freak placeholder that needs to be checked. All current uses seem to warn and skip/abort, which is better using conditions.
(toplevel
  ;; Constants
  (register-cfasl-input-function *cfasl-opcode-constant* 'cfasl-input-constant)
  (register-cfasl-input-function *cfasl-opcode-complete-constant* 'cfasl-input-complete-constant)
  (declare-defglobal '*sample-invalid-constant*)

  ;; NARTs
  (register-cfasl-input-function *cfasl-opcode-nart* 'cfasl-input-nart)
  (declare-defglobal '*sample-invalid-nart*)

  ;; Assertions
  (register-cfasl-input-function *cfasl-opcode-assertion* 'cfasl-input-assertion)
  (declare-defglobal '*sample-invalid-assertion*)

  ;; Deductions
  (register-cfasl-input-function *cfasl-opcode-deduction* 'cfasl-input-deduction)
  (declare-defglobal '*sample-invalid-deduction*)

  ;; KB-HL-Supports
  (register-cfasl-input-function *cfasl-opcode-kb-hl-support* 'cfasl-input-kb-hl-support)
  (declare-defglobal '*sample-invalid-kb-hl-support*)

  ;; Clause-Strucs
  (register-cfasl-input-function *cfasl-opcode-clause-struc* 'cfasl-input-clause-struc)
  (declare-defglobal '*sample-invalid-clause-struc*)

  ;; Variables
  (register-cfasl-input-function *cfasl-opcode-variable* 'cfasl-input-variable)
  (register-cfasl-input-function *cfasl-opcode-complete-variable* 'cfasl-input-complete-variable)

  ;; SBHL Links
  (register-cfasl-input-function *cfasl-opcode-sbhl-directed-link* 'cfasl-input-sbhl-directed-link)
  (register-cfasl-input-function *cfasl-opcode-sbhl-undirected-link* 'cfasl-input-sbhl-undirected-link)

  ;; HL markers
  (register-cfasl-input-function *cfasl-opcode-hl-start* 'cfasl-input-hl-start)
  (register-cfasl-input-function *cfasl-opcode-hl-end* 'cfasl-input-hl-end))

;; Output dispatch — register CLOS methods on cfasl-output-object generic
;; Java uses Structures.register_method on *cfasl-output-object-method-table* array;
;; CL port uses defmethod on the cfasl-output-object generic function instead.

(defmethod cfasl-output-object ((object constant) stream)
  (cfasl-output-object-constant-method object stream))

(defmethod cfasl-output-object ((object nart) stream)
  (cfasl-output-object-nart-method object stream))

(defmethod cfasl-output-object ((object assertion) stream)
  (cfasl-output-object-assertion-method object stream))

(defmethod cfasl-output-object ((object deduction) stream)
  (cfasl-output-object-deduction-method object stream))

(defmethod cfasl-output-object ((object kb-hl-support) stream)
  (cfasl-output-object-kb-hl-support-method object stream))

(defmethod cfasl-output-object ((object clause-struc) stream)
  (cfasl-output-object-clause-struc-method object stream))

(defmethod cfasl-output-object ((object variable) stream)
  (cfasl-output-object-variable-method object stream))

(defmethod cfasl-output-object ((object sbhl-directed-link) stream)
  (cfasl-output-object-sbhl-directed-link-method object stream))

(defmethod cfasl-output-object ((object sbhl-undirected-link) stream)
  (cfasl-output-object-sbhl-undirected-link-method object stream))
