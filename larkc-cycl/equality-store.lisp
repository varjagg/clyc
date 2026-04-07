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

;;; Variables

(defglobal *some-equality-assertions-somewhere-set* nil)

;;; Functions — ordered per declare section

(defun some-equality-assertions? (obj &optional mt)
  "[Cyc] Return T iff OBJ is known to have any equality assertions."
  (declare (ignore mt))
  (when (fort-p obj)
    (and (some-equality-assertions-somewhere? obj)
         ;; missing-larkc 4402 — likely checks for equality assertions with a
         ;; specific truth value or in a specific mt, possibly
         ;; some-equality-assertions-with-truth? or similar predicate filter.
         ;; missing-larkc 4403 — likely a second filter for equality assertions,
         ;; possibly checking a different truth value or direction.
         (or (missing-larkc 4402)
             (missing-larkc 4403)))))

(defun some-equality-assertions-somewhere? (obj)
  "[Cyc] Return T iff OBJ is known to have any equality assertions stated about it at all."
  (when (fort-p obj)
    (unless (set-p *some-equality-assertions-somewhere-set*)
      (initialize-some-equality-assertions-somewhere-set))
    (set-member? obj *some-equality-assertions-somewhere-set*)))

(defun clear-some-equality-assertions-somewhere-set ()
  "[Cyc] Clear the set tracking which forts have equality assertions."
  (when *some-equality-assertions-somewhere-set*
    (clear-set *some-equality-assertions-somewhere-set*))
  nil)

(defun initialize-some-equality-assertions-somewhere-set ()
  "[Cyc] Initialize the set of forts that have equality assertions somewhere."
  (when (valid-constant? #$equals)
    (noting-progress ("Initializing some equality assertions somewhere...")
      (let ((estimated-size (* 2 (num-spec-pred-index #$equals))))
        (setf *some-equality-assertions-somewhere-set*
              (new-set #'eql estimated-size))
        (with-all-mts
          (dolist (spec-pred (all-spec-preds #$equals))
            (let ((pred-var spec-pred))
              (when (do-predicate-extent-index-key-validator pred-var)
                (let ((iterator-var (new-predicate-extent-final-index-spec-iterator pred-var))
                      (done-var nil)
                      (token-var nil))
                  (until done-var
                    (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                           (valid (not (eq token-var final-index-spec))))
                      (when valid
                        (let ((final-index-iterator nil))
                          (unwind-protect
                               (progn
                                 (setf final-index-iterator
                                       (new-final-index-iterator final-index-spec :gaf nil nil))
                                 (let ((done-var-2 nil)
                                       (token-var-3 nil))
                                   (until done-var-2
                                     (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-3))
                                            (valid-4 (not (eq token-var-3 ass))))
                                       (when valid-4
                                         (cache-some-equality-assertions-somewhere ass))
                                       (setf done-var-2 (not valid-4))))))
                            (when final-index-iterator
                              (destroy-final-index-iterator final-index-iterator)))))
                      (setf done-var (not valid)))))))))))))

;; (defun decache-some-equality-assertions-somewhere (arg1 arg2) ...) -- active declareFunction, no body

(defun cache-some-equality-assertions-somewhere (assertion)
  "[Cyc] Cache the args of an equality assertion into the somewhere set."
  (when (and (gaf-assertion? assertion)
             (assertion-arguments assertion))
    (let ((mt (assertion-mt assertion)))
      (when (valid-hlmt-p mt)
        (let ((arg1 (gaf-arg1 assertion))
              (arg2 (gaf-arg2 assertion)))
          (when (valid-fort? arg1)
            (set-add arg1 *some-equality-assertions-somewhere-set*))
          (when (valid-fort? arg2)
            (set-add arg2 *some-equality-assertions-somewhere-set*))))))
  nil)

;; (defun recache-some-equality-assertions-somewhere (arg1) ...) -- active declareFunction, no body
;; (defun some-source-rewrite-of-assertions? (obj &optional mt) ...) -- active declareFunction, no body

(defun some-source-rewrite-of-assertions-somewhere? (obj)
  "[Cyc] Return T iff OBJ is known to have any true #$rewriteOf assertions stated about it
where OBJ is the source arg (the one from which the propagation would occur).
Only works when OBJ is a fort."
  (when (fort-p obj)
    (some-pred-assertion-somewhere? #$rewriteOf obj 2)))

;;; Internal Constants accounting:
;;   $const0$equals = #$equals — used in initialize-some-equality-assertions-somewhere-set
;;   $kw1$TRUE = :true — orphan constant, likely used in stripped bodies of
;;     some-source-rewrite-of-assertions? or decache/recache functions
;;   $sym2$*SOME-EQUALITY-ASSERTIONS-SOMEWHERE-SET* — used in init (defglobal) and setup (declare-defglobal)
;;   $str3 = "Initializing some equality assertions somewhere..." — used in initialize function
;;   $sym4$RELEVANT_MT_IS_EVERYTHING — used in initialize function (with-all-mts expansion)
;;   $const5$EverythingPSC — used in initialize function (with-all-mts expansion)
;;   $kw6$GAF = :gaf — used in initialize function
;;   $sym7$DECACHE_SOME_EQUALITY_ASSERTIONS_SOMEWHERE — used in setup (register-kb-function)
;;   $const8$rewriteOf = #$rewriteOf — used in some-source-rewrite-of-assertions-somewhere?

;;; Setup

(toplevel
  (declare-defglobal '*some-equality-assertions-somewhere-set*)
  (register-kb-function 'decache-some-equality-assertions-somewhere))
