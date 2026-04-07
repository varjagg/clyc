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

(defparameter *forward-modules* nil)

(defparameter *forward-tactic-specs* nil)

;; (defun forward-modules () ...) -- active declareFunction, no body
;; (defun forward-module-count () ...) -- active declareFunction, no body
;; (defun forward-module-p (object) ...) -- active declareFunction, no body

(defun forward-module (name plist)
  "[Cyc] Declare forward module NAME with property list PLIST."
  (let ((hl-module (setup-module name :forward plist)))
    (pushnew hl-module *forward-modules* :test #'eql)
    hl-module))

;; (defun undeclare-forward-module (name) ...) -- active declareFunction, no body

;; Reconstructed from Internal Constants:
;; $list1 = ((HL-MODULE &KEY DONE) &BODY BODY) -- arglist
;; $sym5 = DO-LIST -- operator
;; $list6 = (DO-FORWARD-MODULES-LIST) -- helper call
;; Expansion uses do-list over do-forward-modules-list with :done early-exit.
(defmacro do-forward-modules ((hl-module &key done) &body body)
  `(do-list (,hl-module (do-forward-modules-list) :done ,done)
     ,@body))

(defun do-forward-modules-list ()
  *forward-modules*)

(defun forward-module-callback (trigger-asent trigger-sense examine-asent examine-sense rule &optional trigger-supports)
  (push (list trigger-asent trigger-sense examine-asent examine-sense rule trigger-supports)
        *forward-tactic-specs*)
  nil)

(defun forward-tactic-specs (source-asent source-sense propagation-mt)
  "[Cyc] @param SOURCE-ASENT ; an atomic sentence
@param SOUCE-SENSE  ; sense-p, the sense of SOURCE-ASENT
@param PROPAGATION-MT ; the mt in which forward expansions are to be done
@return A list of tuples of the form
  (EXPANDED-ASENT EXPANDED-SOURCE &optional ADDITIONAL-SUPPORTS)
where :
EXPANDED-ASENT is an atomic sentence
EXPANDED-SENSE ; sense-p, the sense of EXPANDED-ASENT
ADDITIONAL-SUPPORTS ; a list of support-p justifying why :
  SOURCE-ASENT & SOURCE-SENSE => EXPANDED-ASENT & EXPANDED-SENSE"
  (let ((answer nil))
    (when (sublisp-boolean (forward-inference-allowed-rules))
      (let ((*forward-tactic-specs* nil))
        (let ((mt-var (with-inference-mt-relevance-validate propagation-mt)))
          (let ((*mt* (update-inference-mt-relevance-mt mt-var))
                (*relevant-mt-function* (update-inference-mt-relevance-function mt-var))
                (*relevant-mts* (update-inference-mt-relevance-mt-list mt-var)))
            (dolist (forward-hl-module (forward-hl-modules source-asent source-sense))
              (forward-hl-module-apply forward-hl-module source-asent)))
          (setf answer (nreverse *forward-tactic-specs*)))))
    answer))

(defun forward-hl-modules (asent sense)
  "[Cyc] Determine the HL modules which could be used to forward expand ASENT with SENSE"
  (let ((predicate (atomic-sentence-predicate asent))
        (hl-modules nil)
        (supplanted-modules nil)
        (exclusive-found? nil))
    (do* ((rest (do-forward-modules-list) (rest rest)))
         ((or exclusive-found? (null rest)))
      (let ((hl-module (first rest)))
        (when (hl-module-active? hl-module nil)
          (unless (and supplanted-modules
                       (member hl-module supplanted-modules))
            (when (and (hl-module-sense-relevant-p hl-module sense)
                       (hl-module-predicate-relevant-p hl-module predicate)
                       (hl-module-required-pattern-matched-p hl-module asent))
              (let ((exclusive-func (hl-module-exclusive-func hl-module)))
                (when (or (null exclusive-func)
                          (funcall exclusive-func asent))
                  (when exclusive-func
                    (let ((supplants-info (hl-module-supplants-info hl-module)))
                      (if (eql supplants-info :all)
                          (progn
                            (setf hl-modules nil)
                            (setf exclusive-found? t))
                          (let ((newly-supplanted-module-names supplants-info))
                            (dolist (supplanted-module-name newly-supplanted-module-names)
                              (let ((supplanted-module (find-hl-module-by-name supplanted-module-name)))
                                (when supplanted-module
                                  (push supplanted-module supplanted-modules)
                                  (setf hl-modules (delete-first supplanted-module hl-modules #'eq)))))))))
                  (let ((required-func (hl-module-required-func hl-module)))
                    (when (or (null required-func)
                              (funcall required-func asent))
                      (push hl-module hl-modules))))))))))
    (nreverse hl-modules)))

(defun forward-hl-module-apply (forward-hl-module source-asent)
  (let ((candidate-rules (forward-hl-module-rule-select forward-hl-module source-asent)))
    (let ((rules (if candidate-rules
                     (forward-hl-module-rule-filter forward-hl-module source-asent candidate-rules)
                     nil)))
      (forward-hl-module-expand forward-hl-module source-asent rules))))

(defun forward-hl-module-rule-select (forward-hl-module source-asent)
  (if (forward-inference-all-rules-allowed?)
      (let ((rule-select-method (hl-module-rule-select-func forward-hl-module)))
        (if (function-spec-p rule-select-method)
            (funcall rule-select-method source-asent)
            nil))
      *forward-inference-allowed-rules*))

(defun forward-hl-module-rule-filter (forward-hl-module source-asent rules)
  (let ((rule-filter-method (hl-module-rule-filter-func forward-hl-module)))
    (if (and (function-spec-p rule-filter-method)
             (not (forward-inference-all-rules-allowed?)))
        (let ((filtered-rules nil))
          (dolist (rule rules)
            (when (funcall rule-filter-method source-asent rule)
              (push rule filtered-rules)))
          (nreverse filtered-rules))
        rules)))

(defun forward-hl-module-expand (forward-hl-module source-asent rules)
  (let ((expand-function (hl-module-expand-func forward-hl-module)))
    (when (function-spec-p expand-function)
      (dolist (rule rules)
        (funcall expand-function source-asent rule))))
  nil)

(defun all-antecedent-predicate-forward-rules (pred)
  (let ((rules nil))
    (dolist (direction (relevant-directions))
      (when (do-predicate-rule-index-key-validator pred :neg direction)
        (let ((iterator-var (new-predicate-rule-final-index-spec-iterator pred :neg direction))
              (done-var nil)
              (token-var nil))
          (until done-var
            (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                   (valid (not (eq token-var final-index-spec))))
              (when valid
                (let ((final-index-iterator nil))
                  (unwind-protect
                       (progn
                         (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                         (let ((done-var-2 nil)
                               (token-var-2 nil))
                           (until done-var-2
                             (let* ((rule (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                    (valid-2 (not (eq token-var-2 rule))))
                               (when valid-2
                                 (push rule rules))
                               (setf done-var-2 (not valid-2))))))
                    (let ((*is-thread-performing-cleanup?* t))
                      (when final-index-iterator
                        (destroy-final-index-iterator final-index-iterator))))))
              (setf done-var (not valid)))))))
    (setf rules (fast-delete-duplicates rules #'eq))
    rules))

;; (defun all-consequent-predicate-forward-rules (pred) ...) -- active declareFunction, no body

(defun all-ist-predicate-forward-rules (pred)
  (let ((rules nil))
    (dolist (direction (relevant-directions))
      (when (do-decontextualized-ist-predicate-rule-index-key-validator pred nil direction)
        (let ((iterator-var (new-decontextualized-ist-predicate-rule-final-index-spec-iterator pred nil direction))
              (done-var nil)
              (token-var nil))
          (until done-var
            (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                   (valid (not (eq token-var final-index-spec))))
              (when valid
                (let ((final-index-iterator nil))
                  (unwind-protect
                       (progn
                         (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                         (let ((done-var-2 nil)
                               (token-var-2 nil))
                           (until done-var-2
                             (let* ((rule (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                    (valid-2 (not (eq token-var-2 rule))))
                               (when valid-2
                                 (push rule rules))
                               (setf done-var-2 (not valid-2))))))
                    (let ((*is-thread-performing-cleanup?* t))
                      (when final-index-iterator
                        (destroy-final-index-iterator final-index-iterator))))))
              (setf done-var (not valid)))))))
    (setf rules (fast-delete-duplicates rules #'eq))
    rules))

(defun forward-normal-pos-rule-select (asent)
  (all-antecedent-predicate-forward-rules (atomic-sentence-predicate asent)))

(defun forward-normal-pos-rule-filter (asent rule)
  (forward-normal-pos-expand-int asent rule t))

(defun forward-normal-pos-expand (asent rule)
  (dolist (examine-lit (forward-normal-pos-expand-int asent rule))
    (forward-module-callback asent :pos examine-lit :neg rule))
  nil)

(defun forward-normal-pos-expand-int (asent rule &optional boolean?)
  (let* ((pred (atomic-sentence-predicate asent))
         (examine-lits nil)
         (predicate-var pred)
         (cnf-var (assertion-cnf rule)))
    (do* ((rest (neg-lits cnf-var) (rest rest)))
         ((or (and boolean? examine-lits)
              (null rest)))
      (let ((lit (first rest)))
        (when (eq predicate-var (atomic-sentence-predicate lit))
          (push lit examine-lits))))
    (if boolean?
        (sublisp-boolean examine-lits)
        examine-lits)))

;; (defun forward-normal-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-normal-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-normal-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-normal-neg-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

(defun forward-isa-rule-select (asent)
  (let ((col (atomic-sentence-arg2 asent))
        (rules nil))
    (dolist (genl (forward-inference-all-genls col))
      (dolist (direction (relevant-directions))
        (when (do-isa-rule-index-key-validator genl :neg direction)
          (let ((iterator-var (new-isa-rule-final-index-spec-iterator genl :neg direction))
                (done-var nil)
                (token-var nil))
            (until done-var
              (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                     (valid (not (eq token-var final-index-spec))))
                (when valid
                  (let ((final-index-iterator nil))
                    (unwind-protect
                         (progn
                           (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                           (let ((done-var-2 nil)
                                 (token-var-2 nil))
                             (until done-var-2
                               (let* ((rule (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                      (valid-2 (not (eq token-var-2 rule))))
                                 (when valid-2
                                   (push rule rules))
                                 (setf done-var-2 (not valid-2))))))
                      (let ((*is-thread-performing-cleanup?* t))
                        (when final-index-iterator
                          (destroy-final-index-iterator final-index-iterator))))))
                (setf done-var (not valid))))))))
    rules))

(defun forward-isa-rule-filter (asent rule)
  (forward-isa-expand-int asent rule t))

(defun forward-isa-expand (asent rule)
  (let ((arg1 (atomic-sentence-arg1 asent))
        (arg2 (atomic-sentence-arg2 asent)))
    (let ((*type-filter-forward-dnf* t))
      (dolist (examine-lit (forward-isa-expand-int asent rule))
        (let* ((genl (atomic-sentence-arg2 examine-lit))
               (forward-asent (list #$isa arg1 genl))
               (more-supports (if (eq genl arg2)
                                  nil
                                  (list (make-hl-support :genls (list #$genls arg2 genl))))))
          (forward-module-callback forward-asent :pos examine-lit :neg rule more-supports)))))
  nil)

(defun forward-isa-expand-int (asent rule &optional boolean?)
  (let* ((source-col (atomic-sentence-arg2 asent))
         (examine-lits nil)
         (cnf-var (assertion-cnf rule)))
    (do* ((rest (neg-lits cnf-var) (rest rest)))
         ((or (and boolean? examine-lits)
              (null rest)))
      (let ((lit (first rest)))
        (when (eq #$isa (atomic-sentence-predicate lit))
          (let ((rule-col (atomic-sentence-arg2 lit)))
            (when (and (fully-bound-p rule-col)
                       (forward-inference-genl? source-col rule-col))
              (push lit examine-lits))))))
    (if boolean?
        (sublisp-boolean examine-lits)
        examine-lits)))

(defun forward-inference-genl? (source-col rule-col)
  (member-eq? rule-col (forward-inference-all-genls source-col)))

(defun-memoized forward-inference-all-genls (col) (:test eq)
  (all-genls col))

;; (defun forward-not-isa-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-not-isa-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-not-isa-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-not-isa-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body
;; (defun forward-quoted-isa-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-quoted-isa-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-quoted-isa-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-quoted-isa-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body
;; (defun forward-not-quoted-isa-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-not-quoted-isa-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-not-quoted-isa-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-not-quoted-isa-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

(defun forward-genls-rule-select (asent)
  (let ((col (atomic-sentence-arg2 asent))
        (rules nil))
    (dolist (genl (forward-inference-all-genls col))
      (dolist (direction (relevant-directions))
        (when (do-genls-rule-index-key-validator genl :neg direction)
          (let ((iterator-var (new-genls-rule-final-index-spec-iterator genl :neg direction))
                (done-var nil)
                (token-var nil))
            (until done-var
              (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                     (valid (not (eq token-var final-index-spec))))
                (when valid
                  (let ((final-index-iterator nil))
                    (unwind-protect
                         (progn
                           (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                           (let ((done-var-2 nil)
                                 (token-var-2 nil))
                             (until done-var-2
                               (let* ((rule (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                      (valid-2 (not (eq token-var-2 rule))))
                                 (when valid-2
                                   (push rule rules))
                                 (setf done-var-2 (not valid-2))))))
                      (let ((*is-thread-performing-cleanup?* t))
                        (when final-index-iterator
                          (destroy-final-index-iterator final-index-iterator))))))
                (setf done-var (not valid))))))))
    rules))

;; (defun forward-genls-rule-filter (asent rule) ...) -- active declareFunction, no body

(defun forward-genls-expand (asent rule)
  (let ((arg1 (atomic-sentence-arg1 asent))
        (arg2 (atomic-sentence-arg2 asent)))
    (let ((*type-filter-forward-dnf* t))
      (dolist (examine-lit (forward-genls-expand-int asent rule))
        (let* ((genl (atomic-sentence-arg2 examine-lit))
               (forward-asent (list #$genls arg1 genl))
               (more-supports (if (eq genl arg2)
                                  nil
                                  (list (make-hl-support :genls (list #$genls arg2 genl))))))
          (forward-module-callback forward-asent :pos examine-lit :neg rule more-supports)))))
  nil)

(defun forward-genls-expand-int (asent rule &optional boolean?)
  (let* ((source-col (atomic-sentence-arg2 asent))
         (examine-lits nil)
         (cnf-var (assertion-cnf rule)))
    (do* ((rest (neg-lits cnf-var) (rest rest)))
         ((or (and boolean? examine-lits)
              (null rest)))
      (let ((lit (first rest)))
        (when (eq #$genls (atomic-sentence-predicate lit))
          (let ((rule-col (atomic-sentence-arg2 lit)))
            (when (and (fully-bound-p rule-col)
                       (forward-inference-genl? source-col rule-col))
              (push lit examine-lits))))))
    (if boolean?
        (sublisp-boolean examine-lits)
        examine-lits)))

;; (defun forward-not-genls-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-not-genls-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-not-genls-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-not-genls-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

(defun forward-genlmt-rule-select (asent)
  (let ((mt (atomic-sentence-arg2 asent))
        (rules nil))
    (dolist (genl-mt (all-genl-mts mt))
      (dolist (direction (relevant-directions))
        (when (do-genl-mt-rule-index-key-validator genl-mt :neg direction)
          (let ((iterator-var (new-genl-mt-rule-final-index-spec-iterator genl-mt :neg direction))
                (done-var nil)
                (token-var nil))
            (until done-var
              (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                     (valid (not (eq token-var final-index-spec))))
                (when valid
                  (let ((final-index-iterator nil))
                    (unwind-protect
                         (progn
                           (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                           (let ((done-var-2 nil)
                                 (token-var-2 nil))
                             (until done-var-2
                               (let* ((rule (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                      (valid-2 (not (eq token-var-2 rule))))
                                 (when valid-2
                                   (push rule rules))
                                 (setf done-var-2 (not valid-2))))))
                      (let ((*is-thread-performing-cleanup?* t))
                        (when final-index-iterator
                          (destroy-final-index-iterator final-index-iterator))))))
                (setf done-var (not valid))))))))
    rules))

(defun forward-genlmt-rule-filter (asent rule)
  (forward-genlmt-expand-int asent rule t))

;; (defun forward-genlmt-expand (asent rule) ...) -- active declareFunction, no body

(defun forward-genlmt-expand-int (asent rule &optional boolean?)
  (let* ((source-mt (atomic-sentence-arg2 asent))
         (examine-lits nil)
         (cnf-var (assertion-cnf rule)))
    (do* ((rest (neg-lits cnf-var) (rest rest)))
         ((or (and boolean? examine-lits)
              (null rest)))
      (let ((lit (first rest)))
        (when (eq #$genlMt (atomic-sentence-predicate lit))
          (let ((rule-mt (atomic-sentence-arg2 lit)))
            (when (and (fully-bound-p rule-mt)
                       (genl-mt? source-mt rule-mt))
              (push lit examine-lits))))))
    (if boolean?
        (sublisp-boolean examine-lits)
        examine-lits)))

;; (defun forward-not-genlmt-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-not-genlmt-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-not-genlmt-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-not-genlmt-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

(defun forward-symmetric-pos-rule-select (asent)
  (all-antecedent-predicate-forward-rules (atomic-sentence-predicate asent)))

;; (defun forward-symmetric-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-symmetric-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-symmetric-pos-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body
;; (defun forward-symmetric-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-symmetric-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-symmetric-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-symmetric-neg-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

(defun forward-asymmetric-required (asent)
  (let ((pattern '((:and (:test non-hl-predicate-p) (:test inference-asymmetric-predicate?))
                   :anything :anything)))
    (and *forward-propagate-from-negations*
         (formula-matches-pattern asent pattern))))

;; (defun forward-asymmetric-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-asymmetric-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-asymmetric-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-asymmetric-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body
;; (defun forward-commutative-pos-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-commutative-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-commutative-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-commutative-pos-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body
;; (defun forward-commutative-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-commutative-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-commutative-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-commutative-neg-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body
;; (defun forward-genlpreds-gaf-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-genlpreds-gaf-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-genlpreds-gaf-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-genlpreds-gaf-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body
;; (defun forward-not-genlpreds-gaf-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-not-genlpreds-gaf-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-not-genlpreds-gaf-expand (asent rule) ...) -- active declareFunction, no body

(defun forward-genlpreds-pos-rule-select (asent)
  (let ((pred (atomic-sentence-predicate asent))
        (rules nil))
    (dolist (genl-pred (delete pred (all-genl-preds pred) :test #'eq))
      (unless (hl-predicate-p genl-pred)
        (dolist (direction (relevant-directions))
          (when (do-predicate-rule-index-key-validator genl-pred :neg direction)
            (let ((iterator-var (new-predicate-rule-final-index-spec-iterator genl-pred :neg direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator nil))
                      (unwind-protect
                           (progn
                             (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                             (let ((done-var-2 nil)
                                   (token-var-2 nil))
                               (until done-var-2
                                 (let* ((rule (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                        (valid-2 (not (eq token-var-2 rule))))
                                   (when valid-2
                                     (push rule rules))
                                   (setf done-var-2 (not valid-2))))))
                        (let ((*is-thread-performing-cleanup?* t))
                          (when final-index-iterator
                            (destroy-final-index-iterator final-index-iterator))))))
                  (setf done-var (not valid)))))))))
    rules))

;; (defun forward-genlpreds-pos-rule-filter (asent rule) ...) -- active declareFunction, no body

(defun forward-genlpreds-pos-expand (asent rule)
  (let ((pred (atomic-sentence-predicate asent))
        (args (atomic-sentence-args asent)))
    (dolist (examine-lit (forward-genlpreds-pos-expand-int asent rule))
      (let* ((genl-pred (atomic-sentence-predicate examine-lit))
             (forward-asent (cons genl-pred (append args nil)))
             (more-supports (list (make-hl-support :genlpreds (list #$genlPreds pred genl-pred)))))
        (forward-module-callback forward-asent :pos examine-lit :neg rule more-supports))))
  nil)

(defun forward-genlpreds-pos-expand-int (asent rule &optional boolean?)
  (let* ((pred (atomic-sentence-predicate asent))
         (examine-lits nil)
         (cnf-var (assertion-cnf rule)))
    (do* ((rest (neg-lits cnf-var) (rest rest)))
         ((or (and boolean? examine-lits)
              (null rest)))
      (let* ((lit (first rest))
             (rule-pred (atomic-sentence-predicate lit)))
        (when (and (fully-bound-p rule-pred)
                   (not (eq pred rule-pred))
                   (not (hl-predicate-p rule-pred))
                   (genl-predicate? pred rule-pred))
          (push lit examine-lits))))
    (if boolean?
        (sublisp-boolean examine-lits)
        examine-lits)))

(defun forward-genlinverse-gaf-rule-select (asent)
  (let ((pred (atomic-sentence-arg2 asent))
        (rules nil))
    ;; First: search genlInverse rules matching genl-preds of pred
    (let ((genl-preds (delete pred (all-genl-preds pred) :test #'eq)))
      (dolist (direction (relevant-directions))
        (when (do-predicate-rule-index-key-validator #$genlInverse :neg direction)
          (let ((iterator-var (new-predicate-rule-final-index-spec-iterator #$genlInverse :neg direction))
                (done-var nil)
                (token-var nil))
            (until done-var
              (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                     (valid (not (eq token-var final-index-spec))))
                (when valid
                  (let ((final-index-iterator nil))
                    (unwind-protect
                         (progn
                           (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                           (let ((done-var-2 nil)
                                 (token-var-2 nil))
                             (until done-var-2
                               (let* ((rule (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                      (valid-2 (not (eq token-var-2 rule))))
                                 (when valid-2
                                   (let ((selected? nil))
                                     (let* ((predicate-var #$genlPreds)
                                            (cnf-var (assertion-cnf rule)))
                                       (do* ((rest (neg-lits cnf-var) (rest rest)))
                                            ((or selected? (null rest)))
                                         (let ((lit (first rest)))
                                           (when (eq predicate-var (atomic-sentence-predicate lit))
                                             (let ((rule-pred (atomic-sentence-arg2 lit)))
                                               (when (member-eq? rule-pred genl-preds)
                                                 (push rule rules)
                                                 (setf selected? t)))))))))
                                 (setf done-var-2 (not valid-2))))))
                      (let ((*is-thread-performing-cleanup?* t))
                        (when final-index-iterator
                          (destroy-final-index-iterator final-index-iterator))))))
                (setf done-var (not valid))))))))
    ;; Second: search genlPreds rules matching genl-inverses of pred
    (let ((genl-inverses (all-genl-inverses pred)))
      (dolist (direction (relevant-directions))
        (when (do-predicate-rule-index-key-validator #$genlPreds :neg direction)
          (let ((iterator-var (new-predicate-rule-final-index-spec-iterator #$genlPreds :neg direction))
                (done-var nil)
                (token-var nil))
            (until done-var
              (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                     (valid (not (eq token-var final-index-spec))))
                (when valid
                  (let ((final-index-iterator nil))
                    (unwind-protect
                         (progn
                           (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                           (let ((done-var-2 nil)
                                 (token-var-2 nil))
                             (until done-var-2
                               (let* ((rule (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                      (valid-2 (not (eq token-var-2 rule))))
                                 (when valid-2
                                   (let ((selected? nil))
                                     (let* ((predicate-var #$genlInverse)
                                            (cnf-var (assertion-cnf rule)))
                                       (do* ((rest (neg-lits cnf-var) (rest rest)))
                                            ((or selected? (null rest)))
                                         (let ((lit (first rest)))
                                           (when (eq predicate-var (atomic-sentence-predicate lit))
                                             (let ((rule-pred (atomic-sentence-arg2 lit)))
                                               (when (member-eq? rule-pred genl-inverses)
                                                 (push rule rules)
                                                 (setf selected? t)))))))))
                                 (setf done-var-2 (not valid-2))))))
                      (let ((*is-thread-performing-cleanup?* t))
                        (when final-index-iterator
                          (destroy-final-index-iterator final-index-iterator))))))
                (setf done-var (not valid))))))))
    rules))

;; (defun forward-genlinverse-gaf-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-genlinverse-gaf-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-genlinverse-gaf-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body
;; (defun forward-not-genlinverse-gaf-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-not-genlinverse-gaf-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-not-genlinverse-gaf-expand (asent rule) ...) -- active declareFunction, no body

(defun forward-genlinverse-pos-rule-select (asent)
  (let ((pred (atomic-sentence-predicate asent))
        (rules nil))
    (dolist (genl-inverse (all-genl-inverses pred))
      (unless (hl-predicate-p genl-inverse)
        (dolist (direction (relevant-directions))
          (when (do-predicate-rule-index-key-validator genl-inverse :neg direction)
            (let ((iterator-var (new-predicate-rule-final-index-spec-iterator genl-inverse :neg direction))
                  (done-var nil)
                  (token-var nil))
              (until done-var
                (let* ((final-index-spec (iteration-next-without-values-macro-helper iterator-var token-var))
                       (valid (not (eq token-var final-index-spec))))
                  (when valid
                    (let ((final-index-iterator nil))
                      (unwind-protect
                           (progn
                             (setf final-index-iterator (new-final-index-iterator final-index-spec :rule nil direction))
                             (let ((done-var-2 nil)
                                   (token-var-2 nil))
                               (until done-var-2
                                 (let* ((rule (iteration-next-without-values-macro-helper final-index-iterator token-var-2))
                                        (valid-2 (not (eq token-var-2 rule))))
                                   (when valid-2
                                     (push rule rules))
                                   (setf done-var-2 (not valid-2))))))
                        (let ((*is-thread-performing-cleanup?* t))
                          (when final-index-iterator
                            (destroy-final-index-iterator final-index-iterator))))))
                  (setf done-var (not valid)))))))))
    rules))

;; (defun forward-genlinverse-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-genlinverse-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-genlinverse-pos-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

(defun forward-negationpreds-required (asent)
  (when *forward-propagate-from-negations*
    (let ((pattern '((:and (:test non-hl-predicate-p) (:test inference-some-negation-pred-or-inverse?))
                     . :anything)))
      (formula-matches-pattern asent pattern))))

;; (defun forward-negationpreds-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-negationpreds-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-negationpreds-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-negationpreds-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

(defun forward-negationinverse-required (asent)
  (when *forward-propagate-from-negations*
    (let ((pattern '((:and (:test non-hl-predicate-p) (:test inference-some-negation-pred-or-inverse?))
                     :anything :anything)))
      (formula-matches-pattern asent pattern))))

;; (defun forward-negationinverse-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-negationinverse-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-negationinverse-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-negationinverse-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

(defun forward-eval-exclusive-pos (asent)
  (let ((pattern '((:and (:test non-hl-predicate-p) (:test inference-evaluatable-predicate?))
                   . :anything)))
    (formula-matches-pattern asent pattern)))

;; (defun forward-eval-expand-pos (asent rule) ...) -- active declareFunction, no body
;; (defun forward-eval-exclusive-neg (asent) ...) -- active declareFunction, no body
;; (defun forward-eval-expand-neg (asent rule) ...) -- active declareFunction, no body
;; (defun forward-term-of-unit-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-term-of-unit-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-term-of-unit-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-term-of-unit-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body
;; (defun forward-nat-function-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-nat-function-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-nat-function-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-nat-function-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

(defun forward-unbound-pred-pos-required (asent)
  (declare (ignore asent))
  *unbound-rule-backchain-enabled*)

;; (defun forward-unbound-pred-pos-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-unbound-pred-pos-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-unbound-pred-pos-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-unbound-pred-pos-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body
;; (defun forward-unbound-pred-neg-required (asent) ...) -- active declareFunction, no body
;; (defun forward-unbound-pred-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-unbound-pred-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-unbound-pred-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-unbound-pred-neg-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

(defun forward-ist-pos-rule-select (asent)
  (all-ist-predicate-forward-rules (atomic-sentence-predicate asent)))

(defun forward-ist-pos-rule-filter (asent rule)
  (forward-ist-pos-expand-int asent rule t))

;; (defun forward-ist-pos-expand (asent rule) ...) -- active declareFunction, no body

(defun forward-ist-pos-expand-int (asent rule &optional boolean?)
  (let* ((pred (atomic-sentence-predicate asent))
         (examine-lits nil))
    ;; Search neg-lits for non-negated ist sub-sentences with matching pred
    (let ((predicate-var #$ist)
          (cnf-var (assertion-cnf rule)))
      (do* ((rest (neg-lits cnf-var) (rest rest)))
           ((or (and boolean? examine-lits)
                (null rest)))
        (let ((lit (first rest)))
          (when (eq predicate-var (atomic-sentence-predicate lit))
            (let ((sub-sentence (literal-arg2 lit)))
              (unless (el-negation-p sub-sentence)
                (let ((sub-pred (literal-predicate sub-sentence)))
                  (when (eq pred sub-pred)
                    (push lit examine-lits)))))))))
    ;; Search pos-lits for negated ist sub-sentences with matching pred
    (let ((predicate-var #$ist)
          (cnf-var (assertion-cnf rule)))
      (do* ((rest (pos-lits cnf-var) (rest rest)))
           ((or (and boolean? examine-lits)
                (null rest)))
        (let ((lit (first rest)))
          (when (eq predicate-var (atomic-sentence-predicate lit))
            (let ((sub-sentence (literal-arg2 lit)))
              (when (el-negation-p sub-sentence)
                (let ((sub-pred (literal-predicate sub-sentence)))
                  (when (eq pred sub-pred)
                    (push lit examine-lits)))))))))
    (if boolean?
        (sublisp-boolean examine-lits)
        examine-lits)))

;; (defun forward-ist-neg-rule-select (asent) ...) -- active declareFunction, no body
;; (defun forward-ist-neg-rule-filter (asent rule) ...) -- active declareFunction, no body
;; (defun forward-ist-neg-expand (asent rule) ...) -- active declareFunction, no body
;; (defun forward-ist-neg-expand-int (asent rule &optional boolean?) ...) -- active declareFunction, no body

;; Setup-phase toplevel forms

(toplevel
  (register-macro-helper 'do-forward-modules-list 'do-forward-modules))

(toplevel
  (forward-module :forward-normal-pos
                  '(:sense :pos
                    :rule-select forward-normal-pos-rule-select
                    :rule-filter forward-normal-pos-rule-filter
                    :expand forward-normal-pos-expand)))

(toplevel
  (forward-module :forward-normal-neg
                  '(:sense :neg
                    :rule-select forward-normal-neg-rule-select
                    :rule-filter forward-normal-neg-rule-filter
                    :expand forward-normal-neg-expand)))

(toplevel
  (forward-module :forward-isa
                  '(:sense :pos
                    :predicate #$isa
                    :rule-select forward-isa-rule-select
                    :rule-filter forward-isa-rule-filter
                    :expand forward-isa-expand)))

(toplevel
  (note-memoized-function 'forward-inference-all-genls))

(toplevel
  (forward-module :forward-not-isa
                  '(:sense :neg
                    :predicate #$isa
                    :rule-select forward-not-isa-rule-select
                    :rule-filter forward-not-isa-rule-filter
                    :expand forward-not-isa-expand)))

(toplevel
  (forward-module :forward-quoted-isa
                  '(:sense :pos
                    :predicate #$quotedIsa
                    :rule-select forward-quoted-isa-rule-select
                    :rule-filter forward-quoted-isa-rule-filter
                    :expand forward-quoted-isa-expand)))

(toplevel
  (forward-module :forward-not-quoted-isa
                  '(:sense :neg
                    :predicate #$quotedIsa
                    :rule-select forward-not-quoted-isa-rule-select
                    :rule-filter forward-not-quoted-isa-rule-filter
                    :expand forward-not-quoted-isa-expand)))

(toplevel
  (forward-module :forward-genls
                  '(:sense :pos
                    :predicate #$genls
                    :rule-select forward-genls-rule-select
                    :rule-filter forward-genls-rule-filter
                    :expand forward-genls-expand)))

(toplevel
  (forward-module :forward-not-genls
                  '(:sense :neg
                    :predicate #$genls
                    :rule-select forward-not-genls-rule-select
                    :rule-filter forward-not-genls-rule-filter
                    :expand forward-not-genls-expand)))

(toplevel
  (forward-module :forward-genlmt
                  '(:sense :pos
                    :predicate #$genlMt
                    :rule-select forward-genlmt-rule-select
                    :rule-filter forward-genlmt-rule-filter
                    :expand forward-genlmt-expand)))

(toplevel
  (forward-module :forward-not-genlmt
                  '(:sense :neg
                    :predicate #$genlMt
                    :rule-select forward-not-genlmt-rule-select
                    :rule-filter forward-not-genlmt-rule-filter
                    :expand forward-not-genlmt-expand)))

(toplevel
  (forward-module :forward-symmetric-pos
                  '(:sense :pos
                    :required-pattern ((:and (:test non-hl-predicate-p)
                                            (:test inference-symmetric-predicate?))
                                       :anything :anything)
                    :rule-select forward-symmetric-pos-rule-select
                    :rule-filter forward-symmetric-pos-rule-filter
                    :expand forward-symmetric-pos-expand)))

(toplevel
  (forward-module :forward-symmetric-neg
                  '(:sense :neg
                    :required-pattern ((:and (:test non-hl-predicate-p)
                                            (:test inference-symmetric-predicate?))
                                       :anything :anything)
                    :rule-select forward-symmetric-neg-rule-select
                    :rule-filter forward-symmetric-neg-rule-filter
                    :expand forward-symmetric-neg-expand)))

(toplevel
  (forward-module :forward-asymmetric
                  '(:sense :pos
                    :required forward-asymmetric-required
                    :rule-select forward-asymmetric-rule-select
                    :rule-filter forward-asymmetric-rule-filter
                    :expand forward-asymmetric-expand)))

(toplevel
  (forward-module :forward-commutative-pos
                  '(:sense :pos
                    :required-pattern (:and ((:test non-hl-predicate-p)
                                             :anything :anything :anything . :anything)
                                            ((:test inference-at-least-partially-commutative-predicate-p)
                                             . :anything))
                    :rule-select forward-commutative-pos-rule-select
                    :rule-filter forward-commutative-pos-rule-filter
                    :expand forward-commutative-pos-expand)))

(toplevel
  (forward-module :forward-commutative-neg
                  '(:sense :neg
                    :required-pattern (:and ((:test non-hl-predicate-p)
                                             :anything :anything :anything . :anything)
                                            ((:test inference-at-least-partially-commutative-predicate-p)
                                             . :anything))
                    :rule-select forward-commutative-neg-rule-select
                    :rule-filter forward-commutative-neg-rule-filter
                    :expand forward-commutative-neg-expand)))

(toplevel
  (forward-module :forward-genlpreds-gaf
                  '(:sense :pos
                    :predicate #$genlPreds
                    :required-pattern (#$genlPreds
                                       :fully-bound
                                       (:and :fort (:test inference-some-genl-pred-or-inverse?)))
                    :rule-select forward-genlpreds-gaf-rule-select
                    :rule-filter forward-genlpreds-gaf-rule-filter
                    :expand forward-genlpreds-gaf-expand)))

(toplevel
  (forward-module :forward-not-genlpreds-gaf
                  '(:sense :neg
                    :predicate #$genlPreds
                    :rule-select forward-not-genlpreds-gaf-rule-select
                    :rule-filter forward-not-genlpreds-gaf-rule-filter
                    :expand forward-not-genlpreds-gaf-expand)))

(toplevel
  (forward-module :forward-genlpreds-pos
                  '(:sense :pos
                    :required-pattern ((:and (:test non-hl-predicate-p)
                                            (:test inference-some-genl-pred-or-inverse?))
                                       . :anything)
                    :rule-select forward-genlpreds-pos-rule-select
                    :rule-filter forward-genlpreds-pos-rule-filter
                    :expand forward-genlpreds-pos-expand)))

(toplevel
  (forward-module :forward-genlinverse-gaf
                  '(:sense :pos
                    :predicate #$genlInverse
                    :required-pattern (#$genlInverse
                                       :fully-bound
                                       (:and :fort (:test inference-some-genl-pred-or-inverse?)))
                    :rule-select forward-genlinverse-gaf-rule-select
                    :rule-filter forward-genlinverse-gaf-rule-filter
                    :expand forward-genlinverse-gaf-expand)))

(toplevel
  (forward-module :forward-not-genlinverse-gaf
                  '(:sense :neg
                    :predicate #$genlInverse
                    :rule-select forward-not-genlinverse-gaf-rule-select
                    :rule-filter forward-not-genlinverse-gaf-rule-filter
                    :expand forward-not-genlinverse-gaf-expand)))

(toplevel
  (forward-module :forward-genlinverse-pos
                  '(:sense :pos
                    :required-pattern ((:and (:test non-hl-predicate-p)
                                            (:test inference-some-genl-pred-or-inverse?))
                                       :anything :anything)
                    :rule-select forward-genlinverse-pos-rule-select
                    :rule-filter forward-genlinverse-pos-rule-filter
                    :expand forward-genlinverse-pos-expand)))

(toplevel
  (forward-module :forward-negationpreds
                  '(:sense :pos
                    :required forward-negationpreds-required
                    :rule-select forward-negationpreds-rule-select
                    :rule-filter forward-negationpreds-rule-filter
                    :expand forward-negationpreds-expand)))

(toplevel
  (forward-module :forward-negationinverse
                  '(:sense :pos
                    :required forward-negationinverse-required
                    :rule-select forward-negationinverse-rule-select
                    :rule-filter forward-negationinverse-rule-filter
                    :expand forward-negationinverse-expand)))

(toplevel
  (forward-module :forward-eval-pos
                  '(:sense :pos
                    :exclusive forward-eval-exclusive-pos
                    :expand forward-eval-expand-pos)))

(toplevel
  (forward-module :forward-eval-neg
                  '(:sense :neg
                    :exclusive forward-eval-exclusive-neg
                    :expand forward-eval-expand-neg)))

(toplevel
  (forward-module :forward-term-of-unit
                  '(:sense :pos
                    :predicate #$termOfUnit
                    :rule-select forward-term-of-unit-rule-select
                    :rule-filter forward-term-of-unit-rule-filter
                    :expand forward-term-of-unit-expand)))

(toplevel
  (forward-module :forward-nat-function
                  '(:sense :pos
                    :predicate #$termOfUnit
                    :rule-select forward-nat-function-rule-select
                    :rule-filter forward-nat-function-rule-filter
                    :expand forward-nat-function-expand)))

(toplevel
  (forward-module :forward-unbound-pred-pos
                  '(:sense :pos
                    :required forward-unbound-pred-pos-required
                    :rule-select forward-unbound-pred-pos-rule-select
                    :rule-filter forward-unbound-pred-pos-rule-filter
                    :expand forward-unbound-pred-pos-expand)))

(toplevel
  (forward-module :forward-unbound-pred-neg
                  '(:sense :neg
                    :required forward-unbound-pred-neg-required
                    :rule-select forward-unbound-pred-neg-rule-select
                    :rule-filter forward-unbound-pred-neg-rule-filter
                    :expand forward-unbound-pred-neg-expand)))

(toplevel
  (forward-module :forward-ist-pos
                  '(:sense :pos
                    :rule-select forward-ist-pos-rule-select
                    :rule-filter forward-ist-pos-rule-filter
                    :expand forward-ist-pos-expand)))

(toplevel
  (forward-module :forward-ist-neg
                  '(:sense :neg
                    :rule-select forward-ist-neg-rule-select
                    :rule-filter forward-ist-neg-rule-filter
                    :expand forward-ist-neg-expand)))
