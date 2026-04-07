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

;; Method table for type-based dispatch of encapsulation.
;; In SubL this was a 256-element vector indexed by integer type codes.
;; In the CL port, encapsulate dispatches via typecase instead.
;;(deflexical *encapsulate-method-table* (make-array '(256) :initial-element nil))

(defparameter *unencapsulate-believe-names* nil
  "[Cyc] Do we believe the names when the ids fail to match?")

(deflexical *unencapsulated-common-symbols*
    '((monotonic :monotonic)
      (default :default)
      (forward :forward)
      (backward :backward)
      (code :code)))

(defparameter *unencapsulate-constant-via-name-optimization?* nil)

(defglobal *unencapsulate-find-constant-lookaside-table* nil)

(deflexical *unencapsulate-find-constant-capacity* 20)

;;; Functions -- ordered per declare_encapsulation_file

;; TODO - can this be a generic function?
(defun encapsulate (object)
  "[Cyc] Encapsulate OBJECT for transport. Dispatches by type: conses are recursively
encapsulated, constants and NARTs are encapsulated to portable representations."
  ;; In SubL, method_func dispatched on the object's type tag in *encapsulate-method-table*.
  ;; In CL, we use typecase for the same dispatch.
  (typecase object
    (cons (encapsulate-cons-method object))
    (constant (encapsulate-constant-method object))
    (nart (encapsulate-nart-method object))
    (t object)))

(defun encapsulate-cons-method (object)
  "[Cyc] Encapsulation method for cons cells. Recursively encapsulates CAR and CDR."
  (recons (encapsulate (car object))
          (encapsulate (cdr object))
          object))

(defun encapsulate-constant-method (object)
  "[Cyc] Encapsulation method for constants."
  (encapsulate-constant object))

(defun encapsulate-nart-method (object)
  "[Cyc] Encapsulation method for NARTs."
  ;; missing-larkc 30834 -- likely called encapsulate-nart on the object
  (missing-larkc 30834))

(defun encapsulate-constant (constant)
  "[Cyc] Encapsulate a constant for transport. Validates the constant has a valid
external ID and name before encapsulating."
  (must (valid-constant? constant)
        "Attempt to encapsulate invalid constant ~S." constant)
  (let ((external-id (constant-external-id constant)))
    (must (constant-external-id-p external-id)
          "Attempt to encapsulate a constant ~S with an invalid external ID." constant))
  (let ((name (constant-name constant)))
    (when (not (eq :unnamed name))
      (must (stringp name)
            "Attempt to encapsulate a constant ~S with a non-string name ~S." constant name)))
  (encapsulate-constant-internal constant))

;; (defun encapsulate-nart (nart) ...) -- active declareFunction, no body

(defun encapsulate-constant-internal (constant)
  "[Cyc] Create the portable encapsulated representation of a constant."
  (let ((external-id (constant-external-id constant))
        (name (constant-name constant)))
    (list :hp name external-id)))

;; (defun encapsulate-nart-internal (nart) ...) -- active declareFunction, no body
;; (defun unencapsulate (object) ...) -- active declareFunction, no body
;; (defun unencapsulate-partial (object) ...) -- active declareFunction, no body
;; (defun unencapsulate-internal (object full?) ...) -- active declareFunction, no body
;; (defun unencapsulate-token-equal-p (token1 token2) ...) -- active declareFunction, no body
;; (defun unencapsulate-common-symbol (object) ...) -- active declareFunction, no body
;; (defun unencapsulate-cons (object full?) ...) -- active declareFunction, no body
;; (defun unencapsulate-constant-marker (object full?) ...) -- active declareFunction, no body
;; (defun unencapsulate-constant-marker-int (object full?) ...) -- active declareFunction, no body
;; (defun unencapsulate-find-constant (object) ...) -- active declareFunction, no body
;; (defun unencapsulate-nart-marker (object full?) ...) -- active declareFunction, no body
;; (defun handle-unencapsulate-constant-problem (constant v-encapsulation) ...) -- active declareFunction, no body
;; (defun handle-unencapsulate-unnamed-constant-problem (constant v-encapsulation) ...) -- active declareFunction, no body
;; (defun handle-unencapsulate-nart-problem (nart v-encapsulation) ...) -- active declareFunction, no body
;; (defun handle-unencapsulation-error (object) ...) -- active declareFunction, no body

;;; Setup phase

;; unused in CL port
;;(declare-defglobal '*unencapsulate-find-constant-lookaside-table*)

;; Internal Constants accounting:
;;   $int0$256 -- used in init: method table size
;;   $sym1$ENCAPSULATE_CONS_METHOD -- used in setup: register_method for cons
;;   $sym2$ENCAPSULATE_CONSTANT_METHOD -- used in setup: register_method for constant
;;   $sym3$ENCAPSULATE_NART_METHOD -- used in setup: register_method for nart
;;   $str4 -- used in encapsulate-constant body
;;   $str5 -- used in encapsulate-constant body
;;   $kw6$UNNAMED -- used in encapsulate-constant body
;;   $str7 -- used in encapsulate-constant body
;;   $str8$Attempt_to_encapsulate_the_NART__ -- orphan: used in missing encapsulate-nart body
;;   $kw9$HP -- used in encapsulate-constant-internal body
;;   $kw10$NAT -- orphan: used in missing encapsulate-nart-internal body (the :NAT marker for NART encapsulations)
;;   $list11 -- used in init: *unencapsulated-common-symbols* value
;;   $list12 = (HP NAME-SPEC EXTERNAL-ID) -- orphan: destructuring pattern for unencapsulate-constant-marker
;;   $sym13 -- used in init (boundp guard) and setup (declare-defglobal)
;;   $list14 = (NAT NART-HL-FORMULA-SPEC &OPTIONAL ID) -- orphan: destructuring pattern for unencapsulate-nart-marker
;;   $kw15$IGNORE -- orphan: used in missing unencapsulate functions
;;   $str16 = "~%Last operation: ~S ~%This object did not yield a term: ~S" -- orphan: from handle-unencapsulation-error
;;   $str17 = "Skip this operation" -- orphan: cerror restart string from handle-unencapsulation-error
;;   $str18 = "~S did not yield a term" -- orphan: error message from handle-unencapsulation-error
;;   $kw19$UNENCAPSULATION_ERROR -- orphan: keyword tag from handle-unencapsulation-error
