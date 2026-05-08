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

;;; ======================================================================
;;; Commented-out macros — reconstructed from Internal Constants evidence
;;; ======================================================================

;; Reconstructed from $list0 (arglist), $sym6 DO-KEYHASH, $list7 (KB-RULE-SET),
;; $sym8-10 gensyms (MESSAGE-VAR, TOTAL, SOFAR), $sym11 CLET, $list12 ((RULE-COUNT)),
;; $list13 (0), $sym14 NOTING-PERCENT-PROGRESS, $sym16 CINC, $sym17 NOTE-PERCENT-PROGRESS.
;; do-keyhash is elided (keyhash = hash table); replaced with do-set (hash table key iteration).
(defmacro do-rules ((rule-var &key (progress-message "mapping Cyc rules") done) &body body)
  "Iterate over all rules with optional progress reporting."
  (with-temp-vars (total sofar)
    `(let ((,total (rule-count))
           (,sofar 0))
       (noting-percent-progress (,progress-message)
         (do-set (,rule-var (kb-rule-set) ,done)
           (incf ,sofar)
           (note-percent-progress ,sofar ,total)
           ,@body)))))

;; Reconstructed from $list18 (arglist), $sym20 DO-ASSERTIONS, $sym21 PWHEN (=when),
;; $sym22 GAF-ASSERTION?.
;; NOTE: depends on do-assertions (active declareMacro in assertion-handles, not yet
;; reconstructed there as a defmacro — call sites use do-id-index directly).
(defmacro do-gafs ((gaf-var &key (progress-message "mapping Cyc GAFs") done) &body body)
  "Iterate over all GAF assertions with optional progress reporting."
  `(do-assertions (,gaf-var :progress-message ,progress-message :done ,done)
     (when (gaf-assertion? ,gaf-var)
       ,@body)))

;; Reconstructed from $list23 (arglist), $sym24 DEDUCTION (gensym),
;; $sym25 DO-ASSERTION-DEPENDENTS, $sym26 DEDUCTION-ASSERTION.
(defmacro do-assertion-dependent-assertions ((dependent-assertion assertion) &body body)
  "Iterate over all assertions that depend on ASSERTION."
  (with-temp-vars (deduction)
    `(do-assertion-dependents (,deduction ,assertion)
       (let ((,dependent-assertion (deduction-assertion ,deduction)))
         ,@body))))

;; Reconstructed from $list28 (arglist), $list29 (:DONE), $sym30 ARGUMENT (gensym),
;; $sym31 DO-ASSERTION-ARGUMENTS, $sym32 DEDUCTION-P, $sym33 DO-DEDUCTION-SUPPORTS,
;; $sym27 ASSERTION-P.
(defmacro do-assertion-supporting-assertions ((supporting-assertion assertion &key done) &body body)
  "Iterate over all assertions that support ASSERTION (via deductions)."
  (with-temp-vars (argument)
    `(do-assertion-arguments (,argument ,assertion :done ,done)
       (when (deduction-p ,argument)
         (do-deduction-supports (,supporting-assertion ,argument :done ,done)
           (when (assertion-p ,supporting-assertion)
             ,@body))))))

;;; ======================================================================
;;; Commented-out functions — stubs
;;; ======================================================================

;; (defun assertion-list-p (object)) -- commented declareFunction, no body (1 0)
;; (defun list-of-rule-assertion-p (object)) -- commented declareFunction, no body (1 0)
;; (defun assertion-dependent-assertions (assertion)) -- commented declareFunction, no body (1 0)

(defun true-assertion? (assertion)
  "[Cyc] Return T iff ASSERTION is a true assertion."
  (and (assertion-p assertion)
       (assertion-has-truth? assertion :true)
       t))

;; (defun false-assertion? (assertion)) -- commented declareFunction, no body (1 0)
;; (defun unknown-assertion? (assertion)) -- commented declareFunction, no body (1 0)
;; (defun true-gaf-assertion? (assertion)) -- commented declareFunction, no body (1 0)
;; (defun false-gaf-assertion? (assertion)) -- commented declareFunction, no body (1 0)
;; (defun nl-semantic-assertion? (assertion)) -- commented declareFunction, no body (1 0)

(defun assertion-matches-type? (assertion type-spec)
  "[Cyc] Return T iff ASSERTION matches TYPE-SPEC (or TYPE-SPEC is NIL)."
  (or (null type-spec)
      (assertion-has-type? assertion type-spec)))

(defun assertion-matches-truth? (assertion truth-spec)
  "[Cyc] Return T iff ASSERTION matches TRUTH-SPEC (or TRUTH-SPEC is NIL)."
  (or (null truth-spec)
      (assertion-has-truth assertion truth-spec)))

(defun assertion-matches-direction? (assertion direction-spec)
  "[Cyc] Return T iff ASSERTION matches DIRECTION-SPEC (or DIRECTION-SPEC is NIL)."
  (or (null direction-spec)
      (assertion-has-direction assertion direction-spec)))

;; (defun assertion-matches-truth-and-direction? (assertion truth-spec direction-spec)) -- commented declareFunction, no body (3 0)

(defun assertion-matches-type-truth-and-direction? (assertion type-spec truth-spec direction-spec)
  "[Cyc] Return T iff ASSERTION matches all of TYPE-SPEC, TRUTH-SPEC, and DIRECTION-SPEC."
  (and (assertion-matches-type? assertion type-spec)
       (assertion-matches-truth? assertion truth-spec)
       (assertion-matches-direction? assertion direction-spec)
       t))

(defun gaf-has-term-in-argnum? (assertion v-term argnum)
  "[Cyc] Return T iff GAF ASSERTION has V-TERM in argument position ARGNUM."
  (let ((arg (gaf-arg assertion argnum)))
    (equal v-term arg)))

(defun gaf-has-term-in-some-argnum? (assertion v-term)
  "[Cyc] Return T iff ASSERTION has TERM as one of its top-level arguments."
  (term-is-one-of-args? v-term (gaf-formula assertion)))

(defun gaf-assertion-with-pred-p (assertion pred)
  "[Cyc] Return T iff ASSERTION is a gaf with PRED as its arg0.
Assumes equality can be tested with #'eq."
  (and (gaf-assertion? assertion)
       (eq pred (gaf-predicate assertion))
       t))

(defun gaf-assertion-has-pred-p (gaf-assertion pred)
  "[Cyc] Return T iff GAF-ASSERTION has PRED as its arg0.
Assumes that GAF-ASSERTION is a gaf and that equality can be tested with #'eq."
  (eq pred (gaf-predicate gaf-assertion)))

;; (defun gaf-assertion-with-any-of-preds-p (assertion preds)) -- commented declareFunction, no body (2 0)
;; (defun isa-gaf-p (assertion)) -- commented declareFunction, no body (1 0)
;; (defun genls-gaf-p (assertion)) -- commented declareFunction, no body (1 0)
;; (defun assertion-cnf-with-el-vars-only (assertion)) -- commented declareFunction, no body (1 0)
;; (defun except-when-rule-p (assertion)) -- commented declareFunction, no body (1 0)
;; (defun except-for-gaf-p (assertion)) -- commented declareFunction, no body (1 0)
;; (defun abnormal-assertion-p (assertion)) -- commented declareFunction, no body (1 0)
;; (defun abnormal-literal-from-assertion (assertion)) -- commented declareFunction, no body (1 0)

(defun excepted-assertion? (assertion)
  "[Cyc] Check whether ASSERTION is excepted."
  (excepted-assertion?-int assertion))

(defun excepted-assertion?-int (assertion &optional checked-assertions)
  "[Cyc] Check whether ASSERTION is excepted in the current mt context."
  (declare (type assertion assertion))
  (when (not (valid-assertion? assertion))
    (return-from excepted-assertion?-int nil))
  (when (member-eq? assertion checked-assertions)
    (return-from excepted-assertion?-int nil))
  (push assertion checked-assertions)
  (let ((excepted-assertion? nil)
        (mt (assertion-mt assertion)))
    ;; Check exceptMt
    (when (and (fort-p mt)
               (some-pred-assertion-somewhere? #$exceptMt mt 1))
      (let ((exceptions (missing-larkc 30025)))
        (unless excepted-assertion?
          (dolist (exception exceptions)
            (when excepted-assertion? (return))
            (unless (excepted-assertion?-int exception checked-assertions)
              (setf excepted-assertion? t))))))
    ;; Check except
    (unless excepted-assertion?
      (when (some-pred-assertion-somewhere? #$except assertion 1)
        (let ((exceptions (missing-larkc 30026)))
          (unless excepted-assertion?
            (dolist (exception exceptions)
              (when excepted-assertion? (return))
              (unless (excepted-assertion?-int exception checked-assertions)
                (setf excepted-assertion? t)))))))
    ;; Check arguments
    (unless excepted-assertion?
      (let ((non-excepted-support-found? nil))
        (dolist (argument (assertion-arguments assertion))
          (when non-excepted-support-found? (return))
          (if (asserted-argument-p argument)
              (setf non-excepted-support-found? t)
              (let ((excepted-support-found? nil))
                (dolist (support (deduction-supports argument))
                  (when excepted-support-found? (return))
                  (when (and (assertion-p support)
                             (excepted-assertion?-int support checked-assertions))
                    (setf excepted-support-found? t)))
                (unless excepted-support-found?
                  (setf non-excepted-support-found? t)))))
        (setf excepted-assertion? (not non-excepted-support-found?))))
    excepted-assertion?))

(defun excepted-assertion-in-mt? (assertion mt)
  "[Cyc] Check whether ASSERTION is excepted in MT."
  (with-inference-mt-relevance mt
    (excepted-assertion? assertion)))

(defun assertion-matches-mt? (assertion)
  "[Cyc] Return T iff ASSERTION's mt is relevant."
  (relevant-mt? (assertion-mt assertion)))

(defun assertion-has-arguments? (assertion)
  "[Cyc] Return T iff ASSERTION has at least one argument for it, either true or false."
  (and (assertion-arguments assertion) t))

;; (defun assertion-has-deduction-with-support? (assertion support)) -- commented declareFunction, no body (2 0)
;; (defun assertion-has-dependent-with-support? (assertion support)) -- commented declareFunction, no body (2 0)
;; (defun assertion-mentions-asserted-more-specifically? (assertion)) -- commented declareFunction, no body (1 0)
;; (defun assertion-mentions-any-of-terms? (assertion terms)) -- commented declareFunction, no body (2 0)
;; (defun assertion-mentions-any-of-terms-in-set-lambda (assertion)) -- commented declareFunction, no body (1 0)
;; (defun assertion-mentions-any-of-terms-in-set? (assertion term-set)) -- commented declareFunction, no body (2 0)
;; (defun assertion-mentions-any-of-terms-in-dict-lambda (assertion)) -- commented declareFunction, no body (1 0)
;; (defun assertion-mentions-any-of-terms-in-dictionary-keys? (assertion dict)) -- commented declareFunction, no body (2 0)
;; (defun random-gaf-with-pred (pred)) -- commented declareFunction, no body (1 0)
;; (defun random-gaf-with-predicate (pred)) -- commented declareFunction, no body (1 0)
;; (defun random-gaf-with-predicate-and-arg (pred arg argnum)) -- commented declareFunction, no body (3 0)
;; (defun random-rule-mentioning (term)) -- commented declareFunction, no body (1 0)
;; (defun rules-mentioning (term)) -- commented declareFunction, no body (1 0)
;; (defun rule-count-mentioning (term)) -- commented declareFunction, no body (1 0)
;; (defun assertion-earlier? (assertion1 assertion2)) -- commented declareFunction, no body (2 0)
;; (defun assertion-later? (assertion1 assertion2)) -- commented declareFunction, no body (2 0)
;; (defun earliest-assertion (assertions)) -- commented declareFunction, no body (1 0)
;; (defun rename-assertion-variables (assertion rename-map)) -- commented declareFunction, no body (2 0)
;; (defun possibly-rename-assertion-variables (assertion rename-map)) -- commented declareFunction, no body (2 0)
;; (defun assertion-antecedent-query-formula (assertion)) -- commented declareFunction, no body (1 0)
;; (defun assertion-known-extent-query-formula (assertion)) -- commented declareFunction, no body (1 0)
;; (defun assertion-unknown-extent-query-formula (assertion)) -- commented declareFunction, no body (1 0)
;; (defun assertion-known-extent-query-formula-int (assertion flag)) -- commented declareFunction, no body (2 0)
;; (defun assertion-info (assertion)) -- commented declareFunction, no body (1 0)
;; (defun assertion-literal-count (assertion)) -- commented declareFunction, no body (1 0)

(defun rule-literal-count (rule)
  "[Cyc] Return the number of literals in RULE."
  (let ((cnf (assertion-cnf rule)))
    (clause-literal-count cnf)))

;; (defun assertion-universal-time (assertion)) -- commented declareFunction, no body (1 0)
;; (defun all-assertions-sorted-by-creation-time-estimate ()) -- commented declareFunction, no body (0 0)
;; (defun assertion-newest-constant (assertion)) -- commented declareFunction, no body (1 0)
;; (defun initialize-newest-constant-table ()) -- commented declareFunction, no body (0 0)

(defun assertion-has-meta-assertions? (assertion)
  "[Cyc] Return T iff ASSERTION has some meta-assertions."
  (declare (type assertion assertion))
  (and (assertion-index assertion) t))

;; (defun all-meta-assertions (assertion)) -- commented declareFunction, no body (1 0)
;; (defun meta-assertion-list-for-editing (assertion)) -- commented declareFunction, no body (1 0)
;; (defun meta-assertion-p (assertion)) -- commented declareFunction, no body (1 0)
;; (defun meta-assertion-el-formula (assertion mt truth)) -- commented declareFunction, no body (3 0)
;; (defun mt-of-assertions-p (assertions mt)) -- commented declareFunction, no body (2 0)
;; (defun assertions-of-mt (assertions mt)) -- commented declareFunction, no body (2 0)
;; (defun mts-of-assertions (assertions)) -- commented declareFunction, no body (1 0)
;; (defun sibling-mt-assertions (assertion)) -- commented declareFunction, no body (1 0)
;; (defun assertions-min-mt (assertions)) -- commented declareFunction, no body (1 0)
;; (defun sort-gafs-by-term (gafs &optional argnum pred)) -- commented declareFunction, no body (1 2)
;; (defun rule-type-constraints (rule)) -- commented declareFunction, no body (1 0)
;; (defun self-looping-rule? (rule)) -- commented declareFunction, no body (1 0)
;; (defun clear-cached-self-looping-rule-assertion? ()) -- commented declareFunction, no body (0 0)
;; (defun remove-cached-self-looping-rule-assertion? (rule)) -- commented declareFunction, no body (1 0)
;; (defun cached-self-looping-rule-assertion?-internal (rule)) -- commented declareFunction, no body (1 0)
;; (defun cached-self-looping-rule-assertion? (rule)) -- commented declareFunction, no body (1 0)

(defun self-expanding-rule? (rule)
  "[Cyc] Return T iff RULE is a self-expanding rule assertion."
  (when (rule-assertion? rule)
    (cached-self-expanding-rule-assertion? rule)))

;; (defun clear-cached-self-expanding-rule-assertion? ()) -- commented declareFunction, no body (0 0)
;; (defun remove-cached-self-expanding-rule-assertion? (rule)) -- commented declareFunction, no body (1 0)

(defun-cached cached-self-expanding-rule-assertion? (rule)
    (:test eq :capacity nil :initial-size 0)
  "[Cyc] Cached check whether RULE is a self-expanding rule assertion."
  (let ((cnf (assertion-cnf rule))
        (witness nil))
    (dolist (pos-lit (pos-lits cnf))
      (when witness (return))
      (let ((count 0))
        (dolist (neg-lit (neg-lits cnf))
          (when (unify-possible pos-lit neg-lit)
            (incf count)))
        (when (>= count 2)
          (setf witness pos-lit))))
    (and witness t)))

(defun all-forward-rules-relevant-to-term (fort)
  "[Cyc] Return a list of all the forward rules involved in a deduction
that is either an argument* or a dependent* of some assertion
on FORT. 'argument*' and 'dependent*' mean 'transitive argument'
and 'transitive dependent'."
  (declare (type fort fort))
  (let ((rules (all-forward-rules-relevant-to-term-int fort)))
    (sort rules #'> :key #'assertion-dependent-count)))

;; (defun all-forward-rules-relevant-to-terms (forts)) -- commented declareFunction, no body (1 0)

(defun deduction-forward-rule-supports (deduction)
  "[Cyc] Returns all supports of DEDUCTION that are forward rules."
  (let ((forward-rules nil))
    (dolist (support (deduction-supports deduction))
      (when (forward-rule? support)
        (push support forward-rules)))
    (nreverse forward-rules)))

(defparameter *all-forward-rules-relevant-to-term-argument-set* nil
  "[Cyc] to avoid infinite recursion going up")
(defparameter *all-forward-rules-relevant-to-term-dependent-set* nil
  "[Cyc] to avoid infinite recursion going down")
(defparameter *all-forward-rules-relevant-to-term-nart-set* nil
  "[Cyc] to avoid wasting work on duplicate narts")
(defparameter *all-forward-rules-relevant-to-term-result-set* nil
  "[Cyc] the answer, built up by side effect")

(defun all-forward-rules-relevant-to-term-int (fort)
  "[Cyc] Internal implementation of all-forward-rules-relevant-to-term."
  (let ((*relevant-mt-function* 'relevant-mt-is-everything)
        (*mt* #$EverythingPSC)
        (*all-forward-rules-relevant-to-term-argument-set* (new-set #'eq))
        (*all-forward-rules-relevant-to-term-dependent-set* (new-set #'eq))
        (*all-forward-rules-relevant-to-term-nart-set* (new-set #'eq))
        (*all-forward-rules-relevant-to-term-result-set* (new-set #'eq)))
    (compute-all-forward-rules-relevant-to-term fort '(:argument* :dependent*))
    (set-element-list *all-forward-rules-relevant-to-term-result-set*)))

(defun compute-all-forward-rules-relevant-to-term (fort walk-directions)
  "[Cyc] Compute forward rules relevant to FORT walking in WALK-DIRECTIONS."
  (do-term-index (assertion fort)
    (dolist (walk-direction walk-directions)
      (compute-all-forward-rules-relevant-to-assertion assertion walk-direction)))
  nil)

(defun compute-all-forward-rules-relevant-to-assertion (assertion walk-direction)
  "[Cyc] Process ASSERTION for forward rules in WALK-DIRECTION (:argument* or :dependent*)."
  (case walk-direction
    (:argument*
     (when (set-member? assertion *all-forward-rules-relevant-to-term-argument-set*)
       (return-from compute-all-forward-rules-relevant-to-assertion nil))
     (set-add assertion *all-forward-rules-relevant-to-term-argument-set*))
    (:dependent*
     (when (set-member? assertion *all-forward-rules-relevant-to-term-dependent-set*)
       (return-from compute-all-forward-rules-relevant-to-assertion nil))
     (set-add assertion *all-forward-rules-relevant-to-term-dependent-set*)))
  ;; Process NARTs in the assertion
  (dolist (nart (expression-narts assertion t))
    (unless (set-member? nart *all-forward-rules-relevant-to-term-nart-set*)
      (set-add nart *all-forward-rules-relevant-to-term-nart-set*)
      (when (skolemize-forward? (nat-functor nart) (assertion-mt assertion))
        (compute-all-forward-rules-relevant-to-term nart (list walk-direction)))))
  (compute-all-forward-rules-relevant-to-assertion-int assertion walk-direction)
  nil)

(defun compute-all-forward-rules-relevant-to-assertion-int (assertion walk-direction)
  "[Cyc] Walk ASSERTION's arguments or dependents for forward rules."
  ;; Collect forward rules from deduction supports
  (dolist (argument (assertion-arguments assertion))
    (when (deduction-p argument)
      (set-add-all (deduction-forward-rule-supports argument)
                   *all-forward-rules-relevant-to-term-result-set*)))
  ;; Recursively walk in the specified direction
  (case walk-direction
    (:argument*
     (dolist (argument (assertion-arguments assertion))
       (when (deduction-p argument)
         (dolist (supporting-assertion (deduction-supports argument))
           (when (assertion-p supporting-assertion)
             (compute-all-forward-rules-relevant-to-assertion supporting-assertion walk-direction))))))
    (:dependent*
     (dolist (deduction (assertion-dependents assertion))
       (let ((dependent-assertion (deduction-assertion deduction)))
         (when (assertion-p dependent-assertion)
           (compute-all-forward-rules-relevant-to-assertion dependent-assertion walk-direction))))))
  nil)

;; (defun gather-all-exception-rules (&optional mt)) -- commented declareFunction, no body (0 1)
;; (defun gather-all-pragma-rules (&optional mt)) -- commented declareFunction, no body (0 1)
;; (defun gather-all-lifting-rules ()) -- commented declareFunction, no body (0 0)
;; (defun lifting-rule? (rule)) -- commented declareFunction, no body (1 0)
;; (defun rule-has-unlabelled-dont-care-variable? (rule)) -- commented declareFunction, no body (1 0)
;; (defun rule-unlabelled-dont-care-variables (rule)) -- commented declareFunction, no body (1 0)
;; (defun assertion-findable-by-id? (assertion)) -- commented declareFunction, no body (1 0)
;; (defun embedded-assertions-findable-by-id? (assertion &optional deep?)) -- commented declareFunction, no body (1 1)
;; (defun assertions-containing-assertions-not-findable-by-id ()) -- commented declareFunction, no body (0 0)
;; (defun assertions-with-no-arguments (&optional mt)) -- commented declareFunction, no body (0 1)
;; (defun syntactically-ill-formed-assertion-count ()) -- commented declareFunction, no body (0 0)
;; (defun syntactically-ill-formed-assertions ()) -- commented declareFunction, no body (0 0)
;; (defun syntactically-ill-formed-assertion? (assertion)) -- commented declareFunction, no body (1 0)

;;; ======================================================================
;;; Variables
;;; ======================================================================

(deflexical *assertion-mentions-any-of-terms-set-watermark* 30
  "[Cyc] If we're searching for this many terms or more, it's more efficient to construct a set.")
(defparameter *assertion-mentions-any-of-terms-set-lambda* nil)
(defparameter *assertion-mentions-any-of-terms-dict-lambda* nil)
(defparameter *newest-constant-of-assertions* nil)
(deflexical *cached-self-looping-rule-assertion?-caching-state* nil)
;; Note: *cached-self-expanding-rule-assertion?-caching-state* is managed by defun-cached

;;; ======================================================================
;;; Setup phase
;;; ======================================================================

(register-cyc-api-function 'assertion-has-meta-assertions?
  '(assertion)
  "Return T iff ASSERTION has some meta-assertions."
  '((assertion assertion-p))
  '(booleanp))

;; note-globally-cached-function for cached-self-looping-rule-assertion? is a no-op
;; since cached-self-looping-rule-assertion? is commented out (stub only)

;; note-globally-cached-function for cached-self-expanding-rule-assertion? is
;; handled by defun-cached expansion
