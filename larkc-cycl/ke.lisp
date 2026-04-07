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

;;; Variables (from init section)

(defparameter *note-merged-constant-name* t
  "[Cyc] Do we keep the merged constant name info in the KB?")

(defparameter *note-old-constant-name* t
  "[Cyc] Do we keep previous constant name info in the KB?")

(defparameter *check-if-already-ke-unasserted?* nil)

;; deflexical + boundp guard -> defglobal
(defglobal *ke-edit-use-fi-edit* nil
  "[Cyc] Temporary control-variable;
When non-nil, KE-EDIT uses FI-EDIT,
otherwise it uses KE-UNASSERT, KE-ASSERT")

;; deflexical + boundp guard -> defglobal
(defglobal *old-constant-names-table* nil
  "[Cyc] A hash table:  keys are strings, values are lists of constants related to
those strings by #$oldConstantName.")

(defparameter *ke-assertion-edit-formula-find-func* 'assertion-tl-ist-formula)

(defparameter *ke-assertion-edit-formula-display-func* 'assertion-el-formula)


;;; Functions (in declare_ke_file ordering)

;; (defun ke-create (name) ...) -- no body, commented declareFunction
;; (defun ke-create-from-serialization (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun ke-create-internal (name &optional external-id) ...) -- no body, commented declareFunction

(defun ke-create-now (name &optional external-id)
  "[Cyc] Create new constant now and add operation to transcript. If EXTERNAL-ID is non-null
it is used, otherwise a unique identifier is generated.
@return 0 constant ;; new constant if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param NAME string
@param EXTERNAL-ID guid-p
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error."
  (let ((result nil)
        (error-message nil))
    (handler-case
        (let ((*fi-last-constant* nil))
          (setf result (fi-create-int name external-id)))
      (error (e)
        (setf error-message (princ-to-string e))))
    (when result
      (add-to-transcript-queue
       (tl-encapsulate (list 'fi-create
                             (list 'quote (constant-name result))
                             (constant-external-id result))))
      (ignore-errors
       (let ((*fi-last-constant* result))
         (when (fi-timestamp-constant-int (the-cyclist) (the-date)
                                          (ke-purpose) (the-second))
           (add-to-transcript-queue
            (tl-encapsulate (list 'fi-timestamp-constant
                                  (list 'quote (the-cyclist))
                                  (list 'quote (the-date))
                                  (list 'quote (ke-purpose))
                                  (list 'quote (the-second))))))))
      (return-from ke-create-now result))
    (when error-message
      (return-from ke-create-now
        (values nil (list :fatal-error error-message))))
    (when (fi-error-signaled?)
      (return-from ke-create-now
        ;; missing-larkc 11146 likely returns the fi-error-type, and
        ;; missing-larkc 11147 likely returns the fi-error format args
        ;; (the error-type . format-args pattern for fi error reporting)
        (values nil (list (first (missing-larkc 11146))
                          (apply #'format nil (rest (missing-larkc 11147)))))))
    (values nil '(:unknown-error "An unknown error has occurred"))))

(defun ke-find-or-create-now (name &optional external-id)
  "[Cyc] Get the named constant if it exists.
Otherwise, Create new constant now and add operation to transcript. If EXTERNAL-ID is non-null
it is used, otherwise a unique identifier is generated.
@return 0 constant ;; relevant constant if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param NAME string
@param EXTERNAL-ID guid-p
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error."
  (let ((constant (fi-find-int name)))
    (if constant
        (values constant nil)
        (ke-create-now name external-id))))

;; (defun ke-recreate-now (arg1) ...) -- no body, commented declareFunction
;; (defun ke-merge (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun ke-merge-now (arg1 arg2) ...) -- no body, commented declareFunction
;; (defun ke-kill (fort) ...) -- no body, commented declareFunction

(defun ke-kill-now (fort)
  "[Cyc] Kill FORT now and add operation to transcript.
@return 0 boolean ;; t if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param FORT fort
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error."
  (let ((result nil)
        (transcript-op nil)
        (error-message nil))
    (setf fort (eval fort))
    (setf transcript-op (tl-encapsulate (list 'fi-kill (list 'quote fort))))
    (handler-case
        (setf result (fi-kill-int fort))
      (error (e)
        (setf error-message (princ-to-string e))))
    (when result
      (add-to-transcript-queue transcript-op)
      (return-from ke-kill-now result))
    (when error-message
      (return-from ke-kill-now
        (values nil (list :fatal-error error-message))))
    (when (fi-error-signaled?)
      (return-from ke-kill-now
        ;; missing-larkc 11148 likely returns the fi-error-type, and
        ;; missing-larkc 11149 likely returns the fi-error format args
        (values nil (list (first (missing-larkc 11148))
                          (apply #'format nil (rest (missing-larkc 11149)))))))
    (values nil '(:unknown-error "An unknown error has occurred"))))

;; (defun ke-recreate (fort) ...) -- no body, commented declareFunction
;; (defun rename-code-constant (constant name) ...) -- no body, commented declareFunction
;; (defun ke-rename (constant name) ...) -- no body, commented declareFunction
;; (defun ke-rename-code-constant (constant name) ...) -- no body, commented declareFunction
;; (defun ke-rename-internal (constant name) ...) -- no body, commented declareFunction
;; (defun note-old-constant-name (constant name) ...) -- no body, commented declareFunction

(defun ke-rename-now (constant name)
  "[Cyc] Rename CONSTANT to NAME now and add operation to transcript.
@return 0 constant ;; new constant name if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param CONSTANT constant
@param NAME string
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error."
  (let ((old-name (constant-name constant))
        (result nil)
        (transcript-op nil)
        (error-message nil))
    (setf constant (eval constant))
    (setf transcript-op (tl-encapsulate
                          (list 'fi-rename
                                (list 'quote constant)
                                (list 'quote name))))
    (handler-case
        (setf result (fi-rename-int constant name))
      (error (e)
        (setf error-message (princ-to-string e))))
    (when result
      (add-to-transcript-queue transcript-op)
      (when (and *note-old-constant-name*
                 (stringp old-name))
        ;; Remove old #$oldConstantName assertions for this constant in BookkeepingMt
        (ignore-errors
         (let ((*relevant-mt-function* #'relevant-mt-is-eq)
               (*mt* #$BookkeepingMt))
           (do-gaf-arg-index (assertion constant :index 1 :predicate #$oldConstantName)
             ;; missing-larkc 10961 likely calls fi-blast or ke-blast to remove
             ;; the old assertion recording the previous constant name
             (missing-larkc 10961))))
        (ke-assert-now (list #$oldConstantName constant old-name)
                       #$BookkeepingMt)
        (return-from ke-rename-now result)))
    (when error-message
      (return-from ke-rename-now
        (values :fatal-error error-message)))
    (when (fi-error-signaled?)
      (return-from ke-rename-now
        ;; missing-larkc 11150 likely returns the fi-error-type, and
        ;; missing-larkc 11151 likely returns the fi-error format args
        (values nil (list (first (missing-larkc 11150))
                          (apply #'format nil (rest (missing-larkc 11151)))))))
    (values nil '(:unknown-error "An unknown error has occurred"))))

;; commented declareFunction, but body present in Java -- ported for reference
(defun ke-assert (formula mt &optional strength direction)
  "[Cyc] Assert FORMULA in MT, queueing or executing now based on local queue state."
  (when (null strength)
    (setf strength :default))
  (when (ensure-cyclist-ok)
    (setf mt (canonicalize-hlmt mt))
    (let ((ans (do-edit-op (list* 'fi-assert
                                  (list 'quote formula)
                                  (list 'quote mt)
                                  (list 'quote strength)
                                  (append (when direction
                                            (list (list 'quote direction)))
                                          nil))))
          (error nil))
      (unless (eq ans :queued)
        (setf error (fi-get-error-int)))
      (do-edit-op (list 'fi-timestamp-assertion
                        (list 'quote (the-cyclist))
                        (list 'quote (the-date))
                        (list 'quote (ke-purpose))
                        (list 'quote (the-second))))
      (unless (eq ans :queued)
        (signal-fi-error error))
      ans)))

;; (defun ke-reassert-assertion-now (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun ke-reassert-assertion-now-int (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun ke-reassert-assertion (arg1 arg2 arg3) ...) -- no body, commented declareFunction
;; (defun ke-repropagate-assertion-now (assertion) ...) -- no body, commented declareFunction
;; (defun ke-repropagate-assertion (assertion) ...) -- no body, commented declareFunction

(defun ke-assert-now (formula mt &optional (strength :default) direction)
  "[Cyc] Assert FORMULA in MT now and add operation to transcript.
@return 0 boolean ;; t if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param FORMULA list
@param MT microtheory
@param STRENGTH keyword
@param DIRECTION keyword
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error."
  (ke-assert-now-int formula mt strength direction nil))

;; commented declareFunction, but body present in Java -- ported for reference
(defun ke-assert-wff-now (formula mt &optional (strength :default) direction)
  "[Cyc] Assert FORMULA in MT now and add operation to transcript.
FORMULA is assumed to be WFF.
@return 0 boolean ;; t if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param FORMULA list
@param MT microtheory
@param STRENGTH keyword
@param DIRECTION keyword
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error."
  (ke-assert-now-int formula mt strength direction t))

(defun ke-assert-now-int (formula mt strength direction wff?)
  "[Cyc] Internal implementation for ke-assert-now and ke-assert-wff-now."
  (let ((result nil)
        (error-message nil)
        (v-hlmt (canonicalize-hlmt mt))
        (assertions nil))
    (if (not *inference-debug?*)
        (handler-case
            (let ((*fi-last-assertions-asserted* nil))
              (let ((v-properties (list :strength strength :direction direction)))
                (if wff?
                    (setf result (cyc-assert-wff formula v-hlmt v-properties))
                    (setf result (cyc-assert formula v-hlmt v-properties)))
                (setf assertions *fi-last-assertions-asserted*)))
          (error (e)
            (setf error-message (princ-to-string e))))
        (let ((*fi-last-assertions-asserted* nil))
          (let ((v-properties (list :strength strength :direction direction)))
            (if wff?
                (setf result (cyc-assert-wff formula v-hlmt v-properties))
                (setf result (cyc-assert formula v-hlmt v-properties)))
            (setf assertions *fi-last-assertions-asserted*))))
    (when result
      (add-to-transcript-queue
       (tl-encapsulate (list 'fi-assert
                             (list 'quote formula)
                             (list 'quote v-hlmt)
                             (list 'quote strength)
                             (list 'quote direction))))
      (ignore-errors
       (let ((*fi-last-assertions-asserted* assertions))
         (when (fi-timestamp-assertion-int (the-cyclist) (the-date)
                                           (ke-purpose) (the-second))
           (add-to-transcript-queue
            (tl-encapsulate (list 'fi-timestamp-assertion
                                  (list 'quote (the-cyclist))
                                  (list 'quote (the-date))
                                  (list 'quote (ke-purpose))
                                  (list 'quote (the-second))))))))
      (return-from ke-assert-now-int (values result nil)))
    (when error-message
      (return-from ke-assert-now-int
        (values nil (list :fatal-error error-message))))
    (when (fi-error-signaled?)
      (return-from ke-assert-now-int
        ;; missing-larkc 11152 likely returns the fi-error-type, and
        ;; missing-larkc 11153 likely returns the fi-error format args
        (values nil (list (first (missing-larkc 11152))
                          (apply #'format nil (rest (missing-larkc 11153)))))))
    (values nil '(:unknown-error "An unknown error has occurred"))))

;; (defun ke-assert-with-implicature (formula mt &optional strength direction) ...) -- no body, commented declareFunction
;; (defun ke-assert-now-with-implicature (formula mt &optional strength direction) ...) -- no body, commented declareFunction
;; (defun ke-assert-with-implicature-int (formula mt strength direction wff?) ...) -- no body, commented declareFunction
;; (defun ke-assert-with-implicature-int-assert (formula mt strength direction wff?) ...) -- no body, commented declareFunction
;; (defun ke-unassert (formula mt) ...) -- no body, commented declareFunction
;; (defun ke-unassert-assertion (assertion) ...) -- no body, commented declareFunction
;; (defun ke-unassert-now (formula mt) ...) -- no body, commented declareFunction
;; (defun ke-unassert-assertion-now (assertion) ...) -- no body, commented declareFunction
;; (defun ke-edit (old-formula new-formula mt &optional old-strength old-direction new-direction) ...) -- no body, commented declareFunction
;; (defun ke-edit-now (old-formula new-formula mt &optional old-strength old-direction new-direction) ...) -- no body, commented declareFunction
;; (defun ke-edit-assertion (assertion new-formula &optional new-mt new-strength new-direction) ...) -- no body, commented declareFunction
;; (defun ke-edit-assertion-preserving-meta-assertions (old-formula new-formula mt &optional old-strength old-direction new-direction) ...) -- no body, commented declareFunction
;; (defun ke-edit-assertion-now-preserving-meta-assertions (old-formula new-formula mt &optional old-strength old-direction new-direction) ...) -- no body, commented declareFunction
;; (defun ke-edit-assertion-preserving-meta-assertions-int (old-formula new-formula mt old-strength old-direction new-direction now?) ...) -- no body, commented declareFunction
;; (defun ke-edit-assertion-preserving-all-meta-assertions (assertion new-formula &optional new-mt new-strength new-direction) ...) -- no body, commented declareFunction
;; (defun ke-edit-assertion-now-preserving-all-meta-assertions (assertion new-formula &optional new-mt new-strength new-direction) ...) -- no body, commented declareFunction
;; (defun ke-null-edit-assertion (assertion) ...) -- no body, commented declareFunction
;; (defun ke-edit-compute-new-meta-assertion-assertibles (old-assertion new-assertion old-meta-assertion-info meta-assertion-spec) ...) -- no body, commented declareFunction
;; (defun extract-old-meta-assertion-info (assertion) ...) -- no body, commented declareFunction
;; (defun ke-edit-assertion-strings (assertion new-formula &optional new-mt) ...) -- no body, commented declareFunction
;; (defun ke-recanonicalize-assertion (assertion &optional force?) ...) -- no body, commented declareFunction
;; (defun ke-recanonicalize-assertion-now (assertion &optional force?) ...) -- no body, commented declareFunction
;; (defun ke-edit-assertion-but-not-bookkeeping (assertion new-formula &optional new-mt new-strength new-direction editP) ...) -- no body, commented declareFunction
;; (defun ke-edit-assertion-now-but-not-bookkeeping (assertion new-formula &optional new-mt new-strength new-direction editP) ...) -- no body, commented declareFunction
;; (defun formulas-differ-only-in-strings (formula1 formula2) ...) -- no body, commented declareFunction
;; (defun tree-equal-ignoring-type (tree1 tree2 type &optional test) ...) -- no body, commented declareFunction
;; (defun ke-blast (formula mt) ...) -- no body, commented declareFunction
;; (defun ke-blast-assertion (assertion) ...) -- no body, commented declareFunction
;; (defun ke-rename-variables (formula mt rename-alist) ...) -- no body, commented declareFunction
;; (defun ke-remove-argument (formula mt argument) ...) -- no body, commented declareFunction
;; (defun ke-remove-deduction (deduction) ...) -- no body, commented declareFunction
;; (defun ke-tms-reconsider-term (fort &optional mt) ...) -- no body, commented declareFunction
;; (defun ke-tms-reconsider-formula (formula mt) ...) -- no body, commented declareFunction
;; (defun ke-tms-reconsider-assertion (assertion) ...) -- no body, commented declareFunction
;; (defun ke-blast-all-dependents (assertion) ...) -- no body, commented declareFunction
;; (defun ke-change-assertion-direction (assertion direction) ...) -- no body, commented declareFunction
;; (defun ke-change-assertion-strength (assertion strength) ...) -- no body, commented declareFunction
;; (defun ke-change-assertion-mt (assertion mt &optional also-change-meta-assertions?) ...) -- no body, commented declareFunction
;; (defun ke-convert-assertion (assertion new-type &optional new-mt new-direction) ...) -- no body, commented declareFunction

(defun old-constant-names (string)
  "[Cyc] Find any constants for which STRING is an oldConstantName."
  (when *old-constant-names-table*
    (values (gethash string *old-constant-names-table*))))

(defun initialize-old-constant-names ()
  "[Cyc] Set up the *old-constant-names-table* table."
  (let ((total (num-predicate-extent-index #$oldConstantName #$BookkeepingMt)))
    (unless (hash-table-p *old-constant-names-table*)
      (setf *old-constant-names-table* (make-hash-table :test #'equalp :size total)))
    (clrhash *old-constant-names-table*)
    (let ((sofar 0))
      (noting-percent-progress ("Initializing old constant name table")
        (let ((*relevant-mt-function* #'relevant-mt-is-eq)
              (*mt* #$BookkeepingMt))
          (do-predicate-extent-index (gaf #$oldConstantName :truth :true)
            (incf sofar)
            (note-percent-progress sofar total)
            (when (gaf-assertion? gaf)
              (let ((constant (gaf-arg gaf 1))
                    (string (gaf-arg gaf 2)))
                (cache-old-constant-name string constant))))))))
  (hash-table-count *old-constant-names-table*))

(defun cache-old-constant-name (string constant)
  "[Cyc] Cache the association of STRING with CONSTANT in the old constant names table."
  (when *old-constant-names-table*
    (let ((entry (old-constant-names string)))
      (setf (gethash string *old-constant-names-table*)
            (adjoin constant entry :test #'equalp)))
    t))

(defun decache-old-constant-name (string constant)
  "[Cyc] Remove the association of STRING with CONSTANT from the old constant names table."
  (when *old-constant-names-table*
    (let ((entry (old-constant-names string)))
      (when entry
        (setf entry (delete constant entry :test #'equalp))
        (if (null entry)
            (remhash string *old-constant-names-table*)
            (setf (gethash string *old-constant-names-table*) entry))))
    t))

;; commented declareFunction, but body present in Java -- ported for reference
(defun do-edit-op (form)
  "[Cyc] Execute FORM either via local queue or direct eval."
  (if *use-local-queue?*
      (add-to-local-queue form t)
      (eval form)))

;; (defun find-assertions-via-tl (formula mt) ...) -- no body, commented declareFunction
;; (defun ke-assertion-edit-formula (assertion) ...) -- no body, commented declareFunction
;; (defun ke-assertion-find-formula (assertion) ...) -- no body, commented declareFunction

;; commented declareFunction, but body present in Java -- ported for reference
(defun cyclist-is-guest ()
  "[Cyc] Test to determine if the user should have editing privileges, or not."
  (if *allow-guest-to-edit?*
      nil
      (equalp (the-cyclist) #$Guest)))

;; commented declareFunction, but body present in Java -- ported for reference
(defun ensure-cyclist-ok ()
  "[Cyc] Ensure the current cyclist is allowed to edit the KB."
  (if (cyclist-is-guest)
      (progn
        (error "KB editing is not allowed for users logged in as #$Guest.")
        nil)
      t))

;; (defun ke-eval-now (form) ...) -- no body, commented declareFunction


;;; Setup section

(toplevel
  (register-external-symbol 'ke-create)
  (register-cyc-api-function 'ke-create-now
    '(name &optional external-id)
    "Create new constant now and add operation to transcript. If EXTERNAL-ID is non-null
it is used, otherwise a unique identifier is generated.
@return 0 constant ;; new constant if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param NAME string
@param EXTERNAL-ID guid-p
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error.
@owner jantos
@privacy done
"
    nil
    '(constant-p listp))
  (register-external-symbol 'ke-merge)
  (register-external-symbol 'ke-kill)
  (register-cyc-api-function 'ke-kill-now
    '(fort)
    "Kill FORT now and add operation to transcript.
@return 0 boolean ;; t if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param FORT fort
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error.
@owner jantos
@privacy done
"
    nil
    '(booleanp listp))
  (register-external-symbol 'ke-assert)
  (register-cyc-api-function 'ke-assert-now
    '(formula mt &optional (strength :default) direction)
    "Assert FORMULA in MT now and add operation to transcript.
@return 0 boolean ;; t if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param FORMULA list
@param MT microtheory
@param STRENGTH keyword
@param DIRECTION keyword
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error.
@owner jantos
@privacy done
"
    nil
    '(booleanp listp))
  (register-cyc-api-function 'ke-assert-wff-now
    '(formula mt &optional (strength :default) direction)
    "Assert FORMULA in MT now and add operation to transcript.
FORMULA is assumed to be WFF.
@return 0 boolean ;; t if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param FORMULA list
@param MT microtheory
@param STRENGTH keyword
@param DIRECTION keyword
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error.
@owner jantos
@privacy done
"
    nil
    '(booleanp listp))
  (register-external-symbol 'ke-unassert)
  (register-cyc-api-function 'ke-unassert-now
    '(formula mt)
    "Unassert FORMULA in MT now and add operation to transcript.
@return 0 boolean ;; t if success, o/w nil
@return 1 list ;; error list of form (ERROR-TYPE ERROR-STRING) otherwise.
@param FORMULA list
@param MT microtheory
@note Assumes cyclist is ok.
@note The salient property of this function is that it never throws an error.
@owner jantos
@privacy done
"
    nil
    '(booleanp listp))
  (declare-defglobal '*ke-edit-use-fi-edit*)
  (register-external-symbol 'ke-edit-assertion-preserving-all-meta-assertions)
  (declare-defglobal '*old-constant-names-table*))
