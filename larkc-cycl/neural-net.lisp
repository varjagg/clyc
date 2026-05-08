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

;; NEURAL-NET struct — 1 slot: input-nodes
(defstruct neural-net
  input-nodes)

(defconstant *dtp-neural-net* 'neural-net)

;; neural-net-p is provided by defstruct

;; nn-input-nodes is provided by defstruct (neural-net-input-nodes accessor)
;; _csetf-nn-input-nodes is setf of nn-input-nodes
;; make-neural-net is provided by defstruct

;; new-neural-net (weights-list) — active declareFunction, no body
;; (defun new-neural-net (weights-list) ...) -- active declareFunction, no body

;; neural-net-input-nodes (neural-net) — active declareFunction, no body
;; NOTE: this name conflicts with defstruct accessor; the Java struct accessor is
;; nn-input-nodes while this is the public API wrapper. The defstruct already
;; provides neural-net-input-nodes.
;; Leaving as-is since CL defstruct already defines it.

;; neural-net-input-node-count (neural-net) — active declareFunction, no body
;; (defun neural-net-input-node-count (neural-net) ...) -- active declareFunction, no body

;; neural-net-set-inputs (neural-net inputs) — active declareFunction, no body
;; (defun neural-net-set-inputs (neural-net inputs) ...) -- active declareFunction, no body

;; sigmoid (x) — active declareFunction, no body
;; (defun sigmoid (x) ...) -- active declareFunction, no body

;; NN-INPUT-NODE struct — 2 slots: value, weights
(defstruct nn-input-node
  value
  weights)

(defconstant *dtp-nn-input-node* 'nn-input-node)

;; nn-input-node-p is provided by defstruct

;; nnin-value is provided by defstruct (nn-input-node-value accessor)
;; nnin-weights is provided by defstruct (nn-input-node-weights accessor)
;; _csetf-nnin-value is setf of nnin-value
;; _csetf-nnin-weights is setf of nnin-weights
;; make-nn-input-node is provided by defstruct

;; new-nn-input-node (value weights) — active declareFunction, no body
;; (defun new-nn-input-node (value weights) ...) -- active declareFunction, no body

;; nn-input-node-value is provided by defstruct
;; nn-input-node-weights is provided by defstruct

;; nn-input-node-set-value (nn-input-node value) — active declareFunction, no body
;; (defun nn-input-node-set-value (nn-input-node value) ...) -- active declareFunction, no body

;; From Champ0_19.gnm, with the first list of weights moved to the end (the bias node weights)
(deflexical *rl-tactician-neural-net-weights-list*
  '((-0.227514d0 -0.395681d0 -0.392587d0 -0.304583d0 0.717281d0)
    (0.466911d0 -1.01181d0 0.515608d0 0.186695d0 -0.173123d0)
    (0.691837d0 -0.39004d0 1.27718d0 0.0985643d0 -0.459222d0)
    (-0.14361d0 -0.100166d0 -0.409217d0 0.703923d0 0.0986236d0)
    (-0.558941d0 -0.654273d0 0.875859d0 -0.547818d0 0.464239d0)
    (-0.0898241d0 1.16297d0 -0.140286d0 0.727112d0 -0.0571363d0)
    (0.33211d0 0.804213d0 -0.500794d0 0.0836377d0 -0.119423d0)
    (-0.27839d0 -0.424287d0 0.0972779d0 -0.0641412d0 -0.324519d0)
    (-0.04071d0 -1.03764d0 -1.1684d0 -0.285568d0 0.322287d0)
    (0.35157d0 -0.0978135d0 -0.649702d0 1.0535d0 0.83717d0)
    (-0.0862237d0 0.22735d0 -1.21319d0 -0.531121d0 -0.486909d0)
    (0.256012d0 0.852522d0 -0.7396d0 0.233292d0 -0.0850184d0)
    (0.704154d0 -0.182174d0 0.169152d0 -1.2787d0 -0.400246d0)
    (0.242133d0 -0.671766d0 -1.05614d0 -0.0740336d0 -0.0432617d0)
    (-0.871448d0 0.0101277d0 0.221434d0 -0.0241337d0 -0.717193d0)
    (-0.228881d0 -0.132546d0 -0.240634d0 0.935199d0 0.111408d0)
    (0.456088d0 -0.189828d0 0.06841d0 -0.112433d0 -0.254772d0)
    (0.0838212d0 -0.901167d0 0.555404d0 0.126584d0 -1.13132d0)
    (0.927022d0 -0.294691d0 0.735027d0 0.42247d0 0.263537d0)
    (0.229667d0 -0.76629d0 1.13279d0 0.0468138d0 -0.392014d0)
    (0.565153d0 -0.082501d0 0.208606d0 0.101688d0 -0.672053d0))
  "[Cyc] From Champ0_19.gnm, with the first list of weights moved to the end (the bias node weights).")

;; deflexical + boundp guard → defglobal
(defglobal *rl-tactician-neural-net* nil)

;; rl-tactician-initialize-neural-net () — active declareFunction, no body
;; (defun rl-tactician-initialize-neural-net () ...) -- active declareFunction, no body

;; rl-tactician-neural-net () — active declareFunction, no body
;; (defun rl-tactician-neural-net () ...) -- active declareFunction, no body

;; rl-tactician-evaluate-neural-net (a b c d) — active declareFunction, no body
;; (defun rl-tactician-evaluate-neural-net (a b c d) ...) -- active declareFunction, no body

;; rl-tactician-set-neural-net-input-values (a b c d e) — active declareFunction, no body
;; (defun rl-tactician-set-neural-net-input-values (a b c d e) ...) -- active declareFunction, no body

;; rl-tactician-compute-neural-net-input-values (a b c d) — active declareFunction, no body
;; (defun rl-tactician-compute-neural-net-input-values (a b c d) ...) -- active declareFunction, no body

;; rl-tactician-compute-neural-net-output (neural-net something) — active declareFunction, no body
;; (defun rl-tactician-compute-neural-net-output (neural-net something) ...) -- active declareFunction, no body

;; rl-tactician-indexes-we-care-about (thing) — active declareFunction, no body
;; (defun rl-tactician-indexes-we-care-about (thing) ...) -- active declareFunction, no body
