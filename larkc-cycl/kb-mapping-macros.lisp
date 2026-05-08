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

;; DESIGN - abstracted the serious repetition and massive symbol names into a large macro. Hopefully this all works. I couldn't tell which macro this came from, so made my own.

;; TODO - this file has DO- macros for each iterator type in here. Implement them.

;; TODO - put warnings or deprecation in incomplete iterator definitions to ensure nobody uses them


;;; ============================================================
;;; PWHEN filter macros — used inside do-* macro expansions
;;; ============================================================

;; Reconstructed from $list0: (predicate &body body), $sym2: RELEVANT-PRED?
(defmacro pwhen-predicate-is-relevant (predicate &body body)
  "[Cyc] Execute BODY if PREDICATE is relevant."
  `(when (relevant-pred? ,predicate)
     ,@body))

;; Reconstructed from $list3: (mt &body body), $sym4: RELEVANT-MT?
(defmacro pwhen-mt-is-relevant (mt &body body)
  "[Cyc] Execute BODY if MT is relevant."
  `(when (relevant-mt? ,mt)
     ,@body))

;; Reconstructed from $list5: (truth truth-spec &body body), $sym7: TRUTH-RELEVANT-P
(defmacro pwhen-truth-relevant (truth truth-spec &body body)
  "[Cyc] Execute BODY if TRUTH is relevant according to TRUTH-SPEC."
  `(when (truth-relevant-p ,truth ,truth-spec)
     ,@body))

;; Active declareFunction; body not in decompiled Java source.
;; Reconstructed: truth-relevant-p should return whether a truth value matches a truth spec.
;; Evidence: used in PWHEN-TRUTH-RELEVANT to gate assertion filtering by truth value.
;; Pattern: null spec means "any truth is relevant" (consistent with direction-spec pattern below).
(defun truth-relevant-p (truth truth-spec)
  "[Cyc] Return T iff TRUTH is relevant according to TRUTH-SPEC."
  (or (null truth-spec)
      (eq truth truth-spec)))

;; Reconstructed from $list9: (assertion truth &body body), $sym10: ASSERTION-HAS-TRUTH,
;; $sym11: COR, $sym12: NULL  → expansion is (when (or (null truth) (assertion-has-truth assertion truth)) body)
(defmacro pwhen-assertion-has-truth (assertion truth &body body)
  "[Cyc] Execute BODY if ASSERTION has the given TRUTH (or TRUTH is null, meaning no constraint)."
  `(when (or (null ,truth) (assertion-has-truth ,assertion ,truth))
     ,@body))

;; Reconstructed from $list13: (assertion direction-spec &body body), $sym14: ASSERTION-HAS-DIRECTION-SPEC,
;; $sym11: COR, $sym12: NULL  → same pattern as pwhen-assertion-has-truth
(defmacro pwhen-assertion-has-direction-spec (assertion direction-spec &body body)
  "[Cyc] Execute BODY if ASSERTION has the given DIRECTION-SPEC (or DIRECTION-SPEC is null)."
  `(when (or (null ,direction-spec) (assertion-has-direction-spec ,assertion ,direction-spec))
     ,@body))

;; Active declareFunction; body not in decompiled Java source.
;; Reconstructed: checks if a direction spec is valid (a direction or nil).
;; Evidence: arity (1 0), used alongside direction-p in validation contexts.
(defun direction-spec-p (direction-spec)
  "[Cyc] Return T iff DIRECTION-SPEC is a valid direction spec."
  (or (null direction-spec)
      (direction-p direction-spec)))

;; Active declareFunction; body not in decompiled Java source.
;; Reconstructed: checks if an assertion's direction matches the spec.
;; Evidence: used in PWHEN-ASSERTION-HAS-DIRECTION-SPEC with COR/NULL guard.
(defun assertion-has-direction-spec (assertion direction-spec)
  "[Cyc] Return T iff ASSERTION has a direction matching DIRECTION-SPEC."
  (eq direction-spec (assertion-direction assertion)))

;; Reconstructed from $list15: ((var assertions &key truth direction done) &body body),
;; $sym21: DO-LIST, $sym22: PWHEN-ASSERTION-HAS-TRUTH, $sym23: PWHEN-ASSERTION-HAS-DIRECTION-SPEC
(defmacro do-assertion-list ((var assertions &key truth direction done) &body body)
  "[Cyc] Iterate over ASSERTIONS, binding VAR to each assertion matching TRUTH and DIRECTION constraints."
  `(do-list (,var ,assertions :done ,done)
     (pwhen-assertion-has-truth ,var ,truth
       (pwhen-assertion-has-direction-spec ,var ,direction
         ,@body))))

;; Reconstructed from $list24: ((var term &key truth direction done) &body body),
;; $sym25: DO-ASSERTION-LIST, $sym26: DO-SIMPLE-INDEX-TERM-ASSERTION-LIST
(defmacro do-simple-index ((var term &key truth direction done) &body body)
  "[Cyc] Iterate over all assertions for TERM in its simple index."
  `(do-assertion-list (,var (do-simple-index-term-assertion-list ,term)
                            :truth ,truth :direction ,direction :done ,done)
     ,@body))

;; Reconstructed from $list27: (assertion type &body body), $kw28: :GAF, $sym29: GAF-ASSERTION?,
;; $kw30: :RULE, $sym31: RULE-ASSERTION?, $sym32: ASSERTION-HAS-TYPE
(defmacro pwhen-assertion-has-type (assertion type &body body)
  "[Cyc] Execute BODY if ASSERTION has the given TYPE (or TYPE is null)."
  `(when (or (null ,type)
             (case ,type
               (:gaf (gaf-assertion? ,assertion))
               (:rule (rule-assertion? ,assertion))
               (t (assertion-has-type ,assertion ,type))))
     ,@body))

;; Reconstructed from $list33: ((var &key progress-message done) &body body),
;; $sym36: UNTIL-MAPPING-FINISHED, $sym37: SOME-ASSERTIONS-INTERNAL
(defmacro some-assertions ((var &key progress-message done) &body body)
  "[Cyc] Iterate over all assertions binding VAR to each, with optional DONE test."
  `(until-mapping-finished (,done)
     (some-assertions-internal (,var :progress-message ,progress-message)
       ,@body)))

;; Reconstructed from $list40: ((var &key progress-message) &body body), $sym42: DO-ASSERTIONS
(defmacro some-assertions-internal ((var &key progress-message) &body body)
  "[Cyc] Internal iteration over all assertions with optional progress reporting."
  `(do-assertions (,var :progress-message ,progress-message)
     ,@body))

(defmacro define-kb-final-index-spec-iterator (name lambda-list
                                               &key
                                                 ;; list of (name init-form), with lambda-list values in scope
                                                 slots
                                                 singleton-form
                                                 ;; slots are in scope
                                                 done-form
                                                 next-form
                                                 relevant-keylist
                                                 quiesce-step)
  
  (let* ((all-lambda-list-terms (remove '&optional lambda-list))
         (iterator (symbolicate name "-FINAL-INDEX-SPEC-ITERATOR"))
         (state (symbolicate iterator "-STATE"))
         (with (symbolicate "WITH-" iterator))
         (fn-next (symbolicate iterator "-NEXT"))
         (fn-initialize (symbolicate "INITIALIZE-" state))
         (fn-quiesce (symbolicate iterator "-QUIESCE"))
         (fn-quiesce-one-step (symbolicate fn-quiesce "-ONE-STEP")))
    (alexandria:with-gensyms (result done?)
      `(progn
         
         ;; Define the accessors for the state vector
         
         (defstruct (,state (:type vector))
           ,@ (mapcar #'first slots))

         (defmacro ,with (state &body body)
           `(with-accessors ,',(mapcar (lambda (slot)
                                         (let ((name (car slot)))
                                           (list name (symbolicate state "-" name))))
                                       slots)
                ,state
              ,@body))

         ;; Functions
         
         (defun ,(symbolicate "NEW-" name "-FINAL-INDEX-SPEC-ITERATOR") ,lambda-list
           "[Cyc] Makes an iterator which spits out final-index-specs, each of which is a complete path (i.e. a list of keys) leading down to a final index (a list) of assertions."
           (if (simple-indexed-term-p ,(first lambda-list))
               (new-singleton-iterator ,singleton-form)
               (let ((state (,fn-initialize ,@all-lambda-list-terms)))
                 (new-iterator state
                               (lambda (state)
                                 (,with state
                                        ,done-form))
                               #',fn-next))))

         (defun ,fn-initialize ,all-lambda-list-terms
           (declare (ignorable ,@all-lambda-list-terms))
           (vector ,@ (mapcar #'second slots)))

         (defun* ,fn-quiesce-one-step (state) (:inline t)
           (,with state ,quiesce-step))
         
         (defun* ,fn-quiesce (state) (:inline t)
           ;; TODO - there is no <name>-current-keylist as the comments originally referenced
           "[Cyc] Iterates over the keys in STATE until it ends up with its current keylist being valid and relevant, with validity and relevance being determined by :RELEVANT-KEYLIST. It may not need to iterate over any keys in STATE, in which case STATE is left unchanged.
Return 0: The relevant final-index-spec list thus formed, if any.
Return 1: Whether quiescence terminated early due to running out of keys."
           (,with state
                  (let ((,result nil)
                        (,done? nil))
                    (until (or ,result
                               ,done?)
                      (let ((keylist ,relevant-keylist))
                        (if keylist
                            ,(when slots
                               `(,with state
                                       (setf ,result (list* ,(first lambda-list) ,(make-keyword name) keylist))))
                            (setf ,done? (,fn-quiesce-one-step state)))))
                    (values ,result ,done?))))
         
         (defun ,fn-next (state)
           (,with state
                  (multiple-value-bind (final-index-spec done?) (,fn-quiesce state)
                    ,next-form
                    (values final-index-spec done?))))))))











;; GAF-ARG

(define-kb-final-index-spec-iterator gaf-arg (term &optional argnum predicate)
  :slots (;; [Cyc] The input term.
          (term term)
          ;; [Cyc] The input predicate.
          (predicate predicate)
          ;; [Cyc] A note containing information about the state of the keys, used to control code flow.
          (note :argnum-keys-are-fresh)
          ;; [Cyc] The remaining argnums to iterate over.
          (argnum-keys (if argnum
                           (list argnum)
                           (key-gaf-arg-index-cached term)))
          ;; [Cyc] The remaining predicates left to iterate over.
          (predicate-keys nil)
          ;; [Cyc] The remaining MTs left to iterate over.
          (mt-keys nil))

  :singleton-form (new-gaf-simple-final-index-spec term
                                                   (or argnum :any)
                                                   predicate
                                                   nil)
  
  :done-form (or (not argnum-keys)
                 (and (not note)
                      (length= argnum-keys 1)
                      (length<= predicate-keys 1)
                      (not mt-keys)))

  :next-form (pop mt-keys)

  ;; [Cyc] If STATE's current keylist is valid and relevant, returns it. Otherwise returns NIL.
  ;; Valid means that none of its current keys are null.
  ;; Relevant means that all of its current keys (mt and predicate) are deemed relevant (relevance is established from outside).
  :relevant-keylist (when-let ((argnum (first argnum-keys))
                               (predicate-key (first predicate-keys))
                               (mt (first mt-keys)))
                      (if (and (not predicate)
                               (not (relevant-pred? predicate-key)))
                          (progn
                            (setf mt-keys nil)
                            (setf note nil))
                          (and (relevant-mt? mt)
                               (list argnum predicate-key mt))))

  ;; [Cyc] STATE is assumed to be invalid or irrelevant. This function fixes one cause of invalidity or irrelevance.
  ;; Invalidity is caused by having no more pending keys in a slot -- refill them.
  ;; Irrelevance is caused by having the current mt key be irrelevant -- pop it.
  ;; Returns whether we failed to quiesce because we ran out of keys.
  :quiesce-step (or (not argnum-keys)
                    (prog1 nil
                      (cond
                        ((not predicate-keys) (gaf-arg-final-index-spec-iterator-refill-predicate-keys state))
                        ((not mt-keys) (gaf-arg-final-index-spec-iterator-refill-mt-keys state))
                        (t (pop mt-keys))))))





(defun* do-gaf-arg-index-key-validator (term argnum predicate) (:inline t)
  "[Cyc] Return T iff TERM, ARGUM, and PREDICATE are valid keys for DO-GAF-ARG-INDEX."
  ;; TODO - this is in kb-indexing?  move it here
  (gaf-arg-index-key-validator term argnum predicate))



;; TODO - abstract all the refill functions
(defun gaf-arg-final-index-spec-iterator-refill-predicate-keys (state)
  "[Cyc] Refill the predicate-keys by popping an argnum but don't actually pop the argnum if it's fresh, just note that it's unfresh now."
  (with-gaf-arg-final-index-spec-iterator state
    (if (eq :argnum-keys-are-fresh note)
        (setf note nil)
        (pop argnum-keys))
    (when-let ((argnum-key (car argnum-keys)))
      (if predicate
          (setf predicate-keys (list predicate))
          (setf predicate-keys (key-gaf-arg-index-cached term argnum-key)))
      (setf note :predicate-keys-are-fresh))))

(defun gaf-arg-final-index-spec-iterator-refill-mt-keys (state)
  "[Cyc] Refill the mt-keys by popping a predicate but don't actually pop the predicate if it's fresh, just note that it's unfresh now."
  (with-gaf-arg-final-index-spec-iterator state
    (if (eq :predicate-keys-are-fresh note)
        (setf note nil)
        (pop predicate-keys))
    (when-let ((predicate-key (car predicate-keys)))
      (if (only-specified-mt-is-relevant?)
          (setf mt-keys (list *mt*))
          (let ((argnum-key (car argnum-keys)))
            (setf mt-keys (key-gaf-arg-index-cached term argnum-key predicate-key)))))))

;; Reconstructed from kb_mapping_macros.java:
;;   declareMacro(myName, "do_gaf_arg_index", "DO-GAF-ARG-INDEX")
;;   Arglist from $list53: (assertion-var term &key index predicate truth direction done) &body body
;;   Helpers: do-gaf-arg-index-key-validator, new-gaf-arg-final-index-spec-iterator
(defmacro do-gaf-arg-index ((var term &key index predicate truth direction done) &body body)
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-gaf-arg-index-key-validator ,term ,index ,predicate)
       (let ((iterator-var (new-gaf-arg-final-index-spec-iterator ,term ,index ,predicate))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :gaf ,truth ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))

;; Reconstructed from $list63: ((var term gather-index &key index predicate truth direction done) &body body)
;; $sym64: ASSERTION (unintern gensym), $sym65: GAF-ARG, $kw66: :ANY
;; Wraps do-gaf-arg-index to extract a specific GAF argument value.
(defmacro do-gaf-arg-index-values ((var term gather-index &key index predicate truth direction done) &body body)
  "[Cyc] Iterate over values of GATHER-INDEX argument in GAF assertions indexed on TERM."
  (let ((assertion-var (gensym "ASSERTION")))
    `(do-gaf-arg-index (,assertion-var ,term :index ,index :predicate ,predicate
                                              :truth ,truth :direction ,direction :done ,done)
       (let ((,var (gaf-arg ,assertion-var ,gather-index)))
         ,@body))))


;; PREDICATE-EXTENT

(define-kb-final-index-spec-iterator predicate-extent (predicate)
  :slots (;; [Cyc] The input predicate.
          (predicate predicate)
          ;; [Cyc] The remaining MTs left to iterate over.
          (mt-keys (key-predicate-extent-index predicate)))
    
  :singleton-form (new-gaf-simple-final-index-spec predicate
                                                   nil
                                                   predicate
                                                   nil)
  :done-form (not mt-keys)
  :next-form (pop mt-keys)
  ;; [Cyc] If STATE's current keylist is valid and relevant, returns it. Otherwise returns NIL.
  ;; Valid means that none of its current keys are null.
  ;; Relevant means that its MT is deemed relevant (relevance is established from outside).
  :relevant-keylist (when-let ((mt (car mt-keys)))
                      (and (relevant-mt? mt)
                           (list mt))))

(defun* do-predicate-extent-index-key-validator (predicate) (:inline t)
  "[Cyc] Return T iff PREDICATE is a valid key for DO-PREDICATE-EXTENT-INDEX."
  (fort-p predicate))

;; Reconstructed following the do-gaf-arg-index pattern.
;; Helpers: do-predicate-extent-index-key-validator, new-predicate-extent-final-index-spec-iterator
(defmacro do-predicate-extent-index ((var predicate &key truth direction done) &body body)
  "[Cyc] Iterate over all gaf assertions in the predicate extent index of PREDICATE."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-predicate-extent-index-key-validator ,predicate)
       (let ((iterator-var (new-predicate-extent-final-index-spec-iterator ,predicate))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :gaf ,truth ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))




;; NART-ARG

(define-kb-final-index-spec-iterator nart-arg (term &optional argnum function)
  :slots ((term term)
          (function function)
          ;; [Cyc] A note containing information about the state of the keys.
          (note :argnum-keys-are-fresh)
          ;; [Cyc] The remaining argnums to iterate over.
          (argnum-keys (if argnum
                           (list argnum)
                           (key-nart-arg-index term)))
          ;; [Cyc] The remaining functions left to iterate over.
          (function-keys nil))
  :singleton-form (new-nart-simple-final-index-spec term
                                                    (or argnum :any)
                                                    function)
  :done-form (or (not argnum-keys)
                 (and (not note)
                      (length= argnum-keys 1)
                      (not function-keys)))
  ;; TODO - this one is missing a lot
  :next-form (missing-larkc 30408))

(defun do-nart-arg-index-key-validator (term index function)
  "[Cyc] Return T iff TERM, INDEX, and FUNCTION are valid keys for DO-NART-ARG-INDEX."
  (and (indexed-term-p term)
       (or (not index)
           (positive-integer-p index))
       (or (not function)
           (fort-p function))))

;; Implementation taken from kb-mapping.lisp/map-nart-arg-index
;; TODO - since the next-form above is missing-larkc, this likely won't run anyway
(defmacro do-nart-arg-index ((var term &key index function done) &body body)
  ;; TODO - keyword param usage might be off, as they seem to be nil in dependent-narts usage
  (when done
    (error ":done keyword not yet supported in do-nart-arg-index"))
  `(when (do-nart-arg-index-key-validator ,term ,index ,function)
     ;; TODO - extract generic iteration macro in iteration.lisp
     (let ((iterator-var (new-nart-arg-final-index-spec-iterator ,term ,index ,function))
           (done-var nil)
           ;; This is the 'invalid token' return value for the 'next' calls
           (token-var nil))
       (until done-var
         (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                (valid (not (eq token-var final-index-spec))))
           (when valid
             (let ((final-index-iterator nil))
               (unwind-protect (progn
                                 (setf final-index-iterator (new-final-index-iterator final-index-spec :gaf nil nil))
                                 (let ((done-var2 nil)
                                       (token-var2 nil))
                                   (until done-var2
                                     (let* ((,var (iteration-next-without-values-macro-helper final-index-iterator token-var2))
                                            (valid2 (not (eq token-var2 ,var))))
                                       (when valid2
                                         ,@body)
                                       (setf done-var2 (not valid2))))))
                 (when final-index-iterator
                   (destroy-final-index-iterator final-index-iterator)))))
           (setf done-var (not valid)))))))





;; FUNCTION-EXTENT

(defun* do-function-extent-index-key-validator (function) (:inline t)
  "[Cyc] Return T iff FUNCTION is a valid key for DO-FUNCTION-EXTENT-INDEX."
  (fort-p function))

(defun function-extent-final-index-spec (function)
  "[Cyc] Makes the single final-index-spec for FUNCTION. This is the only complete path (i.e. a list of keys) leading down to a final index (a list) of assertions."
  (if (simple-indexed-term-p function)
      (new-gaf-simple-final-index-spec function '(2 0) #$termOfUnit *tou-mt*)
      (list function :function-extent)))

;; From kb-indexing, dependent-narts
(defmacro do-function-extent-index ((var function &key done) &body body)
  ;; TODO - is this the value held in token-var, distinguishing from NIL?
  (when done
    (error ":done keyword not yet supported in do-function-extent-index"))
  ;; This one doesn't have an index spec iterator, just a singular spec
  `(when (do-function-extent-index-key-validator ,function)
     (let ((final-index-spec (function-extent-final-index-spec ,function)))
       ;; TODO - iteration macro, seems to be in a simpler form?
       (let ((final-index-iterator nil))
         (unwind-protect (progn
                           (setf final-index-iterator (new-final-index-iterator final-index-spec :gaf nil nil))
                           (let ((done-var nil)
                                 (token-var nil))
                             (until done-var
                               (let* ((,var (iteration-next-without-values-macro-helper final-index-iterator token-var))
                                      (valid (not (eq token-var ,var))))
                                 (when valid
                                   ,@body)
                                 (setf done-var (not valid))))))
           (when final-index-iterator
             (destroy-final-index-iterator final-index-iterator)))))))





;; PREDICATE-RULE

(define-kb-final-index-spec-iterator predicate-rule (predicate &optional sense direction)
  :slots (;; [Cyc] The input predicate.
          (predicate predicate)
          ;; [Cyc] The input direction
          (direction direction)
          ;; [Cyc] A note containing information about the state of the keys, used to control code flow.
          (note :sense-keys-are-fresh)
          ;; [Cyc] The remaining senses to iterate over.
          (sense-keys (if sense
                          (list sense)
                          (key-predicate-rule-index predicate)))
          ;; [Cyc] The remaining MTs left to iterate over.
          (mt-keys nil)
          ;; [Cyc] The remaining directions left to iterate over.
          (direction-keys nil))

  :singleton-form (new-rule-simple-final-index-spec predicate
                                                    sense
                                                    #'predicate-rule-index-asent-match-p)
  :done-form (or (not sense-keys)
                 (and (not note)
                      (length= sense-keys 1)
                      (length<= mt-keys 1)
                      (not direction-keys)))
  :next-form (pop direction-keys)
  ;; [Cyc] If STATE's current keylist is valid and relevant, returns it. Otherwise returns NIL.
  ;; Valid means that none of its current keys are null.
  ;; Relevant means that its MT is deemed relevant (relevance is established from outside).
  :relevant-keylist (when-let ((sense (car sense-keys))
                               (mt (car mt-keys))
                               (direction (car direction-keys)))
                      (if (relevant-mt? mt)
                          (list sense mt direction)
                          (setf direction-keys nil)))
  :quiesce-step (or (not sense-keys)
                    (prog1 nil
                      (cond
                        ((not mt-keys) (predicate-rule-final-index-spec-iterator-refill-mt-keys state))
                        ((not direction-keys) (predicate-rule-final-index-spec-iterator-refill-direction-keys state))
                        (t (error "PREDICATE-RULE iterator quiescence failed with ~s" state))))))


(defun do-predicate-rule-index-key-validator (predicate sense direction)
  (and (fort-p predicate)
       (or (not sense)
           (sense-p sense))
       (or (not direction)
           (direction-p direction))))


;; Reconstructed following the do-gaf-arg-index pattern, for rule iteration.
;; Helpers: do-predicate-rule-index-key-validator, new-predicate-rule-final-index-spec-iterator
(defmacro do-predicate-rule-index ((var predicate &key sense direction done) &body body)
  "[Cyc] Iterate over all rule assertions in the predicate rule index of PREDICATE."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-predicate-rule-index-key-validator ,predicate ,sense ,direction)
       (let ((iterator-var (new-predicate-rule-final-index-spec-iterator ,predicate ,sense ,direction))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :rule nil ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))

(defun predicate-rule-final-index-spec-iterator-refill-mt-keys (state)
  "[Cyc] Refill the mt-keys by popping a sense but don't actually pop the sense if it's fresh, just note that it's unfresh now."
  (with-predicate-rule-final-index-spec-iterator state
    (if (eq :sense-keys-are-fresh note)
        (setf note nil)
        (pop sense-keys))
    (let ((sense-key (car sense-keys)))
      (when sense-key
        (if (only-specified-mt-is-relevant?)
            (setf mt-keys (list *mt*))
            (setf mt-keys (key-predicate-rule-index predicate sense-key)))
        (setf note :mt-keys-are-fresh)))))

(defun predicate-rule-final-index-spec-iterator-refill-direction-keys (state)
  "[Cyc] Refill the direction-keys by popping an MT but don't actually pop the MT if it's fresh, just note that it's unfresh now."
  (with-predicate-rule-final-index-spec-iterator state
    (if (eq :mt-keys-are-fresh note)
        (setf note nil)
        (pop mt-keys))
    (let ((mt-key (car mt-keys)))
      (when mt-key
        (if direction
            (setf direction-keys (list direction))
            (let ((sense-key (car sense-keys)))
              (setf direction-keys (key-predicate-rule-index predicate sense-key mt-key))))))))






;; DECONTEXTUALIZED-IST

(define-kb-final-index-spec-iterator decontextualized-ist (predicate sense direction)
  :slots (;; [Cyc] The input predicate.
          (predicate predicate)
          ;; [Cyc] The input direction.
          (direction direction)
          ;; [Cyc] A note containing information about the state of the keys, used to control code flow.
          (note :sense-keys-are-fresh)
          ;; [Cyc] The remaining senses to iterate over.
          (sense-keys (if sense
                          (list sense)
                          (key-decontextualized-ist-predicate-rule-index predicate)))
          ;; [Cyc] The remaining directions left to iterate over.
          (direction-keys nil))
  :singleton-form (new-rule-simple-final-index-spec predicate
                                                    sense
                                                    #'decontextualized-ist-predicate-rule-index-asent-match-p)
  :done-form (or (not sense-keys)
                 (and (not note)
                      (length= sense-keys 1)
                      (not direction-keys)))
  :next-form (pop direction-keys)
  :relevant-keylist (when-let ((sense (car sense-keys))
                               (direction (car direction-keys)))
                      (list sense direction))
  :quiesce-step (or (not sense-keys)
                    (prog1 nil
                      (cond
                        ((not direction-keys) (decontextualized-ist-predicate-rule-final-index-spec-iterator-refill-direction-keys state))
                        (t (error "IST-PREDICATE-RULE iterator quiescense failed with ~s" state))))))
  

(defun do-decontextualized-ist-predicate-rule-index-key-validator (predicate sense direction)
  (and (fort-p predicate)
       (or (not sense)
           (sense-p sense))
       (or (not direction)
           (direction-p direction))))

(defun decontextualized-ist-predicate-rule-final-index-spec-iterator-refill-direction-keys (state)
  "[Cyc] Refill the direction-keys by popping a sense but don't actually pop the sense if it's fresh, just note that it's unfresh now."
  (with-decontextualized-ist-final-index-spec-iterator state
    (if (eq :sense-keys-are-fresh note)
        (setf note nil)
        ;; TODO - Was missing-larkc, assuming this is it since our macros filled in all the accessors, and the sense-keys writer was missing in the java
        (pop sense-keys))
    (let ((sense-key (car sense-keys)))
      (when sense-key
        (if direction
            (setf direction-keys (list direction))
            (setf direction-keys (key-decontextualized-ist-predicate-rule-index predicate sense-key)))))))

;; declareMacro "DO-DECONTEXTUALIZED-IST-PREDICATE-RULE-INDEX"; body is missing-larkc.
(defmacro do-decontextualized-ist-predicate-rule-index ((var predicate &key sense direction done) &body body)
  "[Cyc] Iterate over all decontextualized-ist predicate rule assertions for PREDICATE."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-decontextualized-ist-predicate-rule-index-key-validator ,predicate ,sense ,direction)
       (let ((iterator-var (new-decontextualized-ist-final-index-spec-iterator ,predicate ,sense ,direction))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :rule nil ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))



;; ISA-RULE - incomplete

(define-kb-final-index-spec-iterator isa-rule (collection &optional sense direction)
  :singleton-form (new-rule-simple-final-index-spec collection
                                                    sense
                                                    #'isa-rule-index-asent-match-p))

(defun do-isa-rule-index-key-validator (collection sense direction)
  (do-pred-arg2-rule-index-key-validator collection sense direction))

;; declareMacro "DO-ISA-RULE-INDEX"; body is missing-larkc.
;; Reconstructed: routes through pred-arg2-rule with #$isa as the pred.
(defmacro do-isa-rule-index ((var collection &key sense direction done) &body body)
  "[Cyc] Iterate over all rule assertions in the isa rule index of COLLECTION."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-isa-rule-index-key-validator ,collection ,sense ,direction)
       (let ((iterator-var (new-isa-rule-final-index-spec-iterator ,collection ,sense ,direction))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :rule nil ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))


;; QUOTED-ISA-RULE - incomplete

(define-kb-final-index-spec-iterator quoted-isa-rule (collection &optional sense direction)
  :singleton-form (new-rule-simple-final-index-spec collection
                                                    sense
                                                    #'quoted-isa-rule-index-asent-match-p))

(defun do-quoted-isa-rule-index-key-validator (collection sense direction)
  (do-pred-arg2-rule-index-key-validator collection sense direction))

;; declareMacro "DO-QUOTED-ISA-RULE-INDEX"; body is missing-larkc.
;; Reconstructed: routes through pred-arg2-rule with #$quotedIsa as the pred.
(defmacro do-quoted-isa-rule-index ((var collection &key sense direction done) &body body)
  "[Cyc] Iterate over all rule assertions in the quoted-isa rule index of COLLECTION."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-quoted-isa-rule-index-key-validator ,collection ,sense ,direction)
       (let ((iterator-var (new-quoted-isa-rule-final-index-spec-iterator ,collection ,sense ,direction))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :rule nil ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))


;; GENLS-RULE - incomplete

(define-kb-final-index-spec-iterator genls-rule (collection &optional sense direction)
  :singleton-form (new-rule-simple-final-index-spec collection
                                                    sense
                                                    #'genls-rule-index-asent-match-p))

(defun do-genls-rule-index-key-validator (collection sense direction)
  (do-pred-arg2-rule-index-key-validator collection sense direction))

;; declareMacro "DO-GENLS-RULE-INDEX"; body is missing-larkc.
(defmacro do-genls-rule-index ((var collection &key sense direction done) &body body)
  "[Cyc] Iterate over all rule assertions in the genls rule index of COLLECTION."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-genls-rule-index-key-validator ,collection ,sense ,direction)
       (let ((iterator-var (new-genls-rule-final-index-spec-iterator ,collection ,sense ,direction))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :rule nil ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))


;; GENL-MT-RULE - incomplete

(define-kb-final-index-spec-iterator genl-mt-rule (genl-mt &optional sense direction)
  :singleton-form (new-rule-simple-final-index-spec genl-mt
                                                    sense
                                                    #'genl-mt-rule-index-asent-match-p))

(defun do-genl-mt-rule-index-key-validator (genl-mt sense direction)
  (do-pred-arg2-rule-index-key-validator genl-mt sense direction))

;; declareMacro "DO-GENL-MT-RULE-INDEX"; body is missing-larkc.
(defmacro do-genl-mt-rule-index ((var genl-mt &key sense direction done) &body body)
  "[Cyc] Iterate over all rule assertions in the genl-mt rule index of GENL-MT."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-genl-mt-rule-index-key-validator ,genl-mt ,sense ,direction)
       (let ((iterator-var (new-genl-mt-rule-final-index-spec-iterator ,genl-mt ,sense ,direction))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :rule nil ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))



;; PRED-ARG2-RULE - semi-incomplete?  there was no new-* function, guessing at lambda list

(define-kb-final-index-spec-iterator pred-arg2-rule (pred top-level-key arg2 sense direction)
  :slots ( ;; [Cyc] The input arg2.
          (arg2 arg2)
          ;; [Cyc] The input direction.
          (direction direction)
          ;; [Cyc] A note containing information about the state of the keys, used to control code flow.
          (note :sense-keys-are-fresh)
          ;; [Cyc] The remaining senses to iterate over.
          (sense-keys (if sense
                          (list sense)
                          (key-pred-arg2-rule-index pred arg2)))
          ;; [Cyc] The remaining MTs left to iterate over.
          (mt-keys nil)
          ;; [Cyc] The remaining directions left to iterate over.
          (direction-keys nil)
          ;; [Cyc] The input pred.
          (pred pred)
          ;; [Cyc] The top-level key to the final index, used for subclassing.
          (top-level-key top-level-key))

  :done-form (or (not sense-keys)
                 (and (not note)
                      (length= sense-keys 1)
                      (length<= mt-keys 1)
                      (not direction-keys)))
  :next-form (pop direction-keys)

  ;; [Cyc] If STATE's current keylist is valid and relevant, returns it. Otherwise returns NIL.
  ;; Valid means that none of its current keys are null.
  ;; Relevant means that its mt is deemed relevant (relevance is established from outside)
  :relevant-keylist (when-let ((sense (car sense-keys))
                          (mt (car mt-keys))
                          (direction (car direction-keys)))
                      (if (relevant-mt? mt)
                          (list sense mt direction)
                          (setf direction-keys nil)))
  ;; [Cyc] STATE is assumed to be invalid or irrelevant.
  ;; This function fixes one cause of invalidity or irrelevance.
  ;; Invalidity is caused by having no more pending keys in a slot -- refill them.
  ;; Irrelevance is caused by having the current mt key be irrelevant -- pop it.
   :quiesce-step (or (not sense-keys)
                    (prog1 nil
                      (cond
                        ((not mt-keys) (pred-arg2-rule-final-index-spec-iterator-refill-mt-keys state))
                        ((not direction-keys) (pred-arg2-rule-final-index-spec-iterator-refill-direction-keys state))
                        (t (error "PRED-ARG2-RULE iterator quiescense failed with ~s" state))))))

(defun do-pred-arg2-rule-index-key-validator (arg2 sense direction)
  (and (fort-p arg2)
       (or (not sense)
           (sense-p sense))
       (or (not direction)
           (direction-p direction))))

(defun pred-arg2-rule-final-index-spec-iterator-refill-mt-keys (state)
  "[Cyc] Refill the mt-keys by popping a sense but don't actually pop the sense if it's fresh, just note that it's unfresh now."
  (with-pred-arg2-rule-final-index-spec-iterator state
    (if (eq :sense-keys-are-fresh note)
        (setf note nil)
        (pop sense-keys))
    (when-let ((sense-key (car sense-keys)))
      (if (only-specified-mt-is-relevant?)
          (setf mt-keys (list *mt*))
          (setf mt-keys (key-pred-arg2-rule-index pred arg2 sense-key)))
      (setf note :mt-keys-are-fresh))))

(defun pred-arg2-rule-final-index-spec-iterator-refill-direction-keys (state)
  "[Cyc] Refill the direction-keys by popping an MT but don't actually pop the MT if it's fresh, just note that it's unfresh now."
  (with-pred-arg2-rule-final-index-spec-iterator state
    (if (eq :mt-keys-are-fresh note)
        (setf note nil)
        (pop mt-keys))
    (when-let ((mt-key (car mt-keys)))
      (if direction
          (setf direction-keys (list direction))
          (let ((sense-key (car sense-keys)))
            (setf direction-keys (key-pred-arg2-rule-index pred arg2 sense-key mt-key)))))))

(defun key-pred-arg2-rule-index (pred arg2 &optional sense mt)
  (case pred
    (#$isa (key-isa-rule-index arg2 sense mt))
    (#$quotedIsa (missing-larkc 12753))
    (#$genls (key-genls-rule-index arg2 sense mt))
    (#$genlMt (key-genl-mt-rule-index arg2 sense mt))
    (t (error "Unexpected pred in PREG-ARG2 indexing: ~s" pred))))




;; FUNCTION-RULE - incomplete?

(define-kb-final-index-spec-iterator function-rule (function &optional direction)
  :slots ((function function)
          (direction direction)
          ;; [Cyc] A note containing information about the state of the keys, used to control code flow.
          (note :mt-keys-are-fresh)
          ;; [Cyc] The remaining MTs left to iterate over.
          (mt-keys (if (only-specified-mt-is-relevant?)
                       (list *mt*)
                       (key-function-rule-index function)))
          ;; [Cyc] The remaining directions left to iterate over.
          (direction-keys nil))
  :singleton-form (new-rule-simple-final-index-spec function
                                                    :neg
                                                    #'function-rule-index-asent-match-p)
  :done-form (or (not mt-keys)
                 (and (not note)
                      (length= mt-keys 1)
                      (not direction-keys)))
  
  )

(defun do-function-rule-index-key-validator (function direction)
  (and (fort-p function)
       (or (not direction)
           (direction-p direction))))

;; declareMacro "DO-FUNCTION-RULE-INDEX"; body is missing-larkc.
(defmacro do-function-rule-index ((var function &key direction done) &body body)
  "[Cyc] Iterate over all rule assertions in the function rule index of FUNCTION."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-function-rule-index-key-validator ,function ,direction)
       (let ((iterator-var (new-function-rule-final-index-spec-iterator ,function ,direction))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :rule nil ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))


;; EXCEPTION-RULE - incomplete, no INITIALIZE- function to get the slot values from

(define-kb-final-index-spec-iterator exception-rule (rule &optional direction)
  :slots ((rule (missing-larkc 30402))
          (direction (missing-larkc 30402)))
  :singleton-form (new-rule-simple-final-index-spec rule
                                                    :pos
                                                    #'exception-rule-index-asent-match-p))

(defun do-exception-rule-index-key-validator (rule direction)
  (and (rule-assertion? rule)
       (or (not direction)
           (direction-p direction))))

;; declareMacro "DO-EXCEPTION-RULE-INDEX"; body is missing-larkc.
(defmacro do-exception-rule-index ((var rule &key direction done) &body body)
  "[Cyc] Iterate over all rule assertions in the exception rule index of RULE."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-exception-rule-index-key-validator ,rule ,direction)
       (let ((iterator-var (new-exception-rule-final-index-spec-iterator ,rule ,direction))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :rule nil ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))


;; PRAGMA-RULE - incomplete, no INITIALIZE- function to get the slot values from

(define-kb-final-index-spec-iterator pragma-rule (rule &optional direction)
  :slots ((rule (missing-larkc 30403))
          (direction (missing-larkc 30403)))
  :singleton-form (new-rule-simple-final-index-spec rule
                                                    :pos
                                                    #'pragma-rule-index-asent-match-p))

(defun do-pragma-rule-index-key-validator (rule direction)
  (and (rule-assertion? rule)
       (or (not direction)
           (direction-p direction))))

;; declareMacro "DO-PRAGMA-RULE-INDEX"; body is missing-larkc.
(defmacro do-pragma-rule-index ((var rule &key direction done) &body body)
  "[Cyc] Iterate over all rule assertions in the pragma rule index of RULE."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-pragma-rule-index-key-validator ,rule ,direction)
       (let ((iterator-var (new-pragma-rule-final-index-spec-iterator ,rule ,direction))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :rule nil ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))


;;; ============================================================
;;; UNBOUND-PREDICATE-RULE — not in original hand-port
;;; ============================================================

;; Active declareFunction; body not in decompiled Java source.
(defun do-unbound-predicate-rule-index-key-validator (sense direction)
  "[Cyc] Return T iff SENSE and DIRECTION are valid keys for DO-UNBOUND-PREDICATE-RULE-INDEX."
  (and (or (not sense)
           (sense-p sense))
       (or (not direction)
           (direction-p direction))))

;; Active declareFunction "NEW-UNBOUND-PREDICATE-RULE-FINAL-INDEX-SPEC-ITERATOR" (0 2);
;; body not in decompiled Java source.  No define-kb-final-index-spec-iterator form
;; exists for this type because the iterator doesn't follow the standard pattern.
;; Stub: would need to iterate over unbound-rule-index keys.
(defun new-unbound-predicate-rule-final-index-spec-iterator (&optional sense direction)
  "[Cyc] Makes an iterator which spits out final-index-specs for unbound predicate rules."
  (declare (ignore sense direction))
  ;; Active declareFunction; body not recovered from LarKC Java
  (new-singleton-iterator nil))

;; declareMacro "DO-UNBOUND-PREDICATE-RULE-INDEX"; body is missing-larkc.
(defmacro do-unbound-predicate-rule-index ((var &key sense direction done) &body body)
  "[Cyc] Iterate over all unbound predicate rule assertions."
  (let ((done-var (gensym "DONE"))
        (token-var (gensym "TOKEN"))
        (final-index-spec (gensym "SPEC"))
        (valid (gensym "VALID"))
        (final-index-iterator (gensym "ITER"))
        (done-var2 (gensym "DONE2"))
        (token-var2 (gensym "TOKEN2"))
        (valid2 (gensym "VALID2")))
    `(when (do-unbound-predicate-rule-index-key-validator ,sense ,direction)
       (let ((iterator-var (new-unbound-predicate-rule-final-index-spec-iterator ,sense ,direction))
             (,done-var ,done)
             (,token-var nil))
         (until ,done-var
           (let* ((,final-index-spec (iteration-next-without-values-macro-helper iterator-var ,token-var))
                  (,valid (not (eq ,token-var ,final-index-spec))))
             (when ,valid
               (let ((,final-index-iterator nil))
                 (unwind-protect
                      (progn
                        (setf ,final-index-iterator
                              (new-final-index-iterator ,final-index-spec :rule nil ,direction))
                        (let ((,done-var2 ,done)
                              (,token-var2 nil))
                          (until ,done-var2
                            (let* ((,var (iteration-next-without-values-macro-helper ,final-index-iterator ,token-var2))
                                   (,valid2 (not (eq ,token-var2 ,var))))
                              (when ,valid2
                                ,@body)
                              (setf ,done-var2 (or (not ,valid2) ,done))))))
                   (when ,final-index-iterator
                     (destroy-final-index-iterator ,final-index-iterator)))))
             (setf ,done-var (or (not ,valid) ,done))))))))






;; MT

(defun do-mt-index-key-validator (mt type)
  (and (fort-p mt)
       (not (broad-mt? mt))
       (or (not type)
           (missing-larkc 32091))))

(defun mt-final-index-spec (mt)
  "[Cyc] Makes the single final-index-spec for MT. This is the only complete path (i.e. a list of keys) leading down to a final index (a list) of assertions."
  (if (simple-indexed-term-p mt)
      (new-assertion-simple-final-index-spec mt #'mt-index-assertion-match-p)
      (list mt :ist)))




;; OTHER

(defun do-other-index-key-validator (term type)
  (and (indexed-term-p term)
       (or (not type)
           (missing-larkc 32092))))

(defun other-final-index-spec (term)
  "[Cyc] Makes the single final-index-spec for TERM. This is the only complete path (i.e. a list of keys) leading down to a final index (a list) of assertions."
  (if (simple-indexed-term-p term)
      (new-assertion-simple-final-index-spec term #'other-index-assertion-match-p)
      (list term :other)))

(defun* other-simple-final-index-spec-p (object) (:inline t)
  (and (eq (car object) :simple)
       ;; TODO - symbol vs function of final-index-spec
       (eq (fourth object) #'other-index-assertion-match-p)))

(defun* other-complex-final-index-spec-p (object) (:inline t)
  (eq :other (second object)))

(defun other-final-index-spec-p (final-index-spec)
  "[Cyc] The other index is the only one that needs to do post-hoc semantic filtering. It's no tonly redundant for ohter indexes, it's INCORRECT in the case of the mt-index. The mt-index needs to NOT do post-hoc semantic filtering, but the ohter index requires it. Therefore, we need to gate it based on whether these assertions came from the other index."
  (or (other-simple-final-index-spec-p final-index-spec)
      (other-complex-final-index-spec-p final-index-spec)))

(defun other-index-assertion-match-p (assertion term)
  (matches-other-index assertion term))

;; From kb-indexing, dependent-narts
(defmacro do-other-index ((var term &key type truth direction done) &body body)
  ;; Body is after a missing-larkc, so is never entered
  (declare (ignore body))
  (when (or truth direction done)
    (error "Unhandled keyword parameters in do-other-index: :TRUTH ~s, :DIRECTION ~s, :DONE ~s" truth direction done))
  ;; TODO - are we multi-evaluating things like TERM?  are these intended to be simple literals/varnames in usage?
  `(when (do-other-index-key-validator ,term ,type)
     (let ((final-index-spec (other-final-index-spec ,term))
           (final-index-iterator nil))
       (unwind-protect (progn
                         (setf final-index-iterator (new-final-index-iterator final-index-spec nil nil nil))
                         (let ((done-var nil)
                               (token-var nil))
                           (until done-var
                             (let* ((,var (iteration-next-without-values-macro-helper final-index-iterator token-var))
                                    (valid (not (eq token-var ,var))))
                               (when valid
                                 (missing-larkc 30388)
                                 ;;,@body
                                 )
                               (setf done-var (not valid))))))
         (when final-index-iterator
           (destroy-final-index-iterator final-index-iterator))))))



;; TERM - unique, doesn't use the define- macro, dispatches to the above iterators

(defun do-term-index-key-validator (term type)
  (and (indexed-term-p term)
       (or (not type)
           (missing-larkc 32093))))

(defun new-term-final-index-spec-iterator (term type)
  "[Cyc] Makes an iterator which spits out final-index-specs, each of which is a complete path (i.e. a list of keys) leading down to a final index (a list) of assertions."
  (let ((iterators nil))
    ;; GAF type
    (when (or (not type)
              (eq :gaf type))
      (when (do-gaf-arg-index-key-validator term nil nil)
        (push (new-gaf-arg-final-index-spec-iterator term) iterators))
      (when (do-predicate-extent-index-key-validator term)
        (push (new-predicate-extent-final-index-spec-iterator term) iterators))
      (when (do-nart-arg-index-key-validator term nil nil)
        (push (new-nart-arg-final-index-spec-iterator term) iterators))
      (when (do-function-extent-index-key-validator term)
        (push (new-singleton-iterator (function-extent-final-index-spec term)) iterators)))

    ;; RULE type
    (when (or (not type)
              (eq :rule type))
      (when (do-predicate-rule-index-key-validator term nil nil)
        (push (new-predicate-rule-final-index-spec-iterator term) iterators))
      (when (do-isa-rule-index-key-validator term nil nil)
        (push (new-isa-rule-final-index-spec-iterator term) iterators))
      (when (do-genls-rule-index-key-validator term nil nil)
        (push (new-genls-rule-final-index-spec-iterator term) iterators))
      (when (do-genl-mt-rule-index-key-validator term nil nil)
        (push (new-genl-mt-rule-final-index-spec-iterator term) iterators))
      (when (do-function-rule-index-key-validator term nil)
        (push (new-function-rule-final-index-spec-iterator term) iterators))
      (when (do-exception-rule-index-key-validator term nil)
        (push (new-exception-rule-final-index-spec-iterator term) iterators))
      (when (do-pragma-rule-index-key-validator term nil)
        (push (new-pragma-rule-final-index-spec-iterator term) iterators)))

    (when (do-mt-index-key-validator term nil)
      (push (new-singleton-iterator (mt-final-index-spec term)) iterators))
    (when (do-other-index-key-validator term nil)
      (push (new-singleton-iterator (other-final-index-spec term)) iterators))

    (new-iterator-iterator (nreverse iterators))))

(defun do-term-index-assertion-match-p (assertion final-index-spec)
  "[Cyc] The :OTHER index is the only one that needs this post-hoc semantic filtering."
  (declare (ignore assertion))
  (if (other-final-index-spec-p final-index-spec)
      (missing-larkc 31124)
      t))

;; Reconstructed from kb_mapping_macros.java constants:
;; $list45 arglist: ((assertion-var final-index-spec type truth direction done) &body body)
;; $sym46 gensym: FINAL-INDEX-ITERATOR
;; Uses: new-final-index-iterator, do-iterator-without-values-internal, destroy-final-index-iterator
(defmacro do-final-index-from-spec ((assertion-var final-index-spec &optional type truth direction done) &body body)
  "Iterate over all assertions in FINAL-INDEX-SPEC, binding ASSERTION-VAR to each."
  (with-temp-vars (final-index-iterator)
    `(let ((,final-index-iterator nil))
       (unwind-protect
            (progn
              (setf ,final-index-iterator (new-final-index-iterator ,final-index-spec ,type ,truth ,direction))
              (do-iterator-without-values-internal (,assertion-var ,final-index-iterator :done ,done)
                ,@body))
         (when ,final-index-iterator
           (destroy-final-index-iterator ,final-index-iterator))))))

;; Reconstructed from kb_mapping_macros.java constants:
;; $list213 arglist: ((var term &key type truth direction done) &body body)
;; $sym57-58 gensyms: PRED-VAR, FINAL-INDEX-SPEC
;; Uses: do-term-index-key-validator, new-term-final-index-spec-iterator,
;;   do-iterator-without-values-internal, do-final-index-from-spec, do-term-index-assertion-match-p
(defmacro do-term-index ((var term &key type truth direction done) &body body)
  "[Cyc] Iterate over all assertions indexed via TERM, binding VAR to each assertion."
  (with-temp-vars (final-index-spec)
    `(when (do-term-index-key-validator ,term ,type)
       (do-iterator-without-values-internal (,final-index-spec (new-term-final-index-spec-iterator ,term ,type))
         (do-final-index-from-spec (,var ,final-index-spec ,type ,truth ,direction ,done)
           (when (do-term-index-assertion-match-p ,var ,final-index-spec)
             ,@body))))))




;; declareMacro "DO-MT-INDEX"; body is missing-larkc.
;; Reconstructed: uses mt-final-index-spec (which exists) to get a single spec, then iterates.
(defmacro do-mt-index ((var mt &key type truth direction done) &body body)
  "[Cyc] Iterate over all assertions in the MT index of MT."
  `(when (do-mt-index-key-validator ,mt ,type)
     (let ((final-index-spec (mt-final-index-spec ,mt)))
       (do-final-index-from-spec (,var final-index-spec ,type ,truth ,direction ,done)
         ,@body))))


;; Active declareFunction; body not in decompiled Java source.
(defun do-broad-mt-index-key-validator (mt type)
  ;; no body; active declareFunction "DO-BROAD-MT-INDEX-KEY-VALIDATOR" (2 0)
  (declare (ignore type))
  (and (fort-p mt)
       (broad-mt? mt)))

;; Active declareFunction; body not in decompiled Java source.
(defun do-broad-mt-index-match-p (assertion type truth direction)
  ;; no body; active declareFunction "DO-BROAD-MT-INDEX-MATCH-P" (4 0)
  (declare (ignore type truth direction assertion))
  ;; Stub: would filter assertions by type/truth/direction in a broad MT context
  t)

;; declareMacro "DO-BROAD-MT-INDEX"; body is missing-larkc.
;; Reconstructed from $list230: ((var mt &key type truth done) &body body)
(defmacro do-broad-mt-index ((var mt &key type truth done) &body body)
  "[Cyc] Iterate over all assertions in the broad MT index of MT."
  (declare (ignore var mt type truth done body))
  ;; declareMacro; body is missing-larkc
  nil)

;; Active declareFunction; body not in decompiled Java source.
(defun do-mt-contents-method (mt)
  ;; no body; active declareFunction "DO-MT-CONTENTS-METHOD" (1 0)
  (declare (ignore mt))
  ;; Returns the method of iteration to use for MT-CONTENTS
  :mt-index)

;; declareMacro "DO-MT-CONTENTS"; body is missing-larkc.
;; Reconstructed from $list240: dispatches between do-mt-index and do-broad-mt-index
(defmacro do-mt-contents ((var mt &key type truth done) &body body)
  "[Cyc] Iterate over all assertions in the mt contents of MT."
  `(case (do-mt-contents-method ,mt)
     (:mt-index (do-mt-index (,var ,mt :type ,type :truth ,truth :done ,done) ,@body))
     (:broad-mt-index (do-broad-mt-index (,var ,mt :type ,type :truth ,truth :done ,done) ,@body))
     (otherwise nil)))

;; declareMacro "DO-OVERLAP-INDEX"; body is missing-larkc.
;; Reconstructed from $list243: ((assertion-var terms &key truth done) &body body)
(defmacro do-overlap-index ((assertion-var terms &key truth done) &body body)
  "[Cyc] Iterate over assertions that overlap between TERMS."
  (declare (ignore assertion-var terms truth done body))
  ;; declareMacro; body is missing-larkc
  nil)

;; declareMacro "DO-BEST-GAF-LOOKUP-INDEX"; body is missing-larkc.
;; Reconstructed from $list246: ((assertion-var asent &key methods truth done) &body body)
(defmacro do-best-gaf-lookup-index ((assertion-var asent &key methods truth done) &body body)
  "[Cyc] Iterate over assertions using the best GAF lookup method for ASENT."
  (declare (ignore assertion-var asent methods truth done body))
  ;; declareMacro; body is missing-larkc
  nil)

;; declareMacro "DO-GAF-LOOKUP-INDEX"; body is missing-larkc.
;; Reconstructed from $list251: ((assertion-var lookup-index &key truth done) &body body)
(defmacro do-gaf-lookup-index ((assertion-var lookup-index &key truth done) &body body)
  "[Cyc] Iterate over assertions using a GAF LOOKUP-INDEX."
  (declare (ignore assertion-var lookup-index truth done body))
  ;; declareMacro; body is missing-larkc
  nil)

;; declareMacro "DO-GLI-VIA-GAF-ARG"; body is missing-larkc (sub-macro of do-gaf-lookup-index)
(defmacro do-gli-via-gaf-arg ((assertion-var lookup-index &key truth done) &body body)
  (declare (ignore assertion-var lookup-index truth done body))
  nil)

;; declareMacro "DO-GLI-VIA-PREDICATE-EXTENT"; body is missing-larkc (sub-macro)
(defmacro do-gli-via-predicate-extent ((assertion-var lookup-index &key truth done) &body body)
  (declare (ignore assertion-var lookup-index truth done body))
  nil)

;; declareMacro "DO-GLI-VIA-OVERLAP"; body is missing-larkc (sub-macro)
(defmacro do-gli-via-overlap ((assertion-var lookup-index &key truth done) &body body)
  (declare (ignore assertion-var lookup-index truth done body))
  nil)


(defun do-gli-extract-method (lookup-index)
  (lookup-index-get-property lookup-index :index-type))

(defun do-gli-vga-extract-keys (lookup-index)
  (values (lookup-index-get-property lookup-index :term)
          (lookup-index-get-property lookup-index :argnum)
          (lookup-index-get-property lookup-index :predicate)))

(defun do-gli-vpe-extract-key (lookup-index)
  (lookup-index-get-property lookup-index :predicate))

;; Active declareFunction; body not in decompiled Java source.
(defun do-gli-method-error (method macro)
  ;; no body; active declareFunction "DO-GLI-METHOD-ERROR" (2 0)
  (error "Unknown GLI method ~s for ~s" method macro))

;; Active declareFunction; body not in decompiled Java source.
(defun do-gli-vo-extract-key (lookup-index)
  ;; no body; active declareFunction "DO-GLI-VO-EXTRACT-KEY" (1 0)
  (lookup-index-get-property lookup-index :terms))

;; declareMacro "DO-BEST-NAT-LOOKUP-INDEX"; body is missing-larkc.
;; Reconstructed from $list276: ((assertion-var nart-hl-formula &key methods done) &body body)
(defmacro do-best-nat-lookup-index ((assertion-var nart-hl-formula &key methods done) &body body)
  "[Cyc] Iterate over assertions using the best NAT lookup method for NART-HL-FORMULA."
  (declare (ignore assertion-var nart-hl-formula methods done body))
  ;; declareMacro; body is missing-larkc
  nil)

;; declareMacro "DO-NAT-LOOKUP-INDEX"; body is missing-larkc.
;; Reconstructed from $list280: ((assertion-var lookup-index &key done) &body body)
(defmacro do-nat-lookup-index ((assertion-var lookup-index &key done) &body body)
  "[Cyc] Iterate over assertions using a NAT LOOKUP-INDEX."
  (declare (ignore assertion-var lookup-index done body))
  ;; declareMacro; body is missing-larkc
  nil)

;; Active declareFunction; body not in decompiled Java source.
(defun do-nli-extract-method (lookup-index)
  ;; no body; active declareFunction "DO-NLI-EXTRACT-METHOD" (1 0)
  ;; Reconstructed by analogy with do-gli-extract-method
  (lookup-index-get-property lookup-index :index-type))

;; Active declareFunction; body not in decompiled Java source.
(defun do-nli-method-error (method macro)
  ;; no body; active declareFunction "DO-NLI-METHOD-ERROR" (2 0)
  (error "Unknown NLI method ~s for ~s" method macro))

;; declareMacro "DO-NLI-VIA-NART-ARG"; body is missing-larkc (sub-macro)
(defmacro do-nli-via-nart-arg ((assertion-var lookup-index &key done) &body body)
  (declare (ignore assertion-var lookup-index done body))
  nil)

;; Active declareFunction; body not in decompiled Java source.
;; Reconstructed by analogy with do-gli-vga-extract-keys
(defun do-nli-vna-extract-keys (lookup-index)
  ;; no body; active declareFunction "DO-NLI-VNA-EXTRACT-KEYS" (1 0)
  (values (lookup-index-get-property lookup-index :term)
          (lookup-index-get-property lookup-index :argnum)
          (lookup-index-get-property lookup-index :functor)))

;; declareMacro "DO-NLI-VIA-FUNCTION-EXTENT"; body is missing-larkc (sub-macro)
(defmacro do-nli-via-function-extent ((assertion-var lookup-index &key done) &body body)
  (declare (ignore assertion-var lookup-index done body))
  nil)

;; Active declareFunction; body not in decompiled Java source.
;; Reconstructed by analogy with do-gli-vpe-extract-key
(defun do-nli-vfe-extract-key (lookup-index)
  ;; no body; active declareFunction "DO-NLI-VFE-EXTRACT-KEY" (1 0)
  (lookup-index-get-property lookup-index :functor))

;; declareMacro "DO-NLI-VIA-OVERLAP"; body is missing-larkc (sub-macro)
(defmacro do-nli-via-overlap ((assertion-var lookup-index &key done) &body body)
  (declare (ignore assertion-var lookup-index done body))
  nil)

;; Active declareFunction; body not in decompiled Java source.
(defun do-nli-vo-extract-key (lookup-index)
  ;; no body; active declareFunction "DO-NLI-VO-EXTRACT-KEY" (1 0)
  (lookup-index-get-property lookup-index :terms))




;; Simple final index spec, tool to compose the above indexes.

(defun simple-final-index-spec-p (final-index-spec)
  (eq :simple (car final-index-spec)))

(defun simple-final-index-spec-term (final-index-spec)
  (second final-index-spec))

(defun new-final-index-iterator (final-index-spec &optional type truth direction)
  "[Cyc] If FINAL-INDEX-SPEC is simple, then get the syntactically filtered list from the other side, then wrap it witha  filter iterator to do the semantic filtering on this side.
If FINAL-INDEX-SPEC is complex, then get the list from the other side. This list is already filtered by type, truth, and direction, and the keys in FINAL-INDEX-SPEC have already been filtered by MT and predicate relevance, so we don't need a filter."
  (if (simple-final-index-spec-p final-index-spec)
      (let* ((assertions (simple-term-assertion-list-filtered final-index-spec
                                                              type
                                                              truth
                                                              direction))
             (syntactic-iterator (new-list-iterator assertions)))
        ;; was called semantic-iterator
        (new-filter-iterator-without-values syntactic-iterator
                                            #'assertion-semantically-matches-simple-final-index-spec?
                                            (list final-index-spec)))
      ;; TODO - check symbol vs function validity
      (new-hl-store-iterator (list 'final-index-iterator-filtered
                                   (list 'quote final-index-spec)
                                   type
                                   truth
                                   direction)
                             1)))

(defun assertion-semantically-matches-simple-final-index-spec? (assertion simple-final-index-spec)
  "[Cyc] Assumes that ASSERTION syntactically matches SIMPLE-FINAL-INDEX-SPEC."
  (destructuring-bind (simple term type . rest) simple-final-index-spec
    (declare (ignore term))
    (must (eq :simple simple)
          "Unexpected non-simple index ~s" simple-final-index-spec)
    ;; This block returns T unless something else usurps it with a NIL
    ;; Technically this could be mashed into a big AND statement, but whatever.
    (block nil
      (cond
        ((eq :gaf type) (destructuring-bind (argnum-spec pred-spec mt-spec) rest
                          (declare (ignore argnum-spec))
                          (when (or (and (not mt-spec)
                                         (not (assertion-matches-mt? assertion)))
                                    (and (not pred-spec)
                                         (not (all-preds-are-relevant?))
                                         (not (relevant-pred? (gaf-predicate assertion)))))
                            (return nil))))
        ((eq :nart type) (return t))
        ((eq :rule type) (unless (assertion-matches-mt? assertion)
                           (return nil)))
        ((not type) (progn
                      (destructuring-bind (assertion-func) rest
                        (when (eq #'mt-index-assertion-match-p assertion-func)
                          (return t)))
                      (unless (assertion-matches-mt? assertion)
                        (return nil))))
        (t (error "Unexpected type ~s in simple final index spec ~s" type simple-final-index-spec)))
      t)))

(defun* destroy-final-index-iterator (final-index-iterator) (:inline t)
  (iteration-finalize final-index-iterator))

(defun final-index-iterator-filtered (final-index-spec type-spec truth-spec direction-spec)
  "[Cyc] Gets the index of TERM, then follows each key in KEYS in succession. It must end up at NIL or a final index or it will signal an error. Then it turns the final index into an iterator and filters it by TYPE-SPEC, TRUTH-SPEC and DIRECTION-SPEC."
  (destructuring-bind (term . keys) final-index-spec
    (when-let ((final-index (get-subindex term keys)))
      (check-type final-index #'final-index-p)
      (let* ((raw-iterator (new-set-iterator final-index))
             (filtered-iterator (new-filter-iterator-without-values
                                 raw-iterator
                                 #'assertion-matches-type-truth-and-direction
                                 (list type-spec truth-spec direction-spec))))
        filtered-iterator))))



;; Simple final index specs

(defun new-gaf-simple-final-index-spec (term argnum-spec predicate-spec mt-spec)
  "[Cyc] Returns a 'gaf simple final index spec' -- a constraint object used to filter gafs.
TERM: The simply indexed term from which to get the unfiltered list of gafs.
ARGNUM-SPEC: see GAF-MATCHES-SIMPLE-ARGNUM-SPEC?
PREDICATE-SPEC: NIL or predicate-p, the predicate of the gaf.
MT-SPEC: NIL or HLMT-P, the MT of the gaf."
  (list :simple term :gaf argnum-spec predicate-spec mt-spec))

(defun new-nart-simple-final-index-spec (term argnum-spec functor-spec)
  "[Cyc] Returns a 'nart simple final index spec' -- a constraint object used to filter narts.
TERM: The simply indexed term from which to get the unfiltered list of narts.
ARGNUM-SPEC: see TOU-SYNTACTICALLY-MATCHES-SIMPLE-NART-FINAL-INDEX-SPEC?.
FUNCTOR-SPEC: NIL or FUNCTOR-P, the functor of the nart."
  (list :simple term :nart argnum-spec functor-spec))

(defun new-rule-simple-final-index-spec (term sense-spec asent-func)
  "[Cyc] Returns a 'rule simple final index spec' -- a constraint object used to filter rules.
TERM: The simply indexed term from which to get the unfiltered list of rules.
SENSE-SPEC: NIL or SENSE-P, the sense of the literal we're looking for.
ASENT-FUNC: We will (funcall ASET-FUNC asent term) for each ASENT with sense SENSE-SPEC, and the rule is admitted iff there is such a literal."
  (list :simple term :rule sense-spec asent-func))

(defun new-assertion-simple-final-index-spec (term assertion-func)
  "[Cyc] Returns a 'simple final index spec' -- a constraint object used to filter assertions.
ASSERTION-FUNC: We will (funcall ASSERTION-FUNC assertion term), and the assertion is admitted iff it returns true."
  (list :simple term nil assertion-func))






(defun* simple-term-assertion-list-filtered-internal (simple-final-index-spec type truth direction) (:inline t)
  "[Cyc] Returns the list of all assertions referencing the TERM in FINAL-INDEX-SPEC which match TYPE, TRUTH, DIRECTION, and the syntactic constraints expressed in FINAL-INDEX-SPEC."
  (let ((result nil)
        (term (simple-final-index-spec-term simple-final-index-spec)))
    (dolist (assertion (simple-term-assertion-list term))
      (when (and (assertion-syntactically-matches-simple-final-index-spec? assertion simple-final-index-spec)
                 (assertion-matches-type-truth-and-direction? assertion type truth direction))
        (push assertion result)))
    ;; TODO - is it important that the ordering can be retained?  Should we use a tail-push keeping the last cons around for speed?
    (nreverse result)))

;; clear-simple-term-assertion-list-filtered is now generated by defun-cached

(defun-cached simple-term-assertion-list-filtered (simple-final-index-spec type truth direction)
    (:test equal :capacity 512 :clear-when :hl-store-modified)
  (simple-term-assertion-list-filtered-internal simple-final-index-spec type truth direction))


(defun assertion-syntactically-matches-simple-final-index-spec?
    (assertion simple-final-index-spec)
  "[Cyc] Assumes all simple final-index-specs are one of the three forms:
   (:simple term :gaf  argnum-spec predicate mt)
   (:simple term :nart argnum-spec functor)
   (:simple term :rule sense       asent-func)
   (:simple term nil   assertion-func)"
  (destructuring-bind (simple term type . rest) simple-final-index-spec
    (must (eq :simple simple)
          "Unexpected non-simple index ~s" simple-final-index-spec)
    (when (assertion-matches-syntactic-indexing-type? assertion type)
      (cond
        ((eq :gaf type) (gaf-syntactically-matches-simple-gaf-final-index-spec? assertion
                                                                                term
                                                                                rest))
        ((eq :nart type) (missing-larkc 30427))
        ((eq :rule type) (rule-syntactically-matches-simple-rule-final-index-spec? assertion
                                                                                   term
                                                                                   rest))
        ((not type) (assertion-syntactically-matches-simple-assertion-final-index-spec? assertion
                                                                                        term
                                                                                        rest))
        (t (error "Unexpected type ~s in simple final index spec ~s" type simple-final-index-spec))))))

(defun assertion-matches-syntactic-indexing-type? (assertion type)
  (if (eq :nart type)
      (term-of-unit-assertion-p assertion)
      (assertion-matches-type? assertion type)))

(defun gaf-syntactically-matches-simple-gaf-final-index-spec? (gaf term gaf-final-index-spec)
  (destructuring-bind (argnum-spec predicate-spec mt-spec) gaf-final-index-spec
    (and (or (not predicate-spec)
             (gaf-assertion-has-pred-p gaf predicate-spec))
         (gaf-matches-simple-argnum-spec? gaf term argnum-spec)
         (or (not mt-spec)
             (missing-larkc 31008)))))

(defun gaf-matches-simple-argnum-spec? (gaf term argnum-spec)
  "[Cyc] ARGNUM-SPEC is a specification for how TERM must appear in some argunment position of GAF.
   NIL          means that it doesn't matter.
   an integer N means that TERM must appear as the Nth argument in GAF.
   :any         means that TERM must appear as a top-level argument in GAF.
   (N M)        means that TERM must appear as the Mth argunment in the formula that is the Nth argunment of GAF.
   (N :any)     means that TERM must appear as a top-level argument in the formula that is the Nth argunment of GAF."
  (cond
    ((not argnum-spec) t)
    ((eq :any argnum-spec) (gaf-has-term-in-some-argnum? gaf term))
    ;; Since this is indexing an in-memory list, fixnum should be safe
    ;; TODO - search for all integerp, stringp, and other expensive tests and reevaluate
    ((fixnump argnum-spec) (gaf-has-term-in-argnum? gaf term argnum-spec))
    ((and (consp argnum-spec)
          (length= argnum-spec 2)
          (fixnump (first argnum-spec)))
     (let* ((n (first argnum-spec))
            (m (second argnum-spec))
            (subformula (gaf-arg gaf n)))
       (check-type subformula #'el-formula-p)
       (if (eq m :any)
           (term-is-one-of-args? term subformula)
           ;; TODO - doable missing-larkc
           (missing-larkc 30563))))))

(defun rule-syntactically-matches-simple-rule-final-index-spec? (rule term rule-final-index-spec)
  "[Cyc] Returns whether RULE has a SENSE-lit ASENT such that (funcall ASENT-FUNC asent TERM) holds.
RULE-FINAL-INDEX-SPEC: a (SENSE ASENT-FUNC) pair."
  (destructuring-bind (sense asent-func) rule-final-index-spec
    (rule-syntactically-matches-simple-rule-final-index-spec-int? rule sense term asent-func)))

;; TODO - why is this broken out?
(defun rule-syntactically-matches-simple-rule-final-index-spec-int? (rule sense term asent-func)
  (if (not sense)
      (or (rule-syntactically-matches-simple-rule-final-index-spec-int? rule :neg term asent-func)
          (rule-syntactically-matches-simple-rule-final-index-spec-int? rule :pos term asent-func))
      (when (valid-assertion-handle? rule)
        (let ((asents (clause-sense-lits (assertion-cnf rule) sense))
              (match nil))
          (csome (asent asents match)
            (setf match (asent-syntactically-matches-simple-rule-final-index-spec? asent
                                                                                   term
                                                                                   asent-func)))
          match))))

(defun asent-syntactically-matches-simple-rule-final-index-spec? (asent term asent-func)
  ;; This was another case form that called known function names
  ;; These were missing-larkc:
  ;;   isa-rule-index-asent-match-p
  ;;   genl-mt-rule-index-asent-match-p
  ;;   function-rule-index-asent-match-p
  ;;   exception-rule-index-asent-match-p
  (funcall asent-func asent term))

(defun assertion-syntactically-matches-simple-assertion-final-index-spec? (assertion term assertion-final-index-spec)
  (destructuring-bind (assertion-func) assertion-final-index-spec
    (funcall assertion-func assertion term)))

(defun predicate-rule-index-asent-match-p (asent predicate)
  (and (eq predicate (atomic-sentence-predicate asent))
       (predicate-rule-index-asent-p asent)))

(defun predicate-rule-index-asent-p (asent)
  (let ((pred (atomic-sentence-predicate asent)))
    (when (fort-p pred)
      (case pred
        (#$isa (not (isa-rule-index-asent-p asent)))
        (#$genls (not (genls-rule-index-asent-p asent)))
        (#$genlMt (not (genl-mt-rule-index-asent-p asent)))
        (#$termOfUnit (not (function-rule-index-asent-p asent)))
        (#$abnormal (not (exception-rule-index-asent-p asent)))
        (#$meetsPragmaticRequirement (not (pragma-rule-index-asent-p asent)))
        (otherwise t)))))

(defun decontextualized-ist-predicate-rule-index-asent-match-p (asent predicate)
  (and (eq #$ist (atomic-sentence-predicate asent))
       (eq predicate (literal-predicate (atomic-sentence-arg2 asent)))
       (missing-larkc 30350)))

(defun genls-rule-index-asent-match-p (asent collection)
  (and (genls-rule-index-asent-p asent)
       (eq collection (atomic-sentence-arg2 asent))))

(defun genls-rule-index-asent-p (asent)
  (and (eq #$genls (atomic-sentence-predicate asent))
       (formula-arity= asent 2)
       (fort-p (atomic-sentence-arg2 asent))))

(defun pragma-rule-index-asent-match-p (asent rule)
  (and (pragma-rule-index-asent-p asent)
       (eq rule (atomic-sentence-arg2 asent))))

(defun pragma-rule-index-asent-p (asent)
  (and (eq #$meetsPragmaticRequirement (atomic-sentence-predicate asent))
       (formula-arity= asent 2)
       (assertion-p (atomic-sentence-arg2 asent))))

(defun mt-index-assertion-match-p (assertion mt)
  (hlmt-equal? mt (assertion-mt assertion)))

;; Active declareFunction "DO-OTHER-INDEX-ASSERTION-MATCH-P" (1 0);
;; body not in decompiled Java source.
(defun do-other-index-assertion-match-p (final-index-spec)
  "[Cyc] Filter for the OTHER index post-hoc semantic check."
  (not (other-final-index-spec-p final-index-spec)))


;;; ============================================================
;;; Missing asent predicates — reconstructed from analogy
;;; ============================================================

;; Reconstructed from analogy with genls-rule-index-asent-p:
;; Pattern: (and (eq #$PRED pred) (formula-arity= asent 2) (fort-p (arg2 asent)))
;; Evidence: predicate-rule-index-asent-p dispatches #$isa → (missing-larkc 30406)
(defun isa-rule-index-asent-p (asent)
  "[Cyc] Return T iff ASENT is an isa-rule index asent."
  (and (eq #$isa (atomic-sentence-predicate asent))
       (formula-arity= asent 2)
       (fort-p (atomic-sentence-arg2 asent))))

;; Reconstructed from analogy with genls-rule-index-asent-match-p:
;; Pattern: (and (TYPE-rule-index-asent-p asent) (eq collection (arg2 asent)))
(defun isa-rule-index-asent-match-p (asent collection)
  "[Cyc] Return T iff ASENT is an isa-rule asent matching COLLECTION."
  (and (isa-rule-index-asent-p asent)
       (eq collection (atomic-sentence-arg2 asent))))

;; Reconstructed from analogy with isa-rule-index-asent-p, using #$quotedIsa
(defun quoted-isa-rule-index-asent-p (asent)
  "[Cyc] Return T iff ASENT is a quoted-isa-rule index asent."
  (and (eq #$quotedIsa (atomic-sentence-predicate asent))
       (formula-arity= asent 2)
       (fort-p (atomic-sentence-arg2 asent))))

;; Reconstructed from analogy with isa-rule-index-asent-match-p
(defun quoted-isa-rule-index-asent-match-p (asent collection)
  "[Cyc] Return T iff ASENT is a quoted-isa-rule asent matching COLLECTION."
  (and (quoted-isa-rule-index-asent-p asent)
       (eq collection (atomic-sentence-arg2 asent))))

;; Active declareFunction "DECONTEXTUALIZED-IST-PREDICATE-RULE-INDEX-ASENT-P" (1 0);
;; body not in decompiled Java source.
;; The -match-p version (which exists) calls missing-larkc 30350 where this would go.
(defun decontextualized-ist-predicate-rule-index-asent-p (asent)
  "[Cyc] Return T iff ASENT is a decontextualized-ist predicate rule index asent."
  (declare (ignore asent))
  (missing-larkc 30350))

;; Reconstructed from analogy with genls-rule-index-asent-p, using #$genlMt
(defun genl-mt-rule-index-asent-p (asent)
  "[Cyc] Return T iff ASENT is a genl-mt-rule index asent."
  (and (eq #$genlMt (atomic-sentence-predicate asent))
       (formula-arity= asent 2)
       (fort-p (atomic-sentence-arg2 asent))))

;; Reconstructed from analogy with genls-rule-index-asent-match-p
(defun genl-mt-rule-index-asent-match-p (asent genl-mt)
  "[Cyc] Return T iff ASENT is a genl-mt-rule asent matching GENL-MT."
  (and (genl-mt-rule-index-asent-p asent)
       (eq genl-mt (atomic-sentence-arg2 asent))))

;; Reconstructed: function-rule checks for #$termOfUnit.
;; Evidence: predicate-rule-index-asent-p dispatches #$termOfUnit → (missing-larkc 30399)
(defun function-rule-index-asent-p (asent)
  "[Cyc] Return T iff ASENT is a function-rule index asent."
  (and (eq #$termOfUnit (atomic-sentence-predicate asent))
       (formula-arity= asent 2)))

;; Reconstructed from analogy with other -match-p functions
(defun function-rule-index-asent-match-p (asent function)
  "[Cyc] Return T iff ASENT is a function-rule asent matching FUNCTION."
  (and (function-rule-index-asent-p asent)
       (eq function (atomic-sentence-arg2 asent))))

;; Reconstructed: exception-rule checks for #$abnormal.
;; Evidence: predicate-rule-index-asent-p dispatches #$abnormal → (missing-larkc 30396)
(defun exception-rule-index-asent-p (asent)
  "[Cyc] Return T iff ASENT is an exception-rule index asent."
  (and (eq #$abnormal (atomic-sentence-predicate asent))
       (formula-arity= asent 2)
       (assertion-p (atomic-sentence-arg2 asent))))

;; Reconstructed from analogy with pragma-rule-index-asent-match-p
(defun exception-rule-index-asent-match-p (asent rule)
  "[Cyc] Return T iff ASENT is an exception-rule asent matching RULE."
  (and (exception-rule-index-asent-p asent)
       (eq rule (atomic-sentence-arg2 asent))))

;; Active declareFunction "UNBOUND-PREDICATE-RULE-INDEX-ASENT-P" (1 0);
;; body not in decompiled Java source.
(defun unbound-predicate-rule-index-asent-p (asent)
  "[Cyc] Return T iff ASENT is an unbound-predicate-rule index asent."
  (declare (ignore asent))
  ;; Active declareFunction; body not recovered from LarKC Java
  t)

;; Active declareFunction "UNBOUND-PREDICATE-RULE-INDEX-ASENT-MATCH-P" (2 0);
;; body not in decompiled Java source.
(defun unbound-predicate-rule-index-asent-match-p (asent term)
  "[Cyc] Return T iff ASENT is an unbound-predicate-rule asent matching TERM."
  (declare (ignore asent term))
  ;; Active declareFunction; body not recovered from LarKC Java
  t)


;; Active declareFunction "TOU-SYNTACTICALLY-MATCHES-SIMPLE-NART-FINAL-INDEX-SPEC?" (3 0);
;; body not in decompiled Java source.
(defun tou-syntactically-matches-simple-nart-final-index-spec? (tou term nart-final-index-spec)
  "[Cyc] Return T iff TOU syntactically matches SIMPLE-NART-FINAL-INDEX-SPEC."
  (declare (ignore tou term nart-final-index-spec))
  (missing-larkc 30427))


;;; ============================================================
;;; Init / Setup
;;; ============================================================

;; Note: *simple-term-assertion-list-filtered-caching-state* is created by defun-cached above.

(defun setup-kb-mapping-macros-file ()
  ;; Macro helper registrations
  (register-macro-helper 'truth-relevant-p 'pwhen-truth-relevant)
  (register-macro-helper 'some-assertions-internal 'some-assertions)
  (register-macro-helper 'do-final-index-from-spec '(do-gaf-arg-index
                                                      do-predicate-extent-index
                                                      do-nart-arg-index
                                                      do-function-extent-index
                                                      do-predicate-rule-index
                                                      do-decontextualized-ist-predicate-rule-index
                                                      do-isa-rule-index
                                                      do-quoted-isa-rule-index
                                                      do-genls-rule-index
                                                      do-genl-mt-rule-index
                                                      do-function-rule-index
                                                      do-exception-rule-index
                                                      do-pragma-rule-index
                                                      do-unbound-predicate-rule-index
                                                      do-mt-index
                                                      do-other-index
                                                      do-term-index))
  (register-macro-helper 'do-gaf-arg-index-key-validator 'do-gaf-arg-index)
  (register-macro-helper 'new-gaf-arg-final-index-spec-iterator 'do-gaf-arg-index)
  (register-macro-helper 'do-predicate-extent-index-key-validator 'do-predicate-extent-index)
  (register-macro-helper 'new-predicate-extent-final-index-spec-iterator 'do-predicate-extent-index)
  (register-macro-helper 'do-nart-arg-index-key-validator 'do-nart-arg-index)
  (register-macro-helper 'new-nart-arg-final-index-spec-iterator 'do-nart-arg-index)
  (register-macro-helper 'do-function-extent-index-key-validator 'do-function-extent-index)
  (register-macro-helper 'function-extent-final-index-spec 'do-function-extent-index)
  (register-macro-helper 'do-predicate-rule-index-key-validator 'do-predicate-rule-index)
  (register-macro-helper 'new-predicate-rule-final-index-spec-iterator 'do-predicate-rule-index)
  (register-macro-helper 'do-decontextualized-ist-predicate-rule-index-key-validator 'do-decontextualized-ist-predicate-rule-index)
  (register-macro-helper 'new-decontextualized-ist-final-index-spec-iterator 'do-decontextualized-ist-predicate-rule-index)
  (register-macro-helper 'do-isa-rule-index-key-validator 'do-isa-rule-index)
  (register-macro-helper 'new-isa-rule-final-index-spec-iterator 'do-isa-rule-index)
  (register-macro-helper 'do-quoted-isa-rule-index-key-validator 'do-quoted-isa-rule-index)
  (register-macro-helper 'new-quoted-isa-rule-final-index-spec-iterator 'do-quoted-isa-rule-index)
  (register-macro-helper 'do-genls-rule-index-key-validator 'do-genls-rule-index)
  (register-macro-helper 'new-genls-rule-final-index-spec-iterator 'do-genls-rule-index)
  (register-macro-helper 'do-genl-mt-rule-index-key-validator 'do-genl-mt-rule-index)
  (register-macro-helper 'new-genl-mt-rule-final-index-spec-iterator 'do-genl-mt-rule-index)
  (register-macro-helper 'do-function-rule-index-key-validator 'do-function-rule-index)
  (register-macro-helper 'new-function-rule-final-index-spec-iterator 'do-function-rule-index)
  (register-macro-helper 'do-exception-rule-index-key-validator 'do-exception-rule-index)
  (register-macro-helper 'new-exception-rule-final-index-spec-iterator 'do-exception-rule-index)
  (register-macro-helper 'do-pragma-rule-index-key-validator 'do-pragma-rule-index)
  (register-macro-helper 'new-pragma-rule-final-index-spec-iterator 'do-pragma-rule-index)
  (register-macro-helper 'do-unbound-predicate-rule-index-key-validator 'do-unbound-predicate-rule-index)
  (register-macro-helper 'new-unbound-predicate-rule-final-index-spec-iterator 'do-unbound-predicate-rule-index)
  (register-macro-helper 'do-mt-index-key-validator 'do-mt-index)
  (register-macro-helper 'mt-final-index-spec 'do-mt-index)
  (register-macro-helper 'do-other-index-key-validator 'do-other-index)
  (register-macro-helper 'other-final-index-spec 'do-other-index)
  (register-macro-helper 'other-final-index-spec-p 'do-term-index)
  (register-macro-helper 'do-other-index-assertion-match-p 'do-other-index)
  (register-cyc-api-macro 'do-gaf-arg-index '((assertion-var term &key index predicate truth direction done) &body body)
    "Iterate over an index of gaf assertions executing BODY within the scope of VAR.
VAR is bound to each assertion in the iteration such that:
The assertion is in a relevant microtheory (relevance is established outside).
If INDEX is non-nil and positive, TERM is the INDEX argument of the assertion,
else TERM is some nonzero argument of the assertion.
If PREDICATE is non-nil, PREDICATE is the predicate of the assertion.
If TRUTH is non-nil, the assertion has TRUTH as its truth value.
If DIRECTION is non-nil, the assertion has DIRECTION as its direction.
Iteration is halted as soon as DONE becomes non-nil.
@note VAR may be bound to the same assertion twice, if it exists in multiple indexing leaf sets,
for example if TERM appears in more than one non-zero argnum of VAR.")
  

(register-cyc-api-macro 'do-term-index '((var term &key type truth direction done) &body body)
    "Iterate over all assertions indexed from TERM executing BODY within the scope of VAR.
VAR is bound to each assertion in the iteration such that:
The assertion is indexed from TERM.
The assertion is in a relevant microtheory (relevance is established outside).
If the assertion is a gaf, then its predicate is relevant (relevance is established outside).
If TYPE is non-nil, then assertion has TYPE as its type.
If TRUTH is non-nil, the assertion has TRUTH as its truth value.
If DIRECTION is non-nil, the assertion has DIRECTION as its direction.
Iteration is halted as soon as DONE becomes non-nil.
@note VAR may be bound to the same assertion twice, if it exists in multiple indexing leaf sets.
See other indexing macros for examples of how this could happen.")
  (note-globally-cached-function 'simple-term-assertion-list-filtered))

;;; Top-level API registrations (setup function above is never called)

(register-cyc-api-macro 'do-gaf-arg-index '((assertion-var term &key index predicate truth direction done) &body body)
    "Iterate over an index of gaf assertions executing BODY within the scope of VAR.")

(register-cyc-api-macro 'do-term-index '((var term &key type truth direction done) &body body)
    "Iterate over all assertions indexed from TERM executing BODY within the scope of VAR.")
