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

(defparameter *collection-intersection-genls-support-enabled?* nil
  "[Cyc] Whether this support is enabled")

(defparameter *nart-indexing-bug-workaround-enabled?* nil
  "[Cyc] This would only ever need to be T if you were pasting this code into an older image that didn't have
the nart indexing bug fixed.")

;; (defun cyc-collection-intersection-after-adding (hl-module gaf) ...) -- commented declareFunction, no body
;; (defun cyc-collection-intersection-2-after-adding (hl-module gaf) ...) -- commented declareFunction, no body
;; (defun possibly-add-collection-intersection-nart (nart) ...) -- commented declareFunction, no body
;; (defun add-collection-intersection-nart (nart) ...) -- commented declareFunction, no body
;; (defun add-collection-intersection-nart-genls-links (nart) ...) -- commented declareFunction, no body
;; (defun add-collection-intersection-nart-specs-links (nart) ...) -- commented declareFunction, no body
;; (defun add-collection-intersection-nart-genls-links-int (nart) ...) -- commented declareFunction, no body
;; (defun compute-mt-specific-justification-for-collection-intersection-genls-asent (asent mt) ...) -- commented declareFunction, no body
;; (defun compute-more-supports-for-collection-intersection-genls-asent (asent) ...) -- commented declareFunction, no body
;; (defun compute-mt-placement-for-collection-intersection-genls-justified-asents (asent) ...) -- commented declareFunction, no body
;; (defun minimize-genls-hl-supports (supports) ...) -- commented declareFunction, no body
;; (defun max-floor-mts-of-genls-justification (justification) ...) -- commented declareFunction, no body
;; (defun assert-collection-intersection-genls-link (spec genl mt) ...) -- commented declareFunction, no body

(defun genls-collection-intersection-after-adding-int (gaf)
  (when *collection-intersection-genls-support-enabled?*
    (with-inference-mt-relevance (assertion-mt gaf)
      (let ((spec (gaf-arg1 gaf))
            (genl (gaf-arg2 gaf))
            (specs (all-specs spec))
            (v-genls (all-genls genl))
            (candidate-spec-narts (new-set #'eq))
            (candidate-genl-narts (new-set #'eq)))
        (dolist (candidate-spec specs)
          (declare (ignore candidate-spec))
          ;; TODO - missing-larkc 2812: likely called nart-indexing/indexed-narts to get
          ;; the narts involving CANDIDATE-SPEC, then set-add-all-ed them into
          ;; CANDIDATE-SPEC-NARTS. Referenced nearby $const5$collectionIntersection, etc.
          (set-add-all (missing-larkc 2812) candidate-spec-narts))
        (dolist (candidate-genl v-genls)
          (declare (ignore candidate-genl))
          ;; TODO - missing-larkc 2813: analogous to 2812, for CANDIDATE-GENL narts.
          (set-add-all (missing-larkc 2813) candidate-genl-narts))
        ;; TODO - missing-larkc 2826: likely an initial sweep/assertion over the
        ;; combined candidate nart sets (e.g. assert-collection-intersection-genls-link
        ;; or consider-all-combinations-for-genls-collection-intersection).
        (missing-larkc 2826)
        (do-set (candidate-genl-nart candidate-genl-narts)
          ;; TODO - missing-larkc 2807: CANDIDATE-GENL-NART is unused here because
          ;; the per-element action was stripped (likely passed to something like
          ;; consider-all-genl-narts-for-genls-collection-intersection).
          (missing-larkc 2807))))
    nil))

;; (defun consider-all-combinations-for-genls-collection-intersection (spec genl &optional a b c) ...) -- commented declareFunction, no body
;; (defun consider-all-genl-narts-for-genls-collection-intersection (a b c d) ...) -- commented declareFunction, no body
;; (defun collection-intersection-genls-sweep-part-1 (&optional a) ...) -- commented declareFunction, no body
;; (defun collection-intersection-genls-sweep-part-2 (&optional a) ...) -- commented declareFunction, no body
;; (defun collection-intersection-genls-sweep-by-query (a &optional b) ...) -- commented declareFunction, no body
;; (defun collection-intersection-nat-max-proper-genls (nat) ...) -- commented declareFunction, no body
;; (defun collection-intersection-nat-proper-genls (nat &optional b) ...) -- commented declareFunction, no body
;; (defun collection-intersection-nat-max-proper-specs (nat) ...) -- commented declareFunction, no body
;; (defun collection-intersection-nat-proper-specs (nat &optional b) ...) -- commented declareFunction, no body
;; (defun collection-intersection-narts-with-constituent-collection (col) ...) -- commented declareFunction, no body
;; (defun collection-intersection-2-fn-narts-with-constituent-collection (col) ...) -- commented declareFunction, no body
;; (defun collection-intersection-fn-narts-with-constituent-collection (col) ...) -- commented declareFunction, no body
;; (defun fully-bound-collection-intersection-nat-p (object) ...) -- commented declareFunction, no body
;; (defun collection-intersection-nart-p (object) ...) -- commented declareFunction, no body
;; (defun fully-bound-collection-intersection-nat-formula-p (object) ...) -- commented declareFunction, no body
;; (defun collection-intersection-nat-collections (nat) ...) -- commented declareFunction, no body
;; (defun term-constituent-collections (term) ...) -- commented declareFunction, no body
;; (defun genls-collection-intersection-fn-collection-intersection-fn-pos-check-in-any-mt (a b) ...) -- commented declareFunction, no body
;; (defun genls-collection-intersection-fn-collection-intersection-fn-pos-check (a b) ...) -- commented declareFunction, no body
;; (defun genls-collection-intersection-fn-pos-check (a b) ...) -- commented declareFunction, no body
;; (defun collection-intersection-genls-rule-support () ...) -- commented declareFunction, no body
;; (defun collection-intersection-specs-rule-support () ...) -- commented declareFunction, no body
;; (defun justify-collection-intersection-genls-narts (a b &optional c) ...) -- commented declareFunction, no body
;; (defun justify-collection-intersection-specs (a b &optional c) ...) -- commented declareFunction, no body
;; (defun justify-collection-intersection-genls-link-in-any-mt (a b) ...) -- commented declareFunction, no body
;; (defun justify-collection-intersection-genls-asent (asent) ...) -- commented declareFunction, no body
;; (defun why-genls-collection-intersection-fn (a b) ...) -- commented declareFunction, no body

(deflexical *collection-intersection-defining-mt* #$UniversalVocabularyMt)

(deflexical *collection-intersection-genls-rule*
    '(#$implies
      (#$and
       (#$collectionIntersection ?SPEC ?SPEC-CONSTITUENT-COLS)
       (#$collectionIntersection ?GENL ?GENL-CONSTITUENT-COLS)
       (#$forAll ?GENL-CONSTIT-COL
                 (#$implies
                  (#$elementOf ?GENL-CONSTIT-COL ?GENL-CONSTITUENT-COLS)
                  (#$thereExists ?SPEC-CONSTIT-COL
                                 (#$and
                                  (#$elementOf ?SPEC-CONSTIT-COL ?SPEC-CONSTITUENT-COLS)
                                  (#$genls ?SPEC-CONSTIT-COL ?GENL-CONSTIT-COL))))))
      (#$genls ?SPEC ?GENL))
  "[Cyc] The rule used to justify each collectionIntersection genl of ?SPEC")

(deflexical *collection-intersection-specs-rule*
    '(#$implies
      (#$and
       (#$collectionIntersection ?GENL ?GENL-CONSTITUENT-COLS)
       (#$isa ?SPEC #$Collection)
       (#$forAll ?GENL-CONSTIT-COL
                 (#$implies
                  (#$elementOf ?GENL-CONSTIT-COL ?GENL-CONSTITUENT-COLS)
                  (#$genls ?SPEC ?GENL-CONSTIT-COL))))
      (#$genls ?SPEC ?GENL))
  "[Cyc] The rule used to justify each spec of ?GENL")

(toplevel
  (register-kb-function 'cyc-collection-intersection-after-adding)
  (register-kb-function 'cyc-collection-intersection-2-after-adding)
  (note-funcall-helper-function 'fully-bound-collection-intersection-nat-p)
  (note-funcall-helper-function 'collection-intersection-nart-p))
