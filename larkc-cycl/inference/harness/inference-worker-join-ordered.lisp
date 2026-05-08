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

;;; Defstruct: join-ordered-link-data
;; 3 slots: focal-proof-index, non-focal-proof-index, restricted-non-focal-link-index

(defstruct (join-ordered-link-data (:conc-name "JO-LINK-DATA-"))
  focal-proof-index
  non-focal-proof-index
  restricted-non-focal-link-index)

(defconstant *dtp-join-ordered-link-data* 'join-ordered-link-data)


(defun join-ordered-link-data-p (object)
  "[Cyc] Return T iff OBJECT is a join-ordered-link-data structure."
  ;; missing-larkc 36364 is the UnaryFunction version; this is the regular predicate
  (typep object 'join-ordered-link-data))

;; (defun valid-join-ordered-link-data-p (object) ...) -- active declareFunction, no body

(defun new-join-ordered-link-data ()
  (let ((data (make-join-ordered-link-data)))
    (setf (jo-link-data-focal-proof-index data)
          (new-dictionary #'equal))
    (setf (jo-link-data-non-focal-proof-index data)
          (new-dictionary #'equal))
    (setf (jo-link-data-restricted-non-focal-link-index data)
          (new-dictionary-contents 0 #'eq))
    data))

(defun join-ordered-link-p (object)
  (and (problem-link-p object)
       (eq :join-ordered (problem-link-type object))))

(defun maybe-new-join-ordered-link (supported-problem focal-supporting-mapped-problem
                                    non-focal-supporting-mapped-problem)
  "[Cyc] Return join-ordered-link-p, either the already existing one or a new one."
  (do-set (candidate-link (problem-argument-links supported-problem))
    (when (problem-link-has-type? candidate-link :join-ordered)
      (let ((candidate-mapped-problem (join-ordered-link-focal-mapped-problem candidate-link)))
        (when (mapped-problem-equal focal-supporting-mapped-problem candidate-mapped-problem)
          (return-from maybe-new-join-ordered-link candidate-link)))))
  (new-join-ordered-link supported-problem
                         focal-supporting-mapped-problem
                         non-focal-supporting-mapped-problem))

(defun new-join-ordered-link (supported-problem focal-supporting-mapped-problem
                              non-focal-supporting-mapped-problem)
  (declare (type mapped-problem-p focal-supporting-mapped-problem))
  (when non-focal-supporting-mapped-problem
    (check-type non-focal-supporting-mapped-problem mapped-problem-p))
  (let* ((link (new-problem-link :join-ordered supported-problem))
         (data (new-join-ordered-link-data)))
    (set-problem-link-data link data)
    (connect-supporting-mapped-problem-with-dependent-link
     focal-supporting-mapped-problem link)
    (when non-focal-supporting-mapped-problem
      (connect-supporting-mapped-problem-with-dependent-link
       non-focal-supporting-mapped-problem link))
    (propagate-problem-link link)
    link))

;; (defun destroy-join-ordered-link (join-ordered-link) ...) -- active declareFunction, no body

;;; Macros

;; Reconstructed from Internal Constants:
;; $list21 = ((bindings-var proof-var join-ordered-link) &body body)
;; $sym22=INDEX (gensym), $sym23=PROOF-LIST-VAR (gensym)
;; $sym24=CLET, $sym25=JOIN-ORDERED-LINK-FOCAL-PROOF-INDEX
;; $sym26=DO-DICTIONARY, $sym27=DO-LIST
;; Expansion: binds index to focal proof index, iterates via do-dictionary
;; getting proof lists, then iterates over each proof list
(defmacro do-join-ordered-link-focal-proofs ((bindings-var proof-var join-ordered-link)
                                             &body body)
  (with-temp-vars (index proof-list-var)
    `(let ((,index (join-ordered-link-focal-proof-index ,join-ordered-link)))
       (do-dictionary (,bindings-var ,proof-list-var ,index)
         (dolist (,proof-var ,proof-list-var)
           ,@body)))))

;; Reconstructed from Internal Constants:
;; $sym28=INDEX (gensym), $sym29=PROOF-LIST-VAR (gensym)
;; $sym30=JOIN-ORDERED-LINK-NON-FOCAL-PROOF-INDEX
;; Same structure as do-join-ordered-link-focal-proofs but with non-focal index
(defmacro do-join-ordered-link-non-focal-proofs ((bindings-var proof-var join-ordered-link)
                                                 &body body)
  (with-temp-vars (index proof-list-var)
    `(let ((,index (join-ordered-link-non-focal-proof-index ,join-ordered-link)))
       (do-dictionary (,bindings-var ,proof-list-var ,index)
         (dolist (,proof-var ,proof-list-var)
           ,@body)))))

;; Reconstructed from Internal Constants:
;; $list31 = ((restricted-non-focal-problem-var join-ordered-link &key done) &body body)
;; $sym35=LINK-VAR (gensym), $sym36=RESTRICTION-LINK (gensym)
;; $sym37=DO-PROBLEM-ARGUMENT-LINKS, $sym38=JOIN-ORDERED-LINK-NON-FOCAL-PROBLEM
;; $kw39=:TYPE, $kw40=:RESTRICTION, $sym41=PWHEN
;; $sym42=NON-FOCAL-RESTRICTION-LINK-WITH-CORRESPONDING-FOCAL-PROOF?
;; $sym43=PROBLEM-LINK-SOLE-SUPPORTING-PROBLEM
;; Expansion: iterates argument links of the non-focal problem with type :restriction,
;; filters by non-focal-restriction-link-with-corresponding-focal-proof?,
;; then binds the sole supporting problem
(defmacro do-join-ordered-link-restricted-non-focal-problems
    ((restricted-non-focal-problem-var join-ordered-link &key done) &body body)
  (with-temp-vars (link-var restriction-link)
    `(let ((,link-var ,join-ordered-link))
       (do-problem-argument-links (,restriction-link
                                   (join-ordered-link-non-focal-problem ,link-var)
                                   :type :restriction
                                   ,@(when done `(:done ,done)))
         (when (non-focal-restriction-link-with-corresponding-focal-proof?
                ,restriction-link ,link-var)
           (let ((,restricted-non-focal-problem-var
                   (problem-link-sole-supporting-problem ,restriction-link)))
             ,@body))))))

;; Reconstructed from Internal Constants:
;; $list44 = ((join-ordered-link-var restricted-non-focal-problem &key done) &body body)
;; $sym45=RESTRICTION-LINK (gensym), $sym46=NON-FOCAL-PROBLEM (gensym)
;; $sym47=DO-PROBLEM-DEPENDENT-LINKS, $sym48=PROBLEM-LINK-SUPPORTED-PROBLEM
;; $sym49=JOIN-ORDERED-LINK-RESTRICTED-NON-FOCAL-LINK?
;; Expansion: iterates dependent links of the restricted non-focal problem with type :join-ordered,
;; filters by join-ordered-link-restricted-non-focal-link?
(defmacro do-virtual-dependent-join-ordered-links
    ((join-ordered-link-var restricted-non-focal-problem &key done) &body body)
  (with-temp-vars (restriction-link non-focal-problem)
    `(let ((,non-focal-problem ,restricted-non-focal-problem))
       (do-problem-dependent-links (,restriction-link ,non-focal-problem
                                    :type :restriction
                                    ,@(when done `(:done ,done)))
         (let ((,join-ordered-link-var (problem-link-supported-problem ,restriction-link)))
           (when (join-ordered-link-restricted-non-focal-link?
                  ,join-ordered-link-var ,restriction-link)
             ,@body))))))

;;; Accessor functions

(defun join-ordered-link-focal-proof-index (join-ordered-link)
  (jo-link-data-focal-proof-index (problem-link-data join-ordered-link)))

(defun join-ordered-link-non-focal-proof-index (join-ordered-link)
  (jo-link-data-non-focal-proof-index (problem-link-data join-ordered-link)))

(defun join-ordered-link-restricted-non-focal-link-index (join-ordered-link)
  (jo-link-data-restricted-non-focal-link-index (problem-link-data join-ordered-link)))

;; (defun join-ordered-link-triggered-restriction-link (join-ordered-link trigger-proof) ...) -- active declareFunction, no body
;; (defun join-ordered-link-triggered-restricted-non-focal (join-ordered-link trigger-proof) ...) -- active declareFunction, no body

(defun join-ordered-link-restricted-non-focal-links (join-ordered-link)
  (dictionary-contents-keys
   (join-ordered-link-restricted-non-focal-link-index join-ordered-link)))

(defun join-ordered-link-restricted-non-focal-triggering-proof (join-ordered-link
                                                                restriction-link)
  "[Cyc] The proof that, when bubbling up to JOIN-ORDERED-LINK, triggered the creation of RESTRICTION-LINK"
  (let* ((dict-contents (join-ordered-link-restricted-non-focal-link-index join-ordered-link))
         (proof (dictionary-contents-lookup dict-contents restriction-link #'eq)))
    (when (valid-proof-p proof)
      proof)))

(defun join-ordered-link-focal-mapped-problem (join-ordered-link)
  (first (last (problem-link-supporting-mapped-problems join-ordered-link))))

(defun join-ordered-link-has-non-focal-mapped-problem? (join-ordered-link)
  (doubleton? (problem-link-supporting-mapped-problems join-ordered-link)))

(defun join-ordered-link-non-focal-mapped-problem (join-ordered-link)
  (if (join-ordered-link-non-focal-manifested? join-ordered-link)
      (first (problem-link-supporting-mapped-problems join-ordered-link))
      (lazily-create-join-ordered-link-non-focal-mapped-problem join-ordered-link)))

(defun join-ordered-link-non-focal-manifested? (join-ordered-link)
  (doubleton? (problem-link-supporting-mapped-problems join-ordered-link)))

(defun join-ordered-link-focal-problem (join-ordered-link)
  (mapped-problem-problem (join-ordered-link-focal-mapped-problem join-ordered-link)))

(defun join-ordered-link-non-focal-problem (join-ordered-link)
  (mapped-problem-problem (join-ordered-link-non-focal-mapped-problem join-ordered-link)))

;; (defun join-ordered-link-other-mapped-problem (join-ordered-link mapped-problem) ...) -- active declareFunction, no body

(defun join-ordered-link-focal-proofs-lookup (join-ordered-link proof-bindings)
  (let* ((index (join-ordered-link-focal-proof-index join-ordered-link))
         (canonical-proof-bindings (canonicalize-proof-bindings proof-bindings))
         (focal-proofs (gethash canonical-proof-bindings index)))
    focal-proofs))

(defun join-ordered-link-non-focal-proofs-lookup (join-ordered-link proof-bindings)
  (let* ((index (join-ordered-link-non-focal-proof-index join-ordered-link))
         (canonical-proof-bindings (canonicalize-proof-bindings proof-bindings))
         (non-focal-proofs (gethash canonical-proof-bindings index)))
    non-focal-proofs))

(defun join-ordered-link-tactic (join-ordered-link)
  "[Cyc] Return tactic-p; the tactic which created JOIN-ORDERED-LINK"
  (let ((supported-problem (problem-link-supported-problem join-ordered-link)))
    (do-problem-tactics (join-ordered-tactic supported-problem
                         :hl-module *join-ordered-module*)
      (when (eq join-ordered-link (join-ordered-tactic-link join-ordered-tactic))
        (return-from join-ordered-link-tactic join-ordered-tactic)))
    (unless (tactically-unexamined-problem-p supported-problem)
      (error "Could not find the tactic for ~a" join-ordered-link))
    nil))

(defun join-ordered-link-restricted-non-focal-link? (join-ordered-link restriction-link)
  "[Cyc] Return booleanp; true iff RESTRICTION-LINK is a restricted non-focal link of JOIN-ORDERED-LINK"
  (member restriction-link
          (join-ordered-link-restricted-non-focal-links join-ordered-link)
          :test #'eq))

;; (defun join-ordered-link-restricted-non-focal-count (join-ordered-link) ...) -- active declareFunction, no body

(defun add-join-ordered-link-focal-proof (join-ordered-link v-bindings proof)
  "[Cyc] Indexes PROOF by BINDINGS as a focal proof in JOIN-ORDERED-LINK"
  (declare (type join-ordered-link-p join-ordered-link))
  (declare (type proof-p proof))
  (let ((index (join-ordered-link-focal-proof-index join-ordered-link))
        (canonical-bindings (canonicalize-proof-bindings v-bindings)))
    (dictionary-push index canonical-bindings proof))
  join-ordered-link)

;; (defun remove-join-ordered-link-focal-proof (join-ordered-link v-bindings proof) ...) -- active declareFunction, no body

(defun add-join-ordered-link-non-focal-proof (join-ordered-link v-bindings proof)
  "[Cyc] Indexes PROOF by BINDINGS as a non-focal proof in JOIN-ORDERED-LINK"
  (declare (type join-ordered-link-p join-ordered-link))
  (declare (type proof-p proof))
  (let ((index (join-ordered-link-non-focal-proof-index join-ordered-link))
        (canonical-bindings (canonicalize-proof-bindings v-bindings)))
    (dictionary-push index canonical-bindings proof))
  join-ordered-link)

;; (defun remove-join-ordered-link-non-focal-proof (join-ordered-link v-bindings proof) ...) -- active declareFunction, no body

(defun add-join-ordered-link-restricted-non-focal-link (join-ordered-link
                                                        restriction-link
                                                        trigger-proof)
  (declare (type join-ordered-link-p join-ordered-link))
  (declare (type restriction-link-p restriction-link))
  (declare (type proof-p trigger-proof))
  (let ((dict-contents (join-ordered-link-restricted-non-focal-link-index join-ordered-link)))
    (setf dict-contents (dictionary-contents-enter dict-contents restriction-link
                                                   trigger-proof #'eq))
    (setf (jo-link-data-restricted-non-focal-link-index
           (problem-link-data join-ordered-link))
          dict-contents))
  join-ordered-link)

;; (defun remove-join-ordered-link-restricted-non-focal-link (join-ordered-link restriction-link) ...) -- active declareFunction, no body

(defun join-ordered-link-focal-supporting-problem-spec (join-ordered-link)
  "[Cyc] Return subclause-spec-p or nil; the subclause-spec for the focal problem of JOIN-ORDERED-LINK"
  (let ((supported-problem (problem-link-supported-problem join-ordered-link)))
    (do-problem-tactics (join-ordered-tactic supported-problem
                         :hl-module *join-ordered-module*)
      (when (eq join-ordered-link (join-ordered-tactic-link join-ordered-tactic))
        (return-from join-ordered-link-focal-supporting-problem-spec
          (join-ordered-tactic-focal-supporting-problem-spec join-ordered-tactic))))
    nil))

(defun join-ordered-link-non-focal-supporting-problem-spec (join-ordered-link)
  "[Cyc] Return subclause-spec-p or nil; the subclause-spec for the non-focal problem of JOIN-ORDERED-LINK"
  (let* ((focal-spec (join-ordered-link-focal-supporting-problem-spec join-ordered-link))
         (supported-problem (problem-link-supported-problem join-ordered-link))
         (supported-clause (problem-sole-clause supported-problem))
         (non-focal-spec (new-complement-subclause-spec focal-spec supported-clause)))
    non-focal-spec))

;;; Tactic functions

(defparameter *join-ordered-module*
  (inference-structural-module :join-ordered))

(defun join-ordered-tactic-p (object)
  (and (tactic-p object)
       (eq *join-ordered-module* (tactic-hl-module object))))

(defun single-focal-literal-join-ordered-tactic-p (join-ordered-tactic)
  (and (join-ordered-tactic-p join-ordered-tactic)
       (single-literal-subclause-spec?
        (join-ordered-tactic-focal-supporting-problem-spec join-ordered-tactic))))

(defun new-join-ordered-tactic (jo-link focal-supporting-problem-spec)
  "[Cyc] Create a new :JOIN-ORDERED tactic for PROBLEM in which FOCAL-SUPPORTING-PROBLEM-SPEC
specifies the literals of DNF-CLAUSE which should be the focal supporting problem
and the remaining literals should be the non-focal supporting problem."
  (declare (type join-ordered-link-p jo-link))
  (let* ((problem (problem-link-supported-problem jo-link))
         (data (list jo-link focal-supporting-problem-spec))
         (tactic (new-tactic problem *join-ordered-module* data)))
    (do-problem-relevant-strategies (strategy problem)
      (strategy-note-new-tactic strategy tactic))
    tactic))

(defun join-ordered-tactic-link (join-ordered-tactic)
  "[Cyc] Return nil or problem-link-p; the link created by JOIN-ORDERED-TACTIC.
NIL should only occur if the tactic has been discarded."
  (first (tactic-data join-ordered-tactic)))

(defun join-ordered-tactic-focal-supporting-problem-spec (join-ordered-tactic)
  (second (tactic-data join-ordered-tactic)))

;; (defun join-ordered-tactic-subsumes? (tactic1 tactic2) ...) -- active declareFunction, no body

(defun find-or-create-join-ordered-tactic-focal-mapped-problem (tactic)
  (let ((jo-link (join-ordered-tactic-link tactic)))
    (when jo-link
      (join-ordered-link-focal-mapped-problem jo-link))))

;; (defun find-or-create-join-ordered-tactic-non-focal-mapped-problem (tactic) ...) -- active declareFunction, no body

;;; Tactic determination

(defparameter *only-add-multi-literal-jo-tactics-when-no-possible-complete-tactic?* nil
  "[Cyc] When a problem has a candidate early removal tactic--one that's join-ordered, who's
lookahead problem is complete, and is cheap--don't bother looking for multi literal join
ordered tactics (conjunctive removal jo tactics)")

(defun determine-new-join-ordered-tactics (supported-problem dnf-clause)
  (unless (problem-has-a-complete-conjunctive-removal-tactic? supported-problem)
    (determine-new-single-literal-join-ordered-tactics supported-problem dnf-clause)
    (let ((multi-literal-subclause-specs nil))
      (dolist (subclause-spec (motivated-followup-multi-literal-subclause-specs-case-1
                               supported-problem dnf-clause))
        (unless (member subclause-spec multi-literal-subclause-specs :test #'eql)
          (push subclause-spec multi-literal-subclause-specs)))
      (dolist (subclause-spec (motivated-followup-multi-literal-subclause-specs-case-2
                               supported-problem dnf-clause))
        (unless (member subclause-spec multi-literal-subclause-specs :test #'eql)
          (push subclause-spec multi-literal-subclause-specs)))
      (unless (and *only-add-multi-literal-jo-tactics-when-no-possible-complete-tactic?*
                   ;; Likely checks if there's a candidate early removal tactic
                   (missing-larkc 36377))
        (dolist (subclause-spec (motivated-multi-literal-subclause-specs dnf-clause))
          (unless (member subclause-spec multi-literal-subclause-specs :test #'eql)
            (push subclause-spec multi-literal-subclause-specs))))
      (dolist (subclause-spec (nreverse multi-literal-subclause-specs))
        (determine-new-join-ordered-tactic supported-problem subclause-spec dnf-clause))))
  nil)

(defun problem-has-a-complete-conjunctive-removal-tactic? (problem)
  (do-problem-tactics (tactic problem
                       :type :removal-conjunctive :completeness :complete)
    (return-from problem-has-a-complete-conjunctive-removal-tactic? t))
  nil)

;; (defun problem-has-a-candidate-early-removal-tactic? (problem) ...) -- active declareFunction, no body

(defun determine-new-single-literal-join-ordered-tactics (supported-problem dnf-clause)
  (let ((some-backchain-required? (inference-some-backchain-required-asent-in-clause? dnf-clause)))
    (let ((index 0))
      (dolist (contextualized-asent (neg-lits dnf-clause))
        (when (or (not some-backchain-required?)
                  (inference-backchain-required-contextualized-asent?
                   contextualized-asent))
          (determine-new-single-literal-join-ordered-tactic
           supported-problem dnf-clause :neg index))
        (incf index)))
    (let ((index 0))
      (dolist (contextualized-asent (pos-lits dnf-clause))
        (when (or (not some-backchain-required?)
                  (inference-backchain-required-contextualized-asent?
                   contextualized-asent))
          (determine-new-single-literal-join-ordered-tactic
           supported-problem dnf-clause :pos index))
        (incf index))))
  nil)

(defun determine-new-single-literal-join-ordered-tactic (supported-problem dnf-clause
                                                         sense index)
  (let ((focal-supporting-problem-spec (new-single-literal-subclause-spec sense index)))
    (determine-new-join-ordered-tactic supported-problem focal-supporting-problem-spec
                                       dnf-clause)))

(defun motivated-followup-multi-literal-subclause-specs-case-1 (supported-problem dnf-clause)
  "[Cyc] Return list of subclause-spec-p; multi-literal subclause specs that should be considered
for the purpose of reusing existing work in the store."
  (let ((subclause-specs nil))
    (when (problem-store-followup-query-problem-p supported-problem)
      (let ((store (problem-store supported-problem)))
        (do-set (other-root-problem (problem-store-historical-root-problems store))
          (when (and (not (eq other-root-problem supported-problem))
                     (multi-literal-problem-p other-root-problem))
            (let ((other-dnf-clause (problem-sole-clause other-root-problem)))
              (dolist (subclause-spec (matching-subclause-specs dnf-clause other-dnf-clause))
                (unless (member subclause-spec subclause-specs :test #'equal)
                  (push subclause-spec subclause-specs))))))))
    subclause-specs))

(defun problem-store-followup-query-problem-p (supported-problem)
  "[Cyc] Return booleanp; whether SUPPORTED-PROBLEM should be considered for followup-query
join-ordered links. Currently we only do this analysis for root problems when
there is at least one other root problem in the store."
  (and (problem-p supported-problem)
       (>= (problem-store-historical-root-problem-count
            (problem-store supported-problem))
           2)
       (problem-has-dependent-link-of-type? supported-problem :answer)))

(defun motivated-followup-multi-literal-subclause-specs-case-2 (supported-problem dnf-clause)
  (let ((subclause-specs nil))
    (when (not (inference-some-backchain-required-asent-in-clause? dnf-clause))
      (when (problem-has-dependent-link-of-type? supported-problem :union)
        (do-set (union-link (problem-dependent-links supported-problem))
          (when (problem-link-has-type? union-link :union)
            (let ((disjunction-problem (problem-link-supported-problem union-link)))
              (do-set (sibling-union-link (problem-argument-links disjunction-problem))
                (when (and (problem-link-has-type? sibling-union-link :union)
                           (not (eq sibling-union-link union-link)))
                  (let ((sibling-problem (problem-link-sole-supporting-problem
                                          sibling-union-link)))
                    (when (and (not (eq sibling-problem supported-problem))
                               (multi-literal-problem-p sibling-problem))
                      (let ((other-dnf-clause (problem-sole-clause sibling-problem)))
                        ;; Likely computes sub-matching-subclause-specs
                        (dolist (subclause-spec (missing-larkc 36382))
                          (let ((subclause (subclause-specified-by-spec
                                            other-dnf-clause subclause-spec)))
                            (when (all-literals-connected-by-shared-vars? subclause)
                              (unless (member subclause-spec subclause-specs :test #'equal)
                                (push subclause-spec subclause-specs)))))))))))))))
    subclause-specs))

(defun matching-subclause-specs (dnf-clause other-dnf-clause)
  "[Cyc] Returns the subclause specs which, if applied to DNF-CLAUSE, would allow it to unify with OTHER-DNF-CLAUSE."
  (let ((subclause-specs nil)
        (pos-lits (pos-lits dnf-clause))
        (neg-lits (neg-lits dnf-clause))
        (other-pos-lits (pos-lits other-dnf-clause))
        (other-neg-lits (neg-lits other-dnf-clause)))
    (when (and (greater-or-same-length-p pos-lits other-pos-lits)
               (greater-or-same-length-p neg-lits other-neg-lits)
               (or (greater-length-p pos-lits other-pos-lits)
                   (greater-length-p neg-lits other-neg-lits)))
      ;; Likely builds an index dictionary mapping lits to indices
      (let ((pos-dict (missing-larkc 36369)))
        (when pos-dict
          ;; Likely builds neg index dictionary
          (let ((neg-dict (missing-larkc 36370)))
            (when neg-dict
              ;; Likely extracts list of positive index combinations
              (let ((positive-indices-list (missing-larkc 36371))
                    ;; Likely extracts list of negative index combinations
                    (negative-indices-list (missing-larkc 36372)))
                (dolist (positive-indices positive-indices-list)
                  (dolist (negative-indices negative-indices-list)
                    (let* ((candidate-subclause-spec
                             (new-subclause-spec negative-indices positive-indices))
                           (candidate-subclause
                             (subclause-specified-by-spec dnf-clause
                                                          candidate-subclause-spec)))
                      (when (unify candidate-subclause other-dnf-clause)
                        (push candidate-subclause-spec subclause-specs)))))))))))
    subclause-specs))

;; (defun matching-subclause-index-dictionary (lits other-lits) ...) -- active declareFunction, no body
;; (defun matching-subclause-index-dictionary-to-indices-list (dict) ...) -- active declareFunction, no body
;; (defun sub-matching-subclause-specs (dnf-clause other-dnf-clause) ...) -- active declareFunction, no body

(defun determine-new-join-ordered-tactic (supported-problem focal-supporting-problem-spec
                                          dnf-clause)
  (let* ((store (problem-store supported-problem))
         (focal-mapped-problem (find-or-create-join-ordered-focal-mapped-problem
                                store dnf-clause focal-supporting-problem-spec))
         (non-focal-mapped-problem nil)
         (jo-link (maybe-new-join-ordered-link supported-problem
                                               focal-mapped-problem
                                               non-focal-mapped-problem)))
    (new-join-ordered-tactic jo-link focal-supporting-problem-spec))
  nil)

(defun find-or-create-join-ordered-focal-mapped-problem (store dnf-clause
                                                         focal-supporting-problem-spec)
  (find-or-create-problem-from-subclause-spec store dnf-clause
                                               focal-supporting-problem-spec))

(defun find-or-create-join-ordered-non-focal-mapped-problem (store dnf-clause
                                                             focal-supporting-problem-spec)
  (find-or-create-problem-without-subclause-spec store dnf-clause
                                                  focal-supporting-problem-spec))

(defun lazily-create-join-ordered-link-non-focal-mapped-problem (join-ordered-link)
  (unless *problem-store-modification-permitted?*
    (return-from lazily-create-join-ordered-link-non-focal-mapped-problem nil))
  (let* ((focal-open?
           (problem-link-sole-supporting-mapped-problem-open? join-ordered-link))
         (store (problem-link-store join-ordered-link))
         (supported-clause
           (problem-sole-clause
            (problem-link-supported-problem join-ordered-link)))
         (focal-mapped-problem
           (join-ordered-link-focal-mapped-problem join-ordered-link))
         (focal-problem
           (mapped-problem-problem focal-mapped-problem))
         (focal-clause (problem-sole-clause focal-problem))
         (focal-variable-map
           (mapped-problem-variable-map focal-mapped-problem))
         (focal-clause-wrt-supported
           (apply-bindings focal-variable-map focal-clause))
         (focal-supporting-problem-spec
           (subclause-spec-from-clauses supported-clause focal-clause-wrt-supported))
         (non-focal-supporting-mapped-problem
           (find-or-create-join-ordered-non-focal-mapped-problem
            store supported-clause focal-supporting-problem-spec)))
    (connect-supporting-mapped-problem-with-dependent-link
     non-focal-supporting-mapped-problem join-ordered-link)
    (when focal-open?
      (problem-link-close-all join-ordered-link)
      (problem-link-open-supporting-mapped-problem join-ordered-link focal-mapped-problem))
    (propagate-problem-link join-ordered-link)
    non-focal-supporting-mapped-problem))

;;; Strategic properties

(defun compute-strategic-properties-of-join-ordered-tactic (tactic strategy)
  (let ((jo-link (join-ordered-tactic-link tactic)))
    (unless (preference-level-p (tactic-preference-level tactic))
      (multiple-value-bind (join-ordered-preference-level preference-level-justification)
          (compute-join-ordered-tactic-preference-level jo-link :tactical)
        (set-tactic-preference-level tactic join-ordered-preference-level
                                     preference-level-justification)))
    (multiple-value-bind (preference-level justification)
        (compute-join-ordered-tactic-preference-level jo-link strategy)
      (set-tactic-strategic-preference-level tactic strategy preference-level justification))
    (let ((productivity (compute-join-ordered-tactic-productivity jo-link strategy)))
      (set-tactic-strategic-productivity tactic strategy productivity)))
  tactic)

(defun compute-join-ordered-tactic-productivity (jo-link strategy)
  "[Cyc] The productivity of a :join-ordered tactic is twice the
productivity of its focal subproblem"
  (declare (type join-ordered-link-p jo-link))
  (declare (type strategy-p strategy))
  (memoized-problem-max-removal-productivity
   (join-ordered-link-focal-problem jo-link) strategy))

(defun compute-join-ordered-tactic-preference-level (jo-link strategic-context)
  (let* ((focal-problem (join-ordered-link-focal-problem jo-link))
         (shared-variables (focal-vars-shared-by-non-focal jo-link)))
    (multiple-value-bind (join-ordered-preference-level preference-level-justification)
        (memoized-problem-global-preference-level focal-problem strategic-context
                                                   shared-variables)
      (values join-ordered-preference-level preference-level-justification))))

;;; Tactic execution

(defun execute-join-ordered-tactic (tactic)
  (let ((focal-mapped-problem (find-or-create-join-ordered-tactic-focal-mapped-problem tactic))
        (join-ordered-link (join-ordered-tactic-link tactic)))
    (problem-link-open-and-repropagate-supporting-mapped-problem
     join-ordered-link focal-mapped-problem)
    (maybe-possibly-add-residual-transformation-links-via-join-ordered-link
     join-ordered-link))
  (when (tactic-preferred? tactic :tactical)
    (unless (and (better-term-chosen-handling?)
                 (problem-store-transformation-allowed?
                  (tactic-store tactic)))
      (discard-all-other-possible-structural-conjunctive-tactics tactic)))
  (consider-strategic-ramifications-of-tactic-preference-level tactic)
  tactic)

(defun consider-strategic-ramifications-of-tactic-preference-level (tactic)
  (let ((problem (tactic-problem tactic)))
    (do-problem-relevant-strategies (strategy problem)
      (when (tactic-strategically-preferred? tactic strategy)
        (possibly-note-problem-pending (tactic-problem tactic) strategy))))
  nil)

(defun join-ordered-tactic-lookahead-problem (join-ordered-tactic)
  (let ((focal-mapped-problem
          (find-or-create-join-ordered-tactic-focal-mapped-problem join-ordered-tactic)))
    (mapped-problem-problem focal-mapped-problem)))

;;; Proofs

(defun new-join-ordered-proof (join-ordered-link subproofs-with-sub-bindings)
  "[Cyc] Return 0 proof-p, 1 whether the returned proof was newly created"
  (new-conjunctive-proof join-ordered-link subproofs-with-sub-bindings))

(defun join-ordered-proof-p (object)
  (and (proof-p object)
       (eq :join-ordered (proof-type object))))

(defun connected-conjunction-proof-p (object)
  (or (join-ordered-proof-p object)
      (join-proof-p object)))

(defun new-conjunctive-proof (conjunctive-link subproofs-with-sub-bindings)
  (let ((proof-bindings nil)
        (subproofs nil))
    (dolist (subproof-with-sub-bindings subproofs-with-sub-bindings)
      (destructuring-bind (subproof . sub-proof-bindings) subproof-with-sub-bindings
        (setf proof-bindings (nconc (copy-list sub-proof-bindings) proof-bindings))
        (push subproof subproofs)))
    (setf subproofs (nreverse subproofs))
    (setf proof-bindings (ncanonicalize-proof-bindings proof-bindings))
    (propose-new-proof-with-bindings conjunctive-link proof-bindings subproofs)))

;;; Variable maps

(defun compute-sibling-proof-bindings (trigger-proof-bindings join-ordered-link
                                       trigger-is-focal?)
  "[Cyc] TRIGGER-PROOF-BINDINGS; trigger problem's variables -> answers"
  (let ((trigger-to-sibling-variable-map
          (trigger-to-sibling-variable-map join-ordered-link trigger-is-focal?)))
    (transfer-variable-map-to-bindings-filtered trigger-to-sibling-variable-map
                                                trigger-proof-bindings)))

(defun-memoized focal-to-non-focal-variable-map (join-ordered-link) (:test eq)
  (let* ((focal-mapped-problem (join-ordered-link-focal-mapped-problem join-ordered-link))
         (non-focal-mapped-problem (join-ordered-link-non-focal-mapped-problem join-ordered-link))
         (focal-variable-map (mapped-problem-variable-map focal-mapped-problem))
         (non-focal-variable-map (mapped-problem-variable-map non-focal-mapped-problem))
         (supported-to-non-focal-variable-map (invert-bindings non-focal-variable-map))
         (focal-to-non-focal-variable-map
           (compose-bindings-filtered focal-variable-map
                                      supported-to-non-focal-variable-map)))
    focal-to-non-focal-variable-map))

(defun-memoized non-focal-to-focal-variable-map (join-ordered-link) (:test eq)
  (invert-bindings (focal-to-non-focal-variable-map join-ordered-link)))

(defun trigger-to-sibling-variable-map (join-ordered-link trigger-is-focal?)
  (if trigger-is-focal?
      (focal-to-non-focal-variable-map join-ordered-link)
      (non-focal-to-focal-variable-map join-ordered-link)))

(defun focal-bindings-to-non-focal-bindings (focal-restriction-bindings join-ordered-link)
  "[Cyc] Return binding-list-p; non-focal-problem-vars -> restriction.
i.e. a transformation of FOCAL-BINDINGS
into the space of JOIN-ORDERED-LINK's non-focal-problem.
These will be bindings to substitute into JOIN-ORDERED-LINK's non-focal-problem
to restrict it."
  (let ((focal-to-non-focal-variable-map
          (focal-to-non-focal-variable-map join-ordered-link)))
    (transfer-variable-map-to-bindings-filtered focal-to-non-focal-variable-map
                                                focal-restriction-bindings)))

;; (defun non-focal-bindings-to-focal-bindings (non-focal-restriction-bindings join-ordered-link) ...) -- active declareFunction, no body

;;; Proof bubbling

(defun bubble-up-proof-to-join-ordered-link (trigger-subproof variable-map join-ordered-link)
  (let ((trigger-is-focal? (mapped-proof-is-focal? trigger-subproof variable-map
                                                    join-ordered-link)))
    (add-join-ordered-link-proof join-ordered-link trigger-subproof trigger-is-focal?)
    (if (not trigger-is-focal?)
        (bubble-up-proof-to-join-ordered-link-int trigger-subproof variable-map
                                                   join-ordered-link trigger-is-focal?)
        (let ((restricted-non-focal-mapped-problem
                (trigger-split-restriction join-ordered-link trigger-subproof)))
          (bubble-up-proof-to-join-ordered-link-int trigger-subproof variable-map
                                                     join-ordered-link trigger-is-focal?)
          (when restricted-non-focal-mapped-problem
            (let* ((restricted-non-focal-problem
                     (mapped-problem-problem restricted-non-focal-mapped-problem))
                   (supported-problem
                     (problem-link-supported-problem join-ordered-link)))
              (do-problem-relevant-strategies (strategy supported-problem)
                (maybe-possibly-activate-problem strategy restricted-non-focal-problem)))))))
  nil)

(defun trigger-split-restriction (join-ordered-link focal-problem-proof)
  (unless (focal-problem-is-a-single-literal-backchain-required? join-ordered-link)
    (find-or-create-split-restriction-int join-ordered-link focal-problem-proof t)))

;; (defun find-split-restriction (join-ordered-link focal-problem-proof) ...) -- active declareFunction, no body

(defun find-or-create-split-restriction-int (join-ordered-link focal-problem-proof create?)
  "[Cyc] Return mapped-problem-p; a restricted form of JOIN-ORDERED-LINK's non-focal problem,
restricted according to FOCAL-RESTRICTION-BINDINGS modulo some substitution,
with a variable map of the form: restricted non-focal problem vars -> non-focal problem vars"
  (let* ((focal-restriction-bindings (proof-bindings focal-problem-proof))
         (non-focal-restriction-bindings
           (focal-bindings-to-non-focal-bindings focal-restriction-bindings join-ordered-link)))
    (multiple-value-bind (restricted-non-focal-mapped-problem restricted-non-focal-link)
        (find-or-create-restricted-non-focal-problem-int
         join-ordered-link non-focal-restriction-bindings create?)
      (when restricted-non-focal-link
        (add-join-ordered-link-restricted-non-focal-link
         join-ordered-link restricted-non-focal-link focal-problem-proof))
      restricted-non-focal-mapped-problem)))

(defun note-all-triggering-proofs-processed (restriction-link)
  (let ((supported-problem (problem-link-supported-problem restriction-link)))
    (do-set (join-ordered-link (problem-dependent-links supported-problem))
      (when (problem-link-has-type? join-ordered-link :join-ordered)
        (note-restricted-non-focal-finished join-ordered-link restriction-link))))
  nil)

(defun note-restricted-non-focal-finished (join-ordered-link restriction-link)
  "[Cyc] look up the proof from the index on the jo-link and note it processed"
  (let ((proof (join-ordered-link-restricted-non-focal-triggering-proof
                join-ordered-link restriction-link)))
    (when proof
      (possibly-note-proof-processed proof)))
  nil)

;;; Restricted problem functions

;; (defun find-or-create-restricted-non-focal-problem (join-ordered-link non-focal-restriction-bindings) ...) -- active declareFunction, no body
;; (defun find-restricted-non-focal-problem (join-ordered-link non-focal-restriction-bindings) ...) -- active declareFunction, no body

(defun find-or-create-restricted-non-focal-problem-int (join-ordered-link
                                                        non-focal-restriction-bindings
                                                        creation-allowed?)
  (let ((non-focal-problem
          (mapped-problem-problem
           (join-ordered-link-non-focal-mapped-problem join-ordered-link))))
    (find-or-create-restricted-problem-and-link-int
     non-focal-problem non-focal-restriction-bindings creation-allowed?)))

;; (defun find-restricted-problem-and-link (unrestricted-problem restriction-bindings) ...) -- active declareFunction, no body

(defun find-or-create-restricted-problem-and-link-int (unrestricted-problem
                                                       restriction-bindings
                                                       creation-allowed?)
  "[Cyc] RESTRICTION-BINDINGS binding-list-p; UNRESTRICTED-PROBLEM's vars -> restriction.
i.e. bindings to substitute into UNRESTRICTED-PROBLEM to restrict it."
  (must (restriction-bindings)
        "Finding or creating a restricted problem of ~a requires bindings"
        unrestricted-problem)
  (let ((restricted-mapped-problem
          (find-or-create-restricted-problem-int unrestricted-problem restriction-bindings
                                                 creation-allowed?))
        (restriction-link nil))
    (when creation-allowed?
      (setf restriction-link
            (maybe-new-restriction-link unrestricted-problem restricted-mapped-problem
                                       restriction-bindings)))
    (values restricted-mapped-problem restriction-link)))

(defun find-or-create-restricted-problem (unrestricted-problem restriction-bindings)
  (find-or-create-restricted-problem-int unrestricted-problem restriction-bindings t))

(defun find-or-create-restricted-problem-int (unrestricted-problem restriction-bindings
                                              creation-allowed?)
  "[Cyc] RESTRICTION-BINDINGS binding-list-p; UNRESTRICTED-PROBLEM's vars -> restriction.
i.e. bindings to substitute into UNRESTRICTED-PROBLEM to restrict it."
  (must (restriction-bindings)
        "Creating a restricted problem of ~a requires bindings"
        unrestricted-problem)
  (let* ((query (problem-query unrestricted-problem))
         (restricted-query (apply-bindings restriction-bindings query))
         (store (problem-store unrestricted-problem))
         (restricted-mapped-problem
           (if creation-allowed?
               (find-or-create-problem store restricted-query)
               ;; Likely find-problem (without create)
               (missing-larkc 35228))))
    restricted-mapped-problem))

;;; Focal/non-focal analysis

(defun focal-problem-is-a-single-literal-backchain-required? (join-ordered-link)
  (let ((focal-problem (join-ordered-link-focal-problem join-ordered-link)))
    (and (single-literal-problem-p focal-problem)
         (problem-backchain-required? focal-problem))))

;; (defun corresponding-focal-problem (join-ordered-link problem) ...) -- active declareFunction, no body
;; (defun corresponding-non-focal-problem (join-ordered-link problem) ...) -- active declareFunction, no body
;; (defun corresponding-restricted-focal-problem (join-ordered-link problem) ...) -- active declareFunction, no body

(defun non-focal-restriction-link-with-corresponding-focal-proof? (restriction-link
                                                                   join-ordered-link)
  "[Cyc] Return booleanp; whether RESTRICTION-LINK supports a restricted non-focal problem
wrt JOIN-ORDERED-LINK. It checks this by looking for a corresponding proof of the focal
problem of JOIN-ORDERED-LINK with the same bindings (modulo variable map) as RESTRICTION-LINK."
  (join-ordered-link-restricted-non-focal-link? join-ordered-link restriction-link))

;; (defun corresponding-restricted-non-focal-problem (join-ordered-link problem) ...) -- active declareFunction, no body
;; (defun find-restricted-focal-problem-by-bindings (join-ordered-link bindings) ...) -- active declareFunction, no body

(defun mapped-proof-is-focal? (subproof proof-variable-map join-ordered-link)
  (let* ((focal-mapped-problem (join-ordered-link-focal-mapped-problem join-ordered-link))
         (focal-problem (mapped-problem-problem focal-mapped-problem))
         (subproof-supported-problem (proof-supported-problem subproof)))
    (when (eq focal-problem subproof-supported-problem)
      (let ((focal-variable-map (mapped-problem-variable-map focal-mapped-problem)))
        (when (bindings-equal? focal-variable-map proof-variable-map)
          t)))))

;;; Shared variable computation

(defun-memoized trigger-vars-shared-by-sibling (join-ordered-link trigger-is-focal?)
    (:test eq)
  "[Cyc] The variables in the trigger problem of JOIN-ORDERED-LINK which are also shared
by the sibling problem (modulo variable maps)"
  (let ((trigger-to-sibling-variable-map
          (trigger-to-sibling-variable-map join-ordered-link trigger-is-focal?)))
    (mapcar #'variable-binding-variable trigger-to-sibling-variable-map)))

;; (defun non-focal-vars-shared-by-focal (join-ordered-link) ...) -- active declareFunction, no body

(defun focal-vars-shared-by-non-focal (join-ordered-link)
  "[Cyc] This is complicated to avoid unnecessarily manifesting non-focals."
  (let* ((tactic (join-ordered-link-tactic join-ordered-link))
         (focal-mapped-problem (join-ordered-link-focal-mapped-problem join-ordered-link))
         (focal-clause (problem-sole-clause
                        (mapped-problem-problem focal-mapped-problem)))
         (focal-supporting-problem-spec
           (join-ordered-tactic-focal-supporting-problem-spec tactic))
         (dnf-clause (problem-sole-clause
                      (problem-link-supported-problem join-ordered-link)))
         (non-focal-clause (complement-of-subclause-specified-by-spec
                            dnf-clause focal-supporting-problem-spec))
         (non-focal-vars (tree-gather non-focal-clause #'variable-p))
         (focal-focal-vars (tree-gather focal-clause #'variable-p))
         (focal-vars (apply-bindings
                      (mapped-problem-variable-map focal-mapped-problem)
                      focal-focal-vars))
         (shared-vars (intersection focal-vars non-focal-vars :test #'eq))
         (focal-shared-vars (apply-bindings-backwards
                             (mapped-problem-variable-map focal-mapped-problem)
                             shared-vars)))
    focal-shared-vars))

;; (defun join-ordered-link-join-vars (join-ordered-link) ...) -- active declareFunction, no body
;; (defun join-ordered-link-focal-to-supported-variable-map (join-ordered-link) ...) -- active declareFunction, no body
;; (defun join-ordered-link-non-focal-to-supported-variable-map (join-ordered-link) ...) -- active declareFunction, no body

;;; Proof management

(defun add-join-ordered-link-proof (join-ordered-link trigger-proof trigger-is-focal?)
  "[Cyc] TRIGGER-PROOF must be a :proven proof, because otherwise it would not have bubbled up
to JOIN-ORDERED-LINK."
  (must (proof-proven? trigger-proof)
        "~a was a rejected proof" trigger-proof)
  (let ((shared-trigger-proof-bindings
          (join-ordered-link-shared-proof-bindings join-ordered-link trigger-proof
                                                   trigger-is-focal?)))
    (if trigger-is-focal?
        (add-join-ordered-link-focal-proof join-ordered-link
                                           shared-trigger-proof-bindings trigger-proof)
        (add-join-ordered-link-non-focal-proof join-ordered-link
                                               shared-trigger-proof-bindings trigger-proof)))
  nil)

(defun join-ordered-link-shared-proof-bindings (join-ordered-link trigger-proof
                                                trigger-is-focal?)
  (let ((trigger-proof-bindings (proof-bindings trigger-proof)))
    (join-ordered-link-shared-proof-bindings-int join-ordered-link
                                                 trigger-proof-bindings
                                                 trigger-is-focal?)))

;; (defun remove-join-ordered-link-proof (join-ordered-link trigger-proof trigger-is-focal? shared-trigger-proof-bindings) ...) -- active declareFunction, no body
;; (defun remove-join-ordered-link-proof-both-ways (join-ordered-link trigger-proof trigger-is-focal?) ...) -- active declareFunction, no body

(defun join-ordered-link-shared-proof-bindings-int (join-ordered-link
                                                    trigger-proof-bindings
                                                    trigger-is-focal?)
  (let ((trigger-vars-shared-by-sibling
          (trigger-vars-shared-by-sibling join-ordered-link trigger-is-focal?)))
    (filter-bindings-by-variables trigger-proof-bindings trigger-vars-shared-by-sibling)))

(defun join-ordered-link-sibling-proofs-lookup (join-ordered-link sibling-proof-bindings
                                                trigger-is-focal?)
  (if trigger-is-focal?
      (join-ordered-link-non-focal-proofs-lookup join-ordered-link sibling-proof-bindings)
      (join-ordered-link-focal-proofs-lookup join-ordered-link sibling-proof-bindings)))

(defun bubble-up-proof-to-join-ordered-link-int (trigger-subproof variable-map
                                                 join-ordered-link trigger-is-focal?)
  (let ((proofs nil)
        (trigger-proof-bindings (proof-bindings trigger-subproof))
        (sibling-proof-bindings (compute-sibling-proof-bindings
                                 trigger-proof-bindings join-ordered-link trigger-is-focal?)))
    (let ((sibling-proofs
            (remove-if-not #'proof-proven?
                           (join-ordered-link-sibling-proofs-lookup
                            join-ordered-link sibling-proof-bindings trigger-is-focal?))))
      (when sibling-proofs
        (let* ((sibling-mapped-problem
                 (join-ordered-link-sibling-mapped-problem join-ordered-link trigger-is-focal?))
               (sibling-variable-map
                 (mapped-problem-variable-map sibling-mapped-problem))
               (sibling-proofs-with-bindings nil))
          (dolist (sibling-proof sibling-proofs)
            (let ((sibling-sub-proof-bindings
                    (transfer-variable-map-to-bindings
                     sibling-variable-map (proof-bindings sibling-proof))))
              (push (cons sibling-proof sibling-sub-proof-bindings)
                    sibling-proofs-with-bindings)))
          (setf sibling-proofs-with-bindings (nreverse sibling-proofs-with-bindings))
          (let* ((trigger-sub-proof-bindings
                   (transfer-variable-map-to-bindings variable-map trigger-proof-bindings))
                 (supporting-mapped-proof-lists-by-supporting-problem
                   (if trigger-is-focal?
                       (list (list (cons trigger-subproof trigger-sub-proof-bindings))
                             sibling-proofs-with-bindings)
                       (list sibling-proofs-with-bindings
                             (list (cons trigger-subproof trigger-sub-proof-bindings)))))
                 (mapped-subproof-lists
                   (cartesian-product supporting-mapped-proof-lists-by-supporting-problem)))
            (dolist (mapped-subproof-list mapped-subproof-lists)
              (multiple-value-bind (proof new?)
                  (new-join-ordered-proof join-ordered-link mapped-subproof-list)
                (if new?
                    (push proof proofs)
                    (possibly-note-proof-processed trigger-subproof))))))
        (setf proofs (nreverse proofs))
        (dolist (proof proofs)
          (bubble-up-proof proof)))))
  nil)

(defun join-ordered-link-sibling-mapped-problem (join-ordered-link trigger-is-focal?)
  (if trigger-is-focal?
      (join-ordered-link-non-focal-mapped-problem join-ordered-link)
      (join-ordered-link-focal-mapped-problem join-ordered-link)))

;;; Link analysis

(defun join-ordered-link-could-be-finished? (jo-link strategic-context)
  (let ((unfinished? (not (finished-problem-p
                           (join-ordered-link-focal-problem jo-link) strategic-context))))
    (when (join-ordered-link-non-focal-manifested? jo-link)
      (do-problem-argument-links (restriction-link
                                  (join-ordered-link-non-focal-problem jo-link)
                                  :type :restriction
                                  :done unfinished?)
        (when (non-focal-restriction-link-with-corresponding-focal-proof?
               restriction-link jo-link)
          (let ((restricted-non-focal-problem
                  (problem-link-sole-supporting-problem restriction-link)))
            (setf unfinished?
                  (not (finished-problem-p restricted-non-focal-problem
                                           strategic-context)))))))
    (not unfinished?)))

;; (defun join-ordered-link-no-good? (jo-link strategic-context residual-transformation-allowed?) ...) -- active declareFunction, no body
;; (defun join-ordered-link-no-good-case-1? (jo-link strategic-context residual-transformation-allowed?) ...) -- active declareFunction, no body
;; (defun join-ordered-link-no-good-case-2? (jo-link strategic-context residual-transformation-allowed?) ...) -- active declareFunction, no body

(defun join-ordered-link-with-non-focal-unbound-predicate? (join-ordered-link)
  "[Cyc] Return booleanp; whether JOIN-ORDERED-LINK's non-focal problem has an unbound predicate
that would be bound by its focal problem."
  (let* ((non-focal-problem (join-ordered-link-non-focal-problem join-ordered-link))
         (non-focal-query (problem-query non-focal-problem)))
    (dolist (contextualized-clause non-focal-query)
      (dolist (contextualized-asent (neg-lits contextualized-clause))
        (destructuring-bind (mt asent) contextualized-asent
          (declare (ignore mt))
          (let ((pred (atomic-sentence-predicate asent)))
            (when (hl-var? pred)
              ;; Likely checks if pred is in the list of focal vars shared by non-focal
              (when (member-eq? pred (missing-larkc 36373))
                (return-from join-ordered-link-with-non-focal-unbound-predicate? t))))))
      (dolist (contextualized-asent (pos-lits contextualized-clause))
        (destructuring-bind (mt asent) contextualized-asent
          (declare (ignore mt))
          (let ((pred (atomic-sentence-predicate asent)))
            (when (hl-var? pred)
              ;; Likely checks if pred is in the list of focal vars shared by non-focal
              (when (member-eq? pred (missing-larkc 36374))
                (return-from join-ordered-link-with-non-focal-unbound-predicate? t)))))))
    nil))

(defun join-ordered-link-with-non-focal-isa-unbound-unbound-where-arg2-is-restricted?
    (join-ordered-link)
  "[Cyc] Return booleanp; whether JOIN-ORDERED-LINK's non-focal problem is (#$isa ?var0 ?var1) and
the ?var1 is restricted by the focal problem."
  (let* ((non-focal-problem (join-ordered-link-non-focal-problem join-ordered-link))
         (non-focal-query (problem-query non-focal-problem)))
    (dolist (contextualized-clause non-focal-query)
      (dolist (contextualized-asent (neg-lits contextualized-clause))
        (destructuring-bind (mt asent) contextualized-asent
          (declare (ignore mt))
          (let ((pred (atomic-sentence-predicate asent))
                (arg1 (atomic-sentence-arg2 asent))
                (arg2 (atomic-sentence-arg2 asent)))
            (when (and (eq pred (reader-make-constant-shell "isa"))
                       (variable-p arg1)
                       (variable-p arg2)
                       ;; Likely checks if arg2 is in the list of focal vars shared by non-focal
                       (member-eq? arg2 (missing-larkc 36375)))
              (return-from join-ordered-link-with-non-focal-isa-unbound-unbound-where-arg2-is-restricted? t)))))
      (dolist (contextualized-asent (pos-lits contextualized-clause))
        (destructuring-bind (mt asent) contextualized-asent
          (declare (ignore mt))
          (let ((pred (atomic-sentence-predicate asent))
                (arg1 (atomic-sentence-arg2 asent))
                (arg2 (atomic-sentence-arg2 asent)))
            (when (and (eq pred (reader-make-constant-shell "isa"))
                       (variable-p arg1)
                       (variable-p arg2)
                       ;; Likely checks if arg2 is in the list of focal vars shared by non-focal
                       (member-eq? arg2 (missing-larkc 36376)))
              (return-from join-ordered-link-with-non-focal-isa-unbound-unbound-where-arg2-is-restricted? t))))))
    nil))

;;; Setup phase

(toplevel
  (register-macro-helper 'join-ordered-link-focal-proof-index
                         'do-join-ordered-link-focal-proofs)
  (register-macro-helper 'join-ordered-link-non-focal-proof-index
                         'do-join-ordered-link-non-focal-proofs)
  (note-memoized-function 'focal-to-non-focal-variable-map)
  (note-memoized-function 'non-focal-to-focal-variable-map)
  (register-macro-helper 'non-focal-restriction-link-with-corresponding-focal-proof?
                         '(do-join-ordered-link-restricted-non-focal-problems
                           do-virtual-dependent-join-ordered-links))
  (note-memoized-function 'trigger-vars-shared-by-sibling))
