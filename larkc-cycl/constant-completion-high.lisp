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


(defun valid-constant-name-char-p (char)
  "[Cyc] Return T iff CHAR is a character which is allowed in a valid constant name."
  (declare (character char))
  (or (alphanumericp char)
      (find char "-_:")))

(defun valid-constant-name-p (string)
  "[Cyc] Return T iff STRING is a valid name for a constant."
  (and (stringp string)
       (>= (length string) 2)
       (not (find-if #'invalid-constant-name-char-p string))))

(defun invalid-constant-name-char-p (char)
  "[Cyc] Return T iff CHAR is a character which is not allowed in a valid constant name."
  (not (valid-constant-name-char-p char)))

;; Active declareFunction in Java, but body stripped from LarKC.
;; Called by constant-handles:make-constant-shell (checkType) and
;; constants-interface:kb-create-constant (checkType), so must exist.
;; Reconstructed from orphan constants $kw17$UNNAMED and $sym18$STRINGP,
;; confirmed by Javadoc in cyc_kernel.java ("If NAME is anything other than
;; :unnamed") and constants_interface.java ("If NAME is :unnamed, returns a
;; constant with no name").
(defun constant-name-spec-p (object)
  "Return T iff OBJECT is a valid constant name specifier — a valid name string or :UNNAMED."
  (or (eq object :unnamed)
      (and (stringp object)
           (valid-constant-name-p object))))

(defparameter *require-case-insensitive-name-uniqueness* t
  "[Cyc] Do we require that constant names be case-insensitively unique?")

(defun constant-name-case-collisions (string)
  "[Cyc] Return a list of constants whose names differ from STRING only by case."
  (declare (type (satisfies valid-constant-name-p) string))
  (let ((uses (constant-complete string nil t)))
    (delete string uses :test #'equal :key #'constant-name)))

(defun constant-name-case-collision (string)
  "[Cyc] Return a constant whose name differs from STRING only by case."
  (declare (type (satisfies valid-constant-name-p) string))
  (first (constant-name-case-collisions string)))


(defun constant-complete-exact (string &optional (start 0) end)
  "[Cyc] Return a valid constant whose name exactly matches STRING. Optionally the START and END character positions can be specified, such that the STRING matches characters between the START and END range. If no constant exists, return NIL."
  (declare (string string)
           (fixnum start))
  (kb-constant-complete-exact string start end))

(defun constant-complete (prefix &optional case-sensitive? exact-length? (start 0) end)
  "[Cyc] Return all valid constants with PREFIX as a prefix of their name.
When CASE-SENSITIVE? is non-NIL, the comparison is done in a case-sensitive fashion.
When EXACT-LENGTH? is non-NIL, the prefix must be the entire string.
Optionally the START and END character positions can be specified, such that the PREFIX matches characters between the START and END range. If no constant exists, return NIL."
  (kb-constant-complete prefix case-sensitive? exact-length? start end))

(defun new-constant-completion-iterator (&optional (forward? t) (buffer-size 1))
  (kb-new-constant-completion-iterator forward? buffer-size))

(defun map-constants-in-completions (function)
  (let ((iterator (new-constant-completion-iterator)))
    (map-iterator function iterator)))


;;; Cyc API registrations


(register-obsolete-cyc-api-function 'valid-constant-name-char '(valid-constant-name-char-p) '(char)
    "Deprecated in favor of valid-constant-name-char-p
   Return T iff CHAR is a character which is allowed in a valid constant name."
    '((char characterp))
    '(booleanp))


(register-cyc-api-function 'valid-constant-name-char-p '(char)
    "Return T iff CHAR is a character which is allowed in a valid constant name."
    '((char characterp))
    '(booleanp))


(register-obsolete-cyc-api-function 'valid-constant-name '(valid-constant-name-p) '(string)
    "Deprecated in favor of valid-constant-name-p
   Return T iff STRING is a valid name for a constant."
    'nil
    '(booleanp))


(register-cyc-api-function 'valid-constant-name-p '(string)
    "Return T iff STRING is a valid name for a constant."
    'nil
    '(booleanp))


(register-cyc-api-function 'constant-name-available '(name)
    "Return T iff NAME is a valid constant name currently available for use."
    '((name stringp))
    '(booleanp))


(register-cyc-api-function 'uniquify-constant-name '(name)
    "Return a unique, currently unused constant name based on NAME, which must be a valid constant name."
    '((name valid-constant-name-p))
    '(stringp))


(register-cyc-api-function 'constant-name-case-collisions '(string)
    "Return a list of constants whose names differ from STRING only by case."
    '((string valid-constant-name-p))
    '(listp))


(register-cyc-api-function 'constant-name-case-collision '(string)
    "Return a constant whose name differs from STRING only by case."
    '((string valid-constant-name-p))
    '(constant-p))


(register-cyc-api-function 'constant-complete-exact '(string &optional (start ZERO_INTEGER) end)
    "Return a valid constant whose name exactly matches STRING.
Optionally the START and END character positions can be
specified, such that the STRING matches characters between the START and 
END range.  If no constant exists, return NIL."
    '((string stringp) (start fixnump))
    'nil)


(register-cyc-api-function 'constant-complete '(prefix &optional case-sensitive? exact-length? (start ZERO_INTEGER) end)
    "Return all valid constants with PREFIX as a prefix of their name
When CASE-SENSITIVE? is non-nil, the comparison is done in a case-sensitive fashion.
When EXACT-LENGTH? is non-nil, the prefix must be the entire string
Optionally the START and END character positions can be
specified, such that the PREFIX matches characters between the START and 
END range.  If no constant exists, return NIL."
    '((prefix stringp) (case-sensitive? booleanp) (exact-length? booleanp) (start fixnump))
    'nil)


(register-cyc-api-function 'constant-apropos '(substring &optional case-sensitive? (start ZERO_INTEGER) end)
    "Return all valid constants with SUBSTRING somewhere in their name
When CASE-SENSITIVE? is non-nil, the comparison is done in a case-sensitive fashion.
Optionally the START and END character positions can be
specified, such that the SUBSTRING matches characters between the START and 
END range.  If no constant exists, return NIL."
    '((substring stringp) (case-sensitive? booleanp) (start fixnump))
    'nil)


(register-cyc-api-function 'constant-postfix '(postfix &optional case-sensitive? (start ZERO_INTEGER) end)
    "Return all valid constants with POSTFIX as a postfix of their name
When CASE-SENSITIVE? is non-nil, the comparison is done in a case-sensitive fashion.
Optionally the START and END character positions can be
specified, such that the SUBSTRING matches characters between the START and 
END range.  If no constant exists, return NIL."
    '((postfix stringp) (case-sensitive? booleanp) (start fixnump))
    'nil)
