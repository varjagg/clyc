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

;; Internal Constants accounting:
;;   $sym0$EL_MEETS_PRAGMATIC_REQUIREMENT_P — used in postcanonicalizations-int
;;   $kw1$IGNORE — used in postcanonicalizations-int
;;   $kw2$DISJUNCT_IN_PRAGMATIC_REQUIREMENT — orphan, likely used in commented-out postcanonicalize-possible-disjunction
;;   $list3 = (NEG-LITS POS-LITS) — orphan, likely destructuring-bind list in commented-out transform-dnf-and-binding-list-to-negated-el

(defun postcanonicalizations (sentence mt)
  "[Cyc] @return 0 EL sentence
@return 1 mt
Performs some canonicalizations which could not be handled by the canonicalizer.
Canonicalizes the pragmatic requirement condition as a high level query."
  (postcanonicalizations-int sentence mt))

(defun postcanonicalizations-int (sentence mt)
  "[Cyc] @return 0 EL sentence
@return 1 mt"
  (if (not (tree-find-if #'el-meets-pragmatic-requirement-p
                         (sentence-args sentence)))
      (values sentence mt)
      (progn
        (cond
          ((el-conjunction-p sentence)
           (let ((conjuncts nil))
             (cdolist (conjunct (formula-args sentence :ignore))
               (push
                ;; missing-larkc 8556: likely calls postcanonicalize-possible-disjunction
                ;; on each conjunct with mt, to handle pragmatic requirements within
                ;; individual conjuncts that might be disjunctions
                (missing-larkc 8556)
                conjuncts))
             (setf sentence (make-conjunction (nreverse conjuncts)))))
          ((el-disjunction-p sentence)
           ;; missing-larkc 8557: likely calls postcanonicalize-possible-disjunction
           ;; on the entire disjunctive sentence with mt, to handle pragmatic
           ;; requirements within disjunctions
           (setf sentence (missing-larkc 8557))))
        (values sentence mt))))

;; (defun postcanonicalize-possible-disjunction (sentence mt) ...) -- no body, commented declareFunction
;; (defun transform-dnf-and-binding-list-to-negated-el (dnf-and-binding-list) ...) -- no body, commented declareFunction
