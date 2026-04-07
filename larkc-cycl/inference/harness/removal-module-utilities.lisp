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

;; (defun negation-grossly-incomplete? (asent sense) ...) -- active declareFunction, no body
;; (defun invert-removal-check-cost (cost) ...) -- active declareFunction, no body

(defun answer-to-singleton (answer)
  "[Cyc] Return a singleton answer list with ANSWER as the sole item."
  (list answer))

(defun non-null-answer-to-singleton (answer)
  "[Cyc] If ANSWER is non-nil, return a singleton answer list with ANSWER as the sole item.
Otherwise, return an empty answer list."
  (if answer
      (answer-to-singleton answer)
      nil))

;; (defun invert-boolean-answer (answer) ...) -- active declareFunction, no body

(defun additional-isa-support (object collection)
  (let* ((hl-formula (list #$isa object collection))
         (hl-support (make-hl-support :isa hl-formula)))
    hl-support))

(defun additional-isa-supports (object collection)
  (list (additional-isa-support object collection)))

;; (defun make-genl-inverse-support (spec-pred genl-pred) ...) -- active declareFunction, no body
;; (defun additional-genl-inverse-supports (spec-pred genl-pred) ...) -- active declareFunction, no body

(defun make-genl-preds-support (spec-pred genl-pred)
  (let* ((hl-formula (list #$genlPreds spec-pred genl-pred))
         (hl-support (make-hl-support :genlpreds hl-formula)))
    hl-support))

;; (defun additional-genl-preds-supports (spec-pred genl-pred) ...) -- active declareFunction, no body
;; (defun make-simplification-support () ...) -- active declareFunction, no body
;; (defun hl-module-count () ...) -- active declareFunction, no body
;; (defun hl-module-statistics (&optional stream) ...) -- active declareFunction, no body
;; (defun determine-hl-module-name (sense string) ...) -- active declareFunction, no body
;; (defun make-removal-module-name (string) ...) -- active declareFunction, no body

(defun current-query-allows-new-terms? ()
  (let ((store (currently-active-problem-store)))
    (if store
        (problem-store-new-terms-allowed? store)
        (current-query-property-lookup :new-terms-allowed?))))

(deflexical *modules-require-negation-by-failure*
  '(:removal-not-isa-collection-check
    :removal-not-quoted-isa-collection-check
    :removal-not-conceptually-related
    :removal-not-disjointwith-check
    :removal-not-genlinverse-check
    :removal-not-genlmt-check
    :removal-not-genlpreds-check
    :removal-not-superset
    :removal-minimize-extent
    :removal-not-negationinverse-check
    :removal-not-negationpreds-check
    :removal-not-starts-after-starting-of
    :removal-not-starts-after-ending-of
    :removal-not-ends-after-starting-of
    :removal-not-ends-after-ending-of
    :removal-not-temporally-subsumes
    :removal-not-date-of-event
    :removal-not-cotemporal
    :removal-not-temporally-intersects
    :removal-not-temporally-disjoint
    :removal-not-temporal-bounds-contain
    :removal-not-temporal-bounds-subsume
    :removal-not-temporal-bounds-intersect
    :removal-not-temporal-bounds-identical
    :removal-not-temporally-cooriginating
    :removal-not-temporally-coterminal
    :removal-not-contiguous-after
    :removal-not-starts-during
    :removal-not-ends-during
    :removal-not-starting-date
    :removal-not-ending-date
    :removal-not-birth-date
    :removal-not-date-of-death
    :removal-not-temporally-started-by
    :removal-not-temporally-finished-by
    :removal-not-overlaps-start))

;; (defun module-requires-negation-by-failure? (module) ...) -- active declareFunction, no body

(deflexical *completeness-minimization-required-modules*
  '((:removal-not-isa-collection-check . :isa)
    (:removal-isa-defn-reject . :isa)
    (:removal-not-quoted-isa-collection-check . :isa)
    (:removal-quoted-isa-defn-reject . :isa)
    (:removal-completely-decidable-neg . :minimize)))

;; (defun module-requires-completeness-minimization-for-support? (module support) ...) -- active declareFunction, no body

(deflexical *new-terms-allowed-required-modules*
  '(:removal-skolemize-create
    :removal-relation-all-exists-unify
    :removal-relation-exists-all-unify
    :removal-relation-instance-exists-unify-arg1
    :removal-relation-instance-exists-unify-arg2
    :removal-relation-instance-exists-unbound-arg1
    :removal-relation-instance-exists-unbound-arg2
    :removal-relation-exists-instance-unify-arg1
    :removal-relation-exists-instance-unify-arg2
    :removal-relation-exists-instance-unbound-arg1
    :removal-relation-exists-instance-unbound-arg2))

;; (defun module-requires-new-terms-allowed? (module) ...) -- active declareFunction, no body

(deflexical *evaluate-subl-required-modules*
  '(:removal-perform-subl-pos
    :removal-perform-subl-neg))

;; (defun module-requires-evaluate-subl? (module) ...) -- active declareFunction, no body
