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

;;; C-backend translator: emits C source/header files for a translated SubL
;;; system.  Only two functions retained Java bodies after LarKC stripping:
;;; C-BACKED-CONVERT-IDENTIFIER-NAME (note the "backed" typo, preserved from
;;; Java) and C-BACKEND-CONVERT-CHAR.  The 149 other declareFunction entries
;;; are present as commented-out one-line stubs in their source order.

(defparameter *anonymous-variable-counter* nil)

;; c-backend-output-file-and-header-file (ts-file output-file) -- commented declareFunction, no body
;; c-backend-output-file (ts-file output-file) -- commented declareFunction, no body
;; c-backend-output-header-file (ts-file output-file) -- commented declareFunction, no body
;; c-backend-associated-header-file (pathname) -- commented declareFunction, no body
;; c-backend-output-to-stream (ts-file &optional stream header-stream) -- commented declareFunction, no body
;; c-backend-output-definition-headers-to-stream (ts-file &optional stream header-stream) -- commented declareFunction, no body
;; c-backend-output-global-headers (ts-file stream) -- commented declareFunction, no body
;; c-backend-output-function-headers (ts-file stream) -- commented declareFunction, no body
;; c-backend-output-header-section (ts-file stream section) -- commented declareFunction, no body
;; c-backend-write-preamble (ts-file stream &optional extra) -- commented declareFunction, no body
;; c-backend-write-makefile-preamble (stream) -- commented declareFunction, no body
;; translation-copyright-string () -- commented declareFunction, no body
;; c-backend-output-forward-global-declarations (ts-file stream) -- commented declareFunction, no body
;; c-backend-output-forward-function-declarations (ts-file stream) -- commented declareFunction, no body
;; forward-global-reference-via-rtl? (global) -- commented declareFunction, no body
;; forward-function-reference-via-rtl? (function) -- commented declareFunction, no body
;; ts-file-all-forward-referenced-globals (ts-file) -- commented declareFunction, no body
;; ts-file-all-forward-referenced-functions (ts-file) -- commented declareFunction, no body
;; c-backend-output-forward-global-declaration (global stream) -- commented declareFunction, no body
;; c-backend-output-forward-function-declaration (function stream) -- commented declareFunction, no body
;; c-backend-output-internal-constant-array-definition (ts-file stream) -- commented declareFunction, no body
;; c-backend-output-private-global-definitions (ts-file stream) -- commented declareFunction, no body
;; c-backend-output-private-function-definitions (ts-file stream) -- commented declareFunction, no body
;; c-backend-output-definitions (ts-file stream) -- commented declareFunction, no body
;; c-backend-write-statement (form stream &optional indent) -- commented declareFunction, no body
;; c-backend-write-form (form stream &optional indent) -- commented declareFunction, no body
;; c-backend-test-translate-write-form (form stream &optional indent) -- commented declareFunction, no body
;; c-backend-indent (indent stream) -- commented declareFunction, no body
;; c-backend-print-atom (atom stream indent) -- commented declareFunction, no body
;; c-backend-native-constant-p (atom) -- commented declareFunction, no body
;; c-backend-write-native-constant (atom stream) -- commented declareFunction, no body
;; c-backend-write-native-string-constant (atom stream) -- commented declareFunction, no body
;; c-backend-write-%pc (form stream &optional indent) -- commented declareFunction, no body
;; c-backend-print-variable (variable stream) -- commented declareFunction, no body
;; c-backend-variable-binding-type (variable) -- commented declareFunction, no body
;; c-backend-write-global-variable-name (variable stream) -- commented declareFunction, no body
;; c-backend-write-local-variable-name (variable stream) -- commented declareFunction, no body
;; c-backend-secure-global-id (variable) -- commented declareFunction, no body
;; c-backend-secure-local-id-internal (variable) -- commented declareFunction, no body
;; c-backend-secure-local-id (variable) -- commented declareFunction, no body
;; c-backend-local-variable-name-internal (variable) -- commented declareFunction, no body
;; c-backend-local-variable-name (variable) -- commented declareFunction, no body
;; c-backend-global-variable-name (variable) -- commented declareFunction, no body
;; c-backend-compute-global-variable-name-internal (variable) -- commented declareFunction, no body
;; c-backend-compute-global-variable-name (variable) -- commented declareFunction, no body
;; c-backend-symbol-name-basis (symbol) -- commented declareFunction, no body

(defparameter *c-backend-write-global-definition-as-comment* nil
  "[Cyc] When non-nil, we output a global definition statement just as a comment.")

(deflexical *c-backend-convert-char-map*
    (list (cons #\? #\P)
          (cons #\- #\_)
          (cons #\Space #\_)
          (cons #\< #\L)
          (cons #\= #\E)
          (cons #\> #\G)))

(defun c-backed-convert-identifier-name (name)
  (declare (type string name))
  (let* ((length (length name))
         (start (if (and (plusp length)
                         (char= (char name 0) #\*))
                    1
                    0))
         (end (if (and (> length 1)
                       (= start 1)
                       (char= (char name (1- length)) #\*))
                  (1- length)
                  length))
         (name-basis (substring name start end))
         (string-var name-basis)
         (end-var (length string-var)))
    (let ((end-var-10 end-var))
      (do ((index 0 (1+ index)))
          ((>= index end-var-10))
        (let ((v-char (char string-var index)))
          (setf (char name-basis index) (c-backend-convert-char (char-downcase v-char))))))
    name-basis))

(defun c-backend-convert-char (v-char)
  (if (or (alphanumericp v-char)
          (char= v-char #\_))
      v-char
      (alist-lookup-without-values *c-backend-convert-char-map* v-char (symbol-function 'eql) #\X)))

;; c-backend-write-function-call (form stream indent) -- commented declareFunction, no body
;; c-backend-function-name (form) -- commented declareFunction, no body
;; c-backend-computed-function-name-internal (function) -- commented declareFunction, no body
;; c-backend-computed-function-name (function) -- commented declareFunction, no body
;; c-backend-function-signature-info (function) -- commented declareFunction, no body
;; c-backend-function-arglist (function) -- commented declareFunction, no body
;; c-backend-write-function-call-argument-separator (stream) -- commented declareFunction, no body
;; c-backend-write-function-call-unprovided-argument (stream) -- commented declareFunction, no body
;; c-backend-write-call-arity (arity stream) -- commented declareFunction, no body
;; c-backend-writer (operator) -- commented declareFunction, no body
;; c-backend-write-via-writer (writer form stream indent) -- commented declareFunction, no body
;; c-backend-write-%b-check-type (form stream indent) -- commented declareFunction, no body
;; c-backend-write-check-type (object pred form stream indent) -- commented declareFunction, no body
;; c-backend-write-%dp-check-type (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%dp-enforce-type (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%ccatch (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%cdo-symbols (form stream indent) -- commented declareFunction, no body
;; c-backend-write-clet-bind (form stream indent) -- commented declareFunction, no body
;; c-backend-write-clet-local (form stream indent) -- commented declareFunction, no body
;; c-backend-write-code-comment (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%cprogv (form stream indent) -- commented declareFunction, no body
;; c-backend-write-csetq (form stream indent) -- commented declareFunction, no body
;; c-backend-write-csetq-dynamic (form stream indent) -- commented declareFunction, no body
;; c-backend-write-csetq-lexical (form stream indent) -- commented declareFunction, no body
;; c-backend-write-csetq-local (form stream indent) -- commented declareFunction, no body
;; c-backend-write-assignment-operator (stream) -- commented declareFunction, no body
;; c-backend-write-%cunwind-protect (form stream indent) -- commented declareFunction, no body
;; c-backend-write-cvs-id (form stream indent) -- commented declareFunction, no body
;; c-backend-write-defconstant (form stream &optional indent) -- commented declareFunction, no body
;; c-backend-write-global (form stream indent) -- commented declareFunction, no body
;; c-backend-volatilize-locals? () -- commented declareFunction, no body
;; c-backend-write-define (form stream indent) -- commented declareFunction, no body
;; c-backend-compute-function-body-statement (name body arglist) -- commented declareFunction, no body
;; c-backend-write-definer-comment (form stream) -- commented declareFunction, no body
;; c-backend-write-method-source-definition-comment (name stream info) -- commented declareFunction, no body
;; c-backend-write-global-source-definition-comment (name stream info) -- commented declareFunction, no body
;; c-backend-write-function-declaration (form stream &optional indent extern) -- commented declareFunction, no body
;; c-backend-write-function-name (name stream) -- commented declareFunction, no body
;; c-backend-secure-method-id (method) -- commented declareFunction, no body
;; c-backend-optional-argument-initializations (arglist) -- commented declareFunction, no body
;; c-backend-write-object-data-type (stream) -- commented declareFunction, no body
;; c-backend-write-function-arglist (arglist stream indent) -- commented declareFunction, no body
;; c-backend-write-function-argument-separator (stream) -- commented declareFunction, no body
;; c-backend-write-function-arglist-arg (arg stream) -- commented declareFunction, no body
;; translator-arglist-arg-variable (arg) -- commented declareFunction, no body
;; c-backend-volatilize-define? (form) -- commented declareFunction, no body
;; c-backend-method-returns-within-binding-construct? (form) -- commented declareFunction, no body
;; c-backend-transform-returns-to-throws (form) -- commented declareFunction, no body
;; translator-ret-form-p (form) -- commented declareFunction, no body
;; translator-ret-to-throw (form) -- commented declareFunction, no body
;; c-backend-write-define-macroexpander (form stream indent) -- commented declareFunction, no body
;; c-backend-write-deflexical (form stream indent) -- commented declareFunction, no body
;; c-backend-write-defparameter (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%defstruct-class (form stream indent) -- commented declareFunction, no body
;; c-backend-write-defstruct-construct (form stream indent) -- commented declareFunction, no body
;; c-backend-write-defstruct-get-slot (form stream indent) -- commented declareFunction, no body
;; c-backend-write-defstruct-object-p (form stream indent) -- commented declareFunction, no body
;; c-backend-write-defstruct-set-slot (form stream indent) -- commented declareFunction, no body
;; c-backend-write-defvar (form stream indent) -- commented declareFunction, no body
;; c-backend-write-fif (form stream indent) -- commented declareFunction, no body
;; c-backend-write-pcond (form stream indent) -- commented declareFunction, no body
;; c-backend-write-progn (form stream indent) -- commented declareFunction, no body
;; c-backend-write-ret (form stream indent) -- commented declareFunction, no body
;; c-backend-write-while (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%and (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%cdohash (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%enter (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%for (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%ic (form stream indent) -- commented declareFunction, no body
;; c-backend-write-internal-constant-reference (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%internal-constant (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%lf (form stream indent) -- commented declareFunction, no body
;; c-backend-fixnum-p (object) -- commented declareFunction, no body
;; c-backend-write-%local (form stream indent) -- commented declareFunction, no body
;; c-backend-write-multiple-value-list (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%nc (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%not (form stream indent) -- commented declareFunction, no body
;; c-backend-write-nth-value (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%or (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%register-function (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%register-global (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%register-macro (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%with-current-thread (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%with-error-handler (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%with-process-resource-tracking (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%thread-mval (form stream indent) -- commented declareFunction, no body
;; c-backend-write-%thread-reset-mval (form stream indent) -- commented declareFunction, no body
;; c-backend-optimize-function-call-form (form) -- commented declareFunction, no body
;; c-backend-output-system-level-files (ts init-file header-file filelist-file index-file instructions-file) -- commented declareFunction, no body
;; c-backend-file-name-from-string (string) -- commented declareFunction, no body
;; c-backend-output-module-filename (module &optional extension) -- commented declareFunction, no body
;; c-backend-module-name-from-string (string) -- commented declareFunction, no body
;; c-backend-method-name-from-string (string) -- commented declareFunction, no body
;; c-backend-ifdef-name-from-string (string) -- commented declareFunction, no body
;; c-backend-output-system-init-file (ts modules file stream) -- commented declareFunction, no body
;; c-backend-output-system-header-file (ts modules file stream) -- commented declareFunction, no body
;; c-backend-relative-directory (module) -- commented declareFunction, no body
;; c-backend-output-system-filelist-file (ts modules file stream) -- commented declareFunction, no body
;; c-backend-output-system-directory-make-file-info (ts module stream directory modules) -- commented declareFunction, no body
;; c-backend-output-system-build-index-file (ts modules stream) -- commented declareFunction, no body
;; c-backend-output-system-build-index-libraries (ts modules stream libraries objects headers) -- commented declareFunction, no body
;; c-backend-output-system-build-instructions-file (ts modules stream) -- commented declareFunction, no body
;; c-backend-system-build-instructions-path-spec (module) -- commented declareFunction, no body

(deflexical *c-backend-writers*
    (list (cons '%and 'c-backend-write-%and)
          (cons '%b-check-type 'c-backend-write-%b-check-type)
          (cons '%ccatch 'c-backend-write-%ccatch)
          (cons '%cdo-symbols 'c-backend-write-%cdo-symbols)
          (cons '%cdohash 'c-backend-write-%cdohash)
          (cons 'clet-bind 'c-backend-write-clet-bind)
          (cons 'clet-local 'c-backend-write-clet-local)
          (cons 'code-comment 'c-backend-write-code-comment)
          (cons '%cprogv 'c-backend-write-%cprogv)
          (cons 'csetq 'c-backend-write-csetq)
          (cons 'csetq-dynamic 'c-backend-write-csetq-dynamic)
          (cons 'csetq-lexical 'c-backend-write-csetq-lexical)
          (cons 'csetq-local 'c-backend-write-csetq-local)
          (cons '%cunwind-protect 'c-backend-write-%cunwind-protect)
          (cons 'cvs-id 'c-backend-write-cvs-id)
          (cons 'defconstant 'c-backend-write-defconstant)
          (cons 'define 'c-backend-write-define)
          (cons 'define-macroexpander 'c-backend-write-define-macroexpander)
          (cons 'deflexical 'c-backend-write-deflexical)
          (cons 'defparameter 'c-backend-write-defparameter)
          (cons '%defstruct-class 'c-backend-write-%defstruct-class)
          ;; The four _DEFSTRUCT-* entries below were SUBLISP-package symbols
          ;; in the Java source.  Clyc has no :sublisp package, so these are
          ;; interned in :clyc; this is a known direct-port artifact.  TODO
          (cons '_defstruct-construct 'c-backend-write-defstruct-construct)
          (cons '_defstruct-get-slot 'c-backend-write-defstruct-get-slot)
          (cons '_defstruct-object-p 'c-backend-write-defstruct-object-p)
          (cons '_defstruct-set-slot 'c-backend-write-defstruct-set-slot)
          (cons 'defvar 'c-backend-write-defvar)
          (cons '%dp-check-type 'c-backend-write-%dp-check-type)
          (cons '%dp-enforce-type 'c-backend-write-%dp-enforce-type)
          (cons '%enter 'c-backend-write-%enter)
          (cons 'fif 'c-backend-write-fif)
          (cons '%for 'c-backend-write-%for)
          (cons '%ic 'c-backend-write-%ic)
          (cons '%internal-constant 'c-backend-write-%internal-constant)
          (cons '%lf 'c-backend-write-%lf)
          (cons '%local 'c-backend-write-%local)
          (cons 'multiple-value-list 'c-backend-write-multiple-value-list)
          (cons '%nc 'c-backend-write-%nc)
          (cons '%not 'c-backend-write-%not)
          (cons 'nth-value 'c-backend-write-nth-value)
          (cons '%or 'c-backend-write-%or)
          (cons '%pc 'c-backend-write-%pc)
          (cons 'pcond 'c-backend-write-pcond)
          (cons 'progn 'c-backend-write-progn)
          (cons '%register-function 'c-backend-write-%register-function)
          (cons '%register-global 'c-backend-write-%register-global)
          (cons '%register-macro 'c-backend-write-%register-macro)
          (cons 'ret 'c-backend-write-ret)
          (cons 'while 'c-backend-write-while)
          (cons '%with-current-thread 'c-backend-write-%with-current-thread)
          (cons '%with-error-handler 'c-backend-write-%with-error-handler)
          (cons '%with-process-resource-tracking 'c-backend-write-%with-process-resource-tracking)
          (cons '%thread-mval 'c-backend-write-%thread-mval)
          (cons '%thread-reset-mval 'c-backend-write-%thread-reset-mval)))

(defparameter *c-backend-volatilize-locals?* nil
  "[Cyc] When non-NIL, all local variables are declared volatile.")

;; Setup-phase calls (note-memoized-function and note-funcall-helper-function):
(toplevel (note-memoized-function 'c-backend-secure-local-id))
(toplevel (note-memoized-function 'c-backend-local-variable-name))
(toplevel (note-memoized-function 'c-backend-compute-global-variable-name))
(toplevel (note-memoized-function 'c-backend-computed-function-name))
(toplevel (note-funcall-helper-function 'translator-ret-form-p))
(toplevel (note-funcall-helper-function 'translator-ret-to-throw))
