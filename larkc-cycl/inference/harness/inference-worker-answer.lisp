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

(defun answer-link-p (object)
  (and (problem-link-p object)
       (eq :answer (problem-link-type object))))

(defun new-answer-link (inference)
  "[Cyc] Creates a new answer link under INFERENCE.
An :answer link is special because it supports an inference (namely, INFERENCE)
rather than a problem."
  (declare (type (satisfies inference-p) inference))
  (let ((answer-link (new-answer-link-int inference)))
    (set-inference-root-link inference answer-link)
    answer-link))

(defun new-answer-link-int (inference)
  (let ((explanatory-subquery (inference-explanatory-subquery inference))
        (answer-link (new-problem-link-int inference :answer)))
    (set-answer-link-explanatory-subquery answer-link explanatory-subquery)
    answer-link))

(defun answer-link-supported-inference (answer-link)
  (declare (type (satisfies answer-link-p) answer-link))
  (problem-link-supported-object answer-link))

(defun answer-link-propagated? (answer-link)
  "[Cyc] @note this will return NIL if ANSWER-LINK gets closed later, after propagation."
  (declare (type (satisfies answer-link-p) answer-link))
  (problem-link-sole-supporting-mapped-problem-open? answer-link))

(defun answer-link-supporting-mapped-problem (answer-link)
  (declare (type (satisfies answer-link-p) answer-link))
  (problem-link-first-supporting-mapped-problem answer-link))

(defun answer-link-explanatory-subquery (answer-link)
  (declare (type (satisfies answer-link-p) answer-link))
  (problem-link-data answer-link))

(defun set-answer-link-explanatory-subquery (answer-link subquery)
  (declare (type (satisfies answer-link-p) answer-link)
           (type (satisfies explanatory-subquery-spec-p) subquery))
  (set-problem-link-data answer-link subquery)
  answer-link)

(defun note-answer-link-propagated (answer-link)
  (declare (type (satisfies answer-link-p) answer-link))
  (problem-link-open-sole-supporting-mapped-problem answer-link)
  answer-link)

(defun answer-link-supporting-problem (answer-link)
  (let ((mapped-problem (answer-link-supporting-mapped-problem answer-link)))
    (mapped-problem-problem mapped-problem)))

(defun answer-link-supporting-problem-wholly-explanatory? (answer-link)
  (eq :all (answer-link-explanatory-subquery answer-link)))
