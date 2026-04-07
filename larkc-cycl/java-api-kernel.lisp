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


;;;; Variables

(deflexical *java-api-leases* (new-synchronized-dictionary #'equal)
  "[Cyc] The dictionary of java api client leases.  The key is a
UUID string (GUID) provided by the java client, and the value is a timestamp
giving the lease expiration time.")

(deflexical *java-api-lease-monitor* nil
  "[Cyc] The process which monitors lease expirations for java api clients.")

(defconstant *java-api-lease-monitor-sleep-seconds* 2
  "[Cyc] The lease monitor will check for invalid leases every this many seconds.")

(defconstant *maximum-api-services-lease-duration-in-milliseconds* 3600000
  "[Cyc] the maximum java api services lease duration in milliseconds")

(defconstant *lease-timeout-cushion-factor* 3
  "[Cyc] the multiplier factor used to calcuate actual lease expiration from the requested duration")

(deflexical *java-api-sockets* (new-synchronized-dictionary #'equal)
  "[Cyc] The synchronized dictionary of persistent sockets established to provide
outbound cfasl messaging with java api clients. The key is a
UUID string (GUID) provided by the java client when the socket is
created.")

(deflexical *java-home-red-key-name* "JAVA_HOME")
(deflexical *java-lib-red-key-name* "JAVA_LIB")
(deflexical *java-vm-red-key-name* "JAVA_VM")
(deflexical *java-re-home-red-key-name* "JAVA_RE_HOME")
(deflexical *java-re-lib-red-key-name* "JAVA_RE_LIB")
(deflexical *java-re-vm-red-key-name* "JAVA_RE_VM")
(deflexical *java-path-separator-red-key-name* "path_separator")
(deflexical *java-red-subtree-name* "java")
(deflexical *java-red-root-key* nil)
(deflexical *java-default-version-numbers* '(1 4 2))
(deflexical *java-red-key-main-class-key* "java-main-class")
(deflexical *java-red-key-classpath-key* "java-classpath")
(deflexical *java-red-key-arguments-key* "java-arguments")


;;;; Functions

;; (defun java-api-lease-expiration-time (uuid-string) ...) -- active declareFunction, no body

(defun initialize-java-api-lease-monitor ()
  "[Cyc] Initialize the process which monitors lease expirations for java api clients."
  (halt-java-api-lease-monitor)
  (setf *java-api-lease-monitor*
        (bt:make-thread #'java-api-lease-monitor :name "Java API lease monitor"))
  nil)

(defun halt-java-api-lease-monitor ()
  "[Cyc] Halt the the process which monitors lease expirations for java api clients."
  (when *java-api-lease-monitor*
    (bt:destroy-thread *java-api-lease-monitor*)
    (setf *java-api-lease-monitor* nil))
  nil)

(defun java-api-lease-monitor ()
  "[Cyc] Periodically monitors java api client leases, closing sockets and killing active api requests belonging
to clients having expired leases."
  (loop
    (ignore-errors
      (when *java-api-leases*
        (let ((uuid-strings-to-remove nil)
              (current-utc-time-with-milliseconds (get-utc-time-with-milliseconds)))
          (sb-ext:with-locked-hash-table (*java-api-leases*)
            (maphash (lambda (uuid-string lease-expiration-time)
                       (let ((error-message nil))
                         (catch-error-message (error-message)
                           (let ((seconds-yet-to-wait (/ (- lease-expiration-time
                                                            current-utc-time-with-milliseconds)
                                                         1000)))
                             (when (< seconds-yet-to-wait 0)
                               (push uuid-string uuid-strings-to-remove)
                               (release-resources-for-java-api-client uuid-string t))))
                         (when error-message
                           (warn "~A" error-message))))
                     *java-api-leases*))
          (dolist (uuid-string-to-remove uuid-strings-to-remove)
            (let ((error-message nil))
              (catch-error-message (error-message)
                (synchronized-dictionary-remove *java-api-leases* uuid-string-to-remove))
              (when error-message
                (warn "~A" error-message))))
          (sleep *java-api-lease-monitor-sleep-seconds*))))))

(defun release-resources-for-java-api-client (uuid-string &optional abnormal?)
  "[Cyc] Closes the outbound api socket and kills active api requests identified by the given uuid-string.
   @param uuid-string ; stringp
   @param abnormal?   ; boolean Whether or not the release was abnormal or expected"
  (declare (type string uuid-string))
  (when (> (get-task-processor-verbosity) 0)
    (push-tpool-background-msg
     (format nil "Releasing java API resources identified by ~A~%" uuid-string)
     *api-task-process-pool*))
  (when abnormal?
    (warn "~%Releasing java API resources identified by ~A~%" uuid-string))
  (ignore-errors
    (close-java-api-socket uuid-string))
  (ignore-errors
    (unless abnormal?
      (synchronized-dictionary-remove *java-api-leases* uuid-string)))
  (terminate-active-task-processes uuid-string)
  nil)

(defun acquire-api-services-lease (lease-duration-in-milliseconds uuid-string)
  "[Cyc] Requests an API services lease.  Typical leases are expected to be 10 minutes.  A lease request
   for a duration longer than one hour is denied.
   @param lease-duration-in-milliseconds ; integerp, the lease duration in milliseconds
   @param uuid-string ; stringp, identifies the java api client"
  (declare (type integer lease-duration-in-milliseconds)
           (type string uuid-string))
  (if (> lease-duration-in-milliseconds *maximum-api-services-lease-duration-in-milliseconds*)
      (progn
        (synchronized-dictionary-remove *java-api-leases* uuid-string)
        (when (java-api-lease-activity-display)
          ;; Likely prints a newline/header before the denial — evidence: followed by format+force-output
          (missing-larkc 10868)
          (format *cfasl-kernel-standard-output*
                  "api services lease denied for ~A~%" uuid-string)
          (force-output *cfasl-kernel-standard-output*))
        "api services lease denied")
      (progn
        (when (null *java-api-lease-monitor*)
          (initialize-java-api-lease-monitor))
        (let* ((lease-expiration-time
                 (+ (get-utc-time-with-milliseconds)
                    (* lease-duration-in-milliseconds *lease-timeout-cushion-factor*)))
               (renewal-msg
                 (concatenate 'string
                              "api services lease granted by "
                              (cyc-image-id)
                              " to "
                              uuid-string
                              " for "
                              (to-string lease-duration-in-milliseconds)
                              " milliseconds")))
          (synchronized-dictionary-enter *java-api-leases* uuid-string lease-expiration-time)
          (when (java-api-lease-activity-display)
            (format *cfasl-kernel-standard-output* "~A~%" renewal-msg)
            (force-output *cfasl-kernel-standard-output*))
          renewal-msg))))

;; (defun show-java-api-service-leases () ...) -- active declareFunction, no body, Cyc API

(defun get-current-api-socket ()
  (list *api-in-stream* *api-out-stream* (bt:make-lock "Java API stream lock")))

(defun api-socket-in-stream (api-socket)
  (first api-socket))

(defun api-socket-out-stream (api-socket)
  (second api-socket))

(defun api-socket-lock (api-socket)
  (third api-socket))

(defun initialize-java-api-passive-socket (uuid-string)
  "[Cyc] Associates the current socket with the given UUID-STRING, then ends this server process
that currently uses the socket."
  (declare (type string uuid-string))
  (let ((api-socket (get-current-api-socket)))
    (when (> (get-task-processor-verbosity) 0)
      (push-tpool-background-msg
       (format nil "Initializing java client socket ~S~%identified by ~A~%" api-socket uuid-string)
       *api-task-process-pool*))
    (cleanup-broken-java-api-sockets)
    (if (streamp (api-socket-out-stream api-socket))
        (progn
          (synchronized-dictionary-enter *java-api-sockets* uuid-string api-socket)
          (bt:with-lock-held ((api-socket-lock api-socket))
            (send-cfasl-result (api-socket-out-stream api-socket) nil))
          (when (> (get-task-processor-verbosity) 0)
            (push-tpool-background-msg
             (format nil "Initialized java client socket ~S~%identified by ~A~%" api-socket uuid-string)
             *api-task-process-pool*)))
        (when (> (get-task-processor-verbosity) 0)
          (push-tpool-background-msg
           (format nil "Invalid java client socket ~S~%" api-socket)
           *api-task-process-pool*)))
    (synchronized-dictionary-enter *java-api-leases* uuid-string
                                   (+ (get-utc-time-with-milliseconds)
                                      *maximum-api-services-lease-duration-in-milliseconds*))
    (setf *retain-client-socket?* t)
    (cfasl-quit))
  nil)

(defun java-api-socket (uuid-string)
  "[Cyc] Return the java api socket corresponding to the given UUID key."
  (declare (type string uuid-string))
  (let ((api-socket (synchronized-dictionary-lookup *java-api-sockets* uuid-string)))
    (when (> (get-task-processor-verbosity) 0)
      (push-tpool-background-msg
       (format nil "Looked up socket ~S from dictionary~%identifed by ~A~%" api-socket uuid-string)
       *api-task-process-pool*))
    api-socket))

(defun java-api-socket-out-stream (uuid-string)
  "[Cyc] Return the java api socket output stream corresponding to the given UUID key."
  (api-socket-out-stream (java-api-socket uuid-string)))

(defun java-api-lock (uuid-string)
  "[Cyc] Return the java api socket output stream corresponding to the given UUID key."
  (api-socket-lock (java-api-socket uuid-string)))

(defun close-java-api-socket (uuid-string)
  "[Cyc] Closes the persistent cfasl socket that is associated with
the given UUID-STRING."
  (declare (type string uuid-string))
  (when (null *java-api-sockets*)
    (return-from close-java-api-socket nil))
  (let ((api-socket (java-api-socket uuid-string)))
    (when api-socket
      (let ((in-stream (api-socket-in-stream api-socket))
            (out-stream (api-socket-out-stream api-socket)))
        (ignore-errors
          (unwind-protect (close in-stream)
            (unless (eq in-stream out-stream)
              (close out-stream)))))
      (synchronized-dictionary-remove *java-api-sockets* uuid-string)
      (when (> (get-task-processor-verbosity) 0)
        (push-tpool-background-msg
         ;; Java constant has buggy format string "~S~ from dictionary%identifed" — fixed ~S~ → ~S, added missing ~%
         (format nil "Removed socket ~S from dictionary~%identifed by ~A~%" api-socket uuid-string)
         *api-task-process-pool*))))
  nil)

;; (defun show-java-api-sockets () ...) -- active declareFunction, no body, Cyc API

(defun reset-java-api-kernel ()
  "[Cyc] Reset this subsystem to an un-initialized state."
  (halt-api-task-processors)
  (clear-synchronized-dictionary *java-api-leases*)
  (clear-synchronized-dictionary *java-api-sockets*)
  nil)

(defun cleanup-broken-java-api-sockets ()
  "[Cyc] Attempt to send an ignorable message to each java api client and
when failing, close its socket."
  (when *java-api-sockets*
    (let ((uuid-strings (synchronized-dictionary-keys *java-api-sockets*)))
      (dolist (uuid-string uuid-strings)
        (when (> (get-task-processor-verbosity) 0)
          (push-tpool-background-msg
           (format nil "Verifying java api socket identified by ~A~%" uuid-string)
           *api-task-process-pool*))
        (let ((lock (java-api-lock uuid-string))
              (socket (java-api-socket-out-stream uuid-string)))
          (ignore-errors
            (let ((close-socket? t))
              (unwind-protect
                   (progn
                     (bt:with-lock-held (lock)
                       (send-cfasl-result socket '(ignore) nil))
                     (setf close-socket? nil))
                (when close-socket?
                  (when (> (get-task-processor-verbosity) 0)
                    (push-tpool-background-msg
                     (format nil "closing broken java api socket ~A~%identified by ~A~%" socket uuid-string)
                     *api-task-process-pool*))
                  (close-java-api-socket uuid-string)))))))))
  nil)

;; No-body stubs: RED/Java launch functions
;; (defun launch-java-application-from-red (red-application-name &optional process-name) ...) -- active declareFunction, no body
;; (defun launch-java-application-from-red-in-process (red-application-name &optional process-name) ...) -- active declareFunction, no body
;; (defun get-red-value-for-default-java-virtual-machine () ...) -- active declareFunction, no body
;; (defun get-red-value-for-default-java-vm () ...) -- active declareFunction, no body
;; (defun get-red-value-for-default-java-re-vm () ...) -- active declareFunction, no body
;; (defun get-red-value-for-default-java-home () ...) -- active declareFunction, no body
;; (defun get-red-value-for-default-java-re-home () ...) -- active declareFunction, no body
;; (defun get-red-value-for-default-java-lib () ...) -- active declareFunction, no body
;; (defun get-red-value-for-default-java-re-lib () ...) -- active declareFunction, no body
;; (defun get-red-value-for-default-java-path-separator () ...) -- active declareFunction, no body
;; (defun get-red-key-for-default-java-home () ...) -- active declareFunction, no body
;; (defun get-red-key-for-default-java-re-home () ...) -- active declareFunction, no body
;; (defun get-red-key-for-default-java-lib () ...) -- active declareFunction, no body
;; (defun get-red-key-for-default-java-re-lib () ...) -- active declareFunction, no body
;; (defun get-red-key-for-default-java-vm () ...) -- active declareFunction, no body
;; (defun get-red-key-for-default-java-re-vm () ...) -- active declareFunction, no body
;; (defun get-red-key-for-default-java-path-separator () ...) -- active declareFunction, no body
;; (defun get-software-type-as-red-key-name () ...) -- active declareFunction, no body
;; (defun get-java-red-root-key () ...) -- active declareFunction, no body
;; (defun get-java-red-root-key-for-version (version-numbers) ...) -- active declareFunction, no body
;; (defun get-java-red-root-key-for-default-version () ...) -- active declareFunction, no body
;; (defun get-java-application-information-from-red (red-application-name) ...) -- active declareFunction, no body
;; (defun get-java-classpath-from-elments (classpath-elements java-path-separator) ...) -- active declareFunction, no body


;;;; Setup

(toplevel
  (register-cyc-api-function 'initialize-java-api-lease-monitor nil
    "Initialize the process which monitors lease expirations for java api clients."
    nil nil)
  (register-cyc-api-function 'halt-java-api-lease-monitor nil
    "Halt the the process which monitors lease expirations for java api clients."
    nil nil)
  (register-cyc-api-function 'release-resources-for-java-api-client
    '(uuid-string &optional abnormal?)
    "Closes the outbound api socket and kills active api requests identified by the given uuid-string.
   @param uuid-string ; stringp
   @param abnormal?   ; boolean Whether or not the release was abnormal or expected"
    '((uuid-string stringp)) '(nil))
  (register-cyc-api-function 'acquire-api-services-lease
    '(lease-duration-in-milliseconds uuid-string)
    "Requests an API services lease.  Typical leases are expected to be 10 minutes.  A lease request
   for a duration longer than one hour is denied.
   @param lease-duration-in-milliseconds ; integerp, the lease duration in milliseconds
   @param uuid-string ; stringp, identifies the java api client"
    '((lease-duration-in-milliseconds integerp) (uuid-string stringp)) '(stringp))
  (register-cyc-api-function 'show-java-api-service-leases nil
    "Displays the current java api leases."
    nil '(nil))
  (register-cyc-api-function 'initialize-java-api-passive-socket '(uuid-string)
    "Associates the current socket with the given UUID-STRING, then ends this server process
that currently uses the socket."
    '((uuid-string stringp)) '(nil))
  (register-cyc-api-function 'close-java-api-socket '(uuid-string)
    "Closes the persistent cfasl socket that is associated with
the given UUID-STRING."
    '((uuid-string stringp)) '(nil))
  (register-cyc-api-function 'show-java-api-sockets nil
    "Displays the java api sockets."
    nil '(nil))
  (register-cyc-api-function 'reset-java-api-kernel nil
    "Reset this subsystem to an un-initialized state."
    nil nil))
