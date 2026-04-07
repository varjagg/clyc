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

;; Variables (init section)

(defparameter *canonicalize-clause-sentence-terms-sense-lambda* nil
  "[Cyc] lambda for canonicalize-clause-sentence-terms sense")

(defparameter *never-commutative-predicates*
  (list #$isa #$genls)
  "[Cyc] A list of predicates that are guaranteed to never be commutative.  Checked for speed before calling on SBHL.")

(defparameter *tou-skolem-blist* :uninitialized
  "[Cyc] A binding list to remember existential variables, to remember the original EL variable as it was asserted.")

(defparameter *var-is-scoped-in-formula-var* :uninitialized
  "[Cyc] lambda for var-is-scoped-in-formula?")

;; Setup section (register-cyc-api-function and note-memoized-function calls)

(toplevel
  (register-cyc-api-function 'el-to-hl
      '(formula &optional mt)
      "Translate el expression FORMULA into its equivalent canonical hl expressions"
      '((formula el-formula-p))
      nil)
  (register-cyc-api-function 'el-to-hl-query
      '(formula &optional mt)
      "Translate el query FORMULA into its equivalent hl expressions"
      '((formula el-formula-p))
      nil)
  (register-cyc-api-function 'canonicalize-term
      '(term &optional (mt *mt*))
      "Converts the EL term TERM to its canonical HL representation.\n   @return HL term"
      nil
      nil)
  (note-memoized-function 'canonicalize-term-memoized-int)
  (note-memoized-function 'canonicalize-wf-cycl-int-memoized)
  (note-memoized-function 'canonicalize-ask-int-memoized))

;; Function declarations follow declare_czer_main_file() ordering

;; (defun el-to-hl (formula &optional mt) ...) -- active declareFunction, no body
;; (defun el-to-hl-query (formula &optional mt) ...) -- active declareFunction, no body
;; (defun el-to-hl-fast (formula &optional mt) ...) -- active declareFunction, no body
;; (defun el-to-hl-really-fast (formula &optional mt) ...) -- active declareFunction, no body

(defun canonicalize-term (term &optional (mt *mt*))
  "[Cyc] Converts the EL term TERM to its canonical HL representation.
   @return HL term"
  (let ((*mt* mt))
    (when (el-formula-p term)
      (setf term (copy-formula term)))
    (let ((*el-symbol-suffix-table* (make-hash-table :test #'eql))
          (*standardize-variables-memory* nil))
      (setf term (simplify-sequence-variables-1 term))
      (when *canonicalize-all-sentence-args-p*
        ;; missing-larkc 31060: originally canonicalized all sentence args;
        ;; likely called canonicalize-clauses-sentence-terms or similar recursive
        ;; sentence-arg canonicalization routine
        (setf term (missing-larkc 31060)))
      (setf term (canonicalize-term-commutative-terms term))
      (setf term (reify-relation-functions term (not *recanonicalizing-candidate-nat-p*)))
      term)))

;; (defun canonicalize-term-memoized (term &optional (mt *mt*)) ...) -- active declareFunction, no body
;; (defun canonicalize-term-memoized-int-internal (term mt) ...) -- active declareFunction, no body

(defun-memoized canonicalize-term-memoized-int (term mt) (:test equal)
  "[Cyc] Memoized internal version of canonicalize-term."
  (canonicalize-term term mt))

;; (defun canonicalize-term-assert (term &optional mt) ...) -- active declareFunction, no body
;; (defun coerce-to-fort (term) ...) -- active declareFunction, no body

(defun canonicalize-gaf (gaf-asent mt)
  "[Cyc] Return GAF-ASENT in MT expressed as a list of CNF clauses, or a CycL truth value,
or NIL if it couldn't canonicalize."
  (canonicalize-assert-sentence gaf-asent mt))

;; (defun canonicalize-wf-gaf (gaf-asent mt) ...) -- active declareFunction, no body
;; (defun ncanonicalize-cycl (sentence &optional mt) ...) -- active declareFunction, no body
;; (defun canonicalize-cycl (sentence &optional mt) ...) -- active declareFunction, no body

(defun canonicalize-cycl-int (sentence &optional (mt *mt*)
                                        (testing-p nil)
                                        (destructive-p nil)
                                        (unwrap-ist-p nil)
                                        (check-wff-p t))
  "[Cyc] Internal CycL canonicalization entry point.
   @return 0 result; @return 1 subordinate-fi-ops-p; @return 2 variables-memory; @return 3 mt"
  (unless (or *within-wff-p* *within-canonicalizer-p*)
    (clear-canon-caches))
  (let ((result nil)
        (subordinate-fi-ops-p nil)
        (variables-memory nil)
        (wff-p (null check-wff-p))
        (copied-formula nil))
    (setf mt (canonicalize-hlmt mt))
    (when (and check-wff-p (null mt))
      (setf wff-p nil))
    (let ((*within-canonicalizer-p* t)
          (*czer-memoization-state* (new-memoization-state)))
      (let (($memoization-state$ *czer-memoization-state*))
        (let ((local-state *czer-memoization-state*))
          (let ((original-memoization-process nil))
            (when (and local-state
                       (null (memoization-state-lock local-state)))
              (setf original-memoization-process
                    (memoization-state-get-current-process-internal local-state))
              (let ((current-proc (current-process)))
                (if (null original-memoization-process)
                    (memoization-state-set-current-process-internal local-state current-proc)
                    (unless (eq original-memoization-process current-proc)
                      (error "Invalid attempt to reuse memoization state in multiple threads simultaneously.")))))
            (unwind-protect
                (let ((*relevant-mt-function* (possibly-in-mt-determine-function mt))
                      (*mt* (possibly-in-mt-determine-mt mt))
                      (*subordinate-fi-ops-p* nil))
                  (setf copied-formula
                        (if destructive-p sentence (copy-formula sentence)))
                  (let ((*el-symbol-suffix-table* (make-hash-table :test #'eql))
                        (*standardize-variables-memory* nil))
                    (when check-wff-p
                      (let ((*check-arity-p* (check-wff-arity-p))
                            (*check-wff-semantics-p* (check-wff-semantics-p)))
                        (setf wff-p (canon-wff-p sentence *mt*))
                        (when (null wff-p)
                          (multiple-value-bind (simpler-formula is-it-wff-now-p)
                              (try-to-simplify-non-wff-into-wff copied-formula
                                                                #'canon-wff-p
                                                                *mt*)
                            (when is-it-wff-now-p
                              (setf wff-p t)
                              (setf copied-formula simpler-formula))))))
                    (when wff-p
                      (setf result copied-formula)
                      (let ((quiesced-p nil)
                            (count 0))
                        (loop until quiesced-p do
                          (multiple-value-setq (result mt)
                            (clausify-eliminating-ists result mt :cnf unwrap-ist-p))
                          (setf result (cnf-operators-out result))
                          (multiple-value-setq (result mt)
                            (canonicalize-clauses result mt))
                          (if (>= count *czer-quiescence-iteration-limit*)
                              (setf quiesced-p t)
                              (setf quiesced-p (czer-result-quiesced-p result unwrap-ist-p)))
                          (when (null quiesced-p)
                            ;; missing-larkc 4190: likely recanonicalization step,
                            ;; unwrapping IST or transforming after failed quiescence check
                            (setf result (missing-larkc 4190)))
                          (incf count)))
                      (setf subordinate-fi-ops-p *subordinate-fi-ops-p*)
                      (when testing-p
                        (setf variables-memory *standardize-variables-memory*)))))
              (when (and local-state (null original-memoization-process))
                (memoization-state-set-current-process-internal local-state nil)))))))
    (when (null unwrap-ist-p)
      (setf mt nil))
    (when *clothe-naked-skolems-p*
      ;; missing-larkc 31070: clothe-naked-skolems call; adds skolem assertions
      ;; to any naked skolem function terms created during canonicalization
      (missing-larkc 31070))
    (values result subordinate-fi-ops-p variables-memory mt)))

;; (defun clothe-naked-skolems (clauses) ...) -- active declareFunction, no body

(defun czer-result-quiesced-p (czer-result caller-was-supposed-to-unwrap-ist-p)
  "[Cyc] Currently the only case this handles is when the caller was supposed to unwrap #$ist but there's
   still at least one #$ist literal in the czer result and no other literals."
  (when (null caller-was-supposed-to-unwrap-ist-p)
    (return-from czer-result-quiesced-p t))
  (when (cycl-truth-value-p czer-result)
    (return-from czer-result-quiesced-p t))
  (when (expression-find-if #'cycl-generalized-tensed-literal-p czer-result)
    (return-from czer-result-quiesced-p nil))
  (let ((ist-count 0)
        (non-ist-count 0))
    (dolist (clause (extract-hl-clauses czer-result))
      (dolist (asent (neg-lits clause))
        (let ((unwrapped-asent (unwrap-if-ist-permissive asent)))
          (when (or (el-conjunction-p unwrapped-asent)
                    (el-existential-p unwrapped-asent))
            (return-from czer-result-quiesced-p nil)))
        (if (and (ist-sentence-p asent)
                 ;; missing-larkc 30478: likely (chlmt-p (ist-sentence-mt asent)) or similar
                 ;; extracts the MT from the IST sentence and checks if it's a closed HLMT
                 (chlmt-p (missing-larkc 30478)))
            (incf ist-count)
            (incf non-ist-count)))
      (dolist (asent (pos-lits clause))
        (let ((unwrapped-asent (unwrap-if-ist-permissive asent)))
          (when (or (el-conjunction-p unwrapped-asent)
                    (el-existential-p unwrapped-asent))
            (return-from czer-result-quiesced-p nil)))
        (if (and (ist-sentence-p asent)
                 ;; missing-larkc 30479: same pattern as 30478 above — extract MT from IST
                 ;; and check if it is a closed HLMT
                 (chlmt-p (missing-larkc 30479)))
            (incf ist-count)
            (incf non-ist-count))))
    (when (and (>= ist-count 1) (= non-ist-count 0))
      (return-from czer-result-quiesced-p nil)))
  t)

(defun canonicalize-cycl-sentence (sentence &optional (mt *mt*))
  "[Cyc] Converts the EL sentence SENTENCE to its canonical HL representation.
   @return 0 nil or cycl-truth-value-p or list-of-clause-binding-list-pairs-p;
     an unordered list of clause/binding-list pairs, e.g. ((<clause1> <blist1>) (<clause2> <blist2>)),
     or #$True or #$False, or NIL if FORMULA was ill-formed.
   @return 1 nil or hlmt-p;
   the microtheory in which to interpret the returned sentence.
   Note that this may differ from MT, for example when SENTENCE is an #$ist sentence."
  (multiple-value-bind (result dummy1 dummy2 result-mt)
      (canonicalize-cycl-int sentence mt nil nil t)
    (declare (ignore dummy1 dummy2))
    (values result result-mt)))

;; (defun canonicalize-cycl-test (sentence &optional mt) ...) -- active declareFunction, no body
;; (defun canonicalize-wf-cycl (sentence &optional mt) ...) -- active declareFunction, no body
;; (defun canonicalize-wf-cycl-memoized (sentence &optional mt) ...) -- active declareFunction, no body
;; (defun canonicalize-wf-cycl-int-memoized-internal (sentence mt) ...) -- active declareFunction, no body

(defun-memoized canonicalize-wf-cycl-int-memoized (sentence mt) (:test equal)
  "[Cyc] Memoized internal version of canonicalize-wf-cycl."
  (canonicalize-wf-cycl-sentence sentence mt))

(defun canonicalize-wf-cycl-sentence (sentence &optional (mt *mt*))
  "[Cyc] Canonicalize sentence, skipping wff check (assumes well-formed)."
  (multiple-value-bind (result dummy1 dummy2 result-mt)
      (canonicalize-cycl-int sentence mt nil nil t nil)
    (declare (ignore dummy1 dummy2))
    (values result result-mt)))

;; (defun canonicalize-ask-memoized (sentence &optional mt) ...) -- active declareFunction, no body
;; (defun canonicalize-ask-int-memoized-internal (sentence mt) ...) -- active declareFunction, no body

(defun-memoized canonicalize-ask-int-memoized (sentence mt) (:test equal)
  "[Cyc] Memoized internal version of canonicalize-ask."
  (canonicalize-query-sentence sentence mt))

;; (defun canonicalize-ask (sentence &optional mt) ...) -- active declareFunction, no body

(defun canonicalize-ask-mt (mt)
  "[Cyc] Canonicalize MT for an ask (query) context."
  (let ((result nil))
    (let ((*within-ask* t))
      (setf result (canonicalize-term mt *mt-mt*))
      (when result
        (setf result (canonicalize-hlmt result))))
    result))

(defun canonicalize-ask-sentence (sentence &optional (mt *mt*))
  "[Cyc] @return 0 nil or cycl-truth-value-p or list-of-clause-binding-list-pairs-p; actually a list of triples
   @return 1 nil or hlmt-p"
  (let ((result nil))
    (let ((*within-ask* t))
      (multiple-value-setq (result mt)
        (canonicalize-query-sentence sentence mt))
      (setf result (remove-newly-introduced-variables-from-bindings result sentence)))
    (values result mt)))

;; (defun canonicalize-assert (sentence &optional mt) ...) -- active declareFunction, no body
;; (defun test-canonicalize-assert (sentence &optional mt) ...) -- active declareFunction, no body

(defun canonicalize-assert-mt (mt)
  "[Cyc] Canonicalize MT for an assert context."
  (let ((result nil))
    (let ((*within-assert* t)
          (*within-ask* nil))
      (setf result (canonicalize-mt mt)))
    result))

(defun canonicalize-mt (mt)
  "[Cyc] Like @xref canonicalize-hlmt except does more canonicalization,
   possibly including reifying new narts if *within-assert*.
   Returns NIL if MT is ill-formed."
  (setf mt (canonicalize-term mt *mt-mt*))
  (when mt
    (setf mt (canonicalize-hlmt mt)))
  mt)

(defun canonicalize-assert-sentence (sentence &optional (mt *mt*))
  "[Cyc] @note this may create 'naked' skolem functions without #$skolem assertions."
  (let ((result nil))
    (let ((*within-assert* t)
          (*within-ask* nil))
      (multiple-value-setq (result mt)
        (canonicalize-cycl-sentence sentence mt)))
    (values result mt)))

;; (defun test-canonicalize-assert-sentence (sentence &optional mt) ...) -- active declareFunction, no body

(defun canonicalize-wf-assert-sentence (sentence &optional (mt *mt*))
  "[Cyc] @note this may create 'naked' skolem functions without #$skolem assertions."
  (let ((result nil))
    (let ((*within-assert* t)
          (*within-ask* nil))
      (multiple-value-setq (result mt)
        (canonicalize-wf-cycl-sentence sentence mt)))
    (values result mt)))

;; (defun canonicalize-unassert (sentence &optional mt) ...) -- active declareFunction, no body
;; (defun canonicalize-unassert-sentence (sentence &optional mt) ...) -- active declareFunction, no body
;; (defun ncanonicalize-query (sentence &optional mt) ...) -- active declareFunction, no body

(defun canonicalize-query (formula &optional (mt *mt*)
                                   (destructive-p nil)
                                   (unwrap-ist-p nil))
  "[Cyc] Converts the EL query FORMULA to its canonical HL representation.
   @return 0 nil or cycl-truth-value-p or list-of-clause-binding-list-pairs-p;
     an unordered list of clause/binding-list pairs, e.g. ((<clause1> <blist1>) (<clause2> <blist2>)),
     or #$True or #$False, or NIL if FORMULA was ill-formed.
   @return 1 boolean; whether extra FI operations were created as a result of canonicalization.
   @return 2 nil or hlmt-p; if UNWRAP-IST?, the microtheory in which to interpret FORMULA."
  (unless (or *within-wff-p* *within-canonicalizer-p*)
    (clear-canon-caches))
  (let ((result nil)
        (subordinate-fi-ops-p nil)
        (copied-formula nil))
    (setf mt (canonicalize-ask-mt mt))
    (let ((*within-canonicalizer-p* t)
          (*czer-memoization-state* (new-memoization-state)))
      (let (($memoization-state$ *czer-memoization-state*))
        (let ((local-state *czer-memoization-state*))
          (let ((original-memoization-process nil))
            (when (and local-state
                       (null (memoization-state-lock local-state)))
              (setf original-memoization-process
                    (memoization-state-get-current-process-internal local-state))
              (let ((current-proc (current-process)))
                (if (null original-memoization-process)
                    (memoization-state-set-current-process-internal local-state current-proc)
                    (unless (eq original-memoization-process current-proc)
                      (error "Invalid attempt to reuse memoization state in multiple threads simultaneously.")))))
            (unwind-protect
                (let ((*within-query* t))
                  (let ((*mt* (update-inference-mt-relevance-mt mt))
                        (*relevant-mt-function* (update-inference-mt-relevance-function mt))
                        (*relevant-mts* (update-inference-mt-relevance-mt-list mt))
                        (*within-assert* nil)
                        (*check-arg-types-p* nil)
                        (*at-check-arg-types-p* nil)
                        (*check-wff-semantics-p* nil)
                        (*check-wff-coherence-p* nil)
                        (*check-var-types-p* nil)
                        (*simplify-literal-p* nil)
                        (*at-check-relator-constraints-p* nil)
                        (*at-check-arg-format-p* nil)
                        (*validate-constants-p* nil)
                        (*suspend-sbhl-type-checking-p* t)
                        (*subordinate-fi-ops-p* nil)
                        (*el-symbol-suffix-table* (make-hash-table :test #'eql))
                        (*standardize-variables-memory* nil))
                    (let ((wff-p (el-wff-syntax-p formula)))
                      (setf copied-formula
                            (if destructive-p formula (copy-formula formula)))
                      (when (null wff-p)
                        (multiple-value-bind (simpler-formula is-it-wff-now-p)
                            ;; missing-larkc 10699: try-to-simplify-non-wff-into-wff for query context
                            ;; likely calls (try-to-simplify-non-wff-into-wff copied-formula #'el-wff-syntax-p mt)
                            (missing-larkc 10699)
                          (when is-it-wff-now-p
                            (setf wff-p t)
                            (setf copied-formula simpler-formula))))
                      (when wff-p
                        (setf result copied-formula)
                        (let ((quiesced-p nil)
                              (count 0))
                          (loop until quiesced-p do
                            (multiple-value-setq (result mt)
                              (clausify-eliminating-ists result mt :dnf unwrap-ist-p))
                            (setf result (dnf-operators-out result))
                            (multiple-value-setq (result mt)
                              (canonicalize-query-clauses result mt))
                            (if (>= count *czer-quiescence-iteration-limit*)
                                (setf quiesced-p t)
                                (setf quiesced-p (czer-result-quiesced-p result unwrap-ist-p)))
                            (when (null quiesced-p)
                              ;; missing-larkc 4194: recanonicalization step for query;
                              ;; analogous to 4190 in canonicalize-cycl-int but for DNF/query
                              (setf result (missing-larkc 4194)))
                            (incf count)))
                        (setf subordinate-fi-ops-p *subordinate-fi-ops-p*)))))
              (when (and local-state (null original-memoization-process))
                (memoization-state-set-current-process-internal local-state nil)))))))
    (when (null unwrap-ist-p)
      (setf mt nil))
    (values result subordinate-fi-ops-p mt)))

(defun canonicalize-query-sentence (sentence &optional (mt *mt*))
  "[Cyc] Converts the EL query SENTENCE to its canonical HL representation.
   @return 0 nil or cycl-truth-value-p or list-of-clause-binding-list-pairs-p;
     an unordered list of clause/binding-list pairs, e.g. ((<clause1> <blist1>) (<clause2> <blist2>)),
     or #$True or #$False, or NIL if FORMULA was ill-formed.
   @return 1 nil or hlmt-p;
   the microtheory in which to interpret the returned sentence.
   Note that this may differ from MT, for example when SENTENCE is an #$ist sentence."
  (multiple-value-bind (result dummy1 result-mt)
      (canonicalize-query sentence mt nil t)
    (declare (ignore dummy1))
    (values result result-mt)))

;; (defun canonicalize-expression (expression &optional mt destructive-p) ...) -- active declareFunction, no body

(defun clausify-eliminating-ists (sentence mt clausal-form unwrap-ist-p)
  "[Cyc] Canonicalizes sentence into an EL clausal form of CLAUSAL-FORM.
If UNWRAP-IST?, this will recursively canonicalize SENTENCE until there are no more #$ists.
Also finds the nart version of a non-atomic mt before returning it, if one exists."
  (when unwrap-ist-p
    (multiple-value-setq (sentence mt)
      (unwrap-if-ist-permissive-canonical sentence mt)))
  (let ((ist-quiescence-p nil))
    (loop until ist-quiescence-p do
      (setf sentence (simplify-sequence-variables-1 sentence))
      (ecase clausal-form
        (:cnf
         (multiple-value-setq (sentence mt)
           (el-cnf-destructive sentence mt)))
        (:dnf
         (multiple-value-setq (sentence mt)
           (el-dnf-destructive sentence mt))))
      (if (null unwrap-ist-p)
          (setf ist-quiescence-p t)
          (multiple-value-bind (sub-sentence sub-mt)
              (unwrap-if-ist-permissive-canonical sentence mt)
            (if (and (eq sentence sub-sentence) (eq mt sub-mt))
                (setf ist-quiescence-p t)
                (progn
                  (setf sentence sub-sentence)
                  (setf mt (canonicalize-hlmt sub-mt))))))))
  (setf mt (canonicalize-hlmt mt))
  (values sentence mt))

(defun remove-newly-introduced-variables-from-bindings (clauses-and-more original-formula)
  "[Cyc] Remove newly introduced variables from bindings list."
  (when (and (consp clauses-and-more)
             (el-formula-p original-formula))
    (dolist (clause-and-more clauses-and-more)
      (let* ((canon-free-vars (third clause-and-more))
             (original-vars (referenced-variables original-formula))
             (spurious-free-vars (fast-set-difference canon-free-vars original-vars)))
        (when spurious-free-vars
          (let ((corrected-free-vars (fast-set-difference canon-free-vars spurious-free-vars)))
            (nreplace-nth 2 corrected-free-vars clause-and-more))))))
  clauses-and-more)

(defun clear-canon-caches ()
  "[Cyc] Clear all canonicalization caches."
  (clear-cached-cnf-clausal-form)
  (clear-cached-find-assertions-cycl)
  nil)

(defun canon-wff-p (formula &optional (mt *mt*))
  "[Cyc] Test whether FORMULA is well-formed for canonicalization."
  (let ((wff-p nil))
    (let ((*provide-wff-suggestions-p* nil))
      (if *recanonicalizingp*
          (setf wff-p (el-wff-syntax-p formula))
          (setf wff-p (el-wff-p formula mt))))
    wff-p))

(defun check-wff-arity-p ()
  "[Cyc] Return current value of *check-arity-p*."
  *check-arity-p*)

(defun check-wff-semantics-p (&optional (mt nil))
  "[Cyc] Return whether wff semantics should be checked."
  (if (psc-query-p mt)
      nil
      (and (or *must-enforce-semantics-p*
               (and *check-wff-semantics-p*
                    *within-assert*)))))

(defun canonicalize-clauses-terms (clauses)
  "[Cyc] Canonicalize all terms in CLAUSES."
  (when *canonicalize-terms-p*
    (setf clauses (canonicalize-clauses-quoted-terms clauses))
    (setf clauses (canonicalize-clauses-sentence-terms clauses))
    (setf clauses (canonicalize-clauses-commutative-terms-destructive clauses))
    (setf clauses (canonicalize-functions clauses))
    (setf clauses (canonicalize-clauses-tou-terms clauses))
    (setf clauses (canonicalize-clauses-commutative-terms-destructive clauses)))
  clauses)

(defun canonicalize-clauses-quoted-terms (clauses)
  "[Cyc] Canonicalize quoted terms in all clauses."
  (nmapcar #'canonicalize-clause-quoted-terms clauses))

(defun canonicalize-clause-quoted-terms (clause)
  "[Cyc] Canonicalize quoted terms in CLAUSE."
  (make-cnf (canonicalize-literals-quoted-terms (neg-lits clause))
            (canonicalize-literals-quoted-terms (pos-lits clause))))

(defun canonicalize-literals-quoted-terms (literals)
  "[Cyc] Canonicalize quoted terms in all LITERALS."
  (let ((result nil))
    (dolist (literal (reverse literals))
      (push (canonicalize-literal-quoted-terms-recursive literal) result))
    result))

(defun canonicalize-literal-quoted-terms-recursive (literal)
  "[Cyc] Replaces all the escape quoted terms (non variables) with just the term, since
  (#$EscapeQuote <term>) = <term>.  Also converts quasi quoted terms to (#$Quote  Assumes that the literal is well-formed -
  #$EscapeQuote should be nested within #$Quote"
  (let ((result literal))
    (let ((escapequote (tree-find-if #'escape-quote-syntax-p result)))
      (let ((escaped-form nil))
        (when (and escapequote
                   (null (tree-find-if #'cyc-var-p escapequote)))
          (setf escaped-form (formula-arg1 escapequote))
          (setf result (canonicalize-literal-quoted-terms-recursive
                        (subst escaped-form escapequote result))))))
    (let ((quasiquote (tree-find-if #'quasi-quote-syntax-p result)))
      (let ((quote-form nil))
        (when quasiquote
          (setf quote-form (list #$Quote (list #$EscapeQuote (formula-arg1 quasiquote))))
          (setf result (canonicalize-literal-quoted-terms-recursive
                        (subst quote-form quasiquote result))))))
    result))

;; (defun canonicalize-quoted-term (term &optional mt) ...) -- active declareFunction, no body
;; (defun unquote-quoted-term (term &optional mt) ...) -- active declareFunction, no body

(defun canonicalize-clauses-sentence-terms (clauses)
  "[Cyc] Destructively canonicalizes formula args (of any literals or denotational functions in CLAUSES) into their EL formulas.
   A 'formula arg' is, roughly, an argument that is constrained to be a Cyc formula.
   Replaces literals with NIL if they are not a @xref relation-expression?
   @see sentence-arg?"
  (if (canonicalize-no-sentence-args-p)
      clauses
      (nmapcar #'canonicalize-clause-sentence-terms clauses)))

(defun canonicalize-no-sentence-args-p ()
  "[Cyc] fast-fail"
  (not (or *canonicalize-tensed-literals-p*
           *canonicalize-all-sentence-args-p*)))

(defun canonicalize-clause-sentence-terms (clause)
  "[Cyc] Destructively canonicalizes formula args (of any literals or denotational functions in CLAUSE) into their EL formulas.
   A 'formula arg' is an argument that is constrained to be a collection whose instances are Cyc formulas.
   Replaces literals with NIL if they are not a @xref relation-expression?
   @see sentence-arg?"
  (let ((neg-lits nil)
        (pos-lits nil))
    (let ((*canonicalize-clause-sentence-terms-sense-lambda* :neg))
      (setf neg-lits (nmapcar #'canonicalize-literal-sentence-terms (neg-lits clause))))
    (let ((*canonicalize-clause-sentence-terms-sense-lambda* :pos))
      (setf pos-lits (nmapcar #'canonicalize-literal-sentence-terms (pos-lits clause))))
    (multiple-value-setq (neg-lits pos-lits)
      (unnegate-and-flip-negated-lits neg-lits pos-lits))
    (make-clause neg-lits pos-lits)))

(defun unnegate-and-flip-negated-lits (neg-lits pos-lits)
  "[Cyc] Turn pos-lits to neg-lits or vice versa if lit is an el-negation-p"
  (if (or (any-in-list #'el-negation-p neg-lits)
          (any-in-list #'el-negation-p pos-lits))
      (let ((new-neg-lits nil)
            (new-pos-lits nil))
        (dolist (pos-lit pos-lits)
          (if (el-negation-p pos-lit)
              (push (negate pos-lit) new-neg-lits)
              (push pos-lit new-pos-lits)))
        (dolist (neg-lit neg-lits)
          (if (el-negation-p neg-lit)
              (push (negate neg-lit) new-pos-lits)
              (push neg-lit new-neg-lits)))
        (values (nreverse new-neg-lits) (nreverse new-pos-lits)))
      (values neg-lits pos-lits)))

(defun canonicalize-literal-sentence-terms (literal &optional (mt *mt*))
  "[Cyc] Canonicalizes formula args of LITERAL into their EL formulas.
   A 'formula arg' is an argument that is constrained to be a collection whose instances are Cyc formulas.
   Returns NIL if LITERAL is not a @xref relation-expression?
   @see sentence-arg?"
  (if *canonicalize-all-sentence-args-p*
      ;; missing-larkc 31061: canonicalize-all-sentence-args-p path;
      ;; likely calls some function that fully canonicalizes all sentence-type arguments
      ;; in LITERAL, including tensed literals
      (missing-larkc 31061)
      literal))

;; (defun canonicalize-function-sentence-terms (function &optional mt) ...) -- active declareFunction, no body
;; (defun canonicalize-relation-sentence-terms (relation &optional mt) ...) -- active declareFunction, no body

(defun canonicalize-clauses-commutative-terms-destructive (clauses)
  "[Cyc] For each literal in CLAUSES, recursively sorts the arguments of all relations with commutative predicates
   and the arguments of all nats with commutative functors.
   Assumes that every clause in CLAUSES is an EL formula."
  (nmapcar #'canonicalize-clause-commutative-terms-destructive clauses))

;; (defun canonicalize-clause-commutative-terms (clause) ...) -- active declareFunction, no body

(defun canonicalize-clause-commutative-terms-destructive (clause)
  "[Cyc] A destructive version of @xref canonicalize-clause-commutative-terms."
  (if (or (and (null *canonicalize-gaf-commutative-terms-p*)
               ;; missing-larkc 30254: likely some fast-path check on whether clause
               ;; needs commutative canonicalization at all (e.g. gaf-clause-commutative-p)
               (missing-larkc 30254))
          (never-commutative-gaf-clause-p clause))
      clause
      (make-cnf (canonicalize-literals-commutative-terms (neg-lits clause))
                (canonicalize-literals-commutative-terms (pos-lits clause)))))

(defun never-commutative-gaf-clause-p (clause)
  "[Cyc] Return T if CLAUSE is guaranteed to never need commutative term canonicalization."
  (and (pos-atomic-cnf-p clause)
       (member (formula-operator (gaf-cnf-literal clause)) *never-commutative-predicates*)
       (null (contains-subformula-p (gaf-cnf-literal clause)))))

(defun canonicalize-literals-commutative-terms (literals)
  "[Cyc] For each literal in LITERALS, recursively sorts the arguments of all relations with commutative predicates
   and the arguments of all nats with commutative functors."
  (nmapcar #'canonicalize-literal-commutative-terms-destructive literals))

(defun canonicalize-literal-commutative-terms (literal)
  "[Cyc] Recursively sorts the arguments of all relations with commutative predicates
   and the arguments of all nats with commutative functors."
  (canonicalize-literal-commutative-terms-destructive (copy-formula literal)))

(defun canonicalize-literal-commutative-terms-destructive (literal)
  "[Cyc] A destructive version of @xref canonicalize-literal-commutative-terms."
  (let* ((seqvar (sequence-var literal))
         (tempformula literal)
         (literal2 (if seqvar
                       ;; missing-larkc 30659: expand sequence var in literal before sorting;
                       ;; likely (el-strip-sequence-var literal) or similar
                       (missing-larkc 30659)
                       tempformula))
         (result nil)
         (pred (literal-predicate literal2))
         (dont-reorder-argnums (dont-reorder-commutative-terms-for-args pred))
         (args (canonicalize-terms-commutative-terms-without-reordering
                (literal-args literal2)
                dont-reorder-argnums)))
    (cond
      ((commutative-relation-p pred)
       (setf result (make-el-literal pred (order-commutative-terms args))))
      ((partially-commutative-relation-p pred)
       (setf result (make-el-literal pred
                                     ;; missing-larkc 31101: sort partially commutative args;
                                     ;; likely sort-partially-commutative-terms or similar
                                     (missing-larkc 31101))))
      (t
       (setf result (make-el-literal pred args))))
    (if seqvar
        ;; missing-larkc 30608: re-attach sequence var after commutative sorting;
        ;; inverse of 30659 above
        (missing-larkc 30608)
        result)))

(defun canonicalize-literal-commutative-args (lit)
  "[Cyc]  "
  (let ((literal (copy-formula lit)))
    (let* ((seqvar (sequence-var literal))
           (tempformula literal)
           (literal2 (if seqvar
                         ;; missing-larkc 30660: expand sequence var (parallel to 30659)
                         (missing-larkc 30660)
                         tempformula))
           (result nil)
           (pred (literal-predicate literal2))
           (args (literal-args literal2)))
      (cond
        ((commutative-relation-p pred)
         (setf result (make-el-literal pred (order-commutative-terms args))))
        ((partially-commutative-relation-p pred)
         (setf result (make-el-literal pred
                                       ;; missing-larkc 31102: sort partially commutative args (same
                                       ;; as 31101 above, here operating on copy not destructively)
                                       (missing-larkc 31102))))
        (t
         (setf result (make-el-literal pred args))))
      (if seqvar
          ;; missing-larkc 30609: re-attach sequence var (inverse of 30660)
          (missing-larkc 30609)
          result))))

(defun order-commutative-terms (terms)
  "[Cyc] Sort TERMS into canonical commutative order."
  (sort terms #'commutative-terms-in-order-p))

(defun canonicalize-terms-commutative-terms-without-reordering (terms dont-reorder-argnums)
  "[Cyc] Puts each term in the list TERMS in canonical form wrt commutativity except the ones at argnum
   in dont-reorder-argnums, but does not change the order of the list TERMS."
  (let ((canonicalized-terms nil)
        (argnum 0))
    (dolist (term terms)
      (if (member (1+ argnum) dont-reorder-argnums)
          (push term canonicalized-terms)
          (push (canonicalize-term-commutative-terms term) canonicalized-terms))
      (incf argnum))
    (nreverse canonicalized-terms)))

(defun canonicalize-term-commutative-terms (term)
  "[Cyc] Basically just calls @xref canonicalize-relation-commutative-terms,
   if TERM is either a nat or an EL formula with a predicate, variable, or logical operator as its arg0."
  (cond
    ((subl-escape-p term) term)
    ((naut-p term)
     ;; missing-larkc 31057: canonicalize-nat-commutative-terms;
     ;; sorts commutative arguments within a non-atomic term (NAT)
     (missing-larkc 31057))
    ((el-relation-expression-p term)
     ;; missing-larkc 31059: canonicalize-relation-commutative-terms;
     ;; sorts commutative arguments within a relation expression
     (missing-larkc 31059))
    (t term)))

;; (defun unary-function-commutes-with-its-argument-p (function) ...) -- active declareFunction, no body
;; (defun canonicalize-commuting-function (nat) ...) -- active declareFunction, no body
;; (defun canonicalize-nat-commutative-terms (nat) ...) -- active declareFunction, no body
;; (defun canonicalize-relation-commutative-terms (relation) ...) -- active declareFunction, no body
;; (defun canonicalize-relation-commutative-terms-destructive (relation) ...) -- active declareFunction, no body
;; (defun sort-relation-commutative-terms (relation) ...) -- active declareFunction, no body
;; (defun sort-partially-commutative-terms (relation argnums mt) ...) -- active declareFunction, no body

(defun commutative-argnums (relation-expression)
  "[Cyc] Returns the argument positions in RELATION which commute with each other."
  (let ((relation (formula-operator relation-expression))
        (args (formula-args relation-expression :ignore)))
    (cond
      ((commutative-relation-p relation)
       (list (numlist (length args) 1)))
      ((partially-commutative-relation-p relation)
       ;; missing-larkc 31090: partially-commutative-argnums or similar;
       ;; returns grouped argnums that commute within partial commutativity constraints
       (missing-larkc 31090))))
  nil)

;; (defun ok-wrt-partial-commutativity-p (relation argnums mt) ...) -- active declareFunction, no body
;; (defun partially-commutative-argnums (relation mt) ...) -- active declareFunction, no body
;; (defun partially-commutative-argnums-int (relation mt &optional cia-formula) ...) -- active declareFunction, no body
;; (defun cia-formulas (relation &optional mt) ...) -- active declareFunction, no body

(defun commutative-terms-in-order-p (term1 term2)
  "[Cyc] Return T if TERM1 should come before TERM2 in commutative canonical order."
  (if *new-canonicalizer-p*
      (cond
        ((hl-term-with-el-counterpart-p term1)
         (commutative-terms-in-order-p
          ;; missing-larkc 29776: get EL counterpart of HL term1;
          ;; likely (hl-term-to-el-term term1) or (nart-to-el-term term1)
          (missing-larkc 29776)
          term2))
        ((hl-term-with-el-counterpart-p term2)
         (commutative-terms-in-order-p
          term1
          ;; missing-larkc 29777: get EL counterpart of HL term2 (symmetric with 29776)
          (missing-larkc 29777)))
        (t
         (if (atom term1)
             (if (atom term2)
                 ;; missing-larkc 31071: compare two atoms in new canonicalizer order;
                 ;; likely (new-commutative-atoms-in-order-p term1 term2)
                 (missing-larkc 31071)
                 t)
             (if (atom term2)
                 nil
                 ;; missing-larkc 31072: compare two cons cells in new canonicalizer order;
                 ;; likely (new-commutative-conses-in-order-p term1 term2)
                 (missing-larkc 31072)))))
      (old-commutative-terms-in-order-p term1 term2)))

;; (defun commutative-formulas-in-order-p (formula1 formula2) ...) -- active declareFunction, no body

(defun canonicalizer-constant-< (constant1 constant2)
  "[Cyc] Compare two constants by their external IDs for canonicalization ordering."
  (constant-external-id-< constant1 constant2))

;; (defun commutative-atoms-in-order-p (atom1 atom2) ...) -- active declareFunction, no body

(defun canon-term-< (term1 term2)
  "[Cyc] Canonical ordering predicate for terms."
  (commutative-terms-in-order-p term1 term2))

;; (defun canonicalize-functions-in-clause (clause) ...) -- active declareFunction, no body

(defun canonicalize-functions (clauses)
  "[Cyc] Puts all functions in CLAUSES in canonical form,
   by destructively reifying all reifiable functions and adding termOfUnit literals.
   Every function that has a reifiable functor should be reified.
   Every reifiable function that is quantified into should have a termOfUnit assertion."
  (if (or (null *canonicalize-functions-p*)
          (and (singletonp clauses)
               (pos-atomic-cnf-p (first clauses))
               (null (contains-subformula-p (gaf-cnf-literal (first clauses))))))
      clauses
      (let ((result nil))
        (let ((*tou-skolem-blist* nil))
          (setf result (add-term-of-unit-lits (reify-functions clauses t))))
        result)))

(defun add-term-of-unit-lits (clauses)
  "[Cyc] @note this is destructive"
  (let ((result nil))
    (let ((*clause-el-var-names* (clauses-free-variables clauses)))
      (setf result (if *add-term-of-unit-lits-p*
                       (nmapcar #'add-term-of-unit-lits-1 clauses)
                       clauses)))
    result))

(defun clauses-free-variables (clauses)
  "[Cyc] @return a list of the free variable in all the clauses."
  (let ((result nil))
    (dolist (clause clauses)
      (dolist (var-name (nmapcar #'str (clause-free-variables clause #'el-var-p)))
        (unless (member var-name result :test #'eql)
          (push var-name result))))
    result))

(defun add-term-of-unit-lits-1 (clause)
  "[Cyc] inference requires
   . one termOfUnit neg-lit whenever an axiom quantifies into a reifiable function
   . one evaluate neg-lit whenever an axiom quantifies into an evaluatable function
  @note this is destructive"
  (when (ground-p clause #'el-var-p)
    (return-from add-term-of-unit-lits-1 clause))
  (let ((quantified-fn-terms (clause-quantified-fn-terms clause)))
    (if quantified-fn-terms
        (multiple-value-bind (neg-lits pos-lits)
            (unmake-clause clause)
          (let ((target-lits (if (within-query-p) pos-lits neg-lits)))
            (dolist (fn-term quantified-fn-terms)
              (cond
                ;; missing-larkc 31091: reify-term-p or is-reifiable-term-p check;
                ;; determines if fn-term needs a termOfUnit literal added
                ((missing-larkc 31091)
                 ;; missing-larkc 8821: existing-tou-lit-p or similar;
                 ;; checks if a termOfUnit literal for fn-term already exists
                 (unless (missing-larkc 8821)
                   ;; missing-larkc 8841: make-tou-lit or make-term-of-unit-literal;
                   ;; creates the termOfUnit literal for fn-term
                   (setf target-lits (nadd-to-end (missing-larkc 8841) target-lits))))
                ;; missing-larkc 31084: evaluatable-function-term-p check;
                ;; determines if fn-term is an evaluatable function needing evaluate literal
                ((missing-larkc 31084)
                 ;; missing-larkc 8819: existing-evaluate-lit-p check
                 (unless (missing-larkc 8819)
                   ;; missing-larkc 8820: evaluate-lit-needed-p or similar additional check
                   (when (missing-larkc 8820)
                     ;; missing-larkc 8839: make-evaluate-lit; creates the evaluate literal
                     (setf target-lits (nadd-to-end (missing-larkc 8839) target-lits)))))))
            (if (within-query-p)
                (setf pos-lits target-lits)
                (setf neg-lits target-lits)))
          (list neg-lits pos-lits))
        clause)))

;; (defun equal-wrt-svm (expr1 expr2) ...) -- active declareFunction, no body
;; (defun reifiable-function-term-in-clause-p (term clause &optional mt) ...) -- active declareFunction, no body
;; (defun evaluatable-function-term-in-clause-p (term clause &optional mt) ...) -- active declareFunction, no body
;; (defun czer-create-narts-p () ...) -- active declareFunction, no body
;; (defun reify-relation-functions-in-mt-list (relation mt-list &optional reify-relation-p) ...) -- active declareFunction, no body

(defun reify-relation-functions (relation &optional (reify-relation-p t))
  "[Cyc] Reifies functions contained within RELATION.
   Like @xref reify-functions, except it takes a relation instead of clauses.  Also it doesn't reify skolems.
   @param REIFY-RELATION?; whether RELATION itself should be reified if possible."
  (if (relation-expression-p relation)
      (let ((functions nil))
        (dolist (term (cons relation (relation-terms-to-reify relation)))
          (unless (subl-escape-p relation)
            (unless (atom term)
              (when (reifiable-function-term-p term)
                (push term functions)))))
        (when functions
          (setf functions (delete-duplicates functions :test #'equal))
          (setf relation
                ;; missing-larkc 31100: subst-canon-fns or similar;
                ;; substitutes reified versions of each function term into relation
                (missing-larkc 31100)))
        relation)
      (progn
        (el-error 4 "Tried to reify functions within ~A, but it was not a relation expression."
                  relation)
        relation)))

;; (defun reify-relation-functions-in (relation functions mt) ...) -- active declareFunction, no body
;; (defun reify-relation-function-in (relation function mt) ...) -- active declareFunction, no body
;; (defun reify-functions-in-mt (clauses mt) ...) -- active declareFunction, no body

(defun reify-functions (clauses reify-skolems-p)
  "[Cyc] Destructively reifies all reifiable functions in CLAUSES.
   Assumes that each clause in CLAUSES is an EL formula. (huh?)"
  (let ((skolems nil)
        (functions nil))
    (dolist (term (mapnunion #'clause-terms-to-reify clauses #'equal))
      (cond
        ((subl-escape-p term))
        ((atom term))
        ((and reify-skolems-p
              (skolem-fn-function-p (nat-functor term)))
         (push term skolems))
        ((reifiable-function-term-p term)
         (push term functions))))
    (when functions
      (setf clauses
            ;; missing-larkc 31098: reify-functions-in or similar;
            ;; substitutes reified NART versions of each function term into clauses
            (missing-larkc 31098)))
    (when skolems
      (let ((error nil))
        (handler-case
            (setf clauses
                  ;; missing-larkc 13058: reify-skolem-functions or similar;
                  ;; reifies skolem function terms, wrapping sequence vars
                  (missing-larkc 13058))
          (error (ccatch-env-var)
            (declare (ignore ccatch-env-var))
            (setf error :too-many-sequence-vars-in-skolem-scope)))
        (when error
          (when *accumulating-wff-violations-p*
            ;; missing-larkc 8069: accumulate-wff-violation or similar;
            ;; records the too-many-sequence-vars error as a wff violation
            (missing-larkc 8069))
          (return-from reify-functions nil))))
    clauses))

;; (defun reify-functions-in (clauses functions) ...) -- active declareFunction, no body
;; (defun reify-function-in-fns (clause functions) ...) -- active declareFunction, no body
;; (defun reify-function-in (clause function) ...) -- active declareFunction, no body
;; (defun reify-function-in-destructive (clause function) ...) -- active declareFunction, no body
;; (defun canonicalize-fn-term-if-reified (fn-term) ...) -- active declareFunction, no body
;; (defun canonicalize-fn-term-if-reified-destructive (fn-term) ...) -- active declareFunction, no body
;; (defun canonicalize-fn-term (fn-term) ...) -- active declareFunction, no body
;; (defun cyc-find-or-create-nart (nat &optional mt) ...) -- active declareFunction, no body
;; (defun low-find-or-create-nart (nat) ...) -- active declareFunction, no body
;; (defun canonicalize-fn-term-int (nat reify-p find-p &optional mt) ...) -- active declareFunction, no body
;; (defun canonicalize-naut (nat) ...) -- active declareFunction, no body
;; (defun cyc-find-or-create-canonical-nart (nat) ...) -- active declareFunction, no body
;; (defun cyc-create-nart (nat) ...) -- active declareFunction, no body
;; (defun new-canonicalize-fn-term (fn-term) ...) -- active declareFunction, no body
;; (defun new-nested-fn-terms (fn-term) ...) -- active declareFunction, no body
;; (defun nested-fn-terms (fn-term) ...) -- active declareFunction, no body
;; (defun all-nested-fn-terms (fn-term) ...) -- active declareFunction, no body
;; (defun fort-sort-by-type-and-id (forts) ...) -- active declareFunction, no body
;; (defun fort-type-and-id-< (fort1 fort2) ...) -- active declareFunction, no body

(defun clause-quantified-fn-terms (clause)
  "[Cyc] @return list; the terms to reify in CLAUSE that are quantified into;
   i.e. have free variables within them."
  (let ((result nil))
    (let ((*gathering-quantified-fn-terms-p* t))
      (setf result (union (literals-quantified-fn-terms (neg-lits clause))
                          (literals-quantified-fn-terms (pos-lits clause))
                          :test #'equal)))
    result))

(defun literals-quantified-fn-terms (literals)
  "[Cyc] @return list; the terms to reify in LITERAL that are quantified into;
   i.e. have free variables within them."
  (mapappend #'literal-quantified-fn-terms literals))

(defun literal-quantified-fn-terms (literal)
  "[Cyc] @return list; the terms to reify in LITERAL that are quantified into;
   i.e. have free variables within them."
  (delete-if #'no-free-variables-p (literal-terms-to-reify literal)))

(defun clause-terms-to-reify (clause)
  "[Cyc] Return terms to reify in CLAUSE."
  (nunion (mapunion #'literal-terms-to-reify (neg-lits clause) #'equal)
          (mapunion #'literal-terms-to-reify (pos-lits clause) #'equal)
          :test #'equal))

(defun literal-terms-to-reify (literal &optional (mt *mt*))
  "[Cyc] Return terms to reify in LITERAL."
  (let ((result (relation-terms-to-reify literal mt)))
    (when (reify-term-p literal mt)
      (unless (member literal result :test #'equal)
        (push literal result)))
    result))

;; (defun function-terms-to-reify (function &optional mt) ...) -- active declareFunction, no body

(defun relation-terms-to-reify (relation &optional (mt *mt*))
  "[Cyc] Return terms to reify in RELATION."
  (if (and (el-formula-p relation)
           (null (guaranteed-nothing-to-reify-p relation))
           (el-relation-expression-p relation))
      (let ((result nil)
            (pos 0)
            (reln (formula-arg0 relation)))
        (unless (and *gathering-quantified-fn-terms-p*
                     (eq reln #$evaluate))
          (dolist (term (formula-terms relation))
            (let ((arg-isa-pred (if (fort-p reln) (arg-isa-pred pos reln mt) nil)))
              (let ((*permit-generic-arg-variables-p*
                     (or *permit-generic-arg-variables-p*
                         ;; missing-larkc 7228: generic-arg-variable-p check for this arg position;
                         ;; likely (arg-permits-generic-variables-p pos reln mt) or similar
                         (missing-larkc 7228)))
                    (*permit-keyword-variables-p*
                     (or *permit-keyword-variables-p*
                         ;; missing-larkc 7229: keyword-arg-variable-p check; parallel to 7228
                         (missing-larkc 7229))))
                ;; missing-larkc 31092: reify-arg-p check — determines if this arg should be reified
                ;; likely (reify-arg-p pos reln term mt) or similar
                (when (missing-larkc 31092)
                  (push term result))
                (cond
                  ((and *gathering-quantified-fn-terms-p*
                        (scoping-relation-expression-p term)))
                  ((and *gathering-quantified-fn-terms-p*
                        (evaluatable-function-term-p term mt)))
                  ;; missing-larkc 31079: dont-reify-arg-or-subterms-p check;
                  ;; determines if this arg and its subterms should be skipped
                  ((missing-larkc 31079))
                  ((naut-p term)
                   (setf result (ordered-union result (relation-terms-to-reify term mt) #'equal)))
                  ((sentence-p term)
                   (setf result (ordered-union result (relation-terms-to-reify term mt) #'equal)))
                  ;; missing-larkc 30577: el-formula-p or similar check on term type
                  ;; for literal-like terms that are not naut or sentence
                  ((missing-larkc 30577)
                   (setf result (ordered-union result (literal-terms-to-reify term mt) #'equal))))))
            (incf pos)))
        result)
      nil))

(defun guaranteed-nothing-to-reify-p (formula)
  "[Cyc] @return boolean; t iff FORMULA is guaranteed to contain nothing reifiable.
   A quick necessary test to avoid unnecessary work."
  (null (contains-subformula-p formula)))

;; (defun reify-arg-p (pos relation term &optional mt) ...) -- active declareFunction, no body
;; (defun dont-reify-arg-or-subterms-p (pos relation term mt) ...) -- active declareFunction, no body

(defun reify-term-p (term &optional (mt nil))
  "[Cyc] Return T if TERM should be reified."
  (cond
    ((atom term) nil)
    ((unreified-skolem-term-p term)
     *reify-skolems-p*)
    ((and (hl-ground-naut-p term)
          ;; missing-larkc 10334: already-reified-p or nart-exists-p check;
          ;; determines if this HL ground nat already has a NART in the KB
          (missing-larkc 10334))
     t)
    ((reifiable-function-term-p term mt)
     (if (within-forward-inference-p)
         ;; missing-larkc 31085: forward-inference-reifiable-function-term-p check;
         ;; determines if this function term should be reified during forward inference
         (missing-larkc 31085)
         t))
    ((evaluatable-function-term-p term mt) t)
    (t nil)))

;; (defun forward-inference-reifiable-function-term-p (fn-term &optional mt) ...) -- active declareFunction, no body

(defun forward-inference-reifiable-function-p (function &optional (mt nil))
  "[Cyc] Return T if FUNCTION should be reified during forward inference."
  (let ((rule (current-forward-inference-rule)))
    (or *prefer-forward-skolemization*
        (skolemize-forward-p function mt)
        (and rule (forward-reification-rule-p function rule)))))

;; (defun subst-canon-fn-in-clauses (clauses function canon-fn) ...) -- active declareFunction, no body
;; (defun subst-canon-fn-in-clause (clause function canon-fn) ...) -- active declareFunction, no body
;; (defun subst-canon-fn-in-relation (relation function canon-fn &optional mt) ...) -- active declareFunction, no body
;; (defun subst-canon-fn-in-literal (literal function canon-fn) ...) -- active declareFunction, no body
;; (defun subst-canon-fn-in-nat (nat function canon-fn) ...) -- active declareFunction, no body

(defun canonicalize-clauses-tou-terms (clauses)
  "[Cyc] @note this is destructive"
  (if *canonicalize-functions-p*
      (nmapcar #'canonicalize-clause-tou-terms clauses)
      clauses))

(defun canonicalize-clause-tou-terms (clause)
  "[Cyc] replace references in <clause>
   . to reifiable nats with their reifications
   . to evaluatable nats with their evaluations"
  (let ((term-x-nats (nat-atoms clause)))
    (if term-x-nats
        (let ((neg-lits (neg-lits clause))
              (pos-lits (pos-lits clause))
              (result nil))
          (let ((*appraising-disjunct-p* (or *appraising-disjunct-p*
                                             (and neg-lits pos-lits)))
                (*standardize-variables-memory*
                 ;; missing-larkc 31081: merge or extend standardize-variables-memory
                 ;; for TOU terms; likely returns updated memory alist
                 (missing-larkc 31081)))
            (setf result
                  (make-cnf
                   ;; missing-larkc 31055: canonicalize-lits-tou-terms for neg-lits;
                   ;; substitutes reified/evaluated versions of nat atoms in neg-lits
                   (missing-larkc 31055)
                   ;; missing-larkc 31056: canonicalize-lits-tou-terms for pos-lits;
                   ;; symmetric with 31055 for positive literals
                   (missing-larkc 31056))))
          result)
        clause)))

(defun nat-atoms (clause)
  "[Cyc] Return nat atoms (termOfUnit/evaluate args) found in clause."
  (let ((term-x-nats nil))
    (dolist (lit (if (within-query-p) (pos-lits clause) (neg-lits clause)))
      (cond
        ((tou-lit-p lit)
         (push (literal-args lit) term-x-nats))
        ((evaluate-lit-p lit)
         (push (literal-args lit) term-x-nats))))
    (nreverse term-x-nats)))

;; (defun canonicalize-literals-tou-terms (literals mt) ...) -- active declareFunction, no body
;; (defun dwim-svm-wrt-scoping (old-var new-var clause) ...) -- active declareFunction, no body
;; (defun var-is-scoped-in-literal-p (var literal) ...) -- active declareFunction, no body
;; (defun var-is-scoped-in-formula-p (var) ...) -- active declareFunction, no body

(defun canonicalize-clauses-literals (clauses)
  "[Cyc] For each clause in CLAUSES, sorts its literals into a canonical order.
   Also canonicalizes disjunctions as enumerations.
   (Does not change the order of the clauses, because that would be pointless.
   It's not like the canonicalizer is going to impose a canonical order on the assertions in the KB.)"
  (if *canonicalize-literals-p*
      (let ((sorted-clauses (sort-clauses-literals clauses)))
        (if *canonicalize-disjunction-as-enumeration-p*
            ;; missing-larkc 31041: canonicalize-disjunctions-as-enumerations;
            ;; converts disjunctive clauses into enumeration form
            (missing-larkc 31041)
            sorted-clauses))
      clauses))

;; (defun sort-clauses (clauses) ...) -- active declareFunction, no body
;; (defun clauses-in-order-p (clause1 clause2) ...) -- active declareFunction, no body

(defun sort-clauses-literals (clauses)
  "[Cyc] Sort all clause literals into canonical order."
  (nmapcar #'sort-clause-literals clauses))

(defun sort-clause-literals (clause &optional (var-p *var-p*))
  "[Cyc] Sorts the literals in CLAUSE into a canonical order."
  (sort-clause-literals-destructive (copy-clause clause) var-p))

;; (defun canonicalize-skolem-clause (clause &optional var-p) ...) -- active declareFunction, no body

(defun sort-clause-literals-destructive (clause &optional (var-p *var-p*))
  "[Cyc] A destructive version of @xref sort-clause-literals."
  (let ((result nil))
    (let ((*var-p* var-p))
      (multiple-value-bind (neg-lits pos-lits)
          (unmake-clause clause)
        (setf result (append (nmapcar #'negate-atomic neg-lits) pos-lits))
        (setf result (sort-literals result))
        (setf result (evaluate-lits-at-rear result))
        (setf result (tou-lits-at-rear result))
        (setf result (npackage-cnf-clause result))))
    result))

(defun tou-lits-at-rear (literals)
  "[Cyc] puts termOfUnit literals at rear (for cosmetic sake; otherwise, order is unchanged)"
  (let ((front nil)
        (back nil))
    (dolist (lit literals)
      (if (and (el-negation-p lit)
               (tou-lit-p (second lit)))
          (push lit back)
          (push lit front)))
    (nconc (nreverse front) (nreverse back))))

(defun evaluate-lits-at-rear (literals)
  "[Cyc] puts evaluate literals at rear (for cosmetic sake; otherwise, order is unchanged)"
  (let ((front nil)
        (back nil))
    (dolist (lit literals)
      (if (and (el-negation-p lit)
               (evaluate-lit-p (second lit)))
          (push lit back)
          (push lit front)))
    (nconc (nreverse front) (nreverse back))))

(defun sort-literals (literals &optional (bound-vars nil)
                                          (connected-vars nil)
                                          (already-sorted-literals nil)
                                          (originals literals))
  "[Cyc] Sort LITERALS into canonical order."
  (cond
    ((null literals) nil)
    ((singletonp literals) literals)
    (t
     (let ((next-literal (pick-a-lit literals bound-vars connected-vars
                                     already-sorted-literals originals)))
       (cons next-literal
             (sort-literals (remove next-literal literals :test #'equal)
                            (new-bound-vars next-literal bound-vars)
                            (new-connected-vars next-literal bound-vars)
                            (cons next-literal already-sorted-literals)
                            originals))))))

(defun pick-a-lit (literals &optional (bound-vars nil)
                                       (connected-vars nil)
                                       (already-sorted-literals nil)
                                       (originals nil))
  "[Cyc] Returns the first literal in LITERALS with respect to the canonical ordering."
  (let ((results nil)
        (verbose-p nil))
    (setf results (most-constrained-literals literals bound-vars))
    (when (singletonp results)
      (when verbose-p (warn "most-constrained-literals succeeded!"))
      (return-from pick-a-lit (first results)))
    (setf results (fewest-arg-literals results))
    (when (singletonp results)
      (when verbose-p (warn "fewest-arg-literals succeeded!"))
      (return-from pick-a-lit (first results)))
    (setf results (left-weighted-literals results))
    (when (singletonp results)
      (when verbose-p (warn "left-weighted-literals succeeded!"))
      (return-from pick-a-lit (first results)))
    (setf results (left-connected-literals results connected-vars))
    (when (singletonp results)
      (when verbose-p (warn "left-connected-literals succeeded!"))
      (return-from pick-a-lit (first results)))
    (setf results (left-rooted-literals results originals))
    (when (singletonp results)
      (when verbose-p (warn "left-rooted-literals succeeded!"))
      (return-from pick-a-lit (first results)))
    (setf results (least-complex-literals results))
    (when (singletonp results)
      (when verbose-p (warn "least-complex-literals succeeded!"))
      (return-from pick-a-lit (first results)))
    (if *new-canonicalizer-p*
        (progn
          (setf results
                ;; missing-larkc 29109: penultimate-resort-literals-1;
                ;; additional tie-breaking strategy in new canonicalizer
                (missing-larkc 29109))
          (when (singletonp results)
            (when verbose-p (warn "penultimate-resort-literals-1 succeeded!"))
            (return-from pick-a-lit (first results)))
          (setf results
                ;; missing-larkc 29110: penultimate-resort-literals-2;
                ;; second additional tie-breaking strategy in new canonicalizer
                (missing-larkc 29110))
          (when (singletonp results)
            (when verbose-p (warn "penultimate-resort-literals-2 succeeded!"))
            (return-from pick-a-lit (first results)))
          ;; missing-larkc 29104: last-resort-literal in new canonicalizer;
          ;; absolute fallback for new canonicalizer literal ordering
          (missing-larkc 29104))
        (old-last-resort-literal results literals))))

(defun new-bound-vars (literal &optional (bound-vars nil))
  "[Cyc] Return updated bound vars after processing LITERAL."
  (let ((vars (ordered-set-difference (literal-variables literal) bound-vars :test #'equal)))
    (if (singletonp vars)
        (append bound-vars vars)
        bound-vars)))

(defun new-connected-vars (literal &optional (connected-vars nil))
  "[Cyc] Return updated connected vars after processing LITERAL."
  (nconc (ordered-set-difference (literal-variables literal) connected-vars :test #'equal)
         connected-vars))

(defun unbound-vars (vars bound-vars)
  "[Cyc] Return the subset of VARS that are not bound in BOUND-VARS."
  (let ((unbound (ordered-set-difference vars bound-vars :test #'equal)))
    (dolist (var vars)
      (when (unreified-skolem-term-p var)
        (let ((unbound-p nil))
          (unless unbound-p
            (let ((found nil))
              (dolist (free-var (second var))
                (unless (member free-var bound-vars)
                  (setf found t)
                  (return)))
              (setf unbound-p found)))
          (unless unbound-p
            (setf unbound (remove var unbound :test #'equal))))))
    unbound))

(defun most-constrained-literals (literals &optional (bound-vars nil)
                                                     (var-p *var-p*))
  "[Cyc] Return the subset of LITERALS with the fewest unbound variables."
  (let* ((ans (list (first literals)))
         (min (unbound-vars-score (literal-variables (first ans) var-p) bound-vars))
         (score nil))
    (dolist (literal (rest literals))
      (setf score (unbound-vars-score (literal-variables literal var-p) bound-vars))
      (cond
        ((= score min) (push literal ans))
        ((< score min)
         (setf min score)
         (setf ans (list literal)))))
    (reverse ans)))

(defun unbound-vars-score (vars bound-vars)
  "[Cyc] Return the number of unbound vars."
  (length (unbound-vars vars bound-vars)))

;; (defun temp-unbound-vars-score (vars bound-vars) ...) -- active declareFunction, no body

(defun fewest-arg-literals (literals)
  "[Cyc] Return the subset of LITERALS with the fewest arguments."
  (if (singletonp literals)
      literals
      (let* ((ans (list (first literals)))
             (min (literal-arity (first ans)))
             (score nil))
        (dolist (literal (rest literals))
          (setf score (literal-arity literal))
          (cond
            ((= score min) (push literal ans))
            ((< score min)
             (setf min score)
             (setf ans (list literal)))))
        (reverse ans))))

(defun left-weighted-literals (literals)
  "[Cyc] Return the subset of LITERALS with the highest left-weighted score."
  (if (singletonp literals)
      literals
      (let* ((ans (list (first literals)))
             (max (left-weighted-score (literal-args (first literals))))
             (score nil))
        (dolist (literal (rest literals))
          (setf score (left-weighted-score (literal-args literal)))
          (cond
            ((= score max) (push literal ans))
            ((> score max)
             (setf max score)
             (setf ans (list literal)))))
        (reverse ans))))

(defun left-weighted-score (symbols &optional (symbol (first symbols)))
  "[Cyc] Compute left-weighted score for SYMBOLS."
  (let ((score 0)
        (length (length symbols))
        (weights (first-n (length symbols)
                          (n-left-weighted-score-weights (length symbols) 10))))
    (dotimes (n length)
      (when (equal symbol (nth n symbols))
        (setf score (+ score (nth (- length n 1) weights)))))
    score))

(defun n-left-weighted-score-weights (n &optional (multiplier 10))
  "[Cyc] Compute N left-weighted score weights."
  (let ((weights nil)
        (weight 1))
    (dotimes (i n)
      (push weight weights)
      (setf weight (* weight multiplier)))
    (nreverse weights)))

(defun left-connected-literals (literals &optional (connected-vars nil))
  "[Cyc] Return the subset of LITERALS with the highest left-connected score."
  (if (singletonp literals)
      literals
      (let* ((ans (list (first literals)))
             (max (left-connected-score (literal-args (first literals)) connected-vars))
             (score nil))
        (dolist (literal (rest literals))
          (setf score (left-connected-score (literal-args literal) connected-vars))
          (cond
            ((= score max) (push literal ans))
            ((> score max)
             (setf max score)
             (setf ans (list literal)))))
        (reverse ans))))

(defun left-connected-score (vars connected-vars)
  "[Cyc] Compute left-connected score for VARS."
  (let ((score 0)
        (psn 0))
    (dolist (var (reverse vars))
      (incf psn)
      (setf score (+ score (* (length (member var connected-vars :test #'equal)) psn))))
    score))

(defun left-rooted-literals (literals &optional (original literals))
  "[Cyc] Return the subset of LITERALS with the highest left-rooted score."
  (left-rooted-literals-int (default-lit-sort literals)
                             (default-lit-sort original)))

(defun default-lit-sort (literals)
  "[Cyc] Sort LITERALS using the default lit ordering."
  (stable-sort (copy-list literals) #'lit-<))

(defun lit-< (lit-1 lit-2)
  "[Cyc] Ordering predicate for literals."
  (cond
    ((and (el-negation-p lit-1) (null (el-negation-p lit-2))) t)
    ((and (null (el-negation-p lit-1)) (el-negation-p lit-2)) nil)
    ((not (equal (literal-arg0 lit-1) (literal-arg0 lit-2)))
     (pred-< (literal-arg0 lit-1) (literal-arg0 lit-2)))
    (t
     (canon-term-< (literal-args lit-1) (literal-args lit-2)))))

(defun pred-< (pred-1 pred-2)
  "[Cyc] Ordering predicate for predicates."
  (if (and (fort-p pred-1) (fort-p pred-2))
      (let ((pred-1-psn (position pred-1 *hl-pred-order*))
            (pred-2-psn (position pred-2 *hl-pred-order*)))
        (cond
          ((and pred-1-psn pred-2-psn)
           (> pred-2-psn pred-1-psn))
          (pred-1-psn t)
          (pred-2-psn nil)
          (t
           (let ((arity-1 (arity pred-1))
                 (arity-2 (arity pred-2)))
             (cond
               ((and arity-1 arity-2 (not (= arity-1 arity-2)))
                (> arity-2 arity-1))
               (arity-1 t)
               (arity-2 nil)
               ((and (constant-p pred-1) (nart-p pred-2)) t)
               ((and (nart-p pred-1) (constant-p pred-2)) t)
               ((and (constant-p pred-1) (constant-p pred-2))
                (canonicalizer-constant-< pred-1 pred-2))
               ((and (nart-p pred-1) (nart-p pred-2))
                (canon-term-<
                 ;; missing-larkc 10401: nart-formula or nart-hl-formula for pred-1;
                 ;; converts NART to its HL formula for comparison
                 (missing-larkc 10401)
                 ;; missing-larkc 10402: nart-formula or nart-hl-formula for pred-2 (symmetric)
                 (missing-larkc 10402)))
               (t
                (el-error 1 "Got a fort that was neither a nart nor a constant.  It was one of these: ~a or ~a"
                          pred-1 pred-2)))))))
      (canon-term-< pred-1 pred-2)))

(defun left-rooted-literals-int (literals &optional (original literals))
  "[Cyc] Internal version of left-rooted-literals."
  (if (singletonp literals)
      literals
      (let* ((ans (list (first literals)))
             (max (left-rooted-score (first literals) original))
             (score nil))
        (dolist (literal (rest literals))
          (setf score (left-rooted-score literal original))
          (cond
            ((= score max) (push literal ans))
            ((> score max)
             (setf max score)
             (setf ans (list literal)))))
        (reverse ans))))

(defun left-rooted-score (literal literals &optional (depth 1))
  "[Cyc] Compute left-rooted score for LITERAL within LITERALS."
  (unless (eq *ignore-musts-p* nil)
    (unless (member literal literals :test #'equal)
      (error "~s is not an element of ~s" literal literals)))
  (let* ((symbols (literal-args literal))
         (score (left-weighted-score symbols))
         (rest (remove literal literals :test #'equal))
         (psn 0)
         (out-scores nil)
         (out nil)
         (out-score nil)
         (lit-score nil)
         (connected-p nil)
         (unconnected nil))
    (dolist (symbol (remove-duplicates symbols :test #'equal))
      (incf psn)
      (dolist (lit rest)
        (setf connected-p nil)
        (setf out nil)
        (dolist (term (literal-args lit))
          (if (member term symbols :test #'equal)
              (setf connected-p t)
              (unless (member term out :test #'equal)
                (push term out))))
        (when connected-p
          (setf lit-score (left-weighted-score (literal-args lit) symbol))
          (setf score (+ score (/ lit-score psn)))
          (when out
            (push lit unconnected)
            (dolist (term out)
              (let ((existing (assoc term out-scores :test #'equal)))
                (if existing
                    (rplacd existing (+ (cdr existing) lit-score))
                    (push (cons term lit-score) out-scores))))))))
    (let* ((root-term (max-scored-item out-scores #'cdr #'car))
           (root-lit nil)
           (max 0))
      (dolist (lit unconnected)
        (setf lit-score (left-weighted-score (formula-terms lit) root-term))
        (when (> lit-score max)
          (setf max lit-score)
          (setf root-lit lit)))
      (when root-lit
        (setf score (/ (+ score (left-rooted-score root-lit rest (* depth 10)))
                       depth))))
    score))

(defun max-scored-item (items &optional (score-key #'identity) (result-key #'identity))
  "[Cyc] Return the item in ITEMS with the highest score."
  (let ((max most-negative-fixnum)
        (score nil)
        (result nil))
    (dolist (item items)
      (setf score (funcall score-key item))
      (when (> score max)
        (setf max score)
        (setf result (funcall result-key item))))
    result))

(defun least-complex-literals (literals &optional (var-p *var-p*))
  "[Cyc] Return the subset of LITERALS with the lowest EL complexity score."
  (if (singletonp literals)
      literals
      (let* ((first (first literals))
             (ans (list first))
             (min (el-complexity-score first var-p)))
        (dolist (literal (rest literals))
          (let ((score (el-complexity-score literal var-p)))
            (cond
              ((= score min) (push literal ans))
              ((< score min)
               (setf min score)
               (setf ans (list literal))))))
        (reverse ans))))

(defun el-complexity-score (object &optional (var-p *var-p*) (factor 1))
  "[Cyc] Compute the EL complexity score of OBJECT."
  (cond
    ((null object) 0)
    ((constant-p object) 1)
    ((funcall var-p object) 3)
    ((nart-p object)
     (+ 5 (/ (el-complexity-score
              ;; missing-larkc 10403: nart-formula or nart-hl-formula;
              ;; converts NART to its formula for complexity scoring
              (missing-larkc 10403)
              var-p factor)
             2)))
    ((stringp object)
     (+ 4 (/ (length object) 2)))
    ((assertion-p object)
     (+ 1000 (el-complexity-score (assertion-fi-formula object) var-p factor)))
    ((atom object) 2)
    ((consp object)
     (+ 100
        (el-complexity-score (first object) var-p factor)
        (* factor (el-complexity-score (rest object) var-p (* factor 0.9)))))
    (t 10000)))

(defun default-preference-lit (literals)
  "[Cyc] Return a preferred literal from LITERALS based on HL pred order."
  (let ((ans nil)
        (min most-positive-fixnum))
    (dolist (lit literals)
      (let ((score (position (literal-arg0 lit) *hl-pred-order*)))
        (when score
          (cond
            ((> min score)
             (setf min score)
             (setf ans (list lit)))
            ((= min score)
             (push lit ans))))))
    (when (singletonp ans)
      (return-from default-preference-lit (first ans))))
  nil)

;; (defun canonicalize-disjunctions-as-enumerations (clauses) ...) -- active declareFunction, no body

(defun canonicalize-clauses-variables (clauses)
  "[Cyc] Canonicalize variable names in all CLAUSES."
  (rename-clauses-vars clauses))

(defun rename-clauses-vars (clauses)
  "[Cyc] Rename variables in all CLAUSES to canonical names."
  (nmapcar #'rename-clause-vars-int clauses))

(defun standardize-variable-memory-binding (var expression)
  "[Cyc] Find canonical binding for VAR with respect to EXPRESSION."
  (let ((referenced-as-list nil)
        (ambiguous-p nil))
    (unless ambiguous-p
      (dolist (binding (all-bindings var *standardize-variables-memory*))
        (when (ambiguous-p (simple-tree-find-p binding expression))
          (when (or referenced-as-list
                    (simple-tree-find-p var expression))
            (setf ambiguous-p t)))
        (push binding referenced-as-list)))
    (values referenced-as-list ambiguous-p)))

(defun el-nununiquifying-blist-wrt (expression &optional (update-p nil) (force-p nil))
  "[Cyc] Compute the de-uniquifying binding list wrt EXPRESSION."
  (let ((blist nil))
    (dolist (var (fast-delete-duplicates (mapcar #'car *standardize-variables-memory*)))
      (multiple-value-bind (referenced-as-list ambiguous-p)
          (standardize-variable-memory-binding var expression)
        (when (or force-p (null ambiguous-p))
          (when referenced-as-list
            (dolist (referenced-as referenced-as-list)
              (push (cons referenced-as var) blist)
              (when update-p
                (setf *standardize-variables-memory*
                      (nsubst var referenced-as *standardize-variables-memory*))))))))
    blist))

(defun el-nununiquify-vars-wrt-int (expression-1 expression-2
                                    &optional (update-p nil) (force-p nil))
  "[Cyc] De-uniquify variables in EXPRESSION-1 with respect to EXPRESSION-2."
  (let ((blist (el-nununiquifying-blist-wrt expression-2 update-p force-p)))
    (when blist
      (let ((*canonicalize-variables-p* nil))
        (expression-nsublis-free-vars blist expression-1))))
  expression-1)

;; (defun el-nununiquify-vars-wrt (expression-1 expression-2) ...) -- active declareFunction, no body

(defun el-nununiquify-vars-int (expression &optional (update-p nil) (force-p nil))
  "[Cyc] replace uniquified vars with origs when not ambiguous"
  (el-nununiquify-vars-wrt-int expression expression update-p force-p))

;; (defun el-ununiquify-vars-int (expression &optional (update-p nil) (force-p nil)) ...) -- active declareFunction, no body

(defun el-nununiquify-vars (expression)
  "[Cyc] De-uniquify variables in EXPRESSION."
  (el-nununiquify-vars-int expression nil))

;; (defun uniquify (expression) ...) -- active declareFunction, no body
;; (defun rename-clauses-vars-safe (clauses) ...) -- active declareFunction, no body
;; (defun rename-clause-vars (clause &optional var-p) ...) -- active declareFunction, no body

(defun rename-clause-vars-int (clause &optional (var-p nil))
  "[Cyc] Rename variables in CLAUSE to canonical names."
  (let ((blist nil)
        (free-vars nil)
        (closed-vars nil))
    (setf clause (el-nununiquify-vars-int clause t))
    (when *canonicalize-variables-p*
      (let ((meta-blist nil)
            (old nil)
            (new nil)
            (count 0)
            (variables (if var-p
                           (clause-el-variables clause var-p)
                           (clause-el-variables clause #'canon-var-p))))
        (when variables
          (setf closed-vars (mapcar #'cdr *standardize-variables-memory*))
          (setf free-vars (fast-set-difference variables closed-vars))
          (dolist (assertion (formula-gather clause #'assertion-p nil))
            (dolist (var (assertion-el-variables assertion))
              (when (member var variables)
                (push (cons var (get-nth-canonical-variable count)) blist)
                (incf count))))
          (dolist (var variables)
            (cond
              ((assoc var blist)) ; already bound
              ((unreified-skolem-term-p var)
               (el-error 2 "~s treated as variable in rename-clause-vars" var)
               (setf new (first (last var)))
               (setf old (car (rassoc new *standardize-variables-memory*)))
               (when old
                 (push (cons new (get-nth-canonical-variable count)) blist)
                 (push (cons new old) meta-blist)
                 (incf count)))
              (t
               (push (cons var (get-nth-canonical-variable count)) blist)
               (incf count))))
          (setf clause (expression-nsublis-free-vars blist clause))
          (setf blist (nreverse (sublis meta-blist blist))))))
    (if *within-ask*
        (list clause blist (blist-vars-among blist (blist-vars-among blist free-vars)))
        (list clause blist))))

(defun blist-vars-among (blist vars)
  "[Cyc] Return the variables in BLIST that are among VARS."
  (let ((result nil))
    (dolist (binding blist)
      (when (member (car binding) vars)
        (push (car binding) result)))
    (nreverse result)))

;; (defun blist-vars-not-among (blist vars) ...) -- active declareFunction, no body

(defun all-bindings (symbol bindings)
  "[Cyc] Return all values that SYMBOL is bound to in BINDINGS."
  (let ((result nil))
    (dolist (binding bindings)
      (when (eql symbol (car binding))
        (push (cdr binding) result)))
    (nreverse result)))

(defun clause-el-variables (clause &optional (var-p #'el-var-p))
  "[Cyc] Return the EL variables free in CLAUSE."
  (when (null (tree-find-if var-p clause))
    (return-from clause-el-variables nil))
  (clause-free-variables clause var-p))

(defun initialize-symbol-suffix-table (formula)
  "[Cyc] Assumes the EL variable namespace is bound."
  (tree-funcall-if #'el-var-p #'initialize-suffix-table-for-var formula)
  nil)

(defun initialize-suffix-table-for-var (el-var)
  "[Cyc] Initialize the suffix table entry for EL-VAR."
  (multiple-value-bind (integer symbol)
      (extract-name-uniquifying-post-hyphen-integer el-var)
    (when (and (integerp integer) (symbolp symbol))
      (when (>= integer 0)
        (let ((n (gethash symbol *el-symbol-suffix-table*)))
          (when (or (not (integerp n)) (> integer n))
            (setf (gethash symbol *el-symbol-suffix-table*) integer)
            (return-from initialize-suffix-table-for-var integer))))))
  nil)

(defun extract-name-uniquifying-post-hyphen-integer (symbol)
  "[Cyc] Extract the trailing hyphen-integer suffix from SYMBOL's name."
  (when (symbolp symbol)
    (let* ((string (symbol-name symbol))
           (hyphen nil)
           (next nil)
           (end nil))
      (setf hyphen (char-position #\- string))
      (setf next (when (integerp hyphen) (+ 1 hyphen)))
      (setf end (when (integerp next)
                  (char-type-position #'not-digit-char-p string next)))
      (loop while (not (or (null next)
                           (and (> (length string) next)
                                (digit-char-p (char string next))
                                (null end)))) do
        (setf hyphen (char-position #\- string next))
        (setf next (when (integerp hyphen) (+ 1 hyphen)))
        (setf end (when (integerp next)
                    (char-type-position #'not-digit-char-p string next))))
      (when (integerp next)
        (let ((integer (read-from-string (subseq string next))))
          (when (integerp integer)
            (return-from extract-name-uniquifying-post-hyphen-integer
              (values integer
                      (intern (subseq string 0 hyphen)))))))))
  nil)

(defun canonicalize-clauses (clauses mt)
  "[Cyc] Canonicalize CLAUSES in MT."
  (let ((*relevant-mt-function* (possibly-in-mt-determine-function mt))
        (*mt* (possibly-in-mt-determine-mt mt)))
    (unless (cycl-truth-value-p clauses)
      (if (canon-fast-clauses-p clauses)
          (setf clauses (list clauses))
          (progn
            (setf clauses (canonicalize-clauses-wrt-rule-macros clauses))
            (setf clauses (canonicalize-meta-clauses clauses))
            (setf clauses (canonicalize-clauses-terms clauses))
            (setf clauses (canonicalize-clauses-literals clauses))
            (setf clauses (canonicalize-clauses-variables clauses))))))
  (multiple-value-setq (clauses mt)
    (unwrap-clauses-if-ist-permissive clauses mt))
  (multiple-value-setq (clauses mt)
    (lift-clauses-if-decontextualized clauses mt))
  (values clauses mt))

(defun unwrap-clauses-if-ist-permissive (clauses input-mt)
  "[Cyc] Where possible, unwraps #$ist literals in CLAUSES"
  (values clauses input-mt))

(defun canonicalize-query-clauses (clauses mt)
  "[Cyc] Canonicalize query CLAUSES in MT."
  (let ((*mt* (update-inference-mt-relevance-mt mt))
        (*relevant-mt-function* (update-inference-mt-relevance-function mt))
        (*relevant-mts* (update-inference-mt-relevance-mt-list mt)))
    (unless (cycl-truth-value-p clauses)
      (setf clauses (canonicalize-meta-clauses clauses))
      (setf clauses (canonicalize-clauses-terms clauses))
      (setf clauses (canonicalize-clauses-literals clauses))
      (setf clauses (canonicalize-clauses-variables clauses))))
  (multiple-value-setq (clauses mt)
    (unwrap-clauses-if-ist-permissive clauses mt))
  (multiple-value-setq (clauses mt)
    (lift-clauses-if-decontextualized clauses mt))
  (values clauses mt))

(defun canon-fast-clauses-p (clauses)
  "[Cyc] Return T if CLAUSES can be fast-path canonicalized (no term work needed)."
  (when (singletonp clauses)
    (let ((clause (first clauses)))
      (when (pos-atomic-cnf-p clause)
        (let ((lit (first (pos-lits clause))))
          (and (member (formula-operator lit) '(#$isa #$genls))
               (ground-p lit #'el-var-p)
               (null (contains-subformula-p lit))))))))

(defun lift-clauses-if-decontextualized (czer-clauses mt)
  "[Cyc] Lift clauses to UniversalVocabularyMt if they are decontextualized."
  (let ((v-clauses (extract-hl-clauses czer-clauses)))
    (unless (atomic-clauses-p v-clauses)
      (when (generalized-ist-clauses-p v-clauses)
        (setf mt #$UniversalVocabularyMt))))
  (values czer-clauses mt))

(defun psc-query-p (&optional (mt *mt*))
  "[Cyc] Return T if this is a PSC (problem-solving context) query."
  (and (within-query-p)
       ;; missing-larkc 32154: psc-mt-p or within-psc-p check;
       ;; determines if the current context is a problem-solving context
       (missing-larkc 32154)))

;; (defun canonicalizer-problem-p (sentence) ...) -- active declareFunction, no body
;; (defun tl-canonicalizer-problem-p (sentence) ...) -- active declareFunction, no body
;; (defun terms-reorder-equal-p (term1 term2) ...) -- active declareFunction, no body
;; (defun cnfs-reorder-tou-equal-p (cnf1 cnf2 &optional mt) ...) -- active declareFunction, no body
;; (defun unique-arity-literal (literal) ...) -- active declareFunction, no body
;; (defun unique-list-structure-literal (literal) ...) -- active declareFunction, no body

(defun old-last-resort-literal (literals &optional (candidates nil) (var-p *var-p*))
  "[Cyc] Last resort literal selection using old algorithm."
  (let ((literal (default-preference-lit literals)))
    (if literal
        literal
        (alphabetically-minimal-literal literals candidates var-p))))

(defun alphabetically-minimal-literal (literals &optional (candidates nil) (var-p *var-p*))
  "[Cyc] Return the alphabetically minimal literal."
  (if (singletonp literals)
      (first literals)
      (new-alphabetically-minimal-literal-int literals candidates var-p)))

(defun new-alphabetically-minimal-literal-int (literals &optional (candidates literals)
                                                                   (var-p *var-p*))
  "[Cyc] Internal version of alphabetically-minimal-literal."
  (let* ((ans (list (first literals)))
         (ans-string (str (formula-non-var-symbols (first ans) var-p))))
    (dolist (literal (rest literals))
      (let ((lit-string (str (formula-non-var-symbols literal var-p))))
        (cond
          ((string< lit-string ans-string)
           (setf ans-string lit-string)
           (setf ans (list literal)))
          ((string= lit-string ans-string)
           (push literal ans)))))
    (when (singletonp ans)
      (return-from new-alphabetically-minimal-literal-int (first ans)))
    (let* ((candidates-1 (last-resort-min-literals
                          (ordered-set-difference literals ans :test #'equal)))
           (candidates-2 (last-resort-min-literals
                          (ordered-set-difference candidates literals :test #'equal)))
           (candidates-3 (last-resort-min-literals candidates)))
      (when (singletonp candidates-1)
        (return-from new-alphabetically-minimal-literal-int (first candidates-1)))
      (when (singletonp candidates-2)
        (return-from new-alphabetically-minimal-literal-int (first candidates-2)))
      (when (singletonp candidates-3)
        (return-from new-alphabetically-minimal-literal-int (first candidates-3)))
      (let* ((length-0 (if ans (length ans) most-positive-fixnum))
             (length-1 (if candidates-1 (length candidates-1) most-positive-fixnum))
             (length-2 (if candidates-2 (length candidates-2) most-positive-fixnum))
             (length-3 (if candidates-3 (length candidates-3) most-positive-fixnum))
             (min (min length-0 length-1 length-2 length-3)))
        (cond
          ((= min length-0)
           (new-alphabetically-minimal-literal-int-2 (default-lit-sort ans) var-p))
          ((= min length-1)
           (new-alphabetically-minimal-literal-int-2 (default-lit-sort candidates-1) var-p))
          ((= min length-2)
           (new-alphabetically-minimal-literal-int-2 (default-lit-sort candidates-2) var-p))
          ((= min length-3)
           (new-alphabetically-minimal-literal-int-2 (default-lit-sort candidates-3) var-p))
          (t
           (new-alphabetically-minimal-literal-int-2 (default-lit-sort literals) var-p)))))))

(defun new-alphabetically-minimal-literal-int-2 (literals &optional (var-p *var-p*))
  "[Cyc] Second internal version: final tiebreak."
  (if (tree-find-if var-p literals)
      (new-alphabetically-minimal-literal-int literals literals #'false)
      (first literals)))

(defun old-commutative-terms-in-order-p (term1 term2)
  "[Cyc] Old commutative term ordering predicate."
  (if (atom term1)
      (if (atom term2)
          (old-commutative-atoms-in-order-p term1 term2)
          t)
      (if (atom term2)
          nil
          (old-commutative-conses-in-order-p term1 term2))))

(defun old-commutative-atoms-in-order-p (atom1 atom2)
  "[Cyc] Old commutative atom ordering predicate."
  (when (and (null *control-3*) (equal atom1 atom2))
    (return-from old-commutative-atoms-in-order-p t))
  (cond
    ((constant-p atom1)
     (if (constant-p atom2)
         (canonicalizer-constant-< atom1 atom2)
         t))
    ((constant-p atom2) nil)
    ((nart-p atom1)
     (if (nart-p atom2)
         (< ;; missing-larkc 30867: nart-id or nart-external-id for atom1
            (missing-larkc 30867)
            ;; missing-larkc 30868: nart-id or nart-external-id for atom2 (symmetric)
            (missing-larkc 30868))
         t))
    ((nart-p atom2) nil)
    ((el-var-p atom1)
     (if (el-var-p atom2)
         (string-lessp (symbol-name atom1) (symbol-name atom2))
         t))
    ((el-var-p atom2) nil)
    ((kb-var-p atom1)
     (if (kb-var-p atom2)
         (< (variable-id atom1) (variable-id atom2))
         t))
    ((kb-var-p atom1) nil)
    ((symbolp atom1)
     (if (symbolp atom2)
         (string-lessp (symbol-name atom1) (symbol-name atom2))
         t))
    ((symbolp atom2) nil)
    ((numberp atom1)
     (if (numberp atom2)
         (< atom1 atom2)
         t))
    ((numberp atom2) nil)
    ((characterp atom1)
     (if (characterp atom2)
         (char-lessp atom1 atom2)
         t))
    ((characterp atom2) nil)
    ((stringp atom1)
     (if (stringp atom2)
         (string-lessp atom1 atom2)
         t))
    ((stringp atom2) nil)
    (t
     (string-lessp (str atom1) (str atom2)))))

(defun old-commutative-conses-in-order-p (cons1 cons2)
  "[Cyc] Old commutative cons ordering predicate."
  (let ((var-num1 (tree-count-if #'el-var-p cons1))
        (var-num2 (tree-count-if #'el-var-p cons2)))
    (cond
      ((< var-num1 var-num2) t)
      ((> var-num1 var-num2) nil)
      (t
       (let ((atom-num1 (tree-count-if #'atom cons1))
             (atom-num2 (tree-count-if #'atom cons2)))
         (cond
           ((< atom-num1 atom-num2) t)
           ((> atom-num1 atom-num2) nil)
           (t
            (cond
              ((and (not (equal (first cons1) (first cons2)))
                    (commutative-terms-in-order-p (first cons1) (first cons2)))
               t)
              ((and (not (equal (first cons1) (first cons2)))
                    (commutative-terms-in-order-p (first cons2) (first cons1)))
               nil)
              (t
               (commutative-terms-in-order-p (rest cons1) (rest cons2)))))))))))

(defun last-resort-min-literals (literals)
  "[Cyc] Find the minimal set of literals using last-resort scoring."
  (let ((selected nil)
        (remaining nil))
    (setf selected (last-resort-min-literals-int literals))
    (setf remaining (ordered-set-difference literals selected :test #'equal))
    (loop until (or (singletonp selected) (null remaining)) do
      (setf selected (last-resort-min-literals-int remaining))
      (setf remaining (ordered-set-difference remaining selected :test #'equal)))
    (cond
      (selected selected)
      (remaining remaining)
      (literals literals)
      (t nil))))

(defun last-resort-min-literals-int (literals)
  "[Cyc] Internal helper for last-resort-min-literals."
  (when literals
    (when (singletonp literals)
      (return-from last-resort-min-literals-int literals))
    (let ((min-candidates (last-resort-min-literals-min literals)))
      (when (singletonp min-candidates)
        (return-from last-resort-min-literals-int min-candidates))
      (let ((max-candidates (last-resort-min-literals-max literals)))
        (when (singletonp max-candidates)
          (return-from last-resort-min-literals-int max-candidates))
        (if (<= (length min-candidates) (length max-candidates))
            min-candidates
            max-candidates)))))

(defun last-resort-min-literals-min (literals)
  "[Cyc] Return the subset of LITERALS with the minimum last-resort score."
  (let* ((result (list (first literals)))
         (value (last-resort-min-literals-fn (first result))))
    (dolist (literal (rest literals))
      (let ((lit-value (last-resort-min-literals-fn literal)))
        (cond
          ((< lit-value value)
           (setf value lit-value)
           (setf result (list literal)))
          ((= lit-value value)
           (push literal result)))))
    result))

(defun constant-median (constants)
  "[Cyc] @hack this function must die as soon as the recanonicalizer works -eca"
  (parametrized-median constants #'constant-external-id-<))

(defun ugly-thing-< (ugly1 ugly2)
  "[Cyc] @hack this function must die as soon as the recanonicalizer works -eca"
  (cond
    ((eql ugly1 most-positive-fixnum) nil)
    ((eql ugly2 most-positive-fixnum) t)
    (t (constant-external-id-< ugly1 ugly2))))

(defun ugly-thing-> (ugly1 ugly2)
  "[Cyc] @hack this function must die as soon as the recanonicalizer works -eca"
  (and (null (ugly-thing-< ugly1 ugly2))
       (not (equal ugly1 ugly2))))

(defun last-resort-min-literals-max (literals)
  "[Cyc] Return the subset of LITERALS with the maximum last-resort score."
  (let* ((result (list (first literals)))
         (value (last-resort-min-literals-fn (first result))))
    (dolist (literal (rest literals))
      (let ((lit-value (last-resort-min-literals-fn literal)))
        (cond
          ((ugly-thing-> lit-value value)
           (setf value lit-value)
           (setf result (list literal)))
          ((equal lit-value value)
           (push literal result)))))
    result))

(defun last-resort-min-literals-fn (lit)
  "[Cyc] Compute the last-resort score for LIT."
  (let* ((constants (expression-gather lit #'constant-p))
         (value (constant-median constants)))
    (if (constant-external-id-p value)
        value
        most-positive-fixnum)))
