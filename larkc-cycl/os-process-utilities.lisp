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

;; Struct: os-process-impl
;; print-object is missing-larkc 30768 — CL's default print-object handles this.
;; os-process-impl-p has no body (missing-larkc 30749).
(defstruct (os-process-impl
            (:conc-name "OS-PROCESS-IMPL-")
            (:constructor make-os-process-impl (&key id name program arguments
                                                     stdin-stream stdin-filename
                                                     stdout-stream stdout-filename
                                                     stderr-stream stderr-filename
                                                     status started finished
                                                     exit-code properties)))
  id
  name
  program
  arguments
  stdin-stream
  stdin-filename
  stdout-stream
  stdout-filename
  stderr-stream
  stderr-filename
  status
  started
  finished
  exit-code
  properties)

;; (defun print-os-process-impl (object stream depth) ...) -- active declareFunction, no body
;; (defun valid-os-process-input-stream-spec-p (object) ...) -- active declareFunction, no body
;; (defun valid-os-process-output-stream-spec-p (object) ...) -- active declareFunction, no body
;; (defun valid-os-process-error-output-stream-spec-p (object) ...) -- active declareFunction, no body
;; (defun is-valid-os-process-status-p (status) ...) -- active declareFunction, no body
;; (defun os-process-p (object) ...) -- active declareFunction, no body

(defconstant *dtp-os-process-impl* 'os-process-impl)

(defconstant *valid-os-process-status* '(:initializing :running :dead :failure)
  "[Cyc] The valid OS process status values.")

(deflexical *os-process-enumeration-lock*
  (if (and (boundp '*os-process-enumeration-lock*)
           (typep *os-process-enumeration-lock* 'bt:lock))
      *os-process-enumeration-lock*
      (bt:make-lock "OS Process enumeration lock")))

(deflexical *active-os-processes*
  (if (boundp '*active-os-processes*)
      *active-os-processes*
      nil))

(defun clear-active-os-processes ()
  "[Cyc] Called from system code initializations."
  (bt:with-lock-held (*os-process-enumeration-lock*)
    (setf *active-os-processes* nil))
  *active-os-processes*)

;; (defun all-os-processes () ...) -- active declareFunction, no body
;; (defun show-os-processes () ...) -- active declareFunction, no body
;; (defun os-processes-named (name) ...) -- active declareFunction, no body
;; (defun kill-os-processes-named (name) ...) -- active declareFunction, no body
;; (defun add-os-process-to-active-list (os-process) ...) -- active declareFunction, no body
;; (defun remove-os-process-from-active-list (os-process &optional warn?) ...) -- active declareFunction, no body

(defun make-os-process (name program &optional (args nil) (stdin *standard-input*) (stdout *standard-output*) (stderr :output))
  (declare (type string name)
           (type string program))
  (let ((os-process (make-os-process-impl)))
    (setf (os-process-impl-started os-process) (get-internal-real-time))
    (setf (os-process-impl-status os-process) :initializing)
    (setf (os-process-impl-name os-process) name)
    (setf (os-process-impl-program os-process) program)
    (setf (os-process-impl-arguments os-process) args)
    (when (or (stringp stdin) (eq stdin :stream))
      ;; Likely sets stdin-filename or stdin-stream — evidence: parallel stdout/stderr handling
      (missing-larkc 30723))
    (when (or (stringp stdout) (eq stdout :stream))
      ;; Likely sets stdout-filename or stdout-stream
      (missing-larkc 30728))
    (when (or (stringp stderr) (eq stderr :stream))
      ;; Likely sets stderr-filename or stderr-stream
      (missing-larkc 30718))
    (multiple-value-bind (stdin-stream stdout-stream stderr-stream pid)
        (make-os-process-internal program args stdin stdout stderr)
      (declare (ignore stdin-stream stdout-stream stderr-stream))
      ;; Likely sets the id field from pid — evidence: field is $id, and pid is integer
      (missing-larkc 30715)
      (if (integerp pid)
          (progn
            (setf (os-process-impl-status os-process) :running)
            ;; Likely adds os-process to active list — evidence: add-os-process-to-active-list exists
            (missing-larkc 30732))
          (setf (os-process-impl-status os-process) :failure))
      ;; Likely sets stdin-stream field
      (missing-larkc 30725)
      ;; Likely sets stdout-stream field
      (missing-larkc 30730)
      ;; Likely sets stderr-stream field
      (missing-larkc 30720))
    os-process))

;; (defun os-process-running? (os-process) ...) -- active declareFunction, no body
;; (defun wait-until-os-processes-finished (os-processes) ...) -- active declareFunction, no body
;; (defun wait-until-os-process-finished (os-process) ...) -- active declareFunction, no body

(defun make-os-process-internal (program args stdin-spec stdout-spec stderr-spec)
  (let* ((null-stream-path (get-null-file-stream-path))
         (input (if (eq stdin-spec *null-input*)
                    null-stream-path
                    stdin-spec))
         (output (if (eq stdout-spec *null-output*)
                     null-stream-path
                     stdout-spec))
         (error-output (if (eq stderr-spec *null-output*)
                           null-stream-path
                           stderr-spec)))
    (unless (external-processes-supported?)
      (error "Currently not implemented for this port."))
    (run-external-process program args input output error-output)))

(defun get-null-file-stream-path ()
  (canonical-null-file-stream-path))

;; (defun external-program-command-line-from-program-and-args (program args) ...) -- active declareFunction, no body
;; (defun external-program-command-line-for-os-process (os-process) ...) -- active declareFunction, no body
;; (defun verify-os-process-run-status (os-process &optional expected-status) ...) -- active declareFunction, no body
;; (defun get-current-os-process-status-internal (os-process &optional refresh?) ...) -- active declareFunction, no body
;; (defun get-current-os-process-status-implementation (os-process refresh?) ...) -- active declareFunction, no body
;; (defun kill-os-process (os-process) ...) -- active declareFunction, no body
;; (defun cleanup-os-process (os-process) ...) -- active declareFunction, no body
;; (defun destroy-os-process (os-process) ...) -- active declareFunction, no body
;; (defun kill-os-process-internal (os-process) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; Evidence: $list79 = arglist ((OS-PROCESS-VAR COMMAND &KEY (ARGS NIL) (NAME "My OS process")
;;   (STDIN (QUOTE *STANDARD-INPUT*)) (STDOUT (QUOTE *STANDARD-OUTPUT*)) (STDERR :OUTPUT)) &BODY BODY)
;; $sym89=CLET, $sym90=MAKE-OS-PROCESS, $sym91=CUNWIND-PROTECT, $sym92=PROGN, $sym93=DESTROY-OS-PROCESS
;; Pattern: bind os-process-var to make-os-process, run body in unwind-protect, destroy on exit.
;; No expansion sites found in other files.
(defmacro run-os-process ((os-process-var command &key (args nil) (name "My OS process")
                                          (stdin '*standard-input*) (stdout '*standard-output*)
                                          (stderr :output))
                          &body body)
  `(let ((,os-process-var (make-os-process ,name ,command ,args ,stdin ,stdout ,stderr)))
     (unwind-protect
          (progn ,@body)
       (destroy-os-process ,os-process-var))))

;; Reconstructed from Internal Constants:
;; Evidence: $sym94=RUN-OS-PROCESS, $sym95=WAIT-UNTIL-OS-PROCESS-FINISHED
;; Pattern: same arglist as run-os-process, adds wait-until-os-process-finished after body.
;; No expansion sites found in other files.
(defmacro run-os-process-to-completion ((os-process-var command &key (args nil) (name "My OS process")
                                                        (stdin '*standard-input*) (stdout '*standard-output*)
                                                        (stderr :output))
                                        &body body)
  `(run-os-process (,os-process-var ,command :args ,args :name ,name
                                    :stdin ,stdin :stdout ,stdout :stderr ,stderr)
     ,@body
     (wait-until-os-process-finished ,os-process-var)))

(defun system-eval-using-make-os-process (command &optional (args nil) (stdin *standard-input*) (stdout *standard-output*) (stderr :output))
  (let ((exit-code -1)
        (os-process (make-os-process "My system-eval OS Process" command args stdin stdout stderr)))
    (unwind-protect
         (progn
           ;; Likely waits for process completion — evidence: pattern matches run-os-process-to-completion
           (missing-larkc 30771)
           (setf exit-code
                 ;; Likely retrieves exit code — evidence: os-process-exit-code accessor exists
                 (missing-larkc 30743)))
      (progn
        ;; Likely calls destroy-os-process — evidence: cleanup pattern
        (missing-larkc 30736)))
    exit-code))

(defun system-eval-using-make-os-process-successful? (command &optional (args nil) (success-exit-code 0) (stdin *standard-input*) (stdout *standard-output*) (stderr :output))
  "[Cyc] Like @xref system-eval-using-make-os-process, except returns T iff
the os-process's exit code is SUCCESS-EXIT-CODE."
  (let ((exit-code (system-eval-using-make-os-process command args stdin stdout stderr)))
    (eql exit-code success-exit-code)))

;; (defun os-process-evaluation-output-strings (command &optional args stdin stderr) ...) -- active declareFunction, no body
;; (defun os-process-id (os-process) ...) -- active declareFunction, no body
;; (defun os-process-arguments (os-process) ...) -- active declareFunction, no body
;; (defun os-process-exit-code (os-process) ...) -- active declareFunction, no body
;; (defun os-process-finished (os-process) ...) -- active declareFunction, no body
;; (defun os-process-name (os-process) ...) -- active declareFunction, no body
;; (defun os-process-program (os-process) ...) -- active declareFunction, no body
;; (defun os-process-started (os-process) ...) -- active declareFunction, no body
;; (defun os-process-status (os-process) ...) -- active declareFunction, no body
;; (defun os-process-stderr-filename (os-process) ...) -- active declareFunction, no body
;; (defun os-process-stderr-stream (os-process) ...) -- active declareFunction, no body
;; (defun os-process-stdin-filename (os-process) ...) -- active declareFunction, no body
;; (defun os-process-stdin-stream (os-process) ...) -- active declareFunction, no body
;; (defun os-process-stdout-filename (os-process) ...) -- active declareFunction, no body
;; (defun os-process-stdout-stream (os-process) ...) -- active declareFunction, no body

(defparameter *forked-cyc-server-process-task* nil
  "[Cyc] Used to communicate the user's task between the forking CYC server
and the child, which has to run system code initialization setup first.")

;; (defun fork-cyc-server-process (task &optional args stderr) ...) -- active declareFunction, no body
;; (defun fork-cyc-server-process-implementation () ...) -- active declareFunction, no body

;; Setup phase
(toplevel
  (declare-defglobal '*os-process-enumeration-lock*)
  (declare-defglobal '*active-os-processes*)
  (register-external-symbol 'fork-cyc-server-process)
  (note-funcall-helper-function 'fork-cyc-server-process-implementation))
