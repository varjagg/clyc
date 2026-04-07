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


;; Functions ordered per declare_bookkeeping_store_file section.

(defun bookkeeping-predicate-hl-storage-module-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] Applicability test for bookkeeping predicate HL storage modules."
  (declare (ignore argument-spec direction variable-map))
  (when (pos-atomic-cnf-p cnf)
    (let ((asent (gaf-cnf-literal cnf)))
      (when (el-binary-formula-p asent)
        (when (null (sequence-term asent))
          (when (hlmt-equal mt #$BookkeepingMt)
            t))))))

;; (defun bookkeeping-predicate-hl-storage-module-incompleteness (argument-spec cnf mt direction variable-map) ...) -- active declareFunction, no body

(defun bookkeeping-predicate-hl-storage-module-assert (argument-spec cnf mt direction variable-map)
  "[Cyc] Assert handler for bookkeeping predicate HL storage modules."
  (declare (ignore argument-spec direction variable-map))
  (let* ((asent (gaf-cnf-literal cnf))
         (pred (atomic-sentence-predicate asent))
         (arg1 (sentence-arg1 asent))
         (arg2 (sentence-arg2 asent)))
    (hl-assert-bookkeeping-binary-gaf pred arg1 arg2 mt)))

;; (defun bookkeeping-predicate-hl-storage-module-unassert (argument-spec cnf mt) ...) -- active declareFunction, no body

(defun my-creator-hl-storage-module-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] Applicability test for myCreator HL storage module."
  (when (bookkeeping-predicate-hl-storage-module-applicable? argument-spec cnf mt direction variable-map)
    (let ((asent (gaf-cnf-literal cnf)))
      (pattern-matches-formula '(#$myCreator :fort :fort) asent))))

(defun my-creation-time-hl-storage-module-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] Applicability test for myCreationTime HL storage module."
  (when (bookkeeping-predicate-hl-storage-module-applicable? argument-spec cnf mt direction variable-map)
    (let ((asent (gaf-cnf-literal cnf)))
      (pattern-matches-formula '(#$myCreationTime :fort (:test universal-date-p)) asent))))

(defun my-creation-purpose-hl-storage-module-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] Applicability test for myCreationPurpose HL storage module."
  (when (bookkeeping-predicate-hl-storage-module-applicable? argument-spec cnf mt direction variable-map)
    (let ((asent (gaf-cnf-literal cnf)))
      (pattern-matches-formula '(#$myCreationPurpose :fort :fort) asent))))

(defun my-creation-second-hl-storage-module-applicable? (argument-spec cnf mt direction variable-map)
  "[Cyc] Applicability test for myCreationSecond HL storage module."
  (when (bookkeeping-predicate-hl-storage-module-applicable? argument-spec cnf mt direction variable-map)
    (let ((asent (gaf-cnf-literal cnf)))
      (pattern-matches-formula '(#$myCreationSecond :fort (:test universal-second-p)) asent))))

;; Reconstructed macro from Internal Constants evidence:
;; $list24 = ((KEY SUBINDEX TOP-INDEX) &BODY BODY) -> arglist
;; $sym25$DO_ALIST -> expands to do-alist
;; $list26 = (PRED . SUBINDEX) -> destructuring pattern
(defmacro do-bookkeeping-top-level-index ((key subindex top-index) &body body)
  "[Cyc] Iterate over a bookkeeping top-level index."
  `(do-alist (,key ,subindex ,top-index)
     ,@body))

;; (defun bookkeeping-predicates-for-hl-store () ...) -- active declareFunction, no body

(defun arg2-indexed-bookkeeping-predicates-for-hl-store ()
  "[Cyc] Return a copy of the arg2-indexed bookkeeping predicates list."
  (copy-list *arg2-indexed-bookkeeping-predicates-for-hl-store*))

(defun arg2-indexed-bookkeeping-pred? (pred)
  "[Cyc] Return whether PRED is an arg2-indexed bookkeeping predicate."
  (member? pred (arg2-indexed-bookkeeping-predicates-for-hl-store)))

(defun new-bookkeeping-top-level-index (top-level-keys)
  "[Cyc] Create a new bookkeeping top-level index with the given keys."
  (let ((top-index nil))
    (dolist (key top-level-keys)
      (let ((value (new-bookkeeping-intermediate-index)))
        (push (cons key value) top-index)))
    (nreverse top-index)))

(defun bookkeeping-top-level-index-lookup (index key)
  "[Cyc] Look up KEY in a bookkeeping top-level INDEX."
  (cdr (assoc key index)))

(defun bookkeeping-top-level-index-insert (index top-key mid-key leaf single-entry?)
  "[Cyc] Insert a LEAF at MID-KEY under TOP-KEY in a bookkeeping top-level INDEX."
  (let ((intermediate-index (bookkeeping-top-level-index-lookup index top-key)))
    (bookkeeping-intermediate-index-insert intermediate-index mid-key leaf single-entry?)))

;; (defun bookkeeping-top-level-index-delete (index top-key mid-key leaf single-entry?) ...) -- active declareFunction, no body

(defun bookkeeping-top-level-index-count (index)
  "[Cyc] Count the total entries across all sub-indexes of a bookkeeping top-level INDEX."
  (let ((count 0))
    (dolist (cons index)
      (destructuring-bind (pred . subindex) cons
        (declare (ignore pred))
        (setf count (+ count (bookkeeping-intermediate-index-count subindex)))))
    count))

;; Reconstructed macro from Internal Constants evidence:
;; $list27 = ((KEY VALUE INDEX) &BODY BODY) -> arglist
;; $sym28$DO_DICTIONARY -> expands to do-dictionary
(defmacro do-bookkeeping-intermediate-index ((key value index) &body body)
  "[Cyc] Iterate over a bookkeeping intermediate index (dictionary)."
  `(do-dictionary (,key ,value ,index)
     ,@body))

(defun new-bookkeeping-intermediate-index ()
  "[Cyc] Create a new bookkeeping intermediate index."
  (make-hash-table :test #'eq))

(defun bookkeeping-intermediate-index-lookup (index key)
  "[Cyc] Look up KEY in a bookkeeping intermediate INDEX."
  (gethash key index))

;; (defun bookkeeping-intermediate-index-num-keys (index) ...) -- active declareFunction, no body

(defun bookkeeping-intermediate-index-set (index key value)
  "[Cyc] Set KEY to VALUE in a bookkeeping intermediate INDEX."
  (setf (gethash key index) value))

(defun bookkeeping-intermediate-index-push (index key value)
  "[Cyc] Push VALUE into the set at KEY in a bookkeeping intermediate INDEX."
  (let ((v-set (bookkeeping-intermediate-index-lookup index key)))
    (when (null v-set)
      (setf v-set (new-set)))
    (set-add value v-set)
    (setf (gethash key index) v-set)
    t))

;; (defun bookkeeping-intermediate-index-delete-key (index key) ...) -- active declareFunction, no body

(defun bookkeeping-intermediate-index-insert (index key value single-entry?)
  "[Cyc] Insert VALUE at KEY in a bookkeeping intermediate INDEX.
If SINGLE-ENTRY? is non-nil, set the value directly; otherwise push into a set."
  (if single-entry?
      (bookkeeping-intermediate-index-set index key value)
      (bookkeeping-intermediate-index-push index key value)))

;; (defun bookkeeping-intermediate-index-delete (index key value single-entry?) ...) -- active declareFunction, no body

(defun bookkeeping-intermediate-index-count (index)
  "[Cyc] Count the number of entries in a bookkeeping intermediate INDEX."
  (hash-table-count index))


;;; Variables

(deflexical *bookkeeping-predicates-for-hl-store*
    (list #$myCreator #$myCreationPurpose #$myCreationTime #$myCreationSecond))

(deflexical *arg2-indexed-bookkeeping-predicates-for-hl-store*
    (list #$myCreator #$myCreationPurpose))

(defglobal *bookkeeping-binary-gaf-store*
    (new-bookkeeping-top-level-index *bookkeeping-predicates-for-hl-store*)
  "[Cyc] An index for bookkeeping binary gafs: pred -> arg1 -> arg2
This index also serves as the store for these bookkeeping assertions.")

(defglobal *bookkeeping-binary-gaf-arg2-index*
    (new-bookkeeping-top-level-index *arg2-indexed-bookkeeping-predicates-for-hl-store*)
  "[Cyc] An index for bookkeeping binary gafs: pred -> arg2 -> list of arg1s")


;;; More functions (continued from declare section)

(defun clear-bookkeeping-binary-gaf-store ()
  "[Cyc] Clear and reinitialize the bookkeeping binary GAF store."
  (setf *bookkeeping-binary-gaf-store*
        (new-bookkeeping-top-level-index *bookkeeping-predicates-for-hl-store*))
  nil)

;; (defun dumper-num-top-level-index () ...) -- active declareFunction, no body

;; Reconstructed macro from Internal Constants evidence:
;; $list31 = ((PRED SUBINDEX) &BODY BODY) -> arglist
;; $sym32$DO_BOOKKEEPING_TOP_LEVEL_INDEX -> expands to do-bookkeeping-top-level-index
;; $list33 = ((DUMPER-BOOKKEEPING-BINARY-GAF-STORE)) -> wrapped call
(defmacro dumper-do-bookkeeping-top-level-index ((pred subindex) &body body)
  "[Cyc] Iterate over the dumper bookkeeping top-level index."
  `(do-bookkeeping-top-level-index (,pred ,subindex (dumper-bookkeeping-binary-gaf-store))
     ,@body))

;; (defun dumper-num-intermediate-index (index) ...) -- active declareFunction, no body

;; Reconstructed macro from Internal Constants evidence:
;; $list34 = ((ARG1 ARG2 INDEX) &BODY BODY) -> arglist
;; $sym35$DO_BOOKKEEPING_INTERMEDIATE_INDEX -> expands to do-bookkeeping-intermediate-index
(defmacro dumper-do-bookkeeping-intermediate-index ((arg1 arg2 index) &body body)
  "[Cyc] Iterate over a dumper bookkeeping intermediate index."
  `(do-bookkeeping-intermediate-index (,arg1 ,arg2 ,index)
     ,@body))

;; (defun dumper-bookkeeping-binary-gaf-store () ...) -- active declareFunction, no body

(defun dumper-clear-bookkeeping-binary-gaf-store ()
  "[Cyc] Clear the dumper bookkeeping binary GAF store."
  (clear-bookkeeping-binary-gaf-store))

(defun dumper-load-bookkeeping-binary-gaf (pred arg1 arg2)
  "[Cyc] Load a bookkeeping binary GAF during dump loading."
  (assert-bookkeeping-binary-gaf-int pred arg1 arg2))

;; (defun dumper-dumpable-bookkeeping-index () ...) -- active declareFunction, no body

(defun dumper-load-bookkeeping-index (index)
  "[Cyc] Load a bookkeeping arg2 index during dump loading."
  (setf *bookkeeping-binary-gaf-arg2-index* index)
  nil)

(defun bookkeeping-binary-gaf-store ()
  "[Cyc] Return the bookkeeping binary GAF store."
  *bookkeeping-binary-gaf-store*)

(defun bookkeeping-binary-gaf-arg2-index ()
  "[Cyc] Return the bookkeeping binary GAF arg2 index."
  *bookkeeping-binary-gaf-arg2-index*)

(defun assert-bookkeeping-binary-gaf (pred arg1 arg2 mt)
  "[Cyc] Assert a bookkeeping binary GAF."
  (when (null (hlmt-equal mt #$BookkeepingMt))
    (return-from assert-bookkeeping-binary-gaf nil))
  (let ((old-value (bookkeeping-fpred-value pred arg1)))
    (when (and old-value
               (not (equal arg2 old-value)))
      (return-from assert-bookkeeping-binary-gaf nil)))
  (and (assert-bookkeeping-binary-gaf-int pred arg1 arg2)
       (add-bookkeeping-binary-gaf-indices pred arg1 arg2)
       t))

(defun assert-bookkeeping-binary-gaf-int (pred arg1 arg2)
  "[Cyc] Internal: insert a bookkeeping binary GAF into the store."
  (bookkeeping-top-level-index-insert (bookkeeping-binary-gaf-store) pred arg1 arg2 t))

(defun add-bookkeeping-binary-gaf-indices (pred arg1 arg2)
  "[Cyc] Add bookkeeping binary GAF indices for arg2 lookups."
  (and (or (not (arg2-indexed-bookkeeping-pred? pred))
           (bookkeeping-top-level-index-insert (bookkeeping-binary-gaf-arg2-index) pred arg2 arg1 nil))
       t))

;; (defun unassert-bookkeeping-binary-gaf (pred arg1 arg2 mt) ...) -- active declareFunction, no body

;; (defun unassert-bookkeeping-binary-gaf-int (pred arg1 arg2) ...) -- active declareFunction, no body

;; (defun remove-bookkeeping-binary-gaf-indices (pred arg1 arg2) ...) -- active declareFunction, no body

(defun unassert-all-bookkeeping-gafs-on-term (v-term)
  "[Cyc] Unassert all bookkeeping GAFs involving TERM."
  (let ((success? t))
    (dolist (cons (bookkeeping-binary-gaf-store))
      (destructuring-bind (pred . subindex) cons
        (declare (ignore pred))
        (let ((arg2 (bookkeeping-intermediate-index-lookup subindex v-term)))
          (when arg2
            (when (null (missing-larkc 31828))
              (setf success? nil))))))
    (let ((created-terms (terms-created-by v-term)))
      (dolist (created-term created-terms)
        (declare (ignore created-term))
        (when (null (missing-larkc 31829))
          (setf success? nil))))
    (let ((created-terms (terms-created-for v-term)))
      (dolist (created-term created-terms)
        (declare (ignore created-term))
        (when (null (missing-larkc 31830))
          (setf success? nil))))
    success?))

;; (defun unassert-all-bookkeeping-gafs-for-pred (pred) ...) -- active declareFunction, no body

;; (defun creator (fort &optional (mt #$BookkeepingMt)) ...) -- active declareFunction, no body

;; (defun creation-time (fort &optional (mt #$BookkeepingMt)) ...) -- active declareFunction, no body

;; (defun creation-date (fort &optional (mt #$BookkeepingMt)) ...) -- active declareFunction, no body

;; (defun creation-purpose (fort &optional (mt #$BookkeepingMt)) ...) -- active declareFunction, no body

;; (defun creation-second (fort &optional (mt #$BookkeepingMt)) ...) -- active declareFunction, no body

;; (defun created-when (fort &optional (mt #$BookkeepingMt)) ...) -- active declareFunction, no body

;; (defun creation-date-cycl (fort) ...) -- active declareFunction, no body

(defun terms-created-by (cyclist &optional (mt #$BookkeepingMt))
  "[Cyc] Return terms created by CYCLIST."
  (bookkeeping-arg1-pred-values #$myCreator cyclist mt))

(defun terms-created-for (purpose &optional (mt #$BookkeepingMt))
  "[Cyc] Return terms created for PURPOSE."
  (bookkeeping-arg1-pred-values #$myCreationPurpose purpose mt))

;; (defun num-terms-created-by (cyclist &optional (mt #$BookkeepingMt)) ...) -- active declareFunction, no body

;; (defun num-terms-created-for (purpose &optional (mt #$BookkeepingMt)) ...) -- active declareFunction, no body

;; (defun bookkeeping-asents-on-term (v-term) ...) -- active declareFunction, no body

;; (defun bookkeeping-assertibles-on-term (v-term) ...) -- active declareFunction, no body

;; (defun bookkeeping-hl-assertion-specs-on-term (v-term) ...) -- active declareFunction, no body

;; (defun bookkeeping-hl-assertibles-on-term (v-term) ...) -- active declareFunction, no body

;; (defun bookkeeping-asent-to-hl-assertion-spec (asent) ...) -- active declareFunction, no body

;; (defun bookkeeping-asent-to-hl-assertible (asent) ...) -- active declareFunction, no body

(defun bookkeeping-assertion-count ()
  "[Cyc] Return the total number of bookkeeping assertions."
  (bookkeeping-top-level-index-count (bookkeeping-binary-gaf-store)))

;; (defun num-bookkeeping-binary-gafs-on-term (v-term) ...) -- active declareFunction, no body

;; (defun any-bookkeeping-assertions-on-term? (v-term) ...) -- active declareFunction, no body

;; Reconstructed macro from Internal Constants evidence:
;; $list49 = ((PRED ARG1 ARG2) &BODY BODY) -> arglist
;; $sym50$SUBINDEX (unintern) -> gensym for subindex
;; $list51 = ((BOOKKEEPING-BINARY-GAF-STORE)) -> wrapped call
;; $sym32$DO_BOOKKEEPING_TOP_LEVEL_INDEX -> uses do-bookkeeping-top-level-index
;; $sym35$DO_BOOKKEEPING_INTERMEDIATE_INDEX -> uses do-bookkeeping-intermediate-index
(defmacro do-bookkeeping-assertions ((pred arg1 arg2) &body body)
  "[Cyc] Iterate over all bookkeeping assertions, binding PRED, ARG1, and ARG2."
  (let ((subindex (gensym "SUBINDEX")))
    `(do-bookkeeping-top-level-index (,pred ,subindex (bookkeeping-binary-gaf-store))
       (do-bookkeeping-intermediate-index (,arg1 ,arg2 ,subindex)
         ,@body))))

;; Reconstructed macro from Internal Constants evidence:
;; $list52 = ((ASENT) &BODY BODY) -> arglist
;; $sym53-56 (unintern) SUBINDEX, PRED, ARG1, ARG2 -> gensyms
;; $sym57$CLET -> let binding
;; $sym58$MAKE_BINARY_FORMULA -> (make-binary-formula pred arg1 arg2)
;; Uses do-bookkeeping-assertions internally
(defmacro do-bookkeeping-asents ((asent) &body body)
  "[Cyc] Iterate over all bookkeeping asents, binding ASENT to each reconstructed formula."
  (let ((subindex (gensym "SUBINDEX"))
        (pred (gensym "PRED"))
        (arg1 (gensym "ARG1"))
        (arg2 (gensym "ARG2")))
    `(do-bookkeeping-top-level-index (,pred ,subindex (bookkeeping-binary-gaf-store))
       (do-bookkeeping-intermediate-index (,arg1 ,arg2 ,subindex)
         (let ((,asent (make-binary-formula ,pred ,arg1 ,arg2)))
           ,@body)))))

;; (defun total-num-assertions-on-term (v-term) ...) -- active declareFunction, no body

;; (defun bookkeeping-asent-truth (asent) ...) -- active declareFunction, no body

;; (defun bookkeeping-assertion-truth (pred arg1 arg2) ...) -- active declareFunction, no body

;; (defun indexed-terms-mentioned-in-bookkeeping-assertions-of-term (v-term) ...) -- active declareFunction, no body

;; (defun why-not-bookkeeping-asent (asent) ...) -- active declareFunction, no body

(defun bookkeeping-fpred-value (pred arg1 &optional (mt #$BookkeepingMt))
  "[Cyc] Look up the functional predicate value for PRED and ARG1."
  (if (hlmt-equal mt #$BookkeepingMt)
      (bookkeeping-fpred-value-int pred arg1)
      (missing-larkc 30009)))

(defun bookkeeping-fpred-value-int (pred arg1)
  "[Cyc] Internal: look up functional predicate value in the store."
  (let ((arg1-subindex (bookkeeping-top-level-index-lookup (bookkeeping-binary-gaf-store) pred)))
    (when arg1-subindex
      (bookkeeping-intermediate-index-lookup arg1-subindex arg1))))

(defun bookkeeping-arg1-pred-values (pred arg2 &optional (mt #$BookkeepingMt))
  "[Cyc] Look up arg1 values for PRED and ARG2."
  (if (hlmt-equal mt #$BookkeepingMt)
      (bookkeeping-arg1-pred-values-int pred arg2)
      (missing-larkc 30033)))

(defun bookkeeping-arg1-pred-values-int (pred arg2)
  "[Cyc] Internal: look up arg1 values in the arg2 index."
  (let ((arg2-subindex (bookkeeping-top-level-index-lookup (bookkeeping-binary-gaf-arg2-index) pred)))
    (when arg2-subindex
      (let ((arg1-set (bookkeeping-intermediate-index-lookup arg2-subindex arg2)))
        (when arg1-set
          (set-element-list arg1-set))))))

;; (defun bookkeeping-arg1-assertion-count (pred arg2 &optional (mt #$BookkeepingMt)) ...) -- active declareFunction, no body

;; (defun bookkeeping-arg1-assertion-count-int (pred arg2) ...) -- active declareFunction, no body

;; (defun reindex-all-bookkeeping-assertions () ...) -- active declareFunction, no body

;; (defun reindex-all-bookkeeping-assertions-for-pred (pred) ...) -- active declareFunction, no body


;;; Setup

(toplevel
  (register-solely-specific-hl-storage-module-predicate #$myCreator)
  (hl-storage-module :my-creator
                     (list :pretty-name "myCreator"
                           :argument-type :asserted-argument
                           :predicate #$myCreator
                           :applicability 'my-creator-hl-storage-module-applicable?
                           :incompleteness 'bookkeeping-predicate-hl-storage-module-incompleteness
                           :add 'bookkeeping-predicate-hl-storage-module-assert
                           :remove 'bookkeeping-predicate-hl-storage-module-unassert
                           :remove-all 'bookkeeping-predicate-hl-storage-module-unassert))
  (register-solely-specific-hl-storage-module-predicate #$myCreationTime)
  (hl-storage-module :my-creation-time
                     (list :pretty-name "myCreationTime"
                           :argument-type :asserted-argument
                           :predicate #$myCreationTime
                           :applicability 'my-creation-time-hl-storage-module-applicable?
                           :incompleteness 'bookkeeping-predicate-hl-storage-module-incompleteness
                           :add 'bookkeeping-predicate-hl-storage-module-assert
                           :remove 'bookkeeping-predicate-hl-storage-module-unassert
                           :remove-all 'bookkeeping-predicate-hl-storage-module-unassert))
  (register-solely-specific-hl-storage-module-predicate #$myCreationPurpose)
  (hl-storage-module :my-creation-purpose
                     (list :pretty-name "myCreationPurpose"
                           :argument-type :asserted-argument
                           :predicate #$myCreationPurpose
                           :applicability 'my-creation-purpose-hl-storage-module-applicable?
                           :incompleteness 'bookkeeping-predicate-hl-storage-module-incompleteness
                           :add 'bookkeeping-predicate-hl-storage-module-assert
                           :remove 'bookkeeping-predicate-hl-storage-module-unassert
                           :remove-all 'bookkeeping-predicate-hl-storage-module-unassert))
  (register-solely-specific-hl-storage-module-predicate #$myCreationSecond)
  (hl-storage-module :my-creation-second
                     (list :pretty-name "myCreationSecond"
                           :argument-type :asserted-argument
                           :predicate #$myCreationSecond
                           :applicability 'my-creation-second-hl-storage-module-applicable?
                           :incompleteness 'bookkeeping-predicate-hl-storage-module-incompleteness
                           :add 'bookkeeping-predicate-hl-storage-module-assert
                           :remove 'bookkeeping-predicate-hl-storage-module-unassert
                           :remove-all 'bookkeeping-predicate-hl-storage-module-unassert))
  (declare-defglobal '*bookkeeping-binary-gaf-store*)
  (declare-defglobal '*bookkeeping-binary-gaf-arg2-index*)
  (register-cyc-api-function 'creator
                             '(fort &optional (mt #$BookkeepingMt))
                             "Identify the cyclist who created FORT."
                             '((fort fort-p) (mt hlmt-p))
                             '(fort-p))
  (register-cyc-api-function 'creation-time
                             '(fort &optional (mt #$BookkeepingMt))
                             "Identify when FORT was created."
                             '((fort fort-p) (mt hlmt-p))
                             '(integerp)))
