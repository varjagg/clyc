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

;;; Inference harness macros — iteration over problem links, controlling
;;; inference/strategy bindings, and forward inference configuration.
;;; Nearly all macros; only 2 functions with bodies, 2 stubs.

;; TODO - these bindings could be done via PROGV instead of macro symbol injection, but since you need a macro for the &body anyway, might as well jack it in this way.
;; These are also pretty generic, given a variable name and a destructor function, but it would all end up the same


;; Reconstructed from: $list0=((inference-var) &body body), $sym2$CLET,
;; $sym3$CUNWIND_PROTECT, $sym4$PROGN, $sym5$DESTROY_INFERENCE_AND_PROBLEM_STORE
;; Also uses $sym1$SYMBOLP (compile-time check on inference-var)
(defmacro with-inference-var ((inference-var) &body body)
  `(let ((,inference-var nil))
     (unwind-protect
          (progn ,@body)
       (destroy-inference-and-problem-store ,inference-var))))

;; Reconstructed from: $list6=((problem-store-var) &body body), $sym2$CLET,
;; $sym3$CUNWIND_PROTECT, $sym4$PROGN, $sym7$DESTROY_PROBLEM_STORE
(defmacro with-problem-store-var ((problem-store-var) &body body)
  `(let ((,problem-store-var nil))
     (unwind-protect
          (progn ,@body)
       (destroy-problem-store ,problem-store-var))))

;; Reconstructed from: $list8=((problem-store-var &optional properties) &body body),
;; $sym9$WITH_PROBLEM_STORE_VAR, $sym10$CSETQ, $sym11$NEW_PROBLEM_STORE
(defmacro with-new-problem-store ((problem-store-var &optional properties) &body body)
  `(with-problem-store-var (,problem-store-var)
     (setf ,problem-store-var (new-problem-store ,properties))
     ,@body))

;; Reconstructed from: $list12=((link-var problem &key type done) &body body),
;; $sym17$DO_SET_CONTENTS→do-set, $sym18$PROBLEM_ARGUMENT_LINKS,
;; $sym20$PWHEN, $sym21$PROBLEM_LINK_HAS_TYPE_
(defmacro do-problem-argument-links ((link-var problem &key type done) &body body)
  (if type
      `(do-set (,link-var (problem-argument-links ,problem) ,done)
         (when (problem-link-has-type? ,link-var ,type)
           ,@body))
      `(do-set (,link-var (problem-argument-links ,problem) ,done)
         ,@body)))

;; Reconstructed from: $list22=((supporting-mapped-problem-var link &key open? done) &body body),
;; $sym25$LINK_VAR (gensym), $sym26$DO_LIST→dolist,
;; $sym27$PROBLEM_LINK_SUPPORTING_MAPPED_PROBLEMS, $sym28$DO_PROBLEM_LINK_OPEN_MATCH_
(defmacro do-problem-link-supporting-mapped-problems
    ((supporting-mapped-problem-var link &key open? done) &body body)
  (with-temp-vars (link-var)
    `(let ((,link-var ,link))
       (dolist (,supporting-mapped-problem-var
                (problem-link-supporting-mapped-problems ,link-var))
         ,@(when done `((when ,done (return))))
         (when (do-problem-link-open-match? ,open? ,link-var
                                            ,supporting-mapped-problem-var)
           ,@body)))))

(defun do-problem-link-open-match? (open? link supporting-mapped-problem)
  (or (null open?)
      (problem-link-supporting-mapped-problem-open? link supporting-mapped-problem)))

;; Reconstructed from: $list30=((supporting-mapped-problem-var index-var link &key open? done) &body body),
;; $list31=(0) initial index, $sym32$CINC→incf
;; Shares gensym/iteration constants with do-problem-link-supporting-mapped-problems
(defmacro do-problem-link-supporting-mapped-problems-numbered
    ((supporting-mapped-problem-var index-var link &key open? done) &body body)
  (with-temp-vars (link-var)
    `(let ((,link-var ,link)
           (,index-var 0))
       (dolist (,supporting-mapped-problem-var
                (problem-link-supporting-mapped-problems ,link-var))
         ,@(when done `((when ,done (return))))
         (when (do-problem-link-open-match? ,open? ,link-var
                                            ,supporting-mapped-problem-var)
           ,@body
           (incf ,index-var))))))

;; Reconstructed from: $list33=((supporting-problem-var variable-map-var link &key open? done) &body body),
;; $sym34$SUPPORTING_MAPPED_PROBLEM (gensym), $sym35$MAPPED_PROBLEM_PROBLEM,
;; $sym36$MAPPED_PROBLEM_VARIABLE_MAP
;; Wraps do-problem-link-supporting-mapped-problems, destructuring each mapped problem.
(defmacro do-problem-link-supporting-problems
    ((supporting-problem-var variable-map-var link &key open? done) &body body)
  (with-temp-vars (supporting-mapped-problem)
    `(do-problem-link-supporting-mapped-problems
         (,supporting-mapped-problem ,link :open? ,open? :done ,done)
       (let ((,supporting-problem-var (mapped-problem-problem ,supporting-mapped-problem))
             (,variable-map-var (mapped-problem-variable-map ,supporting-mapped-problem)))
         ,@body))))

;; Reconstructed from: $list37=((sibling-link-var link &key done) &body body),
;; $sym39$SUPPORTED_PROBLEM (gensym), $sym40$LINK_VAR (gensym),
;; $sym41$PROBLEM_LINK_SUPPORTED_PROBLEM, $sym42$PUNLESS→unless
;; Iterates argument links of the link's supported problem, skipping the link itself.
(defmacro do-problem-link-sibling-links ((sibling-link-var link &key done) &body body)
  (with-temp-vars (supported-problem link-var)
    `(let* ((,link-var ,link)
            (,supported-problem (problem-link-supported-problem ,link-var)))
       (do-problem-argument-links (,sibling-link-var ,supported-problem :done ,done)
         (unless (eq ,sibling-link-var ,link-var)
           ,@body)))))

;; Reconstructed from: $list43=((dependent-link-var link &key link-type done) &body body),
;; $sym46$SUPPORTED_PROBLEM (gensym), $sym47$DO_PROBLEM_DEPENDENT_LINKS
;; do-problem-dependent-links is from inference-datastructures-problem (unported).
(defmacro do-problem-link-dependent-links
    ((dependent-link-var link &key link-type done) &body body)
  (with-temp-vars (supported-problem)
    `(let ((,supported-problem (problem-link-supported-problem ,link)))
       (do-problem-dependent-links (,dependent-link-var ,supported-problem
                                    :type ,link-type :done ,done)
         ,@body))))

;; Reconstructed from: $list48=((argument-link-var link &key open? link-type done) &body body),
;; $sym50$SUPPORTING_PROBLEM (gensym), $sym51$VARIABLE_MAP (gensym),
;; $sym52$DO_PROBLEM_LINK_SUPPORTING_PROBLEMS, $sym53$IGNORE
;; Iterates supporting problems, ignoring variable-map, then iterates each problem's
;; argument links filtered by link-type.
(defmacro do-problem-link-argument-links
    ((argument-link-var link &key open? link-type done) &body body)
  (with-temp-vars (supporting-problem variable-map)
    `(do-problem-link-supporting-problems
         (,supporting-problem ,variable-map ,link :open? ,open? :done ,done)
       (declare (ignore ,variable-map))
       (do-problem-argument-links (,argument-link-var ,supporting-problem
                                   :type ,link-type)
         ,@body))))

;; Reconstructed from: $list54=((proof-var link &key proof-status) &body body),
;; $sym57$CDOLIST→dolist, $sym58$PROBLEM_LINK_PROOFS, $sym59$PROOF_HAS_STATUS_
(defmacro do-problem-link-proofs-int ((proof-var link &key proof-status) &body body)
  (if proof-status
      `(dolist (,proof-var (problem-link-proofs ,link))
         (when (proof-has-status? ,proof-var ,proof-status)
           ,@body))
      `(dolist (,proof-var (problem-link-proofs ,link))
         ,@body)))

;; Reconstructed from: $sym60$LNK (gensym), $sym61$PROBLEM (gensym),
;; $sym62$DO_PROBLEM_PROOFS (from inference-datastructures-problem),
;; $sym63$PROOF_LINK
;; Computes proofs for a link by iterating the supported problem's proofs
;; and filtering to those whose proof-link matches this link.
(defmacro do-problem-link-proofs-computed ((proof-var link &key proof-status) &body body)
  (with-temp-vars (lnk problem)
    `(let* ((,lnk ,link)
            (,problem (problem-link-supported-problem ,lnk)))
       (do-problem-proofs (,proof-var ,problem :proof-status ,proof-status)
         (when (eq (proof-link ,proof-var) ,lnk)
           ,@body)))))

;; Reconstructed from: $sym64$PIF→if,
;; $sym65$*PROBLEM_LINK_DATASTRUCTURE_STORES_PROOFS?*,
;; $sym66$DO_PROBLEM_LINK_PROOFS_INT, $sym67$DO_PROBLEM_LINK_PROOFS_COMPUTED
;; Dispatches between stored proofs (fast path) and computed proofs.
(defmacro do-problem-link-proofs ((proof-var link &key proof-status) &body body)
  `(if *problem-link-datastructure-stores-proofs?*
       (do-problem-link-proofs-int (,proof-var ,link :proof-status ,proof-status)
         ,@body)
       (do-problem-link-proofs-computed (,proof-var ,link :proof-status ,proof-status)
         ,@body)))

;; Reconstructed from: $list68=((rt-link-var jo-link &key done) &body body),
;; $sym69$JO_LINK_VAR (gensym), $sym70$MOTIVATING_CONJUNCTION_PROBLEM (gensym),
;; $kw71$RESIDUAL_TRANSFORMATION, $sym72$RESIDUAL_TRANSFORMATION_LINK_MOTIVATED_BY_JOIN_ORDERED_LINK_
;; Iterates residual transformation links motivated by a join-ordered link.
;; $sym70 is the gensym for the inlined do-problem-link-dependent-links expansion
;; (which accesses problem-link-supported-problem). $sym47$DO_PROBLEM_DEPENDENT_LINKS shared.
(defmacro do-join-ordered-link-motivated-residual-transformation-links
    ((rt-link-var jo-link &key done) &body body)
  (with-temp-vars (jo-link-var)
    `(let ((,jo-link-var ,jo-link))
       (do-problem-link-dependent-links (,rt-link-var ,jo-link-var
                                         :link-type :residual-transformation
                                         :done ,done)
         (when (residual-transformation-link-motivated-by-join-ordered-link?
                ,rt-link-var ,jo-link-var)
           ,@body)))))

;; Reconstructed from: $list73=((rt-link-var t-link &key done) &body body),
;; $sym74$T_LINK_VAR (gensym), $sym75$JO_LINK_VAR (gensym),
;; $sym76$DO_PROBLEM_LINK_DEPENDENT_LINKS, $kw77$JOIN_ORDERED,
;; $sym78$DO_JOIN_ORDERED_LINK_MOTIVATED_RESIDUAL_TRANSFORMATION_LINKS,
;; $sym79$RESIDUAL_TRANSFORMATION_LINK_MOTIVATED_BY_TRANSFORMATION_LINK_
;; For each join-ordered dependent of t-link, finds its motivated RT links,
;; then filters to those motivated by the original transformation link.
(defmacro do-transformation-link-motivated-residual-transformation-links
    ((rt-link-var t-link &key done) &body body)
  (with-temp-vars (t-link-var jo-link-var)
    `(let ((,t-link-var ,t-link))
       (do-problem-link-dependent-links (,jo-link-var ,t-link-var
                                         :link-type :join-ordered
                                         :done ,done)
         (do-join-ordered-link-motivated-residual-transformation-links
             (,rt-link-var ,jo-link-var)
           (when (residual-transformation-link-motivated-by-transformation-link?
                  ,rt-link-var ,t-link-var)
             ,@body))))))

;; Reconstructed from: $list80=((*current-forward-problem-store* nil)),
;; $list81=((clear-current-forward-problem-store))
(defmacro with-forward-problem-store-reuse (&body body)
  `(let ((*current-forward-problem-store* nil))
     (unwind-protect
          (progn ,@body)
       (clear-current-forward-problem-store))))

;; Reconstructed from: $list82=((*type-filter-forward-dnf* t))
(defmacro with-forward-dnf-type-filtering (&body body)
  `(let ((*type-filter-forward-dnf* t))
     ,@body))

;; Reconstructed from: $list83=((*forward-inference-allowed-rules* :all))
(defmacro with-forward-inference-all-rules-allowed (&body body)
  `(let ((*forward-inference-allowed-rules* :all))
     ,@body))

;; Reconstructed from: $sym84$WITH_FORWARD_INFERENCE_ALLOWED_RULES
;; Delegates to with-forward-inference-allowed-rules with nil.
(defmacro with-forward-inference-no-rules-allowed (&body body)
  `(with-forward-inference-allowed-rules nil ,@body))

;; Reconstructed from: $list85=(rules &body body),
;; $sym86$*FORWARD_INFERENCE_ALLOWED_RULES*
(defmacro with-forward-inference-allowed-rules (rules &body body)
  `(let ((*forward-inference-allowed-rules* ,rules))
     ,@body))

(defun current-controlling-inference ()
  "[Cyc] Return nil or inference-p; the current inference controlling the current work in progress, or NIL if none."
  (first *controlling-inferences*))

;; (defun current-controlling-inferences () ...) -- active declareFunction, no body

;; Reconstructed from: $list88=(inference &body body),
;; $sym89$*CONTROLLING_INFERENCES*, $sym90$CONS, $list91=(*controlling-inferences*)
;; Pushes inference onto the controlling inference stack.
(defmacro within-controlling-inference (inference &body body)
  `(let ((*controlling-inferences* (cons ,inference *controlling-inferences*)))
     ,@body))

;; Reconstructed from: $sym92$WITHIN_CONTROLLING_INFERENCE
;; Clears the controlling inference stack.
(defmacro within-no-controlling-inference (&body body)
  `(let ((*controlling-inferences* nil))
     ,@body))

;; (defun current-controlling-strategy () ...) -- active declareFunction, no body

;; Reconstructed from: $list94=(strategy &body body),
;; $sym95$*CONTROLLING_STRATEGY*
(defmacro within-controlling-strategy (strategy &body body)
  `(let ((*controlling-strategy* ,strategy))
     ,@body))

;; Reconstructed from: $sym96$WITHIN_CONTROLLING_STRATEGY
(defmacro within-no-controlling-strategy (&body body)
  `(let ((*controlling-strategy* nil))
     ,@body))

;; Reconstructed from: $list97=((inference) &body body), $kw98=:cyc-maint
;; Cyc-Maint feature guard for PAD metrics gathering.
;; In the open-source version, just executes body.
(defmacro possibly-gathering-pad-metrics ((inference) &body body)
  (declare (ignore inference))
  `(progn ,@body))

;; Reconstructed from: $list99=((disjunct-var pattern) &body body),
;; $sym100$PATTERN_VAR (gensym), $sym101$OR_PATTERN_P, $sym102$REST
;; If pattern is an OR pattern, iterates over its disjuncts; otherwise treats
;; the whole pattern as a single disjunct.
(defmacro do-pattern-possible-disjuncts ((disjunct-var pattern) &body body)
  (with-temp-vars (pattern-var)
    `(let ((,pattern-var ,pattern))
       (if (or-pattern-p ,pattern-var)
           (dolist (,disjunct-var (rest ,pattern-var))
             ,@body)
           (let ((,disjunct-var ,pattern-var))
             ,@body)))))

;; TODO - do-asked-queries
;; Constants: $list103=((query-info-var filename &key element-num done?) &body body),
;; $list104=(:element-num :done?), $sym107$DONE_VAR? (gensym), $sym108$I (gensym),
;; $sym109$INPUT_STREAM (gensym), $list110=(nil), $sym111$WITH_PRIVATE_BINARY_FILE,
;; $list112=(:input), $sym113$WITH_CFASL_COMMON_SYMBOLS, $list114=(asked-query-common-symbols),
;; $sym115$UNTIL, $sym116$LOAD_ASKED_QUERY_FROM_STREAM, $sym117$PCOND→cond,
;; $kw118$EOF, $list119=(t), $sym120$STRINGP, $sym121$WARN,
;; $str122="Read invalid query info ~s"
;; Complex file I/O macro: opens binary file, reads CFASL query objects in a loop,
;; dispatches on EOF/invalid/valid. element-num likely selects a specific query index.
;; Reconstruction blocked on unported with-private-binary-file and with-cfasl-common-symbols.

;; TODO - do-asked-queries-in-directory
;; Constants: $list123=((query-info-var filename-var directory &key done?) &body body),
;; $list124=(:done?), $sym125$DO_DIRECTORY_CONTENTS, $sym126$ASKED_QUERIES_FILENAME?,
;; $sym127$DO_ASKED_QUERIES
;; Iterates directory, filters by asked-queries-filename?, delegates to do-asked-queries.


;;;; Variables

(defparameter *controlling-inferences* nil)

(defparameter *controlling-strategy* nil)


;;;; Setup

(toplevel
  (register-macro-helper 'do-problem-link-open-match?
                         'do-problem-link-supporting-mapped-problems))
