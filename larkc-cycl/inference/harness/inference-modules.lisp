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

;;; Variables

(defglobal *meta-removal-modules* nil
  "[Cyc] Set of all meta-removal modules, which are modules which execute
other removal tactics on the problem.")

(deflexical *hl-module-properties*
  '(:module-type :module-subtype :module-source :check :external :universal
    :sense :direction :predicate :every-predicates :any-predicates
    :required-pattern :required-mt :arity :exclusive :supplants :required
    :applicability-pattern :applicability :cost-pattern :cost-expression :cost
    :completeness :complete-pattern :completeness-pattern
    :input-extract-pattern :input-verify-pattern :input-encode-pattern
    :output-check-pattern :output-generate-pattern :output-decode-pattern
    :output-verify-pattern :output-construct-pattern
    :rule-select :rule-filter :expand-iterative-pattern :expand-pattern :expand
    :rewrite-closure :support-pattern :support :support-module :support-mt
    :support-strength :rewrite-support :argument-type :incompleteness
    :add :remove :remove-all :preferred-over :documentation :example :pretty-name))

(deflexical *valid-hl-module-subtypes* '(:sksi :kb :abduction))

(deflexical *default-hl-module-subtype* :kb)

(deflexical *hl-module-property-defaults*
  (let ((ht (make-hash-table :test #'eq :size 50)))
    (dolist (pair '((:module-type . nil)
                    (:module-subtype . :kb)
                    (:module-source . nil)
                    (:universal . nil)
                    (:sense . nil)
                    (:required-pattern . :anything)
                    (:required-mt . nil)
                    (:required . nil)
                    (:cost-pattern . nil)
                    (:cost-expression . nil)
                    (:cost . default-cost-func)
                    (:completeness . nil)
                    (:complete-pattern . nil)
                    (:completeness-pattern . nil)
                    (:check . :unknown)
                    (:rule-select . nil)
                    (:expand . :default)
                    (:expand-pattern . nil)
                    (:expand-iterative-pattern . nil)
                    (:predicate . nil)
                    (:arity . nil)
                    (:exclusive . nil)
                    (:supplants . :all)
                    (:direction . :forward)
                    (:input-extract-pattern . :input)
                    (:input-verify-pattern . :anything)
                    (:input-encode-pattern . :input)
                    (:output-check-pattern . nil)
                    (:output-generate-pattern . nil)
                    (:output-decode-pattern . :input)
                    (:output-verify-pattern . :anything)
                    (:output-construct-pattern . :input)
                    (:support-pattern . nil)
                    (:support . nil)
                    (:support-module . :opaque)
                    (:support-mt . nil)
                    (:support-strength . :default)
                    (:every-predicates . nil)
                    (:applicability . nil)
                    (:applicability-pattern . nil)
                    (:any-predicates . nil)
                    (:documentation . "")
                    (:example . "")
                    (:external . nil)
                    (:rewrite-support . nil)
                    (:rewrite-closure . nil)))
      (setf (gethash (car pair) ht) (cdr pair)))
    ht))

;;; HL-MODULE struct
;;; print-object is missing-larkc 36422 — CL's default print-object handles this.

(defstruct (hl-module (:conc-name hl-mod-))
  name
  plist
  sense
  predicate
  any-predicates
  arity
  direction
  required-pattern
  required-mt
  exclusive-func
  required-func
  completeness)

;;; Declare-section ordered functions

(defun hl-module-property-p (object)
  "[Cyc] Return T iff OBJECT is a valid HL module property."
  (member object *hl-module-properties* :test #'eq))

;; Reconstructed from Internal Constants: $list2 arglist, $sym3 makeUninternedSymbol("MODULE-VAR"),
;; $sym4 CLET, $sym5 DO-LIST, $list6 (HL-MODULE-PROPERTIES), $sym7 PWHEN,
;; $sym8 HL-MODULE-PROPERTY-NOT-DEFAULT?, $sym9 HL-MODULE-PROPERTY-WITHOUT-VALUES
(defmacro do-hl-module-properties ((property-var value-var hl-module) &body body)
  (with-temp-vars (module-var)
    `(let ((,module-var ,hl-module))
       (dolist (,property-var (hl-module-properties))
         (when (hl-module-property-not-default? ,module-var ,property-var)
           (let ((,value-var (hl-module-property-without-values ,module-var ,property-var)))
             ,@body))))))

(defun* hl-module-properties () (:inline t)
  "[Cyc] Return the list of all valid HL module properties."
  *hl-module-properties*)

;; (defun removal-module-plist-indicators () ...) -- active declareFunction, no body

(defun hl-module-subtype-p (object)
  "[Cyc] Return T iff OBJECT is a valid HL module subtype."
  (member object *valid-hl-module-subtypes* :test #'eq))

;; (defun allowed-modules-spec-p (object) ...) -- active declareFunction, no body
;; (defun non-universal-allowed-modules-spec-p (object) ...) -- active declareFunction, no body

(defun disjunctive-allowed-modules-spec-p (object)
  (and (consp object)
       (eq :or (first object))
       (list-of-type-p #'allowed-modules-spec-p (rest object))))

(defun conjunctive-allowed-modules-spec-p (object)
  (and (consp object)
       (eq :and (first object))
       (list-of-type-p #'allowed-modules-spec-p (rest object))))

(defun negated-allowed-modules-spec-p (object)
  (and (consp object)
       (eq :not (first object))
       (list-of-type-p #'allowed-modules-spec-p (rest object))))

(defun hl-module-type-spec-p (object)
  (and (doubleton? object)
       (eq :module-type (first object))))

(defun hl-module-subtype-spec-p (object)
  (and (doubleton? object)
       (eq :module-subtype (first object))))

(defun property-allowed-modules-spec-p (object)
  (and (doubleton? object)
       (missing-larkc 36416)))

;; (defun hl-module-allowed? (hl-module allowed-modules-spec) ...) -- active declareFunction, no body

(defun hl-module-allowed-by-allowed-modules-spec? (hl-module allowed-modules-spec)
  (cond
    ((eq :all allowed-modules-spec) t)
    ((disjunctive-allowed-modules-spec-p allowed-modules-spec)
     (dolist (subspec (rest allowed-modules-spec))
       (when (hl-module-allowed-by-allowed-modules-spec? hl-module subspec)
         (return t))))
    ((conjunctive-allowed-modules-spec-p allowed-modules-spec)
     (dolist (subspec (rest allowed-modules-spec) t)
       (unless (hl-module-allowed-by-allowed-modules-spec? hl-module subspec)
         (return nil))))
    ((negated-allowed-modules-spec-p allowed-modules-spec)
     (not (hl-module-allowed-by-allowed-modules-spec? hl-module (second allowed-modules-spec))))
    ((hl-module-type-spec-p allowed-modules-spec)
     (eq (second allowed-modules-spec) (hl-module-type hl-module)))
    ((hl-module-subtype-spec-p allowed-modules-spec)
     (member-eq? (second allowed-modules-spec)
                 (missing-larkc 36417)))
    ((property-allowed-modules-spec-p allowed-modules-spec)
     (let* ((property (first allowed-modules-spec))
            (allowed-value (second allowed-modules-spec))
            (actual-value (hl-module-property-without-values hl-module property)))
       (equal allowed-value actual-value)))
    (t
     (eq hl-module (find-hl-module-by-name allowed-modules-spec)))))

(defun simple-allowed-modules-spec-p (allowed-modules-spec)
  (cond
    ((find-hl-module-by-name allowed-modules-spec) t)
    ((disjunctive-allowed-modules-spec-p allowed-modules-spec)
     (dolist (subspec (rest allowed-modules-spec) t)
       (unless (simple-allowed-modules-spec-p subspec)
         (return nil))))
    ((conjunctive-allowed-modules-spec-p allowed-modules-spec)
     (dolist (subspec (rest allowed-modules-spec) t)
       (unless (simple-allowed-modules-spec-p subspec)
         (return nil))))
    ((or (eq :all allowed-modules-spec)
         (negated-allowed-modules-spec-p allowed-modules-spec)
         (hl-module-type-spec-p allowed-modules-spec)
         (hl-module-subtype-spec-p allowed-modules-spec)
         (property-allowed-modules-spec-p allowed-modules-spec))
     nil)
    (t nil)))

(defun get-modules-from-simple-allowed-modules-spec (allowed-modules-spec)
  (cond
    ((disjunctive-allowed-modules-spec-p allowed-modules-spec)
     (let ((module-specs nil))
       (dolist (subspec (rest allowed-modules-spec))
         (setf module-specs (append module-specs
                                    (get-modules-from-simple-allowed-modules-spec subspec))))
       module-specs))
    ((conjunctive-allowed-modules-spec-p allowed-modules-spec)
     (let ((module-specs nil))
       (dolist (subspec (rest allowed-modules-spec))
         (setf module-specs (append module-specs
                                    (get-modules-from-simple-allowed-modules-spec subspec))))
       module-specs))
    (t
     (list (find-hl-module-by-name allowed-modules-spec)))))

;; struct accessor/setter/constructor/predicate functions are generated by defstruct

;; (defun print-hl-module (object stream depth) ...) -- active declareFunction, no body

(defun sxhash-hl-module-method (object)
  (sxhash (hl-mod-name object)))

(defun check-hl-module-property-list (plist)
  (check-type plist list)
  (let ((exclusive-specified? nil))
    (do ((remainder plist (cddr remainder)))
        ((null remainder))
      (let ((property (first remainder)))
        (assert (hl-module-property-p property) ()
                "~S is not a valid HL module property" property)
        (when (eq property :exclusive)
          (setf exclusive-specified? t))))
    (do ((remainder plist (cddr remainder)))
        ((null remainder))
      (let ((property (first remainder)))
        (when (eq property :supplants)
          (unless exclusive-specified?
            (error ":supplants is meaningless without :exclusive in ~S" plist))))))
  nil)

(defun new-hl-module (name plist)
  "[Cyc] @return hl-module-p; a new HL module named NAME with properties PLIST"
  (check-hl-module-property-list plist)
  (let ((hl-module (allocate-hl-module name)))
    (setf plist (canonicalize-hl-module-plist plist))
    (setf (hl-mod-plist hl-module) plist)
    (add-hl-module hl-module)
    hl-module))

(defun canonicalize-hl-module-plist (plist)
  "[Cyc] Right now the only thing this changes is a single module-subtype canonicalizes
into a singleton list."
  (let ((module-subtypes (getf plist :module-subtype)))
    (unless (listp module-subtypes)
      (setf plist (copy-list plist))
      (setf (getf plist :module-subtype) (list module-subtypes))))
  plist)

(defun allocate-hl-module (name)
  (let ((hl-module (find-hl-module-by-name name)))
    (if hl-module
        (remove-hl-module hl-module)
        (progn
          (setf hl-module (make-hl-module))
          (setf (hl-mod-name hl-module) name)))
    (setf (hl-mod-plist hl-module) nil)
    hl-module))

;; (defun destroy-hl-module (hl-module) ...) -- active declareFunction, no body

(defun hl-module-name (hl-module)
  (declare (type (satisfies hl-module-p) hl-module))
  (hl-mod-name hl-module))

(defun hl-module-plist (hl-module)
  (hl-mod-plist hl-module))

(defun hl-module-property (hl-module property)
  "[Cyc] @return 0 the value of PROPERTY for HL-MODULE.
@return 1 booleanp; whether the returned value was inferred as a default."
  (let* ((plist (hl-module-plist hl-module))
         (value (getf plist property :default)))
    (if (eq value :default)
        (values (gethash property *hl-module-property-defaults*) t)
        (values value nil))))

(defun hl-module-property-without-values (hl-module property)
  "[Cyc] @return the value of PROPERTY for HL-MODULE (no multiple values)."
  (let* ((plist (hl-module-plist hl-module))
         (value (getf plist property :default)))
    (when (eq value :default)
      (setf value (gethash property *hl-module-property-defaults*)))
    value))

;; (defun hl-module-property-not-default? (hl-module property) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants: $list77 arglist ((HL-MODULE-VAR &KEY DONE) &BODY BODY),
;; $sym81 makeUninternedSymbol("NAME-VAR"), $sym82 DO-HASH-TABLE, $list83 (HL-MODULE-STORE), $sym84 IGNORE
(defmacro do-hl-modules ((hl-module-var &key done) &body body)
  (with-temp-vars (name-var)
    `(block nil
       (maphash (lambda (,name-var ,hl-module-var)
                  (declare (ignore ,name-var))
                  ,@(when done
                      `((when ,done (return nil))))
                  ,@body)
                (hl-module-store)))))

;;; HL module store

(defglobal *hl-module-store* (make-hash-table :test #'equal :size 212)
  "[Cyc] An index mapping HL module names to the modules themselves.")

(defun hl-module-store ()
  *hl-module-store*)

(defun find-hl-module-by-name (name)
  (gethash name *hl-module-store*))

(defun add-hl-module (hl-module)
  (let ((name (hl-module-name hl-module)))
    (setf (gethash name *hl-module-store*) hl-module))
  hl-module)

(defun remove-hl-module (hl-module)
  (let ((name (hl-module-name hl-module)))
    (remhash name *hl-module-store*))
  hl-module)

(defun setup-module (name type plist)
  (let ((new-plist (copy-list plist)))
    (setf new-plist (putf plist :module-type type))
    (new-hl-module name new-plist)))

;; (defun default-cost-func (&optional arg) ...) -- active declareFunction, no body
;; (defun default-expand-func (&optional arg1 arg2) ...) -- active declareFunction, no body

(defun hl-module-type (hl-module)
  (hl-module-property-without-values hl-module :module-type))

;; (defun hl-module-subtypes (hl-module) ...) -- active declareFunction, no body
;; (defun abductive-hl-module? (hl-module) ...) -- active declareFunction, no body

(defun hl-module-universal (hl-module)
  (hl-module-property-without-values hl-module :universal))

;; (defun hl-module-source (hl-module) ...) -- active declareFunction, no body

(defun hl-module-sense (hl-module)
  (hl-module-property-without-values hl-module :sense))

(defun hl-module-sense-relevant-p (hl-module sense)
  (let ((module-sense (hl-module-sense hl-module)))
    (or (null module-sense)
        (eq module-sense sense))))

(defun hl-module-required-pattern (hl-module)
  (hl-module-property-without-values hl-module :required-pattern))

(defun hl-module-required-pattern-matched-p (hl-module asent)
  (let ((pattern (hl-module-required-pattern hl-module)))
    (or (eq :anything pattern)
        (pattern-matches-formula-without-bindings pattern asent))))

(defun hl-module-required-mt (hl-module)
  (hl-module-property-without-values hl-module :required-mt))

(defun hl-module-required-mt-result (hl-module)
  "[Cyc] @note: a return value of NIL means that all mts are relevant to HL-MODULE"
  (let ((required-mt-prop (hl-module-required-mt hl-module)))
    (when required-mt-prop
      (interpret-hl-module-mt-prop required-mt-prop))))

(defun interpret-hl-module-mt-prop (mt-prop)
  (cond
    ((hlmt-p mt-prop) mt-prop)
    ((and (symbolp mt-prop) (boundp mt-prop))
     (symbol-value mt-prop))
    (t (possibly-cyc-api-eval mt-prop))))

(defun hl-module-required-mt-relevant? (hl-module)
  (let ((required-mt (hl-module-required-mt-result hl-module)))
    (or (null required-mt)
        (relevant-mt? required-mt))))

(defun hl-module-required-func (hl-module)
  (hl-module-property-without-values hl-module :required))

(defun hl-module-cost-pattern (hl-module)
  (hl-module-property-without-values hl-module :cost-pattern))

(defun hl-module-cost-expression (hl-module)
  (hl-module-property-without-values hl-module :cost-expression))

(defun hl-module-cost-func (hl-module)
  (hl-module-property-without-values hl-module :cost))

(defun hl-module-cost (hl-module object &optional sense)
  "[Cyc] Determines the estimated # of child nodes generated by HL-MODULE
when applied to OBJECT with sense SENSE."
  (declare (ignore sense))
  (let ((cost (hl-module-cost-pattern-result hl-module object)))
    (unless (numberp cost)
      (setf cost (hl-module-cost-expression-result hl-module))
      (unless (numberp cost)
        (setf cost (hl-module-cost-function-result hl-module object))))
    cost))

(defun hl-module-asent-cost (hl-module asent)
  (hl-module-cost hl-module asent))

;; (defun hl-module-clause-cost (hl-module clause) ...) -- active declareFunction, no body

(defun hl-module-cost-pattern-result (hl-module formula)
  "[Cyc] Determines the estimated # of child nodes generated by HL-MODULE
when applied to FORMULA based on the :cost-pattern property."
  (let ((cost-pattern (hl-module-cost-pattern hl-module)))
    (when cost-pattern
      (pattern-transform-formula cost-pattern formula))))

(defun hl-module-cost-expression-result (hl-module)
  "[Cyc] Determines the estimated # of child nodes generated by HL-MODULE
based on the :cost-expression property."
  (let ((cost-expression (hl-module-cost-expression hl-module)))
    (cond
      ((null cost-expression) nil)
      ((numberp cost-expression) cost-expression)
      ((and (symbolp cost-expression) (boundp cost-expression))
       (symbol-value cost-expression))
      (t (possibly-cyc-api-eval cost-expression)))))

(defun hl-module-cost-function-result (hl-module object)
  "[Cyc] Determines the estimated # of child nodes generated by HL-MODULE
when applied to OBJECT based on the :cost property."
  (let ((cost-func (hl-module-cost-func hl-module)))
    (when (possibly-cyc-api-function-spec-p cost-func)
      (possibly-cyc-api-funcall cost-func object))))

;; (defun hl-module-asent-cost-function-result (hl-module asent) ...) -- active declareFunction, no body
;; (defun hl-module-clause-cost-function-result (hl-module clause) ...) -- active declareFunction, no body

(defun hl-module-is-check? (hl-module)
  "[Cyc] @return boolean; whether HL-MODULE is a check module which evaluates
to a boolean."
  (let ((check (hl-module-property-without-values hl-module :check)))
    (if (eq check :unknown)
        (guess-hl-module-is-check? hl-module)
        (not (null check)))))

(defun guess-hl-module-is-check? (hl-module)
  (let ((required-pattern (hl-module-required-pattern hl-module)))
    (if (expression-find :not-fully-bound required-pattern)
        nil
        (let* ((name (str (hl-module-name hl-module)))
               (check? (substring? "check" name)))
          check?))))

(defun hl-module-rule-select-func (hl-module)
  (hl-module-property-without-values hl-module :rule-select))

(defun hl-module-rule-filter-func (hl-module)
  (hl-module-property-without-values hl-module :rule-filter))

(defun hl-module-expand-func (hl-module)
  (cinc-module-expand-count hl-module)
  (let ((expand (hl-module-property-without-values hl-module :expand)))
    (if (eq :default expand)
        (default-expand-func-for-hl-module hl-module)
        expand)))

(defun default-expand-func-for-hl-module (hl-module)
  (if (eq :removal (hl-module-type hl-module))
      (if (hl-module-is-check? hl-module)
          'inference-remove-check-default
          'inference-remove-unify-default)
      'default-expand-func))

(defun hl-module-expand-pattern (hl-module)
  (hl-module-property-without-values hl-module :expand-pattern))

;; (defun hl-module-expand-iterative-pattern (hl-module) ...) -- active declareFunction, no body

(defun hl-module-predicate (hl-module)
  (hl-module-property-without-values hl-module :predicate))

(defun hl-module-predicate-relevant-p (hl-module predicate)
  (let ((hl-module-predicate (hl-module-predicate hl-module)))
    (when hl-module-predicate
      (return-from hl-module-predicate-relevant-p
        (eq hl-module-predicate predicate))))
  (let ((hl-module-any-preds (hl-module-any-predicates hl-module)))
    (when hl-module-any-preds
      (return-from hl-module-predicate-relevant-p
        (member? predicate hl-module-any-preds #'pattern-matches-formula))))
  t)

(defun hl-module-arity (hl-module)
  (hl-module-property-without-values hl-module :arity))

(defun hl-module-arity-relevant-p (hl-module asent)
  (let ((hl-module-arity (hl-module-arity hl-module)))
    (or (null hl-module-arity)
        (and (el-formula-without-sequence-term? asent)
             (= hl-module-arity (length (rest asent)))))))

(defun hl-module-exclusive-func (hl-module)
  (hl-module-property-without-values hl-module :exclusive))

(defun hl-module-supplants-info (hl-module)
  (hl-module-property-without-values hl-module :supplants))

(defun hl-module-direction (hl-module)
  (hl-module-property-without-values hl-module :direction))

(defun hl-module-direction-relevant? (hl-module)
  (if (not (within-forward-inference?))
      t
      (eq (hl-module-direction hl-module) :forward)))

(defun hl-module-input-extract-pattern (hl-module)
  (hl-module-property-without-values hl-module :input-extract-pattern))

(defun hl-module-input-verify-pattern (hl-module)
  (hl-module-property-without-values hl-module :input-verify-pattern))

(defun hl-module-input-encode-pattern (hl-module)
  (hl-module-property-without-values hl-module :input-encode-pattern))

(defun hl-module-output-check-pattern (hl-module)
  (hl-module-property-without-values hl-module :output-check-pattern))

(defun hl-module-output-generate-pattern (hl-module)
  (hl-module-property-without-values hl-module :output-generate-pattern))

(defun hl-module-output-decode-pattern (hl-module)
  (hl-module-property-without-values hl-module :output-decode-pattern))

(defun hl-module-output-verify-pattern (hl-module)
  (hl-module-property-without-values hl-module :output-verify-pattern))

(defun hl-module-output-construct-pattern (hl-module)
  (hl-module-property-without-values hl-module :output-construct-pattern))

(defun hl-module-support-pattern (hl-module)
  (hl-module-property-without-values hl-module :support-pattern))

(defun hl-module-support-func (hl-module)
  (hl-module-property-without-values hl-module :support))

(defun hl-module-support-module (hl-module)
  (hl-module-property-without-values hl-module :support-module))

(defun hl-module-support-mt (hl-module)
  (multiple-value-bind (support-mt default-inferred?)
      (hl-module-property hl-module :support-mt)
    (when default-inferred?
      (setf support-mt (current-mt-relevance-mt)))
    support-mt))

(defun hl-module-support-mt-result (hl-module)
  (let ((support-mt-prop (hl-module-support-mt hl-module)))
    (interpret-hl-module-mt-prop support-mt-prop)))

(defun hl-module-support-strength (hl-module)
  (hl-module-property-without-values hl-module :support-strength))

(defun hl-module-every-predicates (hl-module)
  (hl-module-property-without-values hl-module :every-predicates))

(defun hl-module-applicability-func (hl-module)
  (hl-module-property-without-values hl-module :applicability))

(defun hl-module-applicability-pattern (hl-module)
  (hl-module-property-without-values hl-module :applicability-pattern))

(defun hl-module-any-predicates (hl-module)
  (hl-module-property-without-values hl-module :any-predicates))

;; (defun hl-module-documentation-string (hl-module) ...) -- active declareFunction, no body
;; (defun hl-module-example-string (hl-module) ...) -- active declareFunction, no body
;; (defun hl-module-complete? (hl-module asent) ...) -- active declareFunction, no body
;; (defun hl-module-incomplete? (hl-module asent) ...) -- active declareFunction, no body

(defun hl-module-completeness (hl-module asent &optional (default-completeness :incomplete))
  (let ((completeness (hl-module-property-without-values hl-module :completeness)))
    (when completeness
      (return-from hl-module-completeness completeness)))
  (let ((pattern (hl-module-property-without-values hl-module :complete-pattern)))
    (when (and pattern (pattern-matches-formula-without-bindings pattern asent))
      (return-from hl-module-completeness :complete)))
  (let ((pattern (hl-module-property-without-values hl-module :completeness-pattern)))
    (when pattern
      (let ((completeness (pattern-transform-formula pattern asent)))
        (when completeness
          (return-from hl-module-completeness completeness)))))
  default-completeness)

;; (defun hl-module-clause-completeness (hl-module clause) ...) -- active declareFunction, no body

(defun hl-module-external? (hl-module)
  (hl-module-property-without-values hl-module :external))

(defun hl-module-active? (hl-module &optional inactive-hl-modules)
  (not (member? hl-module inactive-hl-modules)))

;;; Removal modules

(defglobal *removal-modules* (new-set #'eq)
  "[Cyc] Set of all possible removal modules.")

;; Reconstructed from Internal Constants: $list134 arglist, $sym135 DO-SET, $list136 (REMOVAL-MODULES)
(defmacro do-removal-modules ((hl-module &key done) &body body)
  `(do-set (,hl-module (removal-modules) ,done)
     ,@body))

(defun removal-modules ()
  *removal-modules*)

(defun removal-module-p (object)
  (set-member? object *removal-modules*))

;; (defun removal-module-count () ...) -- active declareFunction, no body
;; (defun some-external-removal-modules? () ...) -- active declareFunction, no body

(defglobal *removal-modules-external* nil
  "[Cyc] List of all the external removal modules.")

(defglobal *removal-modules-generic* nil
  "[Cyc] List of all the generic literal-level removal modules.")

;; (defun generic-removal-module-p (object) ...) -- active declareFunction, no body
;; (defun generic-removal-modules () ...) -- active declareFunction, no body

(defun generic-removal-modules-for-sense (sense)
  (remove (inverse-sense sense) *removal-modules-generic*
          :key #'hl-module-sense :test #'eq))

;; (defun generic-removal-module-count () ...) -- active declareFunction, no body

(defglobal *removal-modules-universal* nil
  "[Cyc] List of all the universal literal-level removal modules.")

;; (defun universal-removal-modules () ...) -- active declareFunction, no body
;; (defun universal-removal-module-p (object) ...) -- active declareFunction, no body
;; (defun universal-removal-module-count () ...) -- active declareFunction, no body
;; (defun universal-removal-module-exception-predicates (hl-module) ...) -- active declareFunction, no body
;; (defun universal-removal-module-exception-predicate? (hl-module predicate) ...) -- active declareFunction, no body
;; (defun predicate-doesnt-use-universal-removal-module? (predicate hl-module) ...) -- active declareFunction, no body

(defun universal-removal-modules-for-sense (sense)
  (remove (inverse-sense sense) *removal-modules-universal*
          :key #'hl-module-sense :test #'eq))

(defglobal *removal-modules-specific* (make-hash-table :test #'eq :size 32)
  "[Cyc] A mapping between predicates and a list of modules which exclusively service that predicate.")

;; (defun removal-modules-specific (predicate) ...) -- active declareFunction, no body
;; (defun predicate-has-specific-removal-modules? (predicate) ...) -- active declareFunction, no body

(defun removal-modules-specific-for-sense (predicate sense)
  "[Cyc] Return the removal modules declared specific to PREDICATE in SENSE literals.
@note destructible"
  (declare (type (satisfies fort-p) predicate))
  (remove (inverse-sense sense)
          (gethash predicate *removal-modules-specific* nil)
          :key #'hl-module-sense :test #'eq))

(defun removal-modules-universal-for-predicate-and-sense (predicate sense)
  "[Cyc] Return universal removal modules for SENSE that have not been declared as dont-use for PREDICATE.
@note destructible"
  (declare (type (satisfies fort-p) predicate))
  (let ((universal-modules nil))
    (dolist (universal-module (universal-removal-modules-for-sense sense))
      (unless (missing-larkc 36421)
        (push universal-module universal-modules)))
    (nreverse universal-modules)))

;; (defun predicates-with-specific-removal-modules () ...) -- active declareFunction, no body
;; (defun specific-removal-modules () ...) -- active declareFunction, no body
;; (defun specific-removal-module-count () ...) -- active declareFunction, no body
;; (defun specific-removal-module-set () ...) -- active declareFunction, no body

(defglobal *removal-modules-specific-use-generic* nil
  "[Cyc] A mapping between generic modules and specific predicates for which they should also be used.")

(defglobal *removal-modules-specific-use-meta-removal* nil
  "[Cyc] A mapping between meta-removal modules and specific predicates for which they should also be used.")

(defglobal *removal-modules-specific-dont-use-universal* nil
  "[Cyc] A mapping between universal modules and specific predicates for which they should not be used.")

(defglobal *solely-specific-removal-module-predicate-store* (new-set #'eq 50))

;; (defun clear-solely-specific-removal-module-predicate-store () ...) -- active declareFunction, no body

(defun rebuild-solely-specific-removal-module-predicate-store ()
  (set-rebuild *solely-specific-removal-module-predicate-store*))

(defun register-solely-specific-removal-module-predicate (predicate)
  "[Cyc] If you want the specific removal modules for PREDICATE to supplant ALL
generic removal modules, then register this property."
  (set-add predicate *solely-specific-removal-module-predicate-store*))

;; (defun deregister-solely-specific-removal-module-predicate (predicate) ...) -- active declareFunction, no body

(defun solely-specific-removal-module-predicate? (predicate)
  (set-member? predicate *solely-specific-removal-module-predicate-store*))

(defun inference-removal-module (name plist)
  "[Cyc] Declare an inference removal module named NAME with properties in PLIST."
  (let* ((strengthened-plist (strengthen-removal-module-properties name plist))
         (hl-module (setup-module name :removal strengthened-plist)))
    (set-add hl-module *removal-modules*)
    (classify-removal-module hl-module)
    hl-module))

(defun inference-removal-module-use-generic (predicate name)
  "[Cyc] State that the generic removal module named NAME should also be used for PREDICATE."
  (let ((hl-module (find-hl-module-by-name name)))
    (when hl-module
      (let ((existing (assoc hl-module *removal-modules-specific-use-generic*)))
        (unless existing
          (setf existing (list hl-module))
          (push existing *removal-modules-specific-use-generic*))
        (rplacd existing (adjoin predicate (rest existing))))
      (inference-removal-module-note-specific predicate hl-module))))

(defun inference-removal-module-use-meta-removal (predicate name)
  "[Cyc] State that the meta-removal module named NAME should also be used for PREDICATE."
  (let ((hl-module (find-hl-module-by-name name)))
    (when hl-module
      (let ((existing (assoc hl-module *removal-modules-specific-use-meta-removal*)))
        (unless existing
          (setf existing (list hl-module))
          (push existing *removal-modules-specific-use-meta-removal*))
        (rplacd existing (adjoin predicate (rest existing))))
      hl-module)))

(defun inference-removal-module-dont-use-universal (predicate name)
  "[Cyc] State that the universal removal module named NAME should not be used for PREDICATE."
  (let ((hl-module (find-hl-module-by-name name)))
    (when hl-module
      (let ((existing (assoc hl-module *removal-modules-specific-dont-use-universal*)))
        (unless existing
          (setf existing (list hl-module))
          (push existing *removal-modules-specific-dont-use-universal*))
        (rplacd existing (adjoin predicate (rest existing))))
      hl-module)))

;; (defun redeclare-inference-removal-module (name) ...) -- active declareFunction, no body

(defun strengthen-removal-module-properties (name plist)
  (setf plist (copy-tree plist))
  (let ((sense (getf plist :sense)))
    (unless (or (eql sense :pos) (eql sense :neg))
      (error "removal module ~S must have a :SENSE of :POS or :NEG" name)))
  plist)

;; (defun undeclare-inference-removal-module (name &optional also-undeclare-use-generic?) ...) -- active declareFunction, no body
;; (defun undeclare-inference-meta-removal-module (name) ...) -- active declareFunction, no body
;; (defun undeclare-inference-removal-module-use-generic (predicate name &optional also-undeclare-removal?) ...) -- active declareFunction, no body
;; (defun undeclare-inference-removal-module-use-meta-removal (predicate name &optional also-undeclare-meta-removal?) ...) -- active declareFunction, no body
;; (defun undeclare-inference-removal-module-dont-use-universal (predicate name &optional also-undeclare-removal?) ...) -- active declareFunction, no body

(defun reclassify-removal-modules ()
  "[Cyc] @note also reclassifies preference modules"
  (clear-removal-modules)
  (rebuild-solely-specific-removal-module-predicate-store)
  (dolist (generic-info *removal-modules-specific-use-generic*)
    (destructuring-bind (hl-module &rest predicates) generic-info
      (dolist (predicate predicates)
        (inference-removal-module-note-specific predicate hl-module))))
  ;; [Clyc] Reconstituted do-set macro from Java compiler expansion
  (do-set (hl-module (removal-modules))
    (classify-removal-module hl-module))
  (reclassify-preference-modules)
  nil)

(defun clear-removal-modules ()
  (clrhash *removal-modules-specific*)
  (setf *removal-modules-external* nil)
  (setf *removal-modules-generic* nil)
  nil)

(defun classify-removal-module (hl-module)
  (if (hl-module-external? hl-module)
      (pushnew hl-module *removal-modules-external* :test #'eql)
      (let ((predicate-spec (hl-module-predicate hl-module))
            (universal? (hl-module-universal hl-module)))
        (cond
          (universal?
           (pushnew hl-module *removal-modules-universal* :test #'eql))
          ((null predicate-spec)
           (pushnew hl-module *removal-modules-generic* :test #'eql))
          ((atom predicate-spec)
           (inference-removal-module-note-specific predicate-spec hl-module))
          (t
           (dolist (predicate predicate-spec)
             (inference-removal-module-note-specific predicate hl-module))))))
  hl-module)

(defun inference-removal-module-note-specific (predicate hl-module)
  (setf (gethash predicate *removal-modules-specific*)
        (adjoin hl-module (gethash predicate *removal-modules-specific* nil)))
  hl-module)

;;; Conjunctive removal modules

(defglobal *conjunctive-removal-modules* (new-set #'eq)
  "[Cyc] A set of all currently declared conjunctive removal modules.")

;; Reconstructed from Internal Constants: $list157 arglist, DO-SET, $list158 (REMOVAL-MODULES-CONJUNCTIVE)
(defmacro do-conjunctive-removal-modules ((module &key done) &body body)
  `(do-set (,module (removal-modules-conjunctive) ,done)
     ,@body))

(defun removal-modules-conjunctive ()
  *conjunctive-removal-modules*)

(defun conjunctive-removal-module-p (object)
  "[Cyc] Return T iff OBJECT is a conjunctive removal module."
  (set-member? object *conjunctive-removal-modules*))

;; (defun conjunctive-removal-module-count () ...) -- active declareFunction, no body
;; (defun conjunctive-removal-modules () ...) -- active declareFunction, no body

(defun inference-conjunctive-removal-module (name plist)
  "[Cyc] Declare a conjunctive inference removal module named NAME.
Allowed properties in PLIST:
:every-predicates <listp of predicate-p>; a necessary condition for applicability;
  the clause must contain every predicate in the list for MODULE to apply.
:applicability <function-spec-p>; a unary function whose single argument is
  a contextualized-dnf-clause-p.  Its return value is a list of subclause-spec-p
  indicating which subclauses of the input clause MODULE applies to.
  @note each of the returned subclauses must be a multi-literal-subclause-spec?.
:cost <function-spec-p>; a unary function whose single argument is
  a contextualized-dnf-clause-p.  Its return value is a non-negative number which is
  the expected number of bindings returned by MODULE when MODULE applies
  to the entire input clause, i.e. the return value of the applicability method
  is a singleton whose sole element picks out the totality of the input clause.
  A special case is that if it returns a zero, this indicates that this module
  does not in fact apply.
:expand <function-spec-p>; a unary function whose single argument is
  a contextualized-dnf-clause-p.  Its return value is NIL and it works by
  side effect, calling conjunctive-removal-callback once for each
  binding list it determines to be an answer.  The JUSTIFICATIONS argument
  to conjunctive-removal-callback is an ordered list of hl-justification-p.
  Each justification in JUSTIFICATIONS is a justification for a particular
  literal in the input clause, neg-lits first followed by pos-lits.
:documentation <stringp>; an explanation of what types of queries MODULE solves.
:example <stringp>; an example query that could be solved by MODULE."
  (let ((hl-module (setup-module name :removal-conjunctive plist)))
    (set-add hl-module *conjunctive-removal-modules*)
    hl-module))

;; (defun undeclare-inference-conjunctive-removal-module (name) ...) -- active declareFunction, no body

;;; Meta-removal modules

;; Reconstructed from Internal Constants: same arglist pattern, $list162 (META-REMOVAL-MODULES)
;; *meta-removal-modules* is a list, not a set, so uses dolist
(defmacro do-meta-removal-modules ((module &key done) &body body)
  `(dolist (,module (meta-removal-modules) ,done)
     ,@body))

(defun meta-removal-modules ()
  *meta-removal-modules*)

;; (defun meta-removal-module-list () ...) -- active declareFunction, no body

(defun meta-removal-module-p (object)
  (dolist (module (meta-removal-modules))
    (when (eq object module)
      (return t))))

;; (defun meta-removal-module-count () ...) -- active declareFunction, no body

(defun meta-removal-module-specific-predicates (meta-removal-module)
  "[Cyc] @return listp; a list of predicates with specific removal modules
that want to use this meta-removal module."
  (alist-lookup *removal-modules-specific-use-meta-removal* meta-removal-module #'eq))

(defun meta-removal-module-specific-predicate? (meta-removal-module predicate)
  (member-eq? predicate (meta-removal-module-specific-predicates meta-removal-module)))

(defun predicate-uses-meta-removal-module? (predicate meta-removal-module)
  "[Cyc] All predicates use all meta-removal modules unless they are solely specific
and have not been stated as inference-removal-module-use-meta-removal."
  (when (fort-p predicate)
    (when (solely-specific-removal-module-predicate? predicate)
      (unless (meta-removal-module-specific-predicate? meta-removal-module predicate)
        (return-from predicate-uses-meta-removal-module? nil))))
  t)

(defun inference-meta-removal-module (name &optional plist)
  "[Cyc] Meta-removal modules are modules which execute other removal tactics on the same problem."
  (let ((hl-module (setup-module name :meta-removal plist)))
    (pushnew hl-module *meta-removal-modules* :test #'eq)
    hl-module))

;; (defun removal-proof-module-p (object) ...) -- active declareFunction, no body

;;; Transformation modules

(defglobal *transformation-modules* nil
  "[Cyc] Set of all transformation modules.")

;; Reconstructed from Internal Constants: same arglist pattern, $list167 (TRANSFORMATION-MODULES)
;; *transformation-modules* is a list, so uses dolist
(defmacro do-transformation-modules ((module &key done) &body body)
  `(dolist (,module (transformation-modules) ,done)
     ,@body))

(defun transformation-modules ()
  *transformation-modules*)

(defun transformation-module-p (object)
  (member-eq? object *transformation-modules*))

;; (defun transformation-module-count () ...) -- active declareFunction, no body

(defun inference-transformation-module (name plist)
  (let ((hl-module (setup-module name :transformation plist)))
    (pushnew hl-module *transformation-modules* :test #'eq)
    hl-module))

;;; Meta-transformation modules

(defglobal *meta-transformation-modules* nil
  "[Cyc] Set of all meta-transformation modules.")

;; Reconstructed from Internal Constants: same arglist pattern, $list172 (META-TRANSFORMATION-MODULES)
;; *meta-transformation-modules* is a list, so uses dolist
(defmacro do-meta-transformation-modules ((module &key done) &body body)
  `(dolist (,module (meta-transformation-modules) ,done)
     ,@body))

(defun meta-transformation-modules ()
  *meta-transformation-modules*)

(defun meta-transformation-module-p (object)
  (member-eq? object *meta-transformation-modules*))

;; (defun meta-transformation-module-count () ...) -- active declareFunction, no body

(defun inference-meta-transformation-module (name &optional plist)
  (let ((hl-module (setup-module name :meta-transformation plist)))
    (pushnew hl-module *meta-transformation-modules* :test #'eq)
    hl-module))

;;; Rewrite modules

(defglobal *rewrite-modules* nil
  "[Cyc] Set of all rewrite modules.")

;; Reconstructed from Internal Constants: same arglist pattern, $list177 (REWRITE-MODULES)
;; *rewrite-modules* is a list, so uses dolist
(defmacro do-rewrite-modules ((module &key done) &body body)
  `(dolist (,module (rewrite-modules) ,done)
     ,@body))

(defun rewrite-modules ()
  *rewrite-modules*)

(defun rewrite-module-p (object)
  (member-eq? object *rewrite-modules*))

;; (defun rewrite-module-count () ...) -- active declareFunction, no body
;; (defun rewrite-module-support (hl-module) ...) -- active declareFunction, no body
;; (defun rewrite-module-closure (hl-module) ...) -- active declareFunction, no body

(defun inference-rewrite-module (name plist)
  "[Cyc] Declares NAME to be a rewrite module, with properties specified by PLIST."
  (let* ((strengthened-plist (strengthen-rewrite-module-properties name plist))
         (hl-module (setup-module name :rewrite strengthened-plist)))
    (pushnew hl-module *rewrite-modules* :test #'eq)
    hl-module))

;; (defun undeclare-rewrite-module (hl-module) ...) -- active declareFunction, no body
;; (defun undeclare-rewrite-module-by-name (name) ...) -- active declareFunction, no body
;; (defun deregister-rewrite-module (hl-module) ...) -- active declareFunction, no body
;; (defun deregister-rewrite-module-by-name (name) ...) -- active declareFunction, no body

(defun strengthen-rewrite-module-properties (name plist)
  (setf plist (copy-tree plist))
  (let ((sense (getf plist :sense)))
    (unless (or (eql sense :pos) (eql sense :neg))
      (error "rewrite module ~S must have a :SENSE of :POS or :NEG" name)))
  plist)

;;; Structural modules

(defglobal *structural-modules* nil
  "[Cyc] Set of all structural modules.")

(defun structural-module-p (object)
  (member-eq? object *structural-modules*))

(defun inference-structural-module (name &optional plist)
  (let ((hl-module (setup-module name :structural plist)))
    (pushnew hl-module *structural-modules* :test #'eq)
    hl-module))

;; (defun structural-module-count () ...) -- active declareFunction, no body

;;; Meta-structural modules

(defglobal *meta-structural-modules* nil
  "[Cyc] Set of all meta-structural modules.")

;; Reconstructed from Internal Constants: same arglist pattern, $list185 (META-STRUCTURAL-MODULES)
;; *meta-structural-modules* is a list, so uses dolist
(defmacro do-meta-structural-modules ((module &key done) &body body)
  `(dolist (,module (meta-structural-modules) ,done)
     ,@body))

(defun meta-structural-modules ()
  *meta-structural-modules*)

(defun meta-structural-module-p (object)
  (member-eq? object *meta-structural-modules*))

;; (defun meta-structural-module-count () ...) -- active declareFunction, no body

(defun inference-meta-structural-module (name &optional plist)
  (let ((hl-module (setup-module name :meta-structural plist)))
    (pushnew hl-module *meta-structural-modules* :test #'eq)
    hl-module))

;;; CFASL

(defconstant *cfasl-wide-opcode-hl-module* 256)

;; (defun cfasl-output-object-hl-module-method (object stream) ...) -- active declareFunction, no body
;; (defun cfasl-wide-output-hl-module (object stream) ...) -- active declareFunction, no body
;; (defun cfasl-output-hl-module-internal (hl-module stream) ...) -- active declareFunction, no body
;; (defun cfasl-input-hl-module (stream) ...) -- active declareFunction, no body

;;; Setup

(toplevel
  (register-macro-helper 'hl-module-store 'do-hl-modules)
  (register-macro-helper 'removal-modules 'do-removal-modules)
  (register-macro-helper 'removal-modules-conjunctive 'do-conjunctive-removal-modules)
  (register-macro-helper 'meta-removal-modules 'do-meta-removal-modules)
  (register-macro-helper 'transformation-modules 'do-transformation-modules)
  (register-macro-helper 'meta-transformation-modules 'do-meta-transformation-modules)
  (register-macro-helper 'meta-structural-modules 'do-meta-structural-modules)
  (register-wide-cfasl-opcode-input-function *cfasl-wide-opcode-hl-module* 'cfasl-input-hl-module))
