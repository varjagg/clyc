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

(defparameter *kb-compare-common-symbols*
  (append '(t)
          '(assertion-id-from-recipe
            deduction-id-from-recipe
            constant-internal-id-from-external-id
            constant-name-from-internal-id
            nart-id-from-recipe)
          (append (valid-truths)
                  (valid-hl-truth-values)
                  (hl-support-modules)))
  "[Cyc] A list of the common symbols used across KB compare connections.")

;;; KB-INTERSECTION defstruct
;; conc-name KB-INTRSCT- derived from _csetf_ accessor prefixes in Java.

(defstruct (kb-intersection (:conc-name "KB-INTRSCT-"))
  remote-image
  constant-index
  nart-index
  assertion-index
  deduction-index)

(defconstant *dtp-kb-intersection* 'kb-intersection)

;;; KB-DIFFERENCE defstruct
;; conc-name KB-DIFF- derived from _csetf_ accessor prefixes in Java.

(defstruct (kb-difference (:conc-name "KB-DIFF-"))
  common-intersection
  renamed-constants
  constants
  narts
  assertions
  deductions)

(defconstant *dtp-kb-difference* 'kb-difference)

(defparameter *kb-intersection* nil)

;;; Functions (ordered by declare_kb_compare_file)

;; (defmacro with-new-kb-compare-connection (remote-image &body body) ...) -- reconstructed below
;; (defun set-kb-compare-connection-common-symbols () ...) -- commented declareFunction, no body

(defun kb-intersection-print-function-trampoline (object stream)
  "Print function trampoline for KB-INTERSECTION."
  (declare (ignore object stream))
  ;; Likely calls print-kb-intersection — evidence: Structures.register_method for
  ;; print-object targets this trampoline, same pattern as other LarKC-stripped trampolines.
  (missing-larkc 4602))

;; (defun kb-intersection-p (object) ...) -- commented declareFunction, no body (defstruct provides predicate)
;; kb-intrsct-remote-image — provided by defstruct
;; kb-intrsct-constant-index — provided by defstruct
;; kb-intrsct-nart-index — provided by defstruct
;; kb-intrsct-assertion-index — provided by defstruct
;; kb-intrsct-deduction-index — provided by defstruct
;; _csetf-kb-intrsct-remote-image — provided by defstruct (setf kb-intrsct-remote-image)
;; _csetf-kb-intrsct-constant-index — provided by defstruct (setf kb-intrsct-constant-index)
;; _csetf-kb-intrsct-nart-index — provided by defstruct (setf kb-intrsct-nart-index)
;; _csetf-kb-intrsct-assertion-index — provided by defstruct (setf kb-intrsct-assertion-index)
;; _csetf-kb-intrsct-deduction-index — provided by defstruct (setf kb-intrsct-deduction-index)
;; (defun make-kb-intersection (&optional arglist) ...) -- commented declareFunction, no body
;; (defun print-kb-intersection (object stream depth) ...) -- commented declareFunction, no body
;; (defun new-kb-intersection (remote-image) ...) -- commented declareFunction, no body
;; (defun destroy-kb-intersection (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-remote-image (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-constant-index (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-add-constant (intersection constant remote-id) ...) -- commented declareFunction, no body
;; (defun kb-intersection-add-nart (intersection nart remote-id) ...) -- commented declareFunction, no body
;; (defun kb-intersection-add-assertion (intersection assertion remote-id) ...) -- commented declareFunction, no body
;; (defun kb-intersection-add-deduction (intersection deduction remote-id) ...) -- commented declareFunction, no body
;; (defun kb-intersection-remote-image-machine (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-remote-image-port (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-remote-image-protocol (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-constant? (intersection constant) ...) -- commented declareFunction, no body
;; (defun kb-intersection-constant-remote-id (intersection constant) ...) -- commented declareFunction, no body
;; (defun kb-intersection-nart? (intersection nart) ...) -- commented declareFunction, no body
;; (defun kb-intersection-nart-remote-id (intersection nart) ...) -- commented declareFunction, no body
;; (defun kb-intersection-assertion? (intersection assertion) ...) -- commented declareFunction, no body
;; (defun kb-intersection-assertion-remote-id (intersection assertion) ...) -- commented declareFunction, no body
;; (defun kb-intersection-deduction? (intersection deduction) ...) -- commented declareFunction, no body
;; (defun kb-intersection-deduction-remote-id (intersection deduction) ...) -- commented declareFunction, no body
;; (defmacro do-kb-intersection-constants ((constant intersection &key progress-message) &body body) ...) -- reconstructed below
;; (defun kb-intersection-nart-impossible? (intersection nart) ...) -- commented declareFunction, no body
;; (defun kb-intersection-nart-impossible-int (int) ...) -- commented declareFunction, no body
;; (defun kb-intersection-assertion-impossible? (intersection assertion) ...) -- commented declareFunction, no body
;; (defun kb-intersection-assertion-impossible-int (int) ...) -- commented declareFunction, no body
;; (defun kb-intersection-deduction-impossible? (intersection deduction) ...) -- commented declareFunction, no body
;; (defun kb-intersection-deduction-impossible-int (int) ...) -- commented declareFunction, no body

(defun kb-difference-print-function-trampoline (object stream)
  "Print function trampoline for KB-DIFFERENCE."
  (declare (ignore object stream))
  ;; Likely calls print-kb-difference — evidence: Structures.register_method for
  ;; print-object targets this trampoline, same pattern as other LarKC-stripped trampolines.
  (missing-larkc 4601))

;; (defun kb-difference-p (object) ...) -- commented declareFunction, no body (defstruct provides predicate)
;; kb-diff-common-intersection — provided by defstruct
;; kb-diff-renamed-constants — provided by defstruct
;; kb-diff-constants — provided by defstruct
;; kb-diff-narts — provided by defstruct
;; kb-diff-assertions — provided by defstruct
;; kb-diff-deductions — provided by defstruct
;; _csetf-kb-diff-common-intersection — provided by defstruct (setf kb-diff-common-intersection)
;; _csetf-kb-diff-renamed-constants — provided by defstruct (setf kb-diff-renamed-constants)
;; _csetf-kb-diff-constants — provided by defstruct (setf kb-diff-constants)
;; _csetf-kb-diff-narts — provided by defstruct (setf kb-diff-narts)
;; _csetf-kb-diff-assertions — provided by defstruct (setf kb-diff-assertions)
;; _csetf-kb-diff-deductions — provided by defstruct (setf kb-diff-deductions)
;; (defun make-kb-difference (&optional arglist) ...) -- commented declareFunction, no body
;; (defun print-kb-difference (object stream depth) ...) -- commented declareFunction, no body
;; (defun new-kb-difference (common-intersection) ...) -- commented declareFunction, no body
;; (defun destroy-kb-difference (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-common-intersection (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-renamed-constants (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-constants (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-narts (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-assertions (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-deductions (difference) ...) -- commented declareFunction, no body
;; (defmacro do-kb-difference-renamed-constants ((constant remote-name difference &key done) &body body) ...) -- reconstructed below
;; (defmacro do-kb-difference-constants ((constant difference &key done) &body body) ...) -- reconstructed below
;; (defmacro do-kb-difference-narts ((nart difference &key done) &body body) ...) -- reconstructed below
;; (defmacro do-kb-difference-assertions ((assertion difference &key done) &body body) ...) -- reconstructed below
;; (defmacro do-kb-difference-deductions ((deduction difference &key done) &body body) ...) -- reconstructed below
;; (defun kb-difference-add-renamed-constant (difference constant remote-name) ...) -- commented declareFunction, no body
;; (defun kb-difference-add-constant (difference constant) ...) -- commented declareFunction, no body
;; (defun kb-difference-add-nart (difference nart) ...) -- commented declareFunction, no body
;; (defun kb-difference-add-assertion (difference assertion) ...) -- commented declareFunction, no body
;; (defun kb-difference-add-deduction (difference deduction) ...) -- commented declareFunction, no body
;; (defun kb-difference-remote-image (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-remote-image-machine (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-remote-image-port (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-remote-image-protocol (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-constant-remote-name (difference constant) ...) -- commented declareFunction, no body
;; (defun kb-difference-all-renamed-constants (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-all-constants (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-all-narts (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-all-assertions (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-all-deductions (difference) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-constants (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-congruent-old-constants (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-constant (intersection constant) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-narts (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-congruent-old-narts (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-nart (intersection nart) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-assertions (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-congruent-old-assertions (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-assertion (intersection assertion) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-deductions (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-congruent-old-deductions (intersection) ...) -- commented declareFunction, no body
;; (defun kb-intersection-compute-deduction (intersection deduction) ...) -- commented declareFunction, no body
;; (defun kb-difference-compute (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-compute-renamed-constants (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-compute-constants (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-compute-narts (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-compute-assertions (difference) ...) -- commented declareFunction, no body
;; (defun kb-difference-compute-deductions (difference) ...) -- commented declareFunction, no body
;; (defun compute-remote-image-kb-intersection (remote-image kb-intersection &optional progress-message) ...) -- commented declareFunction, no body
;; (defun compute-remote-image-kb-difference (remote-image kb-difference &optional progress-message) ...) -- commented declareFunction, no body
;; (defun show-kb-difference (difference &optional stream) ...) -- commented declareFunction, no body
;; (defun compute-remote-image-old-constants-congruent? () ...) -- commented declareFunction, no body
;; (defun compute-missing-old-constant-remote-ids () ...) -- commented declareFunction, no body
;; (defun compute-constant-remote-id (constant) ...) -- commented declareFunction, no body
;; (defun compute-constant-remote-name (constant) ...) -- commented declareFunction, no body
;; (defun compute-remote-image-old-narts-congruent? () ...) -- commented declareFunction, no body
;; (defun compute-missing-old-nart-remote-ids () ...) -- commented declareFunction, no body
;; (defun compute-nart-remote-id (nart) ...) -- commented declareFunction, no body
;; (defun compute-remote-image-old-assertions-congruent? () ...) -- commented declareFunction, no body
;; (defun compute-missing-old-assertion-remote-ids () ...) -- commented declareFunction, no body
;; (defun compute-assertion-remote-id (assertion) ...) -- commented declareFunction, no body
;; (defun compute-remote-image-old-deductions-congruent? () ...) -- commented declareFunction, no body
;; (defun compute-missing-old-deduction-remote-ids () ...) -- commented declareFunction, no body
;; (defun compute-deduction-remote-id (deduction) ...) -- commented declareFunction, no body

;;; Macros (reconstructed from Internal Constants evidence)

;; $list2 = (REMOTE-IMAGE &BODY BODY)
;; Orphans: $sym3$WITH_NEW_REMOTE_IMAGE_CONNECTION, $sym4$CLET,
;;   $list5 = ((*KB-COMPARE-COMMON-SYMBOLS* *KB-COMPARE-COMMON-SYMBOLS*)),
;;   $list6 = (SET-KB-COMPARE-CONNECTION-COMMON-SYMBOLS),
;;   $sym7$WITH_CFASL_COMMON_SYMBOLS, $sym8$_KB_COMPARE_COMMON_SYMBOLS_ (the symbol),
;;   $sym16$QUOTE
;; register_macro_helper in setup: SET-KB-COMPARE-CONNECTION-COMMON-SYMBOLS is helper for this macro.
;; Reconstruction: opens a remote image connection, rebinds *kb-compare-common-symbols*
;; to itself, calls the helper to set the remote side, and wraps body in
;; with-cfasl-common-symbols bound to '*kb-compare-common-symbols*.
(defmacro with-new-kb-compare-connection ((remote-image) &body body)
  "Execute BODY inside a new KB compare connection to REMOTE-IMAGE."
  `(with-new-remote-image-connection (,remote-image)
     (clet ((*kb-compare-common-symbols* *kb-compare-common-symbols*))
       (set-kb-compare-connection-common-symbols)
       (with-cfasl-common-symbols ('*kb-compare-common-symbols*)
         ,@body))))

;; $list51 = ((CONSTANT INTERSECTION &KEY PROGRESS-MESSAGE) &BODY BODY)
;; $list52 = (:PROGRESS-MESSAGE), $kw53$ALLOW_OTHER_KEYS, $kw54$PROGRESS_MESSAGE
;; Uninterned gensyms: $sym55$INTERNAL_ID, $sym56$REMOTE_ID
;; $sym57$DO_ID_INDEX, $sym58$IGNORE, $sym59$FIND_CONSTANT_BY_INTERNAL_ID
;; register_macro_helper in setup: KB-INTERSECTION-CONSTANT-INDEX is helper for this macro.
;; Reconstruction: iterate kb-intersection-constant-index via do-id-index; the key is
;; internal-id (gensym), the value is remote-id (gensym); look up the constant by its
;; internal-id and run body.
(defmacro do-kb-intersection-constants ((constant intersection &key progress-message)
                                        &body body)
  "Iterate BODY with CONSTANT bound to each constant in the KB intersection."
  (let ((internal-id (make-symbol "INTERNAL-ID"))
        (remote-id (make-symbol "REMOTE-ID")))
    `(do-id-index (,internal-id ,remote-id
                   (kb-intersection-constant-index ,intersection)
                   :progress-message ,progress-message)
       (declare (ignore ,remote-id))
       (let ((,constant (find-constant-by-internal-id ,internal-id)))
         ,@body))))

;; $list101 = ((CONSTANT REMOTE-NAME DIFFERENCE &KEY DONE) &BODY BODY)
;; $list102 = (:DONE), $kw103$DONE, $sym104$DO_DICTIONARY
;; register_macro_helper in setup: KB-DIFFERENCE-RENAMED-CONSTANTS is helper for this macro.
;; Reconstruction: iterate kb-difference-renamed-constants (a dictionary) via do-dictionary.
(defmacro do-kb-difference-renamed-constants ((constant remote-name difference &key done)
                                              &body body)
  "Iterate BODY over each renamed constant in the KB-DIFFERENCE."
  `(do-dictionary (,constant ,remote-name
                   (kb-difference-renamed-constants ,difference) ,done)
     ,@body))

;; $list105 = ((CONSTANT DIFFERENCE &KEY DONE) &BODY BODY), $sym106$DO_SET
;; register_macro_helper in setup: KB-DIFFERENCE-CONSTANTS is helper for this macro.
;; Reconstruction: iterate kb-difference-constants (a set) via do-set.
(defmacro do-kb-difference-constants ((constant difference &key done) &body body)
  "Iterate BODY over each constant in the KB-DIFFERENCE."
  `(do-set (,constant (kb-difference-constants ,difference) ,done)
     ,@body))

;; $list107 = ((NART DIFFERENCE &KEY DONE) &BODY BODY), $sym106$DO_SET
;; register_macro_helper in setup: KB-DIFFERENCE-NARTS is helper for this macro.
;; Reconstruction: iterate kb-difference-narts (a set) via do-set.
(defmacro do-kb-difference-narts ((nart difference &key done) &body body)
  "Iterate BODY over each nart in the KB-DIFFERENCE."
  `(do-set (,nart (kb-difference-narts ,difference) ,done)
     ,@body))

;; $list108 = ((ASSERTION DIFFERENCE &KEY DONE) &BODY BODY), $sym106$DO_SET
;; register_macro_helper in setup: KB-DIFFERENCE-ASSERTIONS is helper for this macro.
;; Reconstruction: iterate kb-difference-assertions (a set) via do-set.
(defmacro do-kb-difference-assertions ((assertion difference &key done) &body body)
  "Iterate BODY over each assertion in the KB-DIFFERENCE."
  `(do-set (,assertion (kb-difference-assertions ,difference) ,done)
     ,@body))

;; $list109 = ((DEDUCTION DIFFERENCE &KEY DONE) &BODY BODY), $sym106$DO_SET
;; register_macro_helper in setup: KB-DIFFERENCE-DEDUCTIONS is helper for this macro.
;; Reconstruction: iterate kb-difference-deductions (a set) via do-set.
(defmacro do-kb-difference-deductions ((deduction difference &key done) &body body)
  "Iterate BODY over each deduction in the KB-DIFFERENCE."
  `(do-set (,deduction (kb-difference-deductions ,difference) ,done)
     ,@body))

;;; Setup

(toplevel
  (register-macro-helper 'set-kb-compare-connection-common-symbols
                         'with-new-kb-compare-connection)
  (register-macro-helper 'kb-intersection-constant-index
                         'do-kb-intersection-constants)
  (register-macro-helper 'kb-difference-renamed-constants
                         'do-kb-difference-renamed-constants)
  (register-macro-helper 'kb-difference-constants
                         'do-kb-difference-constants)
  (register-macro-helper 'kb-difference-narts
                         'do-kb-difference-narts)
  (register-macro-helper 'kb-difference-assertions
                         'do-kb-difference-assertions)
  (register-macro-helper 'kb-difference-deductions
                         'do-kb-difference-deductions))
