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

;; Memoized wrapper collapses memoized-problem-max-removal-productivity-internal
;; + memoized-problem-max-removal-productivity + note-memoized-function into a
;; single defun-memoized.  The Java internal function just delegates to
;; problem-max-removal-productivity, so the body is that delegation.
(defun-memoized memoized-problem-max-removal-productivity (problem strategic-context) (:test eq)
  (problem-max-removal-productivity problem strategic-context))

(defun problem-max-removal-productivity (problem strategic-context)
  ;; When strategic-context is a balancing-tactician, the Java dispatches to a
  ;; missing-larkc method (33093) that presumably unwraps the underlying strategy.
  (when (balancing-tactician-p strategic-context)
    (setf strategic-context (missing-larkc 33093)))
  (let* ((existing-proof-count (problem-proof-count problem))
         (productivity-from-existing-proofs (productivity-for-number-of-children existing-proof-count))
         (max-productivity productivity-from-existing-proofs)
         (max-justification problem)
         (tactics (problem-relevant-tactics-wrt-removal problem strategic-context)))
    (dolist (tactic tactics)
      (multiple-value-bind (max-lookahead-productivity max-lookahead-justification)
          (tactic-max-removal-productivity tactic strategic-context)
        (when (productivity-> max-lookahead-productivity max-productivity)
          (setf max-productivity max-lookahead-productivity)
          (setf max-justification max-lookahead-justification))))
    (values max-productivity max-justification)))

(defun tactic-max-removal-productivity (tactic strategic-context)
  (cond ((or (generalized-removal-tactic-p tactic)
             (rewrite-tactic-p tactic))
         (values (tactic-original-productivity tactic) tactic))
        ((logical-tactic-with-unique-lookahead-problem-p tactic)
         (let ((lookahead-problem (logical-tactic-lookahead-problem tactic)))
           (problem-max-removal-productivity lookahead-problem strategic-context)))
        ((join-tactic-p tactic)
         (multiple-value-bind (first-problem second-problem)
             (join-tactic-lookahead-problems tactic)
           (multiple-value-bind (first-productivity first-justification)
               (problem-max-removal-productivity first-problem strategic-context)
             (multiple-value-bind (second-productivity second-justification)
                 (problem-max-removal-productivity second-problem strategic-context)
               (if (productivity-> second-productivity first-productivity)
                   (values second-productivity second-justification)
                   (values first-productivity first-justification))))))
        ((meta-split-tactic-p tactic)
         (values 0 tactic))
        (t
         (error "Unexpected removal-relevant tactic ~S" tactic))))

(defun problem-relevant-tactics-wrt-removal (problem strategic-context)
  (determine-strategic-status-wrt problem strategic-context)
  (if (eq :tactical strategic-context)
      ;; Likely calls a tactical method for getting removal-relevant tactics
      (missing-larkc 36532)
      (strategy-relevant-tactics-wrt-removal strategic-context problem)))

(defun strategy-relevant-tactics-wrt-removal (strategy problem)
  (strategy-dispatch strategy :relevant-tactics-wrt-removal problem))

;; Orphan $kw5 = :REMOVAL was likely used in this function's body
;; (defun problem-tactically-relevant-tactics-wrt-removal (problem) ...) -- active declareFunction, no body
