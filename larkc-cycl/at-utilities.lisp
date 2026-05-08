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

;;; Variables from init section

(defglobal *generic-arg-store* nil
  "[Cyc] Association list of number -> generic-arg mappings.")
(defglobal *some-inter-arg-isa-assertion-somewhere-cache* nil)
(defglobal *some-inter-arg-format-assertion-somewhere-cache* nil)
(defparameter *mts-cutoff-for-mts-accommodating-formula-wrt-types* 40
  "[Cyc] max number of mts that will be considered while trying to suggest mts in which non-wf formula might be wf")
(defparameter *max-floor-mts-of-nat-exceptions* nil)
(deflexical *cached-max-floor-mts-of-nat-caching-state* nil)
(defparameter *max-floor-mts-of-nat-recursion?* nil)

;;; Functions ordered per declare_at_utilities_file().

;; (defun arg-n-predicate (n) ...) -- 1 required, 0 optional, no body, commented declareFunction

(defun arg-type-mt (relation args argnum mt)
  (if (and (= argnum 2)
           (mt? (first args))
           (mt-designating-relation? relation))
      (first args)
      mt))

;; (defun find-generic-arg-by-id (id) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun find-generic-arg-id (arg) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun store-generic-arg (id arg) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun stored-generic-arg-p (arg) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun get-generic-arg (arg) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun generic-arg-num (arg) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun generic-arg? (arg) ...) -- 1 required, 0 optional, no body, commented declareFunction

(defun inter-arg-isa-pred (ind-arg dep-arg)
  (cond
    ((eql ind-arg 1)
     (cond
       ((eql dep-arg 2) #$interArgIsa1-2)
       ((eql dep-arg 3) #$interArgIsa1-3)
       ((eql dep-arg 4) #$interArgIsa1-4)
       ((eql dep-arg 5) #$interArgIsa1-5)
       (t (el-error 3 "invalid arg-isa-pred index: ~s-~s" ind-arg dep-arg))))
    ((eql ind-arg 2)
     (cond
       ((eql dep-arg 1) #$interArgIsa2-1)
       ((eql dep-arg 3) #$interArgIsa2-3)
       ((eql dep-arg 4) #$interArgIsa2-4)
       ((eql dep-arg 5) #$interArgIsa2-5)
       (t (el-error 3 "invalid arg-isa-pred index: ~s-~s" ind-arg dep-arg))))
    ((eql ind-arg 3)
     (cond
       ((eql dep-arg 1) #$interArgIsa3-1)
       ((eql dep-arg 2) #$interArgIsa3-2)
       ((eql dep-arg 4) #$interArgIsa3-4)
       ((eql dep-arg 5) #$interArgIsa3-5)
       (t (el-error 3 "invalid arg-isa-pred index: ~s-~s" ind-arg dep-arg))))
    ((eql ind-arg 4)
     (cond
       ((eql dep-arg 1) #$interArgIsa4-1)
       ((eql dep-arg 2) #$interArgIsa4-2)
       ((eql dep-arg 3) #$interArgIsa4-3)
       ((eql dep-arg 5) #$interArgIsa4-5)
       (t (el-error 3 "invalid arg-isa-pred index: ~s-~s" ind-arg dep-arg))))
    ((eql ind-arg 5)
     (cond
       ((eql dep-arg 1) #$interArgIsa5-1)
       ((eql dep-arg 2) #$interArgIsa5-2)
       ((eql dep-arg 3) #$interArgIsa5-3)
       ((eql dep-arg 4) #$interArgIsa5-4)
       (t (el-error 3 "invalid arg-isa-pred index: ~s-~s" ind-arg dep-arg))))
    (t (el-error 3 "invalid arg-isa-pred index: ~s-~s" ind-arg dep-arg)
       nil)))

(defun inter-arg-isa-inverse (ind-arg dep-arg)
  "[Cyc] Returns the appropriate inter-arg-isa predicate for constraining the inverse of IND-ARG and DEP-ARG."
  (when (and (member? ind-arg '(1 2))
             (member? dep-arg '(1 2)))
    (inter-arg-isa-pred dep-arg ind-arg)))

;; (defun inter-arg-not-isa-pred (ind-arg dep-arg) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun inter-arg-not-isa-inverse (ind-arg dep-arg) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun inter-arg-genl-pred (ind-arg dep-arg) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun inter-arg-genl-inverse (ind-arg dep-arg) ...) -- 2 required, 0 optional, no body, commented declareFunction

(defun implication-op? (symbol)
  (member? symbol *implication-operators* #'eq))

(defun logical-op? (symbol)
  (or (isa-logical-connective? symbol *anect-mt*)
      (isa-quantifier? symbol *anect-mt*)))

;; (defun truth-function? (symbol) ...) -- 1 required, 0 optional, no body, commented declareFunction

(defun initialize-all-arg-type-predicate-caches ()
  (let ((count 0))
    (noting-progress ("Initializing all arg type predicate caches...")
      (incf count (initialize-some-inter-arg-isa-assertion-somewhere-cache))
      (incf count (initialize-some-inter-arg-format-assertion-somewhere-cache)))
    count))

(defun clear-all-arg-type-predicate-caches ()
  (clear-some-inter-arg-isa-assertion-somewhere-cache)
  (clear-some-inter-arg-format-assertion-somewhere-cache)
  nil)

;; (defun arg-isa-binary-pred? (pred &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun arg-isa-ternary-pred? (pred &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun arg-isa-predicate? (pred &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun arg-genl-binary-pred? (pred &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun arg-genl-ternary-pred? (pred &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun arg-genl-predicate? (pred &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; commented declareFunction, but body present in Java
(defun formula-denoting-function? (object &optional mt)
  "[Cyc] Is OBJECT a formula-denoting functional expression?"
  (when (relation-expression? object)
    (formula-functor? (nat-functor object) mt)))

;; commented declareFunction, but body present in Java
(defun formula-functor? (functor &optional mt)
  "[Cyc] Does FUNCTOR return a formula?"
  (cond
    ((naut? functor)
     (formula-functor? (find-nart functor) mt))
    ((fort-p functor)
     (let ((formula-functor? nil))
       (dolist (result-isa (result-isa functor mt))
         (when formula-functor? (return))
         (setf formula-functor? (formula-denoting-collection? result-isa)))
       formula-functor?))
    (t nil)))
;; (defun sentence-denoting-function? (object &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun sentence-functor? (functor &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun argn-type-level? (arg level &optional mt) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun min-genl-preds-admitting-fort-as-arg (fort argnum pred &optional mt) ...) -- 3 required, 1 optional, no body, commented declareFunction
;; (defun forts-admitted-as-arg (pred argnum col &optional arg1 arg2 arg3) ...) -- 3 required, 3 optional, no body, commented declareFunction
;; (defun min-implicit-types (fort &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun term-requires-isa-in-relations (v-term relations &optional mt arg1) ...) -- 2 required, 2 optional, no body, commented declareFunction
;; (defun term-requires-genl-in-relations (v-term relations &optional mt arg1) ...) -- 2 required, 2 optional, no body, commented declareFunction
;; (defun term-requires-types-in-relations (v-term relations &optional mt arg1) ...) -- 2 required, 2 optional, no body, commented declareFunction
;; (defun term-requires-isa-in-clause (v-term clause &optional mt) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun term-requires-isa-in-relation (v-term relation &optional mt) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun term-requires-isa-in-formula (v-term formula &optional mt arg1) ...) -- 2 required, 2 optional, no body, commented declareFunction
;; (defun term-requires-genl-in-relation (v-term relation &optional mt) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun get-sub-expression-for-term-position (expression position) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun term-position-requires-types-in-relation (v-term position &optional mt) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun term-requires-types-in-relation (v-term relation &optional mt) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun arg-requires-isa-in-relation (arg relation &optional mt) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun pred-arg-isa-requires-other-arg-isa (pred arg1 arg2 &optional mt) ...) -- 3 required, 1 optional, no body, commented declareFunction
;; (defun make-el-query-literal (literal) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun arg-isa-applicable-gafs (arg) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun gather-via-map-pred-index (arg) ...) -- 1 required, 0 optional, no body, commented declareFunction

(defun inter-arg-isa-cache-initialized? ()
  (set-p *some-inter-arg-isa-assertion-somewhere-cache*))

(defun some-inter-arg-isa-assertion-somewhere-cache-add-int (reln)
  (set-add reln *some-inter-arg-isa-assertion-somewhere-cache*))

;; (defun some-inter-arg-isa-assertion-somewhere-cache-remove-int (reln) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun some-inter-arg-isa-assertion-somewhere-cache-maybe-remove-int (reln) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun some-inter-arg-isa-assertion-somewhere-cache-add (reln) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun some-inter-arg-isa-assertion-somewhere-cache-maybe-remove (reln) ...) -- 1 required, 0 optional, no body, commented declareFunction

(defun clear-some-inter-arg-isa-assertion-somewhere-cache ()
  (if (set-p *some-inter-arg-isa-assertion-somewhere-cache*)
      (clear-set *some-inter-arg-isa-assertion-somewhere-cache*)
      (setf *some-inter-arg-isa-assertion-somewhere-cache* (new-set #'eq)))
  nil)

(defun initialize-some-inter-arg-isa-assertion-somewhere-cache ()
  (clear-some-inter-arg-isa-assertion-somewhere-cache)
  (with-all-mts
    (let ((list-var *arg-positions*))
      (noting-percent-progress ("Initializing #$interArgIsa cache")
        (let ((total (length list-var))
              (sofar 0))
          (dolist (ind-argnum list-var)
            (note-percent-progress sofar total)
            (incf sofar)
            (dolist (dep-argnum *arg-positions*)
              (unless (eql ind-argnum dep-argnum)
                (let ((inter-arg-isa-pred (inter-arg-isa-pred ind-argnum dep-argnum)))
                  (when inter-arg-isa-pred
                    (let ((pred-var inter-arg-isa-pred))
                      (when (do-predicate-extent-index-key-validator pred-var)
                        (let ((iterator-var (new-predicate-extent-final-index-spec-iterator pred-var))
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
                                               (new-final-index-iterator final-index-spec :gaf :true nil))
                                         (let ((done-var-2 nil)
                                               (token-var-2 nil))
                                           (until done-var-2
                                             (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                                    (valid-2 (not (eq token-var-2 ass))))
                                               (when valid-2
                                                 (let ((reln (gaf-arg1 ass)))
                                                   (some-inter-arg-isa-assertion-somewhere-cache-add-int reln)))
                                               (setf done-var-2 (not valid-2))))))
                                    (when final-index-iterator
                                      (destroy-final-index-iterator final-index-iterator)))))
                              (setf done-var (not valid))))))))))))))))
  (set-size *some-inter-arg-isa-assertion-somewhere-cache*))

(defun some-inter-arg-isa-assertion-somewhere? (reln)
  (set-member? reln *some-inter-arg-isa-assertion-somewhere-cache*))

(defun some-inter-arg-isa-constraint-somewhere? (reln)
  (let ((found-one? nil))
    (if (predicate? reln)
        (unless found-one?
          (let* ((module (get-sbhl-module #$genlPreds))
                 (node-var reln)
                 (deck-type :stack)
                 (recur-deck (create-deck deck-type))
                 (node-and-predicate-mode nil))
            (let ((*sbhl-space* (get-sbhl-marking-space)))
              (let ((tv-var nil))
                (let ((*sbhl-tv* (if tv-var tv-var (get-sbhl-true-tv)))
                      (*relevant-sbhl-tv-function*
                        (if tv-var
                            #'relevant-sbhl-tv-is-general-tv
                            *relevant-sbhl-tv-function*)))
                  (when tv-var
                    (when (sbhl-object-type-checking-p)
                      (unless (sbhl-true-tv-p tv-var)
                        (let ((pcase-var *sbhl-type-error-action*))
                          (cond
                            ((eql pcase-var :error)
                             (sbhl-error 1 "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                            ((eql pcase-var :cerror)
                             ;; missing-larkc 2099 likely calls sbhl-cerror for type check
                             (missing-larkc 2099))
                            ((eql pcase-var :warn)
                             (warn "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                            (t
                             (warn "~A is not a valid *sbhl-type-error-action* value"
                                   *sbhl-type-error-action*)
                             (cerror "continue anyway"
                                     "~A is not a ~A" tv-var 'sbhl-true-tv-p)))))))
                  (let ((*sbhl-search-module* module)
                        (*sbhl-search-module-type* (get-sbhl-module-type module))
                        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
                        (*genl-inverse-mode-p* nil)
                        (*sbhl-module* module))
                    (if (or (suspend-sbhl-type-checking?)
                            (apply-sbhl-module-type-test reln (get-sbhl-module)))
                        (let ((*sbhl-search-direction* (get-sbhl-forward-search-direction))
                              (*sbhl-link-direction*
                                (sbhl-search-direction-to-link-direction
                                 (get-sbhl-forward-search-direction) module))
                              (*genl-inverse-mode-p* nil))
                          (sbhl-mark-node-marked node-var)
                          (setf node-and-predicate-mode (list reln (genl-inverse-mode-p)))
                          (loop while (and node-and-predicate-mode (not found-one?))
                                do (let* ((node-var-2 (first node-and-predicate-mode))
                                          (predicate-mode (second node-and-predicate-mode))
                                          (genl-pred node-var-2))
                                     (let ((*genl-inverse-mode-p* predicate-mode))
                                       (let ((inverse-mode predicate-mode))
                                         (declare (ignore inverse-mode))
                                         (when (some-inter-arg-isa-assertion-somewhere? genl-pred)
                                           (setf found-one? t))
                                         (let ((accessible-modules (get-sbhl-accessible-modules module)))
                                           (dolist (module-var accessible-modules)
                                             (when found-one? (return))
                                             (let ((*sbhl-module* module-var)
                                                   (*genl-inverse-mode-p*
                                                     (if (flip-genl-inverse-mode?)
                                                         (not *genl-inverse-mode-p*)
                                                         *genl-inverse-mode-p*)))
                                               (let ((node (naut-to-nart node-var-2)))
                                                 (if (sbhl-node-object-p node)
                                                     (let ((d-link (get-sbhl-graph-link node (get-sbhl-module))))
                                                       (when d-link
                                                         (let ((mt-links (get-sbhl-mt-links
                                                                          d-link
                                                                          (get-sbhl-link-direction)
                                                                          (get-sbhl-module))))
                                                           (when mt-links
                                                             (let ((iteration-state
                                                                     (do-dictionary-contents-state
                                                                      (dictionary-contents mt-links))))
                                                               (until (or found-one?
                                                                          (do-dictionary-contents-done?
                                                                           iteration-state))
                                                                 (multiple-value-bind (mt tv-links)
                                                                     (do-dictionary-contents-key-value
                                                                      iteration-state)
                                                                   (when (relevant-mt? mt)
                                                                     (let ((*sbhl-link-mt* mt))
                                                                       (let ((iteration-state-2
                                                                               (do-dictionary-contents-state
                                                                                (dictionary-contents tv-links))))
                                                                         (until (or found-one?
                                                                                    (do-dictionary-contents-done?
                                                                                     iteration-state-2))
                                                                           (multiple-value-bind (tv link-nodes)
                                                                               (do-dictionary-contents-key-value
                                                                                iteration-state-2)
                                                                             (when (relevant-sbhl-tv? tv)
                                                                               (let ((*sbhl-link-tv* tv))
                                                                                 (let ((new-list
                                                                                         (if (sbhl-randomize-lists-p)
                                                                                             ;; missing-larkc 9234 likely randomizes link-nodes
                                                                                             (missing-larkc 9234)
                                                                                             link-nodes)))
                                                                                   (dolist (node-vars-link-node new-list)
                                                                                     (when found-one? (return))
                                                                                     (unless (sbhl-search-path-termination-p
                                                                                              node-vars-link-node)
                                                                                       (sbhl-mark-node-marked node-vars-link-node)
                                                                                       (deck-push
                                                                                        (list node-vars-link-node
                                                                                              (genl-inverse-mode-p))
                                                                                        recur-deck))))))
                                                                             (setf iteration-state-2
                                                                                   (do-dictionary-contents-next
                                                                                    iteration-state-2))))
                                                                         (do-dictionary-contents-finalize
                                                                          iteration-state-2))))
                                                                   (setf iteration-state
                                                                         (do-dictionary-contents-next
                                                                          iteration-state))))
                                                               (do-dictionary-contents-finalize
                                                                iteration-state))))))
                                                     (when (cnat-p node)
                                                       (let ((new-list
                                                               (if (sbhl-randomize-lists-p)
                                                                   ;; missing-larkc 9235 likely randomizes list
                                                                   (missing-larkc 9235)
                                                                   ;; missing-larkc 2509 likely returns sbhl-link-generators for cnat
                                                                   (missing-larkc 2509))))
                                                         (dolist (generating-fn new-list)
                                                           (when found-one? (return))
                                                           (let ((*sbhl-link-generator* generating-fn))
                                                             (let ((link-nodes (funcall generating-fn node)))
                                                               (let ((new-list-2
                                                                       (if (sbhl-randomize-lists-p)
                                                                           ;; missing-larkc 9236 likely randomizes link-nodes
                                                                           (missing-larkc 9236)
                                                                           link-nodes)))
                                                                 (dolist (node-vars-link-node new-list-2)
                                                                   (when found-one? (return))
                                                                   (unless (sbhl-search-path-termination-p
                                                                            node-vars-link-node)
                                                                     (sbhl-mark-node-marked node-vars-link-node)
                                                                     (deck-push
                                                                      (list node-vars-link-node
                                                                            (genl-inverse-mode-p))
                                                                      recur-deck)))))))))))))))))
                                     (setf node-and-predicate-mode (deck-pop recur-deck))))
                        (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                                   reln (get-sbhl-type-test (get-sbhl-module))))))
                (free-sbhl-marking-space *sbhl-space*)))))
        (setf found-one? (some-inter-arg-isa-assertion-somewhere? reln)))
    found-one?))

(defun inter-arg-format-cache-initialized? ()
  (set-p *some-inter-arg-format-assertion-somewhere-cache*))

;; (defun some-inter-arg-format-assertion-somewhere-cache-add-int (reln) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun some-inter-arg-format-assertion-somewhere-cache-remove-int (reln) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun some-inter-arg-format-assertion-somewhere-cache-maybe-remove-int (reln) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun some-inter-arg-format-assertion-somewhere-cache-add (reln) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun some-inter-arg-format-assertion-somewhere-cache-maybe-remove (reln) ...) -- 1 required, 0 optional, no body, commented declareFunction

(defun clear-some-inter-arg-format-assertion-somewhere-cache ()
  (if (set-p *some-inter-arg-format-assertion-somewhere-cache*)
      (clear-set *some-inter-arg-format-assertion-somewhere-cache*)
      (setf *some-inter-arg-format-assertion-somewhere-cache* (new-set #'eq)))
  nil)

(defun initialize-some-inter-arg-format-assertion-somewhere-cache ()
  (clear-some-inter-arg-format-assertion-somewhere-cache)
  (with-all-mts
    (let ((list-var *arg-positions*))
      (noting-percent-progress ("Initializing #$interArgFormat cache")
        (let ((total (length list-var))
              (sofar 0))
          (dolist (ind-argnum list-var)
            (note-percent-progress sofar total)
            (incf sofar)
            (dolist (dep-argnum *arg-positions*)
              (let ((inter-arg-format-pred (inter-arg-format-pred ind-argnum dep-argnum)))
                (when inter-arg-format-pred
                  (let ((pred-var inter-arg-format-pred))
                    (when (do-predicate-extent-index-key-validator pred-var)
                      (let ((iterator-var (new-predicate-extent-final-index-spec-iterator pred-var))
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
                                             (new-final-index-iterator final-index-spec :gaf :true nil))
                                       (let ((done-var-2 nil)
                                             (token-var-2 nil))
                                         (until done-var-2
                                           (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                                  (valid-2 (not (eq token-var-2 ass))))
                                             (when valid-2
                                               (let ((reln (gaf-arg1 ass)))
                                                 (declare (ignore reln))
                                                 ;; missing-larkc 7243 likely calls
                                                 ;; some-inter-arg-format-assertion-somewhere-cache-add-int
                                                 ;; to add reln to the format cache, paralleling the ISA version
                                                 (missing-larkc 7243)))
                                             (setf done-var-2 (not valid-2))))))
                                  (when final-index-iterator
                                    (destroy-final-index-iterator final-index-iterator)))))
                            (setf done-var (not valid)))))))))))))))
  (set-size *some-inter-arg-format-assertion-somewhere-cache*))

(defun some-inter-arg-format-assertion-somewhere? (reln)
  (set-member? reln *some-inter-arg-format-assertion-somewhere-cache*))

(defun some-inter-arg-format-constraint-somewhere? (reln)
  (let ((found-one? nil))
    (if (predicate? reln)
        (unless found-one?
          (let* ((module (get-sbhl-module #$genlPreds))
                 (node-var reln)
                 (deck-type :stack)
                 (recur-deck (create-deck deck-type))
                 (node-and-predicate-mode nil))
            (let ((*sbhl-space* (get-sbhl-marking-space)))
              (let ((tv-var nil))
                (let ((*sbhl-tv* (if tv-var tv-var (get-sbhl-true-tv)))
                      (*relevant-sbhl-tv-function*
                        (if tv-var
                            #'relevant-sbhl-tv-is-general-tv
                            *relevant-sbhl-tv-function*)))
                  (when tv-var
                    (when (sbhl-object-type-checking-p)
                      (unless (sbhl-true-tv-p tv-var)
                        (let ((pcase-var *sbhl-type-error-action*))
                          (cond
                            ((eql pcase-var :error)
                             (sbhl-error 1 "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                            ((eql pcase-var :cerror)
                             ;; missing-larkc 2100 likely calls sbhl-cerror for type check
                             (missing-larkc 2100))
                            ((eql pcase-var :warn)
                             (warn "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                            (t
                             (warn "~A is not a valid *sbhl-type-error-action* value"
                                   *sbhl-type-error-action*)
                             (cerror "continue anyway"
                                     "~A is not a ~A" tv-var 'sbhl-true-tv-p)))))))
                  (let ((*sbhl-search-module* module)
                        (*sbhl-search-module-type* (get-sbhl-module-type module))
                        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
                        (*genl-inverse-mode-p* nil)
                        (*sbhl-module* module))
                    (if (or (suspend-sbhl-type-checking?)
                            (apply-sbhl-module-type-test reln (get-sbhl-module)))
                        (let ((*sbhl-search-direction* (get-sbhl-forward-search-direction))
                              (*sbhl-link-direction*
                                (sbhl-search-direction-to-link-direction
                                 (get-sbhl-forward-search-direction) module))
                              (*genl-inverse-mode-p* nil))
                          (sbhl-mark-node-marked node-var)
                          (setf node-and-predicate-mode (list reln (genl-inverse-mode-p)))
                          (loop while (and node-and-predicate-mode (not found-one?))
                                do (let* ((node-var-2 (first node-and-predicate-mode))
                                          (predicate-mode (second node-and-predicate-mode))
                                          (genl-pred node-var-2))
                                     (let ((*genl-inverse-mode-p* predicate-mode))
                                       (let ((inverse-mode predicate-mode))
                                         (declare (ignore inverse-mode))
                                         (when (some-inter-arg-format-assertion-somewhere? genl-pred)
                                           (setf found-one? t))
                                         (let ((accessible-modules (get-sbhl-accessible-modules module)))
                                           (dolist (module-var accessible-modules)
                                             (when found-one? (return))
                                             (let ((*sbhl-module* module-var)
                                                   (*genl-inverse-mode-p*
                                                     (if (flip-genl-inverse-mode?)
                                                         (not *genl-inverse-mode-p*)
                                                         *genl-inverse-mode-p*)))
                                               (let ((node (naut-to-nart node-var-2)))
                                                 (if (sbhl-node-object-p node)
                                                     (let ((d-link (get-sbhl-graph-link node (get-sbhl-module))))
                                                       (when d-link
                                                         (let ((mt-links (get-sbhl-mt-links
                                                                          d-link
                                                                          (get-sbhl-link-direction)
                                                                          (get-sbhl-module))))
                                                           (when mt-links
                                                             (let ((iteration-state
                                                                     (do-dictionary-contents-state
                                                                      (dictionary-contents mt-links))))
                                                               (until (or found-one?
                                                                          (do-dictionary-contents-done?
                                                                           iteration-state))
                                                                 (multiple-value-bind (mt tv-links)
                                                                     (do-dictionary-contents-key-value
                                                                      iteration-state)
                                                                   (when (relevant-mt? mt)
                                                                     (let ((*sbhl-link-mt* mt))
                                                                       (let ((iteration-state-2
                                                                               (do-dictionary-contents-state
                                                                                (dictionary-contents tv-links))))
                                                                         (until (or found-one?
                                                                                    (do-dictionary-contents-done?
                                                                                     iteration-state-2))
                                                                           (multiple-value-bind (tv link-nodes)
                                                                               (do-dictionary-contents-key-value
                                                                                iteration-state-2)
                                                                             (when (relevant-sbhl-tv? tv)
                                                                               (let ((*sbhl-link-tv* tv))
                                                                                 (let ((new-list
                                                                                         (if (sbhl-randomize-lists-p)
                                                                                             ;; missing-larkc 9237 likely randomizes link-nodes
                                                                                             (missing-larkc 9237)
                                                                                             link-nodes)))
                                                                                   (dolist (node-vars-link-node new-list)
                                                                                     (when found-one? (return))
                                                                                     (unless (sbhl-search-path-termination-p
                                                                                              node-vars-link-node)
                                                                                       (sbhl-mark-node-marked node-vars-link-node)
                                                                                       (deck-push
                                                                                        (list node-vars-link-node
                                                                                              (genl-inverse-mode-p))
                                                                                        recur-deck))))))
                                                                             (setf iteration-state-2
                                                                                   (do-dictionary-contents-next
                                                                                    iteration-state-2))))
                                                                         (do-dictionary-contents-finalize
                                                                          iteration-state-2))))
                                                                   (setf iteration-state
                                                                         (do-dictionary-contents-next
                                                                          iteration-state))))
                                                               (do-dictionary-contents-finalize
                                                                iteration-state))))))
                                                     (when (cnat-p node)
                                                       (let ((new-list
                                                               (if (sbhl-randomize-lists-p)
                                                                   ;; missing-larkc 9238 likely randomizes list
                                                                   (missing-larkc 9238)
                                                                   ;; missing-larkc 2511 likely returns sbhl-link-generators for cnat
                                                                   (missing-larkc 2511))))
                                                         (dolist (generating-fn new-list)
                                                           (when found-one? (return))
                                                           (let ((*sbhl-link-generator* generating-fn))
                                                             (let ((link-nodes (funcall generating-fn node)))
                                                               (let ((new-list-2
                                                                       (if (sbhl-randomize-lists-p)
                                                                           ;; missing-larkc 9239 likely randomizes link-nodes
                                                                           (missing-larkc 9239)
                                                                           link-nodes)))
                                                                 (dolist (node-vars-link-node new-list-2)
                                                                   (when found-one? (return))
                                                                   (unless (sbhl-search-path-termination-p
                                                                            node-vars-link-node)
                                                                     (sbhl-mark-node-marked node-vars-link-node)
                                                                     (deck-push
                                                                      (list node-vars-link-node
                                                                            (genl-inverse-mode-p))
                                                                      recur-deck)))))))))))))))))
                                     (setf node-and-predicate-mode (deck-pop recur-deck))))
                        (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                                   reln (get-sbhl-type-test (get-sbhl-module))))))
                (free-sbhl-marking-space *sbhl-space*)))))
        (setf found-one? (some-inter-arg-format-assertion-somewhere? reln)))
    found-one?))

;; (defun reln-permits-generic-arg-variables? (reln mt) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun reln-permits-keyword-variables? (reln mt) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun reln-constrained-to-be-collection? (reln argnum mt) ...) -- 3 required, 0 optional, no body, commented declareFunction

(defun constraint-pred-constraint-argnum (pred)
  "[Cyc] Returns the arg-type constraint argnum of the arg constraint predicate PRED.
@owner pace
@note assumes that #$ArgTypeBinaryPredicate and #$ArgTypeTernaryPredicate are ANECTs"
  (cond
    ((or (member? pred *arg-isa-binary-preds*)
         (member? pred *arg-quoted-isa-binary-preds*)
         (member? pred *arg-genl-binary-preds*)
         (member? pred *arg-format-binary-preds*))
     2)
    ((or (member? pred *arg-isa-ternary-preds*)
         (member? pred *arg-quoted-isa-ternary-preds*)
         (member? pred *arg-genl-ternary-preds*)
         (member? pred *arg-format-ternary-preds*))
     3)
    ((or
      ;; missing-larkc 29137 likely checks if pred is an inter-arg-isa binary pred
      (missing-larkc 29137)
      ;; missing-larkc 29135 likely checks if pred is an inter-arg-genl binary pred
      (missing-larkc 29135)
      ;; missing-larkc 29133 likely checks if pred is an inter-arg-format binary pred
      (missing-larkc 29133))
     2)
    ((or
      ;; missing-larkc 29138 likely checks if pred is an inter-arg-isa ternary pred
      (missing-larkc 29138)
      ;; missing-larkc 29136 likely checks if pred is an inter-arg-genl ternary pred
      (missing-larkc 29136)
      ;; missing-larkc 29134 likely checks if pred is an inter-arg-format ternary pred
      (missing-larkc 29134))
     3)
    (t
     ;; missing-larkc 7148 likely signals an error about unexpected arg-type predicate
     (missing-larkc 7148)
     nil)))

;; (defun gaf-arg-type-constraint (gaf) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun gather-at-data (assertion type &optional arg1 arg2) ...) -- 2 required, 2 optional, no body, commented declareFunction

(defun gather-at-data-assertion (assertion &optional (type *at-constraint-type*) (v-term *at-arg*))
  (unless *within-at-suggestion?*
    (gather-at-assertion assertion type v-term)
    (when (integerp *mapping-gather-arg*)
      (let ((constraint (gaf-arg assertion *mapping-gather-arg*)))
        (when (fort-p constraint)
          ;; missing-larkc 7182 likely gathers constraint data for
          ;; fort-typed constraints (e.g. at-defn gathering)
          (missing-larkc 7182)))))
  nil)

;; (defun gather-at-constraint (constraint &optional type v-term) ...) -- 1 required, 2 optional, no body, commented declareFunction

(defun gather-at-assertion (constraint &optional (type :isa) (v-term *at-arg*))
  (when (and *gather-at-assertions?*
             (or (not *at-profile-term*)
                 (equal v-term *at-profile-term*)))
    (cond
      ((eql type :isa)
       (push-hash v-term constraint *at-isa-assertions*))
      ((eql type :genls)
       (push-hash v-term constraint *at-genl-assertions*))
      ((eql type :format)
       (push-hash v-term constraint *at-format-assertions*))
      ((eql type :different)
       (push-hash v-term constraint *at-different-constraints*))))
  nil)

(defun at-finished? (&optional (at-violations? *at-result*))
  (and at-violations?
       (not *accumulating-at-violations?*)
       (not *gather-at-constraints?*)))

;; (defun at-finished (&optional at-violations?) ...) -- 0 required, 1 optional, no body, commented declareFunction
;; (defun at-mapping-finished () ...) -- 0 required, 0 optional, no body, commented declareFunction
;; (defun at-handle-mal-constraint (constraint) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun at-mal-arg-msg (type) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun predicate-isa-violation-data (violation &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun meta-predicate-violation-data (violation &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; commented declareFunction, but body present in Java
(defun semantic-violations ()
  (nreverse (concatenate 'list *arity-violations* *at-violations* *semantic-violations*)))

;; commented declareFunction, but body present in Java
(defun note-at-violation? ()
  (and *noting-at-violations?*
       (or (not *at-violations*)
           *accumulating-at-violations?*)))

;; commented declareFunction, but body present in Java
(defun note-at-violation (note)
  (when (wff-debug?)
    (print note))
  (when (note-at-violation?)
    (setf *current-at-violation* note)
    (unless (recursive-violation? note)
      (unless (member note *at-violations* :test #'equal)
        (push note *at-violations*))))
  *at-violations*)

;; commented declareFunction, but body present in Java
(defun recursive-violation? (note)
  (let ((pcase-var (first note)))
    (cond
      ((eql pcase-var :mal-arg-wrt-col-defn)
       (eq (fifth note) #$CycLSentence-Assertible))
      ((eql pcase-var :mal-arg-wrt-nec-defn)
       (eq (third note) #$CycLSentence-Assertible))
      (t nil))))

(defun reset-at-violations (&optional do-it?)
  (cond
    (do-it?
     (setf *at-violations* nil))
    (*accumulating-at-violations?*)
    (*noting-at-violations?*
     (setf *at-violations* nil)))
  *at-violations*)

(defun reset-arity-violations (&optional do-it?)
  (cond
    (do-it?
     (setf *arity-violations* nil))
    (*accumulating-at-violations?*)
    (*noting-at-violations?*
     (setf *arity-violations* nil)))
  nil)

(defun reset-semantic-violations (&optional do-it?)
  (setf *semantic-violations* nil)
  (reset-at-violations do-it?)
  (reset-arity-violations do-it?)
  nil)

(defun reset-at-state ()
  (reset-arity-violations t)
  (reset-at-violations t)
  nil)

;; (defun suggest-formula-fix-for-at-violation (formula violation) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun assertion-arg-violations-among (violations) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun sef-violations-among (violations) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun predicate-violations-among (violations) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun assertion-arg-violation? (violation) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun assertion-collection? (assertion &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun sef-violation? (violation) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun predicate-violation? (violation) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun assertion-arg-violation-fix (violation) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun strip-mt-literals (formula &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun sef-violation-fix (violation) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun predicate-violation-fix (violation) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; commented declareFunction, but body present in Java
(defun violation-type (violation)
  (when (consp violation)
    (first violation)))
;; (defun mts-accommodating-formula-wrt-types (formula) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun nat-wf-in-some-mt? (nat &optional mt arg2) ...) -- 1 required, 2 optional, no body, commented declareFunction
;; (defun nat-wf-in-some-mt (nat &optional mt arg2) ...) -- 1 required, 2 optional, no body, commented declareFunction
;; (defun nat-wf-default-mts (nat &optional mt arg2) ...) -- 1 required, 2 optional, no body, commented declareFunction
;; (defun formula-forts-isa-mts (formula &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun at-mt-mt-relevant? (mt) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun mts-accommodating-nat (nat &optional mt arg2) ...) -- 1 required, 2 optional, no body, commented declareFunction
;; (defun nat-wf-in-mts (nat &optional mt arg2 arg3) ...) -- 1 required, 3 optional, no body, commented declareFunction
;; (defun clear-cached-max-floor-mts-of-nat () ...) -- 0 required, 0 optional, no body, commented declareFunction
;; (defun remove-cached-max-floor-mts-of-nat (arg1 arg2 arg3 arg4) ...) -- 4 required, 0 optional, no body, commented declareFunction
;; (defun cached-max-floor-mts-of-nat-internal (arg1 arg2 arg3 arg4) ...) -- 4 required, 0 optional, no body, commented declareFunction
;; (defun cached-max-floor-mts-of-nat (arg1 arg2 arg3 arg4) ...) -- 4 required, 0 optional, no body, commented declareFunction
;; (defun fast-max-floor-mts-of-nat (nat &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun max-floor-mts-of-nat (nat &optional mt arg2 arg3) ...) -- 1 required, 3 optional, no body, commented declareFunction
;; (defun max-floor-mts-of-naut (arg1 arg2 arg3 arg4) ...) -- 4 required, 0 optional, no body, commented declareFunction
;; (defun max-floor-mts-of-naut-int (arg1 arg2 arg3) ...) -- 3 required, 0 optional, no body, commented declareFunction
;; (defun admitted-arg-candidate-mt-sets (arg1 arg2 arg3 &optional arg4) ...) -- 3 required, 1 optional, no body, commented declareFunction
;; (defun result-of-max-floor-mts-of-nat (arg1 arg2 &optional arg3) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun max-floor-mts-of-admitted-arg (arg1 arg2 arg3 &optional arg4) ...) -- 3 required, 1 optional, no body, commented declareFunction
;; (defun max-floor-mts-of-nat-benchmark (nat) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun get-random-nart-set (n) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun max-floor-mts-of-admitted-arg-benchmark (&optional arg1) ...) -- 0 required, 1 optional, no body, commented declareFunction
;; (defun get-admitted-by-supports () ...) -- 0 required, 0 optional, no body, commented declareFunction
;; (defun nat-formula-arg-wff-mts (nat) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun nat-function-wff-mts (nat) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun relation-wff-mts (relation) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun candidate-mts-wrt (arg1 arg2) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun nat-arg-wff-wrt-arg-isa-mts (arg1 arg2) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun nat-arg-wff-wrt-arg-genls-mts (arg1 arg2) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun filter-excepted-nat-wff-mts (mts) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun at-note (level format-string &optional arg1 arg2 arg3 arg4 arg5) ...) -- 2 required, 5 optional, no body, commented declareFunction
;; (defun at-error (level format-string &optional arg1 arg2 arg3 arg4 arg5) ...) -- 2 required, 5 optional, no body, commented declareFunction
;; (defun at-cerror (continue-string level format-string &optional arg1 arg2 arg3 arg4 arg5) ...) -- 3 required, 5 optional, no body, commented declareFunction
;; (defun at-warn (level format-string &optional arg1 arg2 arg3 arg4 arg5) ...) -- 2 required, 5 optional, no body, commented declareFunction
;; (defun min-anects (col &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun union-min-anects (cols &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun relation-arg-constraint-sentences (relation argnum &optional mt) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun variable-arity-relation-arg-constraint-sentences (relation &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun all-relation-arg-constraint-sentences (relation &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun all-relation-constraint-sentences (relation &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun relation-term-arg-constraints (relation term argnum &optional mt) ...) -- 3 required, 1 optional, no body, commented declareFunction
;; (defun formula-arg-constraints-cycl (formula &optional mt) ...) -- 1 required, 1 optional, no body, commented declareFunction
;; (defun formula-variable-isa-constraint-alist (formula mt) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun constraint-sentence-isa-constraints (sentence mt) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun possible-followup-variable-binding-sets (arg1 arg2 &optional arg3) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun variable-binding-set-item-comparator (a b) ...) -- 2 required, 0 optional, no body, commented declareFunction
;; (defun calc-possible-followup-binding-sets (arg1 arg2 arg3) ...) -- 3 required, 0 optional, no body, commented declareFunction
;; (defun count-followup-bindings (bindings) ...) -- 1 required, 0 optional, no body, commented declareFunction
;; (defun similarity-for-variable-binding-set (arg1 arg2 arg3 &optional arg4) ...) -- 3 required, 1 optional, no body, commented declareFunction
;; (defun constraint-similarity (arg1 arg2 &optional arg3) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun isa-constraint-similarity (arg1 arg2 &optional arg3) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun genls-constraint-similarity (arg1 arg2 &optional arg3) ...) -- 2 required, 1 optional, no body, commented declareFunction
;; (defun isas-and-genls-similarity (arg1 arg2 arg3 arg4 arg5) ...) -- 5 required, 0 optional, no body, commented declareFunction
;; (defun more-specific-p (arg1 arg2 &optional arg3) ...) -- 2 required, 1 optional, no body, commented declareFunction

;;; Setup section

(toplevel
  (note-globally-cached-function 'cached-max-floor-mts-of-nat))
