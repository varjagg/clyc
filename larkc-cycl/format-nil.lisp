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

;; Reconstructed macro: FORMAT-NIL
;; Active declareMacro, no Java body (compiled away at SubL compile time).
;; Arglist from $list0: (FORMAT-CONTROL &REST FORMAT-ARGUMENTS)
;; Evidence: $sym1$FORMAT=FORMAT, $sym24$CCONCATENATE=CCONCATENATE,
;;   $str16$ASD%~="ASD%~" (valid format chars), $sym17$CHAR_EQUAL=CHAR-EQUAL,
;;   $list23=(OPERATOR ARG), $list25=(NEXT-CONTROL . REST-CONTROL),
;;   $sym22$COPY_SEQ=COPY-SEQ, $sym31$STRINGP=STRINGP,
;;   $str26$~A, $str27$~S, $str28$~D, $str29$~%, $str30$~~,
;;   $list19=(FORMAT-NIL-PERCENT), $list21=(FORMAT-NIL-TILDE).
;; The macro optimizes (format nil ...) at compile time by splitting the control
;; string on ~A/~S/~D/~%/~~ directives and expanding into cconcatenate of
;; format-nil-a/format-nil-s/format-nil-d/format-nil-percent/format-nil-tilde calls.
;; For the CL port, we simply expand to (format nil ...) which CL handles natively.
(defmacro format-nil (format-control &rest format-arguments)
  `(format nil ,format-control ,@format-arguments))

(defun princ-integer-to-string (integer)
  "[Cyc] Return a string representation of INTEGER"
  (declare (integer integer))
  (if (or (typep integer 'bignum)
          (not (eql 10 *print-base*)))
      (princ-to-string integer)
      (let* ((string-length (+ (if (minusp integer) 1 0)
                               (integer-decimal-length integer)))
             (string (make-string string-length))
             (magnitude (abs integer))
             (digits "0123456789")
             (digit nil)
             (index 0))
        (loop while (not (< magnitude 10))
              do (setf digit (mod magnitude 10))
                 (setf magnitude (truncate magnitude 10))
                 (setf (char string index) (char digits digit))
                 (setf index (+ index 1)))
        (setf (char string index) (char digits magnitude))
        (setf index (+ index 1))
        (when (minusp integer)
          (setf (char string index) #\-))
        (setf string (nreverse string))
        string)))

(defun format-nil-a (object)
  "[Cyc] Active declareFunction, no docstring in Java."
  (cond ((symbolp object) (copy-seq (symbol-name object)))
        ((stringp object) (copy-seq object))
        ((integerp object) (princ-integer-to-string object))
        (t (princ-to-string object))))

(defun format-nil-a-no-copy (object)
  "[Cyc] Active declareFunction, no docstring in Java."
  (cond ((symbolp object) (symbol-name object))
        ((stringp object) object)
        ((integerp object) (princ-integer-to-string object))
        (t (princ-to-string object))))

;; (defun format-nil-s (object) ...) -- active declareFunction, no body

;; (defun format-nil-s-no-copy (object) ...) -- active declareFunction, no body

;; (defun format-nil-d (object) ...) -- active declareFunction, no body

;; (defun format-nil-d-no-copy (object) ...) -- active declareFunction, no body

;; (defun format-nil-percent () ...) -- active declareFunction, no body

;; (defun format-nil-tilde () ...) -- active declareFunction, no body

;; (defun format-nil-internal (format-control format-arguments) ...) -- active declareFunction, no body

;; (defun format-nil-control-validator (format-control) ...) -- active declareFunction, no body

;; (defun format-nil-simplify (format-control) ...) -- active declareFunction, no body

;; (defun format-nil-expand (format-control format-arguments) ...) -- active declareFunction, no body

;; (defun format-nil-control-split (format-control) ...) -- active declareFunction, no body

;; (defun format-nil-control-split-internal (format-control) ...) -- active declareFunction, no body

(defun integer-decimal-length (integer)
  "[Cyc] Return the number of digits needed to express INTEGER in base 10."
  (declare (integer integer))
  (let ((magnitude (abs integer))
        (length 1))
    (loop while (not (< magnitude 10))
          do (setf length (+ length 1))
             (setf magnitude (truncate magnitude 10)))
    length))

;; (defun format-one-per-line (list &optional (stream *standard-output*)) ...) -- active declareFunction, no body

;; (defun print-one-per-line (list &optional (stream *standard-output*)) ...) -- active declareFunction, no body

;; (defun print-one-aspect-per-line (list aspect-fn &optional (stream *standard-output*)) ...) -- active declareFunction, no body

;; (defun force-format (destination control-string &optional arg1 arg2 arg3 arg4 arg5 arg6 arg7 arg8) ...) -- active declareFunction, no body

;;; Init phase

(defconstant *format-nil-percent* (format nil "~%")
  "[Cyc] A newline string.")

(defconstant *format-nil-tilde* "~"
  "[Cyc] A tilde string.")

;;; Setup phase

(register-macro-helper 'format-nil-a 'format-nil)
(register-macro-helper 'format-nil-a-no-copy 'format-nil)
(register-macro-helper 'format-nil-s 'format-nil)
(register-macro-helper 'format-nil-s-no-copy 'format-nil)
(register-macro-helper 'format-nil-d 'format-nil)
(register-macro-helper 'format-nil-d-no-copy 'format-nil)
(register-macro-helper 'format-nil-percent 'format-nil)
(register-macro-helper 'format-nil-tilde 'format-nil)
