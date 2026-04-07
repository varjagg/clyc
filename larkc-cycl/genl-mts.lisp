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

;; (defun genl-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun min-genl-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun not-genl-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun max-not-genl-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun spec-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun leaf-mt? (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun max-spec-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun not-spec-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun min-not-spec-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun genl-mt-siblings (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun spec-mt-siblings (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body

(defun all-genl-mts (mt &optional (mt-mt *mt-mt*) tv)
  "[Cyc] Returns all genls of microtheory MT
   (ascending transitive closure; inexpensive)"
  (sbhl-all-forward-true-nodes (get-sbhl-module #$genlMt) mt mt-mt tv))

;; (defun all-spec-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun all-proper-genl-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun all-proper-spec-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun random-genl-mt (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun random-spec-mt (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun random-proper-genl-mt (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun random-proper-spec-mt (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun all-not-genl-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun all-not-spec-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun all-genl-mts-between (low-mt high-mt &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun union-all-genl-mts (mts &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun union-all-spec-mts (mts &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun all-dependent-spec-mts (mt &optional mt-mt tv) ...) -- active declareFunction (1 2), no body
;; (defun all-genl-mts-among (mt candidates &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun all-spec-mts-among (mt candidates &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun selected-genl-mts (fn mt &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun all-genl-mts-if (fn mt &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun all-spec-mts-if (fn mt &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun map-all-genl-mts (fn mt &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun map-all-spec-mts (fn mt &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun map-union-all-genl-mts (fn mt &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun map-all-genl-mts-of-all (fn mt &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun map-union-all-spec-mts (fn mt &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun map-all-spec-mts-of-all (fn mt &optional mt-mt tv) ...) -- active declareFunction (2 2), no body

(defun genl-mt? (spec genl &optional (mt-mt *mt-mt*) tv)
  "[Cyc] Is mt GENL a genl-mt of SPEC?
   (ascending transitive search; inexpensive)"
  (monad-genl-mt? spec genl mt-mt tv))

(defun proper-genl-mt? (spec genl &optional (mt-mt *mt-mt*) tv)
  "[Cyc]"
  (and (genl-mt? spec genl mt-mt tv)
       (not (genl-mt? genl spec mt-mt tv))))

(defun monad-genl-mt? (spec genl &optional (mt-mt *mt-mt*) tv)
  "[Cyc] Is monad mt GENL a genl-mt of SPEC?
   (ascending transitive search; inexpensive)"
  (let (result)
    (with-all-mts
      (setf result (sbhl-non-justifying-predicate-relation-p
                    (get-sbhl-module #$genlMt) spec genl mt-mt tv)))
    result))

;; (defun spec-mt? (genl spec &optional mt-mt tv) ...) -- active declareFunction (2 1), no body
;; (defun genl-mt-of? (genl spec &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun any-genl-mt? (spec genls &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun genl-mt-of-any? (genl specs &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun all-genl-mt? (spec genls &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun genl-mt-of-all? (genl specs &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun any-genl-mt-of-any? (specs genls &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun not-genl-mt? (spec not-genl &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun argue-not-genl-mt? (spec not-genl &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun not-spec-mt? (genl spec &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun not-any-genl-mt? (spec not-genls &optional mt-mt tv) ...) -- active declareFunction (2 2), no body
;; (defun mts-intersect? (mt-1 mt-2 &optional mt-mt) ...) -- active declareFunction (2 1), no body
;; (defun mts-explicitly-intersect? (mt-1 mt-2 &optional mt-mt) ...) -- active declareFunction (2 1), no body
;; (defun why-genl-mt? (spec genl &optional mt-mt tv behavior) ...) -- active declareFunction (2 3), no body
;; (defun why-monad-genl-mt? (spec genl &optional mt-mt tv behavior) ...) -- active declareFunction (2 3), no body
;; (defun any-just-of-genl-mt (spec genl &optional mt-mt) ...) -- active declareFunction (2 1), no body
;; (defun why-not-genl-mt? (spec genl &optional mt-mt tv behavior) ...) -- active declareFunction (2 3), no body
;; (defun any-just-of-not-genl-mt (spec genl &optional mt-mt) ...) -- active declareFunction (2 1), no body

;; all-base-mts is a globally-cached function (defun-cached pattern).
;; The body (all-base-mts-internal) is stripped, so the entire group is stubs:
;;   *all-base-mts-caching-state* — deflexical, caching state variable
;;   clear-all-base-mts (0 0) — clears the caching state
;;   remove-all-base-mts (1 0) — removes a single entry
;;   all-base-mts-internal (1 0) — the actual computation (stripped)
;;   all-base-mts (1 0) — the memoized wrapper
;; All have active declareFunction, no body.

;; Reconstructed from Internal Constants evidence:
;; $list15 = (MT &BODY BODY) — macro arglist
;; $sym16 = uninternedSymbol("BASE-MT") — gensym iteration variable
;; $sym17 = CDOLIST — expansion operator
;; $sym11 = ALL-BASE-MTS — called to get base mts
;; $sym18 = WITH-MT — wraps body in mt context
(defmacro do-base-mts (mt &body body)
  "[Cyc] Execute BODY in the context of each base mt of MT."
  (let ((base-mt (make-symbol "BASE-MT")))
    `(cdolist (,base-mt (all-base-mts ,mt))
       (with-mt ,base-mt ,@body))))

(defvar *min-mts-2-enabled?* nil
  "[Cyc] This controls whether or not MIN-MTS implements a special case for exactly 2 mts.")

(defun min-mts (mts &optional (mt-mt *mt-mt*))
  "[Cyc] The most-specific among microtheories MTS"
  (when *core-mt-optimization-enabled?*
    (setf mts (minimize-mts-wrt-core mts)))
  (when (and *min-mts-2-enabled?*
             (doubleton? mts))
    (return-from min-mts (missing-larkc 23011)))
  (sbhl-min-nodes (get-sbhl-module #$genlMt) mts mt-mt))

(defun min-mts-before-floors (mts &optional (mt-mt *mt-mt*))
  "[Cyc] Version of min-mts called inside max-floor-mts"
  (min-mts mts mt-mt))

;; (defun min-mts-2 (mt-a mt-b &optional mt-mt) ...) -- active declareFunction (2 1), no body
;; (defun max-mts (mts &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun max-mts-before-ceiling (mts &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun min-ceiling-mts (mts &optional candidates mt-mt) ...) -- active declareFunction (1 2), no body

(defun max-floor-mts (mts &optional candidates (mt-mt *mt-mt*))
  "[Cyc] The most general common specializations among microtheories MTS
   (if CANDIDATES is non-nil, then result is a subset of CANDIDATES)"
  (max-floor-monad-mts mts candidates mt-mt))

(defun-memoized max-floor-monad-mts (mts candidates mt-mt) (:test equal)
  "[Cyc] The most general common specializations among MTS, memoized in the current memoization state."
  (when mts
    (sbhl-max-floors (get-sbhl-module #$genlMt)
                     (min-mts-before-floors mts mt-mt)
                     candidates mt-mt)))

(defun max-floor-mts-with-cycles-pruned (mts &optional candidates (mt-mt *mt-mt*))
  "[Cyc] The most general common specializations among microtheories MT such that
   only one node from any given cycle is returned. If CANDIDATES is non-nil,
   the result is a subset of CANDIDATES."
  (max-floor-monad-mts-with-cycles-pruned mts candidates mt-mt))

(defun max-floor-monad-mts-with-cycles-pruned (mts candidates mt-mt)
  (when mts
    (sbhl-max-floors-pruning-cycles (get-sbhl-module #$genlMt)
                                    (min-mts-before-floors mts mt-mt)
                                    candidates mt-mt)))

;; cached-max-floor-mts-from-mt-sets is a globally-cached function (defun-cached pattern).
;; The body (cached-max-floor-mts-from-mt-sets-internal) is stripped, so the entire group is stubs:
;;   *cached-max-floor-mts-from-mt-sets-caching-state* — deflexical, caching state variable
;;   max-floor-mts-from-mt-sets (1 0) — public entry point
;;   clear-cached-max-floor-mts-from-mt-sets (0 0) — clears the caching state
;;   remove-cached-max-floor-mts-from-mt-sets (1 0) — removes a single entry
;;   cached-max-floor-mts-from-mt-sets-internal (1 0) — the actual computation (stripped)
;;   cached-max-floor-mts-from-mt-sets (1 0) — the memoized wrapper
;; All have active declareFunction, no body.
;; (defun max-floor-mts-of-genl-mt-paths (spec genl) ...) -- active declareFunction (2 0), no body
;; (defun genl-mt-mts (mt) ...) -- active declareFunction (1 0), no body
;; (defun asserted-genl-mts? (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun asserted-genl-mts (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun genl-mts-from-asserted-assertions (mt) ...) -- active declareFunction (1 0), no body
;; (defun asserted-not-genl-mts (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun supported-genl-mts (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun supported-not-genl-mts (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun asserted-spec-mts (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun asserted-not-spec-mts (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun supported-spec-mts (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun supported-not-spec-mts (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body

(defun add-base-mt (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (add-genl-mt source assertion))

(defun add-genl-mt (source assertion)
  "[Cyc] Modifier. Adds sbhl links with @see sbhl-after-adding."
  (sbhl-after-adding source assertion (get-sbhl-module #$genlMt))
  ;; after_adding_modules.clear_mt_dependent_caches — unported module
  (clear-mt-dependent-caches source assertion)
  nil)

(defun remove-base-mt (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (remove-genl-mt source assertion))

(defun remove-genl-mt (source assertion)
  "[Cyc] Modifier. Removes sbhl links with @see sbhl-after-removing."
  (sbhl-after-removing source assertion (get-sbhl-module #$genlMt))
  nil)

;; (defun clear-mt-graph () ...) -- active declareFunction (0 0), no body
;; (defun clear-node-genl-mt-links (node direction) ...) -- active declareFunction (2 0), no body
;; (defun reset-genl-mt-links (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun reset-mts-links (mt &optional mt-mt) ...) -- active declareFunction (1 1), no body
;; (defun reset-mts-links-in-mt (mt mt-mt) ...) -- active declareFunction (2 0), no body
;; (defun reset-mt-graph (&optional mt-mt) ...) -- active declareFunction (0 1), no body

;;; Setup phase

(register-cyc-api-function 'any-genl-mt?
    '(spec genls &optional (mt-mt *mt-mt*) tv)
    "(any-genl-mt? spec genls) is t iff (genl-mt? spec genl) for some genl in genls
   (ascending transitive search; inexpensive)"
    '((spec el-fort-p) (genls el-fort-p))
    '(booleanp))

(note-globally-cached-function 'all-base-mts)
(note-memoized-function 'max-floor-monad-mts)
(note-globally-cached-function 'cached-max-floor-mts-from-mt-sets)

(register-kb-function 'add-base-mt)
(register-kb-function 'add-genl-mt)
(register-kb-function 'remove-base-mt)
(register-kb-function 'remove-genl-mt)
