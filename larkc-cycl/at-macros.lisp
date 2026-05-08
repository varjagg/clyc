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

;; Reconstructed from Internal Constants $list1, $sym2$CUNWIND_PROTECT, $list3.
;; Binds new defn history tables with unwind-protect to clear-defn-space.
(defmacro with-new-defn-space (&body body)
  "[Cyc] Execute BODY with fresh defn space history tables, cleaning up on exit."
  `(let ((*defn-fn-history* (make-defn-fn-history-table))
         (*quoted-defn-fn-history* (make-quoted-defn-fn-history-table))
         (*defn-col-history* (make-defn-col-history-table))
         (*quoted-defn-col-history* (make-quoted-defn-col-history-table)))
     (unwind-protect
          (progn ,@body)
       (clear-defn-space))))

;; Reconstructed from Internal Constants $list4.
;; Like with-new-defn-space but reuses existing tables if already initialized.
(defmacro with-possibly-new-defn-space (&body body)
  "[Cyc] Execute BODY with possibly-new defn space history tables, clearing defn cache on exit."
  `(let ((*defn-fn-history* (possibly-make-defn-fn-history-table))
         (*quoted-defn-fn-history* (possibly-make-quoted-defn-fn-history-table))
         (*defn-col-history* (possibly-make-defn-col-history-table))
         (*quoted-defn-col-history* (possibly-make-quoted-defn-col-history-table)))
     (unwind-protect
          (progn ,@body)
       (clear-defn-space))))

(defun make-defn-fn-history-table ()
  "[Cyc] Create a new hash table for defn function history."
  (make-hash-table :size *defn-fn-history-default-size*))

;; [Clyc] Java declareFunction is active but has no method body (missing-larkc).
;; Body hand-reconstructed so the with-new-defn-space macro expansion works at runtime —
;; otherwise every invocation would error on the missing-larkc function. Non-quoted and
;; quoted variants share implementation in the surviving Cyc pattern.
(defun make-quoted-defn-fn-history-table ()
  (make-defn-fn-history-table))

(defun make-defn-col-history-table ()
  "[Cyc] Create a new hash table for defn collection history."
  (make-hash-table :size *defn-col-history-default-size*))

;; [Clyc] Same situation as make-quoted-defn-fn-history-table above —
;; Java has an active declareFunction with no body. Hand-reconstructed.
(defun make-quoted-defn-col-history-table ()
  (make-defn-col-history-table))

(defun* possibly-make-defn-fn-history-table ()
    (:inline t)
  "[Cyc] Return *defn-fn-history* if initialized, else make a new table."
  (let ((val *defn-fn-history*))
    (if (uninitialized-p val)
        (make-defn-fn-history-table)
        val)))

(defun* possibly-make-quoted-defn-fn-history-table () (:inline t)
  "[Cyc] Return quoted defn fn history if initialized, else make a new table."
  (possibly-make-defn-fn-history-table))

(defun* possibly-make-defn-col-history-table () (:inline t)
  "[Cyc] Return *defn-col-history* if initialized, else make a new table."
  (let ((val *defn-col-history*))
    (if (uninitialized-p val)
        (make-defn-col-history-table)
        val)))

(defun* possibly-make-quoted-defn-col-history-table () (:inline t)
  "[Cyc] Return quoted defn col history if initialized, else make a new table."
  (possibly-make-defn-col-history-table))

;; Reconstructed from $list15, $sym16. Simple variable binding macros.
(defmacro with-at-defns ((defns) &body body)
  "[Cyc] Execute BODY with *at-defns* bound to DEFNS."
  `(let ((*at-defns* ,defns))
     ,@body))

;; Reconstructed from $list17, $sym18.
(defmacro with-at-defn ((defn) &body body)
  "[Cyc] Execute BODY with *at-defn* bound to DEFN."
  `(let ((*at-defn* ,defn))
     ,@body))

;; Reconstructed from $list15, $sym19. Uses same arglist pattern as with-at-defns.
(defmacro with-at-functions ((defns) &body body)
  "[Cyc] Execute BODY with *at-functions* bound to DEFNS."
  `(let ((*at-functions* ,defns))
     ,@body))

;; Reconstructed from $list17, $sym20. Uses same arglist pattern as with-at-defn.
(defmacro with-at-function ((defn) &body body)
  "[Cyc] Execute BODY with *at-function* bound to DEFN."
  `(let ((*at-function* ,defn))
     ,@body))

;; Reconstructed from $list21, $list22, $sym23$CSETQ.
;; Binds *at-result*, executes body, sets result-var from *at-result*.
(defmacro with-at-result ((result-var) &body body)
  "[Cyc] Execute BODY tracking AT result in *at-result*, then set RESULT-VAR."
  `(let ((*at-result* nil))
     ,@body
     (setf ,result-var *at-result*)))

;; Reconstructed from $list24, $list25, $sym23$CSETQ.
;; Binds *at-some-arg-isa?*, executes body, sets boolean-var.
(defmacro with-some-at-arg-isa-var ((boolean-var) &body body)
  "[Cyc] Execute BODY tracking whether some arg-isa was found, then set BOOLEAN-VAR."
  `(let ((*at-some-arg-isa?* nil))
     ,@body
     (setf ,boolean-var *at-some-arg-isa?*)))

;; Reconstructed from $list26, $sym27.
(defmacro with-at-mode ((mode) &body body)
  "[Cyc] Execute BODY with *at-mode* bound to MODE."
  `(let ((*at-mode* ,mode))
     ,@body))

;; Reconstructed from $list28, $sym29.
(defmacro with-at-ind-isa ((col) &body body)
  "[Cyc] Execute BODY with *at-ind-isa* bound to COL."
  `(let ((*at-ind-isa* ,col))
     ,@body))

;; Reconstructed from $list30, $sym31.
(defmacro with-at-ind-genl ((term) &body body)
  "[Cyc] Execute BODY with *at-ind-genl* bound to TERM."
  `(let ((*at-ind-genl* ,term))
     ,@body))

;; Reconstructed from $list32, $sym33, $sym34$PWHEN, $sym35.
;; Binds *at-pred*, and when *at-inverse* is non-nil, also executes body
;; for the inverse via pwhen.
(defmacro with-at-pred ((constraint-pred) &body body)
  "[Cyc] Execute BODY with *at-pred* bound to CONSTRAINT-PRED."
  `(let ((*at-pred* ,constraint-pred))
     ,@body))

;; Reconstructed from $list32, $sym35.
(defmacro with-at-inverse ((constraint-pred) &body body)
  "[Cyc] Execute BODY with *at-inverse* bound to CONSTRAINT-PRED."
  `(let ((*at-inverse* ,constraint-pred))
     ,@body))

;; Reconstructed from $list36, $list37.
(defmacro with-at-mapping-inverses (&body body)
  "[Cyc] Execute BODY with *at-mapping-genl-inverses?* bound to T when inverses are checked."
  `(when (and *at-check-genl-inverses?* *at-inverse*)
     (let ((*at-mapping-genl-inverses?* t))
       ,@body)))

;; Reconstructed from $list38, $sym39-$sym51.
;; Complex macro: binds *at-reln*, *at-search-genl-preds?*, *at-search-genl-inverses?*
;; with conditions based on fort-p and asserted-genl-predicates?/inverses?.
(defmacro with-at-reln ((reln) &body body)
  "[Cyc] Execute BODY with *at-reln* bound to RELN and genl-pred/inverse search flags set appropriately."
  (with-temp-vars (asserted-genl-something?)
    `(let* ((,asserted-genl-something?
              (when (fort-p ,reln)
                (or (asserted-genl-predicates? ,reln)
                    (asserted-genl-inverses? ,reln))))
            (*at-reln* ,reln)
            (*at-search-genl-preds?* (and *at-check-genl-preds?*
                                         ,asserted-genl-something?))
            (*at-search-genl-inverses?* (and *at-check-genl-inverses?*
                                            ,asserted-genl-something?)))
       ,@body)))

;; Reconstructed from $list30, $sym52.
(defmacro with-at-arg ((term) &body body)
  "[Cyc] Execute BODY with *at-arg* bound to TERM."
  `(let ((*at-arg* ,term))
     ,@body))

;; Reconstructed from $list53, $sym54.
(defmacro with-at-type ((type) &body body)
  "[Cyc] Execute BODY with *at-arg-type* bound to TYPE."
  `(let ((*at-arg-type* ,type))
     ,@body))

;; Reconstructed from $list55, $sym56$CHECK_TYPE, $list57, $sym58.
(defmacro with-at-argnum ((integer) &body body)
  "[Cyc] Execute BODY with *at-argnum* bound to INTEGER."
  `(let ((*at-argnum* (the integer ,integer)))
     ,@body))

;; Reconstructed from $list30, $sym59.
(defmacro with-at-ind-arg ((term) &body body)
  "[Cyc] Execute BODY with *at-ind-arg* bound to TERM."
  `(let ((*at-ind-arg* ,term))
     ,@body))

;; Reconstructed from $list55, $sym56$CHECK_TYPE, $list57, $sym60.
(defmacro with-at-ind-argnum ((integer) &body body)
  "[Cyc] Execute BODY with *at-ind-argnum* bound to INTEGER."
  `(let ((*at-ind-argnum* (the integer ,integer)))
     ,@body))

;; Reconstructed from $list61, $list62, $sym63.
(defmacro with-at-arg-isa ((collection) &body body)
  "[Cyc] Execute BODY with *at-arg-isa* bound to COLLECTION."
  `(let ((*at-arg-isa* ,collection))
     ,@body))

;; Reconstructed from $list64, $list65, $sym66.
(defmacro with-at-base-fn ((fn) &body body)
  "[Cyc] Execute BODY with *at-base-fn* bound to FN."
  `(let ((*at-base-fn* ,fn))
     ,@body))

;; Reconstructed from $list30, $sym67.
(defmacro with-at-source ((term) &body body)
  "[Cyc] Execute BODY with *at-source* bound to TERM."
  `(let ((*at-source* ,term))
     ,@body))

;; Reconstructed from $list68, $sym69.
(defmacro with-at-constraint-gaf ((gaf) &body body)
  "[Cyc] Execute BODY with *at-constraint-gaf* bound to GAF."
  `(let ((*at-constraint-gaf* ,gaf))
     ,@body))

;; Reconstructed from $list70, $sym71, $sym72.
;; Level-gated: only execute body when *at-test-level* >= level.
(defmacro at-test ((level) &body body)
  "[Cyc] Execute BODY only when *at-test-level* >= LEVEL."
  `(when (>= *at-test-level* ,level)
     ,@body))

;; Reconstructed from $list70, $sym71, $sym73.
(defmacro at-trace ((level) &body body)
  "[Cyc] Execute BODY only when *at-trace-level* >= LEVEL."
  `(when (>= *at-trace-level* ,level)
     ,@body))

;; Reconstructed from $list70, $sym71, $sym74.
(defmacro defn-test ((level) &body body)
  "[Cyc] Execute BODY only when *defn-test-level* >= LEVEL."
  `(when (>= *defn-test-level* ,level)
     ,@body))

;; Reconstructed from $list70, $sym71, $sym75.
(defmacro defn-trace ((level) &body body)
  "[Cyc] Execute BODY only when *defn-trace-level* >= LEVEL."
  `(when (>= *defn-trace-level* ,level)
     ,@body))

;; Reconstructed from $list76, $sym2$CUNWIND_PROTECT, $list77.
;; Binds *gather-at-constraints?* to t, with unwind-protect to clear hash tables.
(defmacro gathering-at-constraints (&body body)
  "[Cyc] Execute BODY gathering AT constraints, clearing constraint tables on exit."
  `(let ((*gather-at-constraints?* t))
     (unwind-protect
          (progn ,@body)
       (clrhash *at-isa-constraints*)
       (clrhash *at-genl-constraints*))))

;; Reconstructed from $list78, $sym2$CUNWIND_PROTECT, $list79.
(defmacro gathering-at-assertions (&body body)
  "[Cyc] Execute BODY gathering AT assertions, clearing assertion tables on exit."
  `(let ((*gather-at-assertions?* t))
     (unwind-protect
          (progn ,@body)
       (clrhash *at-isa-assertions*)
       (clrhash *at-genl-assertions*))))

;; Reconstructed from $list80. Binds *gather-at-format-violations?* to t
;; and *at-format-violations* (implicit nil via clet).
(defmacro gathering-at-format-violations (&body body)
  "[Cyc] Execute BODY gathering AT format violations."
  `(let ((*gather-at-format-violations?* t)
         (*at-format-violations* nil))
     ,@body))

;; Reconstructed from $list81.
(defmacro gathering-at-different-violations (&body body)
  "[Cyc] Execute BODY gathering AT different violations."
  `(let ((*gather-at-different-violations?* t)
         (*at-different-violations* nil))
     ,@body))

;; Reconstructed from $list82.
(defmacro gathering-at-predicate-violations (&body body)
  "[Cyc] Execute BODY gathering AT predicate violations."
  `(let ((*gather-at-predicate-violations?* t)
         (*at-predicate-violations* nil))
     ,@body))

;; Reconstructed from $sym83$CCATCH_IGNORE, $kw84, $list85.
;; Catches :at-mapping-done to allow early exit from mapping.
(defmacro until-at-mapping-finished (&body body)
  "[Cyc] Execute BODY within AT mapping context, catching :at-mapping-done for early exit."
  `(let ((*within-at-mapping?* t))
     (catch :at-mapping-done
       ,@body)))

;; Reconstructed from $list86, $sym87$SYMBOLP, $sym88$QUOTE, $sym89$CPUSHNEW, $list90.
(defmacro declare-collection-specific-defn (symbol)
  "[Cyc] Register SYMBOL as a collection-specific defn."
  `(progn
     (check-type ,symbol symbol)
     (pushnew ',symbol *at-collection-specific-defns*)))

;; Reconstructed from $list91, $str92-$sym127 and verified against actual expansions
;; in at_defns.java and defns.java (setup_at_defns_file lines 2057-2076, function
;; bodies lines 237-268).
;;
;; Generates: defparameter *NAME-METERS* (metering cache hash table),
;;   NAME-METERED (plain body, no metering), RESET-NAME-METERS (resets all meter keys),
;;   NAME (dispatch: if *defn-meters?*, time the call and record; else call directly).
;; Setup phase: register as defn state var, call reset, store :reset key,
;;   clean old caches, push onto *defn-meter-caches*.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun lambda-list-param-names (lambda-list)
    "Extract just the parameter variable names from a lambda list,
stripping &optional, &key, &rest, and default value forms."
    (loop for item in lambda-list
          unless (member item lambda-list-keywords)
          collect (if (consp item) (car item) item))))

(defmacro define-defn-metered (name (&rest arg-list) &body body)
  "[Cyc] Define a metered defn function NAME with metering cache and reset/metered/outer functions."
  (let* ((meters-var (intern (format nil "*~a-METERS*" name)))
         (metered-name (intern (format nil "~a-METERED" name)))
         (reset-name (intern (format nil "RESET-~a-METERS" name)))
         ;; Extract bare parameter names for call sites and :arg-list storage.
         ;; The full arg-list (with &optional, defaults) is used in defun lambda lists.
         (param-names (lambda-list-param-names arg-list)))
    `(progn
       ;; Init phase: create the metering cache
       (def-defn-state-var ,meters-var (make-hash-table :size 8)
         ,(format nil "metering cache for calls to defn module function ~a" name))
       ;; The metered function contains the plain body — no metering logic
       (defun ,metered-name (,@arg-list)
         ,@body)
       ;; Reset function: sets all meter keys to initial values
       (defun ,reset-name ()
         (setf (gethash :calls ,meters-var) 0)
         (setf (gethash :times ,meters-var) nil)
         (setf (gethash :results ,meters-var) nil)
         (setf (gethash :args ,meters-var) nil)
         (setf (gethash :arg-list ,meters-var) ',param-names)
         (setf (gethash :function ,meters-var) ',name)
         nil)
       ;; Outer dispatch function: meters if *defn-meters?*, else calls directly
       (defun ,name (,@arg-list)
         (if *defn-meters?*
             (let ((result nil)
                   (run-time nil))
               (let ((time-var (get-internal-real-time)))
                 (setf result (,metered-name ,@param-names))
                 (setf run-time (/ (- (get-internal-real-time) time-var)
                                   internal-time-units-per-second)))
               (setf (gethash :calls ,meters-var)
                     (1+ (gethash :calls ,meters-var)))
               (setf (gethash :times ,meters-var)
                     (cons run-time (gethash :times ,meters-var)))
               (setf (gethash :results ,meters-var)
                     (cons result (gethash :results ,meters-var)))
               (setf (gethash :args ,meters-var)
                     (cons (list ,@param-names) (gethash :args ,meters-var)))
               result)
             (,metered-name ,@param-names)))
       ;; Setup phase: initialize meters, clean old caches, register
       (toplevel
         (,reset-name)
         (setf (gethash :reset ,meters-var) ',reset-name)
         (dolist (cache *defn-meter-caches*)
           (when (eq ',name (gethash :function cache))
             (setf *defn-meter-caches* (delete cache *defn-meter-caches*))
             (clrhash cache)))
         (push ,meters-var *defn-meter-caches*)))))

;; Reconstructed from $list128, $list129, $kw130, $kw131, $sym132-$sym134.
;; Iterates over all top-level arg constraints for FORMULA.
;; NOTE: Neither this macro nor do-all-arg-constraints-inside-out are expanded
;; anywhere in LarKC. Their helper functions (dtlac-list-generator,
;; daacio-list-generator) have no bodies and no call sites in the Java codebase,
;; so these macros are effectively dead code in LarKC.
(defmacro do-all-top-level-arg-constraints ((constraint-var formula &key done-var)
                                            &body body)
  "[Cyc] Iterate CONSTRAINT-VAR over all top-level arg constraints of FORMULA."
  (with-temp-vars (all-arg-constraints)
    `(let ((,all-arg-constraints (dtlac-list-generator ,formula)))
       (csome (,constraint-var ,all-arg-constraints ,done-var)
         ,@body))))

;; dtlac = do top level arg constraints
;; (defun dtlac-list-generator (formula) ...) -- active declaration, no body

;; Reconstructed from $sym136, $const137, $sym138-$sym140.
;; Like do-all-top-level-arg-constraints but works inside-out with EverythingPSC mt.
(defmacro do-all-arg-constraints-inside-out ((constraint-var formula &key done-var)
                                             &body body)
  "[Cyc] Iterate CONSTRAINT-VAR over all arg constraints of FORMULA inside-out."
  (with-temp-vars (all-arg-constraints)
    `(let ((*relevant-mt-function* #'relevant-mt-is-everything)
           (*mt* #$EverythingPSC))
       (let ((,all-arg-constraints (daacio-list-generator ,formula)))
         (csome (,constraint-var ,all-arg-constraints ,done-var)
           ,@body)))))

;; daacio = do arg constraints inside out
;; (defun daacio-list-generator (formula) ...) -- active declaration, no body

;; Reconstructed from $list141.
(defmacro gather-wff-violations (&body body)
  "[Cyc] Execute BODY with AT and WFF violation gathering enabled."
  `(let ((*noting-at-violations?* t)
         (*accumulating-at-violations?* t)
         (*noting-wff-violations?* t)
         (*accumulating-wff-violations?* t))
     ,@body))

;; Reconstructed from $list142. Binds all four violation vars to nil.
(defmacro dont-gather-wff-violations (&body body)
  "[Cyc] Execute BODY with AT and WFF violation gathering disabled."
  `(let ((*noting-at-violations?* nil)
         (*accumulating-at-violations?* nil)
         (*noting-wff-violations?* nil)
         (*accumulating-wff-violations?* nil))
     ,@body))

;; Reconstructed from $list143. Like dont-gather-wff-violations but also disables suggestions.
(defmacro dont-gather-wff-violations-or-suggestions (&body body)
  "[Cyc] Execute BODY with AT/WFF violation gathering and suggestions disabled."
  `(let ((*noting-at-violations?* nil)
         (*accumulating-at-violations?* nil)
         (*noting-wff-violations?* nil)
         (*accumulating-wff-violations?* nil)
         (*provide-wff-suggestions?* nil))
     ,@body))

;; Setup phase — register macro helpers
(toplevel
  (register-macro-helper 'make-defn-fn-history-table 'with-new-defn-space)
  (register-macro-helper 'make-quoted-defn-fn-history-table 'with-new-defn-space)
  (register-macro-helper 'make-defn-col-history-table 'with-new-defn-space)
  (register-macro-helper 'make-quoted-defn-col-history-table 'with-new-defn-space)
  (register-macro-helper 'possibly-make-defn-fn-history-table 'with-possibly-new-defn-space)
  (register-macro-helper 'possibly-make-quoted-defn-fn-history-table 'with-possibly-new-defn-space)
  (register-macro-helper 'possibly-make-defn-col-history-table 'with-possibly-new-defn-space)
  (register-macro-helper 'possibly-make-quoted-defn-col-history-table 'with-possibly-new-defn-space)
  (register-macro-helper 'dtlac-list-generator 'do-all-top-level-arg-constraints)
  (register-macro-helper 'daacio-list-generator 'do-all-arg-constraints-inside-out))
