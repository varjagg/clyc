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

;; SBHL iterator infrastructure. The sbhl-iterator struct provides a generic
;; iteration protocol (done?/next/finalize) over SBHL search results.
;; Nearly all function bodies are missing from LarKC — only the struct
;; definition, variables, and 3 reconstructed macros survive.

(defparameter *sbhl-iterator-store* nil)
(deflexical *sbhl-iterator-store-max* 10)

(defstruct (sbhl-iterator (:conc-name "SBHL-IT-"))
  state
  done
  next
  finalize)

(defconstant *dtp-sbhl-iterator* 'sbhl-iterator)

;; (defun within-sbhl-iterator-resourcing? ()) -- commented declareFunction, no body

;; Reconstructed from $list1:
;;   (clet ((*sbhl-iterator-store* (fif (within-sbhl-iterator-resourcing?)
;;                                      *sbhl-iterator-store*
;;                                      (new-sbhl-stack *sbhl-iterator-store-max*))))
;;     . body)
;; Depends on: within-sbhl-iterator-resourcing? (commented), new-sbhl-stack (sbhl-search-datastructures, commented)
(defmacro with-sbhl-iterator-resourcing (&body body)
  "Reconstructed from Internal Constants: $list1.
Binds *sbhl-iterator-store* to either the existing store (if already resourcing)
or a new sbhl-stack."
  `(let ((*sbhl-iterator-store* (if (within-sbhl-iterator-resourcing?)
                                    *sbhl-iterator-store*
                                    (new-sbhl-stack *sbhl-iterator-store-max*))))
     ,@body))

;; (defun find-or-create-sbhl-iterator-shell ()) -- commented declareFunction, no body
;; (defun find-sbhl-iterator-shell ()) -- commented declareFunction, no body
;; (defun release-sbhl-iterator (iterator)) -- commented declareFunction, no body

;; (defun sbhl-iterator-p (object)) -- commented declareFunction, provided by defstruct
;; (defun sbhl-it-state (iterator)) -- commented declareFunction, provided by defstruct
;; (defun sbhl-it-done (iterator)) -- commented declareFunction, provided by defstruct
;; (defun sbhl-it-next (iterator)) -- commented declareFunction, provided by defstruct
;; (defun sbhl-it-finalize (iterator)) -- commented declareFunction, provided by defstruct
;; (defun (setf sbhl-it-state) (value iterator)) -- commented declareFunction, provided by defstruct
;; (defun (setf sbhl-it-done) (value iterator)) -- commented declareFunction, provided by defstruct
;; (defun (setf sbhl-it-next) (value iterator)) -- commented declareFunction, provided by defstruct
;; (defun (setf sbhl-it-finalize) (value iterator)) -- commented declareFunction, provided by defstruct
;; (defun make-sbhl-iterator (&optional plist)) -- commented declareFunction, provided by defstruct

;; (defun print-sbhl-iterator (object stream depth)) -- commented declareFunction, no body
;; (defun new-sbhl-iterator (state done next finalize)) -- commented declareFunction, no body
;; (defun sbhl-iteration-done? (iterator)) -- commented declareFunction, no body
;; (defun sbhl-iteration-next (iterator)) -- commented declareFunction, no body
;; (defun sbhl-iteration-finalize (iterator)) -- commented declareFunction, no body

;; Reconstructed from $list52, $sym55-63:
;;   Arglist: ((var sbhl-iterator &key done) &body body)
;;   Uses: UNTIL, COR(=or), NULL, CSETQ(=setf), SBHL-ITERATION-NEXT, PWHEN(=when)
;;   Gensyms: ITERATOR-VAR, DONE-VAR
;;   When :done is provided, that variable is used directly as the loop's
;;   done-flag (both input and output), allowing callers to terminate iteration
;;   early by setting it to T.
(defmacro do-sbhl-iterator ((var sbhl-iterator &key done) &body body)
  "Reconstructed from Internal Constants: $list52, $sym55-63.
Iterates over SBHL-ITERATOR, binding VAR to each result.
When :DONE is provided, that variable serves as the loop control flag —
setting it to T stops iteration."
  (with-temp-vars (iterator-var)
    (let ((done-var (or done (make-temp-var 'done-var))))
      `(let ((,iterator-var ,sbhl-iterator)
             ,@(unless done `((,done-var nil))))
         (until (or ,done-var (sbhl-iteration-done? ,iterator-var))
           (let ((,var (sbhl-iteration-next ,iterator-var)))
             (when (null ,var)
               (setf ,done-var t))
             ,@body))))))

;; Reconstructed from $list64, $sym65-70, $list67, $list71:
;;   Arglist: ((var n sbhl-iterator &key done) &body body)
;;   Uses: DO-SBHL-ITERATOR, PROGN, CINC(=incf), >=
;;   Gensyms: COUNT, NEW-DONE
;;   Iterates at most N items then sets the done-flag to T.
(defmacro do-n-sbhl-iterator-objects ((var n sbhl-iterator &key done) &body body)
  "Reconstructed from Internal Constants: $list64, $sym65-70, $list67, $list71.
Like DO-SBHL-ITERATOR but stops after N objects."
  (with-temp-vars (count)
    (let ((new-done (or done (make-temp-var 'new-done))))
      `(let ((,count 0)
             ,@(unless done `((,new-done nil))))
         (do-sbhl-iterator (,var ,sbhl-iterator :done ,new-done)
           (progn
             ,@body
             (incf ,count))
           (when (>= ,count ,n)
             (setf ,new-done t)))))))

;; (defun new-sbhl-null-iterator ()) -- commented declareFunction, no body
;; (defun sbhl-null-iterator-p (iterator)) -- commented declareFunction, no body
;; (defun new-sbhl-list-iterator (list)) -- commented declareFunction, no body
;; (defun sbhl-list-iterator-done (state)) -- commented declareFunction, no body
;; (defun sbhl-list-iterator-next (state)) -- commented declareFunction, no body
;; (defun new-sbhl-alist-iterator (alist)) -- commented declareFunction, no body
;; (defun sbhl-alist-iterator-done (state)) -- commented declareFunction, no body
;; (defun sbhl-alist-iterator-next (state)) -- commented declareFunction, no body
;; (defun new-sbhl-hash-table-iterator (hash-table)) -- commented declareFunction, no body
;; (defun sbhl-hash-table-iterator-done (state)) -- commented declareFunction, no body
;; (defun sbhl-hash-table-iterator-next (state)) -- commented declareFunction, no body
;; (defun make-sbhl-hash-table-iterator-state (hash-table)) -- commented declareFunction, no body
;; (defun new-sbhl-dictionary-iterator (dictionary)) -- commented declareFunction, no body
;; (defun new-sbhl-iterator-iterator (iterator)) -- commented declareFunction, no body
;; (defun sbhl-iterator-iterator-done (state)) -- commented declareFunction, no body
;; (defun sbhl-iterator-iterator-next (state)) -- commented declareFunction, no body
;; (defun sbhl-iterator-iterator-finalize (state)) -- commented declareFunction, no body

(deflexical *sbhl-null-iterator* nil)
