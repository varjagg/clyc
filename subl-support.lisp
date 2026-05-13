#|
  Copyright (c) 2019 White Flame

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
|#

;; Bits and bobs for providing SubL and Java stdlib stuff

(defpackage :clyc
  (:use :common-lisp)
  (:shadow cl:check-type
           cl:defvar
           cl:defparameter
           cl:defconstant
           cl:sxhash
           cl:variable
           cl:remf))

(in-package :clyc)

;; TODO - code probably has some alexandria prefixes left in it
;; Cherry pick from alexandria to minimize potential conflicts
(import '(alexandria:symbolicate
          alexandria:when-let
          alexandria:when-let*
          alexandria:if-let
          alexandria:deletef
          alexandria:once-only
          alexandria:with-gensyms))


(cl:defvar *macro-helpers* nil
  "a-list of defun name to macro name. There might be multiple entries for each defun name, if they're used by more than one macro.")

(cl:defvar *obsolete-functions* nil
  "List of function names marked as obsolete.")

;;------
;; Variable definitions

;; There's 2 main options in defining variables, which creates 4 ways of binding them.  The two options are:
;;  dynamic = can have dynamic bindings per thread
;;  reinitializing = if the code is (re)loaded, the initialization value overwrites the prior value.

;;  defglobal    = plain baseline variable, initialized once on creation
;;  deflexical   = reinitializing (eg, this file lexically "owns" the value dec)
;;  defvar       = dynamic (same as CL)
;;  defparameter = dynamic + reinitializing (same as CL)
;;
;;  defconstant  = plain variable, but the binding is immutable

(defmacro defglobal (name val &optional doc)
  "Plain variable.  Like defvar — only sets on first load, preserves on reload."
  `(cl:defvar ,name ,val ,@ (and doc (list doc))))

(defmacro deflexical (name val &optional doc)
  "Reinitialized variable.  The 'lexical' in the name implies this file 'owns' the var, since it is in charge of setting its value."
  ;; Evaluate val BEFORE defglobal binds the variable, so that reload guards
  ;; like (if (boundp '*foo*) *foo* (init-form)) see the correct boundp state.
  ;; SBCL's defglobal works like defvar (only sets on first definition),
  ;; so we manually setf on reload.
  #+sbcl (let ((g (gensym "DEFLEXICAL-VAL")))
           `(let ((,g ,val))
              (sb-ext:defglobal ,name nil ,@ (and doc (list doc)))
              (setf ,name ,g)))
  #-sbcl `(cl:defparameter ,name ,val ,@ (and doc (list doc))))


(defmacro defvar (name val &optional doc)
  "Dynamic variable."
  `(cl:defvar ,name ,val ,@ (and doc (list doc))))

(defmacro defparameter (name val &optional doc)
  "Dynamic, reinitialized variable."
  `(cl:defparameter ,name ,val ,@ (and doc (list doc))))

(defmacro defconstant (name val &optional doc)
  "Constant variable binding. If the value is composite, its internals can still be changed."
  ;; The Cyc codebase uses *-earmuffed constant names instead of '+',
  ;; which is a SBCL runtime style warning
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (handler-bind (#+sbcl(sb-kernel:asterisks-around-constant-variable-name #'muffle-warning))
       (unless (boundp ',name)
         (cl:defconstant ,name ,val ,doc)))))



;;------
;; Cross referencing tools

;; Left as a macro to hook in file-load behavior, if necessary
(defmacro toplevel (&body rest) `(progn ,@rest))

;; SubL `fif` is a functional if: (fif test then else). In SubL all args are
;; evaluated eagerly (function-call semantics), but since the return is the
;; then-or-else value, a macro wrapping CL IF gives the same result.
(defmacro fif (test then else) `(if ,test ,then ,else))

(defparameter *file-defs* (make-hash-table :test #'eq)
  "symbol -> declaration in the form of (<filename> <defintion-type> <symbol>).")
(defparameter *file-refs* (make-hash-table :test #'equal)
  "filename -> list of declarations as above.  Intermediately, this holds just filename->list-of-symbol mappings until the final computation.")

(defun reset-file-cross-references ()
  (clrhash *file-defs*)
  (clrhash *file-refs*))

(defun cross-reference-files ()
  (maphash (lambda (filename syms)
             ;; unceremoniously trampling the value
             (setf (gethash filename *file-refs*)
                   ;; Try to find each sym in the defs table
                   (loop for sym in syms
                      for def = (gethash sym *file-defs*)
                      ;; Filter out refs that are defined in this file
                      when (and def (not (equal filename (first def))))
                      collect def)))
           *file-refs*))

(defmacro macro-helpers (macro-name &body body)
  ;; TODO - verify the macros exist, and that no other references to the function does
  (declare (ignore macro-name))
  `(progn
     ,@body))

;; TODO - add (%meta ...) into defun & defmacro
;;  :inline t
;;  :deprecate <favored function>
;;  :private t
;; also scan the body for cross-reference purposes

(defmacro file (filename &body body)
  ;; Analyze the body for what it defines, for dependency tracking
  (let (;; List of (defun funcname) etc
        (defs nil)
        ;; List of non-imported symbols used in the body, includes locals, literals, etc
        ;; This will be pruned by searching the union of all defs later.
        ;; Of course a true code walker would be handy, but that filter will work.
        (raw-refs nil))
    (labels ((scan-for-defs (form)
               (when (consp form)
                 (let ((head (car form)))
                   ;; Anything starting with DEF is assumed to have a naming symbol
                   (if (string= "DEF" (subseq (symbol-name head) 0 3))
                       (push (list filename (first form) (second form)) defs)
                       ;; Scall all the subelements, as the toplevel might be wrapping defs
                       (mapc #'scan-for-defs form)))))
             (scan-for-refs (form)
               (cond
                 ((consp form) (progn (scan-for-refs (car form))
                                      (scan-for-refs (cdr form))))
                 (t (when (and (symbolp form)
                               (eq *package* (symbol-package form)))
                      (pushnew form raw-refs))))))
      (mapc #'scan-for-defs body)
      (scan-for-refs body))
    ;; Now the actual expansion.
    `(progn
       ;; Cross-reference stuff only runs at toplevel, not compile-time
       (dolist (def ',defs) (setf (gethash (third def) *file-defs*) def))
       (setf (gethash ',filename *file-refs*) ',raw-refs)
       ;; The actual body must be available at compile-time for access from subsequent files
       (eval-when (:compile-toplevel :load-toplevel :execute)
         ,@body))))







;;------
;; Random stuff to fill in stdlib, accreted as needed.  TODO - organize when it's settled in.


(defun declare-defglobal (global)
  "Mark GLOBAL as a world-reinitialized variable. No-op in the CL port."
  (declare (ignore global))
  nil)

(defmacro missing-larkc (id)
  `(error ,(if (stringp id)
               id
               (format nil "This call was replaced for LarKC purposes. Originally a method was called. Refer to number ~a" id))))

(defmacro missing-function-implementation (name)
  `(defun ,name (&rest args)
     (error "LarKC declared, referenced, but didn't implement function: ~s" (cons ',name args))))

(let ((package (find-package "KEYWORD")))
  (defun make-keyword (str)
    (intern (string str) package)))

(defun register-macro-helper (funcname macro-names)
  (dolist (macroname (if (listp macro-names)
                         macro-names
                         (list macro-names)))
    (pushnew (cons funcname macroname) *macro-helpers* :test #'equal)))

(defmacro defun* (name params (&key inline ignore macro-helper obsolete) &body body)
  "Ignore will ignore all params for empty bodies, usually for missing or default behavior."
  `(progn
     ,(when inline
        `(declaim (inline ,name)))
     ,(when macro-helper
        `(register-macro-helper ',name ',macro-helper))
     ,(when obsolete
        `(pushnew ',name *obsolete-functions*))
     (defun ,name ,params
       ,@(when ignore
           `((declare (ignore ,@params))))
       ,@body)))

(defmacro check-type (obj type-symbol)
  "This is configured to be ignored in the LarKC version."
  (declare (ignore obj type-symbol))
  nil)

(defun enforce-type (obj predicate)
  "The predicate is a symbol which names a unary function, as well as can be printed."
  (unless (funcall predicate obj)
    (error "Got invalid type for object: ~s. Wanted type: ~a Actual type: ~s" obj predicate (type-of obj))))

(defmacro csome ((var list exit-test) &body body)
  "This is often used in general list iteration processing, not necessarily as an exists check. DONE-FORM is a form called before each iteration. If it returns non-NIL the loop is aborted. VAR and LIST work like dolist. Returns the last computed value from the body, or NIL if no iteration ran, which is the main difference from CL:SOME. If the result is simply a boolean, it can probably be reduced to CL:SOME."
  `(let ((result nil))
     (dolist (,var ,list)
       (when ,exit-test
         (return result))
       (setf result (progn ,@body)))))

(defmacro push-last (val place)
  (alexandria:with-gensyms (new-cons list)
    `(let ((,new-cons (cons ,val nil))
           (,list ,place))
       (if ,list
           (rplacd-last ,list ,new-cons)
           (setf ,place ,new-cons)))))

(defmacro pushnew-last (val place &optional (test #'eql))
  (alexandria:once-only (val)
    `(unless (member ,val ,place :test ,test)
       (push-last ,val ,place))))

(defmacro npush-list (list place)
  `(setf ,place (nconc ,list ,place)))

(defun put (symbol key val)
  (setf (get symbol key) val))

(defvar *ignore-musts?* nil)

(defmacro must (expr &rest error-stuff)
  `(unless *ignore-musts?*
     (unless ,expr
       (error ,@error-stuff))))

(defmacro must-not (expr &rest rest)
  `(must (not ,expr) ,@rest))

(defmacro while (expr &body body)
  `(loop while ,expr do (progn ,@body)))

(defmacro until (expr &body body)
  `(loop until ,expr do (progn ,@body)))

(declaim (inline gethash-without-values))
(defun gethash-without-values (key hash-table &optional default)
  (gethash key hash-table default))

(declaim (inline sublisp-boolean))
(defun sublisp-boolean (object)
  "[Cyc] Convert OBJECT to T or NIL."
  (not (null object)))

(declaim (inline fixnump))
(defun fixnump (expr)
  (typep expr 'fixnum))

(declaim (inline doublep))
(defun doublep (expr)
  (typep expr 'double-float))

(defun function-spec-p (object)
  "SubL isFunctionSpec() — true if OBJECT is a valid function specifier:
either a function object or a symbol naming a bound function."
  (or (functionp object)
      (and (symbolp object)
           (fboundp object))))

(defmacro do-plist ((key val list) &body body)
  `(loop for (,key ,val) on ,list by #'cddr
        do (progn ,@body)))

(defmacro do-alist ((key val list) &body body)
  (alexandria:with-gensyms (cell)
    `(dolist (,cell ,list)
       (let ((,key (car ,cell))
             (,val (cdr ,cell)))
         ,@body))))

(defmacro do-dictionary ((key value dictionary &optional done) &body body)
  (alexandria:with-gensyms (dict cell)
    `(let ((,dict ,dictionary))
       (block nil
         (cond
           ((hash-table-p ,dict)
            (maphash (lambda (,key ,value)
                       (declare (ignorable ,key ,value))
                       (when ,done
                         (return ,done))
                       ,@body
                       (when ,done
                         (return ,done)))
                     ,dict))
           ((listp ,dict)
            (dolist (,cell ,dict)
              (let ((,key (car ,cell))
                    (,value (cdr ,cell)))
                (declare (ignorable ,key ,value))
                (when ,done
                  (return ,done))
                ,@body
                (when ,done
                  (return ,done))))))))))

(defmacro do-list ((var list &key done) &body body)
  `(block nil
     (dolist (,var ,list)
       (declare (ignorable ,var))
       (when ,done
         (return ,done))
       ,@body
       (when ,done
         (return ,done)))))

(defmacro dosome ((var list &optional done) &body body)
  `(do-list (,var ,list :done ,done)
     ,@body))

(defmacro dohash ((key val hashtable) &body body)
  `(block nil
     (maphash (lambda (,key ,val)
                (declare (ignorable ,key ,val))
                ,@body)
              ,hashtable)))

(defmacro dovector ((index val vector) &body body)
  ;; TODO - convert to DO, probably faster as this version maintains a hidden index anyway
  ;; All subl vectors are simple, saves some good speed
  `(loop for ,val across (the simple-vector ,vector)
         for ,index fixnum from 0
      do (progn ,@body)))

(defmacro dolistn ((index val list) &body body)
  "Like dolist, but also binds a 0-based index variable as the iteration progresses."
  `(let ((,index 0))
     (declare (fixnum ,index))
     (dolist (,val ,list)
       ,@body
       (incf ,index))))

(declaim (inline simple-reader-error))
(defun simple-reader-error (&rest rest)
  (apply #'error rest))

(declaim (inline make-vector))
(defun make-vector (size &optional initial-element)
  (make-array (list size) :initial-element initial-element))

;; These two are used as default functions, like IDENTITY
(defun true (&rest rest)
  (declare (ignore rest))
  t)

(defun false (&rest rest)
  (declare (ignore rest))
  nil)

(defun putf (plist indicator value)
  "Destructively returns a list with the added/changed, instead of mutating a place."
  (or (loop
         for cell on plist by #'cddr
         when (eq indicator (car cell))
         return (progn
                  (setf (car (cdr cell)) value)
                  plist))
      (cons indicator (cons value plist))))

(defun remf (plist indicator)
  "Destructively returns a plist without the given key/indicator."
  (loop
     for prev = nil then cell
     for cell on plist by #'cddr
     do (when (eq indicator (car cell))
          (return-from remf
            (if prev
                (progn
                  (setf (cdr (cdr prev)) (cdr (cdr cell)))
                  plist)
                (cdr (cdr cell))))))
  plist)

(defmacro symbol-mapping (&rest plist)
  `(progn
     ,@ (loop for (from to) on plist by #'cddr
           collect `(progn
                      (define-symbol-macro ,from ',to)
                      (defmacro ,from (&rest rest) (cons ',to rest))))))

(defun read-32bit-be (stream)
  "Reads a 4-byte, unsigned, big-endian binary number from the stream."
  ;; TODO - might be faster if we read a single 4-byte sequence, then assemble from that.
  (logior (ash (read-byte stream) 24)
          (ash (read-byte stream) 16)
          (ash (read-byte stream) 8)
          (read-byte stream)))

(defun open-binary (filename direction &rest open-args)
  "Open FILENAME as an unsigned-byte stream, using SubL-style argument order."
  (apply #'open filename
         :direction direction
         :element-type '(unsigned-byte 8)
         open-args))

(defun open-text (filename direction &rest open-args)
  "Open FILENAME as a character stream, using SubL-style argument order."
  (apply #'open filename
         :direction direction
         open-args))

(defun directory-p (path)
  "Return true when PATH names an existing directory."
  (and (ignore-errors (uiop:directory-exists-p path))
       t))

(declaim (inline get-file-position))
(defun get-file-position (stream)
  (file-position stream))

(defun current-process ()
  (bt:current-thread))

(declaim (inline set-file-position))
(defun set-file-position (stream index)
  (file-position stream index))

(defmacro on-error (form &body handler)
  `(handler-case ,form
     (error () ,@handler)))

(defmacro setf-error (place &body body)
  "If an error is raised in running BODY, store it in PLACE and return."
  `(handler-case (progn ,@body)
     (error (e) (setf ,place e))))

(declaim (inline get-process-id))
(defun get-process-id ()
  (sb-posix:getpid))

(defun gethash-and-remove (key hashtable &optional default)
  (multiple-value-bind (val found?) (gethash key hashtable)
    (if found?
        (progn
          (remhash key hashtable)
          val)
        default)))

(defmacro defpolymorphic (name args &body body)
  "Default args & body for the non-specialized default implementation."
  `(progn
     (cl:defgeneric ,name ,args)
     (cl:defmethod ,name ,args ,@body)))

;; duplicate function-spec-p removed — already defined at line 288

(defmacro prog1-let (((name val)) &body body)
  "Creates a single LET binding for a value to be returned."
  `(let ((,name ,val))
     ,@body
     ,name))

(defmacro prog1-when (val &body body)
  (alexandria:once-only (val)
    `(prog1 ,val
       (when ,val
         ,@body))))

;; A java ReentrantReadWriteLock allows multiple readers as long as there's no writer, or a single exclusive writer with no readers. So all will lock a central lock, check if it can work, or wait on an appropriate condition variable, and release the central lock. Exiting a "lock" will again gain the central lock, deregister itself, and notify any appropriate cv.
;; For optimization, fairness, and good ordering semantics, writers could be queued in order of attempt, and readers can block if a writer is already queued instead of starting new read work when write work is waiting.
;; TODO HACK - just to get this up and running, I'll serialize all access for now. Plus, I don't know how often this is used anyway.

(defstruct (rw-lock (:constructor %make-rw-lock))
  lock)

(defun new-rw-lock (name)
  (%make-rw-lock :lock (bt:make-recursive-lock name)))

(defmacro with-rw-read-lock ((rw-lock) &body body)
  `(bt:with-recursive-lock-held ((rw-lock-lock ,rw-lock))
     ,@body))

(defmacro with-rw-write-lock ((rw-lock) &body body)
  `(bt:with-recursive-lock-held ((rw-lock-lock ,rw-lock))
     ,@body))

;;; SubL process-wait — condition-variable based replacement for SubL's
;;; polling process_wait. The original SubL runtime polled with 1s sleeps;
;;; this implementation blocks on a condition variable so callers that signal
;;; the CV get instant wakeup, while a timeout handles periodic checks.

(defvar *process-wait-lock* (bt:make-lock "Process Wait Lock"))
(defvar *process-wait-cv* (bt:make-condition-variable :name "Process Wait CV"))

(defun process-wait (whostate predicate)
  "Block the calling thread until PREDICATE (a zero-arg function) returns non-NIL.
WHOSTATE is a descriptive string for debugging (ignored at present).
The predicate is polled, not run in a separate thread.

Implementation uses a condition variable (*process-wait-cv*) with a 1s fallback
timeout.  Code that changes state the predicate tests should call
  (bt:condition-notify *process-wait-cv*)
to wake the waiter immediately instead of waiting up to 1s."
  (declare (ignore whostate))
  (unless (funcall predicate)
    (bt:with-lock-held (*process-wait-lock*)
      (loop until (funcall predicate)
            do (bt:condition-wait *process-wait-cv* *process-wait-lock*
                                  :timeout 1))))
  t)

(defun process-wait-with-timeout (timeout whostate predicate)
  "Like PROCESS-WAIT, but gives up after TIMEOUT seconds.
Returns T if predicate became true, NIL on timeout.
Same condition-variable wakeup mechanism as process-wait."
  (declare (ignore whostate))
  (when (funcall predicate)
    (return-from process-wait-with-timeout t))
  (let ((deadline (+ (get-internal-real-time)
                     (* timeout internal-time-units-per-second))))
    (bt:with-lock-held (*process-wait-lock*)
      (loop
        (when (funcall predicate)
          (return t))
        (let ((remaining (/ (- deadline (get-internal-real-time))
                            internal-time-units-per-second)))
          (when (<= remaining 0)
            (return nil))
          (bt:condition-wait *process-wait-cv* *process-wait-lock*
                             :timeout (min remaining 1)))))))

(defun construct-filename (dir-list filename &optional ext rel?)
  (princ-to-string (make-pathname :directory (cons (if rel? :relative :absolute) dir-list)
                                  :name (if ext
                                            (concatenate 'string filename "." ext)
                                            filename))))

(defun seed-random (&optional seed)
  (setf *random-state* (if seed
                           ;; Only SBCL provides a repeatable numeric random seeding
                           (sb-ext:seed-random-state seed)
                           (make-random-state t))))
                           
