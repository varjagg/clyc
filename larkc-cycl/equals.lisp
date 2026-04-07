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

;; Functions — following declare_equals_file() ordering

;; (defun all-equals (obj &optional mt tv) ...) -- active declareFunction, no body

(defun equals? (obj1 obj2 &optional mt tv)
  "[Cyc] Test whether OBJ1 and OBJ2 are equal."
  (or (equal obj1 obj2)
      (cond
        ((fort-p obj1)
         (if (fort-p obj2)
             (equal-forts? obj1 obj2 mt tv)
             (equal-fort? obj1 obj2 mt tv)))
        ((fort-p obj2)
         (equal-fort? obj2 obj1 mt tv))
        (t nil))))

;; (defun why-equals (obj1 obj2 &optional mt tv) ...) -- active declareFunction, no body

(defun equal-fort? (fort non-fort &optional mt tv)
  "[Cyc] Check if FORT is equal to NON-FORT."
  (let ((ans nil))
    (when (and *perform-equals-unification*
               (not (meta-variable-p non-fort))
               (some-equality-assertions? fort))
      (setf ans (gt-predicate-relation-p #$equals fort non-fort mt tv)))
    ans))

(defun equal-forts? (fort1 fort2 &optional mt tv)
  "[Cyc] Check if FORT1 is equal to FORT2."
  (let ((ans nil))
    (when (and *perform-equals-unification*
               (some-equality-assertions-somewhere? fort1)
               (some-equality-assertions-somewhere? fort2)
               (some-equality-assertions? fort1)
               (some-equality-assertions? fort2))
      (setf ans (gt-predicate-relation-p #$equals fort1 fort2 mt tv)))
    ans))

;; (defun max-floor-mts-where-equals (obj1 obj2) ...) -- active declareFunction, no body
;; (defun max-floor-mts-where-equals-fort (fort non-fort) ...) -- active declareFunction, no body
;; (defun max-floor-mts-where-equals-non-forts (obj1 obj2) ...) -- active declareFunction, no body
;; (defun equal-everywhere? (obj1 obj2) ...) -- active declareFunction, no body
;; (defun equal-somewhere? (obj1 obj2) ...) -- active declareFunction, no body
;; (defun direct-rewrite-of? (fort1 fort2 &optional mt) ...) -- active declareFunction, no body
;; (defun any-direct-rewrite-of? (fort1 fort2 &optional mt) ...) -- active declareFunction, no body
;; (defun simplest-forts-wrt-rewrite (fort &optional mt) ...) -- active declareFunction, no body

(defun different? (objects &optional unknown-value)
  (let ((result t)
        (failure? nil))
    (do ((object (first objects) (first other-objects))
         (other-objects (rest objects) (rest other-objects)))
        ((or failure? (null other-objects))
         result)
      (unless failure?
        (dolist (other-object other-objects)
          (when failure? (return))
          (let ((different (different?-binary object other-object unknown-value)))
            (cond
              ((eq different unknown-value)
               (setf failure? t)
               (setf result unknown-value))
              ((null different)
               (setf failure? t)
               (setf result nil)))))))))

(defun different?-binary (obj1 obj2 &optional unknown-value)
  (cond
    ((term-unify obj1 obj2) nil)
    ((and (subl-strict-atomic-term-p obj1)
          (subl-strict-atomic-term-p obj2))
     t)
    ((and (unique-names-assumption-applicable-to-term? obj1)
          (unique-names-assumption-applicable-to-term? obj2))
     t)
    ;; missing-larkc 29996 — likely asserted-different? checking for
    ;; explicit #$different assertions between obj1 and obj2
    ((missing-larkc 29996) t)
    ;; missing-larkc 29998 — likely different-by-disjointness? checking
    ;; whether obj1 and obj2 belong to disjoint collections
    ((missing-larkc 29998) t)
    (t unknown-value)))

;; (defun asserted-different? (obj1 obj2) ...) -- active declareFunction, no body
;; (defun find-different-assertion (obj1 obj2) ...) -- active declareFunction, no body
;; (defun different-by-disjointness? (obj1 obj2) ...) -- active declareFunction, no body
;; (defun different-by-disjointness?-rep-unrep (obj1 obj2) ...) -- active declareFunction, no body

(defun why-different (objects)
  (let ((justification nil)
        (failure? nil))
    (do ((object (first objects) (first other-objects))
         (other-objects (rest objects) (rest other-objects)))
        ((or failure? (null other-objects))
         (fast-delete-duplicates justification #'equal))
      (unless failure?
        (dolist (other-object other-objects)
          (when failure? (return))
          (let ((binary-justification (why-different-binary object other-object)))
            (if binary-justification
                (setf justification (nconc justification binary-justification))
                (progn
                  (setf justification nil)
                  (setf failure? t)))))))))

(defun why-different-binary (obj1 obj2)
  (cond
    ((term-unify obj1 obj2) nil)
    ((and (subl-strict-atomic-term-p obj1)
          (subl-strict-atomic-term-p obj2))
     (let ((support (make-hl-support :opaque (make-binary-formula #$different obj1 obj2))))
       (list support)))
    ((and (unique-names-assumption-applicable-to-term? obj1)
          (unique-names-assumption-applicable-to-term? obj2))
     (let ((support (make-hl-support :opaque (make-binary-formula #$different obj1 obj2))))
       (list support)))
    ;; missing-larkc 29997 — likely asserted-different? check
    ((missing-larkc 29997)
     ;; missing-larkc 30003 — likely why-asserted-different
     (missing-larkc 30003))
    ;; missing-larkc 29999 — likely different-by-disjointness? check
    ((missing-larkc 29999)
     ;; missing-larkc 30004 — likely why-different-by-disjointness
     (missing-larkc 30004))
    (t nil)))

;; (defun why-asserted-different (obj1 obj2) ...) -- active declareFunction, no body
;; (defun why-different-by-disjointness (obj1 obj2) ...) -- active declareFunction, no body
;; (defun why-different-by-disjointness-rep-unrep (obj1 obj2) ...) -- active declareFunction, no body

(defun unique-names-assumption-applicable-to-term? (v-term)
  "[Cyc] Return whether the Unique Names Assumption applies to TERM."
  (if (valid-constant? #$TermExemptFromUniqueNamesAssumption)
      ;; missing-larkc 7013 — likely isa? check whether v-term is an instance
      ;; of #$TermExemptFromUniqueNamesAssumption; UNA applies if NOT exempt
      (not (missing-larkc 7013))
      (not (inference-indeterminate-term? v-term))))

(defun unique-names-assumption-applicable-to-all-args? (formula)
  "[Cyc] Return t iff the UNA is applicable to all arguments of FORMULA."
  (let ((failure? nil))
    (dolist (arg (formula-args formula :ignore))
      (when failure? (return))
      (unless (unique-names-assumption-applicable-to-term? arg)
        (setf failure? t)))
    (not failure?)))

(defun unique-names-assumption-applicable-to-all-args-except? (formula argnum)
  "[Cyc] Return t iff the UNA is applicable to all arguments of FORMULA except the ARGNUMth argument.
The UNA may or may not be applicable to the ARGNUMth argument; this function is agnostic."
  (let ((failure? nil)
        (n 0))
    (dolist (arg (formula-args formula :ignore))
      (when failure? (return))
      (incf n)
      (unless (or (eql n argnum)
                  (unique-names-assumption-applicable-to-term? arg))
        (setf failure? t)))
    (not failure?)))
