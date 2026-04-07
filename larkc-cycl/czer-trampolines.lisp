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

(defun* czer-memoization-state () (:inline t)
  "[Cyc] Return the current canonicalizer memoization state."
  *czer-memoization-state*)

(defun within-czer-memoization-state? ()
  "[Cyc] Return T iff there is a current canonicalizer memoization state."
  (memoization-state-p (czer-memoization-state)))

(defun czer-scoping-formula? (formula)
  "[Cyc] Return T iff FORMULA is a scoping formula for canonicalization purposes."
  (when (el-formula-p formula)
    (let ((relation (formula-operator formula)))
      (isa-scoping-relation? relation))))

;; czer-scoping-args (formula) — active declareFunction, no body in LarKC
(defun czer-scoping-args (formula)
  (declare (ignore formula))
  (missing-larkc 29118))

;; czer-scoped-vars (formula) — active declareFunction, no body in LarKC
(defun czer-scoped-vars (formula)
  (declare (ignore formula))
  (missing-larkc 29119))

;; State-dependent memoized function. The Java has an explicit _internal function
;; and memoization wrapper; defun-memoized handles both.
(defun-memoized czer-argn-quoted-isa-int (relation argnum mt-info) (:test equal)
  "[Cyc] Return the argn-quoted-isa constraints for RELATION at ARGNUM, memoized per mt-info."
  (cond
    ((mt-function-eq mt-info 'relevant-mt-is-everything)
     (let ((*relevant-mt-function* 'relevant-mt-is-everything)
           (*mt* #$EverythingPSC))
       (argn-quoted-isa-int relation argnum nil)))
    ((mt-function-eq mt-info 'relevant-mt-is-any-mt)
     (let ((*relevant-mt-function* 'relevant-mt-is-any-mt)
           (*mt* #$InferencePSC))
       (argn-quoted-isa-int relation argnum nil)))
    ((mt-union-naut-p mt-info)
     (let ((*relevant-mt-function* 'relevant-mt-is-genl-mt-of-list-member)
           ;; missing-larkc 12313 likely extracts the mt-list from the MtUnionFn naut,
           ;; e.g. via hlmt:mt-union-mts or similar
           (*relevant-mts* (missing-larkc 12313)))
       (argn-quoted-isa-int relation argnum nil)))
    (t
     (let ((*relevant-mt-function* 'relevant-mt-is-genl-mt)
           (*mt* mt-info))
       (argn-quoted-isa-int relation argnum nil)))))
