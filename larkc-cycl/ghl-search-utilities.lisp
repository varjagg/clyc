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

;; (defun ghl-table-p (v-object) ...) -- 1 req, 0 opt; present in original Cyc, not in LarKC

(defun ghl-goal-node? (v-search node &optional (test #'equal))
  (if (ghl-goal-fn v-search)
      (funcall (ghl-goal-fn v-search) v-search node)
      (if (listp (ghl-goal v-search))
          (member? node (ghl-goal v-search) test)
          (funcall test (ghl-goal v-search) node))))

;; (defun ghl-goal-or-marked-as-goal? (v-search node &optional test) ...) -- 2 req, 1 opt; present in original Cyc, not in LarKC
;; (defun ghl-node-satisfies-pred-arg-type? (v-search node) ...) -- 2 req, 0 opt; present in original Cyc, not in LarKC

(defun ghl-inverse-cardinality (pred node)
  (let ((kb-cardinality (if (sbhl-predicate-p pred)
                            (sbhl-inverse-cardinality (get-sbhl-module pred) node)
                            (missing-larkc 3926)))
        (sksi-cardinality 0))
    (+ kb-cardinality sksi-cardinality)))

(defun ghl-predicate-cardinality (pred node)
  (let ((kb-cardinality (if (sbhl-predicate-p pred)
                            (sbhl-predicate-cardinality (get-sbhl-module pred) node)
                            (missing-larkc 3927)))
        (sksi-cardinality 0))
    (+ kb-cardinality sksi-cardinality)))

(defun ghl-resolve-goal-found (v-search node)
  (unless (ghl-compute-justify? v-search)
    (ghl-set-result v-search node))
  (set-ghl-goal-found-p v-search t)
  (setf *graphl-finished?* t)
  nil)

;; (defun ghl-add-gt-assertion-to-result (v-search assertion) ...) -- 2 req, 0 opt; present in original Cyc, not in LarKC
;; (defun ghl-add-sbhl-assertion-to-result (v-search link-node mt tv pred sense) ...) -- 6 req, 0 opt; present in original Cyc, not in LarKC
;; (defun ghl-add-reflexivity-justification (v-search node pred) ...) -- 3 req, 0 opt; present in original Cyc, not in LarKC
;; (defun ghl-node-admitted-by-some-reflexive-gaf (v-search node) ...) -- 2 req, 0 opt; present in original Cyc, not in LarKC
