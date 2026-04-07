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

;; Two distinct caching mechanisms in the Java:
;;   "Caching" (DEFINE-CACHED-NEW) = global persistent cache in a deflexical *name-caching-state*.
;;     Always caches. Lisp macro: defun-cached.
;;   "Memoization" (DEFINE-MEMOIZED) = state-dependent cache inside *memoization-state*.
;;     Only caches when a memoization state is bound. Lisp macro: defun-memoized.


(defconstant *global-caching-lock* (bt:make-lock "global-caching-lock"))
(defglobal *caching-mode-should-monitor* nil
  "[Cyc] Whether to enable cache monitoring. Need to do a retranslation after changing this.")
(defglobal *cache-monitor-hash* (make-hash-table)
  "[Cyc] Hashtable for monitoring all caching calls.")
(defglobal *cache-monitor-failure-hash* (make-hash-table)
  "[Cyc] Hashtable for monitoring cached calls that aren't already cached.")
(defglobal *allow-function-caching-to-be-disabled* nil
  "[Cyc] This indicates that when evaluating the function caching macros, whether to test if the function should be disabled. Not testing for disabled is generally faster but less flexible because then you can no longer dynamically disable function caching. You'll need to do a new translation after setting this for it to take effect.")
(defvar *caching-mode-enabled* :all
  "[Cyc] Caching mode function indicating what's enabled.")
(defvar *caching-mode-disabled* nil
  "[Cyc] Caching mode function indicating what's disabled.")
(defparameter *function-caching-enabled?* t
  "[Cyc] Global caching and memoization are disabled when NIL.")

;; CL equivalent of the fixed-arity sxhash_calc_N functions from the Java.
;; The Java used sxhash_rot + logxor with a state vector; we use SBCL's
;; sb-int::mix which is the same idea (combine two hash codes into one).
(defmacro multi-hash (&rest hashes)
  "Combine fixnum hashes together, using platform-specific hashing. Should not cons."
  (reduce (lambda (x y) `(sb-int::mix ,x (cl:sxhash ,y))) hashes))

;; DESIGN - The original SubL caching-state used manual sxhash-calc-N + collision lists
;; for multi-arg functions to avoid consing a list key on every call, since SubL hash
;; tables couldn't hash list keys with equal. The sxhash was computed without consing,
;; collisions were walked comparing each arg individually, and the key was only consed
;; on a cache miss.
;;
;; CL SIMPLIFICATION: CL hash tables with :test 'equal natively hash and compare list
;; keys, so the entire manual sxhash/collision-list mechanism is unnecessary. The macros
;; (defun-cached, defun-memoized) now use (list arg1 arg2 ...) as the hash key directly.
;; This does cons a list on every call, but the simplicity gain is worth it — CL
;; implementations optimize sxhash for lists internally using the same techniques.
;; The functions multi-hash, sxhash-calc-N, and caching-state-enter-multi-key-n are
;; retained for backward compatibility but are no longer used by the macros.
;; The zero-arg caching scheme is still broken out to its own storage slot.

;; This also stores the multiple-value-list of the calculation, instead of just a single return value.  TODO DESIGN - optimizing a route for single-value returns can save consing & speed

;; Also, the caches can be selectively cleared, so having knowledge of which global variables hold the cahing states of various usages needs to remain exposed.


(defstruct caching-state
  store
  zero-arg-results
  lock
  capacity
  func-symbol
  test
  args-length)

(defun create-caching-state (lock func-symbol func-args-length &optional capacity (test #'eql) (initial-size 0))
  (declare ((integer 0) initial-size)
           ((or null (integer 1)) capacity)
           ((or symbol function) test))
  ;; CL SIMPLIFICATION: The original SubL used eql with manual sxhash+collision-lists
  ;; for multi-arg functions because SubL hash tables couldn't hash list keys.
  ;; In CL, the macros pass (list arg1 arg2 ...) as the key, which requires :test equal.
  ;;
  ;; For 1-arg, the caller's test is used directly (matching original SubL behavior).
  ;; For 2+ args, we force equal regardless of the caller's test. This is slightly
  ;; more permissive than the original: if the SubL specified :test eq, each element
  ;; was compared with eq in the collision walk. With equal, eql-but-not-eq values
  ;; could match. Confirmed safe: all multi-arg :test eq functions use identity objects
  ;; (FORTs, MTs, keywords, inference structures, small fixnums) — never cons lists or strings.
  (setf test (if (> func-args-length 1)
                 #'equal
                 (coerce test 'function)))
  (make-caching-state :store (if capacity
                                 (new-cache capacity test)
                                 (make-hash-table :test test :size initial-size))
                      :lock lock
                      :capacity capacity
                      :func-symbol func-symbol
                      :test test
                      :args-length func-args-length
                      :zero-arg-results :&memoized-item-not-found&))

(defmacro with-caching-state-lock (cs cache-form &optional hash-form)
  "Runs the body in the cs's lock, or plain if its lock is NIL. If the hash-form is omitted, the same form is run regardless of the store type."
  (alexandria:with-gensyms (lock worker)
    (alexandria:once-only (cs)
      `(let ((,lock (caching-state-lock ,cs)))
         ;; Wrap the body in a function that can be called from 2 places
         (flet ((,worker ()
                  ;; Unhygienic but useful value
                  (let ((store (caching-state-store ,cs)))
                    (declare (ignorable store))
                    ,(if hash-form
                         `(if (caching-state-capacity ,cs) ,cache-form ,hash-form)
                         cache-form))))
           (if ,lock
               (bt:with-lock-held (,lock)
                 (,worker))
               (,worker)))))))

(defun caching-state-get-zero-arg-results (caching-state)
  (with-caching-state-lock caching-state
    (caching-state-zero-arg-results caching-state)))

(defun caching-state-set-zero-arg-results (caching-state val)
  (with-caching-state-lock caching-state
    (setf (caching-state-zero-arg-results caching-state) val)))

(defun caching-state-lookup (caching-state key &optional (default :&memoized-item-not-found&))
  (with-caching-state-lock caching-state
    (cache-get-without-values store key default)
    (gethash key store default)))

(defun caching-state-put (caching-state key value)
  (with-caching-state-lock caching-state
    (cache-set store key value)
    (setf (gethash key store) value)))

(defun caching-state-clear (caching-state)
  (when caching-state
    (with-caching-state-lock caching-state
      (progn (cache-clear store)
             (setf (caching-state-zero-arg-results caching-state) :&memoized-item-not-found&))
      (progn (clrhash store)
             (setf (caching-state-zero-arg-results caching-state) :&memoized-item-not-found&)))))

(defun caching-state-enter-multi-key-n (caching-state sxhash collisions results args-list)
  "[Cyc] Cache in CACHING-STATE under hash code SXHASH the fact that ARGS-LIST returns the list of values RESULTS"
  (unless (listp collisions)
    (setf collisions nil))
  (if (not args-list)
      (caching-state-set-zero-arg-results caching-state results)
      (caching-state-put caching-state sxhash (cons (list args-list results) collisions))))


;; Reconstructed from compiled Java output. The SubL compiler expanded DEFINE-CACHED-NEW into:
;;  - a deflexical *name-caching-state* (initialized to NIL)
;;  - a clear-name function (calls caching-state-clear)
;;  - the wrapper function with lazy init of global caching state + cache lookup
;; Results are wrapped in multiple-value-list and unwrapped via caching-results.
;;
;; CL SIMPLIFICATION: The Java had two arity-dependent lookup patterns:
;;  1-arg: direct caching-state-lookup/put with the arg as key
;;  2+ args: sxhash-calc-N hash + manual collision list (SubL couldn't hash list keys)
;; In CL, both use the same uniform pattern — the key is the arg for 1-arg, or
;; (list arg1 arg2 ...) for 2+ args, with an :equal hash table.
;;
;; NOTE: This is the GLOBAL caching pattern (Java DEFINE-CACHED-NEW).
;; For STATE-DEPENDENT memoization (Java DEFINE-MEMOIZED), see defun-memoized below.
(defmacro defun-cached (name params (&key (capacity nil) (test 'eql) (initial-size 0)
                                      faccess clear-when declare doc) &body calculate-cache-miss)
  "[Cyc] Define a globally cached function. Reconstructed from DEFINE-CACHED-NEW.
   Original SubL lambda list: (NAME (&REST ARGS) (&KEY TEST CAPACITY FACCESS SIZE CLEAR-WHEN) &BODY BODY)
   FACCESS is ignored (SubL-specific access control). SIZE is renamed INITIAL-SIZE."
  (declare (ignore faccess))
  (let ((varname (symbolicate "*" name "-CACHING-STATE*"))
        (clear-name (symbolicate "CLEAR-" name))
        (nparams (length params))
        (test-form (if (symbolp test) (list 'quote test) test)))
    (alexandria:with-gensyms (cs results)
      `(progn
         (defvar ,varname nil)
         (defun ,clear-name ()
           (let ((cs ,varname))
             (when cs (caching-state-clear cs)))
           nil)
         ;; note-globally-cached-function in toplevel matches Java setup_ phase
         (toplevel
           (note-globally-cached-function ',name))
         (defun ,name ,params
           ,@(when declare `((declare ,@declare)))
           ,@(when doc (list doc))
           ;; Lazy initialization of caching state, matching Java pattern
           (let ((,cs ,varname))
             (when (null ,cs)
               (setf ,cs (create-global-caching-state-for-name
                          ',name ',varname ,capacity ,test-form ,nparams ,initial-size))
               ,@(when clear-when
                   (case clear-when
                     (:hl-store-modified
                      (list `(register-hl-store-cache-clear-callback ',clear-name)))
                     (otherwise (error "Unknown defun-cached :clear-when option: ~s" clear-when))))) ;; closes case, when-splice
             ;; Uniform lookup: 1-arg uses param directly, 2+ uses (list ...) as key
             ,(let ((key-form (if (= 1 nparams)
                                  (first params)
                                  `(list ,@params))))
                `(let ((,results (caching-state-lookup ,cs ,key-form :&memoized-item-not-found&)))
                   (when (eq ,results :&memoized-item-not-found&)
                     (setf ,results (multiple-value-list (progn ,@calculate-cache-miss)))
                     (caching-state-put ,cs ,key-form ,results))
                   (caching-results ,results)))))))))



;; Reconstructed from compiled Java output. The SubL compiler expanded DEFINE-MEMOIZED into:
;;  - a wrapper function that checks *memoization-state*
;;  - if no memoization state, calls the body directly (no caching)
;;  - if memoization state is active, looks up/creates a caching-state keyed by function name
;; The caching-state lives INSIDE the memoization-state, not in a global variable.
;; This means the cache is scoped to the dynamic extent of with-memoization-state.
;; Same CL simplification as defun-cached: 2+ args use (list ...) key with :equal hash table.
(defmacro defun-memoized (name params (&key (test 'eql) capacity faccess
                                             memoization-state-function
                                             memoization-state-function-arg-positions)
                          &body body)
  "[Cyc] Define a state-dependent memoized function. Reconstructed from DEFINE-MEMOIZED.
   Original SubL lambda list: (NAME (&REST ARGS) (&KEY TEST CAPACITY FACCESS
     MEMOIZATION-STATE-FUNCTION MEMOIZATION-STATE-FUNCTION-ARG-POSITIONS) &BODY BODY)
   FACCESS, MEMOIZATION-STATE-FUNCTION, and MEMOIZATION-STATE-FUNCTION-ARG-POSITIONS
   are ignored (SubL-specific). CAPACITY is accepted but unused (state-dependent caches
   don't have fixed capacity). Default TEST is EQL, matching create_caching_state."
  (declare (ignore capacity faccess memoization-state-function
                  memoization-state-function-arg-positions))
  (let ((nparams (length params))
        (test-form (if (symbolp test) (list 'quote test) test)))
    (alexandria:with-gensyms (v-memoization-state caching-state results)
      `(progn
         (toplevel
           (note-memoized-function ',name))
         (defun ,name ,params
           (let ((,v-memoization-state *memoization-state*))
             (when (null ,v-memoization-state)
               (return-from ,name (progn ,@body)))
             (let ((,caching-state (memoization-state-lookup ,v-memoization-state ',name)))
               (when (null ,caching-state)
                 (setf ,caching-state (create-caching-state
                                       (memoization-state-lock ,v-memoization-state)
                                       ',name ,nparams nil ,test-form))
                 (memoization-state-put ,v-memoization-state ',name ,caching-state))
               ,(if (= 0 nparams)
                    ;; 0-arg: use zero-arg-results slot
                    `(let ((,results (caching-state-get-zero-arg-results ,caching-state)))
                       (when (eq ,results :&memoized-item-not-found&)
                         (setf ,results (multiple-value-list (progn ,@body)))
                         (caching-state-set-zero-arg-results ,caching-state ,results))
                       (caching-results ,results))
                    ;; 1+ args: uniform lookup; 1-arg uses param directly, 2+ uses (list ...)
                    (let ((key-form (if (= 1 nparams)
                                        (first params)
                                        `(list ,@params))))
                      `(let ((,results (caching-state-lookup ,caching-state ,key-form :&memoized-item-not-found&)))
                         (when (eq ,results :&memoized-item-not-found&)
                           (setf ,results (multiple-value-list (progn ,@body)))
                           (caching-state-put ,caching-state ,key-form ,results))
                         (caching-results ,results)))))))))))

(defmacro with-memoization-state (state &body body)
  "[Cyc] Execute BODY with *memoization-state* bound to STATE."
  `(let ((*memoization-state* ,state))
     ,@body))

(defmacro with-new-memoization-state (&body body)
  "[Cyc] Execute BODY with a fresh memoization state."
  `(let ((*memoization-state* (create-memoization-state)))
     ,@body))

(defmacro with-possibly-new-memoization-state (&body body)
  "[Cyc] Execute BODY with a memoization state, creating one if needed."
  `(let ((*memoization-state* (possibly-new-memoization-state)))
     ,@body))

(defmacro without-clearing-mt-dependent-caches (&body body)
  "[Cyc] Execute BODY with mt-dependent cache clearing suspended."
  `(let ((*suspend-clearing-mt-dependent-caches?* t))
     ,@body))

(defstruct memoization-state
  store
  current-process
  lock
  name
  should-clone)

(defun create-memoization-state (&optional name lock should-clone (test #'eql))
  "[Cyc] Return a new memoization state suitable for WITH-MEMOIZATION-STATE"
  (declare ((or null string) name)
           ((or null bt:lock) lock)
           ((or symbol function) test))
  (when (and should-clone
             (not lock))
    (setf lock (bt:make-lock "Memoization state clone lock")))
  (make-memoization-state :name name
                          :lock lock
                          :store (make-hash-table :test test)
                          :current-process nil
                          :should-clone should-clone))

  ;; TODO - redundant names, clean it up

(defun new-memoization-state (&optional name lock should-clone (test #'eql))
  (create-memoization-state name lock should-clone test))

(defmacro with-memoization-state-lock (ms &body body)
  "Runs the body in the ms's lock, or plain if its lock is NIL."
  (alexandria:with-gensyms (lock worker)
    (alexandria:once-only (ms)
      `(let ((,lock (memoization-state-lock ,ms)))
         ;; Wrap the body in a function that can be called from 2 places
         (flet ((,worker ()
                  (let ((store (memoization-state-store ,ms)))
                    ,@body)))
           (if ,lock
               (bt:with-lock-held (,lock)
                 (,worker))
               (,worker)))))))

(defun memoization-state-lookup (memoization-state key &optional default)
  (with-memoization-state-lock memoization-state
    (gethash key store default)))

(defun memoization-state-put (memoization-state key value)
  (with-memoization-state-lock memoization-state
    (setf (gethash key store) value)))

(defun memoization-state-clear (memoization-state)
  (when memoization-state
    (with-memoization-state-lock memoization-state
      (clrhash store))))

(defparameter *memoization-state* nil
  "[Cyc] Current memoization state. NIL indicates no memoization is occurring.")

(defun current-memoization-state ()
  "[Cyc] Return the current memoization state, or NIL if none."
  *memoization-state*)

(defun possibly-new-memoization-state ()
  (or *memoization-state*
      (create-memoization-state)))

(defun clear-all-memoization (state)
  (memoization-state-clear state)
  state)

(defglobal *memoized-functions* nil
  "[Cyc] The master list of all functions defined via defun-memoized (state-dependent).")

(defun note-memoized-function (function-symbol)
  (pushnew function-symbol *memoized-functions*)
  function-symbol)

(defglobal *globally-cached-functions* nil
  "[Cyc] The master list of all functions defined via define-cached or define-cached-new")

(defun note-globally-cached-function (function-symbol)
  (pushnew function-symbol *globally-cached-functions*)
  function-symbol)

(defun globally-cached-functions ()
  (remove-if-not #'fboundp *globally-cached-functions*))

(defun global-cache-variables ()
  (remove-if-not #'boundp (mapcar (lambda (name)
                                    ;; TODO - which package?
                                    (intern (format nil "*~a-CACHING-STATE*" name)))
                                  (globally-cached-functions))))

(defun global-cache-variable-values ()
  (mapcar #'symbol-value (global-cache-variables)))

(defun clear-all-globally-cached-functions ()
  (progress-dolist (caching-state (global-cache-variable-values) "Clearing all globally cached functions")
    (when caching-state
      (caching-state-clear caching-state))))

(deflexical *cache-clear-triggers* '(:hl-store-modified
                                     :genl-mt-modified
                                     :genl-preds-modified
                                     :genls-modified
                                     :isa-modified
                                     :quoted-isa-modified)
  "[Cyc] The list of possible triggers which can clear caches when they are triggered. Note that :GENL-PREDS-MODIFIED is also triggered on the addition or removal of a #$genlInverse assertion.")

  ;; TODO - arg ordering is different than create-caching-state

(defun create-global-caching-state-for-name (name cs-variable capacity test args-length size)
  (unless test
    (setf test #'eql))
  (bt:with-lock-held (*global-caching-lock*)
    (or (symbol-value cs-variable)
        (set cs-variable (create-caching-state (bt:make-lock (format nil "global caching lock for ~a" name))
                                               name args-length capacity test size)))))

(defun global-caching-variable-new (name)
  (intern (format nil "*~a-CACHING-STATE*" name)))

(defglobal *hl-store-cache-clear-callbacks* nil
  "[Cyc] The list of zero-arity function-spec-p's to funcall each time the HL store changes. These are intended to clear HL-store-dependent caches.")

(defun register-hl-store-cache-clear-callback (callback)
  "[Cyc] Registers CALLBACK as a function which will be funcalled each time the HL store changes. CALLBACK is a function-spec-p which should take zero arguments."
  (declare (type (satisfies function-spec-p) callback))
  (pushnew callback *hl-store-cache-clear-callbacks*)
  callback)

(defun clear-hl-store-dependent-caches ()
  "[Cyc] Clears all HL store dependent caches, as registered by REGISTER-HL-STORE-CACHE-CLEAR-CALLBACK."
  (dolist (callback *hl-store-cache-clear-callbacks*)
    ;; Adding in both symbol & function object support, just in case.
    ;; Original only checked fboundp, which requires symbols and would error on functions.
    ;; However, that doesn't make much sense as it had to be function-spec-p on registration,
    ;;  and this function's fboundp thus would only fail if the symbol was FMAKUNBOUNDed after registeration.
    (when (function-spec-p callback)
      (funcall callback))))

(defglobal *mt-dependent-cache-clear-callbacks* nil
  "[Cyc] The list of zero-arity function-spec-p's to funcall each time the microtheory structure changes. These are intended to clear mt-dependent caches.")

(defun register-mt-dependent-cache-clear-callback (callback)
  "[Cyc] Registers CALLBACK as a function which will be funcalled each time the microtheory structure changes. CALLBACK should take zero arguments."
  (declare (type (satisfies function-spec-p) callback))
  (pushnew callback *mt-dependent-cache-clear-callbacks*)
  callback)

(defparameter *suspend-clearing-mt-dependent-caches?* nil)

(defun clear-mt-dependent-caches? ()
  (not *suspend-clearing-mt-dependent-caches?*))

(defglobal *genl-preds-dependent-cache-clear-callbacks* nil
  "[Cyc] The list of zero-arity function-spec-p's to funcall each time the genlPreds structure changes. These are intended to clear mt-dependent caches.")
(defglobal *genls-dependent-cache-clear-callbacks* nil
  "[Cyc] The list of zero-arity function-spec-p's to funcall each time the genls structure changes. These are intended to clear mt-dependent caches.")
(defglobal *isa-dependent-cache-clear-callbacks* nil
  "[Cyc] The list of zero-arity function-spec-p's to funcall each time the isa structure changes. These are intended to clear mt-dependent caches.")
(defglobal *quoted-isa-dependent-cache-clear-callbacks* nil
  "[Cyc] The list of zero-arity function-spec-p's to funcall each time the quotedIsa structure changes. These are intended to clear mt-dependent caches.")

(defun* caching-results (results) (:inline t)
  "Returns the list of results as multiple-values."
  ;; Bypass the function call to values-list when there's only 1 result
  ;; TODO - can there be zero results? this code would return 0 results into 1 NIL
  (if (cdr results)
      (values-list results)
      (car results)))

(defconstant *caching-n-sxhash-composite-value* 167)
