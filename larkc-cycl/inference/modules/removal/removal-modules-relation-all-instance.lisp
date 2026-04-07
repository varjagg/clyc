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

(defun removal-some-relation-all-instance-for-predicate (predicate &optional mt)
  (when (fort-p predicate)
    (some-pred-value-in-relevant-mts predicate #$relationAllInstance mt 1)))

;; (defun removal-some-relation-all-instance-for-collection (collection &optional mt) ...) -- active declareFunction, no body
;; (defun removal-some-relation-all-instance-for-value (value &optional mt) ...) -- active declareFunction, no body
;; (defun relation-all-instance-predicate-cost-estimate (predicate) ...) -- active declareFunction, no body
;; (defun relation-all-instance-collection-cost-estimate () ...) -- active declareFunction, no body
;; (defun relation-all-instance-value-cost-estimate (value) ...) -- active declareFunction, no body

(defparameter *estimated-per-collection-removal-all-instance-count* 2)

(defun removal-relation-all-instance-required (asent)
  (let ((predicate (atomic-sentence-predicate asent)))
    (and (not (hl-predicate-p predicate))
         (removal-some-relation-all-instance-for-predicate predicate nil))))

(defparameter *relation-all-instance-rule*
  '(#$implies (#$and (#$relationAllInstance ?PRED ?COL ?VALUE)
                     (#$isa ?OBJ ?COL))
              (?PRED ?OBJ ?VALUE)))

;; (defun make-relation-all-instance-support () ...) -- active declareFunction, no body

(defglobal *relation-all-instance-defining-mt*
  (if (and (boundp '*relation-all-instance-defining-mt*)
           (typep *relation-all-instance-defining-mt* 't))
      *relation-all-instance-defining-mt*
      #$BaseKB))

(defun removal-relation-all-instance-check-required (asent &optional sense)
  (declare (ignore sense))
  (when (removal-relation-all-instance-required asent)
    (let ((value (atomic-sentence-arg2 asent)))
      (or (possibly-naut-p value)
          ;; Likely checks if value is a FORT via fort-p
          (missing-larkc 32612)))))

(defparameter *removal-relation-all-instance-check-cost* 1.5)

;; (defun removal-relation-all-instance-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-check-via-value-expand (value asent) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-check-via-collection-expand (collection asent) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-check-via-predicate-expand (predicate asent) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-check-expand-guts (relation-all-instance-asent asent) ...) -- active declareFunction, no body

(defun removal-relation-all-instance-unify-required (asent &optional sense)
  (declare (ignore sense))
  (when (removal-relation-all-instance-required asent)
    (let ((object (atomic-sentence-arg1 asent)))
      (or (fort-p object)
          (possibly-naut-p object)))))

;; (defun removal-relation-all-instance-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-unify-via-collection-expand (collection asent) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-unify-via-predicate-expand (predicate asent) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-unify-expand-guts (relation-all-instance-asent asent) ...) -- active declareFunction, no body

(defparameter *minimum-relation-all-instance-unify-cost* 2)

(defun removal-relation-all-instance-iterate-required (asent &optional sense)
  (declare (ignore sense))
  (when (removal-relation-all-instance-required asent)
    (let ((object (atomic-sentence-arg2 asent)))
      (declare (ignore object))
      ;; Likely checks if object is a variable via cycl-variable-p
      (missing-larkc 32613))))

;; (defun removal-relation-all-instance-iterate-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-iteration-collections (predicate value) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-iteration-collections-rai (predicate value) ...) -- active declareFunction, no body
;; (defun removal-relation-all-instance-iterate-expand (asent &optional sense) ...) -- active declareFunction, no body

;;; ---- relation-instance-all section ----

(defun removal-some-relation-instance-all-for-predicate (predicate &optional mt)
  (when (fort-p predicate)
    (some-pred-value-in-relevant-mts predicate #$relationInstanceAll mt 1)))

;; (defun removal-some-relation-instance-all-for-value (value &optional mt) ...) -- active declareFunction, no body
;; (defun removal-some-relation-instance-all-for-collection (collection &optional mt) ...) -- active declareFunction, no body
;; (defun relation-instance-all-predicate-cost-estimate (predicate) ...) -- active declareFunction, no body
;; (defun relation-instance-all-collection-cost-estimate () ...) -- active declareFunction, no body
;; (defun relation-instance-all-value-cost-estimate (value) ...) -- active declareFunction, no body

(defparameter *estimated-per-collection-removal-instance-all-count* 2)

(defun removal-relation-instance-all-required (asent)
  (let ((predicate (atomic-sentence-predicate asent)))
    (and (not (hl-predicate-p predicate))
         (removal-some-relation-instance-all-for-predicate predicate nil))))

(deflexical *relation-instance-all-rule*
  '(#$implies (#$and (#$relationInstanceAll ?PRED ?VALUE ?COL)
                     (#$isa ?OBJ ?COL))
              (?PRED ?VALUE ?OBJ)))

;; (defun make-relation-instance-all-support () ...) -- active declareFunction, no body

(defglobal *relation-instance-all-defining-mt*
  (if (and (boundp '*relation-instance-all-defining-mt*)
           (typep *relation-instance-all-defining-mt* 't))
      *relation-instance-all-defining-mt*
      #$BaseKB))

(defun removal-relation-instance-all-check-required (asent &optional sense)
  (declare (ignore sense))
  (when (removal-relation-instance-all-required asent)
    (let ((value (atomic-sentence-arg1 asent)))
      (or (possibly-naut-p value)
          ;; Likely checks if value is a FORT via fort-p
          (missing-larkc 32614)))))

(defparameter *removal-relation-instance-all-check-cost* 1.5)

;; (defun removal-relation-instance-all-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-check-via-value-expand (value asent) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-check-via-collection-expand (collection asent) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-check-via-predicate-expand (predicate asent) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-check-expand-guts (relation-instance-all-asent asent) ...) -- active declareFunction, no body

(defun removal-relation-instance-all-unify-required (asent &optional sense)
  (declare (ignore sense))
  (when (removal-relation-instance-all-required asent)
    (let ((object (atomic-sentence-arg2 asent)))
      (or (fort-p object)
          (possibly-naut-p object)))))

;; (defun removal-relation-instance-all-unify-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-unify-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-unify-via-predicate-expand (predicate asent) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-unify-via-collection-expand (collection asent) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-unify-expand-guts (relation-instance-all-asent asent) ...) -- active declareFunction, no body

(defparameter *minimum-relation-instance-all-unify-cost* 2)

(defun removal-relation-instance-all-iterate-required (asent &optional sense)
  (declare (ignore sense))
  (when (removal-relation-instance-all-required asent)
    (let ((object (atomic-sentence-arg1 asent)))
      (declare (ignore object))
      ;; Likely checks if object is a variable via cycl-variable-p
      (missing-larkc 32615))))

;; (defun removal-relation-instance-all-iterate-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-iteration-collections (predicate object) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-iteration-collections-ria (predicate object) ...) -- active declareFunction, no body
;; (defun removal-relation-instance-all-iterate-expand (asent &optional sense) ...) -- active declareFunction, no body

;;; ---- toplevel setup ----

(toplevel
  (declare-defglobal '*relation-all-instance-defining-mt*))

(toplevel
  (note-mt-var '*relation-all-instance-defining-mt* #$relationAllInstance))

(toplevel
  (inference-removal-module :removal-relation-all-instance-check
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :fully-bound :fully-bound)
          :required 'removal-relation-all-instance-check-required
          :cost-expression '*removal-relation-all-instance-check-cost*
          :expand 'removal-relation-all-instance-check-expand
          :documentation "(<predicate> <object> <value>) where <object> and <value> are FORTs or NAUTs
from (#$relationAllInstance <predicate> <collection> <value>)
and (#$isa <arg1> <collection>)"
          :example "(#$hasGender #$AbrahamLincoln #$Masculine)
from (#$relationAllInstance #$hasGender #$MalePerson #$Masculine)
and (#$isa #$AbrahamLincoln #$MalePerson)
(#$duration (#$YearFn 2001) (#$YearsDuration 1))
from (#$relationAllInstance #$duration #$CalendarYear (#$YearsDuration 1))
and (#$isa (#$YearFn 2001) #$CalendarYear)")))

(toplevel
  (inference-removal-module :removal-relation-all-instance-unify
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :anything :not-fully-bound)
          :required 'removal-relation-all-instance-unify-required
          :cost 'removal-relation-all-instance-unify-cost
          :expand 'removal-relation-all-instance-unify-expand
          :documentation "(<predicate> <object> <non-fort>) where <object> is a FORT or NAUT
from (#$relationAllInstance <predicate> <collection> <value>)
and (#$isa <object> <collection>)"
          :example "(#$hasGender #$AbrahamLincoln ?GENDER)
from (#$relationAllInstance #$hasGender #$MalePerson #$Masculine)
and (#$isa #$AbrahamLincoln #$MalePerson)
(#$duration (#$YearFn 2001) ?TIME)
from (#$relationAllInstance #$duration #$CalendarYear (#$YearsDuration 1))
and (#$isa (#$YearFn 2001) #$CalendarYear)")))

(toplevel
  (inference-removal-module :removal-relation-all-instance-iterate
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :not-fully-bound :fort)
          :required 'removal-relation-all-instance-iterate-required
          :cost 'removal-relation-all-instance-iterate-cost
          :completeness :incomplete
          :expand 'removal-relation-all-instance-iterate-expand
          :documentation "(<predicate> <non-fort> <object>) where <object> is a FORT
 from (#$relationAllInstance <predicate> <collection> <object>)"
          :example "(#$hasGender ?WHO #$Masculine)
 from (#$relationAllInstance #$hasGender #$MalePerson #$Masculine)")))

(toplevel
  (declare-defglobal '*relation-instance-all-defining-mt*))

(toplevel
  (note-mt-var '*relation-instance-all-defining-mt* #$relationInstanceAll))

(toplevel
  (inference-removal-module :removal-relation-instance-all-check
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :fully-bound :fully-bound)
          :required 'removal-relation-instance-all-check-required
          :cost-expression '*removal-relation-instance-all-check-cost*
          :expand 'removal-relation-instance-all-check-expand
          :documentation "(<predicate> <object> <value>) where <object> and <value> are FORTs or NAUTs
from (#$relationInstanceAll <predicate> <collection> <value>)
and (#$isa <arg1> <collection>)"
          :example "(#$hasGender #$AbrahamLincoln #$Masculine)
from (#$relationInstanceAll #$hasGender #$MalePerson #$Masculine)
and (#$isa #$AbrahamLincoln #$MalePerson)
(#$duration (#$YearFn 2001) ?TIME)
from (#$relationInstanceAll #$duration #$CalendarYear (#$YearsDuration 1))
and (#$isa (#$YearFn 2001) #$CalendarYear)")))

(toplevel
  (inference-removal-module :removal-relation-instance-all-unify
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :not-fully-bound :anything)
          :required 'removal-relation-instance-all-unify-required
          :cost 'removal-relation-instance-all-unify-cost
          :expand 'removal-relation-instance-all-unify-expand
          :documentation "(<predicate> <whatever> <fort or naut>)
from (#$relationInstanceAll <predicate> <value> <collection>)
and (#$isa <fort> <collection>)")))

(toplevel
  (inference-removal-module :removal-relation-instance-all-iterate
    (list :sense :pos
          :arity 2
          :required-pattern '(:fort :fort :not-fully-bound)
          :required 'removal-relation-instance-all-iterate-required
          :cost 'removal-relation-instance-all-iterate-cost
          :completeness :incomplete
          :expand 'removal-relation-instance-all-iterate-expand
          :documentation "(<predicate> <object> <non-fort>) where <object> is a FORT
 from (#$relationInstanceAll <predicate> <object> <collection>)
 by iterating over <collection>"
          :example "(subsetOf TheEmptySet ?WHAT)
 from
   (relationInstanceAll subsetOf TheEmptySet SetOrCollection)")))
