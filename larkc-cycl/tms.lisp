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

;; Variables from init section

(defparameter *tms-assertions-being-removed* nil)
(defparameter *tms-deductions-being-removed* nil)
(defparameter *circular-deductions* nil)
(defparameter *circular-assertions* nil)
(defparameter *circular-target-assertion* nil)
(defparameter *circular-local-assertions* nil)
(defparameter *circular-complexity-count* 0)

(defparameter *circular-complexity-count-limit* 50
  "[Cyc] The maximum number of assertions we'll consider while checking for
circularly supported assertions.  NIL means no limit")

;; Functions and macros in declare section order

(defun tms-assertion-being-removed? (assertion)
  "[Cyc] Return T iff ASSERTION is in the midst of being removed via TMS"
  (declare (type assertion assertion))
  (member? assertion *tms-assertions-being-removed*))

;; Reconstructed from Internal Constants evidence:
;; $list1 = ((ASSERTION) &BODY BODY) — arglist
;; $sym2$CLET → let, $sym4$ADJOIN → adjoin
;; $sym3$*TMS-ASSERTIONS-BEING-REMOVED*, $list5 = (*TMS-ASSERTIONS-BEING-REMOVED*)
;; Pattern: rebind *tms-assertions-being-removed* with assertion adjoined
(defmacro tms-note-assertion-being-removed ((assertion) &body body)
  "[Cyc] Execute BODY with ASSERTION noted as being removed via TMS."
  `(let ((*tms-assertions-being-removed* (adjoin ,assertion *tms-assertions-being-removed*)))
     ,@body))

(defun tms-deduction-being-removed? (deduction)
  "[Cyc] Return T iff DEDUCTION is in the midst of being removed via TMS"
  (declare (type deduction deduction))
  (member? deduction *tms-deductions-being-removed*))

;; Reconstructed from Internal Constants evidence:
;; $list7 = ((DEDUCTION) &BODY BODY) — arglist
;; $sym8$*TMS-DEDUCTIONS-BEING-REMOVED*, $list9 = (*TMS-DEDUCTIONS-BEING-REMOVED*)
;; Same pattern as tms-note-assertion-being-removed but for deductions
(defmacro tms-note-deduction-being-removed ((deduction) &body body)
  "[Cyc] Execute BODY with DEDUCTION noted as being removed via TMS."
  `(let ((*tms-deductions-being-removed* (adjoin ,deduction *tms-deductions-being-removed*)))
     ,@body))

(defun tms-argument-being-removed? (argument)
  "[Cyc] Return T iff ARGUMENT is known to be in the midst of being removed via TMS"
  (and (deduction-p argument)
       (tms-deduction-being-removed? argument)))

;; Reconstructed from Internal Constants evidence:
;; $sym10$PIF → if, $sym11$TMS_NOTE_DEDUCTION_BEING_REMOVED, $sym12$PROGN
;; No explicit arglist constant, but follows the same ((argument) &body body) pattern.
;; Checks if argument is a deduction; if so, wraps body in tms-note-deduction-being-removed;
;; otherwise just runs body in a progn.
(defmacro tms-note-argument-being-removed ((argument) &body body)
  "[Cyc] Execute BODY with ARGUMENT noted as being removed via TMS (if it is a deduction)."
  `(if (deduction-p ,argument)
       (tms-note-deduction-being-removed (,argument) ,@body)
       (progn ,@body)))

;; (defun tms-possibly-replace-asserted-argument-with-tv (assertion tv) ...) -- no body, commented declareFunction (2 0)

(defun tms-create-asserted-argument-with-tv (assertion tv)
  "[Cyc] Assumes that ASSERTION does not have any asserted arguments.
Creates a new asserted argument for ASSERTION with TV."
  (let ((new-asserted-argument (kb-create-asserted-argument-with-tv assertion tv)))
    (when new-asserted-argument
      (tms-postprocess-new-argument assertion new-asserted-argument))))

(defun tms-add-new-deduction (assertion supports tv)
  "[Cyc]"
  (let ((deduction (create-deduction-with-tv assertion supports tv)))
    (tms-postprocess-new-argument assertion deduction)
    deduction))

(defun tms-postprocess-new-argument (assertion argument)
  "[Cyc] Now that ARGUMENT for ASSERTION has been added to the KB,
perform necessary truth maintenance.  ARGUMENT is assumed to be a new argument,
not a redundant already-existing one."
  (declare (type argument argument))
  (let ((successful? nil))
    (unwind-protect
         (progn
           (tms-recompute-assertion-tv assertion)
           (handle-after-addings argument assertion)
           (setf successful? t))
      (unless successful?
        (tms-remove-argument argument assertion))))
  argument)

(defun tms-remove-argument (argument assertion)
  "[Cyc] Remove ARGUMENT for ASSERTION from the KB and perform necessary truth maintenance.
Return T if the supported assertion was removed, or it was invalid, else NIL."
  (declare (type argument argument))
  (when (and (valid-argument argument)
             (not (tms-argument-being-removed? argument)))
    (let ((assertion-removed? nil))
      (tms-note-argument-being-removed (argument)
        (remove-argument argument assertion)
        (cond ((assertion-p assertion)
               (if (valid-assertion? assertion)
                   (setf assertion-removed? (tms-propagate-removed-argument argument assertion))
                   (setf assertion-removed? t)))
              ((hl-support-p assertion)
               (let ((kb-hl-support (find-kb-hl-support assertion)))
                 (if kb-hl-support
                     ;; missing-larkc 11075 (also 11076 in non-deduction branch of Java expansion):
                     ;; likely tms-remove-kb-hl-support, propagates removal of kb-hl-support
                     (setf assertion-removed? (missing-larkc 11075))
                     (setf assertion-removed? t))))))
      assertion-removed?)))

(defun tms-propagate-removed-argument (argument assertion)
  "[Cyc]"
  (let ((assertion-removed? nil))
    (with-kb-hl-support-rejustification
      (setf assertion-removed? (tms-recompute-assertion-tv assertion))
      (when (valid-assertion? assertion)
        (unwind-protect
             (if assertion-removed?
                 (tms-note-assertion-being-removed (assertion)
                   (handle-after-removings argument assertion))
                 (handle-after-removings argument assertion))
          (if assertion-removed?
              (when (valid-assertion assertion)
                (if (tms-assertion-being-removed? assertion)
                    (tms-remove-assertion-int-2 assertion)
                    (tms-remove-assertion-int assertion)))
              (when (and *check-for-circular-justs*
                         (not (some-belief-justification assertion)))
                (tms-remove-assertion assertion)
                (setf assertion-removed? t))))))
    assertion-removed?))

(defun tms-remove-assertion-list (assertions)
  "[Cyc] Remove each valid assertion in ASSERTIONS"
  (when assertions
    (tms-remove-nonempty-assertion-list assertions)))

(defun tms-remove-nonempty-assertion-list (assertions)
  "[Cyc] Remove each valid assertion in ASSERTIONS"
  (dolist (assertion assertions)
    (tms-remove-assertion assertion))
  nil)

(defun tms-remove-assertion (assertion)
  "[Cyc] Remove ASSERTION from the KB and do all necessary truth maintenance."
  (declare (type assertion assertion))
  (when (and (valid-assertion? assertion)
             (not (tms-assertion-being-removed? assertion)))
    (tms-remove-assertion-int assertion)))

(defun tms-remove-assertion-int (assertion)
  "[Cyc]"
  (with-kb-hl-support-rejustification
    (tms-note-assertion-being-removed (assertion)
      (let ((arguments (assertion-arguments assertion)))
        (if (null arguments)
            (tms-remove-assertion-int-2 assertion)
            (dolist (argument (assertion-arguments assertion))
              (tms-remove-argument argument assertion))))))
  nil)

(defun tms-remove-assertion-int-2 (assertion)
  "[Cyc] Remove ASSERTION from the KB."
  (declare (type assertion assertion))
  (remove-term-indices assertion)
  (remqueue-forward-assertion assertion)
  (when (rule-assertion? assertion)
    (clear-transformation-rule-statistics assertion))
  (unless (tou-assertion? assertion)
    (remove-assertion assertion)))

;; (defun tms-remove-deduction (deduction) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-change-asserted-argument-tv (assertion argument tv) ...) -- no body, commented declareFunction (3 0)

(defun tms-recompute-assertion-tv (assertion)
  "[Cyc] Recompute ASSERTION's tv and perform necessary truth maintenance.
Return T if ASSERTION should be removed, else NIL"
  (declare (type assertion assertion))
  (let ((changed? nil)
        (remove? nil))
    (if (not (assertion-has-arguments? assertion))
        (progn
          (tms-note-assertion-being-removed (assertion)
            (tms-remove-dependents assertion))
          (setf remove? t))
        (let ((old-tv (cyc-assertion-tv assertion))
              (new-tv (compute-assertion-tv assertion)))
          (cond (*bootstrapping-kb?*) ;; empty java body, ignored?
                ((eq old-tv new-tv)) ;; empty java body, ignored?
                ((eq (tv-truth old-tv) (tv-truth new-tv))
                 ;; missing-larkc 12462: likely assertions-interface:kb-set-assertion-strength
                 ;; or similar, updates the assertion's strength component of its TV
                 ;; when truth is the same but strength differs (e.g. monotonic vs default)
                 (missing-larkc 12462))
                (t
                 (tms-remove-dependents assertion)
                 (setf changed? t)))))
    (when changed?
      (perform-rewrite-of-propagation assertion)
      (when (eq (assertion-direction assertion) :forward)
        (queue-forward-assertion assertion)))
    remove?))

(defun tms-change-direction (assertion direction)
  "[Cyc] Change the DIRECTION of ASSERTION and queue forward propagation if required."
  (declare (type assertion assertion)
           (type direction direction))
  (kb-set-assertion-direction assertion direction)
  (when (eq direction :forward)
    (queue-forward-assertion assertion))
  assertion)

;; (defun tms-recompute-dependents (assertion) ...) -- no body, commented declareFunction (1 0)

(defun tms-remove-dependents (assertion)
  "[Cyc] Remove all the deductions depending on this ASSERTION."
  (declare (type assertion assertion))
  (dolist (dependent-deduction (assertion-dependents assertion))
    (when (valid-deduction? dependent-deduction)
      (let ((deduction-assertion (deduction-assertion dependent-deduction)))
        (tms-remove-argument dependent-deduction deduction-assertion))))
  assertion)

;; (defun tms-recompute-dependents-tv (assertion) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-recompute-deduction-tv (deduction) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-remove-mt-arguments (assertion &optional mt) ...) -- no body, commented declareFunction (1 1)
;; (defun tms-remove-deduction-for-assertion (assertion supports &optional truth) ...) -- no body, commented declareFunction (2 1)

(defun tms-add-deduction-for-assertion (assertion supports &optional (truth :true))
  "[Cyc] Return 0 NIL or deduction-p; 1 booleanp, whether the deduction is redundant"
  (if (tms-direct-circularity assertion supports)
      (values nil t)
      (let ((existing (find-deduction assertion supports truth)))
        (if existing
            (values existing t)
            (let* ((tv (compute-supports-tv supports truth))
                   (new-argument (tms-add-new-deduction assertion supports tv)))
              (values new-argument nil))))))

(defun tms-add-deduction-for-cnf (cnf mt supports &optional (truth :true) (direction :backward) (var-names nil))
  "[Cyc]"
  (let ((assertion (find-or-create-assertion cnf mt var-names direction)))
    (tms-add-deduction-for-assertion assertion supports truth)))

(defun tms-direct-circularity (assertion supports)
  "[Cyc] Return T iff SUPPORTS for ASSERTION include a direct circularity"
  (declare (type assertion assertion))
  (member assertion supports))

;; (defun tms-directly-circular-deduction (deduction) ...) -- no body, commented declareFunction (1 0)
;; (defun atomic-cnf-trivially-derivable (cnf mt) ...) -- no body, commented declareFunction (2 0)
;; (defun gaf-trivially-derivable (gaf mt truth) ...) -- no body, commented declareFunction (3 0)
;; (defun true-gaf-trivially-derivable (gaf mt) ...) -- no body, commented declareFunction (2 0)
;; (defun false-gaf-trivially-derivable (gaf mt) ...) -- no body, commented declareFunction (2 0)
;; (defun tms-reconsider-assertion-deductions (assertion) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-reconsider-assertion-dependents (assertion) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-reconsider-deduction (deduction) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-deduction-stale-wrt-supports? (deduction) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-deduction-stale-wrt-exceptions? (deduction) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-reprove-deduction-query-sentence (deduction) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-reprove-deduction-query-mt (deduction) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-reprove-deduction-query-properties (arg1 arg2 arg3 arg4 arg5) ...) -- no body, commented declareFunction (5 0)
;; (defun tms-reconsider-assertion (assertion) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-reconsider-mt (mt) ...) -- no body, commented declareFunction (1 0)
;; (defun tms-reconsider-term-gafs (term &optional mt) ...) -- no body, commented declareFunction (1 1)
;; (defun tms-reconsider-predicate-extent (pred &optional mt) ...) -- no body, commented declareFunction (1 1)
;; (defun tms-reconsider-gaf-args (pred arg &optional argnum mt) ...) -- no body, commented declareFunction (2 2)
;; (defun tms-reconsider-term (term &optional mt) ...) -- no body, commented declareFunction (1 1)
;; (defun tms-reconsider-all-assertions () ...) -- no body, commented declareFunction (0 0)
;; (defun stale-support (support) ...) -- no body, commented declareFunction (1 0)
;; (defun stale-support-mt? (support mt) ...) -- no body, commented declareFunction (2 0)
;; (defun support-mt-ok? (support mt) ...) -- no body, commented declareFunction (2 0)
;; (defun assertion-asserted-more-specifically-deductions (assertion) ...) -- no body, commented declareFunction (1 0)
;; (defun remove-circularly-supported-assertions (&optional stream) ...) -- no body, commented declareFunction (0 1)
;; (defun remove-if-circularly-supported-assertion (assertion &optional stream) ...) -- no body, commented declareFunction (1 1)
;; (defun independently-deducible-assertion? (assertion) ...) -- no body, commented declareFunction (1 0)

(defun some-belief-justification (assertion &optional (asserted-assertions-to-ignore nil))
  "[Cyc]"
  (declare (type assertion assertion))
  (cond ((and (asserted-assertion? assertion)
              (not (member-eq? assertion asserted-assertions-to-ignore)))
         t)
        ((null (assertion-arguments assertion))
         nil)
        (t
         (let ((*circular-deductions* nil)
               (*circular-assertions* nil)
               (*circular-local-assertions* nil)
               (*circular-target-assertion* assertion)
               (*circular-complexity-count* 0))
           (catch :just-found
             (dolist (argument (assertion-arguments assertion))
               (when (deduction-p argument)
                 (gather-circular-deduction argument asserted-assertions-to-ignore)))
             (dolist (supported-assertion *circular-assertions*)
               (when (and (asserted-assertion? supported-assertion)
                          (not (member-eq? supported-assertion asserted-assertions-to-ignore)))
                 (mark-circular-assertion supported-assertion)))
             nil)))))

(defun inc-circular-complexity-count ()
  "[Cyc]"
  (incf *circular-complexity-count*)
  (when *circular-complexity-count-limit*
    (when (> *circular-complexity-count* *circular-complexity-count-limit*)
      (throw :just-found t)))
  nil)

(defun gather-circular-deduction (deduction asserted-assertions-to-ignore)
  "[Cyc]"
  (unless (member? deduction *circular-deductions*)
    (push deduction *circular-deductions*)
    (inc-circular-complexity-count)
    (dolist (assertion (deduction-supports deduction))
      (when (assertion-p assertion)
        (push assertion *circular-assertions*)
        (inc-circular-complexity-count)
        (unless (and (asserted-assertion? assertion)
                     (not (member-eq? assertion asserted-assertions-to-ignore)))
          (dolist (argument (assertion-arguments assertion))
            (when (deduction-p argument)
              (gather-circular-deduction argument asserted-assertions-to-ignore)))))))
  nil)

(defun mark-circular-assertion (assertion)
  "[Cyc]"
  (when (eq assertion *circular-target-assertion*)
    (throw :just-found t))
  (unless (member? assertion *circular-local-assertions*)
    (push assertion *circular-local-assertions*)
    (dolist (deduction (circular-deductions-with-assertion assertion))
      (when (believed-circular-deduction deduction)
        (mark-circular-assertion (deduction-assertion deduction)))))
  nil)

(defun circular-deductions-with-assertion (assertion)
  "[Cyc]"
  (let ((ans nil))
    (dolist (deduction *circular-deductions*)
      (when (member? assertion (deduction-supports deduction))
        (push deduction ans)))
    (nreverse ans)))

(defun believed-circular-deduction (deduction)
  "[Cyc]"
  (let ((ans nil))
    (do* ((rest (deduction-supports deduction) (rest rest)))
         ((or ans (null rest)))
      (let ((support (first rest)))
        (when (assertion-p support)
          (unless (member? support *circular-local-assertions*)
            (setf ans t)))))
    (not ans)))
