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

(defun canonicalize-clauses-wrt-rule-macros (v-clauses)
  "[Cyc] If CLAUSES or its elements match certain hard-coded patterns, they are converted to rule macros.
Otherwise they are left alone."
  (if (not *express-as-rule-macro?*)
      v-clauses
      (if (missing-larkc 3759)
          (missing-larkc 3755)
          (if (missing-larkc 3757)
              (missing-larkc 3754)
              (mapcar #'canonicalize-clause-wrt-rule-macros v-clauses)))))

;; (defun required-arg-pred-clauses? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-required-arg-pred (arg1) ...) -- no body, commented declareFunction
;; (defun required-arg-pred (arg1) ...) -- no body, commented declareFunction
;; (defun relation-type-clauses? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-relation-type (arg1) ...) -- no body, commented declareFunction
;; (defun relation-type-pred (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun relation-type-gaf (arg1 arg2 arg3 arg4 &optional arg5) ...) -- no body, commented declareFunction
;; (defun canonicalize-clause-wrt-rule-macros (arg1) ...) -- no body, commented declareFunction
;; (defun genls-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-genls (arg1) ...) -- no body, commented declareFunction
;; (defun genl-predicates-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-genl-predicates (arg1) ...) -- no body, commented declareFunction
;; (defun genl-inverse-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-genl-inverse (arg1) ...) -- no body, commented declareFunction
;; (defun arg-isa-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun relevant-arg-of-isa-clause (arg1 arg2 &optional arg3) ...) -- no body, commented declareFunction
;; (defun express-as-arg-isa (arg1) ...) -- no body, commented declareFunction
;; (defun arg-genl-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-arg-genl (arg1) ...) -- no body, commented declareFunction
;; (defun inter-arg-isa-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-inter-arg-isa (arg1) ...) -- no body, commented declareFunction
;; (defun disjoint-with-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-disjoint-with (arg1) ...) -- no body, commented declareFunction
;; (defun negation-preds-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-negation-preds (arg1) ...) -- no body, commented declareFunction
;; (defun negation-inverse-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-negation-inverse (arg1) ...) -- no body, commented declareFunction
;; (defun reflexive-predicate-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun reflexive-neg-lits? (arg1 arg2 arg3 &optional arg4) ...) -- no body, commented declareFunction
;; (defun express-as-reflexive-predicate (arg1) ...) -- no body, commented declareFunction
;; (defun irreflexive-predicate-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-irreflexive-predicate (arg1) ...) -- no body, commented declareFunction
;; (defun transitive-predicate-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-transitive-predicate (arg1) ...) -- no body, commented declareFunction
;; (defun symmetric-predicate-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun symmetric-literals? (arg1 arg2 &optional arg3) ...) -- no body, commented declareFunction
;; (defun express-as-symmetric-predicate (arg1) ...) -- no body, commented declareFunction
;; (defun asymmetric-predicate-clause? (arg1 &optional arg2) ...) -- no body, commented declareFunction
;; (defun express-as-asymmetric-predicate (arg1) ...) -- no body, commented declareFunction
;; (defun make-rm-cnf (arg1 &optional arg2) ...) -- no body, commented declareFunction
