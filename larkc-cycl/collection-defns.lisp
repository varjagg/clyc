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

(deflexical *subl-functions-used-as-collection-defns*
  '(stringp integerp keywordp listp symbolp true false)
  "[Cyc] SubL functions used as collection defns.")

(deflexical *cycl-functions-used-as-collection-defns*
  '(cycl-constant-p cycl-variable-p el-variable-p hl-variable-p
    cycl-denotational-term-p el-relation-expression? gaf?
    string-w/o-control-chars? url-p)
  "[Cyc] CycL functions used as collection defns.")

(defun cyc-individual-necessary (object)
  "[Cyc] #$defnNecessary for #$Individual"
  (if (and (fort-p object)
           (collection? object))
      nil
      t))

;; (defun cycl-expression? (object) ...) -- active declaration, no body
;; (defun el-expression? (object) ...) -- active declaration, no body
;; (defun hl-expression-p (object) ...) -- active declaration, no body
;; (defun cycl-open-denotational-term? (object) ...) -- active declaration, no body
;; (defun cycl-closed-denotational-term? (object) ...) -- active declaration, no body
;; (defun cycl-reifiable-denotational-term? (object) ...) -- active declaration, no body
;; (defun cycl-reified-denotational-term? (object) ...) -- active declaration, no body
;; (defun hl-closed-denotational-term-p (object) ...) -- active declaration, no body
;; (defun cycl-represented-atomic-term-p (object) ...) -- active declaration, no body
;; (defun cycl-represented-term? (object) ...) -- active declaration, no body
;; (defun cyc-system-term-p (object) ...) -- active declaration, no body
;; (defun cyc-system-character-p (object) ...) -- active declaration, no body

;; TODO - stringp? or are there other implications on this?
(defun cyc-system-string-p (object)
  "[Cyc] defnIff for #$SubLString"
  (subl-string-p object))

;; (defun cyc-system-real-number-p (object) ...) -- active declaration, no body
;; (defun cyc-system-non-variable-symbol-p (object) ...) -- active declaration, no body

(defun cycl-subl-symbol-p (object)
  "[Cyc] defnIff for CycLSubLSymbol"
  (when (el-formula-p object)
    (and (subl-quote-p object)
         (symbolp (formula-arg1 object)))))

;; (defun cycl-atomic-term-p (object) ...) -- active declaration, no body
;; (defun cycl-closed-atomic-term-p (object) ...) -- active declaration, no body
;; (defun hl-non-atomic-term-p (object) ...) -- active declaration, no body
;; (defun cycl-non-atomic-term? (object) ...) -- active declaration, no body
;; (defun el-non-atomic-term? (object) ...) -- active declaration, no body
;; (defun hl-indexed-term-p (object) ...) -- active declaration, no body
;; (defun cycl-indexed-term? (object) ...) -- active declaration, no body
;; (defun cycl-open-non-atomic-term? (object) ...) -- active declaration, no body
;; (defun cycl-closed-non-atomic-term? (object) ...) -- active declaration, no body
;; (defun cycl-reifiable-non-atomic-term? (object) ...) -- active declaration, no body
;; (defun cycl-non-atomic-reified-term? (object) ...) -- active declaration, no body
;; (defun el-reifiable-non-atomic-term? (object) ...) -- active declaration, no body
;; (defun cycl-closed-expression? (object) ...) -- active declaration, no body
;; (defun cycl-open-expression? (object) ...) -- active declaration, no body
;; (defun cycl-formula? (object) ...) -- active declaration, no body
;; (defun cycl-open-formula? (object) ...) -- active declaration, no body
;; (defun cycl-closed-formula? (object) ...) -- active declaration, no body

(defun hl-formula-p (object)
  "[Cyc] defnIff for HLFormula"
  (or (nart-p object)
      (assertion-p object)))

;; (defun cycl-unbound-relation-formula-p (object) ...) -- active declaration, no body
;; (defun cycl-sentence? (object) ...) -- active declaration, no body
;; (defun cycl-open-sentence? (object) ...) -- active declaration, no body
;; (defun cycl-closed-sentence? (object) ...) -- active declaration, no body
;; (defun cyc-typicality-reference-set-property? (object) ...) -- active declaration, no body (missing-larkc 31364)
;; (defun el-sentence? (object) ...) -- active declaration, no body
;; (defun cycl-atomic-sentence? (object) ...) -- active declaration, no body
;; (defun cycl-closed-atomic-sentence? (object) ...) -- active declaration, no body
;; (defun cycl-propositional-sentence? (object) ...) -- active declaration, no body
;; (defun cycl-sentence-askable? (object) ...) -- active declaration, no body
;; (defun cycl-sentence-assertible? (object) ...) -- active declaration, no body (missing-larkc 31382)
;; (defun el-sentence-askable? (object) ...) -- active declaration, no body
;; (defun el-sentence-assertible? (object) ...) -- active declaration, no body
;; (defun cycl-non-atomic-term-askable? (object) ...) -- active declaration, no body
;; (defun cycl-non-atomic-term-assertible? (object) ...) -- active declaration, no body
;; (defun el-non-atomic-term-askable? (object) ...) -- active declaration, no body
;; (defun el-non-atomic-term-assertible? (object) ...) -- active declaration, no body
;; (defun cycl-expression-askable? (object) ...) -- active declaration, no body
;; (defun cycl-expression-assertible? (object) ...) -- active declaration, no body
;; (defun el-expression-askable? (object) ...) -- active declaration, no body
;; (defun el-expression-assertible? (object) ...) -- active declaration, no body
;; (defun cycl-query? (object) ...) -- active declaration, no body
;; (defun cycl-assertion? (object) ...) -- active declaration, no body
;; (defun cycl-atomic-assertion? (object) ...) -- active declaration, no body
;; (defun cycl-gaf-assertion? (object) ...) -- active declaration, no body
;; (defun cycl-rule-assertion? (object) ...) -- active declaration, no body
;; (defun cycl-asserted-assertion? (object) ...) -- active declaration, no body
;; (defun cycl-deduced-assertion? (object) ...) -- active declaration, no body
;; (defun cycl-nl-semantic-assertion? (object) ...) -- active declaration, no body
;; (defun cycl-canonicalizer-directive? (object) ...) -- active declaration, no body (missing-larkc 31374)
;; (defun cycl-reformulator-directive? (object) ...) -- active declaration, no body
;; (defun cycl-reformulator-rule? (object) ...) -- active declaration, no body
;; (defun cycl-simplifier-directive? (object) ...) -- active declaration, no body
;; (defun hl-assertion-p (object) ...) -- active declaration, no body
;; (defun el-assertion? (object) ...) -- active declaration, no body
;; (defun cyc-indexed-term (object) ...) -- active declaration, no body
;; (defun cyc-assertion (object) ...) -- active declaration, no body
;; (defun cyc-gaf-assertion (object) ...) -- active declaration, no body
;; (defun cyc-rule-assertion (object) ...) -- active declaration, no body
;; (defun cyc-nl-semantic-assertion (object) ...) -- active declaration, no body
;; (defun cyc-reifiable-term (object) ...) -- active declaration, no body
;; (defun cyc-constant (object) ...) -- active declaration, no body
;; (defun cyc-reifiable-nat (object) ...) -- active declaration, no body
;; (defun cyc-gaf (object) ...) -- active declaration, no body
;; (defun cyc-atomic-sentence (object) ...) -- active declaration, no body
;; (defun cyc-first-order-naut (object) ...) -- active declaration, no body
;; (defun cyc-term (object) ...) -- active declaration, no body
;; (defun cyc-ground-term (object) ...) -- active declaration, no body
;; (defun cyc-closed-term (object) ...) -- active declaration, no body
;; (defun cyc-open-term (object) ...) -- active declaration, no body
;; (defun cyc-real-number (object) ...) -- active declaration, no body
;; (defun cyc-system-real-number (object) ...) -- active declaration, no body
;; (defun cyc-positive-number (object) ...) -- active declaration, no body
;; (defun cyc-negative-number (object) ...) -- active declaration, no body
;; (defun cyc-non-positive-number (object) ...) -- active declaration, no body
;; (defun cyc-non-negative-number (object) ...) -- active declaration, no body
;; (defun cyc-rational-number (object) ...) -- active declaration, no body
;; (defun cyc-real-0-100 (object) ...) -- active declaration, no body
;; (defun cyc-real-0-1 (object) ...) -- active declaration, no body
;; (defun cyc-real-minus-1-to-plus-1 (object) ...) -- active declaration, no body
;; (defun cyc-real-1-infinity (object) ...) -- active declaration, no body
;; (defun cyc-nonzero-number (object) ...) -- active declaration, no body

;; TODO - integer & not fixnum?
(defun cyc-integer (integer)
  "[Cyc] defnIff for #$Integer"
  (cyc-system-integer integer))

;; TODO - fixnum?
(defun cyc-system-integer (integer)
  "[Cyc] defnIff for #$SubLInteger"
  (integerp integer))

(defun cyc-positive-integer (integer)
  "[Cyc] defnIff for #$PositiveInteger"
  (and (cyc-integer integer)
       (plusp integer)))

;; (defun cyc-prime-number? (object) ...) -- active declaration, no body
;; (defun cyc-maybe-prime-number? (object) ...) -- active declaration, no body

(defun cyc-negative-integer (integer)
  "[Cyc] defnIff for #$NegativeInteger"
  (and (cyc-integer integer)
       (minusp integer)))

;; (defun cyc-non-positive-integer (object) ...) -- active declaration, no body

(defun cyc-non-negative-integer (integer)
  "[Cyc] defnIff for #$NonNegativeInteger"
  (and (cyc-integer integer)
       (not (cyc-negative-integer integer))))

;; (defun cyc-even-number (object) ...) -- active declaration, no body
;; (defun cyc-odd-number (object) ...) -- active declaration, no body
;; (defun cyc-universal-date (object) ...) -- active declaration, no body
;; (defun cyc-universal-second (object) ...) -- active declaration, no body
;; (defun cyc-set-of-type-necessary (object) ...) -- active declaration, no body
;; (defun cyc-set-of-type-sufficient (object) ...) -- active declaration, no body

(defun cyc-list-of-type-necessary (list)
  "[Cyc] #$defnNecessary for #$List"
  (let ((result (cyc-list-of-type-guts list)))
    (if (eq :agnostic result)
        t
        result)))

;; (defun cyc-list-of-type-sufficient (object) ...) -- active declaration, no body (missing-larkc 31345)
;; (defun cyc-set-of-type-guts (object) ...) -- active declaration, no body

(deflexical *extensional-set?-caching-state* nil "[Cyc] Caching state for extensional-set?.")

;; (defun clear-extensional-set? () ...) -- active declaration, no body (missing-larkc 31329)
;; (defun remove-extensional-set? (object) ...) -- active declaration, no body
;; (defun extensional-set?-internal (object) ...) -- active declaration, no body
;; (defun extensional-set? (object) ...) -- active declaration, no body
;; (defun cyc-set-of-type-internal (object type) ...) -- active declaration, no body

(defun cyc-list-of-type-guts (list)
  "[Cyc] @return t, nil, or :agnostic"
  (when (el-empty-list-p list)
    (return-from cyc-list-of-type-guts t))
  (when (quoted-isa? list #$List-Extensional)
    ;; missing-larkc 32210 likely determines the list-type of LIST
    (let ((list-type (missing-larkc 32210)))
      (when (fort-p list-type)
        (let ((element-type (fpred-value list-type #$instanceListMemberType)))
          (when (fort-p element-type)
            ;; missing-larkc 31344 likely checks element type membership
            (return-from cyc-list-of-type-guts (missing-larkc 31344)))))))
  :agnostic)

;; (defun cyc-list-of-type-internal (list type) ...) -- active declaration, no body
;; (defun every-in-list-has-type-within-collection-defn (list type) ...) -- active declaration, no body
;; (defun cyc-list-without-repetition (object) ...) -- active declaration, no body
;; (defun cyc-numeric-string-necessary (object) ...) -- active declaration, no body (missing-larkc 31353)
;; (defun cyc-numeral-string (object) ...) -- active declaration, no body
;; (defun cyc-numeric-string (object) ...) -- active declaration, no body
;; (defun cyc-number-string (object) ...) -- active declaration, no body
;; (defun cyc-zip-code-five-digit (object) ...) -- active declaration, no body (missing-larkc 31365)
;; (defun cyc-zip-code-nine-digit (object) ...) -- active declaration, no body (missing-larkc 31366)
;; (defun cyc-guid-string-p (object) ...) -- active declaration, no body (missing-larkc 31337)
;; (defun cyc-unicode-denoting-ascii-string-p (object) ...) -- active declaration, no body
;; (defun cyc-ascii-string-p (object) ...) -- active declaration, no body (missing-larkc 31334)
;; (defun cyc-url (object) ...) -- active declaration, no body
;; (defun doctor-me-id? (object) ...) -- active declaration, no body
;; (defun numeric-string-of-length? (object length) ...) -- active declaration, no body
;; (defun clpe? (object) ...) -- active declaration, no body
;; (defun cyc-query? (object) ...) -- active declaration, no body
;; (defun cyc-syntactic-formula-arity-ok (object) ...) -- active declaration, no body
;; (defun cyc-syntactic-formula (object) ...) -- active declaration, no body
;; (defun function-expression? (object) ...) -- active declaration, no body
;; (defun cyc-relation-expression? (object) ...) -- active declaration, no body
;; (defun el-variable? (object) ...) -- active declaration, no body
;; (defun cyc-subl-expression (object) ...) -- active declaration, no body
;; (defun cyc-subl-escape (object) ...) -- active declaration, no body

(defun cyc-subl-template (obj)
  "[Cyc] defnIff for #$SubLTemplate"
  (declare (ignore obj))
  t)

;; (defun ibqe? (object &optional mt) ...) -- active declaration, no body
;; (defun cyc-ibqe (object) ...) -- active declaration, no body
;; (defun scalar-point-value? (object &optional mt) ...) -- active declaration, no body
;; (defun non-negative-scalar-interval? (object &optional mt) ...) -- active declaration, no body
;; (defun positive-scalar-interval? (object &optional mt) ...) -- active declaration, no body
;; (defun unit-of-measure? (object &optional mt) ...) -- active declaration, no body
;; (defun term-set? (object) ...) -- active declaration, no body
;; (defun cycl-var-list? (object) ...) -- active declaration, no body
;; (defun cyc-el-var-list? (object) ...) -- active declaration, no body
;; (defun cyc-system-atom (object) ...) -- active declaration, no body
;; (defun cyc-list-of-lists (object) ...) -- active declaration, no body (missing-larkc 31343)
;; (defun cyc-string-is-length (object) ...) -- active declaration, no body (missing-larkc 31358)
;; (defun cyc-string-is-minimum-length (object) ...) -- active declaration, no body (missing-larkc 31360)
;; (defun cyc-string-is-maximum-length (object) ...) -- active declaration, no body (missing-larkc 31359)
;; (defun cyc-list-is-length (object) ...) -- active declaration, no body
;; (defun cyc-list-is-length-internal (object length) ...) -- active declaration, no body
;; (defun cyc-subl-query-property-p (object) ...) -- active declaration, no body (missing-larkc 31362)
;; (defun cyc-subl-tv-p (object) ...) -- active declaration, no body (missing-larkc 31363)
;; (defun cyc-subl-hl-support-module-p (object) ...) -- active declaration, no body (missing-larkc 31361)
;; (defun cyc-subl-asserted-argument-token-p (object) ...) -- active declaration, no body
;; (defun cyc-subl-kct-metric-identifier-p (object) ...) -- active declaration, no body

(defconstant *8byteinteger-lower-bound* (- (- (expt 2 63)) 1)
  "[Cyc] Lower bound for 8-byte integers.")
(defconstant *8byteinteger-upper-bound* (expt 2 63)
  "[Cyc] Upper bound for 8-byte integers.")

;; (defun cyc-8-byte-integer (object) ...) -- active declaration, no body (missing-larkc 31333)

(defconstant *4byteinteger-lower-bound* (- (- (expt 2 31)) 1)
  "[Cyc] Lower bound for 4-byte integers.")
(defconstant *4byteinteger-upper-bound* (expt 2 31)
  "[Cyc] Upper bound for 4-byte integers.")

;; (defun cyc-4-byte-integer (object) ...) -- active declaration, no body (missing-larkc 31332)

(defconstant *2byteinteger-lower-bound* (- (- (expt 2 15)) 1)
  "[Cyc] Lower bound for 2-byte integers.")
(defconstant *2byteinteger-upper-bound* (expt 2 15)
  "[Cyc] Upper bound for 2-byte integers.")

;; (defun cyc-2-byte-integer (object) ...) -- active declaration, no body (missing-larkc 31331)

(defconstant *1byteinteger-lower-bound* (- (- (expt 2 7)) 1)
  "[Cyc] Lower bound for 1-byte integers.")
(defconstant *1byteinteger-upper-bound* (expt 2 7)
  "[Cyc] Upper bound for 1-byte integers.")

;; (defun cyc-1-byte-integer (object) ...) -- active declaration, no body (missing-larkc 31330)
;; (defun cyc-bit-datatype (object) ...) -- active declaration, no body (missing-larkc 31336)
;; (defun cyc-bit-string (object) ...) -- active declaration, no body
;; (defun cyc-ip4-address (object) ...) -- active declaration, no body (missing-larkc 31338)
;; (defun cyc-ip4-network-address (object) ...) -- active declaration, no body (missing-larkc 31341)
;; (defun cyc-list-is-minimum-length (object) ...) -- active declaration, no body (missing-larkc 31342)
;; (defun cyc-list-is-minimum-length-internal (object length) ...) -- active declaration, no body
;; (defun cyc-list-is-maximum-length (object) ...) -- active declaration, no body
;; (defun cyc-list-is-maximum-length-internal (object length) ...) -- active declaration, no body

;;; Setup phase

(toplevel
  (dolist (symbol *subl-functions-used-as-collection-defns*)
    (register-kb-function symbol))
  (dolist (symbol *cycl-functions-used-as-collection-defns*)
    (register-kb-function symbol))
  (register-kb-function 'cyc-individual-necessary)
  (register-kb-function 'cycl-expression?)
  (register-kb-function 'el-expression?)
  (register-kb-function 'hl-expression-p)
  (register-kb-function 'cycl-open-denotational-term?)
  (register-kb-function 'cycl-closed-denotational-term?)
  (register-kb-function 'cycl-reifiable-denotational-term?)
  (register-kb-function 'cycl-reified-denotational-term?)
  (register-kb-function 'hl-closed-denotational-term-p)
  (register-kb-function 'cycl-represented-atomic-term-p)
  (register-kb-function 'cycl-represented-term?)
  (register-kb-function 'cyc-system-term-p)
  (register-kb-function 'cyc-system-character-p)
  (register-kb-function 'cyc-system-string-p)
  (register-kb-function 'cyc-system-real-number-p)
  (register-kb-function 'cyc-system-non-variable-symbol-p)
  (register-kb-function 'cycl-subl-symbol-p)
  (register-kb-function 'cycl-atomic-term-p)
  (register-kb-function 'cycl-closed-atomic-term-p)
  (register-kb-function 'hl-non-atomic-term-p)
  (register-kb-function 'cycl-non-atomic-term?)
  (register-kb-function 'el-non-atomic-term?)
  (register-kb-function 'hl-indexed-term-p)
  (register-kb-function 'cycl-indexed-term?)
  (register-kb-function 'cycl-open-non-atomic-term?)
  (register-kb-function 'cycl-closed-non-atomic-term?)
  (register-kb-function 'cycl-reifiable-non-atomic-term?)
  (register-kb-function 'cycl-non-atomic-reified-term?)
  (register-kb-function 'el-reifiable-non-atomic-term?)
  (register-kb-function 'cycl-closed-expression?)
  (register-kb-function 'cycl-open-expression?)
  (register-kb-function 'cycl-formula?)
  (register-kb-function 'cycl-open-formula?)
  (register-kb-function 'cycl-closed-formula?)
  (register-kb-function 'hl-formula-p)
  (register-kb-function 'cycl-unbound-relation-formula-p)
  (register-kb-function 'cycl-sentence?)
  (register-kb-function 'cycl-open-sentence?)
  (register-kb-function 'cycl-closed-sentence?)
  (register-kb-function 'cyc-typicality-reference-set-property?)
  (register-kb-function 'el-sentence?)
  (register-kb-function 'cycl-atomic-sentence?)
  (register-kb-function 'cycl-closed-atomic-sentence?)
  (register-kb-function 'cycl-propositional-sentence?)
  (register-kb-function 'cycl-sentence-askable?)
  (register-kb-function 'cycl-sentence-assertible?)
  (register-kb-function 'el-sentence-askable?)
  (register-kb-function 'el-sentence-assertible?)
  (register-kb-function 'cycl-non-atomic-term-askable?)
  (register-kb-function 'cycl-non-atomic-term-assertible?)
  (register-kb-function 'el-non-atomic-term-askable?)
  (register-kb-function 'el-non-atomic-term-assertible?)
  (register-kb-function 'cycl-expression-askable?)
  (register-kb-function 'cycl-expression-assertible?)
  (register-kb-function 'el-expression-askable?)
  (register-kb-function 'el-expression-assertible?)
  (register-kb-function 'cycl-query?)
  (register-kb-function 'cycl-assertion?)
  (register-kb-function 'cycl-atomic-assertion?)
  (register-kb-function 'cycl-gaf-assertion?)
  (register-kb-function 'cycl-rule-assertion?)
  (register-kb-function 'cycl-asserted-assertion?)
  (register-kb-function 'cycl-deduced-assertion?)
  (register-kb-function 'cycl-nl-semantic-assertion?)
  (register-kb-function 'cycl-canonicalizer-directive?)
  (register-kb-function 'cycl-reformulator-directive?)
  (register-kb-function 'cycl-reformulator-rule?)
  (register-kb-function 'cycl-simplifier-directive?)
  (register-kb-function 'hl-assertion-p)
  (register-kb-function 'el-assertion?)
  (register-kb-function 'cyc-ground-term)
  (register-kb-function 'cyc-real-number)
  (register-kb-function 'cyc-system-real-number)
  (register-kb-function 'cyc-positive-number)
  (register-kb-function 'cyc-negative-number)
  (register-kb-function 'cyc-non-positive-number)
  (register-kb-function 'cyc-non-negative-number)
  (register-kb-function 'cyc-rational-number)
  (register-kb-function 'cyc-real-0-100)
  (register-kb-function 'cyc-real-0-1)
  (register-kb-function 'cyc-real-minus-1-to-plus-1)
  (register-kb-function 'cyc-real-1-infinity)
  (register-kb-function 'cyc-nonzero-number)
  (register-kb-function 'cyc-integer)
  (register-kb-function 'cyc-system-integer)
  (register-kb-function 'cyc-positive-integer)
  (register-kb-function 'cyc-prime-number?)
  (register-kb-function 'cyc-maybe-prime-number?)
  (register-kb-function 'cyc-negative-integer)
  (register-kb-function 'cyc-non-positive-integer)
  (register-kb-function 'cyc-non-negative-integer)
  (register-kb-function 'cyc-even-number)
  (register-kb-function 'cyc-odd-number)
  (register-kb-function 'cyc-universal-date)
  (register-kb-function 'cyc-universal-second)
  (pushnew 'cyc-set-of-type-necessary *at-collection-specific-defns*)
  (register-kb-function 'cyc-set-of-type-necessary)
  (pushnew 'cyc-set-of-type-sufficient *at-collection-specific-defns*)
  (register-kb-function 'cyc-set-of-type-sufficient)
  (pushnew 'cyc-list-of-type-necessary *at-collection-specific-defns*)
  (register-kb-function 'cyc-list-of-type-necessary)
  (pushnew 'cyc-list-of-type-sufficient *at-collection-specific-defns*)
  (register-kb-function 'cyc-list-of-type-sufficient)
  (note-globally-cached-function 'extensional-set?)
  (register-kb-function 'cyc-list-without-repetition)
  (register-kb-function 'cyc-numeric-string-necessary)
  (register-kb-function 'cyc-numeral-string)
  (register-kb-function 'cyc-numeric-string)
  (register-kb-function 'cyc-number-string)
  (register-kb-function 'cyc-zip-code-five-digit)
  (register-kb-function 'cyc-zip-code-nine-digit)
  (register-kb-function 'cyc-guid-string-p)
  (register-kb-function 'cyc-unicode-denoting-ascii-string-p)
  (register-kb-function 'cyc-ascii-string-p)
  (register-kb-function 'cyc-url)
  (register-kb-function 'doctor-me-id?)
  (register-kb-function 'clpe?)
  (register-kb-function 'cyc-query?)
  (register-kb-function 'cyc-syntactic-formula-arity-ok)
  (register-kb-function 'cyc-syntactic-formula)
  (register-kb-function 'function-expression?)
  (register-kb-function 'cyc-relation-expression?)
  (register-kb-function 'el-variable?)
  (register-kb-function 'cyc-subl-expression)
  (register-kb-function 'cyc-subl-escape)
  (register-kb-function 'cyc-subl-template)
  (register-kb-function 'ibqe?)
  (register-kb-function 'scalar-point-value?)
  (register-kb-function 'non-negative-scalar-interval?)
  (register-kb-function 'positive-scalar-interval?)
  (register-kb-function 'term-set?)
  (register-kb-function 'cycl-var-list?)
  (register-kb-function 'cyc-el-var-list?)
  (register-kb-function 'cyc-system-atom)
  (register-kb-function 'cyc-list-of-lists)
  (pushnew 'cyc-string-is-length *at-collection-specific-defns*)
  (register-kb-function 'cyc-string-is-length)
  (pushnew 'cyc-string-is-minimum-length *at-collection-specific-defns*)
  (register-kb-function 'cyc-string-is-minimum-length)
  (pushnew 'cyc-string-is-maximum-length *at-collection-specific-defns*)
  (register-kb-function 'cyc-string-is-maximum-length)
  (pushnew 'cyc-list-is-length *at-collection-specific-defns*)
  (register-kb-function 'cyc-list-is-length)
  (register-kb-function 'cyc-subl-query-property-p)
  (register-kb-function 'cyc-subl-tv-p)
  (register-kb-function 'cyc-subl-hl-support-module-p)
  (register-kb-function 'cyc-subl-asserted-argument-token-p)
  (register-kb-function 'cyc-subl-kct-metric-identifier-p)
  (register-kb-function 'cyc-8-byte-integer)
  (register-kb-function 'cyc-4-byte-integer)
  (register-kb-function 'cyc-2-byte-integer)
  (register-kb-function 'cyc-1-byte-integer)
  (register-kb-function 'cyc-bit-string)
  (register-kb-function 'cyc-ip4-address)
  (register-kb-function 'cyc-ip4-network-address)
  (pushnew 'cyc-list-is-minimum-length *at-collection-specific-defns*)
  (register-kb-function 'cyc-list-is-minimum-length)
  (pushnew 'cyc-list-is-maximum-length *at-collection-specific-defns*)
  (register-kb-function 'cyc-list-is-maximum-length))
