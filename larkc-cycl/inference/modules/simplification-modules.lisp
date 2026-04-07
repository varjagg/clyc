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

(deflexical *simplification-module-names*
  '(:removal-simplification-conjunction-duplicate-literals-via-functionality))

(defun simplification-module-p (hl-module)
  (and (hl-module-p hl-module)
       (member-eq? (hl-module-name hl-module) *simplification-module-names*)))

(defparameter *simplification-modules-enabled?* t
  "[Cyc] Temporary control variable, should eventually stay T.
When non-nil, we allow for simplification modules to apply.")

(defun simplification-duplicate-literals-via-functionality-pos-lits-applicability (contextualized-dnf-clause)
  (declare (ignore contextualized-dnf-clause))
  (when *simplification-modules-enabled?*
    (let ((problem (currently-active-problem)))
      (when (problem-is-a-topological-root? problem)
        (let* ((minimal-problem-query (supporting-residual-conjunction-problem-minimal-problem-query problem))
               (equivalence-classes (simplification-duplicate-literals-via-functionality-pos-lits-equivalence-classes
                                     (problem-query-sole-clause minimal-problem-query)))
               (non-singleton-classes (find-all-if-not #'singleton? equivalence-classes)))
          (when non-singleton-classes
            (return-from simplification-duplicate-literals-via-functionality-pos-lits-applicability
              ;; Likely creates a productivity/bindings result from the non-singleton equivalence classes
              (list (missing-larkc 30276))))))))
  nil)

(defun problem-is-a-topological-root? (problem)
  (do-problem-dependent-links (link problem)
    (when (or (residual-transformation-link-p link)
              (answer-link-p link)
              (and (split-link-p link)
                   (problem-is-a-topological-root? (problem-link-supported-problem link))))
      (return-from problem-is-a-topological-root? t)))
  nil)

;; (defun simplification-duplicate-literals-via-functionality-expand (contextualized-dnf-clause) ...) -- active declareFunction, no body
;; (defun problem-query-simplify-via-functionality (problem) ...) -- active declareFunction, no body
;; (defun problem-query-compute-simplification-via-functionality-variable-map (problem) ...) -- active declareFunction, no body
;; (defun compute-simplification-via-functionality-variable-map (equivalence-classes) ...) -- active declareFunction, no body

(defun-memoized asent-pred-inter-arg-dependent-cardinalities (pred) (:test eql :capacity 100)
  (let ((result nil))
    (dolist (tuple (pred-value-tuples-in-any-mt pred #$interArgDependentCardinality 1 '(2 3 4 5 6)))
      (push tuple result))
    result))

;; any-spec?-memoized is a state-dependent memoized function (defun-memoized pattern).
;; Both internal and wrapper bodies are stripped. Orphan $int12$1024 suggests capacity 1024.
;; (defun any-spec?-memoized-internal (spec genl &optional mt tv) ...) -- active declareFunction, no body
;; (defun any-spec?-memoized (spec genl &optional mt tv) ...) -- active declareFunction, no body

(defun simplification-duplicate-literals-via-functionality-pos-lits-equivalence-classes (contextualized-dnf-clause)
  (let ((possible-match-asents nil)
        (result nil))
    (let ((variable-constraint-tuples (dnf-variable-constraint-tuples contextualized-dnf-clause))
          (num 0))
      (declare (ignore variable-constraint-tuples))
      (dolist (lit (pos-lits contextualized-dnf-clause))
        (destructuring-bind (mt asent) lit
          (declare (ignore mt))
          (let ((asent-pred (sentence-arg0 asent)))
            (when (fort-p asent-pred)
              (let ((asent-pred-inter-arg-dependent-cardinalities
                      (asent-pred-inter-arg-dependent-cardinalities asent-pred)))
                (when asent-pred-inter-arg-dependent-cardinalities
                  (dolist (asent-pred-inter-arg-dependent-cardinality
                            asent-pred-inter-arg-dependent-cardinalities)
                    (destructuring-bind (m col1 n col2 card)
                        asent-pred-inter-arg-dependent-cardinality
                      (declare (ignore col2))
                      (when (and (eql card 1)
                                 (eq col1 #$Thing))
                        (let ((arg-from (atomic-sentence-arg asent m))
                              (arg-to (atomic-sentence-arg asent n)))
                          (when (if (fort-p arg-to)
                                    ;; Likely checks whether arg-to is a spec of some collection
                                    (missing-larkc 4983)
                                    ;; Likely checks variable constraint from variable-constraint-tuples
                                    (missing-larkc 32842))
                            (let ((fake-pred
                                    ;; Likely constructs a synthetic predicate symbol from the cardinality info
                                    (missing-larkc 7522)))
                              (push (list fake-pred arg-from arg-to) possible-match-asents)))))))))
              (when (functional-in-some-arg? asent-pred)
                (push asent possible-match-asents)))))
        (incf num)))
    (when (duplicates? possible-match-asents #'equal #'sentence-arg0)
      (let ((equivalence-map
              ;; Likely (new-equivalence-map) — creates a new equivalence map for tracking variable bindings
              (missing-larkc 32853))
            (mapping-iteration-done? nil)
            (predicates (fast-delete-duplicates (mapcar #'sentence-arg0 possible-match-asents))))
        (loop until mapping-iteration-done?
              do (setf mapping-iteration-done? t)
                 (dolist (predicate predicates)
                   (let ((functional-arg-positions
                           (if (keywordp predicate)
                               '(2)
                               ;; Likely calls functional-in-arg-positions for predicate
                               (missing-larkc 29770))))
                     (dolist (functional-position functional-arg-positions)
                       (dolist (possible-match-asent-1 possible-match-asents)
                         (when (equal predicate (sentence-arg0 possible-match-asent-1))
                           (dolist (possible-match-asent-2 possible-match-asents)
                             (when (and (equal predicate (sentence-arg0 possible-match-asent-2))
                                        (not (equal possible-match-asent-1 possible-match-asent-2)))
                               (let ((asent-1-func-arg (sentence-arg possible-match-asent-1 functional-position))
                                     (asent-2-func-arg (sentence-arg possible-match-asent-2 functional-position))
                                     (equivalence-found? t))
                                 (declare (ignore asent-1-func-arg asent-2-func-arg))
                                 (unless
                                     ;; Likely (equivalence-map-equivalent? equivalence-map asent-1-func-arg asent-2-func-arg)
                                     (missing-larkc 32848)
                                   (let ((argnum 0)
                                         (asent-1-arg possible-match-asent-1)
                                         (asent-2-arg possible-match-asent-2))
                                     (loop while (or asent-1-arg asent-2-arg)
                                           do (let ((asent-1-arg-8 (first asent-1-arg))
                                                    (asent-2-arg-9 (first asent-2-arg)))
                                                (declare (ignore asent-1-arg-8 asent-2-arg-9))
                                                (unless (or (eql argnum 0)
                                                            (eql argnum functional-position))
                                                  (unless
                                                      ;; Likely (equivalence-map-equivalent? equivalence-map asent-1-arg-8 asent-2-arg-9)
                                                      (missing-larkc 32849)
                                                    (setf equivalence-found? nil))))
                                              (incf argnum)
                                              (setf asent-1-arg (rest asent-1-arg))
                                              (setf asent-2-arg (rest asent-2-arg))))
                                   (when equivalence-found?
                                     (setf equivalence-map
                                           ;; Likely (equivalence-map-join equivalence-map asent-1-func-arg asent-2-func-arg)
                                           (missing-larkc 32852))
                                     (setf mapping-iteration-done? nil))))))))))))
        (dolist (class-id
                  ;; Likely (equivalence-map-class-ids equivalence-map)
                  (missing-larkc 32846))
          (let ((class-list
                  ;; Likely (equivalence-map-class-list-by-id equivalence-map class-id)
                  (missing-larkc 32847)))
            (when
                ;; Likely checks list length > 1 — non-singleton check
                (missing-larkc 9094)
              (push class-list result))))
        (dolist (other-variable (expression-gather contextualized-dnf-clause #'hl-variable-p))
          (unless
              ;; Likely (equivalence-map-class-id-for-object equivalence-map other-variable) — checks if already tracked
              (missing-larkc 32845)
            (push (list other-variable) result)))))
    result))

;; Orphan constants $sym16$CAR and $str17$_ are used in stripped function bodies above
;; (likely in compute-simplification-via-functionality-variable-map or problem-query-simplify-via-functionality)

;; (defun new-equivalence-map (&optional test) ...) -- active declareFunction, no body
;; (defun print-equivalence-map (equivalence-map) ...) -- active declareFunction, no body
;; (defun equivalence-map-class-ids (equivalence-map) ...) -- active declareFunction, no body
;; (defun equivalence-map-class-id-for-object (equivalence-map object) ...) -- active declareFunction, no body
;; (defun equivalence-map-class-list-by-id (equivalence-map class-id) ...) -- active declareFunction, no body
;; (defun equivalence-map-equivalent? (equivalence-map object1 object2) ...) -- active declareFunction, no body
;; (defun equivalence-map-insert (equivalence-map object) ...) -- active declareFunction, no body
;; (defun equivalence-map-join (equivalence-map object1 object2) ...) -- active declareFunction, no body

;;; Setup

(inference-conjunctive-removal-module :removal-simplification-conjunction-duplicate-literals-via-functionality
  '(:direction :backward
    :every-predicates nil
    :applicability simplification-duplicate-literals-via-functionality-pos-lits-applicability
    :cost-expression 0
    :completeness :complete
    :exclusive t
    :expand simplification-duplicate-literals-via-functionality-expand
    :documentation "Simplification module to bind variables to forts or other variables when functional predicate can be used to prove equivalence."))

(note-funcall-helper-function 'simplification-duplicate-literals-via-functionality-pos-lits-applicability)
;; note-memoized-function for asent-pred-inter-arg-dependent-cardinalities is generated by defun-memoized
(note-memoized-function 'any-spec?-memoized)
