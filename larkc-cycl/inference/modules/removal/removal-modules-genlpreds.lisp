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

(defparameter *default-genlpreds-check-cost* *hl-module-check-cost*)

;; (defun removal-genlpreds-check-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-all-genlpreds-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-all-genlpreds-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-all-spec-preds-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-all-spec-preds-iterator (asent) ...) -- active declareFunction, no body

(defparameter *default-not-genlpreds-check-cost* 2)

;; (defun removal-not-genlpreds-check-expand (asent &optional sense) ...) -- active declareFunction, no body

(toplevel
  (inference-removal-module :removal-genlpreds-check
    (list :sense :pos
          :predicate #$genlPreds
          :required-pattern (list #$genlPreds :predicate-fort :predicate-fort)
          :cost-expression '*default-genlpreds-check-cost*
          :expand 'removal-genlpreds-check-expand)))

(toplevel
  (inference-removal-module :removal-all-genlpreds
    (list :sense :pos
          :predicate #$genlPreds
          :required-pattern (list #$genlPreds :predicate-fort :variable)
          :cost 'removal-all-genlpreds-cost
          :input-extract-pattern (list :template
                                       (list #$genlPreds (list :bind 'spec-pred) :anything)
                                       (list :value 'spec-pred))
          :output-generate-pattern (list :call 'removal-all-genlpreds-iterator :input)
          :output-construct-pattern (list #$genlPreds (list :value 'spec-pred) :input)
          :support-module :genlpreds
          :support-strength :default
          :documentation "(#$genlPreds <predicate-fort> <variable>)"
          :example "(#$genlPreds #$performedBy ?WHAT)")))

(toplevel
  (inference-removal-module :removal-all-spec-preds
    (list :sense :pos
          :predicate #$genlPreds
          :required-pattern (list #$genlPreds :variable :predicate-fort)
          :cost 'removal-all-spec-preds-cost
          :input-extract-pattern (list :template
                                       (list #$genlPreds :anything (list :bind 'genl-pred))
                                       (list :value 'genl-pred))
          :output-generate-pattern (list :call 'removal-all-spec-preds-iterator :input)
          :output-construct-pattern (list #$genlPreds :input (list :value 'genl-pred))
          :support-module :genlpreds
          :support-strength :default
          :documentation "(#$genlPreds <variable> <predicate-fort>"
          :example "(#$genlPreds ?WHAT #$performedBy)")))

(toplevel
  (inference-removal-module :removal-not-genlpreds-check
    (list :sense :neg
          :predicate #$genlPreds
          :required-pattern (list #$genlPreds :predicate-fort :predicate-fort)
          :cost-expression '*default-not-genlpreds-check-cost*
          :expand 'removal-not-genlpreds-check-expand)))

(toplevel
  (register-solely-specific-removal-module-predicate #$genlPreds))
