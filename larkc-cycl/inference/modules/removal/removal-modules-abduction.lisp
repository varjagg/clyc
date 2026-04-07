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

(deflexical *abductive-removal-modules* '(:removal-abduction-pos-unify
                                          :removal-abduction-pos-check
                                          :removal-exclusive-abduction-pos)
  "[Cyc] The exhaustive list all abductive removal modules.")

(defglobal *abduction-term-isg* (new-integer-sequence-generator)
  "[Cyc] The id uniqueifer for abduced terms.")

(defparameter *abduce-subcollection-denoting-terms?* nil)

;; (defun abductive-removal-modules () ...) -- active declareFunction, no body
;; (defun abductive-removal-module? (module) ...) -- active declareFunction, no body
;; (defun abductive-modules-not-allowed-spec () ...) -- active declareFunction, no body
;; (defun problem-store-next-abduced-term-id (problem-store) ...) -- active declareFunction, no body
;; (defun abducing-completely-enumerable-instances? (asent mt) ...) -- active declareFunction, no body
;; (defun candidate-abductive-binding-sets (asent sense mt) ...) -- active declareFunction, no body
;; (defun abduced-collection-for-constraints (constraints problem-store mt) ...) -- active declareFunction, no body
;; (defun abduced-individual-for-constraints (constraints problem-store) ...) -- active declareFunction, no body
;; (defun abduced-term-for-constraints (constraints type problem-store mt) ...) -- active declareFunction, no body
;; (defun abduced-type-from-constraints (constraints) ...) -- active declareFunction, no body
;; (defun abductive-asent-var-arg-constraints (asent var) ...) -- active declareFunction, no body

(defun removal-abduction-required (asent sense)
  (removal-abduction-allowed? asent sense))

(defun removal-abduction-allowed? (asent &optional (sense :pos))
  (let ((problem-store (currently-active-problem-store))
        (mt *mt*))
    (declare (ignore asent mt))
    (and problem-store
         (problem-store-abduction-allowed? problem-store)
         ;; Likely checks whether abduction is allowed for the given asent/sense/mt combination
         (missing-larkc 33026))))

(deflexical *default-abduction-cost* 0)

;; (defun removal-abduction-check-sentence (asent sense mt) ...) -- active declareFunction, no body
;; (defun make-abduction-support (sentence &optional mt tv) ...) -- active declareFunction, no body

(defun removal-abduction-pos-required (asent &optional sense)
  (removal-abduction-required asent sense))

;; (defun removal-abduction-pos-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-abduction-unify-sentence (asent sense bindings mt) ...) -- active declareFunction, no body
;; (defun removal-abduction-pos-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-abduction-exclusive? (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-exclusive-abduction-pos-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-abduction-neg-required (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-abduction-neg-check-expand (asent &optional sense) ...) -- active declareFunction, no body

(toplevel
  (declare-defglobal '*abduction-term-isg*))

(toplevel
  (inference-removal-module :removal-abduction-pos-check
    (list :module-subtype :abduction
          :sense :pos
          :required-pattern '(:fort . :fully-bound)
          :required 'removal-abduction-pos-required
          :cost-expression '*default-abduction-cost*
          :completeness :grossly-incomplete
          :expand 'removal-abduction-pos-check-expand
          :documentation "(<fort> . <whatever>) where the asent is deemed abducible,
    and the problem store allows abduction"
          :example "(#$competitors #$GeorgeWBush #$BillClinton)")))

(toplevel
  (inference-removal-module :removal-abduction-pos-unify
    (list :module-subtype :abduction
          :sense :pos
          :required-pattern '(:and (:fort . :anything)
                                   (:not (:fort . :fully-bound)))
          :required 'removal-abduction-pos-required
          :cost-expression '*default-abduction-cost*
          :completeness :grossly-incomplete
          :expand 'removal-abduction-pos-unify-expand
          :documentation "(<fort> . <whatever>) where the asent is deemed abducible,
    and the problem store allows abduction"
          :example "(#$brothers #$GeorgeWBush ?BROTHER)")))

(toplevel
  (inference-removal-module :removal-exclusive-abduction-pos
    (list :module-subtype :abduction
          :sense :pos
          :required-pattern `(:and (:fort . :anything)
                                   (:tree-find ,#$AbducedTermFn))
          :exclusive 'removal-abduction-exclusive?
          :required 'removal-abduction-pos-required
          :cost-expression '*default-abduction-cost*
          :completeness :complete
          :expand 'removal-exclusive-abduction-pos-expand
          :documentation "apply only abduction on (<fort> . <whatever>) where the asent has an abduced term"
          :example "(#$brothers #$GeorgeWBush (#$AbducedTermFn (#$CycProblemStoreFn 1388) #$MaleAnimal 2))")))

(toplevel
  (inference-removal-module :removal-abduction-neg-check
    (list :module-subtype :abduction
          :sense :neg
          :required-pattern '(:fort . :fully-bound)
          :required 'removal-abduction-neg-required
          :cost-expression '*default-abduction-cost*
          :completeness :grossly-incomplete
          :expand 'removal-abduction-neg-check-expand
          :documentation "(#$not (<fort> . <fully-bound>)) where the asent is deemed abducible,
    and the problem store allows abduction"
          :example "(#$not (#$competitors #$GeorgeWBush #$BillClinton))")))
