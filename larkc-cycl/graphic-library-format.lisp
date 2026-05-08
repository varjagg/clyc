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

;; GLF-GRAPH defstruct — 13 slots, accessor conc-name "GLFGRPH-" per $list4.
;; print-object is missing-larkc 6536 — CL's default print-object handles this.
;; Equality.identity call in setup is elided (no-op DTP registration). All
;; accessors + _csetf setters + MAKE-GLF-GRAPH + GLF-GRAPH-P are provided
;; natively by defstruct.
(defstruct (glf-graph (:conc-name "GLFGRPH-")
                      (:predicate glf-graph-p)
                      (:constructor make-glf-graph (&key id types ais nodes
                                                         node-types source-node
                                                         arcs arc-types
                                                         incoming-connectors
                                                         outgoing-connectors
                                                         incoming-connector-types
                                                         outgoing-connector-types
                                                         rendering-info)))
  id
  types
  ais
  nodes
  node-types
  source-node
  arcs
  arc-types
  incoming-connectors
  outgoing-connectors
  incoming-connector-types
  outgoing-connector-types
  rendering-info)

(defconstant *dtp-glf-graph* 'glf-graph)

;; (defun glfgrph-has-node-types? (glf-graph) ...) -- commented declareFunction, no body
;; (defun glfgrph-has-arc-types? (glf-graph) ...) -- commented declareFunction, no body
;; (defun glfgrph-has-incoming-connector-types? (glf-graph) ...) -- commented declareFunction, no body
;; (defun glfgrph-has-outgoing-connector-types? (glf-graph) ...) -- commented declareFunction, no body
;; (defun glfgrph-has-rendering-info? (glf-graph) ...) -- commented declareFunction, no body
;; (defun glfgrph-has-nodes? (glf-graph) ...) -- commented declareFunction, no body
;; (defun glfgrph-has-arcs? (glf-graph) ...) -- commented declareFunction, no body
;; (defun glfgrph-print (object stream depth) ...) -- commented declareFunction, no body
;; (defun xml-serialize-glf-graph (glf-graph &optional stream) ...) -- commented declareFunction, no body
;; (defun xml-serialize-glf-graph-core (glf-graph stream) ...) -- commented declareFunction, no body
;; (defun xml-serialize-glf-graph-diagram (glf-graph stream) ...) -- commented declareFunction, no body
;; (defun xml-serialize-glf-graph-rendering (glf-graph stream) ...) -- commented declareFunction, no body
;; (defun xml-serialize-glf-graph-rendering-info (glf-graph stream) ...) -- commented declareFunction, no body
;; (defun xml-serialize-glf-graph-flow-model (glf-graph stream) ...) -- commented declareFunction, no body
;; (defun get-graph-defining-mt (graph-term) ...) -- commented declareFunction, no body
;; (defun load-glf-graph-from-kb (graph-term mt) ...) -- commented declareFunction, no body
;; (defun map-glf-graph-to-ais (glf-graph mt) ...) -- commented declareFunction, no body
;; (defun create-glf-graph-from-kb (graph-term mt) ...) -- commented declareFunction, no body
;; (defun initialize-glfgrph-node-types (glf-graph mt) ...) -- commented declareFunction, no body
;; (defun note-glf-graph-node-type (glf-graph type) ...) -- commented declareFunction, no body
;; (defun initialize-glfgrph-arc-types (glf-graph mt) ...) -- commented declareFunction, no body
;; (defun note-glf-graph-arc-type (glf-graph type) ...) -- commented declareFunction, no body
;; (defun load-all-glf-nodes-from-kb (glf-graph mt) ...) -- commented declareFunction, no body
;; (defun load-one-glf-node-from-kb (glf-graph node mt) ...) -- commented declareFunction, no body
;; (defun load-all-glf-arcs-from-kb (glf-graph mt) ...) -- commented declareFunction, no body
;; (defun load-one-glf-arc-from-kb (glf-graph arc mt) ...) -- commented declareFunction, no body

;; GLF-NODE defstruct — 4 slots, accessor conc-name "GLFNODE-" per $list114.
;; print-object is missing-larkc 6543 — CL's default print-object handles this.
(defstruct (glf-node (:conc-name "GLFNODE-")
                     (:predicate glf-node-p)
                     (:constructor make-glf-node (&key id types parent semantics)))
  id
  types
  parent
  semantics)

(defconstant *dtp-glf-node* 'glf-node)

;; (defun glfnode-print (object stream depth) ...) -- commented declareFunction, no body
;; (defun create-glf-node-from-kb (glf-graph node mt) ...) -- commented declareFunction, no body

;; GLF-ARC defstruct — 6 slots, accessor conc-name "GLFARC-" per $list138.
;; print-object is missing-larkc 6492 — CL's default print-object handles this.
(defstruct (glf-arc (:conc-name "GLFARC-")
                    (:predicate glf-arc-p)
                    (:constructor make-glf-arc (&key id types parent from to semantics)))
  id
  types
  parent
  from
  to
  semantics)

(defconstant *dtp-glf-arc* 'glf-arc)

;; (defun glfarc-print (object stream depth) ...) -- commented declareFunction, no body
;; (defun create-glf-arc-from-kb (glf-graph arc mt) ...) -- commented declareFunction, no body

;; GLF-RENDERING defstruct — 1 slot, accessor conc-name "GLFRNDR-" per $list171.
;; print-object is missing-larkc 6550 — CL's default print-object handles this.
(defstruct (glf-rendering (:conc-name "GLFRNDR-")
                          (:predicate glf-rendering-p)
                          (:constructor make-glf-rendering (&key label)))
  label)

(defconstant *dtp-glf-rendering* 'glf-rendering)

;; (defun glfrndr-print (object stream depth) ...) -- commented declareFunction, no body
;; (defun create-glf-rendering-for-component-from-kb (graph component mt) ...) -- commented declareFunction, no body
