#|
  Copyright (c) 2019 White Flame

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

;; register-macro-helper is already in subl-support.lisp — not re-declared here.

;; Access-level macros for SubL.
;;
;; In SubL, these macros annotated functions and variables with visibility
;; levels (PUBLIC, PROTECTED, PRIVATE) via (proclaim '(faccess ...)) and
;; (proclaim '(vaccess ...)).  In Common Lisp, proclaim ignores unknown
;; declaration specifiers, so those annotations are no-ops here.  The primary
;; effect of these macros is to define the function or variable via the
;; appropriate underlying form.
;;
;; Macro-body reconstruction notes (from access_macros.java constants):
;;   - Function macros use DEFINE (→ defun), DEFMACRO, and PROCLAIM+FACCESS
;;   - Variable macros use DEFCONSTANT/DEFLEXICAL/DEFPARAMETER/DEFGLOBAL/DEFVAR
;;     and PROCLAIM+VACCESS
;;   - *-macro-helper variants additionally call REGISTER-MACRO-HELPER
;;   - *-external variants additionally call REGISTER-EXTERNAL-SYMBOL
;;   - define-obsolete calls DEFINE-OBSOLETE-REGISTER and uses DEFINE-PROTECTED
;;   - defmacro-obsolete expands to a defmacro that warns at expansion time

;; ---------------------------------------------------------------------------
;; Utility

;; (defun symbol-or-symbol-list-p (x) ...) -- commented declaration, no body; likely validates :macro/:replacements args

;; ---------------------------------------------------------------------------
;; Function access macros  (arglist: NAME ARGLIST &BODY BODY)
;;
;; Expansion (reconstructed):
;;   (progn (proclaim '(faccess <level> name)) (define name arglist . body))

(defmacro define-public (name arglist &body body)
  `(progn
     (proclaim '(faccess public ,name))
     (defun ,name ,arglist ,@body)))

(defmacro define-protected (name arglist &body body)
  `(progn
     (proclaim '(faccess protected ,name))
     (defun ,name ,arglist ,@body)))

(defmacro define-private (name arglist &body body)
  `(progn
     (proclaim '(faccess private ,name))
     (defun ,name ,arglist ,@body)))

;; define-macro-helper  (arglist: NAME ARGLIST (&KEY MACRO) &BODY BODY)
;; Expansion: register the helper, then define-protected
;; Error if :macro not provided.
;; Java evidence: $kw11$ALLOW_OTHER_KEYS present → the (&key macro) destructuring
;; used &allow-other-keys to permit unknown keyword arguments without error.

(defmacro define-macro-helper (name arglist (&key macro &allow-other-keys) &body body)
  (unless macro
    (error "Macro or list of macros must be specified, not ~a" macro))
  `(progn
     (register-macro-helper ',name ',macro)
     (define-protected ,name ,arglist ,@body)))

;; ---------------------------------------------------------------------------
;; Macro access macros  (arglist: NAME PATTERN &BODY BODY)
;;
;; Expansion (reconstructed):
;;   (progn (proclaim '(faccess <level> name)) (defmacro name pattern . body))

(defmacro defmacro-public (name pattern &body body)
  `(progn
     (proclaim '(faccess public ,name))
     (defmacro ,name ,pattern ,@body)))

(defmacro defmacro-protected (name pattern &body body)
  `(progn
     (proclaim '(faccess protected ,name))
     (defmacro ,name ,pattern ,@body)))

(defmacro defmacro-private (name pattern &body body)
  `(progn
     (proclaim '(faccess private ,name))
     (defmacro ,name ,pattern ,@body)))

;; defmacro-macro-helper  (arglist: NAME PATTERN (&KEY MACRO) &BODY BODY)
;; Shares $kw11$ALLOW_OTHER_KEYS with define-macro-helper — same &allow-other-keys treatment.

(defmacro defmacro-macro-helper (name pattern (&key macro &allow-other-keys) &body body)
  (unless macro
    (error "Macro or list of macros must be specified, not ~a" macro))
  `(progn
     (register-macro-helper ',name ',macro)
     (defmacro-protected ,name ,pattern ,@body)))

;; ---------------------------------------------------------------------------
;; defconstant access macros  (arglist: VARIABLE INITIALIZATION &OPTIONAL DOCUMENTATION)

(defmacro defconstant-public (variable initialization &optional documentation)
  `(progn
     (proclaim '(vaccess public ,variable))
     (defconstant ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro defconstant-protected (variable initialization &optional documentation)
  `(progn
     (proclaim '(vaccess protected ,variable))
     (defconstant ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro defconstant-private (variable initialization &optional documentation)
  `(progn
     (proclaim '(vaccess private ,variable))
     (defconstant ,variable ,initialization ,@(and documentation (list documentation)))))

;; ---------------------------------------------------------------------------
;; deflexical access macros  (arglist: VARIABLE &OPTIONAL INITIALIZATION DOCUMENTATION)

(defmacro deflexical-public (variable &optional initialization documentation)
  `(progn
     (proclaim '(vaccess public ,variable))
     (deflexical ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro deflexical-protected (variable &optional initialization documentation)
  `(progn
     (proclaim '(vaccess protected ,variable))
     (deflexical ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro deflexical-private (variable &optional initialization documentation)
  `(progn
     (proclaim '(vaccess private ,variable))
     (deflexical ,variable ,initialization ,@(and documentation (list documentation)))))

;; ---------------------------------------------------------------------------
;; defparameter access macros  (arglist: VARIABLE INITIALIZATION &OPTIONAL DOCUMENTATION)

(defmacro defparameter-public (variable initialization &optional documentation)
  `(progn
     (proclaim '(vaccess public ,variable))
     (defparameter ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro defparameter-protected (variable initialization &optional documentation)
  `(progn
     (proclaim '(vaccess protected ,variable))
     (defparameter ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro defparameter-private (variable initialization &optional documentation)
  `(progn
     (proclaim '(vaccess private ,variable))
     (defparameter ,variable ,initialization ,@(and documentation (list documentation)))))

;; defparameter-macro-helper  (arglist: VARIABLE (&KEY MACRO) &OPTIONAL INITIALIZATION DOCUMENTATION)
;; Called as: (defparameter-macro-helper *var* (:macro some-macro) init)
;; Shares $kw11$ALLOW_OTHER_KEYS — &allow-other-keys in (&key macro) destructuring.
;; Java setup phase: meta_macros.declare_indention_pattern(DEFPARAMETER-MACRO-HELPER, (VARIABLE &BODY BODY))
;; → indentation hint: first arg (variable) is a value; the rest indent as body code.
(defmacro defparameter-macro-helper (variable (&key macro &allow-other-keys) &optional initialization documentation)
  (unless macro
    (error "Macro or list of macros must be specified, not ~a" macro))
  `(progn
     (register-macro-helper ',variable ',macro)
     (defparameter-protected ,variable ,initialization ,@(and documentation (list documentation)))))

;; ---------------------------------------------------------------------------
;; defglobal access macros  (arglist: VARIABLE INITIALIZATION &OPTIONAL DOCUMENTATION)

(defmacro defglobal-public (variable initialization &optional documentation)
  `(progn
     (proclaim '(vaccess public ,variable))
     (defglobal ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro defglobal-protected (variable initialization &optional documentation)
  `(progn
     (proclaim '(vaccess protected ,variable))
     (defglobal ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro defglobal-private (variable initialization &optional documentation)
  `(progn
     (proclaim '(vaccess private ,variable))
     (defglobal ,variable ,initialization ,@(and documentation (list documentation)))))

;; ---------------------------------------------------------------------------
;; defvar access macros  (arglist: VARIABLE &OPTIONAL INITIALIZATION DOCUMENTATION)

(defmacro defvar-public (variable &optional initialization documentation)
  `(progn
     (proclaim '(vaccess public ,variable))
     (defvar ,variable ,@(and initialization (list initialization)) ,@(and documentation (list documentation)))))

(defmacro defvar-protected (variable &optional initialization documentation)
  `(progn
     (proclaim '(vaccess protected ,variable))
     (defvar ,variable ,@(and initialization (list initialization)) ,@(and documentation (list documentation)))))

(defmacro defvar-private (variable &optional initialization documentation)
  `(progn
     (proclaim '(vaccess private ,variable))
     (defvar ,variable ,@(and initialization (list initialization)) ,@(and documentation (list documentation)))))

;; ---------------------------------------------------------------------------
;; Obsolete function/macro support
;;
;; define-obsolete  (arglist: NAME ARGLIST (&KEY REPLACEMENTS) &BODY BODY)
;; Expansion: call define-obsolete-register, then define-protected.

(defun define-obsolete-register (v-obsolete replacements)
  "[Cyc] Register V-OBSOLETE as an obsolete function with REPLACEMENTS. Returns V-OBSOLETE."
  (declare (ignore replacements))
  v-obsolete)

(defmacro define-obsolete (name arglist (&key replacements) &body body)
  (unless replacements
    (error "Method or list of methods must be specified, not ~a" replacements))
  `(progn
     (define-obsolete-register ',name ',replacements)
     (define-protected ,name ,arglist ,@body)))

;; (defun defmacro-obsolete-warning (name replacements) ...) -- commented declaration, no body

;; (defmacro defmacro-obsolete (name pattern (&key replacements) &body body) ...) -- in original Cyc, not in LarKC
;;   arglist: (NAME PATTERN (&KEY REPLACEMENTS) &BODY BODY) from $list37
;;   expansion: calls define-obsolete-register, then defmacro-protected with expansion-time warn via defmacro-obsolete-warning

;; ---------------------------------------------------------------------------
;; External symbol registry
;;
;; *external-symbols* tracks all symbols marked as externally accessible.

(defglobal *external-symbols* (make-hash-table :size 400 :test #'eq)
  "[Cyc] Hash table of externally-accessible symbols.")

(defun register-external-symbol (symbol)
  "[Cyc] Mark SYMBOL as externally accessible. Returns SYMBOL."
  (setf (gethash symbol *external-symbols*) t)
  symbol)

;; (defun external-symbol-p (symbol) ...) -- commented declaration, no body
;; (defun external-function-p (symbol) ...) -- commented declaration, no body
;; (defun external-macro-p (symbol) ...) -- commented declaration, no body
;; (defun all-external-symbols () ...) -- commented declaration, no body

;; ---------------------------------------------------------------------------
;; External access macros — define-* plus register-external-symbol
;;
;; These combine the access-qualifier macros with external registration.

(defmacro define-external (name arglist &body body)
  `(progn
     (register-external-symbol ',name)
     (define-public ,name ,arglist ,@body)))

(defmacro defmacro-external (name pattern &body body)
  `(progn
     (register-external-symbol ',name)
     (defmacro-public ,name ,pattern ,@body)))

(defmacro defconstant-external (variable initialization &optional documentation)
  `(progn
     (register-external-symbol ',variable)
     (defconstant-public ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro deflexical-external (variable &optional initialization documentation)
  `(progn
     (register-external-symbol ',variable)
     (deflexical-public ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro defparameter-external (variable initialization &optional documentation)
  `(progn
     (register-external-symbol ',variable)
     (defparameter-public ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro defglobal-external (variable initialization &optional documentation)
  `(progn
     (register-external-symbol ',variable)
     (defglobal-public ,variable ,initialization ,@(and documentation (list documentation)))))

(defmacro defvar-external (variable &optional initialization documentation)
  `(progn
     (register-external-symbol ',variable)
     (defvar-public ,variable ,@(and initialization (list initialization)) ,@(and documentation (list documentation)))))

;; ---------------------------------------------------------------------------
;; *external-access-methods* — the list of all access-qualifier macro names.
;; Populated at startup; each is registered as an external symbol.

(deflexical *external-access-methods*
    '(define-private define-protected define-public
      define-macro-helper
      defmacro-private defmacro-protected defmacro-public
      defmacro-macro-helper
      defconstant-private defconstant-protected defconstant-public
      deflexical-private deflexical-protected deflexical-public
      defglobal-private defglobal-protected defglobal-public
      defparameter-private defparameter-protected defparameter-public
      defvar-private defvar-protected defvar-public)
  "[Cyc] List of all access-qualifier macro names, each of which is an external symbol.")

;; Register all access-qualifier macros as external symbols (setup phase).
(dolist (sym *external-access-methods*)
  (register-external-symbol sym))

;; Indentation hint for defparameter-macro-helper: variable is a value, rest is body.
(declare-indention-pattern 'defparameter-macro-helper '(variable &body body))

;; ---------------------------------------------------------------------------
;; Java evidence ($kw57$MACRO_HELPER_FOR): in Java, register-macro-helper stored the
;; macro list on the helper symbol's plist under :macro-helper-for. This port uses the
;; *macro-helpers* alist in subl-support.lisp instead.
;;
;; (defun macro-helper-for-macro? (helper macro) ...) -- commented declaration, no body
;; (defun macro-helper-for-any-of-macros? (helper macros) ...) -- commented declaration, no body
