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

(deflexical *default-tva-check-cost* 2)

;; Functions in declareFunction order:

(defun tva-pos-preference (asent bindable-vars strategic-context)
  (let* ((inference (strategic-context-inference strategic-context))
         (allow-all? (null inference))
         (check-allowed? (or allow-all?
                              (inference-allows-use-of-module? inference
                                (find-hl-module-by-name :removal-tva-check))))
         (unify-allowed? (or allow-all?
                              (inference-allows-use-of-module? inference
                                (find-hl-module-by-name :removal-tva-unify))))
         (unify-closure-allowed? (or allow-all?
                                     (inference-allows-use-of-module? inference
                                       (find-hl-module-by-name :removal-tva-unify-closure)))))
    (when (and inference
               (eq :none (inference-transitive-closure-mode inference)))
      (setf unify-closure-allowed? nil))
    (cond
      ((not check-allowed?)
       (if (and (not unify-allowed?)
                (not unify-closure-allowed?))
           nil
           :preferred))
      ((fully-bound-p asent)
       :preferred)
      ((and (tva-cache-enabled-p)
            (formula-matches-pattern asent '(:fully-bound :anything :fully-bound))
            (tva-cache-predicate-index-arg-cached-p (atomic-sentence-predicate asent) 2))
       :preferred)
      ((and (tva-cache-enabled-p)
            (formula-matches-pattern asent '(:fully-bound :fully-bound :anything))
            (tva-cache-predicate-index-arg-cached-p (atomic-sentence-predicate asent) 1))
       :preferred)
      ((and (fort-p (atomic-sentence-predicate asent))
            (removal-tva-required asent)
            (tva-applicable-to-some-bindable-arg? asent bindable-vars))
       (cond
         ((not (tva-asent-has-fully-bound-arg? asent))
          :disallowed)
         ((eq :tactical strategic-context)
          :dispreferred)
         ((and unify-closure-allowed?
               (eq :all (inference-transitive-closure-mode inference)))
          :preferred)
         ((and (not unify-allowed?)
               (not unify-closure-allowed?))
          :grossly-dispreferred)
         (t :dispreferred)))
      (t nil))))

(defun tva-asent-has-fully-bound-arg? (asent)
  (let ((found-fully-bound-arg? nil))
    (dolist (arg (formula-args asent :ignore))
      (when found-fully-bound-arg? (return))
      (when (fully-bound-p arg)
        (setf found-fully-bound-arg? t)))
    found-fully-bound-arg?))

(defun tva-applicable-to-some-bindable-arg? (asent bindable-vars)
  (let ((applicable? nil)
        (tva-asent-pred (atomic-sentence-predicate asent))
        (argnum 0))
    (dolist (arg (formula-args asent :ignore))
      (when applicable? (return))
      (incf argnum)
      (when (tree-find-any bindable-vars arg)
        (when (any-tva-for-arg? tva-asent-pred argnum)
          (setf applicable? t))))
    applicable?))

;; (defun possible-tva-check-solved-by-other-hl-module (asent &optional sense) ...) -- active declareFunction, no body
;; (defun tva-determine-lookup-success (asent) ...) -- active declareFunction, no body
;; (defun tva-determine-genl-preds-success (asent) ...) -- active declareFunction, no body
;; (defun tva-determine-genl-preds-lookup-int (asent) ...) -- active declareFunction, no body
;; (defun tva-determine-genl-inverse-success (asent) ...) -- active declareFunction, no body
;; (defun tva-determine-genl-inverse-lookup-int (asent) ...) -- active declareFunction, no body
;; (defun tva-check (asent &optional sense) ...) -- active declareFunction, no body
;; (defun tva-justify (asent &optional sense) ...) -- active declareFunction, no body
;; (defun tva-max-floor-mts-of-just (asent) ...) -- active declareFunction, no body
;; (defun inference-tva-check (asent &optional sense) ...) -- active declareFunction, no body
;; (defun inference-tva-unify (asent &optional sense) ...) -- active declareFunction, no body
;; (defun inference-tva-justify (asent &optional sense) ...) -- active declareFunction, no body
;; (defun inference-tva-max-floor-mts (asent) ...) -- active declareFunction, no body
;; (defun make-tva-support (asent) ...) -- active declareFunction, no body

(defun removal-tva-required (asent)
  "[Cyc] Return booleanp. Whether ASENT meets the requirements to be proved by :tva"
  (let ((predicate (atomic-sentence-predicate asent)))
    (and (fort-p predicate)
         (or (some-tva-for-predicate predicate)
             (some-cva-for-predicate predicate))
         (not (tree-find-if #'fast-non-skolem-indeterminate-term? asent)))))

(defun removal-tva-check-required (asent &optional sense)
  (declare (ignore sense))
  (removal-tva-required asent))

;; (defun removal-tva-check-expand (asent &optional sense) ...) -- active declareFunction, no body

(defun removal-tva-unify-required (asent &optional sense)
  (declare (ignore sense))
  (and (removal-tva-unify-required-int asent)
       (tva-unify-useful? asent)))

(defun-memoized removal-tva-unify-required-int (asent &optional (mt *mt*)) (:test equal)
  "[Cyc] Internal memoized helper for removal-tva-unify-required."
  (and (removal-tva-required asent)
       (no-nested-variables-p asent)))

(defun tva-unify-useful? (asent)
  "[Cyc] TVA will only be useful on ASENT if ASENT has some non-variable terms in transitivity arg positions."
  (let* ((tva-asent-pred (atomic-sentence-predicate asent))
         (tva-term-argnums (determine-term-argnums asent))
         (found-use-for-unify? (tva-unify-from-cache-possible? asent)))
    (unless found-use-for-unify?
      ;; Inline expansion of do-all-spec-predicates-and-inverses over genlPreds
      (let ((node-var tva-asent-pred)
            (deck-type :queue)
            (recur-deck (create-deck :queue))
            (node-and-predicate-mode nil))
        (let ((*sbhl-space* (get-sbhl-marking-space)))
          (unwind-protect
               (let* ((tv-var nil)
                      (*sbhl-tv* (if tv-var tv-var (get-sbhl-true-tv)))
                      (*relevant-sbhl-tv-function* (if tv-var
                                                       #'relevant-sbhl-tv-is-general-tv
                                                       *relevant-sbhl-tv-function*)))
                 (when tv-var
                   (when (sbhl-object-type-checking-p)
                     (unless (sbhl-true-tv-p tv-var)
                       (let ((pcase-var *sbhl-type-error-action*))
                         (cond
                           ((eq pcase-var :error)
                            (sbhl-error 1 "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                           ((eq pcase-var :cerror)
                            (missing-larkc 2139))
                           ((eq pcase-var :warn)
                            (warn "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                           (t
                            (warn "~A is not a valid *sbhl-type-error-action* value" *sbhl-type-error-action*)
                            (cerror "continue anyway" "~A is not a ~A" tv-var 'sbhl-true-tv-p)))))))
                 (let* ((*sbhl-search-module* (get-sbhl-module #$genlPreds))
                        (*sbhl-search-module-type* (get-sbhl-module-type (get-sbhl-module #$genlPreds)))
                        (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test (get-sbhl-module #$genlPreds)))
                        (*genl-inverse-mode-p* nil)
                        (*sbhl-module* (get-sbhl-module #$genlPreds)))
                   (if (or (suspend-sbhl-type-checking?)
                           (apply-sbhl-module-type-test tva-asent-pred (get-sbhl-module)))
                       (let* ((*sbhl-search-direction* (get-sbhl-backward-search-direction))
                              (*sbhl-link-direction* (sbhl-search-direction-to-link-direction
                                                      (get-sbhl-backward-search-direction)
                                                      (get-sbhl-module #$genlPreds)))
                              (*genl-inverse-mode-p* nil))
                         (sbhl-mark-node-marked node-var)
                         (setf node-and-predicate-mode (list tva-asent-pred (genl-inverse-mode-p)))
                         (loop while (and node-and-predicate-mode
                                         (not found-use-for-unify?))
                               do (let* ((node-var-38 (first node-and-predicate-mode))
                                         (predicate-mode (second node-and-predicate-mode))
                                         (pred node-var-38)
                                         (*genl-inverse-mode-p* predicate-mode))
                                    (let ((inverse-mode? predicate-mode))
                                      (unless found-use-for-unify?
                                        (dolist (tva-pred (get-tva-predicates))
                                          (when found-use-for-unify? (return))
                                          (unless found-use-for-unify?
                                            (dolist (argnum tva-term-argnums)
                                              (when found-use-for-unify? (return))
                                              (let ((trans-preds (tva-gather-transitive-predicates-for-arg
                                                                  tva-pred pred argnum inverse-mode?)))
                                                (unless found-use-for-unify?
                                                  (dolist (trans-pred trans-preds)
                                                    (when found-use-for-unify? (return))
                                                    (let ((*gt-handle-non-transitive-predicate?* t))
                                                      (let ((arg (atomic-sentence-arg asent argnum)))
                                                        (cond
                                                          ((or (eq tva-pred #$transitiveViaArg)
                                                               (eq tva-pred #$conservativeViaArg))
                                                           (when (> (ghl-inverse-cardinality trans-pred arg) 0)
                                                             (setf found-use-for-unify? t)))
                                                          ((or (eq tva-pred #$transitiveViaArgInverse)
                                                               (eq tva-pred #$conservativeViaArgInverse))
                                                           (when (> (ghl-predicate-cardinality trans-pred arg) 0)
                                                             (setf found-use-for-unify? t)))))))))))))
                                      ;; Iterate accessible modules
                                      (dolist (module-var (get-sbhl-accessible-modules (get-sbhl-module #$genlPreds)))
                                        (when found-use-for-unify? (return))
                                        (let* ((*sbhl-module* module-var)
                                               (*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                                                          (not *genl-inverse-mode-p*)
                                                                          *genl-inverse-mode-p*)))
                                          (let ((node (naut-to-nart node-var-38)))
                                            (if (sbhl-node-object-p node)
                                                (let ((d-link (get-sbhl-graph-link node (get-sbhl-module))))
                                                  (if d-link
                                                      (let ((mt-links (get-sbhl-mt-links d-link (get-sbhl-link-direction) (get-sbhl-module))))
                                                        (when mt-links
                                                          (do-hash-table (mt tv-links mt-links)
                                                            (when found-use-for-unify? (return))
                                                            (when (relevant-mt? mt)
                                                              (let ((*sbhl-link-mt* mt))
                                                                (do-hash-table (tv link-nodes tv-links)
                                                                  (when found-use-for-unify? (return))
                                                                  (when (relevant-sbhl-tv? tv)
                                                                    (let ((*sbhl-link-tv* tv))
                                                                      (let ((new-list (if (sbhl-randomize-lists-p)
                                                                                          (missing-larkc 9303)
                                                                                          link-nodes)))
                                                                        (dolist (node-vars-link-node new-list)
                                                                          (when found-use-for-unify? (return))
                                                                          (unless (sbhl-search-path-termination-p node-vars-link-node)
                                                                            (sbhl-mark-node-marked node-vars-link-node)
                                                                            (deck-push (list node-vars-link-node (genl-inverse-mode-p))
                                                                                       recur-deck))))))))))))
                                                      (sbhl-error 5 "attempting to bind direction link variable, to NIL. macro body not executed.")))
                                                (when (cnat-p node)
                                                  (let ((new-list (if (sbhl-randomize-lists-p)
                                                                      (missing-larkc 9304)
                                                                      (missing-larkc 2621))))
                                                    (dolist (generating-fn new-list)
                                                      (when found-use-for-unify? (return))
                                                      (let ((*sbhl-link-generator* generating-fn))
                                                        (let ((link-nodes (funcall generating-fn node)))
                                                          (let ((new-list-51 (if (sbhl-randomize-lists-p)
                                                                                 (missing-larkc 9305)
                                                                                 link-nodes)))
                                                            (dolist (node-vars-link-node new-list-51)
                                                              (when found-use-for-unify? (return))
                                                              (unless (sbhl-search-path-termination-p node-vars-link-node)
                                                                (sbhl-mark-node-marked node-vars-link-node)
                                                                (deck-push (list node-vars-link-node (genl-inverse-mode-p))
                                                                           recur-deck)))))))))))))))
                                  (setf node-and-predicate-mode (deck-pop recur-deck))))
                       (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                                  tva-asent-pred (get-sbhl-type-test (get-sbhl-module))))))
            (free-sbhl-marking-space *sbhl-space*)))))
    found-use-for-unify?))

(defun tva-unify-from-cache-possible? (asent)
  (let ((arg0 (atomic-sentence-predicate asent))
        (cached? nil)
        (index-argnum 0))
    (dolist (index-arg (formula-args asent :ignore))
      (when cached? (return))
      (incf index-argnum)
      (setf cached? (and (fully-bound-p index-arg)
                         (tva-cache-predicate-index-arg-cached-p arg0 index-argnum))))
    cached?))

(defun no-nested-variables-p (asent)
  "[Cyc] @hack. Temporary addition to prevent TVA module from firing when it can't handle
what it is attempting to unify."
  (let ((found? nil))
    (unless found?
      (dolist (arg (formula-args asent))
        (when found? (return))
        (unless (hl-variable-p arg)
          (when (tree-gather arg #'hl-variable-p)
            (setf found? t)))))
    (not found?)))

(defun removal-tva-unify-cost (asent &optional sense)
  (declare (ignore sense))
  (let* ((tva-asent-pred (atomic-sentence-predicate asent))
         (tva-term-argnums (determine-term-argnums asent)))
    ;; First pass: check argnums without TVA, try fast total via SBHL traversal
    (dolist (tva-term-argnum tva-term-argnums)
      (unless (any-tva-for-arg? tva-asent-pred tva-term-argnum)
        (let ((v-term (sentence-arg asent tva-term-argnum))
              (fast-total 0))
          ;; Inline expansion of do-all-spec-predicates-and-inverses over genlPreds
          (let ((node-var tva-asent-pred)
                (recur-deck (create-deck :queue))
                (node-and-predicate-mode nil))
            (let ((*sbhl-space* (get-sbhl-marking-space)))
              (unwind-protect
                   (let* ((tv-var nil)
                          (*sbhl-tv* (if tv-var tv-var (get-sbhl-true-tv)))
                          (*relevant-sbhl-tv-function* (if tv-var
                                                           #'relevant-sbhl-tv-is-general-tv
                                                           *relevant-sbhl-tv-function*)))
                     (when tv-var
                       (when (sbhl-object-type-checking-p)
                         (unless (sbhl-true-tv-p tv-var)
                           (let ((pcase-var *sbhl-type-error-action*))
                             (cond
                               ((eq pcase-var :error)
                                (sbhl-error 1 "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                               ((eq pcase-var :cerror)
                                (missing-larkc 2140))
                               ((eq pcase-var :warn)
                                (warn "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                               (t
                                (warn "~A is not a valid *sbhl-type-error-action* value" *sbhl-type-error-action*)
                                (cerror "continue anyway" "~A is not a ~A" tv-var 'sbhl-true-tv-p)))))))
                     (let* ((*sbhl-search-module* (get-sbhl-module #$genlPreds))
                            (*sbhl-search-module-type* (get-sbhl-module-type (get-sbhl-module #$genlPreds)))
                            (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test (get-sbhl-module #$genlPreds)))
                            (*genl-inverse-mode-p* nil)
                            (*sbhl-module* (get-sbhl-module #$genlPreds)))
                       (if (or (suspend-sbhl-type-checking?)
                               (apply-sbhl-module-type-test tva-asent-pred (get-sbhl-module)))
                           (let* ((*sbhl-search-direction* (get-sbhl-backward-search-direction))
                                  (*sbhl-link-direction* (sbhl-search-direction-to-link-direction
                                                          (get-sbhl-backward-search-direction)
                                                          (get-sbhl-module #$genlPreds)))
                                  (*genl-inverse-mode-p* nil))
                             (sbhl-mark-node-marked node-var)
                             (setf node-and-predicate-mode (list tva-asent-pred (genl-inverse-mode-p)))
                             (loop while node-and-predicate-mode
                                   do (let* ((node-var-59 (first node-and-predicate-mode))
                                             (predicate-mode (second node-and-predicate-mode))
                                             (pred node-var-59)
                                             (*genl-inverse-mode-p* predicate-mode))
                                        (let ((inverse-mode? predicate-mode))
                                          (declare (ignore inverse-mode?))
                                          (incf fast-total (num-gaf-arg-index v-term tva-term-argnum pred))
                                          ;; Iterate accessible modules
                                          (dolist (module-var (get-sbhl-accessible-modules (get-sbhl-module #$genlPreds)))
                                            (let* ((*sbhl-module* module-var)
                                                   (*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                                                              (not *genl-inverse-mode-p*)
                                                                              *genl-inverse-mode-p*)))
                                              (let ((node (naut-to-nart node-var-59)))
                                                (if (sbhl-node-object-p node)
                                                    (let ((d-link (get-sbhl-graph-link node (get-sbhl-module))))
                                                      (if d-link
                                                          (let ((mt-links (get-sbhl-mt-links d-link (get-sbhl-link-direction) (get-sbhl-module))))
                                                            (when mt-links
                                                              (do-hash-table (mt tv-links mt-links)
                                                                (when (relevant-mt? mt)
                                                                  (let ((*sbhl-link-mt* mt))
                                                                    (do-hash-table (tv link-nodes tv-links)
                                                                      (when (relevant-sbhl-tv? tv)
                                                                        (let ((*sbhl-link-tv* tv))
                                                                          (let ((new-list (if (sbhl-randomize-lists-p)
                                                                                              (missing-larkc 9306)
                                                                                              link-nodes)))
                                                                            (dolist (node-vars-link-node new-list)
                                                                              (unless (sbhl-search-path-termination-p node-vars-link-node)
                                                                                (sbhl-mark-node-marked node-vars-link-node)
                                                                                (deck-push (list node-vars-link-node (genl-inverse-mode-p))
                                                                                           recur-deck)))))))))))))
                                                          (sbhl-error 5 "attempting to bind direction link variable, to NIL. macro body not executed.")))
                                                    (when (cnat-p node)
                                                      (let ((new-list (if (sbhl-randomize-lists-p)
                                                                          (missing-larkc 9307)
                                                                          (missing-larkc 2623))))
                                                        (dolist (generating-fn new-list)
                                                          (let ((*sbhl-link-generator* generating-fn))
                                                            (let ((link-nodes (funcall generating-fn node)))
                                                              (let ((new-list-70 (if (sbhl-randomize-lists-p)
                                                                                     (missing-larkc 9308)
                                                                                     link-nodes)))
                                                                (dolist (node-vars-link-node new-list-70)
                                                                  (unless (sbhl-search-path-termination-p node-vars-link-node)
                                                                    (sbhl-mark-node-marked node-vars-link-node)
                                                                    (deck-push (list node-vars-link-node (genl-inverse-mode-p))
                                                                               recur-deck))))))))))))))
                                      (setf node-and-predicate-mode (deck-pop recur-deck))))
                           (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                                      tva-asent-pred (get-sbhl-type-test (get-sbhl-module))))))
                (free-sbhl-marking-space *sbhl-space*))))
          (when (> fast-total 0)
            (return-from removal-tva-unify-cost fast-total)))))
    ;; Second pass: full cost computation with spec-preds/inverse-preds
    (let ((total 0))
      (dolist (argnum tva-term-argnums)
        (let ((spec-preds nil)
              (inverse-preds nil))
          ;; Inline expansion of do-all-spec-predicates-and-inverses over genlPreds
          (let ((node-var tva-asent-pred)
                (recur-deck (create-deck :queue))
                (node-and-predicate-mode nil))
            (let ((*sbhl-space* (get-sbhl-marking-space)))
              (unwind-protect
                   (let* ((tv-var nil)
                          (*sbhl-tv* (if tv-var tv-var (get-sbhl-true-tv)))
                          (*relevant-sbhl-tv-function* (if tv-var
                                                           #'relevant-sbhl-tv-is-general-tv
                                                           *relevant-sbhl-tv-function*)))
                     (when tv-var
                       (when (sbhl-object-type-checking-p)
                         (unless (sbhl-true-tv-p tv-var)
                           (let ((pcase-var *sbhl-type-error-action*))
                             (cond
                               ((eq pcase-var :error)
                                (sbhl-error 1 "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                               ((eq pcase-var :cerror)
                                (missing-larkc 2141))
                               ((eq pcase-var :warn)
                                (warn "~A is not a ~A" tv-var 'sbhl-true-tv-p))
                               (t
                                (warn "~A is not a valid *sbhl-type-error-action* value" *sbhl-type-error-action*)
                                (cerror "continue anyway" "~A is not a ~A" tv-var 'sbhl-true-tv-p)))))))
                     (let* ((*sbhl-search-module* (get-sbhl-module #$genlPreds))
                            (*sbhl-search-module-type* (get-sbhl-module-type (get-sbhl-module #$genlPreds)))
                            (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test (get-sbhl-module #$genlPreds)))
                            (*genl-inverse-mode-p* nil)
                            (*sbhl-module* (get-sbhl-module #$genlPreds)))
                       (if (or (suspend-sbhl-type-checking?)
                               (apply-sbhl-module-type-test tva-asent-pred (get-sbhl-module)))
                           (let* ((*sbhl-search-direction* (get-sbhl-backward-search-direction))
                                  (*sbhl-link-direction* (sbhl-search-direction-to-link-direction
                                                          (get-sbhl-backward-search-direction)
                                                          (get-sbhl-module #$genlPreds)))
                                  (*genl-inverse-mode-p* nil))
                             (sbhl-mark-node-marked node-var)
                             (setf node-and-predicate-mode (list tva-asent-pred (genl-inverse-mode-p)))
                             (loop while node-and-predicate-mode
                                   do (let* ((node-var-78 (first node-and-predicate-mode))
                                             (predicate-mode (second node-and-predicate-mode))
                                             (pred node-var-78)
                                             (*genl-inverse-mode-p* predicate-mode))
                                        (let ((inverse-mode? predicate-mode))
                                          (dolist (tva-pred (get-tva-predicates))
                                            (let ((trans-preds (tva-gather-transitive-predicates-for-arg
                                                                tva-pred pred argnum inverse-mode?)))
                                              (dolist (trans-pred trans-preds)
                                                (if (not (eq (not inverse-mode?)
                                                             (not (member-eq? tva-pred
                                                                              (list #$transitiveViaArgInverse
                                                                                    #$conservativeViaArgInverse)))))
                                                    (push trans-pred inverse-preds)
                                                    (push trans-pred spec-preds)))))
                                          ;; Iterate accessible modules
                                          (dolist (module-var (get-sbhl-accessible-modules (get-sbhl-module #$genlPreds)))
                                            (let* ((*sbhl-module* module-var)
                                                   (*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                                                              (not *genl-inverse-mode-p*)
                                                                              *genl-inverse-mode-p*)))
                                              (let ((node (naut-to-nart node-var-78)))
                                                (if (sbhl-node-object-p node)
                                                    (let ((d-link (get-sbhl-graph-link node (get-sbhl-module))))
                                                      (if d-link
                                                          (let ((mt-links (get-sbhl-mt-links d-link (get-sbhl-link-direction) (get-sbhl-module))))
                                                            (when mt-links
                                                              (do-hash-table (mt tv-links mt-links)
                                                                (when (relevant-mt? mt)
                                                                  (let ((*sbhl-link-mt* mt))
                                                                    (do-hash-table (tv link-nodes tv-links)
                                                                      (when (relevant-sbhl-tv? tv)
                                                                        (let ((*sbhl-link-tv* tv))
                                                                          (let ((new-list (if (sbhl-randomize-lists-p)
                                                                                              (missing-larkc 9309)
                                                                                              link-nodes)))
                                                                            (dolist (node-vars-link-node new-list)
                                                                              (unless (sbhl-search-path-termination-p node-vars-link-node)
                                                                                (sbhl-mark-node-marked node-vars-link-node)
                                                                                (deck-push (list node-vars-link-node (genl-inverse-mode-p))
                                                                                           recur-deck)))))))))))))
                                                          (sbhl-error 5 "attempting to bind direction link variable, to NIL. macro body not executed.")))
                                                    (when (cnat-p node)
                                                      (let ((new-list (if (sbhl-randomize-lists-p)
                                                                          (missing-larkc 9310)
                                                                          (missing-larkc 2625))))
                                                        (dolist (generating-fn new-list)
                                                          (let ((*sbhl-link-generator* generating-fn))
                                                            (let ((link-nodes (funcall generating-fn node)))
                                                              (let ((new-list-90 (if (sbhl-randomize-lists-p)
                                                                                     (missing-larkc 9311)
                                                                                     link-nodes)))
                                                                (dolist (node-vars-link-node new-list-90)
                                                                  (unless (sbhl-search-path-termination-p node-vars-link-node)
                                                                    (sbhl-mark-node-marked node-vars-link-node)
                                                                    (deck-push (list node-vars-link-node (genl-inverse-mode-p))
                                                                               recur-deck))))))))))))))
                                      (setf node-and-predicate-mode (deck-pop recur-deck))))
                           (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                                      tva-asent-pred (get-sbhl-type-test (get-sbhl-module))))))
                (free-sbhl-marking-space *sbhl-space*))))
          ;; Accumulate cost from spec-preds and inverse-preds
          (let ((*gt-handle-non-transitive-predicate?* t))
            (let ((arg (atomic-sentence-arg asent argnum)))
              (dolist (trans-pred (min-predicates spec-preds))
                (incf total (ghl-inverse-cardinality trans-pred arg)))
              (dolist (trans-pred (max-predicates inverse-preds))
                (incf total (ghl-predicate-cardinality trans-pred arg)))))))
      total)))

;; (defun removal-tva-unify-iterator (asent) ...) -- active declareFunction, no body

(defun removal-tva-unify-closure-required (asent &optional sense)
  (declare (ignore sense))
  (let ((inference (current-controlling-inference)))
    (and (inference-p inference)
         (not (eq :none (inference-transitive-closure-mode inference)))
         (removal-tva-unify-required-int asent))))

;; (defun removal-tva-unify-closure-cost (asent &optional sense) ...) -- active declareFunction, no body
;; (defun removal-tva-unify-closure-iterator (asent) ...) -- active declareFunction, no body

(defun removal-tva-unify-closure-conjunction-applicability (contextualized-dnf-clause)
  (let ((subclause-specs nil)
        (pos-index 0))
    (dolist (pos-lit (pos-lits contextualized-dnf-clause))
      (destructuring-bind (pos-mt pos-asent) pos-lit
        (when (removal-tva-unify-closure-conjunction-appropriate-asent? pos-asent pos-mt)
          (let ((vars (literal-free-variables pos-asent))
                (pos-indices (list pos-index))
                (index 0))
            (dolist (lit (pos-lits contextualized-dnf-clause))
              (unless (eql index pos-index)
                (destructuring-bind (mt asent) lit
                  (when (and (removal-tva-unify-closure-conjunction-appropriate-asent? asent mt)
                             (sets-equal? vars (literal-free-variables asent) #'eq))
                    (push index pos-indices))))
              (incf index))
            (when (length> pos-indices 1)
              (push (new-subclause-spec nil (sort pos-indices #'<))
                    subclause-specs)))))
      (incf pos-index))
    (fast-delete-duplicates subclause-specs #'equal)))

(defun removal-tva-unify-closure-conjunction-appropriate-asent? (asent mt)
  (let ((pred (atomic-sentence-predicate asent))
        (result nil))
    (when (and (fort-p pred)
               (removal-tva-unify-closure-conjunction-appropriate-predicate? pred))
      (let ((*mt* (update-inference-mt-relevance-mt mt))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt)))
        (setf result (removal-tva-unify-required-int asent))))
    result))

(defun removal-tva-unify-closure-conjunction-appropriate-predicate? (predicate)
  (not (or (hl-predicate-p predicate)
           (sbhl-predicate-p predicate)
           (solely-specific-removal-module-predicate? predicate))))

;; (defun removal-tva-unify-closure-conjunction-cost (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun removal-tva-unify-closure-conjunction-output-generate (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun new-tva-closure-crm-iterator (closure-iterator support-templates) ...) -- active declareFunction, no body
;; (defun tva-closure-crm-iterator-state (closure-iterator support-templates) ...) -- active declareFunction, no body
;; (defun tva-closure-crm-iterator-done (state) ...) -- active declareFunction, no body
;; (defun tva-closure-crm-iterator-next (state) ...) -- active declareFunction, no body
;; (defun tva-closure-crm-iterator-finalize (state) ...) -- active declareFunction, no body

;; Setup / toplevel forms

(toplevel
  (inference-preference-module :tva-pos
    (list :sense :pos
          :required-pattern '(:fully-bound . :anything)
          :preference 'tva-pos-preference)))

(toplevel
  (inference-removal-module :removal-tva-check
    (list :sense :pos
          :arity nil
          :required-pattern '(:fort . :fully-bound)
          :required 'removal-tva-check-required
          :cost-expression '*default-tva-check-cost*
          :expand 'removal-tva-check-expand
          :documentation "(<fort> . <fully-bound>)
using true assertions and GAF indexing in the KB
via #$transitiveViaArg or #$transitiveViaArgInverse
and transitivity reasoning"
          :example "(#$relationAllExists #$physicalParts #$Dog #$Head)
via
 (#$relationAllExists #$anatomicalParts #$Vertebrate #$Head-Vertebrate)
and
 (#$transitiveViaArg #$relationAllExists #$genlPreds 1)
 (#$transitiveViaArgInverse #$relationAllExists #$genls 2)
 (#$transitiveViaArg #$relationAllExists #$genls 3)
 (#$genlPreds #$anatomicalParts #$physicalParts)
 (#$genls #$Dog #$Vertebrate)
 (#$genls #$Head-Vertebrate #$Head)
")))

(toplevel
  (note-memoized-function 'removal-tva-unify-required-int))

(toplevel
  (inference-removal-module :removal-tva-unify
    (list :sense :pos
          :arity nil
          :required-pattern '(:fort . :not-fully-bound)
          :required 'removal-tva-unify-required
          :cost 'removal-tva-unify-cost
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-tva-unify-iterator :input)
          :output-decode-pattern '(:call subst-bindings :input (:value asent))
          :output-verify-pattern '(:not (:test possible-tva-check-solved-by-other-hl-module))
          :support-module :tva
          :support-strength :default
          :documentation "(<fort> . <not-fully-bound>)
using true assertions and GAF indexing in the KB
via #$transitiveViaArg or #$transitiveViaArgInverse
and transitivity reasoning"
          :example "(#$relationAllExists #$physicalParts #$Dog ?COL)
via
 (#$relationAllExists #$anatomicalParts #$Vertebrate #$Head-Vertebrate)
and
 (#$transitiveViaArg #$relationAllExists #$genlPreds 1)
 (#$transitiveViaArgInverse #$relationAllExists #$genls 2)
 (#$genlPreds #$anatomicalParts #$physicalParts)
 (#$genls #$Dog #$Vertebrate)
")))

(toplevel
  (inference-removal-module :removal-tva-unify-closure
    (list :sense :pos
          :arity nil
          :required-pattern '(:fort . :not-fully-bound)
          :required 'removal-tva-unify-closure-required
          :cost 'removal-tva-unify-closure-cost
          :input-extract-pattern '(:template (:bind asent) (:value asent))
          :output-generate-pattern '(:call removal-tva-unify-closure-iterator :input)
          :output-decode-pattern '(:call subst-bindings :input (:value asent))
          :support-module :tva
          :support-strength :default
          :documentation "(<fort> . <not-fully-bound>)
using true assertions and GAF indexing in the KB
via #$transitiveViaArg or #$transitiveViaArgInverse
and transitivity reasoning"
          :example "(#$relationAllExists #$physicalParts #$Dog ?COL)
via
 (#$relationAllExists #$anatomicalParts #$Vertebrate #$Head-Vertebrate)
and
 (#$transitiveViaArg #$relationAllExists #$genlPreds 1)
 (#$transitiveViaArgInverse #$relationAllExists #$genls 2)
 (#$genlPreds #$anatomicalParts #$physicalParts)
 (#$genls #$Dog #$Vertebrate)
")))

(toplevel
  (inference-conjunctive-removal-module :removal-tva-unify-closure-conjunction
    (list :applicability 'removal-tva-unify-closure-conjunction-applicability
          :cost 'removal-tva-unify-closure-conjunction-cost
          :completeness :incomplete
          :expand-iterative-pattern '(:call removal-tva-unify-closure-conjunction-output-generate :input)
          :documentation "Solves a conjunction of positive literals each of which can be solved with TVA."
          :example "(#$and
      (#$eventOccursAt #$TerroristAttack-11-mar-2004-Madrid-Spain ?REGION)
      (#$operatesInRegion #$AlQaida ?REGION))")))
