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

;; Functions in declareFunction order:

(defun removal-genlpreds-lookup-pos-cost (asent &optional sense)
  (declare (ignore sense))
  (if (fully-bound-p asent)
      *typical-hl-module-check-cost*
      (num-best-genlpreds-gaf-lookup-index asent :pos)))

(defun removal-genlpreds-lookup-pos-iterator (asent)
  (removal-genlpreds-lookup-iterator asent :pos))

;; (defun removal-genlpreds-lookup-neg-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-genlpreds-lookup-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-genlpreds-lookup-neg-iterator (asent) ...) -- active declareFunction, no body

(defun removal-genlpreds-lookup-iterator (asent sense)
  (let ((result nil)
        (lookup-index (best-genlpreds-gaf-lookup-index asent sense))
        (index-type (lookup-index-get-type lookup-index)))
    (let ((*inference-literal* asent)
          (*relevant-pred-function* (determine-inference-genl-or-spec-pred-relevance sense))
          (*inference-sense* sense))
      (case index-type
        (:predicate-extent
         (let ((predicate
                 ;; Likely extracts the predicate from the lookup index for predicate-extent type
                 (missing-larkc 12760))
               (pred-var nil))
           (when (do-gaf-arg-index-key-validator predicate 0 pred-var)
             (let ((iterator-var (new-gaf-arg-final-index-spec-iterator predicate 0 pred-var))
                   (done-var nil)
                   (token-var nil))
               (until done-var
                 (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                        (valid (not (eq token-var final-index-spec))))
                   (when valid
                     (let ((final-index-iterator nil))
                       (unwind-protect
                            (progn
                              (setf final-index-iterator
                                    (new-final-index-iterator final-index-spec :gaf (sense-truth sense) nil))
                              (let ((done-var-1 nil)
                                    (token-var-2 nil))
                                (until done-var-1
                                  (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                         (valid-3 (not (eq token-var-2 assertion))))
                                    (when valid-3
                                      (let ((bindings-assertion (removal-genlpreds-gaf-iterator-internal assertion)))
                                        (when bindings-assertion
                                          (push bindings-assertion result))))
                                    (setf done-var-1 (not valid-3))))))
                         (when final-index-iterator
                           (destroy-final-index-iterator final-index-iterator)))))
                   (setf done-var (not valid))))))))
        (:gaf-arg
         (multiple-value-bind (v-term argnum predicate) (lookup-index-gaf-arg-values lookup-index)
           (declare (ignore predicate))
           (let ((pred-var nil))
             (when (do-gaf-arg-index-key-validator v-term argnum pred-var)
               (let ((iterator-var (new-gaf-arg-final-index-spec-iterator v-term argnum pred-var))
                     (done-var nil)
                     (token-var nil))
                 (until done-var
                   (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                          (valid (not (eq token-var final-index-spec))))
                     (when valid
                       (let ((final-index-iterator nil))
                         (unwind-protect
                              (progn
                                (setf final-index-iterator
                                      (new-final-index-iterator final-index-spec :gaf (sense-truth sense) nil))
                                (let ((done-var-5 nil)
                                      (token-var-6 nil))
                                  (until done-var-5
                                    (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token-var-6))
                                           (valid-7 (not (eq token-var-6 assertion))))
                                      (when valid-7
                                        (let ((bindings-assertion (removal-genlpreds-gaf-iterator-internal assertion)))
                                          (when bindings-assertion
                                            (push bindings-assertion result))))
                                      (setf done-var-5 (not valid-7))))))
                           (when final-index-iterator
                             (destroy-final-index-iterator final-index-iterator)))))
                     (setf done-var (not valid))))))))))
    (when result
      (new-list-iterator result)))))

;; Variable

(defglobal *unknown-el-variable* '?unknown)

(defun obfuscate-predicate (asent)
  (replace-formula-arg 0 *unknown-el-variable* asent))

(defun best-genlpreds-gaf-lookup-index (asent sense)
  (best-gaf-lookup-index (obfuscate-predicate asent) (sense-truth sense) '(:predicate-extent :gaf-arg)))

(defun num-best-genlpreds-gaf-lookup-index (asent sense)
  (num-best-genlpreds-or-inverse-gaf-lookup-index asent sense nil))

(defun num-best-genlpreds-or-inverse-gaf-lookup-index (asent sense inverse-mode?)
  (let* ((direction (if (eq sense :pos)
                        (get-sbhl-backward-search-direction)
                        (get-sbhl-forward-search-direction)))
         (pred (sentence-arg0 asent))
         (binary-predicate-mode? (binary-predicate? (sentence-arg0 asent)))
         (gaf-argnum (first (determine-term-argnums asent)))
         (v-term (sentence-arg asent gaf-argnum))
         (num 0)
         (module (get-sbhl-module #$genlPreds))
         (node-var pred)
         (deck-type :queue)
         (recur-deck (create-deck deck-type))
         (node-and-predicate-mode nil))
    (let ((*sbhl-space* (get-sbhl-marking-space)))
      (unwind-protect
           (progn
             (let* ((tv-var nil)
                    (*sbhl-tv* (if tv-var tv-var (get-sbhl-true-tv)))
                    (*relevant-sbhl-tv-function* (if tv-var
                                                     #'relevant-sbhl-tv-is-general-tv
                                                     *relevant-sbhl-tv-function*)))
               (when tv-var
                 (when (sbhl-object-type-checking-p)
                   (unless (sbhl-true-tv-p tv-var)
                     (case *sbhl-type-error-action*
                       (:error
                        (sbhl-error 1 "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                       (:cerror
                        ;; Likely calls sbhl-cerror for continue-anyway error
                        (missing-larkc 2133))
                       (:warn
                        (warn "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                       (otherwise
                        (warn "~A is not a valid *sbhl-type-error-action* value" *sbhl-type-error-action*)
                        (cerror "continue anyway" "~A is not a ~A" tv-var 'sbhl-true-tv-p))))))
               (let ((*sbhl-search-module* module)
                     (*sbhl-search-module-type* (get-sbhl-module-type module))
                     (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
                     (*genl-inverse-mode-p* nil)
                     (*sbhl-module* module))
                 (if (or (suspend-sbhl-type-checking?)
                         (apply-sbhl-module-type-test pred (get-sbhl-module)))
                     (let ((*sbhl-search-direction* direction)
                           (*sbhl-link-direction* (sbhl-search-direction-to-link-direction direction module))
                           (*genl-inverse-mode-p* nil))
                       (sbhl-mark-node-marked node-var)
                       (setf node-and-predicate-mode (list pred (genl-inverse-mode-p)))
                       (while node-and-predicate-mode
                         (let* ((node-var-15 (first node-and-predicate-mode))
                                (predicate-mode (second node-and-predicate-mode))
                                (spec-pred node-var-15))
                           (let ((*genl-inverse-mode-p* predicate-mode))
                             (let ((inverse? predicate-mode))
                               (unless (or (eq pred spec-pred)
                                           (not (eq inverse-mode? inverse?)))
                                 (if binary-predicate-mode?
                                     (incf num (num-gaf-arg-index v-term gaf-argnum spec-pred))
                                     (incf num (num-best-gaf-lookup-index
                                                (replace-formula-arg 0 spec-pred asent)
                                                (sense-truth sense)
                                                '(:predicate-extent :gaf-arg)))))
                               (dolist (module-var (get-sbhl-accessible-modules module))
                                 (let ((*sbhl-module* module-var)
                                       (*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                                                  (not *genl-inverse-mode-p*)
                                                                  *genl-inverse-mode-p*)))
                                   (let ((node (naut-to-nart node-var-15)))
                                     (if (sbhl-node-object-p node)
                                         (let ((d-link (get-sbhl-graph-link node (get-sbhl-module))))
                                           (when d-link
                                             (let ((mt-links (get-sbhl-mt-links d-link (get-sbhl-link-direction) (get-sbhl-module))))
                                               (when mt-links
                                                 (do-hash-table (mt tv-links mt-links)
                                                   (when (relevant-mt? mt)
                                                     (let ((*sbhl-link-mt* mt))
                                                       (do-hash-table (tv link-nodes tv-links)
                                                         (when (relevant-sbhl-tv? tv)
                                                           (let ((*sbhl-link-tv* tv))
                                                             (let ((new-list (if (sbhl-randomize-lists-p)
                                                                                 ;; Likely randomizes the list for search diversity
                                                                                 (missing-larkc 9274)
                                                                                 link-nodes)))
                                                               (dolist (node-vars-link-node new-list)
                                                                 (unless (sbhl-search-path-termination-p node-vars-link-node)
                                                                   (sbhl-mark-node-marked node-vars-link-node)
                                                                   (deck-push (list node-vars-link-node (genl-inverse-mode-p)) recur-deck))))))))))))))
                                         (when (cnat-p node)
                                           (let ((new-list (if (sbhl-randomize-lists-p)
                                                               ;; Likely randomizes the list for search diversity
                                                               (missing-larkc 9275)
                                                               ;; Likely gets generating functions for the NART node
                                                               (missing-larkc 2603))))
                                             (dolist (generating-fn new-list)
                                               (let ((*sbhl-link-generator* generating-fn))
                                                 (let ((link-nodes (funcall generating-fn node)))
                                                   (let ((new-list-25 (if (sbhl-randomize-lists-p)
                                                                          ;; Likely randomizes the list for search diversity
                                                                          (missing-larkc 9276)
                                                                          link-nodes)))
                                                     (dolist (node-vars-link-node new-list-25)
                                                       (unless (sbhl-search-path-termination-p node-vars-link-node)
                                                         (sbhl-mark-node-marked node-vars-link-node)
                                                         (deck-push (list node-vars-link-node (genl-inverse-mode-p)) recur-deck)))))))))))))))
                         (setf node-and-predicate-mode (deck-pop recur-deck))))
                     (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%" pred
                                (get-sbhl-type-test (get-sbhl-module)))))))
        (free-sbhl-marking-space *sbhl-space*)))
    num)))

(defun removal-genlpreds-gaf-iterator-internal (assertion)
  (when (direction-is-relevant assertion)
    (let* ((assertion-asent (gaf-formula assertion))
           (ass-pred (atomic-sentence-predicate assertion-asent))
           (inf-pred (atomic-sentence-predicate *inference-literal*)))
      (when (not (eq ass-pred inf-pred))
        (multiple-value-bind (v-bindings gaf-asent unify-justification)
            (gaf-asent-args-unify *inference-literal* assertion-asent)
          (declare (ignore gaf-asent unify-justification))
          (when v-bindings
            (list v-bindings assertion)))))))

(defun removal-genlpreds-lookup-supports (asent assertion sense)
  (let* ((ass-pred (atomic-sentence-predicate (gaf-formula assertion)))
         (inf-pred (atomic-sentence-predicate asent))
         (spec-pred (if (eq :pos sense) ass-pred inf-pred))
         (genl-pred (if (eq :pos sense) inf-pred ass-pred))
         (hl-support (make-genl-preds-support spec-pred genl-pred)))
    (multiple-value-bind (v-bindings gaf-asent unify-justification)
        (gaf-asent-args-unify asent (gaf-formula assertion) t t)
      (declare (ignore v-bindings gaf-asent))
      (append (list assertion hl-support) unify-justification))))

;; (defun removal-genlpreds-pred-index-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-genlpreds-pred-index-pos-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-genlpreds-pred-index-neg-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-genlpreds-pred-index-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-genlpreds-pred-index-neg-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-genlpreds-pred-index-iterator (asent sense) ...) -- active declareFunction, no body

(defun removal-genlinverse-lookup-pos-cost (asent &optional sense)
  (declare (ignore sense))
  (if (fully-bound-p asent)
      *typical-hl-module-check-cost*
      (num-best-genlinverse-gaf-lookup-index asent :pos)))

(defun removal-genlinverse-lookup-pos-iterator (asent)
  (removal-genlinverse-lookup-iterator asent :pos))

;; (defun removal-genlinverse-lookup-neg-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-genlinverse-lookup-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-genlinverse-lookup-neg-iterator (asent) ...) -- active declareFunction, no body

(defun removal-genlinverse-lookup-iterator (asent sense)
  (let ((result nil)
        (lookup-index (best-genlinverse-gaf-lookup-index asent sense))
        (index-type (lookup-index-get-type lookup-index)))
    (let ((*relevant-pred-function* (determine-inference-genl-or-spec-inverse-relevance sense))
          (*inference-literal* asent)
          (*inference-sense* sense))
      (case index-type
        (:predicate-extent
         (let ((predicate
                 ;; Likely extracts the predicate from the lookup index for predicate-extent type
                 (missing-larkc 12761))
               (pred-var nil))
           (when (do-gaf-arg-index-key-validator predicate 0 pred-var)
             (let ((iterator-var (new-gaf-arg-final-index-spec-iterator predicate 0 pred-var))
                   (done-var nil)
                   (token-var nil))
               (until done-var
                 (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                        (valid (not (eq token-var final-index-spec))))
                   (when valid
                     (let ((final-index-iterator nil))
                       (unwind-protect
                            (progn
                              (setf final-index-iterator
                                    (new-final-index-iterator final-index-spec :gaf (sense-truth sense) nil))
                              (let ((done-var-31 nil)
                                    (token-var-32 nil))
                                (until done-var-31
                                  (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token-var-32))
                                         (valid-33 (not (eq token-var-32 assertion))))
                                    (when valid-33
                                      (let ((bindings-assertion
                                              ;; Likely processes an assertion for genl-inverse gaf iteration
                                              (missing-larkc 32783)))
                                        (when bindings-assertion
                                          (push bindings-assertion result))))
                                    (setf done-var-31 (not valid-33))))))
                         (when final-index-iterator
                           (destroy-final-index-iterator final-index-iterator)))))
                   (setf done-var (not valid))))))))
        (:gaf-arg
         (multiple-value-bind (v-term argnum predicate) (lookup-index-gaf-arg-values lookup-index)
           (declare (ignore predicate))
           (let ((pred-var nil))
             (when (do-gaf-arg-index-key-validator v-term argnum pred-var)
               (let ((iterator-var (new-gaf-arg-final-index-spec-iterator v-term argnum pred-var))
                     (done-var nil)
                     (token-var nil))
                 (until done-var
                   (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                          (valid (not (eq token-var final-index-spec))))
                     (when valid
                       (let ((final-index-iterator nil))
                         (unwind-protect
                              (progn
                                (setf final-index-iterator
                                      (new-final-index-iterator final-index-spec :gaf (sense-truth sense) nil))
                                (let ((done-var-35 nil)
                                      (token-var-36 nil))
                                  (until done-var-35
                                    (let* ((assertion (iteration-next-without-values-macro-helper final-index-iterator token-var-36))
                                           (valid-37 (not (eq token-var-36 assertion))))
                                      (when valid-37
                                        (let ((bindings-assertion
                                                ;; Likely processes an assertion for genl-inverse gaf iteration
                                                (missing-larkc 32784)))
                                          (when bindings-assertion
                                            (push bindings-assertion result))))
                                      (setf done-var-35 (not valid-37))))))
                           (when final-index-iterator
                             (destroy-final-index-iterator final-index-iterator)))))
                     (setf done-var (not valid))))))))))
    (when result
      (new-list-iterator result)))))

(defun best-genlinverse-gaf-lookup-index (asent sense)
  (best-gaf-lookup-index (obfuscate-predicate (symmetric-asent asent))
                          (sense-truth sense)
                          '(:predicate-extent :gaf-arg)))

(defun num-best-genlinverse-gaf-lookup-index (asent sense)
  (num-best-genlpreds-or-inverse-gaf-lookup-index asent sense t))

;; (defun removal-genlinverse-gaf-iterator-internal (asent assertion) ...) -- active declareFunction, no body
;; (defun removal-genlinverse-lookup-supports (asent assertion sense) ...) -- active declareFunction, no body
;; (defun removal-genlinverse-pred-index-pos-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-genlinverse-pred-index-pos-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-genlinverse-pred-index-neg-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-genlinverse-pred-index-neg-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-genlinverse-pred-index-neg-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-genlinverse-pred-index-iterator (asent sense) ...) -- active declareFunction, no body
;; (defun removal-negationpreds-lookup-completeness (asent) ...) -- active declareFunction, no body
;; (defun removal-negationpreds-lookup-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-negationpreds-lookup-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-negationpreds-gaf-iterator-internal (asent) ...) -- active declareFunction, no body
;; (defun removal-negationpreds-lookup-supports (asent assertion) ...) -- active declareFunction, no body
;; (defun removal-negationinverse-lookup-iterator (asent) ...) -- active declareFunction, no body
;; (defun removal-negationinverse-gaf-iterator-internal (asent) ...) -- active declareFunction, no body
;; (defun removal-negationinverse-lookup-supports (asent assertion) ...) -- active declareFunction, no body

;; Setup / toplevel forms

(toplevel
  (declare-defglobal '*unknown-el-variable*))

(toplevel
  (inference-removal-module :removal-genlpreds-lookup-pos
    (list :sense :pos
          :arity nil
          :required-pattern '(:and ((:test non-hl-predicate-p) . :anything)
                                   (:test asent-has-indexed-term-arg-p)
                                   ((:test inference-some-spec-pred-or-inverse?) . :anything))
          :cost 'removal-genlpreds-lookup-pos-cost
          :completeness :incomplete
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-genlpreds-lookup-pos-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-genlpreds-lookup-supports (:value asent) (:value assertion) :pos)
          :documentation "(<predicate> ... <indexed-term> ... )
using true assertions using spec-preds of <predicate>"
          :example "(#$geopoliticalSubdivision #$France #$CityOfParisFrance)")))

(toplevel
  (inference-removal-module :removal-genlpreds-lookup-neg
    (list :sense :neg
          :arity nil
          :required-pattern '(:and ((:test non-hl-predicate-p) . :anything)
                                   (:test asent-has-indexed-term-arg-p)
                                   ((:test inference-some-genl-pred-or-inverse?) . :anything))
          :cost 'removal-genlpreds-lookup-neg-cost
          :completeness-pattern '(:call removal-genlpreds-lookup-neg-completeness :input)
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-genlpreds-lookup-neg-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-genlpreds-lookup-supports (:value asent) (:value assertion) :neg)
          :documentation "(#$not (<predicate> ... <indexed-term> ... ))
using false assertions using genl-preds of <predicate>")))

(toplevel
  (inference-removal-module :removal-genlpreds-pred-index-pos
    (list :sense :pos
          :arity nil
          :required-pattern '(:and ((:test non-hl-predicate-p) . :anything)
                                   (:not (:test asent-has-indexed-term-arg-p))
                                   ((:test inference-some-spec-pred-or-inverse?) . :anything))
          :cost 'removal-genlpreds-pred-index-pos-cost
          :completeness :incomplete
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-genlpreds-pred-index-pos-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-genlpreds-lookup-supports (:value asent) (:value assertion) :pos)
          :documentation "(<predicate> <non-indexed-term> ... <non-indexed-term>)
using true assertions using spec-preds of <predicate>"
          :example "(#$spatiallyIntersects ?WHAT ?WHAT-ELSE)")))

(toplevel
  (inference-removal-module :removal-genlpreds-pred-index-neg
    (list :sense :neg
          :arity nil
          :required-pattern '(:and ((:test non-hl-predicate-p) . :anything)
                                   (:not (:test asent-has-indexed-term-arg-p))
                                   ((:test inference-some-genl-pred-or-inverse?) . :anything))
          :cost 'removal-genlpreds-pred-index-neg-cost
          :completeness-pattern '(:call removal-genlpreds-pred-index-neg-completeness :input)
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-genlpreds-pred-index-neg-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-genlpreds-lookup-supports (:value asent) (:value assertion) :neg)
          :documentation "(#$not (<predicate> <non-indexed-term> ... <non-indexed-term> ))
using false assertions using genl-preds of <predicate>"
          :example "(#$not (#$spatiallyIntersects ?WHAT ?WHAT-ELSE))")))

(toplevel
  (inference-removal-module :removal-genlinverse-lookup-pos
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything)
                                   (:test asent-has-indexed-term-arg-p)
                                   ((:test inference-some-spec-pred-or-inverse?) . :anything))
          :cost 'removal-genlinverse-lookup-pos-cost
          :completeness :incomplete
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-genlinverse-lookup-pos-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-genlinverse-lookup-supports (:value asent) (:value assertion) :pos)
          :documentation "(<predicate> <indexed-term> <whatever>) and
(<predicate> <whatever> <indexed-term>)
using true assertions using spec-inverses of <predicate>")))

(toplevel
  (inference-removal-module :removal-genlinverse-lookup-neg
    (list :sense :neg
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything)
                                   (:test asent-has-indexed-term-arg-p)
                                   ((:test inference-some-genl-pred-or-inverse?) . :anything))
          :cost 'removal-genlinverse-lookup-neg-cost
          :completeness-pattern '(:call removal-genlinverse-lookup-neg-completeness :input)
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-genlinverse-lookup-neg-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-genlinverse-lookup-supports (:value asent) (:value assertion) :neg)
          :documentation "(#$not (<predicate> <indexed-term> <whatever>)) and
(#$not (<predicate> <whatever> <indexed-term>))
using false assertions using genl-inverses of <predicate>")))

(toplevel
  (inference-removal-module :removal-genlinverse-pred-index-pos
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything)
                                   (:not (:test asent-has-indexed-term-arg-p))
                                   ((:test inference-some-spec-pred-or-inverse?) . :anything))
          :cost 'removal-genlinverse-pred-index-pos-cost
          :completeness :incomplete
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-genlinverse-pred-index-pos-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-genlinverse-lookup-supports (:value asent) (:value assertion) :pos)
          :documentation "(<predicate> <non-indexed-term> <non-indexed-term> )
using true assertions using spec-inverses of <predicate>")))

(toplevel
  (inference-removal-module :removal-genlinverse-pred-index-neg
    (list :sense :neg
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p) :anything :anything)
                                   (:not (:test asent-has-indexed-term-arg-p))
                                   ((:test inference-some-genl-pred-or-inverse?) . :anything))
          :cost 'removal-genlinverse-pred-index-neg-cost
          :completeness-pattern '(:call removal-genlinverse-pred-index-neg-completeness :input)
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-genlinverse-pred-index-neg-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-genlinverse-lookup-supports (:value asent) (:value assertion) :neg)
          :documentation "(#$not (<predicate> <non-indexed-term> <non-indexed-term> ))
using false assertions using genl-inverses of <predicate>")))

(toplevel
  (inference-removal-module :removal-negationpreds-lookup
    (list :sense :neg
          :arity nil
          :required-pattern '(:and ((:test non-hl-predicate-p) . :anything)
                                   (:test asent-has-indexed-term-arg-p)
                                   ((:test inference-some-negation-pred-or-inverse?) . :anything))
          :cost 'removal-negationpreds-lookup-cost
          :completeness-pattern '(:call removal-negationpreds-lookup-completeness :input)
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-negationpreds-lookup-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-negationpreds-lookup-supports (:value asent) (:value assertion))
          :documentation "(#$not (<predicate> ... <indexed-term> ... ))
using true assertions using negation-preds of <predicate>")))

(toplevel
  (inference-removal-module :removal-negationinverse-lookup
    (list :sense :neg
          :arity nil
          :required-pattern '(:and ((:test non-hl-predicate-p) . :anything)
                                   (:test asent-has-indexed-term-arg-p)
                                   ((:test inference-some-negation-pred-or-inverse?) . :anything))
          :cost 'removal-negationpreds-lookup-cost
          :completeness-pattern '(:call removal-negationpreds-lookup-completeness :input)
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-negationinverse-lookup-iterator :input)
          :output-decode-pattern '(:template ((:bind bindings) (:bind assertion))
                                             ((:value bindings) (:value assertion)))
          :output-construct-pattern '(:call subst-bindings (:value bindings) (:value asent))
          :support-pattern '(:call removal-negationinverse-lookup-supports (:value asent) (:value assertion))
          :documentation "(#$not (<predicate> ... <indexed-term> ... ))
    using true assertions using negation-inverses of <predicate>")))
