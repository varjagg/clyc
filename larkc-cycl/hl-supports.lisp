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

(deflexical *hl-predicates*
  (list #$isa #$quotedIsa #$genls #$termOfUnit #$equals #$equalSymbols
        #$different #$differentSymbols #$evaluate #$elementOf #$subsetOf
        #$disjointWith #$genlMt #$genlPreds #$genlInverse #$negationPreds
        #$negationInverse #$conceptuallyRelated))

(defun hl-predicate-p (object)
  (member-eq? object *hl-predicates*))

(defun non-hl-predicate-p (object)
  (and (fort-p object)
       (not (hl-predicate-p object))))

;; (defun declare-hl-predicate (predicate) ...) -- present in original Cyc, not in LarKC
;; (defun undeclare-hl-predicate (predicate) ...) -- present in original Cyc, not in LarKC

(defglobal *hl-support-modules* nil)

;; TODO - useless, only used like twice in the codebase. Once everything is ported, remove and change all callers to read the variable directly
(defun* hl-support-modules () (:inline t)
  *hl-support-modules*)

(defparameter *hl-support-module-plist-indicators*
  '(:verify :justify :validate :forward-mt-combos))

(defun hl-support-module-p (object)
  "[Cyc] Return T iff OBJECT is an HL support module."
  (member-eq? object *hl-support-modules*))

(defun setup-hl-support-module (name plist)
  "[Cyc] Declare NAME as a new HL support module"
  (declare (type keyword name))
  ;; Clear any existing properties for this module
  (dolist (indicator *hl-support-module-plist-indicators*)
    (remprop name indicator))
  ;; Set new properties from plist
  (loop for (indicator value) on plist by #'cddr
        do (must (member indicator *hl-support-module-plist-indicators*)
                 "~S was not a valid hl-support-module indicator" indicator)
           (setf (get name indicator) value))
  ;; Register the module if not already registered
  (pushnew name *hl-support-modules* :test #'eql)
  name)

;; (defun hl-support-module-verify-func (hl-support-module) ...) -- present in original Cyc, not in LarKC

(defun hl-support-module-justify-func (hl-support-module)
  (get hl-support-module :justify nil))

;; (defun hl-support-module-validate-func (hl-support-module) ...) -- present in original Cyc, not in LarKC

(defun hl-support-module-forward-mt-combos-func (hl-support-module)
  (get hl-support-module :forward-mt-combos 'list))

;; (defun hl-verify (support) ...) -- present in original Cyc, not in LarKC

(defun hl-justify (support)
  "[Cyc] Return a list of supports."
  (declare (type (satisfies support-p) support))
  (support-justification support))

;; (defun hl-justify-expanded (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justification-expand (justification) ...) -- present in original Cyc, not in LarKC

(defun hl-support-justify (hl-support)
  (declare (type (satisfies hl-support-p) hl-support))
  (let ((module (hl-support-module hl-support))
        (justification nil))
    (when (hl-support-module-p module)
      (let ((justify-func (hl-support-module-justify-func module)))
        (when justify-func
          (let ((mt (hl-support-mt hl-support)))
            (with-inference-mt-relevance (mt)
              (setf justification (funcall justify-func hl-support))))))
      (unless (non-empty-hl-justification-p justification)
        (setf justification (hl-trivial-justification hl-support))))
    justification))

(defun hl-trivial-justification (support)
  (list support))

;; (defun hl-validate (support mt) ...) -- present in original Cyc, not in LarKC
;; (defun hl-validate-wff-violations (support mt) ...) -- present in original Cyc, not in LarKC

(defun hl-forward-mt-combos (support)
  (let ((hl-module (support-module support)))
    (declare (type (satisfies hl-support-module-p) hl-module))
    (let ((forward-mt-combos-func (hl-support-module-forward-mt-combos-func hl-module))
          (mt (support-mt support)))
      (if (and forward-mt-combos-func
               (eq mt #$InferencePSC))
          (funcall forward-mt-combos-func support)
          (list support)))))

(defun find-assertion-or-make-support (sentence &optional mt)
  "[Cyc] Return an assertion corresponding to SENTENCE iff one exists (within MT relevance), or a :code support with SENTENCE as support sentence."
  (possibly-in-mt (mt)
    (let ((assertion (find-assertion-cycl sentence)))
      (if assertion
          assertion
          (make-hl-support :code sentence mt)))))

;; (defun max-floor-mts-of-justification (justification) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-opaque (support) ...) -- present in original Cyc, not in LarKC

;; commented declareFunction, but body present in Java — ported for reference
(defun opaque-hl-support-p (support)
  (and (not (assertion-p support))
       (eq :opaque (support-module support))))

;; (defun hl-verify-bookkeeping (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-bookkeeping (support) ...) -- present in original Cyc, not in LarKC

(defparameter *perform-opaque-support-verification* nil)

(defglobal *bookkeeping-justification-assertion-mt* #$BaseKB
  ;; [Cyc] The mt in which assertions for HL justifications of bookkeeping assertions are expected to be.
  )

(deflexical *cached-find-assertion-cycl-caching-state* nil)

;; (defun clear-cached-find-assertion-cycl () ...) -- present in original Cyc, not in LarKC
;; (defun remove-cached-find-assertion-cycl (sentence) ...) -- present in original Cyc, not in LarKC
;; (defun cached-find-assertion-cycl-internal (sentence) ...) -- present in original Cyc, not in LarKC
;; (defun cached-find-assertion-cycl (sentence) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-bookkeeping (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-defn (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-defn (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-defn (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-elementof (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-elementof (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-subsetof (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-subsetof (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-sibling-disjoint (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-sibling-disjoint (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-sibling-disjoint (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-equality (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-equality (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-validate-equality (support mt) ...) -- present in original Cyc, not in LarKC
;; (defun hl-validate-default (support mt) ...) -- present in original Cyc, not in LarKC
;; (defun hl-validate-literal-minimal (support mt) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-equality (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-eval (support) ...) -- present in original Cyc, not in LarKC

(defun hl-justify-eval (support)
  (destructuring-bind (hl-module literal mt tv) support
    (declare (ignore hl-module))
    (let* ((justification nil)
           (predicate (literal-predicate literal)))
      (cond
        ((eq predicate #$evaluate)
         (let ((result (literal-arg1 literal))
               (expression (literal-arg2 literal)))
           (if (not (negated? literal))
               (with-inference-mt-relevance (mt)
                 (setf justification (missing-larkc 30327)))
               (with-inference-mt-relevance (mt)
                 (multiple-value-bind (answer valid?)
                     (cyc-evaluate expression)
                   (when (and valid?
                              (not (term-unify answer result)))
                     (let ((evaluate-support (missing-larkc 1324))
                           (different-support (missing-larkc 32841)))
                       (setf justification (list evaluate-support different-support)))))))))
        ((eq predicate #$different)
         (let ((args (literal-args literal)))
           (setf justification (why-different args))))
        (t
         (let ((atomic-sentence (literal-atomic-sentence literal)))
           (if (not (negated? literal))
               (with-inference-mt-relevance (mt)
                 (setf justification (missing-larkc 30328)))
               (with-inference-mt-relevance (mt)
                 (multiple-value-bind (answer valid?)
                     (cyc-evaluate atomic-sentence)
                   (when (and valid? (null answer))
                     (let ((unknown-support (missing-larkc 1298)))
                       (setf justification (list unknown-support))))))))))
      justification)))

;; (defun hl-verify-reflexive (support) ...) -- present in original Cyc, not in LarKC

(defun hl-justify-reflexive (support)
  (destructuring-bind (hl-module literal mt tv) support
    (declare (ignore hl-module tv))
    (let ((negated? (negated? literal))
          (atomic-sentence (literal-atomic-sentence literal)))
      (destructuring-bind (pred arg1 arg2) atomic-sentence
        (let* ((reflexive-col (if negated?
                                  #$IrreflexiveBinaryPredicate
                                  #$ReflexiveBinaryPredicate))
               (isa-sentence (make-binary-formula #$isa pred reflexive-col))
               (arg1-sentence (make-ternary-formula #$admittedArgument arg1 1 pred))
               (arg2-sentence (make-ternary-formula #$admittedArgument arg2 2 pred))
               (equals-sentence (unless (equal arg1 arg2)
                                  (make-binary-formula #$equals arg1 arg2)))
               (isa-support (make-hl-support :isa isa-sentence mt))
               (arg1-support (make-hl-support :admit arg1-sentence mt))
               (arg2-support (make-hl-support :admit arg2-sentence mt))
               (equals-support (when equals-sentence
                                 (make-hl-support :equality equals-sentence mt))))
          (list* isa-support arg1-support arg2-support
                 (when equals-support (list equals-support))))))))

;; (defun hl-forward-mt-combos-reflexive (support) ...) -- present in original Cyc, not in LarKC
;; (defun inference-semantically-valid-irreflexive-literal? (literal &optional mt) ...) -- present in original Cyc, not in LarKC
;; (defun max-floor-mts-where-reflexive (pred &optional mt) ...) -- present in original Cyc, not in LarKC
;; (defun max-floor-mts-where-arg-constraints-met-internal (arg argnum &optional pred) ...) -- present in original Cyc, not in LarKC
;; (defun max-floor-mts-where-arg-constraints-met (arg argnum &optional pred) ...) -- present in original Cyc, not in LarKC
;; (defun hl-validate-reflexive (support mt) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-reflexive-on (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-reflexive-on (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-reflexive-on (support) ...) -- present in original Cyc, not in LarKC
;; (defun max-floor-mts-where-reflexive-on (pred) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-transitivity (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-transitivity (support) ...) -- present in original Cyc, not in LarKC

(defun hl-justify-transitivity (support)
  (destructuring-bind (hl-module literal mt tv) support
    (declare (ignore hl-module))
    (if (negated? literal)
        nil
        (destructuring-bind (predicate arg1 arg2) (literal-atomic-sentence literal)
          (inference-transitivity-justify predicate arg1 arg2 mt tv)))))

;; (defun hl-verify-contextual-transitivity (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-contextual-transitivity (support) ...) -- present in original Cyc, not in LarKC
;; (defun max-floor-mts-of-transitivity-paths (predicate arg1 arg2 &optional mt) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-tva (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-tva (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-tva (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-rtv (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-rtv (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-rtv (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-minimize (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-consistent (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-consistent (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-conceptually-related (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-conceptually-related (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-conceptually-related (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-admit (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-admit (support) ...) -- present in original Cyc, not in LarKC

(defun hl-justify-admit (support)
  (declare (ignore support))
  nil)

;; (defun hl-verify-admitted-argument (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-admitted-sentence (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-admitted-nat (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-admitted-argument (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-admitted-sentence (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-admitted-nat (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-reformulate (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-assertion (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-assertion (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-assertion (support) ...) -- present in original Cyc, not in LarKC

;; (declareMacro "possibly-with-negated-truth") -- macro, present in original Cyc, not in LarKC

(defun hl-justify-sbhl (support)
  (destructuring-bind (hl-module literal mt tv) support
    (declare (ignore hl-module))
    (cond
      ((el-negation-p literal)
       (let ((new-literal (formula-arg1 literal :regularize))
             (new-tv (missing-larkc 32094))) ;; likely inverse-tv — negation stripped from literal, so tv must be inverted
         (destructuring-bind (predicate arg1 arg2) new-literal
           (with-inference-mt-relevance (mt)
             (why-sbhl-relation? (get-sbhl-module predicate) arg1 arg2
                                 nil (support-tv-to-sbhl-tv new-tv) :assertion)))))
      ((el-formula-p literal)
       (destructuring-bind (predicate arg1 arg2) literal
         (with-inference-mt-relevance (mt)
           (why-sbhl-relation? (get-sbhl-module predicate) arg1 arg2
                               nil (support-tv-to-sbhl-tv tv) :assertion)))))))

;; (defun hl-verify-isa (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-isa (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-isa (support) ...) -- present in original Cyc, not in LarKC
;; (defun justify-not-type-by-extent-known (term collection mt) ...) -- present in original Cyc, not in LarKC
;; (defun inference-max-floor-mts-of-isa-paths (spec genl) ...) -- present in original Cyc, not in LarKC
;; (defun inference-max-floor-mts-of-quoted-isa-paths (spec genl) ...) -- present in original Cyc, not in LarKC
;; (defun gaf-axioms (sentence mt) ...) -- present in original Cyc, not in LarKC
;; (defun gaf-axioms-genl-mts (sentence mt) ...) -- present in original Cyc, not in LarKC
;; (defun symmetric-hl-pred? (pred) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-genls (support) ...) -- present in original Cyc, not in LarKC

(defun hl-justify-genls (support)
  (destructuring-bind (hl-module literal mt tv) support
    (declare (ignore hl-module tv))
    (let ((predicate (literal-predicate literal)))
      (cond
        ((eq predicate #$nearestGenls)
         (missing-larkc 1314))
        ((eq predicate #$nearestGenlsOfType)
         (missing-larkc 1315))
        (t (hl-justify-sbhl support))))))

(defun hl-forward-mt-combos-genls (support)
  (destructuring-bind (hl-module literal mt tv) support
    (let ((mts nil)
          (ans nil))
      (if (not (negated? literal))
          (setf mts (inference-max-floor-mts-of-genls-paths
                     (literal-arg1 literal) (literal-arg2 literal)))
          (setf mts (list mt)))
      (dolist (combo-mt mts)
        (push (make-hl-support hl-module literal combo-mt tv) ans))
      (nreverse ans))))

(defun inference-max-floor-mts-of-genls-paths (spec genl)
  (if (first-order-naut? spec)
      (missing-larkc 5038)
      (let* ((min-mt-sets (sbhl-min-mts-of-predicate-paths (get-sbhl-module #$genls) spec genl))
             (reduced-min-mt-sets (minimize-mt-sets-wrt-core min-mt-sets))
             (max-floor-mts (sbhl-max-floor-mts-of-paths reduced-min-mt-sets))
             (reduced-max-floor-mts (maximize-mts-wrt-core max-floor-mts)))
        reduced-max-floor-mts)))

;; (defun hl-verify-disjointwith (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-disjointwith (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-disjointwith (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-genlmt (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-genlmt (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-genlmt (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-genlpreds (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-genlpreds (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-genlpreds (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-negationpreds (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-negationpreds (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-negationpreds (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-time-sentence (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-true-mts-for-time-sentence (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-validate-time (support mt) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-time-sentence (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-asserted-arg1-binary-preds (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-asserted-arg1-binary-preds (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-shop-effect (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-shop-effect (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-query (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-query (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-query-int (support sentence mt) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-of-query (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-matrix-of-reaction-type (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-matrix-of-reaction-type (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-forward-mt-combos-matrix-of-reaction-type (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-verify-parse-tree-relation (support) ...) -- present in original Cyc, not in LarKC
;; (defun hl-justify-parse-tree-relation (support) ...) -- present in original Cyc, not in LarKC

;;; Setup phase

(declare-defglobal '*hl-support-modules*)
(register-cyc-api-function 'hl-support-module-p '(object)
  "Return T iff OBJECT is an HL support module." nil '(booleanp))

(setup-hl-support-module :code '(:verify t))
(setup-hl-support-module :opaque '(:verify hl-verify-opaque))
(setup-hl-support-module :abduction '(:verify t))

(declare-defglobal '*bookkeeping-justification-assertion-mt*)
(note-mt-var '*bookkeeping-justification-assertion-mt* nil)
(note-globally-cached-function 'cached-find-assertion-cycl)

(setup-hl-support-module :bookkeeping
  '(:verify hl-verify-bookkeeping
    :justify hl-justify-bookkeeping
    :forward-mt-combos hl-forward-mt-combos-bookkeeping))
(setup-hl-support-module :defn
  '(:verify hl-verify-defn
    :justify hl-justify-defn
    :forward-mt-combos hl-forward-mt-combos-defn))
(setup-hl-support-module :elementof
  '(:verify hl-verify-elementof
    :forward-mt-combos hl-forward-mt-combos-elementof))
(setup-hl-support-module :subsetof
  '(:verify hl-verify-subsetof
    :forward-mt-combos hl-forward-mt-combos-subsetof))
(setup-hl-support-module :sibling-disjoint
  '(:verify hl-verify-sibling-disjoint
    :forward-mt-combos hl-forward-mt-combos-sibling-disjoint
    :justify hl-justify-sibling-disjoint))
(setup-hl-support-module :equality
  '(:verify hl-verify-equality
    :forward-mt-combos hl-forward-mt-combos-equality
    :validate hl-validate-equality
    :justify hl-justify-equality))
(setup-hl-support-module :eval
  '(:verify hl-verify-eval
    :justify hl-justify-eval))
(note-memoized-function 'max-floor-mts-where-arg-constraints-met)
(setup-hl-support-module :reflexive
  '(:verify hl-verify-reflexive
    :justify hl-justify-reflexive
    :validate hl-validate-reflexive
    :forward-mt-combos hl-forward-mt-combos-reflexive))
(setup-hl-support-module :reflexive-on
  '(:verify hl-verify-reflexive-on
    :justify hl-justify-reflexive-on
    :forward-mt-combos hl-forward-mt-combos-reflexive-on))
(setup-hl-support-module :transitivity
  '(:verify hl-verify-transitivity
    :forward-mt-combos hl-forward-mt-combos-transitivity
    :justify hl-justify-transitivity))
(setup-hl-support-module :contextual-transitivity
  '(:verify hl-verify-contextual-transitivity
    :forward-mt-combos hl-forward-mt-combos-transitivity
    :justify hl-justify-contextual-transitivity))
(setup-hl-support-module :tva
  '(:verify hl-verify-tva
    :justify hl-justify-tva
    :forward-mt-combos hl-forward-mt-combos-tva))
(setup-hl-support-module :rtv
  '(:verify hl-verify-rtv
    :justify hl-justify-rtv
    :forward-mt-combos hl-forward-mt-combos-rtv))
(setup-hl-support-module :minimize '(:verify hl-verify-minimize))
(setup-hl-support-module :consistent
  '(:verify hl-verify-consistent
    :justify hl-justify-consistent))
(setup-hl-support-module :conceptually-related
  '(:verify hl-verify-conceptually-related
    :forward-mt-combos hl-forward-mt-combos-conceptually-related
    :justify hl-justify-conceptually-related))
(setup-hl-support-module :admit
  '(:verify hl-verify-admit
    :forward-mt-combos hl-forward-mt-combos-admit
    :justify hl-justify-admit))
(setup-hl-support-module :reformulate '(:justify hl-justify-reformulate))
(setup-hl-support-module *assertion-support-module*
  '(:verify hl-verify-assertion
    :justify hl-justify-assertion
    :forward-mt-combos hl-forward-mt-combos-assertion))
(setup-hl-support-module :external nil)
(setup-hl-support-module :external-eval nil)
(setup-hl-support-module :isa
  '(:verify hl-verify-isa
    :justify hl-justify-isa
    :forward-mt-combos hl-forward-mt-combos-isa))
(setup-hl-support-module :genls
  '(:verify hl-verify-genls
    :justify hl-justify-genls
    :forward-mt-combos hl-forward-mt-combos-genls))
(setup-hl-support-module :disjointwith
  '(:verify hl-verify-disjointwith
    :forward-mt-combos hl-forward-mt-combos-disjointwith
    :justify hl-justify-disjointwith))
(setup-hl-support-module :genlmt
  '(:verify hl-verify-genlmt
    :justify hl-justify-genlmt
    :forward-mt-combos hl-forward-mt-combos-genlmt))
(setup-hl-support-module :genlpreds
  '(:verify hl-verify-genlpreds
    :forward-mt-combos hl-forward-mt-combos-genlpreds
    :justify hl-justify-genlpreds))
(setup-hl-support-module :negationpreds
  '(:verify hl-verify-negationpreds
    :forward-mt-combos hl-forward-mt-combos-negationpreds
    :justify hl-justify-negationpreds))
(setup-hl-support-module :time
  '(:verify hl-verify-time-sentence
    :forward-mt-combos hl-true-mts-for-time-sentence
    :validate hl-validate-time
    :justify hl-justify-time-sentence))
(setup-hl-support-module :asserted-arg1-binary-preds
  '(:verify hl-verify-asserted-arg1-binary-preds
    :justify hl-justify-asserted-arg1-binary-preds
    :forward-mt-combos nil))
(setup-hl-support-module :fcp
  '(:verify removal-fcp-verify
    :justify removal-fcp-justify
    :forward-mt-combos nil))
(setup-hl-support-module :shop-effect
  '(:verify hl-verify-shop-effect
    :justify hl-justify-shop-effect
    :forward-mt-combos nil))
(note-funcall-helper-function 'hl-verify-parse-tree-relation)
(note-funcall-helper-function 'hl-justify-parse-tree-relation)
(setup-hl-support-module :parse-tree
  '(:verify hl-verify-parse-tree-relation
    :justify hl-justify-parse-tree-relation))
(setup-hl-support-module :word-strings
  '(:verify hl-verify-word-strings
    :justify hl-justify-word-strings
    :forward-mt-combos hl-forward-mt-combos-word-strings))
(setup-hl-support-module :term-phrases
  '(:verify hl-verify-term-phrases
    :justify hl-justify-term-phrases
    :forward-mt-combos hl-forward-mt-combos-term-phrases))
(setup-hl-support-module :rkf-irrelevant-fort-cache
  '(:verify hl-verify-rkf-irrelevant-fort-cache
    :justify hl-justify-rkf-irrelevant-fort-cache
    :forward-mt-combos hl-forward-mt-combos-rkf-irrelevant-fort-cache))
(setup-hl-support-module :query
  '(:verify hl-verify-query :justify hl-justify-query
    :forward-mt-combos hl-forward-mt-combos-of-query))
(setup-hl-support-module :matrix-of-reaction-type
  '(:verify hl-verify-matrix-of-reaction-type
    :justify hl-justify-matrix-of-reaction-type
    :forward-mt-combos hl-forward-mt-combos-matrix-of-reaction-type))
