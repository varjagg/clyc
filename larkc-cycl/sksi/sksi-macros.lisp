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

;; Reconstructed from Internal Constants:
;; $sym0$CLET, $list1 = ((*MEMOIZE-SKSI-REFORMULATE?* T))
(defmacro with-sksi-reformulation-caching (&body body)
  `(clet ((*memoize-sksi-reformulate?* t))
     ,@body))

;; Reconstructed from Internal Constants:
;; $sym0$CLET, $list2 = ((*MEMOIZE-SKSI-REFORMULATE?* NIL))
(defmacro without-sksi-reformulation-caching (&body body)
  `(clet ((*memoize-sksi-reformulate?* nil))
     ,@body))

;; TODO - Reconstruction from Internal Constants incomplete.
;; Evidence: $sym0$CLET and $sym3$PROGN are available, but no specific
;; binding list constant was compiled in for this macro. Likely binds
;; the SQL connection/statement caches and pool lock (from the file's
;; defparameter variables *sksi-sql-connection-cache*,
;; *sksi-sql-statement-cache*, *sksi-sql-statement-pool-lock*) and
;; wraps body with resource acquisition/release, but arglist and
;; exact expansion are unknown. No call sites exist in the rest of
;; the larkc-java codebase to provide ground truth.
(defmacro with-sksi-sql-connection-resourcing (&body body)
  `(progn ,@body))

(defparameter *sksi-sql-connection-cache* nil)

(defparameter *sksi-sql-statement-cache* nil)

(defparameter *sksi-sql-statement-pool-lock* nil)
