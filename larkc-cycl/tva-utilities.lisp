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


;;; Variables

(deflexical *tva-predicates*
  (list #$transitiveViaArg
        #$transitiveViaArgInverse
        #$conservativeViaArg
        #$conservativeViaArgInverse)
  "[Cyc] The predicates used for TVA inference")

(defun get-tva-predicates ()
  *tva-predicates*)

;; Reconstructed from Internal Constants:
;; $list1 = ((PRED &KEY DONE) &BODY BODY)
;; $kw4 = :DONE, $sym5 = CSOME, $list6 = (GET-TVA-PREDICATES)
(defmacro do-tva-predicates ((pred &key done) &body body)
  `(csome (,pred (get-tva-predicates) ,done)
     ,@body))

(defglobal *tva-precomputes-sksi-closures?* nil)

(defun tva-precomputes-sksi-closures? ()
  *tva-precomputes-sksi-closures?*)

(defglobal *tva-iterates-kb-predicate-extent?* t
  "[Cyc] Whether to iterate over the KB predicate extent within TVA")

(defun tva-iterates-kb-predicate-extent? ()
  *tva-iterates-kb-predicate-extent?*)

(defglobal *tva-iterates-sksi-predicate-extent?* nil
  "[Cyc] Whether to iterate over the SKSI predicate extent within TVA")

(defun tva-iterates-sksi-predicate-extent? ()
  *tva-iterates-sksi-predicate-extent?*)

;; (defun tva-arg-admittance-ok? (v-term argnum pred mt tva-asent) ...) -- active declareFunction, no body
;; (defun tva-relation-checks-arg-admittance-p (relation argnum pred mt) ...) -- active declareFunction, no body
;; (defun tva-argument-admitted-p (argument) ...) -- active declareFunction, no body

(defparameter *tva-precompute-closure-threshold* 60
  "[Cyc] The cardinality below which a closure should be marked, regardless of direction")

;; Reconstructed from Internal Constants:
;; $list12 = (NUM &BODY BODY)
;; $sym13 = PROGN, $sym14 = CHECK-TYPE, $list15 = (INTEGERP),
;; $sym16 = CLET, $sym17 = *TVA-PRECOMPUTE-CLOSURE-THRESHOLD*
(defmacro with-tva-precompute-closure-threshold (num &body body)
  `(progn
     (check-type ,num 'integerp)
     (let ((*tva-precompute-closure-threshold* ,num))
       ,@body)))

;; (defun less-than-precompute-closure-threshold? (num) ...) -- active declareFunction, no body
;; (defun tva-predicate-p (predicate) ...) -- active declareFunction, no body
;; (defun cva-predicate-p (predicate) ...) -- active declareFunction, no body

(defun tva-assertion-p (assertion)
  "[Cyc] @return booleanp. Returns whether the arg 2 of ASSERTION is a GAF."
  (transitive-binary-predicate-p (gaf-arg2 assertion)))

;; (defun cva-assertion-p (assertion) ...) -- active declareFunction, no body

(defun some-transitive-via-arg-assertion? (predicate)
  "[Cyc] @return booleanp. Returns whether PREDICATE should has any pertinent TVA[I] assertions"
  (or (some-pred-value-if predicate #$transitiveViaArg 'tva-assertion-p)
      (some-pred-value-if predicate #$transitiveViaArgInverse 'tva-assertion-p)))

(defun some-conservative-via-arg-assertion? (predicate)
  "[Cyc] @return booleanp. Returns whether PREDICATE should has any pertinent CVA[I] assertions"
  (or (some-pred-value-if predicate #$conservativeViaArg 'cva-assertion-p)
      (some-pred-value-if predicate #$conservativeViaArgInverse 'cva-assertion-p)))

(defun some-tva-for-predicate (predicate)
  "[Cyc] @return booleanp. Returns whether PREDICATE has a #$transitiveViaArg... assertion somewhere, and should use the :tva module"
  (cached-some-tva-for-predicate predicate (mt-info)))

(defun some-cva-for-predicate (predicate)
  "[Cyc] @return booleanp. Returns whether PREDICATE has a #$conservativeViaArg... assertion somewhere should use the :tva module"
  (cached-some-cva-for-predicate predicate (mt-info)))

(defun-cached cached-some-tva-for-predicate (predicate mt-info)
    (:test equal :capacity 100 :clear-when :hl-store-modified)
  "[Cyc] @return booleanp; Whether PREDICATE is the arg1 of any transitive-via assertion."
  (cond
    ((mt-function-eq mt-info 'relevant-mt-is-everything)
     (let ((*relevant-mt-function* 'relevant-mt-is-everything)
           (*mt* #$EverythingPSC))
       (some-all-spec-preds-and-inverses predicate
                                         'some-transitive-via-arg-assertion?)))
    ((mt-function-eq mt-info 'relevant-mt-is-any-mt)
     (let ((*relevant-mt-function* 'relevant-mt-is-any-mt)
           (*mt* #$InferencePSC))
       (some-all-spec-preds-and-inverses predicate
                                         'some-transitive-via-arg-assertion?)))
    ((mt-union-naut-p mt-info)
     (let ((*relevant-mt-function* 'relevant-mt-is-genl-mt-of-list-member)
           ;; missing-larkc 12318 likely extracts the mt-list from the MtUnionFn naut
           (*relevant-mts* (missing-larkc 12318)))
       (some-all-spec-preds-and-inverses predicate
                                         'some-transitive-via-arg-assertion?)))
    (t
     (let ((*relevant-mt-function* 'relevant-mt-is-genl-mt)
           (*mt* mt-info))
       (some-all-spec-preds-and-inverses predicate
                                         'some-transitive-via-arg-assertion?)))))

;; (defun remove-cached-some-tva-for-predicate (predicate &optional mt-info) ...) -- active declareFunction, no body

(defun-cached cached-some-cva-for-predicate (predicate mt-info)
    (:test equal :capacity 100 :clear-when :hl-store-modified)
  "[Cyc] @return booleanp; Whether PREDICATE is the arg1 of any conservative-via assertion."
  (cond
    ((mt-function-eq mt-info 'relevant-mt-is-everything)
     (let ((*relevant-mt-function* 'relevant-mt-is-everything)
           (*mt* #$EverythingPSC))
       (some-all-spec-preds-and-inverses predicate
                                         'some-conservative-via-arg-assertion?)))
    ((mt-function-eq mt-info 'relevant-mt-is-any-mt)
     (let ((*relevant-mt-function* 'relevant-mt-is-any-mt)
           (*mt* #$InferencePSC))
       (some-all-spec-preds-and-inverses predicate
                                         'some-conservative-via-arg-assertion?)))
    ((mt-union-naut-p mt-info)
     (let ((*relevant-mt-function* 'relevant-mt-is-genl-mt-of-list-member)
           ;; missing-larkc 12319 likely extracts the mt-list from the MtUnionFn naut
           (*relevant-mts* (missing-larkc 12319)))
       (some-all-spec-preds-and-inverses predicate
                                         'some-conservative-via-arg-assertion?)))
    (t
     (let ((*relevant-mt-function* 'relevant-mt-is-genl-mt)
           (*mt* mt-info))
       (some-all-spec-preds-and-inverses predicate
                                         'some-conservative-via-arg-assertion?)))))

;; (defun remove-cached-some-cva-for-predicate (predicate &optional mt-info) ...) -- active declareFunction, no body

;; The cached-tva-spec-preds-and-inverses group is globally cached but all bodies are stripped.
(deflexical *cached-tva-spec-preds-and-inverses-caching-state* nil)

;; (defun tva-spec-preds-and-inverses (pred) ...) -- active declareFunction, no body
;; (defun clear-cached-tva-spec-preds-and-inverses () ...) -- active declareFunction, no body
;; (defun remove-cached-tva-spec-preds-and-inverses (pred mt relevant-mt-function) ...) -- active declareFunction, no body
;; (defun cached-tva-spec-preds-and-inverses-internal (pred mt relevant-mt-function) ...) -- active declareFunction, no body
;; (defun cached-tva-spec-preds-and-inverses (pred mt relevant-mt-function) ...) -- active declareFunction, no body

(defun tva-gather-transitive-predicates-for-arg (tva-pred index-pred argnum inverse?)
  "[Cyc] @return listp; Returns the transitive predicates, X, s.t. (TVA-PRED INDEX-PRED X ARGNUM)."
  (when (some-pred-assertion-somewhere? tva-pred index-pred 1)
    (pred-arg-values index-pred tva-pred
                     (determine-tva-gather-argnum argnum inverse?)
                     1 3 2)))

;; Reconstructed from Internal Constants:
;; $list57 = ((TRANS-PRED-VAR TVA-PRED PRED ARGNUM INVERSE?) &BODY BODY)
;; $sym58 = CDOLIST, $sym59 = TVA-GATHER-TRANSITIVE-PREDICATES-FOR-ARG
(defmacro do-trans-preds-for-arg-with-mode ((trans-pred-var tva-pred pred argnum inverse?) &body body)
  `(dolist (,trans-pred-var (tva-gather-transitive-predicates-for-arg ,tva-pred ,pred ,argnum ,inverse?))
     ,@body))

(defun any-tva-for-arg? (pred argnum)
  "[Cyc] For PRED, are there any tva assertions that apply to arg ARGNUM?"
  (cached-any-tva-for-arg? pred argnum *mt* *relevant-mt-function*))

;; State-dependent memoized function. The Java has an explicit _internal function
;; and memoization wrapper; defun-memoized handles both.
;; The _internal body is an inline expansion of an SBHL spec-preds-and-inverses
;; traversal using the genlPreds module (backward BFS), checking each spec-pred
;; (with inverse mode) against get-tva-predicates for arg applicability.
(defun-memoized cached-any-tva-for-arg? (pred argnum mt relevant-mt-function)
    (:test equal)
  (let ((found? nil))
    (let ((node-var pred)
          (deck-type :queue)
          (recur-deck (create-deck deck-type))
          (node-and-predicate-mode nil))
      (let ((*sbhl-space* (get-sbhl-marking-space)))
        (let ((tv-var nil))
          (let ((*sbhl-tv* (or tv-var (get-sbhl-true-tv)))
                (*relevant-sbhl-tv-function*
                  (if tv-var
                      'relevant-sbhl-tv-is-general-tv
                      *relevant-sbhl-tv-function*)))
            (when tv-var
              (sbhl-check-type tv-var sbhl-true-tv-p))
            (let ((*sbhl-search-module* (get-sbhl-module #$genlPreds))
                  (*sbhl-search-module-type*
                    (get-sbhl-module-type (get-sbhl-module #$genlPreds)))
                  (*sbhl-add-node-to-result-test*
                    (get-sbhl-add-node-to-result-test (get-sbhl-module #$genlPreds)))
                  (*genl-inverse-mode-p* nil)
                  (*sbhl-module* (get-sbhl-module #$genlPreds)))
              (if (or (suspend-sbhl-type-checking?)
                      (apply-sbhl-module-type-test pred (get-sbhl-module)))
                  (let ((*sbhl-search-direction* (get-sbhl-backward-search-direction))
                        (*sbhl-link-direction*
                          (sbhl-search-direction-to-link-direction
                           (get-sbhl-backward-search-direction)
                           (get-sbhl-module #$genlPreds)))
                        (*genl-inverse-mode-p* nil))
                    (sbhl-mark-node-marked node-var)
                    (setf node-and-predicate-mode
                          (list pred (genl-inverse-mode-p)))
                    (loop while (and node-and-predicate-mode (not found?)) do
                      (let* ((node-var-27 (first node-and-predicate-mode))
                             (predicate-mode (second node-and-predicate-mode))
                             (spec-pred node-var-27))
                        (let ((*genl-inverse-mode-p* predicate-mode))
                          (let ((inverse-mode? predicate-mode))
                            (when (not found?)
                              (csome (tva-pred (get-tva-predicates) found?)
                                (when (tva-gather-transitive-predicates-for-arg
                                       tva-pred spec-pred argnum inverse-mode?)
                                  (setf found? t))))
                            (csome (module-var
                                    (get-sbhl-accessible-modules
                                     (get-sbhl-module #$genlPreds))
                                    found?)
                              (let ((*sbhl-module* module-var)
                                    (*genl-inverse-mode-p*
                                      (if (flip-genl-inverse-mode?)
                                          (not *genl-inverse-mode-p*)
                                          *genl-inverse-mode-p*)))
                                (let ((node (naut-to-nart node-var-27)))
                                  (if (sbhl-node-object-p node)
                                      (let ((d-link (get-sbhl-graph-link
                                                     node (get-sbhl-module))))
                                        (if d-link
                                            (let ((mt-links
                                                    (get-sbhl-mt-links
                                                     d-link
                                                     (get-sbhl-link-direction)
                                                     (get-sbhl-module))))
                                              (when mt-links
                                                (maphash
                                                 (lambda (mt tv-links)
                                                   (unless found?
                                                     (when (relevant-mt? mt)
                                                       (let ((*sbhl-link-mt* mt))
                                                         (maphash
                                                          (lambda (tv link-nodes)
                                                            (unless found?
                                                              (when (relevant-sbhl-tv? tv)
                                                                (let ((*sbhl-link-tv* tv))
                                                                  (let ((new-list
                                                                          (if (sbhl-randomize-lists-p)
                                                                              (missing-larkc 9338)
                                                                              link-nodes)))
                                                                    (dolist (node-vars-link-node new-list)
                                                                      (unless found?
                                                                        (unless (sbhl-search-path-termination-p
                                                                                 node-vars-link-node)
                                                                          (sbhl-mark-node-marked
                                                                           node-vars-link-node)
                                                                          (deck-push
                                                                           (list node-vars-link-node
                                                                                 (genl-inverse-mode-p))
                                                                           recur-deck)))))))))
                                                          tv-links)))))
                                                 mt-links)))
                                            (sbhl-error 5 "attempting to bind direction link variable, to NIL. macro body not executed.")))
                                      (when (cnat-p node)
                                        (let ((new-list
                                                (if (sbhl-randomize-lists-p)
                                                    (missing-larkc 9339)
                                                    (missing-larkc 2749))))
                                          (dolist (generating-fn new-list)
                                            (unless found?
                                              (let ((*sbhl-link-generator* generating-fn))
                                                (let ((link-nodes (funcall generating-fn node)))
                                                  (let ((new-list-38
                                                          (if (sbhl-randomize-lists-p)
                                                              (missing-larkc 9340)
                                                              link-nodes)))
                                                    (dolist (node-vars-link-node new-list-38)
                                                      (unless found?
                                                        (unless (sbhl-search-path-termination-p
                                                                 node-vars-link-node)
                                                          (sbhl-mark-node-marked
                                                           node-vars-link-node)
                                                          (deck-push
                                                           (list node-vars-link-node
                                                                 (genl-inverse-mode-p))
                                                           recur-deck)))))))))))))))))
                      (setf node-and-predicate-mode (deck-pop recur-deck))))
                  (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                             pred (get-sbhl-type-test (get-sbhl-module)))))))
          (free-sbhl-marking-space *sbhl-space*))))
    found?))

;; (defun tva-direction-for-tva-pred (tva-pred) ...) -- active declareFunction, no body
;; (defun tva-direction-to-sbhl-direction (direction) ...) -- active declareFunction, no body
;; (defun tva-direction-to-ghl-direction (direction) ...) -- active declareFunction, no body
;; (defun tva-direction-to-ghl-closure-direction (direction) ...) -- active declareFunction, no body

(defun determine-tva-gather-argnum (argnum inverse?)
  (if inverse?
      (other-binary-arg argnum)
      argnum))

;; Reconstructed from Internal Constants:
;; $list68 = ((ARGNUM-VAR) &BODY BODY)
;; $list69 = ((TVA-TERM-ARGNUMS))
(defmacro do-tva-term-argnums ((argnum-var) &body body)
  `(dolist (,argnum-var (tva-term-argnums))
     ,@body))

;; (defun tva-precomputation-p (assertion) ...) -- active declareFunction, no body
;; (defun tva-unify-vars (asent) ...) -- active declareFunction, no body
;; (defun tva-support-module-for-pred (tva-pred) ...) -- active declareFunction, no body
;; (defun genl-preds-support-from-pred-to-pred (from-pred to-pred mt) ...) -- active declareFunction, no body
;; (defun genl-preds-support-from-pred-to-tva-pred (from-pred tva-pred) ...) -- active declareFunction, no body
;; (defun tva-assertion-support (tva-pred index-pred argnum trans-pred) ...) -- active declareFunction, no body


;;; Setup phase

(toplevel
  (declare-defglobal '*tva-precomputes-sksi-closures?*)
  (declare-defglobal '*tva-iterates-kb-predicate-extent?*)
  (declare-defglobal '*tva-iterates-sksi-predicate-extent?*)
  (note-globally-cached-function 'cached-tva-spec-preds-and-inverses))
