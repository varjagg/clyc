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

(defun meta-removal-complete-pos-required ()
  (let ((problem (currently-active-problem)))
    (when problem
      (and (problem-has-possible-removal-tactic? problem :tactical)
           (not (problem-has-complete-possible-removal-tactic? problem :tactical))))))

;; (defun meta-removal-complete-pos-cost (asent &optional sense) ...) -- active declareFunction, no body

(defun meta-removal-completely-enumerable-pos-required (asent &optional sense)
  (declare (ignore sense))
  (and (meta-removal-complete-pos-required)
       (inference-completely-enumerable-asent? asent (inference-relevant-mt))))

(defun meta-removal-completely-decidable-pos-required (asent &optional sense)
  (declare (ignore sense))
  (and (meta-removal-complete-pos-required)
       (inference-completely-decidable-asent? asent (inference-relevant-mt))))

(toplevel
  (inference-meta-removal-module :meta-removal-completely-enumerable-pos
    (list :sense :pos
          :required-pattern (cons :fort :not-fully-bound)
          :required 'meta-removal-completely-enumerable-pos-required
          :cost 'meta-removal-complete-pos-cost
          :completeness :complete
          :documentation "(<predicate> . <not fully bound>))
    via indirection, by execution of other tactics on the problem
    and completeness meta-knowledge about the sentence."
          :example "(#$borderingCountries #$Canada ?WHAT)
    given other tactics to solve this and
    (#$completeExtentEnumerable #$borderingCountries)")))

(toplevel
  (inference-meta-removal-module :meta-removal-completely-decidable-pos
    (list :sense :pos
          :required-pattern (cons :fort :fully-bound)
          :required 'meta-removal-completely-decidable-pos-required
          :cost 'meta-removal-complete-pos-cost
          :completeness :complete
          :documentation "(<predicate> . <fully bound>))
    via indirection, by execution of other tactics on the problem
    and completeness meta-knowledge about the sentence."
          :example "(#$borderingCountries #$Canada #$Mexico)
    given other tactics to solve this and
    (#$completeExtentDecidable #$borderingCountries)")))
