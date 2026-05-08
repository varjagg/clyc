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

;; ACTION-TYPE struct — 4 slots
;; print-object is missing-larkc 29497 — CL's default print-object handles this.
(defstruct action-type
  key
  summary-fn
  display-fn
  handler-fn)

(defconstant *dtp-action-type* 'action-type)

;; action-type-p is provided by defstruct
;; action-type-key is provided by defstruct
;; action-type-summary-fn is provided by defstruct
;; action-type-display-fn is provided by defstruct
;; action-type-handler-fn is provided by defstruct
;; _csetf-action-type-key is setf of action-type-key
;; _csetf-action-type-summary-fn is setf of action-type-summary-fn
;; _csetf-action-type-display-fn is setf of action-type-display-fn
;; _csetf-action-type-handler-fn is setf of action-type-handler-fn
;; make-action-type is provided by defstruct

;; (defun print-action-type (object stream depth) ...) -- active declareFunction, no body

;; defaction-type — active declareMacro
;; Reconstructed from Internal Constants evidence:
;; $list26 = (NAME &REST ARGLIST) — the macro arglist
;; $sym28$CLET, $sym29$MAKE_ACTION_TYPE, $sym30$QUOTE, $sym31$CSETF,
;; $sym32$SETHASH, $sym33$_ACTION_TYPES_BY_KEY_ — operators in expansion
;; The macro creates a new action-type, sets its key to NAME, and registers
;; it in *action-types-by-key*.
(defmacro defaction-type (name &rest arglist)
  "[Cyc] Define a new action type NAME with ARGLIST properties."
  (let ((new-action-type (gensym "NEW-ACTION-TYPE")))
    `(let ((,new-action-type (make-action-type)))
       (setf (action-type-key ,new-action-type) ',name)
       ,@(loop for (key val) on arglist by #'cddr
               collect `(setf (,(case key
                                  (:summary-fn 'action-type-summary-fn)
                                  (:display-fn 'action-type-display-fn)
                                  (:handler-fn 'action-type-handler-fn)
                                  (otherwise (error "Unknown action-type slot ~S" key)))
                               ,new-action-type)
                              ,val))
       (setf (gethash ',name *action-types-by-key*) ,new-action-type)
       ,new-action-type)))

(defparameter *action-types-by-key* (make-hash-table :test #'eql :size 64)
  "[Cyc] A hash to find a user action from its key.")

;; action-type-by-key (key) — active declareFunction, no body
;; (defun action-type-by-key (key) ...) -- active declareFunction, no body

;; USER-ACTION struct — 5 slots
;; print-object is missing-larkc 29498 — CL's default print-object handles this.
(defstruct user-action
  id-string
  type-key
  cyclist
  creation-time
  data)

(defconstant *dtp-user-action* 'user-action)

;; user-action-p is provided by defstruct
;; user-action-id-string is provided by defstruct
;; user-action-type-key is provided by defstruct
;; user-action-cyclist is provided by defstruct
;; user-action-creation-time is provided by defstruct
;; user-action-data is provided by defstruct
;; _csetf-user-action-id-string is setf of user-action-id-string
;; _csetf-user-action-type-key is setf of user-action-type-key
;; _csetf-user-action-cyclist is setf of user-action-cyclist
;; _csetf-user-action-creation-time is setf of user-action-creation-time
;; _csetf-user-action-data is setf of user-action-data
;; make-user-action is provided by defstruct

(defun print-user-action (object stream depth)
  "[Cyc] Print function for user-action structs."
  (declare (ignore depth))
  (declare (ignore object stream))
  (missing-larkc 29498))

;; user-actions-empty? () — active declareFunction, no body
;; (defun user-actions-empty? () ...) -- active declareFunction, no body

;; user-actions-size () — active declareFunction, no body
;; (defun user-actions-size () ...) -- active declareFunction, no body

;; new-user-action (type-key) — active declareFunction, no body
;; (defun new-user-action (type-key) ...) -- active declareFunction, no body

;; delete-user-action (user-action) — active declareFunction, no body
;; (defun delete-user-action (user-action) ...) -- active declareFunction, no body

;; user-action-by-id-string (id-string) — active declareFunction, no body
;; (defun user-action-by-id-string (id-string) ...) -- active declareFunction, no body

;; user-action-type (user-action) — active declareFunction, no body
;; (defun user-action-type (user-action) ...) -- active declareFunction, no body

;; user-action-summary-fn (user-action) — active declareFunction, no body
;; NOTE: name conflicts with defstruct accessor for action-type-summary-fn,
;; but this is on user-action, not action-type. The Java declare name is
;; USER-ACTION-SUMMARY-FN which gets the summary-fn via user-action's type.
;; (defun user-action-summary-fn-lookup (user-action) ...) -- active declareFunction, no body

;; user-action-display-fn (user-action) — active declareFunction, no body
;; (defun user-action-display-fn-lookup (user-action) ...) -- active declareFunction, no body

;; user-action-handler-fn (user-action) — active declareFunction, no body
;; (defun user-action-handler-fn-lookup (user-action) ...) -- active declareFunction, no body

;; all-actions-for-cyclist (cyclist) — active declareFunction, no body
;; (defun all-actions-for-cyclist (cyclist) ...) -- active declareFunction, no body

;; all-actions-for-cyclist-of-type (cyclist type-key) — active declareFunction, no body
;; (defun all-actions-for-cyclist-of-type (cyclist type-key) ...) -- active declareFunction, no body

(deflexical *user-actions-lock* (bt:make-lock "User Actions Lock")
  "[Cyc] A lock of the user-action structures to prevent clobbering.")

(defparameter *user-actions* nil
  "[Cyc] All the user actions that have been defined.")

(defparameter *user-actions-by-id-string* (make-hash-table :test #'equal :size 64)
  "[Cyc] A hash to find a user action from its id-string.")
