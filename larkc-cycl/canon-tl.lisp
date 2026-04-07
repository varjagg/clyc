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

;; The only caller of this is from ke.lisp, which transforms HL before adding to the transcript queue,
;; so TL is likely "Transcript Level".

;;; ======================================================================
;;; Variables
;;; ======================================================================

(defparameter *el-var-names* nil
  "[Cyc] EL var names of current assertion being translated to TL.")

;;; ======================================================================
;;; Functions (ordered by declare section)
;;; ======================================================================

;; (defun assertion-tl-formula (assertion) ...) -- no body, commented declareFunction
;; (defun assertion-tl-ist-formula (assertion) ...) -- no body, commented declareFunction
;; (defun convert-assertions-to-tl-ist-formulas (assertions) ...) -- no body, commented declareFunction
;; (defun assertion-tl-formulas (assertion) ...) -- no body, commented declareFunction
;; (defun assertion-tl-ist-formulas (assertion) ...) -- no body, commented declareFunction
;; (defun sibling-tl-assertions (assertion) ...) -- no body, commented declareFunction
;; (defun assertion-tl-ist-formula-int (assertion) ...) -- no body, commented declareFunction
;; (defun assertion-tl-formula-int (assertion) ...) -- no body, commented declareFunction
;; (defun assertion-tl-cnf (assertion) ...) -- no body, commented declareFunction

(defun transform-hl-terms-to-tl (tree)
  "[Cyc] Transform HL terms in TREE to their TL equivalents."
  (quiescent-transform tree #'hl-not-tl-term? #'hl-term-to-tl))

(defun tl-encapsulate (tree)
  "[Cyc] Encapsulate TREE after transforming HL terms to TL."
  (encapsulate (transform-hl-terms-to-tl tree)))

;; (defun find-assertion-from-tl-formula (formula mt) ...) -- no body, commented declareFunction
;; (defun find-assertions-from-tl-formula (formula mt) ...) -- no body, commented declareFunction
;; (defun find-assertion-from-tl-cnf-ist-formula (formula) ...) -- no body, commented declareFunction
;; (defun find-assertion-from-tl-cnf-formula (formula mt) ...) -- no body, commented declareFunction
;; (defun tl-formula-to-hl-cnf (formula) ...) -- no body, commented declareFunction

(defun tlmt-to-hlmt (tl-mt)
  "[Cyc] Convert a TL microtheory to an HL microtheory."
  (transform-tl-terms-to-hl tl-mt))

(defun transform-tl-terms-to-hl (tree)
  "[Cyc] Transform TL terms in TREE to their HL equivalents."
  (quiescent-transform tree #'tl-term? #'tl-term-to-hl))

;; (defun tl-formula-to-cnf-int (formula) ...) -- no body, commented declareFunction

(defun tl-term? (object)
  "[Cyc] Return T iff OBJECT is a TL term (assertion, function, or variable)."
  (or (tl-assertion-term? object)
      (tl-function-term? object)
      (tl-var? object)))

(defun tl-assertion-term? (object)
  "[Cyc] Return T iff OBJECT is a TL assertion term (#$TLAssertionFn)."
  (when (and (possibly-naut-p object)
             (eql #$TLAssertionFn (naut-functor object))
             ;; missing-larkc 30519 likely checks naut arity, ensuring
             ;; TLAssertionFn has the correct number of arguments
             (missing-larkc 30519))
    (let (;; missing-larkc 29817 likely extracts arg1 of the naut
          ;; (the assertion ID or identifier)
          (arg1 (missing-larkc 29817))
          ;; missing-larkc 29820 likely extracts arg2 of the naut
          ;; (the EL formula of the assertion)
          (arg2 (missing-larkc 29820)))
      (declare (ignore arg1))
      (and ;; missing-larkc 30626 likely validates arg1 as an integer
           ;; or valid assertion identifier
           (missing-larkc 30626)
           (el-formula-p arg2)))))

(defun tl-function-term? (object)
  "[Cyc] Return T iff OBJECT is a TL function term (#$TLReifiedNatFn)."
  (when (and (possibly-naut-p object)
             (eql #$TLReifiedNatFn (naut-functor object))
             ;; missing-larkc 30520 likely checks naut arity for TLReifiedNatFn
             (missing-larkc 30520))
    (let (;; missing-larkc 29818 likely extracts arg1 of the naut
          ;; (the NAT formula)
          (arg1 (missing-larkc 29818)))
      (possibly-naut-p arg1))))

(defun tl-var? (object)
  "[Cyc] Return T iff OBJECT is a TL variable (#$TLVariableFn)."
  (when (and (possibly-naut-p object)
             (eql #$TLVariableFn (naut-functor object))
             ;; missing-larkc 30521 likely checks naut arity for TLVariableFn
             (missing-larkc 30521))
    (let (;; missing-larkc 29819 likely extracts arg1 of the naut
          ;; (the variable index, an integer)
          (arg1 (missing-larkc 29819))
          ;; missing-larkc 29821 likely extracts arg2 of the naut
          ;; (the variable name, a string or NIL)
          (arg2 (missing-larkc 29821)))
      (and (integerp arg1)
           (or (stringp arg2)
               (null arg2))))))

(defun hl-not-tl-term? (object)
  "[Cyc] Return T iff OBJECT is an HL term that is not a TL term."
  (or (assertion-p object)
      (nart-p object)
      (variable-p object)))

;; (defun hl-term-to-tl (object) ...) -- no body, commented declareFunction
;; (defun hl-assertion-term-to-tl (object) ...) -- no body, commented declareFunction
;; (defun hl-function-term-to-tl (object) ...) -- no body, commented declareFunction
;; (defun hl-var-to-tl (object &optional name) ...) -- no body, commented declareFunction
;; (defun tl-quotify (object) ...) -- no body, commented declareFunction
;; (defun tl-term-to-hl (object) ...) -- no body, commented declareFunction
;; (defun tl-assertion-term-to-hl (object) ...) -- no body, commented declareFunction
;; (defun tl-function-term-to-hl (object) ...) -- no body, commented declareFunction
;; (defun tl-var-to-hl (object) ...) -- no body, commented declareFunction
;; (defun tl-term-to-el (object) ...) -- no body, commented declareFunction
;; (defun tl-assertion-term-to-el (object) ...) -- no body, commented declareFunction
;; (defun tl-function-term-to-el (object) ...) -- no body, commented declareFunction
;; (defun tl-var-to-el (object) ...) -- no body, commented declareFunction
;; (defun tl-find-nart (object) ...) -- no body, commented declareFunction
;; (defun tl-nart-substitute (object) ...) -- no body, commented declareFunction
;; (defun assertion-findable-via-tl? (assertion) ...) -- no body, commented declareFunction
;; (defun assertion-unassertible-via-tl? (assertion) ...) -- no body, commented declareFunction
;; (defun assertion-unassertible-via-tl-fast? (assertion) ...) -- no body, commented declareFunction
;; (defun duplicate-assertion? (assertion) ...) -- no body, commented declareFunction
;; (defun unassert-assertion-via-tl (assertion) ...) -- no body, commented declareFunction
;; (defun unassert-tl-formula (formula mt) ...) -- no body, commented declareFunction

;;; ======================================================================
;;; Setup phase
;;; ======================================================================

(toplevel
  (register-kb-function 'tl-assertion-term-to-el)
  (register-kb-function 'tl-function-term-to-el)
  (register-kb-function 'tl-var-to-el))

;;; ======================================================================
;;; Orphan Internal Constants
;;; Used only in commented-out function bodies (stripped from LarKC)
;;; ======================================================================

;; $sym0$ASSERTION_P = makeSymbol("ASSERTION-P") -- used in commented assertion-tl-* functions
;; $sym1$ASSERTION_TL_IST_FORMULA = makeSymbol("ASSERTION-TL-IST-FORMULA") -- used in commented convert-assertions-to-tl-ist-formulas
;; $const2$ist = #$ist -- used in commented assertion-tl-ist-formula-int
;; $const5$and = #$and -- used in commented tl-formula-to-cnf-int or assertion-tl-cnf
;; $const8$implies = #$implies -- used in commented tl-formula-to-cnf-int or assertion-tl-cnf
;; $const9$or = #$or -- used in commented tl-formula-to-cnf-int or assertion-tl-cnf
;; $const10$not = #$not -- used in commented tl-formula-to-cnf-int or assertion-tl-cnf
;; $str14$referenced_assertion_not_found___ = "referenced assertion not found: ~%  ~s" -- error msg in commented tl-assertion-term-to-hl
;; $str15$referenced_function_not_found____ = "referenced function not found: ~%  ~s" -- error msg in commented tl-function-term-to-hl
;; $sym16$QUOTE = makeSymbol("QUOTE") -- used in commented tl-quotify
;; $str17$referenced_TL_assertion_not_found = "referenced TL assertion not found: ~%  ~s" -- error msg in commented tl-assertion-term-to-el
;; $str18$referenced_TL_nart_not_found_____ = "referenced TL nart not found: ~%  ~s" -- error msg in commented tl-function-term-to-el
;; $sym22$CONSP = makeSymbol("CONSP") -- used in commented unassert-assertion-via-tl or duplicate-assertion?
;; $sym23$CATCH_ERROR_MESSAGE_HANDLER = makeSymbol("CATCH-ERROR-MESSAGE-HANDLER") -- used in commented find-assertion-from-tl-cnf-formula
;; $kw24$ASSERTION_NOT_PRESENT = :assertion-not-present -- used in commented find-assertion-from-tl-cnf-formula
;; $str25$formula__S_in_mt__S_cannot_be_fou = "formula ~S in mt ~S cannot be found" -- error in commented find-assertion-from-tl-cnf-formula
;; $kw26$ASSERTION_NOT_LOCAL = :assertion-not-local -- used in commented find-assertion-from-tl-cnf-formula
;; $str27$CNF__S_in_mt__S_is_not_locally_in = "CNF ~S in mt ~S is not locally in the KB" -- error in commented find-assertion-from-tl-cnf-formula
