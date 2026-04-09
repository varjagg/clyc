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


;;;; ================================
;;;; STARTUP

(setf *silent-progress?* t) ;this removes some printouts
(setf *dump-verbose* NIL) ;this removes some printouts


(defun clyc-init ()
  (system-code-initializations)

  (print (load-kb "src/main/resources/cyc-tiny/"))
  ;;(print (load-kb "ext/rtiny/")) ;; commented out in LarKC's startup, but can't find anything in LarKC named this
  
  ;; System parameters
  (load-system-parameters)

  ;; CycL code initializations, includes KB-dependent initializations
  (system-code-initializations)

  ;; this should be the very last step
  (setf *init-file-loaded?* t)

  (initialize-larkc)
  ;;(start-sparql-server)
  (start-management-interface))



;;;;;;;;;;;;;;;;;;;;;THE FOLLOWING ENABLES OPENCYC API;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;(define robust-enable-tcp-server (type port handler)
;  (pif (fboundp 'enable-tcp-server)
;       ;; new way
;       (ret (enable-tcp-server type port))
;       ;; old way
;       (ret (sl::start-tcp-server port handler nil))))
;
;(csetq *base-tcp-port* 3600)
;(progn
;  (print "Enabling base TCP services to port 3600")
;  (finish-output))
;
;(robust-enable-tcp-server
; :cyc-api (api-port) 'api-server-top-level)
;;; CFASL server
;(robust-enable-tcp-server
; :cfasl (cfasl-port) 'cfasl-server-top-level)




;;;; ================================
;;;; TOPLEVEL UTILITIES


(defun cyc-api-functions ()
  "Return a list of all registered Cyc API functions with their full signatures.
Each entry is a plist with keys :NAME, :TYPE (:FUNCTION or :MACRO), :ARGLIST,
:ARG-TYPES, :RETURN-TYPES, :OBSOLETE-REPLACEMENTS, and :DOC-STRING."
  (let ((result nil))
    (dolist (name *api-symbols*)
      (let ((kind (cond ((gethash name *api-predefined-macro-table*) :macro)
                        ((gethash name *api-predefined-function-table*) :function)
                        (t :unknown)))
            (arglist (get name :cyc-api-args))
            (arg-types (get name :cyc-api-arg-types))
            (return-types (get name :cyc-api-return-types))
            (replacements (get name :obsolete-cyc-api-replacements))
            (doc-string (documentation name 'function)))
        (push (list :name name
                    :type kind
                    :arglist arglist
                    :arg-types arg-types
                    :return-types return-types
                    :obsolete-replacements replacements
                    :doc-string doc-string)
              result)))
    (sort result #'string< :key (lambda (entry) (symbol-name (getf entry :name))))))

(defun format-typed-param (stream param arg-types)
  "Write PARAM to STREAM as name:type if typed, or just name if untyped.
PARAM may be a symbol, or a list like (NAME DEFAULT) for &optional params."
  (let* ((name (if (consp param) (first param) param))
         (type (second (assoc name arg-types))))
    (princ name stream)
    (when type
      (write-char #\: stream)
      (princ type stream))
    (when (and (consp param) (rest param))
      (write-char #\= stream)
      (princ (second param) stream))))

(defun print-typed-arglist (stream arglist arg-types)
  "Print ARGLIST to STREAM with param:type notation for typed parameters."
  (write-char #\( stream)
  (let ((first-p t))
    (dolist (item arglist)
      (unless first-p (write-char #\Space stream))
      (setf first-p nil)
      (if (member item '(&optional &rest &key &body &allow-other-keys))
          (princ item stream)
          (format-typed-param stream item arg-types))))
  (write-char #\) stream))

(defun print-cyc-api-functions (&optional (stream *standard-output*))
  "Print all registered Cyc API functions with their full signatures to STREAM.
Format: Function: NAME (param:type param ...) => return-types"
  (let ((*package* (find-package :clyc))
        (entries (cyc-api-functions)))
    (format stream "~&~d Cyc API entries registered:~%~%" (length entries))
    (dolist (entry entries)
      (let ((name (getf entry :name))
            (kind (getf entry :type))
            (arglist (getf entry :arglist))
            (arg-types (getf entry :arg-types))
            (return-types (getf entry :return-types))
            (replacements (getf entry :obsolete-replacements))
            (doc-string (getf entry :doc-string)))
        (format stream "~:(~a~): ~a " kind name)
        (print-typed-arglist stream arglist arg-types)
        (when return-types
          (format stream " => ~s" return-types))
        (when replacements
          (format stream "~%  OBSOLETE, replaced by: ~s" replacements))
        (terpri stream)
        (when doc-string
          (format stream "~%  ~a~%" doc-string))
        (terpri stream)))))

(defun typed-arglist (arglist arg-types)
  "Merge ARGLIST with ARG-TYPES to produce a lambda list with inline type annotations.
Typed parameters become (PARAM TYPE), untyped remain bare symbols."
  (let ((type-alist (loop for entry in arg-types
                          when (and (consp entry) (= 2 (length entry)))
                            collect (cons (first entry) (second entry)))))
    (loop for item in arglist
          collect (let ((type (and (symbolp item)
                                   (cdr (assoc item type-alist)))))
                    (if type (list item type) item)))))

(defun print-cyc-api-sexp (&optional (stream *standard-output*))
  "Print one s-expression per line for each registered Cyc API entry.
Format: (Function: NAME (typed-arglist) => (return-types) \"doc\")"
  (let ((*package* (find-package :clyc))
        (*print-right-margin* most-positive-fixnum)
        (*print-pretty* nil))
    (dolist (entry (cyc-api-functions))
      (let ((name (getf entry :name))
            (kind (getf entry :type))
            (arglist (getf entry :arglist))
            (arg-types (getf entry :arg-types))
            (return-types (getf entry :return-types))
            (replacements (getf entry :obsolete-replacements))
            (doc-string (getf entry :doc-string)))
        (let ((doc-1line (when doc-string
                           (substitute #\Space #\Newline doc-string)))
              (merged-args (if arg-types
                               (typed-arglist arglist arg-types)
                               arglist)))
          (write-char #\( stream)
          (format stream "~:(~a~): " kind)
          (prin1 name stream)
          (write-char #\Space stream)
          (prin1 merged-args stream)
          (when return-types
            (write-string " => " stream)
            (prin1 return-types stream))
          (when replacements
            (write-string " :obsolete " stream)
            (prin1 replacements stream))
          (when doc-1line
            (write-string " " stream)
            (prin1 doc-1line stream))
          (write-char #\) stream)
          (terpri stream))))))
