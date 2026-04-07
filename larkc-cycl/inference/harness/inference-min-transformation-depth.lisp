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

(defun problem-min-transformation-depth-from-signature (problem inference)
  (let ((signature (problem-min-transformation-depth-signature problem inference)))
    (min-transformation-depth-from-signature signature)))

(defun min-transformation-depth-from-signature (signature)
  (cond ((eq :undetermined signature)
         :undetermined)
        ((eq *transformation-depth-computation* :counterintuitive)
         (tree-min-number signature))
        (t (tree-sum signature))))

;; (defun logical-tactic-lookahead-min-transformation-depth (tactic inference) ...) -- active declareFunction, no body

(defun propagate-min-transformation-depth-signature-via-link (link)
  "[Cyc] Propagates transformation depth down via LINK."
  (do-id-index (id inference (problem-store-inference-id-index (problem-link-store link)))
    (propagate-min-transformation-depth-signature-via-link-wrt-inference link inference))
  nil)

(defun propagate-min-transformation-depth-signature (problem mtds inference)
  (let ((updated? (note-problem-min-transformation-depth-signature problem inference mtds)))
    (when updated?
      (let* ((set-contents-var (problem-argument-links problem))
             (basis-object (do-set-contents-basis-object set-contents-var))
             (state (do-set-contents-initial-state basis-object set-contents-var)))
        (loop until (do-set-contents-done? basis-object state)
              do (let ((link (do-set-contents-next basis-object state)))
                   (when (do-set-contents-element-valid? state link)
                     (propagate-min-transformation-depth-signature-via-link link)))
                 (setf state (do-set-contents-update-state state)))))
    updated?))

(defun propagate-min-transformation-depth-signature-via-link-wrt-inference (link inference)
  "[Cyc] Propagates transformation depth wrt INFERENCE down via LINK."
  (let* ((supported-problem (problem-link-supported-problem link))
         (parent-mtds (problem-min-transformation-depth-signature supported-problem inference)))
    (when (not (eq :undetermined parent-mtds))
      (cond ((transformation-link-p link)
             (propagate-mtds-via-transformation-link parent-mtds link inference))
            ((join-ordered-link-p link)
             (propagate-mtds-via-join-ordered-link parent-mtds link inference))
            ((residual-transformation-link-p link)
             ;; Likely propagates mtds via residual transformation link, parallel to transformation link case
             (missing-larkc 35423))
            ((split-link-p link)
             (propagate-mtds-via-split-link parent-mtds link inference))
            ((restriction-link-p link)
             (propagate-mtds-via-restriction-link parent-mtds link inference))
            ((union-link-p link)
             ;; Likely propagates mtds via union link, parallel to other link type cases
             (missing-larkc 35424))))))

(defun propagate-mtds-via-transformation-link (parent-mtds t-link inference)
  (must (single-literal-problem-query-depth-signature-p parent-mtds)
        "Time to support ~S propagation" parent-mtds)
  (when (problem-link-with-supporting-problem-p t-link)
    (let* ((supporting-problem (problem-link-sole-supporting-problem t-link))
           (supporting-problem-query (problem-query supporting-problem))
           (parent-depth parent-mtds)
           (child-mtds (new-initial-pqds supporting-problem-query (1+ parent-depth))))
      (propagate-min-transformation-depth-signature supporting-problem child-mtds inference))))

;; (defun propagate-mtds-via-residual-transformation-link (parent-mtds rt-link inference) ...) -- active declareFunction, no body
;; (defun compute-residual-transformation-mtds (parent-mtds rt-link) ...) -- active declareFunction, no body

(defun propagate-mtds-via-join-ordered-link (parent-mtds jo-link inference)
  (let* ((focal-problem (join-ordered-link-focal-problem jo-link))
         (focal-mtds (join-ordered-link-focal-mtds jo-link parent-mtds)))
    (when focal-mtds
      (propagate-min-transformation-depth-signature focal-problem focal-mtds inference)
      (when (join-ordered-link-has-non-focal-mapped-problem? jo-link)
        (let* ((non-focal-problem (join-ordered-link-non-focal-problem jo-link))
               (non-focal-mtds (join-ordered-link-non-focal-mtds jo-link parent-mtds)))
          (when non-focal-mtds
            (propagate-min-transformation-depth-signature non-focal-problem non-focal-mtds inference))))))
  nil)

(defun join-ordered-link-focal-mtds (jo-link parent-mtds)
  (let ((focal-spec (join-ordered-link-focal-supporting-problem-spec jo-link)))
    (when focal-spec
      (new-subclause-pqds parent-mtds focal-spec))))

(defun join-ordered-link-non-focal-mtds (jo-link parent-mtds)
  (let ((non-focal-spec (join-ordered-link-non-focal-supporting-problem-spec jo-link)))
    (when non-focal-spec
      (new-subclause-pqds parent-mtds non-focal-spec))))

;; (defun join-ordered-tactic-lookahead-mtds (tactic parent-mtds) ...) -- active declareFunction, no body

(defun propagate-mtds-via-split-link (parent-mtds split-link inference)
  (let ((split-problem (problem-link-supported-problem split-link)))
    (do-problem-link-supporting-mapped-problems (conjunct-mapped-problem split-link)
      (let* ((conjunct-problem (mapped-problem-problem conjunct-mapped-problem))
             (conjunct-mtds (split-problem-conjunct-mtds split-problem conjunct-mapped-problem parent-mtds)))
        (setf conjunct-mtds (intern-problem-query-depth-signature conjunct-mtds))
        (propagate-min-transformation-depth-signature conjunct-problem conjunct-mtds inference))))
  nil)

;; (defun split-tactic-lookahead-mtds (tactic parent-mtds) ...) -- active declareFunction, no body

(defun split-problem-conjunct-mtds (split-problem conjunct-mapped-problem parent-mtds)
  (let* ((conjunct-problem (mapped-problem-problem conjunct-mapped-problem))
         (literal-map (split-problem-conjunct-literal-map split-problem conjunct-mapped-problem))
         (conjunct-mtds (copy-tree (new-initial-pqds (problem-query conjunct-problem) :uninitialized))))
    (setf conjunct-mtds (napply-literal-map parent-mtds literal-map conjunct-mtds))
    conjunct-mtds))

(defun split-problem-conjunct-literal-map (split-problem conjunct-mapped-problem)
  (let* ((split-problem-query (problem-query split-problem))
         (split-problem-clause (first split-problem-query))
         (conjunct-variable-map (mapped-problem-variable-map conjunct-mapped-problem))
         (conjunct-problem (mapped-problem-problem conjunct-mapped-problem))
         (conjunct-problem-query (problem-query conjunct-problem))
         (conjunct-problem-clause (first conjunct-problem-query))
         (conjunct-problem-clause-wrt-split (apply-bindings conjunct-variable-map conjunct-problem-clause)))
    (new-subclause-literal-map split-problem-clause conjunct-problem-clause-wrt-split)))

(defun propagate-mtds-via-restriction-link (parent-mtds restriction-link inference)
  (let* ((restricted-problem (problem-link-sole-supporting-problem restriction-link))
         (restricted-mtds (restriction-link-restricted-mtds restriction-link parent-mtds)))
    (propagate-min-transformation-depth-signature restricted-problem restricted-mtds inference)))

(defun restriction-link-restricted-mtds (restriction-link parent-mtds)
  (when (single-literal-problem-p (problem-link-supported-problem restriction-link))
    (return-from restriction-link-restricted-mtds parent-mtds))
  (let* ((restricted-problem (problem-link-sole-supporting-problem restriction-link))
         (literal-map (restriction-link-literal-map restriction-link))
         (restricted-mtds (copy-tree (new-initial-pqds (problem-query restricted-problem) :uninitialized))))
    (setf restricted-mtds (napply-literal-map parent-mtds literal-map restricted-mtds))
    restricted-mtds))

(defun restriction-link-literal-map (restriction-link)
  (let* ((unrestricted-clause (first (problem-query (problem-link-supported-problem restriction-link))))
         (restriction-bindings (restriction-link-bindings restriction-link))
         (unrestricted-clause-qua-restricted (apply-bindings restriction-bindings unrestricted-clause))
         (restricted-mapped-problem (problem-link-sole-supporting-mapped-problem restriction-link))
         (restricted-variable-map (mapped-problem-variable-map restricted-mapped-problem))
         (restricted-clause (first (problem-query (mapped-problem-problem restricted-mapped-problem))))
         (restricted-clause-qua-unrestricted (apply-bindings restricted-variable-map restricted-clause))
         (literal-map (compute-restricted-clause-literal-map unrestricted-clause-qua-restricted restricted-clause-qua-unrestricted)))
    literal-map))

(defun compute-restricted-clause-literal-map (unrestricted-clause restricted-clause)
  (let ((literal-map (compute-clause-literal-map unrestricted-clause restricted-clause)))
    (when (or (member-eq? nil (first literal-map))
              (member-eq? nil (second literal-map)))
      (setf unrestricted-clause (inference-simplify-contextualized-dnf-clause (copy-tree unrestricted-clause)))
      (setf literal-map (compute-clause-literal-map unrestricted-clause restricted-clause)))
    literal-map))

(defun compute-clause-literal-map (parent-clause child-clause)
  "[Cyc] Compute a mapping between the literals in the PARENT-CLAUSE to CHILD-CLAUSE."
  (destructuring-bind (parent-neg-lits parent-pos-lits) parent-clause
    (destructuring-bind (child-neg-lits child-pos-lits) child-clause
      (let ((neg-lit-map nil)
            (pos-lit-map nil))
        (dolist (parent-neg-lit parent-neg-lits)
          (let ((child-index (position parent-neg-lit child-neg-lits :test #'equal)))
            (push child-index neg-lit-map)))
        (dolist (parent-pos-lit parent-pos-lits)
          (let ((child-index (position parent-pos-lit child-pos-lits :test #'equal)))
            (push child-index pos-lit-map)))
        (setf pos-lit-map (nreverse pos-lit-map))
        (list neg-lit-map pos-lit-map)))))

;; (defun propagate-mtds-via-union-link (parent-mtds union-link inference) ...) -- active declareFunction, no body
;; (defun union-tactic-lookahead-mtds (tactic parent-mtds) ...) -- active declareFunction, no body
;; (defun problem-query-depth-signature-p (object) ...) -- active declareFunction, no body

(defun single-literal-problem-query-depth-signature-p (object)
  (non-negative-integer-p object))

;; (defun multi-literal-problem-query-depth-signature-p (object) ...) -- active declareFunction, no body
;; (defun multi-clause-problem-query-depth-signature-p (object) ...) -- active declareFunction, no body

;; intern-problem-query-depth-signature is a globally-cached function (defun-cached pattern).
;; clear-intern-problem-query-depth-signature and remove-intern-problem-query-depth-signature
;; are generated by the defun-cached form.
(defun-cached intern-problem-query-depth-signature (pqds)
    (:test equal :declare ((type problem-query-depth-signature-p pqds)))
  (copy-tree pqds))

(defun new-initial-pqds (problem-query &optional (depth 0))
  (cond ((single-literal-problem-query-p problem-query)
         depth)
        ((singleton? problem-query)
         (new-initial-clause-pqds (first problem-query) depth))
        (t (let ((clause-pqds-list nil))
             (dolist (contextualized-clause problem-query)
               (push (new-initial-clause-pqds contextualized-clause depth) clause-pqds-list))
             (setf clause-pqds-list (nreverse clause-pqds-list))
             (when (integerp depth)
               (setf clause-pqds-list (intern-problem-query-depth-signature clause-pqds-list)))
             clause-pqds-list))))

(defun new-initial-clause-pqds (contextualized-clause &optional (depth 0))
  (let ((pqds (list (make-list (length (neg-lits contextualized-clause)) :initial-element depth)
                    (make-list (length (pos-lits contextualized-clause)) :initial-element depth))))
    (when (integerp depth)
      (setf pqds (intern-problem-query-depth-signature pqds)))
    pqds))

(defun new-subclause-pqds (parent-pqds subclause-spec)
  (declare (type multi-literal-problem-query-depth-signature-p parent-pqds))
  (destructuring-bind (neg-lit-pqds pos-lit-pqds) parent-pqds
    (destructuring-bind (neg-lit-specs pos-lit-specs) subclause-spec
      (let ((result-neg-lit-pqds nil)
            (result-pos-lit-pqds nil))
        (dolist (neg-lit-spec neg-lit-specs)
          (push (nth neg-lit-spec neg-lit-pqds) result-neg-lit-pqds))
        (dolist (pos-lit-spec pos-lit-specs)
          (push (nth pos-lit-spec pos-lit-pqds) result-pos-lit-pqds))
        (setf result-neg-lit-pqds (nreverse result-neg-lit-pqds))
        (setf result-pos-lit-pqds (nreverse result-pos-lit-pqds))
        (cond ((and (null result-neg-lit-pqds)
                    (singleton? result-pos-lit-pqds))
               (first result-pos-lit-pqds))
              ((and (null result-pos-lit-pqds)
                    (singleton? result-neg-lit-pqds))
               (first result-neg-lit-pqds))
              (t (intern-problem-query-depth-signature
                  (list result-neg-lit-pqds result-pos-lit-pqds))))))))

;; pqds-depth is a globally-cached function (defun-cached pattern).
;; Both pqds-depth-internal and pqds-depth have no bodies in Java.
;; clear-pqds-depth and remove-pqds-depth are also generated by defun-cached.
;; (defun-cached pqds-depth (pqds mode) (:test equal) ...) -- active declareFunction, no body
;; (defun clear-pqds-depth () ...) -- active declareFunction, no body (generated by defun-cached)
;; (defun remove-pqds-depth (pqds mode) ...) -- active declareFunction, no body (generated by defun-cached)

(defun pqds-merge (pqds1 pqds2)
  (cond ((equal pqds1 pqds2) pqds1)
        ((single-literal-problem-query-depth-signature-p pqds1)
         ;; Likely merges two single-literal pqds values — evidence: dispatch on pqds type
         (missing-larkc 35425))
        ;; The condition itself calls a missing-larkc function (35422, likely multi-clause-problem-query-depth-signature-p)
        ;; and the body calls another (35420, likely multi-clause-pqds-merge)
        ((progn
           ;; Likely tests multi-clause-problem-query-depth-signature-p on pqds1
           (missing-larkc 35422))
         ;; Likely calls multi-clause-pqds-merge
         (missing-larkc 35420))
        (t
         ;; Likely calls multi-literal-pqds-merge for remaining cases
         (missing-larkc 35418))))

;; (defun single-literal-pqds-merge (pqds1 pqds2) ...) -- active declareFunction, no body
;; (defun multi-literal-pqds-merge (pqds1 pqds2) ...) -- active declareFunction, no body
;; (defun multi-clause-pqds-merge (pqds1 pqds2) ...) -- active declareFunction, no body

(defun new-subclause-literal-map (clause subclause &optional (missing nil))
  (destructuring-bind (clause-neg-lits clause-pos-lits) clause
    (destructuring-bind (subclause-neg-lits subclause-pos-lits) subclause
      (let ((map-neg-lits (make-list (length clause-neg-lits) :initial-element missing))
            (map-pos-lits (make-list (length clause-pos-lits) :initial-element missing)))
        (loop for clause-lit in clause-neg-lits
              for clause-index from 0
              do (let ((subclause-index (position clause-lit subclause-neg-lits :test #'equal)))
                   (when (integerp subclause-index)
                     (setf (nth clause-index map-neg-lits) subclause-index))))
        (loop for clause-lit in clause-pos-lits
              for clause-index from 0
              do (let ((subclause-index (position clause-lit subclause-pos-lits :test #'equal)))
                   (when (integerp subclause-index)
                     (setf (nth clause-index map-pos-lits) subclause-index))))
        (let ((literal-map (list map-neg-lits map-pos-lits)))
          (must (tree-find-if #'integerp literal-map)
                "Failed literal map ~S" literal-map)
          literal-map)))))

(defun napply-literal-map (source-mtds literal-map target-mtds)
  (destructuring-bind (source-neg-mtds-list source-pos-mtds-list) source-mtds
    (destructuring-bind (neg-lit-map pos-lit-map) literal-map
      (let ((target-neg-mtds-list (if (consp target-mtds) (first target-mtds) nil))
            (target-pos-mtds-list (if (consp target-mtds) (second target-mtds) nil)))
        (loop for source-neg-mtds-17 in source-neg-mtds-list
              for neg-index-18 in neg-lit-map
              do (when (integerp neg-index-18)
                   (if (consp target-mtds)
                       (setf (nth neg-index-18 target-neg-mtds-list) source-neg-mtds-17)
                       (setf target-mtds source-neg-mtds-17))))
        (loop for source-pos-mtds-19 in source-pos-mtds-list
              for pos-index-20 in pos-lit-map
              do (when (integerp pos-index-20)
                   (if (consp target-mtds)
                       (setf (nth pos-index-20 target-pos-mtds-list) source-pos-mtds-19)
                       (setf target-mtds source-pos-mtds-19)))))))
  target-mtds)

(defun tree-sum (tree)
  "[Cyc] Return the sum of all numbers in TREE."
  (tree-sum-recursive tree 0))

(defun tree-sum-recursive (tree accumulator)
  (cond ((numberp tree)
         (setf accumulator (+ accumulator tree)))
        ((atom tree))
        (t (let ((sublist tree)
                 (first nil))
             (loop while (not (atom (rest sublist)))
                   do (setf first (first sublist))
                      (setf accumulator (tree-sum-recursive first accumulator))
                      (setf sublist (rest sublist)))
             (setf accumulator (tree-sum-recursive (first sublist) accumulator))
             (setf accumulator (tree-sum-recursive (rest sublist) accumulator)))))
  accumulator)

(defun tree-min-number (tree)
  "[Cyc] Return the lowest number TREE."
  (tree-min-number-recursive tree :positive-infinity))

(defun tree-min-number-recursive (tree lowest)
  (cond ((potentially-infinite-number-p tree)
         (setf lowest (potentially-infinite-number-min lowest tree)))
        ((atom tree))
        (t (let ((sublist tree)
                 (first nil))
             (loop while (not (atom (rest sublist)))
                   do (setf first (first sublist))
                      (setf lowest (tree-min-number-recursive first lowest))
                      (setf sublist (rest sublist)))
             (setf lowest (tree-min-number-recursive (first sublist) lowest))
             (setf lowest (tree-min-number-recursive (rest sublist) lowest)))))
  lowest)

;; (defun validate-problem-store-wrt-mtsd (store &optional stream) ...) -- active declareFunction, no body
;; (defun validate-min-transformation-depth-signature-propagation (problem &optional stream) ...) -- active declareFunction, no body
