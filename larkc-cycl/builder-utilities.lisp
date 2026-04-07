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

;; Commented-out functions (not in LarKC)
;; (defun close-old-areas () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun verify-cyc-build () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun cyc-build-world (arg1 arg2) ...) -- commented declareFunction, 2 required, 0 optional, no body
;; (defun cyc-build-world-verify (arg1 arg2) ...) -- commented declareFunction, 2 required, 0 optional, no body
;; (defun build-write-image (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun cyc-install-directory-name (arg1 &optional arg2) ...) -- commented declareFunction, 1 required, 1 optional, no body
;; (defun cyc-install-directory (arg1 arg2 arg3 &optional arg4) ...) -- commented declareFunction, 3 required, 1 optional, no body
;; (defun cyc-versioned-world-name () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun build-write-image-versioned (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun builder-log-directory () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun builder-forward-inference-metrics-log () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun catchup-to-rollover-and-write-image (arg1 &optional arg2 arg3) ...) -- commented declareFunction, 1 required, 2 optional, no body
;; (defun catchup-to-rollover () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun catchup-to-rollover-setup () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun load-submitted-transcripts-and-write-image (arg1 arg2) ...) -- commented declareFunction, 2 required, 0 optional, no body
;; (defun catchup-to-current-and-write-image-versioned (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun catchup-to-current-and-write-image (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun catchup-to-current-kb () ...) -- commented declareFunction, 0 required, 0 optional, no body

(defun declare-cyc-product (cyc-product code-product kb-product branch-tag)
  "[Cyc] Declare that CYC-PRODUCT is composed of CODE-PRODUCT, KB-PRODUCT and BRANCH-TAG.
   This information is used to compositionally determine the CYC-PRODUCT of
   a running image, which in turn can be used to gate various behaviors."
  (declare (type keyword cyc-product)
           (type keyword kb-product)
           (type keyword code-product)
           (type string branch-tag))
  (if (cyc-product-definition-present? cyc-product code-product kb-product branch-tag)
      (warn "The cyc product, ~A, is already present with the declared definition." cyc-product)
      (if (find-cyc-product code-product kb-product branch-tag)
          (error "There already exists a different cyc product, ~A, with this definition."
                 (find-cyc-product code-product kb-product branch-tag))
          (if (assoc cyc-product *cyc-product-definitions*)
              (error "The cyc product ~A already exists with a different definition." cyc-product)
              (progn
                (push cyc-product *all-cyc-products*)
                (push (list cyc-product kb-product code-product branch-tag)
                      *cyc-product-definitions*)
                *cyc-product-definitions*)))))

(defun cyc-product-definition-present? (cyc-product code-product kb-product branch-tag)
  "[Cyc] Returns T if a cyc product definition composed of these 4 values exists."
  (member (list cyc-product code-product kb-product branch-tag)
          *cyc-product-definitions*
          :test #'equal))

(defun find-cyc-product (code-product kb-product branch-tag)
  "[Cyc] Returns the cyc product identifier for this combination of code-product,
   kb-product and branch-tag."
  (first (find (list code-product kb-product branch-tag)
               *cyc-product-definitions*
               :test #'equal
               :key #'cdr)))

(defun cyc-product ()
  "[Cyc] Return a token identifying the cyc product of this running image,
   which was initialized at startup based on properties of the code and
   KB."
  *cyc-product*)

(defun code-product ()
  *code-product*)

(defun kb-product ()
  *kb-product*)

(defun branch-tag ()
  *branch-tag*)

(defun set-cyc-product (cyc-product)
  (declare (type keyword cyc-product))
  (setf *cyc-product* cyc-product)
  (cyc-product))

;; (defun set-kb-product (kb-product) ...) -- commented declareFunction, 1 required, 0 optional, no body

(defun initialize-cyc-product ()
  "[Cyc] Detect what the value of *CYC-PRODUCT* should be, then set it."
  (let ((cyc-product (detect-cyc-product)))
    (if cyc-product
        (set-cyc-product cyc-product)
        (set-cyc-product :unknown-cyc-product))
    cyc-product))

(defun detect-cyc-product ()
  (find-cyc-product (code-product) (kb-product) (branch-tag)))

;; (defun enumerate-fact-sheets-for-kb-to-file (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun enumerate-fact-sheets-for-kb (&optional arg1) ...) -- commented declareFunction, 0 required, 1 optional, no body
;; (defun fact-sheet-path-for-term-filter-and-transform (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body

(defun specify-sbhl-caching-policy-template (link-predicate policy capacity &optional (exempts 0) (prefetch 0))
  (list link-predicate policy capacity exempts prefetch))

;; (defun generate-kb-sbhl-caching-policies (arg1 arg2 &optional arg3) ...) -- commented declareFunction, 2 required, 1 optional, no body
;; (defun generate-legacy-kb-sbhl-caching-policies (arg1 &optional arg2) ...) -- commented declareFunction, 1 required, 1 optional, no body
;; (defun generate-completely-cached-kb-sbhl-caching-policies (arg1 &optional arg2) ...) -- commented declareFunction, 1 required, 1 optional, no body
;; (defun propose-kb-sbhl-caching-policies-from-tuning-data (arg1 &optional arg2) ...) -- commented declareFunction, 1 required, 1 optional, no body
;; (defun propose-completely-cached-kb-sbhl-caching-policies (&optional arg1) ...) -- commented declareFunction, 0 required, 1 optional, no body

(defun propose-legacy-kb-sbhl-caching-policies (&optional link-predicates)
  "[Cyc] Generate a KB SBHL caching policy proposal that reflects the state of the
   the system before the introduction of swap-out support--i.e. all modules
   are handled as sticky and nothing is pre-fetched."
  (propose-all-sticky-kb-sbhl-caching-policies link-predicates nil))

(defun get-all-sbhl-module-link-predicates ()
  "[Cyc] Helper for getting just the predicates out of the module structures."
  (let ((link-predicates nil))
    (do-dictionary (key module (get-sbhl-modules))
      (push (get-sbhl-module-link-pred module) link-predicates))
    link-predicates))

(defun propose-all-sticky-kb-sbhl-caching-policies (link-predicates with-prefetch-p)
  "[Cyc] Generate a KB SBHL caching policy proposal for sticky SBHL caching that for all
   passed link predicates.
   WITH-PREFETCH-P determines whether the prefetch will be all or none."
  (when (null link-predicates)
    (setf link-predicates (get-all-sbhl-module-link-predicates)))
  (let ((prefetch (if with-prefetch-p :all nil))
        (policies nil))
    (dolist (link-predicate link-predicates)
      (let ((legacy-policy (create-sbhl-caching-policy-from-term-recommendation-list
                            link-predicate :sticky :undefined nil :all prefetch)))
        (push legacy-policy policies)))
    (nreverse policies)))

;; (defun gather-data-for-sbhl-cache-tuning (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun run-sbhl-cache-tuning-data-gathering (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun sbhl-cache-tuning-data-gathering-prologue () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun sbhl-cache-tuning-experiment-prologue () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun sbhl-cache-tuning-experiment-epilogue (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun sbhl-cache-tuning-data-gathering-generate-report (arg1 arg2) ...) -- commented declareFunction, 2 required, 0 optional, no body
;; (defun sbhl-cache-tuning-data-gathering-epilogue () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun get-kb-mini-dump-timestamp () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun prepare-kb-mini-dump () ...) -- commented declareFunction, 0 required, 0 optional, no body
;; (defun perform-kb-mini-dump (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun launch-asynchronous-kb-mini-dump (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun mark-kb-mini-dump-as-successful (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun select-clippable-collections (&optional arg1 arg2) ...) -- commented declareFunction, 0 required, 2 optional, no body
;; (defun higher-order-collection? (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body
;; (defun gather-tabu-collections-for-clipping (arg1 &optional arg2 arg3) ...) -- commented declareFunction, 1 required, 2 optional, no body
;; (defun clip-kb-percentage (arg1 arg2 &optional arg3) ...) -- commented declareFunction, 2 required, 1 optional, no body
;; (defun clip-kb-given-tabu-term-list (arg1) ...) -- commented declareFunction, 1 required, 0 optional, no body

;; Variables

(defparameter *all-cyc-products* nil
  "[Cyc] A list of all cyc product identifiers")

(defparameter *cyc-product-definitions* nil
  "[Cyc] A list of cyc product definitions, each of which is of the form
   ([CYC-PRODUCT] [CODE-PRODUCT] [KB-PRODUCT] [BRANCH-TAG])")

(defglobal *cyc-product* nil
  "[Cyc] The value of *CYC-PRODUCT* will be set dynamically at image startup, based
   on the values of *CODE-PRODUCT*, *KB-PRODUCT*, and *BRANCH-TAG*.")

(defconstant *code-product* :standard
  "[Cyc] The value of *CODE-PRODUCT* is set in this definition.")

(defglobal *kb-product* nil
  "[Cyc] The value of *KB-PRODUCT* will be set at KB load time.")

(defconstant *branch-tag* "head"
  "[Cyc] The value of *BRANCH-TAG* is set in this definition.")

(defparameter *generic-sbhl-caching-policy-templates*
  (list (specify-sbhl-caching-policy-template :default :sticky :undefined :all)
        (specify-sbhl-caching-policy-template #$genlMt :sticky :undefined :all :all)
        (specify-sbhl-caching-policy-template #$genlPreds :swapout 500 500 200)
        (specify-sbhl-caching-policy-template #$negationPreds :swapout 500 100 0)
        (specify-sbhl-caching-policy-template #$disjointWith :swapout 500 500 200)
        (specify-sbhl-caching-policy-template #$genlInverse :swapout 500 500 200)
        (specify-sbhl-caching-policy-template #$negationInverse :swapout 500 100 0)
        (specify-sbhl-caching-policy-template #$genls :swapout 5000 5000 2000)
        (specify-sbhl-caching-policy-template #$isa :swapout 10000 8000 2000)
        (specify-sbhl-caching-policy-template #$quotedIsa :swapout 5000 4000 1000)))

(defparameter *cyc-tests-to-use-for-sbhl-cache-tuning* nil
  "[Cyc] Processes all of the tests in this list as part of the SBHL cache tuning.")

(defparameter *kb-queries-to-use-for-sbhl-cache-tuning* nil
  "[Cyc] Runs all of these queries as part of the SBHL cache tuning.
   @hack Currently not implemented.")

(defparameter *run-cyclops-for-sbhl-cache-tuning?* nil
  "[Cyc] When T, runs the CycLOPS benchmark once as part of the SBHL cache tuning.
   @hack Currently not implemented")

;; Setup

(toplevel
  (register-external-symbol 'cyc-build-world-verify)
  (declare-cyc-product :head :standard :full "head")
  (declare-cyc-product :cae-0.3 :tkb :akb "cake-release-0p3-20051215")
  (note-funcall-helper-function 'fact-sheet-path-for-term-filter-and-transform)
  (register-external-symbol 'get-kb-mini-dump-timestamp)
  (register-external-symbol 'prepare-kb-mini-dump)
  (register-external-symbol 'perform-kb-mini-dump)
  (register-external-symbol 'launch-asynchronous-kb-mini-dump))
