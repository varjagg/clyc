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

;; The problem datastructure is the fundamental unit of the inference
;; search graph. Each problem holds a query (contextualized DNF clauses),
;; links to parent/child problems, tactics, and proofs.

(defstruct (problem
            (:conc-name "prob-")
            (:constructor make-problem (&key suid store query status
                                            dependent-links argument-links
                                            tactics proof-bindings-index
                                            argument-link-bindings-index)))
  suid
  store
  query
  status
  dependent-links
  argument-links
  tactics
  proof-bindings-index
  argument-link-bindings-index)

;; print-problem has no body in LarKC. Format strings from Internal Constants:
;; "<Invalid PROBLEM ~s>" and "<~a PROBLEM ~a.~a:~s>"
(defmethod print-object ((object problem) stream)
  (if (eq :free (prob-status object))
      (format stream "<Invalid PROBLEM ~s>" (prob-suid object))
      (format stream "<~a PROBLEM ~a.~a:~s>"
              (prob-status object)
              (when (prob-store object)
                (problem-store-suid (prob-store object)))
              (prob-suid object)
              (prob-query object))))

(defun sxhash-problem-method (object)
  (prob-suid object))


;;; Variables

(defglobal *empty-clauses*
  (list (empty-clause))
  "[Cyc] The empty clauses.")

(deflexical *generalized-tactic-types*
  '(:non-transformation :generalized-removal :generalized-removal-or-rewrite
    :connected-conjunction :conjunctive :disjunctive :logical
    :logical-conjunctive :structural-conjunctive :meta-structural
    :content :union :split :join-ordered :join)
  "[Cyc] Generalized tactic types which specify more than one actual tactic-type-p.")

(defvar *transformation-depth-computation* :counterintuitive
  "[Cyc] :intuitive or :counterintuitive. :intuitive means that any transformation or residual transformation link increments the transformation depth by 1. This corresponds to the number of times that the problem has been transformed. :counterintuitive means that transformation-depth indicates the maximum number of times that any /literal/ in the problem has been transformed.")

(defparameter *problem-min-transformation-depth-from-signature-enabled?* t
  "[Cyc] Temporary control variable; when non-nil min-transformation-depth is computed from the min-transformation-depth-signature. Should eventually stay T.")

(deflexical *max-problem-tactics* 10000
  "[Cyc] The maximum number of tactics (of any status) that can be on a single problem. Attempting to add an additional tactic after this number yields an error.")


;;; Functions with bodies — in source order from declareFunction

(defun valid-problem-p (object)
  (and (problem-p object)
       (not (problem-invalid-p object))))

(defun problem-invalid-p (problem)
  (eq :free (problem-status problem)))

;; (defun print-problem (object stream depth) ...) -- active declareFunction, no body

(defun new-problem (store query)
  "[Cyc] Creates and canonicalizes a new problem."
  (declare (type problem-store-p store))
  (note-new-problem-created)
  (when (and *inference-debug?*
             (missing-larkc 33142))
    (cerror "Ignore the crazy problems"
            "Crazy amount of problems (~a) in store ~a"
            (problem-store-problem-count store) store))
  (let* ((problem (make-problem))
         (suid (problem-store-new-problem-id store)))
    (increment-problem-historical-count)
    (when (problem-query-has-single-literal-p query)
      (increment-single-literal-problem-historical-count))
    (setf (prob-suid problem) suid)
    (setf (prob-store problem) store)
    (setf (prob-query problem) query)
    (set-problem-status problem :new)
    (setf (prob-argument-links problem) (new-set-contents 0 #'eq))
    (setf (prob-dependent-links problem) (new-set-contents 0 #'eq))
    (setf (prob-tactics problem) nil)
    (setf (prob-proof-bindings-index problem) (make-hash-table :test #'equal))
    (setf (prob-argument-link-bindings-index problem) (make-hash-table :test #'equal))
    (add-problem-store-problem store problem)
    (note-problem-created problem)
    problem))


;;; Macro: do-problem-literals
;; Reconstructed from Internal Constants: $list47 (arglist), $sym51 (DO-PROBLEM-QUERY-LITERALS),
;; $sym52 (PROBLEM-QUERY)
(defmacro do-problem-literals ((asent-var mt-var sense-var problem &key done) &body body)
  `(do-problem-query-literals (,asent-var ,mt-var ,sense-var (problem-query ,problem) :done ,done)
     ,@body))


;;; Macro: do-problem-tactics
;; Reconstructed from Internal Constants: $list53 (arglist with &key done status completeness
;; preference-level hl-module type productivity), $sym66 (DO-LIST→dolist),
;; $sym67 (PROBLEM-TACTICS), $sym69 (PWHEN→when), $sym70 (CAND→and),
;; plus helper function symbols for each filter.
(defmacro do-problem-tactics ((tactic-var problem &key done status completeness
                                          preference-level hl-module type productivity)
                              &body body)
  `(dolist (,tactic-var (problem-tactics ,problem))
     ,@(when done `((when ,done (return nil))))
     (when (and (do-problem-tactics-type-match ,tactic-var ,type)
                (do-problem-tactics-status-match ,tactic-var ,status)
                (do-problem-tactics-completeness-match ,tactic-var ,completeness)
                (do-problem-tactics-preference-level-match ,tactic-var ,preference-level)
                (do-problem-tactics-hl-module-match ,tactic-var ,hl-module)
                (do-problem-tactics-productivity-match ,tactic-var ,productivity))
       ,@body)))


(defun problem-tactics (problem)
  (declare (type problem problem))
  (prob-tactics problem))

(defun do-problem-tactics-status-match (tactic status-spec)
  (or (null status-spec)
      (tactic-has-status? tactic status-spec)))

(defun do-problem-tactics-completeness-match (tactic completeness-spec)
  (if (null completeness-spec)
      t
      (eq completeness-spec (tactic-completeness tactic))))

(defun do-problem-tactics-preference-level-match (tactic preference-level-spec)
  (if (null preference-level-spec)
      t
      (eq preference-level-spec (tactic-preference-level tactic))))

(defun do-problem-tactics-productivity-match (tactic productivity-spec)
  (if (null productivity-spec)
      t
      ;; Likely compares tactic productivity to spec
      (missing-larkc 36506)))

(defun do-problem-tactics-hl-module-match (tactic hl-module-spec)
  (if (null hl-module-spec)
      t
      (eq hl-module-spec (tactic-hl-module tactic))))

;; (defun generalized-tactic-type-p (object) ...) -- active declareFunction, no body

(defun do-problem-tactics-type-match (tactic type-spec)
  (tactic-matches-type-spec? tactic type-spec))

(defun tactic-matches-type-spec? (tactic type-spec)
  (if (null type-spec)
      t
      (case type-spec
          (:non-transformation (not (transformation-tactic-p tactic)))
          (:generalized-removal (generalized-removal-tactic-p tactic))
          (:generalized-removal-or-rewrite (or (generalized-removal-tactic-p tactic)
                                               (rewrite-tactic-p tactic)))
          (:connected-conjunction (connected-conjunction-tactic-p tactic))
          (:conjunctive (conjunctive-tactic-p tactic))
          (:disjunctive (disjunctive-tactic-p tactic))
          (:logical (logical-tactic-p tactic))
          (:logical-conjunctive (logical-conjunctive-tactic-p tactic))
          (:structural-conjunctive (logical-conjunctive-tactic-p tactic))
          (:meta-structural (meta-structural-tactic-p tactic))
          (:content (content-tactic-p tactic))
          (:union (union-tactic-p tactic))
          (:split (split-tactic-p tactic))
          (:join-ordered (join-ordered-tactic-p tactic))
          (:join (join-tactic-p tactic))
          (otherwise (eq type-spec (tactic-type tactic))))))

;; (defun tactic-matches-any-of-type-specs? (tactic type-specs) ...) -- active declareFunction, no body

(defun problem-argument-links (problem)
  (prob-argument-links problem))

;; (defun problem-all-argument-links (problem) ...) -- active declareFunction, no body


;;; Macro: do-problem-dependent-links
;; Reconstructed from Internal Constants: $list94 (arglist (link-var problem &key type done)),
;; $sym96 (DO-SET-CONTENTS→do-set), $sym97 (PROBLEM-DEPENDENT-LINKS),
;; $sym99 (PROBLEM-LINK-HAS-TYPE?)
(defmacro do-problem-dependent-links ((link-var problem &key type done) &body body)
  (if type
      `(do-set (,link-var (problem-dependent-links ,problem) ,done)
         (when (problem-link-has-type? ,link-var ,type)
           ,@body))
      `(do-set (,link-var (problem-dependent-links ,problem) ,done)
         ,@body)))


(defun problem-dependent-links (problem)
  (prob-dependent-links problem))

;; (defun problem-all-dependent-links (problem) ...) -- active declareFunction, no body


;;; Macro: do-problem-dependent-link-interpretations
;; Reconstructed from Internal Constants: $list100 (arglist), $sym103 (PROBLEM-VAR gensym),
;; $sym104 (CLET→let), $sym105 (DO-PROBLEM-LINK-SUPPORTING-MAPPED-PROBLEMS),
;; $sym106 (MAPPED-PROBLEM-PROBLEM)
(defmacro do-problem-dependent-link-interpretations ((link-var mapped-problem-var problem
                                                      &key type open? done) &body body)
  (with-temp-vars (problem-var)
    `(let ((,problem-var ,problem))
       (do-problem-dependent-links (,link-var ,problem-var :type ,type :done ,done)
         (do-problem-link-supporting-mapped-problems (,mapped-problem-var ,link-var :done ,done)
           (let ((,mapped-problem-var (mapped-problem-problem ,mapped-problem-var)))
             ,@body))))))


;;; Macro: do-problem-supported-problems
;; Reconstructed from Internal Constants: $list107 (arglist), $sym108 (LINK gensym),
;; $sym109 (PROBLEM-LINK-SUPPORTED-PROBLEM)
(defmacro do-problem-supported-problems ((supported-problem-var problem &key done) &body body)
  (with-temp-vars (link)
    `(do-problem-dependent-links (,link ,problem :done ,done)
       (let ((,supported-problem-var (problem-link-supported-problem ,link)))
         ,@body))))


;;; Macro: do-problem-supported-inferences
;; Reconstructed from Internal Constants: $list110 (arglist), $sym111 (LINK gensym),
;; $sym112 (PROBLEM-LINK-SUPPORTED-INFERENCE)
(defmacro do-problem-supported-inferences ((supported-inference-var problem) &body body)
  (with-temp-vars (link)
    `(do-problem-dependent-links (,link ,problem)
       (let ((,supported-inference-var (problem-link-supported-inference ,link)))
         ,@body))))


;;; Macro: do-problem-supporting-problems
;; Reconstructed from Internal Constants: $list113 (arglist), $sym114 (LINK gensym),
;; $sym115 (DO-PROBLEM-LINK-SUPPORTING-PROBLEMS)
(defmacro do-problem-supporting-problems ((supporting-problem-var variable-map-var problem)
                                          &body body)
  (with-temp-vars (link)
    `(do-problem-argument-links (,link ,problem)
       (do-problem-link-supporting-problems (,supporting-problem-var ,variable-map-var ,link)
         ,@body))))


;;; Macro: do-problem-proofs
;; Reconstructed from Internal Constants: $list116 (arglist), $sym119 (PROOF-LIST gensym),
;; $sym120 (BINDINGS gensym), $sym121 (DO-DICTIONARY-CONTENTS→do-dictionary),
;; $sym122 (PROBLEM-PROOF-BINDINGS-INDEX), $sym124 (STATUS-VAR gensym),
;; $sym126 (PROOF-HAS-STATUS?)
(defmacro do-problem-proofs ((proof-var problem &key proof-status done) &body body)
  (with-temp-vars (proof-list status-var)
    (let ((_bindings (gensym "_BINDINGS")))
      `(let ((,status-var ,proof-status))
         (do-dictionary (,_bindings ,proof-list (problem-proof-bindings-index ,problem)
                         ,@(when done (list done)))
           (dolist (,proof-var ,proof-list)
             ,@(when done `((when ,done (return nil))))
             (when (proof-has-status? ,proof-var ,status-var)
               ,@body)))))))


(defun problem-proof-bindings-index (problem)
  (prob-proof-bindings-index problem))

(defun proof-has-status? (proof status)
  (if (null status)
      t
      (eq status (proof-status proof))))


;;; Macro: do-problem-active-inferences
;; Reconstructed from Internal Constants: $list127 (arglist), $sym128 (STRATEGY gensym),
;; $sym129 (DO-PROBLEM-ACTIVE-STRATEGIES), $sym130 (STRATEGY-INFERENCE)
(defmacro do-problem-active-inferences ((inference-var problem) &body body)
  (with-temp-vars (strategy)
    `(do-problem-active-strategies (,strategy ,problem)
       (let ((,inference-var (strategy-inference ,strategy)))
         ,@body))))


;;; Macro: do-problem-relevant-inferences
;; Reconstructed from Internal Constants: $list131 (arglist), $sym132 (STORE gensym),
;; $sym133 (PROB gensym), $sym134 (PROBLEM-STORE),
;; $sym135 (DO-PROBLEM-STORE-INFERENCES), $sym136 (PROBLEM-RELEVANT-TO-INFERENCE?)
(defmacro do-problem-relevant-inferences ((inference-var problem &key done) &body body)
  (with-temp-vars (store prob id)
    `(let* ((,prob ,problem)
            (,store (problem-store ,prob)))
       (do-problem-store-inferences (,id ,inference-var ,store ,@(when done `(:done ,done)))
         (when (problem-relevant-to-inference? ,prob ,inference-var)
           ,@body)))))


;;; Macro: do-problem-active-strategies
;; Reconstructed from Internal Constants: $list137 (arglist), $sym138 (STORE gensym),
;; $sym139 (PROB gensym), $sym140 (DO-PROBLEM-STORE-STRATEGIES),
;; $sym141 (PROBLEM-ACTIVE-IN-STRATEGY?)
(defmacro do-problem-active-strategies ((strategy-var problem) &body body)
  (with-temp-vars (store prob)
    `(let* ((,prob ,problem)
            (,store (problem-store ,prob)))
       (do-problem-store-strategies (,strategy-var ,store)
         (when (problem-active-in-strategy? ,prob ,strategy-var)
           ,@body)))))


;;; Macro: do-problem-relevant-strategies
;; Reconstructed from Internal Constants: $list142 (arglist), $sym143 (INFERENCE gensym),
;; $sym144 (DO-PROBLEM-RELEVANT-INFERENCES), $sym145 (DO-INFERENCE-STRATEGIES)
(defmacro do-problem-relevant-strategies ((strategy-var problem &key done) &body body)
  (with-temp-vars (inference)
    `(do-problem-relevant-inferences (,inference ,problem :done ,done)
       (do-inference-strategies (,strategy-var ,inference)
         ,@body))))


;;; Macro: do-problem-relevant-strategic-contexts
;; Reconstructed from Internal Constants: $list146 (arglist), $sym147 (PROGN),
;; $list148 (:TACTICAL), $sym149 (DO-PROBLEM-RELEVANT-STRATEGIES)
(defmacro do-problem-relevant-strategic-contexts ((strategic-context-var problem &key done)
                                                  &body body)
  `(progn
     (let ((,strategic-context-var :tactical))
       ,@body)
     (do-problem-relevant-strategies (,strategic-context-var ,problem :done ,done)
       ,@body)))


;;; Destruction

;; (defun destroy-problem (problem) ...) -- active declareFunction, no body

(defun destroy-problem-store-problem (problem)
  (when (valid-problem-p problem)
    (note-problem-invalid problem)
    (destroy-problem-int problem)))

(defun destroy-problem-int (problem)
  (clrhash (prob-proof-bindings-index problem))
  (setf (prob-argument-link-bindings-index problem) :free)
  (clrhash (prob-proof-bindings-index problem))
  (setf (prob-proof-bindings-index problem) :free)
  (dolist (tactic (problem-tactics problem))
    (destroy-problem-tactic tactic))
  (setf (prob-tactics problem) :free)
  (clear-set-contents (prob-dependent-links problem))
  (setf (prob-dependent-links problem) :free)
  (clear-set-contents (prob-argument-links problem))
  (setf (prob-argument-links problem) :free)
  (setf (prob-query problem) :free)
  (setf (prob-store problem) :free)
  nil)

(defun note-problem-invalid (problem)
  (setf (prob-status problem) :free)
  problem)


;;; Accessors

(defun problem-suid (problem)
  (declare (type problem problem))
  (prob-suid problem))

(defun problem-store (problem)
  (declare (type problem problem))
  (prob-store problem))

(defun problem-query (problem)
  (declare (type problem problem))
  (prob-query problem))

(defun problem-status (problem)
  (declare (type problem problem))
  (prob-status problem))

(defun set-problem-status (problem status)
  (declare (type problem problem))
  (setf (prob-status problem) status)
  problem)

;; (defun problem-formula (problem) ...) -- active declareFunction, no body
;; (defun problem-el-formula (problem) ...) -- active declareFunction, no body

(defun closed-problem-p (problem)
  "[Cyc] Return booleanp; whether PROBLEM contains no variables."
  (closed-problem-query-p (problem-query problem)))

;; (defun open-problem-p (problem) ...) -- active declareFunction, no body

(defun closed-problem-query-p (query)
  (hl-ground-tree-p query))

;; (defun open-problem-query-p (query) ...) -- active declareFunction, no body
;; (defun closed-single-literal-problem-query-p (query) ...) -- active declareFunction, no body
;; (defun open-single-literal-problem-query-p (query) ...) -- active declareFunction, no body

(defun problem-variables (problem)
  (problem-query-variables (problem-query problem)))

;; (defun problem-literal-count (problem &optional sense) ...) -- active declareFunction, no body
;; (defun problem-query-literal-count (query &optional sense) ...) -- active declareFunction, no body

(defun single-literal-problem-p (object)
  "[Cyc] Return boolean; whether OBJECT is a problem whose query consists of a single contextualized literal (either positive or negative)."
  (and (problem-p object)
       (problem-query-has-single-literal-p (problem-query object))))

(defun single-literal-problem-predicate (problem)
  "[Cyc] Assuming PROBLEM is a single-literal-problem-p, returns the predicate of its single contextualized literal."
  (single-literal-problem-query-predicate (problem-query problem)))

(defun single-literal-problem-atomic-sentence (problem)
  (single-literal-problem-query-atomic-sentence (problem-query problem)))

(defun single-literal-problem-mt (problem)
  (single-literal-problem-query-mt (problem-query problem)))

(defun single-literal-problem-sense (problem)
  "[Cyc] Return sense-p; Assumes PROBLEM is a single literal problem, and returns the problem's query's sense."
  (single-literal-problem-query-sense (problem-query problem)))

(defun mt-asent-sense-from-single-literal-problem (problem)
  "[Cyc] Return 0 mt, 1 atomic-sentence-p, 2 sense-p."
  (mt-asent-sense-from-singleton-query (problem-query problem)))

(defun single-clause-problem-p (object)
  (when (problem-p object)
    (single-clause-problem-query-p (problem-query object))))

;; (defun conjunctive-problem-p (object) ...) -- active declareFunction, no body

(defun ist-problem-p (object)
  (and (single-literal-problem-p object)
       (or (eq (reader-make-constant-shell "ist")
               (single-literal-problem-predicate object))
           (and (within-normal-forward-inference?)
                (not (eq *mt* (reader-make-constant-shell "InferencePSC")))))))

;; (defun join-problem-p (object) ...) -- active declareFunction, no body
;; (defun split-problem-p (object) ...) -- active declareFunction, no body

(defun multi-literal-problem-p (object)
  (and (single-clause-problem-p object)
       (not (single-literal-problem-p object))))

;; (defun disjunctive-problem-p (object) ...) -- active declareFunction, no body

(defun multi-clause-problem-p (object)
  (and (problem-p object)
       (not (single-clause-problem-p object))))

;; (defun multi-clause-problem-query-p (query) ...) -- active declareFunction, no body

(defun problem-sole-clause (problem)
  "[Cyc] Return contextualized-dnf-clause-p."
  (let ((query (problem-query problem)))
    (must (singleton? query) "The problem ~S did not have a single-clause query." problem)
    (problem-query-sole-clause query)))

(defun problem-query-sole-clause (query)
  (destructuring-bind (dnf-clause) query
    dnf-clause))

(defun problem-in-equality-reasoning-domain? (problem)
  (let ((query (problem-query problem))
        (store (problem-store problem))
        (equality-reasoning-domain (problem-store-equality-reasoning-domain store)))
    (problem-query-in-equality-reasoning-domain? query equality-reasoning-domain)))


;;; Relevance

;; (defun problem-relevant-to-some-inference? (problem) ...) -- active declareFunction, no body
;; (defun first-problem-relevant-inference (problem) ...) -- active declareFunction, no body
;; (defun problem-relevant-to-only-one-inference? (problem) ...) -- active declareFunction, no body

(defun problem-relevant-to-inference? (problem inference)
  (set-member? problem (inference-relevant-problems inference)))

(defun problem-relevant-to-strategy? (problem strategy)
  "[Cyc] Return boolean; t iff PROBLEM is relevant to STRATEGY's inference."
  (problem-relevant-to-inference? problem (strategy-inference strategy)))

;; (defun problem-relevant-strategies (problem) ...) -- active declareFunction, no body
;; (defun problem-active-in-some-strategy? (problem) ...) -- active declareFunction, no body
;; (defun first-problem-active-strategy (problem) ...) -- active declareFunction, no body
;; (defun problem-argument-link-count (problem) ...) -- active declareFunction, no body
;; (defun problem-argument-link-of-type-count (problem type) ...) -- active declareFunction, no body


;;; Argument links

(defun problem-has-argument-link-p (problem)
  "[Cyc] Return boolean; t iff PROBLEM has any argument (child) links."
  (not (set-contents-empty? (prob-argument-links problem))))

(defun problem-has-argument-link-of-type? (problem type)
  (and (problem-first-argument-link-of-type problem type) t))

(defun problem-first-argument-link-of-type (problem type)
  "[Cyc] Return nil or problem-link-p."
  (let ((first-link nil))
    (do-set (link (problem-argument-links problem))
      (when (and (problem-link-has-type? link type)
                 (null first-link))
        (setf first-link link)))
    first-link))

(defun problem-sole-argument-link-of-type (problem type)
  (let ((first-link nil))
    (do-set (link (problem-argument-links problem))
      (when (problem-link-has-type? link type)
        (if first-link
            (error "Found more than one ~a argument link on ~a" type problem)
            (setf first-link link))))
    (must first-link "Expected ~a to have a ~a argument link" problem type)
    first-link))

;; (defun problem-all-argument-links-have-type? (problem type) ...) -- active declareFunction, no body
;; (defun problem-has-supporting-problem-p (problem) ...) -- active declareFunction, no body
;; (defun all-problem-argument-problems (problem) ...) -- active declareFunction, no body
;; (defun all-problem-argument-problems-recursive (problem accumulator) ...) -- active declareFunction, no body


;;; Dependent links

;; (defun problem-dependent-link-count (problem) ...) -- active declareFunction, no body
;; (defun problem-sole-dependent-link (problem) ...) -- active declareFunction, no body
;; (defun problem-has-dependent-link-p (problem) ...) -- active declareFunction, no body

(defun problem-has-dependent-link-of-type? (problem type)
  (do-set (dependent-link (problem-dependent-links problem))
    (when (problem-link-has-type? dependent-link type)
      (return-from problem-has-dependent-link-of-type? t)))
  nil)

;; (defun problem-has-answer-link-p (problem) ...) -- active declareFunction, no body
;; (defun problem-has-non-answer-dependent-link-p (problem) ...) -- active declareFunction, no body
;; (defun problem-has-only-non-abducible-rule-transformation-dependent-links? (problem) ...) -- active declareFunction, no body
;; (defun problem-supported-problems (problem) ...) -- active declareFunction, no body
;; (defun problem-supported-problem-count (problem) ...) -- active declareFunction, no body


;;; Tactics

(defun problem-next-tactic-suid (problem)
  (problem-tactic-count problem))

(defun problem-tactic-count (problem)
  (let ((tactics (problem-tactics problem)))
    (if tactics
        (1+ (tactic-suid (first tactics)))
        0)))

;; (defun problem-tactic-count-with-hl-module (problem hl-module) ...) -- active declareFunction, no body
;; (defun problem-tactic-count-with-hl-module-and-status (problem hl-module status) ...) -- active declareFunction, no body
;; (defun problem-possible-tactics (problem) ...) -- active declareFunction, no body

(defun problem-has-possible-tactics? (problem)
  (declare (type problem problem))
  (and (find-if #'tactic-possible? (problem-tactics problem)) t))

(defun problem-no-tactics-possible? (problem)
  (not (problem-has-possible-tactics? problem)))

;; (defun problem-executed-tactics (problem) ...) -- active declareFunction, no body
;; (defun problem-discarded-tactics (problem) ...) -- active declareFunction, no body
;; (defun problem-possible-tactic-count (problem) ...) -- active declareFunction, no body
;; (defun problem-executed-tactic-count (problem) ...) -- active declareFunction, no body
;; (defun problem-discarded-tactic-count (problem) ...) -- active declareFunction, no body
;; (defun problem-tactic-of-type-with-status-count (problem &optional type status) ...) -- active declareFunction, no body
;; (defun problem-tactic-with-status-count (problem &optional status) ...) -- active declareFunction, no body

(defun problem-has-tactic-of-type-with-status? (problem type &optional status)
  (let ((found? nil))
    (dolist (tactic (problem-tactics problem))
      (when found? (return))
      (when (and (do-problem-tactics-type-match tactic type)
                 (do-problem-tactics-status-match tactic status))
        (setf found? t)))
    found?))

(defun problem-has-tactic-of-type? (problem type)
  (problem-has-tactic-of-type-with-status? problem type))

;; (defun problem-has-removal-tactics? (problem) ...) -- active declareFunction, no body

(defun problem-has-transformation-tactics? (problem)
  (problem-has-tactic-of-type? problem :transformation))

;; (defun problem-has-possible-transformation-tactics? (problem) ...) -- active declareFunction, no body

(defun problem-has-possible-removal-tactic? (problem strategic-context)
  (declare (type problem problem))
  (problem-has-tactic-of-type-with-status? problem :removal :possible))

(defun problem-has-complete-possible-removal-tactic? (problem strategic-context)
  (declare (type problem problem))
  (dolist (tactic (problem-tactics problem))
    (when (and (do-problem-tactics-type-match tactic :removal)
               (do-problem-tactics-status-match tactic :possible))
      (when (tactic-complete? tactic strategic-context)
        (return-from problem-has-complete-possible-removal-tactic? t))))
  nil)

(defun problem-has-split-tactics? (problem)
  (let ((found? nil))
    (dolist (tactic (problem-tactics problem))
      (when found? (return))
      (setf found? (split-tactic-p tactic)))
    found?))

;; (defun problem-has-an-in-progress-tactic? (problem) ...) -- active declareFunction, no body
;; (defun any-problem-has-an-in-progress-tactic? (problems) ...) -- active declareFunction, no body
;; (defun problem-has-no-logical-tactics? (problem) ...) -- active declareFunction, no body
;; (defun problem-total-removal-productivity (problem) ...) -- active declareFunction, no body
;; (defun problem-total-deductive-removal-productivity (problem) ...) -- active declareFunction, no body
;; (defun problem-total-actual-removal-productivity (problem) ...) -- active declareFunction, no body
;; (defun problem-possible-removal-tactics (problem) ...) -- active declareFunction, no body
;; (defun problem-executed-removal-tactic-productivities (problem) ...) -- active declareFunction, no body


;;; Proofs

;; (defun all-problem-proofs (problem &optional status) ...) -- active declareFunction, no body

(defun problem-proof-count (problem &optional proof-status)
  (let ((count 0))
    (maphash (lambda (v-bindings proof-list)
               (declare (ignore v-bindings))
               (dolist (proof proof-list)
                 (when (proof-has-status? proof proof-status)
                   (incf count))))
             (problem-proof-bindings-index problem))
    count))

;; (defun problem-proven-proof-count (problem) ...) -- active declareFunction, no body

(defun problem-has-some-proof? (problem &optional proof-status)
  (maphash (lambda (v-bindings proof-list)
             (declare (ignore v-bindings))
             (dolist (proof proof-list)
               (when (proof-has-status? proof proof-status)
                 (return-from problem-has-some-proof? t))))
           (problem-proof-bindings-index problem))
  nil)

(defun problem-has-some-proven-proof? (problem)
  (problem-has-some-proof? problem :proven))

;; (defun problem-has-some-rejected-proof? (problem) ...) -- active declareFunction, no body

(defun problem-proofs-lookup (problem v-bindings)
  "[Cyc] Return list-of-proof-p (possibly empty)."
  (gethash v-bindings (prob-proof-bindings-index problem)))

(defun problem-argument-links-lookup (problem v-bindings)
  "[Cyc] Return list-of-problem-link-p (possibly empty)."
  (gethash v-bindings (prob-argument-link-bindings-index problem)))

;; (defun problem-indestructible? (problem) ...) -- active declareFunction, no body
;; (defun problem-destructible? (problem) ...) -- active declareFunction, no body
;; (defun problem-destructibility-status (problem) ...) -- active declareFunction, no body
;; (defun problem-min-depth (problem) ...) -- active declareFunction, no body


;;; Depth tracking

(defun problem-min-proof-depth (problem inference)
  "[Cyc] Return non-negative-integer-p or :undetermined; the number of links on the shortest path between PROBLEM and INFERENCE."
  (let* ((store (problem-store problem))
         (hash (gethash inference (problem-store-min-proof-depth-index store))))
    (when hash
      (let ((depth (gethash problem hash)))
        (when (non-negative-integer-p depth)
          (return-from problem-min-proof-depth depth)))))
  :undetermined)

(defun problem-min-transformation-depth (problem inference)
  "[Cyc] Return non-negative-integer-p or :undetermined; the number of transformation links on the shortest path between PROBLEM and INFERENCE."
  (when *problem-min-transformation-depth-from-signature-enabled?*
    (return-from problem-min-transformation-depth
      (problem-min-transformation-depth-from-signature problem inference)))
  (let* ((store (problem-store problem))
         (hash (gethash inference (problem-store-min-transformation-depth-index store))))
    (when hash
      (let ((depth (gethash problem hash)))
        (when (non-negative-integer-p depth)
          (return-from problem-min-transformation-depth depth)))))
  :undetermined)

(defun problem-min-transformation-depth-signature (problem inference)
  "[Cyc] Return problem-query-depth-signature-p or :undetermined; a signature of the per-literal number of transformation links on the shortest path between PROBLEM and INFERENCE."
  (let* ((store (problem-store problem))
         (hash (gethash inference (problem-store-min-transformation-depth-signature-index store))))
    (when hash
      (let ((depth (gethash problem hash)))
        (when depth
          (return-from problem-min-transformation-depth-signature depth)))))
  :undetermined)


;;; Mutation — argument links

(defun add-problem-argument-link (problem argument-link)
  "[Cyc] Puts ARGUMENT-LINK below PROBLEM."
  (declare (type problem problem))
  (setf (prob-argument-links problem)
        (set-contents-add argument-link (prob-argument-links problem)))
  problem)

;; (defun remove-problem-argument-link (problem argument-link) ...) -- active declareFunction, no body

(defun index-problem-argument-link (problem argument-link)
  "[Cyc] Indexes argument-link by bindings for fast lookup. Used for removal and restriction links."
  (let* ((index (prob-argument-link-bindings-index problem))
         (v-bindings (cond ((removal-link-p argument-link)
                            (removal-link-bindings argument-link))
                           ((restriction-link-p argument-link)
                            (restriction-link-bindings argument-link))
                           (t nil)))
         (existing (gethash v-bindings index)))
    (setf (gethash v-bindings index) (cons argument-link existing)))
  problem)

(defun deindex-problem-argument-link (problem argument-link)
  (let* ((index (prob-argument-link-bindings-index problem))
         (v-bindings (cond ((removal-link-p argument-link)
                            (removal-link-bindings argument-link))
                           ((restriction-link-p argument-link)
                            (restriction-link-bindings argument-link))
                           (t nil)))
         (existing (gethash v-bindings index))
         (updated (delete-first argument-link existing #'eq)))
    (when (not (eq existing updated))
      (if (null updated)
          ;; missing-larkc 31609 is dictionary-contents-remove; in hash table terms, remhash
          (remhash v-bindings index)
          (setf (gethash v-bindings index) updated))))
  problem)


;;; Mutation — dependent links

(defun add-problem-dependent-link (problem dependent-link)
  "[Cyc] Puts DEPENDENT-LINK above PROBLEM."
  (declare (type problem problem))
  (setf (prob-dependent-links problem)
        (set-contents-add dependent-link (prob-dependent-links problem)))
  (increment-dependent-link-historical-count)
  (when (single-literal-problem-p problem)
    (increment-single-literal-problem-dependent-link-historical-count))
  problem)

(defun remove-problem-dependent-link (problem dependent-link)
  "[Cyc] Removes DEPENDENT-LINK from above PROBLEM."
  (declare (type problem problem))
  (setf (prob-dependent-links problem)
        (set-contents-delete dependent-link (prob-dependent-links problem)))
  problem)


;;; Mutation — tactics

(defun add-problem-tactic (problem tactic)
  (declare (type problem problem))
  (must (<= (problem-tactic-count problem) *max-problem-tactics*)
        "Tried to add ~s to ~s, which would result in more than ~s tactics on ~s"
        tactic problem *max-problem-tactics* problem)
  (setf (prob-tactics problem) (cons tactic (prob-tactics problem)))
  problem)

;; (defun remove-problem-tactic (problem tactic) ...) -- active declareFunction, no body


;;; Mutation — proofs

(defun add-problem-proof (problem proof)
  (declare (type problem problem))
  (let* ((index (prob-proof-bindings-index problem))
         (v-bindings (proof-bindings proof))
         (existing (gethash v-bindings index)))
    (setf (gethash v-bindings index) (cons proof existing)))
  problem)

;; (defun remove-problem-proof (problem proof) ...) -- active declareFunction, no body
;; (defun remove-problem-proof-with-bindings (problem proof bindings) ...) -- active declareFunction, no body


;;; Mutation — depth

;; (defun set-problem-min-depth (problem depth) ...) -- active declareFunction, no body

(defun set-problem-min-proof-depth (problem inference depth)
  "[Cyc] Primitively sets PROBLEM's proof depth wrt INFERENCE to DEPTH."
  (declare (type problem problem))
  (let* ((store (problem-store problem))
         (hash (gethash inference (problem-store-min-proof-depth-index store))))
    (unless hash
      (setf hash (make-hash-table :test #'eq
                                  :size (problem-store-problem-count store)))
      (setf (gethash inference (problem-store-min-proof-depth-index store)) hash))
    (setf (gethash problem hash) depth))
  problem)

;; (defun set-problem-min-transformation-depth (problem inference depth) ...) -- active declareFunction, no body

(defun set-problem-min-transformation-depth-signature (problem inference pqds)
  "[Cyc] Primitively sets PROBLEM's transformation depth signature wrt INFERENCE to PQDS."
  (declare (type problem problem))
  (let* ((store (problem-store problem))
         (hash (gethash inference (problem-store-min-transformation-depth-signature-index store))))
    (unless hash
      (setf hash (make-hash-table :test #'eq
                                  :size (problem-store-problem-count store)))
      (setf (gethash inference (problem-store-min-transformation-depth-signature-index store)) hash))
    (setf (gethash problem hash) pqds))
  (let ((depth (min-transformation-depth-from-signature pqds)))
    (inference-note-transformation-depth inference depth))
  problem)

(defun set-root-problem-min-transformation-depth-signature (problem inference)
  (let* ((problem-query (problem-query problem))
         (initial-pqds (new-initial-pqds problem-query)))
    (set-problem-min-transformation-depth-signature problem inference initial-pqds)))

;; (defun note-problem-indestructible (problem) ...) -- active declareFunction, no body
;; (defun note-problem-destructible (problem) ...) -- active declareFunction, no body

(defun note-problem-min-transformation-depth-signature (problem inference new-pqds)
  (let* ((old-pqds (problem-min-transformation-depth-signature problem inference))
         (updated-pqds (if (eq :undetermined old-pqds)
                           new-pqds
                           (pqds-merge old-pqds new-pqds))))
    (unless (equal old-pqds updated-pqds)
      (set-problem-min-transformation-depth-signature problem inference updated-pqds)
      (return-from note-problem-min-transformation-depth-signature t)))
  nil)


;;; Status queries

;; (defun problem-tactical-provability-status (problem) ...) -- active declareFunction, no body

(defun tactically-good-problem-p (problem)
  (good-problem-status-p (problem-status problem)))

(defun tactically-no-good-problem-p (problem)
  (no-good-problem-status-p (problem-status problem)))

;; (defun tactically-neutral-problem-p (problem) ...) -- active declareFunction, no body
;; (defun problem-tactical-status (problem) ...) -- active declareFunction, no body
;; (defun tactically-new-problem-p (problem) ...) -- active declareFunction, no body

(defun tactically-unexamined-problem-p (problem)
  (unexamined-problem-status-p (problem-status problem)))

(defun tactically-examined-problem-p (problem)
  (examined-problem-status-p (problem-status problem)))

(defun tactically-possible-problem-p (problem)
  (possible-problem-status-p (problem-status problem)))

(defun tactically-pending-problem-p (problem)
  (pending-problem-status-p (problem-status problem)))

(defun tactically-finished-problem-p (problem)
  (finished-problem-status-p (problem-status problem)))

;; (defun tactical-problem-p (problem) ...) -- active declareFunction, no body
;; (defun tactically-potentially-possible-problem-p (problem) ...) -- active declareFunction, no body
;; (defun tactically-not-potentially-possible-problem-p (problem) ...) -- active declareFunction, no body
;; (defun problem-store-all-modules (problem) ...) -- active declareFunction, no body


;;; Setup phase

(toplevel
  (register-macro-helper 'problem-tactics 'do-problem-tactics)
  (register-macro-helper 'do-problem-tactics-status-match 'do-problem-tactics)
  (register-macro-helper 'do-problem-tactics-completeness-match 'do-problem-tactics)
  (register-macro-helper 'do-problem-tactics-preference-level-match 'do-problem-tactics)
  (register-macro-helper 'do-problem-tactics-productivity-match 'do-problem-tactics)
  (register-macro-helper 'do-problem-tactics-hl-module-match 'do-problem-tactics)
  (register-macro-helper 'do-problem-tactics-type-match 'do-problem-tactics)
  (register-macro-helper 'problem-argument-links 'do-problem-argument-links)
  (register-macro-helper 'problem-dependent-links 'do-problem-dependent-links)
  (register-macro-helper 'problem-proof-bindings-index 'do-problem-proofs)
  (register-macro-helper 'proof-has-status? 'do-problem-proofs)
  (declare-defglobal '*empty-clauses*))
