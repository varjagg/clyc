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

(defun current-problem-store-transformation-allowed? (&optional dummy)
  (declare (ignore dummy))
  (let ((store (currently-active-problem-store)))
    (and store
         (problem-store-transformation-allowed? store))))

;; (defun inference-backchain-forbidden-unless-arg-chosen-asent-in-relevant-mt? (asent) ...) -- active declareFunction, no body
;; (defun removal-backchain-required-prune-required (asent &optional sense) ...) -- active declareFunction, no body

(defun inference-backchain-required-asent-in-relevant-mt? (asent &optional sense)
  "[Cyc] A version of @xref inference-backchain-required-asent? that assumes *mt*"
  (declare (ignore sense))
  (inference-backchain-required-asent? asent *mt*))

(toplevel
  (inference-preference-module :backchain-required-pos
    (list :sense :pos
          :required-pattern (list :test 'inference-backchain-required-asent-in-relevant-mt?)
          :preference-level :preferred
          :supplants :all)))

(toplevel
  (inference-preference-module :backchain-forbidden-unless-arg-chosen-delay
    (list :sense :pos
          :required-pattern (list :and
                                  (list :test 'current-problem-store-transformation-allowed?)
                                  (cons :fort :anything)
                                  (list :test 'inference-backchain-required-asent-in-relevant-mt?)
                                  (list :test 'inference-backchain-forbidden-unless-arg-chosen-asent-in-relevant-mt?))
          :preference-level :disallowed)))

(toplevel
  (inference-removal-module :removal-backchain-required-prune
    (list :sense :pos
          :required-pattern (list :test 'inference-backchain-required-asent-in-relevant-mt?)
          :required 'removal-backchain-required-prune-required
          :exclusive t
          :cost-expression 0
          :completeness :incomplete
          :documentation "(<fort> . <whatever>)
    in all cases where <fort> is #$backchainRequired should immediately fail."
          :example "(#$sentenceTruth (#$isa ?X #$Integer))")))

(toplevel
  (note-funcall-helper-function 'removal-backchain-required-prune-required))

(toplevel
  (note-funcall-helper-function 'inference-backchain-required-asent-in-relevant-mt?))
