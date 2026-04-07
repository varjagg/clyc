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

(defun reflexive-on-predicate? (object)
  (and (or (not (eql 1 (some-pred-assertion-somewhere-argnum #$reflexiveOn)))
           (some-pred-assertion-somewhere? #$reflexiveOn object 1))
       (some-pred-value object #$reflexiveOn 1 :true)))

;; (defun reflexive-on-cols (pred) ...) -- active declareFunction, no body
;; (defun removal-reflexive-on-expand (asent &optional sense) ...) -- active declareFunction, no body
;; (defun reflexive-on-completness (asent) ...) -- active declareFunction, no body
;; (defun supports-for-reflexive-on (pred col) ...) -- active declareFunction, no body
;; (defun reflexive-on-isa-support (pred col mt) ...) -- active declareFunction, no body

(toplevel
  (note-funcall-helper-function 'reflexive-on-completness))

(toplevel
  (inference-removal-module :removal-reflexive-on
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything)
                                   (:or (:anything :fully-bound :anything)
                                        (:anything :anything :fully-bound))
                                   ((:test reflexive-on-predicate?) . :anything))
          :cost-expression '*hl-module-check-cost*
          :completeness-pattern '(:call reflexive-on-completness :input)
          :expand 'removal-reflexive-on-expand
          :documentation "(<reflexive predicate> arg1 arg2)
where at least one of arg1 and arg2 is fully bound,
by unification of arg1 and arg2
"
          :example "(#$whollyLocatedAt-Spatial #$EarthsEquator ?X) in #$WorldGeographyMt
via
 (#$reflexiveOn #$whollyLocatedAt-Spatial #$SpaceRegion)
and
 (#$isa #$EarthsEquator #$SpaceRegion)")))
