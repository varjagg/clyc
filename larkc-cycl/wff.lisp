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


;;;; WFF — Well-formed formula checking for CycL.

(in-package :clyc)

;; Functions (declare phase, in declare_wff_file order)

(defun el-wff? (sentence &optional (mt *mt*) (v-properties nil))
  "[Cyc] Is SENTENCE a well-formed el sentence?"
  (check-type v-properties list)
  (do-plist (property _value v-properties)
    (check-type property (satisfies wff-property-p)))
  (let ((wff? nil))
    (with-wff-formula sentence
      (with-wff-memoization-state
        (with-wff-properties v-properties
          (setf wff? (wff? sentence :elf mt)))))
    wff?))

;; (defun el-wff-assertible? (sentence &optional mt properties) ...) -- commented declaration, no body
;; (defun hl-wff? (formula &optional mt properties) ...) -- commented declaration, no body

(defun wff? (formula &optional (type :elf) (mt *mt*))
  (case type
    (:elf (wff-elf? formula mt))
    (:cnf (missing-larkc 8101)) ;; wff-cnf?
    (:dnf (missing-larkc 8103)) ;; wff-dnf?
    (:naf (missing-larkc 8106)) ;; wff-naf?
    (otherwise (missing-larkc 8105))))

;; (defun wff-in-any-mt? (formula type) ...) -- commented declaration, no body

(defun reset-wff-state ()
  (unless *within-canonicalizer?*
    (clear-canon-caches))
  (reset-wff-violations)
  (reset-wff-suggestions)
  (reset-at-state)
  nil)

(defun mal-precanonicalizations? (formula mt)
  (multiple-value-bind (precanonicalized-formula precanonicalized-mt)
      (safe-precanonicalizations formula mt)
    (when (or (null precanonicalized-formula)
              (null precanonicalized-mt))
      (when (null (wff-violations))
        ;; missing-larkc 8075 — likely note-wff-violation for :mal-precanonicalizations
        (missing-larkc 8075))
      (return-from mal-precanonicalizations? t)))
  (and (wff-violations) t))

(defun syntactically-wff-elf-int? (sentence check-fast-gaf?)
  (let ((wff? t))
    (within-wff
      (when (mal-variables? sentence)
        (setf wff? nil)
        ;; missing-larkc 8076 — likely note-wff-violation for :invalid-variables
        (missing-larkc 8076)))
    (within-wff
      (when wff?
        (when (and *check-wff-constants?*
                   (mal-forts? sentence))
          (setf wff? nil)
          (note-wff-violation (list :mal-forts (mal-forts sentence))))))
    (within-wff
      (when wff?
        (cond ((and check-fast-gaf? (wff-fast-gaf? sentence))
               (setf wff? t))
              ((cycl-sentence-p sentence)
               (setf wff? t))
              (t
               (setf wff? nil)))))
    wff?))

(defun wff-elf? (sentence mt)
  (let ((wff? t)
        (violations nil))
    (let ((*wff-violations* nil))
      (setf wff? (syntactically-wff-elf-int? sentence nil))
      (let ((wff-mt (reify-when-closed-naut mt)))
        (unless (wff-done? wff?)
          (unless (hlmt-p wff-mt)
            ;; missing-larkc 30598 — likely czer-utilities:canonicalize-sentence or similar
            (setf sentence (missing-larkc 30598))
            (setf wff-mt #$BaseKB))
          (when (mal-mt-spec? wff-mt)
            (setf wff? nil)
            ;; missing-larkc 8078 — likely note-wff-violation for :invalid-mt
            (missing-larkc 8078)
            (when (and (provide-wff-suggestions?)
                       (hlmt-p wff-mt)
                       (mt-in-any-mt? wff-mt))
              ;; missing-larkc 8020 — likely note-wff-suggestion for MT change
              (missing-larkc 8020))))
        (unless (or (wff-only-needs-syntactic-checks?)
                    (null wff?))
          (let ((mt-var (with-inference-mt-relevance-validate wff-mt)))
            (let ((*mt* (update-inference-mt-relevance-mt mt-var))
                  (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
                  (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
              (unless (wff-done? wff?)
                (within-wff
                  (setf wff? (not (mal-precanonicalizations? sentence wff-mt)))))
              (unless (wff-done? wff?)
                (let ((*check-arity?* nil)
                      (*check-arg-types?* (wff-check-args?))
                      (*check-wff-coherence?* (wff-check-coherence?))
                      (*check-var-types?* (wff-check-vars?)))
                  (within-wff
                    (setf wff? (and (wff-elf-int? sentence *mt*) wff? t)))
                  (unless (wff-done? wff?)
                    (when (check-var-types? sentence)
                      (within-wff
                        (unless (if *at-assume-conjuncts-independent?*
                                    (formula-var-types-ok-int? sentence *mt*)
                                    ;; missing-larkc 11780 — likely formula-var-types-ok? without independence assumption
                                    (missing-larkc 11780))
                          (setf wff? nil)
                          ;; missing-larkc 7235 — likely at-var-type violations
                          (note-wff-violations (missing-larkc 7235))))))
                  (unless (wff-done? wff?)
                    (when (check-wff-coherence? sentence :elf)
                      (within-wff
                        ;; missing-larkc 8102 — likely wff-coherent? check
                        (unless (missing-larkc 8102)
                          (setf wff? nil)))))))
              (unless (wff-done? wff?)
                (when (check-wff-expansion? sentence)
                  (let ((*within-assert* nil))
                    ;; missing-larkc 8104 — likely wff-el-expansion returning (expansion mt)
                    (multiple-value-bind (expansion mt-16)
                        (missing-larkc 8104)
                      (let ((*relax-arg-constraints-for-disjunctions?*
                              (not (atomic-sentence? sentence))))
                        (when (and expansion (not (equal sentence expansion)))
                          (let ((*unexpanded-formula* sentence)
                                (*validate-expansions?* nil)
                                (*validating-expansion?* t)
                                (*wff-expansion-formula*
                                  (if (and (within-wff?)
                                           ;; missing-larkc 32200 — likely wff-expansion-formula accessor
                                           (missing-larkc 32200))
                                      ;; missing-larkc 32201 — likely wff-expansion-formula value
                                      (missing-larkc 32201)
                                      expansion)))
                            (unless (wff-elf? expansion mt-16)
                              (setf wff? nil)))))))))))))
      (setf violations (wff-violations)))
    (note-wff-violations violations)
    wff?))

;; (defun wff-el-expansion (sentence mt) ...) -- commented declaration, no body

(defun el-wff-syntax? (sentence &optional mt)
  "[Cyc] Is SENTENCE well-formed wrt syntax?"
  (declare (ignore mt))
  (syntactically-wff-elf-int? sentence t))

(defun wff-elf-int? (sentence &optional mt)
  (cond ((eq #$True sentence) t)
        ((eq #$False sentence) (not (within-assert?)))
        ((wff-fast-gaf? sentence) t)
        (t (semantically-wff-elf-int? sentence mt))))

;; (defun why-not-semantically-wf-wrt-types (sentence mt) ...) -- commented declaration, no body

(defun semantically-wff-elf-int? (sentence mt)
  (cond ((assertion-p sentence) t)
        ((el-atomic-sentence? sentence)
         (semantically-wf-literal? sentence mt))
        ((el-non-atomic-sentence? sentence)
         (semantically-wf-non-atomic-sentence? sentence mt))
        ((cyc-var? sentence) *encapsulate-var-formula?*)
        ;; missing-larkc 31894 — likely naut-p or similar, checking if sentence is some special form
        ((missing-larkc 31894) nil)
        (t (error "Got a sentence that was neither atomic nor non-atomic in mt ~s: ~s"
                  mt sentence))))

(defun wff-fast-gaf? (sentence)
  "[Cyc] Return T iff SENTENCE is a gaf which is well-formed (a quick check
before a more involved analysis of well-formedness).
Returning NIL does not mean that SENTENCE is ill-formed."
  (and (no-wff-semantics?)
       (member (formula-operator sentence)
               (list #$isa #$genls #$myCreator #$myCreationTime
                     #$myCreationPurpose #$myCreationSecond))
       (formula-arity= sentence 2)
       (not (contains-subformula-p sentence))
       (ground? sentence #'el-var?)))

;; (defun wff-naf? (formula &optional mt) ...) -- commented declaration, no body
;; (defun wff-cnf? (formula &optional mt) ...) -- commented declaration, no body
;; (defun wff-cnf-int? (formula) ...) -- commented declaration, no body
;; (defun wff-dnf? (formula &optional mt) ...) -- commented declaration, no body
;; (defun wff-literal? (formula &optional mt) ...) -- commented declaration, no body

;; commented declareFunction, but body present in Java — ported for reference
(defun wff-query? (formula &optional (mt *mt*) (v-properties nil))
  "[Cyc] Is FORMULA a well-formed CycL query in MT wrt syntax and arity?"
  (check-type v-properties list)
  (do-plist (property _value v-properties)
    (check-type property (satisfies wff-property-p)))
  (let ((result nil))
    (let ((*within-ask* t))
      (let ((mt-var (with-inference-mt-relevance-validate (canonicalize-hlmt mt))))
        (let ((*mt* (update-inference-mt-relevance-mt mt-var))
              (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
              (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var))
              (*check-wff-semantics?* (check-wff-semantics? mt))
              (*at-check-relator-constraints?* *check-wff-semantics?*))
          (with-wff-properties v-properties
            (setf result (el-wff-syntax? formula))))))
    result))

;; (defun wff-check-arity? () ...) -- commented declaration, no body
;; (defun arity-tests-apply? (formula-arg0 argnum) ...) -- commented declaration, no body

(defun check-arity? (&optional formula-arg0 argnum)
  "[Cyc] Return T iff arg-type analysis should in fact impose arity checks on nats."
  (and *check-arity?*
       (or (not (and (fort-p formula-arg0) (integerp argnum)))
           ;; missing-larkc 7971 — likely arity-tests-apply? check
           (missing-larkc 7971))))

(defun wff-check-args? ()
  (and *check-arg-types?* *check-wff-semantics?*))

(defun wff-check-coherence? ()
  (and *check-wff-coherence?* *check-wff-semantics?*))

(defun wff-check-vars? ()
  (and *check-var-types?* (wff-check-args?)))

(defun* inhibit-skolem-asserts? () (:inline t)
  *inhibit-skolem-asserts?*)

(defun* enforce-evaluatable-satisfiability? () (:inline t)
  *enforce-evaluatable-satisfiability?*)

(defun* enforce-only-definitional-gafs-in-vocab-mt? () (:inline t)
  *enforce-only-definitional-gafs-in-vocab-mt?*)

(defun* enforce-literal-idiosyncrasies? () (:inline t)
  *enforce-literal-wff-idiosyncrasies?*)

(defun check-var-types? (formula &optional (var? #'cyc-var?))
  (when (not (within-wff?))
    (when *check-var-types?*
      (tree-find-if var? formula))))

(defun no-wff-semantics? ()
  "[Cyc] Return T iff ALL semantic wff checking is disabled."
  (and (not *check-arg-types?*)
       (not *check-wff-semantics?*)
       (not *check-wff-coherence?*)
       (not *check-var-types?*)
       (not *at-check-relator-constraints?*)
       (not *at-check-arg-format?*)))

;; (defun no-wff-semantics-or-arity? () ...) -- commented declaration, no body

(defun wff-only-needs-syntactic-checks? ()
  "[Cyc] Whether the wff-checker can use the CycL grammar instead of the full semantic wff-checker."
  (and *use-cycl-grammar-if-semantic-checking-disabled?*
       (not *accumulating-wff-violations?*)
       (no-wff-semantics?)))

(defun check-wff-expansion? (formula)
  (declare (ignore formula))
  (when (not (within-wff?))
    (when *validate-expansions?*
      ;; missing-larkc 4365 — likely expandable-formula? or similar test
      (missing-larkc 4365))))

(defun check-wff-coherence? (formula &optional (form :elf))
  (when (not (within-wff?))
    (when *check-wff-coherence?*
      (case form
        (:elf (not (el-atomic-sentence? formula)))
        (:cnf (not (gaf-cnf? formula)))))))

(defun wff-done? (&optional (wff? t))
  (unless (accumulating-el-violations?)
    (or (null wff?) (wff-violations))))

(defun mal-forts? (expression)
  (expression-find-if #'non-wf-fort-p expression))

(defun mal-forts (expression)
  (expression-gather expression #'non-wf-fort-p))

;; (defun valid-top-level-backward-inference-literal? (literal) ...) -- commented declaration, no body
;; (defun valid-intermediate-backward-inference-literal? (literal) ...) -- commented declaration, no body
;; (defun valid-top-level-forward-inference-literal? (literal) ...) -- commented declaration, no body
;; (defun valid-intermediate-forward-inference-literal? (literal) ...) -- commented declaration, no body

(defun semantically-wf-literal? (literal &optional (mt *mt*))
  (if (within-wff?)
      (memoized-semantically-wf-literal? literal mt (no-wff-semantics?) (check-assertible-literal?))
      (let ((wff? nil))
        (let ((*wff-violations* nil))
          ;; missing-larkc 8010 — likely a syntax/precanon check on the literal
          (setf wff? (missing-larkc 8010))
          (unless (wff-done? wff?)
            (setf wff? (memoized-semantically-wf-literal? literal mt (no-wff-semantics?) (check-assertible-literal?)))))
        wff?)))

;; (defun memoized-syntactically-wf-formula?-internal (formula) ...) -- commented declaration, no body
;; (defun memoized-syntactically-wf-formula? (formula) ...) -- commented declaration, no body
;; (defun semantically-wf-literal-in-any-mt? (literal) ...) -- commented declaration, no body

;; no-semantics? and check-assertible? are part of the cache key but not used in the body;
;; the body re-checks via (check-assertible-literal?) dynamically
(defun-memoized memoized-semantically-wf-literal?
    (literal mt no-semantics? check-assertible?)
    (:test equal)
  (when (or (not (check-assertible-literal?))
            (assertible-literal? literal mt))
    (and (semantically-wf-sentence? literal mt)
         (wff-wrt-literal-idiosyncrasies? literal mt))))

(defun assertible-literal? (literal &optional mt)
  "[Cyc] Applies to top-level and sub-formula literals."
  (let ((unassertible? nil))
    (when (inhibit-skolem-asserts?)
      (unless (pred-of-editable-skolem-gaf? (literal-predicate literal))
        (when (non-editable-skolem-reference? literal)
          (setf unassertible? t)
          ;; missing-larkc 8082 — likely note-wff-violation for :restricted-skolem-assertion
          (missing-larkc 8082))))
    (unless (wff-done? (not unassertible?))
      (when (enforce-evaluatable-satisfiability?)
        (when (closed? literal #'cyc-var?)
          (when (evaluatable-predicate? (literal-predicate literal) mt)
            (multiple-value-bind (answer valid?)
                (cyc-evaluate literal)
              (when valid?
                (unless (and answer (not (eq answer #$False)))
                  (setf unassertible? t)
                  ;; missing-larkc 8083 — likely note-wff-violation for :evaluatable-literal-false
                  (missing-larkc 8083))))))))
    (unless (wff-done? (not unassertible?))
      (multiple-value-bind (unwrapped-literal unwrapped-mt)
          (unwrap-if-ist-permissive literal mt)
        (let ((decontextualized-literal? (decontextualized-literal? unwrapped-literal))
              (decontextualized-mt nil))
          (when decontextualized-literal?
            (setf decontextualized-mt (decontextualized-literal-convention-mt unwrapped-literal))
            (unless (mt-matches-convention-mt? unwrapped-mt decontextualized-mt)
              (setf unwrapped-mt decontextualized-mt)))
          (unless (or *within-function?* *within-predicate?*)
            (when (and unwrapped-mt (not-assertible-mt? unwrapped-mt))
              (setf unassertible? t)
              ;; missing-larkc 8084 — likely note-wff-violation for :restricted-mt-assertion
              (missing-larkc 8084))))))
    (unless (wff-done? (not unassertible?))
      (unless (or *appraising-disjunct?*
                  *within-function?*
                  *within-predicate?*
                  (not (closed? literal)))
        (if (not-assertible-predicate? (literal-predicate literal) mt)
            (progn
              (setf unassertible? t)
              ;; missing-larkc 8085 — likely note-wff-violation for :restricted-predicate-assertion
              (missing-larkc 8085))
            (when (and (isa-lit? literal)
                       (not-assertible-collection? (literal-arg2 literal) mt))
              (setf unassertible? t)
              ;; missing-larkc 8086 — likely note-wff-violation for :restricted-collection-assertion
              (missing-larkc 8086)))))
    (unless (wff-done? (not unassertible?))
      (unless (or *appraising-disjunct?*
                  *within-function?*
                  *within-predicate?*)
        (when (and *reject-sbhl-conflicts?*
                   (sbhl-literal-conflict? literal mt))
          (setf unassertible? t))))
    (when (enforce-only-definitional-gafs-in-vocab-mt?)
      (unless (wff-done? (not unassertible?))
        (unless (or *appraising-disjunct?*
                    *within-function?*
                    *within-predicate?*
                    (not (closed? literal)))
          (let ((assert-mt (or mt *mt*))
                (assert-pred (literal-predicate literal)))
            (when (and (hlmt-p assert-mt)
                       (fort-p assert-pred)
                       (isa? assert-mt #$VocabularyMicrotheory))
              (unless (or
                       ;; missing-larkc 7975 — likely definitional-pred? check
                       (missing-larkc 7975)
                       ;; missing-larkc 8011 — likely meta-sentence-referencing-defn-gaf-in-mt? check
                       (missing-larkc 8011))
                (setf unassertible? t)
                ;; missing-larkc 8087 — likely note-wff-violation for :non-defn-pred-in-vocab-mt
                (missing-larkc 8087)))))))
    (not unassertible?)))

;; (defun meta-sentence-referencing-defn-gaf-in-mt? (literal mt) ...) -- commented declaration, no body
;; (defun definitional-pred? (pred &optional mt) ...) -- commented declaration, no body

(defun sbhl-literal-conflict? (literal &optional mt)
  "[Cyc] Return T iff literal, if asserted, establishes a sbhl conflict."
  (let ((conflict? nil))
    (if (within-negation?)
        (when
            ;; missing-larkc 8096 — likely sbhl-true? check (asserting negation conflicts with known truth)
            (missing-larkc 8096)
          ;; missing-larkc 8088 — likely note-wff-violation for :conflict-asserting-false-sbhl
          (missing-larkc 8088)
          (setf conflict? t))
        (when (sbhl-false? literal mt)
          ;; missing-larkc 8089 — likely note-wff-violation for :conflict-asserting-true-sbhl
          (missing-larkc 8089)
          (setf conflict? t)))
    conflict?))

;; (defun sbhl-true? (asent &optional mt) ...) -- commented declaration, no body

(defun sbhl-false? (asent &optional mt)
  "[Cyc] Return T iff ASENT is known to be false via sbhl inference."
  (let ((pred (literal-predicate asent))
        (arg1 (literal-arg1 asent))
        (arg2 (literal-arg2 asent)))
    (when (and (sbhl-non-time-predicate-p pred)
               (el-fort-p arg2))
      (let ((module (get-sbhl-module pred)))
        (if (sbhl-disjoins-module-p module)
            (sbhl-false-predicate-relation-p module arg1 arg2 mt)
            (sbhl-implied-false-predicate-relation-p module arg1 arg2 mt))))))

(defun non-editable-skolem-reference? (object)
  "[Cyc] Return term or nil; term is object or a component of object that
is returned iff that component has a variable within the scope of
a skolem as a functor."
  (cond
    ((and (constant-p object)
          (fast-reified-skolem? object))
     object)
    ((el-formula-p object)
     (when (formula-find-if #'fast-reified-skolem? object t)
       (if (fast-reified-skolem? (nat-functor object))
           (if (closed? object #'cyc-var?)
               (let ((relation (formula-arg0 object))
                     (ans nil))
                 (let ((argnum 0)
                       (args (nat-args object)))
                   (loop while (consp (rest args))
                         for arg = (first args)
                         do (unless (or
                                    ;; missing-larkc 8832 — likely evaluatable-arg? check
                                    (missing-larkc 8832)
                                    (quoted-argument? relation argnum)
                                    ;; missing-larkc 8778 — likely opaque-arg? check
                                    (missing-larkc 8778))
                              (setf ans (non-editable-skolem-reference? arg))
                              (when ans (return-from non-editable-skolem-reference? ans)))
                            (incf argnum)
                            (setf args (rest args)))
                   (unless (or
                            ;; missing-larkc 8833 — likely evaluatable-arg? for last arg
                            (missing-larkc 8833)
                            (quoted-argument? relation argnum)
                            ;; missing-larkc 8779 — likely opaque-arg? for last arg
                            (missing-larkc 8779))
                     (setf ans (non-editable-skolem-reference? (first args)))
                     (when ans (return-from non-editable-skolem-reference? ans))
                     (when (rest args)
                       (setf ans (non-editable-skolem-reference? (rest args))))))
                 ans)
               object)
           ;; Skolem in formula but not as functor — iterate all args
           (let ((relation (formula-arg0 object))
                 (ans nil))
             (let ((argnum 0)
                   (args object))
               (loop while (consp (rest args))
                     for arg = (first args)
                     do (unless (or
                                ;; missing-larkc 8834 — likely evaluatable-arg? check
                                (missing-larkc 8834)
                                (quoted-argument? relation argnum)
                                ;; missing-larkc 8780 — likely opaque-arg? check
                                (missing-larkc 8780))
                          (setf ans (non-editable-skolem-reference? arg))
                          (when ans (return-from non-editable-skolem-reference? ans)))
                        (incf argnum)
                        (setf args (rest args)))
               (unless (or
                        ;; missing-larkc 8835 — likely evaluatable-arg? for last element
                        (missing-larkc 8835)
                        (quoted-argument? relation argnum)
                        ;; missing-larkc 8781 — likely opaque-arg? for last element
                        (missing-larkc 8781))
                 (setf ans (non-editable-skolem-reference? (first args)))
                 (when ans (return-from non-editable-skolem-reference? ans))
                 (when (rest args)
                   (setf ans (non-editable-skolem-reference? (rest args))))))
             ans))))
    ((not (null object))
     ;; missing-larkc 10752 — likely nart-el-formula or similar to get underlying formula
     (non-editable-skolem-reference? (missing-larkc 10752)))
    (t nil)))

(defun pred-of-editable-skolem-gaf? (pred)
  (or (member? pred *preds-of-editable-skolem-gafs*)
      (editable-skolem-predicate? pred)
      (bookkeeping-predicate-p pred)))

(defun editable-skolem-predicate? (pred)
  (declare (ignore pred))
  nil)

;; (defun inhibit-cyclic-commutative-in-args? () ...) -- commented declaration, no body
;; (defun except-for-wff? (literal) ...) -- commented declaration, no body
;; (defun tou-mt-ok? (literal mt) ...) -- commented declaration, no body

(defun wff-wrt-literal-idiosyncrasies? (literal mt)
  (if (enforce-literal-idiosyncrasies?)
      (let ((pred (literal-predicate literal)))
        (cond ((eq pred #$exceptFor)
               ;; missing-larkc 7992 — likely except-for-wff?
               (missing-larkc 7992))
              ((eq pred #$termOfUnit)
               ;; missing-larkc 8098 — likely tou-mt-ok?
               (missing-larkc 8098))
              ((eq pred #$commutativeInArgs)
               ;; missing-larkc 31087 — likely commutative-in-args ok check
               (missing-larkc 31087))
              ((eq pred #$commutativeInArgsAndRest)
               ;; missing-larkc 31088 — likely commutative-in-args-and-rest ok check
               (missing-larkc 31088))
              (t t)))
      t))

(defun semantically-wf-non-atomic-sentence? (nasent mt)
  (and (semantically-wf-sentence? nasent mt)
       (all-subsentences-semantically-wf? nasent mt)))

(defun all-subsentences-semantically-wf? (nasent mt)
  "[Cyc] Checks whether all subsentences (passing through sentential relations)
of the non-atomic sentence NASENT are semantically well-formed."
  (let ((wff? t)
        (truth-function (sentence-truth-function nasent)))
    (cond
      ((cycl-logical-operator-p truth-function)
       (let ((argnum 0))
         (dolist (subsentence (formula-args nasent :ignore))
           (incf argnum)
           (unless (subsentence-semantically-wf? nasent subsentence argnum mt)
             (setf wff? nil)))))
      ;; missing-larkc 30062 — likely cycl-quantifier-p check
      ((missing-larkc 30062)
       (let ((subsentence (quantified-sub-sentence nasent))
             (argnum (quantified-sub-sentence-argnum nasent)))
         (unless (subsentence-semantically-wf? nasent subsentence argnum mt)
           (setf wff? nil))))
      (t
       (error "Got an unexpected sentential relation ~s in ~s"
              truth-function nasent)))
    wff?))

(defun subsentence-semantically-wf? (nasent subsentence argnum mt)
  (let ((wff? t)
        (truth-function (sentence-truth-function nasent)))
    (let ((*within-negation?* (at-within-negation? truth-function argnum))
          (*within-disjunction?* (at-within-disjunct? nasent argnum))
          (*appraising-disjunct?* (appraising-disjunct? nasent mt)))
      (unless (wff-done? wff?)
        (unless (wff-elf-int? subsentence mt)
          (setf wff? nil))))
    wff?))

(defun semantically-wf-sentence? (sentence mt)
  (if (and mt (all-mts-are-relevant?))
      ;; missing-larkc 8097 — likely semantically-wf-sentence-in-any-mt?
      (missing-larkc 8097)
      (memoized-semantically-wf-sentence? sentence mt)))

;; (defun semantically-wf-sentence-in-any-mt? (sentence) ...) -- commented declaration, no body

(defun-memoized memoized-semantically-wf-sentence? (sentence mt) (:test equal)
  (not (mal-arg-types? sentence mt)))

(defun mal-arity? (formula)
  (when (null *check-arity?*)
    (return-from mal-arity? nil))
  (let ((operator (formula-operator formula)))
    (cond ((cycl-variable-p operator) nil)
          ((note-wff-violation?) (mal-arity-int? formula))
          ((sequence-var formula) (mal-arity-int? formula))
          (t (let ((actual-arity (expression-arity formula)))
               (mal-actual-arity-cached? operator actual-arity))))))

;; Variables (init phase)

;; (defun remove-mal-actual-arity-cached? (operator actual-arity) ...) -- commented declaration, no body

(defun-cached mal-actual-arity-cached? (operator actual-arity)
    (:capacity 256 :test equal :clear-when :hl-store-modified)
  (let* ((args (make-list actual-arity :initial-element :term))
         (formula (make-formula operator args)))
    (mal-arity-int? formula)))

(defun mal-arity-int? (formula)
  (let ((relation (reify-when-closed-naut (formula-operator formula)))
        (mal? nil))
    (when (or (fort-p relation)
              (kappa-predicate-p relation)
              (lambda-function-p relation))
      (if (variable-arity? relation)
          (setf mal? (mal-variable-arity? formula))
          (setf mal? (mal-fixed-arity? formula))))
    mal?))

(defun mal-fixed-arity? (formula)
  "[Cyc] Does FORMULA, with fixed-arity relation arg0, comply with applicable arity constraints?"
  (let ((relation (reify-when-closed-naut (formula-arg0 formula)))
        (v-arity (arity relation))
        (mal? nil))
    (cond
      ((null v-arity)
       (unless (and *relax-type-restrictions-for-nats*
                    (within-forward-inference?)
                    (nart-p relation))
         ;; missing-larkc 6874 — likely arity-unknown-ok? check
         (unless (missing-larkc 6874)
           ;; missing-larkc 8012 — likely note-wff-violation for :missing-arity
           (missing-larkc 8012)
           (setf mal? t))))
      ((not (cyc-non-negative-integer v-arity))
       ;; missing-larkc 8013 — likely note-wff-violation for :mal-arity
       (missing-larkc 8013)
       (setf mal? t))
      ((sequence-var formula)
       (unless (<= (expression-arity formula :ignore) v-arity)
         ;; missing-larkc 8014 — likely note-wff-violation for :violated-arity
         (missing-larkc 8014)
         (setf mal? t)))
      ((not (= v-arity (expression-arity formula)))
       ;; missing-larkc 8015 — likely note-wff-violation for :violated-arity
       (missing-larkc 8015)
       (setf mal? t))
      (t (setf mal? nil)))
    mal?))

(defun mal-variable-arity? (formula)
  "[Cyc] Does FORMULA, with variable-arity relation arg0, comply with applicable arity constraints?"
  (let ((relation (formula-arg0 formula))
        (v-arity (expression-arity formula :ignore))
        (mal? nil))
    (let ((arity-min (arity-min relation))
          (arity-max (arity-max relation)))
      (when arity-min
        (cond
          ((not (cyc-non-negative-integer arity-min))
           ;; missing-larkc 8016 — likely note-wff-violation for :mal-arity
           (missing-larkc 8016)
           (setf mal? t))
          ((and (not (>= v-arity arity-min))
                (null (sequence-var formula)))
           ;; missing-larkc 8017 — likely note-wff-violation for :violated-arity
           (missing-larkc 8017)
           (setf mal? t))))
      (when arity-max
        (cond
          ((not (cyc-non-negative-integer arity-max))
           ;; missing-larkc 8018 — likely note-wff-violation for :mal-arity
           (missing-larkc 8018)
           (setf mal? t))
          ((not (<= v-arity arity-max))
           ;; missing-larkc 8019 — likely note-wff-violation for :violated-arity
           (missing-larkc 8019)
           (setf mal? t)))))
    mal?))

(defun mal-arg-types? (formula &optional mt)
  (when (or (wff-check-args?)
            (not (atomic-sentence? formula))
            (ist-sentence-p formula))
    (let ((wff? nil))
      (reset-semantic-violations)
      (setf wff? (wff-wrt-arg-types? formula mt))
      (unless wff?
        (note-wff-violations (semantic-violations)))
      (not wff?))))

(defun wff-wrt-arg-types? (formula &optional mt)
  (formula-args-ok-wrt-type? formula mt))

;; (defun wff-coherent? (formula &optional mt) ...) -- commented declaration, no body
;; (defun wff-incoherent? (formula &optional mt) ...) -- commented declaration, no body
;; (defun elf-incoherent? (formula) ...) -- commented declaration, no body
;; (defun cnf-incoherent? (formula &optional mt) ...) -- commented declaration, no body
;; (defun kwt-wff? (formula &optional mt) ...) -- commented declaration, no body
;; (defun gat-wff? (formula &optional mt) ...) -- commented declaration, no body
;; (defun el-formula-ok? (formula &optional mt) ...) -- commented declaration, no body
;; (defun formula-ok? (formula &optional mt) ...) -- commented declaration, no body
;; (defun el-query-ok? (formula &optional mt) ...) -- commented declaration, no body
;; (defun query-ok? (formula &optional mt) ...) -- commented declaration, no body
;; (defun why-not-query-ok (formula &optional mt) ...) -- commented declaration, no body
;; (defun el-wft-fast? (term &optional mt) ...) -- commented declaration, no body
;; (defun el-wft-fast-in-mt? (term mt) ...) -- commented declaration, no body
;; (defun el-wft? (term &optional mt properties) ...) -- commented declaration, no body
;; (defun el-wfe? (term &optional mt properties) ...) -- commented declaration, no body
;; (defun wfe? (term &optional mt) ...) -- commented declaration, no body
;; (defun wfe-int? (term) ...) -- commented declaration, no body
;; (defun wff-note (format-string arg1 &optional arg2 arg3 arg4 arg5 arg6) ...) -- commented declaration, no body
;; (defun wff-error (format-string arg1 &optional arg2 arg3 arg4 arg5 arg6) ...) -- commented declaration, no body
;; (defun wff-cerror (continue-string format-string arg1 &optional arg2 arg3 arg4 arg5 arg6) ...) -- commented declaration, no body
;; (defun wff-warn (format-string arg1 &optional arg2 arg3 arg4 arg5 arg6) ...) -- commented declaration, no body

;; Variables (init phase)

(defvar *wff-trace-level* 1)

;; commented declareFunction, but body present in Java — ported for reference
(defun* wff-suggestions () (:inline t)
  *wff-suggestions*)

(defun* reset-wff-suggestions () (:inline t)
  (setf *wff-suggestions* nil))

(defun* provide-wff-suggestions? () (:inline t)
  *provide-wff-suggestions?*)

;; (defun note-wff-suggestion (suggestion) ...) -- commented declaration, no body
;; (defun note-wff-suggestions (suggestions) ...) -- commented declaration, no body

;; commented declareFunction, but body present in Java — ported for reference
(defun how-make-wff? (sentence &optional mt)
  (if (el-wff? sentence mt)
      #$True
      (wff-suggestions)))

;; (defun how-make-wft (term &optional mt) ...) -- commented declaration, no body

;; commented declareFunction, but body present in Java — ported for reference
(defun explanation-of-wff-suggestion (sentence &optional mt (suggestions (how-make-wff? sentence mt)))
  (let ((answer nil))
    (dolist (suggestion suggestions)
      (case (first suggestion)
        (:change-mt
         (destructuring-bind (sentence-1 mt-50 accommodating-mts)
             (rest suggestion)
           (cond ((null accommodating-mts))
                 ((not (equal sentence sentence-1)))
                 ((singleton? accommodating-mts)
                  (push (format nil "~%Consider asserting ~%  ~s~%in mt ~s."
                                sentence (first accommodating-mts))
                        answer))
                 (t
                  (push (format nil "~%Consider asserting ~%  ~s~%in one of these mts: ~s."
                                sentence (stringify-terms accommodating-mts ", " ", or "))
                        answer)))))
        (:replace-term
         (destructuring-bind (old-term new-term)
             (rest suggestion)
           (cond ((null new-term))
                 ((equal old-term new-term))
                 (t
                  (push (format nil "~%Consider using term ~%  ~s~%instead of term~%  ~s."
                                new-term old-term)
                        answer)))))
        (:assert
         (destructuring-bind (sentence-1 &optional mt-51)
             (rest suggestion)
           (if mt-51
               (push (format nil "~%Consider asserting ~%  ~s~%  in mt ~s."
                             sentence-1 mt-51)
                     answer)
               (push (format nil "~%Consider asserting ~%  ~s." sentence-1) answer))))
        (:unassert
         (destructuring-bind (sentence-1 &optional mt-52)
             (rest suggestion)
           (if mt-52
               (push (format nil "~%Consider unasserting ~%  ~s~%  in mt ~s."
                             sentence-1 mt-52)
                     answer)
               (push (format nil "~%Consider unasserting ~%  ~s." sentence-1) answer))))
        (otherwise
         (push (format nil "~%No explanation template exists for wff suggestion~%~s." suggestion) answer))))
    (strcat (nreverse answer))))

;; (defun explanation-of-wft-suggestion (term &optional mt suggestions) ...) -- commented declaration, no body

(defun accumulating-el-violations? ()
  (or *accumulating-wff-violations?*
      *accumulating-at-violations?*
      *accumulating-semantic-violations?*))

;; (defun note-arity-violation (formula) ...) -- commented declaration, no body
;; (defun diagnose-el-formula (sentence &optional mt io-mode) ...) -- commented declaration, no body
;; (defun diagnose-el-term (term &optional mt io-mode) ...) -- commented declaration, no body

;; commented declareFunction, but body present in Java — ported for reference
(defun why-not-wff (sentence &optional (mt *mt*) (v-properties nil))
  (check-type v-properties list)
  (do-plist (property _value v-properties)
    (check-type property (satisfies wff-property-p)))
  (let ((result nil))
    (let ((*noting-at-violations?* t)
          (*accumulating-at-violations?* t)
          (*noting-wff-violations?* t)
          (*accumulating-wff-violations?* t)
          (*wff-violations* nil)
          (*check-wff-semantics?* t))
      (with-wff-properties v-properties
        (el-wff? sentence mt)
        (when (hlmt-p mt)
          (unless (wff-violations)
            (possibly-in-mt (mt)
              (simplify-cycl-sentence sentence))))
        (setf result (wff-violations))))
    result))

;; commented declareFunction, but body present in Java — ported for reference
(defun why-not-wff-assert (sentence &optional (mt *mt*) (v-properties nil))
  (check-type v-properties list)
  (do-plist (property _value v-properties)
    (check-type property (satisfies wff-property-p)))
  (let ((result nil))
    (let ((*within-assert* t))
      (with-wff-properties v-properties
        (setf result (why-not-wff sentence mt))))
    result))

;; (defun why-not-wft (term &optional mt properties) ...) -- commented declaration, no body

;; commented declareFunction, but body present in Java — ported for reference
(defun why-not-wff-ask (sentence &optional (mt *mt*) (v-properties nil))
  (check-type v-properties list)
  (do-plist (property _value v-properties)
    (check-type property (satisfies wff-property-p)))
  (let ((result nil))
    (let ((*noting-at-violations?* t)
          (*accumulating-at-violations?* t)
          (*noting-wff-violations?* t)
          (*accumulating-wff-violations?* t)
          (*wff-violations* nil))
      (with-wff-properties v-properties
        (wff-query? sentence mt)
        (setf result (wff-violations))))
    result))

;; (defun cb-why-not-wff (sentence &optional mt) ...) -- commented declaration, no body

(defun* reset-wff-violations () (:inline t)
  (setf *wff-violations* nil))

(defun* wff-violations () (:inline t)
  *wff-violations*)

(defun note-wff-violation? ()
  (and *noting-wff-violations?*
       (or (null (wff-violations))
           *accumulating-wff-violations?*)))

;; commented declareFunction, but body present in Java — ported for reference
(defun note-wff-violation (violation)
  "[Cyc] VIOLATION is a list, the first element of which is a keyword indicating
the type of violation, and the rest provide additional information about the violation."
  (when (wff-debug?)
    (print violation))
  (when (note-wff-violation?)
    (pushnew violation *wff-violations* :test #'equal))
  nil)

(defun note-wff-violations (violations)
  (dolist (violation violations)
    (note-wff-violation violation))
  nil)

;; (defun explain-why-not-wff (sentence &optional mt properties) ...) -- commented declaration, no body
;; (defun explain-why-not-wff-ask (sentence &optional mt properties) ...) -- commented declaration, no body
;; (defun explain-why-not-wff-assert (sentence &optional mt properties) ...) -- commented declaration, no body
;; (defun explain-why-not-wft (term &optional mt properties) ...) -- commented declaration, no body
;; (defun hl-explain-why-not-wff (sentence &optional mt properties) ...) -- commented declaration, no body
;; (defun hl-explain-why-not-wft (term &optional mt properties) ...) -- commented declaration, no body
;; (defun hl-explanation-of-why-not-wff (sentence &optional mt) ...) -- commented declaration, no body
;; (defun hl-explanation-of-why-not-wft (term &optional mt) ...) -- commented declaration, no body
;; (defun hl-why-not-wff (sentence &optional mt) ...) -- commented declaration, no body
;; (defun hl-why-not-wft (term &optional mt) ...) -- commented declaration, no body
;; (defun explanation-of-why-not-wff (sentence &optional mt properties) ...) -- commented declaration, no body
;; (defun explanation-of-why-not-wff-ask (sentence &optional mt properties) ...) -- commented declaration, no body

(defun explanation-of-why-not-wff-assert (sentence &optional (mt *mt*) (v-properties nil))
  "[Cyc] Gives an explanation of why SENTENCE is not wff to be asserted in MT."
  (check-type v-properties list)
  (do-plist (property _value v-properties)
    (check-type property (satisfies wff-property-p)))
  (let ((io-mode (getf v-properties :io-mode :nl))
        (violations (getf v-properties :violations nil)))
    (explanation-of-why-not-wff-int sentence mt io-mode violations :assert v-properties)))

;; commented declareFunction, but body present in Java — ported for reference
(defun explanation-of-why-not-wff-int (sentence mt io-mode violations wff-context v-properties)
  "[Cyc] WFF-CONTEXT: :ask, :assert, or :default."
  (let ((answer nil))
    (with-wff-properties v-properties
      (unless violations
        (case wff-context
          (:ask (setf violations (why-not-wff-ask sentence mt)))
          (:assert (setf violations (why-not-wff-assert sentence mt)))
          (otherwise (setf violations (why-not-wff sentence mt)))))
      (dolist (why-not violations)
        (push (explain-wff-violation why-not io-mode) answer))
      (when (and (wff-suggestions)
                 (provide-wff-suggestions?)
                 (eq io-mode :nl))
        (let ((suggestions (explanation-of-wff-suggestion sentence mt (wff-suggestions))))
          (when suggestions
            (push (format nil "~%~a" suggestions) answer))))
      (setf answer (nreverse answer))
      (when (eq :nl io-mode)
        (setf answer (strcat answer))))
    answer))

;; (defun explanation-of-why-not-wft (term &optional mt properties) ...) -- commented declaration, no body
;; (defun explain-wff-violations (&optional io-mode) ...) -- commented declaration, no body
;; (defun explain-wff-violation-with-cycl-sentence (violation sentence) ...) -- commented declaration, no body
;; (defun explain-wft-violation-with-cycl-sentence (violation term) ...) -- commented declaration, no body

;; commented declareFunction, but body present in Java — ported for reference
(defun explain-wff-violation (why-not &optional (io-mode :nl))
  (check-type why-not (satisfies wff-violation-p))
  (when why-not
    (let ((explanation-function (wff-violation-explanation-function (violation-type why-not))))
      (if explanation-function
          (funcall explanation-function why-not io-mode)
          (format nil "~%No explanation template exists for wff error~%~s." why-not)))))

;; (defun coherence-violations () ...) -- commented declaration, no body
;; (defun why-not-coherent (formula &optional mt) ...) -- commented declaration, no body
;; (defun reset-coherence-violations () ...) -- commented declaration, no body
;; (defun note-coherence-violation (violation) ...) -- commented declaration, no body

;; Setup phase

(register-cyc-api-function 'el-wff-syntax? '(sentence &optional mt)
  "Is SENTENCE well-formed wrt syntax?" nil '(booleanp))
(note-memoized-function 'memoized-syntactically-wf-formula?)
;; note-memoized-function for memoized-semantically-wf-literal? and
;; memoized-semantically-wf-sentence? are generated by their defun-memoized forms
;; note-globally-cached-function for mal-actual-arity-cached? is generated by its defun-cached form
(register-cyc-api-function 'el-formula-ok? '(formula &optional mt)
  "Is FORMULA a well-formed el formula?" '((formula listp)) '(booleanp))
(register-cyc-api-function 'el-query-ok? '(formula &optional mt)
  "Is FORMULA a well-formed el query?" '((formula listp)) '(booleanp))
(register-cyc-api-function 'diagnose-el-formula '(sentence &optional mt (io-mode :nl))
  "Identify how el sentence SENTENCE fails syntactic or semantic constraints"
  '((sentence listp)) nil)
