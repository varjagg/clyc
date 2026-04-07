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

;; Ordering follows declare_verbosifier_file() in verbosifier.java.
;; Only expandible-el-relation-expression? has an active declareFunction with a
;; body in the Java; all other function declarations are commented out (LarKC
;; strip), and the single declareMacro (gathering-expansion-justifications) is
;; also commented out. The macro is reconstructed from Internal Constants.

;; (defun verbosify-cycl (sentence &optional mt verbosity) ...) -- commented declareFunction, no body
;; (defun el-expansion (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expansion-destructive (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expansion-one-step (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expansion-one-step-destructive (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expand-all (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expand-all-destructive (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expandible-subformula? (formula &optional mt) ...) -- commented declareFunction, no body
;; (defun gathering-expansion-justifications? () ...) -- commented declareFunction, no body
;; (defun possibly-note-expansion-justification-support (support) ...) -- commented declareFunction, no body
;; (defun note-expansion-justification-support (support) ...) -- commented declareFunction, no body
;; (defun expansion-justification () ...) -- commented declareFunction, no body

;; gathering-expansion-justifications -- commented declareMacro
;; Reconstructed from Internal Constants:
;;   $sym6$CLET = CLET
;;   $list7 = ((*GATHER-EXPANSION-JUSTIFICATIONS?* T) (*EXPANSION-JUSTIFICATION* NIL))
;; The macro wraps BODY in a CLET that dynamically binds
;; *gather-expansion-justifications?* to T and *expansion-justification* to NIL,
;; so callers within BODY can accumulate a justification. Ported CLET -> let
;; since both are lexical-style bindings of already-special variables.
(defmacro gathering-expansion-justifications (&body body)
  `(let ((*gather-expansion-justifications?* t)
         (*expansion-justification* nil))
     ,@body))

;; (defun verbosify-cycl-justified (sentence &optional mt verbosity) ...) -- commented declareFunction, no body
;; (defun el-expansion-justified (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expansion-destructive-justified (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expansion-one-step-justified (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expansion-one-step-destructive-justified (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expand-all-justified (relation mt) ...) -- commented declareFunction, no body
;; (defun el-expand-all-destructive-justified (relation mt) ...) -- commented declareFunction, no body
;; (defun el-relations-out (fort pred &optional mt tv) ...) -- commented declareFunction, no body

(defun expandible-el-relation-expression? (object &optional mt)
  "[Cyc] @return boolean; t iff OBJECT is an EL formula with an #$ELRelation as its arg0."
  (and (el-formula-p object)
       (isa-el-relation? (formula-arg0 object) mt)))

;; (defun el-expandible-formula? (formula) ...) -- commented declareFunction, no body
;; (defun el-viably-expandible-formula? (formula) ...) -- commented declareFunction, no body
;; (defun el-expandible-relation? (relation) ...) -- commented declareFunction, no body
;; (defun el-expandible-relation-expression? (expression) ...) -- commented declareFunction, no body
;; (defun expandible-relation-expression? (expression) ...) -- commented declareFunction, no body
;; (defun el-viable-relation-expression? (expression) ...) -- commented declareFunction, no body
;; (defun el-expansion? (object) ...) -- commented declareFunction, no body
;; (defun el-expansion-int (relation mt) ...) -- commented declareFunction, no body
;; (defun el-formula-expansion-int (formula) ...) -- commented declareFunction, no body
;; (defun el-expansion-recursive (formula mt level destructive?) ...) -- commented declareFunction, no body
;; (defun has-viable-expansion? (relation) ...) -- commented declareFunction, no body
;; (defun has-viable-defn? (relation) ...) -- commented declareFunction, no body
;; (defun el-uniquify-wrt (expansion formula) ...) -- commented declareFunction, no body
;; (defun el-uniquify-formula-vars-wrt (expansion formula) ...) -- commented declareFunction, no body
;; (defun el-nuniquify-formula-vars-wrt (expansion formula) ...) -- commented declareFunction, no body
;; (defun el-uniquify-formula-vars-wrt-int (expansion formula destructive?) ...) -- commented declareFunction, no body
;; (defun expansion-naut? (object &optional mt) ...) -- commented declareFunction, no body
;; (defun arg0-of-any-expansion? (relation) ...) -- commented declareFunction, no body
;; (defun expansion-arg2-arg0-p (object) ...) -- commented declareFunction, no body


;; Variables (init phase)

(defparameter *el-relation-recursion-limit* 212
  "[Cyc] How much recursion is allowed in EL relations before yielding an error.")

(defparameter *gather-expansion-justifications?* nil
  "[Cyc] Dynamically bound when we are accumulating justifications for expansions")

(defparameter *expansion-justification* nil
  "[Cyc] Dynamically accumulates the justification for an expansion")
