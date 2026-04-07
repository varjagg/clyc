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

(defun cached-spec-pred? (genl spec &optional (mt *mt*))
  "[Cyc] Return whether SPEC is a spec-predicate of GENL."
  (if (and (fort-p genl)
           (fort-p spec))
      (fort-cache-spec-pred? genl spec mt)
      ;; missing-larkc 32012 — non-fort branch likely calls naut-cache-spec-pred?
      ;; using the *spec-pred-naut-cache*, paralleling the fort path
      (missing-larkc 32012)))

(defun cached-spec-inverse? (genl spec &optional (mt *mt*))
  "[Cyc] Return whether SPEC is a spec-inverse of GENL."
  (if (and (fort-p genl)
           (fort-p spec))
      (fort-cache-spec-inverse? genl spec mt)
      ;; missing-larkc 32011 — non-fort branch likely calls naut-cache-spec-inverse?
      ;; using the *spec-inverse-naut-cache*, paralleling the fort path
      (missing-larkc 32011)))

;; (defun cached-genl-pred? (genl spec &optional mt) ...) -- active declareFunction (2 1), no body
;; (defun cached-genl-inverse? (genl spec &optional mt) ...) -- active declareFunction (2 1), no body

(defun clear-predicate-relevance-cache ()
  "[Cyc] Clear the predicate relevance cache."
  (clear-spec-pred-fort-cache)
  (clear-spec-pred-naut-cache)
  (clear-spec-inverse-fort-cache)
  (clear-spec-inverse-naut-cache)
  (clear-genl-pred-fort-cache)
  (clear-genl-pred-naut-cache)
  (clear-genl-inverse-fort-cache)
  (clear-genl-inverse-naut-cache)
  nil)

(deflexical *pred-relevance-cache-size* 128)

(defglobal *spec-pred-fort-cache* (new-cache *pred-relevance-cache-size* #'equal))
(defglobal *spec-inverse-fort-cache* (new-cache *pred-relevance-cache-size* #'equal))
(defglobal *genl-pred-fort-cache* (new-cache *pred-relevance-cache-size* #'equal))
(defglobal *genl-inverse-fort-cache* (new-cache *pred-relevance-cache-size* #'equal))
(defglobal *spec-pred-naut-cache* (new-cache *pred-relevance-cache-size* #'equal))
(defglobal *spec-inverse-naut-cache* (new-cache *pred-relevance-cache-size* #'equal))
(defglobal *genl-pred-naut-cache* (new-cache *pred-relevance-cache-size* #'equal))
(defglobal *genl-inverse-naut-cache* (new-cache *pred-relevance-cache-size* #'equal))

(defun fort-cache-relevant-pred? (v-cache key-pred relevant-pred mt update-function)
  "[Cyc] Check if RELEVANT-PRED is a relevant predicate of KEY-PRED in the given cache."
  (let ((key (list key-pred mt)))
    (multiple-value-bind (relevant-predicates entry?)
        (cache-get v-cache key)
      (unless entry?
        (setf relevant-predicates (update-relevant-pred-fort-cache update-function key-pred mt))
        (cache-set v-cache key relevant-predicates))
      (set-contents-member? relevant-pred relevant-predicates))))

(defun update-relevant-pred-fort-cache (update-function pred mt)
  "[Cyc] Compute the set of relevant predicates for PRED using UPDATE-FUNCTION."
  (cond ((eq update-function 'all-spec-predicates)
         (construct-set-from-list (all-spec-predicates pred mt) #'eq))
        ((eq update-function 'all-spec-inverses)
         (construct-set-from-list (all-spec-inverses pred mt) #'eq))
        ((eq update-function 'all-genl-predicates)
         (construct-set-from-list (all-genl-predicates pred mt) #'eq))
        ((eq update-function 'all-genl-inverses)
         (construct-set-from-list (all-genl-inverses pred mt) #'eq))
        (t
         (construct-set-from-list (funcall update-function pred mt) #'eq))))

;; (defun naut-cache-relevant-pred? (v-cache key-pred relevant-pred mt update-function) ...) -- active declareFunction (5 0), no body
;; (defun update-relevant-pred-naut-cache (update-function pred mt naut) ...) -- active declareFunction (4 0), no body

(defun fort-cache-spec-pred? (genl spec mt)
  "[Cyc] Check if SPEC is a spec-predicate of GENL using the fort cache."
  (fort-cache-relevant-pred? *spec-pred-fort-cache* genl spec mt 'all-spec-predicates))

;; (defun naut-cache-spec-pred? (genl spec mt) ...) -- active declareFunction (3 0), no body

(defun clear-spec-pred-fort-cache ()
  (cache-clear *spec-pred-fort-cache*))

(defun clear-spec-pred-naut-cache ()
  (cache-clear *spec-pred-naut-cache*))

(defun fort-cache-spec-inverse? (genl spec mt)
  "[Cyc] Check if SPEC is a spec-inverse of GENL using the fort cache."
  (fort-cache-relevant-pred? *spec-inverse-fort-cache* genl spec mt 'all-spec-inverses))

;; (defun naut-cache-spec-inverse? (genl spec mt) ...) -- active declareFunction (3 0), no body

(defun clear-spec-inverse-fort-cache ()
  (cache-clear *spec-inverse-fort-cache*))

(defun clear-spec-inverse-naut-cache ()
  (cache-clear *spec-inverse-naut-cache*))

;; (defun fort-cache-genl-pred? (genl spec mt) ...) -- active declareFunction (3 0), no body
;; (defun naut-cache-genl-pred? (genl spec mt) ...) -- active declareFunction (3 0), no body

(defun clear-genl-pred-fort-cache ()
  (cache-clear *genl-pred-fort-cache*))

(defun clear-genl-pred-naut-cache ()
  (cache-clear *genl-pred-naut-cache*))

;; (defun fort-cache-genl-inverse? (genl spec mt) ...) -- active declareFunction (3 0), no body
;; (defun naut-cache-genl-inverse? (genl spec mt) ...) -- active declareFunction (3 0), no body

;; FIXED: Java bug — both of these cleared the *spec-inverse-* caches instead of
;; the *genl-inverse-* caches. Never caught because the genl-inverse lookup functions
;; (fort-cache-genl-inverse?, naut-cache-genl-inverse?) are stripped stubs, so these
;; caches were never populated, and the only caller (clear-predicate-relevance-cache)
;; clears all 8 caches together, masking that spec-inverse got double-cleared.
(defun clear-genl-inverse-fort-cache ()
  (cache-clear *genl-inverse-fort-cache*))

(defun clear-genl-inverse-naut-cache ()
  (cache-clear *genl-inverse-naut-cache*))
