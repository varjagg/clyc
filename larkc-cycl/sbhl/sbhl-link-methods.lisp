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

(defun sbhl-access-links (node direction)
  "[Cyc] Accessor: takes NODE and DIRECTION, determines sbhl-graph from *sbhl-module*,
returns mt-links dictionary from DIRECTION field of direction-link."
  (let ((link (get-sbhl-graph-link node (get-sbhl-module))))
    (get-sbhl-mt-links link direction (get-sbhl-module))))

;; (defun sbhl-predicate-links (node)) -- commented declareFunction, no body
;; (defun sbhl-inverse-links (node)) -- commented declareFunction, no body
;; (defun sbhl-undirected-links (node)) -- commented declareFunction, no body

(defun get-sbhl-graph-link-nodes (node direction mt tv)
  "[Cyc] Accessor: takes NODE, DIRECTION, MT, and TV. Returns list of nodes for
TV field of tv-link specified by MT and DIRECTION. Requires *sbhl-module* to be defined."
  (let ((mt-links (sbhl-access-links node direction)))
    (when mt-links
      (let ((tv-links (get-sbhl-tv-links mt-links mt)))
        (when tv-links
          (get-sbhl-link-nodes tv-links tv))))))

(defun get-sbhl-forward-link-nodes (node mt tv)
  "[Cyc] Accessor: takes NODE, MT, and TV. Returns list of nodes for TV field of
tv-link specified by MT, in forward direction. Requires *sbhl-module* to be defined."
  (get-sbhl-graph-link-nodes node (get-sbhl-module-forward-direction (get-sbhl-module)) mt tv))

(defun get-sbhl-backward-link-nodes (node mt tv)
  "[Cyc] Accessor: takes NODE, MT, and TV. Returns list of nodes for TV field of
tv-link specified by MT, in backward direction. Requires *sbhl-module* to be defined."
  (get-sbhl-graph-link-nodes node (get-sbhl-module-backward-direction (get-sbhl-module)) mt tv))

;; (defun member-of-sbhl-link-nodes? (arg1 arg2 arg3 arg4 arg5)) -- commented declareFunction, no body
;; (defun no-accessible-sbhl-nodes-p (node)) -- commented declareFunction, no body
;; (defun sbhl-link-mts (arg1 arg2)) -- commented declareFunction, no body
;; (defun sbhl-forward-mts (arg1 arg2)) -- commented declareFunction, no body
;; (defun sbhl-backward-mts (arg1 arg2)) -- commented declareFunction, no body
;; (defun sbhl-link-nodes-by-iteration (arg1 arg2)) -- commented declareFunction, no body

(defun sbhl-link-nodes (module node direction &optional mt tv with-cutoff-support?)
  "[Cyc] The asserted link nodes accessible by NODE via one sbhl-link-pred link,
as specified by MODULE, with relevant truth value."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil))
    (with-sbhl-module (module)
      (possibly-with-sbhl-mt-relevance (mt)
        (possibly-with-sbhl-tv (tv)
          (if with-cutoff-support?
              ;; missing-larkc 1859 — predicate-true-links-by-iteration
              (setf result (missing-larkc 1859))
              (with-relevant-sbhl-link-nodes (link-nodes node direction module)
                (setf result (nconc (copy-list link-nodes) result)))))))
    (fast-delete-duplicates result)))

;; (defun sbhl-link-nodes-p (arg1 arg2 arg3 &optional arg4 arg5)) -- commented declareFunction, no body

(defun sbhl-forward-true-link-nodes (module node &optional mt tv with-cutoff-support?)
  (declare (type (satisfies sbhl-module-p) module))
  (let ((direction (get-sbhl-module-forward-direction module)))
    (cond
      ((sbhl-true-tv-p tv)
       (sbhl-link-nodes module node direction mt tv with-cutoff-support?))
      ((null tv)
       (sbhl-link-nodes module node direction mt #$True-JustificationTruth with-cutoff-support?))
      (t
       (sbhl-error 1 "tv, ~a, does not satisfy sbhl-true-tv-p" tv)
       (sbhl-error 1 "sbhl-link-nodes never called.")
       nil))))

;; (defun sbhl-forward-false-link-nodes (module node &optional mt tv with-cutoff-support?)) -- commented declareFunction, no body

(defun sbhl-backward-true-link-nodes (module node &optional mt tv with-cutoff-support?)
  (declare (type (satisfies sbhl-module-p) module))
  (let ((direction (get-sbhl-module-backward-direction module)))
    (cond
      ((sbhl-true-tv-p tv)
       (sbhl-link-nodes module node direction mt tv with-cutoff-support?))
      ((null tv)
       (sbhl-link-nodes module node direction mt #$True-JustificationTruth with-cutoff-support?))
      (t
       (sbhl-error 1 "tv, ~a, does not satisfy sbhl-true-tv-p" tv)
       (sbhl-error 1 "sbhl-link-nodes never called.")
       nil))))

;; (defun sbhl-backward-true-link-nodes-p (module node &optional mt tv)) -- commented declareFunction, no body
;; (defun sbhl-backward-false-link-nodes (module node &optional mt tv with-cutoff-support?)) -- commented declareFunction, no body

(defun sbhl-mt-matching-link-nodes (module node mt)
  "[Cyc] Assumes TRUE tv, and forward direction, and returns the link-nodes of NODE
in MODULE which match MT"
  (declare (type (satisfies sbhl-module-p) module))
  (let ((result nil))
    (with-sbhl-module (module)
      (do-sbhl-graph-link (direction mt-links node module)
        (when (sbhl-forward-directed-direction-p direction)
          (do-sbhl-mt-link (tv link-nodes mt mt-links)
            (when (sbhl-true-tv-p tv)
              (dolist (link-node link-nodes)
                (push link-node result)))))))
    (fast-delete-duplicates result)))

;; (defun sbhl-siblings-forward (arg1 arg2 &optional arg3 arg4)) -- commented declareFunction, no body
;; (defun sbhl-siblings-backward (arg1 arg2 &optional arg3 arg4)) -- commented declareFunction, no body

(defun create-new-sbhl-link (direction mt tv node &optional module)
  "[Cyc] Returns a new sbhl direction link created from scratch from args."
  (create-sbhl-direction-link direction
                              (create-sbhl-mt-links mt (create-sbhl-tv-links tv node))
                              module))

(defun create-and-store-sbhl-link (arg1 arg2 direction mt tv module)
  "[Cyc] Stores a new link in the graph corresponding to MODULE using args to initialize the link"
  (set-sbhl-graph-link arg1 (create-new-sbhl-link direction mt tv arg2 module) module)
  nil)

(defun add-to-sbhl-link (old-link mt direction tv node)
  "[Cyc] Workhorse of link creation. Checks OLD-LINK and creates the necessary link
substructures, returns the new direction link"
  (let* ((link old-link)
         (mt-links (get-sbhl-mt-links link direction (get-sbhl-module))))
    (if mt-links
        (let ((tv-links (get-sbhl-tv-links mt-links mt)))
          (if tv-links
              (push-onto-sbhl-tv-links tv-links tv node)
              (set-sbhl-mt-links mt-links mt (create-sbhl-tv-links tv node))))
        (set-sbhl-direction-link link direction
                                 (create-sbhl-mt-links mt (create-sbhl-tv-links tv node))
                                 (get-sbhl-module)))
    link))

(defun store-in-sbhl-graph (arg1 arg2 mt tv)
  "[Cyc] Calculates forward and backward links relevant to GAF specified by the arguments.
Store the link, creating proper substructures through add-to-sbhl-link,
create-and-store-sbhl-link. Will not add redundant links."
  (cond
    ((and (sbhl-node-object-p arg1)
          (sbhl-node-object-p arg2))
     (unless (eq tv :unknown)
       (let ((module (get-sbhl-module)))
         (unless (and (sbhl-reflexive-module-p module)
                      (equal arg1 arg2))
           (let* ((module-index-arg (get-sbhl-index-arg module))
                  (index-arg (if (eql module-index-arg 1) arg1 arg2))
                  (gather-arg (if (eql module-index-arg 1) arg2 arg1))
                  (forward-direction (get-sbhl-module-forward-direction module))
                  (backward-direction (get-sbhl-module-backward-direction module))
                  (forward-link (get-sbhl-graph-link index-arg module)))
             (with-rw-lock-write-lock (*sbhl-rw-lock*)
               (if forward-link
                   (let ((forward-link-nodes (get-sbhl-forward-link-nodes index-arg mt tv)))
                     (unless (member-eq? gather-arg forward-link-nodes)
                       (add-to-sbhl-link forward-link mt forward-direction tv gather-arg)
                       (touch-sbhl-graph-link index-arg forward-link module)))
                   (create-and-store-sbhl-link index-arg gather-arg forward-direction mt tv module))
               (let ((backward-link (get-sbhl-graph-link gather-arg module)))
                 (if backward-link
                     (let ((backward-link-nodes (get-sbhl-backward-link-nodes gather-arg mt tv)))
                       (unless (member-eq? index-arg backward-link-nodes)
                         (add-to-sbhl-link backward-link mt backward-direction tv index-arg)
                         (touch-sbhl-graph-link gather-arg backward-link module)))
                     (create-and-store-sbhl-link gather-arg index-arg backward-direction mt tv module)))))))))
    ((isa-to-naut-conditions? arg1 arg2)
     (with-rw-lock-write-lock (*sbhl-rw-lock*)
       ;; missing-larkc 1914 — store-isa-arg2-naut
       (missing-larkc 1914))))
  nil)

;; (defun make-all-sbhl-links ()) -- commented declareFunction, no body

(defun assertion-sbhl-tv (assertion)
  (let ((truth (assertion-truth assertion))
        (strength (assertion-strength assertion)))
    (truth-strength-to-sbhl-tv truth strength)))

;; (defun sbhl-recompute-links (arg1 &optional arg2 arg3)) -- commented declareFunction, no body
;; (defun sbhl-recompute-graph-links (arg1)) -- commented declareFunction, no body
;; (defun sbhl-recompute-links-of-node (node)) -- commented declareFunction, no body
;; (defun sbhl-recompute-links-of-nodes (nodes)) -- commented declareFunction, no body
;; (defun reset-sbhl-links (arg1)) -- commented declareFunction, no body

(defun add-sbhl-link (arg1 arg2 mt tv)
  "[Cyc] After adding support. Adds necessary link structure and data to store
gaf assertion specified by the arguments. Requires (get-sbhl-module) to be bound."
  (store-in-sbhl-graph arg1 arg2 mt tv)
  (unless (or (eq tv :unknown)
              (and (sbhl-reflexive-module-p (get-sbhl-module))
                   (equal arg1 arg2)))
    (when (>= *sbhl-trace-level* 5)
      (missing-larkc 2246))
    (when (>= *sbhl-test-level* 5)
      (let* ((module (get-sbhl-module))
             (module-index-arg (get-sbhl-index-arg module))
             (index-arg (if (eql module-index-arg 1) arg1 arg2))
             (gather-arg (if (eql module-index-arg 1) arg2 arg1)))
        (unless (member? gather-arg (get-sbhl-graph-link-nodes index-arg (get-sbhl-module-forward-direction module) mt tv))
          (sbhl-error 3 "Link node, ~a, not present in forward links after performing (store-in-sbhl-graph ~a ~a ~a ~a). ~%"
                      gather-arg arg1 arg2 mt tv))
        (unless (member? index-arg (get-sbhl-graph-link-nodes gather-arg (get-sbhl-module-backward-direction module) mt tv))
          (sbhl-error 3 "Link node, ~a, not present in backward links after performing (store-in-sbhl-graph ~a ~a ~a ~a). ~%"
                      index-arg arg1 arg2 mt tv)))))
  nil)

(defun sbhl-after-adding (source assertion module)
  "[Cyc] More indirection on top of after adding procedure. Binds the sbhl pred data
corresponding to MODULE."
  (declare (type (satisfies sbhl-module-p) module))
  (let ((*added-source* source)
        (*added-assertion* assertion))
    (let ((tv (assertion-sbhl-tv assertion))
          (mt (assertion-mt assertion))
          (arg1 (gaf-arg assertion 1))
          (arg2 (gaf-arg assertion 2)))
      (with-sbhl-module (module)
        (add-sbhl-link arg1 arg2 mt tv))))
  nil)

;; (defun set-sbhl-links (arg1 arg2 &optional arg3)) -- commented declareFunction, no body
;; (defun remove-sbhl-link-node (arg1 arg2 arg3 arg4 arg5 &optional arg6)) -- commented declareFunction, no body
;; (defun remove-sbhl-forward-and-backward-link-node (arg1 arg2 arg3 arg4 &optional arg5)) -- commented declareFunction, no body

(defun remove-sbhl-link (arg1 arg2 mt tv)
  (let* ((module (get-sbhl-module))
         (forward-direction (get-sbhl-module-forward-direction module))
         (backward-direction (get-sbhl-module-backward-direction module))
         (arg1-graph-link (get-sbhl-graph-link arg1 module))
         (arg2-graph-link (get-sbhl-graph-link arg2 module))
         (arg1-mt-links (when arg1-graph-link (get-sbhl-mt-links arg1-graph-link forward-direction module)))
         (arg2-mt-links (when arg2-graph-link (get-sbhl-mt-links arg2-graph-link backward-direction module)))
         (arg1-tv-links (when arg1-mt-links (get-sbhl-tv-links arg1-mt-links mt)))
         (arg2-tv-links (when arg2-mt-links (get-sbhl-tv-links arg2-mt-links mt))))
    ;; Remove arg2 from arg1's forward links
    (when (member-of-tv-links? arg2 tv arg1-tv-links)
      (remove-sbhl-tv-link-node arg1-tv-links tv arg2)
      (when (empty-tv-link-p tv arg1-tv-links)
        (remove-sbhl-tv-link arg1-tv-links tv))
      (when (empty-mt-link-p mt arg1-mt-links)
        (remove-sbhl-mt-link arg1-mt-links mt))
      (when (empty-direction-link-p forward-direction arg1-graph-link)
        (remove-sbhl-direction-link arg1-graph-link forward-direction module))
      (if (empty-graph-link-p arg1 module)
          (remove-sbhl-graph-link arg1 module)
          (touch-sbhl-graph-link arg1 arg1-graph-link module)))
    ;; Remove arg1 from arg2's backward links
    (when (member-of-tv-links? arg1 tv arg2-tv-links)
      (remove-sbhl-tv-link-node arg2-tv-links tv arg1)
      (when (empty-tv-link-p tv arg2-tv-links)
        (remove-sbhl-tv-link arg2-tv-links tv))
      (when (empty-mt-link-p mt arg2-mt-links)
        (remove-sbhl-mt-link arg2-mt-links mt))
      (when (empty-direction-link-p backward-direction arg2-graph-link)
        (remove-sbhl-direction-link arg2-graph-link backward-direction module))
      (if (empty-graph-link-p arg2 module)
          (remove-sbhl-graph-link arg2 module)
          (touch-sbhl-graph-link arg2 arg2-graph-link module))))
  nil)

(defun sbhl-after-removing (source assertion module)
  (declare (type (satisfies sbhl-module-p) module))
  (declare (ignore source))
  (unless (assertion-still-there? assertion (assertion-truth assertion))
    (let ((tv (assertion-sbhl-tv assertion))
          (mt (assertion-mt assertion))
          (arg1 (gaf-arg assertion 1))
          (arg2 (gaf-arg assertion 2)))
      (with-sbhl-module (module)
        (if (isa-to-naut-conditions? arg1 arg2)
            ;; missing-larkc 1807 — remove-isa-arg2-naut
            (missing-larkc 1807)
            (remove-sbhl-link arg1 arg2 mt tv)))))
  nil)

(defun possibly-update-sbhl-links-tv (assertion old-tv)
  (when (gaf-assertion? assertion)
    (let ((new-tv (assertion-sbhl-tv assertion))
          (old-tv (support-tv-to-sbhl-tv old-tv)))
      (unless (eq new-tv old-tv)
        (let ((pred (gaf-predicate assertion)))
          (when (sbhl-predicate-p pred)
            (sbhl-after-tv-modification assertion old-tv (get-sbhl-module pred)))))))
  nil)

(defun sbhl-after-tv-modification (assertion old-tv module)
  (let ((tv (assertion-sbhl-tv assertion))
        (mt (assertion-mt assertion))
        (arg1 (gaf-arg assertion 1))
        (arg2 (gaf-arg assertion 2)))
    (with-sbhl-module (module)
      (if (isa-to-naut-conditions? arg1 arg2)
          ;; missing-larkc 1808 — remove-quoted-isa-arg2-naut
          (missing-larkc 1808)
          (remove-sbhl-link arg1 arg2 mt old-tv))
      (add-sbhl-link arg1 arg2 mt tv)))
  nil)

;; *isa-arg2-naut-table*
(defglobal *isa-arg2-naut-table* nil
  "[Cyc] Store for isa links that have a NAUT in the arg2 position.")

(defun initialize-isa-arg2-naut-table ()
  "[Cyc] Initializes *isa-arg2-naut-table*."
  (setf *isa-arg2-naut-table* (make-hash-table :size 200))
  nil)

;; (defun clear-isa-arg2-naut-table ()) -- commented declareFunction, no body

(defun isa-stored-naut-arg2-p (v-term)
  "[Cyc] Whether TERM has any direct isas which are NAUTs."
  (and (hash-table-p *isa-arg2-naut-table*)
       (and (gethash v-term *isa-arg2-naut-table*) t)))

;; (defun store-isa-arg2-naut (arg1 arg2 arg3 arg4)) -- commented declareFunction, no body
;; (defun remove-isa-arg2-naut (arg1 arg2 arg3 arg4)) -- commented declareFunction, no body

(defun isa-to-naut-conditions? (arg1 arg2)
  "[Cyc] Whether looking for (isa ARG1 ARG2) in the NAUT table is applicable."
  (and (eq (get-sbhl-link-pred (get-sbhl-module)) #$isa)
       (sbhl-node-object-p arg1)
       (possibly-naut-p arg2)))

;; (defun isas-from-naut-arg2 (arg1 &optional arg2 arg3)) -- commented declareFunction, no body
;; (defun union-isas-from-naut-arg2 (arg1 &optional arg2 arg3)) -- commented declareFunction, no body

;; TODO - reconstruct do-isas-from-naut-arg2 macro. No expansion sites visible to verify against.
;; Internal Constants evidence from sbhl_link_methods.java:
;; Arglist: $list36 = ((ISA-VAR TERM &OPTIONAL MT TV) &BODY BODY)
;; Destructuring: $list35 = (NAUT ISA-MT ISA-TV)
;; Operators: $list43 ((GET-SBHL-MODULE #$genls)), $sym44 POSSIBLY-WITH-SBHL-MT-RELEVANCE,
;;   $sym45 POSSIBLY-WITH-SBHL-TRUE-TV, $sym46 WITH-SBHL-MODULE, $sym47 CDOLIST,
;;   $sym48 GETHASH, $list49 (*ISA-ARG2-NAUT-TABLE*), $sym50 CDESTRUCTURING-BIND,
;;   $sym51 PWHEN, $sym52 CAND, $sym53 RELEVANT-MT?, $sym54 RELEVANT-SBHL-TV?,
;;   $sym55 DO-RELEVANT-SBHL-NAUT-GENERATED-LINKS, $list56 (GET-SBHL-FORWARD-DIRECTED-DIRECTION)
;; Gensym vars: $sym37 MODULE, $sym38 ISA-TUPLE, $sym39 NAUT, $sym40 ISA-MT, $sym41 ISA-TV

;; *quoted-isa-arg2-naut-table*
(defglobal *quoted-isa-arg2-naut-table* nil
  "[Cyc] Store for quotedIsa links that have a NAUT in the arg2 position.")

(defun initialize-quoted-isa-arg2-naut-table ()
  "[Cyc] Initializes *quoted-isa-arg2-naut-table*."
  (setf *quoted-isa-arg2-naut-table* (make-hash-table :size 200))
  nil)

;; (defun clear-quoted-isa-arg2-naut-table ()) -- commented declareFunction, no body

(defun quoted-isa-stored-naut-arg2-p (v-term)
  "[Cyc] Whether TERM has any direct quoted-isas which are NAUTs."
  (and (hash-table-p *quoted-isa-arg2-naut-table*)
       (and (gethash v-term *quoted-isa-arg2-naut-table*) t)))

;; (defun store-quoted-isa-arg2-naut (arg1 arg2 arg3 arg4)) -- commented declareFunction, no body
;; (defun remove-quoted-isa-arg2-naut (arg1 arg2 arg3 arg4)) -- commented declareFunction, no body
;; (defun quoted-isa-to-naut-conditions? (arg1 arg2)) -- commented declareFunction, no body
;; (defun quoted-isas-from-naut-arg2 (arg1 &optional arg2 arg3)) -- commented declareFunction, no body
;; (defun union-quoted-isas-from-naut-arg2 (arg1 &optional arg2 arg3)) -- commented declareFunction, no body
;; TODO - reconstruct do-quoted-isas-from-naut-arg2 macro. No expansion sites visible to verify against.
;; Internal Constants evidence from sbhl_link_methods.java:
;; Arglist: $list60 = ((QUOTED-ISA-VAR TERM &OPTIONAL MT TV) &BODY BODY)
;; Destructuring: $list59 = (NAUT QUOTED-ISA-MT QUOTED-ISA-TV)
;; Same pattern as do-isas-from-naut-arg2 but with *quoted-isa-arg2-naut-table*
;; Gensym vars: $sym61 MODULE, $sym62 QUOTED-ISA-TUPLE, $sym63 NAUT,
;;   $sym64 QUOTED-ISA-MT, $sym65 QUOTED-ISA-TV
;; Uses $list66 (*QUOTED-ISA-ARG2-NAUT-TABLE*)

;; Reconstructed from sbhl_link_methods.java Internal Constants evidence.
;; Arglist: $list69 = ((COL-VAR INS &OPTIONAL MT TV DONE-VAR) &BODY BODY)
;; Destructuring: $list85 = (COL table-mt table-tv) [uninternedSymbols for table-mt, table-tv]
;; Operators: $sym73 POSSIBLY-WITH-INFERENCE-MT-RELEVANCE, $sym74 POSSIBLY-WITH-SBHL-TV,
;;   $sym75 CSOME, $sym76 GETHASH-WITHOUT-VALUES, $list77 ((NON-FORT-ISA-TABLE)),
;;   CDESTRUCTURING-BIND, RELEVANT-MT?, RELEVANT-SBHL-TV?
;; Gensym vars: $sym70 ISA-TUPLE, $sym71 TABLE-MT, $sym72 TABLE-TV
(defmacro do-non-fort-isas ((col-var ins &optional mt tv done-var) &body body)
  "[Cyc] Iterates COL-VAR over the direct isa collections of non-fort INS,
from the *non-fort-isa-table*, with mt and tv relevance filtering."
  (alexandria:with-gensyms (isa-tuple table-mt table-tv)
    `(possibly-with-sbhl-mt-relevance (,mt)
       (possibly-with-sbhl-tv (,tv)
         (dolist (,isa-tuple (gethash ,ins (non-fort-isa-table)))
           ,@(when done-var `((when ,done-var (return))))
           (destructuring-bind (,col-var ,table-mt ,table-tv) ,isa-tuple
             (when (and (relevant-mt? ,table-mt)
                        (relevant-sbhl-tv? ,table-tv))
               ,@body)))))))

;; Non-fort isa tables
(defglobal *non-fort-isa-table* :uninitialized
  "[Cyc] An equal hash table mapping non-forts to their direct isas")

(defglobal *non-fort-instance-table* :uninitialized
  "[Cyc] An eq hash table mapping collections to their non-fort direct instances")

(defun set-non-fort-isa-table (table)
  "[Cyc] For use by the dumper ONLY"
  (declare (type hash-table table))
  (setf *non-fort-isa-table* table)
  nil)

(defun set-non-fort-instance-table (table)
  "[Cyc] For use by the dumper ONLY"
  (declare (type hash-table table))
  (setf *non-fort-instance-table* table)
  nil)

(defun non-fort-isa-table ()
  "[Cyc] For use by ONLY the dumper."
  *non-fort-isa-table*)

;; (defun non-fort-instance-table ()) -- commented declareFunction, no body

(defun non-fort-isa-tables-unbuilt? ()
  (or (uninitialized-p *non-fort-isa-table*)
      (uninitialized-p *non-fort-instance-table*)))

;; (defun initialize-non-fort-isa-tables ()) -- commented declareFunction, no body
;; (defun rebuild-non-fort-isa-tables ()) -- commented declareFunction, no body

(defun non-fort-isa? (ins col &optional mt tv)
  (declare (type (satisfies non-fort-p) ins))
  (let ((result? nil))
    (possibly-with-sbhl-mt-relevance (mt)
      (possibly-with-sbhl-tv (tv)
        (unless result?
          (dolist (isa-tuple (gethash ins (non-fort-isa-table)))
            (when result? (return))
            (destructuring-bind (candidate-col table-mt table-tv) isa-tuple
              (when (and (relevant-mt? table-mt)
                         (relevant-sbhl-tv? table-tv))
                (when (genls? candidate-col col mt tv)
                  (setf result? t))))))))
    result?))

;; (defun non-fort-isa-any? (ins col &optional mt tv)) -- commented declareFunction, no body
;; (defun non-fort-isa-all? (ins col &optional mt tv)) -- commented declareFunction, no body
;; (defun non-fort-isas (ins &optional mt tv)) -- commented declareFunction, no body
;; (defun non-fort-all-isa (ins &optional mt tv)) -- commented declareFunction, no body

(defun non-fort-instance-table-lookup (col)
  (gethash col *non-fort-instance-table*))

(defun possibly-add-non-fort-isa (gaf)
  "[Cyc] Called by the afterAdding for #$isa"
  (let ((ins (gaf-arg1 gaf)))
    (when (non-fort-p ins)
      (when (true-assertion? gaf)
        ;; missing-larkc 1763 — add-non-fort-isa
        (missing-larkc 1763)
        (return-from possibly-add-non-fort-isa t))))
  nil)

(defun possibly-remove-non-fort-isa (gaf)
  "[Cyc] Called by the afterRemoving for #$isa"
  (let ((ins (gaf-arg1 gaf)))
    (when (non-fort-p ins)
      (when (true-assertion? gaf)
        ;; missing-larkc 1809 — remove-non-fort-isa
        (missing-larkc 1809)
        (return-from possibly-remove-non-fort-isa t))))
  nil)

;; (defun add-non-fort-isa (gaf)) -- commented declareFunction, no body
;; (defun remove-non-fort-isa (gaf)) -- commented declareFunction, no body
;; (defun clear-sbhl-links-within-mt (arg1 arg2 &optional arg3)) -- commented declareFunction, no body
;; (defun clear-sbhl-links (arg1 &optional arg2)) -- commented declareFunction, no body
;; (defun clear-all-sbhl-links (arg1)) -- commented declareFunction, no body
;; (defun clear-all-sbhl-links-within-mt (arg1 arg2)) -- commented declareFunction, no body
;; (defun remove-node-from-sbhl-graphs (node)) -- commented declareFunction, no body
;; (defun clear-sbhl-module-graph (module)) -- commented declareFunction, no body
;; (defun clear-all-sbhl-data ()) -- commented declareFunction, no body
;; (defun clear-all-sbhl-non-time-data ()) -- commented declareFunction, no body

(defun sbhl-any-asserted-true-links (module node &optional (mt *mt*))
  "[Cyc] The first term found that appears in the arg 2 position of a gaf with
predicate of MODULE, arg1 NODE, and mt relevance MT."
  (declare (type (satisfies sbhl-module-p) module))
  (some-pred-value-in-relevant-mts node (sbhl-mod-link-pred module) mt 1 :true))

(defun sbhl-asserted-true-links (module node &optional (mt *mt*))
  "[Cyc] The link-nodes in assertions satisfying (PRED NODE link-node) where PRED
is MODULE's link predicate."
  (declare (type (satisfies sbhl-module-p) module))
  (if (sbhl-module-directed-links? module)
      (pred-values-in-relevant-mts node (sbhl-mod-link-pred module) mt 1 2 :true)
      (nconc (pred-values-in-relevant-mts node (sbhl-mod-link-pred module) mt 1 2 :true)
             (pred-values-in-relevant-mts node (sbhl-mod-link-pred module) mt 2 1 :true))))

;; (defun sbhl-asserted-false-links (module node &optional mt)) -- commented declareFunction, no body
;; (defun sbhl-asserted-true-inverse-links (module node &optional mt)) -- commented declareFunction, no body
;; (defun sbhl-asserted-false-inverse-links (module node &optional mt)) -- commented declareFunction, no body
;; (defun sbhl-supported-true-links (module node &optional mt)) -- commented declareFunction, no body
;; (defun sbhl-supported-false-links (module node &optional mt)) -- commented declareFunction, no body
;; (defun sbhl-supported-true-inverse-links (module node &optional mt)) -- commented declareFunction, no body
;; (defun sbhl-supported-false-inverse-links (module node &optional mt)) -- commented declareFunction, no body
