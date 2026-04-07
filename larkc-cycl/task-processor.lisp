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


;;;; Structures

(defstruct (task-info (:conc-name "ti-")
                      (:constructor make-task-info (&key type id priority requestor
                                                        giveback-info bindings request
                                                        response error-message
                                                        task-processor-name)))
  type
  id
  priority
  requestor
  giveback-info
  bindings
  request
  response
  error-message
  task-processor-name)

(defstruct (task-result-set (:conc-name "task-result-set-")
                            (:constructor make-task-result-set (&key result task-info finished)))
  result
  task-info
  finished)

(defstruct (task-processor (:conc-name "tproc-")
                           (:constructor make-task-processor (&key name process busy-p task-info)))
  name
  process
  busy-p
  task-info)

(defstruct (task-process-pool (:conc-name "tpool-")
                              (:constructor make-task-process-pool
                                  (&key lock request-queue request-semaphore
                                        processors background-msgs process-name-prefix
                                        min-nbr-of-task-processors max-nbr-of-task-processors)))
  lock
  request-queue
  request-semaphore
  processors
  background-msgs
  process-name-prefix
  min-nbr-of-task-processors
  max-nbr-of-task-processors)


;;;; Variables

(defparameter *task-processor-verbosity* 0
  "[Cyc] Diagnostic verbosity level of the task processor, 0=quiet, 9=maximum.")

(deflexical *task-processor-response-dispatch-fn-dict* nil
  "[Cyc] Dictionary of task-processor-type --> response dispatch function.")

(defconstant *task-request-queue-max-size* 500)

(deflexical *tpool-background-msg-path* nil
  "[Cyc] The optional file path for the task processor pool background messages.")

(deflexical *tpool-background-msg-stream* nil
  "[Cyc] The stream for the task processor pool background messages.")

(deflexical *tpool-background-msg-lock* nil
  "[Cyc] The lock used to serialize access for the task processor pool background messages.")

(defparameter *eval-with-bindings* nil
  "[Cyc] Result of eval-with-bindings function call.")

(deflexical *process-to-task-process-pool* (new-synchronized-dictionary)
  "[Cyc] Associates a process with its parent task-process-pool object.")

(deflexical *task-processes-being-worked-on-lock* (bt:make-lock "Task processes being worked on"))

(deflexical *task-processes-being-worked-on* nil
  "[Cyc] LRU Cache of task-process-descriptions -> process objects.
This is used to support task suspensions.")

(defparameter *task-processes-worked-on-history* 500
  "[Cyc] How many task processes we remember the cancellation of.")

(deflexical *task-processor-eval-fn-dict* nil
  "[Cyc] Dictionary of task-processor-type --> evaluation function.
The evaluation function is CYC-API-EVAL for API requests,
and could be EVAL for other task processor usage.")

(defparameter *minimize-task-processor-info-communication* t
  "[Cyc] If set to T, dont send the request back; if set to NIL, send the request back.")

(defparameter *current-task-processor-info* nil
  "[Cyc] Contains the current task processor info block that is being handled.")

(defparameter *task-processor-standard-output* *standard-output*
  "[Cyc] the standard output stream for debugging within a task-processor-request")

(defconstant *min-nbr-of-task-processors* 5
  "[Cyc] the default minimum number of task processors")

(defconstant *max-nbr-of-task-processors* 25
  "[Cyc] the default maximum number of task processors")

(deflexical *api-task-process-pool* nil
  "[Cyc] Task process pool for requests.")

(defconstant *api-task-process-pool-lock* (bt:make-lock "task processor initialization lock")
  "[Cyc] Task process pool lock to guarantee only a single instance is initialized.")

(deflexical *java-api-lease-activity-display* nil
  "[Cyc] indicates that lease renewal requests should be displayed on the console.")

(deflexical *bg-task-process-pool* nil
  "[Cyc] Task process pool for requests.")

(defconstant *bg-task-process-pool-lock* (bt:make-lock "task processor initialization lock")
  "[Cyc] Task process pool lock to guarantee only a single instance is initialized.")

(deflexical *bg-task-processor-response-dict* nil
  "[Cyc] Dictionary of requestor-process --> response task-info.")

(deflexical *bg-task-processor-request-id* 0
  "[Cyc] Serial number of background task processor requests.")

(deflexical *console-task-process-pool* nil
  "[Cyc] Task process pool for requests.")

(defconstant *console-task-process-pool-lock* (bt:make-lock "task processor initialization lock")
  "[Cyc] Task process pool lock to guarantee only a single instance is initialized.")

(deflexical *task-processor-console-id*
  (if (and (boundp '*task-processor-console-id*) (integerp *task-processor-console-id*))
      *task-processor-console-id*
      0)
  "[Cyc] Id (serial number) assigned to console task processing requests.")


;;;; Functions

(defun get-task-processor-verbosity ()
  "[Cyc] Return the task processor verbosity level."
  *task-processor-verbosity*)

;; (defun set-task-processor-verbosity (verbosity) ...) -- active declareFunction, no body

(defun set-task-info-type (type task-info)
  "[Cyc] Sets the TYPE of TASK-INFO."
  (declare (type symbol type)
           (type task-info task-info))
  (setf (ti-type task-info) type)
  nil)

(defun get-task-info-id (task-info)
  "[Cyc] Return the id of TASK-INFO."
  (declare (type task-info task-info))
  (ti-id task-info))

(defun set-task-info-id (id task-info)
  "[Cyc] Sets the ID of TASK-INFO."
  (declare (type integer id)
           (type task-info task-info))
  (setf (ti-id task-info) id)
  nil)

(defun get-task-info-priority (task-info)
  "[Cyc] Return the priority of TASK-INFO."
  (declare (type task-info task-info))
  (ti-priority task-info))

(defun set-task-info-priority (priority task-info)
  "[Cyc] Sets the PRIORITY of TASK-INFO."
  (declare (type integer priority)
           (type task-info task-info))
  (setf (ti-priority task-info) priority)
  nil)

(defun get-task-info-requestor (task-info)
  "[Cyc] Return the requestor of TASK-INFO."
  (declare (type task-info task-info))
  (ti-requestor task-info))

(defun set-task-info-requestor (requestor task-info)
  "[Cyc] Sets the REQUESTOR of TASK-INFO."
  (declare (type string requestor)
           (type task-info task-info))
  (setf (ti-requestor task-info) requestor)
  nil)

(defun get-task-info-giveback-info (task-info)
  "[Cyc] Return the giveback-info of TASK-INFO."
  (declare (type task-info task-info))
  (ti-giveback-info task-info))

(defun set-task-info-giveback-info (giveback-info task-info)
  "[Cyc] Sets the GIVEBACK-INFO of TASK-INFO."
  (declare (type task-info task-info))
  (setf (ti-giveback-info task-info) giveback-info)
  nil)

;; (defun get-task-info-bindings (task-info) ...) -- active declareFunction, no body

(defun set-task-info-bindings (bindings task-info)
  "[Cyc] Sets the BINDINGS of TASK-INFO."
  (declare (type task-info task-info))
  (setf (ti-bindings task-info) bindings)
  nil)

(defun get-task-info-request (task-info)
  "[Cyc] Return the request of TASK-INFO."
  (declare (type task-info task-info))
  (ti-request task-info))

(defun set-task-info-request (request task-info)
  "[Cyc] Sets the REQUEST of TASK-INFO."
  (declare (type task-info task-info))
  (setf (ti-request task-info) request)
  nil)

(defun get-task-info-response (task-info)
  "[Cyc] Return the response of TASK-INFO."
  (declare (type task-info task-info))
  (ti-response task-info))

;; (defun set-task-info-response (response task-info) ...) -- active declareFunction, no body

(defun get-task-info-error-message (task-info)
  "[Cyc] Return the error-message of TASK-INFO."
  (declare (type task-info task-info))
  (ti-error-message task-info))

;; (defun set-task-info-error-message (error-message task-info) ...) -- active declareFunction, no body
;; (defun get-task-info-task-processor-name (task-info) ...) -- active declareFunction, no body
;; (defun set-task-info-task-processor-name (task-processor-name task-info) ...) -- active declareFunction, no body
;; (defun print-task-info (object stream depth) ...) -- active declareFunction, no body

(defun new-task-result-set (result task-info finished)
  (make-task-result-set :result result :task-info task-info :finished finished))

;; (defun task-result-set-priority (task-result-set) ...) -- active declareFunction, no body
;; (defun print-task-processor (object stream depth) ...) -- active declareFunction, no body
;; (defun print-task-process-pool (object stream depth) ...) -- active declareFunction, no body
;; (defun display-task-processors (task-process-pool &optional stream) ...) -- active declareFunction, no body
;; (defun display-active-task-processes (&optional task-process-pool) ...) -- active declareFunction, no body

(defun task-processors-initialized-p (task-process-pool)
  "[Cyc] Return T when there are task processors."
  (when (task-process-pool-p task-process-pool)
    (listp (tpool-processors task-process-pool))))

(defun get-tpool-lock (task-process-pool)
  "[Cyc] Return the task process pool lock object."
  (declare (type task-process-pool task-process-pool))
  (tpool-lock task-process-pool))

(defun set-tpool-lock (lock task-process-pool)
  "[Cyc] Sets the LOCK for TASK-PROCESS-POOL."
  (declare (type task-process-pool task-process-pool))
  (setf (tpool-lock task-process-pool) lock)
  nil)

;; (defun get-tpool-request-queue (task-process-pool) ...) -- active declareFunction, no body

(defun set-tpool-request-queue (request-queue task-process-pool)
  "[Cyc] Sets the REQUEST-QUEUE for TASK-PROCESS-POOL."
  (declare (type task-process-pool task-process-pool))
  (setf (tpool-request-queue task-process-pool) request-queue)
  nil)

;; (defun get-tpool-processors (task-process-pool) ...) -- active declareFunction, no body
;; (defun get-tpool-processors-nbr (task-process-pool) ...) -- active declareFunction, no body

(defun push-tpool-processor (v-task-processor task-process-pool)
  "[Cyc] Pushes the TASK-PROCESSOR onto the list of task processors for TASK-PROCESS-POOL."
  (declare (type task-processor v-task-processor)
           (type task-process-pool task-process-pool))
  (setf (tpool-processors task-process-pool)
        (cons v-task-processor (tpool-processors task-process-pool)))
  nil)

;; (defun set-tpool-processors (processors task-process-pool) ...) -- active declareFunction, no body
;; (defun set-tpool-background-msg-path (path) ...) -- active declareFunction, no body

(defun push-tpool-background-msg (msg task-process-pool)
  "[Cyc] Pushes a diagnostic MSG on the background message list for TASK-PROCESS-POOL, or if
a filepath is present, then the the message is output to the file stream."
  (declare (type string msg))
  (when (null *tpool-background-msg-lock*)
    (setf *tpool-background-msg-lock* (bt:make-lock "tpool-background-msg-lock")))
  (bt:with-lock-held (*tpool-background-msg-lock*)
    (if *tpool-background-msg-path*
        (progn
          (assert (stringp *tpool-background-msg-path*) ()
                  "~A is not a valid file specification" *tpool-background-msg-path*)
          (when (null *tpool-background-msg-stream*)
            (setf *tpool-background-msg-stream*
                  (open *tpool-background-msg-path*
                        :direction :output
                        :if-does-not-exist :create
                        :if-exists :overwrite)))
          (princ "[" *tpool-background-msg-stream*)
          (princ (bt:thread-name (bt:current-thread)) *tpool-background-msg-stream*)
          (princ "]" *tpool-background-msg-stream*)
          (terpri *tpool-background-msg-stream*)
          (princ "  " *tpool-background-msg-stream*)
          (princ msg *tpool-background-msg-stream*)
          (terpri *tpool-background-msg-stream*)
          (force-output *tpool-background-msg-stream*))
        (when task-process-pool
          (setf (tpool-background-msgs task-process-pool)
                (cons (concatenate 'string (timestring) " " msg)
                      (tpool-background-msgs task-process-pool))))))
  nil)

;; (defun show-tp-msgs (task-process-pool) ...) -- active declareFunction, no body
;; (defun show-tp-msgs-with-process-name (task-process-pool) ...) -- active declareFunction, no body

(defun set-tpool-process-name-prefix (process-name-prefix task-process-pool)
  "[Cyc] Sets the PROCESS-NAME-PREFIX for processes in TASK-PROCESS-POOL."
  (declare (type string process-name-prefix)
           (type task-process-pool task-process-pool))
  (setf (tpool-process-name-prefix task-process-pool) process-name-prefix)
  nil)

(defun get-tpool-process-name-prefix (task-process-pool)
  "[Cyc] Return the process name prefix for processes in TASK-PROCESS-POOL."
  (declare (type task-process-pool task-process-pool))
  (tpool-process-name-prefix task-process-pool))

(defun set-tpool-min-nbr-of-task-processors (min-nbr-of-task-processors task-process-pool)
  "[Cyc] Sets the MIN-NBR-OF-TASK-PROCESSORS in TASK-PROCESS-POOL."
  (declare (type integer min-nbr-of-task-processors)
           (type task-process-pool task-process-pool))
  (setf (tpool-min-nbr-of-task-processors task-process-pool) min-nbr-of-task-processors)
  nil)

;; (defun get-tpool-min-nbr-of-task-processors (task-process-pool) ...) -- active declareFunction, no body

(defun set-tpool-max-nbr-of-task-processors (max-nbr-of-task-processors task-process-pool)
  "[Cyc] Sets the MAX-NBR-OF-TASK-PROCESSORS in TASK-PROCESS-POOL."
  (declare (type integer max-nbr-of-task-processors)
           (type task-process-pool task-process-pool))
  (setf (tpool-max-nbr-of-task-processors task-process-pool) max-nbr-of-task-processors)
  nil)

(defun get-tpool-max-nbr-of-task-processors (task-process-pool)
  "[Cyc] Return the maximum number of task processors in TASK-PROCESS-POOL."
  (declare (type task-process-pool task-process-pool))
  (tpool-max-nbr-of-task-processors task-process-pool))

(defun get-nbr-of-task-processors (task-process-pool)
  "[Cyc] Return the number of processes in TASK-PROCESS-POOL."
  (length (tpool-processors task-process-pool)))

(defun eval-with-bindings (bindings form eval-fn)
  "[Cyc] Using EVAL-FN, evaluates FORM within the scope of specified variable BINDINGS."
  (let ((*eval-with-bindings* nil))
    (let ((form-to-eval `(let ,bindings (setf *eval-with-bindings* ,form))))
      (cond ((eq eval-fn #'cyc-api-eval)
             (cyc-api-eval form-to-eval))
            ((eq eval-fn #'eval)
             (eval form-to-eval))
            (t (funcall eval-fn form-to-eval))))
    *eval-with-bindings*))

(defun get-task-process-pool-for-process (process)
  "[Cyc] Returns the task-process-pool parent of the given process, or NIL if not found."
  (synchronized-dictionary-lookup *process-to-task-process-pool* process))

(defun add-task-process-pool-for-process (process task-process-pool)
  "[Cyc] Adds the task-process-pool parent of the given process."
  (declare (type task-process-pool task-process-pool))
  (synchronized-dictionary-enter *process-to-task-process-pool* process task-process-pool))

;; (defun remove-task-process-pool-for-process (process) ...) -- active declareFunction, no body

(defun ensure-task-process-being-worked-on-initialized ()
  (bt:with-lock-held (*task-processes-being-worked-on-lock*)
    (when (not (cache-p *task-processes-being-worked-on*))
      (setf *task-processes-being-worked-on*
            (new-cache *task-processes-worked-on-history* #'equal))))
  *task-processes-being-worked-on*)

(defun compute-task-process-description-from-task-info (task-info)
  (compute-task-process-description (get-task-info-id task-info)
                                    (get-task-info-giveback-info task-info)))

(defun compute-task-process-description (task-id giveback-info)
  (cons task-id giveback-info))

;; (defun get-giveback-info-from-task-process-description (description) ...) -- active declareFunction, no body

(defun note-active-task-process-description-if-permitted (task-info)
  "[Cyc] Try to make this the active task, unless someone has already left us
a reason to stop NOW. Return the reason for not permitted."
  (let* ((signature (compute-task-process-description-from-task-info task-info))
         (process (bt:current-thread))
         (retval nil))
    (bt:with-lock-held (*task-processes-being-worked-on-lock*)
      (ensure-task-process-being-worked-on-initialized)
      (multiple-value-bind (reason-to-stop-now? found?)
          (cache-get *task-processes-being-worked-on* signature)
        (if (not found?)
            (cache-set *task-processes-being-worked-on* signature process)
            (setf retval reason-to-stop-now?))))
    retval))

(defun note-inactive-task-process-description (task-info)
  (let ((signature (compute-task-process-description-from-task-info task-info)))
    (bt:with-lock-held (*task-processes-being-worked-on-lock*)
      (when (cache-p *task-processes-being-worked-on*)
        (cache-remove *task-processes-being-worked-on* signature))))
  task-info)

;; (defun task-process-termination-reason-p (reason) ...) -- active declareFunction, no body
;; (defun terminate-active-task-process (giveback-info reason task-process-pool) ...) -- active declareFunction, no body

(defun terminate-active-task-processes (task-giveback-info)
  "[Cyc] Find all of the tasks that are currently running for the passed in task-giveback-info
and abort their processing tasks."
  (bt:with-lock-held (*task-processes-being-worked-on-lock*)
    (when (cache-p *task-processes-being-worked-on*)
      (let ((cache-var *task-processes-being-worked-on*))
        (do-cache (task-process-description process-handling-task cache-var :newest)
          ;; Likely extracts giveback-info from the task-process-description
          (let ((current-giveback-info (missing-larkc 31798)))
            (when (and (equal current-giveback-info task-giveback-info)
                       (bt:thread-alive-p process-handling-task))
              ;; Likely signals the task process to terminate via interrupt
              (handler-case (missing-larkc 31808)
                (error () nil))))))))
  task-giveback-info)

;; (defun signal-terminate-active-task-process (task-id giveback-info reason task-process-pool) ...) -- active declareFunction, no body
;; (defun signal-abort-active-task-process (task-id giveback-info) ...) -- active declareFunction, no body
;; (defun signal-cancel-active-task-process (task-id giveback-info) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list173 = (ANS-VAR &BODY BODY) — arglist
;; $sym174 = CCATCH, $kw172 = :TERMINATE-PREMATURELY
;; $sym178 = ANS-VAR (uninternedSymbol)
;; Expansion: catch :terminate-prematurely around body, result bound to ans-var
(defmacro catch-task-processor-termination (ans-var &body body)
  "[Cyc] Allow for the API calling side to catch the termination of the task processor.
   The client must wrap the api-request form with catch-task-processor-termination."
  `(setf ,ans-var (catch :terminate-prematurely (progn ,@body))))

;; Reconstructed from Internal Constants:
;; $list180 = (&BODY BODY) — arglist
;; Same catch but without capturing the thrown value
(defmacro catch-task-processor-termination-quietly (&body body)
  "[Cyc] Allow for the API calling side to catch the termination of the task processor
   without looking at the termination reason.
   The client must wrap the api-request form with catch-task-processor-termination-quietly."
  `(catch :terminate-prematurely ,@body))

;; (defun get-current-task-processor-info () ...) -- active declareFunction, no body
;; (defun get-current-task-processor-client () ...) -- active declareFunction, no body

(defun map-task-info-priority-to-process-priority (priority)
  ;; CL/SBCL doesn't support thread priorities. Clamp to valid range as in Java.
  (max 0 (min priority 9)))

(defun task-processor-handler ()
  "[Cyc] When awakened, repeatedly evaluate the highest priority request."
  ;; Wait for process→pool mapping to be established
  (let ((task-process-pool (get-task-process-pool-for-process (bt:current-thread))))
    (loop :while (null task-process-pool)
          :do (sleep 0.001)
              (setf task-process-pool (get-task-process-pool-for-process (bt:current-thread)))))
  (catch :task-processor-quit
    (let* ((task-process-pool (get-task-process-pool-for-process (bt:current-thread)))
           (v-task-processor (find-task-processor (bt:thread-name (bt:current-thread)) task-process-pool))
           (eval-fn nil)
           (task-info nil)
           (request nil)
           (response nil)
           (error-message nil))
      (assert (task-processor-p v-task-processor) () "Invalid task-processor")
      (assert (task-process-pool-p task-process-pool) () "Invalid task-process-pool")
      (loop
        (catch :terminate-prematurely
          (setf (tproc-busy-p v-task-processor) nil)
          (bt:wait-on-semaphore (tpool-request-semaphore task-process-pool))
          (bt:with-lock-held ((get-tpool-lock task-process-pool))
            (setf task-info (p-dequeue (tpool-request-queue task-process-pool))))
          (when (> *task-processor-verbosity* 2)
            (push-tpool-background-msg (format nil "Task Info ~S~%" task-info) task-process-pool))
          (setf request (ti-request task-info))
          (setf (ti-task-processor-name task-info) (tproc-name v-task-processor))
          (setf (tproc-task-info v-task-processor) task-info)
          (setf eval-fn (gethash (ti-type task-info) *task-processor-eval-fn-dict*))
          (unwind-protect
               (let ((*current-task-processor-info* task-info))
                 (let ((abort-reason (note-active-task-process-description-if-permitted task-info))
                       (priority (get-task-info-priority task-info)))
                   (declare (ignore priority))
                   ;; set-process-priority is a no-op in CL
                   (when (null abort-reason)
                     (setf abort-reason
                           (catch :terminate-prematurely
                             (let ((err nil))
                               (catch-error-message (err)
                                 (setf response (eval-with-bindings (ti-bindings task-info) request eval-fn)))
                               (setf error-message err))
                             nil))
                     (when abort-reason
                       (setf error-message abort-reason))
                     (when (> *task-processor-verbosity* 2)
                       (push-tpool-background-msg (format nil "Response ~S~%" response) task-process-pool)
                       (when (stringp error-message)
                         (push-tpool-background-msg (format nil "Error-message ~S~%" error-message) task-process-pool)))
                     (setf (ti-response task-info) response)
                     (unless (eq abort-reason :abort)
                       (setf (ti-error-message task-info) error-message))
                     (catch :terminate-prematurely
                       (dispatch-task-processor-response task-info t)))))
            (note-inactive-task-process-description task-info))))))
  nil)

;; (defun post-task-info-processor-partial-results (task-info) ...) -- active declareFunction, no body
;; (defun post-task-info-processor-partial-results-internal (task-info finished) ...) -- active declareFunction, no body

(defun initialize-task-processors (&optional (process-name-prefix "Task processor ")
                                             (min-nbr-of-task-processors *min-nbr-of-task-processors*)
                                             (max-nbr-of-task-processors *max-nbr-of-task-processors*))
  "[Cyc] Initialize the given minimum number of task processors."
  (declare (type integer min-nbr-of-task-processors max-nbr-of-task-processors)
           (type string process-name-prefix))
  (setf *task-processor-standard-output* *standard-output*)
  (let ((task-process-pool (make-task-process-pool)))
    (set-tpool-process-name-prefix process-name-prefix task-process-pool)
    (set-tpool-min-nbr-of-task-processors min-nbr-of-task-processors task-process-pool)
    (set-tpool-max-nbr-of-task-processors max-nbr-of-task-processors task-process-pool)
    (when (> *task-processor-verbosity* 2)
      (push-tpool-background-msg (format nil "Initializing task processors~%") task-process-pool))
    (set-tpool-lock (bt:make-lock (format nil "~alock" process-name-prefix)) task-process-pool)
    (setf (tpool-request-semaphore task-process-pool)
          (bt:make-semaphore :name "task-pool-request-semaphore" :count 0))
    (set-tpool-request-queue (create-p-queue *task-request-queue-max-size* #'ti-priority) task-process-pool)
    (dotimes (i min-nbr-of-task-processors)
      (add-new-task-processor-to-pool task-process-pool))
    task-process-pool))

(defun add-new-task-processor-to-pool (task-process-pool)
  "[Cyc] Add a new task processor for the given TASK-PROCESS-POOL."
  (declare (type task-process-pool task-process-pool))
  (let* ((v-task-processor (make-task-processor))
         (process-name-prefix (get-tpool-process-name-prefix task-process-pool))
         (nbr-of-task-processors (get-nbr-of-task-processors task-process-pool)))
    (setf (tproc-name v-task-processor)
          (format nil "~a~s" process-name-prefix (1+ nbr-of-task-processors)))
    (setf (tproc-process v-task-processor)
          (bt:make-thread #'task-processor-handler :name (tproc-name v-task-processor)))
    (push-tpool-processor v-task-processor task-process-pool)
    (add-task-process-pool-for-process (tproc-process v-task-processor) task-process-pool))
  nil)

;; (defun halt-task-processors (task-process-pool) ...) -- active declareFunction, no body
;; (defun halt-task-processor (task-processor) ...) -- active declareFunction, no body
;; (defun halt-task-processor-via-interrupt (task-processor) ...) -- active declareFunction, no body
;; (defun ensure-task-processors-killed (task-process-pool) ...) -- active declareFunction, no body
;; (defun task-processor-quit () ...) -- active declareFunction, no body

(defun find-task-processor (process-name task-process-pool)
  "[Cyc] Return the task processor in TASK-PROCESS-POOL having PROCESS-NAME.
Return NIL if not found."
  (declare (type string process-name)
           (type task-process-pool task-process-pool))
  (dolist (v-task-processor (tpool-processors task-process-pool))
    (when (string= process-name (tproc-name v-task-processor))
      (return-from find-task-processor v-task-processor)))
  nil)

;; (defun find-task-process-pool (type) ...) -- active declareFunction, no body

(defun awaken-first-available-task-processors (task-process-pool)
  "[Cyc] Awaken the first N task-processor in TASK-PROCESS-POOL having a NIL busy-p."
  (when (< (get-nbr-of-task-processors task-process-pool)
            (get-tpool-max-nbr-of-task-processors task-process-pool))
    (when (> *task-processor-verbosity* 2)
      (push-tpool-background-msg (format nil "Allocating a new task processor~%") task-process-pool))
    (add-new-task-processor-to-pool task-process-pool))
  (push-tpool-background-msg (format nil "Awakening first available task processor~%") task-process-pool)
  (bt:signal-semaphore (tpool-request-semaphore task-process-pool))
  nil)

(defun enqueue-task-request (task-info task-process-pool)
  "[Cyc] Enqueue the TASK-INFO on the TASK-PROCESS-POOL request queue and awaken the
first available task processor within the scope of the queue lock."
  (declare (type task-info task-info)
           (type task-process-pool task-process-pool))
  (assert (tpool-processors task-process-pool) () "Task processors are not initialized.")
  (bt:with-lock-held ((tpool-lock task-process-pool))
    (multiple-value-bind (request-queue bumped-request? bumped-request-item)
        (p-enqueue task-info (tpool-request-queue task-process-pool))
      (declare (ignore request-queue))
      (when bumped-request?
        (cerror "~%Error: cannot queue task request for ~%~S~%" bumped-request-item))
      (awaken-first-available-task-processors task-process-pool)))
  nil)

;; TODO - declare-task-process-pool macro
;; Evidence: $list207 = (TYPE MIN-NBR-OF-TASK-PROCESSORS MAX-NBR-OF-TASK-PROCESSORS)
;; $str208 = "*", $str209 = "-TASK-PROCESS-POOL*", $str210 = "-TASK-PROCESS-POOL-LOCK*"
;; $sym211 = DEFLEXICAL-PUBLIC, $sym213 = DEFCONSTANT-PUBLIC, $sym215 = DEFINE-PUBLIC
;; Generates deflexical *TYPE-TASK-PROCESS-POOL*, defconstant *TYPE-TASK-PROCESS-POOL-LOCK*,
;; and functions TYPE-TASK-PROCESSORS-INITIALIZED-P, INITIALIZE-TYPE-TASK-PROCESSORS,
;; HALT-TYPE-TASK-PROCESSORS, SHOW-TYPE-TP-MSGS

;; TODO - declare-task-process-request macro
;; Evidence: $list238 = (TYPE EVAL-FN ARGS &BODY BODY)
;; $str239 = "-TASK-PROCESSOR-REQUEST"
;; Generates the request function and registers eval-fn in *task-processor-eval-fn-dict*

;; TODO - declare-task-process-response-dispatch macro
;; Evidence: $list243 = (TYPE ARGS &BODY BODY)
;; $str244 = "DISPATCH-", $str245 = "-TASK-PROCESSOR-RESPONSE"
;; Generates the response dispatch function and registers it in *task-processor-response-dispatch-fn-dict*


;;;; API task processor pool (expanded from declare-task-process-pool :API ...)

(defun api-task-processors-initialized-p ()
  "[Cyc] Return T when there are task processors."
  (task-processors-initialized-p *api-task-process-pool*))

(defun initialize-api-task-processors ()
  "[Cyc] Initialize the task processor pool for requests."
  (bt:with-lock-held (*api-task-process-pool-lock*)
    (when *api-task-process-pool*
      (error "Illegal attempt to reinitialize processor pool without first halting it."))
    (setf *api-task-process-pool*
          (initialize-task-processors (concatenate 'string "API" " processor ") 5 25)))
  nil)

(defun halt-api-task-processors ()
  "[Cyc] Halt the task processors."
  (bt:with-lock-held (*api-task-process-pool-lock*)
    (when *api-task-process-pool*
      ;; Likely calls halt-task-processors on the pool
      (missing-larkc 31801)
      (setf *api-task-process-pool* nil)
      ;; Likely notifies waiting semaphores to unblock
      (missing-larkc 31791)))
  nil)

;; (defun show-api-tp-msgs () ...) -- active declareFunction, no body
;; (defun show-api-task-processors () ...) -- active declareFunction, no body, Cyc API
;; (defun display-api-task-processors () ...) -- active declareFunction, no body, Cyc API

(defun api-task-processor-request (request id priority requestor bindings uuid-string)
  "[Cyc] Submits the REQUEST form to the task request queue with ID, PRIORITY,
REQUESTOR, OUT-STREAM and BINDINGS."
  (let ((immediate-execution? (eq (first request) 'with-immediate-execution))
        (task-info (make-task-info)))
    (when immediate-execution?
      (setf request (second request)))
    (set-task-info-type :api task-info)
    (set-task-info-id id task-info)
    (set-task-info-priority priority task-info)
    (set-task-info-requestor requestor task-info)
    (set-task-info-giveback-info uuid-string task-info)
    (set-task-info-bindings bindings task-info)
    (set-task-info-request request task-info)
    (enqueue-task-request task-info *api-task-process-pool*))
  nil)

;; (defun set-java-api-lease-activity-display (value) ...) -- active declareFunction, no body

(defun java-api-lease-activity-display ()
  "[Cyc] Returns the indicator that lease renewal requests should be displayed on the console."
  *java-api-lease-activity-display*)

(defun dispatch-task-processor-response (task-info &optional (finished t))
  (when *minimize-task-processor-info-communication*
    (set-task-info-request nil task-info))
  (funcall (gethash (ti-type task-info) *task-processor-response-dispatch-fn-dict*)
           task-info finished)
  nil)

(defun dispatch-api-task-processor-response (task-info &optional (finished t))
  "[Cyc] Dispatches the api task-info item by sending the
response to the api client socket from which the
request originated."
  (when (> *task-processor-verbosity* 0)
    (push-tpool-background-msg (format nil "Dispatching api response ~S~%" task-info)
                               *api-task-process-pool*))
  (let* ((uuid-string (get-task-info-giveback-info task-info))
         (task-processor-response (list 'task-processor-response
                                        (get-task-info-request task-info)
                                        (get-task-info-id task-info)
                                        (get-task-info-priority task-info)
                                        (get-task-info-requestor task-info)
                                        (get-task-info-response task-info)
                                        (get-task-info-error-message task-info)
                                        finished))
         (socket (java-api-socket-out-stream uuid-string))
         (lock (java-api-lock uuid-string)))
    (let ((*within-complete-cfasl-objects* t))
      (if (and (streamp socket) (open-stream-p socket))
          (progn
            (cfasl-set-mode-externalized)
            (when (> (get-task-processor-verbosity) 0)
              (push-tpool-background-msg
               (format nil "Sending api response ~S to socket ~S~% identified by ~A~%"
                       (get-task-info-response task-info) socket uuid-string)
               *api-task-process-pool*))
            (bt:with-lock-held (lock)
              (send-cfasl-result socket task-processor-response nil)))
          (when (> (get-task-processor-verbosity) 0)
            (push-tpool-background-msg
             (format nil "Dropping api response ~S, socket ~S~% identified by ~A is not available~%"
                     task-processor-response socket uuid-string)
             *api-task-process-pool*)))))
  nil)

;; Intermediate results accumulator stubs
;; (defun new-intermediate-results-accumulator (task-info) ...) -- active declareFunction, no body
;; (defun intermediate-results-accumulator-add (accumulator result) ...) -- active declareFunction, no body
;; (defun intermediate-results-accumulator-add-all (accumulator results) ...) -- active declareFunction, no body
;; (defun intermediate-results-accumulator-reset (accumulator) ...) -- active declareFunction, no body
;; (defun intermediate-results-accumulator-size (accumulator) ...) -- active declareFunction, no body
;; (defun intermediate-results-accumulator-contents (accumulator &optional reset?) ...) -- active declareFunction, no body
;; (defun intermediate-results-accumulator-iterator (accumulator) ...) -- active declareFunction, no body

;;;; BG task processor pool (expanded from declare-task-process-pool :BG ...)

;; (defun bg-task-processors-initialized-p () ...) -- active declareFunction, no body
;; (defun initialize-bg-task-processors () ...) -- active declareFunction, no body
;; (defun halt-bg-task-processors () ...) -- active declareFunction, no body
;; (defun show-bg-tp-msgs () ...) -- active declareFunction, no body
;; (defun bg-task-processor-request (request id priority requestor bindings uuid-string) ...) -- active declareFunction, no body
;; (defun dispatch-bg-task-processor-response (task-info) ...) -- active declareFunction, no body
;; (defun bg-api-eval (form) ...) -- active declareFunction, no body

;;;; Console task processor pool (expanded from declare-task-process-pool :CONSOLE ...)

;; (defun console-task-processors-initialized-p () ...) -- active declareFunction, no body
;; (defun initialize-console-task-processors () ...) -- active declareFunction, no body
;; (defun halt-console-task-processors () ...) -- active declareFunction, no body
;; (defun show-console-tp-msgs () ...) -- active declareFunction, no body
;; (defun console-task-processor-request (request id) ...) -- active declareFunction, no body
;; (defun dispatch-console-task-processor-response (task-info) ...) -- active declareFunction, no body


;;;; Setup

(toplevel
  (register-external-symbol 'set-task-processor-verbosity)
  (register-external-symbol 'set-tpool-background-msg-path)
  (register-cyc-api-macro 'catch-task-processor-termination
    '(ans-var &body body)
    "Allow for the API calling side to catch the termination of the task processor.
   The client must wrap the api-request form with catch-task-processor-termination.")
  (register-cyc-api-macro 'catch-task-processor-termination-quietly
    '(&body body)
    "Allow for the API calling side to catch the termination of the task processor
   without looking at the termination reason.
   The client must wrap the api-request form with catch-task-processor-termination-quietly.")
  (register-external-symbol 'ensure-task-processors-killed)
  (register-cyc-api-function 'show-api-task-processors nil
    "Provides a convenient alias for DISPLAY-API-TASK-PROCESSORS." nil nil)
  (register-cyc-api-function 'display-api-task-processors nil "" nil nil)
  (register-api-predefined-function 'initialize-api-task-processors)
  (register-api-predefined-function 'halt-api-task-processors)
  (register-api-predefined-function 'show-api-tp-msgs)
  (register-api-predefined-function 'api-task-processor-request)
  (register-api-predefined-function 'with-immediate-execution)

  ;; Initialize eval fn dict with API, BG, and Console entries
  (when (null *task-processor-eval-fn-dict*)
    (setf *task-processor-eval-fn-dict* (make-hash-table :test #'eql)))
  (setf (gethash :api *task-processor-eval-fn-dict*) #'cyc-api-eval)
  (register-external-symbol 'set-java-api-lease-activity-display)

  ;; Initialize response dispatch fn dict
  (when (null *task-processor-response-dispatch-fn-dict*)
    (setf *task-processor-response-dispatch-fn-dict* (make-hash-table :test #'eql)))
  (setf (gethash :api *task-processor-response-dispatch-fn-dict*)
        #'dispatch-api-task-processor-response)

  ;; BG task processor registration
  (when (null *task-processor-eval-fn-dict*)
    (setf *task-processor-eval-fn-dict* (make-hash-table :test #'eql)))
  (setf (gethash :bg *task-processor-eval-fn-dict*) #'cyc-api-eval)
  (when (null *task-processor-response-dispatch-fn-dict*)
    (setf *task-processor-response-dispatch-fn-dict* (make-hash-table :test #'eql)))
  ;; dispatch-bg-task-processor-response is a no-body stub, register symbol
  (setf (gethash :bg *task-processor-response-dispatch-fn-dict*)
        'dispatch-bg-task-processor-response)

  ;; Console task processor registration
  (declare-defglobal '*task-processor-console-id*)
  (when (null *task-processor-eval-fn-dict*)
    (setf *task-processor-eval-fn-dict* (make-hash-table :test #'eql)))
  (setf (gethash :console *task-processor-eval-fn-dict*) #'cyc-api-eval)
  (when (null *task-processor-response-dispatch-fn-dict*)
    (setf *task-processor-response-dispatch-fn-dict* (make-hash-table :test #'eql)))
  ;; dispatch-console-task-processor-response is a no-body stub, register symbol
  (setf (gethash :console *task-processor-response-dispatch-fn-dict*)
        'dispatch-console-task-processor-response))
