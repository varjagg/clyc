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


;; DEPRECATED: The SubL dictionary type is elided in preference to standard CL
;; hash tables. Only non-obvious functionality is retained here.

#|
(defun* dictionary-p (object) (:inline t)
  "[Cyc] Return T iff OBJECT is a dictionary."
  (hash-table-p object))

(defun* new-dictionary (&optional (test #'eql) (size 0)) (:inline t)
  "[Cyc] Allocate a new dictionary."
  (make-hash-table :test test :size size))

(defmacro do-dictionary ((key value dictionary &optional done) &body body)
  "Iterate over the key-value pairs of DICTIONARY."
  (let ((dict-var (gensym "DICT")))
    (if done
        `(let ((,dict-var ,dictionary))
           (block nil
             (maphash (lambda (,key ,value)
                        (when ,done (return))
                        ,@body)
                      ,dict-var)))
        `(maphash (lambda (,key ,value)
                    ,@body)
                  ,dictionary))))

(defmacro do-dictionary-progress ((key value dictionary &key done (progress-note "Mapping dictionary...")) &body body)
  "Iterate over DICTIONARY with progress reporting."
  (let ((so-far (gensym "SO-FAR"))
        (total (gensym "TOTAL")))
    `(let ((,so-far 0)
           (,total (hash-table-count ,dictionary)))
       (noting-percent-progress (,progress-note)
         (do-dictionary (,key ,value ,dictionary ,done)
           ,@body
           (incf ,so-far)
           (note-percent-progress ,so-far ,total))))))
|#

;;; CFASL deserialization

(declare-cfasl-opcode *cfasl-opcode-dictionary* 61 'cfasl-input-dictionary)
(defconstant *cfasl-opcode-legacy-dictionary* 64)
;; (defun cfasl-input-legacy-dictionary (stream) ...) -- active declareFunction, no body

(defun cfasl-input-dictionary (stream)
  "[Cyc] Read a dictionary from STREAM using the CFASL protocol."
  (let* ((test (cfasl-input stream))
         (size (cfasl-input stream))
         (dictionary (make-hash-table :test test :size size)))
    (dotimes (i size)
      (let ((key (cfasl-input stream))
            (value (cfasl-input stream)))
        (setf (gethash key dictionary) value)))
    dictionary))

