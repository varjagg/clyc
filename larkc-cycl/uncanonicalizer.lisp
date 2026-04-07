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

;; TODO - nothing else in the java accesses this at all?  Imports, but not actually accesses vars etc

(in-package :clyc)

;; Macro (declare section)

;; Reconstructed from Internal Constants:
;;   $list0 = arglist (CNF &BODY BODY)
;;   $sym1$CLET, $list2 = ((*UNUNIQUIFIED-EL-VARS* (NEW-DICTIONARY))),
;;   $sym3$CDOLIST, $sym4$VAR, $sym5$CLAUSE-VARIABLES,
;;   $list6 = ((REMEMBER-UNUNIQUIFIED-EL-VAR VAR VAR))
(defmacro remembering-ununiquified-el-vars (cnf &body body)
  `(let ((*ununiquified-el-vars* (make-hash-table)))
     (dolist (var (clause-variables ,cnf))
       (remember-ununiquified-el-var var var))
     ,@body))

;; Variables (init section)

(defparameter *ununiquified-el-vars* nil
  "[Cyc] A dictionary of the variables in the formula being uncanonicalized.  May change as variables are ununiquified.")

(defparameter *cache-el-formula?* nil
  "[Cyc] should the uncanonicalizer cache the el formula it computes for each assertion?")

(deflexical *potentially-interestingly-uncanonicalizable-tense-terms*
    (list #$IntervalEndedByFn #$IntervalStartedByFn)
  "[Cyc] extend this as necessary")

(defparameter *retain-leading-universals* nil
  "[Cyc] variables whose leading universal quantification should be retained?")

(defparameter *vars-to-universalize* nil
  "[Cyc] A list of all variables that are universally quantified")

(defparameter *universal-vars-to-skolem* nil
  "[Cyc] A hash table to store free-variables and the skolem functions that reference them")

(defparameter *uncanonicalizer-dnf-threshold* 5
  "[Cyc] max number of conjuncts that will be attempted to put in dnf during uncanonicalization")

(deflexical *default-skolem-vars* '(?X ?Y ?Z ?A ?B ?C ?D ?E)
  "[Cyc] A list of variables to use for zero-arity skolems")

;; Functions (declare section) — ALL commented out in Java, no bodies

;; assertion-el-formula-memoized is a state-dependent memoized function (defun-memoized pattern).
;; The body (assertion-el-formula-memoized-internal) is stripped, so the group is stubs:
;;   assertion-el-formula-memoized-internal (1 0) — the actual computation (stripped)
;;   assertion-el-formula-memoized (1 0) — the memoized wrapper (stripped)
;; Both have commented declareFunction, no body.

;; (defun assertion-el-formula (assertion) ...) -- no body, commented declareFunction
;; (defun assertion-elmt (assertion) ...) -- no body, commented declareFunction
;; (defun assertion-el-ist-formula (assertion) ...) -- no body, commented declareFunction
;; (defun interesting-uncanonicalizations? (assertion) ...) -- no body, commented declareFunction
;; (defun fast-fi-not-el-term? (term) ...) -- no body, commented declareFunction
;; (defun potentially-interestingly-uncanonicalizable-tense-term? (term) ...) -- no body, commented declareFunction

;; cached-assertion-el-formula-int is a globally-cached function (defun-cached pattern).
;; The body (cached-assertion-el-formula-int-internal) is stripped, so the entire group is stubs:
;;   *cached-assertion-el-formula-int-caching-state* — deflexical, caching state variable
;;   clear-cached-assertion-el-formula-int (0 0) — clears the caching state
;;   remove-cached-assertion-el-formula-int (1 0) — removes a single entry
;;   cached-assertion-el-formula-int-internal (1 0) — the actual computation (stripped)
;;   cached-assertion-el-formula-int (1 0) — the cached wrapper
;; All have commented declareFunction, no body.

;; (defun assertion-el-formula-int (assertion) ...) -- no body, commented declareFunction
;; (defun unwrap-el-formulas-of-assertions-destructive (formula) ...) -- no body, commented declareFunction
;; (defun new-assertion-el-formula-int (assertion) ...) -- no body, commented declareFunction
;; (defun cnf-el-formula (cnf &optional mt direction) ...) -- no body, commented declareFunction
;; (defun cnfs-el-formula (cnfs &optional mt direction) ...) -- no body, commented declareFunction
;; (defun hl-dnfs-to-hl-cnfs (dnfs) ...) -- no body, commented declareFunction
;; (defun hl-cnfs-to-hl-dnfs (cnfs) ...) -- no body, commented declareFunction
;; (defun dnfs-el-formula (dnfs &optional mt direction) ...) -- no body, commented declareFunction
;; (defun el-cnfs-to-el-implication (neg-cnfs pos-cnfs) ...) -- no body, commented declareFunction
;; (defun remove-index-lits-from-cnfs (cnfs index-lits) ...) -- no body, commented declareFunction
;; (defun cnf-intermediate-el-formula (cnf) ...) -- no body, commented declareFunction
;; (defun el-version (formula &optional mt) ...) -- no body, commented declareFunction
;; (defun el-explicitify-implicit-meta-literals (formula) ...) -- no body, commented declareFunction
;; (defun el-pragmatic-requirements (formula) ...) -- no body, commented declareFunction
;; (defun el-pragmatic-requirement (formula) ...) -- no body, commented declareFunction
;; (defun el-exceptions (formula) ...) -- no body, commented declareFunction
;; (defun el-except-for (formula) ...) -- no body, commented declareFunction
;; (defun el-except-when (formula) ...) -- no body, commented declareFunction
;; (defun unpackage-cnf-clauses (clauses) ...) -- no body, commented declareFunction
;; (defun remove-truesentence-refs (formula) ...) -- no body, commented declareFunction
;; (defun true-sentence-vars (formula) ...) -- no body, commented declareFunction
;; (defun undo-variables (formula) ...) -- no body, commented declareFunction
;; (defun unremove-universals (formula) ...) -- no body, commented declareFunction
;; (defun unremove-universals-int (formula) ...) -- no body, commented declareFunction
;; (defun inter-formula-terms (formula-a formula-b &optional test key) ...) -- no body, commented declareFunction
;; (defun inter-formula-skolems (formula-a formula-b) ...) -- no body, commented declareFunction
;; (defun some-tree-find (item tree &optional test key) ...) -- no body, commented declareFunction
;; (defun unremove-existentials-and-refd-universals (formula skolems) ...) -- no body, commented declareFunction
;; (defun undo-skolem-mt (formula mt) ...) -- no body, commented declareFunction
;; (defun base-kb-ist-sentence? (sentence) ...) -- no body, commented declareFunction
;; (defun segregate-skolems (skolems) ...) -- no body, commented declareFunction
;; (defun undo-existentials-and-refd-universals (formula &optional skolems) ...) -- no body, commented declareFunction
;; (defun init-existentialize-formula (formula var) ...) -- no body, commented declareFunction
;; (defun existentialize-formula (formula var) ...) -- no body, commented declareFunction
;; (defun implications-in (formula) ...) -- no body, commented declareFunction
;; (defun undo-implications (formula) ...) -- no body, commented declareFunction
;; (defun implicatable-disjunction? (formula) ...) -- no body, commented declareFunction
;; (defun implicatable-conjunction? (formula) ...) -- no body, commented declareFunction
;; (defun uncanon-dnf-1 (formula) ...) -- no body, commented declareFunction
;; (defun naut-formula? (formula) ...) -- no body, commented declareFunction
;; (defun ists-out (formula) ...) -- no body, commented declareFunction
;; (defun simplifiable-ist-expression? (expression) ...) -- no body, commented declareFunction
;; (defun simplify-ist-expression (expression) ...) -- no body, commented declareFunction
;; (defun remove-leading-universals (formula) ...) -- no body, commented declareFunction
;; (defun sentence-free-vars-not-bound-to-skolems (sentence &optional skolems) ...) -- no body, commented declareFunction
;; (defun add-universal-var-placeholder (formula) ...) -- no body, commented declareFunction
;; (defun check-for-universal-var-placeholder (formula) ...) -- no body, commented declareFunction
;; (defun remove-universal-var-placeholder (formula) ...) -- no body, commented declareFunction
;; (defun skolem-fn-arg-vars (skolem) ...) -- no body, commented declareFunction
;; (defun formula-unreified-skolems (formula) ...) -- no body, commented declareFunction
;; (defun universal-vars-to-skolem-table (formula &optional table) ...) -- no body, commented declareFunction
;; (defun remove-skolem-from-universal-vars-to-skolem (skolem) ...) -- no body, commented declareFunction
;; (defun num-args-of-skolem-fn (skolem-fn) ...) -- no body, commented declareFunction
;; (defun order-skolems-inner-to-outer (skolems) ...) -- no body, commented declareFunction
;; (defun nsubst-hl-vars (cnfs vars) ...) -- no body, commented declareFunction
;; (defun unreify-cnfs-nats (cnfs &optional mt direction) ...) -- no body, commented declareFunction
;; (defun gather-skolem-constants (formula &optional skolems) ...) -- no body, commented declareFunction
;; (defun unreify-cnfs-terms (cnfs &optional mt direction) ...) -- no body, commented declareFunction
;; (defun unreify-cnfs-assertions (cnfs &optional mt) ...) -- no body, commented declareFunction
;; (defun wrapped-assertion-el-formula-wrt-mt (assertion) ...) -- no body, commented declareFunction
;; (defun subst-index-in (formula index) ...) -- no body, commented declareFunction
;; (defun unreify-cnfs-skolem (cnfs skolem vars) ...) -- no body, commented declareFunction
;; (defun expression-subst-skolem (skolem var formula &optional mt) ...) -- no body, commented declareFunction
;; (defun sk-fn-arg-wrt (skolem arg &optional mt direction) ...) -- no body, commented declareFunction
;; (defun sk-var-wrt (skolem arg &optional mt direction) ...) -- no body, commented declareFunction
;; (defun skolem-uniquify (formula) ...) -- no body, commented declareFunction
;; (defun ununiquify-el-var (var) ...) -- no body, commented declareFunction
;; (defun remember-ununiquified-el-var (var value) ...) -- no body, commented declareFunction
;; (defun ununiquification-conflict? (var value) ...) -- no body, commented declareFunction
;; (defun skolem-el-cnfs-from-assertions (skolem assertions mt) ...) -- no body, commented declareFunction
;; (defun possibly-make-ist-sentence (mt assertion sentence) ...) -- no body, commented declareFunction
;; (defun assertions-in-same-mt? (assertions) ...) -- no body, commented declareFunction
;; (defun el-cnfs (assertion &optional mt direction) ...) -- no body, commented declareFunction
;; (defun repair-assertion-vars (formula) ...) -- no body, commented declareFunction
;; (defun index-lits-to-remove (cnf) ...) -- no body, commented declareFunction
;; (defun tou-lits-to-remove (cnf) ...) -- no body, commented declareFunction
;; (defun evaluate-lits-to-remove (cnf) ...) -- no body, commented declareFunction
;; (defun variable-should-not-be-substituted-during-uncze? (var cnf) ...) -- no body, commented declareFunction
;; (defun equals-lits-to-remove (cnf) ...) -- no body, commented declareFunction
;; (defun uncanonicalize-recursive-query (formula) ...) -- no body, commented declareFunction
;; (defun uncanonicalize-recursive-query-vars (formula) ...) -- no body, commented declareFunction

;; Setup section

(note-memoized-function 'assertion-el-formula-memoized)

(register-cyc-api-function 'assertion-el-formula '(assertion)
  "Return the EL formula for ASSERTION.  Does uncanonicalization, and converts HL terms to EL."
  '((assertion assertion-p))
  '(listp))

(register-cyc-api-function 'assertion-el-ist-formula '(assertion)
  "Return the el formula in #$ist format for ASSERTION."
  '((assertion assertion-p))
  '(consp))

(note-globally-cached-function 'cached-assertion-el-formula-int)
