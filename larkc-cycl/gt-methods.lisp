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

;;; Functions — following declare_gt_methods_file() ordering

;; (defun gt-superiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-superiors (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-min-superiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-min-superiors (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-inferiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-inferiors (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-max-inferiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-max-inferiors (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-co-superiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-co-superiors (node &optional mt1 mt2) ...) -- no body, commented declareFunction
;; (defun gt-co-inferiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-co-inferiors (node &optional mt1 mt2) ...) -- no body, commented declareFunction
;; (defun gt-redundant-superiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-redundant-superiors (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-redundant-inferiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-redundant-inferiors (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-all-superiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-all-superiors (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-all-inferiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-all-inferiors (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-union-all-inferiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-union-all-inferiors (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-all-accessible (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-all-accessible (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-roots (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-roots (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-leaves (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-leaves (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-compose-fn-all-superiors (predicate fort fn &optional combine-fn mt) ...) -- no body, commented declareFunction
;; (defun gtm-compose-fn-all-superiors (node fn &optional combine-fn mt) ...) -- no body, commented declareFunction
;; (defun gt-compose-fn-all-inferiors (predicate fort fn &optional combine-fn mt) ...) -- no body, commented declareFunction
;; (defun gtm-compose-fn-all-inferiors (node fn &optional combine-fn mt) ...) -- no body, commented declareFunction
;; (defun gt-compose-pred-all-superiors (predicate fort compose-pred &optional compose-index-arg compose-gather-arg mt) ...) -- no body, commented declareFunction
;; (defun gtm-compose-pred-all-superiors (node compose-pred &optional compose-index-arg compose-gather-arg mt) ...) -- no body, commented declareFunction
;; (defun gt-compose-pred-all-inferiors (predicate fort compose-pred &optional compose-index-arg compose-gather-arg mt) ...) -- no body, commented declareFunction
;; (defun gtm-compose-pred-all-inferiors (node compose-pred &optional compose-index-arg compose-gather-arg mt) ...) -- no body, commented declareFunction
;; (defun gt-all-dependent-inferiors (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-all-dependent-inferiors (node &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-boolean? (predicate arg1 arg2 &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-boolean? (arg1 arg2 &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-superior? (predicate superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-superior? (superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-why-superior? (predicate superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-support-predicate (support) ...) -- no body, commented declareFunction
;; (defun gt-support-sentence (support) ...) -- no body, commented declareFunction
;; (defun gtm-why-superior? (superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-inferior? (predicate arg1 arg2 &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-inferior? (arg1 arg2 &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-has-superior? (predicate inferior superior &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-has-superior? (inferior superior &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-has-inferior? (predicate superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-has-inferior? (superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-gather-inferior (predicate arg1 arg2 &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-gather-inferior (arg1 arg2 &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-gather-superior (predicate arg1 arg2 &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-gather-superior (arg1 arg2 &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-cycles? (predicate fort &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-cycles? (node &optional mt1 mt2) ...) -- no body, commented declareFunction
;; (defun gt-completes-cycle? (predicate fort1 fort2 &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-completes-cycle? (fort1 fort2 &optional mt1 mt2) ...) -- no body, commented declareFunction
;; (defun gt-why-completes-cycle? (predicate fort1 fort2 &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-why-completes-cycle? (fort1 fort2 &optional mt1 mt2) ...) -- no body, commented declareFunction
;; (defun gt-min-nodes (predicate forts &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-min-nodes (nodes &optional mt) ...) -- no body, commented declareFunction

(defun gt-max-nodes (predicate forts &optional mt (direction *gt-max-nodes-direction*))
  "[Cyc] Returns returns the least-subordinate elements of FORTS
   (<direction> should be :up unless all nodes are low in the hierarchy)"
  (declare (type fort-p predicate))
  (declare (type list forts))
  (gtm predicate :max-nodes forts mt direction))

(defun gtm-max-nodes (nodes &optional mt (direction *gt-max-nodes-direction*))
  "[Cyc] Returns returns the least-subordinate elements of <nodes>
   (<direction> should be :up unless all nodes are low in the hierarchy)"
  (let ((unique-nodes (remove-duplicate-forts nodes)))
    (if (singleton? unique-nodes)
        unique-nodes
        (cond
          ((eq direction :up)
           (missing-larkc 4445))
          ((eq direction :down)
           (gt-max-nodes-down unique-nodes mt))))))

(defun gt-max-nodes-down (nodes &optional mt)
  "[Cyc] Returns the least-subordinate elements of <nodes>
   (permit search downwards in the hierarchy: expensive)"
  (let ((result nil)
        (mt-var mt))
    (let ((*mt* (update-inference-mt-relevance-mt mt-var))
          (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
          (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
      (dolist (node nodes)
        (when (not (gt-searched? node))
          (missing-larkc 3581)
          (when (gt-searched? node)
            (missing-larkc 3565))))
      (setf result (remove-if #'gt-searched? nodes)))
    result))

;; (defun gt-max-nodes-up-with-hash (nodes &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-max-nodes-up (nodes &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-min-ceilings (predicate forts &optional candidates mt) ...) -- no body, commented declareFunction
;; (defun gtm-min-ceilings (nodes &optional candidates mt) ...) -- no body, commented declareFunction
;; (defun gt-ceilings (nodes &optional candidates mt) ...) -- no body, commented declareFunction
;; (defun gt-ceilings-int (nodes &optional candidates mt) ...) -- no body, commented declareFunction
;; (defun gt-max-floors (predicate forts &optional candidates mt) ...) -- no body, commented declareFunction
;; (defun gtm-max-floors (nodes &optional candidates mt) ...) -- no body, commented declareFunction
;; (defun gt-floors (nodes &optional candidates mt) ...) -- no body, commented declareFunction
;; (defun gt-floors-int (nodes &optional candidates mt) ...) -- no body, commented declareFunction
;; (defun gt-min-superiors-excluding (predicate inferior superior &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-min-superiors-excluding (inferior superior &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-max-inferiors-excluding (predicate superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-max-inferiors-excluding (superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-all-superior-edges (predicate superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-all-inferior-edges (predicate superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-all-superior-edges (superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-all-inferior-edges (superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-all-paths (predicate superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-all-paths (superior inferior &optional mt) ...) -- no body, commented declareFunction
;; (defun gt-superior-in-what-mts (predicate superior inferior) ...) -- no body, commented declareFunction
;; (defun gtm-in-what-mts (superior inferior method) ...) -- no body, commented declareFunction
;; (defun gt-which-mts (predicate superior inferior method) ...) -- no body, commented declareFunction
;; (defun gt-hierarchically-direct-in-what-mts (predicate fort) ...) -- no body, commented declareFunction
;; (defun associate-node-with-last-spec-total (node) ...) -- no body, commented declareFunction
;; (defun find-spec-cardinality (node) ...) -- no body, commented declareFunction
;; (defun gt-all-inferiors-with-their-max-mts (predicate fort) ...) -- no body, commented declareFunction
;; (defun gtm-all-inferiors-with-mts (node) ...) -- no body, commented declareFunction
;; (defun find-instance-cardinality (node) ...) -- no body, commented declareFunction
;; (defun gt-all-fort-instances-with-their-max-mts (fort) ...) -- no body, commented declareFunction
;; (defun add-result-to-gt-result (result) ...) -- no body, commented declareFunction
;; (defun gt-isa-in-what-mts (predicate fort) ...) -- no body, commented declareFunction
;; (defun gt-any-superior-path (predicate inferior superior &optional mt) ...) -- no body, commented declareFunction
;; (defun gtm-any-superior-path (inferior superior &optional mt) ...) -- no body, commented declareFunction

;;; Setup section

(toplevel
  (register-cyc-api-function 'gt-superiors
    '(predicate fort &optional mt)
    "Returns direct superiors of FORT via transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-min-superiors
    '(predicate fort &optional mt)
    "Returns minimal superiors of FORT via transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-inferiors
    '(predicate fort &optional mt)
    "Returns direct inferiors of FORT via transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-max-inferiors
    '(predicate fort &optional mt)
    "Returns maximal inferiors of FORT via transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-co-superiors
    '(predicate fort &optional mt)
    "Returns sibling direct-superiors of direct-inferiors of FORT via PREDICATE, excluding FORT itself"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-co-inferiors
    '(predicate fort &optional mt)
    "Returns sibling direct-inferiors of direct-superiors of FORT via PREDICATE, excluding FORT itself"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-redundant-superiors
    '(predicate fort &optional mt)
    "Returns direct-superiors of FORT via PREDICATE that are subsumed by other superiors"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-redundant-inferiors
    '(predicate fort &optional mt)
    "Returns direct-inferiors of FORT via PREDICATE that subsumed other inferiors"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-all-superiors
    '(predicate fort &optional mt)
    "Returns all superiors of FORT via PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-all-inferiors
    '(predicate fort &optional mt)
    "Returns all inferiors of FORT via PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-all-accessible
    '(predicate fort &optional mt)
    "Returns all superiors and all inferiors of FORT via PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-roots
    '(predicate fort &optional mt)
    "Returns maximal superiors (i.e., roots) of FORT via PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-leaves
    '(predicate fort &optional mt)
    "Returns minimal inferiors (i.e., leaves) of FORT via PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-compose-fn-all-superiors
    '(predicate fort fn &optional (combine-fn #'cons) mt)
    "Apply fn to each superior of FORT;
   fn takes a fort as its only arg, and must not effect the search status of each
  fort it visits"
    '((predicate fort-p) (fort gt-term-p) (fn function-spec-p))
    nil)
  (register-cyc-api-function 'gt-compose-fn-all-inferiors
    '(predicate fort fn &optional (combine-fn *gt-combine-fn*) mt)
    "Apply fn to each inferior of FORT;
   fn takes a fort as its only arg, and
   it must not effect the search status of each fort it visits"
    '((predicate fort-p) (fort gt-term-p) (fn function-spec-p))
    nil)
  (register-cyc-api-function 'gt-compose-pred-all-superiors
    '(predicate fort compose-pred &optional (compose-index-arg *gt-compose-index-arg*) (compose-gather-arg *gt-compose-gather-arg*) mt)
    "Returns all nodes accessible by COMPOSE-PRED from each superior of FORT along
  transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p) (compose-pred predicate-in-any-mt?))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-compose-pred-all-inferiors
    '(predicate fort compose-pred &optional (compose-index-arg *gt-compose-index-arg*) (compose-gather-arg *gt-compose-gather-arg*) mt)
    "Returns all nodes accessible by COMPOSE-PRED from each inferior of FORT along
  transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p) (compose-pred predicate-in-any-mt?))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-all-dependent-inferiors
    '(predicate fort &optional mt)
    "Returns all inferiors i of FORT s.t. every path connecting i to
   any superior of FORT must pass through FORT"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-why-superior?
    '(predicate superior inferior &optional mt)
    "Returns justification of why SUPERIOR is superior to (i.e., hierarchically higher than)
  INFERIOR"
    '((predicate fort-p) (superior gt-term-p) (inferior gt-term-p))
    '((list assertion-p)))
  (register-cyc-api-function 'gt-has-superior?
    '(predicate inferior superior &optional mt)
    "Returns whetherfort INFERIOR is hierarchically lower (wrt transitive PREDICATE)
  to fort SUPERIOR?"
    '((predicate fort-p) (inferior gt-term-p) (superior gt-term-p))
    '(booleanp))
  (register-cyc-api-function 'gt-has-inferior?
    '(predicate superior inferior &optional mt)
    "Returns whether fort SUPERIOR is hierarchically higher
   (wrt transitive PREDICATE) to fort INFERIOR?"
    '((predicate fort-p) (superior gt-term-p) (inferior gt-term-p))
    '(booleanp))
  (register-cyc-api-function 'gt-cycles?
    '(predicate fort &optional mt)
    "Returns whether FORT is accessible from itself by one or more PREDICATE gafs?"
    '((predicate fort-p) (fort gt-term-p))
    '(booleanp))
  (register-cyc-api-function 'gt-completes-cycle?
    '(predicate fort1 fort2 &optional mt)
    "Returns whether a transitive path connect FORT2 to FORT1,
   or whether a transitive inverse path connect FORT1 to FORT2?"
    '((predicate fort-p) (fort1 gt-term-p) (fort2 gt-term-p))
    '(booleanp))
  (register-cyc-api-function 'gt-why-completes-cycle?
    '(predicate fort1 fort2 &optional mt)
    "Returns justification that a transitive path connects FORT2 to FORT1,
   or that a transitive inverse path connects FORT1 to FORT2?"
    '((predicate fort-p) (fort1 gt-term-p) (fort2 gt-term-p))
    nil)
  (register-cyc-api-function 'gt-min-nodes
    '(predicate forts &optional mt)
    "Returns returns the most-subordinate elements of FORTS
   (one member only of a cycle will be a min-node candidate)"
    '((predicate fort-p) (forts listp))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-max-nodes
    '(predicate forts &optional mt (direction *gt-max-nodes-direction*))
    "Returns returns the least-subordinate elements of FORTS
   (<direction> should be :up unless all nodes are low in the hierarchy)"
    '((predicate fort-p) (forts listp))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-min-ceilings
    '(predicate forts &optional candidates mt)
    "Returns the most-subordinate common superiors of FORTS
   (when CANDIDATES is non-nil, the result must subset it)"
    '((predicate fort-p) (forts listp))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-max-floors
    '(predicate forts &optional candidates mt)
    "Returns the least-subordinate elements or common inferiors of FORTS
   (when CANDIDATES is non-nil, the result must subset it)"
    '((predicate fort-p) (forts listp))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-min-superiors-excluding
    '(predicate inferior superior &optional mt)
    "Returns least-general superiors of INFERIOR ignoring SUPERIOR
   (useful for splicing-out SUPERIOR from hierarchy)"
    '((predicate fort-p) (inferior gt-term-p) (superior gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-max-inferiors-excluding
    '(predicate superior inferior &optional mt)
    "Returns most-general inferiors of SUPERIOR ignoring INFERIOR (expensive)
   (useful for splicing-out INFERIOR from hierarchy)"
    '((predicate fort-p) (inferior gt-term-p) (superior gt-term-p))
    '((list gt-term-p)))
  (register-cyc-api-function 'gt-any-superior-path
    '(predicate inferior superior &optional mt)
    "Returns list of nodes connecting INFERIOR with SUPERIOR"
    '((predicate fort-p) (inferior gt-term-p) (superior gt-term-p))
    '((list gt-term-p))))
