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


;; Most dump_* functions have no body in LarKC (stripped); the load counterparts
;; remain. Commented //declareMacro entries at top of declare-file reconstruct
;; to with-*-dump-id-table / with-kb-*-ids / with-kb-dump-filename /
;; with-kb-dump-binary-file / with-kb-dump-text-file / with-kb-load-area-allocation
;; / without-kb-load-area-allocation — all dump-side macros whose bodies are not
;; reconstructible from this file's Internal Constants alone; marked TODO below.

(deflexical *force-monolithic-kb-assumption*
    (if (boundp '*force-monolithic-kb-assumption*)
        *force-monolithic-kb-assumption*
        nil)
  "[Cyc] Force the KB to be completely stored in memory and therefore able written out as a single image file with no other dependencies.")

(defun force-monolithic-kb-assumption? ()
  (symbol-value '*force-monolithic-kb-assumption*))

;; TODO - reconstruct macro body from evidence; arglist from $list12:
;; ((FILENAME-VAR FILENAME) &BODY BODY).
;; Evidence: expansions call DISCARD-DUMP-FILENAME ($sym13) at end.
;; Likely wraps body with (unwind-protect BODY (discard-dump-filename FILENAME-VAR)).
;; Used with filename gensym that is filled with spaces on exit (see discard-dump-filename).
(defmacro with-kb-dump-filename ((filename-var filename) &body body)
  `(let ((,filename-var ,filename))
     (unwind-protect
          (progn ,@body)
       (discard-dump-filename ,filename-var))))

;; TODO - reconstruct macro body; arglist from $list14:
;; ((STREAM FILENAME DIRECTION) &BODY BODY).
;; Evidence: $sym15/18 = makeUninternedSymbol("FILENAME-VAR"), $sym16 = WITH-KB-DUMP-FILENAME,
;; $sym17 = WITH-PRIVATE-BINARY-FILE. Nests WITH-KB-DUMP-FILENAME around
;; WITH-PRIVATE-BINARY-FILE over the stream.
(defmacro with-kb-dump-binary-file ((stream filename direction) &body body)
  (with-temp-vars (filename-var)
    `(with-kb-dump-filename (,filename-var ,filename)
       (with-private-binary-file (,stream ,filename-var ,direction)
         ,@body))))

;; TODO - reconstruct macro body; arglist from $list14:
;; ((STREAM FILENAME DIRECTION) &BODY BODY).
;; Evidence: $sym19 = WITH-PRIVATE-TEXT-FILE. Nests WITH-KB-DUMP-FILENAME around
;; WITH-PRIVATE-TEXT-FILE over the stream.
(defmacro with-kb-dump-text-file ((stream filename direction) &body body)
  (with-temp-vars (filename-var)
    `(with-kb-dump-filename (,filename-var ,filename)
       (with-private-text-file (,stream ,filename-var ,direction)
         ,@body))))

;; TODO - reconstruct macro bodies for commented declareMacros:
;;   with-kb-dump-ids, with-kb-load-ids, with-kb-load-area-allocation,
;;   without-kb-load-area-allocation.
;; Evidence: $list9 binds 6 *cfasl-*-lookup-func* params to 'find-*-by-dump-id symbols
;; around body (used by load path in kb-load-from-directory as an open-coded expansion);
;; $list10 binds *structure-resourcing-make-static*+*cfasl-input-to-static-area* to T
;; (with-kb-load-area-allocation), $list11 binds them both to NIL
;; (without-kb-load-area-allocation). The with-kb-dump-ids / with-kb-load-ids arglists are
;; unknown without visible expansions.

(defun discard-dump-filename (filename)
  (declare (type string filename))
  (fill filename #\Space))

(deflexical *default-dump-path* (list "units")
  "[Cyc] The default directory chain for KB dumps under the Cyc Home directory.")

(defparameter *default-dump-extension* "cfasl"
  "[Cyc] The default extension for all KB dump files.")

(defparameter *default-dump-product-extension* "fht"
  "[Cyc] The default extension for all KB dump product files.")

(defun kb-dump-file (name directory-path &optional (extension *default-dump-extension*))
  "[Cyc] Return the KB dump file NAME.EXTENSION in the dump directory DIRECTORY-PATH"
  (relative-filename directory-path name extension))

(deflexical *dump-bytes-per-assertion* 192
  "[Cyc] Dump size scaling factor in number of bytes per assertion.")

(defparameter *dump-verify* t
  "[Cyc] Verify the existence of dump files when non-nil.")

(defun verify-file-existence (filename &optional warn-only?)
  "[Cyc] Generate an error if FILENAME does not exist.
@param WARN-ONLY?; if t, warns instead of errors if FILENAME does not exist."
  (declare (type string filename))
  (when *dump-verify*
    (unless (probe-file filename)
      (if warn-only?
          (warn "file ~s not found" filename)
          (error "file ~s not found" filename))
      (return-from verify-file-existence nil)))
  t)

(defparameter *kb-load-gc-checkpoints-enabled?* nil
  "[Cyc] When T, the load process attempts to GC and make static the memory that has
 been recently allocated after each key point where a major chunk of KB content
 has been loaded.")

(defun kb-load-gc-checkpoint ()
  (when *kb-load-gc-checkpoints-enabled?*
    ;; Original body stripped in LarKC (Java has empty then-branch).
    nil)
  nil)

(defparameter *dump-verbose* t)

(defun load-kb (directory-path)
  "[Cyc] Load the KB from the dump directory in DIRECTORY-PATH."
  (when *dump-verbose*
    (format *standard-output* "~&~%;;; Loading KB from ~A at ~A~%" directory-path (timestring))
    (force-output *standard-output*))
  (let ((load-time nil))
    (let ((*save-asked-queries?* nil))
      (let ((time-var (get-internal-real-time)))
        (kb-load-from-directory directory-path)
        (load-kb-initializations)
        (cond
          ((force-monolithic-kb-assumption?)
           ;; Likely did (swap-out-and-finalize-kb-objects ...) / finalization
           ;; for monolithic-image KBs — contextual with swap-out branch below.
           (missing-larkc 2354)
           (kb-load-gc-checkpoint))
          (t
           (swap-out-all-pristine-kb-objects)
           (enforce-standard-kb-sbhl-caching-policies directory-path)
           (kb-load-gc-checkpoint)))
        (setf load-time (/ (- (get-internal-real-time) time-var) internal-time-units-per-second))
        (when *dump-verbose*
          (format t "~&~%;;; Load of KB ~A completed (~A) at ~A~%"
                  (kb-loaded) (elapsed-time-abbreviation-string load-time) (timestring))
          (kb-statistics *standard-output*)
          (force-output *standard-output*)))))
  (kb-loaded))

(defun kb-load-from-directory (directory-path)
  (kb-load-gc-checkpoint)
  (let ((common-symbols (load-special-objects directory-path)))
    (when (null *force-monolithic-kb-assumption*)
      (initialize-hl-store-cache-directory-and-shared-symbols directory-path common-symbols)
      (kb-load-gc-checkpoint))
    (let ((*cfasl-common-symbols* nil))
      (cfasl-set-common-symbols common-symbols)
      (let ((*cfasl-constant-handle-lookup-func* 'find-constant-by-dump-id)
            (*cfasl-nart-handle-lookup-func* 'find-nart-by-dump-id)
            (*cfasl-assertion-handle-lookup-func* 'find-assertion-by-dump-id)
            (*cfasl-deduction-handle-lookup-func* 'find-deduction-by-dump-id)
            (*cfasl-kb-hl-support-handle-lookup-func* 'find-kb-hl-support-by-dump-id)
            (*cfasl-clause-struc-handle-lookup-func* 'find-clause-struc-by-dump-id))
        (load-essential-kb directory-path)
        (load-computable-content directory-path))))
  nil)

(defun load-essential-kb (directory-path)
  (when *dump-verbose*
    (format *standard-output* "~&~%;;; Loading essential KB at ~A~%" (timestring))
    (force-output *standard-output*))
  (let ((*structure-resourcing-make-static* t)
        (*cfasl-input-to-static-area* t))
    (setup-kb-state-from-dump directory-path)
    (kb-load-gc-checkpoint)
    (load-constant-shells directory-path)
    (kb-load-gc-checkpoint)
    (load-nart-shells directory-path)
    (kb-load-gc-checkpoint)
    (load-assertion-shells directory-path)
    (kb-load-gc-checkpoint)
    (load-kb-hl-support-shells directory-path)
    (kb-load-gc-checkpoint)
    (load-clause-struc-defs directory-path)
    (kb-load-gc-checkpoint)
    (load-deduction-defs directory-path)
    (kb-load-gc-checkpoint)
    (load-assertion-defs directory-path)
    (kb-load-gc-checkpoint)
    (load-kb-hl-support-defs directory-path)
    (kb-load-gc-checkpoint)
    (load-bookkeeping-assertions directory-path)
    (kb-load-gc-checkpoint)
    (load-experience directory-path)
    (kb-load-gc-checkpoint))
  (load-essential-kb-initializations)
  nil)

(defun load-essential-kb-initializations ()
  "[Cyc] Initialize the non-dumpable but computable KB aspects exclusively
 dependent on the essential KB that other computable KB aspects,
 whether dumpable or not, are dependent upon"
  (initialize-kb-features)
  nil)

(defun load-computable-kb-initializations ()
  "[Cyc] Initialize the non-dumpable but computable KB aspects exclusively
 dependent on the computable KB (e.g.indexing), but not on the remaining HL"
  nil)

(defun load-computable-remaining-hl-low-initializations ()
  "[Cyc] Initialize the non-dumpable but computable KB aspects
 dependent on SBHL and arg type caches."
  (initialize-sublid-mappings)
  nil)

(defun load-computable-content (directory-path)
  (load-computable-kb directory-path)
  (load-computable-remaining-hl directory-path)
  nil)

(defun load-computable-kb (directory-path)
  (when *dump-verbose*
    (format *standard-output* "~&~%;;; Loading computable KB at ~A~%" (timestring))
    (force-output *standard-output*))
  (let ((*structure-resourcing-make-static* t)
        (*cfasl-input-to-static-area* t))
    (load-kb-unrepresented-terms directory-path)
    (kb-load-gc-checkpoint)
    (load-kb-indexing directory-path)
    (kb-load-gc-checkpoint)
    (load-rule-set directory-path)
    (kb-load-gc-checkpoint))
  (load-computable-kb-initializations)
  nil)

(defun load-computable-remaining-hl (directory-path)
  (when *dump-verbose*
    (format *standard-output* "~&~%;;; Loading computable remaining HL at ~A~%" (timestring))
    (force-output *standard-output*))
  (let ((*structure-resourcing-make-static* t)
        (*cfasl-input-to-static-area* t))
    (load-nart-hl-formulas directory-path)
    (kb-load-gc-checkpoint)
    (load-miscellaneous directory-path)
    (kb-load-gc-checkpoint)
    (load-sbhl-data directory-path)
    (kb-load-gc-checkpoint)
    (load-sbhl-cache directory-path)
    (kb-load-gc-checkpoint)
    (load-cardinality-estimates directory-path)
    (kb-load-gc-checkpoint)
    (load-arg-type-cache directory-path)
    (kb-load-gc-checkpoint)
    (load-defns-cache directory-path)
    (kb-load-gc-checkpoint)
    (load-somewhere-cache directory-path)
    (kb-load-gc-checkpoint)
    (load-arity-cache directory-path)
    (kb-load-gc-checkpoint)
    (load-tva-cache directory-path)
    (kb-load-gc-checkpoint)
    (load-computable-remaining-hl-low-initializations))
  nil)

(defun rebuild-computable-but-not-dumpable-yet ()
  "[Cyc] These are former 'initializations' that are rebuilding expensive (in both time and space) structures and so should *not* be part of load-kb-initializations, but part of [dump/load/rebuild]-computable-remaining-hl.  The refactoring to do that requires: identifying the initializations the rebuild depends on and adding it before the rebuild in rebuild-computable-remaining-hl (@see lexicon-cache's dependency on initialize-lexicon-modules), then making the structures dump/loadable, which in the case of most of these is non-trivial."
  (when *dump-verbose*
    (format *standard-output* "~&~%;;; Rebuilding computable-but-not-dumpable-yet-KB at ~A~%" (timestring))
    (force-output *standard-output*))
  (let ((*wff-memoization-state* (possibly-new-wff-memoization-state)))
    (let ((local-state *wff-memoization-state*))
      (let ((*memoization-state* local-state))
        (let ((original-memoization-process nil))
          (when (and local-state
                     (null (memoization-state-lock local-state)))
            (setf original-memoization-process
                  (memoization-state-get-current-process-internal local-state))
            (let ((current-proc (current-process)))
              (cond
                ((null original-memoization-process)
                 (memoization-state-set-current-process-internal local-state current-proc))
                ((not (eq original-memoization-process current-proc))
                 (error "Invalid attempt to reuse memoization state in multiple threads simultaneously.")))))
          (unwind-protect
               (unless (within-wff?)
                 (reset-wff-state))
            (let ((*is-thread-performing-cleanup?* t))
              (let ((already-resourcing-p *resourcing-sbhl-marking-spaces-p*))
                (let ((*resourced-sbhl-marking-space-limit*
                        (determine-resource-limit already-resourcing-p 12))
                      (*resourced-sbhl-marking-spaces*
                        (possibly-new-marking-resource already-resourcing-p))
                      (*resourcing-sbhl-marking-spaces-p* t))
                  (declare (ignorable *resourced-sbhl-marking-space-limit*
                                      *resourced-sbhl-marking-spaces*
                                      *resourcing-sbhl-marking-spaces-p*))))
              (when (and local-state
                         (null original-memoization-process))
                (memoization-state-set-current-process-internal local-state nil))))))))
  nil)

(defun load-copyright (stream)
  (let ((copyright (cfasl-input stream)))
    (declare (type string copyright))
    copyright))

(defun load-unit-file (dump-directory filename load-func progress-message)
  "[Cyc] A helper used for a few of the KB object load methods.
@param LOAD-FUNC; a unary function-spec-p that takes a stream as its single argument."
  (declare (type string dump-directory filename progress-message)
           (type symbol load-func))
  (let ((unit-file (kb-dump-file filename dump-directory)))
    (when (verify-file-existence unit-file t)
      (let ((filename-var unit-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-9 stream)
                      (total (file-length stream-9)))
                 (load-copyright stream-9)
                 (let ((*noting-progress-start-time* (get-universal-time)))
                   (noting-progress-preamble progress-message)
                   (funcall load-func stream-9)
                   (unless (eq (cfasl-input stream-9 nil :eof) :eof)
                     (warn "~d bytes of unread stuff in ~S"
                           (- total (get-file-position stream-9)) unit-file))
                   (noting-progress-postamble))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  nil)

(defun load-kb-object-count (directory-path filename)
  (let ((result nil)
        (text-file (kb-dump-file filename directory-path "text")))
    (when (verify-file-existence text-file t)
      (let ((filename-var text-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-text filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-11 stream)
                      (count (read stream-11)))
                 (declare (type integer count))
                 (setf result count)))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var)))
    result))

(defparameter *kb-dump-common-symbols*
  (append (valid-hl-truth-values)
          (valid-directions)
          (asserted-argument-tokens)
          (hl-support-modules)
          (valid-hash-test-symbols)
          '(:unnamed :variable-names :dependents :index :assert-info)))

(defun load-special-objects (directory-path)
  (let ((special-objects-file (kb-dump-file "special" directory-path))
        (ans nil))
    (when (verify-file-existence special-objects-file)
      (let ((*noting-progress-start-time* (get-universal-time)))
        (noting-progress-preamble "Loading special objects...")
        (let ((filename-var special-objects-file)
              (stream nil))
          (unwind-protect
               (progn
                 (let ((*stream-requires-locking* nil))
                   (setf stream (open-binary filename-var :input)))
                 (unless (streamp stream)
                   (error "Unable to open ~S" filename-var))
                 (let ((stream-16 stream))
                   (let ((*cfasl-common-symbols* nil))
                     (cfasl-set-common-symbols nil)
                     (load-copyright stream-16)
                     (setf ans (cfasl-input stream-16)))))
            (let ((*is-thread-performing-cleanup?* t))
              (when (streamp stream)
                (close stream))))
          (discard-dump-filename filename-var))
        (noting-progress-postamble)))
    ans))

(defun load-kb-product-shared-symbols (directory-path)
  "[Cyc] An accessor for load-special-objects, currently required by HL module stores.  Also quieter than load-special-objects since callers should print their own progress at a higher level."
  (let ((result nil))
    (let ((*dump-verbose* nil)
          (*silent-progress?* t))
      (setf result (load-special-objects directory-path)))
    result))

(defun setup-kb-state-from-dump (directory-path)
  (let ((constant-count (load-constant-count directory-path))
        (nart-count (load-nart-count directory-path))
        (assertion-count (load-assertion-count directory-path))
        (deduction-count (load-deduction-count directory-path))
        (kb-hl-support-count (load-kb-hl-support-count directory-path))
        (clause-struc-count (load-clause-struc-count directory-path))
        (kb-unrepresented-term-count (load-kb-unrepresented-term-count directory-path)))
    (declare (type integer constant-count))
    (cond
      ((and nart-count assertion-count deduction-count kb-hl-support-count
            clause-struc-count kb-unrepresented-term-count)
       (setup-kb-tables-int t constant-count nart-count assertion-count deduction-count
                            kb-hl-support-count clause-struc-count kb-unrepresented-term-count)
       (clear-kb-state-int))
      (t
       ;; Likely did per-table error reporting when one or more counts were NIL.
       ;; Evidence: this is the fail branch when any KB-object count is missing.
       (missing-larkc 4883))))
  nil)

(defun load-constant-count (directory-path)
  "[Cyc] @return 0 integerp; the constant count
@return 1 booleanp; whether the constants are dense"
  (let ((count (load-kb-object-count directory-path "constant-count")))
    (if count
        (values count t)
        (let ((result nil)
              (cfasl-file (kb-dump-file "constant-shell" directory-path)))
          (when (verify-file-existence cfasl-file)
            (let ((filename-var cfasl-file)
                  (stream nil))
              (unwind-protect
                   (progn
                     (let ((*stream-requires-locking* nil))
                       (setf stream (open-binary filename-var :input)))
                     (unless (streamp stream)
                       (error "Unable to open ~S" filename-var))
                     (let ((stream-23 stream))
                       (load-copyright stream-23)
                       (let ((constant-count (cfasl-input stream-23)))
                         (setf result constant-count))))
                (let ((*is-thread-performing-cleanup?* t))
                  (when (streamp stream)
                    (close stream))))
              (discard-dump-filename filename-var)))
          (values result nil)))))

(defun load-constant-shells (directory-path)
  (let ((cfasl-file (kb-dump-file "constant-shell" directory-path)))
    (when (verify-file-existence cfasl-file)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-24 stream)
                      (total (file-length stream-24)))
                 (load-copyright stream-24)
                 (cfasl-input stream-24)
                 (noting-percent-progress ("Loading constant shells")
                   (do ((dump-id (cfasl-input stream-24 nil) (cfasl-input stream-24 nil)))
                       ((eq dump-id :eof))
                     (note-percent-progress (get-file-position stream-24) total)
                     (when (integerp dump-id)
                       (load-constant-shell dump-id stream-24))))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  (multiple-value-bind (constant-count exact?) (load-constant-count directory-path)
    (unless exact?
      (setf constant-count nil))
    (finalize-constants constant-count))
  nil)

(defun load-constant-shell (dump-id stream)
  (let ((name (cfasl-input stream))
        (guid (cfasl-input stream)))
    (load-constant-shell-internal dump-id name guid)))

(defun load-constant-shell-internal (dump-id name guid)
  (let ((constant (make-constant-shell name t)))
    (load-install-constant-ids constant dump-id guid)
    constant))

(defun load-nart-shells (directory-path)
  (let ((nart-count (load-nart-count directory-path)))
    (cond
      (nart-count
       (initialize-nart-shells nart-count))
      (t
       ;; Likely emitted an error about missing nart count, analogous to other
       ;; setup-kb-state-from-dump guards.
       (missing-larkc 10574))))
  nil)

(defun load-nart-count (directory-path)
  (load-kb-object-count directory-path "nart-count"))

(defun initialize-nart-shells (nart-count)
  (do ((id 0 (1+ id)))
      ((>= id nart-count))
    (make-nart-shell id))
  (finalize-narts nart-count))

(defun load-assertion-shells (directory-path)
  (let ((assertion-count (load-assertion-count directory-path)))
    (cond
      (assertion-count
       (initialize-assertion-shells assertion-count))
      (t
       ;; Likely emitted an error about missing assertion count.
       (missing-larkc 10565))))
  nil)

(defun load-assertion-count (directory-path)
  (load-kb-object-count directory-path "assertion-count"))

(defun initialize-assertion-shells (assertion-count)
  (do ((id 0 (1+ id)))
      ((>= id assertion-count))
    (make-assertion-shell id))
  (finalize-assertions assertion-count)
  nil)

(defun load-kb-hl-support-shells (directory-path)
  (let ((kb-hl-support-count (load-kb-hl-support-count directory-path)))
    (cond
      (kb-hl-support-count
       (initialize-kb-hl-support-shells kb-hl-support-count))
      (t
       ;; Likely emitted an error about missing KB-HL support count.
       (missing-larkc 10567))))
  nil)

(defun load-kb-hl-support-count (directory-path)
  (load-kb-object-count directory-path "kb-hl-support-count"))

(defun initialize-kb-hl-support-shells (kb-hl-support-count)
  (do ((id 0 (1+ id)))
      ((>= id kb-hl-support-count))
    (make-kb-hl-support-shell id))
  (finalize-kb-hl-supports kb-hl-support-count))

(defun load-kb-unrepresented-terms (directory-path)
  (let ((cfasl-file (kb-dump-file "unrepresented-terms" directory-path)))
    (when (verify-file-existence cfasl-file t)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-36 stream)
                      (total (file-length stream-36)))
                 (load-copyright stream-36)
                 (noting-percent-progress ("Loading KB unrepresented terms")
                   (do ((dump-id (cfasl-input stream-36 nil) (cfasl-input stream-36 nil)))
                       ((eq dump-id :eof))
                     (note-percent-progress (get-file-position stream-36) total)
                     (when (integerp dump-id)
                       (load-kb-unrepresented-term dump-id stream-36))))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  (let ((unrepresented-term-count (load-kb-unrepresented-term-count directory-path)))
    (finalize-unrepresented-terms unrepresented-term-count))
  nil)

(defun load-kb-unrepresented-term (dump-id stream)
  (let ((v-term (cfasl-input stream nil)))
    (cond
      ((indexed-unrepresented-term-p v-term)
       (register-unrepresented-term-suid v-term dump-id)
       v-term)
      (t nil))))

(defun load-kb-unrepresented-term-count (directory-path)
  (load-kb-object-count directory-path "unrepresented-term-count"))

(defun load-clause-struc-defs (directory-path)
  (let ((cfasl-file (kb-dump-file "clause-struc" directory-path)))
    (when (verify-file-existence cfasl-file)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-41 stream)
                      (total (file-length stream-41)))
                 (load-copyright stream-41)
                 (noting-percent-progress ("Loading clause-struc definitions")
                   (do ((dump-id (cfasl-input stream-41 nil) (cfasl-input stream-41 nil)))
                       ((eq dump-id :eof))
                     (note-percent-progress (get-file-position stream-41) total)
                     (when (integerp dump-id)
                       (load-clause-struc-def dump-id stream-41))))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  (let ((clause-struc-count (load-clause-struc-count directory-path)))
    (finalize-clause-strucs clause-struc-count))
  nil)

(defun load-clause-struc-def (dump-id stream)
  (let* ((cnf (cfasl-input stream))
         (clause-struc (make-clause-struc-shell cnf dump-id)))
    (reset-clause-struc-assertions clause-struc (cfasl-input stream))
    clause-struc))

(defun load-clause-struc-count (directory-path)
  (load-kb-object-count directory-path "clause-struc-count"))

(defun load-deduction-defs (directory-path)
  (let ((deduction-cfasl-file (kb-dump-file "deduction" directory-path))
        (deduction-index-file (kb-dump-file "deduction-index" directory-path)))
    (cond
      ((and (null *force-monolithic-kb-assumption*)
            (probe-file deduction-index-file))
       (let ((max-dump-id nil))
         (let ((*structure-resourcing-make-static* nil)
               (*cfasl-input-to-static-area* nil))
           (setf max-dump-id (file-vector-length-from-index deduction-index-file)))
         (setf *progress-note* "Initializing deduction handles only")
         (setf *progress-start-time* (get-universal-time))
         (setf *progress-total* max-dump-id)
         (setf *progress-sofar* 0)
         (noting-percent-progress (*progress-note*)
           (do ((dump-id 0 (1+ dump-id)))
               ((>= dump-id *progress-total*))
             (note-percent-progress *progress-sofar* *progress-total*)
             (setf *progress-sofar* (+ *progress-sofar* 1))
             (let ((*structure-resourcing-make-static* t)
                   (*cfasl-input-to-static-area* t))
               (make-deduction-shell dump-id)))))
       (initialize-deduction-hl-store-cache))
      ((verify-file-existence deduction-cfasl-file)
       (let* ((deduction-file deduction-cfasl-file)
              (filename-var deduction-file)
              (stream nil))
         (unwind-protect
              (progn
                (let ((*stream-requires-locking* nil))
                  (setf stream (open-binary filename-var :input)))
                (unless (streamp stream)
                  (error "Unable to open ~S" filename-var))
                (let* ((stream-50 stream)
                       (total (file-length stream-50)))
                  (load-copyright stream-50)
                  (noting-percent-progress ("Loading deduction definitions")
                    (do ((dump-id (cfasl-input stream-50 nil) (cfasl-input stream-50 nil)))
                        ((eq dump-id :eof))
                      (note-percent-progress (get-file-position stream-50) total)
                      (when (integerp dump-id)
                        (make-deduction-shell dump-id)
                        (load-deduction-def dump-id stream-50))))))
           (let ((*is-thread-performing-cleanup?* t))
             (when (streamp stream)
               (close stream))))
         (discard-dump-filename filename-var)))))
  (let ((deduction-count (load-deduction-count directory-path)))
    (finalize-deductions deduction-count))
  nil)

(defun load-deduction-def (dump-id stream)
  (let ((deduction (find-deduction-by-dump-id dump-id)))
    (load-deduction-content deduction stream)
    deduction))

(defun load-deduction-def-from-cache (dump-id stream)
  (let ((deduction nil))
    (let ((*within-cfasl-externalization* nil))
      (setf deduction (load-deduction-def dump-id stream)))
    deduction))

(defun load-deduction-count (directory-path)
  (load-kb-object-count directory-path "deduction-count"))

(defun load-assertion-defs (directory-path)
  (let ((assertion-cfasl-file (kb-dump-file "assertion" directory-path))
        (assertion-index-file (kb-dump-file "assertion-index" directory-path)))
    (cond
      ((and (null *force-monolithic-kb-assumption*)
            (probe-file assertion-index-file))
       (initialize-assertion-hl-store-cache))
      ((verify-file-existence assertion-cfasl-file)
       (let* ((assertion-file assertion-cfasl-file)
              (filename-var assertion-file)
              (stream nil))
         (unwind-protect
              (progn
                (let ((*stream-requires-locking* nil))
                  (setf stream (open-binary filename-var :input)))
                (unless (streamp stream)
                  (error "Unable to open ~S" filename-var))
                (let* ((stream-57 stream)
                       (total (file-length stream-57)))
                  (load-copyright stream-57)
                  (noting-percent-progress ("Loading assertion definitions")
                    (do ((dump-id (cfasl-input stream-57 nil) (cfasl-input stream-57 nil)))
                        ((eq dump-id :eof))
                      (note-percent-progress (get-file-position stream-57) total)
                      (when (integerp dump-id)
                        (load-assertion-def dump-id stream-57))))))
           (let ((*is-thread-performing-cleanup?* t))
             (when (streamp stream)
               (close stream))))
         (discard-dump-filename filename-var)))))
  nil)

(defun load-assertion-def (dump-id stream)
  (let ((assertion (find-assertion-by-dump-id dump-id)))
    (load-assertion-content assertion stream)
    assertion))

(defun load-assertion-def-from-cache (dump-id stream)
  (let ((assertion nil))
    (let ((*within-cfasl-externalization* nil))
      (setf assertion (load-assertion-def dump-id stream)))
    assertion))

(defun load-kb-hl-support-defs (directory-path)
  (let ((cfasl-file (kb-dump-file "kb-hl-support" directory-path))
        (index-file (kb-dump-file "kb-hl-support-index" directory-path)))
    (cond
      ((and (null *force-monolithic-kb-assumption*)
            (probe-file index-file))
       (initialize-kb-hl-support-hl-store-cache))
      ((verify-file-existence cfasl-file t)
       (let ((filename-var cfasl-file)
             (stream nil))
         (unwind-protect
              (progn
                (let ((*stream-requires-locking* nil))
                  (setf stream (open-binary filename-var :input)))
                (unless (streamp stream)
                  (error "Unable to open ~S" filename-var))
                (let* ((stream-64 stream)
                       (total (kb-hl-support-count))
                       (sofar 0))
                  (load-copyright stream-64)
                  (noting-percent-progress ("Loading KB HL support definitions")
                    (do ((dump-id (cfasl-input stream-64 nil) (cfasl-input stream-64 nil)))
                        ((eq dump-id :eof))
                      (setf sofar (+ sofar 1))
                      (note-percent-progress sofar total)
                      (when (integerp dump-id)
                        (load-kb-hl-support-def dump-id stream-64))))))
           (let ((*is-thread-performing-cleanup?* t))
             (when (streamp stream)
               (close stream))))
         (discard-dump-filename filename-var)))))
  nil)

(defun load-kb-hl-support-def (dump-id stream)
  (let ((kb-hl-support (find-kb-hl-support-by-dump-id dump-id)))
    (load-kb-hl-support-content kb-hl-support stream)
    kb-hl-support))

(defun load-kb-hl-support-def-from-cache (dump-id stream)
  (let ((index nil))
    (let ((*within-cfasl-externalization* nil))
      (setf index (load-kb-hl-support-def dump-id stream)))
    index))

(defun load-kb-hl-support-indexing (directory-path)
  (let ((index-file (kb-dump-file "kb-hl-support-indexing" directory-path)))
    (when (verify-file-existence index-file t)
      (let ((*noting-progress-start-time* (get-universal-time)))
        (noting-progress-preamble "Loading KB HL support indexing...")
        (load-kb-hl-support-indexing-int index-file)
        (noting-progress-postamble))))
  nil)

(defun load-bookkeeping-assertions (directory-path)
  (let ((cfasl-file (kb-dump-file "bookkeeping-assertions" directory-path)))
    (when (verify-file-existence cfasl-file)
      (let ((*noting-progress-start-time* (get-universal-time)))
        (noting-progress-preamble "Loading bookkeeping assertions...")
        (let ((filename-var cfasl-file)
              (stream nil))
          (unwind-protect
               (progn
                 (let ((*stream-requires-locking* nil))
                   (setf stream (open-binary filename-var :input)))
                 (unless (streamp stream)
                   (error "Unable to open ~S" filename-var))
                 (let* ((stream-69 stream)
                        (total (file-length stream-69)))
                   (load-copyright stream-69)
                   (dumper-clear-bookkeeping-binary-gaf-store)
                   (let ((num-bookkeeping-preds (cfasl-input stream-69)))
                     (do ((n 0 (+ n 1)))
                         ((>= n num-bookkeeping-preds))
                       (load-bookkeeping-assertions-for-pred stream-69)))
                   (cfasl-input stream-69)
                   (cfasl-input stream-69)
                   (cfasl-input stream-69)
                   (unless (eq (cfasl-input stream-69 nil :eof) :eof)
                     (warn "~d bytes of unread stuff in ~S"
                           (- total (get-file-position stream-69)) cfasl-file))))
            (let ((*is-thread-performing-cleanup?* t))
              (when (streamp stream)
                (close stream))))
          (discard-dump-filename filename-var))
        (noting-progress-postamble))))
  nil)

(defun load-bookkeeping-assertions-for-pred (stream)
  (let ((pred (cfasl-input stream))
        (num-assertions (cfasl-input stream)))
    (do ((i 0 (+ i 1)))
        ((>= i num-assertions))
      (load-bookkeeping-assertion pred stream)))
  nil)

(defun load-bookkeeping-assertion (pred stream)
  (let ((arg1 (cfasl-input stream))
        (arg2 (cfasl-input stream)))
    (dumper-load-bookkeeping-binary-gaf pred arg1 arg2))
  nil)

(defun load-experience (directory-path)
  (let ((*noting-progress-start-time* (get-universal-time)))
    (noting-progress-preamble "Loading rule utility experience...")
    (load-rule-utility-experience directory-path)
    (noting-progress-postamble))
  nil)

(defun load-rule-utility-experience (directory-path)
  (let ((experience-file (kb-dump-file "rule-utility-experience" directory-path)))
    (when (verify-file-existence experience-file t)
      (load-transformation-rule-statistics experience-file nil)))
  nil)

(defun load-kb-indexing (directory-path)
  (load-constant-indices directory-path)
  (kb-load-gc-checkpoint)
  (load-nart-indices directory-path)
  (kb-load-gc-checkpoint)
  (load-unrepresented-term-indices directory-path)
  (kb-load-gc-checkpoint)
  (load-assertion-indices directory-path)
  (kb-load-gc-checkpoint)
  (load-auxiliary-indices-file directory-path)
  (kb-load-gc-checkpoint)
  (load-bookkeeping-indices-file directory-path)
  (kb-load-gc-checkpoint)
  (load-kb-hl-support-indexing directory-path)
  (kb-load-gc-checkpoint)
  nil)

(defun load-constant-indices (directory-path)
  (let ((cfasl-file (kb-dump-file "indices" directory-path))
        (index-file (kb-dump-file "indices-index" directory-path)))
    (cond
      ((and (null *force-monolithic-kb-assumption*)
            (probe-file index-file))
       (initialize-constant-index-hl-store-cache))
      ((verify-file-existence cfasl-file)
       (let ((filename-var cfasl-file)
             (stream nil))
         (unwind-protect
              (progn
                (let ((*stream-requires-locking* nil))
                  (setf stream (open-binary filename-var :input)))
                (unless (streamp stream)
                  (error "Unable to open ~S" filename-var))
                (let* ((stream-79 stream)
                       (total (constant-count))
                       (sofar 0))
                  (load-copyright stream-79)
                  (noting-percent-progress ("Loading constant indices")
                    (do ((dump-id (cfasl-input stream-79 nil) (cfasl-input stream-79 nil)))
                        ((eq dump-id :eof))
                      (setf sofar (+ sofar 1))
                      (note-percent-progress sofar total)
                      (when (integerp dump-id)
                        (load-constant-index dump-id stream-79))))))
           (let ((*is-thread-performing-cleanup?* t))
             (when (streamp stream)
               (close stream))))
         (discard-dump-filename filename-var)))))
  nil)

(defun load-constant-index (dump-id stream)
  (let ((constant (find-constant-by-dump-id dump-id)))
    (reset-constant-index constant (cfasl-input stream))))

(defun load-constant-index-from-cache (dump-id stream)
  (let ((index nil))
    (let ((*within-cfasl-externalization* nil))
      (setf index (load-constant-index dump-id stream)))
    index))

(defun load-nart-indices (directory-path)
  (let ((cfasl-file (kb-dump-file "nat-indices" directory-path))
        (index-file (kb-dump-file "nat-indices-index" directory-path)))
    (cond
      ((and (null *force-monolithic-kb-assumption*)
            (probe-file index-file))
       (initialize-nart-index-hl-store-cache))
      ((verify-file-existence cfasl-file)
       (let ((filename-var cfasl-file)
             (stream nil))
         (unwind-protect
              (progn
                (let ((*stream-requires-locking* nil))
                  (setf stream (open-binary filename-var :input)))
                (unless (streamp stream)
                  (error "Unable to open ~S" filename-var))
                (let* ((stream-86 stream)
                       (total (nart-count))
                       (sofar 0))
                  (load-copyright stream-86)
                  (noting-percent-progress ("Loading NART indices")
                    (do ((dump-id (cfasl-input stream-86 nil) (cfasl-input stream-86 nil)))
                        ((eq dump-id :eof))
                      (setf sofar (+ sofar 1))
                      (note-percent-progress sofar total)
                      (when (integerp dump-id)
                        ;; Likely did (load-nart-index dump-id stream-86) —
                        ;; the load-nart-index declareFunction is commented-out.
                        (missing-larkc 10571))))))
           (let ((*is-thread-performing-cleanup?* t))
             (when (streamp stream)
               (close stream))))
         (discard-dump-filename filename-var)))))
  nil)

(defun load-unrepresented-term-indices (directory-path)
  (let ((cfasl-file (kb-dump-file "unrepresented-term-indices" directory-path))
        (index-file (kb-dump-file "unrepresented-term-indices-index" directory-path)))
    (cond
      ((and (null *force-monolithic-kb-assumption*)
            (probe-file index-file))
       (initialize-unrepresented-term-index-hl-store-cache))
      ((verify-file-existence cfasl-file t)
       (let ((filename-var cfasl-file)
             (stream nil))
         (unwind-protect
              (progn
                (let ((*stream-requires-locking* nil))
                  (setf stream (open-binary filename-var :input)))
                (unless (streamp stream)
                  (error "Unable to open ~S" filename-var))
                (let* ((stream-93 stream)
                       (total (kb-unrepresented-term-count))
                       (sofar 0))
                  (load-copyright stream-93)
                  (noting-percent-progress ("Loading unrepresented term indices")
                    (do ((dump-id (cfasl-input stream-93 nil) (cfasl-input stream-93 nil)))
                        ((eq dump-id :eof))
                      (setf sofar (+ sofar 1))
                      (note-percent-progress sofar total)
                      (when (integerp dump-id)
                        (load-unrepresented-term-index dump-id stream-93))))))
           (let ((*is-thread-performing-cleanup?* t))
             (when (streamp stream)
               (close stream))))
         (discard-dump-filename filename-var)))))
  nil)

(defun load-unrepresented-term-index (dump-id stream)
  (let ((unrepresented-term (find-unrepresented-term-by-dump-id dump-id)))
    (reset-unrepresented-term-index unrepresented-term (cfasl-input stream))))

(defun load-unrepresented-term-index-from-cache (dump-id stream)
  (let ((index nil))
    (let ((*within-cfasl-externalization* nil))
      (setf index (load-unrepresented-term-index dump-id stream)))
    index))

(defun load-assertion-indices (directory-path)
  (let ((cfasl-file (kb-dump-file "assertion-indices" directory-path)))
    (when (verify-file-existence cfasl-file)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-98 stream)
                      (total (file-length stream-98)))
                 (load-copyright stream-98)
                 (noting-percent-progress ("Loading assertion indices")
                   (do ((dump-id (cfasl-input stream-98 nil) (cfasl-input stream-98 nil)))
                       ((eq dump-id :eof))
                     (note-percent-progress (get-file-position stream-98) total)
                     (when (integerp dump-id)
                       (load-assertion-index dump-id stream-98))))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  nil)

(defun load-assertion-index (dump-id stream)
  (let ((assertion (find-assertion-by-dump-id dump-id)))
    (reset-assertion-index assertion (cfasl-input stream))))

(defun load-auxiliary-indices-file (directory-path)
  (let ((cfasl-file (kb-dump-file "auxiliary-indices" directory-path)))
    (when (verify-file-existence cfasl-file)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-100 stream)
                      (total (file-length stream-100)))
                 (load-copyright stream-100)
                 (let ((*noting-progress-start-time* (get-universal-time)))
                   (noting-progress-preamble "Loading auxiliary indices")
                   (load-auxiliary-indices stream-100)
                   (unless (eq (cfasl-input stream-100 nil :eof) :eof)
                     (warn "~d bytes of unread stuff in ~S"
                           (- total (get-file-position stream-100)) cfasl-file))
                   (noting-progress-postamble))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  nil)

(defun load-bookkeeping-indices-file (directory-path)
  (load-unit-file directory-path "bookkeeping-indices" 'load-bookkeeping-indices "Loading bookkeeping indices..."))

(defun load-bookkeeping-indices (stream)
  (let ((index (cfasl-input stream)))
    (dumper-load-bookkeeping-index index))
  nil)

(defun load-rule-set (directory-path)
  (load-unit-file directory-path "rule-set" 'load-rule-set-from-stream "Loading rule set..."))

(defun load-nart-hl-formulas (directory-path)
  (let ((nart-hl-formula-cfasl-file (kb-dump-file "nart-hl-formula" directory-path))
        (nart-hl-formula-index-file (kb-dump-file "nart-hl-formula-index" directory-path)))
    (cond
      ((and (null *force-monolithic-kb-assumption*)
            (probe-file nart-hl-formula-index-file))
       (initialize-nart-hl-formula-hl-store-cache))
      ((verify-file-existence nart-hl-formula-cfasl-file t)
       (let* ((nart-hl-formula-file nart-hl-formula-cfasl-file)
              (filename-var nart-hl-formula-file)
              (stream nil))
         (unwind-protect
              (progn
                (let ((*stream-requires-locking* nil))
                  (setf stream (open-binary filename-var :input)))
                (unless (streamp stream)
                  (error "Unable to open ~S" filename-var))
                (let* ((stream-112 stream)
                       (total (file-length stream-112)))
                  (load-copyright stream-112)
                  (noting-percent-progress ("Loading nart-hl-formula definitions")
                    (do ((dump-id (cfasl-input stream-112 nil) (cfasl-input stream-112 nil)))
                        ((eq dump-id :eof))
                      (note-percent-progress (get-file-position stream-112) total)
                      (when (integerp dump-id)
                        ;; Likely did (load-nart-hl-formula dump-id stream-112) —
                        ;; the load-nart-hl-formula declareFunction is commented-out.
                        (missing-larkc 10568))))))
           (let ((*is-thread-performing-cleanup?* t))
             (when (streamp stream)
               (close stream))))
         (discard-dump-filename filename-var)))))
  nil)

;; (defun load-nart-hl-formula-from-cache (dump-id stream) ...) -- commented declareFunction, no body (BinaryFunction class present but returns handleMissingMethodError 10570)

(defun load-miscellaneous (directory-path)
  (let ((cfasl-file (kb-dump-file "misc" directory-path)))
    (when (verify-file-existence cfasl-file)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-114 stream)
                      (total (file-length stream-114)))
                 (load-copyright stream-114)
                 (let ((*noting-progress-start-time* (get-universal-time)))
                   (noting-progress-preamble "Loading miscellaneous stuff...")
                   (cfasl-input stream-114)
                   (setf *skolem-axiom-table* (cfasl-input stream-114))
                   (cfasl-input stream-114)
                   (set-build-kb-loaded (cfasl-input stream-114))
                   (unless (eq (cfasl-input stream-114 nil :eof) :eof)
                     (warn "~d bytes of unread stuff in ~S"
                           (- total (get-file-position stream-114)) cfasl-file))
                   (noting-progress-postamble))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  nil)

(defun load-sbhl-data (directory-path)
  (let ((cfasl-file (kb-dump-file "sbhl-modules" directory-path))
        (data-file (kb-dump-file "sbhl-module-graphs" directory-path))
        (index-file (kb-dump-file "sbhl-module-graphs-index" directory-path)))
    (when (verify-file-existence cfasl-file)
      (when (and (verify-file-existence data-file :warn-only)
                 (verify-file-existence index-file :warn-only))
        (initialize-sbhl-graph-caches-during-load-kb data-file index-file))
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-117 stream)
                      (total (file-length stream-117)))
                 (load-copyright stream-117)
                 (let ((graph-count (cfasl-input stream-117)))
                   (let ((*cfasl-stream-extensions-enabled* t)
                         (*cfasl-unread-byte* nil)
                         (*noting-progress-start-time* (get-universal-time)))
                     (noting-progress-preamble "Loading SBHL graphs...")
                     (initialize-sbhl-modules t)
                     (do ((n 0 (+ n 1)))
                         ((>= n graph-count))
                       (when (= (cfasl-opcode-peek stream-117) 30)
                         (let* ((predicate (cfasl-input stream-117))
                                (graph (cfasl-input stream-117))
                                (module (get-sbhl-module predicate)))
                           (when (and (valid-constant? predicate)
                                      (hash-table-p graph)
                                      (sbhl-module-p module))
                             (set-sbhl-module-property module :graph graph)))))
                     (when (get-sbhl-modules)
                       (note-sbhl-modules-initialized))
                     (load-sbhl-miscellany stream-117)
                     (unless (eq (cfasl-input stream-117 nil :eof) :eof)
                       (warn "~d bytes of unread stuff in ~S"
                             (- total (get-file-position stream-117)) cfasl-file))
                     (noting-progress-postamble)))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  nil)

(defun load-sbhl-miscellany (stream)
  (let ((token nil))
    (loop until (eq token :end) do
      (setf token (cfasl-input stream))
      (cond
        ((hash-table-p token)
         (setf *isa-arg2-naut-table* token)
         ;; Likely called (set-non-fort-isa-table (cfasl-input stream)) and
         ;; (set-non-fort-instance-table (cfasl-input stream)) — legacy path
         ;; where the three tables were concatenated after the hashtable.
         (missing-larkc 1805)
         (setf token :end))
        (t
         (case token
           (:isa-arg2-naut-table (load-isa-arg2-naut-table stream))
           (:non-fort-isa-table (load-non-fort-isa-table stream))
           (:non-fort-instance-table (load-non-fort-instance-table stream))
           (:end nil)
           (t (warn "Could not handle SBHL miscellany token ~s" token)))))))
  nil)

(defun load-isa-arg2-naut-table (stream)
  (setf *isa-arg2-naut-table* (cfasl-input stream))
  nil)

(defun load-non-fort-isa-table (stream)
  (set-non-fort-isa-table (cfasl-input stream))
  nil)

(defun load-non-fort-instance-table (stream)
  (set-non-fort-instance-table (cfasl-input stream))
  nil)

(defun load-sbhl-cache (directory-path)
  (let ((cfasl-file (kb-dump-file "sbhl-cache" directory-path)))
    (when (verify-file-existence cfasl-file)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-119 stream)
                      (total (file-length stream-119)))
                 (load-copyright stream-119)
                 (let ((*noting-progress-start-time* (get-universal-time)))
                   (noting-progress-preamble "Loading SBHL cache...")
                   (setf *isa-cache* (cfasl-input stream-119))
                   (setf *all-mts-isa-cache* (cfasl-input stream-119))
                   (setf *genls-cache* (cfasl-input stream-119))
                   (setf *all-mts-genls-cache* (cfasl-input stream-119))
                   (setf *genl-predicate-cache* (cfasl-input stream-119))
                   (setf *genl-inverse-cache* (cfasl-input stream-119))
                   (setf *all-mts-genl-predicate-cache* (cfasl-input stream-119))
                   (setf *all-mts-genl-inverse-cache* (cfasl-input stream-119))
                   (note-sbhl-caches-initialized)
                   (unless (eq (cfasl-input stream-119 nil :eof) :eof)
                     (warn "~d bytes of unread stuff in ~S"
                           (- total (get-file-position stream-119)) cfasl-file))
                   (noting-progress-postamble))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  nil)

(defun load-cardinality-estimates (directory-path)
  (load-unit-file directory-path "cardinality-estimates"
                  'load-cardinality-estimates-from-stream
                  "Loading cardinality estimates..."))

(defparameter *compute-arg-type-cache-on-dump?* t)

(defun load-arg-type-cache (directory-path)
  (let ((cfasl-file (kb-dump-file "arg-type-cache" directory-path)))
    (when (verify-file-existence cfasl-file t)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-122 stream)
                      (total (file-length stream-122)))
                 (load-copyright stream-122)
                 (let ((*noting-progress-start-time* (get-universal-time)))
                   (noting-progress-preamble "Loading arg-type cache...")
                   (let ((dummy nil))
                     (declare (ignorable dummy))
                     (setf *arg-type-cache* (cfasl-input stream-122))
                     (setf dummy (cfasl-input stream-122))
                     (setf dummy (cfasl-input stream-122))
                     (setf dummy (cfasl-input stream-122)))
                   (note-at-cache-initialized)
                   (unless (eq (cfasl-input stream-122 nil :eof) :eof)
                     (warn "~d bytes of unread stuff in ~S"
                           (- total (get-file-position stream-122)) cfasl-file))
                   (noting-progress-postamble))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  nil)

(defun load-defns-cache (directory-path)
  (let ((cfasl-file (kb-dump-file "defns-cache" directory-path)))
    (when (verify-file-existence cfasl-file t)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-124 stream)
                      (total (file-length stream-124)))
                 (load-copyright stream-124)
                 (let ((*noting-progress-start-time* (get-universal-time)))
                   (noting-progress-preamble "Loading defns cache...")
                   (load-defns-cache-from-stream stream-124)
                   (unless (eq (cfasl-input stream-124 nil :eof) :eof)
                     (warn "~d bytes of unread stuff in ~S"
                           (- total (get-file-position stream-124)) cfasl-file))
                   (noting-progress-postamble))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  nil)

(defun load-tva-cache (dump-directory)
  (let ((result (load-unit-file dump-directory "tva-cache"
                                'load-tva-cache-from-stream
                                "Loading TVA cache...")))
    (reconnect-tva-cache-registry dump-directory (cfasl-current-common-symbols))
    result))

(defun load-somewhere-cache (directory-path)
  (let ((cfasl-file (kb-dump-file "somewhere-cache" directory-path)))
    (when (verify-file-existence cfasl-file t)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-127 stream)
                      (total (file-length stream-127)))
                 (load-copyright stream-127)
                 (let ((*noting-progress-start-time* (get-universal-time)))
                   (noting-progress-preamble "Loading somewhere cache...")
                   (load-somewhere-cache-from-stream stream-127)
                   (unless (eq (cfasl-input stream-127 nil :eof) :eof)
                     (warn "~d bytes of unread stuff in ~S"
                           (- total (get-file-position stream-127)) cfasl-file))
                   (noting-progress-postamble))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  nil)

(defun load-arity-cache (directory-path)
  (let ((cfasl-file (kb-dump-file "arity-cache" directory-path)))
    (when (verify-file-existence cfasl-file t)
      (let ((filename-var cfasl-file)
            (stream nil))
        (unwind-protect
             (progn
               (let ((*stream-requires-locking* nil))
                 (setf stream (open-binary filename-var :input)))
               (unless (streamp stream)
                 (error "Unable to open ~S" filename-var))
               (let* ((stream-129 stream)
                      (total (file-length stream-129)))
                 (load-copyright stream-129)
                 (let ((*noting-progress-start-time* (get-universal-time)))
                   (noting-progress-preamble "Loading arity cache...")
                   (load-arity-cache-from-stream stream-129)
                   (unless (eq (cfasl-input stream-129 nil :eof) :eof)
                     (warn "~d bytes of unread stuff in ~S"
                           (- total (get-file-position stream-129)) cfasl-file))
                   (noting-progress-postamble))))
          (let ((*is-thread-performing-cleanup?* t))
            (when (streamp stream)
              (close stream))))
        (discard-dump-filename filename-var))))
  nil)

(defun load-kb-initializations ()
  "[Cyc] Initializations which should be run whenever the KB is loaded.  Note that the definition of initialization has stretched to include the building of huge structures.  Large structures must be loaded and dumped like other large structure.  Initialization need to be FAST to support starting up a Cyc image without a world from units."
  (when *dump-verbose*
    (format *standard-output* "~&~%;;; Performing KB initializations at ~A~%" (timestring))
    (force-output *standard-output*))
  (clean-sbhl-modules)
  (kb-load-gc-checkpoint)
  (compute-bogus-constant-names-in-code)
  (kb-load-gc-checkpoint)
  (initialize-kb-state-hashes)
  (kb-load-gc-checkpoint)
  (initialize-old-constant-names)
  (kb-load-gc-checkpoint)
  (initialize-kb-variables)
  (kb-load-gc-checkpoint)
  (rebuild-computable-but-not-dumpable-yet)
  (kb-load-gc-checkpoint)
  (unless (non-tiny-kb-loaded?)
    (setf *allow-guest-to-edit?* t))
  nil)

(defun initialize-kb-features ()
  "[Cyc] If the code is missing, assume the relevant portion of the KB is also missing,
 because it won't matter if it's there."
  (initialize-kct-kb-feature)
  nil)

;; The dump-side counterparts below are commented-out //declareFunction entries
;; in the Java — stripped in LarKC. The from-cache helper wrappers, the count
;; files, and the swap-in branches rely on them only conceptually; they have no
;; body here and are not redefined:
;; (defun kb-dump-directory (&optional name extension) ...) -- commented declareFunction, no body
;; (defun kb-dump-product-file (name directory-path &optional extension) ...) -- commented declareFunction, no body
;; (defun dump-estimated-size (&optional a-count n-assertions-per-cons) ...) -- commented declareFunction, no body
;; (defun validate-dump-directory (directory-path) ...) -- commented declareFunction, no body
;; (defun preprocess-experience-and-dump-standard-kb (&optional a b c) ...) -- commented declareFunction, no body
;; (defun dump-standard-kb (&optional directory-path) ...) -- commented declareFunction, no body
;; (defun perform-standard-pre-dump-kb-cleanups () ...) -- commented declareFunction, no body
;; (defun perform-kb-cleanups () ...) -- commented declareFunction, no body
;; (defun preprocess-experience (&optional a b) ...) -- commented declareFunction, no body
;; (defun preprocess-experience-and-dump-non-computable-kb (&optional a b c) ...) -- commented declareFunction, no body
;; (defun dump-non-computable-kb (directory-path) ...) -- commented declareFunction, no body
;; (defun load-non-computable-kb-and-rebuild-computable-kb-and-write-image (a b c) ...) -- commented declareFunction, no body
;; (defun load-non-computable-kb (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-computable-kb-and-content (a b) ...) -- commented declareFunction, no body
;; (defun dump-kb (&optional directory-path) ...) -- commented declareFunction, no body
;; (defun kb-dump-to-directory (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-kb-ids (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-essential-kb (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-computable-content (directory-path) ...) -- commented declareFunction, no body
;; (defun rebuild-computable-content () ...) -- commented declareFunction, no body
;; (defun rebuild-computable-content-dumpable () ...) -- commented declareFunction, no body
;; (defun rebuild-computable-content-dumpable-low () ...) -- commented declareFunction, no body
;; (defun dump-computable-kb (directory-path) ...) -- commented declareFunction, no body
;; (defun rebuild-computable-kb () ...) -- commented declareFunction, no body
;; (defun dump-computable-remaining-hl (directory-path) ...) -- commented declareFunction, no body
;; (defun rebuild-computable-remaining-hl () ...) -- commented declareFunction, no body
;; (defun rebuild-computable-remaining-hl-low () ...) -- commented declareFunction, no body
;; (defun rebuild-computable-remaining-hl-high () ...) -- commented declareFunction, no body
;; (defun dump-copyright (stream) ...) -- commented declareFunction, no body
;; (defun dump-kb-object-count (directory-path filename count) ...) -- commented declareFunction, no body
;; (defun kb-dump-common-symbols () ...) -- commented declareFunction, no body
;; (defun dump-special-objects (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-special-objects-internal (stream common-symbols) ...) -- commented declareFunction, no body
;; (defun dump-constant-shells (stream) ...) -- commented declareFunction, no body
;; (defun dump-constant-shell (constant stream) ...) -- commented declareFunction, no body
;; (defun dump-constant-shell-internal (dump-id name guid stream) ...) -- commented declareFunction, no body
;; (defun generate-constant-shell-file (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-nart-count (directory-path) ...) -- commented declareFunction, no body
;; (defun load-nart-shells-legacy (stream) ...) -- commented declareFunction, no body
;; (defun dump-nart-shell (nart stream) ...) -- commented declareFunction, no body
;; (defun load-nart-shell (dump-id stream) ...) -- commented declareFunction, no body
;; (defun dump-assertion-count (directory-path) ...) -- commented declareFunction, no body
;; (defun load-assertion-shells-legacy (stream) ...) -- commented declareFunction, no body
;; (defun dump-assertion-shell (assertion stream) ...) -- commented declareFunction, no body
;; (defun load-assertion-shell (dump-id stream) ...) -- commented declareFunction, no body
;; (defun dump-kb-hl-support-count (directory-path) ...) -- commented declareFunction, no body
;; (defun load-kb-hl-support-shells-legacy (stream) ...) -- commented declareFunction, no body
;; (defun dump-kb-hl-support-shell (kb-hl-support stream) ...) -- commented declareFunction, no body
;; (defun load-kb-hl-support-shell (dump-id stream) ...) -- commented declareFunction, no body
;; (defun dump-kb-unrepresented-terms (stream) ...) -- commented declareFunction, no body
;; (defun dump-kb-unrepresented-term (unrepresented-term stream) ...) -- commented declareFunction, no body
;; (defun dump-clause-struc-defs (stream) ...) -- commented declareFunction, no body
;; (defun dump-clause-struc-def (clause-struc stream) ...) -- commented declareFunction, no body
;; (defun dump-deduction-defs (stream) ...) -- commented declareFunction, no body
;; (defun dump-deduction-def (deduction stream) ...) -- commented declareFunction, no body
;; (defun dump-assertion-defs (stream) ...) -- commented declareFunction, no body
;; (defun dump-assertion-def (assertion stream) ...) -- commented declareFunction, no body
;; (defun dump-kb-hl-support-defs (stream) ...) -- commented declareFunction, no body
;; (defun dump-kb-hl-support-def (kb-hl-support stream) ...) -- commented declareFunction, no body
;; (defun dump-kb-hl-support-indexing (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-bookkeeping-assertions (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-bookkeeping-assertions-for-pred (pred subindex stream) ...) -- commented declareFunction, no body
;; (defun dump-bookkeeping-assertion (pred arg1 arg2) ...) -- commented declareFunction, no body
;; (defun dump-experience (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-rule-utility-experience (directory-path &optional stream) ...) -- commented declareFunction, no body
;; (defun reload-experience (&optional directory-path) ...) -- commented declareFunction, no body
;; (defun dump-kb-indexing (directory-path) ...) -- commented declareFunction, no body
;; (defun rebuild-kb-indexing () ...) -- commented declareFunction, no body
;; (defun test-dump-kb-indexing (directory-path) ...) -- commented declareFunction, no body
;; (defun test-load-kb-indexing (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-constant-indices (stream) ...) -- commented declareFunction, no body
;; (defun dump-constant-index (constant stream) ...) -- commented declareFunction, no body
;; (defun dump-nart-indices (stream) ...) -- commented declareFunction, no body
;; (defun dump-nart-index (nart stream) ...) -- commented declareFunction, no body
;; (defun load-nart-index (dump-id stream) ...) -- commented declareFunction, no body
;; (defun load-nart-index-from-cache (dump-id stream) ...) -- commented declareFunction, no body
;; (defun dump-unrepresented-term-indices (stream) ...) -- commented declareFunction, no body
;; (defun dump-unrepresented-term-index (unrepresented-term stream) ...) -- commented declareFunction, no body
;; (defun dump-assertion-indices (stream) ...) -- commented declareFunction, no body
;; (defun dump-assertion-index (assertion stream) ...) -- commented declareFunction, no body
;; (defun dump-auxiliary-indices-file (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-bookkeeping-indices-file (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-bookkeeping-indices (stream) ...) -- commented declareFunction, no body
;; (defun dump-rule-set (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-nart-hl-formulas (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-nart-hl-formula (index dump-id stream) ...) -- commented declareFunction, no body
;; (defun load-nart-hl-formula (dump-id stream) ...) -- commented declareFunction, no body
;; (defun dump-miscellaneous (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-sbhl-data (directory-path) ...) -- commented declareFunction, no body
;; (defun old-dump-sbhl-data (directory-path) ...) -- commented declareFunction, no body
;; (defun rebuild-sbhl-data () ...) -- commented declareFunction, no body
;; (defun dump-sbhl-miscellany (stream) ...) -- commented declareFunction, no body
;; (defun dump-isa-arg2-naut-table (stream) ...) -- commented declareFunction, no body
;; (defun dump-non-fort-isa-table (stream) ...) -- commented declareFunction, no body
;; (defun dump-non-fort-instance-table (stream) ...) -- commented declareFunction, no body
;; (defun dump-sbhl-cache (directory-path) ...) -- commented declareFunction, no body
;; (defun rebuild-sbhl-cache () ...) -- commented declareFunction, no body
;; (defun dump-cardinality-estimates (directory-path) ...) -- commented declareFunction, no body
;; TODO - defmacro not-computing-arg-type-cache; arglist from $list184:
;; ((*compute-arg-type-cache-on-dump?* nil)). Binds that parameter to NIL
;; around the body.
;; (defmacro not-computing-arg-type-cache (&body body) ...) -- commented declareMacro
;; (defun dump-arg-type-cache (directory-path) ...) -- commented declareFunction, no body
;; (defun rebuild-arg-type-cache () ...) -- commented declareFunction, no body
;; (defun dump-defns-cache (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-tva-cache (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-somewhere-cache (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-arity-cache (directory-path) ...) -- commented declareFunction, no body
;; (defun dump-kb-activities (directory-path) ...) -- commented declareFunction, no body
;; (defun show-kb-features () ...) -- commented declareFunction, no body

(declare-defglobal '*force-monolithic-kb-assumption*)
(note-funcall-helper-function 'load-deduction-def-from-cache)
(note-funcall-helper-function 'load-assertion-def-from-cache)
(note-funcall-helper-function 'load-kb-hl-support-def-from-cache)
(note-funcall-helper-function 'load-constant-index-from-cache)
(note-funcall-helper-function 'load-nart-index-from-cache)
(note-funcall-helper-function 'load-unrepresented-term-index-from-cache)
