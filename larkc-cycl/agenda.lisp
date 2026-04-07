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

(defglobal *agenda-should-quit* nil)
(defglobal *restart-agenda-flag* nil)
(defparameter *within-agenda* nil)
(deflexical *default-agenda-package* (find-package "CYC"))
(defparameter *agenda-resourcing-spaces* 10
  "[Cyc] The number of SBHL spaces to resource within an agenda process")
(defglobal *agenda-process* nil)
(deflexical *agenda-process-lock* (bt:make-lock "Agenda Process Lock"))
(deflexical *agenda-error-modes* '(:ignore :halt :debug :log))
(defglobal *agenda-error-mode* :halt)
(defvar *agenda-log-file* nil
  "[Cyc] The file used to log agenda errors when the agenda is in log mode.")
(defglobal *agenda-action-table* nil)
(deflexical *agenda-action-table-lock* (bt:make-lock "Agenda Action Table Lock")
  "[Cyc] A lock to control access to *agenda-action-table*.")
(deflexical *transcript-queue-worry-size* 20)
(deflexical *save-transcript-quantum* 60)
(defglobal *next-save-transcript-time* (get-universal-time))
(deflexical *worry-transmit-quantum* 600)
(deflexical *worry-transmit-size* 1000)
(defglobal *next-worry-transmit-time* (get-universal-time))
(deflexical *normal-transmit-quantum* 120)
(defglobal *next-normal-transmit-time* (get-universal-time))
(deflexical *load-transcript-quantum* 120)
(defglobal *next-load-transcript-time* (get-universal-time))
(deflexical *save-recent-experience?* t
  "[Cyc] Whether to save recent experience into an experience transcript.")
(deflexical *save-experience-transcript-quantum* 600
  "[Cyc] 10 minutes")
(defglobal *next-save-experience-transcript-time* (get-universal-time))
(deflexical *save-asked-queries-transcript-quantum* 60
  "[Cyc] 1 minute")
(defglobal *next-save-asked-queries-transcript-time* (get-universal-time))
(deflexical *agenda-daily-gc-lock* (bt:make-lock "Agenda Daily GC"))
(defglobal *agenda-daily-gc-enabled* nil
  "[Cyc] Do we perform a complete, daily once-a-day GC in the Cyc Agenda?")
(defglobal *agenda-daily-gc-time-of-day* '(4 0 0)
  "[Cyc] Local time in form of (HH MM SS) at which a daily (gc) by the agenda is invoked.")
(defglobal *next-agenda-daily-gc-time* nil)



;;; Functions — ordered by declare_agenda_file

(defun initialize-agenda ()
  "[Cyc] Initialize the agenda."
  (set-communication-mode *startup-communication-mode*)
  (when (and *start-agenda-at-startup?*
             (not (agenda-running)))
    (start-agenda 10))
  t)

;; (defun within-agenda () ...) -- active declareFunction, no body
;; (defun agenda-form-to-show () ...) -- active declareFunction, no body

(defun agenda-top-level ()
  (start-agenda-process)
  (when (current-process-is-agenda)
    (unwind-protect
        (progn
          (agenda-startup-actions)
          (setf *restart-agenda-flag* nil)
          (let ((*package* *default-agenda-package*))
            (let* ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*)
                   (*resourced-sbhl-marking-space-limit*
                     (determine-resource-limit already-resourcing-p
                                               *agenda-resourcing-spaces*))
                   (*resourced-sbhl-marking-spaces*
                     (possibly-new-marking-resource already-resourcing-p))
                   (*resourcing-sbhl-marking-spaces-p* t))
              (loop until *agenda-should-quit*
                    do (loop while (and (not *agenda-should-quit*)
                                        (agenda-work-to-do))
                             do (perform-one-agenda-action))
                       ;; Wait if there is nothing to do
                       (process-wait "Idle" #'agenda-work-to-do)))))
      (clear-agenda-process)))
  nil)

(defun start-agenda (&optional wait?)
  (when (agenda-running)
    ;; missing-larkc 31524 — likely signals an error that the agenda is already running
    (missing-larkc 31524))
  (setf *agenda-should-quit* nil)
  (bt:make-thread #'agenda-top-level :name "Cyc Agenda")
  (when wait?
    (wait-for-agenda-running wait?))
  (agenda-running))

;; (defun restart-agenda (&optional wait?) ...) -- active declareFunction, no body

(defun halt-agenda (&optional wait?)
  (setf *agenda-should-quit* t)
  (bt:condition-notify *process-wait-cv*)
  (when (agenda-running)
    (when wait?
      (wait-for-agenda-not-running wait?)))
  nil)

;; (defun abort-agenda () ...) -- active declareFunction, no body
;; (defun abort-and-restart-agenda () ...) -- active declareFunction, no body

(defun wait-for-agenda-running (&optional (wait-time 1))
  (process-wait-with-timeout wait-time "Waiting for agenda" #'agenda-running)
  (agenda-running))

(defun wait-for-agenda-not-running (&optional (wait-time 1))
  "[Cyc] Waits until the adding assertions stopps running"
  (process-wait-with-timeout wait-time "Waiting for agenda stop"
                             (lambda () (not (agenda-running))))
  (not (agenda-running)))

;; (defun ensure-agenda-running () ...) -- active declareFunction, no body

(defun agenda-process ()
  *agenda-process*)

(defun agenda-running ()
  (let ((proc (agenda-process)))
    (and proc (bt:thread-alive-p proc))))

;; (defun agenda-state () ...) -- active declareFunction, no body

(defun current-process-is-agenda ()
  (eq (bt:current-thread) (agenda-process)))

;; (defun agenda-idle? () ...) -- active declareFunction, no body
;; (defun agenda-busy? () ...) -- active declareFunction, no body

(defun start-agenda-process ()
  (bt:with-lock-held (*agenda-process-lock*)
    (unless *agenda-process*
      (setf *agenda-process* (bt:current-thread))))
  (bt:condition-notify *process-wait-cv*)
  nil)

(defun clear-agenda-process ()
  (bt:with-lock-held (*agenda-process-lock*)
    (setf *agenda-process* nil))
  (bt:condition-notify *process-wait-cv*)
  nil)

;; (defun agenda-error-modes () ...) -- active declareFunction, no body
;; (defun agenda-error-mode () ...) -- active declareFunction, no body
;; (defun set-agenda-error-mode (mode) ...) -- active declareFunction, no body
;; (defun agenda-logs-errors? () ...) -- active declareFunction, no body
;; (defun set-agenda-log-file (file) ...) -- active declareFunction, no body
;; (defun get-agenda-log-file () ...) -- active declareFunction, no body

(defun agenda-startup-actions ()
  "[Cyc] Code which is run whenever the agenda is restarted"
  (unless (local-transcript)
    (new-local-transcript))
  (unless (master-transcript)
    (set-master-transcript))
  nil)

(defun agenda-work-to-do ()
  "[Cyc] Returns NIL iff there is no agenda work to do"
  (dolist (agenda-task (agenda-tasks))
    (let ((test (agenda-task-test agenda-task)))
      (when (and (fboundp test) (funcall test))
        (let ((action (agenda-task-action agenda-task)))
          (when (fboundp action)
            (return agenda-task)))))))

(defun clear-agenda-halt-explanation ()
  "[Cyc] Sets Agenda error messages and explanations to nil"
  (setf *last-agenda-error-message* nil)
  (setf *last-agenda-error-explanatory-supports* nil)
  nil)

(defun perform-one-agenda-action ()
  "[Cyc] Performs one agenda action"
  (clear-agenda-halt-explanation)
  (let ((agenda-task (agenda-work-to-do)))
    (when agenda-task
      (let ((action (agenda-task-action agenda-task)))
        (let ((*within-agenda* t))
          (funcall action))))
    agenda-task))

(defun declare-agenda-task (test action priority)
  "[Cyc] Declare an agenda task which does ACTION whenever TEST is true. The task
priority is PRIORITY, larger numbers indicate lesser priority. TEST and ACTION
are functions of no arguments."
  (declare (type symbol test action)
           (type number priority))
  (undeclare-agenda-task test)
  (bt:with-lock-held (*agenda-action-table-lock*)
    (setf *agenda-action-table*
          (splice-into-sorted-list (list test action priority)
                                   *agenda-action-table*
                                   #'<
                                   #'agenda-task-priority)))
  test)

(defun undeclare-agenda-task (test)
  "[Cyc] UNDECLARE the agenda task associated with TEST."
  (bt:with-lock-held (*agenda-action-table-lock*)
    (setf *agenda-action-table*
          (delete test *agenda-action-table* :test #'eql :key #'first)))
  test)

(defun agenda-tasks ()
  *agenda-action-table*)

(defun agenda-task-test (agenda-task)
  (first agenda-task))

(defun agenda-task-action (agenda-task)
  (second agenda-task))

(defun agenda-task-priority (agenda-task)
  (third agenda-task))

(defun agenda-should-quit? ()
  *agenda-should-quit*)

;; (defun do-nothing () ...) -- active declareFunction, no body

(defun restart-agenda-flag? ()
  *restart-agenda-flag*)

(defun save-operations? ()
  (and (saving-operations?)
       (or (and (>= (get-universal-time) *next-save-transcript-time*)
                (not (transcript-queue-empty))
                (local-queue-empty))
           (> (transcript-queue-size) *transcript-queue-worry-size*))))

(defun save-local-operations ()
  (setf *next-save-transcript-time*
        (time-from-now (+ *save-transcript-quantum* (random 20))))
  (save-transcript-ops)
  nil)

(defun worry-transmit-operations? ()
  (and (allow-transmitting)
       (or (and (>= (get-universal-time) *next-worry-transmit-time*)
                (not (transmit-queue-empty)))
           (>= (transmit-queue-size) *worry-transmit-size*))))

;; (defun worry-transmit-operations () ...) -- active declareFunction, no body

(defun run-auxiliary-op? ()
  (and (process-auxiliary-operations?)
       (not (auxiliary-queue-empty))))

;; (defun run-one-auxiliary-op-in-agenda () ...) -- active declareFunction, no body
;; (defun run-one-non-local-op-in-agenda (op) ...) -- active declareFunction, no body
;; (defun handle-agenda-fi-error-state () ...) -- active declareFunction, no body

(defun run-local-op? ()
  (and (process-local-operations?)
       (not (local-queue-empty))))

;; (defun run-one-local-op-in-agenda () ...) -- active declareFunction, no body
;; (defun agenda-throw-error-message () ...) -- active declareFunction, no body
;; (defun log-agenda-error (error) ...) -- active declareFunction, no body
;; (defun timestamp-operation-p (operation) ...) -- active declareFunction, no body
;; (defun construct-generic-timestamp-operation () ...) -- active declareFunction, no body

(defun normal-transmit-operations? ()
  (and (>= (get-universal-time) *next-normal-transmit-time*)
       (not (transmit-queue-empty))
       (allow-transmitting)
       (local-queue-empty)
       (transcript-queue-empty)))

;; (defun normal-transmit-operations () ...) -- active declareFunction, no body

(defun run-remote-op? ()
  (remote-operation-to-run?))

;; (defun run-one-remote-op-in-agenda () ...) -- active declareFunction, no body

(defun load-operations? ()
  (and (receiving-remote-operations?)
       (>= (get-universal-time) *next-load-transcript-time*)))

;; (defun load-remote-operations () ...) -- active declareFunction, no body

(defun save-experience? ()
  (and *save-recent-experience?*
       (>= (get-universal-time) *next-save-experience-transcript-time*)))

(defun save-local-experience ()
  (setf *next-save-experience-transcript-time*
        (time-from-now *save-experience-transcript-quantum*))
  (possibly-save-recent-experience))

(defun agenda-save-asked-queries? ()
  (and (save-asked-queries?)
       (>= (get-universal-time) *next-save-asked-queries-transcript-time*)))

;; (defun save-local-asked-queries () ...) -- active declareFunction, no body
;; (defun enable-agenda-daily-gc (hour minute second) ...) -- active declareFunction, no body
;; (defun disable-agenda-daily-gc () ...) -- active declareFunction, no body

(defun agenda-daily-gc-ready-p ()
  (and *agenda-daily-gc-enabled*
       *next-agenda-daily-gc-time*
       (>= (get-universal-time) *next-agenda-daily-gc-time*)))

;; (defun do-agenda-daily-gc () ...) -- active declareFunction, no body
;; (defun set-next-agenda-daily-gc-time () ...) -- active declareFunction, no body
;; (defun update-agenda-daily-gc-time () ...) -- active declareFunction, no body


;;; Setup phase

(declare-defglobal '*agenda-should-quit*)
(declare-defglobal '*restart-agenda-flag*)
(declare-defglobal '*agenda-process*)
(register-external-symbol 'agenda-running)
(declare-defglobal '*agenda-error-mode*)
(declare-defglobal '*agenda-action-table*)

(toplevel
  (declare-agenda-task 'agenda-should-quit? 'do-nothing 0)
  (declare-agenda-task 'restart-agenda-flag? 'do-nothing 0))

(declare-defglobal '*next-save-transcript-time*)

(toplevel
  (declare-agenda-task 'save-operations? 'save-local-operations 10))

(declare-defglobal '*next-worry-transmit-time*)

(toplevel
  (declare-agenda-task 'worry-transmit-operations? 'worry-transmit-operations 15)
  (declare-agenda-task 'run-auxiliary-op? 'run-one-auxiliary-op-in-agenda 20)
  (declare-agenda-task 'run-local-op? 'run-one-local-op-in-agenda 25))

(declare-defglobal '*next-normal-transmit-time*)

(toplevel
  (declare-agenda-task 'normal-transmit-operations? 'normal-transmit-operations 35)
  (declare-agenda-task 'run-remote-op? 'run-one-remote-op-in-agenda 40))

(declare-defglobal '*next-load-transcript-time*)

(toplevel
  (declare-agenda-task 'load-operations? 'load-remote-operations 45))

(declare-defglobal '*next-save-experience-transcript-time*)

(toplevel
  (declare-agenda-task 'save-experience? 'save-local-experience 60))

(declare-defglobal '*next-save-asked-queries-transcript-time*)

(toplevel
  (declare-agenda-task 'agenda-save-asked-queries? 'save-local-asked-queries 30))

(declare-defglobal '*agenda-daily-gc-enabled*)
(declare-defglobal '*agenda-daily-gc-time-of-day*)
(declare-defglobal '*next-agenda-daily-gc-time*)

(toplevel
  (declare-agenda-task 'agenda-daily-gc-ready-p 'do-agenda-daily-gc 1000))
