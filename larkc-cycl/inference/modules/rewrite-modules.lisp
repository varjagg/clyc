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

;; Variables

(defvar *ral-sub-situations-from-sub-situation-types-rule* :uninitialized)
(defvar *sub-situation-types-from-ral-sub-situations-rule* :uninitialized)
(defvar *rai-group-member-type-from-group-type-member-type-rule* :uninitialized)
(defvar *group-type-member-type-from-rai-group-member-type-rule* :uninitialized)
(defvar *ral-sub-events-from-sub-event-types-rule* :uninitialized)
(defvar *sub-event-types-from-ral-sub-events-rule* :uninitialized)

;; Functions in declareFunction order

(defun *ral-sub-situations-from-sub-situation-types-rule*-initializer ()
  (find-assertion-or-make-support
   (list #$implies
         (list #$subSituationTypes '?whole-type '?part-type)
         (list #$relationAllExists #$subSituations '?whole-type '?part-type))
   #$BaseKB))

(defun *sub-situation-types-from-ral-sub-situations-rule*-initializer ()
  (find-assertion-or-make-support
   (list #$implies
         (list #$relationAllExists #$subSituations '?whole-type '?part-type)
         (list #$subSituationTypes '?whole-type '?part-type))
   #$BaseKB))

;; (defun relation-all-exists-sub-situations-rewrite-expand (asent) ...) -- active declareFunction, no body
;; (defun sub-situation-types-rewrite-expand (asent) ...) -- active declareFunction, no body

(defun *rai-group-member-type-from-group-type-member-type-rule*-initializer ()
  (find-assertion-or-make-support
   (list #$implies
         (list #$groupTypeMemberType '?grouptype '?membertype)
         (list #$relationAllInstance #$groupMemberType '?grouptype '?membertype))
   #$BaseKB))

(defun *group-type-member-type-from-rai-group-member-type-rule*-initializer ()
  (find-assertion-or-make-support
   (list #$implies
         (list #$relationAllInstance #$groupMemberType '?grouptype '?membertype)
         (list #$groupTypeMemberType '?grouptype '?membertype))
   #$BaseKB))

;; (defun relation-all-instance-group-member-type-rewrite-expand (asent) ...) -- active declareFunction, no body
;; (defun group-type-member-type-rewrite-expand (asent) ...) -- active declareFunction, no body

(defun *ral-sub-events-from-sub-event-types-rule*-initializer ()
  (find-assertion-or-make-support
   (list #$implies
         (list #$subEventTypes '?whole-type '?part-type)
         (list #$relationAllExists #$subEvents '?whole-type '?part-type))
   #$BaseKB))

(defun *sub-event-types-from-ral-sub-events-rule*-initializer ()
  (find-assertion-or-make-support
   (list #$implies
         (list #$relationAllExists #$subEvents '?whole-type '?part-type)
         (list #$subEventTypes '?whole-type '?part-type))
   #$BaseKB))

;; (defun relation-all-exists-sub-events-rewrite-expand (asent) ...) -- active declareFunction, no body
;; (defun sub-event-types-rewrite-expand (asent) ...) -- active declareFunction, no body

;; Setup phase

(toplevel
  (register-kb-variable-initialization
   '*ral-sub-situations-from-sub-situation-types-rule*
   '*ral-sub-situations-from-sub-situation-types-rule*-initializer))

(toplevel
  (register-kb-variable-initialization
   '*sub-situation-types-from-ral-sub-situations-rule*
   '*sub-situation-types-from-ral-sub-situations-rule*-initializer))

(toplevel
  (inference-rewrite-module :relation-all-exists-sub-situations-from-sub-situation-types-check
    (list :sense :pos
          :required-pattern (list #$relationAllExists #$subSituations :fully-bound :fully-bound)
          :cost-expression 1
          :completeness :incomplete
          :expand 'relation-all-exists-sub-situations-rewrite-expand
          :rewrite-support '*ral-sub-situations-from-sub-situation-types-rule*
          :documentation "Rewrites (#$subSituationTypes <fort1> <fort2>) literals as
    (#$relationAllExists #$subSituations <fort1> <fort2>) literals."
          :example "(#$subSituationTypes #$AilmentCondition #$PhysiologicalCondition)
    ----->
    (#$relationAllExists #$subSituations #$AilmentCondition #$PhysiologicalCondition)")))

(toplevel
  (inference-rewrite-module :sub-situation-types-from-relation-all-exists-sub-situations-check
    (list :sense :pos
          :required-pattern (list #$subSituationTypes :fully-bound :fully-bound)
          :cost-expression 1
          :completeness :incomplete
          :expand 'sub-situation-types-rewrite-expand
          :rewrite-support '*sub-situation-types-from-ral-sub-situations-rule*
          :documentation "Rewrites (#$relationAllExists #$subSituations <fort1> <fort2>) literals as
    (#$subSituationTypes <fort1> <fort2>) literals."
          :example "(#$relationAllExists #$subSituations #$PhysiologicalCondition #$BiologicalEvent)
    ----->
    (#$subSituationTypes #$PhysiologicalCondition #$BiologicalEvent)")))

(toplevel
  (register-kb-variable-initialization
   '*rai-group-member-type-from-group-type-member-type-rule*
   '*rai-group-member-type-from-group-type-member-type-rule*-initializer))

(toplevel
  (register-kb-variable-initialization
   '*group-type-member-type-from-rai-group-member-type-rule*
   '*group-type-member-type-from-rai-group-member-type-rule*-initializer))

(toplevel
  (inference-rewrite-module :relation-all-instance-group-member-type-from-group-type-member-type-check
    (list :sense :pos
          :required-pattern (list #$relationAllInstance #$groupMemberType :fully-bound :fully-bound)
          :cost-expression 1
          :completeness :incomplete
          :expand 'relation-all-instance-group-member-type-rewrite-expand
          :rewrite-support '*rai-group-member-type-from-group-type-member-type-rule*
          :documentation "Rewrites (#$groupTypeMemberType <fort1> <fort2>) literals as
    (#$relationAllInstance #$groupMemberType <fort1> <fort2>) literals."
          :example "(#$groupTypeMemberType (#$GroupFn #$InanimateObject) #$InanimateObject))
    ----->
    (#$relationAllInstance #$groupMemberType (#$GroupFn #$InanimateObject) #$InanimateObject))")))

(toplevel
  (inference-rewrite-module :group-type-member-type-from-relation-all-instance-group-member-type-check
    (list :sense :pos
          :required-pattern (list #$groupTypeMemberType :fully-bound :fully-bound)
          :cost-expression 1
          :completeness :incomplete
          :expand 'group-type-member-type-rewrite-expand
          :rewrite-support '*group-type-member-type-from-rai-group-member-type-rule*
          :documentation "Rewrites (#$relationAllInstance #$groupMemberType <fort1> <fort2>) literals as
    (#$groupTypeMemberType <fort1> <fort2>) literals."
          :example "(#$relationAllInstance #$groupMemberType (#$GroupFn #$InanimateObject) #$InanimateObject)
    ----->
    (#$groupTypeMemberType (#$GroupFn #$InanimateObject) #$InanimateObject)")))

(toplevel
  (register-kb-variable-initialization
   '*ral-sub-events-from-sub-event-types-rule*
   '*ral-sub-events-from-sub-event-types-rule*-initializer))

(toplevel
  (register-kb-variable-initialization
   '*sub-event-types-from-ral-sub-events-rule*
   '*sub-event-types-from-ral-sub-events-rule*-initializer))

(toplevel
  (inference-rewrite-module :relation-all-exists-sub-events-from-sub-event-types-check
    (list :sense :pos
          :required-pattern (list #$relationAllExists #$subEvents :fully-bound :fully-bound)
          :cost-expression 1
          :completeness :incomplete
          :expand 'relation-all-exists-sub-events-rewrite-expand
          :rewrite-support '*ral-sub-events-from-sub-event-types-rule*
          :documentation "Rewrites (#$subEventTypes <fort1> <fort2>) literals as
    (#$relationAllExists #$subEvents <fort1> <fort2>) literals."
          :example "(#$subEventTypes #$Foraging #$Perceiving)
    ----->
    (#$relationAllExists #$subEvents #$Foraging #$Perceiving)")))

(toplevel
  (inference-rewrite-module :sub-event-types-from-relation-all-exists-sub-events-check
    (list :sense :pos
          :required-pattern (list #$subEventTypes :fully-bound :fully-bound)
          :cost-expression 1
          :completeness :incomplete
          :expand 'sub-event-types-rewrite-expand
          :rewrite-support '*sub-event-types-from-ral-sub-events-rule*
          :documentation "Rewrites (#$relationAllExists #$subEvents <fort1> <fort2>) literals as
    (#$subEventTypes <fort1> <fort2>) literals."
          :example "(#$relationAllExists #$subEvents #$CompostingProcess #$DecompositionProcess)
    ----->
    (#$subEventTypes #$CompostingProcess #$DecompositionProcess)")))
