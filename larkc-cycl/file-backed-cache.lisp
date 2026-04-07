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

(deflexical *fbc-reset-lock* (bt:make-lock "fbc-reset-lock")
  "[Cyc] Lock used to ensure resets of file backed caches are done atomically.")

(deflexical *file-backed-cache-base-path* "data/caches/"
  "[Cyc] Where the cache files live.")
;; NOTE: Java uses red_infrastructure_macros.red_def_helper for config lookup,
;; but red-infrastructure-macros is ELIDED. Using the default value directly.

(defstruct (file-backed-cache (:conc-name "FBC-"))
  file-hash-table-cache
  local-cache
  file-hash-table-path
  should-preload-cache
  is-fort-cache
  fht-cache-percentage
  test
  mode
  is-busy)

(defconstant *dtp-file-backed-cache* 'file-backed-cache)

(defun file-backed-cache-print-function-trampoline (object stream)
  "[Cyc] Print function trampoline for file-backed-cache."
  (missing-larkc 7781))

;; file-backed-cache-p - commented, no body (1 0)
;; fbc-file-hash-table-cache - commented, no body (1 0)
;; fbc-local-cache - commented, no body (1 0)
;; fbc-file-hash-table-path - commented, no body (1 0)
;; fbc-should-preload-cache - commented, no body (1 0)
;; fbc-is-fort-cache - commented, no body (1 0)
;; fbc-fht-cache-percentage - commented, no body (1 0)
;; fbc-test - commented, no body (1 0)
;; fbc-mode - commented, no body (1 0)
;; fbc-is-busy - commented, no body (1 0)
;; _csetf-fbc-file-hash-table-cache - commented, no body (2 0)
;; _csetf-fbc-local-cache - commented, no body (2 0)
;; _csetf-fbc-file-hash-table-path - commented, no body (2 0)
;; _csetf-fbc-should-preload-cache - commented, no body (2 0)
;; _csetf-fbc-is-fort-cache - commented, no body (2 0)
;; _csetf-fbc-fht-cache-percentage - commented, no body (2 0)
;; _csetf-fbc-test - commented, no body (2 0)
;; _csetf-fbc-mode - commented, no body (2 0)
;; _csetf-fbc-is-busy - commented, no body (2 0)
;; make-file-backed-cache - commented, no body (0 1)
;; file-backed-cache-create - commented, no body (1 5)
;; print-fbc - commented, no body (3 0)
;; fbc-initialize - commented, no body (1 0)
;; fbc-initialize-internal - commented, no body (2 0)
;; file-backed-cache-reconnect - commented, no body (1 1)
;; file-backed-cache-reset - commented, no body (1 1)
;; file-backed-cache-finalize - commented, no body (1 0)
;; preload-entire-file-hash-table - commented, no body (1 0)
;; file-backed-cache-lookup - commented, no body (2 2)
;; file-backed-cache-enter - commented, no body (3 0)
;; file-backed-cache-file-hash-table-path - commented, no body (1 0)
;; file-backed-cache-local-cache-count - commented, no body (1 0)
;; replicate-file-backed-cache - commented, no body (2 4)
;; replicate-file-backed-cache-int - commented, no body (6 0)
