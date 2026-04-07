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

(deflexical *cycl-functions-used-as-after-addings* '(clear-paraphrase-caches))

(defparameter *inside-clear-genls-dependent-caches?* nil
  "[Cyc] Protection against infinite recursion.")

(defparameter *inside-clear-isa-dependent-caches?* nil
  "[Cyc] Protection against infinite recursion.")

(defparameter *inside-clear-quoted-isa-dependent-caches?* nil
  "[Cyc] Protection against infinite recursion.")

(defparameter *true-rule-template* (list #$implies
                                         (list #$trueRule '?template '?formula)
                                         '?formula))

(defglobal *true-rule-defining-mt* #$CoreCycLMt)

;; Functions in declareFunction order:

;; (defun decache-after-addings (argument assertion) ...) -- active declareFunction, no body
;; (defun decache-after-removings (argument assertion) ...) -- active declareFunction, no body
;; (defun decache-rule-after-addings (argument assertion) ...) -- active declareFunction, no body
;; (defun decache-rule-after-removings (argument assertion) ...) -- active declareFunction, no body

(defun clear-mt-dependent-caches (argument assertion)
  "[Cyc] possibly clear all mt dependent caches"
  (possibly-clear-mt-dependent-caches argument assertion))

(defun possibly-clear-mt-dependent-caches (argument assertion)
  (when (clear-mt-dependent-caches?)
    (clear-mt-dependent-caches-int argument assertion))
  nil)

(defun clear-mt-dependent-caches-int (argument assertion)
  (clear-all-base-mts)
  (update-mt-relevance-cache argument assertion)
  (clear-predicate-relevance-cache)
  (clear-cached-all-isa-sdct)
  (clear-cached-some-tva-for-predicate)
  (dolist (callback *mt-dependent-cache-clear-callbacks*)
    (when (fboundp callback)
      (funcall callback)))
  nil)

(defun clear-genls-dependent-caches (argument assertion)
  "[Cyc] clear all genls dependent caches"
  (unless *inside-clear-genls-dependent-caches?*
    (let ((*inside-clear-genls-dependent-caches?* t))
      (dolist (callback *genls-dependent-cache-clear-callbacks*)
        (when (fboundp callback)
          (funcall callback)))
      (clear-isa-dependent-caches-internal)
      (clear-quoted-isa-dependent-caches-internal)))
  nil)

(defun clear-isa-dependent-caches (argument assertion)
  "[Cyc] clear all isa dependent caches"
  (clear-isa-dependent-caches-internal)
  nil)

(defun clear-isa-dependent-caches-internal ()
  "[Cyc] clear all isa dependent caches"
  (unless *inside-clear-isa-dependent-caches?*
    (let ((*inside-clear-isa-dependent-caches?* t))
      (clear-cached-all-isa-sdct)
      (dolist (callback *isa-dependent-cache-clear-callbacks*)
        (when (fboundp callback)
          (funcall callback)))))
  nil)

(defun clear-quoted-isa-dependent-caches (argument assertion)
  "[Cyc] clear all quotedIsa dependent caches"
  (clear-quoted-isa-dependent-caches-internal)
  nil)

(defun clear-quoted-isa-dependent-caches-internal ()
  "[Cyc] clear all quotedIsa dependent caches"
  (unless *inside-clear-quoted-isa-dependent-caches?*
    (let ((*inside-clear-quoted-isa-dependent-caches?* t))
      (dolist (callback *quoted-isa-dependent-cache-clear-callbacks*)
        (when (fboundp callback)
          (funcall callback)))))
  nil)

(defun clear-genl-pred-dependent-caches (argument assertion)
  "[Cyc] clear all genlPreds and genlInverse dependent caches"
  (clear-predicate-relevance-cache)
  (clear-cached-some-tva-for-predicate)
  (dolist (callback *genl-preds-dependent-cache-clear-callbacks*)
    (when (fboundp callback)
      (funcall callback)))
  nil)

;; (defun add-transitive-via-arg (argument assertion) ...) -- active declareFunction, no body
;; (defun remove-transitive-via-arg (argument assertion) ...) -- active declareFunction, no body
;; (defun add-transitive-via-arg-inverse (argument assertion) ...) -- active declareFunction, no body
;; (defun remove-transitive-via-arg-inverse (argument assertion) ...) -- active declareFunction, no body
;; (defun clear-cached-tva-checks (argument assertion) ...) -- active declareFunction, no body
;; (defun clear-cached-some-tva-checks (argument assertion) ...) -- active declareFunction, no body
;; (defun clear-cached-cva-checks (argument assertion) ...) -- active declareFunction, no body
;; (defun clear-cached-some-cva-checks (argument assertion) ...) -- active declareFunction, no body
;; (defun skolem-after-removing (argument assertion) ...) -- active declareFunction, no body

(defun add-old-constant-name (argument assertion)
  "[Cyc] Update the cache after an oldConstantName assertion is added."
  (when (gaf-assertion? assertion)
    (let ((constant (gaf-arg assertion 1))
          (string (gaf-arg assertion 2)))
      (cache-old-constant-name string constant)
      (return-from add-old-constant-name nil)))
  nil)

(defun remove-old-constant-name (argument assertion)
  "[Cyc] Update the cache after an oldConstantName assertion is removed."
  (when (gaf-assertion? assertion)
    (let ((constant (gaf-arg assertion 1))
          (string (gaf-arg assertion 2)))
      (decache-old-constant-name string constant)
      (return-from remove-old-constant-name nil)))
  nil)

;; (defun propagate-to-isa (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-to-genls (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-to-disjointwith (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-to-genlmt (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-to-genlpreds (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-to-negationpreds (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-to-genlinverse (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-to-negationinverse (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-inverse-to-isa (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-inverse-to-genls (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-inverse-to-genlmt (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-inverse-to-genlpreds (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-inverse-to-genlinverse (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-sbhl-spec-pred-uses (argument assertion) ...) -- active declareFunction, no body
;; (defun propagate-sbhl-spec-inverse-uses (argument assertion) ...) -- active declareFunction, no body
;; (defun add-gen-keyword (argument assertion) ...) -- active declareFunction, no body
;; (defun add-ist (argument assertion) ...) -- active declareFunction, no body
;; (defun add-ist-el-support (support) ...) -- active declareFunction, no body
;; (defun add-true-rule (argument assertion) ...) -- active declareFunction, no body
;; (defun true-rule-el-support () ...) -- active declareFunction, no body
;; (defun true-rule-support-p (support) ...) -- active declareFunction, no body
;; (defun rule-template-direction (rule-template &optional mt) ...) -- active declareFunction, no body
;; (defun add-rule-template-direction (argument assertion) ...) -- active declareFunction, no body
;; (defun remove-rule-template-direction (argument assertion) ...) -- active declareFunction, no body
;; (defun rule-template-instantiations (rule-template &optional mt) ...) -- active declareFunction, no body
;; (defun rule-template-instantiation-deduction (assertion) ...) -- active declareFunction, no body
;; (defun remove-dependent-term (argument assertion) ...) -- active declareFunction, no body

(defun add-arity (argument assertion)
  (when (and (true-assertion? assertion)
             (only-argument-of-assertion-p assertion argument))
    (let ((relation (gaf-arg1 assertion))
          (v-arity (gaf-arg2 assertion)))
      (maybe-add-arity-for-relation relation v-arity)))
  assertion)

(defun remove-arity (argument assertion)
  (unless (assertion-still-there? assertion :true)
    (let ((relation (gaf-arg1 assertion))
          (v-arity (gaf-arg2 assertion)))
      (maybe-remove-arity-for-relation relation v-arity)))
  assertion)

;; (defun add-arity-min (argument assertion) ...) -- active declareFunction, no body
;; (defun remove-arity-min (argument assertion) ...) -- active declareFunction, no body
;; (defun add-arity-max (argument assertion) ...) -- active declareFunction, no body
;; (defun remove-arity-max (argument assertion) ...) -- active declareFunction, no body
;; (defun inter-arg-isa-after-adding (argument assertion) ...) -- active declareFunction, no body
;; (defun inter-arg-isa-after-removing (argument assertion) ...) -- active declareFunction, no body
;; (defun inter-arg-format-after-adding (argument assertion) ...) -- active declareFunction, no body
;; (defun inter-arg-format-after-removing (argument assertion) ...) -- active declareFunction, no body
;; (defun add-to-contraction-ht (argument assertion) ...) -- active declareFunction, no body
;; (defun remove-from-contraction-ht (argument assertion) ...) -- active declareFunction, no body
;; (defun add-gen-template-expansion (argument assertion) ...) -- active declareFunction, no body
;; (defun remove-gen-template-expansion (argument assertion) ...) -- active declareFunction, no body
;; (defun add-expansion-axiom (argument assertion) ...) -- active declareFunction, no body
;; (defun cyc-add-reformulation-assertion (argument assertion) ...) -- active declareFunction, no body
;; (defun cyc-remove-reformulation-assertion (argument assertion) ...) -- active declareFunction, no body
;; (defun cyc-add-element-of (argument assertion) ...) -- active declareFunction, no body
;; (defun cyc-add-known-antecedent-rule (argument assertion) ...) -- active declareFunction, no body
;; (defun cyc-remove-known-antecedent-rule (argument assertion) ...) -- active declareFunction, no body
;; (defun add-merged-constant-guid (argument assertion) ...) -- active declareFunction, no body
;; (defun remove-merged-constant-guid (argument assertion) ...) -- active declareFunction, no body
;; (defun cyc-except-added (argument assertion) ...) -- active declareFunction, no body
;; (defun cyc-except-removed (argument assertion) ...) -- active declareFunction, no body
;; (defun add-relation-instance-all (argument assertion) ...) -- active declareFunction, no body
;; (defun remove-relation-instance-all (argument assertion) ...) -- active declareFunction, no body
;; (defun add-relation-all-instance (argument assertion) ...) -- active declareFunction, no body
;; (defun remove-relation-all-instance (argument assertion) ...) -- active declareFunction, no body

;; Setup phase

(toplevel
  (dolist (symbol *cycl-functions-used-as-after-addings*)
    (register-kb-function symbol)))

(toplevel (register-kb-function 'decache-after-addings))
(toplevel (register-kb-function 'decache-after-removings))
(toplevel (register-kb-function 'decache-rule-after-addings))
(toplevel (register-kb-function 'decache-rule-after-removings))
(toplevel (register-kb-function 'clear-mt-dependent-caches))
(toplevel (register-kb-function 'clear-genls-dependent-caches))
(toplevel (register-kb-function 'clear-isa-dependent-caches))
(toplevel (register-kb-function 'clear-quoted-isa-dependent-caches))
(toplevel (register-kb-function 'clear-genl-pred-dependent-caches))
(toplevel (register-kb-function 'add-transitive-via-arg))
(toplevel (register-kb-function 'remove-transitive-via-arg))
(toplevel (register-kb-function 'add-transitive-via-arg-inverse))
(toplevel (register-kb-function 'remove-transitive-via-arg-inverse))
(toplevel (register-kb-function 'clear-cached-tva-checks))
(toplevel (register-kb-function 'clear-cached-some-tva-checks))
(toplevel (register-kb-function 'clear-cached-cva-checks))
(toplevel (register-kb-function 'clear-cached-some-cva-checks))
(toplevel (register-kb-function 'skolem-after-removing))
(toplevel (register-kb-function 'add-old-constant-name))
(toplevel (register-kb-function 'remove-old-constant-name))
(toplevel (register-kb-function 'propagate-to-isa))
(toplevel (register-kb-function 'propagate-to-genls))
(toplevel (register-kb-function 'propagate-to-disjointwith))
(toplevel (register-kb-function 'propagate-to-genlmt))
(toplevel (register-kb-function 'propagate-to-genlpreds))
(toplevel (register-kb-function 'propagate-to-negationpreds))
(toplevel (register-kb-function 'propagate-to-genlinverse))
(toplevel (register-kb-function 'propagate-to-negationinverse))
(toplevel (register-kb-function 'propagate-inverse-to-isa))
(toplevel (register-kb-function 'propagate-inverse-to-genls))
(toplevel (register-kb-function 'propagate-inverse-to-genlmt))
(toplevel (register-kb-function 'propagate-inverse-to-genlpreds))
(toplevel (register-kb-function 'propagate-inverse-to-genlinverse))
(toplevel (register-kb-function 'add-gen-keyword))
(toplevel (register-kb-function 'add-ist))
(toplevel (register-kb-function 'add-true-rule))
(toplevel (declare-defglobal '*true-rule-defining-mt*))
(toplevel (note-mt-var '*true-rule-defining-mt* #$trueRule))
(toplevel (register-kb-function 'add-rule-template-direction))
(toplevel (register-kb-function 'remove-rule-template-direction))
(toplevel (register-kb-function 'remove-dependent-term))
(toplevel (register-kb-function 'add-arity))
(toplevel (register-kb-function 'remove-arity))
(toplevel (register-kb-function 'add-arity-min))
(toplevel (register-kb-function 'remove-arity-min))
(toplevel (register-kb-function 'add-arity-max))
(toplevel (register-kb-function 'remove-arity-max))
(toplevel (register-kb-function 'inter-arg-isa-after-adding))
(toplevel (register-kb-function 'inter-arg-isa-after-removing))
(toplevel (register-kb-function 'inter-arg-format-after-adding))
(toplevel (register-kb-function 'inter-arg-format-after-removing))
(toplevel (register-kb-function 'add-to-contraction-ht))
(toplevel (register-kb-function 'remove-from-contraction-ht))
(toplevel (register-kb-function 'add-gen-template-expansion))
(toplevel (register-kb-function 'remove-gen-template-expansion))
(toplevel (register-kb-function 'add-expansion-axiom))
(toplevel (register-kb-function 'cyc-add-reformulation-assertion))
(toplevel (register-kb-function 'cyc-remove-reformulation-assertion))
(toplevel (register-kb-function 'cyc-add-element-of))
(toplevel (register-kb-function 'cyc-add-known-antecedent-rule))
(toplevel (register-kb-function 'cyc-remove-known-antecedent-rule))
(toplevel (register-kb-function 'add-merged-constant-guid))
(toplevel (register-kb-function 'remove-merged-constant-guid))
(toplevel (register-kb-function 'cyc-except-added))
(toplevel (register-kb-function 'cyc-except-removed))
(toplevel (register-kb-function 'add-relation-instance-all))
(toplevel (register-kb-function 'remove-relation-instance-all))
(toplevel (register-kb-function 'add-relation-all-instance))
(toplevel (register-kb-function 'remove-relation-all-instance))
