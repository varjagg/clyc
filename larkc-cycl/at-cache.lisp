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

(defglobal *arg-type-cache* (make-hash-table :size 1024)
  "[Cyc]
  relation -> argnum -> col -> mts
           |         |      |
           hash      list   alist")

(deflexical *arg-type-cache-preds* (list #$arg1Isa #$arg2Isa #$arg3Isa
                                         #$arg4Isa #$arg5Isa #$arg6Isa)
  "[Cyc] The predicates that are used to build the arg-type cache, in ascending numerical order.")

(deflexical *arg-type-cache-preds-reversed* (reverse *arg-type-cache-preds*))

(defglobal *arg-type-cache-initialized?* nil)

;; Functions, in declare section order:

(defun arg-type-cached-pred-p (object)
  "[Cyc] Return whether OBJECT is a predicate used in the arg-type cache."
  (member? object *arg-type-cache-preds*))

(defun some-args-isa-assertion-somewhere? (relation)
  "[Cyc] Return whether there is some #$argsIsa assertion somewhere for RELATION."
  (some-pred-assertion-somewhere? #$argsIsa relation 1))

(defun some-arg-and-rest-isa-assertion-somewhere? (relation)
  "[Cyc] Return whether there is some #$argAndRestIsa assertion somewhere for RELATION."
  (some-pred-assertion-somewhere? #$argAndRestIsa relation 1))

(defun cached-arg-isas-in-mt (relation argnum &optional mt)
  "[Cyc] Return the cached arg-isa constraints for RELATION at ARGNUM in MT."
  (let ((mt-var mt))
    (let ((*mt* (update-inference-mt-relevance-mt mt-var))
          (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
          (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
      (cached-arg-isas-in-relevant-mts relation argnum))))

(defun cached-arg-isas-in-relevant-mts (relation argnum)
  "[Cyc] Return the cached arg-isa constraints for RELATION at ARGNUM in relevant mts."
  (let* ((argnum-table (at-cache-lookup-argnum-table relation))
         (collection-table (nth (1- argnum) argnum-table)))
    (at-cache-relevant-collections collection-table)))

(defun at-cache-relevant-collections (collection-table)
  "[Cyc] Filter COLLECTION-TABLE to only those collections relevant in the current mt context."
  (let ((cols nil))
    (if (not (fort-p collection-table))
        ;; collection-table is a list of entries
        (dolist (entry collection-table)
          (if (not (fort-p entry))
              ;; entry is (col . mts)
              (destructuring-bind (col &rest mts) entry
                (let ((relevant-col nil))
                  (dolist (mt mts)
                    (when (and (not relevant-col)
                               (relevant-mt? mt))
                      (setf relevant-col col)))
                  (when relevant-col
                    (push relevant-col cols))))
              ;; entry is a bare fort (col in UniversalVocabularyMt)
              (let ((col entry))
                (when (relevant-mt? #$UniversalVocabularyMt)
                  (push col cols)))))
        ;; collection-table is a single fort
        (let ((col collection-table))
          (when (relevant-mt? #$UniversalVocabularyMt)
            (push col cols))))
    (nreverse cols)))

(defun at-cache-lookup-argnum-table (relation)
  "[Cyc] Look up the argnum table for RELATION in the arg-type cache."
  (gethash relation *arg-type-cache*))

;; (defun initialize-at-cache () ...) -- active declareFunction, no body

(defun at-cache-use-possible? (constraint-pred argnum)
  "[Cyc] Return whether the arg-type cache can be used for CONSTRAINT-PRED at ARGNUM."
  (and *arg-type-cache-initialized?*
       (arg-type-cached-argnum-p argnum)
       (arg-type-cached-pred-p constraint-pred)))

(defun arg-type-cached-argnum-p (object)
  "[Cyc] Return whether OBJECT is a valid argnum for the arg-type cache (1-6)."
  (and (integerp object)
       (>= object 1)
       (<= object 6)))

(defun at-cache-initialize-relation (relation)
  "[Cyc] Initialize the arg-type cache entry for RELATION."
  (let* ((max-argnum (max-constrained-argnum relation))
         (argnum-table (at-cache-initialize-argnum-table relation max-argnum)))
    (at-cache-set-argnum-table relation argnum-table)
    argnum-table))

(defun at-cache-initialize-argnum-table (relation max-argnum)
  "[Cyc] Build the argnum table for RELATION, collecting constraints for each pred up to MAX-ARGNUM."
  (let ((argnum-list nil))
    (let ((*relevant-mt-function* 'relevant-mt-is-everything)
          (*mt* #$EverythingPSC))
      (dolist (constraint-pred *arg-type-cache-preds*)
        (let ((argnum (constrained-argnum constraint-pred)))
          (when (<= argnum max-argnum)
            (let ((col-alist (at-cache-initialize-collection-table relation constraint-pred)))
              (push col-alist argnum-list))))))
    (setf argnum-list (nreverse argnum-list))
    argnum-list))

(defun at-cache-initialize-collection-table (relation constraint-pred)
  "[Cyc] Build the collection table for RELATION and CONSTRAINT-PRED by iterating over GAF assertions."
  (let ((collection-alist nil))
    (do-gaf-arg-index (ass relation :predicate constraint-pred :truth :true)
      (when (assertion-still-there? ass :true)
        (let ((col (gaf-arg2 ass))
              (mt (assertion-mt ass)))
          (when (fort-p col)
            (setf collection-alist (alist-push collection-alist col mt #'eq))))))
    ;; Simplify entries where the only mt is UniversalVocabularyMt:
    ;; replace (col . (UniversalVocabularyMt)) with just col
    (do ((cons collection-alist (cdr cons)))
        ((atom cons))
      (let ((entry (car cons)))
        (when (not (fort-p entry))
          (destructuring-bind (col &rest mts) entry
            (when (and (singleton? mts)
                       (eq #$UniversalVocabularyMt (first mts)))
              (rplaca cons col))))))
    ;; If there's exactly one entry and it's a bare fort, unwrap the list
    (when (and (singleton? collection-alist)
               (fort-p (first collection-alist)))
      (setf collection-alist (first collection-alist)))
    collection-alist))

(defun at-cache-set-argnum-table (relation argnum-table)
  "[Cyc] Set the argnum table for RELATION in the arg-type cache."
  (setf (gethash relation *arg-type-cache*) argnum-table))

(defun max-constrained-argnum (relation)
  "[Cyc] Return the maximum constrained argnum for RELATION. 0 indicates no arg constraints."
  (let ((max-argnum nil))
    (dolist (constraint-pred *arg-type-cache-preds-reversed*)
      (do-gaf-arg-index (ass relation :predicate constraint-pred :done max-argnum)
        (setf max-argnum (constrained-argnum constraint-pred))))
    (or max-argnum 0)))

(defun constrained-argnum (constraint-pred)
  "[Cyc] Return the argnum constrained by CONSTRAINT-PRED."
  (isa-pred-arg constraint-pred))

(defun cyc-add-to-arg-type-cache (argument assertion)
  "[Cyc] Add ASSERTION to the arg-type cache."
  (declare (ignore argument))
  (cyc-update-arg-type-cache assertion))

(defun cyc-remove-from-arg-type-cache (argument assertion)
  "[Cyc] Remove ASSERTION from the arg-type cache."
  (declare (ignore argument))
  (cyc-update-arg-type-cache assertion))

(defun cyc-update-arg-type-cache (gaf)
  "[Cyc] Update the arg-type cache for the relation in GAF."
  (declare (type (satisfies gaf-assertion?) gaf))
  (let ((arg-isa-pred (gaf-predicate gaf)))
    (declare (type (satisfies arg-type-cached-pred-p) arg-isa-pred))
    (let ((relation (gaf-arg1 gaf)))
      (when (fort-p relation)
        (at-cache-initialize-relation relation)
        (return-from cyc-update-arg-type-cache t))))
  nil)

(defun note-at-cache-initialized ()
  "[Cyc] Note that the arg-type cache has been initialized."
  (setf *arg-type-cache-initialized?* t)
  t)

;; Setup
(toplevel
  (declare-defglobal '*arg-type-cache*)
  (declare-defglobal '*arg-type-cache-initialized?*)
  (register-kb-function 'cyc-add-to-arg-type-cache)
  (register-kb-function 'cyc-remove-from-arg-type-cache))
