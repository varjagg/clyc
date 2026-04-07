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

(defun removal-some-relation-all-for-predicate (predicate &optional mt)
  (when (fort-p predicate)
    (some-pred-value-in-relevant-mts predicate #$relationAll mt 1)))

;; (defun removal-some-relation-all-for-collection (collection &optional mt) ...) -- active declareFunction, no body

;; (defun relation-all-predicate-cost-estimate (predicate) ...) -- active declareFunction, no body
;; (defun relation-all-collection-cost-estimate () ...) -- active declareFunction, no body

(defparameter *estimated-per-collection-relation-all-fraction* 10)

(defun removal-relation-all-required (asent)
  (let ((predicate (atomic-sentence-predicate asent)))
    (and (not (hl-predicate-p predicate))
         (removal-some-relation-all-for-predicate predicate nil))))

(deflexical *relation-all-rule*
  '(#$implies (#$and (#$relationAll ?PRED ?COL)
                     (#$isa ?OBJ ?COL))
              (?PRED ?OBJ)))

;; (defun make-relation-all-support () ...) -- active declareFunction, no body

(defglobal *relation-all-defining-mt*
  (if (and (boundp '*relation-all-defining-mt*)
           (typep *relation-all-defining-mt* 't))
      *relation-all-defining-mt*
      #$BaseKB))

(defun removal-relation-all-check-required (asent &optional sense)
  (declare (ignore sense))
  (removal-relation-all-required asent))

(defparameter *removal-relation-all-check-cost* 1.5)

;; (defun removal-relation-all-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-relation-all-check-via-collection-expand (collection asent) ...) -- active declareFunction, no body
;; (defun removal-relation-all-check-via-predicate-expand (predicate asent) ...) -- active declareFunction, no body
;; (defun removal-relation-all-check-expand-guts (relation-all-asent asent) ...) -- active declareFunction, no body
;; (defun unary-pred-holds (pred arg &optional mt) ...) -- active declareFunction, no body
;; (defun unary-pred-holds-via-relation-all (pred arg &optional mt) ...) -- active declareFunction, no body

(toplevel
  (declare-defglobal '*relation-all-defining-mt*))

(toplevel
  (note-mt-var '*relation-all-defining-mt* #$relationAll))

(toplevel
  (inference-removal-module :removal-relation-all-check
    (list :sense :pos
          :arity 1
          :required-pattern '(:fort :fort)
          :required 'removal-relation-all-check-required
          :cost-expression '*removal-relation-all-check-cost*
          :expand 'removal-relation-all-check-expand
          :documentation "(< predicate> <object>) where <object> is a FORT
from (#$relationAll <predicate> <collection>)
and (#$isa <object> <collection>)"
          :example "(#$temporallyContinuous #$AbrahamLincoln)
from (#$relationAll #$temporallyContinuous #$Entity)
and (#$isa #$AbrahamLincoln #$Entity)")))
