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


;; Reconstructed iteration macros from sbhl_macros.java Internal Constants.
;; Evidence: commented declareMacro entries + orphan $list* arglists + operator $sym* constants.
;; Arglists from: $list0 (do-sbhl-link-nodes), $list6 (do-sbhl-tv-links),
;;   $list8 (do-sbhl-mt-link), $list12 (do-sbhl-mt-links),
;;   $list13 (do-sbhl-direction-link), $list16 (do-sbhl-graph-link),
;;   $list55 (with-sbhl-graph-link), $list58 (with-relevant-sbhl-link-nodes),
;;   $list68 (with-relevant-sbhl-fort-link-nodes).
;; Expansion operators: GET-SBHL-LINK-NODES, DO-DICTIONARY (=dohash),
;;   GET-SBHL-TV-LINKS, GET-SBHL-MT-LINKS, GET-SBHL-GRAPH-LINK,
;;   DO-RELEVANT-SBHL-DIRECTIONS, RELEVANT-MT?, *SBHL-LINK-MT*,
;;   RELEVANT-SBHL-TV?, *SBHL-LINK-TV*, NAUT-TO-NART, SBHL-NODE-OBJECT-P,
;;   CNAT-P, PIF + error string.

(defmacro do-sbhl-link-nodes ((link-node-var tv tv-links &optional done-var) &body body)
  "[Cyc] Iterates LINK-NODE-VAR over the link nodes for TV in TV-LINKS."
  (declare (ignore done-var))
  (alexandria:with-gensyms (nodes)
    `(let ((,nodes (get-sbhl-link-nodes ,tv-links ,tv)))
       (when ,nodes
         (dolist (,link-node-var ,nodes)
           ,@body)))))

(defmacro do-sbhl-tv-links ((tv-var link-nodes-var tv-links &optional done-var) &body body)
  "[Cyc] Iterates TV-VAR and LINK-NODES-VAR over the truth-value/nodes pairs in TV-LINKS."
  (declare (ignore done-var))
  `(dohash (,tv-var ,link-nodes-var ,tv-links)
     ,@body))

(defmacro do-sbhl-mt-link ((tv-var link-nodes-var mt mt-links &optional done-var) &body body)
  "[Cyc] Gets the tv-links for MT in MT-LINKS, then iterates with do-sbhl-tv-links."
  (alexandria:with-gensyms (tvl)
    `(let ((,tvl (get-sbhl-tv-links ,mt-links ,mt)))
       (when ,tvl
         (do-sbhl-tv-links (,tv-var ,link-nodes-var ,tvl ,done-var)
           ,@body)))))

(defmacro do-sbhl-mt-links ((mt-var tv-links-var mt-links &optional done-var) &body body)
  "[Cyc] Iterates MT-VAR and TV-LINKS-VAR over the mt/tv-links pairs in MT-LINKS."
  (declare (ignore done-var))
  `(dohash (,mt-var ,tv-links-var ,mt-links)
     ,@body))

(defmacro do-sbhl-direction-link ((mt-var tv-links-var direction d-link module &optional done-var) &body body)
  "[Cyc] Gets mt-links from DIRECTION of D-LINK for MODULE, then iterates with do-sbhl-mt-links."
  (alexandria:with-gensyms (mtl)
    `(let ((,mtl (get-sbhl-mt-links ,d-link ,direction ,module)))
       (when ,mtl
         (do-sbhl-mt-links (,mt-var ,tv-links-var ,mtl ,done-var)
           ,@body)))))

(defmacro do-sbhl-graph-link ((direction-var mt-links-var node module &optional done-var) &body body)
  "[Cyc] Gets the graph link for NODE in MODULE, then iterates relevant directions."
  (declare (ignore done-var))
  (alexandria:with-gensyms (dl)
    `(let ((,dl (get-sbhl-graph-link ,node ,module)))
       (when ,dl
         (dolist (,direction-var (get-relevant-sbhl-directions ,module))
           (let ((,mt-links-var (get-sbhl-mt-links ,dl ,direction-var ,module)))
             (when ,mt-links-var
               ,@body)))))))

(defmacro with-sbhl-graph-link ((d-link-var node module) &body body)
  "[Cyc] Binds D-LINK-VAR to the graph link for NODE in MODULE. Errors if nil."
  `(let ((,d-link-var (get-sbhl-graph-link ,node ,module)))
     (if ,d-link-var
         (progn ,@body)
         (sbhl-error 5 "attempting to bind direction link variable, to NIL. macro body not executed."))))

(defmacro with-relevant-sbhl-fort-link-nodes ((link-nodes-var node direction module &optional done-var) &body body)
  "[Cyc] Iterates LINK-NODES-VAR over relevant link nodes for fort NODE in DIRECTION of MODULE,
binding *sbhl-link-mt* and *sbhl-link-tv* for each relevant mt/tv combination."
  (alexandria:with-gensyms (dl mt tvl tv)
    `(with-sbhl-graph-link (,dl ,node ,module)
       (do-sbhl-direction-link (,mt ,tvl ,direction ,dl ,module ,done-var)
         (when (relevant-mt? ,mt)
           (let ((*sbhl-link-mt* ,mt))
             (do-sbhl-tv-links (,tv ,link-nodes-var ,tvl ,done-var)
               (when (relevant-sbhl-tv? ,tv)
                 (let ((*sbhl-link-tv* ,tv))
                   ,@body)))))))))

(defmacro with-relevant-sbhl-link-nodes ((link-nodes-var start-node direction module &optional done-var) &body body)
  "[Cyc] Iterates LINK-NODES-VAR over relevant link nodes for START-NODE, dispatching
between fort nodes (via with-relevant-sbhl-fort-link-nodes) and NAUTs
(via do-relevant-sbhl-naut-generated-links)."
  (alexandria:with-gensyms (nd)
    `(let ((,nd (naut-to-nart ,start-node)))
       (cond
         ((sbhl-node-object-p ,nd)
          (with-relevant-sbhl-fort-link-nodes (,link-nodes-var ,nd ,direction ,module ,done-var)
            ,@body))
         ((cnat-p ,nd)
          ;; TODO - do-relevant-sbhl-naut-generated-links expansion needs sbhl-module-relevant-naut-link-generators (missing-larkc 2701)
          (let ((generating-fns (missing-larkc 2701)))
            (dolist (generating-fn generating-fns)
              (let ((*sbhl-link-generator* generating-fn))
                (let ((,link-nodes-var (funcall generating-fn ,nd)))
                  ,@body)))))))))

;; Reconstructed from sbhl_macros.java. The NAUT branch of with-relevant-sbhl-link-nodes.
;; Iterates generating functions from the module and funcalls them to produce link nodes.
;; get-sbhl-module-relevant-naut-link-generators is missing-larkc 2701.
(defmacro do-relevant-sbhl-naut-generated-links ((link-nodes-var node direction module &optional done-var) &body body)
  "[Cyc] Iterates LINK-NODES-VAR over NAUT-generated link nodes for NODE in DIRECTION of MODULE."
  (declare (ignore done-var))
  (alexandria:with-gensyms (generating-fn)
    `(dolist (,generating-fn (missing-larkc 2701))
       (let ((*sbhl-link-generator* ,generating-fn))
         (let ((,link-nodes-var (funcall ,generating-fn ,node)))
           ,@body)))))

(defun do-sbhl-non-fort-links? (node module)
  (and (eq module (get-sbhl-module #$isa))
       (collection-supports-non-fort-instances? node)))

(defun* collection-supports-non-fort-instances? (col) (:inline t)
  t)

(defun get-sbhl-accessible-modules (module)
  "[Cyc] Returns the list of SBHL modules allowed by MODULE for following links."
  (if-let ((preds (get-sbhl-accessible-link-preds module)))
    (mapcar #'get-sbhl-module preds)
    (list module)))


;;; Cyc API registrations

(register-cyc-api-macro 'do-all-instances '((instance-var term &optional mt tv done-var search-type) &body body)
    "Iterator. @see do-all-simple-backward-true-links.")



(register-cyc-api-macro 'do-all-fort-instances '((instance-var term &optional mt tv done-var search-type) &body body)
    "Like @xref do-all-instances except only iterates over forts.  Deprecated.")



(register-cyc-api-macro 'do-all-quoted-instances '((instance-var term &optional mt tv done-var search-type) &body body)
    "Iterator. @see do-all-simple-backward-true-links.")
