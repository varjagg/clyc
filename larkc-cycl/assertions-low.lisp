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

;; Internal Constants orphans (used only in stripped functions):
;;   $int2$148 = 148            -- CFASL opcode for assertion-content structs (dump/load)
;;   $kw25$NOT_FOUND = :not-found -- sentinel value for stripped lookup variants
;;   $str36 = "mapping Cyc assertions" -- progress string in rebuild-rule-set (stripped)
;;   $kw38$SKIP = :skip         -- iteration control in stripped functions
;;   $str40 = "Rebuilding the Rule Set" -- progress string in rebuild-rule-set (stripped)
;;   $sym48$VALID_ARGUMENT      -- used in valid-assertion-robust? (stripped)
;;   $sym54$DEDUCTION_P         -- used in mark-dependent-deduction (stripped)

;; [Clyc] Java uses a SubLStructNative with manual AS-CONTENT-* and _CSETF-AS-CONTENT-*
;; accessors, registered via Structures.def_csetf in the setup phase so that `(setf (as-content-X ...))`
;; works. CL's defstruct generates equivalent readers and setf expanders natively, so the
;; def-csetf calls are unneeded here.
(defstruct (assertion-content (:constructor make-assertion-content
                                            (&key formula-data mt (flags 0) arguments plist))
                              (:conc-name "AS-CONTENT-"))
  formula-data
  mt
  (flags 0 :type (or null fixnum))
  arguments
  plist)


(defconstant *dtp-assertion-content* 'assertion-content)

(defun assertion-content-p (object)
  (typep object 'assertion-content))

(deflexical *default-assertion-flags* 0)

(defun create-assertion-content (mt)
  (make-assertion-content :mt mt :flags *default-assertion-flags*))

(defun destroy-assertion-content (id)
  (let ((assertion-content (lookup-assertion-content id)))
    (when (assertion-content-p assertion-content)
      (deregister-assertion-content id)
      (setf (as-content-formula-data assertion-content) nil)
      (setf (as-content-mt assertion-content) nil)
      (setf (as-content-flags assertion-content) nil)
      (setf (as-content-arguments assertion-content) nil)
      (setf (as-content-plist assertion-content) nil)
      (return-from destroy-assertion-content t)))
  nil)

(defun* lookup-assertion-formula-data (id) (:inline t)
  (let ((contents (lookup-assertion-content id)))
    (when contents (as-content-formula-data contents))))

(defun* lookup-assertion-mt (id) (:inline t)
  (let ((contents (lookup-assertion-content id)))
    (when contents (as-content-mt contents))))

(defun* lookup-assertion-flags (id) (:inline t)
  (let ((contents (lookup-assertion-content id)))
    (when contents (as-content-flags contents))))

(defun* lookup-assertion-arguments (id) (:inline t)
  (let ((contents (lookup-assertion-content id)))
    (when contents (as-content-arguments contents))))

(defun* lookup-assertion-plist (id) (:inline t)
  (let ((contents (lookup-assertion-content id)))
    (when contents (as-content-plist contents))))

(defun* set-assertion-formula-data (id new-formula-data) (:inline t)
  (setf (as-content-formula-data (lookup-assertion-content id)) new-formula-data)
  (mark-assertion-content-as-muted id)
  id)

(defun* set-assertion-flags (id new-flags) (:inline t)
  (setf (as-content-flags (lookup-assertion-content id)) new-flags)
  (mark-assertion-content-as-muted id)
  id)

(defun* set-assertion-arguments (id new-arguments) (:inline t)
  (setf (as-content-arguments (lookup-assertion-content id)) new-arguments)
  (mark-assertion-content-as-muted id)
  id)

(defun* set-assertion-plist (id new-plist) (:inline t)
  (setf (as-content-plist (lookup-assertion-content id)) new-plist)
  (mark-assertion-content-as-muted id)
  id)

;; (defun dump-assertion-content (assertion stream) ...) -- no body
;; (defun bundle-assertion-content-for-dumping (assertion) ...) -- no body
;; (defun bundle-assertion-content (formula-data mt flags arguments plist) ...) -- no body
;; (defun dump-assertion-content-to-fht (id assertion-content &optional table) ...) -- no body
;; (defun dump-assertion-content-bundle-to-fht (id bundle table) ...) -- no body

(defun load-assertion-content (assertion stream)
  ;; Left-to-right parameter evaluation guaranteed by 3.1.2.1.2.3
  (let* ((id (assertion-id assertion))
         (formula-data (cfasl-input stream))
         (mt (cfasl-input stream))
         (flags (cfasl-input stream))
         (v-arguments (cfasl-input stream))
         (plist (cfasl-input stream)))
    (load-assertion-content-int id formula-data mt flags v-arguments plist))
  assertion)

;; (defun load-assertion-content-as-bundle (assertion stream) ...) -- no body
;; (defun load-assertion-content-from-fht (assertion table) ...) -- no body

(defun load-assertion-content-int (id formula-data mt flags v-arguments plist)
  (let ((assertion-content (create-assertion-content mt)))
    (setf (as-content-formula-data assertion-content) formula-data)
    (setf (as-content-flags assertion-content) flags)
    (setf (as-content-arguments assertion-content) v-arguments)
    (setf (as-content-plist assertion-content) plist)
    (register-assertion-content id assertion-content))
  id)

(defun assertion-cnf-internal (assertion)
  (let ((hl-cnf (assertion-hl-cnf assertion)))
    (if (clause-struc-p hl-cnf)
        (clause-struc-cnf hl-cnf)
        hl-cnf)))

(defun possibly-assertion-cnf-internal (assertion)
  (when (valid-assertion-with-content? assertion)
    (assertion-cnf-internal assertion)))

(defun* assertion-mt-internal (assertion) (:inline t)
  (lookup-assertion-mt (assertion-id assertion)))

(defun assertion-gaf-hl-formula-internal (assertion)
  (when (assertion-gaf-p assertion)
    (let ((formula-data (assertion-formula-data assertion)))
      (if (clause-struc-p formula-data)
          (cnf-to-gaf-formula (clause-struc-cnf formula-data))
          formula-data))))

(defun assertion-cons-internal (assertion)
  (if (assertion-gaf-p assertion)
      (assertion-gaf-hl-formula assertion)
      (assertion-cnf-internal assertion)))

(defun assertion-direction-internal (assertion)
  (decode-direction (assertion-flags-direction-code (assertion-flags assertion))))

(defun assertion-truth-internal (assertion)
  (tv-truth (assertion-tv assertion)))

(defun assertion-strength-internal (assertion)
  (tv-strength (assertion-tv assertion)))

(defun assertion-tv (assertion)
  "[Cyc] Return the hl tv of ASSERTION."
  (decode-tv (assertion-flags-tv-code (assertion-flags assertion))))

(defun* assertion-variable-names-internal (assertion) (:inline t)
  "[Cyc] Return the list of names for the variables in ASSERTION."
  (get-assertion-prop assertion :variable-names))

(defun asserted-by-internal (assertion)
  (when (asserted-assertion? assertion)
    (assert-info-who (assertion-assert-info assertion))))

(defun asserted-when-internal (assertion)
  (when (asserted-assertion? assertion)
    (assert-info-when (assertion-assert-info assertion))))

(defun asserted-why-internal (assertion)
  (when (asserted-assertion? assertion)
    (assert-info-why (assertion-assert-info assertion))))

(defun asserted-second-internal (assertion)
  (when (asserted-assertion? assertion)
    (assert-info-second (assertion-assert-info assertion))))

(defun* assertion-arguments-internal (assertion) (:inline t)
  (lookup-assertion-arguments (assertion-id assertion)))

(defun* assertion-dependents-internal (assertion) (:inline t)
  (get-assertion-prop assertion :dependents))

(defun assertion-formula-data (assertion)
  "[Cyc] Return the HL structure used to implement the formula for ASSERTION.
This will either be a clause struc containing a cnf, a cnf, or a gaf formula."
  (lookup-assertion-formula-data (assertion-id assertion)))

(defun reset-assertion-formula-data (assertion new-formula-data)
  "[Cyc] Primitively sets the HL structure used to implement the formula for ASSERTION.
This should either be a clause struc containing a cnf, a cnf, or a gaf formula."
  (declare (type assertion assertion))
  (set-assertion-formula-data (assertion-id assertion) new-formula-data)
  assertion)

(defun assertion-hl-cnf (assertion)
  "[Cyc] Return the HL structure used to implement the CNF clause for ASSERTION.
This will either be a clause struc containing a cnf, or a cnf.
gaf formulas are expanded into CNFs."
  (declare (type assertion assertion))
  (let ((formula-data (assertion-formula-data assertion)))
    (cond
      ((clause-struc-p formula-data) formula-data)
      ((not formula-data)            formula-data)
      ((not (assertion-gaf-p assertion)) formula-data)
      (t (gaf-formula-to-cnf formula-data)))))

(defun update-assertion-formula-data (assertion new-formula-data)
  "[Cyc] Primitively change the formula data of ASSERTION to NEW-FORMULA-DATA,
and update the GAF flag. Assumes that NEW-FORMULA-DATA is either a CNF clause,
a gaf formula, a clause-struc, or NIL."
  (cond
    ((clause-struc-p new-formula-data) (missing-larkc 32000))
    ((not new-formula-data) (annihilate-assertion-formula-data assertion))
    ((cnf-p new-formula-data) (reset-assertion-cnf assertion new-formula-data))
    ((el-formula-p new-formula-data) (reset-assertion-gaf-formula assertion new-formula-data))
    (t (error "Unexpected formula-data type: ~S" new-formula-data)
       (return-from update-assertion-formula-data nil)))
  assertion)

(defun assertion-clause-struc (assertion)
  "[Cyc] If ASSERTION has a clause struc as its HL CNF implementation, return it.
Otherwise, return NIL."
  (let ((formula-data (assertion-formula-data assertion)))
    (when (clause-struc-p formula-data)
      formula-data)))

(defun reset-assertion-cnf (assertion new-cnf)
  "[Cyc] Primitively change the formula data of ASSERTION to NEW-CNF,
and update the GAF flag. Shrinks NEW-CNF to a gaf formula if possible."
  (let ((gaf? (determine-cnf-gaf-p new-cnf)))
    (reset-assertion-formula-data assertion
                                  (if gaf?
                                      (cnf-to-gaf-formula new-cnf)
                                      new-cnf))
    (set-assertion-gaf-p assertion gaf?)
    assertion))

;; (defun reset-assertion-clause-struc (assertion new-clause-struc) ...) -- no body

(defun reset-assertion-gaf-formula (assertion new-gaf-formula)
  "[Cyc] Primitively change the formula data of ASSERTION to NEW-GAF-FORMULA,
and set the GAF flag to t. Assumes that NEW-GAF-FORMULA is a valid gaf formula."
  (reset-assertion-formula-data assertion new-gaf-formula)
  (set-assertion-gaf-p assertion t)
  assertion)

(defun annihilate-assertion-formula-data (assertion)
  "[Cyc] Primitively change the formula data of ASSERTION to nil,
and update the GAF flag to t (why not?)"
  (reset-assertion-formula-data assertion nil)
  (set-assertion-gaf-p assertion t)
  assertion)

(defun* assertion-flags (assertion) (:inline t)
  "[Cyc] Return the bit-flags for ASSERTION."
  (lookup-assertion-flags (assertion-id assertion)))

(defun reset-assertion-flags (assertion new-flags)
  (declare (type assertion assertion))
  (let ((flags (assertion-flags assertion)))
    (unless (eql flags new-flags)
      (set-assertion-flags (assertion-id assertion) new-flags)))
  assertion)

(defconstant *assertion-flags-gaf-byte* (byte 1 0))

;; (defun assertion-flags-gaf-code (flags) ...) -- no body

(defun* set-assertion-flags-gaf-code (flags code) (:inline t)
  (dpb code *assertion-flags-gaf-byte* flags))

(defconstant *assertion-flags-direction-byte* (byte 2 1))

(defun* assertion-flags-direction-code (flags) (:inline t)
  (ldb *assertion-flags-direction-byte* flags))

(defun* set-assertion-flags-direction-code (flags code) (:inline t)
  (dpb code *assertion-flags-direction-byte* flags))

(defconstant *assertion-flags-tv-byte* (byte 3 3))

(defun* assertion-flags-tv-code (flags) (:inline t)
  (ldb *assertion-flags-tv-byte* flags))

(defun* set-assertion-flags-tv-code (flags code) (:inline t)
  (dpb code *assertion-flags-tv-byte* flags))

(defun* assertion-flags-gaf-p (assertion) (:inline t)
  "[Cyc] Return T iff ASSERTION is a GAF according to its internal flag bits."
  (oddp (assertion-flags assertion)))

(defun set-assertion-flags-gaf-p (assertion gaf?)
  "[Cyc] Primitively set the gaf flag of ASSERTION."
  (let ((gaf-code (encode-boolean gaf?)))
    (when gaf-code
      (reset-assertion-flags assertion
                             (set-assertion-flags-gaf-code (assertion-flags assertion)
                                                           gaf-code))))
  assertion)

(deflexical *rule-set* nil
    "[Cyc] When non-NIL, a cache of all the rule assertions in the KB.")

(deflexical *prefer-rule-set-over-flags?* nil
    "[Cyc] When non-NIL, the rule-set cache is used to compute GAF vs Rule rather than
using the bit in the flags.")

(deflexical *estimated-assertions-per-rule* 60)

(defun setup-rule-set (estimated-assertion-size)
  (declare (type (integer 0) estimated-assertion-size))
  (let ((estimated-rule-count (ceiling (/ estimated-assertion-size
                                          *estimated-assertions-per-rule*))))
    (setf *rule-set* (new-set #'eq estimated-rule-count))
    t))

;; (defun kb-rule-set () ...) -- no body; registered as macro helper for do-rules

(defun assertion-gaf-p (assertion)
  (if (and *prefer-rule-set-over-flags?* *rule-set*)
      (not (set-member? assertion *rule-set*))
      (assertion-flags-gaf-p assertion)))

;; (defun assertion-rule-p (assertion) ...) -- no body
;; (defun rule-count () ...) -- no body
;; (defun gaf-count () ...) -- no body

(defun set-assertion-gaf-p (assertion gaf?)
  "[Cyc] Primitively set the gaf flag of ASSERTION."
  (when *rule-set*
    (if gaf?
        (set-remove assertion *rule-set*)
        (set-add assertion *rule-set*)))
  (set-assertion-flags-gaf-p assertion gaf?))

;; (defun possibly-rule-set-delete (assertion) ...) -- no body
;; (defun recompute-assertion-gaf-p (assertion) ...) -- no body

(defun* determine-cnf-gaf-p (cnf) (:inline t)
  "[Cyc] Return the recomputed value for the gaf flag of ASSERTION."
  (gaf-cnf? cnf))

;; (defun dump-rule-set-to-stream (stream) ...) -- no body

(defun load-rule-set-from-stream (stream)
  (setf *rule-set* (cfasl-input stream))
  (set-size *rule-set*))

;; (defun rebuild-rule-set () ...) -- no body

(defun* gaf-formula-to-cnf (gaf) (:inline t)
  "[Cyc] Converts a gaf formula to a CNF clause."
  (make-gaf-cnf gaf))

(defun* cnf-to-gaf-formula (cnf) (:inline t)
  "[Cyc] Converts a CNF representation of a gaf formula to a gaf formula."
  (gaf-cnf-literal cnf))

(defun kb-set-assertion-direction-internal (assertion new-direction)
  (if (gaf-assertion? assertion)
      (reset-assertion-direction assertion new-direction)
      (progn
        (remove-assertion-indices assertion)
        (reset-assertion-direction assertion new-direction)
        (add-assertion-indices assertion)))
  assertion)

(defun reset-assertion-direction (assertion new-direction)
  "[Cyc] Primitively change direction of ASSERTION to NEW-DIRECTION."
  (declare (type assertion assertion))
  (let ((direction-code (encode-direction new-direction)))
    (when direction-code
      (reset-assertion-flags assertion
                             (set-assertion-flags-direction-code (assertion-flags assertion)
                                                                 direction-code))))
  assertion)

(defun reset-assertion-tv (assertion new-tv)
  "[Cyc] Primitively change the hl tv of ASSERTION to NEW-TV."
  (declare (type assertion assertion))
  (let ((tv-code (encode-tv new-tv)))
    (when tv-code
      (reset-assertion-flags assertion
                             (set-assertion-flags-tv-code (assertion-flags assertion) tv-code))))
  assertion)

(defun reset-assertion-truth (assertion new-truth)
  (let* ((existing-strength (assertion-strength assertion))
         (new-tv (tv-from-truth-strength new-truth existing-strength)))
    (reset-assertion-tv assertion new-tv)))

(defun reset-assertion-strength (assertion new-strength)
  (let* ((existing-truth (assertion-truth assertion))
         (new-tv (tv-from-truth-strength existing-truth new-strength)))
    (reset-assertion-tv assertion new-tv)))

(defun assertion-plist (assertion)
  "[Cyc] Return the plist for ASSERTION."
  (lookup-assertion-plist (assertion-id assertion)))

(defun* reset-assertion-plist (assertion plist) (:inline t)
  "[Cyc] Primitively set the plist of ASSERTION to PLIST."
  (declare (type assertion assertion))
  (declare (type list plist))
  (set-assertion-plist (assertion-id assertion) plist)
  assertion)

(defun* get-assertion-prop (assertion indicator &optional default) (:inline t)
  (getf (assertion-plist assertion) indicator default))

(defun set-assertion-prop (assertion indicator value)
  (reset-assertion-plist assertion (putf (assertion-plist assertion) indicator value))
  assertion)

(defun rem-assertion-prop (assertion indicator)
  (let ((old-plist (assertion-plist assertion)))
    (reset-assertion-plist assertion (remf old-plist indicator)))
  assertion)

(defun reset-assertion-variable-names (assertion new-variable-names)
  "[Cyc] Primitively change the variable names for ASSERTION to NEW-VARIABLE-NAMES."
  (declare (type assertion assertion))
  (declare (type list new-variable-names))
  (dolist (elem new-variable-names)
    (declare (type string elem)))
  (if new-variable-names
      (set-assertion-prop assertion :variable-names new-variable-names)
      (rem-assertion-prop assertion :variable-names))
  assertion)

(defun* assertion-index (assertion) (:inline t)
  "[Cyc] Return the indexing structure for ASSERTION."
  (assertion-indexing-store-get assertion))

(defun reset-assertion-index (assertion new-index)
  "[Cyc] Primitively change the indexing structure for ASSERTION to NEW-INDEX."
  (declare (type assertion assertion))
  (if (eq new-index (new-simple-index))
      (missing-larkc 31913)
      (assertion-indexing-store-set assertion new-index))
  assertion)

;; (defun clear-assertion-index (assertion) ...) -- no body

(defmacro destructure-assert-info ((who when why second) assert-info &body body)
  `(destructuring-bind (&optional ,who ,when ,why ,second) ,assert-info
     ,@body))

(defun* assertion-assert-info (assertion) (:inline t)
  "[Cyc] Return the assert timestamping info for ASSERTION."
  (get-assertion-prop assertion :assert-info))

(defun reset-assertion-assert-info (assertion new-info)
  "[Cyc] Primitively change the assert timestamping info for ASSERTION to NEW-INFO."
  (declare (type assertion assertion))
  (if new-info
      (set-assertion-prop assertion :assert-info new-info)
      (rem-assertion-prop assertion :assert-info))
  assertion)

(defun asserted-assertion-timestamped? (assertion)
  (declare (type assertion assertion))
  (when (asserted-assertion? assertion)
    (if (assertion-assert-info assertion) t nil)))

;; assert-info is a plain list; use a (:type list) struct for free accessors
(defstruct (assert-info (:type list)
                        (:constructor make-assert-info (&optional who when why second)))
  who
  when
  why
  second)

(defun set-assertion-asserted-by (assertion assertor)
  (destructure-assert-info (who when why second) (assertion-assert-info assertion)
    (setf who assertor)
    (reset-assertion-assert-info assertion (make-assert-info who when why second))))

(defun set-assertion-asserted-when (assertion universal-date)
  (destructure-assert-info (who when why second) (assertion-assert-info assertion)
    (setf when universal-date)
    (reset-assertion-assert-info assertion (make-assert-info who when why second))))

(defun set-assertion-asserted-why (assertion reason)
  (destructure-assert-info (who when why second) (assertion-assert-info assertion)
    (setf why reason)
    (reset-assertion-assert-info assertion (make-assert-info who when why second))))

(defun set-assertion-asserted-second (assertion universal-second)
  (destructure-assert-info (who when why second) (assertion-assert-info assertion)
    (setf second universal-second)
    (reset-assertion-assert-info assertion (make-assert-info who when why second))))

;; (defun valid-assertion-robust? (assertion) ...) -- no body

(defun valid-assertion-with-content? (assertion)
  "[Cyc] Does ASSERTION have content?"
  (let* ((id (assertion-id assertion))
         (content (ignore-errors (lookup-assertion-content id))))
    (if content t nil)))

(defun kb-create-assertion-kb-store (cnf mt)
  (let ((assertion (find-assertion-internal cnf mt)))
    (if assertion
        (assertion-id assertion)
        (let* ((internal-id (make-assertion-id))
               (shell-assertion (make-assertion-shell internal-id)))
          (kb-create-assertion-int shell-assertion internal-id cnf mt)
          internal-id))))

(defun kb-create-assertion-int (assertion internal-id cnf mt)
  (let ((assertion-content (create-assertion-content mt)))
    (register-assertion-content internal-id assertion-content)
    (reset-assertion-tv assertion :unknown)
    (let ((formula-data-hook (find-cnf-formula-data-hook cnf)))
      (connect-assertion assertion formula-data-hook)
      nil)))

;; (defun kb-create-assertion-cyc (assertion) ...) -- no body

(defun find-cnf-formula-data-hook (cnf)
  (if (gaf-cnf? cnf)
      (find-gaf-formula-hook (gaf-cnf-literal cnf))
      (find-hl-cnf-hook cnf)))

(defun find-hl-cnf-hook (cnf)
  (let ((assertion (find-assertion-any-mt cnf)))
    (if assertion
        (or (assertion-clause-struc assertion) assertion)
        cnf)))

(defun find-gaf-formula-hook (gaf)
  (let ((assertion (find-gaf-any-mt gaf)))
    (if assertion
        (or (assertion-clause-struc assertion) assertion)
        gaf)))

(defun connect-assertion (assertion formula-data-hook)
  "[Cyc] Connect ASSERTION to FORMULA-DATA-HOOK and all its relevant indexes."
  (connect-assertion-formula-data assertion formula-data-hook)
  (add-assertion-indices assertion)
  assertion)

(defun connect-assertion-formula-data (assertion formula-data-hook)
  (let ((formula-data formula-data-hook))
    (cond
      ((clause-struc-p formula-data-hook)
       (missing-larkc 11315))
      ((assertion-p formula-data-hook)
       (let* ((cnf (assertion-cnf formula-data-hook))
              (new-clause-struc (missing-larkc 11343)))
         (missing-larkc 11316)
         (missing-larkc 11317)
         (setf formula-data new-clause-struc)
         (missing-larkc 32001)))
      ((cnf-p formula-data-hook))
      ((el-formula-p formula-data-hook))
      (t (error "Unexpected formula data hook: ~S" formula-data-hook)
         (return-from connect-assertion-formula-data nil)))
    (update-assertion-formula-data assertion formula-data))
  assertion)

(defun kb-remove-assertion-internal (assertion)
  (let ((id (assertion-id assertion)))
    (disconnect-assertion assertion)
    (destroy-assertion-content id)
    (deregister-assertion-id id))
  (free-assertion assertion)
  nil)

;; (defun reconnect-assertion (assertion formula-data-hook) ...) -- no body

(defun disconnect-assertion (assertion)
  "[Cyc] Disconnect ASSERTION from all its connections."
  (remove-assertion-indices assertion)
  (disconnect-assertion-formula-data assertion)
  assertion)

(defun disconnect-assertion-formula-data (assertion)
  (when (assertion-clause-struc assertion)
    (missing-larkc 11355))
  (annihilate-assertion-formula-data assertion)
  assertion)

(defun add-new-assertion-argument (assertion new-argument)
  (set-assertion-arguments (assertion-id assertion)
                           (cons new-argument (assertion-arguments assertion)))
  assertion)

(defun remove-assertion-argument (assertion argument)
  (set-assertion-arguments (assertion-id assertion)
                           (delete-first argument (assertion-arguments assertion)))
  assertion)

(defun reset-assertion-dependents (assertion new-dependents)
  "[Cyc] Primitively set the dependent arguments of ASSERTION to NEW-DEPENDENTS."
  (declare (type list new-dependents))
  (if new-dependents
      (set-assertion-prop assertion :dependents new-dependents)
      (rem-assertion-prop assertion :dependents))
  assertion)

(defun add-assertion-dependent (assertion argument)
  "[Cyc] Add ARGUMENT as an argument depending on ASSERTION.  Return ASSERTION."
  (declare (type assertion assertion))
  (declare (type argument argument))
  (reset-assertion-dependents assertion (cons argument (assertion-dependents assertion)))
  assertion)

(defun remove-assertion-dependent (assertion argument)
  "[Cyc] Remove ARGUMENT as an argument depending on ASSERTION.  Return ASSERTION."
  (declare (type assertion assertion))
  (declare (type argument argument))
  (reset-assertion-dependents assertion
                              (delete-first argument (assertion-dependents assertion)))
  assertion)

;; (defun assertion-dependencies (assertion) ...) -- no body
;; (defun mark-dependent-assertion (assertion) ...) -- no body
;; (defun mark-dependent-deduction (deduction) ...) -- no body
;; (defun verify-assertion-content-table (&optional verbose?) ...) -- no body

(defparameter *dependent-deduction-table* nil)
(defparameter *dependent-assertion-table* nil)

;;; Setup phase

(toplevel
  (declare-defglobal '*rule-set*)
  (declare-defglobal '*prefer-rule-set-over-flags?*)
  (register-macro-helper 'kb-rule-set 'do-rules))
