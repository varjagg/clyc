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

;; WFF module data structure and store.
;; A wff-module has a name and a property list (plist).
;; print-object is missing-larkc 31864 — CL's default print-object handles this.

(defstruct (wff-module (:conc-name "WFF-MOD-")
                       (:constructor make-wff-module (&key name plist)))
  name
  plist)

;; (defun print-wff-module (object stream depth) ...) -- active declareFunction, no body

(defun new-wff-module (name plist)
  "[Cyc] @return wff-module-p; a new WFF module with NAME and properties PLIST"
  (declare (type list plist))
  (let ((wff-module (allocate-wff-module name)))
    (setf (wff-mod-plist wff-module) plist)
    (add-wff-module wff-module)
    wff-module))

(defun allocate-wff-module (name)
  (let ((wff-module (find-wff-module-by-name name)))
    (if wff-module
        ;; missing-larkc 31865 -- likely warns that a module with this name
        ;; already exists, then reuses it (since we fall through to reset plist)
        (missing-larkc 31865)
        (progn
          (setf wff-module (make-wff-module))
          (setf (wff-mod-name wff-module) name)))
    (setf (wff-mod-plist wff-module) nil)
    wff-module))

;; (defun destroy-wff-module (wff-module) ...) -- active declareFunction, no body in LarKC

(defun wff-module-name (wff-module)
  (declare (type wff-module wff-module))
  (wff-mod-name wff-module))

(defun wff-module-plist (wff-module)
  (declare (type wff-module wff-module))
  (wff-mod-plist wff-module))

(defun wff-module-property (wff-module property &optional default)
  (declare (type wff-module wff-module))
  (let ((plist (wff-module-plist wff-module)))
    (getf plist property default)))

(defmacro do-wff-modules ((wff-module-var &key done) &body body)
  (with-temp-vars (name-var)
    `(block nil
       (maphash (lambda (,name-var ,wff-module-var)
                  (declare (ignore ,name-var))
                  ,@(when done
                      `((when ,done (return))))
                  ,@body)
                *wff-module-store*))))

(defun find-wff-module-by-name (name)
  (gethash name *wff-module-store*))

(defun add-wff-module (wff-module)
  (declare (type wff-module wff-module))
  (let ((name (wff-module-name wff-module)))
    (setf (gethash name *wff-module-store*) wff-module))
  wff-module)

;; (defun remove-wff-module (wff-module) ...) -- active declareFunction, no body in LarKC

(defun setup-wff-module (name type plist)
  (let ((new-plist (copy-list plist)))
    (setf new-plist (putf plist :module-type type))
    (let ((wff-module (new-wff-module name new-plist)))
      wff-module)))

;; Reconstructed: no body in LarKC, but setup-wff-module stores :module-type
;; in the plist, so this accessor must retrieve it
(defun wff-module-type (wff-module)
  (wff-module-property wff-module :module-type))

;; (defun wff-violation-type-p (type) ...) -- active declareFunction, no body in LarKC
;; (defun wff-violation-p (object) ...) -- active declareFunction, no body in LarKC
;; (defun wff-module-property-p (property wff-module) ...) -- active declareFunction, no body in LarKC
;; (defun wff-module-property-list-p (plist) ...) -- active declareFunction, no body in LarKC

(defun wff-violation-module (name plist)
  "[Cyc] Declare and wff module named NAME with properties in PLIST."
  (let ((wff-module (setup-wff-module name :violation plist)))
    wff-module))

(defun wff-violation-explanation-function (wff-violation-name)
  (wff-module-property (find-wff-module-by-name wff-violation-name) :explain-func nil))

(defun wff-violation-explanation-function-args (wff-violation-name)
  (wff-module-property (find-wff-module-by-name wff-violation-name) :explain-args nil))

;; Variables

(defconstant *dtp-wff-module* 'wff-module)

(defglobal *wff-module-store* (make-hash-table :test #'equal :size 212)
  "[Cyc] An index mapping WFF module names to modules themselves")

(deflexical *wff-module-properties*
  (list (cons :explain-func 'symbolp)
        (cons :comment 'stringp)))

;; Setup

;; wff-module-store was a macro helper for do-wff-modules in Java, but has no
;; callers outside this file and no body in LarKC.  Elided; the macro references
;; *wff-module-store* directly.
