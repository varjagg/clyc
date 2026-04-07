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

(defparameter *default-transitive-check-cost* *expensive-hl-module-check-cost*)

(defparameter *default-transitive-walk-cost* 4)

;; Functions in declareFunction order

(defun make-transitivity-support (predicate &optional mt (tv :true-def))
  (make-hl-support :isa
                   (make-binary-formula #$isa predicate #$TransitiveBinaryPredicate)
                   mt tv))

(defun gt-required-arg-type-p (object)
  (gt-term-p object))

;; (defun inference-transitivity-check (predicate arg1 arg2 &optional mt tv) ...) -- active declareFunction, no body

(defun inference-transitivity-check-strict (predicate arg1 arg2 &optional mt (tv :true-def))
  "[Cyc] Like @xref INFERENCE-TRANSITIVITY-CHECK but requires at least one actual transitive step."
  (gt-predicate-relation-p predicate arg1 arg2 mt tv nil))

(defun inference-transitivity-justify (predicate arg1 arg2 &optional mt (tv :true-def))
  (let ((trans-support (make-transitivity-support predicate mt tv))
        (justification (why-gt-predicate-relation-p predicate arg1 arg2 mt tv)))
    (when justification
      (cons trans-support justification))))

;; This is an inline expansion of do-all-genl-predicates-and-inverses (SBHL backward
;; traversal over genlPreds module). For each genl-pred reached, it estimates the
;; cost of walking arg1's transitive links under that predicate.
(defun removal-transitive-arg1-walk-cost (asent &optional sense)
  (declare (ignore sense))
  (let* ((pred (atomic-sentence-predicate asent))
         (arg1 (atomic-sentence-arg1 asent))
         (est 0)
         (module (get-sbhl-module #$genlPreds))
         (node-var pred)
         (deck-type :queue)
         (recur-deck (create-deck deck-type))
         (node-and-predicate-mode nil))
    (let ((*sbhl-space* (get-sbhl-marking-space)))
      (let ((tv-var nil))
        (let ((*sbhl-tv* (or tv-var (get-sbhl-true-tv)))
              (*relevant-sbhl-tv-function*
                (if tv-var
                    'relevant-sbhl-tv-is-general-tv
                    *relevant-sbhl-tv-function*)))
          (when tv-var
            (sbhl-check-type tv-var sbhl-true-tv-p))
          (let ((*sbhl-search-module* module)
                (*sbhl-search-module-type* (get-sbhl-module-type module))
                (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
                (*genl-inverse-mode-p* nil)
                (*sbhl-module* module))
            (if (or (suspend-sbhl-type-checking?)
                    (apply-sbhl-module-type-test pred (get-sbhl-module)))
                (let ((*sbhl-search-direction* (get-sbhl-backward-search-direction))
                      (*sbhl-link-direction*
                        (sbhl-search-direction-to-link-direction
                         (get-sbhl-backward-search-direction) module))
                      (*genl-inverse-mode-p* nil))
                  (sbhl-mark-node-marked node-var)
                  (setf node-and-predicate-mode
                        (list pred (genl-inverse-mode-p)))
                  (loop while node-and-predicate-mode do
                    (let* ((node-var-7 (first node-and-predicate-mode))
                           (predicate-mode (second node-and-predicate-mode))
                           (genl-pred node-var-7))
                      (let ((*genl-inverse-mode-p* predicate-mode))
                        (let ((inv predicate-mode))
                          (if inv
                              (if (eq genl-pred #$genls)
                                  (incf est (spec-cardinality arg1))
                                  (incf est (num-gaf-arg-index arg1 2 genl-pred)))
                              (if (eq genl-pred #$genls)
                                  (incf est (genl-cardinality arg1))
                                  (incf est (num-gaf-arg-index arg1 1 genl-pred))))
                          (dolist (module-var (get-sbhl-accessible-modules module))
                            (let ((*sbhl-module* module-var)
                                  (*genl-inverse-mode-p*
                                    (if (flip-genl-inverse-mode?)
                                        (not *genl-inverse-mode-p*)
                                        *genl-inverse-mode-p*)))
                              (let ((node (naut-to-nart node-var-7)))
                                (if (sbhl-node-object-p node)
                                    (let ((d-link (get-sbhl-graph-link node (get-sbhl-module))))
                                      (if d-link
                                          (let ((mt-links (get-sbhl-mt-links
                                                           d-link
                                                           (get-sbhl-link-direction)
                                                           (get-sbhl-module))))
                                            (when mt-links
                                              (maphash
                                               (lambda (mt tv-links)
                                                 (when (relevant-mt? mt)
                                                   (let ((*sbhl-link-mt* mt))
                                                     (maphash
                                                      (lambda (tv link-nodes)
                                                        (when (relevant-sbhl-tv? tv)
                                                          (let ((*sbhl-link-tv* tv))
                                                            (let ((new-list
                                                                    (if (sbhl-randomize-lists-p)
                                                                        (missing-larkc 9297)
                                                                        link-nodes)))
                                                              (dolist (node-vars-link-node new-list)
                                                                (unless (sbhl-search-path-termination-p
                                                                         node-vars-link-node)
                                                                  (sbhl-mark-node-marked node-vars-link-node)
                                                                  (deck-push (list node-vars-link-node
                                                                                   (genl-inverse-mode-p))
                                                                             recur-deck)))))))
                                                      tv-links))))
                                               mt-links)))
                                          (sbhl-error 5 "attempting to bind direction link variable, to NIL. macro body not executed.")))
                                    (when (cnat-p node)
                                      (let ((new-list
                                              (if (sbhl-randomize-lists-p)
                                                  ;; Likely randomizes NART generating functions
                                                  (missing-larkc 9298)
                                                  ;; Likely gets NART generating functions for node
                                                  (missing-larkc 2617))))
                                        (dolist (generating-fn new-list)
                                          (let ((*sbhl-link-generator* generating-fn))
                                            (let ((link-nodes (funcall generating-fn node)))
                                              (let ((new-list-17
                                                      (if (sbhl-randomize-lists-p)
                                                          (missing-larkc 9299)
                                                          link-nodes)))
                                                (dolist (node-vars-link-node new-list-17)
                                                  (unless (sbhl-search-path-termination-p
                                                           node-vars-link-node)
                                                    (sbhl-mark-node-marked node-vars-link-node)
                                                    (deck-push (list node-vars-link-node
                                                                     (genl-inverse-mode-p))
                                                               recur-deck))))))))))))))
                      (setf node-and-predicate-mode (deck-pop recur-deck)))))
                (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                           pred (get-sbhl-type-test (get-sbhl-module)))))))
        (free-sbhl-marking-space *sbhl-space*)))
    (max *default-transitive-walk-cost* est)))

(defun removal-transitive-arg1-walk-iterator (predicate arg1)
  (new-removal-ghl-closure-iterator predicate arg1 :forward))

;; This is an inline expansion of do-all-genl-predicates-and-inverses (SBHL forward
;; traversal over genlPreds module). For each genl-pred reached, it estimates the
;; cost of walking arg2's transitive links under that predicate.
(defun removal-transitive-arg2-walk-cost (asent &optional sense)
  (declare (ignore sense))
  (let* ((pred (atomic-sentence-predicate asent))
         (arg2 (atomic-sentence-arg2 asent))
         (est 0)
         (module (get-sbhl-module #$genlPreds))
         (node-var pred)
         (deck-type :queue)
         (recur-deck (create-deck deck-type))
         (node-and-predicate-mode nil))
    (let ((*sbhl-space* (get-sbhl-marking-space)))
      (let ((tv-var nil))
        (let ((*sbhl-tv* (or tv-var (get-sbhl-true-tv)))
              (*relevant-sbhl-tv-function*
                (if tv-var
                    'relevant-sbhl-tv-is-general-tv
                    *relevant-sbhl-tv-function*)))
          (when tv-var
            (sbhl-check-type tv-var sbhl-true-tv-p))
          (let ((*sbhl-search-module* module)
                (*sbhl-search-module-type* (get-sbhl-module-type module))
                (*sbhl-add-node-to-result-test* (get-sbhl-add-node-to-result-test module))
                (*genl-inverse-mode-p* nil)
                (*sbhl-module* module))
            (if (or (suspend-sbhl-type-checking?)
                    (apply-sbhl-module-type-test pred (get-sbhl-module)))
                (let ((*sbhl-search-direction* (get-sbhl-forward-search-direction))
                      (*sbhl-link-direction*
                        (sbhl-search-direction-to-link-direction
                         (get-sbhl-forward-search-direction) module))
                      (*genl-inverse-mode-p* nil))
                  (sbhl-mark-node-marked node-var)
                  (setf node-and-predicate-mode
                        (list pred (genl-inverse-mode-p)))
                  (loop while node-and-predicate-mode do
                    (let* ((node-var-25 (first node-and-predicate-mode))
                           (predicate-mode (second node-and-predicate-mode))
                           (genl-pred node-var-25))
                      (let ((*genl-inverse-mode-p* predicate-mode))
                        (let ((inv predicate-mode))
                          (if inv
                              (if (eq genl-pred #$genls)
                                  (incf est (genl-cardinality arg2))
                                  (incf est (num-gaf-arg-index arg2 1 genl-pred)))
                              (if (eq genl-pred #$genls)
                                  (incf est (spec-cardinality arg2))
                                  (incf est (num-gaf-arg-index arg2 2 genl-pred))))
                          (dolist (module-var (get-sbhl-accessible-modules module))
                            (let ((*sbhl-module* module-var)
                                  (*genl-inverse-mode-p*
                                    (if (flip-genl-inverse-mode?)
                                        (not *genl-inverse-mode-p*)
                                        *genl-inverse-mode-p*)))
                              (let ((node (naut-to-nart node-var-25)))
                                (if (sbhl-node-object-p node)
                                    (let ((d-link (get-sbhl-graph-link node (get-sbhl-module))))
                                      (if d-link
                                          (let ((mt-links (get-sbhl-mt-links
                                                           d-link
                                                           (get-sbhl-link-direction)
                                                           (get-sbhl-module))))
                                            (when mt-links
                                              (maphash
                                               (lambda (mt tv-links)
                                                 (when (relevant-mt? mt)
                                                   (let ((*sbhl-link-mt* mt))
                                                     (maphash
                                                      (lambda (tv link-nodes)
                                                        (when (relevant-sbhl-tv? tv)
                                                          (let ((*sbhl-link-tv* tv))
                                                            (let ((new-list
                                                                    (if (sbhl-randomize-lists-p)
                                                                        (missing-larkc 9300)
                                                                        link-nodes)))
                                                              (dolist (node-vars-link-node new-list)
                                                                (unless (sbhl-search-path-termination-p
                                                                         node-vars-link-node)
                                                                  (sbhl-mark-node-marked node-vars-link-node)
                                                                  (deck-push (list node-vars-link-node
                                                                                   (genl-inverse-mode-p))
                                                                             recur-deck)))))))
                                                      tv-links))))
                                               mt-links)))
                                          (sbhl-error 5 "attempting to bind direction link variable, to NIL. macro body not executed.")))
                                    (when (cnat-p node)
                                      (let ((new-list
                                              (if (sbhl-randomize-lists-p)
                                                  ;; Likely randomizes NART generating functions
                                                  (missing-larkc 9301)
                                                  ;; Likely gets NART generating functions for node
                                                  (missing-larkc 2619))))
                                        (dolist (generating-fn new-list)
                                          (let ((*sbhl-link-generator* generating-fn))
                                            (let ((link-nodes (funcall generating-fn node)))
                                              (let ((new-list-35
                                                      (if (sbhl-randomize-lists-p)
                                                          (missing-larkc 9302)
                                                          link-nodes)))
                                                (dolist (node-vars-link-node new-list-35)
                                                  (unless (sbhl-search-path-termination-p
                                                           node-vars-link-node)
                                                    (sbhl-mark-node-marked node-vars-link-node)
                                                    (deck-push (list node-vars-link-node
                                                                     (genl-inverse-mode-p))
                                                               recur-deck))))))))))))))
                      (setf node-and-predicate-mode (deck-pop recur-deck)))))
                (sbhl-warn 2 "Node ~a does not pass sbhl-type-test ~a~%"
                           pred (get-sbhl-type-test (get-sbhl-module)))))))
        (free-sbhl-marking-space *sbhl-space*)))
    (max *default-transitive-walk-cost* est)))

(defun removal-transitive-arg2-walk-iterator (predicate arg2)
  (new-removal-ghl-closure-iterator predicate arg2 :backward))

;; (defun inference-transitivity-gather-arg1 (predicate arg1) ...) -- active declareFunction, no body

;; Setup phase

(toplevel
  (inference-removal-module :removal-transitive-check
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p)
                                    (:test gt-required-arg-type-p)
                                    (:test gt-required-arg-type-p))
                                   ((:test inference-transitive-predicate?) . :anything))
          :cost-expression '*default-transitive-check-cost*
          :output-check-pattern '(:tuple (pred arg1 arg2)
                                  (:call inference-transitivity-check-strict
                                         (:value pred)
                                         (:value arg1)
                                         (:value arg2)))
          :support-module :transitivity
          :documentation "(<transitive predicate> <fort> <fort>))
using general transitivity graph walking of KB assertions"
          :example "(#$geographicalSubRegions #$ContinentOfEurope #$CityOfParisFrance)")))

(toplevel
  (inference-removal-module :removal-transitive-arg1-walk
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p)
                                    (:test gt-required-arg-type-p)
                                    :variable)
                                   ((:test inference-transitive-predicate?) . :anything))
          :cost 'removal-transitive-arg1-walk-cost
          :input-extract-pattern '(:template ((:bind predicate) (:bind arg1) :anything)
                                             ((:value predicate) (:value arg1)))
          :output-generate-pattern '(:call removal-transitive-arg1-walk-iterator
                                           (:value predicate) (:value arg1))
          :output-construct-pattern '((:value predicate) (:value arg1) :input)
          :support-module :transitivity
          :documentation "(<transitive predicate> <fort> <variable>))
using general transitivity graph walking of KB assertions
starting from <arg1>"
          :example "(#$geographicalSubRegions #$ContinentOfEurope ?SUB)")))

(toplevel
  (inference-removal-module :removal-transitive-arg2-walk
    (list :sense :pos
          :arity 2
          :required-pattern '(:and ((:test non-hl-predicate-p)
                                    :variable
                                    (:test gt-required-arg-type-p))
                                   ((:test inference-transitive-predicate?) . :anything))
          :cost 'removal-transitive-arg2-walk-cost
          :input-extract-pattern '(:template ((:bind predicate) :anything (:bind arg2))
                                             ((:value predicate) (:value arg2)))
          :output-generate-pattern '(:call removal-transitive-arg2-walk-iterator
                                           (:value predicate) (:value arg2))
          :output-construct-pattern '((:value predicate) :input (:value arg2))
          :support-module :transitivity
          :documentation "(<transitive predicate> <variable> <fort>))
using general transitivity graph walking of KB assertions
starting from <arg2>"
          :example "(#$geographicalSubRegions ?SUPER #$CityOfParisFrance)")))
