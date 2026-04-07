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

(defun basemt? (mt basemt)
  "[Cyc] Optimized for kb-mapping: this assumes all baseMt assertions are visible in BaseKB."
  (setf mt (bind-mt-indexicals mt))
  (setf basemt (bind-mt-indexicals basemt))
  (monad-basemt? mt basemt))

(defun clear-mt-relevance-cache ()
  "[Cyc] Clear the Mt relevance cache."
  (clear-monad-mt-fort-cache)
  (clear-monad-mt-naut-cache)
  (when (hlmts-supported?)
    ;; HLMT cache clearing would go here, but the Java body is empty
    )
  t)

(defun update-mt-relevance-cache (argument assertion)
  "[Cyc] Update the Mt relevance cache with information that ASSERTION is
being added to or removed from the KB."
  (declare (ignore argument assertion))
  (clear-mt-relevance-cache))

(defun bind-mt-indexicals (mt)
  (when (not (fort-p mt))
    ;; Java body empty for non-fort case (missing-larkc for indexical binding)
    )
  mt)

(defun monad-basemt? (mt basemt)
  (cond ((equal mt basemt) t)
        ((and (fort-p mt) (fort-p basemt))
         (monad-mt-fort-cache-base-mt mt basemt))
        (t
         ;; missing-larkc 31128 — likely handles NAUT-based mt comparison
         ;; (e.g. calling monad-mt-naut-cache-base-mt for non-fort mts)
         (missing-larkc 31128))))

;; (defun hlmt-basemt? (mt basemt) ...) -- active declareFunction (2 0), no body
;; (defun non-monad-basemt? (mt basemt) ...) -- active declareFunction (2 0), no body

(deflexical *mt-relevance-cache-unknown* :unknown)

;; (defun mt-relevance-cache-unknown-p (value) ...) -- active declareFunction (1 0), no body
;; (defun mt-relevance-cache-get (mt cache) ...) -- active declareFunction (2 0), no body
;; (defun mt-relevance-cache-set (mt value cache) ...) -- active declareFunction (3 0), no body
;; (defun mt-relevance-cache-remove (mt cache) ...) -- active declareFunction (2 0), no body
;; (defun mt-relevance-cache-base-mt (mt basemt cache update-fn) ...) -- active declareFunction (4 0), no body
;; (defun mt-relevance-cache-update (mt basemt old-value cache update-fn) ...) -- active declareFunction (5 0), no body

(defglobal *monad-mt-fort-cache* (new-cache 256 #'eq))

(defun monad-mt-fort-cache-base-mt (mt basemt)
  (multiple-value-bind (v-genl-mts entry?)
      (cache-get *monad-mt-fort-cache* mt)
    (unless entry?
      (setf v-genl-mts (construct-set-from-list (all-genl-mts mt) #'eq))
      (cache-set *monad-mt-fort-cache* mt v-genl-mts))
    (set-contents-member? basemt v-genl-mts)))

(defun clear-monad-mt-fort-cache ()
  (cache-clear *monad-mt-fort-cache*))

(defglobal *monad-mt-naut-cache* (new-cache 256 #'equal))

;; (defun monad-mt-naut-cache-base-mt (mt basemt) ...) -- active declareFunction (2 0), no body

(defun clear-monad-mt-naut-cache ()
  (cache-clear *monad-mt-naut-cache*))
