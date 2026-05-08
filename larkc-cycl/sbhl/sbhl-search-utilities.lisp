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

(defun determine-sbhl-search-behavior (module direction tv)
  "[Cyc] Accessor: returns the name of the search function to call, as determined
by MODULE's type, DIRECTION, and TV."
  (declare (type (satisfies sbhl-module-p) module))
  (cond
    ((sbhl-transitive-module-p module)
     (if (sbhl-true-tv-p tv)
         'sbhl-simple-true-search
         'sbhl-simple-false-search))
    ((sbhl-transfers-through-module-p module)
     (if (sbhl-forward-search-direction-p direction)
         'sbhl-step-and-sweep-with-tt-module
         'sbhl-sweep-with-tt-module-carry-step))
    ((sbhl-disjoins-module-p module)
     'sbhl-sweep-step-disjoins-and-sweep-again)
    (t
     (sbhl-error 1 "Search behavior not recognized. Sorry."))))

(defun determine-sbhl-terminating-marking-space (search-behavior)
  "[Cyc] Accessor: returns the marking space that will contain goal markings,
based on SEARCH-BEHAVIOR."
  (case search-behavior
    (sbhl-simple-true-search *sbhl-space*)
    (sbhl-simple-false-search *sbhl-gather-space*)
    (sbhl-step-and-sweep-with-tt-module *sbhl-space*)
    (sbhl-sweep-with-tt-module-carry-step *sbhl-gather-space*)
    (sbhl-sweep-step-disjoins-and-sweep-again *sbhl-gather-space*)
    (otherwise
     (sbhl-error 1 "Search Behavior not recognized: ~a" search-behavior))))

(defun sbhl-module-premarks-gather-nodes-p ()
  "[Cyc] Accessor. Whether MODULE marks in gather space before performing other search.
Used for boolean disjoins searches."
  (and (sbhl-boolean-search-p)
       (sbhl-disjoins-search-p)
       (sbhl-true-search-p)
       t))

(defun sbhl-just-gaf (just-step)
  "[Cyc] Accessor. Returns the gaf part of JUST-STEP."
  (first just-step))

(defun sbhl-just-mt (just-step)
  "[Cyc] Accessor. Returns the mt of JUST-STEP."
  (second just-step))

(defun sbhl-possibly-just-mt (just-step &optional mt)
  (let ((result (sbhl-just-mt just-step)))
    (cond
      (result result)
      (mt mt)
      (t *mt*))))

(defun sbhl-just-tv (just-step)
  "[Cyc] Accessor. Returns the truth value of JUST-STEP."
  (third just-step))

(defun sbhl-gaf-pred (gaf-formula)
  "[Cyc] Accessor. Returns the predicate of GAF-FORMULA."
  (first gaf-formula))

;; (defun hl-default-tv (arg1) ...) -- commented declareFunction, no body
;; (defun sbhl-find-first-matching-gaf (arg1) ...) -- commented declareFunction, no body

(defun sbhl-find-gaf (gaf-formula mt tv)
  "[Cyc] Accessor. Returns the assertion associated with GAF-FORMULA and MT.
If the predicate of GAF-FORMULA is symmetric, the associated assertion may have
its arguments flipped."
  (let* ((result nil)
         (lucky-gaf (find-gaf gaf-formula mt))
         (pred (sbhl-gaf-pred gaf-formula))
         (hl-module (sbhl-pred-get-hl-module
                     (get-sbhl-link-pred
                      (get-sbhl-module)))))
    (cond
      (lucky-gaf
       (setf result lucky-gaf))
      ((not (sbhl-predicate-p pred))
       (let ((gaf (missing-larkc 2328)))
         (if gaf
             (setf result gaf)
             ;; missing-larkc 2317 — probably sbhl-tv-to-support-tv
             (setf result (make-hl-support hl-module gaf-formula mt
                                           (missing-larkc 2317))))))
      ((not (sbhl-module-directed-links? (get-sbhl-module pred)))
       (destructuring-bind (pred-1 arg1 arg2) gaf-formula
         (let* ((sym-formula (list pred-1 arg2 arg1))
                (gaf (find-gaf sym-formula mt)))
            ;; TODO - These GAF settings smell like it should be (or (find-gaf) (missing-larkc) (missing-larckc)) instead of conditional SETFs
           (unless gaf
             (setf gaf (missing-larkc 2329)))
           (unless gaf
             (setf gaf (missing-larkc 2330)))
           (if gaf
               (setf result gaf)
               ;; missing-larkc 2318 — probably sbhl-tv-to-support-tv
               (setf result (make-hl-support hl-module gaf-formula mt
                                             (missing-larkc 2318)))))))
      (t
       (let ((gaf (missing-larkc 2331)))
         (if gaf
             (setf result gaf)
             ;; missing-larkc 2319 — probably sbhl-tv-to-support-tv
             (setf result (make-hl-support hl-module gaf-formula mt
                                           (missing-larkc 2319)))))))
    result))

(defun sbhl-assemble-justification-step (just-step &optional mt)
  "[Cyc] Accessor. Takes JUST-STEP and assembles a justification step according to
get-sbhl-just-behavior. The return is either a list or an assertion."
  (when (hl-support-p just-step)
    (return-from sbhl-assemble-justification-step just-step))
  (let* ((assembly-behavior (get-sbhl-just-behavior))
         (just-tv (sbhl-just-tv just-step))
         (tv (if (sbhl-link-truth-value-p just-tv)
                 (sbhl-possibly-translate-tv just-tv)
                 just-tv)))
    (unless assembly-behavior
      (when (missing-larkc 2477)
        (setf assembly-behavior :old)))
    (case assembly-behavior
      (:assertion
       (sbhl-find-gaf (sbhl-just-gaf just-step)
                      (sbhl-possibly-just-mt just-step mt)
                      just-tv))
      (:verbose
       just-step)
      (:old
       (if (missing-larkc 2478)
           (list (sbhl-just-gaf just-step) tv)
           (list (sbhl-just-gaf just-step)
                 (sbhl-possibly-translate-tv (sbhl-just-tv just-step)))))
      (otherwise
       (sbhl-error 1 "incorrect justification assembly ~a" assembly-behavior)))))

(defun sbhl-assemble-justification (just-path &optional mt)
  "[Cyc] Returns the justification distilled from repeated application of
sbhl-assemble-justification-step to JUST-PATH."
  (if (sbhl-justification-assembled-p)
      just-path
      (let ((result nil))
        (dolist (just-step just-path)
          (push (sbhl-assemble-justification-step just-step mt) result))
        (nreverse result))))

(defun sbhl-handle-justification (method module node1 node2
                                  &optional mt tv
                                    (behavior *sbhl-justification-behavior*)
                                    (justify-node-equality? t))
  "[Cyc] Wraps the execution of METHOD (with args NODE1 NODE2 MT TV) so that
justifications will be accumulated on the unwind. Justification behavior is
governed by BEHAVIOR."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((just nil)
        (result nil))
    (let ((*sbhl-search-module* module)
          (*sbhl-search-module-type* (get-sbhl-module-type module))
          (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
          (*genl-inverse-mode-p* nil)
          (*sbhl-module* module)
          (*sbhl-justification-assembled-p* nil)
          (*sbhl-justification-defaulted-old* nil))
      (flet ((do-search ()
               (cond
                 ((and justify-node-equality?
                       (equal node1 node2)
                       (sbhl-reflexive-module-p module))
                  (setf just (list (make-hl-support
                                   :reflexive
                                   (make-binary-formula
                                    (get-sbhl-link-pred module)
                                    node1 node2)))))
                 ((and justify-node-equality?
                       (equal node1 node2)
                       (sbhl-time-module-p module)
                       (missing-larkc 69))
                  (setf just (list (list #$equals node1 node2)
                                   mt #$MonotonicallyTrue)))
                 (t
                  (let ((*sbhl-justification-search-p* t)
                        (*sbhl-apply-unwind-function-p* nil)
                        (*sbhl-unwind-function* (if (sbhl-time-search-p)
                                                    'sbhl-temporal-justification-unwind
                                                    'sbhl-push-unwind-onto-result))
                        (*suspend-sbhl-cache-use?* t)
                        (*sbhl-justification-result* nil))
                    (unwind-protect
                         (setf result (funcall method module node1 node2 mt tv))
                      (setf just *sbhl-justification-result*)))))))
        (if behavior
            (let ((*sbhl-justification-behavior* behavior))
              (do-search)
              (setf just (sbhl-assemble-justification just mt)))
            (progn
              (do-search)
              (setf just (sbhl-assemble-justification just mt))))))
    (when (and (length>= just 2)
               (sbhl-transitive-module-p module)
               (not (sbhl-inverse-module-p module)))
      (setf just (adjoin (sbhl-module-transitivity-support module mt) just
                         :test #'equal)))
    (if just just result)))

(defun sbhl-module-transitivity-support (module &optional mt)
  (must (sbhl-transitive-module-p module)
        "~S is not a transitive module" module)
  (make-transitivity-support (get-sbhl-link-pred module)
                             #$UniversalVocabularyMt))

;; (defun sbhl-set-empty-extent-justification (arg1) ...) -- commented declareFunction, no body
;; (defun sbhl-temporal-faux-link (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun any-support-chain-of-temporal-link (arg1) ...) -- commented declareFunction, no body
;; (defun any-support-chain-of-link-disjunction-consequent (arg1 arg2) ...) -- commented declareFunction, no body

(defun apply-sbhl-add-node-test (test-fn node)
  "[Cyc] Applies TEST-FN (to NODE, where appropriate). Used to determine whether
to add node to result."
  (case test-fn
    (not-genl-inverse-mode-p (not-genl-inverse-mode-p))
    (genl-inverse-mode-p (genl-inverse-mode-p))
    (non-empty-extent t)
    (otherwise
     (sbhl-warn 3 "Using potentially unsupported gather gating behavior: ~a" test-fn)
     (funcall test-fn node))))

;; (defun apply-sbhl-add-unmarked-node-test (arg1) ...) -- commented declareFunction, no body

(defun sbhl-push-onto-result (node)
  "[Cyc] Modifier. Will push NODE onto *sbhl-result*."
  (push node *sbhl-result*)
  nil)

(defun sbhl-push-onto-result-if (node)
  "[Cyc] Modifier. Will push NODE onto *sbhl-result* if applying *sbhl-compose-fn*
to node gives a non-nil answer."
  (let* ((compose-fn (get-sbhl-compose-fn))
         (test-p (funcall compose-fn node)))
    (when test-p
      (sbhl-push-onto-result node)))
  nil)

;; (defun sbhl-push-onto-result-if-and-stop-unless (node) ...) -- commented declareFunction, no body
;; (defun sbhl-push-onto-result-with-prune (node) ...) -- commented declareFunction, no body

(defun sbhl-push-unwind-onto-result (nodelist)
  "[Cyc] Modifier: will push a list of *sbhl-module*, the nodes in NODELIST,
*sbhl-link-mt*, and *sbhl-link-tv* onto the result. If search is a time search,
instead calls sbhl-temporal-justification-unwind."
  (let* ((directed? (sbhl-module-directed-links? (get-sbhl-module)))
         (forward? (if directed?
                       (sbhl-forward-directed-direction-p (get-sbhl-link-direction))
                       t))
         (node1 (if forward? (first nodelist) (second nodelist)))
         (node2 (if forward? (second nodelist) (first nodelist))))
    (if (or (fort-p node1) (not forward?))
        (push (list (list (get-sbhl-link-pred (get-sbhl-module)) node1 node2)
                    (get-sbhl-link-mt)
                    (get-sbhl-link-tv))
              *sbhl-justification-result*)
        ;; missing-larkc 57 — probably sbhl-temporal-justification-unwind or naut justification
        (setf *sbhl-justification-result* (missing-larkc 57))))
  nil)

(defun sbhl-apply-compose-fn (node)
  "[Cyc] Modifier. Applies *sbhl-compose-fn* to NODE."
  (let ((compose-fn (get-sbhl-compose-fn)))
    (if (sbhl-suspend-new-spaces-during-mapping?)
        (let ((*sbhl-space* *sbhl-mapping-marking-space*)
              (*sbhl-gather-space* *sbhl-mapping-gather-marking-space*)
              (*sbhl-suspend-new-spaces?* t))
          (funcall compose-fn node))
        (funcall compose-fn node)))
  nil)

;; (defun sbhl-apply-compose-fn-if (node) ...) -- commented declareFunction, no body
;; (defun sbhl-apply-compose-fn-and-combine-with-result (node) ...) -- commented declareFunction, no body

(defun sbhl-gather-first-non-nil-result (node)
  "[Cyc] Modifier. Applies *sbhl-compose-fn* to node. If the result is non-nil,
sets *sbhl-result* to the result, and sets *sbhl-finished?* to true."
  (let ((compose-fn (get-sbhl-compose-fn))
        (result nil))
    (if (sbhl-suspend-new-spaces-during-mapping?)
        (let ((*sbhl-space* *sbhl-mapping-marking-space*)
              (*sbhl-gather-space* *sbhl-mapping-gather-marking-space*)
              (*sbhl-suspend-new-spaces?* t))
          (setf result (funcall compose-fn node)))
        (setf result (funcall compose-fn node)))
    (when result
      (setf *sbhl-result* result)
      (setf *sbhl-finished?* t)))
  nil)

(defun sbhl-gather-first-non-nil-result-with-prune (node)
  "[Cyc] Modifier. Applies *sbhl-compose-fn* to node. *sbhl-compose-fn* should return
a list of two values: result and done? If the result is non-nil, sets *sbhl-result*
to the result, and sets *sbhl-finished?* to true. If the result is nil, sets
*sbhl-finished?* to the value of done?"
  (let ((compose-fn (get-sbhl-compose-fn))
        (v-return nil))
    (if (sbhl-suspend-new-spaces-during-mapping?)
        (let ((*sbhl-space* *sbhl-mapping-marking-space*)
              (*sbhl-gather-space* *sbhl-mapping-gather-marking-space*)
              (*sbhl-suspend-new-spaces?* t))
          (setf v-return (funcall compose-fn node)))
        (setf v-return (funcall compose-fn node)))
    (destructuring-bind (result done?) v-return
      (if result
          (progn
            (setf *sbhl-result* result)
            (setf *sbhl-finished?* t))
          (if done?
              (sbhl-stop-search-path)
              (missing-larkc 2474)))))
  nil)

;; (defun sbhl-gather-first-dead-end-node-and-enqueue-others (node) ...) -- commented declareFunction, no body
;; (defun sbhl-gather-first-node (node) ...) -- commented declareFunction, no body
;; (defun sbhl-gather-first-target-unmarked-node (node) ...) -- commented declareFunction, no body
;; (defun sbhl-search-has-multiple-goals-p () ...) -- commented declareFunction, no body

(defun set-sbhl-boolean-goal-conditions ()
  "[Cyc] Modifier. Sets *sbhl-result* to true, and sets *sbhl-finished?* to indicate
that the goal was found."
  (sbhl-finished-with-goal)
  (if (sbhl-justification-search-p)
      (sbhl-toggle-unwind-function-on)
      (setf *sbhl-result* t))
  nil)

(defun sbhl-node-marked-as-goal-node (node)
  "[Cyc] Modifier. Determines if NODE is marked with a terminating mark in the
*sbhl-goal-space*. If so, calls set-sbhl-boolean-goal-conditions."
  (let ((goal-space (get-sbhl-goal-space)))
    (when (sbhl-search-path-termination-p node goal-space)
      (when (and (sbhl-justification-search-p)
                 (sbhl-module-premarks-gather-nodes-p))
        (missing-larkc 1442)
        (setf *sbhl-result* (nreverse *sbhl-result*)))
      (set-sbhl-boolean-goal-conditions)))
  nil)

(defun sbhl-node-is-goal-node (node)
  "[Cyc] Modifier. Determines if NODE is the current *sbhl-goal-node*. If so,
calls set-sbhl-boolean-goal-conditions."
  (when (sbhl-goal-node-p node)
    (set-sbhl-boolean-goal-conditions))
  nil)

;; (defun sbhl-node-is-a-goal-node (node) ...) -- commented declareFunction, no body
;; (defun sbhl-reached-cutoff-p () ...) -- commented declareFunction, no body

(defun sbhl-check-cutoff (node)
  "[Cyc] Modifier. Checks cutoff conditions and terminates search if cutoff is reached."
  (declare (ignore node))
  nil)

(defun apply-sbhl-consider-node-fn (fn node)
  "[Cyc] Modifier: applies FN to NODE. Used at each step of search."
  (let ((add-node-test (get-sbhl-search-add-node-test))
        (apply-fn? t))
    (when add-node-test
      (setf apply-fn? (apply-sbhl-add-node-test add-node-test node)))
    (when (and apply-fn? fn)
      (case fn
        (sbhl-push-onto-result
         (sbhl-push-onto-result node))
        (sbhl-push-onto-result-with-prune
         (missing-larkc 2340))
        (sbhl-node-is-goal-node
         (sbhl-node-is-goal-node node))
        (sbhl-node-marked-as-goal-node
         (sbhl-node-marked-as-goal-node node))
        (sbhl-gather-first-non-nil-result
         (sbhl-gather-first-non-nil-result node))
        (sbhl-gather-first-non-nil-result-with-prune
         (sbhl-gather-first-non-nil-result-with-prune node))
        (sbhl-apply-compose-fn
         (sbhl-apply-compose-fn node))
        (sbhl-apply-compose-fn-and-combine-with-result
         (missing-larkc 2326))
        (sbhl-gather-dead-end-nodes
         (missing-larkc 1565))
        (sbhl-gather-first-dead-end-node-and-enqueue-others
         (missing-larkc 2332))
        (otherwise
         (funcall fn node)))))
  nil)

(defun apply-sbhl-consider-unmarked-node-fn (fn node)
  "[Cyc] Modifier: applies FN to NODE. Used at each step of some unmarking searches."
  (let ((add-unmarked-node-test (get-sbhl-search-add-unmarked-node-test))
        (apply-fn? t))
    (when add-unmarked-node-test
      ;; missing-larkc 2316 — apply-sbhl-add-unmarked-node-test
      (setf apply-fn? (missing-larkc 2316)))
    (when apply-fn?
      (case fn
        (sbhl-push-onto-result
         (sbhl-push-onto-result node))
        (otherwise
         (funcall fn node)))))
  nil)

(defun sbhl-consider-node (node)
  "[Cyc] Modifier. Called during search on each NODE. Determines behavior with
*sbhl-consider-node-fn*."
  (if (sbhl-unmarking-search-p)
      (sbhl-consider-unmarked-node node)
      (let ((consider-node-fn (get-sbhl-consider-node-fn)))
        (apply-sbhl-consider-node-fn consider-node-fn node)))
  nil)

(defun sbhl-consider-any-node (node)
  "[Cyc] Modifier. Called during search to check any NODE, without passing through
an add node test."
  (let ((fn (get-sbhl-consider-node-fn)))
    (case fn
      (sbhl-node-marked-as-goal-node
       (sbhl-node-marked-as-goal-node node))
      (otherwise
       (funcall fn node))))
  nil)

(defun sbhl-consider-unmarked-node (node)
  "[Cyc] Modifier. Called upon each NODE during unmarking searches which gather nodes."
  (let ((consider-node-fn (get-sbhl-consider-node-fn)))
    (apply-sbhl-consider-unmarked-node-fn consider-node-fn node)))

(defun sbhl-mark-and-sweep (node)
  "[Cyc] Modifier. The recursive search workhouse. Stops recurring when NODE's marking
indicates path termination. Dynamically rebinds *sbhl-search-parent-marking*, when it
gathers new nodes during search, with either a search mapping function or recurring
among link-nodes."
  (unless (sbhl-search-path-termination-p node)
    (sbhl-mark-node-marked node)
    (apply-sbhl-mapping-function node)
    (unless (sbhl-stop-search-path-p)
      (dolist (module-var (get-sbhl-accessible-modules (get-sbhl-module)))
        (unless *sbhl-finished?*
          (let ((*sbhl-module* module-var)
                (*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                           (not *genl-inverse-mode-p*)
                                           *genl-inverse-mode-p*)))
            (with-relevant-sbhl-link-nodes (link-nodes node
                                            (get-sbhl-link-direction)
                                            (get-sbhl-module))
              (dolist (link-node link-nodes)
                (unless *sbhl-finished?*
                  (sbhl-mark-and-sweep link-node)
                  (when (sbhl-apply-unwind-function-p)
                    (sbhl-apply-unwind-function (list node link-node))))))))))))

(defun sbhl-unmark-and-sweep (node)
  "[Cyc] Modifier. The recursive search workhouse, for searches on marked nodes.
Stops recurring when NODE's marking does not indicate path termination.
Dynamically rebinds *sbhl-search-parent-marking*."
  (when (sbhl-search-path-termination-p node)
    (sbhl-mark-node-unmarked node)
    (let ((*sbhl-search-parent-marking* *sbhl-search-parent-marking*))
      (apply-sbhl-mapping-function node))
    (unless (sbhl-stop-search-path-p)
      (dolist (module-var (get-sbhl-accessible-modules (get-sbhl-module)))
        (unless *sbhl-finished?*
          (let ((*sbhl-module* module-var)
                (*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                           (not *genl-inverse-mode-p*)
                                           *genl-inverse-mode-p*)))
            (with-relevant-sbhl-link-nodes (link-nodes node
                                            (get-sbhl-link-direction)
                                            (get-sbhl-module))
              (dolist (link-node link-nodes)
                (unless *sbhl-finished?*
                  (let ((*sbhl-search-parent-marking* *sbhl-search-parent-marking*))
                    (sbhl-unmark-and-sweep link-node))
                  (when (sbhl-apply-unwind-function-p)
                    (sbhl-apply-unwind-function (list node link-node))))))))))))

;; (defun sbhl-mark-sweep-and-unwind (node) ...) -- commented declareFunction, no body

(defun sbhl-step-and-suspend-mark (node suspend-test-p)
  "[Cyc] Modifier: Steps over NODE's accessible links, ignoring NODE's marking
if SUSPEND-TEST-P is true. Does not mark node. Applies sbhl-mapping-function."
  (let ((terminate-p nil))
    (dolist (module-var (get-sbhl-accessible-modules (get-sbhl-module)))
      (unless *sbhl-finished?*
        (let ((*sbhl-module* module-var)
              (*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                         (not *genl-inverse-mode-p*)
                                         *genl-inverse-mode-p*)))
          (with-relevant-sbhl-link-nodes (link-nodes node
                                          (get-sbhl-link-direction)
                                          (get-sbhl-module))
            (dolist (link-node link-nodes)
              (unless *sbhl-finished?*
                (if suspend-test-p
                    (setf terminate-p nil)
                    (setf terminate-p (sbhl-search-path-termination-p link-node)))
                (unless terminate-p
                  (apply-sbhl-mapping-function link-node))
                (when (sbhl-apply-unwind-function-p)
                  (sbhl-apply-unwind-function (list node link-node))))))))))
  nil)

;; (defun sbhl-step-and-suspend-unmark (node) ...) -- commented declareFunction, no body

(defun sbhl-step-and-mark (node)
  "[Cyc] Modifier: Steps over NODE's accessible unmarked links, testing their markings
and subsequently marking them. Applies sbhl-mapping-function."
  (dolist (module-var (get-sbhl-accessible-modules (get-sbhl-module)))
    (unless *sbhl-finished?*
      (let ((*sbhl-module* module-var)
            (*genl-inverse-mode-p* (if (flip-genl-inverse-mode?)
                                       (not *genl-inverse-mode-p*)
                                       *genl-inverse-mode-p*)))
        (let ((nd (naut-to-nart node)))
          (cond
            ((sbhl-node-object-p nd)
             (let ((d-link (get-sbhl-graph-link nd (get-sbhl-module))))
               (if d-link
                   (let ((mt-links (get-sbhl-mt-links d-link
                                                      (get-sbhl-link-direction)
                                                      (get-sbhl-module))))
                     (when mt-links
                       (dohash (mt tv-links mt-links)
                         (unless *sbhl-finished?*
                           (when (relevant-mt? mt)
                             (let ((*sbhl-link-mt* mt))
                               (dohash (tv link-nodes tv-links)
                                 (unless *sbhl-finished?*
                                   (when (relevant-sbhl-tv? tv)
                                     (let ((*sbhl-link-tv* tv))
                                       (dolist (link-node link-nodes)
                                         (unless *sbhl-finished?*
                                           (unless (sbhl-search-path-termination-p link-node)
                                             (sbhl-mark-node-marked link-node)
                                             (apply-sbhl-mapping-function link-node))
                                           (when (sbhl-apply-unwind-function-p)
                                             (sbhl-apply-unwind-function
                                              (list node link-node)))))))))))))))
                   (sbhl-error 5 "attempting to bind direction link variable, to NIL. macro body not executed."))
               ;; Non-fort isa links (only for #$isa module)
               (when (do-sbhl-non-fort-links? nd (get-sbhl-module))
                 (unless *sbhl-finished?*
                   (dolist (instance-tuple (non-fort-instance-table-lookup nd))
                     (unless *sbhl-finished?*
                       (destructuring-bind (link-node mt tv) instance-tuple
                         (when (relevant-mt? mt)
                           (let ((*sbhl-link-mt* mt))
                             (when (relevant-sbhl-tv? tv)
                               (let ((*sbhl-link-tv* tv))
                                 (let ((link-nodes (list link-node)))
                                   (dolist (link-node-2 link-nodes)
                                     (unless *sbhl-finished?*
                                       (unless (sbhl-search-path-termination-p link-node-2)
                                         (sbhl-mark-node-marked link-node-2)
                                         (apply-sbhl-mapping-function link-node-2))
                                       (when (sbhl-apply-unwind-function-p)
                                         (sbhl-apply-unwind-function
                                          (list node link-node-2)))))))))))))))))
            ((cnat-p nd)
             ;; NAUT branch — generating functions
             (dolist (generating-fn (missing-larkc 2709))
               (unless *sbhl-finished?*
                 (let ((*sbhl-link-generator* generating-fn))
                   (let ((link-nodes (funcall generating-fn nd)))
                     (dolist (link-node link-nodes)
                       (unless *sbhl-finished?*
                         (unless (sbhl-search-path-termination-p link-node)
                           (sbhl-mark-node-marked link-node)
                           (apply-sbhl-mapping-function link-node))
                         (when (sbhl-apply-unwind-function-p)
                           (sbhl-apply-unwind-function
                            (list node link-node)))))))))))))))
  nil)

;; (defun sbhl-step-and-unmark (node) ...) -- commented declareFunction, no body

(defun sbhl-sweep (module link-direction tv space map-fn node &optional unmarking?)
  "[Cyc] Takes MODULE, TV, LINK-DIRECTION, SPACE, and MAP-FN parameter and binds them
for the execution of sbhl-mark-and-sweep, as applied to NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (if unmarking?
      (sbhl-unmark-sweep module link-direction tv space map-fn node)
      (let ((*sbhl-module* module)
            (*sbhl-tv* tv)
            (*sbhl-link-direction* link-direction)
            (*sbhl-space* space)
            (*sbhl-map-function* map-fn))
        (unless (sbhl-time-search-p)
          (sbhl-mark-and-sweep node))))
  nil)

(defun sbhl-unmark-sweep (module link-direction tv space map-fn node)
  "[Cyc] Takes MODULE, TV, LINK-DIRECTION, SPACE, and MAP-FN parameter and binds them
for the execution of sbhl-unmark-and-sweep, as applied to NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((*sbhl-module* module)
        (*sbhl-tv* tv)
        (*sbhl-link-direction* link-direction)
        (*sbhl-space* space)
        (*sbhl-map-function* map-fn)
        (*sbhl-search-parent-marking* *sbhl-search-parent-marking*))
    (set-sbhl-search-parent-marking (sbhl-marked-with node))
    (sbhl-unmark-and-sweep node))
  nil)

;; (defun sbhl-sweep-and-unwind (module link-direction tv space map-fn node &optional unmarking?) ...) -- commented declareFunction, no body

(defun sbhl-step (module link-direction tv space map-fn node
                  &optional suspend-marking-p suspend-test-p)
  "[Cyc] Takes MODULE, TV, LINK-DIRECTION, SPACE, and MAP-FN parameter and binds them
for the execution of sbhl-step-and-mark, as applied to NODE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((*sbhl-module* module)
        (*sbhl-tv* tv)
        (*sbhl-link-direction* link-direction)
        (*sbhl-space* space)
        (*sbhl-map-function* map-fn))
    (if suspend-marking-p
        (sbhl-step-and-suspend-mark node suspend-test-p)
        (sbhl-step-and-mark node)))
  nil)

(defun sbhl-step-through (module link-direction tv space map-fn node)
  (declare (type (satisfies sbhl-module-p) module))
  (sbhl-step module link-direction tv space map-fn node t t)
  nil)

(defun sbhl-step-and-test (module link-direction tv space map-fn node &optional unmarking?)
  (declare (type (satisfies sbhl-module-p) module))
  (if unmarking?
      (missing-larkc 2347)
      (sbhl-step module link-direction tv space map-fn node t nil))
  nil)

(defun sbhl-step-and-perform-marking (module link-direction tv space map-fn node
                                      &optional unmarking?)
  (declare (type (satisfies sbhl-module-p) module))
  (if unmarking?
      (missing-larkc 2348)
      (sbhl-step module link-direction tv space map-fn node))
  nil)

;; (defun sbhl-unmark-step (module link-direction tv space map-fn node &optional unmarking?) ...) -- commented declareFunction, no body

(defun apply-sbhl-search-behavior (behavior node)
  "[Cyc] Applies BEHAVIOR to NODE."
  (case behavior
    (sbhl-simple-true-search
     (sbhl-simple-true-search node))
    (sbhl-simple-false-search
     (sbhl-simple-false-search node))
    (sbhl-step-and-sweep-with-tt-module
     (sbhl-step-and-sweep-with-tt-module node))
    (sbhl-sweep-with-tt-module-carry-step
     (sbhl-sweep-with-tt-module-carry-step node))
    (sbhl-sweep-step-disjoins-and-sweep-again
     (sbhl-sweep-step-disjoins-and-sweep-again node))
    (sbhl-simple-true-search-and-unwind
     (missing-larkc 2343))
    (sbhl-leaf-instances-sweep
     (missing-larkc 2333))
    (otherwise
     (sbhl-error 1 "attempt to call unsupported sbhl search behavior: ~a~%" behavior)))
  nil)

(defun apply-sbhl-mapping-function (node)
  "[Cyc] Applies sbhl-map-function to NODE."
  (let ((map-fn (get-sbhl-map-function)))
    (case map-fn
      (sbhl-consider-node
       (sbhl-consider-node node))
      (sbhl-consider-unmarked-node
       (sbhl-consider-unmarked-node node))
      (sbhl-sweep-with-carrying-module
       (sbhl-sweep-with-carrying-module node))
      (sbhl-step-with-carried-module
       (sbhl-step-with-carried-module node))
      (sbhl-step-disjoins-and-sweep-inherited
       (sbhl-step-disjoins-and-sweep-inherited node))
      (sbhl-sweep-inherited-disjoins
       (sbhl-sweep-inherited-disjoins node))
      (sbhl-step-and-check-markings
       (sbhl-step-and-check-markings node))
      (sbhl-step-false-and-sweep-opposite
       (sbhl-step-false-and-sweep-opposite node))
      (sbhl-sweep-opposite-for-false
       (missing-larkc 2346))
      (sbhl-check-cutoff
       (sbhl-check-cutoff node))
      (otherwise
       (funcall map-fn node))))
  nil)

(defun sbhl-apply-unwind-function (node)
  "[Cyc] Applies the *sbhl-unwind-function* to NODE."
  (let ((unwind-fn (get-sbhl-unwind-function)))
    (case unwind-fn
      (sbhl-push-unwind-onto-result
       (sbhl-push-unwind-onto-result node))
      (otherwise
       (funcall unwind-fn node))))
  nil)

(defun sbhl-simple-true-search (node)
  "[Cyc] Used for basic true searches. Applies sbhl-sweep, upon NODE with current
search module, link direction corresponding to current search direction, with a true tv,
in *sbhl-space*, with map-fn sbhl-consider-node."
  (sbhl-sweep (get-sbhl-search-module) (get-sbhl-link-direction)
              (sbhl-search-true-tv) *sbhl-space*
              'sbhl-consider-node node (sbhl-unmarking-search-p))
  nil)

;; (defun sbhl-simple-true-search-and-unwind (node) ...) -- commented declareFunction, no body

(defun sbhl-simple-false-search (node)
  "[Cyc] Used as first part of false searches; it gathers all nodes related by true
predicate links that would carry a false relation to NODE."
  (sbhl-sweep (get-sbhl-search-module) (get-sbhl-opposite-link-direction)
              (sbhl-search-true-tv) *sbhl-space*
              'sbhl-step-false-and-sweep-opposite node (sbhl-unmarking-search-p))
  nil)

(defun sbhl-step-false-and-sweep-opposite (node)
  "[Cyc] Used as second part of false searches; it steps across false relations to NODE."
  (sbhl-step-and-test (get-sbhl-search-module)
                      (sbhl-search-direction-to-link-direction
                       (get-sbhl-search-direction) (get-sbhl-module))
                      (sbhl-search-false-tv) *sbhl-gather-space*
                      'sbhl-sweep-opposite-for-false node)
  nil)

;; (defun sbhl-sweep-opposite-for-false (node) ...) -- commented declareFunction, no body

(defun sbhl-step-and-sweep-with-tt-module (node)
  "[Cyc] Used for step part of step and sweep searches."
  (sbhl-step-and-test (get-sbhl-search-module)
                      (sbhl-search-direction-to-link-direction
                       (get-sbhl-search-direction) (get-sbhl-module))
                      *sbhl-tv* *sbhl-space*
                      'sbhl-sweep-with-carrying-module node)
  nil)

(defun sbhl-sweep-with-carrying-module (node)
  "[Cyc] Used for sweep part of step and sweep searches."
  (sbhl-sweep (get-sbhl-transfers-through-module (get-sbhl-module))
              (if (sbhl-true-search-p)
                  (get-sbhl-link-direction)
                  (get-sbhl-opposite-link-direction))
              (sbhl-search-true-tv) *sbhl-space*
              'sbhl-consider-node node (sbhl-unmarking-search-p))
  nil)

(defun sbhl-sweep-with-tt-module-carry-step (node)
  "[Cyc] Used for sweep part of sweep and step searches."
  (sbhl-sweep (get-sbhl-transfers-through-module (get-sbhl-module))
              (if (sbhl-true-search-p)
                  (get-sbhl-link-direction)
                  (get-sbhl-opposite-link-direction))
              (sbhl-search-true-tv) *sbhl-space*
              'sbhl-step-with-carried-module node (sbhl-unmarking-search-p))
  nil)

(defun sbhl-step-with-carried-module (node)
  "[Cyc] Used for step part of sweep and step searches."
  (when (sbhl-leaf-sample-search-p)
    (enqueue node *sbhl-current-leaf-queue*))
  (sbhl-step-and-perform-marking (get-sbhl-search-module)
                                 (sbhl-search-direction-to-link-direction
                                  (get-sbhl-search-direction) (get-sbhl-module))
                                 (if (sbhl-true-search-p)
                                     (sbhl-search-true-tv)
                                     (sbhl-search-false-tv))
                                 *sbhl-gather-space*
                                 'sbhl-consider-node node (sbhl-unmarking-search-p))
  nil)

(defun sbhl-sweep-step-disjoins-and-sweep-again (node)
  "[Cyc] Used as first part of disjoins searches, or second part of boolean disjoins
searches; it gathers all nodes related by true predicate links that would carry a
disjoins relation to NODE."
  (if (and (sbhl-true-search-p)
           (sbhl-boolean-search-p)
           (or (sbhl-empty-extent-p node)
               (sbhl-goal-empty-extent-p)))
      (if (sbhl-justification-search-p)
          (if (sbhl-goal-empty-extent-p)
              (missing-larkc 2341)
              (missing-larkc 2342))
          (setf *sbhl-result* t))
      (let ((tt-module (get-sbhl-disjoins-search-tt-module (get-sbhl-module))))
        (sbhl-sweep tt-module
                    (if (sbhl-true-search-p)
                        (get-sbhl-module-forward-direction tt-module)
                        (get-sbhl-module-backward-direction tt-module))
                    (sbhl-search-true-tv) *sbhl-space*
                    (if (sbhl-true-search-p)
                        (if (sbhl-boolean-search-p)
                            'sbhl-step-and-check-markings
                            'sbhl-step-disjoins-and-sweep-inherited)
                        'sbhl-sweep-forward-step-false-disjoins-and-sweep-forward-nots)
                    node (sbhl-unmarking-search-p))))
  nil)

(defun sbhl-step-disjoins-and-sweep-inherited (node)
  "[Cyc] Used as second part of disjoins closure searches; it steps across disjoins
relations to NODE."
  (sbhl-step-and-test (get-sbhl-search-module)
                      (get-sbhl-undirected-direction)
                      *sbhl-tv* *sbhl-gather-space*
                      'sbhl-sweep-inherited-disjoins node)
  nil)

(defun sbhl-sweep-inherited-disjoins (node)
  "[Cyc] Used as third part of disjoins closure searches; it gathers all of the
inherited disjoins relations."
  (let ((tt-module (get-sbhl-disjoins-search-tt-module (get-sbhl-module))))
    (sbhl-sweep tt-module
                (if (sbhl-true-search-p)
                    (get-sbhl-module-backward-direction tt-module)
                    (get-sbhl-module-forward-direction tt-module))
                *sbhl-tv* *sbhl-gather-space*
                'sbhl-consider-node node (sbhl-unmarking-search-p))
    nil))

(defun sbhl-step-and-check-markings (node)
  "[Cyc] Used as third part of disjoins boolean search; it steps across disjoins
relations of NODE checking for link nodes marked in gather-space."
  (sbhl-step-through (get-sbhl-search-module)
                     (get-sbhl-undirected-direction)
                     *sbhl-tv* *sbhl-space*
                     'sbhl-consider-any-node node)
  nil)

(defun sbhl-node-locally-disjoint-with-self-p (node)
  (let ((links (sbhl-forward-true-link-nodes
                (get-sbhl-disjoins-module (get-sbhl-search-module))
                node)))
    (member? node links)))

(defun sbhl-empty-extent-p (node)
  (sbhl-gather-first-among-all-forward-true-nodes
   (get-sbhl-disjoins-search-tt-module (get-sbhl-module))
   node #'sbhl-node-locally-disjoint-with-self-p))

(defun sbhl-goal-empty-extent-p ()
  (let ((goal (get-sbhl-goal-node))
        (goals (get-sbhl-goal-nodes))
        (done? nil))
    (cond
      (goal (sbhl-empty-extent-p goal))
      (goals
       (dolist (node goals)
         (unless done?
           (when (sbhl-empty-extent-p node)
             (setf done? t))))
       done?)
      (t nil))))

(defun sbhl-sweep-forward-step-false-disjoins-and-sweep-forward-nots (node)
  "[Cyc] Used in false-disjoins searches while sweeping all backward nodes. From each
it gathers the forward true closure and the local false disjoins and the closures
from them."
  (let ((tt-module (get-sbhl-disjoins-search-tt-module (get-sbhl-module))))
    (unless (or (sbhl-empty-extent-p node)
                (not *assume-sbhl-extensions-nonempty*))
      (sbhl-sweep tt-module
                  (get-sbhl-module-forward-direction tt-module)
                  (sbhl-search-true-tv) *sbhl-gather-space*
                  'sbhl-consider-node node)))
  (sbhl-step-and-test (get-sbhl-search-module)
                      (get-sbhl-undirected-direction)
                      (sbhl-search-false-tv) *sbhl-gather-space*
                      'sbhl-sweep-forward-nots node)
  nil)

;; (defun sbhl-sweep-forward-nots (node) ...) -- commented declareFunction, no body

(defun sbhl-sweep-and-gather-disjoins (node)
  "[Cyc] Used to gather the extremal disjoins. Sweeps the transfer through module
and gathers asserted disjoins."
  (let ((tt-module (get-sbhl-disjoins-search-tt-module (get-sbhl-module))))
    (sbhl-sweep tt-module
                (if (sbhl-true-search-p)
                    (get-sbhl-module-forward-direction tt-module)
                    (get-sbhl-module-backward-direction tt-module))
                (sbhl-search-true-tv) *sbhl-space*
                'sbhl-step-gather-disjoins node))
  nil)

(defun sbhl-step-gather-disjoins (node)
  "[Cyc] Steps and marks asserted disjoins of NODE. Used to gather extremal disjoins."
  (sbhl-step-and-perform-marking (get-sbhl-search-module)
                                 (get-sbhl-undirected-direction)
                                 (if (sbhl-true-search-p)
                                     (sbhl-search-true-tv)
                                     (sbhl-search-false-tv))
                                 *sbhl-gather-space*
                                 'sbhl-consider-node node (sbhl-unmarking-search-p))
  nil)

;; (defun sbhl-sweep-and-gather-first-disjoin (node) ...) -- commented declareFunction, no body
;; (defun sbhl-step-gather-first-disjoin (node) ...) -- commented declareFunction, no body
;; (defun determine-sbhl-sample-leaf-consider-fn (&optional arg1) ...) -- commented declareFunction, no body
;; (defun sbhl-enqueue-node-in-leaf-queue (node) ...) -- commented declareFunction, no body
;; (defun sbhl-leaf-instances-sweep (node) ...) -- commented declareFunction, no body
;; (defun sbhl-leaf-instances-step (node) ...) -- commented declareFunction, no body
;; (defun sbhl-mark-and-sweep-extremal-independent-nodes (node) ...) -- commented declareFunction, no body
;; (defun sbhl-min-backward-true-nodes-such-that (arg1 arg2 arg3 &optional arg4 arg5) ...) -- commented declareFunction, no body
;; (defun sbhl-extremal-independent-nodes-such-that (arg1 arg2) ...) -- commented declareFunction, no body
;; (defun sbhl-test-for-previous-extremal-paths (node) ...) -- commented declareFunction, no body

(defun sbhl-check-disjoins-of-all-backward-nodes (node)
  "[Cyc] Used for implied false relations, which need to check the disjoins of all
of the backward closure of NODE."
  (let ((tt-module (get-sbhl-disjoins-search-tt-module (get-sbhl-module))))
    (sbhl-sweep tt-module
                (get-sbhl-module-backward-direction tt-module)
                (sbhl-search-true-tv) *sbhl-space*
                'sbhl-target-sweep-step-disjoins-and-check node))
  nil)

(defun sbhl-target-sweep-step-disjoins-and-check (node)
  (let ((*sbhl-space* *sbhl-target-space*))
    (let ((tt-module (get-sbhl-disjoins-search-tt-module (get-sbhl-module))))
      (sbhl-sweep tt-module
                  (get-sbhl-module-forward-direction tt-module)
                  (sbhl-search-true-tv) *sbhl-space*
                  'sbhl-step-and-check-markings node)))
  nil)

;; (defun note-kb-access-sbhl-link (arg1 arg2) ...) -- commented declareFunction, no body
