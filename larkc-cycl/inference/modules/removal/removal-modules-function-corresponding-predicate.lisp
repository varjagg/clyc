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
;; $list1 = arglist ((FCP-AS PRED &OPTIONAL DONE-VAR) &BODY BODY)
;; $sym2 = gensym FCP-PRED
;; $sym3 = PWHEN, $sym4 = INDEXED-TERM-P
;; $sym5 = DO-ALL-SPEC-PREDICATES
;; $const6 = #$functionCorrespondingPredicate-Canonical
;; $sym7 = DO-GAF-ARG-INDEX
;; $kw8 = :INDEX, $kw9 = :PREDICATE, $kw10 = :TRUTH, $kw11 = :TRUE, $kw12 = :DONE
;; $kw13 = :DEPTH — orphan from do-all-spec-predicates' default search-type parameter
;; Verified against expansions in removal-fcp-check-required and removal-fcp-find-nat-required:
;; checks (indexed-term-p pred), then iterates spec predicates of
;; #$functionCorrespondingPredicate-Canonical via do-all-spec-predicates,
;; and for each fcp-pred does do-gaf-arg-index on (pred 2 fcp-pred :true).
(defmacro do-fcp-assertions-for-pred ((fcp-as pred &optional done-var) &body body)
  (with-temp-vars (fcp-pred)
    `(pwhen (indexed-term-p ,pred)
       (do-all-spec-predicates (,fcp-pred #$functionCorrespondingPredicate-Canonical
                                          :done ,done-var)
         (do-gaf-arg-index (,fcp-as ,pred
                            :index 2
                            :predicate ,fcp-pred
                            :truth :true
                            :done ,done-var)
           ,@body)))))

(defglobal *use-fcp-removal-module?* nil)

;; (defun removal-fcp-check-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-fcp-check-required (asent &optional sense)
  (declare (ignore sense))
  (let ((ans nil))
    (when *use-fcp-removal-module?*
      (let ((pred (atomic-sentence-predicate asent)))
        (do-fcp-assertions-for-pred (fcp-as pred ans)
          (let ((fail? nil)
                (nat-argnum (gaf-arg3 fcp-as))
                (argnum 0))
            (dolist (arg (formula-args asent :ignore))
              (when fail? (return))
              (incf argnum)
              (if (eql argnum nat-argnum)
                  (setf fail? (not (and (fully-bound-p arg)
                                        (or (nart-p arg)
                                            (naut? arg)))))
                  (setf fail? (not (fully-bound-p arg)))))
            (unless fail?
              (setf ans t))))))
    ans))

;; (defun removal-fcp-find-nat-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-fcp-find-nat-required (asent &optional sense)
  (declare (ignore sense))
  (let ((ans nil))
    (when *use-fcp-removal-module?*
      (let ((pred (atomic-sentence-predicate asent)))
        (do-fcp-assertions-for-pred (fcp-as pred ans)
          (let ((fail? nil)
                (nat-argnum (gaf-arg3 fcp-as))
                (argnum 0))
            (dolist (arg (formula-args asent :ignore))
              (when fail? (return))
              (incf argnum)
              (if (eql argnum nat-argnum)
                  (setf fail? (fully-bound-p arg))
                  (setf fail? (not (fully-bound-p arg)))))
            (unless fail?
              (setf ans t))))))
    ans))

;; (defun removal-fcp-support (asent) ...) -- active declareFunction, no body
;; (defun removal-fcp-bindings (asent) ...) -- active declareFunction, no body
;; (defun removal-fcp-justify (asent) ...) -- active declareFunction, no body
;; (defun removal-fcp-verify (asent) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list37 = arglist ((FUNCTION ARGNUM PREDICATE &KEY DONE SUPPORT-ASSERTION) &BODY BODY)
;; $list38 = (:DONE :SUPPORT-ASSERTION) — allowed keys
;; $kw39 = :ALLOW-OTHER-KEYS, $kw40 = :SUPPORT-ASSERTION
;; $sym41 = DO-GAF-ARG-INDEX-GP
;; $sym42 = CLET, $sym43 = GAF-ARG1, $sym44 = GAF-ARG3
;; $sym45 = EVALUATABLE-FUNCTION-P
;; $sym46 = gensym SUPPORT-ASSERTION
;; $const6 = #$functionCorrespondingPredicate-Canonical (reused)
;; Verified against expansion in removal-evaluatable-fcp-unify-required:
;; iterates over GAF assertions via do-gaf-arg-index-gp on (predicate 2 nil)
;; with pred #$functionCorrespondingPredicate-Canonical.
;; For each assertion, extracts function=(gaf-arg1), argnum=(gaf-arg3),
;; filters by evaluatable-function-p, then runs body.
;; User may supply :support-assertion to bind the iteration variable;
;; otherwise a gensym is used.
(defmacro do-corresponding-evaluatable-functions ((function argnum predicate
                                                   &key done support-assertion)
                                                  &body body)
  (let ((sa-var (or support-assertion (make-symbol "SUPPORT-ASSERTION"))))
    `(do-gaf-arg-index-gp (,sa-var ,predicate
                           :index 2
                           :predicate #$functionCorrespondingPredicate-Canonical
                           :truth :true
                           :done ,done)
       (let ((,function (gaf-arg1 ,sa-var))
             (,argnum (gaf-arg3 ,sa-var)))
         (when (evaluatable-function-p ,function)
           ,@body)))))

(defun removal-evaluatable-fcp-unify-required (asent &optional sense)
  (declare (ignore sense))
  (let ((predicate (atomic-sentence-predicate asent))
        (success? nil))
    (when (indexed-term-p predicate)
      (do-corresponding-evaluatable-functions (function argnum predicate
                                               :done success?)
        (let ((fail? nil)
              (asent-argnum 0))
          (dolist (asent-arg (formula-args asent :ignore))
            (when fail? (return))
            (incf asent-argnum)
            (unless (or (eql argnum asent-argnum)
                        (fully-bound-p asent-arg))
              (setf fail? t)))
          (unless fail?
            (setf success? t)))))
    success?))

;; (defun removal-evaluatable-fcp-unify-expand (asent &optional sense) ...) -- active declareFunction, no body

;; Setup

(toplevel
  (declare-defglobal '*use-fcp-removal-module?*))

(toplevel
  (inference-removal-module :removal-fcp-check
    (list :sense :pos
          :required 'removal-fcp-check-required
          :cost-expression 0
          :expand 'removal-fcp-check-expand
          :documentation "(<functional-pred> . <args>)
    with all ARGS fully bound
    using only the KB GAF indexing and explicit assertions"
          :example "(#$territoryOf #$France (#$TerritoryFn #$France))")))

(toplevel
  (inference-removal-module :removal-fcp-find-nat
    (list :sense :pos
          :required 'removal-fcp-find-nat-required
          :cost-expression 0
          :expand 'removal-fcp-find-nat-expand
          :documentation "(<functional-pred> . <args>)
    with only NAT arg not fully bound
    using only the KB GAF indexing and explicit assertions"
          :example "(#$territoryOf #$France ?TERRITORY)
    (#$anatomicalPartOfType #$AbrahamLincoln #$Head-AnimalBodyPart ?HEAD)
    (#$intervalEndedBy ?INTERVAL #$WorldWarII)")))

(toplevel
  (inference-removal-module :removal-evaluatable-fcp-unify
    (list :sense :pos
          :required 'removal-evaluatable-fcp-unify-required
          :cost-expression 1
          :expand 'removal-evaluatable-fcp-unify-expand
          :completeness :complete
          :documentation "(<functional-pred> . <args>)
    with all ARGS fully bound except possibly the functional arg"
          :example "(#$commonResidue (#$Degree-UnitOfAngularMeasure 450) ?X)")))
