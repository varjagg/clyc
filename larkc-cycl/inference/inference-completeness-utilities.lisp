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

;; (defun inference-minimize-extent?-internal (predicate) ...) -- commented declareFunction, no body
;; (defun inference-minimize-extent? (predicate) ...) -- commented declareFunction, no body

;; (defun inference-complete-extent-asserted? (predicate mt) ...) -- commented declareFunction, no body

(defun inference-complete-extent-asserted-gaf (predicate mt)
  "[Cyc] Return nil or gaf-assertion?; a gaf assertion justifying
the fact that PREDICATE's extent is completely asserted in MT and its genlMts.
If there is more than one such assertion, the inferentially strongest one will be returned."
  (setf mt (completeness-constraint-mt mt))
  (let ((gaf nil))
    (let ((mt-var (with-inference-mt-relevance-validate mt)))
      (let ((*mt* (update-inference-mt-relevance-mt mt-var))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
        (setf gaf (complete-extent-asserted-gaf predicate))))
    gaf))

;; (defun inference-complete-extent-asserted-for-value-in-arg? (predicate value argnum mt) ...) -- commented declareFunction, no body
;; (defun inference-complete-extent-asserted-for-value-in-arg-gaf (predicate value argnum mt) ...) -- commented declareFunction, no body

(defun-memoized inference-complete-extent-asserted-for-value-in-arg-gafs
    (predicate value argnum mt) (:test eq)
  "[Cyc] Return list of gaf-assertion?; a list of gaf assertions, each of which independently
justify the fact that PREDICATE's extent for VALUE in ARGNUM is completely asserted in MT and its genlMts.
The list of assertions is returned in a partial order of strength, with the inferentially
strongest assertion first."
  (setf mt (completeness-constraint-mt mt))
  (let ((gafs nil))
    (let ((stronger-gaf (inference-complete-extent-asserted-gaf predicate mt)))
      (when stronger-gaf
        (push stronger-gaf gafs)))
    (let ((mt-var (with-inference-mt-relevance-validate mt)))
      (let ((*mt* (update-inference-mt-relevance-mt mt-var))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
        (let ((gaf (complete-extent-asserted-for-value-in-arg-gaf predicate value argnum)))
          (when gaf
            (push gaf gafs)))))
    (nreverse gafs)))

;; (defun inference-complete-extent-enumerable? (predicate mt) ...) -- commented declareFunction, no body
;; (defun inference-complete-extent-enumerable-gaf (predicate mt) ...) -- commented declareFunction, no body

(defun-memoized inference-complete-extent-enumerable-gafs (predicate mt) (:test eq)
  "[Cyc] Return list of gaf-assertion?; a list of gaf assertions, each of which independently
justify the fact that PREDICATE's extent is completely enumerable in MT.
The list of assertions is returned in a partial order of strength, with the inferentially
strongest assertion first."
  (setf mt (completeness-constraint-mt mt))
  (let ((gafs nil))
    (let ((stronger-gaf (inference-complete-extent-asserted-gaf predicate mt)))
      (when stronger-gaf
        (push stronger-gaf gafs)))
    (let ((mt-var (with-inference-mt-relevance-validate mt)))
      (let ((*mt* (update-inference-mt-relevance-mt mt-var))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
        (let ((gaf (complete-extent-enumerable-gaf predicate)))
          (when gaf
            (push gaf gafs)))))
    (nreverse gafs)))

;; (defun inference-complete-extent-decidable? (predicate mt) ...) -- commented declareFunction, no body
;; (defun inference-complete-extent-decidable-gaf (predicate mt) ...) -- commented declareFunction, no body

(defun-memoized inference-complete-extent-decidable-gafs (predicate mt) (:test eq)
  "[Cyc] Return list of gaf-assertion?; a list of gaf assertions, each of which independently
justify the fact that PREDICATE's extent is completely decidable in MT.
The list of assertions is returned in a partial order of strength, with the inferentially
strongest assertion first."
  (setf mt (completeness-constraint-mt mt))
  (let ((gafs nil))
    (dolist (stronger-gaf (inference-complete-extent-enumerable-gafs predicate mt))
      (push stronger-gaf gafs))
    (let ((mt-var (with-inference-mt-relevance-validate mt)))
      (let ((*mt* (update-inference-mt-relevance-mt mt-var))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
        (let ((gaf (complete-extent-decidable-gaf predicate)))
          (when gaf
            (push gaf gafs)))))
    (nreverse gafs)))

;; (defun inference-complete-extent-enumerable-for-arg? (predicate argnum mt) ...) -- commented declareFunction, no body
;; (defun inference-complete-extent-enumerable-for-arg-gaf (predicate argnum mt) ...) -- commented declareFunction, no body

(defun-memoized inference-complete-extent-enumerable-for-arg-gafs
    (predicate argnum mt) (:test eq)
  "[Cyc] Return list of gaf-assertion?; a list of gaf assertions, each of which independently
justify the fact that PREDICATE's extent is completely enumerable for ARGNUM in MT.
The list of assertions is returned in a partial order of strength, with the inferentially
strongest assertion first."
  (setf mt (completeness-constraint-mt mt))
  (let ((gafs nil))
    (dolist (stronger-gaf (inference-complete-extent-enumerable-gafs predicate mt))
      (push stronger-gaf gafs))
    (let ((mt-var (with-inference-mt-relevance-validate mt)))
      (let ((*mt* (update-inference-mt-relevance-mt mt-var))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
        (let ((gaf (complete-extent-enumerable-for-arg-gaf predicate argnum)))
          (when gaf
            (push gaf gafs)))))
    (nreverse gafs)))

;; (defun inference-complete-extent-enumerable-for-value-in-arg? (predicate value argnum mt) ...) -- commented declareFunction, no body
;; (defun inference-complete-extent-enumerable-for-value-in-arg-gaf (predicate value argnum mt) ...) -- commented declareFunction, no body

(defun-memoized inference-complete-extent-enumerable-for-value-in-arg-gafs
    (predicate value argnum mt) (:test eq)
  "[Cyc] Return list of gaf-assertion?; a list of gaf assertions, each of which independently
justify the fact that PREDICATE's extent is completely enumerable for VALUE in ARGNUM in MT.
The list of assertions is returned in a partial order of strength, with the inferentially
strongest assertion first."
  (setf mt (completeness-constraint-mt mt))
  (let ((gafs nil))
    (dolist (stronger-gaf (inference-complete-extent-asserted-for-value-in-arg-gafs
                           predicate value argnum mt))
      (push stronger-gaf gafs))
    (dolist (stronger-gaf (inference-complete-extent-enumerable-for-arg-gafs
                           predicate argnum mt))
      (push stronger-gaf gafs))
    (let ((mt-var (with-inference-mt-relevance-validate mt)))
      (let ((*mt* (update-inference-mt-relevance-mt mt-var))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
        (let ((gaf (complete-extent-enumerable-for-value-in-arg-gaf
                    predicate value argnum)))
          (when gaf
            (push gaf gafs)))))
    (nreverse gafs)))

;; (defun inference-complete-extent-decidable-for-value-in-arg? (predicate value argnum mt) ...) -- commented declareFunction, no body
;; (defun inference-complete-extent-decidable-for-value-in-arg-gaf (predicate value argnum mt) ...) -- commented declareFunction, no body

(defun-memoized inference-complete-extent-decidable-for-value-in-arg-gafs
    (predicate value argnum mt) (:test eq)
  "[Cyc] Return list of gaf-assertion?; a list of gaf assertions, each of which independently
justify the fact that PREDICATE's extent is completely decidable for ARGNUM in MT.
The list of assertions is returned in a partial order of strength, with the inferentially
strongest assertion first."
  (setf mt (completeness-constraint-mt mt))
  (let ((gafs nil))
    (dolist (stronger-gaf (inference-complete-extent-enumerable-for-value-in-arg-gafs
                           predicate value argnum mt))
      (push stronger-gaf gafs))
    (let ((mt-var (with-inference-mt-relevance-validate mt)))
      (let ((*mt* (update-inference-mt-relevance-mt mt-var))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
        (let ((gaf (complete-extent-decidable-for-value-in-arg-gaf
                    predicate value argnum)))
          (when gaf
            (push gaf gafs)))))
    (nreverse gafs)))

;; (defun inference-completely-enumerable-collection? (collection mt) ...) -- commented declareFunction, no body

(defun inference-completely-enumerable-collection-gaf (collection mt)
  "[Cyc] Return nil or gaf-assertion?; a gaf assertion justifying
the fact that COLLECTION is completely enumerable in MT.
If there is more than one such assertion, the inferentially strongest one will be returned."
  (setf mt (completeness-constraint-mt mt))
  (let ((gaf nil))
    (let ((mt-var (with-inference-mt-relevance-validate mt)))
      (let ((*mt* (update-inference-mt-relevance-mt mt-var))
            (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
            (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
        (setf gaf (completely-enumerable-collection-gaf collection))))
    gaf))

;; (defun inference-completely-decidable-collection? (collection mt) ...) -- commented declareFunction, no body
;; (defun inference-completely-decidable-collection-gaf (collection mt) ...) -- commented declareFunction, no body
;; (defun inference-completely-decidable-collection-gafs-internal (collection mt) ...) -- commented declareFunction, no body
;; (defun inference-completely-decidable-collection-gafs (collection mt) ...) -- commented declareFunction, no body

(defun inference-complete-asent? (asent mt)
  "[Cyc] Return boolean; whether all bindings for free variables in ASENT
can be completely enumerated in MT.  If ASENT is closed, return
whether the truth of ASENT can be completely decided with no transformation."
  (if (fully-bound-p asent)
      (inference-completely-decidable-asent? asent mt)
      (inference-completely-enumerable-asent? asent mt)))

(defun inference-completely-asserted-asent? (asent mt)
  "[Cyc] Return boolean; whether all bindings for free variables in ASENT
are completely asserted in MT.  If ASENT is closed, return
whether the truth of ASENT can be completely decided via assertion lookup."
  (sublisp-boolean (inference-completely-asserted-asent-gaf asent mt)))

(defun inference-completely-asserted-asent-gaf (asent mt)
  "[Cyc] Return nil or gaf-assertion?; if all bindings for free variables in ASENT
are completely asserted in MT, or if ASENT is closed and its
truth can be completely decided via assertion lookup, return a gaf
assertion justifying this claim."
  (first (inference-completely-asserted-asent-gafs asent mt)))

(defun inference-completely-asserted-asent-gafs (asent mt)
  "[Cyc] Return list of gaf-assertion?; if all bindings for free variables in ASENT
are completely asserted in MT, or if ASENT is closed and its
truth can be completely decided via assertion lookup, return a list of
gaf assertion justifying this claim.  The list of assertions is returned
in a partial order of strength, with the inferentially strongest assertion first."
  (setf mt (completeness-constraint-mt mt))
  (let ((result-gafs nil)
        (predicate (atomic-sentence-predicate asent)))
    (when (fort-p predicate)
      (let ((gaf (inference-complete-extent-asserted-gaf predicate mt)))
        (when (unique-names-assumption-applicable-to-all-args? asent)
          (when gaf
            (push gaf result-gafs))))
      (let ((terms (formula-terms asent :ignore))
            (argnum 0))
        (dolist (value terms)
          (when (fully-bound-p value)
            (let ((gafs (inference-complete-extent-asserted-for-value-in-arg-gafs
                         predicate value argnum mt)))
              (when gafs
                (when (unique-names-assumption-applicable-to-all-args-except? asent argnum)
                  (dolist (gaf gafs)
                    (pushnew gaf result-gafs :test #'eq))))))
          (setf argnum (1+ argnum)))))
    (nreverse result-gafs)))

(defun inference-completely-enumerable-asent? (asent mt)
  "[Cyc] Return boolean; whether all bindings for free variables in ASENT
can be completely enumerated in MT.  If ASENT is closed, return
whether the truth of ASENT can be completely decided with no transformation."
  (sublisp-boolean (inference-completely-enumerable-asent-gaf asent mt)))

(defun inference-completely-enumerable-asent-gaf (asent mt)
  "[Cyc] Return nil or gaf-assertion?; if all bindings for free variables in ASENT
can be completely enumerated in MT, or if ASENT is closed and its
truth can be completely decided with no transformation, return a gaf
assertion justifying this claim."
  (inference-completely-enumerable-asent-gafs asent mt))

(defun inference-completely-enumerable-asent-gafs (asent mt)
  "[Cyc] Return list of gaf-assertion?; if all bindings for free variables in ASENT
can be completely enumerated in MT, or if ASENT is closed and its
truth can be completely decided with no transformation, return a list of gaf
assertions justifying this claim.  The list of assertions is returned
in a partial order of strength, with the inferentially strongest assertion first."
  (setf mt (completeness-constraint-mt mt))
  (let ((result-gafs nil)
        (predicate (atomic-sentence-predicate asent)))
    (when (fort-p predicate)
      (let ((gafs (inference-complete-extent-enumerable-gafs predicate mt)))
        (when gafs
          (when (unique-names-assumption-applicable-to-all-args? asent)
            (dolist (gaf gafs)
              (push gaf result-gafs)))))
      (when (eq (reader-make-constant-shell "isa") predicate)
        (let ((collection (atomic-sentence-arg2 asent)))
          (when (fort-p collection)
            (let ((gaf (inference-completely-enumerable-collection-gaf collection mt)))
              (when gaf
                (when (unique-names-assumption-applicable-to-term?
                       (atomic-sentence-arg1 asent))
                  (push gaf result-gafs)))))))
      (let ((terms (formula-terms asent :ignore))
            (argnum 0))
        (dolist (value terms)
          (when (fully-bound-p value)
            (let ((gafs (inference-complete-extent-enumerable-for-arg-gafs
                         predicate argnum mt)))
              (when gafs
                (when (unique-names-assumption-applicable-to-all-args-except? asent argnum)
                  (dolist (gaf gafs)
                    (pushnew gaf result-gafs :test #'eq))))))
          (setf argnum (1+ argnum))))
      (let ((terms (formula-terms asent :ignore))
            (argnum 0))
        (dolist (value terms)
          (when (fully-bound-p value)
            (let ((gafs (inference-complete-extent-enumerable-for-value-in-arg-gafs
                         predicate value argnum mt)))
              (when gafs
                (when (unique-names-assumption-applicable-to-all-args-except? asent argnum)
                  (dolist (gaf gafs)
                    (pushnew gaf result-gafs :test #'eq))))))
          (setf argnum (1+ argnum)))))
    (nreverse result-gafs)))

(defun inference-completely-decidable-asent? (asent mt)
  "[Cyc] Return boolean; whether the truth of ASENT can be completely decided with no transformation."
  (sublisp-boolean (inference-completely-decidable-asent-gaf asent mt)))

(defun inference-completely-decidable-asent-gaf (asent mt)
  "[Cyc] Return nil or gaf-assertion?; if the truth of ASENT can be completely decided with no transformation,
return a gaf assertion justifying this claim."
  (first (inference-completely-decidable-asent-gafs asent mt)))

(defun inference-completely-decidable-asent-gafs (asent mt)
  "[Cyc] Return nil or gaf-assertion?; if the truth of ASENT can be completely decided with no transformation,
return a list of gaf assertions justifying this claim.  The list of assertions is returned
in a partial order of strength, with the inferentially strongest assertion first."
  (setf mt (completeness-constraint-mt mt))
  (let ((result-gafs nil)
        (predicate (atomic-sentence-predicate asent)))
    (when (fort-p predicate)
      ;; enumerable gafs (first block)
      (let ((gafs (inference-complete-extent-enumerable-gafs predicate mt)))
        (when gafs
          (when (unique-names-assumption-applicable-to-all-args? asent)
            (dolist (gaf gafs)
              (push gaf result-gafs)))))
      ;; isa + completely-enumerable-collection check
      (when (eq (reader-make-constant-shell "isa") predicate)
        (let ((collection (atomic-sentence-arg2 asent)))
          (when (fort-p collection)
            (let ((gaf (inference-completely-enumerable-collection-gaf collection mt)))
              (when gaf
                (when (unique-names-assumption-applicable-to-term?
                       (atomic-sentence-arg1 asent))
                  (push gaf result-gafs)))))))
      ;; decidable gafs
      (let ((gafs (inference-complete-extent-decidable-gafs predicate mt)))
        (when gafs
          (when (unique-names-assumption-applicable-to-all-args? asent)
            (dolist (gaf gafs)
              (pushnew gaf result-gafs :test #'eq)))))
      ;; isa + completely-decidable-collection check (missing-larkc 3454)
      (when (eq (reader-make-constant-shell "isa") predicate)
        (let ((collection (atomic-sentence-arg2 asent)))
          (when (fort-p collection)
            ;; Likely calls inference-completely-decidable-collection-gafs, parallel to
            ;; the enumerable-collection-gaf pattern above but for decidability.
            (let ((gafs (missing-larkc 3454)))
              (when gafs
                (when (unique-names-assumption-applicable-to-term?
                       (atomic-sentence-arg1 asent))
                  (dolist (gaf gafs)
                    (pushnew gaf result-gafs :test #'eq))))))))
      ;; enumerable-for-arg gafs per bound term
      (let ((terms (formula-terms asent :ignore))
            (argnum 0))
        (dolist (value terms)
          (when (fully-bound-p value)
            (let ((gafs (inference-complete-extent-enumerable-for-arg-gafs
                         predicate argnum mt)))
              (when gafs
                (when (unique-names-assumption-applicable-to-all-args-except? asent argnum)
                  (dolist (gaf gafs)
                    (pushnew gaf result-gafs :test #'eq))))))
          (setf argnum (1+ argnum))))
      ;; decidable-for-value-in-arg gafs per bound term
      (let ((terms (formula-terms asent :ignore))
            (argnum 0))
        (dolist (value terms)
          (when (fully-bound-p value)
            (let ((gafs (inference-complete-extent-decidable-for-value-in-arg-gafs
                         predicate value argnum mt)))
              (when gafs
                (when (unique-names-assumption-applicable-to-all-args-except? asent argnum)
                  (dolist (gaf gafs)
                    (pushnew gaf result-gafs :test #'eq))))))
          (setf argnum (1+ argnum)))))
    (nreverse result-gafs)))

(defun completeness-constraint-mt (mt)
  "[Cyc] Assuming that we are doing inference in MT, return the mt in which we look
for completeness assertions.  If all mts are relevant, we need to be conservative
and only look for universally true completeness assertions."
  (conservative-constraint-mt mt))

;; (defun inference-complete-extent-enumerable-via-backchain? (predicate mt) ...) -- commented declareFunction, no body
;; (defun inference-complete-extent-enumerable-via-backchain-gaf (predicate mt) ...) -- commented declareFunction, no body
;; (defun inference-complete-extent-enumerable-via-backchain-gafs-internal (predicate mt) ...) -- commented declareFunction, no body
;; (defun inference-complete-extent-enumerable-via-backchain-gafs (predicate mt) ...) -- commented declareFunction, no body
;; (defun inference-collection-completely-enumerable-via-backchain? (collection mt) ...) -- commented declareFunction, no body
;; (defun inference-collection-completely-enumerable-via-backchain-gaf (collection mt) ...) -- commented declareFunction, no body
;; (defun inference-completely-enumerable-via-backchain-asent? (asent mt) ...) -- commented declareFunction, no body
;; (defun inference-completely-enumerable-via-backchain-asent-gaf (asent mt) ...) -- commented declareFunction, no body
;; (defun inference-completely-enumerable-via-backchain-asent-gafs (asent mt) ...) -- commented declareFunction, no body

;; Setup: note-memoized-function calls for commented-out memoized functions.
;; The active memoized functions' note-memoized-function calls are generated by defun-memoized.
(toplevel
  (note-memoized-function 'inference-minimize-extent?))
(toplevel
  (note-memoized-function 'inference-completely-decidable-collection-gafs))
(toplevel
  (note-memoized-function 'inference-complete-extent-enumerable-via-backchain-gafs))
