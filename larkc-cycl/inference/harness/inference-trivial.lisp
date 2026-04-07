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

;; (defun new-cyc-trivial-query (sentence mt &optional query-properties) ...) -- active declareFunction, no body
;; (defun new-cyc-trivial-query-from-dnf (dnf mt &optional scoped-vars query-properties) ...) -- active declareFunction, no body

(defun new-cyc-trivial-query-int (sentence mt query-properties)
  (setf query-properties (trivial-strategist-strengthen-query-properties query-properties))
  (when (trivial-strategist-can-handle-query-properties? query-properties)
    (let ((trivial-query-properties (filter-plist query-properties
                                                  #'trivial-strategist-at-least-partially-handled-query-property-p)))
      (multiple-value-bind (sentence-clauses v-bindings free-el-vars)
          (inference-canonicalize-ask-int sentence mt
                                         *default-inference-disjunction-free-el-vars-policy*)
        (when (atomic-clauses-p sentence-clauses)
          (let* ((sentence-clause (first sentence-clauses))
                 (free-hl-vars (apply-bindings v-bindings free-el-vars)))
            (possibly-enqueue-asked-query sentence mt query-properties)
            (return-from new-cyc-trivial-query-int
              (new-cyc-trivial-query-via-removal-ask sentence-clause v-bindings
                                                     free-hl-vars trivial-query-properties)))))))
  (values nil :non-trivial nil))

(defun new-cyc-trivial-query-from-dnf-int (dnf mt scoped-vars query-properties)
  (setf query-properties (trivial-strategist-strengthen-query-properties query-properties))
  (when (trivial-strategist-can-handle-query-properties? query-properties)
    (let ((trivial-query-properties (filter-plist query-properties
                                                  #'trivial-strategist-at-least-partially-handled-query-property-p)))
      (let ((sentence-clauses (dnf-and-mt-to-hl-query dnf mt)))
        (when (atomic-clauses-p sentence-clauses)
          (let* ((sentence-clause (first sentence-clauses))
                 (free-hl-vars (set-difference (tree-gather sentence-clause #'hl-variable-p)
                                               scoped-vars)))
            (possibly-enqueue-asked-query dnf mt query-properties)
            (return-from new-cyc-trivial-query-from-dnf-int
              (new-cyc-trivial-query-via-removal-ask sentence-clause nil
                                                     free-hl-vars trivial-query-properties)))))))
  (values nil :non-trivial nil))

(defparameter *current-query-properties* nil)

(defun current-query-property-lookup (property)
  (inference-query-property-lookup *current-query-properties* property))

;; (defun current-trivial-query-properties () ...) -- active declareFunction, no body

(defun new-cyc-trivial-query-via-removal-ask (sentence-clause v-bindings free-hl-vars
                                              trivial-query-properties)
  (let ((truth (if (pos-atomic-clause-p sentence-clause) :true :false)))
    (destructuring-bind (hl-mt hl-sentence)
        (atomic-clause-asent sentence-clause)
      (let* ((max-time (inference-properties-max-time trivial-query-properties))
             (return-type (inference-properties-return-type trivial-query-properties))
             (answer-language (inference-properties-answer-language trivial-query-properties))
             (productivity-limit (strategy-dynamic-properties-productivity-limit trivial-query-properties))
             (removal-ask-query-properties (filter-plist trivial-query-properties
                                                         #'removal-ask-query-property-p))
             (result nil)
             (halt-reason nil)
             (metrics nil))
        (let ((*current-query-properties* trivial-query-properties)
              (*currently-active-problem* nil)
              (*currently-executing-tactic* nil))
          (let ((aborted-p
                  (catch :inference-abort-target
                    (let ((*within-inference-control-process?* t))
                      (let ((error-message nil))
                        (if *inference-debug?*
                            ;; Debug mode: no error handler
                            (let ((abort-max-time max-time)
                                  (timed-out nil))
                              (if abort-max-time
                                  (progn
                                    (with-timeout (abort-max-time timed-out)
                                      (with-possibly-new-memoization-state
                                        (let ((*removal-cost-cutoff* (removal-cost-cutoff-for-productivity productivity-limit)))
                                          (multiple-value-setq (result halt-reason metrics)
                                            (removal-ask hl-sentence hl-mt truth removal-ask-query-properties)))))
                                    (when timed-out
                                      (setf halt-reason :max-time)))
                                  (with-possibly-new-memoization-state
                                    (let ((*removal-cost-cutoff* (removal-cost-cutoff-for-productivity productivity-limit)))
                                      (multiple-value-setq (result halt-reason metrics)
                                        (removal-ask hl-sentence hl-mt truth removal-ask-query-properties))))))
                            ;; Non-debug mode: with inference error handler
                            (setf error-message
                                  (catch :inference-error
                                    (handler-bind ((error (lambda (c)
                                                           (declare (ignore c))
                                                           (inference-error-handler))))
                                      (let ((abort-max-time max-time)
                                            (timed-out nil))
                                        (if abort-max-time
                                            (progn
                                              (with-timeout (abort-max-time timed-out)
                                                (with-possibly-new-memoization-state
                                                  (let ((*removal-cost-cutoff* (removal-cost-cutoff-for-productivity productivity-limit)))
                                                    (multiple-value-setq (result halt-reason metrics)
                                                      (removal-ask hl-sentence hl-mt truth removal-ask-query-properties)))))
                                              (when timed-out
                                                (setf halt-reason :max-time)))
                                            (with-possibly-new-memoization-state
                                              (let ((*removal-cost-cutoff* (removal-cost-cutoff-for-productivity productivity-limit)))
                                                (multiple-value-setq (result halt-reason metrics)
                                                  (removal-ask hl-sentence hl-mt truth removal-ask-query-properties)))))))
                                    nil)))
                        (when error-message
                          (setf halt-reason (new-inference-error-suspend-status error-message)))))
                    nil)))
            (when aborted-p
              (setf halt-reason :abort)
              (missing-larkc 35565))))
        (when result
          (setf result (removal-ask-filter-out-uninteresting-bindings result free-hl-vars))
          (setf result (removal-ask-result-closed-query-success-ntransform result))
          (setf result (removal-ask-result-return-type-ntransform result v-bindings return-type answer-language)))
        (values result halt-reason metrics)))))

(defun removal-ask-filter-out-uninteresting-bindings (result free-vars)
  (let ((filtered-result nil))
    (dolist (one-result result)
      (destructuring-bind (one-bindings one-supports) one-result
        (let ((filtered-bindings (filter-out-uninteresting-bindings one-bindings free-vars)))
          (push (list filtered-bindings one-supports) filtered-result))))
    (nreverse filtered-result)))

(defun removal-ask-result-closed-query-success-ntransform (result)
  (destructuring-bind (first-bindings first-supports) (first result)
    (declare (ignore first-supports))
    (when (unification-success-token-p first-bindings)
      (dolist (result-tuple result)
        (rplaca result-tuple nil))))
  result)

(defun removal-ask-result-return-type-ntransform (result v-bindings return-type answer-language)
  (cond
    ((eql return-type :bindings)
     (setf result (nmapcar #'first result))
     (setf result (napply-bindings-backwards-to-list v-bindings result))
     (when (eq :el answer-language)
       (setf result (nmapcar #'inference-bindings-hl-to-el result)))
     (setf result (fast-delete-duplicates result #'equal)))
    ((eql return-type :supports)
     (setf result (nmapcar #'second result)))
    ((eql return-type :bindings-and-supports)
     (setf result (napply-bindings-backwards-to-list v-bindings result))
     (when (eq :el answer-language)
       (dolist (tuple result)
         (let ((v-bindings (first tuple)))
           (rplaca tuple (inference-bindings-hl-to-el v-bindings))))))
    ((inference-template-return-type-p return-type)
     (let ((template (second return-type)))
       (declare (ignore template))
       (setf result (removal-ask-result-return-type-ntransform result v-bindings :bindings answer-language))
       ;; Likely applies the template to result bindings
       (setf result (missing-larkc 36250))))
    (t
     (error "unexpected return type ~S" return-type)))
  result)

(defun trivial-strategist-can-handle-query-properties? (query-properties)
  (do ((remainder query-properties (cddr remainder)))
      ((null remainder) t)
    (let ((property (first remainder))
          (value (cadr remainder)))
      (unless (trivial-strategist-can-handle-query-property? property value)
        (return nil)))))

(defun trivial-strategist-strengthen-query-properties (query-properties)
  (unless (transformation-allowed-by-properties? query-properties)
    (setf query-properties (remf (copy-list query-properties) :max-transformation-depth)))
  (let ((pcase-var (inference-properties-return-type query-properties)))
    (when (or (eql pcase-var :supports)
              (eql pcase-var :bindings-and-supports))
      (setf query-properties (putf (copy-list query-properties) :answer-language :hl))))
  query-properties)

(deflexical *trivial-strategist-dont-care-properties*
  '(:disjunction-free-el-vars-policy
    :allow-hl-predicate-transformation?
    :allow-unbound-predicate-transformation?
    :allow-evaluatable-predicate-transformation?
    :allowed-rules
    :forbidden-rules
    :max-proof-depth
    :probably-approximately-done
    :removal-backtracking-productivity-limit
    :max-problem-count
    :transformation-allowed?
    :add-restriction-layer-of-indirection?
    :result-uniqueness)
  "[Cyc] Query properties whose value we don't care about for trivial-strategist.")

(deflexical *trivial-strategist-forbidden-properties*
  '(:conditional-sentence?
    :non-explanatory-sentence
    :maintain-term-working-set?
    :cache-inference-results?
    :browsable?
    :continuable?
    :block?
    :problem-store-name
    :rewrite-allowed?
    :abduction-allowed?
    :forget-extra-results?)
  "[Cyc] Query properties that are forbidden to be non-nil if we're going to use trivial-strategist.")

(deflexical *trivial-strategist-forbid-non-default-properties*
  '(:transitive-closure-mode
    :equality-reasoning-method
    :equality-reasoning-domain
    :negation-by-failure?
    :completeness-minimization-allowed?
    :direction
    :evaluate-subl-allowed?
    :removal-allowed?)
  "[Cyc] Query properties that are forbidden to be anything other than the default if we're going to use trivial-strategist.")

(deflexical *trivial-strategist-partially-handled-query-properties*
  '(:return :inference-mode :metrics)
  "[Cyc] A list of query properties for which the trivial strategist can handle some
values but not others.  The handled and unhandled values are specified in
@xref trivial-strategist-query-property-unhandled-reason.")

(deflexical *trivial-strategist-handled-query-properties*
  '(:max-time :max-number :allowed-modules :answer-language
    :productivity-limit :new-terms-allowed?
    :allow-abnormality-checking? :allow-indeterminate-results?))

(defun trivial-strategist-handled-query-property-p (object)
  (member-eq? object *trivial-strategist-handled-query-properties*))

(defun trivial-strategist-at-least-partially-handled-query-property-p (object)
  (or (trivial-strategist-handled-query-property-p object)
      (member-eq? object *trivial-strategist-partially-handled-query-properties*)))

(defun trivial-strategist-can-handle-query-property? (property value)
  (cond
    ((member-eq? property *trivial-strategist-dont-care-properties*) t)
    ((trivial-strategist-handled-query-property-p property) t)
    (t (not (trivial-strategist-query-property-unhandled-reason property value)))))

(defun trivial-strategist-query-property-unhandled-reason (property value)
  (when (member-eq? property *trivial-strategist-forbidden-properties*)
    (return-from trivial-strategist-query-property-unhandled-reason
      (if value property nil)))
  (when (member-eq? property *trivial-strategist-forbid-non-default-properties*)
    (return-from trivial-strategist-query-property-unhandled-reason
      ;; Likely checks if value is the default for this property
      (if (missing-larkc 36511) nil property)))
  (case property
    (:max-transformation-depth
     (if (eql 0 value) nil :nonzero-max-transformation-depth))
    (:problem-store
     (if (null value) nil :problem-store-passed-in))
    (:forward-max-time
     (if (eql 0 value) nil :nonzero-forward-max-time))
    (:return
     ;; Likely checks if value is a handled return type
     (if (missing-larkc 35359) nil :unhandled-return-value))
    (:intermediate-step-validation-level
     (if (eq :none value) nil :intermediate-step-validation-level))
    (:inference-mode
     (if (member-eq? value '(:minimal :custom)) nil :non-trivial-inference-mode))
    (:metrics
     (if (or (member-eq? :inference-proof-spec value)
             (member-eq? :answer-proof-specs value)
             (member-eq? :total-steps value))
         :unhandled-metric
         nil))
    (otherwise :unexpected)))

;; (defun trivial-strategist-handled-return-value? (value) ...) -- active declareFunction, no body
;; (defun trivial-strategist-unhandled-template-return-keyword-p (object) ...) -- active declareFunction, no body
