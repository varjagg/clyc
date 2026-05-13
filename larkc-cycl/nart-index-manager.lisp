#|
  Copyright (c) 2019-2020 White Flame

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

;; TODO - very similar in form to constant-index-manager. there's also unrepresented-term-index-manager, nart-hl-formula-manager

(defglobal *nart-index-manager* :uninitialized
    "[Cyc] The KB object manager for nart indices.")

(deflexical *nart-index-lru-size-percentage* 20
    "[Cyc] Based on arete experiments, only 20% of all narts are touched during normal inference, so we'll make a conservative guess that every one of those touched the nart's index.")

(defun setup-nart-index-table (size exact?)
  (setf *nart-index-manager* (new-kb-object-manager "nart-index"
                                                    size
                                                    *nart-index-lru-size-percentage*
                                                    #'load-nart-index-from-cache
                                                    exact?)))

(defun* cached-nart-index-count () (:inline t)
  "[Cyc] Return the number of nart indices currently cached in memory."
  (cached-kb-object-count *nart-index-manager*))

(defun* lookup-nart-index (id) (:inline t)
  (lookup-kb-object-content *nart-index-manager* id))

(defun register-nart-index (id nart-index)
  "[Cyc] Note that ID will be used as the id for NART-INDEX."
  (register-kb-object-content *nart-index-manager* id nart-index))

(defun deregister-nart-index (id)
  (deregister-kb-object-content *nart-index-manager* id))

(defun nart-index (nart)
  "[Cyc] Return the indexing structure for NART."
  (let ((id (n-id nart)))
    (and id (lookup-nart-index id))))

(defun reset-nart-index (nart new-index)
  "[Cyc] Primitively change the assertion index for NART to NEW-INDEX."
  (register-nart-index (n-id nart) new-index)
  nart)

(defun swap-out-all-pristine-nart-indices ()
  (swap-out-all-pristine-kb-objects-int *nart-index-manager*))

(defun initialize-nart-index-hl-store-cache ()
  (initialize-kb-object-hl-store-cache *nart-index-manager*
                                       "nat-indices"
                                       "nat-indices-index"))
