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

(defun scientific-number-p (object)
  "[Cyc] We check that object is a nat with functor #$ScientificNumberFn
and two integer args."
  (and (el-formula-with-operator-p object #$ScientificNumberFn)
       (el-binary-formula-p object)
       (integerp (formula-arg1 object))
       (integerp (formula-arg2 object))))

;; (defun cyc-scientific-number-p (object) ...) -- commented declareFunction, no body
;; (defun new-scientific-number (significand exponent) ...) -- commented declareFunction, no body
;; (defun new-scientific-number-from-integer (integer &optional precision) ...) -- commented declareFunction, no body
;; (defun scientific-number-significand (scientific-number) ...) -- commented declareFunction, no body
;; (defun scientific-number-exponent (scientific-number) ...) -- commented declareFunction, no body
;; (defun copy-scientific-number (scientific-number) ...) -- commented declareFunction, no body
;; (defun scientific-number-zero-p (scientific-number) ...) -- commented declareFunction, no body
;; (defun scientific-number-minus-p (scientific-number) ...) -- commented declareFunction, no body
;; (defun scientific-number-plus-p (scientific-number) ...) -- commented declareFunction, no body
;; (defun scientific-number-non-negative-p (scientific-number) ...) -- commented declareFunction, no body
;; (defun scientific-number-add-significant-zeros (scientific-number count) ...) -- commented declareFunction, no body
;; (defun cyc-scientific-number-from-string (string) ...) -- commented declareFunction, no body
;; (defun scientific-number-from-string (string &optional precision) ...) -- commented declareFunction, no body
;; (defun first-non-zero-digit-position (string) ...) -- commented declareFunction, no body
;; (defun non-zero-digit-char-p (char) ...) -- commented declareFunction, no body
;; (defun cyc-scientific-number-to-string (scientific-number) ...) -- commented declareFunction, no body
;; (defun cyc-scientific-number-from-subl-real (real) ...) -- commented declareFunction, no body
;; (defun scientific-number-from-subl-real (real &optional precision) ...) -- commented declareFunction, no body
;; (defun cyc-scientific-number-to-subl-real (scientific-number) ...) -- commented declareFunction, no body
;; (defun cyc-scientific-number-significant-digit-count (scientific-number) ...) -- commented declareFunction, no body

(toplevel
  (register-kb-function 'cyc-scientific-number-p)
  (register-kb-function 'cyc-scientific-number-from-string)
  (register-kb-function 'cyc-scientific-number-to-string)
  (register-kb-function 'cyc-scientific-number-from-subl-real)
  (register-kb-function 'cyc-scientific-number-to-subl-real)
  (register-kb-function 'cyc-scientific-number-significant-digit-count))
