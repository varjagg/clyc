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

;; Meta-level canonicalization: finding assertions from EL sentences,
;; handling meta-propositions (propositions about propositions).

;;; Variables

(deflexical *meta-relation-somewhere?-caching-state* nil)
(deflexical *possibly-meta-relation-somewhere?-cached-caching-state* nil)
(deflexical *cached-find-assertions-cycl-caching-state* nil)

;;; Functions — following declare_czer_meta_file() ordering

;; (defun has-exception? (object) ...) -- no body, commented declareFunction
;; (defun accessible-kb-assertions (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun accessible-kb-assertions? (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun accessible-assertions-cycl (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun kb-versions (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun literal-meta-args (literal &optional mt) ...) -- no body, commented declareFunction
;; (defun el-assertion-spec? (spec &optional mt) ...) -- no body, commented declareFunction
;; (defun el-gaf-assertion-spec? (spec &optional mt) ...) -- no body, commented declareFunction
;; (defun el-rule-assertion-spec? (spec &optional mt) ...) -- no body, commented declareFunction
;; (defun el-asserted-assertion-spec? (spec &optional mt) ...) -- no body, commented declareFunction
;; (defun el-deduced-assertion-spec? (spec &optional mt) ...) -- no body, commented declareFunction
;; (defun el-constrained-assertion-spec? (spec constraint &optional mt) ...) -- no body, commented declareFunction
;; (defun el-nl-semantic-assertion-spec? (spec &optional mt) ...) -- no body, commented declareFunction
;; (defun common-el-sentences? (sentence) ...) -- no body, commented declareFunction
;; (defun meta-predicate? (pred &optional mt) ...) -- no body, commented declareFunction
;; (defun meta-relation? (relation &optional mt) ...) -- no body, commented declareFunction
;; (defun clear-meta-relation-somewhere? () ...) -- no body, commented declareFunction
;; (defun remove-meta-relation-somewhere? (relation) ...) -- no body, commented declareFunction
;; (defun meta-relation-somewhere?-internal (relation) ...) -- no body, commented declareFunction
;; (defun meta-relation-somewhere? (relation) ...) -- no body, commented declareFunction
;; (defun meta-relation-int? (relation &optional mt) ...) -- no body, commented declareFunction
;; (defun sentence-with-meta-predicate? (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun sentence-with-meta-relation? (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun possibly-meta-predicate? (pred &optional mt) ...) -- no body, commented declareFunction
;; (defun possibly-meta-relation? (relation &optional mt) ...) -- no body, commented declareFunction
;; (defun possibly-meta-relation-somewhere? (relation) ...) -- no body, commented declareFunction
;; (defun clear-possibly-meta-relation-somewhere?-cached () ...) -- no body, commented declareFunction
;; (defun remove-possibly-meta-relation-somewhere?-cached (relation) ...) -- no body, commented declareFunction
;; (defun possibly-meta-relation-somewhere?-cached-internal (relation) ...) -- no body, commented declareFunction
;; (defun possibly-meta-relation-somewhere?-cached (relation) ...) -- no body, commented declareFunction
;; (defun possibly-meta-relation-int? (relation &optional mt) ...) -- no body, commented declareFunction
;; (defun sentence-with-possibly-meta-predicate? (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun sentence-with-possibly-meta-relation? (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun possibly-meta-arg? (relation argnum &optional mt) ...) -- no body, commented declareFunction
;; (defun possibly-but-not-definitely-meta-arg? (relation argnum &optional mt) ...) -- no body, commented declareFunction
;; (defun definitely-meta-arg? (relation argnum &optional mt) ...) -- no body, commented declareFunction

(defun find-assertion-cycl (sentence &optional (mt *mt*))
  "[Cyc] May return an arbitrary assertion if more than one assertion matches SENTENCE."
  (when (or (el-formula-p sentence)
            (kb-assertion? sentence))
    (first (find-kb-assertions sentence mt))))

;; (defun find-unique-assertion-cycl (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun find-visible-assertion-cycl (sentence &optional mt) ...) -- no body, commented declareFunction

(defun find-kb-assertions (sentence &optional (mt *mt*))
  "[Cyc] Find KB assertions matching SENTENCE in MT."
  (cond
    ((kb-assertion? sentence)
     (list sentence))
    ((mt-designating-literal? sentence)
     ;; missing-larkc 30500 likely extracts the designated sentence from the literal
     ;; missing-larkc 30480 likely extracts the designated mt from the literal
     (find-kb-assertions (missing-larkc 30500) (missing-larkc 30480)))
    (t
     (find-assertions-cycl sentence mt))))

;; (defun find-visible-kb-assertions (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun find-visible-sibling-mt-assertions (sentence) ...) -- no body, commented declareFunction
;; (defun find-some-assertion-cycl (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun all-kb-assertions-findable? (sentence &optional mt) ...) -- no body, commented declareFunction
;; (defun recanonicalized-candidate-assertion-equals-cnf? (cnf assertion) ...) -- no body, commented declareFunction
;; (defun recanonicalized-candidate-assertion-equals-gaf? (gaf assertion) ...) -- no body, commented declareFunction
;; (defun recanonicalize-candidate-assertion () ...) -- no body, commented declareFunction
;; (defun candidate-assertion-el-formula () ...) -- no body, commented declareFunction
;; (defun candidate-assertion-fi-formula () ...) -- no body, commented declareFunction

(defun robust-assertion-lookup? ()
  "[Cyc] Returns t iff we want to look up assertions robustly (by recanonicalization of assertions already existing in the KB). This can be set to t or nil by the global variable *robust-assertion-lookup*, but can also be set to :default. If it's set to :default, it used to be t iff we're in the canonicalizer, the wff-checker, or the recanonicalizer, but now (after Nov 2002) the default is nil. It's too inefficient to try this by default; the problem should be solved at its root by recanonicalizing the uncanonical assertions."
  (if (eq :default *robust-assertion-lookup*)
      nil
      *robust-assertion-lookup*))

(defun find-assertions-cycl (sentence &optional (mt *mt*))
  "[Cyc] Finds a list of assertions in the KB which match the EL sentence SENTENCE.
It does this by finding the best index, then looping through that index and using *cnf-matching-predicate*
to check the equality of the canonical version of SENTENCE and the cnf expansion of each assertion.
Assumes that the assertions in the KB are in canonical form, unless robust-assertion-lookup? is true.
@return 0 list; a list of assertions
@return 1 booleanp; whether there are some assertions specified by SENTENCE which were _not_ found.
This could happen for example when SENTENCE is a conjunction.
@see robust-assertion-lookup?"
  (cond
    ((el-formula-p sentence)
     (let ((fort-mt (reify-when-closed-naut mt)))
       (when (hlmt-p fort-mt)
         (if (or *within-canonicalizer?*
                 *within-wff?*)
             ;; missing-larkc 9602 likely calls a variant of find-assertions-cycl-int
             ;; that uses the czer memoization state for caching within the canonicalizer
             (missing-larkc 9602)
             (find-assertions-cycl-int sentence fort-mt nil)))))
    ((kb-assertion? sentence)
     (list sentence))
    (t nil)))

;; (defun find-visible-assertions-cycl (sentence &optional mt) ...) -- no body, commented declareFunction

;; Partially missing-larkc defun-cached, where the clearing functionality is still called
(defun clear-cached-find-assertions-cycl ()
  "[Cyc] Clear the cached find-assertions-cycl results."
  (let ((cs *cached-find-assertions-cycl-caching-state*))
    (when cs
      (caching-state-clear cs)))
  nil)

;; (defun remove-cached-find-assertions-cycl (sentence mt include-genl-mts?) ...) -- no body, commented declareFunction
;; (defun cached-find-assertions-cycl-internal (sentence mt include-genl-mts?) ...) -- no body, commented declareFunction
;; (defun cached-find-assertions-cycl (sentence mt include-genl-mts?) ...) -- no body, commented declareFunction

(defun find-assertions-cycl-int (sentence mt include-genl-mts?)
  "[Cyc] Find assertions for SENTENCE in MT, with optional genl-mt inclusion."
  (multiple-value-bind (result missing?)
      (find-assertions-cycl-int-2 sentence mt include-genl-mts?)
    (when (and (null result)
               (robust-assertion-lookup?))
      (let ((*cnf-matching-predicate* 'recanonicalized-candidate-assertion-equals-cnf?)
            (*gaf-matching-predicate* 'recanonicalized-candidate-assertion-equals-gaf?))
        (multiple-value-setq (result missing?)
          (find-assertions-cycl-int-2 sentence mt include-genl-mts?))))
    (values result missing?)))

(defun find-assertions-cycl-int-2 (sentence mt include-genl-mts?)
  "[Cyc] @return 0 a list of assertions found corresponding to SENTENCE in MT
@return 1 booleanp; whether there are some assertions specified by SENTENCE which were _not_ found.
This could happen for example when SENTENCE is a conjunction.
@return 2 something else"
  (let* ((new-var-sentence (el-nununiquify-vars sentence))
         (all-assertions nil)
         (canon-cnf-tvs nil)
         (blists nil)
         (missing? nil))
    (multiple-value-setq (canon-cnf-tvs blists mt)
      (canon-cnfs-sentence new-var-sentence t mt))
    (unless (cycl-truth-value-p blists)
      (loop for cnf-tv in canon-cnf-tvs
            for blist in blists
            do (destructuring-bind (cnf . hl-tv) cnf-tv
                 (declare (ignore hl-tv))
                 (let ((assertions-for-cnf (find-assertions-from-cnf cnf blist mt include-genl-mts?)))
                   (when (null assertions-for-cnf)
                     (setf missing? t))
                   (setf all-assertions (nconc all-assertions assertions-for-cnf))))))
    (when (null all-assertions)
      (setf missing? t))
    (values (nreverse all-assertions) missing?)))

(defun find-assertions-from-cnf (cnf blist mt include-genl-mts?)
  "[Cyc] Find assertions from a specific CNF clause."
  (let ((assertions-for-cnf nil))
    ;; Handle mt-designating literals
    (when (and (pos-atomic-cnf-p cnf)
               (mt-designating-literal? (atomic-cnf-asent cnf))
               ;; missing-larkc 30481 likely extracts the designated mt from the literal
               (hlmt-p (missing-larkc 30481)))
      ;; missing-larkc 9633 likely calls find-assertions-from-mt-designating-literal
      (let ((new-assertions (missing-larkc 9633)))
        (setf assertions-for-cnf (nconc assertions-for-cnf new-assertions))))
    ;; Handle decontextualized literals
    (if (decontextualized-atomic-cnf? cnf)
        (let ((new-assertions
                ;; missing-larkc 9632 likely calls find-assertions-from-decontextualized-literal
                (missing-larkc 9632)))
          (setf assertions-for-cnf (nconc assertions-for-cnf new-assertions)))
        ;; Normal case
        (let ((new-assertions
                (cond
                  ((all-mts-are-relevant?)
                   ;; missing-larkc 12712 likely finds assertions across all mts
                   (missing-larkc 12712))
                  (include-genl-mts?
                   ;; missing-larkc 12714 likely finds assertions in mt and genl-mts
                   (missing-larkc 12714))
                  (t
                   (non-null-answer-to-singleton (find-assertion cnf mt))))))
          (when new-assertions
            (setf assertions-for-cnf (nconc assertions-for-cnf new-assertions)))))
    assertions-for-cnf))

;; (defun find-assertions-from-mt-designating-literal (cnf blist) ...) -- no body, commented declareFunction
;; (defun find-assertions-from-decontextualized-literal (cnf blist) ...) -- no body, commented declareFunction
;; (defun canon-versions (sentence &optional mt) ...) -- no body, commented declareFunction

(defun canon-versions-sentence (sentence &optional (mt *mt*))
  "[Cyc] Canonicalize SENTENCE in MT for assertion purposes."
  (let ((canon-versions nil))
    (let ((*noting-at-violations?* nil)
          (*accumulating-at-violations?* nil)
          (*noting-wff-violations?* nil)
          (*accumulating-wff-violations?* nil)
          (*within-assert* nil)
          (*within-ask* nil))
      ;; TODO - clearly a macroexpansion from somewhere, but this test & error message are nowhere to be found
      (unless (valid-tense-czer-mode-p :assert)
        (error "Cannot set tense czer to invalid mode."))
      (let ((*tense-czer-mode* :assert))
        (multiple-value-setq (canon-versions mt)
          (canonicalize-wf-cycl-sentence sentence mt))))
    (values canon-versions mt)))

;; (defun canon-cnfs (sentence &optional canon-gaf? mt) ...) -- no body, commented declareFunction

(defun canon-cnfs-sentence (sentence &optional canon-gaf? (mt *mt*))
  "[Cyc] Canonicalize SENTENCE to CNF form."
  (let ((canon-versions nil))
    (multiple-value-setq (canon-versions mt)
      (canon-versions-sentence sentence mt))
    (let ((blists (extract-blists canon-versions))
          (result nil))
      (when (el-formula-p canon-versions)
        (dolist (canon-version canon-versions)
          (multiple-value-bind (cnf v-variables hl-tv)
              (fi-canonicalize canon-version canon-gaf?)
            (declare (ignore v-variables))
            (if canon-gaf?
                (push (cons cnf hl-tv) result)
                (push cnf result)))))
      (values (nreverse result) blists mt))))

(defun canonicalize-meta-clauses (v-clauses)
  "[Cyc] Canonicalize meta-proposition clauses."
  (cond
    ((eq #$True v-clauses) v-clauses)
    ((eq #$False v-clauses) v-clauses)
    (t
     (let ((result nil))
       (dolist (clause v-clauses)
         (cond
           ((distributing-meta-proposition-clause? clause)
            ;; missing-larkc 9628 likely calls express-as-distributed-meta-proposition
            (setf result (nconc (missing-larkc 9628) result)))
           ((meta-proposition-clause? clause)
            ;; missing-larkc 9630 likely calls express-as-meta-proposition
            (push (missing-larkc 9630) result))
           (t
            (push clause result))))
       (nreverse result)))))

;; (defun express-as-meta-proposition (clause) ...) -- no body, commented declareFunction
;; (defun transform-delta (formula old-pred new-pred &optional old-mt new-mt) ...) -- no body, commented declareFunction
;; (defun ntransform-delta (formula old-pred new-pred &optional old-mt new-mt) ...) -- no body, commented declareFunction
;; (defun ntransform-delta-int (formula old-pred new-pred &optional old-mt new-mt) ...) -- no body, commented declareFunction
;; (defun express-as-meta-formula (clause) ...) -- no body, commented declareFunction
;; (defun meta-assertion-formulas (assertion) ...) -- no body, commented declareFunction
;; (defun express-as-meta-formula-int (clause assertion) ...) -- no body, commented declareFunction
;; (defun express-as-distributed-meta-proposition (clause) ...) -- no body, commented declareFunction
;; (defun express-asent-as-distributed-meta-proposition (asent) ...) -- no body, commented declareFunction

(defun meta-proposition-clause? (clause)
  "[Cyc] Return T iff CLAUSE contains a meta-proposition (a formula about formulas)."
  (dolist (asent (neg-lits clause))
    (when (contains-subformula-p asent)
      (if *within-ask*
          (when (expression-find-if 'el-meta-formula? asent)
            (return-from meta-proposition-clause? t))
          (when (expression-find-if 'ground-el-meta-formula? asent)
            (return-from meta-proposition-clause? t)))))
  (dolist (asent (pos-lits clause))
    (when (contains-subformula-p asent)
      (if *within-ask*
          (when (expression-find-if 'el-meta-formula? asent)
            (return-from meta-proposition-clause? t))
          (when (expression-find-if 'ground-el-meta-formula? asent)
            (return-from meta-proposition-clause? t)))))
  nil)

(defun distributing-meta-proposition-clause? (clause)
  "[Cyc] Return T iff CLAUSE consists of exactly one pos-lit which is both a meta-literal and a distributing-meta-literal."
  (when (null (neg-lits clause))
    (let* ((pos-lits (pos-lits clause))
           (literal (first pos-lits)))
      (when (singleton? pos-lits)
        (and (distributing-meta-literal? literal)
             ;; missing-larkc 9646 likely tests meta-literal?
             (missing-larkc 9646))))))

(defun distributing-meta-literal? (literal)
  "[Cyc] Return T iff LITERAL is a distributing meta-literal."
  (when (and (contains-subformula-p literal)
             ;; missing-larkc 30580 likely tests that all subformulas are ground
             (missing-larkc 30580))
    (or (distributing-meta-pred? (literal-arg0 literal))
        ;; missing-larkc 9612 likely tests for a non-distributing-meta-pred
        ;; that can be distributed over in special cases
        (missing-larkc 9612)
        (and *distribute-meta-over-common-el?*
             ;; missing-larkc 9642 likely tests meta-args-have-common-el-sentences?
             (missing-larkc 9642)))))

;; (defun distributing-meta-mt-literal? (literal) ...) -- no body, commented declareFunction
;; (defun meta-mt-literal? (literal) ...) -- no body, commented declareFunction
;; (defun meta-mt-formula? (formula) ...) -- no body, commented declareFunction
;; (defun meta-literal? (literal &optional mt) ...) -- no body, commented declareFunction
;; (defun meta-formula? (formula &optional mt) ...) -- no body, commented declareFunction
;; (defun meta-args-wff? (literal &optional mt check-mt?) ...) -- no body, commented declareFunction
;; (defun findable-assertion-arg? (literal argnum asent mt) ...) -- no body, commented declareFunction
;; (defun meta-args-have-common-el-sentences? (formula &optional mt) ...) -- no body, commented declareFunction
;; (defun el-meta-formula? (formula &optional mt) ...) -- no body, commented declareFunction
;; (defun ground-meta-formula? (formula &optional mt check-mt?) ...) -- no body, commented declareFunction
;; (defun ground-el-meta-formula? (formula &optional mt check-mt?) ...) -- no body, commented declareFunction

;;; Setup phase

(toplevel
  (note-globally-cached-function 'meta-relation-somewhere?)
  (note-globally-cached-function 'possibly-meta-relation-somewhere?-cached)
  (note-globally-cached-function 'cached-find-assertions-cycl))
