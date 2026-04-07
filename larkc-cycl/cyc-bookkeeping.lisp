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

;;; Macros (declare section ordering: with-bookkeeping-info, with-assertion-bookkeeping-info,
;;;         possibly-with-bookkeeping-info, without-bookkeeping)

(defmacro with-bookkeeping-info ((bookkeeping-info &body body))
  "[Cyc] Binds *cyc-bookkeeping-info* to BOOKKEEPING-INFO, which must
be a plist.  The cyc-* functions will use this bookkeeping info
if it is bound.  Supported bookkeeping properties for the plist include:
:who      The Cyclist who performed the operation
:when     The universal date on which the operation was performed
:purpose  The #$Cyc-BasedProject for which the operation was performed
:second   The universal second at which the operation was performed"
  `(clet ((*cyc-bookkeeping-info* ,bookkeeping-info))
     ,@body))

;; Reconstructed from Internal Constants evidence:
;;   $list5 = (ASSERTION &BODY BODY) — macro arglist
;;   $sym6$ASSERTION_VAR = makeUninternedSymbol("ASSERTION-VAR") — gensym for assertion binding
;;   $sym23$ASSERTION_P = ASSERTION-P — type check on the assertion
;;   $sym7/$sym8 = *THE-CYCLIST* / ASSERTED-BY — extract cyclist from assertion
;;   $sym9/$sym10 = *THE-DATE* / ASSERTED-WHEN — extract date from assertion
;;   $sym11/$sym12 = *KE-PURPOSE* / ASSERTED-WHY — extract purpose from assertion
;;   $sym13/$sym14 = *THE-SECOND* / ASSERTED-SECOND — extract second from assertion
;; The macro binds special variables from the assertion's bookkeeping fields,
;; then wraps body with with-bookkeeping-info using those values.
(defmacro with-assertion-bookkeeping-info ((assertion &body body))
  (with-temp-vars (assertion-var)
    `(let ((,assertion-var ,assertion))
       (check-type ,assertion-var #'assertion-p)
       (clet ((*cyc-bookkeeping-info*
               (new-bookkeeping-info
                (asserted-by ,assertion-var)
                (asserted-when ,assertion-var)
                (asserted-why ,assertion-var)
                (asserted-second ,assertion-var))))
         ,@body))))

;; Reconstructed from Internal Constants evidence:
;;   $list15 = (NEW-BOOKKEEPING-INFO *THE-CYCLIST* *THE-DATE* *KE-PURPOSE* *THE-SECOND*)
;;     — the bookkeeping-info expression, using current dynamic bindings of cyclist/date/purpose/second
;;   $sym16$PROGN — wraps the expansion
;; The macro creates bookkeeping info from the currently-bound special variables
;; *the-cyclist*, *the-date*, *ke-purpose*, *the-second* and wraps the body.
(defmacro possibly-with-bookkeeping-info ((&body body))
  `(progn
     (with-bookkeeping-info ((new-bookkeeping-info *the-cyclist* *the-date* *ke-purpose* *the-second*))
       ,@body)))

;; Reconstructed from Internal Constants evidence:
;;   $list17 = ((*CYC-BOOKKEEPING-INFO* NIL)) — clet binding list
;; Simply disables bookkeeping by binding *cyc-bookkeeping-info* to NIL.
(defmacro without-bookkeeping ((&body body))
  `(clet ((*cyc-bookkeeping-info* nil))
     ,@body))

;;; Functions (declare section ordering: cyc-bookkeeping-info, do-bookkeeping?,
;;;            new-bookkeeping-info, assertion-bookkeeping-info,
;;;            cyc-bookkeeping-info-for, perform-constant-bookkeeping,
;;;            perform-assertion-bookkeeping)

(defun cyc-bookkeeping-info ()
  "[Cyc] Public accessor for *cyc-bookkeeping-info*"
  *cyc-bookkeeping-info*)

(defun do-bookkeeping? ()
  (and *bookkeeping-enabled?*
       (cyc-bookkeeping-info)))

(defun new-bookkeeping-info (&optional who when why when-sec)
  "[Cyc] Constructs a plist from any or all of the arguments passed in,
suitable for passing to @xref with-bookkeeping-info"
  (let ((plist nil))
    (when when-sec
      (setf plist (nconc (list :second when-sec) plist)))
    (when why
      (setf plist (nconc (list :purpose why) plist)))
    (when when
      (setf plist (nconc (list :when when) plist)))
    (when who
      (setf plist (nconc (list :who who) plist)))
    plist))

;; (defun assertion-bookkeeping-info (assertion) ...) -- active declareFunction, no body

(defun cyc-bookkeeping-info-for (what)
  "[Cyc] Assumes that equality of WHAT can be tested with #'eql."
  (getf (cyc-bookkeeping-info) what))

(defun perform-constant-bookkeeping (constant)
  (declare (ignore constant))
  (when (do-bookkeeping?)
    (let ((who (cyc-bookkeeping-info-for :who))
          (when (cyc-bookkeeping-info-for :when))
          (purpose (cyc-bookkeeping-info-for :purpose))
          (when-sec (cyc-bookkeeping-info-for :second)))
      (fi-timestamp-constant-int who when purpose when-sec))))

(defun perform-assertion-bookkeeping (assertion)
  (declare (ignore assertion))
  (when (do-bookkeeping?)
    (let ((who (cyc-bookkeeping-info-for :who))
          (when (cyc-bookkeeping-info-for :when))
          (purpose (cyc-bookkeeping-info-for :purpose))
          (when-sec (cyc-bookkeeping-info-for :second)))
      (fi-timestamp-assertion-int who when purpose when-sec))))

;;; Variables (init phase)

(defglobal *bookkeeping-enabled?* t
  "[Cyc] If T, bookkeeping information, if any, is considered.
Can be set to nil by applications that don't care about bookkeeping.")

(defparameter *cyc-bookkeeping-info* nil
  "[Cyc] Can be dynamically bound to the right bookkeeping information (a plist).")

;;; Setup phase

(declare-defglobal '*bookkeeping-enabled?*)
(register-external-symbol 'with-bookkeeping-info)
(register-external-symbol 'new-bookkeeping-info)
