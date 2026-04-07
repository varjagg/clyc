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

(defparameter *check-wff-constants?* t)
(defparameter *check-wff-semantics?* t)
(defparameter *check-wff-coherence?* nil)
(defparameter *check-arg-types?* t)
(defparameter *check-var-types?* t)
(defparameter *check-arity?* t)
(defparameter *use-cycl-grammar-if-semantic-checking-disabled?* t
  "[Cyc] Whether to use a totally syntactic wff-check if all semantic wff-checking is disabled.")

;; (defun assertion-not-wff? (assertion) ...) -- active declaration, no body
;; (defun set-dont-check-wff-semantics () ...) -- active declaration, no body
;; (defun set-check-wff-semantics () ...) -- active declaration, no body

(defun check-assertible-literal? ()
  "[Cyc] Should we check literals for assertibility?"
  (within-assert?))

(defun mal-mt-spec? (mt)
  (not (valid-mt-spec? mt)))

(defun valid-mt-spec? (mt)
  (or (hlmt-p mt)
      (and (null mt)
           (all-mts-are-relevant?))))

(defun wf-fort-p (object)
  "[Cyc] T iff OBJECT is a well-formed fort.
Notes a wff violation if OBJECT is an invalid fort."
  (cond ((valid-fort? object) t)
        ((not (fort-p object)) nil)
        (t (when *within-wff?*
             (note-wff-violation (list :mal-fort object)))
           nil)))

(defun non-wf-fort-p (object)
  "[Cyc] T iff OBJECT is an ill-formed fort.
Notes a wff violation if OBJECT is an invalid fort."
  (and (fort-p object)
       (not (wf-fort-p object))))

(defun non-wf-variable-p (object)
  "[Cyc] T iff OBJECT is an invalid el-var."
  (and (el-var? object)
       (not (valid-el-var? object))))

(defun mal-variables? (sentence)
  "[Cyc] T if SENTENCE has any invalid el-vars."
  (expression-find-if #'non-wf-variable-p sentence))

;; (defun mal-variables (sentence) ...) -- active declaration, no body
;; (defun non-wff-cached-p (assertion) ...) -- active declaration, no body
;; (defun wff-check-assertion (assertion) ...) -- active declaration, no body
;; (defun wff-check-assertions-via-tl (assertions mt) ...) -- active declaration, no body
