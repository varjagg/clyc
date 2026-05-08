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

;; Reconstructed from Internal Constants:
;; $list0 = ((PREFMOD &KEY DONE) &BODY BODY)
;; $sym4$DO_SET = DO-SET
;; $sym5$_GENERIC_PREFERENCE_MODULES_ = *GENERIC-PREFERENCE-MODULES*
;; Expands to iterating over the generic preference modules set with do-set.
(defmacro do-generic-preference-modules ((prefmod &key done) &body body)
  `(do-set (,prefmod *generic-preference-modules* ,done)
     ,@body))

;; Reconstructed from Internal Constants:
;; $list6 = ((PREFMOD PRED &KEY DONE) &BODY BODY)
;; $sym7$CSOME = CSOME
;; $sym8$SPECIFIC_PREFERENCE_MODULES_FOR_PRED = SPECIFIC-PREFERENCE-MODULES-FOR-PRED
;; Expands to iterating over specific preference modules for a predicate with csome.
(defmacro do-specific-preference-modules-for-pred ((prefmod pred &key done) &body body)
  `(csome (,prefmod (specific-preference-modules-for-pred ,pred) ,done)
     ,@body))

;; Reconstructed from Internal Constants:
;; $list9 = ((PREFMOD ASENT SENSE BINDABLE-VARS &KEY DONE) &BODY BODY)
;; $sym10$PRED = gensym PRED
;; $sym11$CLET = CLET (let)
;; $sym12$ATOMIC_SENTENCE_PREDICATE = ATOMIC-SENTENCE-PREDICATE
;; $sym13$DO_SPECIFIC_PREFERENCE_MODULES_FOR_PRED
;; $sym14$PWHEN = PWHEN (when)
;; $sym15$PREFERENCE_MODULE_RELEVANT_ = PREFERENCE-MODULE-RELEVANT?
;; $sym16$DO_GENERIC_PREFERENCE_MODULES
;; Iterates over both specific and generic preference modules relevant to the
;; given asent/sense/bindable-vars, executing body for each relevant one.
(defmacro do-relevant-preference-modules ((prefmod asent sense bindable-vars &key done) &body body)
  (with-temp-vars (pred)
    `(let ((,pred (atomic-sentence-predicate ,asent)))
       (do-specific-preference-modules-for-pred (,prefmod ,pred :done ,done)
         (when (preference-module-relevant? ,prefmod ,asent ,sense ,bindable-vars)
           ,@body))
       (do-generic-preference-modules (,prefmod :done ,done)
         (when (preference-module-relevant? ,prefmod ,asent ,sense ,bindable-vars)
           ,@body)))))

;; Reconstructed from Internal Constants:
;; $sym17$DO_DICTIONARY_VALUES = DO-DICTIONARY-VALUES
;; $sym18$_PREFERENCE_MODULES_BY_NAME_ = *PREFERENCE-MODULES-BY-NAME*
;; Iterates over all registered preference modules (from the by-name dictionary).
;; Since dictionaries are hash tables, uses maphash to iterate values.
(defmacro do-preference-modules ((prefmod &key done) &body body)
  (let ((key-var (gensym "KEY")))
    (if done
        `(block nil
           (maphash (lambda (,key-var ,prefmod)
                      (declare (ignore ,key-var))
                      (when ,done (return))
                      ,@body)
                    *preference-modules-by-name*))
        `(maphash (lambda (,key-var ,prefmod)
                    (declare (ignore ,key-var))
                    ,@body)
                  *preference-modules-by-name*))))

(defun problem-preference-level-wrt-modules (problem strategic-context shared-vars)
  (check-type problem (satisfies single-literal-problem-p))
  (let ((preference-level nil)
        (justification nil))
    (multiple-value-bind (mt asent sense)
        (mt-asent-sense-from-single-literal-problem problem)
      (with-inference-mt-relevance mt
        (multiple-value-setq (preference-level justification)
          (literal-preference-level-wrt-modules asent sense shared-vars strategic-context))))
    (values preference-level justification)))

(defun literal-preference-level-wrt-modules (asent sense bindable-vars strategic-context)
  (let ((min-preference-level :preferred)
        (justification "no preference modules applicable")
        (disallowed? nil))
    (when bindable-vars
      (let ((relevant-modules (all-relevant-preference-modules asent sense bindable-vars)))
        (dolist (prefmod relevant-modules)
          (when disallowed?
            (return))
          (let ((preference-level (preference-module-compute-preference-level prefmod asent bindable-vars strategic-context)))
            (when preference-level
              (when (preference-level-< preference-level min-preference-level)
                (setf min-preference-level preference-level)
                (setf justification (str (preference-module-name prefmod))))
              (when (eq :disallowed preference-level)
                (setf disallowed? t)))))))
    (values min-preference-level justification)))

(defun all-relevant-preference-modules (asent sense bindable-vars)
  (let ((candidate-modules nil)
        (pred (atomic-sentence-predicate asent)))
    ;; Collect from specific preference modules
    (dolist (prefmod (specific-preference-modules-for-pred pred))
      (when (preference-module-relevant? prefmod asent sense bindable-vars)
        (push prefmod candidate-modules)))
    ;; Collect from generic preference modules
    (do-set (prefmod *generic-preference-modules*)
      (when (preference-module-relevant? prefmod asent sense bindable-vars)
        (push prefmod candidate-modules)))
    ;; Filter out supplanted modules
    (let ((relevant-modules nil)
          (supplanted-module-names nil))
      (dolist (candidate-module candidate-modules)
        (unless (or (eq :all supplanted-module-names)
                    (member-eq? (preference-module-name candidate-module) supplanted-module-names))
          (when (preference-module-exclusive? candidate-module)
            (let ((supplants-spec
                    ;; Likely returns the supplants spec for the module, determining
                    ;; which other modules this exclusive module replaces.
                    (missing-larkc 32940)))
              (if (eq :all supplants-spec)
                  (progn
                    (setf supplanted-module-names :all)
                    (setf relevant-modules nil))
                  (dolist (supplanted-module-name supplants-spec)
                    (setf relevant-modules (delete supplanted-module-name relevant-modules
                                                   :test #'eq :key #'preference-module-name))
                    (pushnew supplanted-module-name supplanted-module-names)))))
          (push candidate-module relevant-modules)))
      relevant-modules)))

;; (defun el-literal-preference-level-wrt-modules (asent sense bindable-vars strategic-context) ...) -- active declareFunction, no body

;; These are sorted from least preferred to most preferred.
;; Disallowed:           no answers can be generated for the literal as-is, but answers might be generated if the literal were more fully bound.
;; Grossly Dispreferred: many answers will probably be missed if the literal is enumerated, but they might be testable if the literal were more fully bound.
;; Dispreferred:         some answers might be missed if the literal is enumerated, but they might be testable if the literal were more fully bound.
;; Preferred:            everything that's decidable is also enumerable, i.e. anything that could be proven if the literal were more fully bound is provable in the current state.
(deflexical *ordered-preference-levels* '(:disallowed :grossly-dispreferred :dispreferred :preferred))

;; (defun preference-level-string (preference-level) ...) -- active declareFunction, no body
;; (defun disallowed-preference-level-p (object) ...) -- active declareFunction, no body

(defun preference-level-p (object)
  (member-eq? object *ordered-preference-levels*))

(defun preference-level-< (preference-level1 preference-level2)
  "[Cyc] t iff PREFERENCE-LEVEL1 is _less_ preferred than PREFERENCE-LEVEL2."
  (check-type preference-level1 (satisfies preference-level-p))
  (check-type preference-level2 (satisfies preference-level-p))
  (position-< preference-level1 preference-level2 *ordered-preference-levels*))

(defun preference-level-> (preference-level1 preference-level2)
  "[Cyc] t iff PREFERENCE-LEVEL1 is _more_ preferred than PREFERENCE-LEVEL2."
  (preference-level-< preference-level2 preference-level1))

(defun preference-level-<= (preference-level1 preference-level2)
  (not (preference-level-> preference-level1 preference-level2)))

;; (defun preference-level->= (preference-level1 preference-level2) ...) -- active declareFunction, no body
;; (defun min-preference-level (preference-levels) ...) -- active declareFunction, no body
;; (defun min2-preference-level (preference-level1 preference-level2) ...) -- active declareFunction, no body
;; (defun max-preference-level (preference-levels) ...) -- active declareFunction, no body
;; (defun max2-preference-level (preference-level1 preference-level2) ...) -- active declareFunction, no body

(defun completeness-to-preference-level (completeness)
  "[Cyc] This function should go away soon."
  (case completeness
    (:complete :preferred)
    (:incomplete :dispreferred)
    (:grossly-incomplete :grossly-dispreferred)
    (:impossible :disallowed)
    (otherwise (error "unexpected completeness ~s" completeness))))

;; (defun preference-level-to-completeness (preference-level) ...) -- active declareFunction, no body

(deflexical *preference-module-properties*
  '(:predicate :sense :required-pattern :required-mt :any-predicates :supplants :preference-level :preference))

;; Reconstructed: body is missing-larkc, but used at load time by check-preference-module-properties.
;; Evidence: *preference-module-properties* is the deflexical list of valid property keywords.
(defun preference-module-property-p (property)
  (and (member property *preference-module-properties*) t))

(defun check-preference-module-properties (plist)
  "[Cyc] t or throw an error"
  (do ((remainder plist (cddr remainder)))
      ((null remainder))
    (let ((property (first remainder))
          (value (second remainder)))
      (must (preference-module-property-p property) "~s is not a valid preference module property" property)
      (case property
        (:predicate (must (fort-p value) "expected fort for :predicate, got ~s" value))
        (:sense (must (sense-p value) "expected sense for :sense, got ~s" value))
        (:required-pattern (check-type value cons))
        (:required-mt (must (hlmt-p value) "expected hlmt for :required-mt, got ~s" value))
        (:any-predicates (check-type value list))
        (:exclusive (must (function-spec-p value) "expected function-spec for :exclusive, got ~s" value))
        (:supplants
         (must (or (eq value :all)
                   (and (proper-list-p value)
                        (every-in-list #'symbolp value)))
               "invalid :supplants value ~s" value))
        (:preference-level (must (preference-level-p value) "expected preference-level for :preference-level, got ~s" value))
        (:preference (check-type value symbol))
        (otherwise (error "unexpected preference module property ~s" property)))))
  (must (getf plist :sense)
        "~s must specify :sense" plist)
  (must (not (eq (not (getf plist :preference-level))
                 (not (getf plist :preference))))
        "~s must specify exactly one of :preference-level or :preference" plist)
  t)

(defglobal *preference-modules-by-name* (make-hash-table :test #'eq)
  "[Cyc] A dictionary mapping names (keywords) to preference module objects.")

(defglobal *generic-preference-modules* (new-set #'eq)
  "[Cyc] The set of preference modules that are not specific to a single predicate")

(defglobal *specific-preference-modules* (make-hash-table :test #'eq)
  "[Cyc] Dictionary mapping a predicate to a list of preference modules that apply to that predicate")

(defglobal *preference-module-supplants* (make-hash-table :test #'eq)
  "[Cyc] Dictionary mapping a preference module to its supplants property")

(defun reclassify-preference-modules ()
  "[Cyc] called by reclassify-removal-modules"
  (rehash *specific-preference-modules*)
  nil)

;; (defun generic-preference-modules () ...) -- active declareFunction, no body
;; (defun generic-preference-module-count () ...) -- active declareFunction, no body
;; (defun specific-preference-module-count () ...) -- active declareFunction, no body
;; (defun preference-module-count () ...) -- active declareFunction, no body
;; (defun specific-preference-module-predicates () ...) -- active declareFunction, no body

(defun specific-preference-modules-for-pred (pred)
  (gethash pred *specific-preference-modules*))

;; (defun predicate-has-specific-preference-modules? (pred) ...) -- active declareFunction, no body

(defun note-preference-module-supplants (prefmod supplants)
  (if (null supplants)
      (remhash prefmod *preference-module-supplants*)
      (setf (gethash prefmod *preference-module-supplants*) supplants))
  prefmod)

(defun preference-module-exclusive? (prefmod)
  (sublisp-boolean (gethash prefmod *preference-module-supplants*)))

;; (defun preference-module-supplants (prefmod) ...) -- active declareFunction, no body

;; [Clyc] Reconstructed: inverse of register-preference-module. Needed for clean reload.
(defun deregister-preference-module (prefmod)
  (remhash (preference-module-name prefmod) *preference-modules-by-name*)
  (let ((predicate (preference-module-predicate prefmod)))
    (if predicate
        (dictionary-delete-first-from-value *specific-preference-modules* predicate prefmod)
        (set-remove prefmod *generic-preference-modules*)))
  (remhash prefmod *preference-module-supplants*)
  prefmod)

(defun register-preference-module (prefmod)
  (setf (gethash (preference-module-name prefmod) *preference-modules-by-name*) prefmod)
  (let ((predicate (preference-module-predicate prefmod)))
    (if predicate
        (dictionary-push *specific-preference-modules* predicate prefmod)
        (set-add prefmod *generic-preference-modules*)))
  prefmod)

;; Struct: preference-module
;; print-object is missing-larkc 32941 — CL's default print-object handles this.
(defstruct (preference-module
            (:conc-name "PREF-MOD-")
            (:constructor make-preference-module-int ()))
  name
  predicate
  sense
  required-pattern
  preference-level
  preference-func
  required-mt
  any-predicates)

;; (defun print-preference-module (object stream depth) ...) -- active declareFunction, no body

;; preference-module-p is auto-generated by defstruct

(defun make-preference-module (&optional arglist)
  (let ((v-new (make-preference-module-int)))
    (do ((next arglist (cddr next)))
        ((null next))
      (let ((current-arg (first next))
            (current-value (second next)))
        (case current-arg
          (:name (setf (pref-mod-name v-new) current-value))
          (:predicate (setf (pref-mod-predicate v-new) current-value))
          (:sense (setf (pref-mod-sense v-new) current-value))
          (:required-pattern (setf (pref-mod-required-pattern v-new) current-value))
          (:preference-level (setf (pref-mod-preference-level v-new) current-value))
          (:preference-func (setf (pref-mod-preference-func v-new) current-value))
          (:required-mt (setf (pref-mod-required-mt v-new) current-value))
          (:any-predicates (setf (pref-mod-any-predicates v-new) current-value))
          (otherwise (error "Invalid slot ~S for construction function" current-arg)))))
    v-new))

;; (defun print-preference-module (object stream depth) ...) -- active declareFunction, no body
;; (defun sxhash-preference-module-method (object) ...) -- active declareFunction, no body

(defun find-preference-module (name)
  "[Cyc] nil or preference-module-p"
  (declare (type keyword name))
  (gethash name *preference-modules-by-name*))

(defun inference-preference-module (name plist)
  (declare (type keyword name))
  (check-preference-module-properties plist)
  (let ((prefmod (find-preference-module name)))
    ;; [Clyc] missing-larkc 32934 replaced: original throws on re-registration, which
    ;; only worked because Cyc loaded once. On SLIME reload the module already exists.
    ;; Deregister and recreate to avoid duplicate accumulation in secondary structures.
    (when prefmod
      (deregister-preference-module prefmod))
    (setf prefmod (make-preference-module))
    (destructuring-bind (&key predicate sense any-predicates required-pattern
                         required-mt supplants preference-level preference
                         &allow-other-keys)
        plist
      (setf (pref-mod-name prefmod) name)
      (setf (pref-mod-predicate prefmod) predicate)
      (setf (pref-mod-any-predicates prefmod) any-predicates)
      (setf (pref-mod-sense prefmod) sense)
      (setf (pref-mod-required-pattern prefmod) required-pattern)
      (setf (pref-mod-required-mt prefmod) required-mt)
      (setf (pref-mod-preference-level prefmod) preference-level)
      (setf (pref-mod-preference-func prefmod) preference)
      (note-preference-module-supplants prefmod supplants))
    (register-preference-module prefmod)
    prefmod))

;; (defun undeclare-inference-preference-module (name) ...) -- active declareFunction, no body

(defun preference-module-name (prefmod)
  (declare (type preference-module prefmod))
  (pref-mod-name prefmod))

(defun preference-module-predicate (prefmod)
  (declare (type preference-module prefmod))
  (pref-mod-predicate prefmod))

(defun preference-module-any-predicates (prefmod)
  (declare (type preference-module prefmod))
  (pref-mod-any-predicates prefmod))

(defun preference-module-sense (prefmod)
  (declare (type preference-module prefmod))
  (pref-mod-sense prefmod))

(defun preference-module-required-pattern (prefmod)
  (declare (type preference-module prefmod))
  (pref-mod-required-pattern prefmod))

(defun preference-module-required-mt (prefmod)
  (declare (type preference-module prefmod))
  (pref-mod-required-mt prefmod))

(defun preference-module-preference-level (prefmod)
  (declare (type preference-module prefmod))
  (pref-mod-preference-level prefmod))

(defun preference-module-preference-func (prefmod)
  (declare (type preference-module prefmod))
  (pref-mod-preference-func prefmod))

(defun preference-module-relevant? (prefmod asent sense bindable-vars)
  (and (preference-module-predicate-match? prefmod (atomic-sentence-predicate asent))
       (preference-module-sense-match? prefmod sense)
       (preference-module-required-pattern-match? prefmod asent bindable-vars)
       (preference-module-required-mt-match? prefmod)
       t))

(defun preference-module-predicate-match? (prefmod pred)
  (let ((match-pred (preference-module-predicate prefmod)))
    (when match-pred
      (return-from preference-module-predicate-match? (eq match-pred pred))))
  (let ((match-any-preds (preference-module-any-predicates prefmod)))
    (when match-any-preds
      (return-from preference-module-predicate-match?
        (member? pred match-any-preds #'pattern-matches-formula))))
  t)

(defun preference-module-sense-match? (prefmod sense)
  (eq sense (preference-module-sense prefmod)))

(defun preference-module-required-pattern-match? (prefmod asent bindable-vars)
  (let ((pattern (preference-module-required-pattern prefmod)))
    (or (null pattern)
        (not (null (formula-matches-pattern asent pattern))))))

(defun preference-module-required-mt-match? (prefmod)
  (let ((match-mt (preference-module-required-mt prefmod)))
    (or (null match-mt)
        (not (null (relevant-mt? match-mt))))))

(defun preference-module-compute-preference-level (prefmod asent bindable-vars strategic-context)
  (let ((preference-level (preference-module-preference-level prefmod)))
    (if preference-level
        preference-level
        (let ((preference-func (preference-module-preference-func prefmod)))
          (preference-module-compute-preference-level-funcall preference-func asent bindable-vars strategic-context)))))

(defun preference-module-compute-preference-level-funcall (preference-func asent bindable-vars strategic-context)
  (case preference-func
    (tva-pos-preference (tva-pos-preference asent bindable-vars strategic-context))
    (otherwise (funcall preference-func asent bindable-vars strategic-context))))

;; Setup phase
(toplevel (declare-defglobal '*preference-modules-by-name*))
(toplevel (declare-defglobal '*generic-preference-modules*))
(toplevel (declare-defglobal '*specific-preference-modules*))
(toplevel (declare-defglobal '*preference-module-supplants*))
