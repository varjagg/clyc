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

;; (defun print-sbhl-direction-link (arg1 arg2)) -- commented declareFunction, no body

(defun empty-tv-link-p (tv tv-links)
  "[Cyc] Accessor: determines if the tv-link in TV-LINKS associated with TV is empty"
  (null (get-sbhl-link-nodes tv-links tv)))

(defun empty-tv-links-p (tv-links)
  "[Cyc] Accessor: determines if all truth value fields of TV-LINKS are NIL."
  (dohash (tv links tv-links)
    (declare (ignore tv))
    (when links
      (return-from empty-tv-links-p nil)))
  t)

(defun empty-mt-link-p (mt mt-links)
  "[Cyc] Accessor: takes MT and MT-LINKS and determines if all tv-link substructures are empty."
  (let ((tv-links (get-sbhl-tv-links mt-links mt)))
    (if tv-links
        (empty-tv-links-p tv-links)
        t)))

(defun empty-mt-links-p (mt-links)
  "[Cyc] Accessor: determines if the MT-LINKS structure has completely empty substructures"
  (dohash (mt tv-links mt-links)
    (declare (ignore mt))
    (unless (empty-tv-links-p tv-links)
      (return-from empty-mt-links-p nil)))
  t)

(defun empty-direction-link-p (direction d-link)
  "[Cyc] Accessor: takes direction-link D-LINK and determines if all substructures are empty."
  (let ((mt-links (get-sbhl-mt-links d-link direction (get-sbhl-module))))
    (if mt-links
        (empty-mt-links-p mt-links)
        t)))

(defun empty-graph-link-p (node module)
  "[Cyc] Accessor: takes NODE and determines emptiness of the fields of the direction link that NODE and that MODULE / *sbhl-module* specify."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((d-link (get-sbhl-graph-link node module)))
    (when d-link
      (dolist (direction (get-relevant-sbhl-directions module))
        (let ((mt-links (get-sbhl-mt-links d-link direction module)))
          (when (and mt-links (not (empty-mt-links-p mt-links)))
            (return-from empty-graph-link-p nil)))))
    t))

;; (defun valid-sbhl-graph-link-p (arg1 arg2)) -- commented declareFunction, no body
;; (defun valid-sbhl-module-p (arg1)) -- commented declareFunction, no body
;; (defun valid-sbhl-links-p (arg1)) -- commented declareFunction, no body
;; (defun valid-sbhl-p ()) -- commented declareFunction, no body
