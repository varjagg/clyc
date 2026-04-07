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

(defun make-eval-support (sentence &optional contextualized?)
  (let ((module (if contextualized? :code :eval)))
    (make-hl-support module sentence)))

(defparameter *default-eval-cost* 1)

(defun removal-eval-exclusive (asent &optional sense)
  (declare (ignore sense))
  (let* ((pred (atomic-sentence-predicate asent))
         (mt (current-mt-relevance-mt))
         (constraint-mt (conservative-constraint-mt mt))
         (exclusive? nil))
    (with-inference-mt-relevance constraint-mt
      (setf exclusive? (inference-evaluatable-predicate? pred)))
    exclusive?))

(defun removal-eval-required (asent &optional sense)
  (declare (ignore sense))
  (fully-bound-p asent))

(defun removal-eval-expand (asent &optional sense)
  (declare (ignore sense))
  (multiple-value-bind (answer valid? contextualized?)
      (cyc-evaluate asent)
    (when valid?
      (when answer
        (let* ((hl-support-formula (inference-canonicalize-hl-support-literal asent))
               (support (make-eval-support hl-support-formula contextualized?)))
          (removal-add-node support)))))
  nil)

;; (defun removal-not-eval-exclusive (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-not-eval-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-not-eval-expand (asent &optional sense) ...) -- active declareFunction, no body

(deflexical *evaluatable-predicates-to-optimize*
  (list (reader-make-constant-shell "greaterThan")
        (reader-make-constant-shell "greaterThanOrEqualTo")
        (reader-make-constant-shell "quantitySubsumes")))

(deflexical *removal-generic-eval-modules*
  '(:removal-eval :removal-not-eval))

(toplevel
  (inference-removal-module :removal-eval
    (list :sense :pos
          :arity nil
          :required-pattern (cons :fort :anything)
          :exclusive 'removal-eval-exclusive
          :required 'removal-eval-required
          :cost-expression '*default-eval-cost*
          :completeness :complete
          :expand 'removal-eval-expand
          :documentation "(<evaluatable predicate> . <fully bound>)
using (#$evaluationDefn <evaluatable predicate> <symbol>)
and calling the SubL form (<symbol> . <fully bound>)")))

(toplevel
  (inference-removal-module :removal-not-eval
    (list :sense :neg
          :arity nil
          :required-pattern (cons :fort :anything)
          :exclusive 'removal-not-eval-exclusive
          :required 'removal-not-eval-required
          :cost-expression '*default-eval-cost*
          :completeness :complete
          :expand 'removal-not-eval-expand
          :documentation "(#$not (<evaluatable predicate> . <fully bound>))
using (#$evaluationDefn <evaluatable predicate> <symbol>)
and calling the SubL form (<symbol> . <fully bound>)")))

(toplevel
  (inference-preference-module :evaluatable-predicate-delay-until-closed
    (list :sense :pos
          :required-pattern '(:and (:fort . :not-fully-bound)
                                   ((:test inference-evaluatable-predicate?) . :anything))
          :preference-level :disallowed)))

(toplevel
  (dolist (pred *evaluatable-predicates-to-optimize*)
    (register-solely-specific-removal-module-predicate pred)
    (dolist (module *removal-generic-eval-modules*)
      (inference-removal-module-use-generic pred module))))
