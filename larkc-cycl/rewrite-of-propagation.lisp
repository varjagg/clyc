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

;; rewrite-of-after-adding (source target assertion) — commented, no body
;; rewrite-of-after-adding-internal (source target assertion) — commented, no body
;; propagate-rewrite-of-assertion (assertion) — commented, no body

(defparameter *enable-rewrite-of-propagation?* t
  "[Cyc] Enable assertion propagation across equal forts when this is non-nil.")

(defparameter *propagate-rewrite-of-source-term* nil)
(defparameter *propagate-rewrite-of-target-term* nil)
(defparameter *propagate-rewrite-of-assertion* nil)

(defun perform-rewrite-of-propagation (assertion)
  "[Cyc] Propagate ASSERTION across rewriteOf links."
  (when *enable-rewrite-of-propagation?*
    (let ((forts-with-rewrite-of (expression-gather assertion
                                                    #'fort-with-some-source-rewrite-of-assertions
                                                    t)))
      (when forts-with-rewrite-of
        (dolist (fort forts-with-rewrite-of)
          (declare (ignore fort))
          (missing-larkc 4713)))))
  assertion)

(defun fort-with-some-source-rewrite-of-assertions (fort)
  (some-source-rewrite-of-assertions-somewhere? fort))

;; perform-rewrite-of-propagation-internal (source-term assertion) — commented, no body
;; propagate-assertion-via-rewrite-of (source-term target-term assertion mt) — commented, no body
;; should-propagate-rewrite-of-cnf (source-term target-term cnf) — commented, no body
;; note-should-propagate-rewrite-of-cnf () — commented, no body
;; propagate-rewrite-of-cnf (source-term target-term cnf) — commented, no body
;; propagate-rewrite-of-cnf-internal (source-term target-term cnf mt) — commented, no body
;; propagate-rewrite-of-atomic-sentence (source-term target-term atomic-sentence mt) — commented, no body
;; determine-propagate-rewrite-of-mt (assertion mt) — commented, no body

(toplevel
  (register-kb-function 'rewrite-of-after-adding))
