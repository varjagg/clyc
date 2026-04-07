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

;;; Variables

(deflexical *red-variables-dictionary*
  (if (boundp '*red-variables-dictionary*)
      *red-variables-dictionary*
      (make-hash-table :test #'eql))
  "[Cyc] The list of red symbols  by DEFINE-red-ltype.")

(deflexical *red-symbols-list*
  (if (boundp '*red-symbols-list*)
      *red-symbols-list*
      nil)
  "[Cyc] The list of all known red-symbols.")

(deflexical *red-keys-dictionary*
  (if (boundp '*red-keys-dictionary*)
      *red-keys-dictionary*
      (make-hash-table :test #'eql))
  "[Cyc] a dictionary whose keys are all known red-keys and whose values are lists of red symbols")

(deflexical *red-reload-callback-moniker-dictionary*
  (if (boundp '*red-reload-callback-moniker-dictionary*)
      *red-reload-callback-moniker-dictionary*
      (make-hash-table :test #'eql))
  "[Cyc] a dictionary whose keys are monikers(keywords) and whose values are lists of callback routines")

(deflexical *repositories-loaded*
  (if (boundp '*repositories-loaded*)
      *repositories-loaded*
      nil)
  "[Cyc] Set by def-red-set-vars to T")

;;; red-symbol struct

(defstruct (red-symbol
            (:conc-name "RED-SYMBOL-")
            (:constructor make-red-symbol-struct (&key name red-key default-value ltype set-from-red valuetype)))
  name
  red-key
  default-value
  ltype
  set-from-red
  valuetype)

(defconstant *dtp-red-symbol* 'red-symbol)

(defun red-symbol-print-function-trampoline (object stream)
  ;; Likely calls print-red-symbol -- evidence: registered as print method in setup
  (declare (ignore object stream))
  (missing-larkc 30850))

;; (defun red-symbol-p (object) ...) -- active declareFunction, no body
;; Accessors red-symbol-name, red-symbol-red-key, red-symbol-default-value,
;; red-symbol-ltype, red-symbol-set-from-red, red-symbol-valuetype and their
;; setf counterparts are provided by defstruct.

(defun make-red-symbol (&optional arglist)
  (let ((v-new (make-red-symbol-struct)))
    (loop for next = arglist then (cddr next)
          while next
          do (let ((current-arg (first next))
                   (current-value (cadr next)))
               (case current-arg
                 (:name (setf (red-symbol-name v-new) current-value))
                 (:red-key (setf (red-symbol-red-key v-new) current-value))
                 (:default-value (setf (red-symbol-default-value v-new) current-value))
                 (:ltype (setf (red-symbol-ltype v-new) current-value))
                 (:set-from-red (setf (red-symbol-set-from-red v-new) current-value))
                 (:valuetype (setf (red-symbol-valuetype v-new) current-value))
                 (otherwise (error "Invalid slot ~S for construction function" current-arg)))))
    v-new))

(defun new-red-symbol (red-key name defaultval ltype &optional (valuetype :simple))
  (let ((red-sym-obj (make-red-symbol)))
    (setf (red-symbol-name red-sym-obj) name)
    (setf (red-symbol-red-key red-sym-obj) red-key)
    (setf (red-symbol-default-value red-sym-obj) defaultval)
    (setf (red-symbol-ltype red-sym-obj) ltype)
    (setf (red-symbol-set-from-red red-sym-obj) nil)
    (setf (red-symbol-valuetype red-sym-obj) valuetype)
    red-sym-obj))

;; (defun print-red-symbol (object stream depth) ...) -- active declareFunction, no body
;; (defun set-red-symbols () ...) -- active declareFunction, no body
;; (defun list-def-red-non-repository-initialized-variables () ...) -- active declareFunction, no body
;; (defun list-def-red-variables () ...) -- active declareFunction, no body
;; (defun red-utilities-initialization () ...) -- active declareFunction, no body

(defun register-red (red-sym)
  (let ((red-sym-q (gethash (red-symbol-name red-sym) *red-variables-dictionary*)))
    (if red-sym-q
        (progn
          (setf (red-symbol-default-value red-sym-q) (red-symbol-default-value red-sym))
          (unless (equal (red-symbol-red-key red-sym-q) (red-symbol-red-key red-sym))
            (let* ((oldkey (red-symbol-red-key red-sym-q))
                   (newkey (red-symbol-red-key red-sym))
                   (oldkeydictentry (gethash oldkey *red-keys-dictionary*))
                   (newkeydictentry (gethash newkey *red-keys-dictionary*))
                   (newlist nil))
              (dolist (elt oldkeydictentry)
                (unless (eq elt red-sym-q)
                  (setf newlist (cons elt newlist))))
              (if newlist
                  (setf (gethash oldkey *red-keys-dictionary*) newlist)
                  (remhash oldkey *red-keys-dictionary*))
              (setf (red-symbol-red-key red-sym-q) newkey)
              (if newkeydictentry
                  (setf newkeydictentry (cons red-sym-q newkeydictentry))
                  (setf newkeydictentry (list red-sym-q)))
              (setf (gethash newkey *red-keys-dictionary*) newkeydictentry)))
          nil)
        (progn
          (setf *red-symbols-list* (cons red-sym *red-symbols-list*))
          (setf (gethash (red-symbol-name red-sym) *red-variables-dictionary*) red-sym)
          (let* ((newkey (red-symbol-red-key red-sym))
                 (newkeydictentry (gethash newkey *red-keys-dictionary*)))
            (if newkeydictentry
                (setf newkeydictentry (cons red-sym newkeydictentry))
                (setf newkeydictentry (list red-sym)))
            (setf (gethash newkey *red-keys-dictionary*) newkeydictentry))
          red-sym))))

;; (defun red-conditional-set (red-sym) ...) -- active declareFunction, no body
;; (defun red-ordered-var-list () ...) -- active declareFunction, no body
;; (defun def-red-should-be-set (red-sym) ...) -- active declareFunction, no body

(defun red-value (red-sym)
  (red-symbol-default-value red-sym))

;; (defun red-make-list (red-sym) ...) -- active declareFunction, no body
;; (defun red-get-relative-key (red-key) ...) -- active declareFunction, no body
;; (defun redu-translate-to-key (obj) ...) -- active declareFunction, no body
;; (defun red-reload-repository (red-key moniker) ...) -- active declareFunction, no body
;; (defun red-update-def-red-from-repository (red-sym) ...) -- active declareFunction, no body
;; (defun red-execute-callbacks (moniker red-key) ...) -- active declareFunction, no body

;;; Macros

;; Reconstructed from Internal Constants:
;; $list46 = (MONIKER FUNCSPEC) -- arglist
;; $sym47$PROGN, $sym48$CHECK_TYPE, $list49 = (KEYWORDP), $list50 = (FUNCTION-SPEC-P)
;; $sym51$CLET, $sym52$MONIKER_FUN_LIST, $sym53$DICTIONARY_LOOKUP
;; $sym54$PIF, $sym55$CPUSH, $list56 = (MONIKER-FUN-LIST)
;; $sym57$CSETQ, $sym58$LIST
;; $list59 = ((DICTIONARY-ENTER *RED-RELOAD-CALLBACK-MONIKER-DICTIONARY* MONIKER MONIKER-FUN-LIST))
(defmacro red-repository-register-reload-callback (moniker funcspec)
  `(progn
     (check-type ,moniker 'keywordp)
     (check-type ,funcspec 'function-spec-p)
     (clet ((moniker-fun-list (gethash ,moniker *red-reload-callback-moniker-dictionary*)))
       (pif moniker-fun-list
            (cpush ,funcspec moniker-fun-list)
            (csetq moniker-fun-list (list ,funcspec)))
       (setf (gethash ,moniker *red-reload-callback-moniker-dictionary*) moniker-fun-list))))

;; TODO reconstruct body -- only partial evidence
;; Internal Constants: $list46 = (MONIKER FUNCSPEC) arglist,
;; $sym60$FUNCTION_SPEC_P, $list61 = (PROGN) with nothing inside.
;; Likely a (progn (check-type moniker keywordp) (check-type funcspec function-spec-p) <remove from dictionary>),
;; but the dictionary-remove symbol is not present among the orphan constants,
;; so the removal body cannot be reliably reconstructed.
(defmacro red-repository-unregister-reload-callback (moniker funcspec)
  (declare (ignore moniker funcspec))
  ;; TODO - stripped, see evidence comment above
  '(progn))

;; Reconstructed from Internal Constants:
;; $list62 = (NAME ARGLIST MONIKERS &BODY BODY) -- arglist
;; $str63 = "RED reload callback ~A has an invalid arglist of:~%  ~S~%Use DEFINE instead."
;; $sym64$DEFINE, $sym65$CDOLIST, $sym66$MONIKER,
;; $sym67$RED_REPOSITORY_REGISTER_RELOAD_CALLBACK, $sym68$QUOTE
(defmacro red-reload-callback-define (name arglist monikers &body body)
  (if arglist
      (error "RED reload callback ~A has an invalid arglist of:~%  ~S~%Use DEFINE instead." name arglist)
      `(progn
         (define ,name ,arglist ,@body)
         (cdolist (moniker ',monikers)
           (red-repository-register-reload-callback moniker ',name)))))

;;; Setup phase

(toplevel
  (declare-defglobal '*red-variables-dictionary*)
  (declare-defglobal '*red-symbols-list*)
  (declare-defglobal '*red-keys-dictionary*)
  (declare-defglobal '*red-reload-callback-moniker-dictionary*)
  (declare-defglobal '*repositories-loaded*))
