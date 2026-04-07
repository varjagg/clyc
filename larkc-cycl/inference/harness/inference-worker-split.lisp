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

(defun split-link-p (object)
  (and (problem-link-p object)
       (eq :split (problem-link-type object))))

(defun maybe-new-split-link (supported-problem dnf-clause)
  "[Cyc] Return split-link-p, either the already existing one or a new one."
  (let ((split-link (problem-first-split-argument-link supported-problem)))
    (unless split-link
      (let* ((store (problem-store supported-problem))
             (supporting-mapped-problems
               (find-or-create-split-link-supporting-problems store dnf-clause)))
        (setf split-link (new-split-link supported-problem supporting-mapped-problems))))
    split-link))

(defun new-split-link (supported-problem supporting-mapped-problems)
  (let ((split-link (new-problem-link :split supported-problem)))
    (dolist (supporting-mapped-problem supporting-mapped-problems)
      (connect-supporting-mapped-problem-with-dependent-link
       supporting-mapped-problem split-link))
    (propagate-problem-link split-link)
    split-link))

;; (defun destroy-split-link (link) ...) -- active declareFunction, no body

;;; Macro: do-split-link-open-supporting-mapped-problems-numbered
;; Reconstructed from Internal Constants: $list1 (arglist), $sym2$SPLIT_LINK_VAR (gensym),
;; $sym3$CLET, $sym4$DO_PROBLEM_LINK_SUPPORTING_MAPPED_PROBLEMS_NUMBERED,
;; $sym5$PWHEN, $sym6$PROBLEM_LINK_INDEX_OPEN?
;; The macro wraps do-problem-link-supporting-mapped-problems-numbered and adds
;; a check that the index is open on the split-link.
(defmacro do-split-link-open-supporting-mapped-problems-numbered
    ((supporting-mapped-problem-var index-var split-link) &body body)
  (with-temp-vars (split-link-var)
    `(let ((,split-link-var ,split-link))
       (do-problem-link-supporting-mapped-problems-numbered
           (,supporting-mapped-problem-var ,index-var ,split-link-var)
         (when (problem-link-index-open? ,split-link-var ,index-var)
           ,@body)))))

;; (defun split-link-tactic (split-link index) ...) -- active declareFunction, no body
;; (defun split-link-tactics (split-link) ...) -- active declareFunction, no body

(defun close-split-link (split-link)
  "[Cyc] Closes all open supporting mapped problems of SPLIT-LINK and considers
that they could be irrelevant."
  (do-split-link-open-supporting-mapped-problems-numbered
      (supporting-mapped-problem index split-link)
    (problem-link-close-index split-link index)
    (consider-that-mapped-problem-could-be-irrelevant
     supporting-mapped-problem split-link))
  nil)

(defun find-or-create-split-link-supporting-problems (store dnf-clause)
  (let ((split-clauses (determine-shared-variable-islands dnf-clause))
        (supporting-mapped-problems nil))
    (dolist (subquery split-clauses)
      (let ((supporting-mapped-problem (find-or-create-problem store subquery)))
        (push supporting-mapped-problem supporting-mapped-problems)))
    (nreverse supporting-mapped-problems)))

(defparameter *split-module* (inference-structural-module :split))

(defun split-tactic-p (object)
  (and (tactic-p object)
       (eq *split-module* (tactic-hl-module object))))

(defun new-split-tactic (supported-problem index)
  (let ((tactic (new-tactic supported-problem *split-module* index)))
    (do-problem-relevant-strategies (strategy supported-problem)
      (strategy-note-new-tactic strategy tactic))
    tactic))

(defun split-tactic-supporting-mapped-problem-index (tactic)
  (tactic-data tactic))

(defun split-tactic-link (split-tactic)
  (let* ((problem (tactic-problem split-tactic))
         (split-link (problem-sole-split-argument-link problem)))
    (if split-link
        split-link
        (error "Could not find the link for ~a" split-tactic))))

(defun find-split-tactic-supporting-mapped-problem (tactic)
  (declare (type (satisfies split-tactic-p) tactic))
  (let* ((index (split-tactic-supporting-mapped-problem-index tactic))
         (link (split-tactic-link tactic))
         (supporting-mapped-problem
           (find-supporting-mapped-problem-by-index link index)))
    (must supporting-mapped-problem
          "Generalized tactic ~a did not indicate a valid supporting mapped problem"
          tactic)
    (values supporting-mapped-problem link)))

(defun find-split-tactic-supporting-problem (tactic)
  (mapped-problem-problem (find-split-tactic-supporting-mapped-problem tactic)))

;; (defun discard-all-other-possible-split-tactics (tactic) ...) -- active declareFunction, no body
;; (defun determine-new-split-tactics (supported-problem dnf-clause) ...) -- active declareFunction, no body

(defun compute-strategic-properties-of-split-tactic (tactic supporting-problem strategy)
  (let ((problem (tactic-problem tactic)))
    (unless (preference-level-p (tactic-preference-level tactic))
      (multiple-value-bind (preference-level justification)
          (compute-split-tactic-preference-level problem supporting-problem :tactical)
        (set-tactic-preference-level tactic preference-level justification)))
    (multiple-value-bind (strategic-preference-level justification)
        (compute-split-tactic-preference-level problem supporting-problem strategy)
      (set-tactic-strategic-preference-level tactic strategy
                                             strategic-preference-level justification))
    (let ((strategic-productivity
            (compute-split-tactic-productivity problem supporting-problem strategy)))
      (set-tactic-strategic-productivity tactic strategy strategic-productivity)))
  tactic)

(defun compute-split-tactic-productivity (supported-problem supporting-problem strategy)
  (memoized-problem-max-removal-productivity supporting-problem strategy))

(deflexical *split-tactic-default-preference-level* :preferred
  "[Cyc] The default preference level used for split tactics.
Splits are independent of each other, so no bindings from one half
could possibly make the other half any more solvable.
Hence, all splits should be preferred by default.
However, if any split is disallowed, the entire problem should be deemed no-good.")

(deflexical *split-tactic-default-preference-level-justification*
  "the default for split tactics")

(defun compute-split-tactic-preference-level (supported-problem supporting-problem
                                              strategic-context)
  (multiple-value-bind (supporting-preference-level justification)
      (memoized-problem-global-preference-level supporting-problem strategic-context nil)
    (unless (eq supporting-preference-level :disallowed)
      (setf supporting-preference-level *split-tactic-default-preference-level*)
      (setf justification *split-tactic-default-preference-level-justification*))
    (values supporting-preference-level justification)))

(defun execute-split-tactic (tactic)
  (let ((split-link (split-tactic-link tactic))
        (index (split-tactic-supporting-mapped-problem-index tactic)))
    (problem-link-open-and-repropagate-index split-link index))
  tactic)

(defun problem-sole-split-argument-link (problem)
  "[Cyc] PROBLEM should have exactly one argument link which is a split link.
Signals an error if this is not the case."
  (problem-sole-argument-link-of-type problem :split))

(defun problem-first-split-argument-link (problem)
  "[Cyc] Return nil or split-link-p."
  (problem-first-argument-link-of-type problem :split))

;; (defun problem-has-split-argument-link? (problem) ...) -- active declareFunction, no body

(defun split-tactic-lookahead-problem (split-tactic)
  (let ((supporting-mapped-problem
          (find-split-tactic-supporting-mapped-problem split-tactic)))
    (mapped-problem-problem supporting-mapped-problem)))

;; (defun split-link-supporting-problems-with-variables (split-link) ...) -- active declareFunction, no body

(defun new-split-proof (link subproofs-with-sub-bindings)
  "[Cyc] Return 0 proof-p; Return 1 whether the returned proof was newly created."
  (new-conjunctive-proof link subproofs-with-sub-bindings))

(defun split-proof-p (object)
  (and (proof-p object)
       (eq :split (proof-type object))))

(defun bubble-up-proof-to-split-link (supporting-proof my-variable-map split-link)
  "[Cyc] First we translate the subproofs' bindings into terms of SPLIT-LINK's
supported problem, then we cartesian-product them and make new proofs."
  (let ((proofs nil)
        (supporting-mapped-proof-lists-by-supporting-problem nil)
        (my-supporting-problem (proof-supported-problem supporting-proof)))
    (do-problem-link-supporting-mapped-problems (supporting-mapped-problem split-link)
      (let ((supporting-problem (mapped-problem-problem supporting-mapped-problem))
            (variable-map (mapped-problem-variable-map supporting-mapped-problem)))
        (if (and (eq supporting-problem my-supporting-problem)
                 (bindings-equal? variable-map my-variable-map))
            ;; This is the supporting problem that generated the proof
            (let* ((proof-bindings (proof-bindings supporting-proof))
                   (sub-proof-bindings
                     (transfer-variable-map-to-bindings my-variable-map proof-bindings)))
              (push (list (cons supporting-proof sub-proof-bindings))
                    supporting-mapped-proof-lists-by-supporting-problem))
            ;; Other supporting problems: collect all proven proofs
            (let ((proofs-with-bindings nil))
              (do-problem-proofs (proof supporting-problem :proof-status :proven)
                (let ((sub-proof-bindings
                        (transfer-variable-map-to-bindings
                         variable-map (proof-bindings proof))))
                  (push (cons proof sub-proof-bindings) proofs-with-bindings)))
              (push proofs-with-bindings
                    supporting-mapped-proof-lists-by-supporting-problem)))))
    (setf supporting-mapped-proof-lists-by-supporting-problem
          (nreverse supporting-mapped-proof-lists-by-supporting-problem))
    (let ((mapped-subproof-lists
            (cartesian-product supporting-mapped-proof-lists-by-supporting-problem)))
      (dolist (mapped-subproof-list mapped-subproof-lists)
        (multiple-value-bind (proof new?)
            (new-split-proof split-link mapped-subproof-list)
          (if new?
              (push proof proofs)
              (possibly-note-proof-processed supporting-proof)))))
    (setf proofs (nreverse proofs))
    (dolist (proof proofs)
      (bubble-up-proof proof))
    proofs))

(defun all-literals-connected-by-shared-vars? (dnf-clause)
  (dolist (contextualized-asent (neg-lits dnf-clause))
    (when (hl-ground-tree-p contextualized-asent)
      (return-from all-literals-connected-by-shared-vars? nil)))
  (dolist (contextualized-asent (pos-lits dnf-clause))
    (when (hl-ground-tree-p contextualized-asent)
      (return-from all-literals-connected-by-shared-vars? nil)))
  (multiple-value-bind (connected-groups isolated-groups)
      (categorize-clause-variables-via-literals dnf-clause)
    (and (null isolated-groups)
         (singleton? connected-groups))))

(defun determine-shared-variable-islands (dnf-clause)
  "[Cyc] Return list of problem-query-p."
  (let ((islands nil))
    (if (hl-ground-tree-p dnf-clause)
        (progn
          (dolist (contextualized-asent (neg-lits dnf-clause))
            (let* ((sense :neg)
                   (island (new-problem-query-from-contextualized-asent-sense
                            contextualized-asent sense)))
              (push island islands)))
          (dolist (contextualized-asent (pos-lits dnf-clause))
            (let* ((sense :pos)
                   (island (new-problem-query-from-contextualized-asent-sense
                            contextualized-asent sense)))
              (push island islands))))
        (let ((sensified-clause (sensify-contextualized-clause dnf-clause)))
          (multiple-value-bind (connected-groups isolated-groups)
              (categorize-sensified-clause-variables-via-literals sensified-clause)
            (dolist (group connected-groups)
              (let ((island (categorized-group-to-problem-query group)))
                (push island islands)))
            (dolist (group isolated-groups)
              (let ((island (categorized-group-to-problem-query group)))
                (push island islands))))))
    (fast-delete-duplicates islands #'equal)))

(defun categorize-clause-variables-via-literals (clause)
  (let ((all-hl-vars (tree-gather clause #'hl-variable-p))
        (all-literals (all-literals-as-asents clause)))
    (categorize-nodes-via-links all-hl-vars all-literals)))

(defun categorize-sensified-clause-variables-via-literals (sensified-clause)
  (let ((ground-groups nil))
    (dolist (sensified-literal sensified-clause)
      (when (hl-ground-tree-p sensified-literal)
        (let ((group (ground-sensified-literal-to-categorized-group sensified-literal)))
          (push group ground-groups))))
    (let ((all-hl-vars (tree-gather sensified-clause #'hl-variable-p))
          (all-literals sensified-clause))
      (multiple-value-bind (connected-groups isolated-groups naked-groups)
          (categorize-nodes-via-links all-hl-vars all-literals)
        (declare (ignore naked-groups))
        (values connected-groups (nconc ground-groups isolated-groups))))))

(defun sensify-contextualized-clause (clause)
  (let ((literals nil))
    (dolist (contextualized-asent (neg-lits clause))
      (push (negate contextualized-asent) literals))
    (dolist (contextualized-asent (pos-lits clause))
      (push contextualized-asent literals))
    (nreverse literals)))

;; (defun unmake-sensified-literal (sensified-literal) ...) -- active declareFunction, no body

(defun ground-sensified-literal-to-categorized-group (sensified-literal)
  (list nil (list sensified-literal)))

(defun categorized-group-to-problem-query (group)
  "[Cyc] Takes the return value of categorize-variables-via-literals and turns it
into a problem query.
Return problem-query-p."
  (let ((neg-lits nil)
        (pos-lits nil)
        (group-lits (second group)))
    (dolist (literal group-lits)
      (if (el-negation-p literal)
          (push (literal-atomic-sentence literal) neg-lits)
          (push literal pos-lits)))
    (setf neg-lits (nreverse neg-lits))
    (setf pos-lits (nreverse pos-lits))
    (new-problem-query-from-contextualized-clause (make-clause neg-lits pos-lits))))


;;; Meta-split tactics

(defparameter *meta-split-tactics-enabled?* t
  "[Cyc] Temporary control variable, @todo hard-code to T.")

(defun meta-split-tactics-enabled? ()
  *meta-split-tactics-enabled?*)

(deflexical *determine-new-split-tactics-module*
  (if (and (boundp '*determine-new-split-tactics-module*)
           *determine-new-split-tactics-module*)
      *determine-new-split-tactics-module*
      (inference-meta-structural-module :determine-new-split-tactics)))

(deflexical *meta-split-tactic-default-preference-level* :preferred)

(deflexical *meta-split-tactic-default-preference-level-justification*
  "the default for meta-split tactics")

(defun meta-split-tactic-p (object)
  (and (tactic-p object)
       (eq *determine-new-split-tactics-module* (tactic-hl-module object))))

;; (defun generalized-split-tactic-p (object) ...) -- active declareFunction, no body

(defun meta-split-tactic-link (meta-split-tactic)
  (split-tactic-link meta-split-tactic))

(defun meta-split-tactic-todo-indices (meta-split-tactic)
  (tactic-data meta-split-tactic))

(defun meta-split-tactic-index-done? (meta-split-tactic index)
  (let ((todo-indices (meta-split-tactic-todo-indices meta-split-tactic)))
    (not (member-eq? index todo-indices))))

;; (defun meta-split-tactic-productivity (meta-split-tactic) ...) -- active declareFunction, no body

(defun determine-new-meta-split-tactics (supported-problem dnf-clause)
  (let* ((split-link (maybe-new-split-link supported-problem dnf-clause))
         (supporting-problem-count
           (problem-link-supporting-mapped-problem-count split-link)))
    (must (> supporting-problem-count 1)
          "Tried to make a split link with less than two supporting problems: ~a"
          split-link)
    (consider-that-problem-could-be-no-good supported-problem nil :tactical t)
    (unless (no-good-problem-p supported-problem :tactical)
      (new-meta-split-tactic supported-problem)
      (return-from determine-new-meta-split-tactics t)))
  nil)

(defun new-meta-split-tactic (problem)
  (let* ((split-link (problem-sole-split-argument-link problem))
         (supporting-problem-count
           (problem-link-supporting-mapped-problem-count split-link))
         (todo-indices (copy-list (num-list supporting-problem-count)))
         (tactic (new-tactic problem
                             *determine-new-split-tactics-module*
                             todo-indices)))
    (note-tactic-progress-iterator tactic (new-meta-split-progress-iterator tactic))
    (do-problem-relevant-strategies (strategy problem)
      (strategy-note-new-tactic strategy tactic))
    tactic))

(defun compute-strategic-properties-of-meta-split-tactic (tactic strategy)
  (unless (preference-level-p (tactic-preference-level tactic))
    (set-tactic-preference-level tactic
                                 *meta-split-tactic-default-preference-level*
                                 *meta-split-tactic-default-preference-level-justification*))
  (set-tactic-strategic-preference-level tactic strategy
                                         *meta-split-tactic-default-preference-level*
                                         *meta-split-tactic-default-preference-level-justification*)
  (set-tactic-strategic-productivity tactic strategy 0)
  tactic)

(defun new-meta-split-progress-iterator (tactic)
  (new-tactic-progress-iterator :meta-structural tactic nil))

(defun meta-structural-progress-iterator-done? (tactic)
  (if (meta-split-tactic-p tactic)
      (meta-split-progress-iterator-done? tactic)
      (error "unexpected meta-structural tactic ~s" tactic)))

(defun meta-split-progress-iterator-done? (tactic)
  (let ((supported-problem (tactic-problem tactic))
        (todo-indices (meta-split-tactic-todo-indices tactic)))
    (or (null todo-indices)
        (no-good-problem-p supported-problem :tactical))))

(defparameter *meta-split-criteria* nil
  "[Cyc] If you set this to non-nil, it will trump the following variables.")

(defparameter *meta-split-tactics-do-single-literals-first?* t)

(defparameter *meta-split-favors-problem-reuse?* t)

(defun meta-split-criteria ()
  (cond (*meta-split-criteria*
         *meta-split-criteria*)
        (*meta-split-tactics-do-single-literals-first?*
         '(:one-no-good :all-single-literal :all-the-rest))
        (*meta-split-favors-problem-reuse?*
         '(:one-no-good :one-closed-problem-reuse :all-single-literal-problem-reuse
           :one-closed :all-the-rest))
        (t
         '(:one-no-good :one-closed :all-the-rest))))

(defun execute-meta-split-tactic (tactic)
  (let ((supported-problem (tactic-problem tactic)))
    (unless (tactically-no-good-problem-p supported-problem)
      (let ((split-link (meta-split-tactic-link tactic))
            (problem-index-pairs nil)
            (done? nil))
        (csome (meta-split-criterion (meta-split-criteria) done?)
          (do-problem-link-supporting-mapped-problems-numbered
              (supporting-mapped-problem index split-link :done done?)
            (unless (meta-split-tactic-index-done? tactic index)
              (let ((supporting-problem
                      (mapped-problem-problem supporting-mapped-problem)))
                (multiple-value-bind (applicable? stop-after-each-one?)
                    (meta-split-criterion-applicable? meta-split-criterion
                                                     supporting-problem)
                  (when applicable?
                    (push (list index supporting-problem) problem-index-pairs)
                    (when stop-after-each-one?
                      (setf done? t)))))))
          (when problem-index-pairs
            (setf done? t)))
        (meta-split-tactic-create-and-activate-split-tactics
         tactic supported-problem problem-index-pairs))))
  nil)

(defun meta-split-criterion-applicable? (meta-split-criterion conjunct-problem)
  "[Cyc] Return 0 booleanp; whether META-SPLIT-CRITERION applies to CONJUNCT-PROBLEM.
Return 1 booleanp; If NIL, all tactics leading to conjunct problems that pass the
applicability test will be activated as a group. If T, the first problem passing
the applicability test will be activated by itself."
  (case meta-split-criterion
    (:one-no-good
     (values (tactically-no-good-problem-p conjunct-problem) t))
    (:all-single-literal
     (values (single-literal-problem-p conjunct-problem) nil))
    (:all-problem-reuse
     ;; Likely checks problem-dependent-link-count > 1 for problem reuse
     (values (> (missing-larkc 35370) 1) nil))
    (:one-closed
     (values (closed-problem-p conjunct-problem) t))
    (:one-closed-problem-reuse
     ;; Likely checks closed AND problem-dependent-link-count > 1
     (values (and (closed-problem-p conjunct-problem)
                  (> (missing-larkc 35371) 1))
             t))
    (:all-single-literal-problem-reuse
     ;; Likely checks single-literal AND problem-dependent-link-count > 1
     (values (and (single-literal-problem-p conjunct-problem)
                  (> (missing-larkc 35372) 1))
             nil))
    (:all-the-rest
     (values t nil))
    (otherwise
     (error "Unknown meta-split criterion ~s" meta-split-criterion))))

(defun meta-split-tactic-create-and-activate-split-tactics (meta-split-tactic
                                                            supported-problem
                                                            problem-index-pairs)
  (let ((split-tactics nil))
    (dolist (pair problem-index-pairs)
      (destructuring-bind (index supporting-problem) pair
        (declare (ignore supporting-problem))
        (let ((split-tactic (meta-split-tactic-create-one-split-tactic
                             meta-split-tactic supported-problem index)))
          (push split-tactic split-tactics))))
    (note-split-tactics-strategically-possible split-tactics)
    split-tactics))

(defun meta-split-tactic-create-one-split-tactic (meta-split-tactic
                                                   supported-problem index)
  (meta-split-tactic-note-split-tactic-done meta-split-tactic index)
  (new-split-tactic supported-problem index))

(defun meta-split-tactic-note-split-tactic-done (tactic index)
  (let ((todo-indices (meta-split-tactic-todo-indices tactic)))
    (setf todo-indices (delete index todo-indices))
    (set-meta-split-tactic-data tactic todo-indices))
  tactic)

(defun note-split-tactics-strategically-possible (split-tactics)
  (when split-tactics
    (let ((supported-problem (tactic-problem (first split-tactics))))
      (do-problem-relevant-strategies (strategy supported-problem)
        (strategy-note-split-tactics-strategically-possible strategy split-tactics))))
  nil)


;;; Toplevel forms

(toplevel (declare-defglobal '*determine-new-split-tactics-module*))
