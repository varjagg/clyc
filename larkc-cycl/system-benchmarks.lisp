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

;; CycLOPs benchmarking suite. Builds a synthetic collection ontology,
;; asserts family/parent/ancestor/sibling predicates, runs test queries,
;; and measures the elapsed time to produce a CycLOPs score.

(defvar *cyclops-family-fix-enabled?* nil
    "[Cyc] When non-NIL, a uniquifying FAMILY predicate is added")

(defparameter *cyclops-anect-fix-enabled?* t
    "[Cyc] Temporary control variable;
   When non-nil
   (1) we assert the ANECT of the created term in BaseKB
   (2) we assert the the non-ANECTs of the term in a lower Mt
   When nil
   (1) we only assert the non-ANECTs of the term in BaseKB.")

(defvar *benchmark-cyclops-power* 6)

(defvar *benchmark-cyclops-ontology-root* #$Individual
    "[Cyc] The top of the ontology created by CycLOPs.")

(deflexical *cyclops-throwaway-default* 33)

(defun benchmark-cyclops-compensating-for-paging (&optional (throwaway-n *cyclops-throwaway-default*) (sample-n 7) (power *benchmark-cyclops-power*) (stream *standard-output*))
  "[Cyc] The standard interface function for CycLOPs benchmarking.
   Runs the CycLOPs benchmark THROWAWAY-N times and ignores those results.
   Then runs it SAMPLE-N more times and returns the median of those sampled results."
  (let ((total-n (+ throwaway-n sample-n)))
    (median-cyclops total-n power stream throwaway-n)))

(defun benchmark-cyclops-n-times (n &optional (power *benchmark-cyclops-power*) (stream *standard-output*) (throw-away-first-n 0))
  "[Cyc] @param THROW-AWAY-FIRST-N integerp; if zero, has no effect.
   if greater than zero, it will toss out (i.e. not return) the first THROW-AWAY-FIRST-N results.
   This can be used to compensate for paging."
  (declare (type (satisfies non-negative-integer-p) n power))
  (let ((values nil))
    (multiple-value-bind (mt-1 mt-2 collections bottom-collection parent ancestor sibling family)
        (benchmark-cyclops-setup)
      (unwind-protect
           (dotimes (i n)
             (let* ((guts-time (benchmark-cyclops-guts power mt-1 mt-2 bottom-collection parent ancestor sibling family))
                    (cyclops (benchmark-cyclops-compute-and-print-statistics stream power guts-time)))
               (when (>= i throw-away-first-n)
                 (push cyclops values))))
        (let ((*is-thread-performing-cleanup?* t))
          (benchmark-cyclops-teardown mt-1 mt-2 collections parent ancestor sibling family))))
    (setf values (nreverse values))
    (when (> n 1)
      (missing-larkc 31856))
    values))

;; (defun benchmark-cyclops (&optional power stream) ...) -- active declareFunction, no body

(defun median-cyclops (n &optional (power *benchmark-cyclops-power*) (stream *standard-output*) (throw-away-first-n 0))
  "[Cyc] Runs benchmark-cyclops N times and returns the median recorded value."
  (let ((cyclops (median (benchmark-cyclops-n-times n power stream throw-away-first-n)))
        (bogomips (machine-bogomips)))
    (if bogomips
        (values cyclops (/ bogomips cyclops))
        cyclops)))

;; (defun max-cyclops (n &optional power stream throw-away-first-n) ...) -- active declareFunction, no body
;; (defun benchmark-cyclops-setup-and-teardown () ...) -- active declareFunction, no body

(defun benchmark-cyclops-setup ()
  "[Cyc] initialization"
  (let ((mt-1 nil)
        (mt-2 nil)
        (collections nil)
        (top-collection nil)
        (bottom-collection nil)
        (parent nil)
        (ancestor nil)
        (sibling nil)
        (family nil))
    (let ((*silent-progress?* t)
          (*standard-output* *null-output*))
      (multiple-value-setq (mt-1 mt-2) (benchmark-cyclops-create-mts))
      (multiple-value-setq (collections top-collection bottom-collection) (benchmark-cyclops-create-ontology))
      (setf parent (benchmark-cyclops-create-parent top-collection))
      (setf ancestor (benchmark-cyclops-create-ancestor top-collection))
      (setf sibling (benchmark-cyclops-create-sibling top-collection))
      (setf family (benchmark-cyclops-create-family top-collection))
      (benchmark-cyclops-define-predicates parent ancestor sibling family))
    (values mt-1 mt-2 collections bottom-collection parent ancestor sibling family)))

(defun benchmark-cyclops-guts (power mt-1 mt-2 bottom-collection parent ancestor sibling family)
  (gc-ephemeral)
  (let* ((time nil)
         (time-var (get-internal-real-time)))
    (benchmark-cyclops-guts-int 0 power mt-1 mt-2 bottom-collection parent ancestor sibling family)
    (setf time (/ (- (get-internal-real-time) time-var) internal-time-units-per-second))
    time))

(defun benchmark-cyclops-guts-int (uniquifier power mt-1 mt-2 bottom-collection parent ancestor sibling family)
  "[Cyc] the scalable portion"
  (let ((*silent-progress?* t)
        (*standard-output* *null-output*)
        (*inference-intermediate-step-validation-level* :none)
        (*suspend-type-checking?* t))
    (progv *fi-state-variables* (make-list (length *fi-state-variables*) :initial-element nil)
      (let ((*within-assertion-forward-propagation?* nil)
            (*prefer-forward-skolemization* nil))
        (let ((environment (get-forward-inference-environment)))
          (declare (type (satisfies queue-p) environment))
          (let ((*forward-inference-environment* environment)
                (*current-forward-problem-store* nil))
            (unwind-protect
                 (let ((sbhl-ms-resource (new-sbhl-marking-space-resource 10)))
                   (let ((*resourced-sbhl-marking-spaces* sbhl-ms-resource)
                         (*resourcing-sbhl-marking-spaces-p* t)
                         (*resourced-sbhl-marking-space-limit* (determine-marking-space-limit sbhl-ms-resource)))
                     (let ((k (- (expt 2 power) 1))
                           (terms nil))
                       (unwind-protect
                            (progn
                              (setf terms (benchmark-cyclops-create-terms uniquifier k bottom-collection mt-1))
                              (benchmark-cyclops-assert-family-links uniquifier k terms family mt-1)
                              (benchmark-cyclops-assert-parent-links k terms parent mt-1)
                              (benchmark-cyclops-query-parent-links k terms parent mt-2)
                              (benchmark-cyclops-query-ancestor-links k terms ancestor mt-1)
                              (benchmark-cyclops-query-sibling-links-via-rule k terms sibling mt-2)
                              (benchmark-cyclops-forward-propagate-sibling-rule uniquifier parent sibling family)
                              (benchmark-cyclops-turn-sibling-rule-backward uniquifier parent sibling family)
                              (benchmark-cyclops-query-sibling-links-via-lookup k terms sibling mt-2))
                         (let ((*is-thread-performing-cleanup?* t))
                           (benchmark-cyclops-kill-terms k terms)))
                       (setf sbhl-ms-resource *resourced-sbhl-marking-spaces*))))
              (let ((*is-thread-performing-cleanup?* t))
                (clear-current-forward-problem-store))))))))
  nil)

(defun benchmark-cyclops-teardown (mt-1 mt-2 collections parent ancestor sibling family)
  "[Cyc] cleanup"
  (let ((*silent-progress?* t)
        (*standard-output* *null-output*))
    (benchmark-cyclops-kill-vocabulary mt-1 mt-2 collections parent ancestor sibling family))
  nil)

(defun benchmark-cyclops-compute-and-print-statistics (stream power guts-time)
  (let* ((k (- (expt 2 power) 1))
         (efficiency (/ guts-time k))
         (cyclops (/ 1 efficiency))
         (bogomips (machine-bogomips)))
    (benchmark-cyclops-print-statistics stream bogomips k guts-time efficiency cyclops)
    cyclops))

(defun benchmark-cyclops-create-mts ()
  (let ((mt-1 nil)
        (mt-2 nil))
    (setf mt-1 (cyc-create-new-ephemeral "Mt-1"))
    (setf mt-2 (cyc-create-new-ephemeral "Mt-2"))
    (cyc-assert-wff (list* #$isa mt-1 (list #$Microtheory)) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list* #$isa mt-2 (list #$Microtheory)) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list #$genlMt mt-2 mt-1) #$BaseKB '(:strength :monotonic :direction :forward))
    (values mt-1 mt-2)))

(defun benchmark-cyclops-create-ontology ()
  (let ((collections nil)
        (top-collection nil)
        (bottom-collection nil))
    (setf *progress-note* "Creating collection ontology")
    (setf *progress-start-time* (get-universal-time))
    (setf *progress-total* 25)
    (setf *progress-so-far* 0)
    (noting-percent-progress (*progress-note*)
      (dotimes (i *progress-total*)
        (note-percent-progress *progress-so-far* *progress-total*)
        (setf *progress-so-far* (+ *progress-so-far* 1))
        (let ((collection (cyc-create-new-ephemeral (cconcatenate "Col-" (format-nil-a-no-copy i)))))
          (setf collections (cons collection collections))
          (cyc-assert-wff (list* #$isa collection (list #$Collection)) #$BaseKB '(:strength :monotonic :direction :forward)))))
    (let ((previous *benchmark-cyclops-ontology-root*))
      (dolist (collection collections)
        (cyc-assert-wff (list #$genls collection previous) #$BaseKB '(:strength :monotonic :direction :forward))
        (setf previous collection)))
    (setf top-collection (first collections))
    (setf bottom-collection (first (last collections)))
    (values collections top-collection bottom-collection)))

(defun benchmark-cyclops-create-parent (top-collection)
  (let ((parent (cyc-create-new-ephemeral "parent")))
    (cyc-assert-wff (list* #$isa parent (list #$IrreflexiveBinaryPredicate)) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list* #$isa parent (list #$AsymmetricBinaryPredicate)) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list #$arg1Isa parent top-collection) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list #$arg2Isa parent top-collection) #$BaseKB '(:strength :monotonic :direction :forward))
    parent))

(defun benchmark-cyclops-create-ancestor (top-collection)
  (let ((ancestor (cyc-create-new-ephemeral "ancestor")))
    (cyc-assert-wff (list* #$isa ancestor (list #$ReflexiveBinaryPredicate)) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list* #$isa ancestor (list #$AntiSymmetricBinaryPredicate)) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list* #$isa ancestor (list #$TransitiveBinaryPredicate)) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list #$arg1Isa ancestor top-collection) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list #$arg2Isa ancestor top-collection) #$BaseKB '(:strength :monotonic :direction :forward))
    ancestor))

(defun benchmark-cyclops-create-sibling (top-collection)
  (let ((sibling (cyc-create-new-ephemeral "sibling")))
    (cyc-assert-wff (list* #$isa sibling (list #$IrreflexiveBinaryPredicate)) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list* #$isa sibling (list #$SymmetricBinaryPredicate)) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list #$arg1Isa sibling top-collection) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list #$arg2Isa sibling top-collection) #$BaseKB '(:strength :monotonic :direction :forward))
    sibling))

(defun benchmark-cyclops-create-family (top-collection)
  (let ((family (cyc-create-new-ephemeral "family")))
    (cyc-assert-wff (list* #$isa family (list #$BinaryPredicate)) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list #$arg1Isa family top-collection) #$BaseKB '(:strength :monotonic :direction :forward))
    (cyc-assert-wff (list* #$arg2Isa family (list #$Integer)) #$BaseKB '(:strength :monotonic :direction :forward))
    family))

(defun benchmark-cyclops-define-predicates (parent ancestor sibling family)
  (cyc-assert-wff (list #$genlPreds parent ancestor) #$BaseKB '(:strength :monotonic :direction :forward))
  (benchmark-cyclops-assert-sibling-rule -1 parent sibling family :backward)
  nil)

(defun benchmark-cyclops-assert-sibling-rule (uniquifier parent sibling family direction)
  (let ((v-properties (list :strength :monotonic :direction direction))
        (sentence nil))
    (if (and *cyclops-family-fix-enabled?*
             (not (minusp uniquifier)))
        (setf sentence (list #$implies
                             (list #$and '(#$different ?CHILD-1 ?CHILD-2) (list family '?PARENT uniquifier)
                                   (cons parent '(?CHILD-1 ?PARENT))
                                   (cons parent '(?CHILD-2 ?PARENT)))
                             (cons sibling '(?CHILD-1 ?CHILD-2))))
        (setf sentence (list #$implies
                             (list #$and (list #$different '?CHILD-1 '?CHILD-2 uniquifier)
                                   (cons parent '(?CHILD-1 ?PARENT))
                                   (cons parent '(?CHILD-2 ?PARENT)))
                             (cons sibling '(?CHILD-1 ?CHILD-2)))))
    (cyc-assert-wff sentence #$BaseKB v-properties)))

(defparameter *cyclops-locked?* nil)

(deflexical *cyclops-lock*
  (if (and (boundp '*cyclops-lock*)
           (typep *cyclops-lock* 'bt:lock))
      *cyclops-lock*
      (bt:make-lock "CycLOPs lock"))
    "[Cyc] This is a temporary proxy for better HL lock handling.")

;; Reconstructed from Internal Constants: $sym49$PIF, $sym50$_CYCLOPS_LOCKED__,
;; $sym51$WITH_LOCK_HELD, $list52=(*CYCLOPS-LOCK*), $sym53$PROGN.
;; Expansion visible inline in every function that guards its body on
;; *CYCLOPS-LOCKED?* with a seize-lock/release-lock pair around *CYCLOPS-LOCK*.
(defmacro with-cyclops-lock (&body body)
  `(pif *cyclops-locked?*
        (bt:with-lock-held (*cyclops-lock*) ,@body)
        (progn ,@body)))

(defun benchmark-cyclops-create-terms (uniquifier k bottom-collection mt-1)
  (when (not *cyclops-anect-fix-enabled?*)
    (setf mt-1 #$BaseKB))
  (let ((terms nil))
    (setf *progress-note* "Creating terms")
    (setf *progress-start-time* (get-universal-time))
    (setf *progress-total* k)
    (setf *progress-so-far* 0)
    (noting-percent-progress (*progress-note*)
      (dotimes (i *progress-total*)
        (note-percent-progress *progress-so-far* *progress-total*)
        (setf *progress-so-far* (+ *progress-so-far* 1))
        (let ((v-term (benchmark-cyclops-create-term uniquifier i)))
          (setf terms (cons v-term terms))
          (when *cyclops-anect-fix-enabled?*
            (with-cyclops-lock
              (cyc-assert-wff (list* #$isa v-term (list #$Individual)) #$BaseKB '(:strength :monotonic :direction :forward))))
          (with-cyclops-lock
            (cyc-assert-wff (list #$isa v-term bottom-collection) mt-1 '(:strength :monotonic :direction :forward))))))
    (setf terms (apply (symbol-function 'vector) (nreverse terms)))
    terms))

(defun benchmark-cyclops-create-term (uniquifier index)
  (let ((v-term nil))
    (with-cyclops-lock
      (setf v-term (cyc-create-new-ephemeral (cconcatenate "Term-" (format-nil-a-no-copy uniquifier) "-" (format-nil-a-no-copy index)))))
    v-term))

(defun benchmark-cyclops-assert-family-links (uniquifier k terms family mt-1)
  (setf *progress-note* "Asserting family links")
  (setf *progress-start-time* (get-universal-time))
  (setf *progress-total* k)
  (setf *progress-so-far* 0)
  (noting-percent-progress (*progress-note*)
    (dotimes (i *progress-total*)
      (note-percent-progress *progress-so-far* *progress-total*)
      (setf *progress-so-far* (+ *progress-so-far* 1))
      (with-cyclops-lock
        (cyc-assert-wff (list family (aref terms i) uniquifier) mt-1 '(:strength :monotonic :direction :forward)))))
  nil)

(defun benchmark-cyclops-assert-parent-links (k terms parent mt-1)
  (setf *progress-note* "Asserting parent links")
  (setf *progress-start-time* (get-universal-time))
  (setf *progress-total* k)
  (setf *progress-so-far* 0)
  (noting-percent-progress (*progress-note*)
    (dotimes (i *progress-total*)
      (note-percent-progress *progress-so-far* *progress-total*)
      (setf *progress-so-far* (+ *progress-so-far* 1))
      (unless (= i 0)
        (with-cyclops-lock
          (cyc-assert-wff (list parent (aref terms i) (aref terms (floor (- i 1) 2))) mt-1 '(:strength :monotonic :direction :forward))))))
  nil)

(defun benchmark-cyclops-query (sentence mt v-properties error-spec)
  (let ((result (new-cyc-query sentence mt v-properties)))
    (when result
      (return-from benchmark-cyclops-query result))
    (apply (symbol-function 'warn) error-spec))
  (let ((result (new-cyc-query sentence mt v-properties)))
    (when result
      (return-from benchmark-cyclops-query result))
    (apply (symbol-function 'error) error-spec))
  nil)

(defun benchmark-cyclops-query-parent-links (k terms parent mt-2)
  (setf *progress-note* "Asking parent links")
  (setf *progress-start-time* (get-universal-time))
  (setf *progress-total* k)
  (setf *progress-so-far* 0)
  (noting-percent-progress (*progress-note*)
    (dotimes (i *progress-total*)
      (note-percent-progress *progress-so-far* *progress-total*)
      (setf *progress-so-far* (+ *progress-so-far* 1))
      (unless (= i 0)
        (let ((sentence (list* parent (aref terms i) '(?PARENT))))
          (benchmark-cyclops-query sentence mt-2 nil (list "CycLOPs error asking parent ~S" i))))))
  nil)

(defun benchmark-cyclops-query-ancestor-links (k terms ancestor mt-1)
  (setf *progress-note* "Asking ancestor links")
  (setf *progress-start-time* (get-universal-time))
  (setf *progress-total* k)
  (setf *progress-so-far* 0)
  (noting-percent-progress (*progress-note*)
    (dotimes (i *progress-total*)
      (note-percent-progress *progress-so-far* *progress-total*)
      (setf *progress-so-far* (+ *progress-so-far* 1))
      (unless (= i 0)
        (let ((sentence (list #$and
                              (list* ancestor (aref terms i) '(?ANCEST))
                              (list* #$different (aref terms i) '(?ANCEST)))))
          (benchmark-cyclops-query sentence mt-1 nil (list "CycLOPs error: asking ancestor ~S" i))))))
  nil)

(defun benchmark-cyclops-query-sibling-links-via-rule (k terms sibling mt-2)
  (setf *progress-note* "Asking sibling links")
  (setf *progress-start-time* (get-universal-time))
  (setf *progress-total* k)
  (setf *progress-so-far* 0)
  (noting-percent-progress (*progress-note*)
    (dotimes (i *progress-total*)
      (note-percent-progress *progress-so-far* *progress-total*)
      (setf *progress-so-far* (+ *progress-so-far* 1))
      (unless (= i 0)
        (let ((sentence (list* sibling (aref terms i) '(?SIBLING)))
              (v-properties '(:max-transformation-depth 1)))
          (benchmark-cyclops-query sentence mt-2 v-properties (list "CycLOPs error: asking sibling ~S via rule" i))))))
  nil)

(defun benchmark-cyclops-forward-propagate-sibling-rule (uniquifier parent sibling family)
  (with-cyclops-lock
    (benchmark-cyclops-assert-sibling-rule uniquifier parent sibling family :forward))
  nil)

(defun benchmark-cyclops-turn-sibling-rule-backward (uniquifier parent sibling family)
  (with-cyclops-lock
    (benchmark-cyclops-assert-sibling-rule uniquifier parent sibling family :backward))
  nil)

(defun benchmark-cyclops-query-sibling-links-via-lookup (k terms sibling mt-2)
  (setf *progress-note* "Asking sibling links")
  (setf *progress-start-time* (get-universal-time))
  (setf *progress-total* k)
  (setf *progress-so-far* 0)
  (noting-percent-progress (*progress-note*)
    (dotimes (i *progress-total*)
      (note-percent-progress *progress-so-far* *progress-total*)
      (setf *progress-so-far* (+ *progress-so-far* 1))
      (unless (= i 0)
        (let ((sentence (list* sibling (aref terms i) '(?SIBLING))))
          (benchmark-cyclops-query sentence mt-2 nil (list "CycLOPs error: asking sibling ~S" i))))))
  nil)

(defun benchmark-cyclops-kill-terms (k terms)
  (setf *progress-note* "Killing terms")
  (setf *progress-start-time* (get-universal-time))
  (setf *progress-total* k)
  (setf *progress-so-far* 0)
  (noting-percent-progress (*progress-note*)
    (dotimes (i *progress-total*)
      (note-percent-progress *progress-so-far* *progress-total*)
      (setf *progress-so-far* (+ *progress-so-far* 1))
      (with-cyclops-lock
        (cyc-kill (aref terms i)))))
  nil)

(defun benchmark-cyclops-kill-vocabulary (mt-1 mt-2 collections parent ancestor sibling family)
  (let ((list-var collections))
    (setf *progress-note* "Killing collections")
    (setf *progress-start-time* (get-universal-time))
    (setf *progress-total* (length list-var))
    (setf *progress-so-far* 0)
    (noting-percent-progress (*progress-note*)
      (dolist (col list-var)
        (note-percent-progress *progress-so-far* *progress-total*)
        (setf *progress-so-far* (+ *progress-so-far* 1))
        (cyc-kill col))))
  (cyc-kill family)
  (cyc-kill sibling)
  (cyc-kill ancestor)
  (cyc-kill parent)
  (cyc-kill mt-2)
  (cyc-kill mt-1)
  nil)

(defun benchmark-cyclops-print-statistics (stream bogomips k guts-time efficiency cyclops)
  (let ((*read-default-float-format* 'double-float))
    (format stream "~%CycLOPs Benchmark Results")
    (format stream "~%========================================")
    (format stream "~%System ~S.~S KB ~S" (cycl-system-number) (cycl-patch-number) (kb-loaded))
    (when bogomips
      (format stream "~%Bogomips :~% ~S" bogomips))
    (format stream "~%Scaling factor :~% ~S" k)
    (format stream "~%Elapsed time (seconds) :~% ~S" (significant-digits guts-time 4))
    (format stream "~%Efficiency (seconds/op) :~% ~S" (significant-digits efficiency 4))
    (format stream "~%CycLOPs :~% ~S" (significant-digits cyclops 4))
    (when bogomips
      (format stream "~%Bogomips/CycLOPs : ~% ~S" (significant-digits (/ bogomips cyclops) 4)))
    (terpri stream)
    (force-output stream))
  stream)

;; (defun benchmark-cyclops-print-statistical-summary (stream sampled-data) ...) -- active declareFunction, no body
;; (defun benchmark-parallel-cyclops-compensating-for-paging (&optional parallelism throwaway-n sample-n power stream) ...) -- active declareFunction, no body
;; (defun benchmark-parallel-cyclops-efficiency (parallelism &optional power stream throw-away-first-n) ...) -- active declareFunction, no body
;; (defun median-parallel-cyclops (parallelism n &optional power stream throw-away-first-n) ...) -- active declareFunction, no body
;; (defun benchmark-parallel-cyclops-n-times (parallelism n &optional power stream throw-away-first-n) ...) -- active declareFunction, no body
;; (defun benchmark-parallel-cyclops-guts (parallelism power mt-1 mt-2 bottom-collection parent ancestor sibling family) ...) -- active declareFunction, no body
;; (defun benchmark-parallel-cyclops-guts-thread (thread-index uniquifier power mt-1 mt-2 bottom-collection parent ancestor sibling family) ...) -- active declareFunction, no body
;; (defun benchmark-parallel-cyclops-compute-and-print-statistics (stream power parallelism guts-time) ...) -- active declareFunction, no body
;; (defun benchmark-parallel-cyclops-print-statistics (stream bogomips parallelism k guts-time efficiency cyclops) ...) -- active declareFunction, no body
;; (defun benchmark-parallel-cyclops-print-statistical-summary (stream parallelism sampled-data) ...) -- active declareFunction, no body
;; (defun benchmark-cyclops-sample (n &optional power) ...) -- active declareFunction, no body

(toplevel
  ;; CVS_ID("Id: system-benchmarks.lisp 126640 2008-12-04 13:39:36Z builder ")
  (register-external-symbol 'benchmark-cyclops-compensating-for-paging)
  (declare-defglobal '*cyclops-lock*)
  (register-external-symbol 'benchmark-parallel-cyclops-compensating-for-paging)
  (define-obsolete-register 'benchmark-cyclops-sample '(benchmark-cyclops-compensating-for-paging)))
