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

(deflexical *indexical-referent-expansions* nil
  "[Cyc] A table of expansion methods for #$indexicalReferent.")

(defun register-indexical-referent-expansion (indexical method)
  (setf *indexical-referent-expansions*
        (alist-enter *indexical-referent-expansions* indexical method #'equal))
  nil)

;; (defun cyc-indexical-referent (indexical) ...) -- active declareFunction, no body

(defun indexical-referent-term-p (object)
  ;; Likely tests if OBJECT is a constant that has an indexical-referent expansion registered.
  ;; Evidence: used in :required-pattern (:test indexical-referent-term-p) for the removal module.
  (missing-larkc 32833))

;; (defun indexical-referent-expand (indexical) ...) -- active declareFunction, no body

(defparameter *default-indexical-referent-cost* 1)

(defun temporal-indexical-expand (indexical)
  ;; Likely expands temporal indexicals (e.g. #$Now, #$Today) to their current referents.
  ;; Evidence: name implies temporal indexical handling; registered as a UnaryFunction.
  (missing-larkc 32834))

;; (defun indexical-query-mt () ...) -- active declareFunction, no body
;; (defun indexical-the-user () ...) -- active declareFunction, no body
;; (defun indexical-the-purpose () ...) -- active declareFunction, no body

;; Globally cached group: clear-indexical-the-cyc-process-owner,
;; remove-indexical-the-cyc-process-owner, indexical-the-cyc-process-owner-internal,
;; indexical-the-cyc-process-owner. All bodies stripped.
;; (defun-cached indexical-the-cyc-process-owner () (:test eql) ...) -- active declareFunction, no body

;; (defun indexical-the-current-kb-number () ...) -- active declareFunction, no body
;; (defun indexical-the-current-system-number () ...) -- active declareFunction, no body
;; (defun indexical-the-current-host-name () ...) -- active declareFunction, no body

(toplevel
  (register-kb-function 'cyc-indexical-referent))

(toplevel
  (register-solely-specific-removal-module-predicate #$indexicalReferent))

(toplevel
  (inference-removal-module :removal-indexical-referent-pos
    (list :sense :pos
          :predicate #$indexicalReferent
          :required-pattern '(#$indexicalReferent
                              (:and :fully-bound (:test indexical-referent-term-p))
                              :anything)
          :cost-expression '*default-indexical-referent-cost*
          :completeness :complete
          :input-extract-pattern '(:template (#$indexicalReferent (:bind indexical) :anything)
                                             (:value indexical))
          :output-generate-pattern '(:call non-null-answer-to-singleton
                                           (:call indexical-referent-expand :input))
          :output-construct-pattern '(#$indexicalReferent (:value indexical) :input))))

(toplevel
  (register-indexical-referent-expansion #$QueryMt 'indexical-query-mt))

(toplevel
  (register-indexical-referent-expansion #$TheUser 'indexical-the-user))

(toplevel
  (register-indexical-referent-expansion #$ThePurpose 'indexical-the-purpose))

(toplevel
  (note-globally-cached-function 'indexical-the-cyc-process-owner))

(toplevel
  (register-indexical-referent-expansion #$TheCycProcessOwner 'indexical-the-cyc-process-owner))

(toplevel
  (register-indexical-referent-expansion #$TheCurrentKBNumber 'indexical-the-current-kb-number))

(toplevel
  (register-indexical-referent-expansion #$TheCurrentSystemNumber 'indexical-the-current-system-number))

(toplevel
  (register-indexical-referent-expansion #$TheCurrentHostName 'indexical-the-current-host-name))
