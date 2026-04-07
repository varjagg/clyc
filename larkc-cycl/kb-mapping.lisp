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

;; TODO - all the gather-* functions cons up lists & deduplicate them.  A faster, less gc pressure way of iterating?

(defparameter *mapping-function* nil)
(defparameter *mapping-truth* nil)
(defparameter *mapping-direction* nil)

(defun map-nart-arg-index (subl-function term &optional argnum cycl-function)
  "Apply FUNCTION to each #$termOfUnit assertion whose arg2 is a naut which mentions TERM in position ARGNUM."
  (catch :mapping-done
    (cond
      ((and argnum cycl-function)
       ;; TODO - iteration macro
       (when (do-nart-arg-index-key-validator term argnum cycl-function)
         (let ((iterator-var (new-nart-arg-final-index-spec-iterator term argnum cycl-function))
               (done-var nil)
               (token-var nil))
           (until done-var
             (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                    (valid (not (eq token-var final-index-spec))))
               (when valid
                 (let ((final-index-iterator nil))
                   (unwind-protect (progn
                                     (setf final-index-iterator (new-final-index-iterator final-index-spec :gaf nil nil))
                                     (let ((done-var-25 nil)
                                           (token-var-26 nil))
                                       (until done-var-25
                                         (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-26))
                                                (valid-27 (not (eq token-var-26 ass))))
                                           (when valid-27
                                             (funcall subl-function ass))
                                           (setf done-var-25 (not valid-27))))))
                     (when final-index-iterator
                       (destroy-final-index-iterator final-index-iterator)))))
               (setf done-var (not valid)))))))

      ((and argnum (not cycl-function))
       (when (do-nart-arg-index-key-validator term argnum nil)
         (let ((iterator-var (new-nart-arg-final-index-spec-iterator term argnum nil))
               (done-var nil)
               (token-var nil))
           (until done-var
             (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                    (valid (not (eq token-var final-index-spec))))
               (when valid
                 (let ((final-index-iterator nil))
                   (unwind-protect (progn
                                     (setf final-index-iterator (new-final-index-iterator final-index-spec :gaf nil nil))
                                     (let ((done-var-28 nil)
                                           (token-var-29 nil))
                                       (until done-var-28
                                         (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-29))
                                                (valid-30 (not (eq token-var-29 ass))))
                                           (when valid-30
                                             (funcall subl-function ass))
                                           (setf done-var-28 (not valid-30))))))
                     (when final-index-iterator
                       (destroy-final-index-iterator final-index-iterator)))))
               (setf done-var (not valid)))))))

      ((and (not argnum) cycl-function)
       (when (do-nart-arg-index-key-validator term nil cycl-function)
         (let ((iterator-var (new-nart-arg-final-index-spec-iterator term nil cycl-function))
               (done-var nil)
               (token-var nil))
           (until done-var
             (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                    (valid (not (eq token-var final-index-spec))))
               (when valid
                 (let ((final-index-iterator (new-final-index-iterator final-index-spec :gaf nil nil)))
                   (unwind-protect (let ((done-var-31 nil)
                                         (token-var-32 nil))
                                     (until done-var-31
                                       (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-32))
                                              (valid-33 (not (eq token-var-32 ass))))
                                         (when valid-33
                                           (funcall subl-function ass))
                                         (setf done-var-31 (not valid-33)))))
                     (destroy-final-index-iterator final-index-iterator))))
               (setf done-var (not valid)))))))

      ((and (not argnum)
            (not cycl-function))
       (when (do-nart-arg-index-key-validator term nil nil)
         (let ((iterator-var (new-nart-arg-final-index-spec-iterator term nil nil))
               (done-var nil)
               (token-var nil))
           (until done-var
             (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                    (valid (not (eq token-var final-index-spec))))
               (when valid
                 (let ((final-index-iterator (new-final-index-iterator final-index-spec :gaf nil nil)))
                   (unwind-protect (let ((done-var-34 nil)
                                         (token-var-35 nil))
                                     (until done-var-34
                                       (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-35))
                                              (valid-36 (not (eq token-var-35 ass))))
                                         (when valid-36
                                           (funcall subl-function ass))
                                         (setf done-var-34 (not valid-36)))))
                     (destroy-final-index-iterator final-index-iterator))))
               (setf done-var (not valid))))))))))

(defun map-predicate-rule-index (function pred sense &optional direction mt)
  (catch :mapping-done
    (possibly-with-just-mt (mt)
      (if direction
          ;; TODO - macro helper instance
          (when (do-predicate-rule-index-key-validator pred sense direction)
            (let ((iterator-var (new-predicate-rule-final-index-spec-iterator pred sense direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator nil))
                      (unwind-protect (progn
                                        (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                                        (let ((done-var-37 nil)
                                              (token-var-38 nil))
                                          (until done-var-37
                                            ;; macro var
                                            (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-38))
                                                   (valid-39 (not (eq token-var-38 ass))))
                                              (when valid-39
                                                ;; macro body
                                                (funcall function ass))
                                              (setf done-var-37 (not valid-39))))))
                        (when final-index-iterator                          
                          (destroy-final-index-iterator final-index-iterator)))))
                  (setf done-var (not valid))))))
          ;; TODO - another macro helper instance, different iteration via direction decision above
          (when (do-predicate-rule-index-key-validator pred sense nil)
            (let ((iterator-var (new-predicate-rule-final-index-spec-iterator pred sense nil))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator nil))
                      (unwind-protect (progn
                                        (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil nil))
                                        (let ((done-var-41 nil)
                                              (token-var-42 nil))
                                          (until done-var-41
                                            (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-42))
                                                   (valid-43 (not (eq token-var-42 ass))))
                                              (when valid-43
                                                (funcall function ass))
                                              (setf done-var-41 (not valid-43))))))
                        (when final-index-iterator
                          (destroy-final-index-iterator final-index-iterator)))))
                  (setf done-var (not valid))))))))))

(defparameter *map-term-selective-test* nil)
(defparameter *map-term-selective-action* nil)

(defun map-mt-contents (function term &optional truth gafs-only)
  "[Cyc] Apply FUNCTION to each assertion with TRUTH in MT TERM.
If TRUTH is NIL, all assertions are mapped.
If GAFS-ONLY, then only gafs are mapped."

  (when (fort-p term)
    (if (broad-mt? term)
        (when (relevant-mt? term)
          (let ((*mapping-truth* truth))
            (catch :mapping-done
              ;; TODO - more macro expansion that isn't part of noting-percent-progress?  the totl & sofar seem to be part of calculating percentage?
              (let* ((idx (do-assertions-table))
                     (total (id-index-count idx))
                     (sofar 0))
                (noting-percent-progress ("mapping broad mt index")
                  ;; TODO - more macroexpansions, re gensym'd variables, but this is missing-larkc anyway
                  (let ((idx-120 idx))
                    (unless (id-index-objects-empty-p idx-120 :skip)
                      ;; peer 1 code, old objects?  this is an id-index structure
                      (let ((idx-121 idx-120))
                        (unless (id-index-old-objects-empty-p idx-121 :skip)
                          ;; likely gensyms as well
                          (let* ((vector-var (id-index-old-objects idx-121))
                                 (backward?-var nil)
                                 (length (length vector-var)))
                            (loop for iteration from 0 below length
                               ;; TODO - slower than doing a different iteration, or precalculating a +1/-1 delta
                               do (let* ((id (if backward?-var
                                                 ;; backward?-var is likely a macro-generated constant
                                                 (- length iteration 1)
                                                 iteration))
                                         (assertion (aref vector-var id)))
                                    (unless (and (id-index-tombstone-p assertion)
                                                 (id-index-skip-tombstones-p :skip))
                                      (when (id-index-tombstone-p assertion)
                                        (setf assertion :skip))
                                      (note-percent-progress sofar total)
                                      (incf sofar)
                                      (missing-larkc 9466)))))))
                      ;; peer 2 code, new objects?
                      (let ((idx-122 idx-120))
                        (unless (and (id-index-new-objects-empty-p idx-122)
                                     (id-index-skip-tombstones-p :skip))
                          (let* ((new (id-index-new-objects idx-122))
                                 (id (id-index-new-id-threshold idx-122))
                                 (end-id (id-index-next-id idx-122))
                                 (default (if (id-index-skip-tombstones-p :skip)
                                              nil
                                              :skip)))
                            (while (< id end-id)
                              (let ((assertion (gethash id new default)))
                                (unless (and (id-index-skip-tombstones-p :skip)
                                             (id-index-tombstone-p assertion))
                                  (note-percent-progress sofar total)
                                  (incf sofar)
                                  (missing-larkc 9467)))
                              (incf id))))))))))))
        (map-mt-index function term truth gafs-only))))

(defun map-mt-index (function mt &optional truth gafs-only)
  "[Cyc] Apply FUNCTION to each assertion with TRUTH at mt index MT.
If TRUTH is nil, all assertions are mapped.
If GAFS-ONLY, then only gafs are mapped."
  (when (fort-p mt)
    (let ((type (if gafs-only :gaf nil)))
      ;; TODO - iteration macro
      (when (do-mt-index-key-validator mt type)
        (let ((final-index-spec (mt-final-index-spec mt))
              (final-index-iterator nil))
          (unwind-protect (progn
                            (setf final-index-iterator (new-final-index-iterator final-index-spec type truth nil))
                            (let ((done-var nil)
                                  (token-var nil))
                              (until done-var
                                (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var))
                                       (valid (not (eq token-var ass))))
                                  (when valid
                                    (funcall function ass))
                                  (setf done-var (not valid))))))
            (when final-index-iterator
              (destroy-final-index-iterator final-index-iterator))))))))

(defun map-other-index (function term &optional truth gafs-only)
  "[Cyc] Apply FUNCTION to each assertion with TRUTH at other index TERM.
If TRUTH is nil, all assertionsa re mapped.
If GAFS-ONLY, then only gafs are mapped."
  (let ((type (if gafs-only :gaf nil)))
    ;; TODO - iteration macro
    (when (do-other-index-key-validator term type)
      (let ((final-index-spec (other-final-index-spec term))
            (final-index-iterator nil))
        (unwind-protect (progn
                          (setf final-index-iterator (new-final-index-iterator final-index-spec type truth nil))
                          (let ((done-var nil)
                                (token-var nil))
                            (until done-var
                              (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var))
                                     (valid (not (eq token-var ass))))
                                (when valid
                                  (when valid
                                    (when (missing-larkc 30389)
                                      (funcall function ass))))
                                (setf done-var (not valid))))))
          (when final-index-iterator
            (destroy-final-index-iterator final-index-iterator)))))))

(defun gather-index (term &optional remove-duplicates?)
  "[Cyc] Return a list of all mt-relevant assertions indexed via TERM.
If REMOVE-DUPLICATES? is non-nil, assertions are guaranteed to only be listed once."
  (let ((result nil))
    (if (auxiliary-index-p term)
        (if (eq term (unbound-rule-index))
            (missing-larkc 30393)
            ;; TODO - why a ~% at the end of an error message?
            (cerror "So don't!" "Can't gather unknown auxilliar index ~s~%" term))
        (do-term-index (ass term)
          (push ass result)))
    (if remove-duplicates?
        (fast-delete-duplicates result #'eq)
        result)))

(defun gather-index-in-any-mt (term &optional remove-duplicates?)
  "[Cyc] Return a list of all assertions indexed via TERM.
If REMOVE-DUPLICATES? is non-nil, assertions are guaranteed to only be listed once."
  ;; TODO - mt binding macro
  (let ((*relevant-mt-function* #'relevant-mt-is-everything)
        (*mt* #$EverythingPSC))
    (gather-index term remove-duplicates?)))

(defun gather-gaf-arg-index (term argnum &optional pred mt (truth :true))
  "[Cyc] Return a list of all gaf assertions such that:
a) TERM is its ARGNUMth argument
b) if TRUTH is non-nil, then TRUTH is its truth value
c) if PRED is non-nil, then PRED must be its predicate
d) if MT is non-nil, then MT must be its microtheory (and PRED must be non-nil)."
  (let ((result nil))
    (possibly-with-just-mt (mt)
      (if pred
          ;; TODO - iteration macro, contains pred as a parameter
          (let ((pred-var pred))
            (when (do-gaf-arg-index-key-validator term argnum pred-var)
              (let ((iterator-var (new-gaf-arg-final-index-spec-iterator term argnum pred-var))
                    (done-var nil)
                    (token-var nil))
                (until done-var
                  (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                         (valid (not (eq token-var final-index-spec))))
                    (when valid
                      (let ((final-index-iterator nil))
                        (unwind-protect (progn
                                          (setf final-index-iterator (new-final-index-iterator final-index-spec :gaf truth nil))
                                          (let ((done-var-129 nil)
                                                (token-var-130 nil))
                                            (until done-var-129
                                              (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-130))
                                                     (valid-131 (not (eq token-var-130 ass))))
                                                (when valid-131
                                                  (push ass result))
                                                (setf done-var-129 (not valid-131))))))
                          (when final-index-iterator
                            (destroy-final-index-iterator final-index-iterator)))))
                    (setf done-var (not valid)))))))
          ;; TODO - iteration macro, again with pred
          (let ((pred-var nil))
            (when (do-gaf-arg-index-key-validator term argnum pred-var)
              (let ((iterator-var (new-gaf-arg-final-index-spec-iterator term argnum pred-var))
                    (done-var nil)
                    (token-var nil))
                (until done-var
                  (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                         (valid (not (eq token-var final-index-spec))))
                    (when valid
                      (let ((final-index-iterator nil))
                        (unwind-protect (progn
                                          (setf final-index-iterator (new-final-index-iterator final-index-spec :gaf truth nil))
                                          (let ((done-var-133 nil)
                                                (token-var-134 nil))
                                            (until done-var-133
                                              (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-134))
                                                     (valid-135 (not (eq token-var-134 ass))))
                                                (when valid-135
                                                  (push ass result))
                                                (setf done-var-133 (not valid-135))))))
                          (when final-index-iterator
                            (destroy-final-index-iterator final-index-iterator)))))
                    (setf done-var (not valid)))))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-predicate-extent-index (pred &optional mt (truth :true))
  "[Cyc] Return a list of all gaf assertions such that:
a) PRED is its predicate
b) if TRUTH is non-nil, then TRUTH is its truth value
c) if MT is non-nil, then MT must be its microtheory."
  (let ((result nil))
    (possibly-with-just-mt (mt)
      (let ((pred-var pred))
        (when (do-predicate-extent-index-key-validator pred-var)
          (let ((iterator-var (new-predicate-extent-final-index-spec-iterator pred-var))
                (done-var nil)
                (token-var nil))
            (until done-var
              (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                     (valid (not (eq token-var final-index-spec))))
                (when valid
                  (let ((final-index-iterator nil))
                    (unwind-protect (progn
                                      (setf final-index-iterator (new-final-index-iterator final-index-spec :gaf truth nil))
                                      (let ((done-var-143 nil)
                                            (token-var-144 nil))
                                        (until done-var-143
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-144))
                                                 (valid-145 (not (eq token-var-144 ass))))
                                            (when valid-145
                                              (push ass result))
                                            (setf done-var-143 (not valid-145))))))
                      (when final-index-iterator
                        (destroy-final-index-iterator final-index-iterator)))))
                (setf done-var (not valid))))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-function-extent-index (func)
  "[Cyc] Return a list of all #$termOfUnit assertions such that:
FUNC is the functor of the naut arg 2."
  (let ((result nil))
    ;; TODO - iteration macro
    (when (do-function-extent-index-key-validator func)
      (let ((final-index-spec (function-extent-final-index-spec func))
            (final-index-iterator nil))
        (unwind-protect (progn
                          (setf final-index-iterator (new-final-index-iterator final-index-spec :gaf nil nil))
                          (let ((done-var nil)
                                (token-var nil))
                            (until done-var
                              (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var))
                                     (valid (not (eq token-var ass))))
                                (when valid
                                  (push ass result))
                                (setf done-var (not valid))))))
          (when final-index-iterator
            (destroy-final-index-iterator final-index-iterator)))))
    (fast-delete-duplicates result #'eq)))

(defun gather-predicate-rule-index (pred sense &optional mt direction)
  "[Cyc] Returna  list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has PRED as a predicate in a positive literal
b) if SENSE is :neg, it has PRED as a predicate in a negative literal
c) if MT is non-nil, then MT must be its microtheory
d) if DIRECTION is non-nil, then DIRECTION must be its direciton."
  (let ((result nil))
    (possibly-with-just-mt (mt)
      (if direction
          ;; TODO - iteration macro
          (when (do-predicate-rule-index-key-validator pred sense direction)
            (let ((iterator-var (new-predicate-rule-final-index-spec-iterator pred sense direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator nil))
                      (unwind-protect (progn
                                        (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                                        (let ((done-var-147 nil)
                                              (token-var-148 nil))
                                          (until done-var-147
                                            (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-148))
                                                   (valid-149 (not (eq token-var-148 ass))))
                                              (when valid-149
                                                (push ass result))
                                              (setf done-var-147 (not valid-149))))))
                        (when final-index-iterator
                          (destroy-final-index-iterator final-index-iterator)))))
                  (setf done-var (not valid))))))
          ;; TODO - iteration macro
          (when (do-predicate-rule-index-key-validator pred sense nil)
            (let ((iterator-var (new-predicate-rule-final-index-spec-iterator pred sense nil))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil nil)))
                      (unwind-protect (let ((done-var-151 nil)
                                            (token-var-152 nil))
                                        (until done-var-151
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-152))
                                                 (valid-153 (not (eq token-var-152 ass))))
                                            (when valid-153
                                              (push ass result))
                                            (setf done-var-151 (not valid-153)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-decontextualized-ist-predicate-rule-index (pred sense &optional direction)
  "[Cyc] Returna  list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has PRED as a predicate in a positive literal wrapped in #$ist
b) if SENSE is :neg, it has PRED as a predicate in a negative literal wrapped in #$ist
c) if DIRECTION is non-nil, then DIRECTION must be its direction."
  (let ((result nil))
    (if direction
        ;; TODO - iteration macro
        (when (do-decontextualized-ist-predicate-rule-index-key-validator pred sense direction)
          (let ((iterator-var (new-decontextualized-ist-predicate-rule-final-index-spec-iterator pred sense direction))
                (done-var nil)
                (token-var nil))
            (until done-var
              (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                     (valid (not (eq token-var final-index-spec))))
                (when valid
                  (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction)))
                    (unwind-protect (let ((done-var-155 nil)
                                          (token-var-156 nil))
                                      (until done-var-155
                                        (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-156))
                                               (valid-157 (not (eq token-var-156 ass))))
                                          (when valid-157
                                            (push ass result))
                                          (setf done-var-155 (not valid-157)))))
                      (destroy-final-index-iterator final-index-iterator))))
                (setf done-var (not valid))))))
        ;; TODO - iteration macro
        (when (do-decontextualized-ist-predicate-rule-index-key-validator pred sense nil)
          (let ((iterator-var (new-decontextualized-ist-predicate-rule-final-index-spec-iterator pred sense nil))
                (done-var nil)
                (token-var nil))
            (until done-var
              (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                     (valid (not (eq token-var final-index-spec))))
                (when valid
                  (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil nil)))
                    (unwind-protect (let ((done-var-158 nil)
                                          (token-var-159 nil))
                                      (until done-var-158
                                        (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-159))
                                               (valid-160 (not (eq token-var-159 ass))))
                                          (when valid-160
                                            (push ass result))
                                          (setf done-var-158 (not valid-160)))))
                      (destroy-final-index-iterator final-index-iterator))))
                (setf done-var (not valid)))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-isa-rule-index (collection sense &optional mt direction)
  "[Cyc] Return a list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has a positive literal of the form (isa <whatever> COLLECTION)
b) if SENSE is :neg, it has a negative literal of the form (isa <whatever> COLLECTION)
c) if MT is non-nil, then MT must be its microtheory
d) if DIRECTION is non-nil, then DIRECTION must be its direction."
  (let ((result nil))
    (possibly-with-just-mt (mt)
      (if direction
          ;; TODO - iteration macro
          (when (do-isa-rule-index-key-validator collection sense direction)
            (let ((iterator-var (new-isa-rule-final-index-spec-iterator collection sense direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction)))
                      (unwind-protect (let ((done-var-161 nil)
                                            (token-var-162 nil))
                                        (until done-var-161
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-162))
                                                 (valid-163 (not (eq token-var-162 ass))))
                                            (when valid-163
                                              (push ass result))
                                            (setf done-var-161 (not valid-163)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))
          ;; TODO - iteration macro
          (when (do-isa-rule-index-key-validator collection sense nil)
            (let ((iterator-var (new-isa-rule-final-index-spec-iterator collection sense nil))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil nil)))
                      (unwind-protect (let ((done-var-165 nil)
                                            (token-var-166 nil))
                                        (until done-var-165
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-166))
                                                 (valid-167 (not (eq token-var-166 ass))))
                                            (when valid-167
                                              (push ass result))
                                            (setf done-var-165 (not valid-167)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-quoted-isa-rule-index (collection sense &optional mt direction)
  "[Cyc] Return a list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has a positive literal of the form (quotedIsa <whatever> COLLECTION)
b) if SENSE is :neg, it has a negative literal of the form (quotedIsa <whatever> COLLECTION)
c) if MT is non-nil, then MT must be its microtheory
d) if DIRECTION is non-nil, then DIRECTION must be its direction."
  (let ((result nil))
    (possibly-with-just-mt (mt)
      (if direction
          ;; TODO - iteration macro
          (when (do-quoted-isa-rule-index-key-validator collection sense direction)
            (let ((iterator-var (new-quoted-isa-rule-final-index-spec-iterator collection sense direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction)))
                      (unwind-protect (let ((done-var-169 nil)
                                            (token-var-170 nil))
                                        (until done-var-169
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-170))
                                                 (valid-171 (not (eq token-var-170 ass))))
                                            (when valid-171
                                              (push ass result))
                                            (setf done-var-169 (not valid-171)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))
          ;; TODO - iteration macro
          (when (do-quoted-isa-rule-index-key-validator collection sense nil)
            (let ((iterator-var (new-quoted-isa-rule-final-index-spec-iterator collection sense nil))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil nil)))
                      (unwind-protect (let ((done-var-173 nil)
                                            (token-var-174 nil))
                                        (until done-var-173
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-174))
                                                 (valid-175 (not (eq token-var-174 ass))))
                                            (when valid-175
                                              (push ass result))
                                            (setf done-var-173 (not valid-175)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-genls-rule-index (collection sense &optional mt direction)
  "[Cyc] Return a list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has a positive literal of the form (genls <whatever> COLLECTION)
b) if SENSE is :neg, it has a negative literal of the form (genls <whatever> COLLECTION)
c) if MT is non-nil, then MT must be its microtheory
d) if DIRECTION is non-nil, then DIRECTION must be its direction."

  (let ((result nil))
    (possibly-with-just-mt (mt)
      (if direction
          ;; TODO - iteration macro
          (when (do-genls-rule-index-key-validator collection sense direction)
            (let ((iterator-var (new-genls-rule-final-index-spec-iterator collection sense direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction)))
                      (unwind-protect (let ((done-var-177 nil)
                                            (token-var-178 nil))
                                        (until done-var-177
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-178))
                                                 (valid-179 (not (eq token-var-178 ass))))
                                            (when valid-179
                                              (push ass result))
                                            (setf done-var-177 (not valid-179)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))
          ;; TODO - iteration macro
          (when (do-genls-rule-index-key-validator collection sense nil)
            (let ((iterator-var (new-genls-rule-final-index-spec-iterator collection sense nil))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil nil)))
                      (unwind-protect (let ((done-var-181 nil)
                                            (token-var-182 nil))
                                        (until done-var-181
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-182))
                                                 (valid-183 (not (eq token-var-182 ass))))
                                            (when valid-183
                                              (push ass result))
                                            (setf done-var-181 (not valid-183)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-genl-mt-rule-index (genl-mt sense &optional rule-mt direction)
  "[Cyc] Returns  alist of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has a positive literal of the form (genlMt <whatever> GENL-MT)
b) if SENSE is :neg, it has a negative literal of the form (genlMt <whatever> GENL-MT)
c) if RULE-MT is non-nil, then RULE-MT must be its microtheory
d) if DIRECTION is non-nil, then DIRECTION must be its direction."
  (let ((result nil))
    (possibly-with-just-mt (rule-mt)
      (if direction
          ;; TODO - iteration macro
          (when (do-genl-mt-rule-index-key-validator genl-mt sense direction)
            (let ((iterator-var (new-genl-mt-rule-final-index-spec-iterator genl-mt sense direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction)))
                      (unwind-protect (let ((done-var-185 nil)
                                            (token-var-186 nil))
                                        (until done-var-185
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-186))
                                                 (valid-187 (not (eq token-var-186 ass))))
                                            (when valid-187
                                              (push ass result))
                                            (setf done-var-185 (not valid-187)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))
          ;; TODO - iteration macro
          (when (do-genl-mt-rule-index-key-validator genl-mt sense nil)
            (let ((iterator-var (new-genl-mt-rule-final-index-spec-iterator genl-mt sense nil))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil nil)))
                      (unwind-protect (let ((done-var-189 nil)
                                            (token-var-190 nil))
                                        (until done-var-189
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-190))
                                                 (valid-191 (not (eq token-var-190 ass))))
                                            (when valid-191
                                              (push ass result))
                                            (setf done-var-189 (not valid-191)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-function-rule-index (func &optional mt direction)
  "[Cyc] Return a list of all non-gaf assertions (rules) such that:
a) it has a negative literal of the form (termOfUnit <whatever> (FUNC . <whatever>))
b) if MT is non-nil, then MT must be its microtheory
c) if DIRECTION is non-nil, then DIRECTION must be its direction."
  (let ((result nil))
    (possibly-with-just-mt (mt)
      (if direction
          ;; TODO - iteration macro
          (when (do-function-rule-index-key-validator func direction)
            (let ((iterator-var (new-function-rule-final-index-spec-iterator func direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction)))
                      (unwind-protect (let ((done-var-193 nil)
                                            (token-var-194 nil))
                                        (until done-var-193
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-194))
                                                 (valid-195 (not (eq token-var-194 ass))))
                                            (when valid-195
                                              (push ass result))
                                            (setf done-var-193 (not valid-195)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))
          ;; TODO - iteration macro
          (when (do-function-rule-index-key-validator func nil)
            (let ((iterator-var (new-function-rule-final-index-spec-iterator func nil))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil nil)))
                      (unwind-protect (let ((done-var-197 nil)
                                            (token-var-198 nil))
                                        (until done-var-197
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-198))
                                                 (valid-199 (not (eq token-var-198 ass))))
                                            (when valid-199
                                              (push ass result))
                                            (setf done-var-197 (not valid-199)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-exception-rule-index (rule &optional mt direction)
  "[Cyc] Return a list of all non-gaf assertions (rules) such that:
a) it has a positive literal of the form (abnormal <whatever> RULE)
b) if MT is non-nil, then MT must be its microtheory
c) if DIRECTION is non-nil, then DIRECTION must be its direction."
  (let ((result nil))
    (possibly-with-just-mt (mt)
      (if direction
          ;; TODO - iteration macro
          (when (do-exception-rule-index-key-validator rule direction)
            (let ((iterator-var (new-exception-rule-final-index-spec-iterator rule direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction)))
                      (unwind-protect (let ((done-var-201 nil)
                                            (token-var-202 nil))
                                        (until done-var-201
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-202))
                                                 (valid-203 (not (eq token-var-202 ass))))
                                            (when valid-203
                                              (push ass result))
                                            (setf done-var-201 (not valid-203)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))
          ;; TODO - iteration macro
          (when (do-exception-rule-index-key-validator rule nil)
            (let ((iterator-var (new-exception-rule-final-index-spec-iterator rule nil))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil nil)))
                      (unwind-protect (let ((done-var-205 nil)
                                            (token-var-206 nil))
                                        (until done-var-205
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-206))
                                                 (valid-207 (not (eq token-var-206 ass))))
                                            (when valid-207
                                              (push ass result))
                                            (setf done-var-205 (not valid-207)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-pragma-rule-index (rule &optional mt direction)
  "[Cyc] Return a list of all non-gaf assertions (rules) such that:
a) it has a positive literal of the form (meetsPragmaticRequirement <whatever> RULE)
b) if MT is non-nil, then MT must be its microtheory
c) if DIRECTION is non-nil, then DIRECTION must be its direction."
  (let ((result nil))
    (possibly-with-just-mt (mt)
      (if direction
          ;; TODO - iteration macro
          (when (do-pragma-rule-index-key-validator rule direction)
            (let ((iterator-var (new-pragma-rule-final-index-spec-iterator rule direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction)))
                      (unwind-protect (let ((done-var-209 nil)
                                            (token-var-210 nil))
                                        (until done-var-209
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-210))
                                                 (valid-211 (not (eq token-var-210 ass))))
                                            (when valid-211
                                              (push ass result))
                                            (setf done-var-209 (not valid-211)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))
          ;; TODO - iteration macro
          (when (do-pragma-rule-index-key-validator rule nil)
            (let ((iterator-var (new-pragma-rule-final-index-spec-iterator rule nil))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator (new-final-index-iterator final-index-spec :rule nil nil)))
                      (unwind-protect (let ((done-var-213 nil)
                                            (token-var-214 nil))
                                        (until done-var-213
                                          (let* ((ass (iteration-next-without-values-macro-helper final-index-iterator token-var-214))
                                                 (valid-215 (not (eq token-var-214 ass))))
                                            (when valid-215
                                              (push ass result))
                                            (setf done-var-213 (not valid-215)))))
                        (destroy-final-index-iterator final-index-iterator))))
                  (setf done-var (not valid))))))))
    (fast-delete-duplicates result #'eq)))

(defun gather-mt-index (term)
  "[Cyc] Return a list of all assertions such that TERM is its microtheory."
  (if (or (simple-indexed-term-p term)
          (and (hlmt-p term)
               (broad-mt? (hlmt-monad-mt term))))
      (let ((*mapping-answer* nil))
        ;; TODO - mt macro
        (let ((*relevant-mt-function* #'relevant-mt-is-eq)
              (*mt* term))
          (map-mt-contents #'gather-assertions (hlmt-monad-mt term))
          *mapping-answer*))
      (missing-larkc 12735)))

(defun gather-other-index (term)
  "[Cyc] Return a list of other assertions mentioning TERM but not indexed in any other more useful manner."
  (if (simple-indexed-term-p term)
      (let ((*mapping-answer* nil))
        (map-other-index #'gather-assertions term)
        *mapping-answer*)
      (when-let ((final-index (get-other-subindex term)))
        (missing-larkc 31921))))

(defun gather-assertions (assertion)
  (when (or (not *mapping-assertion-selection-fn*)
            (funcall *mapping-assertion-selection-fn* assertion))
    (push assertion *mapping-answer*)))



;;; Cyc API registrations


(register-cyc-api-function 'why-not-genl-inverse? '(spec genl &optional mt tv behavior)
    "A justification of (not (genlInverse SPEC GENL)"
    '((spec fort-p) (genl fort-p))
    '(listp))

(register-cyc-api-function 'max-floor-mts-of-genl-predicate-paths '(spec genl &optional tv)
    "@return listp; In what (most-genl) mts is GENL a genlPred of SPEC?"
    '((spec fort-p) (genl fort-p))
    'nil)

(register-cyc-api-function 'max-floor-mts-of-genl-inverse-paths '(spec genl-inverse &optional tv)
    "In what (most-genl) mts is GENL-INVERSE a genlInverse of SPEC?"
    '((spec fort-p) (genl-inverse fort-p))
    'nil)

(register-cyc-api-function 'min-genls '(col &optional mt tv)
    "Returns the most-specific genls of collection COL"
    'nil
    '((list fort-p)))

(register-cyc-api-function 'max-not-genls '(col &optional mt tv)
    "Returns the least-specific negated genls of collection COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'max-specs '(col &optional mt tv)
    "Returns the least-specific specs of collection COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'min-not-specs '(col &optional mt tv)
    "Returns the most-specific negated specs of collection COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'genl-siblings '(col &optional mt tv)
    "Returns the direct genls of those direct spec collections of COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'spec-siblings '(col &optional mt tv)
    "Returns the direct specs of those direct genls collections of COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'all-genls '(col &optional mt tv)
    "Returns all genls of collection COL
   (ascending transitive closure; inexpensive)"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'all-specs '(col &optional mt tv)
    "Returns all specs of collection COL 
   (descending transitive closure; expensive)"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'count-all-specs '(collection &optional mt tv)
    "Counts the number of specs in COLLECTION and then returns the count."
    '((collection el-fort-p))
    '(integerp))

(register-cyc-api-function 'all-genls-wrt '(spec genl &optional mt tv)
    "Returns all genls of collection SPEC that are also specs of collection GENL (ascending transitive closure; inexpensive)"
    '((spec el-fort-p) (genl el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'union-all-genls '(cols &optional mt tv)
    "Returns all genls of each collection in COLs"
    '((cols listp))
    '((list fort-p)))

(register-cyc-api-function 'union-all-specs '(cols &optional mt tv)
    "Returns all specs of each collection in COLs"
    '((cols listp))
    '((list fort-p)))

(register-cyc-api-function 'all-dependent-specs '(col &optional mt tv)
    "Returns all specs s of COL s.t. every path connecting
   s to any genl of COL must pass through COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'all-genls-among '(col candidates &optional mt tv)
    "Returns those genls of COL that are included among CANDIDATES"
    '((col el-fort-p) (candidates listp))
    '((list fort-p)))

(register-cyc-api-function 'all-specs-among '(col candidates &optional mt tv)
    "Returns those specs of COL that are included among CANDIDATEs"
    '((col el-fort-p) (candidates listp))
    '((list fort-p)))

(register-cyc-api-function 'all-genls-if '(function col &optional mt tv)
    "Returns all genls of collection COL that satisfy FUNCTION
   (FUNCTION must not effect sbhl search state)"
    '((function function-spec-p) (col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'all-specs-if '(function col &optional mt tv)
    "Returns all genls of collection COL that satisfy FUNCTION
   (FUNCTION must not effect sbhl search state)"
    '((function function-spec-p) (col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'all-not-genls '(col &optional mt tv)
    "Returns all negated genls of collection COL 
   (descending transitive closure; expensive)"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'all-not-specs '(col &optional mt tv)
    "Returns all negated specs of collection COL 
   (ascending transitive closure; inexpensive)"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'map-all-genls '(fn col &optional mt tv)
    "Applies FN to every (all) genls of COL
   (FN must not effect the current sbhl space)"
    '((fn function-spec-p) (col el-fort-p))
    'nil)

(register-cyc-api-function 'map-all-specs '(fn col &optional mt tv)
    "Applies FN to every (all) specs of COL
   (FN must not effect the current sbhl space)"
    '((fn function-spec-p) (col el-fort-p))
    'nil)

(register-cyc-api-function 'any-all-genls '(fn col &optional mt tv)
    "Return a non-nil result of applying FN to some all-genl of COL
   (FN must not effect the current sbhl space)"
    '((fn function-spec-p) (col el-fort-p))
    'nil)

(register-cyc-api-function 'any-all-specs '(fn col &optional mt tv)
    "Return a non-nil result of applying FN to some all-spec of COL
   (FN must not effect the current sbhl space)"
    '((fn function-spec-p) (col el-fort-p))
    'nil)

(register-cyc-api-function 'genl? '(spec genl &optional mt tv)
    "Returns whether (#$genls SPEC GENL) can be inferred.
   (ascending transitive search; inexpensive)"
    '((spec el-fort-p) (genl el-fort-p))
    '(booleanp))

(register-cyc-api-function 'spec? '(genl spec &optional mt tv)
    "Returns whether (#$genls SPEC GENL) can be inferred.
   (ascending transitive search; inexpensive)"
    '((genl el-fort-p) (spec el-fort-p))
    '(booleanp))

(register-cyc-api-function 'any-genl? '(spec genls &optional mt tv)
    "(any-genl? spec genls) is t iff (genl? spec genl) for some genl in genls
   (ascending transitive search; inexpensive)"
    '((spec el-fort-p) (genls listp))
    '(booleanp))

(register-cyc-api-function 'any-spec? '(genl specs &optional mt tv)
    "Returns T iff (spec? genl spec) for some spec in SPECS"
    '((genl el-fort-p) (specs listp))
    '(booleanp))

(register-cyc-api-function 'all-genl? '(spec genls &optional mt tv)
    "Returns T iff (genl? spec genl) for every genl in GENLS
   (ascending transitive search; inexpensive)"
    '((spec el-fort-p) (genls listp))
    '(booleanp))

(register-cyc-api-function 'all-spec? '(genl specs &optional mt tv)
    "Returns T iff (spec? genl spec) for every spec in SPECS"
    '((genl el-fort-p) (specs listp))
    '(booleanp))

(register-cyc-api-function 'any-genl-any? '(specs genls &optional mt tv)
    "Return T iff (genl? spec genl mt) for any spec in SPECS, genl in GENLS"
    '((specs listp) (genls listp))
    '(booleanp))

(register-cyc-api-function 'any-genl-all? '(specs genls &optional mt tv)
    "Return T iff (genl? spec genl mt) for any spec in SPECS and all genl in GENLS"
    '((specs listp) (genls listp))
    '(booleanp))

(register-cyc-api-function 'all-spec-any? '(specs genls &optional mt tv)
    "Return T iff for each spec in SPECS there is some genl in GENLS s.t. (genl? spec genl mt)"
    '((specs listp) (genls listp))
    '(booleanp))

(register-cyc-api-function 'not-genl? '(col not-genl &optional mt tv)
    "Return whether collection NOT-GENL is not a genl of COL."
    '((col el-fort-p) (not-genl el-fort-p))
    '(booleanp))

(register-cyc-api-function 'all-not-spec? '(col not-specs &optional mt tv)
    "Return whether every collection in NOT-SPECS is not a spec of COL."
    '((col el-fort-p) (not-specs listp))
    '(booleanp))

(register-cyc-api-function 'any-not-genl? '(col not-genls &optional mt tv)
    "Returns whether any collection in NOT-GENLS is not a genl of COL."
    '((col el-fort-p) (not-genls listp))
    '(booleanp))

(register-cyc-api-function 'collections-coextensional? '(col-1 col-2 &optional mt)
    "Are COL-1 and COL-2 coextensional?"
    '((col-1 el-fort-p) (col-2 el-fort-p))
    '(booleanp))

(register-cyc-api-function 'collections-intersect? '(col-1 col-2 &optional mt)
    "Do collections COL-1 and COL-2 intersect?
   (uses only sbhl graphs: their extensions are not searched
    nor are their sufficient conditions analyzed)"
    '((col-1 el-fort-p) (col-2 el-fort-p))
    '(booleanp))

(register-cyc-api-function 'why-genl? '(spec genl &optional mt tv behavior)
    "Justification of (genls SPEC GENL)"
    '((spec el-fort-p) (genl el-fort-p))
    '(listp))

(register-cyc-api-function 'why-not-genl? '(spec genl &optional mt tv behavior)
    "Justification of (not (genls SPEC GENL))"
    '((spec el-fort-p) (genl el-fort-p))
    '(listp))

(register-cyc-api-function 'why-not-assert-genls? '(spec genl &optional mt)
    "Justification of why asserting (genls SPEC GENL) is not consistent"
    '((spec el-fort-p) (genl el-fort-p))
    '(listp))

(register-cyc-api-function 'collection-leaves '(col &optional mt tv)
    "Returns the minimally-general (the most specific) among all-specs of COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'min-cols '(cols &optional mt tv)
    "Returns the minimally-general (the most specific) among reified collections COLS,
   collections that have no proper specs among COLS"
    '((cols list-of-collections-p))
    '((list fort-p)))

(register-cyc-api-function 'min-col '(cols &optional mt tv)
    "Returns the single minimally-general (the most specific) among reified collections COLS.
Ties are broken by comparing the number of all-genls which is a rough depth estimate."
    '((cols listp))
    '(fort-p))

(register-cyc-api-function 'max-cols '(cols &optional mt tv)
    "Returns the most-general among reified collections COLS, collections
   that have no proper genls among COLS"
    '((cols listp))
    '((list fort-p)))

(register-cyc-api-function 'min-ceiling-cols '(cols &optional candidates mt tv)
    "Returns the most specific common generalizations among reified collections COLS
   (if CANDIDATES is non-nil, then result is a subset of CANDIDATES)"
    '((cols listp))
    '((list fort-p)))

(register-cyc-api-function 'max-floor-cols '(cols &optional candidates mt tv)
    "Returns the most general common specializations among reified collections COLS
   (if CANDIDATES is non-nil, then result is a subset of CANDIDATES)"
    '((cols listp))
    '((list fort-p)))

(register-cyc-api-function 'any-genl-isa '(col isa &optional mt tv)
    "Return some genl of COL that isa instance of ISA (if any such genl exists)"
    '((col el-fort-p) (isa el-fort-p))
    '(fort-p))

(register-cyc-api-function 'lighter-col '(col-a col-b)
    "Return COL-B iff it has fewer specs than COL-A, else return COL-A"
    '((col-a el-fort-p) (col-b el-fort-p))
    '(fort-p))

(register-cyc-api-function 'lightest-of-cols '(cols)
    "Return the collection having the fewest specs given a list of collections."
    '((cols listp))
    '(fort-p))

(register-cyc-api-function 'shallower-col '(col-a col-b)
    "Return COL-B iff it has fewer genls than COL-A, else return COL-A"
    '((col-a el-fort-p) (col-b el-fort-p))
    '(fort-p))

(register-cyc-api-function 'max-floor-mts-of-genls-paths '(spec genl &optional tv)
    "@return listp; Returns in what (most-genl) mts GENL is a genls of SPEC"
    '((spec el-fort-p) (genl el-fort-p))
    'nil)

(register-cyc-api-function 'gt-superiors '(predicate fort &optional mt)
    "Returns direct superiors of FORT via transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-min-superiors '(predicate fort &optional mt)
    "Returns minimal superiors of FORT via transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-inferiors '(predicate fort &optional mt)
    "Returns direct inferiors of FORT via transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-max-inferiors '(predicate fort &optional mt)
    "Returns maximal inferiors of FORT via transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-co-superiors '(predicate fort &optional mt)
    "Returns sibling direct-superiors of direct-inferiors of FORT via PREDICATE, excluding FORT itself"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-co-inferiors '(predicate fort &optional mt)
    "Returns sibling direct-inferiors of direct-superiors of FORT via PREDICATE, excluding FORT itself"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-redundant-superiors '(predicate fort &optional mt)
    "Returns direct-superiors of FORT via PREDICATE that are subsumed by other superiors"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-redundant-inferiors '(predicate fort &optional mt)
    "Returns direct-inferiors of FORT via PREDICATE that subsumed other inferiors"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-all-superiors '(predicate fort &optional mt)
    "Returns all superiors of FORT via PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-all-inferiors '(predicate fort &optional mt)
    "Returns all inferiors of FORT via PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-all-accessible '(predicate fort &optional mt)
    "Returns all superiors and all inferiors of FORT via PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-roots '(predicate fort &optional mt)
    "Returns maximal superiors (i.e., roots) of FORT via PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-leaves '(predicate fort &optional mt)
    "Returns minimal inferiors (i.e., leaves) of FORT via PREDICATE"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-compose-fn-all-superiors '(predicate fort fn &optional (combine-fn (function cons)) mt)
    "Apply fn to each superior of FORT;
   fn takes a fort as its only arg, and must not effect the search status of each
  fort it visits"
    '((predicate fort-p) (fort gt-term-p) (fn function-spec-p))
    'nil)

(register-cyc-api-function 'gt-compose-fn-all-inferiors '(predicate fort fn &optional (combine-fn *gt-combine-fn*) mt)
    "Apply fn to each inferior of FORT; 
   fn takes a fort as its only arg, and 
   it must not effect the search status of each fort it visits"
    '((predicate fort-p) (fort gt-term-p) (fn function-spec-p))
    'nil)

(register-cyc-api-function 'gt-compose-pred-all-superiors '(predicate fort compose-pred &optional (compose-index-arg *gt-compose-index-arg*) (compose-gather-arg *gt-compose-gather-arg*) mt)
    "Returns all nodes accessible by COMPOSE-PRED from each superior of FORT along 
  transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p) (compose-pred predicate-in-any-mt?))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-compose-pred-all-inferiors '(predicate fort compose-pred &optional (compose-index-arg *gt-compose-index-arg*) (compose-gather-arg *gt-compose-gather-arg*) mt)
    "Returns all nodes accessible by COMPOSE-PRED from each inferior of FORT along 
  transitive PREDICATE"
    '((predicate fort-p) (fort gt-term-p) (compose-pred predicate-in-any-mt?))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-all-dependent-inferiors '(predicate fort &optional mt)
    "Returns all inferiors i of FORT s.t. every path connecting i to 
   any superior of FORT must pass through FORT"
    '((predicate fort-p) (fort gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-why-superior? '(predicate superior inferior &optional mt)
    "Returns justification of why SUPERIOR is superior to (i.e., hierarchically higher than) 
  INFERIOR"
    '((predicate fort-p) (superior gt-term-p) (inferior gt-term-p))
    '((list assertion-p)))

(register-cyc-api-function 'gt-has-superior? '(predicate inferior superior &optional mt)
    "Returns whetherfort INFERIOR is hierarchically lower (wrt transitive PREDICATE) 
  to fort SUPERIOR?"
    '((predicate fort-p) (inferior gt-term-p) (superior gt-term-p))
    '(booleanp))

(register-cyc-api-function 'gt-has-inferior? '(predicate superior inferior &optional mt)
    "Returns whether fort SUPERIOR is hierarchically higher 
   (wrt transitive PREDICATE) to fort INFERIOR?"
    '((predicate fort-p) (superior gt-term-p) (inferior gt-term-p))
    '(booleanp))

(register-cyc-api-function 'gt-cycles? '(predicate fort &optional mt)
    "Returns whether FORT is accessible from itself by one or more PREDICATE gafs?"
    '((predicate fort-p) (fort gt-term-p))
    '(booleanp))

(register-cyc-api-function 'gt-completes-cycle? '(predicate fort1 fort2 &optional mt)
    "Returns whether a transitive path connect FORT2 to FORT1, 
   or whether a transitive inverse path connect FORT1 to FORT2?"
    '((predicate fort-p) (fort1 gt-term-p) (fort2 gt-term-p))
    '(booleanp))

(register-cyc-api-function 'gt-why-completes-cycle? '(predicate fort1 fort2 &optional mt)
    "Returns justification that a transitive path connects FORT2 to FORT1, 
   or that a transitive inverse path connects FORT1 to FORT2?"
    '((predicate fort-p) (fort1 gt-term-p) (fort2 gt-term-p))
    'nil)

(register-cyc-api-function 'gt-min-nodes '(predicate forts &optional mt)
    "Returns returns the most-subordinate elements of FORTS
   (one member only of a cycle will be a min-node candidate)"
    '((predicate fort-p) (forts listp))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-max-nodes '(predicate forts &optional mt (direction *gt-max-nodes-direction*))
    "Returns returns the least-subordinate elements of FORTS
   (<direction> should be :up unless all nodes are low in the hierarchy)"
    '((predicate fort-p) (forts listp))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-min-ceilings '(predicate forts &optional candidates mt)
    "Returns the most-subordinate common superiors of FORTS
   (when CANDIDATES is non-nil, the result must subset it)"
    '((predicate fort-p) (forts listp))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-max-floors '(predicate forts &optional candidates mt)
    "Returns the least-subordinate elements or common inferiors of FORTS
   (when CANDIDATES is non-nil, the result must subset it)"
    '((predicate fort-p) (forts listp))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-min-superiors-excluding '(predicate inferior superior &optional mt)
    "Returns least-general superiors of INFERIOR ignoring SUPERIOR
   (useful for splicing-out SUPERIOR from hierarchy)"
    '((predicate fort-p) (inferior gt-term-p) (superior gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-max-inferiors-excluding '(predicate inferior superior &optional mt)
    "Returns most-general inferiors of SUPERIOR ignoring INFERIOR (expensive)
   (useful for splicing-out INFERIOR from hierarchy)"
    '((predicate fort-p) (inferior gt-term-p) (superior gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'gt-any-superior-path '(predicate inferior superior &optional mt)
    "Returns list of nodes connecting INFERIOR with SUPERIOR"
    '((predicate fort-p) (inferior gt-term-p) (superior gt-term-p))
    '((list gt-term-p)))

(register-cyc-api-function 'schedule-guardian-request '(checker-fn parameter notification-fn &optional process interrupt-p)
    "Schedule a guardian request. (funcall checker-fn parameter) will be called
   until it returns NIL. 
   In this case, the requesting process is notified, either via FUNCALL or INTERRUPT-PROCESS-WITH-ARGS
   and passed the parameter one last time; the INTERRUPT-P flag decides which one it is; FUNCALL is default.
   @note use FUNCALL when the function invoked cannot or need not run in the process being notified;
   for example, TERMINATE-ACTIVE-TASK-PROCESS already calls INTERRRUPT-PROCESS, and not all LISP implementation
   actually handle that gracefully, so there FUNCALL is sufficient.
   @return the ticked for the guardian request"
    '((checker-fn function-spec-p) (notification-fn function-spec-p) (interrupt-p booleanp))
    '(fixnump))

(register-cyc-api-function 'guardian-request-id-p '(request-id)
    "Determine whether this is a proper guardian request id."
    'nil
    '(booleanp))

(register-cyc-api-function 'cancel-guardian-request '(request-id)
    "Abort a guardian request that is currently scheduled to be checked.
   @return T"
    '((request-id fixnump))
    '(symbolp))

(register-cyc-api-macro 'with-guardian-request '((checker-fn parameter notification-fn) &body body)
    "Setup a guardian request and cancel if necessary.")

(register-cyc-api-function 'active-guardian-requests 'nil
    "The active guardian requests.
   @return 0 the elements on the request queue
   @return 1 the UnivTime Stamp of the contents"
    'nil
    'nil)

(register-cyc-api-function 'initialize-guardian 'nil
    "Starts the guardian unless it is running."
    'nil
    '(booleanp))

(register-cyc-api-function 'stop-guardian 'nil
    "Tell the guardian to shut itself down."
    'nil
    '(booleanp))

(register-cyc-api-function 'start-guardian 'nil
    "Launch the guardian process, potentially overwriting an existing guardian."
    'nil
    '(booleanp))

(register-cyc-api-function 'ensure-guardian-running 'nil
    "Launch the guardian process if it is not currently running."
    'nil
    '(booleanp))

(register-cyc-api-function 'kb-create-asserted-argument '(assertion truth strength)
    "Create an asserted argument for ASSERTION from TRUTH and STRENGTH,
and hook up all the indexing between them."
    '((assertion assertion-p) (truth truth-p) (strength el-strength-p))
    '(asserted-argument-p))

(register-cyc-api-function 'kb-remove-asserted-argument '(assertion asserted-argument)
    "Remove ASSERTED-ARGUMENT for ASSERTION."
    '((assertion assertion-p) (asserted-argument asserted-argument-p))
    '(null))

(register-cyc-api-function 'hl-assert-bookkeeping-binary-gaf '(pred arg1 arg2 mt)
    "Assert (PRED ARG1 ARG2) in MT to the bookkeeping store."
    '((pred fort-p) (mt hlmt-p))
    '(boolean))

(register-cyc-api-function 'hl-unassert-bookkeeping-binary-gaf '(pred arg1 arg2 mt)
    "Unassert (PRED ARG1 ARG2) in MT from the bookkeeping store."
    '((pred fort-p) (mt hlmt-p))
    '(boolean))

(register-cyc-api-function 'hl-support-module-p '(object)
    "Return T iff OBJECT is an HL support module."
    'nil
    '(booleanp))

(register-cyc-api-function 'min-isa '(term &optional mt tv)
    "Returns most-specific collections that include TERM (inexpensive)"
    '((term hl-term-p))
    '((list fort-p)))

(register-cyc-api-function 'max-not-isa '(term &optional mt tv)
    "Returns most-general collections that do not include TERM (expensive)"
    '((term hl-term-p))
    '((list fort-p)))

(register-cyc-api-function 'instances '(col &optional mt (tv constant_handles.reader_make_constant_shell(makeString("True-JustificationTruth"))))
    "Returns the asserted instances of COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'max-instances '(col &optional mt tv)
    "Returns the maximal among the asserted instances of COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'min-not-instances '(col &optional mt tv)
    "Returns the most-specific negated instances of collection COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'isa-siblings '(term &optional mt tv)
    "Returns the direct isas of those collections of which TERM is a direct instance"
    '((term hl-term-p))
    '((list fort-p)))

(register-cyc-api-function 'instance-siblings '(term &optional mt tv)
    "Returns the direct instances of those collections having direct isa TERM"
    '((term el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'map-instances '(function term &optional mt tv)
    "apply FUNCTION to every (least general) #$isa of TERM"
    '((function function-spec-p) (term el-fort-p))
    'nil)

(register-cyc-api-function 'all-isa '(term &optional mt tv)
    "Returns all collections that include TERM (inexpensive)"
    '((term hl-term-p))
    '((list fort-p)))

(register-cyc-api-function 'all-instances '(col &optional mt tv)
    "Returns all instances of COLLECTION (expensive)"
    '((col el-fort-p))
    '((list hl-term-p)))

(register-cyc-api-function 'all-instances-in-all-mts '(collection)
    "@return listp; all instances of COLLECTION in all mts."
    '((collection el-fort-p))
    '((list hl-term-p)))

(register-cyc-api-function 'all-isas-wrt '(term isa &optional mt tv)
    "Returns all isa of term TERM that are also instances of collection ISA (ascending transitive closure; inexpensive)"
    '((term el-fort-p) (isa el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'union-all-isa '(terms &optional mt tv)
    "Returns all collections that include any term in TERMS (inexpensive)"
    '((terms listp))
    '((list fort-p)))

(register-cyc-api-function 'union-all-instances '(cols &optional mt tv)
    "Returns set of all instances of each collection in COLS (expensive)"
    '((cols listp))
    '((list fort-p)))

(register-cyc-api-function 'all-isa-among '(term collections &optional mt tv)
    "Returns those elements of COLLECTIONS that include TERM as an all-instance"
    '((term hl-term-p) (collections listp))
    '((list fort-p)))

(register-cyc-api-function 'all-instances-among '(col terms &optional mt tv)
    "Returns those elements of TERMS that include COL as an all-isa"
    '((col hl-term-p) (terms listp))
    '((list hl-term-p)))

(register-cyc-api-function 'all-not-isa '(term &optional mt tv)
    "Returns all collections that do not include TERM (expensive)"
    '((term hl-term-p))
    '((list fort-p)))

(register-cyc-api-function 'all-not-instances '(col &optional mt tv)
    "Returns all terms that are not members of col (by assertion)"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'not-isa-among '(term collections &optional mt tv)
    "Returns those elements of COLLECTIONS that do NOT include TERM"
    '((term hl-term-p) (collections listp))
    '((list fort-p)))

(register-cyc-api-function 'map-all-isa '(fn term &optional mt tv)
    "Apply FUNCTION to every all-isa of TERM
   (FUNCTION must not affect the current sbhl search state)"
    '((fn function-spec-p) (term hl-term-p))
    'nil)

(register-cyc-api-function 'map-all-instances '(fn col &optional mt tv)
    "Apply FUNCTION to each unique instance of all specs of COLLECTION."
    '((fn function-spec-p) (col el-fort-p))
    'nil)

(register-cyc-api-function 'any-wrt-all-isa '(function term &optional mt tv)
    "Return the first encountered non-nil result of applying FUNCTION to the all-isa of TERM
   (FUNCTION may not affect the current sbhl search state)"
    '((function function-spec-p) (term hl-term-p))
    'nil)

(register-cyc-api-function 'count-all-instances '(collection &optional mt tv)
    "Counts the number of instances in COLLECTION and then returns the count."
    '((collection el-fort-p))
    '(integerp))

(register-cyc-api-function 'count-all-quoted-instances '(collection &optional mt tv)
    "Counts the number of quoted instances in COLLECTION and then returns the count."
    '((collection el-fort-p))
    '(integerp))

(register-cyc-api-function 'isa? '(term collection &optional mt tv)
    "Returns whether TERM is an instance of COLLECTION via the SBHL, i.e. isa and genls assertions.
@note This function does _not_ use defns to determine membership in COLLECTION.
@see has-type?
@see quiet-has-type?"
    '((collection el-fort-p))
    '(booleanp))

(register-cyc-api-function 'isa-in-mts? '(term collection mts)
    "is <term> an element of <collection> via assertions in any mt in <mts>"
    '((collection el-fort-p))
    '(booleanp))

(register-cyc-api-function 'isa-in-any-mt? '(term collection)
    "is <term> an element of <collection> in any mt"
    'nil
    '(booleanp))

(register-cyc-api-function 'any-isa? '(term collections &optional mt tv)
    "Returns whether TERM is an instance of any collection in COLLECTIONS"
    '((term hl-term-p) (collections listp))
    '(booleanp))

(register-cyc-api-function 'isa-any? '(term collections &optional mt tv)
    "Returns whether TERM is an instance of any collection in COLLECTIONS"
    '((term hl-term-p) (collections listp))
    '(booleanp))

(register-cyc-api-function 'any-isa-any? '(terms collections &optional mt tv)
    "@return booleanp; whether any term in TERMS is an instance of any collection in COLLECTIONS"
    '((terms listp) (collections listp))
    '(booleanp))

(register-cyc-api-function 'not-isa? '(term collection &optional mt tv)
    "@return booleanp; whether TERM is known to not be an instance of COLLECTION"
    '((term hl-term-p) (collection el-fort-p))
    '(booleanp))

(register-cyc-api-function 'why-isa? '(term collection &optional mt tv behavior)
    "Returns justification of (isa TERM COLLECTION)"
    '((term hl-term-p) (collection el-fort-p))
    '(listp))

(register-cyc-api-function 'why-not-isa? '(term collection &optional mt tv behavior)
    "Returns justification of (not (isa TERM COLLECTION))"
    '((term hl-term-p) (collection el-fort-p))
    '(listp))

(register-cyc-api-function 'instances? '(collection &optional mt tv)
    "Returns whether COLLECTION has any direct instances"
    '((collection el-fort-p))
    '(booleanp))

(register-cyc-api-function 'max-floor-mts-of-isa-paths '(term collection &optional tv)
    "Returns in what (most-genl) mts TERM is an instance of COLLECTION"
    '((term hl-term-p) (collection el-fort-p))
    'nil)

(register-cyc-api-function 'quoted-isa? '(term collection &optional mt tv)
    "Returns whether TERM is a quoted instance of COLLECTION via the SBHL, i.e. quotedIsa and genls assertions.
@note This function does _not_ use defns to determine membership in COLLECTION.
@see has-type?
@see quiet-has-type?"
    '((collection el-fort-p))
    '(booleanp))

(register-cyc-api-function 'quoted-isa-in-any-mt? '(term collection)
    "is <term> an element of <collection> in any mt"
    'nil
    '(booleanp))

(register-cyc-api-function 'any-quoted-isa? '(term collections &optional mt tv)
    "Returns whether TERM is an instance of any collection in COLLECTIONS"
    '((term hl-term-p) (collections listp))
    '(booleanp))

(register-cyc-api-function 'quoted-isa-any? '(term collections &optional mt tv)
    "Returns whether TERM is an instance of any collection in COLLECTIONS"
    '((term hl-term-p) (collections listp))
    '(booleanp))

(register-cyc-api-function 'all-quoted-isa? '(term collections &optional mt tv)
    "Returns whether TERM is a quoted instance of all collections in COLLECTIONS"
    '((term hl-term-p) (collections listp))
    '(booleanp))

(register-cyc-api-function 'not-quoted-isa? '(term collection &optional mt tv)
    "@return booleanp; whether TERM is known to not be an instance of COLLECTION"
    '((term hl-term-p) (collection el-fort-p))
    '(booleanp))

(register-cyc-api-function 'quoted-instances '(col &optional mt (tv constant_handles.reader_make_constant_shell(makeString("True-JustificationTruth"))))
    "Returns the asserted instances of COL"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'union-all-quoted-instances '(cols &optional mt tv)
    "Returns set of all quoted instances of each collection in COLS (expensive)"
    '((cols listp))
    '((list fort-p)))

(register-cyc-api-function 'map-all-quoted-isa '(fn term &optional mt tv)
    "Apply FUNCTION to every all-quoted-isa of TERM
   (FUNCTION must not affect the current sbhl search state)"
    '((fn function-spec-p) (term hl-term-p))
    'nil)

(register-cyc-api-function 'all-quoted-isa '(term &optional mt tv)
    "Returns all collections that include TERM (inexpensive)"
    '((term hl-term-p))
    '((list fort-p)))

(register-cyc-api-function 'all-quoted-isas-wrt '(term isa &optional mt tv)
    "Returns all isa of term TERM that are also instances of collection ISA (ascending transitive closure; inexpensive)"
    '((term el-fort-p) (isa el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'all-quoted-instances '(col &optional mt tv)
    "Returns all instances of COLLECTION (expensive)"
    '((col el-fort-p))
    '((list fort-p)))

(register-cyc-api-function 'all-quoted-isa-among '(term collections &optional mt tv)
    "Returns those elements of COLLECTIONS that include TERM as an all-quoted-instance"
    '((term hl-term-p) (collections listp))
    '((list fort-p)))

(register-cyc-api-function 'initialize-java-api-lease-monitor 'nil
    "Initialize the process which monitors lease expirations for java api clients."
    'nil
    'nil)

(register-cyc-api-function 'halt-java-api-lease-monitor 'nil
    "Halt the the process which monitors lease expirations for java api clients."
    'nil
    'nil)

(register-cyc-api-function 'release-resources-for-java-api-client '(uuid-string &optional abnormal?)
    "Closes the outbound api socket and kills active api requests identified by the given uuid-string.
   @param uuid-string ; stringp
   @param abnormal?   ; boolean Whether or not the release was abnormal or expected"
    '((uuid-string stringp))
    '(nil))

(register-cyc-api-function 'acquire-api-services-lease '(lease-duration-in-milliseconds uuid-string)
    "Requests an API services lease.  Typical leases are expected to be 10 minutes.  A lease request
   for a duration longer than one hour is denied.
   @param lease-duration-in-milliseconds ; integerp, the lease duration in milliseconds
   @param uuid-string ; stringp, identifies the java api client"
    '((lease-duration-in-milliseconds integerp) (uuid-string stringp))
    '(stringp))

(register-cyc-api-function 'show-java-api-service-leases 'nil
    "Displays the current java api leases."
    'nil
    '(nil))

(register-cyc-api-function 'initialize-java-api-passive-socket '(uuid-string)
    "Associates the current socket with the given UUID-STRING, then ends this server process
that currently uses the socket."
    '((uuid-string stringp))
    '(nil))

(register-cyc-api-function 'close-java-api-socket '(uuid-string)
    "Closes the persistent cfasl socket that is associated with 
the given UUID-STRING."
    '((uuid-string stringp))
    '(nil))

(register-cyc-api-function 'show-java-api-sockets 'nil
    "Displays the java api sockets."
    'nil
    '(nil))

(register-cyc-api-function 'reset-java-api-kernel 'nil
    "Reset this subsystem to an un-initialized state."
    'nil
    'nil)

(register-cyc-api-function 'relation? '(relation)
    "Return T iff RELATION is a relationship."
    'nil
    '(booleanp))

(register-cyc-api-function 'reflexive-predicate? '(predicate)
    "Return T iff PREDICATE is a reflexive predicate."
    'nil
    '(booleanp))

(register-cyc-api-function 'irreflexive-predicate? '(predicate)
    "Return T iff PREDICATE is an irreflexive predicate."
    'nil
    '(booleanp))

(register-cyc-api-function 'symmetric-predicate? '(predicate)
    "Return T iff PREDICATE is a symmetric predicate."
    'nil
    '(booleanp))

(register-cyc-api-function 'asymmetric-predicate? '(predicate)
    "Return T iff PREDICATE is an asymmetric predicate."
    'nil
    '(booleanp))

(register-cyc-api-function 'anti-symmetric-predicate? '(predicate)
    "Return T iff PREDICATE is an anti-symmetric predicate."
    'nil
    '(booleanp))

(register-cyc-api-function 'transitive-predicate? '(predicate)
    "Return T iff PREDICATE is a transitive predicate."
    'nil
    '(booleanp))

(register-cyc-api-function 'commutative-function? '(function)
    "Return T iff FUNCTION is a commutative function."
    'nil
    '(booleanp))

(register-cyc-api-function 'binary-predicate? '(predicate)
    "Return T iff PREDICATE is a predicate of arity 2."
    'nil
    '(booleanp))

(register-cyc-api-function 'individual? '(term)
    "Return T iff TERM is an individual (i.e., *not* a collection)."
    'nil
    '(booleanp))

(register-cyc-api-function 'set-or-collection? '(term)
    "Return T iff TERM is a set or collection (i.e., *not* an individual)."
    'nil
    '(booleanp))

(register-cyc-api-function 'argn-isa '(relation argnum &optional mt)
    "Returns a list of the local isa constraints applied to the ARGNUMth argument of 
RELATION (#$argsIsa conjoins with #$arg1Isa et al)."
    '((argnum integerp))
    'nil)

(register-cyc-api-function 'argn-quoted-isa '(relation argnum &optional mt)
    "Returns a list of the local isa constraints applied to the ARGNUMth argument of 
RELATION (#$argsIsa conjoins with #$arg1Isa et al)."
    '((argnum integerp))
    'nil)

(register-cyc-api-function 'min-argn-isa '(relation n &optional mt)
    "Returns a list of the most specific local isa-constraints applicable 
to argument N of RELATION."
    '((relation indexed-term-p) (n integerp))
    '((list indexed-term-p)))

(register-cyc-api-function 'argn-isa-of '(collection argnum &optional mt)
    "Returns the relations for which COLLECTION is a 
local isa constraint applied to argument ARGNUM."
    '((argnum integerp))
    '((list indexed-term-p)))

(register-cyc-api-function 'argn-genl '(relation argnum &optional mt)
    "Returns the local genl constraints applied to the ARGNUMth argument of RELATION."
    '((argnum integerp))
    '((list indexed-term-p)))

(register-cyc-api-function 'min-argn-genl '(relation n &optional mt)
    "Return a list of the most specific local genl constraints applicable 
to the argument N of RELATION."
    '((n integerp))
    '((list fort-p)))

(register-cyc-api-function 'argn-genl-of '(collection argnum &optional mt)
    "Returns a list of the predicates for which COLLECTION is a 
local genl constraint applied to the Nth argument."
    '((argnum integerp))
    '((list fort-p)))

(register-cyc-api-function 'inter-arg-isa1-2 '(relation &optional mt)
    "return a list of pairs of (<arg1-isa> <arg2-isa>) that are 
the #$interArgIsa1-2 constraints of RELATION"
    'nil
    '((list listp)))

(register-cyc-api-function 'defining-defns '(col &optional mt)
    "Return a list of the local defining (necessary and sufficient definitions) of collection COL."
    'nil
    '((list fort-p)))

(register-cyc-api-function 'necessary-defns '(col &optional mt)
    "Return a list of the local necessary definitions of collection COL."
    'nil
    '((list fort-p)))

(register-cyc-api-function 'sufficient-defns '(col &optional mt)
    "Return a list of the local sufficient definitions of collection COL."
    'nil
    '((list fort-p)))

(register-cyc-api-function 'all-sufficient-defns '(col &optional mt)
    "Return a list of all sufficient definitions of collection COL."
    'nil
    '((list fort-p)))

(register-cyc-api-function 'result-isa '(functor &optional mt)
    "Return a list of the collections that include as instances 
the results of non-predicate function constant FUNCTOR."
    'nil
    '((list fort-p)))

(register-cyc-api-function 'evaluation-result-quoted-isa '(functor &optional mt)
    "return the collections that include as quoted instances the evaluation results of non-predicate function constant FUNCTOR."
    'nil
    '((list fort-p)))

(register-cyc-api-function 'result-quoted-isa '(functor &optional mt)
    "return the collections that include as quoted instances the results of non-predicate function constant FUNCTOR."
    'nil
    '((list fort-p)))

(register-cyc-api-function 'reviewer '(fort &optional (mt constant_handles.reader_make_constant_shell(makeString("BookkeepingMt"))))
    "Identify the cyclist who reviewed FORT."
    '((fort fort-p) (mt hlmt-p))
    '(fort-p))

(register-cyc-api-function 'comment '(fort &optional mt)
    "Return the comment string for FORT."
    '((fort fort-p))
    '(stringp))

(register-cyc-api-function 'all-term-assertions '(term &optional remove-duplicates?)
    "Return a list of all the assertions indexed via the indexed term TERM."
    '((term indexed-term-p))
    '((list assertion-p)))

(register-cyc-api-function 'isa-relevant-assertions '(term &optional mt)
    "Return a list of all (e.g., inheritance) rules relevant to TERM 
by virtue of the collections of which it is an instance."
    'nil
    '((list assertion-p)))

(register-cyc-api-function 'isa-relevant-assertions-wrt-type '(term collection &optional mt)
    "Returns a list of all (e.g., inheritance) rules that may apply 
to TERM by virtue of it being an instance of COLLECTION."
    'nil
    '((list assertion-p)))

(register-cyc-api-macro 'do-gafs-wrt-pred-type '((assertion-var term pred-type &key mt truth done) &body body)
    "iterate over every gaf assertion mentioning TERM and having as a predicate some instance of PRED-TYPE")

(register-cyc-api-function 'indexed-term-p '(object)
    "Returns T iff OBJECT is an indexed CycL term, e.g. a fort or assertion."
    'nil
    '(booleanp))

(register-cyc-api-function 'num-gaf-arg-index '(term &optional argnum pred mt)
    "Return the number of gafs indexed off of TERM ARGNUM PRED MT."
    'nil
    '(integerp))

(register-cyc-api-function 'relevant-num-gaf-arg-index '(term &optional argnum pred)
    "Return the assertion count at relevant mts under TERM ARGNUM PRED."
    'nil
    '(integerp))

(register-cyc-api-function 'key-gaf-arg-index '(term &optional argnum pred)
    "Return a list of the keys to the next index level below TERM ARGNUM PRED.
   @note destructible"
    'nil
    '(listp))

(register-cyc-api-function 'num-nart-arg-index '(term &optional argnum func)
    "Return the number of #$termOfUnit gafs indexed off of TERM ARGNUM FUNC."
    'nil
    '(integerp))

(register-cyc-api-function 'relevant-num-nart-arg-index '(term &optional argnum func)
    "Compute the assertion count at relevant mts under TERM ARGNUM FUNC.
   This will be the entire count extent if *tou-mt* is relevant,
   and zero otherwise."
    'nil
    '(integerp))

(register-cyc-api-function 'key-nart-arg-index '(term &optional argnum func)
    "Return a list of the keys to the next index level below TERM ARGNUM FUNC."
    'nil
    '(listp))

(register-cyc-api-function 'num-predicate-extent-index '(pred &optional mt)
    "Return the assertion count at PRED MT."
    'nil
    '(integerp))

(register-cyc-api-function 'relevant-num-predicate-extent-index '(pred)
    "Compute the assertion count at relevant mts under PRED."
    'nil
    '(integerp))

(register-cyc-api-function 'key-predicate-extent-index '(pred)
    "Return a list of the keys to the next predicate-extent index level below PRED."
    'nil
    '(listp))

(register-cyc-api-function 'num-function-extent-index '(func)
    "Return the function extent of FUNC."
    'nil
    '(integerp))

(register-cyc-api-function 'relevant-num-function-extent-index '(func)
    "Compute the function extent at relevant mts under FUNC.
   This will be the entire function extent if *tou-mt* is relevant,
   and zero otherwise."
    'nil
    '(integerp))

(register-cyc-api-function 'num-predicate-rule-index '(pred &optional sense mt direction)
    "Return the raw assertion count at PRED SENSE MT DIRECTION."
    'nil
    '(integerp))

(register-cyc-api-function 'key-predicate-rule-index '(pred &optional sense mt)
    "Return a list of the keys to the next index level below PRED SENSE MT."
    'nil
    '(listp))

(register-cyc-api-function 'num-decontextualized-ist-predicate-rule-index '(pred &optional sense direction)
    "Return the raw assertion count at PRED SENSE DIRECTION."
    'nil
    '(integerp))

(register-cyc-api-function 'key-decontextualized-ist-predicate-rule-index '(pred &optional sense)
    "Return a list of the keys to the next index level below PRED SENSE."
    'nil
    '(listp))

(register-cyc-api-function 'num-isa-rule-index '(col &optional sense mt direction)
    "Return the raw assertion count at COL SENSE MT DIRECTION."
    'nil
    '(integerp))

(register-cyc-api-function 'key-isa-rule-index '(col &optional sense mt)
    "Return a list of the keys to the next index level below COL SENSE MT."
    'nil
    '(listp))

(register-cyc-api-function 'num-quoted-isa-rule-index '(col &optional sense mt direction)
    "Return the raw assertion count at COL SENSE MT DIRECTION."
    'nil
    '(integerp))

(register-cyc-api-function 'key-quoted-isa-rule-index '(col &optional sense mt)
    "Return a list of the keys to the next index level below COL SENSE MT."
    'nil
    '(listp))

(register-cyc-api-function 'num-genls-rule-index '(col &optional sense mt direction)
    "Return the raw assertion count at COL SENSE MT DIRECTION."
    'nil
    '(integerp))

(register-cyc-api-function 'key-genls-rule-index '(col &optional sense mt)
    "Return a list of the keys to the next index level below COL SENSE MT."
    'nil
    '(listp))

(register-cyc-api-function 'num-genl-mt-rule-index '(col &optional sense mt direction)
    "Return the raw assertion count at COL SENSE MT DIRECTION."
    'nil
    '(integerp))

(register-cyc-api-function 'key-genl-mt-rule-index '(col &optional sense mt)
    "Return a list of the keys to the next index level below COL SENSE MT."
    'nil
    '(listp))

(register-cyc-api-function 'num-function-rule-index '(func &optional mt direction)
    "Return the raw assertion count at FUNC MT DIRECTION."
    'nil
    '(integerp))

(register-cyc-api-function 'key-function-rule-index '(func &optional mt)
    "Return a list of the keys to the next index level below FUNC MT."
    'nil
    '(listp))

(register-cyc-api-function 'num-exception-rule-index '(rule &optional mt direction)
    "Return the raw assertion count at RULE MT DIRECTION."
    'nil
    '(integerp))

(register-cyc-api-function 'key-exception-rule-index '(rule &optional mt)
    "Return a list of the keys to the next index level below RULE MT."
    'nil
    '(listp))

(register-cyc-api-function 'num-pragma-rule-index '(rule &optional mt direction)
    "Return the raw assertion count at RULE MT DIRECTION."
    'nil
    '(integerp))

(register-cyc-api-function 'key-pragma-rule-index '(rule &optional mt)
    "Return a list of the keys to the next index level below RULE MT."
    'nil
    '(listp))

(register-cyc-api-function 'num-mt-index '(term)
    "Return the number of assertions at the mt index for TERM."
    'nil
    '(integerp))

(register-cyc-api-function 'num-other-index '(term)
    "Return the number of assertions at the other index for TERM."
    'nil
    '(integerp))

(register-cyc-api-function 'num-index '(term)
    "The total number of assertions indexed from TERM."
    'nil
    '(integerp))

(register-cyc-api-function 'remove-term-indices '(term)
    "Remove all assertions about TERM from the KB. Return the TERM."
    'nil
    '(indexed-term-p))

(register-cyc-api-function 'find-assertion '(cnf mt)
    "Find the assertion in MT with CNF.  Return NIL if not present."
    '((cnf cnf-p) (mt hlmt-p))
    '((nil-or assertion-p)))

(register-cyc-api-function 'find-assertion-any-mt '(cnf)
    "Find any assertion in any mt with CNF.  Return NIL if none are present."
    '((cnf cnf-p))
    '((nil-or assertion-p)))

(register-cyc-api-function 'find-all-assertions '(cnf)
    "Return all assertions that have CNF or NIL if there aren't any.
   @note destructible"
    '((cnf cnf-p))
    '((nil-or (list assertion-p))))

(register-cyc-api-function 'find-gaf '(gaf-formula mt)
    "Find the assertion in MT with GAF-FORMULA as its formula.  Return NIL if not present."
    '((gaf-formula el-formula-p) (mt hlmt-p))
    '((nil-or assertion-p)))

(register-cyc-api-function 'find-gaf-any-mt '(gaf-formula)
    "Find any assertion in any mt with GAF-FORMULA as its formula.  Return NIL if not present."
    '((gaf-formula el-formula-p))
    '((nil-or assertion-p)))

(register-cyc-api-function 'find-all-gafs '(gaf-formula)
    "Return all assertions of GAF-FORMULA or NIL if there aren't any.
   @note destructible"
    '((gaf-formula el-formula-p))
    '((nil-or (list assertion-p))))

(register-cyc-api-function 'map-term '(function term)
    "Apply FUNCTION to each assertion indexed from TERM."
    '((function function-spec-p))
    '(null))

(register-cyc-api-function 'map-term-selective '(function term test &optional truth)
    "Apply FUNCTION to each assertion indexed from TERM with TRUTH that passes TEST.
  If TRUTH is nil, all assertions are mapped."
    '((function function-spec-p) (test function-spec-p))
    '(null))

(register-cyc-api-function 'map-term-gafs '(function term &optional truth)
    "Apply FUNCTION to every gaf indexed from TERM.
   If TRUTH is nil, all assertions are mapped."
    '((function function-spec-p))
    '(null))

(register-cyc-api-function 'map-mt-contents '(function term &optional truth gafs-only)
    "Apply FUNCTION to each assertion with TRUTH in MT TERM.
   If TRUTH is nil, all assertions are mapped.
   If GAFS-ONLY, then only gafs are mapped."
    '((function function-spec-p))
    '(null))

(register-cyc-api-function 'map-mt-index '(function mt &optional truth gafs-only)
    "Apply FUNCTION to each assertion with TRUTH at mt index MT.
   If TRUTH is nil, all assertions are mapped.
   If GAFS-ONLY, then only gafs are mapped."
    '((function function-spec-p))
    '(null))

(register-cyc-api-function 'map-other-index '(function term &optional truth gafs-only)
    "Apply FUNCTION to each assertion with TRUTH at other index TERM.
   If TRUTH is nil, all assertions are mapped.
   If GAFS-ONLY, then only gafs are mapped."
    '((function function-spec-p))
    '(null))

(register-cyc-api-function 'gather-index '(term &optional remove-duplicates?)
    "Return a list of all mt-relevant assertions indexed via TERM.
If REMOVE-DUPLICATES? is non-nil, assertions are guaranteed to only be listed once."
    'nil
    '((list assertion-p)))

(register-cyc-api-function 'gather-index-in-any-mt '(term &optional remove-duplicates?)
    "Return a list of all assertions indexed via TERM.
If REMOVE-DUPLICATES? is non-nil, assertions are guaranteed to only be listed once."
    'nil
    '((list assertion-p)))

(register-cyc-api-function 'gather-gaf-arg-index '(term argnum &optional pred mt (truth :true))
    "Return a list of all gaf assertions such that:
a) TERM is its ARGNUMth argument
b) if TRUTH is non-nil, then TRUTH is its truth value
c) if PRED is non-nil, then PRED must be its predicate
d) if MT is non-nil, then MT must be its microtheory (and PRED must be non-nil)."
    '((argnum positive-integer-p))
    '((list assertion-p)))

(register-cyc-api-function 'gather-nart-arg-index '(term argnum &optional func)
    "Return a list of all #$termOfUnit assertions with a naut arg2 such that:
a) TERM is its ARGNUMth argument
b) if FUNC is non-nil, then FUNC must be its functor"
    '((argnum positive-integer-p))
    '((list assertion-p)))


(register-cyc-api-function 'gather-predicate-extent-index '(pred &optional mt (truth :true))
    "Return a list of all gaf assertions such that:
a) PRED is its predicate
b) if TRUTH is non-nil, then TRUTH is its truth value
c) if MT is non-nil, then MT must be its microtheory."
    'nil
    '((list assertion-p)))


(register-cyc-api-function 'gather-function-extent-index '(func)
    "Return a list of all #$termOfUnit assertions such that:
FUNC is the functor of the naut arg2."
    'nil
    '((list assertion-p)))


(register-cyc-api-function 'gather-predicate-rule-index '(pred sense &optional mt direction)
    "Return a list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has PRED as a predicate in a positive literal
b) if SENSE is :neg, it has PRED as a predicate in a negative literal
c) if MT is non-nil, then MT must be its microtheory
d) if DIRECTION is non-nil, then DIRECTION must be its direction."
    '((sense sense-p))
    '((list assertion-p)))


(register-cyc-api-function 'gather-decontextualized-ist-predicate-rule-index '(pred sense &optional direction)
    "Return a list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has PRED as a predicate in a positive literal wrapped in #$ist
b) if SENSE is :neg, it has PRED as a predicate in a negative literal wrapped in #$ist
c) if DIRECTION is non-nil, then DIRECTION must be its direction."
    '((sense sense-p))
    '((list assertion-p)))


(register-cyc-api-function 'gather-isa-rule-index '(collection sense &optional mt direction)
    "Return a list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has a positive literal of the form (isa <whatever> COLLECTION)
b) if SENSE is :neg, it has a negative literal of the form (isa <whatever> COLLECTION)
c) if MT is non-nil, then MT must be its microtheory
d) if DIRECTION is non-nil, then DIRECTION must be its direction."
    '((sense sense-p))
    '((list assertion-p)))


(register-cyc-api-function 'gather-quoted-isa-rule-index '(collection sense &optional mt direction)
    "Return a list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has a positive literal of the form (quotedIsa <whatever> COLLECTION)
b) if SENSE is :neg, it has a negative literal of the form (quotedIsa <whatever> COLLECTION)
c) if MT is non-nil, then MT must be its microtheory
d) if DIRECTION is non-nil, then DIRECTION must be its direction."
    '((sense sense-p))
    '((list assertion-p)))


(register-cyc-api-function 'gather-genls-rule-index '(collection sense &optional mt direction)
    "Return a list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has a positive literal of the form (genls <whatever> COLLECTION)
b) if SENSE is :neg, it has a negative literal of the form (genls <whatever> COLLECTION)
c) if MT is non-nil, then MT must be its microtheory
d) if DIRECTION is non-nil, then DIRECTION must be its direction."
    '((sense sense-p))
    '((list assertion-p)))


(register-cyc-api-function 'gather-genl-mt-rule-index '(genl-mt sense &optional rule-mt direction)
    "Return a list of all non-gaf assertions (rules) such that:
a) if SENSE is :pos, it has a positive literal of the form (genlMt <whatever> GENL-MT)
b) if SENSE is :neg, it has a negative literal of the form (genlMt <whatever> GENL-MT)
c) if RULE-MT is non-nil, then RULE-MT must be its microtheory
d) if DIRECTION is non-nil, then DIRECTION must be its direction."
    '((sense sense-p))
    '((list assertion-p)))


(register-cyc-api-function 'gather-function-rule-index '(func &optional mt direction)
    "Return a list of all non-gaf assertions (rules) such that:
a) it has a negative literal of the form (termOfUnit <whatever> (FUNC . <whatever>))
b) if MT is non-nil, then MT must be its microtheory
c) if DIRECTION is non-nil, then DIRECTION must be its direction."
    'nil
    '((list assertion-p)))


(register-cyc-api-function 'gather-exception-rule-index '(rule &optional mt direction)
    "Return a list of all non-gaf assertions (rules) such that:
a) it has a positive literal of the form (abnormal <whatever> RULE)
b) if MT is non-nil, then MT must be its microtheory
c) if DIRECTION is non-nil, then DIRECTION must be its direction."
    'nil
    '((list assertion-p)))


(register-cyc-api-function 'gather-pragma-rule-index '(rule &optional mt direction)
    "Return a list of all non-gaf assertions (rules) such that:
a) it has a positive literal of the form (meetsPragmaticRequirement <whatever> RULE)
b) if MT is non-nil, then MT must be its microtheory
c) if DIRECTION is non-nil, then DIRECTION must be its direction."
    'nil
    '((list assertion-p)))


(register-cyc-api-function 'gather-mt-index '(term)
    "Return a list of all assertions such that TERM is its microtheory."
    'nil
    '((list assertion-p)))


(register-cyc-api-function 'gather-other-index '(term)
    "Return a list of other assertions mentioning TERM but not indexed in any other more useful manner."
    'nil
    '((list assertion-p)))


(register-cyc-api-function 'gather-term-assertions '(term &optional mt)
    "Return a list of all mt-relevant assertions of TERM."
    'nil
    '((list assertion-p)))
