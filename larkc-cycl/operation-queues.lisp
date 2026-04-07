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

;; Functions follow declare_operation_queues_file ordering.

;; (defun local-queue-size () ...) -- active declareFunction, no body

(defun local-queue-empty ()
  "[Cyc] Return T iff there are no local operations pending."
  (queue-empty-p *local-queue*))

;; (defun clear-local-queue () ...) -- active declareFunction, no body

(defun local-queue-enqueue (operation)
  "[Cyc] Enqueue OPERATION onto the local queue."
  (let ((lock *local-queue-lock*))
    (bt:with-lock-held (lock)
      (enqueue operation *local-queue*)))
  (bt:condition-notify *process-wait-cv*)
  nil)

;; (defun local-queue-dequeue () ...) -- active declareFunction, no body
;; (defun local-queue-peek () ...) -- active declareFunction, no body
;; (defun local-queue-contents () ...) -- active declareFunction, no body
;; (defun local-queue () ...) -- active declareFunction, no body
;; (defun set-local-queue (queue) ...) -- active declareFunction, no body
;; (defun remote-queue-size () ...) -- active declareFunction, no body
;; (defun remote-queue-empty () ...) -- active declareFunction, no body
;; (defun clear-remote-queue () ...) -- active declareFunction, no body
;; (defun remote-queue-enqueue (operation) ...) -- active declareFunction, no body
;; (defun remote-queue-dequeue () ...) -- active declareFunction, no body

(defun transcript-queue-size ()
  "[Cyc] Return the number of transcript operations pending."
  (queue-size *transcript-queue*))

(defun transcript-queue-empty ()
  "[Cyc] Return T iff there are no transcript operations pending."
  (queue-empty-p *transcript-queue*))

;; (defun clear-transcript-queue () ...) -- active declareFunction, no body

(defun transcript-queue-enqueue (operation)
  "[Cyc] Enqueue OPERATION onto the transcript queue."
  (let ((lock *transcript-queue-lock*))
    (bt:with-lock-held (lock)
      (enqueue operation *transcript-queue*)))
  (bt:condition-notify *process-wait-cv*)
  nil)

(defun transcript-queue-dequeue ()
  "[Cyc] Dequeue an operation from the transcript queue."
  (let ((ans nil)
        (lock *transcript-queue-lock*))
    (bt:with-lock-held (lock)
      (setf ans (dequeue *transcript-queue*)))
    ans))

;; (defun hl-transcript-queue-size () ...) -- active declareFunction, no body
;; (defun hl-transcript-queue-empty? () ...) -- active declareFunction, no body
;; (defun clear-hl-transcript-queue () ...) -- active declareFunction, no body
;; (defun hl-transcript-queue-enqueue (operation) ...) -- active declareFunction, no body
;; (defun hl-transcript-queue-dequeue () ...) -- active declareFunction, no body
;; (defun auxiliary-queue-size () ...) -- active declareFunction, no body

(defun auxiliary-queue-empty ()
  "[Cyc] Return T iff there are no auxiliary operations pending."
  (queue-empty-p *auxiliary-queue*))

;; (defun clear-auxiliary-queue () ...) -- active declareFunction, no body
;; (defun auxiliary-queue-enqueue (operation) ...) -- active declareFunction, no body
;; (defun auxiliary-queue-dequeue () ...) -- active declareFunction, no body

(defun transmit-queue-size ()
  "[Cyc] Return the number of transmit operations pending."
  (queue-size *transmit-queue*))

(defun transmit-queue-empty ()
  "[Cyc] Return T iff there are no transmit operations pending."
  (queue-empty-p *transmit-queue*))

;; (defun clear-transmit-queue () ...) -- active declareFunction, no body
;; (defun transmit-queue-enqueue (operation) ...) -- active declareFunction, no body
;; (defun transmit-queue-dequeue () ...) -- active declareFunction, no body
;; (defun local-operation-storage-queue-size () ...) -- active declareFunction, no body
;; (defun local-operation-storage-queue-empty () ...) -- active declareFunction, no body

(defun clear-local-operation-storage-queue ()
  "[Cyc] Clear the local operation storage queue."
  (let ((lock *local-operation-storage-queue-lock*))
    (bt:with-lock-held (lock)
      (clear-queue *local-operation-storage-queue*)))
  t)

(defun local-operation-storage-queue-enqueue (operation)
  "[Cyc] Enqueue OPERATION onto the local operation storage queue."
  (let ((lock *local-operation-storage-queue-lock*))
    (bt:with-lock-held (lock)
      (enqueue operation *local-operation-storage-queue*)))
  (bt:condition-notify *process-wait-cv*)
  nil)

;; (defun local-operation-storage-queue-dequeue () ...) -- active declareFunction, no body
;; (defun local-operation-storage-queue-contents () ...) -- active declareFunction, no body
;; (defun local-operations-anywhere () ...) -- active declareFunction, no body

(defun add-to-local-queue (form &optional (encapsulate? t))
  "[Cyc] Add FORM to the local queue, optionally encapsulating it."
  (let ((api-op (if encapsulate?
                    (form-to-api-op form)
                    form)))
    (local-queue-enqueue api-op)
    t))

;; (defun run-one-local-op () ...) -- active declareFunction, no body
;; (defun add-to-remote-queue (operation) ...) -- active declareFunction, no body
;; (defun within-a-remote-op? () ...) -- active declareFunction, no body
;; (defun run-one-remote-op () ...) -- active declareFunction, no body
;; (defun run-one-remote-op-internal (operation) ...) -- active declareFunction, no body
;; (defun add-to-auxiliary-queue (operation) ...) -- active declareFunction, no body
;; (defun run-one-auxiliary-op () ...) -- active declareFunction, no body

(defun add-to-transcript-queue (encapsulated-form)
  "[Cyc] Add an encapsulated form to the transcript queue with cyclist, image-id, and date info."
  (transcript-queue-enqueue (list (encapsulate (the-cyclist))
                                  (cyc-image-id)
                                  (get-universal-date)
                                  encapsulated-form))
  t)

;; (defun hl-transcript-form? (form) ...) -- active declareFunction, no body
;; (defun add-to-hl-transcript-queue (operation) ...) -- active declareFunction, no body
;; (defun api-op-to-form (api-op) ...) -- active declareFunction, no body

(defun form-to-api-op (form)
  "[Cyc] Add bookkeeping info (if any) and other context to FORM,
then encapsulate it so it is externalizable."
  (let ((info (cyc-bookkeeping-info)))
    (if info
        (encapsulate (list 'with-bookkeeping-info (list 'quote info) form))
        (encapsulate form))))

;; Variables — init phase

(defglobal *local-queue* (create-queue)
  "[Cyc] A queue for local operations that need to be processed by the agenda.")

(defparameter *local-queue-lock* (bt:make-lock "Local Queue Lock"))

(defglobal *remote-queue* (create-queue)
  "[Cyc] A queue for operations that are loaded from the master transcript and need to be processed.")

(defparameter *remote-queue-lock* (bt:make-lock "Remote Queue Lock"))

(defglobal *transcript-queue* (create-queue)
  "[Cyc] A queue for storing operations that have been processed but need to be written to a transcript.")

(defparameter *transcript-queue-lock* (bt:make-lock "Transcript Queue Lock"))

(defglobal *hl-transcript-queue* (create-queue)
  "[Cyc] A queue for storing operations that have been processed but need to be written to an HL transcript.")

(defparameter *hl-transcript-queue-lock* (bt:make-lock "HL Transcript Queue Lock"))

(defglobal *auxiliary-queue* (create-queue)
  "[Cyc] A queue for loading separate stand-alone transcript files, and for other (yet to be specified) uses.")

(defparameter *auxiliary-queue-lock* (bt:make-lock "Auxiliary Queue Lock"))

(defglobal *transmit-queue* (create-queue)
  "[Cyc] A queue for storing operations that need to be sent to the master transcript.")

(defparameter *transmit-queue-lock* (bt:make-lock "Transmit Queue Lock"))

(defglobal *local-operation-storage-queue* (create-queue)
  "[Cyc] A queue for storing operations while in storing mode.")

(defparameter *local-operation-storage-queue-lock* (bt:make-lock "Local Operation Queue Lock"))

(defparameter *within-a-remote-op?* nil)

(defparameter *hl-transcripts-enabled?* nil
  "[Cyc] Do we support HL transcripts? Currently (11/04) HL transcript support is experimental, so this should be left as NIL.")

(deflexical *hl-transcript-special-operators* '(fi-assert fi-unassert fi-blast fi-timestamp-constant fi-timestamp-assertion)
  "[Cyc] Operators that are handled differently in HL transcripts than EL transcripts, and so should not be straightforwardly written to the HL transcript.")
