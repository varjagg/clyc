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

;; This file is nearly entirely missing-larkc. Only the struct definitions and
;; resourcing variables survive. All iterator logic (generate, update, done?,
;; next, finalize) is stripped.

;; Struct 1: top-level iterator over multiple modules
(defstruct sbhl-link-node-search-state-iterator-state
  sbhl-link-node-search-state
  remaining-modules
  module-node-search-state-iterator)

;; (defun sbhl-link-node-search-state-iterator-state-p (object)) -- commented declareFunction, no body
;; (defun generate-new-sbhl-link-node-search-state-iterator-state (iterator)) -- commented declareFunction, no body
;; (defun get-sbhl-link-node-search-state-iterator-state-next-module (state)) -- commented declareFunction, no body
;; (defun update-sbhl-link-node-search-state-iterator-state (state)) -- commented declareFunction, no body
;; (defun sbhl-link-node-search-state-iterator-state-done? (state)) -- commented declareFunction, no body
;; (defun new-sbhl-link-node-search-state-iterator (search-state)) -- commented declareFunction, no body
;; (defun sbhl-link-node-search-state-iterator-done (iterator)) -- commented declareFunction, no body
;; (defun sbhl-link-node-search-state-iterator-next (iterator)) -- commented declareFunction, no body
;; (defun sbhl-link-node-search-state-iterator-finalize (iterator)) -- commented declareFunction, no body
;; (defun new-sbhl-module-link-node-search-state-iterator (node module)) -- commented declareFunction, no body
;; (defun new-fort-sbhl-module-link-node-search-state-iterator (fort module mt)) -- commented declareFunction, no body
;; (defun new-naut-sbhl-module-link-node-search-state-iterator (naut module mt)) -- commented declareFunction, no body

;; Struct 2: per-module direction link iterator
(defstruct sbhl-module-direction-link-search-state-iterator-state
  mt-link-iterator
  tv-link-search-state-iterator
  graph-link
  module
  node
  direction
  genl-inverse-mode?)

;; (defun sbhl-module-direction-link-search-state-iterator-state-p (object)) -- commented declareFunction, no body
;; (defun generate-new-sbhl-module-direction-link-search-state-iterator-state (node module direction mt genl-inverse-mode?)) -- commented declareFunction, no body
;; (defun update-sbhl-module-direction-link-search-state-iterator-state (state)) -- commented declareFunction, no body
;; (defun sbhl-module-direction-link-search-state-iterator-done? (state)) -- commented declareFunction, no body
;; (defun new-sbhl-module-direction-link-search-state-iterator (node module direction mt genl-inverse-mode?)) -- commented declareFunction, no body
;; (defun sbhl-module-direction-link-search-state-iterator-done (iterator)) -- commented declareFunction, no body
;; (defun sbhl-module-direction-link-search-state-iterator-next (iterator)) -- commented declareFunction, no body
;; (defun sbhl-module-direction-link-search-state-iterator-finalize (iterator)) -- commented declareFunction, no body

;; Struct 3: per-module tv-link node iterator
(defstruct sbhl-module-tv-link-node-search-state-iterator-state
  tv-link-iterator
  current-tv
  current-remaining-nodes
  module
  parent-node
  direction
  mt
  genl-inverse-mode?)

;; (defun sbhl-module-tv-link-node-search-state-iterator-state-p (object)) -- commented declareFunction, no body
;; (defun generate-new-sbhl-module-tv-link-node-search-state-iterator-state (parent-node module direction mt tv genl-inverse-mode?)) -- commented declareFunction, no body
;; (defun sbhl-module-tv-link-node-search-state-iterator-state-done? (state)) -- commented declareFunction, no body
;; (defun sbhl-module-tv-link-node-search-state-iterator-state-next-sbhl-link-node-search-state (state)) -- commented declareFunction, no body
;; (defun sbhl-module-tv-link-node-search-state-iterator-state-generate-sbhl-link-node-search-state (state tv)) -- commented declareFunction, no body
;; (defun new-sbhl-module-tv-link-node-search-state-iterator (parent-node module direction mt tv genl-inverse-mode?)) -- commented declareFunction, no body
;; (defun sbhl-module-tv-link-node-search-state-iterator-done (iterator)) -- commented declareFunction, no body
;; (defun sbhl-module-tv-link-node-search-state-iterator-next (iterator)) -- commented declareFunction, no body
;; (defun sbhl-module-tv-link-node-search-state-iterator-finalize (iterator)) -- commented declareFunction, no body

;; Struct 4: per-module NAUT link node iterator
(defstruct sbhl-module-naut-link-node-search-state-iterator-state
  generating-functions
  current-generating-function
  current-remaining-nodes
  module
  parent-node
  direction
  mt
  tv
  genl-inverse-mode?)

;; (defun sbhl-module-naut-link-node-search-state-iterator-state-p (object)) -- commented declareFunction, no body
;; (defun generate-new-sbhl-module-naut-link-node-search-state-iterator-state (parent-node module direction mt tv genl-inverse-mode? generating-functions)) -- commented declareFunction, no body
;; (defun sbhl-module-naut-link-node-search-state-iterator-state-done? (state)) -- commented declareFunction, no body
;; (defun sbhl-module-naut-link-node-search-state-iterator-state-next-sbhl-link-node-search-state (state)) -- commented declareFunction, no body
;; (defun sbhl-module-naut-link-node-search-state-iterator-state-generate-sbhl-link-node-search-state (state generating-function)) -- commented declareFunction, no body
;; (defun new-sbhl-module-naut-link-node-search-state-iterator (parent-node module direction mt tv genl-inverse-mode? generating-functions)) -- commented declareFunction, no body
;; (defun sbhl-module-naut-link-node-search-state-iterator-done (iterator)) -- commented declareFunction, no body
;; (defun sbhl-module-naut-link-node-search-state-iterator-next (iterator)) -- commented declareFunction, no body
;; (defun sbhl-module-naut-link-node-search-state-iterator-finalize (iterator)) -- commented declareFunction, no body

;; (defun within-sbhl-link-iterator-resourcing? ()) -- commented declareFunction, no body
;; TODO with-sbhl-link-iterator-state-resourcing -- commented declareMacro
;; TODO with-sbhl-link-iterator-resourcing -- commented declareMacro
;; (defun find-or-create-sbhl-link-node-search-state-iterator-state ()) -- commented declareFunction, no body
;; (defun find-sbhl-link-node-search-state-iterator-state ()) -- commented declareFunction, no body
;; (defun release-sbhl-link-node-search-state-iterator-state (state)) -- commented declareFunction, no body
;; (defun find-or-create-sbhl-module-direction-link-search-state-iterator-state ()) -- commented declareFunction, no body
;; (defun find-sbhl-module-direction-link-search-state-iterator-state ()) -- commented declareFunction, no body
;; (defun release-sbhl-module-direction-link-search-state-iterator-state (state)) -- commented declareFunction, no body
;; (defun find-or-create-sbhl-module-tv-link-node-search-state-iterator-state ()) -- commented declareFunction, no body
;; (defun find-sbhl-module-tv-link-node-search-state-iterator-state ()) -- commented declareFunction, no body
;; (defun release-sbhl-module-tv-link-node-search-state-iterator-state (state)) -- commented declareFunction, no body
;; (defun find-or-create-sbhl-module-naut-link-node-search-state-iterator-state ()) -- commented declareFunction, no body
;; (defun find-sbhl-module-naut-link-node-search-state-iterator-state ()) -- commented declareFunction, no body
;; (defun release-sbhl-module-naut-link-node-search-state-iterator-state (state)) -- commented declareFunction, no body

;; Resourcing variables
(defparameter *sbhl-link-node-search-state-iterator-state-store* nil)
(defparameter *sbhl-module-direction-link-search-state-iterator-state-store* nil)
(defparameter *sbhl-module-tv-link-node-search-state-iterator-state-store* nil)
(defparameter *sbhl-module-naut-link-node-search-state-iterator-state-store* nil)
(defparameter *sbhl-link-iterator-resourcing?* nil)
