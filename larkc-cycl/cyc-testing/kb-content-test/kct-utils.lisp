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

;; Most functions in this file are LarKC-stripped stubs (commented-out
;; declareFunction entries). Their Internal Constants survive only as
;; macro-body / function-body evidence for the missing implementations.

(defconstant *kct-test-execution-type* "I")

(defconstant *kct-collection-execution-type* "C")

(defparameter *kct-default-error-notify-cyclist* nil)

(defparameter *kct-use-sampling-mode* nil)

(defparameter *kct-debug* nil)

(deflexical *kct-core-constants* (list #$TestVocabularyMt
                                       #$testQuerySpecification)
  "[Cyc] A representative sample of the KB constants that KCT depends on.")

(defun initialize-kct ()
  (initialize-ctest)
  t)

(defun initialize-kct-kb-feature ()
  "[Cyc] Determines whether the portion of the KB necessary for KCTs is loaded."
  (if (every-in-list #'valid-constant? *kct-core-constants*)
      ;; Originally set-kct-kb-loaded and/or a kct kb-feature hook; stripped in LarKC.
      (missing-larkc 32161)
      (unset-kct-kb-loaded))
  (kct-kb-loaded-p))

;; (defun kct-query-specification (kct) ...) -- commented declareFunction, no body
;; (defun kct-initialize () ...) -- commented declareFunction, no body
;; (defun kct-test-spec-p (object) ...) -- commented declareFunction, no body
;; (defun kct-test-spec-permissive-p (object) ...) -- commented declareFunction, no body
;; (defun kct-test-collection-p (object) ...) -- commented declareFunction, no body
;; (defun kct-asserted-test-collections (kct) ...) -- commented declareFunction, no body
;; (defun kct-comments (kct) ...) -- commented declareFunction, no body
;; (defun kct-test-collection-instances (collection) ...) -- commented declareFunction, no body
;; (defun kct-responsible-cyclists (kct) ...) -- commented declareFunction, no body
;; (defun kct-collection-responsible-cyclists (collection) ...) -- commented declareFunction, no body
;; (defun kct-test-metrics (kct) ...) -- commented declareFunction, no body
;; (defun kct-exact-set-of-binding-sets (kct) ...) -- commented declareFunction, no body
;; (defun kct-exact-binding-sets (kct) ...) -- commented declareFunction, no body
;; (defun kct-wanted-binding-sets (kct) ...) -- commented declareFunction, no body
;; (defun kct-unwanted-binding-sets (kct) ...) -- commented declareFunction, no body
;; (defun kct-bindings-unimportant? (kct) ...) -- commented declareFunction, no body
;; (defun kct-binding-sets-cardinality (kct) ...) -- commented declareFunction, no body
;; (defun kct-binding-sets-min-cardinality (kct) ...) -- commented declareFunction, no body
;; (defun kct-binding-sets-max-cardinality (kct) ...) -- commented declareFunction, no body
;; (defun kct-defining-mt (kct) ...) -- commented declareFunction, no body
;; (defun kct-test-runnable? (kct) ...) -- commented declareFunction, no body
;; (defun kct-test-known-unrunnable? (kct) ...) -- commented declareFunction, no body
;; (defun why-not-kct-test-valid (kct) ...) -- commented declareFunction, no body
;; (defun categorize-kct-invalidity-reasons () ...) -- commented declareFunction, no body
;; (defun why-not-kct-test-collection-valid (collection) ...) -- commented declareFunction, no body
;; (defun printable-execution-mode (mode) ...) -- commented declareFunction, no body
;; (defun printable-execution-type (type) ...) -- commented declareFunction, no body
;; (defun kct-default-for-parameter (parameter) ...) -- commented declareFunction, no body
;; (defun kct-new-hlmt (mt arg1 arg2) ...) -- commented declareFunction, no body
;; (defun kct-transform-query-results-for-comparison (results) ...) -- commented declareFunction, no body
;; (defun canonicalize-query-bindings-int (bindings) ...) -- commented declareFunction, no body
;; (defun ncanonicalize-query-bindings-int (bindings) ...) -- commented declareFunction, no body
;; (defun ncanonicalize-query-binding-int (binding) ...) -- commented declareFunction, no body
;; (defun kct-transform-set-of-binding-sets (set-of-binding-sets transform) ...) -- commented declareFunction, no body
;; (defun kct-formula-if-assertion (obj) ...) -- commented declareFunction, no body
