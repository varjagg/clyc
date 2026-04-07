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

;; Inference strategy datastructures. A strategy controls how inference
;; explores the problem store, managing active/motivated/set-aside
;; problems and dispatching to specific tactician implementations.


;;; strategy defstruct — 15 slots, conc-name "strat-"

(defstruct (strategy
            (:conc-name "strat-")
            (:predicate strategy-p)
            (:print-function print-strategy))
  suid
  inference
  result-uniqueness-criterion
  active-problems
  motivated-problems
  set-aside-problems
  should-reconsider-set-asides?
  productivity-limit
  removal-backtracking-productivity-limit
  proof-spec
  problem-proof-spec-index
  problem-strategic-index
  memoization-state
  type
  data)

(defun strategy-print-function-trampoline (object stream)
  "[Cyc] Trampoline for printing strategies."
  ;; Likely calls print-strategy — evidence: $sym6$PRINT_STRATEGY
  (missing-larkc 36447))

(defun valid-strategy-p (object)
  (and (strategy-p object)
       (not (strategy-invalid-p object))))

(defun strategy-invalid-p (strategy)
  (eq :free (strategy-type strategy)))

;; (defun print-strategy (object stream depth) ...) -- active declareFunction, no body

(defun sxhash-strategy-method (object)
  (strat-suid object))


;;; Variables

(defconstant *dtp-strategy* 'strategy)

(defparameter *current-strategy-wrt-memoization* nil
  "[Cyc] The strategy of the currently active strategy memoization state, if any.")

(defglobal *strategy-type-store*
  (if (and (boundp '*strategy-type-store*) (hash-table-p *strategy-type-store*))
      *strategy-type-store*
      (make-hash-table :test #'eq :size 5)))

(defparameter *uninterestingness-cache-lookup-enabled?* t)

(defconstant *default-uninterestingness-flags* 0)

(defconstant *uninterestingness-cache-thrown-away-wrt-removal-byte*
  (byte 2 0))
(defconstant *uninterestingness-cache-thrown-away-wrt-transformation-byte*
  (byte 2 2))
(defconstant *uninterestingness-cache-thrown-away-wrt-new-root-byte*
  (byte 2 4))
(defconstant *uninterestingness-cache-set-aside-wrt-removal-byte*
  (byte 2 6))
(defconstant *uninterestingness-cache-set-aside-wrt-transformation-byte*
  (byte 2 8))
(defconstant *uninterestingness-cache-set-aside-wrt-new-root-byte*
  (byte 2 10))
(defconstant *uninterestingness-cache-thrown-away-byte*
  (byte 2 12))
(defconstant *uninterestingness-cache-set-aside-byte*
  (byte 2 14))

(defconstant *dtp-problem-strategic-properties* 'problem-strategic-properties)

(defconstant *dtp-tactic-strategic-properties* 'tactic-strategic-properties)


;;; Functions — in source order from declareFunction

(defun new-strategy (type inference)
  (declare (type symbol type))
  (let* ((store (inference-problem-store inference))
         (suid (problem-store-new-strategy-id store))
         (strategy (make-strategy)))
    (setf (strat-suid strategy) suid)
    (setf (strat-inference strategy) inference)
    (setf (strat-result-uniqueness-criterion strategy) nil)
    (setf (strat-active-problems strategy) (new-set #'eq))
    (setf (strat-motivated-problems strategy)
          (new-set-contents 0 #'eq))
    (setf (strat-set-aside-problems strategy) (new-set #'eq))
    (setf (strat-problem-proof-spec-index strategy)
          (make-hash-table :test #'eq))
    (setf (strat-should-reconsider-set-asides? strategy) nil)
    (setf (strat-productivity-limit strategy)
          *default-productivity-limit*)
    (setf (strat-removal-backtracking-productivity-limit strategy)
          *default-removal-backtracking-productivity-limit*)
    (setf (strat-proof-spec strategy)
          *default-proof-spec*)
    (setf (strat-problem-strategic-index strategy)
          (make-hash-table :test #'eq :size 1))
    (setf (strat-memoization-state strategy)
          (new-memoization-state))
    (setf (strat-type strategy) type)
    (setf (strat-data strategy) nil)
    (let ((subconstructor (strategy-type-property type :constructor)))
      (funcall subconstructor strategy))
    (add-problem-store-strategy store strategy)
    (add-inference-strategy inference strategy)
    strategy))

;; (defun destroy-strategy (strategy) ...) -- active declareFunction, no body

(defun destroy-problem-store-strategy (strategy)
  (when (valid-strategy-p strategy)
    (note-strategy-invalid strategy)
    (destroy-strategy-int strategy)))

(defun destroy-inference-strategy (strategy)
  (when (valid-strategy-p strategy)
    (note-strategy-invalid strategy)
    (remove-problem-store-strategy (strategy-problem-store strategy) strategy)
    (destroy-strategy-int strategy)))

(defun destroy-strategy-int (strategy)
  (setf (strat-data strategy) :free)
  (setf (strat-proof-spec strategy) :free)
  (setf (strat-removal-backtracking-productivity-limit strategy) :free)
  (setf (strat-productivity-limit strategy) :free)
  (setf (strat-should-reconsider-set-asides? strategy) :free)
  (clear-all-memoization (strategy-memoization-state strategy))
  (setf (strat-memoization-state strategy) :free)
  (clrhash (strat-problem-proof-spec-index strategy))
  (setf (strat-problem-proof-spec-index strategy) :free)
  (clrhash (strat-problem-strategic-index strategy))
  (setf (strat-problem-strategic-index strategy) :free)
  (clear-set (strat-set-aside-problems strategy))
  (setf (strat-set-aside-problems strategy) :free)
  (clear-set (strat-active-problems strategy))
  (setf (strat-active-problems strategy) :free)
  (clear-set-contents (strat-motivated-problems strategy))
  (setf (strat-motivated-problems strategy) :free)
  (setf (strat-result-uniqueness-criterion strategy) :free)
  (setf (strat-inference strategy) :free)
  nil)

(defun note-strategy-invalid (strategy)
  (setf (strat-type strategy) :free)
  strategy)

;; (defun remove-strategy-problem (strategy problem) ...) -- active declareFunction, no body

(defun strategy-suid (strategy)
  (declare (type strategy strategy))
  (strat-suid strategy))

(defun strategy-inference (strategy)
  (declare (type strategy strategy))
  (strat-inference strategy))

(defun strategy-local-result-uniqueness-criterion (strategy)
  (declare (type strategy strategy))
  (strat-result-uniqueness-criterion strategy))

(defun strategy-problem-strategic-index (strategy)
  (strat-problem-strategic-index strategy))

(defun strategy-type (strategy)
  (strat-type strategy))

(defun strategy-data (strategy)
  (declare (type strategy strategy))
  (strat-data strategy))

(defun strategy-active-problems (strategy)
  (declare (type strategy strategy))
  (strat-active-problems strategy))

(defun strategy-motivated-problems (strategy)
  (declare (type strategy strategy))
  (strat-motivated-problems strategy))

(defun strategy-set-aside-problems (strategy)
  (declare (type strategy strategy))
  (strat-set-aside-problems strategy))

(defun strategy-should-reconsider-set-asides? (strategy)
  (declare (type strategy strategy))
  (strat-should-reconsider-set-asides? strategy))

(defun strategy-productivity-limit (strategy)
  "[Cyc] @return productivity-p If a tactic's productivity meets or exceeds this limit, it will be ignored instead of executed."
  (declare (type strategy strategy))
  (strat-productivity-limit strategy))

(defun strategy-removal-backtracking-productivity-limit (strategy)
  "[Cyc] @return productivity-p If a tactic's productivity meets or exceeds this limit, it will not be considered for removal backtracking."
  (declare (type strategy strategy))
  (strat-removal-backtracking-productivity-limit strategy))

(defun strategy-proof-spec (strategy)
  "[Cyc] @return proof-spec-p The proof spec that this strategy is allowed to apply."
  (declare (type strategy strategy))
  (strat-proof-spec strategy))

;; (defun strategy-problem-proof-spec-index (strategy) ...) -- active declareFunction, no body

;; (defun set-strategy-result-uniqueness-criterion (strategy criterion) ...) -- active declareFunction, no body

(defun set-strategy-productivity-limit (strategy productivity-limit)
  (declare (type strategy strategy))
  (setf (strat-productivity-limit strategy) productivity-limit)
  strategy)

;; (defun set-strategy-removal-backtracking-productivity-limit (strategy limit) ...) -- active declareFunction, no body
;; (defun set-strategy-proof-spec (strategy proof-spec) ...) -- active declareFunction, no body

(defun set-strategy-data (strategy data)
  (declare (type strategy strategy))
  (setf (strat-data strategy) data)
  strategy)


;;; Macros

;; Reconstructed from: $list70=((PROBLEM-VAR STRATEGY &KEY DONE) &BODY BODY),
;; $sym74$DO_SET, $sym61$STRATEGY_ACTIVE_PROBLEMS
;; register_macro_helper: STRATEGY-ACTIVE-PROBLEMS -> DO-STRATEGY-ACTIVE-PROBLEMS
(defmacro do-strategy-active-problems ((problem-var strategy &key done) &body body)
  `(do-set (,problem-var (strategy-active-problems ,strategy) :done ,done)
     ,@body))

;; Reconstructed from: $list70 (same arglist pattern),
;; $sym75$DO_SET_CONTENTS, $sym63$STRATEGY_MOTIVATED_PROBLEMS
;; register_macro_helper: STRATEGY-MOTIVATED-PROBLEMS -> DO-STRATEGY-MOTIVATED-PROBLEMS
(defmacro do-strategy-motivated-problems ((problem-var strategy &key done) &body body)
  `(do-set-contents (,problem-var (strategy-motivated-problems ,strategy)
                     :test #'eq :done ,done)
     ,@body))

;; Reconstructed from: $list70 (same arglist pattern),
;; $sym74$DO_SET, $sym65$STRATEGY_SET_ASIDE_PROBLEMS
;; register_macro_helper: STRATEGY-SET-ASIDE-PROBLEMS -> DO-STRATEGY-SET-ASIDE-PROBLEMS
(defmacro do-strategy-set-aside-problems ((problem-var strategy &key done) &body body)
  `(do-set (,problem-var (strategy-set-aside-problems ,strategy) :done ,done)
     ,@body))

;; Reconstructed from: $list76=(STRATEGY &BODY BODY),
;; $sym77$STRATEGY_VAR (gensym), $sym78$STATE_VAR (gensym),
;; $sym79$CLET, $sym80$STRATEGY_MEMOIZATION_STATE,
;; $sym81$_CURRENT_STRATEGY_WRT_MEMOIZATION_,
;; $sym82$WITH_MEMOIZATION_STATE
;; register_macro_helper: STRATEGY-MEMOIZATION-STATE, CURRENT-STRATEGY-WRT-MEMOIZATION
;;   -> WITH-STRATEGY-MEMOIZATION-STATE
(defmacro with-strategy-memoization-state (strategy &body body)
  (with-temp-vars (strategy-var state-var)
    `(let* ((,strategy-var ,strategy)
            (,state-var (strategy-memoization-state ,strategy-var))
            (*current-strategy-wrt-memoization* ,strategy-var))
       (with-memoization-state (,state-var)
         ,@body))))

;; Reconstructed from: $list94=((STRATEGY PROBLEM) &BODY BODY),
;; $sym95$STRATEGY_VAR (gensym), $sym96$PROBLEM_VAR (gensym),
;; $sym97$STRATEGY_NOTE_PROBLEM_ACTIVE, $sym98$STRATEGY_NOTE_PROBLEM_INACTIVE,
;; $sym99$POSSIBLY_REACTIVATE_PROBLEM
(defmacro with-strategically-active-problem ((strategy problem) &body body)
  (with-temp-vars (strategy-var problem-var)
    `(let ((,strategy-var ,strategy)
           (,problem-var ,problem))
       (strategy-note-problem-active ,strategy-var ,problem-var)
       (unwind-protect
            (progn ,@body)
         (strategy-note-problem-inactive ,strategy-var ,problem-var)
         (possibly-reactivate-problem ,strategy-var ,problem-var)))))


;;; More functions

(defun strategy-memoization-state (strategy)
  (strat-memoization-state strategy))

;; (defun current-strategy-wrt-memoization () ...) -- active declareFunction, no body

(defun strategic-context-inference (strategic-context)
  (if (strategy-p strategic-context)
      (strategy-inference strategic-context)
      nil))

(defun strategy-answer-link (strategy)
  "[Cyc] @return answer-link-p; The answer-link of the inference of STRATEGY."
  (inference-root-link (strategy-inference strategy)))

(defun strategy-answer-link-propagated? (strategy)
  "[Cyc] Return T iff the answer-link of the inference of STRATEGY has been propagated and has not been closed thereafter."
  (answer-link-propagated? (strategy-answer-link strategy)))

(defun strategy-should-propagate-answer-link? (strategy)
  "[Cyc] Return T iff the answer-link of the inference of STRATEGY ought to be propagated."
  (cond
    ((strategy-answer-link-propagated? strategy)
     nil)
    ((and (inference-deems-answer-link-should-be-closed?
           (strategy-inference strategy)
           (strategy-answer-link strategy))
          (inference-has-some-answer? (strategy-inference strategy)))
     nil)
    (t t)))

(defun strategy-root-problem (strategy)
  "[Cyc] @return problem-p; The root problem of the inference of STRATEGY."
  (inference-root-problem (strategy-inference strategy)))

(defun strategy-continuable? (strategy)
  (inference-continuable? (strategy-inference strategy)))

(defun problem-active-in-strategy? (problem strategy)
  (set-member? problem (strategy-active-problems strategy)))

(defun problem-motivated? (problem strategy)
  (set-contents-member? problem (strategy-motivated-problems strategy) #'eq))

(defun problem-set-aside-in-strategy? (problem strategy)
  (set-member? problem (strategy-set-aside-problems strategy)))

(defun strategy-has-some-set-aside-problems? (strategy)
  (not (set-empty? (strategy-set-aside-problems strategy))))

(defun strategy-all-valid-set-aside-problems (strategy)
  (delete-if-not #'valid-problem-p
                 (set-element-list (strategy-set-aside-problems strategy))))

(defun strategy-problem-store (strategy)
  (inference-problem-store (strategy-inference strategy)))

(defun strategy-result-uniqueness-criterion (strategy)
  "[Cyc] Locally specified result uniqueness criteria on the strategy (if any) override the one from the inference."
  (let ((local-criterion (strategy-local-result-uniqueness-criterion strategy)))
    (if local-criterion
        local-criterion
        (let ((inference (strategy-inference strategy)))
          (inference-result-uniqueness-criterion inference)))))

;; (defun strategy-unique-wrt-proofs? (strategy) ...) -- active declareFunction, no body

(defun strategy-unique-wrt-bindings? (strategy)
  (eq :bindings (strategy-result-uniqueness-criterion strategy)))

(defun strategy-wants-one-answer? (strategy)
  (declare (ignore strategy))
  nil)

;; (defun strategy-active-problem-count (strategy) ...) -- active declareFunction, no body
;; (defun strategy-motivated-problem-count (strategy) ...) -- active declareFunction, no body
;; (defun strategy-set-aside-problem-count (strategy) ...) -- active declareFunction, no body
;; (defun strategy-problem-proof-spec (strategy problem) ...) -- active declareFunction, no body

(defun set-strategy-property (strategy property value)
  (declare (type strategy strategy))
  (cond
    ((eq property :productivity-limit)
     (set-strategy-productivity-limit strategy value))
    ((eq property :removal-backtracking-productivity-limit)
     ;; Likely calls set-strategy-removal-backtracking-productivity-limit
     (missing-larkc 36460))
    ((eq property :proof-spec)
     ;; Likely calls set-strategy-proof-spec
     (missing-larkc 36459))
    (t
     (error "Unexpected strategy property ~s with value ~s" property value)))
  strategy)

(defun set-strategy-properties (strategy strategy-properties)
  (do* ((remainder strategy-properties (cddr remainder)))
       ((null remainder))
    (let ((property (first remainder))
          (value (cadr remainder)))
      (set-strategy-property strategy property value)))
  strategy)

(defun strategy-note-problem-active (strategy problem)
  (set-add problem (strategy-active-problems strategy))
  strategy)

(defun strategy-note-problem-inactive (strategy problem)
  (set-remove problem (strategy-active-problems strategy))
  strategy)

(defun strategy-note-problem-motivated (strategy problem)
  (let ((motivated-problems (strategy-motivated-problems strategy)))
    (setf (strat-motivated-problems strategy)
          (set-contents-add problem motivated-problems #'eq)))
  (controlling-strategy-callback strategy :substrategy-strategem-motivated problem)
  strategy)

;; (defun strategy-note-problem-unmotivated (strategy problem) ...) -- active declareFunction, no body

(defun strategy-note-problem-set-aside (strategy problem)
  (set-add problem (strategy-set-aside-problems strategy))
  strategy)

;; (defun strategy-clear-problem-set-aside (strategy problem) ...) -- active declareFunction, no body

(defun strategy-clear-set-asides (strategy)
  (clear-set (strategy-set-aside-problems strategy))
  strategy)

(defun note-strategy-should-reconsider-set-asides (strategy)
  (setf (strat-should-reconsider-set-asides? strategy) t)
  strategy)

(defun clear-strategy-should-reconsider-set-asides (strategy)
  (setf (strat-should-reconsider-set-asides? strategy) nil)
  strategy)

;; (defun strategy-note-problem-proof-spec (strategy problem proof-spec) ...) -- active declareFunction, no body

(defun strategy-dispatch (strategy method-type &optional
                          (arg1 :unprovided) (arg2 :unprovided)
                          (arg3 :unprovided) (arg4 :unprovided)
                          (arg5 :unprovided))
  (let ((arg1-provided? (not (eq arg1 :unprovided)))
        (arg2-provided? (not (eq arg2 :unprovided)))
        (arg3-provided? (not (eq arg3 :unprovided)))
        (arg4-provided? (not (eq arg4 :unprovided)))
        (arg5-provided? (not (eq arg5 :unprovided))))
    (when (eq arg1 :unprovided) (setf arg1 nil))
    (when (eq arg2 :unprovided) (setf arg2 nil))
    (when (eq arg3 :unprovided) (setf arg3 nil))
    (when (eq arg4 :unprovided) (setf arg4 nil))
    (when (eq arg5 :unprovided) (setf arg5 nil))
    (let ((handler-func (strategy-dispatch-handler strategy method-type)))
      (when (null handler-func)
        (setf handler-func (strategy-default-method-handler method-type)))
      (when (and (null handler-func)
                 (balancing-tactician-p strategy))
        (return-from strategy-dispatch
          (error "balancing tactician does not implement ~a" method-type)))
      (cond
        (arg5-provided?
         ;; Likely calls funcall with 7 args
         (missing-larkc 36472))
        (arg4-provided?
         ;; Likely calls funcall with 6 args
         (missing-larkc 36471))
        (arg3-provided?
         ;; Likely calls funcall with 5 args
         (missing-larkc 36470))
        (arg2-provided?
         ;; Likely calls funcall with 4 args
         (missing-larkc 36469))
        (arg1-provided?
         (strategy-dispatch-funcall-1 handler-func strategy arg1))
        (t
         (strategy-dispatch-funcall-0 handler-func strategy))))))

(defun strategy-dispatch-handler (strategy method-type)
  (let ((strategy-type (strategy-type strategy)))
    (strategy-type-dispatch-handler strategy-type method-type)))

(defun strategy-dispatch-funcall-0 (func strategy)
  (cond
    ((eq func 'balanced-strategy-default-select-best-strategem)
     (balanced-strategy-default-select-best-strategem strategy))
    ((eq func 'balanced-strategy-do-one-step)
     (balanced-strategy-do-one-step strategy))
    ((eq func 'balanced-strategy-done?)
     (balanced-strategy-done? strategy))
    (t
     (funcall func strategy))))

(defun strategy-dispatch-funcall-1 (func strategy arg1)
  (cond
    ((eq func 'balanced-strategy-possibly-activate-problem)
     (balanced-strategy-possibly-activate-problem strategy arg1))
    (t
     (funcall func strategy arg1))))

;; (defun strategy-dispatch-funcall-2 (func strategy arg1 arg2) ...) -- active declareFunction, no body
;; (defun strategy-dispatch-funcall-3 (func strategy arg1 arg2 arg3) ...) -- active declareFunction, no body
;; (defun strategy-dispatch-funcall-4 (func strategy arg1 arg2 arg3 arg4) ...) -- active declareFunction, no body
;; (defun strategy-dispatch-funcall-5 (func strategy arg1 arg2 arg3 arg4 arg5) ...) -- active declareFunction, no body
;; (defun strategy-dispatch-unexpected-strategy-type-error (strategy) ...) -- active declareFunction, no body

(defun controlling-strategy-callback (substrategy method-type &optional
                                      (arg1 :unprovided) (arg2 :unprovided)
                                      (arg3 :unprovided) (arg4 :unprovided))
  (let ((arg1-provided? (not (eq arg1 :unprovided)))
        (arg2-provided? (not (eq arg2 :unprovided)))
        (arg3-provided? (not (eq arg3 :unprovided)))
        (arg4-provided? (not (eq arg4 :unprovided))))
    (when (eq arg1 :unprovided) (setf arg1 nil))
    (when (eq arg2 :unprovided) (setf arg2 nil))
    (when (eq arg3 :unprovided) (setf arg3 nil))
    (when (eq arg4 :unprovided) (setf arg4 nil))
    (let ((controlling-strategy (controlling-strategy substrategy)))
      (when (not (eq substrategy controlling-strategy))
        (cond
          (arg4-provided?
           (strategy-dispatch controlling-strategy method-type
                              substrategy arg1 arg2 arg3 arg4))
          (arg3-provided?
           (strategy-dispatch controlling-strategy method-type
                              substrategy arg1 arg2 arg3))
          (arg2-provided?
           (strategy-dispatch controlling-strategy method-type
                              substrategy arg1 arg2))
          (arg1-provided?
           (strategy-dispatch controlling-strategy method-type
                              substrategy arg1))
          (t
           (strategy-dispatch controlling-strategy method-type
                              substrategy))))))
  nil)

;; (defun strategy-type-p (type) ...) -- active declareFunction, no body

(defun new-strategy-type (type plist)
  (deregister-strategy-type type)
  (do* ((remainder plist (cddr remainder)))
       ((null remainder))
    (let ((property (first remainder))
          (value (cadr remainder)))
      (set-strategy-type-property type property value)))
  type)

(defun deregister-strategy-type (type)
  (remhash type *strategy-type-store*))

;; (defun clear-strategy-type-store () ...) -- active declareFunction, no body

(defun strategy-type-property (type property)
  (dictionary-getf *strategy-type-store* type property))

(defun set-strategy-type-property (type property value)
  (dictionary-putf *strategy-type-store* type property value))


;;; Uninterestingness cache byte accessors

(defun uninterestingness-cache-thrown-away-wrt-removal-code (flags)
  (ldb *uninterestingness-cache-thrown-away-wrt-removal-byte* flags))

(defun uninterestingness-cache-thrown-away-wrt-transformation-code (flags)
  (ldb *uninterestingness-cache-thrown-away-wrt-transformation-byte* flags))

(defun uninterestingness-cache-thrown-away-wrt-new-root-code (flags)
  (ldb *uninterestingness-cache-thrown-away-wrt-new-root-byte* flags))

(defun uninterestingness-cache-set-aside-wrt-removal-code (flags)
  (ldb *uninterestingness-cache-set-aside-wrt-removal-byte* flags))

(defun uninterestingness-cache-set-aside-wrt-transformation-code (flags)
  (ldb *uninterestingness-cache-set-aside-wrt-transformation-byte* flags))

(defun uninterestingness-cache-set-aside-wrt-new-root-code (flags)
  (ldb *uninterestingness-cache-set-aside-wrt-new-root-byte* flags))

(defun uninterestingness-cache-thrown-away-code (flags)
  (ldb *uninterestingness-cache-thrown-away-byte* flags))

(defun uninterestingness-cache-set-aside-code (flags)
  (ldb *uninterestingness-cache-set-aside-byte* flags))

(defun set-uninterestingness-cache-thrown-away-wrt-removal-code (flags code)
  (dpb code *uninterestingness-cache-thrown-away-wrt-removal-byte* flags))

(defun set-uninterestingness-cache-thrown-away-wrt-transformation-code (flags code)
  (dpb code *uninterestingness-cache-thrown-away-wrt-transformation-byte* flags))

(defun set-uninterestingness-cache-thrown-away-wrt-new-root-code (flags code)
  (dpb code *uninterestingness-cache-thrown-away-wrt-new-root-byte* flags))

(defun set-uninterestingness-cache-set-aside-wrt-removal-code (flags code)
  (dpb code *uninterestingness-cache-set-aside-wrt-removal-byte* flags))

(defun set-uninterestingness-cache-set-aside-wrt-transformation-code (flags code)
  (dpb code *uninterestingness-cache-set-aside-wrt-transformation-byte* flags))

(defun set-uninterestingness-cache-set-aside-wrt-new-root-code (flags code)
  (dpb code *uninterestingness-cache-set-aside-wrt-new-root-byte* flags))

(defun set-uninterestingness-cache-thrown-away-code (flags code)
  (dpb code *uninterestingness-cache-thrown-away-byte* flags))

(defun set-uninterestingness-cache-set-aside-code (flags code)
  (dpb code *uninterestingness-cache-set-aside-byte* flags))

(defun decode-uninterestingness-cache-code (code)
  (cond
    ((eql code 0) :recompute)
    ((eql code 1) t)
    ((eql code 2) nil)
    (t (error "invalid uninterestingness cache code ~s" code))))

(defun encode-uninterestingness-cache-status (status)
  (cond
    ((eq :recompute status) 0)
    ((eq t status) 1)
    ((null status) 2)
    (t (error "invalid uninterestingness cache status ~s" status))))


;; problem-strategic-properties-print-function-trampoline is auto-generated by defstruct

;;; problem-strategic-properties defstruct — 4 slots

(defstruct (problem-strategic-properties
            (:conc-name "prob-strategic-properties-")
            (:predicate problem-strategic-properties-p))
  status
  tactic-strategic-property-index
  possible-tactic-count
  flags)

(defun new-problem-strategic-properties ()
  (let ((props (make-problem-strategic-properties)))
    (setf (prob-strategic-properties-status props) :new)
    (setf (prob-strategic-properties-tactic-strategic-property-index props) nil)
    (setf (prob-strategic-properties-possible-tactic-count props) 0)
    (setf (prob-strategic-properties-flags props) *default-uninterestingness-flags*)
    props))

(defun problem-strategic-properties-int (problem strategy)
  "[Cyc] @return problem-strategic-properties-p or NIL if uninitialized"
  (declare (type strategy strategy))
  (let ((problem-strategic-properties
          (gethash problem (strategy-problem-strategic-index strategy))))
    problem-strategic-properties))

(defun set-problem-strategic-properties (problem strategy properties)
  (declare (type strategy strategy)
           (type problem-strategic-properties properties))
  (let ((hash (strategy-problem-strategic-index strategy)))
    (setf (gethash problem hash) properties))
  problem)

;; (defun remove-problem-strategic-properties (problem strategy) ...) -- active declareFunction, no body

(defun problem-strategic-properties (problem strategy)
  "[Cyc] Initializes the problem-strategic-properties if they do not exist yet."
  (let ((problem-strategic-properties (problem-strategic-properties-int problem strategy)))
    (unless (problem-strategic-properties-p problem-strategic-properties)
      (setf problem-strategic-properties (new-problem-strategic-properties))
      (set-problem-strategic-properties problem strategy problem-strategic-properties))
    problem-strategic-properties))

(defun problem-strategic-properties-tactic-strategic-property-index (problem problem-strategic-properties)
  "[Cyc] Initializes the tactic-properties-vector if it does not exist yet."
  (let ((tactic-properties-vector
          (prob-strategic-properties-tactic-strategic-property-index problem-strategic-properties)))
    (unless (vectorp tactic-properties-vector)
      (setf tactic-properties-vector
            (make-array (problem-tactic-count problem)))
      (setf (prob-strategic-properties-tactic-strategic-property-index problem-strategic-properties)
            tactic-properties-vector))
    (when (< (length tactic-properties-vector)
             (problem-tactic-count problem))
      (setf tactic-properties-vector
            (extend-vector-to tactic-properties-vector
                              (problem-tactic-count problem)))
      (setf (prob-strategic-properties-tactic-strategic-property-index problem-strategic-properties)
            tactic-properties-vector))
    tactic-properties-vector))

(defun problem-raw-strategic-status (problem strategy)
  (let* ((problem-strategic-properties (problem-strategic-properties problem strategy))
         (strategic-status (prob-strategic-properties-status problem-strategic-properties)))
    (if (and (eq :new strategic-status)
             (not (eq :new (problem-status problem))))
        :unexamined
        strategic-status)))

(defun problem-strategic-status (problem strategy)
  (let* ((status (problem-raw-strategic-status problem strategy))
         (weak-tactical-status (tactical-status-from-problem-status status)))
    (if (tactically-finished-problem-p problem)
        :finished
        weak-tactical-status)))

(defun problem-strategic-provability-status (problem strategy)
  (let* ((status (problem-raw-strategic-status problem strategy))
         (weak-provability-status (provability-status-from-problem-status status)))
    (cond
      ((and (eq :neutral weak-provability-status)
            (tactically-good-problem-p problem))
       :good)
      ((and (eq :neutral weak-provability-status)
            (tactically-no-good-problem-p problem))
       :no-good)
      (t weak-provability-status))))

;; (defun problem-tactical-or-strategic-status (problem strategic-context) ...) -- active declareFunction, no body
;; (defun problem-provability-status (problem strategic-context) ...) -- active declareFunction, no body

(defun set-problem-raw-strategic-status (problem strategy status)
  (let ((problem-strategic-properties (problem-strategic-properties problem strategy)))
    (setf (prob-strategic-properties-status problem-strategic-properties) status))
  problem)

(defun strategically-unexamined-problem-p (problem strategy)
  (eq :unexamined (problem-strategic-status problem strategy)))

(defun strategically-examined-problem-p (problem strategy)
  (eq :examined (problem-strategic-status problem strategy)))

(defun strategically-possible-problem-p (problem strategy)
  (eq :possible (problem-strategic-status problem strategy)))

(defun strategically-pending-problem-p (problem strategy)
  (eq :pending (problem-strategic-status problem strategy)))

(defun strategically-finished-problem-p (problem strategy)
  (eq :finished (problem-strategic-status problem strategy)))

(defun strategically-no-good-problem-p (problem strategy)
  (eq :no-good (problem-strategic-provability-status problem strategy)))

(defun strategically-neutral-problem-p (problem strategy)
  (eq :neutral (problem-strategic-provability-status problem strategy)))

(defun strategically-good-problem-p (problem strategy)
  (eq :good (problem-strategic-provability-status problem strategy)))

;; (defun strategically-potentially-possible-problem-p (problem strategy) ...) -- active declareFunction, no body
;; (defun strategically-not-potentially-possible-problem-p (problem strategy) ...) -- active declareFunction, no body

(defun strategically-totally-no-good-problem-p (problem strategy)
  (strategically-no-good-problem-p problem (controlling-strategy strategy)))

(defun problem-strategic-flags (problem strategy)
  (let ((problem-strategic-properties (problem-strategic-properties problem strategy)))
    (prob-strategic-properties-flags problem-strategic-properties)))

(defun set-problem-strategic-flags (problem strategy flags)
  (declare (type fixnum flags))
  (let ((problem-strategic-properties (problem-strategic-properties problem strategy)))
    (setf (prob-strategic-properties-flags problem-strategic-properties) flags))
  flags)

(defun problem-thrown-away-cache-status (problem strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-thrown-away-code
    (problem-strategic-flags problem strategy))))

(defun problem-thrown-away-cache-removal-status (problem strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-thrown-away-wrt-removal-code
    (problem-strategic-flags problem strategy))))

(defun problem-thrown-away-cache-transformation-status (problem strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-thrown-away-wrt-transformation-code
    (problem-strategic-flags problem strategy))))

(defun problem-thrown-away-cache-new-root-status (problem strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-thrown-away-wrt-new-root-code
    (problem-strategic-flags problem strategy))))

(defun problem-set-aside-cache-removal-status (problem strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-set-aside-wrt-removal-code
    (problem-strategic-flags problem strategy))))

(defun problem-set-aside-cache-status (problem strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-set-aside-code
    (problem-strategic-flags problem strategy))))

(defun problem-set-aside-cache-transformation-status (problem strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-set-aside-wrt-transformation-code
    (problem-strategic-flags problem strategy))))

;; (defun problem-set-aside-cache-new-root-status (problem strategy) ...) -- active declareFunction, no body

(defun set-problem-thrown-away (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-code
                     flags (encode-uninterestingness-cache-status t))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-not-thrown-away (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-problem-strategic-flags problem strategy new-flags)))

;; (defun set-problem-recompute-thrown-away (problem strategy) ...) -- active declareFunction, no body
;; (defun set-problem-thrown-away-wrt-removal (problem strategy) ...) -- active declareFunction, no body

(defun set-problem-not-thrown-away-wrt-removal (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-removal-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-recompute-thrown-away-wrt-removal (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-removal-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-thrown-away-wrt-transformation (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status t))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-not-thrown-away-wrt-transformation (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-recompute-thrown-away-wrt-transformation (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-thrown-away-wrt-new-root (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-new-root-code
                     flags (encode-uninterestingness-cache-status t))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-not-thrown-away-wrt-new-root (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-new-root-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-recompute-thrown-away-wrt-new-root (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-new-root-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-set-aside (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-set-aside-code
                     flags (encode-uninterestingness-cache-status t))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-not-set-aside (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-set-aside-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-problem-strategic-flags problem strategy new-flags)))

;; (defun set-problem-recompute-set-aside (problem strategy) ...) -- active declareFunction, no body
;; (defun set-problem-set-aside-wrt-removal (problem strategy) ...) -- active declareFunction, no body

(defun set-problem-not-set-aside-wrt-removal (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-removal-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-recompute-set-aside-wrt-removal (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-removal-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-problem-strategic-flags problem strategy new-flags)))

;; (defun set-problem-set-aside-wrt-transformation (problem strategy) ...) -- active declareFunction, no body

(defun set-problem-not-set-aside-wrt-transformation (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-problem-strategic-flags problem strategy new-flags)))

(defun set-problem-recompute-set-aside-wrt-transformation (problem strategy)
  (let* ((flags (problem-strategic-flags problem strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-problem-strategic-flags problem strategy new-flags)))

;; (defun set-problem-set-aside-wrt-new-root (problem strategy) ...) -- active declareFunction, no body
;; (defun set-problem-not-set-aside-wrt-new-root (problem strategy) ...) -- active declareFunction, no body

(defun set-problem-recompute-set-aside-wrt-new-root (problem strategy)
  (declare (ignore problem strategy))
  nil)

(defun set-problem-thrown-away-wrt (problem strategy motivation)
  (cond
    ((eq motivation :removal)
     ;; Likely calls set-problem-thrown-away-wrt-removal
     (missing-larkc 36458))
    ((eq motivation :transformation)
     (set-problem-thrown-away-wrt-transformation problem strategy))
    ((eq motivation :new-root)
     (set-problem-thrown-away-wrt-new-root problem strategy))
    (t
     (error "unexpected motivation ~s" motivation))))

(defun set-problem-not-thrown-away-wrt (problem strategy motivation)
  (cond
    ((eq motivation :removal)
     (set-problem-not-thrown-away-wrt-removal problem strategy))
    ((eq motivation :transformation)
     (set-problem-not-thrown-away-wrt-transformation problem strategy))
    ((eq motivation :new-root)
     (set-problem-not-thrown-away-wrt-new-root problem strategy))
    (t
     (error "unexpected motivation ~s" motivation))))

;; (defun set-problem-recompute-thrown-away-wrt (problem strategy motivation) ...) -- active declareFunction, no body

;; (defun set-problem-set-aside-wrt (problem strategy motivation) ...) -- active declareFunction, no body

(defun set-problem-not-set-aside-wrt (problem strategy motivation)
  (cond
    ((eq motivation :removal)
     (set-problem-not-set-aside-wrt-removal problem strategy))
    ((eq motivation :transformation)
     (set-problem-not-set-aside-wrt-transformation problem strategy))
    ((eq motivation :new-root)
     ;; Likely calls set-problem-not-set-aside-wrt-new-root
     (missing-larkc 36449))
    (t
     (error "unexpected motivation ~s" motivation))))

;; (defun set-problem-recompute-set-aside-wrt (problem strategy motivation) ...) -- active declareFunction, no body

(defun problem-thrown-away-cache-status-wrt-motivation (problem strategy motivation)
  (unless *uninterestingness-cache-lookup-enabled?*
    (return-from problem-thrown-away-cache-status-wrt-motivation :recompute))
  (cond
    ((eq motivation :removal)
     (problem-thrown-away-cache-removal-status problem strategy))
    ((eq motivation :transformation)
     (problem-thrown-away-cache-transformation-status problem strategy))
    ((eq motivation :new-root)
     (problem-thrown-away-cache-new-root-status problem strategy))
    (t
     (error "unexpected motivation ~s" motivation))))

(defun set-problem-recompute-thrown-away-wrt-all-motivations (problem strategy)
  (if (balancing-tactician-substrategy-p strategy)
      ;; Likely calls a substrategy-specific version
      (missing-larkc 36452)
      (progn
        (set-problem-recompute-thrown-away-wrt-removal problem strategy)
        (set-problem-recompute-thrown-away-wrt-transformation problem strategy)
        (set-problem-recompute-thrown-away-wrt-new-root problem strategy)))
  nil)

(defun set-problem-recompute-thrown-away-wrt-all-relevant-strategies-and-all-motivations (problem)
  (let* ((prob problem)
         (store (problem-store prob))
         (idx (problem-store-inference-id-index store)))
    (do-id-index (_id inference idx)
      (when (problem-relevant-to-inference? prob inference)
        (do-set (strategy (inference-strategy-set inference))
          (set-problem-recompute-thrown-away-wrt-all-motivations problem strategy)))))
  nil)

(defun problem-set-aside-cache-status-wrt-motivation (problem strategy motivation)
  (unless *uninterestingness-cache-lookup-enabled?*
    (return-from problem-set-aside-cache-status-wrt-motivation :recompute))
  (cond
    ((eq motivation :removal)
     (problem-set-aside-cache-removal-status problem strategy))
    ((eq motivation :transformation)
     (problem-set-aside-cache-transformation-status problem strategy))
    ((eq motivation :new-root)
     nil)
    (t
     (error "unexpected motivation ~s" motivation))))

(defun set-problem-recompute-set-aside-wrt-all-motivations (problem strategy)
  (if (balancing-tactician-substrategy-p strategy)
      ;; Likely calls a substrategy-specific version
      (missing-larkc 36450)
      (progn
        (set-problem-recompute-set-aside-wrt-removal problem strategy)
        (set-problem-recompute-set-aside-wrt-transformation problem strategy)
        (set-problem-recompute-set-aside-wrt-new-root problem strategy)))
  nil)


;; tactic-strategic-properties-print-function-trampoline is auto-generated by defstruct

;;; tactic-strategic-properties defstruct — 4 slots

(defstruct (tactic-strategic-properties
            (:conc-name "tact-strategic-properties-")
            (:predicate tactic-strategic-properties-p))
  preference-level
  preference-level-justification
  productivity
  flags)

(defun new-tactic-strategic-properties ()
  (let ((props (make-tactic-strategic-properties)))
    (setf (tact-strategic-properties-preference-level props) :disallowed)
    (setf (tact-strategic-properties-preference-level-justification props) "")
    (setf (tact-strategic-properties-productivity props) (positive-infinity))
    (setf (tact-strategic-properties-flags props) *default-uninterestingness-flags*)
    props))

(defun tactic-strategic-properties-int (tactic strategy)
  "[Cyc] @return tactic-strategic-properties-p or NIL if uninitialized"
  (declare (type strategy strategy))
  (let* ((problem (tactic-problem tactic))
         (problem-strategic-properties (problem-strategic-properties problem strategy)))
    (when (problem-strategic-properties-p problem-strategic-properties)
      (let ((tactic-properties-vector
              (problem-strategic-properties-tactic-strategic-property-index
               problem problem-strategic-properties)))
        (when (vectorp tactic-properties-vector)
          (let ((tactic-suid (tactic-suid tactic)))
            (aref tactic-properties-vector tactic-suid)))))))

(defun set-tactic-strategic-properties (tactic strategy properties)
  (declare (type strategy strategy)
           (type tactic-strategic-properties properties))
  (let* ((problem (tactic-problem tactic))
         (problem-strategic-properties (problem-strategic-properties problem strategy))
         (tactic-properties-vector
           (problem-strategic-properties-tactic-strategic-property-index
            problem problem-strategic-properties))
         (tactic-suid (tactic-suid tactic)))
    (setf (aref tactic-properties-vector tactic-suid) properties))
  tactic)

(defun tactic-strategic-properties (tactic strategy)
  "[Cyc] Initializes the tactic-strategic-properties if they do not exist yet."
  (let ((tactic-strategic-properties (tactic-strategic-properties-int tactic strategy)))
    (unless (tactic-strategic-properties-p tactic-strategic-properties)
      (setf tactic-strategic-properties (new-tactic-strategic-properties))
      (set-tactic-strategic-properties tactic strategy tactic-strategic-properties))
    tactic-strategic-properties))

(defun tactic-strategic-completeness (tactic strategic-context)
  (cond
    ((eq :tactical strategic-context)
     (tactic-completeness tactic))
    ((content-tactic-p tactic)
     (tactic-completeness tactic))
    (t
     (error "structural tactic ~s cannot have a completeness" tactic))))

(defun tactic-strategic-preference-level (tactic strategic-context)
  (cond
    ((eq :tactical strategic-context)
     (tactic-preference-level tactic))
    ((generalized-structural-tactic-p tactic)
     (let ((tactic-strategic-properties (tactic-strategic-properties tactic strategic-context)))
       (tact-strategic-properties-preference-level tactic-strategic-properties)))
    (t
     (error "content tactic ~s cannot have a preference level" tactic))))

(defun tactic-strategic-preference-level-justification (tactic strategic-context)
  (cond
    ((eq :tactical strategic-context)
     (tactic-preference-level-justification tactic))
    ((generalized-structural-tactic-p tactic)
     (let ((tactic-strategic-properties (tactic-strategic-properties tactic strategic-context)))
       ;; Likely calls tact-strategic-properties-preference-level-justification
       (missing-larkc 36476)))
    (t
     (error "content tactic ~s cannot have a preference level justification" tactic))))

;; (defun tactic-strategic-dwimmed-completeness (tactic strategic-context) ...) -- active declareFunction, no body

(defun conjunctive-tactic-strategic-preference-level (tactic strategic-context)
  (if (conjunctive-removal-tactic-p tactic)
      (completeness-to-preference-level
       (tactic-strategic-completeness tactic strategic-context))
      (tactic-strategic-preference-level tactic strategic-context)))

(defun conjunctive-tactic-strategic-preference-level-justification (tactic strategic-context)
  (if (conjunctive-removal-tactic-p tactic)
      (str (tactic-strategic-completeness tactic strategic-context))
      (tactic-strategic-preference-level-justification tactic strategic-context)))

(defun tactic-strategic-productivity (tactic strategic-context)
  (cond
    ((eq :tactical strategic-context)
     (tactic-productivity tactic))
    ((content-tactic-p tactic)
     (tactic-productivity tactic))
    (t
     (let ((tactic-strategic-properties (tactic-strategic-properties tactic strategic-context)))
       (tact-strategic-properties-productivity tactic-strategic-properties)))))

(defun tactic-strategically-preferred? (tactic strategy)
  (eq :preferred (tactic-strategic-preference-level tactic strategy)))

(defun set-tactic-strategic-preference-level (tactic strategy preference-level justification)
  (let ((tactic-strategic-properties (tactic-strategic-properties tactic strategy)))
    (setf (tact-strategic-properties-preference-level tactic-strategic-properties)
          preference-level)
    (setf (tact-strategic-properties-preference-level-justification tactic-strategic-properties)
          justification))
  tactic)

(defun set-tactic-strategic-productivity (tactic strategy productivity)
  (let ((tactic-strategic-properties (tactic-strategic-properties tactic strategy)))
    (setf (tact-strategic-properties-productivity tactic-strategic-properties)
          productivity))
  tactic)

(defun tactic-strategic-flags (tactic strategy)
  (let ((tactic-strategic-properties (tactic-strategic-properties tactic strategy)))
    (tact-strategic-properties-flags tactic-strategic-properties)))

(defun set-tactic-strategic-flags (tactic strategy flags)
  (declare (type fixnum flags))
  (let ((tactic-strategic-properties (tactic-strategic-properties tactic strategy)))
    (setf (tact-strategic-properties-flags tactic-strategic-properties) flags))
  flags)

(defun tactic-thrown-away-cache-status (tactic strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-thrown-away-code
    (tactic-strategic-flags tactic strategy))))

(defun tactic-thrown-away-cache-removal-status (tactic strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-thrown-away-wrt-removal-code
    (tactic-strategic-flags tactic strategy))))

(defun tactic-thrown-away-cache-transformation-status (tactic strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-thrown-away-wrt-transformation-code
    (tactic-strategic-flags tactic strategy))))

(defun tactic-thrown-away-cache-new-root-status (tactic strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-thrown-away-wrt-new-root-code
    (tactic-strategic-flags tactic strategy))))

(defun tactic-set-aside-cache-status (tactic strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-set-aside-code
    (tactic-strategic-flags tactic strategy))))

(defun tactic-set-aside-cache-removal-status (tactic strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-set-aside-wrt-removal-code
    (tactic-strategic-flags tactic strategy))))

(defun tactic-set-aside-cache-transformation-status (tactic strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-set-aside-wrt-transformation-code
    (tactic-strategic-flags tactic strategy))))

(defun tactic-set-aside-cache-new-root-status (tactic strategy)
  (decode-uninterestingness-cache-code
   (uninterestingness-cache-set-aside-wrt-new-root-code
    (tactic-strategic-flags tactic strategy))))

(defun set-tactic-thrown-away (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-code
                     flags (encode-uninterestingness-cache-status t))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-not-thrown-away (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

;; (defun set-tactic-recompute-thrown-away (tactic strategy) ...) -- active declareFunction, no body

(defun set-tactic-thrown-away-wrt-removal (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-removal-code
                     flags (encode-uninterestingness-cache-status t))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-not-thrown-away-wrt-removal (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-removal-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-recompute-thrown-away-wrt-removal (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-removal-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-thrown-away-wrt-transformation (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status t))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-not-thrown-away-wrt-transformation (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-recompute-thrown-away-wrt-transformation (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-thrown-away-wrt-new-root (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-new-root-code
                     flags (encode-uninterestingness-cache-status t))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-not-thrown-away-wrt-new-root (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-new-root-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-recompute-thrown-away-wrt-new-root (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-thrown-away-wrt-new-root-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

;; (defun set-tactic-set-aside (tactic strategy) ...) -- active declareFunction, no body

(defun set-tactic-not-set-aside (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-set-aside-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

;; (defun set-tactic-recompute-set-aside (tactic strategy) ...) -- active declareFunction, no body
;; (defun set-tactic-set-aside-wrt-removal (tactic strategy) ...) -- active declareFunction, no body

(defun set-tactic-not-set-aside-wrt-removal (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-removal-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-recompute-set-aside-wrt-removal (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-removal-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-set-aside-wrt-transformation (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status t))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-not-set-aside-wrt-transformation (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-recompute-set-aside-wrt-transformation (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-transformation-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

;; (defun set-tactic-set-aside-wrt-new-root (tactic strategy) ...) -- active declareFunction, no body

(defun set-tactic-not-set-aside-wrt-new-root (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-new-root-code
                     flags (encode-uninterestingness-cache-status nil))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-recompute-set-aside-wrt-new-root (tactic strategy)
  (let* ((flags (tactic-strategic-flags tactic strategy))
         (new-flags (set-uninterestingness-cache-set-aside-wrt-new-root-code
                     flags (encode-uninterestingness-cache-status :recompute))))
    (set-tactic-strategic-flags tactic strategy new-flags)))

(defun set-tactic-thrown-away-wrt (tactic strategy motivation)
  (cond
    ((eq motivation :removal)
     (set-tactic-thrown-away-wrt-removal tactic strategy))
    ((eq motivation :transformation)
     (set-tactic-thrown-away-wrt-transformation tactic strategy))
    ((eq motivation :new-root)
     (set-tactic-thrown-away-wrt-new-root tactic strategy))
    (t
     (error "unexpected motivation ~s" motivation))))

(defun set-tactic-not-thrown-away-wrt (tactic strategy motivation)
  (cond
    ((eq motivation :removal)
     (set-tactic-not-thrown-away-wrt-removal tactic strategy))
    ((eq motivation :transformation)
     (set-tactic-not-thrown-away-wrt-transformation tactic strategy))
    ((eq motivation :new-root)
     (set-tactic-not-thrown-away-wrt-new-root tactic strategy))
    (t
     (error "unexpected motivation ~s" motivation))))

;; (defun set-tactic-recompute-thrown-away-wrt (tactic strategy motivation) ...) -- active declareFunction, no body

(defun set-tactic-set-aside-wrt (tactic strategy motivation)
  (cond
    ((eq motivation :removal)
     ;; Likely calls set-tactic-set-aside-wrt-removal
     (missing-larkc 36467))
    ((eq motivation :transformation)
     (set-tactic-set-aside-wrt-transformation tactic strategy))
    ((eq motivation :new-root)
     ;; Likely calls set-tactic-set-aside-wrt-new-root
     (missing-larkc 36466))
    (t
     (error "unexpected motivation ~s" motivation))))

(defun set-tactic-not-set-aside-wrt (tactic strategy motivation)
  (cond
    ((eq motivation :removal)
     (set-tactic-not-set-aside-wrt-removal tactic strategy))
    ((eq motivation :transformation)
     (set-tactic-not-set-aside-wrt-transformation tactic strategy))
    ((eq motivation :new-root)
     (set-tactic-not-set-aside-wrt-new-root tactic strategy))
    (t
     (error "unexpected motivation ~s" motivation))))

;; (defun set-tactic-recompute-set-aside-wrt (tactic strategy motivation) ...) -- active declareFunction, no body

(defun tactic-thrown-away-cache-status-wrt-motivation (tactic strategy motivation)
  (unless *uninterestingness-cache-lookup-enabled?*
    (return-from tactic-thrown-away-cache-status-wrt-motivation :recompute))
  (cond
    ((eq motivation :removal)
     (tactic-thrown-away-cache-removal-status tactic strategy))
    ((eq motivation :transformation)
     (tactic-thrown-away-cache-transformation-status tactic strategy))
    ((eq motivation :new-root)
     (tactic-thrown-away-cache-new-root-status tactic strategy))
    (t
     (error "unexpected motivation ~s" motivation))))

(defun set-tactic-recompute-thrown-away-wrt-all-motivations (tactic strategy)
  (if (balancing-tactician-substrategy-p strategy)
      ;; Likely calls a substrategy-specific version
      (missing-larkc 36462)
      (progn
        (set-tactic-recompute-thrown-away-wrt-removal tactic strategy)
        (set-tactic-recompute-thrown-away-wrt-transformation tactic strategy)
        (set-tactic-recompute-thrown-away-wrt-new-root tactic strategy)))
  nil)

(defun set-problem-tactics-recompute-thrown-away-wrt-all-motivations (problem strategy)
  (dolist (tactic (problem-tactics problem))
    (set-tactic-recompute-thrown-away-wrt-all-motivations tactic strategy))
  nil)

(defun set-problem-tactics-recompute-thrown-away-wrt-all-relevant-strategies-and-all-motivations (problem)
  (let* ((prob problem)
         (store (problem-store prob))
         (idx (problem-store-inference-id-index store)))
    (do-id-index (_id inference idx)
      (when (problem-relevant-to-inference? prob inference)
        (do-set (strategy (inference-strategy-set inference))
          (set-problem-tactics-recompute-thrown-away-wrt-all-motivations
           problem strategy)))))
  nil)

(defun tactic-set-aside-cache-status-wrt-motivation (tactic strategy motivation)
  (unless *uninterestingness-cache-lookup-enabled?*
    (return-from tactic-set-aside-cache-status-wrt-motivation :recompute))
  (cond
    ((eq motivation :removal)
     (tactic-set-aside-cache-removal-status tactic strategy))
    ((eq motivation :transformation)
     (tactic-set-aside-cache-transformation-status tactic strategy))
    ((eq motivation :new-root)
     (tactic-set-aside-cache-new-root-status tactic strategy))
    (t
     (error "unexpected motivation ~s" motivation))))

(defun set-tactic-recompute-set-aside-wrt-all-motivations (tactic strategy)
  (if (balancing-tactician-substrategy-p strategy)
      ;; Likely calls a substrategy-specific version
      (missing-larkc 36461)
      (progn
        (set-tactic-recompute-set-aside-wrt-removal tactic strategy)
        (set-tactic-recompute-set-aside-wrt-transformation tactic strategy)
        (set-tactic-recompute-set-aside-wrt-new-root tactic strategy)))
  nil)

(defun set-tactic-recompute-set-aside-wrt-all-relevant-strategies-and-all-motivations (tactic)
  (let* ((prob (tactic-problem tactic))
         (store (problem-store prob))
         (idx (problem-store-inference-id-index store)))
    (do-id-index (_id inference idx)
      (when (problem-relevant-to-inference? prob inference)
        (do-set (strategy (inference-strategy-set inference))
          (set-tactic-recompute-set-aside-wrt-all-motivations tactic strategy)))))
  nil)

;; (defun set-problem-tactics-recompute-set-aside-wrt-all-motivations (problem strategy) ...) -- active declareFunction, no body

;; (defun set-problem-tactics-recompute-set-aside-wrt-all-motivations (problem strategy) ...) -- active declareFunction, no body
;; (defun set-problem-tactics-recompute-set-aside-wrt-all-relevant-strategies-and-all-motivations (problem) ...) -- active declareFunction, no body
;; (defun set-problem-recompute-set-aside-wrt-all-relevant-strategies-and-all-motivations (problem) ...) -- active declareFunction, no body

;; (defun problem-strategically-possible-tactic-count (problem strategy) ...) -- active declareFunction, no body

(defun problem-note-tactic-strategically-possible (problem tactic strategy)
  (declare (type strategy strategy))
  (let ((problem-strategic-properties (problem-strategic-properties problem strategy)))
    (setf (prob-strategic-properties-possible-tactic-count problem-strategic-properties)
          (1+ (prob-strategic-properties-possible-tactic-count problem-strategic-properties))))
  problem)

(defun problem-note-tactic-not-strategically-possible (problem tactic strategy)
  (declare (type strategy strategy))
  (let ((problem-strategic-properties (problem-strategic-properties problem strategy)))
    (setf (prob-strategic-properties-possible-tactic-count problem-strategic-properties)
          (1- (prob-strategic-properties-possible-tactic-count problem-strategic-properties))))
  problem)

;; (defun problem-note-all-tactics-not-strategically-possible (problem strategy) ...) -- active declareFunction, no body


;;; Setup phase (toplevel forms)

(toplevel
  (register-macro-helper 'strategy-active-problems
                         'do-strategy-active-problems)
  (register-macro-helper 'strategy-motivated-problems
                         'do-strategy-motivated-problems)
  (register-macro-helper 'strategy-set-aside-problems
                         'do-strategy-set-aside-problems)
  (register-macro-helper 'strategy-memoization-state
                         'with-strategy-memoization-state)
  (register-macro-helper 'current-strategy-wrt-memoization
                         'with-strategy-memoization-state)
  (declare-defglobal '*strategy-type-store*))
