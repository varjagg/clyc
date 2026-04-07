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

(defparameter *default-different-duplicate-cost* 0)

(defun asent-duplicate-args-p (asent)
  (duplicates? (atomic-sentence-args asent) #'equal))

;; (defun make-binary-different-eval-support (arg1 arg2) ...) -- active declareFunction, no body
;; (defun different-delay-pos-preference (asent bindable-vars strategic-context) ...) -- active declareFunction, no body
;;   Orphan constants: HL-VARIABLE-P, :DISALLOWED, :PREFERRED — likely tests args for hl-variable-p
;;   and returns :disallowed or :preferred

(defun removal-different-duplicate-exclusive (asent &optional sense)
  (declare (ignore sense))
  (asent-duplicate-args-p asent))

;; (defun different-symbols-delay-pos-preference (asent bindable-vars strategic-context) ...) -- active declareFunction, no body
;; (defun removal-different-symbols-duplicate-exclusive (asent &optional sense) ...) -- active declareFunction, no body
;; (defun cyc-possibly-evaluate (term) ...) -- active declareFunction, no body
;; (defun cyc-possibly-evaluate-args (asent) ...) -- active declareFunction, no body

(toplevel
  (register-solely-specific-removal-module-predicate #$different))

(toplevel
  (inference-removal-module-use-generic #$different :removal-eval))

(toplevel
  (inference-removal-module-use-generic #$different :removal-not-eval))

(toplevel
  (inference-preference-module :different-delay-pos
    (list :sense :pos
          :predicate #$different
          :required-pattern (cons #$different :not-fully-bound)
          :preference 'different-delay-pos-preference)))

(toplevel
  (note-funcall-helper-function 'different-delay-pos-preference))

(toplevel
  (inference-removal-module :removal-different-duplicate
    (list :sense :pos
          :predicate #$different
          :required-pattern (cons #$different :anything)
          :exclusive 'removal-different-duplicate-exclusive
          :supplants :all
          :cost-expression '*default-different-duplicate-cost*
          :completeness :complete)))

(toplevel
  (register-solely-specific-removal-module-predicate #$differentSymbols))

(toplevel
  (inference-removal-module-use-generic #$differentSymbols :removal-eval))

(toplevel
  (inference-removal-module-use-generic #$differentSymbols :removal-not-eval))

(toplevel
  (inference-removal-module-use-meta-removal #$differentSymbols :meta-removal-completely-enumerable-pos))

(toplevel
  (inference-removal-module-use-meta-removal #$differentSymbols :meta-removal-completely-decidable-pos))

(toplevel
  (inference-preference-module :different-symbols-delay-pos
    (list :sense :pos
          :predicate #$differentSymbols
          :required-pattern (cons #$differentSymbols :not-fully-bound)
          :preference 'different-symbols-delay-pos-preference)))

(toplevel
  (note-funcall-helper-function 'different-symbols-delay-pos-preference))

(toplevel
  (inference-removal-module :removal-different-symbols-duplicate
    (list :sense :pos
          :predicate #$differentSymbols
          :required-pattern (cons #$differentSymbols :anything)
          :exclusive 'removal-different-symbols-duplicate-exclusive
          :supplants :all
          :cost-expression '*default-different-duplicate-cost*
          :completeness :complete)))
