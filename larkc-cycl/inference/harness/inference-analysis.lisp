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

(deflexical *transformation-rule-statistics-table*
  (if (and (boundp '*transformation-rule-statistics-table*)
           (typep *transformation-rule-statistics-table* 'hash-table))
      *transformation-rule-statistics-table*
      (make-hash-table :test #'eq :size 64)))

(deflexical *transformation-rule-statistics-lock*
  (if (and (boundp '*transformation-rule-statistics-lock*)
           *transformation-rule-statistics-lock*)
      *transformation-rule-statistics-lock*
      (bt:make-lock "Transformation Rule Statistics Lock")))

(deflexical *transformation-rule-statistics-filename-load-history*
  (if (and (boundp '*transformation-rule-statistics-filename-load-history*)
           *transformation-rule-statistics-filename-load-history*)
      *transformation-rule-statistics-filename-load-history*
      nil)
  "[Cyc] A list of experience filenames which have been loaded into this image to add to the transformation rule statistics.")

(defvar *transformation-rule-statistics-update-enabled?* t
  "[Cyc] When non-nil, the transformation rule statistics are updated during inference.")

(defvar *transformation-rule-historical-success-pruning-threshold* 0
  "[Cyc] Absolute historical success limit, below which rules are never even tried.")

(defvar *transformation-rule-historical-utility-pruning-threshold* -100
  "[Cyc] Absolute historical utility limit, below which rules are never even tried.")

(defparameter *save-recent-experience-lock* (bt:make-lock "Save recent experience lock")
  "[Cyc] This lock controls who actually gets to write to the experience transcript file, since multiple threads could otherwise open the same file for appending and stomp all over each other.")

(defparameter *average-rule-historical-success-probability* 0.02939361143247565d0)

(defparameter *rule-historical-success-happiness-scaling-factor* 10)

(deflexical *transformation-rule-historical-connectivity-graph*
  (if (and (boundp '*transformation-rule-historical-connectivity-graph*)
           (typep *transformation-rule-historical-connectivity-graph* 'hash-table))
      *transformation-rule-historical-connectivity-graph*
      (make-hash-table :test #'eq :size 256))
  "[Cyc] A hashtable of RULE -> a set-contents of rules that have been used in a successful proof together with RULE sometime in the past. This is an implementation of a graph; rules are nodes and edges are indicated by being present in the set-contents.")

(deflexical *transformation-rule-historical-connectivity-graph-lock*
  (if (and (boundp '*transformation-rule-historical-connectivity-graph-lock*)
           *transformation-rule-historical-connectivity-graph-lock*)
      *transformation-rule-historical-connectivity-graph-lock*
      (bt:make-lock "Rule Historical Connectivity Graph Lock")))

(defvar *hl-module-expand-counts-enabled?* nil)

(defvar *hl-module-expand-counts* (make-hash-table))

(deflexical *asked-queries-queue*
  (if (and (boundp '*asked-queries-queue*)
           *asked-queries-queue*)
      *asked-queries-queue*
      (create-queue))
  "[Cyc] The queue of asked queries to be written out.")

(defparameter *save-recent-asked-queries-lock* (bt:make-lock "Query logging lock")
  "[Cyc] The lock for the asked queries queue.")

(deflexical *asked-queries-queue-limit* 300
  "[Cyc] The limit to the number of queries we will store before writing them out.")

(deflexical *asked-query-common-symbols*
  (if (and (boundp '*asked-query-common-symbols*)
           *asked-query-common-symbols*)
      *asked-query-common-symbols*
      nil))


;;;; Functions — no body in Java (active declareFunction, no body)

;; (defun problem-store-estimated-problem-reuses-count (problem-store) ...) -- active declareFunction, no body
;; (defun problem-store-estimated-reuse-ratio (problem-store) ...) -- active declareFunction, no body

(defun clear-transformation-rule-statistics-filename-load-history ()
  (setf *transformation-rule-statistics-filename-load-history* nil)
  nil)

(defun add-to-transformation-rule-statistics-filename-load-history (filename)
  (let ((new-cons (cons filename nil))
        (list *transformation-rule-statistics-filename-load-history*))
    (if list
        (rplacd-last list new-cons)
        (setf *transformation-rule-statistics-filename-load-history* new-cons)))
  filename)

;; (defun transformation-rule-statistics-filename-load-history () ...) -- active declareFunction, no body
;; (defun transformation-rule-statistics-update-enabled? () ...) -- active declareFunction, no body
;; (defun enable-transformation-rule-statistics-update () ...) -- active declareFunction, no body
;; (defun disable-transformation-rule-statistics-update () ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list5: ((RULE-VAR &KEY RECENT? COPY? DONE) &BODY BODY)
;; $list6: (:RECENT? :COPY? :DONE), $kw7: :ALLOW-OTHER-KEYS
;; $sym11: DO-LIST, $list12: (TRANSFORMATION-RULES-WITH-STATISTICS-HELPER)
;; $sym13: PWHEN, $sym14: TRANSFORMATION-RULES-WITH-STATISTICS-CONDITION-PASSES?
;; $sym15: gensym STATISTICS-VAR, $sym16: DO-HASH-TABLE
;; $list17: (TRANSFORMATION-RULE-STATISTICS-TABLE), $sym18: IGNORE
;; When COPY? is true, iterates via do-list over a copied list from the helper.
;; When COPY? is false, iterates directly over the hash table.
;; In both cases, filters with TRANSFORMATION-RULES-WITH-STATISTICS-CONDITION-PASSES?.
(defmacro do-transformation-rules-with-statistics ((rule-var &key recent? copy? done) &body body)
  (with-temp-vars (statistics-var)
    (if copy?
        `(do-list (,rule-var (transformation-rules-with-statistics-helper) :done ,done)
           (when (transformation-rules-with-statistics-condition-passes? ,rule-var ,recent?)
             ,@body))
        `(do-hash-table (,rule-var ,statistics-var (transformation-rule-statistics-table))
           (declare (ignore ,statistics-var))
           (when (transformation-rules-with-statistics-condition-passes? ,rule-var ,recent?)
             ,@body)))))

(defun transformation-rule-statistics-table ()
  *transformation-rule-statistics-table*)

;; (defun transformation-rules-with-statistics-helper () ...) -- active declareFunction, no body

(defun transformation-rules-with-statistics-condition-passes? (rule recent?)
  (and (valid-assertion? rule)
       (or (not recent?)
           (transformation-rule-has-recent-statistics? rule))))

(defun new-transformation-rule-statistics ()
  (make-array 4 :initial-element 0))

(defun clear-all-transformation-rule-statistics ()
  (bt:with-lock-held (*transformation-rule-statistics-lock*)
    (clrhash *transformation-rule-statistics-table*)
    (clear-transformation-rule-statistics-filename-load-history))
  t)

(defun clear-transformation-rule-statistics (rule)
  (let ((result nil))
    (bt:with-lock-held (*transformation-rule-statistics-lock*)
      (setf result (remhash rule *transformation-rule-statistics-table*)))
    result))

;; (defun transformation-rules-with-statistics-count () ...) -- active declareFunction, no body

(defun get-transformation-rule-statistics (rule)
  (gethash rule *transformation-rule-statistics-table* :uninitialized))

(defun ensure-transformation-rule-statistics (rule)
  (let ((statistics (get-transformation-rule-statistics rule)))
    (when (eq :uninitialized statistics)
      (setf statistics (new-transformation-rule-statistics))
      (bt:with-lock-held (*transformation-rule-statistics-lock*)
        (setf (gethash rule *transformation-rule-statistics-table*) statistics)))
    statistics))

;; (defun transformation-rules-with-statistics (&optional sort-key sort-order) ...) -- active declareFunction, no body
;; (defun transformation-rules-with-recent-statistics () ...) -- active declareFunction, no body
;; (defun transformation-rules-with-recent-statistics-count () ...) -- active declareFunction, no body

(defun any-recent-experience? ()
  (dohash (rule statistics-var (transformation-rule-statistics-table))
    (declare (ignore statistics-var))
    (when (transformation-rules-with-statistics-condition-passes? rule t)
      (return-from any-recent-experience? t)))
  nil)

;; (defun total-transformation-rule-considered-count () ...) -- active declareFunction, no body
;; (defun total-transformation-rule-recent-considered-count () ...) -- active declareFunction, no body

(defun transformation-rule-considered-count (rule)
  (let ((statistics (get-transformation-rule-statistics rule)))
    (if (eq :uninitialized statistics)
        0
        (aref statistics 0))))

(defun transformation-rule-recent-considered-count (rule)
  (let ((statistics (get-transformation-rule-statistics rule)))
    (if (eq :uninitialized statistics)
        0
        (aref statistics 2))))

(defun transformation-rule-has-recent-statistics? (rule)
  (plusp (transformation-rule-recent-considered-count rule)))

;; (defun total-transformation-rule-success-count () ...) -- active declareFunction, no body
;; (defun total-transformation-rule-recent-success-count () ...) -- active declareFunction, no body

(defun transformation-rule-success-count (rule)
  (let ((statistics (get-transformation-rule-statistics rule)))
    (if (eq :uninitialized statistics)
        0
        (aref statistics 1))))

;; (defun transformation-rule-recent-success-count (rule) ...) -- active declareFunction, no body
;; (defun transformation-rule-success-probability (rule &optional default) ...) -- active declareFunction, no body

(defun increment-transformation-rule-considered-count (rule recent? &optional (count 1))
  "[Cyc] Note that RULE has been considered COUNT more times. If RECENT?, also queue this information for logging in the experience transcript."
  (declare (type assertion rule)
           (type integer count))
  (unless (positive-integer-p count)
    (warn "Incrementing transformation rule considered count by zero; this is is vacuous and suspicious"))
  (let ((statistics (ensure-transformation-rule-statistics rule)))
    (when *transformation-rule-statistics-update-enabled?*
      (setf (aref statistics 0) (+ (aref statistics 0) count))
      (when recent?
        (setf (aref statistics 2) (+ (aref statistics 2) count))))
    (aref statistics 0)))

(defun increment-transformation-rule-success-count (rule recent? &optional (count 1))
  "[Cyc] Note that RULE has been successfully used COUNT more times. If RECENT?, also queue this information for logging in the experience transcript."
  (declare (type assertion rule)
           (type integer count))
  (let ((statistics (ensure-transformation-rule-statistics rule)))
    (when *transformation-rule-statistics-update-enabled?*
      (setf (aref statistics 1) (+ (aref statistics 1) count))
      (when recent?
        (setf (aref statistics 3) (+ (aref statistics 3) count))))
    (aref statistics 1)))

;; (defun clear-all-recent-transformation-rule-statistics () ...) -- active declareFunction, no body
;; (defun clear-transformation-rule-recent-counts (rule) ...) -- active declareFunction, no body
;; (defun clean-transformation-rule-statistics () ...) -- active declareFunction, no body

(defun transformation-rule-has-insufficient-historical-utility? (rule)
  (if (and (= 0 *transformation-rule-historical-success-pruning-threshold*)
           (= -100 *transformation-rule-historical-utility-pruning-threshold*))
      nil
      (or (< (transformation-rule-success-count rule)
              *transformation-rule-historical-success-pruning-threshold*)
          (< (transformation-rule-historical-utility rule)
              *transformation-rule-historical-utility-pruning-threshold*))))

;; (defun rule-historical-utility-success-threshold (&optional threshold) ...) -- active declareFunction, no body
;; (defun rule-historical-utility-saved-considerations (&optional threshold) ...) -- active declareFunction, no body
;; (defun transformation-rules-considered-with-success () ...) -- active declareFunction, no body
;; (defun transformation-rules-considered-with-no-success () ...) -- active declareFunction, no body
;; (defun transformation-rules-considered-with-success-from-mt (mt) ...) -- active declareFunction, no body
;; (defun transformation-rules-considered-with-no-success-from-mt (mt) ...) -- active declareFunction, no body
;; (defun transformation-rules-considered-with-no-success-not-in-mts (mts) ...) -- active declareFunction, no body
;; (defun transformation-rule-mts-considered-with-success () ...) -- active declareFunction, no body
;; (defun transformation-rule-mts-considered-with-no-success () ...) -- active declareFunction, no body
;; (defun transformation-rules-considered-with-success-proving-predicate (predicate) ...) -- active declareFunction, no body
;; (defun transformation-rules-considered-with-no-success-proving-predicate (predicate) ...) -- active declareFunction, no body
;; (defun transformation-rule-predicates-considered-with-success () ...) -- active declareFunction, no body
;; (defun transformation-rule-predicates-considered-with-no-success () ...) -- active declareFunction, no body
;; (defun reinforce-transformation-rule (rule &optional count) ...) -- active declareFunction, no body
;; (defun reinforce-inference-transformation-rules-in-answers (inference &optional count) ...) -- active declareFunction, no body
;; (defun reinforce-inference-transformation-rules (inference &optional count) ...) -- active declareFunction, no body
;; (defun save-transformation-rule-statistics (filename &optional recent?) ...) -- active declareFunction, no body

(defun load-transformation-rule-statistics (filename &optional (merge? t))
  (load-transformation-rule-statistics-int filename merge? nil))

;; (defun load-transformation-rule-statistics-except-for-rules (filename exclude-rules &optional merge?) ...) -- active declareFunction, no body

(defun load-transformation-rule-statistics-int (filename merge? exclude-rules)
  (let ((exclude-rule-set (when exclude-rules
                            (construct-set-from-list exclude-rules))))
    (load-transformation-rule-statistics-bookkeeping filename merge?)
    (with-open-file (stream filename :element-type '(unsigned-byte 8))
      (let* ((count (cfasl-input stream))
             (i 0))
        (loop while (< i count) do
          (load-transformation-rule-statistics-for-rule stream exclude-rule-set)
          (incf i))))
    nil))

(defun load-transformation-rule-statistics-bookkeeping (filename merge?)
  (must *transformation-rule-statistics-update-enabled?*
    "Transformation rule statistics updating is not enabled.")
  (unless merge?
    (clear-all-transformation-rule-statistics))
  (add-to-transformation-rule-statistics-filename-load-history filename)
  nil)

;; (defun save-recent-transformation-rule-statistics (filename) ...) -- active declareFunction, no body
;; (defun save-transformation-rule-statistics-for-rule (stream rule considered success) ...) -- active declareFunction, no body

(defun load-transformation-rule-statistics-for-rule (stream exclude-rule-set)
  "[Cyc] @param EXCLUDE-RULE-SET don't load in statistics for any rule in EXCLUDE-RULE-SET."
  (let* ((rule (cfasl-input stream))
         (considered (cfasl-input stream))
         (success (cfasl-input stream)))
    (when (and (non-negative-integer-p considered)
               (non-negative-integer-p success)
               (valid-assertion? rule)
               (not (and exclude-rule-set
                         (set-member? rule exclude-rule-set))))
      (increment-transformation-rule-considered-count rule nil considered)
      (increment-transformation-rule-success-count rule nil success))
    rule))

;; (defun show-transformation-rule-statistics (&optional sort-key stream) ...) -- active declareFunction, no body

(defun possibly-save-recent-experience ()
  (if (lock-idle-p *save-recent-experience-lock*)
      (save-recent-experience)
      nil))

(defun save-recent-experience ()
  (when (any-recent-experience?)
    (bt:with-lock-held (*save-recent-experience-lock*)
      ;; Likely calls save-recent-experience-internal which writes experience to transcript.
      (missing-larkc 32996))
    t))

;; (defun local-experience-transcript () ...) -- active declareFunction, no body
;; (defun save-recent-experience-internal () ...) -- active declareFunction, no body
;; (defun replace-and-collate-experience (old-filename new-filename) ...) -- active declareFunction, no body
;; (defun collate-experience (filename) ...) -- active declareFunction, no body
;; (defun load-all-experience-transcripts-from-directory (directory) ...) -- active declareFunction, no body
;; (defun transformation-rule-utility-experience-filename? (filename) ...) -- active declareFunction, no body
;; (defun load-experience-transcript (filename) ...) -- active declareFunction, no body

(defun transformation-rule-historical-utility (rule)
  "[Cyc] Return number between -100 and 100 indicating the historical utility of RULE. 100 is most useful, 0 is of average utility, and -100 is most useless."
  (rule-historical-utility-from-observations
   (transformation-rule-success-count rule)
   (transformation-rule-considered-count rule)))

;; (defun transformation-rule-historical-utility-> (rule1 rule2) ...) -- active declareFunction, no body
;; (defun current-average-rule-historical-success-probability (&optional recalculate?) ...) -- active declareFunction, no body

(defun rule-historical-utility-from-observations (success considered)
  (historical-utility-from-observations
   success considered
   *average-rule-historical-success-probability*
   *rule-historical-success-happiness-scaling-factor*))

(defun historical-utility-from-observations (success considered
                                             average-historical-probability
                                             utility-scaling-factor)
  (if (not (plusp considered))
      0
      (let ((probability (/ success considered)))
        (cond ((> probability average-historical-probability)
               (let* ((raw-utility (* utility-scaling-factor
                                     (/ (- probability average-historical-probability)
                                        (- 1 average-historical-probability))
                                     (integer-length considered)))
                      (utility (truncate (min 100 raw-utility))))
                 utility))
              ((< probability average-historical-probability)
               (let* ((raw-utility (* utility-scaling-factor
                                     (/ (- probability average-historical-probability)
                                        average-historical-probability)
                                     (integer-length considered)))
                      (utility (truncate (max -100 raw-utility))))
                 utility))
              (t
               0)))))

;; (defun repair-all-experience-files-in-directory (directory) ...) -- active declareFunction, no body
;; (defun repair-experience-file (filename) ...) -- active declareFunction, no body
;; (defun load-transformation-rule-statistics-ignoring-header (filename stream) ...) -- active declareFunction, no body
;; (defun historically-connected-rules-set-contents (rule) ...) -- active declareFunction, no body
;; (defun set-historically-connected-rules-set-contents (rule set-contents) ...) -- active declareFunction, no body
;; (defun rules-historically-connected? (rule1 rule2) ...) -- active declareFunction, no body
;; (defun historically-connected-rules (rule) ...) -- active declareFunction, no body
;; (defun rule-historical-connectedness-ratio (rule) ...) -- active declareFunction, no body
;; (defun rule-historical-connectedness-percentage (rule) ...) -- active declareFunction, no body
;; (defun note-rules-historically-connected (rule1 rule2) ...) -- active declareFunction, no body

(defun note-inference-answer-proof-rules (rules)
  "[Cyc] Notes that the rules in RULE-SET-CONTENTS have been successfully used together in an inference answer proof."
  (when (length>= rules 2)
    (dolist (rule rules)
      (dolist (connected-rule rules)
        (unless (eq rule connected-rule)
          ;; Likely calls note-rules-historically-connected to record the edge in the connectivity graph.
          (missing-larkc 32992))))
    t))

;; (defun show-transformation-rule-historical-connectivity-graph (&optional stream) ...) -- active declareFunction, no body
;; (defun save-transformation-rule-historical-connectivity-graph (filename &optional recent?) ...) -- active declareFunction, no body
;; (defun load-transformation-rule-historical-connectivity-graph (filename) ...) -- active declareFunction, no body
;; (defun clear-hl-module-expand-counts () ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $sym73: CLET, $list74: ((*HL-MODULE-EXPAND-COUNTS-ENABLED?* T) (*HL-MODULE-EXPAND-COUNTS* (NEW-DICTIONARY)))
;; Binds the two special variables to enable and collect HL module expand counts, then runs body.
(defmacro noting-hl-module-expand-counts (&body body)
  `(let ((*hl-module-expand-counts-enabled?* t)
         (*hl-module-expand-counts* (make-hash-table)))
     ,@body))

;; (defun hl-module-expand-count (hl-module) ...) -- active declareFunction, no body
;; (defun all-hl-module-expand-counts () ...) -- active declareFunction, no body

(defun cinc-hl-module-expand-count (hl-module)
  (when *hl-module-expand-counts-enabled?*
    (let ((count (gethash hl-module *hl-module-expand-counts* 0)))
      (setf count (+ count 1))
      (setf (gethash hl-module *hl-module-expand-counts*) count)))
  nil)

;; (defun show-hl-module-expand-counts (&optional sort-key stream) ...) -- active declareFunction, no body

(defun cinc-module-expand-count (name)
  (let ((hl-module (find-hl-module-by-name name)))
    (cinc-hl-module-expand-count hl-module)))

(defun clear-asked-query-queue ()
  (clear-queue *asked-queries-queue*)
  nil)

(defun possibly-enqueue-asked-query (query-sentence query-mt query-properties)
  (let ((result nil))
    (when (save-asked-queries?)
      (unless (missing-larkc 22953)
        ;; Likely checks if the query is already queued or otherwise should not be enqueued.
        (setf result (missing-larkc 32981))))
    ;; Likely calls enqueue-asked-query to add the query to the queue.
    result))

;; (defun enqueue-asked-query (query-sentence query-mt query-properties) ...) -- active declareFunction, no body

(defun possibly-enqueue-asked-query-from-inference (inference)
  (let ((result nil))
    (when (save-asked-queries?)
      (unless (missing-larkc 22954)
        ;; Likely checks if the inference query is already queued.
        (setf result (missing-larkc 32983))))
    ;; Likely calls enqueue-asked-query-from-inference to add the inference query to the queue.
    result))

;; (defun enqueue-asked-query-from-inference (inference) ...) -- active declareFunction, no body

(defun possibly-save-recent-asked-queries ()
  "[Cyc] Save recent asked queries, if it appears sensible to do so."
  (if (lock-idle-p *save-recent-asked-queries-lock*)
      (save-recent-asked-queries)
      nil))

;; (defun load-asked-queries (filename &optional handler) ...) -- active declareFunction, no body
;; (defun query-info-p (object) ...) -- active declareFunction, no body
;; (defun valid-query-info? (object) ...) -- active declareFunction, no body
;; (defun load-asked-query (stream) ...) -- active declareFunction, no body

(defun save-recent-asked-queries ()
  (let ((any-saved? nil))
    (when (any-recent-asked-queries?)
      (bt:with-lock-held (*save-recent-asked-queries-lock*)
        (setf any-saved? (save-recent-asked-queries-int))))
    any-saved?))

(defun any-recent-asked-queries? ()
  (not (queue-empty-p *asked-queries-queue*)))

(defun local-asked-queries-transcript ()
  (replace-substring
   (replace-substring
    (construct-transcript-filename
     (make-local-transcript-filename "asked-queries"))
    ".TS" ".CFASL")
   ".ts" ".cfasl"))

(defun save-recent-asked-queries-int ()
  (let ((local-asked-queries-transcript (local-asked-queries-transcript))
        (success? nil)
        (error nil))
    (when local-asked-queries-transcript
      (catch-error-message (error)
        (setf success? (save-recent-asked-queries-to-file local-asked-queries-transcript))))
    (and success? (not error))))

(defun save-recent-asked-queries-to-file (filename)
  (with-open-file (stream filename :element-type '(unsigned-byte 8)
                                   :direction :output
                                   :if-exists :append
                                   :if-does-not-exist :create)
    (let ((q *asked-queries-queue*))
      (loop until (queue-empty-p q) do
        (let ((query (dequeue q)))
          (write-asked-query-to-stream stream query t)))))
  t)

(defun write-asked-query-to-stream (stream query-info externalized?)
  (let ((*cfasl-common-symbols* nil))
    (cfasl-set-common-symbols (asked-query-common-symbols))
    (cfasl-output-maybe-externalized query-info stream externalized?))
  query-info)

;; (defun load-asked-query-from-stream (stream) ...) -- active declareFunction, no body
;; (defun asked-queries-filename? (filename) ...) -- active declareFunction, no body

(defun asked-query-common-symbols ()
  (unless *asked-query-common-symbols*
    (setf *asked-query-common-symbols*
          (append (all-query-properties)
                  (list (reader-make-constant-shell "and")
                        (reader-make-constant-shell "isa")
                        (reader-make-constant-shell "InferencePSC")
                        (reader-make-constant-shell "quotedIsa")
                        (reader-make-constant-shell "resultGenls")
                        (reader-make-constant-shell "resultIsa")
                        (reader-make-constant-shell "resultQuotedIsa")
                        (reader-make-constant-shell "termOfUnit")))))
  *asked-query-common-symbols*)

;; (defun show-asked-query-statistics (directory) ...) -- active declareFunction, no body
;; (defun show-asked-query-statistics-int (directory stream callback) ...) -- active declareFunction, no body
;; (defun write-inference-heuristic-ke-file (filename mt &optional stream) ...) -- active declareFunction, no body
;; (defun write-inference-heuristic-ke-file-to-stream (stream &optional mt) ...) -- active declareFunction, no body
;; (defun write-irrelevant-mts-ke-file-section (stream mt) ...) -- active declareFunction, no body
;; (defun write-backchain-forbidden-ke-file-section (stream mt) ...) -- active declareFunction, no body
;; (defun write-irrelevant-assertion-ke-file-section (stream mt) ...) -- active declareFunction, no body


;;;; Setup

(toplevel
  (declare-defglobal '*transformation-rule-statistics-table*)
  (declare-defglobal '*transformation-rule-statistics-lock*)
  (declare-defglobal '*transformation-rule-statistics-filename-load-history*)
  (register-macro-helper 'transformation-rule-statistics-table
                         'do-transformation-rules-with-statistics)
  (register-macro-helper 'transformation-rules-with-statistics-helper
                         'do-transformation-rules-with-statistics)
  (register-macro-helper 'transformation-rules-with-statistics-condition-passes?
                         'do-transformation-rules-with-statistics)
  (declare-defglobal '*transformation-rule-historical-connectivity-graph*)
  (declare-defglobal '*transformation-rule-historical-connectivity-graph-lock*)
  (register-global-lock '*transformation-rule-historical-connectivity-graph-lock*
                        "Rule Historical Connectivity Graph Lock")
  (declare-defglobal '*asked-queries-queue*)
  (declare-defglobal '*asked-query-common-symbols*))
