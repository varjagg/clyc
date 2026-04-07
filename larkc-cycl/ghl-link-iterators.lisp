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

(defparameter *ghl-link-pred* nil)

(defparameter *gt-relevant-pred* nil)

;; Reconstructed from Internal Constants evidence:
;; $list0 = (PRED &BODY BODY), $sym1$CLET, $sym2$_GHL_LINK_PRED_
;; Simple binding macro: binds *ghl-link-pred* to the given predicate.
(defmacro with-ghl-link-pred (pred &body body)
  `(let ((*ghl-link-pred* ,pred))
     ,@body))

;; Reconstructed from Internal Constants evidence:
;; $list3 = ((*GHL-LINK-PRED* NIL))
;; Binds *ghl-link-pred* to NIL for a fresh context.
(defmacro with-new-ghl-link-pred (&body body)
  `(let ((*ghl-link-pred* nil))
     ,@body))

;; (defun get-ghl-link-pred () ...) -- commented declareFunction, no body (0 0)
;; Likely returns the current value of *ghl-link-pred*.

;; Reconstructed from Internal Constants evidence:
;; $list4 = ((LINK-NODE-VAR NODE PREDICATES DIRECTION &KEY SUPPORT-VAR (TV :TRUE-DEF) DONE-VAR) &BODY BODY)
;; $sym11$PRED (uninterned), $sym12$CDOLIST, $sym13$WITH_GHL_LINK_PRED,
;; $sym14$PCOND, $sym15$SBHL_PREDICATE_P, $sym16$DO_SBHL_ACCESSIBLE_LINK_NODES,
;; $sym17$GET_SBHL_MODULE, $sym18$GHL_MAKE_SBHL_SUPPORT, $sym19$GT_PREDICATE_P,
;; $sym20$DO_GT_ACCESSIBLE_LINK_NODES, $sym21$PRED (uninterned),
;; $sym22$SUPPORT_VAR (uninterned), $sym23$IGNORE
;;
;; Iterates over predicates, dispatching to either SBHL or GT link iteration
;; depending on predicate type. When support-var is given, SBHL branch creates
;; a support object, GT branch passes an assertion-var.
(defmacro do-ghl-accessible-link-nodes ((link-node-var node predicates direction
                                         &key support-var (tv :true-def) done-var)
                                        &body body)
  (let ((pred (make-symbol "PRED")))
    (if support-var
        (let ((sv (make-symbol "SUPPORT-VAR")))
          `(cdolist (,pred ,predicates)
             (with-ghl-link-pred ,pred
               (cond
                 ((sbhl-predicate-p ,pred)
                  (do-sbhl-accessible-link-nodes (,link-node-var ,node
                                                  (get-sbhl-module ,pred)
                                                  ,direction
                                                  :done-var ,done-var)
                    (let ((,support-var (ghl-make-sbhl-support ,pred ,link-node-var
                                                               *sbhl-link-mt*
                                                               *sbhl-link-tv*)))
                      ,@body)))
                 ((gt-predicate-p ,pred)
                  (let ((,sv nil))
                    (declare (ignore ,sv))
                    (do-gt-accessible-link-nodes (,link-node-var ,support-var
                                                  ,node ,pred ,direction
                                                  :tv ,tv :done-var ,done-var)
                      ,@body)))))))
        ;; No support-var: simpler expansion without ghl-make-sbhl-support
        (let ((pred2 (make-symbol "PRED")))
          `(cdolist (,pred2 ,predicates)
             (with-ghl-link-pred ,pred2
               (cond
                 ((sbhl-predicate-p ,pred2)
                  (do-sbhl-accessible-link-nodes (,link-node-var ,node
                                                  (get-sbhl-module ,pred2)
                                                  ,direction
                                                  :done-var ,done-var)
                    ,@body))
                 ((gt-predicate-p ,pred2)
                  (do-gt-accessible-link-nodes (,link-node-var nil
                                                ,node ,pred2 ,direction
                                                :tv ,tv :done-var ,done-var)
                    ,@body)))))))))

;; (defun ghl-make-sbhl-support (pred link-node mt tv) ...) -- commented declareFunction, no body (4 0)
;; Creates a support object for SBHL links.
;; Registered as macro helper for DO-GHL-ACCESSIBLE-LINK-NODES.

;; Reconstructed from Internal Constants evidence:
;; $list25 = ((LINK-NODE-VAR START-NODE MODULE DIRECTION &KEY DONE-VAR) &BODY BODY)
;; Uninterned symbols: LINK-NODES-VAR, SEARCH-DIRECTION, LINK-DIRECTION, D-LINK, MT,
;;   TV-LINKS, TV, NODE
;; $sym35$NAUT_TO_NART, $sym36$WITH_SBHL_SEARCH_MODULE,
;; $sym37$POSSIBLY_FLIP_GENL_INVERSE_MODE, $sym38$FORT_P,
;; $sym39$WITH_SBHL_GRAPH_LINK, $sym40$DO_GHL_RELEVANT_DIRECTIONS,
;; $sym41$SBHL_SEARCH_DIRECTION_TO_LINK_DIRECTION,
;; $sym42$DO_SBHL_DIRECTION_LINK, $sym43$PWHEN, $sym44$RELEVANT_MT_,
;; $sym45$_SBHL_LINK_MT_, $sym46$DO_SBHL_TV_LINKS, $sym47$RELEVANT_SBHL_TV_,
;; $sym48$_SBHL_LINK_TV_, $sym49$DO_LIST, $kw50$DONE, $sym51$CLOSED_NAUT_,
;; $sym52$DO_RELEVANT_SBHL_NAUT_GENERATED_LINKS
;;
;; Iterates SBHL links for a node: opens the SBHL graph link, iterates over
;; relevant directions, mt-links, tv-links, and node lists to yield accessible
;; link nodes. Also handles NAUT-generated links for closed NAUTs.
(defmacro do-sbhl-accessible-link-nodes ((link-node-var start-node module direction
                                          &key done-var)
                                         &body body)
  (let ((link-nodes-var (make-symbol "LINK-NODES-VAR"))
        (search-direction (make-symbol "SEARCH-DIRECTION"))
        (link-direction (make-symbol "LINK-DIRECTION"))
        (d-link (make-symbol "D-LINK"))
        (mt-var (make-symbol "MT"))
        (tv-links (make-symbol "TV-LINKS"))
        (tv-var (make-symbol "TV"))
        (node-var (make-symbol "NODE")))
    `(let ((,node-var (naut-to-nart ,start-node)))
       (with-sbhl-search-module (,module)
         (possibly-flip-genl-inverse-mode (,module ,direction)
           (when (fort-p ,node-var)
             (with-sbhl-graph-link (,node-var)
               (do-ghl-relevant-directions (,search-direction ,direction)
                 (let ((,link-direction (sbhl-search-direction-to-link-direction
                                         ,search-direction ,module)))
                   (do-sbhl-direction-link (,d-link ,link-direction)
                     (when (relevant-mt? *sbhl-link-mt*)
                       (do-sbhl-tv-links (,tv-links ,d-link)
                         (when (relevant-sbhl-tv? *sbhl-link-tv*)
                           (do-list (,link-node-var ,tv-links :done ,done-var)
                             ,@body)))))))))))
       (when (closed-naut? ,start-node)
         (do-relevant-sbhl-naut-generated-links (,link-node-var ,start-node ,module
                                                  ,direction :done ,done-var)
           ,@body)))))

;; Reconstructed from Internal Constants evidence:
;; $list53 = ((LINK-NODE-VAR ASSERTION-VAR NODE PRED DIRECTION &KEY (TV :TRUE-DEF) DONE-VAR) &BODY BODY)
;; Uninterned symbols: SEARCH-DIRECTION, INDEX-ARGNUM, GATHER-ARGNUM, ASSERTION, TRUTH, STRENGTH
;; $sym61$TV_TRUTH, $sym62$TV_STRENGTH, $sym63$WITH_GT_ARGS_UNSWAPPED,
;; $sym64$GT_INDEX_ARGNUM_FOR_DIRECTION, $sym65$OTHER_BINARY_ARG,
;; $sym66$DO_GT_GAF_ARG_INDEX, $kw67$INDEX, $kw68$TRUTH,
;; $sym69$COR, $sym70$CNOT, $sym71$ASSERTION_P,
;; $sym72$EL_STRENGTH_IMPLIES, $sym73$ASSERTION_STRENGTH,
;; $sym74$FORMULA_ARG, $list75 = (GHL-USES-SPEC-PREDS-P)
;;
;; Iterates GT (graph transversal) accessible link nodes. Unswaps args if
;; spec-preds are in use, then iterates GAF arg index entries matching
;; the predicate and direction, filtering by truth value and strength.
(defmacro do-gt-accessible-link-nodes ((link-node-var assertion-var node pred direction
                                        &key (tv :true-def) done-var)
                                       &body body)
  (let ((search-direction (make-symbol "SEARCH-DIRECTION"))
        (index-argnum (make-symbol "INDEX-ARGNUM"))
        (gather-argnum (make-symbol "GATHER-ARGNUM"))
        (assertion (make-symbol "ASSERTION"))
        (truth (make-symbol "TRUTH"))
        (strength (make-symbol "STRENGTH")))
    `(let* ((,search-direction ,direction)
            (,truth (tv-truth ,tv))
            (,strength (tv-strength ,tv)))
       (with-gt-args-unswapped
         (let* ((,index-argnum (gt-index-argnum-for-direction ,search-direction))
                (,gather-argnum (other-binary-arg ,index-argnum)))
           (do-gt-gaf-arg-index (,assertion ,node ,pred
                                 :index ,index-argnum
                                 :truth ,truth
                                 :done ,done-var)
             (when (or (not (assertion-p ,assertion))
                       (el-strength-implies (assertion-strength ,assertion)
                                            ,strength))
               (let ((,link-node-var (formula-arg ,assertion ,gather-argnum))
                     ,@(when assertion-var
                         `((,assertion-var ,assertion))))
                 ,@(when (and assertion-var
                              (not (eq assertion-var link-node-var)))
                     `((declare (ignorable ,assertion-var))))
                 ,@body)))))
       (when (ghl-uses-spec-preds-p)
         (with-gt-args-swapped
           (let* ((,index-argnum (gt-index-argnum-for-direction ,search-direction))
                  (,gather-argnum (other-binary-arg ,index-argnum)))
             (do-gt-gaf-arg-index (,assertion ,node ,pred
                                   :index ,index-argnum
                                   :truth ,truth
                                   :done ,done-var)
               (when (or (not (assertion-p ,assertion))
                         (el-strength-implies (assertion-strength ,assertion)
                                              ,strength))
                 (let ((,link-node-var (formula-arg ,assertion ,gather-argnum))
                       ,@(when assertion-var
                           `((,assertion-var ,assertion))))
                   ,@(when (and assertion-var
                                (not (eq assertion-var link-node-var)))
                       `((declare (ignorable ,assertion-var))))
                   ,@body)))))))))

(defun relevant-pred-wrt-gt? (predicate)
  "[Cyc] Return whether PREDICATE is relevant with respect to the current GT search predicate."
  (gt-relevant-pred? predicate *gt-relevant-pred*))

;; Reconstructed from Internal Constants evidence:
;; $list77 = ((VAR TERM PRED &KEY INDEX TRUTH DONE) &BODY BODY)
;; $sym76$WITH_GT_ARGS_SWAPPED, $sym79$VAR_MT (uninterned),
;; $sym80$PROGN, $sym81$_GT_RELEVANT_PRED_, $sym82$WITH_PREDICATE_FUNCTION,
;; $list83 = (QUOTE RELEVANT-PRED-WRT-GT?), $sym84$DO_GAF_ARG_INDEX,
;; $sym85$PWHEN_FEATURE, $kw86$CYC_SKSI, $list87 = (GT-USE-SKSI?),
;; $sym88$WITH_SKSI_GT_SEARCH_PRED, $sym89$DO_SKSI_GAF_ARG_INDEX_RELEVANT_PRED,
;; $kw90$INDEX_ARGNUM
;;
;; Iterates GAF arg index for GT predicates. Binds *gt-relevant-pred* and
;; uses WITH-PREDICATE-FUNCTION with RELEVANT-PRED-WRT-GT? for pred relevance,
;; then delegates to DO-GAF-ARG-INDEX. Also conditionally handles SKSI lookups.
(defmacro do-gt-gaf-arg-index ((var term pred &key index truth done) &body body)
  (let ((var-mt (make-symbol "VAR-MT")))
    `(progn
       (let ((*gt-relevant-pred* ,pred))
         (with-predicate-function (#'relevant-pred-wrt-gt?)
           (do-gaf-arg-index (,var ,term
                              :index ,index
                              :predicate ,pred
                              :truth ,truth
                              :done ,done)
             ,@body)))
       ;; SKSI support (feature-gated on :cyc-sksi)
       (pwhen-feature (:cyc-sksi)
         (when (gt-use-sksi?)
           (with-sksi-gt-search-pred (,pred)
             (do-sksi-gaf-arg-index-relevant-pred (,var ,term ,pred
                                                   :index-argnum ,index
                                                   :done ,done)
               ,@body)))))))

(defun gt-predicate-p (pred)
  "[Cyc] Return T if PRED is a GT predicate."
  (declare (ignore pred))
  t)

(defun gt-index-argnum-for-direction (direction)
  "[Cyc] Return the index argnum for DIRECTION."
  (cond
    ((eq direction :forward) 1)
    ((eq direction :backward) 2)
    (t
     ;; missing-larkc 31825 likely signals an error for an invalid direction.
     ;; The $str93 format string "Invalid direction ~a" confirms this was an error call.
     (missing-larkc 31825))))

(defun gt-relevant-pred? (pred search-pred)
  "[Cyc] Return whether PRED is relevant given SEARCH-PRED, using spec-pred or spec-inverse checking when applicable."
  (if (ghl-uses-spec-preds-p)
      (if (gt-args-swapped-p)
          (cached-spec-inverse? search-pred pred)
          (cached-spec-pred? search-pred pred))
      (eq pred search-pred)))

(register-macro-helper 'ghl-make-sbhl-support 'do-ghl-accessible-link-nodes)
