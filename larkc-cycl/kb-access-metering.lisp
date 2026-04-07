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

(defglobal *kb-access-metering-enabled?* nil
  "[Cyc] A control variable that gates whether KB access metering is enabled.")

(defparameter *kb-access-metering-domains* nil)

(defparameter *kb-access-metering-table* nil)

;; Reconstructed from Internal Constants:
;; Arglist: $list1 = ((result-var &key (domains ''(:assertion)) options) &body body)
;; Gensyms: $sym7 DOMAINS-VAR, $sym8 OPTIONS-VAR, $sym9 TABLE-VAR
;; Operators: CLET ($sym10), CUNWIND-PROTECT ($sym14), PROGN ($sym15), CSETQ ($sym16)
;; Functions: NEW-KB-ACCESS-METERING-TABLE ($sym11), POSTPROCESS-KB-ACCESS-METERING-TABLE ($sym17)
;; Binds: *KB-ACCESS-METERING-DOMAINS* ($sym12), *KB-ACCESS-METERING-TABLE* ($sym13)
;; No expansion sites found in other Java files; reconstructed from constants alone.
(defmacro with-kb-access-metering ((result-var &key (domains ''(:assertion)) options)
                                   &body body)
  (with-temp-vars (domains-var options-var table-var)
    `(let* ((,domains-var ,domains)
            (,options-var ,options)
            (,table-var (new-kb-access-metering-table ,domains-var ,options-var))
            (*kb-access-metering-domains* ,domains-var)
            (*kb-access-metering-table* ,table-var))
       (unwind-protect
            (progn ,@body)
         (setf ,result-var (postprocess-kb-access-metering-table
                            ,table-var ,domains-var ,options-var))))))

;; (defun eval-with-kb-access-metering (body &optional domains options) ...) -- commented declareFunction, no body
;; (defun new-kb-access-metering-table (domains options) ...) -- commented declareFunction, no body
;; (defun postprocess-kb-access-metering-table (table domains options) ...) -- commented declareFunction, no body
;; (defun possibly-note-kb-access-constant (constant) ...) -- commented declareFunction, no body
;; (defun possibly-note-kb-access-nart (nart) ...) -- commented declareFunction, no body

(defun possibly-note-kb-access-assertion (assertion)
  (when *kb-access-metering-enabled?*
    (when (member-eq? :assertion *kb-access-metering-domains*)
      ;; Likely records this assertion access in the metering table
      (missing-larkc 7966)))
  nil)

;; (defun note-kb-access-assertion (assertion) ...) -- commented declareFunction, no body

;; Reconstructed from Internal Constants:
;; Arglist: $list23 = (node link-node)
;; Test: $list25 = (cand *kb-access-metering-enabled?* (note-kb-access-sbhl?))
;; Operator: PWHEN ($sym24)
;; Body calls: NOTE-KB-ACCESS-SBHL-LINK ($sym26)
;; Helper: NOTE-KB-ACCESS-SBHL? ($sym27) registered for this macro
(defmacro possibly-note-kb-access-sbhl-link (node link-node)
  `(when (and *kb-access-metering-enabled?* (note-kb-access-sbhl?))
     (note-kb-access-sbhl-link ,node ,link-node)))

;; (defun note-kb-access-sbhl? () ...) -- commented declareFunction, no body
;; (defun kb-access-metering-asserted-assertions (table) ...) -- commented declareFunction, no body
;; (defun mean-asserted-assertion-dates (assertions) ...) -- commented declareFunction, no body
;; (defun median-asserted-assertion-dates (assertions) ...) -- commented declareFunction, no body
;; (defun weighted-mean-asserted-assertion-dates (assertions) ...) -- commented declareFunction, no body
;; (defun weighted-median-asserted-assertion-dates (assertions) ...) -- commented declareFunction, no body
;; (defun percent-before-date (assertions date) ...) -- commented declareFunction, no body
;; (defun weighted-percent-before-date (assertions date) ...) -- commented declareFunction, no body
;; (defun print-asserted-assertions-by-date (table &optional stream) ...) -- commented declareFunction, no body

(toplevel
  (declare-defglobal *kb-access-metering-enabled?*)
  (register-macro-helper 'new-kb-access-metering-table 'with-kb-access-metering)
  (register-macro-helper 'postprocess-kb-access-metering-table 'with-kb-access-metering)
  (register-macro-helper 'note-kb-access-sbhl? 'possibly-note-kb-access-sbhl-link))
