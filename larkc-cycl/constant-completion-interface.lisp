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


(defun kb-constant-complete-exact (string &optional (start 0) end)
  "[Cyc] Return a valid constant whose name exactly matches STRING.
Optionally the START and END character positions can be specified, such that the STRING matches the characters between the START and END range.
If no constant exists, return NIL."
  (if (hl-access-remote?)
      (missing-larkc 29536)
      (kb-constant-complete-exact-internal string start end)))

(defun kb-constant-complete (prefix &optional case-sensitive? exact-length? (start 0) end)
  "[Cyc] Return all valid constants with PREFIX as a prefix of their name.
When CASE-SENSITIVE? is non-NIL, the comparison is done in a case-sensitive fashion.
When EXACT-LENGTH? is non-NIL, the prefix must be the entire string.
Optionally the START and END character positions can be specified, such that the PREFIX matches characters between the START and END range.
If no constant exists, return NIL."
  (if (hl-access-remote?)
      (missing-larkc 29537)
      (kb-constant-complete-internal prefix case-sensitive? exact-length? start end)))

(defun kb-new-constant-completion-iterator (&optional (forward? t) (buffer-size 1))
  "[Cyc] Returns an iterator for the constants in the constant completion table."
  (new-hl-store-iterator (list 'kb-new-constant-completion-iterator-internal (quotify forward?))
                         buffer-size))


;;; Cyc API registrations


(register-cyc-api-function 'kb-constant-complete-exact '(string &optional (start ZERO_INTEGER) end)
    "Return a valid constant whose name exactly matches STRING.
   Optionally the START and END character positions can be
   specified, such that the STRING matches characters between the START and 
   END range.  If no constant exists, return NIL."
    '((string stringp) (start fixnump) (end (nil-or fixnump)))
    '((nil-or constant-p)))


(register-cyc-api-function 'kb-constant-complete '(prefix &optional case-sensitive? exact-length? (start ZERO_INTEGER) end)
    "Return all valid constants with PREFIX as a prefix of their name
   When CASE-SENSITIVE? is non-nil, the comparison is done in a case-sensitive fashion.
   When EXACT-LENGTH? is non-nil, the prefix must be the entire string
   Optionally the START and END character positions can be
   specified, such that the PREFIX matches characters between the START and 
   END range.  If no constant exists, return NIL."
    '((prefix stringp) (case-sensitive? booleanp) (exact-length? booleanp) (start fixnump) (end (nil-or fixnump)))
    '((list constant-p)))


(register-cyc-api-function 'kb-constant-apropos '(substring &optional case-sensitive? (start ZERO_INTEGER) end)
    "Return all valid constants with SUBSTRING somewhere in their name
   When CASE-SENSITIVE? is non-nil, the comparison is done in a case-sensitive fashion.
   Optionally the START and END character positions can be
   specified, such that the SUBSTRING matches characters between the START and 
   END range.  If no constant exists, return NIL."
    '((substring stringp) (case-sensitive? booleanp) (start fixnump) (end (nil-or fixnump)))
    '((list constant-p)))


(register-cyc-api-function 'kb-constant-postfix '(postfix &optional case-sensitive? (start ZERO_INTEGER) end)
    "Return all valid constants with POSTFIX as a postfix of their name
   When CASE-SENSITIVE? is non-nil, the comparison is done in a case-sensitive fashion.
   Optionally the START and END character positions can be
   specified, such that the SUBSTRING matches characters between the START and 
   END range.  If no constant exists, return NIL."
    '((postfix stringp) (case-sensitive? booleanp) (start fixnump) (end (nil-or fixnump)))
    '((list constant-p)))


(register-cyc-api-function 'kb-n-constants-before '(n string &optional case-sensitive? (start ZERO_INTEGER) end strict?)
    "Return the N constants with names before STRING.  When CASE-SENSITIVE? is non-nil,
   the comparison is done in a case-sensitive fashion.  Optionally the START and END
   character positions can be specified, such that STRING matches characters between
   the START and END range.  If STRICT? is non-nil, then only constants strictly
   before the string are returned."
    '((n non-negative-integer-p) (string stringp) (case-sensitive? booleanp) (start fixnump) (end (nil-or fixnump)))
    '((list constant-p)))


(register-cyc-api-function 'kb-n-constants-after '(n string &optional case-sensitive? (start ZERO_INTEGER) end strict?)
    "Return the N constants with names after STRING.  When CASE-SENSITIVE? is non-nil,
   the comparison is done in a case-sensitive fashion.  Optionally the START and END
   character positions can be specified, such that STRING matches characters between
   the START and END range.  If STRICT? is non-nil, then only constants strictly after
   the string are returned."
    '((n non-negative-integer-p) (string stringp) (case-sensitive? booleanp) (start fixnump) (end (nil-or fixnump)))
    '((list constant-p)))
