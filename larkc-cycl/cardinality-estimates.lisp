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

(defglobal *local-instance-cardinality* nil)
(defglobal *local-quoted-instance-cardinality* nil)
(defglobal *local-spec-cardinality* nil)
(defglobal *total-instance-cardinality* nil)
(defglobal *total-quoted-instance-cardinality* nil)
(defglobal *total-spec-cardinality* nil)
(defglobal *total-genl-cardinality* nil)
(defglobal *generality-estimate-table* nil)
(defparameter *generality-estimate-scale-factor* 100)

;;; Functions

;; (defun cardinality-estimates-initialized? () ...) -- commented declareFunction (0 0), no body
;; (defun rebuild-cardinality-estimates () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun isa-cardinality (term) ...) -- commented declareFunction (1 0), no body

(defun instance-cardinality (term)
  "[Cyc] Return an estimate of the number of instances of TERM."
  (declare (type fort-p term))
  (total-instance-cardinality term))

;; (defun quoted-instance-cardinality (term) ...) -- commented declareFunction (1 0), no body

(defun genl-cardinality (term)
  "[Cyc] Return an estimate of the number of generalizations of TERM."
  (declare (type fort-or-chlmt-p term))
  (total-genl-cardinality term))

(defun spec-cardinality (term)
  "[Cyc] Return an estimate of the number of specializations of TERM."
  (declare (type fort-or-chlmt-p term))
  (when (hlmt-naut-p term)
    (setf term (hlmt-monad-mt term)))
  (total-spec-cardinality term))

(defun use-cardinality (term)
  "[Cyc] Return an estimate of the number of uses generalized by TERM."
  (declare (type fort-or-chlmt-p term))
  (+ (instance-cardinality term) (spec-cardinality term)))

;; (defun lightest-node (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun shallowest-node (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun generality-estimate (arg1) ...) -- commented declareFunction (1 0), no body
;; (defun sort-by-generality-estimate (arg1 &optional arg2) ...) -- commented declareFunction (1 1), no body
;; (defun stable-sort-by-generality-estimate (arg1 &optional arg2) ...) -- commented declareFunction (1 1), no body
;; (defun generality-estimate< (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun generality-estimate> (arg1 arg2) ...) -- commented declareFunction (2 0), no body

(defun instance-iteration-cost (term)
  "[Cyc] Return the iteration cost for instances of TERM."
  (declare (type fort-p term))
  (instance-cardinality term))

;; (defun quoted-instance-iteration-cost (arg1) ...) -- commented declareFunction (1 0), no body
;; (defun clear-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun local-instance-cardinality (arg1) ...) -- commented declareFunction (1 0), no body
;; (defun set-local-instance-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun increment-local-instance-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun local-quoted-instance-cardinality (arg1) ...) -- commented declareFunction (1 0), no body
;; (defun set-local-quoted-instance-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun increment-local-quoted-instance-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun local-spec-cardinality (arg1) ...) -- commented declareFunction (1 0), no body
;; (defun set-local-spec-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body

(defun total-instance-cardinality (term)
  "[Cyc] Return the total instance cardinality of TERM."
  (gethash term *total-instance-cardinality* 0))

;; (defun set-total-instance-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun increment-total-instance-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body

(defun total-quoted-instance-cardinality (term)
  "[Cyc] Return the total quoted instance cardinality of TERM."
  (gethash term *total-quoted-instance-cardinality* 0))

;; (defun set-total-quoted-instance-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun increment-total-quoted-instance-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body

(defun total-spec-cardinality (term)
  "[Cyc] Return the total spec cardinality of TERM."
  (gethash term *total-spec-cardinality* 0))

(defun set-total-spec-cardinality (term count)
  "[Cyc] Set the total spec cardinality of TERM to COUNT."
  (setf (gethash term *total-spec-cardinality*) count)
  term)

;; (defun increment-total-spec-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body

(defun total-genl-cardinality (term)
  "[Cyc] Return the total genl cardinality of TERM."
  (gethash term *total-genl-cardinality* 0))

(defun set-total-genl-cardinality (term count)
  "[Cyc] Set the total genl cardinality of TERM to COUNT."
  (setf (gethash term *total-genl-cardinality*) count)
  term)

;; (defun get-generality-estimate (arg1) ...) -- commented declareFunction (1 0), no body

(defun set-generality-estimate (term estimate)
  "[Cyc] Set the generality estimate of TERM to ESTIMATE."
  (setf (gethash term *generality-estimate-table*) estimate)
  term)

(defun setup-cardinality-tables (estimated-size)
  "[Cyc] Set up the cardinality tables with ESTIMATED-SIZE."
  (let ((local-instance-cardinality-size (truncate estimated-size 10))
        (local-quoted-instance-cardinality-size (truncate estimated-size 10))
        (local-spec-cardinality-size (truncate estimated-size 10)))
    (let ((total-instance-cardinality-size local-instance-cardinality-size)
          (total-quoted-instance-cardinality-size local-quoted-instance-cardinality-size)
          (total-spec-cardinality-size local-spec-cardinality-size))
      (let ((total-genl-cardinality-size total-spec-cardinality-size)
            (generality-estimate-size total-spec-cardinality-size))
        (unless (hash-table-p *local-instance-cardinality*)
          (setf *local-instance-cardinality* (make-hash-table :size local-instance-cardinality-size :test #'eq)))
        (unless (hash-table-p *total-instance-cardinality*)
          (setf *total-instance-cardinality* (make-hash-table :size total-instance-cardinality-size :test #'eq)))
        (unless (hash-table-p *local-quoted-instance-cardinality*)
          (setf *local-quoted-instance-cardinality* (make-hash-table :size local-quoted-instance-cardinality-size :test #'eq)))
        (unless (hash-table-p *total-quoted-instance-cardinality*)
          (setf *total-quoted-instance-cardinality* (make-hash-table :size total-quoted-instance-cardinality-size :test #'eq)))
        (unless (hash-table-p *local-spec-cardinality*)
          (setf *local-spec-cardinality* (make-hash-table :size local-spec-cardinality-size :test #'eq)))
        (unless (hash-table-p *total-spec-cardinality*)
          (setf *total-spec-cardinality* (make-hash-table :size total-spec-cardinality-size :test #'eq)))
        (unless (hash-table-p *total-genl-cardinality*)
          (setf *total-genl-cardinality* (make-hash-table :size total-genl-cardinality-size :test #'eq)))
        (unless (hash-table-p *generality-estimate-table*)
          (setf *generality-estimate-table* (make-hash-table :size generality-estimate-size :test #'eq))))))
  estimated-size)

;; (defun clear-local-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-local-cardinalities () ...) -- commented declareFunction (0 0), no body

;; Reconstructed from Internal Constants:
;; $list15 = ((NODE-VAR MODULE &KEY PROGRESS-MESSAGE DONE) &BODY BODY) — arglist
;; $list16 = (:PROGRESS-MESSAGE :DONE) — keys list
;; $sym20-23 = gensyms MESSAGE-VAR, MODULE-VAR, TOTAL, SOFAR
;; $sym24 = CLET, $sym25 = GET-SBHL-MODULE-SIZE, $list26 = (0)
;; $sym27 = NOTING-PERCENT-PROGRESS, $sym29 = NOTE-PERCENT-PROGRESS, $sym30 = CINC
;; $sym31-32 = gensyms MODULE-VAR, LINK-VAR (duplicate MODULE-VAR = same gensym reused)
;; $sym33 = DO-SBHL-GRAPH-LINKS, $kw34 = :MODULE, $sym35 = IGNORE
;; Pattern: bind module, compute total via get-sbhl-module-size, iterate graph links
;; with noting-percent-progress wrapper, ignoring link-var and tracking progress.
;; The :done keyword is passed through to do-sbhl-graph-links for early termination.
(defmacro do-sbhl-module-nodes ((node-var module &key progress-message done) &body body)
  (let ((message-var (make-symbol "MESSAGE-VAR"))
        (module-var (make-symbol "MODULE-VAR"))
        (total (make-symbol "TOTAL"))
        (sofar (make-symbol "SOFAR"))
        (link-var (make-symbol "LINK-VAR")))
    `(let ((,message-var ,progress-message)
           (,module-var ,module)
           (,total (get-sbhl-module-size ,module-var))
           (,sofar 0))
       (noting-percent-progress (,message-var)
         (do-sbhl-graph-links (,node-var ,link-var :module ,module-var
                                                   ,@(when done `(:done ,done)))
           (declare (ignore ,link-var))
           (note-percent-progress ,sofar ,total)
           (incf ,sofar)
           ,@body)))))

;; (defun get-sbhl-module-size (arg1) ...) -- commented declareFunction (1 0), no body
;; (defun initialize-collection-local-spec-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-collection-local-instance-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-collection-local-quoted-instance-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-predicate-local-spec-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-microtheory-local-spec-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-other-local-instance-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun clear-total-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-total-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-collection-total-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-predicate-total-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-microtheory-total-cardinalities () ...) -- commented declareFunction (0 0), no body
;; (defun clear-generality-estimates () ...) -- commented declareFunction (0 0), no body
;; (defun initialize-generality-estimates () ...) -- commented declareFunction (0 0), no body
;; (defun dump-cardinality-estimates-to-stream (arg1) ...) -- commented declareFunction (1 0), no body

(defun load-cardinality-estimates-from-stream (stream)
  "[Cyc] Load cardinality estimates from STREAM."
  (setf *local-instance-cardinality* (cfasl-input stream))
  (setf *local-quoted-instance-cardinality* (cfasl-input stream))
  (setf *local-spec-cardinality* (cfasl-input stream))
  (setf *total-instance-cardinality* (cfasl-input stream))
  (setf *total-quoted-instance-cardinality* (cfasl-input stream))
  (setf *total-spec-cardinality* (cfasl-input stream))
  (setf *total-genl-cardinality* (cfasl-input stream))
  (setf *generality-estimate-table* (cfasl-input stream))
  nil)

(defun update-cardinality-estimates-wrt-genls (spec genl)
  "[Cyc] Conservatively update the cardinality estimates of SPEC and GENL due to a new
link between them."
  (declare (type fort-or-chlmt-p spec)
           (type fort-or-chlmt-p genl))
  (update-instance-cardinality spec genl)
  (update-spec-cardinality spec genl)
  (update-genl-cardinality spec genl)
  (update-generality-estimate spec)
  (update-generality-estimate genl)
  nil)

(defun clear-cardinality-estimates (term)
  "[Cyc] Remove TERM from any of the cardinality estimate tables."
  (remhash term *local-instance-cardinality*)
  (remhash term *local-quoted-instance-cardinality*)
  (remhash term *local-spec-cardinality*)
  (remhash term *total-instance-cardinality*)
  (remhash term *total-quoted-instance-cardinality*)
  (remhash term *total-spec-cardinality*)
  (remhash term *total-genl-cardinality*)
  (remhash term *generality-estimate-table*)
  term)

(defun update-instance-cardinality (spec genl)
  "[Cyc] Conservatively update the instance cardinality estimate due to SPEC GENL link."
  (let ((spec-card (total-instance-cardinality spec))
        (genl-card (total-instance-cardinality genl)))
    (when (> spec-card genl-card)
      (missing-larkc 3953)))
  (let ((spec-card (total-quoted-instance-cardinality spec))
        (genl-card (total-quoted-instance-cardinality genl)))
    (when (> spec-card genl-card)
      (missing-larkc 3954)))
  nil)

(defun update-spec-cardinality (spec genl)
  "[Cyc] Conservatively update the spec cardinality estimate due to SPEC GENL link."
  (let ((spec-card (total-spec-cardinality spec))
        (genl-card (total-spec-cardinality genl))
        (conservative-new-genl-card (1+ spec-card)))
    (when (> conservative-new-genl-card genl-card)
      (set-total-spec-cardinality genl conservative-new-genl-card)))
  nil)

(defun update-genl-cardinality (spec genl)
  "[Cyc] Conservatively update the genl cardinality estimate due to SPEC GENL link."
  (let ((spec-card (total-genl-cardinality spec))
        (genl-card (total-genl-cardinality genl))
        (conservative-new-spec-card (1+ genl-card)))
    (when (> conservative-new-spec-card spec-card)
      (set-total-genl-cardinality spec conservative-new-spec-card)))
  nil)

(defun update-generality-estimate (term)
  "[Cyc] Update the generality estimate for TERM."
  (let ((new-estimate (compute-generality-estimate term)))
    (set-generality-estimate term new-estimate)
    new-estimate))

(defun compute-generality-estimate (term)
  "[Cyc] Compute the generality estimate for TERM."
  (let ((scale *generality-estimate-scale-factor*)
        (numerator (* scale (use-cardinality term)))
        (denominator (max (genl-cardinality term) 1)))
    (values (truncate numerator denominator))))

;; (defun initialize-inference-test-cardinalities (arg1) ...) -- commented declareFunction (1 0), no body
;; (defun disjointness-power (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun gt-inverse-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun gt-predicate-cardinality (arg1 arg2) ...) -- commented declareFunction (2 0), no body
;; (defun gt-pred-extent-cardinality (arg1) ...) -- commented declareFunction (1 0), no body
;; (defun collection-and-specs-assertion-count (arg1 &optional arg2) ...) -- commented declareFunction (1 1), no body
;; (defun terms-assertion-count (arg1 &optional arg2 arg3) ...) -- commented declareFunction (1 2), no body
