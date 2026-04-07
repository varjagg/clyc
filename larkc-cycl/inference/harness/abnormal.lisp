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

(defvar *abnormality-checking-enabled* t
  "[Cyc] When non-nil, #$abnormal reasoning is performed to defeat proofs.")

(defparameter *abnormality-except-support-enabled* t
  "[Cyc] When non-nil, support #$except abnormality checking.")

(defun abnormality-except-support-enabled? ()
  *abnormality-except-support-enabled*)

(defun rule-has-exceptions? (rule)
  "[Cyc] Return T iff RULE is a rule that has some exceptions somewhere."
  (and (rule-assertion? rule)
       (assertion-has-meta-assertions? rule)
       (or (plusp (num-gaf-arg-index rule 2 #$abnormal))
           ;; Likely checks num-gaf-arg-index with a different predicate — evidence:
           ;; parallel structure with the first check above.
           (plusp (missing-larkc 12775))
           (and (abnormality-except-support-enabled?)
                (excepted-assertion? rule)))))

(defun rule-bindings-abnormal? (store rule rule-bindings transformation-mt)
  "[Cyc] Return non-nil iff RULE-BINDINGS can be proven to be abnormal wrt RULE in
in problem-store STORE under the assumptions of TRANSFORMATION-MT."
  (when (rule-has-exceptions? rule)
    (let ((bound-values-to-check (mapcar #'variable-binding-value
                                         (canonicalize-proof-bindings rule-bindings))))
      ;; Likely performs the abnormality check query using bound-values-to-check,
      ;; store, rule, and transformation-mt — evidence: all four arguments are available
      ;; and bound-values-to-check is computed for use in the query.
      (missing-larkc 35171))))

(defvar *abnormality-transformation-depth* 1)

;; (defun abnormality-check-internal (store rule bound-values-to-check transformation-mt) ...) -- active declareFunction, no body
;; (defun abnormality-check-sentence (rule bound-values-to-check) ...) -- active declareFunction, no body
;; (defun abnormality-check-query-properties (store) ...) -- active declareFunction, no body
;; (defun abnormality-query-used-illegal-proof? (query-results rule) ...) -- active declareFunction, no body
;; (defun abnormality-justification-used-illegal-proof? (justification rule) ...) -- active declareFunction, no body
;; (defun backward-abnormality-check (store rule bound-values-to-check) ...) -- active declareFunction, no body

(defun forward-bindings-abnormal? (propagation-mt rule trigger-bindings inference-bindings)
  "[Cyc] @return booleanp; Like @xref forward-abnormality-check except doesn't throw anything,
just returns a nice, simple boolean."
  (catch :inference-rejected
    (forward-abnormality-check propagation-mt rule trigger-bindings inference-bindings)))

(defun forward-abnormality-check (propagation-mt rule trigger-bindings inference-bindings)
  "[Cyc] Reject forward inference if the given bindings are abnormal wrt RULE."
  (when *abnormality-checking-enabled*
    (when (rule-has-exceptions? rule)
      (let ((rule-variables nil)
            (bound-values-to-check nil))
        ;; Likely retrieves the rule's node variables — evidence: the result is used
        ;; as the basis for substitution of trigger and inference bindings.
        (setf rule-variables (missing-larkc 31007))
        (setf bound-values-to-check rule-variables)
        (setf bound-values-to-check (nsublis trigger-bindings bound-values-to-check))
        (setf bound-values-to-check (nsublis inference-bindings bound-values-to-check))
        (unless (fully-bound-p bound-values-to-check)
          (cerror "Assume it isn't abnormal"
                  "Abnormality checker doesn't have all bindings for ~S" rule)
          (return-from forward-abnormality-check nil))
        (let ((*within-forward-inference?* nil))
          ;; Likely performs the abnormality check and signals if abnormal —
          ;; evidence: 35173 checks abnormality, 35175 signals the rejection.
          (when (missing-larkc 35173)
            (missing-larkc 35175))))))
  nil)

;; (defun signal-abnormal (rule bound-values-to-check) ...) -- active declareFunction, no body
