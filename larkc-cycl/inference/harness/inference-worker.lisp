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

;; The inference worker handles tactic determination, execution, proof bubbling,
;; problem status propagation, link propagation, and problem store pruning.

(defparameter *currently-executing-tactic* nil)

(defun currently-executing-tactic ()
  "[Cyc] Return nil or tactic-p; the current tactic under execution, or NIL if none."
  *currently-executing-tactic*)

;; Reconstructed from: $list0=(TACTIC &BODY BODY), $sym1$CLET, $sym2$*CURRENTLY-EXECUTING-TACTIC*
;; Expansion: binds *currently-executing-tactic* to TACTIC around BODY
(defmacro within-tactic-execution ((tactic) &body body)
  `(let ((*currently-executing-tactic* ,tactic))
     ,@body))

;; (defun currently-executing-hl-module () ...) -- active declareFunction, no body

(defparameter *currently-active-problem* nil)

(defun currently-active-problem ()
  "[Cyc] Return nil or problem-p; the problem of the current tactic under execution, or the problem whose tactics are being determined, or NIL if none."
  (let ((tactic (currently-executing-tactic)))
    (if tactic
        (tactic-problem tactic)
        *currently-active-problem*)))

;; Reconstructed from: $list3=(PROBLEM &BODY BODY), $sym4$*CURRENTLY-ACTIVE-PROBLEM*,
;; $list5=((*CURRENTLY-EXECUTING-TACTIC* NIL))
;; Expansion: binds *currently-active-problem* and clears *currently-executing-tactic*
(defmacro within-problem-consideration ((problem) &body body)
  `(let ((*currently-active-problem* ,problem)
          (*currently-executing-tactic* nil))
     ,@body))

;; (defun currently-active-problem-query () ...) -- active declareFunction, no body

;; Reconstructed from: $list6=(STORE &BODY BODY), $sym7$*NEGATION-BY-FAILURE*,
;; $sym8$PROBLEM-STORE-NEGATION-BY-FAILURE?
;; Expansion: binds *negation-by-failure* from the problem store
(defmacro with-problem-store-tactical-evaluation-properties ((store) &body body)
  `(let ((*negation-by-failure* (problem-store-negation-by-failure? ,store)))
     ,@body))

(defun currently-active-problem-store ()
  "[Cyc] Return nil or problem-store-p; the problem-store of the currently active problem, or NIL if none."
  (let ((problem (currently-active-problem)))
    (when problem
      (problem-store problem))))

;; (defun currently-active-problem-store-creation-time () ...) -- active declareFunction, no body

(defun determine-new-tactics (problem)
  "[Cyc] Determines the tactics for PROBLEM, adds them to PROBLEM, and sets the status of PROBLEM to :possible."
  (declare (type problem-p problem))
  (must (tactically-unexamined-problem-p problem)
        "~a was not an :unexamined problem, so cannot determine its tactics" problem)
  (must (null (problem-tactics problem))
        "~a was :unexamined but somehow got some tactics already." problem)
  (within-problem-consideration (problem)
    (if (single-clause-problem-p problem)
        (let ((clause (problem-sole-clause problem)))
          (determine-new-tactics-for-dnf-clause problem clause))
        (let ((query (problem-query problem)))
          ;; Likely determines new tactics for a disjunction of clauses
          (missing-larkc 35213)))
    (note-problem-examined problem)
    (discard-all-impossible-possible-tactics problem)
    (consider-that-problem-could-be-no-good problem nil :tactical t)
    (do-problem-relevant-strategies (strategy problem)
      (consider-that-problem-could-be-no-good problem nil strategy t)))
  problem)

;; (defun determine-new-tactics-for-disjunction (problem query) ...) -- active declareFunction, no body

(defun determine-new-tactics-for-dnf-clause (problem dnf-clause)
  (cond ((pos-atomic-clause-p dnf-clause)
         (determine-new-tactics-for-literal problem
                                            (atomic-clause-asent dnf-clause) :pos))
        ((neg-atomic-clause-p dnf-clause)
         (determine-new-tactics-for-literal problem
                                            (atomic-clause-asent dnf-clause) :neg))
        (t (determine-new-tactics-for-multiple-literals problem dnf-clause))))

(defun determine-new-tactics-for-multiple-literals (problem dnf-clause)
  (determine-new-conjunctive-removal-tactics problem dnf-clause)
  (if (all-literals-connected-by-shared-vars? dnf-clause)
      (determine-new-connected-conjunction-tactics problem dnf-clause)
      (if (meta-split-tactics-enabled?)
          (determine-new-meta-split-tactics problem dnf-clause)
          (missing-larkc 36478))))

(defun determine-new-connected-conjunction-tactics (problem dnf-clause)
  (determine-new-join-ordered-tactics problem dnf-clause)
  (determine-new-join-tactics problem dnf-clause)
  nil)

(defun determine-new-tactics-for-literal (problem contextualized-asent sense)
  (destructuring-bind (mt asent) contextualized-asent
    (when (hlmt-p mt)
      (with-inference-mt-relevance (mt)
        (determine-new-literal-removal-tactics problem asent sense)
        (when (problem-store-rewrite-allowed? (problem-store problem))
          ;; Likely determines new literal rewrite tactics
          (missing-larkc 32957))
        (when (problem-store-transformation-allowed? (problem-store problem))
          (add-tactic-to-determine-new-literal-transformation-tactics problem asent sense mt)))))
  nil)

(defun possibly-compute-strategic-properties-of-problem-tactics (problem strategy)
  (declare (type strategy-p strategy))
  (when (strategically-unexamined-problem-p problem strategy)
    (strategy-compute-strategic-properties-of-problem-tactics strategy problem))
  problem)

(defun strategy-compute-strategic-properties-of-problem-tactics (strategy problem)
  (compute-strategic-properties-of-problem-tactics problem strategy :non-discarded))

(defun compute-strategic-properties-of-problem-tactics (problem strategy &optional status)
  (dolist (tactic (problem-tactics problem))
    (when (do-problem-tactics-status-match tactic status)
      (possibly-compute-strategic-properties-of-tactic tactic strategy)))
  nil)

(defun possibly-compute-strategic-properties-of-tactic (tactic strategy)
  (unless (strategy-chooses-not-to-examine-tactic? strategy tactic)
    (strategy-note-new-tactic strategy tactic)
    t))

(defun strategy-chooses-not-to-examine-tactic? (strategy tactic)
  (not (and (strategy-admits-tactic-wrt-proof-spec? strategy tactic)
            (strategy-allows-use-of-tactic-hl-module? strategy tactic))))

(defun default-compute-strategic-properties-of-tactic (strategy tactic)
  "[Cyc] Depending on what type of tactic TACTIC is, compute its strategic properties wrt STRATEGY."
  (cond ((split-tactic-p tactic)
         (let ((supporting-problem (find-split-tactic-supporting-problem tactic)))
           (compute-strategic-properties-of-split-tactic tactic supporting-problem strategy)))
        ((meta-split-tactic-p tactic)
         (compute-strategic-properties-of-meta-split-tactic tactic strategy))
        ((union-tactic-p tactic)
         (let ((disjunct-index (missing-larkc 33019)))
           (missing-larkc 33005)))
        ((join-ordered-tactic-p tactic)
         (compute-strategic-properties-of-join-ordered-tactic tactic strategy))
        ((join-tactic-p tactic)
         (compute-strategic-properties-of-join-tactic tactic strategy))
        ((transformation-tactic-p tactic)
         (compute-strategic-properties-of-transformation-tactic tactic strategy))
        ((meta-transformation-tactic-p tactic)
         (missing-larkc 36428))
        ((removal-tactic-p tactic)
         (compute-strategic-properties-of-removal-tactic tactic strategy))
        ((meta-removal-tactic-p tactic)
         (missing-larkc 36109))
        ((rewrite-tactic-p tactic)
         (missing-larkc 32956))
        ((conjunctive-removal-tactic-p tactic)
         ;; Likely computes strategic properties of conjunctive removal tactic
         (missing-larkc 0))
        (t (error "unexpected tactic ~S" tactic)))
  tactic)

(defun execute-tactic (tactic)
  (must (not (eq tactic (currently-executing-tactic)))
        "Tried to recursively execute ~a" tactic)
  (must (tactic-possible? tactic)
        "Tried to execute a tactic that was not possible: ~s" tactic)
  (within-tactic-execution (tactic)
    (note-tactic-most-recent-executed tactic)
    (cond ((single-literal-tactic-p tactic)
           (execute-literal-level-tactic tactic))
          ((generalized-conjunctive-tactic-p tactic)
           (execute-multiple-literal-tactic tactic))
          ((disjunctive-tactic-p tactic)
           ;; Likely executes disjunctive tactic
           (missing-larkc 35226))
          (t (error "unexpected tactic ~s" tactic)))
    (possibly-note-tactic-finished tactic))
  tactic)

;; (defun possibly-execute-tactic (tactic) ...) -- active declareFunction, no body

(defun possibly-note-tactic-finished (tactic)
  (cond ((tactic-in-progress? tactic) nil)
        ((tactic-executed? tactic) nil)
        (t (note-tactic-finished tactic)
           t)))

(defparameter *asent-of-currently-executing-tactic* nil)
(defparameter *mt-of-currently-executing-tactic* nil)

;; Reconstructed from: $list23=((ASENT MT) &BODY BODY),
;; $sym24$*ASENT-OF-CURRENTLY-EXECUTING-TACTIC*, $sym25$*MT-OF-CURRENTLY-EXECUTING-TACTIC*
(defmacro within-single-literal-tactic-with-asent-and-mt (((asent mt)) &body body)
  `(let ((*asent-of-currently-executing-tactic* ,asent)
          (*mt-of-currently-executing-tactic* ,mt))
     ,@body))

;; (defun asent-of-currently-executing-tactic () ...) -- active declareFunction, no body
;; (defun mt-of-currently-executing-tactic () ...) -- active declareFunction, no body

(defun single-literal-tactic-p (tactic)
  (or (literal-level-removal-tactic-p tactic)
      (literal-level-meta-removal-tactic-p tactic)
      (literal-level-transformation-tactic-p tactic)
      (literal-level-rewrite-tactic-p tactic)))

(defun execute-literal-level-tactic (tactic)
  (let* ((problem (tactic-problem tactic))
         (query (problem-query problem)))
    (multiple-value-bind (mt asent sense)
        (mt-asent-sense-from-singleton-query query)
      (within-single-literal-tactic-with-asent-and-mt ((asent mt))
        (cond ((literal-level-removal-tactic-p tactic)
               (execute-literal-level-removal-tactic tactic mt asent sense))
              ((literal-level-meta-removal-tactic-p tactic)
               ;; Likely executes literal-level meta-removal tactic
               (missing-larkc 36226))
              ((literal-level-transformation-tactic-p tactic)
               (execute-literal-level-transformation-tactic tactic mt asent sense))
              ((literal-level-rewrite-tactic-p tactic)
               ;; Likely executes literal-level rewrite tactic
               (missing-larkc 32958))
              (t (error "Got a literal-level tactic ~s that was neither a transformation nor a removal nor a rewrite"
                        tactic))))))
  tactic)

(defun literal-level-tactic-p (tactic)
  (and (not (conjunctive-tactic-p tactic))
       (not (disjunctive-tactic-p tactic))))

;; (defun execute-multiple-clause-tactic (tactic) ...) -- active declareFunction, no body

(defun execute-multiple-literal-tactic (tactic)
  (cond ((structural-tactic-p tactic)
         (execute-structural-multiple-literal-tactic tactic))
        ((meta-structural-tactic-p tactic)
         (execute-meta-structural-multiple-literal-tactic tactic))
        ((conjunctive-removal-tactic-p tactic)
         ;; Likely executes conjunctive removal tactic
         (missing-larkc 36225))
        (t (error "Unexpected multiple literal tactic module ~a"
                  (tactic-hl-module tactic))))
  nil)

(defun execute-structural-multiple-literal-tactic (tactic)
  (cond ((split-tactic-p tactic)
         (execute-split-tactic tactic))
        ((join-ordered-tactic-p tactic)
         (execute-join-ordered-tactic tactic))
        ((join-tactic-p tactic)
         (execute-join-tactic tactic))
        (t (error "Unexpected structural multiple literal tactic module ~a"
                  (tactic-hl-module tactic))))
  nil)

(defun execute-meta-structural-multiple-literal-tactic (tactic)
  (cond ((meta-split-tactic-p tactic)
         (tactic-in-progress-next tactic))
        (t (error "Unexpected meta-structural multiple literal tactic module ~a"
                  (tactic-hl-module tactic))))
  nil)

(defun connected-conjunction-link-p (object)
  (or (join-ordered-link-p object)
      (join-link-p object)))

(defun connected-conjunction-tactic-p (object)
  (or (join-ordered-tactic-p object)
      (join-tactic-p object)))

(defun connected-conjunction-link-tactic (link)
  "[Cyc] Return connected-conjunction-tactic-p"
  (cond ((join-ordered-link-p link) (join-ordered-link-tactic link))
        ((join-link-p link) (join-link-tactic link))
        (t (error "unexpected connected conjunction link ~s" link))))

(defun connected-conjunction-tactic-link (tactic)
  "[Cyc] Return connected-conjunction-tactic-p"
  (cond ((join-ordered-tactic-p tactic) (join-ordered-tactic-link tactic))
        ((join-tactic-p tactic) (join-tactic-link tactic))
        (t (error "unexpected connected conjunction tactic ~s" tactic))))

(defun conjunctive-link-p (object)
  (or (split-link-p object)
      (connected-conjunction-link-p object)))

(defun logical-conjunctive-tactic-p (object)
  (or (split-tactic-p object)
      (connected-conjunction-tactic-p object)))

(defun conjunctive-tactic-p (object)
  (or (logical-conjunctive-tactic-p object)
      (conjunctive-removal-tactic-p object)))

(defun meta-conjunctive-tactic-p (object)
  (meta-split-tactic-p object))

(defun generalized-conjunctive-tactic-p (object)
  (or (conjunctive-tactic-p object)
      (meta-conjunctive-tactic-p object)))

(defun connected-conjunction-tactic-literal-count (conjunctive-tactic)
  (if (join-ordered-tactic-p conjunctive-tactic)
      (clause-literal-count (join-ordered-tactic-focal-supporting-problem-spec conjunctive-tactic))
      1))

(defun disjunctive-link-p (object)
  (or (union-link-p object)
      (disjunctive-assumption-link-p object)))

(defun logical-disjunctive-tactic-p (object)
  (or (union-tactic-p object)
      (disjunctive-assumption-tactic-p object)))

(defun disjunctive-tactic-p (object)
  (logical-disjunctive-tactic-p object))

;; (defun disjunctive-link-tactic (object) ...) -- active declareFunction, no body

(defun logical-link-p (object)
  (or (conjunctive-link-p object)
      (disjunctive-link-p object)))

(defun logical-tactic-p (object)
  (or (logical-conjunctive-tactic-p object)
      (logical-disjunctive-tactic-p object)))

;; (defun logical-link-with-unique-tactic-p (object) ...) -- active declareFunction, no body

(defun logical-tactic-with-unique-lookahead-problem-p (tactic)
  (and (logical-tactic-p tactic)
       (not (join-tactic-p tactic))))

(defun logical-link-unique-tactic (link)
  (cond ((join-ordered-link-p link) (join-ordered-link-tactic link))
        ((join-link-p link) (join-link-tactic link))
        ((union-link-p link) (missing-larkc 33017))
        (t (error "~s was not a logical-link-with-unique-tactic-p" link))))

(defun logical-tactic-link (logical-tactic)
  (let ((pcase-var (tactic-hl-module-name logical-tactic)))
    (cond ((eq pcase-var :split) (split-tactic-link logical-tactic))
          ((eq pcase-var :join-ordered) (join-ordered-tactic-link logical-tactic))
          ((eq pcase-var :union) (missing-larkc 33022))
          ((eq pcase-var :join) (join-tactic-link logical-tactic))
          (t (error "Unexpected logical tactic module ~S"
                    (tactic-hl-module logical-tactic))))))

(defun logical-tactic-lookahead-problem (logical-tactic)
  (let ((pcase-var (tactic-hl-module-name logical-tactic)))
    (cond ((eq pcase-var :split) (split-tactic-lookahead-problem logical-tactic))
          ((eq pcase-var :join-ordered) (join-ordered-tactic-lookahead-problem logical-tactic))
          ((eq pcase-var :union) (missing-larkc 33024))
          ((eq pcase-var :join) (error "Join tactics like ~S do not have a unique lookahead problem."
                                       logical-tactic))
          (t (error "Unexpected logical tactic module ~S"
                    (tactic-hl-module logical-tactic))))))

;; (defun logical-proof-p (proof) ...) -- active declareFunction, no body
;; (defun structural-link-p (object) ...) -- active declareFunction, no body

(defun structural-tactic-p (tactic)
  (logical-tactic-p tactic))

(defun meta-structural-tactic-p (tactic)
  (meta-conjunctive-tactic-p tactic))

(defun generalized-structural-tactic-p (tactic)
  (or (structural-tactic-p tactic)
      (meta-structural-tactic-p tactic)))

;; (defun structural-tactic-lookahead-problem (tactic) ...) -- active declareFunction, no body
;; (defun structural-proof-p (proof) ...) -- active declareFunction, no body

(defun structural-proof-type (structural-proof)
  (declare (type structural-proof-p structural-proof))
  (problem-link-type (proof-link structural-proof)))

(defun content-link-p (object)
  (or (removal-link-p object)
      (transformation-link-p object)
      (residual-transformation-link-p object)
      (rewrite-link-p object)))

(defun content-tactic-p (object)
  (or (generalized-removal-tactic-p object)
      (transformation-tactic-p object)
      (rewrite-tactic-p object)))

(defun content-proof-p (proof)
  (and (proof-p proof)
       (content-link-p (proof-link proof))))

(defun content-link-supports (content-link)
  (cond ((removal-link-p content-link) (removal-link-supports content-link))
        ((transformation-link-p content-link) (transformation-link-supports content-link))
        ((residual-transformation-link-p content-link)
         (transformation-link-supports (missing-larkc 35073)))
        ((rewrite-link-p content-link) (missing-larkc 32967))
        (t (error "~a is not a CONTENT-LINK-P" content-link)))
  nil)

;; (defun content-link-tactic (content-link) ...) -- active declareFunction, no body

(defun content-link-hl-module (content-link)
  (cond ((removal-link-p content-link) (removal-link-hl-module content-link))
        ((transformation-link-p content-link) (transformation-link-hl-module content-link))
        ((residual-transformation-link-p content-link)
         (transformation-link-hl-module (missing-larkc 35075)))
        ((rewrite-link-p content-link) (missing-larkc 32964))
        (t (error "~a is not a CONTENT-LINK-P" content-link)))
  nil)

(defun content-proof-hl-module (proof)
  (let* ((link (proof-link proof))
         (hl-module (content-link-hl-module link)))
    hl-module))

;; (defun content-tactic-actual-productivity (tactic) ...) -- active declareFunction, no body
;; (defun removal-tactic-actual-productivity (tactic) ...) -- active declareFunction, no body
;; (defun single-literal-removal-tactic-actual-productivity (tactic) ...) -- active declareFunction, no body
;; (defun conjunctive-removal-tactic-actual-productivity (tactic) ...) -- active declareFunction, no body
;; (defun conjunctive-removal-tactic-child-count-via-split-link (tactic split-link) ...) -- active declareFunction, no body
;; (defun transformation-tactic-actual-productivity (tactic) ...) -- active declareFunction, no body
;; (defun rewrite-tactic-actual-productivity (tactic) ...) -- active declareFunction, no body
;; (defun meta-removal-tactic-actual-productivity (tactic) ...) -- active declareFunction, no body
;; (defun simple-problem-estimated-total-global-productivity (problem strategic-context) ...) -- active declareFunction, no body
;; (defun estimated-global-productivity-of-problem-possible-tactics (problem strategic-context) ...) -- active declareFunction, no body
;; (defun estimated-generalized-removal-productivity-of-problem-possible-tactics-with-completeness (problem strategic-context completeness) ...) -- active declareFunction, no body
;; (defun estimated-global-structural-productivity-of-problem-possible-tactics-with-preference-level (problem strategic-context preference-level) ...) -- active declareFunction, no body
;; (defun estimated-global-structural-productivity-of-problem-possible-preferred-tactics (problem strategic-context) ...) -- active declareFunction, no body
;; (defun estimated-global-structural-productivity-of-problem-possible-dispreferred-tactics (problem strategic-context) ...) -- active declareFunction, no body
;; (defun estimated-global-structural-productivity-of-problem-possible-grossly-dispreferred-tactics (problem strategic-context) ...) -- active declareFunction, no body
;; (defun estimated-global-structural-productivity-of-problem-possible-non-preferred-tactics (problem strategic-context preference-level) ...) -- active declareFunction, no body
;; (defun problem-doomed-due-to-lookahead-removal-completeness? (problem strategic-context) ...) -- active declareFunction, no body
;; (defun problem-doomed-due-to-removal-completeness? (problem strategic-context) ...) -- active declareFunction, no body
;; (defun problem-structural-preference-level (problem strategic-context) ...) -- active declareFunction, no body
;; (defun logical-link-generalized-removal-completeness (link strategic-context) ...) -- active declareFunction, no body

(defun logical-tactic-generalized-removal-completeness (logical-tactic strategic-context)
  (if (join-tactic-p logical-tactic)
      (multiple-value-bind (first-problem second-problem)
          (join-tactic-lookahead-problems logical-tactic)
        (let ((first-completeness (problem-generalized-removal-completeness first-problem strategic-context))
              (second-completeness (problem-generalized-removal-completeness second-problem strategic-context)))
          ;; Likely combines the two completeness values
          (missing-larkc 36504)))
      (problem-generalized-removal-completeness
       (logical-tactic-lookahead-problem logical-tactic)
       strategic-context)))

(defun problem-generalized-removal-completeness (problem strategic-context)
  "[Cyc] Returns the maximal completeness of PROBLEM's generalized removal tactics (wrt STRATEGIC-CONTEXT if provided), even the discarded ones."
  (declare (type strategic-context-p strategic-context))
  (determine-strategic-status-wrt problem strategic-context)
  (let ((max-completeness :impossible)
        (max-possible-completeness-found? nil))
    (do* ((rest (problem-tactics problem) (rest rest))
          (tactic (first rest) (first rest)))
         ((or max-possible-completeness-found? (null rest)))
      (when (do-problem-tactics-type-match tactic :generalized-removal)
        (unless (and (strategy-p strategic-context)
                     (simple-strategy-chooses-to-ignore-tactic? strategic-context tactic))
          (let ((tactic-completeness (tactic-strategic-completeness tactic strategic-context)))
            (when (completeness-> tactic-completeness max-completeness)
              (setf max-completeness tactic-completeness)
              (when (eq max-completeness :complete)
                (setf max-possible-completeness-found? t)))))))
    (when (and (not (eq :complete max-completeness))
               strategic-context
               (problem-has-executed-a-complete-removal-tactic? problem strategic-context))
      (setf max-completeness :complete))
    max-completeness))

;; (defun problem-preference-level-int (problem strategic-context type) ...) -- active declareFunction, no body
;; (defun discard-all-other-possible-connected-conjunction-tactics (tactic) ...) -- active declareFunction, no body

(defun discard-all-other-possible-structural-conjunctive-tactics (tactic)
  "[Cyc] Discards all conjunctive tactics on TACTIC's problem, other than TACTIC. This is used when the conjunctive tactic TACTIC is known to be complete and has been selected by the strategy, so we can discard all others because they will be subsumed by TACTIC."
  (unless (problem-store-transformation-allowed? (tactic-store tactic))
    (let ((problem (tactic-problem tactic)))
      (discard-possible-tactics-int problem nil nil :structural-conjunctive tactic nil)))
  nil)

;; (defun problem-link-can-have-proofs? (link) ...) -- active declareFunction, no body
;; (defun intermediate-proof-step-valid-memoized?-internal (problem step level) ...) -- active declareFunction, no body
;; (defun intermediate-proof-step-valid-memoized? (problem step level) ...) -- active declareFunction, no body
;; (defun intermediate-proof-step-valid? (problem step level) ...) -- active declareFunction, no body
;; (defun intermediate-proof-valid? (proof) ...) -- active declareFunction, no body
;; (defun intermediate-proof-valid-int? (proof level) ...) -- active declareFunction, no body
;; (defun intermediate-proof-asent-valid? (mt asent sense level) ...) -- active declareFunction, no body
;; (defun intermediate-proof-valid-due-to-structure? (proof) ...) -- active declareFunction, no body
;; (defun intermediate-proof-supports-valid? (proof level) ...) -- active declareFunction, no body
;; (defun intermediate-proof-content-link-valid? (link) ...) -- active declareFunction, no body

(defparameter *eager-proof-validation?* nil
  "[Cyc] Whether the Worker tests all newly proofs for well-formedness as soon as they are created. This could be turned back to t or investigated further if we find that we end up taking large cartesian products of ill-formed proofs.")

(defun propose-new-proof-with-bindings (link proof-bindings subproofs)
  "[Cyc] Return 0 nil or proof-p returns NIL iff the proposed proof was semantically invalid wrt the intermediate-step-validation-level. Return 1 boolean; t if the returned proof was newly created, nil if it already existed (or was not proven due to invalidity)"
  (let ((existing-proof (find-proof link proof-bindings subproofs)))
    (if existing-proof
        (values existing-proof nil)
        (let ((new-proof (new-proof-with-bindings link proof-bindings subproofs)))
          (proof-propagate-non-explananatory-subproofs new-proof)
          (let ((valid? (or (not *eager-proof-validation?*)
                            (missing-larkc 35238))))
            (if (not valid?)
                (missing-larkc 35345)
                (let ((circular? (proof-circular? new-proof)))
                  (if circular?
                      (missing-larkc 35344)
                      (let ((supported-problem (problem-link-supported-problem link)))
                        (cond ((tactically-no-good-problem-p supported-problem)
                               (missing-larkc 35346))
                              ((reject-proof-due-to-non-abducible-rule? link supported-problem subproofs)
                               (missing-larkc 35348))
                              ((and (modus-tollens-transformation-proof-p new-proof)
                                    (missing-larkc 1297))
                               (missing-larkc 35347))
                              (t (consider-that-problem-could-be-good supported-problem)
                                 (consider-that-subproofs-may-be-unprocessed new-proof)))))))
            (values new-proof valid?))))))

(defun proof-propagate-non-explananatory-subproofs (proof)
  (declare (type proof-p proof))
  (let ((store (proof-store proof))
        (total 0))
    (when (problem-store-non-explanatory-subproofs-possible? store)
      (when (proof-has-subproofs? proof)
        (dolist (subproof (proof-direct-subproofs proof))
          (dolist (non-explanatory-subproof (proof-non-explanatory-subproofs subproof))
            (incf total)
            (missing-larkc 35036)))
        (when (generalized-transformation-proof-p proof)
          (let ((non-explanatory-subproofs (missing-larkc 35194)))
            (dolist (non-explanatory-subproof non-explanatory-subproofs)
              (incf total)
              (missing-larkc 35037))))))
    total))

(deflexical *circular-proof-max-depth-cutoff* 300
  "[Cyc] The proof depth beyond which we give up trying to check for proof circularity.")

(defun proof-circular? (proof)
  "[Cyc] PROOF is circular when it contains a very similar proof to itself as one of its subproofs."
  (dolist (subproof (proof-direct-subproofs proof))
    (when (proof-circular-wrt? subproof proof 0)
      (return-from proof-circular? t)))
  nil)

(defun proof-circular-wrt? (proof candidate-circular-proof depth)
  (cond ((> depth *circular-proof-max-depth-cutoff*) nil)
        ((proofs-share-problem-and-bindings? proof candidate-circular-proof) t)
        (t (dolist (subproof (proof-direct-subproofs proof))
             (when (proof-circular-wrt? subproof candidate-circular-proof (1+ depth))
               (return-from proof-circular-wrt? t)))
           nil)))

(defun proofs-share-problem-and-bindings? (proof1 proof2)
  (and (eq (proof-supported-problem proof1) (proof-supported-problem proof2))
       (proof-bindings-equal? (proof-bindings proof1) (proof-bindings proof2))))

;; (defun proofs-share-problem-and-bindings-and-direct-supports? (proof1 proof2) ...) -- active declareFunction, no body
;; (defun reject-proof-due-to-circularity (proof) ...) -- active declareFunction, no body
;; (defun reject-proof-due-to-ill-formedness (proof) ...) -- active declareFunction, no body
;; (defun reject-proof-due-to-non-abducible-rule (proof) ...) -- active declareFunction, no body
;; (defun reject-proof-due-to-modus-tollens-with-non-wff (proof) ...) -- active declareFunction, no body
;; (defun reject-proof (proof reason) ...) -- active declareFunction, no body
;; (defun propagate-proof-rejected (proof) ...) -- active declareFunction, no body
;; (defun proof-note-proven-query-no-good-due-to-ill-formedness (proof) ...) -- active declareFunction, no body
;; (defun problem-force-no-goodness (problem) ...) -- active declareFunction, no body

(defun possibly-note-proof-processed (proof)
  (declare (type proof-p proof))
  (let ((store (proof-store proof)))
    (when (problem-store-allows-proof-processing? store)
      (missing-larkc 35256)))
  proof)

(defparameter *process-motivated-transformation-link-proofs?* t
  "[Cyc] if an RT-link's proof is processed, note its motivating T-link's proofs as processed too, they're kind of like siblings")

;; (defun possibly-note-proof-processed-int (proof) ...) -- active declareFunction, no body

(defun consider-that-subproofs-may-be-unprocessed (new-proof)
  (let ((store (proof-store new-proof)))
    (when (problem-store-allows-proof-processing? store)
      (dolist (subproof (proof-direct-subproofs new-proof))
        (when (missing-larkc 35413)
          (missing-larkc 35023)
          (consider-that-subproofs-may-be-unprocessed subproof)))))
  new-proof)

;; (defun all-dependent-proofs-are-processed? (proof) ...) -- active declareFunction, no body

(defparameter *find-proof-bindings-optimization-enabled?* t
  "[Cyc] Temporary control variable; should eventually stay T")

(defun find-proof (link proof-bindings subproofs)
  "[Cyc] Return nil or proof-p"
  (when *find-proof-bindings-optimization-enabled?*
    (let ((inference (current-controlling-inference)))
      (when (and (inference-problem-store-private? inference)
                 (inference-unique-wrt-bindings? inference))
        (when (or (not (generalized-transformation-link-p link))
                  (generalized-transformation-link-unaffected-by-exceptions? link))
          (let* ((supported-problem (problem-link-supported-problem link))
                 (candidate-proofs (problem-proofs-lookup supported-problem proof-bindings)))
            (dolist (candidate-proof candidate-proofs)
              (unless (proof-rejected? candidate-proof)
                (return-from find-proof candidate-proof))))))))
  (when (transformation-link-p link)
    (return-from find-proof nil))
  (let* ((supported-problem (problem-link-supported-problem link))
         (candidate-proofs (problem-proofs-lookup supported-problem proof-bindings)))
    (when candidate-proofs
      (let ((direct-supports (proof-spec-direct-supports link subproofs)))
        (dolist (proof candidate-proofs)
          (when (or (conjunctive-proof-subsumes-conjunctive-proof-spec? proof link proof-bindings subproofs)
                    (residual-transformation-proof-subsumes-conjunctive-proof-spec? proof link proof-bindings subproofs)
                    (proof-matches-specification? proof supported-problem proof-bindings direct-supports))
            (return-from find-proof proof))))))
  nil)

(defun conjunctive-proof-subsumes-conjunctive-proof-spec? (proof link proof-bindings subproofs)
  (or (connected-conjunction-proof-subsumes-connected-conjunction-proof-spec? proof link proof-bindings subproofs)
      (split-proof-subsumes-split-proof-spec? proof link proof-bindings subproofs)))

(defun connected-conjunction-proof-subsumes-connected-conjunction-proof-spec? (proof link proof-bindings subproofs)
  (and (connected-conjunction-proof-p proof)
       (connected-conjunction-link-p link)
       (sets-equal? (proof-direct-subproofs proof) subproofs #'eq)))

(defun split-proof-subsumes-split-proof-spec? (proof link proof-bindings subproofs)
  (and (split-proof-p proof)
       (split-link-p link)
       (sets-equal? (proof-direct-subproofs proof) subproofs #'eq)))

(defun residual-transformation-proof-subsumes-conjunctive-proof-spec? (proof link proof-bindings subproofs)
  (and (residual-transformation-proof-p proof)
       (conjunctive-link-p link)
       (missing-larkc 35349)))

;; (defun residual-transformation-proof-subsumes-conjunctive-proof-spec?-int (proof link proof-bindings subproofs) ...) -- active declareFunction, no body

(defun new-goal-proof (goal-link)
  "[Cyc] Return 0 proof-p. Return 1 whether the returned proof was newly created"
  (declare (type problem-link-to-goal-p goal-link))
  (if (removal-link-p goal-link)
      (new-removal-proof goal-link)
      (new-transformation-proof goal-link nil nil)))

;; (defun proof-proven-query (proof) ...) -- active declareFunction, no body
;; (defun proof-proven-sentence (proof) ...) -- active declareFunction, no body

(defun proof-bindings-from-constituents (local-bindings sub-bindings variable-map)
  "[Cyc] Returns bindings mapping local-vars -> old contents + new contents."
  (if (null sub-bindings)
      (progn
        (must (null variable-map)
              "expected a variable map to be null because the sub-bindings were null")
        local-bindings)
      (let* ((localized-sub-bindings (transfer-variable-map-to-bindings variable-map sub-bindings))
             (grounded-local-bindings (apply-bindings-to-values localized-sub-bindings local-bindings))
             (complete-local-bindings (nconc localized-sub-bindings grounded-local-bindings)))
        (setf complete-local-bindings (ncanonicalize-proof-bindings complete-local-bindings))
        complete-local-bindings)))

(defun ncanonicalize-proof-bindings-int (proof-bindings)
  (let ((sorted-bindings (sort proof-bindings #'variable-< :key #'variable-binding-variable)))
    (delete-duplicates-sorted sorted-bindings #'equal)))

(defun ncanonicalize-proof-bindings (proof-bindings)
  (if (singleton? proof-bindings)
      proof-bindings
      (ncanonicalize-proof-bindings-int proof-bindings)))

(defun canonicalize-proof-bindings (proof-bindings)
  "[Cyc] Result is not destructible"
  (if (proof-bindings-canonical? proof-bindings)
      proof-bindings
      (ncanonicalize-proof-bindings (copy-list proof-bindings))))

(defun proof-bindings-canonical? (proof-bindings)
  (proof-bindings-canonical?-recursive proof-bindings -1))

(defun proof-bindings-canonical?-recursive (proof-bindings last-id)
  (if (null proof-bindings)
      t
      (let ((next-id (variable-id (variable-binding-variable (first proof-bindings)))))
        (if (<= next-id last-id)
            nil
            (proof-bindings-canonical?-recursive (rest proof-bindings) next-id)))))

(defun proof-bindings-equal? (proof-bindings1 proof-bindings2)
  "[Cyc] These are assumed to be canonical"
  (equal proof-bindings1 proof-bindings2))

(defun unify-all-equal-bindings (v-bindings)
  "[Cyc] For each variable in BINDINGS which occurs twice, unify its first and second value and append them to the result, unless they are ((T . T))"
  (let ((new-bindings nil)
        (duplicate-bindings (duplicates v-bindings #'eq #'variable-binding-variable))
        (duplicate-variables (fast-delete-duplicates
                              (mapcar #'variable-binding-variable duplicate-bindings))))
    (dolist (variable duplicate-variables)
      (multiple-value-bind (first-value second-value)
          (missing-larkc 35356)
        (multiple-value-bind (value-unify-results value-unify-justification)
            (unify first-value second-value t)
          (unless (unification-success-token-p value-unify-results)
            (setf new-bindings (append value-unify-results new-bindings))))))
    new-bindings))

;; (defun two-values-in-bindings-with-same-variable (v-bindings variable) ...) -- active declareFunction, no body

(defun all-bindings-ground-out? (v-bindings)
  "[Cyc] Return boolean; t iff all values in BINDINGS are fully bound"
  (declare (type bindings-p v-bindings))
  (dolist (binding v-bindings t)
    (unless (binding-ground-out? binding)
      (return nil))))

(defun binding-ground-out? (binding)
  (let ((value (variable-binding-value binding)))
    (fully-bound-p value)))

(defparameter *proof-bubbling-depth* 0
  "[Cyc] used as a failsafe to avoid infinite proof bubbling")

(deflexical *max-proof-bubbling-depth* 50
  "[Cyc] the depth above which we forcibly halt recursive proof bubbling")

(defun bubble-up-proof (proof)
  (if (> *proof-bubbling-depth* *max-proof-bubbling-depth*)
      (missing-larkc 35339)
      (let ((*proof-bubbling-depth* (1+ *proof-bubbling-depth*)))
        (let ((supported-problem (proof-supported-problem proof)))
          (bubble-up-proof-from-problem proof supported-problem))))
  nil)

(defun bubble-up-proof-from-problem (proof problem)
  (do-set (dependent-link (problem-dependent-links problem))
    (bubble-up-proof-to-link proof dependent-link))
  nil)

(defun bubble-up-proof-to-link (proof dependent-link)
  (when (proof-proven? proof)
    (let ((pcase-var (problem-link-type dependent-link)))
      (if (eq pcase-var :answer)
          (let ((inference (problem-link-supported-inference dependent-link)))
            (propagate-proof-to-inference proof inference))
          (let ((problem (proof-supported-problem proof)))
            (do-problem-link-supporting-mapped-problems (supporting-mapped-problem dependent-link)
              (when (eq problem (mapped-problem-problem supporting-mapped-problem))
                (bubble-up-proof-to-link-via-mapped-problem proof dependent-link supporting-mapped-problem)))))))
  nil)

(defun bubble-up-proof-to-link-via-mapped-problem (proof dependent-link mapped-problem)
  (when (link-permits-proof-propagation? dependent-link mapped-problem)
    (let ((variable-map (mapped-problem-variable-map mapped-problem)))
      (bubble-up-proof-to-link-via-variable-map proof variable-map dependent-link)))
  nil)

(defun bubble-up-proof-to-link-via-variable-map (proof variable-map dependent-link)
  "[Cyc] Just having PROOF and DEPENDENT-LINK is not enough, because if DEPENDENT-LINK has two or more supporting problems which are both equal to the supported problem of PROOF, then we couldn't distinguish them without VARIABLE-MAP."
  (declare (type proof-p proof))
  (declare (type variable-map-p variable-map))
  (let ((pcase-var (problem-link-type dependent-link)))
    (cond ((eq pcase-var :transformation)
           (bubble-up-proof-to-transformation-link proof variable-map dependent-link))
          ((eq pcase-var :rewrite) (missing-larkc 32954))
          ((eq pcase-var :join-ordered)
           (bubble-up-proof-to-join-ordered-link proof variable-map dependent-link))
          ((eq pcase-var :join)
           (bubble-up-proof-to-join-link proof variable-map dependent-link))
          ((eq pcase-var :split)
           (bubble-up-proof-to-split-link proof variable-map dependent-link))
          ((eq pcase-var :restriction)
           (bubble-up-proof-to-restriction-link proof variable-map dependent-link))
          ((eq pcase-var :residual-transformation) (missing-larkc 35048))
          ((eq pcase-var :union) (missing-larkc 33004))
          ((eq pcase-var :disjunctive-assumption)
           (error "can't handle bubbling up proofs past disjunctive assumption links yet"))
          ((eq pcase-var :answer)
           (let ((inference (problem-link-supported-inference dependent-link)))
             (propagate-proof-to-inference proof inference)))))
  nil)

(defun perform-lazy-proof-rejection (proof inference)
  (when (inference-allow-abnormality-checking? inference)
    (reject-abnormal-subproofs proof))
  nil)

;; (defun proof-consistent-with-mt-assumptions? (proof) ...) -- active declareFunction, no body

(defparameter *within-abnormality-checking?* nil)

;; (defun within-abnormality-checking? () ...) -- active declareFunction, no body

(defun reject-abnormal-subproofs (proof)
  (when (null (proof-proven? proof))
    (return-from reject-abnormal-subproofs nil))
  (let ((*within-abnormality-checking?* t))
    (dolist (subproof (proof-direct-subproofs proof))
      (reject-abnormal-subproofs subproof))
    (when (or (and (transformation-proof-p proof)
                   (transformation-proof-abnormal? proof))
              (and (residual-transformation-proof-p proof)
                   (missing-larkc 35098)))
      (missing-larkc 35343))
    (when (and (abnormality-except-support-enabled?)
               (proof-depends-on-excepted-assertion? proof))
      (missing-larkc 35340)))
  nil)

;; (defun reject-proof-due-to-abnormality (proof) ...) -- active declareFunction, no body

(defun inference-proof-non-explanatory-subproofs (inference proof)
  (let ((answer-link (inference-root-link inference)))
    (if (answer-link-supporting-problem-wholly-explanatory? answer-link)
        (proof-non-explanatory-subproofs proof)
        (missing-larkc 35190))))

;; (defun cached-inference-proof-non-explanatory-subproofs-internal (inference proof) ...) -- active declareFunction, no body
;; (defun cached-inference-proof-non-explanatory-subproofs (inference proof) ...) -- active declareFunction, no body

(defun proof-non-explanatory-subproofs (proof)
  (let ((subproofs nil))
    (when (proof-has-subproofs? proof)
      (let ((store (proof-store proof)))
        (when (problem-store-non-explanatory-subproofs-possible? store)
          (setf subproofs (missing-larkc 35028)))))
    subproofs))

;; (defun compute-generalized-transformation-proof-non-explanatory-subproofs (proof) ...) -- active declareFunction, no body
;; (defun inference-proof-proven-non-explanatory-subquery (inference proof) ...) -- active declareFunction, no body
;; (defun generalized-transformation-proof-proven-non-explanatory-subquery (proof) ...) -- active declareFunction, no body
;; (defun transformation-proof-proven-non-explanatory-subquery (proof) ...) -- active declareFunction, no body
;; (defun residual-transformation-proof-proven-non-explanatory-subquery (proof) ...) -- active declareFunction, no body
;; (defun compute-non-explanatory-subproofs (proof query) ...) -- active declareFunction, no body
;; (defun non-explanatory-subproofs-recursive (proof query subproofs) ...) -- active declareFunction, no body
;; (defun non-explanatory-proof? (proof query) ...) -- active declareFunction, no body
;; (defun non-explanatory-asent? (asent sense query) ...) -- active declareFunction, no body
;; (defun explanatory-asent? (asent sense query) ...) -- active declareFunction, no body

(defun note-tactic-finished (tactic)
  (let ((problem (tactic-problem tactic)))
    (note-tactic-executed tactic)
    (set-problem-tactics-recompute-thrown-away-wrt-all-relevant-strategies-and-all-motivations
     (tactic-problem tactic))
    (when (problem-no-tactics-possible? problem)
      (unless (tactically-no-good-problem-p problem)
        (note-problem-pending problem :tactical))
      (consider-that-problem-could-be-finished problem nil :tactical t)
      (when (problem-has-executed-a-complete-tactic? problem :tactical)
        (consider-that-problem-could-be-no-good problem nil :tactical t)))
    (do-problem-relevant-strategies (strategy problem)
      (strategy-note-tactic-finished strategy tactic)))
  tactic)

(defun consider-strategic-ramifications-of-possibly-executed-tactic (strategy tactic)
  (when (tactic-executed? tactic)
    (consider-strategic-ramifications-of-executed-tactic strategy tactic)
    (return-from consider-strategic-ramifications-of-possibly-executed-tactic t))
  nil)

(defun consider-strategic-ramifications-of-executed-tactic (strategy tactic)
  (let ((problem (tactic-problem tactic)))
    (when (strategy-no-possible-strategems-for-problem? strategy problem)
      (possibly-note-problem-pending problem strategy)
      (consider-that-problem-could-be-finished problem nil strategy t)
      (when (problem-has-executed-a-complete-tactic? problem strategy)
        (consider-that-problem-could-be-no-good problem nil strategy t))))
  tactic)

(defun note-problem-created (problem)
  "[Cyc] Changes PROBLEM's status to :unexamined."
  (change-and-propagate-problem-status problem :unexamined nil :tactical)
  problem)

;; (defun possibly-reactivate-problem (strategy problem) ...) -- active declareFunction, no body

(defun possibly-activate-problem (strategy problem)
  (let ((really-relevant? (strategy-possibly-activate-problem strategy problem)))
    (when really-relevant?
      (strategy-note-problem-active strategy problem)
      (let ((inference (strategy-inference strategy)))
        (add-inference-relevant-problem inference problem)
        (do-set (argument-link (problem-argument-links problem))
          (propagate-min-proof-depth-via-link-wrt-inference argument-link inference)
          (propagate-min-transformation-depth-via-link-wrt-inference argument-link inference)
          (propagate-min-transformation-depth-signature-via-link-wrt-inference argument-link inference)
          (propagate-proof-spec argument-link))))
    really-relevant?))

(defun determine-strategic-status-wrt (problem strategic-context)
  "[Cyc] Push PROBLEM as far as it can go wrt STRATEGIC-CONTEXT through the progression of strategic statuses."
  (unless (tactically-no-good-problem-p problem)
    (when (tactically-unexamined-problem-p problem)
      (determine-new-tactics problem))
    (when (strategy-p strategic-context)
      (possibly-compute-strategic-properties-of-problem-tactics problem strategic-context)
      (possibly-note-problem-strategically-examined problem strategic-context)
      (possibly-note-problem-strategically-possible problem strategic-context)
      (consider-that-problem-could-be-strategically-pending-wrt problem strategic-context)
      (return-from determine-strategic-status-wrt
        (problem-strategic-status problem strategic-context))))
  problem)

(defun note-problem-examined (problem)
  (let* ((old-status (problem-status problem))
         (new-status (examined-version-of-problem-status old-status)))
    (change-and-propagate-problem-status problem new-status nil :tactical)
    (do-problem-relevant-strategies (strategy problem)
      (possibly-note-problem-strategically-examined problem strategy)))
  (if (problem-no-tactics-possible? problem)
      nil
      (note-problem-possible problem))
  problem)

(defun possibly-note-problem-strategically-examined (problem strategy)
  (when (and (not (tactically-unexamined-problem-p problem))
             (strategically-unexamined-problem-p problem strategy))
    (let* ((old-strategic-status (problem-raw-strategic-status problem strategy))
           (new-strategic-status (examined-version-of-problem-status old-strategic-status)))
      (change-and-propagate-problem-status problem new-strategic-status nil strategy)))
  problem)

(defun note-problem-possible (problem)
  (let* ((old-status (problem-status problem))
         (new-status (possible-version-of-problem-status old-status)))
    (change-and-propagate-problem-status problem new-status nil :tactical)
    (do-problem-relevant-strategies (strategy problem)
      (possibly-note-problem-strategically-possible problem strategy)))
  problem)

(defun possibly-note-problem-strategically-possible (problem strategy)
  (when (and (strategically-examined-problem-p problem strategy)
             (not (strategically-no-good-problem-p problem strategy))
             (not (strategy-no-possible-strategems-for-problem? strategy problem)))
    (note-problem-strategically-possible problem strategy))
  problem)

;; (defun note-problem-strategically-unexamined (problem strategy) ...) -- active declareFunction, no body

(defun note-problem-strategically-possible (problem strategy)
  (let* ((old-strategic-status (problem-raw-strategic-status problem strategy))
         (new-strategic-status (possible-version-of-problem-status old-strategic-status)))
    (change-and-propagate-problem-status problem new-strategic-status nil strategy))
  problem)

(defun possibly-note-problem-pending (problem strategic-context)
  "[Cyc] Notes that PROBLEM is pending (wrt STRATEGIC-CONTEXT) unless it is already known to be pending (wrt STRATEGIC-CONTEXT)."
  (declare (type strategic-context-p strategic-context))
  (when (possible-problem-p problem strategic-context)
    (note-problem-pending problem strategic-context)))

(defun note-problem-pending (problem strategic-context)
  "[Cyc] Assumes that strategy activity is propagated first, since it uses that as a criterion for considering no-goodness."
  (unless (strategy-p strategic-context)
    (must (problem-no-tactics-possible? problem)
          "Tried to make ~a pending but it still had possible tactics" problem))
  (let* ((old-status (problem-raw-tactical-or-strategic-status problem strategic-context))
         (new-status (pending-version-of-problem-status old-status)))
    (change-and-propagate-problem-status problem new-status nil strategic-context)
    (consider-that-problem-could-be-no-good problem nil strategic-context t)
    (if (strategy-p strategic-context)
        (inference-note-problem-pending (strategy-inference strategic-context) problem)
        (do-problem-relevant-strategies (strategy problem)
          (possibly-note-problem-pending problem strategy)))
    new-status))

(defun possibly-note-problem-finished (problem strategic-context)
  "[Cyc] Notes that PROBLEM is finished (wrt STRATEGIC-CONTEXT) unless it is already known to be finished (wrt STRATEGIC-CONTEXT)."
  (declare (type strategic-context-p strategic-context))
  (when (pending-problem-p problem strategic-context)
    (note-problem-finished problem strategic-context)))

(defun note-problem-finished (problem strategic-context)
  "[Cyc] Assumes that strategy activity is propagated first, since it uses that as a criterion for considering no-goodness."
  (let* ((old-status (problem-raw-tactical-or-strategic-status problem strategic-context))
         (new-status (finished-version-of-problem-status old-status)))
    (change-and-propagate-problem-status problem new-status nil strategic-context)
    (consider-ramifications-of-problem-finished problem strategic-context)
    new-status))

(defun consider-ramifications-of-problem-finished (problem strategic-context)
  (consider-that-problem-could-be-no-good problem nil strategic-context t)
  (possibly-propagate-problem-finished problem strategic-context)
  (if (strategy-p strategic-context)
      (strategy-note-problem-finished strategic-context problem)
      ;; When tactical: check restriction/join-ordered link interactions
      (progn
        (do-set (restriction-link (problem-dependent-links problem))
          (when (problem-link-has-type? restriction-link :restriction)
            (let ((supported-problem (problem-link-supported-problem restriction-link)))
              (do-set (jo-link (problem-dependent-links supported-problem))
                (when (problem-link-has-type? jo-link :join-ordered)
                  (note-restricted-non-focal-finished jo-link restriction-link))))))
        (do-problem-relevant-strategies (strategy problem)
          (if (finished-problem-p problem strategy)
              (consider-ramifications-of-problem-finished problem strategy)
              (possibly-note-problem-finished problem strategy)))))
  nil)

(defun possibly-propagate-problem-finished (problem strategic-context)
  (do-problem-link-open-supporting-mapped-problems (supporting-mapped-problem dependent-link problem)
    (let ((supported-problem (problem-link-supported-problem dependent-link)))
      (when supported-problem
        (when (or (not (strategy-p strategic-context))
                  (problem-relevant-to-strategy? supported-problem strategic-context))
          (consider-that-problem-could-be-finished supported-problem nil strategic-context t)
          (when (restriction-link-p dependent-link)
            (do-set (jo-link (problem-dependent-links supported-problem))
              (when (and (problem-link-has-type? jo-link :join-ordered)
                         (problem-link-open? jo-link))
                (let ((conjunction-problem (problem-link-supported-problem jo-link)))
                  (consider-that-problem-could-be-finished conjunction-problem nil strategic-context t)))))))))
  nil)

(defun strategy-note-problem-finished (strategic-context problem)
  nil)

(defun note-argument-link-added (link)
  (let ((supported-problem (problem-link-supported-problem link)))
    (do-problem-relevant-strategies (strategy supported-problem)
      (strategy-note-argument-link-added strategy link)))
  link)

(defun note-goal-link-added (link)
  (multiple-value-bind (goal-proof new?)
      (new-goal-proof link)
    (when new?
      (bubble-up-proof goal-proof)))
  link)

;; (defun strategic-context-p (object) ...) -- active declareFunction, no body
;; (defun strategic-context-suid (object) ...) -- active declareFunction, no body
;; (defun find-strategic-context-by-id (store id) ...) -- active declareFunction, no body
;; (defun find-strategic-context-by-ids (store ids) ...) -- active declareFunction, no body

(defun no-good-problem-p (problem strategic-context)
  (if (strategy-p strategic-context)
      (strategically-no-good-problem-p problem strategic-context)
      (tactically-no-good-problem-p problem)))

(defun neutral-problem-p (problem strategic-context)
  (if (strategy-p strategic-context)
      (strategically-neutral-problem-p problem strategic-context)
      (missing-larkc 35397)))

(defun good-problem-p (problem strategic-context)
  (if (strategy-p strategic-context)
      (strategically-good-problem-p problem strategic-context)
      (tactically-good-problem-p problem)))

;; (defun examined-problem-p (problem strategic-context) ...) -- active declareFunction, no body

(defun possible-problem-p (problem strategic-context)
  (if (strategy-p strategic-context)
      (strategically-possible-problem-p problem strategic-context)
      (tactically-possible-problem-p problem)))

(defun pending-problem-p (problem strategic-context)
  (if (strategy-p strategic-context)
      (strategically-pending-problem-p problem strategic-context)
      (tactically-pending-problem-p problem)))

(defun finished-problem-p (problem strategic-context)
  (if (strategy-p strategic-context)
      (strategically-finished-problem-p problem strategic-context)
      (tactically-finished-problem-p problem)))

;; (defun potentially-possible-problem-p (problem strategic-context) ...) -- active declareFunction, no body
;; (defun not-potentially-possible-problem-p (problem strategic-context) ...) -- active declareFunction, no body

(defun totally-finished-problem-p (problem strategic-context)
  (finished-problem-p problem (controlling-strategic-context strategic-context)))

(defparameter *disable-link-propagation?* nil
  "[Cyc] When non-NIL link propagation is disabled. This is only useful when serializing in problem stores.")

(defun propagate-problem-link (link)
  "[Cyc] Does all propagation necessary to handle the addition of the newly created link LINK."
  (unless *disable-link-propagation?*
    (propagate-min-proof-depth-via-link link)
    (propagate-min-transformation-depth-via-link link)
    (propagate-min-transformation-depth-signature-via-link link)
    (propagate-strategy-activity link)
    (propagate-inference-relevance link)
    (note-argument-link-added link)
    (propagate-proofs link)
    (propagate-proof-spec link)
    (return-from propagate-problem-link link))
  nil)

(defun propagate-proofs (link)
  (if (problem-link-to-goal-p link)
      (note-goal-link-added link)
      (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
        (when (link-permits-proof-propagation? link supporting-mapped-problem)
          (do-problem-proofs (proof (mapped-problem-problem supporting-mapped-problem) :proof-status :proven)
            (bubble-up-proof-to-link-via-variable-map
             proof
             (mapped-problem-variable-map supporting-mapped-problem)
             link)))))
  link)

(defun repropagate-newly-opened-link (link mapped-supporting-problem)
  (propagate-strategy-activity link)
  (propagate-inference-relevance link)
  (propagate-proofs link)
  (propagate-proof-spec link)
  link)

;; (defun problem-link-open-and-repropagate-sole-supporting-mapped-problem (link) ...) -- active declareFunction, no body

(defun problem-link-open-and-repropagate-index (link index)
  (problem-link-open-index link index)
  (let ((supporting-mapped-problem (problem-link-find-supporting-mapped-problem-by-index link index)))
    (repropagate-newly-opened-link link supporting-mapped-problem))
  link)

(defun problem-link-open-and-repropagate-supporting-mapped-problem (link supporting-mapped-problem)
  (problem-link-open-supporting-mapped-problem link supporting-mapped-problem)
  (repropagate-newly-opened-link link supporting-mapped-problem)
  link)

;; (defun problem-link-open-and-repropagate-all (link) ...) -- active declareFunction, no body

(defun propagate-answer-link (link)
  "[Cyc] Does all propagation necessary to handle the addition of the newly created answer link LINK."
  (let ((inference (problem-link-supported-inference link)))
    (propagate-proof-spec-via-answer-link link)
    (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
      (let ((supporting-problem (mapped-problem-problem supporting-mapped-problem))
            (variable-map (mapped-problem-variable-map supporting-mapped-problem)))
        (set-problem-min-proof-depth supporting-problem inference 0)
        (unless *problem-min-transformation-depth-from-signature-enabled?*
          ;; Likely sets the min transformation depth
          (missing-larkc 35391))
        (set-root-problem-min-transformation-depth-signature supporting-problem inference)
        (do-problem-proofs (proof supporting-problem :proof-status :proven)
          (propagate-proof-to-inference proof inference))
        (dolist (strategy (inference-initial-relevant-strategies inference))
          (maybe-possibly-activate-problem strategy supporting-problem))
        (possibly-note-problem-relevant inference supporting-problem))))
  (note-answer-link-propagated link)
  link)

(defun possibly-propagate-answer-link (link)
  "[Cyc] Return booleanp; whether you just propagated LINK"
  (unless (answer-link-propagated? link)
    (propagate-answer-link link)
    (return-from possibly-propagate-answer-link t))
  nil)

(defun propagate-proof-to-inference (proof inference)
  (when (or *eager-proof-validation?*
            (proof-tree-valid? proof))
    (inference-note-proof inference proof)
    (consider-closing-answer-link (inference-root-link inference))
    (return-from propagate-proof-to-inference t))
  nil)

(defun consider-closing-answer-link (answer-link)
  "[Cyc] Return booleanp; whether ANSWER-LINK became closed due to this call."
  (let* ((inference (answer-link-supported-inference answer-link))
         (should-close? (inference-deems-answer-link-should-be-closed? inference answer-link)))
    (when should-close?
      (close-answer-link answer-link)
      (return-from consider-closing-answer-link t))
    nil))

(defun inference-deems-answer-link-should-be-closed? (inference answer-link)
  "[Cyc] Return booleanp; whether INFERENCE deems that ANSWER-LINK ought to be closed."
  (let* ((root-mapped-problem (problem-link-sole-supporting-mapped-problem answer-link))
         (root-problem (mapped-problem-problem root-mapped-problem)))
    (do-inference-strategies (strategy inference)
      (unless (strategy-has-enough-proofs-for-problem? strategy root-problem)
        (return-from inference-deems-answer-link-should-be-closed? nil)))
    t))

(defun close-answer-link (answer-link)
  (problem-link-close-sole-supporting-mapped-problem answer-link)
  (clear-inference-relevant-problems (answer-link-supported-inference answer-link))
  answer-link)

(defun proof-tree-valid? (proof)
  "[Cyc] Return boolean; t iff PROOF and all its subproofs are well-formed."
  (if (eq :none (problem-store-intermediate-step-validation-level (proof-store proof)))
      t
      (missing-larkc 35333)))

;; (defun recursive-proof-tree-valid? (proof) ...) -- active declareFunction, no body

(defun depth-< (depth1 depth2)
  "[Cyc] Return boolean; t iff DEPTH1 is less than DEPTH2. Any integer is deemed less than :undetermined."
  (if (non-negative-integer-p depth1)
      (if (non-negative-integer-p depth2)
          (< depth1 depth2)
          t)
      nil))

;; (defun depth-<= (depth1 depth2) ...) -- active declareFunction, no body

(defun propagate-min-proof-depth-via-link (link)
  "[Cyc] Propagates proof depth down via LINK."
  (do-id-index (id inference (problem-store-inference-id-index (problem-link-store link)))
    (propagate-min-proof-depth-via-link-wrt-inference link inference))
  nil)

(defun propagate-min-proof-depth-via-link-wrt-inference (link inference)
  "[Cyc] Propagates proof depth wrt INFERENCE down via LINK."
  (let* ((supported-problem (problem-link-supported-problem link))
         (parent-depth (problem-min-proof-depth supported-problem inference)))
    (when (non-negative-integer-p parent-depth)
      (let* ((supporting-problem-count (problem-link-number-of-supporting-problems link))
             (supporting-problem-count (if (and (= 1 supporting-problem-count)
                                                (join-ordered-link-p link))
                                           2
                                           supporting-problem-count)))
        (when (plusp supporting-problem-count)
          (let* ((content-increment (if (content-link-p link) 1 0))
                 (sibling-increment (1- supporting-problem-count))
                 (increment (+ content-increment sibling-increment))
                 (propagated-child-depth (+ parent-depth increment)))
            (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
              (let* ((supporting-problem (mapped-problem-problem supporting-mapped-problem))
                     (child-depth (problem-min-proof-depth supporting-problem inference)))
                (when (proof-depth-< propagated-child-depth child-depth)
                  (set-problem-min-proof-depth supporting-problem inference propagated-child-depth)
                  (do-problem-relevant-strategies (strategy supporting-problem)
                    (set-problem-recompute-thrown-away-wrt-all-motivations supporting-problem strategy)
                    (set-problem-recompute-set-aside-wrt-all-motivations supporting-problem strategy))
                  (do-set (argument-link (problem-argument-links supporting-problem))
                    (propagate-min-proof-depth-via-link-wrt-inference argument-link inference))))))))))
  nil)

(defun proof-depth-< (depth1 depth2)
  (depth-< depth1 depth2))

(defun problem-strictly-within-max-proof-depth? (inference problem)
  "[Cyc] Return T iff PROBLEM is strictly within (not at) the stated max proof depth of INFERENCE."
  (let ((max-proof-depth (inference-max-proof-depth inference)))
    (when max-proof-depth
      (let ((proof-depth (problem-min-proof-depth problem inference)))
        (when (and (numberp proof-depth)
                   (not (proof-depth-< proof-depth max-proof-depth)))
          (return-from problem-strictly-within-max-proof-depth? nil)))))
  t)

(defun propagate-min-transformation-depth-via-link (link)
  "[Cyc] Propagates transformation depth down via LINK."
  (when *problem-min-transformation-depth-from-signature-enabled?*
    (return-from propagate-min-transformation-depth-via-link nil))
  (do-id-index (id inference (problem-store-inference-id-index (problem-link-store link)))
    (propagate-min-transformation-depth-via-link-wrt-inference link inference))
  nil)

(defun propagate-min-transformation-depth-via-link-wrt-inference (link inference)
  "[Cyc] Propagates transformation depth wrt INFERENCE down via LINK."
  (when *problem-min-transformation-depth-from-signature-enabled?*
    (return-from propagate-min-transformation-depth-via-link-wrt-inference nil))
  (let* ((supported-problem (problem-link-supported-problem link))
         (parent-depth (problem-min-transformation-depth supported-problem inference)))
    (when (non-negative-integer-p parent-depth)
      (when (problem-link-with-supporting-problem-p link)
        (let ((increment (missing-larkc 35355)))
          (when (non-negative-integer-p increment)
            (let ((propagated-child-depth (+ parent-depth increment)))
              (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
                (let* ((supporting-problem (mapped-problem-problem supporting-mapped-problem))
                       (child-depth (problem-min-transformation-depth supporting-problem inference)))
                  (when (transformation-depth-< propagated-child-depth child-depth)
                    (missing-larkc 35392)
                    (do-set (argument-link (problem-argument-links supporting-problem))
                      (propagate-min-transformation-depth-via-link-wrt-inference argument-link inference))
                    ;; Handle transformation link interactions with join-ordered and RT links
                    (when (transformation-link-p link)
                      (let ((t-supported-problem (problem-link-supported-problem link)))
                        (do-set (jo-link-var (problem-dependent-links t-supported-problem))
                          (when (problem-link-has-type? jo-link-var :join-ordered)
                            (let ((motivating-conjunction-problem (problem-link-supported-problem jo-link-var)))
                              (do-set (rt-link (problem-argument-links motivating-conjunction-problem))
                                (when (problem-link-has-type? rt-link :residual-transformation)
                                  (when (missing-larkc 35062)
                                    (when (missing-larkc 35066)
                                      (propagate-min-transformation-depth-via-link-wrt-inference rt-link inference)))))))))))))))))))
  nil)

;; (defun clear-uninterestingness-cache-wrt-transformation (problem inference) ...) -- active declareFunction, no body

(defun transformation-depth-< (depth1 depth2)
  (depth-< depth1 depth2))

;; (defun transformation-depth-<= (depth1 depth2) ...) -- active declareFunction, no body

(defun problem-strictly-within-max-transformation-depth? (inference problem)
  "[Cyc] Return T iff PROBLEM is strictly within (not at) the stated max transformation depth of INFERENCE."
  (let ((max-transformation-depth (inference-max-transformation-depth inference)))
    (when max-transformation-depth
      (let ((transformation-depth (problem-min-transformation-depth problem inference)))
        (when (and (numberp transformation-depth)
                   (not (transformation-depth-< transformation-depth max-transformation-depth)))
          (return-from problem-strictly-within-max-transformation-depth? nil)))))
  t)

(defun problem-transformation-allowed-wrt-max-transformation-depth? (inference problem)
  "[Cyc] Return T iff transformation on PROBLEM is allowed based on the max transformation depth of INFERENCE."
  (problem-strictly-within-max-transformation-depth? inference problem))

(defun logical-tactic-transformation-allowed-wrt-max-transformation-depth? (inference logical-tactic)
  "[Cyc] Return T iff transformation motivation on LOGICAL-TACTIC is allowed based on the max transformation depth of INFERENCE."
  (let ((problem (tactic-problem logical-tactic)))
    (unless (problem-transformation-allowed-wrt-max-transformation-depth? inference problem)
      (return-from logical-tactic-transformation-allowed-wrt-max-transformation-depth? nil))
    (when (join-tactic-p logical-tactic)
      (return-from logical-tactic-transformation-allowed-wrt-max-transformation-depth? nil))
    (let ((max-transformation-depth (inference-max-transformation-depth inference)))
      (cond ((null max-transformation-depth) t)
            ((zerop max-transformation-depth) nil)
            (t (let ((transformation-depth (missing-larkc 35417)))
                 (if (not (numberp transformation-depth))
                     t
                     (transformation-depth-< transformation-depth max-transformation-depth))))))))

;; (defun transformation-depth-increment (link inference) ...) -- active declareFunction, no body

(defun problem-has-been-transformed? (problem inference)
  (let ((result nil))
    (let ((*transformation-depth-computation* :intuitive))
      (setf result (positive-integer-p (problem-min-transformation-depth problem inference))))
    result))

(defun propagate-strategy-activity (link)
  (let ((supported-problem (problem-link-supported-problem link)))
    (do-problem-relevant-strategies (strategy supported-problem)
      (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
        (when (link-permits-activity-propagation? link supporting-mapped-problem)
          (let ((supporting-problem (mapped-problem-problem supporting-mapped-problem)))
            (maybe-possibly-activate-problem strategy supporting-problem))))))
  nil)

(defun maybe-possibly-activate-problem (strategy problem)
  "[Cyc] Unless PROBLEM is already active in STRATEGY, notifies STRATEGY that PROBLEM might be newly active in it."
  (unless (problem-active-in-strategy? problem strategy)
    (when (possibly-activate-problem strategy problem)
      (do-set (argument-link (problem-argument-links problem))
        (propagate-strategy-activity argument-link))
      (return-from maybe-possibly-activate-problem t)))
  nil)

(defun link-permits-activity-propagation? (link supporting-mapped-problem)
  (problem-link-supporting-mapped-problem-open? link supporting-mapped-problem))

(defun propagate-inference-relevance (link)
  (let ((supported-problem (problem-link-supported-problem link)))
    (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
      (when (link-permits-relevance-propagation? link supporting-mapped-problem)
        (let ((supporting-problem (mapped-problem-problem supporting-mapped-problem)))
          (propagate-relevance-to-supporting-problem supported-problem supporting-problem)))))
  nil)

(defun propagate-relevance-to-supporting-problem (problem supporting-problem)
  "[Cyc] Propagates inferential relevance from PROBLEM to SUPPORTING-PROBLEM"
  (do-problem-relevant-inferences (inference problem)
    (possibly-note-problem-relevant inference supporting-problem))
  problem)

(defun possibly-note-problem-relevant (inference problem)
  (unless (problem-relevant-to-inference? problem inference)
    (add-inference-relevant-problem inference problem)
    (do-set (argument-link (problem-argument-links problem))
      (when (rewrite-link-p argument-link)
        (set-problem-tactics-recompute-thrown-away-wrt-all-relevant-strategies-and-all-motivations
         (problem-link-sole-supporting-problem argument-link)))
      (propagate-inference-relevance argument-link))
    (return-from possibly-note-problem-relevant t))
  nil)

(defun link-permits-relevance-propagation? (link supporting-mapped-problem)
  t)

(defparameter *bubble-up-proofs-through-closed-split-links?* t)

(defun link-permits-proof-propagation? (link supporting-mapped-problem)
  (or (problem-link-supporting-mapped-problem-open? link supporting-mapped-problem)
      (and (join-ordered-link-p link)
           (join-ordered-link-has-non-focal-mapped-problem? link)
           (mapped-problem-equal supporting-mapped-problem
                                 (join-ordered-link-non-focal-mapped-problem link)))
      (and *bubble-up-proofs-through-closed-split-links?*
           (split-link-p link))))

(defun consider-that-mapped-problem-could-be-irrelevant (mapped-problem dependent-link)
  (when (link-permits-relevance-propagation? dependent-link mapped-problem)
    (let ((problem (mapped-problem-problem mapped-problem)))
      (do-problem-relevant-inferences (inference problem)
        (consider-that-problem-could-be-irrelevant-to-inference problem inference))))
  nil)

(defun consider-that-problem-could-be-irrelevant-to-inference (problem inference)
  (when (problem-irrelevant-to-inference? problem inference)
    (maybe-make-problem-irrelevant-to-inference inference problem)
    (return-from consider-that-problem-could-be-irrelevant-to-inference t))
  nil)

(defun problem-irrelevant-to-inference? (problem inference)
  "[Cyc] Return boolean; whether PROBLEM is deemed irrelevant to INFERENCE."
  (when (problem-link-closed? (inference-root-link inference))
    (return-from problem-irrelevant-to-inference? t))
  (do-problem-link-open-supporting-mapped-problems (supporting-mapped-problem dependent-link problem)
    (when (link-permits-relevance-propagation? dependent-link supporting-mapped-problem)
      (if (answer-link-p dependent-link)
          (when (eq inference (problem-link-supported-inference dependent-link))
            (return-from problem-irrelevant-to-inference? nil))
          (let ((supported-problem (problem-link-supported-problem dependent-link)))
            (when (problem-relevant-to-inference? supported-problem inference)
              (return-from problem-irrelevant-to-inference? nil))))))
  t)

(defun maybe-make-problem-irrelevant-to-inference (inference problem)
  "[Cyc] Unless PROBLEM is already irrelevant to INFERENCE, notes that PROBLEM is now irrelevant to INFERENCE. Then propagates the irrelevance."
  (when (problem-relevant-to-inference? problem inference)
    (make-problem-irrelevant-to-inference inference problem)
    (do-set (argument-link (problem-argument-links problem))
      (propagate-inference-irrelevance inference argument-link))
    (return-from maybe-make-problem-irrelevant-to-inference t))
  nil)

(defun make-problem-irrelevant-to-inference (inference problem)
  (remove-inference-relevant-problem inference problem)
  (do-inference-strategies (strategy inference)
    (when (problem-set-aside-in-strategy? problem strategy)
      (missing-larkc 36468)))
  nil)

(defun propagate-inference-irrelevance (inference link)
  (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
    (when (link-permits-relevance-propagation? link supporting-mapped-problem)
      (consider-that-problem-could-be-irrelevant-to-inference
       (mapped-problem-problem supporting-mapped-problem)
       inference)))
  nil)

(defun problem-raw-tactical-or-strategic-status (problem strategic-context)
  "[Cyc] If STRATEGIC-CONTEXT is :tactical, returns PROBLEM's status. If STRATEGIC-CONTEXT is STRATEGY, returns PROBLEM's strategic status wrt STRATEGY."
  (declare (type strategic-context-p strategic-context))
  (if (strategy-p strategic-context)
      (problem-raw-strategic-status problem strategic-context)
      (problem-status problem)))

(defun set-problem-raw-tactical-or-strategic-status (problem strategic-context status)
  "[Cyc] If STRATEGIC-CONTEXT is :tactical, sets PROBLEM's status to STATUS. If STRATEGIC-CONTEXT is STRATEGY, sets PROBLEM's raw strategic status wrt STRATEGY to STATUS."
  (declare (type strategic-context-p strategic-context))
  (if (strategy-p strategic-context)
      (set-problem-raw-strategic-status problem strategic-context status)
      (set-problem-status problem status))
  problem)

(defparameter *reconsidering-set-asides?* nil
  "[Cyc] Whether we are currently reconsidering set-asides for some strategy.")

(defun change-and-propagate-problem-status (problem new-status consider-deep? strategic-context)
  (let ((old-status (problem-raw-tactical-or-strategic-status problem strategic-context)))
    (if (eq old-status new-status)
        (error "Uninteresting problem status change for ~a: ~a -> ~a"
               problem old-status new-status)
        (macrolet ((change-status ()
                     '(set-problem-raw-tactical-or-strategic-status problem strategic-context new-status)))
          (case old-status
            (:new
             (case new-status
               (:unexamined (change-status))
               (otherwise (missing-larkc 35283))))
            (:unexamined
             (case new-status
               (:unexamined-good
                (change-status)
                (when (eq :tactical strategic-context)
                  (increment-good-problem-historical-count)))
               (:unexamined-no-good
                (change-status)
                (when (eq :tactical strategic-context)
                  (increment-no-good-problem-historical-count))
                (consider-that-supported-problems-could-be-no-good problem consider-deep? strategic-context))
               (:examined (change-status))
               (otherwise (missing-larkc 35284))))
            (:unexamined-good
             (case new-status
               (:examined-good (change-status))
               (:unexamined
                (change-status)
                (when (eq :tactical strategic-context)
                  (missing-larkc 36279))
                (consider-that-problem-could-be-no-good problem consider-deep? strategic-context t))
               (otherwise (missing-larkc 35285))))
            (:unexamined-no-good
             (case new-status
               (:examined-no-good
                (if (strategy-p strategic-context)
                    (change-status)
                    (missing-larkc 35286)))
               (otherwise (missing-larkc 35287))))
            (:examined
             (case new-status
               (:examined-good
                (change-status)
                (when (eq :tactical strategic-context)
                  (increment-good-problem-historical-count)))
               (:examined-no-good
                (change-status)
                (when (eq :tactical strategic-context)
                  (increment-no-good-problem-historical-count))
                (consider-that-supported-problems-could-be-no-good problem consider-deep? strategic-context))
               (:possible (change-status))
               (:unexamined
                (if (and *reconsidering-set-asides?* (strategy-p strategic-context))
                    (change-status)
                    (missing-larkc 35288)))
               (otherwise (missing-larkc 35289))))
            (:examined-good
             (case new-status
               (:possible-good (change-status))
               (:examined
                (change-status)
                (when (eq :tactical strategic-context)
                  (missing-larkc 36280))
                (consider-that-problem-could-be-no-good problem consider-deep? strategic-context t))
               (:unexamined-good
                (if (and *reconsidering-set-asides?* (strategy-p strategic-context))
                    (change-status)
                    (missing-larkc 35290)))
               (otherwise (missing-larkc 35291))))
            (:possible
             (case new-status
               (:possible-good
                (change-status)
                (when (eq :tactical strategic-context)
                  (increment-good-problem-historical-count)))
               (:pending (change-status))
               (:unexamined
                (if (and *reconsidering-set-asides?* (strategy-p strategic-context))
                    (change-status)
                    (missing-larkc 35292)))
               (otherwise (missing-larkc 35293))))
            (:possible-good
             (case new-status
               (:pending-good (change-status))
               (:possible
                (change-status)
                (when (eq :tactical strategic-context)
                  (missing-larkc 36281))
                (consider-that-problem-could-be-no-good problem consider-deep? strategic-context t))
               (:unexamined-good
                (if (and *reconsidering-set-asides?* (strategy-p strategic-context))
                    (change-status)
                    (missing-larkc 35294)))
               (otherwise (missing-larkc 35295))))
            (:pending
             (case new-status
               (:pending-good
                (change-status)
                (when (eq :tactical strategic-context)
                  (increment-good-problem-historical-count)))
               (:pending-no-good
                (change-status)
                (when (eq :tactical strategic-context)
                  (increment-no-good-problem-historical-count))
                (consider-that-supported-problems-could-be-no-good problem consider-deep? strategic-context))
               (:finished
                (change-status)
                (consider-that-problem-could-be-no-good problem consider-deep? strategic-context t))
               (:unexamined
                (if (and *reconsidering-set-asides?* (strategy-p strategic-context))
                    (change-status)
                    (missing-larkc 35296)))
               (otherwise (missing-larkc 35297))))
            (:pending-good
             (case new-status
               (:pending
                (change-status)
                (when (eq :tactical strategic-context)
                  (missing-larkc 36282))
                (consider-that-problem-could-be-no-good problem consider-deep? strategic-context t))
               (:finished-good (change-status))
               (:unexamined-good
                (if (and *reconsidering-set-asides?* (strategy-p strategic-context))
                    (change-status)
                    (missing-larkc 35298)))
               (otherwise (missing-larkc 35299))))
            (:pending-no-good
             (case new-status
               (:finished-no-good (change-status))
               (:unexamined
                (if (and *reconsidering-set-asides?* (strategy-p strategic-context))
                    (change-status)
                    (missing-larkc 35300)))
               (otherwise (missing-larkc 35301))))
            (:finished
             (case new-status
               (:finished-good
                (change-status)
                (when (eq :tactical strategic-context)
                  (increment-good-problem-historical-count)))
               (:finished-no-good
                (change-status)
                (when (eq :tactical strategic-context)
                  (increment-no-good-problem-historical-count))
                (consider-that-supported-problems-could-be-no-good problem consider-deep? strategic-context))
               (:unexamined
                (if (and *reconsidering-set-asides?* (strategy-p strategic-context))
                    (change-status)
                    (missing-larkc 35302)))
               (otherwise (missing-larkc 35303))))
            (:finished-good
             (case new-status
               (:finished
                (change-status)
                (when (eq :tactical strategic-context)
                  (missing-larkc 36283))
                (consider-that-problem-could-be-no-good problem consider-deep? strategic-context t))
               (:unexamined-good
                (if (and *reconsidering-set-asides?* (strategy-p strategic-context))
                    (change-status)
                    (missing-larkc 35304)))
               (otherwise (missing-larkc 35305))))
            (:finished-no-good
             (case new-status
               (:unexamined
                (if (and *reconsidering-set-asides?* (strategy-p strategic-context))
                    (change-status)
                    (missing-larkc 35306)))
               (otherwise (missing-larkc 35307))))
            (otherwise (missing-larkc 35308)))))
    (when (substrategy? strategic-context)
      (controlling-strategy-callback strategic-context :substrategy-problem-status-change
                                     problem old-status new-status)))
  (if (strategy-p strategic-context)
      (progn
        (set-problem-recompute-thrown-away-wrt-all-motivations problem strategic-context)
        (set-problem-tactics-recompute-thrown-away-wrt-all-motivations problem strategic-context))
      (progn
        (set-problem-recompute-thrown-away-wrt-all-relevant-strategies-and-all-motivations problem)
        (set-problem-tactics-recompute-thrown-away-wrt-all-relevant-strategies-and-all-motivations problem)))
  problem)

;; (defun prohibited-problem-status-change-error (problem old-status new-status) ...) -- active declareFunction, no body

(defun consider-that-problem-could-be-good (problem)
  "[Cyc] Changes PROBLEM's status to a good version of its current status if it has at least one argument link which is good. Propagates the change if there is actually a change."
  (unless (tactically-good-problem-p problem)
    (when (problem-good? problem)
      (let* ((old-status (problem-status problem))
             (new-status (good-version-of-problem-status old-status)))
        (change-and-propagate-problem-status problem new-status nil :tactical))
      ;; Recompute set-aside for logical tactics on dependent links
      (do-set (dependent-link (problem-dependent-links problem))
        (when (problem-link-has-type? dependent-link :logical)
          (dolist (logical-tactic (problem-tactics problem))
            (when (do-problem-tactics-type-match logical-tactic :logical)
              (set-tactic-recompute-set-aside-wrt-all-relevant-strategies-and-all-motivations logical-tactic)))))
      ;; Check for irrelevance to inferences
      (do-problem-relevant-inferences (inference problem)
        (consider-that-problem-could-be-irrelevant-to-inference problem inference))))
  problem)

(defun problem-good? (problem)
  "[Cyc] PROBLEM is deemed good iff it has at least one proof."
  (problem-has-some-proven-proof? problem))

(defun good-version-of-problem-status (status)
  (case status
    ((:unexamined-good :examined-good :possible-good :pending-good :finished-good) status)
    (:unexamined :unexamined-good)
    (:examined :examined-good)
    (:possible :possible-good)
    (:pending :pending-good)
    (:finished :finished-good)
    (:new (error "new problem cannot become good yet"))
    ((:unexamined-no-good :examined-no-good :pending-no-good :finished-no-good)
     (error "Once a problem is no good, it can never go back."))
    (otherwise (error "unknown problem status ~a" status))))

;; (defun unexamined-version-of-problem-status (status) ...) -- active declareFunction, no body

(defun examined-version-of-problem-status (status)
  (case status
    ((:examined :examined-good :examined-no-good) status)
    (:unexamined :examined)
    (:unexamined-good :examined-good)
    (:unexamined-no-good :examined-no-good)
    (otherwise (error "problem of status ~a cannot be examined" status))))

(defun possible-version-of-problem-status (status)
  (case status
    ((:possible :possible-good :possible-no-good) status)
    (:examined :possible)
    (:examined-good :possible-good)
    (otherwise (error "problem of status ~a cannot be made possible" status))))

(defun pending-version-of-problem-status (status)
  (case status
    ((:pending :pending-good :pending-no-good) status)
    (:possible :pending)
    (:possible-good :pending-good)
    (otherwise (error "problem of status ~a cannot be pending" status))))

(defun finished-version-of-problem-status (status)
  (case status
    ((:finished :finished-good :finished-no-good) status)
    (:pending :finished)
    (:pending-good :finished-good)
    (:pending-no-good :finished-no-good)
    (otherwise (error "problem of status ~a cannot be finished" status))))

;; (defun consider-that-problem-could-no-longer-be-good (problem) ...) -- active declareFunction, no body
;; (defun neutral-version-of-problem-status (status) ...) -- active declareFunction, no body

(defun consider-that-problem-could-be-finished (problem consider-deep? strategic-context consider-transformation-tactics?)
  (declare (type strategic-context-p strategic-context))
  (when (problem-could-be-finished? problem consider-deep? strategic-context consider-transformation-tactics?)
    (possibly-note-problem-finished problem strategic-context))
  problem)

(defun problem-could-be-finished? (problem consider-deep? strategic-context consider-transformation-tactics?)
  (unless (pending-problem-p problem strategic-context)
    (return-from problem-could-be-finished? nil))
  (let ((unfinished? nil))
    (do-set (link (problem-argument-links problem) unfinished?)
      (when (problem-link-open? link)
        (setf unfinished? (not (problem-link-could-be-finished? link strategic-context consider-transformation-tactics?)))))
    (not unfinished?)))

(defun problem-link-could-be-finished? (link strategic-context consider-transformation-tactics?)
  (cond ((simplification-link-p link)
         (finished-problem-p (problem-link-sole-supporting-problem link) strategic-context))
        ((restriction-link-p link) t)
        ((removal-link-p link) t)
        ((generalized-transformation-link-p link)
         (if (not consider-transformation-tactics?)
             t
             (finished-problem-p (problem-link-sole-supporting-problem link) strategic-context)))
        ((rewrite-link-p link)
         (finished-problem-p (problem-link-sole-supporting-problem link) strategic-context))
        ((split-link-p link)
         (split-link-could-be-finished? link strategic-context))
        ((join-ordered-link-p link)
         (join-ordered-link-could-be-finished? link strategic-context))
        ((join-link-p link)
         (join-link-could-be-finished? link strategic-context))
        ((union-link-p link)
         (missing-larkc 35357))
        (t (error "unexpected link type ~S" link))))

(defun split-link-could-be-finished? (split-link strategic-context)
  ;; If any conjunct is no-good, the split is "finished" in the no-good sense
  (do-problem-link-supporting-mapped-problems (supporting-mapped-problem split-link)
    (let ((conjunct-problem (mapped-problem-problem supporting-mapped-problem)))
      (when (no-good-problem-p conjunct-problem strategic-context)
        (return-from split-link-could-be-finished? t))))
  ;; Otherwise, all conjuncts must be finished
  (let ((unfinished? nil))
    (do* ((rest (problem-link-supporting-mapped-problems split-link) (rest rest))
          (supporting-mapped-problem (first rest) (first rest)))
         ((or unfinished? (null rest)))
      (when (do-problem-link-open-match? nil split-link supporting-mapped-problem)
        (let ((conjunct-problem (mapped-problem-problem supporting-mapped-problem)))
          (setf unfinished? (not (finished-problem-p conjunct-problem strategic-context))))))
    (not unfinished?)))

(defun join-link-could-be-finished? (j-link strategic-context)
  (let ((first-problem (join-link-first-problem j-link))
        (second-problem (join-link-second-problem j-link)))
    (cond ((or (no-good-problem-p first-problem strategic-context)
               (no-good-problem-p second-problem strategic-context))
           t)
          ((and (finished-problem-p first-problem strategic-context)
                (finished-problem-p second-problem strategic-context))
           t)
          (t nil))))

;; (defun union-link-could-be-finished? (link strategic-context) ...) -- active declareFunction, no body

(defun consider-that-problem-could-be-no-good (problem consider-deep? strategic-context consider-transformation-tactics?)
  (if (eq :tactical strategic-context)
      (default-consider-that-problem-could-be-no-good strategic-context problem consider-deep? consider-transformation-tactics?)
      (strategy-consider-that-problem-could-be-no-good strategic-context problem consider-deep? consider-transformation-tactics?)))

(defun default-consider-that-problem-could-be-no-good (strategic-context problem consider-deep? consider-transformation-tactics?)
  "[Cyc] Changes PROBLEM's status to no-good if it will never have any goal descendants."
  (declare (type strategic-context-p strategic-context))
  (unless (or (tactically-good-problem-p problem)
              (no-good-problem-p problem strategic-context))
    (when (problem-no-good? problem consider-deep? strategic-context consider-transformation-tactics?)
      (make-problem-no-good problem consider-deep? strategic-context)
      (return-from default-consider-that-problem-could-be-no-good t)))
  nil)

(defun make-problem-no-good (problem consider-deep? strategic-context)
  (if (strategy-p strategic-context)
      (possibly-note-problem-pending problem strategic-context)
      (discard-all-possible-tactics problem))
  (when (eq :tactical strategic-context)
    (do-problem-relevant-inferences (inference problem)
      (maybe-make-problem-irrelevant-to-inference inference problem)))
  (when (tactically-good-problem-p problem)
    (do-problem-proofs (proof problem :proof-status :proven)
      (missing-larkc 35342)))
  (unless (no-good-problem-p problem strategic-context)
    (let* ((old-status (problem-raw-tactical-or-strategic-status problem strategic-context))
           (new-status (no-good-version-of-problem-status old-status)))
      (change-and-propagate-problem-status problem new-status consider-deep? strategic-context)
      (when (eq :tactical strategic-context)
        (possibly-note-eager-pruning-problem problem))
      (do-set (link (problem-dependent-links problem))
        (when (problem-link-has-type? link :conjunctive)
          (make-problem-no-good (problem-link-supported-problem link) consider-deep? strategic-context)))))
  nil)

(defun discard-all-possible-tactics (problem)
  (discard-possible-tactics-int problem nil nil nil nil nil))

(defun discard-all-impossible-possible-tactics (problem)
  (discard-possible-tactics-int problem :impossible nil :content nil nil)
  (unless (problem-store-transformation-allowed? (problem-store problem))
    (discard-possible-tactics-int problem nil :disallowed :logical nil nil))
  problem)

(defun discard-possible-tactics-int (problem completeness preference-level type tactic-to-not-discard productivity)
  (dolist (tactic (problem-tactics problem))
    (when (and (do-problem-tactics-type-match tactic type)
               (do-problem-tactics-status-match tactic :possible)
               (do-problem-tactics-completeness-match tactic completeness)
               (do-problem-tactics-preference-level-match tactic preference-level)
               (do-problem-tactics-productivity-match tactic productivity))
      (unless (eq tactic tactic-to-not-discard)
        (note-tactic-discarded tactic)
        (do-problem-relevant-strategies (strategy problem)
          (strategy-note-tactic-discarded strategy tactic)))))
  (when (and (tactically-possible-problem-p problem)
             (not (problem-has-possible-tactics? problem)))
    (note-problem-pending problem :tactical))
  (consider-that-problem-could-be-strategically-pending problem)
  problem)

(defun consider-that-problem-could-be-strategically-pending (problem)
  (when (eq problem (currently-active-problem))
    (return-from consider-that-problem-could-be-strategically-pending nil))
  (do-problem-relevant-strategies (strategy problem)
    (consider-that-problem-could-be-strategically-pending-wrt problem strategy))
  problem)

(defun consider-that-problem-could-be-strategically-pending-wrt (problem strategy)
  (strategy-consider-that-problem-could-be-strategically-pending strategy problem)
  (when (and (strategically-possible-problem-p problem strategy)
             (strategy-no-possible-strategems-for-problem? strategy problem))
    (possibly-note-problem-pending problem strategy))
  problem)

(defun consider-that-supported-problems-could-be-no-good (supporting-problem consider-deep? strategic-context)
  (do-set (link (problem-dependent-links supporting-problem))
    (cond ((answer-link-p link)
           (let ((supported-inference (problem-link-supported-inference link)))
             (inference-note-no-good supported-inference)))
          ((union-link-p link)
           (let ((supported-problem (problem-link-supported-problem link)))
             (when (missing-larkc 35185)
               (consider-that-problem-could-be-no-good supported-problem consider-deep? strategic-context t))))
          ((transformation-link-p link)
           (let ((supported-problem (problem-link-supported-problem link)))
             (consider-that-problem-could-be-no-good supported-problem consider-deep? strategic-context t)))
          ((rewrite-link-p link)
           (let ((supported-problem (problem-link-supported-problem link)))
             (consider-that-problem-could-be-no-good supported-problem consider-deep? strategic-context t)))
          (t
           (when (and (eq :tactical strategic-context) (split-link-p link))
             (close-split-link link))
           (when (link-permits-no-good-propagation-to-supported-problems? link)
             (let ((supported-problem (problem-link-supported-problem link)))
               (consider-that-problem-could-be-no-good supported-problem consider-deep? strategic-context t))))))
  supporting-problem)

(defun no-good-version-of-problem-status (status)
  (case status
    (:finished :finished-no-good)
    (:pending :pending-no-good)
    (:examined :examined-no-good)
    (:unexamined :unexamined-no-good)
    (otherwise (error "Unexpected status ~s" status))))

(defun problem-no-good? (problem consider-deep? strategic-context consider-transformation-tactics?)
  "[Cyc] A problem is considered no-good if all of its argument links are no good, and it will never have any more."
  (declare (type strategic-context-p strategic-context))
  (unsatisfiable-problem? problem consider-deep? strategic-context consider-transformation-tactics?))

(defun unsatisfiable-problem? (problem consider-deep? strategic-context consider-transformation-tactics?)
  (cond ((good-problem-p problem strategic-context) nil)
        ((tactically-unexamined-problem-p problem) nil)
        ((tactically-examined-problem-p problem) (closed-problem-p problem))
        ((and (single-literal-problem-p problem)
              (problem-has-some-open-obviously-neutral-argument-link?
               problem consider-deep? strategic-context consider-transformation-tactics?))
         nil)
        ((and (finished-problem-p problem strategic-context)
              (or (closed-problem-p problem)
                  (not (single-literal-problem-p problem))))
         t)
        ((and (pending-problem-p problem strategic-context)
              (problem-has-executed-a-complete-tactic? problem strategic-context :generalized-removal)
              (not (problem-has-relevant-supporting-problem? problem strategic-context consider-transformation-tactics?)))
         t)
        ((and (pending-problem-p problem strategic-context)
              (eq :preferred (memoized-problem-global-preference-level
                              problem strategic-context (problem-variables problem)))
              (not (problem-has-relevant-supporting-problem? problem strategic-context consider-transformation-tactics?)))
         t)
        ((and (problem-has-argument-link-of-type? problem :split)
              (some-no-good-split-argument-link? problem consider-deep? strategic-context consider-transformation-tactics?))
         t)
        ((and (problem-has-argument-link-of-type? problem :join-ordered)
              (some-no-good-join-ordered-argument-link? problem consider-deep? strategic-context consider-transformation-tactics?))
         t)
        ((and (problem-has-argument-link-of-type? problem :join)
              (some-no-good-join-argument-link? problem consider-deep? strategic-context consider-transformation-tactics?))
         t)
        ((and (tactically-pending-problem-p problem)
              (problem-has-argument-link-of-type? problem :union)
              (missing-larkc 35186))
         t)
        ((problem-has-a-simplification? problem) (missing-larkc 35184))
        (t nil)))

(defun problem-has-some-open-obviously-neutral-argument-link? (problem consider-deep? strategic-context consider-transformation-tactics?)
  (do-set (argument-link (problem-argument-links problem))
    (when (or consider-transformation-tactics?
              (not (generalized-transformation-link-p argument-link)))
      (when (and (or (not consider-deep?)
                     (not (missing-larkc 35273)))
                 (problem-link-has-some-open-obviously-neutral-supporting-mapped-problem? argument-link strategic-context))
        (return-from problem-has-some-open-obviously-neutral-argument-link? t))))
  nil)

(defun some-no-good-split-argument-link? (problem consider-deep? strategic-context consider-transformation-tactics?)
  (do-set (split-link (problem-argument-links problem))
    (when (problem-link-has-type? split-link :split)
      (when (problem-link-no-good? split-link consider-deep? strategic-context consider-transformation-tactics?)
        (return-from some-no-good-split-argument-link? t))))
  nil)

(defun some-no-good-join-ordered-argument-link? (problem consider-deep? strategic-context consider-transformation-tactics?)
  (do-set (join-ordered-link (problem-argument-links problem))
    (when (problem-link-has-type? join-ordered-link :join-ordered)
      (when (problem-link-no-good? join-ordered-link consider-deep? strategic-context consider-transformation-tactics?)
        (return-from some-no-good-join-ordered-argument-link? t))))
  nil)

(defun some-no-good-join-argument-link? (problem consider-deep? strategic-context consider-transformation-tactics?)
  (do-set (join-link (problem-argument-links problem))
    (when (problem-link-has-type? join-link :join)
      (when (problem-link-no-good? join-link consider-deep? strategic-context consider-transformation-tactics?)
        (return-from some-no-good-join-argument-link? t))))
  nil)

;; (defun all-no-good-union-argument-links? (problem consider-deep? strategic-context consider-transformation-tactics?) ...) -- active declareFunction, no body

(defun problem-link-no-good? (link consider-deep? strategic-context consider-transformation-tactics?)
  "[Cyc] A link is considered no-good if at least one of its supporting problems is no good."
  (declare (type strategic-context-p strategic-context))
  (when (and consider-transformation-tactics?
             (strategy-p strategic-context)
             (not (problem-transformation-allowed-wrt-max-transformation-depth?
                   (strategy-inference strategic-context)
                   (problem-link-supported-problem link))))
    (setf consider-transformation-tactics? nil))
  (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
    (let ((supporting-problem (mapped-problem-problem supporting-mapped-problem)))
      (when (no-good-problem-p supporting-problem strategic-context)
        (return-from problem-link-no-good? t))
      (when (and (not consider-transformation-tactics?)
                 (problem-no-good-ignoring-transformation-tactics? supporting-problem strategic-context))
        (return-from problem-link-no-good? t))))
  (when consider-deep?
    (when (join-ordered-link-p link)
      (missing-larkc 36367)))
  nil)

(defun problem-no-good-ignoring-transformation-tactics? (problem strategic-context)
  "[Cyc] Return boolean; t iff PROBLEM is no good if you ignore its transformation tactics (if any)."
  (problem-no-good? problem nil strategic-context nil))

(defun problem-link-has-some-open-obviously-neutral-supporting-mapped-problem? (link strategic-context)
  (declare (type strategic-context-p strategic-context))
  (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
    (when (problem-link-supporting-mapped-problem-open? link supporting-mapped-problem)
      (let ((supporting-problem (mapped-problem-problem supporting-mapped-problem)))
        (when (neutral-problem-p supporting-problem strategic-context)
          (return-from problem-link-has-some-open-obviously-neutral-supporting-mapped-problem? t)))))
  nil)

;; (defun problem-link-has-some-open-obviously-good-supporting-mapped-problem? (link) ...) -- active declareFunction, no body
;; (defun problem-link-interesting-when-considered-deep? (link) ...) -- active declareFunction, no body
;; (defun problem-link-no-good-wrt-dependent-join-ordered-link? (link consider-deep? strategic-context consider-transformation-tactics?) ...) -- active declareFunction, no body
;; (defun restricted-focal-problem-has-a-no-good-restricted-non-focal-analogue? (problem strategic-context) ...) -- active declareFunction, no body

(defun link-permits-no-good-propagation-to-supported-problems? (link)
  (let ((pcase-var (problem-link-type link)))
    (cond ((eq pcase-var :split) t)
          ((eq pcase-var :join-ordered) t)
          (t nil))))

(defun propagate-proof-spec-via-answer-link (answer-link)
  (let ((inference (answer-link-supported-inference answer-link))
        (supporting-problem (answer-link-supporting-problem answer-link)))
    (do-inference-strategies (strategy inference)
      (let ((proof-spec (strategy-proof-spec strategy)))
        (unless (eq :anything proof-spec)
          (missing-larkc 35351)))))
  answer-link)

(defun propagate-proof-spec (link)
  (when (answer-link-p link)
    (return-from propagate-proof-spec (propagate-proof-spec-via-answer-link link)))
  (let ((supported-problem (problem-link-supported-problem link)))
    (when (problem-has-some-proof-spec-to-propagate? supported-problem)
      (do-problem-link-supporting-mapped-problems (supporting-mapped-problem link)
        (when (missing-larkc 35244)
          (let ((supporting-problem (mapped-problem-problem supporting-mapped-problem)))
            (missing-larkc 35316))))))
  link)

(defun problem-has-some-proof-spec-to-propagate? (problem)
  (do-problem-relevant-strategies (strategy problem)
    (when (not (eq :anything (strategy-proof-spec strategy)))
      (when (not (eq :anything (missing-larkc 36474)))
        (return-from problem-has-some-proof-spec-to-propagate? t))))
  nil)

;; Reconstructed from: $list145=((TYPED-PROOF-SPEC PROOF-SPEC PROOF-SPEC-TYPE-P) &BODY BODY),
;; $sym146$FILTER-PROOF-SPECS-OF-TYPE, $sym147$PUNLESS, $sym148$NULL
(defmacro with-proof-spec-of-appropriate-type (((typed-proof-spec proof-spec proof-spec-type-p)) &body body)
  `(let ((,typed-proof-spec (filter-proof-specs-of-type ,proof-spec ,proof-spec-type-p)))
     (unless (null ,typed-proof-spec)
       ,@body)))

;; (defun propagate-proof-spec-to-supporting-problem-via-link (link strategy proof-spec) ...) -- active declareFunction, no body
;; (defun strategy-propagate-proof-spec-to-supporting-problem-via-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun link-permits-proof-spec-propagation? (link supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun proof-spec-of-appropriate-type? (proof-spec type) ...) -- active declareFunction, no body
;; (defun strategy-propagate-problem-proof-spec (strategy problem proof-spec) ...) -- active declareFunction, no body
;; (defun propagate-join-ordered-proof-spec-via-join-ordered-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-join-ordered-proof-spec-via-join-ordered-link-int (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-proof-spec-via-union-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-residual-transformation-proof-spec-via-join-ordered-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-residual-transformation-proof-spec-via-join-ordered-link-int (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-proof-spec-via-restriction-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-proof-spec-via-split-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-proof-spec-via-join-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-proof-spec-via-conjunctive-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-proof-spec-via-simplification-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-proof-spec-via-transformation-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-transformation-proof-spec-via-transformation-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-proof-spec-via-residual-transformation-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun propagate-residual-transformation-proof-spec-via-residual-transformation-link (link strategy proof-spec supporting-mapped-problem) ...) -- active declareFunction, no body

;; (defun find-problem (store query) ...) -- active declareFunction, no body

(defun find-or-create-problem (store query &optional complex?)
  "[Cyc] Return nil or mapped-problem-p"
  (multiple-value-bind (problem problem-variable-map canonical-query)
      (find-problem-int store query complex?)
    (unless problem
      (setf problem (new-problem store canonical-query)))
    (new-mapped-problem problem problem-variable-map)))

(defun find-problem-int (store query complex?)
  "[Cyc] See find-problem. Returns an additional value: the canonical query extracted from QUERY"
  (let ((method (problem-store-equality-reasoning-method store)))
    (cond ((eq method :equal)
           (let ((problem (find-problem-by-query store query))
                 (problem-variable-map nil))
             (values problem problem-variable-map query)))
          ((eq method :czer-equal)
           (multiple-value-bind (canonical-query canonical-variable-map)
               (canonicalize-problem-query query)
             (let ((problem (find-problem-by-query store canonical-query)))
               (when (and (null problem) complex?)
                 (multiple-value-bind (complex-problem complex-variable-map)
                     (missing-larkc 33146)
                   (when complex-problem
                     (let* ((complex-query (problem-query complex-problem))
                            (final-variable-map (compose-bindings complex-variable-map canonical-variable-map)))
                       (return-from find-problem-int
                         (values complex-problem final-variable-map complex-query))))))
               (values problem canonical-variable-map canonical-query)))))))

;; (defun find-or-create-problem-from-contextualized-asent-sense (store contextualized-asent sense) ...) -- active declareFunction, no body
;; (defun find-or-create-problem-from-contextualized-clause (store contextualized-clause) ...) -- active declareFunction, no body

(defun find-or-create-problem-from-subclause-spec (store contextualized-clause subclause-spec)
  "[Cyc] Return a problem in STORE whose query is the literals from CONTEXTUALIZED-CLAUSE specified by SUBCLAUSE-SPEC."
  (let ((query (new-problem-query-from-subclause-spec contextualized-clause subclause-spec)))
    (find-or-create-problem store query)))

(defun find-or-create-problem-without-subclause-spec (store contextualized-clause subclause-spec)
  "[Cyc] Return a problem in STORE whose query is CONTEXTUALIZED-CLAUSE without the literals specified by SUBCLAUSE-SPEC."
  (let ((query-without (new-problem-query-without-subclause-spec contextualized-clause subclause-spec)))
    (find-or-create-problem store query-without)))

(defun find-or-create-root-problem-and-link (inference)
  (let* ((store (inference-problem-store inference))
         (hl-query (inference-hl-query inference))
         (mapped-root-problem (find-or-create-root-problem store hl-query)))
    (new-root-answer-link inference mapped-root-problem)
    mapped-root-problem))

(defun new-root-answer-link (inference mapped-root-problem)
  "[Cyc] Hooks up the answer link between the root subproblem and the strategy, but intentionally doesn't propagate it yet."
  (let ((link (new-answer-link inference)))
    (connect-supporting-mapped-problem-with-dependent-link mapped-root-problem link)
    (let ((root-problem (mapped-problem-problem mapped-root-problem)))
      (add-problem-store-historical-root-problem (problem-store root-problem) root-problem))
    link))

(defun find-or-create-root-problem (store query)
  (find-or-create-problem store query))

(deflexical *problem-store-prune-reports*
  (if (and (boundp '*problem-store-prune-reports*) (typep *problem-store-prune-reports* t))
      *problem-store-prune-reports*
      nil)
  "[Cyc] Whether the problem store prune should be verbose.")

(defparameter *possibly-propagate-problem-indestructible-stack* :uninitialized
  "[Cyc] to avoid infinite recursion")

;; (defun prune-problem-store (store &optional verbose?) ...) -- active declareFunction, no body
;; (defun destroy-destructible-problems (store) ...) -- active declareFunction, no body
;; (defun recompute-destructible-problems (store &optional verbose?) ...) -- active declareFunction, no body
;; (defun consider-deep-no-goodness (store) ...) -- active declareFunction, no body
;; (defun compute-problem-store-min-depth-index (store) ...) -- active declareFunction, no body
;; (defun compute-indestructible-problems-from-inferences (store) ...) -- active declareFunction, no body
;; (defun possibly-propagate-problem-indestructible (problem) ...) -- active declareFunction, no body
;; (defun possibly-propagate-problem-indestructible-int (problem) ...) -- active declareFunction, no body
;; (defun possibly-note-problem-indestructible (problem) ...) -- active declareFunction, no body
;; (defun compute-problem-link-destructible? (link) ...) -- active declareFunction, no body
;; (defun problem-link-closed-forever? (link) ...) -- active declareFunction, no body
;; (defun problem-link-closed-forever-wrt-supporting-mapped-problem? (link supporting-mapped-problem) ...) -- active declareFunction, no body
;; (defun problem-should-be-indestructible? (problem) ...) -- active declareFunction, no body
;; (defun problem-store-janitor-destructible-problem-list (store) ...) -- active declareFunction, no body
;; (defun note-all-root-problems-indestructible (store) ...) -- active declareFunction, no body
;; (defun compute-indestructible-problems-due-to-proofs (store) ...) -- active declareFunction, no body
;; (defun propagate-proof-indestructibility (proof) ...) -- active declareFunction, no body
;; (defun compute-indestructible-problems-due-to-strategic-activity (store) ...) -- active declareFunction, no body
;; (defun possibly-prune-processed-problems (store) ...) -- active declareFunction, no body
;; (defun possibly-prune-wrt-conjunctive-removal (store) ...) -- active declareFunction, no body
;; (defun prunable-objects-wrt-conjunctive-removal (store) ...) -- active declareFunction, no body
;; (defun update-prunable-conjunctive-removal-objects (objects problem proof-tuples) ...) -- active declareFunction, no body
;; (defun compute-conjunctive-removal-proof-tuples (proof) ...) -- active declareFunction, no body
;; (defun isolated-problem-subset (problems) ...) -- active declareFunction, no body
;; (defun problem-isolated-wrt-problems? (problem problems) ...) -- active declareFunction, no body
;; (defun finished-problem-subset (problems) ...) -- active declareFunction, no body

(defun possibly-note-eager-pruning-problem (problem)
  0)

;; (defun possibly-prune-processed-proofs (store) ...) -- active declareFunction, no body
;; (defun problem-store-all-processed-objects (store type) ...) -- active declareFunction, no body
;; (defun problem-processed? (problem type) ...) -- active declareFunction, no body
;; (defun link-processed? (link) ...) -- active declareFunction, no body
;; (defun possibly-prune-processed-object (object) ...) -- active declareFunction, no body
;; (defun problem-is-the-root-problem-of-some-inference? (problem) ...) -- active declareFunction, no body

(defun consider-pruning-ramifications-of-ignored-strategem (strategy strategem)
  (when (and (conjunctive-removal-tactic-p strategem)
             (tactic-executed? strategem)
             (not (problem-store-compute-answer-justifications? (tactic-store strategem))))
    (let ((problem (tactic-problem strategem)))
      (when (and (tactically-good-problem-p problem)
                 (tactically-finished-problem-p problem)
                 (not (missing-larkc 35271))
                 (not (find-if #'split-link-p (missing-larkc 35368))))
        (missing-larkc 35363))))
  nil)

(defparameter *processed-proofs-retain-one-proof?* t)

;; (defun prunable-processed-problem? (problem) ...) -- active declareFunction, no body
;; (defun restricted-non-focal-with-sibling? (problem store) ...) -- active declareFunction, no body
;; (defun restricted-focal-with-sibling? (problem store) ...) -- active declareFunction, no body
;; (defun corresponding-restricted-non-focal-unfinished? (problem store) ...) -- active declareFunction, no body
;; (defun prunable-processed-link? (link) ...) -- active declareFunction, no body
;; (defun problem-is-reused-interestingly? (problem) ...) -- active declareFunction, no body
;; (defun link-has-all-the-proofs? (link) ...) -- active declareFunction, no body
;; (defun join-ordered-link-restricted-focal-count (link) ...) -- active declareFunction, no body
;; (defun all-problem-proofs-are-processed? (problem) ...) -- active declareFunction, no body
;; (defun all-link-proofs-are-processed? (link) ...) -- active declareFunction, no body
;; (defun problem-has-no-motivation-other-than-removal? (problem) ...) -- active declareFunction, no body
;; (defun problem-finished-wrt-removal? (problem strategies) ...) -- active declareFunction, no body
;; (defun problem-store-removal-strategies (store) ...) -- active declareFunction, no body
;; (defun problem-is-a-new-root? (problem strategies) ...) -- active declareFunction, no body
;; (defun problem-store-new-root-strategies (store) ...) -- active declareFunction, no body
;; (defun note-problem-dirty (problem) ...) -- active declareFunction, no body
;; (defun problem-store-possibly-redundant-proof-sets (store) ...) -- active declareFunction, no body
;; (defun problem-store-all-possibly-redundant-proofs (store) ...) -- active declareFunction, no body
;; (defun problem-store-possibly-redundant-proof-count (store) ...) -- active declareFunction, no body
;; (defun possibly-prune-proof-tree (store) ...) -- active declareFunction, no body
;; (defun compute-root-proofs (store) ...) -- active declareFunction, no body
;; (defun direct-dependent-proofs-including-split-restrictions (proof) ...) -- active declareFunction, no body
;; (defun all-triggered-restricted-non-focal-links (proof) ...) -- active declareFunction, no body
;; (defun proof-prunable? (proof) ...) -- active declareFunction, no body
;; (defun prune-starting-from-root-proofs (store) ...) -- active declareFunction, no body
;; (defun prune-entire-problem-store (store) ...) -- active declareFunction, no body
;; (defun prune-problem-store-below (store) ...) -- active declareFunction, no body
;; (defun all-problem-store-objects-below (store) ...) -- active declareFunction, no body
;; (defun add-all-problem-store-objects-below-recursive (object set) ...) -- active declareFunction, no body
;; (defun prune-problem-store-objects (store objects) ...) -- active declareFunction, no body
;; (defun prunable-problem-store-object? (object set) ...) -- active declareFunction, no body
;; (defun prunable-problem? (problem set) ...) -- active declareFunction, no body
;; (defun prunable-problem-link? (link) ...) -- active declareFunction, no body
;; (defun problem-not-in-progress-wrt-removal? (problem strategies) ...) -- active declareFunction, no body
;; (defun prune-problem-store-object (object) ...) -- active declareFunction, no body
;; (defun problem-store-compute-proof-keeping-problems (store) ...) -- active declareFunction, no body
;; (defun inference-compute-proof-keeping-problems (inference) ...) -- active declareFunction, no body
;; (defun compute-proof-keeping-problems-recursive (problem) ...) -- active declareFunction, no body
;; (defun compute-proof-keeping-links-recursive (link) ...) -- active declareFunction, no body
;; (defun choose-split-link-non-proof-keeping-problem (link) ...) -- active declareFunction, no body
;; (defun note-and-propagate-proof-keeping-problem (problem set) ...) -- active declareFunction, no body
;; (defun note-and-propagate-proof-keeping-problem-recursive (problem set) ...) -- active declareFunction, no body

;; Setup-phase forms
(toplevel (note-memoized-function 'intermediate-proof-step-valid-memoized?))
(toplevel (note-memoized-function 'cached-inference-proof-non-explanatory-subproofs))
(toplevel (declare-defglobal '*problem-store-prune-reports*))
