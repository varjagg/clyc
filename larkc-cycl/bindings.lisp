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

;; hl-identity-binding (singular) — all 4 memoization functions stripped
(deflexical *hl-identity-binding-caching-state* nil)

;; (defun clear-hl-identity-binding () ...) -- active declaration, no body
;; (defun remove-hl-identity-binding (n) ...) -- active declaration, no body
;; (defun hl-identity-binding-internal (n) ...) -- active declaration, no body
;; (defun hl-identity-binding (n) ...) -- active declaration, no body

;; (defun clear-hl-identity-bindings () ...) -- active declaration, no body
;; (defun remove-hl-identity-bindings (n) ...) -- active declaration, no body

(defun-cached hl-identity-bindings (n)
    (:test eql
     :initial-size 10
     :declare ((type (integer 0) n))
     :doc "[Cyc] Return bindings of the form ((?varN-1 . ?varN-1) ... (?var0 . ?var0))")
  (if (zerop n)
      nil
      (let* ((n-1 (1- n))
             (variable (find-variable-by-id n-1)))
        (add-variable-binding variable variable (hl-identity-bindings n-1)))))

(defun binding-p (object)
  "Return T iff OBJECT is a binding."
  (consp object))

;; (defun variable-to-variable-binding-p (object) ...) -- active declaration, no body
;; (defun bindings-p (object) ...) -- active declaration, no body

(defun binding-list-p (object)
  "[Cyc] @return boolean; t iff OBJECT is a binding list"
  (and (non-dotted-list-p object)
       (every-in-list #'binding-p object)))

;; (defun non-empty-binding-list-p (object) ...) -- active declaration, no body
;; (defun binding-lists-p (object) ...) -- active declaration, no body
;; (defun variable-map-p (object) ...) -- active declaration, no body

(defun inference-binding-p (object)
  "[Cyc] True if OBJECT is of the form (<el-var> . <whatever>)."
  (and (binding-p object)
       (el-var? (variable-binding-variable object))))

;; (defun inference-binding-set-p (object) ...) -- active declaration, no body
;; (defun inference-set-of-binding-sets-p (object) ...) -- active declaration, no body

(deflexical *el-inference-binding-fn* (reader-make-constant-shell "ELInferenceBindingFn"))

(defun kb-binding-p (object)
  "[Cyc] True if OBJECT is of the form (#$ELInferenceBindingFn <var> <whatever>)"
  (and (possibly-naut-p object)
       (eq (nat-functor object) *el-inference-binding-fn*)
       (el-var? (nat-arg1 object))))

(defun kb-binding-set-p (object)
  "[Cyc] True if OBJECT is of the form (#$TheSet [<kb-binding-p>])"
  (or (el-empty-set-p object)
      (and (possibly-naut-p object)
           (el-extensional-set-p object)
           (every-in-list #'kb-binding-p (nat-args object)))))

;; (defun kb-set-of-binding-sets-p (object) ...) -- active declaration, no body

(defun subst-bindings (bindings object)
  "[Cyc] Substitute the value of variables in bindings into object,
taking recursively bound variables into account."
  (if (binding-list-p bindings)
      (apply-bindings bindings object)
      object))

;; (defun equal-bindings (bindings-1 bindings-2) ...) -- active declaration, no body

(defun bindings-equal? (bindings-1 bindings-2)
  "[Cyc] Return T iff the binding lists BINDINGS-1 and BINDINGS-2 are equivalent"
  (fast-sets-equal? bindings-1 bindings-2 #'equal))

;; (defun lists-of-binding-lists-equal? (list1 list2) ...) -- active declaration, no body
;; (defun compare-lists-of-binding-lists (list1 list2) ...) -- active declaration, no body

(defun variable-bound-p (variable bindings)
  "[Cyc] Return T iff VARIABLE has some associated value in BINDINGS"
  (and (get-variable-binding variable bindings) t))

;; (defun variable-lookup (variable bindings) ...) -- active declaration, no body

(defun add-variable-binding (variable value bindings)
  "[Cyc] Add a new (VARIABLE . VALUE) variable-binding to BINDINGS"
  (cons (make-variable-binding variable value) bindings))

(defun make-variable-binding (variable value)
  "Construct a variable binding pair."
  (cons variable value))

(defun variable-binding-variable (binding)
  ;; NB: Java Javadoc says "Get the value part" — copy-paste bug; this is the variable accessor
  "[Cyc] Get the value part of a single binding."
  (car binding))

(defun variable-binding-value (binding)
  "[Cyc] Get the value part of a single binding."
  (cdr binding))

(defun get-variable-binding (variable bindings)
  "[Cyc] Return the variable-binding for VARIABLE in BINDINGS, or NIL if none."
  (assoc variable bindings))

(defun get-value-binding (value bindings &optional (test #'eql))
  "[Cyc] Return the variable-binding which binds something to VALUE, or NIL if none.
Assumes there is a unique one."
  (rassoc value bindings :test test))

;; (defun bindings-variables (bindings) ...) -- active declaration, no body
;; (defun bindings-values (bindings) ...) -- active declaration, no body
;; (defun apply-binding (binding tree) ...) -- active declaration, no body

(defun apply-bindings (bindings tree)
  "[Cyc] @param BINDINGS; A -> B
@return a modified version of TREE with all elements of A
replaced by corresponding elements of B"
  (declare (type (satisfies bindings-p) bindings))
  (sublis bindings tree))

(defun apply-bindings-to-values (bindings-to-apply target-bindings)
  "[Cyc] @param BINDINGS-TO-APPLY  ; A -> B
   @return a modified version of TARGET-BINDINGS with all elements of A in the values
 (cdrs) replaced by corresponding elements of B."
  (declare (type (satisfies bindings-p) bindings-to-apply target-bindings))
  (let ((modified-target-bindings nil))
    (dolist (target-binding target-bindings)
      (destructuring-bind (variable . value) target-binding
        (let* ((modified-value (apply-bindings bindings-to-apply value))
               (modified-target-binding (make-variable-binding variable modified-value)))
          (push modified-target-binding modified-target-bindings))))
    (nreverse modified-target-bindings)))

(defun apply-bindings-backwards (bindings tree)
  "[Cyc] @param BINDINGS; A -> B
@return a modified version of TREE with all elements of B
replaced by corresponding elements of A"
  (declare (type (satisfies bindings-p) bindings))
  (rsublis bindings tree))

;; (defun apply-bindings-backwards-to-values (bindings target-bindings) ...) -- active declaration, no body
;; (defun napply-binding (binding tree) ...) -- active declaration, no body

(defun napply-bindings (bindings tree)
  "[Cyc] A destructive version of @xref apply-bindings."
  (declare (type (satisfies bindings-p) bindings))
  (nsublis bindings tree :test #'eq))

;; (defun napply-bindings-backwards (bindings tree) ...) -- active declaration, no body

(defun napply-bindings-backwards-to-list (bindings list)
  "[Cyc] Like @xref napply-bindings-backwards that assumes a proper list rather than an arbitrary tree."
  (declare (type (satisfies bindings-p) bindings))
  (do ((cons list (cdr cons)))
      ((atom cons))
    (rplaca cons (nrsublis bindings (car cons))))
  list)

(defun transfer-variable-map-to-bindings (a-to-b-variable-map a-to-c-bindings)
  "[Cyc] @param A-TO-B-VARIABLE-MAP; A -> B
   @param A-TO-C-BINDINGS;     A -> C
   @return binding-list-p;     B -> C
Errors if A-TO-B-VARIABLE-MAP does not contain bindings for all As.
@example (transfer-variable-map-to-bindings '((?X . ?Y)) '((?X . #$Muffet))) -> ((?Y . #$Muffet))"
  (transfer-variable-map-to-bindings-int a-to-b-variable-map a-to-c-bindings t))

(defun transfer-variable-map-to-bindings-filtered (a-to-b-variable-map a-to-c-bindings)
  "[Cyc] @param A-TO-B-VARIABLE-MAP; A -> B
   @param A-TO-C-BINDINGS;     A -> C
   @return binding-list-p;     B -> C
Filters out bindings for which there is no binding to B in A-TO-B-VARIABLE-MAP.
@example (transfer-variable-map-to-bindings-filtered '((?X . ?Y)) '((?X . #$Muffet) (?Z . #$Dog))) -> ((?Y . #$Muffet))"
  (transfer-variable-map-to-bindings-int a-to-b-variable-map a-to-c-bindings nil))

;; (defun transfer-variable-map-to-bindings-backwards (a-to-b-variable-map b-to-c-bindings) ...) -- active declaration, no body
;; (defun transfer-variable-map-to-bindings-backwards-filtered (a-to-b-variable-map b-to-c-bindings) ...) -- active declaration, no body

(defun transfer-variable-map-to-bindings-int (a-to-b-variable-map a-to-c-bindings error-if-incomplete?)
  (declare (type (satisfies variable-map-p) a-to-b-variable-map)
           (type (satisfies bindings-p) a-to-c-bindings))
  (let ((result nil))
    (dolist (a-to-c-binding a-to-c-bindings)
      (destructuring-bind (a-var . c-value) a-to-c-binding
        (let ((a-to-b-binding (get-variable-binding a-var a-to-b-variable-map)))
          (when error-if-incomplete?
            (must (not (null a-to-b-binding))
                  "Incomplete variable map ~a applied to ~a"
                  a-to-b-variable-map a-to-c-bindings))
          (when a-to-b-binding
            (let ((b-var (variable-binding-value a-to-b-binding)))
              (setf result (add-variable-binding b-var c-value result)))))))
    (nreverse result)))

(defun compose-bindings (a-to-b-variable-map b-to-c-bindings)
  "[Cyc] @param A-TO-B-VARIABLE-MAP; A -> B
   @param B-TO-C-BINDINGS;     B -> C
   @return binding-list-p;     A -> C
Errors if A-TO-B-VARIABLE-MAP does not contain bindings for all Bs.
@example (compose-bindings '((?X . ?A) (?Y . ?B) (?Z . ?C)) '((?A . #$Cat) (?C . #$Dog))) -> ((?X . #$Cat) (?Z . #$Dog))"
  (compose-bindings-int a-to-b-variable-map b-to-c-bindings t))

(defun compose-bindings-filtered (a-to-b-variable-map b-to-c-bindings)
  "[Cyc] @param A-TO-B-VARIABLE-MAP; A -> B
   @param B-TO-C-BINDINGS;     B -> C
   @return binding-list-p;     A -> C
Filters out bindings for which there is no binding to B in A-TO-B-VARIABLE-MAP.
@example (compose-bindings-filtered '((?X . ?A) (?Y . ?B) (?Z . ?C)) '((?A . #$Cat) (?C . #$Dog) (?D . #$Horse))) -> ((?X . #$Cat) (?Z . #$Dog))"
  (compose-bindings-int a-to-b-variable-map b-to-c-bindings nil))

(defun compose-bindings-int (a-to-b-variable-map b-to-c-bindings error-if-incomplete?)
  (declare (type (satisfies variable-map-p) a-to-b-variable-map)
           (type (satisfies bindings-p) b-to-c-bindings))
  (let ((result nil))
    (dolist (b-to-c-binding b-to-c-bindings)
      (destructuring-bind (b-var . c-value) b-to-c-binding
        (let ((a-to-b-binding (get-value-binding b-var a-to-b-variable-map)))
          (when error-if-incomplete?
            (must (not (null a-to-b-binding))
                  "Incomplete variable map ~a applied to ~a"
                  a-to-b-variable-map b-to-c-bindings))
          (when a-to-b-binding
            (let ((a-var (variable-binding-variable a-to-b-binding)))
              (setf result (add-variable-binding a-var c-value result)))))))
    (nreverse result)))

(defun invert-bindings (bindings)
  "[Cyc] @param BINDINGS; A -> B
@return binding-list-p; B -> A"
  (flip-alist bindings))

(defun filter-bindings-by-variables (bindings variable-keep-list)
  "[Cyc] Filters out bindings from BINDINGS whose variables are not
members of VARIABLE-KEEP-LIST."
  (let ((filtered-bindings nil))
    (dolist (binding bindings)
      (destructuring-bind (variable . value) binding
        (declare (ignore value))
        (when (member? variable variable-keep-list)
          (push (make-variable-binding variable (variable-binding-value binding))
                filtered-bindings))))
    (nreverse filtered-bindings)))

(defun inference-simplify-unification-bindings (bindings)
  "Simplify unification bindings by removing inference-specific bindings."
  (when (find-if #'inference-binding-p bindings)
    (setf bindings (remove-if #'inference-binding-p bindings)))
  (when (unification-success-token-p bindings)
    (setf bindings nil))
  bindings)

(defun possibly-optimize-bindings-wrt-equivalence (old-bindings)
  "Optimize bindings by resolving transitive variable equivalences."
  (if (or (null old-bindings)
          (singleton? old-bindings))
      old-bindings
      (loop
        (let ((new-bindings nil))
          (dolist (binding old-bindings)
            (let ((old-value (variable-binding-value binding)))
              (when (not (fully-bound-p old-value))
                (let ((new-value (apply-bindings-backwards old-bindings old-value))
                      (variable (variable-binding-variable binding)))
                  (when (and (not (simple-tree-find? variable new-value))
                             (not (equal new-value old-value)))
                    (setf binding (make-variable-binding variable new-value))))))
            (push binding new-bindings))
          (setf new-bindings (nreverse new-bindings))
          (when (equal new-bindings old-bindings)
            (return old-bindings))
          (setf old-bindings new-bindings)))))

(defun bindings-to-closed (bindings)
  "[Cyc] All bindings in BINDINGS that bind a variable to a fully bound value."
  (remove-if-not #'fully-bound-p bindings :key #'variable-binding-value))

(defun stable-sort-bindings (bindings variables)
  "[Cyc] Sort BINDINGS via the variable order in VARIABLES"
  (stable-sort-via-position bindings variables #'eq #'variable-binding-variable))

;; (defun remove-dummy-binding (bindings) ...) -- active declaration, no body
;; (defun delete-dummy-binding (bindings) ...) -- active declaration, no body
;; (defun tree-find-dummy-binding? (tree) ...) -- active declaration, no body

(defglobal *dummy-binding* (make-variable-binding t t)
  "[Cyc] Dummy unification binding indicating unification success, with no variables.")

(deflexical *unification-success-token*
  (list *dummy-binding*)
  "[Cyc] Dummy unification binding list indicating unification success, with no variables.")

(defun unification-success-token ()
  "[Cyc] Return a token indicating successful unification without any substitution required."
  *unification-success-token*)

(defun unification-success-token-p (bindings)
  "[Cyc] Return T iff BINDINGS are a token indicating unification success without any substitution required."
  (equal bindings *unification-success-token*))

;; (defun variables-with-conflicting-bindings (bindings-1 bindings-2) ...) -- active declaration, no body
;; (defun some-variable-with-conflicting-bindings (bindings-1 bindings-2) ...) -- active declaration, no body
;; (defun inferencify-kb-set-of-binding-sets (object) ...) -- active declaration, no body
;; (defun inferencify-kb-set-of-binding-sets-internal (object) ...) -- active declaration, no body
;; (defun inferencify-kb-binding-set (object) ...) -- active declaration, no body
;; (defun inferencify-kb-binding-set-internal (object) ...) -- active declaration, no body
;; (defun inferencify-kb-binding (object) ...) -- active declaration, no body
;; (defun kbify-inference-set-of-binding-sets (object) ...) -- active declaration, no body
;; (defun kbify-inference-set-of-binding-sets-internal (object) ...) -- active declaration, no body
;; (defun kbify-inference-binding-set (object) ...) -- active declaration, no body
;; (defun kbify-inference-binding-set-internal (object) ...) -- active declaration, no body
;; (defun kbify-inference-binding (object) ...) -- active declaration, no body
;; (defun kb-binding-variable (binding) ...) -- active declaration, no body
;; (defun kb-binding-value (binding) ...) -- active declaration, no body
;; (defun kb-binding-set-variables (binding-set) ...) -- active declaration, no body
;; (defun kb-binding-set-values (binding-set) ...) -- active declaration, no body
;; (defun kb-binding-set-value-for-variable (binding-set variable) ...) -- active declaration, no body
;; (defun kb-set-of-binding-sets-values (set-of-binding-sets) ...) -- active declaration, no body
;; (defun kb-set-of-binding-sets-size (set-of-binding-sets) ...) -- active declaration, no body
;; (defun kb-set-of-binding-sets-binding-sets (set-of-binding-sets) ...) -- active declaration, no body

(deflexical *the-set* (reader-make-constant-shell "TheSet"))

(defun make-kb-binding (variable value)
  "[Cyc] @return a kb-binding-p, denoting a binding of VARIABLE to VALUE."
  (declare (type (satisfies el-var?) variable))
  (make-el-formula *el-inference-binding-fn* (list variable value)))

(defun make-kb-binding-set (bindings)
  "[Cyc] @return a kb-binding-set-p, consisting of BINDINGS."
  (must (every-in-list #'kb-binding-p bindings)
        "Some element of ~A is not a KB-BINDING-P" bindings)
  (make-el-formula *the-set* bindings))

(defun make-kb-set-of-binding-sets (binding-sets)
  "[Cyc] @return a kb-set-of-binding-sets-p, consisting of BINDING-SETS"
  (must (every-in-list #'kb-binding-set-p binding-sets)
        "Some element of ~A is not a KB-BINDING-SET-P" binding-sets)
  (make-el-formula *the-set* binding-sets))

;; (defun no-answers-kb-set-of-binding-sets () ...) -- active declaration, no body
;; (defun proven-kb-binding-set () ...) -- active declaration, no body
;; (defun proven-kb-set-of-binding-sets () ...) -- active declaration, no body
;; Setup phase
(note-globally-cached-function 'hl-identity-binding)
(declare-defglobal '*dummy-binding*)
