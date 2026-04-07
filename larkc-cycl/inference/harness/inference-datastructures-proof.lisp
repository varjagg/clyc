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

(defparameter *proof-datastructure-stores-dependent-proofs?* nil
  "[Cyc] If T, when a proof A is made a subproof of another proof B, the proof B is also recorded in the dependents slot the subproof A.")


;;; Struct: proof

(defstruct (proof
            (:conc-name "prf-")
            (:constructor make-proof (&key suid bindings link subproofs dependents)))
  suid
  bindings
  link
  subproofs
  dependents)

(defconstant *dtp-proof* 'proof)


;;; Defstruct print trampoline and sxhash — both missing-larkc

(defun proof-print-function-trampoline (object stream)
  ;; Likely dispatches to print-proof for custom printing
  (missing-larkc 35406))

;; (defun print-proof (object stream depth) ...) -- active declareFunction, no body
;; (defun sxhash-proof-method (object) ...) -- active declareFunction, body is missing-larkc 35414


;;; Type predicates

(defun valid-proof-p (object)
  (and (proof-p object)
       (not (proof-invalid-p object))))

(defun proof-invalid-p (proof)
  (declare (type proof proof))
  (eq :free (proof-bindings proof)))

;; (defun list-of-proof-p (object) ...) -- active declareFunction, no body
;; (defun non-empty-list-of-proof-p (object) ...) -- active declareFunction, no body


;;; Macros

;; Reconstructed from Internal Constants: arglist $list30 ((SUBPROOF-VAR PROOF) &BODY BODY),
;; operators $sym31 DO-LIST, $sym32 PROOF-DIRECT-SUBPROOFS
(defmacro do-proof-direct-subproofs ((subproof-var proof) &body body)
  `(dolist (,subproof-var (proof-direct-subproofs ,proof))
     ,@body))

;; Reconstructed from Internal Constants: arglist $list33 ((SUBPROOF-VAR PROOF &KEY DONE) &BODY BODY),
;; $kw36 :DONE, $sym37 ALL-PROOF-SUBPROOFS; reuses $sym31 DO-LIST
(defmacro do-proof-all-subproofs ((subproof-var proof &key done) &body body)
  `(csome (,subproof-var (all-proof-subproofs ,proof) ,done)
     ,@body))

;; Reconstructed from Internal Constants: arglist $list38 ((DEPENDENT-PROOF-VAR PROOF &KEY PROOF-STATUS DONE) &BODY BODY),
;; gensyms $sym41 PROOF-PROBLEM, $sym42 SUPPORTED-PROBLEM, $sym43 DEPENDENT-PROOF;
;; operators $sym44 CLET, $sym45 PROOF-SUPPORTED-PROBLEM, $sym46 DO-PROBLEM-SUPPORTED-PROBLEMS,
;; $sym47 DO-PROBLEM-PROOFS, $sym48 PWHEN, $sym49 MEMBER-EQ?
;; Computes dependent proofs by navigating the problem/link graph structure.
(defmacro do-proof-dependent-proofs-computed ((dependent-proof-var proof &key proof-status done) &body body)
  (with-temp-vars (proof-problem supported-problem dependent-proof)
    `(let ((,proof-problem (proof-supported-problem ,proof)))
       (do-problem-supported-problems (,supported-problem ,proof-problem :done ,done)
         (do-problem-proofs (,dependent-proof ,supported-problem :proof-status ,proof-status)
           (when (member-eq? ,proof (proof-direct-subproofs ,dependent-proof))
             (let ((,dependent-proof-var ,dependent-proof))
               ,@body)))))))

;; Reconstructed from Internal Constants: $sym50 CSOME, $sym51 PROOF-DEPENDENTS,
;; $sym52 PROOF-HAS-STATUS?
;; Iterates over stored dependent proofs (when *proof-datastructure-stores-dependent-proofs?* is T).
(defmacro do-proof-dependent-proofs-int ((dependent-proof-var proof &key proof-status done) &body body)
  `(csome (,dependent-proof-var (proof-dependents ,proof) ,done)
     (when (proof-has-status? ,dependent-proof-var ,proof-status)
       ,@body)))

;; Reconstructed from Internal Constants: $sym53 PIF,
;; $sym54 *PROOF-DATASTRUCTURE-STORES-DEPENDENT-PROOFS?*,
;; $sym55 DO-PROOF-DEPENDENT-PROOFS-INT, $sym56 DO-PROOF-DEPENDENT-PROOFS-COMPUTED
;; Dispatches between stored and computed dependent proof iteration.
(defmacro do-proof-dependent-proofs ((dependent-proof-var proof &key proof-status done) &body body)
  `(if *proof-datastructure-stores-dependent-proofs?*
       (do-proof-dependent-proofs-int (,dependent-proof-var ,proof
                                       :proof-status ,proof-status :done ,done)
         ,@body)
       (do-proof-dependent-proofs-computed (,dependent-proof-var ,proof
                                            :proof-status ,proof-status :done ,done)
         ,@body)))


;;; Construction and destruction

(defun new-proof (link subproofs)
  (declare (type problem-link link))
  (let* ((proof (make-proof))
         (store (problem-link-store link))
         (suid (problem-store-new-proof-id store)))
    (increment-proof-historical-count)
    (setf (prf-suid proof) suid)
    (setf (prf-link proof) link)
    (setf (prf-subproofs proof) subproofs)
    proof))

(defun new-proof-with-bindings (link bindings subproofs)
  (let ((proof (new-proof link subproofs)))
    (set-proof-bindings proof bindings)
    (register-proof proof)
    proof))

(defun register-proof (proof)
  "[Cyc] Adds backpointers to PROOF from other datastructures"
  (let* ((link (proof-link proof))
         (supported-problem (problem-link-supported-problem link))
         (store (problem-link-store link)))
    (add-problem-proof supported-problem proof)
    (add-problem-store-proof store proof)
    (when *problem-link-datastructure-stores-proofs?*
      ;; Likely adds proof to the link's proof set
      (missing-larkc 35655))
    (when *proof-datastructure-stores-dependent-proofs?*
      ;; Likely adds backpointers from subproofs to this proof
      (missing-larkc 35398)))
  proof)

;; (defun add-dependent-proof-references (proof) ...) -- active declareFunction, no body
;; (defun destroy-proof (proof) ...) -- active declareFunction, no body
;; (defun destroy-dependent-proofs (proof) ...) -- active declareFunction, no body

(defun destroy-problem-store-proof (proof)
  (when (valid-proof-p proof)
    (note-proof-invalid proof)
    (destroy-proof-int proof)))

(defun destroy-proof-int (proof)
  (setf (prf-subproofs proof) :free)
  (setf (prf-dependents proof) :free)
  (setf (prf-link proof) :free)
  nil)

(defun note-proof-invalid (proof)
  (setf (prf-bindings proof) :free)
  proof)


;;; Accessors

(defun proof-suid (proof)
  (declare (type proof proof))
  (prf-suid proof))

(defun proof-bindings (proof)
  "[Cyc] Maps PROOF's problem-query -> HL proven-query of PROOF
or equivalently, PROOF's problem-query vars -> content.
Bindings to substitute into the supported-problem-query to get the proven-query.
First elements are variables in the supported-problem-query,
second elements are terms bound by this proof."
  (declare (type proof proof))
  (prf-bindings proof))

(defun proof-link (proof)
  (declare (type proof proof))
  (prf-link proof))

(defun proof-direct-subproofs (proof)
  (declare (type proof proof))
  (prf-subproofs proof))

;; (defun proof-dependents (proof) ...) -- active declareFunction, no body

(defun set-proof-bindings (proof bindings)
  (declare (type proof proof))
  (setf (prf-bindings proof) bindings)
  proof)

;; (defun add-proof-dependent (proof dependent) ...) -- active declareFunction, no body
;; (defun remove-proof-dependent (proof dependent) ...) -- active declareFunction, no body


;;; Derived accessors

(defun proof-store (proof)
  (let* ((link (proof-link proof))
         (store (problem-link-store link)))
    store))

(defun proof-supported-problem (proof)
  (let ((link (proof-link proof)))
    (problem-link-supported-problem link)))

;; (defun proof-supported-problem-query (proof) ...) -- active declareFunction, no body
;; (defun proof-has-supports? (proof) ...) -- active declareFunction, no body

(defun proof-supports (proof)
  (let ((link (proof-link proof)))
    (when (content-link-p link)
      (content-link-supports link))))

(defun proof-direct-supports (proof)
  (proof-direct-supports-recursive proof))

(defun proof-spec-direct-supports (link subproofs)
  (proof-spec-direct-supports-recursive link subproofs))

(defun proof-direct-supports-recursive (proof)
  (let ((link (proof-link proof))
        (subproofs (proof-direct-subproofs proof)))
    (proof-spec-direct-supports-recursive link subproofs)))

(defun proof-spec-direct-supports-recursive (link subproofs)
  (cond
    ((and (problem-store-abduction-allowed? (problem-link-store link))
          (transformation-link-p link))
     (must (singleton? subproofs)
           "Expected link ~a to have exactly one subproof" link)
     (let ((subproof (first subproofs)))
       (append (content-link-supports link)
               (proof-direct-supports-recursive subproof))))
    ((content-link-p link)
     (content-link-supports link))
    ((or (restriction-link-p link)
         (union-link-p link))
     (must (singleton? subproofs)
           "Expected link ~a to have exactly one subproof" link)
     (let ((subproof (first subproofs)))
       (proof-direct-supports-recursive subproof)))
    ((conjunctive-link-p link)
     (let ((direct-supports nil))
       (dolist (subproof subproofs)
         (dolist (direct-support (proof-direct-supports-recursive subproof))
           (push direct-support direct-supports)))
       (nreverse direct-supports)))
    (t
     (error "Unexpected link type for proof: ~a" link))))

;; (defun all-proof-supports (proof) ...) -- active declareFunction, no body
;; (defun all-proof-supports-recursive (proof acc) ...) -- active declareFunction, no body
;; (defun all-proof-supports-of-proofs (proofs) ...) -- active declareFunction, no body


;;; Subproof queries

(defun proof-has-subproofs? (proof)
  (sublisp-boolean (proof-direct-subproofs proof)))

;; (defun proof-sole-subproof (proof) ...) -- active declareFunction, no body

(defun proof-first-subproof (proof)
  "[Cyc] @return nil or proof-p"
  (dolist (subproof (proof-direct-subproofs proof))
    (return-from proof-first-subproof subproof))
  nil)

(defun all-proof-subproofs (proof)
  (let ((set-contents (new-set-contents 0 #'eq)))
    (setf set-contents (all-proof-subproofs-recursive proof set-contents))
    (set-contents-element-list set-contents)))

(defun all-proof-subproofs-recursive (proof all-subproofs-set)
  (unless (set-contents-member? proof all-subproofs-set #'eq)
    (setf all-subproofs-set (set-contents-add proof all-subproofs-set #'eq))
    (dolist (subproof (proof-direct-subproofs proof))
      (setf all-subproofs-set (all-proof-subproofs-recursive subproof all-subproofs-set))))
  all-subproofs-set)

;; (defun all-proof-subproblems (proof) ...) -- active declareFunction, no body


;;; Dependent proof queries

;; (defun proof-has-dependent-proofs? (proof) ...) -- active declareFunction, no body
;; (defun proof-dependent-proofs-computed (proof &optional proof-status) ...) -- active declareFunction, no body
;; (defun proof-dependent-proofs-int (proof &optional proof-status) ...) -- active declareFunction, no body
;; (defun proof-dependent-proofs (proof &optional proof-status) ...) -- active declareFunction, no body


;;; Status queries

(defun proof-status (proof)
  "[Cyc] @return proof-status-p"
  (if (proof-rejected? proof)
      :rejected
      :proven))

(defun proof-rejected? (proof)
  (let* ((store (proof-store proof))
         (rejected-proofs (problem-store-rejected-proofs store)))
    (dictionary-has-key? rejected-proofs proof)))

(defun proof-proven? (proof)
  (not (proof-rejected? proof)))

;; (defun proof-processed? (proof) ...) -- active declareFunction, no body
;; (defun proof-destructibility-status (proof) ...) -- active declareFunction, no body
;; (defun proof-indestructible? (proof) ...) -- active declareFunction, no body
;; (defun proof-destructible? (proof) ...) -- active declareFunction, no body
;; (defun proof-note-rejected (proof reason) ...) -- active declareFunction, no body
;; (defun proof-rejected-due-to-ill-formedness? (proof) ...) -- active declareFunction, no body

(defun proof-type (proof)
  "[Cyc] @return hl-module-p or problem-link-type-p"
  (if (content-proof-p proof)
      (content-proof-hl-module proof)
      (structural-proof-type proof)))

;; (defun proof-equal? (proof1 proof2) ...) -- active declareFunction, no body

(defun proof-matches-specification? (candidate-proof supported-problem proof-bindings proof-direct-supports)
  "[Cyc] @return boolean; t iff CANDIDATE-PROOF would equal a proof supporting
SUPPORTED-PROBLEM, with bindings PROOF-BINDINGS and direct supports PROOF-DIRECT-SUPPORTS.
   @note assumes PROOF-BINDINGS have been canonicalized, but does not assume that PROOF-DIRECT-SUPPORTS has been canonicalized."
  (declare (type proof candidate-proof))
  (cond
    ((not (eq (proof-supported-problem candidate-proof) supported-problem))
     nil)
    ((not (proof-bindings-equal? (proof-bindings candidate-proof) proof-bindings))
     nil)
    (t
     (justification-equal (proof-direct-supports candidate-proof) proof-direct-supports))))
