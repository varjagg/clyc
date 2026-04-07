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

(defun pattern-matches-formula (pattern formula)
  "[Cyc] Return T iff PATTERN matches FORMULA."
  (pattern-matches-formula-internal pattern formula))

(defun pattern-matches-formula-without-bindings (pattern formula)
  "[Cyc] Return T iff PATTERN matches FORMULA.
:BIND expressions are not allowed within PATTERN"
  (pattern-matches-formula-without-bindings-internal pattern formula))

(defun formula-matches-pattern (formula pattern)
  "[Cyc] Return T iff FORMULA matches PATTERN."
  (pattern-matches-formula-internal pattern formula))

(defun pattern-matches-formula-internal (pattern formula)
  "[Cyc] Active declareFunction, body present."
  (let ((*pattern-matches-tree-atomic-methods* *pattern-matches-formula-atomic-methods*)
        (*pattern-matches-tree-methods* *pattern-matches-formula-methods*))
    (multiple-value-bind (match-success match-bindings)
        (pattern-matches-tree pattern formula)
      (values match-success match-bindings))))

(defun pattern-matches-formula-without-bindings-internal (pattern formula)
  "[Cyc] Active declareFunction, body present."
  (let ((*pattern-matches-tree-atomic-methods* *pattern-matches-formula-atomic-methods*)
        (*pattern-matches-tree-methods* *pattern-matches-formula-methods*))
    (pattern-matches-tree-without-bindings pattern formula)))

;; pattern-matches-formula-isa-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-isa-method (pattern formula) ...) -- active declareFunction, no body

;; call-pattern-matches-formula-isa-method (formula collection mt) -- active declareFunction, no body
;; (defun call-pattern-matches-formula-isa-method (formula collection mt) ...) -- active declareFunction, no body

;; pattern-matches-formula-isa-memoized-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-isa-memoized-method (pattern formula) ...) -- active declareFunction, no body

;; memoized-call-pattern-matches-formula-isa-method-internal (formula collection mt &optional mt2) -- active declareFunction, no body
;; (defun memoized-call-pattern-matches-formula-isa-method-internal (formula collection mt &optional mt2) ...) -- active declareFunction, no body

;; memoized-call-pattern-matches-formula-isa-method (formula collection mt &optional mt2) -- active declareFunction, no body
;; (defun memoized-call-pattern-matches-formula-isa-method (formula collection mt &optional mt2) ...) -- active declareFunction, no body

;; pattern-matches-formula-not-isa-disjoint-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-not-isa-disjoint-method (pattern formula) ...) -- active declareFunction, no body

;; call-pattern-matches-formula-not-isa-disjoint-method (formula collection mt) -- active declareFunction, no body
;; (defun call-pattern-matches-formula-not-isa-disjoint-method (formula collection mt) ...) -- active declareFunction, no body

;; pattern-matches-formula-not-isa-disjoint-memoized-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-not-isa-disjoint-memoized-method (pattern formula) ...) -- active declareFunction, no body

;; memoized-call-pattern-matches-formula-not-isa-disjoint-method-internal (formula collection mt &optional mt2) -- active declareFunction, no body
;; (defun memoized-call-pattern-matches-formula-not-isa-disjoint-method-internal (formula collection mt &optional mt2) ...) -- active declareFunction, no body

;; memoized-call-pattern-matches-formula-not-isa-disjoint-method (formula collection mt &optional mt2) -- active declareFunction, no body
;; (defun memoized-call-pattern-matches-formula-not-isa-disjoint-method (formula collection mt &optional mt2) ...) -- active declareFunction, no body

;; pattern-matches-formula-genls-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-genls-method (pattern formula) ...) -- active declareFunction, no body

;; pattern-matches-formula-spec-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-spec-method (pattern formula) ...) -- active declareFunction, no body

(defun pattern-matches-formula-nat-method (pattern formula)
  "[Cyc] Active declareFunction, body present."
  (destructuring-bind (pattern-operator subpattern) pattern
    (declare (ignore pattern-operator))
    (if (nart-p formula)
        ;; missing-larkc 10378 likely calls nart-el-formula or narts-high:nart-hl-formula
        ;; to get the expanded formula for matching against the subpattern,
        ;; since a NART needs to be converted to its NAUT representation for pattern matching.
        (pattern-matches-tree-internal subpattern (missing-larkc 10378))
        (pattern-matches-tree-internal subpattern formula))))

;; pattern-matches-formula-unify-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-unify-method (pattern formula) ...) -- active declareFunction, no body

;; pattern-matches-formula-genl-pred-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-genl-pred-method (pattern formula) ...) -- active declareFunction, no body

;; pattern-matches-formula-genl-inverse-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-genl-inverse-method (pattern formula) ...) -- active declareFunction, no body

;; pattern-matches-formula-spec-pred-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-spec-pred-method (pattern formula) ...) -- active declareFunction, no body

;; pattern-matches-formula-spec-inverse-method (pattern formula) -- active declareFunction, no body
;; (defun pattern-matches-formula-spec-inverse-method (pattern formula) ...) -- active declareFunction, no body

(defun pattern-transform-formula (pattern formula &optional (v-bindings nil))
  "[Cyc] Use PATTERN to transform FORMULA, assuming BINDINGS."
  (pattern-transform-formula-internal pattern formula v-bindings))

(defun formula-transform-pattern (formula pattern &optional (v-bindings nil))
  "[Cyc] Active declareFunction, no body.
Likely the reverse argument order of pattern-transform-formula, similar to
formula-matches-pattern vs pattern-matches-formula."
  (pattern-transform-formula-internal pattern formula v-bindings))

(defun pattern-transform-formula-internal (pattern formula v-bindings)
  "[Cyc] Active declareFunction, body present."
  (let ((*pattern-transform-match-method* #'pattern-matches-formula))
    (multiple-value-bind (sub-transform sub-bindings)
        (pattern-transform-tree pattern formula v-bindings)
      (values sub-transform sub-bindings))))

;;; Init phase

(deflexical *pattern-matches-formula-atomic-methods*
  '((:fully-bound fully-bound-p)
    (:not-fully-bound not-fully-bound-p)
    (:string stringp)
    (:integer integerp)
    (:fort fort-p)
    (:hlmt hlmt-p)
    (:closed-hlmt closed-hlmt-p)
    (:constant constant-p)
    (:nart nart-p)
    (:closed-naut closed-naut?)
    (:open-naut open-naut?)
    (:assertion assertion-p)
    (:sentence el-sentence-p)
    (:variable variable-p)
    (:el-variable el-variable-p)
    (:collection-fort collection-p)
    (:predicate-fort predicate-p)
    (:functor-fort functor-p)
    (:mt-fort microtheory-p))
  "[Cyc] Atomic methods for formula pattern matching.")

(deflexical *pattern-matches-formula-methods*
  '((:isa pattern-matches-formula-isa-method)
    (:isa-memoized pattern-matches-formula-isa-memoized-method)
    (:not-isa-disjoint pattern-matches-formula-not-isa-disjoint-method)
    (:not-isa-disjoint-memoized pattern-matches-formula-not-isa-disjoint-memoized-method)
    (:genls pattern-matches-formula-genls-method)
    (:spec pattern-matches-formula-spec-method)
    (:nat pattern-matches-formula-nat-method)
    (:unify pattern-matches-formula-unify-method)
    (:genl-pred pattern-matches-formula-genl-pred-method)
    (:genl-inverse pattern-matches-formula-genl-inverse-method)
    (:spec-pred pattern-matches-formula-spec-pred-method)
    (:spec-inverse pattern-matches-formula-spec-inverse-method))
  "[Cyc] Methods for formula pattern matching.")

;;; Setup phase

(note-memoized-function 'memoized-call-pattern-matches-formula-isa-method)
(note-memoized-function 'memoized-call-pattern-matches-formula-not-isa-disjoint-method)
