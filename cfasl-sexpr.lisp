;;; cfasl-sexpr.lisp — Dump a KB directory as executable ke-assert forms
;;;
;;; Not in the .asd — load manually after (asdf:load-system :clyc)
;;;   (load "cfasl-sexpr.lisp")
;;;   (clyc::cfasl-kb-to-sexpr "/path/to/kb/" "/path/to/output.lisp")

(in-package :clyc)


;;;; ----------------------------------------------------------------
;;;; State
;;;; ----------------------------------------------------------------

(defvar *constant-names* nil "Vector: dump-id → constant name string.")
(defvar *constant-guids* nil "Vector: dump-id → GUID string.")
(defvar *nart-formulas* nil "Vector: nart dump-id → HL formula.")
(defvar *clause-struc-data* nil "Hashtable: clause-struc dump-id → CNF.")
(defvar *assertion-formulas* nil "Vector: assertion dump-id → EL formula (filled after reading).")


;;;; ----------------------------------------------------------------
;;;; Handle-lookup functions for CFASL deserialization
;;;; ----------------------------------------------------------------

(defun sexpr-constant-lookup (id)
  "Look up constant by dump-id, return the actual constant object."
  (let ((name (when (and *constant-names* (< id (length *constant-names*)))
                (aref *constant-names* id))))
    (if name
        (make-constant-shell name t)
        (error "Unknown constant ID ~d" id))))

(defun sexpr-nart-lookup (id)
  "Look up NART by dump-id, return its HL formula."
  (let ((formula (when (and *nart-formulas* (< id (length *nart-formulas*)))
                   (aref *nart-formulas* id))))
    (or formula (list :nart id))))

(defstruct (assertion-ref (:constructor make-assertion-ref (id)))
  id)

(defmethod print-object ((ref assertion-ref) stream)
  (let* ((id (assertion-ref-id ref))
         (entry (when (and *assertion-formulas* (< id (length *assertion-formulas*)))
                  (aref *assertion-formulas* id))))
    (if entry
        (destructuring-bind (mt formula var-names) entry
          (let ((*variable-names* var-names))
            (write-string "(find-assertion-cycl '" stream)
            (prin1 formula stream)
            (write-char #\Space stream)
            (prin1 mt stream)
            (write-char #\) stream)))
        (format stream "(:unresolved-assertion ~d)" id))))

(defun sexpr-assertion-lookup (id)
  (make-assertion-ref id))

(defun sexpr-deduction-lookup (id)
  (list :deduction id))

(defun sexpr-kb-hl-support-lookup (id)
  (list :kb-hl-support id))

(defun sexpr-clause-struc-lookup (id)
  "Look up clause-struc by dump-id, return CNF or placeholder."
  (or (when *clause-struc-data* (gethash id *clause-struc-data*))
      (list :clause-struc id)))

(defun sexpr-input-fort-id-index (stream)
  "Read fort-id-index as a plain hashtable (no KB tables needed)."
  (let ((count (cfasl-input stream))
        (ht (make-hash-table :test 'eql)))
    (dotimes (i count)
      (let ((fort (cfasl-input-object stream))
            (value (cfasl-input-object stream)))
        (setf (gethash fort ht) value)))
    ht))


;;;; ----------------------------------------------------------------
;;;; CFASL file helpers
;;;; ----------------------------------------------------------------

(defmacro with-cfasl-file ((stream filename) &body body)
  "Open FILENAME as binary, skip the copyright string, execute BODY."
  `(with-open-file (,stream ,filename :element-type '(unsigned-byte 8))
     (cfasl-input ,stream)
     ,@body))

(defmacro with-cfasl-handles (&body body)
  "Execute BODY with CFASL lookups bound to our sexpr functions."
  `(let ((*cfasl-constant-handle-lookup-func* 'sexpr-constant-lookup)
         (*cfasl-nart-handle-lookup-func* 'sexpr-nart-lookup)
         (*cfasl-assertion-handle-lookup-func* 'sexpr-assertion-lookup)
         (*cfasl-deduction-handle-lookup-func* 'sexpr-deduction-lookup)
         (*cfasl-kb-hl-support-handle-lookup-func* 'sexpr-kb-hl-support-lookup)
         (*cfasl-clause-struc-handle-lookup-func* 'sexpr-clause-struc-lookup))
     ,@body))

(defun cfasl-file-path (directory name &optional (ext "cfasl"))
  (merge-pathnames (make-pathname :name name :type ext) directory))

(defun read-text-count (directory name)
  (let ((path (cfasl-file-path directory name "text")))
    (when (probe-file path)
      (with-open-file (s path) (read s nil nil)))))


;;;; ----------------------------------------------------------------
;;;; CFASL readers — return deserialized objects directly
;;;; ----------------------------------------------------------------

(defun read-constant-shells (directory)
  "Read constant-shell.cfasl, populate *constant-names* and *constant-guids*."
  (let ((path (cfasl-file-path directory "constant-shell"))
        (count (or (read-text-count directory "constant-count") 1024)))
    (setf *constant-names* (make-array count :initial-element nil))
    (setf *constant-guids* (make-array count :initial-element nil))
    (when (probe-file path)
      (with-cfasl-file (stream path)
        ;; First value after copyright is the total count
        (cfasl-input stream)
        ;; Then [dump-id name guid]* triples
        (loop for dump-id = (cfasl-input stream nil :eof)
              until (eq dump-id :eof)
              when (integerp dump-id) do
                (let* ((name (cfasl-input stream))
                       (guid (cfasl-input stream))
                       (guid-str (if (guid-p guid) (guid-string guid) guid)))
                  (when (< dump-id (length *constant-names*))
                    (setf (aref *constant-names* dump-id) name)
                    (setf (aref *constant-guids* dump-id) guid-str))))))))

(defun read-nart-hl-formulas-eager (directory)
  "Read nart-hl-formula.cfasl, return alist of (dump-id . formula)."
  (let ((path (cfasl-file-path directory "nart-hl-formula"))
        (result nil))
    (when (probe-file path)
      (with-cfasl-file (stream path)
        (loop for dump-id = (cfasl-input stream nil :eof)
              until (eq dump-id :eof)
              when (integerp dump-id) do
                (push (cons dump-id (cfasl-input stream)) result))))
    (nreverse result)))

(defun read-clause-strucs (directory)
  "Read clause-struc.cfasl, return alist of (dump-id . cnf)."
  (let ((path (cfasl-file-path directory "clause-struc"))
        (result nil))
    (when (probe-file path)
      (with-cfasl-file (stream path)
        (loop for dump-id = (cfasl-input stream nil :eof)
              until (eq dump-id :eof)
              when (integerp dump-id) do
                (let ((cnf (cfasl-input stream))
                      (assertions (cfasl-input stream)))
                  (declare (ignore assertions))
                  (push (cons dump-id cnf) result)))))
    (nreverse result)))

(defun read-assertions-eager (directory)
  "Read assertion.cfasl, return list of assertion plists (with :dump-id)."
  (let ((path (cfasl-file-path directory "assertion"))
        (result nil))
    (when (probe-file path)
      (with-cfasl-file (stream path)
        (loop for dump-id = (cfasl-input stream nil :eof)
              until (eq dump-id :eof)
              when (integerp dump-id) do
                (let ((formula-data (cfasl-input stream))
                      (mt (cfasl-input stream))
                      (flags (cfasl-input stream))
                      (arguments (cfasl-input stream))
                      (plist (cfasl-input stream)))
                  (declare (ignore arguments))
                  (push (list :dump-id dump-id
                              :formula-data formula-data
                              :mt mt
                              :flags flags
                              :plist plist)
                        result)))))
    (nreverse result)))


;;;; ----------------------------------------------------------------
;;;; CNF → EL conversion
;;;; ----------------------------------------------------------------

(defun cnf-p (form)
  "Is FORM a CNF clause (neg-lits pos-lits)?"
  (and (consp form)
       (= 2 (length form))
       (listp (car form))
       (listp (cadr form))
       ;; Distinguish from a 2-element EL formula like (#$pred #$arg)
       ;; by checking that elements of pos/neg lists are themselves lists (literals)
       (or (null (car form))
           (consp (caar form)))
       (or (null (cadr form))
           (consp (caadr form)))))

(defun cnf-to-el (neg-lits pos-lits)
  "Convert CNF (neg-lits pos-lits) to EL.
Variable names are resolved via *variable-names* binding at print time."
  (let ((ante (wrap-conjunction neg-lits))
        (cons (wrap-conjunction pos-lits)))
    (cond
      ((and ante cons) (list #$implies ante cons))
      (ante (list #$not ante))
      (cons cons)
      (t nil))))

(defun wrap-conjunction (lits)
  (cond ((null lits) nil)
        ((null (cdr lits)) (car lits))
        (t (cons #$and lits))))


(defun contains-assertion-ref-p (form)
  "Return T if FORM contains any assertion-ref objects."
  (cond
    ((assertion-ref-p form) t)
    ((consp form) (or (contains-assertion-ref-p (car form))
                      (contains-assertion-ref-p (cdr form))))
    (t nil)))

(defun write-assertion-with-refs (stream formula mt strength direction)
  "Write a ke-assert form where the formula contains assertion references.
Uses backquote+comma so find-assertion-cycl calls are evaluated."
  (write-string "(ke-assert `" stream)
  (write-form-with-refs stream formula)
  (write-char #\Space stream)
  (prin1 mt stream)
  (format stream " ~s" strength)
  (when direction (format stream " ~s" direction))
  (write-char #\) stream))

(defun write-form-with-refs (stream form)
  "Write FORM, inserting ,(...) around assertion-ref objects."
  (cond
    ((assertion-ref-p form)
     (write-char #\, stream)
     (prin1 form stream))
    ((null form)
     (write-string "nil" stream))
    ((consp form)
     (write-char #\( stream)
     (write-form-with-refs stream (car form))
     (do ((tail (cdr form) (cdr tail)))
         ((null tail))
       (cond
         ((consp tail)
          (write-char #\Space stream)
          (write-form-with-refs stream (car tail)))
         (t
          (write-string " . " stream)
          (write-form-with-refs stream tail))))
     (write-char #\) stream))
    (t (prin1 form stream))))

(defun write-license-header (stream)
  "Copy the project license header to STREAM."
  (let ((path (merge-pathnames "larkc-cycl/license-header"
                               (asdf:system-source-directory :clyc))))
    (with-open-file (in path)
      (loop for line = (read-line in nil nil)
            while line do
              (write-line line stream)))))

(defun decode-assertion-flags (flags)
  "Decode flags integer into (values strength direction)."
  (let* ((dir-code (ldb (byte 2 1) flags))
         (tv-code (ldb (byte 3 3) flags))
         (direction (nth dir-code '(:backward :forward :code)))
         (tv (nth tv-code '(:true-mon :true-def :unknown :false-def :false-mon)))
         (strength (case tv
                     ((:true-mon :false-mon) :monotonic)
                     (t :default))))
    (values strength direction)))


;;;; ----------------------------------------------------------------
;;;; Main entry point
;;;; ----------------------------------------------------------------

(defun cfasl-kb-to-sexpr (kb-directory output-file)
  "Read CFASL KB dump and write executable ke-assert forms.
Constants print as #$Name via the constant print-object method."
  (let ((dir (pathname (if (char= (char kb-directory (1- (length kb-directory))) #\/)
                           kb-directory
                           (concatenate 'string kb-directory "/")))))
    (format t "~&;;; Reading KB from ~a~%" dir)
    (setf *constant-names* nil *constant-guids* nil
          *nart-formulas* nil *clause-struc-data* nil
          *assertion-formulas* nil)

    ;; Init variable table (needed by cfasl-input-variable)
    (setup-variable-table)

    ;; Register dictionary opcode (elided from system but used in CFASL)
    (register-cfasl-input-function 61 'cfasl-input-hashtable)
    ;; Override fort-id-index to avoid needing KB tables
    (register-cfasl-input-function 99 'sexpr-input-fort-id-index)

    ;; Phase 0: Common symbols
    (format t ";;; Reading common symbols...~%")
    (let ((common-symbols-raw
            (let ((*cfasl-common-symbols* nil))
              (cfasl-set-common-symbols nil)
              (let ((path (cfasl-file-path dir "special")))
                (when (probe-file path)
                  (with-cfasl-file (stream path)
                    (cfasl-input stream)))))))
      (cfasl-set-common-symbols common-symbols-raw)

      ;; Phase 1: Constants
      (format t ";;; Reading constants...~%")
      (with-cfasl-handles (read-constant-shells dir))

      (let ((nart-count (or (read-text-count dir "nart-count") 0)))

        (with-cfasl-handles
          ;; Phase 2: NARTs
          (format t ";;; Reading NARTs...~%")
          (let ((nart-data (read-nart-hl-formulas-eager dir)))
            (setf *nart-formulas* (make-array (max nart-count 1) :initial-element nil))
            (dolist (entry nart-data)
              (when (< (car entry) (length *nart-formulas*))
                (setf (aref *nart-formulas* (car entry)) (cdr entry)))))

          ;; Phase 3: Clause-strucs
          (format t ";;; Reading clause-strucs...~%")
          (let ((cs-data (read-clause-strucs dir)))
            (setf *clause-struc-data* (make-hash-table))
            (dolist (entry cs-data)
              (setf (gethash (car entry) *clause-struc-data*) (cdr entry))))

          ;; Phase 4: Assertions
          (format t ";;; Reading assertions...~%")
          (let ((assertions (read-assertions-eager dir))
                (assertion-count (or (read-text-count dir "assertion-count") 0)))
            ;; Build assertion formula table for resolving cross-references.
            ;; Store each assertion's EL formula with variable names resolved.
            (setf *assertion-formulas* (make-array (max assertion-count 1) :initial-element nil))
            (dolist (a assertions)
              (let* ((id (getf a :dump-id))
                     (mt (getf a :mt))
                     (fd (getf a :formula-data))
                     (flags (getf a :flags))
                     (plist (getf a :plist))
                     (*variable-names* (getf plist 'variable-names))
                     (gaf? (oddp flags))
                     (formula (cond
                                ((and gaf? (not (cnf-p fd))) fd)
                                ((cnf-p fd)
                                 (cnf-to-el (car fd) (cadr fd)))
                                (t fd))))
                (when (and formula (< id (length *assertion-formulas*)))
                  (setf (aref *assertion-formulas* id)
                        (list mt formula *variable-names*)))))
            (format t ";;; Writing ~d assertions to ~a...~%" (length assertions) output-file)
            (with-open-file (out output-file :direction :output :if-exists :supersede)
              (let ((*print-readably* t)
                    (*print-pretty* nil)
                    (*print-right-margin* nil)
                    (*print-length* nil)
                    (*print-level* nil)
                    (*print-case* :downcase)
                    (*package* (find-package :clyc)))
                (write-license-header out)
                (format out ";;; -*- mode: lisp; package: clyc -*-~%")
                (format out ";;; Converted KB — ~d assertions~%~%" (length assertions))
                (dolist (a assertions)
                  (write-assertion out a))))
            (format t ";;; Done. Output in ~a~%" output-file)
            output-file))))))


(defun write-assertion (stream assertion)
  "Write a single ke-assert form for ASSERTION."
  (let* ((formula-data (getf assertion :formula-data))
         (mt (getf assertion :mt))
         (flags (getf assertion :flags))
         (plist (getf assertion :plist))
         (*variable-names* (getf plist 'variable-names))
         (gaf? (oddp flags)))
    (multiple-value-bind (strength direction) (decode-assertion-flags flags)
      (let ((formula (cond
                       ((and gaf? (not (cnf-p formula-data)))
                        formula-data)
                       ((cnf-p formula-data)
                        (cnf-to-el (car formula-data) (cadr formula-data)))
                       (t formula-data))))
        (when formula
          (if (contains-assertion-ref-p formula)
              (write-assertion-with-refs stream formula mt strength direction)
              (progn
                (write-string "(ke-assert '" stream)
                (prin1 formula stream)
                (write-char #\Space stream)
                (prin1 mt stream)
                (format stream " ~s" strength)
                (when direction (format stream " ~s" direction))
                (write-char #\) stream)))
          (terpri stream))))))
