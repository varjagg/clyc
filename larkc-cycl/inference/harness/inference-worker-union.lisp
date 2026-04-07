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

(defun union-link-p (object)
  (and (problem-link-p object)
       (eq :union (problem-link-type object))))

;; (defun maybe-new-union-link (problem disjuncts) ...) -- active declareFunction, no body
;; (defun new-union-link (problem disjuncts) ...) -- active declareFunction, no body
;; (defun destroy-union-link (link) ...) -- active declareFunction, no body
;; (defun union-link-supporting-problem (link) ...) -- active declareFunction, no body
;; (defun union-link-tactic (link) ...) -- active declareFunction, no body

(defparameter *union-module* (inference-structural-module :union))

(defun union-tactic-p (object)
  (and (tactic-p object)
       (eq *union-module* (tactic-hl-module object))))

;; (defun new-union-tactic (link disjunct-index) ...) -- active declareFunction, no body
;; (defun union-tactic-disjunct-index (tactic) ...) -- active declareFunction, no body
;; (defun union-tactic-link (tactic) ...) -- active declareFunction, no body
;; (defun find-or-create-union-tactic-disjunct-mapped-problem (tactic) ...) -- active declareFunction, no body
;; (defun find-or-create-union-link-supporting-mapped-problem (link variable-map) ...) -- active declareFunction, no body
;; (defun determine-new-union-tactics (link strategy) ...) -- active declareFunction, no body
;; (defun compute-strategic-properties-of-union-tactic (tactic strategy problem) ...) -- active declareFunction, no body
;; (defun compute-union-tactic-productivity (tactic strategy problem) ...) -- active declareFunction, no body
;; (defun compute-union-tactic-preference-level (tactic strategy problem) ...) -- active declareFunction, no body

(deflexical *union-tactic-preference-level* :preferred
  "[Cyc] The preference level used for union tactics.
Union tactics are independent of each other, so no bindings from one half
could possibly make the other half any more solvable.
Hence, all union tactics should be preferred.")

(deflexical *union-tactic-preference-level-justification* :preferred
  "[Cyc] the preference level for all union tactics")

;; (defun union-tactic-lookahead-problem (tactic) ...) -- active declareFunction, no body
;; (defun execute-union-tactic (tactic) ...) -- active declareFunction, no body
;; (defun new-union-proof (link supporting-proof variable-map) ...) -- active declareFunction, no body
;; (defun bubble-up-proof-to-union-link (link supporting-proof variable-map) ...) -- active declareFunction, no body

(defun disjunctive-assumption-link-p (object)
  (and (problem-link-p object)
       (eq :disjunctive-assumption (problem-link-type object))))

(defparameter *disjunction-assumption-module* (inference-structural-module :disjunctive-assumption))

(defun disjunctive-assumption-tactic-p (object)
  (and (tactic-p object)
       (eq *disjunction-assumption-module* (tactic-hl-module object))))
