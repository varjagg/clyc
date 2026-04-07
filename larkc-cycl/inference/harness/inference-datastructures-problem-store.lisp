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

;; The problem store is the central data structure of the inference harness.
;; It holds all problems, links, proofs, inferences, and strategies, indexed
;; by integer IDs via id-index structures.

(defparameter *problem-store-modification-permitted?* nil
  "[Cyc] Whether the problem store and related datastructures are permitted to be created, destroyed, or modified. This is set to T in the main entry point to inference but NIL in the inference browser. Currently this only controls modifications that could conceivably happen via the browser, like lazy manifestation of non-focals.")

(defglobal *problem-store-id-index* (new-id-index)
  "[Cyc] The global index of all problem stores : id -> problem-store")

(defun new-problem-store-id ()
  (id-index-reserve *problem-store-id-index*))

(defun index-problem-store-by-id (store suid)
  (id-index-enter *problem-store-id-index* suid store))

(defun unindex-problem-store-by-id (store)
  (let ((suid (problem-store-suid store)))
    (id-index-remove *problem-store-id-index* suid)))

;; (defun find-problem-store-by-id (id) ...) -- active declareFunction, no body
;; (defun problem-store-count () ...) -- active declareFunction, no body
;; (defun problem-store-next-id () ...) -- active declareFunction, no body
;; (defun most-recent-problem-store () ...) -- active declareFunction, no body

;; Reconstructed from: $list1=((PROBLEM-STORE-VAR &KEY DONE) &BODY BODY),
;; $sym5$ID (gensym), $sym6$DO-ID-INDEX, $list7=(PROBLEM-STORE-ID-INDEX), $sym8$IGNORE
;; Expansion: iterates over *problem-store-id-index* binding each store
(defmacro do-all-problem-stores ((problem-store-var &key done) &body body)
  (with-temp-vars (id)
    `(do-id-index (,id ,problem-store-var (problem-store-id-index))
       ,@body)))

(defun problem-store-id-index ()
  *problem-store-id-index*)

(defun all-problem-stores ()
  "[Cyc] Return a list of all problem stores."
  (id-index-values *problem-store-id-index*))

(defun destroy-all-problem-stores ()
  "[Cyc] Destroy all current problem stores; return the number of stores successfully destroyed."
  (let ((count 0))
    (dolist (store (all-problem-stores))
      (ignore-errors
        (destroy-problem-store store)
        (incf count)))
    count))

;; problem-store defstruct — 46 slots
(defstruct (problem-store
            (:conc-name "prob-store-")
            (:predicate problem-store-p))
  guid
  suid
  lock
  creation-time
  inference-id-index
  strategy-id-index
  problem-id-index
  link-id-index
  proof-id-index
  problem-by-query-index
  rejected-proofs
  processed-proofs
  non-explanatory-subproofs-possible?
  non-explanatory-subproofs-index
  most-recent-tactic-executed
  min-proof-depth-index
  min-transformation-depth-index
  min-transformation-depth-signature-index
  min-depth-index
  equality-reasoning-method
  equality-reasoning-domain
  intermediate-step-validation-level
  max-problem-count
  crazy-max-problem-count
  removal-allowed?
  transformation-allowed?
  add-restriction-layer-of-indirection?
  negation-by-failure?
  completeness-minimization-allowed?
  direction
  evaluate-subl-allowed?
  rewrite-allowed?
  abduction-allowed?
  new-terms-allowed?
  compute-answer-justifications?
  memoization-state
  sbhl-resource-space
  prepared?
  destruction-imminent?
  meta-problem-store
  static-properties
  janitor
  historical-root-problems
  complex-problem-query-czer-index
  complex-problem-query-signatures
  proof-keeping-index)

(defmethod print-object ((obj problem-store) stream)
  (print-unreadable-object (obj stream :type t :identity nil)
    (format stream "~D" (prob-store-suid obj))))

(defun valid-problem-store-p (object)
  (and (problem-store-p object)
       (not (problem-store-invalid-p object))))

;; (defun id-of-valid-problem-store-p (id) ...) -- active declareFunction, no body

(defun problem-store-invalid-p (store)
  (eq :free (prob-store-equality-reasoning-domain store)))

;; (defun print-problem-store (store stream depth) ...) -- active declareFunction, no body

(defun sxhash-problem-store-method (object)
  (prob-store-suid object))

;; Reconstructed from expansion visible in problem-store-new-inference-id:
;; seize-lock / release-lock pattern → bt:with-lock-held
(defmacro with-problem-store-lock-held ((store) &body body)
  (with-temp-vars (lock)
    `(let ((,lock (problem-store-lock ,store)))
       (bt:with-lock-held (,lock)
         ,@body))))

(defun problem-store-lock (store)
  (prob-store-lock store))

;; Reconstructed from expansion visible in problem-store-note-transformation-rule-considered:
;; Binds *memoization-state* to the store's memoization state, handling process ownership
(defmacro with-problem-store-memoization-state ((store) &body body)
  (with-temp-vars (local-state original-memoization-process current-proc)
    `(let* ((,local-state (problem-store-memoization-state ,store))
            (*memoization-state* ,local-state)
            (,original-memoization-process nil))
       (when (and ,local-state (null (memoization-state-lock ,local-state)))
         (setf ,original-memoization-process
               (memoization-state-get-current-process-internal ,local-state))
         (let ((,current-proc (bt:current-thread)))
           (cond ((null ,original-memoization-process)
                  (memoization-state-set-current-process-internal ,local-state ,current-proc))
                 ((not (eq ,original-memoization-process ,current-proc))
                  (error "Invalid attempt to reuse memoization state in different process")))))
       (unwind-protect
            (progn ,@body)
         (when (and ,local-state (null ,original-memoization-process))
           (memoization-state-set-current-process-internal ,local-state nil))))))

(defun problem-store-memoization-state (store)
  (prob-store-memoization-state store))

;; TODO - WITH-PROBLEM-STORE-SBHL-RESOURCE-SPACE macro
;; Evidence: helpers are problem-store-sbhl-resource-space and set-problem-store-sbhl-resource-space
;; Likely binds *sbhl-resource-space* or similar to the store's resource space

(defun problem-store-sbhl-resource-space (store)
  (prob-store-sbhl-resource-space store))

(defun set-problem-store-sbhl-resource-space (store space)
  (setf (prob-store-sbhl-resource-space store) space)
  store)

;; TODO - WITH-PROBLEM-STORE-RESOURCING-AND-MEMOIZATION macro
;; Evidence: likely combines with-problem-store-memoization-state and
;; with-problem-store-sbhl-resource-space

;; Reconstructed from expansion visible in first-problem-store-inference / destroy-problem-store-int:
;; Iterates over the store's inference id-index using do-id-index
(defmacro do-problem-store-inferences ((id-var inference-var store &key done) &body body)
  `(do-id-index (,id-var ,inference-var (problem-store-inference-id-index ,store)
                 ,@(when done `(:done ,done)))
     ,@body))

(defun problem-store-inference-id-index (store)
  (prob-store-inference-id-index store))

;; Reconstructed: same pattern as do-problem-store-inferences
(defmacro do-problem-store-strategies ((id-var strategy-var store &key done) &body body)
  `(do-id-index (,id-var ,strategy-var (problem-store-strategy-id-index ,store)
                 ,@(when done `(:done ,done)))
     ,@body))

(defun problem-store-strategy-id-index (store)
  (prob-store-strategy-id-index store))

;; TODO - DO-PROBLEM-STORE-STRATEGIC-CONTEXTS macro
;; Evidence: declareMacro in Java, likely iterates over strategies plus the store itself

;; Reconstructed: same pattern as do-problem-store-inferences
(defmacro do-problem-store-problems ((id-var problem-var store &key done) &body body)
  `(do-id-index (,id-var ,problem-var (problem-store-problem-id-index ,store)
                 ,@(when done `(:done ,done)))
     ,@body))

(defun problem-store-problem-id-index (store)
  (prob-store-problem-id-index store))

;; Reconstructed: same pattern
(defmacro do-problem-store-links ((id-var link-var store &key done) &body body)
  `(do-id-index (,id-var ,link-var (problem-store-link-id-index ,store)
                 ,@(when done `(:done ,done)))
     ,@body))

(defun problem-store-link-id-index (store)
  (prob-store-link-id-index store))

;; Reconstructed: same pattern
(defmacro do-problem-store-proofs ((id-var proof-var store &key done) &body body)
  `(do-id-index (,id-var ,proof-var (problem-store-proof-id-index ,store)
                 ,@(when done `(:done ,done)))
     ,@body))

(defun problem-store-proof-id-index (store)
  (prob-store-proof-id-index store))

;; Reconstructed: iterates over the historical-root-problems set
(defmacro do-problem-store-historical-root-problems ((problem-var store &key done) &body body)
  `(do-set (,problem-var (problem-store-historical-root-problems ,store)
            ,@(when done (list done)))
     ,@body))

(defun problem-store-historical-root-problems (store)
  (prob-store-historical-root-problems store))

;; TODO - DO-INFERENCE-STRATEGIES macro
;; Evidence: declareMacro in Java

;;; =========================================================================
;;; Default sizes and globals
;;; =========================================================================

(deflexical *default-problem-store-problem-size* 80)
(deflexical *default-problem-store-link-size* 120)
(deflexical *default-problem-store-inference-size* 10)
(deflexical *default-problem-store-strategy-size* *default-problem-store-inference-size*)
(deflexical *default-problem-store-proof-size* 40)
(deflexical *problem-store-sbhl-resource-space-number* 10)

;;; =========================================================================
;;; Constructor / destructor
;;; =========================================================================

(defun new-problem-store (&optional problem-store-properties)
  "[Cyc] Allocates a new problem-store object and sets up its internal datastructures."
  (declare (type list problem-store-properties))
  (let ((name (problem-store-properties-name problem-store-properties)))
    (must (not (find-problem-store-by-name name))
          "A problem store named ~s already exists." name))
  (let* ((store (make-problem-store))
         (suid (new-problem-store-id)))
    (increment-problem-store-historical-count)
    (setf (prob-store-guid store) nil)
    (setf (prob-store-suid store) suid)
    (index-problem-store-by-id store suid)
    (setf (prob-store-lock store) (bt:make-lock :name "Problem Store Lock"))
    (setf (prob-store-creation-time store) (get-universal-time))
    (setf (prob-store-prepared? store) nil)
    (setf (prob-store-problem-id-index store) (new-id-index *default-problem-store-problem-size* 0))
    (setf (prob-store-inference-id-index store) (new-id-index *default-problem-store-inference-size* 0))
    (setf (prob-store-strategy-id-index store) (new-id-index *default-problem-store-strategy-size* 0))
    (setf (prob-store-link-id-index store) (new-id-index *default-problem-store-link-size* 0))
    (setf (prob-store-proof-id-index store) (new-id-index *default-problem-store-proof-size* 0))
    (setf (prob-store-rejected-proofs store) (make-hash-table :test #'eq))
    (setf (prob-store-processed-proofs store) (new-set #'eq))
    (setf (prob-store-non-explanatory-subproofs-possible? store) nil)
    (setf (prob-store-non-explanatory-subproofs-index store) (make-hash-table :test #'eq))
    (setf (prob-store-most-recent-tactic-executed store) nil)
    (setf (prob-store-min-proof-depth-index store) (make-hash-table :test #'eq))
    (setf (prob-store-min-transformation-depth-index store) (make-hash-table :test #'eq))
    (setf (prob-store-min-transformation-depth-signature-index store) (make-hash-table :test #'eq))
    (setf (prob-store-min-depth-index store) (make-hash-table :test #'eq))
    (let ((name (problem-store-properties-name problem-store-properties)))
      (set-problem-store-name store name)
      (let ((equality-reasoning-method (problem-store-properties-equality-reasoning-method problem-store-properties)))
        (setf (prob-store-equality-reasoning-method store) equality-reasoning-method))
      (let ((equality-reasoning-domain (problem-store-properties-equality-reasoning-domain problem-store-properties)))
        (setf (prob-store-equality-reasoning-domain store) equality-reasoning-domain)
        (if (eq :none equality-reasoning-domain)
            (setf (prob-store-problem-by-query-index store) :empty-domain)
            (setf (prob-store-problem-by-query-index store) (make-hash-table :test #'equal :size *default-problem-store-problem-size*))))
      (let ((intermediate-step-validation-level (problem-store-properties-intermediate-step-validation-level problem-store-properties)))
        (setf (prob-store-intermediate-step-validation-level store) intermediate-step-validation-level))
      (let ((max-problem-count (problem-store-properties-max-problem-count problem-store-properties)))
        (setf (prob-store-max-problem-count store) max-problem-count)
        (let ((crazy-max-problem-count (compute-crazy-max-problem-count max-problem-count)))
          (setf (prob-store-crazy-max-problem-count store) crazy-max-problem-count)))
      (let ((removal-allowed? (removal-allowed-by-properties? problem-store-properties)))
        (setf (prob-store-removal-allowed? store) removal-allowed?))
      (let ((transformation-allowed? (transformation-allowed-by-properties? problem-store-properties)))
        (setf (prob-store-transformation-allowed? store) transformation-allowed?))
      (let ((add-restriction-layer-of-indirection? (problem-store-properties-add-restriction-layer-of-indirection? problem-store-properties)))
        (setf (prob-store-add-restriction-layer-of-indirection? store) add-restriction-layer-of-indirection?))
      (let ((negation-by-failure? (problem-store-properties-negation-by-failure? problem-store-properties)))
        (setf (prob-store-negation-by-failure? store) negation-by-failure?))
      (let ((completeness-minimization-allowed? (problem-store-properties-completeness-minimization-allowed? problem-store-properties)))
        (setf (prob-store-completeness-minimization-allowed? store) completeness-minimization-allowed?))
      (let ((direction (problem-store-properties-direction problem-store-properties)))
        (setf (prob-store-direction store) direction))
      (let ((evaluate-subl-allowed? (problem-store-properties-evaluate-subl-allowed? problem-store-properties)))
        (setf (prob-store-evaluate-subl-allowed? store) evaluate-subl-allowed?))
      (let ((rewrite-allowed? (problem-store-properties-rewrite-allowed? problem-store-properties)))
        (setf (prob-store-rewrite-allowed? store) rewrite-allowed?))
      (let ((abduction-allowed? (problem-store-properties-abduction-allowed? problem-store-properties)))
        (setf (prob-store-abduction-allowed? store) abduction-allowed?))
      (let ((new-terms-allowed? (problem-store-properties-new-terms-allowed? problem-store-properties)))
        (setf (prob-store-new-terms-allowed? store) new-terms-allowed?))
      (let ((compute-answer-justifications? (problem-store-properties-compute-answer-justifications? problem-store-properties)))
        (setf (prob-store-compute-answer-justifications? store) compute-answer-justifications?)))
    (setf (prob-store-memoization-state store) (new-memoization-state "problem-store-memoization-state" (new-rw-lock "problem-store-memoization-lock")))
    (set-problem-store-sbhl-resource-space store (new-sbhl-marking-space-resource *problem-store-sbhl-resource-space-number*))
    (setf (prob-store-destruction-imminent? store) nil)
    (setf (prob-store-meta-problem-store store) nil)
    (setf (prob-store-static-properties store) (copy-list problem-store-properties))
    (setf (prob-store-janitor store) (new-problem-store-janitor store))
    (setf (prob-store-historical-root-problems store) (new-set #'eq))
    (setf (prob-store-complex-problem-query-czer-index store) (make-hash-table :test #'equal))
    (setf (prob-store-complex-problem-query-signatures store) (make-hash-table :test #'eq))
    (setf (prob-store-proof-keeping-index store) (make-hash-table :test #'eq))
    store))

(defun destroy-problem-store (store)
  (when (valid-problem-store-p store)
    (unwind-protect
         (destroy-problem-store-int store)
      (unindex-problem-store-by-id store)
      (setf (prob-store-lock store) :free)))
  nil)

(defun destroy-problem-store-int (store)
  (update-maximum-problem-store-historical-problem-count store)
  (note-problem-store-invalid store)
  (let ((meta-problem-store (prob-store-meta-problem-store store)))
    (when (problem-store-p meta-problem-store)
      (destroy-problem-store meta-problem-store))
    (setf (prob-store-meta-problem-store store) :free))
  (destroy-problem-store-janitor (prob-store-janitor store))
  (setf (prob-store-janitor store) :free)
  (free-problem-store-name store)
  (setf (prob-store-equality-reasoning-method store) :free)
  (setf (prob-store-intermediate-step-validation-level store) :free)
  (setf (prob-store-max-problem-count store) :free)
  (setf (prob-store-crazy-max-problem-count store) :free)
  (setf (prob-store-removal-allowed? store) :free)
  (setf (prob-store-transformation-allowed? store) :free)
  (setf (prob-store-add-restriction-layer-of-indirection? store) :free)
  (setf (prob-store-negation-by-failure? store) :free)
  (setf (prob-store-completeness-minimization-allowed? store) :free)
  (setf (prob-store-direction store) :free)
  (setf (prob-store-evaluate-subl-allowed? store) :free)
  (setf (prob-store-rewrite-allowed? store) :free)
  (setf (prob-store-abduction-allowed? store) :free)
  (setf (prob-store-new-terms-allowed? store) :free)
  (setf (prob-store-compute-answer-justifications? store) :free)
  (setf (prob-store-prepared? store) :free)
  (setf (prob-store-destruction-imminent? store) :free)
  (setf (prob-store-static-properties store) :free)
  (clear-problem-store-proof-keeping-problems store)
  (setf (prob-store-proof-keeping-index store) :free)
  (clrhash (prob-store-complex-problem-query-signatures store))
  (setf (prob-store-complex-problem-query-signatures store) :free)
  (clrhash (prob-store-complex-problem-query-czer-index store))
  (setf (prob-store-complex-problem-query-czer-index store) :free)
  (clear-set (prob-store-historical-root-problems store))
  (setf (prob-store-historical-root-problems store) :free)
  (setf (prob-store-sbhl-resource-space store) :free)
  (clear-all-memoization (problem-store-memoization-state store))
  (setf (prob-store-memoization-state store) :free)
  (clrhash (prob-store-min-depth-index store))
  (setf (prob-store-min-depth-index store) :free)
  (clrhash (prob-store-min-transformation-depth-index store))
  (setf (prob-store-min-transformation-depth-index store) :free)
  (clrhash (prob-store-min-transformation-depth-signature-index store))
  (setf (prob-store-min-transformation-depth-signature-index store) :free)
  (clrhash (prob-store-min-proof-depth-index store))
  (setf (prob-store-min-proof-depth-index store) :free)
  (when (hash-table-p (prob-store-problem-by-query-index store))
    (clrhash (prob-store-problem-by-query-index store)))
  (setf (prob-store-problem-by-query-index store) :free)
  ;; Destroy all inferences
  (do-id-index (_id inference (problem-store-inference-id-index store))
    (destroy-problem-store-inference inference))
  (clear-id-index (prob-store-inference-id-index store))
  (setf (prob-store-inference-id-index store) :free)
  ;; Destroy all strategies
  (do-id-index (_id strategy (problem-store-strategy-id-index store))
    (destroy-problem-store-strategy strategy))
  (clear-id-index (prob-store-strategy-id-index store))
  (setf (prob-store-strategy-id-index store) :free)
  (clrhash (prob-store-rejected-proofs store))
  (setf (prob-store-rejected-proofs store) :free)
  (clear-set (prob-store-processed-proofs store))
  (setf (prob-store-processed-proofs store) :free)
  (setf (prob-store-non-explanatory-subproofs-possible? store) :free)
  (clrhash (prob-store-non-explanatory-subproofs-index store))
  (setf (prob-store-non-explanatory-subproofs-index store) :free)
  (setf (prob-store-most-recent-tactic-executed store) :free)
  ;; Destroy all proofs
  (do-id-index (_id proof (problem-store-proof-id-index store))
    (destroy-problem-store-proof proof))
  (clear-id-index (prob-store-proof-id-index store))
  (setf (prob-store-proof-id-index store) :free)
  ;; Destroy all links
  (do-id-index (_id link (problem-store-link-id-index store))
    (destroy-problem-store-link link))
  (clear-id-index (prob-store-link-id-index store))
  (setf (prob-store-link-id-index store) :free)
  ;; Destroy all problems
  (do-id-index (_id problem (problem-store-problem-id-index store))
    (destroy-problem-store-problem problem))
  (clear-id-index (prob-store-problem-id-index store))
  (setf (prob-store-problem-id-index store) :free)
  nil)

(defun note-problem-store-invalid (store)
  (setf (prob-store-equality-reasoning-domain store) :free)
  store)

;;; =========================================================================
;;; Accessors (public wrappers)
;;; =========================================================================

;; (defun problem-store-guid (store) ...) -- active declareFunction, no body

(defun problem-store-suid (store)
  (declare (type problem-store store))
  (prob-store-suid store))

;; (defun problem-store-creation-time (store) ...) -- active declareFunction, no body

(defun problem-store-rejected-proofs (store)
  (prob-store-rejected-proofs store))

;; (defun problem-store-processed-proofs (store) ...) -- active declareFunction, no body

(defun problem-store-non-explanatory-subproofs-possible? (store)
  (declare (type problem-store store))
  (prob-store-non-explanatory-subproofs-possible? store))

;; (defun problem-store-non-explanatory-subproofs-index (store) ...) -- active declareFunction, no body
;; (defun problem-store-most-recent-tactic-executed (store) ...) -- active declareFunction, no body

(defun problem-store-min-proof-depth-index (store)
  (declare (type problem-store store))
  (prob-store-min-proof-depth-index store))

(defun problem-store-min-transformation-depth-index (store)
  (declare (type problem-store store))
  (prob-store-min-transformation-depth-index store))

(defun problem-store-min-transformation-depth-signature-index (store)
  (declare (type problem-store store))
  (prob-store-min-transformation-depth-signature-index store))

;; (defun problem-store-min-depth-index (store) ...) -- active declareFunction, no body

(defun problem-store-equality-reasoning-method (store)
  (declare (type problem-store store))
  (prob-store-equality-reasoning-method store))

(defun problem-store-equality-reasoning-domain (store)
  (declare (type problem-store store))
  (prob-store-equality-reasoning-domain store))

(defun problem-store-intermediate-step-validation-level (store)
  (declare (type problem-store store))
  (prob-store-intermediate-step-validation-level store))

(defun problem-store-max-problem-count (store)
  (declare (type problem-store store))
  (prob-store-max-problem-count store))

;; (defun problem-store-crazy-max-problem-count (store) ...) -- active declareFunction, no body

(defun problem-store-removal-allowed? (store)
  (declare (type problem-store store))
  (prob-store-removal-allowed? store))

(defun problem-store-transformation-allowed? (store)
  (declare (type problem-store store))
  (prob-store-transformation-allowed? store))

(defun problem-store-add-restriction-layer-of-indirection? (store)
  (declare (type problem-store store))
  (prob-store-add-restriction-layer-of-indirection? store))

(defun problem-store-negation-by-failure? (store)
  (declare (type problem-store store))
  (prob-store-negation-by-failure? store))

;; (defun problem-store-completeness-minimization-allowed? (store) ...) -- active declareFunction, no body

(defun problem-store-direction (store)
  (declare (type problem-store store))
  (prob-store-direction store))

;; (defun problem-store-evaluate-subl-allowed? (store) ...) -- active declareFunction, no body

(defun problem-store-rewrite-allowed? (store)
  (declare (type problem-store store))
  (prob-store-rewrite-allowed? store))

(defun problem-store-abduction-allowed? (store)
  (declare (type problem-store store))
  (prob-store-abduction-allowed? store))

(defun problem-store-new-terms-allowed? (store)
  (declare (type problem-store store))
  (prob-store-new-terms-allowed? store))

(defun problem-store-compute-answer-justifications? (store)
  (declare (type problem-store store))
  (if (testing-real-time-prining?)
      nil
      (prob-store-compute-answer-justifications? store)))

(defun problem-store-prepared? (store)
  (declare (type problem-store store))
  (prob-store-prepared? store))

;; (defun problem-store-destruction-imminent? (store) ...) -- active declareFunction, no body
;; (defun problem-store-meta-problem-store (store) ...) -- active declareFunction, no body
;; (defun problem-store-static-properties (store) ...) -- active declareFunction, no body
;; (defun problem-store-janitor (store) ...) -- active declareFunction, no body

;;; =========================================================================
;;; Mutators
;;; =========================================================================

(defun note-problem-store-most-recent-tactic-executed (store tactic)
  (declare (type problem-store store))
  (setf (prob-store-most-recent-tactic-executed store) tactic)
  store)

;; (defun set-problem-store-intermediate-step-validation-level (store level) ...) -- active declareFunction, no body

(defun set-problem-store-add-restriction-layer-of-indirection? (store value)
  (setf (prob-store-add-restriction-layer-of-indirection? store) value)
  store)

(defun set-problem-store-transformation-allowed? (store value)
  (setf (prob-store-transformation-allowed? store) value)
  store)

;; (defun set-problem-store-removal-allowed? (store value) ...) -- active declareFunction, no body
;; (defun set-problem-store-new-terms-allowed? (store value) ...) -- active declareFunction, no body

(defun note-problem-store-prepared (store)
  (setf (prob-store-prepared? store) t)
  store)

(defun note-problem-store-destruction-imminent (store)
  "[Cyc] @note the actual destruction must still be done by the caller."
  (setf (prob-store-destruction-imminent? store) t)
  store)

;; (defun reset-problem-store-janitor (store) ...) -- active declareFunction, no body

;;; =========================================================================
;;; Predicates
;;; =========================================================================

(defun problem-store-forward? (store)
  "[Cyc] Return T iff STORE has a direction of :FORWARD."
  (eq :forward (problem-store-direction store)))

(defun problem-store-new? (store)
  "[Cyc] Whether STORE is newly created and not yet finalized."
  (not (problem-store-prepared? store)))

;; (defun new-problem-store-p (store) ...) -- active declareFunction, no body

;;; =========================================================================
;;; Counts
;;; =========================================================================

(defun problem-store-inference-count (store)
  "[Cyc] Return the number of inferences that are currently in STORE."
  (id-index-count (prob-store-inference-id-index store)))

(defun problem-store-has-only-one-inference? (store)
  (= 1 (problem-store-inference-count store)))

;; (defun problem-store-historical-inference-count (store) ...) -- commented declareFunction, no body

;; (defun find-inference-by-id (store id) ...) -- active declareFunction, no body
;; (defun find-inference-by-ids (store-id inference-id) ...) -- active declareFunction, no body

(defun first-problem-store-inference (store)
  (do-id-index (_id inference (problem-store-inference-id-index store))
    (return inference)))

;; (defun earliest-problem-store-inference (store) ...) -- active declareFunction, no body
;; (defun latest-problem-store-inference (store) ...) -- active declareFunction, no body

(defun problem-store-private? (store)
  (let ((inference (first-problem-store-inference store)))
    (when inference
      (inference-problem-store-private? inference))))

;; (defun problem-store-strategy-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-historical-strategy-count (store) ...) -- commented declareFunction, no body
;; (defun problem-store-strategies (store) ...) -- active declareFunction, no body
;; (defun find-strategy-by-id (store id) ...) -- active declareFunction, no body
;; (defun find-strategy-by-ids (store-id strategy-id) ...) -- active declareFunction, no body
;; (defun first-problem-store-strategy (store) ...) -- active declareFunction, no body
;; (defun problem-store-obvious-strategic-context (store) ...) -- active declareFunction, no body
;; (defun problem-store-unique-balancing-tactician (store) ...) -- active declareFunction, no body
;; (defun problem-store-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-historical-link-count (store) ...) -- commented declareFunction, no body
;; (defun find-problem-link-by-id (store id) ...) -- active declareFunction, no body
;; (defun find-problem-link-by-ids (store-id link-id) ...) -- active declareFunction, no body
;; (defun problem-store-first-link-of-type (store type) ...) -- active declareFunction, no body
;; (defun problem-store-link-type-count (store type) ...) -- active declareFunction, no body
;; (defun problem-store-content-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-answer-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-removal-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-conjunctive-removal-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-transformation-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-rewrite-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-structural-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-join-ordered-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-join-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-split-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-restriction-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-residual-transformation-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-union-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-unmanifested-non-focal-count (store) ...) -- active declareFunction, no body

(defun problem-store-problem-count (store)
  "[Cyc] Return the number of problems that are currently in STORE."
  (id-index-count (prob-store-problem-id-index store)))

(defun problem-store-historical-problem-count (store)
  "[Cyc] Return the number of problems that have ever existed in STORE."
  (id-index-next-id (prob-store-problem-id-index store)))

;; (defun problem-store-empty? (store) ...) -- active declareFunction, no body

(defun compute-crazy-max-problem-count (max-problem-count)
  "[Cyc] Given MAX-PROBLEM-COUNT which is the amount of problems above which the problem store will attempt to prune, returns the CRAZY-MAX-PROBLEM-COUNT which is the amount of problems above which the problem store will error without even trying to prune."
  (potentially-infinite-number-max
   (potentially-infinite-number-plus max-problem-count 212)
   (potentially-infinite-number-times max-problem-count 2)))

(defun problem-store-max-problem-count-reached? (store)
  (let ((max-problem-count (problem-store-max-problem-count store)))
    (and (not (positive-infinity-p max-problem-count))
         (>= (problem-store-problem-count store) max-problem-count))))

(deflexical *max-proof-count-multiplier* 5
  "[Cyc] If the problem store fills up with this many times more than the max problem count, halt with a :max-proof-count halt reason.")

(defun problem-store-max-proof-count-reached? (store)
  (let* ((max-problem-count (problem-store-max-problem-count store))
         (max-proof-count (potentially-infinite-number-times max-problem-count *max-proof-count-multiplier*)))
    (and (not (positive-infinity-p max-proof-count))
         (>= (problem-store-proof-count store) max-proof-count))))

;; (defun problem-store-crazy-max-problem-count-exactly-reached? (store) ...) -- active declareFunction, no body
;; (defun problem-store-crazy-max-problem-count-reached? (store) ...) -- active declareFunction, no body

(defun problem-store-allows-proof-processing? (store)
  (and (problem-store-private? store)
       (not (problem-store-compute-answer-justifications? store))))

;; (defun find-problem-by-id (store id) ...) -- active declareFunction, no body
;; (defun find-problem-by-ids (store-id problem-id) ...) -- active declareFunction, no body

(defun find-problem-by-query (store query)
  (let ((domain (problem-store-equality-reasoning-domain store)))
    (when (problem-query-in-equality-reasoning-domain? query domain)
      (gethash query (prob-store-problem-by-query-index store)))))

;; (defun problem-store-tactical-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-unexamined-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-examined-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-possible-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-pending-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-finished-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-neutral-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-no-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-single-literal-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-conjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-join-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-split-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-disjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-unexamined-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-examined-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-possible-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-pending-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-finished-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-unexamined-neutral-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-examined-neutral-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-possible-neutral-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-pending-neutral-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-finished-neutral-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-unexamined-no-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-examined-no-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-possible-no-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-pending-no-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-finished-no-good-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-good-single-literal-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-good-conjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-good-join-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-good-split-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-good-disjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-neutral-single-literal-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-neutral-conjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-neutral-join-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-neutral-split-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-neutral-disjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-no-good-single-literal-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-no-good-conjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-no-good-join-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-no-good-split-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-no-good-disjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-unexamined-single-literal-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-unexamined-conjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-unexamined-join-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-unexamined-split-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-unexamined-disjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-examined-single-literal-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-examined-conjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-examined-join-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-examined-split-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-examined-disjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-possible-single-literal-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-possible-conjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-possible-join-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-possible-split-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-possible-disjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-pending-single-literal-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-pending-conjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-pending-join-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-pending-split-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-pending-disjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-finished-single-literal-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-finished-conjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-finished-join-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-finished-split-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-finished-disjunctive-problem-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-executed-removal-tactic-productivities (store) ...) -- active declareFunction, no body
;; (defun problem-store-tactic-with-status-count (store &optional status) ...) -- active declareFunction, no body
;; (defun problem-store-tactic-of-type-with-status-count (store &optional type status) ...) -- active declareFunction, no body
;; (defun problem-store-tactic-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-possible-tactic-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-executed-tactic-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-discarded-tactic-count (store) ...) -- active declareFunction, no body

(defun problem-store-proof-count (store)
  "[Cyc] Return the number of proofs that are currently in STORE."
  (id-index-count (prob-store-proof-id-index store)))

;; (defun problem-store-historical-proof-count (store) ...) -- commented declareFunction, no body
;; (defun find-proof-by-id (store id) ...) -- active declareFunction, no body
;; (defun find-proof-by-ids (store-id proof-id) ...) -- active declareFunction, no body
;; (defun problem-store-some-rejected-proofs? (store) ...) -- active declareFunction, no body
;; (defun problem-store-rejected-proof-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-proven-proof-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-all-processed-proofs (store) ...) -- active declareFunction, no body
;; (defun problem-store-has-some-non-explanatory-subproof? (store) ...) -- active declareFunction, no body
;; (defun problem-store-proof-non-explanatory-subproofs (store proof) ...) -- active declareFunction, no body
;; (defun problem-store-size (store) ...) -- active declareFunction, no body
;; (defun problem-store-historical-size (store) ...) -- commented declareFunction, no body
;; (defun problem-store-dependent-link-count (store) ...) -- active declareFunction, no body
;; (defun problem-store-most-recent-transformation-link (store) ...) -- active declareFunction, no body
;; (defun problem-store-transformation-rules (store) ...) -- active declareFunction, no body
;; (defun problem-store-all-non-focal-problems (store) ...) -- active declareFunction, no body
;; (defun problem-store-could-recompute-destructibles? (store) ...) -- active declareFunction, no body
;; (defun problem-store-could-remove-destructibles? (store) ...) -- active declareFunction, no body
;; (defun problem-stores-similar? (store1 store2) ...) -- active declareFunction, no body
;; (defun problem-store-transformation-rule-bindings-to-closed (store) ...) -- active declareFunction, no body
;; (defun problem-store-all-problems (store) ...) -- active declareFunction, no body
;; (defun problem-store-all-problem-queries (store) ...) -- active declareFunction, no body
;; (defun problem-store-all-problem-links (store) ...) -- active declareFunction, no body
;; (defun problem-store-all-proofs (store) ...) -- active declareFunction, no body
;; (defun problem-store-historical-root-problem? (store problem) ...) -- commented declareFunction, no body

(defun problem-store-historical-root-problem-count (store)
  "[Cyc] Return the number of currently existing problems in STORE that have ever been the root problem of some inference."
  (set-size (prob-store-historical-root-problems store)))

;; (defun problem-store-problem-with-complex-problem-query? (store problem) ...) -- active declareFunction, no body
;; (defun problem-store-complex-problem-query-signature (store problem) ...) -- active declareFunction, no body
;; (defun problem-store-find-complex-problem-query (store signature) ...) -- active declareFunction, no body

(defun clear-problem-store-proof-keeping-problems (store)
  (clrhash (prob-store-proof-keeping-index store))
  nil)

;; (defun problem-proof-keeping-status (problem) ...) -- active declareFunction, no body
;; (defun proof-keeping-problem? (problem) ...) -- active declareFunction, no body
;; (defun non-proof-keeping-problem? (problem) ...) -- active declareFunction, no body
;; (defun unknown-proof-keeping-problem? (problem) ...) -- active declareFunction, no body
;; (defun note-proof-keeping-problem (problem status) ...) -- active declareFunction, no body
;; (defun note-not-proof-keeping-problem (problem) ...) -- active declareFunction, no body
;; (defun problem-store-prepare-for-expected-problem-count (store count) ...) -- active declareFunction, no body
;; (defun problem-store-prepare-for-expected-link-count (store count) ...) -- active declareFunction, no body
;; (defun problem-store-prepare-for-expected-proof-count (store count) ...) -- active declareFunction, no body

;;; =========================================================================
;;; ID allocation (locked)
;;; =========================================================================

(defun problem-store-new-inference-id (store)
  (let ((v-id-index (problem-store-inference-id-index store)))
    (with-problem-store-lock-held (store)
      (id-index-reserve v-id-index))))

(defun problem-store-new-strategy-id (store)
  (let ((v-id-index (problem-store-strategy-id-index store)))
    (with-problem-store-lock-held (store)
      (id-index-reserve v-id-index))))

(defun problem-store-new-problem-id (store)
  (let ((v-id-index (problem-store-problem-id-index store)))
    (with-problem-store-lock-held (store)
      (id-index-reserve v-id-index))))

(defun problem-store-new-link-id (store)
  (let ((v-id-index (problem-store-link-id-index store)))
    (with-problem-store-lock-held (store)
      (id-index-reserve v-id-index))))

(defun problem-store-new-proof-id (store)
  (let ((v-id-index (problem-store-proof-id-index store)))
    (with-problem-store-lock-held (store)
      (id-index-reserve v-id-index))))

;;; =========================================================================
;;; Index add/remove (locked)
;;; =========================================================================

(defun add-problem-store-inference (store inference)
  (let ((id (inference-suid inference)))
    (with-problem-store-lock-held (store)
      (id-index-enter (prob-store-inference-id-index store) id inference)))
  store)

(defun remove-problem-store-inference (store inference)
  (let ((id (inference-suid inference)))
    (with-problem-store-lock-held (store)
      (id-index-remove (prob-store-inference-id-index store) id)
      (problem-store-min-proof-depth-index-remove-inference store inference)
      (problem-store-min-transformation-depth-index-remove-inference store inference)
      (problem-store-min-transformation-depth-signature-index-remove-inference store inference)))
  store)

(defun add-problem-store-strategy (store strategy)
  (let ((id (strategy-suid strategy)))
    (with-problem-store-lock-held (store)
      (id-index-enter (prob-store-strategy-id-index store) id strategy)))
  store)

(defun remove-problem-store-strategy (store strategy)
  (let ((id (strategy-suid strategy)))
    (with-problem-store-lock-held (store)
      (id-index-remove (prob-store-strategy-id-index store) id)))
  store)

(defun add-problem-store-problem-by-id (store problem)
  (let ((id (problem-suid problem)))
    (with-problem-store-lock-held (store)
      (id-index-enter (prob-store-problem-id-index store) id problem)))
  store)

;; (defun remove-problem-store-problem-by-id (store problem) ...) -- active declareFunction, no body

(defun add-problem-store-problem-by-query (store problem)
  (when (problem-in-equality-reasoning-domain? problem)
    (let ((query (problem-query problem)))
      (with-problem-store-lock-held (store)
        (setf (gethash query (prob-store-problem-by-query-index store)) problem))))
  store)

;; (defun remove-problem-store-problem-by-query (store problem) ...) -- active declareFunction, no body

(defun add-problem-store-link (store link)
  (let ((id (problem-link-suid link)))
    (with-problem-store-lock-held (store)
      (id-index-enter (prob-store-link-id-index store) id link)))
  store)

(defun remove-problem-store-link (store link)
  (let ((id (problem-link-suid link)))
    (with-problem-store-lock-held (store)
      (id-index-remove (prob-store-link-id-index store) id)))
  store)

(defun add-problem-store-proof (store proof)
  (let ((id (proof-suid proof)))
    (with-problem-store-lock-held (store)
      (id-index-enter (prob-store-proof-id-index store) id proof)))
  store)

;; (defun remove-problem-store-proof (store proof) ...) -- active declareFunction, no body
;; (defun problem-store-forget-that-proof-is-rejected (store proof) ...) -- active declareFunction, no body
;; (defun problem-store-note-proof-processed (store proof) ...) -- active declareFunction, no body
;; (defun problem-store-note-proof-unprocessed (store proof) ...) -- active declareFunction, no body
;; (defun problem-store-note-non-explanatory-subproofs-possible (store) ...) -- active declareFunction, no body
;; (defun problem-store-note-non-explanatory-subproof (store proof subproof) ...) -- active declareFunction, no body
;; (defun proof-note-non-explanatory-subproof (proof subproof) ...) -- active declareFunction, no body
;; (defun reset-problem-store-min-depth-index (store) ...) -- active declareFunction, no body

(defun problem-store-min-proof-depth-index-remove-inference (store inference)
  (let ((index (problem-store-min-proof-depth-index store)))
    (remhash inference index))
  store)

(defun problem-store-min-transformation-depth-index-remove-inference (store inference)
  (let ((index (problem-store-min-transformation-depth-index store)))
    (remhash inference index))
  store)

(defun problem-store-min-transformation-depth-signature-index-remove-inference (store inference)
  (let ((index (problem-store-min-transformation-depth-signature-index store)))
    (remhash inference index))
  store)

(defun add-problem-store-historical-root-problem (store problem)
  (set-add problem (prob-store-historical-root-problems store)))

;; (defun remove-problem-store-historical-root-problem (store problem) ...) -- active declareFunction, no body

(defun finalize-problem-store-properties (store)
  "[Cyc] Call this after STORE is done being constructed. Sets all STORE's static properties to be no longer modifiable."
  (unless (problem-store-prepared? store)
    (note-problem-store-prepared store))
  store)

;; (defun add-problem-store-complex-problem (store problem) ...) -- active declareFunction, no body
;; (defun remove-problem-store-complex-problem (store problem) ...) -- active declareFunction, no body

(defun add-problem-store-problem (store problem)
  (add-problem-store-problem-by-id store problem)
  (add-problem-store-problem-by-query store problem)
  store)

;; (defun remove-problem-store-problem (store problem) ...) -- active declareFunction, no body
;; (defun remove-problem-wrt-reuse (store problem) ...) -- active declareFunction, no body

;;; =========================================================================
;;; Transformation rule tracking (memoized per problem store)
;;; =========================================================================

(defun problem-store-note-transformation-rule-considered (store rule)
  (with-problem-store-memoization-state (store)
    (ensure-transformation-rule-considered-noted rule))
  t)

(defun problem-store-note-transformation-rule-success (store rule)
  (with-problem-store-memoization-state (store)
    (ensure-transformation-rule-success-noted rule))
  nil)

(defun-memoized ensure-transformation-rule-considered-noted (rule) (:test eq)
  (when (rule-assertion? rule)
    (increment-transformation-rule-considered-count rule t)
    t))

(defun-memoized ensure-transformation-rule-success-noted (rule) (:test eq)
  (when (rule-assertion? rule)
    (increment-transformation-rule-success-count rule t)
    t))

;;; =========================================================================
;;; Problem Store Janitor
;;; =========================================================================

(defstruct (problem-store-janitor
            (:conc-name "prob-store-janitor-")
            (:predicate problem-store-janitor-p))
  store
  indestructible-problems
  stale?)

(defun new-problem-store-janitor (store)
  (declare (type problem-store store))
  (let ((janitor (make-problem-store-janitor)))
    (setf (prob-store-janitor-store janitor) store)
    (setf (prob-store-janitor-indestructible-problems janitor) (new-set #'eq))
    (problem-store-janitor-note-stale janitor)
    janitor))

(defun destroy-problem-store-janitor (janitor)
  (clear-set (prob-store-janitor-indestructible-problems janitor))
  (setf (prob-store-janitor-indestructible-problems janitor) :free)
  (setf (prob-store-janitor-store janitor) :free)
  (problem-store-janitor-note-stale janitor)
  nil)

;; (defun problem-store-janitor-store (janitor) ...) -- active declareFunction, no body
;; (defun problem-store-janitor-stale? (janitor) ...) -- active declareFunction, no body
;; (defun problem-store-janitor-indestructible-problems (janitor) ...) -- active declareFunction, no body

;; TODO - DO-PROBLEM-STORE-JANITOR-INDESTRUCTIBLE-PROBLEMS macro
;; Evidence: helper is problem-store-janitor-indestructible-problems, iterates over set

;; TODO - DO-PROBLEM-STORE-JANITOR-DESTRUCTIBLE-PROBLEMS macro
;; Evidence: declareMacro in Java

;; (defun problem-store-janitor-indestructible-problem-count (janitor) ...) -- active declareFunction, no body
;; (defun problem-store-janitor-destructible-problem-count (janitor) ...) -- active declareFunction, no body

(defun problem-store-janitor-note-stale (janitor)
  (setf (prob-store-janitor-stale? janitor) t)
  janitor)

;; (defun problem-store-janitor-note-unstale (janitor) ...) -- active declareFunction, no body
;; (defun problem-store-janitor-note-problem-indestructible (janitor problem) ...) -- active declareFunction, no body
;; (defun problem-store-janitor-note-problem-destructible (janitor problem) ...) -- active declareFunction, no body

;;; =========================================================================
;;; Problem Store Naming
;;; =========================================================================

(defglobal *problem-store-id-to-name-table* (make-hash-table :test #'eql))
(defglobal *problem-store-name-to-id-table* (make-hash-table :test #'equal))

(defun problem-store-name (problem-store)
  "[Cyc] Returns an object which is the unique name of PROBLEM-STORE. This object can be of any type, but names are assumed unique wrt the #'equal test."
  (declare (type problem-store problem-store))
  (let ((id (problem-store-suid problem-store)))
    (gethash id *problem-store-id-to-name-table*)))

(defun find-problem-store-by-name (name)
  "[Cyc] Return nil or problem-store-p."
  (when name
    (let ((id (gethash name *problem-store-name-to-id-table*)))
      (when id
        ;; Likely calls find-problem-store-by-id
        (missing-larkc 33112)))))

;; (defun find-or-create-problem-store-by-name (name &optional properties) ...) -- active declareFunction, no body
;; (defun destroy-problem-store-by-name (name) ...) -- active declareFunction, no body
;; (defun rename-problem-store (store new-name) ...) -- active declareFunction, no body

(defun set-problem-store-name (problem-store name)
  (when name
    (let ((id (problem-store-suid problem-store)))
      (setf (gethash id *problem-store-id-to-name-table*) name)
      (setf (gethash name *problem-store-name-to-id-table*) id)))
  problem-store)

(defun free-problem-store-name (problem-store)
  (let ((id (problem-store-suid problem-store))
        (name (problem-store-name problem-store)))
    (remhash id *problem-store-id-to-name-table*)
    (remhash name *problem-store-name-to-id-table*))
  nil)

;; (defun problem-store-properties (store) ...) -- active declareFunction, no body
;; (defun problem-store-property-value (store property) ...) -- active declareFunction, no body

;;; =========================================================================
;;; Setup phase (toplevel forms)
;;; =========================================================================

(toplevel (declare-defglobal '*problem-store-id-index*))
(toplevel (register-macro-helper 'problem-store-id-index 'do-all-problem-stores))
(toplevel (register-macro-helper 'problem-store-lock 'with-problem-store-lock-held))
(toplevel (register-macro-helper 'problem-store-memoization-state 'with-problem-store-memoization-state))
(toplevel (register-macro-helper 'problem-store-sbhl-resource-space 'with-problem-store-sbhl-resource-space))
(toplevel (register-macro-helper 'set-problem-store-sbhl-resource-space 'with-problem-store-sbhl-resource-space))
(toplevel (register-macro-helper 'problem-store-inference-id-index 'do-problem-store-inferences))
(toplevel (register-macro-helper 'problem-store-strategy-id-index 'do-problem-store-strategies))
(toplevel (register-macro-helper 'problem-store-problem-id-index 'do-problem-store-problems))
(toplevel (register-macro-helper 'problem-store-link-id-index 'do-problem-store-links))
(toplevel (register-macro-helper 'problem-store-proof-id-index 'do-problem-store-proofs))
(toplevel (register-macro-helper 'problem-store-historical-root-problems 'do-problem-store-historical-root-problems))
(toplevel (note-memoized-function 'ensure-transformation-rule-considered-noted))
(toplevel (note-memoized-function 'ensure-transformation-rule-success-noted))
(toplevel (register-macro-helper 'problem-store-janitor-indestructible-problems 'do-problem-store-janitor-indestructible-problems))
(toplevel (declare-defglobal '*problem-store-id-to-name-table*))
(toplevel (declare-defglobal '*problem-store-name-to-id-table*))
(toplevel (register-external-symbol 'find-problem-store-by-name))
(toplevel (register-external-symbol 'find-or-create-problem-store-by-name))
(toplevel (register-external-symbol 'destroy-problem-store-by-name))
