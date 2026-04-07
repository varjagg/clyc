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

;; ---------------------------------------------------------------------------
;; RED-DEF-HELPER — allocates a red-symbol via red-infrastructure primitives,
;; registers it, and returns its current red-value. Used by all 24
;; DEFINE-RED-* macros as the initialization expression for their variable.
;;
;; Java reference: red_infrastructure_macros.red_def_helper (active declareFunction
;; with body, position 17262). Calls new-red-symbol, register-red, red-value from
;; the (currently unported) red-infrastructure file.

(defun red-def-helper (key name defaultvalue ltype &optional (valuetype :simple))
  (let ((red-sym (new-red-symbol key name defaultvalue ltype valuetype)))
    (register-red red-sym)
    (red-value red-sym)))

;; (defun red-reinitialize-variable-helper (name) ...) -- commented declareFunction, no body
;; (defun red-infa-unit-test () ...) -- commented declareFunction, no body

;; ---------------------------------------------------------------------------
;; DEFINE-RED-* macros
;;
;; Reconstructed from Internal Constants:
;;   $list0 = (KEY NAME DEFAULTVALUE DESCRIPTION)  — macro arglist
;;   $sym2$RED-DEF-HELPER                          — the helper called in the expansion
;;   $sym3$FIF, $sym4$SYMBOLP, $sym5$QUOTE, $sym6$SYMBOL-VALUE
;;                                                  — (fif (symbolp 'x) (symbol-value 'x) 'x)
;;                                                    pattern that lets KEY and DEFAULTVALUE
;;                                                    be either a symbol whose value to use,
;;                                                    or a literal value
;;   $sym1$DEFPARAMETER-PUBLIC  .. $sym9$DEFPARAMETER-PRIVATE
;;   $sym10$DEFLEXICAL-PUBLIC   .. $sym13$DEFLEXICAL-PRIVATE
;;   $sym14$DEFGLOBAL-PUBLIC    .. $sym17$DEFGLOBAL-PRIVATE
;;   $sym18$DEFVAR-PUBLIC       .. $sym21$DEFVAR-PRIVATE
;;                                                  — access-macros wrappers for each
;;                                                    storage class × access level
;;   $list7  = (:PARAMETER)                         — base ltype lists, passed as the
;;   $list11 = (:LEXICAL)                             fourth argument to red-def-helper
;;   $list15 = (:GLOBAL)                              (each macro fixes the ltype)
;;   $list19 = (:VAR)
;;   $list22 = (:PARAMETER :LIST)                   — list-variant ltype lists; the
;;   $list23 = (:LEXICAL :LIST)                       DEFINE-RED-LIST-* macros pass
;;   $list24 = (:GLOBAL :LIST)                        these instead of the plain ltypes
;;   $list25 = (:VAR :LIST)
;;   $list28 = list of all 24 DEFINE-RED-* names    — the macros register RED-DEF-HELPER
;;                                                    as their helper in setup phase
;;
;; Post-expansion evidence from init_red_infrastructure_macros_file():
;;   $reddef_par_prvt$ = defparameter("REDDEF-PAR-PRVT",
;;                         red_def_helper(
;;                           fif(symbolp(*RED-INFRASTRUCTURE-TEST-KEY*),
;;                               symbol_value(*RED-INFRASTRUCTURE-TEST-KEY*),
;;                               *RED-INFRASTRUCTURE-TEST-KEY*),
;;                           REDDEF-PAR-PRVT,
;;                           fif(symbolp(*RED-INFRASTRUCTURE-TEST-DEFAULT*),
;;                               symbol_value(*RED-INFRASTRUCTURE-TEST-DEFAULT*),
;;                               *RED-INFRASTRUCTURE-TEST-DEFAULT*),
;;                           :PARAMETER,
;;                           UNPROVIDED));
;;   — the outermost call site is a plain defparameter because the access-qualifier
;;     macro (defparameter-private) was also expanded inline at compile time. The
;;     macro source form we restore uses defparameter-private so that the access
;;     annotation is visible and preserved.
;;
;; The DESCRIPTION argument is not referenced anywhere in the expansion; it serves
;; solely as a human-readable doc slot on the original source call, matched by the
;; "dummy doc info" Javadoc placed on each generated variable in the Java output.

(defmacro define-red-parameter-public (key name defaultvalue description)
  (declare (ignore description))
  `(defparameter-public ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :parameter)))

(defmacro define-red-parameter-protected (key name defaultvalue description)
  (declare (ignore description))
  `(defparameter-protected ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :parameter)))

(defmacro define-red-parameter-private (key name defaultvalue description)
  (declare (ignore description))
  `(defparameter-private ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :parameter)))

(defmacro define-red-lexical-public (key name defaultvalue description)
  (declare (ignore description))
  `(deflexical-public ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :lexical)))

(defmacro define-red-lexical-protected (key name defaultvalue description)
  (declare (ignore description))
  `(deflexical-protected ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :lexical)))

(defmacro define-red-lexical-private (key name defaultvalue description)
  (declare (ignore description))
  `(deflexical-private ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :lexical)))

(defmacro define-red-global-public (key name defaultvalue description)
  (declare (ignore description))
  `(defglobal-public ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :global)))

(defmacro define-red-global-protected (key name defaultvalue description)
  (declare (ignore description))
  `(defglobal-protected ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :global)))

(defmacro define-red-global-private (key name defaultvalue description)
  (declare (ignore description))
  `(defglobal-private ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :global)))

(defmacro define-red-var-public (key name defaultvalue description)
  (declare (ignore description))
  `(defvar-public ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :var)))

(defmacro define-red-var-protected (key name defaultvalue description)
  (declare (ignore description))
  `(defvar-protected ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :var)))

(defmacro define-red-var-private (key name defaultvalue description)
  (declare (ignore description))
  `(defvar-private ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     :var)))

(defmacro define-red-list-parameter-public (key name defaultvalue description)
  (declare (ignore description))
  `(defparameter-public ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:parameter :list))))

(defmacro define-red-list-parameter-protected (key name defaultvalue description)
  (declare (ignore description))
  `(defparameter-protected ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:parameter :list))))

(defmacro define-red-list-parameter-private (key name defaultvalue description)
  (declare (ignore description))
  `(defparameter-private ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:parameter :list))))

(defmacro define-red-list-lexical-public (key name defaultvalue description)
  (declare (ignore description))
  `(deflexical-public ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:lexical :list))))

(defmacro define-red-list-lexical-protected (key name defaultvalue description)
  (declare (ignore description))
  `(deflexical-protected ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:lexical :list))))

(defmacro define-red-list-lexical-private (key name defaultvalue description)
  (declare (ignore description))
  `(deflexical-private ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:lexical :list))))

(defmacro define-red-list-global-public (key name defaultvalue description)
  (declare (ignore description))
  `(defglobal-public ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:global :list))))

(defmacro define-red-list-global-protected (key name defaultvalue description)
  (declare (ignore description))
  `(defglobal-protected ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:global :list))))

(defmacro define-red-list-global-private (key name defaultvalue description)
  (declare (ignore description))
  `(defglobal-private ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:global :list))))

(defmacro define-red-list-var-public (key name defaultvalue description)
  (declare (ignore description))
  `(defvar-public ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:var :list))))

(defmacro define-red-list-var-protected (key name defaultvalue description)
  (declare (ignore description))
  `(defvar-protected ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:var :list))))

(defmacro define-red-list-var-private (key name defaultvalue description)
  (declare (ignore description))
  `(defvar-private ,name
     (red-def-helper (fif (symbolp ',key) (symbol-value ',key) ',key)
                     ',name
                     (fif (symbolp ',defaultvalue) (symbol-value ',defaultvalue) ',defaultvalue)
                     '(:var :list))))

;; ---------------------------------------------------------------------------
;; RED-REINITIALIZE-VARIABLE macro
;;
;; Reconstructed from Internal Constants:
;;   $list26 = (NAME)                                  — macro arglist
;;   $sym27$RED-REINITIALIZE-VARIABLE-HELPER           — the helper function (no body,
;;                                                       ported as comment stub above)
;;   $sym30$RED-REINITIALIZE-VARIABLE                   — the macro name itself
;;   register_macro_helper(RED-REINITIALIZE-VARIABLE-HELPER, RED-REINITIALIZE-VARIABLE)
;;                                                     — paired in setup phase
;;
;; No visible expansion sites in other Java files. The macro simply wraps a call
;; to its helper, quoting its variable name. Since the helper is body-stripped
;; (missing-larkc), the macro expansion goes through the helper at runtime.

(defmacro red-reinitialize-variable (name)
  `(red-reinitialize-variable-helper ',name))

;; ---------------------------------------------------------------------------
;; Test variables (all defined by red-def-helper through the macros above)

(defconstant-private *red-infrastructure-test-key* '("redtest.crtl.worldfile"))

(defconstant-private *red-infrastructure-test-default* "dflt")

(defconstant-private *red-infrastructure-test-red-value* "/cyc/CycC/Linux/head/run/world/latest.load")

;; dummy doc info
(define-red-lexical-private *red-infrastructure-test-key* reddef-lex-prvt-2 "dflt" nil)

;; dummy doc info
(define-red-lexical-private *red-infrastructure-test-key* reddef-lex-prvt *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-lexical-protected *red-infrastructure-test-key* reddef-lex-prot *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-lexical-public *red-infrastructure-test-key* reddef-lex-publ *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-parameter-private *red-infrastructure-test-key* reddef-par-prvt *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-parameter-protected *red-infrastructure-test-key* reddef-par-prot *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-parameter-public *red-infrastructure-test-key* reddef-par-publ *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-var-private *red-infrastructure-test-key* reddef-var-prvt *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-var-protected *red-infrastructure-test-key* reddef-var-prot *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-var-public *red-infrastructure-test-key* reddef-var-publ *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-global-private *red-infrastructure-test-key* reddef-gbl-prvt *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-global-protected *red-infrastructure-test-key* reddef-gbl-prot *red-infrastructure-test-default* nil)

;; dummy doc info
(define-red-global-public *red-infrastructure-test-key* reddef-gbl-publ *red-infrastructure-test-default* nil)

;; ---------------------------------------------------------------------------
;; Setup

(toplevel
  (register-macro-helper 'red-def-helper
                         '(define-red-parameter-public define-red-parameter-protected define-red-parameter-private
                           define-red-lexical-public define-red-lexical-protected define-red-lexical-private
                           define-red-global-public define-red-global-protected define-red-global-private
                           define-red-var-public define-red-var-protected define-red-var-private
                           define-red-list-parameter-public define-red-list-parameter-protected define-red-list-parameter-private
                           define-red-list-lexical-public define-red-list-lexical-protected define-red-list-lexical-private
                           define-red-list-global-public define-red-list-global-protected define-red-list-global-private
                           define-red-list-var-public define-red-list-var-protected define-red-list-var-private))
  (register-macro-helper 'red-reinitialize-variable-helper 'red-reinitialize-variable)
  (declare-defglobal 'reddef-gbl-prvt)
  (declare-defglobal 'reddef-gbl-prot)
  (declare-defglobal 'reddef-gbl-publ))
