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


;;; Variables (from init section)

(deflexical *fi-dispatch-table*
  (list (list :get-warning 'fi-get-warning 'fi-get-warning-int nil)
        (list :get-error 'fi-get-error 'fi-get-error-int nil)
        (list :find 'fi-find 'fi-find-int nil)
        (list :complete 'fi-complete 'fi-complete-int nil)
        (list :create 'fi-create 'fi-create-int t)
        (list :find-or-create 'fi-find-or-create 'fi-find-or-create-int t)
        (list :create-skolem 'fi-create-skolem 'fi-create-skolem-int t)
        (list :merge 'fi-merge 'fi-merge-int t)
        (list :kill 'fi-kill 'fi-kill-int t)
        (list :rename 'fi-rename 'fi-rename-int t)
        (list :lookup 'fi-lookup 'fi-lookup-int nil)
        (list :assert 'fi-assert 'fi-assert-int t)
        (list :reassert 'fi-reassert 'fi-reassert-int t)
        (list :unassert 'fi-unassert 'fi-unassert-int t)
        (list :edit 'fi-edit 'fi-edit-int t)
        (list :rename-variables 'fi-rename-variables 'fi-rename-variables-int t)
        (list :justify 'fi-justify 'fi-justify-int nil)
        (list :add-argument 'fi-add-argument 'fi-add-argument-int t)
        (list :remove-argument 'fi-remove-argument 'fi-remove-argument-int t)
        (list :blast 'fi-blast 'fi-blast-int t)
        (list :ask 'fi-ask 'fi-ask-int t)
        (list :continue-last-ask 'fi-continue-last-ask 'fi-continue-last-ask-int t)
        (list :ask-status 'fi-ask-status 'fi-ask-status-int nil)
        (list :tms-reconsider-formula 'fi-tms-reconsider-formula 'fi-tms-reconsider-formula-int t)
        (list :tms-reconsider-mt 'fi-tms-reconsider-mt 'fi-tms-reconsider-mt-int t)
        (list :tms-reconsider-gafs 'fi-tms-reconsider-gafs 'fi-tms-reconsider-gafs-int t)
        (list :tms-reconsider-term 'fi-tms-reconsider-term 'fi-tms-reconsider-term-int t)
        (list :hypothesize 'fi-hypothesize 'fi-hypothesize-int t)
        (list :prove 'fi-prove 'fi-prove-int t)
        (list :timestamp-constant 'fi-timestamp-constant 'fi-timestamp-constant-int t)
        (list :timestamp-assertion 'fi-timestamp-assertion 'fi-timestamp-assertion-int t)
        (list :remove-timestamp 'fi-remove-timestamp 'fi-remove-timestamp-int t)
        (list :get-parameter 'fi-get-parameter 'fi-get-parameter-int nil)
        (list :set-parameter 'fi-set-parameter 'fi-set-parameter-int t)
        (list :eval 'fi-eval 'fi-eval-int t)
        (list :local-eval 'fi-local-eval 'fi-local-eval-int nil)))

(defparameter *fi-warning* nil)
(defparameter *fi-error* nil)
(defparameter *fi-last-constant* nil)
(defparameter *fi-last-assertions-asserted* nil)
(defparameter *within-fi-operation?* nil)
(defparameter *current-fi-op* nil)
(defparameter *merge-fort-assertion-map* nil)
(defparameter *assume-assert-sentence-is-wf?* nil
  "[Cyc] To be used only by cyc-assert-wff")
(defparameter *generate-precise-fi-wff-errors?* t
  "[Cyc] Whether to generate precise WFF errors when FI operations fail.
These precise explanations will explain why the operation failed.
If NIL, the error will simply state that the operation was ill-formed,
but will not say why.  Can be bound to NIL by callers that do not
care about the reason.")
(defparameter *the-date* nil
  "[Cyc] When non-nil, this variable contains the date to be used for asserting formulas to the system.
NIL means that the current date is to be used.")
(defparameter *the-second* nil
  "[Cyc] When non-nil, this variable contains the second to be used for asserting formulas to the system.
NIL means that the current second is to be used.")
(deflexical *cached-fi-canonicalize-gaf-caching-state* nil)
(defparameter *assertion-fi-formula-mt-scope* nil)


;;; Functions (ordered per declare section)

(defun reset-fi-error-state ()
  (reset-fi-error)
  (reset-fi-warning)
  nil)

;; (defmacro with-clean-fi-error-state (&body body) ...) -- no body, commented declareMacro
;; Reconstructed from Internal Constants evidence:
;; $sym1$CLET, $list2 = ((*fi-error* nil) (*fi-warning* nil))
;; Expansion: (let ((*fi-error* nil) (*fi-warning* nil)) . body)
(defmacro with-clean-fi-error-state (&body body)
  `(let ((*fi-error* nil)
          (*fi-warning* nil))
     ,@body))

(defun reset-fi-warning ()
  (setf *fi-warning* nil)
  nil)

(defun signal-fi-warning (fi-warning)
  (setf *fi-warning* fi-warning)
  nil)

;; (defun fi-warning-signaled? () ...) -- no body, commented declareFunction
;; (defun fi-get-warning-int () ...) -- no body, commented declareFunction

(defun reset-fi-error ()
  (setf *fi-error* nil)
  nil)

(defun signal-fi-error (fi-error)
  (setf *fi-error* fi-error)
  nil)

(defun fi-error-signaled? ()
  (and *fi-error* t))

;; commented declareFunction, but body present in Java -- ported for reference
(defun fi-get-error-int ()
  *fi-error*)

;; (defun fi-error-string (error) ...) -- no body, commented declareFunction
;; (defun fi-get-error-string-int () ...) -- no body, commented declareFunction

;; (defmacro within-fi-operation (&body body) ...) -- no body, commented declareMacro
;; Reconstructed from Internal Constants evidence:
;; $list9 = ((*within-fi-operation?* t))
;; Expansion: (let ((*within-fi-operation?* t)) . body)
(defmacro within-fi-operation (&body body)
  `(let ((*within-fi-operation?* t))
     ,@body))

;; (defun already-within-fi-operation? () ...) -- no body, commented declareFunction
;; (defun fi (op &optional arg1 arg2 arg3 arg4 arg5 arg6 arg7 arg8) ...) -- no body, commented declareFunction
;; (defun fi-1 (op int-fun modifies-kb?) ...) -- no body, commented declareFunction
;; (defun possibly-add-to-transcript-queues (op) ...) -- no body, commented declareFunction
;; (defun safe-fi (op &optional arg1 arg2 arg3 arg4 arg5 arg6 arg7 arg8) ...) -- no body, commented declareFunction
;; (defun fi-get-warning () ...) -- no body, commented declareFunction
;; (defun fi-get-error () ...) -- no body, commented declareFunction
;; (defun fi-find (name) ...) -- no body, commented declareFunction

(defun fi-find-int (name)
  (reset-fi-error-state)
  (unless (stringp name)
    (signal-fi-error (list :arg-error "Expected a string, got ~S" name))
    (return-from fi-find-int nil))
  (unless (valid-constant-name-p name)
    (signal-fi-error (list :invalid-name "~S is not a valid name for a constant" name))
    (return-from fi-find-int nil))
  (let ((ans nil))
    (let ((*within-fi-operation?* t))
      (let ((constant (find-constant name)))
        (setf ans (if (valid-constant? constant) constant nil))))
    ans))

;; (defun fi-complete (prefix &optional case-sensitive?) ...) -- no body, commented declareFunction
;; (defun fi-complete-int (prefix &optional case-sensitive?) ...) -- no body, commented declareFunction
;; (defun fi-create (name &optional external-id) ...) -- no body, commented declareFunction

(defun fi-create-int (name &optional external-id)
  (reset-fi-error-state)
  (unless (eq name :unnamed)
    (unless (stringp name)
      (signal-fi-error (list :arg-error "Expected a string, got ~S" name))
      (return-from fi-create-int nil))
    (unless (valid-constant-name-p name)
      (signal-fi-error (list :invalid-name "~S is not a valid name for a constant" name))
      (return-from fi-create-int nil))
    (when *require-case-insensitive-name-uniqueness*
      (let ((name-collision (constant-name-case-collision name)))
        (when name-collision
          ;; missing-larkc 31584 likely calls unique-name-wrt-case to generate
          ;; a new name that doesn't clash case-insensitively
          (let ((new-name (missing-larkc 31584)))
            (signal-fi-warning (list :name-clash "NAME clash for ~S ; renaming to ~S" name new-name))
            (setf name new-name))))))
  (unless (or (null external-id)
              (constant-external-id-p external-id))
    (signal-fi-error (list :arg-error "Expected an external ID, got ~S" external-id))
    (return-from fi-create-int nil))
  (let ((ans nil))
    (let ((*janus-within-something?* t)
           (*within-fi-operation?* t))
      (let ((existing-by-name (if (stringp name) (find-constant name) nil))
            (existing-by-id (if external-id (find-constant-by-external-id external-id) nil)))
        (cond
          ((and (null existing-by-name)
                (null external-id))
           (let ((new-external-id (make-constant-external-id)))
             (setf ans (create-constant name new-external-id))
             (setf *fi-last-constant* ans)))
          ((and (null existing-by-name)
                external-id
                (null existing-by-id))
           (setf ans (create-constant name external-id))
           (setf *fi-last-constant* ans))
          ((and (null existing-by-name)
                existing-by-id)
           ;; missing-larkc 11177 likely handles ID clash when a constant
           ;; exists with the given external-id but under a different name
           (setf ans (missing-larkc 11177)))
          ((and existing-by-name
                existing-by-id
                (not (eq existing-by-name existing-by-id)))
           ;; missing-larkc 11178 likely handles the case where name and id
           ;; map to different existing constants
           (setf ans (missing-larkc 11178)))
          ((and existing-by-name
                existing-by-id
                (eq existing-by-name existing-by-id))
           (setf ans existing-by-name))
          ((and existing-by-name
                (null existing-by-id)
                (uninstalled-constant-p existing-by-name))
           (let ((external-id-to-install (if external-id external-id (make-constant-external-id))))
             (setf ans (create-constant name external-id-to-install)))
           (setf *fi-last-constant* ans))
          ((and existing-by-name
                (null existing-by-id))
           ;; missing-larkc 31585 likely calls unique-name-wrt-case to generate
           ;; a new name that avoids the clash
           (let ((new-name (missing-larkc 31585)))
             (setf ans (create-constant new-name external-id))
             (setf *fi-last-constant* ans)
             (signal-fi-warning (list :name-clash "NAME clash for ~S ; renaming to ~S" name new-name)))))))
    (janus-note-create-finished ans)
    ans))

;; (defun handle-id-clash (existing-by-name external-id) ...) -- no body, commented declareFunction
;; (defun fi-find-or-create (name &optional external-id) ...) -- no body, commented declareFunction
;; (defun fi-find-or-create-int (name &optional external-id) ...) -- no body, commented declareFunction
;; (defun fi-create-skolem (name unrestricted-vars asserted-sentence defining-mt arity) ...) -- no body, commented declareFunction
;; (defun fi-create-skolem-int (unrestricted-vars asserted-sentence defining-mt arity &optional name) ...) -- no body, commented declareFunction
;; (defun fi-skolem-assert-arg-isas (skolem-function arity unrestricted-vars asserted-sentence) ...) -- no body, commented declareFunction
;; (defun fi-skolem-assert-result-types (skolem-function unrestricted-vars asserted-sentence) ...) -- no body, commented declareFunction
;; (defun new-skolem-name (arity) ...) -- no body, commented declareFunction
;; (defun fi-merge (kill-fort keep-fort) ...) -- no body, commented declareFunction
;; (defun fi-merge-int (kill-fort keep-fort) ...) -- no body, commented declareFunction
;; (defun merge-fort-recursive (kill-fort keep-fort) ...) -- no body, commented declareFunction
;; (defun merge-dependent-narts (kill-fort keep-fort) ...) -- no body, commented declareFunction
;; (defun merge-dependent-kb-hl-supports (kill-fort keep-fort) ...) -- no body, commented declareFunction
;; (defun substitute-assertion (assertion kill-fort keep-fort mt) ...) -- no body, commented declareFunction
;; (defun substitute-asserted-argument (assertion kill-fort keep-fort mt) ...) -- no body, commented declareFunction
;; (defun substitute-deduction (deduction kill-fort keep-fort mt assertion-mapping assertion) ...) -- no body, commented declareFunction
;; (defun substitute-dependents (assertion kill-fort keep-fort mt assertion-mapping) ...) -- no body, commented declareFunction
;; (defun substitute-dependent-assertion (dep-assertion kill-fort keep-fort mt) ...) -- no body, commented declareFunction
;; (defun substitute-termofunit-assertion (tou-assertion kill-fort keep-fort mt) ...) -- no body, commented declareFunction
;; (defun make-merge-fort-assertion-map (kill-fort) ...) -- no body, commented declareFunction
;; (defun merge-fort-assertion-map-valid? () ...) -- no body, commented declareFunction
;; (defun add-merge-fort-assertion-mapping (old-assertion new-assertion assertion-map) ...) -- no body, commented declareFunction
;; (defun get-merge-fort-assertion-mapping (old-assertion) ...) -- no body, commented declareFunction
;; (defun fi-kill (fort) ...) -- no body, commented declareFunction

(defun fi-kill-int (fort)
  (reset-fi-error-state)
  (setf fort (fi-convert-to-fort fort))
  (when (fi-error-signaled?)
    (return-from fi-kill-int nil))
  (when (uninstalled-constant-p fort)
    (signal-fi-error (list :arg-error "Constant ~S is merely an empty shell, not part of the Knowledge Base" fort))
    (return-from fi-kill-int nil))
  (let ((*within-assert* nil)
         (*check-arg-types?* nil)
         (*at-check-arg-types?* nil)
         (*check-wff-semantics?* nil)
         (*check-wff-coherence?* nil)
         (*check-var-types?* nil)
         (*simplify-literal?* nil)
         (*at-check-relator-constraints?* nil)
         (*at-check-arg-format?* nil)
         (*validate-constants?* nil)
         (*suspend-sbhl-type-checking?* t)
         (*within-fi-operation?* t))
    (remove-fort fort))
  (not (fi-error-signaled?)))

;; (defun fi-rename (constant name) ...) -- no body, commented declareFunction

(defun fi-rename-int (constant name)
  (reset-fi-error-state)
  (unless (constant-p constant)
    (signal-fi-error (list :arg-error "Expected a constant, got ~S" constant))
    (return-from fi-rename-int nil))
  (unless (stringp name)
    (signal-fi-error (list :arg-error "Expected a string, got ~S" name))
    (return-from fi-rename-int nil))
  (unless (valid-constant-name-p name)
    (signal-fi-error (list :invalid-name "~S is not a valid name for a constant" name))
    (return-from fi-rename-int nil))
  (when *require-case-insensitive-name-uniqueness*
    (let ((name-collisions (constant-name-case-collisions name)))
      (setf name-collisions (delete constant name-collisions))
      (when name-collisions
        ;; missing-larkc 31586 likely calls unique-name-wrt-case to generate
        ;; a new name that avoids the case-insensitive clash
        (let ((new-name (missing-larkc 31586)))
          (signal-fi-warning (list :name-clash "NAME clash for ~S ; renaming to ~S" name new-name))
          (setf name new-name)))))
  (let ((ans nil))
    (let ((*within-fi-operation?* t))
      (if (equal (constant-name constant) name)
          (signal-fi-warning (list :already-has-name "Constant ~S is already named ~A" constant name))
          (let ((existing-constant (find-constant name)))
            (if (valid-constant? existing-constant)
                (progn
                  ;; missing-larkc 31587 likely generates a unique name
                  ;; to avoid the clash with the existing constant
                  (let ((new-name (missing-larkc 31587)))
                    (setf ans (rename-constant constant new-name))
                    (signal-fi-warning (list :name-clash "NAME clash for ~S ; renaming to ~S" name new-name))))
                (progn
                  (when (constant-p existing-constant)
                    (remove-constant existing-constant))
                  (setf ans (rename-constant constant name)))))))
    ans))

;; (defun fi-lookup (formula mt) ...) -- no body, commented declareFunction
;; (defun fi-lookup-int (formula mt) ...) -- no body, commented declareFunction
;; (defun sentence-assertions-in-mt (sentence mt truth) ...) -- no body, commented declareFunction
;; (defun sentence-assertions (sentence mt) ...) -- no body, commented declareFunction
;; (defun sentence-visible-assertions (sentence mt) ...) -- no body, commented declareFunction
;; (defun sentence-assertions-in-any-mt (sentence) ...) -- no body, commented declareFunction
;; (defun sentence-assertion (sentence mt) ...) -- no body, commented declareFunction
;; (defun gaf-sentence-assertion (sentence mt) ...) -- no body, commented declareFunction
;; (defun fi-assert (formula mt &optional strength direction) ...) -- no body, commented declareFunction

(defun fi-assert-int (formula mt &optional (strength :default) direction)
  (reset-fi-error-state)
  (unless (el-formula-p formula)
    (signal-fi-error (list :arg-error "Expected a cons, got ~S" formula))
    (return-from fi-assert-int nil))
  (setf formula (transform-tl-terms-to-hl formula))
  (setf mt (transform-tl-terms-to-hl mt))
  (setf mt (fi-convert-to-assert-hlmt mt))
  (when (fi-error-signaled?)
    (return-from fi-assert-int nil))
  (unless (el-strength-p strength)
    (signal-fi-error (list :arg-error "Expected :default or :monotonic, got ~S" strength))
    (return-from fi-assert-int nil))
  (unless (or (null direction) (direction-p direction))
    (signal-fi-error (list :arg-error "Expected a direction, got ~S" direction))
    (return-from fi-assert-int nil))
  (let ((assertions-found-or-created nil)
        (ans nil)
        (janus-deduce-specs nil))
    (let ((*janus-within-something?* t)
           (*janus-extraction-deduce-specs* nil))
      (multiple-value-bind (canon-versions canon-mt)
          (if *assume-assert-sentence-is-wf?*
              (canonicalize-wf-assert-sentence formula mt)
              (canonicalize-assert-sentence formula mt))
        (let ((mt-var (with-inference-mt-relevance-validate canon-mt)))
          (let ((*mt* (update-inference-mt-relevance-mt mt-var))
                 (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
                 (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var))
                 (*within-fi-operation?* t))
            (cond
              ((null canon-versions)
               (signal-fi-error (fi-not-wff-assert-error formula canon-mt)))
              ((eq canon-versions #$True)
               (signal-fi-error (list :tautology "Formula ~%  ~S ~%in ~S was a tautology." formula canon-mt)))
              ((eq canon-versions #$False)
               (signal-fi-error (list :contradiction "Formula ~%  ~S ~%in ~S was a contradiction." formula canon-mt)))
              (t
               (setf *fi-last-assertions-asserted* nil)
               (dolist (canon-version canon-versions)
                 (unless (fi-error-signaled?)
                   (destructuring-bind (cnf &optional variable-map query-free-vars)
                       canon-version
                     (declare (ignore query-free-vars))
                     (when (null direction)
                       (setf direction (fi-cnf-default-direction cnf)))
                     (let ((assertion (hl-assert cnf canon-mt strength direction variable-map)))
                       (cond
                         ((assertion-p assertion)
                          (push assertion assertions-found-or-created))
                         ((null assertion)
                          (signal-fi-error (list :could-not-assert "Unable to assert formula ~S~%in ~S." formula canon-mt))))))))
               (setf assertions-found-or-created (nreverse assertions-found-or-created))))
            (setf ans (not (fi-error-signaled?))))))
      (when (not (fi-error-signaled?))
        (let ((deductions-found-or-created nil))
          (let ((*forward-inference-allowed-rules* (hl-prototype-allowed-forward-rules assertions-found-or-created)))
            (setf deductions-found-or-created (perform-forward-inference)))
          (perform-assert-post-processing assertions-found-or-created deductions-found-or-created)))
      (setf janus-deduce-specs *janus-extraction-deduce-specs*))
    (janus-note-assert-finished formula mt strength direction janus-deduce-specs)
    ans))

(defun perform-assert-post-processing (assertions-found-or-created deductions-found-or-created)
  (declare (ignore deductions-found-or-created))
  (let ((skolem-functions nil))
    (dolist (ass assertions-found-or-created)
      (unless (tou-assertion? ass)
        (let ((skolem-narts nil))
          (let ((*opaque-arg-function* 'opaque-arg-wrt-quoting-not-counting-logical-ops?))
            (setf skolem-narts (assertion-gather 'fast-skolem-nat? ass nil)))
          (when skolem-narts
            (dolist (skolem-nart skolem-narts)
              (pushnew (nat-functor skolem-nart) skolem-functions))))))
    (when skolem-functions
      (dolist (skolem-function skolem-functions)
        (declare (ignore skolem-function))
        ;; missing-larkc 11190 likely calls fi-perform-assert-post-processing-for-skolem
        ;; to set up defining assertions (isa, arity, arg-type constraints) for the skolem function
        (missing-larkc 11190))))
  nil)

;; (defun perform-assert-post-processing-for-skolem (assertions-found-or-created deductions-found-or-created) ...) -- no body, commented declareFunction
;; (defun fi-perform-assert-post-processing-for-skolem (assertions-found-or-created deductions-found-or-created) ...) -- no body, commented declareFunction

(defun fi-cnf-default-direction (cnf)
  (declare (type cnf-p cnf))
  (when (pos-atomic-clause-p cnf)
    (let ((asent (atomic-clause-asent cnf)))
      (when (ist-sentence-p asent)
        ;; missing-larkc 30485 likely extracts the sub-mt from the ist sentence
        (let ((sub-mt (missing-larkc 30485)))
          (declare (ignore sub-mt))
          ;; missing-larkc 30505 likely extracts the sub-sentence from the ist sentence
          (let ((subsentence (missing-larkc 30505)))
            (declare (ignore subsentence))
            ;; missing-larkc 8813 likely canonicalizes the sub-sentence into cnf form
            (let ((sub-cnfs (missing-larkc 8813)))
              (dolist (sub-cnf sub-cnfs)
                (when (eq :backward (fi-cnf-default-direction sub-cnf))
                  (return-from fi-cnf-default-direction :backward))))))
        (return-from fi-cnf-default-direction :forward))))
  (if (and (atomic-clause-p cnf)
           (ground-clause-p cnf))
      :forward
      :backward))

;; (defun fi-not-wff-error (formula mt) ...) -- no body, commented declareFunction

(defun fi-not-wff-assert-error (formula mt)
  "[Cyc] Returns an error for why it is not wff to assert FORMULA in MT."
  (if *generate-precise-fi-wff-errors?*
      (list :formula-not-well-formed "Formula ~%  ~S ~%was not well formed because: ~%~a" formula (explanation-of-why-not-wff-assert formula mt))
      (list :formula-not-well-formed "Formula ~%  ~S ~%was not well formed" formula)))

(defun fi-assert-update-asserted-argument (assertion hl-tv direction)
  (let ((current-direction (assertion-direction assertion))
        (existing-asserted-argument (get-asserted-argument assertion)))
    (push assertion *fi-last-assertions-asserted*)
    (if existing-asserted-argument
        (if (eq hl-tv (argument-tv existing-asserted-argument))
            (when (eq direction current-direction)
              (signal-fi-warning '(:redundant-local-assertion)))
            ;; missing-larkc 12457 likely changes the TV of the existing asserted argument,
            ;; e.g. calls tms-change-asserted-argument-tv
            (missing-larkc 12457))
        (tms-create-asserted-argument-with-tv assertion hl-tv))
    (when (not (eq direction current-direction))
      (tms-change-direction assertion direction)))
  assertion)

(defun hl-assert-update-asserted-argument (assertion hl-tv direction)
  (fi-assert-update-asserted-argument assertion hl-tv direction))

;; (defun fi-reassert (old-formula new-formula old-mt new-mt) ...) -- no body, commented declareFunction
;; (defun fi-reassert-int (old-formula new-formula old-mt new-mt) ...) -- no body, commented declareFunction
;; (defun fi-reassert-hl-tv (assertion strength) ...) -- no body, commented declareFunction
;; (defun fi-rededuce-deduction-assertion (deduction assertion) ...) -- no body, commented declareFunction
;; (defun fi-unassert (sentence mt) ...) -- no body, commented declareFunction

(defun fi-unassert-int (sentence mt)
  (reset-fi-error-state)
  (unless (el-formula-p sentence)
    (signal-fi-error (list :arg-error "Expected a cons, got ~S" sentence))
    (return-from fi-unassert-int nil))
  (let ((ans nil)
        (environment (get-forward-inference-environment)))
    (check-type environment 'queue-p)
    (let ((*forward-inference-environment* environment))
      (let ((*within-fi-operation?* t))
        (multiple-value-bind (canon-versions new-mt deduced-argument?)
            (canonicalize-fi-unassert-sentence sentence mt)
          (setf mt new-mt)
          (let ((canonical-mt (fi-convert-to-assert-hlmt mt)))
            (unless (fi-error-signaled?)
              (let ((mt-var (with-inference-mt-relevance-validate canonical-mt)))
                (let ((*mt* (update-inference-mt-relevance-mt mt-var))
                       (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
                       (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
                  (cond
                    ((and deduced-argument? (null canon-versions))
                     ;; no-op: deduced argument with no canon versions
                     )
                    ((null canon-versions)
                     ;; missing-larkc 11160 likely returns an error about the sentence
                     ;; not being well-formed for unassertion
                     (signal-fi-error (missing-larkc 11160)))
                    ((eq canon-versions #$True)
                     (signal-fi-error (list :tautology "Sentence ~%  ~S ~%in ~S was a tautology." sentence mt)))
                    ((eq canon-versions #$False)
                     (signal-fi-error (list :contradiction "Sentence ~%  ~S ~%in ~S was a contradiction." sentence mt)))
                    (t
                     (dolist (canon-version canon-versions)
                       (unless (fi-error-signaled?)
                         (destructuring-bind (cnf &optional variable-map query-free-vars)
                             canon-version
                           (declare (ignore variable-map query-free-vars))
                           (unless (hl-unassert cnf mt)
                             (signal-fi-warning (list :assertion-not-present "Sentence ~S in mt ~S is not in the KB" sentence mt)))))))))))))
          (setf ans (not (fi-error-signaled?))))
      (when ans
        (perform-forward-inference)))
    ans))

(defun canonicalize-fi-unassert-sentence (sentence mt)
  (canonicalize-fi-remove-sentence sentence mt t))

;; (defun canonicalize-fi-blast-sentence (sentence mt) ...) -- no body, commented declareFunction

(defun canonicalize-fi-remove-sentence (sentence mt check-for-asserted-argument?)
  "[Cyc] @return 0 canon-versions
@return 1 mt"
  (let ((el-sentence (transform-tl-terms-to-hl sentence)))
    (multiple-value-bind (new-el-sentence new-mt)
        (unwrap-if-ist el-sentence mt)
      (setf el-sentence new-el-sentence)
      (setf mt new-mt))
    (setf mt (canonicalize-unassert-hlmt mt))
    (let ((canon-versions nil)
          (deduced-argument? nil)
          (assertions (if (hlmt-p mt)
                          (find-assertions-cycl el-sentence mt)
                          nil)))
      (when (null assertions)
        ;; missing-larkc 10917 likely looks up assertions via a broader search
        ;; (e.g. find-assertions-cycl-renaming or similar) as a fallback
        (setf assertions (missing-larkc 10917)))
      (if assertions
          (dolist (assertion assertions)
            (if (and check-for-asserted-argument?
                     (null (get-asserted-argument assertion)))
                (progn
                  (signal-fi-warning (list :assertion-not-local "Sentence ~S in mt ~S is not locally in the KB" el-sentence mt))
                  (setf deduced-argument? t))
                (let ((cnf (assertion-cnf assertion))
                      (variable-map nil)
                      (query-free-vars nil))
                  (let ((canon-version (list cnf variable-map query-free-vars))
                        (ass-mt (assertion-mt assertion)))
                    (push canon-version canon-versions)
                    (setf mt ass-mt)))))
          (when (hlmt-p mt)
            ;; missing-larkc 31062 likely calls canonicalize-assert-sentence or similar
            ;; to generate canon-versions from the el-sentence when no assertions found
            (multiple-value-bind (new-canon-versions new-mt)
                (missing-larkc 31062)
              (setf canon-versions new-canon-versions)
              (setf mt new-mt))))
      (values canon-versions mt deduced-argument?))))

(defun canonicalize-unassert-hlmt (mt)
  (setf mt (tlmt-to-hlmt mt))
  (setf mt (nart-substitute mt))
  mt)

;; (defun fi-edit (old-formula new-formula &optional old-mt new-mt strength direction) ...) -- no body, commented declareFunction
;; (defun fi-edit-int (old-formula new-formula &optional old-mt new-mt strength direction) ...) -- no body, commented declareFunction
;; (defun careful-fi-edit-int (old-formula new-formula &optional old-mt new-mt strength direction) ...) -- no body, commented declareFunction
;; (defun fi-justify (formula mt &optional backchain) ...) -- no body, commented declareFunction
;; (defun fi-justify-int (formula mt &optional backchain) ...) -- no body, commented declareFunction
;; (defun formula-justify (formula mt &optional backchain) ...) -- no body, commented declareFunction
;; (defun gaf-justify (sentence mt truth) ...) -- no body, commented declareFunction
;; (defun one-step-gaf-justify (sentence mt) ...) -- no body, commented declareFunction
;; (defun justify-support (support) ...) -- no body, commented declareFunction
;; (defun fi-add-argument (sentence mt support &optional strength direction) ...) -- no body, commented declareFunction
;; (defun fi-add-argument-int (sentence mt support &optional strength direction) ...) -- no body, commented declareFunction
;; (defun convert-hl-support-to-el-support (hl-support) ...) -- no body, commented declareFunction
;; (defun convert-hl-support-to-fi-support (hl-support) ...) -- no body, commented declareFunction
;; (defun convert-hl-support-to-tl-support (hl-support) ...) -- no body, commented declareFunction
;; (defun make-el-support (module formula &optional mt tv) ...) -- no body, commented declareFunction
;; (defun fi-canonicalize-el-supports (el-supports &optional mt) ...) -- no body, commented declareFunction
;; (defun el-support-assertions (el-support mt) ...) -- no body, commented declareFunction
;; (defun fi-remove-argument (sentence mt support &optional strength) ...) -- no body, commented declareFunction
;; (defun fi-remove-argument-int (sentence mt support &optional strength) ...) -- no body, commented declareFunction
;; (defun fi-blast (formula mt) ...) -- no body, commented declareFunction
;; (defun fi-blast-int (formula mt) ...) -- no body, commented declareFunction
;; (defun fi-ask (formula &optional mt backchain number time depth) ...) -- no body, commented declareFunction
;; (defun fi-ask-int (formula &optional mt backchain number time depth) ...) -- no body, commented declareFunction
;; (defun fi-ask-ist-query-p (formula) ...) -- no body, commented declareFunction
;; (defun fi-ask-int-new-cyc-query-trampoline (formula mt backchain number time depth) ...) -- no body, commented declareFunction
;; (defun fi-continue-last-ask (&optional backchain number time depth reconsider-deep) ...) -- no body, commented declareFunction
;; (defun fi-continue-last-ask-int (&optional backchain number time depth reconsider-deep) ...) -- no body, commented declareFunction
;; (defun fi-ask-status () ...) -- no body, commented declareFunction
;; (defun fi-ask-status-int () ...) -- no body, commented declareFunction
;; (defun fi-tms-reconsider-formula (formula mt) ...) -- no body, commented declareFunction
;; (defun fi-tms-reconsider-formula-int (formula mt) ...) -- no body, commented declareFunction
;; (defun fi-tms-reconsider-mt (mt) ...) -- no body, commented declareFunction
;; (defun fi-tms-reconsider-mt-int (mt) ...) -- no body, commented declareFunction
;; (defun fi-tms-reconsider-gafs (term &optional arg predicate mt) ...) -- no body, commented declareFunction
;; (defun fi-tms-reconsider-gafs-int (term &optional arg predicate mt) ...) -- no body, commented declareFunction
;; (defun fi-tms-reconsider-term (term &optional mt) ...) -- no body, commented declareFunction
;; (defun fi-tms-reconsider-term-int (term &optional mt) ...) -- no body, commented declareFunction
;; (defun fi-timestamp-constant (cyclist time &optional why second) ...) -- no body, commented declareFunction

(defun fi-timestamp-constant-int (cyclist time &optional why second)
  (setf cyclist (transform-tl-terms-to-hl cyclist))
  (when why
    (setf why (transform-tl-terms-to-hl why)))
  (reset-fi-error-state)
  (let ((ans nil))
    (let ((*within-fi-operation?* t))
      (cond
        ((not (fort-p cyclist))
         (signal-fi-warning '(:invalid-cyclist)))
        ((not (integerp time))
         (signal-fi-warning '(:invalid-time)))
        ((not (or (null why) (constant-p why)))
         (signal-fi-warning '(:invalid-purpose)))
        ((not (or (null second) (universal-second-p second)))
         (signal-fi-warning '(:invalid-second)))
        ((not (constant-p *fi-last-constant*))
         (signal-fi-warning '(:no-constant)))
        ((constant-timestamped? *fi-last-constant*)
         (signal-fi-warning '(:already-timestamped)))
        (t
         (timestamp-constant *fi-last-constant* cyclist time why second)))
      (setf ans (not (fi-error-signaled?)))
      (setf *fi-last-constant* nil)
      (setf *fi-last-assertions-asserted* nil))
    ans))

(defun constant-timestamped? (constant)
  (declare (type constant-p constant))
  (or (fpred-value-in-any-mt constant #$myCreator)
      (fpred-value-in-any-mt constant #$myCreationTime)
      (fpred-value-in-any-mt constant #$myCreationPurpose)
      (fpred-value-in-any-mt constant #$myCreationSecond)
      nil))

(defun timestamp-constant (constant cyclist time &optional why second)
  (let ((v-properties (list :strength :monotonic :direction :backward)))
    (cyc-assert-wff (list #$myCreator constant cyclist) #$BookkeepingMt v-properties)
    (cyc-assert-wff (list #$myCreationTime constant time) #$BookkeepingMt v-properties)
    (when (constant-p why)
      (cyc-assert-wff (list #$myCreationPurpose constant why) #$BookkeepingMt v-properties))
    (when (universal-second-p second)
      (cyc-assert-wff (list #$myCreationSecond constant second) #$BookkeepingMt v-properties)))
  constant)

;; (defun untimestamp-constant (constant) ...) -- no body, commented declareFunction
;; (defun retimestamp-constant (constant cyclist time &optional why second) ...) -- no body, commented declareFunction
;; (defun fi-timestamp-assertion (cyclist time &optional why second) ...) -- no body, commented declareFunction

(defun fi-timestamp-assertion-int (cyclist time &optional why second)
  (setf cyclist (transform-tl-terms-to-hl cyclist))
  (when why
    (setf why (transform-tl-terms-to-hl why)))
  (reset-fi-error-state)
  (let ((ans nil))
    (let ((*within-fi-operation?* t))
      (cond
        ((not (fort-p cyclist))
         (signal-fi-warning '(:invalid-cyclist)))
        ((not (integerp time))
         (signal-fi-warning '(:invalid-time)))
        ((not (or (null why) (constant-p why)))
         (signal-fi-warning '(:invalid-purpose)))
        ((not (or (null second) (universal-second-p second)))
         (signal-fi-warning '(:invalid-second)))
        ((not (consp *fi-last-assertions-asserted*))
         (signal-fi-warning '(:no-assertions)))
        (t
         (let ((assertions *fi-last-assertions-asserted*))
           (dolist (assertion assertions)
             (when (asserted-assertion? assertion)
               (if (asserted-assertion-timestamped? assertion)
                   (signal-fi-warning '(:already-timestamped))
                   (timestamp-asserted-assertion assertion cyclist time why second)))))))
      (setf ans (not (fi-error-signaled?)))
      (setf *fi-last-assertions-asserted* nil))
    ans))

;; (defun fi-remove-timestamp (constant &optional assertion) ...) -- no body, commented declareFunction
;; (defun fi-remove-timestamp-int (constant assertion) ...) -- no body, commented declareFunction
;; (defun fi-rename-variables (assertion new-variables &optional mt) ...) -- no body, commented declareFunction
;; (defun fi-rename-variables-int (assertion new-variables &optional mt) ...) -- no body, commented declareFunction
;; (defun fi-get-parameter (param) ...) -- no body, commented declareFunction
;; (defun fi-get-parameter-int (param) ...) -- no body, commented declareFunction
;; (defun fi-set-parameter (param value) ...) -- no body, commented declareFunction
;; (defun fi-set-parameter-int (param value) ...) -- no body, commented declareFunction
;; (defun fi-eval (form) ...) -- no body, commented declareFunction
;; (defun fi-eval-int (form) ...) -- no body, commented declareFunction
;; (defun fi-local-eval (form) ...) -- no body, commented declareFunction
;; (defun fi-local-eval-int (form) ...) -- no body, commented declareFunction

(defun ke-purpose ()
  *ke-purpose*)

;; (defun set-ke-purpose (purpose) ...) -- no body, commented declareFunction

(defun the-date ()
  (if (integerp *the-date*)
      *the-date*
      (get-universal-date)))

(defun the-second ()
  (if (integerp *the-second*)
      *the-second*
      (get-universal-second)))

(defun fi-convert-to-assert-hlmt (el-term)
  (let ((v-hlmt (canonicalize-assert-mt el-term)))
    (unless (hlmt-p v-hlmt)
      (signal-fi-error (list :arg-error "Expected a microtheory, got ~S" el-term))
      (return-from fi-convert-to-assert-hlmt nil))
    v-hlmt))

;; (defun fi-convert-to-ask-hlmt (el-term) ...) -- no body, commented declareFunction

(defun fi-convert-to-fort (el-term)
  (let ((fort (fi-canonicalize-el-term el-term)))
    (unless (fort-p fort)
      (signal-fi-error (list :arg-error "Expected a term, got ~S" el-term))
      (return-from fi-convert-to-fort nil))
    fort))

(defun fi-canonicalize-el-term (el-term)
  (setf el-term (transform-tl-terms-to-hl el-term))
  (cond
    ((fort-or-chlmt-p el-term) el-term)
    ((possibly-naut-p el-term)
     ;; missing-larkc 10341 likely calls nart-substitute or czer-main function
     ;; to canonicalize the NAUT to a NART
     (missing-larkc 10341))
    (t nil)))

(defun fi-canonicalize (canon-info &optional canon-gaf (strength :default))
  (let* ((cnf (first canon-info))
         (v-variables (mapcar #'car (second canon-info)))
         (hl-tv nil))
    (when *within-assert*
      (check-type (mapcar #'cdr (second canon-info)) 'kb-var-list?))
    (cond
      ((and canon-gaf
            (atomic-clause-p cnf)
            (null v-variables))
       (if (null (neg-lits cnf))
           (setf hl-tv (if (eq strength :monotonic) :true-mon :true-def))
           (progn
             (rplaca (rest cnf) (neg-lits cnf))
             (rplaca cnf nil)
             (setf hl-tv (if (eq strength :monotonic) :false-mon :false-def)))))
      (t
       (setf hl-tv (if (eq strength :monotonic) :true-mon :true-def))))
    (values cnf v-variables hl-tv)))

;; (defun fi-canonicalize-gaf (gaf mt) ...) -- no body, commented declareFunction
;; (defun clear-cached-fi-canonicalize-gaf () ...) -- no body, commented declareFunction
;; (defun remove-cached-fi-canonicalize-gaf (gaf mt) ...) -- no body, commented declareFunction
;; (defun cached-fi-canonicalize-gaf-internal (gaf mt) ...) -- no body, commented declareFunction
;; (defun cached-fi-canonicalize-gaf (gaf mt) ...) -- no body, commented declareFunction
;; (defun fi-canonicalize-literal (literal mt) ...) -- no body, commented declareFunction
;; (defun fi-canonicalize-ask (formula) ...) -- no body, commented declareFunction
;; (defun kb-var-list? (list) ...) -- no body, commented declareFunction

(defun assertion-fi-formula (assertion &optional (substitute-vars? t))
  "[Cyc] Return the formula for ASSERTION which is suitable for the FI.
If SUBSTITUTE-VARS? is non-nil, then the original variable names are substituted as well."
  (let* ((scope-mt *assertion-fi-formula-mt-scope*)
         (mt (assertion-mt assertion))
         (formula nil))
    (if (and scope-mt (not (hlmt-equal mt scope-mt)))
        ;; missing-larkc 31010 likely returns an ist-wrapped formula
        ;; since the assertion's mt differs from the scope mt
        (setf formula (missing-larkc 31010))
        (setf formula (assertion-formula assertion)))
    (setf formula (copy-tree formula))
    (let ((*assertion-fi-formula-mt-scope* mt))
      (setf formula (perform-fi-substitutions formula (if substitute-vars?
                                                          (assertion-el-variables assertion)
                                                          nil))))
    formula))

(defun assertion-hl-formula (assertion &optional (substitute-vars? t))
  (declare (type assertion-p assertion))
  (let ((formula nil))
    (let ((*generate-readable-fi-results* nil))
      (setf formula (assertion-fi-formula assertion substitute-vars?)))
    formula))

;; (defun assertion-fi-ist-formula (assertion &optional substitute-vars?) ...) -- no body, commented declareFunction
;; (defun assertion-fi-cnf (assertion &optional substitute-vars?) ...) -- no body, commented declareFunction
;; (defun assertion-cnf-with-el-vars (assertion) ...) -- no body, commented declareFunction

(defun perform-fi-substitutions (object &optional symbol-variables)
  (dolist (symbol symbol-variables)
    (let ((variable (find-variable-by-id (position symbol symbol-variables))))
      (setf object (nsubst symbol variable object))))
  (setf object (ntransform object #'variable-p #'default-el-var-for-hl-var))
  (when *generate-readable-fi-results*
    (setf object (assertion-expand object))
    (setf object (nart-expand object)))
  object)

(defun assertion-expand (object)
  (when (tree-find-if #'assertion-p object)
    (setf object (transform object #'assertion-p #'assertion-fi-formula)))
  object)

;; (defun assertion-ist-expand (object) ...) -- no body, commented declareFunction


;;; Setup section

(toplevel
  (pushnew '*fi-warning* *fi-state-variables*)
  (pushnew '*fi-error* *fi-state-variables*)
  (pushnew '*fi-last-constant* *fi-state-variables*)
  (pushnew '*fi-last-assertions-asserted* *fi-state-variables*))

(toplevel
  (register-cyc-api-function 'fi-get-warning nil
    "Return a description of the warning resulting from the last FI operation."
    nil '((nil-or atom)))
  (register-cyc-api-function 'fi-get-error nil
    "Return a description of the error resulting from the last FI operation."
    nil '((nil-or atom)))
  (register-cyc-api-function 'fi-find '(name)
    "Return the constant indentified by the string NAME."
    nil '((nil-or constant-p)))
  (register-cyc-api-function 'fi-complete '(prefix &optional case-sensitive?)
    "Return a list of constants whose name begins with PREFIX. The comparison is
performed in a case-insensitive mode unless CASE-SENSITIVE? is non-nil."
    nil '((list constant-p)))
  (register-cyc-api-function 'fi-create '(name &optional external-id)
    "Create a new constant with NAME.
If EXTERNAL-ID is non-null it is used, otherwise a unique identifier is generated."
    nil '(constant-p))
  (register-cyc-api-function 'fi-find-or-create '(name &optional external-id)
    "Return constant with NAME if it is present.
If not present, then create constant with NAME, using EXTERNAL-ID if given.
If EXTERNAL-ID is not given, generate a new one for the new constant."
    nil '(constant-p))
  (register-cyc-api-function 'fi-kill '(fort)
    "Kill FORT and all its uses from the KB.  If FORT is a microtheory, all assertions
in that microtheory are removed."
    nil '(booleanp))
  (register-cyc-api-function 'fi-rename '(constant name)
    "Change name of CONSTANT to NAME. Return the constant if no error, otherwise return NIL."
    nil '((nil-or constant-p)))
  (register-cyc-api-function 'fi-lookup '(formula mt)
    "Returns two values when looking up the EL FORMULA in the microtheory MT.  The
first value returned is a list of HL formulas resulting from the canonicalization
of the EL FORMULA.  The second value is T iff all the HL assertions were properly
put into the KB."
    nil '((list consp) booleanp))
  (register-cyc-api-function 'fi-assert '(formula mt &optional (strength :default) direction)
    "Assert the FORMULA in the specified MT.  STRENGTH is :default or :monotonic.
DIRECTION is :forward or :backward.  GAF assertion direction defaults to :forward, and rule
assertion direction defaults to :backward. Return T if there was no error."
    nil '(booleanp))
  (register-cyc-api-function 'fi-unassert '(formula mt)
    "Remove the assertions canonicalized from FORMULA in the microtheory MT.
Return T if the operation succeeded, otherwise return NIL."
    nil '(booleanp))
  (register-cyc-api-function 'fi-edit '(old-formula new-formula &optional old-mt (new-mt old-mt) (strength :default) direction)
    "Unassert the assertions canonicalized from OLD-FORMULA in the microtheory OLD-MT.
   Assert NEW-FORMULA in the specified NEW-MT.
   STRENGTH is :default or :monotonic.
   DIRECTION is :forward or :backward.
    GAF assertion direction defaults to :forward.
    Rule assertion direction defaults to :backward.
   Return T if there was no error."
    nil '(booleanp))
  (register-cyc-api-function 'fi-blast '(formula mt)
    "Remove all arguments for the FORMULA within MT, including both those
arguments resulting the direct assertion of the FORMULA, and
those arguments supporting the FORMULA which were derived through inference.
Return T if successful, otherwise return NIL."
    nil '(booleanp))
  (register-cyc-api-function 'fi-ask '(formula &optional mt backchain number time depth)
    "Ask for bindings for free variables which will satisfy FORMULA within MT.
If BACKCHAIN is NIL, no inference is performed.
If BACKCHAIN is an integer, then at most that many backchaining steps using rules
are performed.
If BACKCHAIN is T, then inference is performed without limit on the number of
backchaining steps when searching for bindings.
If NUMBER is an integer, then at most that number of bindings are returned.
If TIME is an integer, then at most TIME seconds are consumed by the search for
bindings.
If DEPTH is an integer, then the inference paths are limited to that number of
total steps.
Returns NIL if the operation had an error.  Otherwise returns a list of variable/
binding pairs.  In the case where the FORMULA has no free variables, the form
 (((T . T))) is returned indicating that the gaf is either directly asserted in the
KB, or that it can be derived via rules in the KB."
    nil '((nil-or listp)))
  (register-obsolete-cyc-api-function 'fi-continue-last-ask '(continue-inference)
                                      '(&optional backchain number time depth reconsider-deep)
    "Continue the last ask that was performed with more resources.
If BACKCHAIN is NIL, no inference is performed.
If BACKCHAIN is an integer, then at most that many backchaining steps using rules
are performed.
If BACKCHAIN is T, then inference is performed without limit on the number of
backchaining steps when searching for bindings.
If NUMBER is an integer, then at most that number of bindings are returned.
If TIME is an integer, then at most TIME seconds are consumed by the search for
bindings.
If DEPTH is an integer, then the inference paths are limited to that number of
total steps.
Returns NIL if the operation had an error.  Otherwise returns a list of variable/
binding pairs.  In the case where the FORMULA has no free variables, the form
 (((T . T))) is returned indicating that the gaf is either directly asserted in the
KB, or that it can be derived via rules in the KB."
    nil '((nil-or listp)))
  (define-obsolete-register 'fi-continue-last-ask-int '(continue-inference))
  (register-obsolete-cyc-api-function 'fi-ask-status '(inference-suspend-status) nil
    "Return a status as to how the last ask successfully completed regarding
resource limits.
:EXHAUST if the search spaces was exhausted.
:DEPTH if the search space was limited because some nodes were too deep.
:NUMBER if the requested number of bindings was found without exceeding other limits.
:TIME if the time alloted expired prior to exhausting the search space.
Return NIL if there was no prior successful ask."
    nil '((nil-or atom)))
  (define-obsolete-register 'fi-ask-status-int '(inference-suspend-status))
  (register-cyc-api-function 'fi-tms-reconsider-formula '(formula mt)
    "Reconsider all arguments for FORMULA within MT.  Return T if the
operation succeeded, NIL if there was an error."
    nil '(booleanp))
  (register-cyc-api-function 'fi-tms-reconsider-mt '(mt)
    "Reconsider all arguments for all formulas within MT.  Return T if the
operation succeeded, NIL if there was an error."
    nil '(booleanp))
  (register-cyc-api-function 'fi-tms-reconsider-gafs '(term &optional arg predicate mt)
    "Reconsider all arguments for all gaf formulas involving TERM.
ARG optionally constrains gafs such that the TERM occupies a specific arg position.
PREDICATE optionally constrains gafs such that the specifed PREDICATE
occupies the arg0 position.
MT optionally constrains gafs such that they must be included in the specific
microtheory.
Return T if the operation succeeded, NIL if there was an error."
    nil '(booleanp))
  (register-cyc-api-function 'fi-tms-reconsider-term '(term &optional mt)
    "Reconsider all arguments involving TERM.
If MT is provided, then only arguments in that microtheory are reconsidered.
Return T if the operation succeeded, NIL if there was an error."
    nil '(booleanp)))

(toplevel
  (note-globally-cached-function 'cached-fi-canonicalize-gaf))
